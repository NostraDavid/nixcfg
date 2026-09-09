{
  inputs,
  system,
  unstable,
  ...
}: {
  inherit (inputs) pi;
  inherit system;
  # pi still builds with both tsc (TypeScript 5) and the old tsgo command.
  typescript = unstable.typescript_5;
  typescript-go = unstable.typescript.overrideAttrs (old: {
    postInstall =
      old.postInstall
      + ''
        ln -s tsc "$out/bin/tsgo"
      '';
  });
}
