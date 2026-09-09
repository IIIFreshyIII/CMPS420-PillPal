"""
Export a fine-tuned token-classification checkpoint to ONNX, make fp16 + int8
variants, and check each one's F1 against the PyTorch parent on the real-label
set. The winner (smallest that holds the score) is what the phone ships.

    # on the server (.venv-gpu -- it has the checkpoints)
    python export_onnx.py --model model-mobile  --data data-mobile
    python export_onnx.py --model model-noisy2  --data data-noisy2

    # then copy the chosen variant + tokenizer into the app
    python export_onnx.py --model model-mobile --variant int8 --emit ../app/assets/ner

Reproduces evaluate.py's decode exactly (HF pipeline, aggregation_strategy=
"first") so the numbers are comparable. Needs:  optimum[exporters,onnxruntime]
onnx onnxruntime onnxconverter-common  (see requirements.txt / setup_gpu.sh).
"""

from __future__ import annotations

import argparse
import json
import shutil
import time
import warnings
from pathlib import Path

# export/quant tooling is noisy: fp16 clamp notices, torch tracer warnings
warnings.filterwarnings("ignore", category=UserWarning, module="onnxconverter_common")
warnings.filterwarnings("ignore", message=".*TracerWarning.*")
warnings.filterwarnings("ignore", message=".*torch_dtype.*")

from make_dataset import spans_to_bio  # reuse the exact span->BIO alignment

HERE = Path(__file__).resolve().parent
ENTITY_ORDER = ["DRUG", "STRENGTH", "DOSAGE", "FORM", "ROUTE", "FREQUENCY", "DURATION"]


def _load_jsonl(p: Path):
    return [json.loads(x) for x in p.read_text().splitlines() if x.strip()]


# --------------------------------------------------------------------------- #
def export_fp32(model_dir: Path, out: Path) -> Path:
    from optimum.onnxruntime import ORTModelForTokenClassification
    from transformers import AutoTokenizer

    out.mkdir(parents=True, exist_ok=True)
    print(f">> exporting fp32 ONNX  {model_dir} -> {out}")
    try:
        ort = ORTModelForTokenClassification.from_pretrained(model_dir, export=True)
    except TypeError:  # older optimum
        ort = ORTModelForTokenClassification.from_pretrained(model_dir, from_transformers=True)
    ort.save_pretrained(out)
    AutoTokenizer.from_pretrained(model_dir).save_pretrained(out)
    src_labels = model_dir / "labels.json"
    if src_labels.exists():
        shutil.copy(src_labels, out / "labels.json")
    fp32 = out / "model.onnx"
    print(f"   {fp32.name}  {fp32.stat().st_size/1e6:.1f} MB")
    return fp32


def make_fp16(fp32: Path) -> Path:
    import onnx
    from onnxconverter_common import float16

    dst = fp32.with_name("model_fp16.onnx")
    # keep_io_types=True leaves stray fp32 Cast nodes that ORT rejects on load;
    # False casts the whole graph (int64 id inputs are untouched, logits -> fp16)
    m = float16.convert_float_to_float16(onnx.load(str(fp32)), keep_io_types=False)
    onnx.save(m, str(dst))
    print(f"   {dst.name}  {dst.stat().st_size/1e6:.1f} MB")
    return dst


def make_int8(fp32: Path) -> Path:
    from onnxruntime.quantization import QuantType, quantize_dynamic

    dst = fp32.with_name("model_int8.onnx")
    src = fp32
    # onnxruntime's symbolic shape inference chokes on the MobileBERT/DistilBERT
    # Slice ops; skip_symbolic_shape=True works, and if the whole preprocess
    # still fails we quantize the raw graph (dynamic quant doesn't require it).
    try:
        from onnxruntime.quantization.shape_inference import quant_pre_process
        prepped = fp32.with_name("model_prepped.onnx")
        quant_pre_process(str(fp32), str(prepped), skip_symbolic_shape=True)
        src = prepped
    except Exception as exc:  # noqa: BLE001
        print(f"   (quant_pre_process skipped: {type(exc).__name__})")

    quantize_dynamic(
        str(src), str(dst),
        weight_type=QuantType.QInt8, per_channel=True, reduce_range=True,
    )
    if src != fp32:
        src.unlink(missing_ok=True)
    print(f"   {dst.name}  {dst.stat().st_size/1e6:.1f} MB")
    return dst


# --------------------------------------------------------------------------- #
def _prep_tok(tok, model):
    """DistilBERT has no token_type_ids input but its tokenizer emits one; drop
    it. Pin max_length so truncation matches training (make_dataset uses 256)."""
    if getattr(model.config, "model_type", "") == "distilbert":
        tok.model_input_names = [n for n in tok.model_input_names if n != "token_type_ids"]
    tok.model_max_length = 256
    return tok


def _pipe_torch(model_dir: Path):
    from transformers import (AutoModelForTokenClassification, AutoTokenizer,
                              pipeline)
    mdl = AutoModelForTokenClassification.from_pretrained(model_dir)
    tok = _prep_tok(AutoTokenizer.from_pretrained(model_dir), mdl)
    return pipeline("token-classification", model=mdl, tokenizer=tok,
                    aggregation_strategy="first", device=-1), tok


def _pipe_onnx(onnx_dir: Path, file_name: str):
    from optimum.onnxruntime import ORTModelForTokenClassification
    from transformers import AutoTokenizer, pipeline
    mdl = ORTModelForTokenClassification.from_pretrained(onnx_dir, file_name=file_name)
    tok = _prep_tok(AutoTokenizer.from_pretrained(onnx_dir), mdl)
    return pipeline("token-classification", model=mdl, tokenizer=tok,
                    aggregation_strategy="first", device=-1), tok


