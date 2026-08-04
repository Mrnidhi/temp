# Reply to Kolin, 2026-08-04

Reply on the thread "RE: Kolin Knott shared ATC Check_Excersise with you".
Attach a screenshot of the `test.sql` grid, which shows the candidates Compile
holds for the two centres that could not be placed.

---

Hi Kolin,

Call went well. Sent them the transformation logic and the dataset list along with the other docs, so nothing outstanding from my side. It's with them now to build the automation.

On the ATC list, 95 of the 97 Komodo columns are filled in. The five you'd already done came back identical.

Two I couldn't place, screenshot below. Compile has more than one option for each and they sit under different HCOs, so I didn't want to guess. Which would you use?

A few addresses on the list also don't quite match what Compile has for the same building. Happy to send that separately.

Thanks,
Srinidhi

---

## What sits behind each line

**"The five you'd already done came back identical."** Kolin had filled in five
rows by hand. The query reproduces all five, facility and HCO. That is the only
ground truth there was and it is the reason to trust the other 92.

**"Two I couldn't place."** Avera McKennan and TriHealth. Avera has three
candidates: two at 1000 E 23rd St under different HCOs, one a hospital and one
a physician group, and the Transplant Institute at 1315 S Cliff Ave which is
one building from the address on his list. TriHealth's 625 Eden Park Dr looks
like a corporate office and Compile holds nothing there; its two hospitals in
Cincinnati are Bethesda North and Good Samaritan.

**"A few addresses don't quite match."** UAB is 1802 6th Ave S in 35233 rather
than 1802 6th St in 35205, and the Compile version is the one that returns the
ID Kolin had already filled in himself. North Shore is 300 Community Dr rather
than 800. Ohio State Wexner is 410 W 10th Ave rather than 520. Stanford shows
as Stanford in one column of his sheet and Palo Alto in the other.

## Held back deliberately

Both true, both detail for a conversation rather than an email:

- Excel drops the leading zero from Yale's zip, so it reads 6510 rather than
  06510. The pipeline re-pads every zip so it did not break anything.
- The Compile facility ID is a composite, `LOC-xxxxx+H-yyyyy`, and the part
  after the plus is the HCO ID. Column N already contains column Q.
