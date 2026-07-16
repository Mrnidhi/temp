# Build instructions — Region & State non-ATC card slides

Two new slides for the ATC vs Non-ATC Site of Care deck.

**READ FIRST:** PowerPoint Copilot cannot build these faithfully. It will not place
18 precisely scaled bars or match the card grid. Use this order:
1. **Duplicate an existing content slide** (e.g. slide 5 or 6). This carries the
   theme, the green angular footer band, the IOVANCE tab, and the copyright line.
2. Delete the body content, keep the frame.
3. Build the cards manually using the exact specs below. Build ONE card fully,
   then copy-paste it 5 times and edit the text and bar widths. That is far faster
   than Copilot and it will actually match.
4. The Copilot prompt in each section is optional, only useful to rough in the
   title and text boxes.

Slide size assumed: **13.333 in x 7.5 in** (standard widescreen).

---

## Shared style (both slides)

| Element | Value |
|---|---|
| Font | Segoe UI throughout |
| Title | Navy `#17344F`, 20 pt, bold |
| Eyebrow | Steel blue `#2F5D8A`, 11 pt, bold, letter-spaced, ALL CAPS |
| Card header bar | Fill navy `#17344F`, text white 11 pt bold |
| Card body | White fill, border `#D8DEE4` 0.75 pt |
| Normal bar | Forest green `#567A2E` |
| Flagged bar (see footnotes) | Grey `#C9CCD1` |
| Account name / count | `#2B3742`, 9.5 pt (count bold, right-aligned) |
| Footnotes | `#5B6670`, 9.5 pt (source line italic) |
| Dagger flags † ‡ | Red `#C0392B` |
| Olive squares flanking title | `#9DC13C`, 0.15 in square, at x 0.50 in and x 12.69 in, y 0.54 in |

### Layout grid (identical on both slides)
| Item | X | Y | W | H |
|---|--:|--:|--:|--:|
| Eyebrow text | 0.73" | 0.54" | — | — |
| Title text | 0.73" | 0.89" | 11.9" | — |
| Divider line | 0.73" → 12.60" | 1.29" | — | — |
| Card 1 / 4 | 0.73" | 1.56" / 3.75" | 3.81" | 2.08" |
| Card 2 / 5 | 4.76" | 1.56" / 3.75" | 3.81" | 2.08" |
| Card 3 / 6 | 8.79" | 1.56" / 3.75" | 3.81" | 2.08" |
| Card header bar | (card X) | (card Y) | 3.81" | 0.31" |
| Footnote line 1 | 0.73" | 6.15" | — | — |
| Source line | 0.73" | 6.34" | — | — |

### Inside each card (offsets from the card's top-left)
- Account name: +0.15" right, rows at +0.63", +1.08", +1.54" (from card top)
- Count: right-aligned to card right edge minus 0.15", same rows
- Bar: starts +0.15" right, sits 0.06" below its name row, **height 0.09"**

### BAR WIDTH RULE (important — this is what makes it match)
All 18 bars share one scale so they are comparable across cards:

> **bar width (inches) = patients × 0.00375**

Examples: 531 → 1.99" · 216 → 0.81" · 188 → 0.71" · 85 → 0.32" · 34 → 0.13"

---

## SLIDE A — Region view

- **Eyebrow:** REGIONAL VIEW  ·  NON-ATC ACCOUNTS
- **Title:** Each region's non-ATC volume is led by a few large accounts
- Card header shows region name (left) and untapped total (right, `#CFE08A`, 9 pt)
- Cards ordered by untapped volume, left to right, top row then bottom row.

| Card | Region | Header right | Account 1 | Account 2 | Account 3 |
|---|---|---|---|---|---|
| 1 | West | 2,319 untapped | City of Hope † — 293 (GREY) | Sutter Health — 186 | Kaiser — 98 |
| 2 | Northeast | 1,969 untapped | NYU Langone † — 216 (GREY) | Dartmouth Health — 189 | University of Virginia — 138 |
| 3 | Southeast | 1,605 untapped | Clearview Imaging ‡ — 234 (GREY) | Florida Cancer Specialists — 197 | Baptist Health S. FL — 134 |
| 4 | Ohio Valley | 1,270 untapped | Indiana University Health — 188 | Baptist Health — 138 | Kettering Health — 85 |
| 5 | Great Lakes | 1,262 untapped | **University of Michigan — 531** (bold) | Allina Health — 77 | Aspirus — 66 |
| 6 | Central | 752 untapped | Texas Oncology — 211 | University of Arkansas — 52 | Monument Health — 37 |

**Footnote 1:** † On the ATC roster (grey), so not true leakage. Excluding City of Hope and NYU Langone raises ATC share from ~43% to ~46%.  ‡ Clearview is an imaging center, a likely claims artifact.
**Source:** Source: McKesson (Compile) medical claims (2021 to 2025); ATC roster per Infinity. Untapped = non-ATC patients per region.

---

## SLIDE B — State view

- **Eyebrow:** STATE VIEW  ·  NON-ATC ACCOUNTS
- **Title:** State by state, non-ATC volume usually runs through one dominant account
- Card header shows state name only (no total — we do not have verified state totals, do not invent one).
- Six largest states by non-ATC volume.

| Card | State | Account 1 | Account 2 | Account 3 |
|---|---|---|---|---|
| 1 | California | City of Hope † — 277 (GREY) | Sutter Health — 186 | Kaiser — 78 |
| 2 | Florida | Florida Cancer Specialists — 197 | Baptist Health S. FL — 134 | Tampa General — 60 |
| 3 | Michigan | **University of Michigan — 531** (bold) | Cancer & Hem. of W. Michigan — 43 | Bronson — 34 |
| 4 | New York | NYU Langone † — 216 (GREY) | Albany Med Health System — 60 | NY Oncology Hematology — 27 |
| 5 | Ohio | Kettering Health — 85 | American Oncology Network — 45 | Premier Health — 41 |
| 6 | Indiana | **Indiana University Health — 188** (bold) | Parkview Health — 55 | Goshen Health — 33 |

**Footnote 1:** † On the ATC roster (grey), so not true leakage. Excluding City of Hope and NYU Langone raises ATC share from ~43% to ~46%.
**Source:** Source: McKesson (Compile) medical claims (2021 to 2025); ATC roster per Infinity. Six largest states by non-ATC volume shown; bars share one scale.

---

## Optional Copilot prompt (rough-in only)

Paste per slide, then fix manually. It will get the title and text roughly right
and miss the cards.

> Add a slide matching this deck's theme. Small steel-blue all-caps label top-left
> reading "REGIONAL VIEW · NON-ATC ACCOUNTS". Navy bold title: "Each region's
> non-ATC volume is led by a few large accounts". Below it, a 3 by 2 grid of six
> white cards with a thin grey border. Each card has a navy header bar with the
> region name in white, and inside lists three account names with their patient
> counts right-aligned. Keep the existing green footer band, IOVANCE tab, and
> copyright line. No clip art or icons.

## Caveats to keep (do not drop these)
- The grey bars are not targets. City of Hope and NYU Langone are on the ATC
  roster and were misclassified; Clearview is an imaging artifact. If these are
  removed from the analysis the ATC share moves from 42.7% to about 46%.
- State totals are not shown because we never pulled verified state totals, only
  the top 3 accounts per state. Do not invent them.
- If you want genuine-only cards (no grey bars), the region/state queries in
  `SQL/Non-ATC accounts by region.sql` must be re-run with City of Hope, NYU
  Langone and Clearview excluded, because we do not have the 4th account per
  region or state to backfill.