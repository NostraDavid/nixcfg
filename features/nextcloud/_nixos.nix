{
  config,
  lib,
  pkgs,
  utils,
  ...
}: let
  root = "/srv/nextcloud";
  cfg = config.nixcfg.nextcloud;
  initializeDisk = pkgs.writeShellApplication {
    name = "nextcloud-initialize-disk";
    runtimeInputs = [pkgs.util-linux pkgs.e2fsprogs pkgs.diffutils pkgs.coreutils];
    text = builtins.readFile ../../scripts/lab-initialize-disk.sh;
  };
  users = "cn=users,cn=accounts,dc=powerlan,dc=empire";
  groups = "cn=groups,cn=accounts,dc=powerlan,dc=empire";
  userFilter = "(&(objectClass=inetOrgPerson)(memberOf=cn=grp-nextcloud-user,${groups})(!(nsAccountLock=TRUE)))";
  ldapSettings = {
    ldapHost = "ldaps://ldap.powerlan.empire";
    ldapPort = "636";
    ldapBase = "dc=powerlan,dc=empire";
    ldapBaseUsers = users;
    ldapBaseGroups = groups;
    ldapAgentName = "uid=nextcloud-reader,cn=sysaccounts,cn=etc,dc=powerlan,dc=empire";
    ldapUserFilter = userFilter;
    ldapLoginFilter = "(&${userFilter}(uid=%uid))";
    ldapGroupFilter = "(&(objectClass=groupOfNames)(cn=grp-nextcloud-user))";
    ldapGroupMemberAssocAttr = "member";
    ldapGroupDisplayName = "cn";
    ldapUserDisplayName = "displayName";
    ldapEmailAttribute = "mail";
    ldapExpertUUIDUserAttr = "ipaUniqueID";
    ldapExpertUUIDGroupAttr = "ipaUniqueID";
    ldapUserAvatarRule = "none";
    ldapExperiencedAdmin = "1";
    ldapUserFilterMode = "1";
    ldapLoginFilterMode = "1";
    ldapGroupFilterMode = "1";
    ldapTLS = "0";
    turnOffCertCheck = "0";
    turnOnPasswordChange = "0";
  };
  mounted = {
    requires = ["srv-nextcloud.mount" "nextcloud-prepare.service"];
    after = ["srv-nextcloud.mount" "nextcloud-prepare.service"];
    unitConfig.AssertPathIsMountPoint = root;
  };
