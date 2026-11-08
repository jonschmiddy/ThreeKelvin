The reasoning behind `tkg/scripts/sim/TwinSiteTest.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Twin site test

Above `const PanelS := preload("res://scripts/ui/sysmap/SystemPanel.gd")`:

```text
STAR B IS A PLACE, AS THE ONE STAR IS (ruling 20, Oct 30: "Prototype: twin:A
giant:A"), on the real map, headless:
  godot --headless --fixed-fps 60 --path . -- sheet=TwinSiteTest

A system with two suns (the run's ordinary system with the longest name, made
a twin the way a harness may, `n.twin = true`), from a world round star A:
  - star B is hit where its sun is drawn, at the size it is drawn (the
    SunView the map puts there, `SystemView.star2`), and star A where it is;
    a click on a sun is on it even with its world just behind it; the tip
    names each "<system> A" / "<system> B" with its kind;
  - each star's close orbit, drawn bigger than life to read, stays short of
    its own world's disc, and a ship's orbit round that world off its sun;
  - one click on star B selects it: the panel's sector page shows both suns,
    each with its own facts and FLY HERE, and the system reads BINARY; every
    word and button on it inside the panel and none on another (fit means
    nothing overlaps), here and on the giant's page with its MASS line;
  - a right-click zooms onto star B and holds it in the middle;
  - star B's FLY HERE flies there: the status line says where it is going,
    then CLOSE ORBIT · <system> B, and the ship rides round star B at the
    layout's close orbit for it; its FLY HERE reads IN A CLOSE ORBIT;
  - the map leaves the ship at star B (`Run.site_here` -4), LOCAL finds no
    event there (star B holds none), and the map puts it back round star B;
  - a partner in star B's close orbit is drawn where it said it was (a spot
    at -4 is absolute, as at -1), and hidden behind star B's disc there;
  - a ship let go round star B, or round both suns, is drawn on a wide orbit
    round that and the words say ORBITING <system> B / BOTH STARS;
  - a ship settled round star B, round both suns or round star A, the map
    left for LOCAL and shown again (and the same through the save's rows),
    comes back on that orbit: the same centre, on its radius within 1 px a
    second on, a flight from there leaving from the ship; one sun the same;
  - the map left on a flight's coast puts the ship where it was going, in
    orbit there, as LOCAL is told and the flight counted (twin and one sun);
    the map_fly hint keeps quiet on the way;
  - the map drawn again round a flight (another rendering style or GRAPHICS
    LOW, `_on_style`): a GO on its coast is in orbit there with its errand
    run once and the map open; a GO still being planned flies on and its
    errand runs on arrival; a FLY HERE on its coast opens the place; a
    flight let go of with W is not flown again (twin and one sun);
  - the curl the map draws for a capture into star B's close orbit is the
    one `start_rail` flies;
  - in either star's close orbit the words by the ship, and a selected sun's
    name, are never written across the other sun;
  - a partner off a world is drawn on that orbit's drawn ring, as your own
    ship is;
  - holding alongside to leave, the status line and the words by the ship
    say LEAVING, not ALONGSIDE and YOU;
  - a ship left at star B in a system with one sun comes back at the star,
    LOCAL's sky with it;
  - it quits with a flight plan still being made on a worker, and the quit
    waits for it (`ShipFlight.drain`: it crashed, signal 11);
  - the zoom the map opens at is the layout's own formula
    (`SystemLayout.open_zoom`) on its frame, and on the real frame every
    twin opens at or nearer than the zoom its rings were fitted to;
  - every giant's MASS line is 1/n of its star (n the whole number nearest
    1 / gm_frac), "OF ITS STARS" round two suns, in the FAUNA row's place so
    the page keeps its rows;
  - the HUD's SECTOR tab says "binary system".
