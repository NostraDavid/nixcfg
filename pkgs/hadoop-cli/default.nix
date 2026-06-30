{
  lib,
  stdenv,
  fetchurl,
  jdk,
  nix-update,
  openssl_1_1,
  zstd,
  makeBinaryWrapper,
  writeShellApplication,
  curl,
  gnugrep,
  gnused,
  version ? "3.5.0",
  sha256 ? "sha256-grnCuJwskD3BBHsSl9pCrlvL9KPnNVlAwzfrWlFASFA=",
  ...
}:
stdenv.mkDerivation rec {
  pname = "hadoop-cli";
  inherit version;

  # Fetch the prebuilt tarball from the Apache mirrors. Replace the sha256 if
  # Hadoop version is updated. You can get a new hash via:
  # nix-prefetch-url --unpack https://downloads.apache.org/hadoop/common/hadoop-${version}/hadoop-${version}.tar.gz
  src = fetchurl {
    url = "https://downloads.apache.org/hadoop/common/hadoop-${version}/hadoop-${version}.tar.gz";
    inherit sha256;
  };

  # Hadoop is a prebuilt distribution in the tarball. No compilation is
  # required; we only need Java available at runtime.
  nativeBuildInputs = [makeBinaryWrapper];
  buildInputs = [jdk (lib.getLib openssl_1_1) (lib.getLib zstd)];

  installPhase = ''
    runHook preInstall

    # Flatten the directory so $out has bin/, libexec/, etc. directly and the
    # scripts keep resolving relative paths correctly.
    if [ -d "hadoop-${version}" ]; then
      cd "hadoop-${version}"
    fi

    mkdir -p "$out"
    cp -r ./* "$out/"
    # Remove Windows helper scripts from the Unix package output.
    find "$out" -name "*.cmd" -delete || true

    # Provide minimal configuration so basic commands like `hdfs version` do
    # not error out in a clean Nix store install.
    mkdir -p "$out/etc/hadoop"

    cat > "$out/etc/hadoop/core-site.xml" <<'EOF'
    <?xml version="1.0"?>
    <configuration>
      <property>
        <name>fs.defaultFS</name>
        <value>file:///</value>
      </property>
    </configuration>
    EOF

    cat > "$out/etc/hadoop/hdfs-site.xml" <<'EOF'
    <?xml version="1.0"?>
    <configuration>
      <property>
        <name>dfs.replication</name>
        <value>1</value>
      </property>
    </configuration>
    EOF

    cat > "$out/etc/hadoop/log4j.properties" <<'EOF'
    log4j.rootLogger=INFO,console
    log4j.appender.console=org.apache.log4j.ConsoleAppender
    log4j.appender.console.target=System.err
    log4j.appender.console.layout=org.apache.log4j.PatternLayout
    log4j.appender.console.layout.ConversionPattern=%d{ISO8601} %p %c: %m%n
    EOF

    # Hadoop's native loader already searches $HADOOP_HOME/lib/native. Expose
    # native compression/crypto libraries there for `hadoop checknative -a`.
    ln -sf "${lib.getLib openssl_1_1}/lib/libcrypto.so" "$out/lib/native/libcrypto.so"
    ln -sf "${lib.getLib zstd}/lib/libzstd.so.1" "$out/lib/native/libzstd.so.1"

    runHook postInstall
  '';

  # Wrap binaries to ensure the full Hadoop environment is set and to avoid
  # fallback to /usr/local/hadoop.
  postFixup = ''
    export HADOOP_HOME="$out"
    export JAVA_HOME="${jdk}"
    export HADOOP_LD_LIBRARY_PATH="${lib.makeLibraryPath [(lib.getLib openssl_1_1) (lib.getLib zstd)]}"

    for f in "$out/bin"/*; do
      if [ -f "$f" ] && [ -x "$f" ]; then
        wrapProgram "$f" \
          --set HADOOP_HOME "$HADOOP_HOME" \
          --set HADOOP_COMMON_HOME "$HADOOP_HOME" \
          --set HADOOP_HDFS_HOME "$HADOOP_HOME" \
          --set HADOOP_MAPRED_HOME "$HADOOP_HOME" \
          --set HADOOP_YARN_HOME "$HADOOP_HOME" \
          --set HADOOP_LIBEXEC_DIR "$HADOOP_HOME/libexec" \
          --set JAVA_HOME "$JAVA_HOME" \
          --prefix LD_LIBRARY_PATH : "$HADOOP_LD_LIBRARY_PATH" \
          --prefix PATH : "${jdk}/bin" \
          --prefix PATH : "$out/bin"
      fi
    done
  '';

  passthru.updateScript = lib.getExe (writeShellApplication {
    name = "update-hadoop-cli";
    runtimeInputs = [
      curl
      gnugrep
      gnused
      nix-update
    ];
    text = ''
      set -euo pipefail

      latest_version="$(${lib.getExe curl} -fsSL https://downloads.apache.org/hadoop/common/stable/ \
        | ${lib.getExe gnugrep} -oE 'hadoop-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' \
        | ${lib.getExe gnused} -E 's/^hadoop-([0-9.]+)\.tar\.gz$/\1/' \
        | sort -V \
        | tail -n1)"

      if [[ -z "$latest_version" ]]; then
        echo "Failed to determine the latest Hadoop version from Apache downloads" >&2
        exit 1
      fi

      exec ${lib.getExe nix-update} -F --version "$latest_version" "$UPDATE_NIX_ATTR_PATH"
    '';
  });

  meta = with lib; {
    description = "Apache Hadoop command-line distribution";
    homepage = "https://hadoop.apache.org/";
    license = licenses.asl20;
    mainProgram = "hadoop";
    maintainers = [];
    platforms = platforms.linux;
  };
}
