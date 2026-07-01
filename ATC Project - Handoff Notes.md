# ATC vs Non-ATC Site of Care — Project Handoff

A complete brief so this can be picked up in a fresh session. Covers the business
ask, the data, the query, every decision made, what's open, and the next steps.

---

## 1. The business problem

The board (via Tim, through manager Kolin Knott / "KK") wants to understand **site of
care** for metastatic melanoma patients on our drugs.

Of patients **diagnosed with metastatic melanoma AND treated** with one of our drugs,
**what % are treated at an ATC vs a non-ATC center** — and for non-ATC, what kind of site:

- ATC
- Non-ATC: Hospital-affiliated
- Non-ATC: Physician-owned (e.g. Florida Cancer, Texas Oncology)
- Non-ATC: Stand-alone private practice

Final deliverable: a **pie chart** on a slide titled "Add site of care: ATC vs non-ATC."

---

## 2. The data

**Claims table (source of truth used):**
`COMPILE_CLAIMS.OPEN_CLAIMS.IOV2501_MEDICAL_CLAIMS`
- `D_PATIENT_ID` (filter out `'XXX - HIDDEN'`)
- `D_DIAGNOSIS_CODE_ALL` (combined diagnosis-code field)
- `DATE_OF_SERVICE`
- `D_NDC_CODE`, `D_PROCEDURE_CODE`
- `D_PRIMARY_HCO_COMPILE_ID`, `D_HCO_PARENT_COMPILE_ID`
- `PRIMARY_HCO_NPI_NAME`, `D_PRIMARY_HCO_NPI`, `HCO_PARENT_NAME`, `PRIMARY_HCO_NPI_STATE`

