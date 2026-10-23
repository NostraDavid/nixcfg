{
  lib,
  stable,
  unstable,
  ...
}: {
  home.packages =
    [
      # Climate / weather data tooling
      stable.cdo
      stable.eccodes
      stable.gdal
      stable.h5glance
      stable.h5utils
      stable.netcdf
      unstable.csvkit # Python based CSV toolkit (heavier)
      unstable.duckdb # DuckDB CLI
      unstable.freetype # Font rendering library for data tooling
      unstable.jq # JSON processor
      stable.kcat # The same version; unstable's GCC 16 dependency chain fails.
      unstable.miller # CSV processor
      unstable.parquet-tools # Parquet file viewer and converter
      unstable.pgcli # psql replacement
      unstable.postgresql # Stable PostgreSQL CLI
      unstable.rainfrog # Database management TUI
      unstable.sabiql # PostgreSQL TUI
      unstable.sqlfluff # SQL linter and formatter
      unstable.sqlite # SQLite CLI
      unstable.sqls # SQL language server
      unstable.visidata # Interactive multitool for tabular data
      unstable.xan # CSV processor
      unstable.xq-xml # XML processor
      unstable.yq-go # YAML processor
    ]
    ++ lib.optionals stable.stdenv.hostPlatform.isLinux [
      # netcdf-cxx4 is marked broken on Darwin in the pinned nixpkgs.
      stable.nco
    ];
}
