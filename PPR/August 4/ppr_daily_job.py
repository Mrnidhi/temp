"""Daily job: Redshift in, P&PR tables out.

Reads the raw tables, runs the transformation in ppr_transform.py, and writes
two tables back to Redshift:

    ppr.ppr_events        the final table, the one Tableau reads
    ppr.ppr_order_master  one row per order, for drill-down and audit

Safe to rerun. The as-of date comes from the data rather than the clock, each
table is replaced inside a single transaction, and the staged files for a given
as-of are written to the same keys every time, so a second run of the same day
lands exactly where the first one did.

Runs as a Glue python shell job with ppr_transform.py, metrics.py and
cancellations.py supplied through --extra-py-files.
"""

import json
import sys

import boto3
import redshift_connector

import ppr_transform

s3 = boto3.client("s3")

SOURCES = ["bai_list_of_orders", "bai_tumor_documentation", "bai_infusion",
           "veeva_komodo_atc_mapping", "bai_slot_data",
           "ltd_reschedules", "ltd_cancellations"]
OPTIONAL = {"bai_slot_data"}
LTD = {"ltd_reschedules", "ltd_cancellations"}

EVENTS_TABLE = "ppr_events"
ORDER_TABLE = "ppr_order_master"

# The reference table carries the fields a metric can be traced back through.
ORDER_COLUMNS = [
    "order_request__til_order_name", "coi_number", "iovance_patient_id", "atc",
    "center_key", "region", "territory", "atc_segment", "atc_tier",
    "enrollment_date", "tumor_pickup_date", "fp_delivery_date", "infusion_date",
    "fp_status", "oos_status", "til_order_cancellation_reason", "tpf_count",
    "has_tumor", "has_slot", "completed_ttp", "scheduled_ttp", "oos_product",
    "mfg_started", "dropout_post_ttp_health", "drop_after_mfg", "amtagvi_infused",
    "ttp_cancel_le7", "days_enroll_to_ttp", "days_ttp_to_infusion",
    "days_delivery_to_infusion",
]

DDL = {
    EVENTS_TABLE: """
        center varchar(256), metric_group varchar(64), metric varchar(160),
        metric_order int, agg varchar(16), event_date date, value double precision,
        unit varchar(256), col_label varchar(32), col_order int,
        cell_color varchar(32), col_group varchar(64), col_group_order int
    """,
    ORDER_TABLE: """
        order_request__til_order_name varchar(256), coi_number varchar(256),
        iovance_patient_id varchar(256), atc varchar(256), center_key varchar(256),
        region varchar(256), territory varchar(256), atc_segment varchar(256),
        atc_tier varchar(256), enrollment_date date, tumor_pickup_date date,
        fp_delivery_date date, infusion_date date, fp_status varchar(256),
        oos_status varchar(256), til_order_cancellation_reason varchar(256),
        tpf_count int, has_tumor boolean, has_slot boolean, completed_ttp boolean,
        scheduled_ttp boolean, oos_product boolean, mfg_started boolean,
        dropout_post_ttp_health boolean, drop_after_mfg boolean,
        amtagvi_infused boolean, ttp_cancel_le7 boolean,
        days_enroll_to_ttp double precision, days_ttp_to_infusion double precision,
        days_delivery_to_infusion double precision
    """,
}


def arg(name, default=None):
    flag = "--" + name
    if flag in sys.argv:
        return sys.argv[sys.argv.index(flag) + 1]
    return default


def split_s3(url):
    assert url.startswith("s3://"), url
    bucket, _, key = url[5:].partition("/")
    return bucket, key.rstrip("/")


def connect(secret_arn):
    sec = boto3.client("secretsmanager").get_secret_value(SecretId=secret_arn)
    c = json.loads(sec["SecretString"])
    return redshift_connector.connect(
        host=c["host"], port=int(c.get("port", 5439)),
        database=c.get("dbname") or c.get("dbName"),
        user=c["username"], password=c["password"])


