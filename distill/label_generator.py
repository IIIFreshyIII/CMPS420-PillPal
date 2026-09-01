"""
Synthetic prescription-label generator — held-out split + template variety.

Two kinds of variety, on purpose:

  * VOCABULARY holdout: drugs / pharmacies / phrasings are pre-split into a
    "train" pool and a disjoint "test" pool. generate(split="unseen") draws only
    from the held-out pool, so the test set contains words the model never saw.

  * STRUCTURAL variety: the drug line, the sig ("Take ...") line, the header and
    the footer each have several templates / orderings / optional fields, chosen
    at random. This stops the model from cheating with "the token after 'Take' is
    always the dose" — it has to actually read the language.

    text, spans = generate(seed=0, split="train")
    text, spans = add_ocr_noise(text, spans, rate=0.02, seed=0)

Run directly to eyeball it:  python label_generator.py
"""

from __future__ import annotations

import random

LABELS = ["DRUG", "STRENGTH", "DOSAGE", "FORM", "ROUTE", "FREQUENCY", "DURATION"]

# --- ingredient lists --------------------------------------------------- #
# (drug, salt or "", [strengths], [forms])
DRUGS = [
    ("metformin", "hcl", ["500 mg", "850 mg", "1000 mg"], ["tablet", "ER tablet"]),
    ("lisinopril", "", ["5 mg", "10 mg", "20 mg", "40 mg"], ["tablet"]),
    ("atorvastatin", "calcium", ["10 mg", "20 mg", "40 mg", "80 mg"], ["tablet"]),
    ("amlodipine", "besylate", ["2.5 mg", "5 mg", "10 mg"], ["tablet"]),
    ("metoprolol", "tartrate", ["25 mg", "50 mg", "100 mg"], ["tablet", "ER tablet"]),
    ("omeprazole", "", ["10 mg", "20 mg", "40 mg"], ["capsule", "DR capsule"]),
    ("simvastatin", "", ["10 mg", "20 mg", "40 mg"], ["tablet"]),
    ("losartan", "potassium", ["25 mg", "50 mg", "100 mg"], ["tablet"]),
    ("albuterol", "sulfate", ["90 mcg"], ["inhaler", "HFA inhaler"]),
    ("gabapentin", "", ["100 mg", "300 mg", "600 mg", "800 mg"], ["capsule", "tablet"]),
    ("hydrochlorothiazide", "", ["12.5 mg", "25 mg", "50 mg"], ["tablet", "capsule"]),
    ("levothyroxine", "sodium", ["25 mcg", "50 mcg", "75 mcg", "100 mcg", "125 mcg"], ["tablet"]),
    ("sertraline", "hcl", ["25 mg", "50 mg", "100 mg"], ["tablet"]),
    ("montelukast", "sodium", ["10 mg"], ["tablet"]),
    ("furosemide", "", ["20 mg", "40 mg", "80 mg"], ["tablet"]),
    ("pantoprazole", "sodium", ["20 mg", "40 mg"], ["DR tablet"]),
    ("escitalopram", "oxalate", ["5 mg", "10 mg", "20 mg"], ["tablet"]),
    ("rosuvastatin", "calcium", ["5 mg", "10 mg", "20 mg", "40 mg"], ["tablet"]),
    ("bupropion", "hcl", ["75 mg", "100 mg", "150 mg", "300 mg"], ["ER tablet", "SR tablet"]),
    ("trazodone", "hcl", ["50 mg", "100 mg", "150 mg"], ["tablet"]),
    ("duloxetine", "hcl", ["20 mg", "30 mg", "60 mg"], ["DR capsule"]),
    ("prednisone", "", ["1 mg", "5 mg", "10 mg", "20 mg"], ["tablet"]),
    ("tramadol", "hcl", ["50 mg"], ["tablet"]),
    ("citalopram", "hydrobromide", ["10 mg", "20 mg", "40 mg"], ["tablet"]),
    ("fluoxetine", "hcl", ["10 mg", "20 mg", "40 mg"], ["capsule"]),
    ("tamsulosin", "hcl", ["0.4 mg"], ["capsule"]),
    ("carvedilol", "", ["3.125 mg", "6.25 mg", "12.5 mg", "25 mg"], ["tablet"]),
    ("warfarin", "sodium", ["1 mg", "2 mg", "2.5 mg", "5 mg"], ["tablet"]),
    ("clopidogrel", "bisulfate", ["75 mg"], ["tablet"]),
    ("apixaban", "", ["2.5 mg", "5 mg"], ["tablet"]),
    ("glipizide", "", ["5 mg", "10 mg"], ["tablet", "ER tablet"]),
    ("glimepiride", "", ["1 mg", "2 mg", "4 mg"], ["tablet"]),
    ("pravastatin", "sodium", ["10 mg", "20 mg", "40 mg"], ["tablet"]),
    ("meloxicam", "", ["7.5 mg", "15 mg"], ["tablet"]),
    ("naproxen", "", ["250 mg", "375 mg", "500 mg"], ["tablet"]),
    ("ibuprofen", "", ["400 mg", "600 mg", "800 mg"], ["tablet"]),
    ("celecoxib", "", ["100 mg", "200 mg"], ["capsule"]),
    ("cyclobenzaprine", "hcl", ["5 mg", "10 mg"], ["tablet"]),
    ("methocarbamol", "", ["500 mg", "750 mg"], ["tablet"]),
    ("amoxicillin", "", ["250 mg", "500 mg", "875 mg"], ["capsule", "tablet"]),
    ("azithromycin", "", ["250 mg", "500 mg"], ["tablet"]),
    ("cephalexin", "", ["250 mg", "500 mg"], ["capsule"]),
    ("ciprofloxacin", "hcl", ["250 mg", "500 mg", "750 mg"], ["tablet"]),
    ("doxycycline", "hyclate", ["50 mg", "100 mg"], ["capsule", "tablet"]),
    ("nitrofurantoin", "", ["50 mg", "100 mg"], ["capsule"]),
    ("fluconazole", "", ["50 mg", "100 mg", "150 mg", "200 mg"], ["tablet"]),
    ("valacyclovir", "hcl", ["500 mg", "1000 mg"], ["tablet"]),
    ("hydroxyzine", "hcl", ["10 mg", "25 mg", "50 mg"], ["tablet"]),
    ("cetirizine", "hcl", ["5 mg", "10 mg"], ["tablet"]),
    ("loratadine", "", ["10 mg"], ["tablet"]),
    ("fexofenadine", "hcl", ["60 mg", "180 mg"], ["tablet"]),
    ("famotidine", "", ["20 mg", "40 mg"], ["tablet"]),
    ("ondansetron", "hcl", ["4 mg", "8 mg"], ["tablet", "ODT tablet"]),
    ("promethazine", "hcl", ["12.5 mg", "25 mg"], ["tablet"]),
    ("spironolactone", "", ["25 mg", "50 mg", "100 mg"], ["tablet"]),
    ("atenolol", "", ["25 mg", "50 mg", "100 mg"], ["tablet"]),
    ("propranolol", "hcl", ["10 mg", "20 mg", "40 mg", "80 mg"], ["tablet", "ER capsule"]),
    ("diltiazem", "hcl", ["30 mg", "60 mg", "120 mg", "180 mg"], ["ER capsule", "tablet"]),
    ("nifedipine", "", ["30 mg", "60 mg", "90 mg"], ["ER tablet"]),
    ("isosorbide mononitrate", "", ["30 mg", "60 mg"], ["ER tablet"]),
    ("allopurinol", "", ["100 mg", "300 mg"], ["tablet"]),
    ("colchicine", "", ["0.6 mg"], ["tablet"]),
    ("levetiracetam", "", ["250 mg", "500 mg", "750 mg"], ["tablet"]),
    ("lamotrigine", "", ["25 mg", "100 mg", "200 mg"], ["tablet"]),
    ("topiramate", "", ["25 mg", "50 mg", "100 mg"], ["tablet"]),
    ("pregabalin", "", ["50 mg", "75 mg", "150 mg", "300 mg"], ["capsule"]),
    ("venlafaxine", "hcl", ["37.5 mg", "75 mg", "150 mg"], ["ER capsule", "tablet"]),
    ("mirtazapine", "", ["7.5 mg", "15 mg", "30 mg", "45 mg"], ["tablet"]),
    ("quetiapine", "fumarate", ["25 mg", "50 mg", "100 mg", "200 mg"], ["tablet"]),
    ("aripiprazole", "", ["2 mg", "5 mg", "10 mg", "15 mg"], ["tablet"]),
    ("buspirone", "hcl", ["5 mg", "10 mg", "15 mg"], ["tablet"]),
    ("zolpidem", "tartrate", ["5 mg", "10 mg"], ["tablet"]),
    ("tizanidine", "hcl", ["2 mg", "4 mg"], ["tablet", "capsule"]),
    ("baclofen", "", ["5 mg", "10 mg", "20 mg"], ["tablet"]),
    ("sumatriptan", "succinate", ["25 mg", "50 mg", "100 mg"], ["tablet"]),
    ("fluticasone", "propionate", ["50 mcg", "110 mcg", "220 mcg"], ["nasal spray", "inhaler"]),
    ("tiotropium", "bromide", ["18 mcg"], ["inhaler"]),
    ("finasteride", "", ["1 mg", "5 mg"], ["tablet"]),
    ("sildenafil", "citrate", ["25 mg", "50 mg", "100 mg"], ["tablet"]),
    ("tadalafil", "", ["2.5 mg", "5 mg", "10 mg", "20 mg"], ["tablet"]),
    ("oxybutynin", "chloride", ["5 mg", "10 mg"], ["ER tablet", "tablet"]),
    ("donepezil", "hcl", ["5 mg", "10 mg"], ["tablet"]),
    ("memantine", "hcl", ["5 mg", "10 mg"], ["tablet"]),
    ("guaifenesin", "", ["400 mg", "600 mg", "1200 mg"], ["ER tablet"]),
    ("benzonatate", "", ["100 mg", "200 mg"], ["capsule"]),
    ("latanoprost", "", ["0.005%"], ["eye drops"]),
    ("timolol", "maleate", ["0.25%", "0.5%"], ["eye drops"]),
]

