"""Render the P&PR scorecard dashboard (the mandated template, Iovance house style).

This is exactly what Kolin asked for: pick one ATC center and its 13 P&PR metrics fill
across the year, blinded peer-tier, and quarterly columns of the (Proposed) P&PR Metrics
template. Definitions follow memory/ppr-scorecard-spec.md (Meet 6 + template footnotes).
Network / yield / funnel views are a separate later enhancement, intentionally not here."""
import json, os
HERE = os.path.dirname(__file__)
DASH = os.path.join(HERE, "..", "dashboard")
sc = json.load(open(os.path.join(DASH, "scorecard_payload.json")))
default_center = None
# default to the busiest center by launch-to-date enrollments
best, bestv = None, -1
for c in sc["centers"]:
    v = (sc["cv"].get(c, {}).get("Enrollments in IovanceCares", {}) or {}).get("Launch to Date", "0")
    try:
        iv = int(v)
    except ValueError:
        iv = 0
    if iv > bestv:
        best, bestv = c, iv
default_center = best or sc["centers"][0]

HTML = r"""<title>P&PR Scorecard | Iovance</title>
<style>
:root{
  --navy:#17344F; --steel:#2F5D8A; --steel2:#2E6DA4; --lime:#9DC13C; --olive:#567A2E;
  --olive2:#4A6B2E; --red:#C0392B; --gray:#7F8B8F;
  --bg:#e9edf1; --surface:#fff; --surface2:#f2f5f8; --band:#eaf0e4;
  --ink:#17344F; --body:#26333d; --ink-soft:#5c6b76; --faint:#8a97a1;
  --line:#d0d9e0; --grid:#243441; --bench-head:#2E6DA4; --bench-tint:#eef3f9;
  --font:"Segoe UI",system-ui,-apple-system,Roboto,"Helvetica Neue",Arial,sans-serif;
  --mono:ui-monospace,"Cascadia Code",Consolas,Menlo,monospace;
}
@media (prefers-color-scheme:dark){:root{
  --bg:#0c1620; --surface:#12212e; --surface2:#182a38; --band:#1c3020;
  --ink:#dfeaf2; --body:#c5d2dc; --ink-soft:#93a3af; --faint:#6a7883;
  --line:#263a48; --grid:#3a5163; --steel2:#5b8fc4; --bench-head:#274a66; --bench-tint:#14283a; --olive:#5f8a34;
}}
:root[data-theme="light"]{--bg:#e9edf1;--surface:#fff;--surface2:#f2f5f8;--band:#eaf0e4;--ink:#17344F;
  --body:#26333d;--ink-soft:#5c6b76;--faint:#8a97a1;--line:#d0d9e0;--grid:#243441;--bench-head:#2E6DA4;--bench-tint:#eef3f9;--olive:#567A2E;}
:root[data-theme="dark"]{--bg:#0c1620;--surface:#12212e;--surface2:#182a38;--band:#1c3020;--ink:#dfeaf2;
  --body:#c5d2dc;--ink-soft:#93a3af;--faint:#6a7883;--line:#263a48;--grid:#3a5163;--steel2:#5b8fc4;--bench-head:#274a66;--bench-tint:#14283a;--olive:#5f8a34;}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--body);font-family:var(--font);font-size:14px;line-height:1.45}
.page{max-width:1180px;margin:0 auto;background:var(--surface);box-shadow:0 1px 40px rgba(20,40,60,.10)}
.masthead{position:relative;background:var(--navy);color:#fff;padding:22px 34px 20px;overflow:hidden}
.masthead::after{content:"";position:absolute;top:0;right:0;width:220px;height:100%;
  background:var(--lime);clip-path:polygon(38% 0,100% 0,100% 100%,0 100%)}
.mast-in{position:relative;z-index:2;display:flex;justify-content:space-between;align-items:flex-start;gap:20px}
.eyebrow{font-size:11px;letter-spacing:.15em;text-transform:uppercase;color:var(--lime);font-weight:640;margin:0 0 7px}
h1{font-size:25px;font-weight:640;letter-spacing:-.01em;margin:0}
.brand{text-align:right;position:relative;z-index:3}
.wordmark{font-size:26px;font-weight:800;letter-spacing:.02em;color:var(--navy)}
.wordmark .o{color:#fff}
.brand .sub{font-size:9.5px;letter-spacing:.34em;color:var(--navy);font-weight:700;margin-top:1px}
.brand .conf{font-size:9px;color:#0f2437;margin-top:9px;font-weight:600;opacity:.85}
.controls{display:flex;gap:20px;align-items:flex-end;flex-wrap:wrap;padding:16px 34px;background:var(--surface2);border-bottom:1px solid var(--line)}
.field{display:flex;flex-direction:column;gap:5px}
.lab{font-size:10px;font-weight:700;letter-spacing:.1em;text-transform:uppercase;color:var(--faint)}
input[list]{font:inherit;font-size:14px;padding:9px 12px;min-width:320px;color:var(--ink);background:var(--surface);border:1px solid var(--line);border-radius:3px}
input[list]:focus-visible{outline:2px solid var(--steel);outline-offset:1px;border-color:var(--steel)}
.spacer{flex:1}
.asof{font-family:var(--mono);font-size:11px;color:var(--faint);text-align:right;align-self:flex-end}
.asof b{color:var(--ink-soft)}
.toggles{display:flex;border:1px solid var(--line);border-radius:3px;overflow:hidden}
.chip{font:inherit;font-size:12px;font-weight:600;padding:8px 13px;cursor:pointer;background:var(--surface);color:var(--ink-soft);border:none;border-right:1px solid var(--line)}
.chip:last-child{border-right:none}
.chip[aria-pressed="true"]{background:var(--navy);color:#fff}
.chip:focus-visible{outline:2px solid var(--steel);outline-offset:-2px}
.body{padding:20px 34px 8px}
.lead{font-size:13px;color:var(--ink-soft);margin:0 0 16px;line-height:1.5}
.lead b{color:var(--ink)}
.scroll{overflow-x:auto;border:1px solid var(--grid)}
table{border-collapse:collapse;width:100%;font-variant-numeric:tabular-nums}
th,td{border:1px solid var(--grid);padding:7px 11px;text-align:right;white-space:nowrap;font-size:12.5px}
thead .grp{color:#fff;font-style:italic;font-weight:700;font-size:11px;letter-spacing:.03em;text-align:center;padding:6px 11px}
thead .grp.ctr{background:var(--olive)} thead .grp.bench{background:var(--bench-head)} thead .grp.qtr{background:var(--olive2)}
thead .grp.metric-h,thead .lab-h.metric-h{background:var(--navy);color:#fff;text-align:left}
thead .lab-h{background:var(--surface2);color:var(--ink-soft);font-weight:700;font-size:11px}
thead .lab-h.bench{background:var(--bench-tint)}
.cat-col{width:172px}
th.metric-h{min-width:230px}
td.cat{background:var(--band);color:var(--olive2);font-weight:700;font-size:10px;letter-spacing:.05em;text-transform:uppercase;text-align:left;white-space:normal;vertical-align:middle;width:172px}
td.metric{text-align:left;font-weight:500;color:var(--body);white-space:normal;min-width:230px;line-height:1.3}
td.val{color:var(--body)} td.bench-col{background:var(--bench-tint)}
td.ltd{font-weight:700;color:var(--ink)}
tbody tr:hover td.val{background:var(--surface2)}
tbody tr:hover td.bench-col{background:var(--bench-tint);filter:brightness(.98)}
.notes{margin:16px 0 4px;font-size:11.5px;color:var(--ink-soft);line-height:1.6}
.notes .nt{display:flex;gap:8px;margin-bottom:3px}
.notes .st{color:var(--olive);font-weight:700;flex:none}
.proxy{margin-top:10px;padding:10px 13px;background:var(--surface2);border:1px solid var(--line);font-size:11px;color:var(--ink-soft);line-height:1.55}
.proxy b{color:var(--ink)}
.foot-band{background:var(--lime);color:var(--navy);text-align:center;padding:11px;font-size:12px;letter-spacing:.28em;font-weight:700;text-transform:uppercase;margin-top:16px}
.foot-legal{background:var(--navy);color:#cdd8e2;text-align:center;font-size:10.5px;padding:7px}
@media (max-width:720px){input[list]{min-width:220px}}
</style>

<div class="page">
  <header class="masthead"><div class="mast-in">
    <div>
      <p class="eyebrow">AMTAGVI CTAM &nbsp; Patient &amp; Process Review</p>
      <h1>P&amp;PR Scorecard</h1>
    </div>
    <div class="brand">
      <div class="wordmark">I<span class="o">O</span>VANCE</div>
      <div class="sub">BIOTHERAPEUTICS</div>
      <div class="conf">Confidential for Internal Use Only</div>
    </div>
  </div></header>

  <div class="controls">
    <div class="field">
      <label class="lab" for="centerpick">Authorized Treatment Center</label>
      <input list="centerlist" id="centerpick" autocomplete="off" spellcheck="false">
      <datalist id="centerlist"></datalist>
    </div>
    <div class="field">
      <span class="lab">Columns</span>
      <div class="toggles">
        <button class="chip" data-grp="Time" aria-pressed="true">Year</button>
        <button class="chip" data-grp="Benchmark" aria-pressed="true">National</button>
        <button class="chip" data-grp="Quarter" aria-pressed="true">Quarterly</button>
      </div>
    </div>
    <div class="spacer"></div>
    <div class="asof">Source Data As of <b id="asof"></b><br>Synthetic preview build</div>
  </div>

  <div class="body">
    <p class="lead">Select a center and its metrics fill automatically. The three <b>national columns</b> are
      blinded ATC-tier averages and stay the same whichever center you pick, so a center can be read against
      the peer group that fits it.</p>
    <div class="scroll"><table id="matrix"></table></div>

    <div class="notes" id="notes"></div>
    <div class="proxy" id="proxy"></div>
  </div>

  <div class="foot-band">Advancing Immuno-Oncology</div>
  <div class="foot-legal">&copy; 2025 Iovance Biotherapeutics, Inc. &nbsp;|&nbsp; Confidential for Internal Use Only &nbsp;|&nbsp; Built on synthetic data matching the Infinity schema</div>
</div>

<script>
const SC=__SC__, DEFAULT="__DEFAULT__";
const QUARTERS=["Q3'26 QTD","Q2'26","Q1'26","Q4'25"];
const TIMEONLY=SC.time_cols.filter(c=>!QUARTERS.includes(c));
const BENCH_LABEL={"Top 10":"Top 10 ATCs","Top 40":"Top 40 ATCs","New":"'New' ATCs"};
const active={Time:true,Benchmark:true,Quarter:true};
let center=DEFAULT;
document.getElementById("asof").textContent=SC.asof;

const dl=document.getElementById("centerlist");
SC.centers.forEach(c=>{const o=document.createElement("option");o.value=c;dl.appendChild(o);});
const pick=document.getElementById("centerpick"); pick.value=center;
pick.addEventListener("change",()=>{if(SC.centers.includes(pick.value)){center=pick.value;renderMatrix();}});
document.querySelectorAll(".chip").forEach(b=>b.addEventListener("click",()=>{
  const g=b.dataset.grp,on=b.getAttribute("aria-pressed")==="true";
  active[g]=!on;b.setAttribute("aria-pressed",String(!on));renderMatrix();}));

const cval=(m,col)=>(SC.cv[center]||{})[m]?.[col] ?? "";
const bval=(m,col)=>(SC.bv[m]||{})[col] ?? "";
function visibleCols(){
  const cols=[];
  if(active.Time)TIMEONLY.forEach(c=>cols.push({label:c,kind:"time"}));
  if(active.Benchmark)SC.bench_cols.forEach(c=>cols.push({label:c,kind:"bench"}));
  if(active.Quarter)QUARTERS.forEach(c=>cols.push({label:c,kind:"quarter"}));
  return cols;
}
function renderMatrix(){
  const cols=visibleCols(),groups=[];
  cols.forEach(c=>{const last=groups[groups.length-1];
    const name=c.kind==="bench"?"YTD National Metrics":(c.kind==="quarter"?"Quarterly ATC Metrics":center);
    const cls=c.kind==="bench"?"bench":(c.kind==="quarter"?"qtr":"ctr");
    if(last&&last.name===name)last.span++;else groups.push({name,span:1,cls});});
  let h="<thead><tr><th class='grp metric-h cat-col' rowspan='2'>Category</th>"+
        "<th class='grp metric-h' rowspan='2'>Metric</th>";
  groups.forEach(g=>h+=`<th class='grp ${g.cls}' colspan='${g.span}'>${g.name}</th>`);
  h+="</tr><tr>";
  cols.forEach(c=>{const lbl=c.kind==="bench"?BENCH_LABEL[c.label]:c.label;
    h+=`<th class='lab-h ${c.kind==="bench"?"bench":""}'>${lbl}</th>`;});
  h+="</tr></thead><tbody>";
  // group metrics by category, category cell spans its metrics
  const cats=[];
  SC.metrics.forEach(m=>{const last=cats[cats.length-1];
    if(last&&last.g===m.metric_group)last.items.push(m);else cats.push({g:m.metric_group,items:[m]});});
  cats.forEach(cat=>{
    cat.items.forEach((m,i)=>{
      h+="<tr>";
      if(i===0)h+=`<td class='cat' rowspan='${cat.items.length}'>${cat.g}</td>`;
      h+=`<td class='metric'>${m.metric}</td>`;
      cols.forEach(c=>{const v=c.kind==="bench"?bval(m.metric,c.label):cval(m.metric,c.label);
        const cls=c.kind==="bench"?"bench-col":(c.label==="Launch to Date"?"ltd":"");
        h+=`<td class='val ${cls}'>${v||"-"}</td>`;});
      h+="</tr>";
    });
  });
  document.getElementById("matrix").innerHTML=h+"</tbody>";
}
document.getElementById("notes").innerHTML=[
  ["Patient Progression Rate","(patient related drop-offs after mfg. start) / (mfg. starts)."],
  ["Top 10 &amp; Top 40 ATCs","the highest enrolling centers during the specific timeframe (the set shifts over time)."],
  ["'New' ATCs","centers authorized and onboarded in the 2025 calendar year."],
  ["2nd Resections","patients with two or more actual TTP dates; a re-enrollment that never reached a first TTP does not count."],
  ["TTPs Cancelled within 7 Days","cancelled or moved to a later date within 7 days of the scheduled slot, so there is no time to backfill the slot."],
].map(([s,t])=>`<div class="nt"><span class="st">${s}</span><span>${t}</span></div>`).join("");
document.getElementById("proxy").innerHTML=
  "<b>Two metrics run on stand-ins in this preview.</b> The 7-day cancellation metric needs Infinity's "+
  "snapshot history (the feed Jonathan owns) to measure days-to-cancellation exactly; it uses the reschedule "+
  "flag until that is wired in. The 'New' tier needs each center's onboarding year, which is not in the current "+
  "mapping export, so it stands in with the newest low-volume centers. Both resolve automatically once the real fields are connected.";
renderMatrix();
</script>
"""
html = HTML.replace("__SC__", json.dumps(sc)).replace("__DEFAULT__", default_center)
open(os.path.join(DASH, "ppr_scorecard.html"), "w", encoding="utf-8").write(html)
print("wrote dashboard/ppr_scorecard.html", os.path.getsize(os.path.join(DASH,"ppr_scorecard.html"))//1024, "KB | default", default_center)
