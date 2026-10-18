# Knowledge base sources

Current size: 90 symptoms, 64 faults, 152 rules, 109 test scenarios, across seven printer types (laser, inkjet, dot matrix, thermal receipt, label, large-format plotter, compact photo).

This file records where the knowledge in `assets/kb/` came from. It is the evidence for the knowledge acquisition chapter of the dissertation.

## How the knowledge was acquired

An expert system is not trained on data the way a machine-learning model is. Its knowledge is acquired: a knowledge engineer reads expert sources (manufacturer manuals, support notes, technicians) and writes what they say as IF-THEN rules with certainty factors. This project uses that method (SPEC section 2 rules out ML training).

The steps were:
1. Read the manufacturer's troubleshooting section for each printer type.
2. Pick out each *symptom → cause → remedy* the manual gives.
3. Write the symptom as a `symptoms.json` entry with the words a user might say, the cause as a `faults.json` entry with spoken repair steps, and the link as a `rules.json` rule.
4. Pick a certainty factor (CF) for each rule. 0.8 to 0.95 means the source names one clear cause. 0.5 to 0.7 means the source lists several possible causes.
5. Add a test scenario for each new fault to `test_scenarios.json` and run `flutter test`.
6. **Still to do:** have a printer technician review the rules and CFs (see the table at the end).

The repair steps are written in our own words, not copied from the manuals.

## Sources for faults F29 to F40 (added October 2026)

| Fault | Printer type | Main source | What it supports |
|---|---|---|---|
| F29 Worn-out ribbon | Dot matrix | Epson LX-350 User's Guide, *Problems and Solutions*: https://files.support.epson.com/htmldocs/lx50__/lx50__ug/trble_2.htm | "Sounds like printing but nothing prints" or faint print: ribbon worn out or not installed properly; replace the ribbon cartridge. |
| F30 Damaged print head pin | Dot matrix | Same Epson LX-350 page; Epson LQ-630 and PLQ-20 guides (search results); TechRepublic, *Troubleshoot common dot matrix printer problems* | "Lines of dots are missing": print head damaged, stop and have a dealer replace the head. White horizontal lines usually mean a dead pin. |
| F31 Loose or twisted ribbon | Dot matrix | Same Epson LX-350 page; Epson PLQ-20 guide | Missing dots can be caused by too much slack in the ribbon; reinstall the cartridge and take up slack with the knob. |
| F32 Tractor feed problem | Dot matrix | Same Epson LX-350 page, *Continuous paper does not feed properly* | Paper release lever position, paper off the tractor, misaligned holes, sprocket units not locked, paper supply more than 1 m away or obstructed. |
| F33 Roll loaded wrong way | Thermal receipt | Epson TM-m30II-H Technical Reference, *Installing or Replacing the Roll Paper*: https://download4.epson.biz/sec_pubs/bs/html/m001275/en/chap05_4.html | Install the roll in the correct direction and take up slack. |
| F34 Non-thermal paper | Thermal receipt | Epson TM-T20 guidance quoted by Club Caddie support: https://support.clubcaddie.com/portal/en/kb/articles/epson-tm-20-receipt-printer-troubleshooting-and-faqs | The printer needs thermal paper to print. (The fingernail scratch test is common trade practice; ask the technician to confirm it.) |
| F35 Dirty thermal head | Thermal receipt | Epson TM-m30II-H, *Printout is Faint* and *Cleaning the Thermal Head and the Platen Roller*: https://download4.epson.biz/sec_pubs/bs/html/m001275/en/chap07_3.html and https://download4.epson.biz/sec_pubs/bs/html/m001275/en/chap06_2.html | Faint print or banding means a stained head; clean with alcohol on a cotton swab about every 3 months; head is hot after printing. |
| F36 Cover open / paper finished | Thermal receipt | Epson TM-m30II-H, *Meanings of LED Indications*: https://download4.epson.biz/sec_pubs/bs/html/m001275/en/chap07_2.html | Error LED for cover open and for no roll paper; power off for 10 seconds; if it persists, contact service. |
| F37 Auto-cutter jam | Thermal receipt | Same LED page and *When the Roll Paper Jams*: https://download4.epson.biz/sec_pubs/bs/html/m001275/en/chap07_5.html | Cutter error: check for jammed paper or a foreign object; never pull paper out with force; do not touch the hot head. |
| F38 Waste ink pads full | Inkjet | Epson US, *Printer Parts "Service Required" Message*: https://epson.com/Support/wa00369 ; Canon Community moderator replies on support code 5B00: https://community.usa.canon.com/t5/Desktop-Inkjet-Printers/PIXMA-MG7120-printer-has-a-Support-Code-5B00/td-p/520470 | The pads collect waste ink and the printer stops to prevent leaks; service centre or certified technician; Canon says 5B00 is not user-serviceable. |
| F39 Print head failure | Inkjet | Canon Community threads on support code B200: https://community.usa.canon.com/t5/Desktop-Inkjet-Printers/PIXMA-MX922-with-error-code-B200-Series-MX920/m-p/341886 | Power reset, reseat cartridges; persistent B200 needs repair. **Weaker source (community forum), so get the technician to confirm.** |
| F40 Drum counter not reset | Laser | Brother support FAQs on drum messages, e.g. https://www.brother.com.ph/en/support/hl-l5100dn/faqs?cate=187 | "Replace Drum" can remain after fitting a new drum until the drum counter is reset; the reset does not fix a worn drum. |
| F08 (new rule R97) | Laser | Same Brother FAQs; HP repeating-defect tables: https://www.hp.com/cpso-support-new/pq/M855/defectspacing.html | "Drum End Soon" means the drum is near the end of its life. |

