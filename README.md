# PillPal — Med-Tracker (CMPS 420, Phase 1)

Photograph a prescription label → the app extracts the fields → you confirm every
one → it becomes a tracked medication with refill reminders. Fully on-device.

Read **`med-tracker-spec.md`** for the design and the non-negotiables:

- NER only, no generative LLM in the extraction path (avoid made-up info)
- refill date is arithmetic (`fill date + days supply`), never predicted
- every field is human-confirmed before anything is saved
- the source photo is deleted right after confirmation
- local-first — the whole pipeline runs on the phone

## Repo layout

| path | what it is |
|------|-----------|
| `app/` | **The Flutter app.** The product. See `app/README.md`. |
| `distill/` | **Trains the on-device NER model.** Generates synthetic labels, distils Med7 into DistilBERT, evaluates it, exports to ONNX (int8, ~67 MB, shipped in `app/assets/ner/`). See `distill/DISTILLATION.md` and `distill/SERVER.md`. |
| `med7_pipeline.py` | The original computer-only prototype: OCR → Med7 → regex → confirm → refill math. Kept as a reference and a quick way to eyeball Med7. |
| `compare_models.py` | One-off: Med7 vs candidate on-device models on the sample labels. |
| `notebooks/med7_colab.ipynb` | Med7 quickstart in Colab (synthetic labels only). |
| `sample_labels/` | A couple of synthetic label texts for testing. |

## Key decisions so far

- **Everything runs on the phone.** No backend. (Med7 itself can't — spaCy has no
  mobile export — so Med7 became the *reference* we distil from and measure against.)
- **App framework: Flutter.**
- **On-device model:** DistilBERT (66M), fine-tuned on synthetic labels whose gold
  answers come from a generator, with Med7 as the baseline. MobileBERT (25M) was
  tried for its smaller size but rejected — it collapsed under int8 quantization
  (F1 ≈ 0.03) while DistilBERT quantized losslessly. Runs via ONNX Runtime in the app.
- **Encrypted storage:** SQLCipher via `drift` (not yet built).

## Where to start

- **App lane:** `cd app`, then `app/README.md`. First runnable slice (list →
  capture → confirm → save) is done and tested. Next: the real `OnnxExtractor`
  (Dart tokenizer + decode, see `distill/infer.py` for the Python reference).
- **Model lane:** `cd distill`, then `DISTILLATION.md`. Pipeline is done: the
  29-photo real-label eval set exists, and the shipped model scores 0.686 F1
  on it (vs Med7's 0.477). Remaining model-lane work is optional (growing the
  real-label set, tightening FREQUENCY).
- **Research lane:** user interviews — 0 of the target 6 conducted so far, the
  current gap; see `USER_RESEARCH.md` for the interview script + personas.

## The original prototype (`med7_pipeline.py`)

Runs on a computer, not the phone. Useful for seeing what Med7 does.

```bash
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
sudo apt install tesseract-ocr          # only needed for --image

python med7_pipeline.py --text "$(cat sample_labels/example1.txt)"
python med7_pipeline.py --image path/to/label.jpg --delete-image --out profile.json
```

Known limits: Med7 (`en_core_med7_lg`) is trained on clinical prose, so it misses
drug names in ALL-CAPS label layout and scores ~0.79 F1 on label-format text —
which is the whole reason the `distill/` pipeline exists.
