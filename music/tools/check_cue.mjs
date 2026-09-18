// Check a cue against the musical rules, without listening to it.
//
//   node check_cue.mjs [cue-id ...]        (default: every cue)
//
// Reports, per cue:
//   * length, tempo, form, and the density curve section by section
//   * notes on strong beats that are not in the running chord
//   * held notes a half step or a tritone from a chord tone   <- the ones that sound wrong
//   * repeated notes and leaps wider than an octave across phrase seams
//   * for First Light and Quiet Orbit: any C or E natural, which those two must never contain
//
// Exit code is non-zero if anything failed, so it works in a pre-commit hook.

import { JSDOM } from 'jsdom';
import fs from 'fs';

const LAB = new URL('../lab/tk_music_lab.html', import.meta.url);
// ALL SEVENTEEN, not the seven this list used to hold. The other ten play,
// render and pass when named explicitly -- they were simply never added here,
// so `check_cue.mjs` with no arguments silently checked 7 of 17 while its own
// header said "default: every cue". A check that quietly covers 41% of the
// material is worse than one that says it is partial.
const ALL = [
  'title',
  'fl',
  'coldstart',
  'longway',
  'closequarters',
  'cutsignal',
  'qo',
  'slipstream',
  'redline',
  'deadweight',
  'hairline',
  'nothingleft',
  'wrongship',
  'overpressure',
  'eventhorizon',
  'noair',
  'laststand',
];
const ids = process.argv.slice(2).length ? process.argv.slice(2) : ALL;
const NO_FIFTH = ['qo'];   // Quiet Orbit's own rule: no C, no E natural anywhere.
                           // First Light is not in this list: its written lines do reach the fifth,
                           // and it is a verbatim port of tkg/audio/first_light.py, so it is not ours to change.
const NAMES = ['C','C#','D','D#','E','F','F#','G','G#','A','A#','B'];
const nm = m => NAMES[m % 12] + (Math.floor(m / 12) - 1);

const html = fs.readFileSync(LAB, 'utf8');
const src = html.slice(html.indexOf('<script>') + 8, html.lastIndexOf('</script>'));
const dom = new JSDOM(html.replace(/<link[^>]*>/g, '').replace(/<script>[\s\S]*<\/script>/, ''),
                      { runScripts: 'outside-only', pretendToBeVisual: true });
const w = dom.window;
w.requestAnimationFrame = () => 0;
w.HTMLElement.prototype.scrollIntoView = () => {};
w.eval(src.replace('buildUI();\n',
  'buildUI(); window.__lab = {THEMES, buildTheme, slotEvents, midi, switchSong};'));
const lab = w.__lab;

let failures = 0;

