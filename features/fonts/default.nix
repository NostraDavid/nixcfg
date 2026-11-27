_: let
  packages = pkgs: unstable: [
    pkgs.monocraft # Monocraft
    pkgs.nerd-fonts.bigblue-terminal # BigBlue Terminal Nerd Font
    (pkgs.nerd-fonts.iosevka.overrideAttrs {
      installPhase = ''
        runHook preInstall
        install -Dm644 -t "$out/share/fonts/truetype/NerdFonts/Iosevka" \
          IosevkaNerdFont-{Regular,Bold,Italic,BoldItalic}.ttf
        runHook postInstall
      '';
    })
    unstable.ioskeley-mono.nf # Ioskeley Mono Nerd Font
    unstable.ioskeley-mono.term-nf # Ioskeley Mono Term Nerd Font
    pkgs.nerd-fonts.jetbrains-mono # JetBrainsMono Nerd Font Mono
    pkgs.spleen # Spleen 6x12, Spleen 8x16, Spleen 12x24, Spleen 16x32, Spleen 32x64 (OTF)
    pkgs.terminus_font_ttf # Terminus (TTF)
    pkgs.ultimate-oldschool-pc-font-pack # IBM PC, CGA, EGA, VGA, DOS and BIOS fonts
  ];
  systemFonts = {
    pkgs,
    unstable,
    ...
  }: {
    fonts.packages = packages pkgs unstable;
  };
in {
  den.aspects.fonts = {
    nixos = systemFonts;
    darwin = systemFonts;
    homeManager = {
      pkgs,
      unstable,
      ...
    }: {
      home.packages = packages pkgs unstable;
      fonts.fontconfig.enable = pkgs.stdenv.hostPlatform.isLinux;
    };
  };
}
