//! THE YARD MANIFEST: every part and card in the game, on one page.
//!
//!     godot --headless --path tkg -- content json
//!     node tkg/tools/manifest.mjs [out.html]
//!
//! Then publish the HTML as an artifact. See docs/catalogue.md for the rules the
//! page is used to check, and for why it is generated rather than written.
//!
//! GENERATED, NEVER TYPED. The whole point of this file is that the catalogue is
//! read out of `-- content json` — a hand-copied catalogue is wrong the day after
//! it is copied, and the two duplicates that survived longest were only ever
//! visible because a page put them next to each other. A page that has drifted
//! from the game is worse than no page: it costs a review that finds problems
//! which are already fixed, which is exactly what happened once.
//!
//! It also runs the duplicate check itself, over the export, rather than quoting
//! holdtest's verdict. Two independent implementations of one rule disagreeing is
//! information; a page repeating what the test said is not.
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';

const NL = String.fromCharCode(10);

// Where Godot writes `user://`. One platform each, because the alternative is a
// dependency for four lines of string joining.
function exportPath() {
	const app = 'Three Kelvin';
	if (process.platform === 'win32') {
		return path.join(process.env.APPDATA || '', 'Godot', 'app_userdata', app, 'modules.json');
	}
	if (process.platform === 'darwin') {
		return path.join(os.homedir(), 'Library', 'Application Support', 'Godot',
			'app_userdata', app, 'modules.json');
	}
	return path.join(os.homedir(), '.local', 'share', 'godot', 'app_userdata', app, 'modules.json');
}

const SRC = process.env.MANIFEST_JSON || exportPath();
if (!fs.existsSync(SRC)) {
	console.error('no export at ' + SRC);
	console.error('run:  godot --headless --path tkg -- content json');
	process.exit(1);
}
const OUT = process.argv[2] || 'parts-manifest.html';
const D = JSON.parse(fs.readFileSync(SRC, 'utf8'));
const MODS = D.modules, JUNK = D.malfunctions;

const HOUSE_ORDER = ['Korvan Heavy Works','Solari Foundry','The Probate Combine',
  'Redline Shipyards','Cygnet Dynamics','Verity Ateliers','Calyx Biosystems','Unbranded'];
const SHORT = {'Korvan Heavy Works':'Korvan','Solari Foundry':'Solari',
  'The Probate Combine':'Probate','Redline Shipyards':'Redline',
  'Cygnet Dynamics':'Cygnet','Verity Ateliers':'Verity',
  'Calyx Biosystems':'Calyx','Unbranded':'Unbranded'};
const TARGET = {'Korvan Heavy Works':40,'Unbranded':20,'Solari Foundry':40,
  'The Probate Combine':40,'Redline Shipyards':40,'Cygnet Dynamics':40,
  'Verity Ateliers':40,'Calyx Biosystems':40};
const RAR = ['Common','Uncommon','Rare','Epic','Legendary','Exotic','Artifact','Contraband'];
const esc = s => String(s).replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
const slug = s => String(s).toLowerCase().replace(/[^a-z0-9]+/g,'-');

// ---- the audit, run over the real export rather than asserted ----
// Two cards are the same card when they PRINT the same words for the same
// price. That is the player's definition, and it is the one that caught
// Bolt On / Brace by eye.
const byEffect = new Map(), byName = new Map();
for (const m of MODS) {
  for (const c of m.cards) {
    const sig = c.energy + 'e/' + c.heat + 'h ' + c.text;
    if (!byEffect.has(sig)) byEffect.set(sig, new Set());
    byEffect.get(sig).add(c.name);
    if (!byName.has(c.name)) byName.set(c.name, new Set());
    byName.get(c.name).add(sig);
  }
}
const twins = [...byEffect].filter(([, n]) => n.size > 1)
  .map(([sig, n]) => ({sig, names: [...n].sort()}));
const forks = [...byName].filter(([, s]) => s.size > 1)
  .map(([n, s]) => ({name: n, sigs: [...s].sort()}));

