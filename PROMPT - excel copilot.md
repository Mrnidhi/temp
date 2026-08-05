# Excel Copilot Prompts — Enrollment Contest Scorer update

Paste these into Excel's Copilot **with the Enrollment Contest Scorer tab
active**. Prompt 1 does the territory changes, Prompt 2 the RAD bucket, Prompt 3
the national bonus and the totals.

Run them in order. If Copilot stalls trying to do a whole prompt at once, feed
the numbered steps one message at a time, each starting with "On this active
sheet only."

Save a backup copy of the workbook before you start.

---

## PROMPT 1 — Territory scoring, updated rules

> **What this sheet is:** a sales enrollment contest scorer with one row per
> territory. It already calculates a size, a two-month baseline, a tier, volume
> growth, percent growth, two ranks and a final score. Leadership has changed
> the rules and I need the scoring and payout updated to match.
>
> **Ground rule — read carefully:** make every change on **this active sheet
> only**. There are other tabs in this workbook. You may **read** values from
> them if a formula needs a number, but do **not** edit, rename, move,
> reformat or delete any tab other than this one. Add any new columns **to the
> right** of what is already there so my layout does not shift. Do not insert
> or delete rows inside the territory table. If a step would need changing
> another tab, stop and tell me instead.
>
> Please do these in order, and show me each formula in plain English before
> you apply it.
>
> **Step 1 — Update the settings block.** Change the existing contest dates and
> add the new inputs, in empty cells near the top, so every formula points at a
> cell rather than a hardcoded number:
> - Contest Start = 15 August 2026, Contest End = 15 October 2026, both as real
>   dates, not text
> - Conversion kicker TTP deadline = 15 November 2026, also a real date
> - Territory 1st place = 7000, 2nd place = 5000, 3rd place = 3000
> - Territory conversion kicker = 5000
> - RAD 1st place = 10000, RAD 2nd place = 5000, RAD conversion kicker = 5000
> - National bonus = 10000
> - Desert Plains bucket = "Tier 2"
>
> The old Total prize pot, 1st share, 2nd share and Side share cells are
> superseded by these flat dollar amounts. Do not delete them yet, just rename
> their labels to say SUPERSEDED. We will remove them at the end once nothing
> errors.
>
> **Step 2 — Force Desert Plains into the medium bucket.** Leadership moved it
> by hand, so it must not depend on the cutoff. Rewrite the Tier column as:
> `=IF(this row's Territory = "Desert Plains", the Desert Plains bucket cell,
> IF(Size >= Tier 1 cutoff, "Tier 1", IF(Size >= Tier 2 cutoff, "Tier 2",
> "Tier 3")))`. Then tell me what Tier Desert Plains now shows.
>
> **Step 3 — Pay three winners instead of two, and add an eligibility gate.**
> A territory must finish **above** its baseline to place at all. Landing
> exactly on the baseline is not a placement.
> - Rewrite Place so that if Volume Growth is not greater than zero it returns
>   blank. Otherwise it counts, within the same tier and among rows whose
>   Volume Growth is greater than zero, how many have a lower Final Score, plus
>   how many tie on Final Score but have a higher % Growth, plus one.
> - Rewrite Result as `=IF(Place = "", "Below baseline", IF(Place <= 3, "Paid",
>   ""))`.
> - Rewrite Payout as `=IF(Place = "", 0, IF(Place = 1, 1st place cell,
>   IF(Place = 2, 2nd place cell, IF(Place = 3, 3rd place cell, 0))))`. Format
>   as currency.
>
> **Step 4 — Fix a tie in the conversion kicker.** Right now two territories on
> an identical pull-through would both rank 1 and both be paid, which pays the
> prize twice. Rewrite Side Rank so that among territories in the same tier
> that meet the minimum enrollments, it counts how many have a higher
> pull-through, plus how many tie on pull-through but have more TTPs, plus one.
> Then Side Prize = `=IF(Side Rank = 1, the conversion kicker cell, 0)`,
> formatted as currency.
>
> Rename the Side Prize column header to "Conversion kicker" and the TTPs
> column header to "Manual entry: TTPs by 11/15/2026".
>
> **Step 5 — Update the notes block** at the bottom so it describes the current
> rules: territories are ranked within their tier on volume growth and percent
> growth, the two ranks are averaged, the top three are paid, a territory
> finishing at or below its baseline cannot place, and ties go to the higher
> percent growth.
>
> **Reminder: only this active sheet gets changed. Leave every other tab
> exactly as it is.**

