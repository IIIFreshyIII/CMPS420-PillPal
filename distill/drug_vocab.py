"""
Build a bundled drug-name list from RxNorm and fuzzy-match spans against it.

The NER model reads the label; this list is the controlled vocabulary that
validates its DRUG guesses (standard clinical-NLP architecture: model +
terminology). It fixes the model's measured weak spot -- DRUG precision ~0.4,
where manufacturer names / "Generic for NEURONTIN" / OCR garble get tagged DRUG.

    python drug_vocab.py --build          # download RxNorm -> distill/drug_names.txt
    python drug_vocab.py --check atomoxetine "AUROBINDO" "atomoxetine25m"

`drug_names.txt` is committed so nobody has to re-download. Source: RxNorm
"Current Prescribable Content" (freely redistributable subset, no UMLS login) --
ingredient (IN/PIN/MIN) and brand (BN) names only.
"""

from __future__ import annotations

import argparse
import io
import re
import sys
import zipfile
from difflib import SequenceMatcher
from pathlib import Path
from urllib.request import Request, urlopen

HERE = Path(__file__).resolve().parent
NAMES_FILE = HERE / "drug_names.txt"

RXNORM_URL = "https://download.nlm.nih.gov/rxnorm/RxNorm_full_prescribe_current.zip"
NDC_URL = "https://www.accessdata.fda.gov/cder/ndctext.zip"

# RxNorm term types worth keeping as label-style names
_KEEP_TTY = {"IN", "PIN", "MIN", "BN"}

# a strength/form chunk the OCR glues onto or runs after a drug name:
# "atomoxetine25mgcap", "venlafaxine 75 mg er cap" -> drop from the digit on,
# but only when a letter precedes it (so a bare "25 mg" STRENGTH span survives)
_STRENGTH_TAIL = re.compile(r"(?<=[a-z])\s*\d[\w.,%/\s-]*$", re.IGNORECASE)
_NONWORD_EDGES = re.compile(r"^[^0-9a-z]+|[^0-9a-z]+$")
_SPLIT = re.compile(r"[\s:/\\|]+")
# herbal / homeopathic / excipient entries RxNorm carries that never appear as
# the drug on a US prescription label -- drop them to shrink the list and cut
# fuzzy-collision risk
_HERBAL = re.compile(
    r"\b(extract|flower|leaf|root|seed|bark|pollen|whole|oil|juice|"
    r"reformulated|homeopathic)\b",
    re.IGNORECASE,
)


def _download(url: str) -> bytes:
    req = Request(url, headers={"User-Agent": "cmps420-pillpal/1.0"})
    with urlopen(req, timeout=120) as r:  # noqa: S310 - fixed gov URLs
        return r.read()


def _parse_rxnorm(zip_bytes: bytes) -> set[str]:
    names: set[str] = set()
    with zipfile.ZipFile(io.BytesIO(zip_bytes)) as z:
        conso = next(n for n in z.namelist() if n.upper().endswith("RXNCONSO.RRF"))
        with z.open(conso) as fh:
            for raw in io.TextIOWrapper(fh, encoding="utf-8", errors="replace"):
                # RRF: RXCUI|LAT|TS|LUI|STT|SUI|ISPREF|RXAUI|SAUI|SCUI|SDUI|SAB|TTY|CODE|STR|...
                f = raw.split("|")
                if len(f) > 14 and f[1] == "ENG" and f[12] in _KEEP_TTY:
                    n = _clean(f[14])
                    if n:
                        names.add(n)
    return names


def _parse_ndc(zip_bytes: bytes) -> set[str]:
    names: set[str] = set()
    with zipfile.ZipFile(io.BytesIO(zip_bytes)) as z:
        prod = next(n for n in z.namelist() if n.lower().endswith("product.txt"))
        with z.open(prod) as fh:
            reader = io.TextIOWrapper(fh, encoding="utf-8", errors="replace")
            header = next(reader).rstrip("\n").split("\t")
            pi = header.index("PROPRIETARYNAME")
            ni = header.index("NONPROPRIETARYNAME")
            for line in reader:
                cols = line.rstrip("\n").split("\t")
                if len(cols) <= max(pi, ni):
                    continue
                for cell in (cols[pi], cols[ni]):
                    for part in re.split(r"[;,/]| and ", cell):
                        n = _clean(part)
                        if n:
                            names.add(n)
    return names


