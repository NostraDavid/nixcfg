{
  lib,
  writeShellApplication,
  linkFarm,
  python3,
  ffmpeg,
  gnused,
  piper-tts,
  makeFontsConf,
  dejavu_fonts,
  unstable,
}: let
  # Cairo scenes use Text and vectors, so omit Manim's bundled TeX wrapper path.
  manim = unstable.manim.overrideAttrs (old: {
    makeWrapperArgs = [];
    # Click 8.4.2 marks optional subcommands with brackets in usage text.
    postPatch =
      (old.postPatch or "")
      + ''
        substituteInPlace tests/interface/test_commands.py \
          --replace-fail 'Usage: manim init [OPTIONS] COMMAND [ARGS]...' \
            'Usage: manim init [OPTIONS] [COMMAND] [ARGS]...'
      '';
  });
  voice = linkFarm "video-piper-pim" [
    {
      name = "nl_NL-pim-medium.onnx";
      path = ../../dotfiles/piper-voices/nl_NL-pim-medium.onnx;
    }
    {
      name = "nl_NL-pim-medium.onnx.json";
      path = ../../dotfiles/piper-voices/nl_NL-pim-medium.onnx.json;
    }
  ];
  piper = piper-tts.override {
    withAlignment = false;
    withHTTP = false;
    withTrain = false;
  };
in
  (writeShellApplication {
    name = "video-explainer";
    runtimeInputs = [python3 manim piper ffmpeg gnused];
    text = ''
      export VIDEO_EXPLAINER_MODEL="''${VIDEO_EXPLAINER_MODEL:-${voice}/nl_NL-pim-medium.onnx}"
      export VIDEO_EXPLAINER_RULES="''${VIDEO_EXPLAINER_RULES:-${../../dotfiles/espeak-ng-1.52.0/piper.sed}}"
      export FONTCONFIG_FILE="''${FONTCONFIG_FILE:-${makeFontsConf {fontDirectories = [dejavu_fonts];}}}"
      exec python3 ${../../dotfiles/agents/.agents/video-explainer/scripts/render.py} "$@"
    '';
  }).overrideAttrs (_: {
    version = "1.0.0";
    passthru.updateSkipReason = "Local renderer; dependencies are updated through flake.lock";
    meta = {
      description = "Render narrated explanatory animations with Manim, Piper and FFmpeg";
      mainProgram = "video-explainer";
      platforms = ["x86_64-linux" "aarch64-darwin"];
      license = lib.licenses.mit;
    };
  })
