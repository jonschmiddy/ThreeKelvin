# Development — three cues that leave F

The first five cues share a problem. They are all excellent at one trick and
it is the same trick: hold the motif still and change the harmony under it.
`THEME_NOTES` §3 works that way, `DREAD_NOTES` §1 works that way, and "Hard
Burn", "Warm Ship" and "Poisoned Ground" are three more variations on it.

The trick has a cost, and it shows up as a measurement. Instrument `synth.hz`
and record every pitch each score asks for:

| | Pitch classes actually sounded |
|---|---|
| Slow Drift | C D♭ D E♭ F G A♭ B♭ — 8 of 12 |
| Dead Sector | C D♭ E♭ **E** F G♭ A♭ B♭ B — 9 |
| Hard Burn | C D♭ E♭ F G A♭ B♭ B — 8 |
| Warm Ship | C D♭ D E♭ F G A♭ B♭ — 8 |
| Poisoned Ground | C D♭ E♭ F G♭ G A♭ B♭ B — 9 |
| **all five together** | **11 of 12 — everything except A♮** |

**A♮ is the major third of F.** Its complete absence is not a coincidence and
it is not a stylistic choice that was made; it is what "the motif is 1–2–♭3
and we never rewrite it" mechanically produces. With no A♮ the major mode is
not constructible, so five cues could not have been anything but minor even
if someone had wanted otherwise.

The one E♮ is just as telling. It occurs in exactly one place — `SINK`, in
"Dead Sector"'s collapse, F–G♭–F–**E**–E♭ — where it is reached from above
and left downward. It is a passing note. There is no C–E–G–B♭ anywhere in the
first five scores, so there has never been a dominant, and with no dominant
nothing in the game has ever cadenced.

These three cues are about those two notes.

| | Does this to the motif | Centre(s) | BPM | Bars | Length |
|---|---|---|---|---|---|
| **Nine Shells** | transposes it around the minor-third cycle | F → A♭ → B → D → F | 71 | 40 | 135.21 s |
| **Ship's Business** | runs it through a circle of fifths, and cadences | F m → A♭ → 8 keys → F m | 142 | 48 | 81.13 s |
| **Five Ways Home** | varies it five ways, and turns it major | F m → **F major** → whole tone → F m | 142 | 48 | 81.13 s |

All three still sit on the 142 / 71 tempo lock, so all **28 pairings** of the
eight cues are a 1:1 or 2:1 bar lock and any two still crossfade without a
tempo match. Changing key turned out to cost nothing structurally. Nobody had
tried.

---

## "Nine Shells" — the star chart

### The whole-tone fact

There are two whole-tone collections and every pitch is in exactly one:

```
WT1 = D♭ E♭ F  G  A  B          F, G  ->  WT1
WT0 = C  D  E  G♭ A♭ B♭         A♭    ->  WT0
```

So the motif's rocking 1–2 sits wholly inside one collection, and its single
upward gesture — the leap to ♭3, the only thing the phrase ever *does* — is
the moment it crosses into the other. That is arithmetic on the five measured
pitches from `refine.py`, not a reading imposed afterwards.

The piece is that crossing made structural. The motif is transposed around the
**minor-third cycle F – A♭ – B – D**, which alternates collections at every
step and closes after four. Four notes belong and one does not, in every
section, in both directions.

### The first version ran it straight, and that was wrong

Four eight-bar whole-tone sections, then one pentatonic section at the end:
thirty-two bars — **one minute forty-eight** — with no consonance in it
anywhere. It was hard to sit with, and the interesting part is that measuring
it says the chords were never the problem.

| | Sensory roughness | Spectral flatness |
|---|---|---|
| Nine Shells, first version | **0.224** — 2nd *lowest* of eight cues | **0.0246** — highest of eight, 4× the median |
| score median | 0.78 | 0.0062 |

Roughness there is Plomp–Levelt in Sethares' parametrisation: partials beat
when they fall inside one critical band, so it measures what actually grinds
rather than what looks strange written down. By that measure the whole-tone
harmony was among the *smoothest* material in the game. Two other things were
wrong:

* **It was noise.** `pluck()` is Karplus-Strong — every note begins as a burst
  of filtered noise — and the figuration ran eight notes a bar for all forty
  bars with no rest anywhere. 320 overlapping noise bursts measured 0.081
  flatness on that stem alone. `air()` compounded it by running continuously
  for the whole piece, in the 300–3000 Hz band where hearing is most sensitive.
