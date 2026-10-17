# PrinterDoc: User Guide & Operator Manual

**PrinterDoc** is an offline, voice-controlled edge expert system designed to help users diagnose and resolve desktop printer faults on Android smartphones.

---

## ⚠️ Important Safety Notice

> **SAFETY FIRST:** Always switch off and unplug your printer from the electrical wall outlet before opening covers, touching rollers, or removing internal assemblies.
>
> If you detect **smoke, a pungent burning smell, or extreme heat**, **STOP IMMEDIATELY**. Switch off power at the wall if safe to do so, unplug the unit, ventilate the area, and consult a qualified printer technician. Never operate a damaged electrical appliance.

---

## 1. Quick Start Guide

1. **Launch the App:** Open **PrinterDoc** on your Android smartphone.
2. **Grant Microphone Access:** When prompted on first launch, allow audio recording permissions so the offline voice recognizer can hear your symptoms.
3. **Describe the Fault:** Tap the large green **Microphone** button at the bottom of the screen and speak naturally, or type your problem in the text box.
   - *Example:* *"My laser printer is printing faded pages and says low toner."*
   - *Example:* *"The paper keeps jamming in the tray."*
4. **Answer Follow-up Questions:** The expert system will ask targeted questions to narrow down the cause. Tap the quick-action chips (**Yes**, **No**, **Not Sure**) or speak your answer.
5. **Follow the Step-by-Step Fix:** When the diagnosis is reached, follow the numbered checklist. You can tap the speaker icon on any step to hear spoken instructions.

---

## 2. Screen-by-Screen Guide

### 2.1 Home / Diagnosis Screen

The Home screen is your primary interactive diagnostic assistant:
- **Offline Mode Badge:** Displayed at the top of the screen confirming that the app is operating 100% offline with zero cloud communication.
- **Chat Transcript:** Displays the conversation history with clean user speech bubbles and expert system responses.
- **Live Hearing Preview:** As you speak, a subtle preview line indicates real-time words heard by the speech engine before finalizing your sentence.
- **Microphone Button:** Large circular button in the center bottom. 
  - *Green & Pulsing:* The system is actively listening.
  - *Solid Green:* Ready to listen; tap once to activate push-to-talk.
  - *Muted Speaker:* The system is currently speaking guidance and microphone input is temporarily paused to avoid acoustic feedback.
- **Quick Action Chips:** Contextual buttons appear right above the input bar:
  - **Yes / No / Not Sure:** Quickly answer follow-up diagnostic questions with a single tap.
  - **Why?:** Ask the expert system why it is asking a specific question or how it reached a candidate.
  - **Start Over:** Clears working memory and begins a fresh consultation.
- **Text Input Row:** In noisy rooms or quiet office environments, you can type your symptoms using your phone's on-screen keyboard.

---

### 2.2 Diagnosis Result Screen

When the forward-chaining engine reaches a conclusion ($CF \ge 0.60$ or best candidate), the Diagnosis screen opens automatically:
- **Fault Title & Category:** Clearly displays the diagnosed issue (e.g., *"Clogged print head nozzles or low ink"*) along with its category badge (*Paper, Quality, Connectivity, Hardware, Safety*).
- **Severity Badge:** Indicates the issue severity (*Low, Medium, High, Critical*).
- **Confidence Bar:** Visual progress indicator showing the calculated Certainty Factor (e.g., *85% confidence*).
- **Summary:** Plain-English description of what causes the issue.
- **Step-by-Step Fix Checklist:** Clear, numbered repair steps:
  - Checkboxes help you track which steps you have completed.
  - Tap the **Speaker Icon** next to any step to have the step read aloud at an easy instructional pace.
- **"Why This?" Explanation Facility:** Tap to expand the reasoning audit trail. It shows:
  - Exactly which IF-THEN rules fired.
  - What symptoms triggered each rule.
  - The certainty factor contribution of each rule.
