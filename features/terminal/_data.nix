{
  stable,
  unstable,
  ...
}: {
  home.packages = [
    stable.libxml2 # Provides xmllint
    unstable.csvkit # CSV toolkit
    unstable.duckdb # Analytical SQL database
    unstable.jq # JSON processor
    unstable.miller # Stream processor for tabular data
    unstable.parquet-tools # Inspect Apache Parquet files
    unstable.pgcli # Interactive PostgreSQL client
    unstable.rainfrog # Database management TUI
    unstable.sabiql # PostgreSQL TUI
    unstable.sqlite # Embedded SQL database and CLI
    unstable.visidata # Interactive terminal tool for tabular data
    unstable.xq-xml # XML processor with jq-style queries
    unstable.yq-go # YAML processor
    unstable.zsv # CSV viewer and slicer
  ];
}
