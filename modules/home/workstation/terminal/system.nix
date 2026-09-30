{
  lib,
  stable,
  ...
}: {
  home.packages =
    [
      stable.duf # Disk usage utility
      stable.dust # Disk usage analyzer
      stable.gdu # Disk usage analyzer
      stable.htop # Interactive process viewer
      stable.lsof # List open files
      stable.ncdu # Disk usage analyzer
      stable.procs # Modern ps replacement
    ]
    ++ lib.optionals stable.stdenv.isLinux [
      stable.bandwhich
      stable.inotify-tools # File system event monitoring
      stable.inxi # System information tool
      stable.killall # Kill processes by name
      stable.strace # System call tracer
      stable.ntfs3g
      stable.plocate # Locate command
      stable.util-linux # Low-level Linux utilities
    ];
}
