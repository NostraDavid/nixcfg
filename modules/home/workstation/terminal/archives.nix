{stable, ...}: {
  home.packages = [
    stable.lz4 # Fast compression tools
    stable.p7zip # 7-Zip command-line tools
    stable.pigz # Parallel gzip implementation
    stable.poppler-utils # PDF utilities
    stable.unzip # Extract ZIP archives
    stable.xz # XZ compression tools
    stable.zstd # Zstandard compression tools
  ];
}
