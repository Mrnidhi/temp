# PowerPoint Copilot — Slide-by-Slide Edit Instructions (v2: voice + final-slide rework)

> **How to use**: Open the deck in PowerPoint Online → click **Copilot** → go to the slide → paste the prompt.
>
> **Deck stays at 6 slides.** This pass does two things: (1) strips the "AI voice" out of the copy so it reads like consulting-grade business analysis, and (2) rebuilds Slide 6 from a flat menu into a real "what this means" closer.
>
> **Voice rules baked into every prompt below:** declarative, business-first, no em-dash-plus-explainer tics, no filler ("substantial portion", "points to opportunity", "underserved markets"), no hedging. Say the finding, then the "so what."
>
> **⚠️ Copilot-budget note:** Copilot edits are limited, and you barely need them. Slides 4 and 5 are **text-only** — do them by hand (click the text box, retype); this costs zero Copilot edits and avoids Copilot disturbing the chart/2×2 layout. The only edit worth Copilot is **Slide 6** (a real layout change), and even that can be done manually. Below, each prompt doubles as the exact final text to type by hand.

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
**Action: MANUAL text swap (recommended) — or Copilot. Rewrite the TEXT only; layout, numbers, colors all stay.**

> Do this by hand to save a Copilot edit and protect the 2×2 grid: click each text box and retype. Numbers (3,701 / 9,301 / 3,234 / 10) do not change. If you do use Copilot, the prompt below tells it to touch text only.

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
**Action: MANUAL text swap (recommended) — or Copilot. Rewrite the TEXT only; the bar chart stays untouched.**

> Do this by hand: retype the title, the three bullets, and the callout. The chart and values (50/49/43/42/40/26) do not change. Manual avoids any risk of Copilot disturbing the chart.

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

## Slide 6 — Additional analyses available on request (Kolin's appendix ask)
**Action: Copilot edit (worth the one edit here) — or manual. Replace the current strategy grid with the list below. Do not add a new slide.**

> This is the only slide where Copilot earns its cost — it's a real layout change (2×2 grid → two-column list). Manual alternative: delete the four boxes and the callout, then add one text box with the eight bullets below.

> This is exactly what Kolin asked for: a simple list of the other data cuts explored / available. Kept simple, but each line carries a real one-line finding (not a dry description) so it reads as "here's what else we found — ask us to go deeper," not a lifeless menu.

**Copilot prompt:**
```
Replace the contents of this slide (keep the deck template, section-label style, title style, and source line).

Section label: "APPENDIX"
Title: "Additional analyses available on request"

Lay out a simple two-column list of eight items. Each is a bold topic followed by a short plain-text finding on the same line:

• Satellite split: 53% of ATC patients are at satellite sites of an ATC parent, not the flagship campus
• Definition sensitivity: ATC share runs from 20% (strict NPI match) to 43% (parent level)
• Year-over-year ATC share: flat near 19% for three years, then up to 24% in 2024 and 2025
• Regional penetration: ATC reach spans 50% in the Southeast to 26% in the Central region
• Central coverage gap: Arkansas, South Dakota, and North Dakota have no authorized ATC at all
• Claims intensity: 6.7 vs 6.0 claims per patient at ATC versus non-ATC sites
• Migration journeys: individual patient traces showing the path from non-ATC into an ATC
• Diagnosis-to-treatment timing: about a 40-day median, similar across both settings

Keep it clean and scannable. No charts.

Source footnote: "Source: McKesson (Compile) medical claims (2021 to 2025)."
```

**Keep the strategic "so what" as your talking track, not a slide.** The referral-speed thesis I drafted is strong material, but it's a different slide than Kolin asked for. Use it as speaker notes / what you *say* when you land on this appendix — it makes the list feel like a springboard:
> "These aren't just extra cuts — they point one way. For a therapy only ATCs can deliver, the lever is referral speed, not first-line capture: the network already pulls patients in and holds them, it's inflecting since 2024, and where it's weak (Central) it's a coverage gap, not effort."

If Kolin wants that as its own slide later, we can add it then — but it stays out of the deck unless he asks.

---

# Final Deck Structure (6 slides)

| # | Section | Title | Status |
|---|---------|-------|--------|
| 1 | TITLE | …July 2026 | Manual month fix (outstanding) |
| 2 | METHODOLOGY | ATC is defined at the HCO parent level… | Done |
| 3 | MARKET STRUCTURE | A majority of patients are treated outside our ATCs | Leave (Kolin) + flag "grown steadily" |
| 4 | PATIENT JOURNEY | ATCs gain patients over the course of care… | Copilot: text-only rewrite |
| 5 | REGIONAL VIEW | Where a patient lives shapes whether they reach an ATC | Copilot: text-only rewrite |
| 6 | APPENDIX | Additional analyses available on request | Copilot: simple list, each line a real finding (Kolin's ask) |

---

# Data backing

- **S4 four buckets (query F):** 3,701 / 9,301 / 3,234 / 10 → Σ 16,246 ✓.
- **S6 appendix items** all trace to confirmed numbers: satellite 47/53 (B1); sensitivity 20↔43 (B3); yearly 19→24 with 2024 inflection (Insight 3); regional 50→26 (Insight 10); Central AR/SD/ND 0% (D1); claims 6.7 vs 6.0 (Insight 13); migration journeys (query E / Insight 8); dx-to-tx ~40d (Insight 11).
- **Strategic "so what" (talking track, not a slide):** access-not-quality (Insight 11 + 13), one-way referral engine (query F: 3,701 in / 10 out), 2024 inflection (Insight 3; coincides with Amtagvi's Feb-2024 approval — verify before asserting causation), structural Central gap (D1–D3). Optional supporting cuts if it ever becomes a slide: Insight 6b (referral lanes), Insight 5 (target list).

> **Source-of-truth note:** `git/NewCode.sql` is the canonical/showcase pipeline (13 insights). The `Snowflake/ATC Follow-ups…` file is a scratch/test script. All deck numbers should trace back to NewCode.sql insights: S3 table → Insight 1; S4 buckets → query F (a Slide-4 variant of Insight 8); S5 regional → Insight 10; S6 → Insights 5 + 7.
