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
    text, spans = add_ocr_noise(text, spans, rate=0.01, seed=0)   # 0.01 ~= real-photo OCR

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
    # topicals: "%" strengths, cream/ointment/gel forms, "to the affected area" routes
    ("econazole", "nitrate", ["1%"], ["cream"]),
    ("ketoconazole", "", ["2%"], ["cream", "shampoo"]),
    ("clotrimazole", "", ["1%"], ["cream"]),
    ("terbinafine", "hcl", ["1%"], ["cream"]),
    ("metronidazole", "", ["0.75%", "1%", "250 mg", "500 mg"], ["cream", "gel", "tablet"]),
    ("hydrocortisone", "", ["1%", "2.5%"], ["cream", "ointment"]),
    ("triamcinolone", "acetonide", ["0.025%", "0.1%"], ["cream", "ointment"]),
    ("mupirocin", "", ["2%"], ["ointment"]),
    ("clindamycin", "phosphate", ["1%"], ["gel", "solution"]),
    ("tretinoin", "", ["0.025%", "0.05%"], ["cream", "gel"]),
    ("ketorolac", "tromethamine", ["10 mg"], ["tablet"]),
    ("dicyclomine", "hcl", ["10 mg", "20 mg"], ["tablet", "capsule"]),
    ("ranitidine", "hcl", ["150 mg", "300 mg"], ["tablet"]),
    ("clonidine", "hcl", ["0.1 mg", "0.2 mg"], ["tablet"]),
    ("hydralazine", "hcl", ["10 mg", "25 mg", "50 mg"], ["tablet"]),
    ("amitriptyline", "hcl", ["10 mg", "25 mg", "50 mg", "75 mg"], ["tablet"]),
    ("nortriptyline", "hcl", ["10 mg", "25 mg"], ["capsule"]),
    ("paroxetine", "hcl", ["10 mg", "20 mg", "30 mg"], ["tablet"]),
    ("clonazepam", "", ["0.5 mg", "1 mg", "2 mg"], ["tablet"]),
    ("lorazepam", "", ["0.5 mg", "1 mg", "2 mg"], ["tablet"]),
    ("alprazolam", "", ["0.25 mg", "0.5 mg", "1 mg"], ["tablet"]),
    ("methylphenidate", "hcl", ["5 mg", "10 mg", "20 mg"], ["tablet", "ER tablet"]),
    ("atomoxetine", "hcl", ["10 mg", "18 mg", "25 mg", "40 mg", "60 mg", "80 mg"], ["capsule"]),
    ("lithium", "carbonate", ["150 mg", "300 mg", "600 mg"], ["capsule", "ER tablet"]),
    ("divalproex", "sodium", ["125 mg", "250 mg", "500 mg"], ["DR tablet", "ER tablet"]),
    ("carbamazepine", "", ["100 mg", "200 mg"], ["tablet", "ER tablet"]),
    ("oxcarbazepine", "", ["150 mg", "300 mg", "600 mg"], ["tablet"]),
    ("phenytoin", "sodium", ["100 mg"], ["ER capsule"]),
    ("prochlorperazine", "maleate", ["5 mg", "10 mg"], ["tablet"]),
    ("metoclopramide", "hcl", ["5 mg", "10 mg"], ["tablet"]),
    ("dexamethasone", "", ["0.5 mg", "1 mg", "4 mg"], ["tablet"]),
    ("methylprednisolone", "", ["4 mg"], ["tablet", "dose pack"]),
    ("cefdinir", "", ["300 mg"], ["capsule"]),
    ("amoxicillin-clavulanate", "", ["500 mg", "875 mg"], ["tablet"]),
    ("sulfamethoxazole-trimethoprim", "", ["800 mg"], ["tablet", "DS tablet"]),
    ("clarithromycin", "", ["250 mg", "500 mg"], ["tablet"]),
    ("acyclovir", "", ["200 mg", "400 mg", "800 mg"], ["tablet", "capsule"]),
    ("terazosin", "hcl", ["1 mg", "2 mg", "5 mg"], ["capsule"]),
    ("doxazosin", "mesylate", ["1 mg", "2 mg", "4 mg", "8 mg"], ["tablet"]),
    ("potassium chloride", "", ["10 mEq", "20 mEq"], ["ER tablet"]),
    ("folic acid", "", ["1 mg"], ["tablet"]),
    ("cyanocobalamin", "", ["1000 mcg"], ["tablet"]),
    ("cholecalciferol", "", ["1000 unit", "2000 unit", "50000 unit"], ["capsule", "tablet"]),
    ("ferrous sulfate", "", ["325 mg"], ["tablet"]),
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

