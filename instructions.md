# Territory Fairness Analysis for the Enrollment Contest

*A plain writeup of what I looked at, what I found, and how it shapes the scoring. Every number here comes straight from the data, not an estimate.*

---

## The question I started with

Before ranking the 24 territories against each other, I wanted to answer one thing first: are the territories even enough to compare directly? If they are, I can rank on raw numbers. If they are not, I have to level the field before scoring. The data gives a clear answer, and it points to exactly how the contest should be scored.

---

## 1. The market

Out of 16,246 eligible patients:

* **6,935 (43%)** are already in network
* **9,311 (57%)** are still out of network, and that group is the real enrollment opportunity

So the fair thing to measure is how much of its own available patients a territory captures, not how big its patch already is.

---

## 2. Region level: even

Grouped into the six regions, the picture is balanced. The out of network pool stays within about **1.05 times** its middle value across regions, so no region stands out as an outlier.

| Region | Eligible | In network | Out of network | % Out of network |
|---|---:|---:|---:|---:|
| West | 4,018 | 1,699 | 2,319 | 58% |
| Northeast | 3,855 | 1,886 | 1,969 | 51% |
| Southeast | 3,206 | 1,601 | 1,605 | 50% |
| Great Lakes | 2,113 | 851 | 1,262 | 60% |
| Ohio Valley | 1,903 | 633 | 1,270 | 67% |
| Central | 1,017 | 265 | 752 | 74% |

What this tells me: region is too even to separate one territory's effort from another. It is a useful check, but the wrong level to run a contest on.

---

## 3. Territory level: very uneven

The same patients, grouped by the 24 territories, look completely different. They run from 1,015 at the top down to 12 at the bottom. Most territories sit well below the middle, and a small number sit far above it.

```
In-network patients per territory (a stand-in for territory size)

LARGE  (top 8)
South FL             1015  ████████████████████████████████
Desert Plains         731  ███████████████████████
Philly                637  ████████████████████
New England           579  ██████████████████
Pittsburgh/Cleveland  524  █████████████████
Chicago/IN            426  █████████████
South TX/LA           377  ████████████
Pacific Northwest     347  ███████████

MEDIUM  (middle 8)
San Diego/OC          310  ██████████
CT/NYC                308  ██████████
MN/WI                 294  █████████
Great South           275  █████████
Northern Cal          218  ███████
Mid-Atlantic          168  █████
Northern NJ & NYC     142  ████
Carolinas             136  ████
                            median = 247 (half the territories are below here)

SMALL  (bottom 8)
IN/KY/Cincy           109  ███
OH/MI                  89  ███
Los Angeles           81  ███
North TX/OK           65  ██
North FL/GA           40  █
Midwest               26  █
AR/MO/Tulsa           26  █
Rocky Mountains       12  |
```

The numbers behind it: the biggest territory is about **85 times** the smallest. The average sits well above the middle value (a ratio of 1.17, against 1.05 for regions), which is the mark of a skewed spread where a few large territories pull the average up.

What this tells me: if I scored the contest on raw enrollment counts, the largest territories would win every time and the smaller ones could never catch up. So raw totals cannot be the score.

---

## 4. How I set up the scoring

Two simple moves come straight out of the numbers above:

1. **Bracket by size.** Split the 24 territories into three equal groups of eight (large, medium, small), so every territory only competes against others its own size.
2. **Score on growth over each territory's own baseline.** Half the score on raw patients added, half on percent growth, so a small territory that doubles can beat a large one that barely moves.
3. **Quality check.** Only count enrollments that move forward to the next stage, so the numbers stay honest.

---

## 5. A useful side finding

When I sorted the same data by state, something practical showed up. Several of the least penetrated states hold some of the largest untapped pools. A growth based, bracketed contest points effort straight at that room, instead of rewarding whoever already sits on a big base.

| State | Out of network patients | Currently penetrated |
|---|---:|---:|
| Indiana | 403 | 0.7% |
| Michigan | 663 | 12% |
| Virginia | 287 | 2% |
| Nevada | 164 | 0% |

---

## 6. Bottom line

Bracket by size, then score on growth over baseline. The region view shows the field is even enough that no territory is shut out. The territory view shows it is uneven enough that raw volume would be unfair. Both point to the same setup.

One note on the data. These numbers are built from claims data as a stand-in for demand, so they size the opportunity rather than count actual enrollments. When the live enrollment numbers by territory are available, the same method runs on them without any change, and only the input swaps. The size gap will not move, because it comes from real differences in where the large treatment centers sit, not from the stand-in data.

---

*How the numbers were built: the eligible melanoma cohort, matched to each territory by treating site, then checked to make sure every in-network patient landed in a territory (full coverage). The spread was profiled with the average, the middle value, and the quartiles. Brackets are equal thirds by size.*