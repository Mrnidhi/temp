# Iovance theme - build the P&PR dashboard in Tableau

Paste this whole file into the office assistant on the Windows laptop. It is a
self-contained brief. It assumes `python RUN_ALL.py` has already run and the three
extracts exist in the `tableau` folder, and that the workbook already has the two
worksheets from the README (the P&PR Scorecard sheet and the Custom Date Window
sheet). The job here is to make the dashboard look like the Iovance house deck and
lay it out cleanly, not to rebuild the data.

If the two worksheets do not exist yet, build them first using section 4 of
`README.md` in this same folder, then come back to this file.

---

## What "Iovance theme" means (use these exact values)

Colors, taken from the real house deck:

- Navy `#17344F` - the top band, all column-header shading, the confidentiality strip
- Steel blue `#2F5D8A` - section labels and secondary headers
- Lime green `#9DC13C` - the brand accent strip and the bottom band
- Forest green `#3F7A2E` - "improved" in the year-over-year Difference column only
- Red `#C0392B` - "slipped" in the year-over-year Difference column only
- Off white `#EDF1F5` - dashboard background
- Ink `#17232C` - body text on light
- Hairline `#D4DCE3` - light cell borders

Font: **Segoe UI** everywhere. It is the Windows default and it is the house deck
font, so the dashboard will match the slides with no extra install.

House layout idea: a navy title band across the top with the word IOVANCE on the
left and the sheet name next to it, a thin lime strip directly under that band, the
scorecard as the main body, the center dropdown and the date slider as controls, and
a lime band along the bottom that reads ADVANCING IMMUNO-ONCOLOGY. This mirrors the
title slide of the deck.

---

## Step 1. Set the workbook font once

1. Format menu at the top, then Workbook.
2. In the panel on the left, set Fonts to Segoe UI, Regular, 10 pt.
3. This makes every new sheet and label use the house font by default.

## Step 2. Theme the P&PR Scorecard worksheet

Open the P&PR Scorecard sheet. Everything here is under the Format menu and the
right-click menus, nothing is retyped.

1. **Column headers navy, white bold.** Right-click any column header, Format. In the
   Header tab set Shading to `#17344F` and the Font to Segoe UI, white, Bold, 9 pt.
   These are the row that reads Launch to Date, 2024, Top 10, and so on.
2. **Row section labels steel blue.** The left column shows the four metric groups
   (Patient Identification, Tumor Tissue Procurement, and so on). Right-click that
   field on Rows, Format, and set its Font to `#2F5D8A`, Bold. Leave the metric names
   themselves in ink `#17232C`, Regular.
3. **Light row banding.** Format menu, Shading. Under Row Banding set Band Size to 1,
   Pane color to white, and the alternate band to a very light gray (click the color,
   More Colors, enter `#F4F7F9`). This makes rows easy to track across the wide table.
4. **Separate the three column blocks with a border, not a fill.** Tableau cannot
   easily give one column a different background from the next, so use a heavier
   divider instead. Format menu, Borders. Set Row Divider and Column Divider to the
   hairline `#D4DCE3`, thin. Then to mark where the blocks change, put one heavier
   navy vertical line before the Top 10 column and one before the Q3'26 column: in the
   same Borders panel raise the Column Divider Level slider so the pane divider between
   the block groups is darker, or accept the thin dividers if that is fiddly. The three
   blocks are Time (this center), National Metrics (blinded benchmarks), and Quarterly
   (this center).
5. **Right-align the numbers.** The values come in as text from the Result calc.
   Right-click the value field, Format, Alignment tab, set Horizontal to Right so the
   digits line up. Turn on tabular figures is not available, so right alignment is what
   keeps the columns clean.
6. **Kill the heavy gridlines.** Format menu, Lines. Set Grid Lines to None. Keep only
   the light row and column dividers from step 4.
7. **Hide the worksheet title.** Uncheck Worksheet menu, Show Title. The dashboard band
   will carry the name.

## Step 3. Theme the Custom Date Window worksheet

Open the Custom Date Window sheet and repeat Step 2 items 1, 2, 3, 6, and 7 so it
matches the scorecard exactly. It has the same metric rows, so the same formatting
applies.

## Step 4. Build the dashboard

