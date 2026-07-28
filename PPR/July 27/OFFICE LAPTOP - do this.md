# Office laptop, start to finish

Windows, PowerShell. Every step says what you should see, so you know it worked before
moving on. Real Infinity data never leaves this machine; only code and printed numbers
travel back through git.

Steps 1 to 5 give you a working dashboard with no Tableau at all. Do those first.

---

## Where everything lives

```
C:\Users\SGowda\OneDrive - Iovance Biotherapeutics\Desktop\PPR Automation\VS Code
```

Open a PowerShell terminal there. In VS Code that is Terminal > New Terminal, which
already opens in this folder. Every command below runs from there.

---

## 0. One-time setup

```
python --version
```

VS Code is showing **Python 3.14**, which is newer than pandas and pantab reliably ship
wheels for. Run the install and watch what happens:

```
pip install -r requirements.txt
```

If any package fails to build, that is the 3.14 problem, not your machine. Install
Python 3.12 alongside it and use that instead:

```
py -3.12 -m pip install -r requirements.txt
```

and run everything below with `py -3.12` in place of `python`. Tell me which one you
ended up on so the rest of the notes match.

---

## 1. Get the latest code

Your `VS Code` folder is not a git clone, so there is nothing to pull. Copy these across
from the repo, overwriting what is there:

```
RUN_ALL.py
metric3_cancellations.py
ONE DASHBOARD - Tableau build.md
OFFICE LAPTOP - do this.md      (this file)
pipeline\metrics.py
pipeline\baseline.py
pipeline\build_analysis_table.py
pipeline\build_dashboard_html.py
pipeline\build_datewindow.py
pipeline\build_hyper.py
pipeline\build_scorecard.py
```

Delete `pipeline\build_center_decks.py` if it is there. The PowerPoint stage was removed;
the dashboard filters and screenshots cover it. The `decks\` folder can go too.

**Leave alone:** `data\`, `analysis\`, `dashboard\`, `tableau\`, `PPR Dashboard.twbx`,
`up.twb`. Those are yours and hold real output.

Delete `pipeline\__pycache__` after copying. Stale `.pyc` files from the old versions
are the one thing that can make a fresh script behave like the old one.

---

## 2. Put the real exports in place

You already have a `data` folder. Download these seven from Infinity into it as `.xlsx`.
Only the part of the name in backticks has to match; export-date suffixes are fine, so
`BAI - List of Orders 07.28.xlsx` matches `bai_list_of_orders`.

| Needs to contain | Infinity report |
|---|---|
| `bai_list_of_orders` | BAI List of Orders |
| `bai_infusion` | BAI Infusion |
| `bai_slot_data` | BAI Slot Data |
| `bai_ttp_data` | BAI TTP Data |
| `bai_tumor_documentation` | BAI Tumor Documentation |
| `veeva_call_activity` | Veeva Call Activity |
| `veeva_komodo_atc_mapping` | Veeva / Komodo ATC mapping |

`data/` is gitignored, so nothing in it can be committed by accident.

---

## 3. Run everything

```
python RUN_ALL.py
```

The header prints the folder it is reading and how many `.xlsx` it found. It must be your
`data` folder and it must say 7. If it found fewer it lists them, and stage 1 will stop
and name the missing one. If it is reading the synthetic sample it prints a row of
exclamation marks saying so; every number after that would be made up.

Five stages run in order. A minute or so.

**Expect assertions to fire that never fired on synthetic data.** That is them working.
If a stage stops with a message about cells not reconciling, or a column it did not
recognise, copy the whole message and send it to me. Do not edit the script to make it
pass. It is telling you something true about the real data.

---

## 4. Read what it tells you

Two prints in stage 2 matter:

- `reconciles: N center/metric cells` — the year columns plus Undated plus After as-of
  add up to Launch to Date everywhere. If this fails the run stops.
- `events dated after the as-of date` — a list. Scheduled TTPs being in there is normal,
  they are future bookings. **AMTAGVI Infusions Performed being in there is not.** An
  infusion with a future date has not happened, so counting it as performed overstates
  treated patients. Send me that number.

Also note the `Undated` count. On synthetic data it was 7% of events, but synthetic
missingness is a property of the generator and tells us nothing. The real figure decides
whether missing dates are a footnote or a problem.

---

## 5. Open the dashboard (no Tableau needed)

```
start dashboard\ppr_scorecard.html
```

Opens in your browser. Pick a centre from the dropdown. This is the fastest way to see
whether the real numbers look sane, and it is shareable as a single file.

To reproduce one of Kolin's existing slides: set the four date boxes to that slide's two
periods and hit Apply. The table becomes period A, period B, difference.

---

## 6. Metric 3 on real history

This is the highest-value step on the page. One run answers three separate open questions.

In Infinity, run this and export the result into the same `data` folder, with `hist`
somewhere in the filename:

```sql
SELECT order_request__til_order_name, record_number, load_datetime,
       tumor_tissue_pick_up_date, atc, fp_status, til_order_cancellation_reason
FROM bai_list_of_orders_hist
```

Then:

```
python metric3_cancellations.py
```

What it answers:

1. **The real metric 3.** The pipeline currently stands in a proxy flag that fires on 26.8%
   of orders while Kolin's UK deck reports zero. This walks the snapshot history properly:
   whenever a booked pickup date moves or is cleared, it measures the days of notice.
2. **Whether `fp_status` survives a cancellation.** Decides if the progression-rate
   denominator quietly decays over time.
3. **When each order was cancelled.** The event date we were going to ask Jonathan for,
   recovered from the first snapshot carrying a cancellation reason.

**Sanity check is built in.** If it comes back anywhere near 347 orders, the logic is
wrong and the script says so. Send me the printed summary either way. Numbers only, no
rows.

---

## 7. Build the Tableau sheet (about 10 minutes, once)

Follow `ONE DASHBOARD - Tableau build.md` in this folder. One data source, one worksheet,
one dashboard.

Close Tableau before any future `RUN_ALL.py` run. It holds the `.hyper` files open and
the run will fail with a permission error.

This has never been built in the product. Anything that does not match the doc, write it
down and I will fix the doc.

---

## 8. Before Kolin sees it

Pick two or three centres he knows and already has decks for. UK Chandler is the one
already checked, 6 of 8 metrics exact. Compare cell by cell.

Understand every difference before he sees it, not during. The first disputed cell decides
whether he believes the other twelve.

---

## If something breaks

| Symptom | Cause |
|---|---|
| Row of `!!!!` saying synthetic | `data\` is missing, empty, or has no `.xlsx` |
| `PermissionError` on a `.hyper` | Tableau Desktop is open. Close it and rerun |
| `Could not find a file matching...` | one of the seven exports is missing or misnamed |
| A stage stops on an assertion | real data disagrees with an assumption. Send the message |
| `ModuleNotFoundError` | rerun the `pip install` line in step 0 |
| `pip install` fails building a wheel | Python 3.14. Use `py -3.12` (step 0) |
| A script behaves like the old version | stale `pipeline\__pycache__`. Delete the folder |

Rerunning is always safe. Every output is rebuilt from scratch.

Nothing here writes outside the `VS Code` folder, and nothing sends data anywhere. Only
what you copy into chat leaves the laptop.
