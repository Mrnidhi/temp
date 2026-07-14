What I'm trying to figure out: whether monthly enrollment numbers are steady enough to use a simple monthly average as the contest baseline, or whether they bounce around too much (spikes, dips, seasonality) so an average would be misleading. I want to see the monthly pattern first.

Ground rule: Create a new worksheet called "Monthly Trend Check" for all of this. Read enrollment data from the ATC Enrollments tab, but do not edit, move, or reformat that tab or any other existing tab. Everything you build goes on the new sheet only.

Please do these in order and explain each step in plain English:

1. Build a monthly table. From the ATC Enrollments data, aggregate enrollments by month (rows = each month in the history) and by territory (columns), plus a "Total (all territories)" column. So I can see enrollments per territory per month.

2. Add a line chart of Total enrollments by month across the whole history. I want to eyeball the overall shape — is it trending up, is it seasonal, does it spike.

3. Add a second line chart with a few individual territories (pick 4 or 5 with different sizes) plotted by month, so I can see how much each one bounces month to month.

4. Add a "stability" summary table, one row per territory, with these columns:

Average monthly enrollments
Median monthly enrollments
Minimum and Maximum month
Standard deviation
Coefficient of variation = standard deviation ÷ average (this is the key one — a high value means the monthly number is noisy and the average isn't reliable)
5. Sort that summary by coefficient of variation, highest first, so the noisiest territories are at the top. Those are the ones where a plain monthly average would be the least fair.

Keep everything on the new "Monthly Trend Check" sheet, and walk me through what the charts and the coefficient of variation are telling me.

