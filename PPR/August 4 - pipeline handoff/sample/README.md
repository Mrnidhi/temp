# About this sample

**The `ppr_events.csv` next to this file was produced from test data. Every number
in it is made up. Replace it with a real run before this folder goes anywhere.**

It is here so the shape is right: column order, types, the repeated rows per
scorecard column, blank event dates, the benchmark rows. All of that matches a
real run. The values do not.

    as-of date        2026-06-16, taken from the test file
    rows              41,313
    columns           13, in reporting-table order
    metric 3 source   proxy, because the two LTD files were not present

That last line matters. With the LTD files present, metric 3 is computed from the
seven day rule on real events. Here it came from the fallback proxy, so it is the
one metric that will not match in shape or in value.

## Replacing it

Put the six source files in `pipeline/data/`, then from `pipeline/`:

    python RUN_ALL.py

Copy the `ppr_events.csv` it writes in here, then empty `pipeline/data/` and
delete `pipeline/work/`. The run prints its as-of date and which source metric 3
used; check both before handing the folder over.