DOSE_AMOUNTS = ["1", "2", "3", "one", "two", "1 to 2", "1-2", "one-half", "1/2", "one to two",
                "a thin layer", "a small amount", "a thin film"]
ROUTES = ["by mouth", "by mouth", "by mouth", "orally", "PO", "by mouth",
          "into the affected eye", "in each eye", "by inhalation", "in each nostril",
          "sublingually", "topically",
          "to the affected area", "to the affected area", "to the affected skin",
          "to affected areas", "to the face"]
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

# --- distractor vocab: everything below appears on real labels near the fields
#     we care about, and the model must learn to leave it as O ---------- #
MANUFACTURERS = [
    "AUROBINDO PHARMA", "DR. REDDY'S LABORATORIES", "TEVA PHARMACEUTICALS", "MYLAN",
    "SANDOZ INC", "ACCORD HEALTHCARE", "CAMBER PHARMACEUTICALS", "ZYDUS PHARMACEUTICALS",
    "LUPIN PHARMACEUTICALS", "AMNEAL PHARMACEUTICALS", "APOTEX CORP", "TORRENT PHARMA",
    "GRANULES PHARMACEUTICALS", "AMBER PHARMACEUTICALS", "TRIS PHARMA", "NORTHSTAR RX",
    "AJANTA PHARMA", "ASCEND LABORATORIES", "MACLEODS PHARMACEUTICALS", "GLENMARK",
    "ALEMBIC PHARMACEUTICALS", "RISING PHARMACEUTICALS", "PRINCETON",
]
GENERIC_BRANDS = [
    "NEURONTIN", "LIPITOR", "ZOLOFT", "PRILOSEC", "NORVASC", "LASIX", "COZAAR",
    "SYNTHROID", "GLUCOPHAGE", "VIBRAMYCIN", "EFFEXOR XR", "XANAX", "LEXAPRO",
    "AMBIEN", "CYMBALTA", "SEROQUEL", "WELLBUTRIN", "CRESTOR", "SPECTAZOLE",
    "FLAGYL", "DIFLUCAN", "KEFLEX",
]
REASON_PHRASES = [
    "for pain", "for nerve pain", "for anxiety", "for blood pressure",
    "for cholesterol", "for sleep", "for infection", "for reflux", "for flaking",
    "for itching", "for swelling", "as directed", "as directed by prescriber",
]
NOISE_WORDS = [
    "*THANK YOU*", "THANK YOU", "KEEP OUT OF REACH OF CHILDREN", "SHAKE WELL BEFORE USE",
    "FOR EXTERNAL USE ONLY", "DERMATOLOGIC USE ONLY", "REFRIGERATE", "DO NOT REFRIGERATE",
    "PROTECT FROM LIGHT", "SWALLOW WHOLE DO NOT CHEW", "NO REFILLS REMAINING",
    "REFILLS REMAINING", "FEDERAL LAW PROHIBITS TRANSFER", "STORE AT ROOM TEMPERATURE",
    "WITH A FULL GLASS OF WATER",
]

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
    if route == "topically" or "affected" in route or "face" in route or "skin" in route:
        return rng.choice(["Apply", "Apply", "Use"])
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
    if rng.random() < 0.35:
        b.sp()
        b.add(_casing(rng.choice(REASON_PHRASES), case))   # deliberately unlabelled -> O
    b.line(rng.choice([".", "", ".", "; refill as needed", " *THANK YOU*"]))
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


