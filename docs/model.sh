#!/usr/bin/env bash

llama-server --model ~/.cache/huggingface/hub/models--Qwen--Qwen2.5-7B-Instruct-GGUF/snapshots/bb5d59e06d9551d752d08b292a50eb208b07ab1f/qwen2.5-7b-instruct-fp16-00001-of-00004.gguf --port 8000 --chat-template chatml --n-gpu-layers 999
