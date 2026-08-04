"""Glue python shell job that builds the P&PR Events table once a day.

Reads the raw tables from Redshift, runs the transformation in ppr_transform.py
(ported from the reference pipeline and verified byte for byte against it),
and lands the final table back in Redshift as <reporting_schema>.ppr_events.
Tableau connects to that table. S3 is used only as the bulk load buffer for
the Redshift copy and as the per run audit trail.

Ships with ppr_transform.py, metrics.py and cancellations.py as extra files.
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

EVENTS_COLUMNS = """
    center varchar(256), metric_group varchar(64), metric varchar(160),
    metric_order int, agg varchar(16), event_date date, value double precision,
    unit varchar(256), col_label varchar(32), col_order int, cell_color varchar(32),
    col_group varchar(64), col_group_order int
"""


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


def upload_csv(df, bucket, key):
    s3.put_object(Bucket=bucket, Key=key, Body=df.to_csv(index=False).encode())
    return f"s3://{bucket}/{key}"


def publish_events(conn, schema, csv_url, copy_role_arn):
    full = f'"{schema}"."ppr_events"'
    cur = conn.cursor()
    cur.execute(f"create table if not exists {full} ({EVENTS_COLUMNS})")
    conn.commit()
    # delete instead of truncate so the swap stays inside one transaction
    cur.execute(f"delete from {full}")
    cur.execute(
        f"copy {full} from '{csv_url}' iam_role '{copy_role_arn}' "
        "format as csv ignoreheader 1 emptyasnull blanksasnull timeformat 'auto'")
    conn.commit()
    cur.execute(f"select count(*) from {full}")
    n = cur.fetchone()[0]
    cur.close()
    print(f"published {n} rows to {schema}.ppr_events")
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
    asof_override = arg("asof")

    conn = connect(secret_arn)
    frames = fetch_frames(conn, source_schema, allow_proxy_m3)

    # the transformation, with its additivity and reconciliation gates inside;
    # any gate failure raises and the job stops before touching ppr_events
    events, tidy, order_master, canc, undated, meta = ppr_transform.run(
        frames, asof_override)

    asof = meta["asof"]
    m3 = meta.get("m3_source", "proxy")
    print(f"transformation done. asof={asof} m3_source={m3} events={len(events)} rows")
    if m3 == "proxy" and not allow_proxy_m3:
        sys.exit("metric 3 fell back to the proxy flag. Pass --allow_proxy_m3 true "
                 "only if that is an accepted run.")

    bucket, out_key = split_s3(output_prefix)
    events_url = upload_csv(events, bucket, f"{out_key}/latest/ppr_events.csv")
    for name, df in [("ppr_events", events), ("ppr_scorecard_tidy", tidy),
                     ("ppr_analysis", order_master), ("ppr_cancellations", canc),
                     ("undated_events", undated)]:
        upload_csv(df, bucket, f"{out_key}/asof={asof}/{name}.csv")
    s3.put_object(Bucket=bucket, Key=f"{out_key}/asof={asof}/run_meta.json",
                  Body=json.dumps(meta, indent=1).encode())
    print(f"audit copies uploaded to {output_prefix}/asof={asof}/")

    publish_events(conn, reporting_schema, events_url, copy_role_arn)
    conn.close()


if __name__ == "__main__":
    main()
