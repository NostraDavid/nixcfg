{
  lib,
  stdenv,
  stdenvAdapters,
  rustPlatform,
  fetchurl,
  fetchFromGitHub,
  installShellFiles,
  clang,
  cmake,
  coreutils,
  curl,
  gitMinimal,
  libclang,
  libcap,
  makeWrapper,
  nix-update-script,
  pkg-config,
  openssl,
  ripgrep,
  versionCheckHook,
  installShellCompletions ? stdenv.buildPlatform.canExecute stdenv.hostPlatform,
}: let
  effectiveStdenv =
    if stdenv.hostPlatform.isLinux
    then stdenvAdapters.useMoldLinker stdenv
    else stdenv;
  rustyV8Archive =
    if stdenv.hostPlatform.system == "x86_64-linux"
    then
      fetchurl {
        url = "https://github.com/denoland/rusty_v8/releases/download/v149.2.0/librusty_v8_release_x86_64-unknown-linux-gnu.a.gz";
        hash = "sha256-iu2YY323533Iv7i7R1nsW95HLQv3lD9Y4OYqNQlFxVk=";
      }
    else if stdenv.hostPlatform.system == "aarch64-darwin"
    then
      fetchurl {
        url = "https://github.com/denoland/rusty_v8/releases/download/v149.2.0/librusty_v8_release_aarch64-apple-darwin.a.gz";
        hash = "sha256-hQ2J1b0Z9AOfa4x4g8Rv+dG8fV7fW24Qv2jq3u5M5o4=";
      }
    else throw "Unsupported system for codex rusty_v8 archive: ${stdenv.hostPlatform.system}";
in
  (rustPlatform.buildRustPackage.override {stdenv = effectiveStdenv;}) (finalAttrs: {
    pname = "codex";
    version = "0.143.0";

    src = fetchFromGitHub {
      owner = "openai";
      repo = "codex";
      tag = "rust-v${finalAttrs.version}";
      hash = "sha256-4xJcE8/lFwp1r/J8z7HMb7A59WXkj3rtm9QDtjJfC04=";
    };

    sourceRoot = "${finalAttrs.src.name}/codex-rs";

    cargoLock = {
      lockFile = "${finalAttrs.src}/codex-rs/Cargo.lock";
      outputHashes = {
        "crossterm-0.28.1" = "sha256-6qCtfSMuXACKFb9ATID39XyFDIEMFDmbx6SSmNe+728=";
        "libwebrtc-0.3.26" = "sha256-0HPuwaGcqpuG+Pp6z79bCuDu/DyE858VZSYr3DKZD9o=";
        "nucleo-0.5.0" = "sha256-Hm4SxtTSBrcWpXrtSqeO0TACbUxq3gizg1zD/6Yw/sI=";
        "ratatui-0.29.0" = "sha256-HBvT5c8GsiCxMffNjJGLmHnvG77A6cqEL+1ARurBXho=";
        "runfiles-0.1.0" = "sha256-uJpVLcQh8wWZA3GPv9D8Nt43EOirajfDJ7eq/FB+tek=";
        "tokio-tungstenite-0.28.0" = "sha256-V1xmnrfRWOcZZogelZEA4vvyMj2awCfHVA5/glQ6KAI=";
        "tungstenite-0.27.0" = "sha256-VVHhk7l9J/sEmG3q/UuV/sQ3f+fGsmq5vumSy8vbMvw=";
      };
    };

    nativeBuildInputs = [
      clang
      cmake
      curl
      gitMinimal
      installShellFiles
      makeWrapper
      pkg-config
    ];

    buildInputs = [
      libclang
      libcap
      openssl
    ];

    # NOTE: set LIBCLANG_PATH so bindgen can locate libclang, and adjust
    # warning-as-error flags to avoid known false positives (GCC's
    # stringop-overflow in BoringSSL's a_bitstr.cc) while keeping Clang's
    # character-conversion warning-as-error disabled.
    env = {
      LIBCLANG_PATH = "${lib.getLib libclang}/lib";
      RUSTY_V8_ARCHIVE = rustyV8Archive;
      NIX_CFLAGS_COMPILE = toString (
        lib.optionals stdenv.cc.isGNU [
          "-Wno-error=stringop-overflow"
        ]
        ++ lib.optionals stdenv.cc.isClang [
          "-Wno-error=character-conversion"
        ]
      );
    };

    # NOTE: part of the test suite requires access to networking, local shells,
    # apple system configuration, etc. since this is a very fast moving target
    # (for now), with releases happening every other day, constantly figuring out
    # which tests need to be skipped, or finding workarounds, was too burdensome,
    # and in practice not adding any real value. this decision may be reversed in
    # the future once this software stabilizes.
    doCheck = false;

    postInstall = lib.optionalString installShellCompletions ''
      installShellCompletion --cmd codex \
        --bash <($out/bin/codex completion bash) \
        --fish <($out/bin/codex completion fish) \
        --zsh <($out/bin/codex completion zsh)
    '';

    postFixup = ''
      wrapProgram $out/bin/codex \
        --run 'volatile_dir="/tmp/$USER-codex"; ${coreutils}/bin/install -d -m 700 "$volatile_dir"' \
        --prefix PATH : ${lib.makeBinPath [ripgrep]}
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];

    passthru = {
      updateScript = nix-update-script {
        extraArgs = [
          "--flake"
          "--version"
          "unstable"
          "--version-regex"
          "^rust-v(\\d+\\.\\d+\\.\\d+)$"
        ];
      };
    };

    meta = {
      description = "Lightweight coding agent that runs in your terminal";
      homepage = "https://github.com/openai/codex";
      changelog = "https://raw.githubusercontent.com/openai/codex/refs/tags/rust-v${finalAttrs.version}/CHANGELOG.md";
      license = lib.licenses.asl20;
      mainProgram = "codex";
      maintainers = with lib.maintainers; [
        malo
        delafthi
      ];
      platforms = lib.platforms.unix;
    };
  })
