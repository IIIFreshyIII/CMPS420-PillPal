"""
Med-Tracker — Phase 1 extraction prototype.

Pipeline:  photo --(OCR)--> raw text --(Med7 NER + regex)--> draft fields
           --(human confirmation)--> medication profile  (+ computed refill date)

Design rules from the spec that this file enforces:
  * NER only (Med7). No generative LLM anywhere in the extraction path.
  * Refill date is arithmetic, never predicted:  fill_date + days_supply.
  * Nothing is "saved" until a human confirms every field.
  * With --image, the source photo is deleted right after confirmation
    (or on --discard without confirming).

Usage:
  python med7_pipeline.py --text "Take 1 tablet of Metformin 500mg twice daily. Days supply 30."
  python med7_pipeline.py --image label.jpg --delete-image
  python med7_pipeline.py --image label.jpg --no-confirm        # skip the prompt (dev only)
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import sys
from dataclasses import dataclass, field, asdict

from dateutil import parser as dateparser

# Med7's seven entity labels.
MED7_LABELS = ("DRUG", "STRENGTH", "DOSAGE", "DURATION", "FREQUENCY", "FORM", "ROUTE")

_MODEL_NAME = "en_core_med7_lg"
_nlp = None


# --------------------------------------------------------------------------- #
# Model loading                                                                #
# --------------------------------------------------------------------------- #
def load_model():
    """Load Med7 once and cache it."""
    global _nlp
    if _nlp is None:
        import spacy  # imported lazily so --help works without the model installed

        try:
            _nlp = spacy.load(_MODEL_NAME)
        except OSError as exc:
            sys.exit(
                f"Could not load '{_MODEL_NAME}'. Install it with:\n"
                f'  pip install "en-core-med7-lg @ https://huggingface.co/'
                f'kormilitzin/en_core_med7_lg/resolve/main/'
                f'en_core_med7_lg-1.1.0-py3-none-any.whl"\n\n{exc}'
            )
    return _nlp


# --------------------------------------------------------------------------- #
# Step 1 — OCR (photo -> text)                                                 #
# --------------------------------------------------------------------------- #
def ocr_image(path: str) -> str:
    """Run Tesseract on a label photo with light preprocessing.

    Kept intentionally simple and fully on-device. EasyOCR is a stronger
    drop-in replacement for real-world label photos if Tesseract underperforms.
    """
    try:
        import pytesseract
        from PIL import Image, ImageOps
    except ImportError:
        sys.exit("OCR needs: pip install pytesseract Pillow  (and: sudo apt install tesseract-ocr)")

    if not os.path.exists(path):
        sys.exit(f"Image not found: {path}")

    img = Image.open(path)
    img = ImageOps.exif_transpose(img)          # honour phone orientation
    img = img.convert("L")                       # grayscale
    img = ImageOps.autocontrast(img)
    w, h = img.size
    if max(w, h) < 2000:                         # upscale small photos for OCR
        scale = 2000 / max(w, h)
        img = img.resize((int(w * scale), int(h * scale)))

    try:
        text = pytesseract.image_to_string(img)
    except pytesseract.TesseractNotFoundError:
        sys.exit("Tesseract binary missing. Install it: sudo apt install tesseract-ocr")
    return text


# --------------------------------------------------------------------------- #
# Step 2 — extraction (Med7 NER + deterministic regex)                         #
# --------------------------------------------------------------------------- #
@dataclass
class Extraction:
    """Everything the machine proposes. All of it is a *draft* until confirmed."""

    drug: str | None = None
    strength: str | None = None
    dosage: str | None = None
    form: str | None = None
    route: str | None = None
    frequency: str | None = None
    duration: str | None = None

    fill_date: str | None = None        # ISO date string, from regex only
    days_supply: int | None = None      # int, from regex only
    quantity: str | None = None

    raw_text: str = ""
    ner_spans: list = field(default_factory=list)   # [(label, text)] for auditing


def _first(spans_by_label: dict, label: str) -> str | None:
    vals = spans_by_label.get(label, [])
    return vals[0] if vals else None


def _all_joined(spans_by_label: dict, label: str) -> str | None:
    vals = spans_by_label.get(label, [])
    return " / ".join(dict.fromkeys(vals)) if vals else None


# Deterministic patterns for the things Med7 does NOT label (dates, supply, qty).
_DATE_RX = re.compile(
    r"(?:date\s*filled|fill(?:ed)?\s*date|filled|dispensed|date)\s*[:\-]?\s*"
    r"(\d{1,2}[/\-.]\d{1,2}[/\-.]\d{2,4}|\d{4}[/\-.]\d{1,2}[/\-.]\d{1,2}"
    r"|[A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4})",
    re.IGNORECASE,
)
# Colon form ("Days supply: 30") is the common pharmacy-label layout — try it first.
# The bare form allows at most one "-"/space so it can't reach across from "Qty: 60".
_SUPPLY_RX_COLON = re.compile(r"day(?:s)?\s*supply\s*[:\-]?\s*(\d{1,3})", re.IGNORECASE)
_SUPPLY_RX_BARE = re.compile(r"(\d{1,3})[\- ]?day(?:s)?\s*supply", re.IGNORECASE)
_QTY_RX = re.compile(r"\b(?:qty|quantity)\s*[:\-]?\s*(\d+(?:\.\d+)?)", re.IGNORECASE)


def _regex_fields(text: str) -> dict:
    out: dict = {}

    m = _DATE_RX.search(text)
    if m:
        try:
            out["fill_date"] = dateparser.parse(m.group(1), dayfirst=False).date().isoformat()
        except (ValueError, OverflowError):
            pass

    m = _SUPPLY_RX_COLON.search(text) or _SUPPLY_RX_BARE.search(text)
    if m:
        out["days_supply"] = int(m.group(1))

    m = _QTY_RX.search(text)
    if m:
        out["quantity"] = m.group(1)

    return out


def normalize_for_ner(text: str) -> str:
    """Med7 is trained on clinical prose, not label layout. Collapse newlines and
    lowercase so an OCR'd label reads more like a sentence."""
    return re.sub(r"\s+", " ", text).strip().lower()


