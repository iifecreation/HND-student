# PROJECT SPECIFICATION

**Title:** Design and Implementation of a Voice-Controlled Edge Expert System for Diagnosing Printer Faults
**Working app name:** PrinterDoc (Dart package name `printer_doc`)
**Platform:** Android phone (Flutter, Dart). Fully offline at runtime.

---

## 1. Aim and objectives

**Aim:** Build an Android application in which a user describes a printer problem by voice and the app diagnoses the fault and speaks step-by-step fixes, with every part (speech recognition, reasoning, speech output) running on the phone itself, with no internet and no cloud service.

**Objectives**
1. Acquire and encode printer-fault knowledge as IF-THEN production rules with certainty factors.
2. Implement a forward-chaining inference engine with certainty-factor combination and an explanation facility.
3. Implement offline speech-to-text and text-to-speech on the phone (the "edge" node).
4. Implement a dialogue manager that asks follow-up questions by voice until it is confident.
5. Evaluate diagnostic accuracy, speech accuracy, response time and usability.
6. Demonstrate that the system works with the phone in airplane mode.

## 2. Scope

**In scope:** English; desktop laser and inkjet printers, dot matrix (impact) printers, thermal receipt (POS) printers and label/barcode printers, mostly brand-agnostic; 50 faults; Android only; voice plus text fallback; local history log; evaluation harness.

**Out of scope (do not build):** cloud APIs of any kind, internet access, machine-learning model training, iOS, full brand-specific error-code libraries (a few very common codes such as Canon 5B00 and B200 are included as synonyms), user accounts, ads, analytics.

**Stretch only if everything else is finished:** brand error-code lookup (HP, Canon, Epson), a "teach the system a new rule" screen.

## 3. Requirements

### Functional
| ID | Requirement |
|---|---|
| FR1 | Capture speech from the microphone and convert it to text on-device. |
| FR2 | Provide a text box and quick-reply chips as an equal fallback to voice. |
| FR3 | Extract symptoms from free text, handling synonyms, small recognition errors and negation ("no jam", "not blinking"). |
| FR4 | Run forward chaining over the rule base and compute a certainty factor (CF) per candidate fault. |
| FR5 | Choose and ask the most useful next yes/no/not-sure question when confidence is low. |
| FR6 | Present the diagnosis with confidence percentage and ranked alternatives. |
| FR7 | Speak the solution one step at a time; support voice commands next, repeat, back, stop, start over, why. |
| FR8 | Explain: "why was this asked" and "how was this concluded" (list the rules that fired). |
| FR9 | Safety override: if `overheating` is true, immediately speak the safety fault F20 and stop other questioning. |
| FR10 | If the user says the fix did not work, exclude that fault and continue with the next candidate. |
| FR11 | Log each session (time, symptoms, questions, diagnosis, CF, outcome, timings) to a local file. |
| FR12 | Knowledge-base browser screen listing faults and the rules that conclude them. |
| FR13 | Settings: speech rate, voice output on/off, auto-listen on/off, STT engine. |
| FR14 | Headless evaluation harness that runs `assets/kb/test_scenarios.json` and prints accuracy metrics. |

### Non-functional
| ID | Requirement |
|---|---|
| NFR1 | **Offline:** the release build must not declare the INTERNET permission. No network calls anywhere. |
| NFR2 | Inference over the full knowledge base completes in under 100 ms. |
| NFR3 | From end of utterance to first spoken response: under 3 seconds on a mid-range phone. |
| NFR4 | Release APK under 150 MB (the Vosk model is the bulk). |
| NFR5 | `minSdkVersion 24`. Runs on a phone with 3 GB RAM. |
| NFR6 | Explainable and deterministic: same inputs always give the same output. No black-box ML. |
| NFR7 | Large touch targets, high contrast, readable at arm's length (it is used while standing at a printer). |

## 4. Architecture

```
 USER (speech) -> [Voice input layer]  -> text
                  SpeechRecognizerService (abstract)
                    |- VoskSpeechRecognizer  (primary, bundled offline model)
                    |- DeviceSpeechRecognizer (fallback, speech_to_text onDevice)
 text -> [NLU layer]          TextNormalizer, SymptomExtractor, CommandParser
      -> [Dialogue manager]   state machine, QuestionSelector
      -> [Expert system core] KnowledgeBase (JSON) + WorkingMemory + InferenceEngine + Explanation
      -> [Voice output layer] TtsService (flutter_tts, offline system voice)
 UI (Flutter) observes the dialogue manager through a ViewModel (provider).
```

**Edge justification (for the report):** speech recognition, symptom extraction, reasoning and speech synthesis all execute on the handset. Raw audio never leaves the phone. There is no network dependency, so latency is bounded by local compute only and the app works in airplane mode.

