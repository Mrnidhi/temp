# MASTER HANDOFF, Full Project Detail

Written 2026-07-15 for the office laptop agent. That machine cannot reach this Mac's files
(separate network, no transfer), so every number, spec, and decision needed to work is
written out inline below. Read this top to bottom.

There are two workstreams. The active one right now is the **Enrollment Contest pitch deck**.
The **Site of Care deck** is a second, near-finished piece with a few review comments open.

---

# 0. HOW TO WORK (constraints and tone)

- The office laptop is a separate, secured machine. You run SQL (Snowflake and Infinity)
  and edit PowerPoint and Excel there. You cannot receive files from the Mac, so anything
  the Mac built is a reference to be rebuilt, not transferred.
- The user takes phone photos of results and drops them into folders for review.
- Microsoft Copilot inside PowerPoint edits one slide at a time and is weak at precise
  charts. Expect to finish chart styling by hand.
- Tone rules for anything on a slide: plain and clear, corporate but easy for anyone to
  follow, aimed at about a 7 out of 10 reading level. No em-dashes, no semicolons, no arrows
  or math symbols, no jargon words like pull-through, overlay, or gamify. Every point should
  tell a small story, not just state a number. Keep chat short, the user has asked for that.
- The full sentences we wrote are the SPEAKER SCRIPT (talk track). The SLIDE text itself
  should be lean. Put the story in the notes, keep the slide tight.

---

# 1. THE ENROLLMENT CONTEST (active workstream)

