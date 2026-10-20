_: {
  den.aspects.selfhosted-apps = {
    nixos = {
      imports = [
        ./_nixos.nix
      ];
    };
  };
}
