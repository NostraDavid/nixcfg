{
  root ? ../.,
  flake ? builtins.getFlake (toString root),
}: let
  inherit (flake.inputs.nixpkgs) lib;
  structural = import ../policy {
    inherit lib;
    inherit (flake.lib) den;
    root = flake.outPath;
  };
  homes =
    builtins.attrValues (lib.mapAttrs (_: home: home.config) flake.homeConfigurations)
    ++ lib.concatMap (system: builtins.attrValues (system.config.home-manager.users or {}))
    (builtins.attrValues flake.nixosConfigurations ++ builtins.attrValues flake.darwinConfigurations);
  configs = map (system: system.config) (builtins.attrValues flake.nixosConfigurations ++ builtins.attrValues flake.darwinConfigurations) ++ homes;
  homeSentinel = selected: config:
    (import ../policy/native.nix {
      inherit lib selected config;
      root = flake.outPath;
      graph = [];
      options = {};
      class = "homeManager";
    }).assertion;
  coverage =
    map (homeSentinel ["annotation" "mcp"]) homes
    ++ map (name: homeSentinel ["codex-browser"] flake.nixosConfigurations.${name}.config.home-manager.users.david) ["wodan" "frigg" "bragi"];
  coverageFailures = builtins.filter (entry: !entry.assertion) coverage;
  failures = lib.concatMap (config: builtins.filter (entry: !entry.assertion) config.assertions) configs;
