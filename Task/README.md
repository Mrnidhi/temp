# ATC to McKesson Compile crosswalk

Fills columns N to R of the Active ATC List tab in **ATC Check_Excersise**, the
block headed "Komodo Information": facility ID, facility name, facility type,
HCO ID, HCO name.

As of 2026-08-04: **95 of 97 ATCs resolved, 2 questions outstanding.**

## The task

Kolin's ask, in his words: get facility ID and name from the Compile facility
table by matching on address, with the account type likely Hospital, then use
that facility ID to get the HCO ID and name from the hierarchy table. He also
wants to know where the location on his list is wrong, the example he gave
being an ATC recorded as Phoenix that is actually in Gilbert.

Nothing beyond that is calculated here.

## Files

| File | What it does |
|---|---|
| `ATC crosswalk - build and verify.sql` | Builds everything and checks itself. Run All, top to bottom. |
| `test.sql` | One query. The final record: every ATC, its four columns, and a plain instruction beside each. |

## How to run

Open a fresh Snowflake worksheet, paste `ATC crosswalk - build and verify.sql`,
press Run All. It takes about a minute and rebuilds four transient tables in
`COMPILE_DEV.PUBLIC` before it checks anything, so no result can ever describe
a stale table.

Read **Q1** first. Six checks, all must say PASS. If one fails, stop.

Then run `test.sql` and download its grid with the arrow above the result
panel. That CSV is the record of what went into the workbook and why.

## Sources

- `COMPILE_PROVIDER360.ENTITIES.IOV2501_FACILITY_ATTRIBUTES`
- `COMPILE_PROVIDER360.RELATIONSHIPS.IOV2501_HCO_FULL_HIERARCHY`
- `COMPILE_DEV.PUBLIC.ATC_CHECK_EXCERSISE`, the Active ATC List tab uploaded
  2026-08-04

## Things about the data that were not obvious

**The facility ID is a composite.** `LOC-xxxxx+H-yyyyy`, and the part after the
plus is the HCO ID. `H-` is a hospital, `PG-` a physician group. So column N
already contains column Q. Every matched row was checked against this and all
of them agree, which is an independent proof that the hierarchy join is right.

**The uploaded sheet has two header rows.** The merged section banners and then
the real column names. Snowflake could not infer names and produced c1 to c18,
which it folded to uppercase, so write `c1` and never `"c1"`. Both header rows
load as data and are dropped in Build Step 1.

**The hierarchy table is wide, not long.** One row per facility, 29 columns,
carrying the HCO directly plus a twelve level parent chain. There is no level
column, so there is no level to pick.

**There is no cancer centre account type.** Eleven types exist and the largest
is PHYSICIAN GROUP, not HOSPITALS. Four correct answers are filed as PHYSICIAN
GROUP or CLINIC. A hard filter on Hospital would have thrown them away and
reported them as unmatched, which is why the type is a preference in the
ranking and never a filter.

**An NPI is not an address.** It belongs to an organisation rather than a
building. On the first run the UC San Diego NPI led to a facility fifteen miles
from the address on the sheet. An NPI now only counts as a strong match when
the zip and the street number agree with it.

## How the matching works

The state is the only hard gate. Everything weaker is a tier, so a poor match
is visible rather than absent.

1. zip and the whole address agree
2. NPI, zip and street number all agree
3. zip, street number and street name
4. city, street number and street name
5. street number and a close address
6. NPI agrees but the address does not, held back and never pasted

Within a tier the choice is settled by address similarity first, then a
hospital ahead of other account types, then the name, then the facility ID so
that two runs on the same input give the same answer.

Address beats name throughout, because the two systems do not agree on names.
Sheet row 6 is "Honorhealth Scottsdale Shea Medical Center" and Compile calls
the same building "HONORHEALTH".

## What proves it works

Kolin had already filled in five rows by hand. The query reproduces all five
exactly, facility and HCO. That is check 6 in Q1 and it is the reason to trust
the other 92.

## Filling the workbook

Paste the CSV onto a new tab in the workbook, then in N3 of the Active ATC
List:

```
=XLOOKUP($A3, compile_match!$A:$A, compile_match!$B:$F, "")
```

Swap the tab name if yours differs. It spills across N to R, so nothing goes in
O, P, Q or R. Fill down to row 99.

Check three things before locking it in:

- `=COUNTA(N3:N99)` returns 95
- no #N/A anywhere in N3:R99
- row 3 matches what Kolin already had there

Then select N3:R99, copy, Paste Special to values.

Do the lookup with a formula, not by asking a language model to place the IDs.
The formula either finds the row or fails visibly with #N/A. A model can
produce an ID that looks exactly like the others and is wrong, and nothing
downstream would catch it.

## The three resolved by hand

None of these were guessed from names. Each was read out of the facility table
by listing every hospital Compile holds in that ATC's own city.

- **UF Health Cancer Center**: Shands Teaching Hospital and Clinics at 1600 SW
  Archer Rd. All three Shands buildings share one HCO, so the HCO is certain
  whichever is used. 2033 Mowry Rd is the research building and Compile does
  not hold it.
- **UK Albert B Chandler Hospital**: University of Kentucky at 800 Rose St,
  which is the hospital's real address. The 1000 S Limestone on the sheet is a
  campus mailing address. Not UK Hospital Clinical Lab, which shares the same
  location under a different HCO.
- **University of Louisville Health-Jewish**: Jewish Hospital at 217 E Chestnut
  St, the same block as the address on the sheet.

## The two still open

**TriHealth.** The 625 Eden Park Dr on the sheet is a corporate office and
Compile holds no facility there. TriHealth's two Cincinnati hospitals are Good
Samaritan and Bethesda North. Which one is the authorized site is Kolin's call.

**Avera McKennan.** Two candidates under different HCOs. The transplant
institute sits at 1315 S Cliff Ave, one building from the 1325 S Cliff Ave on
the sheet. A separate Avera McKennan entity sits at 1000 E 23rd St, a different
street. The address points at the transplant institute but which entity is
authorized is Kolin's call.

## Addresses on the sheet that look wrong

Worth sending back separately. In each case Compile carries the address of the
actual building and the sheet does not.

- **UAB**: sheet says 1802 6th St in 35205, Compile says 1802 6th Ave S in
  35233. Compile's version returns the exact ID Kolin had already filled in by
  hand.
- **North Shore**: sheet says 800 Community Dr, the hospital is at 300.
- **Ohio State Wexner**: sheet says 520 W 10th Ave, the main hospital is at
  410. Same street.
- **Stanford**: sheet's own two address blocks disagree, one says Stanford and
  the other Palo Alto. Same building, both valid.
- **Yale**: the zip reads 6510 in the sheet because Excel dropped the leading
  zero. It is 06510. The pipeline re-pads every zip so this did not break the
  match.
