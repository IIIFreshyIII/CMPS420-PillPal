"""
Synthetic prescription-label generator.

Produces realistic-looking label text AND the exact character spans of every
field it inserted (drug, strength, dose, form, route, frequency, duration).

Because we assemble each label from known pieces, we get perfect ("gold")
labels for free — no need to hand-annotate anything. Med7 is then used as a
*second opinion* / baseline to compare against (see make_dataset.py).

    from label_generator import generate
    text, spans = generate(seed=0)
    # spans = [(start, end, "DRUG"), (start, end, "STRENGTH"), ...]

Run directly to eyeball a few:  python label_generator.py
"""

from __future__ import annotations

import random

# Med7's seven entity types — the label scheme we're standardising on.
LABELS = ["DRUG", "STRENGTH", "DOSAGE", "FORM", "ROUTE", "FREQUENCY", "DURATION"]

# --- ingredient lists ------------------------------------------------------- #
# (drug, optional salt, list of plausible strengths, list of plausible forms)
DRUGS = [
    ("metformin", "hcl", ["500 mg", "850 mg", "1000 mg"], ["tablet", "ER tablet"]),
    ("lisinopril", "", ["5 mg", "10 mg", "20 mg", "40 mg"], ["tablet"]),
    ("atorvastatin", "calcium", ["10 mg", "20 mg", "40 mg", "80 mg"], ["tablet"]),
    ("amoxicillin", "", ["250 mg", "500 mg", "875 mg"], ["capsule", "tablet"]),
    ("amlodipine", "besylate", ["2.5 mg", "5 mg", "10 mg"], ["tablet"]),
    ("omeprazole", "", ["10 mg", "20 mg", "40 mg"], ["capsule", "DR capsule"]),
    ("levothyroxine", "sodium", ["25 mcg", "50 mcg", "75 mcg", "100 mcg"], ["tablet"]),
    ("hydrochlorothiazide", "", ["12.5 mg", "25 mg"], ["tablet", "capsule"]),
    ("gabapentin", "", ["100 mg", "300 mg", "600 mg"], ["capsule", "tablet"]),
    ("sertraline", "hcl", ["25 mg", "50 mg", "100 mg"], ["tablet"]),
    ("montelukast", "sodium", ["10 mg"], ["tablet"]),
    ("losartan", "potassium", ["25 mg", "50 mg", "100 mg"], ["tablet"]),
    ("albuterol", "sulfate", ["90 mcg"], ["inhaler", "HFA inhaler"]),
    ("prednisone", "", ["5 mg", "10 mg", "20 mg"], ["tablet"]),
    ("azithromycin", "", ["250 mg", "500 mg"], ["tablet"]),
    ("ibuprofen", "", ["400 mg", "600 mg", "800 mg"], ["tablet"]),
    ("warfarin", "sodium", ["1 mg", "2 mg", "5 mg"], ["tablet"]),
    ("furosemide", "", ["20 mg", "40 mg", "80 mg"], ["tablet"]),
    ("citalopram", "hydrobromide", ["10 mg", "20 mg", "40 mg"], ["tablet"]),
    ("tramadol", "hcl", ["50 mg"], ["tablet"]),
]

DOSE_AMOUNTS = ["1", "2", "one", "two", "1 to 2", "1-2", "one-half", "1/2"]
ROUTES = ["by mouth", "orally", "PO", "by mouth", "by mouth"]  # weighted toward "by mouth"
FREQ = [
    "once daily", "twice daily", "three times daily", "four times daily",
    "every morning", "at bedtime", "every 8 hours", "every 12 hours",
    "every 4 to 6 hours", "twice a day", "once a day", "every other day",
    "as needed", "as needed for pain", "with meals", "before meals",
    "in the morning and evening", "BID", "TID", "QID", "daily",
]
DURATION = [
    "", "", "", "for 5 days", "for 7 days", "for 10 days", "for 14 days",
    "for 30 days", "until gone", "for 3 months", "for 90 days",
]
PHARMACIES = [
    ("GOODHEALTH PHARMACY", "(555) 123-4567"),
    ("CITY DRUGS #214", "(555) 908-1122"),
    ("MAIN STREET RX", "(555) 447-0099"),
    ("VALLEY CARE PHARMACY", "(555) 771-3030"),
    ("PARKSIDE APOTHECARY", "(555) 226-8842"),
]
PRESCRIBERS = ["DR A PATEL", "DR SARAH KIM", "DR J RODRIGUEZ", "DR M OKAFOR", "DR L CHEN"]


