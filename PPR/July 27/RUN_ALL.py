"""
PPR pipeline - run everything, in order.

Usage (office laptop, real Infinity files):
    set PPR_INPUT_DIR to the folder holding the 7 Infinity .xlsx files, then:
        python RUN_ALL.py

    PowerShell:  $env:PPR_INPUT_DIR="C:\\path\\to\\real_files"
                 python RUN_ALL.py
    CMD:         set PPR_INPUT_DIR=C:\\path\\to\\real_files
                 python RUN_ALL.py

Without PPR_INPUT_DIR it runs on the synthetic sample, which is fine for a dry run.

Order:
    1. build_analysis_table.py  -> analysis/ppr_analysis.csv        (one row per order)
    2. build_scorecard.py       -> analysis/ppr_scorecard_tidy.csv  (the 13 metrics)
    3. build_datewindow.py      -> analysis/ppr_datewindow_long.csv (date-filter source)
    4. build_hyper.py           -> tableau/*.hyper                  (Tableau extracts)

Then build/refresh the workbook in Tableau Desktop from the .hyper extracts.
One-time build recipe: README.md section 4. After that, refresh only.
"""
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
PIPE = os.path.join(HERE, "pipeline")

STEPS = [
    ("build_analysis_table.py", "joining the 7 Infinity files into one order-grain table"),
    ("build_scorecard.py",      "computing the 13 scorecard metrics"),
    ("build_datewindow.py",     "building the event-level date-window source"),
    ("build_hyper.py",          "writing the Tableau .hyper extracts"),
]


def main() -> int:
    # Input, first match wins: PPR_INPUT_DIR env var, then data/ next to this
    # file, then the synthetic sample. Stage 1 applies the same order.
    candidates = [os.environ.get("PPR_INPUT_DIR"),
                  os.path.join(HERE, "data"),
                  os.path.join(HERE, "..", "..", "..", "PPR Automation", "synthetic_data", "out")]
    src = next((p for p in candidates if p and os.path.isdir(p)
                and any(f.endswith(".xlsx") for f in os.listdir(p))), None)
    if not src:
        print("No input found. Create a data/ folder next to RUN_ALL.py holding the")
        print("7 Infinity .xlsx files (or set PPR_INPUT_DIR to their folder).")
        return 1

    print("=" * 62)
    print("PPR pipeline")
    print("input:", src)
    print("=" * 62)

    for i, (script, what) in enumerate(STEPS, 1):
        path = os.path.join(PIPE, script)
        if not os.path.exists(path):
            print(f"\n[{i}/{len(STEPS)}] MISSING {script} - stopping.")
            return 1
        print(f"\n[{i}/{len(STEPS)}] {script}: {what}")
        r = subprocess.run([sys.executable, path], cwd=PIPE)
        if r.returncode != 0:
            print(f"\nFAILED at {script}. Nothing after this step ran.")
            print("Fix the error above and run again.")
            return r.returncode

    print("\n" + "=" * 62)
    print("Done. Outputs:")
    print("  analysis/ppr_analysis.csv")
    print("  analysis/ppr_scorecard_tidy.csv")
    print("  analysis/ppr_datewindow_long.csv")
    print("  tableau/ppr_scorecard.hyper")
    print("  tableau/ppr_analysis.hyper")
    print("  tableau/ppr_datewindow.hyper")
    print("\nNext: Tableau Desktop. First time: README.md section 4. After: just refresh extracts.")
    print("=" * 62)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
