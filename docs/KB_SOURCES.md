# Knowledge base sources

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

Signature: ____________________
