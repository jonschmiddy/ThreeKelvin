// Run the bench's real draw() against canvases that actually hold pixels, and
// report what it painted.
//
// WHY THIS EXISTS. `bench_check.js` runs the page against a stub whose
// `getImageData` returns undefined. Every routine that reads pixels -- the lit
// panels on a vending machine, the pilots on an opening, the backdrop's tone --
// is wrapped in try/catch and falls back to "nothing", so the check goes green
// on code that draws nothing at all. That is how "the vending machines still
// aren't lit" survived three builds: the gate could not see it.
//
//   node tools/bench_probe.js tools/out/room-bench.html <pixdir>
const fs = require('fs');
const path = require('path');

const page = fs.readFileSync(process.argv[2], 'utf8');
const PIXDIR = process.argv[3];
const META = JSON.parse(fs.readFileSync(path.join(PIXDIR, '_meta.json'), 'utf8'));

function pixels(src) {
  const nm = String(src).split('/').pop().split('?')[0];
  if (!META[nm]) return null;
  const [w, h] = META[nm];
  return { w, h, data: new Uint8ClampedArray(fs.readFileSync(path.join(PIXDIR, nm + '.rgba'))) };
}

// Every drawImage onto the main canvas is recorded, so the probe can say which
// pass painted what rather than guessing from the final image.
const PAINTED = [];
let PHASE = 'setup';

function makeCtx(surface) {
  return {
    imageSmoothingEnabled: true, globalAlpha: 1, globalCompositeOperation: 'source-over',
    fillStyle: '', strokeStyle: '', font: '', lineWidth: 1, textAlign: '', textBaseline: '',
    save() {}, restore() {}, translate() {}, scale() {}, setTransform() {}, rotate() {},
    beginPath() {}, moveTo() {}, lineTo() {}, arc() {}, closePath() {}, fill() {}, stroke() {},
    clip() {}, rect() {}, fillRect() {}, strokeRect() {}, clearRect() {}, fillText() {},
    setLineDash() {}, measureText() { return { width: 10 }; },
    createLinearGradient() { return { addColorStop() {} }; },
    drawImage(im) {
      const src = im && (im.src || im._src);
      if (surface === 'main') PAINTED.push({ phase: PHASE, src: String(src || '?') });
      if (surface !== 'main') this._owner._src = src;
    },
    getImageData(x, y, w, h) {
      const p = this._owner && this._owner._src ? pixels(this._owner._src) : null;
      if (p) return { width: p.w, height: p.h, data: new Uint8ClampedArray(p.data) };
      // the main canvas: a flat surface is enough for applyLight to run on
      return { width: w, height: h, data: new Uint8ClampedArray(w * h * 4).fill(128) };
    },
    putImageData(img) { if (this._owner) this._owner._img = img; },
  };
}

function makeCanvas(surface) {
  const c = { _w: 0, _h: 0, _src: null, _img: null, style: {}, dataset: {},
    classList: { add() {}, remove() {}, toggle() { return false; }, contains() { return false; } },
    appendChild() {}, removeChild() {}, addEventListener() {}, setAttribute() {},
    getAttribute() { return null; }, querySelector() { return makeCanvas('off'); },
    querySelectorAll() { return []; }, select() {}, focus() {}, click() {},
    innerHTML: '', textContent: '', className: '', value: '', options: [],
    getBoundingClientRect() { return { left: 0, top: 0, width: 740, height: 431 }; } };
  Object.defineProperty(c, 'width', { get() { return c._w; }, set(v) { c._w = v; } });
  Object.defineProperty(c, 'height', { get() { return c._h; }, set(v) { c._h = v; } });
  c.getContext = function () { const g = makeCtx(surface); g._owner = c; return g; };
  return c;
}

const cache = {};
global.window = { addEventListener() {}, innerWidth: 1600 };
global.requestAnimationFrame = () => {};
global.navigator = {};
global.localStorage = { getItem() { return null; }, setItem() {}, removeItem() {} };
global.Image = function () {
  const self = this;
  this.width = 0; this.height = 0;
  let src = '';
  Object.defineProperty(this, 'src', {
    get() { return src; },
    set(v) { src = v; const p = pixels(v); if (p) { self.width = p.w; self.height = p.h; } },
  });
  this.addEventListener = function (ev, fn) { if (ev === 'load') self._onload = fn; };
  this.onload = null;
};
global.document = {
  getElementById: (id) => cache[id] || (cache[id] = makeCanvas(id === 'view' ? 'main' : 'el')),
  querySelector: () => makeCanvas('el'), querySelectorAll: () => [],
  createElement: (t) => makeCanvas(t === 'canvas' ? 'off' : 'el'), addEventListener() {},
};

