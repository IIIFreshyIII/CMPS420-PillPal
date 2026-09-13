# PillPal — Writeup Brief

This document exists to brief an assistant (or a reader) who has no other context
on the project, for the purpose of drafting a class report. It's the narrative
version of what's scattered across `med-tracker-spec.md`, `distill/DISTILLATION.md`,
and the two READMEs — written as a story with the reasoning and numbers inline,
not as reference documentation.

**Course:** CMPS 420, Phase 1 (academic, one semester, small team).
**Deliverable:** an installable phone app.

---

## 1. The idea and the constraints

**PillPal** (working name "Med-Tracker"): a user photographs a prescription
label, the app extracts the fields (drug, strength, dose, form, route,
frequency, duration, fill date, days supply), the user reviews and confirms
every field, and it becomes a tracked medication with refill reminders.

Four guiding principles were set at the start and drove every technical
decision after:

1. **Avoid hallucination.** Don't let AI guess at things that matter for
   someone's health. Concretely: the extraction model must be a Named Entity
   Recognition (NER) model — it *labels spans of text that are already there*
   — never a generative LLM that could invent a dose that isn't on the label.
2. **Privacy first / local-first.** No cloud processing for the core pipeline.
   The photo is deleted immediately after the user confirms the fields.
3. **No confidence-based shortcuts.** Every field is human-confirmed before
   anything is saved, regardless of how confident the model is.
4. **The refill date is arithmetic, not predicted.** `fill_date + days_supply
   = refill_date`, computed with plain code. Anything computable by rule
   should be computed by rule, not inferred by a model.

These constraints matter for the report because they explain *why* several
"obvious" shortcuts were deliberately not taken (no ChatGPT-style extraction,
no cloud OCR API, no confidence-thresholded auto-fill).

Team lanes: **Model lane** (the NER pipeline — the bulk of this brief), **App
lane** (the Flutter app), **Research lane** (interviews, spec, writeups).

---

## 2. Why an off-the-shelf clinical NER model wasn't enough

The natural starting point for pulling structured fields out of clinical text
is **Med7** (`en_core_med7_lg`, a spaCy model), which recognizes exactly the
seven fields we need: DRUG, STRENGTH, DOSAGE, FORM, ROUTE, FREQUENCY,
DURATION. It's a real, published clinical NER model — not something we built.

Two problems surfaced immediately:

- **Med7 cannot run on a phone.** It's a spaCy model with no ONNX / mobile
  export path. spaCy models run in a Python process; there is no supported way
  to ship one inside an Android/iOS app. Since the spec requires the pipeline
  to run fully on-device, Med7 itself was disqualified as the shipped model —
  it could only ever be a *reference/yardstick*, run on a computer, to measure
  against.
