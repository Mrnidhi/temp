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
