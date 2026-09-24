// Run the bench's script against a stub DOM and report what throws.
const fs = require('fs');
const h = fs.readFileSync(process.argv[2], 'utf8');
const m = h.match(/<script>([\s\S]*?)<\/script>\s*<\/body>/);

const ctx = new Proxy({}, {
  get(t, k) {
    if (k === 'measureText') return () => ({ width: 10 });
    if (k === 'createLinearGradient') return () => ({ addColorStop() {} });
    if (typeof k === 'string' && /^(fillStyle|strokeStyle|font|textAlign|textBaseline|lineWidth|globalCompositeOperation|globalAlpha|imageSmoothingEnabled)$/.test(k)) return t[k];
    return () => {};
  },
  set(t, k, v) { t[k] = v; return true; },
});

function mk(id) {
  return {
    id, style: {}, dataset: {}, hidden: false,
    classList: { add() {}, remove() {}, toggle() { return false; }, contains() { return false; } },
    appendChild() {}, removeChild() {}, addEventListener() {}, setAttribute() {},
    getAttribute() { return null; }, querySelector() { return mk('q'); },
    querySelectorAll() { return []; }, getContext() { return ctx; },
    getBoundingClientRect() { return { left: 0, top: 0, width: 740, height: 431 }; },
    select() {}, focus() {}, click() {},
    innerHTML: '', textContent: '', className: '', value: '', width: 0, height: 0, options: [],
  };
}
const cache = {};
global.window = { addEventListener() {}, innerWidth: 1600 };
global.requestAnimationFrame = () => {};
global.navigator = {};
global.localStorage = { getItem() { return null; }, setItem() {} };
global.Image = function () { this.width = 48; this.height = 48; this.src = ''; };
global.document = {
  getElementById: (id) => cache[id] || (cache[id] = mk(id)),
  querySelector: () => mk('main'), querySelectorAll: () => [],
  createElement: () => mk('new'), addEventListener() {},
};

const hook = ';globalThis.__ui=ui;globalThis.__gallery=gallery;globalThis.__draw=draw;';
try {
  new Function(m[1] + hook)();
  console.log('script ran to the end');
} catch (e) {
  console.log('SCRIPT THREW:', e.message);
  console.log(e.stack.split('\n').slice(1, 4).join('\n'));
  process.exit(1);
}
for (const name of ['__gallery', '__ui', '__draw']) {
  try {
    globalThis[name]();
    console.log(name.slice(2) + ': ok');
  } catch (e) {
    console.log(name.slice(2) + ' THREW: ' + e.message);
    console.log(e.stack.split('\n').slice(1, 4).join('\n'));
  }
}
