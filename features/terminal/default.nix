{den, ...}: {
  den.aspects = {
    terminal-core = {
      nixos.services.locate.enable = true;
      darwin = {pkgs, ...}: let
        plocate = pkgs.callPackage ../../pkgs/plocate-xnu {};
      in {
        system.activationScripts.preActivation.text = ''
          /usr/bin/install -d -m 0755 -o nobody -g nobody /var/db/plocate
        '';
        launchd.daemons.locate = {
          # Index as nobody so the shared database contains only public paths.
          script = ''
            set -eu
            ${plocate}/bin/updatedb --prunepaths="/private/tmp /private/var/tmp /private/var/folders"
            /bin/chmod 0644 /var/db/plocate/plocate.db
          '';
          serviceConfig = {
            UserName = "nobody";
            GroupName = "nobody";
            ProcessType = "Background";
            RunAtLoad = true;
            StartCalendarInterval = [
              {
                Hour = 3;
                Minute = 15;
              }
            ];
          };
        };
      };
      homeManager = {stable, ...}: {
        home.packages = [
          (
            if stable.stdenv.hostPlatform.isDarwin
            then stable.callPackage ../../pkgs/plocate-xnu {}
            else stable.plocate
          )
        ];
        imports = [
          ./_config.nix
        ];
      };
    };
    terminal = {
      includes = with den.aspects; [
        terminal-core
      ];
      homeManager = {
        imports = [
          ./_packages.nix
        ];
      };
    };
  };
}
