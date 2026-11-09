The reasoning behind `tkg/scripts/ui/MapChart.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Held keys

Above `func _settle_walk() -> void:`:

```text
WASD, held. The same move a drag makes, so it goes through the same three
lines: the sky follows what the galaxy ACTUALLY did after the clamp, not
what the key asked for, or the background slides under a stationary
galaxy at the edge of the chart.

It counts as moving it by hand, so a held view lets go -- pressing a
direction is exactly as much "I am looking somewhere else" as dragging is.
A KEY-UP THAT NEVER ARRIVED CANNOT LEAVE THE CHART DRIVING.

`_walk` accumulates on key-down and subtracts on key-up, so it depends on
seeing both halves of every press -- and WIN+SHIFT+S is a press of S
followed by the operating system taking focus for the snip overlay. The
release goes to Windows, `_walk` keeps its DOWN, and the chart pans on
its own until you press and release S again to balance the books.

Checked here rather than only on focus loss because this covers every way
a release can go missing -- alt-tab, a shortcut, a lost window -- and it
can only ever CANCEL movement. That is what makes it safe next to
`_unhandled_key_input`: polling `Input` directly to START a pan would let
a keystroke meant for a focused field drive the chart, which is the exact
thing routing this through `_unhandled_key_input` was for.
```

## Scale bar

Above `const RADIUS_LY := 50000.0`:

```text
How far across the galaxy is, so a bar can say a NUMBER.

`MapNode.gal` is normalised — a fraction of the disc radius — which is
the right thing for a map that only has to be self-consistent, and no
use at all to a reader asking how far a jump is. One constant turns the
whole chart into real units.

50,000 is chosen rather than measured: it is roughly the Milky Way's
radius, so the bar reads as a galaxy instead of a solar system. Nothing
in the sim depends on it — MapGen prices jumps off `gal` directly — so
this is a label, and changing it relabels without rebalancing.
```

Above `func _draw_scale() -> void:`:

```text
HOW FAR IS THAT, in light years.

A zoomable map without one asks the reader to hold a scale in their
head across every zoom step. The bar is the standard answer and it is
cheap: pick the longest round number that fits the allowance, draw it,
print it.

Bottom LEFT. The tooltip follows the cursor and the party markers sit
with the ships, and both of those move; this does not, so it goes in
the one corner nothing else claims.
```

## Sky parallax

Above `const PARALLAX := 0.5`:

```text
How hard the fixed sky slides against the galaxy when you drag.

Halved. Both fields keep their own SPREAD of rates — seven shells of
distant galaxies, twenty-two of halo stars — and that spread is what
actually carries depth, since layers disagreeing about how fast they move
is the whole effect. Amplitude only sets how far they travel, and at full
strength the background covered enough ground to read as the sky being
dragged past rather than as distance behind the galaxy.

One constant on purpose: the two fields have to move as one sky, so their
rates are not independently tunable numbers.
```

## Mark halo key

Above `const _UNDER := Color(0.0, 1.0, 0.0, 0.65)`:

```text
What the chart's marks stand on over the bright sky: the void, a rim of
it round every glyph and dot, and a softer one under routes and rings.
Drawn in a key colour (pure green) that `chart_marks.gdshader` turns into
the void, part see-through and only where the sky under it is bright --
over dark sky, where a mark already reads, it is not there at all (a
solid rim everywhere was "kinda too thick", Jon).
```

## Show all debug

Above `var show_all: bool = false`:

```text
Debug: ignore the visited/reachable filter and draw every system.

RESTORED, dev-only, and the reason it came out is worth keeping: it
defeats the one thing the chart is for, which is the map you have EARNED.
That argument is about the PLAYER, and it still stands — this is behind
DevMode, like the card gallery and the manufacturer list, and for the same
reason. The three dev toggles exist to look at GENERATION: whether the
shells are spaced sensibly, how the lattice is wired, whether a galaxy
rolled something odd. None of that can be seen through a filter that hides
most of the galaxy.

Its absence read as a bug rather than as a decision, which is the other
half of why it is back: the link overlay -- SHOW REACH now, and it drew
the whole `links` lattice then -- painted edges over a chart that was
still hiding the systems those edges ran to, so the diagnostic showed
lines going nowhere and stations floating in the dark, stations being the
one type the filter always let through.

Nothing is reachable through it. Jumping has always been gated on
Run.can_jump_to(), so this reveals and never travels.
```

## WASD pan speed

Above `const WALK_PX_PER_SEC := 320.0`:

```text
HOW FAST WASD WALKS THE CHART, in screen pixels a second.

320 crosses a 960-wide view in three seconds at the reading zoom, which is
the pace of somebody looking rather than somebody travelling. A drag is
for going somewhere; this is for reading along a route, and it should feel
closer to leaning than to flying.

Divided by the zoom, so it moves the same distance across the GALAXY at
every magnification -- otherwise zoomed in it crawls and zoomed out it
throws you across the disc, and the key stops meaning one thing.
```

## Zoom tick

Above `const ZOOM_STEP := 1.12`:

```text
(`remembers_view`): the launcher's backdrop is the same class and must stay
silent and bare.
One wheel notch. A magnification LEVEL is a power of this, so the tick
lands once per notch, and a glide (LOCAL REGION) that crosses nine levels
runs nine ticks off quickly.
```

## Faint star tier

Above `var _star_dim: PackedByteArray = PackedByteArray()`:

```text
The faintest tier of the field, flagged once at build time. While a drag
is actually in flight these are skipped: they are the dim wash between
the bright structure, they carry no shape on their own, and dropping them
costs well over half the pixels in a repaint. Halving the field wholesale
was the earlier attempt and it visibly dimmed the galaxy — this leaves
every bright star, the arms, the core and the lanes exactly as they are.
```

## Core stars

Above `var _core_rad: PackedFloat32Array = PackedFloat32Array()`:

```text
The core's stars: their radius and their colour, kept as the stars
themselves rather than a separate population standing in for them.