def fetch_frames(conn, schema, allow_proxy_m3):
    frames = {}
    cur = conn.cursor()
    for table in SOURCES:
        try:
            cur.execute(f'select * from "{schema}"."{table}"')
        except Exception as e:
            conn.rollback()
            if table in OPTIONAL:
                print(f"optional table {schema}.{table} not readable, skipping ({e})")
                frames[table] = None
                continue
            if table in LTD and allow_proxy_m3:
                print(f"{schema}.{table} not readable, proxy run allowed ({e})")
                continue
            raise
        df = cur.fetch_dataframe()
        print(f"{schema}.{table}: {len(df)} rows")
        if table in LTD and len(df) == 0 and not allow_proxy_m3:
            sys.exit(f"{schema}.{table} is empty. Metric 3 would degrade to the "
                     "proxy flag. Fix the load, or pass --allow_proxy_m3 true if "
                     "a proxy run is explicitly accepted.")
        frames[table] = df
    cur.close()
    return frames


def stage(df, bucket, key):
    s3.put_object(Bucket=bucket, Key=key, Body=df.to_csv(index=False).encode())
    return f"s3://{bucket}/{key}"


def publish(conn, schema, table, csv_url, copy_role_arn):
    """Replace one table from a staged csv. The delete and the load share a
    transaction, so readers see either the previous run or this one."""
    full = f'"{schema}"."{table}"'
    cur = conn.cursor()
    cur.execute(f"create table if not exists {full} ({DDL[table]})")
    conn.commit()
    cur.execute(f"delete from {full}")
    cur.execute(
        f"copy {full} from '{csv_url}' iam_role '{copy_role_arn}' "
        "format as csv ignoreheader 1 emptyasnull blanksasnull timeformat 'auto'")
    conn.commit()
    cur.execute(f"select count(*) from {full}")
    n = cur.fetchone()[0]
    cur.close()
    print(f"published {n} rows to {schema}.{table}")
    return n


def main():
    secret_arn = arg("secret_arn")
    output_prefix = arg("output_prefix")
    copy_role_arn = arg("copy_role_arn")
    if not (secret_arn and output_prefix and copy_role_arn):
        sys.exit("required arguments: --secret_arn --output_prefix --copy_role_arn")
    source_schema = arg("source_schema", "infinity")
    reporting_schema = arg("reporting_schema", "ppr")
    allow_proxy_m3 = arg("allow_proxy_m3", "false").lower() == "true"
    with_order_master = arg("with_order_master", "true").lower() == "true"
    asof_override = arg("asof")

    conn = connect(secret_arn)
    frames = fetch_frames(conn, source_schema, allow_proxy_m3)

    # The additivity and reconciliation gates live inside the transformation.
    # A failed gate raises here, before anything is written.
    events, tidy, order_master, canc, undated, meta = ppr_transform.run(
        frames, asof_override)

    asof = meta["asof"]
    m3 = meta.get("m3_source", "proxy")
    print(f"transformed. asof={asof} m3_source={m3} events={len(events)} rows")
    if m3 == "proxy" and not allow_proxy_m3:
        sys.exit("metric 3 fell back to the proxy flag. Pass --allow_proxy_m3 true "
                 "only if that is an accepted run.")

    bucket, out_key = split_s3(output_prefix)
    events_url = stage(events, bucket, f"{out_key}/asof={asof}/{EVENTS_TABLE}.csv")
    s3.put_object(Bucket=bucket, Key=f"{out_key}/asof={asof}/run_meta.json",
                  Body=json.dumps(meta, indent=1).encode())
    publish(conn, reporting_schema, EVENTS_TABLE, events_url, copy_role_arn)

    if with_order_master:
        om = order_master.reindex(columns=ORDER_COLUMNS)
        om_url = stage(om, bucket, f"{out_key}/asof={asof}/{ORDER_TABLE}.csv")
        publish(conn, reporting_schema, ORDER_TABLE, om_url, copy_role_arn)

    conn.close()
    print(f"done. staged copies under {output_prefix}/asof={asof}/")


if __name__ == "__main__":
    main()
