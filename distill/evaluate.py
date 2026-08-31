"""
Stage 4: score the fine-tuned model on BOTH held-out test sets, next to Med7.

    python evaluate.py --model ner-model --data data/

Reads test_seen.jsonl (training-style labels) and test_unseen.jsonl (held-out
drugs / pharmacies / phrasings). The seen -> unseen drop is the headline number:
small drop = it generalises; big drop = it memorised.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from make_dataset import med7_spans, spans_to_bio


def _load(path: Path):
    return [json.loads(l) for l in path.read_text().splitlines()]


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="ner-model")
    ap.add_argument("--data", default="data")
    ap.add_argument("--no-med7", action="store_true")
    args = ap.parse_args()

    from transformers import AutoTokenizer, AutoModelForTokenClassification, pipeline
    from seqeval.metrics import classification_report, f1_score

    data = Path(args.data)
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
            print(f"(Med7 unavailable, skipping baseline: {exc})")

    test_files = [f for f in ("test_seen", "test_unseen", "test", "real_test")
                  if (data / f"{f}.jsonl").exists()]
    summary = {}

    for name in test_files:
        rows = _load(data / f"{name}.jsonl")

        def model_spans(text: str):
            return [[s["start"], s["end"], s["entity_group"]] for s in ner(text)]

        yt, ym, y7 = [], [], []
        for r in rows:
            _, g = spans_to_bio(r["text"], r["entities"], tok)
            _, m = spans_to_bio(r["text"], model_spans(r["text"]), tok)
            yt.append(g)
            ym.append(m)
            if nlp is not None:
                _, s7 = spans_to_bio(r["text"], med7_spans(nlp, r["text"]), tok)
                y7.append(s7)

        print(f"\n{'#'*64}\n#  {name}   ({len(rows)} labels)\n{'#'*64}")
        print("--- fine-tuned model vs gold ---")
        print(classification_report(yt, ym, digits=3, zero_division=0))
        mdl_f1 = f1_score(yt, ym, zero_division=0)
        summary.setdefault(name, {})["model"] = mdl_f1
        print(f"model F1: {mdl_f1:.3f}")
        if y7:
            m7_f1 = f1_score(yt, y7, zero_division=0)
            summary[name]["med7"] = m7_f1
            print(f"Med7  F1: {m7_f1:.3f}")

    # ---- headline table ----
    print(f"\n{'='*52}\n{'':16}{'model F1':>12}{'Med7 F1':>12}\n{'='*52}")
    for name, d in summary.items():
        print(f"{name:16}{d.get('model', 0):>12.3f}{d.get('med7', float('nan')):>12.3f}")
    if "test_seen" in summary and "test_unseen" in summary:
        drop = summary["test_seen"]["model"] - summary["test_unseen"]["model"]
        print(f"\ngeneralisation gap (seen - unseen), model: {drop:+.3f}")
        print("  < 0.05  -> generalising well")
        print("  > 0.15  -> largely memorising; needs more vocab / more data / noise")


if __name__ == "__main__":
    main()