## Sources for faults F41 to F50 (added October 2026, batch 2)

| Fault | Printer type | Main source | What it supports |
|---|---|---|---|
| F41 Dirty corona wire | Laser (Brother) | Brother HL-B2080DW Online User's Guide, *Clean the Corona Wire*: https://support.brother.com/g/s/id/htmldoc/printer/cv_hlb2080dw/asoce/html/GUID-F406D846-93AB-4C32-ABE0-C31497BAAAE0_154.html | The [Drum !] message means clean the corona wire by sliding the green tab; return it to home or pages get a vertical stripe. |
| F42 Paper size/type mismatch | Laser and inkjet | Brother HL-B2080DW, *Error and Maintenance Messages*: https://support.brother.com/g/s/id/htmldoc/printer/cv_hlb2080dw/asoce/html/GUID-D508418E-CC5B-42EE-8001-EFFA0AFD6A51_126.html | Size Mismatch, Size Error and Media Mismatch messages: load the right paper and set the matching tray size and type. |
| F43 Fuser heating error | Laser | Same Brother messages table (*Self-Diagnostic*: fuser does not reach temperature); HP Community and repair-guide reports on HP 50.x fuser errors (search results) | Power off, wait, leave idle 15 minutes; fuser or power board if it persists; avoid UPS and power strips. **HP part is community-sourced.** |
| F44 Print job cannot be processed | Laser | HP Community accepted answers on the 49 service error: https://h30434.www3.hp.com/t5/LaserJet-Printing/49-Service-Error/td-p/5645477 ; Brother messages table (*Out of Memory*, *Print Data Full*) | Remove all jobs from every computer, disconnect and restart, update firmware; reduce resolution for memory errors. **HP part is community-sourced.** |
| F45 Waste toner full | Office laser / copier | Kyocera, Ricoh and Konica technician forum threads (copytechnet.com, edugeek.net, search results) | Waste toner box is counted and the machine stops until it is replaced; a stuck sensor can give false readings. **No official Kyocera page was reachable, so the technician should confirm.** |
| F46 Label sensor not calibrated | Label (Zebra) | Zebra ZD620/ZD420 User Guide, *Resolve Print Issues*: https://docs.zebra.com/us/en/printers/desktop/bm-zd620-and-zd420-desktop-printers-user-guide-ditamap/c-zd620-420-troubleshooting/c-zd620-zd420-ug-resolve-print-issues.html ; Zebra ZD220/230 flash sequence: https://support.zebra.com/article/000027417 | Skipping labels: sensor not calibrated or not positioned; run SmartCal (hold Feed until two flashes); media out alerts from dirty or misaligned sensor. |
| F47 Label media/ribbon loaded wrongly | Label (Zebra) | Same Zebra *Resolve Print Issues* page | No print on the label: printable side must face the head; thermal transfer media needs a ribbon. |
| F48 Faint labels | Label (Zebra) | Same Zebra page | Darkness and speed settings, dirty print head, worn head. |
| F49 Air in ink tubes after refill | Ink tank (Epson EcoTank etc.) | Epson ET-2720 FAQ: https://epson.com/faq/SPT_C11CH42201~faq-000080a-et2720 | After refilling expended tanks, run Power Cleaning, tanks at least one third full, wait 12 hours between Power Cleanings. |
| F50 Cover not closed | Laser | Brother messages table (*Cover is Open*) | Close the front cover and the fuser cover firmly. |