A stand-in can match a count and still be obviously wrong. On an edge-on
galaxy the disc is a bright blue-white lane straight through the middle,
and replacing its stars with a warm gold field left the lane running up to
the core, stopping, and a different-coloured thing turning where it should
have continued. Inheriting radius and colour makes the core the same
galaxy as the rest of it — just the part that is moving.
```

Above `var _core_ang: PackedFloat32Array = PackedFloat32Array()`:

```text
The angle each one was already at. Orbits used to take a hashed angle,
which threw away where the star actually WAS — so the arms stopped dead at
the core and a scrambled cloud turned inside it. Worse, the hash was fed a
strided index once the core overflowed, and a multiplicative hash on an
arithmetic progression lands on a lattice: the whole cluster bunched into
one arc. Keeping the angle fixes both. The arms now run continuously into
the core and wind as it turns, which is what a galaxy does.
```

## Sky cache

Above `const SKY_FIELDS: Array[String] = [`:

```text
Everything above that _build_stars derives, by name.

Kept as a list rather than as thirty-four static vars because the cache
has to be saved and restored as a SET — one field left out is a chart
that draws with last galaxy's dust lanes over this galaxy's stars, and a
list you can read against the declarations above catches that by eye.

Everything in it is a Packed*Array or an int. Those are copy-on-write
value types, so storing one is a snapshot rather than an alias; a plain
Array or Dictionary in here would be shared by reference and the cache
would mutate under itself.
```

Above `static var _sky_cache: Dictionary = {}`:

```text
The built sky, shared by every MapChart this process makes.

Router builds a NEW StarchartScreen on every visit, so an instance-level
cache was thrown away every time the player looked at the chart and
rebuilt from scratch on the next look — a quarter of a second of galaxy
maths to redraw a sky that had not changed. It is keyed by panel width as
well as by galaxy, so a resize still rebuilds; what it stops is paying for
the same sky twice.
```

## Nebula label height

Above `var _neb_top: PackedFloat32Array = PackedFloat32Array()`:

```text
How far above its centre each cloud actually reached, MEASURED off the
pixels that survived the dither rather than taken from the radius it was
nominally built to. The two are nowhere near each other — lobes sit at
half to nine tenths of the nominal radius and the falloff then kills
everything past about six tenths of each lobe — so spacing the label off
the nominal figure hung it a couple of hundred pixels above the cloud
with clear sky in between, plainly labelling nothing.
```

## Warm sky

Above `func warm_sky() -> void:`:

```text
Build the star field NOW, rather than on demand inside the first draw.

_build_stars() is the expensive half of this class — 350 to 420ms for a
galaxy it has not seen — and the first paint calls it lazily, so the cost
lands on whichever frame first paints the sky. That frame is then a
quarter-second long, and a quarter-second frame is one the display gets to
show partway through.

Calling it here moves the work to a frame of the caller's choosing, before
anything is visible or moving. The draw that follows finds the key
unchanged and returns immediately. The layers' textures and meshes are
made here too, for the same reason.
```

## Chart built ahead

Above `const CHART_AT := Vector2(655.0, 419.0)`:

```text
THE FIRST CHART OF A RUN, BUILT WHILE THE HULL IS PICKED (Oct 27, on
Jon's Mac). The run's star field was built the first time its chart was
drawn: the click on STARCHART, or Tab, held the old screen still for the
whole build -- 350-420 ms on the PC, 300-560 ms on Jon's Mac -- before the move
began. `Router.new_run` (and CONTINUE) start it here instead, on a worker,
from a copy of the run's galaxy (`_ahead_src`), so it is done long before
anyone opens the chart; the chart's own `_build_stars` finds it in the
cache (`_take_ahead`) and draws the same stars it would have built.

The field is laid out for the chart's size, which only the screen's
layout decides: the size the last chart had this session, or the one it
has had since the field went under the navigation screens (`CHART_AT`;
`-- sheet=ChartAheadTest` fails if the layout moves it). Built for a size
the chart turns out not to have, it is simply not used: the chart builds
its own, as before.

Not headless and not in the sim, which start runs by the hundred and never
draw a chart (`ahead_always` for the test).
```

## Pan slack

Above `const PAN_SLACK := 0.5`:

```text
How far past "the rim is in the middle of the view" a drag may go, as a
fraction of the view.

0.5 is the ordinary convention -- the rim reaches the near EDGE, so the
galaxy may be pushed exactly out of frame and no further. Worth knowing
before trusting that: `ex` is the disc's NOMINAL radius, and the stars fade
out well inside it, so at full pan the screen really is empty rather than
showing a sliver. Lower this if drifting into the void feels like being
lost rather than like looking away.
```

## Remembered view

Above `if remembers_view and size.x > 0.0 and _lad.is_empty():`:

```text
RECORDED HERE RATHER THAN AT EVERY MUTATION. Zoom and pan are moved by
the wheel, by a drag, by `glide_to`'s animation and by both framing
helpers; hooking all of them would leave one out. Reading the result
once a frame cannot.
(not while the zoom ladder holds the view: what is remembered is where
the chart rests, not the dive into your star on the way out)
```

## Framing the title

Above `func frame_to(screen: Vector2, fill: float) -> void:`:

```text
Zoom so the galaxy's outer edge lands at `fill` times half the short side
of `screen`.

For anything that draws the sky on a control BIGGER than the view. The
launcher does: its sky is a square as wide as the screen's diagonal, so
that rotating it can never sweep a corner into frame. _radius() is derived
from the control, so on that square it is nearly twice what it would be on
the screen, and a zoom picked by eye against the chart put the galaxy at
about 1.6 screen-widths across — a title screen showing only the core.

Framing is a question about what the player can see, so it takes the view
as an argument rather than reading a size that is deliberately too big.
```

## Navigated chart flag

Above `var remembers_view := false`:

```text
Whether this chart is the one the player navigates.

`LauncherScreen` builds a MapChart too, as the menu's galaxy backdrop, and
the view memory lives on the CLASS -- so a chart panned in a run was
recorded by one instance and restored by the other, and quitting to the
menu showed a galaxy sitting off centre in exactly the way you had left the
starchart. Reported as, correctly, "LOL".

Off by default so anything decorative stays where it was put; the screen
that owns the real chart opts in.
```

## Arrival framing

Above `func _arrive() -> void:`:

```text
What an arrival does to the view, which is what LOCAL REGION is FOR.

ON, the chart follows you: every arrival re-frames on the region you are
standing in, so the ship is always in the middle of what you are looking
at. OFF, the chart stays exactly where you left it -- same zoom, same pan
-- so you can park on a distant approach and keep watching it across
several jumps.

The toggle used to persist while doing NOTHING on arrival, which read as
broken: it stayed lit and the view sat wherever the last jump had left it.
```

## Core ownership

Above `func _own_at(r: float, clear: float) -> float:`:

```text
The star field is built in two lists, the core's and the rest, split at
this radius by `_own_at`: an old live layer's ownership rule, kept because
the split decides which random numbers each star draws. The sky reads
both lists the same way (`ChartSky`).
Which layer OWNS the stars at this radius — a different question from how
fast they are going, and it needs a different curve.

Splitting them by speed alone put half the stars in each layer wherever
the speed happened to be halfway, and at those radii the motion is still
plainly visible — so you got stationary stars sitting among obviously
moving ones. Weighting ownership hard toward the live layer keeps the
cached field out until the motion is genuinely almost nothing, which is
the only place a static star can hide next to a moving one.
```

Above `var x: float = clampf(r / maxf(1.0, clear), 0.0, 1.0)`:

```text
Total inside three quarters of the core, then a smooth handover.

This was pow(motion, 0.30), which is a curve rather than a rule, and a
curve leaves a tail: measured, it left thirteen static stars in the
innermost fifth of the core but two hundred in the next and nearly a
thousand in the outermost — about twenty-two hundred motionless stars
sitting inside a region where everything is supposed to be turning.
A few percent of a very dense place is still a crowd.

The live layer takes ALL of it out to 0.72 and hands back over the last
quarter. A sharp edge is safe here because the two layers share one
rule: whatever this gives up, the other picks up, so the total density
is flat across the seam however abrupt the split.
```

Above `var seed := (_gseed() * 2654435761 + 24601) & 0x7fffffff`:

```text
Whether a drawn position falls inside the region the live layer owns.
Measured in UNSQUASHED space, which is the fix for the dark crescents
above and below the core: the orbiting stars are laid out on the
galaxy's ellipse, but this test was a circle, so a band was cleared of
static stars that the orbiting ones never reached. The hole itself
stays round — that is the accretion disc's inner radius, not this.
Everything about the core is measured in DRAWN space, and is round.

Ownership used the unsquashed radius so it would line up with the
ellipse the orbits were laid out on, and that was the root of a whole
family of bugs. On a flattened galaxy a star sitting a few pixels
above the hole has a large unsquashed radius: it reads as far out,
keeps its place in the static field, and sits there motionless right
beside the thing everything else is orbiting. Same arithmetic put
stars inside the hole earlier.

A black hole is round on screen whatever the inclination of its
galaxy, and so is the cluster around it. Measuring the distance you
can actually see makes the rule mean what it says: near the hole is
near the hole.
```

## Live core radius

Above `return maxf(_radius() * 0.21, _shadow_r() * 5.0)`:

```text
Never smaller than the disc needs: a galaxy that rolled a large hole
would otherwise have its accretion disc pushed through the boundary.
Every star in here is redrawn sixty times a second, and the count is
derived from the area, so this radius IS the frame budget. At 0.22 it
was nine thousand moving particles and 23ms a frame. The speed
gradient still reads across a smaller region; nine thousand stars
turning did not read any better than three thousand.
```

## Chart scale

Above `return minf(size.x * 0.5 / DISC, size.y * 0.5 / (DISC * ChartSky.TILT)) * 1.9`:

```text
Twice the frame. Twenty-four rings inside one screen puts them about
twenty pixels apart — closer than a system glyph is tall — so the chart
is drawn large and navigated. Zoom out to ZOOM_MIN to see all of it.

Fitted to the plane the chart is DRAWN in (TILT), not the galaxy's own
squash: every galaxy lies at the sector map's angle now, so a squash fit
only made the round ones small -- an elliptical at 0.92 came out 450 px a
galaxy unit against a spiral's 622 (the showcase's audit). One scale
for every kind.
```

## Visible set

Above `func _visible_set(here: MapGen.MapNode, reach: Array) -> Dictionary:`:

```text
Everything currently on screen, as a set of indices.

Built once per frame and shared with hit-testing, because "what is drawn"
and "what can be clicked" answering differently is how you end up with a
tooltip hovering over empty space.

Pointing at a reachable system adds ITS neighbourhood too — that is the
question you are asking by pointing at it. Without that the onward routes
were drawn to systems the filter had hidden, so hovering a candidate gave
you dotted lines running off to nothing.
```

## Sight vs reach

Above `if selected >= 0:`:

```text
ENGINE RANGE IS NOT SIGHT. This used to add everything `in_range()`
returns, which is pure geometry and knows nothing about the dish -- so a
ship with a big thruster and no sensors was shown systems it had never
resolved, could select them, and got a fuel quote for them.

Ruled 2026-08-28: "you still shouldn't be able to SEE those sectors
unless you have the sensor range to see them." Reach beyond sight is
real and allowed -- it is simply range you cannot spend until you fit a
dish, and an unspendable range draws nothing.

Nothing is lost by dropping the clause: anything reachable AND sensed is
already in by `Run.charted`.
```

## Projection

Above `func turn() -> float:`:

```text
THE CHART'S ONE PROJECTION, the sector map's angle with the galaxy turned.

Positions stay in the galaxy's own coordinates: `MapNode.gal`, which
MapGen prices jumps by (`hop_distance` measures in the disc's own plane,
`gal.y / squash`), and which NebulaField speaks. The chart shows that
plane tipped to the sector map's 0.38 and turned by the galaxy's angle:
  in the plane     d  = (gal.x, gal.y / squash) * radius
  turned           d' = d turned back by `turn()`
  on the screen    centre + (d'.x, d'.y * eff) * zoom
`eff` is how flat the disc looks from there (`ChartSky.eff_of`). The
systems, the routes, the rings, the trail, YOU, the party, the Hellbender,
the markers, the tooltips, the pulsars and the bursts all go through
`_proj`; a click comes back through `_to_galaxy`, its inverse, so what is
drawn and what can be pointed at never disagree. The sky turns by the same
angle (`ChartSky`), so a system stays on the arm it was placed on.
```

## Centre pixel

Above `func centre_px() -> Vector2:`:

```text
The galaxy's centre on the screen, on a whole pixel: the sky's blocks are
anchored to it and the systems are drawn from it.
ON THE PIXEL THE SKY SETS THE GALAXY ON: once the sky has settled after a zoom
(`ChartSky.settled`) it moves the galaxy a whole 2x2 block of its own art at a
time, on the even pixel at or below the centre, so its far stars never hop back
on a pan; on an odd centre the systems stood a pixel off the light they belong
to. Hidden while the chart's height was even and a test's drag even too, until
the top plate's new height (d1256496) made the chart 419 px tall and the centre
odd at rest -- `solidtest` 1.93 -> 2.28 px after a drag. While the sky holds a
zoom it draws about the exact centre, and the marks stay on its whole pixel.
```

## Hidden means hidden

Above `var under_badge := CustodianBadge.covers(get_global_transform_with_canvas() * mm.position)`:

```text
Hidden means hidden. The rule used to be that pointing at a
system brought it back — hiding as a way to look PAST the
interface rather than to turn it off — but a toggle that
still answers the cursor is not a toggle, and every hover
still drew a glyph and a tooltip over the galaxy you had just
asked to see on its own. The nebulae still answer, because
they are the galaxy.
Nothing under the Custodian's badge on the goal line: its own
tooltip opens there, and the chart's would open under it. A
press there is still the chart's.
```

## Sky zoom pivot

Above `var eff: float = zoom / maxf(0.0001, was)`:

```text
The sky is anchored at the cursor too, and that is the whole point.
Zoom pivots the galaxy about the pointer, so the galaxy is perfectly
still THERE — and translating the sky by a share of the pan correction
moved it uniformly, hardest at the one spot the galaxy was guaranteed
not to move. Pivoting both about the same point means they agree under
the cursor and diverge with distance from it, which is what parallax
actually looks like.

Only the offset is pivoted, never the contents: the objects translate
as a rigid group, so no pixel is ever rescaled and nothing crawls.
It also falls out correctly at the zoom limits — a clamped zoom gives
an effective factor of 1, so the sky simply does not move.
```

## Pan limit

Above `var ex := _radius() * DISC * zoom`:

```text
THE RIM MAY BE PUSHED TO THE EDGE OF THE VIEW, NOT ONLY TO ITS MIDDLE.

This was `maxf(half a screen, ex)`, which reads as a sensible floor and
is really a REGIME CHANGE. `ex` is the disc's radius in screen pixels,
so it overtakes half a screen at about zoom 0.62, and the two sides of
that switch behave differently: below it you may shift the galaxy 1.47
disc-radii off centre, above it exactly 1.00 and never more, because
panning by `ex` is by definition "put the rim in the middle of the
view". So the drag room collapsed as you leaned in and then stayed
pinned -- which is what "it stops too soon when I zoom in" was.

Adding half a view instead of taking the larger of the two makes one
rule at every zoom: pan until the rim reaches the NEAR EDGE of the
view. That is strictly more room than before at every zoom, it is the
ordinary convention for panning something bigger than its window, and
it still cannot lose the galaxy -- one more pixel and it would be off
screen, so it never is.

The `maxf` is gone rather than relaxed: `ex + half` is already at least
half a view, so the floor it provided is built in.
```

## Range cache

Above `var _range_key: String = ""`:

```text
`Run.in_range()`, remembered.

It walks every system and works the ship's thrust out afresh for each,
about 3ms a call, and the chart asked it on every redraw and on every
mouse motion -- three quarters of a dragged frame once the sky had moved
to the GPU. Its answer depends on where you are, which map, how far the
ship reaches and how the galaxy is tilted (`hop_distance` divides by the
squash), and on nothing a pan, a zoom or a hover can change. Those are the
key, so fitting a thruster or jumping is a new answer and looking around
is not.
```

## Too deep set

Above `func too_deep_set() -> Dictionary:`:

```text
THE STARS INSIDE THE REACH RING THAT A JUMP STILL REFUSES, as a set of
indices: near enough for the drive, but deeper than one jump may go
(`Run.too_deep_only`; ruling 13 A, Jon, Oct 27). Remembered with
`_in_range`, on the same key, since it is the same kind of answer.

Geno met these near the top of the map, where the tilted chart puts rings
close together on the screen: a star beside YOU, lit like the rest, and
TOO DEEP only once it was clicked. The chart draws them dimmed
(`Glyph.DIM`).

The rule is read through `Run.too_deep_only` and nothing here, so how many
rings a jump may go (`RunState.DEPTH_STEP`) can change under it. The core
is left out: it has its own mark on the black hole, and `too_deep_only`
counts it from any distance, not only from inside the ring.
```

## Hit testing

Above `func nodes_near(r: Rect2) -> Dictionary:`:

```text
THE SYSTEMS A CLICK COULD PICK ANYWHERE IN `r` (local), as
`[index, screen position]` in `_node_at`'s order, with the radius it
picks by: what `node_among` asks instead of the whole map.

For A.S.H.'s `covers`, which asks at every 3 px of her box. `_node_at`
rebuilds the visible set over every system (410: 0.8 ms) on each call,
and some 1,500 calls a box made 1.2 s, every tenth of a second while she
taught the chart's list -- the game frozen until she was clicked away
(Jon, Oct 20: "SUPER laggy and unresponsive"). Asked once here, the
answer is the same to the system: a point picks a system within the
radius of it, so any system it could pick stands inside `r` grown by it.
```

## Reach overlay

Above `if show_links and hovered >= 0 and hovered < Run.map.size():`:

```text
WHAT THE SYSTEM UNDER THE CURSOR CAN REACH.

This used to draw every `links` entry from every system at once --
both ends, so each line twice -- and at four hundred systems that
is a grey fog rather than a diagram. It was also a picture of the
WRONG GRAPH: links are what the chart draws, while `can_jump_to` is
`sensed` plus `reachable_from` plus fuel and never consults them.

Its old comment said it "answers the question no in-game view can:
whether MapGen wired the galaxy up sensibly", and that was true
while links gated movement. The modern form of the question is
whether a system can be flown out of, which is what this shows.

ONE SYSTEM AT A TIME, because the reachable graph is DENSER than
the link graph, not sparser -- a radius reaches further than the
lattice does. Drawing all of it would be worse than what it
replaces. Pointing at a system is the question.
```

## Route lines

Above `reach = []`:

```text
Two kinds of line, and they should not look alike. Where you HAVE
been is settled fact: solid, white, unbroken. Where you COULD go is
a proposal: dotted, dim, obviously provisional. Drawing both as
plain lines in different colours made the chart look like one
network when it is really a record and a set of options.
ONLY TO SYSTEMS THAT ARE DRAWN. `in_range` is geometry and knows
nothing about the dish, so a fast ship with no sensors got dotted
lines running out to nothing -- the destination glyph was correctly
hidden and the route to it was not. A line to an invisible place is
worse than either showing both or hiding both.
```

## Remembered systems

Above `if not node2.sensed and node2.index != here.index:`:

```text
REMEMBERED, NOT SEEN, and both are meant to be on the chart: where
you have been is a historical marker and stays, which is a ruling.

So the whole job here is telling them apart. Drawn identically, a
chart carrying a run's worth of history looked like a dish reaching
far past its own ring, and the ring read as a lie. Dimmed, the lit
systems are the ones you can see RIGHT NOW and the ring is their
boundary; the dim ones are places you have been.

Not `cleared`'s dead grey, which says "spent". These keep their
region colour because they are still real places you might route
back through -- they are simply not on the dish this minute.
```

## Core marker

Above `if node2.type == MapGen.NodeType.CORE and not (show_all or node2.index == here.index`:

```text
THE CORE IS ITS BLACK HOLE, AND MARKED ON IT ("the core icon should
be in the center of the black part of the black hole AND the
selection reticle should be there too", Jon): its glyph on the
shadow, the brackets and YOU with it, no name. Its band in the
flare's amber, not the near-white that read as a second, smaller
hole inside the black ("I don't like the white outline on the
center of the black hole").
(the core is always on the chart's list -- it is where the run
ends and can always be jumped toward -- but its icon shows only
when it is in your sensors, as any system's would: "have the black
hole icon only show up when you're in range of it", Jon. The hole
itself is sky and always there.)
```

## Local region framing

Above `var _glide: Tween = null`:

```text
FRAME WHERE YOU ARE, not the ring you are on.

The first version framed the whole LAYER, which is right in the abstract
and useless in practice: at the rim a layer is most of the galaxy's
circumference, so the fit came out at ZOOM_MIN and the button appeared to
do nothing on exactly the screen you start the run on.

A neighbourhood instead: everything within `span` of you in galaxy
coordinates, which is the same measure MapGen prices jumps by. That is
the region you can actually reach, and it frames the same way whether you
are on the rim or in the core.
A view change in flight, so a second press can cancel the first.
```

Above `if n <= 1:`:

```text
EVERY GALAXY'S FRAME IS THE SYSTEMS NEAR YOU, a ball's as a spiral's (Jon,
Oct 21, for 0.3.0). His "frame:A" of Oct 18 framed a ball whole -- the box took
in the core and the ball's lit radius (`ChartSky.ball_lit_gu`), because its
systems lie on the disc's plane, drawn mostly below the core, and a frame of
them alone cut the ball off at the top -- so L took a ball from 0.42 to 0.54-0.84
(PGC 6236 0.58) against a spiral's 1.8, and read as doing nothing. The ball is
out of the frame now, as a spiral's arms are; L is for the systems in reach.
```

## Glide

Above `func glide_to(z: float, p: Vector2, secs: float = 0.55) -> void:`:

```text
Move the view to a zoom and a pan over time rather than at once.

The sky is settled EVERY STEP, against the values from the step before.
`_settle_sky` is written as a delta — pivot by however much the zoom just
changed, translate by however far the pan just moved — so feeding it the
whole journey at the end would pivot the starfield about the wrong point
and slide it past where it belongs.
```

Above `var pz := zoom`:

```text
WORK OUT WHERE THE SKY ENDS UP FIRST, then travel to it.

Settling per step against the step before accumulates: each frame
pivots by a pow() of a fraction of the zoom change, and a chain of
those does not add up to the single pivot the whole move deserves.
On screen the galaxy trailed the systems and caught up at the end,
which is exactly what an accumulating error looks like.

The end state is computable in closed form, so the sky is simply
LERPED to it alongside the zoom and the pan. All three then move as
one and arrive together.
```

Above `var sf: float = pow(zoom / maxf(0.0001, z0), SKY_ZOOM_POWER)`:

```text
SOLVED AT THIS ZOOM, never interpolated towards the end.

The sky's offset is a pow() of the zoom RATIO, and the zoom is
travelling on a cubic ease. Lerping the sky between its start and
end is therefore right at both ends and wrong everywhere between
them, which on screen is the galaxy trailing the systems and
catching up at the last moment. Evaluating the same closed form
against the CURRENT zoom is exact at every step.
```

Above `func center_on_ship(z: float) -> void:`:

```text
Travel there, or simply be there.

The snap is the same two assignments the remembered-view restore makes,
and that path was already smooth -- there is no third way of moving the
chart, only the question of whether the move is watched.
Frame the ship at a given zoom. The screenshot harnesses both need
exactly this and were each poking zoom, pan, `_clamp_pan` and
`_repaint_sky` by hand, which is the part a caller doing it by hand
forgets.
```

## Snap on arrival

Above `func frame_region(here: MapGen.MapNode, span: float = 0.24,`:

```text
`animate` false SNAPS, which is what an ARRIVAL wants.

`glide_to` tweens for half a second and repaints the galaxy on every frame
of it. That is right for a PRESS -- you asked for the view to move, and
watching it travel is how you keep your bearings -- and wrong for a jump,
where the screen is rebuilt at ZOOM_MIN and then visibly zooms itself in.
Reported as jitter with LOCAL REGION on, and absent with it off for exactly
this reason: the off path assigns and repaints once.
```

## Sky settle

Above `func _settle_sky(was: float, before: Vector2) -> void:`:

```text
Move the SKY to match a jump the view just made.

The starfield is not drawn from `pan`. It has its own offset, and only
dragging and `_zoom_at` were maintaining it — so setting `zoom` and
`pan` directly moved the systems and left the galaxy where it was. On
screen that reads as the local region being pasted onto the middle of
an unmoved galaxy, and it corrected itself the moment you dragged,
which is what made it look like a repaint bug rather than a missing
term.

Two motions, in the order the view made them: pivot about the frame
centre for the zoom, then translate by however far the pan moved.
`_repaint_galaxy` is the other half — the starfield is a cached image,
so a queue_redraw alone repaints everything except the thing that
moved.
```

## Nebula boundary

Above `func _draw_neb_edges() -> void:`:

```text
The boundary of the cloud under the cursor, and only that one.

Every cloud outlined at once was a set of rings competing with the systems
for attention — and an outline is an answer to "what am I pointing at",
which is a question you are only asking about one of them.

Drawn as the union boundary of its lobes: every point on a lobe that is
not inside another one. That is the actual silhouette, so the line agrees
with the gas rather than circling it approximately, and it is exactly the
region the tooltip answers for.
```

## Reach ring

Above `func _draw_reach_ring(c: Vector2) -> void:`:

```text
How far the ship can go, drawn where it can be seen.

AN ELLIPSE, NOT A CIRCLE, and that is the whole of it. `galaxy_pos` draws
the disc foreshortened -- `Vector2(cos(a), sin(a) * squash)` -- and
`hop_distance` measures in the disc's own plane, dividing `gal.y` back out
by that same squash. So the reachable set is a circle in the galaxy and an
ELLIPSE on the chart: at squash 0.62 you reach about 1.6x further sideways
than you do up or down, in screen pixels.

Reported as a bug -- a system plainly nearer than a reachable one that
could not be reached. It is not one; it was just impossible to see. A ring
that is visibly wide and flat says "down costs more than across" without a
word of explanation, and says the galaxy is tilted while it is at it.

Whole pixels and a step count tied to the radius, for the reason `_dotted`
gives below: a ring walked in continuous space lands its dashes on
fractions of a pixel and shimmers as you pan.
```

## Sight and reach rings

Above `if show_sight:`:

```text
TWO RINGS, BECAUSE THERE ARE TWO LIMITS AND THEY ARE NOT THE SAME ONE.
Sight is `base * (SENSE_FLOOR + sensors * SENSE_REACH)` and reach is
`base * thrust_reach()`, so the dish ALWAYS outruns the engine -- 1.39x
at no sensors at all, near 3x at ten.

Only the inner one used to be drawn, which left the outer boundary with
no line on it: systems lit up outside the ring you could see and there
was nothing to say why. Reported as "I can see outside my range
circle?", which is exactly right and exactly the design.

The gap between them is what a dish BUYS, and now it is a visible band
rather than an inference from which dots happen to be lit.
AND THE OUTER ONE HAS TO BE VISIBLE, which took a second report to
notice. Drawing it was not enough: at alpha 0.34 in single pixels, two
on and three off, on a ring with a far bigger circumference than the
inner one, the dots land further apart AND dimmer than reach's -- so on
a dense starfield the only boundary a player could actually find was the
orange one, and every system in the band between them read as a bug.
Measured after the fact by `-- chartfilter`: nothing was wrong with the
filter, the line saying where the limit was simply could not be seen.

So sight carries reach's weight and a LONGER dash. Two boundaries at the
same rhythm in two colours are one boundary drawn twice; a long dash
reads as an outer limit and a short dot as an immediate one, which is
what they respectively are.
```

## Contract tooltip

Above `if Run.known_only_by_contract(n.index):`:

```text
THE SAME REFUSAL THE PANEL MAKES, and it has to be made twice or it is
not made at all: the tooltip prints type, place and danger, which is
precisely the survey the destination panel just declined to give. One
hover and the withholding is undone.

Fuel survives, because reachability is a fact about your tank and the
link you are standing next to rather than about the place. So does
TOO DEEP, for the same reason.
```

## Party markers

Above `func _draw_party() -> void:`:

```text
Where the rest of the party is.

Drawn OUTSIDE the visibility filter, deliberately. The chart otherwise
hides a system you have never been to and cannot reach, which is right for
a place and wrong for a person: a partner four shells coreward is the one
piece of information you most want and the one you can least reach. It is
also what makes `docs/coop-design.md` §7 legible — danger tracking the deepest
ship is only a leash if you can see how deep they are.

`docs/coop-design.md` §9 rules that this should be gated on sensor range, with
a last-known position and an age stamp outside it. There is no fog in the
game yet, so this shows everybody. When fog arrives it gates the position
going ONTO the wire rather than coming off it, and nothing here changes.
```

Above `_diamond(c, 6.0, _UNDER)`:

```text
Backed in ink, and the name shadowed with it.

Not a polish pass. The deepest ship is the one this marker exists
to show — `docs/coop-design.md` §7 makes everybody's danger track it —
and deep means over the core, which is the brightest thing on the
chart. Unbacked, the one marker that matters most was the only one
you could not see.
```

Above `func party_marks() -> Array:`:

```text
Where each partner's diamond goes: `[[slot, screen point, label row], ...]`.

OFF YOUR OWN SYSTEM, NOT ON IT. A partner in the system you are in was
drawn on its centre -- the glyph your ship is marked on -- so the two of
you were one picture "totally on top of each other" (Oct 22 playtest).
There the diamonds stand to the upper right of your marker, one under
another, each with its name beside it (row -1 says "name beside");
elsewhere a diamond is on its system and names stack above it.
```

## Hellbender marker

Above `func _draw_hellbender() -> void:`:

```text
The galaxy's other harvester, drawn wherever the host last said it was.

OUTSIDE any visibility filter, like the party and the work, and the
fiction pays for it: the hellbender is the hottest thing flying, and heat is
the one signature this game says you cannot hide. That is also its
balance — a threat you can always see is a threat you can always route
around, and routing around it has a price the map charges in salvage.
```

## Quest markers

Above `func _draw_quests() -> void:`:

```text
Where the work is. A ring in the issuing manufacturer's colour, on every system an
open contract points at.

THE CHART IS WHERE A CONTRACT BECOMES PLAYABLE. A fetch that names "Kappa
Thorn Reach" and then leaves you to find it is a memory test, and the
station board is four screens away from the only page that plots a jump.

Drawn OUTSIDE the visibility filter, like the party markers above and for
the same reason: the filter is right about places and wrong about
intentions. A job you signed for is a fact about YOU, and hiding it until
you happen to fly within sensor range of it would hide it exactly while it
is still a decision.

Not a route and not an arrow. It says where, and leaves the whether alone —
see ContractData's header on why nothing here pushes you anywhere.
A SYSTEM SOMEBODY PUT SOMETHING ON, and the name of the thing.

A CHEVRON POINTING DOWN AT IT, and every other shape was taken. The chart
speaks in rings for contracts -- one for a fetch, two for a hunt -- in
diamonds for the party and the hellbender, and in four corner ticks for
YOU. Corner ticks were the first thing I drew here and they were wrong:
gold ticks beside amber ticks is the same marker in two colours, and the
one meaning "you are here" is the one you least want doubled.

A SQUARE, and it took three tries to get there. A filled triangle was too
heavy -- nothing on this map is filled -- and an open chevron was two
strokes floating over a star with nothing tying them to it.

The three markers are now three shapes at the same weight: a SQUARE for a
quest, a DIAMOND for the hellbender, and the corner brackets for YOU. All
outlines, all a pixel wide, told apart by form rather than by colour --
which matters most zoomed out, where colour is two pixels and shape is
the only thing left.

The name rides above it, which no other marker carries and which is the
one thing a quest has that a contract ring does not.

IT IGNORES THE VISIBILITY RULE, and that is the point of it. The chart
deliberately hides systems you have never been to and cannot reach,
because "a system you can neither see nor go to is not information you can
act on" -- and a quest is the one thing on the map that IS. You cannot act
on it this minute; you can route toward it, which is the entire reason it
was placed four jumps deeper instead of handed to you.

The name goes ABOVE. Hovering already prints a system's own name below it,
and two labels on one node stacked on each other.
```

## Delivery berths

Above `for manufacturer in _work_berths:`:

```text
AND WHERE IT GETS HANDED OVER, which is the third thing to mark and the
one that was missing. A fetch and a hunt ring a place before you go; a
finished job and a heat contract have to ring a place you come BACK to,
and a heat contract never had a target at all. Every berth of that
manufacturer, because delivery is to the manufacturer rather than to the desk that
posted it.

A square rather than a ring, and filled: this is not somewhere to look,
it is somewhere to land.
THE NEAREST FEW, NOT ALL OF THEM. A manufacturer holds berths all over the
galaxy and marking every one drew twelve squares across the disc, which
reads as a rash rather than as directions — and the question a player is
actually asking is not "where could I hand this over" but "where is the
closest place I can". Three is enough to offer a choice of routes and
few enough to be a marking.
```

Above `func _nearest_berths(manufacturer: StringName, want: int) -> Array:`:

```text
The closest berths of one manufacturer, by galaxy distance from where you stand.

Distance rather than jumps, deliberately. A route is a fuel question that
the neighbour list answers properly and a straight line cannot, and a chart
marking that pretended to know the route would be wrong the first time a
link did not exist. This says WHICH WAY, and leaves the how to the list.
```

## YOU marker

Above `func _draw_you(p: Vector2, tiny: bool) -> void:`:

```text
THE LABEL ONLY. This used to draw corner brackets as well, at 21 pixels
with 5-pixel arms -- and `Glyph.draw_glyph` has always bracketed the
current node too, at 16 with 4, in the same FLARE. So the ship sat inside
two nested boxes that were meant to be one, close enough in size to read
as a rendering fault rather than as a design.

The glyph's are kept because they are drawn WITH the node and scale with
it; this one is a label and does the job the glyph cannot.
```

## Galaxy rim

Above `u *= 1.0 + 0.55 * pow(t, 8.0)`:

```text
The outermost few percent of stars are stretched well past the
nominal edge. Without this the disc simply stops at r_max — every
star inside, none outside — and a galaxy with a hard boundary
reads as a picture pasted onto the starfield. Spreading the last
few percent over half again the radius makes density decay instead
of truncating, and only that outer tail moves at all.
```

## Nebula dither

Above `const _DITHER4 := [`:

```text
Ordered dither, 4x4, indexed by position in GALAXY space rather than on
screen. The art contract allows this and nothing else, and a nebula is
mostly edge: a random stipple where the gas thins out reads as noise on
the screen, a fixed threshold pattern reads as gas. Keying it to the
galaxy rather than to the viewport is what stops the pattern crawling
across the cloud when you pan.
```

## Dark nebula extinction

Above `func _extinct(p: Vector2) -> float:`:

```text
How much a dark nebula blocks whatever is behind it, 0 to 1.

A dark nebula is the one kind defined by what it HIDES, and the clouds
are drawn BEFORE the arms so that arm stars sit in front of the gas —
which is right for gas that glows and exactly wrong for gas that does
not. The result was a dust cloud with the full star field shining
through it, which is the one thing a dark nebula must never look like.

Smoothstepped so the cloud has an edge you can see into rather than a
rim, and cheap enough to ask per star: a few lobes, no trig, and an
instant zero in a galaxy that rolled no dark clouds at all.
```

Above `return e`:

```text
Returned RAW. The diffuse arm field tempers this down at its own call
site, because taking every one of those left a smooth black disc with
a hard rim — a hole cut in the galaxy rather than dust in front of it.
Bright point sources are the opposite case and want the full value:
a globular or a foreground-bright field star showing through at even
a quarter strength is precisely what stops a dark cloud reading dark.
```

## Static pixel gate

Above `func _static_ok(p: Vector2, t: float) -> bool:`:

```text
Whether a point in drawn galaxy space may hold a static pixel.

The live layer owns the black hole's neighbourhood outright and fades in
across a band on the way out of it, so everything cached has to fade out
across the same band or the handover shows as a ring. `t` is the pixel's
own random number, which is what makes that fade dithered rather than a
hard edge. The four original field passes each inline this; everything
added since calls it.
Whether a piece of static material — nebula, dust lane, remnant — may sit
here. The nebulae, lanes and remnants go through this; the stars, arms and
bulge go through the same two rules inline.

It was still using a fixed blend band from before the core was rewritten,
and it had no test against the hole at all. That is why the disc lane ran
straight across the middle of an edge-on galaxy: it is dust rather than
stars, so it never met either of the rules the stars were following, and
sat frozen among the orbiting field with a slice of it inside the hole.
```

## Region tint

Above `func _region_tint(at: Vector2) -> Color:`:

```text
What colour the gas around here is, taken from the nearest system.

This is the art direction's rule about the void carrying region
signatures, applied to the only thing on the chart big enough to carry a
wash: a cloud sitting in Korvan space glows rusty amber, one on a
migration route glows teal, and the Core's neighbourhood glows red. So the
sky tells you whose space you are looking at before you point at anything.
```

## Nebula ramps

Above `func _neb_ramp(base: Color, hue: float, sat: float, val: float,`:

```text
One four-step ramp for one tone of one cloud: fringe, low, body, and a
lit core that only emission gas gets.

Clouds are built from three of these at once rather than one, because a
single ramp is what makes a nebula read as a splotch — a shape filled in.
Real gas is not one temperature: it is patches of different ionisation
sitting against each other, and that is most of what gives a cloud its
interior. The variants stay NEAR each other on purpose — a few hundredths
of a turn of hue, a few percent of saturation. Push them further apart and
the cloud stops being one object.
```

## Nebula layers

Above `func _pn_reach(kind: int, a: float) -> float:`:

```text
Nebulae, as the art direction specifies them: layered translucent masses,
dithered edges, coloured per region.

Appended BEFORE the arms so arm stars draw in front of them. Gas you can
see stars through is gas; gas that occludes them is a sticker laid over
the galaxy. The dark half of the same material is a separate pass that
runs AFTER the arms, because a dust lane only reads as a lane when it
hides the stars behind it.
How far out a planetary's gas reaches at this angle, as a multiple of its
nominal radius. Build-time only, so it can afford to be readable.
```

## Cloud colour

Above `var pull: float = 0.88 if cloud.hollow > 0.0 else 0.68`:

```text
Weighted toward the gas rather than the region: region colours are
chrome, chosen to sit quietly behind an icon, and a cloud built out
of one at full strength comes out the colour of the panel border.
The region pulls the hue over; it does not set it.
The kind decides the hue and the region pulls it over — a
planetary is oxygen green wherever it is, but a green one sitting
in Korvan space leans amber.
A shell keeps far more of its own colour than a diffuse cloud
does. The region tint is chrome — it exists so gas sits quietly
behind an icon — and at 0.68 it was pulling the planetary's
oxygen green and the remnant's filament teal to within a few
points of each other, which is most of why the two were hard to
tell apart. A shell is a bright, compact, high-contrast object;
it can afford to be its own colour.
```

## Nebula sampling

Above `var px := clampi(int(rad * rad * 0.62), 1200, 12000)`:

```text
Enough samples that the blocks overlap through the middle and only
separate out at the fringe, which is the point at which a scatter
of dots stops reading as dots. The first pass ran at a third of
this and the clouds were invisible underneath their own labels.
Raised with the block size halved: a quarter of the area per pixel
needs more pixels to read as the same body of gas, and the wash
lives in the static arrays so it costs a rect apiece and nothing
to derive.
```

Above `px = int(float(px) * (4.0 if cloud.kind == NebulaField.Kind.PLANETARY else 3.4))`:

```text
A shell puts every pixel it has into a thin annulus rather
than spreading them through a volume, so it needs fewer than
a solid cloud of the same radius — but a planetary is also
the smallest object here by a distance, and the budget goes
with the SQUARE of the radius. Without a bump it was getting
about a tenth of the pixels of its neighbours and came out as
a faint smudge.
The remnant spends its budget over a much wider, fainter band
than the planetary and throws most of it away again at the
arc gaps, so it needs the larger share despite being the
larger object. The planetary now fills its interior as well
as its rim and wants enough left for both.
```

## Shell lobes

Above `var nl := lobes.size()`:

```text
lobes.size(), NOT a literal 3. A planetary and a remnant are gas
thrown outward from a single point, so NebulaField gives them ONE
centred lobe — and this loop was indexing three of them. Two
thirds of every shell's pixels were read out of bounds: radius
zero, offset zero, the whole budget piled onto the exact centre,
where the hollow test then threw it away. That is why a supernova
remnant drew as an empty circle with a few strays in it.
```

## Shell wall

Above `var wall: float = NebulaField.EXTENT * 0.80`:

```text
A shell, sampled AS a shell. The wall used to be carved
out of a solid cloud by remapping the density falloff,
which had two problems: almost every sample fell outside
the band and was discarded, and because the falloff is
smoothstepped, the surviving wall landed at about a third
of the radius — a small faint ring adrift inside a large
boundary circle, with nothing between the two.

Placing samples in the wall directly costs nothing, wastes
nothing, and puts the gas where the hover outline is.
```

Above `wall = NebulaField.EXTENT * 0.64`:

```text
Pulled in and spread wide. A remnant is thousands of
years past the explosion: the front has broken up,
slowed unevenly and begun mixing back into the medium
it swept. It is not a shell so much as a REGION, and
smearing it over half its own radius is what stops it
reading as a drawn ring. The centre comes in to match,
so the gas still mostly sits inside the outline.
```

## Remnant ragged

Above `var wob: float = sin(a2 * 3.0 + twist_k) * 0.36 \`:

```text
Ragged, and incomplete. A shock front does not expand
into a vacuum — it ploughs into gas that is lumpy, so
it runs ahead where the medium is thin and stalls
where it is thick. Three harmonics wobble the wall,
and a slower one takes whole arcs of it away, which is
what makes a remnant read as something torn rather
than something drawn.
```

## Planetary interior

Above `filled = true`:

```text
The inside of a planetary GLOWS. The star that shed
the envelope is still sitting in the middle of it and
still ionising it, so the interior is not empty — it
holds the same oxygen light as the rim, only fainter
for having less gas along the line of sight.

Drawing it as a bare ring was the single thing that
made these read as remnants: a hollow outline is what
is left when something has gone, and this one has not
gone anywhere.
```

## Planetary shape

Above `var pu: float = u * _pn_reach(cloud.shape, a2)`:

```text
A planetary is one star's envelope, thrown off in one
go and seen at whatever angle it happens to present:
smooth, unbroken, and elliptical because it is tilted
rather than because it is deformed. Where the remnant
is torn, this is intact — that contrast is the whole
distinction between the two.
```

## Nebula tone

Above `var tone: float = 0.5 + 0.20 * sin(local.x * tf + twist_k * 0.6) \`:

```text
Which tone, from a field at a much lower frequency than the
filaments — so brightness and temperature vary independently
and the cloud does not come out banded.
Three terms, none of them a multiple of another. Two put the
tones in clean diagonal bands across the cloud, which reads as
two clouds overlapping rather than as one with structure.
```

## Nebula blocks

Above `_star_big.append(2)`:

```text
Every tier is a block, the bright ones included. Drawing the
core at full resolution and the wash at a quarter of it was
the obvious economy and it erased the cloud's whole interior:
single pixels of the bright steps disappeared between blocks
of the dim ones, so what was left was a flat even mat with no
middle to it. A nebula has to have a middle.
```

## Nebula stars

Above `if cloud.kind == NebulaField.Kind.PLANETARY:`:

```text
The stars that lit it. Only a cloud that is actively forming them
gets them: a planetary is one dying star's envelope, a remnant is
what is left after the star went, and a dark cloud has nothing
lighting it at all.
The star that shed it, still sitting in the middle. A planetary is
the one nebula with an obvious source, and it is what makes the
ring read as a ring around something.
```

## Dust lanes

Above `var n := 0 if (int(g.arms) <= 0 or gas < 0.35) \`:

```text
No arms, no density wave, nothing to pile the dust into a lane — and a
galaxy that has run out of gas has nothing to make one out of either.
The globules below still run: they belong to the clouds, not to the
arms, and a barless ring galaxy has clouds without having lanes.

A lane runs along the INNER edge of an arm, which is where the wave
piles material up, and it is why a spiral arm has a bright side and a
dark side instead of fading off symmetrically both ways.
```

## Globular clusters

Above `func _build_clusters(r_max: float) -> void:`:

```text
Globular clusters. Old, dense, and out of the plane — which is the whole
point of drawing them. Everything else on this chart lies in the disc, so
a knot of stars plainly sitting above it is the cheapest thing available
that says the galaxy is a solid object rather than a picture of a spiral.

Deliberately NOT squashed: the halo is a sphere, and a sphere in
projection is a circle however flattened the disc in front of it is.
```

## Pulsars

Above `func _build_remnants(r_max: float) -> void:`:

```text
The flashing star at each pulsar.

This used to draw a small shock shell around every pulsar as well. That
shell is now redundant and was actively misleading: a pulsar only exists
inside a supernova remnant or a planetary nebula, and both of those are
already drawn — as hollow clouds, at their real size, by the nebula pass.
Ringing the system with a second, smaller shell of its own put two shock
fronts on the chart for one explosion.

So all that is left is the star itself, which the sky lights.
```

Above `for raw in _clouds():`:

```text
No map — the launcher. Pulsars are placed by MapGen, which marks a
SYSTEM inside a remnant as one, so with no systems there were no
pulsars and the title screen's remnants sat there with nothing at the
centre. A supernova remnant without its neutron star is the one thing
in this sky that is actually wrong rather than merely absent.

Straight from the cloud instead: one per REMNANT, at its centre, which
is where the star that threw the shell has to be. Planetary nebulae get
nothing, same as in a real run — they are low-mass envelopes and leave
a white dwarf.
```

## Survey tag

Above `static func survey_lines(n: MapGen.MapNode, here: MapGen.MapNode) -> PackedStringArray:`:

```text
STRIPPED-DOWN UI C3 (Jon, Nov 9): the chart's one action is JUMP, and it is
the biggest thing on the screen, so the DESTINATION panel keeps only what
decides a jump (name, danger, fuel, warnings). The survey the panel used to
list in eight to ten rows (what the star is, what else is in the sky, how
built up, how policed, who runs it, what it sells, which way it lies) moved
here, to the star's hover tag, one short line each, after the four lines
the harnesses read by index (ChartDeepTest reads line 3 for TOO DEEP). A
position known only from a contract still withholds the survey.

The tag itself is the torn tag (T1, `TornTag`), placed above the star and
clear of it, where it was a framed box with a colour chip beside the cursor.
```
