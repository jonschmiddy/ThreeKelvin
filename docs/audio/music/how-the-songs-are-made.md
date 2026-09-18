# How the songs are made

## Three families

The seventeen cues come from three different approaches, and it's worth knowing which is which.

**First Light and Quiet Orbit follow the repo's system** (`tkg/audio/README.md`). Both are built
from the game's phrase — scale degrees 1-2-1-2-♭3 — at 71 BPM, with no fifth anywhere in the
melody, no leading tone and no cadence.

- **First Light** is the existing score from `tkg/audio/first_light.py`, ported note for note.
  Its whistle, reed, glass, bells and keyboard parts map onto the lab's Tune, Middle melody,
  Echo and Extra parts. All 437 notes were checked against the Python source.
- **Quiet Orbit** is new, and its one thing is **retrograde**: the phrase backwards, A♭ G F G F.
  It opens on the flat third every other cue ends on. No other cue uses retrograde.

**The title menu** is its own thing: suspended chords, a drone, and a scrap of the phrase drifting
past once.

**The other fourteen are separate songs.** They share no phrase, key or tempo with each other. What
they share is a shape and a position on a danger scale. They exist because a ladder of cues that
are all the same phrase in different clothes reads as one piece of music, not fourteen.

## Drums

Every cue except First Light and the title has a **Drums** switch: deep hits only, a written
pattern, or nothing. The patterns live in `GROOVES` in the lab: `brush`, `pulse`, `half`, `drive`,
`broken`, `slow`, `pound` and `tick`, plus `quake`, which has no steady pulse at all. Which
sections of a cue get which pattern is written per cue in its `groove` field.

Two rules that came out of the work: **hi-hats are what make a fast beat sound energetic** rather
than oppressive, so the heaviest cues have none; and **a steady kick makes anything danceable**, so
the most frightening cues avoid a regular pulse entirely.

## What makes a cue feel dangerous

Every cue is the same seven parts (see below) over a chord rotation. The difference between EASY
and ROUGH is made of five things, none of which is "add drums":

| | Long Way Round (safest) | Cold Start | Slipstream | Cut Signal (worst) |
|---|---|---|---|---|
| Tempo | 71 | 71 | 104 | 96 |
| Harmony | major, resolves every 8 bars | major, resolves | minor, keeps turning | minor plus a chord that can't resolve |
| Peak note density | 58 | 154 | 162 | 154 |
| Fastest figuration | quarter notes | sixteenths | sixteenths from early on | sixteenths |
| Deep hits | 0 | 1 | 4 | 5 |
| Silence | long | some | one sudden break | two dead stops |

The build is made **entirely of added top**: more notes, higher register, brighter figuration.
The sub bass is printed at one level the whole way through. That's from the repo's own
measurement of its cues, and it's why the music gets more intense without getting muddier.

The level of each section is written as decibels relative to the peak — an arch, not a ramp.
Typically about -9 dB at the start, 0 dB at the peak roughly two thirds through, then a hard
drop for the release.

## The seven parts

Every cue is arranged for the same seven parts, which is why one instrument palette can be
swapped for another in a single click.

| Part | What it does |
|---|---|
| Tune | the melody |
| Middle melody | a second voice, usually the same line an octave down |
| Echo | far-off single notes and bells, almost always on a long delay |
| Chords | the sustained pad, one chord per bar or per two bars |
| Extra | the keyboard figuration: the eighths and sixteenths that carry the build |
| Bass | the sub, flat in level |
| Drums | deep hits only, never a groove |

## Structure

Each cue has its own form. They are not variations on one template:

- **Close Quarters** — Contact 4, Fight 8, Push 8, Turn 8, Clear 4. The EASY fight: a riff that comes back.
- **Red Line** — Pulse 8, Climb 8, Red line 8, Hold 4, Red line 2 8, Cut 4. One four-bar release in the whole cue.
- **Hairline** — 6, 6, 8, 4, 8, 6. Uneven on purpose, so the pattern is never learnable.
- **Dead Weight** — Weight 8, Drag 8, Crush 8, Wake 8, at 60 BPM.
- **Overpressure** — Seal 8, Strain 8, Fail 8, Rupture 4, After 4. One cluster per section, each a half step higher.
- **Nothing Left** — Empty 8, Almost 8, Something 8, Empty 2 8. Three notes in the first section.
- **Wrong Ship** — Signal 6, Closer 8, Wrong 8, Worse 8, Gone 6, over a bass that never moves.
- **Event Horizon** — Fall 8, Deeper 8, Closer 8, Silence 4. One chord throughout.
- **No Air** — Thin 6, Thinner 8, Ring 8, Out 6. No bass at all.
- **Last Stand** — Hold 8, Push 8, Wave 8, Break 4, Hold 2 8, Push 2 8, Closer 6, Tighter 6, Rally 8, Stop 2. The boss.

- **Cold Start** — Intro 4, Verse 8, Chorus 8, Verse 2 8, Chorus 2 8, Outro 4. The only cue that
  repeats a tune on purpose.
- **Long Way Round** — Open 8, Wide 8, Wider 8, Away 8. No peak.
- **Slipstream** — Run 8, Push 8, Break 4, Return 8, Sprint 8, Tail 4. The break drops to almost
  nothing in the middle.
- **Cut Signal** — Signal 5, Dead air 2, Push 7, Burst 6, Hold 2, Collapse 8. Unequal lengths, two stops.
- **Quiet Orbit** — Floor 2, Open 6, Turn 8, Lift 8, Peak 8, Release 8. The repo's arch shape.
- **First Light** — Floor 2, Enter 8, Figure 8, Gather 8, Turn 8, Release 8, as written in the Python.
- **Title menu** — Wide 8, Signal 8, Quiet 8. Chords, drone and a few far-off notes.

## Rules every cue obeys

These are checked automatically whenever the music changes:

1. **No note is a half step or a tritone from a chord tone if it's held.** Passing dissonance is
   fine; sustained dissonance is a mistake.
2. **Strong beats are chord tones.** Beats 1 and 3 land inside the chord.
3. **No repeated note across a phrase seam**, and no leap wider than an octave between
   consecutive notes.
4. **First Light and Quiet Orbit additionally contain no C and no E natural**, since the phrase
   never touches the fifth and there is no leading tone.
5. **Loops are seamless.** The last bar leads into the first, and no cue ends on a cadence.

## Writing a new cue

In `lab/tk_music_lab.html`, find `const LADDER = [`. Each entry is a complete song:

```js
{id:'yourcue', name:'Your Cue', tier:'BRUTAL', bpm:88, key:'G minor',
 form:[['Open',8],['Turn',8],['Peak',8],['Out',8]],     // section names and bar counts
 arch:[-8, -4, 0, -7],                                   // dB per section
 chords:{i:['G1','D3','G3','Bb3'], ...},                 // the chord voicings
 bars:{'Open':'i i iv iv ...'},                          // one chord name per bar
 figures:{'Turn':[1,0], 'Peak':[.25,12]},                // [note value, semitone lift]
 lines:{'Turn':{notes:['G5:2 Bb5:2', ...], amp:.85, second:true}},
 bells:[['Peak',8,'G6',2]], booms:[['Peak',0]]}
```

Melody notation is `note:beats`, with `r` for a rest, and each string is one bar of four beats.
Add the cue's id to `LADDER_SETUPS` and `LADDER_BPM` to give it a palette and a default tempo,
and it appears as a tab, sorted into its tier automatically.
