{
  at-spi2-core,
  fetchurl,
  gdk-pixbuf,
  gobject-introspection,
  gtk3,
  harfbuzz,
  ibus,
  lib,
  libayatana-appindicator,
  libnotify,
  makeWrapper,
  pango,
  procps,
  python3Packages,
  wl-clipboard,
  wrapGAppsHook3,
  wtype,
  xclip,
  xdotool,
  ydotool,
}: let
  pythonDependencies = with python3Packages; [
    evdev
    faster-whisper
    numpy
    onnxruntime
    pillow
    pygobject3
    pynput
    pystray
    sounddevice
    wordfreq
  ];
  systemPython = python3Packages.python.withPackages (_: pythonDependencies);
in
  python3Packages.buildPythonApplication rec {
    pname = "python-voiceio";
    version = "1.9.2";
    pyproject = true;

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/ef/08/b97ddaee353a046730a626a1aca576fdd3215dd4823316a0babb8e36bb83/python_voiceio-1.9.2.tar.gz";
      hash = "sha256-siAHL46EoEcvPwnMPvUAgtyxzYMoifAjbYYBIS5rNw8=";
    };

    build-system = with python3Packages; [
      setuptools
      wheel
    ];

    dependencies = pythonDependencies;

    nativeBuildInputs = [
      makeWrapper
      wrapGAppsHook3
    ];
    buildInputs = [
      gobject-introspection
      gtk3
      ibus
      libayatana-appindicator
    ];
    pythonImportsCheck = ["voiceio"];

    postFixup = ''
      wrapProgram $out/bin/voiceio \
        --set-default VOICEIO_SYSTEM_PYTHON ${systemPython}/bin/python3 \
        --prefix PATH : ${
        lib.makeBinPath [
          ibus
          libnotify
          procps
          systemPython
          wl-clipboard
          wtype
          xclip
          xdotool
          ydotool
        ]
      } \
        --prefix GI_TYPELIB_PATH : ${
        lib.makeSearchPath "lib/girepository-1.0" [
          at-spi2-core
          gdk-pixbuf
          gobject-introspection
          gtk3
          harfbuzz
          ibus
          libayatana-appindicator
          pango.out
        ]
      }
    '';

    meta = {
      description = "Local push-to-talk voice dictation for Linux";
      homepage = "https://github.com/Hugo0/voiceio";
      changelog = "https://github.com/Hugo0/voiceio/releases/tag/v${version}";
      license = lib.licenses.mit;
      mainProgram = "voiceio";
      platforms = lib.platforms.linux;
    };
  }
