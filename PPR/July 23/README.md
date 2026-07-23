# P&PR Scorecard

Patient and Process Review scorecard for the AMTAGVI ATC network. Pick a center and its
13 review metrics fill across the year, the blinded peer tier, and the recent quarters.
Replaces the manual Infinity to Excel to slide workflow.

## Open it

Double click `PPR Scorecard.twbx` in Tableau Desktop. The data is packaged inside the
workbook, so it opens with everything connected and the table filled in. Nothing to wire up.

The workbook has two dashboards:
- **Proposed Template** - the mandated scorecard (center columns, blinded national tier, quarters)
- **Current Template** - the older view (this center against all-ATC quartiles and the national average)

Use the `pCenter` dropdown to switch centers. The peer benchmark columns stay fixed on purpose.

## What is in this folder

- `PPR Scorecard.twbx` - the workbook (opens standalone)
- `analysis/ppr_scorecard_tidy.csv` - the data the workbook is built on (one row per center x column x metric)
- `analysis/ppr_analysis.csv` - the order-grain table the scorecard is computed from
- `pipeline/` - the scripts that turn the seven Infinity files into the scorecard data
- `synthetic_data/generate_synthetic.py` - builds stand-in files that match the real schema
- `tableau/` - native `.hyper` extracts plus the build spec
- `Infinity schema profile (from office laptop).md` - the schema the whole thing is built to
- `requirements.txt` - Python dependencies

The numbers in the workbook right now are **synthetic**, built to match the real Infinity
schema exactly. Swapping in real data is the step below.

## Point it at the real Infinity data

The workbook view does not change. Only the numbers update.

1. Install the dependencies once:
   ```
   pip install -r requirements.txt
   ```
2. Put the seven real Infinity `.xlsx` exports in a folder, then point the pipeline at it:
   ```
   export PPR_INPUT_DIR="/path/to/real_infinity_files"     # Windows: set PPR_INPUT_DIR=...
   python pipeline/build_analysis_table.py                 # -> analysis/ppr_analysis.csv
   python pipeline/build_scorecard.py                      # -> analysis/ppr_scorecard_tidy.csv
   ```
   The file matcher is tolerant of the real names (case, separators, the date suffixes) and
   already knows the real files carry a banner row, so the true header is row 3.
3. In Tableau, open the workbook, then Data menu > `ppr_scorecard_tidy.csv` > Replace Data
   Source and point it at the freshly built `analysis/ppr_scorecard_tidy.csv`. Refresh.

That is the whole job. Every calc, the center picker, the aliases, and the formatting carry
over untouched.

## Notes carried from the build

- Two metrics run on documented stand-ins until the real fields land. The 7-day cancellation
  metric needs Infinity's snapshot history (Jonathan's feed). The 'New' tier needs each center's
  onboarding year, which is not in the current mapping export.
- Benchmark tiers (Top 10, Top 40, New) are the highest enrolling centers in the timeframe, so
  the set shifts over time. The benchmark value is the per-center median within the tier.
- Full metric definitions and the native calc-field formulas are in `tableau/Tableau build spec.md`.
