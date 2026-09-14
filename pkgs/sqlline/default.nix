{
  bash,
  lib,
  maven,
  fetchFromGitHub,
  nix-update-script,
  docbook_xml_dtd_42,
  jdk,
  writeText,
}: let
  jdbcJar = ./ImpalaJDBC42.jar;
  defaultArgsFile = writeText "sqlline-default-args" "";
in
  maven.buildMavenPackage (finalAttrs: {
    pname = "sqlline";
    version = "1.12.0";
    src = fetchFromGitHub {
      owner = "julianhyde";
      repo = "sqlline";
      tag = "sqlline-${finalAttrs.version}";
      hash = "sha256-rUlGtMgTfhciQVif0KaUcuY28wh+PrHsKen8qODom24=";
    };
    mvnHash = "sha256-9qDzc6TRn9Yv3/nTATZgP6J+PTZEZCN1et/3GrRb7X4=";
    nativeBuildInputs = [docbook_xml_dtd_42];
    mvnParameters = "-DskipTests";
    buildOffline = true;

    postPatch = ''
      substituteInPlace src/docbkx/manual.xml \
        --replace-fail "https://docbook.org/xml/4.2/docbookx.dtd" "${docbook_xml_dtd_42}/xml/dtd/docbook/docbookx.dtd" \
        --replace-fail 'PUBLIC "-//OASIS//DTD DocBook XML V4.1.2//EN"' 'PUBLIC "-//OASIS//DTD DocBook XML V4.2//EN"'
    '';

    passthru.updateScript = nix-update-script {
      extraArgs = ["--version-regex" "^sqlline-(\\d+\\.\\d+\\.\\d+)$"];
    };

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/bin" "$out/share/java" "$out/share/sqlline"

      install -m644 target/sqlline-${finalAttrs.version}-jar-with-dependencies.jar \
        "$out/share/java/sqlline-${finalAttrs.version}.jar"
      cp ${jdbcJar} "$out/share/java/ImpalaJDBC42.jar"
      cp ${defaultArgsFile} "$out/share/sqlline/default-args"

      cat > "$out/bin/sqlline" <<EOF
      #!${bash}/bin/bash
      set -euo pipefail

      config_home="\''${XDG_CONFIG_HOME:-\$HOME/.config}"
      state_home="\''${XDG_STATE_HOME:-\$HOME/.local/state}"
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
        -cp "$out/share/java/sqlline-${finalAttrs.version}.jar:$out/share/java/ImpalaJDBC42.jar" \
        sqlline.SqlLine "\''${args[@]}" "\$@"
      EOF

      chmod +x "$out/bin/sqlline"

      runHook postInstall
    '';

    meta = {
      description = "SQLLine with the local Impala JDBC driver";
      homepage = "https://github.com/julianhyde/sqlline";
      license = lib.licenses.bsd3;
      mainProgram = "sqlline";
    };
  })
