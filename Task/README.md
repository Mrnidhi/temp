On the Active ATC List tab, fill columns N to R for rows 3 to 99.

Take every value from the pasted results tab. Do not type, infer or recall any facility ID, HCO ID or name yourself. Every value must come from a lookup against that tab. If a lookup fails, leave the cell empty and tell me which row.

Use this in N3 and fill down to N99, adjusting only the tab name if it differs:

=XLOOKUP($A3, compile_match!$A:$A, compile_match!$B:$F, "")

It spills across N to R, so do not put anything in O, P, Q or R.

Then tell me three things: how many rows in N3:N99 are non-empty, whether any cell in N3:R99 is #N/A, and what N3 and R3 contain.

Do not paste-special to values yet. Wait for me to check those numbers first.
