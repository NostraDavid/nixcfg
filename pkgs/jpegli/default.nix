{
  lib,
  stdenv,
  brotli,
  cmake,
  ninja,
  patchelf,
  pkg-config,
  libhwy,
  lcms2,
  libpng,
  zlib,
  fetchFromGitHub,
  fetchzip,
}: let
  version = "unstable-2026-06-01";
  libjpegTurboVersion = "3.2.0";
  libjpegTurboSrc = fetchzip {
    url = "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${libjpegTurboVersion}/libjpeg-turbo-${libjpegTurboVersion}.tar.gz";
    hash = "sha256-SPxWCDt9hFQ8uRaaKLkpWp9oPhfcRkDBm5MarTgdmV4=";
  };
  sjpegSrc = fetchFromGitHub {
    owner = "webmproject";
    repo = "sjpeg";
    rev = "94e0df6d0f8b44228de5be0ff35efb9f946a13c9";
    hash = "sha256-bXZG3Batuqeh7v7WPu0baMALeWV3PA2wqzBU9fJMuqc=";
  };
  src = fetchFromGitHub {
    owner = "google";
    repo = "jpegli";
    # Upstream jpegli does not publish version tags.
    rev = "031a0077f5799a6041004267fc12b956c1f52a20";
    # Submodule fetch via git intermittently fails while pruning .git metadata;
    # the GitHub source archive is sufficient with our system-lib cmake flags.
    fetchSubmodules = false;
    # To get the hash:
    # nix store prefetch-file --unpack https://github.com/google/jpegli/archive/REPLACE_WITH_COMMIT.tar.gz
    hash = "sha256-caDC6eevDu5PETQOKPQMx90ZeGzUi5HBl2Xn1a06NSs=";
  };
in
  stdenv.mkDerivation {
    pname = "jpegli";
    inherit version src;

    nativeBuildInputs = [
      cmake
      ninja
      patchelf
      pkg-config
    ];

    buildInputs = [
      brotli
      libhwy
      lcms2
      libpng
      zlib
    ];

    cmakeFlags = [
      "-DBUILD_TESTING=OFF"
      "-DJPEGXL_ENABLE_BENCHMARK=OFF"
      "-DJPEGXL_ENABLE_DEVTOOLS=OFF"
      "-DJPEGXL_ENABLE_DOXYGEN=OFF"
      "-DJPEGXL_ENABLE_FUZZERS=OFF"
      "-DJPEGXL_ENABLE_JNI=OFF"
      "-DJPEGXL_ENABLE_MANPAGES=OFF"
      "-DJPEGXL_ENABLE_OPENEXR=OFF"
      "-DJPEGXL_ENABLE_SJPEG=OFF"
      "-DJPEGXL_ENABLE_SKCMS=OFF"
      "-DJPEGXL_ENABLE_TCMALLOC=OFF"
      "-DJPEGXL_FORCE_SYSTEM_BROTLI=ON"
      "-DJPEGXL_FORCE_SYSTEM_HWY=ON"
      "-DJPEGXL_FORCE_SYSTEM_LCMS2=ON"
      "-DJPEGXL_INSTALL_JPEGLI_LIBJPEG=ON"
    ];

    postPatch = ''
      rm -rf third_party/libjpeg-turbo
      cp -r ${libjpegTurboSrc} third_party/libjpeg-turbo
      chmod -R u+w third_party/libjpeg-turbo
      # libjpeg-turbo 3.2 moved the public headers and config template into src/.
      substituteInPlace lib/jpegli.cmake \
        --replace-fail "../third_party/libjpeg-turbo/" "../third_party/libjpeg-turbo/src/"

      rm -rf third_party/sjpeg
      cp -r ${sjpegSrc} third_party/sjpeg
      chmod -R u+w third_party/sjpeg
    '';

    preFixup = ''
      if [ -f "$out/lib/pkgconfig/libhwy.pc" ]; then
        # Remove bundled highway .pc that contains broken paths under Nix.
        rm -f "$out/lib/pkgconfig/libhwy.pc"
      fi
    '';

    postInstall = ''
      mkdir -p "$out/lib/jpegli-private"
      shopt -s nullglob
      privateLibs=("$out"/lib/libjxl_cms.so* "$out"/lib/libjxl_threads.so*)
      if [ "''${#privateLibs[@]}" -gt 0 ]; then
        mv "''${privateLibs[@]}" "$out/lib/jpegli-private/"
      fi

      for bin in "$out"/bin/*; do
        if [ -f "$bin" ] && [ -x "$bin" ]; then
          patchelf --set-rpath "$out/lib/jpegli-private:$(patchelf --print-rpath "$bin")" "$bin"
        fi
      done

      find "$out/bin" -maxdepth 1 -type f \
        ! -name cjpegli \
        ! -name djpegli \
        -delete

      rm -f "$out"/lib/libjxl_extras_codec.a
      rm -f "$out"/lib/pkgconfig/libjxl_*.pc
      rm -rf "$out"/include/jxl
    '';

    meta = {
      description = "Improved JPEG encoder and decoder compatible with libjpeg";
      homepage = "https://github.com/google/jpegli";
      license = lib.licenses.bsd3;
      maintainers = with lib.maintainers; [
        dbreyfogle
      ];
      platforms = lib.platforms.linux;
      mainProgram = "cjpegli";
    };
  }
