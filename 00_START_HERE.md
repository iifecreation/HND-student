# START HERE: how to build the project with Antigravity

This kit contains everything Antigravity needs. You do the setup once, then paste the prompts below one phase at a time.

## What is in this kit
| File | Purpose |
|---|---|
| `AGENTS.md` and `GEMINI.md` | Standing rules Antigravity reads automatically when you open the folder (identical copies, so either name works). |
| `docs/SPEC.md` | The full specification: requirements, architecture, algorithms, UI, tests. |
| `assets/kb/symptoms.json` | 46 symptoms with synonyms and follow-up questions. |
| `assets/kb/faults.json` | 28 faults with spoken fix steps. |
| `assets/kb/rules.json` | 72 IF-THEN rules with certainty factors. |
| `assets/kb/test_scenarios.json` | 20 evaluation scenarios with expected answers. |

## Part A: one-time setup (you do this by hand)

1. **Install the tools** (several GB, so use a good connection): Flutter SDK, Android Studio (it installs the Android SDK), and Antigravity. Run `flutter doctor` in a terminal and fix anything marked with a red cross.
2. **Create the project:**
   ```
   flutter create --org com.yourname --platforms android printer_doc
   ```
3. **Copy this kit into the `printer_doc` folder.** Merge the `assets/` and `docs/` folders and place `AGENTS.md`, `GEMINI.md` and `00_START_HERE.md` in the project root.
4. **Download the offline speech model** (about 40 MB) from https://alphacephei.com/vosk/models and choose `vosk-model-small-en-us-0.15.zip`. Put the zip, unextracted, in `printer_doc/assets/models/`.
5. **Prepare your phone:** Settings, About phone, tap Build number 7 times, then Developer options, switch on USB debugging. Plug it in and check that `flutter devices` lists it. Also install offline speech voice data: Settings, search "Text-to-speech output", open the engine's settings, and download English voice data.
6. **Open the `printer_doc` folder in Antigravity.** Set the agent to **Planning** mode for the phase prompts below. Use Fast mode only for small fixes. Choose a review setting that lets you read what the agent plans to run, so you learn what it does.
7. Run `git init` and make a first commit, so you can roll back any phase that goes wrong.

If Antigravity does not seem to pick up `AGENTS.md` or `GEMINI.md`, paste this at the start of your first prompt: "Read AGENTS.md and docs/SPEC.md completely before doing anything."

## Part B: the prompts (paste one at a time, check the result, then move on)

### Phase 0: project setup
```
Read AGENTS.md and docs/SPEC.md completely. Then do Phase 0 only:
1. Set up pubspec.yaml with the approved packages from AGENTS.md, and register assets/kb/ and assets/models/ as assets.
2. Set minSdkVersion 24. Add the RECORD_AUDIO permission to the main AndroidManifest.xml. Create android/app/proguard-rules.pro with the JNA keep rules from SPEC section 10 and make sure release builds use it.
3. Make sure the release manifest does NOT declare INTERNET. Note that Flutter adds it only in debug/profile manifests; confirm and tell me.
4. Create the empty folder structure from SPEC section 4 with a one-line header comment in each placeholder file.
5. Run flutter pub get and flutter analyze. If vosk_flutter fails to resolve or build, report the exact error and try the alternates in SPEC section 14 in order.
Do not write any app logic yet. Summarise what you did and commit.
```

### Phase 1: knowledge base layer
```
Phase 1 only. Implement lib/knowledge: Symptom, Fault and Rule models; KbLoader that reads the three JSON files from assets; and KbValidator that checks for duplicate ids, rules referencing unknown symptoms or faults, CF values outside 0 to 1, and rules with empty conditions. Keep the Dart pure (no Flutter imports) by having KbLoader accept the raw JSON strings, with a thin Flutter-side helper that reads the assets. Write unit tests, including one that loads the real files from assets/kb and asserts the validator reports no errors. Run flutter analyze and flutter test, then commit.
```

### Phase 2: inference engine
```
Phase 2 only. Implement lib/engine as specified in SPEC section 7: WorkingMemory with TRUE/FALSE/UNKNOWN plus evidence certainty and the "excludes" behaviour; certainty.dart with combine(); InferenceEngine with forward chaining, all/any/none conditions, excluded faults, the safety override, and the conclusion criteria; and the Explanation facility with why() and how(). Write unit tests for each behaviour. In particular write a test that loads the real KB, sets the facts from each scenario's truth list in assets/kb/test_scenarios.json, and checks the top fault equals expected. Run analyze and test, then commit.
```

### Phase 3: language understanding
```
Phase 3 only. Implement lib/nlu as specified in SPEC section 8: TextNormalizer, Stemmer, Levenshtein, SymptomExtractor (longest-phrase matching, fuzzy matching, negation, no double-counting), and CommandParser including yes/no/not-sure answer parsing. Build the stemmed synonym index from symptoms.json at load time. Write thorough unit tests, including these cases: "my printer keeps jamming", "it won't pick up paper", "there is no paper jam but the light is blinking" (paper_jam FALSE, error_light TRUE), and an utterance with a one-letter speech error. Run analyze and test, then commit.
```

