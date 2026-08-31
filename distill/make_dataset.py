"""
Stage 2: turn generated labels into a training dataset with a HELD-OUT test split.

Four files come out (JSONL, one label per line, {"text": ..., "entities": [[s,e,LAB]]}):

    train.jsonl        training-pool vocab
    val.jsonl          training-pool vocab (for picking the best epoch)
    test_seen.jsonl    training-pool vocab, fresh instances
                       -> "can it do labels like the ones it trained on?"
    test_unseen.jsonl  HELD-OUT drugs / pharmacies / phrasings
                       -> "does it generalise, or did it just memorise?"

The gap between test_seen and test_unseen is the number that matters for the report.
We also score Med7 on both test sets as the baseline.

    python make_dataset.py --n-train 4000 --out data/
    python make_dataset.py --n-train 4000 --noise 0.02 --out data_noisy/   # + OCR corruption
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from label_generator import LABELS, add_ocr_noise, generate, holdout_manifest

BIO = ["O"] + [f"{p}-{l}" for l in LABELS for p in ("B", "I")]
LABEL2ID = {t: i for i, t in enumerate(BIO)}

# disjoint seed ranges per split, so no label is ever shared between them
SEED_BASE = {"train": 0, "val": 1_000_000, "test_seen": 2_000_000, "test_unseen": 3_000_000}


def med7_spans(nlp, text: str) -> list[list]:
    out = []
    for ent in nlp(text).ents:
        if ent.label_ in LABELS:
            out.append([ent.start_char, ent.end_char, ent.label_])
    return out


def spans_to_bio(text: str, spans: list, tokenizer) -> tuple[list[str], list[str]]:
    """Align character spans onto word-piece tokens as B-/I-/O tags."""
    enc = tokenizer(text, return_offsets_mapping=True, truncation=True, max_length=256)
    tokens = tokenizer.convert_ids_to_tokens(enc["input_ids"])
    tags = []
    for (a, b) in enc["offset_mapping"]:
        if a == b:
            tags.append("O")
            continue
        hit = next(((s, e, lab) for s, e, lab in spans if s <= a < e), None)
        tags.append("O" if hit is None else f"{'B' if a == hit[0] else 'I'}-{hit[2]}")
    return tokens, tags


def _make_split(name: str, n: int, split_kind: str, noise: float, noise_seed: int):
    rows = []
    for i in range(SEED_BASE[name], SEED_BASE[name] + n):
        text, ents = generate(seed=i, split=split_kind)
        if noise > 0:
            text, ents = add_ocr_noise(text, ents, rate=noise, seed=noise_seed + i)
        rows.append({"text": text, "entities": [list(e) for e in ents]})
    return rows


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--n-train", type=int, default=4000)
    ap.add_argument("--n-val", type=int, default=400)
    ap.add_argument("--n-test", type=int, default=500, help="size of EACH test set")
    ap.add_argument("--noise", type=float, default=0.0, help="per-char OCR corruption rate")
    ap.add_argument("--out", default="data")
    ap.add_argument("--base-model", default="distilbert-base-uncased")
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)

    splits = {
        "train":       _make_split("train", args.n_train, "train", args.noise, 11),
        "val":         _make_split("val", args.n_val, "train", args.noise, 22),
        "test_seen":   _make_split("test_seen", args.n_test, "train", args.noise, 33),
        "test_unseen": _make_split("test_unseen", args.n_test, "unseen", args.noise, 44),
    }
    for name, rows in splits.items():
        with open(out / f"{name}.jsonl", "w") as fh:
            for r in rows:
                fh.write(json.dumps(r) + "\n")
        print(f"{name:12} {len(rows):>5} -> {out / f'{name}.jsonl'}")

    (out / "labels.json").write_text(json.dumps({"bio": BIO, "label2id": LABEL2ID}, indent=2))
    (out / "holdout_manifest.json").write_text(json.dumps(holdout_manifest(), indent=2))
    print(f"\nheld out from training: {len(holdout_manifest()['drugs_held_out'])} drugs, "
          f"{len(holdout_manifest()['pharmacies_held_out'])} pharmacies, "
          f"{len(holdout_manifest()['frequencies_held_out'])} frequency phrasings "
          f"(see {out / 'holdout_manifest.json'})")
    if args.noise:
        print(f"OCR noise applied at rate {args.noise}")

    _med7_baseline(splits, args.base_model)


def _med7_baseline(splits: dict, base_model: str) -> None:
    print("\nMed7 baseline (F1 vs gold)...")
    try:
        import spacy
        from seqeval.metrics import f1_score
        from transformers import AutoTokenizer

        nlp = spacy.load("en_core_med7_lg")
        tok = AutoTokenizer.from_pretrained(base_model)
        for name in ("test_seen", "test_unseen"):
            yt, yp = [], []
            for r in splits[name]:
                _, g = spans_to_bio(r["text"], r["entities"], tok)
                _, m = spans_to_bio(r["text"], med7_spans(nlp, r["text"]), tok)
                yt.append(g)
                yp.append(m)
            print(f"  Med7 on {name:12}: F1 = {f1_score(yt, yp, zero_division=0):.3f}")
    except Exception as exc:
        print(f"  (skipped: {type(exc).__name__}: {exc})")


if __name__ == "__main__":
    main()
