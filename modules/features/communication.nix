{config, ...}: {
  flake.modules = {
    nixos.communication = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.communication
      ];
    };
    nixos.work-communication = {main-user, ...}: {
      home-manager.users.${main-user}.imports = [
        config.flake.modules.homeManager.work-communication
      ];
    };
    homeManager.communication = ../home/communication.nix;
    homeManager.work-communication = {
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
        local.say-dictionary.speechEngine # Matches the compiled pronunciation dictionary
        piperTts # Neural speech synthesis for say-piper-tts
      ];
    };
  };
}
