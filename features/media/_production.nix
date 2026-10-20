{
  local,
  stable,
  unstable,
  ...
}: {
  home.packages = [
    local.photorec # image recovery
    local.voiceio # Local push-to-talk voice dictation
    stable.flite # flite -f <file>; TTS Engine
    stable.gperftools # Google Performance Tools (gperftools) for profiling and performance analysis
    stable.nuclear # Music streaming app
    stable.pavucontrol # Route PipeWire/PulseAudio app streams, e.g. Friture input from output monitor
    stable.pocket-tts # Lightweight, CPU-friendly text-to-speech
    stable.pulseaudio # provides pactl for PipeWire/PulseAudio debugging
    stable.renderdoc # Graphics debugger for Vulkan, OpenGL, and Direct3D
    stable.tts # coqui-tts
    unstable.blender # 3D modeling and animation software
    unstable.friture # Real-time audio analyzer
  ];
}