Jon's picks from the twin looks sheet (Nov 1), and "Let's call it Binary
instead of two suns":
  - no string a player reads says two suns or both suns (a world round the
    pair is AROUND BOTH STARS, a ship settled round it ORBITING BOTH STARS);
  - every system lists its SATELLITES in name order, the sector page too, one
    sun's in the order they always were ("list:C"); and every binary's event
    cards, above that list, in the same order;
  - star B reads a K5's own MASS and RADIUS, 0.7 SOL, in every binary, its
    pull as built ("starb:B");
  - on the ring of a world round one sun the ship is drawn over that world all
    the way round in a 1 px light outline, never on a ring round both suns or
    one sun's ("ring:A");
  - over the binaries of three seeds at the opening zoom, with the ship in
    every star's close orbit and on every world's ring, with each other place
    selected, and let go coasting into each world's ring, no word on the map
    is written across a sun (IN ORBIT · OMEGA CALLOUS I ran across both on
    seed 7; WILL ORBIT <world> across one in about half the coasts, a
    selected world's name across its sun), and nearly none held back for it;
    the ship's own words never over an event's beacon where a spot clears
    both (stepped off the suns, IN ORBIT · OMEGA CALLOUS I covered one), and
    where stepped, off the reticle's ticks round their place and over no
    selected name or forecast they would hide where a spot clears it;
  - riding OMEGA CALLOUS I's ring for two orbits, its world selected, the
    ship's words hold still (stepped, they hopped between under the ring and
    under the ship about twice an orbit).
Jon's "Binary kinds: close:B share:A" (Nov 1), `_close_pairs`, over the
binaries of seeds 7, 4242 and 1999 as rolled: about one in three a close pair,
its suns 150 to 170 px apart, every body round both past the steady limit,
nothing meeting (bodies, rings, the suns' keep-outs, close orbits and capture
rings), most with a planet in the middle band, the giant round both suns in
either kind, a ship jumping in arrived out past every world's ring (53 of 56
not, 43 inside the first world, on d9f1afca); and the ring sweep above
sweeps close pairs too.
Jon's "gap:A" (Nov 1): one sun and every close pair open as they always did
(`_opens_as_before`); a wide pair opens framed on its two suns and their own
worlds, the wheel goes out to the whole system and a right-click comes home
to that framing (`_wheel_and_home`); in each wide pair the ring sweep opens,
each world round one sun drawn clear of its sun and every beacon off the
picture marked at the frame's edge on nothing drawn (`_pair_marks`); a ship
put back on a world round both suns is taken into the framing
(`_put_back_framed`); a partner off the picture has its arrow too
(`_partner_marked`). Each arrow's look (Jon, Nov 5, `_arrow_shapes`): its
key glyph as tall as the arrow, and the arrow hollow.
Prints how many twin systems and cases each part saw.

