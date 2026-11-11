The reasoning behind `tkg/scripts/ui/ZoomLadder.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Four distances

Above `enum { CHART = 0, MAP = 1, LOCAL = 2, STATION = 3 }`:

```text
ONE PICTURE, FOUR DISTANCES (Jon picked C on "Where LOCAL fits", Oct 8: "Let's
go with that, but the transitions need to be MUCH better than a simple
fade"). The star chart, the sector map, LOCAL and the station are one camera
at four distances, and moving between them is a camera move centred on your
ship (or your star), never a cut.

THE SCREENS STAY FOUR SCREENS. Each is drawn by its own renderer with its own
palette and tone, and they are coordinated rather than merged: a move is
  1. PRE-ROLL: the screen being left moves its own camera, live, toward the
     next distance (the map zooms onto your ship, the chart onto your star,
     LOCAL pulls back, or pushes in on the station's ring);
  2. THE HANDOFF: its last frame is held (the Router frees it as it always
     did), and the screen arriving is built underneath, its own camera placed
     at the matching distance;
  3. THE MOVE: the arriving screen's camera eases to rest, live, while the
     held picture is carried with it -- scaled by exactly the arriving camera's
     own change of scale, its anchor riding the arriving anchor -- and taken
     away in the dither of the design picked for that seam (`zoom_ladder`).
So the two renderers never have to agree on a pixel: the held picture moves
the way the live one does, and the handoff is a dither, not an alpha.

THE SEAMS AND THEIR DESIGNS, the first of each the default:
  1 chart <-> map:    A the system opens out of your star (an iris);
                      B the chart's stars stream past, dark first;
                      C mosaic blocks.
  2 map <-> LOCAL:    A dive past your ship; B the map lies down into LOCAL's
                      plane; C the world you orbit carried into LOCAL's.
  3 LOCAL <-> station: A through the ring; B your hull carried to its berth;
                      C mosaic blocks.
Two distances apart (LOCAL <-> chart, map <-> station) is one dive.

THE SWITCHES. `-- flow=legacy` is today's flow (the alpha's fallback);
`-- flow1=B` (flow2, flow3) picks a design, for a harness or a film. They
were Settings > MOTION rows in dev mode, kept in `[flow]` of settings.cfg,
until Jon said remove them, even in dev mode (Oct 19): what he had picked
ships, and a `[flow]` left in a settings file is not read. Off under
reduced motion and wherever `Router.animating()` is false, so every harness
and the sim take the plain swap they always took. Any key or click during a
move finishes it at once, and is not eaten.
```

## Move timings

Above `const UI_OUT_S := 0.22`:

```text
THE TIMINGS, ONE DIAL EACH (Jon, Oct 10: the moves "feel really fast and
rushed and chaotic"). They were dials in Settings > MOTION in dev mode, set by
feel; these are what Jon had them at when the dials went (Oct 19), baked.
A move is three beats that never overlap: THE UI LEAVES (`UI_OUT_S`, the
camera still), ONE CAMERA MOVE (the seam's own length, eased in and out),
THE UI ARRIVES (`UI_IN_S`, the camera at rest).
```

## Dock in five steps

Above `const DOCK_BEAT_S := 0.3`:

```text
3B AT A STATION: THE DOCK IN FIVE STEPS, in seconds (Jon, Oct 20: "Why
doesn't the ship enter like the first local?" -- so it does, exactly; before
that, "...the station turns on, then the ship flies in", and "Let's have the
station turn on BEFORE the ship moves in"). In order, never two at once
(`SectorScreen.ladder_cam`):
  1. CUT: LOCAL down to black (`FADE_OUT_S`, the game's fade), your ship
     taken off its mooring in the black;
  2. ARRIVE: up from black (`FADE_IN_S`) on the dark station with your ship
     off screen, and in it comes -- A NEW SYSTEM'S ARRIVAL, the very call
     (`SectorScreen._ship_arrives`): its drive heard `ShipView.ARRIVE_LEAD_S`
     first, the approach from off the left edge over `ShipView.ARRIVE_MS`,
     the flameout sputtering down to the idle and the drift to its mooring,
     its clip under it, its bob;
  3. BEAT: it idles at its mooring by the dark station;
  4. POWER: the station's lights come on (`StationFace.power`), the warning
     lights at the mouth flashing and then green;
  5. ENTER: its engines lit, your ship from its mooring on into the hull in
     one move along the approved dock's path and its shrink with depth (so
     the mouth fits every hull) -- the dock approved at this length.
THE CAMERA DOES NOT MOVE in any of the five (Jon, Oct 20: "Why is there so
much parallax? ... The station is stationary."): only your ship does. The
map's DOCK comes to LOCAL through black (`preroll`'s `dock_fade`), your ship
kept off it, so the arrival is the first of it seen there.
LOCAL's whole pre-roll is the five (`dock_approach_s`); the yard after it is
its own (`YARD_FADE_S`, `YARD_BEAT_S`, `DOCK_YARD_S`). Reduced motion never
animates a dock (`Router.animating`), and a press mid-dock ends it at once.
UNDOCKING HOLDS THE BACKGROUND AS DOCKING DOES (Jon, Oct 21: "the background
stays put as your ship flies out, matching docking"): the yard as it was --
the elevator out, your ship off its stands and away, the empty yard down to
black -- then LOCAL up from the black over the dock's dip backwards with
your ship still in the hull, then over `DOCK_ENTER_S` out of the mouth from
rest at the idle, growing back to its size down the ENTER's path, slowing to
rest at its mooring as its engines cough. The camera does not move on LOCAL
and the station stays lit (`SectorScreen.ladder_cam`). A press mid-undock
parks your ship at its mooring at once, its sounds hushed.
```

## Station lights

Above `const LIGHT_OFF := 0.22`:

```text
THE STATION'S LIGHTS (Jon: "i think the lighting can be MUCH more dramatic
between turned off and turned on"): OFF, how much of the bay's own dark
picture shows while the station sleeps (and the hull's plating in starlight
only); ON, how bright the bay and every lamp are once it wakes (over 1 is
brighter than painted); GLOW, how strongly each lamp's light spills onto the
plating round it (`StationFace`)
```

## Chart to LOCAL

Above `const FADE_OUT_S := 0.3`:

```text
THE CHART TO LOCAL OR THE BERTH, AND BACK (Jon, Oct 10: "Chart straight to
local is ehhhh kinda hard to do... just do a fade. No transition"): down to
black, the new screen built in the black, and up from it. No camera.
```

## Handoff disc

Above `const DISC_PX := 0.0`:

```text
THE HANDOFF DISC (1A, 2C, GO): the radius, screen px at the swap, of the soft
disc round the focus -- your star, the world you orbit -- that carries the
screen being left into the one arriving. Jon: "the circle is better.... but
it's still WAYYY too big". 0 is the focus object and a thin halo round it,
which is Jon's pick of three sizes filmed (Oct 11, "Circle: C").
```

## Calm move

Above `const CALM_OUT_S := 0.2`:

```text
THE CALM MOVE (Jon's pick A, Oct 17, after "the movement between local >
sector > starchart ... EXTREMELY disorienting"): every hop between LOCAL, the
map and the chart, both ways and by every route, is one motion of the same
length -- THE UI LEAVES (`CALM_OUT_S`, the camera still); out of LOCAL, the
side column and band slide on (`CALM_SLIDE_S`, the camera still); ONE CAMERA
MOVE (`CALM_CAM_S`) scaled about your ship, your ship on one straight line
from where it rests to where it rests on the next view; then, the camera
landed, into LOCAL the column and band slide off (`CALM_SLIDE_S`), and the
arriving screen's UI comes (`CALM_IN_S`) while its side bar and toolbar
decode (`CALM_DECODE_S`). Never two of these at once with the camera.
```

Above `const CALM_DECODE_S := 0.7`:

```text
(Jon asked for E's decode "slowly" on Oct 13, 1.1 s, when it ran under the
camera; after the landing that second is all added to the hop. Of 0.4, 0.7
and 1.1 s filmed he picked 0.7, Oct 17: "decode:B")
```

## Yard handoff

Above `const FADES := ["F", "P"]`:

```text
THE HAND-OFF INTO THE YARD (3B). "F", Jon's pick and the default: a dip to
black once your ship is out of sight in the hull; the EMPTY yard comes up
from black slowly (Jon: "let's have the yard show up without our ship
first" -- "and the black should slowly fade out"), holds a beat, and your
ship -- travelling all along, off the picture -- comes in from the left and
lands; then the elevator. Undocking: the elevator out, your ship off its
stands and away to the left, a beat of the empty yard, the yard slowly down
to black, and up on LOCAL, the camera still, with your ship coming out of the
hull the way the dock took it in. "P", kept as the alternative: the pan
through the hull, a harness's `seam3_fade=P`.
```

## Side bar look

Above `const SIDE_LOOK := "E"`:

```text
Jon picked E (Oct 13), "and let's have the sector and starchart buttons at
the top also decode during the transition" -- the chart's toolbar (LAYER,
its pips, CORE, the view toggles) and the map's (DANGER), not the HUD's tabs
("I meant these buttons, not the top left buttons"): `ladder_bar`.
```

## Chrome slide

Above `var band: SideBand = null`:

```text
BETWEEN LOCAL AND A SCREEN WITH CHROME -- the map's and the chart's band
along the top and side bar down the right; LOCAL has neither -- THE CHROME
MOVES (Jon picked the band easing, then: "the tooltip bar moves up and the
side bar slides to the right as the local image expands. the opposite
happens when you move from local to sector or local to starchart"). Out of
LOCAL the band slides down and the side bar's column in from the right,
empty, as LOCAL's camera leaves, landing as the screens change hands (or in
a dive's dip to black), and their contents decode in after; into LOCAL the
chrome being left slides off, up and right, as LOCAL's camera lands. LOCAL
is drawn whole beneath and uncovered, never scaled (`ChromeSlide`).
the band of this move, if any (out of LOCAL: it opens as the camera leaves)
```

THE BOTTOM BANDS (Jon, Nov 11: "I want the star chart to have the same bottom
tray as the system. I also want them to slide in and out like the other panels
during the transitions"). The map's and the chart's KEY band and LOCAL's strip
are each screen's `ladder_foot`, and on the calm move they never fade
(`calm_moving`). Between LOCAL and the map or the chart they are a `PanelSlide`
of kind foot, down off the screen on the panels' curve and timing: the leaving
screen's off before the camera moves, the arriving one's on after it lands, so
LOCAL's strip now goes before the camera on the way out and comes after it on the
way in. That makes every hop to or from LOCAL a slide longer (`calm_length`).
Between the map and the chart the band does what the toolbar does: held whole as
a piece of the held picture while the camera moves, then decoded into the new
row (`foot_swap`). LOCAL's strip is a drawer (`_quiet_wrap` in its clipped
holder, with its own rise on arrival and the hand band that replaces it in a
fight): the slide moves the drawer inside its holder, and with the hand up, where
the strip is hidden, LOCAL has no foot.

Inside `_drive_chrome()`, above `var on := _slide_way == &"on"`:

```text
ON eases out, OFF eases in (the band's cubic; the side bar's column, 265
px to the band's 21, on a sine, so at its fastest it moves 8 px a frame,
not 15)
```

## No wheel between distances

Above `static func fade_chrome(c: CanvasItem, k: float, dx: float = 0.0) -> void:`:

```text
NO WHEEL BETWEEN DISTANCES (Jon, Oct 10: "having the scroll function to go
between them isn't intuitive for users and is kinda disruptive. Tab and
clicking the actual buttons works just fine"). The wheel zooms within the
chart and the map and stops at the end of each; Tab (`next_screen`) and the
HUD's tabs are the way from one distance to the next.
```

## Map dock by black

Inside `preroll()`, above `var dock_fade := chain == &"station" and r == MAP and target == LOCAL`:

```text
THE MAP'S DOCK GOES BY BLACK, NOT THE CALM MOVE (Jon, Oct 20: "there is a
frame where the ship is there? then it goes away? and then it comes back
in?"): LOCAL is built in the black with your ship kept off it
(`SectorScreen.dock_hidden`), comes up empty beside the station, and the
dock's arrival is the first your ship is seen of it
```

## Prebuilt map

Inside `preroll()`, above `var _pt_pre := Time.get_ticks_usec()`:

```text
THE MAP BUILT WHILE THE OLD SCREEN MOVES (Jon on 1A: "it hitches"): its
system drawn and its sky baked out of sight during the pre-roll, so it is
up the frame it is asked for and the move never waits on it
(drawn, but not seen: its pictures have to be drawn to finish -- the map's
palette is cut from its own first frames -- so it stands in the tree at no
opacity, under nothing it could take a click from for long)
```

Inside `preroll()`, above `pm.modulate.a = PREBUILT_A if target == CHART else 0.0`:

```text
(the chart at a trace of opacity so it is drawn, `PREBUILT_A`; the map at
none: its panel's sun is a shader that does not take its node's opacity,
and showed whole over the chart)
```

Inside `preroll()`, above `(pm as SystemMapScreen).show_system(Run.node_at(), Net.handed_clock(Run.at) if r == LOCAL else Net.adopt_clock(Run.at), false)`:

```text
(at the system's kept clock, held while it waits here and through
the move: `SystemMapScreen.clock_held`. Out of LOCAL, LOCAL's own,
so the pair stands where LOCAL had it, unless the party is too far
on from it, `NetSession.handed_clock`; out of the chart, which shows
no angle of it, the party's in co-op: `Router.pair_handed`)
```

## Prebuild LOCAL

Inside `preroll()`, above `elif target == LOCAL and ((lad.seam == 2 and lad.design == "C") or lad.seam == 0) \`:

```text
LOCAL TOO, ON 2C (Jon: "2C still has a small delay/hitch"): built here, at
the click, before anything has moved, instead of at the swap in the middle
of the dive, where building it took 60-90 ms of one frame. Not when LOCAL
would play something as it is built -- an event opening, a fight, a jump's
arrival or departure, undocking -- which would play out unseen
(and on a dive -- Tab from the chart -- and on GO, the event's band waiting
for the move to land: built at the swap, LOCAL stood still 40-110 ms in the
middle of the move)
```

## Prebuild yard

Inside `preroll()`, above `elif target == STATION and ((lad.seam == 3 and lad.design == "B") or (lad.seam == 0 and Router.docked)) \`:

```text
3B TOO, BOTH WAYS (one smooth motion: the screen arriving was built at the
swap, a quarter of a second stood still in the middle of the move): the
yard built at DOCK, before anything moves, and held still (not ticking, so
none of its sound starts) until it is shown; LOCAL built at UNDOCK
(the berth from the chart while docked, Tab: built at the swap it stood
160 ms still in the middle of the dive)
```

Inside `preroll()`, above `Router.content.add_child(ss)`:

```text
BUILT WHERE IT WILL STAND, as LOCAL is at UNDOCK (below): in the
screens' area behind LOCAL, laid out by the game's own theme. Under the
ladder it took the engine's, and the figures over your ship in the yard
kept it after the swap: 153 px tall for 144, hung 9 px high (Oct 21)
```

Inside `preroll()`, above `Router.content.add_child(pl)`:

```text
BUILT WHERE IT WILL STAND, as the calm move builds its screens
(`_calm_prebuild`): in the screens' area behind the berth, laid out by
the game's own theme. Under the ladder it took the engine's, and kept
it after the swap: its bar 43 px tall for 32, its arena 11 px short,
your ship 5 px high on it and the station placed for neither (Oct 21,
found laying the undock over the dock's ENTER backwards)
```

## Carried keys

Inside `_input()`, above `if e is InputEventKey and _carry(e as InputEventKey):`:

```text
THE ARRIVING SCREEN'S OWN KEY, carried to it: until the camera lands
the screen left is still the current one, so L pressed as the chart
came on went to LOCAL and was lost (Jon, Oct 20: "L doesn't work to
bring you to the local region"). Taken here, so the screen left does
not act on it too, and given to the screen arrived at once it is up.
```

## Side bar swap

Above `func _side_begin() -> void:`:

```text
THE SIDE BAR SWAPS IN PLACE (Jon, Oct 13: "the side bar goes blank and then
draws the new side bar. Can we not have it go blank and just have it
transition to the new side bar?"). From the swap, the side bar's rect is the
`SideSwap`'s: the held frame's copy of the panel left, to the arriving
screen's panel, live underneath, in the look picked, over the rest of the
move (A, B) or its own short length (C to F). The held picture leaves that
rect alone once it is drawing (`side` in the shader).
```

## Two distances in one

Inside `_style_for()`, above `s.soft = true`:

```text
TWO DISTANCES IN ONE (Tab from the chart, the berth to the map): the held
picture leaves by how much of it is kept, not by a dither -- the 4x4
checker it went through read as noise at the middle of the move
```

## Star handoff

Inside `_style_for()`, above `s.curve = true`:

```text
YOUR STAR HANDED OVER (Jon: "zoom in on the star icon on the star chart
and THAT transitions into the star in the sector map"): the chart
closes on your system's star; the map arrives so far out that its sun
is the size of the chart's star and on it; the held chart has a hole
exactly the size of the live sun, so the icon becomes the sun, and
the system opens round it as the chart thins away, one curve
```

## Smoothed handoff

Inside `_style_for()`, above `s.world = true`:

```text
SMOOTHED (Jon: "the transition can be smoother"): one curve with the
same speed both sides of the handoff, the world's size and place
carried exactly, the held picture sampled between its pixels so it
slides rather than steps, and taken away by a soft edge from the
outside in, the world itself last
```

## Into the hangar

Inside `_style_for()`, above `s.soft = true`:

```text
INTO THE HANGAR (Jon: "the station becomes something on the far right
of the screen that the ship flies into .... and THAT becomes the
shipyard"): LOCAL draws the station's side with its hallway at your
height (`StationFace`); your ship flies into it and the camera after
it. 3B: once your ship is all inside, the camera pans sideways through
the station's own hull into the yard (`_step_pan`). 3D: on
into the mouth until the hangar fills the picture, and across into the
yard by a soft edge. In the yard your ship flies in from the left onto
its stands, and then the elevator slides in (`StationScreen`).
Undocking runs it all the other way.
```

## Soft edge

Inside `_style_for()`, above `if bool(s.get("soft", false)) and (seam == 0 or seam == 1):`:

```text
(the soft moves -- 1A, the dives -- feather the held picture's edge as it
goes; the eaten edge on top of that put a 40 px dark band round it on the
very first frame)
```

## Pan through station

Above `var _pan_view: _PanView = null`:

```text
THE PAN THROUGH THE STATION (3B, Jon: "When the LAST part of the ship (its
tail) has gone in behind the lip, the screen PANS"): the camera slides
sideways -- the held picture out to the left, the station's own hull close
past the camera (`StationFace.draw_hull`), and the screen arriving in from the
right behind it -- and stops on the yard, the hull gone past (Jon: no
station in the yard), the yard's own hall running on where the elevator will
slide in (`StationScreen`'s yard edge). Undocking pans the other way.
```

## Prebuilt chart opacity

Above `const PREBUILT_A := 0.008`:

```text
THE CHART BUILT AHEAD STANDS AT THIS OPACITY, not none: Godot leaves a
canvas item under about 0.007 undrawn, so a chart at 0 drew for the first
time on the frame of the swap -- 64 ms in the middle of the move. At 0.008 it
is drawn (its sky's shaders and caches warmed) and adds at most two levels in
255 over the picture it is under, for the UI's fade before the move.
```

## Calm move audit

Above `const CALM_SHADER := preload("res://shaders/calm_ladder.gdshader")`:

```text
THE CALM MOVE (Jon picked A, Oct 17, of three directions filmed after the nav
audit: "the movement between local > sector > starchart and all the various
iterations [is] EXTREMELY disorienting"). The audit measured why: the move
between LOCAL and the map zoomed about the world you orbit, so your ship slid
330 px one way, reappeared 270 px off and slid 350 px back -- two of it on
screen at the handoff; the side bar and the toolbar decoded while the camera
moved; the chart and LOCAL were a dip to black where the others zoomed; and a
press mid-move was a hard cut.

Every hop between LOCAL, the map and the chart -- both ways, by a tab, Tab,
any door -- is now this one motion: the UI leaves, (into LOCAL) the side
column and band slide off, ONE CAMERA MOVE (`CALM_CAM_S`, smootherstep) with
both screens scaled about your ship (your star, on the chart) and your ship
walked along ONE STRAIGHT LINE from where it rests to where it will rest, the
screens changing hands by a crossfade where both draw it in the same place;
then (out of LOCAL) the column and band slide on, the side bar and toolbar
decode, the UI arrives. The side panel is never on the move with the camera
(Jon, Oct 17: "The side panel should come in AFTER the animation stops when
going local > sector or local > starchart ... go away BEFORE the animation
starts when going from sector > local or starchart > local"). "Out" is always the picture shrinking about you, "in"
always it growing. THE CHART AND LOCAL are the same move with one handoff
(not two through the map, which would be twice as long, nor the dip to black
Jon asked for on Oct 10 when the zoom between them swung round).
The station and the jump's departure keep their own moves.
```

## Calm switch

Above `static var calm_force := -1`:

```text
THE SWITCH: `-- calm=off` puts back the moves Jon picked on Oct 8-13 (1A,
2C, the dip to black) -- the designs and their timings kept whole behind it.
A harness sets `calm_force`. (`[flow] calm=false` in settings.cfg did it too,
and is not read since the dev rows went from Settings, Oct 19.)
```

## Prebuilt chart

Inside `_calm_prebuild()`, above `Router.content.add_child(pm)`:

```text
BUILT WHERE IT WILL STAND, in the screens' area, behind all of it: laid
out by the game's own theme (the ladder is not under it, and a chart
built here took the engine's -- its buttons 31 px tall, its row 1020
wide, your ship's place on it 7 to 50 px off where it then rested: the
move aimed at the one and landed on the other); and the chart, drawn
faintly to warm it, behind the field, not over the screen being left
(at PREBUILT_A over it, it lifted the top plate two levels for the UI's
fade -- Jon's "the border on the top panel flickers?")
```

## Held picture opacity

Inside `_calm_hold()`, above `img.convert(Image.FORMAT_RGB8)`:

```text
OPAQUE, as it was seen (Jon, of the map <-> chart hop: "the border on the
top panel flickers?"): the viewport's own alpha is not what was seen --
where a see-through plate was drawn over the field it reads 0.84, and the
plate held over its place (`_calm_cover`) let the screen arriving under it
show through, the plate's line and fill shifting for the length of the move
```

## Held ship position

Inside `_calm_hold()`, above `if is_instance_valid(old) and bool(old.call(&"ladder_ready")):`:

```text
(where the screen left actually drew your ship in that frame, not where its
camera was asked to put it: the chart's turning galaxy lands it a pixel or
so off its aim at a far zoom, and the held picture, carried at four times
its size into LOCAL, put a second ship 5 px from the first)
```
