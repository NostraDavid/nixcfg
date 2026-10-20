{
  lib,
  stable,
  unstable,
  ...
}: {
  home.packages =
    [
      stable.freetype # Font rendering library for data tooling
      stable.postgresql # Stable PostgreSQL CLI
      unstable.csvkit # Python based CSV toolkit (heavier)
      unstable.duckdb # DuckDB CLI
      unstable.jq # JSON processor
      unstable.kcat # Kafka CLI
      unstable.miller # CSV processor
      unstable.parquet-tools # Parquet file viewer and converter
      unstable.pgcli # psql replacement
      unstable.sqlfluff # SQL linter and formatter
      unstable.sqlite # SQLite CLI
      unstable.sqls # SQL language server
      unstable.visidata # Interactive multitool for tabular data
      unstable.xan # CSV processor
      unstable.xq-xml # XML processor
      unstable.yq-go # YAML processor
    ]
    ++ lib.optionals stable.stdenv.isLinux [
      # Climate / weather data tooling
      stable.cdo
      stable.eccodes
      stable.gdal
      stable.h5glance
      stable.h5utils
      stable.nco
      stable.netcdf
    ];
}