**Hard rule:** the folders `knowledge/`, `engine/`, `nlu/` and `dialogue/` are **pure Dart with no Flutter imports**, so they can be unit-tested without a device.

### Folder structure
```
lib/
  main.dart
  app/            theme.dart, routes.dart, service_locator.dart
  knowledge/      models: symptom.dart fault.dart rule.dart
                  kb_loader.dart kb_validator.dart
  engine/         working_memory.dart inference_engine.dart certainty.dart explanation.dart
  nlu/            text_normalizer.dart stemmer.dart levenshtein.dart
                  symptom_extractor.dart command_parser.dart
  dialogue/       dialogue_state.dart dialogue_manager.dart question_selector.dart
  voice/          speech_recognizer_service.dart vosk_speech_recognizer.dart
                  device_speech_recognizer.dart tts_service.dart permissions.dart
  data/           session_logger.dart settings_repository.dart
  ui/             screens/ widgets/ viewmodels/
test/             unit tests + scenario test
assets/kb/        symptoms.json faults.json rules.json test_scenarios.json
assets/models/    vosk-model-small-en-us-0.15.zip   (added manually by the student)
```

## 5. Technology stack (verified against pub.dev, 2026)

| Purpose | Package | Notes |
|---|---|---|
| Offline STT (primary) | `vosk_flutter` ^0.3.48 | Offline Vosk toolkit. Android native binaries are included. Load the model with `ModelLoader().loadFromAssets('assets/models/vosk-model-small-en-us-0.15.zip')`. Needs `RECORD_AUDIO` permission and ProGuard keep rules for JNA (see section 10). |
| Offline STT (alternates if build fails) | `vosk_flutter_service`, then `vosk_flutter_fixed` | Maintained forks with the same API. Try these in order if `vosk_flutter` will not build. |
| Offline STT (fallback) | `speech_to_text` | Use `onDevice: true`. Some Android phones need the offline language pack installed in system settings first. |
| Text to speech | `flutter_tts` | Uses the phone's built-in engine; works offline if voice data is installed. |
| Microphone permission | `permission_handler` | |
| State management | `provider` | Keep simple. |
| Local files | `path_provider`, `shared_preferences` | Log file and settings. |
| Tests | `flutter_test` | No other test packages. |

**Do not add any package not in this table without asking the student first.** No ML packages. Write Levenshtein, stemming and the rule engine by hand so the student can explain every line in the viva.

**Optional comparison for the report:** `whisper_wrapper` and `whisper_edge` (on-device Whisper via whisper.cpp) exist on pub.dev and are more accurate but need a larger model (around 60 MB for a quantised base model) and more CPU. Mention in the literature review; do not implement unless Vosk accuracy proves unusable.

## 6. Knowledge representation

All knowledge is **data in JSON, not hard-coded in Dart.** Files are already provided in `assets/kb/`.

**symptoms.json**
```json
{"id":"paper_jam","label":"Paper jam","category":"paper",
 "synonyms":["paper jam","jammed","paper stuck"],
 "question":"Is paper stuck or jammed in the printer?",
 "excludes":["..."]}
```
`category` is one of: printer_type, paper, quality, connectivity, hardware, context. Symptoms in `printer_type` (laser, inkjet, dot matrix, thermal, label) are what the question selector asks about early; a new printer type can be added in JSON alone. `excludes` lists mutually exclusive symptoms (asserting `type_laser` as true sets the other printer types to false).

**faults.json**
```json
{"id":"F01","name":"...","category":"paper","severity":"low|medium|high|critical",
 "technician":false,"summary":"...","steps":["...","..."]}
```

**rules.json**
```json
{"id":"R01","all":["paper_jam","tray_overfilled"],"none":[],"any":[],
 "then":"F01","cf":0.80,"why":"...","safety":false}
```
A rule is **satisfied** when every symptom in `all` is TRUE, at least one in `any` is TRUE (if `any` is present), and no symptom in `none` is TRUE. `why` is the human-readable explanation spoken and shown by the explanation facility.

**Working memory** stores each symptom as one of: `TRUE`, `FALSE`, `UNKNOWN` (default), plus an evidence certainty: 1.0 for a firm yes, 0.5 for "not sure" (stored as TRUE with 0.5), 1.0 for FALSE.

## 7. Inference engine

**Strategy: forward chaining (data-driven).** The user supplies symptoms; the engine derives faults.

```
function infer(workingMemory, rules, excludedFaults):
    candidates = {}                       # faultId -> CF
    fired = []                            # for the explanation facility
    for rule in rules:
        if rule.then in excludedFaults: continue
        if not satisfied(rule, workingMemory): continue
        evidenceCf = min(certainty of each TRUE symptom in rule.all/any used)
        ruleCf = rule.cf * evidenceCf
        old = candidates.get(rule.then, 0)
        candidates[rule.then] = old + ruleCf * (1 - old)    # MYCIN-style combination
        fired.add(rule, ruleCf)
    return sorted(candidates by CF desc), fired
```

