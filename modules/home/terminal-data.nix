{
  stable,
  unstable,
  ...
}: {
  home.packages = [
    stable.csvkit # CSV toolkit
    stable.duckdb # Analytical SQL database
    stable.jq # JSON processor
    stable.libxml2 # Provides xmllint
    stable.miller # Stream processor for tabular data
    stable.parquet-tools # Inspect Apache Parquet files
    stable.pgcli # Interactive PostgreSQL client
    stable.sqlite # Embedded SQL database and CLI
    stable.visidata # Interactive terminal tool for tabular data
    stable.xq-xml # XML processor with jq-style queries
    stable.yq-go # YAML processor
    unstable.zsv # CSV viewer and slicer
  ];
}
