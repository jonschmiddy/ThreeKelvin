The reasoning behind `tkg/scripts/systems/Ladder.gd`, `tkg/scripts/ui/LaunchBox.gd` and `tkg/scripts/ui/TierGalaxy.gd`; each heading is referenced from the code by a `Why:` line.

## The ladder

The game had an ascension level (`Run.ascension`, Nov 8: the Hellbender's rung) and
no table of what the levels are. The table is the ladder Jon picked on Nov 7 from the
page in `tk-scratch/ascension/ladder/` (reply `L: s1 s2 s3a d4a d5 d6 b7 b8 b9 T:A`):
three spiral rungs, three disc, three ball, and the torn dwarf, each with a name and
one line of rule. The player's word for a level is Tier, everywhere a player reads
(the box, the tooltips, the flight record); the code, the saves (`ascension` in a
save), the record's key and the protocol keep `ascension`, so nothing old stops
loading and nothing was renamed for its own sake.

Only two rungs do anything yet: the Hellbender flies from tier 7 (`Hellbender`), and
the galaxy takes the tier's form from tier 1 (`Ladder.roll_kind`: the same one draw
from the world stream `_roll_galaxy` always made, among the kinds of that form), which
is Jon's Nov 5 galaxy pick (the others opened by winning) folded into the ladder. Tier
0 still rolls any kind, as every seed did until now: forcing spirals there moved every
seeded world, and six pinned harnesses (TwinSiteTest, WreckSiteTest, StationDeckTest's
seed 9300, FlightTest's twin counts, two SolveTest cases) failed on their pins. Whether
tier 0 should be spirals only, and those pins re-measured, is Jon's call. The other rules are stated on the box and not yet in play; building them is
the ladder's own job.

The unlock rule is the record's: a tier up to one past the best tier won
(`Ladder.best_won`, the `ascension` of a WON entry; an entry from before tiers is a
tier 0 win, so one win opens tier 1). Developer mode opens every tier, as it opens
every manufacturer.

## The galaxy

The box's picture is procedural pixel art, 112 px, animated (Jon's v2, Nov 9): the
body is a shader (`tier_galaxy.gdshader`, the dithered glow in whole pixels, six
levels and a 2x2 ordered dither, the galaxy's shape by form, a pulse, a glare streak,
a soft round window), and the stars and flares are drawn over it by `TierGalaxy` on
a 30 Hz clock, whole-pixel points moving smoothly, twinkling at the tier's rate.
Everything rises with the tier: the turn, the twinkle, the pulse, the flares, the
glare, and the hue from the spiral's cool blue through the disc's amber to the ball's
red; tier 10 is the big spiral eating the dwarf, a stream of stars between them and
a stuttering pulse. The stars are seeded per tier, so the same tier shows the same
galaxy every time the box opens.

## The box

LAUNCH A RUN keeps its width and grows down, on three columns (Jon's v3, Nov 10:
"the bottom half kinda doesn't line up"): L the text edge (the heading, the TIER
label, the galaxy, LAUNCH's border), C at L + 112 + 14 (the stops, TIER N, its name
line and rule, SEED), R the right text edge (the last stop, the end of the seed
field). The buttons sit 12 px under the galaxy and the box ends 12 px under them;
LAUNCH, NOT YET, SEED and its field share one row. The eleven stops are the things
you click: the current one outlined in its kind colour, an open one plain, one past
best + 1 dim and dead (a click on it is refused with the denied sound). The pick is
remembered across opens (`LaunchBox.last_tier`) and clamped to what is open; the
seed field behaves as it did. A fresh profile still skips the box
(`LauncherScreen.fresh_profile`) and launches at tier 0.