def _emit_distractors(b, rng, n: int) -> None:
    """Emit n lines of the stuff that sits *next to* the fields on a real label
    and that the model keeps mislabelling: manufacturer names, 'Generic for X',
    boilerplate. None of it carries a label -> all O."""
    for _ in range(n):
        r = rng.random()
        if r < 0.34:
            pre = rng.choice(["MFR:", "MFG", "Mfr:", "MFR", "MANUFACTURER:", "Mfg by"])
            b.line(f"{pre} {rng.choice(MANUFACTURERS)}")
        elif r < 0.58:
            b.line(f"{rng.choice(['Generic for', 'GENERIC FOR', 'Gen. for', 'Substituted for'])} "
                   f"{rng.choice(GENERIC_BRANDS)}")
        elif r < 0.80:
            b.line(rng.choice(NOISE_WORDS))
        elif r < 0.90:
            b.line(f"NDC {rng.randint(10000, 99999)}-{rng.randint(100, 999)}-{rng.randint(10, 99)}")
        else:
            b.line(f"Disp by: {rng.choice(['RG/CP', 'VL/CDP', 'JM', 'RPH', 'AB/CD'])}")


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

    # keep the sig roughly coherent with the form (topicals get applied, not swallowed)
    _topical = form in ("cream", "ointment", "gel", "lotion", "shampoo")
    if _topical:
        dose = rng.choice(["a thin layer", "a small amount", "a thin film", "a thin layer"])
        route = rng.choice(["to the affected area", "to the affected area",
                            "to the affected skin", "to affected areas", "to the face", "topically"])
    elif dose in ("a thin layer", "a small amount", "a thin film"):
        dose = rng.choice(["1", "one", "2", "1 to 2"])
    _skin_route = any(w in route for w in ("affected", "face", "skin")) or route == "topically"
    if not _topical and _skin_route:
        if "tab" in form or "cap" in form:
            route = rng.choice(["by mouth", "by mouth", "orally", "PO"])
        elif "eye" in form or "drop" in form:
            route = rng.choice(["in each eye", "into the affected eye"])
        elif "inhaler" in form or "spray" in form:
            route = rng.choice(["by inhalation", "in each nostril"])
        else:
            route = "by mouth"
    case = rng.choice(["upper", "upper", "title", "as-is", "lower"])
    pharm, phone = rng.choice(pharms)

    m, d, y = _emit_header(b, pharm, phone, case, rng)
    _emit_distractors(b, rng, rng.randint(0, 2))
    # sig sometimes comes before the drug-strength line, sometimes after
    if rng.random() < 0.85:
        _emit_drug_line(b, drug, salt, strength, form, case, rng)
        if rng.random() < 0.65:
            _emit_distractors(b, rng, 1)
        _emit_sig_line(b, dose, form, route, freq, dur, case, rng)
    else:
        _emit_sig_line(b, dose, form, route, freq, dur, case, rng)
        _emit_drug_line(b, drug, salt, strength, form, case, rng)
        if rng.random() < 0.65:
            _emit_distractors(b, rng, 1)
    _emit_distractors(b, rng, rng.randint(0, 1))
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
# Real OCR (RapidOCR / ML Kit) on a curved bottle label does four things, and the
# distilled model fails on all four because clean synthetic text never shows them:
#   1. drops whole lines / regions it can't segment
#   2. deletes the space between fields    -> "ATOMOXETINE25MGCAP", "capsule3times"
#   3. truncates the tail of a line that wraps off the bottle -> "by mouth in the"
#   4. garbles characters, especially in the low-contrast boilerplate
# We model each as a set of character deletions, remap the spans once, then swap
# characters on what's left. A span whose text is partly deleted is clipped; one
# that's fully deleted is dropped (the field is simply gone).
_CONFUSE = {
    "0": "O", "O": "0", "1": "l", "l": "1", "I": "l", "5": "S", "S": "5",
    "8": "B", "B": "8", "2": "Z", "Z": "2", "6": "b", "g": "9", "9": "g",
}


