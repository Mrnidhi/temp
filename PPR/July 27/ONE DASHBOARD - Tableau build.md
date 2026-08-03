# One dashboard, one sheet, with the date filter built in

Replaces the two-sheet design. Previously the scorecard was precomputed, so it had no dates
left to filter, and the date window had to live on a second sheet fed by a second source.
That is gone: the event table now carries the template columns itself, so a single worksheet
renders the whole scorecard **and** responds to a date filter.

Verified before writing this: rendering the event table as a table reproduces the
precomputed scorecard on **3,308 of 3,309 cells**. The one exception is documented at the
bottom.

---

## How it works, in one paragraph

Every metric event is emitted once per template column it falls into. An infusion on
2025-03-14 appears as a row for `Launch to Date`, a row for `2025`, and nothing else. That
turns the column headers into an ordinary dimension, which is what lets one worksheet show
them all. Each event is *also* emitted once more tagged `Selected window`. A single filter
calc applies the date parameters to those rows only, so dragging the slider changes that one
column and leaves 2024 and 2025 untouched. Without that split, dragging the dates would blank
out the fixed columns.

---

## Build it (about 10 minutes)

### 1. Connect
Data > New Data Source > More > `tableau/ppr_datewindow.hyper` > drag the **Events** table on.

Fields you will use: `center`, `metric_group`, `metric_order`, `metric`, `col_label`,
`col_order`, `agg`, `event_date`, `value`, `unit`.

### 2. Parameters
- **pCenter** — String, list, Add values from field > `center`.
- **pStart** — Date, default 2025-01-01.
- **pEnd** — Date, default 2026-05-05.

### 3. Three calculated fields

**Keep Center**
```
[center] = [pCenter]
```

**Keep Row** — the piece that makes one sheet work.
```
IF [col_label] = "Selected window"
THEN [event_date] >= [pStart] AND [event_date] <= [pEnd]
ELSE TRUE
END
```

The dates bite only on the live column. Every template column passes through untouched, so
2024, 2025 and the quarters stay on screen as anchors while the reviewer asks about a period beside
them.

They deliberately do not filter the template columns. If the dates applied to `2024` as well,
that column would show the overlap between 2024 and the slider, which is empty whenever the
slider sits outside 2024. A column headed 2024 reading zero because of a filter elsewhere on
the sheet is the kind of thing that destroys trust in a number.

**Result** — one expression covering all four aggregation kinds.
```
IF ATTR([agg]) = "sum" THEN STR(INT(SUM([value])))
ELSEIF ATTR([agg]) = "distinct" THEN STR(COUNTD([unit]))
ELSEIF ATTR([agg]) = "avg" THEN STR(ROUND(MEDIAN([value]), 1))
ELSEIF ATTR([agg]) = "rate" THEN STR(ROUND(AVG([value]) * 100, 1)) + "%"
END
```
`distinct` exists because a distinct count cannot be precomputed: how many distinct patients
enrolled depends on the window you ask about, so the dedup has to happen at read time.

### 4. The worksheet
- Name it `P&PR Scorecard`.
- **Filters:** `Keep Center` = True, `Keep Row` = True.
- **Columns:** `col_order` then `col_label`. Right-click `col_order` > Discrete, then
  untick Show Header. It exists only to hold the template order.
- **Rows:** `metric_group`, then `metric_order` (Discrete, Show Header off), then `metric`.
- **Marks:** Text = `Result`.
- Analysis > Table Layout > Show Empty Rows, so a metric with nothing in a window still
  shows its row.

### 5. The dashboard
- New dashboard, 1400 x 850. Drag the sheet in.
- Show all three parameter controls: pCenter, pStart, pEnd.
- Title band navy `#17344F` with white text, footer band lime `#9DC13C` with navy text.

That is the whole build. One source, one sheet, one dashboard.

---

## How it is used

Pick a centre. Read the fixed columns exactly as before. When he wants a different period,
drag the two dates and read the **Selected window** column. Nothing else moves.

To reproduce one of his existing decks, set the dates to that deck's window and compare the
Selected column against his slide.

---

## Columns and what they mean

| Column | Meaning |
|---|---|
| Launch to Date | everything, including undated events |
| 2024 / 2025 / 2026 YTD | calendar periods, each event counted on its own event date |
| Undated | real events with no usable date, so they belong to no period |
| After as-of | dated beyond the extract date |
| Selected window | whatever the two date parameters are set to |
| Q3'26 QTD … Q4'25 | the four template quarters |

`Undated` and `After as-of` exist so the period columns cannot silently lose events.
Launch to Date equals the year columns plus those two, and the pipeline asserts it on every
run. Without them, an out-of-spec product that was never delivered, or a procurement that was
cancelled and so never happened, would vanish from every period column while still counting
in the total — which biases every period optimistic.

---

## Known limitation

**2nd Resections** is deduped across all time rather than per window, so in a narrow window
it can differ by one from the precomputed scorecard. Measured: 1 cell in 3,309 on the
synthetic set. Rendering it correctly per window needs an LOD calculation; left alone until
someone asks for that metric by window.
