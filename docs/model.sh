#!/usr/bin/env bash

llama-server --model ~/.cache/huggingface/hub/models--Qwen--Qwen2.5-7B-Instruct-GGUF/snapshots/bb5d59e06d9551d752d08b292a50eb208b07ab1f/qwen2.5-7b-instruct-fp16-00001-of-00004.gguf --port 8000 --chat-template chatml --n-gpu-layers 999

curl -s http://localhost:11434/api/generate \
  -d '{
    "model": "qwen2.5:7b-instruct-q4_K_M",
    "prompt": "Say one sentence about Amsterdam.",
    "options": {
      "num_thread": 8,
      "num_ctx": 2048,
      "num_batch": 256,
      "temperature": 0.2,
      "top_p": 0.9,
      "num_predict": 256
    }
  }' | jq -r 'select(.done==true).response'

ollama run qwen2.5:7b-instruct-q4_K_M