BRANDS = {
    "metformin": "Glucophage", "atorvastatin": "Lipitor", "lisinopril": "Prinivil",
    "amlodipine": "Norvasc", "omeprazole": "Prilosec", "sertraline": "Zoloft",
    "escitalopram": "Lexapro", "duloxetine": "Cymbalta", "gabapentin": "Neurontin",
    "montelukast": "Singulair", "losartan": "Cozaar", "rosuvastatin": "Crestor",
    "bupropion": "Wellbutrin", "pregabalin": "Lyrica", "tamsulosin": "Flomax",
    "quetiapine": "Seroquel", "zolpidem": "Ambien", "sumatriptan": "Imitrex",
    "tadalafil": "Cialis", "sildenafil": "Viagra", "apixaban": "Eliquis",
}

DOSE_AMOUNTS = ["1", "2", "3", "one", "two", "1 to 2", "1-2", "one-half", "1/2", "one to two"]
ROUTES = ["by mouth", "by mouth", "by mouth", "orally", "PO", "by mouth",
          "into the affected eye", "in each eye", "by inhalation", "in each nostril",
          "sublingually", "topically"]
FREQ = [
    "once daily", "twice daily", "three times daily", "four times daily",
    "every morning", "every evening", "at bedtime", "every 8 hours",
    "every 12 hours", "every 6 hours", "every 4 to 6 hours", "twice a day",
    "once a day", "three times a day", "every other day", "as needed",
    "as needed for pain", "as needed for anxiety", "with meals", "before meals",
    "in the morning and evening", "at the first sign of migraine",
    "BID", "TID", "QID", "QHS", "daily", "weekly", "every night at bedtime",
    "2 times per day", "3 times per day", "once weekly", "q6h", "q8h",
]
DURATION = [
    "", "", "", "for 3 days", "for 5 days", "for 7 days", "for 10 days",
    "for 14 days", "for 21 days", "for 28 days", "for 30 days", "for 90 days",
    "until gone", "for 1 week", "for 2 weeks", "for 3 months", "for 6 months",
    "for the next 5 days", "x 10 days", "x 7 days",
]
PHARMACIES = [
    ("GOODHEALTH PHARMACY", "(555) 123-4567"),
    ("CITY DRUGS #214", "(555) 908-1122"),
    ("MAIN STREET RX", "(555) 447-0099"),
    ("VALLEY CARE PHARMACY", "(555) 771-3030"),
    ("PARKSIDE APOTHECARY", "(555) 226-8842"),
    ("RIVERBEND PHARMACY", "(555) 610-2075"),
    ("SUNRISE DRUG MART", "(555) 402-8890"),
    ("OAKWOOD FAMILY PHARMACY", "(555) 337-1450"),
    ("HILLCREST PHARMACY #7", "(555) 889-6120"),
    ("CORNER CARE DRUGS", "(555) 213-7788"),
]
PRESCRIBERS = ["DR A PATEL", "DR SARAH KIM", "DR J RODRIGUEZ", "DR M OKAFOR",
               "DR L CHEN", "DR R NGUYEN", "DR B GOLDBERG", "DR T WILLIAMS"]
