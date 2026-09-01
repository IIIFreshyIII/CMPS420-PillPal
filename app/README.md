# PillPal — the app

Flutter app for the Med-Tracker Phase 1 project. See `../med-tracker-spec.md`.

## Status

First runnable slice works and is tested (`flutter test` = 3 pass, `flutter
analyze` clean): **the confirm-and-save loop, with stub data.**

```
Med list → [＋ Add from label] → Capture (stub) → Confirm every field → saved → list
                                                                          └ tap a med → Detail (view / delete)
```

No camera, OCR, model, database, or reminders yet — those wire in behind the
interfaces already here (`Extractor`, `MedStore`). Platforms: `android/`, `ios/`,
`web/` are committed. `linux/macos/windows` were removed (not targets).

## Setup

A fresh clone already has the platform folders — you just need the SDK + deps.

1. **Flutter SDK**
   ```bash
   sudo snap install flutter --classic     # easiest on Ubuntu
   flutter --version
   ```

2. **Deps**
   ```bash
   cd app
   flutter pub get
   flutter test          # 3 tests, should pass
   flutter analyze       # should be clean
   ```

3. **To build/run on Android** you also need the Android SDK — install Android
   Studio (bundles it + emulator; `flutter doctor` finds it) or the cmdline-tools,
   then `flutter doctor --android-licenses`. iOS builds need a Mac.

## Running it

- **On a phone:** `flutter run` with an Android device (USB debugging) plugged in.
- **Headless / quick look:** `flutter run -d web-server --web-port 8080`, then open
  `http://<host>:8080` in a browser. Good for the server or a laptop without an
  emulator.

## Layout

| path | what |
|------|------|
| `lib/main.dart` | app entry, theme |
| `lib/models/medication.dart` | the confirmed medication; `refillDate` = arithmetic |
| `lib/services/extractor.dart` | `Extractor` interface + `StubExtractor`; real OCR+NER swaps in here |
| `lib/services/med_store.dart` | in-memory list; encrypted DB swaps in here |
| `lib/util/format.dart` | date formatting |
| `lib/screens/` | list · capture (stub) · **confirm** · detail |
| `test/flow_test.dart` | refill math + the capture→confirm→save flow |

## Next

- Real camera + guided frame (`camera` package)
- On-device OCR (`google_mlkit_text_recognition`) → real text into the extractor
- Swap `StubExtractor` for a real one: regex for dates/supply now, the distilled
  ONNX model (from `../distill/`) when it's trained
- Encrypted local storage (`drift` + `sqlcipher_flutter_libs`)
- Reminders (`flutter_local_notifications`) + missed-dose logic
- Photo auto-delete after confirm / on idle
- App lock (`local_auth`)
