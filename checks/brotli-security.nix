{pkgs}: let
  inherit (pkgs) lib;
  brotli = pkgs.brotliPatched;
in
  pkgs.runCommand "brotli-security-check" {
    nativeBuildInputs = [pkgs.python3 pkgs.stdenv.cc];
    BROTLI_LIBRARY = "${lib.getLib brotli}/lib/libbrotlidec${pkgs.stdenv.hostPlatform.extensions.sharedLibrary}";
    BROTLI_CLI = lib.getExe brotli;
  } ''
    python3 ${./test-brotli-security.py}
    ${lib.getExe pkgs.bun} ${./test-brotli-runtime.mjs}
    brotli_src=${pkgs.duckdb.src}/third_party/brotli
    $CXX -shared -fPIC -O2 -I"$brotli_src/include" \
      "$brotli_src"/common/*.cpp "$brotli_src"/dec/*.cpp \
      ${./duckdb-brotli-ffi.cpp} -o duckdb-brotli.so
    BROTLI_LIBRARY="$PWD/duckdb-brotli.so" python3 ${./test-brotli-security.py}
    touch "$out"
  ''
