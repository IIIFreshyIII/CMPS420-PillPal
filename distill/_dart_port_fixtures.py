"""
Dev tool, not part of the shipped pipeline: generates ground-truth fixtures
from the REAL Python reference (tokenizer, ONNX model, postprocess, drug
matcher, regex fields) for the Dart port's unit tests to assert against.

This is what makes "verified against Python" a checked-in fact instead of a
claim -- see app/test/core/ner/*_test.dart.

    python _dart_port_fixtures.py

Writes app/test/fixtures/ner_fixtures.json
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
sys.path.insert(0, str(HERE.parent))  # repo root, for med7_pipeline

from postprocess import refine, first_per_type
from drug_vocab import DrugMatcher
from med7_pipeline import _regex_fields, compute_refill
from technical_spike import build_pipe, MODEL_DIR

OUT = HERE.parent / "app" / "test" / "fixtures" / "ner_fixtures.json"

REAL_TEST = HERE / "data" / "real_test.jsonl"


def main() -> None:
    rows = [json.loads(l) for l in REAL_TEST.read_text().splitlines() if l.strip()][:6]
    pipe, tok = build_pipe()
    matcher = DrugMatcher()

    id2label = pipe.model.config.id2label

    def token_label_ids(text: str):
        """Per-token argmax label ids straight from the model -- the input
        bio_decoder.dart's tests need, since flutter_onnxruntime can't run
        inside `flutter test` (it's a native plugin, needs a real device)."""
        enc = tok(text, return_tensors="pt", truncation=True, max_length=256)
        enc.pop("token_type_ids", None)
        import torch
        with torch.no_grad():
            logits = pipe.model(**enc).logits[0]
        return logits.argmax(dim=-1).tolist()

    # ---- tokenizer + raw-span cases (tests tokenizer + BIO decoder together) ----
    tokenizer_cases = []
    for r in rows:
        text = r["text"]
        enc = tok(text, return_offsets_mapping=True, truncation=True, max_length=256)
        tokens = tok.convert_ids_to_tokens(enc["input_ids"])
        raw = [[s["start"], s["end"], s["entity_group"]] for s in pipe(text)]
        tokenizer_cases.append({
            "text": text,
            "input_ids": enc["input_ids"],
            "offset_mapping": enc["offset_mapping"],
            "tokens": tokens,
            "raw_spans": raw,
            "token_label_ids": token_label_ids(text),
        })

    # edge cases: empty string, whitespace-only, very short
    for text in ["", "   ", "a"]:
        enc = tok(text, return_offsets_mapping=True, truncation=True, max_length=256)
        tokenizer_cases.append({
            "text": text,
            "input_ids": enc["input_ids"],
            "offset_mapping": enc["offset_mapping"],
            "tokens": tok.convert_ids_to_tokens(enc["input_ids"]),
            "raw_spans": [[s["start"], s["end"], s["entity_group"]] for s in pipe(text)] if text.strip() else [],
            "token_label_ids": token_label_ids(text) if text.strip() else [],
        })

    # ---- refine() cases: real raw spans -> expected refined output ----
    refine_cases = []
    for c in tokenizer_cases[:6]:
        refined = refine(c["raw_spans"], c["text"], matcher)
        refine_cases.append({
            "text": c["text"],
            "raw_spans": c["raw_spans"],
            "expected_refined": refined,
            "expected_first_per_type": {k: v for k, v in first_per_type(refined).items()},
        })

    # ---- DrugMatcher cases: curated, hits every code path ----
    drug_cases = []
    for s in [
        "atomoxetine",                 # exact match
        "ATOMOXETINE25M",              # OCR-glued strength tail -> strip -> exact match
        "venlafaxine 75 mg er cap",    # multi-token span, strength+form tail
        "AUROBINDO",                   # manufacturer, not a drug name at all
        "asdkjqwoeiru",                # pure garble, too different from anything
        "atorvastati",                 # one char short of "atorvastatin" -> fuzzy match
        "mfr:aurobindo",               # colon-glued manufacturer prefix
    ]:
        drug_cases.append({"input": s, "expected": matcher.match(s)})

    # ---- regex_fields + compute_refill cases ----
    regex_cases = []
    for text in [
        "Date filled: 08/01/2026\nDays supply: 30",
        "Filled 2026-08-01\n30-day supply",
        "Fill date: August 1, 2026\nQty: 90",
        "Dispensed: Aug 1, 26\nDays Supply:30",
        "no dates or supply info here at all",
        "Date: 12/31/99\nDays supply: 10",  # 2-digit year, dateutil century-pivot case
    ]:
        regex_cases.append({"text": text, "expected": _regex_fields(text)})

    refill_cases = []
    for fill, days in [
        ("2026-08-01", 30), ("2026-12-15", 10), (None, 30), ("2026-01-01", None),
        ("2026-01-20", 7),
    ]:
        refill, warn = compute_refill(fill, days)
        refill_cases.append({"fill_date": fill, "days_supply": days,
                              "expected_refill": refill, "expected_warn": warn})

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps({
        "vocab_size": tok.vocab_size,
        "model_max_length": 256,
        "id2label": {str(k): v for k, v in id2label.items()},
        "tokenizer_cases": tokenizer_cases,
        "refine_cases": refine_cases,
        "drug_cases": drug_cases,
        "regex_cases": regex_cases,
        "refill_cases": refill_cases,
    }, indent=2))
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
