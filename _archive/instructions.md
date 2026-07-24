For each CSV in this project, give me a schema profile only — no actual row values. For every column:
- exact column name (as-is, including spaces/casing)
- dtype (int / float / string / date / datetime / bool)
- % null
- for numbers/dates: min, max, mean, median
- for strings: number of distinct values, and if under ~30 distinct, list them all; if more, just the count and 3 example formats (masked)
- flag which column looks like the primary key and which looks like Patient ID, Center/ATC name, and any date columns

Then tell me, across files, which columns are the shared join keys and roughly what % of IDs overlap between files. Output as one markdown table per file plus a short join summary.