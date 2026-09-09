{
  fetchPypi,
  lib,
  python3Packages,
}:
python3Packages.buildPythonPackage rec {
  pname = "model2vec";
  version = "0.9.0";
  pyproject = true;
  src = fetchPypi {
    inherit pname version;
    hash = "sha256-9QIpzqEoydtc+nshc0eClL48hOXT1/uEh+vXryhTg6s=";
  };
  build-system = with python3Packages; [setuptools setuptools-scm];
  dependencies = with python3Packages; [jinja2 joblib numpy safetensors tokenizers tqdm huggingface-hub];
  pythonImportsCheck = ["model2vec"];
  meta = {
    description = "Static text embeddings for local semantic retrieval";
    homepage = "https://github.com/MinishLab/model2vec";
    license = lib.licenses.mit;
  };
}
