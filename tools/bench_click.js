// Click the bench's controls the way a person does, and report what throws.
//
//   node tools/bench_click.js tools/out/room-bench.html <pixdir>
//
// WHY THIS EXISTS. `bench_probe.js` draws the page; it does not OPERATE it.
// Its DOM hands back a stub for every element, so a handler that would throw
// in a browser runs clean here, and it only ever draws the tab the page opens
// on. Three separate faults have now reached Jon looking identical -- the room
// stops repainting and a control stops responding -- because an exception in
// one frame aborts the rest of it. "Stuck on a layout" is what a thrown
// drawImage looks like from the outside.
//
// So this keeps real elements, real listeners and a real child tree, then
// clicks every tab and every button and says which one broke.
const fs = require('fs');
const path = require('path');

const page = fs.readFileSync(process.argv[2], 'utf8');
const PIXDIR = process.argv[3];
const META = JSON.parse(fs.readFileSync(path.join(PIXDIR, '_meta.json'), 'utf8'));

const STATION = path.join(__dirname, '..', 'tkg', 'art', 'sprites', 'station');

// A PNG's size is in its header, twenty-four bytes in. The page inlines some
// art as data: URIs and fetches the rest by path, and a harness that can only
// size one of those reports the other as a 404 -- which is a false alarm about
// exactly the fault being hunted.
function pngSize(buf) {
  if (buf.length < 24) return null;
  return [buf.readUInt32BE(16), buf.readUInt32BE(20)];
}

function pixels(src) {
  const s = String(src);
  if (s.startsWith('data:image')) {
    const b = Buffer.from(s.slice(s.indexOf(',') + 1), 'base64');
    const d = pngSize(b);
    return d ? { w: d[0], h: d[1] } : null;
  }
  const nm = s.split('/').pop().split('?')[0];
  if (META[nm]) return { w: META[nm][0], h: META[nm][1] };
  // Anything published beside the page lives in the station folder; sizing it
  // from disk is what a browser fetching it would see.
  const onDisk = path.join(STATION, nm);
  if (fs.existsSync(onDisk)) {
    const d = pngSize(fs.readFileSync(onDisk));
    if (d) return { w: d[0], h: d[1] };
  }
  return null;
}

// A picture the page asked for and did not get. Width 0 is exactly what a
// browser reports for a 404, and it is the state that made drawImage throw.
const MISSING = [];

function makeCanvas() {
  const g = {
    canvas: null, fillStyle: '', strokeStyle: '', globalAlpha: 1,
    imageSmoothingEnabled: false, lineWidth: 1,
    save() {}, restore() {}, translate() {}, scale() {}, setTransform() {},
    beginPath() {}, moveTo() {}, lineTo() {}, stroke() {}, rect() {}, clip() {},
    setLineDash() {}, fillRect() {}, strokeRect() {}, clearRect() {}, fill() {},
    createPattern() { return null; },
    drawImage(im) {
      // THE BEHAVIOUR THE STUB WAS MISSING. A browser throws here; the old
      // probe returned undefined and the bug walked straight past it.
      if (!im || im.width === 0 || im.height === 0) {
        const e = new Error('drawImage: source has no pixels (' +
          ((im && im._src) || 'unknown') + ')');
        e.name = 'InvalidStateError';
        throw e;
      }
    },
    // The rest of the 2D context the page touches. Missing one of these looks
    // exactly like a page bug, which is how the last two minutes went.
    fillText() {}, strokeText() {}, measureText(t) { return { width: String(t).length * 6 }; },
    arc() {}, closePath() {}, quadraticCurveTo() {}, bezierCurveTo() {},
    createLinearGradient() { return { addColorStop() {} }; },
    createRadialGradient() { return { addColorStop() {} }; },
    getImageData(x, y, w, h) {
      return { width: w, height: h, data: new Uint8ClampedArray(w * h * 4) };
    },
    putImageData() {},
  };
  const c = { width: 0, height: 0, getContext: () => g, style: {},
              addEventListener() {}, focus() {} };
  g.canvas = c;
  return c;
}