// Every unique card, once, with who hands it over.
const CARDS = [];
{
  const seen = new Map();
  for (const m of MODS) for (const c of m.cards) {
    const k = c.name + '|' + c.text + '|' + c.energy + '|' + c.heat;
    if (!seen.has(k)) {
      const e = {name: c.name, text: c.text, energy: c.energy, heat: c.heat,
        rarities: new Set(), houses: new Set(), parts: new Set()};
      seen.set(k, e); CARDS.push(e);
    }
    const e = seen.get(k);
    e.rarities.add(c.rarity || '—');
    e.houses.add(m.house_name); e.parts.add(m.name);
  }
}
CARDS.sort((a, b) => a.text.localeCompare(b.text) || a.name.localeCompare(b.name));
const SHARED = CARDS.filter(c => c.parts.size > 1);

// ---- per-house tallies ----
// A card counts ONCE, toward the first house that uses it, walking the parts in
// the game's own order. Counting it in every house that grants it would inflate
// the totals by the eight shared cards and make this page disagree with what
// `-- content` prints, which is the one thing a page generated from the export
// must never do.
const owner = new Map();
for (const m of MODS) for (const c of m.cards) {
  if (!owner.has(c.name)) owner.set(c.name, m.house_name);
}
const houses = HOUSE_ORDER.map(h => {
  const parts = MODS.filter(m => m.house_name === h);
  const names = new Set();
  for (const m of parts) for (const c of m.cards) {
    if (owner.get(c.name) === h) names.add(c.name);
  }
  const pairs = parts.filter(m => new Set(m.cards.map(c => c.name)).size === 1
    && m.cards.length > 1).length;
  return {name: h, short: SHORT[h], parts, cards: names.size, want: TARGET[h], pairs};
});
const totalCards = new Set(MODS.flatMap(m => m.cards.map(c => c.name))).size;
const shortfall = houses.reduce((n, h) => n + Math.max(0, h.want - h.cards), 0);

// ---- rendering ----
function plate(m) {
  const cells = [];
  for (let i = 0; i < m.w * m.h; i++) cells.push('<i></i>');
  return '<div class="plate r-' + slug(m.rarity) + '" style="grid-template-columns:repeat('
    + m.w + ',var(--cell))" aria-label="' + m.w + ' by ' + m.h + '">' + cells.join('') + '</div>';
}
function cardLine(c) {
  const r = c.rarity
    ? '<span class="cr r-' + slug(c.rarity) + '">' + esc(c.rarity.slice(0, 2)) + '</span>'
    : '<span class="cr"></span>';
  const cost = '<span class="cost">' + c.energy + (c.heat ? '<b>+' + c.heat + '</b>' : '') + '</span>';
  return '<li>' + r + cost + '<span class="cn">' + esc(c.name) + '</span>'
    + '<span class="ct">' + esc(c.text) + '</span></li>';
}
function partCard(m) {
  const dupe = new Set(m.cards.map(c => c.name)).size === 1 && m.cards.length > 1;
  return '<article class="part" data-house="' + esc(m.house_name) + '" data-rarity="'
    + esc(m.rarity) + '" data-slot="' + esc(m.slot) + '">'
    + '<header>' + plate(m)
    + '<div class="ph"><h3>' + esc(m.name) + '</h3>'
    + '<p class="meta"><span class="r-' + slug(m.rarity) + '">' + esc(m.rarity.toUpperCase())
    + '</span> &middot; ' + esc(m.slot.toUpperCase()) + ' &middot; ' + m.w + '&times;' + m.h
    + ' &middot; ' + m.cells + (m.cells === 1 ? ' cell' : ' cells')
    + (dupe ? ' &middot; <span class="pair">pair</span>' : '') + '</p></div></header>'
    + (m.flavour ? '<p class="flav">' + esc(m.flavour) + '</p>' : '')
    + '<ul class="cards">' + m.cards.map(cardLine).join('') + '</ul>'
    + '</article>';
}

const houseSections = houses.map(h =>
  '<section class="house" data-house="' + esc(h.name) + '">'
  + '<h2><span class="swatch m-' + slug(h.short) + '"></span>'
  + esc(h.name.toUpperCase()) + '<span class="hcount">' + h.parts.length + ' parts &middot; '
  + h.cards + ' cards' + (h.cards < h.want ? ' &middot; <em>' + (h.want - h.cards)
  + ' short of ' + h.want + '</em>' : '') + '</span></h2>'
  + '<div class="grid">' + h.parts.map(partCard).join('') + '</div></section>').join(NL);

