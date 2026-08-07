#!/usr/bin/env python3
"""Build the Metric 3 CSV from LTD event exports only.

Full Metric 3 requires both files::

    python build_ltd_metric3_csv.py \
      --reschedules /path/LTD_Reschedules.csv \
      --cancellations /path/LTD_Cancellations.csv \
      --as-of-date 2026-08-07 \
      --output /path/ltd_metric3_events.csv

Use ``--cancellations-only`` only when a cancellation-only CSV is intended.
"""
import argparse
import json
import sys
from pathlib import Path

import pandas as pd

PIPELINE_DIR = Path(__file__).resolve().parent / "PPR" / "July 27" / "pipeline"
sys.path.insert(0, str(PIPELINE_DIR))
from cancellations import (  # noqa: E402
    COUNT_DIRECTIONS,
    THRESHOLD_DAYS,
    _col,
    _dates,
    _has,
    _read_any,
    _required_direction,
    _required_order,
    apply_rule,
)


OUTPUT_COLUMNS = [
    "order_id",
    "lost_slot_date",
    "recorded_at",
    "days_notice",
    "event_type",
    "reschedule_direction",
    "cancellation_reason",
    "source_input",
    "as_of_date",
]


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--cancellations", required=True,
                        help="CSV or XLSX export of LTD_Cancellations")
    parser.add_argument("--reschedules",
                        help="CSV or XLSX export of LTD_Reschedules (required for full Metric 3)")
    parser.add_argument("--cancellations-only", action="store_true",
                        help="Produce only cancellation events; requires omitting --reschedules")
    parser.add_argument("--as-of-date", required=True, metavar="YYYY-MM-DD",
                        help="Explicit reporting cut-off; rows recorded after this date are excluded")
    parser.add_argument("--output", required=True, help="Output CSV path")
    parser.add_argument("--overwrite", action="store_true", help="Replace an existing output CSV")
    args = parser.parse_args()

    if args.cancellations_only and args.reschedules:
        parser.error("--cancellations-only cannot be used with --reschedules")
    if not args.cancellations_only and not args.reschedules:
        parser.error("full Metric 3 requires --reschedules; use --cancellations-only only for a "
                     "deliberately partial cancellation endpoint")
    return args


def parse_as_of(value):
    parsed = pd.to_datetime(value, format="%Y-%m-%d", errors="coerce")
    if pd.isna(parsed) or parsed.strftime("%Y-%m-%d") != value:
        raise ValueError(f"--as-of-date must be YYYY-MM-DD, received {value!r}")
    return parsed.normalize()


def require_file(path_arg, label):
    path = Path(path_arg).expanduser().resolve()
    if not path.is_file():
        raise FileNotFoundError(f"{label} input not found: {path}")
    if path.suffix.lower() not in {".csv", ".xlsx", ".xls"}:
        raise ValueError(f"{label} must be a .csv, .xlsx, or .xls file: {path}")
    return path


def cancellation_events(path):
    frame = _read_any(str(path), ["ORDER_ID", "TTP_DATE"])
    if not _has(frame, "SNAPSHOT_DATE_TIME_CURR"):
        raise KeyError("LTD_Cancellations is missing SNAPSHOT_DATE_TIME_CURR")
    if not _has(frame, "CANCELLATION_REASON"):
        raise KeyError("LTD_Cancellations is missing CANCELLATION_REASON")
    return pd.DataFrame({
        "order": _required_order(_col(frame, "ORDER_ID")),
        "lost_slot": _dates(_col(frame, "TTP_DATE"), "LTD_Cancellations.TTP_DATE"),
        "recorded_on": _dates(_col(frame, "SNAPSHOT_DATE_TIME_CURR"),
                              "LTD_Cancellations.SNAPSHOT_DATE_TIME_CURR"),
        "kind": "cancelled",
        "direction": pd.Series(pd.NA, index=frame.index, dtype="string"),
        "reason": _col(frame, "CANCELLATION_REASON").astype("string").str.strip(),
        "source_input": path.name,
    })


