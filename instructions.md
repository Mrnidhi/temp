# PowerPoint Copilot — Slide-by-Slide Edit Instructions

> **How to use**: Open the deck in PowerPoint Online → click **Copilot** → go to the slide → paste the prompt. Do them **in order** (Slides 5 and 6 are new).
>
> Current deck: **4 slides** → Target deck: **6 slides**
>
> **Authority for these changes:** Kolin's "Daily Connect (07/07)" recap email (Tue 2026-07-07) + Meet 10 detail. His three deck asks: (i) split the Methodology right-side bullets, (ii) split Patient Journey into two slides (journey + regional), (iii) add a slide listing the other data cuts explored. That takes the deck from 4 to 6 slides.

---

## Slide 1 — Title
**Action: Manual edit (no Copilot needed)**

- Change `June 2026` → `July 2026`. Nothing else.

---

## Slide 2 — Methodology Overview
**Action: Copilot edit — split the RIGHT column only**

> Kolin: "Split up bullet 1 & 2 as 'how ATCs are classified' & then last bullet mentions patient assignment." The top two bullets are about classifying the *centers*; the last is about assigning the *patients*.

**Copilot prompt:**
```
On the right side of this slide, split the three bullets under "How each patient is assigned" into two labelled groups, each with a bold sub-header. Keep the exact bullet wording.

Group 1 — bold sub-header: "How ATC centers are classified"
• Provider NPI is matched against the authorized ATC list first
• If there is no NPI match, the site is matched on HCO parent name, which is how satellites of an ATC parent are captured

Group 2 — bold sub-header: "How each patient is assigned"
• A patient seen at both ATC and non-ATC sites is counted once, at the site with the most claims

Keep the entire LEFT column ("What each site bucket includes") unchanged.
Keep the yellow callout box, the source footnote, the slide title, and the section label unchanged.
```

---

## Slide 3 — Market Structure (Table + Takeaways)
**Action: LEAVE AS-IS — no Copilot edit**

> Kolin is rewording the ATC-share-growth bullet himself ("let me play with that a little bit"). The source already reads "McKesson (Compile)" and the growth bullet already says "where patients began treatment." Nothing for us to do here.
>
> *(Optional, only if you personally want it: round the table to whole numbers — 42.7→43, 43.7→44, 8.1→8, 5.5→5. Not requested by Kolin; leave alone unless asked.)*

---

## Slide 4 — Patient Journey → Migration (EDIT existing slide)
**Action: Copilot edit — keep migration, remove the regional chart, add the 4-bucket graphic**

> Kolin (email ii + Meet 10): Slide 4 does two things at once. Keep the migration story here; move the regional chart to its own new slide. Replace the chart with the four start→end buckets ("the four kind of buckets… start and end").
> Numbers are confirmed from Snowflake query F (sum = 16,246; ended-ATC = 6,935).

**Copilot prompt:**
```
Redesign this slide to focus ONLY on patient migration between ATC and non-ATC sites. Remove the regional bar chart and the "26%" stat box — those move to a new separate slide.

Section label: "PATIENT JOURNEY"
Title: "Migration into ATCs is almost entirely one-directional"

Replace the stat boxes and bar chart with a clean 4-bucket start-to-end graphic (a 2x2 grid or simple flow). Use these exact figures:

| Journey | Patients | Share |
|---|---|---|
| Started non-ATC → moved to ATC | 3,701 | 23% |
| Started non-ATC → stayed non-ATC | 9,301 | 57% |
| Started ATC → stayed ATC | 3,234 | 20% |
| Started ATC → moved to non-ATC | 10 | 0.1% |

Visually emphasize the "3,701 — moved to ATC" bucket (it is over half of all ATC-classified patients) and the "10" bucket (once patients start at an ATC, almost none leave).

Keep "6.7 vs 6.0 claims per patient at ATC versus non-ATC sites" as a small supporting callout near the bottom.

Yellow callout: "Over half of ATC-classified patients began outside the ATC network — and once patients start at an ATC, they almost never leave."

Source footnote: "Source: McKesson (Compile) medical claims (2021 to 2025). Start = site of first treatment claim (NPI-confirmed); end = final ATC classification. Patients may have activity across both ATC and Non-ATC settings."

Use the same slide template, fonts, and color scheme as the rest of the deck.
```

