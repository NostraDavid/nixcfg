_: {
  perSystem = {pkgs, ...}: let
    modules = pkgs.linkFarm "headlamp-identity-python" [
      {
        name = "openbao.py";
        path = ../scripts/openbao.py;
      }
    ];
  in {
    packages.headlamp-identity = pkgs.writeShellApplication {
      name = "headlamp-identity";
      runtimeInputs = [pkgs.python3];
      text = ''PYTHONPATH=${modules} exec python3 ${../scripts/headlamp-identity.py} "$@"'';
    };
  };
}
