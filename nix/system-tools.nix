# Shell hook for standalone development tools. Keep library/setup-hook inputs in packages.
pkgs: tools: let
  inherit (pkgs) lib;
  configure = tool: let
    spec =
      if builtins.isString tool
      then {attr = tool;}
      else tool;
    package = lib.attrByPath (lib.splitString "." spec.attr) (throw "Unknown tool: ${spec.attr}") pkgs;
    bin = lib.getBin package;
    python = builtins.match "python3([0-9]+)" spec.attr;
    node = lib.hasPrefix "nodejs_" spec.attr;
    command =
      spec.command or (
        if python != null
        then "python3"
        else if node
        then "node"
        else package.meta.mainProgram or (lib.getName package)
      );
    companions =
      spec.also or (
        if node
        then ["npm" "npx"]
        else if python != null
        then ["python" "python3.${builtins.head python}"]
        else []
      );
    series =
      spec.series or (
        if python != null || spec.attr == "blender" || lib.versions.major package.version == "0"
        then lib.versions.majorMinor package.version
        else lib.versions.major package.version
      );
  in
    "_nd_capabilities() { ${spec.check or ":"}; }\n_nd_select_tool "
    + lib.escapeShellArgs ([
        command
        package.version
        series
        (lib.concatStringsSep " " companions)
        (
          if python != null
          then "python3.${builtins.head python}"
          else ""
        )
        (lib.getName package)
        # Refer to the recipe itself. A regular package interpolation would eagerly build it.
        "${builtins.unsafeDiscardOutputDependency bin.drvPath}^${bin.outputName}"
      ]
      ++ (spec.versionArgs or ["--version"]))
    + " || exit 1";
in ''
  _nd_select_tool() {
    local cmd=$1 pin=$2 series=$3 companions=$4 alternate=$5 pname=$6 recipe=$7
    shift 7
    local name exe dir output version sibling ok resolved store_name
    local cache=''${DEVENV_DOTFILE:-"$PWD/.direnv"}/system-tools
    for name in "$cmd" $alternate; do
      exe=$(type -P "$name") || continue
      [[ $exe == /* && $exe != "$PWD"/* ]] || continue
      resolved=$(${pkgs.coreutils}/bin/realpath "$exe") || continue
      dir=
      if [[ -n $alternate && $resolved == /nix/store/*/bin/* ]]; then
        dir=''${resolved%/*}
        exe="$dir/$cmd"
        [[ -x $exe ]] || continue
      elif [[ $name != "$cmd" ]]; then
        continue
      fi
      store_name=''${resolved#/nix/store/}
      store_name=''${store_name%%/*}
      if [[ $resolved == /nix/store/* && ''${store_name#*-} == "$pname-$pin" ]]; then
        version=$pin
      else
        output=$("$exe" "$@" </dev/null 2>&1) || continue
        [[ $output =~ (^|[^[:alnum:].])v?([0-9]+([.][0-9]+)+[[:alnum:].+_-]*) ]] || continue
        version=''${BASH_REMATCH[2]}
      fi
      if [[ $version != "$pin" ]]; then
        [[ ( $series == newer || $version == "$series".* ) && $version =~ ^[0-9]+([.][0-9]+)+$ && $pin =~ ^[0-9]+([.][0-9]+)+$ ]] || continue
        printf '%s\n' "$pin" "$version" | ${pkgs.coreutils}/bin/sort -V -C || continue
      fi
      ok=1
      for sibling in $companions; do
        if [[ -n $dir ]]; then [[ -x "$dir/$sibling" ]] || ok=0
        else type -P "$sibling" >/dev/null || ok=0
        fi
      done
      [[ $ok == 1 ]] || continue
      _nd_capabilities "$exe" || continue
      if [[ -L $cache/$cmd && ! $cache/$cmd/bin/$cmd -ef $exe ]]; then
        ${pkgs.coreutils}/bin/unlink "$cache/$cmd" || return 1
      fi
      if [[ -n $dir ]]; then export PATH="$dir:$PATH"; fi
      return 0
    done
    # nix-shell --pure can omit the Nix CLI from PATH.
    local nix
    for nix in "$(type -P nix)" /run/current-system/sw/bin/nix /nix/var/nix/profiles/default/bin/nix "$HOME/.nix-profile/bin/nix"; do
      [[ -x $nix && -f $nix ]] && break
    done
    ${pkgs.coreutils}/bin/mkdir -p "$cache" || return 1
    dir=$("$nix" --extra-experimental-features 'nix-command flakes' build --print-out-paths --out-link "$cache/$cmd" "$recipe") || return 1
    [[ -x "$dir/bin/$cmd" ]] || { echo "Missing $cmd in $dir/bin" >&2; return 1; }
    export PATH="$dir/bin:$PATH"
  }
  ${lib.concatMapStringsSep "\n" configure tools}
  unset -f _nd_select_tool _nd_capabilities
''