def _drug_from(nlp, text: str) -> str | None:
    for ent in nlp(text).ents:
        if ent.label_ == "DRUG":
            return ent.text.strip()
    return None


def extract(text: str) -> Extraction:
    """Med7 for medication entities; regex for dates / supply / quantity."""
    nlp = load_model()
    norm = normalize_for_ner(text)
    doc = nlp(norm)

    spans_by_label: dict[str, list[str]] = {lab: [] for lab in MED7_LABELS}
    ner_spans = []
    for ent in doc.ents:
        if ent.label_ in spans_by_label:
            spans_by_label[ent.label_].append(ent.text.strip())
        ner_spans.append((ent.label_, ent.text.strip()))

    # Med7-lg often misses drug names that carry a salt suffix ("metformin hcl")
    # or sit outside a verb/prepositional context (common on label layout).
    # Retry per line with a "take " lead-in, which markedly improves DRUG recall.
    if not spans_by_label["DRUG"]:
        for line in (ln.strip().lower() for ln in text.splitlines() if ln.strip()):
            retry = _drug_from(nlp, f"take {line}")
            if retry and retry != "take":
                spans_by_label["DRUG"].append(retry)
                ner_spans.append(("DRUG", retry + "  (low confidence — verify)"))
                break

    ex = Extraction(
        drug=_first(spans_by_label, "DRUG"),
        strength=_all_joined(spans_by_label, "STRENGTH"),
        dosage=_all_joined(spans_by_label, "DOSAGE"),
        form=_first(spans_by_label, "FORM"),
        route=_first(spans_by_label, "ROUTE"),
        frequency=_all_joined(spans_by_label, "FREQUENCY"),
        duration=_all_joined(spans_by_label, "DURATION"),
        raw_text=text,
        ner_spans=ner_spans,
    )
    for k, v in _regex_fields(text).items():
        setattr(ex, k, v)
    return ex


# --------------------------------------------------------------------------- #
# Step 3 — human confirmation (nothing is saved before this)                   #
# --------------------------------------------------------------------------- #
_FIELDS = [
    ("drug", "Drug name"),
    ("strength", "Strength"),
    ("dosage", "Dose amount"),
    ("form", "Form"),
    ("route", "Route"),
    ("frequency", "Frequency"),
    ("duration", "Duration"),
    ("fill_date", "Fill date (YYYY-MM-DD)"),
    ("days_supply", "Days supply (number)"),
    ("quantity", "Quantity"),
]


