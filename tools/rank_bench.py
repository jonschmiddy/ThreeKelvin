# -*- coding: utf-8 -*-
"""Cull, then rank by pairwise comparison. Three tiers, 35 hulls each.

    python tools/rank_bench.py [pool_dir] [out.html] [storage_key]

Each bench gets its own output file AND its own storage key. Two benches
sharing a key would have one page's keeps silently answering for the other's,
and the verdicts are the expensive part -- they are the only thing here a
person spent time on.

PASS 1 is the cull, same question as always: keep, cut, or mirror. It is a grid,
because "is this Korvan" is an absolute judgement you can make on one card.

PASS 2 is a BRACKET, because "is this more advanced than that" is not. Ranking
35 hulls by eye in a grid is a task nobody can do consistently -- you cannot
hold 35 things in your head at once. Shown two at a time, the same judgement is
easy and repeatable, and a sort turns those answers into a total order.

The sort is a bottom-up merge sort driven by the person: whenever it needs to
know which of two hulls is more advanced, it stops and asks. That costs about
n*log2(n) comparisons -- roughly 130 for 35 hulls, fewer for a culled set --
against the ~600 a full round-robin would need, and unlike a round robin it
cannot produce a cycle.

State lives in the browser, so the sort can be stopped and resumed. Every choice
is undoable, because a misclick early in a merge sort quietly poisons everything
downstream and there is no way to see that from the result.
"""
import base64
import io
import json
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "tools", "out", "rank.html")
DEFAULT_TIERS = ("light", "medium", "heavy")


def groups(pool):
	"""Tab order: groups.txt if the pool has one, else whatever folders exist.

	The bench started life with three weight classes. Pointed at a pool of every
	heavy ever generated it needs seventeen tabs in round order instead, and
	alphabetical is not round order once you pass r09.
	"""
	man = os.path.join(pool, "groups.txt")
	if os.path.isfile(man):
		with io.open(man, encoding="utf-8") as f:
			names = [ln.strip() for ln in f if ln.strip()]
		if names:
			return names
	here = [n for n in sorted(os.listdir(pool))
		if os.path.isdir(os.path.join(pool, n))]
	return [n for n in DEFAULT_TIERS if n in here] or here


def bbox_of(path):
	"""The ship inside the canvas. These are pre-trimmed, so it is the canvas."""
	with open(path, "rb") as f:
		b = f.read()
	w, h = struct.unpack(">II", b[16:24])
	return w, h


def candidates(pool, tiers):
	out = []
	for tier in tiers:
		d = os.path.join(pool, tier)
		if not os.path.isdir(d):
			continue
		for n in sorted(os.listdir(d)):
			if not n.lower().endswith(".png"):
				continue
			p = os.path.join(d, n)
			with open(p, "rb") as f:
				raw = f.read()
			w, h = bbox_of(p)
			out.append({
				"id": os.path.splitext(n)[0],
				"tier": tier,
				"w": w, "h": h,
				"ratio": round(w / float(h), 2) if h else 0,
				"src": "data:image/png;base64," + base64.b64encode(raw).decode("ascii"),
			})
	return out


