{unstable, ...}: {
  home.packages = [
    unstable.curl
    unstable.dnstop # DNS traffic analyzer
    unstable.dnsutils # `dig` + `nslookup`
    unstable.doggo # DNS lookup tool
    unstable.inetutils # telnet and related tools
    unstable.ipcalc # Subnet calculator
    unstable.mtr # Network route diagnostics
    unstable.net-tools # arp, ifconfig, netstat, route
    unstable.netcat-gnu # nc (GNU version)
    unstable.nmap # Network mapper
    unstable.rsync
    unstable.wget
  ];
}
