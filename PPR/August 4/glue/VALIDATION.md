# What was validated locally, 2026-08-04

The job cannot reach Redshift or Glue from the build machine, so validation
covers the transformation completely and stops at the AWS boundary.

Checked and passed:

1. The ported transformation reproduces the reference pipeline byte for byte.
   The synthetic source tables were loaded as DataFrames with lowercase
   column names, exactly the shape redshift-connector returns, and run
   through ppr_transform.run(). All three outputs (order master, scorecard,
   Events) came out identical to the reference pipeline files, byte for byte.
2. The lost slot path. Stub reschedule and cancellation tables with lowercase
   columns produced m3_source ltd, the correct 4 counted events, the correct
   exclusion of an order that does not exist, and scorecard and Events
   outputs byte for byte identical to a reference pipeline run on the same
   stubs.
3. Both gates fire inside the transformation: the additivity check across the
   period columns and the cell by cell reconciliation of Events against the
   scorecard, with the two documented metric exemptions.
4. The stage boundaries are faithful: frames pass between stages through an
   in memory csv round trip, reproducing the float quantization the
   reference gets from writing and reading its csv files. Without this one
   benchmark value differed in the last digit; with it, nothing differs.
5. The DDL column order in create_events_table.sql matches the Events csv
   header order exactly, checked programmatically, so the copy maps columns
   one to one.
6. ppr_daily_job.py and ppr_transform.py compile clean, and the job imports
   cleanly with stubbed AWS modules.

Not checkable from here, first deployment should watch these:

- Network path from the Glue job to the cluster, the secret shape, and the
  copy role permissions on the output bucket.
- Real raw table names and column names in Redshift. If the loader renamed
  anything, alias it back in a view and point --source_schema at that schema.
- fetch_dataframe dtype behavior on the real cluster (dates arriving as
  strings parse identically; the transformation parses every date column
  itself).

No longer a caveat: the Hyper engine. This job does not write .hyper files,
so pantab is not needed in Glue at all.
