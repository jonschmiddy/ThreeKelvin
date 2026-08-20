# Three more cues

"Slow Drift" and "Dead Sector" covered the whole game between them: one for
the run, one for danger. These three take the states that were borrowing an
arrangement and give them a piece of their own — combat, the places you are
safe in, and the boss.

All three are the same whistled motif. Nothing here is a new tune.

| | Does this to the motif | Key | BPM | Bars | Length | Stems |
|---|---|---|---|---|---|---|
| **Hard Burn** | halves its note values and makes the engine out of it | F Aeolian | 142 | 48 | 81.13 s | 9 |
| **Warm Ship** | gives it the fifth it never reaches | F, coloured from ♭VI | 71 | 24 | 81.13 s | 8 |
| **Poisoned Ground** | gives it that fifth a semitone flat | F over a tritone pedal | 71 | 32 | 108.17 s | 9 |

Every cue in the set is 142 BPM or exactly half at 71, so all ten pairings are
a 1:1 or 2:1 bar lock and any two can crossfade without a tempo match. "Hard
Burn" and "Warm Ship" are the same length to the sample — 48 bars at 142 is
81.126761 s and 24 bars at 71 is 81.126761 s — so they also stay phrase-aligned
across an indefinite number of loops.

The forms all live in `motif.py`; the reasoning for each piece is below and in
its score's header.

---

## "Hard Burn" — combat

Same tempo as the main theme. Combat is a change of arrangement, never a
change of clock.

### The motif *is* the riff

`diminish(MOTIF, 2)` halves every note value, which puts the five-note cell in
**3 beats against a 4/4 bar**. That mismatch is the whole engine:

* Locked to the barline (§II, §IV) it fills three beats and leaves one for a
  tail, so the bar has a built-in kick and answer.
* Let go (§III) and placed every 3 beats, it walks — ten cells across eight
  bars, aligning with the barline exactly twice.

This is "Dead Sector"'s 7-beat polymetre rebuilt at four times the speed. The
device is the same; slow it is dread, fast it is drive.

### The ♭5 is already in it

`RIFF_B` ends on B♮ and lands every other bar. The tritone that "Dead Sector"
saves for its climax and "Poisoned Ground" is built on is sitting in the combat
riff from bar 9 — so by the time a boss states it, the ear has heard it a
hundred times without being told what it was.

### Devices

| Device | Bars | What it does |
|---|---|---|
| **Fragmentation** | 5–8 | Riff arrives as its first two notes only, same withholding the dread cue opens with |
| **Diminution** | 9–24 | The motif as an 8th-note riff. The hook overhead is the same phrase at original speed |
| **Polymetre** | 25–32 | 3-beat cell every 3 beats under 4/4, harmony frozen so the metre is all you hear |
| **Stretto** | 33–44 | The cell entered 2 beats later an octave down; the two copies overlap for a beat every bar |
| **Canon** | 37–44 | Whistle against itself at the octave, 2 beats late |
| **Terminal thinning** | 45–48 | Back to the pedal and the first two notes — where bar 1 starts, so the loop point is a musical event |

`blade()` is new in `synth.py` and is the only driven voice in the set.
Everywhere else the ship is a small warm thing in a cold frame; in a fight it
is loud, so it is the one place distortion belongs. The cue is also the driest
in the set — every reverb value is below its counterpart elsewhere, because
reverb is distance and a fight is not far away.

Measured: 250–800 Hz at 9.6% of energy, centroid 265 Hz, RMS −10.7 dBFS
against the main theme's −12.8. Two decibels louder and no brighter, which is
what a fight should be.

---

## "Warm Ship" — station, refit, deck

The audio half of "cold universe, warm ship". It is the only music in the game
with **no noise, no drums and no distortion anywhere in it** — every other cue
has at least breath noise or a filtered-noise layer. That absence is what makes
it read as an interior rather than as more void.

### It starts on the ♭VI

`THEME_NOTES` §3: over D♭maj7 the motif's G is a ♯11 and the phrase reads as
wonder rather than as home. So the cycle is **♭VI – ♭III – ♭VII – i**, walking
*towards* the tonic across eight bars. Arriving at a station is a cadence.
Leaving one re-opens it.

Bars 19–20 lift with `INVERT` — the mirrored form, whose D♮ is A♭maj7's ♯11.
The Lydian colour lands exactly where the harmony can take it, which is why
the inversion sits there and nowhere else in the piece.

### It answers the motif

The source phrase never touches the fifth. `THEME_NOTES` §1 calls that a
question with no answer, which is right under a run that can end at any moment
— and it means the game has one unused card in its hand for the whole
soundtrack.

`ANSWER` spends it. Bars 23–24: the five notes, then the **C**, over Fm9, held
on the glass. Exactly two bars, once per loop, in the one place in the game
where you are safe. Then the loop wraps to the ♭VI and the question re-opens,
which is what leaving a station is.

