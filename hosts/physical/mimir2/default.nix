{
  den,
  constructors,
  packageSets,
  mimir2Spec,
  ...
}: {
  den.homes.x86_64-linux.mimir2 = {
    pkgs = packageSets.pkgsFor "x86_64-linux";
    instantiate = constructors.home mimir2Spec;
    aspect = den.aspects.home-mimir2;
  };
  den.aspects.home-mimir2 = {
    includes = [
      den.aspects.portable-home
    ];
    homeManager = {local, ...}: {
      home.packages = [
        local.pandacode
        local.twg # Atlassian Teamwork Graph CLI
      ];
      programs.home-manager.enable = true;
      targets.genericLinux = {
        enable = true;
        gpu.enable = false;
      };
      home = {
        username = "david";
        homeDirectory = "/home/david";
        stateVersion = "25.11";
      };
    };
  };
}
