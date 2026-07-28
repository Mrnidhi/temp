# P&PR automation, Daily Connect note

For Srinidhi to report from. Everything below is built and running on real Infinity data
on the office laptop.

---

## Where it stands

The whole scorecard now builds from one command. Pick a centre in the dashboard and all 13
metrics fill in, launch to date, by year, against the national benchmark, and by quarter.
The manual download-to-Excel-to-slide step is gone.

**Roughly 80 percent done.** What is left is the column and row pickers so you can
screenshot a subset, the comparison-arm rule, and checking it against decks you have
already made by hand.

---

## What runs, and what each piece does

One command, `python RUN_ALL.py`, does all of it in about a minute.

| Script | What it does |
|---|---|
| `RUN_ALL.py` | runs the five stages in order and stops if any of them fails |
| `pipeline/metrics.py` | the 13 metric names and which date each one is counted on. One definition, imported by every other stage, so the wording can never drift |
| `pipeline/build_analysis_table.py` | joins the seven Infinity exports into one table, one row per order, and works out the derived flags |
| `pipeline/build_scorecard.py` | computes all 13 metrics for every centre and every column, plus the three national benchmarks |
| `pipeline/build_datewindow.py` | turns the same events into one row per event so a single Tableau sheet can show the fixed columns and a live date window together |
| `pipeline/build_hyper.py` | writes the Tableau extract files |
| `pipeline/build_dashboard_html.py` | writes a standalone browser version, one file, no Tableau needed |
| `pipeline/baseline.py` | freezes a reference copy so any later change can be diffed against it |
| `metric3_cancellations.py` | the real 7-day cancellation logic, ready to run the moment I get the snapshot history export |

Real patient data never leaves the office laptop. Only code moves, through a git folder.

---

## The 13 formulas

Every metric is counted on **its own event date**, not on the patient's enrolment date. So
the 2025 column of Infusions Performed means infusions that happened in 2025, whatever year
that patient enrolled. That matches the footnote on your existing decks.

| # | Metric | How it is calculated | Counted on |
|---|---|---|---|
| 1 | Enrollments in IovanceCares | count of distinct TIL order names | enrolment date |
| 2 | Patients Enrolled in IovanceCares | count of distinct Iovance patient IDs | enrolment date |
| 3 | TTPs Cancelled or Rescheduled within 7 Days | **estimate for now.** Currently the `resection_rescheduled_` flag. The real rule needs the snapshot history | TTP pickup date |
| 4 | Completed TTPs | pickup date filled in and on or before the as-of date | TTP pickup date |
| 5 | Scheduled TTPs | pickup date filled in and after the as-of date | TTP pickup date |
| 6 | 2nd Resections | distinct patients with 2 or more different real pickup dates | TTP pickup date |
| 7 | Patient Related Drop-outs following TTP | distinct patients who had a tumour and whose cancellation reason is a health reason | TTP pickup date |
| 8 | OOS Products | OOS status equals exactly "Confirmed OOS" | FP delivery date |
| 9 | Patient Progression Rate | distinct patients who started manufacturing and then dropped for a patient reason, divided by distinct patients who started manufacturing | TTP pickup date |
| 10 | AMTAGVI Infusions Performed | in the infusion file, lifileucel infused is Yes, and the infusion date is filled in | infusion date |
| 11 | Median Time Enrollment to TTP | median of pickup date minus enrolment date | TTP pickup date |
| 12 | Median Time TTP to Infusion | median of infusion date minus pickup date | infusion date |
| 13 | Median Time FP Delivery to Infusion | median of infusion date minus delivery date | infusion date |

**Four decisions worth flagging, because they change the numbers:**

**Metrics 4 and 5 never overlap.** Completed is the pickup date in the past, Scheduled is
the pickup date in the future. That comes from the Notes column of your own Proposed
Template. It means the two can be added together for a total procurement count without
double-counting.

**Metrics 2, 6, 7 and 9 count patients, not orders.** A patient holding three orders would
otherwise be weighted three times. Metric 1 counts orders on purpose, because that is what
it means.

**Metric 9's denominator excludes the starting-material states.** SM pickup and courier
steps happen before manufacturing. Including them would inflate the denominator by roughly
a third and make the rate look better than it is. It also excludes NED/MRD from the
numerator, because no evidence of disease means the patient responded, and counting that as
progression would report a good outcome as a failure.

**Metrics 11 to 13 are medians, and the labels now say Median.** You said the Infinity
scorecard shows the median and that averages get skewed by the patients at the top end. If
you want the word Average back, that is a one-line change, but the number moves.

---

## The benchmarks

Top 10, Top 40 and New each show the **median of the per-centre values within that tier**,
launch to date. Not a total, not an average. They are blinded, so a centre sees where the
middle of its peer group sits and never sees another centre's name or number. They stay the
same when you switch centre, which is the design working, not a bug.

**Quartiles are gone.** You said they confuse the sales folks and the people in the ATCs and
that the team is moving away from them, so the three tier medians replace them entirely.

---

## What checks itself on every run

Three things, and any of them stops the build rather than letting a wrong number through.

The year columns plus the two hidden diagnostic columns must add back to Launch to Date for
every centre and every metric. Last run: 595 cells, all reconciled.

The event-level table and the precomputed scorecard must agree cell for cell. Last run:
11,049 of 11,050, with one known exception in 2nd Resections.

A cancellation reason or a status value that the code does not recognise stops the run. It
does not quietly fall into no bucket and shift a metric.

---

## Three things I need from you

**1. Which comparison arm does each centre see?** Your template has a red note saying "Pick
one comparative arm depending on ATC". The dashboard currently shows all three side by side.
A large centre compared against the New tier is a misleading number, so I would rather show
one.

**2. Two cancellation reasons have no category.** "Clinical Trial /IST/ Collaboration" and
"Peer to Peer Consult Decision". They are currently excluded from metrics 7 and 9. Which
bucket do they belong in?

**3. The snapshot history export.** One pull of `bai_list_of_orders_hist` and metric 3 stops
being an estimate. The logic is written and tested against your August 14 / August 9
example.

---

## What I am doing next

Finishing the column and row pickers so you can untick what you do not need and screenshot
the table straight into a deck. Then reproducing two or three centres you have already done
by hand, so we can walk any differences together before a centre ever sees this.
