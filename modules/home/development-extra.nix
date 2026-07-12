{pkgs, ...}: {
  home.packages = with pkgs; [
    exfatprogs # ExFAT FS utilities
    helm
    k3d # k3s in docker
    k3s # kubes (includes kubectl)
    postgresql # for psql; there's pgcli for shared
    redpanda-client # Kafka alternative
    vimgolf # Vim golfing
    dotnet-sdk
    # ydotool # for voxtype
    # sqruff wrapped to avoid /bin/bench collision with ollama-cuda
    (sqruff.overrideAttrs (old: {
      postInstall =
        (old.postInstall or "")
        + ''
          rm -f $out/bin/bench
        '';
    }))

    # GUI libs for Haemwend
    fontconfig
    freetype
    libGL
    libx11
    libxcursor
    libxext
    libxi
    libxrandr
    libxrender
  ];
}
