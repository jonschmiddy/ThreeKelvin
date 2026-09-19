# Three Kelvin — music handoff

Everything needed to play, change, re-render and ship the music: the lab that makes it,
the songs themselves, the instrument and effect tables, and how to wire the result into the game.

Nothing here is a recording. Every sound is synthesised from scratch in the Web Audio API —
no samples, no libraries, no licensing to worry about.

## What's in here

```
lab/tk_music_lab.html      the music lab: one self-contained page, no build step, no network
audio/*.ogg                all 27 cues as loops, ready to ship
audio/loops.json           tempo, bar count and exact loop point for every cue
engine/render_wav.mjs      re-render any cue to WAV after you change it
tools/check_cue.mjs        check a cue against the musical rules
tools/check_lab.mjs        smoke-test the lab page: tabs, transport, scrubbing, settings
CLAUDE.md                  orientation: where everything lives and the edit workflow
songs/cues.json            the cues, their tiers and their structure
songs/instruments.json     every instrument, its number and what it sounds like
songs/presets.json         the 45 sound presets used in the lab
songs/effects.json         the per-part and global effects, and their settings
docs/how-the-songs-are-made.md   the composition rules and how a cue is built
docs/instruments.md        the instrument list in readable form
docs/effects.md            what every effect does
integration/godot.md       wiring the cues into the game, with example code
integration/tiers.md       which cue plays when
```

## The cues

Twenty-seven: a title theme, four run cues and one fight cue for each of five difficulty tiers,
and a death cue. LETHAL's fight is the boss. Lights Out does not loop.

| Cue | Tier | Role | Key | Tempo | Length | Character |
|---|---|---|---|---|---|---|
| Title menu | menu | run | B major, suspended | 72 | 1:20 | Big, empty and lonely. Almost no melody. |
| First Light | EASY | run | F minor to F major | 71 | 2:22 | The repo score, ported note for note. |
| Cold Start | EASY | run | B flat major | 71 | 2:15 | Verse and chorus, brushed drums. The warmest cue. |
| Long Way Round | EASY | run | D major | 71 | 1:48 | No climax and no drums, ever. |
| Drift Plane | EASY | run | C major | 68 | 2:00 | A call and an answer passed between the two voices. |
| Close Quarters | EASY | fight | A dorian | 100 | 1:17 | A scuffle you expect to win: it resolves and lands home. |
| Ghost Freight | ROUGH | run | B minor | 88 | 1:22 | Harmony turns every three bars, the tune every four. |
| Salvage | ROUGH | run | A minor | 82 | 1:45 | A ground bass: the same four chords all the way down. |
| Cut Signal | ROUGH | run | C sharp minor with a tritone | 96 | 1:15 | Fragments of unequal length and two dead stops. |
| Quiet Orbit | ROUGH | run | F Aeolian | 71 | 2:15 | The repo phrase played backwards. |
| Slipstream | ROUGH | fight | E minor | 104 | 1:32 | Relentless, and the floor drops out of the middle. |
| Red Line | HARD | run | G minor | 116 | 1:23 | Danger by speed. Sixteenths almost all the way through. |
| Dead Weight | HARD | run | C minor | 60 | 2:08 | Danger by weight. Half the tempo of anything else. |
| Cold Iron | HARD | run | F sharp minor | 92 | 1:23 | One hammered figure that never lets up. |
| Thin Ice | HARD | run | C minor | 104 | 1:14 | Brittle: short stabs, and the gaps do the work. |
| Hairline | HARD | fight | A minor | 108 | 1:24 | The key comes apart underneath you. |
| Nothing Left | BRUTAL | run | E flat minor | 52 | 2:28 | Abandonment. Three notes in the first eight bars. |
| Wrong Ship | BRUTAL | run | D minor over a pedal | 71 | 2:02 | The bass never moves while the chords slide against it. |
| Countdown | BRUTAL | run | A minor | 100 | 1:07 | A timer: sections shorten and the ping closes in. |
| Attrition | BRUTAL | run | F minor | 92 | 1:34 | The same two bars eighteen times, heavier each pass. |
| Overpressure | BRUTAL | fight | F sharp, rising clusters | 84 | 1:31 | No pulse at all, only rising pressure. |
| Event Horizon | LETHAL | run | B flat minor, one chord | 46 | 2:26 | The hit closes from eight bars apart to every bar. |
| No Air | LETHAL | run | stacked fifths | 96 | 1:10 | No sub, nothing below the middle of the keyboard. |
| Sealed | LETHAL | run | G sharp minor | 54 | 2:13 | Almost nothing, very slowly, in an enormous room. |
| Aftermath | LETHAL | run | B minor | 56 | 2:09 | A beacon nobody will answer. |
| Last Stand | LETHAL | fight | D minor | 132 | 2:00 | The boss: three waves, a phase break, then it tightens. |
| Lights Out | DEATH | death | D minor, then no key | 48 | 1:10 | Falls, stops, and ends in twenty seconds of silence. Not a loop. |

Every cue loops seamlessly: the last bar leads back into the first, and no cue ends on a
cadence, so a loop point is never a full stop.

## Quick start

**Just want the music?** Take `audio/*.ogg` and go. The uncompressed WAVs are in the
separate `three_kelvin_music_wavs.zip` if you need them. See `integration/godot.md`.

**Want to change something?** Open `lab/tk_music_lab.html` in a browser. Nothing to install.
Pick a cue's tab, change instruments, effects or arrangement, and press Play. When it sounds
right, press **Copy** at the top of the page: that line describes the whole setup.

**Changing the music?** Read `CLAUDE.md` first — it says where each thing lives inside the page
and the check-then-render loop to use.

**Want to re-render after a change?**

```bash
cd engine
npm install jsdom node-web-audio-api
node render_wav.mjs qo ../audio/qo.wav
```

The renderer reads the lab page itself, so the WAV and the lab can never drift apart.
