r"""
PPR pipeline - run everything, in order.

OFFICE LAPTOP
    The project lives at:
        C:\Users\SGowda\OneDrive - Iovance Biotherapeutics\Desktop\PPR Automation\VS Code

    Put the seven Infinity .xlsx exports in the data\ folder already sitting there,
    then from that folder:
        python RUN_ALL.py

    Nothing else to configure. data\ is found automatically because it is next to
    this file. Real data never leaves the laptop; only code and printed numbers travel.

    To read from somewhere else instead, set PPR_INPUT_DIR first:
        PowerShell:  $env:PPR_INPUT_DIR="C:\path\to\real_files"
        CMD:         set PPR_INPUT_DIR=C:\path\to\real_files

MAC / DEV
    With no data\ folder it falls back to the synthetic sample. That is fine for a dry
    run, and the header says so in a block of exclamation marks you cannot miss. Every
    number from a synthetic run is a property of the generator, not of the world.

Order:
    1. build_analysis_table.py  -> analysis/ppr_analysis.csv        (one row per order)
    2. build_cancellations.py   -> analysis/ppr_cancellations.csv   (metric 3 from history)
    3. build_scorecard.py       -> analysis/ppr_scorecard_tidy.csv  (the 13 metrics)
    4. build_datewindow.py      -> analysis/ppr_datewindow_long.csv (date-filter source)
    5. build_hyper.py           -> tableau/*.hyper                  (Tableau extracts)
    6. build_dashboard_html.py  -> dashboard/ppr_scorecard.html     (standalone browser view)

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
    ("build_cancellations.py",  "counting metric 3 cancellations from the snapshot history"),
    ("build_scorecard.py",      "computing the 13 scorecard metrics"),
    ("build_datewindow.py",     "building the event-level date-window source"),
    ("build_hyper.py",          "writing the Tableau .hyper extracts"),
    ("build_dashboard_html.py", "rendering the standalone HTML scorecard"),
]

# After a run: python pipeline/baseline.py diff
# Reports every cell that moved against the frozen reference. Freeze once with
# `baseline.py freeze`, then diff after every change. A change with no diff is safe.


def main() -> int:
    # Input, first match wins: PPR_INPUT_DIR env var, then data/ next to this
    # file, then the synthetic sample. Stage 1 applies the same order.
    candidates = [os.environ.get("PPR_INPUT_DIR"),
                  os.path.join(HERE, "data"),
                  os.path.join(HERE, "..", "..", "..", "PPR Automation", "synthetic_data", "out")]
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

    # A synthetic run that looks like a real one is the dangerous case, and the path
    # above is easy to skim past. Say it outright instead.
    if "synthetic" in src.lower():
        print("!" * 62, flush=True)
        print("  SYNTHETIC DATA. Every number this run produces is made up.", flush=True)
        print("  For real numbers put the seven Infinity exports in:", flush=True)
        print("     " + os.path.abspath(os.path.join(HERE, "data")), flush=True)
        print("!" * 62, flush=True)
    if len(xlsx) < 7:
        print(f"\nOnly {len(xlsx)} of the 7 expected exports are here:", flush=True)
        for f in xlsx:
            print("   " + f, flush=True)
        print("Stage 1 will stop and name whichever one it cannot find.\n", flush=True)

    # Hand the resolved folder down rather than letting each stage resolve it again.
    # They apply the same rules, but a stage reading a different folder than the one
    # printed above would be silent and would poison every output after it.
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