const cardRows = CARDS.map(c =>
  '<tr>'
  + '<td class="c-name">' + esc(c.name)
  + (c.parts.size > 1 ? '<span class="tag">' + c.parts.size + ' parts</span>' : '') + '</td>'
  + '<td class="c-cost">' + c.energy + (c.heat ? ' <b>+' + c.heat + '</b>' : '') + '</td>'
  + '<td class="c-text">' + esc(c.text) + '</td>'
  + '<td class="c-rar">' + [...c.rarities].map(r =>
      '<span class="r-' + slug(r) + '">' + esc(r) + '</span>').join(' / ') + '</td>'
  + '<td class="c-from">' + esc([...c.parts].join(', ')) + '</td></tr>').join(NL);

const junkRows = JUNK.map(j =>
  '<tr><td class="c-name">' + esc(j.name) + '</td>'
  + '<td class="c-text">' + esc(j.text) + '</td>'
  + '<td class="c-kw">'
  + (j.corrode ? '<span class="kw corrode">Corrode ' + j.corrode + '</span>' : '')
  + (j.smoulder ? '<span class="kw smoulder">Smoulder ' + j.smoulder + '</span>' : '')
  + (j.fused ? '<span class="kw fused">Fused</span>' : '')
  + (!j.corrode && !j.smoulder && !j.fused ? '<span class="kw dead">inert</span>' : '')
  + '</td></tr>').join(NL);

const auditVerdict = (twins.length === 0 && forks.length === 0)
  ? '<p class="verdict pass"><b>Clean.</b> No two names share one effect, and no two '
    + 'effects share one name — checked across all ' + CARDS.length
    + ' cards the catalogue can hand you, by comparing what each one prints and costs.</p>'
  : '<p class="verdict fail"><b>' + (twins.length + forks.length) + ' collisions.</b></p>'
    + '<ul class="collisions">'
    + twins.map(t => '<li>' + esc(t.names.join(' = ')) + ' <span class="ct">all do '
        + esc(t.sig) + '</span></li>').join('')
    + forks.map(f => '<li>' + esc(f.name) + ' <span class="ct">is '
        + f.sigs.length + ' different cards</span></li>').join('')
    + '</ul>';

const sharedRows = SHARED.slice().sort((a, b) => b.parts.size - a.parts.size).map(c =>
  '<tr><td class="c-name">' + esc(c.name) + '</td><td class="c-text">' + esc(c.text)
  + '</td><td class="c-cnt">' + c.parts.size + '</td>'
  + '<td class="c-from">' + esc([...c.parts].join(', ')) + '</td></tr>').join(NL);

const tally = houses.map(h =>
  '<tr><td><span class="swatch m-' + slug(h.short) + '"></span>' + esc(h.short) + '</td>'
  + '<td class="n">' + h.parts.length + '</td>'
  + '<td class="n">' + h.cards + '</td>'
  + '<td class="n">' + h.want + '</td>'
  + '<td class="n ' + (h.cards >= h.want ? 'done' : 'gap') + '">'
  + (h.cards >= h.want ? '—' : (h.want - h.cards)) + '</td>'
  + '<td class="bar"><span style="width:' + Math.round(100 * Math.min(1, h.cards / h.want))
  + '%"></span></td></tr>').join(NL);

