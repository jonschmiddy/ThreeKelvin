# Which cue plays when

Twenty-six cues: a title theme, four run cues for each of five tiers, three battle cues by
danger, a boss cue, and a death cue.

| Game state | Cues |
|---|---|
| Title screen | Title menu |
| EASY run | First Light, Cold Start, Long Way Round, Drift Plane |
| EASY fight | Crosswind |
| ROUGH run | Ghost Freight, Salvage, Cut Signal, Quiet Orbit |
| ROUGH fight | Crosswind |
| HARD run | Red Line, Dead Weight, Cold Iron, Thin Ice |
| HARD fight | Gallop |
| BRUTAL run | Nothing Left, Wrong Ship, Countdown, Attrition |
| BRUTAL fight | Full Burn |
| LETHAL run | Event Horizon, No Air, Sealed, Aftermath |
| LETHAL fight | Full Burn |
| Boss | Last Stand |
| Death | Lights Out, then silence |

Pick randomly among a tier's run cues without repeating the last one. Switch to that tier's fight
cue (a boss gets Last Stand at any depth) when a fight starts and back when it ends; a 2 to 3 second crossfade covers the tempo change.

**Lights Out is not a loop.** It is 70 seconds: 50 of music and 20 of literal silence at the end.
Play it once from zero on death and let it run out, or fade it during the silence. Do not loop it.

## Ordering within a tier

If you'd rather escalate inside a tier than shuffle, safest to most uneasy:

- **EASY:** Long Way Round → Drift Plane → Cold Start → First Light
- **ROUGH:** Quiet Orbit → Salvage → Ghost Freight → Cut Signal
- **HARD:** Dead Weight → Cold Iron → Thin Ice → Red Line
- **BRUTAL:** Nothing Left → Wrong Ship → Attrition → Countdown
- **LETHAL:** Sealed → Aftermath → No Air → Event Horizon

## How the tiers escalate

| | EASY | ROUGH | HARD | BRUTAL | LETHAL |
|---|---|---|---|---|---|
| Tempo range | 68–100 | 71–104 | 60–116 | 52–100 | 46–132 |
| Harmony | major, resolves | minor, keeps turning | unstable, chromatic | clusters and pedals | one chord, or none |
| Deep hits per cue | 0–377 | 5–419 | 46–429 | 5–198 | 0–613 |
| Quietest cue | Long Way Round | Ghost Freight | Thin Ice (in its gaps) | Nothing Left | Sealed |

Two things worth knowing. Tempo stops being the signal above HARD: the slowest cues in the game
are in BRUTAL and LETHAL. And the run cues get emptier as the tiers climb while the fight cues get
denser, so the gap between running and fighting widens the further in you get.

## The fights

Three battle cues by danger (Jon, Nov 10), all in F minor at 142 on the game's phrase
(F G F G A flat), composed in the lab after ElevenLabs takes did not fit the set.

| Fight | Tiers | Tempo | Length | Feel |
|---|---|---|---|---|
| Crosswind | EASY, ROUGH | 142 | 1:08 | the phrase in a skipping 3+3+2, F Dorian; scrappy rather than grand |
| Gallop | HARD | 142 | 1:08 | four falling chords over a gallop bass that never stops |
| Full Burn | BRUTAL, LETHAL | 142 | 1:08 | First Light's phrase as a march, then its turn to F major |
| Last Stand | boss | 132 | 2:00 | the boss: three waves, a phase break, then it tightens |

Close Quarters, Slipstream, Hairline and Overpressure, the fights before these, are still in the
lab and in git but no longer ship.
