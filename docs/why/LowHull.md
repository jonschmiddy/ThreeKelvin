The reasoning behind `tkg/scripts/ui/LowHull.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Low hull warning

Above `enum Preset { SUBTLE, MEDIUM, STRONG }`:

```text
THE HULL IS FAILING, AND THE SCREEN KNOWS (Jon, Oct 20: "When you are low
health, can you have all the text kinda glitch a bit? Maybe with the screen
turning red? I don't want it to be too overt. Just kinda like a gentle
warning state." And then: "Maybe even A.S.H.'s voice could glitch a bit?").

WHEN: the hull at or under TIER1_AT of its max (a second, slightly stronger
step of the red at TIER2_AT), read as the HUD reads it -- the figure the fight
has SHOWN, not the one the click already decided (`SectorScreen.shown_hull`,
`OutcomeRow.held`) -- so the warning arrives with the number that says so.
Only inside a run: never on the title, the lobby, the hull pick, RUN ENDED or
the records room from the title, and never once the hull is at 0 (the
ship's loss has its own picture, `DeathHandoff`). It eases in and out over
EASE_S as the hull crosses the line either way; a repair clears it.

WHAT:
  * THE RED, drawn over the finished frame (`low_hull.gdshader`, on a
    CanvasLayer of its own at LAYER: above the screens and the HUD, under the
    escape menu): a faint red at the picture's edges, breathing (BREATH_S a
    cycle), never reaching the middle of the screen. Its two steps are the
    preset's `red`.
  * THE WORDS DECODING BADLY (`HullScramble`; Jon: "I think the text should
    glitch more like the decoding. It should be ALL of the text on the
    screen. With it getting worse as the health lowers."): letters all over
    the screen flip to `SignalText`'s noise for a moment and resolve back.
    NOT IN STEPS: `depth` runs from 0 at TIER1_AT to 1 at no hull, eased over
    EASE_S, and the scramble's rate, run and hold follow it; the preset's
    `scr.most` and `scr.share` are its ceilings, so it stays readable at 5%.
    The hull readout scrambles too (Jon: ALL the text); the escape menu never.
  * HER VOICE: A.S.H.'s lines while it is on stutter, drop out, chop and
    crackle (`voice_plan`, rendered by `VoiceGlitch`), more and longer as the
    hull falls, by the same `depth`; her portrait slips in step (`AshPortrait`).

NO SOUND OF ITS OWN. The game has no low-hull sound and this adds none: the
heat warning (`heat_warn`) is the only alarm the ship has.

REDUCED MOTION (`Router.animating()` false): no scramble and no breathing --
the red stands still at REDUCED_RED of its strength -- and her voice glitches
at the SUBTLE preset whatever PRESET is (a sound does not move on screen, so
it stays, at its quietest).

THE STRENGTH IS ONE CONSTANT: PRESET, from LOOKS. `-- lowhull=subtle|medium|
strong` overrides it for a film.
```

## Presets

Above `const LOOKS := {`:

```text
Per preset.
  red     the red at the very edge, (tier 1, tier 2) (`low_hull.gdshader`)
  breath  how far a breath takes it down, as a share of itself
  scr     the words (`HullScramble`), each pair (at TIER1_AT, at no hull):
            rate   letters' runs started a second, across a screen of
                   `HullScramble.REF_LETTERS` letters (more on a fuller one,
                   fewer on a bare one), followed as depth^1.5: rare near the line
            run    the longest run, letters (1 at the line, this near 0)
            hold   how long a letter stays noise, s
            most   the ceiling: letters scrambled at once on the whole screen
            share  the ceiling for one text: of its letters, at once
  voice   her lines (`plan_for`), each pair (at TIER1_AT, at no hull):
            rate   glitches a second of her words
            len    each window's length, times its kind's (KIND_LEN)
            amt    how hard each bites (`VoiceGlitch.apply`)
```

## Voice glitches

Above `const MIN_APART := 0.14`:

```text
WHERE HER LINE GLITCHES (Jon, Oct 20, on the first take of this: "I don't
hear A.S.H.'s voice glitch that much"). Heard at the line already -- a
stutter or a chop first in every line -- and more of them, longer, with the
crush, the ring and the wobble joining, as `depth` goes to 1.

SHE STAYS UNDERSTOOD: a dropout or a stutter replaces what she said, so it
is never longer than KIND_MOST (110 ms: under a short word); the chop, the
crackle, the crush, the ring and the wobble keep her words under them. At
least MIN_APART between two, and never more than MOST_SHARE of a line.
Inside her words only: after the take's 30 ms lead-in (and a little) and
before its trailing silence.
```

## Tags

Above `const WORN_AT`:

```text
The tooltips wear with the hull (`HoloTag`, Jon, Nov 11): "G2 above 50% hull;
at 50% hull and below they move to G3, and at 30% and below to G4, easing in
with the red edge. They go back to G2 when you repair. G5b when under 15%."
WORN_AT 0.50 is at or under, like the tiers; DIRE_UNDER 0.15 is strictly
under, as he said it (6 of 40 is G4, 5 of 40 is G5b). `worn` and `dire` ease
like `on` (EASE_S on the game's clock) and change no red: G3 comes before the
red edge exists. Off in the title, at 0 hull and out of a run, as the rest.
```
