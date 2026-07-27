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
    5. gen_workbook.py          -> PPR Dashboard.twbx               (finished workbook)

Then open PPR Dashboard.twbx in Tableau Desktop. See README.md.
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
    ("gen_workbook.py",         "authoring PPR Dashboard.twbx"),
]


def main() -> int:
    src = os.environ.get("PPR_INPUT_DIR")
    if not src:
        print("PPR_INPUT_DIR is not set.\n")
        print("Set it to the folder holding the 7 Infinity .xlsx files, then run again:")
        print('  PowerShell:  $env:PPR_INPUT_DIR="C:\\path\\to\\real_files"')
        print("  CMD:         set PPR_INPUT_DIR=C:\\path\\to\\real_files")
        print("  Mac/Linux:   export PPR_INPUT_DIR=/path/to/real_files")
        return 1
    if not os.path.isdir(src):
        print(f"PPR_INPUT_DIR points at a folder that does not exist:\n  {src}")
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
    print("  PPR Dashboard.twbx")
    print("\nNext: open 'PPR Dashboard.twbx' in Tableau Desktop. See README.md.")
    print("=" * 62)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
