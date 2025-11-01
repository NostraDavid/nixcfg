{
  lib,
  stdenv,
  cmake,
  fetchFromGitHub,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "bitnet";
  version = "unstable-2025-06-03";

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "BitNet";
    rev = "404980eecae38affa4871c3e419eae3f44536a95";
    fetchSubmodules = true;
    hash = "sha256-bRnrjsE+WdZXAAtDISDu8qICLI70q2TFDSZyI5mzvEY=";
  };

  nativeBuildInputs = [ cmake ];

  cmakeFlags = [
    "-DLLAMA_BUILD_COMMON=ON"
    "-DLLAMA_BUILD_EXAMPLES=ON"
    "-DLLAMA_BUILD_TESTS=OFF"
  ];

  meta = {
    description = "bitnet.cpp - inference framework for 1-bit LLMs";
    homepage = "https://github.com/microsoft/BitNet";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [
      dbreyfogle
    ];
    platforms = lib.platforms.linux;
    mainProgram = "llama-cli";
  };
})