IT JUDGES THE WHOLE BUILD. Where a part is another build's (the flight's ride
round star B and its settle, the drawing's star B), it is checked all the
same and fails on a tree without that build, saying whose it is: on
feat/twin-sites alone, the ride round star B, the settle and star B's drawn
sun fail, and nothing else.
```

## Required ring sweep nodes

Above `const RING_MUST := {7: [284, 46, 83], 4242: [116]}`:

```text
and always these (seed: nodes): the binary the words ran across both suns in,
and those a selected world's name sat across its sun in (SIGMA CINDER-2 II,
LAMBDA FALLOW II, ETA CALLOUS II; the picks review, Nov 1)
```

## Click clock

Inside `_run()`, above `var over: Dictionary = m.overlay.hit(m.overlay.star_scr(-1))`:

```text
(at a clock where no world's beacon is drawn over star A's middle: a beacon
is drawn on top and takes the click, and the clicks below are on the suns.
EPSILON GALLOWS SECUNDUS on seed 4242, this pick since stations were halved
on Nov 3, opened with its world just in front of star A and that world's
beacon over the sun, so the map opens again half the world's turn on)
```

## Pair framing at any clock

Above `const LAP_CLOCKS := 8`:

```text
A WIDE PAIR OPENED AT ANY KEPT CLOCK (ruling 23: the map keeps each
system's clock, `Run.map_clock`, and the pair turns on it): at LAP_CLOCKS
clocks round its lap, `open_view` frames it the same as at t 0 (on the
balance point, no nearer than the circle it sweeps allows,
`SystemMapScreen.pair_reach`), and the
pair as it stands at each (both suns' discs and every world round one sun,
its whole circle and reach) is inside the picture that frames, on the
layout's frame. 1 where it holds, else 0 and why in `bad`. Held still
(`-- pair=0`) every clock is the laid-out pair, as before.
```

## Put back framed

Above `func _put_back_framed() -> void:`:

```text
A SHIP PUT BACK ON SOMETHING THAT CIRCLES BOTH SUNS, the map shown again: the
opening framing takes it in (`SystemMapScreen.show_system`), so it is on the
picture, its place too, and the framing is still no further out than the
whole system. Framed on the pair alone the ship was off it, and the move
down from LOCAL ended on nothing.
```

## Close pair

Above `const CLOSE_SEEDS := [7, 4242, 1999]`:

```text
THE CLOSE PAIR (Jon, Nov 1, "Binary kinds: close:B share:A"), over the
binaries of CLOSE_SEEDS as each rolls them, laid out, no map:
  - about one binary in three is a close pair, the rest wide, on every seed;
  - its suns 150 to 170 px apart, every body round both, at the balance point
    and past 1.03 of the nearest steady orbit round the pair;
  - nothing meets: no two bodies, no world's ring and a sun's close ring
    (RING_GAP, one sun's rule), no sun's keep-out, close orbit or capture ring
    and the other's;
  - most have a planet in the middle band, where a city, a green world or an
    ocean can be (a wide pair's are near or far);
  - in both kinds the giant circles both suns.
How often a body sits inside another world's ring is printed against one
sun's, not judged (the sheet's cost: about twice as often). The words on the
map are `_ring_sweep`'s, which counts the close pairs it saw.
```

Inside `_close_pairs()`, above `var z := SystemMapScreen.zoom_for(L, c, SystemLayout.FIT_FRAME)`:

```text
THE SHIP ARRIVES OUT PAST EVERY WORLD, at the frame's edge as round
one sun (`SystemMapScreen.show_system`'s point, on the layout's
frame): packed close, the rings left no clear circle there, and it
was put inside the first world beside the suns (43 of 56 on
d9f1afca, the built stills)
```

## Opening zoom

Above `func _fit_zooms() -> void:`:

```text
THE OPENING ZOOM IS THE LAYOUT'S FORMULA. `SystemMapScreen.fit_zoom_in` on
the layout's frame is `SystemLayout.open_zoom`, for every system of the run
(twins forced on where they may be); and on the frame the map really has,
measured off a real map, no twin opens further out than its rings were
fitted to (`fit_zoom`), with no job or Hellbender out to widen it.
```

## Sun click with world behind

Above `func _hits_behind(m: SystemMapScreen) -> void:`:

```text
A CLICK ON A SUN IS ON THE SUN WITH ITS WORLD JUST BEHIND IT. In a pair a world
round one star passes 6 to 8 px from its sun's middle at the far side of its
circle, behind the disc; its click circle took the sun's middle there. Each
star's own world is put just behind its middle (3 px up the screen, further
from the viewer) and just in front (3 px down), where the view puts bodies
(`view.pos` / `view.at`) and put back at once: behind, the click is the sun's;
in front, the world's, which is drawn over it. Then round one turn of its
circle, every place it is behind the sun's middle.
```

## Orbit fit

Above `func _orbit_fit(m: SystemMapScreen) -> void:`:

```text
WHAT FITS ROUND A STAR OF TWO, AS DRAWN, at the opening zoom. An orbit is
drawn bigger than life to read (`SystemOverlay._orbit_k`: the place's disc +
9 px at least), and in a pair that floor would reach past what is next to
it. On this map: each star's close orbit (the layout's,
`FlightSolve.star_orbit_r`) is drawn short of the disc of its own world by 2
px where that world stands widest from it, and a ship's orbit round that
world (the flight's `orbit_r`) 2 px off its sun's disc, unless it truly is
that big. Then for every twin of the run at its fit_zoom, by the layout's own
drawn sizes (`sun_drawn`, `world_drawn`): how many cut through before the cap
and after, and the least room left between a close orbit and its sun.
```

## Fit

Above `func _fit(m: SystemMapScreen, tag: String) -> void:`:

```text
FIT MEANS NOTHING OVERLAPS: the page as it stands at the panel's real size.
It asks for no more width than the panel's text column (else, with the
scroll bar up, the panel widens and the map frame narrows); every one-line
label's words fit its own box; every word and button is inside the page; and
no two of them meet.
```

Inside `_fit()`, above `var mw := 0.0`:

```text
THE PAGE'S OWN ROWS (the head, its facts and ways in: what this build
adds), each no wider than the text column; and the event cards under them
(a card naming the world you orbit asked for 231 px of the 226, its tags
and YOU · <place> on one row; that row now wraps, Nov 1)
```

## Star B close orbit

Above `func _round_b(m: SystemMapScreen, what: String) -> void:`:

```text
WHERE THE SHIP IS, IN STAR B'S CLOSE ORBIT: measured on the plane from star
B's own place, against the layout's close orbit for it
(`FlightSolve.star_orbit_r`, its rail in a twin), not the flight's own idea
of either. `reached() == STAR_B` alone passed with the ship riding star A.
The ride is the flight build's (`ShipFlight.center` / `orbit_r` for star B):
on a tree without it this fails, as it should.
```

## Partner arrows

Above `func _partner_marked() -> void:`:

```text
A PARTNER OFF THE PICTURE HAS ITS ARROW AT THE EDGE, as your ship and the
events' beacons do (`SystemOverlay._draw_edge_marks`): this wide pair at its
opening framing, a partner out in open space round both suns, below the
balance point most of the way to the edge.
The whole-system view kept every partner on the picture; framed on the pair,
15 of seed 7's 16 such were nowhere (the gap:A review). The arrow in the
party's colour, inside the frame, and off the partner's own hull.
```

## Settle round star B

Above `func _settle_round(n: MapGen.MapNode) -> void:`:

```text
LET GO ROUND STAR B, AND ROUND BOTH STARS: the wide orbit is drawn round what
the flight settles round (`SystemOverlay._star_c`, from the flight's own
settle centre, `ShipFlight.f.cen`), and the status line names it (from
`f.cen_id`). It read `ShipFlight.star_orbit_c`, which the flight never built,
and so drew and named every wide orbit round star A. First the names alone,
from each centre; then the flight's settle (`ShipFlight.settle_at`, the
flight build's: on a tree without it this fails, as it should), at a point
inside star B's steady zone on the far side from its world, and at one out
between the suns' zones and the worlds round both.
```

## Settled star B moves

Above `func _settled_as_b_moves(m: SystemMapScreen, p: Vector2, nm_b: String) -> void:`:

```text
SETTLED ROUND STAR B AS IT MOVES (ruling 23): let go round star B, the clock
running for two seconds as the pair turns, every frame the status line and
the words by the ship say ORBITING <system> B (`SystemOverlay._settle_id`,
by the flight's `f.cen_id`), and the wide orbit is drawn round star B where
it is that frame (`_star_c`), on its disc (`_ring_c`, star B's place on the
grid). Named by where its centre was kept, a ship round star B drifted to
ORBITING BOTH STARS within seconds of the pair turning. Then broken away, the
orbit left fades round star B (`_left`, by id).
```

## Restore round

Above `func _restore_round(n: MapGen.MapNode) -> void:`:

```text
PUT BACK ON THE WIDE ORBIT IT WAS SETTLED ON: round star B, round both suns
and round star A (the way round the worlds do not go, to see it kept), the
map left for LOCAL and shown again, and again with the record through the
save's own rows (`SaveGame._parked_to` / `_parked_from`, JSON and back). The
same centre and way round, on its radius within 1 px then and a second on,
the status line naming it, and a flight from there leaving from the ship
(`ShipFlight._dep_of`). Put back with only its point it kept the arrival
orbit `setup` makes, round the balance point, and was pulled onto that
radius round its own star: round B at 68 px, back on a 314 px ring that ran
inside star A's keep-out (the seams and saves reviews, Oct 31).
```

## Labels off suns

Above `func _labels_off_suns(n: MapGen.MapNode) -> void:`:

```text
NEVER WRITTEN ACROSS THE OTHER SUN: in each star's close orbit, at the
opening zoom, the words by the ship ("CLOSE ORBIT · <system> A/B") and the
other star's name when it is selected, their boxes as placed
(`SystemOverlay.label_rects`) against the other sun's disc. In this system
the words in star B's close orbit sat 10 px over star A's disc, its whole
radius (the words review, Oct 31).
```

## Ship words off beacons

Above `static func _ship_words_off_beacons(ov, full: String, place: int, where: String, st: Dictionary, out: Array[String]) -> void:`:

```text
THE SHIP'S OWN WORDS OFF THE BEACONS: `full` (IN ORBIT · <world>, CLOSE ORBIT
· <star>) or the words before its " · ", as placed last frame, against every
event's beacon drawn that frame (`_on_beacon`). Counted in `st`: placed
(`bc_words`); left by a beacon where no spot cleared the suns and the
beacons both (`bc_fallback`, `SystemOverlay.label_on_beacon`; none on a tree
without it); over a beacon all the same (`bc_crossed`), each added to `out`.
AND WHERE THE OVERLAY STEPPED THEM clear of the beacons (`bc_stepped`,
`SystemOverlay.ship_words` clear &"all" or &"marks"): off the corner ticks of
the reticle round `place`, the place they name (`bc_ticks` where not), and
over none of the words they hid (`SystemOverlay.label_under`; `bc_hid` where
they are) but where the overlay says no spot cleared those as well (&"marks",
`bc_marks`). Words where they first stood may cross the ticks under the ring,
as with one sun; stepped, the ticks once moved them 20 px and they hid a
selected place's name a step less far would have shown (the review of
19fd37e5, Nov 1).
```

## Capture curl

Above `func _capture_curl_b(n: MapGen.MapNode) -> void:`:

```text
THE CURL DRAWN FOR A CAPTURE INTO STAR B'S CLOSE ORBIT IS THE ONE FLOWN: the
overlay's (`SystemOverlay.capture_ins`) against `ShipFlight.start_rail`'s own
insertion, for captures just inside B's ring from all round it, coming in
and going round both ways. Drawn against star A's keep-out it was up to 58
px off the curl flown (the seams review, Oct 31).
```

## Map left mid flight

Above `func _mid_flight_tab(n: MapGen.MapNode, what: String) -> void:`:

```text
THE MAP LEFT ON A FLIGHT'S COAST (Tab, the HUD's tabs, SAVE & EXIT): the
ship is where it was going, in orbit there -- LOCAL told so (`Run.site_here`)
and the flight counted (`flown_to`), the map putting it back on that orbit.
It put the ship back at the system's edge with the flight gone, and ruling
20's flights, about 24 s, made that several times as likely (the reviews,
Oct 31). On the way, the map_fly hint ("Click a world twice to fly there")
keeps quiet: a click does nothing then.
```

## Style change mid flight

Above `func _restyle_mid_flight(n: MapGen.MapNode, what: String) -> void:`:

```text
THE MAP DRAWN AGAIN ROUND A FLIGHT, as Settings' style and GRAPHICS rows do
it (`Sig.render_style_changed`, `SystemMapScreen._on_style`): the flight's
errand goes on with the new ship (`ShipFlight.hand_over`, `_carry_on`). It was
lost: a GO cut short this way left the ship at its target with the event
never opened, and `_taking` true, so the map took no click, hover, zoom, drag,
WASD or FLY HERE until it was left (the recheck's probe, Oct 31, both a twin
and one sun; main has the same code, ruling 20's ~24 s flights made it likely).
```

## GO leaves view open

Above `func _go_view_open(n: MapGen.MapNode, what: String) -> void:`:

```text
A GO LEAVES THE VIEW OPEN (kept finding [11], Nov 1: the whole map was shut
for the flight, about 27 s on map time), through the window's own input
(`push_input`, so the map's frame takes it as a hand's): while it flies the
pointer hovers and its tip shows, offering no click; the wheel zooms; a drag
pans; a right-click is the view's. A click, a double click, FLY HERE and WASD
are refused, so the GO's errand is the one that runs, once, on arrival, and
after it a click selects again.
```

## Alongside hold words

Above `func _alongside_hold() -> void:`:

```text
HOLDING ALONGSIDE TO LEAVE (`FlightSolve`'s KEEP_HOLD, and while the flight
is planned): the status line says LEAVING · TO <place> and the words by the
ship LEAVING · <here>, as a ring's ride round to leave says LEAVING ORBIT. It
said ALONGSIDE, and YOU by the ship, with the flight already drawn (the
seams and seen reviews). In the first system of the run with a station,
belt, hulk or contact.
```

## Quit and zoom ladder

Above `func _ladder_holds_the_pair() -> void:`:

```text
IT QUITS WITH A FLIGHT PLAN STILL BEING MADE on a worker (a preview asked
for this frame): the quit waits for it (`ShipFlight.drain`, Router). Not
waited for, its task crashed the quit, signal 11, exit 134 (the scroll
check, 3 of 3; the saves review's QuitLens, Oct 31).
THE ZOOM LADDER HANDS THE PAIR OVER WHERE IT STANDS (ruling 23; the review of
the plan, "the zoom-ladder handovers"), the moves animated as in play
(`Router.animate_in_harness`, the ladder's clock 1/30 s a frame), on a wide
pair's map opened a quarter of the way round its lap:
  - down to LOCAL, the map's clock kept at the click holds through the move
    (`SystemMapScreen.clock_held`), so the clock LOCAL is handed
    (`Run.map_t`) is the one the map last drew;
  - back up, the map built ahead (`ZoomLadder.prebuilt`) waits at that clock
    and holds it through the move, then runs on once it lands;
  - out to the chart by 1A (behind the calm switch, as LadderTest's every
    design), the move anchors on star A where it is now (`ladder_anchor`,
    the sun its hole shows, `ladder_sun`), not on the plane's origin where
    star A stood at t 0, and the map's clock holds through it too.
Running on through a move, the suns stood a frame's worth of turn or a whole
pre-roll's from where the other picture had them, and a map built ahead and
dropped wrote its moved clock back.
```

## Star facts

Above `func _page_facts(m: SystemMapScreen, nm: String) -> Dictionary:`:

```text
EACH STAR'S FACTS AS IT IS DRAWN (kept findings [23] and [27], Nov 1): star B
read YELLOW DWARF, G2, 5,700 K, star A's, under the orange sun the map draws,
and MASS read each star's share of the pair's pull (star A 0.55 SOL beside G2,
which no G2 weighs). Now star A reads as the one sun does, and star B as the
K5 orange dwarf its colour is nearest, with a K5's own MASS and RADIUS, 0.7
SOL each (Jon, Nov 1, "starb:B"; they read its mass against A's as their
pulls are, 0.72 to 0.92, and its drawn radius). The pulls are as they were.
The sector page as it stands, star by star: its kind under its name, then
CLASS, SURFACE, MASS and RADIUS.
```

## Satellite name order

Above `func _name_order_all() -> void:`:

```text
THE SATELLITES LIST IN NAME ORDER ("list:C"): every system of the run, laid
out each way it may be, lists its bodies (`SystemLayout.name_order`) with the
numerals of their names going up, I, II, III (past X, which ROMAN stops at,
X again); round one sun that is the order they were made in, so nothing there
moves. The binaries whose made order was not their names' are counted: the
list read III, IV, I, V, II, VI in some.
```

## No two suns wording

Above `func _no_two_suns_said() -> void:`:

```text
NO STRING A PLAYER READS SAYS TWO SUNS ("Let's call it Binary instead of two
suns"): every string in the game's scripts, scenes and data, the harnesses and
comments left out, read for "two suns", "two-sun", "second sun" and "both
suns". The sector page, the HUD's tip (`_stars_as_places`) and the chart's
STAR row (`MapGen.BINARY`) say binary; a world round the pair, and a ship
settled round it, say BOTH STARS (the AROUND row read BOTH SUNS beside the
page's BINARY, the picks review, Nov 1).
```

## Ship on ring frames

Above `func _ring_frames(m: SystemMapScreen, w: int, frames: int, every: int) -> Dictionary:`:

```text
THE SHIP ON A RING, frame by frame (`SystemOverlay.ship_px`): over `frames`
frames, every `every`th, with world `w` the ring it rides. Counts the frames
looked at, those with any of the hull drawn and those with the light outline
(&"rim"); the outline's pixels in another colour, on the hull's shape or not
beside it; the hull's pixels hidden by nothing but its own world (any other
world's disc or a sun's explains one); and the frames with the ship's middle
on its own world's drawn disc, where it sat hidden in part before ring:A.
```

Inside `_ring_frames()`, above `var over := false`:

```text
(a frame with the hull over its world's disc, so "never hidden" was asked
of it: by its pixels, not its middle -- the ring's near point is about
the disc's own radius from the world's middle at the opening zoom, so the
middle came onto the disc in a few frames or none by the rounding alone,
4 of 60 with the pair held still and 0 once it turns, ruling 23)
```

## Preview end gap

Above `func _preview_end_gap(m: SystemMapScreen, wa: int) -> void:`:

```text
WHERE THE FLIGHT DRAWN BEFORE IT IS FLOWN ENDS, flown to a world round star B
from the ring of the world round star A (the review of the plan, PLAUSIBLE:
at Kepler x 4 those two worlds go round their suns four times as fast, and
their suns turn, so the line's end, round where the world will be when the
ship gets there, `SystemOverlay._ends_table` at the plan's own moments,
stands off where it is drawn now): printed, not judged, for Jon to see; and
a ring drawn there goes behind the world's disc as drawn now, judged.
```

Inside `_preview_end_gap()`, above `var cw: Vector2 = v.screen(then3.x, then3.z)`:

```text
THE RING ROUND WHERE IT WILL BE (as the let-go forecast draws its orbit
there, `SystemOverlay._line`), dashed and solid: its far half never
crosses the world's disc as it is drawn now. Cut only round its own
centre, 7.8 px off the drawn world at the opening zoom, it was drawn
across the world's face (review 1, Nov 2)
```

## Words hold on ring

Above `const RIDE_FRAMES := 400`:

```text
THE WORDS BY THE SHIP HOLD STILL AS IT RIDES ITS RING: in OMEGA CALLOUS REACH
(seed 7, node 284), on the ring of its first world round star A (OMEGA
CALLOUS I), the world selected as in the picks stills, at the opening zoom,
the clock running for `RIDE_FRAMES` frames (about two orbits). The words are
there every frame and, measured from where their world is drawn (it goes
round its sun, carried as its sun turns: ruling 23), never move more than 3
px from one frame to the next, and spread no more than 3 px each way over the
ride.
Stepped off a sun and the beacon there, nearest first under the ring, above
it and under the ship together, they hopped 6 to 10 px between under the
ring and under the ship about twice an orbit and slid with the ship between
(the review of 19fd37e5, Nov 1); still, as they stood on b764c344, on the
beacon.
```

## Words at beacon edge

Above `func _close_b_words_ride() -> void:`:

```text
THE WORDS BY THE SHIP DO NOT FLICKER AT A BEACON'S EDGE (review 2): in star
B's close orbit of seed 7's close pair (system 41, ZETA VESPER-4) from map
time 97 to 107, the beacon on a world round both suns creeps along the
words' left end as star B carries the words the same way. They stepped 16 px
down off it, back up as it cleared by a hair and down again, three hops in
4 s; stepped off, they now go back only once their first spot clears by
`SystemOverlay.WORDS_BACK_PX`. At most the one step off, never back and forth.
```

## Edge arrow look

Above `func _arrow_shapes() -> void:`:

```text
THE EDGE ARROW'S LOOK (Jon, Nov 5: "make the icon the same height as the
arrow and make the arrow hollow"; then "Two px"), for each of the eight ways,
drawn by `SystemOverlay._tri_queue` alone: the key glyph in 2 px cells, as
tall across the arrow's axis as a side arrow is (10 px), centred on that
axis, and on a diagonal arrow centred on its middle line; the arrow's line 2
px (`_arrow_line`: every one of those cells in its colour), the hole inside
it never in its colour, only the dark ring just inside the line, and nothing
at all further in. And a ship's arrow with a name (Jon, Nov 5, "hollow arrow
with their name"): the name's box beside the arrow on its inward side, off
the arrow, in the mark's box, a side arrow's caps on its axis and an up or
down arrow's name centred on it.
```

## Wide pair framing

Above `const PAIR_GAP_LEAST := 24.0`:

```text
A WIDE PAIR OPENS FRAMED ON ITS OWN PART (Jon, Nov 1, "gap:A"), as the ring
sweep shows each wide pair (`_pair_marks`): at `SystemMapScreen.open_view`,
nearer than the whole system and centred on the two suns and their own
worlds; each world round one sun drawn PAIR_GAP_LEAST px or more clear of its
sun's disc beside it (fitted to the whole system it was 5 px, seed 7); every
event's beacon off the picture with an arrow at the frame's edge
(`SystemOverlay.edge_marks`), each inside the frame and over nothing drawn
there: the words, the beacons, the suns, the worlds, your ship, the status
line, the goal, the instrument or another arrow.
```

## Named arrows

Above `const SHIP_NAME_LONG := "Alexandria Kesselring-Vanterpool"`:

```text
YOUR SHIP'S AND THE PARTNERS' ARROWS, NAMED (Jon, Nov 5: "Maybe hollow arrow
with their name?"), on this wide pair at its opening framing: your ship put
in orbit of a place round both suns off the picture, and five partners off
it (`Net.roster`, `Net.spots`) -- four round the frame from an angle that
turns with each pair, and one straight out past a corner -- one of them with
a long name (SHIP_NAME_LONG). Each ship's arrow carries its name (YOU, the
pilot's, cut with ".." to `MARK_NAME_MOST` or less), its box (`name_box`)
inside the frame, in the mark's box, off its arrow and on its inward side,
queued for the screen (`mark_words`); every arrow's box, names in, inside the
frame and on nothing drawn (`_drawn_under_marks`) or another arrow.
```

## Nearer sun click

Above `func _nearer_hit(m: SystemMapScreen, sd: int, n: MapGen.MapNode, st: Dictionary, bad: Array[String]) -> void:`:

```text
THE NEARER SUN TAKES THE CLICK (ruling 23, "stacked:A": a close pair turns
through standing one sun in front of the other, the near one drawn over the
far), on this close pair's map at its opening zoom: over a lap of the pair,
the moment the suns' discs overlap most with each sun in front; there, a
click between their middles, on both discs, is on the nearer sun
(`SystemOverlay.hit`, the suns nearest first). Tried in fixed order, star A
first, the click went to star A behind star B's face. A pair whose discs
never meet at this zoom is counted, not judged.
```

## Words hold as suns turn

Above `const TURN_RUNS := 3`:

```text
THE WORDS HOLD AS THE SUNS TURN (ruling 23: each frame's nearest clear spot,
`SystemOverlay._spot_off_suns`, made the words hop a whole step as a sun
crept past a spot tried before theirs; DESIGN step 5): in the first
TURN_RUNS close pairs, the ship in star A's close orbit at the opening zoom,
the clock stepped TURN_STEP_S a frame through a whole lap of the pair, the
words by the ship (CLOSE ORBIT · <system> A, or CLOSE ORBIT alone) measured
from star A where it is (`_body_scr`, what they are centred on). Twice: as
the overlay places them, each spot held while it stays clear
(`SystemOverlay._spot_kept`), and placed afresh each frame, its memory
cleared, as they were before the pair turned. Held, they hop (move more than
3 px in a frame, or change what they say) no more often than afresh and at
most TURN_HOPS_MOST times a lap; never across a sun; held back off one in
at most 1 frame in 20.
```

## Ring sweep

Above `func _ring_sweep() -> void:`:

```text
THE WORDS BY THE SHIP NEVER ACROSS A SUN, AND THE SHIP ON A SMALL WORLD'S RING
OUTLINED, over the binaries of `RING_SEEDS` as each seed rolls them (at most
`RING_CAP` a seed), on the real map at its opening zoom: the ship put in each
star's close orbit and in orbit of each world, a world round one star at
three moments of its year. Every word placed that frame
(`SystemOverlay.label_rects`) clear of both suns' discs; the ship's own words
(IN ORBIT · <world>, CLOSE ORBIT · <star>) counted where they stand whole,
shortened to IN ORBIT or CLOSE ORBIT, or held back. The outline on the ring of
each world round one star, as `_ring_outline_open`; none round both suns, nor
(once a seed) round one sun's world. OMEGA CALLOUS REACH on seed 7, its first
world round star A: IN ORBIT · OMEGA CALLOUS I ran across both suns, under
the ring, above it and under the ship all crossing one (Nov 1).
THEN IN EACH BINARY (the picks review, Nov 1): its event cards
(`SystemPanel._events`) in name order; the ship on its first world's ring
and each other place but a belt selected in turn, its name clear of both
suns; and the ship let go from four sides of each world, coasting into its
ring (held at its point, the clock still), the forecast's WILL ORBIT <world>
or WILL BE ALONGSIDE <world> clear of both. Each name and forecast counted
shown, held back off a sun (`SystemOverlay.label_held`) or under a higher
label (the map's rule since before binaries). On 35ce5c73, 235 words across
a sun: 226 forecasts (WILL ORBIT IOTA CINDER-2 I across IOTA CINDER-2 B on
seed 7) and 9 selected names (IOTA CINDER-2 II across IOTA CINDER-2 B).
THE SHIP'S OWN WORDS OFF THE BEACONS, at each place and each selection
(`_ship_words_off_beacons`): clear of every event's beacon drawn that frame,
but where the overlay says no spot cleared the suns and the beacons both
(`SystemOverlay.label_on_beacon`, the suns-only fallback, counted and at most
1 in 50). On b764c344, stepped off a sun, 209 of 760 sat over a beacon (IN
ORBIT · OMEGA CALLOUS I over the one above its world, the picks stills);
with every system a binary (`twin=all`), CLOSE ORBIT · TAU BRINE-2 B sat on
one where it first stood, clear of the suns. And where the overlay stepped
them (`SystemOverlay.ship_words`), off the corner ticks of the reticle round
the place they name and over none of the words queued under them that a spot
clears (`_ship_words_off_beacons`). On 19fd37e5 the ticks alone moved them in
209 of 760 frames, and stepped they hid 8 selected names b764c344 showed
(IOTA CINDER-2 II selected from IOTA CINDER-2 I's ring, seed 7).
```

Inside `_ring_sweep()`, above `if two:`:

```text
(in a binary, a world round one sun when it has one: the ship put
back round a giant out past the pair widens the opening to show it,
and a wide pair's opening is checked framed on its own part. Seed
4242's ETA GRIST SECUNDUS, a twin since stations were halved on
Nov 3, opened at 0.32 round its giant, 1.33 of its whole system)
```