PAGE = u'''<title>@@TITLE@@</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Instrument+Serif:ital@0;1&family=IBM+Plex+Mono:wght@400;500&family=Silkscreen&display=swap">
<style>
:root{--void:#070a10;--sunk:#04060a;--panel:#0b1018;--line:#1d2735;--line2:#2a3648;
 --ice:#ccd7e4;--cold:#8a9ab0;--dim:#5d6d83;--flare:#d99b29;--hot:#ffd28a;
 --good:#5fa88a;--bad:#a85f52;
 --serif:"Instrument Serif",Georgia,serif;
 --mono:"IBM Plex Mono",ui-monospace,Consolas,monospace;
 --pix:"Silkscreen",var(--mono);}
*{box-sizing:border-box}
@media (prefers-reduced-motion:reduce){*{transition:none!important}}
body{margin:0;background:var(--void);color:var(--ice);font-family:var(--mono);
 font-size:14px;line-height:1.55}
.wrap{max-width:min(1560px,96vw);margin:0 auto;padding:36px 20px 80px}
.eyebrow{font-family:var(--pix);font-size:10px;letter-spacing:.18em;color:var(--flare);
 text-transform:uppercase;margin:0 0 12px}
h1{font-family:var(--serif);font-weight:400;font-size:clamp(32px,5vw,46px);
 line-height:1;margin:0 0 12px}
.stand{max-width:70ch;color:var(--cold);margin:0;font-size:13px}
.stand b{color:var(--ice);font-weight:500}

.bar{display:flex;flex-wrap:wrap;gap:8px;align-items:center;margin:22px 0 0;
 padding:12px 0;border-top:1px solid var(--line);border-bottom:1px solid var(--line);
 position:sticky;top:0;background:var(--void);z-index:5}
.seg{display:flex;gap:0;flex-wrap:wrap}
.seg button,.act{font-family:var(--pix);font-size:9px;letter-spacing:.1em;
 text-transform:uppercase;color:var(--cold);background:transparent;
 border:1px solid var(--line);padding:8px 11px;cursor:pointer}
.seg button+button{border-left:0}
.seg button[aria-pressed="true"]{background:var(--flare);color:#0c0a06;
 border-color:var(--flare)}
.act:hover,.seg button:hover{border-color:var(--flare);color:var(--ice)}
.count{font-size:11.5px;color:var(--dim);font-variant-numeric:tabular-nums}
.sp{flex:1 1 auto}
:focus-visible{outline:2px solid var(--flare);outline-offset:2px}

.blurb{margin:16px 0 0;color:var(--dim);font-size:12.5px;max-width:76ch}
.blurb b{color:var(--ice);font-weight:500}

.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(258px,1fr));
 gap:10px;margin-top:16px}
.card{border:1px solid var(--line);background:var(--panel);padding:9px}
.card[data-v="keep"]{border-color:var(--good)}
.card[data-v="cut"]{border-color:var(--bad);opacity:.5}
.chead{display:flex;align-items:baseline;gap:8px;margin-bottom:7px}
.cname{font-family:var(--pix);font-size:9px;letter-spacing:.1em;color:var(--ice)}
.cdim{font-size:10.5px;color:var(--dim);font-variant-numeric:tabular-nums;
 margin-left:auto}
.shot{background:var(--sunk);display:flex;align-items:flex-end;padding:8px;
 overflow-x:auto;min-height:70px}
.shot img{display:block;image-rendering:pixelated;max-width:none}
.btns{display:flex;gap:5px;margin-top:8px;flex-wrap:wrap}
.btns button{font-family:var(--pix);font-size:8px;letter-spacing:.08em;
 text-transform:uppercase;color:var(--dim);background:transparent;
 border:1px solid var(--line);padding:6px 8px;cursor:pointer;flex:1 1 auto}
.btns button:hover{color:var(--ice);border-color:var(--line2)}
.btns button[aria-pressed="true"][data-v="keep"]{background:var(--good);
 color:#06120d;border-color:var(--good)}
.btns button[aria-pressed="true"][data-v="cut"]{background:var(--bad);
 color:#150705;border-color:var(--bad)}
.btns button[aria-pressed="true"][data-m]{background:var(--ice);color:#0a0e16;
 border-color:var(--ice)}

/* ---- bracket ---- */
.duel{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-top:18px}
.pick{border:1px solid var(--line);background:var(--panel);padding:14px;
 cursor:pointer;display:flex;flex-direction:column;gap:10px;text-align:left;
 color:inherit;font:inherit}
.pick:hover{border-color:var(--flare)}
.pick .shot{min-height:120px;align-items:center;justify-content:center}
.pick .cname{font-size:10px}
.progress{height:3px;background:var(--line);margin-top:16px;overflow:hidden}
.progress i{display:block;height:100%;background:var(--flare);width:0}
.pmeta{display:flex;gap:14px;margin-top:8px;font-size:11.5px;color:var(--dim);
 font-variant-numeric:tabular-nums;align-items:center;flex-wrap:wrap}
.hint{font-size:11.5px;color:var(--dim);margin-top:12px}
.hint kbd{font-family:var(--mono);border:1px solid var(--line2);padding:1px 5px;
 color:var(--cold)}

.ranked{margin-top:18px;display:flex;flex-direction:column;gap:6px}
.row{display:flex;align-items:center;gap:12px;border:1px solid var(--line);
 background:var(--panel);padding:8px 10px}
.rank{font-family:var(--pix);font-size:11px;color:var(--flare);min-width:28px;
 text-align:right}
.row .shot{flex:1 1 auto;background:var(--sunk);min-height:0}
.tierpill{font-family:var(--pix);font-size:8px;letter-spacing:.08em;
 text-transform:uppercase;padding:3px 7px;border:1px solid var(--line2);
 color:var(--cold)}
.empty{color:var(--dim);font-size:12.5px;margin-top:20px}
footer{margin-top:44px;border-top:1px solid var(--line);padding-top:18px;
 color:var(--dim);font-size:12px;max-width:78ch}
footer b{color:var(--cold)}
</style>
<div class="wrap">
<header>
 <div class="eyebrow">Three Kelvin &middot; Korvan &middot; @@N@@ hulls</div>
 <h1>@@TITLE@@</h1>
 <p class="stand">@@STAND@@ Cull, then rank what survives by asking which of two hulls is
 <b>more advanced</b>. Everything is kept in this browser, so you can stop and come back.</p>
</header>

<div class="bar">
 <div class="seg" role="group" aria-label="Tier" id="tierseg"></div>
 <div class="seg" role="group" aria-label="Pass">
  <button id="p1" aria-pressed="true">1 &mdash; cull</button>
  <button id="p2" aria-pressed="false">2 &mdash; rank</button>
 </div>
 <div class="seg" role="group" aria-label="Zoom" id="zoomseg"></div>
 <span class="count" id="cnt"></span>
 <span class="sp"></span>
 <button class="act" id="undo" hidden>Undo</button>
 <button class="act" id="reset" hidden>Restart rank</button>
 <button class="act" id="copy">Copy results</button>
</div>

<p class="blurb" id="blurb"></p>
<div id="stage"></div>

<footer>
 <p><b>Pass 1</b> asks one thing per hull: does it belong in the Korvan line. Mirror flips a
 hull that is facing the wrong way; the export records it and the sprite is flipped when the
 art is built.</p>
 <p><b>Pass 2</b> shows two hulls and asks which is further along &mdash; more equipment, more
 armour, more of a ship. It only ever compares hulls you kept, within one tier. The answers
 are fed to a merge sort, so about @@CMP@@ comparisons produce a full ranking of 35 rather
 than the ~600 that comparing every pair would need. <b>Undo</b> steps back one answer.</p>
 <p><b>Copy results</b> puts JSON on the clipboard: per hull its tier, verdict and mirror
 flag, plus the ranked order per tier, most advanced first.</p>
</footer>
</div>
<script>
var CAND = @@CAND@@;
var KEY = "@@KEY@@";
var TIERS = @@TIERS@@;
var S = {v:{}, r:{}};
try { S = JSON.parse(localStorage.getItem(KEY)) || S; } catch(e){}
if (!S.v) S.v = {};
if (!S.r) S.r = {};
var tier = TIERS[0], pass = 1, hist = [];
// Default 2x: at 1x a 96-pixel-deep light is too small to judge on a
// modern display, which is the whole point of the exercise.
var zoom = S.z || 2;
function save(){ S.z = zoom; try { localStorage.setItem(KEY, JSON.stringify(S)); } catch(e){} }

function inTier(t){ return CAND.filter(function(c){ return c.tier === t; }); }
function kept(t){
  return inTier(t).filter(function(c){ return (S.v[c.id]||{}).verdict === "keep"; })
                  .map(function(c){ return c.id; });
}
function byId(id){
  for (var i=0;i<CAND.length;i++) if (CAND[i].id === id) return CAND[i];
  return null;
}
function img(c, big){
  var im = document.createElement("img");
  var k = zoom;
  im.src = c.src; im.width = c.w*k; im.height = c.h*k; im.alt = c.id;
  if ((S.v[c.id]||{}).flip) im.style.transform = "scaleX(-1)";
  return im;
}
function shot(c, big){
  var d = document.createElement("div"); d.className = "shot";
  d.appendChild(img(c, big)); return d;
}

/* ---------- pass 1 : cull ---------- */
function drawCull(){
  var set = inTier(tier);
  var wide = 0;
  set.forEach(function(c){ if (c.w > wide) wide = c.w; });
  var host = document.createElement("div"); host.className = "grid";
  // Size the column to the WIDEST sprite in the tier at this zoom, so no card
  // ever has to scroll its own contents. Fewer columns and a longer page is the
  // right trade -- a scrollbar inside a 350px box is unusable for judging art,
  // and you cannot compare two hulls when one of them is cropped.
  host.style.gridTemplateColumns =
    "repeat(auto-fill,minmax(" + (wide * zoom + 36) + "px,1fr))";
  set.forEach(function(c){
    var v = S.v[c.id] || {};
    var box = document.createElement("div"); box.className = "card";
    if (v.verdict) box.setAttribute("data-v", v.verdict);
    var h = document.createElement("div"); h.className = "chead";
    var n = document.createElement("span"); n.className = "cname"; n.textContent = c.id;
    var dm = document.createElement("span"); dm.className = "cdim";
    dm.textContent = c.w + "\\u00d7" + c.h + " \\u00b7 " + c.ratio.toFixed(2) + ":1";
    h.appendChild(n); h.appendChild(dm); box.appendChild(h);
    box.appendChild(shot(c, false));
    var bs = document.createElement("div"); bs.className = "btns";
    ["keep","cut"].forEach(function(k){
      var b = document.createElement("button");
      b.setAttribute("data-v", k);
      b.setAttribute("aria-pressed", String(v.verdict === k));
      b.textContent = k;
      b.addEventListener("click", function(){
        S.v[c.id] = S.v[c.id] || {};
        S.v[c.id].verdict = (S.v[c.id].verdict === k) ? "" : k;
        delete S.r[tier];            // the pool changed, so any ranking is stale
        save(); render();
      });
      bs.appendChild(b);
    });
    var m = document.createElement("button");
    m.setAttribute("data-m","1");
    m.setAttribute("aria-pressed", String(!!v.flip));
    m.textContent = v.flip ? "mirrored \\u21c4" : "mirror \\u21c4";
    m.addEventListener("click", function(){
      S.v[c.id] = S.v[c.id] || {};
      S.v[c.id].flip = !S.v[c.id].flip;
      save(); render();
    });
    bs.appendChild(m);
    box.appendChild(bs);
    host.appendChild(box);
  });
  return host;
}

/* ---------- pass 2 : bracket ---------- */
function freshRank(ids){
  return {runs: ids.map(function(x){ return [x]; }), cur: null, n: 0, order: null};
}
function rankState(){
  var ids = kept(tier);
  var r = S.r[tier];
  // A saved sort is only valid for the exact set it was started on. The pool
  // under a bench can change -- a tier gets regenerated, hulls get swapped in --
  // and a stored run still naming a hull that is gone crashes the duel on
  // byId() returning null. Compare the sets and start over when they differ.
  if (r) {
    var seen = {}, n = 0;
    (r.order || []).concat(r.runs ? [].concat.apply([], r.runs) : [])
      .concat(r.cur ? r.cur.a.concat(r.cur.b, r.cur.out) : [])
      .forEach(function(id){ if (!seen[id]) { seen[id] = 1; n++; } });
    var ok = (n === ids.length) && ids.every(function(id){ return seen[id]; });
    if (!ok) { r = null; delete S.r[tier]; }
  }
  if (!r) { r = S.r[tier] = freshRank(ids); }
  return r;
}
function nextPair(r){
  for (;;) {
    if (!r.cur) {
      if (r.runs.length === 0) { r.order = []; return null; }
      if (r.runs.length === 1) { r.order = r.runs[0].slice(); return null; }
      r.cur = {a: r.runs.shift(), b: r.runs.shift(), out: [], i: 0, j: 0};
    }
    var c = r.cur;
    if (c.i < c.a.length && c.j < c.b.length) return [c.a[c.i], c.b[c.j]];
    while (c.i < c.a.length) c.out.push(c.a[c.i++]);
    while (c.j < c.b.length) c.out.push(c.b[c.j++]);
    r.runs.push(c.out); r.cur = null;
  }
}
function estimate(n){
  if (n < 2) return 0;
  return Math.max(1, Math.round(n * Math.log(n) / Math.LN2 - n + 1));
}
function choose(side){
  var r = rankState();
  hist.push(JSON.stringify({runs: r.runs, cur: r.cur, n: r.n}));
  if (hist.length > 200) hist.shift();
  var c = r.cur;
  if (side === "a") c.out.push(c.a[c.i++]); else c.out.push(c.b[c.j++]);
  r.n++;
  save(); render();
}
function drawRank(){
  var ids = kept(tier);
  if (ids.length < 2) {
    var e = document.createElement("p"); e.className = "empty";
    e.textContent = ids.length
      ? "Only one hull kept in this tier. Keep at least two to rank."
      : "Nothing kept in this tier yet. Do pass 1 first.";
    return e;
  }
  var r = rankState();
  var pair = nextPair(r);
  save();
  if (!pair) return drawOrder(r.order);

  var host = document.createElement("div");
  var duel = document.createElement("div"); duel.className = "duel";
  // auto-fit rather than a hard 1fr 1fr: at 3x a heavy is nearly a thousand
  // pixels wide, and two of those side by side would crop both.
  var dw = Math.max(byId(pair[0]).w, byId(pair[1]).w) * zoom + 44;
  duel.style.gridTemplateColumns = "repeat(auto-fit,minmax(" + dw + "px,1fr))";
  [["a", pair[0]], ["b", pair[1]]].forEach(function(p){
    var c = byId(p[1]);
    var b = document.createElement("button"); b.className = "pick"; b.type = "button";
    var hd = document.createElement("div"); hd.className = "chead";
    var nm = document.createElement("span"); nm.className = "cname"; nm.textContent = c.id;
    var dm = document.createElement("span"); dm.className = "cdim";
    dm.textContent = c.w + "\\u00d7" + c.h;
    hd.appendChild(nm); hd.appendChild(dm);
    b.appendChild(hd); b.appendChild(shot(c, true));
    b.addEventListener("click", function(){ choose(p[0]); });
    duel.appendChild(b);
  });
  host.appendChild(duel);

  var est = estimate(ids.length);
  var bar = document.createElement("div"); bar.className = "progress";
  var fill = document.createElement("i");
  fill.style.width = Math.min(100, Math.round(100 * r.n / est)) + "%";
  bar.appendChild(fill); host.appendChild(bar);
  var meta = document.createElement("div"); meta.className = "pmeta";
  meta.textContent = r.n + " of about " + est + " comparisons \\u00b7 "
    + ids.length + " hulls in this tier";
  host.appendChild(meta);
  var hint = document.createElement("p"); hint.className = "hint";
  hint.innerHTML = "Click the one that reads as <b>further along</b> \\u2014 more equipment, "
    + "more armour, more ship. Press <kbd>\\u2190</kbd> or <kbd>\\u2192</kbd> to pick.";
  host.appendChild(hint);
  return host;
}
function drawOrder(order){
  var host = document.createElement("div");
  var p = document.createElement("p"); p.className = "blurb";
  p.innerHTML = "<b>Ranked, most advanced first.</b> The top four are your S, A, B and C.";
  host.appendChild(p);
  var list = document.createElement("div"); list.className = "ranked";
  order.forEach(function(id, i){
    var c = byId(id);
    var row = document.createElement("div"); row.className = "row";
    var rk = document.createElement("span"); rk.className = "rank"; rk.textContent = (i+1);
    var tp = document.createElement("span"); tp.className = "tierpill";
    tp.textContent = ["S","A","B","C"][i] || c.id;
    row.appendChild(rk);
    if (i < 4) row.appendChild(tp);
    row.appendChild(shot(c, false));
    var dm = document.createElement("span"); dm.className = "cdim";
    dm.textContent = c.id + " \\u00b7 " + c.w + "\\u00d7" + c.h;
    row.appendChild(dm);
    list.appendChild(row);
  });
  host.appendChild(list);
  return host;
}

/* ---------- chrome ---------- */
function counted(){
  var set = inTier(tier), k=0, x=0, n=0;
  set.forEach(function(c){
    var v = (S.v[c.id]||{}).verdict;
    if (v === "keep") k++; else if (v === "cut") x++; else n++;
  });
  if (pass === 1) return "keep " + k + " \\u00b7 cut " + x + " \\u00b7 unjudged " + n;
  var r = S.r[tier];
  return (r && r.order) ? "ranked " + r.order.length : k + " to rank";
}
function render(){
  document.getElementById("blurb").innerHTML = pass === 1
    ? "One question per hull: does it belong in the Korvan line. <b>Mirror</b> flips one that faces the wrong way."
    : "Two at a time: which is <b>more advanced</b>?";
  var stage = document.getElementById("stage");
  stage.innerHTML = "";
  stage.appendChild(pass === 1 ? drawCull() : drawRank());
  document.getElementById("cnt").textContent = counted();
  document.getElementById("p1").setAttribute("aria-pressed", String(pass === 1));
  document.getElementById("p2").setAttribute("aria-pressed", String(pass === 2));
  document.getElementById("undo").hidden = !(pass === 2 && hist.length);
  document.getElementById("reset").hidden = (pass !== 2);
  [].forEach.call(document.getElementById("tierseg").children, function(b){
    b.setAttribute("aria-pressed", String(b.getAttribute("data-t") === tier));
  });
  [].forEach.call(document.getElementById("zoomseg").children, function(b){
    b.setAttribute("aria-pressed", String(+b.getAttribute("data-z") === zoom));
  });
}
[1,2,3].forEach(function(k){
  var b = document.createElement("button");
  b.setAttribute("data-z", String(k));
  b.textContent = k + "\\u00d7";
  b.addEventListener("click", function(){ zoom = k; save(); render(); });
  document.getElementById("zoomseg").appendChild(b);
});
TIERS.forEach(function(t){
  var b = document.createElement("button");
  b.setAttribute("data-t", t);
  b.textContent = t + " " + inTier(t).length;
  b.addEventListener("click", function(){ tier = t; hist = []; render(); });
  document.getElementById("tierseg").appendChild(b);
});
document.getElementById("p1").addEventListener("click", function(){ pass = 1; render(); });
document.getElementById("p2").addEventListener("click", function(){ pass = 2; render(); });
document.getElementById("undo").addEventListener("click", function(){
  var snap = hist.pop(); if (!snap) return;
  var s = JSON.parse(snap);
  var r = S.r[tier]; r.runs = s.runs; r.cur = s.cur; r.n = s.n; r.order = null;
  save(); render();
});
document.getElementById("reset").addEventListener("click", function(){
  delete S.r[tier]; hist = []; save(); render();
});
document.addEventListener("keydown", function(e){
  if (pass !== 2) return;
  var picks = document.querySelectorAll(".pick");
  if (picks.length !== 2) return;
  if (e.key === "ArrowLeft") { picks[0].click(); e.preventDefault(); }
  if (e.key === "ArrowRight") { picks[1].click(); e.preventDefault(); }
});
document.getElementById("copy").addEventListener("click", function(){
  var btn = this;
  var out = {hulls: CAND.map(function(c){
      var v = S.v[c.id] || {};
      return {id: c.id, tier: c.tier, w: c.w, h: c.h,
              verdict: v.verdict || "", flip: !!v.flip};
    }), ranked: {}};
  TIERS.forEach(function(t){
    var r = S.r[t];
    out.ranked[t] = (r && r.order) ? r.order : [];
  });
  var txt = JSON.stringify(out, null, 1);
  navigator.clipboard.writeText(txt).then(function(){
    btn.textContent = "Copied";
    setTimeout(function(){ btn.textContent = "Copy results"; }, 1600);
  }, function(){
    var ta = document.createElement("textarea");
    ta.value = txt; document.body.appendChild(ta); ta.select();
    btn.textContent = "Press Ctrl+C";
  });
});
render();
</script>
'''


