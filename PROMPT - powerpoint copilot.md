# PowerPoint Copilot Prompts — Enrollment Contest deck

## Read this first

Copilot in PowerPoint cannot rebuild the visual design. It has no reliable way
to set an exact hex fill on a specific shape, place a panel at a given
coordinate, draw the left-edge accent bar, or build a twelve-column table in the
Iovance house style. Asking it to will produce something that looks nothing like
the rest of the deck.

So split the job:

- **The design is already built.** Use `3Q2026 Contest.pptx` from the FINAL
  folder. It is nine slides on the real corporate master with the layout,
  colours, panels and tables already correct. Open the real deck, delete the
  slides being replaced, and use Home > New Slide > Reuse Slides to bring the
  finished ones across, or copy and paste each slide. Keep your existing title
  slide and only edit its date line, because it has the photograph.
- **Use Copilot for what it is genuinely good at**, which is the wording and
  the speaker notes. The prompts below are scoped to that.

If you would rather rebuild from scratch inside PowerPoint anyway, expect to do
the layout by hand and use Copilot only for the text.

---

## PROMPT 1 — Speaker notes, one slide at a time

Select a slide first, then paste this with the details for that slide filled in.
Copilot handles notes well when it is looking at one slide.

> Rewrite the speaker notes for the slide I have selected. Keep it to 30 to 60
> seconds when read aloud, and structure it as exactly three things, in this
> order:
>
> 1. The one main takeaway of this slide.
> 2. How it follows from the previous slide.
> 3. The one misunderstanding I should head off before it becomes a question.
>
> Write it as flowing sentences, not bullets or headings. Plain language, no
> jargon, no exclamation marks. Do not introduce any rule, number or date that
> is not already visible on the slide. Do not mention design or layout.
>
> Here is what this slide is about: **[paste the slide's takeaway, the previous
> slide's subject, and the misconception]**

The nine slides and what to feed it:

| Slide | Takeaway | Misconception to kill |
|---|---|---|
| Title | A two-month enrollment contest running alongside the IC plan | That it competes with the IC plan. It does not. The IC plan pays on infusions, this pays on enrollments, the step before |
| Business context | We bought capacity we are not filling, slots up but weekly enrollments down | That we should be incentivising infusions. The IC plan already does; the bottleneck is upstream |
| Contest at a glance | Who competes, when, how winners are found, what it takes to place | That anyone competes against the whole country. You are only ranked against territories of a similar size |
| Fairness check | The largest territory is many times the smallest, so one national list would be decided before it started | That high, medium and low describe how good someone is. They describe how big the patch is |
| Scoring methodology | Eight steps, and step 7 is the gate: above your own baseline or you cannot place | That it is one measure. It is two, and averaging the ranks is what stops either running away with it |
| Worked example | One bucket end to end, the smallest baseline still wins | That the kicker is part of the placement score. It is separate, and it is scored on pull-through |
| Contest requirements | Two different awards with two different sets of requirements | That the kicker is a consolation prize for missing a place. A territory can win one, both or neither |
| Payout | 20,000 per volume bucket, 20,000 for the RAD bucket, 10,000 national, 90,000 at the maximum | That 90,000 is the plan. It is the ceiling, and only if every bucket has three eligible winners |
| Reference, the baselines | Every territory and the number it has to beat, inside its bucket | That the baseline is a target somebody set. It is that territory's own recent average scaled to two months |

---

## PROMPT 2 — Tighten the wording on a slide

Use this when a slide is right but reads like a rulebook.

> Rewrite the text on the slide I have selected so a person who has never seen
> this contest can follow it. Keep every number, date, name and dollar amount
> exactly as it is. Do not add or remove any rule. Do not change the slide
> title unless I ask.
>
> House rules for the writing:
> - No em dashes or en dashes. No arrows, no "approximately", no maths symbols.
>   Write them as words.
> - The groups are always "high volume", "medium volume" and "low volume".
>   Never large, small, or tier 1, 2 or 3.
> - Sentence case. No slogans, no exclamation marks.
> - Say "at or below its baseline cannot place", never "below its baseline".
>
> Show me the before and after so I can compare.

---

## PROMPT 3 — Draft the contest-at-a-glance content

Only if you are rebuilding rather than reusing the finished slide. Copilot can
draft the words; you will still place the four panels yourself.

> Draft the text for an orientation slide called "Contest at a glance". Four
> short blocks, each with a heading in capitals and two sentences under it. No
> dollar amounts anywhere on this slide, its job is orientation only.
>
> - WHO COMPETES: CTAM territories compete inside high, medium and low volume
>   buckets, and RADs compete in one overall RAD bucket.
> - WHEN IT RUNS: enrollments count from 15 August to 15 October 2026, and for
>   the conversion kicker the TTP has to occur by 15 November 2026.
> - HOW WINNERS ARE FOUND: each territory is ranked on both volume growth and
>   percent growth, inside its own bucket rather than against the whole
>   country.
> - WHAT IT TAKES TO PLACE: a territory has to finish above its baseline, and
>   the top three eligible territories in each volume bucket take a placement
>   award.
>
> Then one closing line saying that what each territory, each RAD and the
> country as a whole can win is set out on the payout slide.
>
> Keep it short enough to read in a few seconds. No em dashes, no maths symbols,
> sentence case.

---

## What Copilot must not be asked to do

It will attempt these and get them wrong:

- Set specific hex colours, or match the fills used on the existing slides
- Place shapes at exact positions or sizes
- Build the tinted card with a coloured bar down its left edge
- Build the twelve-column worked-example table in the house table style
- Reorder the deck to a specified sequence
- Renumber the footer page circles

Do all of that by reusing the finished file, or by hand.

---

## Checks to run yourself afterwards

1. Nine slides, footer numbers running 2 to 9 with no gaps.
2. No text clipped and nothing overlapping the green footer band.
3. Every slide has notes, and they match what is actually on that slide.
4. Search the deck, including notes, for: "to confirm", "top 10", "pending",
   "$30,000", "16.67", "6.67", "top two", "quality prize", "September 30", and
   "finishes below its baseline". All should return nothing. The correct
   phrasing is "at or below".
5. Desert Plains appears in the medium volume table only.
6. Export to PDF and read it once as if you had never seen the contest. You
   should be able to explain back, in order: why it exists, how participants are
   grouped, how scoring works, what is required to qualify, and what the awards
   are.
