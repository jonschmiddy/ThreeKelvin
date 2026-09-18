// Render a cue from the music lab to a WAV file, with no browser involved.
//
//   node render_wav.mjs <cue-id> [outfile.wav]
//
// Cue ids: title, fl, coldstart, longway, qo, slipstream, cutsignal
// (see ../songs/cues.json for the list and what each one is)
//
// Requires: npm install jsdom node-web-audio-api
//
// The lab page is the single source of truth for every note, patch and effect.
// This script loads it, asks it for the cue's events, schedules them into an
// offline audio context, and writes the result out as 16-bit stereo WAV.

import { JSDOM } from 'jsdom';
import fs from 'fs';
import * as WA from 'node-web-audio-api';

const LAB = new URL('../lab/tk_music_lab.html', import.meta.url);
const id = process.argv[2] || 'qo';
const out = process.argv[3] || `../audio/${id}.wav`;
const SR = 44100;
const TAIL = 6;                        // seconds of room for reverb and delay tails

const html = fs.readFileSync(LAB, 'utf8');
const src = html.slice(html.indexOf('<script>') + 8, html.lastIndexOf('</script>'));
const page = () => new JSDOM(html.replace(/<link[^>]*>/g, '').replace(/<script>[\s\S]*<\/script>/, ''),
                             { runScripts: 'outside-only', pretendToBeVisual: true });

// 1. Ask the lab how long this cue is.
{
  var meta;
  const m = page();
  m.window.requestAnimationFrame = () => 0;
  m.window.HTMLElement.prototype.scrollIntoView = () => {};
  m.window.eval(src.replace('buildUI();\n', `buildUI(); switchSong('${id}'); window.__m = buildTheme(THEMES[0]);`));
  meta = m.window.__m;
  if (!meta) { console.error(`unknown cue: ${id}`); process.exit(1); }
}
const seconds = meta.loopBeats * 60 / meta.bpm;

// 2. Render the loop offline.
const dom = page();
const w = dom.window;
w.requestAnimationFrame = () => 0;
w.Float32Array = Float32Array;
w.HTMLElement.prototype.scrollIntoView = () => {};
const ctx = new WA.OfflineAudioContext(2, Math.ceil((seconds + TAIL) * SR), SR);
w.AudioContext = function () { return ctx; };
w.setInterval = () => 1;
w.clearInterval = () => {};
w.eval(src.replace('buildUI();\n', `buildUI(); switchSong('${id}'); initAudio();
  const sg = buildTheme(THEMES[0]); SPB = 60 / sg.bpm; events = slotEvents(sg);
  for (const slot in events){
    if (!state.slots[slot]) continue;
    const s = sessionFor(slot); applyFx(slot, .001); const p = P[state.slots[slot] - 1];
    for (const [b, d, m, v, low] of events[slot]){
      if (low && state.slots.bass) continue;      // the pad's lowest note is left to the sub
      playEvent(slot, s, p, .05 + b * SPB, d, m, v);
    }
  }`));
await new Promise(r => setTimeout(r, 300));
const buf = await ctx.startRendering();

// 3. Write 16-bit stereo WAV, normalised with a little headroom.
const L = buf.getChannelData(0);
const R = buf.numberOfChannels > 1 ? buf.getChannelData(1) : L;
const n = L.length;
let peak = 0;
for (let i = 0; i < n; i++) peak = Math.max(peak, Math.abs(L[i]), Math.abs(R[i]));
const gain = peak > 0 ? Math.min(1, 0.89 / peak) : 1;
const data = Buffer.alloc(n * 4);
for (let i = 0; i < n; i++) {
  data.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(L[i] * gain * 32767))), i * 4);
  data.writeInt16LE(Math.max(-32768, Math.min(32767, Math.round(R[i] * gain * 32767))), i * 4 + 2);
}
const head = Buffer.alloc(44);
head.write('RIFF', 0); head.writeUInt32LE(36 + data.length, 4); head.write('WAVE', 8);
head.write('fmt ', 12); head.writeUInt32LE(16, 16); head.writeUInt16LE(1, 20); head.writeUInt16LE(2, 22);
head.writeUInt32LE(SR, 24); head.writeUInt32LE(SR * 4, 28); head.writeUInt16LE(4, 32); head.writeUInt16LE(16, 34);
head.write('data', 36); head.writeUInt32LE(data.length, 40);
fs.writeFileSync(new URL(out, import.meta.url), Buffer.concat([head, data]));

console.log(`${id}: ${meta.bpm} BPM, ${meta.loopBeats / 4} bars, loop ${seconds.toFixed(3)}s ` +
            `(+${TAIL}s tail), peak ${peak.toFixed(2)} -> ${out}`);
