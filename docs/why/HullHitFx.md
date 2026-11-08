The reasoning behind `tkg/scripts/ui/HullHitFx.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Hull hit looks

Above `const GLOW_HZ := 12.0`:

```text
A SHIP'S HULL TAKING HITS WITHOUT HOLES IN IT (Oct 17). Three looks were made
for Jon's pick and he picked the fourth, D, all three mixed per hit: it is the
game's (`ShipHitFx.look`); A, B and C stay as its parts and as looks to compare.

James, a playtester, of today's marks: when ships are damaged they get big
holes in the hull, and ships can't really have holes in them. Jon: "Can we
update the damage shader to be more realistic and prettier?" What read as a
hole was measured, not guessed: Chain's bite (a near-black disc 9 to 17 px
across on a full sheet, its pixels flown off as chips), the vent's punched
disc, and the black-brown core of every soot disc, which on a dark hull is the
same colour as space. So every look here is armour taking punishment, and
nothing in it is see-through or punched out to space:

  A  BATTLE-WORN PLATING. Dents (the plating's own shading bent: shadow under
     the top of the dish, light on its floor, a raised lip), soot streaks
     thrown from the blast, paint scraped back to the metal, popped rivets
     along a lifted panel line. Grounded and quiet; at low hull, split seams
     at the edge sputter vapour.
  B  HEAT AND STRESS. Every impact leaves a heat bloom on the plating that
     cools white, orange, dull red, then a dark scorch over about four
     seconds; under 60% hull the hull's own panel lines glow where the hits
     are, more of them the lower it goes, throwing sparks.
  C  PLATES CRACK AND PEEL. A big hit tears a plate and curls it back over its
     hinge, showing the ribs and stringers under it (lit and shadowed, never
     empty); a small one cracks a plate along its panel lines. Under half
     hull, each breach sputters vapour and throws sparks.
  D  ALL THREE, MIXED PER HIT (Jon: "What would battleworn + heat + stress
     and crack and peel look like together?"), as a creature's hits mix
     wounds, bruises and shed. Small hits lean to A's dents and scrapes and
     C's knocked panels, big ones to B's blooms and C's peels; every hit
     also gets B's bloom cooling to a scorch (smaller on a small hit), the
     mark that reads on a dark hull. Low hull brings B's glowing lines, C's
     breaches and A's split edges together, each held down (fewer lines, the
     newest three breaches and two splits) so it stays quieter than today's.

THE SAME RULES AS EVERY MARK SINCE: on the hull's own pixels, never its
outline (the silhouette never changes); every colour is one the sprite
already has (`_snap`, HullWear's guarantee) or the heat ramp; light has a
falloff in held steps with dithered edges, and whatever glows changes shape
twelve times a second (`GLOW_HZ`); a mote that leaves the hull stays inside
the shield's oval (`ShieldFx.fit`, which the pack layout keeps clear of the
words, name and bars). Each hit is rolled from the fight's seeded stream as
today, so two machines draw the same marks; what moves with time alone (a
spark, a puff) draws from its own stream so it can never move a mark.

The marks are `marks()` like today's, so a wreck and a death keep them.
```

## Hit placement

Above `func _pick(edge: bool, rad: float, near: Vector2 = Vector2.INF, around: Vector2 = Vector2.INF) -> Vector2i:`:

```text
Where a hit lands: the best of sixteen fair candidates on the hull, leaning
to the side the shots come from and to plating light enough for a mark to
show (the 3x3 round it, so a dark seam is not mistaken for dark plating),
and clear of the marks already there. `edge` on the outline (a split vents
into open space above or below), `near` as close as it gets to a screen
point, `around` a mark's width or so from a hit (an extra).
```

## Knocked plates

Above `func _knock(p: Vector2i, big: bool) -> void:`:

```text
A plate knocked out of true: the panel it struck (bounded by the hull's own
panel lines) sags a pixel down or is driven a pixel back from the shot. The
strip it uncovers is the frame under it, in shadow; its leading edge rides
over the seam beyond and throws a shadow of its own; its trailing edge is lit.
A short crack from where it struck. Where no panel line bounds the plate
near the hit, it cracks instead (`_plate_crack`).
```

## Glow stepping

Above `func _build_glow(step: int) -> void:`:

```text
The light on the plating, GLOW_HZ times a second: every bloom and glowing
line as heat, a pixel's heat jittered and the dither shifted each step, so a
glow's edge changes shape twelve times a second and no faster. A step that
happens to come out as the last one is jittered again, then flickered dimmer
(a small ember can come out the same), so while anything glows, every step
moves.
```
