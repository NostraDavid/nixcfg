_: {
  den.aspects.wireguard-gui = {
    meta.platforms = [
      "linux"
    ];
    # The app needs a privileged helper for every tunnel operation. It only
    # trusts a helper at /usr/local/lib/wireguard-gui/wg-helper or
    # /usr/lib/wireguard-gui/wg-helper whose ancestors are root-owned and not
    # group-writable. /nix/store is group-writable, so the helper is copied to
    # the expected path during activation. The shipped polkit rule lets members
    # of the wireguard group run it from an active local session.
    nixos.imports = [
      ({
        local,
        main-user,
        pkgs,
        ...
      }: {
        environment.systemPackages = [
          local.wireguard-gui
          # The helper runs wg and wg-quick from a fixed PATH that starts with
          # /run/current-system/sw/bin, so wireguard-tools must be in the
          # system profile. The nixpkgs wg-quick wrapper injects iproute2 and
          # procps itself.
          pkgs.wireguard-tools
        ];

        users = {
          groups.wireguard = {};
          users.${main-user}.extraGroups = [
            "wireguard"
          ];
        };

        security.polkit.enable = true;
        environment.etc."polkit-1/rules.d/49-wireguard-gui.rules".source = "${local.wireguard-gui}/share/polkit-1/rules.d/49-wireguard-gui.rules";

        system.activationScripts.wireguard-gui-helper = ''
          install -d -m 0755 /usr/local/lib/wireguard-gui
          install -m 0755 -o root -g root \
            ${local.wireguard-gui}/libexec/wireguard-gui/wg-helper \
            /usr/local/lib/wireguard-gui/wg-helper
        '';
      })
    ];
  };
}
