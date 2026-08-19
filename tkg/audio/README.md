# Audio

Everything the game hears is generated here by pure Python — numpy and scipy
only, no DAW, no sample libraries. Eight music cues, twenty-four sound
effects, one synth engine shared between them, and one whistled five-note
phrase under all of it.

```bash
pip install numpy scipy soundfile
python3 build.py               # music + sfx -> ../assets/audio/
python3 build.py music
python3 build.py music burn    # one cue, for iterating on a score
python3 build.py sfx
```

About four minutes for the lot. `audio/out/` holds the WAV intermediates
(~2 GB) and is gitignored; only the encoded `assets/audio/` is committed.

## Files

| File | What it is |
|---|---|
| `synth.py` | The engine. Instruments, envelopes, filters, reverb, delay, the `Track` mixer, and the master bus. |
| `motif.py` | The source motif and every transformation the scores apply to it. No tempo, no octave, no dependencies — just the phrase. |
| `arrange.py` | Score for **"Slow Drift"** — main theme, F minor, 142 BPM, 72 bars. |
| `dread.py` | Score for **"Dead Sector"** — F Phrygian, 71 BPM, 40 bars. |
| `burn.py` | Score for **"Hard Burn"** — combat, F Aeolian, 142 BPM, 48 bars. |
| `warm.py` | Score for **"Warm Ship"** — station and refit, 71 BPM, 24 bars. |
| `boss.py` | Score for **"Poisoned Ground"** — boss, 71 BPM, 32 bars. |
| `shells.py` | Score for **"Nine Shells"** — star chart, whole-tone, 71 BPM, 40 bars. |
| `business.py` | Score for **"Ship's Business"** — events, sonata form, 142 BPM, 48 bars. |
| `home.py` | Score for **"Five Ways Home"** — title, theme and variations, 142 BPM, 48 bars. |
| `sfx.py` | The sound effect set. |
| `build.py` | Renders everything and encodes it into `../assets/audio/`. |
| `analyze.py` → `seg.py` → `refine.py` | Pitch analysis of the original whistled recording. Run in that order. This is what produced the F6/G6/A♭6 result the whole soundtrack is built on. |
| `THEME_NOTES.md`, `DREAD_NOTES.md`, `CUE_NOTES.md`, `DEVELOPMENT_NOTES.md` | The composition reasoning. Read these first. |

`.gdignore` keeps Godot out of this directory — it is source, not assets.

## The eight cues are one idea

The source motif is scale degrees **1–2–1–2–♭3**. Every cue in the game is
that phrase, and each does exactly one thing to it.

**Five recolour it in place.** Those three degrees belong to five different
modes, so the melody is never rewritten and only the harmony under it moves:

| Cue | The one thing | Form used |
|---|---|---|
| **Slow Drift** | states it, and recolours it under a rotating i–♭VI–iv–♭VII | `MOTIF`, `INVERT` |
| **Dead Sector** | flattens the 2nd: whole tone → semitone, Aeolian → Phrygian | `PHRYGIAN`, `TRITONE`, `SINK` |
| **Hard Burn** | halves its note values and makes the engine out of it | `diminish(MOTIF)` |
| **Warm Ship** | gives it the fifth it never reaches | `ANSWER` |
| **Poisoned Ground** | gives it that fifth a semitone flat | `MOTIF`, `transpose(MOTIF,-2)`, `FALSE_ANSWER` |

The motif never touches the fifth — no dominant, no leading tone, no cadence.
A question with no answer, which is what you want under a run that can end at
any moment. Two cues answer it, once each: the station with the C, the boss
with the B♮.

**Three develop it instead**, because five cues of one tonic is a lot of F.
These change key, which nothing before them did:

| Cue | The one thing | Centres |
|---|---|---|
| **Nine Shells** | transposes it around the minor-third cycle, each centre answered by its own pentatonic | F → A♭ → B → D → F |
| **Ship's Business** | runs it through a circle of fifths, and cadences | F m → A♭ → 8 keys → F m |
| **Five Ways Home** | varies it five ways, and turns it major | F m → **F major** → whole tone → F m |

Instrumenting `synth.hz` shows what the first five had cost: between them they
use **11 of the 12 pitch classes, everything except A♮** — the major third of
F, so the major mode was not constructible — and their only E♮ is one passing
note in "Dead Sector"'s collapse, so there was no dominant and nothing could
cadence. `DEVELOPMENT_NOTES.md` is about those two notes.

**Every cue is 142 BPM or exactly half at 71.** All **28 pairings** are a 1:1
or 2:1 bar lock, so any two can cut or crossfade without a tempo match.
Verified across all 28. "Hard Burn", "Warm Ship", "Ship's Business" and "Five
Ways Home" are the same length to the sample (81.126761 s). Changing key
turned out to cost nothing structurally; nobody had tried.