STREETS = ["MAIN", "OAK", "ELM", "1ST", "2ND", "PARK", "CEDAR", "MAPLE", "HILL", "RIVER"]
WARNINGS = ["MAY CAUSE DROWSINESS", "TAKE WITH FOOD", "DO NOT DRINK ALCOHOL",
            "AVOID PROLONGED SUN EXPOSURE", "DO NOT CRUSH OR CHEW",
            "TAKE ON AN EMPTY STOMACH", "KEEP REFRIGERATED"]

_FORM_ABBREV = {"tablet": "tab", "capsule": "cap", "ER tablet": "ER tab",
                "ER capsule": "ER cap", "DR capsule": "DR cap", "DR tablet": "DR tab"}
_ORAL_ROUTES = {"by mouth", "orally", "PO"}


# --- vocabulary partition --------------------------------------------- #
def _split_pool(items, holdout_frac: float, seed: int):
    xs = list(items)
    random.Random(seed).shuffle(xs)
    n_hold = max(1, round(len(xs) * holdout_frac))
    return xs[n_hold:], xs[:n_hold]


DRUG_TRAIN, DRUG_TEST = _split_pool(DRUGS, 0.25, seed=1001)
PHARM_TRAIN, PHARM_TEST = _split_pool(PHARMACIES, 0.30, seed=1002)
FREQ_TRAIN, FREQ_TEST = _split_pool(FREQ, 0.30, seed=1003)
DUR_TRAIN, DUR_TEST = _split_pool([d for d in DURATION if d], 0.30, seed=1004)
DUR_TRAIN += ["", "", ""]
DUR_TEST += ["", "", ""]


