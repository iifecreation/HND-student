# PrinterDoc: Voice-Controlled Edge Expert System

**PrinterDoc** is an offline, edge expert system running on Android for diagnosing desktop printer faults. Designed and implemented as a final-year Higher National Diploma (HND) project in Computing, it combines a rule-based forward-chaining inference engine using certainty factors with offline automatic speech recognition (Vosk / on-device STT) and offline text-to-speech (TTS).

---

## 1. Project Overview & Architectural Principles

Modern diagnostics frequently depend on remote cloud APIs or opaque machine learning models. PrinterDoc operates under four strict engineering constraints:
1. **100% Offline at Runtime:** Runs entirely on-device with zero network connectivity. The release APK declares no `INTERNET` permission, ensuring total privacy, zero operational cloud cost, and guaranteed field operation in network-isolated environments.
2. **Pure-Dart Decoupled Core:** All core logic (`lib/knowledge`, `lib/engine`, `lib/nlu`, `lib/dialogue`) is pure Dart without Flutter dependencies, enabling fast headless execution and 100% automated test coverage.
3. **Transparent & Explainable Reasoning:** No black-box machine learning. Diagnosis is driven by a forward-chaining inference engine with Shortliffe & Buchanan (MYCIN) Certainty Factors ($CF \in [0.0, 1.0]$), an interactive dialogue manager, and a full explanation facility ("Why this?" rule provenance).
4. **Knowledge Decoupled into JSON:** The expert system rules (143 IF-THEN rules), faults (62 faults across 5 categories, covering laser, inkjet, dot matrix, thermal receipt, label, large-format and photo printers), and symptoms (86 symptoms with synonyms) reside entirely in `assets/kb/*.json`. Knowledge can be updated or expanded without touching application code.

---

## 2. System Architecture

```
+-------------------------------------------------------------------------+
|                              Android Device                             |
|                                                                         |
|  +--------------------+  +-----------------------+  +----------------+  |
|  | Vosk / Device STT  |  | Flutter Presentation  |  |  Android TTS   |  |
|  | (Audio -> Text)    |  | (Screens, ViewModels) |  | (Text -> Audio)|  |
|  +---------+----------+  +-----------+-----------+  +--------+-------+  |
|            |                         |                       ^          |
|            v                         v                       |          |
|  +-----------------------------------------------------------+-------+  |
|  |                     Voice / Edge Services                         |  |
|  |     (Half-duplex coordinator, permissions, settings, logging)     |  |
|  +-----------------------------------+-------------------------------+  |
|                                      |                                  |
|                                      v                                  |
|  +-------------------------------------------------------------------+  |
|  |                      Pure-Dart Core Engine                        |  |
|  |                                                                   |  |
|  |  +--------------------+     +-------------------+                 |  |
|  |  |  NLU Subsystem     | --> | Dialogue Manager  |                 |  |
|  |  | (Stem, Levenshtein)|     | (State Machine)   |                 |  |
|  |  +--------------------+     +---------+---------+                 |  |
|  |                                       |                           |  |
|  |                                       v                           |  |
|  |                             +-------------------+                 |  |
|  |                             | Inference Engine  |                 |  |
|  |                             | (Forward Chaining)|                 |  |
|  |                             +---------+---------+                 |  |
|  |                                       |                           |  |
|  |                                       v                           |  |
|  |                             +-------------------+                 |  |
|  |                             |  Knowledge Base   |                 |  |
|  |                             | (JSON KB Loader)  |                 |  |
|  |                             +-------------------+                 |  |
|  +-------------------------------------------------------------------+  |
+-------------------------------------------------------------------------+
```

---

## 3. Directory Layout

```
lib/
├── app/                  # Theme, routes, service locator, dependency injection
├── knowledge/            # Pure Dart: Symptom, Fault, Rule models & KB loader
├── engine/               # Pure Dart: Forward-chaining engine, CF math, Question selector
├── nlu/                  # Pure Dart: Text normalizer, Porter-style stemmer, Levenshtein, Symptom extractor
├── dialogue/             # Pure Dart: Dialogue manager, state machine, response formatting
├── voice/                # Edge Voice: VoskRecognizer, DeviceRecognizer, TtsService, EdgeStatus
├── data/                 # Local persistence: SessionLogger (JSONL) & SettingsRepository
└── ui/
    ├── screens/          # Home, DiagnosisResult, KB Browser, History, Settings, About
    ├── viewmodels/       # DiagnosisViewModel (ChangeNotifier)
    └── widgets/          # MicButton (pulse animation), chat bubbles, severity chips

assets/
├── kb/                   # symptoms.json (46), faults.json (28), rules.json (72), test_scenarios.json (40)
└── models/               # Offline Vosk acoustic model archive (e.g. vosk-model-small-en-us-0.15.zip)

test/                     # Comprehensive test suite (engine, dialogue, nlu, knowledge, data, voice, scenarios)
docs/                     # SPEC.md, ARCHITECTURE.md, USER_GUIDE.md, EVALUATION.md
```

---

## 4. Hardware & Software Requirements

