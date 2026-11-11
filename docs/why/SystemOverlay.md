The reasoning behind `tkg/scripts/ui/sysmap/SystemOverlay.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Overlay design

Above `const GLYPH := {`:

```text
WHAT IS DRAWN OVER A SYSTEM'S PICTURE: the stations and derelicts, a beacon
for every encounter, the selection, your ship and the hover tip -- the
approved mockup's (scratchpad `sysmap/template.html`: `frame()`, `shipDraw`,
`tip`) in the game's own colours and face.

A beacon rides its body: a glyph for its lead tag in its tag's colour, a
dotted stem down to the body, a ring pulsing out while it is open; spent, it
stays put, dim, and says what it came to. Hovering a beacon in an exclusive
group dims its rivals, joins them with a dashed line and marks each WILL
BE MADE UNAVAILABLE (Jon's words, the same as the panel's cards); pointing
at a card in the panel does the same here. Two beacons on one world stand
side by side. Your ship warps in at the system's edge and is flown
(`ShipFlight`, Jon's arcade orbits): WASD, the rings that take it into orbit,
the dotted line of where it will end up, and the transfer orbit a second click
flies. A place's beacons are lit only while you are in orbit of it or
alongside it; until then they stand dim (Jon: "when orbiting a planet, that's
when an event on a planet should become available").

HOVER AS THE STAR CHART DOES (`StarchartScreen._draw_tip`): four corner ticks
closing in on the thing as the hover eases in, the tip sliding in with it; the
selection is the same reticle, closed and held. A belt is hovered as its whole
band and brightens.
```

## Ship drawing

Above `const ION_CORE := Color("#5ea6ff")`:

```text
THE ION DRIVE'S COLOURS, two steps of the player's cold drive ramp
(`ThrusterFx.COOL_RAMP`): the cool blue the flame leaves the stern in, and
the paler blue it fades to at the tip. The ramp's deep blue was tried for
the flame's edges and vanished against the map's blue nebulae.
```

Inside `_draw_ship()`, above `var own_w := ringed_world()`:

```text
ON THE RING OF A WORLD ROUND ONE SUN OF A BINARY (Jon, Nov 1, "ring:A"):
that world is small and its ring tight, so at the opening zoom the ship sat
on it (its middle on the disc for a quarter of the lap and up to all of it,
TwinDrawTest), and on the far side the world hid part of the hull. It is
drawn over its own world all the way round, in a 1 px light outline
(`RING_OUTLINE`), so the hull reads on any world and the camera never moves
on its own. Every other world and either sun still hides it.
```

## Orbit look

Above `const ORBIT_MIN_PX := 9.0`:

```text
IN ORBIT OR NOT, AT A GLANCE (Jon: "it's hard to tell if I'm in an orbit or
not"). In orbit the orbit is a solid ring the ship rides, never drawn smaller
than the world's disc plus 9 px: at the opening zoom the ship's offset from
its world is drawn scaled up by `_ok` (eased, so a capture never jumps), from
`_ok_body`. A trail behind the ship; a pulse on capture; the ring left behind
fading as you break away.
```

## Plan preview

Above `const PV_N := 1600`:

```text
THE PLAN DRAWN BEFORE IT IS FLOWN, held steady (Jon: "the predictive path
updates every time the ship rotates around the planet"): from an orbit it is
planned from the orbit itself (its departure point fixed on the ring), and
replanned only when the place, the orbit or the state changes, or every 3 s
to follow the worlds, keeping to the same choice; in free flight every half
second. Each replan blends in over PV_BLEND s, point for point along the path.
(1,600: at 320 a turn-round a few pixels across was cut into corners)
```

Inside `_draw_paths()`, above `if flight != _pv_flight:`:

```text
A NEW SHIP (another system shown, or this one again): nothing drawn for the
last one carries over. Its clock starts again at 0 and the arrival orbit's
key is the same every visit, so a preview from an earlier visit could pass
as this one's and, its time ahead of the clock, never be planned again
(the flight review, Oct 31)
```

Inside `_draw_paths()`, above `var blend: bool = was_same and _pv_new.size() == PV_N and pl.res == null and not pl.ahead and _pv_plan.res == null and not _pv_plan.ahead`:

```text
A SOLVED FLIGHT IS DRAWN AS IT IS, never blended in: the line on
screen is the flight a click flies. Blended over PV_BLEND from
the last, it was another flight for that half second, a fifth of
the time a preview showed (the flight review, Oct 31); the same
flight planned again is the same line point for point, so the
blend only ever showed a flight that had changed. Today's
planner's made for the moment only still blend, as they did.
```

## Harness records

Above `var ship_words: Dictionary = {}`:

```text
THE WORDS BY THE SHIP last frame as `_draw_ship` placed them, for a harness:
{says, at (their baseline's left end), clear}, or {} for none. `clear` is
what the spot `_words_off_suns` stepped them to is clear of: &"all" (the
suns, the events' beacons, the reticle's ticks round the place they name and
the words queued under them), &"marks" (all but those words, which they then
hide: no spot cleared them too), &"suns" (the suns alone: `label_on_beacon`);
&"" where they stand where they first stood, as with one sun.
```

Above `var edge_marks: Array = []`:

```text
THE ARROWS DRAWN last frame, for a harness: {at (the arrow's middle), box
(round all of it, outline and name in), arrow_box, glyph_box (Rect2() with
none), glyph (the key glyph's name, &"" for a ship), name (the words drawn
beside a ship's arrow, "" for an event's), name_box (their box, rim in, or
Rect2()), body (the beacon's place, or -9 a ship), peer (a partner's id, 0
for yours or a beacon), dir (one of the eight, x and y -1 to 1), to (where
what it points at is drawn)}
```

## Words off suns

Above `func _meets_sun(at: Vector2, words: String, but := -99, grow := 0.0) -> bool:`:

```text
WHETHER WORDS AT `at` WOULD BE WRITTEN ACROSS A SUN: their box, as
`_place_labels` builds it, against the disc of each star of a pair but `but`
(one sun has no other). The words a twin puts by a star or a selected name
sat across the other sun about half the time at the opening zoom: the suns
are 56 to 106 px apart there, and such words 140 to 230 px wide (the words
review, Oct 31).
`grow`: the box grown by that much each way (words held off their first
spot come back only once it clears by a margin, `_draw_ship`).
```

Above `func _clear_of_beacons(words: String, also: Array = [], grow := 0.0) -> Callable:`:

```text
WORDS CLEAR OF THE BEACONS, a test for `_spot_off_suns`'s `ok`: their box, as
`_place_labels` builds it, against every event's beacon drawn this frame
(`beacons_at`, filled before any words are placed) and each of `also`.
Stepping the ship's words off a binary's suns put IN ORBIT · OMEGA CALLOUS I
over the event beacon above its world, touching the world's reticle (seed 7,
the opening zoom, the picks stills, Nov 1).
```

Inside `_draw()`, above `if _meets_sun(at, nm, selected):`:

```text
NEVER ACROSS A SUN of a pair: the other side, else under the
reticle, else over it (on a flight to star B it lay over star A's
disc); then each a step further out (`_spot_off_suns`), the side
spots up or down. Where none clears, the name is held back: the
panel names what is selected. A world close to its sun kept its
name across that sun where both first tries met it (SIGMA
CINDER-2 II on seed 7, the picks review, Nov 1). Each spot clear
of the events' beacons too and of the words by the ship where
they first stand (`_ship_words_first`), else of the beacons, else
of the suns alone, as the words by the ship (`_words_off_suns`):
over the reticle is where the place's own beacon stands, and a
step past it they stood on the ship's words, which hid them
(LAMBDA FLINT II on seed 11, the review of the beacons, Nov 1).
```

Above `func _mark_word(key: String, p: Vector2, words: String, col: Color) -> void:`:

```text
A WORD AT A POINT ON THE LINE (TOO FAST, BUMP), on its right as it always
was; in a binary NEVER ACROSS A SUN (`_meets_sun`): on its left, else each a
step up or down (`_spot_off_suns`, held where it stood, `_spot_kept`), else
held back. A coast let go by a turning pair's sun bumps off that sun's
keep-out, a few px past its disc, and BUMP on the bump's right sat across the
sun's face (seed 7 ETA THORN SECUNDUS, coasting into ETA THORN I, with the
pair turned; the sweep met no such coast while the pair held still).
```

Above `func _label_clear(tag: String, at: Vector2, half: float, path: PackedVector2Array, a: float) -> void:`:

```text
THE WORDS FOR WHERE THE LINE ENDS, on a shadow and clear of the line: under
the ring (`half` its half-height round `at`), on the side away from where the
path comes in; failing that centred, or over it, or on the other side.
NEVER ACROSS A SUN of a binary (`_meets_sun`): a spot clear of the line that
meets one is passed over; where the one it falls back on meets one, each spot
a step further out (`_spot_off_suns`), clear of the line and the events'
beacons (`_clear_of_beacons`), else of the line, else not; else the words are
held back (the ring and the reticle still show the place). Coasting into
OMEGA CALLOUS I's ring on seed 7, WILL ORBIT OMEGA CALLOUS I sat across star A
in every frame; over 40 binaries a seed about half the forecasts crossed a sun
(the picks review, Nov 1), and a quarter of those stepped off one then stood
on a beacon (75 of 294 frames, TwinSiteTest's sweep). One sun: as it always
was.
```

Inside `_draw_ship()`, above `var sun: bool = names_on and _meets_sun(Vector2(lx, ly), words)`:

```text
NEVER ACROSS A SUN of a binary (`_words_off_suns`). In a star's close
orbit they sat across the other one, 46 of 90 twins; on the ring of a
world round star A at the opening zoom, under the ring, above it and
under the ship all crossed a sun (OMEGA CALLOUS REACH on seed 7, Nov 1:
the suns 76 px apart, the words 136 px wide). NOR OVER AN EVENT'S
BEACON in a binary, where a spot clears both: stepped off the suns they
covered the beacon over OMEGA CALLOUS I, and in star B's close orbit
of TAU BRINE-2 (seed 7, every system a binary) they sat on one where
they first stood. Off a beacon alone and nothing clear, they stay put.
One sun: as it always was.
```

Inside `_draw_ship()`, above `var was: Array = _spot_mem.get("ship", [])`:

```text
BACK TO THEIR FIRST SPOT ONLY CLEAR BY A MARGIN (WORDS_BACK_PX): words
stepped off last frame (`_spot_kept`'s memory) stay where they stepped
to, while that still clears, until a sun or a beacon creeping a pixel
or two past can no longer flip them. A beacon on a world round both
suns crept along the words' left end as star B carried them the same
way, and in star B's close orbit of a close pair (seed 7, system 41)
the words hopped 16 px down, up and down again in 4 s (review 2)
```

Inside `_draw_ship()`, above `var cut: bool = names_on and not _win_in(0.0).encloses(_words_box(Vector2(lx, ly), words))`:

```text
NOR CUT BY THE FRAME (Nov 5): under a ring near the frame's edge, or
under a world off the picture, they ran in past the edge, the first
letters cut ("ᴀLONGSIDE · ALPHA KESTREL III" under your ship's arrow
at the edge). With the ship on the picture they step in as off a sun
(`_words_off_suns` keeps every spot inside the frame), back only clear
of the edge by the same margin. Off the picture its arrow says YOU and
the status line at the frame's top left says the same, so words that
would be cut go, and so do words pushed in to hug the edge, in the key
shader's edge fade (`NavField.EDGE_FADE`): under a world off the
picture's left side, ALONGSIDE · SIGMA KESTREL III stood 4 px in, its
A faded out (seed 7, system 314, the review of round two)
```

Above `func _win_in(m: float) -> Rect2:`:

```text
THE WORDS BY THE SHIP AND WHERE THEY FIRST STAND, the ship drawn at `x`:
[the words, their baseline's left end], or [] where it says YOU instead.
What it is doing, by the ship itself: in orbit, alongside, a close orbit
(which says which ship well enough: YOU would sit on the ring). Under the
ring they name, centred on its place (under the ship they sat on the world
when zoomed in); off a ring, under the ship. `_draw_ship` steps them off a
binary's suns and beacons from here (`_words_off_suns`); a selected place's
name stepping off a sun keeps off them here too.
The map's window drawn in by `m` px, never a negative size: before the map
is laid out (a harness, a screen still opening) the window can be empty, and
a negative Rect2's has_point and encloses log errors (the Nov 5 gate).
```

Above `func _words_off_suns(words: String, on: int, x: Vector2) -> Array:`:

```text
WHERE THE WORDS BY THE SHIP GO CLEAR OF A BINARY'S SUNS (`_meets_sun`) and
its events' beacons, as [their baseline's left end, the words, what that
spot is clear of (`ship_words`)], or [] where nothing clears. The spots the
words always tried: under the ring they name (under the ship off a ring),
above it, under the ship. The two by the ring first, each a step further
out, 2 px at a time to `WORDS_STEP_MOST`, the nearer first; then under the
ship, the same. Tried nearest first all three together, the words hopped
between the ring's spots and the ship's as it rode round, about twice an
orbit on OMEGA CALLOUS I (seed 7, Nov 1): under the ring stands still, under
the ship goes round with it. Then the same for the words before their " · "
alone (IN ORBIT, CLOSE ORBIT, ALONGSIDE: the status line at the frame's top
left still names the place). Each spot clear of the events' beacons too, of
the corner ticks of the reticle round the place they name
(`_clear_of_beacons`), and of the words queued under them (a selected
place's name, the forecast's), which `_place_labels` would hold back under
them: above the ring they covered the beacon over OMEGA CALLOUS I, and
stepped off a beacon or a tick they hid the name of IOTA CINDER-2 II,
selected from IOTA CINDER-2 I's ring (seed 7, Nov 1). Where none clears all
that, the same clear of the beacons and ticks alone (&"marks", the name
under them held back), then of the suns alone (&"suns", `label_on_beacon`),
so a beacon never holds them back. Where nothing clears, the words are held
back off a sun, as `_place_labels` holds back words that would sit on
others, and the status line says them.
```

Above `func _spot_kept(key: String, words: String, tries: Array, but := -99) -> Array:`:

```text
WORDS STEPPED OFF A BINARY'S SUNS HOLD WHERE THEY STOOD (ruling 23): the suns
of a pair turn, and each frame's nearest clear spot (`_spot_off_suns`) made
the words hop a whole step (up to `WORDS_STEP_MOST`) whenever a sun crept
across a spot tried before theirs: a lap of a close pair turning under the
words by the ship in star A's close orbit, placed afresh each frame, moved
them 59 times and hopped them 13 over three pairs, held 26 and 8
(TwinSiteTest, seeds 7, 4242 and 1999). So each kind of words stepped (`key`:
the ship's, a selected name, the forecast's, a warning on the line) keeps
last frame's spot, as the same try (its spot and how far along its step),
while those same `words` still stand clear there; pushed by a sun, they step
on along that same way first; only where that way is used up are the spots
tried afresh, nearest first. The spot is the try's own each frame, so the
words ride with the place they name (a world round one sun goes round with
it). `tries`: [[tag, spots, steps, the words to place, ok (`_spot_off_suns`),
anything else], ...], the order to try them afresh in. Returns [the spot, the
try], or [] where none clears.
```

Above `var _spot_i := -1`:

```text
THE NEAREST SPOT CLEAR OF A BINARY'S SUNS for `words` (`_meets_sun`, every
star but `but`): each of `spots` as it is, in its order, then each moved on
along its own `steps` 2 px at a time to `WORDS_STEP_MOST`, the nearest first.
Their box, as `_place_labels` builds it, inside the frame, and passing `ok`
where one is given (clear of the events' beacons, `_clear_of_beacons`; the
let-go forecast's words clear of its path too). Vector2.INF where none
clears. The ship's words (`_words_off_suns`), a selected place's name and the
forecast's (`_label_clear`) all step out this way: the forecast's
WILL ORBIT <world> sat across a sun in about half the coasts into a binary's
rings at the opening zoom, and a selected world close to its sun had its name
across that sun on every side it tried (the picks review, Nov 1). `only` and
`from_d`: that one spot alone, from that far along its step on (a spot held,
`_spot_kept`). Which spot it found and how far along, `_spot_i` and `_spot_d`.
```

## Edge marks

Above `var mark_zoom := INF`:

```text
WHAT IS OFF THE PICTURE, MARKED AT ITS EDGE (Jon, Nov 1, "gap:A"): a wide
pair opens framed on its two suns and their own worlds
(`SystemMapScreen.open_view`), so the events out on what circles both suns
-- fights, salvage, jobs, the Hellbender -- start off screen. Each event's
beacon off the picture, your ship and each partner's has a small arrow at the
frame's edge pointing to it, where the line to it from the frame's middle
crosses the edge. The look is Jon's "Edge arrows: C" (Nov 2): a narrow
triangle (`tri_px`) in the beacon's own colour, closed or not (your ship's in
ice, a partner's in the party's green), an event's with its key glyph just
behind it and one dark outline round both, a tag on the arrow and never a
second beacon; and since Nov 5 ("make the icon the same height as the arrow
and make the arrow hollow") the glyph in 2 px cells, as tall as the arrow,
and the arrow its line alone (`tri_line`), the map showing through it; that
line 2 px (Jon, Nov 5, "Two px": the 1 px line read lighter than the glyph's
2 px strokes). Your ship's and each partner's arrow is hollow too, and named
(Jon, Nov 5, "hollow arrow with their name"): YOU, the star chart's word for
your ship, in ice, a partner's pilot in the party's green, the map's small
words beside the arrow on its inward side (`_name_at`), inside the frame and
moving round the edge with it. The map screen draws them over the picture
(`SystemMapScreen._Marks`, from `mark_rects`), out of the key shader's edge
fade, which left the first arrows faint. Only at the opening zoom or further
out (`mark_zoom`): zoomed in, looking closer is the player's choice, and
LOCATION and a right-click hold what they look at. Never on anything else
drawn there: each arrow is slid round the edge clear of the words
(MARK_WORDS_CLEAR off them: an arrow just under the status line read as its
bullet, a thing to press) and of the column under the status line and the
goal (MARK_UNDER_WORDS: an up arrow there read as the line's caret), the
suns, the worlds, the beacons, the reticles and the bracket, your ship and
the partners', the goal and the instrument (`mark_keep`) and the arrows
already placed, and left out where no spot clears. Not a control: it takes
no click (only pressable things look pressable).
```

Inside `_draw_edge_marks()`, above `for e: Array in partner_at:`:

```text
and each partner's (the whole-system view kept every partner on the
picture; framed on a wide pair's own part, one out on a world round both
suns was nowhere: 15 of 16 such on seed 7, the gap:A review), named
```

## Edge arrow shape

Above `const TRI_SIDE := ["##...........", "#####........", "########.....", "###########..",`:

```text
THE ARROW, a narrow triangle 13 px long and 10 across, its point cut to
2 px, its sides in even 3 px stairs (about 40 degrees at the point: the
90-degree one read as a mound pointing up, a play button pointing right).
Pointing right, round its middle (the row and column of the first cell):
```

Above `const TRI_DIAG := ["..........##", ".........###", ".......####.", ".....#####..",`:

```text
and pointing up-right: the same triangle turned 45 degrees, its point on the
diagonal and no edge along the frame (the wedge with its legs on the axes
read as a ramp, and pointing down-right as a window's resize grip), its point
a 2 px corner and its back corners blunted a pixel (a 3 px square point with
1 px back corners read as pointing the other way)
```

Above `func _name_at(q: Vector2, dir: Vector2i, ab: Rect2, w: float) -> Vector2:`:

```text
WHERE A SHIP'S NAME STANDS beside its arrow at `q` pointing `dir` (`ab` the
arrow's box, outline in), as its baseline's left end: on the arrow's inward
side, MARK_NAME_GAP off its outline. Beside a side arrow, the caps on its
axis; beside a diagonal one, on the same side and half the caps further in;
under an up arrow and over a down one, centred on it. Kept MARK_NAME_IN
inside the frame (a down arrow near a corner slides its name along).
```

Above `func _tri_queue(q: Vector2, dir: Vector2i, c: Color, glyph_too: bool, gname: StringName) -> void:`:

```text
The arrow's line (`tri_line`) and the glyph's 2 px cells, outlined 1 px
all round as one shape (its corners too, in one even dark), queued for the
screen to draw over the picture. Inside the hollow arrow the same dark runs
just inside its line and nothing further in: on a sun's glow, the line with
the bright glow on its inner side read as a filled pale arrow, its colour
lost (the Nov 5 sheet), and on the map's dark the ring is the dark it sits on.
```

## Star positions

Above `func star_scr(p: int) -> Vector2:`:

```text
STAR p ON SCREEN (-1 star A, the star; `SystemLayout.STAR_B` star B of two
suns, ruling 20): where its disc is drawn, on the block grid as `origin()`
puts star A. The view says where it draws star B (`SystemView.star_screen`)
once it does; until then it is worked out the same way, where the pair has
it at the view's t.
```

Above `func _ring_c(id: int, c: Vector2) -> Vector2:`:

```text
WHERE A WIDE ORBIT ROUND `id` IS DRAWN ROUND on screen, its centre at plane
point `c`: one sun, the star where it is drawn (`origin()`); a sun of a pair,
that sun's disc on the block grid (`star_scr`), so the ring never wobbles a
pixel against it as the sun creeps (ruling 23); the balance point, on the
same grid. (Told by id: a centre of exactly zero was star A only while star
A held still at the origin.)
```

## Capture insertion

Above `func capture_ins(body: int, rel: Vector2, rv: Vector2) -> Dictionary:`:

```text
THE INSERTION A CAPTURE AT `body` WILL FLY (the ship at `rel` from it,
moving `rv` relative to it): `ShipFlight.insert_plan` as `start_rail` makes
it, cleared against the very star it is onto. Drawn with star A's keep-out
for a twin's star B, bigger by 0.4 to 1.5 px where B's rail is 2 px clear,
the curl drawn was up to 58 px off the one flown, 961 of 1,666 captures at
star B (the seams review, Oct 31).
```

## Settle id

Above `func _settle_c() -> Vector2:`:

```text
THE CENTRE OF THE WIDE STAR ORBIT the ship is settled on (plane), now: star
A at the origin with one sun, or, in a pair, whatever the flight settles
round (the nearer star or both suns' balance point, `_settle_id`) where it is
at the view's t. Worked out from what it circles, never kept as a point: a
pair's suns turn (ruling 23), and a centre kept from the settle was off its
sun within seconds.
```

Above `func _settle_id() -> int:`:

```text
WHAT THE WIDE ORBIT THE SHIP IS SETTLED ON CIRCLES, as a place id: -1 star A
(the one star), `SystemLayout.STAR_B` star B, -9 both suns. The flight says
which (`ShipFlight.f.cen_id`) while it is settled; after it breaks away, what
it last circled (`_star_id`). By id, never by where a centre is: once the
pair turns a centre read off a point drifts off its sun, and a ship round
star B read ORBITING BOTH STARS.
```

Above `func _settle_nm(id: int) -> String:`:

```text
What a wide orbit round `id` (`_settle_id`) circles, named: a star, or BOTH
STARS round the pair (it was BOTH SUNS: "Let's call it Binary instead of two
suns", Nov 1; the panel's AROUND row says the same, `SystemView.host_line`).
One sun: the star.
```

## Flight line

Inside `_draw_paths()`, above `var by_hand: bool = flight.mode == &"free" and t - float(flight.thrust_t) < 1.0`:

```text
FLYING BY HAND (a key held, or let go of a moment ago): only where you are
going is drawn, never a plan replanned from under you (Jon: "why does the
predicted orbit act so weird")
ONLY OUT OF AN ORBIT does a click fly (`ShipFlight.can_fly`), so only then
is its flight drawn: not on the way, not burning onto an orbit, not under
thrust or settling
```

Above `func _draw_line3(pts: PackedVector3Array, lit: PackedByteArray, k: float, us: PackedFloat32Array, u0: float, pl = null) -> void:`:

```text
A LAID-OUT FLIGHT, DOTTED: projected point by point, a smooth curve through
them, a dot every 3 px of it -- in the burn's colour where the engine burns,
ice on the coast; from `u0` of the flight on. `pl`, the plan it is: its ends
drawn at its rings' drawn size (`_drawn_ends`).
HIDDEN BEHIND what stands in front of it, as the ship is: a sun's disc, a
nearer world's. Dotted over everything, a flight's line ran across a sun's
face where it passed behind it -- a quarter of a twin's flights at the
opening zoom, up to 26 px of it, the ship itself hidden on that stretch --
and over nearer worlds (the seen review, Oct 31). Each dot goes by the point
of the flight it is on.
```

Above `func _drawn_ends(pts: PackedVector3Array, us: PackedFloat32Array, pl) -> PackedVector3Array:`:

```text
A SOLVED FLIGHT'S ENDS AT ITS RINGS' DRAWN SIZE: a ring is drawn bigger than
life to read (`_orbit_k`), and the ship on it drawn out with it (`_ok`, on
its spring: easing to life size as it leaves, to the ring's size as it burns
on), while its line was laid at life size. At a twin's worlds round one
star (a ring of 4 to 5 px drawn at about 10) the line began and ended on the
world's face and the ship rode 3.5 to 8.9 px off it at each end (the seen
review, Oct 31). Each point is drawn off its place as the ship will be drawn
there at its moment: the departure's spring from the plan's start, the
arrival's from its burn (`ShipFlight._arrive_t`). The moments and places are
worked out once a plan (`_ends_table`); the sizes, which go with the zoom,
every frame. Today's planner's lines, and a one-sun or giant system's (where
a ring is drawn its own size), are as laid out.
```

## Orbit cap

Above `func _orbit_cap(body: int) -> float:`:

```text
HOW FAR OUT AN ORBIT ROUND `body` MAY BE DRAWN in a pair (ruling 20), px. The
floor above drew a star's close orbit at its disc + 9 px, about 19 px at a
twin's opening zoom, where it rides 12.5 to 13 px out, and that cut into the
disc of the star's own world; and it drew a ship riding a world round a star
at the world's disc + 9 px, where it rides about 5 px out, across its sun's
disc every lap. Measured at fit_zoom over the 470 stars of seed 4242's twins
(TwinSiteTest): 454 close orbits drawn into their world's disc (5 outside
its orbit altogether) and 454 world orbits onto their sun. So in a twin:
  - a star's close orbit stops 2 px short of the disc of each world round
    that star, where the world stands widest from it on screen;
  - an orbit round a world that goes round one star stops 2 px short of that
    star's disc there.
Neither is ever drawn smaller than it is. With the cap, 0 and 0, and the
least room left between a close orbit as drawn and its sun is 1.84 px. One
sun: no cap (INF), since its close orbit (ring - 8, 87 px) and its worlds are
far wider than the floor. (The tilt brings both nearer above and below the
star, where a world passes in front of and behind its sun anyway.)
```

## Ring drawing

Above `func ring_pts(w: Vector2, r: float, body: int, dashed: bool) -> PackedVector2Array:`:

```text
The pixels `_ring` draws (public for TwinSiteTest). Its far half goes behind
the place's disc round w, and behind the place's disc where it is drawn now
(`_place_scr`): a ring round where a world will be when the ship gets there
(`_line`) stands off the world as drawn, at Kepler x 4 by 5 to 9 px round a
sun of a turning pair (ruling 23), and its far half was drawn across the
world's disc while the cut fell on empty space.
```

## Partners

Above `func _draw_partners(_t: float) -> void:`:

```text
THE PARTY ON THE MAP: the small arrow your own ship was before it was your
hull, in the party's colour, with its pilot's name (Oct 22 playtest:
partners were never drawn here). A partner sitting where you are -- two
ships that jumped in together arrive on the same point -- is drawn a ship's
length off, in formation, never on top of you: as far below as your hull
reaches (`ship_r`), and a row more for each partner after.
```

Inside `_draw_partners()`, above `if shown > 0 and _win_in(2.0).has_point(x):`:

```text
The name UNDER the ship, where YOU (over yours) cannot meet it when
the two sit side by side, and at priority 0: placed last, so it gives
way to every word the map already had, and outside YOU's own rule
(priority 1, dropped near your orbit's words), under which every
partner's name went whenever you were in orbit. Not for a ship wholly
behind the star. Nor for one off the picture: its arrow at the edge
carries the name (`_draw_edge_marks`), and this one ran in past the
frame, the name said twice and the second cut (Nov 5)
```

## Click hit test

Above `func _behind_sun(q: Vector2, p: Vector2) -> bool:`:

```text
A BODY AT PLANE POINT q IS HIDDEN AT SCREEN POINT p by a sun in front of it,
whose disc p is on. In a pair a world round one star passes 6 to 8 px from
its sun's middle at the far side of its circle, behind the disc, and its
click circle covered the sun's middle there (the review: on ZETA HOLLOW-4,
seed 4242, 8 of 48 clicks on star B over one turn went to its world). A
click on the sun you see is on the sun: TwinSiteTest puts each star's world
just behind its middle, and on its own turn where it is behind (2 and 3 of 48
on LAMBDA CALLOUS SECUNDUS), and every click is the sun's. One sun's
innermost world never comes that near.
```

## Comet spots

Above `func _draw_spots() -> void:`:

```text
While a comet's reading is open, its three spots are drawn on its path: a ring
in the spot's colour (far ice, near flare, the star red, as the panel's), its
number and name, and IT, the time until the comet gets there. A spot that can
no longer be made is greyed and says TOO LATE. The spot the ship waits at has a
larger ring.
```

Jon, Nov 11: "Can we have the path of the comet and the landing points invisible
unless the comet is clicked?" So the spots, like the path (`RealComet.path_on`),
show only while the comet is selected. Pointing at it does not preview them: he
said clicked. The one exception is the spot the ship is flying to or waiting at,
which stays marked after the comet is deselected, so a ship parked in empty space
still says why it is there. `spots_drawn` counts them for `CometCatchTest`.

## Click again

Above `var preview_to := -9` and `func _click_line`.

Jon's pick F-C (Nov 11): the system map has no FLY HERE button; the second click on
the selected place flies. So the map says so where the click is:

- the flight a second click would fly (the preview) is drawn faint (`PV_REST`) while
  the place is only selected, and lit in the flight's ink (HOT, full strength) while
  the pointer is on the place and a click there would fly (`aimed`);
- the pointer shuts to the game's sight as it does over a button
  (`SystemMapScreen._aim_sight` sets the frame's cursor shape, which `Main` reads),
  and the map's own plane cursor rings in HOT with four ticks (`SectorCursor.sight`);
- the tag's last line is `CLICK AGAIN: FLY`.

This restores the line the Nov 9 stripped-down pass (UI 3) took out. It first carried
the flight's time (`CLICK AGAIN: FLY · N S`, click to arrival on the drawn plan) and,
on a world, two side lines over it ("LIT SIDE · WITH ITS SPIN", "HOLD SHIFT: AGAINST
ITS SPIN") with an arc over the picked half. Jon, Nov 11: "too much text on the box for
a planet... Click again to fly is good, but you can remove the flight time from after
it." The side choice went with it (every flight arrives lit, with the spin:
docs/why/ArriveSide.md#arrive-side), so the tag is the name, the kind, the event line
and the click. Where the click cannot
fly, the same last line says why: UNDOCK FIRST, CANNOT UNDOCK, CLICK AGAIN ONCE IN
ORBIT (a click while the ship spins down onto its ring is kept, so that counts as
flying). A beacon on the selected world says no click line, as its click may open
its page instead (`tap`'s `panel.mode` test).
