{pkgs, ...}: {
  home.packages = with pkgs; [
    # GUI libs for Haemwend
    fontconfig
    freetype
    libGL
    libx11
    libxcursor
    libxext
    libxi
    libxrandr
    libxrender
  ];
}
