# Audio

Everything the game hears is generated here by pure Python — numpy and scipy
only, no DAW. Eight music cues, twenty-four sound effects, one synth engine
shared between them, and one whistled five-note phrase under all of it.

Optionally the melodic instruments are **recorded** rather than synthesised.
Same scores, same stems, same bus — see "Recorded instruments" below.

```bash
pip install numpy scipy soundfile
python3 build.py               # music + sfx -> ../assets/audio/
python3 build.py music
python3 build.py music burn    # one cue, for iterating on a score
python3 build.py sfx

python3 fetch_samples.py       # once: ~1.1 GB of CC0 samples, gitignored
python3 build.py music --sampled     # recorded melodic instruments, synth kit
python3 build.py music --drums       # ...and a recorded kit too
python3 build.py music --lead=piano  # what plays the melody
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
| `core.py` | Score for **"The Last Warm Place"** — the core, both answers at once, 71 BPM, 40 bars. |
| `fauna.py` | Score for **"The Warm Things"** — megafauna, the question at whale size, 71 BPM, 32 bars. |
| `nofault.py` | Score for **"No Fault Found"** — the end of a run as a line item, 71 BPM, 16 bars. |
| `perpetuity.py` | Score for **"Perpetuity"** — organ passacaglia and fugue, 142 BPM, 96 bars. |
| `first_light.py` | Score for **"First Light"** — title/lobby, one 142 s arc, 71 BPM, 42 bars. The alternative to `home.py`, written from a measurement. |
| `sfx.py` | The sound effect set. |
| `sampler.py` | The recorded instrument set. Same doors as `synth.py`. |
| `fetch_samples.py` | Downloads the two CC0 libraries `sampler.py` plays. |
| `build.py` | Renders everything and encodes it into `../assets/audio/`. |
| `motif_audit.py` | How much of each cue is literally the motif. Pattern-matches the rendered note stream. |
| `analyze_track.py` | Takes a finished mix apart — arch, sections, brightness, width, onset density, key. What `analyze.py` is for a whistled line, this is for an arrangement. |
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


## Recorded instruments

`synth.py`'s instruments are all one shape — `f, dur, amp -> mono float array`
— and no score knows what is behind that door. So a set of recorded
instruments with the same signatures is a drop-in. That is `sampler.py`, and
it is why swapping the timbre of the whole soundtrack costs **zero score
edits**: the motif logic, the eight forms, the 142/71 bar lock and every one
of the 28 pairings are untouched, because none of them was ever about
waveforms.

    python3 fetch_samples.py                  # once
    python3 build.py music theme --sampled    # or --drums for the kit as well
    TK_VOICES=sampled python3 arrange.py      # one score, no encode

Samples come from two Versilian Studios libraries, both **CC0 1.0** — public
domain, commercial use, no attribution required, no royalties:

| | |
|---|---|
| [VSCO-2 CE](https://github.com/sgossner/VSCO-2-CE) | strings, flute, piccolo, harp, glockenspiel |
| [VCSL](https://github.com/sgossner/VCSL) | ocarina, folk harp, vibraphone, kit |

`fetch_samples.py` partial-clones both (`--filter=blob:none` plus a sparse
checkout), so the 8 GB the two repos hold costs 1.09 GB of WAV on disk. It is
gitignored and it is a **build input**: the game loads rendered stems and has
no idea a sample was involved.

### What is sampled, and what is deliberately not

| Sampled | |
|---|---|
| `whistle`, `whistle_bend` | whatever `TK_LEAD` selects — see below |
| `pad`, `strings` | violin / viola / cello sections, voiced by register |
| `pluck` | harp |
| `bell`, `glass` | glockenspiel, vibraphone |
| `hammer`, `reed` | folk harp, ocarina |
| `kick`, `snare`, `hat` | only under `--drums` |

| Still an oscillator | Why |
|---|---|
| `sub` | a sine with a controlled 2nd harmonic sits under a mix; a recorded contrabass in the same slot is mud plus room |
| `drone`, `blade`, `metal`, `cluster` | not imitating anything, so there is nothing to sample |
| `noise_swell`, `air`, `rev_swell`, `impact`, `heart` | texture and transition, where a recording would be a *worse* fit |

That split is the point rather than a stopping place. What samples buy is the
attack transient and the small per-note irregularity of a played instrument,
which is exactly the melodic material and exactly what synthesis is worst at.
The ship still sounds like a machine underneath because the machine layer
never changed.

The kit is behind its own flag for the same reason. `kick()` is a pitch-swept
sine that reads as a *machine*; a recorded bass drum reads as a room with a
drummer in it. Which of those a cue about a freighter wants is a judgement, so
both render.

### Which instrument plays the melody

    TK_LEAD=piano TK_VOICES=sampled python3 arrange.py
    python3 build.py music --lead=piano

`flute` (default, piccolo above 1100 Hz), `piano`, `ocarina`, `vibes`. This is
the one choice in `sampler.py` that is taste rather than measurement, so it is
a switch rather than a decision baked into the file.

The default is the flute because it is the closest thing to the whistled
recording the whole score is built on. It is also the brightest: at F6 a
piccolo sits at 1397 Hz with its formant right where the ear is most
sensitive, so over a two-minute loop it can read as **piercing** in a way
`synth.whistle` — a near-sine with a 4.5% second harmonic — never did. That
is not a bug in the patch, it is what a piccolo is.

`piano` is the useful opposite. It swaps a sustained tone for an attack and a
decay, which changes the phrasing as much as the timbre: the motif stops being
*held* and starts being *struck*, and the 1–2–1–2–♭3 reads as a figure rather
than as a line.

### Levels are measured, not guessed

`Patch._measure` normalises **per note**, and `sampler.GAIN` carries the
remaining few dB per patch. Both halves of that were arrived at the hard way.

The first version normalised each patch by one number, its median peak. That
put the theme's `arp` stem within 0.7 dB and the combat cue's — the same harp,
an octave higher — **9.0 dB hot**. The cause is in the library rather than in
the code: VSCO's harp peaks per note run

    E1 0.022   G1 0.003   B1 0.008   ...   A4 0.123   ...   F7 0.139

a 33 dB spread, non-monotonic, which is session drift and not something a harp
does. One constant cannot answer a curve, so every note is now scaled to its
own reference — the top velocity layer of that note, which leaves the layers'
relative dynamics intact because the inconsistency being corrected is *between*
notes. Peak for a struck patch, RMS for a sustained one: the loudness of a
plucked note is its attack and the loudness of a bowed one is its body.

With that in place the per-patch trims were measured by rendering `theme` and
`burn` both ways and comparing per-stem RMS. Where it landed:

| | worst stem | most stems |
|---|---|---|
| theme | arp +1.4 dB | within 0.9 dB |
| burn | arp +2.4 dB | within 0.6 dB |

`arp` is the one deliberate departure: `GAIN['harp']` carries **+3 dB over**
the value that matched `synth.pluck`, because the harp was wanted louder than
the Karplus-Strong it replaced. That is a taste decision sitting in a table of
measurements, so it is labelled as one in `sampler.GAIN`.

The stems that kept their oscillators — bass, sub, fx, perc, riff — sat within
0.2 dB, which is the check that nothing *else* moved. The residual 4 dB spread
on `arp` between the two cues is real and is not worth chasing: `synth.pluck`
is Karplus-Strong, whose level falls with frequency because the delay line
gets shorter, and burn plays the same figure an octave up. A harp does not do
that, so no single constant fits both.

This is worth doing properly rather than by ear. A stem 4 dB hot is not wrong
on its own — the bus peak-normalises, so the mix sounds fine — it is wrong
against the stem ladder `Audio.gd` climbs at runtime, and that only shows up
in the game.

The master bus invariant survives every variant. Printed stems sum back to the
mix at **5 LSB of 32768** for the sampled theme (6 for the synthesised one),
**7** for burn either way, and 5 for the piano lead. Same 16-bit rounding,
nothing else.

### What it costs

Measured on `theme` (72 bars) and `burn` (48):

| | synth | sampled |
|---|---|---|
| theme render | 14.5 s | **8.8 s** |
| burn render | 8.7 s | **5.9 s** |
| theme shipped stems, Ogg | 9.94 MB | **9.23 MB** |

Both go the way you would not guess. It renders *faster* because `pluck()` is
Karplus-Strong — a per-sample Python loop — and resampling is vectorised. It
*ships smaller* because a recorded flute has far less energy above 8 kHz than
three detuned saws, and Vorbis charges for exactly that. The download budget
is not a reason to decide this either way.

The build environment pays instead: 1.58 GB of WAV across fifteen
instruments, 2.5 GB on disk because git keeps its own copy of the blobs beside
the checkout. Adding an instrument to `fetch_samples.py` costs its own size
and nothing else.

### Looping, and why sustains need it

`_fit_sustain` crossfades a window out of a sample's steady state and repeats
it. This is not optional: sustains in both libraries run 2–4 seconds and the
pad in `arrange.py` holds two bars, which is 3.38 s at 142 BPM and 6.76 s at
71. The window is taken as a *fraction* of the sample rather than as a fixed
length, because 100 ms of crossfade against a 5 Hz vibrato is only half a
cycle and the loop point becomes audible as a pulse.

Checked rather than assumed: across the sampled `theme` stems, zero
sample-to-sample steps above 40× the median slope — so no loop clicks. (The
synthesised `arp` has 75, which is Karplus-Strong noise bursts and correct.)


## Two title cues, and why there are two

`home.py` and `first_light.py` are different answers to the same screen and
both are in the ladder. Only one can be wired to `menu` at a time —
`Audio.gd`'s `STATES` table, one line.

**"Five Ways Home"** is a theme and five variations: discrete eight-bar
blocks, each a self-contained way of looking at the motif, and deliberately
flat in dynamic because a variation set is an argument rather than a climb.

**"First Light"** is a single 142-second arc with one event in it, and it was
written from a measurement rather than from taste. The brief was "slow build
to grandiose exploratory", taken from a reference track; `analyze_track.py`
was pointed at that track so the brief could become numbers, because a
dB-per-phrase schedule is something you can write a score from and an
adjective is not. What it found, and what the score does with it:

| Measured on the reference | What the score does |
|---|---|
| +12.7 dB arch, peak at **76%**, then a hard release | `PHRASE_DB`, one number per eight-bar phrase; climax at bar 33 of 48 |
| centroid 917 → 1231 Hz | string cutoff climbs 1500 → 5200 |
| high band 12 → 17%, **low band flat at 30-36%** | the bass grows *with* the build instead of being left behind |
| onset density ×3.3 | nothing struck until bar 17, then 8ths, then 16ths |
| i(add9) ↔ iv, ~23 s cycle, **no dominant, nothing cadences** | i(add9) ↔ iv(add9), four bars each |

That last row is why this was worth writing rather than licensing: the
reference and this soundtrack had independently arrived at the same rule.
And its key is not a coincidence either — it is in B♭ minor, which is F
minor's **iv**, so the reference's home chord is this game's colour chord and
its harmonic world transposes here without being bent to fit.

Rendered, against the reference: arch 13.1 dB (target 12.7), peak at 69%
(76), centroid 765 → 1248 (917 → 1231), high band 9 → 19% (12 → 17).

**Two things were wrong in the first version and both are worth recording,
because both were mistakes the measurement had already ruled out.**

*The floor ran 27 seconds.* The reference's opening section is **8.3 s** —
it is in the table, it was measured before a note was written, and the score
still gave the floor a full eight-bar phrase because eight-bar phrases are
the habit. Two bars now, and the proportions live in `PHRASES` so the next
re-cut is one line rather than forty edited bar numbers.

*Every melodic event was the motif.* Fourteen call-sites, all fourteen the
motif, which is roughly twenty-five statements of the same five notes in two
and a half minutes — an ostinato, not a motif, and the cue had no tune for
it to be the motif *of*. There are three written lines now (`ASCENT`,
`REACH`, `GRAND`) and the motif appears twice plainly, at the entry and at
the end. The relationship that matters is that `GRAND` opens F–G–A, which is
the motif in major: the climax **grows out of** the motif instead of
restating it, and then goes where the motif cannot — the reach to C6, the
eight-beat F. This does not contradict "the eight cues are one idea"; that
rule is about what each cue does to the motif, and doing nothing but repeat
it is not one of the things.

**Stereo width is the one axis deliberately not matched.** The reference runs
0.76 side/mid; the eight cues already here run 0.14 to 0.57, because it is a
commercial master with a widener across the bus and these are not. Matching
it would have made the title screen the one cue that does not sound like it
comes from the same room as the rest. `first_light` lands at 0.39, wider than
six of the eight.

No melodic material was taken. The tune is the same five notes as everything
else, because a title cue that opened with somebody else's phrase would be
the one screen in the game that does not sound like the game.


## How much of each cue is the motif

`python3 motif_audit.py`. It runs each score with `Track.add` instrumented,
recovers the real note stream per stem, and slides the motif's interval
signature over the pitch set at each beat. Transposition, octave, unison
doubling, augmentation and diminution are all free by construction, so what
it counts is the phrase however it is dressed.

Two numbers, because counting note **onsets** is unfair to slow writing — a
bowed line that occupies sixteen bars scores the same as six short notes. The
time-weighted column counts seconds sounded, which is what a listener gets.

| cue | onsets | motif | secs | motif | |
|---|---|---|---|---|---|
| boss | 210 | 86% | 287 | **44%** | quotation is the whole cue; the new bowed climb is the counterweight |
| theme | 339 | 68% | 263 | **47%** | was 83% / 76% on shipped stems |
| shells | 194 | 62% | 206 | 55% | harp is 70 beats of its own |
| burn | 176 | 57% | 116 | 46% | by design: the engine *is* the motif |
| home | 223 | 54% | 160 | 45% | has THEME, ORNAMENTED, TURN_FIG |
| warm | 122 | 49% | 236 | **24%** | was 65% |
| business | 294 | 43% | 98 | 42% | sonata material |
| dread | 120 | 25% | 207 | 18% | mostly texture |
| first_light | 139 | 7% | 268 | 5% | two statements, three written lines |

**This is a measurement, not a verdict.** "Every cue in this game is that
phrase" is the design, and for `burn` — "halves its note values and makes the
engine out of it" — 57% is the cue working. What the table is for is the
distinction between a cue *built on* the motif and a cue with no other
melodic material at all, which is easy to reach by accident and hard to hear
until somebody sits with it.

### The three rewrites

`theme`, `boss` and `warm` had no melodic material that was not the motif.
An earlier pass at this added a counter-subject to each and left the motif
statements where they were, which moved the numbers and did not fix the
problem: 46 statements in two minutes is still one every 2.7 seconds, and a
second voice underneath does not change what you are hearing on top. So each
of the three has a **tune** now and the motif does what a motif does.

| | statements before | after |
|---|---|---|
| theme | 46 | **8** |
| boss | 36 | **21** |
| warm | 12 | **5** |

**"Slow Drift" — `THEME_A` / `THEME_B`.** A sixteen-bar period over two turns
of the i–♭VI–iv–♭VII cycle. The antecedent ends open on the ♭VII; the
consequent goes higher, touches D♭6 once — the only time anything in the cue
reaches it — and falls to an F over the E♭ chord, so it lands on the tonic
*pitch* without a tonic *chord* under it and finishes without closing. The
canon in A′ now runs on the period instead of on five notes, which is
something a canon can actually do something with. The motif opens the piece,
tags the end of A and of B, and closes it.

**"Warm Ship" — `WARM_A/B/C`.** One tune stated three times over the cycle:
low and plain, then a fourth higher with the intervals opened out, then
climbing into the answer. The motif keeps the far-off statement in the empty
room at the top and the answer at the end.

**"Poisoned Ground" — `DESCENT`.** The cue's two real ideas — the untouched
quotation at the top and the ♭5 at the bottom — were buried under the middle
sixteen bars restating them. The middle has its own line now, built from the
cue's pitch world (F Phrygian plus the tritone): it opens on the semitone the
whole cue turns on, touches a D♭6 once, and comes back down through the B♮,
so the ♭5 is in the melody sixteen bars before `FALSE_ANSWER` lands on it.
The quotation is every other bar rather than every bar — four statements say
what eight were saying, and leave the pedal audible, which is the half of
that section actually doing the work.

### A correction about "rulings"

An earlier version of this section justified these cues' melodic writing by
appeal to rules — "no A♮", "no E♮", "the melody is never rewritten". **Those
are not rulings.** `CLAUDE.md`'s "do not silently reverse" table contains no
audio entries at all. The A♮ line is a sentence further up this file
*describing which pitch classes five cues happened to use*; it was a
measurement, and treating it as a constraint meant designing around an
accident.

What survives on merit rather than authority, and is kept by choice:

* **The modal colour.** These cues stay in Aeolian/Phrygian because that is
  what makes them sound like this game rather than like film music, not
  because a document said so. A raised seventh would drag them toward a
  cadence they do not want.
* **Warm Ship holding its C.** The cue's one event is the phrase finally
  getting its fifth. A melody that had already sung four of them arrives
  there with nothing to give. That is a musical argument and it is checkable:
  the first C in any melodic voice is in bar 23.
* **The bar lock.** 142 or exactly half at 71. That one *is* structural —
  `Audio.gd` crossfades any two cues.

Verified after: lengths identical to the sample; peaks unchanged at 0.89 /
0.84 / 0.88; RMS within 0.5 dB of the tiering in `CUE_NOTES.md`; stems sum to
mix within 7 LSB on both backends.

### The full sweep

| cue | onsets | motif | secs | motif | statements |
|---|---|---|---|---|---|
| burn | 193 | 3% | 120 | 2% | 20 → 2 |
| boss | 146 | 72% | 279 | 30% | 36 → 21 |
| home | 217 | 30% | 169 | 21% | 24 → 13 |
| dread | 97 | 15% | 226 | 8% | 14 → 5 |
| warm | 113 | 22% | 305 | 13% | 12 → 5 |
| theme | 224 | 18% | 238 | 11% | 46 → 8 |
| business | 279 | 16% | 118 | 15% | 25 → 9 |
| shells | 173 | 14% | 306 | 14% | 24 → 5 |
| first_light | 139 | 7% | 268 | 5% | 2 |

**"Nine Shells" — `SEARCH` / `LANDED`, written in scale DEGREES.** The
whole-tone and pentatonic collections on any root share their first three
degrees (on F, both start F G A) and disagree only at the fourth and fifth,
by a semitone each. So one degree sequence realised against whichever
collection the ground is currently in comes out as two tunes that are
recognisably the same tune — floating or landed, from no edit at all. That is
what the piece already did to the motif with `MOTIF` and `MAGGIORE`, and it
is a better argument for a melody than for five notes, because a melody has
somewhere to put the disagreement. `SEARCH` rises through six bars and ends
an octave up unresolved; `LANDED` descends four bars onto the root.

**"Ship's Business" — `SECOND_SUBJ`.** The second subject used to be
`MAGGIORE`: the first subject with its ♭3 raised. The old comment called that
"either a very economical piece of writing or the only honest thing to do
with a five-note tune"; it is neither, it is a sonata with one theme in it,
and the form's whole point is two subjects that behave differently so the
development has an argument to have. The new one contrasts on every axis the
first has — it leaps a sixth where `ANTE` rocks between two notes, moves in
dotted halves against quarters, spans a tenth against a fifth, and descends
to its own root instead of circling. The circle-of-fifths transition carries
a real four-note sequence now instead of eight consecutive motif statements,
which modulates just as correctly and actually says something.

**"Five Ways Home" — the variations vary the THEME.** Every variation after
the first worked on the five notes alone — `MAGGIORE` at F5, F6 and F4, the
motif in canon with itself, the motif augmented — while `THEME`, defined
directly above them, is a thirty-two-beat period with a half cadence and a
PAC in it. A set of variations on a five-note head is not a set of
variations. `MAJOR_ANTE` raises every ♭3 and ♭6 of the antecedent, which is
what *maggiore* actually means and is a good deal more than one note; the
canon imitates the antecedent instead of the head; and the chorale augments
it, which fills its eight bars exactly rather than being the head at half
speed with silence after it.

**"Hard Burn" — a new cell, and `HOOK`.** This was the one I argued should
be left alone, on the grounds that its riff *is* `diminish(MOTIF, 2)` so
removing the motif removes the cue. That was wrong, and the mistake is worth
naming: what this cue actually is, is **the 3-beat cell against 4/4** —
locked to the bar it leaves one beat for a tail, let go it walks and
realigns twice in eight bars. That is a *rhythmic* idea. The pitches running
through it were incidental, and having them be the motif meant the engine and
the tune were the same five notes. The cell keeps its rhythm to the sample
and has its own pitches now: up a minor third, down to the ♭7, back, then a
leap to the fifth — angular, and nothing like the motif's rocking 1–2. The
1-beat tail and the B♮ on alternate bars are untouched, because that is what
puts the dread cue's tritone inside the combat cue before you meet a boss.
`HOOK` is a real top line, syncopated against a riff already fighting the
barline, climbing chromatically through B♮ into a C. 20 statements → 2.

**"Dead Sector" — `LAMENT`.** This cue audited *lowest* of the eight and was
still saturated by ear, which is the clearest case in the set that the count
was never the point: every melodic note in it was the motif, and everything
else is drone, cluster, bowed pedal and heartbeat, so there was nothing for
the phrase to be heard against. `LAMENT` is the oldest answer there is — F
Phrygian's descending tetrachord, F E♭ D♭ C, which is the one line this mode
wants to make, because the ♭2 is what makes Phrygian sound like Phrygian and
a descent through it lands on the dominant degree without ever being a
dominant. One note every two bars, slower than anything else in the cue, so
it reads as the ground giving way rather than as a tune. It transposes down
at each section and by the collapse it is an octave below where it started
and has never come back up; in the tritone section its own descent lands on
the B♮ the cue is named for. 14 statements → 5.

`boss` stays highest by onsets at 72% and that is the cue working: it is
built on quoting the theme untouched while the ground rots under it. By time
it is 30%, because the bowed line added underneath occupies the second half.

### Two bugs this tool had first

Both are recorded because both produced confident, wrong numbers.

*Every voice in one bucket.* Tracks were tagged with their stem name after
the score finished running, so every note had already been filed under a
placeholder and all six voices shared one stream — "five consecutive notes"
meant five notes interleaved from different instruments. Keyed on object
identity now, which is available during the run.

*Flat consecutive matching.* `burn.py` adds its motif to the same track twice
at two pans, so every beat carries the same pitch twice and the offsets read
`0 0 2 2 …`. It reported **burn at 0% motif** — the one cue that is nothing
but the motif. Matching is over the pitch set per beat now, so unisons,
octave doublings and an accompanying line all stop mattering.


## The popping

Reported by ear as "popping on quarter notes, boss in particular", and it was
neither quarter notes nor anything to do with the notes.

`drone()` swept its filter by chopping the signal into 0.25 s blocks and
calling `lfilter` on each one at a new cutoff. `lfilter` starts from **zero
state** on every call, so every block opened with the filter's own startup
transient and every boundary was a step discontinuity — a pop every 0.25 s,
4 Hz, dead regular, through every drone in the game. It read as rhythmic
because it *was* rhythmic, which is why it sounded like it was on the notes.

Measured on the boss cue, which is mostly drone: **382 discontinuities in the
sub stem and 207 in the drone stem, both to zero.** `dread` had it too.

`sweep_lp()` replaces it. The filter state carries across blocks, which is
what removes the step; the cutoff is quantised into 64 bands so coefficients
change only when they meaningfully differ; and the blocks are the runs
between band changes rather than a fixed length, so a slow sweep barely
re-designs at all.

A second, simpler fault came out of the same hunt. Six voices ended at
between 2% and 22% of their own peak — `metal` 4.4%, `hammer` 5.0%, `impact`
5.8%, `rev_swell` 1.9%, `noise_swell` 22% — which is a step to zero and a
click. `fade_tail()` puts a 12 ms cosine on the end of each. (Named
`fade_tail` and not `tail` because `impact()` already has a local called
`tail`, and shadowing it would have been silent.)

### How it was found, and how the detector was wrong first

The obvious detector — flag any sample-to-sample step far above the median —
is useless here: it reports thousands of hits on every noise bed and none on
a low-frequency drone, because a step that is large for a 40 Hz sine is small
in absolute terms. It found 3,925 "pops" in the boss `fx` stem, which is
filtered noise and correct, and nothing in `sub`, which was the actual fault.

What works is isolated outliers in the **second** derivative, measured
against the local level rather than a global one. Noise has a uniformly high
second derivative and produces no outliers; a discontinuity produces a spike
25× the neighbourhood.

The remaining flags after the fix are all note attacks, which are supposed to
be sharp — checked rather than assumed: every one of boss's 38 and dread's 48
sits on a `heart()` thump onset, including the second thump at beat 2.

Verified after: peaks unchanged on all five tiered cues, RMS within 0.8 dB
(dread moved most, +0.8, because a filter that now actually sweeps passes
more energy than one that kept restarting), stems sum to mix within 7 LSB on
both backends.


## The strings were enormous

Reported as "an entire orchestra playing all at once", and it was three
separate faults compounding, none of which the earlier per-cue calibration
could have caught because they cancel differently in every cue.

**One gain for two different doors.** `pad()` and `strings()` are separate
functions in `synth.py` at separate levels, and `sampler.py` mapped both to
the same sampled voice with one gain — calibrated on `pad()`, in `theme`.
Measured against the synthesised render, the strings-bearing stem came out
**business +10.4 dB, home +5.6, first_light +3.3, shells +3.0**. In business
that put the strings stem within 1.2 dB of the entire mix: the stem *was* the
mix. They have separate gains now, 0.28 and 0.20.

**Velocity was being derived from gain.** `_voiced()` hands each voice of a
chord `amp / len(freqs)`, and `Patch._source` used that same number to pick
the velocity layer — so adding voices to a chord silently moved every one of
them onto a softer, differently-recorded sample. A two-note chord measured
**12 dB louder than a four-note chord at the same written amp**, and a score
got quieter by adding notes to it. Velocity is now passed separately from
gain: the gain still divides, the velocity does not.

**The sections had no taper.** `_measure` normalises each patch to its own
level, which is right within a patch and wrong between three of them. VSCO's
violin samples were recorded quieter, so normalising landed the violins about
12 dB hot against the cellos and every chord came out top-heavy — which is
most of what "an entire orchestra at once" actually is. `SECTIONS` carries a
balance now: cello 1.00, viola 0.72, violin 0.42.

Every strings/pad stem is within 2.4 dB of its synthesised counterpart
afterwards, and all of them slightly under rather than over.

**Two earlier workarounds turned out to be symptoms of this** and are gone.
`home` and `first_light` had their bus ceilings dropped to 0.74 and 0.78
because their sampled strings stem clipped past 1.0 and broke the
stems-sum-to-mix property. With the strings at a sane level neither clips —
loudest stem 0.67 and 0.67 — so both are back at 0.87 and 0.86. A workaround
that stops being necessary is evidence the diagnosis under it was wrong.


## Words for directing this

Written down because "not very space-y" was a completely correct note that
took a while to act on. These are the axes that actually move, roughly in
order of how much difference they make.

**Timbre — what is making the sound.** The biggest lever and the one that
was wrong. A flute is a column of air driven by a body: breath transient on
every note, strong fundamental, nearly pure harmonic series above it,
vibrato. All of that reads as *someone playing*. Rubbed glass, bowed metal
and struck tubes have **inharmonic** partials — overtones that are not whole
multiples of the fundamental — which is most of what "space" means as a
sound. Say **"less breath"**, **"inharmonic"**, or just **"that sounds like a
person playing an instrument"**.

**Attack — how a note starts.** A flute speaks instantly; a wine glass swells
in over a second. Fast attack reads as urgent and human, slow attack as
distant and inevitable. Say **"slower attack"** or **"I can hear it start"**.

**Register, and the gap in the middle.** Where things sit. Big spread with a
hollow middle — very low and very high, nothing in between — reads as
enormous and empty; everything crowded into the vocal range reads as
intimate. Say **"hollow out the middle"** or **"it's all in one register"**.

**Density.** How many things are happening at once. This is what
"overwhelming" usually means, and it is separate from volume. Say **"too many
voices"** or **"thin it out"**.

**Vibrato and detune.** Vibrato is a body. Two copies of the same note
slightly apart is **beating** or **chorus**, which is a machine. Say **"take
the vibrato off"**.

**Reverb.** Long tails and a gap before the reflections (**pre-delay**) mean
far away and large. Dry means close. Say **"further away"** or **"too wet"**.

**Harmonic rhythm.** How often the chord changes — not how fast the notes
are. Slow harmonic rhythm under fast notes is what makes something feel like
it is drifting rather than marching. Say **"the chords are moving too fast"**.

The switch for the first two is `TK_LEAD`: `glass` (default, rubbed wine
glasses), `chimes`, `flute`, `piano`, `ocarina`, `vibes`. Everything else is
per-cue and lives in the scores.

There is no music-theory skill in the registry, incidentally — searching it
returns AI music *generation* tools and, for "orchestration", software
orchestration. This section is the substitute.


## Filenames are a name; the SFZ is the data

A note came back that one sustained tone in `theme` sounded flat. It was:
the score asks for C5 (midi 72) and the render measured **midi 84.56** — an
octave and 56 cents sharp, which sits between C6 and C♯6.

The first diagnosis was that VCSL's wine glasses are mislabelled. Measured,
the partial at the labelled pitch carries no energy and the one an octave up
carries all of it, and the four glasses are individually out by +29, −10,
+56 and +4 cents. That much is true, and it was nearly the basis of a
pull request against somebody else's library.

**It would have been wrong.** VCSL ships `.sfz` mappings on its `sfz` branch,
and they already say all of this:

    glass1_D#4 -> pitch_keycenter=75  tune=-28      (D♯5, 28 cents sharp)
    glass2_F#4 -> pitch_keycenter=78  tune=+10
    glass3_A#4 -> pitch_keycenter=82  tune=-53
    glass4_D5  -> pitch_keycenter=86  tune=-5

Against an independent FFT of the recordings, those agree to within **3
cents on all four**. Nothing is mislabelled. The filenames are names — the
glass's number and roughly where it sits — and the SFZ is the library's
actual statement of what the recording sounds. This loader was reading the
decorative half and ignoring the authoritative half.

So `sfz_pitch()` parses them and `Patch._scan` prefers them over any pitch
guessed from a filename. That is **4,177 regions** across every VCSL
instrument, not just the glasses, and it makes note keys fractional — a
sample can sit at midi 82.53 and be resampled from there. Re-measured
afterwards, through the passage that started this: written C5 D♭5 C5 A♭4,
rendered +2, +1, +2, +1 cents.

VSCO-2 CE ships no SFZ in its repository, so those patches still key off the
filename, which for them has been correct all along.

`detect_hz()` stays in the file as an independent check rather than as the
mechanism — it is what caught the problem, and it is what confirmed the SFZ
was right.



## "Perpetuity" — the reading room

The word is Verity's: *"We repair what we sold you. Forever."* This is the
institutions' own music and its home is the archive reading room, where the
player reads their paperwork.

The first version was a passacaglia-and-fugue for full organ — an experiment
in registration that came out busy and over the top, which is everything an
institution is not. An institution is *patient*. The rewrite keeps the one
idea that was right — a ground bass, because a line that repeats forever
without needing anyone is what perpetuity is — and discards the fugue, the
stretto and the plenum. The organ remains as one quiet layer, the bed under
everything; the descant, strings and bells are the album's own palette
passing through the file room.

The cast, at home: THE FIFTH is structural rather than planted — the ground
cadences onto the bare open fifth at the end of every statement, six
receipts, and the piece ends with that interval *held*, unresolved, the loop
wrapping out of it back into the ground. No Picardy. Perpetuity does not
end; it continues. THE LOOP ticks from the third statement on. THE QUESTION
passes exactly once, on the reed — a person in the file, processed without
comment. THE LAMENT passes once in the strings, late: the file has deaths in
it, and they are filed too.

Measured: −19.3 → −15.5 dBFS across its span — it breathes rather than
builds, and sits in the tiering between the station and the deep, which is
where a reading room belongs.

## Words for directing this

Written down because "not very space-y" was a completely correct note that
took a while to act on. These are the axes that actually move, roughly in
order of how much difference they make.

**Timbre — what is making the sound.** The biggest lever and the one that
was wrong. A flute is a column of air driven by a body: breath transient on
every note, strong fundamental, nearly pure harmonic series above it,
vibrato. All of that reads as *someone playing*. Rubbed glass, bowed metal
and struck tubes have **inharmonic** partials — overtones that are not whole
multiples of the fundamental — which is most of what "space" means as a
sound. Say **"less breath"**, **"inharmonic"**, or just **"that sounds like a
person playing an instrument"**.

**Attack — how a note starts.** A flute speaks instantly; a wine glass swells
in over a second. Fast attack reads as urgent and human, slow attack as
distant and inevitable. Say **"slower attack"** or **"I can hear it start"**.

**Register, and the gap in the middle.** Where things sit. Big spread with a
hollow middle — very low and very high, nothing in between — reads as
enormous and empty; everything crowded into the vocal range reads as
intimate. Say **"hollow out the middle"** or **"it's all in one register"**.

**Density.** How many things are happening at once. This is what
"overwhelming" usually means, and it is separate from volume. Say **"too many
voices"** or **"thin it out"**.

**Vibrato and detune.** Vibrato is a body. Two copies of the same note
slightly apart is **beating** or **chorus**, which is a machine. Say **"take
the vibrato off"**.

**Reverb.** Long tails and a gap before the reflections (**pre-delay**) mean
far away and large. Dry means close. Say **"further away"** or **"too wet"**.

**Harmonic rhythm.** How often the chord changes — not how fast the notes
are. Slow harmonic rhythm under fast notes is what makes something feel like
it is drifting rather than marching. Say **"the chords are moving too fast"**.

The switch for the first two is `TK_LEAD`: `glass` (default, rubbed wine
glasses), `chimes`, `flute`, `piano`, `ocarina`, `vibes`. Everything else is
per-cue and lives in the scores.

There is no music-theory skill in the registry, incidentally — searching it
returns AI music *generation* tools and, for "orchestration", software
orchestration. This section is the substitute.


## Filenames are a name; the SFZ is the data

A note came back that one sustained tone in `theme` sounded flat. It was:
the score asks for C5 (midi 72) and the render measured **midi 84.56** — an
octave and 56 cents sharp, which sits between C6 and C♯6.

The first diagnosis was that VCSL's wine glasses are mislabelled. Measured,
the partial at the labelled pitch carries no energy and the one an octave up
carries all of it, and the four glasses are individually out by +29, −10,
+56 and +4 cents. That much is true, and it was nearly the basis of a
pull request against somebody else's library.

**It would have been wrong.** VCSL ships `.sfz` mappings on its `sfz` branch,
and they already say all of this:

    glass1_D#4 -> pitch_keycenter=75  tune=-28      (D♯5, 28 cents sharp)
    glass2_F#4 -> pitch_keycenter=78  tune=+10
    glass3_A#4 -> pitch_keycenter=82  tune=-53
    glass4_D5  -> pitch_keycenter=86  tune=-5

Against an independent FFT of the recordings, those agree to within **3
cents on all four**. Nothing is mislabelled. The filenames are names — the
glass's number and roughly where it sits — and the SFZ is the library's
actual statement of what the recording sounds. This loader was reading the
decorative half and ignoring the authoritative half.

So `sfz_pitch()` parses them and `Patch._scan` prefers them over any pitch
guessed from a filename. That is **4,177 regions** across every VCSL
instrument, not just the glasses, and it makes note keys fractional — a
sample can sit at midi 82.53 and be resampled from there. Re-measured
afterwards, through the passage that started this: written C5 D♭5 C5 A♭4,
rendered +2, +1, +2, +1 cents.

VSCO-2 CE ships no SFZ in its repository, so those patches still key off the
filename, which for them has been correct all along.

`detect_hz()` stays in the file as an independent check rather than as the
mechanism — it is what caught the problem, and it is what confirmed the SFZ
was right.



## "Perpetuity" — the organ piece

Grand, complicated and satisfying are three requests, and organ music
answered all three a long time ago. 142 BPM, F minor to F major, 96 bars.

**Grand is registration.** A pipe organ has one pipe per note per rank, and a
rank is named for the length of its longest pipe: 8′ sounds the written note,
4′ an octave above, 2′ two octaves, **2 2/3′ an octave and a fifth**, 16′ an
octave below. Drawing more stops does not really make it louder — it turns
every note into a chord of its own overtones, which is why full organ sounds
enormous rather than merely loud. `reg()` plays a line through a stop list
and the piece is largely a plan for which stops are drawn when: one rank at
the start, `PRINCIPAL` (8′+4′) for the first variations, `PLENUM` (with the
twelfth and the fifteenth) at the seventh, `FULL` at the stretto. Nothing
else in this soundtrack can get big this way, because nothing else in it is
an instrument that works like this.

**Satisfying is a ground bass.** A passacaglia states an eight-bar bass and
never stops playing it — seven times here. The satisfaction is structural and
it is cheap: the ear learns the ground in one hearing, so every variation
afterwards is heard *against* something it already knows, and novelty and
familiarity arrive together instead of competing. Variation VI does the
oldest trick in the form and puts the ground in the treble, so the ear
discovers it is still the same eight bars. The ground opens with the game's
motif in the bass, which is the one place in the soundtrack the phrase is
load-bearing rather than decorative.

**Complicated is a fugue**, and specifically complicated rather than busy.
One subject entering in four voices a fifth apart — alto, soprano, tenor,
pedal, so the lowest arrives last and the texture is only complete when it
does — each continuing into a fixed **countersubject** written in
complementary rhythm: it moves in eighths exactly where the subject holds
half notes. That is the whole craft of a countersubject and it is why two
lines can be heard at once. Then two **episodes**, the subject's head
sequenced down a step every two bars, which is how a fugue modulates without
saying anything new. Then **stretto**: the entries stop waiting their turn
and overlap two bars apart instead of four, so each arrives while the last is
still unfinished. That is what makes the end of a fugue feel like an argument
being won.

The last eight bars are a **tonic pedal** — the bass takes F and never moves
again, which is the one device that lets harmony climb without the bass
agreeing, so the coda can build without modulating. It ends on a **tierce de
Picardie**, a minor-key piece closing on a major triad: the same
F-minor-turns-major hinge "Five Ways Home" and "First Light" use, spent here
with every rank drawn.

Measured: the arc runs −23.9 dB at the ground to −16.1 at the coda, and
unlike a film-score arch it peaks at the very end and stays there, which is
what this form is for. The dip at 1:08 is variation VI clearing the way for
the plenum.


## The album

The soundtrack has two characters and always did; naming them is what turned
a set of cues into a record. **The whistle is the person** — the source
phrase is a field recording of a human being, and every melody is that
person's five notes. **The organ is the institutions** — "Perpetuity" is
Verity's own warranty word. The plot between them is carried by pitch:

| | | |
|---|---|---|
| THE QUESTION | `MOTIF` | five notes, never touches the fifth. What is the heat for. |
| THE FIFTH | `FIFTH` | the bare interval the question never reaches, owned vertically by the institutions. Struck, never sung, never given a third. |
| THE LAMENT | `LAMENT` | F–E♭–D♭–C. The cold's line — and it *ends on C*: the answer, reached by falling. |
| THE LOOP | `loop_beats()` | a cell repeating on a cycle that does not fit the bar. The transponder loop; the schedule that outlives everyone. Planted, never the subject. |

All four live in `motif.py` so every score draws them from one place. The
question is answered exactly three times in the game — "Warm Ship" gives it
the true C in the one safe place, "Poisoned Ground" the false B♮, and "No
Fault Found" lets the lament fall onto C at the end of a run — and asked one
final time at the core, where it cannot finish.

The three album pieces:

**"The Last Warm Place"** (`core.py`) — the finale, built the way a game
finale is built: a bed that never stops, an ostinato with a pulse, and
layers that enter and leave on eight-bar blocks — change one thing per
block, and an exit is as much an event as an entrance. Its theme is its own
and does the one thing no other melody in the game may: it reaches both
answers. The identical approach gesture — the motif's rise used as a
springboard, not a quotation — lands first on C6, then on B5, and the phrase
hangs on the 2. The answers also arrive harmonically in their own voices
(glass and bowed, Warm Ship's and the boss's), so melody and harmony
disagree about the same two notes at once. The FIFTH is absent on purpose;
the LOOP runs throughout and leaves last.

**"The Warm Things"** (`fauna.py`) — owns a real song, opening on a
minor-sixth leap: a whale's interval, and a gesture the five-note question
cannot make. Layers: water pad, harp arpeggios, the song on reed, doubled
8va on whistle at the full block. The motif appears exactly once and it is
the point when it does — midway, the whale sings the player's tune at whale
size *underneath* the song, and you hear your own phrase inside something
enormous. The LOOP fades in for the last four bars: a schedule, arriving.

**"No Fault Found"** (`nofault.py`) — a piece now, not a gesture: 24 bars.
Its melody, THE FILING, uses the lament as a seed rather than as content —
the four-note fall sequenced from three starting heights, a compound descent
that takes twelve bars to reach the C the question never touched. Bell toll
every three beats (the LOOP as a funeral device), chorale strings, the
descent doubled an octave down, the question filed once on the reed, the
FIFTH stamped twice, and the toll cut mid-cell at the end. Ends on business.

One plant in an existing cue: "Ship's Business" now opens each large section
with the FIFTH struck once, like a letterhead — it is the contracts cue, and
the paperwork is theirs even when the business is yours. "Dead Sector"
already spoke the language: its lament *is* `LAMENT` augmented, and its
7-beat ostinato is a LOOP.

Album order, as a run: First Light → Slow Drift → Warm Ship → Nine Shells →
Ship's Business → Hard Burn → Dead Sector → Poisoned Ground → Perpetuity →
The Warm Things → The Last Warm Place → No Fault Found → Five Ways Home.

Wiring: `nofault` is the natural `gameover` cue (currently `theme` rung 0);
`fauna` wants `Combat.pacify` or a fauna encounter; `core` waits for the core
arrival; `perpetuity` belongs in the archive reading room, which currently
sets no music state. All four are rendered and registered in `build.py`;
none is wired into `Audio.gd` yet.


## The album pass over the existing cues

Every track owns a theme now; the motif is connective tissue. What changed,
and what deliberately did not:

**"Warm Ship" — rewritten.** It was one tune restated three times; it is an
arrangement now, with THE HEARTH as its song — written around a hole: **no C
anywhere in the melody**, verified (first C in any voice is bar 24.2, the
answer itself). The institutions appear exactly once: a single soft FIFTH
under bar 9, the berth clamp taking hold — you are docked at *their*
station, and the room is warm because somebody's invoice says it may be.
Stem names and the 24-bar length were load-bearing (the ladder and the
bar-lock with "Hard Burn") and are unchanged.

**"Poisoned Ground" — strengthened, not rewritten.** Quotation is the piece;
the four documented devices stand. The heart is now a backbone that builds
the way a kit would — one thump per two bars in the descent, doubled in the
stretto, doubled again with an offbeat under the false answer, so the pulse
races as the fight ends. DESCENT's peaks ring on metal; DESCENT_LO's are
doubled an octave down on the bowed voice.

**"Slow Drift" — one plant.** THE LOOP ticks through the emptied C bridge,
faint and far right: the one place in normal play a player meets the
transponder before the deep cues, planted the way the lore plants constants
— in the corner of the document, never the subject.

**"Dead Sector" — recognised and joined.** Its 7-beat ostinato always *was*
the LOOP; the header now says so, and the album's actual tick (same pitch,
same three-beat indifference as everywhere else) sounds briefly in the
opening bars — a schedule still running in an empty system, which is the
lore's own image for this cue.

**Left alone, with reasons:** "Hard Burn" (CELL + HOOK, rung-driven
layering, 2% motif), "Nine Shells" (SEARCH/LANDED written in scale degrees),
"Ship's Business" (two real subjects and the letterhead stamps), "Five Ways
Home" (the variations vary a real theme), "First Light" (the PHRASES table
is already the layer map). Each owns its material; a pass over them would be
churn.

Verified after: all four reworked cues at their documented peaks, RMS within
1 dB of the tiering (warm's synth render sits 1 dB warm; the sampled backend
— the one that ships — is on the nose at −13.4), stems sum within 7 LSB on
both backends, and the two flags the pop detector raises on dread sit on
heart-thump onsets to within 4 ms, which is an attack doing its job.


## The full cutover

The hybrid — recorded melody over synthesised texture — was the original
design and it stopped earning its keep: a synthesised texture next to a
recorded instrument reads as a different room. Every remaining oscillator
voice now has a recorded door, and `TK_VOICES=sampled` swaps the full set —
melodic, texture and kit.

| door | was | is now |
|---|---|---|
| `sub` | sine + harmonics | contrabass section, octave-doubled |
| `drone` | detuned saws through a swept filter | contrabass + cello tremolo — a tremolo section *is* a slow boil and needs no filter to say so |
| `bowed` | sawtooth + bow noise | contrabass below C3, cello tremolo above |
| `blade` | driven saw through tanh | cello spiccato, octave-doubled — a section digging in *is* the aggression; the distortion stage is retired |
| `cluster` | saw stack | viola tremolo, minor seconds |
| `metal` | inharmonic sines | a bowed suspended cymbal |
| `impact` | swept sine + noise | a gong |
| `heart` | pitch-swept sine thumps | two soft bass-drum strokes |
| `air` | filtered noise | an ocean drum |
| `noise_swell` / `rev_swell` | shaped noise | suspended-cymbal crescendo, forward and reversed |
| kit | synthesised | bass drum, snare, hi-hat (on by default now) |

Calibration was measured per door against the oscillator's RMS at a
representative call, and the drone exposed the velocity-layer trap a third
time: scaling `amp` changed which *recording* played, so level was a
nonlinear function of amp — down 9 dB at one scale, up 9 at another. Texture
doors now pin `vel=0.5` and scale gain only. Everything lands within ~1 dB.

One knock-on: boss's `fx` stem (now gong + reversed cymbal) peaked at 1.021,
which clips on write and breaks the stem sum — the guard caught it, and the
bus ceiling moved 0.88 → 0.85, the only lever that works on a
peak-normalised bus.

The sampled build is the soundtrack now. The oscillators remain in
`synth.py` — renderable with no env var set — as the reference
implementation every door is calibrated against, which is also what keeps
the calibration checkable.

"Perpetuity" also lost its second organ manual in this pass: the organ
carries the ground throughout — it is the institution and it holds the main
line — but the breathing is strings now, the file room works in harp
eighths, and the pages turn in glass and bell. One instrument being the
whole band was the original sin of that piece twice over.


## The design cards, and the low end that went missing

The design card (`score_sheet.py` plus the card renderer) now carries three
lanes: placed events, register envelope, and a **spectrogram of the rendered
mix** — intent, geometry, and result on one page. The spectrum lane earned
its place immediately.

Reading theme's card showed the 100–250 Hz band running near-white
wall-to-wall. Measured: the synth renders carried **45–52% of their energy
below 80 Hz** — "the weight is at 20–80" is a documented identity of these
cues — and the full-cutover renders carried 16–20%, with the weight shoved
into 250–800. A bowed contrabass stacks partials exactly where the old sine
had silence, and no level meter could see it because every stem's RMS was
calibrated and correct.

The fix took three attempts, each of which taught the same lesson from a new
side: a fixed low-pass plus fixed gain was register-dependent by **24 dB**
(how much of a bowed note survives a 105 Hz filter depends on where its
fundamental sits, and the per-note normalisation upstream was measured on
the unfiltered recording). The sub door now low-passes at 105 Hz and
normalises **after the filter, per note**, to the oscillator sub's own flat
law — register-flat to 0.0 dB by construction. The unfiltered contrabass
still speaks through `drone` and `bowed`, where its midrange is the point.

After: theme 38% below 80 Hz (synth 46), burn 62% (synth 52) — the same
neighbourhood, with the sample set's legitimate timbre differences intact.
Burn's ceiling moved 0.90 → 0.86 for the hotter low end. All thirteen cues
re-rendered: stems sum within 7 LSB, and burn's four pop-detector flags sit
on beat-grid kick onsets in the sparse ignition bars.


## The anti-cheese pass

Two upgrades aimed at the specific mechanics of "sounds like a MIDI mockup",
both from-scratch rather than licensing anything finished.

**Karoryfer instruments (CC0).** `fetch_samples.py` now clones
[karoryfer-bigcat.cello](https://github.com/sfzinstruments/karoryfer-bigcat.cello)
and [karoryfer.meatbass](https://github.com/sfzinstruments/karoryfer.meatbass)
— a close-mic'd solo cello and a 1958 Otto Rubner double bass, and the first
patches in this soundtrack with real **round robins**: the cello's sustains
exist as down-bow and up-bow at four dynamics, its staccatos four deep per
note, the bass's arco with up/down pairs at three velocity layers. A repeated
note is never the identical recording twice, which is the single biggest
mechanical difference between a mockup and a performance. Rewired doors:
`bowed` (meatbass below C2, cello above), `drone` (meatbass mass under
cello octaves), `blade` (cello staccato round robins — the combat riff stops
being one wav machine-gunned). The loader needed two lines: lowercase note
names and `vl<N>` velocity tokens.

**Humanization, seeded — and corrected once.** Everything in this engine
landed mathematically dead on the grid, which is the other half of the
mockup sound. The magnitude is from the sensorimotor-synchronization
literature: musicians locked to an established beat hold 4–15 ms of per-note
asynchrony (Repp), so σ = 5 ms models a tight player. The first version drew
**white** noise at that σ, and that was wrong in the way a listener noticed
before the numbers did: white jitter lets consecutive notes lurch 20+ ms in
opposite directions, and a lurch is what sloppiness *is*. A real player
phase-corrects — the error wanders smoothly and is pulled back — so each
`Track` (one player) now carries an AR(1) error state (ρ = 0.72, marginal SD
held at 5 ms; verified: measured SD 4.95 ms, lag-1 correlation 0.71, max
note-to-note step 14 ms against white's ~30). Gain scatter stays white at
σ = 0.7 dB. All of it draws from the generator every score seeds, so renders
are deterministic; stems still sum to the mix exactly, because jitter
happens before the bus. The gain scatter can lift a marginal stem over full
scale — the clip guard caught theme, burn and boss, whose ceilings moved
down accordingly.

## The mastering toolbox

`mastering.py` -- meters and processors, deliberately NOT a pipeline.  Every
processor is `x -> y` on an array, same shape as an instrument door, so it
applies to whatever layer needs it: one stem inside a score's `render()`
(before the master bus, where the stem-sum invariant is not yet in force), a
whole mix, or an offline wav.  Nothing calls these automatically; a score
reaches for a compressor the way it reaches for a reverb.

Meters (ITU-R BS.1770-4, coefficients redesigned for 44.1 kHz via the
bilinear transform; self-checked against the spec's 997 Hz fixed points):

- `lufs(x)` -- K-weighted, gated integrated loudness.  Peak normalisation
  answers "will it clip"; LUFS answers "how loud does it feel."
- `true_peak(x)` -- 4x oversampled, in dBTP.
- `window_scan(x)` -- avg/peak RMS over 0.4 s windows.  The tool that found
  burn's gong: whole-track RMS averages one loud event into silence.

Processors:

- `compress(x, thresh_db, ratio, ...)` -- slow RMS bus compressor, soft
  knee, 2:1 default.  Glue, not squash.
- `limit(x, ceiling_db)` -- look-ahead brickwall.
- `loudness_normalize(x, target_lufs)` -- pure gain to an LUFS target.

CLI: `python3 mastering.py report out_s` (LUFS/dBTP per song) and
`python3 mastering.py stems out_s/burn_stems` (windowed per-layer balance).

First report on the album found the tiering inverted in LUFS terms: the
station cues (business, home at -12.6) out-loud the fight (burn -14.5), and
dread sits quietest at -17.2 -- an ordering peak normalisation could not
see, because each song's `peak=` ceiling only pins its maximum, not its
felt loudness.
