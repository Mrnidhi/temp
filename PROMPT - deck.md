# Prompt: rebuild the 3Q 2026 AMTAGVI Enrollment Contest deck

Paste everything below to Claude on the machine that has the real
`3Q2026 Contest.pptx`.

---

You are editing `3Q2026 Contest.pptx`, an internal Iovance Biotherapeutics
deck proposing a two-month enrollment contest to commercial leadership. Work on
the real file. Copy it to a backup first. Use python-pptx, not manual XML, and
keep the existing corporate slide master, logo, footer band and confidentiality
line exactly as they are.

## What changed and why

Kolin Knott sent these instructions over Teams. They are final. Do not
reinterpret them, do not add contest rules, and do not add caveats or
"to confirm" language anywhere.

- Each volume bucket pays three winners: 1st $7,000, 2nd $5,000, 3rd $3,000.
- Each volume bucket also pays one $5,000 conversion kicker.
- One overall RAD bucket: 1st $10,000, 2nd $5,000, plus one $5,000 conversion
  kicker across all RADs.
- National VP bonus of $10,000 if total national contest enrollments exceed the
  sum of every territory baseline. On the current roster that sum is 203, so
  the trigger is more than 203, not 203 or more.
- Contest runs August 15 to October 15, 2026. For the conversion kicker the TTP
  must occur by November 15, 2026.
- Desert Plains moves from the high volume bucket to the medium volume bucket
  at leadership direction.
- To be considered a winner for 1st, 2nd or 3rd, a territory must grow over its
  baseline. At or below baseline is not a placement.

Maximum payout is therefore $90,000: three volume buckets at $20,000 each
(15,000 of places plus a 5,000 kicker), $20,000 for the RAD bucket, and the
$10,000 national bonus.

## Deck structure, in this order

Nine slides. Page numbers 2 to 9 in the footer circle; the title slide carries
no number.

1. **Title.** Keep the existing cover and its photograph. Change only the
   subtitle to "A two-month enrollment contest for CTAMs and RADs" and the
   date line to "Runs August 15 to October 15, 2026.  Prepared August 2026."
2. **Business context.** Why the contest exists. Keep the existing capacity and
   funnel content.
3. **Contest at a glance.** New slide, see below.
4. **Fairness check.** Why territories are bucketed by size. Keep the existing
   chart and the three group cards.
5. **Scoring methodology.** Rebuild as eight numbered steps, see below.
6. **Worked example.** Rebuild as a full worked table, see below.
7. **Contest requirements.** Rebuild as two labelled awards, see below.
8. **Payout.** Rebuild, see below.
9. **Reference, the baselines.** The full 28-territory table, moved to the end
   as reference material rather than sitting mid-narrative.

A first-time audience must be able to answer all of these by the end of slide
3: why the contest is being run, who participates, when it runs, who competes
against whom, how winners are determined, what is required to qualify, and
where the awards are explained.

## Design system, follow exactly

Slide size 13.333 by 7.5 inches.

**Grid.** Content left edge 0.62in, right edge 12.71in, so content width is
12.09in. Two-column layout uses 5.85in columns at x = 0.62 and x = 6.88.
Eyebrow at y = 0.34. Title at y = 0.62. Content zone starts at y = 1.85.
Footnote at y = 6.90. The green footer band starts at y = 7.17 and nothing may
overlap it.

**Type.** Segoe UI throughout; the IOVANCE wordmark in the footer stays
Cambria. Eyebrow 12pt bold letter-spaced in blue 2F5D8A. Slide title 23pt bold
navy 17344F, sentence case, message-led, one or two lines. Section labels 11pt
bold. Body 11 to 12pt navy. Key figures 26 to 30pt bold. Footnotes 8.5pt italic
grey 8A8A80.

**Colour, and each one has exactly one job.**

| Hex | Use |
|---|---|
| 17344F | navy, primary content and figures |
| 567A2E | olive, section rules, table headers, confirmed accents |
| 9DC13C | lime, footer band only, never data |
| 2F5D8A | eyebrow labels only |
| 2E6DA4 | secondary accent, used on the second card of a pair |
| 8A8A80 | supporting text and footnotes |

**Panel fills, taken from the existing slides 2 and 3.**

| Hex | Use |
|---|---|
| F4F7EC | soft stat panel |
| F2F6EC | tinted card, olive family |
| EAEEF2 | tinted card, navy family |
| E7EFD6 | full-width takeaway band |
| BFD48A / 8FB446 / 567A2E | graduated greens, light to dark |
| C9CEC0 | connector arrows |

**Four devices, and only these.**

1. *Section label over a rule.* 11pt bold text, then a 1.6pt horizontal rule
   0.28in below it in the same colour, spanning the column. Content starts
   0.44in below the label.
2. *Tinted card.* A filled rectangle with a 0.10in wide accent bar down its
   left edge and a 0.75pt border in the accent colour. No shadow.
3. *Numbered step.* A 0.26in olive square with a white bold number, then the
   text 0.40in to its right, bold term followed by regular explanation.
