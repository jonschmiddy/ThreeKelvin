# "Dead Sector" — dread cue

A separate piece, not a remix. Same motif, mutated.

**71 BPM — exactly half of the main theme's 142.** Bar = 3.380 s. Every bar line in this piece lands on a bar line in "Slow Drift", so the engine can hard-cut or crossfade between the two without a tempo match.

Key: **F Phrygian**. 40 bars, 2:18.

---

## 1. The mutation: one flat

| | Notes | Interval rocked | Mode |
|---|---|---|---|
| Original | F **G** F **G** A♭ | whole tone | Aeolian |
| Dread | F **G♭** F **G♭** A♭ | **semitone** | **Phrygian** |

That is the entire change. Scale degree 2 becomes ♭2.

Why it works so hard:

- A rocking semitone is the oldest menace figure there is — it reads as *stalking* rather than *drifting*. The whole tone had somewhere to go; the semitone just grinds.
- ♭2 defines Phrygian, the darkest of the common modes. You get it for free without touching the contour.
- The final leap to A♭ is now a **minor third above the ♭2** instead of a whole step. The motif's one upward gesture got wider and more desperate.
- The pitch shape is preserved exactly, so it still reads as the same theme. Players will recognise it before they can say why it feels wrong.

---

## 2. Dread devices, and where each one is

| Device | Bars | What it does |
|---|---|---|
| **Static tonic pedal** | throughout | F1 drone never moves. Harmony changes above it, so nothing ever resolves. |
| **♭II over the pedal** | 9–16 | G♭maj7 against the F pedal is a **minor 9th** — the single most sour interval in tonal music. |
| **Fragmentation** | 1–8 | The motif appears as two notes only, twice, far apart. Withholding the theme is scarier than stating it. |
| **Polymetre** | 17–24 | A **7-beat ostinato** under 4/4. It realigns every 7 bars, so it never settles inside the section. Instability you feel but can't count. |
| **Tritone** | 25–32 | The last note is dragged from A♭ up to **B♮** — the ♭5. A B1 pedal joins the F1: the *diabolus in musica* sustained under everything. |
| **Detuned shadow** | 25–32 | A second whistle 5 cents flat, half a beat late. Beating, not harmony. |
| **Downward collapse** | 33–40 | Motif sinks F – G♭ – F – **E – E♭**, ending a whole step *below* the tonic. Nothing recovers. |
| **Terminal pitch bend** | 38–40 | The last two notes slide 12 and 55 cents flat. The music itself is failing. |
| **Heartbeat pulse** | 13–36 | Two-thump sub figure, no cymbals. Felt in the chest, never identified as a drum. |
| **Reverse swells** | 23, 31 | Pre-echo before each event — dread is anticipation, not the hit. |

No drum kit anywhere. Rhythm is a pulse, not a groove. The moment you add a backbeat, dread turns into action.

---

## 3. Form

| Bars | Time | Section | What happens |
|---|---|---|---|
| 1–8 | 0:00 | **Silence with something in it** | Pedal + air. Two-note fragment only. |
| 9–16 | 0:27 | **The motif arrives** | Full Phrygian statement, low register, i ↔ ♭II. |
| 17–24 | 0:54 | **Polymetre** | 7-beat cell under 4/4. Motif augmented, floating above. |
| 25–32 | 1:21 | **Tritone** | Impact. B♮ replaces A♭. Peak of the piece. |
| 33–40 | 1:48 | **Collapse** | Everything sinks below the tonic and detunes out. |

Dynamic range is wide and deliberate: section RMS runs 0.09 → 0.20. The loud part is only twice the quiet part. Do not normalise this to match the main theme's level — the headroom *is* the effect.

---

## 4. Stems — `dread_stems/`

Nine WAVs, all 138.2 s, bar-1 aligned.

| Game state | Unmute |
|---|---|
| Something is wrong here | `sub`, `fx` |
| Hull breach / low oxygen | + `drone`, `pad` |
| Being hunted | + `motif`, `pulse` |
| It has found you | + `bowed`, `metal` |
| Tritone / kill state | all nine (`cluster` is the ♭5 stack) |

`pulse` alone under any other music is a usable low-health layer.

**Engine numbers:** beat 0.8451 s, bar 3.3803 s, 8-bar phrase 27.04 s. One "Dead Sector" bar = two "Slow Drift" bars.

---

## 5. Where else the mutation goes

- **Death sting:** just the semitone, F→G♭, on a single low bowed note. 2 seconds.
- **Sector transition:** hold the pedal, swap the mode. F Aeolian → F Phrygian is one note of difference, so you can crossfade the two soundtracks over a common F drone and the change lands as a mood shift, not a music change. That is the strongest cue in the whole set and it costs nothing.
- **Boss reveal:** state the *original* motif (whole tone) over the tritone pedal. Familiar melody, poisoned ground.
