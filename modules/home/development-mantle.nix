{
  config,
  inputs,
  lib,
  pkgs,
  ...
}: let
  unstable = import inputs.nixpkgs-unstable {
    inherit (pkgs.stdenv.hostPlatform) system;
    config = pkgs.config // {allowUnfree = true;};
  };
  inherit (builtins) attrNames filter listToAttrs map readDir;
  localPackageNames = let
    entries = readDir ../../pkgs;
  in
    filter (name: entries.${name} == "directory") (attrNames entries);
  local =
    listToAttrs
    (map (name: {
        inherit name;
        value = pkgs.${name};
      })
      localPackageNames);
  piExe = lib.getExe config.programs.pi.coding-agent.finalPackage;
in {
  programs.pi.coding-agent.enable = true;

  xdg.desktopEntries.code = {
    name = "Visual Studio Code";
    genericName = "Text Editor";
    comment = "Code Editing. Redefined.";
    exec = "${config.home.homeDirectory}/.local/bin/code %F";
    icon = "vscode";
    terminal = false;
    type = "Application";
    categories = ["Utility" "TextEditor" "Development" "IDE"];
    startupNotify = true;
    settings = {
      StartupWMClass = "Code";
      Actions = "new-empty-window";
      Keywords = "vscode";
    };
    actions.new-empty-window = {
      name = "New Empty Window";
      icon = "vscode";
      exec = "${lib.getExe local.vscode} --new-window %F";
    };
  };

  home.packages = with pkgs; [
    # Language runtimes and additional development applications.
    jdk17 # openjdk for nvim-lsp-java
    zed-editor # vscode alternative

    # unstable
    unstable.gemini-cli
    # unstable.github-copilot-cli
    unstable.oxfmt # prettier replacement
    unstable.oxlint # js linter
    unstable.fastfetch # neofetch alternative
    unstable.zigfetch # neofetch alternative
    unstable.devenv # Development environment manager | using unstable for 2.x
    # unstable.codex # Code autocompletion tool
    unstable.witr # Why is this running?
    unstable.zsv # CSV viewer and slicer
    unstable.opencode # codex-cli alternative
    unstable.ctx7 # Context7 CLI - Manage AI coding skills and documentation context

    # local
    freetype # font-rendering library, for Whatpulse
    libpcap # for Whatpulse
    local.jpegli
    local.fixit
    local.mdschema
    local.whatpulse
    local.yafc
    local.xdgctl
    local.vscode
    local.jsongrep # JSONPath-inspired query language over JSON documents
    local.austin # CPython frame stack sampler
    local.semble # Fast code search for agents
    local.dpaint-js
    local.doctok
    local.tiktoken
    local.ptk
    local.photogimp # Photoshop-like defaults for GIMP
    local.hermes-agent
    local.github-copilot-cli
    local.snip # CLI proxy, to reduce token usage for LLMs
    local.rtk
    local.codealmanac # Local codebase wiki for AI coding agents
    local.skillkit # Local codebase wiki for AI coding agents
  ];

  home.activation.piTensorx = lib.hm.dag.entryAfter ["writeBoundary"] ''
    if ! $DRY_RUN_CMD ${piExe} list 2>/dev/null \
      | ${lib.getExe pkgs.gnugrep} -F '@czottmann/pi-tensorx' >/dev/null 2>&1; then
      if ! $DRY_RUN_CMD ${piExe} install npm:@czottmann/pi-tensorx; then
        echo "warning: failed to install Pi extension @czottmann/pi-tensorx" >&2
      fi
    fi
  '';
}
