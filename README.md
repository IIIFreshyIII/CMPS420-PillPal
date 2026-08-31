# Med-Tracker — Phase 1 extraction prototype

Turns a prescription-label photo into a draft medication profile using **Med7**
(`en_core_med7_lg`, a spaCy NER model — *not* a generative LLM) plus deterministic
regex for the fields Med7 doesn't cover (fill date, days supply, quantity).

See `med-tracker-spec.md` for the design rules this implements:
- NER only, no generative model in the extraction path
- refill date is arithmetic (`fill_date + days_supply`), never predicted
- every field is human-confirmed before anything is "saved"
- the source photo is deleted right after confirmation

## What Med7 gives you

Seven entity labels: `DRUG`, `STRENGTH`, `DOSAGE`, `DURATION`, `FREQUENCY`,
`FORM`, `ROUTE`. F1 ≈ 0.889 on its held-out split. Runs fine on CPU.

## Run locally

```bash
cd "CMPS 420"
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# OCR backend (only needed for --image):
sudo apt install tesseract-ocr
```

Text in, no OCR:

```bash
python med7_pipeline.py --text "$(cat sample_labels/example1.txt)"
```

Photo in:

```bash
python med7_pipeline.py --image path/to/label.jpg --delete-image --out profile.json
```

`--no-confirm` skips the interactive review (dev only — the spec requires confirmation).

## Run in Google Colab

Open `notebooks/med7_colab.ipynb` in Colab, or paste this into a cell:

```python
!pip -q install "en-core-med7-lg @ https://huggingface.co/kormilitzin/en_core_med7_lg/resolve/main/en_core_med7_lg-1.1.0-py3-none-any.whl"
# If Colab complains about spaCy version, Runtime > Restart session, then re-run.

import spacy
nlp = spacy.load("en_core_med7_lg")
doc = nlp("Take 1 tablet of Metformin 500mg by mouth twice daily for 30 days.")
for ent in doc.ents:
    print(f"{ent.label_:<10} {ent.text}")
```

Note: Colab uploads your text to Google. Fine for synthetic test labels;
for real prescription data use the local path (the spec is local-first).

## Files

| file | purpose |
|------|---------|
| `med7_pipeline.py` | OCR → Med7 NER + regex → human confirm → profile + refill math |
| `requirements.txt` | pinned deps incl. the Med7 wheel URL |
| `sample_labels/` | synthetic label text for testing |
| `notebooks/med7_colab.ipynb` | Colab quickstart |

## What we learned testing it

- **Med7-lg is trained on clinical prose, not label layout.** A bare noun phrase like
  `METFORMIN HCL 500 MG TABLET` yields no `DRUG` tag; `take metformin hcl 500 mg tablet`
  does. `med7_pipeline.py` works around this by lowercasing/collapsing the OCR text and
  retrying each line with a `take ` lead-in — recovered `metformin hcl` on the sample.
  Still flagged "low confidence — verify" for the human step.
- Salt suffixes (`hcl`, `hydrochloride`) and adjacent strengths hurt `DRUG` recall.
  `en_core_med7_trf` (transformer variant) is more robust — worth trying if the lg
  model's drug misses are too frequent: needs `spacy-transformers` + `torch`.
- Fill date / days supply / quantity are **not** Med7 labels — they come from regex in
  `_regex_fields()`. Watch for the "Qty 60 ... Days supply 30" trap (fixed: colon-form
  pattern is tried first).

## Known gaps / next steps

- Tesseract is weak on angled/curved label photos — try EasyOCR (`pip install easyocr`)
  as a drop-in for `ocr_image()`.
- No persistence layer yet (spec calls for an encrypted local DB — SQLCipher TBD).
- "Auto-delete photo after inactivity" is not implemented here (belongs in the app layer).
- Consider a small deterministic drug lexicon (RxNorm subset) as a backstop for Med7 —
  fits the spec's "deterministic where possible" principle better than a second model.