**HCO attributes table:**
`COMPILE_PROVIDER360.ENTITIES.IOV2501_HCO_ATTRIBUTES`
- Join key is `D_HCO_COMPILE_ID` (NOT `HCO_COMPILE_ID` — that was a transcription error
  in KK's older files).
- `HCO_TYPE` values seen: HOSPITALS, CLINIC, PHYSICIAN GROUP, OUTPATIENT CENTER, ASC,
  RESIDENTIAL, LABORATORIES, SUPPLIERS, PHARMACY, INSURANCE, OTHER SERVICE PROVIDERS.

**ATC list — this CSV is the ONLY ATC source available (KK confirmed there is no better one):**
`Sales Team - Rosters, ZTT & Alignments (CTAM ATC Alignment_ACTIVE_2026).csv`
- 112 rows, 4 preamble rows before the header (header on row 5).
- Columns: ATC Name (IovanceCares), NPI, ATC Name (Veeva Activity),
  **ATC HCO Parent Name (McKesson Claims)**, ATC Name (short/abbreviated), Status,
  Authorization Date, City, State, Zip, County, CTAM Territory, CTAM ID, CTAM Name,
  RAD ID, RAD Region.
- Status values: **Authorized / Planned / ON HOLD**.
- **No HCO compile ID and no clean ID** in the file. Only NPI (30 rows = 0/missing) and names.
  => ATCs must be matched on **parent name**, not an ID.
- Known gaps: parent name blank/dash in 25 rows; NPI missing in 30 rows.

---

## 3. Decisions made

- **Drug universe = Field** (Yervoy + Opdualag only).
  - NDC: `00003232711`, `00003232822` (Yervoy), `00003712511` (Opdualag)
  - J:   `J9228` (Yervoy), `J9298` (Opdualag)
- **Counting = primary center.** Each patient assigned to ONE center — where they had the
  most treatment claims (latest service date breaks ties). Prevents double-counting a patient
  treated at two centers; makes the split sum to 100%.
- **Time window = 2021–2025.**
- **Claims source = OPEN_CLAIMS for now** (combined open+closed left as an open item).
- **ATC status = Authorized only** (confirm whether ON HOLD is also excluded — assume yes).
- **ATC match = parent name** (forced by the file having no compile ID; also matches how
  the board/KK think about ATCs — network/parent level). The ATC file's
  `ATC HCO Parent Name (McKesson Claims)` joins to claims `HCO_PARENT_NAME`.

---

## 4. Bug found and fixed (flag to KK)

KK's existing queries filter diagnosis with `'%IC43%'` — that returns **ZERO** patients.
Codes are stored as plain ICD-10 (`C43`, `C77`, `C78`, `C79`), no leading I. With the
correct `'%C43%'` the diagnosed population is ~105,436 patients. **KK's other files likely
have the same bug and may be under-returning.**

---

## 5. How the query works (plain English, for explaining to KK)

1. DIAGNOSED_PATIENTS — metastatic melanoma (C43 + one of C77/C78/C79), 2021-2025.
2. TREATED_PATIENTS — claims for Yervoy/Opdualag (NDC or J-code), with center + date.
3. PATIENT_HCO — per patient+center, count treatment claims and note latest date.
4. PATIENT_SITE — pick the ONE center per patient with the most claims (the new piece that
   stops double-counting a patient treated at two centers).
5. ATC_LIST — Authorized ATC parent names from the loaded CSV.
6. Final SELECT — label each patient's center (ATC / non-ATC type) and report the % split.

Improvement over KK's version: his counts distinct patients *within* each center, which
double-counts anyone treated at two different centers. This pins each patient to a single
primary center, so percentages are clean and total 100%.

---

## 6. The workflow on the laptop (do these in order)

**Step 1 — Load the CSV into Snowflake as a table** (your workspace, e.g. COMPILE_DEV.PUBLIC):
- Skip the 4 preamble rows; header is row 5.
- Load NPI and Zip as VARCHAR/TEXT (leading zeros; NPI=0 = missing).
- Suggested table name: `CTAM_ATC_ALIGNMENT_2026`.
- The SQL file references `COMPILE_DEV.PUBLIC.CTAM_ATC_ALIGNMENT_2026` in THREE places
  (ATC_LIST, Check A, Check B) — update all three to your actual table name.

**Step 2 — Run CHECK B** (in the SQL file): how many Authorized ATCs have no usable parent
name. Note that number — it's a known undercount to report to KK (limit of the file, not the query).

**Step 3 — Run CHECK A**: which Authorized ATC parent names don't match any claims
`HCO_PARENT_NAME`. This is your fix-list — usually a handful of names with spelling/punctuation
differences. Tidy them (in the loaded table or via a small mapping) so they match.

**Step 4 — Run the main split query.** Sanity checks:
- Total patient count reasonable vs ~105K diagnosed?
- Known ATC parents land as ATC? A non-ATC physician group (e.g. Texas Oncology if not an ATC)
  lands as Physician-owned?

**Step 5 — Confirm bucket definitions with KK** (see section 7), adjust the CASE if needed.

**Step 6 — Build the pie chart** for the slide once numbers are final.

---

## 7. Open questions for KK

1. **Match approach** — the ATC file has no compile ID, so matching on parent name
   (`ATC HCO Parent Name (McKesson Claims)` -> claims `HCO_PARENT_NAME`). Confirm that's fine.
2. **Match level = parent** — all sites under an ATC parent count as ATC. Confirm that's intended.
3. **Status** — Authorized only? Exclude ON HOLD too (assume yes)?
4. **Non-ATC buckets** — confirm the HCO_TYPE -> bucket mapping
   (HOSPITALS = Hospital-affiliated, PHYSICIAN GROUP = Physician-owned, else = Private practice).
   Note the ELSE currently also sweeps clinics/outpatient/ASC and non-care types (labs,
   pharmacies) into "Private practice" — worth eyeballing.
5. **Undercount** — report the Check B number (Authorized ATCs with no parent name, can't match).
6. **(Lower priority) Claims source** — OPEN_CLAIMS vs combined open+closed.
7. **`%IC43%` bug** — flag it; correct is `%C43%`.

---

## 8. Known limitations to state honestly (not flaws in the work)

- The ATC list has no ID, so matching is by name — a few centers may miss and need manual
  name cleanup (Check A handles this).
- Authorized ATCs with blank parent names can't be matched and fall into non-ATC, slightly
  understating ATC share (Check B quantifies this).
- Bucket mapping is a first pass pending KK's confirmation.
- These are limits of the only available source file; naming them up front is the right move.

---

## 9. The SQL

See the companion file: `Diagnosised & Treated Patients - Site of Care Split.sql`.
It contains the main split query plus CHECK A (unmatched names) and CHECK B (blank-parent
count). Update the loaded-table name in all three spots before running.




-----------------

Good approach. One-shot prompts mean they have to be complete and unambiguous, no room for the tool to guess. Let me think about what kills these prompts: vague layout, missing exact numbers, no styling direction, and leaving the tool to invent data. I'll lock all of that down. I'm writing them so the numbers, positions, and text are fully specified, and matching the Iovance template you already have (navy and lime green, that visual identity).
One thing I'm deliberately building in: explicit instruction not to invent or add anything, because that's the single biggest failure mode with slide generators, they pad with plausible-sounding extra stats. Your numbers are validated; a hallucinated one would undo all the work.
Here are the two prompts.

PROMPT — SLIDE 1
Create a single professional corporate slide for a pharmaceutical leadership presentation. Use a clean navy-blue and lime-green color scheme (corporate biotech style). Do not invent, add, or modify any numbers beyond exactly what I provide.

TITLE (top left, bold, dark navy):
Non-ATC Settings Drive the Majority of Patient Care

KICKER above title (small, lime-green caps): MARKET STRUCTURE

LEFT HALF — a clean 3-column table titled "Site of Care | Patients | %":
ATC | 7,584 | 46.7%
Non-ATC: Hospital-affiliated | 5,488 | 33.8%
Non-ATC: Physician-owned | 2,012 | 12.4%
Non-ATC: Private practice | 1,295 | 8.0%
Use alternating row shading. Bold the ATC row.

RIGHT HALF — three short bullet points:
- ~53% of patients are treated outside ATCs
- Hospital-affiliated systems drive the largest share of non-ATC care
- Non-ATC volume is concentrated in a few large systems with a long tail

BOTTOM — one full-width takeaway bar (lime-green tint) with bold text:
Most patients are treated outside ATCs, with no consistent pathway routing them into ATC care.

FOOTNOTE (small grey text, bottom edge):
Source: Komodo medical claims, 2021–2025. Metastatic melanoma patients treated with Yervoy or Opdualag. ATC classified by authorized provider NPI.

Keep it minimal, lots of white space, one slide only, 16:9. No charts, no extra commentary, no added statistics.

PROMPT — SLIDE 2
Create a single professional corporate slide for a pharmaceutical leadership presentation, matching the same navy-blue and lime-green corporate biotech style as the previous slide. Do not invent, add, or modify any numbers beyond exactly what I provide.

TITLE (top left, bold, dark navy):
ATCs Deliver Higher Treatment Intensity but Remain Underutilized

KICKER above title (small, lime-green caps): ATC UTILIZATION

LEFT HALF — a clean comparison table with columns "Metric | ATC | Non-ATC":
Patients | 7,584 | 8,662
% Patients | 46.7% | 53.3%
Total Claims | 50,778 | 51,933
Avg Claims per Patient | 6.7 | 6.0
Use alternating row shading. Bold the "Avg Claims per Patient" row.

RIGHT HALF — four short bullet points:
- ATC patients receive higher treatment intensity (6.7 vs 6.0 claims per patient)
- ATCs deliver similar total treatment volume despite fewer patients
- Some patients receive care at both ATC and non-ATC sites, pointing to referral activity
- Non-ATC volume concentrates in a few large systems and community networks, creating targeted expansion opportunities

BOTTOM — one full-width takeaway bar (lime-green tint) with bold text:
ATCs are the highest-value treatment setting but remain underutilized, with clear opportunity to improve referral pathways and expand access.

Keep it minimal, lots of white space, one slide only, 16:9. No charts, no extra commentary, no added statistics.




-------------------------------------------------------------------------------------------------------

Prompt for Slide 1:
Create one slide, 16:9 widescreen, white background. Do not add any content beyond what I specify. Do not invent numbers.

Top bar: a dark navy rectangle (hex 16394F) spanning the full width, about 0.6 inches tall, flush to the top. Inside it on the left, the text "IOVANCE" in bold white followed by "BIOTHERAPEUTICS" in smaller lime-green (hex B4C424). On the right side of the same bar, the text "SITE OF CARE ANALYSIS" in lime-green, small, letter-spaced.

Below the bar, left aligned: a small olive-green (hex 7A9A1E) all-caps label "MARKET STRUCTURE". Under it, a bold navy (16394F) title in a serif font: "Most metastatic melanoma patients are still treated outside Authorized Treatment Centers, but ATC share is rising".

Left half, a table with a navy (16394F) header row with white text, columns "Site of care", "Patients", "%". Rows exactly:
ATC | 6,935 | 42.7%   (shade this row light green, hex EEF2E0, and bold it)
Non-ATC: Hospital | 7,100 | 43.7%
Non-ATC: Community network | 1,317 | 8.1%
Non-ATC: Other | 894 | 5.5%
Total | 16,246 | 100%   (bold this row)

Right half, three stacked stat callouts, each a big bold number with a small caption under it:
1. "57.3%" in navy, caption "of patients treated outside ATCs"
2. "19% to 24%" in olive-green, caption "ATC share rising, 2021 to 2025"
3. "85.7%" in navy, caption "of non-ATC volume is independent or community, a long tail of accounts"

Near the bottom, a full-width light-green (EEF2E0) band with a thin lime (B4C424) border containing: bold "Bottom line:" then "The majority of treatment happens outside ATCs today, but ATC share is growing every year and non-ATC care is fragmented across many small accounts."

Very bottom, a thin lime-green (B4C424) footer bar with navy text "ADVANCING IMMUNO-ONCOLOGY" on the left and the page number "1" on the right.

Just above the footer, tiny gray source text: "Source: Komodo medical claims, 2021 to 2025. Metastatic melanoma patients treated with Yervoy or Opdualag. ATC classified by authorized provider NPI and parent name. Percentages may not sum to 100 due to rounding."

Use Calibri for body text and a serif like Cambria for the title. Keep it clean and flat, no gradients or shadows.
Prompt for Slide 2:
Create one slide, 16:9 widescreen, white background. Do not add any content beyond what I specify. Do not invent numbers.

Top bar: a dark navy rectangle (hex 16394F) spanning the full width, about 0.6 inches tall, flush to the top. Inside it on the left, "IOVANCE" in bold white followed by "BIOTHERAPEUTICS" in smaller lime-green (hex B4C424). On the right, "THE OPPORTUNITY" in lime-green, small, letter-spaced.

Below the bar, left aligned: a small olive-green (hex 7A9A1E) all-caps label "REFERRAL AND UTILIZATION". Under it, a bold navy (16394F) serif title: "ATCs grow by pulling patients in from the community and deliver more treatment once they arrive".

A row of three equal rounded cards, each filled light green (hex EEF2E0), each with a big bold number and a caption below:
Card 1: "3,701" in navy, caption "ATC patients started in the community and migrated in, over half of all ATC patients".
Card 2: "6.7 vs 6.0" in olive-green, caption "claims per patient, ATC versus non-ATC. Patients get more treatment at ATCs".
Card 3: "26%" in navy, caption "ATC share in Central region versus about 48% in Northeast and Southeast, clear white space".

Below the cards, a small bold navy heading "ATC penetration by region", then a column bar chart with these exact bars and values, in this order:
Southeast 49.9, Northeast 48.9, Ohio Valley 43.3, West 42.3, Great Lakes 40.3, Central 26.1.
Color the Southeast and Northeast bars olive-green (7A9A1E), the Ohio Valley, West, and Great Lakes bars navy (16394F), and the Central bar red (C0392B). Show the value on top of each bar. Hide the vertical axis and gridlines.

Near the bottom, a full-width light-green (EEF2E0) band with a thin lime (B4C424) border containing: bold "Recommendation:" then "Prioritize referral pathways from community sites into ATCs, and target under-penetrated regions such as Central, rather than treating community and ATC as separate patient pools."

Very bottom, a thin lime-green (B4C424) footer bar with navy text "ADVANCING IMMUNO-ONCOLOGY" on the left and page number "2" on the right.

Just above the footer, tiny gray source text: "Source: Komodo medical claims, 2021 to 2025. Migration and claims-per-patient based on NPI-confirmed ATC sites. Regional shares based on hybrid classification."

Use Calibri for body text and a serif like Cambria for the title. Keep it clean and flat, no gradients or shadows.