Implement `certainty.dart` with `combine(cf1, cf2) = cf1 + cf2 * (1 - cf1)`; unit test it.

**Conclusion criteria:** conclude when top CF >= 0.75 **and** (top CF - second CF) >= 0.15, or when 6 follow-up questions have been asked, or when no unasked useful question remains. In the last two cases present the ranked top 3 and say the system is less certain. If `safety` rule F20 fires, conclude immediately.

**Explanation facility:** `why(question)` returns the candidate faults the question would help distinguish. `how(fault)` returns the fired rules (id, `why` text, contribution) for that fault.

## 8. Natural-language understanding (symptom extraction)

Lightweight and rule-based. No ML.

1. **Normalise:** lowercase, remove apostrophes ("won't" becomes "wont"), replace other punctuation with spaces, collapse spaces.
2. **Light stemmer:** strip suffixes `ing`, `ed`, `es`, `s`, `ly`; if the result ends in a doubled consonant, drop one (jamming becomes jam); minimum stem length 3. Apply the same stemmer to the synonym phrases at load time.
3. **Phrase matching:** a symptom matches when any of its stemmed synonym phrases appears as a consecutive token sequence in the utterance. Prefer the longest phrase; do not double-count overlapping matches.
4. **Fuzzy matching:** allow Levenshtein distance 1 per token for tokens of 5 or more characters, to tolerate speech recognition errors.
5. **Negation:** if a negator (`no`, `not`, `dont`, `doesnt`, `isnt`, `without`, `never`, `nothing`) appears within the 3 tokens before a matched phrase, set that symptom to FALSE instead of TRUE. Be careful that "cannot see anything inside" does not negate "paper jam" when "jam" was stated positively earlier; tests must cover this.
6. **Answer parsing** for yes/no questions: yes set (`yes yeah yep correct right sure true`), no set (`no nope nah not`), unsure set (`not sure maybe dont know unsure`). Check "unsure" before "no".
7. **Command parsing:** `next`, `repeat` / `say again`, `back` / `previous`, `stop`, `start over` / `restart`, `why`, `how sure`, `done` / `fixed` / `it worked`, `didnt work` / `still broken`.

## 9. Dialogue manager

**States:** `idle` -> `collecting` -> `questioning` -> `diagnosed` -> `guiding` -> `resolved` or `escalated`.

**Turn loop**
1. User utterance arrives (voice or text). In `collecting`, run the symptom extractor and write results to working memory.
2. If nothing was extracted, reply with a short help prompt listing example symptoms. After two failures, show category quick-pick chips (Paper, Print quality, Connection, Hardware).
3. Run inference. If conclusion criteria are met, go to `diagnosed`.
4. Otherwise `QuestionSelector` picks the next question: among symptoms still UNKNOWN that appear in rules of the top 5 candidate faults, choose the one that appears in the most such rules; break ties by highest sum of rule CFs. Ask `symptom.question`. If no printer type is known yet and any top candidate rule needs one, ask first about the printer type those rules mention most often.
5. In `diagnosed`, speak: fault name, confidence, one-sentence summary. Ask "Shall I walk you through the fix?"
6. In `guiding`, speak one step at a time; wait for `next`, `repeat`, `back` or `stop`. After the last step ask "Did that fix it?". Yes goes to `resolved`; no excludes the fault and returns to step 3 (FR10).
7. If the fault has `technician: true`, say so clearly in the diagnosis and after the steps.

**Half-duplex voice:** stop the microphone while text-to-speech is speaking, and restart listening only after speech completes. This prevents the app hearing itself. Default to push-to-talk (big mic button); auto-listen is a setting.

## 10. Voice layer details

- Abstract class `SpeechRecognizerService` with: `initialize()`, `startListening()`, `stopListening()`, `Stream<String> partialResults`, `Stream<String> finalResults`, `bool get isOffline`. UI and dialogue code depend only on this interface, so the engine can be swapped without touching anything else.
- **Vosk:** load the small English model zip from assets at startup (show a loading indicator; first extraction takes a few seconds, then cache the extracted folder). Sample rate 16000. Create the recognizer once and reuse it.
- **Android build requirements for Vosk:** `android/app/proguard-rules.pro` must contain `-keep class com.sun.jna.* { *; }` and `-keepclassmembers class * extends com.sun.jna.* { public *; }`. `AndroidManifest.xml` needs `<uses-permission android:name="android.permission.RECORD_AUDIO" />`. Set `minSdkVersion 24`.
- **TTS:** call `setSpeechRate` (default 0.45), `setLanguage('en-US')`, and enable awaiting speak completion. At startup check that an engine and voice are available; if not, show a clear banner telling the user to install offline voice data in Android Settings under Text-to-speech output.
- **Startup self-check** shown on an "Edge Status" card: model loaded (yes/no), microphone permission, TTS ready, INTERNET permission present (should read "No"), STT engine in use.
- **Accent testing:** the student will test with Nigerian-accented English. Make the Vosk model path configurable so a second small English model can be swapped in for comparison. Record word error rate per model in the evaluation.

