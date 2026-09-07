# The bank

Card art that was **wrong for its card but too good to delete**. A take lands here
by a `store` verdict on a review bench, not by being second-best: the question is
never "is this the runner-up", it is "would I be sorry if this were gone".

Every entry is 92x60, full-bleed, opaque, already posted through
`tools/card_batch.py` (palette snapped, no background to strip). That is also the
shape an **event illustration** wants, and Phase 8 has 90 authored event options
with no art at all — so the bank is a supply, not a graveyard.

`*.raw.png` beside an entry is the untouched generation, kept because posting is
lossy and a re-post under a changed rule needs the original. The zero-cost-seam
and fractional-resample findings are both cases where the raw was the only way back.

**Prompts are not recorded for entries 01-02.** They were generated before
`card_batch.py` logged prompts, and I am not going to reconstruct from memory and
present a guess as a record. Everything banked from here carries its prompt.

| # | from | why it was stored |
|---|---|---|
| 01 | `rack_and_load` take 2 | the only take in a round of 23 that was not cut outright |
| 02 | `auspice` take 1 | the take the other three Auspice options were measured against |
| 03 | `resonance` take 1 | a standing-wave readout; reads as UI on a card, but real as a screen or an event |
| 04 | `sympathetic_burst` take 1 | the quiet version of the take that won |
| 05 | `walking_fire` take 1 | a craft firing a heavy beam, planet behind — a strong ship-firing picture |
| 06 | `walking_fire` take 2 | a craft trailing a long white plume; reads as speed |
| 07 | `walking_fire` take 3 | a craft firing over a moon with debris |
| 08 | `walking_fire` take 4 | a craft venting hard with red fire down one side; a ship in trouble |
| 09 | `walking_fire` take 8 | a craft with a bright burst amidships against a nebula |

## What this is for

`python tools/card_batch.py --wanted` prints the OPEN cards beside this list, and
`--install <entry>.png <card_key>` puts any of them on any card. Five of the nine
are craft-firing-in-the-void pictures from one round, which is a shape several
weapon cards want and only one of them was briefed for.

The five stored on 2026-09-06 all came from a single instruction: *"maybe another
card might generate the art for ripple_fire"*. That is the bank's actual job — a
picture is made for one card and lands on another.