def holdout_manifest() -> dict:
    return {
        "drugs_held_out": [d[0] for d in DRUG_TEST],
        "drugs_in_training": [d[0] for d in DRUG_TRAIN],
        "pharmacies_held_out": [p[0] for p in PHARM_TEST],
        "frequencies_held_out": FREQ_TEST,
        "durations_held_out": [d for d in DUR_TEST if d],
    }


# --- span-tracking string builder ------------------------------------ #
class _Builder:
    def __init__(self) -> None:
        self.text = ""
        self.spans: list[tuple[int, int, str]] = []

    def add(self, s: str, label: str | None = None) -> None:
        start = len(self.text)
        self.text += s
        if label:
            self.spans.append((start, len(self.text), label))

    def sp(self) -> None:
        self.text += " "

    def line(self, s: str = "") -> None:
        self.text += s + "\n"


def _casing(s: str, mode: str) -> str:
    return {"upper": s.upper(), "lower": s.lower(), "title": s.title(), "as-is": s}[mode]


def _sig_verb(route: str, rng) -> str:
    if "eye" in route:
        return rng.choice(["Instill", "Place"])
    if "nostril" in route:
        return rng.choice(["Spray", "Instill"])
    if "inhal" in route:
        return rng.choice(["Inhale", "Take"])
    if route == "topically":
        return rng.choice(["Apply", "Use"])
    if route == "sublingually":
        return rng.choice(["Place", "Dissolve"])
    return rng.choice(["Take", "Take", "Use"])


# --- section templates ---------------------------------------------- #
def _emit_header(b, pharm, phone, case, rng):
    b.line(_casing(pharm, "as-is"))
    if rng.random() < 0.6:
        b.line(f"{rng.randint(100, 4999)} {rng.choice(STREETS)} ST")
    if rng.random() < 0.5:
        b.line(phone)
    rx = rng.choice(["Rx", "Rx #", "RX", "RX NO."])
    df = rng.choice(["Date filled:", "Filled", "Date:", "FILL DATE", "Filled on"])
    m, d, y = rng.randint(1, 12), rng.randint(1, 28), 2026
    sep = rng.choice(["   ", "    ", "  "])
    b.line(f"{rx} {rng.randint(1_000_000, 9_999_999)}{sep}{df} {m:02d}/{d:02d}/{y}")
    b.line()
    return m, d, y