in {
  imports = [./_openbao.nix];

  options.nixcfg.nextcloud.dataDevice = lib.mkOption {
    type = lib.types.str;
    default = "/dev/disk/by-id/virtio-nextcloud-state";
    description = "The designated empty disk for persistent Nextcloud state.";
  };

  config = {
    services = {
      nextcloud = {
        enable = true;
        package = pkgs.nextcloud35;
        hostName = "nextcloud.powerlan.empire";
        home = "${root}/nextcloud";
        https = true;
        database.createLocally = true;
        configureRedis = true;
        appstoreEnable = false;
        phpExtraExtensions = extensions: [extensions.ldap];
        config = {
          dbtype = "pgsql";
          adminuser = "recovery-admin";
          adminpassFile = "${root}/secrets/admin-password";
        };
        settings = {
          trusted_proxies = ["127.0.0.1" "192.168.2.111"];
          overwriteprotocol = "https";
          "overwrite.cli.url" = "https://nextcloud.powerlan.empire";
          log_type = "systemd";
          updatechecker = false;
        };
      };
      postgresql = {
        package = pkgs.postgresql_16;
        dataDir = "${root}/postgresql/16";
      };
      nginx.virtualHosts."nextcloud.powerlan.empire" = {
        listen = [
          {
            addr = "127.0.0.1";
            port = 8080;
          }
        ];
        extraConfig = "access_log off;";
      };
      caddy = {
        enable = true;
        dataDir = "${root}/caddy";
        globalConfig = ''
          skip_install_trust
          servers {
            trusted_proxies static 192.168.2.111/32
            trusted_proxies_strict
          }
        '';
        virtualHosts."https://nextcloud-backend.powerlan.empire:8443" = {
          logFormat = lib.mkForce null;
          extraConfig = ''
            tls internal
            reverse_proxy 127.0.0.1:8080 {
              header_up Host nextcloud.powerlan.empire
            }
          '';
        };
      };
    };

    systemd.services = lib.mkMerge [
      (lib.genAttrs ["nextcloud-setup" "nextcloud-update-db" "nextcloud-cron" "phpfpm-nextcloud" "postgresql" "caddy" "nginx" "nextcloud-ldap"] (_: mounted))
      {
        nextcloud-setup.serviceConfig.RemainAfterExit = true;
        nextcloud-update-db.environment.NEXTCLOUD_CONFIG_DIR = "${root}/nextcloud/config";
        nextcloud-data-init = {
          description = "Initialize only the designated empty Nextcloud data disk";
          requiredBy = ["srv-nextcloud.mount"];
          before = ["srv-nextcloud.mount"];
          requires = ["${utils.escapeSystemdPath cfg.dataDevice}.device"];
          after = ["${utils.escapeSystemdPath cfg.dataDevice}.device"];
          unitConfig.DefaultDependencies = false;
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            TimeoutStartSec = "10min";
          };
          script = "exec ${initializeDisk}/bin/nextcloud-initialize-disk ${lib.escapeShellArg cfg.dataDevice} nextcloud-state";
        };
        nextcloud-prepare = {
          description = "Prepare Nextcloud directories and recovery credential on the state disk";
          requires = ["srv-nextcloud.mount"];
          after = ["srv-nextcloud.mount"];
          unitConfig.AssertPathIsMountPoint = root;
          path = [pkgs.coreutils pkgs.openssl];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            UMask = "0077";
          };
          script = ''
            install -d -m 0755 ${root}
            # A nofail mount can finish after the boot-time tmpfiles pass.
            ${pkgs.systemd}/bin/systemd-tmpfiles --create --prefix=${root}/nextcloud
            install -d -m 0700 -o postgres -g postgres ${root}/postgresql ${root}/postgresql/16
            install -d -m 0700 -o caddy -g caddy ${root}/caddy
            install -d -m 0700 ${root}/secrets ${root}/openbao-consumer
            if [ ! -s ${root}/secrets/admin-password ]; then
              if [ -e ${root}/nextcloud/config/config.php ]; then
                echo 'Existing Nextcloud installation has no recovery credential; restore it' >&2
                exit 1
              fi
              openssl rand -hex 32 > ${root}/secrets/admin-password.new
              mv ${root}/secrets/admin-password.new ${root}/secrets/admin-password
            fi
          '';
        };
        nextcloud-ldap = {
          description = "Reconcile the restricted FreeIPA login configuration";
          wantedBy = ["multi-user.target"];
          requires = ["nextcloud-setup.service"];
          after = ["nextcloud-setup.service" "network-online.target"];
          wants = ["network-online.target"];
          unitConfig.ConditionPathExists = "${root}/secrets/ldap-bind-password";
          path = [config.services.nextcloud.occ pkgs.jq];
          environment.LDAPTLS_REQCERT = "demand";
          serviceConfig = {
            Type = "oneshot";
            User = "nextcloud";
            RemainAfterExit = true;
            LoadCredential = "ldap-password:${root}/secrets/ldap-bind-password";
            UMask = "0077";
          };
          script = ''
            test -s "$CREDENTIALS_DIRECTORY/ldap-password"
            nextcloud-occ app:enable user_ldap
            existing=$(nextcloud-occ ldap:show-config --output=json)
            if [ "$(printf '%s' "$existing" | jq 'length')" = 0 ]; then
              nextcloud-occ ldap:create-empty-config
              existing=$(nextcloud-occ ldap:show-config --output=json)
            fi
            printf '%s' "$existing" | jq -e 'keys == ["s01"]' >/dev/null
            # Changing an established UUID mapping can disconnect accounts from their files.
            printf '%s' "$existing" | jq -e '.s01.ldapExpertUUIDUserAttr | ascii_downcase | . == "" or . == "ipauniqueid"' >/dev/null
            nextcloud-occ ldap:set-config s01 ldapConfigurationActive 0
            ${lib.concatStringsSep "\n" (lib.mapAttrsToList (key: value: "nextcloud-occ ldap:set-config s01 ${lib.escapeShellArg key} ${lib.escapeShellArg value}") ldapSettings)}
            jq -n --rawfile password "$CREDENTIALS_DIRECTORY/ldap-password" \
              '{apps:{user_ldap:{s01ldap_agent_password:($password | rtrimstr("\n") | @base64)}}}' \
              | nextcloud-occ config:import
            nextcloud-occ ldap:set-config s01 ldapConfigurationActive 1
            nextcloud-occ ldap:test-config s01
          '';
        };
      }
    ];
  };
}
