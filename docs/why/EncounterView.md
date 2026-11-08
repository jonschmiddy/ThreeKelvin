The reasoning behind `tkg/scripts/ui/EncounterView.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Frame and convoy

Above `enum Subject { AREA, ENEMY }`:

```text
One continuous space. Your ship on the left, whatever you are facing on the
right, a single starfield behind both.

Not two panels. The moment you put a border around each half you get a stat
block facing another stat block; with one field behind them the ship reads as
a thing in a place. This is the frame the sector view and combat share, so the
ship never disappears between them.

THE CONVOY sits to the left of your hull, and only when there is one. Your
partners are drawn from the HALF sheet and you are not, so the party reads at
two to one — 248 against 124 for a heavy — and the ship you fly is the subject
by size as well as by position: centre of frame, facing what you are facing,
and the one you can drop a card on.

Two sizes and no more. Pixel art scales by whole numbers, so the ladder is
1x, half and quarter, and a quarter-size medium is 50x20 — which fails the
test in CONVOY_MAX below, that a hull nobody can identify is not a hull. Half
is a second set of FILES rather than a scale, because nothing below 1x exists
at the renderer. See HullData.sprite_half.
The others are a column beside it, each in a box just tall enough for a hull,
with the name and the two gauges painted over it.

`docs/coop-design.md` §15 calls the party screen the hardest design problem
outside the netcode, and this does not solve it — four hands and four intent
strips still have nowhere to live. What it solves is the half that had to
come first: a partner is drawn from a description of THEIR ship. See
ShipBuild.
```

## Slot modes

Above `var _slots_mode: StringName = &""`:

```text
WHAT THE SLOTS ARE CURRENTLY SHOWING: a fight, or the wrecks it left.

