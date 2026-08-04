# Bridge: prior (primary-only) vs current (parent rollup) analysis

Source: CLASS_FINAL x CLASS_HYBRID from ATC_CLASSIFIED_FINAL, run 07/23 evening.
Denominator = 16,246 metastatic melanoma patients on Yervoy/Opdualag (McKesson, 2021-2025).

## The ATC total (7,501, 46.2%) breaks into three tiers

| Tier (CLASS_HYBRID)      | Patients | What it is                                              |
|--------------------------|----------|---------------------------------------------------------|
| ATC: NPI confirmed       | 3,257    | Confirmed at an ATC by provider NPI = the primary/prior method |
| ATC: name fallback       | 3,678    | Sites that roll up to an ATC parent, matched by name = the satellites |
| ATC: roster gap corrected| 566      | ATCs missing from the roster, added back (City of Hope, NYU Langone, OSU Wexner, Hoag) |
| **ATC total**            | **7,501**| 46.2% of all patients                                   |

Non-ATC total = 8,643 (Non-ATC 6,832 + Community Network 1,317 + System sweep 351 +
Unknown 143). Needs Review = 102. Grand total 16,246. Reconciles exactly.

## The bridge (this is the apples-to-apples the field lead asked for)

| Step | Method | Patients | ATC share |
|------|--------|----------|-----------|
| 1 | Primary location only (NPI confirmed) - the prior method | 3,257 | **20.0%** |
| 2 | + parent-child rollup (satellite sites) | +3,678 -> 6,935 | 42.7% |
| 3 | + roster corrections | +566 -> 7,501 | 46.2% |
| = | Current analysis total | 7,501 | 46.2% |

Step 1 (20.0%) matches the old 19-24% range. Step 2 is exactly the "leveraging
parent-child relationships" the field lead described. Step 3 is the roster fixes. Same population
throughout, so the old number and the new number are reconciled line by line.

## Site-split finding (corrects the earlier "closer to 50%")

The Kaiser / Providence / St Luke's system matches from the 07/23 reconciliation were
checked at the SITE level. The authorized sites hold almost no patients:
- Providence Portland Medical Center (authorized): 1 patient. The other ~84 Providence
  patients are at non-authorized Providence sites across CA, WA, TX, MT.
- Kaiser Permanente Vallejo (authorized): not in the top 21 sites, so <=1 patient. The
  166 "Kaiser" patients are spread across the national Kaiser/Permanente system.
- St Luke's: the 10 patients are at St Luke's Regional (Idaho), NOT the authorized
  Colorado Blood Cancer Institute (Denver). 0 at the authorized site.

So the ~260 system matches are NOT valid ATC additions. The 07/23 roster correction
stays at ~399 patients (IU Health 188, Mayo 56, Intermountain 55, etc.), which would move
the next-version share from 46.2% to about **48.5%** - it does NOT approach 50%.
