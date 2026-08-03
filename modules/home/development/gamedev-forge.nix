{stable, ...}: {
  home.packages = [
    # GUI libs for Haemwend
    stable.fontconfig
    stable.freetype
    stable.libGL
    stable.libx11
    stable.libxcursor
    stable.libxext
    stable.libxi
    stable.libxrandr
    stable.libxrender
  ];
}
