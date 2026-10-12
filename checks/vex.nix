let
  flake = builtins.getFlake (toString ../.);
  statementId = "https://example.invalid/vex/test-conditional";
  fixture = builtins.toFile "vex-condition-test.json" (builtins.toJSON {
    "@context" = "https://openvex.dev/ns/v0.2.0";
    "@id" = "https://example.invalid/vex/test";
    author = "nixcfg test fixture";
    timestamp = "2026-10-12T00:00:00Z";
    version = 1;
    statements = [
      {
        "@id" = statementId;
        vulnerability.name = "TEST-CONDITIONAL";
        products = [{"@id" = "pkg:nix/test-fixture@1";}];
        status = "not_affected";
        justification = "vulnerable_code_not_present";
        status_notes = "[nixos-vex:condition=no-user-mounts]";
      }
    ];
  });
  evaluate = enable:
    (flake.nixosConfigurations.wodan.extendModules {
      modules = [
        ({lib, ...}: {
          nixosVex.feed = fixture;
          services.udisks2.enable = lib.mkForce enable;
        })
      ];
    }).config.nixosVex;
  holds = evaluate false;
  fails = evaluate true;
in
  assert builtins.length holds.generated.statements == 1;
  assert holds.dropped == {};
  assert fails.generated.statements == [];
  assert fails.dropped."no-user-mounts" == [statementId]; true
