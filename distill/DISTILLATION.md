# Shrinking Med7 into a phone-sized model

The goal: a small model that does Med7's job (label DRUG / STRENGTH / DOSAGE /
FORM / ROUTE / FREQUENCY / DURATION in text) but is small and fast enough to run
inside the phone app.

## First, clearing up two things

**"Med7 trains MobileBERT" — sort of, but the cleaner version is:**
We *generate* fake labels from known pieces, so we already know the correct
answer for every one — no labelling needed. Med7's real jobs are (1) it defines
the 7 categories we use, and (2) it's the **yardstick** we measure our new model
against. You *can* literally have Med7 do the labelling (`make_dataset.py
--labels med7`), but then the new model also copies Med7's mistakes — like Med7
missing drug names in ALL CAPS. Using the generator's own answers ("gold" labels)
avoids that and is less work. We keep Med7 as the thing to beat.

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
label_generator.py   make fake labels + know every answer  ─┐
                                                            │
make_dataset.py       run generator ×N, split into           │  Med7 also runs here,
                      train / val / test  (JSONL)            │  scored vs gold = baseline
                                                            │
train_ner.py          fine-tune DistilBERT/MobileBERT on     │
                      train; check val after each epoch      │
                                                            │
evaluate.py           score the trained model on test,      ─┘
                      side by side with Med7   ← the table for your report
                                                            │
(optimum-cli)         export model -> ONNX -> quantise (~4× smaller)
                                                            │
Flutter app           run the .onnx file on the phone
```

### Run it

```bash
cd distill
python make_dataset.py --n 4000 --out data/
python train_ner.py    --data data/ --base-model distilbert-base-uncased --epochs 4
python evaluate.py      --model ner-model --data data/
```

DistilBERT first — it's the smoothest to get working. Once the whole pipeline
runs end to end, try `--base-model google/mobilebert-uncased` (smaller, ~25M vs
66M params) and compare size vs accuracy. MobileBERT can be fussier — if it won't
learn, lower the learning rate (`--lr 5e-5` or `1e-4`) and add an epoch.

Training on a laptop CPU works but is slow. Free option: paste these into a
Google Colab notebook, set Runtime → Change runtime type → GPU, and it's ~10–20
minutes.

### Convert for the phone (after you're happy with accuracy)

```bash
pip install "optimum[exporters,onnxruntime]"
optimum-cli export onnx --model ner-model ner-onnx/
python -m onnxruntime.quantization.preprocess --input ner-onnx/model.onnx --output ner-onnx/model-infer.onnx
# then dynamic int8 quantisation -> ner-onnx/model.quant.onnx  (see optimum docs)
```

You ship `model.quant.onnx` + the tokenizer's vocab file in the app.

## What "good" looks like

- Med7's published score is F1 ≈ 0.89. On our synthetic labels Med7 scores about
  the same **except DRUG**, where its recall is low (~0.3) because our labels are
  often ALL CAPS.
- A target: match Med7 overall (F1 ~0.85–0.90) and **beat it on DRUG**, because
  the gold labels teach the small model the ALL-CAPS cases Med7 misses.
- If the small model is close to Med7 at a fraction of the size and runs on a
  phone — that's the result, and the report writes itself.

## The honest risks

1. **Synthetic-data gap.** If real OCR'd labels look very different from our fake
   ones, the model won't transfer. Mitigation: photograph ~20 real (or realistic
   mock) labels, OCR them, hand-check the fields, and add them to `test.jsonl`.
   If the score holds up there, you're fine. Also: add OCR-style noise to the
   generator (random character swaps, missing spaces) so training sees messiness.
2. **On-phone tokenizer.** The model needs its text split into tokens the exact
   same way in Dart as in Python. DistilBERT/MobileBERT use "WordPiece", which is
   simpler to port than most; some Flutter ONNX packages bundle it.
3. **Time.** Generator + dataset + first training run + evaluation is a
   ~2-week job for one person. The ONNX-on-phone step is the less predictable
   part — start it early in Month 2, keep the rules + drug-list fallback ready.