---

## Slide 5 — Regional Penetration (NEW — insert after Slide 4)
**Action: Copilot — create a new slide (the chart from old Slide 4)**

> Kolin (email ii + Meet 10): break the regional chart onto its own slide with a header that ATC/non-ATC distribution "is vastly different depending on what region."

**Copilot prompt:**
```
Add a new slide after this one:

Section label: "REGIONAL VIEW"
Title: "ATC penetration varies vastly by region"

Main content: a vertical bar chart, "ATC penetration by region (% of Patients)", with a Y-axis label "% of Patients":
- Southeast: 50
- Northeast: 49
- Ohio Valley: 43
- West: 42
- Great Lakes: 40
- Central: 26

Use the same olive/dark-green bar color as the rest of the deck.

Bullets beside the chart:
• Southeast and Northeast lead at ~50% ATC penetration
• Central lags at 26% — a coverage gap (no authorized ATC in AR, SD, or ND)
• Regional variation points to opportunity in underserved markets

Yellow callout: "The share of patients treated at ATCs ranges from 50% in the Southeast to 26% in the Central region."

Source footnote: "Source: McKesson (Compile) medical claims (2021 to 2025). Regional shares based on hybrid classification. Patients may have activity across both ATC and Non-ATC settings."

Match the same slide template, fonts, and color scheme as the rest of the deck.
```

---

## Slide 6 — Additional Analyses Available (NEW — insert after Slide 5)
**Action: Copilot — create a simple list slide**

> Kolin (email iii + Meet 10): "add one simple slide… a simple list of just like a high level what we looked at… additional analysis available on request." Every item below is an analysis already run — no new work.

**Copilot prompt:**
```
Add a new slide:

Section label: "APPENDIX"
Title: "Additional analyses available on request"

A clean, scannable bulleted list with bold topic names (no charts):
• Satellite split — true ATC site vs satellite of an ATC parent (47% / 53%)
• Classification sensitivity — strict NPI-only floor vs parent-level definition (20% ↔ 43%)
• Year-over-year ATC share — starting-site share by year, 2021 to 2025 (19% → 24%)
• Regional penetration — ATC share by region
• Central region root cause — coverage-gap analysis by state
• Claims intensity — average claims per patient, ATC vs non-ATC (6.7 vs 6.0)
• Sample patient journeys — individual migration traces
• Diagnosis-to-treatment timing — median days from diagnosis to first treatment (~39–44 days)

Source footnote: "Source: McKesson (Compile) medical claims (2021 to 2025)."

Match the same slide template as the rest of the deck.
```

---

# Final Deck Structure

| # | Section | Title | Status |
|---|---------|-------|--------|
| 1 | TITLE | ATC vs Non-ATC Site of Care Analysis — July 2026 | Manual (month fix) |
| 2 | METHODOLOGY OVERVIEW | ATC is defined at the HCO parent level… | Copilot edit (split right side) |
| 3 | MARKET STRUCTURE | A majority of patients are treated outside our ATCs | **Leave as-is** (Kolin rewords) |
| 4 | PATIENT JOURNEY | Migration into ATCs is almost entirely one-directional | Copilot edit (4-bucket graphic, chart removed) |
| 5 | REGIONAL VIEW | ATC penetration varies vastly by region | **NEW** (chart from old Slide 4) |
| 6 | APPENDIX | Additional analyses available on request | **NEW** (simple list) |

---

# Data backing (Snowflake, confirmed)

- **4-bucket graphic (query F, Jul 8):** 3,234 / 10 / 3,701 / 9,301 → Σ 16,246 ✓; ended-ATC 6,935 ✓; started-ATC 3,244 = 20.0% ✓.
- **Table (Slide 3):** ATC 6,935 (42.7%) · Hospital 7,100 · Community 1,317 · Other 894 · Total 16,246.
- **Regional (Slide 5):** SE 50 · NE 49 · OHV 43 · West 42 · GL 40 · Central 26.
- **Appendix items** all correspond to queries already run (see `Memory/code_memory/atc_followups_runbook.md`).
