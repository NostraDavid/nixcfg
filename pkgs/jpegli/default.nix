{
  lib,
  stdenv,
  cmake,
  ninja,
  pkg-config,
  highway ? null,
  lcms2,
  libpng,
  zlib,
  fetchFromGitHub,
}: let
  version = "unstable-2025-02-11";
  src = fetchFromGitHub {
    owner = "google";
    repo = "jpegli";
    # Prefer a pinned commit for reproducibility.
    rev = "bc19ca2393f79bfe0a4a9518f77e4ad33ce1ab7a";
    fetchSubmodules = true;
    # To get the hash:
    # nix store prefetch-file --unpack https://github.com/google/jpegli/archive/REPLACE_WITH_COMMIT.tar.gz
    hash = "sha256-8th+QHLOoAIbSJwFyaBxUXoCXwj7K7rgg/cCK7LgOb0=";
  };
in
  stdenv.mkDerivation (finalAttrs: {
    pname = "jpegli";
    inherit version src;

    nativeBuildInputs = [
      cmake
      ninja
      pkg-config
    ];

    buildInputs =
      [
        lcms2
        libpng
        zlib
      ]
      ++ lib.optional (highway != null) highway;

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
      "-DJPEGXL_FORCE_SYSTEM_LCMS2=ON"
      "-DJPEGXL_INSTALL_JPEGLI_LIBJPEG=ON"
    ]
    ++ lib.optional (highway != null) "-DJPEGXL_FORCE_SYSTEM_HWY=ON"
    ++ lib.optional (highway == null) "-DJPEGXL_FORCE_SYSTEM_HWY=OFF";

    preFixup = ''
      if [ -f "$out/lib/pkgconfig/libhwy.pc" ]; then
        # Remove bundled highway .pc that contains broken paths under Nix.
        rm -f "$out/lib/pkgconfig/libhwy.pc"
      fi
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
  })
