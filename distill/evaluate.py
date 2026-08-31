"""
Stage 4: score the fine-tuned model against the gold test set, side by side
with Med7. This table is the heart of your report.

    python evaluate.py --model ner-model --data data/
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from make_dataset import med7_spans, spans_to_bio


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="ner-model")
    ap.add_argument("--data", default="data")
    ap.add_argument("--compare-med7", action="store_true", default=True)
    args = ap.parse_args()

    from transformers import AutoTokenizer, AutoModelForTokenClassification, pipeline
    from seqeval.metrics import classification_report, f1_score

    meta = json.loads((Path(args.model) / "labels.json").read_text())
    tok = AutoTokenizer.from_pretrained(args.model)
    model = AutoModelForTokenClassification.from_pretrained(args.model)
    ner = pipeline("token-classification", model=model, tokenizer=tok,
                   aggregation_strategy="first")

    test = [json.loads(l) for l in (Path(args.data) / "test.jsonl").read_text().splitlines()]

    def model_spans(text: str):
        out = []
        for s in ner(text):
            lab = s["entity_group"]
            if lab in meta["label2id"] or any(lab == x for x in _entity_names(meta)):
                out.append([s["start"], s["end"], lab])
        return out

    y_true, y_model = [], []
    for r in test:
        _, gold = spans_to_bio(r["text"], r["entities"], tok)
        _, mdl = spans_to_bio(r["text"], model_spans(r["text"]), tok)
        y_true.append(gold)
        y_model.append(mdl)

    print("\n================  FINE-TUNED MODEL vs GOLD  ================")
    print(classification_report(y_true, y_model, digits=3, zero_division=0))
    print(f"overall F1: {f1_score(y_true, y_model, zero_division=0):.3f}")

    if args.compare_med7:
        try:
            import spacy
            nlp = spacy.load("en_core_med7_lg")
            y_med7 = []
            for r in test:
                _, m7 = spans_to_bio(r["text"], med7_spans(nlp, r["text"]), tok)
                y_med7.append(m7)
            print("\n================  MED7 vs GOLD (baseline)  ================")
            print(classification_report(y_true, y_med7, digits=3, zero_division=0))
            print(f"overall F1: {f1_score(y_true, y_med7, zero_division=0):.3f}")
        except Exception as exc:
            print(f"(Med7 comparison skipped: {exc})")


def _entity_names(meta) -> list[str]:
    return sorted({t.split("-", 1)[1] for t in meta["bio"] if t != "O"})


if __name__ == "__main__":
    main()
