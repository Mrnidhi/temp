# Real PPR decks from Kolin (received 07-26, transcribed from photos)

Two real per-center decks Kolin produced with his current manual process. These are the
output the dashboard must be able to reproduce. The (Proposed) P&PR Metrics.xlsx
(Goal/IMG_9059.jpeg) stays the main template; these show how the numbers are actually
cut and presented today.

## What the real decks establish (differences from prior assumptions)

1. **Per-metric event dating, confirmed.** Footnote on both YoY slides: "Timing metrics
   based upon the TTP or Infusion Date." Enrollments count by enrollment date, TTPs by
   pickup date, infusions by infusion date. NOT an enrollment-date cohort cut.
2. **YoY uses custom date windows, not calendar years.** UK: Jan'25-Sept'25 (9 mo) vs
   Oct'25-May'26 (8 mo). Froedtert: Oct'24-Jun'25 vs Jul'25-Apr'26. Plus a Difference
   column with red/green sign coloring.
3. **Launch-to-Date slide = the Current Template**, but shown as 4 quartile RANGE columns
   (worst to best, left to right) with the center's own cell heat-colored by which
   quartile it lands in. Lower-is-better metrics (cancels, dropouts, OOS, progression,
   delivery-to-infusion days) have their quartile direction flipped so best is always
   rightmost/green.
4. **Median vs Average wording is inconsistent across his decks** (UK says Median,
   Froedtert says Average for the same timing rows). The proposed template says Average.
   Dashboard: keep Average, offer median as a toggle.
5. Real decks use a subset of metrics (9 on LTD, 8 on YoY), some renamed:
   "Patients Scheduled for TTP", "Patients with Completed TTP's", "Patients with OOS
   Product", "Tumor Tissue Procurements (scheduled + completed)".
6. Decks also include **"Closest Community Treaters"** provider tables. Provider-level
   (name, specialty, setting, HCO org, address). NOT derivable from the 7 Infinity
   exports; separate provider/claims source. Out of scorecard scope for now.

## Deck 1: UK Albert B Chandler Hospital (data as of May 5, 2026 @ 9:00AM EST)

### Slide 1 "Launch-to-Date Metrics" (LTD | National Average | Quartiles 1-4 as ranges)
| Metric | LTD | Natl Avg | Q1 | Q2 | Q3 | Q4 |
|---|---|---|---|---|---|---|
| Patients Enrolled in IovanceCares | 10 | 23.1 | 1-5 | 5-13 | 13-31 | 31-119 |
| Patients Scheduled for TTP | 7 | 17.1 | 0-3 | 3-10 | 10-25 | 25-80 |
| TTPs Cancelled or Rescheduled within 7 days of TTP | 0 | 4.5 | 5-40 | 2-5 | 1-2 | 0-1 |
| Patients with Completed TTP's | 7 | 16.9 | 0-3 | 3-10 | 10-25 | 25-80 |
| Patient Related Drop-outs due to patient health after TTP | 1 | 3.0 | 4-12 | 2-4 | 1-2 | 0-1 |
| Patients with OOS Product | 1 | 4.2 | 6-19 | 3-6 | 0-3 | 0-0 |
| Patient Progression Rate* | 14.3% | 8.6% | 11.11%-100% | 4.36%-11.11% | 0%-4.36% | 0%-0% |
| AMTAGVI Infusions performed | 3 | 9.6 | 0-2 | 2-4 | 4-13 | 13-53 |
| Median Time from Final Product Delivery Date to AMTAGVI Infusion (Days) | 18 | 10.3 | 12-19 | 10-12 | 8-10 | 2-8 |

Footnotes: `* Patient Progression Rate = (patient related drop-offs after mfg. start)/(mfg. starts)`;
`Data as of May 5th, 2026 @ 9:00AM EST`.
Cell coloring: center's LTD cell colored by quartile placement (red worst, green best).

