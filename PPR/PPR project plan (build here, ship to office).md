# PPR Automation - project plan

The real Infinity data cannot leave the office network. So we build the whole
dashboard here on synthetic data that matches the real files exactly, then ship
the finished work to the office laptop, where it gets pointed at the real data.

## The two machines
- **Office laptop**: has the real Infinity CSVs and now has Claude access. Real
  data stays here. Used only to (a) read out the true schema of each file and
  (b) run the final build against real data.
- **Home machine (this one)**: has full Claude Code + Tableau + MCP. All the
  building happens here on synthetic data.

## The pipeline
1. **Office laptop**: upload the real Infinity CSVs into a Claude project. Ask
   Claude there to profile each file and export a schema-only description:
   column names, dtypes, null rates, value ranges, and the distinct values of
   categorical columns. No real row values leave the office.
2. **Home**: paste that schema profile in here. Claude generates a synthetic
   dataset that matches it exactly (same columns, dtypes, null patterns,
   category sets, plausible distributions, correct cross-file join keys).
3. **Home**: build the Tableau dashboard against the synthetic data, wiring
   Tableau to Claude over MCP so the calcs, the 14 metrics, the center picker,
   and the benchmark buckets all get developed and tested here.
4. **Ship**: push the finished workbook + any prep scripts to GitHub.
5. **Office laptop**: pull from GitHub, repoint the same workbook from the
   synthetic file to the real Infinity connection, refresh. Numbers fill.

## Why this works
The synthetic data is a stand-in with an identical shape, so a workbook that
works here works there after a connection swap. Nothing confidential crosses
machines except column-level schema.

## Status
- [x] Step 1: schema profiled on office laptop (7 files). Transcribed to
  `Infinity schema profile (from office laptop).md`.
- [x] Step 2: synthetic dataset generated and QA'd against the profile
  (`synthetic_data/generate_synthetic.py` -> `synthetic_data/out/*.xlsx`).
  Columns, dtypes, null rates, categoricals, ID formats, the funnel joins
  (2250 orders -> 1643 slot -> 869 tumor / 1126 rows -> 1002 infusion,
  537 infusion∩tumor), and the ~94% fuzzy center join all match.
- [x] Step 3: dashboard built. Portable pipeline (`pipeline/`) -> tidy scorecard;
  `PPR Scorecard.twbx` (Tableau, hand-authored - validate in Desktop); working
  interactive preview `dashboard/ppr_scorecard.html` (published as an Artifact).
  13 P&PR metrics, center picker, time/benchmark/quarter columns, KPI strip.
- [ ] Step 3b: open the .twbx in Tableau Desktop, confirm it renders / polish design
  (later via MCP). Confirm the open definitions with Kolin (see README).
- [ ] Step 4: push to GitHub.
- [ ] Step 5: office laptop pulls, repoints to real Infinity, refreshes.
