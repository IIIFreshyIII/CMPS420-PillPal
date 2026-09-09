"""
End-to-end reference for the on-phone pipeline, in Python. The Dart code in the
app must reproduce this exactly.

    OCR text
      -> ONNX NER model  (HF pipeline, aggregation_strategy="first")
      -> postprocess.refine   (RxNorm + closed-set validation / normalization)
      -> first span per type   -> Extraction-shaped fields
      -> _regex_fields (med7_pipeline)  for fillDate / daysSupply
      -> compute_refill

    python infer.py --onnx onnx-mobile --text "<paste a real OCR block>"
    python infer.py --onnx onnx-mobile --data data-mobile --eval   # RxNorm lift

`--eval` scores model-alone vs model+refine on real_test.jsonl (seqeval), i.e.
how much the validation layer moves the number. That delta goes in the writeup.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))  # repo root, for med7_pipeline

from make_dataset import spans_to_bio
from postprocess import first_per_type, refine
from drug_vocab import DrugMatcher

# NER entity type -> Extraction field name (app/lib/services/extractor.dart)
FIELD = {"DRUG": "drug", "STRENGTH": "strength", "DOSAGE": "dose", "FORM": "form",
         "ROUTE": "route", "FREQUENCY": "frequency", "DURATION": "duration"}


def _load_jsonl(p: Path):
    return [json.loads(x) for x in p.read_text().splitlines() if x.strip()]


def _build_pipe(onnx_dir: Path):
    from optimum.onnxruntime import ORTModelForTokenClassification
    from transformers import AutoTokenizer, pipeline

    fname = next((f for f in ("model.quant.onnx", "model_int8.onnx", "model.onnx")
                  if (onnx_dir / f).exists()), "model.onnx")
    tok = AutoTokenizer.from_pretrained(onnx_dir)
    mdl = ORTModelForTokenClassification.from_pretrained(onnx_dir, file_name=fname)
    return pipeline("token-classification", model=mdl, tokenizer=tok,
                    aggregation_strategy="first"), tok


def raw_spans(pipe, text: str):
    return [[s["start"], s["end"], s["entity_group"]] for s in pipe(text)]


def extract(pipe, text: str, matcher: DrugMatcher) -> dict:
    refined = refine(raw_spans(pipe, text), text, matcher)
    picked = first_per_type(refined)
    fields = {FIELD[t]: None for t in FIELD}
    flags: list[str] = []
    for typ, r in picked.items():
        fields[FIELD[typ]] = r["canonical"]
        if not r["recognized"]:
            flags.append(f"{FIELD[typ]}=?({r['text']!r})")

    from med7_pipeline import _regex_fields  # date / days-supply / qty via regex
    rf = _regex_fields(text)
    fill = rf.get("fill_date")
    days = rf.get("days_supply")
    fields["fillDate"] = fill
    fields["daysSupply"] = int(days) if days else None

    refill = warn = None
    if fill and days:
        from med7_pipeline import compute_refill
        refill, warn = compute_refill(fill, int(days))
    return {"fields": fields, "flags": flags, "refill": refill, "refill_warn": warn,
            "spans": [(r["start"], r["end"], r["type"], r["canonical"]) for r in refined]}


def cmd_eval(onnx_dir: Path, data: Path) -> None:
    from seqeval.metrics import classification_report, f1_score

    rows = _load_jsonl(data / "real_test.jsonl")
    pipe, tok = _build_pipe(onnx_dir)
    matcher = DrugMatcher()

    yt, y_raw, y_ref = [], [], []
    for r in rows:
        rs = raw_spans(pipe, r["text"])
        refined = refine(rs, r["text"], matcher)
        rss = [[x["start"], x["end"], x["type"]] for x in refined]
        _, g = spans_to_bio(r["text"], r["entities"], tok)
        _, a = spans_to_bio(r["text"], rs, tok)
        _, b = spans_to_bio(r["text"], rss, tok)
        yt.append(g)
        y_raw.append(a)
        y_ref.append(b)

    for name, yp in (("model alone", y_raw), ("model + refine", y_ref)):
        rep = classification_report(yt, yp, output_dict=True, zero_division=0)
        d = rep.get("DRUG", {})
        print(f"\n=== {name} ===  micro F1 {f1_score(yt, yp, zero_division=0):.3f}")
        print(f"    DRUG  P {d.get('precision', 0):.2f}  R {d.get('recall', 0):.2f}  "
              f"F1 {d.get('f1-score', 0):.2f}")
    print("\n(full report, model + refine)")
    print(classification_report(yt, y_ref, digits=3, zero_division=0))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--onnx", required=True, help="ONNX bundle dir (has model + tokenizer)")
    ap.add_argument("--text", help="one OCR block to run")
    ap.add_argument("--data", help="data dir with real_test.jsonl (for --eval)")
    ap.add_argument("--eval", action="store_true", help="RxNorm lift on real_test")
    args = ap.parse_args()
    onnx_dir = Path(args.onnx).resolve()

    if args.eval:
        cmd_eval(onnx_dir, Path(args.data).resolve())
        return

    pipe, _ = _build_pipe(onnx_dir)
    matcher = DrugMatcher()
    if args.text:
        texts = [args.text]
    elif args.data:
        texts = [r["text"] for r in _load_jsonl(Path(args.data).resolve() / "real_test.jsonl")]
    else:
        raise SystemExit("pass --text or --data")

    for t in texts:
        out = extract(pipe, t, matcher)
        print("\n" + "=" * 70)
        print(t.replace("\n", " / "))
        print("-" * 70)
        for k, v in out["fields"].items():
            print(f"  {k:11} {v}")
        if out["refill"]:
            print(f"  refill      {out['refill']}")
        if out["flags"]:
            print(f"  FLAGGED     {', '.join(out['flags'])}")


if __name__ == "__main__":
    main()
