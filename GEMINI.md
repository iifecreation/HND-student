# AGENTS.md: standing rules for this workspace

## Project
Voice-controlled edge expert system for diagnosing printer faults. Flutter (Dart), Android only. A final-year HND project. The student must be able to explain and defend every line in a viva, so clarity beats cleverness.

Full requirements are in `docs/SPEC.md`. Read the relevant sections before starting any task. Seed knowledge is in `assets/kb/`.

## Hard constraints
1. **Offline at runtime.** No internet access, no cloud APIs, no analytics. Do not add the INTERNET permission to the release manifest. No HTTP clients.
2. **Pure-Dart core.** Code in `lib/knowledge`, `lib/engine`, `lib/nlu` and `lib/dialogue` must not import Flutter, so it can be unit-tested without a device.
3. **Knowledge lives in JSON**, not in Dart. Never hard-code rules, faults or symptoms in code.
4. **No black-box ML.** The expert system is rule-based forward chaining with certainty factors. Write Levenshtein, stemming and the inference engine by hand.
5. **Approved packages only:** `vosk_flutter` (alternates `vosk_flutter_service`, `vosk_flutter_fixed`), `speech_to_text`, `flutter_tts`, `permission_handler`, `provider`, `path_provider`, `shared_preferences`, `flutter_test`. Ask the student before adding anything else.
6. **Android `minSdkVersion` 24.** Target a mid-range phone with 3 GB RAM.

## Code style
- Null-safe, idiomatic Dart. Small files, one responsibility each. Follow the folder layout in `docs/SPEC.md` section 4.
- Every file begins with a short plain-English comment: what it does and why.
- Comment non-obvious logic. Prefer simple loops and plain classes over clever abstractions.
- UI depends on interfaces (for example `SpeechRecognizerService`), never directly on a plugin.

## Workflow
- Work one phase at a time. State the plan briefly, then implement.
- After each phase run `flutter analyze` and `flutter test`. Fix every warning and failure before reporting done.
- Never edit `expected` or `truth` in `assets/kb/test_scenarios.json` to make a test pass. Fix synonyms, extraction or rules instead, and tell the student exactly what you changed.
- If a plugin will not build, report the exact error, then try the fallback listed in `docs/SPEC.md` section 14. Do not silently replace it.
- Make a git commit at the end of each phase with a clear message.
- Do not rewrite files that are not part of the current task.
- At the end of each phase give a short summary: what was built, what was tested, what is left, and anything the student must do by hand.

## Things only the student can do (remind them when relevant)
Downloading the Vosk model into `assets/models/`, installing offline TTS voice data on the phone, enabling USB debugging, recording the manual evaluation data, and having a technician validate the rules.
