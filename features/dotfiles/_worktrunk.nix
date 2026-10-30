{
  config,
  lib,
  repoRoot,
  stable,
  unstable,
  ...
}: let
  codexPlugin = stable.runCommand "worktrunk-codex-plugin" {} ''
    cp -R ${unstable.worktrunk.src}/plugins/worktrunk "$out"
    chmod -R u+w "$out"
    rm -r "$out/skills/wt-switch-create"
  '';
  skill =
    stable.runCommand "worktrunk-skill" {
      nativeBuildInputs = [
        (stable.python3.withPackages (ps: [
          ps.pyyaml
        ]))
      ];
    } ''
      cp -R ${unstable.worktrunk}/share/skills/worktrunk/worktrunk "$out"
      chmod -R u+w "$out"
      python ${./skill-descriptions.py} ${../../dotfiles/agents/descriptions.json} "$out"
    '';
in {
  home = {
    packages = [
      unstable.worktrunk
    ];
    file =
      (lib.genAttrs [
        ".agents/skills/worktrunk"
        ".codex/skills/worktrunk"
        ".copilot/skills/worktrunk"
        ".config/opencode/skills/worktrunk"
        ".pi/agent/skills/worktrunk"
      ] (_: {source = skill;}))
      // {
        ".config/worktrunk/config.toml".source = config.lib.file.mkOutOfStoreSymlink "${repoRoot}/dotfiles/worktrunk-0.80.0/.config/worktrunk/config.toml";
        ".config/opencode/plugins/worktrunk.ts".source = "${unstable.worktrunk.src}/dev/opencode-plugin.ts";
        "plugins/worktrunk".source = codexPlugin;
      };
    activation.worktrunkCodex = lib.hm.dag.entryAfter ["linkGeneration"] ''
      $DRY_RUN_CMD ${stable.python3}/bin/python ${./worktrunk-marketplace.py} ${lib.escapeShellArg config.home.homeDirectory}
      if ! $DRY_RUN_CMD ${unstable.codex}/bin/codex plugin add worktrunk@personal --json >/dev/null 2>&1; then
        echo "warning: failed to install Codex plugin worktrunk" >&2
      fi
    '';
  };
}
