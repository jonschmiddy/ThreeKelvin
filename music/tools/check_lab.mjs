// Smoke-test the lab page itself: does it load, do all the tabs work, does the transport run,
// does scrubbing land where it should, and does each cue still report its locked setup?
//
//   node check_lab.mjs
//
// This catches the class of bug that a musical check can't: a JavaScript error on load, a stale
// saved setting breaking a panel, a scrub bar that doesn't move, a tab that forgets its palette.

import { JSDOM } from 'jsdom';
import fs from 'fs';
import * as WA from 'node-web-audio-api';

const LAB = new URL('../lab/tk_music_lab.html', import.meta.url);
const html = fs.readFileSync(LAB, 'utf8');
const src = html.slice(html.indexOf('<script>') + 8, html.lastIndexOf('</script>'));

const dom = new JSDOM(html.replace(/<link[^>]*>/g, '').replace(/<script>[\s\S]*<\/script>/, ''),
                      { runScripts: 'outside-only', pretendToBeVisual: true, url: 'https://lab.test/' });
const w = dom.window;
w.requestAnimationFrame = () => 0;
w.Float32Array = Float32Array;
w.HTMLElement.prototype.scrollIntoView = () => {};
w.HTMLElement.prototype.setPointerCapture = () => {};
w.HTMLElement.prototype.getBoundingClientRect = function () {
  return { left: 0, width: this.id === 'progress' ? 800 : 100, top: 0, height: 30 };
};

// settings left over from an older version of a cue: the lab must ignore them, not break on them
w.localStorage.setItem('tk-lab5-qo', JSON.stringify({ tweaks: { bpm: 999, mode: 'nonsense' }, gfx: { space: 'bogus' } }));

let now = 0;
const ctx = new WA.OfflineAudioContext(2, 44100, 44100);
w.AudioContext = function () {
  return new Proxy(ctx, { get(t, k) {
    if (k === 'currentTime') return now;
    if (k === 'state') return 'running';
    if (k === 'resume') return async () => {};
    const v = t[k]; return typeof v === 'function' ? v.bind(t) : v;
  }});
};
let tick = null;
w.setInterval = fn => { tick = fn; return 1; };
w.clearInterval = () => { tick = null; };

const notes = [];
const errors = [];
w.addEventListener('error', e => errors.push(String(e.error && e.error.stack || e.error)));

let threw = null;
try {
  w.eval(src
    .replace('function voice(s, p, t, dur, m, prev, vel){',
             'function voice(s, p, t, dur, m, prev, vel){ window.__notes.push([t, p.name]); return;')
    .replace('buildUI();\n', 'buildUI(); window.__lab = {state, currentBeat, get loop(){return LOOP_BEATS}};'));
} catch (e) { threw = String(e.stack || e); }
w.__notes = notes;

const d = w.document;
const lab = w.__lab;
const run = seconds => { for (let i = 0; i < seconds * 25; i++) { now += .04; if (tick) tick(); } };
let fails = 0;
const check = (label, ok, detail = '') => {
  console.log(`${ok ? 'ok  ' : 'FAIL'}  ${label}${detail ? ' — ' + detail : ''}`);
  if (!ok) fails++;
};

check('page loads without throwing', !threw, threw ? threw.split('\n')[0] : '');
const tabs = [...d.querySelectorAll('[role=tab]')];
check('every cue has a tab', tabs.length >= 7, tabs.map(t => t.textContent).join(' | '));

for (const tab of tabs) {
  const id = tab.dataset.id;
  tab.click();
  const line = d.getElementById('summaryInline').textContent;
  check(`${id}: settings line is present`, line.length > 60, line.slice(0, 48) + '…');

  const play = d.getElementById('theme-0').querySelector('.tplay');
  notes.length = 0;
  play.click();
  await new Promise(r => setTimeout(r, 10));
  run(8);
  check(`${id}: plays notes`, notes.length > 0, `${notes.length} notes, ${[...new Set(notes.map(n => n[1]))].filter(Boolean).length} instruments`);

  // scrub to three quarters of the way through, via the strip and via the slider
  const prog = d.getElementById('progress');
  const ev = (type, x) => { const e = new w.Event(type, { bubbles: true, cancelable: true }); e.clientX = x; e.pointerId = 1; e.button = 0; return e; };
  prog.dispatchEvent(ev('pointerdown', 600)); prog.dispatchEvent(ev('pointerup', 600));
  run(.5);
  const target = lab.loop * .75;
  check(`${id}: clicking the strip seeks`, Math.abs(lab.currentBeat() - target) < 6,
        `beat ${lab.currentBeat().toFixed(0)} of ${lab.loop}`);

  const rng = d.getElementById('scrubRange');
  rng.value = String(Math.round(lab.loop * .25));
  rng.dispatchEvent(new w.Event('input', { bubbles: true }));
  rng.dispatchEvent(new w.Event('change', { bubbles: true }));
  run(.5);
  check(`${id}: the slider seeks`, Math.abs(lab.currentBeat() - lab.loop * .25) < 6,
        `beat ${lab.currentBeat().toFixed(0)}`);

  play.click();   // stop
}

check('no errors on the page', errors.length === 0, errors[0] || '');
console.log(fails ? `\n${fails} check(s) failed` : '\nall checks passed');
process.exit(fails ? 1 : 0);
