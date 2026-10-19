# Home-manager programs specific to wodan.
{
  inputs,
  lib,
  local,
  stable,
  unstable,
  ...
}: let
  mcpServers = {
    nixos.command = lib.getExe unstable.mcp-nixos;
    playwright = {
      command = lib.getExe unstable.playwright-mcp;
      args = ["--headless" "--isolated" "--executable-path" (lib.getExe stable.chromium)];
    };
    chrome-devtools = {
      command = lib.getExe local.chrome-devtools-mcp;
      args = ["--headless" "--isolated" "--executable-path" (lib.getExe stable.chromium) "--no-usage-statistics" "--no-performance-crux"];
    };
  };
  inline = {
    codexDesktopSafe = let
      codexDesktop = inputs.codex-desktop-linux.packages.${stable.stdenv.hostPlatform.system}.codex-desktop;
    in
      stable.symlinkJoin {
        name = "codex-desktop-safe-${codexDesktop.version}";
        paths = [codexDesktop];
        nativeBuildInputs = [stable.makeWrapper];
        postBuild = ''
          wrapProgram "$out/bin/codex-desktop" \
            --run 'volatile_dir="/tmp/$USER-codex"; ${stable.coreutils}/bin/install -d -m 700 "$volatile_dir"' \
            --set-default CODEX_ELECTRON_DISABLE_GPU_COMPOSITING 1
        '';
      };
  };
