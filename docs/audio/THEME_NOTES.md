# "Slow Drift" — main theme

Built from the whistled motif in `New_Recording_2.m4a`.

---

## 1. What the source gave us

| Measured | Value | What it became |
|---|---|---|
| Pitches | 1395 / 1570 / 1413 / 1557 / 1646 Hz | F6 G6 F6 G6 A♭6 |
| Scale degrees | — | **1 – 2 – 1 – 2 – ♭3** |
| Note spacing | 0.42–0.43 s | **142 BPM**, quarter notes |
| Last note | 0.55 s + vibrato | Half note, ~5 Hz vibrato (kept in the synth patch) |

Two facts drove every decision that follows:

**The motif never touches the fifth.** It oscillates 1–2 and then leans up to ♭3. There is no dominant, no leading tone, no cadence built into it. It is a question with no answer — which is what you want looping behind a run that can end at any moment.

**Scale degrees 1, 2, ♭3 belong to five different modes.** F Aeolian, F Dorian, F Phrygian (no — Phrygian needs ♭2), F minor pentatonic, and as colour tones over a dozen chords. So the motif can be recoloured without ever being rewritten. That is the whole arrangement strategy.

Key: **F minor**, 4/4, 142 BPM, 72 bars, 2:04.

---

## 2. Motif transformations used

Standard developmental toolkit — each one appears in the track:

| Technique | Where | Result |
|---|---|---|
| **Statement** | Intro, bar 1 | F5 G5 F5 G5 A♭5, dry-ish with ping-pong delay |
| **Transposition (register)** | A, bar 9 | Same octave as the statement — singable lead range |
| **Reharmonisation** | A, all | Notes stay fixed; the chord under them changes every 2 bars |
| **Inversion** | B, bar 25 | Intervals mirrored: F E♭ F E♭ **D** — the D natural forces Dorian |
| **Augmentation** | Bridge, bar 41 | Same notes, doubled durations — half-speed, weightless |
| **Canon at the octave** | A′, bar 49 | Second voice enters 2 beats late, one octave below |
| **Octave doubling** | A (2nd pass), A′ | Bells restate the original F6 register on top |

The intro was in the original F6 register — the measured pitch of the whistled
source, §1 — and is an octave down as of the recorded instrument set. A
near-sine at 1397 Hz is distant; a piccolo at 1397 Hz is *piercing*, and eight
bare bars is a long time to be sure which one you meant. The statement itself
is unharmed: the bell doubling and the outro's last word both still sit at F6,
and the outro is the one that carries it, because the cue ends on the
recording's own pitch. Reverting is one digit in `arrange.py`'s intro loop.

---

## 3. Reharmonisation — the core trick

The five notes sit over a rotating **i – ♭VI – iv – ♭VII** cycle (2 bars each). Same melody, four different emotional colours:

| Chord | F is | G is | A♭ is | Feel |
|---|---|---|---|---|
| **Fm** (i) | root | 9th | ♭3rd | home, stable |
| **D♭maj7** (♭VI) | 3rd | **♯11** | 5th | Lydian lift — wonder |
| **B♭m7** (iv) | 5th | **13th** | ♭7th | Dorian — motion, drift |
| **E♭** (♭VII) | 9th | 3rd | **11th** | suspended, unresolved |

The G is the pivot. It is a plain 9th over Fm and a ♯11 over D♭maj7 — the same whistled pitch turns from "safe" to "strange" with no change in the melody. That is the sound of the same ship in a different sector.

**B section** swaps to F Dorian (D♮ instead of D♭): `Fm9 – B♭ – A♭maj7 – E♭6/9`. Raising the 6th degree is the single cheapest way to move minor from *bleak* to *adventurous*. It is why Dorian is all over space and sea-voyage scoring.

---

## 4. Form

| Bars | Section | Layers running |
|---|---|---|
| 1–8 | Intro | whistle only → pad enters bar 5 |
| 9–24 | A | + sub bass, half-time drums, bells on 2nd pass |
| 25–40 | B | + 16th arpeggio, full drums, Dorian, motif inverted |
| 41–48 | Bridge | drums out, augmented motif, D♭maj7 → Cm |
| 49–64 | A′ | tutti, canon, driving kick |
| 65–72 | Outro | strip back to the bare F6 whistle |

Drums are **half-time in A and full-time in B/A′** at the same 142 BPM. The tempo never changes; only the density does. This means every section is beat-locked and any two can be cross-faded in a game engine without a tempo match.

---

## 5. Stems for adaptive playback

`stems/` holds 8 beat-aligned WAVs, all 124.7 s, all starting at bar 1. Layer them vertically:

| Game state | Stems to unmute |
|---|---|
| Menu / title | `whistle`, `pad` |
| Idle in ship, map screen | + `bass`, `fx` |
| Exploring a sector | + `arp`, `bell` |
| Enemy contact | + `lead` |
| Combat | + `perc` (all 8) |

Because the harmony is a fixed 8-bar loop, you can also cut A (bars 9–24) or A′ (bars 49–64) into a seamless 8-bar loop for indefinite exploration and only jump to the through-composed material on events.

**Useful numbers for the engine:**
- Beat = 0.4225 s, bar = 1.6901 s
- 8-bar phrase = 13.52 s (quantise all transitions to this)
- Loop point candidate: bar 9 → bar 25 (A repeats cleanly)

---

## 6. Ideas from here

- ~~**Stinger:** the motif's last two notes (G→A♭, a semitone) as a 0.5 s rise for level-up or item pickup.~~ Built as `ui_confirm` in `sfx.py`.
- **Death cue:** the motif with the ♭3 flattened again to G (F G F G **G**) — collapses to a flat oscillation, no lift. (`death_sting` uses the dread cue's F→G♭ instead; this variant is still unbuilt.)
- ~~**Boss:** transpose the whole cycle down to E♭ minor and put the motif in the bass; keep the whistle on top so it clashes at the ♯11.~~ Built — **"Poisoned Ground"** (`boss.py`), bars 9–16. `transpose(MOTIF, -2)` on bowed strings while the whistle holds the original pitches, so its G♮ grinds against the bass's G♭ for eight bars. See `CUE_NOTES.md`.
- **Procedural variation:** the reharmonisation table in §3 is a lookup. Pick a chord per sector at run time and the same melodic asset re-colours itself. Four chords is four sector moods from one 6-beat sample.

Two things §1 and §3 turned out to be load-bearing for later cues:

- **The motif never touches the fifth**, which §1 calls a question with no answer. That leaves the soundtrack one unused card, and it is spent exactly twice: **"Warm Ship"** answers with the C (`ANSWER`), **"Poisoned Ground"** answers with the B♮ (`FALSE_ANSWER`). Nowhere else does the phrase finish.
- **§2's transformation table is the whole method, and it was under-used for five cues.** Everything up to "Poisoned Ground" reharmonised a static F; nothing transposed, sequenced or modulated. Measuring the result: the first five cues between them use eleven pitch classes and never once sound A♮, so the major mode was mechanically unavailable to them. `DEVELOPMENT_NOTES.md` is the three cues that fix that.
- **The ♭VI colour** in §3 — where the G becomes a ♯11 and the phrase reads as wonder — is the whole harmonic premise of "Warm Ship", which starts on D♭maj7 and walks home rather than starting at home.