const CSS = [
':root{',
'  --void:#0b1017; --panel:#141c26; --panel-2:#101720; --line:#243244;',
'  --ice:#c3d2e2; --chill:#8195aa; --cold:#61738a; --ember:#d97b2e;',
'  --common:#98a0a8; --uncommon:#4fbf82; --rare:#6a9ad4; --epic:#8b4fd4;',
'  --legendary:#d99b29; --exotic:#e05fa8; --artifact:#e0402e;',
'  --contraband:#05070a; --contraband-ink:#b9b3a6;',
'  --korvan:#8ea6c0; --solari:#d98c3a; --probate:#7f8fa8; --redline:#c9584a;',
'  --cygnet:#5fb2c4; --verity:#c9b06a; --calyx:#7fbf7a; --unbranded:#6d7f95;',
'  --cell:11px;',
'}',
'*{box-sizing:border-box}',
'html{scroll-behavior:smooth}',
'body{background:var(--void);color:var(--ice);',
'  font-family:"IBM Plex Sans",system-ui,sans-serif;font-size:15px;line-height:1.55;',
'  margin:0;padding:clamp(20px,4vw,52px) clamp(14px,4vw,36px) 96px}',
'.wrap{max-width:1160px;margin:0 auto}',
'h1{font-family:Oxanium,system-ui,sans-serif;font-weight:700;',
'  font-size:clamp(30px,5vw,46px);letter-spacing:.01em;line-height:1.02;',
'  margin:0 0 4px;text-wrap:balance}',
'.sub{font-family:"IBM Plex Mono",monospace;font-size:11.5px;letter-spacing:.16em;',
'  text-transform:uppercase;color:var(--cold);margin:0 0 26px}',
'h2{font-family:Oxanium,system-ui,sans-serif;font-weight:700;font-size:15px;',
'  letter-spacing:.13em;text-transform:uppercase;margin:42px 0 12px;',
'  display:flex;align-items:center;gap:9px;flex-wrap:wrap;',
'  border-bottom:1px solid var(--line);padding-bottom:8px}',
'.hcount{font-family:"IBM Plex Mono",monospace;font-size:11px;letter-spacing:.06em;',
'  text-transform:none;color:var(--cold);font-weight:400;margin-left:auto}',
'.hcount em{color:var(--ember);font-style:normal}',
'h3{font-family:Oxanium,system-ui,sans-serif;font-weight:700;font-size:14.5px;',
'  margin:0;letter-spacing:.01em;line-height:1.2}',
'.tiles{display:grid;grid-template-columns:repeat(auto-fit,minmax(112px,1fr));',
'  gap:8px;margin:0 0 22px}',
'.tile{background:var(--panel-2);border:1px solid var(--line);padding:10px 12px}',
'.tile b{display:block;font-family:Oxanium,sans-serif;font-size:24px;line-height:1.1}',
'.tile span{font-family:"IBM Plex Mono",monospace;font-size:10px;letter-spacing:.11em;',
'  text-transform:uppercase;color:var(--cold)}',
'.tile.warn b{color:var(--ember)}',
'.verdict{background:var(--panel-2);border-left:3px solid var(--uncommon);',
'  padding:12px 15px;margin:0 0 10px;font-size:14px}',
'.verdict.fail{border-left-color:var(--artifact)}',
'.verdict b{font-family:Oxanium,sans-serif;letter-spacing:.02em}',
'.collisions{margin:0 0 18px;padding-left:18px;font-family:"IBM Plex Mono",monospace;',
'  font-size:12.5px}',
'.filters{display:flex;flex-wrap:wrap;gap:14px;margin:0 0 8px;',
'  padding:11px 13px;background:var(--panel-2);border:1px solid var(--line)}',
'.set{display:flex;flex-wrap:wrap;align-items:center;gap:5px}',
'.lbl{font-family:"IBM Plex Mono",monospace;font-size:10px;letter-spacing:.13em;',
'  text-transform:uppercase;color:var(--cold);margin-right:3px}',
'button{font-family:"IBM Plex Mono",monospace;font-size:11.5px;background:transparent;',
'  color:var(--chill);border:1px solid var(--line);padding:3px 9px;cursor:pointer;',
'  letter-spacing:.03em}',
'button:hover{color:var(--ice);border-color:var(--cold)}',
'button[data-on]{background:var(--ice);color:var(--void);border-color:var(--ice)}',
'button:focus-visible{outline:2px solid var(--ember);outline-offset:2px}',
'.showing{font-family:"IBM Plex Mono",monospace;font-size:11px;color:var(--cold);',
'  letter-spacing:.06em;margin:0 0 20px}',
'.showing b{color:var(--ice)}',
'.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(292px,1fr));gap:9px}',
'.part{background:var(--panel);border:1px solid var(--line);padding:11px 12px 10px;',
'  display:flex;flex-direction:column;gap:7px}',
'.part header{display:flex;gap:11px;align-items:flex-start}',
'.ph{min-width:0;flex:1}',
'.meta{font-family:"IBM Plex Mono",monospace;font-size:10px;letter-spacing:.05em;',
'  color:var(--cold);margin:3px 0 0}',
'.pair{color:var(--ember)}',
'.flav{font-size:12.5px;color:var(--chill);font-style:italic;margin:0;line-height:1.45}',
'.plate{display:grid;gap:1px;flex:0 0 auto;padding:2px;border:1px solid currentColor;',
'  align-self:flex-start;margin-top:2px}',
'.plate i{width:var(--cell);height:var(--cell);background:currentColor;opacity:.34;display:block}',
'ul.cards{list-style:none;margin:0;padding:7px 0 0;border-top:1px solid var(--line);',
'  display:flex;flex-direction:column;gap:5px}',
'ul.cards li{display:grid;grid-template-columns:22px 26px 1fr;gap:6px;',
'  align-items:baseline;font-size:12.5px}',
'.cr{font-family:"IBM Plex Mono",monospace;font-size:9px;letter-spacing:.05em;',
'  text-transform:uppercase;text-align:center;border:1px solid currentColor;line-height:1.6}',
'.cost{font-family:"IBM Plex Mono",monospace;font-size:11px;color:var(--cold);text-align:right}',
'.cost b{color:var(--ember);font-weight:500}',
'.cn{font-weight:500;grid-column:3}',
'.ct{color:var(--chill);font-size:12px;grid-column:3;margin-top:-3px}',
'.scroll{overflow-x:auto;border:1px solid var(--line);background:var(--panel-2)}',
'table{border-collapse:collapse;width:100%;font-size:13px;font-variant-numeric:tabular-nums}',
'th{font-family:"IBM Plex Mono",monospace;font-size:10px;letter-spacing:.12em;',
'  text-transform:uppercase;color:var(--cold);text-align:left;font-weight:400;',
'  padding:9px 11px;border-bottom:1px solid var(--line);white-space:nowrap}',
'td{padding:7px 11px;border-bottom:1px solid rgba(36,50,68,.5);vertical-align:top}',
'tr:last-child td{border-bottom:none}',
'tbody tr:hover{background:rgba(255,255,255,.025)}',
'.c-name{font-weight:500;white-space:nowrap}',
'.c-cost,.c-cnt,.n{font-family:"IBM Plex Mono",monospace;text-align:right;',
'  color:var(--chill);white-space:nowrap}',
'.c-cost b{color:var(--ember);font-weight:500}',
'.c-text{color:var(--chill)}',
'.c-from,.c-rar{font-family:"IBM Plex Mono",monospace;font-size:11px;color:var(--cold)}',
'.n.gap{color:var(--ember)}',
'.n.done{color:var(--uncommon)}',
'.bar{width:120px;min-width:90px}',
'.bar span{display:block;height:5px;background:var(--cold)}',
'.tag{font-family:"IBM Plex Mono",monospace;font-size:9.5px;letter-spacing:.08em;',
'  text-transform:uppercase;border:1px solid var(--line);padding:0 4px;margin-left:7px;',
'  color:var(--cold)}',
'.kw{font-family:"IBM Plex Mono",monospace;font-size:10px;letter-spacing:.07em;',
'  text-transform:uppercase;border:1px solid currentColor;padding:1px 5px;margin-right:5px;',
'  white-space:nowrap}',
'.kw.corrode{color:var(--artifact)}',
'.kw.smoulder{color:var(--legendary)}',
'.kw.fused{color:var(--epic)}',
'.kw.dead{color:var(--cold)}',
'.note{background:var(--panel-2);border-left:2px solid var(--line);padding:10px 14px;',
'  margin:0 0 10px;font-size:13.5px;color:var(--chill);max-width:78ch}',
'.note b{color:var(--ice)}',
'.note code{font-family:"IBM Plex Mono",monospace;font-size:12px;color:var(--ice)}',
'.swatch{width:4px;height:14px;display:inline-block;flex:0 0 auto}',
'.m-korvan{background:var(--korvan)} .m-solari{background:var(--solari)}',
'.m-probate{background:var(--probate)} .m-redline{background:var(--redline)}',
'.m-cygnet{background:var(--cygnet)} .m-verity{background:var(--verity)}',
'.m-calyx{background:var(--calyx)} .m-unbranded{background:var(--unbranded)}',
'.r-common{color:var(--common)} .r-uncommon{color:var(--uncommon)}',
'.r-rare{color:var(--rare)} .r-epic{color:var(--epic)}',
'.r-legendary{color:var(--legendary)} .r-exotic{color:var(--exotic)}',
'.r-artifact{color:var(--artifact)} .r-contraband{color:var(--contraband-ink)}',
'.ladder{display:flex;flex-wrap:wrap;gap:7px;margin:0 0 10px}',
'.rung{border:1px solid currentColor;padding:5px 11px;font-family:"IBM Plex Mono",monospace;',
'  font-size:11px;letter-spacing:.09em;text-transform:uppercase}',
'.rung.contra{background:var(--contraband);color:var(--contraband-ink)}',
'.hide{display:none!important}',
'@media (prefers-reduced-motion:reduce){html{scroll-behavior:auto}}'
].join(NL);