### Slide 2 "Year over Year Metrics at ATC"
Columns: Jan.'25-Sept.'25 (9 months) | Oct.'25-May'26 (8 months) | Difference
| Metric | W1 | W2 | Diff |
|---|---|---|---|
| Enrollments in IovanceCares | 3 | 7 | +4 |
| Tumor Tissue Procurements (scheduled + completed) | 2 | 5 | +3 |
| Patient Related Drop-outs due to patient health (after TTP occurred) | 0 | 1 | -1 |
| Patients with OOS Product | 0 | 1 | -1 |
| AMTAGVI Infusions performed | 1 | 2 | +1 |
| Median Time from Enrollment to TTP Date (Days) | 52 | 29 | -23 |
| Median Time from TTP to Infusion (Days) | 52 | 54 | +2 |
| Median Time from Final Product Delivery Date to AMTAGVI Infusion (Days) | 11 | 18 | +7 |

Footnotes: `Data as of May 5th, 2026 @ 9AM EST`; `Timing metrics based upon the TTP or Infusion Date`.

### Slides 3-4 "University of Kentucky - Closest Community Treaters (1 of 2, 2 of 2)"
Provider table: First Name | Last Name | Specialty | Setting (Community/Academic) |
HCO Organization | HCO Address | City | State. ~16 rows/slide, KY orgs: Baptist Health
Medical Group (Lexington), Saint Joseph Health System, Commonwealth Hematology Oncology
(Danville), Rockcastle County Hospital, Baptist Healthcare System (La Grange/Louisville),
Meadowview Regional (Maysville), St Claire Medical Center (Morehead).

## Deck 2: Froedtert & Medical College of Wisconsin

### Slide 1 "Launch-to-Date Metrics" (data as of May 11, 2026 @ 9:00AM EST)
| Metric | LTD | Natl Avg | Q1 | Q2 | Q3 | Q4 |
|---|---|---|---|---|---|---|
| Patients Enrolled in IovanceCares | 8 | 23.3 | 1-5 | 5-13 | 13-31 | 31-119 |
| Patients Scheduled for TTP | 7 | 17.3 | 0-4 | 4-10 | 10-25 | 25-81 |
| TTPs Cancelled or Rescheduled | 0 | 4.6 | 5-40 | 2-5 | 1-2 | 0-1 |
| Patients with Completed TTP's | 7 | 17.1 | 0-4 | 4-10 | 10-25 | 25-81 |
| Patient Related Drop-outs due to patient health | 0 | 3.0 | 4-12 | 2-4 | 1-2 | 0-1 |
| Patients with OOS Product | 1 | 4.2 | 6-19 | 3-6 | 0-3 | 0-0 |
| Patient Progression Rate* | 0.0% | 8.5% | 10.83%-100% | 4.26%-10.83% | 0%-4.26% | 0%-0% |
| AMTAGVI Infusions performed | 6 | 9.7 | 0-2 | 2-4 | 4-13 | 13-55 |
| Average Time from Final Product Delivery Date to AMTAGVI Infusion (Days) | 13 | 10.3 | 12-19 | 10-12 | 8-10 | 2-8 |

### Slide 2 "Year over Year Metrics at ATC" (data as of April 11, 2026 @ 9AM EST)
Columns: Oct.'24-Jun.'25 | Jul.'25-Apr.'26 | Difference
| Metric | W1 | W2 | Diff |
|---|---|---|---|
| Enrollments in IovanceCares | 4 | 5 | +1 |
| Tumor Tissue Procurements (scheduled + completed) | 4 | 4 | - |
| Patient Related Drop-outs due to patient health (after TTP occurred) | 0 | 0 | - |
| Patients with OOS Product | 1 | 0 | -1 |
| AMTAGVI Infusions performed | 3 | 3 | - |
| Average Time from Enrollment to TTP Date (Days) | 33 | 29 | -4 |
| Average Time from TTP to Infusion (Days) | 55 | 52 | -3 |
| Average Time from Final Product Delivery Date to AMTAGVI Infusion (Days) | 14 | 13 | -1 |

Footnote: `Timing metrics in green boxes are based upon the TTP or Infusion Date`.

## Verification recipe (office laptop)
Set the dashboard date filter to a deck's exact windows and pick that center; numbers
should land close to the slide. Exact match is NOT expected unless the Infinity extract
is from the same as-of date (UK deck: May 5; Froedtert: Apr/May 11; our extract: Jul 21).
Orders added, cancelled, or reclassified between those dates move the counts.
