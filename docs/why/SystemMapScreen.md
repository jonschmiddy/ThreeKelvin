The reasoning behind `tkg/scripts/ui/sysmap/SystemMapScreen.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Sector map

Above `signal beacon_opened(body: int, beacon)`:

```text
THE SECTOR MAP (Jon: "a system map like Starfield's"): the system's star and
the worlds going round it, a beacon on whatever holds an encounter, your ship
among them. The picture is `SystemView`; what is drawn over it -- beacons,
selection, ship, hover tip -- is `SystemOverlay`; the panel holds the sector,
a body, or an encounter (`SystemPanel`).

LAID OUT LIKE THE STAR CHART (Jon: "style the system page like the starchart
page"): a strip along the top, the map framed on the left with the star in
the middle of it, the panel on the right with the way on at its foot, and a
KEY along the bottom.

THE MAP DRAWS INTO ITS OWN 960x540 PICTURE, shown in the frame. Its shadows,
palette, lens and star masks all read pixels off the screen, and a screen
that is the map's own cannot sit anywhere but where the map thinks it is.
Drawn straight into the game's picture it sat ten pixels under where it
assumed, because the HUD had grown, and every planet's shadow came off it
crooked (Jon: "the shadow of the planet being delayed").

FLOWN, NOT PARKED (Jon picked the arcade orbits, F, of six mocked): WASD flies
your ship (`ShipFlight`); a world's ring takes it into orbit when you let go
inside it slowly, and a place's events open only while you are in orbit of it
or alongside it. Click once to select a place (the panel shows it, the map
holds a reticle on it); click it again to fly there on a transfer orbit;
click empty space to go back to the sector's list (Jon: "click once on an
object to update the focus of the right panel. click again on an object ...
travels to that object"). A choice taken anywhere else flies you there first.
The arrows and a drag pan the view; [ and ] step the events.
```

## Pixel grid

Inside `_place_map()`, above `var g := _frame.global_position + at`:

```text
ON THE GAME'S GRID: the map's 2x2 blocks on the same pixels as LOCAL's
(whose sky is drawn from the picture's corner), so a world handed from one to
the other (`ZoomLadder`, 2C) is the same pixels -- a block off by one pixel
was every pixel of it different
-- and on the same 8-pixel step, so the dithers drawn in its blocks (4 x 4,
a block a step) fall on the same pixels too
```

## Restyle during flight

Inside `show_system()`, above `var going: Dictionary = {}`:

```text
A FLIGHT UNDER WAY, THE MAP DRAWN AGAIN ROUND IT (`_on_style`: another
rendering style, GRAPHICS LOW): its errand goes on with the ship that
replaces this one (`_carry_on`). Its callback belonged to this ship and
never ran: a GO's event, DOCK or ENGAGE was lost, and `_taking`, cleared
only there, kept the map shut (no click, hover, zoom, drag, WASD or FLY
HERE) until the player left it (the recheck's probe, Oct 31)
```

## Flight errand handover

Above `func _carry_on(going: Dictionary, taking: bool) -> void:`:

```text
THE ERRAND OF A FLIGHT THE MAP WAS DRAWN AGAIN ROUND (`ShipFlight.hand_over`):
the ship has been put where it was going if it was on its way (`ship_place`),
and what was to happen there happens now, once; if it was still planning or
riding round to leave, it was put back where it was leaving and flies there
now, keeping its choice, the map shut again for a GO as it was. Clicking never
loses anything: fly, then orbit, then open.
```

## Opening view

Above `static func open_view(L: SystemLayout, n: MapGen.MapNode, fs: Vector2, _t: float, ship := Vector2.INF) -> Dictionary:`:

```text
WHERE SYSTEM L (of node n) OPENS in a frame of size `fs`: {at, the plane
point the frame centres on, star A at the origin; zoom}. One sun and
a close pair: star A and the whole system (`zoom_for`), as they always
opened. A WIDE PAIR (Jon, Nov 1, "gap:A"): its own part (`pair_box`, the two
suns and the worlds round one of them) filling PAIR_FILL of the frame, never
further out than the whole system. Fitted to the whole system, the things
that circle both suns far out made the pair so small that a world round one
sun was drawn as little as 5 px from its sun's disc; framed on the pair it is
28 px from it at the least (the wide pairs of seeds 7, 4242 and 1999). The
wheel still goes out to the whole system, and what circles both suns is
marked at the frame's edge until then (`SystemOverlay._draw_edge_marks`). `ship`, the
plane point your ship is at when the map is shown with it put back off that
framing (`show_system`): taken in too, with SHIP_PAD round it. `_t`: the map
time it opens at (the system's kept clock, `Run.map_clock`), which changes
nothing: a turning pair opens the same at every clock (below).
```

## Turning pair framing

Inside `open_view()`, above `var reach := Vector2.ONE * pair_reach(L)`:

```text
A TURNING PAIR (ruling 23) opens on its balance point, at the zoom the pair
as laid out opens at, or further out where the whole circle the pair sweeps
(`pair_reach`, and the ship put back) would not fit the frame at it with
the whole system's margins (`fit_zoom_in`). Framed on the pair as it stood
at the kept clock, the zoom went with the angle (upright, a pair stands
0.38 as wide on screen, the map's slant, so it opened nearer) and
the pair turned off the picture within the visit (70 to 95 degrees in five
minutes); framed on the circle it sweeps, the worlds round one sun opened
as near their suns as 22.8 px (TwinSiteTest's sweep, every system a
binary) against the 24 the framing is for. The balance point never moves, so this framing,
and home (a second right-click, LOCATION let go), hold the whole visit, at
every clock.
```

## Two suns zoom floor

Above `static func _twin_floor(L: SystemLayout, n: MapGen.MapNode, fs: Vector2, z: float) -> float:`:

```text
TWO SUNS OPEN NO FURTHER OUT THAN THEIR RINGS WERE FITTED TO while nothing is
posted past the edge (`SystemLayout.fit_zoom`: "the map opens there or
nearer"), and only where the whole edge is still in the frame at it.
Measured on seed 4242 (`-- sheet=TwinSiteTest`): the edge alone fitted
opened twins at down to 0.9924 of their `fit_zoom`, their suns' floor drawn
wider than the rings round them were fitted to -- from two causes. The
layout fits on a 655x420 frame, which the map's is until a panel row asks
for more than its text column with the scroll bar up and the panel widens
(650x420: an event card naming a long world you orbit); and some twins' edge
reaches a little past the farthest the fit allowed for. A job or the
Hellbender posted past the edge opens the map further out, as it must to show
them (the drawing keeps the suns to their fitted size there). One sun opens
exactly as it did.
```

## Party spot

Above `func _report_spot(held := false) -> void:`:

```text
Where this ship is in the system, told to the party (`Net.report_spot`,
throttled there), so a partner's map draws it flying (Oct 22 playtest: "we
could not see each other flying around on the sector map"). In orbit of or
alongside a world it is said as the offset from that world, and in either
star's close orbit or settled round one sun as the offset from that sun: a
world's place on its orbit, and a turning pair's suns (PROTOCOL 14), are each
machine's own clock. With this map's clock, which is the party's.
`held`: the map's clock is not running (put away, or held for a move of the
ladder, `clock_held`), so no partner runs it on (`NetSession.party_t`); sent
at once when that changes.
```

## Ship place

Above `func ship_place() -> int:`:

```text
WHERE THE SHIP IS, as LOCAL is told it: a body, -1 the star's close orbit
(star A's), `SystemLayout.STAR_B` star B's, -9 none. Also what
`Router.at_station` reads off the map while LOCAL is built
ahead of the swap: it read `reached` there, so LOCAL opened as the ship burned
onto the station's orbit drew the station's world (this) with no station's
side and a bar saying to fly to the station (that), and the hab ring's picture
once the swap had made the two agree.
```

Inside `ship_place()`, above `if not SystemLayout.is_place(at) and (flight.mode == &"rail" or flight.mode == &"keep"):`:

```text
BURNING ONTO AN ORBIT IS BEING AT THE WORLD, and riding out of one to
leave it is still being at the old one (Jon, Oct 21: "Does the local view
show the planet you are orbiting the first time you go to a planet?"). Kept
as `reached`, which is neither until the burn is over, LOCAL opened as
the ship came in drew open space with the world right there on the map,
and the map, back, dropped the ship off its orbit. Put back, it is on that
orbit (`_restore_ship`); a flight it was waiting to start is let go.
```

Inside `ship_place()`, above `elif not SystemLayout.is_place(at) and flight.mode == &"fly" and SystemLayout.is_place(flight.fly_to):`:

```text
AND A FLIGHT UNDER WAY IS AT THE PLACE IT IS GOING TO, as its arrival burn
already is: the map left on the way (Tab, the HUD's tabs, SAVE & EXIT, the
window closed) puts the ship there, in orbit or alongside, and LOCAL opens
its event. Clicking never loses anything: fly, then orbit, then open. It
put the ship back at the system's edge with the flight gone, which ruling
20's flights, about 24 s where they took 4 to 12, made several times as
likely (the reviews, Oct 31)
```

## Writing on put away

Above `func _notification(what: int) -> void:`:

```text
WRITTEN AS THE MAP IS PUT AWAY, not only as it leaves the tree (Jon: "when
transitioning from one planet to another I have to go to the local and then
the system and then the local again for the local to update"). `Router._swap`
hides the outgoing screen, then builds the next one at once, and only frees
this one at the end of the frame: LOCAL composed its sky (`LocalSky._situate`)
and its event bar (`LocalEventDrawer.here_now`) from the record the last visit
left, the world the ship had just flown away from. Every door off the map --
the HUD's tab, a fight, the dock, Tab, GO -- goes through that hide.
```

## Clock hold

Above `func clock_held() -> bool:`:

```text
THE MAP'S CLOCK HOLDS (ruling 23) for the length of a move of the zoom
ladder (`ZoomLadder.busy`, its camera `cam_held`, the calm move too: from the
click, where the clock is kept, `_keep_ship`) and while it waits built ahead
of one (`ZoomLadder.prebuilt`, at no opacity): a pair's suns turn on the map's time,
and LOCAL holds the angle it was handed (`Run.map_t`) for its visit, so the
pair stands where both pictures have it across the swap. Running on through
a move, the suns had moved by the time the map was seen (a map built ahead
ticked while it waited) or LOCAL's had not (a move down onto the ship), and
a map built ahead and dropped wrote its moved clock back (`_keep_ship`).
YOUR SHIP HOLDS WITH IT (Jon, Nov 2, "Pair calls: 4A"; one sun too): stepped
by no time (`ShipFlight.step`), its ride round its ring or orbit stops with
the suns and the worlds and goes on with them, from the very point, so
nothing moves against a still picture. Riding on by frame time it went round
its world held still for the second or so of a move: turning back on the
line a ladder move draws it on (CalmLadderTest, 6.8 px), and every preview
planned in the hold came back stale, the ship off where it was planned from,
so it was planned again every frame of the hold. Partners drawn here hold
too (`SystemOverlay._draw_partners`).
And hidden (put away, about to be freed): it wrote its clock as it went
(`_keep_ship`), and a frame more run on past the one LOCAL took was written
again on the way out.
```

## Catching up with party

Above `const CATCH_K := 0.25`:

```text
CATCHING UP WITH THE PARTY (PROTOCOL 14): a map behind a partner's in the
same system runs faster until it is there, never past it and never back: by
the gap over CATCH_S, at least CATCH_K and at most CATCH_MAX faster than
time, so a gap closes in seconds and smoothly (from CATCH_CUT, the most a
map out of LOCAL opens behind, `NetSession.handed_clock`, in about 18 s). A
map handed its pair by LOCAL opens on LOCAL's clock, not the party's
(`Router.pair_handed`), so a peer that only goes map to LOCAL and back would
otherwise never come level; at CATCH_K alone it fell further behind on every
visit that was more than a quarter of its time on the map (review 2). Not
while the ship flies a plan (a flight is a plan on map time), so only the
suns, the worlds and what rides with them go faster for a while.
```

## Right click

Above `func right_click(h: Dictionary) -> void:`:

```text
RIGHT-CLICK (Jon: "If you right-click a planet that is selected, it should
zoom the camera onto that planet. A second right-click zooms all the way
out"): onto the selected place, held there as it moves; again, or on empty
space, back out to the opening framing: the whole sector, or a wide pair's
own part (`open_view`; the wheel goes out the rest). A fixed control (a
mouse button: the rebindable keys are keys), listed in Settings > CONTROLS.
```

## GO in flight

Above `func _on_map_input(e: InputEvent) -> void:`:

```text
A GO UNDER WAY (`_taking`, about 27 s of flight on map time) leaves the VIEW
the player's: the pointer hovers and its tip shows, the wheel zooms, a drag
pans (and lets go of LOCATION, as any drag does), a right-click zooms. What
would fly, select or open is refused until it lands -- a click (`tap`),
FLY HERE, GO and WASD -- so its errand is the one that runs, once (Nov 1: the
whole map was shut for the flight). The zoom down onto the ship after it
(`_diving`) keeps the camera to itself, as it did.
```

## Opening a beacon

Above `func open_beacon(body: int, bc) -> void:`:

```text
Opens a beacon in the panel: an encounter's page, or for DOCK, HARVEST and
the custodian the list narrowed to where it is, its card holding the button.
The pulsar's own beacon (body -1) is on the star.
OPENS IT, AND ONLY THAT (Jon: "clicking on a beacon and immediately moving
there is kinda disorienting"): the encounter comes up in the panel and its
world is selected; the ship stays put until you choose something.
```

## Flying

Inside `_fly()`, above `var near: bool = overlay.preview_to == body`:

```text
LANDING IS THE FLIGHT'S OWN BUSINESS: the callback decides what the panel
shows (a choice's result, or the place), so the frame's own "arrived in
orbit" must not open the place over it
THE FLIGHT DRAWN BEFORE IT IS THE ONE FLOWN: the preview's own plan while
its departure is still ahead, else one planned on a worker keeping the
preview's choice (ruling 20's solved flights take a median of 40 ms in a
twin, too long for the frame of a click), the ship riding on meanwhile;
one that finds nothing puts the ship in orbit there (`ShipFlight.fly_bg`)
```

## Zoom ladder

Above `var cam_held := false`:

```text
THE MAP AS ONE DISTANCE OF FOUR (`ZoomLadder`): its camera, moved by the
ladder for the length of a move; where your ship (your star, the world you
orbit) is on screen; the picture's frame. k is 0 at rest and 1 at the
distance toward the other screen: onto your ship at the closest zoom for
LOCAL and the station, back out past the whole sector for the chart.
```

## Ladder star

Above `func _ladder_star() -> Vector2:`:

```text
YOUR STAR ON SCREEN, in the game's picture: star A where the pair has it
now (`SystemOverlay.place_rel`), the one star at the origin. The chart's mark
for your system is a burst for star A with star B small at its lower right
(`StarchartScreen._TWIN`), so star A is what a move to and from the chart
carries onto that mark (1A: `ladder_anchor`, `sun0`), the sun its hole shows
(`ladder_sun`), and the star LOCAL's plane is laid onto (`ladder_plane`).
Anchored on the plane's origin, a pair's moves carried an empty point where
star A had been at t 0 onto the chart's star. The map's clock holds for the
move (`clock_held`), so star A stands still under it.
```

## Ladder UI

Above `var _key_row: Control = null`:

```text
THE MAP'S UI, k of the way gone (`ZoomLadder`: it leaves before the camera
moves and comes back after it lands, never during): the key, the scale bar
and LOCATION, and the words over the worlds (a label magnified with the
picture is a smear of letter-sized blocks). NOT the panel nor the danger
strip: they stay through the move and swap in place for the next screen's
(`ladder_side`, `ladder_bar`, `SideSwap`; Jon, Oct 13).
```

## World handover

Above `var _world_peek := {}`:

```text
its surface's memory and every value its shader was last given -- taken out of
the map as it goes, for LOCAL to draw on (`LocalSky.adopt_near`). {} when the
ship orbits nothing the map draws as a turning world.
THE WORLD AS THIS FRAME WILL DRAW IT, taken by the ladder after its own
camera step each frame of the way in: the map steps its worlds at the top of
a frame from the camera the frame before, so what is on screen is always a
frame behind what the map holds now -- and the picture held at the swap is the
last one drawn. What is handed over is that, not the map's next frame.
```

## Edge arrows

Above `class _Marks extends Control:`:

```text
THE EDGE ARROWS (Jon, Nov 2, "Edge arrows: C"): the overlay's
(`SystemOverlay.mark_rects`, in the picture's own space), drawn over the
picture where it sits in the frame, out of the key shader's edge fade.
Redrawn when the overlay has drawn (`marks_drawn`), so never a frame behind
the picture, and each frame while it shows any (for the overlay hidden).
None while a move of the zoom ladder (or the calm move) runs: the key shader
dissolves the picture into its cloud then (`round_k`), and these stood crisp
over it. None under the hover tip, which covers an arrow. The ships' names
beside their arrows (`SystemOverlay.mark_words`, Jon, Nov 5) with them, in
the map's small words on a 1 px dark rim, as the star chart rims its YOU and
the arrow has its outline (a drop shadow alone left a green name faint on a
sun's glow, the Nov 5 sheet).
```

## Flight said once

Above `var _said_key := 0`:

```text
YOUR FLIGHT, SAID ONCE AS IT STARTS (PROTOCOL 17, `NetSession.report_flight`):
its whole path on this map's clock, about 60 points a second, from the ride
round to its departure to its spin-down onto the ring after
(`ShipFlight.said_path`), so a partner draws the arc it flies and not a
chord between spots; and let go of (W off it, or another place picked on the
way) before it lands, said too.
```
