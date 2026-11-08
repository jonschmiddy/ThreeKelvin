The reasoning behind `tkg/scripts/systems/HullWear.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Design

Above `static func palette(img: Image) -> Dictionary:`:

```text
Battle damage, drawn rather than drawn ON.

A hull sprite is authored once, intact. This beats it up in proportion to how
close the ship is to dying, by scoring, staining, streaking, holing and
patching the pixels it already has.

IT USED TO BE KEYED ON TIER, and that was two ideas wearing one letter. Tier
grows a ship HARDPOINTS at A and a reactor at S — that is a specification, and
a well-kept ship does not sprout a weapon mount. Condition and specification
are different axes and only one of them belongs on a surface. So the letters
keep the spec and this takes the damage, which is the half that was always
missing: `ShipBuild.damage()` has returned hp-over-max since the convoy strip
needed it, the procedural path spent it on two flat dark rectangles, and the
real-art path ignored it completely — a hull with a sprite looked showroom
fresh at one hull point.

WHY THIS IS CODE AND NOT ART. Seven manufacturers times three weight classes
is 21 hulls, and four condition grades makes 84 sprites. Generating the 63
damaged ones costs about 13,860 PixelLab generations at eleven masked tiles
apiece — near three months of allowance, for hulls alone, before a single
module or enemy or station. Drawn here it costs nothing, on the twenty hulls
that do not exist yet as readily as on the one that does.

THE PROPERTY THAT MATTERS MOST is not the price, though. Every operation below
ends by SNAPPING its result to a colour the sprite already contains, so wear
cannot introduce a colour — measured at 0 new colours on all four grades. The
generated attempts drifted 17 to 41 new colours per tile, and a single pass
over the whole hull invented an entirely new palette and threw away every
amber panel Korvan flies. Arithmetic cannot do that. There is nowhere for a
new colour to come from.

What it is good at is GRIME: soot, staining, streaking, wear. That is most of
what separates a kept ship from a neglected one, and it is exactly the sort of
thing arithmetic does well. What it is NOT good at is spectacle — a torn
opening with ideas in it, where something specific clearly happened. If that
is ever wanted, the cheap answer is a handful of generated wound decals
stamped on top of this, once, and reused across all 84.
```

## Palette check

Above `static func palette(img: Image) -> Dictionary:`:

```text
4x4 ordered dither. Staining has to FADE, and a fade in pixel art is a
pattern, not an alpha ramp — alpha would blend toward colours off the palette
and undo the whole guarantee above.
Every distinct RGB in an image, as a set. Alpha-zero pixels do not count.

This is the measurement behind the ruling that generated art may not drift the
palette: the wear operations are checked by counting the colours before and
after and requiring the difference to be zero. Three contact sheets — FitSheet,
BestiarySheet and WearSheet — each carried a byte-identical private copy, which
is a strange thing for the number that proves the invariant to be.
```

## Damage kinds

Above `enum Substance { METAL, ORGANIC }`:

```text
Twelve kinds of damage, and how many of each a band earns.

The first version of this had five, and all five DARKENED — stain, streak,
gouge, hole, patch. That is one register, and a hull can only get so
interesting while every mark on it is a shadow. `bare`, `buckle` and `weld`
work the other way, lightening toward the metal under the paint, and they are
what stop a wrecked ship reading as a dirty one.

Ordered roughly from atmosphere to event: the grime at the top happens to a
ship that is merely OLD, the wounds at the bottom happen to a ship that was
HIT. A band earns more of everything, but the shape of the list is why a
marked hull looks neglected and a wrecked one looks shot.
WHAT THE THING IS MADE OF. Not called Material — Godot already owns that name
and shadowing it in a class_name script is a debugging afternoon nobody needs.

