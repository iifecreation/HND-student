# Architecture & Technical Design Specification

**Project:** PrinterDoc — Edge Expert System for Printer Fault Diagnosis  
**Target:** Android (API 24+) | Offline-first Edge Architecture  
**Author:** HND Final-Year Student Project  

---

## 1. System Overview & Layered Architecture

PrinterDoc is engineered using a clean, layered architecture with a strict boundary between platform-dependent presentation/voice services and a pure-Dart core computational engine.

```mermaid
graph TD
    subgraph UI_Layer ["Presentation Layer (Flutter & Material 3)"]
        HomeScreen["HomeScreen<br/>(Transcript, Chips, Mic Button)"]
        DiagnosisScreen["DiagnosisScreen<br/>(Fault, Checklist, Provenance, Alternatives)"]
        KBScreen["KBScreen<br/>(Fault Search & Rule Viewer)"]
        HistoryScreen["HistoryScreen<br/>(Audit Logs & JSON Export)"]
        SettingsScreen["SettingsScreen<br/>(Edge Status, STT/TTS Config)"]
        AboutScreen["AboutScreen<br/>(Viva Info, Electrical Safety Warning)"]
        DiagnosisVM["DiagnosisViewModel<br/>(ChangeNotifier Coordinator)"]
    end

    subgraph Service_Layer ["Voice & Local Services (Platform Bound)"]
        VoskRec["VoskSpeechRecognizer<br/>(Offline Small Model)"]
        DeviceRec["DeviceSpeechRecognizer<br/>(Android On-Device STT)"]
        TtsServ["TtsService<br/>(Offline Android TTS, Pacing 0.45)"]
        EdgeStat["EdgeStatusService<br/>(Self-Check: Model, Mic, Zero-Internet)"]
        SessLog["SessionLogger<br/>(Append-Only JSON-Lines Audit)"]
        SettingsRepo["SettingsRepository<br/>(SharedPreferences)"]
    end

    subgraph Core_Layer ["Pure-Dart Isolated Core (Zero Flutter Imports)"]
        DM["DialogueManager<br/>(State Machine, Turns, Explanation)"]
        NLU["Natural Language Understanding<br/>(SymptomExtractor, Stemmer, Levenshtein)"]
        IE["InferenceEngine<br/>(Forward Chaining, Certainty Factors)"]
        QS["QuestionSelector<br/>(Max CF Gain Heuristic)"]
        KB["KnowledgeBase & Loader<br/>(Faults, Symptoms, Rules from JSON)"]
    end

    HomeScreen --> DiagnosisVM
    DiagnosisScreen --> DiagnosisVM
    DiagnosisVM --> DM
    DiagnosisVM --> VoskRec
    DiagnosisVM --> DeviceRec
    DiagnosisVM --> TtsServ
    DiagnosisVM --> SessLog
    DiagnosisVM --> SettingsRepo
    SettingsScreen --> EdgeStat

    DM --> NLU
    DM --> IE
    DM --> QS
    IE --> KB
    QS --> KB
    NLU --> KB
```

---

## 2. Pure-Dart Core Isolation Principle

To guarantee testability, maintainability, and clean separation of concerns, the computational core located in:
- `lib/knowledge/`
- `lib/engine/`
- `lib/nlu/`
- `lib/dialogue/`

contains **zero imports from `package:flutter/...`**. All data structures are standard Dart (`dart:core`, `dart:collection`, `dart:math`, `dart:convert`). This enables sub-millisecond unit test execution without spinning up Flutter test harnesses or Android emulators.

---

## 3. Dialogue Manager State Machine

The interaction flow is managed by a deterministic finite state machine implemented in `DialogueManager`.

```mermaid
stateDiagram-v2
    [*] --> Idle: startSession()

    Idle --> Collecting: First prompt / Welcome
    Collecting --> Questioning: Initial symptoms extracted & candidates exist
    Collecting --> Escalated: No symptoms matched / unparseable

    Questioning --> Questioning: User answers Yes / No / Unsure<br/>(Inference updates candidates)
    Questioning --> Diagnosed: Top candidate reaches CF >= 0.60<br/>or no further questions remain
    Questioning --> Escalated: All questions exhausted with no fault >= 0.20
    Questioning --> SafetyEmergency: Overheating / smoke detected (FR09)

    Diagnosed --> Explaining: User asks "Why this?" / taps provenance
    Explaining --> Diagnosed: Back to diagnosis

    Diagnosed --> Questioning: User reports "Did not fix it" (FR10)<br/>(Current candidate excluded, next evaluated)
    Diagnosed --> Idle: User taps "Start Over" / "Fixed"

    SafetyEmergency --> Idle: User resets session
    Escalated --> Idle: User resets session
```

