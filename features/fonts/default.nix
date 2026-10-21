_: let
  packages = pkgs: [
    pkgs.monocraft # Monocraft
    pkgs.nerd-fonts.bigblue-terminal # BigBlue Terminal Nerd Font
    pkgs.nerd-fonts.iosevka # Iosevka Nerd Font, Iosevka Nerd Font Mono
    pkgs.nerd-fonts.jetbrains-mono # JetBrainsMono Nerd Font Mono
    pkgs.spleen # Spleen 6x12, Spleen 8x16, Spleen 12x24, Spleen 16x32, Spleen 32x64 (OTF)
    pkgs.terminus_font_ttf # Terminus (TTF)
    pkgs.ultimate-oldschool-pc-font-pack # IBM PC, CGA, EGA, VGA, DOS and BIOS fonts
  ];
  systemFonts = {pkgs, ...}: {
    fonts.packages = packages pkgs;
  };
in {
  den.aspects.fonts = {
    nixos = systemFonts;
    darwin = systemFonts;
    homeManager = {pkgs, ...}: {
      home.packages = packages pkgs;
      fonts.fontconfig.enable = pkgs.stdenv.hostPlatform.isLinux;
    };
  };
}
