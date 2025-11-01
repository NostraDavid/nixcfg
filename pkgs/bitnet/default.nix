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

  preConfigure = ''
    rm -f include/bitnet-lut-kernels.h
    ln -s ../preset_kernels/bitnet_b1_58-large/bitnet-lut-kernels-tl2.h include/bitnet-lut-kernels.h
    rm -f 3rdparty/llama.cpp/ggml/include/ggml-bitnet.h
    ln -s ../../../../include/ggml-bitnet.h 3rdparty/llama.cpp/ggml/include/ggml-bitnet.h
  '';

  postConfigure = ''
    ln -sf 3rdparty/llama.cpp/LlamaConfig.cmake LlamaConfig.cmake
    ln -sf 3rdparty/llama.cpp/LlamaConfigVersion.cmake LlamaConfigVersion.cmake
  '';

  cmakeFlags = [
    "-DLLAMA_BUILD_COMMON=ON"
    "-DLLAMA_BUILD_EXAMPLES=ON"
    "-DLLAMA_BUILD_TESTS=OFF"
    "-DBITNET_X86_TL2=ON"
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
