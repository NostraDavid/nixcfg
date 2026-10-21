{
  config,
  lib,
  repoRoot,
  stable,
  ...
}: let
  dot = "${repoRoot}/dotfiles";
  mk = config.lib.file.mkOutOfStoreSymlink;
  espeak = stable.callPackage ../../pkgs/espeak-ng {};
  mbrolaNl2 = stable.mbrola-voices.override {
    languages = [
      "nl2"
    ];
  };
in {
  config = lib.mkIf stable.stdenv.hostPlatform.isDarwin {
    home.packages = [
      stable.coreutils
      stable.gnused
    ];
    home.file =
      lib.genAttrs [
        ".local/bin/say"
        ".local/bin/say-espeak-ng"
        ".local/bin/say-espeak-ng-mbrola"
        ".local/bin/say-piper-tts"
      ]
      (name: {source = mk "${dot}/ndtk/.local/bin/${builtins.baseNameOf name}.sh";})
      // {
        ".config/say/espeak-ng-data".source = "${espeak}/share/espeak-ng-data";
        ".config/say/piper.sed".source = mk "${dot}/espeak-ng-1.52.0/piper.sed";
        ".local/share/mbrola/nl2".source = "${mbrolaNl2}/data/nl2";
        ".local/share/piper-voices/nl_NL-pim-medium.onnx".source = mk "${dot}/piper-voices/nl_NL-pim-medium.onnx";
        ".local/share/piper-voices/nl_NL-pim-medium.onnx.json".source = mk "${dot}/piper-voices/nl_NL-pim-medium.onnx.json";
      };
  };
}
