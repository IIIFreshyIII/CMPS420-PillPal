# Shrinking Med7 into a phone-sized model

The goal: a small model that does Med7's job (label DRUG / STRENGTH / DOSAGE /
FORM / ROUTE / FREQUENCY / DURATION in text) but is small and fast enough to run
inside the phone app.

## First, clearing up two things

**"Med7 trains MobileBERT" — sort of, but the cleaner version is:**
We *generate* fake labels from known pieces, so we already know the correct
answer for every one — no labelling needed. Med7's real jobs are (1) it defines
the 7 categories we use, and (2) it's the **yardstick** we measure our new model
against. Using the generator's own answers ("gold" labels) rather than Med7's
avoids copying Med7's mistakes (e.g. missing drug names in ALL CAPS) and is less
work. We keep Med7 as the thing to beat.

**"Setting weights" — you don't.**
The base model (DistilBERT or MobileBERT) already knows English from Google's
pre-training. It does **not** know what a "drug name" is. Training = showing it
our labelled examples over and over:

1. For each example, the model guesses a tag for every word.
2. We compute how wrong the whole guess was — one number, the **loss**.
3. An **optimiser** nudges the model's millions of internal numbers ("weights")
   a tiny step in the direction that would have lowered the loss.
4. Repeat for every example, a few passes through the data (**epochs**).
5. Loss goes down, predictions get better. You never touch a weight by hand.

Your job is: good data, pick a handful of settings (learning rate, epochs, batch
size), and watch the score on held-out examples.

## The pipeline

```
label_generator.py   fake labels + exact answers. Vocab is pre-split into a
                     TRAIN pool and a disjoint HELD-OUT pool (drugs, pharmacies,
                     phrasings) so the test set contains things never trained on.
                                                            ─┐
make_dataset.py      run generator ×N -> train / val /       │  Med7 also scored
                     test_seen / test_unseen  (JSONL)        │  here on both test
                     + holdout_manifest.json                 │  sets = baseline
                                                            │
train_ner.py         fine-tune DistilBERT/MobileBERT on      │
                     train; pick best epoch on val           │
                                                            │
evaluate.py          score on test_seen AND test_unseen,    ─┘
                     next to Med7.  The seen->unseen drop is the headline number.
                                                            │
(optimum-cli)        export model -> ONNX -> quantise (~4× smaller)
                                                            │
Flutter app          run the .onnx file on the phone
```

**Why two test sets:** `test_seen` uses training-pool vocab (fresh instances) —
"can it handle labels like the ones it trained on?". `test_unseen` uses the
held-out drugs / pharmacies / phrasings — "does it *generalise*, or did it just
memorise the drug list?". A model that scores 0.99 on seen and 0.70 on unseen has
memorised. Small gap = real learning.

### Run it — one command

```bash
cd distill
bash run.sh                                  # distilbert, 5000 labels, 5 epochs
bash run.sh --noise 0.02 --name noisy        # + OCR-style corruption
bash run.sh --base google/mobilebert-uncased --name mobilebert --lr 5e-5 --epochs 6
```

`run.sh` builds the dataset, fine-tunes, evaluates, and writes everything to
`run-<name>-<timestamp>.log`. Each `--name` gets its own `data-<name>/` and
`model-<name>/` so runs don't clobber each other. It auto-picks `.venv-gpu` if
present, else `.venv`.

Or run the three stages by hand:

```bash
python make_dataset.py --n-train 4000 --out data/     # --noise 0.02 optional
python train_ner.py    --data data/ --base-model distilbert-base-uncased --epochs 4
python evaluate.py      --model ner-model --data data/
```

DistilBERT first — smoothest to get working. Then try
`--base google/mobilebert-uncased` (smaller, ~25M vs 66M params) and compare size
vs accuracy; MobileBERT can be fussier, so lower the LR (`--lr 5e-5`) and add an
epoch if it won't learn.

Runs on the homelab 3060 Ti in ~2 minutes (see SERVER.md). Laptop CPU works but
takes ~15–20 min.

### Convert for the phone (after you're happy with accuracy)

```bash
pip install "optimum[exporters,onnxruntime]"
optimum-cli export onnx --model ner-model ner-onnx/
python -m onnxruntime.quantization.preprocess --input ner-onnx/model.onnx --output ner-onnx/model-infer.onnx
# then dynamic int8 quantisation -> ner-onnx/model.quant.onnx  (see optimum docs)
```

You ship `model.quant.onnx` + the tokenizer's vocab file in the app.

## What "good" looks like

- Med7 scores F1 ≈ 0.86 on our synthetic labels (about the same on seen and
  unseen — it never trained on any of it), but its **DRUG** score is low because
  our labels are often ALL CAPS.
- Targets for the distilled model:
  - `test_unseen` F1 within ~0.05 of `test_seen` F1  → it generalises
  - overall F1 on `test_unseen` ≥ Med7's ≈ 0.86      → it's a real replacement
  - **beat Med7 on DRUG**, because the gold labels teach the ALL-CAPS cases
- Small model close to Med7 on held-out data, at a fraction of the size, running
  on a phone — that's the result.

## The honest risks

1. **Synthetic-data gap.** Even `test_unseen` is still *generated* text. If real
   OCR'd labels look very different, the model won't transfer. Mitigations:
   (a) `--noise 0.02` so training sees OCR-style corruption;
   (b) photograph ~20–50 real or realistic mock labels, OCR them, hand-correct
   the fields, save as `data/real_test.jsonl` — `evaluate.py` picks it up
   automatically. That score is the one that actually matters, and it doubles as
   the spec's required user-testing data.
2. **On-phone tokenizer.** The model needs its text split into tokens the exact
   same way in Dart as in Python. DistilBERT/MobileBERT use "WordPiece", which is
   simpler to port than most; some Flutter ONNX packages bundle it.
3. **Time.** Generator + dataset + first training run + evaluation is a
   ~2-week job for one person. The ONNX-on-phone step is the less predictable
   part — start it early in Month 2, keep the rules + drug-list fallback ready.
