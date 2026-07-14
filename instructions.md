What to build: a complete enrollment contest scorer on one single sheet. It scores each territory on enrollment growth over its own baseline, grouped into size buckets so small territories compete fairly, with a conversion side prize and a payout. Contest window is Aug 1 to Sep 30.

Ground rule: Put everything on this one active sheet. You may read from the ATC Enrollments and ATC TTPs tabs, but do not edit, rename, move, or reformat those or any other tab. Build the whole thing here.

Do it in this order, and show me each formula in plain English as you go:

1. Settings block (a few cells at the top):

Total prize pot = 30000
Tier 1 cutoff = =PERCENTILE(size column, 2/3)
Tier 2 cutoff = =PERCENTILE(size column, 1/3)
Min enrollments for side prize = 5
1st share = 0.1666, 2nd share = 0.10, side share = 0.0666
2. Territory table — one row per territory (pull the quarterly enrollments per territory from ATC Enrollments):

Size = average of the territory's trailing quarterly enrollments. (Use the quarterly average, not a single month — monthly is too noisy.)
Baseline (2-month target) = Size × 2/3. (A quarter is 3 months, the contest is 2, so this scales the quarterly rate down to the 2-month window while staying smooth.)
Tier = =IF(Size>=Tier1cutoff,"Tier 1",IF(Size>=Tier2cutoff,"Tier 2","Tier 3"))
Contest Enroll = actual Aug–Sep enrollments (leave editable / pull from ATC Enrollments)
Volume Growth = Contest − Baseline
% Growth = (Contest − Baseline) / Baseline
Volume Rank = =SUMPRODUCT((TierCol=thisTier)*(VolGrowthCol>thisVolGrowth))+1
Growth Rank = =SUMPRODUCT((TierCol=thisTier)*(%GrowthCol>this%Growth))+1
Final Score = =AVERAGE(VolRank, GrowthRank)
Place = =SUMPRODUCT((TierCol=thisTier)*((ScoreCol<thisScore)+(ScoreCol=thisScore)*(%GrowthCol>this%Growth)))+1
Result = =IF(Place<=2,"PAID","") (top 2 per tier)
TTPs = pull from the ATC TTPs tab (read only)
Pull-through % = =IFERROR(TTP/Contest,0)
Side Prize = =IF(AND(Contest>=MinEnroll, PullThrough=MAXIFS(PullCol,TierCol,thisTier,ContestCol,">="&MinEnroll)),"SIDE","")
Payout = =IF(Place=1,1stShare*Pot,IF(Place=2,2ndShare*Pot,0))+IF(SidePrize="SIDE",SideShare*Pot,0), formatted as currency
3. RAD bucket — a small separate table below the territory table. All Regional Account Directors compete as one group (no tiers). Same columns: Baseline, Contest, Volume Growth, % Growth, Vol Rank, Growth Rank, Final Score, Place, Result. Rank across all RADs together (not within a tier), top 2 = PAID. A RAD's baseline is the sum of the baselines of the territories they cover.

Keep everything on this one sheet, round any percentages and currency, and explain what each block does as you finish it.