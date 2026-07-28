{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "win11-icon-theme";
  version = "unstable-2025-07-28";

  src = fetchFromGitHub {
    owner = "yeyushengfan258";
    repo = "Win11-icon-theme";
    rev = "a5b460a407da143b32f19a503d7fcebb3edf2371";
    hash = "sha256-+GtOkOVSWlNTdKSs0R86LhnpbBZ21Y0ML3V8pwDUUSc=";
  };

  dontFixup = true;

  installPhase = ''
    runHook preInstall

    bash install.sh -t black -a -d "$out/share/icons" 2>/dev/null || true
    # Als install.sh faalt door parse bug, doe het handmatig voor de dark variant
    if [ ! -d "$out/share/icons/Win11-black-dark" ]; then
      echo "Manual install for dark variant..."
      THEME_DIR="$out/share/icons/Win11-black-dark"
      mkdir -p "$THEME_DIR"
      cp -r {COPYING,AUTHORS} "$THEME_DIR"
      cp -r src/index.theme "$THEME_DIR"
      sed -i "s/Win11/Win11-black-dark/g" "$THEME_DIR/index.theme"

      mkdir -p "$THEME_DIR"/{apps,categories,emblems,devices,mimes,places,status}
      cp -r src/actions "$THEME_DIR"
      cp -r src/apps/{22,32,symbolic} "$THEME_DIR/apps"
      cp -r src/categories/{22,symbolic} "$THEME_DIR/categories"
      cp -r src/emblems/symbolic "$THEME_DIR/emblems"
      cp -r src/mimes/symbolic "$THEME_DIR/mimes"
      cp -r src/devices/{16,22,24,32,symbolic} "$THEME_DIR/devices"
      cp -r src/places/{16,22,24,scalable,symbolic} "$THEME_DIR/places"
      cp -r src/status/symbolic "$THEME_DIR/status"

      cp -r alternative/apps/symbolic/*.svg "$THEME_DIR/apps/symbolic/"
      cp -r alternative/places/scalable/*.svg "$THEME_DIR/places/scalable/"
      cp -r colors/color-black/*.svg "$THEME_DIR/places/scalable/"

      # Dark color transform
      sed -i "s/#363636/#dedede/g" "$THEME_DIR"/{actions,devices,places}/{16,22,24}/*.svg
      sed -i "s/#363636/#dedede/g" "$THEME_DIR"/apps/{22,32}/*.svg
      sed -i "s/#363636/#dedede/g" "$THEME_DIR"/categories/22/*.svg
      sed -i "s/#363636/#dedede/g" "$THEME_DIR"/{actions,devices}/32/*.svg
      sed -i "s/#363636/#dedede/g" "$THEME_DIR"/{actions,apps,categories,emblems,devices,mimes,places,status}/symbolic/*.svg

      mv "$THEME_DIR/places/scalable/user-trash-dark.svg" "$THEME_DIR/places/scalable/user-trash.svg"
      mv "$THEME_DIR/places/scalable/user-trash-full-dark.svg" "$THEME_DIR/places/scalable/user-trash-full.svg"

      cp -r links/actions/{16,22,24,32,symbolic} "$THEME_DIR/actions"
      cp -r links/devices/{16,22,24,32,symbolic} "$THEME_DIR/devices"
      cp -r links/places/{16,22,24,scalable,symbolic} "$THEME_DIR/places"
      cp -r links/apps/{22,symbolic} "$THEME_DIR/apps"
      cp -r links/categories/{22,symbolic} "$THEME_DIR/categories"
      cp -r links/mimes/symbolic "$THEME_DIR/mimes"
      cp -r links/status/symbolic "$THEME_DIR/status"

      (
        cd "$THEME_DIR"
        ln -sf actions actions@2x
        ln -sf apps apps@2x
        ln -sf categories categories@2x
        ln -sf devices devices@2x
        ln -sf emblems emblems@2x
        ln -sf mimes mimes@2x
        ln -sf places places@2x
        ln -sf status status@2x
      )
    fi

    runHook postInstall
  '';

  meta = {
    description = "A colorful design icon theme for linux desktops";
    homepage = "https://github.com/yeyushengfan258/Win11-icon-theme";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
