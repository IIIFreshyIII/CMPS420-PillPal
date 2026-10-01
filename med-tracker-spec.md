# Medication Tracking App — Project Spec

**Project type:** Phase 1 academic project (mobile app)
**Core idea:** User photographs a prescription label. The app pulls out the important info (drug name, dosage, frequency, fill date, days supply, refill date) and turns it into a tracked medication profile with reminders.

**Guiding principles (these drive every decision below):**
- Avoid hallucination — don't let AI guess at things that matter for someone's health
- Privacy first — keep data on the device whenever possible
- Local-first — no unnecessary cloud processing
- Clear boundaries — the app assists, it doesn't make medical decisions

---

## 1. Core Pipeline (Scan → Data)

1. **User scans the label — no photo is ever taken or saved.** The camera view runs live, on-device OCR continuously on the video frames while the user pans it over the label (the same interaction pattern as a barcode/QR scanner). This replaces an earlier "take a photo, review a guided frame" design: scanning is far more forgiving of a bad angle or a curved bottle than one static shot has to be, and it's a stronger privacy story — there's no photo to delete because none is ever written to disk, not even briefly.
2. As text accumulates from the live OCR stream, it goes through a **NER model** (Named Entity Recognition — a model that pulls out specific pieces of info like "drug name" or "dosage" from text, rather than a general-purpose AI that writes/guesses text). This is *not* a generative LLM, specifically to avoid made-up info. The NER model is a small transformer distilled from Med7 and run on-device via ONNX (see `distill/DISTILLATION.md`); dates and days-supply come from plain regex, not the model.
3. The scan ends when the app has a reasonable set of fields (or the user taps "done" manually) — exact heuristic is a Phase 2 design detail, not a Phase 1 concern.
4. **Every extraction requires human confirmation** — no matter how confident the model is, the user checks and confirms the fields before anything is saved. No confidence-based shortcuts.
5. Camera frames only ever exist in memory during the live scan; nothing is written to disk before or after confirmation. (This supersedes the earlier "photo deleted immediately after confirmation" language — there's no photo in the first place now.)
6. Refill date is **not** predicted by AI — it's basic math: `fill date + days supply = refill date`. Anything that can be calculated with plain logic should be, not inferred by a model.

## 2. Security & Privacy

- **Local-first architecture** — the core pipeline (scan → extraction → confirmation) runs entirely on-device. No cloud processing required for core functionality.
- **Hardware-backed encryption** — uses the device's built-in secure storage (Secure Enclave on iOS, Android Keystore on Android)
- **App lock** — biometric (fingerprint/face) + PIN fallback, with auto-lock after inactivity
- **Cloud backup is opt-in only**, and if used, it's **zero-knowledge encrypted** (meaning even the backup provider can't read the data — only the user's device can decrypt it)

## 3. Notifications & Reminders

- Users can set reminder times **per day of the week** (not just one fixed daily time)
- Lock-screen notification text stays generic (doesn't reveal medication names/details for privacy)
- App logs missed or late doses and can proactively alert the user
- **3 consecutive missed doses** triggers a supportive check-in (not punitive, just a gentle nudge)
- Refill reminders default to a **two-stage warning**: 7 days before running out, and again on the day it runs out. Fully user-configurable.

## 4. Family / Shared Use

- **Option A**: Multiple people's medication profiles can live under one shared device/account (like a family member managing profiles for a parent and a child)
- Planned (not yet built): a way to **migrate a profile to its own independent install** later, using a local encrypted transfer (QR code scan or the phone's built-in share feature) — no cloud round-trip needed for the transfer itself

## 5. Tech Stack (Decided)

- **Cross-platform: Flutter** (one Dart codebase for iOS + Android). Android is
  the day-to-day target; a team Mac handles the iOS builds.
- **On-device extraction:** ML Kit for OCR; DistilBERT, fine-tuned on synthetic
  labels and distilled from Med7, quantized to int8 ONNX (~67 MB), run via ONNX
  Runtime. MobileBERT was tried for its smaller size but rejected — it collapsed
  under quantization (F1 ≈ 0.03) while DistilBERT held (0.583, then 0.686 with
  the RxNorm validation layer). Med7 itself can't run on a phone (spaCy has no
  mobile export), so it serves as the reference we train against and measure
  against — it scores 0.477 on the same real photos.
- **Encrypted local database:** SQLCipher (encrypted SQLite) via the `drift`
  package; encryption key in the platform keystore.

---

## Explicitly Out of Scope for Phase 1 (MVP)

- **On-device chat/query feature** — letting users "ask" the app questions about their own stored medication data using an on-device LLM. This is a real idea, just deliberately parked for Phase 2 so the MVP doesn't grow out of control.

---

## Remaining Work

- **User interviews — 0 of the target 6 conducted.** Current gap; see
  `USER_RESEARCH.md` for the interview script and working (unvalidated) personas.
- Real-label evaluation set: **done** — 29 photographed prescription labels,
  OCR'd and hand-corrected. Shipped model scores 0.686 F1 on it (vs Med7's 0.477).
  Growing it toward 40–50 for a tighter number is optional follow-up, not a blocker.
- Technical documentation on the NER model — **done**, `distill/DISTILLATION.md`.
- Build out the app past the confirm-and-save loop: camera, OCR, the real
  on-device extractor (`OnnxExtractor` — Python reference exists in
  `distill/infer.py`, Dart port not yet built), encrypted storage, reminders.
