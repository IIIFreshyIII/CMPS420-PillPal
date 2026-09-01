# Medication Tracking App — Project Spec

**Project type:** Phase 1 academic project (mobile app)
**Core idea:** User photographs a prescription label. The app pulls out the important info (drug name, dosage, frequency, fill date, days supply, refill date) and turns it into a tracked medication profile with reminders.

**Guiding principles (these drive every decision below):**
- Avoid hallucination — don't let AI guess at things that matter for someone's health
- Privacy first — keep data on the device whenever possible
- Local-first — no unnecessary cloud processing
- Clear boundaries — the app assists, it doesn't make medical decisions

---

## 1. Core Pipeline (Photo → Data)

1. User takes a photo using a guided on-screen frame (helps line up the label correctly)
2. Photo goes through **on-device OCR** (photo → text), then a **NER model** (Named Entity Recognition — a model that pulls out specific pieces of info like "drug name" or "dosage" from text, rather than a general-purpose AI that writes/guesses text). This is *not* a generative LLM, specifically to avoid made-up info. The NER model is a small transformer distilled from Med7 and run on-device via ONNX (see `distill/DISTILLATION.md`); dates and days-supply come from plain regex, not the model.
3. **Every extraction requires human confirmation** — no matter how confident the model is, the user checks and confirms the fields before anything is saved. No confidence-based shortcuts.
4. Once confirmed, the photo is **deleted immediately**. If the user doesn't confirm right away, the photo auto-deletes after a short period of inactivity.
5. Refill date is **not** predicted by AI — it's basic math: `fill date + days supply = refill date`. Anything that can be calculated with plain logic should be, not inferred by a model.

## 2. Security & Privacy

- **Local-first architecture** — the core pipeline (photo → extraction → confirmation) runs entirely on-device. No cloud processing required for core functionality.
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
- **On-device extraction:** ML Kit for OCR; a small transformer (DistilBERT →
  MobileBERT for size) fine-tuned on synthetic labels and distilled from Med7,
  run via ONNX Runtime. Med7 itself can't run on a phone (spaCy has no mobile
  export), so it serves as the reference we train against and measure against.
- **Encrypted local database:** SQLCipher (encrypted SQLite) via the `drift`
  package; encryption key in the platform keystore.

---

## Explicitly Out of Scope for Phase 1 (MVP)

- **On-device chat/query feature** — letting users "ask" the app questions about their own stored medication data using an on-device LLM. This is a real idea, just deliberately parked for Phase 2 so the MVP doesn't grow out of control.

---

## Remaining Work

- User interviews (not yet started)
- Real-label evaluation set: ~30–50 photographed prescription labels, OCR'd and
  hand-corrected, for measuring the on-device model (doubles as user-testing data)
- Technical documentation on the NER model — in progress, `distill/DISTILLATION.md`
- Build out the app past the confirm-and-save loop: camera, OCR, real extractor,
  encrypted storage, reminders