Also from batch 2:
- R89 and R90 (thermal roll empty, roll cover open) now require a thermal printer. Before this fix, a laser user saying "out of paper" got receipt advice.
- R118 (cartridge error on a laser means the cartridge is not seated) comes from Brother's *Cartridge Error* and *No Toner* rows.
- Brand model-line names (PIXMA, EcoTank, LaserJet, i-SENSYS, ECOSYS, TaskAlfa, bizhub, TM-T20, Zebra, DYMO) were added as printer-type synonyms, so saying the model tells the system the printer type.
- Single words that the fuzzy matcher would confuse with common words were removed on purpose: "xprinter" (≈ printer), "copier" (≈ copies), "label" and "labels".

## Sources for faults F51 to F54 (batch 3)

| Fault | Printer type | Main source | What it supports |
|---|---|---|---|
| F51 Phone cannot print | Any network printer | OKI online manual, *Troubleshooting for Mopria Print Service*: https://www.oki.com/printing/online-manuals-Z002/EE8001-4624/id/contents/contents/120775527.html | Wait 2–3 minutes after power-on, same network as the phone, Default/Mopria Print Service enabled on Android, firmware up to date, Mopria enabled on the printer. |
| F52 Service call code | Office copier / laser (Ricoh etc.) | Ricoh service-code summaries and technician forum threads (search results; no official Ricoh page reachable) | SC codes are hardware, temperature or control faults; power-cycle at most once; heat/fuser codes need an authorised technician. **Community-sourced, so ask the technician to confirm.** |
| F53 Extra blank pages | Any | HP Tech Takes, *Printer printing blank pages fix*: https://www.hp.com/us-en/shop/tech-takes/printer-printing-blank-pages-fix ; existing separation-pad rules (F24) | Blank pages from settings, drivers or feeding; extra pages from document page breaks and paper-size mismatch are common trade knowledge. |
| F54 Two-sided printing blocked | Laser and inkjet | Brother HL-B2080DW *Error and Maintenance Messages* (*2-sided Disabled*, *Size Error DX*), link above | Back cover not closed, 2-sided tray not installed, paper size not supported for duplex. |
| F39 (new synonyms) | Inkjet (HP) | HP Community threads on "Missing or Failed Printhead" (OfficeJet Pro 8610/8620) | Same fault as Canon B200: reseat the head, clean the contacts, replace the head if it persists. |

**Design note found while testing (useful for the viva):** the extractor treats *not / cannot / can't* just before a phrase as negation. For symptoms that describe a failure ("cannot print from my phone"), the negative word must be inside the synonym, or the symptom is recorded as absent. Scenarios T78 and T84 caught this.

## Sources for faults F55 to F58 (batch 4)

Main source: Brother HL-B2080DW Online User's Guide, *Improve the Print Quality*: https://support.brother.com/g/s/id/htmldoc/printer/cv_hlb2080dw/asoce/html/GUID-EEC1EE16-C8ED-4BC3-B3C4-27B0AACF0D44_133.html