## 1.1 What it is and why
A short sales contest for August and September 2026 that rewards growth in new patient
enrollments. Purpose, all confirmed from meeting transcripts:
- Infusion capacity grew from **50 to 70 treatment slots a month** for the second half.
- Weekly enrollments slipped from about **27 at launch to about 21**, and the forecast wants **25 or more**.
- The funnel leaks: of about **100 who enroll, around 70 reach the next step (TTP), and about 50 reach infusion**, where revenue lands. (Kolin's rule of thumb.)
- The standing plan already rewards infusion. This contest rewards the enrollment step for the two months it matters most.
- Audience for the pitch: **Abel, the VP of Sales**.

## 1.2 The scoring logic (complete, verified against the live Excel scorer)
- **Baseline** for each territory = its average enrollments over the last four quarters,
  then scaled to the two month window by taking **two thirds** of it. That baseline is the
  number to beat.
  - Baseline window: **Q3 2025 through Q2 2026** per the July 14 call. NOTE: Kolin's follow up
    email said one quarter later (Q4 2025 through Q2 2026, three quarters). THIS IS OPEN, confirm which.
  - Monthly baselines were tested and rejected. Monthly numbers swing too much for small
    territories (some have a median of zero), so quarterly average is used instead.
- **Size** for grouping = the average of those trailing quarters (before scaling).
- **Tiers** (three size groups), by Size:
  - Large, Size of about 12.7 or more.
  - Medium, Size between about 6.5 and 12.7.
  - Small, Size below about 6.5.
  - (These cutoffs came from the old Excel and may shift once the real roster and baseline
    window are set. Treat as illustrative.)
- **Two measures**, scored inside each tier:
  - Volume growth = actual contest enrollments minus baseline (patients added).
  - Percent growth = that difference divided by baseline.
- Rank each territory on both measures within its tier, **average the two ranks** into one
  score, lowest score is best. **Top two in each tier get paid.** Ties go to the higher percent growth.
- **RADs** (the regional directors) compete as **one single group, no size tiers**, since
  there are only a handful. A RAD's baseline is the sum of its territories' baselines. Same
  two measures, top two paid.
- **Quality prize (side prize)** = the territory in each tier whose enrollments most often
  reach TTP (the next treatment step). A territory needs at least **5 enrollments** to qualify.
  Because TTP lags about **30 days** after enrollment, the quality prize is settled about a
  month after the contest ends, so **after October**. A territory can win the quality prize
  and still place first or second, it is a separate award, not a trade off.

## 1.3 The payout (confirm the exact numbers)
- Single prize pot, shown as a formula so any budget plugs in.
- Current build uses **$30,000 pot**, split per tier as **first 16.67 percent, second 10 percent,
  quality prize 6.67 percent**, which comes out to about **$5,000 first, $3,000 second, $2,000 quality** per tier.
  Across the three tiers that is 50 / 30 / 20 percent of the pot, nine prizes in total.
- OPEN: Kolin's July 14 follow up email floated a larger split, **first $7,500, second $5,000,
  quality $3,000** per tier (a pot of about $46,500). Confirm which set to use.

## 1.4 Confirmed vs placeholder (never present placeholders as real)
- Confirmed real, cite freely: the 50 to 70 capacity, the 27 to 21 enrollment dip and 25+ goal,
  the 100 / 70 / 50 funnel, 28 territories (was 24), three size tiers, top two per tier, RADs as
  one bucket, quarterly baseline scaled by two thirds, quality prize on enrollment to TTP with a
  minimum of 5 and a roughly 30 day lag, the region-even versus territory-uneven fairness finding.
- PLACEHOLDER, must be labeled illustrative and never presented as real:
  - The 28 territory names, their sizes, and their tier assignments (slide 8).
  - The worked example numbers (slide 7).
  - The backtest chart values are real but aggregate only, no territory names.
- The real 28 territory list and the live enrollment and TTP feed are still pending from Kolin.

## 1.5 The fairness evidence (why we group by size)
- By region, the country is fairly even, within about 1.05 times the middle.
- By territory, it is about an **85 times spread**, roughly 1,000 patients in the largest and
  about 12 in the smallest.
- A raw count contest would crown the biggest territory every time, so grouping by size is required.

## 1.6 Timeline
- Backtest window used to prove it works: **August 1 to September 30, 2025** (last year, real data).
- Live contest: **August 1 to September 30, 2026**. Kolin wants it rolling by early August.
- Quality prize settled after October.

---

# 2. THE CONTEST PITCH DECK (build spec)

Ten slides, each copying a device from the real Iovance IC deck so it looks native. Kolin
prefers visuals over text. Full sentence action titles that state the point. Below is the
slide by slide plan with the on-slide content already trimmed to the lean, consulting style.

### Slide 1, Title
- IC title slide look: dark teal navy background, angular lime banners, IOVANCE serif logo.
- Title: 3Q Enrollment Contest
- Subtitle: A proposed sales contest to drive enrollments, August and September 2026
- Footer: Confidential for Internal Use Only

### Slide 2, Overview (BUILT AND APPROVED as the style sample)
- Eyebrow: Overview
- Title: We added capacity, but enrollments have dipped, so this contest gives the funnel a short push
- Left, two stat tiles (big number style):
  - Monthly treatment capacity: big number 70, "slots a month", green delta "Up from 50".
  - Weekly enrollments: big number 21, "a week now", red delta "Down from about 27, and the goal is 25 or more".
- Right, a funnel graphic, three stacked bars narrowing: 100 Enrollments, 70 Reach the next step,
  50 Infusions where revenue lands. A steel blue marker points at the top bar, "The contest pushes here".
- Keep it lean, do not repeat the title in bullets, do not add a caption under the funnel.

### Slide 3, The four ideas behind it (BUILT as the visual sample)
- Eyebrow: The Four Ideas Behind It
- Title: We built the contest on four simple ideas, so it stays fair for every territory
- A four quadrant wheel (green, blue, navy, gray) with a white center hub reading "Reward enrollment growth".
- Quadrant labels: Grow over Baseline, Fair by Size, Count and Percent, Quality.
- Four corner callout boxes, matched to each quadrant color:
  - Grow over your own baseline: Each territory is measured against its own past numbers, so no one wins just for being big or loses for being small.
  - Fair by size: We sort territories into large, medium, and small, so you only compete with others your own size.
  - Count and percent: We score both patients added and percent growth, so a big and a small territory both have a real chance.
  - Quality, not chasing numbers: A separate prize goes to the territories whose patients actually move forward to treatment.

### Slide 4, Why we group by size
- Eyebrow: The Fairness Problem
- Title: Our territories are far too different in size to compete head to head, so we group them first
- Visual, a calm even panel next to a bold uneven one (before and after contrast):
  - By region, fairly even, within about 1.05 times the middle.
  - By territory, about 85 times the difference, roughly 1,000 patients in the largest and about 12 in the smallest.
- One line: If we simply counted enrollments, the biggest territories would win every time. Grouping by size keeps it fair.

### Slide 5, How the scoring works
- Eyebrow: How the Scoring Works
- Title: Here is how each territory is scored, and how the RAD group and the quality prize work
- Two column dashed plan detail boxes, a few key terms in red.
- Left, Scoring one territory: baseline is the average of the last four quarters (Q3 2025 through
  Q2 2026), take two thirds for the two month window. Score patients added and percent growth,
  rank on both inside the size group, average them, top two paid, ties go to higher percent.
- Right, The RAD group and the quality prize: RADs are one group with no tiers, baseline is the
  sum of their territories. Quality prize goes to the best enrollment to treatment rate in each
  group, minimum 5 enrollments, settled about 30 days after the contest so after October.

### Slide 6, The payout
- Eyebrow: The Payout
- Title: Each size group pays its top two, plus a quality prize, all from one shared prize pot
- A simple graphic, one pot splitting into three groups. Per group, first about $5,000, second
  about $3,000, quality prize about $2,000, funded from a $30,000 pot. Three groups, nine prizes.
  The pot is a formula so any budget updates every prize. (Confirm the $30k vs the email's larger split.)

### Slide 7, A worked example
- Eyebrow: A Worked Example
- Title: Here is how the scoring plays out, using made up territories and numbers for each of the three groups
- Three small tables side by side, one per size group, columns Territory, Baseline, Actual, Percent, Place.
  ALL PLACEHOLDER, footnote "Made up example, not real targets".
- A green compare line: a small territory that grew 83 percent beats a large one that grew only 4 percent.
  That is the point of splitting by size.

### Slide 8, The 28 territory footprint
- Eyebrow: The 28 Territories
- Title: The contest covers 28 territories, sorted into three size groups by their recent enrollments
- Left, a summary table, group, number of territories, size band, mostly to be filled in.
- Right, the full territory table, each with its size and group. PLACEHOLDER, red flag box
  "Placeholder, waiting on Kolin's real list".
- How we set the groups: average of last four quarters, sort into three groups by size, new
  territories placed with whatever data we have so all 28 are in, groups lock the day the contest starts.

### Slide 9, It works on real data (validation)
- Eyebrow: Proof It Works
- Title: We tested the scoring on last year's real numbers, and it produced clear, sensible winners
- Two small charts from the August and September 2025 backtest, aggregate only, no names.
- Finding: larger territories were flat to slightly down, smaller ones swung high on percent
  because they start from a small base. That is the exact pattern the design is built for.

### Slide 10, What we need to go live
- Eyebrow: Next Steps
- Title: The design is finished, and to go live we need the real roster and the enrollment feed to set the final numbers
- The full list of 28 territories and each one's baseline.
- The enrollment and treatment feed by territory, so we can score the contest as it runs.
- A final decision on the baseline window and the size of the prize budget.
- If everything lands in time, the contest runs August 1 to September 30, quality prize settled after October.

---

# 3. THE IOVANCE HOUSE STYLE (match this exactly on every slide)

Reference deck is the real "2H'26 AMTAGVI CTAM_RAD IC Overviews (Proposed)", 20 slides, photos
in the Style Reference folder. Best way to match the theme in PowerPoint is to duplicate an
existing house slide and retype, rather than build from scratch.

- Font: **Segoe UI** for everything, a serif (Georgia or Cambria) only for the IOVANCE footer tab.
- Colors (hex):
  - Title navy 17344F
  - Steel blue eyebrow 2F5D8A
  - Lime brand and footer band 9DC13C
  - Forest green headings and accents 567A2E
  - Olive squares 6B8E23
  - Quadrant colors: green 4A6B2E, blue 2E6DA4, navy 1F3A56, gray 7F8B8F
  - Red for a rare call out only, C0392B
  - Card fill for stat tiles F4F7EC
- Every content slide has: a small title case steel blue eyebrow at top left, a full sentence
  navy action title that states the takeaway, two small olive squares flanking the title (one
  far left, one far right), and an angular lime footer band with a serif "IOVANCE" tab and a
  small white circle holding the page number at bottom right.
- Footer text: "© 2025, Iovance Biotherapeutics, Inc.  |  Confidential for Internal Use Only".
- Title slide: dark teal navy background, angular lime banners top right and along the bottom
  reading "ADVANCING IMMUNO-ONCOLOGY", the IOVANCE serif logo with "BIOTHERAPEUTICS" in spaced caps.
- Visual devices Kolin likes and the IC deck uses: the four quadrant wheel with a center hub,
  before and after arrow flows, two column dashed plan detail boxes with red key terms, payout
  visuals, scenario cards labeled illustrative example, regional or territory tables, and a
  histogram plus scatter for validation.
- Do NOT use a beige takeaway bar at the bottom, that is not house style, put the point in the title.

## Build toolchain (if building the pptx programmatically on a Mac)
- pptxgenjs, installed globally. Render and check with LibreOffice to PDF, then pdftoppm to PNG, then view.
- LibreOffice substitutes a heavy fallback for Segoe UI, so the preview looks heavier than the
  real thing on a Windows machine with Segoe UI installed. Layout and color are accurate.
- Known pptxgenjs traps to check before shipping (grep the unzipped slide XML): no literal
  "object Object" (a text run's text must be a plain string, not a nested array), no negative
  height like cy="-..." (use flipV or flipH with positive size instead), no stray alpha.

---

# 4. THE SITE OF CARE DECK (second workstream, near done)

An 8 slide deck titled "ATC vs Non-ATC Site of Care Analysis, Metastatic Melanoma". It got
review comments from Tim Logan and Kolin. Source data is McKesson (Compile) medical claims,
2021 to 2025, the metastatic melanoma population on Yervoy or Opdualag.

## 4.1 The 8 slides and their numbers
1. Title.
2. Methodology: ATC is defined at the parent level and includes satellite locations.
3. Market structure: a table, ATC 6,935 (42.7%), Non-ATC Hospital 7,100 (43.7%), Non-ATC
   Community network 1,317 (8.1%), Non-ATC Other 894 (5.5%), Total 16,246 (100%). Bullets:
   about 57 percent treated outside ATCs, non-ATC mostly independent or community with a long
   tail of small accounts, ATC share rose from 19 to 24 percent between 2021 and 2025.
4. Patient journey, a 2 by 2: started outside and ended at an ATC 3,701 (23%), stayed outside
   the whole time 9,301 (57%), started and stayed at an ATC 3,234 (20%), started ATC then left 10 (0.1%).
   Also 6.7 versus 6.0 claims per patient, ATC versus non-ATC.
5. Regional penetration, bar chart, percent of patients reaching an ATC by region: Southeast 50,
   Northeast 49, Ohio Valley 43, West 42, Great Lakes 40, Central 26.
6. Regional opportunity, stacked bar per region, at an ATC versus untapped, with totals:
   West 4,018 (1,699 at ATC, 2,319 untapped), Northeast 3,855 (1,886, 1,969), Southeast 3,206
   (1,601, 1,605), Great Lakes 2,113 (851, 1,262), Ohio Valley 1,903 (633, 1,270), Central 1,017 (265, 752).
7. State targeting, a scatter, penetration on the x axis and untapped patients on the y axis:
   CA (32.8, 1249), FL (62.1, 691), MI (12.3, 663), NY (39.6, 478), OH (51.0, 451), IN (0.7, 403),
   TX (33.0, 377), VA (1.7, 287), AL (25.0, 279), KY (9.8, 239). Michigan, Indiana, and Virginia
   are the priority target zone, large volume and low penetration.
8. Appendix, additional analyses available on request.

Kolin's ask was to combine slides 5 and 6 into one stacked bar showing total patients by region
in two colors, share at an ATC versus not.

## 4.2 The review comments (open)
- Tim, slide 2, naming: "ATC" here means the main center plus its affiliated locations, but the
  prior analysis counted only the main center. Suggests labeling it "ATC Network" to make the
  distinction clear. NOT yet done.
- Tim, slide 4: "I really like this analysis." No action.
- Tim, slide 5: examine at state level and add the volumes per region. Largely answered by the
  new slides 6 and 7.
- Kolin, slide 5: combine 5 and 6 into one stacked bar. Partly done on slide 6.
- Tim, appendix: add a concentration by segment view, and a comparison cheatsheet of this analysis
  versus the prior one (claims source, time period, market basket, business rules). The cheatsheet
  is BLOCKED, waiting on the prior analysis, Kolin is getting it from Tim.

## 4.3 Key findings from the follow up work
- Concentration verdict: the non-ATC volume is DISPERSED, a long tail. About 9,066 identifiable
  non-ATC patients across 621 parent accounts, the top 10 are only about 27 percent, it takes 38
  accounts to reach half. So there is no small cluster to target. This is already implied by the
  deck, so a standalone concentration slide would repeat slides 3, 6, and 7. Recommendation: do
  not add one.
- THE roster correction (the one genuinely new insight): two accounts were wrongly scored as
  non-ATC but are actually ATCs, City of Hope (about 298 patients) and NYU Langone (about 216).
  Fixing them raises ATC share from 42.7 percent to about 46 percent. This is worth adding as a
  footnote or callout on slide 3 or 6. Kaiser Vallejo and Providence Portland add a little more.
- Top non-ATC accounts by region: Central, Texas Oncology 211. Great Lakes, University of Michigan
  531. Northeast, NYU Langone 216 (roster gap). Ohio Valley, Indiana University Health 188. Southeast,
  Clearview Imaging 234 (likely a claims artifact, an imaging center, exclude), Florida Cancer
  Specialists 197. West, City of Hope 293 (roster gap), Sutter 186.
- Top non-ATC accounts by priority state: MI, University of Michigan 531. IN, Indiana University
  Health 188. VA, UVA 138. These could be named on slide 7.

## 4.4 Data landscape
- Snowflake, database COMPILE_DEV.PUBLIC, McKesson Compile claims, the melanoma Yervoy or Opdualag
  population. The canonical SQL pipeline is git/NewCode.sql, which builds ATC_CLASSIFIED_FINAL and
  related tables. All Site of Care numbers reconcile to 16,246 patients.
- Infinity is a separate platform (the AMTAGVI and TIL operations world, host wotcqlf.vespa.stotle.io).
  It holds the authoritative ATC account list (93 accounts) and the roster and mapping files. It
  CANNOT be joined or uploaded to Snowflake, so reconciliation is done offline by name. Infinity is
  the AMTAGVI/TIL population, not the Yervoy/Opdualag claims population, do not mix them.

---

# 5. OPEN DECISIONS FOR KOLIN (carry these forward)
1. Contest baseline window: Q3 2025 through Q2 2026 (four quarters, from the call) or one quarter
   later (three quarters, from the email).
2. Contest prize budget: $30,000 with about $5,000, $3,000, $2,000 per group, or the email's
   $7,500, $5,000, $3,000 per group.
3. The real 28 territory list, plus the live enrollment and TTP feed (slides 7, 8, 9 depend on these).
4. Who presents the contest, Kolin from the call, or you drafting it for Abel from the email.
5. Site of Care: whether to add the roster correction callout, whether to name top accounts on the
   state slide, and the ATC Network naming change on slide 2. Do not build a standalone concentration slide.
6. Site of Care cheatsheet is blocked on the prior analysis from Tim.

---

# 6. PEOPLE
- Kolin Knott, Associate Director, Sales Operations, the user's manager and the main contact.
- Abel, VP of Sales, the audience for the contest pitch.
- Tim Logan, senior, gave the Site of Care deck comments.
- Sasi (Sassy), the data and Tableau contact for the dashboard and Infinity access.
- The user, Srinidhi, a summer intern on the BAI team, departing around end of summer, so the
  contest should be rolling before then.

# 7. THE PPR DASHBOARD (background, not the current focus)
A separate project. Today each practice scorecard is built by hand, over an hour each. The plan
is a Tableau dashboard on Infinity data that fills in when you pick a center, with benchmarks. Sasi
said to use Infinity and build the whole dashboard. Tableau is installed and the license is shared,
next step is to connect it and confirm data access. This is a later task, after the contest deck.

---

# 8. CURRENT STATE OF THE CONTEST DECK BUILD
- Slides 2 and 3 are designed and approved as the style and tone samples (consulting clean, Option C
  voice, funnel on slide 2, four idea wheel on slide 3).
- The remaining slides (1, 4, 5, 6, 7, 8, 9, 10) are specced above and ready to build in the same style.
- The immediate next step is to build the full ten slide deck to that standard, keeping every
  placeholder and open item clearly flagged, then reconcile the payout and baseline once Kolin confirms.