4. *Full-width takeaway band.* A 12.09in wide E7EFD6 rectangle with a bold lead
   phrase followed by regular text, used to land the point of a slide.

**Key figure treatment.** Small caption above in 10.5pt, large bold numeral,
small note below in 9.5 to 10pt.

Do not add icons, gradients, shadows, stock photography, trophies or medals.
Do not introduce a new font or a new colour.

## Slide 3, contest at a glance

Four tinted cards in a two by two grid, each 5.85 by 1.66in, at x = 0.62 and
6.88, y = 2.02 and 3.92. Olive fill F2F6EC with an olive left edge. Each card
has an 11pt olive bold label and two lines of 11.5pt navy body.

- **WHO COMPETES.** CTAM territories compete inside High, Medium and Low volume
  buckets. RADs compete in one overall RAD bucket.
- **WHEN IT RUNS.** Enrollments count from August 15 to October 15, 2026. For
  the conversion kicker the TTP has to occur by November 15, 2026.
- **HOW WINNERS ARE FOUND.** Each territory is ranked on both volume growth and
  percent growth. Ranking happens inside your own bucket, never against the
  whole country.
- **WHAT IT TAKES TO PLACE.** You have to finish above your baseline. The top
  three eligible territories in each volume bucket take a placement award.

Takeaway band: "**Awards come later.**  What each territory, each RAD and the
country as a whole can win is set out on the payout slide."

No dollar amounts on this slide. Its job is orientation.

Title: "A two-month contest, scored inside size-matched buckets".

## Slide 5, scoring methodology

Two columns of four numbered steps. Left column section label "FIRST, MEASURE
THE GROWTH", right column "THEN, RANK AND AWARD". Steps spaced 0.74in apart.

1. **Establish the baseline.** The average of 4Q 2025, 1Q 2026 and 2Q 2026,
   scaled to the two-month contest window.
2. **Count contest enrollments.** Everything enrolled between August 15 and
   October 15, 2026.
3. **Volume growth.** Contest enrollments minus baseline.
4. **Percent growth.** Volume growth divided by baseline.
5. **Rank both measures** separately, against the other territories in your own
   volume bucket.
6. **Average the two ranks** to get the final score. The lowest score is the
   best.
7. **Apply the eligibility gate.** A territory at or below its baseline is out,
   whatever it scored.
8. **Award the top three eligible** territories in each volume bucket. Ties go
   to the higher percent growth.

Give step 7 a navy chip while the other seven are olive, so the gate stands
out.

Takeaway band: "**Step 7 is the one to remember.**  A territory that finishes
at or below its baseline cannot take first, second or third, however well it
ranks on either measure."

Nothing about RAD payouts or kicker mechanics belongs on this slide. Keep core
scoring separate from the other award mechanics.

## Slide 6, worked example

One volume bucket, five territories, the complete chain. Use generic names,
Territory A through E, because the numbers are invented. Twelve columns:
Territory, Bucket, Baseline, Contest enrol., Volume growth, Percent growth,
Volume rank, Percent rank, Final score, Above baseline, Place, Award.

| Territory | Bucket | Baseline | Contest enrol. | Volume growth | Percent growth | Volume rank | Percent rank | Final score | Above baseline | Place | Award |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Territory A | Medium | 6 | 11 | +5 | +83% | 1 | 1 | 1.0 | Yes | 1st | $7,000 |
| Territory C | Medium | 9 | 12 | +3 | +33% | 3 | 2 | 2.5 | Yes | 2nd | $5,000 |
| Territory B | Medium | 14 | 18 | +4 | +29% | 2 | 3 | 2.5 | Yes | 3rd | $3,000 |
| Territory D | Medium | 11 | 12 | +1 | +9% | 4 | 4 | 4.0 | Yes | 4th | none |
| Territory E | Medium | 10 | 8 | -2 | -20% | 5 | 5 | 5.0 | No | not eligible | none |

These rows are chosen to teach three things at once, so do not alter them.
Territory A has the smallest baseline and still wins, which is the slide title.
B and C tie on 2.5 so the tie-break is demonstrated rather than asserted. E has
a score but finished below baseline, so the eligibility gate is visible.

Below the table, one line: "**Read the tie:**  Territory B and Territory C both
score 2.5. The higher percent growth wins, so Territory C takes second.
Territory E ranked last on both measures and finished below its baseline, so it
cannot place at all."

Then a separate section labelled "CONVERSION KICKER, SCORED SEPARATELY" with a
tinted olive card: "**Territory D takes the $5,000 conversion kicker.**  It
enrolled 12 and 10 of them reached TTP by November 15, an 83 percent
pull-through and the best in the bucket. It wins the kicker even though it did
not place, because the kicker is scored on pull-through and not on growth."

Keeping the kicker visually separate is the point of the slide. Do not merge it
into the table.

Title: "A smaller territory can win by growing more against its own baseline".

## Slide 7, contest requirements

Top third: the three dates as a left-to-right sequence of three panels, 3.55in
wide, filled with the graduated greens light to dark, with grey connector
arrows between them. August 15, 2026 "Contest opens"; October 15, 2026
"Contest closes"; November 15, 2026 "TTP deadline for the conversion kicker".

