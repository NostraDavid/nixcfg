{
  prev,
  system,
  unstable,
  ...
}: let
  source =
    if system == "x86_64-linux"
    then unstable
    else prev;
in {
  inherit (source) vscode curl openssl ripgrep;
}
