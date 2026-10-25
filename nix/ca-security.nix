# Remove these backports when every pinned channel contains the security releases.
final: prev: let
  inherit (prev) lib;
  # Documentation builds are offline; reuse the channel's tested native tools.
  documentation = import prev.path {
    system = prev.stdenv.buildPlatform.system;
    config = {};
    overlays = [];
  };
  pipWheel = prev.fetchurl {
    url = "https://files.pythonhosted.org/packages/3f/06/3e4420302363fbb71be3c7f35ce042f54bfca330e3e66b3a2e3c4cca579f/pip-26.2.2-py3-none-any.whl";
    hash = "sha256-/X9N+oGQ4BQBO58I8+lz9OTCb/0XmiBIlVM6clSBOnA=";
  };
in {
  # Keep build interpreters unchanged; only the user's Python needs new seeds.
  python3Ca =
    prev.runCommand "${prev.python3.name}-ca" {
      passthru = {
        inherit (prev.python3) version pythonVersion executable;
        interpreter = "${final.python3Ca}/bin/${prev.python3.executable}";
      };
      inherit (prev.python3) meta;
    } ''
      cp -a ${prev.python3} "$TMPDIR/python"
      chmod -R u+w "$TMPDIR/python"
      ensurepip="$TMPDIR/python/lib/python${prev.python3.pythonVersion}/ensurepip"
      current=$(sed -n 's/^_PIP_VERSION = "\([^"]*\)"/\1/p' "$ensurepip/__init__.py")
      test -n "$current"
      if [ "$(printf '%s\n' "$current" 26.2.2 | sort -V | head -n1)" != 26.2.2 ]; then
        rm "$ensurepip"/_bundled/pip-*.whl
        cp ${pipWheel} "$ensurepip/_bundled/pip-26.2.2-py3-none-any.whl"
        substituteInPlace "$ensurepip/__init__.py" \
          --replace-fail "_PIP_VERSION = \"$current\"" '_PIP_VERSION = "26.2.2"'
        rm -rf "$ensurepip/__pycache__"
      fi
      mv "$TMPDIR/python" "$out"
    '';
  cacert =
    if lib.versionAtLeast prev.cacert.version "3.131.1"
    then prev.cacert
    else prev.cacert.override {blacklist = import ./ca-blacklist.nix prev.cacert.version;};
  pythonPackagesExtensions =
    prev.pythonPackagesExtensions
    ++ [
      (_pyFinal: pyPrev: let
        nativeDocumentation = documentation.${"python${lib.replaceStrings ["."] [""] pyPrev.python.pythonVersion}Packages"};
      in {
        virtualenv =
          if lib.versionOlder pyPrev.python.version "3.10"
          then pyPrev.virtualenv
          else
            pyPrev.virtualenv.overridePythonAttrs (old: {
              postPatch =
                (old.postPatch or "")
                + ''
                  ${prev.python3.interpreter} ${../scripts/repair-python-ca.py} --apply src/virtualenv/seed/wheels/embed
                  find src/virtualenv/seed/wheels/embed -name '*.before-emudhra' -delete
                '';
            });
        pip =
          if lib.versionOlder pyPrev.python.version "3.10" || lib.versionAtLeast pyPrev.pip.version "26.2.2"
          then pyPrev.pip
          else
            (pyPrev.pip.override {
              inherit (nativeDocumentation) sphinx sphinx-issues;
            }).overridePythonAttrs (_old: {
              version = "26.2.2";
              src = prev.fetchzip {
                url = "https://files.pythonhosted.org/packages/fa/e8/0842d757e483e895e670f655084cfe8b8c72580c6769a76b30b2789a0608/pip-26.2.2.tar.gz";
                hash = "sha256-tYr0HbHfpE6jbz5+s/O+P+ry9IqvMlZBYEFmQkPMv4g=";
              };
            });
      })
    ];
  uv = prev.callPackage ../pkgs/uv {};
  nodejs-slim_24 =
    if lib.versionAtLeast prev.nodejs-slim_24.version "24.22.1"
    then prev.nodejs-slim_24
    else
      (prev.nodejs-slim_24.override {
        callPackage = prev.newScope {
          # Node 24.22.1 needs the same decoder fix already used by Node 26.
          brotli = prev.brotli.overrideAttrs (old: {
            patches =
              (old.patches or [])
              ++ [
                (prev.fetchurl {
                  url = "https://github.com/google/brotli/commit/0ed4268a4401abcb4472096340477cf4af7d1a2b.patch?full_index=1";
                  hash = "sha256-1vliUJAAIj3vcGKVgim9CEV+XgMuftDR2U+3kLBUsfw=";
                })
              ];
          });
        };
      }).overrideAttrs (_old: {
        version = "24.22.1";
        src = prev.fetchurl {
          url = "https://nodejs.org/dist/v24.22.1/node-v24.22.1.tar.xz";
          hash = "sha256-T1N5eWKAza6wwvNY/QS2oWzE+336g7WoyRqdljtDUjE=";
        };
      });
}
