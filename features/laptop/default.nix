_: {
  den.aspects.laptop = {
    meta.platforms = [
      "linux"
    ];
    nixos.imports = [
      {
        boot.kernelParams = [
          # This Legion's firmware does not support suspend-to-idle reliably;
          # S3/deep avoids the amdgpu resume hang seen after s2idle.
          "mem_sleep_default=deep"
          "pcie_aspm=force"
          "amdgpu.dc=1"
        ];

        powerManagement = {
          cpuFreqGovernor = "schedutil";
          powertop.enable = true;
        };

        services = {
          xserver.videoDrivers = [
            "amdgpu"
          ];
          power-profiles-daemon.enable = false;
          tlp = {
            enable = true;
            settings = {
              CPU_BOOST_ON_AC = 1;
              CPU_BOOST_ON_BAT = 0;
              CPU_SCALING_GOVERNOR_ON_AC = "performance";
              CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
              STOP_CHARGE_THRESH_BAT0 = 95;
            };
          };
        };

        hardware.bluetooth = {
          enable = true;
          powerOnBoot = true;
        };
      }
    ];
  };
}
