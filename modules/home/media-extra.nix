{
  inputs,
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
in {
  home.packages = with pkgs; [
    unstable.blender
    nuclear
    renderdoc
    # for stable-diffusion-webui
    gperftools
    flite # flite -f <file>; TTS Engine
    tts # coqui-tts
    pulseaudio # provides pactl for PipeWire/PulseAudio debugging
    pavucontrol # Route PipeWire/PulseAudio app streams, e.g. Friture input from output monitor

    # Unstable
    unstable.friture # Real-time audio analyzer
    unstable.stable-diffusion-cpp # Stable Diffusion in C++
    # unstable.vllm # High-performance inference server for large language models
    # unstable.antigravity # Google IDE
    # unstable.opencode
    # unstable.ollama-cuda # Local LLM server
    # # Zed is slow to build :/
    # (unstable.zed-editor.overrideAttrs (_: {
    #   doCheck = false;
    # })) # Zed text editor

    # local.github-copilot-cli
    # local.synology-drive-client-pinned # kaput in 25.11
    # local.vscode
    local.cool-retro-term # terminal emulator with retro style
    local.dlss-updater
    local.photorec # image recovery
    # local.pixieditor
    local.pyre
  ];
}
