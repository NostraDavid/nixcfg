{
  fetchurl,
  fixedsys-excelsior,
}:
fixedsys-excelsior.overrideAttrs (finalAttrs: old: {
  version = "3.09.10";
  src = fetchurl {
    url = "https://github.com/kika/fixedsys/releases/download/v${finalAttrs.version}/FSEX302.ttf";
    hash = "sha256-hC+Pv4D1fYZ66x0piBQNPqi0cY5faHA1sKO2Z1bfOJk=";
  };
  meta = old.meta // {homepage = "https://github.com/kika/fixedsys";};
})
