# Working on the Three Kelvin music

Orientation for whoever (or whatever) picks this up next.

## The two rules

**`lab/tk_music_lab.html` is the source.** Every note, instrument, effect and arrangement lives
in that one file. The WAVs and OGGs are rendered *from* it. The JSON files in `songs/` are
dumped *from* it for reading. Never edit a rendered file, and never treat the JSON as the source
— change the lab, then re-render and re-dump.

It's a single self-contained page: open it in a browser, no build step, no server, no network.

**Run the checks after any music change.**

```bash
cd music/tools && npm install      # once per machine
node check_cue.mjs                 # the musical rules, every cue in loops.json
node check_lab.mjs                 # the page itself: tabs, transport, scrubbing, settings
```

`.github/scripts/validate.sh` runs both under *The music lab still holds
together*, and skips them with a note when node or `node_modules` is missing —
so a fresh clone does not fail, but a machine that can check does.

## Where things are inside the page

Search for these strings to land in the right place:

| Looking for | Search for |
|---|---|
| The instrument definitions (all 130 patches) | `const P = [` |
| Which instruments are offered, by part | `const POOL` and `validFor` |
| The sound presets | `const PRESETS = [` |
| Per-part effects (reverb, delay, volume) | `const FX = {` |
| Effects on everything (space, warmth, lo-fi…) | `const GFX = [` and `applyGlobalFx` |
| The standalone songs (24 of them) | `const LADDER = [` |
| Their palettes, tempos, grooves | `LADDER_SETUPS`, `LADDER_BPM`, `LADDER_GROOVE` |
| Per-cue build and sub defaults | `LADDER_ARCH`, `LADDER_BASS` |
| The drum patterns | `const GROOVES = {` |
| Quiet Orbit | `function buildQuietOrbit` |
| First Light (ported from the repo) | `function buildFirstLight` |
| The title menu | `THEMES[0] = {name:'Three Kelvin'` |
| How a standalone song is turned into notes | `function buildStandalone` |
| The synth engine (one note) | `function voice(` |
| Scheduling and transport | `function scheduler`, `function start`, `function seek` |
| The tabs | `const SONGS = [` and `function switchSong` |

## Melody notation

Each melodic line is an array of bar strings. One string is one bar of four beats:

```js
['F5:2 D5:2', 'Bb5:4', 'r:2 G5:2']
```

`note:beats`, separated by spaces, `r` for a rest. The beats in a bar must add to 4.

## The workflow that worked

1. **Change the lab.** Edit a line, a chord rotation, a form, a palette.
2. **Run the checks.**
   ```bash
   cd tools && npm install jsdom node-web-audio-api    # once
   node check_cue.mjs              # musical rules, all cues
   node check_cue.mjs slipstream   # or just one
   node check_lab.mjs              # the page itself: tabs, transport, scrubbing, settings lines
   ```
   `check_cue.mjs` fails on two things only: a held note grinding against its chord, and a cue
   containing a pitch it has sworn off. Everything else it prints as a note to look at, because
   off-chord strong beats and repeated notes are often deliberate.
3. **Listen.** Open the lab, play the section you changed. The checks catch wrong notes, not
   boring ones.
4. **Re-render.**
   ```bash
   cd engine && node render_wav.mjs slipstream ../audio/slipstream.wav
   ```
   Then re-encode to OGG if you're shipping those:
   `ffmpeg -y -i ../audio/slipstream.wav -c:a libvorbis -q:a 6 ../audio/slipstream.ogg`
5. **If tempo or bar count changed,** update the loop points in `audio/loops.json` and
   `integration/godot.md`. The renderer prints the new values when it runs.

## Things that will bite you

