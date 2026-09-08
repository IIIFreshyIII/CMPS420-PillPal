"""
Look at what the model ACTUALLY predicts on the real-label test set, span by span,
next to the gold and next to Med7. The aggregate F1 in evaluate.py tells you the
model is losing to Med7 on real labels; this tells you *why*.

    python diagnose_real.py --model model-noisy --data data-noisy
    python diagnose_real.py --model model-noisy --data data-noisy --entity DRUG

For each label it prints:
  - the OCR text
  - GOLD spans            (what the hand annotation says)
  - MODEL spans           (marked  ok / MISS / FALSE+  against gold, exact match)
  - MED7 spans
and at the end, a per-entity tally of false positives / misses for the model,
plus the model's false-positive DRUG strings (the over-prediction we suspect).
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path


def _load(path: Path):
    return [json.loads(l) for l in path.read_text().splitlines()]


def _norm(s: str) -> str:
    return " ".join(s.split()).lower()


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="model-noisy")
    ap.add_argument("--data", default="data-noisy")
    ap.add_argument("--entity", default=None, help="only show rows / tallies for this label")
    ap.add_argument("--no-med7", action="store_true")
    args = ap.parse_args()

    rows = _load(Path(args.data) / "real_test.jsonl")

    from transformers import AutoModelForTokenClassification, AutoTokenizer, pipeline

    tok = AutoTokenizer.from_pretrained(args.model)
    model = AutoModelForTokenClassification.from_pretrained(args.model)
    ner = pipeline("token-classification", model=model, tokenizer=tok,
                   aggregation_strategy="first")

    nlp = None
    if not args.no_med7:
        try:
            import spacy
            nlp = spacy.load("en_core_med7_lg")
        except Exception as exc:
            print(f"(Med7 unavailable: {exc})")

    fp = Counter()          # model predicted a span that isn't in gold
    miss = Counter()        # gold span the model didn't predict
    hit = Counter()
    fp_drug_strings = Counter()

    for r in rows:
        text = r["text"]
        gold = {(s, e, lab) for s, e, lab in r["entities"]}
        gold_by_norm = {(_norm(text[s:e]), lab) for s, e, lab in r["entities"]}

        pred = [(p["start"], p["end"], p["entity_group"]) for p in ner(text)]
        m7 = []
        if nlp is not None:
            m7 = [(e.start_char, e.end_char, e.label_) for e in nlp(text).ents
                  if e.label_ in {"DRUG", "STRENGTH", "DOSAGE", "FORM", "ROUTE",
                                  "FREQUENCY", "DURATION"}]

        if args.entity and not any(lab == args.entity for *_, lab in gold | set(pred)):
            continue

        print("\n" + "=" * 72)
        print(f"{r['source']}")
        print("-" * 72)
        print(text.replace("\n", " ⏎ "))
        print("-" * 72)

        print("GOLD :")
        for s, e, lab in sorted(r["entities"]):
            print(f"       {lab:10} {text[s:e]!r}")

        print("MODEL:")
        for s, e, lab in sorted(pred):
            frag = text[s:e]
            exact = (s, e, lab) in gold
            loose = (_norm(frag), lab) in gold_by_norm
            tag = "ok" if exact else ("~ok(span off)" if loose else "FALSE+")
            print(f"       {lab:10} {frag!r:40} {tag}")
            if exact or loose:
                hit[lab] += 1
            else:
                fp[lab] += 1
                if lab == "DRUG":
                    fp_drug_strings[_norm(frag)] += 1

        for s, e, lab in r["entities"]:
            frag = text[s:e]
            if (_norm(frag), lab) not in {(_norm(text[a:b]), l) for a, b, l in pred}:
                miss[lab] += 1

        if nlp is not None:
            print("MED7 :")
            for s, e, lab in sorted(m7):
                exact = (_norm(text[s:e]), lab) in gold_by_norm
                print(f"       {lab:10} {text[s:e]!r:40} {'ok' if exact else 'FALSE+'}")

    print("\n" + "#" * 72)
    print("# model, per entity:   hits (exact or span-off)  |  misses  |  false positives")
    print("#" * 72)
    for lab in ("DRUG", "STRENGTH", "DOSAGE", "FORM", "ROUTE", "FREQUENCY", "DURATION"):
        if args.entity and lab != args.entity:
            continue
        print(f"  {lab:10}  hit {hit[lab]:3}   miss {miss[lab]:3}   FALSE+ {fp[lab]:3}")

    if fp_drug_strings:
        print("\nmodel's FALSE-POSITIVE DRUG predictions (string -> count):")
        for s, n in fp_drug_strings.most_common():
            print(f"  {n:3}  {s!r}")


if __name__ == "__main__":
    main()
