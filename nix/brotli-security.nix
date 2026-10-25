# CVE-2026-111497 affects shared Brotli and independent bundled decoders.
_final: prev: let
  inherit (prev) lib;
  decoderFix = prev.fetchurl {
    url = "https://github.com/google/brotli/commit/0ed4268a4401abcb4472096340477cf4af7d1a2b.patch?full_index=1";
    hash = "sha256-1vliUJAAIj3vcGKVgim9CEV+XgMuftDR2U+3kLBUsfw=";
  };
  duckdbFix = prev.fetchurl {
    url = "https://github.com/duckdb/duckdb/commit/8243a9ab13d4339c1ee8c29598bfdadf0648bee9.patch";
    hash = "sha256-y/NQABvxB3YI4d6A5PB0pMyYLN39+wlmIWi1yCl2uvc=";
  };
  bunAssets = {
    aarch64-darwin = {
      name = "bun-darwin-aarch64";
      hash = "sha256-wkDX8My5DCY6hJ/NsJt+5iYw2SE0jtaq/ahrnVd7xRA=";
    };
    aarch64-linux = {
      name = "bun-linux-aarch64";
      hash = "sha256-uqa7NvUdblhWHgK76oJQOKnfRU9nPW13bou/hvjHhQ4=";
    };
    x86_64-darwin = {
      name = "bun-darwin-x64-baseline";
      hash = "sha256-1KFVrfv9CRVes7oFyeOlRPOSl9emhhbTx3WfZ6tcR9w=";
    };
    x86_64-linux = {
      name = "bun-linux-x64-baseline";
      hash = "sha256-4ERutVmVdy65iUvrrppr42jZhai5Jx7hJEhvmUbu3XY=";
    };
  };
  bunSources = lib.mapAttrs (_: asset:
    prev.fetchurl {
      url = "https://github.com/oven-sh/bun/releases/download/bun-v1.4.4/${asset.name}.zip";
      inherit (asset) hash;
    })
  bunAssets;
  patchedBrotli = prev.brotli.overrideAttrs (old: {
    postPatch =
      (old.postPatch or "")
      + ''
        # Node's existing scoped dependency may already apply this same fix.
        if ! grep -q 'BLOCK_SWITCH' c/include/brotli/decode.h; then
          patch -p1 < ${decoderFix}
        fi
      '';
  });
in {
  brotliPatched = patchedBrotli;
  # Darwin needs normal linking and signing; Linux grafts deployed closures.
  brotli =
    if prev.stdenv.hostPlatform.isLinux
    then prev.brotli
    else patchedBrotli;
  duckdb = prev.duckdb.overrideAttrs (old: {
    # Python's binding consumes duckdb.src directly, before DuckDB's patches.
    src = prev.applyPatches {
      name = "duckdb-${old.version}-brotli-security-source";
      inherit (old) src;
      patches = [duckdbFix];
    };
  });
  bun =
    if lib.versionAtLeast prev.bun.version "1.4.4"
    then prev.bun
    else
      prev.bun.overrideAttrs (old: {
        version = "1.4.4";
        src = bunSources.${prev.stdenvNoCC.hostPlatform.system};
        passthru =
          (old.passthru or {})
          // {
            sources = bunSources;
          };
      });
}
