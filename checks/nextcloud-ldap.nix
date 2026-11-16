{
  pkgs,
  nextcloudModule,
}: let
  base = "dc=powerlan,dc=empire";
  users = "cn=users,cn=accounts,${base}";
  group = "cn=grp-nextcloud-user,cn=groups,cn=accounts,${base}";
  reader = "uid=nextcloud-reader,cn=sysaccounts,cn=etc,${base}";
  password = "synthetic-nextcloud-password-123456";
  tls = pkgs.runCommand "nextcloud-test-ldap-tls" {nativeBuildInputs = [pkgs.openssl];} ''
    mkdir -p "$out"
    openssl req -x509 -newkey rsa:2048 -nodes \
      -keyout "$out/key.pem" -out "$out/cert.pem" -days 3650 \
      -subj /CN=ldap.powerlan.empire \
      -addext subjectAltName=DNS:ldap.powerlan.empire \
      -addext basicConstraints=critical,CA:TRUE
  '';
  contents = ''
    dn: ${base}
    objectClass: domain
    dc: powerlan

    dn: cn=accounts,${base}
    objectClass: organizationalRole
    cn: accounts

    dn: ${users}
    objectClass: organizationalRole
    cn: users

    dn: cn=groups,cn=accounts,${base}
    objectClass: organizationalRole
    cn: groups

    dn: cn=etc,${base}
    objectClass: organizationalRole
    cn: etc

    dn: cn=sysaccounts,cn=etc,${base}
    objectClass: organizationalRole
    cn: sysaccounts

    dn: ${reader}
    objectClass: account
    objectClass: simpleSecurityObject
    uid: nextcloud-reader
    userPassword: ${password}

    dn: uid=alice,${users}
    objectClass: inetOrgPerson
    objectClass: nextcloudFixture
    uid: alice
    cn: Test Alice
    sn: Alice
    displayName: Test Alice
    mail: alice@example.com
    ipaUniqueID: 11111111-1111-4111-8111-111111111111
    memberOf: ${group}
    userPassword: ${password}

    dn: uid=outsider,${users}
    objectClass: inetOrgPerson
    objectClass: nextcloudFixture
    uid: outsider
    cn: Test Outsider
    sn: Outsider
    displayName: Test Outsider
    mail: outsider@example.com
    ipaUniqueID: 22222222-2222-4222-8222-222222222222
    userPassword: ${password}

    dn: ${group}
    objectClass: groupOfNames
    objectClass: nextcloudFixture
    cn: grp-nextcloud-user
    member: uid=alice,${users}
    ipaUniqueID: 33333333-3333-4333-8333-333333333333
  '';
