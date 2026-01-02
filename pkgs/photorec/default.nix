{
  lib,
  stdenvNoCC,
  fetchzip,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "photorec";
  version = "7.2";

  src = fetchzip {
    url = "https://www.cgsecurity.org/testdisk-${finalAttrs.version}.linux26-x86_64.tar.bz2";
    hash = "sha256-YNrP+BkYOqoRfPkktmqfu/I0A22xjo1hJoxSQTJXW4A=";
  };

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    install -Dm755 photorec_static $out/bin/photorec
    install -Dm755 testdisk_static $out/bin/testdisk
    install -Dm755 fidentify_static $out/bin/fidentify

    install -Dm644 photorec.8 $out/share/man/man8/photorec.8
    install -Dm644 testdisk.8 $out/share/man/man8/testdisk.8
    install -Dm644 fidentify.8 $out/share/man/man8/fidentify.8
  '';

  meta = {
    description = "File recovery tool and companion utilities from TestDisk";
    homepage = "https://www.cgsecurity.org/wiki/PhotoRec";
    license = lib.licenses.gpl2Plus;
    maintainers = with lib.maintainers; [
      dbreyfogle
    ];
    mainProgram = "photorec";
    platforms = ["x86_64-linux"];
    sourceProvenance = with lib.sourceTypes; [lib.sourceTypes.binaryNativeCode];
  };
})
