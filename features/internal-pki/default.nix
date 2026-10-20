_: {
  den.aspects.internal-pki = {
    nixos.imports = [
      {
        security.pki.certificateFiles = [
          ../../certs/freeipa.crt
          ../../certs/forgejo-ca.crt
        ];
      }
    ];
  };
}
