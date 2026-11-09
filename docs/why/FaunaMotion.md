The reasoning behind `tkg/scripts/ui/FaunaMotion.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Fauna motion

Above `enum Kind { CUSTODIAN, CALF, LEVIATHAN }`:

```text
THE THREE THAT ARE NOT SHIPS MOVE ON THEIR OWN (Oct 13). Jon: "The custodian
and the megafauna should get their own movement animations :) Not
thrusters." Every ordinary ship burns an engine flame (`ThrusterFx`); The
Custodian, the Voidwhale Calf and the Void Leviathan move instead. Jon picked
from three ideas each (fx/fauna-motion's films): "custodian:A leviathan:B
whale:B", and for the calf "i really like the movement of breathe but the
lights of glow".
  - THE CUSTODIAN, BREATH: its octahedra drift apart along the spine and
    back, a pixel or two each, out of step; its orange pinpoints pulse in a
    wave that runs along the spine. Charging pulls the pieces in tight, runs
    two light waves into its heart and fills the heart with the cold charge.
  - THE LEVIATHAN, BREATHE: the body swells up to two pixels, the belly
    first, the swell running head to tail with a slow pulse of the belly
    lights; the flippers drift back with each breath; a ripple lifts the
    back crystals one after another.
  - THE CALF, BREATHE'S BODY AND GLOW'S LIGHTS: the same swell and spine
    ripple, and two packets of light chasing down the belly head to tail.
  - A creature's strike (`strike`, 0.35 s before its attack is fired, Jon's
    "windup:B"): a deep in-breath, the spines bristling; the Leviathan's
    belly lights flare, the calf's light runs back up to its head and
    blazes; then the shot.

THE PICTURE IS NEVER REDRAWN OR TURNED. Rotating pixel art shimmers, and an
AI animation of a whole picture boils (memory turn-pixel-art-in-whole-pixel-
steps, animate-image-redraws-the-whole-picture). Each picture is cut ONCE
(`cut`, on a worker thread: pure CPU work, its textures owed until `attach`
pays them on the main thread -- `OffThread`) into the parts it already has, and only the
parts move, in whole pixels, on held steps (8 or 12 a second):
  - THE CUSTODIAN into its octahedra: their apexes are the dips in its top
    edge and they all sit on one equator (the silver spine), so each is a
    diamond; a pixel belongs to the biggest diamond holding it (the big ones
    read as nearer), and each piece is filled in behind its neighbours from
    its own nearest pixels, so a piece that moves a pixel or two uncovers
    more of the piece behind it, never a hole. Its pinpoints are the warm
    pixels sitting in dark glass (too pale for `ShipBreakup._is_glow`), cut
    into their little star clusters, each riding its piece.
  - THE CREATURES in one small shader: a medial line per column (a swell
    parts the body there, the belly half dropping, the back half rising),
    their spines (the calf's are its thin lines, what a 3x3 opening of the
    silhouette loses; the Leviathan's are the pale crystal blobs along its
    back), the Leviathan's two hanging flippers (below a belly line drawn
    between them), and their lights (`ShipBreakup._is_glow`'s, the pixels its
    creature deaths dim).

LIGHT IS DRAWN AS LIGHT (memory draw-light-as-light): every glowing pixel is
the dark body plus its own light added back at a level, and above level 1 it
gathers a halo, added in 4x4-ordered-dither eighths, on the body only. At
level 1 with no halo the sum is the picture. The Custodian's charge is
`EnemyArt._pool` to the dither: the same falloff, colour and strength, at
the same point, so a full charge here is the charge the still picture has.

REST IS THE STILL PICTURE. `settle()` (`SectorScreen._prebuild_death`, ten-
odd frames before the breakup is cut) walks every offset back a pixel a
frame and every light a step a frame; it is at rest in four frames or fewer
and then draws the still picture itself, which is what the death cuts from.

THE BOB is the slot's 2 px (`EnemySlot.BOB_AMP` / `BOB_HZ`), but taken from
here (`bob_px`), on the motion's own steps: a bob step one frame and a part's
step the next put pixels back where they were, one-frame flip-backs of 0.1-
0.4 x1e-4 a frame against today's 0.011 (measured on fx/fauna-motion).

HALF SIZE (a pack of three or more draws each ship from its half sheet,
`EnemyArt.draw_scale`): `pic_scale` 0.5 halves the moves (never under a pixel)
and the cut's own measures.
```
