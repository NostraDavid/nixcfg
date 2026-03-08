{
  fetchurl,
  lib,
  pkg-config,
  stdenv,
  libpcap,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "whatpulse-pcap-service";
  version = "1.4.0";

  src = fetchurl {
    url = "https://github.com/whatpulse/linux-external-pcap-service/releases/download/v${finalAttrs.version}/whatpulse-pcap-service-${finalAttrs.version}-source.tar.gz";
    hash = "sha256-yPwvQnvnQtnScsDwKayB+WgIl8rTwljfNJ84Fl9grtM=";
  };

  nativeBuildInputs = [pkg-config];
  buildInputs = [libpcap];

  sourceRoot = ".";

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
