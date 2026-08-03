# Open questions on the dashboard

Three things on the dashboard.

1. If a TTP slot gets moved earlier instead of later, do we count that as a lost slot? The
   original slot still gets freed and we can't refill it that fast, but the patient isn't
   delayed. Right now I'm counting both, and it's about half the reschedules either way.

2. If one order loses two slots at short notice, is that two or one? Right now it counts as
   two.

3. There are 233 events with no date for the metric they belong to, so they sit in Launch to
   Date but in no year or quarter. Breakdown attached. Do you want those left as they are, or
   handled differently?
