{den, ...}: {
  den.aspects.portable-home = {
    includes = with den.aspects; [interactive portable-runtime terminal-core development-core darwin-speech portable-dotfiles];
  };
}