1. New Dashboard from the tab strip at the bottom.
2. In the Dashboard pane on the left set Size to Fixed size, Custom, 1400 by 900. Set
   the object mode to Tiled (bottom of the Objects list) so pieces snap into a grid.
3. Dashboard menu, Format, Dashboard Shading, set to the off white `#EDF1F5`.

**Top band (navy with the wordmark).**

4. Drag a Text object to the very top, full width, about 60 px tall. Type two things on
   one line: `IOVANCE      P&PR Scorecard`. Select IOVANCE and make it Segoe UI, white,
   Bold, 16 pt with wide letter spacing feel (type it as `I O V A N C E` if you want the
   spaced-cap logo look). Make the rest white, Regular, 12 pt.
5. Right-click that Text object, Format, and set its Shading to navy `#17344F`.

**Lime accent strip.**

6. Drag a Blank object directly under the navy band, full width, about 6 px tall.
   Right-click it, Format, Shading lime `#9DC13C`. This is the thin house accent line.

**Controls row (center dropdown and the date stamp).**

7. Put the pCenter parameter on the dashboard: click either sheet on the canvas, use the
   small dropdown arrow at its corner, Parameters, pCenter. Move the card to the top
   right. Right-click the card, Format, header navy, font white, so it reads as house.
8. Add a Text object next to it that reads `Source Data As of: 04/27/2026`. Update the
   date to match the extract each refresh, or leave it as a reminder to update.

**Main body.**

9. Drag the P&PR Scorecard sheet onto the large empty area under the controls. It fills
   the width. If a filter or legend tags along that you do not want, right-click it,
   Remove.
10. Drag the Custom Date Window sheet in below the scorecard, or to a right rail if you
    prefer them side by side. Whichever reads better at 1400 wide.
11. Add the date slider: click the Custom Date Window sheet on the canvas, dropdown
    arrow, Filters, event_date. A slider card with two handles appears. Move it under
    the date-window table. Right-click the slider card, Format, and set the header navy
    and the highlight to lime so it matches.

**Bottom band.**

12. Drag a Text object to the very bottom, full width, about 40 px tall. Type
    `ADVANCING IMMUNO-ONCOLOGY`. Font navy `#17232C`, Bold, 11 pt, letter spaced. Set
    the object Shading to lime `#9DC13C`. This mirrors the deck title slide.
13. Optional confidentiality line: a second thin Text object, navy shading, white text,
    9 pt, reading `2025 Iovance Biotherapeutics, Inc. Confidential for Internal Use Only`.

**Final touches.**

14. On every sheet on the dashboard, use the corner dropdown and uncheck Title so only
    the bands name things.
15. File, Save.

## Step 4b. Exact position and size of every object (1400 by 900)

These are pixel coordinates for a Fixed size dashboard set to 1400 wide by 900 tall.
They only take effect on Floating objects, so for each object do this:

- When you drop the object, set it to Floating (in the Objects area at the bottom left,
  switch the toggle from Tiled to Floating before you drag, or right-click a placed
  object and choose Floating).
- Select the object, open the Layout pane (top left, the tab next to Dashboard).
- In Position type the x and the y. In Size type the w and the h. All four are pixels
  measured from the top-left corner of the dashboard.
- For each worksheet, also set the toolbar Fit dropdown to Entire View so the sheet
  fills its box exactly instead of leaving white space.

Base layout, the scorecard with the date-window companion on the right:

| Object | x | y | w | h | Fill |
|---|---|---|---|---|---|
| Top navy band (Text: I O V A N C E   P&PR Scorecard) | 0 | 0 | 1400 | 64 | navy #17344F |
| Lime accent strip (Blank) | 0 | 64 | 1400 | 6 | lime #9DC13C |
| Source Data As of (Text) | 16 | 82 | 420 | 28 | none |
| Center dropdown (pCenter card) | 1085 | 80 | 300 | 34 | white |
| P&PR Scorecard sheet | 16 | 124 | 896 | 720 | white |
| Custom Date Window sheet | 924 | 124 | 460 | 604 | white |
| Event date slider (event_date card) | 924 | 736 | 460 | 108 | white |
| Bottom lime band (Text: ADVANCING IMMUNO-ONCOLOGY) | 0 | 852 | 1400 | 40 | lime #9DC13C |

