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
  interpreters = builtins.filter (name: builtins.hasAttr name prev) [
    "python310"
    "python311"
    "python312"
    "python313"
    "python314"
    "python315"
  ];
  fixPython = name: {
    inherit name;
    value = (prev.${name}.override {self = final.${name};}).overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          current=$(sed -n 's/^_PIP_VERSION = "\([^"]*\)"/\1/p' Lib/ensurepip/__init__.py)
          test -n "$current"
          if [ "$(printf '%s\n' "$current" 26.2.2 | sort -V | head -n1)" != 26.2.2 ]; then
            rm Lib/ensurepip/_bundled/pip-*.whl
            cp ${pipWheel} Lib/ensurepip/_bundled/pip-26.2.2-py3-none-any.whl
            substituteInPlace Lib/ensurepip/__init__.py \
              --replace-fail "_PIP_VERSION = \"$current\"" '_PIP_VERSION = "26.2.2"'
          fi
        '';
    });
  };
  uvAssets = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-V++dnMsB+xvZmN+ZWw3SIbUvfXhB++qT8tRGO/Yft6k=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-eQbHmtshyBq9VZhBuna7HZr515GsrHoEGyly4DrhZTg=";
    };
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-dD+FA1oZluyzUGWeAc2frqlwmCm+CbG0sDxz6vPJzXM=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-sPUrDjlFtBB9iQJOo45iVoMBH7/AWg2Y+fotbc7ijGY=";
    };
  };
  uvAsset = uvAssets.${prev.stdenv.hostPlatform.system};
in
  builtins.listToAttrs (map fixPython interpreters)
  // {
    cacert = prev.cacert.override {blacklist = import ./ca-blacklist.nix prev.cacert.version;};
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
    uv =
      if lib.versionAtLeast prev.uv.version "0.13.5"
      then prev.uv
      else
        prev.stdenvNoCC.mkDerivation {
          pname = "uv";
          version = "0.13.5";
          src = prev.fetchurl {
            url = "https://github.com/astral-sh/uv/releases/download/0.13.5/uv-${uvAsset.target}.tar.gz";
            inherit (uvAsset) hash;
          };
          dontBuild = true;
          nativeBuildInputs = [prev.installShellFiles];
          installPhase = ''
            runHook preInstall
            install -Dm755 uv uvx -t "$out/bin"
            installShellCompletion --cmd uv \
              --bash <("$out/bin/uv" generate-shell-completion bash) \
              --fish <("$out/bin/uv" generate-shell-completion fish) \
              --zsh <("$out/bin/uv" generate-shell-completion zsh)
            runHook postInstall
          '';
          doInstallCheck = true;
          installCheckPhase = ''
            "$out/bin/uv" --version | grep -F 'uv 0.13.5'
            "$out/bin/uvx" --version | grep -F 'uvx 0.13.5'
          '';
          meta =
            prev.uv.meta
            // {
              platforms = builtins.attrNames uvAssets;
              sourceProvenance = [lib.sourceTypes.binaryNativeCode];
            };
        };
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
