The reasoning behind `tkg/scripts/ui/EnemyArt.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Enemy art

Above `var _used: Rect2i = Rect2i(0, 0, 240, 120)`:

```text
Procedural enemy sprites. Ships get riveted industrial plating; fauna get
dithered organic segments. The Hulk's "winding up" telegraph lights its ram
prow — art and mechanics doing the same job.

Everything below obeys ART_CONTRACT's two-plane rule, and `_hull` is that
rule written once: a lit top face, a bright lip, a front wall falling away
into shadow, and a 1px ink outline around the silhouette. The first version
of these sprites filled rectangles with one flat colour each, which is why
the Hulk read as a brown box with three orange boxes on it and the fauna read
as a bar chart. The shapes were never really the problem — nothing was
lighting them, and every silhouette was a rectangle because a rectangle is
what `px()` draws.

So the two things this file adds are a ramp and a profile. A ramp is six
value stops out of ART_CONTRACT section 3, spaced widely enough to survive
being looked at from across a screen. A profile is a handful of control
points that `_hull` tapers between, so a hull can be a shape.
```

## Engine flame

Above `const NO_FLAME := ["custodian_tetra", "whale_fan", "leviathan_lev_spine"]`:

```text
THE ENGINE FLAME (look A, Jon's pick, Oct 13): a live enemy with a picture
idles its engines, found on the picture or placed by hand in art/engines.json
(`ThrusterFx.for_picture`). Not on a coded drawing (it has its own stern
wash), not on a dead ship, and not on the three that get their own movement
instead of thrusters (NO_FLAME).

Drawn by `_flame_layer` outside this control, which is clipped to the ship's
own box (`clip_contents`, the slot fits itself to the hull) while the flame
burns out past it. It reads this control's transform every frame and draws
in it, so it moves, scales and fades with the ship.

It starts TOP LEVEL, and that is how it drew for a month. But a top-level
canvas item is drawn outside tree order, over everything else at its z, so
the plume showed through the draw and discard piles' panel (#56, Nov 8: a
SNAP SHOT with an exhaust across its art). The slot now calls `host_flame`,
which moves the flame into its art holder (a plain Control that does not
clip) as the sibling right after the art: drawn in tree order, so a panel
added to the screen later covers it, and still outside the clip. Top level
remains only for an art nobody hosts, such as the offscreen snapshots.
```

## Ramps

Above `var _steel: Array[Color] = [Color("#131a23"), Color("#232d3a"), Color("#344254"),`:

```text
Six stops, darkest first: shadow, wall, lit wall, deck, lit deck, rim.

Sampled from ART_CONTRACT section 3. Do not add a seventh stop to one of
these — add a whole ramp, which is how a new manufacturer is supposed to
enter the game. The gap between stop 1 and stop 3 is the two-plane break and
it is deliberately large; closing it is how you get a flat sprite back.
```

## Sprite blit

Above `func _blit_sprite(tex: Texture2D) -> bool:`:

```text
Put a generated ship on the canvas. False if there is no sprite, which is the
caller's cue to draw one instead.

CENTRED, NEVER SCALED. The canvas is a fixed 240x120 and a sprite is authored
to its own ink, so the two are not the same size and never will be --
`ArtCheck` asks only that the art fits. Centring is the one placement that
does not need a per-ship anchor table, and it matches how the texture is
presented (`STRETCH_KEEP_CENTERED`), so a sprite lands where the drawing it
replaces already was. Resampling is refused outright: the whole art direction
rests on nearest-neighbour crispness.

THE BOUNDS COME FROM THE SPRITE'S OWN INK, not from its canvas. Everything
that reads `used_rect()` -- the aim reticle's brackets, the Control's minimum
size -- wants the ship, and a file with transparent margin would hand them the
margin as well. `get_used_rect()` is honest here in a way it is not for the
drawn path, because nothing has been painted behind it yet.
```

## Hull profile

Above `func _profile(pts: Array) -> Dictionary:`:

```text
Control points (x, top, bottom) filled in for every column between them.

Authoring a hull as six points and letting this interpolate the taper is the
whole difference between a ship and a rectangle. It is also what lets a
silhouette be raked — the Cutter's top edge falls away toward the nose while
its belly stays flat, and tapering both edges by the same amount is exactly
what made the first attempt read as an airship.
```

## Hull drawing

Above `func _hull(prof: Dictionary, r: Array, deck: float = 0.55, cap: bool = true) -> void:`:

```text
One body, lit from the top of the frame.

Column by column, because the shape changes column by column: rim, top face,
the bright lip where the deck turns, then the wall dropping through two
dithered steps into the shadow it sits in. `deck` is how much of the height
the top face takes — high for something seen more from above, low for a
strake hanging off the underside.

`cap` closes the two ends with ink. Turn it off for a piece that runs into
another one, or you get a black seam where they meet.
```

## Wounds

Above `func _wound(cx: int, cy: int, w: int, h: int, ember: bool = true) -> void:`:

```text
A hole, not a decal.

Scorch first, in three rings of falling size and rising density so the edge
has no boundary; then a ragged core built from three offset boxes, because a
single box reads as a sticker someone put on the ship; then whatever is still
burning at the bottom of it.
```

## Death styles

Above `const SHIP_STYLES: Array[int] = [0, 1, 2, 3, 5, 6, 8, 9, 10, 11, 12]`:

```text
HOW A SHIP DIES: one of these, rolled per kill (Jon's picks, Oct 13). Ships
roll from the kept ship styles -- A B C D F G I J K L M; E CHAIN and H SLICE
were cut and stay in `ShipBreakup` unplayed -- and creatures from their own
three, N O P. The two pools never cross: a whale does not snap like a
cutter, and a cutter does not bloom spores. The Custodian rolls from the
ships' pool and plays its boss version.
```

Above `static func death_style(t: EnemyTemplate, node_index: int, nth_wreck: int) -> int:`:

```text
WHICH STYLE THIS WRECK DIED IN, as a fact about where it lies rather than a
roll made at the time: the system, and which wreck of that system's it is
(the n-th wreck there, in the order `Combat._victory` makes them -- other
things in the jetsam, a pile of loose material, do not count). So the kill
and LOCAL's wreck, long after, agree without anything saved, and a seeded
run replays the same deaths. `Rng.derive`, as every positional thing is.
```

## Wreck cache

Above `static var _wrecks: Dictionary = {}`:

```text
WRECKS ARE CUT AHEAD OF THE KILL. Cutting a hull into its wreck takes 40 to
90 ms of GDScript, and doing it on the frame the killing shot landed froze
the picture for three to six frames at exactly the moment it should move. So
each kind's wreck is cut once, on a worker thread, when the fight opens
(`warm_wreck`), and every later dead draw -- the slot at the kill, the wrecks
on LOCAL -- takes it from here.

NO LOCK, AND NO OBJECT IN A STATIC. Each task writes only into its own
holder, read by the main thread after waiting on that task; a Mutex held in a
static var crashed the engine on its way out (moontest and laddertest passed
and then exited 139).
```

Above `static var _marked: Dictionary = {}`:

```text
Wrecks that carry their fight's hit marks (Jon's picks, Oct 13): by where
they lie (`node index * 64 + nth wreck there`, the same place the death style
is rolled from), each {style, img}. Cut from the damaged picture when the
ship died, so the slot's wreck and LOCAL's afterwards are the breakup's last
frame, marks and all. This session only: a saved run comes back to clean
wrecks.
```

## Dead canvas

Above `static func dead_canvas(e: Combat.EnemyState, with_marks: ShipHitFx = null, scale: float = 1.0) -> Array:`:

```text
THE PICTURE A DEATH IS CUT FROM: the ship drawn dead, whole (scorched,
darkened, engines still on until the cut puts them out), and its box. The
breakup cuts this, not the live picture, so its last frame and every later
dead draw -- the slot, LOCAL's wreck -- are one image to the pixel; the live
picture's wound depends on the hull it had, which nothing after the kill
knows. The difference is hidden under the hit's flash.
```

## Redraw cache

Inside `set_enemy()`, above `var sig := "%s|%s|%d|%d|%d|%d|%d" % [e.template.id, e.template.art, int(telegraphing),`:

```text
Rebuilding a 240x120 image column by column is not free, and bind() runs
on every combat refresh — every card played, every intent that changes.
Nothing below reads anything except which art, whether it is winding up,
roughly how hurt it is and how big it is, so the redraw is skipped unless
one of those four actually moved. Skipping is safe for the layout too:
_used and custom_minimum_size are left from the draw that still matches.

THE ID IS IN THE SIGNATURE, NOT JUST THE ART KEY. Three kinds draw as
`cutter` and three as `hulk`, so keying the cache on `art` alone meant two
different ships in the same fight could hold each other's picture. It never
showed while they were literally the same pixels; the moment one of them
has a sprite and the other does not, it would.
```

## Sprite or drawing

Inside `set_enemy()`, above `_flame_fx = null`:

```text
ONE DOOR: the ship's own sprite if it has one, the drawing if it does not.
The same shape `ModuleIcon.draw_body` uses, and for the same reason -- there
is no third state where an enemy vanishes because its file has not been
generated yet.

THE DAMAGE AND THE TELEGRAPH STAY DRAWN EITHER WAY. `_wound`, the dark
blend and the two telegraph glows are painted OVER the hull, so a sprite
inherits all of them for nothing. That is what keeps the asset set at nine
files rather than nine times four wound bands times two telegraphs.
```

## Control sizing

Inside `set_enemy()`, above `var cx := W * 0.5`:

```text
And the Control shrinks to fit it. The canvas is a fixed 240x120 while a
hull is about 150 wide and 40 tall, so the Control was carrying eighty
pixels of empty image below the ship — which is what held the health bar
and the intent so far away from it. Nothing that reads as "near the ship"
can be, while the ship's own box is mostly not ship.

Sized symmetrically about the canvas centre because the texture is drawn
KEEP_CENTERED: taking the larger half-extent on each axis crops the margin
without ever moving the hull inside the frame.
```

## Sprite drawing

Above `func _draw_sprite(e: Combat.EnemyState, wounded: float, telegraphing: bool) -> bool:`:

```text
THE PICTURE, when the kind has one: Jon's kept ship, centred and never
scaled, then what the fight has done to it drawn over it.

NO STARS ON THIS CANVAS. The coded drawings put a starfield behind the hull;
a sprite does not, so the canvas holds the ship and nothing else, and what a
breakup cuts out of it is the ship's own alpha -- a star showing through a
gap in a ring would otherwise break off as hull.
```

## Wind-up light

Above `const WINDUP := {&"hulk": &"nose", &"hellbender": &"stern"}`:

```text
THE WIND-UP, as light over the picture: the Hulk's ram at its nose, the
Hellbender's escape burn at its drive, anything else (the Custodian's
charge) at its heart. The coded drawings paint these into the hull; a sprite
is lit instead -- the plating near the source brightens with distance, in
whole steps with a dithered edge (memory draw-light-as-light), and only a
real emitter (a ram's hot point, a drive) puts light past the silhouette.
Still while the intent holds: the picture is only redrawn when it changes.
```

## Hellbender art

Above `func _draw_hellbender(wounded: float, telegraphing: bool) -> void:`:

```text
The Hellbender: a furnace wearing a hull. Every other ship out here is cold
metal with one warm exception at the nozzle; this one is black iron leaking
its own cargo — ember light standing in every seam, a radiator spine that
cannot not glow, and an intake maw at the bow because it eats wrecks for a
living. No new ramp: ART_CONTRACT reserves those for manufacturers, and the
whole design is _gun darks letting _heat out, which is the one warm ramp a
ship is allowed and the one thing this ship IS.

Telegraphing here is the ESCAPE BURN — the only telegraph in its kit — so
the tell lights the DRIVE, not a weapon: the hulk teaches you its glow means
a ram is coming, this one teaches you its glow means it is leaving.
```
