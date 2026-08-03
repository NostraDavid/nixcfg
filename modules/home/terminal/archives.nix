{stable, ...}: {
  home.packages = [
    stable.brotli # Brotli compression tools
    stable.bzip2 # bzip2 compression tools
    stable.gzip # gzip compression tools
    stable.lz4 # Fast compression tools
    stable.p7zip # 7-Zip command-line tools
    stable.pigz # Parallel gzip implementation
    stable.rar # RAR archive tools
    stable.unzip # Extract ZIP archives
    stable.upx # Compress executable files
    stable.xz # XZ compression tools
    stable.zip # Create ZIP archives
    stable.zstd # Zstandard compression tools
  ];
}