## 11. UI screens (Material 3, light and dark)

1. **Home / Diagnose:** chat-style transcript (user bubbles, system bubbles), large circular mic button with listening pulse, partial-transcript line, text input row, yes / no / not sure chips that appear only when a question is pending, "Start over" button, small badge "Offline mode".
2. **Diagnosis result:** fault name, severity chip, confidence bar, summary, numbered steps (stepper or checklist) with a Speak button, "Why this?" expandable list of fired rules, ranked alternatives, technician warning when relevant.
3. **Knowledge Base:** searchable list of faults, tap to see its steps and the rules that conclude it.
4. **History:** past sessions from the log; tap to view.
5. **Settings & Edge Status:** speech rate, voice on/off, auto-listen, STT engine, and the self-check card with the latest timing figures (STT latency, inference ms).
6. **About:** project title, student name placeholder, supervisor placeholder, version, disclaimer: "Guidance only. Switch off and unplug the printer before opening it. For smoke or burning smell, stop and call a technician."

## 12. Testing and evaluation (feeds the dissertation results chapter)

**Unit tests (required):** normaliser; stemmer; Levenshtein; symptom extractor (synonyms, fuzzy, negation); command parser; certainty combination; inference engine (single rule, multi-rule CF combination, `none` and `any` conditions, `excludes`); question selector; dialogue manager state transitions; KB validator (no dangling ids, no duplicate ids, CF within 0 to 1).

**Scenario test:** `test/scenario_test.dart` loads `assets/kb/test_scenarios.json`. For each scenario: feed `utterance` into the dialogue manager; answer each question yes if the symptom is in `truth`, otherwise no; record the final top fault, number of questions asked and time. **Print a table and the metrics:** Top-1 accuracy, Top-3 accuracy, average questions per diagnosis, average inference time.
Rules for this test: the 20 provided scenarios must stay unchanged. **Never edit `expected` or `truth` to make a test pass.** If a scenario fails, fix synonyms, extraction or rules, and report what was changed. Extend the file to at least 40 scenarios, including negation, multi-symptom, ambiguous and noisy-speech phrasings, each with a hand-verified expected fault.

**Manual evaluation (the student performs these, the app only has to support them):**
- Speech accuracy: 30 standard phrases x at least 3 speakers; compute word error rate.
- Response time: use the on-screen timing figures; report mean and worst case.
- Usability: 10 users complete 3 tasks, then fill in the System Usability Scale questionnaire.
- Offline proof: airplane mode demo, plus show `aapt dump permissions app-release.apk` has no INTERNET entry.
- Resource use: APK size and peak RAM (Android Studio profiler).

## 13. Knowledge acquisition and validation (for the report)

The supplied knowledge base was compiled from general printer troubleshooting practice for laser and inkjet printers; faults F29 to F50 were added from manufacturer documentation listed in `docs/KB_SOURCES.md`. **It must be validated before submission:** (1) cross-check each fault against manufacturer support pages and manuals (HP, Canon, Epson, Brother) and cite them; (2) have a qualified printer technician review the rules and adjust CF values; (3) record the review in the report as the knowledge-validation step. The app must make adding or editing rules easy: change JSON, no Dart changes.

## 14. Risks and fallbacks

| Risk | Fallback |
|---|---|
| `vosk_flutter` fails to build with the current Flutter or Gradle version | Try `vosk_flutter_service`, then `vosk_flutter_fixed`; if all fail, use `DeviceSpeechRecognizer` (`speech_to_text` with `onDevice: true`). The interface makes this a small change. |
| Vosk small model misrecognises accented speech | Test a second small English model; widen fuzzy matching; add more synonyms; keep text and chips as full alternatives. |
| TTS voice data not installed on the phone | Startup banner with instructions; the app still shows all text. |
| Large model slows first launch | Extract once and cache; show progress. |
| Demo room is noisy | Chips and text input are first-class; practise the demo with them. |

## 15. Deliverables

1. Working Flutter app, release APK built and tested on a real phone.
2. Passing unit tests and a printed scenario-test evaluation table.
3. `README.md` (setup, build, run, test), `docs/ARCHITECTURE.md` with Mermaid diagrams (system architecture, dialogue state machine, inference flow, class diagram), `docs/USER_GUIDE.md`, `docs/EVALUATION.md` (template tables for the manual evaluations).
4. Every Dart file has a header comment explaining its purpose in plain English, and non-obvious logic is commented, so the student can explain it in the viva.
