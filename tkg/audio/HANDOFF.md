# HANDOFF — roguelike soundtrack from a whistled motif

Everything here is pure Python. numpy + scipy only. No DAW, no samples, no external audio libs. `ffmpeg` is used only for m4a→wav in and wav→mp3 out.

## Run it

```bash
pip install numpy scipy
mkdir -p out
python3 arrange.py     # -> out/theme.wav  + out/stems/*.wav   (2:04)
python3 dread.py       # -> out/dread.wav + out/dread_stems/*.wav (2:18)
```

Both scripts write output paths under `/home/claude/out/` — change those two constants at the bottom of each file.

## Files

| File | What it is |
|---|---|
| `synth.py` | The whole engine. Instruments, envelopes, filters, reverb, delay, `Track` mixer. ~29 functions. |
| `motif.py` | The source motif and its transformations. Shared by every score. |
| `arrange.py` | Score for "Slow Drift" — main theme, F minor, 142 BPM, 72 bars. |
| `dread.py` | Score for "Dead Sector" — F Phrygian, 71 BPM, 40 bars. |
| `burn.py` | Score for "Hard Burn" — combat, F Aeolian, 142 BPM, 48 bars. |
| `warm.py` | Score for "Warm Ship" — station and refit, 71 BPM, 24 bars. |
| `boss.py` | Score for "Poisoned Ground" — boss, 71 BPM, 32 bars. |
| `shells.py` | Score for "Nine Shells" — star chart, whole-tone, 71 BPM, 40 bars. |
| `business.py` | Score for "Ship's Business" — events, sonata form, 142 BPM, 48 bars. |
| `home.py` | Score for "Five Ways Home" — title, theme and variations, 142 BPM, 48 bars. |
| `analyze.py` | Frame-wise pitch track of the source recording (4096 FFT, 512 hop, parabolic peak interp). Writes `t.npy`/`f.npy`/`r.npy`. |
| `seg.py` | Segments the pitch track into notes via an RMS gate, maps Hz → note name + cents. |
| `refine.py` | RMS-weighted per-note frequency estimate. This produced the F6/G6/A♭6 result. |

Run the analysis chain in order: `analyze.py` → `seg.py` → `refine.py`.

## Architecture

`synth.py` is three layers:

1. **Instruments** — every one returns a mono float array. `whistle`, `pad`, `sub`, `pluck`, `bell`, `kick`, `snare`, `hat`, plus the dread set: `drone`, `cluster`, `bowed`, `metal`, `heart`, `impact`, `rev_swell`, `whistle_bend`, `air`.
2. **`Track`** — a stereo buffer with `.add(audio, at_beat, pan, gain)`. Beats, not samples. Equal-power pan.

   Five instruments were added after the first two cues: `blade` (driven mid-range, the combat riff — the only distorted voice in the set), `glass` (glass harmonica, the only sustained voice with no noise component at all), and then `reed`, `strings` and `hammer` for the two classical cues. See `DEVELOPMENT_NOTES.md` for why none of those three could be an existing voice with different parameters.
3. **Effects** — `reverb()` convolves against a synthetic IR (decaying filtered noise, generated at import). `delay()` is ping-pong with feedback.

A score file builds a dict of `Track` objects (one per stem), fills them with `.add()` calls, then renders each through a per-stem `(reverb wet, level)` table and hands the lot to `synth.master()`, which sums them and applies the bus.

**`master()` prints the stems through the bus too**, so they sum back to the mix sample-for-sample rather than sitting 3.7 dB below it. That is the difference between stems you can layer at runtime and stems you can only listen to. `README.md` has the derivation.

## Tempo

`synth.set_tempo(bpm)` rebinds the `SPB`/`BAR` globals. Call it **before** `from synth import *`, or the star import copies stale values:

```python
import synth; synth.set_tempo(71)
from synth import *
```

Both scores do this at the top.

142 and 71 BPM are deliberate — exact 2:1. Every cue uses one of those two tempi, so all eight are bar-aligned with each other and any of the 28 pairings can crossfade without a tempo match. Cues change key freely; the lock is about bar lengths and is indifferent to it.