const m = page.match(/<script>([\s\S]*?)<\/script>\s*<\/body>/);
const hook = ';globalThis.__P={draw:draw,ctx:ctx,IMG:IMG,L:L,PROP_GLOW:PROP_GLOW,' +
  'litPixels:litPixels,litFace:litFace,add:add,state:state,' +
  'drawPropGlass:drawPropGlass,rectOf:rectOf,layer:layer,SRC:SRC,D:D,' +
  'occluderAlpha:occluderAlpha,shadowGrid:shadowGrid,band:band,' +
  'buildLightMap:buildLightMap,BLOCKED:BLOCKED,light:light,setLamps:setLamps};';
try { new Function(m[1] + hook)(); } catch (e) {
  console.log('SCRIPT THREW:', e.message); console.log(e.stack.split('\n').slice(1, 5).join('\n'));
  process.exit(1);
}
const P = globalThis.__P;

// The main canvas is whatever the page drew through; record against it.
const mainCtx = P.ctx;
mainCtx.drawImage = function (im) { PAINTED.push({ phase: PHASE, src: String((im && (im.src || im._src)) || '?') }); };

// Put two vending machines and a caged lamp in the room, the way the user would.
['prop:vend_a', 'prop:vend_b', 'prop:caglamp', 'prop:barrels'].forEach((k) => {
  try { P.add(k); } catch (e) { console.log('could not add ' + k + ': ' + e.message); }
});
const items = P.L().items.filter((o) => o.type === 'prop');
console.log('props in the layout: ' + items.map((o) => o.id).join(', ') + '\n');

items.forEach(function(o){ var k = 'prop_' + o.id; if (P.SRC[k]) { var im = P.IMG[k]; } });
PHASE = 'draw';
PAINTED.length = 0;
try { P.draw(); } catch (e) {
  console.log('draw THREW: ' + e.message); console.log(e.stack.split('\n').slice(1, 4).join('\n'));
}

PHASE = 'propglass';
const before = PAINTED.length;
try { P.drawPropGlass(); } catch (e) { console.log('drawPropGlass THREW: ' + e.message); }
const glassDraws = PAINTED.length - before;

console.log('prop'.padEnd(18) + 'on the list  lit pixels  drawn as glass');
let bad = 0;
items.forEach((o) => {
  const listed = !!P.PROP_GLOW[o.id];
  const im = P.IMG['prop_' + o.id];
  const lit = im ? P.litPixels(im) : null;
  let n = 0;
  if (lit && lit._img) { const d = lit._img.data; for (let i = 0; i < d.length; i += 4) if (d[i + 3] > 0) n++; }
  const painted = PAINTED.slice(before).some((p) => String(p.src).indexOf(o.id) >= 0);
  if (listed && !painted) bad++;
  console.log(o.id.padEnd(18) + (listed ? 'yes' : 'NO ').padEnd(13) +
    String(n).padStart(6) + '      ' + (painted ? 'yes' : (listed ? 'NO  <-- stays dark' : '-')));
});
console.log('\ndrawPropGlass painted ' + glassDraws + ' lit face(s)');

const lay = P.L();
const standing = lay.items.filter(function(o){ return P.band(o) && P.band(o) !== "wall"; });
console.log("");
console.log("things that should block light: " + standing.length);
standing.slice(0,8).forEach(function(o){ console.log("   " + (o.id || o.type) + "  band " + P.band(o)); });
let threw = null;
try { P.occluderAlpha(false, true); } catch(e){ threw = e.message; }
console.log("occluderAlpha(false,true) threw: " + (threw || "no"));
const g = P.shadowGrid();
let cells = 0; if (g) for (let i = 0; i < g.length; i++) if (g[i]) cells++;
console.log("shadow grid blocking cells     : " + cells +
  (cells > 0 ? "   (things are in the way)" : "   <-- STILL EMPTY"));
process.exit(cells > 0 ? 0 : 1);

