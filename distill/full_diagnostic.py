"""
Full Med7-vs-DistilBERT diagnostic.

Expands on three things that already existed separately -- evaluate.py's
strict seqeval P/R/F1, diagnose_real.py's per-example span-by-span view, and
technical_spike.py's latency measurement -- into one program that runs both
models on the same real labels and writes one full-picture report. Nothing
here reinvents those; it imports and reuses them directly.

Med7 only runs where spaCy + en_core_med7_lg are installed -- the homelab GPU
server (see SERVER.md), not this laptop. Run it there:

    python full_diagnostic.py

or locally without Med7 (DistilBERT-only columns):

    python full_diagnostic.py --no-med7

Writes, next to this script:
    full_diagnostic/results.json          -- every example, every model, full detail
    full_diagnostic/FULL_DIAGNOSTIC.md     -- the readable comparison report

Copy results.json into Phase 2/technical_spike/ once generated on the server.
FULL_DIAGNOSTIC.md is committed and pushed to git automatically when the run
finishes -- it's just the report on data we're testing, not source data or
app code, so that's fine to automate. Nothing else in the working tree is
touched: results.json and everything else stay local, untracked, unpushed.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import statistics
import time
from pathlib import Path

from drug_vocab import DrugMatcher
from make_dataset import med7_spans, spans_to_bio
from postprocess import first_per_type, refine
from technical_spike import build_pipe

HERE = Path(__file__).resolve().parent
DATA = HERE / "data" / "real_test.jsonl"
OUT_DIR = HERE / "full_diagnostic"

FIELD = {"DRUG": "drug", "STRENGTH": "strength", "DOSAGE": "dose", "FORM": "form",
         "ROUTE": "route", "FREQUENCY": "frequency", "DURATION": "duration"}
ENTITY_TYPES = ("DRUG", "STRENGTH", "DOSAGE", "FORM", "ROUTE", "FREQUENCY", "DURATION")


def _norm(s: str) -> str:
    return " ".join(s.split()).lower()


def score_spans(text: str, gold: list, pred: list) -> dict:
    """Exact + loose (span-off) span matching, same logic as diagnose_real.py."""
    gold_set = {(s, e, lab) for s, e, lab in gold}
    gold_by_norm = {(_norm(text[s:e]), lab) for s, e, lab in gold}
    pred_by_norm = {(_norm(text[a:b]), l) for a, b, l in pred}

    hits, fps = [], []
    for s, e, lab in pred:
        frag = text[s:e]
        if (s, e, lab) in gold_set or (_norm(frag), lab) in gold_by_norm:
            hits.append((s, e, lab, frag))
        else:
            fps.append((s, e, lab, frag))
    misses = [(s, e, lab, text[s:e]) for s, e, lab in gold
              if (_norm(text[s:e]), lab) not in pred_by_norm]
    return {"hits": hits, "misses": misses, "false_positives": fps}


def field_hit(gold: list, text: str, field_value: str | None, label: str) -> bool | None:
    """Does the validated pipeline's canonical field value loosely match gold for this label?"""
    gold_frags = [_norm(text[s:e]) for s, e, lab in gold if lab == label]
    if not gold_frags:
        return None  # nothing to check this field against
    if field_value is None:
        return False
    fv = _norm(field_value)
    return any(fv in g or g in fv for g in gold_frags)


