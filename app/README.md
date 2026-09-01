# PillPal — the app

Flutter app for the Med-Tracker Phase 1 project. See `../med-tracker-spec.md`.

## Status

First runnable slice: **the confirm-and-save loop, with stub data.**

```
Med list → [＋ Add from label] → Capture (stub) → Confirm every field → saved → list
                                                                          └ tap a med → Detail (view / delete)
```

No camera, OCR, model, database, or reminders yet — those are wired in behind
the interfaces already here (`Extractor`, `MedStore`).

## First-time setup (Linux)

1. **Flutter SDK**
   ```bash
   sudo snap install flutter --classic     # easiest on Ubuntu
   # or: git clone https://github.com/flutter/flutter.git -b stable ~/flutter
   #     echo 'export PATH="$PATH:$HOME/flutter/bin"' >> ~/.bashrc
   flutter --version
   ```

2. **Android toolchain** — install Android Studio (bundles the SDK + emulator +
   device manager; `flutter doctor` finds it), or the command-line tools only:
   ```bash
   # cmdline-tools route:
   #   download from developer.android.com/studio#command-line-tools-only
   #   unzip to ~/Android/cmdline-tools/latest
   #   sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"
   flutter doctor --android-licenses
   ```

3. **Check**
   ```bash
   flutter doctor        # green checks for Flutter + Android toolchain
   ```

4. **Generate the platform folders** around this code (one time):
   ```bash
   cd "CMPS 420/app"
   flutter create --org com.cmps420.pillpal --project-name pillpal .
   flutter pub get
   ```
   This adds `android/`, `ios/`, etc. without touching `lib/`, `pubspec.yaml`,
   or `test/`.

5. **Run** — on a physical Android phone (USB debugging on) or an emulator:
   ```bash
   flutter devices
   flutter run
   ```

6. **Test**
   ```bash
   flutter test
   ```

Building for iPhone needs a Mac; Android builds anywhere. If nobody's on a Mac
yet, stay Android-only — the code doesn't change.

## Layout

| path | what |
|------|------|
| `lib/main.dart` | app entry, theme |
| `lib/models/medication.dart` | the confirmed medication; `refillDate` = arithmetic |
| `lib/services/extractor.dart` | `Extractor` interface + `StubExtractor`; real OCR+NER swaps in here |
| `lib/services/med_store.dart` | in-memory list; encrypted DB swaps in here |
| `lib/screens/` | list · capture (stub) · **confirm** · detail |
| `test/flow_test.dart` | refill math + the capture→confirm→save flow |

## Next

- Real camera + guided frame (`camera` package)
- On-device OCR (`google_mlkit_text_recognition`)
- Wire the distilled NER model (`onnxruntime`) into a real `Extractor`
- Encrypted local storage (`drift` + `sqlcipher_flutter_libs`)
- Reminders (`flutter_local_notifications`) + missed-dose logic
- Photo auto-delete after confirm / on idle
- App lock (`local_auth`)