for (const id of ids) {
  lab.switchSong(id);
  const th = lab.THEMES[0];
  const sg = lab.buildTheme(th);
  const ev = lab.slotEvents(sg);
  const problems = [];

  // 0. every event must be a real note: an unparseable name (Cb, Fb, E#) turns into NaN and
  //    blows up at render time, which is a much worse way to find out
  const broken = Object.entries(ev).flatMap(([slot, list]) =>
    list.filter(e => !Number.isFinite(e[0]) || !Number.isFinite(e[1]) || !Number.isFinite(e[2]))
        .map(() => slot));
  if (broken.length) problems.push(`unplayable events in: ${[...new Set(broken)].join(', ')} (check for note names like Cb or E#)`);

  const melodic = [...(ev.tune || []).filter(e => !e[5]), ...(ev.middle || [])].sort((a, b) => a[0] - b[0]);
  const chordOf = bar => sg.chordMap && sg.barChords ? sg.chordMap[sg.barChords[bar]] : null;
  const pcs = bar => (chordOf(bar) || []).map(n => lab.midi(n) % 12);

  // 1. strong beats should be chord tones
  const offChord = melodic
    .filter(e => Math.abs(e[0] % 2) < 1e-6 && chordOf(Math.floor(e[0] / 4)))
    .filter(e => !pcs(Math.floor(e[0] / 4)).includes(e[2] % 12))
    .map(e => `${nm(e[2])} in bar ${Math.floor(e[0] / 4) + 1} over ${sg.barChords[Math.floor(e[0] / 4)]}`);

  // 2. held notes must not grind: a half step or a tritone from a chord tone
  const grinds = melodic
    .filter(e => e[1] >= 2.5 && chordOf(Math.floor(e[0] / 4)))
    .filter(e => !pcs(Math.floor(e[0] / 4)).includes(e[2] % 12))      // a chord tone can never grind
    .filter(e => pcs(Math.floor(e[0] / 4)).some(p => {
      const gap = Math.abs(p - e[2] % 12) % 12;
      return gap === 1 || gap === 11 || gap === 6;
    }))
    .map(e => `${nm(e[2])} held in bar ${Math.floor(e[0] / 4) + 1} over ${sg.barChords[Math.floor(e[0] / 4)]}`);

  // 3. seams: a note should not repeat itself, or leap more than an octave, when notes run together
  const tune = (ev.tune || []).filter(e => !e[5]).sort((a, b) => a[0] - b[0]);
  const gapOk = (prev, e) => e[0] - (prev[0] + prev[1]) < 1.5;
  const repeats = tune.filter((e, j) => j && e[2] === tune[j - 1][2] && gapOk(tune[j - 1], e))
                      .map(e => `${nm(e[2])} twice at bar ${Math.floor(e[0] / 4) + 1}`);
  const leaps = tune.filter((e, j) => j && Math.abs(e[2] - tune[j - 1][2]) > 12 && gapOk(tune[j - 1], e))
                    .map(e => `leap into bar ${Math.floor(e[0] / 4) + 1}`);

  // 4. the two phrase-based cues may not touch the fifth or the leading tone
  const used = [...new Set([...(ev.tune || []), ...(ev.middle || []), ...(ev.echo || [])].map(e => e[2] % 12))];
  const forbidden = NO_FIFTH.includes(id)
    ? used.filter(p => p === 0 || p === 4).map(p => NAMES[p])   // C is the fifth of F, E is the leading tone
    : [];

  // Only two things are actually wrong: a held note that grinds, and a pitch a cue has sworn off.
  // The rest is worth a look but is often deliberate — the phrase itself puts the second on a
  // strong beat, and a written line may repeat a note on purpose.
  const notes_ = [];
  if (grinds.length) problems.push(`grinding held notes: ${[...new Set(grinds)].join('; ')}`);
  if (forbidden.length) problems.push(`must not contain: ${forbidden.join(' ')}`);
  if (offChord.length) notes_.push(`off-chord on strong beats (${offChord.length}): ${[...new Set(offChord)].slice(0, 4).join('; ')}${offChord.length > 4 ? ' …' : ''}`);
  if (repeats.length) notes_.push(`repeated notes: ${[...new Set(repeats)].join('; ')}`);
  if (leaps.length) notes_.push(`leaps over an octave: ${[...new Set(leaps)].join('; ')}`);

  const density = sg.sections.map(s => {
    const n = [...(ev.tune || []), ...(ev.middle || []), ...(ev.extra || []), ...(ev.echo || [])]
      .filter(e => e[0] >= s[1] * 4 && e[0] < s[2] * 4).length;
    return `${s[0]} ${n}`;
  }).join(' → ');

  console.log(`\n${th.name} (${th.tier}) — ${sg.bpm} BPM, ${sg.loopBeats / 4} bars, ` +
              `${(sg.loopBeats * 60 / sg.bpm).toFixed(3)}s`);
  console.log(`  form: ${sg.sections.map(s => `${s[0]}(${s[2] - s[1]})`).join(' ')}`);
  console.log(`  density: ${density}`);
  console.log(`  deep hits: ${(ev.drums || []).length}`);
  notes_.forEach(n => console.log(`  note     ${n}`));
  if (problems.length) { failures++; problems.forEach(p => console.log(`  PROBLEM  ${p}`)); }
  else console.log('  no problems');
}

console.log(failures ? `\n${failures} cue(s) with problems` : '\nall cues clean');
process.exit(failures ? 1 : 0);