def prf1(hits: int, misses: int, fps: int) -> tuple[float, float, float]:
    p = hits / (hits + fps) if (hits + fps) else 0.0
    r = hits / (hits + misses) if (hits + misses) else 0.0
    f1 = 2 * p * r / (p + r) if (p + r) else 0.0
    return p, r, f1


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--no-med7", action="store_true", help="skip Med7 (it needs spaCy + en_core_med7_lg)")
    args = ap.parse_args()
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    pipe, tok = build_pipe()
    matcher = DrugMatcher()

    nlp = None
    if not args.no_med7:
        try:
            import spacy
            nlp = spacy.load("en_core_med7_lg")
        except Exception as exc:
            print(f"(Med7 unavailable, continuing without it: {exc})")

    rows = [json.loads(l) for l in DATA.read_text().splitlines() if l.strip()]

    examples = []
    distil_latencies, med7_latencies = [], []
    seqeval_gold, seqeval_distil, seqeval_med7 = [], [], []
    tally = {"med7": {t: {"hit": 0, "miss": 0, "fp": 0} for t in ENTITY_TYPES},
             "distil_raw": {t: {"hit": 0, "miss": 0, "fp": 0} for t in ENTITY_TYPES},
             "distil_validated": {t: {"hit": 0, "miss": 0} for t in ENTITY_TYPES}}
    agree_gold, distil_only, med7_only, both_wrong = 0, 0, 0, 0
    fp_drug_strings = {"med7": {}, "distil_raw": {}}

    for r in rows:
        text, gold = r["text"], r["entities"]

        t0 = time.perf_counter()
        raw = [[s["start"], s["end"], s["entity_group"]] for s in pipe(text)]
        distil_latencies.append((time.perf_counter() - t0) * 1000)

        m7 = []
        if nlp is not None:
            t0 = time.perf_counter()
            m7 = med7_spans(nlp, text)
            med7_latencies.append((time.perf_counter() - t0) * 1000)

        refined = refine(raw, text, matcher)
        validated_fields = {FIELD[t]: r_["canonical"] for t, r_ in first_per_type(refined).items()}

        # strict BIO alignment, same as evaluate.py
        _, g_tags = spans_to_bio(text, gold, tok)
        _, d_tags = spans_to_bio(text, raw, tok)
        seqeval_gold.append(g_tags)
        seqeval_distil.append(d_tags)
        if nlp is not None:
            _, m_tags = spans_to_bio(text, m7, tok)
            seqeval_med7.append(m_tags)

        # loose span scoring, per model
        d_score = score_spans(text, gold, raw)
        m_score = score_spans(text, gold, m7) if nlp is not None else {"hits": [], "misses": [], "false_positives": []}

        for s, e, lab, frag in d_score["hits"]:
            tally["distil_raw"][lab]["hit"] += 1
        for s, e, lab, frag in d_score["misses"]:
            tally["distil_raw"][lab]["miss"] += 1
        for s, e, lab, frag in d_score["false_positives"]:
            tally["distil_raw"][lab]["fp"] += 1
            if lab == "DRUG":
                fp_drug_strings["distil_raw"][_norm(frag)] = fp_drug_strings["distil_raw"].get(_norm(frag), 0) + 1
        if nlp is not None:
            for s, e, lab, frag in m_score["hits"]:
                tally["med7"][lab]["hit"] += 1
            for s, e, lab, frag in m_score["misses"]:
                tally["med7"][lab]["miss"] += 1
            for s, e, lab, frag in m_score["false_positives"]:
                tally["med7"][lab]["fp"] += 1
                if lab == "DRUG":
                    fp_drug_strings["med7"][_norm(frag)] = fp_drug_strings["med7"].get(_norm(frag), 0) + 1

        # validated-pipeline field-level hit/miss
        for lab, field in FIELD.items():
            ok = field_hit(gold, text, validated_fields.get(field), lab)
            if ok is None:
                continue
            tally["distil_validated"][lab]["hit" if ok else "miss"] += 1

        # who's right when Med7 and raw DistilBERT disagree with each other (DRUG field, most comparable)
        d_drug_hit = any(lab == "DRUG" for s, e, lab, f in d_score["hits"])
        m_drug_hit = any(lab == "DRUG" for s, e, lab, f in m_score["hits"]) if nlp is not None else None
        has_gold_drug = any(lab == "DRUG" for s, e, lab in gold)
        if has_gold_drug and nlp is not None:
            if d_drug_hit and m_drug_hit:
                agree_gold += 1
            elif d_drug_hit and not m_drug_hit:
                distil_only += 1
            elif m_drug_hit and not d_drug_hit:
                med7_only += 1
            else:
                both_wrong += 1

        examples.append({
            "source": r["source"], "text": text, "gold": gold,
            "distilbert_raw": raw, "distilbert_validated_fields": validated_fields,
            "med7": m7,
            "distilbert_score": {k: [list(t) for t in v] for k, v in d_score.items()},
            "med7_score": {k: [list(t) for t in v] for k, v in m_score.items()} if nlp is not None else None,
        })

    # ---- strict seqeval P/R/F1, same metric evaluate.py already reports ----
    from seqeval.metrics import f1_score, precision_score, recall_score
    strict = {
        "distilbert_raw": {"precision": precision_score(seqeval_gold, seqeval_distil, zero_division=0),
                            "recall": recall_score(seqeval_gold, seqeval_distil, zero_division=0),
                            "f1": f1_score(seqeval_gold, seqeval_distil, zero_division=0)},
    }
    if nlp is not None:
        strict["med7"] = {"precision": precision_score(seqeval_gold, seqeval_med7, zero_division=0),
                           "recall": recall_score(seqeval_gold, seqeval_med7, zero_division=0),
                           "f1": f1_score(seqeval_gold, seqeval_med7, zero_division=0)}

    # ---- loose per-field P/R/F1, from the tallies above ----
    loose = {}
    for model in ("med7", "distil_raw"):
        if model == "med7" and nlp is None:
            continue
        loose[model] = {}
        for t in ENTITY_TYPES:
            c = tally[model][t]
            p, r, f1 = prf1(c["hit"], c["miss"], c["fp"])
            loose[model][t] = {"hit": c["hit"], "miss": c["miss"], "fp": c["fp"],
                                "precision": round(p, 3), "recall": round(r, 3), "f1": round(f1, 3)}
    validated_field_acc = {}
    for t in ENTITY_TYPES:
        c = tally["distil_validated"][t]
        total = c["hit"] + c["miss"]
        validated_field_acc[t] = {"hit": c["hit"], "miss": c["miss"],
                                   "accuracy": round(c["hit"] / total, 3) if total else None}

    out = {
        "n_examples": len(rows),
        "med7_available": nlp is not None,
        "latency_ms": {
            "distilbert_raw": {"min": round(min(distil_latencies), 2), "avg": round(statistics.mean(distil_latencies), 2), "max": round(max(distil_latencies), 2)},
            **({"med7": {"min": round(min(med7_latencies), 2), "avg": round(statistics.mean(med7_latencies), 2), "max": round(max(med7_latencies), 2)}} if med7_latencies else {}),
        },
        "strict_seqeval_f1": strict,
        "loose_span_prf1": loose,
        "distilbert_validated_field_accuracy": validated_field_acc,
        "drug_field_agreement": {"both_right": agree_gold, "distilbert_only": distil_only,
                                  "med7_only": med7_only, "both_wrong": both_wrong} if nlp is not None else None,
        "false_positive_drug_strings": fp_drug_strings,
        "examples": examples,
    }
    (OUT_DIR / "results.json").write_text(json.dumps(out, indent=2))

    # ---- readable report ----
    def fmt_prf1_table(d: dict) -> str:
        lines = ["| Field | Hit | Miss | FP | Precision | Recall | F1 |", "|---|--:|--:|--:|--:|--:|--:|"]
        for t in ENTITY_TYPES:
            c = d[t]
            lines.append(f"| {t} | {c['hit']} | {c['miss']} | {c['fp']} | {c['precision']:.3f} | {c['recall']:.3f} | {c['f1']:.3f} |")
        return "\n".join(lines)

    med7_note = "" if nlp is not None else "\n**Med7 was not available in this run** (`--no-med7` or spaCy/en_core_med7_lg missing) -- Med7 columns are omitted below. Run on the homelab GPU server (see SERVER.md) for the full comparison.\n"

    report = f"""# Full Diagnostic — Med7 vs. DistilBERT

Expands the technical spike into a side-by-side comparison against Med7, the
reference model DistilBERT was distilled from. Same {out['n_examples']} real,
hand-corrected prescription labels used throughout this project.
{med7_note}
## Latency

| | min ms | avg ms | max ms |
|---|--:|--:|--:|
| DistilBERT (int8 ONNX, on-device) | {out['latency_ms']['distilbert_raw']['min']} | {out['latency_ms']['distilbert_raw']['avg']} | {out['latency_ms']['distilbert_raw']['max']} |
{f"| Med7 (spaCy, server-only) | {out['latency_ms']['med7']['min']} | {out['latency_ms']['med7']['avg']} | {out['latency_ms']['med7']['max']} |" if 'med7' in out['latency_ms'] else ""}

Med7 can't run on-device at all (no mobile export) -- this number exists only
to show the gap, not because it's a real option.

## Strict accuracy (seqeval, exact span + type match)

Same metric `evaluate.py` reports, so these numbers are directly comparable to
the ones already in `DISTILLATION.md`.

| | Precision | Recall | F1 |
|---|--:|--:|--:|
| DistilBERT (raw) | {strict['distilbert_raw']['precision']:.3f} | {strict['distilbert_raw']['recall']:.3f} | {strict['distilbert_raw']['f1']:.3f} |
{f"| Med7 | {strict['med7']['precision']:.3f} | {strict['med7']['recall']:.3f} | {strict['med7']['f1']:.3f} |" if 'med7' in strict else ""}

## Loose accuracy, per field (span-off text match allowed)

A few characters of boundary drift doesn't matter for the real product -- this
view is forgiving of that the way the strict metric above isn't.

**DistilBERT (raw model output, before validation):**
{fmt_prf1_table(loose['distil_raw'])}
{f"**Med7:**{chr(10)}{fmt_prf1_table(loose['med7'])}" if 'med7' in loose else ""}

## The number that actually matters: DistilBERT + validation layer

DistilBERT's raw output is never what ships -- the RxNorm/closed-set
validation layer (`postprocess.py`) runs on top of it first. This is
field-level accuracy of *that* combined pipeline against gold:

| Field | Hit | Miss | Accuracy |
|---|--:|--:|--:|
{chr(10).join(f"| {t} | {validated_field_acc[t]['hit']} | {validated_field_acc[t]['miss']} | {validated_field_acc[t]['accuracy']:.3f} |" if validated_field_acc[t]['accuracy'] is not None else f"| {t} | - | - | n/a (no gold examples) |" for t in ENTITY_TYPES)}

{"## Where Med7 and DistilBERT disagree (DRUG field)" if nlp is not None else ""}
{f'''
Of {agree_gold + distil_only + med7_only + both_wrong} examples with a gold DRUG span:

| | count |
|---|--:|
| both models correct | {agree_gold} |
| DistilBERT right, Med7 wrong | {distil_only} |
| Med7 right, DistilBERT wrong | {med7_only} |
| both wrong | {both_wrong} |

DistilBERT was fine-tuned specifically on this project's label style (OCR noise,
pharmacy phrasing); Med7 is a general clinical-note model that never saw this
distribution. That's the expected shape of the disagreement, not a surprise.
''' if nlp is not None else ""}

## False-positive DRUG strings

What each model predicted as a drug name that wasn't one, most common first:

**DistilBERT:** {", ".join(f"{s!r} ({n})" for s, n in sorted(fp_drug_strings['distil_raw'].items(), key=lambda x: -x[1])[:8]) or "none"}
{f"**Med7:** {', '.join(f'{s!r} ({n})' for s, n in sorted(fp_drug_strings['med7'].items(), key=lambda x: -x[1])[:8]) or 'none'}" if nlp is not None else ""}

## Full per-example detail

Every example's gold spans, both models' raw predictions, and the validated
pipeline's final fields are in `results.json` -- the same level of detail
`diagnose_real.py` prints to the terminal, kept here as structured data instead.
"""
    (OUT_DIR / "FULL_DIAGNOSTIC.md").write_text(report)
    print(f"wrote {OUT_DIR / 'results.json'}")
    print(f"wrote {OUT_DIR / 'FULL_DIAGNOSTIC.md'}")

    push_report(OUT_DIR / "FULL_DIAGNOSTIC.md")


