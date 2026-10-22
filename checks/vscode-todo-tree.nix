let
  flake = builtins.getFlake (toString ../.);
  pkgs = import flake.inputs.nixpkgs {system = builtins.currentSystem;};
in {
  node = pkgs.nodejs_24;
  vsix = pkgs.callPackage ../pkgs/vscode-todo-tree {
    inherit (flake.lib.unstableFor builtins.currentSystem) vscode-extensions;
  };
}
