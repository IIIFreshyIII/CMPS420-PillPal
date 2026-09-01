#!/usr/bin/env bash
#
# One command: build dataset -> fine-tune -> evaluate, with everything logged.
#
#   bash run.sh                                  # distilbert, 5000 labels, 5 epochs, no noise
#   bash run.sh --noise 0.02 --name noisy
#   bash run.sh --base google/mobilebert-uncased --name mobilebert --lr 5e-5 --epochs 6
#   bash run.sh --n 8000 --epochs 6 --name big
#
# Each --name gets its own data-<name>/ , model-<name>/ and run-<name>-<timestamp>.log
# so runs never clobber each other. Re-run with the same --name to overwrite it.

set -euo pipefail
cd "$(dirname "$0")"

# --- defaults ---
BASE=distilbert-base-uncased
N=5000; EPOCHS=5; BATCH=64; LR=3e-5; NOISE=0; NAME=run; PY=""

# --- args ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)   BASE=$2;   shift 2;;
    --n)      N=$2;      shift 2;;
    --epochs) EPOCHS=$2; shift 2;;
    --batch)  BATCH=$2;  shift 2;;
    --lr)     LR=$2;     shift 2;;
    --noise)  NOISE=$2;  shift 2;;
    --name)   NAME=$2;   shift 2;;
    --python) PY=$2;     shift 2;;
    -h|--help) sed -n '2,15p' "$0"; exit 0;;
    *) echo "unknown arg: $1  (see: bash run.sh --help)"; exit 1;;
  esac
done

# --- pick a python that has the deps ---
if [[ -z "$PY" ]]; then
  for c in ../.venv-gpu/bin/python ../.venv/bin/python python3; do
    if [[ -x "$(command -v "$c" || true)" || -x "$c" ]] && \
       "$c" -c "import transformers, torch, seqeval, datasets" 2>/dev/null; then
      PY=$c; break
    fi
  done
fi
[[ -z "$PY" ]] && { echo "No python with transformers/torch/seqeval/datasets found."; \
                    echo "Run  bash setup_gpu.sh  first (or pass --python <path>)."; exit 1; }

STAMP=$(date +%Y%m%d-%H%M)
DATA="data-$NAME"; MODEL="model-$NAME"; LOG="run-$NAME-$STAMP.log"

hr() { printf '%.0s-' {1..60}; echo; }

{
  hr
  echo "run          : $NAME"
  echo "python       : $PY"
  "$PY" -c "import torch;print('device       :', ('cuda '+torch.cuda.get_device_name(0)) if torch.cuda.is_available() else 'cpu (slow)')"
  echo "base model   : $BASE"
  echo "labels       : $N   epochs: $EPOCHS   batch: $BATCH   lr: $LR   noise: $NOISE"
  echo "data dir     : $DATA"
  echo "model dir    : $MODEL"
  hr

  echo ">>> [1/3] make_dataset  ($(date +%T))"
  "$PY" make_dataset.py --n-train "$N" --noise "$NOISE" --out "$DATA" --base-model "$BASE"

  echo; echo ">>> [2/3] train  ($(date +%T))"
  "$PY" train_ner.py --data "$DATA" --base-model "$BASE" \
        --epochs "$EPOCHS" --batch-size "$BATCH" --lr "$LR" --out "$MODEL"
  rm -rf "$MODEL"/checkpoint-*        # keep only the final model

  echo; echo ">>> [3/3] evaluate  ($(date +%T))"
  "$PY" evaluate.py --model "$MODEL" --data "$DATA"

  hr
  echo "done  ($(date +%T))    log: $LOG"
  hr
} 2>&1 | tee "$LOG"