def _apply_deletions(text: str, spans, deleted: set) -> tuple[str, list]:
    """Rebuild text with `deleted` char indices removed; remap/clip/drop spans."""
    if not deleted:
        return text, [list(s) for s in spans]
    keep = [i for i in range(len(text)) if i not in deleted]
    new_index = {old: new for new, old in enumerate(keep)}
    new_text = "".join(text[i] for i in keep)
    new_spans = []
    for s, e, lab in spans:
        kept = [i for i in range(s, e) if i not in deleted]
        if not kept:
            continue                       # whole field lost
        new_spans.append([new_index[kept[0]], new_index[kept[-1]] + 1, lab])
    return new_text, new_spans


def _line_spans(text: str):
    """(start, content_end) for every line — content_end excludes the '\\n'."""
    out, i = [], 0
    for ln in text.splitlines(keepends=True):
        out.append((i, i + len(ln.rstrip("\n"))))
        i += len(ln)
    return out


def add_ocr_noise(text: str, spans, rate: float = 0.02, seed: int | None = None,
                  line_drop: float | None = None):
    """Corrupt `text` the way real label OCR does and remap `spans`. `rate` is the
    master knob (0 = off); the sub-effects below scale off it. `line_drop`
    overrides the per-line drop probability."""
    rng = random.Random(seed)
    spans = [list(s) for s in spans]
    if rate <= 0:
        return text, spans

    ld = rate if line_drop is None else line_drop
    lines = _line_spans(text)
    content = [(a, c) for a, c in lines if text[a:c].strip()]
    deleted: set = set()

    # 1. drop whole lines (keep at least one content line)
    droppable = [k for k in range(len(content)) if rng.random() < ld]
    if len(droppable) >= len(content) and content:
        droppable = droppable[1:]
    for k in droppable:
        a, c = content[k]
        deleted.update(range(a, c))

    # 2. truncate the tail of a line that "wraps off the bottle"
    p_trunc = min(0.9, rate * 12)
    for a, c in content:
        if c - a > 5 and rng.random() < p_trunc:
            cut = rng.randint(1, min(8, c - a - 2))
            deleted.update(range(c - cut, c))

    # 3. delete spaces (hard at field boundaries, softer elsewhere) and some \n
    edge = set()
    for s, e, _ in spans:
        edge.add(s - 1)
        edge.add(e)
    p_edge, p_mid, p_nl = min(0.6, rate * 26), min(0.22, rate * 6), min(0.14, rate * 5)
    for i, ch in enumerate(text):
        if ch == " " and rng.random() < (p_edge if i in edge else p_mid):
            deleted.add(i)
        elif ch == "\n" and rng.random() < p_nl:
            deleted.add(i)

    new_text, new_spans = _apply_deletions(text, spans, deleted)
    if spans and not new_spans:                 # too aggressive - back off to line-drop only
        new_text, new_spans = _apply_deletions(
            text, spans, {i for k in droppable for i in range(*content[k])})

    # 4. character garble - heavier on the boilerplate than on the fields
    field_chars = {i for s, e, _ in new_spans for i in range(s, e)}
    chars = list(new_text)
    for i, ch in enumerate(chars):
        if ch in ("\n", " "):
            continue
        if rng.random() > (rate if i in field_chars else rate * 2.5):
            continue
        if ch in _CONFUSE:
            chars[i] = _CONFUSE[ch]
        elif ch.isalpha():
            chars[i] = ch.upper() if ch.islower() else ch.lower()
    return "".join(chars), new_spans


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