def score(pipe, tok, rows: list[dict]) -> tuple[float, dict]:
    from seqeval.metrics import classification_report, f1_score

    yt, yp = [], []
    for r in rows:
        spans = [[s["start"], s["end"], s["entity_group"]] for s in pipe(r["text"])]
        _, g = spans_to_bio(r["text"], r["entities"], tok)
        _, p = spans_to_bio(r["text"], spans, tok)
        yt.append(g)
        yp.append(p)
    rep = classification_report(yt, yp, output_dict=True, zero_division=0)
    return f1_score(yt, yp, zero_division=0), rep


def latency_ms(pipe, texts: list[str], n: int = 40) -> float:
    warm = texts[: min(3, len(texts))]
    for t in warm:
        pipe(t)
    picks = (texts * ((n // max(1, len(texts))) + 1))[:n]
    t0 = time.perf_counter()
    for t in picks:
        pipe(t)
    return (time.perf_counter() - t0) / len(picks) * 1000


# --------------------------------------------------------------------------- #
def parity(model_dir: Path, onnx_dir: Path, data: Path, fp32, fp16, int8) -> None:
    real = _load_jsonl(data / "real_test.jsonl") if (data / "real_test.jsonl").exists() else []
    unseen = _load_jsonl(data / "test_unseen.jsonl") if (data / "test_unseen.jsonl").exists() else []
    variants = [
        ("pytorch", lambda: _pipe_torch(model_dir), None),
        ("onnx fp32", lambda: _pipe_onnx(onnx_dir, fp32.name), fp32),
        ("onnx fp16", lambda: _pipe_onnx(onnx_dir, fp16.name), fp16),
        ("onnx int8", lambda: _pipe_onnx(onnx_dir, int8.name), int8),
    ]
    print(f"\n{'variant':11} {'size MB':>8} {'real F1':>8} {'unseen F1':>10} "
          f"{'DRUG':>6} {'STR':>6} {'lat ms':>7}")
    print("-" * 62)
    for name, mk, path in variants:
        size = path.stat().st_size / 1e6 if path and path.exists() else float("nan")
        try:
            pipe, tok = mk()
            rf1, rrep = (score(pipe, tok, real) if real else (float("nan"), {}))
            uf1, _ = (score(pipe, tok, unseen) if unseen else (float("nan"), {}))
            drug = rrep.get("DRUG", {}).get("f1-score", float("nan"))
            stg = rrep.get("STRENGTH", {}).get("f1-score", float("nan"))
            lat = latency_ms(pipe, [r["text"] for r in (real or unseen)])
            print(f"{name:11} {size:8.1f} {rf1:8.3f} {uf1:10.3f} {drug:6.2f} {stg:6.2f} {lat:7.1f}")
        except Exception as exc:  # noqa: BLE001 - one bad variant shouldn't kill the table
            print(f"{name:11} {size:8.1f}   FAILED: {type(exc).__name__}: {str(exc)[:60]}")
    print("\npick: smallest variant with real F1 within ~0.03 of pytorch and >= 0.53")


def emit(onnx_dir: Path, variant: str, dest: Path) -> None:
    fmap = {"fp32": "model.onnx", "fp16": "model_fp16.onnx", "int8": "model_int8.onnx"}
    src = onnx_dir / fmap[variant]
    dest.mkdir(parents=True, exist_ok=True)
    shutil.copy(src, dest / "model.quant.onnx")
    for f in ("vocab.txt", "labels.json", "config.json", "tokenizer_config.json",
              "special_tokens_map.json"):
        if (onnx_dir / f).exists():
            shutil.copy(onnx_dir / f, dest / f)
    dn = HERE / "drug_names.txt"
    if dn.exists():
        shutil.copy(dn, dest / "drug_names.txt")
    total = sum(p.stat().st_size for p in dest.iterdir()) / 1e6
    print(f">> emitted {variant} bundle -> {dest}  ({total:.1f} MB total)")
    for p in sorted(dest.iterdir()):
        print(f"   {p.name}  {p.stat().st_size/1e6:.2f} MB")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True, help="fine-tuned checkpoint dir")
    ap.add_argument("--data", help="data dir with real_test.jsonl / test_unseen.jsonl")
    ap.add_argument("--out", help="ONNX output dir (default: onnx-<model>)")
    ap.add_argument("--variant", default="int8", choices=["fp32", "fp16", "int8"])
    ap.add_argument("--emit", help="copy the --variant bundle into this dir (e.g. ../app/assets/ner)")
    ap.add_argument("--skip-parity", action="store_true")
    args = ap.parse_args()

    model_dir = Path(args.model).resolve()
    onnx_dir = Path(args.out).resolve() if args.out else HERE / f"onnx-{model_dir.name.replace('model-', '')}"

    fp32 = onnx_dir / "model.onnx"
    if not fp32.exists():
        fp32 = export_fp32(model_dir, onnx_dir)
    fp16 = onnx_dir / "model_fp16.onnx"
    if not fp16.exists():
        fp16 = make_fp16(fp32)
    int8 = onnx_dir / "model_int8.onnx"
    if not int8.exists():
        int8 = make_int8(fp32)

    if args.data and not args.skip_parity:
        parity(model_dir, onnx_dir, Path(args.data).resolve(), fp32, fp16, int8)

    if args.emit:
        emit(onnx_dir, args.variant, Path(args.emit).resolve())


if __name__ == "__main__":
    main()