# --- span-tracking string builder ---------------------------------------- #
class _Builder:
    def __init__(self) -> None:
        self.text = ""
        self.spans: list[tuple[int, int, str]] = []

    def add(self, s: str, label: str | None = None) -> None:
        start = len(self.text)
        self.text += s
        if label:
            self.spans.append((start, len(self.text), label))

    def line(self, s: str = "") -> None:
        self.text += s + "\n"


def _casing(s: str, mode: str) -> str:
    return {"upper": s.upper(), "lower": s.lower(), "title": s.title(), "as-is": s}[mode]


def generate(seed: int | None = None) -> tuple[str, list[tuple[int, int, str]]]:
    """Return (label_text, gold_spans)."""
    rng = random.Random(seed)
    b = _Builder()

    drug, salt, strengths, forms = rng.choice(DRUGS)
    strength = rng.choice(strengths)
    form = rng.choice(forms)
    dose = rng.choice(DOSE_AMOUNTS)
    route = rng.choice(ROUTES)
    freq = rng.choice(FREQ)
    dur = rng.choice(DURATION)

    case = rng.choice(["upper", "upper", "title", "as-is"])   # labels skew ALL CAPS
    pharm, phone = rng.choice(PHARMACIES)
    month, day, year = rng.randint(1, 12), rng.randint(1, 28), 2026
    supply = rng.choice([7, 10, 14, 30, 60, 90])
    qty = supply * rng.choice([1, 1, 2, 3])

    # --- header ---
    b.line(pharm)
    if rng.random() < 0.6:
        b.line(f"{rng.randint(100, 4999)} {rng.choice(['MAIN','OAK','ELM','1ST'])} ST")
    b.line(f"Rx {rng.randint(1_000_000, 9_999_999)}    Date filled: {month:02d}/{day:02d}/{year}")
    b.line()

    # --- drug line:  NAME [SALT] STRENGTH FORM ---
    b.add(_casing(drug, case), "DRUG")
    if salt and rng.random() < 0.7:
        b.add(" ")
        b.add(_casing(salt, case), "DRUG")   # salt is part of the drug name
    b.add(" ")
    b.add(_casing(strength, case), "STRENGTH")
    b.add(" ")
    b.add(_casing(form, case), "FORM")
    b.line()

    # --- sig line:  Take <dose> <form> <route> <freq> <duration> ---
    b.add(_casing("Take ", case))
    b.add(_casing(dose, case), "DOSAGE")
    b.add(" ")
    b.add(_casing(form, case), "FORM")
    b.add(" ")
    b.add(_casing(route, case), "ROUTE")
    b.add(" ")
    b.add(_casing(freq, case), "FREQUENCY")
    if dur:
        b.add(" ")
        b.add(_casing(dur, case), "DURATION")
    b.line(".")
    b.line()

    # --- footer ---
    b.line(f"Qty: {qty}    Days supply: {supply}")
    b.line(f"Refills: {rng.randint(0, 11)} before {month:02d}/{day:02d}/{year + 1}")
    if rng.random() < 0.7:
        b.line(f"Prescriber: {rng.choice(PRESCRIBERS)}")
    if rng.random() < 0.3:
        b.line(rng.choice(["MAY CAUSE DROWSINESS", "TAKE WITH FOOD", "DO NOT DRINK ALCOHOL"]))

    return b.text, b.spans


def _preview(n: int = 3) -> None:
    for i in range(n):
        text, spans = generate(seed=i)
        print(f"\n{'='*64}\nSEED {i}\n{'='*64}\n{text}")
        for s, e, lab in spans:
            print(f"  {lab:<10} {text[s:e]!r}  [{s}:{e}]")


if __name__ == "__main__":
    _preview()