- **Ranked Alternatives:** Lists other plausible faults considered by the engine that had lower confidence scores.
- **Technician Warning:** If the fault requires specialized workshop tools or involves high-voltage/fuser components, a clear warning banner recommends certified technician assistance.
- **Resolution Feedback:**
  - **Fixed:** Concludes the consultation successfully and records the resolution in history.
  - **Did Not Work:** Tells the expert system the proposed fix failed. The system excludes that fault and resumes dialogue with the next best candidate (FR10).

---

### 2.3 Knowledge Base Browser

Tap the **Knowledge Base** tab in the navigation drawer or bottom bar to explore the entire printer troubleshooting knowledge base:
- **Search Bar:** Real-time search across all 40 faults, descriptions, and repair steps.
- **Category Filter:** Filter faults by *Paper, Quality, Connectivity, Hardware, or Safety*.
- **Fault Detail View:** Tap any fault card to view its complete summary, recommended repair sequence, and the exact knowledge base rules that conclude it.

---

### 2.4 History & Audit Logs

PrinterDoc records diagnostic consultations locally for record-keeping and viva evaluation:
- **Session List:** Displays past diagnostic sessions in reverse-chronological order with timestamps and outcomes.
- **Session Details:** Tap any session to inspect the complete question-and-answer exchange, diagnosed fault, and latency statistics.
- **Export Session:** Tap the **Export** button to copy formatted JSON data to your Android clipboard for report generation or external evaluation.

---

### 2.5 Settings & Edge Diagnostics

Configure voice parameters and inspect system health:
- **Edge Status Card:** Performs instant self-check diagnostics:
  - *Offline Status:* Confirms zero INTERNET permission.
  - *Microphone Permission:* Granted or Denied.
  - *Offline TTS:* Ready / Available.
  - *Vosk Model:* Loaded or Unloaded.
  - *Active STT Engine:* Vosk Offline Recognizer vs. Device Speech Recognizer.
- **Speech Rate Slider:** Adjust voice output speed from slow ($0.30$) to brisk ($0.75$). Default is $0.45$, calibrated for clear instructional audio.
- **Voice Output Toggle:** Turn spoken TTS responses on or off.
- **Auto-Listen Toggle:** When enabled, the microphone automatically opens after the app finishes speaking a question.
- **Speech-to-Text Engine Switcher:** Select between **Vosk Offline Acoustic Model** and **Android On-Device Recognizer**.
- **Vosk Model Archive Path:** Specify custom model paths to test alternate English models (e.g. for accent benchmarks).

---

### 2.6 About Screen

Provides academic viva metadata and safety disclaimers:
- Project title, student name, academic institution, and software version.
- Academic viva defense summary.
- Mandatory electrical and fire hazard disclaimer.

---

## 3. Best Practices for Voice Recognition

To achieve maximum speech accuracy when using offline voice recognition:
1. **Hold the Phone at 15–30 cm:** Keep the microphone a short distance from your mouth.
2. **Speak in a Natural Tone:** Speak clearly at normal conversational volume.
3. **Pause Before Speaking:** Tap the Mic button, wait for the green pulse, then begin speaking.
4. **Use Quick Chips in Loud Areas:** If printing equipment or workshop background noise makes speaking difficult, use the on-screen **Yes**, **No**, and category chips.

---

## 4. Troubleshooting & FAQ

| Problem | Cause | Solution |
|---|---|---|
| **App says "TTS Voice Data Not Found"** | Android lacks offline English voice packs. | Go to your phone's **Settings -> System -> Languages & input -> Text-to-speech output**. Tap the gear icon next to Preferred engine, select **Install voice data**, and download English (offline). |
| **Microphone does not react** | Permission was denied or audio is in use. | Open Android **Settings -> Apps -> PrinterDoc -> Permissions** and enable **Microphone**. |
| **Vosk model shows "Not Loaded"** | The model archive is missing. | Download `vosk-model-small-en-us-0.15.zip` and place it in the `assets/models/` folder as explained in the README, or switch to Device Speech Recognizer in Settings. |
| **Diagnosis shows "Escalated"** | Symptoms were too ambiguous or contradictory. | Tap **Start Over** and describe the most obvious visual symptom first (e.g., *"pages come out completely blank"*). |
