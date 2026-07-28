"""Render the P&PR dashboard: the mandated (Proposed) P&PR Metrics template, Iovance house style.

Pick one ATC and its 13 metrics fill across the year columns, the blinded tier benchmark
(Top 10 / Top 40 / New) and the quarterly columns. Optionally set two date windows and the
table becomes a like-for-like comparison of the two periods.

The old Excel view (launch-to-date against all-ATC quartiles) used to be a second tab here.
Removed 2026-07-27: Kolin, Meet 6, said quartiles "confuse the hell out of our sales folks"
and that the team is actively moving away from them.

Definitions follow memory/ppr-scorecard-spec.md (Meet 6 + template footnotes)."""
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
  --navy:#17344F; --steel:#2F5D8A; --lime:#9DC13C; --olive:#567A2E; --olive2:#4A6B2E;
  --bg:#eef1f5; --surface:#fff; --surface2:#f7f9fb; --band:#f1f6ea;
  --ink:#17344F; --body:#2b3742; --ink-soft:#5c6b76; --faint:#8a97a1;
  --line:#e0e7ee; --rule:#edf1f5; --bench-head:#2E6DA4; --bench-tint:#f4f8fc;
  --shadow:0 1px 3px rgba(20,40,60,.05),0 12px 40px rgba(20,40,60,.08);
  --font:"Segoe UI",system-ui,-apple-system,Roboto,"Helvetica Neue",Arial,sans-serif;
  --mono:ui-monospace,"Cascadia Code",Consolas,Menlo,monospace;
}
@media (prefers-color-scheme:dark){:root{
  --bg:#0c1620; --surface:#12212e; --surface2:#17293700; --band:#1b2c22;
  --ink:#dfeaf2; --body:#c5d2dc; --ink-soft:#93a3af; --faint:#6a7883;
  --line:#243646; --rule:#1b2c3a; --bench-head:#274a66; --bench-tint:#152736; --olive:#5f8a34;
  --surface2:#172937; --shadow:0 1px 3px rgba(0,0,0,.4);
}}
:root[data-theme="light"]{--bg:#eef1f5;--surface:#fff;--surface2:#f7f9fb;--band:#f1f6ea;--ink:#17344F;
  --body:#2b3742;--ink-soft:#5c6b76;--faint:#8a97a1;--line:#e0e7ee;--rule:#edf1f5;
  --bench-head:#2E6DA4;--bench-tint:#f4f8fc;--olive:#567A2E;}
:root[data-theme="dark"]{--bg:#0c1620;--surface:#12212e;--surface2:#172937;--band:#1b2c22;--ink:#dfeaf2;
  --body:#c5d2dc;--ink-soft:#93a3af;--faint:#6a7883;--line:#243646;--rule:#1b2c3a;
  --bench-head:#274a66;--bench-tint:#152736;--olive:#5f8a34;}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--body);font-family:var(--font);font-size:14px;line-height:1.45}
.page{max-width:1240px;margin:22px auto;background:var(--surface);border-radius:10px;overflow:hidden;box-shadow:var(--shadow)}

/* masthead */
.masthead{position:relative;background:var(--navy);color:#fff;padding:24px 34px 22px;overflow:hidden}
.masthead::after{content:"";position:absolute;top:0;right:0;width:210px;height:100%;
  background:var(--lime);clip-path:polygon(40% 0,100% 0,100% 100%,0 100%)}
.mast-in{position:relative;z-index:2;display:flex;justify-content:space-between;align-items:flex-start;gap:20px}
.eyebrow{font-size:10.5px;letter-spacing:.16em;text-transform:uppercase;color:var(--lime);font-weight:650;margin:0 0 7px}
h1{font-size:26px;font-weight:650;letter-spacing:-.015em;margin:0}
.brand{text-align:right;position:relative;z-index:3}
.wordmark{font-size:25px;font-weight:800;letter-spacing:.02em;color:var(--navy)}
.wordmark .o{color:#fff}
.brand .sub{font-size:9.5px;letter-spacing:.34em;color:var(--navy);font-weight:700;margin-top:1px}
.brand .conf{font-size:9px;color:#0f2437;margin-top:9px;font-weight:600;opacity:.85}

/* controls */
.controls{display:flex;gap:22px;align-items:flex-end;flex-wrap:wrap;padding:18px 34px;
  background:var(--surface2);border-bottom:1px solid var(--line)}
.field{display:flex;flex-direction:column;gap:6px}
.lab{font-size:10px;font-weight:700;letter-spacing:.1em;text-transform:uppercase;color:var(--faint)}
input[list]{font:inherit;font-size:14.5px;font-weight:600;padding:10px 13px;min-width:330px;color:var(--ink);
  background:var(--surface);border:1px solid var(--line);border-radius:6px}
input[list]:focus-visible{outline:2px solid var(--steel);outline-offset:1px;border-color:var(--steel)}
.spacer{flex:1}
.asof{font-family:var(--mono);font-size:11px;color:var(--faint);text-align:right;align-self:flex-end;line-height:1.6}
.asof b{color:var(--ink-soft)}
.toggles{display:flex;border:1px solid var(--line);border-radius:6px;overflow:hidden;background:var(--surface)}
.chip{font:inherit;font-size:12px;font-weight:600;padding:9px 14px;cursor:pointer;background:var(--surface);
  color:var(--ink-soft);border:none;border-right:1px solid var(--line)}
.chip:last-child{border-right:none}
.chip[aria-pressed="true"]{background:var(--navy);color:#fff}
.chip:focus-visible{outline:2px solid var(--steel);outline-offset:-2px}

/* table: rules not boxes, and the two label columns stay put while you scroll right */
.body{padding:22px 34px 10px}
.scroll{overflow:auto;max-height:74vh;border:1px solid var(--line);border-radius:8px}
table{border-collapse:separate;border-spacing:0;width:100%;font-variant-numeric:tabular-nums}
th,td{padding:9px 14px;text-align:right;white-space:nowrap;font-size:13px;border-bottom:1px solid var(--rule)}
thead th{position:sticky;top:0;z-index:3}
thead tr:nth-child(2) th{top:30px}
thead .grp{color:#fff;font-weight:700;font-size:10.5px;letter-spacing:.06em;text-transform:uppercase;
  text-align:center;padding:0 14px;height:30px;border-bottom:none}
thead .grp.ctr{background:var(--olive)} thead .grp.bench{background:var(--bench-head)} thead .grp.qtr{background:var(--olive2)}
thead .grp.metric-h{background:var(--navy);color:#fff;text-align:left;z-index:6}
thead .lab-h{background:var(--surface2);color:var(--ink-soft);font-weight:700;font-size:11px;
  border-bottom:1px solid var(--line)}
thead .lab-h.bench{background:var(--bench-tint)}
.cat-col{width:150px;min-width:150px}
th.metric-h{min-width:250px;width:250px}
/* Category and Metric stay pinned while the value columns scroll right. Without this
   you lose which row you are reading the moment you look at a quarterly column. */
th.cat-col,td.cat{position:sticky;left:0}
th.metric-h:not(.cat-col),td.metric{position:sticky;left:150px}
td.cat,td.metric{z-index:2}
th.cat-col,th.metric-h{z-index:6}
td.cat{background:var(--band);color:var(--olive2);font-weight:700;font-size:9.5px;letter-spacing:.06em;
  text-transform:uppercase;text-align:left;white-space:normal;vertical-align:middle;line-height:1.35}
td.metric{background:var(--surface);text-align:left;font-weight:500;color:var(--body);white-space:normal;
  line-height:1.35;border-right:1px solid var(--line)}
td.val{color:var(--body)}
td.bench-col{background:var(--bench-tint)}
td.ltd{font-weight:700;color:var(--ink)}
tbody tr:last-child td{border-bottom:none}
tbody tr:hover td.val{background:var(--surface2)}
tbody tr:hover td.metric{background:var(--surface2)}
tbody tr:hover td.bench-col{background:var(--bench-tint);filter:brightness(.985)}

/* date window compare */
.winrow{display:flex;align-items:center;gap:6px;flex-wrap:wrap}
.winrow input[type=date]{font:inherit;font-size:12px;padding:8px 9px;color:var(--ink);background:var(--surface);
  border:1px solid var(--line);border-radius:6px}
.winrow .dash{color:var(--faint);font-size:11px}
.winrow .vs{color:var(--ink-soft);font-size:11px;font-weight:700;margin:0 4px}
.chip.go{background:var(--olive);color:#fff;border:1px solid var(--olive);border-radius:6px}
#winClear{border:1px solid var(--line);border-radius:6px}
/* Two range inputs stacked on one track. Only the thumbs take pointer events, so
   whichever handle you grab is the one that moves. */
.slider{position:relative;height:26px;margin:8px 2px 0;min-width:340px}
.slider .track,.slider .fill{position:absolute;top:11px;height:4px;border-radius:2px}
.slider .track{left:0;right:0;background:var(--line)}
.slider .fill{background:var(--olive)}
.slider input[type=range]{position:absolute;top:0;left:0;width:100%;height:26px;margin:0;
  background:none;-webkit-appearance:none;appearance:none;pointer-events:none}
.slider input[type=range]::-webkit-slider-thumb{-webkit-appearance:none;pointer-events:auto;
  width:16px;height:16px;border-radius:50%;background:var(--surface);border:2px solid var(--olive);
  cursor:grab;box-shadow:0 1px 3px rgba(20,40,60,.25)}
.slider input[type=range]::-moz-range-thumb{pointer-events:auto;width:16px;height:16px;
  border-radius:50%;background:var(--surface);border:2px solid var(--olive);cursor:grab}
td.diff{background:rgba(47,93,138,.07);font-weight:600}

.notes{margin:16px 0 4px;font-size:11.5px;color:var(--ink-soft);line-height:1.6}
.notes .nt{display:flex;gap:8px;margin-bottom:3px}
.notes .st{color:var(--olive);font-weight:700;flex:none;min-width:14px}
.foot-band{background:var(--lime);color:var(--navy);text-align:center;padding:11px;font-size:11.5px;
  letter-spacing:.28em;font-weight:700;text-transform:uppercase;margin-top:18px}
.foot-legal{background:var(--navy);color:#cdd8e2;text-align:center;font-size:10.5px;padding:8px}
@media (max-width:720px){input[list]{min-width:220px}.body,.controls,.masthead{padding-left:18px;padding-right:18px}}
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
    <div class="field" id="colToggles">
      <span class="lab">Columns</span>
      <div class="toggles">
        <button class="chip" data-grp="Time" aria-pressed="true">Year</button>
        <button class="chip" data-grp="Benchmark" aria-pressed="true">National</button>
        <button class="chip" data-grp="Quarter" aria-pressed="true">Quarterly</button>
      </div>
    </div>
    <div class="field" id="winFields">
      <span class="lab">Date window (each metric counts by its own event date)</span>
      <div class="winrow">
        <input type="date" id="w0" title="Window start"><span class="dash">to</span><input type="date" id="w1" title="Window end">
        <button class="chip" id="winClear">Reset</button>
        <div class="toggles" id="aggT">
          <button class="chip" data-agg="median" aria-pressed="true">Median</button>
          <button class="chip" data-agg="mean" aria-pressed="false">Avg</button>
        </div>
      </div>
      <div class="slider" id="slider">
        <div class="track"></div><div class="fill" id="sfill"></div>
        <input type="range" id="s0" min="0" max="100" value="0">
        <input type="range" id="s1" min="0" max="100" value="100">
      </div>
    </div>
    <div class="spacer"></div>
    <div class="asof">Source Data As of <b id="asof"></b><br><span id="buildtag"></span></div>
  </div>

  <div class="body">
    <div class="scroll"><table id="matrix"></table></div>
    <div class="notes" id="notes"></div>
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
// Label the data source honestly. Synthetic numbers must never pass as real, and real
// numbers must never carry a synthetic caption.
document.getElementById("buildtag").textContent =
  SC.synthetic ? "SYNTHETIC DATA - preview only" : "Infinity extract";
if(SC.synthetic)document.getElementById("buildtag").style.color="#C0392B";

const dl=document.getElementById("centerlist");
SC.centers.forEach(c=>{const o=document.createElement("option");o.value=c;dl.appendChild(o);});
const pick=document.getElementById("centerpick"); pick.value=center;
pick.addEventListener("change",()=>{if(SC.centers.includes(pick.value)){center=pick.value;render();}});
document.querySelectorAll(".chip").forEach(b=>b.addEventListener("click",()=>{
  const g=b.dataset.grp,on=b.getAttribute("aria-pressed")==="true";
  if(!g)return; active[g]=!on;b.setAttribute("aria-pressed",String(!on));render();}));

const cval=(m,col)=>(SC.cv[center]||{})[m]?.[col] ?? "";
const bval=(m,col)=>(SC.bv[m]||{})[col] ?? "";

/* ---- custom date-window engine -------------------------------------------
   Mirrors compute() in build_scorecard.py: every metric is filtered on ITS OWN
   event date, so a window means "what happened between these dates". Lets you
   reproduce Kolin's year-over-year slides (e.g. Jan'25-Sep'25 vs Oct'25-May'26)
   without rerunning the pipeline. */
/* Metric names are looked up from the payload by the template's metric_order, never
   retyped here. They were retyped once, and when metrics 11-13 were renamed from
   "Average Time From..." to "Median Time From..." in build_scorecard.py this map kept
   the old spelling, so all three timing rows silently rendered "-" in window compare.
   Now a rename cannot drift, and a missing metric throws instead of blanking a row. */
const ORDER={enr:1,pat:2,can:3,cttp:4,sttp:5,res2:6,drop:7,oos:8,prog:9,inf:10,d1:11,d2:12,d3:13};
const M={};
for(const k in ORDER){
  const hit=SC.metrics.find(m=>m.metric_order===ORDER[k]);
  if(!hit)throw new Error("metric_order "+ORDER[k]+" is missing from the payload");
  M[k]=hit.metric;
}
/* Median by default, because rows 11-13 are literally titled "Median Time From..." and the
   launch-to-date columns are computed with median in build_scorecard.py. A mean sitting under
   a heading that says median is the one error you cannot walk back in a meeting. */
let win=null, aggMode="median";
const inWin=(d,a,b)=>d&&d>=a&&d<=b;
function avg(xs){ if(!xs.length)return NaN;
  if(aggMode==="median"){const s=[...xs].sort((p,q)=>p-q),h=s.length>>1;
    return s.length%2?s[h]:(s[h-1]+s[h])/2;}
  return xs.reduce((p,q)=>p+q,0)/xs.length; }
function computeWin(rows,a,b){
  const W=m=>rows.filter(r=>inWin(r[SC.event_date[m]],a,b));
  const uniq=(rs,k)=>new Set(rs.map(r=>r[k]).filter(v=>v!=null)).size;
  const sum=(rs,k)=>rs.reduce((t,r)=>t+(+r[k]||0),0);
  const nums=(rs,k)=>rs.map(r=>r[k]).filter(v=>v!=null&&v!=="").map(Number).filter(v=>!isNaN(v));
  const wp=W(M.prog), mfg=sum(wp,"mfg_started");
  const wr=W(M.res2), byPat={};
  wr.forEach(r=>{if(r.tumor_pickup_date){(byPat[r.iovance_patient_id]=byPat[r.iovance_patient_id]||new Set()).add(r.tumor_pickup_date);}});
  const o={};
  o[M.enr]=uniq(W(M.enr),"order_request__til_order_name");
  o[M.pat]=uniq(W(M.pat),"iovance_patient_id");
  o[M.can]=sum(W(M.can),"ttp_cancel_le7");
  o[M.cttp]=sum(W(M.cttp),"completed_ttp");
  o[M.sttp]=sum(W(M.sttp),"scheduled_ttp");
  o[M.res2]=Object.values(byPat).filter(s=>s.size>=2).length;
  o[M.drop]=sum(W(M.drop),"dropout_post_ttp_health");
  o[M.oos]=sum(W(M.oos),"oos_product");
  o[M.prog]=mfg?sum(wp,"drop_after_mfg")/mfg:NaN;
  o[M.inf]=sum(W(M.inf),"amtagvi_infused");
  o[M.d1]=avg(nums(W(M.d1),"days_enroll_to_ttp"));
  o[M.d2]=avg(nums(W(M.d2),"days_ttp_to_infusion"));
  o[M.d3]=avg(nums(W(M.d3),"days_delivery_to_infusion"));
  return o;
}
const vtype=m=>(SC.metrics.find(x=>x.metric===m)||{}).value_type;
function fmtv(m,v){ if(v==null||(typeof v==="number"&&isNaN(v)))return "-";
  const t=vtype(m); return t==="rate"?(v*100).toFixed(1)+"%":t==="days"?v.toFixed(1):String(Math.round(v)); }
function fmtd(m,v){ if(v==null||(typeof v==="number"&&isNaN(v)))return "-";
  const t=vtype(m), s=v>0?"+":""; return t==="rate"?s+(v*100).toFixed(1)+"pt":t==="days"?s+v.toFixed(1):s+Math.round(v); }
const rowsFor=c=>SC.raw.filter(r=>r.atc===c);
function catGroups(){
  const cats=[];
  SC.metrics.forEach(m=>{const last=cats[cats.length-1];
    if(last&&last.g===m.metric_group)last.items.push(m);else cats.push({g:m.metric_group,items:[m]});});
  return cats;
}
function bodyRows(cellsFn){
  let h="";
  catGroups().forEach(cat=>{
    cat.items.forEach((m,i)=>{
      h+="<tr>";
      if(i===0)h+=`<td class='cat' rowspan='${cat.items.length}'>${cat.g}</td>`;
      h+=`<td class='metric'>${m.metric}</td>`+cellsFn(m)+"</tr>";
    });
  });
  return h;
}
function visibleCols(){
  const cols=[];
  if(active.Time)TIMEONLY.forEach(c=>cols.push({label:c,kind:"time"}));
  if(active.Benchmark)SC.bench_cols.forEach(c=>cols.push({label:c,kind:"bench"}));
  if(active.Quarter)QUARTERS.forEach(c=>cols.push({label:c,kind:"quarter"}));
  return cols;
}
function renderProposed(){
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
  h+=bodyRows(m=>cols.map(c=>{
    const v=c.kind==="bench"?bval(m.metric,c.label):cval(m.metric,c.label);
    const cls=c.kind==="bench"?"bench-col":(c.label==="Launch to Date"?"ltd":"");
    return `<td class='val ${cls}'>${v||"-"}</td>`;}).join(""));
  document.getElementById("matrix").innerHTML=h+"</tbody>";
}
function renderWindows(){
  // The window column sits beside Launch to Date on purpose: the anchor is what makes
  // a windowed number readable, and it makes an impossible value (window > all time)
  // obvious on sight.
  const W=computeWin(rowsFor(center),win.w0,win.w1);
  let h="<thead><tr><th class='grp metric-h cat-col' rowspan='2'>Category</th>"+
        "<th class='grp metric-h' rowspan='2'>Metric</th>"+
        `<th class='grp ctr' colspan='2'>${center}</th></tr><tr>`+
        "<th class='lab-h'>Launch to Date</th>"+
        `<th class='lab-h'>${win.w0} to ${win.w1}</th></tr></thead><tbody>`;
  h+=bodyRows(m=>
    `<td class='val'>${cval(m.metric,"Launch to Date")||"-"}</td>`+
    `<td class='val ltd'>${fmtv(m.metric,W[m.metric])}</td>`);
  document.getElementById("matrix").innerHTML=h+"</tbody>";
}
const NOTES_PROPOSED=[
  ["*","Patient Progression Rate = (patient related drop-offs after mfg. start) / (mfg. starts)"],
  ["*","Top 10 &amp; Top 40 ATCs defined as highest enrolling centers during specific timeframe"],
  ["**","'New' refers to ATCs authorized &amp; onboarded in the 2025 calendar year"],
];
const NOTES_WINDOW=[
  ["*","Each metric is counted on its own event date (enrollment, TTP pickup, delivery, or infusion), matching Kolin's decks."],
  ["*","Launch to Date is shown beside the window as an anchor. A window can never exceed it."],
];

// ---- one date window: drag the handles or type the dates, they drive each other ----
const DATEF=[...new Set(Object.values(SC.event_date))];
let DMIN=null,DMAX=null;
SC.raw.forEach(r=>DATEF.forEach(f=>{const v=r[f];
  if(v){ if(!DMIN||v<DMIN)DMIN=v; if(!DMAX||v>DMAX)DMAX=v; }}));
const DAY=86400000;
const d2n=s=>Math.round((Date.parse(s)-Date.parse(DMIN))/DAY);
const n2d=n=>new Date(Date.parse(DMIN)+n*DAY).toISOString().slice(0,10);
const SPAN=Math.max(1,d2n(DMAX));

const s0=document.getElementById("s0"),s1=document.getElementById("s1"),
      w0i=document.getElementById("w0"),w1i=document.getElementById("w1"),
      sfill=document.getElementById("sfill");
[s0,s1].forEach(s=>{s.min=0;s.max=SPAN;});
[w0i,w1i].forEach(i=>{i.min=DMIN;i.max=DMAX;});

function paint(){
  const a=Math.min(+s0.value,+s1.value), b=Math.max(+s0.value,+s1.value);
  sfill.style.left=(a/SPAN*100)+"%";
  sfill.style.right=(100-b/SPAN*100)+"%";
}
function fromSlider(){
  const a=Math.min(+s0.value,+s1.value), b=Math.max(+s0.value,+s1.value);
  win={w0:n2d(a),w1:n2d(b)};
  w0i.value=win.w0; w1i.value=win.w1;
  paint(); render();
}
function fromDates(){
  if(!(w0i.value&&w1i.value))return;              // half-typed date, wait
  let a=w0i.value,b=w1i.value; if(a>b)[a,b]=[b,a];
  win={w0:a,w1:b};
  s0.value=Math.max(0,Math.min(SPAN,d2n(a)));
  s1.value=Math.max(0,Math.min(SPAN,d2n(b)));
  paint(); render();
}
function resetWin(){
  win=null; s0.value=0; s1.value=SPAN;
  w0i.value=DMIN; w1i.value=DMAX;
  paint(); render();
}
s0.addEventListener("input",fromSlider);
s1.addEventListener("input",fromSlider);
w0i.addEventListener("change",fromDates);
w1i.addEventListener("change",fromDates);
document.getElementById("winClear").addEventListener("click",resetWin);
document.querySelectorAll("#aggT .chip").forEach(b=>b.addEventListener("click",()=>{
  aggMode=b.dataset.agg;
  document.querySelectorAll("#aggT .chip").forEach(x=>x.setAttribute("aria-pressed",String(x===b)));
  if(win)render();}));

function render(){
  document.getElementById("colToggles").style.display = win ? "none" : "";
  document.getElementById("aggT").style.display = win ? "" : "none";
  if(win)renderWindows(); else renderProposed();
  const notes = win?NOTES_WINDOW:NOTES_PROPOSED;
  document.getElementById("notes").innerHTML=
    notes.map(([s,t])=>`<div class="nt"><span class="st">${s}</span><span>${t}</span></div>`).join("");
}
w0i.value=DMIN; w1i.value=DMAX; s0.value=0; s1.value=SPAN;
paint(); render();
</script>
"""
html = HTML.replace("__SC__", json.dumps(sc)).replace("__DEFAULT__", default_center)
open(os.path.join(DASH, "ppr_scorecard.html"), "w", encoding="utf-8").write(html)
print("wrote dashboard/ppr_scorecard.html", os.path.getsize(os.path.join(DASH,"ppr_scorecard.html"))//1024, "KB | default", default_center)
