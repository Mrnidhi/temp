r"""
PPR pipeline - runs every stage in order.

Put the Infinity exports in data\ next to this file, then:
    python RUN_ALL.py

Six files. Four build the order table, two carry metric 3:
    bai_list_of_orders, bai_tumor_documentation, bai_infusion, veeva_komodo_atc_mapping
    LTD_Reschedules, LTD_Cancellations
data\README.md lists what each one feeds and what is optional.

Input resolution, first match wins: PPR_INPUT_DIR, then data\, then the local
test sample. To read from elsewhere:
    PowerShell:  $env:PPR_INPUT_DIR="C:\path\to\exports"
    CMD:         set PPR_INPUT_DIR=C:\path\to\exports

Stages:
    1. build_analysis_table.py  -> analysis/ppr_analysis.csv        (one row per order)
    2. build_cancellations.py   -> analysis/ppr_cancellations.csv   (metric 3 from history)
    3. build_scorecard.py       -> analysis/ppr_scorecard_tidy.csv  (the 13 metrics)
    4. build_datewindow.py      -> analysis/ppr_datewindow_long.csv (date-filter source)
    5. build_hyper.py           -> tableau/*.hyper                  (Tableau extracts)
    6. build_dashboard_html.py  -> dashboard/ppr_scorecard.html     (standalone browser view)

Refresh the Tableau extracts after a run. First-time workbook build: README.md section 4.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PIPE = os.path.join(HERE, "pipeline")

STEPS = [
    ("build_analysis_table.py", "joining the 7 Infinity files into one order-grain table"),
    ("build_cancellations.py",  "counting metric 3 short-notice lost slots"),
    ("build_scorecard.py",      "computing the 13 scorecard metrics"),
    ("build_datewindow.py",     "building the event-level date-window source"),
    ("build_hyper.py",          "writing the Tableau .hyper extracts"),
    ("build_dashboard_html.py", "rendering the standalone HTML scorecard"),
]

# Regression check after a change: python pipeline/baseline.py diff


def main() -> int:
    # First match wins; stage 1 resolves the same way.
    candidates = [os.environ.get("PPR_INPUT_DIR"),
                  os.path.join(HERE, "data"),
                  os.path.join(HERE, "synthetic_data", "out")]
    src = next((p for p in candidates if p and os.path.isdir(p)
                and any(f.endswith(".xlsx") for f in os.listdir(p))), None)
    if not src:
        print("No input found. Put the 7 Infinity .xlsx exports in:", flush=True)
        print("   " + os.path.abspath(os.path.join(HERE, "data")), flush=True)
        print("(or set PPR_INPUT_DIR to the folder holding them).", flush=True)
        return 1

    src = os.path.abspath(src)
    xlsx = sorted(f for f in os.listdir(src) if f.endswith(".xlsx"))
    print("=" * 62, flush=True)
    print("PPR pipeline", flush=True)
    print("input:", src, flush=True)
    print(f"found: {len(xlsx)} .xlsx files", flush=True)
    print("=" * 62, flush=True)

    # A test-sample run that reads like a real one is the dangerous case.
    if "synthetic" in src.lower():
        print("!" * 62, flush=True)
        print("  TEST SAMPLE DATA. Every number this run produces is made up.", flush=True)
        print("  For real numbers put the seven Infinity exports in:", flush=True)
        print("     " + os.path.abspath(os.path.join(HERE, "data")), flush=True)
        print("!" * 62, flush=True)
    # Name what is missing up front. Stage 1 would stop on a missing required file anyway,
    # but only on the first one, so a single run would not show the whole gap.
    present = [f.lower().replace(" ", "").replace("-", "").replace("_", "")
               for f in os.listdir(src)]
    REQUIRED = ["listoforders", "tumordocumentation", "infusion", "komodoatcmapping"]
    METRIC3 = ["ltdreschedules", "ltdcancellations"]
    missing = [s for s in REQUIRED if not any(s in f for f in present)]
    if missing:
        print(f"\nMissing required export(s): {missing}", flush=True)
        print("Stage 1 will stop. See data\\README.md.\n", flush=True)
    if not any(any(s in f for f in present) for s in METRIC3):
        print("\nNeither LTD export is here, so metric 3 falls back to the snapshot history "
              "or the proxy.", flush=True)
        print("The source used is printed at stage 2 and recorded in run_meta.json.\n",
              flush=True)

    # Pass the resolved folder down so no stage can pick a different one.
    env = {**os.environ, "PPR_INPUT_DIR": src}

    for i, (script, what) in enumerate(STEPS, 1):
        path = os.path.join(PIPE, script)
        if not os.path.exists(path):
            print(f"\n[{i}/{len(STEPS)}] MISSING {script} - stopping.", flush=True)
            return 1
        print(f"\n[{i}/{len(STEPS)}] {script}: {what}", flush=True)
        r = subprocess.run([sys.executable, path], cwd=PIPE, env=env)
        if r.returncode != 0:
            print(f"\nFAILED at {script}. Nothing after this step ran.", flush=True)
            print("Fix the error above and run again.", flush=True)
            return r.returncode

    print("\n" + "=" * 62, flush=True)
    print("Done. Outputs:", flush=True)
    print("  analysis/ppr_analysis.csv", flush=True)
    print("  analysis/ppr_scorecard_tidy.csv", flush=True)
    print("  analysis/ppr_datewindow_long.csv", flush=True)
    print("  tableau/ppr_scorecard.hyper", flush=True)
    print("  tableau/ppr_analysis.hyper", flush=True)
    print("  tableau/ppr_datewindow.hyper", flush=True)
    print("  dashboard/ppr_scorecard.html       (standalone, open in any browser)", flush=True)
    print("\nNext: Tableau Desktop. First time: README.md section 4. After: just refresh extracts.", flush=True)
    print("=" * 62, flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