* **Nothing ever landed.** A whole-tone scale contains no perfect fifth by
  construction, so for 1:48 there was no consonant anchor to rest on. That
  reads as dissonance even when nothing is beating.

### What it is now

Each six-bar whole-tone section is answered by four bars of **major pentatonic
on the same root** — the exact complement, five stacked perfect fifths against
six equal steps — so every centre is stated twice, once floating and once
landed, and relief arrives every twenty seconds instead of once at 1:48.

| Bars | Centre | Ground | The motif there |
|---|---|---|---|
| 1–6 | F | whole-tone, WT1 | F G F G **A♭** ← the A♭ is in WT0 |
| 7–10 | F | pentatonic | F G F G **A♮** — nothing crosses |
| 11–16 | A♭ | whole-tone, WT0 | A♭ B♭ A♭ B♭ **B** ← the B is in WT1 |
| 17–20 | A♭ | pentatonic | landed |
| 21–26 | B | whole-tone, WT1 | B D♭ B D♭ **D** ← the D is in WT0 |
| 27–30 | B | pentatonic | landed |
| 31–36 | D | whole-tone, WT0 | D E D E **F** ← the F is in WT1 |
| 37–40 | F | pentatonic | home |

This is how Debussy actually uses the scale — the whole-tone passages in
*Voiles* are episodes between pentatonic ones, not the substance of the piece.

Three things carry it:

* **The motif follows the ground.** `MOTIF` in the whole-tone bars, where its
  ♭3 crosses out of the collection; `MAGGIORE` in the pentatonic bars, where
  every note belongs. Minor and crossing, or major and home, from one edit.
* **The bass can only put a perfect fifth under the pentatonic bars**, because
  in the whole-tone bars there is not one to use. The anchor is literal.
* **One voicing rule, two opposite results.** `spread()` takes a scale's 1st,
  4th, 2nd and 5th degrees and lets each octave wrap carry. On a pentatonic
  that is a stack of perfect fifths — F2 C3 G3 D4. On a whole-tone scale the
  same indices give F3 B3 G4 D♭5, where the seconds sit two octaves up as
  shimmer rather than at 175 Hz as beating. The first version voiced that
  tetrad closed, as F3 G3 B3 D♭4.

And the figuration became a gesture rather than a texture: `bell()` in the
whole-tone bars (struck cleanly, no noise burst), `pluck()` kept for the
pentatonic bars where a harp is what you want, twice a passage. 88 notes
instead of 320.

Measured after: **flatness 0.0246 → 0.0029**, from the noisiest cue in the
score to the third cleanest, below the median. Roughness 0.224 → 0.267 — i.e.
unchanged, which is the point. Fixing what was actually wrong meant not
touching the thing that looked wrong.

### Why this is the chart cue and not something else

**A whole-tone scale contains no perfect fifth.** It therefore has no root,
no dominant and no cadence available anywhere in it — the harmony can only
slide. That is the correct sound for a screen where you are looking at a
galaxy and choosing where to go next, and it is why the piece has almost no
vocabulary: augmented triads and the 0–2–6–8 tetrad are most of what exists,
so `tetrad()` planes one shape in parallel rather than progressing between
several. Poverty of harmony is the effect, not a shortcut.

### Section V, which is the point

It lands on **F major pentatonic** — the first perfect fifth in five sections
— and `MAGGIORE` (F G F G A♮) fits it exactly, because F, G and A are the
pentatonic's own first three notes.

They are also all in WT1. So the same one-note edit that turns the motif major
is the edit that makes it wholly whole-tone: home and the void are the same
three notes, and the piece arrives somewhere without ever having modulated
away from what it started with.

---

## "Ship's Business" — events

A sonata-form miniature, and the first music in the game with a cadence in it.

### Bar 4

The antecedent stops on **C–E–G–B♭** and the melody stops on E♮. First
dominant in the score, first leading tone used as a leading tone, first phrase
that ends by *asking* rather than by looping. Bar 8 answers it with a perfect
cadence in A♭ major.

This is the one screen where that belongs. Everywhere else you are inside a
run that can end at any moment and an open question is the honest sound; an
event is a specific thing that has happened, in front of you, that you have to
decide about. It should be able to finish a sentence.

### Bars 9–16: eight keys in eight bars