Optional confidentiality line: a Text object at x 984, y 860, w 400, h 24, navy text on
top of the lime band, right aligned, reading the internal-use line from Step 4 item 13.

Nothing overlaps: the scorecard ends at x 912, the right rail starts at x 924, a 12 px
gutter between them. The scorecard and the slider both end at y 844, and the bottom band
starts at y 852. Right and bottom margins are 16 px and 8 px. Adjust any number to taste,
the layout holds as long as the right rail starts a few pixels past where the scorecard
ends.

If you put the two tables side by side feels too tight at 460 wide, an equally clean
option is to stack them: scorecard at x 16, y 124, w 1368, h 470, and the date-window
sheet at x 16, y 604, w 1368, h 150 with the slider at x 16, y 762, w 1368, h 82. Use
whichever reads better once real data is in.

## Step 5. Optional KPI band across the top (the executive look)

Only if Kolin wants the headline-first version. This adds a row of five colored number
tiles between the accent strip and the scorecard.

1. Make five small worksheets, one per headline metric: Patients Enrolled, Completed
   TTPs, AMTAGVI Infusions, Patient Progression Rate, and Avg Time Enrollment to TTP.
2. In each, filter the Events source to that one metric and to Keep Center is True, drag
   Result to the Text card, and hide all headers so only the big number shows. Set the
   number font Segoe UI, 30 pt, Bold.
3. Give each small sheet a top border in steel blue: Format, Borders.
4. On the dashboard, drag the five sheets into a single horizontal row under the accent
   strip, equal widths. Add a tiny label above each number in steel blue caps.
5. Keep the full scorecard underneath. Now the center is read at a glance first, detail
   second.

Exact positions for the KPI variant. The five tiles sit in a row at y 124, each 264
wide and 96 tall with a 12 px gap, and the body below shifts down to make room:

| Object | x | y | w | h |
|---|---|---|---|---|
| KPI tile 1 (Patients Enrolled) | 16 | 124 | 264 | 96 |
| KPI tile 2 (Completed TTPs) | 292 | 124 | 264 | 96 |
| KPI tile 3 (AMTAGVI Infusions) | 568 | 124 | 264 | 96 |
| KPI tile 4 (Progression Rate) | 844 | 124 | 264 | 96 |
| KPI tile 5 (Avg Enroll to TTP) | 1120 | 124 | 264 | 96 |
| P&PR Scorecard sheet | 16 | 232 | 896 | 612 |
| Custom Date Window sheet | 924 | 232 | 460 | 500 |
| Event date slider | 924 | 740 | 460 | 104 |

The top band, accent strip, controls, and bottom band keep the same coordinates as the
base layout. Only the body drops from y 124 to y 232 to clear the tile row.

## Step 6. Check it before you show it

- The three column blocks are visually distinct, Time then National then Quarterly.
- Numbers are right aligned and the columns line up down the table.
- The navy top band, the lime strip, and the lime bottom band read like the deck.
- Picking a center in the dropdown changes both the scorecard and the date-window table.
- Dragging the date slider changes every number in the date-window table.
- Timing rows still read as one decimal and the percent row still shows a percent.
- Take a screenshot and hold it next to one of Kolin's real slides. The palette and font
  should match.

## Things to keep honest

- The timing rows are medians, even though the header says Average Time. That is the
  mandated template wording. Do not relabel it.
- Do not put the old quartile columns (25th, Median, 75th, National Average) on this
  dashboard. Kolin is retiring quartiles. They live only on the old template sheet.
- The TTPs Cancelled row is a proxy until Jonathan's Infinity snapshot history is
  connected. If you want, mark it with a small asterisk in the metric label and add one
  footnote Text object at the bottom saying so.
- Tableau cannot fill individual columns with different background colors the way a web
  page can. Use the block dividers from Step 2 item 4 to separate the three blocks. That
  is the correct Tableau way and it is what the house scorecards do.

## Step 7. Make it production ready (punch list from the 07/27 screenshot)

The theme is done. These are the fixes that make it correct and readable. Do the ones in
group A first, they are the ones a viewer notices immediately. Do each fix on BOTH the
P&PR Scorecard sheet and the Custom Date Window sheet so the two tables read together.

### A. Correctness, fix these first