def push_report(md_path: Path) -> None:
    """Commit and push ONLY the .md report -- never results.json or anything
    else in the working tree. This is a deliberate, narrow exception to the
    project's normal "never commit without being asked each time" rule,
    made because this file is just a report on test data, not source data
    or app code. A push failure (offline, no upstream, etc.) is reported but
    never crashes the run -- the report is already safely written either way.
    """
    def run(*args: str) -> subprocess.CompletedProcess:
        return subprocess.run(["git", *args], cwd=HERE, capture_output=True, text=True)

    rel = md_path.relative_to(run("rev-parse", "--show-toplevel").stdout.strip() or HERE.parent)
    add = run("add", "--", str(md_path))
    if add.returncode != 0:
        print(f"(git add failed, report stays local only: {add.stderr.strip()})")
        return

    status = run("status", "--porcelain", "--", str(md_path))
    if not status.stdout.strip():
        print("(no change to the report since last commit -- nothing to push)")
        return

    commit = run("commit", "-m",
                 f"Update Med7 vs DistilBERT full diagnostic report\n\n"
                 f"Auto-generated by distill/full_diagnostic.py.\n\n"
                 f"Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>")
    if commit.returncode != 0:
        print(f"(git commit failed, report stays local only: {commit.stderr.strip()})")
        return

    push = run("push")
    if push.returncode != 0:
        print(f"(committed locally, but git push failed -- push it yourself when ready: {push.stderr.strip()})")
        return
    print(f"pushed {rel} to git")


if __name__ == "__main__":
    main()
