# -*- coding: utf-8 -*-
"""The hull culling bench: two passes over a batch of generated sprites.

    python tools/hull_bench.py <folder> [--pass2]

PASS 1 is a cull. One question per sprite: **does this come out of the same yard
as the three that already exist?** Keep or cut, nothing else. The reference
hulls sit pinned at the top of the page so the comparison is never from memory.

PASS 2 ranks the survivors C -> B -> A -> S. Only what survived pass 1 appears,
and the four reference hulls for that weight sit alongside as the anchor for
what each tier already looks like.

Verdicts live in the browser and export as JSON. Two passes rather than one
because they are different questions and mixing them makes both worse: "is this
Korvan" is absolute, "is this more advanced than that one" is relative, and a
person asked both at once will answer neither well.
"""
import base64
import io
import json
import os
import struct
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HULLS = os.path.join(ROOT, "tkg", "art", "sprites", "hulls", "korvan")
OUT = os.path.join(ROOT, "tools", "out", "hull-bench.html")
TIERS = ["c", "b", "a", "s"]


def png(path):
	with open(path, "rb") as f:
		b = f.read()
	w, h = struct.unpack(">II", b[16:24])
	return {"src": "data:image/png;base64," + base64.b64encode(b).decode("ascii"),
		"w": w, "h": h, "name": os.path.basename(path)}


def refs():
	"""The twelve that exist, as the thing every candidate is judged against."""
	out = {}
	for weight in ["light", "medium", "heavy"]:
		row = []
		for t in TIERS:
			p = os.path.join(HULLS, "hull_%s_%s.png" % (weight, t))
			if os.path.exists(p):
				d = png(p)
				d["tier"] = t.upper()
				row.append(d)
		out[weight] = row
	return out


def candidates(folder):
	out = []
	if not os.path.isdir(folder):
		return out
	for n in sorted(os.listdir(folder)):
		if not n.lower().endswith(".png"):
			continue
		d = png(os.path.join(folder, n))
		low = n.lower()
		d["weight"] = ("heavy" if "heavy" in low else
			"medium" if "medium" in low else
			"light" if "light" in low else "unsorted")
		d["id"] = os.path.splitext(n)[0]
		out.append(d)
	return out


