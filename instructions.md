# PowerPoint Copilot — Slide-by-Slide Edit Instructions

> **How to use**: Open your deck in PowerPoint Online → click **Copilot** → navigate to the slide → paste the prompt. Do them **in order** (some steps create new slides).
>
> Current deck: **4 slides**
> Target deck: **7 slides**

---

## Sources of Feedback (Cross-Referenced)

| Source | What was said |
|---|---|
| **Meet 7** (Tim team call) | Fix source label — said "Komodo" but it's McKesson claims via Komodo/Compile (line 368–370). Add year-over-year ATC share visual 19→24% (line 380–388). Add site hierarchy/characterization slide showing main campus vs satellite breakdown (line 530–546). Community network capture rate question — add caveat (line 430–432). |
| **Meet 8** (Kolin 1:1) | Left side = holistic total share, right side = where patients started — don't mix these two metrics (line 68–74). Add a third slide detailing what's in each bucket + how patients are characterized (line 74–86). |
| **Meet 10** (Kolin deep dive) | Split right side of Slide 2 into "how ATCs are classified" vs "patient assignment" (line 116–138). Wordsmith ATC share growth bullet — it's based on where patients *began* (line 148–162). Split Slide 4 into two: migration focus + regional chart (line 192–194). Add simple "additional analyses available" slide (line 174–188). Kolin said he'll wordsmith bullet himself (line 162). |
| **Kolin's PPT Comments** (visible on slides) | Slide 2: "Split bullet 1 & 2 as 'how ATCs are classified' or something similar & then last bullet mentions patient assignment." Slide 4: "Add one simple slide to list available insights examined." Slide 4: "Let's split existing slide 4 into two separate slides: one highlighting the non-ATC patients that moved into an ATC..." |

---

## ✅ Slide 1 — Title Slide
**Action: Manual edit (no Copilot needed)**

- Change `June 2026` → `July 2026`

---

## ✅ Slide 2 — Methodology Overview
**Action: Copilot edit**

> **Meet 10 + Kolin's PPT comment**: Split right-side bullets — top 2 are about classifying ATC *centers*, last bullet is about assigning *patients*.
> **Meet 8**: Make it clear what's in each bucket and how patients are pushed into them.

**Copilot prompt:**
```
On the right side of this slide, reorganize the three bullets into two visually separated sections with bold sub-headers:

Section 1 — Bold sub-header: "How ATC centers are identified"
• "Provider NPI is matched against the authorized ATC list first"
• "If there is no NPI match, the site is matched on HCO parent name, which is how satellites of an ATC parent are captured"

Section 2 — Bold sub-header: "How each patient is assigned"
• "A patient seen at both ATC and non-ATC sites is counted once, at the site with the most claims"

Keep the left side ("What each site bucket includes") completely unchanged.
Keep the yellow callout box and source footnote unchanged.
Do not change the slide title or section label.
```

---

## ✅ Slide 3 — Market Structure (Table + Key Takeaways)
**Action: Copilot edit**