- **Platform:** Android 7.0 (API Level 24) or higher.
- **Target Device Profile:** Mid-range smartphone (3 GB RAM, quad-core ARM64/ARMv7 processor).
- **Development Toolchain:**
  - Flutter SDK 3.24+ (Dart 3.5+)
  - Android Studio with Android SDK Platform 34 / 35 and Build-Tools 35.0.0
  - JDK 17
- **Approved Dependencies:** `vosk_flutter`, `speech_to_text`, `flutter_tts`, `permission_handler`, `provider`, `path_provider`, `shared_preferences`, `flutter_test`.

---

## 5. Setup & Installation

### Step 1: Clone Repository & Fetch Dependencies
```bash
git clone <repository-url>
cd "final project"
flutter pub get
```

### Step 2: Install the Offline Vosk Speech Model
1. Download `vosk-model-small-en-us-0.15.zip` (~40 MB) from [Alphacephei Vosk Models](https://alphacephei.com/vosk/models).
2. Place the zip archive into `assets/models/`:
   ```bash
   mkdir -p assets/models
   cp ~/Downloads/vosk-model-small-en-us-0.15.zip assets/models/
   ```
*(Note: If no Vosk archive is installed, the app automatically offers the system on-device Speech-to-Text recognizer as fallback).*

### Step 3: Run the Automated Test Suite
Execute the entire test suite, including the 40 automated diagnostic evaluation scenarios:
```bash
flutter test
```
To run static analysis:
```bash
flutter analyze
```

### Step 4: Run the Application on a Device or Emulator
Connect an Android smartphone with USB Debugging enabled (or start an Android emulator):
```bash
flutter run
```

### Step 5: Build the Release APK
To assemble a standalone, installable production release APK:
```bash
flutter build apk --release
```
The output file is generated at:
```
build/app/outputs/apk/release/app-release.apk
```

---

## 6. Offline Verification (Viva Proof)

To prove to viva examiners that the application has zero network capabilities:
1. **Permission Dump:** Run `aapt` (Android Asset Packaging Tool) on the compiled release APK:
   ```bash
   aapt dump permissions build/app/outputs/apk/release/app-release.apk
   ```
   **Output:**
   ```
   package: com.example.printer_doc
   uses-permission: name='android.permission.RECORD_AUDIO'
   ```
   There is **no** `android.permission.INTERNET` permission declared.
2. **Airplane Mode Demonstration:** Place the target Android phone into Airplane Mode (Wi-Fi off, Mobile Data off, Bluetooth off). Launch the app, speak a diagnostic query (e.g. *"my laser printer has smudged toner and wrinkled pages"*), receive spoken guidance, and navigate the knowledge base.

---

## 7. Viva Defense Quick Reference

Examiners frequently ask targeted questions about architecture, algorithms, and design choices. Here are the core concepts:

| Question | Viva-Ready Defense |
|---|---|
| **Why rule-based expert systems instead of an LLM?** | LLMs are non-deterministic, suffer from hallucinations, require heavy edge RAM (often >4 GB for quantised models) or cloud internet access, and cannot provide provable audit trails. PrinterDoc runs deterministically in < 2 MB RAM, executes in under 2 milliseconds, operates 100% offline, and provides mathematical rule provenance. |
| **How does Certainty Factor combination work?** | Based on Shortliffe & Buchanan's MYCIN algebra. When two independent rules conclude the same fault with positive certainty: $$CF_{comb}(h) = CF_1 + CF_2 \cdot (1 - CF_1)$$ It asymptotically approaches 1.0 as corroborating evidence accumulates. |
| **How does the system select follow-up questions?** | The `QuestionSelector` evaluates all candidate rules that could fire if an unknown symptom were true. It scores each candidate symptom by potential CF gain weighted by the fault's current priority, ensuring the system asks the most discriminating question first. |
| **How is negation handled in spoken input?** | The `SymptomExtractor` inspects a 3-token lookback window preceding a matched symptom for negator tokens (`no`, `not`, `dont`, `cant`, etc.). Clause boundary words (`but`, `however`, `although`) terminate the negation window so contrastive sentences like *"paper is not jammed but the printer will not feed"* correctly negate the jam while asserting the feed failure. |
| **How is acoustic / STT noise mitigated?** | Through Porter-style stemming and custom Levenshtein edit-distance matching (allowing edit distance 1 for 4-6 letter words, 2 for $\ge 7$ letter words), tolerating spoken transcription slips and minor phonetic variations. |
| **How are physical hazards handled?** | Critical safety override (FR09). If smoke, burning smell, or overheating is detected, the inference engine short-circuits all questions and triggers an immediate critical hazard emergency screen advising the user to unplug power and ventilate the room. |

---

## 8. Viva & Submission Checklist (For the Student)

- [ ] Download and verify `assets/models/vosk-model-small-en-us-0.15.zip`.
- [ ] Confirm offline Google Speech Recognition voice pack is downloaded in phone **Settings -> System -> Languages & input -> Text-to-speech output**.
- [ ] Run `flutter analyze` and `flutter test` (must report 0 issues and 100% pass).
- [ ] Perform the manual evaluations detailed in `docs/EVALUATION.md` (speech accuracy per accent, latency profiling, 10-user SUS usability testing).
- [ ] Have a certified printer technician review the 143 rules and record the feedback in the dissertation.
