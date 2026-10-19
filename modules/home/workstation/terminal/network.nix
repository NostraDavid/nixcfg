{
  lib,
  stable,
  unstable,
  ...
}: {
  home.packages =
    [
      stable.curl
      stable.dnsutils # `dig` + `nslookup`
      stable.nmap # Network mapper
      stable.rsync
      stable.wget
      unstable.doggo # DNS lookup tool
    ]
    ++ lib.optionals stable.stdenv.isLinux [
      stable.dnstop # DNS traffic analyzer
      stable.inetutils # telnet and related tools
      stable.ipcalc # Subnet calculator
      stable.mtr # Network route diagnostics
      stable.net-tools # arp, ifconfig, netstat, route
      stable.netcat-gnu # nc (GNU version)
    ];
}
