{den, ...}: {
  den.aspects.portable-home = {
    includes = with den.aspects; [
      darwin-speech
      development-core
      interactive
      portable-dotfiles
      portable-runtime
      terminal-core
    ];
  };
}
