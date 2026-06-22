{
  lib,
  llvmPackages_20,
  cmake,
  fetchFromGitHub,
}:
llvmPackages_20.stdenv.mkDerivation (finalAttrs: {
  pname = "bitnet";
  version = "unstable-2026-03-10";

  src = fetchFromGitHub {
    owner = "microsoft";
    repo = "BitNet";
    rev = "01eb415772c342d9f20dc42772f1583ae1e5b102";
    fetchSubmodules = true;
    hash = "sha256-piKVvE0m6b9N9UNIMp8gHibEwmTT08RCbu4YWoqqaIQ=";
  };

  nativeBuildInputs = [
    cmake
    llvmPackages_20.clang
    llvmPackages_20.lld
  ];

  postPatch = ''
    substituteInPlace src/ggml-bitnet-lut.cpp \
      --replace-fail '#include "bitnet-lut-kernels.h"' $'#include <immintrin.h>\n#include "bitnet-lut-kernels.h"'

    if grep -qF 'int8_t * y_col = y + col * by;' src/ggml-bitnet-mad.cpp; then
      substituteInPlace src/ggml-bitnet-mad.cpp \
        --replace-fail 'int8_t * y_col = y + col * by;' 'const int8_t * y_col = y + col * by;'
    fi
  '';

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
    "-DGGML_NATIVE=OFF"
    "-DBITNET_X86_TL2=ON"
  ];

  passthru.updateScript = ../../cmd/update-bitnet.sh;

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
