{
  lib,
  stable,
  ...
}: {
  home.packages =
    [
      stable.csvkit # Python based CSV toolkit (heavier)
      stable.duckdb # DuckDB CLI
      stable.freetype # Font rendering library for data tooling
      stable.jq # JSON processor
      stable.kcat # Kafka CLI
      stable.miller # CSV processor
      stable.parquet-tools # Parquet file viewer and converter
      stable.pgcli # psql replacement
      stable.postgresql # Stable PostgreSQL CLI
      stable.sqlite # SQLite CLI
      stable.sqlfluff # SQL linter and formatter
      stable.sqls # SQL language server
      stable.visidata # Interactive multitool for tabular data
      stable.xan # CSV processor
      stable.xq-xml # XML processor
      stable.yq-go # YAML processor
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