def _clean(s: str) -> str:
    s = s.strip().lower()
    if "(" in s and ")" not in s:            # truncated parenthetical
        s = s[: s.index("(")].strip()
    s = _NONWORD_EDGES.sub("", s)
    if len(s) < 3 or len(s) > 45 or not re.search(r"[a-z]", s):
        return ""
    if len(s.split()) > 4 or _HERBAL.search(s):
        return ""
    return s


def build(source: str = "rxnorm") -> None:
    print(f">> downloading {source} ...", file=sys.stderr)
    if source == "rxnorm":
        names = _parse_rxnorm(_download(RXNORM_URL))
    elif source == "ndc":
        names = _parse_ndc(_download(NDC_URL))
    else:
        raise SystemExit(f"unknown source {source!r} (rxnorm|ndc)")
    ordered = sorted(names)
    NAMES_FILE.write_text("\n".join(ordered) + "\n")
    print(f">> wrote {NAMES_FILE}  ({len(ordered)} names)", file=sys.stderr)


# --------------------------------------------------------------------------- #
class DrugMatcher:
    """Match a (possibly OCR-mangled) span against the drug-name list."""

    def __init__(self, names_file: Path | None = None) -> None:
        path = names_file or NAMES_FILE
        if not path.exists():
            raise SystemExit(f"{path} missing -- run:  python drug_vocab.py --build")
        self.names = [n for n in path.read_text().splitlines() if n]
        self._exact = set(self.names)
        # bucket by first char + rough length for a cheap fuzzy shortlist
        self._buckets: dict[tuple[str, int], list[str]] = {}
        for n in self.names:
            self._buckets.setdefault((n[0], len(n) // 3), []).append(n)

    @staticmethod
    def _norm(s: str) -> str:
        s = re.sub(r"\s+", " ", s.strip().lower())
        s = _STRENGTH_TAIL.sub("", s)          # "atomoxetine25m" -> "atomoxetine"
        return _NONWORD_EDGES.sub("", s).strip()

    def _forms(self, span_text: str):
        """Candidate strings to look up, roughly best-first: whole span, then each
        token (real spans: 'delroy\\natomoxetine25m', 'atomoxetine hcl',
        'mfr:aurobindo')."""
        whole = self._norm(span_text)
        seen = {whole} if whole else set()
        yield whole
        for tok in _SPLIT.split(span_text.strip()):
            t = self._norm(tok)
            if t and t not in seen:
                seen.add(t)
                yield t

    def match(self, span_text: str) -> dict:
        """-> {canonical, recognized, corrected}."""
        forms = [f for f in self._forms(span_text) if len(f) >= 3]
        if not forms:
            return {"canonical": span_text.strip().lower(), "recognized": False, "corrected": False}
        for f in forms:
            if f in self._exact:
                return {"canonical": f, "recognized": True, "corrected": f != forms[0]}
        for f in forms:
            if len(f) < 5:
                continue
            best, best_score = None, 0.0
            for cand in self._candidates(f):
                score = SequenceMatcher(None, f, cand).ratio()
                if score > best_score:
                    best, best_score = cand, score
            if best is not None and best_score >= 0.88:
                return {"canonical": best, "recognized": True, "corrected": True}
        return {"canonical": forms[0], "recognized": False, "corrected": False}

    def _candidates(self, n: str):
        for dl in (-1, 0, 1):
            yield from self._buckets.get((n[0], len(n) // 3 + dl), ())


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--build", action="store_true", help="download + rebuild drug_names.txt")
    ap.add_argument("--source", default="rxnorm", choices=["rxnorm", "ndc"])
    ap.add_argument("--check", nargs="+", metavar="SPAN", help="test-match some strings")
    args = ap.parse_args()

    if args.build:
        build(args.source)
    if args.check:
        m = DrugMatcher()
        print(f"({len(m.names)} names loaded)")
        for s in args.check:
            print(f"  {s!r:30} -> {m.match(s)}")
    if not args.build and not args.check:
        ap.print_help()


if __name__ == "__main__":
    main()
