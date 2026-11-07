The reasoning behind `tkg/scripts/ui/FaunaHitFx.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Creature damage

Above `var body: FaunaGuard.Body`:

```text
DAMAGE ON A CREATURE (`FaunaGuard`). Jon: "the damage to the void leviathan
and voidwhale calf should be more organic... not ship damage", and of the
three ideas, "damage:A+B+C (all wounds! they're sick)": every hit is one of
three KINDS, rolled from the fight's seeded generator the way a ship's hit
marks roll theirs (`roll_organic`), and they build up together. Every mark
is baked into the picture the motion is cut from (`marks()`, as the ship
marks are), so it swells and dips with the body; what moves on it (a
wound's pulse, a dying light) is drawn through the motion's own table; what
comes off it (drops, scales, vapour) flies free.
  WOUND   the hide tears in a slit along the body, glowing tissue inside,
          the torn lip lit above and dark round it. Every wound pulses with
          one heartbeat, quicker as the hull goes; each weeps a drop of ichor
          now and then, more often when badly hurt. A hit splashes ichor.
  BRUISE  the hide bruises purple-dark round the hit.
  SHED    a patch of scales chips off and tumbles away, raw pale skin under
          it, cracks running from its edge; a crystal or spine near the hit
          snaps and falls.
Whatever the kind, two things build with the hull lost: the creature's own
lights flicker and die round each hit (more the bigger it was, nearest
first) until near death it is nearly dark, a dead light sparking back now
and then; and under 45% it trails a pale vapour from its raw patches (or,
with none yet, from its marks).
ONE PICTURE, SO NO FIGHTING: the marks are one baked image, each kind
leaving tissue (a wound, raw skin) alone -- a bruise or a shed goes round a
wound, a wound may open on a bruise or on raw skin -- and nothing that moves
is drawn on a pixel a later wound has opened.
The hit's white flash (the art's) and the numbers stay as they are.
```
