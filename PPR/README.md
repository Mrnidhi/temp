# PPR Automation

Auto-filling Patient & Process Review (P&PR) scorecard: pick an ATC center, the 13
metrics fill from Infinity data across time / benchmark / quarter columns. Replaces
Kolin's manual Infinity -> Excel -> slide workflow.

Real Infinity data cannot leave the office network, so everything is built here on
synthetic data that matches the real schema exactly, then shipped to the office
laptop to run on the real files. See `PPR project plan (build here, ship to office).md`.

## Quick start on the office laptop (real data)
Put the 5 required Infinity files in one folder (names may have date suffixes; the loader
matches flexibly): `list_of_orders`, `tumor_documentation`, `infusion`, `slot_data`,
`komodo_atc_mapping`. Then:
```
pip install -r requirements.txt
$env:PPR_INPUT_DIR="C:\path\to\real_files"   # PowerShell; points the pipeline at the real files
python pipeline/build_analysis_table.py
python pipeline/build_scorecard.py
python pipeline/build_hyper.py               # writes tableau/ppr_scorecard.hyper from real data
```
Then in Tableau: Data > `ppr_scorecard Extract` > Refresh (or repoint to the new .hyper).
Build the workbook itself per `tableau/Tableau build spec.md`. Without `PPR_INPUT_DIR` the
pipeline falls back to synthetic data.

## Layout
- `Infinity schema profile (from office laptop).md` - the real files' schema (blueprint).
- `synthetic_data/generate_synthetic.py` - builds 7 xlsx stand-ins in `out/`,
  matching columns, dtypes, null rates, categoricals, and the order funnel joins.
- `pipeline/` - the portable automation (point at real files, rerun):
  - `build_analysis_table.py`  -> `analysis/ppr_analysis.csv` (order grain + derived fields)
  - `build_scorecard.py`       -> `analysis/ppr_scorecard_tidy.csv` + `dashboard/scorecard_payload.json`
  - `build_hyper.py`           -> `tableau/*.hyper` (native Tableau extracts) **[primary output]**
  - `build_center_extras.py`   -> `dashboard/extras_payload.json` (parked network analytics)
  - `gen_twbx.py`              -> `PPR Scorecard.twbx` (starter Tableau workbook, unverified)
  - `build_dashboard_html.py`  -> `dashboard/ppr_scorecard.html` (HTML preview, secondary)

## Tableau is the primary deliverable
Build the dashboard natively in Tableau Desktop from `tableau/` following
`tableau/Tableau build spec.md`:
- `tableau/ppr_scorecard.hyper` (table `Scorecard`) - the tidy matrix; build the exact template
  off this with one calc field (`Keep Row`) and `ATTR([value_display])` on Text.
- `tableau/ppr_analysis.hyper` (table `Orders`) - order grain for native metric calc fields
  (the spec lists all 13 formulas, validated to match the pipeline exactly) and custom views.
The HTML dashboard is a preview only; I cannot render Tableau in this environment, so the office
laptop (real Tableau) is where the workbook is assembled and verified per the spec.

The HTML dashboard (`build_dashboard_html.py`) is the **mandated P&PR scorecard** exactly as
Kolin specified it: pick one ATC center and its 13 review metrics fill across the year, blinded
national-tier, and quarterly columns of the (Proposed) P&PR Metrics template, in Iovance house
style (navy/steel/olive/lime, olive-header black-grid table, Segoe UI). Metric definitions follow
the memory spec `ppr-scorecard-spec.md`, transcribed from Kolin's Meet 6 walkthrough and the
template footnotes (e.g. 2nd Resections = patients with 2+ TTP dates; Progression Rate = patient
drop-offs after mfg start / mfg starts; Top 10/40 = highest-enrolling in the timeframe).

Two metrics run on documented stand-ins pending real fields: the 7-day cancellation metric needs
Infinity's snapshot history (Jonathan's), and the "New" tier needs each center's onboarding year.

PARKED for later (not in the current dashboard): a leadership Network Command view (portfolio KPIs,
85-center leaderboard, below-peer watchlist, regional rollup) plus yield/funnel analytics. Its data
logic still lives in `build_center_extras.py` -> `extras_payload.json`; only the network HTML view
was set aside to keep the current build to exactly what Kolin asked for. See [[ppr-build-plan]].
- `PPR Scorecard.twbx` - Tableau workbook (open in Desktop; repoint to real data).
- `dashboard/ppr_scorecard.html` - working preview dashboard (also published as an Artifact).

## Rebuild everything
```
python synthetic_data/generate_synthetic.py
python pipeline/build_analysis_table.py
python pipeline/build_scorecard.py
python pipeline/build_hyper.py          # native Tableau extracts (primary)
python pipeline/build_dashboard_html.py # HTML preview (secondary)
# optional: build_center_extras.py (parked network data), gen_twbx.py (starter workbook)
```
Needs `pip install pantab tableauhyperapi` for the extract step.

## Ship to office laptop
1. Push this folder to GitHub.
2. On the office laptop, pull. Set `INPUT_DIR` in `build_analysis_table.py` to the
   real Infinity folder. Rerun stages 1-2 -> real `ppr_scorecard_tidy.csv`.
3. Refresh `PPR Scorecard.twbx` (or reopen the HTML pipeline). The view is unchanged.

## Open definitions to confirm with Kolin
- "Enrollments" = count of orders (TIL Order Name) vs distinct patients. (Currently: orders.)
- Which date defines an enrollment. (Currently: order_request__created_date.)
- Exact rule for "TTPs Cancelled/Rescheduled <=7d prior to slot reservation"
  (currently a proxy on resection_rescheduled_).
- "New ATC" onboarding source (currently proxied by lowest-volume centers on synthetic data).
