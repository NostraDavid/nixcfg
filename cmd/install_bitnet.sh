#!/usr/bin/env bash
nix-shell -p cmake llvmPackages_20.clangUseLLVM
git clone --recursive https://github.com/microsoft/BitNet.git
cd BitNet
uv venv --python 3.9
source .venv/bin/activate
uv pip install -r requirements.txt --prerelease=allow --index-strategy unsafe-best-match
hf download microsoft/BitNet-b1.58-2B-4T-gguf --local-dir models/BitNet-b1.58-2B-4T
uv pip install pip --upgrade
uv run setup_env.py -md models/BitNet-b1.58-2B-4T -q i2_s
uv run run_inference.py -m models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf -p "You are a helpful assistant" -cnv