function makeEl(tag) {
  const el = {
    tagName: String(tag || 'div').toUpperCase(),
    children: [], style: {}, dataset: {}, className: '', id: '',
    _on: {}, value: '', textContent: '', _html: '', hidden: false,
    get innerHTML() { return this._html; },
    set innerHTML(v) { this._html = v; this.children = []; },
    addEventListener(k, fn) { (this._on[k] = this._on[k] || []).push(fn); },
    removeEventListener() {},
    appendChild(c) { this.children.push(c); return c; },
    removeChild(c) { this.children = this.children.filter((x) => x !== c); },
    remove() {},
    setAttribute(k, v) { if (k === 'id') this.id = v; },
    getAttribute() { return null; },
    // innerHTML creates real elements in a browser, and code that sets it then
    // reaches for those children is correct. Hand back a stub rather than
    // null, or the harness invents faults the page does not have.
    querySelector() { return makeEl('div'); },
    querySelectorAll() { return [makeEl('input'), makeEl('input')]; },
    contains() { return false; },
    focus() {}, click() { fire(this, 'click'); },
    getBoundingClientRect() { return { left: 0, top: 0, width: 740, height: 431 }; },
  };
  return el;
}

function fire(el, kind, ev) {
  const fns = (el._on && el._on[kind]) || [];
  for (const fn of fns) fn(ev || { currentTarget: el, target: el, preventDefault() {}, key: '' });
  if (kind === 'click' && typeof el.onclick === 'function') el.onclick({ currentTarget: el });
  if (kind === 'input' && typeof el.oninput === 'function') el.oninput({ currentTarget: el });
}

const REG = {};
const canvas = makeCanvas();

global.window = {
  addEventListener() {}, matchMedia: () => ({ matches: false }),
  requestAnimationFrame() { return 0; }, devicePixelRatio: 1,
  location: { href: '' },
};
global.requestAnimationFrame = () => 0;
global.localStorage = {
  _d: {}, getItem(k) { return this._d[k] || null; },
  setItem(k, v) { this._d[k] = String(v); }, removeItem(k) { delete this._d[k]; },
};
global.document = {
  getElementById(id) {
    if (id === 'cv') return canvas;
    if (!REG[id]) { REG[id] = makeEl('div'); REG[id].id = id; }
    return REG[id];
  },
  createElement(t) { return t === 'canvas' ? makeCanvas() : makeEl(t); },
  addEventListener() {}, body: makeEl('body'),
  querySelector() { return null; }, querySelectorAll() { return []; },
};
global.Image = class {
  constructor() { this.width = 0; this.height = 0; this._src = ''; }
  set src(v) {
    this._src = v;
    const p = pixels(v);
    if (p) { this.width = p.w; this.height = p.h; }
    else MISSING.push(v);
    // A browser fires these asynchronously; firing now is close enough and
    // makes the first draw see what a settled page would.
    if (p && this.onload) this.onload();
    if (!p && this.onerror) this.onerror();
  }
  get src() { return this._src; }
};
global.Blob = class {}; global.URL = { createObjectURL: () => '', revokeObjectURL() {} };
global.navigator = { clipboard: null };

const m = page.match(/<script>([\s\S]*?)<\/script>\s*<\/body>/);
const hook = ';globalThis.__P={draw:draw,ui:ui,state:state,L:L};';
try { new Function(m[1] + hook)(); } catch (e) {
  console.log('SCRIPT THREW ON LOAD: ' + e.message);
  console.log((e.stack || '').split('\n').slice(1, 4).join('\n'));
  process.exit(1);
}
const P = globalThis.__P;

console.log('pictures the page asked for and did not get: ' +
  (MISSING.length ? MISSING.length : 'none'));
for (const s of [...new Set(MISSING)].slice(0, 8)) console.log('    ' + s);

let broke = 0;
function attempt(what, fn) {
  try { fn(); return true; }
  catch (e) {
    broke++;
    console.log('  ' + what.padEnd(26) + 'THREW ' + e.name + ': ' + e.message);
    const at = (e.stack || '').split('\n')[1];
    if (at) console.log('      ' + at.trim().slice(0, 110));
    return false;
  }
}

console.log('');
attempt('first draw', () => P.draw());

const tabs = document.getElementById('tabs');
console.log('tabs built: ' + tabs.children.length);
tabs.children.forEach((b, i) => {
  attempt('click tab ' + i + ' (' + (b.textContent || '?') + ')', () => fire(b, 'click'));
});

console.log('');
console.log(broke ? (broke + ' control(s) throw') : 'every tab switches cleanly');
process.exit(broke ? 1 : 0);