in {
  nixcfg.plasma = {
    taskbarScreens = [0 1];
    extraTaskbarLaunchers = [
      "applications:orca-ide.desktop"
      "applications:paperclip.desktop"
      "applications:agent-orchestrator.desktop"
      "applications:Emdash.desktop"
      "applications:Kandev.desktop"
      "applications:Paseo.desktop"
      "applications:superset.desktop"
    ];
  };

  programs = {
    plasma = {
      kwin.effects.zoom = {
        enable = true;
        mousePointer = "scale";
        mouseTracking = "proportional";
        # Four steps reach exactly 2x linear zoom: one source quarter fills the screen.
        zoomFactor = 1.189207115002721;
      };

      configFile = {
        kcminputrc = {
          "Libinput/1133/49970/Logitech Gaming Mouse G502".PointerAccelerationProfile = 1;
          Mouse = {
            X11LibInputXAccelProfileFlat = true;
            cursorSize = 36;
            cursorTheme = "breeze_cursors";
          };
        };

        ktrashrc."\\/home\\/david\\/.local\\/share\\/Trash" = {
          Days = 7;
          LimitReachedAction = 0;
          Percent = 10;
          UseSizeLimit = true;
          UseTimeLimit = false;
        };

        kwinrc = {
          Desktops = {
            Number = 1;
            Rows = 1;
          };
          NightColor.Active = true;
          TabBox = {
            ActivitiesMode = 0;
            DesktopMode = 0;
            HighlightWindows = false;
            MultiScreenMode = 1;
            OrderMinimizedMode = 1;
          };
          Tiling.padding = 4;
          Xwayland.Scale = 1.25;
          "org.kde.kdecoration2".theme = "__aurorae__svg__WillowDarkBlur";
        };
      };
    };

    codexDesktopLinux = {
      enable = true;
      package = inline.codexDesktopSafe;
    };
  };

  xdg = {
    configFile = {
      "codex-desktop/settings.json".text = builtins.toJSON {
        codex-linux-prompt-window-enabled = false;
        codex-linux-system-tray-enabled = false;
        codex-linux-warm-start-enabled = true;
      };
    };
  };

  home = {
    packages = [
      local.agent-orchestrator
      local.bend
      local.chrome-devtools-mcp
      local.dbhub
      local.emdash
      local.kandev
      local.orca-ide
      local.paperclip
      local.paseo-desktop
      local.pi-desktop
      local.playwright-cli
      local.superset
      local.t3code
      local.unsloth
      unstable.mcp-nixos
      unstable.playwright-mcp
    ];
    file = lib.genAttrs [
      ".agents/skills/playwright-cli"
      ".codex/skills/playwright-cli"
      ".copilot/skills/playwright-cli"
      ".config/opencode/skills/playwright-cli"
    ] (_: {source = "${local.playwright-cli}/share/skills/playwright-cli";});

    activation = {
      wodanMcpClients = lib.hm.dag.entryAfter ["headroomClients" "blenderMcpClient" "linkGeneration"] ''
        $DRY_RUN_CMD ${stable.python3.withPackages (p: [p.tomlkit])}/bin/python - "$HOME" ${lib.escapeShellArg (builtins.toJSON mcpServers)} <<'PY'
        import json
        import os
        from pathlib import Path
        import shutil
        import sys
        import tempfile
        import tomlkit

        home = Path(sys.argv[1])
        servers = json.loads(sys.argv[2])
        for relative, loads, dumps in [
            (".codex/config.toml", tomlkit.loads, tomlkit.dumps),
            (".config/opencode/opencode.json", json.loads, lambda value: json.dumps(value, indent=2) + "\n"),
        ]:
            path = home / relative
            original = path.read_text() if path.exists() else ""
            document = loads(original) if original else {}
            if relative.endswith(".toml"):
                document.setdefault("mcp_servers", {}).update(servers)
            else:
                document.setdefault("mcp", {}).update({
                    name: {"type": "local", "command": [server["command"], *server.get("args", [])], "enabled": True}
                    for name, server in servers.items()
                })
            updated = dumps(document)
            if updated == original:
                continue
            path.parent.mkdir(parents=True, exist_ok=True)
            backup = path.with_name(path.name + ".before-wodan-mcp")
            if path.exists() and not backup.exists():
                shutil.copy2(path, backup)
            fd, temporary = tempfile.mkstemp(dir=path.parent)
            try:
                with os.fdopen(fd, "w") as stream:
                    stream.write(updated)
                # Replace symlinks locally rather than editing shared dotfiles.
                os.replace(temporary, path)
            finally:
                if os.path.exists(temporary):
                    os.unlink(temporary)
        PY
      '';

      codexVolatileLogs = lib.hm.dag.entryAfter ["writeBoundary"] ''
        codex_dir="$HOME/.codex"
        volatile_dir="/tmp/$USER-codex"

        $DRY_RUN_CMD mkdir -p "$codex_dir" "$volatile_dir"
        $DRY_RUN_CMD chmod 700 "$volatile_dir"

        for name in logs_2.sqlite logs_2.sqlite-shm logs_2.sqlite-wal; do
          link="$codex_dir/$name"
          target="$volatile_dir/$name"

          if [ -L "$link" ] && [ "$(${stable.coreutils}/bin/readlink "$link")" != "$target" ]; then
            $DRY_RUN_CMD rm -f "$link"
          fi

          if [ -e "$link" ] && [ ! -L "$link" ]; then
            $DRY_RUN_CMD rm -f "$link"
          fi

          if [ ! -L "$link" ]; then
            $DRY_RUN_CMD ln -s "$target" "$link"
          fi
        done
      '';

      codexBrowserRuntime = lib.hm.dag.entryAfter ["agentMemoryClients" "blenderMcpClient" "linkGeneration"] ''
        for plugin in browser chrome; do
          cache="$HOME/.codex/plugins/cache/openai-bundled/$plugin/${local.chatgpt.version}"
          if [ -L "$cache" ]; then
            $DRY_RUN_CMD rm "$cache"
          fi
          if [ -d "$cache" ]; then
            $DRY_RUN_CMD ${stable.coreutils}/bin/chmod -R u+w "$cache"
          fi
          $DRY_RUN_CMD mkdir -p "$cache"
          # Replace cached files so running executables keep their original inode.
          $DRY_RUN_CMD ${stable.coreutils}/bin/cp -R --remove-destination --preserve=mode --no-preserve=ownership \
            "${local.chatgpt}/lib/chatgpt/resources/plugins/openai-bundled/plugins/$plugin/." "$cache/"
          $DRY_RUN_CMD ${stable.coreutils}/bin/chmod -R u+w "$cache"
        done

        # The Browser service must resolve inside CODEX_HOME's trusted code path.
        $DRY_RUN_CMD sed -i -E \
          -e 's#/nix/store/[a-z0-9]+-chatgpt-[0-9.]+/lib/chatgpt/resources#${local.chatgpt}/lib/chatgpt/resources#g' \
          -e 's#(BROWSER_USE_CODEX_APP_VERSION = ")[^"]+#\1${local.chatgpt.version}#' \
          -e 's#/nix/store/[a-z0-9]+-chatgpt-[0-9.]+/lib/chatgpt/resources/plugins/openai-bundled/plugins/browser/scripts/browser-service.mjs#/home/david/.codex/plugins/cache/openai-bundled/browser/${local.chatgpt.version}/scripts/browser-service.mjs#g' \
          -e 's#(/home/[^/]+/[.]codex/plugins/cache/openai-bundled/browser/)[0-9.]+(/scripts/browser-service.mjs)#\1${local.chatgpt.version}\2#g' \
          "$HOME/.codex/config.toml"
      '';
    };
  };

  systemd.user.services.ydotoold = {
    Unit = {
      Description = "ydotool input injection daemon";
    };
    Service = {
      ExecStart = "${stable.ydotool}/bin/ydotoold";
      Restart = "on-failure";
    };
    Install = {
      WantedBy = ["default.target"];
    };
  };
}
