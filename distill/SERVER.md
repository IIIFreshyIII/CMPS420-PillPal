# Running the model work on the homelab GPU server

Your RTX 3060 Ti (8 GB) is *far* more than these small models need — DistilBERT /
MobileBERT token-classification fine-tuning uses roughly 2–3 GB of VRAM. Training
that took ~15 min on the laptop CPU drops to well under a minute on the GPU.

**This does not change the app's architecture.** The server is a *development*
machine — it trains the model and can host Med7 as the reference. The phone app
still runs the finished model fully on-device. This is the same as using Google
Colab, just your own hardware.

## 1. Get / update the code

The repo is on GitHub. First time on the server:

```bash
# add an SSH key once: ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
#   then paste ~/.ssh/id_ed25519.pub at github.com -> Settings -> SSH keys
git clone git@github.com:IIIFreshyIII/CMPS420-PillPal.git ~/Projects/CMPS420-PillPal
```

After that, just `git pull`. The venvs, generated `data-*/`, `model-*/`, and run
logs are gitignored — regenerate them on the server. The generator is seeded, so
`make_dataset.py` produces identical data on any machine.

## 2. One-time server setup

```bash
cd ~/Projects/CMPS420-PillPal/distill
nvidia-smi                       # note the "CUDA Version" top-right
bash setup_gpu.sh                # or:  CUDA=cu124 bash setup_gpu.sh
```
This makes `.venv-gpu/` (at the repo root) and prints whether PyTorch sees the GPU.

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
cd ~/Projects/CMPS420-PillPal/distill

bash run.sh                                              # baseline: distilbert, 5000 labels
bash run.sh --noise 0.02 --name noisy                    # with OCR corruption
bash run.sh --base google/mobilebert-uncased --name mobilebert --lr 5e-5 --epochs 6
```

`run.sh` does dataset -> train -> evaluate in one shot, logs to
`run-<name>-<timestamp>.log`, and auto-detects `../.venv-gpu`. Each `--name` keeps
its own `data-<name>/` and `model-<name>/`. `evaluate.py` reports F1 on
`test_seen` and `test_unseen` plus the generalisation gap.

With the GPU you can afford `--n 8000`+, more epochs, and quick experiments with
`--base bert-base-uncased` / `--base roberta-base` as a "how good could it get"
ceiling. Batch 64 fits easily in 8 GB.

## 5. Long runs without babysitting the SSH session

```bash
tmux new -s train
bash run.sh --name baseline
#   Ctrl-b then d  to detach;  tmux attach -t train  to come back
```

The run also streams to `run-baseline-<timestamp>.log`, so even if the session
dies you get the full output with `cat run-baseline-*.log`.

## 6. The app lane also lives here

Flutter is installed on this server too (`snap install flutter`). `flutter test`
and `flutter analyze` run headless. To *see* the UI without a phone or emulator:

```bash
cd ~/Projects/CMPS420-PillPal/app
flutter run -d web-server --web-port 8080
```

then open `http://<server-ip>:8080` from the laptop browser.

VS Code's "Remote - SSH" extension lets you edit and run on the server from the
laptop as if the files were local.