| Fault / rule | What the source says |
|---|---|
| R125–R126 grey background → F08 worn drum | *Grey background*: hot or humid room, clean the drum, replace the drum. |
| F55 Drum surface contaminated | *Toner specks* and *spots at 94 mm intervals*: glue from label sheets or foreign material on the drum; clean with Drum Dot Print; staples or clips can damage the drum. |
| F56 Toner on transfer roller or fuser | *Toner specks* / *toner stains*: fuser may be contaminated, contact service. HP Community answers also name the transfer roller (https://h30434.www3.hp.com/t5/LaserJet-Printing/Grey-Shading-on-8000N/td-p/7452548). |
| F57 Wrong setting for envelopes or thick paper | *Poor fixing* and *Envelope creases*: green levers inside the back cover, media type setting, envelopes from the manual feed slot with the back cover open. R17 and R30 (fuser) now exclude this case. |
| F58 Print job set to manual feed | Brother *Error and Maintenance Messages*, *Manual Feed*: manual selected as the paper source in the driver. |
| draft_mode synonyms | *Faint*: Toner Save may be on. |

## Sources for faults F59 to F62 (batch 5)

| Fault | Printer type | Main source | What it supports |
|---|---|---|---|
| F59 Roll paper skewed | Large format (HP DesignJet) | HP, *Designjet T-Series and Z-Series - Paper Skewing or Misaligned Paper*: https://support.hp.com/us-en/document/c03673219 | Space around the printer, bent spindle or broken hubs, roll loose on its core, roll against the stoppers, straight leading edge, follow the front-panel alignment instructions. |
| F60 Photo cassette mismatch | Compact photo (Canon SELPHY) | Canon Community, Canon staff reply on SELPHY CP1500 "paper and ink cassette sizes are incorrect": https://community.usa.canon.com/t5/Mobile-Compact-Printers/SELPHY-CP1500-Paper-and-ink-cassette-sizes-are-incorrect/m-p/521252 | Paper types L, Postcard and Card; select the loaded paper type in the SELPHY app; reseat the cassettes. **Forum source with Canon staff; get the technician to confirm.** |
| F61 Bluetooth not paired | Portable / receipt | Epson *TM Bluetooth Connector* overview (an OS update deletes pairing information); Lightspeed POS guide for TM-m10/TM-m30 (forget device, power-cycle, re-pair, app Bluetooth permission) | |
| F62 Page length / top of form | Dot matrix | Epson LX-350 User's Guide *Problems and Solutions* (link above): *Printing position problems* and *Regular gaps occur in the printout* | Margin/top-of-form in the application, tractor page length, skip over perforation. |
| Brand names | Laser | Pantum M6200 manual (*No Laser Toner Cartridge Detected*, *Close Output Bin*); Lexmark, Xerox, Ricoh, Kyocera, Konica, Samsung Xpress added as laser synonyms | R118 raised from 0.60 to 0.75 because Brother and Pantum both name "not installed correctly" as the cause of a cartridge-not-detected message. |

**Design change in batch 5 (viva point):** with seven printer types, the question selector used to ask "is it X?" for one type after another and ran out of its 6-question budget before reaching real symptoms. Original scenario T02 started failing because of this. The selector now forces only one early type question and allows at most two type questions per session (`QuestionSelector.maxTypeQuestions`). A user can still name the type in their own words at any time.

## Sources for batch 6 (F63, F64 and new message wording)

| Item | Brand / type | Main source | What it supports |
|---|---|---|---|
| F63 Ink level detection stopped | Canon inkjet | Canon support, *A Support Code and A Message Are Displayed*: https://support.usa.canon.com/kb/articles/en_US/Knowledge/ART143345 (and regional copies such as https://sg.canon/en/support/8201730300) | Code 1686: ink level cannot be detected; 1688: ink has run out; holding Stop for at least 5 seconds continues printing with level detection disabled; Canon is not liable for printing in the ink-out state. |
| R144–R145 → F23 | HP laser | HP support document on PCL XL errors: https://support.hp.com/sg-en/document/c02008692 | PCL XL errors come from the driver or print language; change driver settings, use the model-specific or PostScript driver. |
| cartridge_not_recognized wording | HP inkjet | HP support, dynamic security and "Cartridge Problem" / "cartridges appear to be damaged": https://support.hp.com/nz-en/document/c05308850 | Non-HP chips can be rejected; HP released firmware that disables dynamic security on affected models (existing F17 steps). |
| F64 Colour registration | Colour laser (Brother) | Brother FAQ *Correct Color Print Alignment (Color Registration)*: https://support.brother.com/g/b/faqend.aspx?c=us&lang=en&prod=hll3270cdw_us_eu_as&faqid=faq00000023_500 | Use registration when colour areas have cyan, magenta or yellow fringes; Toner > Registration; colour calibration is a separate step. |
| R150–R152 beeping | Dot matrix (Epson) | Epson LX-350 *Problems and Solutions* (link above) | "Beeper sounds five times and all lights blink": error; switch off and on; check for paper or ribbon jam. |
| wifi_drop, job_stuck wording | Any | Existing faults F14 and F15 | "won't connect to Wi-Fi", "WPS failed", "spooler not running". |

**Quality checks added in batch 6 (viva point):**
- `KbValidator` now reports an error if the same synonym belongs to two symptoms. It found "refilled" in both *third-party cartridge* and *ink tanks recently refilled*.
- New test `test/extraction_precision_test.dart`: no scenario sentence may produce a symptom outside its truth list. It caught "printer beeps" fuzzy-matching "printer keeps" and "very old" (old printer) inside "ribbon is very old".

## Live app test on an Android emulator (17 October 2026)

The debug app was installed on a Pixel 4 emulator (Android 16, 2 GB RAM) and driven by typed input:
1. The app started, asked for microphone permission, loaded the Vosk model with no error banner, and greeted the user.
2. Typing "myy" (rubbish) got "I did not catch a specific printer symptom…".
3. "my receipt printer prints blank receipts" → the scratch-test question → answering No → more questions → **Diagnosis: Thermal paper roll loaded the wrong way (F33), 60%**. The Diagnosis & Fix Guide showed severity, the certainty bar and the five spoken steps.

**Bug found and fixed during this test:** the Android TTS engine was updated in the background mid-session. flutter_tts then never reported speech completion, and the next reply hung. `TtsService.speak()` now has a time limit and re-initialises the engine, and the reply no longer waits on stopping the microphone or saving timings.

## Sources still needed for F01 to F28

The original 28 faults came from general troubleshooting practice. Before submission, add one manufacturer source to each row, for example:
- HP support "Fix paper jams" and "Printer offline" pages for F01–F04 and F12–F16.
- HP LaserJet print quality and repeating-defect tables for F07–F09 and F27.
- Canon and Epson inkjet print quality pages (nozzle check, head cleaning) for F06 and F11.

## Technician validation table (print this and fill it in)

Technician name: ____________________  Role / workshop: ____________________  Date: __________

| Rule | IF | THEN | CF | Agree? | Suggested change |
|---|---|---|---|---|---|
| R73 | faded print + dot matrix | F29 worn ribbon | 0.70 | | |
| R74 | faded print + dot matrix + old ribbon | F29 | 0.90 | | |
| R75 | blank page + dot matrix | F31 ribbon badly seated | 0.60 | | |
| R77 | missing dot lines (ribbon not loose) | F30 broken pin | 0.70 | | |
| R81 | paper coming off tractor | F32 tractor feed | 0.80 | | |
| R84 | blank receipt + non-thermal paper | F34 | 0.95 | | |
| R85 | blank receipt (paper is thermal) | F33 roll backwards | 0.60 | | |
| R87 | faint receipt | F35 dirty thermal head | 0.70 | | |
| R89 | paper roll finished | F36 | 0.85 | | |
| R92 | cutter error | F37 cutter jam | 0.85 | | |
| R94 | ink absorber / service life message | F38 waste ink pads | 0.90 | | |
| R95 | print head error message | F39 head failure | 0.80 | | |
| R96 | drum message + new drum | F40 counter not reset | 0.85 | | |
| R97 | drum message, no new drum | F08 worn drum | 0.70 | | |
| R98 | Drum ! message | F41 dirty corona wire | 0.85 | | |
| R100 | size or media mismatch message | F42 | 0.85 | | |
| R101 | fuser error message | F43 fuser heating | 0.85 | | |
| R102 | 49 service error / memory full | F44 bad print job | 0.80 | | |
| R104 | waste toner box full | F45 | 0.90 | | |
| R105 | labels skip | F46 sensor calibration | 0.85 | | |
| R110 | blank labels | F47 media/ribbon wrong | 0.75 | | |
| R111 | faint labels | F48 darkness / dirty head | 0.75 | | |
| R113 | blank pages after refilling ink tank | F49 air in tubes | 0.85 | | |
| R116 | cover open (not receipt printer) | F50 | 0.80 | | |
| R119 | cannot print from phone | F51 | 0.80 | | |
| R121 | service call / SC code | F52 technician | 0.90 | | |
| R122 | extra blank pages | F53 | 0.70 | | |
| R124 | two-sided printing not working | F54 | 0.80 | | |
| R125 | grey background (laser) | F08 worn drum | 0.70 | | |
| R128 | specks after label sheets | F55 drum contaminated | 0.85 | | |
| R130 | toner on back of page | F56 transfer roller / fuser | 0.75 | | |
| R131 | toner rubs off envelopes / card | F57 settings | 0.85 | | |
| R134 | manual feed message | F58 | 0.85 | | |
| R135 | roll misaligned / too much skew | F59 | 0.85 | | |
| R137 | photo cassette size error | F60 | 0.85 | | |
| R139 | Bluetooth will not pair | F61 | 0.80 | | |
| R142 | print starts in wrong place (dot matrix) | F62 | 0.85 | | |
| R118 | cartridge not detected (laser) | F10 not seated | 0.75 | | |
| R144 | PCL XL / PostScript error page | F23 driver language | 0.85 | | |
| R146 | ink has run out / 1688 / 1686 | F63 | 0.80 | | |
| R148 | colours misaligned | F64 registration | 0.80 | | |
| R151 | beeping dot matrix | F28 restart / jam check | 0.65 | | |

Signature: ____________________
