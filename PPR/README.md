# PPR Automation

Auto-filling Patient & Process Review (P&PR) scorecard: pick an ATC center, the 13
review metrics fill from the Infinity data across the time / peer-benchmark / quarter
columns of Kolin's (Proposed) P&PR Metrics template. Replaces the manual
Infinity -> Excel -> slide workflow. Output is a native Tableau extract.

## Quick start (office laptop, real data)
1. Put all your Infinity Excel files in **one folder**. By default that is `PPR/data/`
   (just drop them in). The pipeline uses these 5 (filenames may have date suffixes,
   matching is flexible): `list_of_orders`, `tumor_documentation`, `infusion`,
   `slot_data`, `komodo_atc_mapping`. Extra files are ignored.
2. If your folder is somewhere else, set the path once in `pipeline/config.py` (`DATA_DIR`).
3. Run:
```
pip install -r requirements.txt
python pipeline/build_analysis_table.py
python pipeline/build_scorecard.py
python pipeline/build_hyper.py
```
4. In Tableau: **Data > ppr_scorecard Extract > Refresh** (or connect to the new
   `tableau/ppr_scorecard.hyper`). Build the workbook itself per `tableau/Tableau build spec.md`.

## What each piece does
```
data/                         your Infinity Excel files (git-ignored, never committed)
pipeline/config.py            the ONE place you set the data folder path
pipeline/build_analysis_table.py   reads the 5 files -> one order-grain table (analysis/ppr_analysis.csv)
pipeline/build_scorecard.py        computes the 13 metrics + median peer benchmarks (tidy table)
pipeline/build_hyper.py            packs the tidy table into tableau/ppr_scorecard.hyper
tableau/Tableau build spec.md      step-by-step recipe to build/verify the dashboard in Desktop
requirements.txt                   pip install -r this first
```
Only `build_analysis_table.py` reads your raw files (via `config.DATA_DIR`); the other two
work off the intermediate outputs. Everything except the 5 input files is regenerated on each run.

## Metric definitions
Follow Kolin's exact definitions (memory spec `ppr-scorecard-spec.md`, from his Meet 6
walkthrough + template footnotes). Highlights:
- Enrollments = count of orders; Patients = distinct patient IDs.
- 2nd Resections = patients with 2+ real TTP dates.
- Patient Progression Rate = patient-related drop-offs after mfg start / mfg starts.
- Peer benchmark (Top 10 / Top 40 / New) = the per-center **median** within the tier,
  launch-to-date (not the tier total, not the average).

Two metrics run on documented stand-ins until real fields are wired in: the 7-day
cancellation metric needs Infinity's snapshot history (Jonathan's), and the "New" tier
needs each center's onboarding year.

## Safety
`data/*` is git-ignored (only `data/README.md` is tracked). Real Infinity data must never
be committed or pushed - only the code moves through GitHub.
