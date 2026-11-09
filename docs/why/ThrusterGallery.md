The reasoning behind `tkg/scripts/sim/ThrusterGallery.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Thruster gallery

Above `const ENEMY_SKIP := ["custodian_tetra", "whale_fan", "leviathan_lev_spine"]`:

```text
EVERY SHIP IN THE GAME WITH THE CODED FLAME (Jon, Oct 13: "Can I see these
thrusters for EVERY ship in the game?"). Look A, dynamic, with sparks: the
one he picked.
  godot --path . --windowed --position 3840,0 -- sheet=ThrusterGallery out=<dir>
      [groups=player,pool,enemy] [frames=75]
One contact sheet per group at 1x, every ship labelled, `frames` at IDLE then
`frames` at FULL, into out/<group>/f_####.png with layout.json (each ship's
tile, its engines, its checks). The groups:
  player  every Korvan hull sprite (light/medium/heavy x C/B/A/S), rigged;
  pool    every PixelLab pool ship (art/subjects/ships, ship_*): LOCAL's
          traders and subjects;
  enemy   every enemy picture in art/sprites/enemies but the Custodian, the
          Voidwhale Calf and the Leviathan (they get their own movement).
CHECKS, per ship: player hulls run ThrusterSheet's nozzle/bell/particle check
against their strips; every ship counts flame and particle pixels on its hull
(must be 0), and flags engines that look wrong: none found, an engine far
forward of the stern (a window or a tower, not a nozzle), or a flame whose
stream runs into the hull (most of its length blocked).
```

## Flame room

Inside `_film()`, above `tw = maxi(tw, im.get_width() + (76 if player else 136))`:

```text
Room for the longest flame and its sparks, so no ship's flame reaches
into its neighbour's tile: a player hull's canvas carries some at the
stern, given 60 more; a pool ship or an enemy gets 128 behind it. (At
76 the Rustjaw hulk's flame burned across the net ship's nose, and Jon
asked what the flame on its front was.)
```

## Nozzle fit

Above `func _fit_check(fx: ThrusterFx, img: Image, entries: Array) -> Array:`:

```text
A HAND-PLACED ENGINE FITS ITS NOZZLE (Jon on the domes ship: "Doesn't quite
fit nozzle"). The opening at the placed column: the contiguous rows round the
entry's middle whose hull edge is within 2 px of the deepest (not rows
another engine of the ship claims; a `port` entry is its own opening). The
flame's start: how many of those rows it lights right at their own edge (on
the outline, the edge or one past), on its worst loop frame at full burn. It
fits when that is at least 90% of the opening.
```

## Engine diagnosis

Above `func _diagnose(fx: ThrusterFx, img: Image, used: Rect2i, player: bool) -> Dictionary:`:

```text
What can be measured about a ship's engines without looking at it:
  engines    each nozzle's rows and where it sits;
  on_hull    flame (every loop frame, idle and full) and particle (five
             seconds) pixels on the hull's opaque pixels -- must be 0;
  flags      none found; a nozzle more than 15% of the hull's length
             forward of its stern; a stream that is mostly blocked by hull.
```
