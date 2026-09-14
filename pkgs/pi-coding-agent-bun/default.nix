{
  pi,
  system,
  jq,
}:
pi.packages.${system}.coding-agent-bun.overrideAttrs (old: {
  nativeBuildInputs = old.nativeBuildInputs ++ [jq];
  # Bun's lockfile has the global rimraf pin but not npm's redundant nested
  # override. That mismatch makes Bun re-resolve dependencies in the sandbox.
  postPatch =
    old.postPatch
    + ''
      jq 'if .overrides.gaxios == {rimraf: .overrides.rimraf}
          then del(.overrides.gaxios) else . end' package.json > package.json.tmp
      mv package.json.tmp package.json
    '';
})
