# Audio

Everything the game hears is generated here by pure Python — numpy and scipy
only, no DAW, no sample libraries. Two music cues, twenty-four sound effects,
one synth engine shared between them.

```bash
pip install numpy scipy soundfile
python3 build.py            # music + sfx -> ../assets/audio/
python3 build.py music
python3 build.py sfx
```

Half a minute for the lot. `audio/out/` holds the WAV intermediates (~850 MB)
and is gitignored; only the encoded `assets/audio/` is committed.

## Files

| File | What it is |
|---|---|
| `synth.py` | The engine. Instruments, envelopes, filters, reverb, delay, the `Track` mixer, and the master bus. |
| `arrange.py` | Score for **"Slow Drift"** — main theme, F minor, 142 BPM, 72 bars. |
| `dread.py` | Score for **"Dead Sector"** — F Phrygian, 71 BPM, 40 bars. |
| `sfx.py` | The sound effect set. |
| `build.py` | Renders everything and encodes it into `../assets/audio/`. |
| `analyze.py` → `seg.py` → `refine.py` | Pitch analysis of the original whistled recording. Run in that order. This is what produced the F6/G6/A♭6 result the whole soundtrack is built on. |
| `THEME_NOTES.md`, `DREAD_NOTES.md` | The composition reasoning. Read these first. |

`.gdignore` keeps Godot out of this directory — it is source, not assets.

## The two cues are one idea

The source motif is scale degrees **1–2–1–2–♭3**. "Dead Sector" mutates exactly
one note, 2 → ♭2, which turns F Aeolian into F Phrygian and a drifting whole
tone into a stalking semitone. The melody is never rewritten; only the harmony
under it changes.

**142 and 71 BPM are an exact 2:1.** One dread bar is two theme bars, so the
engine can cut or crossfade between them without a tempo match. Verified at
`ratio 2.000000`.

| | Bar | 8-bar phrase | Body | Stems |
|---|---|---|---|---|
| theme | 1.6901 s | 13.52 s | 121.690 s, 72 bars | 8 |
| dread | 3.3803 s | 27.04 s | 135.211 s, 40 bars | 9 |

## Master bus — why stems are printed through it

`master()` in `synth.py` sums the stems and applies the bus: low-shelf tilt →
soft clip → peak normalise → fades. Crucially it applies **every stage to each
stem as well**, so the printed stems sum back to the mix sample-for-sample.

The soft clipper is the only non-linear stage, and it is applied as a *shared
gain curve* taken from the summed bus:

    tanh(a·b)/a  ==  b · G      where   G = tanh(a·b)/(a·b)

`G` depends only on the bus, so scaling every stem by it and summing reproduces
the clipped bus exactly rather than approximately.

This matters because a game that layers stems at runtime *is* building the mix
itself. The first render printed stems straight off the instrument chain and
put the bus on the mix only: the dread stems needed +3.7 dB to match, and since
the final stage is a peak normalise, the correction was render-dependent — so
there was no fixed number to compensate with either. Measured after the fix,
across all seventeen stems: **max error 6 LSB out of 32768**, which is nothing
but 16-bit rounding.

## What ships vs. the concert master

`build.py` renders each cue twice.

* **Concert master** (`out/theme.wav`, `out/dread.wav`) — exactly as composed,
  fades and all. Reference only, not shipped.
* **Shipped** (`assets/audio/music/<cue>/`) — rendered with `--loop`, which
  drops the fade-out and wraps the reverb tail back over the head, and with a
  **32 Hz bus high-pass**.

Both differences are deliberate:

* The fade-out was baked into the *stems* as well as the mix (5.0 s on dread,
  2.6 s on theme) and ate real musical material, so anything looped off the old
  files faded out mid-loop.
* `drone()` adds a hardcoded sub-octave, which put the F1 pedal's strongest
  partial at **21.8 Hz** — below the reproduction floor of every laptop, phone
  and TV, while still driving the limiter. The concert master keeps it. The
  game does not spend headroom on something only a subwoofer will ever hear.

Loop seams measured on the encoded files: theme 0.017, dread 0.00009, against
interior sample-to-sample motion of 0.33 and 0.06 respectively. Inaudible.

## Sound effects

Twenty-four, all built from the same synth and tuned to the same F minor, so a
click landing under the score is consonant with whatever chord is running.

The art direction translates directly (`CLAUDE.md`, "Cold universe, warm ship"):
chrome is cold, dry and quiet; only things that actually radiate get a warm low
body. Measured spectral centroids bear it out — `ui_hover` 10.6 kHz and
`ui_click` 8.5 kHz against `station_dock` 53 Hz, `overheat` 64 Hz and
`impact_hull` 81 Hz.

Two design rulings are audible rather than merely implemented:

* **Ballistics run cold, energy weapons run hot.** `weapon_ballistic` is a dry
  mechanical crack at 338 Hz; `weapon_energy` is a bright ionised zap at
  1072 Hz that sags as it drains. You can hear what a build is made of.
* **Venting is a real action.** `vent` falls and resolves; `overheat` rises and
  bites. Opposite gestures for opposite outcomes.

Two sounds specced in the notes files and previously unbuilt now exist:
`ui_confirm` is the G→A♭ stinger from `THEME_NOTES.md` §6, and `death_sting` is
the F→G♭ semitone on one low bowed note from `DREAD_NOTES.md` §5.

SFX ship as **WAV**, not Ogg: a UI click has to be instant, and the whole set is
2.8 MB — smaller than a single music stem.

## Sizes

| | Before | After |
|---|---|---|
| Music | 390 MB WAV | 36.2 MB Ogg Vorbis |
| SFX | — | 2.8 MB WAV |

## Gotchas

* **Encode Ogg in blocks.** libsndfile's Vorbis encoder sizes a stack buffer
  from the write length, so handing it a two-minute buffer in one call
  overflows the thread stack and segfaults inside `_preextrapolate_helper`.
  `build.py` writes a second at a time.
* **Render each cue in its own process.** A cue holds about a gigabyte of
  float64 track buffers, and the scores rebind `synth`'s tempo globals at
  import — so importing both into one interpreter gives the second one the
  first one's bar length.
* **`synth.set_tempo(bpm)` must be called before `from synth import *`**, or
  the star import copies stale `SPB`/`BAR` values. Both scores already do this.
* **Renders are deterministic within a machine but not across them.**
  `np.random.seed` is set in `synth.py` and in both scores; two runs here are
  byte-identical. A different numpy/scipy build gives the same composition with
  different noise realisations (measured correlation 0.80 dread, 0.95 theme).
  Pick one render as master and do not mix.

## Not yet built

* An 8-bar A-section loop (`THEME_NOTES.md` §5) for indefinite exploration,
  jumping to the through-composed material only on events.
* Boss reveal: the *original* whole-tone motif over the tritone pedal —
  familiar melody, poisoned ground (`DREAD_NOTES.md` §5).
* Procedural reharmonisation: the §3 chord table is a lookup, so picking a
  chord per sector at run time would re-colour the same melodic asset. Four
  chords is four sector moods from one 6-beat sample.