def _emit_drug_line(b, drug, salt, strength, form, case, rng):
    style = rng.choice(["full", "full", "no_salt", "brand", "glued", "dash"])
    b.add(_casing(drug, case), "DRUG")
    if salt and style in ("full", "brand") and rng.random() < 0.85:
        b.sp()
        b.add(_casing(salt, case), "DRUG")
    if style == "dash":
        b.add("-")
        b.add(_casing(strength.replace(" ", ""), case), "STRENGTH")
    elif style == "glued":
        b.sp()
        b.add(_casing(strength.replace(" ", ""), case), "STRENGTH")
    else:
        b.sp()
        b.add(_casing(strength, case), "STRENGTH")
    b.sp()
    b.add(_casing(form, case), "FORM")
    if style == "brand" and drug in BRANDS:
        b.add(" (")
        b.add(_casing(BRANDS[drug], case))
        b.add(")")
    b.line()


def _emit_sig_line(b, dose, form, route, freq, dur, case, rng):
    t = rng.choice(["v_route_freq", "v_route_freq", "v_freq_route", "bare"])
    form_s = _FORM_ABBREV.get(form, form) if rng.random() < 0.35 else form
    route_s = "PO" if (route in _ORAL_ROUTES and rng.random() < 0.3) else route
    include_route = rng.random() > 0.15

    if t != "bare":
        b.add(_casing(_sig_verb(route, rng) + " ", case))
    b.add(_casing(dose, case), "DOSAGE")
    b.sp()
    b.add(_casing(form_s, case), "FORM")

    order = ["freq", "route"] if t == "v_freq_route" else ["route", "freq"]
    for part in order:
        if part == "route" and include_route:
            b.sp()
            b.add(_casing(route_s, case), "ROUTE")
        elif part == "freq":
            b.sp()
            b.add(_casing(freq, case), "FREQUENCY")
    if dur:
        b.sp()
        b.add(_casing(dur, case), "DURATION")
    b.line(rng.choice([".", "", ".", "; refill as needed"]))
    b.line()


def _emit_footer(b, rng, m, d, y):
    supply = rng.choice([5, 7, 10, 14, 30, 30, 60, 90])
    qty = supply * rng.choice([1, 1, 2, 3])
    exp = f"{m:02d}/{d:02d}/{y + 1}"
    lines = [
        rng.choice([f"Qty: {qty}    Days supply: {supply}",
                    f"Quantity {qty}   {supply} day supply",
                    f"QTY {qty}     DAYS SUPPLY: {supply}"]),
        rng.choice([f"Refills: {rng.randint(0, 11)} before {exp}",
                    f"{rng.randint(0, 11)} refills remaining",
                    f"REFILLS {rng.randint(0, 11)}"]),
    ]
    if rng.random() < 0.7:
        lines.append(f"Prescriber: {rng.choice(PRESCRIBERS)}")
    if rng.random() < 0.35:
        lines.append(rng.choice(WARNINGS))
    if rng.random() < 0.3:
        lines.append(f"Discard after {exp}")
    rng.shuffle(lines)
    for ln in lines:
        b.line(ln)


# --- generation --------------------------------------------------- #
def generate(seed: int | None = None, split: str = "train"):
    if split == "train":
        drugs, pharms, freqs, durs = DRUG_TRAIN, PHARM_TRAIN, FREQ_TRAIN, DUR_TRAIN
    elif split == "unseen":
        drugs, pharms, freqs, durs = DRUG_TEST, PHARM_TEST, FREQ_TEST, DUR_TEST
    else:
        raise ValueError(f"split must be 'train' or 'unseen', got {split!r}")

    rng = random.Random(None if seed is None else seed + (0 if split == "train" else 999_983))
    b = _Builder()

    drug, salt, strengths, forms = rng.choice(drugs)
    strength = rng.choice(strengths)
    form = rng.choice(forms)
    dose = rng.choice(DOSE_AMOUNTS)
    route = rng.choice(ROUTES)
    freq = rng.choice(freqs)
    dur = rng.choice(durs)
    case = rng.choice(["upper", "upper", "title", "as-is", "lower"])
    pharm, phone = rng.choice(pharms)

    m, d, y = _emit_header(b, pharm, phone, case, rng)
    # sig sometimes comes before the drug-strength line, sometimes after
    if rng.random() < 0.85:
        _emit_drug_line(b, drug, salt, strength, form, case, rng)
        _emit_sig_line(b, dose, form, route, freq, dur, case, rng)
    else:
        _emit_sig_line(b, dose, form, route, freq, dur, case, rng)
        _emit_drug_line(b, drug, salt, strength, form, case, rng)
    _emit_footer(b, rng, m, d, y)

    return b.text, _merge_adjacent(b.text, b.spans)


