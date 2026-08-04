# P&PR Dashboard - Data Engineering Handoff (current state)

Written 2026-08-03 from the project files in this repo. Every claim is labeled
Confirmed / Inferred / TBD / Needs TWBX verification. The production Tableau
workbook lives on the office laptop and is not in this environment, so nothing
here is read from the workbook itself; workbook internals are marked
`Needs TWBX verification`.

## Dashboard Overview

- **Dashboard name:** P&PR Dashboard (Patient & Process Review Scorecard).
  Confirmed: `git/PPR/July 27/README.md` line 1.
- **Business purpose:** per-treatment-center review of the mandated 13 P&PR
  metrics against national tier benchmarks, for any date window. Replaces a
  manual Infinity-to-Excel-to-slide workflow. Confirmed: `PPR Automation/README.md`.
- **Main users:** the BAI team manager and reviewers in per-center review
  meetings; designed for non-Tableau users (one dropdown, two date pickers).
  Confirmed: `git/PPR/July 27/README.md` section 5.
- **Main KPIs:** 13 metrics in 4 groups - Patient Identification & Enrollment
  (enrollments, patients, short-notice TTP cancellations), Tumor Tissue
  Procurement (completed/scheduled TTPs, 2nd resections), AMTAGVI Regimen
  (drop-outs, OOS products, progression rate, infusions), AMTAGVI Treatment
  Timelines (three median day-counts). Confirmed: `git/PPR/July 27/pipeline/metrics.py`.
- **Current data sources:** 6 required manual Excel exports from the Infinity
  platform (4 core tables + the 2 metric-3 LTD files), plus optional
  `bai_slot_data`. Full list in [01_data_model.md](01_data_model.md).
- **Current final dataset used by Tableau:** `tableau/ppr_datewindow.hyper`,
  table `Events`. Confirmed: `git/PPR/July 27/README.md` section 4;
  `ONE DASHBOARD - Tableau build.md` section 1.
- **Current refresh process:** manual and on demand. Download exports from
  Infinity into `data\`, close Tableau, run `python RUN_ALL.py` (6 stages),
  reopen the workbook, refresh each extract. Confirmed:
  `git/PPR/July 27/README.md` section 8; `OFFICE LAPTOP - do this.md`.

## One-Sentence Architecture

Current state (the laptop flow this package documents):

```text
6 required Infinity Excel exports (+1 optional)
  -> Python pipeline (RUN_ALL.py, 6 stages: clean/join -> metric-3 events -> scorecard -> event table -> extracts -> HTML)
  -> tableau/ppr_datewindow.hyper (table Events)
  -> P&PR Dashboard workbook (Tableau Desktop, office laptop)
```

Agreed target architecture (2026-08-03, the goal every artifact in this
package now points at):

```text
Redshift raw tables (Infinity data landed by data engineering)
  -> daily Glue job (runs the same six-stage preparation, unchanged)
  -> final Events table lands back in Redshift (ppr.ppr_events)
  -> Tableau connects directly to that table
```

Tableau never connects to Infinity. The job files for this target live in
[glue/](glue/); the interactive data model is [ppr_data_model.html](ppr_data_model.html).

## Dataset Contract Summary

```text
Final Tableau dataset:   tableau/ppr_datewindow.hyper, table "Events" (from analysis/ppr_datewindow_long.csv)
Dataset grain:           one row per metric event per scorecard column it belongs to,
                         plus one "Selected window" copy per event, plus pre-aggregated
                         benchmark rows and zero-value stub rows (Confirmed: build_datewindow.py)
Expected unique key:     none by design - rows are intentional copies across column buckets
                         and same-day events emit identical rows (Confirmed by construction)
Refresh frequency:       on demand today; no scheduler exists anywhere in the project (Confirmed)
Current connection type: local .hyper files refreshed manually in Desktop per the build docs;
                         actual connection in the production workbook - Needs TWBX verification
Target Tableau link:     Redshift table ppr.ppr_events, refreshed only after the
                         daily Glue job succeeds (agreed 2026-08-03); the hyper
                         extract stays as a byproduct
```

## Files in This Handoff

1. [01_data_model.md](01_data_model.md) - sources, keys, joins, grains, cardinality risks
2. [02_data_flow.md](02_data_flow.md) - lineage diagram and the processing flow in 10 steps
3. [03_rules_and_questions.md](03_rules_and_questions.md) - exact processing rules, the
   Tableau input contract, TWBX verification checklist, and open questions
4. [ppr_data_model.html](ppr_data_model.html) - interactive crow's foot model of the whole
   preparation, hover any column for its formula
5. [glue/](glue/) - the daily job for the target architecture (job script, DDL, config,
   validation record)
6. [pipeline/](pipeline/) - the reference python implementation as it runs on the office
   laptop today; the Glue job must reproduce its output