They are rebuilt only when the COUNT changes -- which is right within one
mode, since a fight's dead keep their slots -- and catastrophically wrong
across the two. One wreck in a
system and then one new contact is a count that did not change, so the slot
kept its dead binding: the live ship drew on top of a corpse and could not be
hit, because the thing under the cursor was still a hull with no hp.
```

## Deferred roster

Inside `_ready()`, above `Sig.party_changed.connect(refresh_convoy, CONNECT_DEFERRED)`:

```text
DEFERRED. A roster push lands from the network poll at any point in the
frame -- including while a jump's new screen is being added to the tree,
where add_child() on the column fails ("Parent node is busy setting up
children") and the partner's slot is remembered but never drawn. Found
flying two instances into one system (`-- cojoin`, Oct 22).
```

## Depth order

Inside `_ready()`, above `backdrop = LocalSky.new()`:

```text
Depth order, and the reason it is expressed as child order. NOT
show_behind_parent: this view paints the wash in _draw, and a child behind
the parent is behind THAT — so the gas was being drawn and then covered by
the sky every frame. A Control draws itself first and its children after,
in order, so the two background layers have to be the first two children:
wash, then what is out there, then the gas blowing through it, then the
ship.
```

## Convoy sizing

Above `static func convoy_w() -> int:`:

```text
How wide one partner gets: the biggest canvas any hull draws into, so nothing
is ever cropped nose-first — which reads as a mistake rather than as distance.

ASKED, NOT TYPED, and it used to be typed. 208 was measured against the
procedural drawing and was already stale when the real hulls landed: every
heavy in the party lost about fifteen pixels off each end, and losing them off
the FRONT is the half you notice. A hull sprite is cropped tight to its ship,
so horizontal crop is never empty space.

The HALF set, because that is what a convoy slot draws — 75 to 124 across
rather than 150 to 248. Asking for the full width here would reserve twice the
column the ships need and push your own hull off centre.

Vertical is a different question and stays a constant — see CONVOY_H. A canvas
is taller than its ship by the bob headroom, so trimming rows costs nothing.
```

Above `const CONVOY_H := 118`:

```text
And how tall. Tall enough for the tallest canvas any hull draws into, so no
partner is ever cropped along the hull line — a ship with its keel cut off
reads as a bug, and it is the one crop a viewer cannot explain to themselves
as distance.

Three of these plus the separations is 362 rows against the 378 the arena
leaves under the sector header. That is the whole arithmetic, and it is also
a CEILING rather than a coincidence — see CONVOY_MAX.
```

## Convoy overflow

Above `const CONVOY_MAX := 3`:

```text
How many partners the strip will draw, however many are in the room.

Three, because three is what fits: the arithmetic above is not a description
of the tuned party size, it is the number of 118px rows the arena has room
for. That distinction did not matter while MAX_PLAYERS was four and does the
moment it is not — photographed at seven, the fourth ship was cut in half by
the quiet strip and the last three were not drawn at all. Silently.

So the overflow is SAID rather than dropped. A chip under the column carries
the count and opens the party page, which scrolls and therefore has no
opinion about how many ships there are. The strip keeps the job it is good at
— who is in this room, at a glance, without leaving the sector — and hands
off the one it cannot do.

Not tuned per party size on purpose. A strip that shrinks its rows to fit six
ships is a strip where no ship is legible, and the point of drawing a hull
rather than a name is that you can tell a Dreadnought from a Sloop.
```

Inside `refresh_convoy()`, above `var shown := CONVOY_MAX if here.size() <= CONVOY_MAX else CONVOY_MAX - 1`:

```text
THE COUNTER OCCUPIES A PLACE. The column has room for CONVOY_MAX rows and
not one pixel more — 362 against 378 — so a chip added BESIDE three hulls
pushes the block ten rows over, and because the column is centred it spends
half of that going upward, writing the first partner's name across the name
of the system. Measured, by adding it and looking.

So the strip has three places rather than three ships: when more ships are
here than there are places, the last place holds the count instead of a
hull. Nobody is dropped, the arithmetic above stays true, and the rule is
one sentence.
```

## Convoy membership

Above `func _here() -> Array:`:

```text
Who is actually HERE, in arrival order.

The sector is a place, not a party list. A ship two hundred light years away
is in your convoy and is not in this room, and drawing it beside your hull
says the opposite — during a fight it says it is helping. So the strip is
filtered by position and the STAR CHART is where the whole party lives,
because that is the screen whose subject is where everybody is.

`where_is` returns -1 for somebody who has not reported a position yet, which
is a real answer and correctly matches nothing: a player still on the chassis
select has a galaxy and no place in it.
```

Above `func refresh_convoy() -> void:`:

```text
Who is flying with you, redrawn when that changes.

Rebuilt only when the PARTY changes, not when a ship does. A partner's own
view is wired to `Sig.party_changed` itself and repaints in place, so a new
gun on somebody else's hull costs a repaint rather than a rebuild of the
column it sits in.
```

## Convoy arrivals

Inside `refresh_convoy()`, above `for c in _made_convoy.duplicate():`:

```text
A DIFF, NOT A REBUILD, and that is what makes a departure drawable at all.
Clearing the column and building it again gave every remaining ship a
fresh arrival for somebody else's jump, and gave the ship that left no
frame to leave in — it was simply not in the next list.
```

Inside `refresh_convoy()`, above `var lone := _made_convoy.size() == 1 and _convoy.get_child_count() == 1`:

```text
Staggered, and behind you. Four hulls starting the same approach
on the same frame arrive as one object with four parts; a fraction
of a second apart they read as ships flying in formation. Yours
goes first because it is the one the screen is about.

The stagger applies to the OPENING convoy only. A ship arriving on
its own, into a system you are already sitting in, has nobody to be
staggered against and a delay on it is just latency.
```

Inside `refresh_convoy()`, above `var crowded := not _made_convoy.is_empty()`:

```text
Visible while any SHIP is in the column, including one on its way out.
`them.is_empty()` would take the last partner off screen on the frame they
pressed JUMP, which is the one frame the effect exists to fill.

Counted off the slots rather than off the children, because the overflow
chip is a child too and a column holding nothing but a chip is a column
that should not be on screen.
YOUR HULL COMES DOWN TO 1x WHILE ANYBODY IS FLYING WITH YOU.

2x is right for the game one person is looking at: the sector is where a
run is mostly spent and the ship should carry it. It is wrong the moment
the convoy column appears, because then the left of the screen has to hold
your hull AND up to three partners, and a hull at 2x takes the room the
column needs.

Hung off the same fact the column's own visibility is — one test, so the
two cannot disagree about whether there is a party — and re-applied here
rather than set once, because somebody joining or leaving mid-run is
exactly the case a value set at build time would miss.
```

## Own ship size

Inside `refresh_convoy()`, above `_ship.use_half(false)`:

```text
YOUR ship stays on the full sheet. Your partners are on the half one, so
the party reads at two to one and the ship you fly is plainly the subject.

This is the one place the old code could not go. Everything used to be the
same size in a party — your hull dropped from 2x to 1x to make room and
landed on the convoy's own scale — so the class note above had to say the
foreground came from position alone, because there was no other size to
give it. There is now: 248 against 124 for a heavy, and both fit, because
the column costs 124 and a gap rather than 248 and a gap.

A one-line flip if it reads wrong. `use_half(crowded)` puts everybody back
on the same footing.
```

## Place setup

Above `func set_place(n: MapGen.MapNode) -> void:`:

```text
Where you are, told once. Sky and wash both, and both for every sector —
fighting or not.

show_area() is not enough to carry this and never was: it runs only when the
sector is quiet, so arriving straight into a fight left the wash on its
default tint and would now leave the sky on the last system's. What is out
there does not care whether something is shooting at you.
```

## Wreck slots

Above `func show_wrecks(wrecks: Array, on_open: Callable) -> void:`:

```text
What is left of the ship that died here, if anything is.

REUSES `EnemySlot` WHOLE, which is the point: it already knows how to draw a
dead hull -- dimmed, named, "WRECKED" where the health was -- and it already
answers a click when dead. Building a second thing that draws a wreck would
have been a second thing to keep looking like the first.

The state it is handed is fabricated: the fight is over and `Combat` is gone,
so this is a template out of the node and a hull of zero. Nothing downstream
asks it anything a dead ship cannot answer.
Every hull that died here, each a door to its own container.

`on_open` is called with the jetsam that hull is, so the screen does not have
to work out which wreck was clicked from a position on screen -- the slot
already knows, because it was built from one.
```

## Aiming

Above `const AIM_NONE := -2`:

```text
Combat: the right side is everything shooting at you. Slots are rebuilt only
when the count changes, which is when a fight opens.
WHAT IS UNDER THIS GLOBAL POINT: an enemy index, -1 for your own hull, or
AIM_NONE for nothing.

BY RECTANGLE, NOT BY INPUT PICKING, and that is deliberate. The party column
sits over the arena and carries `MOUSE_FILTER_IGNORE` precisely so a card can
be dropped THROUGH it -- a tuning that exists for Godot's drop propagation and
does not survive leaving it. Testing the slots' own rectangles reproduces the
rule on purpose rather than inheriting it: the column is not a target, and the
arena behind it is.
```

## Slot arrivals

Inside `show_enemies()`, above `_layout_pack()`:

```text
A NEW SLOT IS AN ARRIVAL: a fight opening. Flown in
AFTER the bind, because the bind sizes the slot to its ship and the
entrance flies to that resting place. The dead keep their slots, so a
kill does not change the count and the survivors are never re-flown.
Placed BEFORE they fly, so each flies to its own place; the ships already
here ease to theirs (`_layout_pack` moves a placed slot, never jumps it).
```

## Wreck handoff

Above `const WRECK_EXITS := {&"A": &"fade", &"B": &"drift", &"C": &"recede"}`:

```text
THE WRECKS GO BEFORE THE FIGHT COMES, never on one frame. A fight opening
where hulls already lie swapped in a fight screen built without them, so
every wreck was gone on the frame it opened. The wreck slots LOCAL drew are
handed across instead (`hand_wrecks` on the screen going, `wrecks_out` on the
one coming: `Router.start_combat`), held where they stood on screen by a
top-level holder the row's layout never sees, and played out by
`WRECK_EXIT`; the contacts are held until they have gone (`leaving`), the
same handoff the place's picture makes.
  A  fade:   where they lie, in the time the place's picture takes
  B  drift:  carried off the view's right edge, easing in, fading at the end
  C  recede: into the distance -- smaller and darker toward the sky, then gone
`wreckexit=A|B|C` on a harness's command line picks one for a film.
```

## Place fade

Above `func _area_fade_out() -> void:`:

```text
THE PLACE GOES BY FADING when a fight takes its half of the row: it was
gone on the frame the fight opened. The row's own place picture has to leave
the row at once (the enemies take its share of it), so a copy of it fades out
where it stood: the share of the row right of your ship, worked out the way
the row lays it out (`_pack_room`) and anchored, so it is right on the first
frame and follows the view as the hand comes up.
```

## Pack layout

Above `static var pack_layout: StringName = &"B"`:

```text
The ships already in the row slide to the places a newcomer's arrival gave
them, measured after the row has been laid out again.
NOTHING IN A PACK SITS ON ANYTHING ELSE (Jon, Oct 13: three ships "don't fit
on screen"; then, of the overlapped row: no ship, wreck, name, hull bar,
chips or intent may overlap another, or yours).

Every slot is placed by hand, as a unit -- its ship and its whole readout --
and no two units share a pixel. The room they have is the band of the row
from just past YOUR ship (its hull and its plate) to the view's edge; a pack
is centred on the enemy half while it fits there and slides toward you only
as far as it must. Your ship never moves.

THREE OR MORE AT HALF (Jon: "when there are 3+ enemy ships on the screen can
we render them at 1X? Kinda like how we do for multiplayer"). With three or
more blocks in the pack, wrecks counted, every ship is drawn from its HALF
sheet, the way the convoy draws hulls (`ShipView.use_half`): a second file,
nearest 2:1, never a resample (`EnemyArt.draw_scale`). One or two stay at full
size. The step happens at once, at the start of the move that makes room.

THE FORMATION (Jon picked B): one rank for one or two ships, at full size;
with three or more, ranks: the first two in front, the rest behind and above,
every block the same gap from its neighbours (`_pack_ranks`), each ship with
its readout under it. More ranks, or more to a rank, when there are more
ships -- never smaller ships.

`pack_layout` C (a column, each readout beside its ship) is kept to compare
against, and for the test; B is the game's.
```

Above `func _pack_area() -> Rect2:`:

```text
The room a pack has, in `_slots`' own coordinates, AS THE SCENE STANDS AT
REST, whatever scale it is drawn at this frame.

The cutaway and the zoom ladder scale and move `_row` (the scene: your ship,
the wrecks) round a point. This was measured on the screen, so a layout asked
for while the cutaway had the scene at 2x -- a part moved or a wreck emptied
in there, each of which refreshes LOCAL -- planned the wrecks into the room
the zoomed picture left them: half size, stacked in a column just past your
hull's middle. Shut, the scene went back to 1x and they stayed where that
plan put them, across your bow with their names on your hull (Jon, Oct 17:
"destroyed ships going on top of you when you edit your ship after a
fight"). Measured in the row's own frame, and against the row's size at rest
(this view's, less the bleed under it: a refresh in the cutaway can stretch
the zoomed row), the plan is the same zoomed or not. `-- sheet=WreckSiteTest`
goes round every door.
```

## World clearance

Above `func _body_rest() -> Vector3:`:

```text
THE WORLD YOU ORBIT, as LOCAL draws it at rest: its disc's middle and radius
in `_slots`' own frame (x, y, r), or r 0 where there is none.

From the sky's plan of it (`LocalSky.near_plan`), not from its picture: the
plan is there the moment the sky is set up, headless too, and is where the
picture stands at rest -- the sky's 960x540 frame is the screen's, the view
at rest is the row's frame (`_pack_area`), and the cutaway's or the ladder's
zoom moves neither.
```

Above `const BODY_GAP := 8.0`:

```text
WRECKS OFF THE WORLD YOU ORBIT (Jon's rule: fit means nothing overlaps). A
wreck's name and tag across the world's lit face cannot be read, and a hulk
laid over a planet is a picture of neither. The plan that fits the room is
kept if no wreck's block (its picture and its words, `EnemySlot.block`)
comes within BODY_GAP of the world's disc; else the pack is planned again in
the room left beside the world -- just over it, above it, before it, after
it, below it, or at last the whole width over it, your ship's side too --
and the one at the larger size nearest where the pack would have stood wins.
With no such room (a big world and a big pile), the art may cross the world
but the words never do: the same rooms are tried again for the words alone
(`EnemySlot.words`). Only if even that fails does the plan stand as it was.
```

## Pack formation

Above `const PACK_GAP_MIN := 12.0`:

```text
B, THE FORMATION, EVENLY SPACED (Jon: "this is great, but we need more space
and they can be evenly spaced around each other"). One gap, `g`, between
every pair of neighbouring blocks -- across a rank and between ranks alike --
measured between what is drawn (`EnemySlot.block`: the ship's ink and its
readout), as wide as the free band allows up to PACK_GAP_MAX and never under
PACK_GAP_MIN. One or two ships stand in one rank (two ranks of one if a rank
of two will not fit); three or more stand two in front and the rest behind
and above, a rank one short of the rank in front sitting over its gaps (three
make an even triangle), any other rank centred on the one in front. The block
is centred on the enemy half while it fits there, and in the band's height.
```

Inside `_pack_ranks()`, above `if fits and _slots_mode != &"wrecks" and ranks.size() == 2 \`:

```text
THE TRIANGLE, ITS SHIELDS' ROOM KEPT. Stacked whole, the ranks of a
pack of three mostly no longer fit the band with every ship's shield
room; the ship behind is set into the shoulders of the two in front
instead, its plate between their words, every part of each ship's
room (`EnemySlot.rooms`) the gap between ranks from the other's
(Jon: "you can decrease the vertical space height between the top and
bottom ships to make room for the text"). Always, so the gap between
ranks is measured one way in every triangle.
```

Above `const SHOULDER_DX := 40`:

```text
THE RANK BEHIND, SET INTO THE SHOULDERS OF THE RANK IN FRONT. The front
rank stands on one baseline at the gap `g0` across (or wider, if it must,
up to what the band allows); each ship behind sits over its gap, nudged at
most SHOULDER_DX across so its gaps to the two either side of it come out
equal, and as low as its room (`EnemySlot.rooms`: words, shield oval, plate)
stays the gap between ranks from theirs -- that gap as wide as the band
allows up to the gap across, never under PACK_GAP_MIN. The ship behind
stays behind: its oval above theirs. Empty if no such formation fits.
```

## Wreck spacing

Inside `_pack_ranks()`, above `var g := PACK_GAP_WRECKS if _slots_mode == &"wrecks" else PACK_GAP_MAX`:

```text
LOCAL's wrecks share the view with the system's own subject, which
keeps clear of them (`LocalSubject.fit`): a wreck pile spaces evenly
at the least gap, leaving it room (at 24 px between blocks the fuel
cache's pieces had nowhere left beside three wrecks; subjecttest)
```

## Hit number room

Above `const POP_ROOM := HitText.GAP + 2.0 * HitText.LINE + HitText.CAP + 1.0 + HitText.RISE + 2.0`:

```text
ROOM FOR THE NUMBERS (Jon, Oct 13, "C": a landing's numbers stack above
the ship's words). A fight's ships, centred in the band, sit lower where
the band allows, so the stack over the top rank -- three lines, risen --
stays under the HUD rather than go on the hull. `top` is where the blocks'
top would be centred; `h` their height. LOCAL's wrecks take no hits.
```

## Hull anchor

Above `func self_anchor() -> Vector2:`:

```text
Where YOUR hull is, in this view's own coordinates.

The mirror of `enemy_anchor`, and it exists for the same reason: anything that
wants to sit under the ship has to ask where the ship IS. Deriving it from
`ShipSlot.HULL_BIAS` and a guess at how wide the slot is gets it wrong the
moment the row gains or loses a child -- which it does, because the enemy
slots live in the same row.
```

## Sky bleed

Above `var _bleed: float = 0.0`:

```text
HOW FAR THE SKY CARRIES ON PAST THIS VIEW.

The arena stops where the drawer band starts, and for as long as the drawer
was always up that was invisible. It is not invisible during an arrival: the
drawer is parked below the floor, and the bottom of the screen was a flat
dark strip with the starfield ending at a hard horizontal seam.

So the SKY bleeds past this control and the CONTENTS do not. `_row` -- the
ship, the convoy, the place, the enemies -- is untouched, which is the whole
point: growing the view instead would drop the hull half the band's height
and then lift it again when the drawer arrived.

The drawer draws over it, and always could: `UITheme.PANEL_A` is 0.88 and its
own comment calls it "the panel-over-sky alpha". There has simply never been
any sky under it before.
```

Above `func set_bleed(px: float) -> void:`:

```text
THE VIEW GROWS AND ITS CONTENTS DO NOT, which is the only order that works.

Extending the backdrop alone does nothing: this control sets
`clip_contents` in `_ready` -- the fly-in starts the hull hundreds of pixels
off its left edge and something has to stop that drawing over the rail -- so
a child reaching past the bottom is cut off at exactly the seam being fixed.

So the CLIP has to move, which means the view itself has to be taller. `_row`
is then held up by the same amount, because it carries the ship, the convoy,
the place and the enemies, and every one of them is centred in its height.
```

Above `func reapply_bleed() -> void:`:

```text
The row put back on the band as it stands now. A camera move keeps the row's
offsets from the moment it began and puts them back when it lands
(`SectorScreen.ladder_cam_end`), and `set_bleed` does not repeat a value it
already holds, so a band that changed under the move left the row reaching
down behind it: your ship half the band's height low and its plate hidden
under the hand (Jon, Oct 22, the Custodian fight: "Glitch on boss fight?").
```

## Place pictures

Above `class AreaView extends Control:`:

```text
The place, drawn. Every node type has a picture before any real art exists,
and a cleared node visibly differs from one you have not touched.

Lit the same way as everything else in the game: from the top of the frame,
cold, with warmth only where something emits it. `_body` is ART_CONTRACT's
two-plane rule — bright top face, bright lip, wall falling into shadow — and
it replaces the flat `_plate` these were built from. A station drawn as three
filled rectangles is three filled rectangles; the same station drawn as three
LIT rectangles is a place with a near side and a far side.
```

## Place art switch

Inside `_draw()`, above `const SHOW_PLACES := true`:

```text
The sector pictures are OFF while their real art is drawn.

Everything below this line still works and is still correct; it is
placeholder art, and placeholder art that is good enough to read is
exactly the kind that quietly becomes the shipped answer. Empty space
says "not drawn yet" in a way a passable procedural station does not.

One switch rather than a deletion: the kit underneath -- the two-plane
bodies, the six-stop ramps, the dither -- is the vocabulary the real
sprites will be checked against, and START already proves the screen
reads fine with nothing in it.

ON, 2026-09-12, by Jon, asked directly and answered "turn it on now,
commission art later". THE WORRY ABOVE STILL STANDS and is the reason this
note has a date on it: the way this ends badly is not that it looks wrong,
it is that it looks fine for a year. Art for these five is commissioned
work, gated on a brief, and until that lands the sector is showing a
sketch of the place rather than the place.

What changed since the switch went in is the argument, not the art. The
sector was empty sky beside your ship, and a system you fly to and find
nothing in reads as a screen that has not finished loading rather than as
a place with nothing in it. EnemyArt is the precedent in the other
direction: it draws every enemy in the game procedurally and nobody has
ever called it a placeholder.
```

## Place picture choice

Inside `_draw()`, above `func _place_name() -> StringName:`:

```text
WHICH PICTURE THIS SECTOR IS, as a name.

Named rather than typed, because the picture does not follow `NodeType`: a
SYSTEM is a battlefield, a derelict or a beacon depending on its option
tags, and a battlefield is two pictures depending on whether it is cleared.
Splitting this out means the sprite and the drawing are chosen by the same
line, so they can never disagree about what this sector is. Empty means
nothing is drawn here at all.
```

Inside `_draw()`, above `MapGen.NodeType.SYSTEM:`:

```text
READ WHAT IS HERE. The three types this replaced each had their own
picture, and the picture is still worth having -- it just comes off
the options now instead of a label chosen before anything rolled.

NONE OF THEM ON LOCAL (Jon, Oct 21: "I don't want the beacon to show up
at all. I want to see the actual event of that planet/POI"). The
beacon, the derelict and the battlefield were pictures picked from the
options' tags, standing in for events that LOCAL now shows as
themselves: the event at the place the ship is, opened as GO opens it,
its own subject drawn (`LocalEventDrawer.auto_open`, `LocalSubject`),
and the hulls of the fights fought there (`show_wrecks`). On LOCAL
(`site` set) a system draws no place picture; the sheets (`ANY`) still
draw every one of them.
```

Inside `_draw()`, above `MapGen.NodeType.CORE, MapGen.NodeType.PULSAR:`:

```text
THE CORE AND A PULSAR ARE THE SYSTEM'S OWN STAR, and LOCAL's sky
already draws that star (`LocalSky`: the core's hole is the black
hole every style shares, `CoreLegacy`; the pulsar and its beams).
A place picture here drew it a second time, beside your ship --
Jon, Oct 13, at the core: "why are there two black holes lololool".
`_core` and `_pulsar` stay, for `-- sheet=PlaceSheet`.
```

Inside `_draw()`, above `var tex: Texture2D = DB.place_sprite(what)`:

```text
ONE DOOR, and the moving parts stay on this side of it. The two places
that animate do so as OVERLAYS -- the station's two navigation strobes
and the beacon's five walking rings -- so they are drawn after the
picture whether the picture was generated or drawn. That keeps the
asset set at one still frame per place: a sprite inherits the motion,
and nothing has to be authored at the 12 Hz this repaints at.
```

## Station and beacon

Inside `_draw()`, above `func _station_lights(c: Vector2) -> void:`:

```text
Navigation strobes: the one cold light on it, so it does not read as a
furnace.

THEY STROBE, and out of phase with each other. A navigation light is the
one thing on a station that genuinely blinks, so it is the one thing here
that earns an animation -- the windows stay lit, because a window going
dark is somebody walking about and this game has no people in it you can
see. Long dark, short bright, two different periods: in step they would be
a heartbeat, and a heartbeat is a rhythm the sector does not have.

SEPARATE SO A SPRITE CAN KEEP IT. This is the only moving part of the
station, and it is two three-pixel squares -- so the generated plate is a
still station with its lights off, and these go on top of it exactly as
they go on top of the drawing. Baking them into the art would cost a frame
set for six pixels.
```

Inside `_draw()`, above `func _strobe(period: float, offset: float) -> float:`:

```text
One strobe: dark most of the period, then a short bright flash.

Deliberately not a sine. A sine spends half its time near full and reads
as a pulsing glow; a light that is off and then briefly on reads as a
machine signalling, which is what this is.
```

Inside `_draw()`, above `func _beacon_rings(c: Vector2, tint: Color) -> void:`:

```text
The rings, which are the thing the beacon is DOING.

SPLIT FROM THE LAMP BECAUSE THE BUOY SITS BETWEEN THEM. Rings go down
first and the lamp goes on top, so a generated buoy has to land in the
middle of the sandwich -- an overlay drawn wholly after the sprite would
paint the transmission over the transmitter.
```

Inside `_draw()`, above `for i in 5:`:

```text
THE RINGS GO OUTWARD, because the rings are the thing it is doing. A
beacon drawn as five fixed circles is a diagram of a transmission; the
same five walking outward and dissolving is a transmission. It costs
one modulo and it is the difference between a picture of a place and a
place -- and this setting's cheapest horror, per lore.md, is a system
that is empty and still talking.

Five rings on one cycle, so a ring leaves the buoy exactly as the
outermost reaches the edge and fades into the void. Nothing appears or
vanishes; the colour ramp was already taking them to the background
colour at the far end, so the loop hides itself.
```

## Own ship slot

Inside `_draw()`, above `const HULL_BIAS := 0.68`:

```text
How much of the slot the hull is centred in. The rest is empty space on
its right.

The frame is "your ship left, what you face right", and a Control that
fills its half and centres its texture puts the ship in the middle of the
screen — which reads as neither. Centring it in the left two thirds of the
same box moves it back onto the left without changing the layout, and it
leaves the ship pointing INTO the space the subject occupies rather than
across it.

Done with an anchor and not with `position`, because `ShipView.arrive()`
animates position and puts it back to zero when the ship parks.
```

Inside `_draw()`, above `art.zoom(1)`:

```text
2x, matching the refit screen and the chassis select. The hulls are
authored small enough that 1x here left the ship a detail in the
middle of its own encounter — and this is the screen the game is
mostly played on, so it is the one that should agree with the others.

1x, solo or crowded. The hulls are authored at 2x their box, so this
is the full-size ship and there is no step below it.

zoom(), not magnify(): the slot's width is anchored to a fraction of
the encounter and a minimum size would fight that.
```

Inside `_draw()`, above `art.bob(2)`:

```text
THE IDLE DRIFT, which this slot never had. The convoy slots below ask
for `bob(1, 0.19)` and call it "slower and shallower than your own
ship's" -- a comparison to a bob that was not there. The ship screen
and the chassis select both use 2, so that is what your own ship's is.

It moves inside the canvas rather than moving the Control: see
`ShipView`'s note, which is why anything riding the hull has to take
the offset out again. `_place_self_plate` does.
```

## Jump flare

Inside `_draw()`, above `_flare_box = Control.new()`:

```text
THE COLUMN YOU LEAVE ON. The convoy slots have had one of these since
they were written; your own ship never did, because your own ship
never left while you were watching.

IN A BOX THE SIZE OF THE HULL, not of the slot. JumpFlare.MAX_W is 20
and its own comment reasons that against a 208px slot holding a 124px
hull: a beam that wide is "plainly a thing the ship came out of".
Across this slot — most of half the arena — twenty pixels is a rule
somebody drew, not a column. So the box is sized to the art, and added
last so the flash is in front of the hull rather than behind it.
```

Inside `_draw()`, above `func _process(_d: float) -> void:`:

```text
Fire the column over the hull, wherever the hull has got to. Returns it so
the caller can hang off `peaked` — the frame the ship changes hands, which
is what that signal was built for.

Re-measured at play time rather than at build time, because the departure
leans the hull twenty pixels right before this fires and a beam that
arrives where the ship was is a beam that missed.
THE COLUMN TRAVELS WITH THE SHIP. Placed once at play time it stayed where
the hull had been while the hull kept accelerating out of it -- by the peak
the ship had outrun its own flare by most of a hull length. Two lines a
frame, and only while the thing is on screen.
```

Inside `_draw()`, above `var flare := 0.0`:

```text
Width: two segments, meeting at PEAK. Not one sine across the whole
life — that put the widest frame at 0.62 while the hull swapped at
0.42, and the swap was visible next to the flash instead of inside it.
```

## Drag preview

Inside `_draw()`, above `if _drag_text != "":`:

```text
What this card would give you, over your own hull. Same idea as the
enemy's number and the opposite colour: one is what you take off them,
the other is what you put on yourself.
On the hull too, for the same reason the brackets are, in the same
letters a landing pops (`HitText`): centred on the hull's INK, not
the bracket box (clipped to the view) nor the canvas (which carries
the exhaust's clearance on one side).
```

## Partner slot

Above `class JumpFlare extends Control:`:

```text
One ship flying with you: their hull, their name, and how they are doing.

The readouts are PAINTED OVER the ship rather than stacked under it, which is
the same choice `ShipSlot` makes below and for the same reason — a column of
four ships each with a label and two bars under it is sixteen rows of chrome
in an arena that has none to spare, and a name written across a hull is
plainly that hull's name.

It is not a drop target and it never will be. Cards are played from your deck
onto your ship and onto what is shooting at you; a partner is a thing you can
see, not a thing you can aim at. See `docs/coop-design.md` §5.
The light a ship arrives and leaves in.

ONE ANIMATION FOR BOTH DIRECTIONS, and that is not a shortcut. A jump is a
column of light with a hull either side of it: what differs between arriving
and leaving is only whether the ship is there before the flash or after it.
Two separate effects would be two things to keep in step and would read as
two different events, which they are not.

Cold, not ember. Every other light in this game is heat — weapons, the hull
shader, the overheat warning — so a jump has to be the one thing on screen
that is bright and not warm, or it reads as another gun going off.

Drawn rather than animated. Everything here is on the pixel grid at integer
widths and the brightness is stepped, for the reason CombatFx records: a
pixel is lit or it is not, and fading one through alpha is how pixel art
starts looking like a screensaver.
```

Inside `_draw()`, above `var _engaged: bool = false`:

```text
In the same fight as you, right now.

Worth its own mark because the column shows the whole party and a fight
involves some of it. Three ships in the sector and two in the fight is the
normal case, not the exception — people arrive at different times — so
"who is shooting at the thing shooting at me" cannot be read off presence.
```

## Partner label redraw

Inside `_draw()`, above `art.visibility_changed.connect(queue_redraw)`:

```text
THE NAME AND GAUGES COME BACK WITH THE HULL. `_draw` paints nothing
while the hull is hidden, and `ShipView.arrive` hides it for its first
tick after the flare has already asked for a redraw -- so the slot
drew once, empty, and nothing asked again: the partner flew in with no
name over it (seen in the Oct 22 stills, LOCAL and the fight alike).
```

Inside `_draw()`, above `queue_redraw()`:

```text
And ask for the name and the gauges back. They are painted by this
slot rather than by the hull, and _draw() bailed out while there
was no hull under them — without this the ship returns and its
label does not, because nothing else redraws a settled convoy.
```

## Gauge placement

Inside `_draw()`, above `_gauge(float(fs) + 3.0, _hull_at, UITheme.HULL_GREEN)`:

```text
Directly under the name rather than at the floor of the slot. The ship
is centred in the box and the box is taller than the ship, so bars on
the floor float in space below it and read as belonging to whoever is
next in the column.

Hull above heat, which is the order they are stacked on the HUD and
under every enemy.
```