### Phase 4: dialogue manager
```
Phase 4 only. Implement lib/dialogue per SPEC section 9: the state machine, QuestionSelector (most-informative-question heuristic), the turn loop, the "fix did not work, exclude that fault" path, and the guided-steps flow with next/repeat/back/stop. The dialogue manager must be pure Dart and return structured responses (what to say, what to display, which quick-reply chips to offer) rather than calling any plugin. Then write test/scenario_test.dart that runs every scenario in assets/kb/test_scenarios.json through the dialogue manager with a simulated user, and prints a results table plus Top-1 accuracy, Top-3 accuracy, average questions asked and average inference time. Do not modify expected or truth in the scenarios. Report any failures and fix them by improving synonyms, extraction or rules, telling me exactly what you changed. Commit.
```

### Phase 5: voice services
```
Phase 5 only. Implement lib/voice per SPEC section 10: the abstract SpeechRecognizerService, VoskSpeechRecognizer (load the model from assets, extract once and cache, 16000 Hz, partial and final result streams), DeviceSpeechRecognizer using speech_to_text with onDevice true, TtsService wrapping flutter_tts with awaitable completion and the speech-rate setting, and the permission helper. Add the startup self-check that reports model loaded, mic permission, TTS ready, INTERNET permission absent, and which engine is active. Make the STT engine selectable from settings. Keep everything behind interfaces. Run analyze, then build a debug APK and run it on my connected phone with a tiny temporary test screen that shows live transcription and speaks a sentence. Tell me exactly what I should say and see to confirm it works. Commit.
```

### Phase 6: user interface
```
Phase 6 only. Build the UI per SPEC section 11 with Material 3, light and dark themes, large touch targets and the "Offline mode" badge: Home/Diagnose chat screen (mic button with listening pulse, partial transcript, text input, yes/no/not-sure chips shown only when a question is pending, start over), the Diagnosis result screen (fault, severity, confidence bar, steps, Speak button, Why this? list of fired rules, ranked alternatives, technician warning), the Knowledge Base browser, History, Settings with the Edge Status card, and About. Wire it to the dialogue manager through a provider ViewModel. Half-duplex rule: stop listening while TTS speaks. Remove the temporary test screen. Run on my phone. Commit.
```

### Phase 7: logging, settings and polish
```
Phase 7 only. Implement SessionLogger (JSON-lines file with time, symptoms, questions asked, diagnosis, CF, outcome and timings: STT latency, inference ms, end-of-speech to first spoken response), the History screen backed by it, and SettingsRepository using shared_preferences. Show the latest timings in the Edge Status card. Add friendly empty states and error banners (no mic permission, model missing, TTS voice data missing, with instructions). Add an in-app "Export log" button that shares the log file. Run analyze and test, then commit.
```

### Phase 8: evaluation and release
```
Phase 8 only. 1) Extend assets/kb/test_scenarios.json to at least 40 scenarios by adding 20 new ones covering negation, multi-symptom, ambiguous and noisy-speech phrasings. Each new one needs a clearly correct expected fault; list your reasoning for each in a table so I can check it. Do not touch the first 20. 2) Re-run the scenario test and report the metrics. 3) Build a release APK with flutter build apk --release, then run aapt (or apkanalyzer) to print the permissions and prove INTERNET is absent. Report APK size. 4) Create docs/EVALUATION.md with ready-to-fill tables for speech word error rate (30 phrases x 3 speakers), response-time measurements, SUS usability scoring with the ten standard statements, and an offline airplane-mode test checklist. Commit.
```

### Phase 9: documentation for the dissertation
```
Phase 9 only. Write README.md (setup, build, run, test), docs/ARCHITECTURE.md with Mermaid diagrams (system architecture, dialogue state machine, inference flow, class diagram of the main classes), and docs/USER_GUIDE.md for a non-technical user. Explain every design decision in plain English, as if preparing me for questions in a viva: why forward chaining, why certainty factors, why the engine is separate from the UI, why Vosk, what "edge" means here. Commit.
```

## Part C: helper prompts

**If a build fails**
```
The build failed. Here is the full error: [paste it]. Diagnose the root cause, explain it in two sentences, fix it with the smallest change, and re-run. If it is a plugin incompatibility, follow SPEC section 14 fallbacks in order and tell me which one you chose.
```

**If speech recognition is poor**
```
Speech recognition is misreading my accent. Add a debug screen that shows raw partial and final transcripts and the symptoms extracted from them. Then list the 10 most likely misrecognitions for our symptom words, add the closest ones as synonyms in symptoms.json, and re-run the scenario test to confirm nothing regressed.
```

**If you want to understand something (use before your viva)**
```
Explain lib/engine/inference_engine.dart to me line by line as if I will be questioned on it. Then ask me five questions an examiner might ask about it.
```

## Part D: your own work (the app cannot do this for you)
1. **Validate the knowledge** with a printer technician and cite manufacturer manuals for each fault. This is your "knowledge acquisition" chapter and it is where much of the project's academic credit comes from.
2. **Collect the evaluation data:** speech tests, response times, SUS questionnaires.
3. **Rehearse the demo** with the phone in airplane mode, and have the chips and text box ready as backup in case the room is noisy.
4. **Read every file Antigravity writes** at least once. You will be asked about it.
