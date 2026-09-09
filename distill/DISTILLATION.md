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
                     next to Med7  (+ real_test.jsonl if present).
                                                            │
(optimum-cli)        export model -> ONNX -> quantise (~4× smaller)
                                                            │
Flutter app          run the .onnx file on the phone
```

**Why two synthetic test sets:** `test_seen` uses training-pool vocab (fresh
instances); `test_unseen` uses the held-out drugs / pharmacies / phrasings. The
seen→unseen gap is a *memorisation check* — a big drop means it memorised the drug
list. In practice both saturate near 1.0 (see "The real evaluation" below), so
this gap is a sanity check, not the deliverable.

### Run it — one command

```bash
cd distill
bash run.sh                                  # distilbert, 5000 labels, 5 epochs, clean
bash run.sh --noise 0.01 --name noisy        # + OCR-style corruption (see below)
bash run.sh --base google/mobilebert-uncased --name mobilebert --lr 5e-5 --epochs 6
```

`--noise 0.01` makes the generator mimic what RapidOCR / ML Kit actually do to a
curved bottle label:

- **drops whole lines / regions** it can't segment
- **deletes the space between fields** — `ATOMOXETINE25MGCAP`, `capsule3times`
- **truncates the tail of a line** that wraps off the bottle — `by mouth in the`
- **garbles characters**, harder on the low-contrast boilerplate than the fields
- interleaves the stuff that sits next to the fields on a real label —
  manufacturer names, `Generic for NEURONTIN`, `NDC …`, `*THANK YOU*`,
  `for nerve pain` — all left unlabelled, so the model learns to output nothing
  there instead of guessing DRUG / FREQUENCY

Spans are clipped or dropped to match. The rate is calibrated: at `--noise 0.01`
Med7 scores ~0.45 on the synthetic set — the same as it scores on the real
labels — so a model trained at that rate is training on the right difficulty.
(`0.0` = clean, ~0.74 for Med7; `0.02`+ is harder than the real photos.)

`run.sh` builds the dataset, fine-tunes, evaluates, and writes everything to
`run-<name>-<timestamp>.log`. Each `--name` gets its own `data-<name>/` and
`model-<name>/` so runs don't clobber each other. It auto-picks `.venv-gpu` if
present, else `.venv`.

Or run the three stages by hand:

```bash
python make_dataset.py --n-train 4000 --out data/     # --noise 0.01 optional
python train_ner.py    --data data/ --base-model distilbert-base-uncased --epochs 4
python evaluate.py      --model ner-model --data data/
```

DistilBERT first — smoothest to get working. Then try
`--base google/mobilebert-uncased` (smaller, ~25M vs 66M params) and compare size
vs accuracy; MobileBERT can be fussier, so lower the LR (`--lr 5e-5`) and add an
epoch if it won't learn.

Runs on the homelab 3060 Ti in ~2 minutes (see SERVER.md). Laptop CPU works but
takes ~15–20 min.

### Convert for the phone

PyTorch can't run in a Flutter app; ONNX Runtime can. `export_onnx.py` exports
the checkpoint to ONNX, makes **fp16** and **int8-dynamic** variants, and scores
all three next to the PyTorch parent on the real-label set so we know
quantization didn't wreck the number.

```bash
# on the server (.venv-gpu has the checkpoints)
python export_onnx.py --model model-mobile  --data data-mobile
python export_onnx.py --model model-noisy2  --data data-noisy2
```

Prints a table: per-variant real F1 / test_unseen F1 / DRUG F1 / **file size MB** /
**CPU latency ms**. Pick the **smallest variant whose real F1 stays within ~0.03
of PyTorch and ≥ 0.53** (still clears Med7). Expected winner: MobileBERT int8
(~25 MB). Contingency: MobileBERT fp16 (~50 MB, full accuracy — but phone CPUs
have no fast fp16 path, so it's the same speed as fp32) or DistilBERT int8.

```bash
# copy the winner + tokenizer + drug list into the app
python export_onnx.py --model model-mobile --variant int8 --emit ../app/assets/ner
```

Ships in `app/assets/ner/`: `model.quant.onnx`, `vocab.txt`, `labels.json`,
`config.json` (id2label), tokenizer config, `drug_names.txt`.

### Validation layer (RxNorm + closed sets)

The model's weak spot is DRUG precision (~0.4 — it tags manufacturer names,
"Generic for NEURONTIN", OCR garble as drugs). `postprocess.py` checks every
span against a controlled vocabulary — the standard clinical-NER architecture
(model proposes, terminology validates):

- **DRUG** → RxNorm list (`drug_vocab.DrugMatcher`, ~10k names, built from the
  freely-redistributable RxNorm *Prescribable Content* subset — no UMLS login).
  Exact / salt-stripped / fuzzy (edit-dist ≤ 2) match → normalize + tighten the
  span to the drug name (`ATOMOXETINE25M` → `atomoxetine`, span shrunk).
  Manufacturer / non-word garble → **dropped**. Unknown-but-plausible → kept and
  **flagged** ("not a recognized drug name — verify"), never silently deleted,
  because every field is human-confirmed anyway.
- **FORM** → ~25-item set (`tab`→`tablet`, `er cap`→`capsule`, …)
- **ROUTE** → ~20-item set (`po`/`orally`→`by mouth`, `affected area`→`topically`)
- **STRENGTH / DOSAGE** → kept; flagged if no digit / number-word
- **FREQUENCY / DURATION** → passthrough (too open-ended for a list)

```bash
python drug_vocab.py --build                          # -> distill/drug_names.txt (committed)
python infer.py --onnx onnx-mobile --data data-mobile --eval   # model-alone vs model+refine on real_test
python infer.py --onnx onnx-mobile --text "<a real OCR block>"  # eyeball end-to-end fields
```

`infer.py` is the Python reference for the whole phone pipeline (model → refine →
first span per type → `Extraction` fields; `_regex_fields` from `med7_pipeline`
for fill date / days supply). The Dart `OnnxExtractor` must reproduce it.

## The real evaluation

The synthetic `test_seen` / `test_unseen` scores saturate near 1.0 — a 66M-param
model learns a template generator no matter how much vocab or structural variety
we add, so those numbers do NOT predict real-world performance. They're only good
for *relative* comparisons on a fixed set (noise on/off, DistilBERT vs MobileBERT,
training-set size).

The number that matters comes from real label photos the generator never made:

```bash
# optional warm-up: mock label IMAGES to test the OCR path end to end
python make_mock_label_images.py --n 18 --out mock_labels/
python build_real_testset.py --images mock_labels/ --out data/     # needs tesseract-ocr; Med7 pre-annotates
#   -> edit data/real_test.draft.txt:
#      - fix the [text](LABEL) marks
#      - where OCR garbled a field, add its real value on the block's "@true" line
#      - replace any patient identifiers (name / Rx # / phone) with realistic fakes
python build_real_testset.py --finalize data/real_test.draft.txt --out data/   # runs a PII check
python evaluate.py --model model-run --data data/                  # reads real_test.jsonl