def reschedule_events(path):
    frame = _read_any(str(path), ["ORDER_ID", "TTP_DATE_PREV"])
    missing = [column for column in ("SNAPSHOT_DATE_TIME_CURR", "RESCHEDULED_CATEGORY")
               if not _has(frame, column)]
    if missing:
        raise KeyError("LTD_Reschedules is missing required column(s): " + ", ".join(missing))
    return pd.DataFrame({
        "order": _required_order(_col(frame, "ORDER_ID")),
        "lost_slot": _dates(_col(frame, "TTP_DATE_PREV"), "LTD_Reschedules.TTP_DATE_PREV"),
        "recorded_on": _dates(_col(frame, "SNAPSHOT_DATE_TIME_CURR"),
                              "LTD_Reschedules.SNAPSHOT_DATE_TIME_CURR"),
        "kind": "rescheduled",
        "direction": _required_direction(_col(frame, "RESCHEDULED_CATEGORY")),
        "reason": pd.Series(pd.NA, index=frame.index, dtype="string"),
        "source_input": path.name,
    })


def build_endpoint(frames, as_of):
    raw = pd.concat(frames, ignore_index=True)
    assert len(raw) == sum(len(frame) for frame in frames), "Input-row concatenation did not reconcile."

    future_recorded = raw["recorded_on"] > as_of
    eligible = raw.loc[~future_recorded].copy()
    result = apply_rule(eligible, THRESHOLD_DAYS, COUNT_DIRECTIONS)
    rule_drops = result.attrs["drops"]
    drops = {
        "rows in": int(len(raw)),
        "recorded after as-of date": int(future_recorded.sum()),
        "no slot was ever booked": rule_drops["no slot was ever booked"],
        "recorded after the date": rule_drops["recorded after the date"],
        f"more than {THRESHOLD_DAYS} days notice": rule_drops[f"more than {THRESHOLD_DAYS} days notice"],
        "direction not counted": rule_drops["direction not counted"],
        "counted": rule_drops["counted"],
    }
    accounted = sum(count for label, count in drops.items() if label != "rows in")
    assert accounted == drops["rows in"], (
        f"Funnel does not reconcile: {accounted} accounted for versus {drops['rows in']} rows in")

    kept_ids = result.index
    selected = eligible.loc[kept_ids].copy()
    assert len(selected) == len(result), "Kept-row selection did not reconcile to the rule output."

    endpoint = pd.DataFrame({
        "order_id": selected["order"].astype("string"),
        "lost_slot_date": selected["lost_slot"].dt.strftime("%Y-%m-%d"),
        "recorded_at": selected["recorded_on"].dt.strftime("%Y-%m-%d"),
        "days_notice": result["days_notice"].astype("int64").to_numpy(),
        "event_type": selected["kind"].astype("string"),
        "reschedule_direction": selected["direction"].astype("string"),
        "cancellation_reason": selected["reason"].astype("string"),
        "source_input": selected["source_input"].astype("string"),
        "as_of_date": as_of.strftime("%Y-%m-%d"),
    })
    endpoint = endpoint.sort_values(
        ["lost_slot_date", "recorded_at", "event_type", "order_id", "source_input"],
        kind="mergesort",
        na_position="last",
    ).reset_index(drop=True)
    assert endpoint.columns.tolist() == OUTPUT_COLUMNS, "Endpoint columns changed unexpectedly."
    assert len(endpoint) == drops["counted"], "Endpoint row count does not equal the funnel count."
    return endpoint, drops


def main():
    args = parse_args()
    as_of = parse_as_of(args.as_of_date)
    cancellations_path = require_file(args.cancellations, "LTD_Cancellations")
    reschedules_path = require_file(args.reschedules, "LTD_Reschedules") if args.reschedules else None
    if reschedules_path and reschedules_path == cancellations_path:
        raise ValueError("--reschedules and --cancellations must be different files")

    output = Path(args.output).expanduser().resolve()
    if output.exists() and not args.overwrite:
        raise FileExistsError(f"Output already exists: {output}. Re-run with --overwrite to replace it.")
    output.parent.mkdir(parents=True, exist_ok=True)

    inputs = [cancellation_events(cancellations_path)]
    if reschedules_path:
        inputs.append(reschedule_events(reschedules_path))
    endpoint, drops = build_endpoint(inputs, as_of)
    endpoint.to_csv(output, index=False)

    print(json.dumps({
        "as_of_date": as_of.strftime("%Y-%m-%d"),
        "mode": "cancellations_only" if args.cancellations_only else "full_metric_3",
        "input_files": [path.name for path in (cancellations_path, reschedules_path) if path],
        "funnel": drops,
        "output": str(output),
    }, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
