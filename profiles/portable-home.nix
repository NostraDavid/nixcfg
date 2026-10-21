{den, ...}: {
  den.aspects.portable-home = {
    includes = with den.aspects; [
      darwin-speech
      development-core
      fonts
      interactive
      portable-dotfiles
      portable-runtime
      terminal-core
    ];
  };
}