A **diatonic** circle of fifths — F, B♭, E♭, A♭, D♭, G°, C7, F. Diatonic and
not chromatic, so the G is a diminished triad, because F minor has G♮ and not
G♭. That single scale-tone irregularity is what makes the sequence sound like
it is *going* somewhere rather than merely sliding; a chromatic version of the
same figure is Debussy's planing, which is what "Nine Shells" does instead.

The motif is halved (`diminish`) so one statement fits one bar, and it lands
on the root of each new chord as that chord arrives. What modulates is the
tune. Five cues had moved the harmony under a fixed melody; this moves the
melody.

### The two subjects are one note apart

A sonata has two subjects in different keys, reconciled in the tonic at the
end. Here the second subject (bars 17–24, A♭ major) is **`MAGGIORE`** and the
first is **`MOTIF`**.

So the recapitulation's structural job — bring the second subject home — is
done by flattening a single note, and bars 37–40 have both voices playing what
is audibly the same tune in the same key. The form's central drama and the
soundtrack's central fact turn out to be the same statement.

The coda withholds the cadence once (V–VI, C7 → D♭) before giving it, then
puts the motif in the bass under a held tonic so the loop turns over on the
tune rather than on a join.

---

## "Five Ways Home" — title and menu

Theme and five variations. The oldest form there is for the exact problem this
soundtrack has, which is that one whistled phrase has to carry a whole game
without wearing out — and the one place it is honest to do it in the open is
the title screen.

| | Bars | What varies |
|---|---|---|
| Theme | 1–8 | plain, F minor, one voice and a quartet |
| I | 9–16 | ornamental — `appoggiatura` on every note, a `turn` on the ♭3, sixteenths under it |
| III | 25–32 | *(same noise treatment as "Nine Shells": `bell` gestures instead of 64 continuous plucked notes, and the spread voicing)* |
| II | 17–24 | **maggiore: F major** |
| III | 25–32 | whole-tone |
| IV | 33–40 | canon at the octave, two beats apart, back in minor |
| V | 41–48 | chorale, augmented, four parts, cadence home |

### Variation II is the one that matters

A♭ becomes A♮ and the soundtrack is not in a minor key for the first time
since the game booted. Nothing else changes — same rhythm, same phrase
lengths, same bar-by-bar harmonic rhythm. One note.

### Variation III costs nothing

There is no modulation between II and III. F, G and A are already one
whole-tone collection, so the maggiore variation hands III its material
intact; all that changes is what the chord underneath is doing. Instead of
functioning, it planes.

The most classical moment in the set and the most impressionist one are
therefore the same five notes with the same single edit, and the join between
them is not a key change but a change of mind about what harmony is *for*.
That is the whole argument of these three cues in eight bars.

---

## Bar 9 of "Five Ways Home": six faults in one line

Variation I shipped broken and took three rounds to fix, because one line had
six independent faults in it and each round only found some of them. It is the
most instructive thing in this directory, so it is written out in full.

```python
ORNAMENTED = pitches(turn(appoggiatura(MOTIF, 1, 0.32), 4, ...), 'F5')
```

**1 — the index pointed at the wrong note.** `appoggiatura()` doubles a form's
length, so `index=4` was not the ♭3; it was a *grace note of 0.32 beats*, which
`turn()` then divided by four. Four notes of **16.9 ms** in a row.

**2 — the notes were still too short after that.** The corrected leans were
130 ms, which looks fine written down. `whistle()`'s 45 ms attack, 80 ms decay
and 180 ms vibrato ramp are *absolute* times, so below about 250 ms `env_adsr`
finds a+d+r no longer fits and drops to its degenerate branch — **and** the
vibrato is still ramping when the note ends, so the pitch slides the whole way
through. Eight sliding blips across two bars.

**3 — the leaning notes were out of key.** `semitones=1` is a fixed interval,
and a semitone above F in F minor is **G♭**, which is not in the key: it is the
Phrygian ♭2, which is to say it is "Dead Sector"'s note, four of them in a
Mozart pastiche. The upper neighbour of F in F minor is G and of G is A♭ — a
whole step and a half step — so it cannot be a number.

**4 — the whole melody was a step flat.** `pitches(seq, start)` names `seq[0]`,
and an ornamented form does not begin on its own first note; it begins on the
grace note. Passing `'F5'` pinned the *lean* to F5 and dragged everything down
a whole step. Right contour, wrong key, and close to invisible in a table of
note names.

