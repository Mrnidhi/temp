Here's the complete, self-contained instruction set. Copy everything below and hand it to the Tableau Copilot (or follow it top-to-bottom yourself). It assumes you're connected to the **`ppr_scorecard Extract`** (table `Scorecard`) — which you already are — and that the `pCenter` parameter and `Keep Row` field already exist in your list (they do).

---

# P&PR Scorecard — Complete Build Instructions

**Data source:** `ppr_scorecard Extract`, table `Scorecard`.
**Grain:** one row per center × column × metric. Each cell is a single value, pre-formatted in the field `Value Display`.

## 1. Parameter (skip if `pCenter` already exists)
Create a String parameter named **`pCenter`**. Allowable values = List, populated from the field **`Center`** (Add values from field → Center). Default = any center.

## 2. Calculated field (skip if `Keep Row` already exists)
Create a boolean calc field named **`Keep Row`** with this formula:
```
([Scope] = "Center" AND [Center] = [pCenter]) OR [Scope] = "National"
```

## 3. Build the worksheet (rename it "P&PR Scorecard")
- **Filters:** add `Keep Row`, keep only **True**.
- **Columns shelf:** place `Col Group`, then `Col Label` (both discrete/blue), in that order.
- **Rows shelf:** place `Metric Group`, then `Metric` (both discrete), in that order.
- **Marks card:** set mark type to **Text**. Drag **`Value Display`** onto **Text** (it becomes `ATTR([Value Display])`).

## 4. Sorting (critical — matches Kolin's template order)
Apply a "Sort by Field, Minimum, Ascending" on each of these four pills:
- `Col Group` → sort by field **`Col Order`**, Minimum, Ascending
- `Col Label` → sort by field **`Col Order`**, Minimum, Ascending
- `Metric Group` → sort by field **`Metric Order`**, Minimum, Ascending
- `Metric` → sort by field **`Metric Order`**, Minimum, Ascending

Correct result: columns read **Time (Launch to Date, 2024, 2025, 2026 YTD) → Benchmark (Top 10, Top 40, New) → Quarter (Q3'26 QTD, Q2'26, Q1'26, Q4'25)**; rows read **Patient Identification & Enrollment → Tumor Tissue Procurement → AMTAGVI Regimen → AMTAGVI Treatment Timelines**.

## 5. Rename the column-group headers (aliases on `Col Group`)
Edit Alias on each `Col Group` member:
- `Time` → **This Center**
- `Benchmark` → **YTD National Metrics**
- `Quarter` → **Quarterly ATC Metrics**

## 6. Formatting (Iovance house style)
- **Hide field labels:** right-click the column field labels → Hide Field Labels for Columns; do the same for Rows.
- **Borders:** Format → Borders → Sheet tab → set **Cell** and **Pane** to a thin light-grey solid line.
- **Header shading:** shade the column header row olive green **#567A2E** with white **bold italic** text.
- **Benchmark tint:** give the three benchmark columns (Top 10 / Top 40 / New) a light steel fill **#EEF3F9**.
- **Fit:** Analysis → Table Layout, or set the view to **Fit Width** so all 11 columns and full metric names are readable (no truncation like "Enroll..").

## 7. Build the dashboard (name it "P&PR Scorecard")
- New Dashboard. Size: **Fixed 1300 × 850** (or Automatic).
- Drag the **P&PR Scorecard** worksheet onto the canvas.
- **Show the `pCenter` parameter control** as a dropdown; position it at the **top-left**.
- Add a **Text** object at the top as the title: **"Patient & Process Review Scorecard"**.
- Add a smaller **Text** object below/right: **"Source Data As of: July 21, 2026"**.
- Add a small footnote Text object at the bottom: **"'TTPs Cancelled within 7 Days' and the 'New' ATC tier are placeholders pending the Infinity snapshot feed and center onboarding-year source. Built on preview data."**

## 8. Verify
- Change `pCenter` in the dropdown → the This Center and Quarterly columns should update; the Top 10 / Top 40 / New columns stay constant.
- Counts are whole numbers, Patient Progression Rate shows a percent, timelines show one decimal.
- "Launch to Date" equals the sum of 2024 + 2025 + 2026 YTD for the count rows.

---

Go build it with the Copilot, and come back with a screenshot of the finished dashboard — I'll do a final review and we can then plan the real-Infinity data swap.