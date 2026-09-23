{
  inputs,
  system,
  unstable,
  ...
}: {
  inherit (inputs) pi;
  inherit system;
  # Keep the compiler on the TypeScript 5 package used by pi.nix.
  typescript = unstable.typescript_5;
}
