{
  lib,
  stable,
  unstable,
  ...
}: {
  home.packages =
    [
      stable.lsof # List open files
      unstable.duf # Disk usage utility
      unstable.dust # Disk usage analyzer
      unstable.gdu # Disk usage analyzer
      unstable.htop # Interactive process viewer
      unstable.ncdu # Disk usage analyzer
      unstable.procs # Modern ps replacement
    ]
    ++ lib.optionals stable.stdenv.isLinux [
      stable.bandwhich
      stable.inotify-tools # File system event monitoring
      stable.inxi # System information tool
      stable.killall # Kill processes by name
      stable.ntfs3g
      stable.util-linux # Low-level Linux utilities
      unstable.strace # System call tracer
    ];
}
