# Full Diagnostic — Med7 vs. DistilBERT

Expands the technical spike into a side-by-side comparison against Med7, the
reference model DistilBERT was distilled from. Same 29 real,
hand-corrected prescription labels used throughout this project.

## Latency

| | min ms | avg ms | max ms |
|---|--:|--:|--:|
| DistilBERT (int8 ONNX, on-device) | 3.52 | 7.82 | 19.19 |
| Med7 (spaCy, server-only) | 9.15 | 18.34 | 38.67 |

Med7 can't run on-device at all (no mobile export) -- this number exists only
to show the gap, not because it's a real option.

## Strict accuracy (seqeval, exact span + type match)

Same metric `evaluate.py` reports, so these numbers are directly comparable to
the ones already in `DISTILLATION.md`.

| | Precision | Recall | F1 |
|---|--:|--:|--:|
| DistilBERT (raw) | 0.573 | 0.593 | 0.583 |
| Med7 | 0.705 | 0.360 | 0.477 |

## Loose accuracy, per field (span-off text match allowed)

A few characters of boundary drift doesn't matter for the real product -- this
view is forgiving of that the way the strict metric above isn't.

**DistilBERT (raw model output, before validation):**
| Field | Hit | Miss | FP | Precision | Recall | F1 |
|---|--:|--:|--:|--:|--:|--:|
| DRUG | 7 | 9 | 9 | 0.438 | 0.438 | 0.438 |
| STRENGTH | 5 | 4 | 3 | 0.625 | 0.556 | 0.588 |
| DOSAGE | 11 | 1 | 3 | 0.786 | 0.917 | 0.846 |
| FORM | 15 | 7 | 8 | 0.652 | 0.682 | 0.667 |
| ROUTE | 4 | 2 | 3 | 0.571 | 0.667 | 0.615 |
| FREQUENCY | 9 | 10 | 11 | 0.450 | 0.474 | 0.462 |
| DURATION | 0 | 0 | 1 | 0.000 | 0.000 | 0.000 |
**Med7:**
| Field | Hit | Miss | FP | Precision | Recall | F1 |
|---|--:|--:|--:|--:|--:|--:|
| DRUG | 8 | 8 | 11 | 0.421 | 0.500 | 0.457 |
| STRENGTH | 4 | 5 | 0 | 1.000 | 0.444 | 0.615 |
| DOSAGE | 8 | 4 | 2 | 0.800 | 0.667 | 0.727 |
| FORM | 9 | 11 | 0 | 1.000 | 0.450 | 0.621 |
| ROUTE | 0 | 6 | 0 | 0.000 | 0.000 | 0.000 |
| FREQUENCY | 2 | 17 | 0 | 1.000 | 0.105 | 0.190 |
| DURATION | 0 | 0 | 0 | 0.000 | 0.000 | 0.000 |

## The number that actually matters: DistilBERT + validation layer

DistilBERT's raw output is never what ships -- the RxNorm/closed-set
validation layer (`postprocess.py`) runs on top of it first. This is
field-level accuracy of *that* combined pipeline against gold:

| Field | Hit | Miss | Accuracy |
|---|--:|--:|--:|
| DRUG | 14 | 2 | 0.875 |
| STRENGTH | 5 | 4 | 0.556 |
| DOSAGE | 11 | 1 | 0.917 |
| FORM | 14 | 6 | 0.700 |
| ROUTE | 2 | 4 | 0.333 |
| FREQUENCY | 17 | 2 | 0.895 |
| DURATION | - | - | n/a (no gold examples) |

## Where Med7 and DistilBERT disagree (DRUG field)

Of 16 examples with a gold DRUG span:

| | count |
|---|--:|
| both models correct | 5 |
| DistilBERT right, Med7 wrong | 2 |
| Med7 right, DistilBERT wrong | 3 |
| both wrong | 6 |

DistilBERT was fine-tuned specifically on this project's label style (OCR noise,
pharmacy phrasing); Med7 is a general clinical-note model that never saw this
distribution. That's the expected shape of the disagreement, not a surprise.


## False-positive DRUG strings

What each model predicted as a drug name that wasn't one, most common first:

**DistilBERT:** 'atomoxetine25m' (1), 'atomoxetine25mgcap' (1), 'venlafaxine75m' (1), 'venlafaxine7s' (1), 'venlafaxine75' (1), 'ne75mg' (1), 'nidazolet' (1), 'sorbitol' (1)
**Med7:** 'by:3/26/2027' (4), 'fhds' (1), 'capsuleb' (1), 'ologic' (1), 'tham' (1), 'amig' (1), 'nrlr' (1), 'avrendo pharma' (1)

## Full per-example detail

Every example's gold spans, both models' raw predictions, and the validated
pipeline's final fields are in `results.json` -- the same level of detail
`diagnose_real.py` prints to the terminal, kept here as structured data instead.
