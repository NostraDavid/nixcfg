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
    version = "0.9.11";
    pyproject = true;

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/45/20/8f44cd8457497b228c5b83338ca1dff00c52c4cba727a8d5b780a6472155/python_voiceio-0.9.11.tar.gz";
      hash = "sha256-ab94xyEOlRZLeLawSC4bt/4uKGvxkUmwuWN4oISeN/0=";
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

    postPatch = ''
      substituteInPlace voiceio/typers/ibus.py \
        --replace-fail 'for path in ("/usr/bin/python3", "/usr/bin/python"):' \
          'for path in ("${systemPython}/bin/python3",):' \
        --replace-fail 'return "/usr/bin/python3"' \
          'return "${systemPython}/bin/python3"'
      substituteInPlace voiceio/tray/__init__.py \
        --replace-fail 'for py in ["/usr/bin/python3"]:' \
          'for py in ["${systemPython}/bin/python3"]:' \
        --replace-fail 'if not shutil.which("/usr/bin/python3"):' \
          'if not shutil.which("${systemPython}/bin/python3"):'
    '';

    postFixup = ''
      wrapProgram $out/bin/voiceio \
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