### State Definitions & Transitions:
1. **Idle:** System initialized, waiting for user trigger.
2. **Collecting:** Initial open-ended symptom elicitation (*"What seems to be the problem with your printer?"*).
3. **Questioning:** System targets the highest-information follow-up symptom and prompts the user with binary/clarification questions (*"Does the printer fail to pull paper in from the tray?"*).
4. **Diagnosed:** A conclusive candidate exceeds the confidence threshold ($CF \ge 0.60$) or maximum information gain has concluded. Displays repair steps.
5. **Explaining:** The user invokes *"Why?"* or inspects the audit trail, prompting rule contributions and evidence.
6. **SafetyEmergency:** Immediate override triggered when critical thermal/electrical hazard symptoms appear (FR09).
7. **Escalated:** Safe fallback when symptoms are contradictory or cannot be resolved above $CF = 0.20$.

---

## 4. Forward-Chaining Inference & Certainty Algebra

The inference engine executes data-driven forward chaining using certainty factor algebra adapted from Shortliffe & Buchanan's MYCIN expert system.

```mermaid
flowchart TD
    Start([User Utterance / Answer]) --> NLU[Extract Symptoms & Polarities]
    NLU --> AssertWM[Update WorkingMemory: symptomId -> bool]
    AssertWM --> SafetyCheck{Is 'overheating' asserted true?}
    SafetyCheck -- Yes --> SafetyTrigger[Short-circuit: Fault F20, CF = 1.0]
    SafetyCheck -- No --> MatchRules[Evaluate Rule Antecedents]

    MatchRules --> EvalConds{Check Conditions:<br/>- all satisfied?<br/>- any satisfied?<br/>- none absent/false?<br/>- excludes absent/false?}
    EvalConds -- No --> NextRule[Skip Rule]
    EvalConds -- Yes --> ComputeCF[Calculate Rule CF Contribution]

    ComputeCF --> CombineCF[Combine with Existing Fault CF:<br/>CF_new = CF_old + CF_rule * (1 - CF_old)]
    CombineCF --> MoreRules{More Rules?}
    MoreRules -- Yes --> MatchRules
    MoreRules -- No --> RankCandidates[Rank Candidates by CF descending]

    RankCandidates --> ThresholdCheck{Top candidate CF >= 0.60<br/>OR questions exhausted?}
    ThresholdCheck -- Yes --> Conclude[Diagnose Top Fault Candidate]
    ThresholdCheck -- No --> SelectQ[QuestionSelector: Find Next Best Question]
```

### Mathematical Certainty Factor Algebra:
- **Rule Firing:** A rule fires if all preconditions in its `all` list are confirmed in working memory, at least one in `any` is confirmed (if specified), no symptoms in `none` are confirmed true, and no symptoms in `excludes` are confirmed true.
- **Parallel Certainty Combination:** When multiple independent rules $R_1, R_2, \dots, R_k$ conclude the same fault hypothesis $h$ with positive certainty factors $CF_1, CF_2$:
  $$CF_{comb}(h) = CF_{prev} + CF_{new} \cdot (1 - CF_{prev})$$
- **Bounded Monotonicity:** As evidence accumulates, certainty monotonically increases toward 1.0 without ever exceeding 1.0:
  $$\lim_{k \to \infty} CF(h) = 1.0$$
- **Pruning Thresholds:**
  - Candidates with $CF < 0.20$ are pruned as non-viable.
  - Candidates with $CF \ge 0.60$ qualify for confident diagnosis.

---

## 5. Natural Language Understanding (NLU) Pipeline

The NLU subsystem is deterministic and lightweight, requiring no neural models or tokenizers:

```mermaid
flowchart LR
    Input["Spoken/Typed Utterance"] --> Norm["TextNormalizer<br/>(Lowercase, Punctuation Strip, Tokenize)"]
    Norm --> Stem["Stemmer<br/>(Porter-style Suffix Stripping)"]
    Stem --> Match["SymptomExtractor<br/>(Longest-Phrase Match & Levenshtein)"]
    Match --> Negate["Negation Scope Analyzer<br/>(3-Token Window & Clause Delimiters)"]
    Negate --> Output["Extracted Symptoms & Polarities"]
```

1. **Text Normalization:** Converts strings to lowercase, strips punctuation while retaining alphanumeric tokens and contractions, collapses repeated whitespace.
2. **Stemming:** Applies step-by-step suffix stripping (e.g. `-ing`, `-ed`, `-es`, `-s`, `-tion`, `-ment`) to match root word variations (*"jamming"* $\to$ *"jam"*, *"streaks"* $\to$ *"streak"*).
3. **Levenshtein Fuzzy Matching:** Supports fuzzy token comparison with adaptive distance:
   - Tokens with length $\le 3$: exact match only.
   - Tokens with length $4 \dots 6$: Levenshtein distance $\le 1$.
   - Tokens with length $\ge 7$: Levenshtein distance $\le 2$.
