{
  lib,
  unstable,
  ...
}: {
  home.packages =
    [
      unstable.bandwhich
      unstable.duf # Disk usage utility
      unstable.dust # Disk usage analyzer
      unstable.gdu # Disk usage analyzer
      unstable.htop # Interactive process viewer
      unstable.inxi # System information tool
      unstable.killall # Kill processes by name
      unstable.lsof # List open files
      unstable.ncdu # Disk usage analyzer
      unstable.ntfs3g
      unstable.procs # Modern ps replacement
      unstable.util-linux # Portable subset on macOS
    ]
    ++ lib.optionals unstable.stdenv.hostPlatform.isLinux [
      unstable.inotify-tools # File system event monitoring
      unstable.strace # System call tracer
    ];
}
