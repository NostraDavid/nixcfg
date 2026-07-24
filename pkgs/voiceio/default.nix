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
    version = "0.9.10";
    pyproject = true;

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/40/c6/811a51c8c5ea1c184a3ca06ea2257360e22f8f84a3e589740e245920bd36/python_voiceio-${version}.tar.gz";
      hash = "sha256-ZeqcY8B4/+WD4AAKMs8YwMcYBDCqbQ5dzXYzhtfgUkE=";
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