def _merge_adjacent(text: str, spans):
    spans = sorted(spans)
    out: list = []
    for s, e, lab in spans:
        if out and out[-1][2] == lab and text[out[-1][1]:s].strip() == "":
            out[-1] = (out[-1][0], e, lab)
        else:
            out.append((s, e, lab))
    return out


# --- OCR-style corruption ---------------------------------------- #
# Tesseract's dominant failure on real label photos is dropping whole lines /
# regions it can't segment (testing showed it losing entire sig lines). So the
# primary effect here is line dropout; light character swaps are secondary.
_CONFUSE = {
    "0": "O", "O": "0", "1": "l", "l": "1", "I": "l", "5": "S", "S": "5",
    "8": "B", "B": "8", "2": "Z", "Z": "2", "6": "b", "g": "9", "9": "g",
}


def _drop_lines(text: str, spans, prob: float, rng) -> tuple[str, list]:
    """Delete whole non-empty lines at `prob` each and remap the spans. A span
    that sat on a dropped line is removed (the field is simply gone, as when OCR
    loses the sig line)."""
    ranges, i = [], 0
    for ln in text.splitlines(keepends=True):
        ranges.append([i, i + len(ln), ln.strip() != ""])
        i += len(ln)

    nonempty = [k for k, r in enumerate(ranges) if r[2]]
    drop = {k for k in nonempty if rng.random() < prob}
    if drop and len(drop) >= len(nonempty):        # never drop every real line
        drop.discard(min(drop))

    new_text, remap, cur = "", [], 0
    for k, (a, b, _) in enumerate(ranges):
        if k in drop:
            continue
        remap.append((a, b, cur))
        new_text += text[a:b]
        cur += b - a

    new_spans = []
    for s, e, lab in spans:
        for a, b, ns in remap:
            if a <= s < b and e <= b:
                new_spans.append([ns + s - a, ns + e - a, lab])
                break
    return new_text, new_spans


def add_ocr_noise(text: str, spans, rate: float = 0.02, seed: int | None = None,
                  line_drop: float | None = None):
    """Corrupt text the way Tesseract does: drop whole lines (primary), plus a
    few length-preserving character swaps (secondary). Spans are remapped.
    `line_drop` defaults to `rate` when not given."""
    rng = random.Random(seed)
    if line_drop is None:
        line_drop = rate
    if line_drop > 0:
        text, spans = _drop_lines(text, spans, line_drop, rng)

    chars = list(text)
    for i, ch in enumerate(chars):
        if ch == "\n" or rng.random() > rate:
            continue
        if ch in _CONFUSE:
            chars[i] = _CONFUSE[ch]
        elif ch.isalpha():
            chars[i] = ch.upper() if ch.islower() else ch.lower()
    return "".join(chars), spans


# --- preview ---------------------------------------------------- #
def _preview() -> None:
    print(f"train drugs: {len(DRUG_TRAIN)}   held-out drugs: {len(DRUG_TEST)}")
    print("held-out drugs:", [d[0] for d in DRUG_TEST])
    print("held-out frequencies:", FREQ_TEST, "\n")
    for split in ("train", "unseen"):
        for s in (0, 1, 2):
            text, spans = generate(seed=s, split=split)
            print(f"{'='*64}\nsplit={split} seed={s}\n{'='*64}\n{text}")
            for a, e, lab in spans:
                print(f"  {lab:<10} {text[a:e]!r}")
            print()


if __name__ == "__main__":
    _preview()
