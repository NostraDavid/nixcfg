{
  fetchFromGitHub,
  lib,
  pkg-config,
  stdenv,
  libpcap,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "whatpulse-pcap-service";
  version = "1.5.2";

  src = fetchFromGitHub {
    owner = "whatpulse";
    repo = "linux-external-pcap-service";
    rev = "v${finalAttrs.version}";
    hash = "sha256-ih0Jz6gzgVsLK8szT5ouTKT9fEsA9Iy4PTiQCh3vDVQ=";
  };

  nativeBuildInputs = [pkg-config];
  buildInputs = [libpcap];

  buildPhase = ''
    runHook preBuild

    make

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 whatpulse-pcap-service $out/bin/whatpulse-pcap-service

    runHook postInstall
  '';

  meta = {
    description = "External packet capture service for WhatPulse on Linux";
    homepage = "https://github.com/whatpulse/linux-external-pcap-service";
    changelog = "https://github.com/whatpulse/linux-external-pcap-service/releases/tag/v${finalAttrs.version}";
    license = lib.licenses.gpl3Only;
    mainProgram = "whatpulse-pcap-service";
    platforms = lib.platforms.linux;
    maintainers = [];
  };
})
