"""
Validate / normalize raw model spans against controlled vocabularies.

The NER model proposes spans; this layer checks each one:
  DRUG      -> RxNorm list (drug_vocab.DrugMatcher): normalize, or drop if it's a
              manufacturer / pure OCR garble, else keep-and-flag
  FORM      -> ~20-item closed set (tab->tablet, er cap->capsule, ...)
  ROUTE     -> ~15-item closed set (po/orally->by mouth, affected area->topically)
  STRENGTH  -> keep; sanity-flag if it has no digit
  DOSAGE    -> keep; sanity-flag if it has no digit / number word
  FREQUENCY, DURATION -> passthrough

`refine(spans, text)` returns a list of dicts:
  {start, end, type, text, canonical, recognized}
`recognized=False` means "show it to the user but flag: not in the vocabulary" --
never a silent delete, because every field is human-confirmed anyway. The one
exception is a DRUG span that is clearly a manufacturer name or non-word garble;
those are dropped.
"""

from __future__ import annotations

import re

from drug_vocab import DrugMatcher

# generic-manufacturer tokens the model kept tagging as DRUG (from diagnose_real)
MANUFACTURER_STOP = {
    "aurobindo", "teva", "mylan", "sandoz", "accord", "camber", "zydus", "lupin",
    "amneal", "apotex", "torrent", "granules", "amber", "tris", "northstar",
    "ajanta", "ascend", "macleods", "glenmark", "alembic", "rising", "princeton",
    "reddy", "reddys", "laboratories", "laboratory", "labs", "pharma",
    "pharmaceutical", "pharmaceuticals", "inc", "llc", "ltd", "usa", "co",
    "mfr", "mfg", "manufacturer", "generic", "brand", "distributed",
}

_FORM_CANON = {
    "tab": "tablet", "tabs": "tablet", "tablet": "tablet", "tablets": "tablet",
    "cap": "capsule", "caps": "capsule", "capsule": "capsule", "capsules": "capsule",
    "er tab": "tablet", "er tablet": "tablet", "dr tab": "tablet", "dr tablet": "tablet",
    "sr tab": "tablet", "er cap": "capsule", "er capsule": "capsule",
    "dr cap": "capsule", "sr cap": "capsule",
    "cream": "cream", "ointment": "ointment", "oint": "ointment", "gel": "gel",
    "lotion": "lotion", "foam": "foam", "solution": "solution", "soln": "solution",
    "suspension": "suspension", "susp": "suspension", "syrup": "syrup",
    "elixir": "solution", "inhaler": "inhaler", "hfa inhaler": "inhaler",
    "nebulizer solution": "solution", "spray": "spray", "nasal spray": "spray",
    "patch": "patch", "film": "film", "drops": "drops", "eye drops": "drops",
    "suppository": "suppository", "shampoo": "shampoo", "powder": "powder",
    "packet": "packet", "kit": "kit", "pen": "pen", "vial": "vial",
}

_ROUTE_CANON = {
    "by mouth": "by mouth", "oral": "by mouth", "orally": "by mouth", "po": "by mouth",
    "mouth": "by mouth", "swallow": "by mouth",
    "topical": "topically", "topically": "topically", "externally": "topically",
    "to the affected area": "topically", "affected area": "topically",
    "affected areas": "topically", "to the affected skin": "topically",
    "affected skin": "topically", "to affected areas": "topically",
    "to the face": "topically", "to face": "topically", "to the scalp": "topically",
    "in each eye": "in each eye", "into the affected eye": "in each eye",
    "affected eye": "in each eye", "each eye": "in each eye", "both eyes": "in each eye",
    "in each nostril": "in each nostril", "each nostril": "in each nostril",
    "nasally": "in each nostril",
    "by inhalation": "by inhalation", "inhalation": "by inhalation",
    "inhaled": "by inhalation", "orally inhaled": "by inhalation",
    "sublingually": "sublingually", "under the tongue": "sublingually",
    "rectally": "rectally", "vaginally": "vaginally",
    "subcutaneously": "subcutaneously", "subcutaneous": "subcutaneously",
}

_WORD_NUM = re.compile(r"\b(one|two|three|four|half|thin|small)\b")
_NONWORD = re.compile(r"[^a-z]")


def _norm(s: str) -> str:
    return re.sub(r"\s+", " ", s.strip().lower())


def _lookup(n: str, table: dict[str, str]) -> str | None:
    """Exact, else the longest table key that appears at a word boundary in n
    (catches glued/truncated OCR: 'capsule3time' -> capsule)."""
    if n in table:
        return table[n]
    hits = [(len(k), v) for k, v in table.items() if re.search(rf"\b{re.escape(k)}", n)]
    return max(hits)[1] if hits else None


def _tighten(frag: str, start: int, canonical: str) -> tuple[int, int] | None:
    """If `canonical` (or its first word) sits literally inside `frag`, shrink the
    span to just that -- fixes the model's 'grabbed the glued neighbour' errors
    ('ATOMOXETINE25M' span -> 'ATOMOXETINE')."""
    low = frag.lower()
    for needle in (canonical, canonical.split(" ")[0], canonical.split("/")[0].strip()):
        if len(needle) >= 4 and needle in low:
            p = low.index(needle)
            return start + p, start + p + len(needle)
    return None


def _is_manufacturer_or_junk(n: str) -> bool:
    toks = [t for t in re.split(r"[\s:/\\|.,]+", n) if t]
    if not toks:
        return True
    if all(t in MANUFACTURER_STOP for t in toks):
        return True
    if any(t in MANUFACTURER_STOP for t in toks) and len(toks) <= 3:
        return True
    if "generic for" in n or "mfr" in n or "mfg" in n:
        return True
    letters = _NONWORD.sub("", n)
    return len(letters) < 3


def refine(spans, text: str, matcher: DrugMatcher | None = None) -> list[dict]:
    matcher = matcher or DrugMatcher()
    out: list[dict] = []
    for s, e, typ in spans:
        frag = text[s:e]
        n = _norm(frag)
        rec = {"start": s, "end": e, "type": typ, "text": frag,
               "canonical": frag, "recognized": True}

        if typ == "DRUG":
            m = matcher.match(frag)
            rec["canonical"] = m["canonical"]
            rec["recognized"] = m["recognized"]
            if not m["recognized"] and _is_manufacturer_or_junk(n):
                continue                       # drop: manufacturer / garble
            if m["recognized"]:
                t = _tighten(frag, s, m["canonical"])
                if t:
                    rec["start"], rec["end"], rec["text"] = t[0], t[1], text[t[0]:t[1]]
        elif typ == "FORM":
            c = _lookup(n, _FORM_CANON)
            rec["canonical"], rec["recognized"] = (c or frag), c is not None
            if c and (t := _tighten(frag, s, c)):
                rec["start"], rec["end"], rec["text"] = t[0], t[1], text[t[0]:t[1]]
        elif typ == "ROUTE":
            c = _lookup(n, _ROUTE_CANON)
            rec["canonical"], rec["recognized"] = (c or frag), c is not None
        elif typ == "STRENGTH":
            rec["recognized"] = bool(re.search(r"\d", n))
        elif typ == "DOSAGE":
            rec["recognized"] = bool(re.search(r"\d", n) or _WORD_NUM.search(n))
        # FREQUENCY, DURATION: passthrough

        out.append(rec)
    return out


def first_per_type(refined: list[dict]) -> dict[str, dict]:
    """The confirm screen shows one value per field -> take the first span of
    each type (matches evaluate.py / the model pipeline order)."""
    picked: dict[str, dict] = {}
    for r in refined:
        picked.setdefault(r["type"], r)
    return picked
