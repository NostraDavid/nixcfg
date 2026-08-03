{stable, ...}: {
  home.packages = [
    stable.evolution # Email client
    stable.legcord # Discord client
    stable.mutt # Terminal email client
    stable.newsboat # Terminal RSS reader
    stable.nom # RSS reader for the terminal
    stable.signal-desktop # Signal client
  ];
}
