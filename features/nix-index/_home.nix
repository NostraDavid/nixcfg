{
  inputs,
  lib,
  unstable,
  ...
}: {
  home.activation.nixIndex = lib.hm.dag.entryAfter ["writeBoundary"] ''
    (
      index_dir="''${NIX_INDEX_DATABASE:-''${XDG_CACHE_HOME:-$HOME/.cache}/nix-index}"
      if [[ -z "''${DRY_RUN_CMD:-}" && ! -s "$index_dir/files" ]]; then
        mkdir -p "$index_dir"
        temporary=$(mktemp -d "$index_dir/.build.XXXXXXXX")
        trap 'rm -rf "$temporary"' EXIT
        ${unstable.nix-index}/bin/nix-index \
          --nixpkgs ${inputs.nixpkgs-unstable} \
          --system ${unstable.stdenv.hostPlatform.system} \
          --db "$temporary"
        mv "$temporary/files" "$index_dir/files"
      fi
    )
  '';
}
