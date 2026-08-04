# P&PR daily Glue job, Redshift in and Redshift out

Builds the P&PR Events table every day. The job reads the raw tables from
Redshift, runs the whole transformation in its own code, and lands the final
table back in Redshift as ppr.ppr_events. Tableau connects directly to that
table and never to Infinity. S3 appears only as the bulk load buffer for the
Redshift copy and as a per run audit trail.

The transformation code (ppr_transform.py) was ported from the reference
pipeline in ../pipeline/ and verified byte for byte against it on the
test sample, on both the normal path and the lost slot path. The
additivity gate and the cell by cell reconciliation gate run inside every
call; a failed gate stops the job before ppr_events is touched.

## Files

- ppr_daily_job.py: the Glue job script
- ppr_transform.py: the transformation, DataFrames in, DataFrames out
- metrics.py, cancellations.py: shipped verbatim from the reference pipeline
  (metric names, groups, event dates, and the 7 day lost slot rule)
- package_glue_lib.sh: zips the three modules above for --extra-py-files
- create_events_table.sql: reporting table DDL plus the grant for Tableau
- job_config.json: skeleton for aws glue create-job, fill in the REPLACE values
- VALIDATION.md: what was proven locally and what remains for first deployment

## What the job does, in order

1. Reads these tables from the source schema (default "infinity") with plain
   select star: bai_list_of_orders, bai_tumor_documentation, bai_infusion,
   veeva_komodo_atc_mapping, ltd_reschedules, ltd_cancellations, and
   bai_slot_data if present (optional, drives no metric).
2. Fails before transforming when a required table is missing or when either
   reschedule table is empty (metric 3 would silently degrade to a proxy).
3. Runs the transformation: order master, lost slot events, the 13 metrics
   with their windows and benchmarks, then the Events table, with both
   validation gates inside.
4. Uploads the Events csv plus audit copies (order master, scorecard, lost
   slot events, undated events, run metadata) to
   s3://bucket/ppr/output/asof=YYYY-MM-DD/. The as-of date comes from the
   data itself, never the clock.
5. Loads the Events csv into <reporting_schema>.ppr_events with delete plus
   copy in one transaction, so readers never see a half loaded table.

## Linking Tableau

Tableau connects to ppr.ppr_events, builds the three calculated fields from
the build doc (Keep Center, Keep Row, Result), and refreshes as a Tableau
extract only after this job succeeds. On failure nothing is published and
ppr_events keeps the last good run. Check MEDIAN support if someone insists
on a live connection, extracts always support it.

The .hyper extract is no longer produced by this job; the reference
pipeline in ../pipeline/ still writes one when needed for Desktop work.

## One time setup

1. ./package_glue_lib.sh s3://YOUR_BUCKET/ppr/code/
2. Upload ppr_daily_job.py to s3://YOUR_BUCKET/ppr/code/
3. Run create_events_table.sql in Redshift and grant select to the Tableau user.
4. Fill in job_config.json and create the job:
   aws glue create-job --cli-input-json file://job_config.json
   The job needs a Glue connection (or VPC route) that can reach the cluster,
   a secret with host, port, dbname, username, password, and an IAM role
   attached to Redshift that can read the output bucket for the copy.
5. Create the schedule once the business confirms the run time:
   aws glue create-trigger --name ppr-daily-0600 --type SCHEDULED \
     --schedule "cron(0 6 * * ? *)" --actions JobName=ppr-daily --start-on-creation
6. Wire the Tableau refresh to run only after this job succeeds.

## Job arguments

- --secret_arn, --output_prefix, --copy_role_arn: required
- --source_schema: default "infinity", change if the raw tables live elsewhere
- --reporting_schema: default "ppr"
- --asof YYYY-MM-DD: optional override for reruns of an old cut
- --allow_proxy_m3 true: optional. By default the job fails when either
  reschedule table is missing or empty, or when metric 3 fell back to the
  proxy flag. Only pass this if a proxy run is explicitly accepted.

## Failure behavior

The job exits nonzero when a required source table is missing, when a
reschedule table is empty, when any gate inside the transformation fails
(additivity, event reconciliation, drop funnel), or when metric 3 silently
degraded. Nothing is uploaded and ppr_events is untouched on failure.

## Known caveats

- The raw tables must carry the same column names the Infinity exports had,
  lowercase is fine. If the loader renamed columns, alias them back in a view
  and point --source_schema at that view schema.
- Network path to the cluster, the secret shape, and the copy role are the
  parts that cannot be tested outside AWS. See VALIDATION.md.
