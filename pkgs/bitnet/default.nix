{
  lib,
  llvmPackages_20,
  cmake,
  fetchFromGitHub,
}:

llvmPackages_20.stdenv.mkDerivation (finalAttrs: {
  pname = "bitnet";
  version = "unstable-2025-06-03";

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "BitNet";
    rev = "404980eecae38affa4871c3e419eae3f44536a95";
    fetchSubmodules = true;
    hash = "sha256-bRnrjsE+WdZXAAtDISDu8qICLI70q2TFDSZyI5mzvEY=";
  };

  nativeBuildInputs = [
    cmake
    llvmPackages_20.clang
    llvmPackages_20.lld
  ];

  preConfigure = ''
    rm -f include/bitnet-lut-kernels.h
    ln -s ../preset_kernels/bitnet_b1_58-large/bitnet-lut-kernels-tl2.h include/bitnet-lut-kernels.h
    rm -f 3rdparty/llama.cpp/ggml/include/ggml-bitnet.h
    ln -s ../../../../include/ggml-bitnet.h 3rdparty/llama.cpp/ggml/include/ggml-bitnet.h
    # Provide llama.h at the project root so CMake install succeeds
    cp 3rdparty/llama.cpp/include/llama.h llama.h
  '';

  # Upstream install target expects a generated LlamaConfig.cmake that is
  # currently missing, so provide a minimal stub so the install phase succeeds.
  preBuild = ''
    cat > LlamaConfig.cmake <<'EOF'
get_filename_component(_LLAMA_PREFIX "''${CMAKE_CURRENT_LIST_DIR}/.." ABSOLUTE)
set(Llama_INCLUDE_DIR "''${_LLAMA_PREFIX}/include")
set(Llama_LIBRARY "''${_LLAMA_PREFIX}/lib/libggml.so")
set(Llama_LIBRARIES "''${Llama_LIBRARY}")
set(Llama_FOUND TRUE)
EOF
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