| | Bar | 8-bar phrase | Body | Stems |
|---|---|---|---|---|
| theme | 1.6901 s | 13.52 s | 121.690 s, 72 bars | 8 |
| dread | 3.3803 s | 27.04 s | 135.211 s, 40 bars | 9 |
| burn | 1.6901 s | 13.52 s | 81.127 s, 48 bars | 9 |
| warm | 3.3803 s | 27.04 s | 81.127 s, 24 bars | 8 |
| boss | 3.3803 s | 27.04 s | 108.169 s, 32 bars | 9 |
| shells | 3.3803 s | 27.04 s | 135.211 s, 40 bars | 6 |
| business | 1.6901 s | 13.52 s | 81.127 s, 48 bars | 6 |
| home | 1.6901 s | 13.52 s | 81.127 s, 48 bars | 6 |

The last three carry six stems and three rungs rather than nine and five. They
play on single-state screens where there is no fight to escalate, so a
five-rung ladder would be stems nothing ever climbs — and stems are the whole
download. `play_cue()` clamps to the table, so a short ladder is supported and
not a special case.

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

Loop seams measured on the encoded files: theme 0.020, dread 0.0001, warm
0.012, boss 0.021, shells 0.008, business 0.007, home 0.013 — every one at or
below its own interior sample-to-sample motion. Inaudible.

## Two measurements worth keeping

`DEVELOPMENT_NOTES.md` has the working, but both generalise:

* **Sensory roughness** (Plomp–Levelt / Sethares) over the detected partials,
  and **spectral flatness** as a noise proxy, computed per cue and per stem.
  They separate "this harmony grinds" from "this is hissing", which sound
  alike described and need opposite fixes. "Nine Shells" measured as the
  second *smoothest* cue in the set while being the noisiest by four times,
  and the fix was in the figuration and the form, not the chords.
* **A short-note scan.** Every pitched voice has an attack — `whistle()` 45 ms,
  `reed()` 30 ms, `strings()` 160 ms — and asking one for a note shorter than
  its own attack drops `env_adsr` into a degenerate branch and yields a click.
  Nothing errors. Instrumenting the voices and reporting any note under its
  floor catches it; `motif.turn()` and `motif.appoggiatura()` now also raise
  rather than emitting one.

"Hard Burn" is the exception and needs its own measurement. Its seam is 0.22 —
but the cue starts on a kick, and every interior downbeat in it steps by
0.25–0.36. The discontinuity at the loop point is *smaller* than the one on
every other bar line in the piece, because it is the same kick attack. Compare
a drum cue's seam against its own downbeats, not against mean sample motion.

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
| Music | 890 MB WAV | 79.5 MB Ogg Vorbis |
| SFX | — | 2.8 MB WAV |

Per cue: theme 17.4, dread 17.1, boss 16.7, burn 15.5, shells 15.1, warm 12.8,
business 10.5, home 8.0 MB. Streams are loaded lazily per cue in
`Audio._ensure_loaded()` and never freed, so a long session ends up holding
all eight.

**This is the one number in the project that is getting uncomfortable.**
`ogg()`'s `compression` is the knob, and it is measured rather than guessed —
re-encoding a dense sustained stem at each setting:

| compression | size | quantisation noise |
|---|---|---|
| **0.3** (current) | — | 29.6 dB below signal |
| 0.4 (libsndfile default) | −13% | 29.2 dB |
| 0.5 | −26% | 27.2 dB |
| 0.6 | −39% | 25.3 dB |

0.5 would bring the set to roughly 84 MB for 2.4 dB of noise floor that is
already 27 dB down. It is a one-line change and a full re-encode, and it has
not been made because it should be a deliberate call and not a side effect.

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
* Procedural reharmonisation: the §3 chord table is a lookup, so picking a
  chord per sector at run time would re-colour the same melodic asset. Four
  chords is four sector moods from one 6-beat sample.
* A victory cue. "Warm Ship" already owns the resolution, so winning currently
  gets the `victory` sting over the main theme at rung 0, which is thin for
  the end of a run. "Five Ways Home" variation II is the obvious seed — the
  one place the soundtrack is in a major key.
* **"Slow Drift" is now the odd one out.** It still plays on the sector screen
  and on game over, and it is the only cue left that neither develops the
  motif nor goes anywhere. It is also the original, so changing it is a
  decision about the game's identity rather than a music task.

Built since: **"Hard Burn"**, **"Warm Ship"**, **"Poisoned Ground"**
(`CUE_NOTES.md`), then **"Nine Shells"**, **"Ship's Business"** and **"Five
Ways Home"** (`DEVELOPMENT_NOTES.md`).