in {
  bootConfiguration = let
    donar = flake.nixosConfigurations.donar.config;
    whatpulse = donar.systemd.services.whatpulse-pcap-service.serviceConfig;
    localeAvailable = system:
      lib.all (home: let
        locale = home.programs.plasma.configFile.plasma-localerc.Formats.LC_TIME.value or null;
      in
        locale == null || builtins.elem "${locale}/UTF-8" system.config.i18n.supportedLocales)
      (builtins.attrValues (system.config.home-manager.users or {}));
  in
    assert donar.services.displayManager.defaultSession == "plasmax11";
    assert builtins.elem "plasmax11" donar.services.displayManager.sessionData.sessionNames;
    assert donar.services.tlp.settings.STOP_CHARGE_THRESH_BAT0 == 1;
    assert donar.powerManagement.cpuFreqGovernor == null;
    assert !(builtins.elem "cpufreq_schedutil" donar.boot.kernelModules);
    assert donar.services.libinput.mouse.scrollMethod == "none";
    assert donar.services.libinput.touchpad.scrollMethod == "twofinger";
    assert !donar.services.devmon.enable;
    assert lib.hasSuffix " --log-file ''" whatpulse.ExecStart;
    assert whatpulse.ProtectSystem == "strict";
    assert donar.home-manager.users.david.xdg.configFile ? "autostart/whatpulse.desktop";
    assert donar.home-manager.users.david.programs.plasma.configFile.bluedevilglobalrc.Adapters."F4:B3:01:11:B5:B5_powered".value;
    assert lib.hasInfix "Hidden=true" (builtins.readFile donar.home-manager.users.david.xdg.configFile."autostart/org.kde.discover.notifier.desktop".source);
    assert lib.all localeAvailable (builtins.attrValues flake.nixosConfigurations); true;
  homepage = let
    proxy = flake.nixosConfigurations.proxy.config;
    homepage = flake.nixosConfigurations.homepage.config;
    dashboard = homepage.services.homepage-dashboard;
    certs = flake.nixosConfigurations.certs.config;
  in
    assert dashboard.enable;
    assert homepage.networking.interfaces.ens18.ipv4.addresses
    == [
      {
        address = "192.168.2.103";
        prefixLength = 24;
      }
    ];
    assert dashboard.allowedHosts == "home.powerlan.empire,localhost:3000,127.0.0.1:3000";
    assert !dashboard.openFirewall;
    assert homepage.systemd.services.homepage-dashboard.environment.HOSTNAME == "0.0.0.0";
    assert !proxy.services.homepage-dashboard.enable;
    assert !homepage.services.caddy.enable;
    assert homepage.systemd.services.homepage-monitor-api.serviceConfig.IPAddressDeny == "any";
    assert homepage.systemd.services.homepage-monitor-api.serviceConfig.IPAddressAllow == "localhost";
    assert builtins.elem "-/run/homepage-monitor/credentials.env" homepage.systemd.services.homepage-dashboard.serviceConfig.EnvironmentFile;
    assert !(proxy.systemd.services ? pihole-tls-publish);
    assert certs.services.caddy.enable;
    assert certs.systemd.services.caddy.unitConfig.ConditionPathExists == "/srv/certs/caddy/.local/share/caddy/pki/authorities/local/root.key";
    assert lib.hasInfix "-s 192.168.2.111 -p tcp --dport 8443" certs.networking.firewall.extraCommands;
    assert lib.hasInfix "-s 192.168.2.111 -p tcp --dport 3000" homepage.networking.firewall.extraCommands;
    assert lib.hasInfix "reverse_proxy 192.168.2.103:3000" proxy.services.caddy.virtualHosts."home.powerlan.empire".extraConfig;
    assert lib.hasInfix "https://192.168.2.113:8443/acme/local/directory" proxy.services.caddy.virtualHosts."home.powerlan.empire".extraConfig; true;
  k3sPoc = let
    node = flake.nixosConfigurations.k3s.config;
    manifests = node.services.k3s.manifests.poc.content;
    deployment = builtins.head (builtins.filter (item: item.kind == "Deployment") manifests);
    pod = deployment.spec.template.spec;
    agent = builtins.elemAt pod.containers 1;
    policy = builtins.readFile ../features/k3s/policy.hcl;
  in
    assert node.services.k3s.enable;
    assert lib.versionAtLeast node.services.k3s.package.version "1.36.5";
    assert node.services.k3s.disable == ["servicelb"];
    assert (builtins.fromJSON node.services.k3s.manifests.traefik-config.content.spec.valuesContent).ports.traefik.port == 9000;
    assert builtins.elem "--secrets-encryption-provider=secretbox" node.services.k3s.extraFlags;
    assert node.fileSystems."/var/lib/rancher/k3s".device == "/dev/disk/by-label/k3s-state";
    assert !pod.automountServiceAccountToken;
    assert pod.securityContext.runAsNonRoot;
    assert lib.all (container: container.securityContext.readOnlyRootFilesystem && !container.securityContext.allowPrivilegeEscalation && container.imagePullPolicy == "Never") pod.containers;
    assert !(lib.any (mount: mount.name == "identity") (builtins.head pod.containers).volumeMounts);
    assert lib.any (mount: mount.name == "identity") agent.volumeMounts;
    assert lib.hasInfix "services/data/k3s/poc" policy;
    assert !(lib.hasInfix "services/data/*" policy);
    assert !(lib.any (item: item.kind == "Secret") manifests); true;
  certificateTrust = let
    blacklist = pkgs: import ../nix/ca-blacklist.nix pkgs.cacert.version;
    systems = builtins.attrValues flake.nixosConfigurations ++ builtins.attrValues flake.darwinConfigurations;
    standaloneHomes = builtins.filter (home: home.config.targets.genericLinux.enable) (builtins.attrValues flake.homeConfigurations);
    homepage = flake.nixosConfigurations.homepage.config;
    homepageEnvironment = homepage.systemd.services.homepage-dashboard.environment;
  in
    assert homepage.services.homepage-dashboard.enable;
    assert homepageEnvironment.HOSTNAME == "0.0.0.0";
    assert homepageEnvironment.NODE_OPTIONS == "--use-openssl-ca";
    assert homepageEnvironment.SSL_CERT_FILE == "/etc/ssl/certs/ca-certificates.crt";
    assert homepageEnvironment.SSL_CERT_DIR == toString flake.nixosConfigurations.homepage.pkgs.emptyDirectory;
    assert lib.all (system: lib.all (name: builtins.elem name system.config.security.pki.caCertificateBlacklist) (blacklist system.pkgs)) systems;
    assert lib.all (system: system.config.security.pki.installCACerts) (builtins.attrValues flake.darwinConfigurations);
    assert lib.all (system: system.config.environment.variables.SSL_CERT_FILE == "/etc/ssl/certs/ca-certificates.crt") (builtins.attrValues flake.darwinConfigurations);
    assert lib.all (system: system.config.environment.variables.SSL_CERT_DIR == toString system.pkgs.emptyDirectory) systems;
    assert lib.all (system: system.config.environment.variables.NIX_SSL_CERT_FILE == "/etc/ssl/certs/ca-certificates.crt" && system.config.environment.variables.REQUESTS_CA_BUNDLE == "/etc/ssl/certs/ca-certificates.crt" && system.config.environment.variables.PIP_CERT == "/etc/ssl/certs/ca-certificates.crt") systems;
    assert lib.all (system: lib.versionAtLeast system.pkgs.python3Packages.pip.version "26.2.2" && lib.versionAtLeast system.pkgs.uv.version "0.13.5" && lib.versionAtLeast system.pkgs.nodejs_24.version "24.22.1") systems;
    assert lib.all (home: lib.hasSuffix "-ca/bin/python3" (toString home.home.file.".local/bin/python3".source)) homes;
    assert lib.all (home: let
      bundle = "${home.pkgs.cacert.override {blacklist = blacklist home.pkgs;}}/etc/ssl/certs/ca-bundle.crt";
    in
      home.config.home.sessionVariables.SSL_CERT_FILE
      == bundle
      && home.config.home.sessionVariables.NIX_SSL_CERT_FILE == bundle
      && home.config.home.sessionVariables.REQUESTS_CA_BUNDLE == bundle)
    standaloneHomes; true;
  structure =
    if structural.valid
    then true
    else throw structural.assertion.message;
  coverage =
    if coverageFailures == []
    then true
    else throw (lib.concatMapStringsSep "\n" (entry: entry.message) coverageFailures);
  effective =
    if failures == []
    then true
    else throw (lib.concatMapStringsSep "\n" (entry: entry.message) failures);
}