def confirm(ex: Extraction) -> Extraction | None:
    """Walk every field with the user. Enter keeps the draft value; typing replaces it.

    Returns the confirmed Extraction, or None if the user aborts.
    """
    print("\n--- Review every field. This is the only thing that gets saved. ---")
    print("[Enter] = keep shown value   |   type a value to change it   |   'q' = abort\n")

    for attr, label in _FIELDS:
        current = getattr(ex, attr)
        shown = "" if current is None else str(current)
        resp = input(f"{label} [{shown}]: ").strip()
        if resp.lower() == "q":
            return None
        if resp == "":
            continue
        if attr == "days_supply":
            if not resp.isdigit():
                print("  ! days supply must be a whole number — keeping previous value")
                continue
            setattr(ex, attr, int(resp))
        elif attr == "fill_date":
            try:
                setattr(ex, attr, dateparser.parse(resp).date().isoformat())
            except (ValueError, OverflowError):
                print("  ! could not parse that date — keeping previous value")
        else:
            setattr(ex, attr, resp)

    return ex


# --------------------------------------------------------------------------- #
# Step 4 — build the profile; refill date is pure arithmetic                   #
# --------------------------------------------------------------------------- #
@dataclass
class MedicationProfile:
    drug: str | None
    strength: str | None
    dosage: str | None
    form: str | None
    route: str | None
    frequency: str | None
    duration: str | None
    fill_date: str | None
    days_supply: int | None
    quantity: str | None
    refill_date: str | None
    refill_warn_date: str | None            # first of the two-stage refill warnings
    notes: list = field(default_factory=list)


def compute_refill(fill_date: str | None, days_supply: int | None, warn_days: int = 7):
    """refill_date = fill_date + days_supply. No model involved. Returns (refill, warn)."""
    if not fill_date or not days_supply:
        return None, None
    start = dt.date.fromisoformat(fill_date)
    refill = start + dt.timedelta(days=days_supply)
    warn = refill - dt.timedelta(days=warn_days)
    return refill.isoformat(), warn.isoformat()


def build_profile(ex: Extraction) -> MedicationProfile:
    refill, warn = compute_refill(ex.fill_date, ex.days_supply)
    notes = []
    if not ex.drug:
        notes.append("Drug name not extracted — you must enter it manually.")
    if refill is None:
        notes.append("Refill date not computed: need both fill date and days supply.")
    return MedicationProfile(
        drug=ex.drug, strength=ex.strength, dosage=ex.dosage, form=ex.form,
        route=ex.route, frequency=ex.frequency, duration=ex.duration,
        fill_date=ex.fill_date, days_supply=ex.days_supply, quantity=ex.quantity,
        refill_date=refill, refill_warn_date=warn, notes=notes,
    )


# --------------------------------------------------------------------------- #
# CLI                                                                          #
# --------------------------------------------------------------------------- #
def _print_draft(ex: Extraction) -> None:
    print("\n=== Med7 NER spans (audit) ===")
    for label, txt in ex.ner_spans:
        print(f"  {label:<10} {txt}")
    print("\n=== Draft fields (NOT saved yet) ===")
    print(json.dumps({k: v for k, v in asdict(ex).items()
                      if k not in ("raw_text", "ner_spans")}, indent=2))


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="Med-Tracker Phase 1 extraction prototype")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--text", help="raw label text (skip OCR)")
    src.add_argument("--image", help="path to a label photo (runs OCR)")
    ap.add_argument("--delete-image", action="store_true",
                    help="delete the source photo after confirmation (spec behaviour)")
    ap.add_argument("--no-confirm", action="store_true",
                    help="dev only: skip the human confirmation step")
    ap.add_argument("--out", help="write the confirmed profile to this JSON file")
    args = ap.parse_args(argv)

    text = args.text if args.text else ocr_image(args.image)
    if not text.strip():
        return _fail_and_maybe_delete("OCR produced no text.", args)

    print("=== Source text ===")
    print(text.strip())

    ex = extract(text)
    _print_draft(ex)

    if args.no_confirm:
        confirmed = ex
    else:
        confirmed = confirm(ex)
        if confirmed is None:
            return _fail_and_maybe_delete("Aborted — nothing saved.", args)

    profile = build_profile(confirmed)
    print("\n=== CONFIRMED medication profile ===")
    print(json.dumps(asdict(profile), indent=2))

    if args.out:
        with open(args.out, "w") as fh:
            json.dump(asdict(profile), fh, indent=2)
        print(f"\nSaved -> {args.out}")

    if args.image and args.delete_image:
        os.remove(args.image)
        print(f"Deleted source photo: {args.image}")

    return 0


def _fail_and_maybe_delete(msg: str, args) -> int:
    print(msg)
    if getattr(args, "image", None) and args.delete_image and os.path.exists(args.image):
        os.remove(args.image)
        print(f"Deleted source photo: {args.image}")
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