- **`render_wav.mjs` does not currently reproduce the shipped audio.** Do not
  re-render a cue and ship it until this is understood. The oggs in
  `tkg/assets/audio/music/` are good; a fresh render is not.

  **The right channel comes out nearly empty.** Measured on `qo`, which nobody
  had touched — a fresh render against its shipped ogg:

  | | L rms | R rms |
  |---|---|---|
  | shipped | 0.099 | 0.088 |
  | fresh render | 0.096 | **0.015** |

  By band, the fresh render's R against its own L: **17 to 26 dB down below
  2.5 kHz, and +10 dB above 5 kHz.** So the right channel has almost none of the
  music and mostly high-frequency noise. Summed to mono that loses 5.7 dB and
  the cue goes thin and dry, which is how it was first noticed.

  Ruled out, each by experiment:
  - **The dependency version.** Pinned `^0.21.0`, installs 0.21.5; 0.21.0
    exactly behaves identically.
  - **The reverb impulse.** `makeIR` builds two independent noise channels.
    Forcing both channels to the *same* noise changes nothing.
  - **Every node in the master chain.** Gain, biquad, waveshaper, compressor,
    analyser and the splitter/merger width stage each pass a stereo signal
    through with both channels intact.

  Found but not the cause: **node's `ConvolverNode` sums its input to mono.**
  Feed it 300 Hz left and 900 Hz right and both output channels come back
  identical, carrying both tones — where a browser keeps them separate. Worth
  knowing, but it makes reverb *more* correlated, not less, so it does not
  explain an empty right channel.

  **What would settle it fastest is knowing how the shipped oggs were made** —
  whether `render_wav.mjs` produced them on another machine, or whether they
  came from somewhere else and this script never matched.

  Check any render before shipping it:

  ```python
  import soundfile as sf, numpy as np
  y, _ = sf.read('cue.ogg', always_2d=True, frames=44100*20)
  L, R = y[:, 0], y[:, 1]
  print(np.sqrt(np.mean(L**2)), np.sqrt(np.mean(R**2)))   # want them within a few dB
  ```

- **`nothingleft.ogg` is one note behind the lab, deliberately.** Bar 24 held a
  half step against bVI and was changed to `B4` in the lab; the shipped ogg still
  has the old note, because the render that would have carried the change is the
  broken one above. Jon has heard the shipped cue and is happy with it, so this
  is not urgent — but `check_cue.mjs` reads the LAB, so it is green while the
  audio is not. **When the renderer is fixed, re-render this cue first** and the
  two come back into line.

- **Handoffs arrive from a copy of this folder that is not the repo.** The
  second one came back with bar 24 of Nothing Left undone and `check_cue.mjs`
  checking seven cues again -- both fixed here after the first handoff, both
  reverted by copying the next one over the top. So a handoff is MERGED, not
  copied: diff the lab, the checker and this file against the repo before
  anything lands, and carry the repo's changes forward. The checker now reads
  its cue list from `loops.json`, which removes one of the two ways back.

- **Saved settings live in the browser.** The lab remembers each cue's switches in
  localStorage under `tk-lab5-<cue>`. If you change a switch's options, old saved values are
  cleaned automatically now, but if you ever see a panel come up blank, that's the first suspect.
- **A cue's defaults are its locked version.** `LADDER_SETUPS`, `LADDER_BPM`, `QO_SETUP_ROW`,
  `FL_SETUP_ROW`, `TITLE_SETUP_ROW` and the `*_GFX` constants are the approved sound of each
  cue. Changing them changes what everyone hears on a fresh load, so only do it deliberately.
- **Held notes are where dissonance hurts.** Passing notes can be anything; a note held two
  beats or longer has to agree with the chord. That's the rule `check_cue.mjs` enforces.
- **The build is added on top, never underneath.** More notes, higher register, brighter
  figuration. The sub bass stays at one level through the whole cue. Breaking this makes cues
  louder rather than more intense.
- **First Light is not ours to rewrite.** It's a verbatim port of `tkg/audio/first_light.py`.
  If that file changes in the repo, re-port it rather than editing the copy here.
- **Reverb is shared.** One convolver for the whole mix, not one per part. Separate reverbs
  overloaded the audio thread and caused crackling.
- **Two cues sit off the grid on purpose.** Slipstream (104) and Cut Signal (96) don't share a
  bar length with the rest. That's part of how they read as more dangerous, not an oversight.

## What's deliberately not here

The lab has no undo, no project files and no version history beyond git. If you're making a big
change, copy the lab file first — it's 220 KB.
