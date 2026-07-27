{
  inputs,
  pkgs,
  ...
}: let
  stable = pkgs;
  unstable = import inputs.nixpkgs-unstable {
    inherit (stable.stdenv.hostPlatform) system;
    config = stable.config // {allowUnfree = true;};
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
        value = stable.${name};
      })
      localPackageNames);
in {
  home.packages = [
    unstable.blender
    stable.nuclear
    stable.renderdoc
    # for stable-diffusion-webui
    stable.gperftools
    stable.flite # flite -f <file>; TTS Engine
    stable.tts # coqui-tts
    stable.pocket-tts # Lightweight, CPU-friendly text-to-speech
    stable.pulseaudio # provides pactl for PipeWire/PulseAudio debugging
    stable.pavucontrol # Route PipeWire/PulseAudio app streams, e.g. Friture input from output monitor

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
    local.voiceio # Local push-to-talk voice dictation
    # local.dlss-updater # disabled: its Flatpak dependency currently pulls insecure pnpm 9
    local.photorec # image recovery
    # local.pixieditor
  ];
}
