"""
Stage 2 of the pipeline: turn generated labels into a training dataset.

Writes train/val/test as JSONL, one label per line:
    {"text": "...", "entities": [[start, end, "DRUG"], ...]}

The "entities" are the GOLD spans straight from the generator (perfect, free).
We also run Med7 over the *test* split and score it, so you have a baseline
number to beat ("Med7 gets F1 = 0.xx on our labels").

    python make_dataset.py --n 4000 --out data/

Optional: --labels med7  writes Med7's predictions as the training labels
instead of gold (true "imitate the teacher" distillation — usually worse,
because it copies Med7's mistakes; gold is the recommended default).
"""

from __future__ import annotations

import argparse
import json
import random
from pathlib import Path

from label_generator import LABELS, generate

BIO = ["O"] + [f"{p}-{l}" for l in LABELS for p in ("B", "I")]
LABEL2ID = {t: i for i, t in enumerate(BIO)}


# --------------------------------------------------------------------------- #
def med7_spans(nlp, text: str) -> list[list]:
    """Med7's predicted entity spans, in the same [start, end, LABEL] shape."""
    out = []
    for ent in nlp(text).ents:
        if ent.label_ in LABELS:
            out.append([ent.start_char, ent.end_char, ent.label_])
    return out


def spans_to_bio(text: str, spans: list, tokenizer) -> tuple[list[str], list[str]]:
    """Align character spans onto word-piece tokens as B-/I-/O tags.

    This is the one fiddly step: Med7 speaks in character positions, the model
    speaks in tokens, so we translate.
    """
    enc = tokenizer(text, return_offsets_mapping=True, truncation=True, max_length=256)
    tokens = tokenizer.convert_ids_to_tokens(enc["input_ids"])
    tags = []
    for (a, b) in enc["offset_mapping"]:
        if a == b:                       # special token ([CLS], [SEP], padding)
            tags.append("O")
            continue
        hit = next(((s, e, lab) for s, e, lab in spans if s <= a < e), None)
        if hit is None:
            tags.append("O")
        else:
            s, e, lab = hit
            tags.append(f"{'B' if a == s else 'I'}-{lab}")
    return tokens, tags


# --------------------------------------------------------------------------- #
def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--n", type=int, default=4000, help="how many labels to generate")
    ap.add_argument("--out", default="data", help="output directory")
    ap.add_argument("--base-model", default="distilbert-base-uncased")
    ap.add_argument("--labels", choices=["gold", "med7"], default="gold")
    ap.add_argument("--seed-start", type=int, default=0)
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    nlp = None
    if args.labels == "med7":
        import spacy
        nlp = spacy.load("en_core_med7_lg")

    rows = []
    for i in range(args.seed_start, args.seed_start + args.n):
        text, gold = generate(seed=i)
        ents = gold if args.labels == "gold" else med7_spans(nlp, text)
        rows.append({"text": text, "entities": ents})

    random.Random(42).shuffle(rows)
    n_test = n_val = max(1, args.n // 10)
    splits = {
        "test": rows[:n_test],
        "val": rows[n_test:n_test + n_val],
        "train": rows[n_test + n_val:],
    }
    for name, data in splits.items():
        with open(out / f"{name}.jsonl", "w") as fh:
            for r in data:
                fh.write(json.dumps(r) + "\n")
        print(f"{name:5} {len(data):>5} labels -> {out / f'{name}.jsonl'}")

    # save the label map the training + ONNX steps need
    (out / "labels.json").write_text(json.dumps({"bio": BIO, "label2id": LABEL2ID}, indent=2))

    # ---- Med7 baseline on the test split (the number to beat) ----
    print("\nScoring Med7 on the test split (baseline)...")
    try:
        import spacy
        from seqeval.metrics import classification_report
        if nlp is None:
            nlp = spacy.load("en_core_med7_lg")
        tok = _load_tokenizer(args.base_model)
        y_true, y_pred = [], []
        for r in splits["test"]:
            _, gold_tags = spans_to_bio(r["text"], r["entities"], tok)
            _, m7_tags = spans_to_bio(r["text"], med7_spans(nlp, r["text"]), tok)
            y_true.append(gold_tags)
            y_pred.append(m7_tags)
        print(classification_report(y_true, y_pred, digits=3, zero_division=0))
    except Exception as exc:
        print(f"(skipped baseline: {type(exc).__name__}: {exc})")


def _load_tokenizer(name: str):
    from transformers import AutoTokenizer
    return AutoTokenizer.from_pretrained(name)


if __name__ == "__main__":
    main()
