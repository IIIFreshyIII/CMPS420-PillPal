"""
Build data/real_test.jsonl from real prescription-label images or text.

This is the ONLY evaluation number that predicts real-world performance, because
the model can't have memorised it (the generator never made it).

Two steps.

STEP 1 — draft.  Point it at a folder of label images (or .txt files you already
OCR'd / typed out):

    python build_real_testset.py --images real_labels/  --out data/
    python build_real_testset.py --texts  real_labels/  --out data/

It OCRs each image (Tesseract), pre-annotates with Med7's best guess, and writes
data/real_test.draft.txt — plain text, one label per block, entities marked as
[some text](LABEL).

STEP 2 — you fix the brackets by hand (fast: you're correcting, not starting
cold), then:

    python build_real_testset.py --finalize data/real_test.draft.txt --out data/

-> writes data/real_test.jsonl, which evaluate.py picks up automatically.

Labels: DRUG STRENGTH DOSAGE FORM ROUTE FREQUENCY DURATION
(mark the drug name, the strength like "500 mg", the dose like "1", the form like
"tablet", the route like "by mouth", the frequency, the duration. Ignore
everything else — pharmacy name, patient info, Rx number, dates.)

PRIVACY: real labels carry patient names / addresses / Rx numbers. We never label
those, and the images stay out of git (.gitignore). Only the finalised text goes
in the repo — scrub any patient identifier from the draft before finalising.
"""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

LABELS = ["DRUG", "STRENGTH", "DOSAGE", "FORM", "ROUTE", "FREQUENCY", "DURATION"]
_BRACKET = re.compile(r"\[([^\]\n]+?)\]\(([A-Z_]+)\)")


# --------------------------------------------------------------------------- #
def ocr_image(path: Path) -> str:
    import pytesseract
    from PIL import Image, ImageOps

    img = ImageOps.exif_transpose(Image.open(path)).convert("L")
    img = ImageOps.autocontrast(img)
    w, h = img.size
    if max(w, h) < 2000:
        s = 2000 / max(w, h)
        img = img.resize((int(w * s), int(h * s)))
    return pytesseract.image_to_string(img)


def med7_preannotate(text: str) -> str:
    """Wrap Med7's predicted spans in [text](LABEL), right-to-left so offsets hold."""
    try:
        import spacy
        nlp = spacy.load("en_core_med7_lg")
    except Exception:
        return text
    ents = sorted((e for e in nlp(text).ents if e.label_ in LABELS),
                  key=lambda e: e.start_char, reverse=True)
    for e in ents:
        text = text[:e.start_char] + f"[{e.text}]({e.label_})" + text[e.end_char:]
    return text


# --------------------------------------------------------------------------- #
def cmd_draft(sources: list[tuple[str, str]], out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    draft = out / "real_test.draft.txt"
    with open(draft, "w") as fh:
        for name, text in sources:
            text = re.sub(r"\n{3,}", "\n\n", text.strip())
            fh.write(f"### {name}\n{med7_preannotate(text)}\n\n")
    print(f"wrote {draft}  ({len(sources)} labels)")
    print("\nNext: open it, fix the [text](LABEL) marks, remove any patient info, then:")
    print(f"  python build_real_testset.py --finalize {draft} --out {out}")


def cmd_finalize(draft: Path, out: Path) -> None:
    out.mkdir(parents=True, exist_ok=True)
    blocks = re.split(r"^### (.+)$", draft.read_text(), flags=re.MULTILINE)[1:]
    rows, warnings = [], []

    for name, body in zip(blocks[0::2], blocks[1::2]):
        body = body.strip("\n")
        clean, spans, pos = "", [], 0
        for m in _BRACKET.finditer(body):
            clean += body[pos:m.start()]
            s = len(clean)
            clean += m.group(1)
            lab = m.group(2)
            spans.append([s, len(clean), lab])
            if lab not in LABELS:
                warnings.append(f"{name}: unknown label {lab!r}")
            pos = m.end()
        clean += body[pos:]
        rows.append({"source": name.strip(), "text": clean, "entities": spans})
        if not spans:
            warnings.append(f"{name}: no entities marked")

    path = out / "real_test.jsonl"
    with open(path, "w") as fh:
        for r in rows:
            fh.write(json.dumps(r) + "\n")

    counts: dict[str, int] = {}
    for r in rows:
        for _, _, lab in r["entities"]:
            counts[lab] = counts.get(lab, 0) + 1
    print(f"wrote {path}  ({len(rows)} labels, {sum(counts.values())} entities)")
    for lab in LABELS:
        print(f"  {lab:<10} {counts.get(lab, 0)}")
    for w in warnings:
        print("  ! " + w)
    print(f"\nNow: python evaluate.py --model model-run --data {out}")


# --------------------------------------------------------------------------- #
def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--images", help="folder of label image files")
    ap.add_argument("--texts", help="folder of .txt files (already OCR'd / typed)")
    ap.add_argument("--finalize", help="path to the edited real_test.draft.txt")
    ap.add_argument("--out", default="data", help="output directory")
    args = ap.parse_args()
    out = Path(args.out)

    if args.finalize:
        cmd_finalize(Path(args.finalize), out)
        return

    sources: list[tuple[str, str]] = []
    if args.images:
        try:
            import pytesseract  # noqa: F401
        except ImportError:
            raise SystemExit("Need OCR: pip install pytesseract  +  sudo apt install tesseract-ocr")
        for p in sorted(Path(args.images).iterdir()):
            if p.suffix.lower() in {".jpg", ".jpeg", ".png", ".webp", ".tif", ".tiff", ".bmp"}:
                print(f"OCR {p.name}...")
                sources.append((p.name, ocr_image(p)))
    if args.texts:
        for p in sorted(Path(args.texts).glob("*.txt")):
            sources.append((p.name, p.read_text()))

    if not sources:
        raise SystemExit("Nothing to do. Pass --images DIR, --texts DIR, or --finalize FILE.")
    cmd_draft(sources, out)


if __name__ == "__main__":
    main()
