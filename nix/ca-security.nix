# Remove these backports when every pinned channel contains the security releases.
final: prev: let
  pipWheel = prev.fetchurl {
    url = "https://files.pythonhosted.org/packages/3f/06/3e4420302363fbb71be3c7f35ce042f54bfca330e3e66b3a2e3c4cca579f/pip-26.2.2-py3-none-any.whl";
    hash = "sha256-/X9N+oGQ4BQBO58I8+lz9OTCb/0XmiBIlVM6clSBOnA=";
  };
in {
  # Keep build interpreters unchanged; only the user's Python needs new seeds.
  python3Ca =
    prev.runCommand "${prev.python3.name}-ca" {
      passthru = {
        inherit (prev.python3) version pythonVersion executable;
        interpreter = "${final.python3Ca}/bin/${prev.python3.executable}";
      };
      inherit (prev.python3) meta;
    } ''
      cp -a ${prev.python3} "$TMPDIR/python"
      chmod -R u+w "$TMPDIR/python"
      ensurepip="$TMPDIR/python/lib/python${prev.python3.pythonVersion}/ensurepip"
      current=$(sed -n 's/^_PIP_VERSION = "\([^"]*\)"/\1/p' "$ensurepip/__init__.py")
      test -n "$current"
      if [ "$(printf '%s\n' "$current" 26.2.2 | sort -V | head -n1)" != 26.2.2 ]; then
        rm "$ensurepip"/_bundled/pip-*.whl
        cp ${pipWheel} "$ensurepip/_bundled/pip-26.2.2-py3-none-any.whl"
        substituteInPlace "$ensurepip/__init__.py" \
          --replace-fail "_PIP_VERSION = \"$current\"" '_PIP_VERSION = "26.2.2"'
        rm -rf "$ensurepip/__pycache__"
      fi
      mv "$TMPDIR/python" "$out"
    '';
  uv = prev.callPackage ../pkgs/uv {};
}