- **Med7 is trained on clinical prose** (doctors' notes, discharge summaries),
  **not pharmacy label text.** Label text is short, ALL CAPS, abbreviation-
  heavy, and laid out in lines rather than sentences. Med7's accuracy on this
  style of text is measurably worse than on the prose it was trained for.

We also ran a small bake-off against two alternatives that *can* run
on-device in principle — `d4data/biomedical-ner-all` (too coarse a label
scheme — strength/dose/route/frequency all collapse into one or two buckets)
and GLiNER, a zero-shot model (better drug-name recall than Med7 on ALL-CAPS
text, but noisier and less separated). Neither beat Med7's underlying label
quality; both confirmed that no off-the-shelf model is a good fit for
pharmacy-label text specifically (they're all trained on clinical narrative).

**Conclusion:** build a small model of our own, but don't design it from
scratch — **distill Med7's knowledge into something small enough to ship.**

---

## 3. The distillation approach

"Distillation" here means: use a big/expensive model's knowledge to train a
small/cheap one that can actually be deployed. Concretely:

1. **Generate synthetic prescription labels programmatically** — a Python
   generator (`label_generator.py`) that assembles a label from a drug/salt/
   strength/form, a dosing instruction, a pharmacy header, and a footer, with
   randomized templates, casing, and ordering. Because *we* generate the text,
   we already know the exact correct answer for every field — no manual
   labelling needed, and no risk of copying Med7's mistakes (e.g. Med7 misses
   drug names in ALL CAPS; a hand-built generator doesn't need to replicate
   that bug).
2. **Fine-tune a small transformer** — **DistilBERT** (66M parameters) and
   **MobileBERT** (25M parameters), both distilled/compressed relatives of
   BERT already, general-purpose, pre-trained on English — on the synthetic
   labels as a token-classification (BIO-tagging) task: for every word-piece,
   predict one of 15 tags (`O`, plus `B-`/`I-` for each of the 7 entity
   types).
3. **Keep Med7 only as the yardstick** — every training run reports the small
   model's score *and* Med7's score on the same test data, so "did we actually
   improve on the thing we can't ship" is always visible.
4. **Export the winner to ONNX and quantize it** so it can run inside the
   Flutter app via ONNX Runtime.

What "training" means in plain terms, for the report: the base model already
knows English from pre-training; it does not know what a "drug name" is. For
each example, the model guesses a tag per word, the guess is compared to the
known-correct answer to get one number (the *loss*), and an optimizer nudges
the model's internal parameters slightly in the direction that would have
lowered that loss. Repeated over thousands of examples and a few passes
("epochs"), the loss falls and the tagging gets accurate. No parameter is ever
set or edited by hand.

---

## 4. The first trap: synthetic accuracy is not real accuracy

The first training run (2,000 synthetic examples, DistilBERT, random
train/test split) scored **F1 = 1.000** — a perfect score. This was correctly
flagged as a red flag, not a win: with only ~20 drugs and a handful of fixed
templates, a 66-million-parameter model can simply memorize the generator
rather than learn to read.

The fix attempted first was a **held-out vocabulary split**: partition the
drug list, pharmacy list, and phrasing list into a "train" pool and a
disjoint "test" pool, so the test set contains drugs and phrasings the model
never saw during training (`test_unseen`), alongside a `test_seen` set (same
vocab, fresh instances) as a sanity check. The gap between the two is a
*memorization check* — if the model does much worse on unseen vocabulary, it
memorized; if the gap is small, it generalized.

Result: **still saturated.** Even with 85 drugs split into disjoint pools and
several sentence-structure templates, `test_unseen` F1 sat at 0.997. A second
attempt — adding more structural variety to the generator specifically to try
to bring the synthetic score down to something "realistic" — also failed to
move the number in any meaningful way; it only changed Med7's synthetic score
(from ~0.86 down to ~0.79, since Med7 had never trained on any of it either).

**The lesson, stated plainly:** a 66M-parameter model can fit *any* procedural
generator, no matter how much vocabulary or structural variety is added,
given a few thousand examples. Synthetic test-set accuracy is **structurally
uninformative** about real-world performance once a model is large enough to
memorize the generator's patterns. It remains useful for two narrower things:
(a) a *relative* comparison between two training configurations on the same
fixed synthetic set (e.g. "does adding noise help"), and (b) a sanity check
that the pipeline works end-to-end. It is **not** evidence of real-world
accuracy, and continuing to tune the generator to chase a lower synthetic
score would have been a waste of effort. This reframed the whole project: the
critical path became **building a test set from real prescription-label
photos**, because that's the only number that means anything.

---

## 5. Building the real-label test set

Med7's score on synthetic label-format text (~0.79–0.80 F1) became the first
useful reference point once we accepted the synthetic *training* signal was
fine but the synthetic *test* signal was not. The plan was to collect 30–50
real label photos, OCR them, hand-correct the fields, and score everything
against that.

**OCR engine choice mattered a lot.** The first 10 photos (curved pill
bottles, held in hand, varied angle/blur) were run through **Tesseract**,
which produced near-total garbage on roughly half of them — its dominant
failure mode is *dropping whole lines/regions it can't segment*, not
misreading individual characters. Switching to **RapidOCR** (an ONNX-based
OCR engine, closer in behavior to what a phone's on-device OCR — ML Kit —
actually does: rotation/blur-tolerant, but prone to gluing adjacent words
together with no space) recovered most of the text on the same photos. This
became a permanent pipeline change: RapidOCR primary, Tesseract fallback.

**Annotation process:** each OCR'd photo produces a text block; a script
pre-annotates it with Med7's guesses as `[text](LABEL)` markup, which is then
hand-corrected — fixing wrong spans, and for badly garbled OCR, adding the
*true* value on a separate line (so later analysis can distinguish "OCR's
fault" from "the model's fault"). Patient names and addresses were replaced
with realistic fakes rather than deleted (deleting them would remove the
surrounding noise the model needs to learn to ignore); a pattern-based PII
scanner flags anything that still looks like an identifier before it's
committed. Only the finished, de-identified JSONL file is kept — the raw
photos never leave the local machine.

**Final real-label test set: 29 labels**, collected in two batches — 10 JPEGs
and 19 iPhone HEIC photos (the HEIC format needed an extra library to read).
Six distinct medications across two (fictionalized) patients and two
pharmacies: atomoxetine, venlafaxine (extended-release), gabapentin,
econazole (topical cream), metronidazole (topical cream), and doxycycline.
The topicals were valuable additions because they introduce percentage
strengths (`2%`) and non-oral routes ("apply to the affected area") that the
original generator didn't cover at all.

---

## 6. The second trap: the first real-world test was a loss

Once the real-label test set existed, the model trained purely on **clean**
synthetic data scored **F1 ≈ 0.43–0.45** on it — while Med7, run on the same
real photos, scored **F1 ≈ 0.477**. **The distilled model lost to the model
it was distilled from.** This was reported plainly rather than downplayed.

A diagnostic pass — printing, for every real photo, the gold answer next to
what the model actually predicted and what Med7 predicted — made the failure
mode legible:

- **DRUG precision was only ~0.14–0.22.** The model was tagging manufacturer
  names (`AUROBINDO`, `DR. REDDY'S LABORATORIES`), brand-name callouts
  ("Generic for NEURONTIN"), and outright OCR garbage as if they were drug
  names.
- **No concept of "this is noise, say nothing."** Every synthetic training
  example was fully populated with clean, correctly-labelled text; the model
  had never once been shown a line of junk and rewarded for predicting
  nothing there. Med7, by contrast, is conservative — it stayed silent on the
  same junk far more often, which is *why* it won despite otherwise weaker
  language understanding.
- **Span boundaries broke on glued OCR tokens.** Real OCR frequently drops
  the space between a drug name and its strength (`ATOMOXETINE25MGCAP`); the
  model would grab the whole glued blob as one DRUG span instead of just the
  drug portion, which counts as wrong under exact-span scoring.

---

## 7. The fix: calibrating synthetic noise against the real photos

Rather than guess at a fix, the corruption the generator applies to training
text was rebuilt to match what was actually observed, and then **calibrated
numerically** against the real photos — a genuinely useful methodological
step for the report:

- **Structural noise, not just character noise.** The generator now (a)
  deletes the space between adjacent fields to mimic OCR gluing, (b)
  truncates the tail of a line (modelling text that wraps off a curved
  bottle and is cut out of frame), and (c) still drops whole lines and swaps
  similar-looking characters (the original Tesseract-motivated noise).
- **Distractor text as unlabelled context.** The generator now interleaves
  manufacturer names, "Generic for {brand}" lines, boilerplate warnings, and
  NDC-style codes into the label — all deliberately left *unlabelled* (tag
  `O`), specifically to teach the model that this class of text should not be
  tagged DRUG.
- **Calibration.** The amount of corruption is controlled by one parameter.
  Rather than pick a value by feel, we measured **Med7's F1 on the synthetic
  set at increasing corruption levels** and compared it to **Med7's F1 on the
  real photos (0.477)**: a corruption level of 0 gave Med7 ~0.74 (too easy —
  matches the earlier clean-synthetic number), while a moderate level gave
  Med7 ~0.455 — almost exactly its real-photo score. That corruption level was
  then used for training, on the logic that if the synthetic data is exactly
  as hard for Med7 as the real photos are, it's probably close to the right
  difficulty for training our model too.

**Result after retraining:** real-label F1 rose from ~0.43–0.45 to **0.58**,
finally clearing Med7's 0.477. DRUG false-positives dropped sharply (the
distractor-text training specifically fixed the "tagged the manufacturer
name" failure mode).

---

## 8. Picking the model to ship: DistilBERT vs. MobileBERT

MobileBERT (25M parameters) is roughly a third the size of DistilBERT (66M)
and was tested as the phone-target model on the theory that smaller is
better for an app bundle. On the calibrated-noise training, the two were a
statistical tie on the real photos (MobileBERT 0.587 vs DistilBERT 0.579,
with the real test set small enough — 29 labels — that a few points either
way is noise).

The deciding factor turned out to be **quantization**, covered next.

---

## 9. Getting the model onto the phone: ONNX + quantization

PyTorch (what the model is trained in) cannot run inside a Flutter app. The
model has to be converted to **ONNX** — a portable neural-network file format
that a small runtime library (ONNX Runtime, with Android/iOS builds) can
execute — and then **quantized**, i.e. its internal numbers shrunk from
32-bit decimals to 8-bit whole numbers, for a roughly 4x smaller file and
faster inference on a phone's CPU (phone CPUs have dedicated fast instructions
for 8-bit integer math; they generally do *not* have a fast path for the
in-between 16-bit float format, so "half precision" saves file size but not
speed on-device — 8-bit quantization was the target from the start for that
reason).

The ONNX conversion itself was validated by re-scoring the converted model
on the real-label set and checking it matched the original PyTorch model
exactly — it did, for both candidates, and the converted model ran roughly
2x faster than the PyTorch version even just on a CPU.

**Quantization is where MobileBERT lost.** DistilBERT quantized to 8-bit
losslessly — its real-label F1 actually stayed the same (0.583 quantized vs
0.579 full-precision) at 67 MB. **MobileBERT collapsed to F1 ≈ 0.03** under
the same quantization procedure — its full-precision accuracy was fine
(0.587), but its architecture (a deliberately narrow "bottleneck" design
built for size, not for standard 8-bit quantization) did not survive naive
post-training quantization. Recovering MobileBERT would need
quantization-aware training — retraining the model to expect quantization
noise from the start — which is a substantially bigger undertaking and out
of scope for this project.

**Decision: ship DistilBERT, quantized, at 67 MB.** MobileBERT's smaller
*size* stopped mattering once it couldn't be shrunk further without breaking.
This is a good, citable, self-contained finding for the report: a smaller
model is not automatically the better choice for on-device deployment if it
doesn't survive the deployment step.

---

## 10. The last lift: model plus a controlled vocabulary

The model's remaining weak point after all of the above was still **DRUG
precision** — it still occasionally tagged a manufacturer name or a stray
piece of OCR garbage as a drug. Rather than try to solve this purely by
retraining, we added a validation layer *after* the model, which is standard
practice in clinical NLP systems generally (real systems like cTAKES and
MedEx pair a statistical model with a controlled medical vocabulary rather
than relying on the model alone):

- **DRUG spans** are checked against a list of ~10,500 real drug names,
  built from RxNorm (the U.S. National Library of Medicine's standard drug
  nomenclature; the specific subset used is freely redistributable and needs
  no special license). A recognized name is normalized to its canonical form
  and the span is tightened to just the drug name if OCR had glued something
  onto it (e.g. `ATOMOXETINE25MGCAP` → `atomoxetine`). An unrecognized span
  that looks like a manufacturer name or pure noise is dropped; anything else
  unrecognized is kept but flagged for the user to double-check — never
  silently deleted, since every field is human-confirmed before saving
  regardless.
- **FORM and ROUTE** are checked against small fixed lists (tablet, capsule,
  cream, …; by mouth, topically, …) and normalized the same way.
- **STRENGTH and DOSAGE** get a light sanity check (do they contain a number
  or number-word). **FREQUENCY and DURATION** are left as pure model output —
  too open-ended in real phrasing to usefully constrain with a fixed list.

**Result:** DRUG F1 rose from **0.44 to 0.75**; overall real-label F1 rose
from **0.583 to 0.686**. Compared against Med7's 0.477 on the same photos,
that is a **+0.21 F1 margin** — the final, reportable headline number.

---

## 11. Final results summary

| stage | real-label F1 | note |
|---|---:|---|
| Med7 (reference, off-the-shelf) | 0.477 | can't run on a phone at all |
| distilled model, clean synthetic training | 0.43–0.45 | *lost* to Med7 |
| distilled model, calibrated-noise training | 0.579–0.587 | beats Med7 |
| + int8 quantization (DistilBERT) | 0.583 | quantization was free (no accuracy loss) |
| + int8 quantization (MobileBERT) | 0.026 | architecture doesn't survive quantization — not shipped |
| **+ RxNorm / closed-set validation layer (shipped)** | **0.686** | **DRUG F1 0.44 → 0.75** |

Shipped artifact: `model.quant.onnx` (DistilBERT, int8, 67 MB) + a WordPiece
vocabulary file + a ~10,500-name drug list, bundled into the Flutter app.

Per-entity F1 on the shipped configuration: DOSAGE 0.85, FORM 0.81, DRUG 0.75,
ROUTE 0.62, STRENGTH 0.59, FREQUENCY 0.46 (no duration examples in the current
real test set).

---

## 12. Honest limitations (state these directly in the report)

- **n = 29 real labels** is a small evaluation set; treat any single-digit-
  point difference as noise. The synthetic-vs-real methodology (calibrating
  noise so Med7's synthetic score matches its real score) is the more
  defensible part of the evaluation story; the absolute real-label F1 should
  be reported with that caveat.
- **FREQUENCY remains the weakest field (F1 ≈ 0.46)** — it has no controlled
  vocabulary to fall back on, and real phrasing ("3 times a day for nerve
  pain") is harder to bound with fixed spans than the other fields.
  Additionally, a portion of the FREQUENCY gold-standard annotations
  themselves are partial (the OCR fused the phrase across a line break in a
  way that made a full annotation impossible), which biases this number
  pessimistically.
- **The Dart/Flutter side of the pipeline is not yet built.** The ONNX model
  and validation logic exist and are verified in Python; porting the
  tokenizer, the decoding logic, and the validation layer into Dart (so it
  runs inside the actual app) is the next concrete task, and a Python
  reference implementation exists specifically so the Dart port can be
  checked for correctness against it.
- **The app itself is at an early stage**: the confirm-and-save loop (camera
  → OCR → confirm every field → save → refill math) works end-to-end with a
  placeholder extractor; camera capture, on-device OCR, encrypted storage,
  and reminders are still to be built.
- User interviews (part of the semester plan) have not yet been conducted.

## 13. Suggested framing for a report's "contributions" or "findings" section

1. Demonstrated that a clinical NER model too large to deploy (Med7 / spaCy)
   can be distilled into a small transformer that runs entirely on-device and
   **outperforms the original model on the target domain** (real prescription
   photos vs. the clinical prose Med7 was trained on).
2. Identified and corrected a **synthetic-evaluation trap**: a sufficiently
   large model memorizes any fixed procedural generator regardless of
   vocabulary/structural variety added to it, making synthetic test accuracy
   structurally uninformative; only evaluation against real photographed
   labels was predictive.
3. Introduced a **noise-calibration methodology** — tuning synthetic training
   corruption until a known reference model's synthetic score matches its
   real-world score — as a principled way to make synthetic training data
   realistic without hand-tuning by feel.
4. Found that **quantization robustness, not raw parameter count, decided
   which model shipped** — a 25M-parameter model matched a 66M-parameter
   model in full precision but did not survive 8-bit quantization, while the
   larger model quantized losslessly.
5. Combined the trained model with a **controlled medical vocabulary**
   (RxNorm) as a post-processing validation layer, following established
   clinical-NLP system design, for a further material accuracy gain with no
   retraining required.
