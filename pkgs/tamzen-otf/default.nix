{
  runCommand,
  tamzen,
  bdf2sfd,
  fontforge,
}:
runCommand "tamzen-otf-${tamzen.version}" {
  nativeBuildInputs = [bdf2sfd fontforge];
  inherit (tamzen) src meta;
} ''
  mkdir -p "$out/share/fonts/opentype"
  fontforge -lang py -script ${./convert.py}
''