1. **The metrics are in the wrong order. This is the biggest one.** Right now they sort
   alphabetically, so AMTAGVI Regimen sits at the top and, inside a group, OOS Products
   comes before Patient Progression Rate. Kolin's template order is Patient
   Identification and Enrollment, then Tumor Tissue Procurement, then AMTAGVI Regimen,
   then AMTAGVI Treatment Timelines, with the 13 metrics numbered inside that.
   Fix: on the Rows shelf, right-click the metric_group pill, Sort, Sort By Field, choose
   metric_order, Aggregation Minimum, Order Ascending. Then right-click the metric pill,
   Sort, Sort By Field, metric_order, Minimum, Ascending. If a sort icon is showing on the
   Metric header from an earlier click, clear it first (right-click, Clear Sort). Because
   metric_order rises across the whole template, sorting both levels by it fixes the group
   order and the within-group order at once.
2. **Hide the field-label rows.** The table is showing Tableau's field names as headers:
   "Col Group / Col Label" across the top and "Metric" twice on the left. Turn them off:
   Analysis menu, uncheck Show Field Labels for Columns and Show Field Labels for Rows. Or
   right-click the "Col Group / Col Label" text, Hide Field Labels for Columns, and the
   same for Rows.
3. **Show empty rows.** As you slide the date, metrics with no events in that window drop
   out, which makes the table jump around. Analysis menu, Table Layout, tick Show Empty
   Rows. Now all 13 always show, blank where there is nothing.

### B. Legibility

4. **Widen the metric name column.** Names are cut off ("Patient Relate..", "Average
   Time .."). Drag its right border out, or double-click the border to auto-fit. Aim for
   about 230 px so the longest name fits on one line.
5. **Widen the group column so it stops stacking letters.** "AMTAGVI Regimen" is wrapping
   down to "AMTAG VI Regi men" because the column is too narrow. Give it about 100 px, or
   drop its font a point.
6. **Fix the column headers being cut off.** "Laun..", "202..", "Top ..", "Q3'2.." are all
   truncated. Two ways, use both: set the header font to 8 or 9 pt (Format, Font, Header),
   and widen the number columns a little. If Top 10 and Top 40 still collide, that is fine,
   they are short.
7. **Right-align the numbers.** They currently sit on the left of each cell, which is why
   the columns look ragged. Right-click the value field, Format, Alignment tab, set
   Horizontal to Right. Do this on both sheets. The percent and decimal values that look
   cut off ("12.5..", "20.0..") will show fully once the column is right-aligned and a
   touch wider.

### C. Keep it honest

8. **Mark the cancellation metric as an estimate.** Add an asterisk to the "TTPs Cancelled
   or Rescheduled" row label, and add one small Text object at the bottom of the dashboard
   reading: "TTP cancellations are estimated until the Infinity snapshot feed is
   connected." This is the proxy we already flagged.
9. **Leave the timing headers as Average Time, but confirm the value is a median.** The
   template wording stays. Check the Result calc still uses MEDIAN for the timing rows so
   the number under the header is the median, matching Kolin's own deck.

### D. Before you show it to the team

10. **Test the dropdown.** Change pCenter to another center and confirm both tables update
    and the benchmark columns (Top 10, Top 40, New) stay the same. Benchmarks are blinded
    and must not move with the center.
11. **Test the slider.** Drag the Event Date ends and confirm every number in the
    date-window table recomputes. Set it near 04/27/2026 and confirm the center reproduces
    the numbers on Kolin's real deck, which is the proof to show him.
12. **Clean the tooltips.** Right-click each sheet, Tooltip, and write it in plain words:
    the metric name, the column, and the value. No raw field names.
13. **Keep only Dashboard 3 for showing.** The Current Template and Proposed Template
    sheets are working tabs. The retiring quartile tab stays minimal. Present from the
    themed dashboard only.
14. **When it is signed off, publish.** Server menu, Publish Workbook, to Tableau Cloud, so
    the team gets the same dropdown and slider in a browser. Refresh cadence is in
    section 8: new export, run RUN_ALL, then Extract, Refresh.

### One thing that is already right

The right panel, windowed to 04/27/2026, is showing 10 patients enrolled, 7 completed
TTPs, 3 infusions, 1 drop-out, 1 OOS, and a 14.3% progression rate. That matches Kolin's
Albert B Chandler deck exactly. The build is correct. The work left here is order and
legibility, not the numbers.