const JS = [
'(function(){',
'  var f={house:"all",rarity:"all",slot:"all"};',
'  var parts=[].slice.call(document.querySelectorAll(".part"));',
'  var shown=document.getElementById("shown");',
'  function apply(){',
'    var n=0;',
'    parts.forEach(function(p){',
'      var ok=(f.house==="all"||p.dataset.house===f.house)',
'        &&(f.rarity==="all"||p.dataset.rarity===f.rarity)',
'        &&(f.slot==="all"||p.dataset.slot===f.slot);',
'      p.classList.toggle("hide",!ok); if(ok)n++;',
'    });',
'    document.querySelectorAll(".house").forEach(function(s){',
'      s.classList.toggle("hide",!s.querySelector(".part:not(.hide)"));',
'    });',
'    shown.textContent=n;',
'  }',
'  document.querySelectorAll(".filters .set").forEach(function(set){',
'    set.addEventListener("click",function(e){',
'      var b=e.target.closest("button"); if(!b)return;',
'      set.querySelectorAll("button").forEach(function(x){x.removeAttribute("data-on")});',
'      b.setAttribute("data-on","1");',
'      f[set.dataset.k]=b.dataset.v; apply();',
'    });',
'  });',
'  apply();',
'})();'
].join(NL);

const HTML = [
'<title>Yard Manifest</title>',
'<link rel="preconnect" href="https://fonts.googleapis.com">',
'<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>',
'<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Oxanium:wght@500;700&family=IBM+Plex+Mono:wght@400;500&family=IBM+Plex+Sans:wght@400;500&display=swap">',
'<style>' + CSS + '</style>',
'<div class="wrap">',
'<h1>Yard Manifest</h1>',
'<p class="sub">Every part in Three Kelvin &middot; exported from the game, not retyped</p>',

'<div class="tiles">',
'<div class="tile"><b>' + MODS.length + '</b><span>parts</span></div>',
'<div class="tile"><b>' + totalCards + '</b><span>unique cards</span></div>',
'<div class="tile"><b>' + JUNK.length + '</b><span>malfunctions</span></div>',
'<div class="tile"><b>' + SHARED.length + '</b><span>shared cards</span></div>',
'<div class="tile warn"><b>' + shortfall + '</b><span>still to write</span></div>',
'</div>',

'<h2>The duplicate check</h2>',
auditVerdict,
'<p class="note">Four duplicates were found by <b>reading a list</b>: Bolt On was Brace, '
+ 'Sight In was Load was Lay the Guns, Range Finding was Range, and a card called Hold Fast '
+ 'sat beside a different card called Hold Fast. This page runs the same comparison the game '
+ 'now runs in <code>-- holdtest</code> — two cards are the same card when they print the '
+ 'same words for the same price — so the list checks itself instead of waiting to be read.</p>',

'<h2>The grade ladder</h2>',
'<div class="ladder">' + RAR.map(function(r){
  return '<span class="rung r-' + slug(r) + (r === 'Contraband' ? ' contra' : '') + '">'
    + r + '</span>';
}).join('') + '</div>',
'<p class="note"><b>Exotic is pink and Artifact is red</b> — the only warm hues on the '
+ 'ladder, so its top separates from its middle before a word is read. Exotic used to be a '
+ 'teal sitting two steps from Rare’s blue.</p>',
'<p class="note"><b>Contraband is black, and has no parts yet.</b> It is the one grade that '
+ 'is a fact about who sold you the thing rather than how well it was made, and it comes only '
+ 'from the Probate Combine, Redline and Cygnet — the scrappers, the hackers and the '
+ 'technologists, the three houses with a reason to move something off the manifest. Black is '
+ 'darker than the screen it is drawn on, so a contraband plate has no visible ground at all: '
+ 'only a bone edge, the shape of a part with nothing filled in.</p>',

'<h2>What each house owes</h2>',
'<div class="scroll"><table><thead><tr><th>House</th><th class="n">Parts</th>'
+ '<th class="n">Cards</th><th class="n">Want</th><th class="n">Short</th><th>Progress</th>'
+ '</tr></thead><tbody>' + tally + '</tbody></table></div>',

'<h2>Every part</h2>',
'<div class="filters">',
'<div class="set" data-k="house"><span class="lbl">House</span>'
+ '<button data-v="all" data-on="1">All</button>'
+ houses.map(function(h){
    return '<button data-v="' + esc(h.name) + '">' + esc(h.short) + '</button>';
  }).join('') + '</div>',
'<div class="set" data-k="rarity"><span class="lbl">Grade</span>'
+ '<button data-v="all" data-on="1">All</button>'
+ RAR.slice(0, 7).map(function(r){
    return '<button data-v="' + r + '">' + r + '</button>';
  }).join('') + '</div>',
'<div class="set" data-k="slot"><span class="lbl">Slot</span>'
+ '<button data-v="all" data-on="1">All</button>'
+ ['weapon','system','utility'].map(function(s){
    return '<button data-v="' + s + '">' + s.charAt(0).toUpperCase() + s.slice(1) + '</button>';
  }).join('') + '</div></div>',
'<p class="showing"><b id="shown">' + MODS.length + '</b> of ' + MODS.length
+ ' showing &middot; the plate is the part’s real footprint in the hold</p>',
houseSections,

'<h2>Every card, sorted by what it does</h2>',
'<p class="note">Sorted by <b>effect</b>, not by name — so two cards that do the same '
+ 'thing sit next to each other instead of eleven screens apart, which is the only reason the '
+ 'earlier duplicates were ever visible at all. Cost is energy, with heat after it in orange.</p>',
'<div class="scroll"><table><thead><tr><th>Card</th><th class="n">Cost</th><th>Effect</th>'
+ '<th>Grade</th><th>Granted by</th></tr></thead><tbody>' + cardRows + '</tbody></table></div>',

'<h2>Cards more than one part hands you</h2>',
'<p class="note">A shared vocabulary is the point — it is what lets a part be a '
+ '<b>combination</b> rather than a verb with a name on it. These are deliberate. The '
+ 'duplicates above were not.</p>',
'<div class="scroll"><table><thead><tr><th>Card</th><th>Effect</th><th class="n">Parts</th>'
+ '<th>Granted by</th></tr></thead><tbody>' + sharedRows + '</tbody></table></div>',

'<h2>Malfunctions</h2>',
'<p class="note">Not modules — that was a bug once. They arrive unasked, cost a hand '
+ 'slot, and charge you at the <b>end of your turn</b>, which makes them a question rather '
+ 'than a tax: you are holding something that will cost you, and you have a turn to find a '
+ 'way to throw it away.</p>',
'<div class="scroll"><table><thead><tr><th>Malfunction</th><th>Effect</th><th>Keywords</th>'
+ '</tr></thead><tbody>' + junkRows + '</tbody></table></div>',
'</div>',
'<script>' + JS + '</scr' + 'ipt>'
].join(NL);

fs.writeFileSync(OUT, HTML, 'utf8');
console.log('wrote ' + OUT + ' (' + HTML.length + ' bytes) from ' + SRC);
console.log('twins', twins.length, '| forks', forks.length, '| unique cards', CARDS.length,
  '| shared', SHARED.length, '| shortfall', shortfall);