## Known issues — read before you build on it

- ~~**Not deterministic.**~~ **Fixed and verified.** `np.random.seed(4242)` sits before the IRs in `synth.py` and `np.random.seed(1729)` at the top of each score, which fixes the whole RNG stream, not just the reverb. Two renders of `dread.py` on the same machine are byte-identical. Renders are *not* reproducible across machines — a different numpy/scipy build gives the same composition with different noise realisations (correlation 0.80 dread, 0.95 theme), so pick one render as master.
- **`pluck()` is a per-sample Python loop.** Karplus-Strong, no vectorization. It's the slowest thing here. `arrange.py` caches by (freq, duration) to keep it tolerable — see `pluck_cache`.
- ~~**`Track.add` has a dead local**~~ — deleted.
- **Instrument envelopes are absolute times, not fractions of the note.** `whistle()` used to want 45 ms of attack and 80 ms of decay whatever you asked it for, so any note under ~250 ms fell into `env_adsr`'s degenerate branch while its 180 ms vibrato ramp was still running — a sliding blip instead of a pitch. It scales below `synth.SHORT_NOTE` now. Every other voice still has fixed times; `reed()` needs 30 ms and `strings()` 160 ms, so ornament them at your peril. The scan described in `DEVELOPMENT_NOTES.md` is the check.
- **Filter sweeps in `drone()` are stepped**, not smooth — 0.25 s blocks re-filtered. Audible on very long notes if you listen for it. Fine at the levels used.
- **`reverb()` renormalizes** against the dry peak, which is crude and means wet level interacts with input level. Works, isn't principled.
- ~~**Stem WAVs are uncompressed**~~ — `build.py` encodes to Ogg Vorbis now: 390 MB of WAV became 36.2 MB. See `README.md`.

## The musical part

Two notes files carry the composition reasoning:

- `THEME_NOTES.md` — motif analysis, the i–♭VI–iv–♭VII reharmonization table, form, stem→game-state map.
- `DREAD_NOTES.md` — the Phrygian mutation, dread devices per bar range, tritone section.

The short version: the source motif is scale degrees **1–2–1–2–♭3** in F minor. Those three pitches are consonant across many modes, so the melody is never rewritten — only the harmony under it changes. The dread cue mutates exactly one note (2 → ♭2) to flip Aeolian into Phrygian.

## Obvious next work

- ~~Seed the RNG, verify byte-identical renders.~~ Done.
- Vectorize `pluck()`. Still the slowest thing here; the theme takes ~19 s and almost all of it is this.
- ~~Extract the score DSL~~ — done. `motif.py` holds every form (`MOTIF`, `PHRYGIAN`, `MAGGIORE`, `INVERT`, `TRITONE`, `SINK`, `ANSWER`, `FALSE_ANSWER`) and every transformation (`bar`, `octave`, `pitches`, `augment`, `diminish`, `transpose`, `retrograde`, `sequence`, `appoggiatura`, `turn`, `whole_tone`).

  **Use `pitches()`, not `octave()`, for anything transposed.** `octave()` names pitch classes in a fixed octave, which is correct only for a form written inside one octave in its home key; transpose it and the octave boundary moves under it, so `transpose(MOTIF, 6)` named in octave 5 turns the rising whole tone into a falling major seventh. `pitches()` walks the intervals from a starting pitch instead. Nothing hit this until the first cue that transposed a form. It has no dependencies and carries no tempo or octave, so it can be imported before or after `set_tempo` and one form serves a 142 BPM combat cue and a 71 BPM dread cue unchanged. Verified render-neutral: all 19 theme and dread files came back byte-identical after `arrange.py` and `dread.py` were pointed at it.
- ~~Stinger/death-cue variants specced but not built.~~ Both exist as `ui_confirm` and `death_sting` in `sfx.py`. The boss-reveal and procedural-reharmonisation ideas are still unbuilt — see `README.md`.

## Read next

`README.md` is now the entry point: build commands, what ships versus the
concert master, the sound effect set, and the gotchas that cost real time
(block-encoding Ogg, per-process rendering, the tempo-globals import order).
