_: {
  den.aspects.common-tooling = {
    homeManager = {
      config,
      stable,
      lib,
      local,
      unstable,
      ...
    }: let
      asdSte100 = stable.callPackage ../../pkgs/asd-ste100-skill {};
      todoTree = stable.callPackage ../../pkgs/vscode-todo-tree {
        inherit (unstable) vscode-extensions;
      };
    in {
      home = {
        activation = {
          linkPackageCommands = lib.hm.dag.entryAfter ["installPackages" "linkGeneration"] ''
            $DRY_RUN_CMD ${stable.bash}/bin/bash ${./link-package-commands.sh} \
              ${lib.escapeShellArg config.home.profileDirectory} \
              ${lib.escapeShellArg "${config.home.homeDirectory}/.local/bin"}
          '';
          vscodeExtensions = lib.hm.dag.entryAfter ["linkPackageCommands"] ''
            vscode_cli=""
            for candidate in ${lib.escapeShellArg "${config.home.profileDirectory}/bin/code"} \
                "$HOME/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
                "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" \
                /run/current-system/sw/bin/code /usr/bin/code /usr/local/bin/code; do
              if [ -x "$candidate" ]; then
                vscode_cli="$candidate"
                break
              fi
            done
            if [ -n "$vscode_cli" ]; then
              for extension in dprint.dprint mkhl.shfmt; do
                if ! $DRY_RUN_CMD "$vscode_cli" --list-extensions 2>/dev/null \
                    | ${lib.getExe stable.gnugrep} -Fx "$extension" >/dev/null 2>&1; then
                  if ! $DRY_RUN_CMD "$vscode_cli" --install-extension "$extension"; then
                    echo "warning: failed to install VS Code extension $extension" >&2
                  fi
                fi
              done
              $DRY_RUN_CMD "$vscode_cli" --install-extension ${todoTree} --force \
                || echo "warning: failed to install Todo Tree's native path patch" >&2
              if $DRY_RUN_CMD "$vscode_cli" --list-extensions 2>/dev/null \
                  | ${lib.getExe stable.gnugrep} -Fx 'foxundermoon.shell-format' >/dev/null 2>&1 \
                  && $DRY_RUN_CMD "$vscode_cli" --list-extensions 2>/dev/null \
                  | ${lib.getExe stable.gnugrep} -Fx 'mkhl.shfmt' >/dev/null 2>&1; then
                $DRY_RUN_CMD "$vscode_cli" --uninstall-extension foxundermoon.shell-format \
                  || echo "warning: failed to remove the replaced Shell Format extension" >&2
              fi
            fi
          '';
        };
        file = lib.genAttrs [
          ".agents/skills/asd-ste100"
          ".claude/skills/asd-ste100"
          ".codex/skills/asd-ste100"
          ".config/opencode/skills/asd-ste100"
          ".copilot/skills/asd-ste100"
          ".pi/agent/skills/asd-ste100"
        ] (_: {source = "${asdSte100}/asd-ste100";});
        packages = with unstable; [
          actionlint
          flameshot
          fast-resume
          hurl
          just
          just-lsp
          lazyjournal
          lnav
          nix-index
          nix-tree
          nvd
          ov
          posting
          shfmt
          sqruff
          watchexec
          zellij
          local.espeak-ng
          (stable.piper-tts.override {
            withAlignment = false;
            withHTTP = false;
            withTrain = false;
          })
        ];
      };
    };
  };
}
