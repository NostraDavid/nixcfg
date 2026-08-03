{stable, ...}: {
  home.packages = [
    stable.curl # Transfer data over network protocols
    stable.dnsutils # Provides dig and nslookup
    stable.httpie # User-friendly HTTP client
    stable.inetutils # Traditional network tools, including telnet
    stable.ipcalc # IPv4 and IPv6 calculator
    stable.mtr # Network route diagnostics
    stable.netcat-gnu # TCP and UDP utility
    stable.openssl # TLS and certificate toolkit
    stable.rsync # Incremental file transfer
    stable.sipcalc # Advanced IP calculator
    stable.wget # Non-interactive network downloader
    stable.xh # Friendly HTTP client
  ];
}
