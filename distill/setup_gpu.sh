#!/usr/bin/env bash
# One-time setup on the homelab GPU server (Linux + NVIDIA).
#
#   bash setup_gpu.sh              # auto: installs CUDA 12.1 torch (driver >= 525)
#   CUDA=cu124 bash setup_gpu.sh   # pick another wheel if your driver is newer/older
#
# Check your driver first:  nvidia-smi  -> top-right "CUDA Version:"
#   >= 12.4  -> CUDA=cu124   (or leave default cu121, also fine)
#   12.1-12.3-> CUDA=cu121   (default)
#   11.8     -> CUDA=cu118
set -euo pipefail

CUDA="${CUDA:-cu121}"
HERE="$(cd "$(dirname "$0")" && pwd)"
VENV="$HERE/../.venv-gpu"

echo ">> creating venv at $VENV"
python3 -m venv "$VENV"
"$VENV/bin/pip" install -q --upgrade pip

echo ">> installing PyTorch ($CUDA)"
"$VENV/bin/pip" install -q torch --index-url "https://download.pytorch.org/whl/$CUDA"

echo ">> installing the rest"
"$VENV/bin/pip" install -q \
  "transformers>=4.40" "datasets>=2.19" "accelerate>=1.1" "seqeval>=1.2" gliner \
  "spacy==3.8.14" "click>=8.1" python-dateutil "Pillow>=10" pytesseract \
  "en-core-med7-lg @ https://huggingface.co/kormilitzin/en_core_med7_lg/resolve/main/en_core_med7_lg-1.1.0-py3-none-any.whl"

command -v tesseract >/dev/null || echo ">> NOTE: the OCR binary is missing -- run:  sudo apt install tesseract-ocr"

echo ">> checking GPU is visible to PyTorch"
"$VENV/bin/python" - <<'PY'
import torch
print("torch:", torch.__version__)
print("cuda available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("device:", torch.cuda.get_device_name(0))
    free, total = torch.cuda.mem_get_info()
    print(f"vram: {free/1e9:.1f} GB free / {total/1e9:.1f} GB total")
PY

echo
echo "Done. Use $VENV/bin/python to run make_dataset.py / train_ner.py / evaluate.py"
