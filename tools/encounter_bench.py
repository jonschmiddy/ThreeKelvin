# -*- coding: utf-8 -*-
"""Every encounter on one page, with a verdict button on each.

    python tools/encounter_bench.py            -> tools/out/encounter-bench.html

Triage the table in one sitting instead of one encounter per round trip: KEEP,
REWRITE or CUT each, type a note, then Copy verdicts and paste the JSON back.
Verdicts survive a reload (localStorage), so it does not have to be one sitting.

Whatever `encounter_lint.py` already found is printed ON the card, because a
fault a machine can name is not worth a person's attention -- the page exists
for the half that is judgement.
"""
import io
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tkg", "scripts", "systems", "OptionTable.gd")
OUT = os.path.join(ROOT, "tools", "out", "encounter-bench.html")

PAY = [0, 1.0, 1.8, 3.0, 4.7, 7.2]
TOLL = [0, 1.0, 1.9, 3.0, 4.3, 5.8]
TIERS = ["", "EASY", "ROUGH", "HARD", "BRUTAL", "LETHAL"]
TAGCOL = {"signal": "#9b8ec8", "contract": "#9b8ec8", "salvage": "#b3a488",
	"hazard": "#f2761d", "fight": "#c05046", "quest": "#e0b83c"}


def tier(d):
	return max(1, min(5, (d + 1) // 2))


def ledger(chunk, t):
	out = []
	for m in re.finditer(r"Run\.add_credits\(OptionTable\.purse\((\d+)\)", chunk):
		out.append(["gain", "credits", "+%d" % round(int(m.group(1)) * PAY[t])])
	for m in re.finditer(r"Run\.add_credits\(-(\d+)\)", chunk):
		out.append(["cost", "credits", u"−" + m.group(1)])
	for m in re.finditer(r"OptionTable\.toll\((\d+)\)", chunk):
		out.append(["cost", "hull", u"−%d" % round(int(m.group(1)) * TOLL[t])])
	for m in re.finditer(r"heat \+= (\d+)", chunk):
		out.append(["heat", "heat", "+" + m.group(1)])
	for m in re.finditer(r"Run\.fuel = maxi\(0, Run\.fuel - (\d+)\)", chunk):
		out.append(["cost", "fuel", u"−" + m.group(1)])
	for m in re.finditer(r"Run\.fuel \+= (\d+)", chunk):
		out.append(["gain", "fuel", "+" + m.group(1)])
	for m in re.finditer(r'material_id = &"([a-z_]+)"', chunk):
		out.append(["item", m.group(1).replace("_", " "), "named"])
	for m in re.finditer(r'material = &"([a-z]+)"', chunk):
		out.append(["item", m.group(1), "rolled"])
	if "module = true" in chunk:
		out.append(["item", "module", "rolled"])
	if "archive_recover = true" in chunk:
		out.append(["item", "archive", "found"])
	if "fight = true" in chunk:
		out.append(["cost", "a fight", "starts"])
	if "place = " in chunk:
		out.append(["item", "quest", "placed"])
	if "consume_material_tier" in chunk:
		out.append(["cost", "hold item", "TAKEN"])
	return out or [["none", "nothing moves", ""]]


def parse(src):
	lines = src.split("\n")
	st = [(m.group(1), n) for n, l in enumerate(lines)
		for m in [re.match(r'\t*id = &"([a-z_]+)",\s*$', l)] if m]
	recs = []
	for k, (eid, n) in enumerate(st):
		end = st[k + 1][1] if k + 1 < len(st) else len(lines)
		blk = "\n".join(lines[n:end])
		lo = re.search(r"min_danger = (\d+)", blk)
		hi = re.search(r"max_danger = (\d+)", blk)
		lo, hi = int(lo.group(1)) if lo else 1, int(hi.group(1)) if hi else 10
		t = tier(hi)
		bm = re.search(r'body = "(.*?)",\n', blk, re.S)
		gates = [g for g in ["needs_star", "needs_giant", "needs_pulsar",
			"needs_fauna", "needs_berth", "regions", "max_security", "placed"]
			if re.search(r"\b%s\b" % g, blk)]
		star = re.search(r"needs_star = MapGen\.Star\.([A-Z]+)", blk)
		if star:
			gates = [g for g in gates if g != "needs_star"] + [
				star.group(1).lower() + " star"]
		choices = []
		for m in re.finditer(r"\n\t{4}\{label = \"(.*?)\"", blk):
			nxt = blk.find('\n\t\t\t\t{label = ', m.end())
			chunk = blk[m.start():nxt if nxt > 0 else len(blk)]
			br = []
			for band in ["met", "clean", "partial", "botched"]:
				bm2 = re.search(
					r"\n\t{5}%s = func\(\) -> Dictionary:(.*?)"
					r"(?=\n\t{5}\w+ = func|\Z)" % band, chunk, re.S)
				if bm2:
					tx = re.search(r'text = "(.*?)"[,}]', bm2.group(1), re.S)
					br.append({"band": "success" if band == "met" else band,
						"text": tx.group(1) if tx else "",
						"led": ledger(bm2.group(1), t)})
			if not br:
				tx = re.search(r'text = "(.*?)"[,}]', chunk, re.S)
				br.append({"band": "outcome", "text": tx.group(1) if tx else "",
					"led": ledger(chunk, t)})
			ck = re.search(r'attr = &"([a-z_]+)", need = (\d+)', chunk)
			choices.append({"name": m.group(1),
				"check": "%s %s" % ck.groups() if ck else "",
				"stay": "stay = true" in chunk.split("func()")[0],
				"branches": br})
		recs.append({"id": eid, "line": n + 1,
			"title": re.search(r'title = "(.*?)"', blk).group(1),
			"body": bm.group(1) if bm else "",
			"tags": sorted(set(re.findall(
				r'&"(quest|fight|hazard|salvage|signal|contract)"', blk))),
			"band": "%s–%s" % (TIERS[tier(lo)], TIERS[t])
				if tier(lo) != t else TIERS[t],
			"tier": t, "gates": gates, "choices": choices})
	return recs


def lint():
	"""Whatever the linter already knows, keyed by encounter id."""
	try:
		r = subprocess.run([sys.executable,
			os.path.join(ROOT, "tools", "encounter_lint.py")],
			capture_output=True, text=True, encoding="utf-8")
	except Exception:
		return {}
	out, kind = {}, None
	for line in (r.stdout or "").split("\n"):
		if line.startswith("ERRORS"):
			kind = "error"
		elif line.startswith("REVIEW"):
			kind = "review"
		m = re.match(r"\s+OptionTable\.gd:\d+\s+(\S+)\s+(.*)", line)
		if m and kind:
			out.setdefault(m.group(1), []).append([kind, m.group(2).strip()])
	return out


PAGE = u'''<title>Encounter Bench</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Instrument+Serif&family=IBM+Plex+Mono:wght@400;500&family=Silkscreen&display=swap">
<style>
:root{--void:#070a10;--sunk:#0a0e16;--plate:#111823;--line:#1b2430;--line2:#2a3648;
 --ice:#cbd6e3;--cold:#8b9bb0;--dim:#5f6f85;--flare:#d99b29;--hot:#ffd28a;
 --good:#7fb89a;--warn:#d99b29;--bad:#c05046;
 --serif:"Instrument Serif",Georgia,serif;
 --mono:"IBM Plex Mono",ui-monospace,Consolas,monospace;
 --pix:"Silkscreen",var(--mono);}
*{box-sizing:border-box}
body{margin:0;background:var(--void);color:var(--ice);font-family:var(--mono);
 font-size:14px;line-height:1.55}
.wrap{max-width:1080px;margin:0 auto;padding:0 20px 90px}
header{padding:52px 0 0}
.eyebrow{font-family:var(--pix);font-size:10px;letter-spacing:.16em;color:var(--flare);
 text-transform:uppercase;margin-bottom:18px}
h1{font-family:var(--serif);font-weight:400;font-size:clamp(40px,7vw,68px);line-height:1;
 margin:0 0 14px;letter-spacing:-.015em}
.stand{max-width:64ch;color:var(--cold);margin:0 0 10px}
.stand b{color:var(--ice);font-weight:500}
.bar{position:sticky;top:0;z-index:9;background:var(--void);
 border-bottom:1px solid var(--line2);padding:12px 0;margin:22px 0 0;
 display:flex;gap:10px;align-items:center;flex-wrap:wrap}
.count{font-family:var(--pix);font-size:10px;letter-spacing:.1em;color:var(--dim);
 text-transform:uppercase}
.count b{color:var(--ice)}
.filters{display:flex;gap:0;border:1px solid var(--line2);flex-wrap:wrap}
.filters button{font-family:var(--pix);font-size:9px;letter-spacing:.1em;
 text-transform:uppercase;background:transparent;color:var(--dim);border:0;
 padding:8px 11px;cursor:pointer}
.filters button+button{border-left:1px solid var(--line2)}
.filters button[aria-pressed="true"]{background:var(--flare);color:#0c0a06}
.copy{margin-left:auto;font-family:var(--pix);font-size:10px;letter-spacing:.12em;
 text-transform:uppercase;background:var(--ice);color:#0a0e16;border:0;
 padding:10px 16px;cursor:pointer}
.copy:hover{background:#fff}
button:focus-visible{outline:2px solid var(--hot);outline-offset:2px}
.enc{margin:22px 0 0;background:var(--sunk);border:1px solid var(--line2)}
.enc[data-v="keep"]{border-left:3px solid var(--good)}
.enc[data-v="rewrite"]{border-left:3px solid var(--warn)}
.enc[data-v="cut"]{border-left:3px solid var(--bad);opacity:.55}
.eh{display:flex;gap:12px;align-items:baseline;padding:15px 17px 0;flex-wrap:wrap}
.et{font-family:var(--serif);font-size:26px;margin:0}
.eid{font-family:var(--pix);font-size:9px;letter-spacing:.1em;color:var(--dim)}
.chips{margin-left:auto;display:flex;gap:5px;flex-wrap:wrap}
.chip{font-family:var(--pix);font-size:8px;letter-spacing:.08em;text-transform:uppercase;
 border:1px solid var(--line2);color:var(--dim);padding:3px 7px}
.chip.t5{color:var(--bad);border-color:var(--bad)}
.chip.t4{color:var(--warn);border-color:var(--warn)}
.eb{padding:11px 17px 13px;color:var(--ice);max-width:80ch}
.lint{margin:0 17px 13px;border-left:2px solid var(--bad);padding:2px 0 2px 12px}
.lint div{font-size:12px;color:var(--cold);margin:2px 0}
.lint b{font-family:var(--pix);font-size:8px;letter-spacing:.1em;margin-right:7px}
.lint b.e{color:var(--bad)} .lint b.r{color:var(--warn)}
.ch{margin:0 17px 9px;border:1px solid var(--line)}
.chh{display:flex;gap:10px;align-items:center;padding:8px 11px;background:var(--plate);
 font-size:13px}
.chh .nm{flex:1}
.chh .mt{font-family:var(--pix);font-size:8px;letter-spacing:.08em;color:var(--cold);
 text-transform:uppercase}
.chh .mt.stay{color:var(--good)}
.br{display:grid;grid-template-columns:66px 1fr 150px;gap:12px;padding:9px 11px;
 border-top:1px solid var(--line);font-size:13px}
.bn{font-family:var(--pix);font-size:8px;letter-spacing:.1em;text-transform:uppercase;
 padding-top:3px}
.bn.success,.bn.clean{color:var(--good)} .bn.partial{color:var(--warn)}
.bn.botched{color:var(--bad)} .bn.outcome{color:var(--cold)}
.bt{color:var(--ice);line-height:1.58}
.lg{display:grid;gap:2px;align-content:start}
.lg div{font-family:var(--pix);font-size:8px;letter-spacing:.06em;text-transform:uppercase;
 display:flex;justify-content:space-between;gap:6px;border-bottom:1px solid var(--line);
 padding-bottom:2px}
.lg span:last-child{font-family:var(--mono);font-size:11px;letter-spacing:0}
.lg .gain span:last-child{color:var(--good)} .lg .cost span:last-child{color:var(--bad)}
.lg .heat span:last-child{color:var(--warn)} .lg .item span:last-child{color:#9b8ec8}
.lg .none{color:var(--dim);border:0}
.verdict{display:flex;gap:8px;align-items:center;padding:11px 17px 15px;flex-wrap:wrap}
.verdict button{font-family:var(--pix);font-size:9px;letter-spacing:.1em;
 text-transform:uppercase;background:transparent;border:1px solid var(--line2);
 color:var(--dim);padding:8px 14px;cursor:pointer}
.verdict button[aria-pressed="true"][data-v="keep"]{background:var(--good);color:#06120c;border-color:var(--good)}
.verdict button[aria-pressed="true"][data-v="rewrite"]{background:var(--warn);color:#140d02;border-color:var(--warn)}
.verdict button[aria-pressed="true"][data-v="cut"]{background:var(--bad);color:#160707;border-color:var(--bad)}
.verdict input{flex:1;min-width:220px;background:var(--plate);border:1px solid var(--line2);
 color:var(--ice);font-family:var(--mono);font-size:13px;padding:8px 10px}
.verdict input:focus-visible{outline:2px solid var(--hot);outline-offset:-1px}
footer{margin:44px 0 0;border-top:1px solid var(--line2);padding-top:18px;color:var(--dim);
 font-size:12.5px;max-width:74ch}
@media(max-width:760px){.br{grid-template-columns:1fr;gap:7px}}
@media(prefers-reduced-motion:reduce){*{transition:none!important}}
</style>
<div class="wrap">
<header>
 <div class="eyebrow">Three Kelvin &middot; @@N@@ encounters &middot; triage</div>
 <h1>Encounter Bench</h1>
 <p class="stand">Every encounter in the table, with what each branch actually
 does beside what it says. Mark each <b>KEEP</b>, <b>REWRITE</b> or <b>CUT</b>,
 add a note, then <b>Copy verdicts</b> and paste the JSON back.</p>
 <p class="stand">Anything the linter already found is printed on the card in
 red. Those get fixed regardless &mdash; they are rulings, not taste, and they
 are not what your eyes are for. <b>Judge the writing.</b></p>
</header>
<div class="bar">
 <span class="count" id="cnt"></span>
 <div class="filters" role="group" aria-label="Filter">
  <button data-f="all" aria-pressed="true">All</button>
  <button data-f="todo" aria-pressed="false">Unjudged</button>
  <button data-f="lint" aria-pressed="false">Has findings</button>
  <button data-f="5" aria-pressed="false">Lethal</button>
  <button data-f="4" aria-pressed="false">Brutal</button>
  <button data-f="3" aria-pressed="false">Hard</button>
  <button data-f="2" aria-pressed="false">Rough</button>
  <button data-f="1" aria-pressed="false">Easy</button>
 </div>
 <button class="copy" id="copy">Copy verdicts</button>
</div>
<div id="list"></div>
<footer>
 <p>Verdicts live in this browser, so you can stop and come back. Copy verdicts
 puts a JSON array on the clipboard &mdash; id, verdict, note. Paste it into the
 session and it becomes the work list.</p>
</footer>
</div>
<script>
const ENC = @@ENC@@, LINT = @@LINT@@;
const KEY = "tk_encounter_bench_v1";
let V = {};
try { V = JSON.parse(localStorage.getItem(KEY) || "{}"); } catch (e) { V = {}; }
let filter = "all";
function save(){ try { localStorage.setItem(KEY, JSON.stringify(V)); } catch(e){} }
function shown(e){
  const v = V[e.id];
  if (filter === "all") return true;
  if (filter === "todo") return !v || !v.verdict;
  if (filter === "lint") return (LINT[e.id] || []).length > 0;
  return String(e.tier) === filter;
}
function counted(){
  let k = 0, r = 0, c = 0, n = 0;
  ENC.forEach(e => { const v = (V[e.id] || {}).verdict;
    if (v === "keep") k++; else if (v === "rewrite") r++; else if (v === "cut") c++; else n++; });
  return "keep " + k + " \\u00b7 rewrite " + r + " \\u00b7 cut " + c + " \\u00b7 unjudged " + n;
}
function render(){
  const host = document.getElementById("list");
  host.textContent = "";
  ENC.filter(shown).forEach(e => {
    const v = V[e.id] || {};
    const box = document.createElement("section");
    box.className = "enc";
    if (v.verdict) box.setAttribute("data-v", v.verdict);
    const h = document.createElement("div"); h.className = "eh";
    const t = document.createElement("h2"); t.className = "et"; t.textContent = e.title;
    const i = document.createElement("span"); i.className = "eid";
    i.textContent = e.id + " \\u00b7 line " + e.line;
    const ch = document.createElement("div"); ch.className = "chips";
    [e.band].concat(e.tags).concat(e.gates).forEach(c => {
      const s = document.createElement("span");
      s.className = "chip" + (c === "LETHAL" ? " t5" : c === "BRUTAL" ? " t4" : "");
      s.textContent = c; ch.appendChild(s);
    });
    h.appendChild(t); h.appendChild(i); h.appendChild(ch); box.appendChild(h);
    const b = document.createElement("p"); b.className = "eb"; b.textContent = e.body;
    box.appendChild(b);
    const found = LINT[e.id] || [];
    if (found.length) {
      const L = document.createElement("div"); L.className = "lint";
      found.forEach(pair => {
        const d = document.createElement("div");
        const tag = document.createElement("b");
        tag.className = pair[0] === "error" ? "e" : "r";
        tag.textContent = pair[0] === "error" ? "ruling" : "review";
        d.appendChild(tag); d.appendChild(document.createTextNode(pair[1]));
        L.appendChild(d);
      });
      box.appendChild(L);
    }
    e.choices.forEach(c => {
      const C = document.createElement("div"); C.className = "ch";
      const hh = document.createElement("div"); hh.className = "chh";
      const nm = document.createElement("span"); nm.className = "nm"; nm.textContent = c.name;
      hh.appendChild(nm);
      if (c.stay) { const s = document.createElement("span"); s.className = "mt stay";
        s.textContent = "walk-away"; hh.appendChild(s); }
      const mt = document.createElement("span"); mt.className = "mt";
      mt.textContent = c.check || "no check"; hh.appendChild(mt);
      C.appendChild(hh);
      c.branches.forEach(br => {
        const r = document.createElement("div"); r.className = "br";
        const n2 = document.createElement("div"); n2.className = "bn " + br.band;
        n2.textContent = br.band;
        const tx = document.createElement("div"); tx.className = "bt"; tx.textContent = br.text;
        const lg = document.createElement("div"); lg.className = "lg";
        br.led.forEach(tri => {
          const d = document.createElement("div"); d.className = tri[0];
          const a = document.createElement("span"); a.textContent = tri[1];
          const z = document.createElement("span"); z.textContent = tri[2];
          d.appendChild(a); d.appendChild(z); lg.appendChild(d);
        });
        r.appendChild(n2); r.appendChild(tx); r.appendChild(lg); C.appendChild(r);
      });
      box.appendChild(C);
    });
    const vr = document.createElement("div"); vr.className = "verdict";
    ["keep", "rewrite", "cut"].forEach(k => {
      const btn = document.createElement("button");
      btn.setAttribute("data-v", k);
      btn.setAttribute("aria-pressed", String(v.verdict === k));
      btn.textContent = k;
      btn.addEventListener("click", () => {
        V[e.id] = V[e.id] || {};
        V[e.id].verdict = (V[e.id].verdict === k) ? "" : k;
        save(); render();
      });
      vr.appendChild(btn);
    });
    const note = document.createElement("input");
    note.type = "text";
    note.placeholder = "what is wrong with it, in your words";
    note.value = v.note || "";
    note.addEventListener("input", () => {
      V[e.id] = V[e.id] || {}; V[e.id].note = note.value; save();
      document.getElementById("cnt").textContent = counted();
    });
    vr.appendChild(note);
    box.appendChild(vr);
    host.appendChild(box);
  });
  document.getElementById("cnt").textContent = counted();
}
document.querySelectorAll(".filters button").forEach(b => {
  b.addEventListener("click", () => {
    filter = b.getAttribute("data-f");
    document.querySelectorAll(".filters button").forEach(o =>
      o.setAttribute("aria-pressed", String(o === b)));
    render();
  });
});
document.getElementById("copy").addEventListener("click", () => {
  const out = ENC.filter(e => (V[e.id] || {}).verdict || (V[e.id] || {}).note)
    .map(e => ({id: e.id, verdict: (V[e.id] || {}).verdict || "",
                note: (V[e.id] || {}).note || ""}));
  const txt = JSON.stringify(out, null, 1);
  const btn = document.getElementById("copy");
  navigator.clipboard.writeText(txt).then(function(){
    btn.textContent = "Copied " + out.length;
    setTimeout(function(){ btn.textContent = "Copy verdicts"; }, 1600);
  }, function(){
    const ta = document.createElement("textarea");
    ta.value = txt; document.body.appendChild(ta); ta.select();
    btn.textContent = "Press Ctrl+C";
  });
});
render();
</script>
'''


def main():
	recs = parse(io.open(SRC, encoding="utf-8").read())
	page = (PAGE.replace("@@N@@", str(len(recs)))
		.replace("@@ENC@@", json.dumps(recs, ensure_ascii=False))
		.replace("@@LINT@@", json.dumps(lint(), ensure_ascii=False)))
	os.makedirs(os.path.dirname(OUT), exist_ok=True)
	io.open(OUT, "w", encoding="utf-8", newline="\n").write(page)
	print("wrote %s  (%d encounters, %.0f KB)"
		% (OUT, len(recs), len(page) / 1024.0))


if __name__ == "__main__":
	main()