PAGE = u'''<title>Hull Bench</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Instrument+Serif&family=IBM+Plex+Mono:wght@400;500&family=Silkscreen&display=swap">
<style>
:root{--void:#070a10;--sunk:#0a0e16;--plate:#111823;--line:#1b2430;--line2:#2a3648;
 --ice:#cbd6e3;--cold:#8b9bb0;--dim:#5f6f85;--flare:#d99b29;--hot:#ffd28a;
 --good:#7fb89a;--bad:#c05046;
 --serif:"Instrument Serif",Georgia,serif;
 --mono:"IBM Plex Mono",ui-monospace,Consolas,monospace;
 --pix:"Silkscreen",var(--mono);}
*{box-sizing:border-box}
body{margin:0;background:var(--void);color:var(--ice);font-family:var(--mono);
 font-size:14px;line-height:1.55}
.wrap{max-width:1180px;margin:0 auto;padding:0 20px 90px}
header{padding:48px 0 0}
.eyebrow{font-family:var(--pix);font-size:10px;letter-spacing:.16em;color:var(--flare);
 text-transform:uppercase;margin-bottom:16px}
h1{font-family:var(--serif);font-weight:400;font-size:clamp(38px,7vw,64px);line-height:1;
 margin:0 0 14px;letter-spacing:-.015em}
.stand{max-width:64ch;color:var(--cold);margin:0 0 10px}
.stand b{color:var(--ice);font-weight:500}
.bar{position:sticky;top:0;z-index:20;background:var(--void);
 border-bottom:1px solid var(--line2);padding:11px 0;margin:20px 0 0;
 display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.count{font-family:var(--pix);font-size:10px;letter-spacing:.1em;color:var(--dim);
 text-transform:uppercase}
.seg{display:flex;border:1px solid var(--line2)}
.seg button{font-family:var(--pix);font-size:9px;letter-spacing:.1em;
 text-transform:uppercase;background:transparent;color:var(--dim);border:0;
 padding:8px 12px;cursor:pointer}
.seg button+button{border-left:1px solid var(--line2)}
.seg button[aria-pressed="true"]{background:var(--flare);color:#0c0a06}
.copy{margin-left:auto;font-family:var(--pix);font-size:10px;letter-spacing:.12em;
 text-transform:uppercase;background:var(--ice);color:#0a0e16;border:0;
 padding:9px 15px;cursor:pointer}
.copy:hover{background:#fff}
button:focus-visible{outline:2px solid var(--hot);outline-offset:2px}

/* the reference strip, pinned so nothing is judged from memory */
.refs{position:sticky;top:47px;z-index:15;background:var(--sunk);
 border:1px solid var(--line2);padding:11px 14px;margin:14px 0 0}
.refh{font-family:var(--pix);font-size:9px;letter-spacing:.12em;color:var(--flare);
 text-transform:uppercase;margin-bottom:9px}
.refrow{display:flex;gap:16px;align-items:flex-end;flex-wrap:wrap}
.ref{text-align:center}
.ref img{display:block;image-rendering:pixelated;background:#0d1520;
 border:1px solid var(--line)}
.ref span{font-family:var(--pix);font-size:8px;letter-spacing:.1em;color:var(--dim);
 display:block;margin-top:4px}

.grid{display:grid;gap:14px;margin:18px 0 0}
.cand{background:var(--sunk);border:1px solid var(--line2);padding:12px 14px}
.cand[data-v="keep"]{border-left:3px solid var(--good)}
.cand[data-v="cut"]{border-left:3px solid var(--bad);opacity:.4}
.cand[data-t]{border-left:3px solid var(--flare)}
.chead{display:flex;gap:10px;align-items:baseline;margin-bottom:9px}
.cname{font-family:var(--pix);font-size:9px;letter-spacing:.1em;color:var(--cold)}
.cdim{font-family:var(--pix);font-size:8px;letter-spacing:.08em;color:var(--dim);
 margin-left:auto}
.shot{background:#0d1520;border:1px solid var(--line);padding:8px;
 display:flex;justify-content:center;align-items:center;min-height:110px}
.shot img{image-rendering:pixelated;display:block}
.btns{display:flex;gap:7px;margin-top:10px;flex-wrap:wrap}
.btns button{font-family:var(--pix);font-size:9px;letter-spacing:.1em;
 text-transform:uppercase;background:transparent;border:1px solid var(--line2);
 color:var(--dim);padding:7px 13px;cursor:pointer;flex:1}
.btns button[aria-pressed="true"][data-v="keep"]{background:var(--good);color:#06120c;border-color:var(--good)}
.btns button[aria-pressed="true"][data-v="cut"]{background:var(--bad);color:#160707;border-color:var(--bad)}
.btns button[aria-pressed="true"][data-t]{background:var(--flare);color:#0c0a06;border-color:var(--flare)}
.note{width:100%;margin-top:8px;background:var(--plate);border:1px solid var(--line2);
 color:var(--ice);font-family:var(--mono);font-size:12px;padding:6px 9px}
.empty{color:var(--dim);padding:40px 0;text-align:center}
footer{margin:40px 0 0;border-top:1px solid var(--line2);padding-top:18px;color:var(--dim);
 font-size:12.5px;max-width:74ch}
@media(prefers-reduced-motion:reduce){*{transition:none!important}}
</style>
<div class="wrap">
<header>
 <div class="eyebrow">Three Kelvin &middot; Korvan hulls &middot; @@N@@ candidates</div>
 <h1>Hull Bench</h1>
 <p class="stand" id="blurb"></p>
</header>
<div class="bar">
 <span class="count" id="cnt"></span>
 <div class="seg" role="group" aria-label="Pass">
  <button id="p1" aria-pressed="true">Pass 1 &mdash; cull</button>
  <button id="p2" aria-pressed="false">Pass 2 &mdash; rank</button>
 </div>
 <div class="seg" role="group" aria-label="Weight">
  <button data-w="all" aria-pressed="true">All</button>
  <button data-w="light" aria-pressed="false">Light</button>
  <button data-w="medium" aria-pressed="false">Medium</button>
  <button data-w="heavy" aria-pressed="false">Heavy</button>
 </div>
 <div class="seg" role="group" aria-label="Zoom">
  <button data-z="1" aria-pressed="true">1&times;</button>
  <button data-z="2" aria-pressed="false">2&times;</button>
 </div>
 <button class="copy" id="copy">Copy verdicts</button>
</div>
<div class="refs">
 <div class="refh" id="refh">What already exists &mdash; judge against these, not from memory</div>
 <div class="refrow" id="refrow"></div>
</div>
<div class="grid" id="grid"></div>
<footer>
 <p>Pass 1 asks one thing: <b>does this come out of the same yard.</b> Pass 2
 ranks what survived, C to S, and a tier is accumulation rather than redesign
 &mdash; if a C and an S do not read as the same yard's work, the pair has failed
 however good either looks alone.</p>
 <p>Verdicts are kept in this browser. Copy verdicts puts JSON on the clipboard:
 id, verdict, tier, note.</p>
</footer>
</div>
<script>
const CAND = @@CAND@@, REFS = @@REFS@@;
const KEY = "tk_hull_bench_v1";
let V = {};
try { V = JSON.parse(localStorage.getItem(KEY) || "{}"); } catch (e) { V = {}; }
let pass = 1, weight = "all", zoom = 1;
function save(){ try { localStorage.setItem(KEY, JSON.stringify(V)); } catch(e){} }

function shown(){
  return CAND.filter(function(c){
    if (weight !== "all" && c.weight !== weight) return false;
    if (pass === 2) return (V[c.id] || {}).verdict === "keep";
    return true;
  });
}
function counted(){
  var k = 0, x = 0, n = 0, t = 0;
  CAND.forEach(function(c){
    var v = V[c.id] || {};
    if (v.verdict === "keep") k++; else if (v.verdict === "cut") x++; else n++;
    if (v.tier) t++;
  });
  return pass === 1
    ? "keep " + k + " \\u00b7 cut " + x + " \\u00b7 unjudged " + n
    : "ranked " + t + " of " + k + " kept";
}
function drawRefs(){
  var host = document.getElementById("refrow");
  host.textContent = "";
  var ws = weight === "all" ? ["light","medium","heavy"] : [weight];
  ws.forEach(function(w){
    (REFS[w] || []).forEach(function(r){
      var d = document.createElement("div"); d.className = "ref";
      var i = document.createElement("img");
      i.src = r.src; i.width = r.w * zoom; i.height = r.h * zoom;
      i.alt = w + " " + r.tier;
      var s = document.createElement("span");
      s.textContent = w.slice(0,1).toUpperCase() + " \\u00b7 " + r.tier;
      d.appendChild(i); d.appendChild(s); host.appendChild(d);
    });
  });
}
function render(){
  document.getElementById("blurb").textContent = pass === 1
    ? "One question per sprite: does this come out of the same yard as the ones pinned above? Keep or cut. Nothing else is being asked yet."
    : "Now rank what survived, C to S. A tier is the same ship further along \\u2014 not a different ship.";
  drawRefs();
  var host = document.getElementById("grid");
  host.textContent = "";
  var list = shown();
  if (!list.length) {
    var e = document.createElement("div"); e.className = "empty";
    e.textContent = pass === 2
      ? "Nothing kept yet. Do pass 1 first."
      : "No sprites in this folder yet.";
    host.appendChild(e);
  }
  list.forEach(function(c){
    var v = V[c.id] || {};
    var box = document.createElement("div"); box.className = "cand";
    if (pass === 1 && v.verdict) box.setAttribute("data-v", v.verdict);
    if (pass === 2 && v.tier) box.setAttribute("data-t", v.tier);
    var h = document.createElement("div"); h.className = "chead";
    var n = document.createElement("span"); n.className = "cname"; n.textContent = c.id;
    var dm = document.createElement("span"); dm.className = "cdim";
    dm.textContent = c.w + " \\u00d7 " + c.h + " \\u00b7 " + c.weight;
    h.appendChild(n); h.appendChild(dm); box.appendChild(h);
    var sh = document.createElement("div"); sh.className = "shot";
    var im = document.createElement("img");
    im.src = c.src; im.width = c.w * zoom; im.height = c.h * zoom; im.alt = c.id;
    sh.appendChild(im); box.appendChild(sh);
    var bs = document.createElement("div"); bs.className = "btns";
    if (pass === 1) {
      ["keep","cut"].forEach(function(k){
        var b = document.createElement("button");
        b.setAttribute("data-v", k);
        b.setAttribute("aria-pressed", String(v.verdict === k));
        b.textContent = k;
        b.addEventListener("click", function(){
          V[c.id] = V[c.id] || {};
          V[c.id].verdict = (V[c.id].verdict === k) ? "" : k;
          save(); render();
        });
        bs.appendChild(b);
      });
    } else {
      ["C","B","A","S"].forEach(function(t){
        var b = document.createElement("button");
        b.setAttribute("data-t", t);
        b.setAttribute("aria-pressed", String(v.tier === t));
        b.textContent = t;
        b.addEventListener("click", function(){
          V[c.id] = V[c.id] || {};
          V[c.id].tier = (V[c.id].tier === t) ? "" : t;
          save(); render();
        });
        bs.appendChild(b);
      });
    }
    box.appendChild(bs);
    var note = document.createElement("input");
    note.className = "note"; note.type = "text";
    note.placeholder = "what is wrong with it, in your words";
    note.value = v.note || "";
    note.addEventListener("input", function(){
      V[c.id] = V[c.id] || {}; V[c.id].note = note.value; save();
      document.getElementById("cnt").textContent = counted();
    });
    box.appendChild(note);
    host.appendChild(box);
  });
  document.getElementById("cnt").textContent = counted();
  document.getElementById("p1").setAttribute("aria-pressed", String(pass === 1));
  document.getElementById("p2").setAttribute("aria-pressed", String(pass === 2));
}
document.getElementById("p1").addEventListener("click", function(){ pass = 1; render(); });
document.getElementById("p2").addEventListener("click", function(){ pass = 2; render(); });
document.querySelectorAll('[data-w]').forEach(function(b){
  b.addEventListener("click", function(){
    weight = b.getAttribute("data-w");
    document.querySelectorAll('[data-w]').forEach(function(o){
      o.setAttribute("aria-pressed", String(o === b)); });
    render();
  });
});
document.querySelectorAll('[data-z]').forEach(function(b){
  b.addEventListener("click", function(){
    zoom = parseInt(b.getAttribute("data-z"), 10);
    document.querySelectorAll('[data-z]').forEach(function(o){
      o.setAttribute("aria-pressed", String(o === b)); });
    render();
  });
});
document.getElementById("copy").addEventListener("click", function(){
  var out = CAND.filter(function(c){ return V[c.id]; }).map(function(c){
    return {id: c.id, weight: c.weight, verdict: (V[c.id]||{}).verdict || "",
            tier: (V[c.id]||{}).tier || "", note: (V[c.id]||{}).note || ""};
  });
  var txt = JSON.stringify(out, null, 1);
  var btn = document.getElementById("copy");
  navigator.clipboard.writeText(txt).then(function(){
    btn.textContent = "Copied " + out.length;
    setTimeout(function(){ btn.textContent = "Copy verdicts"; }, 1600);
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
	folder = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
		ROOT, "tools", "out", "hull_candidates")
	cand = candidates(folder)
	page = (PAGE.replace("@@N@@", str(len(cand)))
		.replace("@@CAND@@", json.dumps(cand))
		.replace("@@REFS@@", json.dumps(refs())))
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	io.open(OUT, "w", encoding="utf-8", newline="\n").write(page)
	print("wrote %s  (%d candidates from %s, %.0f KB)"
		% (OUT, len(cand), folder, len(page) / 1024.0))
	if not cand:
		print("  nothing there yet -- the twelve reference hulls still load, so "
			"the page is worth opening to check the layout")


if __name__ == "__main__":
	main()
