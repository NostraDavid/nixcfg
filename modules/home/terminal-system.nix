{stable, ...}: {
  home.packages = [
    stable.btop # Resource monitor
    stable.dust # du replacement
    stable.gdu # Disk usage analyzer
    stable.glances # System monitor with temperature information
    stable.inotify-tools # Watch filesystem events
    stable.inxi # System information
    stable.iotop # Per-process I/O monitor
    stable.lsof # List open files
    stable.ncdu # Ncurses disk usage analyzer
    stable.nvme-cli # Inspect and manage NVMe devices
    stable.pciutils # Provides lspci
    stable.procps # Standard process utilities such as ps
    stable.procs # Modern ps replacement
    stable.smartmontools # Monitor storage health
    stable.strace # Trace system calls
    stable.sysstat # System statistics, including iostat
    stable.util-linux # Low-level Linux utilities, including chrt
  ];
}
