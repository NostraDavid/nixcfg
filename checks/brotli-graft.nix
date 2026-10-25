{
  pkgs,
  unstable,
  replacements,
  graftRuntime,
}: let
  inherit (pkgs) lib;
  fixture = pkgs.runCommand "brotli-graft-consumer" {nativeBuildInputs = [pkgs.stdenv.cc];} ''
    mkdir -p "$out/bin"
    $CC ${./brotli-graft-consumer.c} -I${pkgs.brotli.dev}/include \
      -L${pkgs.brotli.lib}/lib -Wl,-rpath,${pkgs.brotli.lib}/lib \
      -lbrotlidec -o "$out/bin/consumer"
    printf '%s\n' ${lib.escapeShellArgs (map (r: toString r.oldDependency) replacements)} > "$out/paths"
    ln -s ${pkgs.brotli.lib}/lib/libbrotlidec.so "$out/stable.so"
    ln -s ${unstable.brotli.lib}/lib/libbrotlidec.so "$out/unstable.so"
    ln -s /tmp/nixcfg-live-dotfiles/config "$out/dotfile"
  '';
  grafted = graftRuntime fixture;
  ordinary = pkgs.stdenvNoCC.mkDerivation {
    name = "brotli-graft-ordinary-package";
    dontUnpack = true;
    installPhase = ''printf 'ordinary package\n' > "$out"'';
  };
  singleLine = pkgs.runCommand "brotli-graft-single-line" {} ''printf 'single line\n' > "$out"'';
in
  pkgs.runCommand "brotli-graft-check" {
    passthru = {inherit fixture grafted;};
    nativeBuildInputs = [pkgs.python3];
    exportReferencesGraph = ["runtime-graph" grafted];
    BROTLI_CLI = lib.getExe pkgs.brotliPatched;
  } ''
    grep -F -x 'ordinary package' ${graftRuntime ordinary}
    grep -F -x 'single line' ${graftRuntime singleLine}
    # The same binary must fail the regression before grafting and pass after it.
    if ${fixture}/bin/consumer; then
      echo "The upstream fixture is already patched; update this negative control." >&2
      exit 1
    fi
    ${grafted}/bin/consumer
    test "$(readlink ${grafted}/dotfile)" = /tmp/nixcfg-live-dotfiles/config
    for library in stable unstable; do
      BROTLI_LIBRARY="${grafted}/$library.so" python3 ${./test-brotli-security.py}
    done
    ${lib.concatMapStringsSep "\n" (r: ''
        if grep -F -x ${lib.escapeShellArg (toString r.oldDependency)} runtime-graph; then
          echo "Unpatched Brotli remains in the grafted runtime closure." >&2
          exit 1
        fi
        grep -F -x ${lib.escapeShellArg (toString r.newDependency)} ${grafted}/paths
      '')
      replacements}
    touch "$out"
  ''
