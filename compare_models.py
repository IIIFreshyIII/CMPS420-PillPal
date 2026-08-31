"""
Month-1 model bake-off: Med7 (computer-only yardstick) vs the two on-device
candidates — d4data/biomedical-ner-all (primary) and GLiNER (backup).

Run:  .venv/bin/python compare_models.py
      .venv/bin/python compare_models.py sample_labels/example1.txt

First run downloads the two models (~300 MB total) into the HuggingFace cache.
Everything runs on CPU.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# The fields we actually care about for the app.
TARGET = ["DRUG", "STRENGTH", "DOSAGE", "FORM", "ROUTE", "FREQUENCY", "DURATION"]

# GLiNER is zero-shot: we hand it these label names at runtime.
GLINER_LABELS = [
    "drug", "strength", "dose amount", "form", "route", "frequency", "duration",
]

# Map each model's label vocabulary onto our TARGET set.
D4DATA_MAP = {
    "Medication": "DRUG",
    "Dosage": "STRENGTH",        # d4data "Dosage" is usually the strength ("10 mg")
    "Administration": "ROUTE",
    "Form": "FORM",
    "Frequency": "FREQUENCY",
    "Duration": "DURATION",
    "Route": "ROUTE",
}
GLINER_MAP = {
    "drug": "DRUG", "strength": "STRENGTH", "dose amount": "DOSAGE",
    "form": "FORM", "route": "ROUTE", "frequency": "FREQUENCY", "duration": "DURATION",
}


def normalize(text: str) -> str:
    return re.sub(r"\s+", " ", text).strip()


# --------------------------------------------------------------------------- #
def run_med7(text: str) -> dict[str, list[str]]:
    import spacy

    nlp = spacy.load("en_core_med7_lg")
    out: dict[str, list[str]] = {t: [] for t in TARGET}
    for ent in nlp(normalize(text).lower()).ents:
        if ent.label_ in out:
            out[ent.label_].append(ent.text)
    return out


def run_d4data(text: str) -> dict[str, list[str]]:
    from transformers import pipeline

    ner = pipeline(
        "token-classification",
        model="d4data/biomedical-ner-all",
        aggregation_strategy="simple",
    )
    out: dict[str, list[str]] = {t: [] for t in TARGET}
    raw: dict[str, list[str]] = {}
    for span in ner(normalize(text)):
        grp = span["entity_group"]
        raw.setdefault(grp, []).append(span["word"])
        tgt = D4DATA_MAP.get(grp)
        if tgt:
            out[tgt].append(span["word"])
    out["_raw"] = raw  # keep everything it found, for inspection
    return out


def run_gliner(text: str) -> dict[str, list[str]]:
    from gliner import GLiNER

    model = GLiNER.from_pretrained("urchade/gliner_small-v2.1")
    out: dict[str, list[str]] = {t: [] for t in TARGET}
    for ent in model.predict_entities(normalize(text), GLINER_LABELS, threshold=0.4):
        tgt = GLINER_MAP.get(ent["label"])
        if tgt:
            out[tgt].append(ent["text"])
    return out


# --------------------------------------------------------------------------- #
def show(name: str, result: dict) -> None:
    print(f"\n{'='*60}\n{name}\n{'='*60}")
    for t in TARGET:
        vals = result.get(t, [])
        print(f"  {t:<10} {vals if vals else '—'}")
    if "_raw" in result:
        print("  (all raw groups it found:)")
        for grp, vals in result["_raw"].items():
            print(f"     {grp:<16} {vals}")


def main() -> None:
    paths = sys.argv[1:] or ["sample_labels/example1.txt", "sample_labels/example2.txt"]
    for p in paths:
        text = Path(p).read_text()
        print(f"\n\n######## {p} ########\n{text.strip()}")
        for name, fn in [("Med7 (yardstick)", run_med7),
                         ("d4data/biomedical-ner-all", run_d4data),
                         ("GLiNER small-v2.1", run_gliner)]:
            try:
                show(name, fn(text))
            except Exception as exc:  # keep going if one model errors
                print(f"\n{name}: FAILED — {type(exc).__name__}: {exc}")


if __name__ == "__main__":
    main()
