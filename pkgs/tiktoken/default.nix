{
  lib,
  fetchurl,
  python3Packages,
}:
python3Packages.buildPythonPackage rec {
  pname = "tiktoken";
  version = "0.13.0";
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/86/f5/bab735d2c72ea55404b295d02d092644eb5f7cc6205e34d35eb9abfb9ab2/tiktoken-0.13.0-cp313-cp313-manylinux_2_28_x86_64.whl";
    hash = "sha256-XmNYkRyrSt7mcS2ifWVXNJak9oz4orX8pqStEPxXSM8=";
  };

  dependencies = with python3Packages; [
    blobfile
    regex
    requests
  ];

  pythonImportsCheck = ["tiktoken"];

  meta = {
    description = "Fast BPE tokeniser for use with OpenAI models";
    homepage = "https://github.com/openai/tiktoken";
    license = lib.licenses.mit;
    platforms = ["x86_64-linux"];
  };
}