> **Meet 7**: Kolin asked — is 19→24% shown visually or just a takeaway? (It's a takeaway.) Also: source said "Komodo" but data is McKesson claims. Check current source footnote.
> **Meet 8**: The left side is holistic total share; the third bullet about 19→24% is based on where patients *started* — don't mix these.
> **Meet 10**: Kolin will wordsmith the growth bullet himself, but clarify it's based on starting site.

**Copilot prompt:**
```
Make these edits to this slide:

BULLETS (right side):
1. Keep first bullet: "About 57% of patients are treated outside ATCs"
2. Keep second bullet: "Non-ATC volume is mostly independent or community sites, a long tail of many small accounts"
3. Replace the third bullet with: "Looking at where patients began their treatment, ATC share as a starting site has grown steadily — from 19% in 2021 to 24% in 2025 (see next slide)"

TABLE:
Round all percentages to whole numbers:
- 42.7% → 43%
- 43.7% → 44%
- 8.1% → 8%
- 5.5% → 5%
- Total stays at 100%

SOURCE FOOTNOTE:
Make sure the source footnote begins with "Source: McKesson (Compile) medical claims (2021 to 2025)." — If it says "Komodo" anywhere, change it to "McKesson (Compile)".

Do not change the slide title, section label, or yellow callout box.
```

---

## ✅ Slide 4 — Patient Journey / Migration (EDIT existing slide)
**Action: Copilot edit — strip out the regional chart, focus on migration only**

> **Meet 10 + Kolin's PPT comment**: Slide 4 is trying to do two things at once. Split it. Keep the migration story here, move the regional chart to its own slide. Show the 4-bucket patient journey table instead of the 3-box layout.
> **Meet 7**: 3,701 patients started non-ATC but got ATC exposure — this is the key story.

**Copilot prompt:**
```
Redesign this slide to focus ONLY on patient migration between ATC and non-ATC sites. Remove the regional bar chart and the "26%" stat box — those are moving to a new separate slide.

Section label: "PATIENT JOURNEY"
Title: Change to "Over half of ATC-classified patients started treatment at a non-ATC site"

Replace the three stat boxes and bar chart with a clean 4-bucket visual (use a 2x2 grid, table, or flow diagram):

| Journey | Description |
|---------|-------------|
| Started ATC → Stayed ATC | Patients who began at an ATC and remained there throughout treatment |
| Started Non-ATC → Migrated to ATC | 3,701 patients — began outside ATC network but later received care at an ATC. Over half of all ATC-classified patients. |
| Started ATC → Also seen at Non-ATC | Patients who began at an ATC but also had claims at non-ATC sites |
| Started Non-ATC → Stayed Non-ATC | Patients who never received care at an ATC |

Keep the "6.7 vs 6.0 claims per patient at ATC versus non-ATC sites" as a smaller supporting callout near the bottom.

Yellow callout: "A significant share of ATC volume comes from patients who were initially treated outside the ATC network"

Source footnote: "Source: McKesson (Compile) medical claims (2021 to 2025). Migration and claims-per-patient based on NPI-confirmed ATC sites. Patients may have treatment activity across both ATC and Non-ATC settings."

Use the same slide template and color scheme as the rest of the deck.
```

---

## ✅ NEW Slide 5 — Regional Penetration (INSERT after Slide 4)
**Action: Create a new slide**

> **Meet 10**: Break out the regional chart into its own slide with a header calling out that ATC/non-ATC distribution varies widely by region.
> **Meet 7**: Central region at 26% — big gap vs Southeast/Northeast at ~50%.

**Copilot prompt:**
```
Add a new slide after the current slide with:

Section label: "REGIONAL VIEW"
Title: "ATC penetration varies significantly by region"

Main content: A horizontal or vertical bar chart showing ATC penetration by region (% of Patients):
- Southeast: 50%
- Northeast: 49%
- Ohio Valley: 43%
- West: 42%
- Great Lakes: 40%
- Central: 26%

Use the same olive/dark-green color as the bars on other slides in this deck. Add a Y-axis label: "% of Patients"

Bullets on the right side of the chart:
• "Southeast and Northeast lead with ~50% ATC penetration"
• "Central region significantly lower at 26%, suggesting fewer available ATC centers"
• "Regional variation points to potential opportunity in underserved markets"

Yellow callout at bottom: "The share of patients treated at ATCs varies widely by region — from 50% in the Southeast to 26% in the Central"

Source footnote: "Source: McKesson (Compile) medical claims (2021 to 2025). Regional shares based on hybrid classification. Patients may have treatment activity across both ATC and Non-ATC settings."

Match the same slide template, fonts, and color scheme as the rest of this deck.
```

---

## ✅ NEW Slide 6 — Additional Analyses Available (INSERT after Regional slide)
**Action: Create a new slide**

> **Meet 10 + Kolin's PPT comment**: "Add one simple slide to list available insights examined." Keep it simple — just a bulleted list of what was analyzed.

**Copilot prompt:**
```
Add a new slide with:

Section label: "APPENDIX"
Title: "Additional analyses available on request"

Body — a clean, simple bulleted list with bold topic names:
• Migration patterns — Detailed patient flow between ATC and non-ATC sites by year
• Classification confidence — Breakdown of ATC patients by NPI-confirmed (front door) vs parent-name match (back door/satellite)
• Community network share — Patient volume within organized oncology networks (US Oncology, One Oncology, American Oncology)
• Claims intensity — Average claims per patient at ATC vs non-ATC sites
• Drug mix — ATC share split by treatment product (Yervoy vs Opdualag)
• Diagnosis-to-treatment delay — Median time from diagnosis to first treatment, by site type
• Non-ATC concentration — How patient volume is distributed across non-ATC hospital systems
• Year-over-year ATC share trend — Annual starting-site ATC share from 2021 to 2025 (19% → 24%)

No charts or visuals needed — just the list. Keep it clean and scannable.

Source footnote: "Source: McKesson (Compile) medical claims (2021 to 2025)."

Match the same slide template as the rest of the deck.
```

---

## ✅ Slide 7 — Closing Slide (OPTIONAL)
**Action: Create if desired**

**Copilot prompt:**
```
Add a closing slide that matches the style of Slide 1 (title slide). Show the Iovance Biotherapeutics logo centered, and "Confidential for Internal Use Only" at the bottom. No other text needed.
```

---

# Final Deck Structure

| # | Section | Title | Status |
|---|---------|-------|--------|
| 1 | TITLE | ATC vs Non-ATC Site of Care Analysis — July 2026 | Manual fix (month) |
| 2 | METHODOLOGY OVERVIEW | ATC is defined at the HCO parent level... | Copilot edit (split right side) |
| 3 | MARKET STRUCTURE | A majority of metastatic melanoma patients... | Copilot edit (round %, fix source, clarify bullet) |
| 4 | PATIENT JOURNEY | Over half of ATC patients started at non-ATC | Copilot edit (4-bucket migration visual) |
| 5 | REGIONAL VIEW | ATC penetration varies significantly by region | **NEW** (chart from old Slide 4) |
| 6 | APPENDIX | Additional analyses available on request | **NEW** (simple list) |
| 7 | CLOSING | *(optional)* | **NEW** |

---

# All Feedback — Resolution Map

| Feedback | Source | Resolved In |
|----------|-------|-------------|
| Fix source: "Komodo" → "McKesson (Compile)" | Meet 7 (line 368) | Slide 3 source footnote |
| 19→24% is a takeaway, not a visual — clarify it's about starting site | Meet 7 (line 380), Meet 8 (line 72), Meet 10 (line 154) | Slide 3 bullet 3 |
| Left side = total share, right side = where started — don't mix | Meet 8 (line 68–74) | Slide 3 bullet 3 wording |
| Add slide for what's in each bucket + how patients are classified | Meet 8 (line 74–86) | Already exists as Slide 2 (Kolin added it) |
| Split Slide 2 right side: "how ATCs are classified" + "patient assignment" | Meet 10 (line 116–138), Kolin PPT comment | Slide 2 edit |
| Split Slide 4: migration + regional on separate slides | Meet 10 (line 192–194), Kolin PPT comment | Slide 4 edit + New Slide 5 |
| Show 4-bucket patient journey (started ATC/stayed, started non-ATC/migrated, etc.) | Meet 10 (line 194) | Slide 4 edit |
| Add "additional analyses available" slide | Meet 10 (line 174–186), Kolin PPT comment | New Slide 6 |
| Round decimals on table | Previous session notes | Slide 3 table |
| Add Y-axis label "% of Patients" to regional chart | Previous session notes | New Slide 5 |
| Main campus vs satellite breakdown slide | Meet 7 (line 530–546) | Listed in Slide 6 appendix as "Classification confidence" — full slide is a future task |
| Site hierarchy/characterization slide | Meet 7 (line 544–546) | Listed in Slide 6 appendix — full slide is a future task |
| Kolin to wordsmith growth bullet himself | Meet 10 (line 162) | Slide 3 — we've clarified the wording, Kolin may tweak further |

---

# 🎯 All-In-One Master Prompt (if Copilot allows full-deck edit)

If PowerPoint Copilot ever supports editing the whole deck at once, here's the consolidated prompt:

```
I need to make the following changes to this presentation:

SLIDE 1 (Title): Change "June 2026" to "July 2026". No other changes.

SLIDE 2 (Methodology Overview): On the right side, split the 3 bullets into two sections. Add bold sub-header "How ATC centers are identified" above bullets 1-2 (NPI matching and parent name matching). Add bold sub-header "How each patient is assigned" above bullet 3 (counted once at most claims). Keep left side unchanged.

SLIDE 3 (Market Structure): Round table percentages to whole numbers (43%, 44%, 8%, 5%, 100%). Update third bullet to: "Looking at where patients began their treatment, ATC share as a starting site has grown steadily — from 19% in 2021 to 24% in 2025 (see next slide)". Ensure source footnote says "McKesson (Compile)" not "Komodo".

SLIDE 4 (Patient Journey): Remove the regional bar chart and "26%" box. Change title to "Over half of ATC-classified patients started treatment at a non-ATC site". Replace with a 4-bucket visual showing: (1) Started ATC → Stayed ATC, (2) Started Non-ATC → Migrated to ATC (3,701 patients, over half of ATC-classified), (3) Started ATC → Also seen at Non-ATC, (4) Started Non-ATC → Stayed Non-ATC. Keep "6.7 vs 6.0 claims" as supporting detail. Update callout to: "A significant share of ATC volume comes from patients initially treated outside the ATC network".

NEW SLIDE 5 (after Slide 4): "REGIONAL VIEW" — "ATC penetration varies significantly by region". Bar chart with Southeast 50%, Northeast 49%, Ohio Valley 43%, West 42%, Great Lakes 40%, Central 26%. Add Y-axis label "% of Patients". Bullets: Southeast/Northeast ~50%, Central at 26% with fewer ATC centers, regional variation = opportunity.

NEW SLIDE 6: "APPENDIX" — "Additional analyses available on request". Simple bulleted list: Migration patterns, Classification confidence (NPI vs parent match), Community network share, Claims intensity, Drug mix (Yervoy vs Opdualag), Diagnosis-to-treatment delay, Non-ATC concentration, Year-over-year ATC share trend.

Match all new slides to the existing deck template, fonts, and Iovance color scheme.
```
