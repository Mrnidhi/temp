# P&PR transformation

Builds the P&PR dashboard tables. Reads the raw tables from Redshift, runs the
transformation, and writes back:

    ppr.ppr_events        the final table, the one Tableau reads
    ppr.ppr_order_master  one row per order, for drill-down and audit

Tableau connects to ppr_events and nothing else.

## Files

    ppr_daily_job.py    the job: Redshift in, transform, Redshift out
    ppr_transform.py    the transformation
    metrics.py          the 13 metric names, groups and event dates
    cancellations.py    the 7 day lost slot rule for metric 3
    create_tables.sql   table definitions and the grants for the Tableau user
    job_config.json     aws glue create-job skeleton, fill in the REPLACE values

## Deploy

    zip ppr_glue_lib.zip ppr_transform.py metrics.py cancellations.py
    aws s3 cp ppr_glue_lib.zip s3://YOUR_BUCKET/ppr/code/
    aws s3 cp ppr_daily_job.py s3://YOUR_BUCKET/ppr/code/

Run create_tables.sql once, fill in job_config.json, then:

    aws glue create-job --cli-input-json file://job_config.json

The job needs a Glue connection that reaches the cluster, a secret holding
host, port, dbname, username and password, and an IAM role attached to
Redshift that can read the output bucket for the copy.

Schedule it once the run time is agreed:

    aws glue create-trigger --name ppr-daily --type SCHEDULED \
      --schedule "cron(0 6 * * ? *)" --actions JobName=ppr-daily --start-on-creation

Refresh Tableau only after the job succeeds.

## Arguments

    --secret_arn --output_prefix --copy_role_arn   required
    --source_schema        default infinity
    --reporting_schema     default ppr
    --with_order_master    default true, set false for the final table only
    --asof YYYY-MM-DD      rerun an older cut
    --allow_proxy_m3 true  accept a run where metric 3 falls back to the proxy

## Source tables

Required: bai_list_of_orders, bai_tumor_documentation, bai_infusion,
veeva_komodo_atc_mapping, ltd_reschedules, ltd_cancellations.
Optional: bai_slot_data, which drives no metric.

Column names must match what Infinity exports, lowercase is fine. If the
loader renamed anything, alias it back in a view and point --source_schema
at that view.

## Rerunning

The job is safe to run twice. The as-of date is taken from the newest order
creation date in the data, never from the clock, so the same rows always give
the same tables. Each table is replaced inside one transaction, and the staged
csv for an as-of is written to the same key every run.

## Failing

The job stops and writes nothing when a required table is missing, when a
reschedule table is empty, when metric 3 silently degrades, or when either
gate inside the transformation fails: the additivity check across the period
columns, and the cell by cell reconciliation of the event table against the
scorecard. On failure the previous tables stay in place.

## What was checked

The transformation reproduces the reference implementation exactly. Running it
on the sample data gives byte identical output for the order master, the
scorecard and the event table, on both the normal path and the lost slot path.
Running it twice gives identical frames. Untested outside AWS: the network
path to the cluster, the secret, and the copy role.
