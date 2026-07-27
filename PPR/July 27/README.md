# PPR bundle - July 27

What changed since July 23, and the build order for the office laptop.

## What's new
1. **Per-metric event dating** (confirmed by Kolin's real decks). Every year/quarter/window column
   counts each metric on its own event date, not the enrollment date. Baked into `build_scorecard.py`.
2. **Main dashboard = date-window scorecard.** Pick a center + a date range, the 13 metrics recompute
   for that window. Easy controls (center dropdown + two date calendars) that all viewers get on publish.
3. **Current Template** target is the quartile-RANGE layout from Kolin's real slide (heat-colored cell).

## Files
- `tableau/MAIN DASHBOARD - Tableau Desktop build (office laptop).md` - the main build, step by step.
- `tableau/Tableau build spec.md` - the fixed-column Proposed/Current template tabs.
- `tableau/ppr_analysis.hyper` (Orders, order-grain, has raw dates) - source for the date-window dashboard.
- `tableau/ppr_scorecard.hyper` (Scorecard, pre-shaped) - source for the fixed template tabs.
- `pipeline/*.py` - updated pipeline; rerun on the real Infinity files, then `build_hyper.py`.
- `Real PPR slides - Kolin ...md` - the target output (his two per-center decks, transcribed).
- `DATA DICTIONARY ...md` - every dataset and column.

## Build order (office laptop)
1. Drop the real Infinity exports into `synthetic_data/out/` (same 7 filenames), rerun the pipeline,
   rerun `build_hyper.py`. The `.hyper` files refresh with real data; the workbook view is unchanged.
2. Open Tableau Desktop, follow `MAIN DASHBOARD ...md` to build the date-window dashboard.
3. Publish to Tableau Cloud. Every viewer gets the center dropdown + date calendars.

## Note on Tableau Cloud (personal laptop, 07-27)
Confirmed by test: Tableau Cloud web will NOT upload a `.twbx` workbook (needs Desktop to publish),
but it DOES accept a raw data file (CSV/xlsx) and builds worksheets fine. The date filter was proven
working there on the synthetic data. The polished, styled, publishable build happens here on Desktop.
