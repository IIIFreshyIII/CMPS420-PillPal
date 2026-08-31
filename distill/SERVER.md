# Running the model work on the homelab GPU server

Your RTX 3060 Ti (8 GB) is *far* more than these small models need — DistilBERT /
MobileBERT token-classification fine-tuning uses roughly 2–3 GB of VRAM. Training
that took ~15 min on the laptop CPU drops to well under a minute on the GPU.

**This does not change the app's architecture.** The server is a *development*
machine — it trains the model and can host Med7 as the reference. The phone app
still runs the finished model fully on-device. This is the same as using Google
Colab, just your own hardware.

## 1. Move the code

Don't copy `.venv/`, `data/`, `ner-model/`, or the HuggingFace cache — regenerate
those on the server. The generator is seeded, so `make_dataset.py` produces the
exact same data on any machine.

**Quick way (rsync over SSH):**
```bash
rsync -av --exclude .venv --exclude .venv-gpu --exclude 'distill/data' \
      --exclude 'distill/data_smoke' --exclude 'distill/ner-model' \
      "CMPS 420/" user@homelab:~/med-tracker/
```

**Better way for a team — put it in git:**
```bash
cd "CMPS 420"
git init && git add -A && git commit -m "Med-Tracker: extraction prototype + distillation pipeline"
# push to GitHub / your Gitea, then on the server:  git clone ...
```
(`.gitignore` already excludes the venvs and generated data.)

## 2. One-time server setup

```bash
cd ~/med-tracker/distill
nvidia-smi                       # note the "CUDA Version" top-right
bash setup_gpu.sh                # or:  CUDA=cu124 bash setup_gpu.sh
```
This makes `.venv-gpu/` and prints whether PyTorch sees the GPU.

## 3. Free up the GPU during training runs

Ollama holds a model in VRAM for 5 minutes after use by default. A 7B model
(~5–6 GB) plus training (~3 GB) can overflow 8 GB. Cleanest is to stop it for the
run:

```bash
sudo systemctl stop ollama
#   ... train ...
sudo systemctl start ollama
```

Or, to keep Ollama up but not pinning VRAM: `ollama stop <model>` right before
training, or set `OLLAMA_KEEP_ALIVE=0` in its service so models unload
immediately when idle.

Check what's on the card any time: `nvidia-smi`.

## 4. Run the pipeline (GPU)

```bash
cd ~/med-tracker/distill
V=../.venv-gpu/bin/python

$V make_dataset.py --n 6000 --out data/
$V train_ner.py   --data data/ --base-model distilbert-base-uncased --epochs 5 --batch-size 64
$V evaluate.py     --model ner-model --data data/

# then try the smaller target and compare size vs accuracy:
$V train_ner.py   --data data/ --base-model google/mobilebert-uncased --epochs 6 --lr 5e-5 --batch-size 64 --out ner-mobilebert
$V evaluate.py     --model ner-mobilebert --data data/
```

With the GPU you can afford bigger runs: `--n 6000`+, more epochs, and quick
experiments with `bert-base-uncased` or `roberta-base` as a "how good could it
get" ceiling. Batch size 64 fits easily in 8 GB for these models.

## 5. Long runs without babysitting the SSH session

```bash
tmux new -s train
#   ... start training ...
#   Ctrl-b then d  to detach;  tmux attach -t train  to come back
```

## 6. Optional: remote development

VS Code's "Remote - SSH" extension lets you edit and run on the server from your
laptop as if the files were local. Good for the model lane; the app lane keeps
working in Flutter locally.