---

## PROMPT 2 — RAD bucket payout (run after Prompt 1)

> On **this active sheet only** (do not touch any other tab), update the RAD
> table below the territory table. The RADs compete as **one single group**,
> no tiers. It currently ranks them but pays nothing. It now needs to pay.
>
> Add these columns to the right of what is already there, and show me each
> formula before applying it:
>
> - **Above baseline** = `=Volume Growth > 0`, the same rule the territories
>   use.
> - **Place** = blank if not above baseline. Otherwise, across all RADs and
>   among those above baseline, count how many have a lower Final Score, plus
>   how many tie on Final Score but have a higher % Growth, plus one.
> - **Place payout** = `=IF(Place = "", 0, IF(Place = 1, RAD 1st place cell,
>   IF(Place = 2, RAD 2nd place cell, 0)))`, formatted as currency.
> - **TTPs** = the sum of the TTPs of the territories that roll up to this RAD.
> - **Pull-through** = TTPs divided by Contest Enroll, formatted as a
>   percentage.
> - **Kicker Rank** = across **all** RADs with contest enrollments above zero,
>   count how many have a higher pull-through, plus how many tie on
>   pull-through but have more TTPs, plus one.
> - **Conversion kicker** = `=IF(Kicker Rank = 1, RAD conversion kicker cell,
>   0)`, formatted as currency.
> - **Total** = Place payout plus Conversion kicker.
>
> Important: there is exactly **one** RAD conversion kicker across the whole
> group, not one per RAD. The Kicker Rank must be calculated across every RAD
> row, not within any subgroup.
>
> After you apply it, tell me how many RADs are paid a place and how many are
> paid a kicker. It should be two and one.

---

## PROMPT 3 — National bonus and totals (run after Prompt 2)

> On **this active sheet only**, add two small blocks below the notes.
>
> **National bonus block:**
> - National baseline = the sum of every territory's Baseline, with each
>   baseline rounded to a whole number before summing.
> - All contest enrollments = the sum of the Contest Enroll column.
> - Exceeds the national baseline = "YES" if all contest enrollments is
>   **strictly greater than** the national baseline, otherwise "NO". Landing
>   exactly on it does not pay.
> - National bonus payable = `=IF(that cell = "YES", the national bonus cell,
>   0)`, formatted as currency.
>
> **Payout summary block:**
> - Territory places = the sum of the territory Payout column
> - Territory conversion kickers = the sum of the territory Conversion kicker
>   column
> - RAD places = the sum of the RAD Place payout column
> - RAD conversion kicker = the sum of the RAD Conversion kicker column
> - National bonus = the payable cell above
> - Total awarded = those five added together
> - Maximum possible payout = `=3*(1st + 2nd + 3rd) + 3*(territory kicker) +
>   RAD 1st + RAD 2nd + RAD kicker + national bonus`
>
> Tell me what Maximum possible payout comes to. It should be 90000. If it is
> not, one of the settings cells is wrong and I want to know which.
>
> Finally, delete the superseded pot and share cells from Prompt 1 now that
> nothing points at them, and confirm no cell on the sheet errors.

---

## Checks to run yourself afterwards (not for Copilot)

Copilot will not verify its own work, so do these by hand.

1. Desert Plains shows Tier 2.
2. Temporarily set one territory's Contest Enroll to exactly its own Baseline
   cell. Its Place must go blank and its Payout must be zero. Undo afterwards.
   Use the baseline cell itself, not a rounded version, or a territory whose
   real baseline is 12.9 will look wrong when you type 13.
3. With a realistic set of contest enrollments in, filter Payout for greater
   than zero. No tier should show more than three rows, and the only values
   should be 7000, 5000 and 3000.
4. Filter Conversion kicker for greater than zero. Exactly three rows, one per
   tier, and each one has at least the minimum enrollments.
5. No two rows in the same tier share a Place number.
6. The RAD block pays exactly two places and exactly one kicker.
7. Total awarded equals the five parts added up.

## Things to flag rather than fix

- The deck lists 28 territories. Count the rows in this sheet. If they do not
  match, do not add or rename anything, just note the difference.
- Same for the RAD list: note how many RADs the sheet has and what they are
  called, and whether that matches the deck.
- The TTPs column is a number you type, so the 15 November deadline is not
  actually enforced by the sheet. If the ATC TTPs tab holds a TTP date per
  patient, that is where a real cut-off would come from. Worth checking before
  anyone assumes the deadline is being applied.
