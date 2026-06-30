{
  bash,
  stdenvNoCC,
  jdk,
  upstreamSqlline,
  writeText,
}: let
  jdbcJar = ./ImpalaJDBC42.jar;
  defaultArgsFile = writeText "sqlline-default-args" "";
in
  stdenvNoCC.mkDerivation {
    inherit (upstreamSqlline) pname version;

    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin" "$out/share/java" "$out/share/sqlline"

      cp ${jdbcJar} "$out/share/java/ImpalaJDBC42.jar"
      cp ${defaultArgsFile} "$out/share/sqlline/default-args"

      cat > "$out/bin/sqlline" <<EOF
      #!${bash}/bin/bash
      set -euo pipefail

      config_home="''${XDG_CONFIG_HOME:-\$HOME/.config}"
      state_home="''${XDG_STATE_HOME:-\$HOME/.local/state}"
      default_args_file="\$config_home/sqlline/default-args"
      fallback_args_file="$out/share/sqlline/default-args"
      history_file="\$state_home/sqlline/history"

      mkdir -p "\$(dirname "\$history_file")"

      args=("--historyfile=\$history_file")
      args_file="\$fallback_args_file"
      if [ -f "\$default_args_file" ]; then
        args_file="\$default_args_file"
      fi

      if [ -f "\$args_file" ]; then
        while IFS= read -r line || [ -n "\$line" ]; do
          case "\$line" in
            "" | \#*)
              continue
              ;;
          esac
          args+=("\$line")
        done < "\$args_file"
      fi

      exec ${jdk}/bin/java \
        -cp "${upstreamSqlline}/share/java/sqlline-${upstreamSqlline.version}.jar:$out/share/java/ImpalaJDBC42.jar" \
        sqlline.SqlLine "''${args[@]}" "\$@"
      EOF

      chmod +x "$out/bin/sqlline"

      runHook postInstall
    '';

    meta =
      upstreamSqlline.meta
      // {
        description = "SQLLine wrapped with the local Impala JDBC driver";
        mainProgram = "sqlline";
      };
  }