# then the same with 30-50 REAL label photos in place of mock_labels/
# re-running --images APPENDS new photos; it won't clobber your annotations
```

Only `data/real_test.jsonl` is committed (a `.gitignore` exception) — the raw
images and the `.draft.txt` stay local.

Mock images have template text, so they mostly test OCR robustness + tooling. Real
photos are the deliverable — target ~30-50, varied pharmacies/layouts/capture
conditions. That F1 doubles as the spec's required user-testing data.

Med7 as the baseline: F1 ≈ 0.79 on *clean* label-format text, but ≈ **0.47 on the
real OCR'd photos** (curved bottles, glued tokens, wrapped-off tails). That 0.47
is the bar.

Progress on the 29-label real set (exact-span F1):

| model / training | params | real_test F1 | vs Med7 0.47 |
|---|---:|---:|---|
| DistilBERT, clean synthetic (v1 generator) | 66M | 0.43–0.45 | loses — over-predicts DRUG on manufacturer names + OCR garble |
| DistilBERT, clean synthetic (v2: +vocab, distractors) | 66M | 0.51 | edges ahead |
| DistilBERT, **`--noise 0.01`** (v2 + gluing/truncation/distractors) | 66M | 0.58 | wins by ~0.10 |
| **MobileBERT, `--noise 0.01`** (6 ep, lr 5e-5) | **25M** | **0.59** | **wins, at 1/3 the size** |

MobileBERT (the actual phone-target model) ties the bigger DistilBERT and beats
Med7 — **this is the Phase 1 deliverable.** It trades: better FORM (0.80) and
DOSAGE (0.76), weaker DRUG (0.35, precision 0.39) and STRENGTH (0.53).

The `--noise 0.01` models' synthetic scores also drop to ~0.64 (from 1.0) and now
*track* the real score within ~0.06 — the synthetic eval finally means something.
n=29 so treat ±0.1 as noise, but every `--noise 0.01` model beats Med7.
Weakest entity across the board is DRUG precision (manufacturer / OCR-garble
false-positives) — the place to push next if the number needs to go up.

## The honest risks

1. **Synthetic-data gap.** Even `test_unseen` is still *generated* text. If real
   OCR'd labels look very different, the model won't transfer. Mitigations:
   (a) `--noise 0.01` so training sees realistic OCR corruption (gluing,
       truncation, distractor lines), calibrated to the real photos' difficulty;
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