`glass()` is new — a glass-harmonica voice with pure partials and a slow swell.
`bell()` strikes and decays; this one breathes.

Wettest cue in the set. A hull interior is a small room, but reverb here is
comfort rather than distance, so the tails stay long.

---

## "Poisoned Ground" — the boss

Both boss ideas the notes files left unbuilt, in one piece.

### Bars 1–8: the title music, unaltered

`DREAD_NOTES` §5 — *"state the original motif over the tritone pedal. Familiar
melody, poisoned ground."*

Bars 1–8 are not a variation of anything. They are the opening of "Slow Drift":
the same five notes, the same F6 register, the same whistle patch, and — this
is the part that has to be got right — **the same note durations to the
sample**. The B♮ slides in underneath at bar 5 and **the melody does not change
at all**.

The tempo lock is what makes that possible, and it is the first place in the
set where the lock is a compositional device rather than a crossfade
convenience. This cue runs at 71 BPM, so `diminish(MOTIF, 2)` here produces
0.422535 s quarter notes and a 0.794366 s tail — bit for bit the values
`arrange.py` writes at 142. One statement per bar is one every 3.3803 s, which
is also exactly the rate "Slow Drift" restates it at in its own intro. Onsets,
durations and restatement interval all match, so the quotation is verifiable
rather than gestural.

Stating the motif at this cue's own 71 BPM would have given the theme at half
speed, which reads as a slow variation — an allusion. A boss cue that alludes
to the theme does not do the job. It has to *be* it.

That is the inversion the whole cue is built on. Everywhere else in the game
the motif mutates to tell you something — one flat means deep space, a halved
note value means a fight. Here it stays innocent and the ground goes bad under
it. There is nothing you can point at in the tune.

### Bars 9–16: the motif in the bass

`THEME_NOTES` §6 — *"transpose the cycle down to E♭ minor and put the motif in
the bass; keep the whistle on top so it clashes."*

The bass plays `transpose(MOTIF, -2)` — E♭ F E♭ F G♭ — on bowed strings two
octaves down. The whistle does not follow. It holds the original pitches, so
its G♮ grinds a semitone against the bass's G♭ for eight bars, and its A♭ sits
as the 11th over E♭m. The F pedal never moves and is now the 9th of the chord
above it, so nothing in the section is resolved on any axis at once.

### Bars 17–24: both mutations at once

Whole tone and semitone, one beat apart — the quoted form on the whistle,
`PHRYGIAN` in the shadow voice. "Slow Drift" and "Dead Sector" playing the same
phrase over the same pedal and disagreeing about exactly the one note they have
ever disagreed about. The B♮ pedal underneath means neither of them is right.

Each voice runs at its **own** tempo: the theme voice twice per two-bar unit
(142 BPM note values), the dread voice once (71 BPM note values). The 2:1 lock
the whole soundtrack is built on stops being an engineering property here and
becomes the thing you are listening to — one cue running at exactly double the
other, over one pedal, inside the same bar.

This is the cue's 4th stem, and it is why `Audio.DEEP_MAX` exists: a danger-10
skirmish gets this cue at rung 3 and never unmutes the shadow. A boss is the
only thing that spends it.

### Bars 25–32: the fifth, flat

`FALSE_ANSWER` keeps the original whole tone the whole way in and then lands on
B♮ where the C should be. It spans exactly two bars, so it fits the cycle.

The station cue answers the motif's question with the fifth. The boss answers
it with the ♭5. Those are the only two places in the game the phrase finishes,
and a player who has heard both knows which one they are in before the enemy
sprite has finished drawing.

The loop then wraps from that ♭5 straight back into the untouched theme of
bar 1, which is the joke the cue is built on: it never stops being the same
tune.

No drum kit — `DREAD_NOTES` §2's ruling holds. Rhythm is `heart()` and two
impacts, nothing else.

---

## Levels

Deliberately tiered, and not normalised to each other. `master()` peak-limits
each cue but the RMS is the composition's, and the ladder is the point.

| Cue | Peak | RMS | Centroid | Where the weight is |
|---|---|---|---|---|
| Warm Ship | 0.84 | −13.5 dBFS | 292 Hz | 80–250 Hz — bass in its own register, mids open |
| Dead Sector | 0.86 | −17.6 dBFS | 341 Hz | 250–800 Hz — bowed mass, no floor |
| Poisoned Ground | 0.88 | −15.5 dBFS | 345 Hz | split: pedal below 80, bowed mass at 250–800 |
| Slow Drift | 0.89 | −12.8 dBFS | 281 Hz | 20–80 Hz |
| Hard Burn | 0.90 | −10.7 dBFS | 265 Hz | 20–80 Hz, and 2 dB louder than the theme |

`DREAD_NOTES` §3's warning generalises: **do not normalise these to match each
other.** The headroom is the effect. A station is quiet because it is safe.