in {
  name = "nextcloud-ldap";
  nodes.machine = {lib, ...}: {
    imports = [nextcloudModule];
    virtualisation = {
      memorySize = 4096;
      cores = 2;
      emptyDiskImages = [2048];
      fileSystems."/srv/nextcloud" = {
        device = "/dev/disk/by-label/nextcloud-state";
        fsType = "ext4";
        options = ["nofail"];
      };
    };
    nixcfg.nextcloud.dataDevice = "/dev/vdb";
    networking.extraHosts = "127.0.0.1 ldap.powerlan.empire nextcloud.powerlan.empire";
    security.pki.certificateFiles = ["${tls}/cert.pem"];
    environment.systemPackages = [pkgs.curl pkgs.jq pkgs.openldap];
    services.openldap = {
      enable = true;
      urlList = ["ldapi:///" "ldaps://127.0.0.1:636"];
      settings = {
        attrs = {
          olcTLSCertificateFile = "${tls}/cert.pem";
          olcTLSCertificateKeyFile = "${tls}/key.pem";
        };
        children = {
          "cn=schema" = {
            includes = map (name: "${pkgs.openldap}/etc/schema/${name}.ldif") ["core" "cosine" "inetorgperson"];
            children."cn=nextcloud-fixture".attrs = {
              objectClass = "olcSchemaConfig";
              cn = "nextcloud-fixture";
              olcAttributeTypes = [
                "( 1.3.6.1.4.1.4203.666.1.91 NAME 'ipaUniqueID' EQUALITY caseIgnoreMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.15 SINGLE-VALUE )"
                "( 1.3.6.1.4.1.4203.666.1.92 NAME 'nsAccountLock' EQUALITY booleanMatch SYNTAX 1.3.6.1.4.1.1466.115.121.1.7 SINGLE-VALUE )"
              ];
              olcObjectClasses = ["( 1.3.6.1.4.1.4203.666.2.90 NAME 'nextcloudFixture' SUP top AUXILIARY MAY ( ipaUniqueID $ nsAccountLock ) )"];
            };
          };
          "olcDatabase={1}mdb".attrs = {
            objectClass = ["olcDatabaseConfig" "olcMdbConfig"];
            olcDatabase = "{1}mdb";
            olcDbDirectory = "/var/lib/openldap/db";
            olcSuffix = base;
            olcRootDN = "cn=admin,${base}";
            olcRootPW = password;
            olcAccess = [
              "to attrs=userPassword by anonymous auth by self write by * none"
              "to * by dn.exact=\"${reader}\" read by * none"
            ];
          };
        };
      };
      declarativeContents.${base} = contents;
    };
    systemd = {
      services.nextcloud-ldap = {
        after = ["openldap.service"];
        requires = ["openldap.service"];
      };
      timers.openbao-consumer.enable = lib.mkForce false;
    };
    system.stateVersion = "26.05";
  };
  testScript = ''
    import json

    machine.start()
    machine.wait_until_succeeds("runuser -u nextcloud -- nextcloud-occ status --output=json | jq -e '.installed == true'")
    machine.wait_for_unit("openldap.service")
    machine.wait_for_unit("nginx.service")
    machine.succeed("install -m 0600 /dev/stdin /srv/nextcloud/secrets/ldap-bind-password <<<'${password}'")
    machine.succeed("systemctl start nextcloud-ldap.service")
    machine.succeed("runuser -u nextcloud -- nextcloud-occ ldap:test-config s01")

    curl = "curl --fail --silent --show-error -H 'Host: nextcloud.powerlan.empire' --user alice:${password} "
    endpoint = "http://127.0.0.1:8080"
    identity_url = endpoint + "/ocs/v2.php/cloud/user?format=json"
    account = json.loads(machine.succeed(curl + "-H 'OCS-APIRequest: true' '" + identity_url + "'"))["ocs"]["data"]["id"]
    assert account
    dav = endpoint + "/remote.php/dav/files/" + account + "/probe.txt"
    machine.succeed(curl + "-X PUT --data-binary 'persistent LDAP file' '" + dav + "'")
    assert machine.succeed(curl + "'" + dav + "'") == "persistent LDAP file"

    with subtest("wrong password and nonmember are refused"):
        for user in ["alice:wrong-password", "outsider:${password}"]:
            code = machine.succeed("curl --silent --output /dev/null --write-out '%{http_code}' -H 'Host: nextcloud.powerlan.empire' --user '" + user + "' '" + identity_url + "'")
            assert code == "401", code

    with subtest("TLS verification cannot be bypassed by an untrusted LDAP CA"):
        machine.fail("runuser -u nextcloud -- env LDAPTLS_CACERT=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt nextcloud-occ ldap:test-config s01")

    with subtest("repeat setup retains one provider and the same account"):
        machine.succeed("systemctl restart nextcloud-ldap.service")
        providers = json.loads(machine.succeed("runuser -u nextcloud -- nextcloud-occ ldap:show-config --output=json"))
        assert list(providers) == ["s01"]
        assert machine.succeed("stat -c %a /srv/nextcloud/secrets/admin-password").strip() == "600"
        machine.succeed("sync")
        machine.shutdown()
        machine.start()
        machine.wait_for_unit("nextcloud-ldap.service")
        machine.wait_for_unit("nginx.service")
        after = json.loads(machine.succeed(curl + "-H 'OCS-APIRequest: true' '" + identity_url + "'"))["ocs"]["data"]["id"]
        assert after == account
        assert machine.succeed(curl + "'" + dav + "'") == "persistent LDAP file"

    with subtest("reader password rotation is applied without a duplicate provider"):
        machine.succeed("ldapmodify -x -H ldaps://ldap.powerlan.empire -D 'cn=admin,${base}' -w '${password}' <<'EOF'\ndn: ${reader}\nchangetype: modify\nreplace: userPassword\nuserPassword: synthetic-rotated-password-123456789\nEOF")
        machine.succeed("printf '%s' synthetic-rotated-password-123456789 > /srv/nextcloud/secrets/ldap-bind-password")
        machine.succeed("systemctl restart nextcloud-ldap.service")
        machine.succeed("runuser -u nextcloud -- nextcloud-occ ldap:test-config s01")
        assert machine.succeed(curl + "'" + dav + "'") == "persistent LDAP file"

    with subtest("existing incompatible UUID mapping is refused"):
        machine.succeed("runuser -u nextcloud -- nextcloud-occ ldap:set-config s01 ldapExpertUUIDUserAttr uid")
        machine.fail("systemctl restart nextcloud-ldap.service")
        machine.succeed("runuser -u nextcloud -- nextcloud-occ ldap:set-config s01 ldapExpertUUIDUserAttr ipaUniqueID")
        machine.succeed("systemctl restart nextcloud-ldap.service")
  '';
}
