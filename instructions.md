# PowerPoint Copilot — Slide-by-Slide Edit Instructions (v2: voice + final-slide rework)

> **How to use**: Open the deck in PowerPoint Online → click **Copilot** → go to the slide → paste the prompt.
>
> **Deck stays at 6 slides.** This pass does two things: (1) strips the "AI voice" out of the copy so it reads like consulting-grade business analysis, and (2) rebuilds Slide 6 from a flat menu into a real "what this means" closer.
>
> **Voice rules baked into every prompt below:** declarative, business-first, no em-dash-plus-explainer tics, no filler ("substantial portion", "points to opportunity", "underserved markets"), no hedging. Say the finding, then the "so what."

---

## Slide 1 — Title
**Action: Manual edit — still outstanding**

- Change `June 2026` → `July 2026`. (This never got made; it's the one mechanical fix left.)

---

## Slide 2 — Methodology Overview
**Action: Done — leave as-is (optional polish only)**

The right-column split ("How ATC centers are classified" / "How each patient is assigned") is already applied correctly. Copy is clean and factual. Only optional tweak, if you want it: vertically center the two columns so the big empty band at the bottom closes up. No wording change needed.

---

## Slide 3 — Market Structure
**Action: Leave for Kolin — but flag one accuracy issue to him**

Kolin is rewording the growth bullet himself, so don't overwrite. But raise this with him: the yellow callout says *"ATC share has grown steadily each year,"* which the yearly data contradicts — it was **flat 2021–2023 (19.0 / 18.9 / 19.1) then jumped in 2024–2025 (22.0 / 23.9).** It didn't grow steadily; it inflected recently. Suggested honest replacement (his call):

> "Most metastatic melanoma treatment still happens outside our ATCs, but ATC share has climbed sharply since 2024."

---

## Slide 4 — Patient Journey
**Action: Copilot edit — rewrite the TEXT only, keep the 2×2 layout, numbers, and colors**

> The graphic is great; only the wording needs de-robotizing. Do NOT move boxes, change numbers, or restyle — only replace the text strings below.

**Copilot prompt:**
```
On this slide, keep the 2x2 grid, all four numbers (3,701 / 9,301 / 3,234 / 10), the percentages, the colors, and the box positions exactly as they are. Only replace the wording, as follows.

Title: "ATCs gain patients over the course of care, and almost never lose them"

Box wording (match by number):
• 3,701 (23% of all patients): "Began outside the ATC network, then treated at an ATC. More than half of today's ATC patients arrived this way."
• 9,301 (57% of all patients): "Treated entirely outside the ATC network."
• 3,234 (20% of all patients): "Began and stayed at an ATC."
• 10 (0.1% of all patients): "Began at an ATC, then left. Almost no one does."

Keep the "6.7 vs 6.0 claims per patient at ATC versus non-ATC sites" line as-is.

Bottom callout, replace with: "More than half of our ATC patients started somewhere else, and once patients reach an ATC they rarely leave. The network grows by pulling patients in over the course of their care."

Leave the source footnote unchanged.
```

---

## Slide 5 — Regional View
**Action: Copilot edit — rewrite the TEXT only, keep the bar chart untouched**

**Copilot prompt:**
```
On this slide, keep the bar chart, the six regions, the values (50/49/43/42/40/26), the axis, and the colors exactly as they are. Only replace the wording.

Title: "Where a patient lives shapes whether they reach an ATC"

Replace the three bullets with:
• In the Southeast and Northeast, about half of patients reach an ATC.
• The Central region sits at just 26%, held down by states with no authorized ATC at all: Arkansas, South Dakota, and North Dakota.
• This is a coverage gap, not a demand gap: patients in these states are being treated, they just aren't reaching an ATC.

Bottom callout, replace with: "A patient's region drives their odds of reaching an ATC, from 50% in the Southeast down to 26% in the Central."

Leave the source footnote unchanged.
```

---

## Slide 6 — What this means (REBUILD: from appendix menu → the strategic close)
**Action: Copilot edit — replace the contents of the existing Slide 6 (do not add a new slide)**

> This is the payoff slide, and it carries the deck's argument: because Amtagvi (TIL) can only be delivered at an ATC, the whole analysis is about therapy *reach*, not market share. The four takeaways ladder into one thesis — reach patients faster, and fix the places we can't reach them at all. **All four are backed by data already in hand; no new query needed.**

**Copilot prompt:**
```
Replace the contents of this slide (keep the deck template, section-label style, title style, and source line).

Section label: "WHAT THIS MEANS"
Title: "The lever is referral speed, not first-line capture"

Lay out four numbered takeaways, each a bold one-line headline followed by one or two supporting sentences:

1. The gap is about access, not quality.
   Patients treated outside our ATCs reach treatment about as fast (roughly 40 days from diagnosis) and get comparable treatment volume (6.0 vs 6.7 claims per patient). They are not getting worse care. They are in settings that cannot offer a therapy only ATCs deliver.

2. The referral engine already works, and it runs one way.
   More than half of today's ATC patients (3,701) arrived from outside the network, and almost none leave (10). We do not need to win patients at diagnosis. We need to shorten the path in. Every month earlier is a month more of eligibility.

3. The trend has turned in our favor.
   ATC share held flat near 19% for three years, then climbed to 24% across 2024 and 2025. The pull into ATCs is accelerating. The question is how much faster we can make it.

4. Where we are weak, the cause is structural.
   The Central region sits at 26% because Arkansas, South Dakota, and North Dakota have no authorized ATC at all, and one system (Texas Oncology) holds 28% of the region's off-ATC patients. That is a build-or-partner decision with a specific target, not a sales-effort problem.

Bottom callout: "For a therapy only ATCs can deliver, the commercial lever is the speed of referral into the network, and coverage where it does not yet reach."

Source footnote: "Source: McKesson (Compile) medical claims (2021 to 2025). Analysis by Iovance Sales Operations."
```

**Optional depth (only if you want it):** takeaway 2 can name real referral lanes from **Insight 6b** (which non-ATC systems feed which ATCs); takeaway 4 can add a target list from **Insight 5** (top non-ATC accounts + `CUM_PCT_OF_LEAKAGE`). Both are already in `git/NewCode.sql`. The slide stands on its own at four; add these only if Kolin wants the extra specificity.

---

# Final Deck Structure (6 slides)

| # | Section | Title | Status |
|---|---------|-------|--------|
| 1 | TITLE | …July 2026 | Manual month fix (outstanding) |
| 2 | METHODOLOGY | ATC is defined at the HCO parent level… | Done |
| 3 | MARKET STRUCTURE | A majority of patients are treated outside our ATCs | Leave (Kolin) + flag "grown steadily" |
| 4 | PATIENT JOURNEY | ATCs gain patients over the course of care… | Copilot: text-only rewrite |
| 5 | REGIONAL VIEW | Where a patient lives shapes whether they reach an ATC | Copilot: text-only rewrite |
| 6 | WHAT THIS MEANS | The lever is referral speed, not first-line capture | Copilot: full rebuild (all data in hand) |

---

# Data backing

- **S4 four buckets (query F):** 3,701 / 9,301 / 3,234 / 10 → Σ 16,246 ✓.
- **S6 #1 (access not quality):** dx-to-treatment ~39–44 days both settings (Insight 11); 6.0 vs 6.7 claims/patient (Insight 13). Therapy-only-at-ATC is the premise of NewCode.sql.
- **S6 #2 (one-way referral engine):** 3,701 migrate in / 10 leave (query F). Optional named lanes = Insight 6b.
- **S6 #3 (trend inflected):** yearly 19.0 / 18.9 / 19.1 / 22.0 / 23.9 (Insight 3). NB: the 2024 inflection coincides with Amtagvi's Feb-2024 approval — plausible driver, verify before asserting causation.
- **S6 #4 (structural gap):** Central 26%; AR/SD/ND 0% ATC; Texas Oncology PA = 28.3% of Central off-ATC (D1–D3). Optional target list = Insight 5.

> **Source-of-truth note:** `git/NewCode.sql` is the canonical/showcase pipeline (13 insights). The `Snowflake/ATC Follow-ups…` file is a scratch/test script. All deck numbers should trace back to NewCode.sql insights: S3 table → Insight 1; S4 buckets → query F (a Slide-4 variant of Insight 8); S5 regional → Insight 10; S6 → Insights 5 + 7.