Below: two tinted cards, explicitly lettered so nobody has to infer that these
are separate award mechanisms.

**A.  TO WIN A PLACEMENT AWARD** (olive card, olive edge)
- You have to finish above your baseline. At or below the baseline is not a
  placement, however you rank.
- You are ranked inside your assigned bucket. High, medium and low volume
  territories are scored separately, and the RADs are scored as one group of
  their own.
- Ties are resolved by the higher percent growth.

**B.  TO WIN THE CONVERSION KICKER** (navy card, 2E6DA4 edge)
- Best enrollment-to-TTP pull-through in your bucket, so this one is about
  conversion rather than growth.
- At least five contest enrollments to qualify.
- The TTP has to occur by November 15, 2026. An enrollment converting after
  that date does not count.

Takeaway band: "**These are two separate awards.**  A territory can win a
placement award, the conversion kicker, both, or neither."

Title: "Two separate awards, with two separate sets of requirements".

## Slide 8, payout

Two rows of four panels, each naming the participant group it belongs to.

Section "CTAM TERRITORIES, INSIDE THEIR VOLUME BUCKET": 1st place $7,000 on a
dark olive panel with white text; 2nd place $5,000 on mid green; 3rd place
$3,000 on light green with navy text; Conversion kicker $5,000 on a tinted
olive card with an olive edge, noted "per volume bucket, best TTP
pull-through".

Section "RADs, AND THE COUNTRY AS A WHOLE": RAD 1st place $10,000 on navy with
white text; RAD 2nd place $5,000 on 2E6DA4 with white text; RAD conversion
kicker $5,000 on a tinted navy card, noted "one across all RADs"; National
bonus $10,000 on a tinted navy card, noted "VP option, if enrollments exceed
203".

Takeaway band: "**Maximum payout $90,000.**  $20,000 in each of the three
volume buckets, $20,000 in the RAD bucket, and the $10,000 national bonus. You
have to finish above your baseline to place."

Title: "Three winners in every volume bucket, separate RAD bucket, and national
bonus".

## Slide 9, the baselines

The existing 28-territory table, unchanged in content, moved to the end. Retitle
the eyebrow to "REFERENCE  |  THE BASELINES" and the title to "All 28
territories and the baseline each has to beat, inside its volume bucket".
Desert Plains must appear in the medium volume table, not the high one. Set its
row in bold so the moved territory is findable.

Table style, which is the Iovance house style and must not change: dark olive
567A2E header row, white bold italic header text, white body cells, black body
text, a thin black grid line on every cell. Not banded, not borderless, not
navy.

Under each bucket heading, state the count and the range in grey 9.5pt, for
example "10 territories, baseline of 6 to 9".

Footnote: the baseline is each territory's average enrollments across 4Q 2025,
1Q 2026 and 2Q 2026 scaled to the two month contest window, and Desert Plains
moves to medium volume at leadership request so the groups are stated on the
baseline column rather than a cutoff.

## Fairness slide, one fix

The footnote currently says the real groups "will be set from the enrollment
numbers". That is out of date. Replace it with wording that says the three
buckets are set and lock for the contest, that Desert Plains is assigned to
medium volume at leadership direction, and that the full roster is in the
appendix.

## House writing rules

- No em dashes or en dashes anywhere. No arrows, no approximately, no greater
  than or equal signs, no middle dots. Write them as words.
- The groups are always "high volume", "medium volume", "low volume". Never
  large, small, or tier 1, 2, 3. Kolin was explicit that these describe
  territory size, not territory quality.
- No marketing slogans and no exclamation marks.
- Sentence case for titles.

## Speaker notes

Every slide gets 30 to 60 seconds of notes with exactly three things: the one
main takeaway, the transition from the previous slide, and the one
misunderstanding the presenter should head off. Do not put new rules or
assumptions in the notes. Do not put design commentary in the notes.

Rewrite all of them. Nothing may survive that mentions the old August 1 to
September 30 dates, "top two", the "quality prize", a $30,000 pool, percentage
share payouts, or anything pending about the RAD bucket.

## Before you finish

Render every slide to an image and look at all of them, both at laptop size and
in slideshow mode. Then check:

- Nine slides, footer numbers running 2 to 9, no gaps.
- No text clipped, no shape overlapping another, nothing over the footer band.
- Every slide has speaker notes and they match what is on the slide.
- Grep the whole file including notes for: "to confirm", "top 10", "pending",
  "$30,000", "16.67", "6.67", "top two", "quality prize", "September 30", any
  dash character, and "finishes below its baseline". All must return nothing.
  The correct phrasing is "at or below".
- Desert Plains appears in the medium volume table only.
- The deck exports cleanly to PDF at nine pages.
- Read it as if you had never seen the contest. You should be able to explain
  back, in order: why it exists, how participants are grouped, how scoring
  works, what is required to qualify, and what the awards are.

Do not touch the Excel scorer in this pass.
