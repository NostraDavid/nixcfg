{
  stable,
  unstable,
  ...
}: {
  home.packages = [
    stable.inotify-tools # Watch filesystem events
    stable.inxi # System information
    stable.iotop # Per-process I/O monitor
    stable.lsof # List open files
    stable.nvme-cli # Inspect and manage NVMe devices
    stable.pciutils # Provides lspci
    stable.procps # Standard process utilities such as ps
    stable.smartmontools # Monitor storage health
    stable.sysstat # System statistics, including iostat
    stable.util-linux # Low-level Linux utilities, including chrt
    unstable.btop # Resource monitor
    unstable.dust # du replacement
    unstable.gdu # Disk usage analyzer
    unstable.glances # System monitor with temperature information
    unstable.ncdu # Ncurses disk usage analyzer
    unstable.procs # Modern ps replacement
    unstable.strace # Trace system calls
  ];
}