4. **Negation Detection:** Inspects up to 3 tokens preceding a matched phrase for negative indicators (`no`, `not`, `dont`, `doesnt`, `isnt`, `cant`, `cannot`, `never`, `without`).
5. **Clause Boundary Delimitation:** Tokens such as `but`, `however`, `although`, `though`, and `yet` isolate negation scope, preventing negative modifiers from leaking into contrastive clauses (*"not jammed but will not feed"*).

---

## 6. Class Hierarchy & Entity Relationships

```mermaid
classDiagram
    class KnowledgeBase {
        +List~Symptom~ symptoms
        +List~Fault~ faults
        +List~Rule~ rules
        +Symptom? getSymptom(String id)
        +Fault? getFault(String id)
        +List~Rule~ getRulesForFault(String faultId)
    }

    class Rule {
        +String id
        +List~String~ all
        +List~String~ any
        +List~String~ none
        +List~String~ excludes
        +String then
        +double cf
        +String why
        +bool safety
    }

    class Fault {
        +String id
        +String name
        +String category
        +String severity
        +bool technician
        +String summary
        +List~String~ steps
    }

    class Symptom {
        +String id
        +String label
        +String category
        +List~String~ synonyms
        +String question
        +List~String~ excludes
    }

    class WorkingMemory {
        -Map~String, bool~ _facts
        +void setFact(String symptomId, bool value)
        +bool? getFact(String symptomId)
        +bool isTrue(String symptomId)
        +bool isFalse(String symptomId)
    }

    class InferenceEngine {
        +KnowledgeBase kb
        +InferenceResult infer(WorkingMemory wm, Set~String~ excludedFaults)
    }

    class QuestionSelector {
        +KnowledgeBase kb
        +Symptom? selectNextQuestion(WorkingMemory wm, List~FaultCandidate~ candidates)
    }

    class DialogueManager {
        +KnowledgeBase kb
        +DialogueState state
        +WorkingMemory workingMemory
        +DialogueResponse processUtterance(String text)
        +void restartSession()
    }

    KnowledgeBase "1" o-- "*" Rule
    KnowledgeBase "1" o-- "*" Fault
    KnowledgeBase "1" o-- "*" Symptom
    InferenceEngine --> KnowledgeBase
    InferenceEngine --> WorkingMemory
    QuestionSelector --> KnowledgeBase
    DialogueManager --> InferenceEngine
    DialogueManager --> QuestionSelector
    DialogueManager --> WorkingMemory
```

---

## 7. Voice Subsystem & Half-Duplex Coordination

To prevent acoustic feedback (where speech synthesis is picked up by the microphone recognizer), the audio services operate in a synchronized **half-duplex mode**:

```
+-------------------------------------------------------------+
|                     Half-Duplex Coordinator                 |
|                                                             |
|   1. System speaks (TTS active)                             |
|      --> Mic recognizer explicitly PAUSED                   |
|      --> Mic button UI indicates muted speaker state        |
|                                                             |
|   2. TTS Completes (`await tts.speak()`)                    |
|      --> 350 ms acoustic settling delay                     |
|      --> Auto-listen resumes (if enabled in Settings)       |
|      --> Mic recognizer activated                           |
|      --> Mic button UI pulses green                         |
+-------------------------------------------------------------+
```

- **Pluggable STT Interface (`SpeechRecognizerService`):**
  - `VoskSpeechRecognizer`: Offline small acoustic model running locally on-device.
  - `DeviceSpeechRecognizer`: Android native speech recognizer configured with `onDevice: true`.
- **Offline TTS Engine (`TtsService`):**
  - Native Android `TextToSpeech` service configured for `en-US`.
  - Pacing defaulted to $0.45$ for clear step-by-step diagnostic instructional cadence.
  - Startup self-check alerts the user if language data requires offline voice download in Android Settings.

---

## 8. Persistence & Audit Logging

- **`SessionLogger`:** Diagnostic sessions are logged to an append-only JSON-lines (`.jsonl`) file in the application's local documents directory (`diagnostics_history.jsonl`). Corrupted lines are skipped gracefully, sessions are retrieved in reverse-chronological order, and audit records can be exported directly to clipboard or file.
- **`SettingsRepository`:** User preferences (voice rate, STT engine choice, auto-listen toggle, Vosk model path) are persisted via `shared_preferences`.
