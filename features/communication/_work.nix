{
  stable,
  local,
  ...
}: let
  piperTts = stable.piper-tts.override {
    withAlignment = false;
    withHTTP = false;
    withTrain = false;
  };
in {
  home.packages = [
    stable.slack # Work chat; intentionally excluded from lean workstations
    local.espeak-ng # Includes the compiled pronunciation dictionary
    piperTts # Neural speech synthesis for say-piper-tts
  ];
}