A weld bead on a whale is nonsense, and so is a riveted patch, and so is
buckled plating. The reverse holds too: a hull does not bruise and it does not
SCAR, because scarring is a thing a body does afterwards and a machine has no
afterwards — somebody has to come and weld it. That asymmetry is the most
useful thing in this enum. It is the difference between damage that happened
TO a thing and damage the thing then lived through.
```

## Organic ops

Above `const OPS_ORGANIC := [`:

```text
Living things, and megafauna in particular. Shares the ops that are about
SPACE rather than about metal — pitting, scorching, cracking, impact — and
replaces everything that assumes a fabricated surface.

`barnacle` is not damage at all and belongs here anyway: the art direction
asks for "barnacles and scars on megafauna" by name, and a leviathan that has
been alive long enough to be shot at has been alive long enough to be lived
ON. `scar` is the other one that is not damage — it is damage SURVIVED, and
it is why an old whale reads differently from a beaten ship.
```

## Damage profile

Above `const MIX := [0.0, 0.0, 0.5, 1.0, 1.0, 1.5, 2.0]`:

```text
What KIND of damage this hull takes, decided once per ship from its seed.

Without this, every ship in the game suffers the same twelve things in the
same proportions and runs differ only in where the marks land — which is
variety of PLACEMENT, and reads as one ship photographed from twelve angles.
Weighting the mix gives a hull a character: this one is pitted and cracked
from a long time in the cold, that one is gouged and scorched because
something shot at it.

Weights are coarse on purpose. A zero means that kind of damage is simply
absent from this ship, which is a stronger statement than "less of it" and is
most of where the variety comes from.
```

## Gouges

Above `static func _gouge(p: Plate, r: Lcg, n: int) -> void:`:

```text
Raking gouges. A strike arrives at a shallow angle, so these run mostly along
the hull with a slight rise — a vertical scratch reads as a panel line and
vanishes into the ones already drawn.

Dark trough, bare metal on the lit lip, and the lip appears in RUNS rather
than continuously: an unbroken highlight at full brightness is a white line
drawn on top of the ship, where metal only shows where the gouge bit deepest.
```

## Holes

Above `static func _hole(p: Plate, r: Lcg, n: int, punch: bool) -> void:`:

```text
Blown open, WITH AN INSIDE.

The first version of this cut an ellipse to alpha and ringed it in black, and
it read as a missing pixel rather than a wound. A hole in a hull is not an
absence — it is a view of the frame behind the plating. So this paints a
cavity: darkest colour for the void, structure running across it, a torn lip
catching light on the top edge and shadow on the bottom.

`punch` is the switch on whether a grade may change the SILHOUETTE. Off, the
opening is painted and the outline is untouched, which is what keeps every
grade the same ship. On, the middle is cut through as well.
```

## Impact

Above `static func _impact(p: Plate, r: Lcg, n: int) -> void:`:

```text
Where something hit. The only COMPOSITE operation: a crater, short gouges
thrown radially out of it, and a burn trailing off downstream.

It exists because the rest of this file draws damage that merely EXISTS, and
a hull wants at least one mark on it that clearly HAPPENED — with a direction
and an order of events. One impact does more for a ship reading as attacked
than a dozen more gouges would.
```

## Op order

Above `static func worn(src: Image, band: int, seed_in: int, punch: bool = false,`:

```text
The public door. Returns a WORN COPY; the source image is never touched,
because it is the catalogue's and every ship in the game shares it.

Order is not arbitrary. Stain and streak go down first so gouges and holes cut
THROUGH the grime rather than being buried under it, and patches land before
the gouges so a plate can itself be scarred — a repair that is still pristine
reads as newer than the ship around it, which is exactly wrong on a C.
```

## Wear seeding

Inside `worn()`, above `for i in ops.size():`:

```text
ONE STREAM PER OPERATION, AND THE BAND IS NOT IN THE SEED. Both halves are
required for damage to accumulate rather than reshuffle.

The band was in the seed and every operation shared one stream, which meant
a ship crossing from marked to mauled drew an entirely different set of
scars — measured at 16% overlap, which is chance. The dent taken at half
hull healed, and a new one opened somewhere else. A hull is a record of
what has happened to it, and that made it a record of nothing.

Seeded per operation rather than per pass so the counts cannot interfere:
sharing one stream, drawing eight stains instead of four would leave the
streaks starting from a different place in the sequence, and they would
move too. Given its own stream, each operation's first N draws are the same
at every band and a worse band simply draws MORE of them.
IN OPS ORDER, which is grime first and wounds last, so a gouge cuts THROUGH
the staining rather than being buried under it and an impact lands on top
of everything. Reordering this list reorders the ship's history.
```

## Wear cache

Above `static func worn_cached(tex: Texture2D, band: int, seed_in: int,`:

```text
Worn, and remembered. ShipView repaints whenever the idle bob moves, so this
is the entry every caller should use — the uncached one is a whole-image pass
and would run several times a second otherwise.

Keyed on the SPRITE's path rather than the hull's, because a looted hull is a
duplicate() of a catalogue frame: same art, different stats, and two of them
at the same grade should wear identically.
```

## Wear bands

Above `static func band_for(damage: float) -> int:`:

```text
How beaten up, as one of four bands. QUANTISED on purpose: `worn()` is a pass
over every pixel in the sprite, and hull points change constantly in a fight.
Four bands means a ship rebuilds its damage at most three times in a run
rather than on every point it loses, and the cache holds all four after that.

The first band is deliberately wide. Losing a few points should not visibly
scar a ship — a hull is not a progress bar, and the first mark ought to mean
something went wrong rather than that the fight started.
```

## Wear seed

Above `static func seed_for(h: HullData, pilot: String = "", run_seed: int = 0) -> int:`:

```text
A wear seed: THE SHIP, THE PILOT, AND THE RUN.

Deliberately not the band — a worse band must draw further along the same
sequence, not a different one, or damage reshuffles instead of accumulating.
Everything else varies, and each part earns its place:

  the HULL, so a Bastion does not wear a Cutter's scars.
  the PILOT, so two Ironsides in one party are two ships and not one drawn
    twice. `ShipBuild.pilot` is already on the wire for the convoy strip.
  the RUN, so the same chassis flown again is scarred differently. This is
    what makes damage feel like something that happened rather than something
    the hull was shipped with.

PASSED IN RATHER THAN READ. `Rng.master` is the obvious source for the run
and this could reach for it directly, but then a headless sheet would render
a different ship on every invocation and there would be no way to ask for a
specific one. The caller knows which run it means.

Co-op holds because every part is agreed: a peer's ship is drawn from THEIR
HullData and THEIR pilot name on YOUR machine, and the master seed is shared
— that is what puts four players in one galaxy. Both machines compute the
same scars for the same ship.
```
