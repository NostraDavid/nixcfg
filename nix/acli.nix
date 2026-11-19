{
  pkgs,
  formula,
  candidate ? pkgs.acli,
}: let
  inherit (pkgs) lib;
  inherit (pkgs.stdenv.hostPlatform) go;
  upstream = candidate.unwrapped or candidate;
  contents = builtins.readFile (formula + "/Formula/acli.rb");
  release = builtins.match ''.*  version "([0-9]+[.][0-9]+[.][0-9]+-stable)".*'' contents;
  version = assert lib.assertMsg (release != null) "No stable version in Atlassian's ACLI formula"; builtins.head release;
in
  if lib.meta.availableOn pkgs.stdenv.hostPlatform upstream && lib.versionAtLeast upstream.version version
  then upstream
  else
    (pkgs.acli.unwrapped or pkgs.acli).overrideAttrs (old: {
      pname = "acli";
      inherit version;
      src = let
        url = "https://acli.atlassian.com/${go.GOOS}/${version}/acli_${version}_${go.GOOS}_${go.GOARCH}.tar.gz";
        checksum = builtins.match ''.*url "${lib.escapeRegex url}"[^"]*sha256 "([[:xdigit:]]{64})".*'' contents;
      in
        assert lib.assertMsg (checksum != null) "Atlassian's ACLI formula has no checksum for ${url}";
          pkgs.fetchurl {
            inherit url;
            sha256 = builtins.head checksum;
          };
      # ACLI removed the completion command used by older nixpkgs installers.
      installPhase = ''
        runHook preInstall
        install -Dm755 acli "$out/bin/acli"
        runHook postInstall
      '';
      meta = old.meta // {platforms = lib.unique (old.meta.platforms ++ ["x86_64-darwin"]);};
    })
