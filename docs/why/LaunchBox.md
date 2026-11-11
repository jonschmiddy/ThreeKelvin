The reasoning behind the tier stack on LAUNCH A RUN, drawn by `tkg/scripts/ui/LaunchBox.gd` and `tkg/scripts/ui/TierGalaxy.gd`; each heading is referenced from the code by a `Why:` line. The box itself is `docs/why/Ladder.md#the-box`.

## The stack

Jon's pick on Nov 11, "T-A and T-C", from the tier stack page
(https://claude.ai/artifact/AbkrXZ5YG3KppYHqSpd4JK; the mockups and their box test
in `tk-scratch/ui-build/tierstack/mock.py`). The question was how to show that a
tier keeps every lower tier's rule (`docs/why/Ladder.md#the-stack`). The box stays
the same size at every tier.

T-A, the ladder fills. Stops 1 to the current tier are lit: each filled with its
own kind colour at 26% over the panel and edged at 60%, the current one at 42% with
its kind colour for an edge and a near-white numeral. A 4 x 5 px bridge joins each
lit stop to the next one, in the next stop's kind colour at 60%. The bridges sit in
the 4 px gaps, so they are drawn by the box under the stops, not by a stop past its
own rect. The cool, amber, red and hot runs of the bar show where the galaxy changes
form. Stop 0 is never lit, since tier 0 has no rule. Under the rule, in CHILL, one
line says the lower tiers still apply (`Ladder.still_line`), 12 px under the rule's
last line, as the rule's own lines are spaced. At tier 10 the rule takes three lines
and this line ends 34 px above the buttons.

T-C, the galaxy wears them. A faint 1 px ring (radius 52, `RING`) runs round the
galaxy under its glow, drawn with the far stars, so it shows only where the galaxy
is dark, as in the mock, which drew it only on pixels darker than 40. Ten lamps sit
on the ring, clockwise from the top, lamp k for tier k's rule. Each is a 3 x 3 core
in a 5 x 5 dark rim, drawn over the glow (`TierGalaxy.Lamps`, a child after the
body). A lit lamp is its rule's kind colour; the current tier's lamp has a white
heart and four glints, and an unlit one is slate. The mock's radius was 54 on a shot
drawn at about 1.027x the code's size; 52 keeps every rim inside the 112 px picture
(2 to 110). The galaxy takes the pointer, and its tooltip is the game's tag
(`TagLayer`) with a rich body (`TierGalaxy.RulesTag`) on the tag plate: "8 RULES IN
FORCE", then each rule by number in its kind colour and name, newest first, the
current one in ICE. At tier 0 it says NO RULES IN FORCE. The tag sits where every
tag sits, above the thing pointed at (`HoloTag.place`), where the mock showed it
beside the pointer.