**5 — the ornament was off the grid.** `frac=0.34` is not a sixteenth (0.25)
and not a triplet eighth (0.333). It is nothing. It put every resolution
**38 ms behind** the sixteenths the fortepiano plays underneath, and made the
line alternate 138 and 268 ms. An appoggiatura takes a *notated* fraction of
its note — half of a duple note. `frac=0.5` puts all eight onsets on the
eighth-note grid at 203 ms each.

**6 — the fast ornament was on the wrong instrument.** A turn is four notes at
a sixteenth apiece, and `whistle()` has a 45 ms attack and a vibrato. It cannot
articulate that; four in a row is a stutter. The turn moved to the fortepiano,
which has a 1.5 ms attack and is the instrument the figure was written for, and
the whistle holds the ♭3 plainly underneath — which is also what a singer would
do with it.

Rendered and measured after all six: every onset **+0 ms** against the grid,
every pitch within **±1 cent** of target.

### What is guarded now

* `turn()` and `appoggiatura()` **raise** if they would produce a step below a
  floor in beats, naming the likely cause. (Faults 1 and 2.)
* `whistle()` scales its envelope and vibrato ramp below `synth.SHORT_NOTE`;
  above it every number is unchanged. (Fault 2.)
* `appoggiatura(scale=...)` and `pitches(anchor=...)` exist. (Faults 3 and 4.)
* A short-note scan instruments every voice and reports anything it cannot
  render. A schedule dump prints each stem's onsets against the sixteenth grid
  with the offset in milliseconds — that is what finally located faults 5 and 6,
  after an onset detector run on the audio turned out to be measuring envelope
  ripple and told me nothing.

**Not one of the six raised an exception.** Four were only ever going to be
caught by ear. The render pipeline reports success on a wrong note, a flat key,
an off-grid rhythm and a click alike, and the listener is the only test that
covers all of it — which is the real reason this is written down.

## Engine additions

Three instruments, because a Mozart texture built out of the dread cue's
sour solo `bowed()` and a synthesiser `pad()` would have been a pastiche of
the wrong thing.

| | What it is | Why it is not one of the existing voices |
|---|---|---|
| `reed()` | oboe / cor anglais | A fixed formant near 1.1 kHz, so timbre changes *across the range* instead of transposing with the note. That is what makes a wind instrument sound like a pipe rather than a filtered saw. |
| `strings()` | bowed ensemble, three desks a note | Detuned **and** given different vibrato rates and phases. Detune alone is a chorus effect, which is a much more synthetic sound. `bowed()` is one close, noisy player; this is a section. |
| `hammer()` | fortepiano | Partials sit slightly sharp of the harmonic series (string stiffness) and the upper ones die first, so the tone darkens as it decays. `bell()`'s ratios are fixed, which is most of why a bell is not a piano. |

And four additions to `motif.py`: `MAGGIORE`, `sequence()`, `appoggiatura()`,
`turn()`, plus `whole_tone()` and `pitches()`.

`pitches()` fixes a real latent bug. `octave()` names pitch classes and leaves
the register to the caller, which is fine for a form written inside one octave
in its home key — but transpose that form and the octave boundary moves under
it. `transpose(MOTIF, 6)` is B D♭ B D♭ D, and naming those all in octave 5
turns the motif's rising whole tone into a **falling major seventh**: the
contour, which is the only thing that makes the phrase recognisable, is
destroyed. `pitches()` walks the intervals instead. Nothing before these three
cues transposed a form, so nothing had hit it.

---

## Levels

| Cue | Peak | RMS | Centroid | Character |
|---|---|---|---|---|
| Hard Burn | 0.90 | −10.7 dBFS | 265 Hz | loudest, darkest — a fight is close and low |
| Slow Drift | 0.89 | −12.8 | 281 | the reference |
| Warm Ship | 0.84 | −13.5 | 292 | interior |
| Five Ways Home | 0.87 | −14.3 | 584 | transparent — you follow four voices |
| Ship's Business | 0.86 | −14.9 | 433 | small room, close |
| Poisoned Ground | 0.88 | −15.5 | 345 | |
| Nine Shells | 0.86 | −16.7 | 471 | airiest, and the most evenly spread spectrum in the set |
| Dead Sector | 0.86 | −17.6 | 341 | quietest, and deliberately so |

`DREAD_NOTES` §3 still applies to all eight: **do not normalise these to each
other.** The two classical cues are the brightest in the set by a wide margin
and that is the style working — transparency is the whole point of the
texture, and rolling them off to match the others would remove it.