def main():
	pool = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, "tools", "out", "pool")
	out = sys.argv[2] if len(sys.argv) > 2 else OUT
	key = sys.argv[3] if len(sys.argv) > 3 else "tk_fleet_bench_v1"
	title = sys.argv[4] if len(sys.argv) > 4 else "Korvan Fleet Bench"
	stand = sys.argv[5] if len(sys.argv) > 5 else "Every candidate, by group."
	tiers = groups(pool)
	cand = candidates(pool, tiers)
	n = len(cand)
	per = n // max(1, len(tiers)) if n else 0
	est = max(1, int(round(per * (per and __import__("math").log(per, 2)) - per + 1))) if per > 1 else 0
	page = (PAGE.replace("@@KEY@@", key)
		.replace("@@TITLE@@", title)
		.replace("@@STAND@@", stand)
		.replace("@@N@@", str(n))
		.replace("@@CMP@@", str(est))
		.replace("@@TIERS@@", json.dumps(tiers))
		.replace("@@CAND@@", json.dumps(cand)))
	os.makedirs(os.path.dirname(out), exist_ok=True)
	io.open(out, "w", encoding="utf-8", newline="\n").write(page)
	print("wrote %s  (%d hulls from %s, %.0f KB, key %s)"
		% (out, n, pool, len(page) / 1024.0, key))


if __name__ == "__main__":
	main()
