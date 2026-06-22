{
  lib,
  fetchFromGitHub,
  makeWrapper,
  python3,
  stdenvNoCC,
}: let
  python = python3.withPackages (ps:
    with ps; [
      charset-normalizer
      psutil
      pymupdf
      python-docx
      python-pptx
      tiktoken
    ]);
in
  stdenvNoCC.mkDerivation {
    pname = "doctok";
    version = "0-unstable-2026-05-29";

    src = fetchFromGitHub {
      owner = "Pranesh-2005";
      repo = "Token-Calculator";
      rev = "b43f0f9cad6618880ce833d49072142a56c75cfa";
      hash = "sha256-lC5jO5JHpnnNKHZn2rIQn0dj1t5Lkif5VFQ5CWvxR7Q=";
    };

    nativeBuildInputs = [makeWrapper];

    installPhase = ''
      runHook preInstall

      install -Dm644 core.py "$out/share/doctok/core.py"
      makeWrapper ${python}/bin/python "$out/bin/doctok" \
        --add-flags "$out/share/doctok/core.py"

      runHook postInstall
    '';

    meta = {
      description = "Count GPT tokens in PDF, TXT, DOCX, Markdown, and PPTX files";
      homepage = "https://github.com/Pranesh-2005/Token-Calculator";
      license = lib.licenses.mit;
      mainProgram = "doctok";
      platforms = lib.platforms.all;
    };
  }
