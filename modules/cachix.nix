{...}: {
  # Pull from commonly used Cachix binary cache to reduce local builds.
  nix.settings = {
    extra-substituters = [
      "https://nix-community.cachix.org"
    ];
    extra-trusted-public-keys = [
      "nix-community.cachix.org-1:mB9FSzHXK6P9M4RTbtf6WXwDqfSx7rJyYvG3BQY6x8o="
    ];
  };
}
