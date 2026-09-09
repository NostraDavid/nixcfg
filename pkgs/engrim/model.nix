{
  fetchurl,
  linkFarm,
}: let
  # The embedding model has no release tags; pin its immutable snapshot.
  revision = "bf8b056651a2c21b8d2565580b8569da283cab23";
  files = {
    "config.json" = "sha256-KmrA6aqjVqaKVogHDbePw6Rk/v6F0vBqGQXONxhodVM=";
    "model.safetensors" = "sha256-9l0PMl+q3B4SHDGeL6pBFw0/oH2MiavUjKU1jZoiPeI=";
    "tokenizer.json" = "sha256-5n6AP2JPtNZ96hxzDQbhBn4bFNgw4sIgJWnj7w9wu1A=";
  };
in
  linkFarm "potion-base-8M" (builtins.map (name: {
      inherit name;
      path = fetchurl {
        url = "https://huggingface.co/minishlab/potion-base-8M/resolve/${revision}/${name}";
        hash = files.${name};
      };
    })
    (builtins.attrNames files))
