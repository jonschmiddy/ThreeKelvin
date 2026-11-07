The reasoning behind `tkg/scripts/systems/HullFit.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Class bolt-ons

Above `const KIT := {`:

```text
What a CLASS bolts on. The other half of HullWear.

HullWear takes a hull away — scoring, soot, holes. This puts things on it:
vents, sensor blisters, conduit runs, running lights, an antenna. Same
engine, opposite direction, and they compose in that order because a bolt-on
should be able to get shot.

WHY IT EXISTS. DB.TIER_DELTA grants an A-class frame an extra weapon hardpoint
and an S-class one a system mount and the reactor to run it, and until now
none of that was visible: a C and an S were the same picture with different
numbers behind them. A ship carrying more should look like it is carrying
more.

SIZED BY WHAT THE HULL CAN TAKE, not by what would be nice. Measured on the
medium: 1,226 places a 3x3 fits without covering something already drawn, 273
for a 6x4, and 3 for a 10x6. So everything here is small. That is also the
correct answer artistically — a bolt-on is a vent or a blister, and anything
slab-sized is not a fitting, it is a different ship.

Reuses HullWear's Plate and Lcg rather than carrying its own, so the palette
guarantee holds identically: every pixel written here snaps to a colour the
sprite already contains.
```

## Flat spots

Above `static func _room(p: HullWear.Plate, r: HullWear.Lcg, bw: int, bh: int) -> Vector2i:`:

```text
Somewhere this fitting can sit without covering anything already drawn.

FLAT means every pixel under the footprint is the same colour — which is how
a hull says "this is bare plating" without anyone having to author anchors.
The alternative was HullData's weapon_anchors, empty on all 21 frames and
needing a human to place them; this reads the art instead.
```

## Antenna

Above `static func _mast(p: HullWear.Plate, r: HullWear.Lcg, n: int) -> void:`:

```text
An antenna, on the DORSAL EDGE rather than anywhere flat — a mast in the
middle of a hull is a pole stuck through a roof. Walks up from a flat spot
until it finds the outside of the ship, then stands proud of it.

The only fitting that can change the silhouette, which is why S gets it and
nothing else does: the top of a range should read differently in outline.
```
