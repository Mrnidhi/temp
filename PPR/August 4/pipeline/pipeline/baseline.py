"""
Golden baseline and regression diff.

Nothing else in this plan is safe without it. Today one centre has been validated by hand
and there is no way to tell whether a change moved a number somewhere else. This freezes
every output, then reports exactly what a later change did.

    python baseline.py freeze     capture current outputs as the reference
    python baseline.py diff       compare current outputs against the reference
    python baseline.py show       what is in the reference and when it was taken

Freeze BEFORE changing any calculation. Diff after every change. A diff of zero rows is the
only evidence that a refactor was safe.

Patient-level data stays out of the repository, so the reference is machine-local and
stores aggregates and hashes only, never order-level rows.
"""
import hashlib
import json
import os
import sys

import pandas as pd

HERE = os.path.dirname(os.path.abspath(__file__))
ANA = os.path.join(HERE, "..", "analysis")
REF = os.path.join(HERE, "..", "baseline")

# Files worth guarding, and the columns that identify one cell of the output.
TRACKED = {
    "ppr_scorecard_tidy.csv": ["scope", "center", "col_label", "metric"],
    "ppr_datewindow_long.csv": ["center", "metric", "agg", "event_date"],
}


def digest(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()[:16]


def load(name):
    path = os.path.join(ANA, name)
    if not os.path.exists(path):
        sys.exit(f"missing {name}. Run RUN_ALL.py first.")
    return pd.read_csv(path, low_memory=False), path


def freeze(asof):
    os.makedirs(REF, exist_ok=True)
    meta = {"asof": asof, "files": {}}
    for name, keys in TRACKED.items():
        df, path = load(name)
        df.to_csv(os.path.join(REF, name), index=False)
        meta["files"][name] = {"rows": len(df), "sha256_16": digest(path),
                               "keys": keys, "columns": list(df.columns)}
        print(f"froze {name:28s} {len(df):>7,} rows  {meta['files'][name]['sha256_16']}")
    with open(os.path.join(REF, "baseline.json"), "w") as f:
        json.dump(meta, f, indent=2)
    print(f"\nreference written to {os.path.relpath(REF, HERE)}")
    print("Diff against it after every change. Machine-local, never committed: a reference")
    print("frozen on the test sample says nothing about the data, and a reference frozen")
    print("on the data would put patient rows in the repo.")


def diff():
    mpath = os.path.join(REF, "baseline.json")
    if not os.path.exists(mpath):
        sys.exit("No baseline. Run: python baseline.py freeze")
    meta = json.load(open(mpath))
    print(f"reference taken as-of {meta['asof']}\n")

    total_changed = 0
    for name, keys in TRACKED.items():
        new, path = load(name)
        old = pd.read_csv(os.path.join(REF, name), low_memory=False)

        if digest(path) == meta["files"][name]["sha256_16"]:
            print(f"{name}: identical")
            continue

        added = set(new.columns) - set(old.columns)
        dropped = set(old.columns) - set(new.columns)
        if added or dropped:
            print(f"{name}: columns added {sorted(added) or 'none'}, "
                  f"dropped {sorted(dropped) or 'none'}")

        # compare the value of every cell that exists in both, keyed on grain
        vcol = "value"
        if vcol not in new.columns or vcol not in old.columns:
            print(f"{name}: no '{vcol}' column, comparing row counts only "
                  f"({len(old):,} -> {len(new):,})")
            continue

        o = old[keys + [vcol]].rename(columns={vcol: "was"})
        n = new[keys + [vcol]].rename(columns={vcol: "now"})
        j = o.merge(n, on=keys, how="outer", indicator=True)

        gone = j[j._merge == "left_only"]
        fresh = j[j._merge == "right_only"]
        both = j[j._merge == "both"].copy()
        both["delta"] = both["now"] - both["was"]
        moved = both[both.delta.abs() > 1e-9]

        total_changed += len(moved) + len(gone) + len(fresh)
        print(f"\n{name}")
        print(f"  rows        {len(old):,} -> {len(new):,}")
        print(f"  cells moved {len(moved):,}")
        print(f"  cells gone  {len(gone):,}")
        print(f"  cells new   {len(fresh):,}")

        if len(moved):
            by_metric = (moved.groupby("metric")
                         .agg(cells=("delta", "size"), biggest=("delta", lambda s: s.abs().max()))
                         .sort_values("cells", ascending=False))
            print("\n  by metric:")
            print(by_metric.to_string())
            print("\n  largest 10 moves:")
            cols = keys + ["was", "now", "delta"]
            print(moved.reindex(moved.delta.abs().sort_values(ascending=False).index)
                  [cols].head(10).to_string(index=False))

    print("\n" + "=" * 60)
    if total_changed == 0:
        print("NO CHANGE. Safe.")
    else:
        print(f"{total_changed:,} cells differ from the reference.")
        print("Every one of these must be explained before shipping. If a change was")
        print("intended, re-freeze. If it was not, it is a regression.")


def show():
    mpath = os.path.join(REF, "baseline.json")
    if not os.path.exists(mpath):
        sys.exit("No baseline yet.")
    meta = json.load(open(mpath))
    print(f"as-of {meta['asof']}")
    for name, info in meta["files"].items():
        print(f"  {name:28s} {info['rows']:>7,} rows  {info['sha256_16']}  "
              f"grain: {' + '.join(info['keys'])}")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "diff"
    if cmd == "freeze":
        freeze(os.environ.get("PPR_ASOF", "2026-07-21"))
    elif cmd == "diff":
        diff()
    elif cmd == "show":
        show()
    else:
        sys.exit(__doc__)
