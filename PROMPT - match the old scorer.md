# Make the new scorer match the old one

Open the new workbook, click the Enrollment Contest Scorer tab, paste
everything below the line into the Claude add-in.

---

I have an older version of this scorer that worked properly, and this new one
is missing pieces. I want this sheet to end up looking and behaving exactly
like the old one.

**Two things that must not change.** This sheet has 28 territories and 6 RADs.
The old one had 24 territories and 5 RADs. Keep what is here. And keep the tier
cutoffs that are already in this sheet, whatever they are. They were set for
this roster and they currently produce the right split of 9, 10 and 9
territories. Do not copy the old sheet's cutoffs across.

Everything else should match.

## Step 0, look first

Tell me what you find before changing anything: the header row, the first and
last territory row, the column letter for every header, where the RAD block
starts and ends, where the parameters, notes, national bonus calculation and
payout summary sit, and which of the columns below are missing.

## The territory table

Columns in this order, left to right. Match by header name, and add any that
are missing on the right rather than shuffling what is already there.

RAD, Territory, 4Q2025, 1Q2026, 2Q2026, Size, Baseline (2-mo), Tier,
Contest Enroll, Volume Growth, % Growth, Vol Rank, Growth Rank, Final Score,
Place, Result, TTPs, Pull-through, Side Rank, Conversion kicker, Data check,
Baseline flag, Payout.

The two you are most likely missing are **Data check** and **Baseline flag**.

```
Data check     =IF(<Terr>13="","",IF(<TTPs>13><Enrol>13,"CHECK",""))
Baseline flag  =IF(<Terr>13="","",IF(<Base>13<3,"LOW BASE",""))
```

Data check is copied straight from the old workbook, so use it as written. It
flags any row where TTPs came out higher than contest enrollments, which should
not be possible and is exactly what I want to see. **Do not "fix" that by
capping pull-through at 100 percent.** I need those rows visible.

I am less sure about the Baseline flag threshold. Under 3 matches what I can
see in the old sheet, but if the old workbook is open, read its real formula
and use that instead, and tell me if it differs.

## The RAD block

This is where the actual bug is. Columns, in order:

RAD, Baseline, Contest, Volume Growth, % Growth, Vol Rank, Growth Rank,
Final Score, Place, Result, Eligible, Place payout, TTPs, Pull-through,
**Kicker Rank**, Conversion kicker, Total.

The new sheet is missing **Kicker Rank**, which sits between Pull-through and
Conversion kicker. Because it is missing, the Conversion kicker column has
nothing to rank on, so it is blank for every RAD and the $5,000 RAD kicker can
never be paid. In the old sheet Northeast held Kicker Rank 1 and took the
$5,000.

Add it. It ranks every RAD on pull-through, best first. Level on pull-through
goes to more TTPs. Still level goes to whichever is higher up the sheet, so the
prize cannot be paid twice.

```
=IF($<Enrol><FIRST><=0,"",SUMPRODUCT(($<Enrol>$<FIRST>:$<Enrol>$<LAST>>0)*($<Pull>$<FIRST>:$<Pull>$<LAST>>$<Pull><FIRST>))+SUMPRODUCT(($<Enrol>$<FIRST>:$<Enrol>$<LAST>>0)*($<Pull>$<FIRST>:$<Pull>$<LAST>=$<Pull><FIRST>)*($<TTPs>$<FIRST>:$<TTPs>$<LAST>>$<TTPs><FIRST>))+SUMPRODUCT(($<Enrol>$<FIRST>:$<Enrol>$<LAST>>0)*($<Pull>$<FIRST>:$<Pull>$<LAST>=$<Pull><FIRST>)*($<TTPs>$<FIRST>:$<TTPs>$<LAST>=$<TTPs><FIRST>)*(ROW($<Pull>$<FIRST>:$<Pull>$<LAST>)<ROW()))+1)
```

Then:

```
Conversion kicker  =IF($<KickRank><FIRST>=1,<RADKickerCell>,0)
Total              =<PlacePayout><FIRST>+<Kicker><FIRST>
```

Watch the dollar signs when you fill down. `$<Pull><FIRST>` is the row you are
on and should move. `$<Pull>$<FIRST>:$<Pull>$<LAST>` is the whole block and must
stay put. If it slides, each RAD gets compared against a different set and the
answer is quietly wrong.

**The kicker does not care about beating baseline.** Every RAD in this sheet is
currently below baseline and reads Eligible NO. That correctly stops the place
money, but it must not stop the kicker, which is scored on conversion rather
than growth. If eligibility is wired into the kicker anywhere, take it out.
Exactly one RAD gets it across the whole block, not one each.

## Parameters, notes and the summary blocks

The old sheet had a Contest Parameters block with these thirteen rows, labelled,
dates as real date cells and money as currency:

Contest Start, Contest End, Conversion kicker TTP deadline, Territory 1st place
$7,000, Territory 2nd place $5,000, Territory 3rd place $3,000, Territory
conversion kicker $5,000, RAD 1st place $10,000, RAD 2nd place $5,000, RAD
conversion kicker $5,000, National bonus VP option $10,000, Must beat baseline
to place TRUE, Desert Plains bucket Tier 2.

Leave the dates as whatever is in this sheet now. I am testing with a shifted
window on purpose.

Below the notes, a National bonus calculation block: National baseline, Contest
window in days, All contest enrollments, Exceeds the national baseline,
National bonus payable.

Then a Payout summary: Territory places, Territory conversion kickers, RAD
places, RAD conversion kicker, National bonus, Total awarded, Maximum possible
payout. Total awarded is the sum of the five above it.

If any of these blocks is missing or half built, rebuild it to match. If it is
already there and correct, leave it alone and say so.

## Check it and show me

- Every column listed above exists, in that order.
- Exactly one RAD has Kicker Rank 1, exactly one shows $5,000 in Conversion
  kicker, the rest show zero.
- The RAD conversion kicker line in the payout summary reads $5,000, not $0.
- Maximum possible payout returns $90,000.
- Total awarded equals the sum of its five parts.
- No cell anywhere says "TO CONFIRM", "pending", "$30,000", "16.67" or "6.67".
- The tier split is still 9 in Tier 1, 10 in Tier 2, 9 in Tier 3, and Desert
  Plains is still Tier 2. If that changed, you touched the cutoffs and I want
  them put back.

Then tell me three things: which RAD won the kicker and why, how many rows are
showing CHECK in Data check, and the highest pull-through figure on the sheet.

Do not touch any other tab.
