# How the songs are made

## Three families

The twenty-seven cues come from three different approaches, and it's worth knowing which is which.

**First Light and Quiet Orbit follow the repo's system** (`tkg/audio/README.md`). Both are built
from the game's phrase — scale degrees 1-2-1-2-♭3 — at 71 BPM, with no fifth anywhere in the
melody, no leading tone and no cadence.

- **First Light** is the existing score from `tkg/audio/first_light.py`, ported note for note. Its
  whistle, reed, glass, bells and keyboard parts map onto the lab's Tune, Middle melody, Echo and
  Extra parts. All 437 notes were checked against the Python source.
- **Quiet Orbit** is new, and its one thing is **retrograde**: the phrase backwards, A♭ G F G F. It
  opens on the flat third that every other cue ends on.

**The title menu** is its own thing: suspended chords, a drone, and a scrap of the phrase drifting
past once.

**The other twenty-four are separate songs.** They share no phrase, key or tempo with each other.
What they share is a shape and a position on a danger scale. They exist because a ladder of cues
that are all the same phrase in different clothes reads as one piece of music, not twenty-four.

## What makes a cue feel dangerous

The difference between tiers is made of several things, and none of them is "add drums" or "turn
it up":

| | Long Way Round (safest) | Cold Iron (HARD) | Attrition (BRUTAL) | Last Stand (boss) |
|---|---|---|---|---|
| Tempo | 71 | 92 | 92 | 132 |
| Harmony | major, resolves every 8 bars | minor, hammered | tonic and the chord a half step above | minor, bass walking down chromatically |
| Peak notes per section | 58 | 99 | 161 | 165 |
| Fastest figuration | quarter notes | eighths | sixteenths | sixteenths an octave up |
| Deep hits | 0 | 178 | 198 | 613 |
| Silence | long | none | none | one four-bar break |

Two rules came out of the work and are worth keeping:

- **Hi-hats are what make a fast beat sound energetic** rather than oppressive. The heaviest cues
  have none.
- **A steady kick makes anything danceable.** The most frightening cues (Overpressure, Event
  Horizon) avoid a regular pulse entirely; the `quake` pattern has no beat you can tap to.

Above HARD, tempo stops being the signal. BRUTAL and LETHAL hold the slowest cues in the game
(Nothing Left at 52, Event Horizon at 46) alongside the fastest (Last Stand at 132). What escalates
instead is how little the music offers: fewer resolutions, less pulse, less bottom end, less of
anything to hold onto.

## The seven parts

Every cue is arranged for the same seven parts, which is why one instrument palette can be swapped
for another in a single click.

| Part | What it does |
|---|---|
| Tune | the melody |
| Middle melody | a second voice, usually the same line an octave down |
| Echo | far-off single notes and bells, almost always on a long delay |
| Chords | the sustained pad, one chord per bar or per two bars |
| Extra | the keyboard figuration: the eighths and sixteenths that carry the build |
| Bass | the sub |
| Drums | deep hits, and a pattern where the cue calls for one |

## Drums

Every cue except First Light and the title has a **Drums** switch: deep hits only, a written
pattern, or nothing. The patterns live in `GROOVES` in the lab:

| Pattern | What it is |
|---|---|
| `brush` | rim clicks and soft hats, for the warm cues |
| `pulse` | kick on 1 and 3 with eighth hats |
| `half` | half-time: kick on 1, snare on 3 |
| `drive` | a full beat with eighth hats, for the fights |
| `broken` | the snare drops out every third bar and the kick moves |
| `slow` | one huge kick every other bar |
| `pound` | four heavy kicks a bar, a late snare, no hats at all |
| `tick` | rim only, no kick: for cues with no bottom end |
| `quake` | no pulse: one hit on the bar, one that moves, a roll every eighth bar |

Which sections get which pattern is written per cue in its `groove` field.

## Structure

Each cue has its own form. They are not variations on one template:

- **Cold Start** — Intro, Verse, Chorus, Verse 2, Chorus 2, Outro. The only cue that repeats a tune.
- **Long Way Round** — Open, Wide, Wider, Away. No peak at all.
- **Drift Plane** — Open, Call, Answer, Together, Rest. The second voice leads a whole section.
- **Close Quarters** — Contact, Fight, Push, Turn, Clear. The EASY fight: a riff that comes back.
- **Ghost Freight** — the harmony turns every three bars, the tune every four. Sections of 6, 9, 9, 6.
- **Salvage** — a ground bass: the same four chords all the way down, four times over.
- **Cut Signal** — Signal 5, Dead air 2, Push 7, Burst 6, Hold 2, Collapse 8. Two dead stops.
- **Slipstream** — Run, Push, Break, Return, Sprint, Tail. The floor drops out of the middle.
- **Red Line** — sixteenths from the second section to the end, with one four-bar release.
- **Dead Weight** — 60 BPM, one huge hit every other bar.
- **Cold Iron** — one hammered figure, mid-tempo, that never lets up.
- **Thin Ice** — short stabs and rests; the gaps do as much work as the notes.
- **Hairline** — 6, 6, 8, 4, 8, 6. Uneven on purpose, with a Neapolitan and a diminished chord.
- **Nothing Left** — three notes in the first eight bars.
- **Wrong Ship** — the bass never leaves D while the chords slide a half step against it.
- **Countdown** — sections shorten (8, 8, 6, 4, 2) and the ping gets closer together.
- **Attrition** — the same two-bar figure eighteen times, heavier each pass, never developing.
- **Overpressure** — one cluster per section, each a half step higher than the last.
- **Event Horizon** — one chord for the whole cue; the hit closes from eight bars apart to every bar.
- **No Air** — stacked fifths, no sub, nothing below the middle of the keyboard.
- **Sealed** — almost nothing, very slowly, in an enormous room.
- **Aftermath** — a beacon pinging once a bar while everything else decays around it.
- **Last Stand** — the boss: three waves, a phase break, then sections that shorten to the end.
- **Lights Out** — the death cue: Fall, Empty, Gone, then four bars of literal silence.

## Rules every cue obeys

These are checked automatically by `tools/check_cue.mjs`:

1. **Every event is a playable note.** A name the engine can't parse (C♭, F♭, E♯) becomes a silent
   NaN that only blows up at render time.
2. **No held note is a half step or a tritone from a chord tone.** Passing dissonance is fine;
   sustained dissonance is a mistake.
3. **Strong beats are chord tones**, with deliberate exceptions reported as notes rather than failures.
4. **No repeated note or leap wider than an octave across a phrase seam.**
5. **Quiet Orbit contains no C and no E natural**, since its phrase never touches the fifth and
   there is no leading tone.
6. **Loops are seamless.** No cue ends on a cadence.

## Writing a new cue

In `lab/tk_music_lab.html`, find `const LADDER = [`. Each entry is a complete song:

```js
{id:'yourcue', name:'Your Cue', tier:'HARD', role:'fight', bpm:88, key:'G minor',
 form:[['Open',8],['Turn',8],['Peak',8],['Out',8]],     // section names and bar counts
 arch:[-8, -4, 0, -7],                                   // dB per section
 groove:{'Turn':'half', 'Peak':'pound'},                 // which pattern, per section
 chords:{i:['G1','D3','G3','Bb3'], none:[]},             // voicings; [] means silence
 bars:{'Open':'i i iv iv ...'},                          // one chord name per bar
 figures:{'Turn':[1,0], 'Peak':[.25,12]},                // [note value, semitone lift]
 lines:{'Turn':{notes:['G5:2 Bb5:2', ...], amp:.85, second:true}},
 bells:[['Peak',8,'G6',2]], booms:[['Peak',0]]}
```

Melody notation is `note:beats`, `r` for a rest, one string per bar of four beats.

- `role:'fight'` puts it last in its tier and labels the tab.
- `tier:'DEATH'` puts it in its own group at the end of the tabs.
- A chord of `[]` prints nothing at all: no pad, no sub, no figuration. That's how Lights Out ends.
- Add the id to `LADDER_SETUPS` (its palette), `LADDER_BPM`, `LADDER_GROOVE`, and optionally
  `LADDER_ARCH` (`'flat'` for no build) and `LADDER_BASS` (`'off'` for no sub).
