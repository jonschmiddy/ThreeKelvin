The reasoning behind `tkg/scripts/ui/ShipView.gd`, moved out of the code verbatim; each heading is referenced from the code by a `Why:` line.

## Two renderers

Above `const W := 240`:

```text
The ship sprite is a UI element: it shows your build, your heat, and your
damage at a glance. Hull shape reads weight class; bolted-on modules read
manufacturer via shape and palette.

TWO RENDERERS, one control. When the hull carries a `sprite` it is blitted
whole; when it does not, draw_ship() draws it procedurally exactly as it
always has. That fallback is the point — real art arrives one asset at a time
and the game has to stay playable through a migration that will take a while.

Every screen goes through this class rather than through ShipSprite, which was
written for real art and never instantiated. Five call sites already use this
one, and it already owns magnification, showroom preview, heat and damage.

ONE SUBJECT, NOT ONE SHIP. Every read used to go straight to `Run` — the
hull, the fitted modules, the hull points, the heat — which is exactly right
for the only ship a solo game has. A party has four, and three of them are
being flown on other machines, so the drawing code now takes a `ShipBuild`
and the question "whose ship is this" is answered once, in `_b()`, rather
than at every point of use. See ShipBuild.
```

## Canvas size

Above `var _w: int = W`:

```text
The canvas actually in use. Equal to W/H while drawing procedurally, and equal
to the hull sprite's own dimensions when there is one.

Variables rather than constants because the alternative is scaling the sprite
to fit 240x120, and scaling pixel art by a non-integer factor is the one thing
the art direction forbids outright.
```

Above `var _sized: bool = false`:

```text
A caller has set `custom_minimum_size` itself and owns it — crop(), or
setup_preview() with a view height. `_resize_canvas` leaves those alone.

Needed because a crop deliberately clears `_fit_h` ("a width the caller
means"), which used to be enough to protect it only because the canvas branch
was unreachable at the magnifications every screen used.
```

## Idle bob

Above `var _bob_amp: int = 0`:

```text
Idle bob: the ship drifts a couple of pixels up and down so it reads as
floating rather than pinned to the panel.

Moved in WHOLE PIXELS, inside the image, and only redrawn on the frames the
offset actually changes — which at these settings is about eight times a
second, not sixty. Both halves matter. A sub-pixel offset would resample the
sprite and undo the nearest-neighbour crispness the whole art direction rests
on; and animating the Control's `position` instead would fight the containers
every screen puts this inside.
```

## Exhaust

Above `const FLAME_HZ := 10.0`:

```text
Exhaust playback. The plume is a strip of authored frames that change SHAPE
as they burn, so nothing here has to fake motion — it just picks a frame.

This replaced a palette cycle that stepped every pixel up and down the
flame's own brightness ramp. That animated all of it, but only ever in
brightness; a flame gutters and swells, and shape is most of what sells it.
```

## Idle burn

Above `var _burning: bool = false`:

```text
OFF unless a screen asks for it.

The engines only burn on the chassis select, where the ship is a showroom
piece being sold to you. Everywhere else it is parked — the refit screen is a
workbench, the sector is a place you have arrived at, the dock is a dock — and
a permanently firing engine on a stationary ship reads as a loop nobody
switched off rather than as motion.

REVERSED BY JON, Oct 13, on the coded-thruster mockup (ThrusterFx): "Yes, a
gentle idle burn, in fights and anywhere a ship sits." The paragraph above
is kept as the reasoning that held until then. So this flag now means the
engines are UP -- the chassis select's showroom burn (CRUISE), the arrival
and the departure (FULL) -- and a ship with it off idles (`_thrust_now`).
```

## Engine flame

Above `var _flame_layer: Control`:

```text
THE ENGINE FLAME IS CODE NOW (Jon picked look A, dynamic with sparks, Oct
13): `ThrusterFx`, drawn by `_flame_layer`, an INTERNAL child in front of the
others, so it is drawn after the hull and BEFORE every child -- the mount
points and their parts are painted over it, never under it. It reads the
same canvas transform the hull does (`canvas_to_local`: centring, bob, zoom,
the half sheet), so it moves, scales and crops with the ship and nothing
repaints the hull for it. The PixelLab strips are no longer drawn: the rig
(`HullData.thrusters`) is where each flame starts, and `-- exhaust` still
checks it.
```

## Arrival

Above `const ARRIVE_MS := 4500.0`:

```text
ARRIVAL. The ship flies in from the left, cuts its engines, and drifts to a
halt at its resting position, then settles into the idle bob.

Eased out rather than linear, because the DRIFT is the whole point: constant
speed reads as a slide. The engines cut at ARRIVE_CUT, before the stop, so the
last third is visibly unpowered coasting.
Slow, and slower than feels right when you read the number. The approach is
the only unhurried thing in the game and it is doing scene-setting work: four
and a half seconds of coasting says "you have got somewhere" in a way that a
second and a half does not. Most of it is the unpowered drift, which is the
part worth having.
```

Above `const ARRIVE_LEAD_S := 0.80`:

```text
THE DRIVE IS HEARD BEFORE THE SHIP IS SEEN. Jon: "reverse warp... pause ..
thruster sound ... ship enters". Every arrival clip opens with this long a
swell of the drive before the approach starts, and every caller that plays one
holds the ship this long first, so the flame and the sound still share a clock.
`audio/flameout.py` reads this line.
```

Above `func arrive(bob_amp: int = 2, delay: float = 0.0) -> StringName:`:

```text
Fly in, then idle. Safe on a view that is already parked.

`delay` holds the ship off screen before it starts. A convoy is the reason it
exists: four hulls beginning the same eased approach on the same frame arrive
as one object with four parts, and a fraction of a second between them is the
whole difference between a formation and a sprite sheet.
Returns the CLIP for the approach it just drew, so a caller that also plays
the drive plays the one cut from this row at this hull's weight. A caller
with no sound to play ignores it — and a convoy still gets four different
patterns, which is the one place the variation is free.
```

## Flameout table

Above `const FLAMEOUTS := [`:

```text
shrink at intervals that grow — and the ship coasts the rest dark. A hard cut
read as a switch being thrown.

It used to be one fixed pattern, which was good the first time and a
metronome by the tenth. Now it is five, picked per arrival, and the sound is
cut from the same table so the two cannot come apart. See audio/flameout.py.
GENERATED BY audio/flameout.py -- do not hand-edit; run it instead.

Each row is one way for the drive to starve: the lit windows of
the flame, in arrival progress. The first window is the clean
burn, so the rule is just 'lit if e falls inside a span'.

THE SOUND IS CUT FROM THESE SAME ROWS -- sfx/thruster_arrive_a
is row 0 gated by row 0 -- so editing a number here without
re-running flameout.py slides the picture off the sound, which
is the one thing this must never do.
```

Above `const FLAMEOUT_SFX := [`:

```text
The clips cut from those rows: one ROW of this per hull
weight, indexed by HullData.Weight, and one COLUMN per
pattern above. Same flame timing at every weight -- what
changes across a row is how big the engine making it is.

Not named `thruster_arrive_2`: Audio.play() reads that
spelling as a round-robin take and would pick one at
random, which is exactly the desynchronisation this table
exists to prevent.
```

## Departure

Above `const DEPART_EDGE := 12.0`:

```text
LEAVING. The engines come up, the hull leans into them, and the flare takes
it — the vanish is not here, it belongs to `ShipSlot.pulse()` the same way
`ConvoySlot.jump_out()`'s does.

HOW FAR IT GETS, and it is measured rather than chosen.

The first version was a twenty-pixel lean, on the reasoning that a hull
driven any real distance would draw across the AreaView on the far side of
the arena -- true, and the wrong conclusion. `ShipSlot` biases this control
to 68% of its slot precisely so there is empty space on the ship's right,
and the run is the whole of that space: measured on the first tick, from the
hull's nose to the slot's edge, less a margin. Nothing to collide with,
because the room was already there and empty.

`hull_rect()` is what makes it measurable. This control is most of half the
arena and the ship is centred inside it, so "where does the nose end" is not
`size.x` and never was.
```

Above `const DEPART_OVER := 150.0`:

```text
AND THEN SOME. The room inside the slot is about ninety pixels, which on a
four-hundred-pixel hull is a nudge rather than a departure. The overrun is
the rest, and it is affordable because of WHEN it happens: ease-in cubic
puts most of the travel in the last fifth of the run, which is the fifth the
flare is already firing over and the frame before the hull is taken. The
nose crosses into the neighbouring space for about a sixth of a second,
under a column of light, and then there is no ship to overlap anything.
```

Above `func _tick_departure() -> bool:`:

```text
Ease-IN cubic, the exact mirror of the approach's ease-out. The approach
arrives with speed and gives it all up to the drift; this gives up nothing
and takes it all.

Driven from `_process` rather than from a Tween for the reason `position.x`
is commented as reserved: it is owned here, in one place, under one rule.
```

## Hyperdrive

Above `const HYPER_CORE := Color("#e4f2ff")`:

```text
HYPERDRIVE. The one departure that touches the hull instead of drawing over
it: the ship holds station, shudders under a charge, and is eaten from the
outside in until nothing is left but a line of light along its own centre.

THIS CLASS KEEPS NO CLOCK FOR IT. It did -- a melt driven off its own timer
here, while `JumpFx` ran the beam off its own life -- and two clocks that
have to agree are two clocks that eventually will not, which is the lesson
the flameout table was built on. The choreography lives in `JumpFx` alone;
`ShipSlot` pushes the melt and the shake in every frame, and this renders
what it is told.

The light the ship turns into. Same cold white the columns are drawn in.
```

## Hull extent

Above `var _body_px := Rect2i()`:

```text
THE HULL'S OWN EXTENT, in canvas pixels: where the sprite is actually opaque.
The canvas is wider than the ship -- it carries empty columns at the stern for
the exhaust art to sit in -- so anything sized to the canvas reaches past the
tail. Jon, on the first hyperdrive: "the horizontal bar shouldn't be longer
than the ship". It was, by exactly that padding.
```

## Standalone flameout

Above `var _sputter_e := -1.0`:

```text
THE FLAMEOUT ON ITS OWN (Jon, Oct 21, undocking: "its flame sputters down to
idle"): the arrival's own flameout from its first cough on -- the end of its
clean burn -- on a ship that is not arriving: the coughs of a FLAMEOUTS row
(`arrive_thrust` of its windows, over the idle), then the idle it keeps. Its
owner steps it (`sputter_step`, seconds since the first cough) and hears the
same row's clip from the same place (`sputter_from_s`), so the coughs seen
are the coughs heard, as on an arrival. The arrival's flameout as a progress
through its row, or -1 when not sputtering.
```

## Film clock

Above `static var shot_clock := -1.0`:

```text
FOR THE HARNESSES' FILMS: when set (>= 0), the clock every hull's bob, flame
and shudder run on, in seconds, advanced by the film one step a saved frame
-- so a window that drew at 8 a second still films a bob at its real rate.
-1 is the game's clock (`GameClock`), which is all play ever uses: game
time, not the wall's, so the movie writer's films and the hit-stop's slow
motion reach it too.
```

## Half pixel snap

Inside `_init()`, above `stretch_mode = TextureRect.STRETCH_KEEP_CENTERED`:

```text
Draw at native size, centred. KEEP_ASPECT_CENTERED rescales the texture to
whatever rect it is handed, so the ship changed size whenever a side rail
opened — and scaled pixel art by arbitrary fractions while doing it.

CENTRED MEANS HALF-PIXELS, and that is why the project turns on
`rendering/2d/snap/snap_2d_transforms_to_pixel`. KEEP_CENTERED puts the
texture at (size - tex) * 0.5 from the control's origin, so whenever those
two differ by an ODD number the sprite is drawn on a half pixel. In the
sector slot the control is 455 tall against a 144-row heavy: (455-144)/2 is
155.5, and the ship rendered at y=197.50.

Half a pixel is invisible while the ship is still. It is NOT invisible while
it bobs: with NEAREST filtering every row's sample sits exactly on a texel
boundary, so the tie-break flips as the content moves and about 1100 pixels
of a heavy changed colour on every bob step — the hull appearing to crawl
without moving. The canvas itself was never at fault; it is a pure
translation at all five bob offsets, which is what made this hard to find.
Snapping took that to six pixels. Do not turn the snap settings off.
```

Inside `_blit_sprite()`, above `var ch := img.get_height() + _bob_amp * 2`:

```text
Headroom above and below so the bob has somewhere to travel without the
sprite being clipped at the extremes of its own canvas.
ONE ROW OF PADDING WHEN THE PARITY IS WRONG, and this is the whole reason
the ship stopped crawling as it bobs.

STRETCH_KEEP_CENTERED puts the texture at (size - tex) * 0.5 from the
control's origin. When those two differ by an ODD number that is a HALF
pixel -- the sector slot is 455 tall against a 144-row heavy, so the ship
drew at y=197.50 -- and with NEAREST filtering every row's sample then sits
exactly on a texel boundary. Standing still that is invisible. Bobbing, the
tie-break flips as the content moves and about 1100 pixels of a heavy
changed colour on every step, which reads as the hull crawling.

A transparent row costs nothing and makes the difference even, so the
texture lands on a whole pixel. This was briefly fixed with the project's
`snap_2d_transforms_to_pixel` instead; that works here and quantises the
launcher's rotating galaxy into a visible judder, because a global snap
cannot tell a bobbing sprite from a turning starfield. Fix the sprite.
```

## Whose ship

Above `var _fixed: ShipBuild = null`:

```text
WHOSE SHIP. Set by setup_preview() or follow_peer(); both left alone means
the ship you are flying, which is what every existing call site wants and
why none of them changed.

Two fields rather than one because the two cases refresh differently. A fixed
build is a snapshot and never moves on its own; a partner's build is replaced
wholesale every time the host pushes a roster, so it has to be looked up
again rather than held.
```

## Canvas readback

Above `func canvas() -> Image:`:

```text
The composed pixels, for anything that wants them without a renderer.

`texture.get_image()` reads back through the RenderingServer, which under
--headless is a dummy that hands back nothing — so the contact sheet came out
eight transparent rectangles. This is the image the view actually painted.
```

## Partner repaint

Above `func _repaint_partner() -> void:`:

```text
Repaint only when THAT partner's ship changed.

`party_changed` fires for anything the roster says, including somebody else
venting a point of heat, and a procedural hull is fifteen thousand pixels of
GDScript to redraw. `NetSession.build_of()` hands back the same object while
the wire is unchanged, so object identity is the test.
```

## Magnification

Above `var _k: int = 1`:

```text
Whole-number magnification for the preview. The sprite is drawn once at 240
by 120 and then resized with INTERPOLATE_NEAREST, which is what keeps a
doubled pixel exactly four pixels rather than a blurred one — the same reason
the project only ever scales its window by integers.

Done to the IMAGE rather than by stretching the TextureRect because the two
stretch modes that could do it are both wrong here: KEEP_CENTERED never
scales at all, and KEEP_ASPECT_CENTERED fits the whole texture into the
control, so cropping the empty rows above and below the hull would shrink the
ship instead of magnifying it.
```

## Canvas to local

Above `func canvas_to_local(p: Vector2) -> Vector2:`:

```text
Where a pixel of the HULL SPRITE lands inside this control.

Three transforms, and every one of them is a thing that has moved at least
once: the sprite is pasted into a canvas with `_bob_amp` rows of headroom and
then shifted by `_bob_off` as it idles, the canvas is magnified by `_k`, and
STRETCH_KEEP_CENTERED centres the result in whatever rect the layout gave us.

Exists so that anything drawn ON the ship — a hardpoint, a mount marker — can
be positioned from the hull's own measured coordinates rather than from a
second set of numbers that would have to be kept in step with them.
```

Inside `canvas_to_local()`, above `var q := p * 0.5 if _half else p`:

```text
FOUR transforms once the half sheet exists. A caller measures against the
full sprite — HullData's lines are one set of numbers per hull, not one per
sheet — so a point has to come down to the canvas actually being drawn
before anything else is done to it. Without this the mounts on a convoy
ship sit at twice their offset and scatter off the hull, which is what it
looks like: markers in space beside the ship rather than on it.

The bob is NOT halved. It is already in canvas pixels, because it is a
property of the canvas rather than of the sprite that went into it.
```

## Art scale

Above `func art_scale() -> float:`:

```text
The same thing as a float, and the one to ask when the answer has to be right
on the half sheet.

`zoom_level()` returns the magnification and nothing else, so on a half-drawn
ship it is out by a factor of two — an art pixel there is half a screen pixel
per unit of _k. Anything sizing itself against the HULL wants this; anything
that genuinely means "how many times is the canvas magnified" still wants
zoom_level().
```

Above `func use_half(on: bool) -> void:`:

```text
A note on the OTHER unit, because it is the one that causes mistakes.

A hull sprite is authored at TWICE its box (art/tools/boxes.py, ART_CONTRACT
§4), so a sprite pixel is half a box pixel. Anything that has to agree with a
number measured off the box rather than off the image has to know that.

Nothing in the UI currently does, and the reasoning is worth keeping: a fitted
part is sized in SPRITE pixels on purpose, which makes it half the size it is
in the hold. Matching the hold instead would put five weapon hardpoints' worth
of gun on 125% of a heavy hull. See MountPoints._mag.
```

## Half sheet

Above `func use_half(on: bool) -> void:`:

```text
Draw this ship from the half sheet, for the views that hold several at once.

A SHEET, not a scale. `zoom()` cannot go below 1 and the art is authored at 2x
its box, so the size the convoy column wants only exists as a second file —
see HullData.sprite_half. The canvas follows whatever is blitted into it, so
nothing else here has to know: `_resize_canvas` picks up the smaller image and
`custom_minimum_size` comes down with it.

Idempotent, and it refreshes only on a real change, because callers set it
from party state that repaints far more often than it changes.
```

## Ship offset

Above `func canvas_width() -> float:`:

```text
How far the SHIP's centre sits from the middle of its own canvas, in screen
pixels. Positive means right of centre.

Not zero, and not a constant. A hull canvas carries the clearance its exhaust
plume needs, which is on one side only — 38 art pixels against 5 at the nose
on the box spec — so a canvas centred in a panel draws a ship that is plainly
right of the middle. Measured off the opaque pixels rather than off the spec,
because the spec is a fact about the placeholders and this has to keep being
true of whatever art replaces them.
How wide this view's canvas draws, in screen pixels. The control's own width
is the same number once a layout pass has run; this is available before one
has, which is what lets a screen place the ship on the FIRST frame instead of
converging onto it over several visible ones.
```

## Ship rect

Above `func ink_rect() -> Rect2i:`:

```text
THE SHIP'S OWN RECT, in this control's coordinates.

For anything that wants to draw AROUND the hull rather than around the panel
holding it. A slot is usually far bigger than the ship in it -- ShipSlot's is
half the screen -- so a box at the control's own edges says nothing about
what is being pointed at.

The opaque pixels, in CANVAS coordinates and with the bob taken out.

`ship_rect` answers the same question in the CONTROL's coordinates, which is
what anything drawing a box over the ship wants. A caller that is deciding
how to scale and place the canvas itself needs the other frame of reference:
a hull occupies about a third of its sheet, so "how big is this ship" and
"how big is this sheet" differ by a factor that changes per hull.
```

## Ship bottom

Above `func ship_bottom_y() -> float:`:

```text
How far BELOW the canvas's middle the hull's last opaque row falls.

The vertical twin of `ship_offset_x`, and it exists for the same reason: a
hull occupies about a third of its canvas, so anything placed a fixed
distance from the middle is placed a fixed distance from nothing. A light
hull and a heavy one want the same air under them, not the same number.

The bob is subtracted. It moves the drawn rows a couple of pixels either way
several times a second, and a readout that recomputed its place from a bobbing
sprite would twitch every time the screen refreshed.
```

## Magnify and crop

Above `func magnify(k: int, view_height: int) -> void:`:

```text
Magnify and crop WITHOUT going into showroom mode.

The refit screen wants the live ship — its heat glow, its battle damage, the
modules actually bolted to it — just bigger. setup_preview() would give it
the size and take all three away, because preview means "a hull you do not
own yet". Same geometry, different question.
```

Inside `magnify()`, above `crop(_w * _k, view_height)`:

```text
REMEMBERED, so the width can be re-fitted when the canvas turns out to be
a different size than it was at this call. It usually is: _w is still the
procedural 240 until a sprite is composited, so a 168-wide hull was
reserving 480px of panel for 336px of ship and drawing it centred in the
difference. Only magnify() sets this — crop()'s other caller, the convoy
strip, passes a width it means and must keep it.
```

Inside `magnify()`, above `clip_contents = self_clip and view_height < _h * _k`:

```text
NOT CLIPPED, when the box already covers the canvas. `crop` turns clipping
on because cropping IS clipping — but magnify shows the whole canvas, so
the only thing the clip can remove is a CHILD, and the child here is the
hardpoint layer. A gun bolted to the last mount on the spine reaches past
the hull it is mounted on, and it was losing its muzzle to a rectangle
with nothing else to cut.
```

## Self clip

Above `var self_clip: bool = true`:

```text
WHETHER THIS VIEW MAY CLIP ITSELF.

True everywhere by default, and FALSE on the refit screen, which wraps the
view in a window of its own and does the clipping there.

It matters because the hardpoint layer is a CHILD of this control, so a clip
meant to keep a magnified hull inside a short row also cuts every gun that
reaches past the hull it is bolted to. `magnify` already refuses to clip
when the box covers the canvas, for exactly that reason — but the moment the
zoom makes the canvas taller than the box, the clip comes back on and takes
the muzzles with it. Two owners of one decision; this is the one that wins.
```

## Zoom only

Above `func zoom(k: int) -> void:`:

```text
Magnify WITHOUT taking a position on how big the control should be.

magnify() also sets custom_minimum_size, which is right where the view owns
its own box — the refit screen, the chassis select, the dock — and wrong
where a layout has already decided the box. The sector strip anchors its hull
to a fraction of the encounter slot, so a minimum size fights the anchors and
the ship shoves the enemy panel sideways.

Whatever rect it is given, this changes only how big the ship is drawn inside
it. STRETCH_KEEP_CENTERED does the centring; the caller does the clipping.
```

## Crop

Above `func crop(view_width: int, view_height: int) -> void:`:

```text
Show only the middle of the canvas, at whatever magnification is set.

The convoy strip is the reason this is separate from magnify(): three
partners have to fit beside your ship in an arena that is already full, and
a hull sits in the middle of a canvas with empty rows above and below it. So
the way to make a partner small is to show less of the canvas, never to scale
the ship — the art direction allows integer magnification and nothing else,
and half a pixel is not a pixel.
```

## Build view

Above `func setup_build(b: ShipBuild, k: int = 1) -> void:`:

```text
A view of a SPECIFIC build, rather than of a hull or of the run.

`setup_preview` shows a hull bare and `local()` shows the ship you are
flying. Between them sits the one case the transfer screen needs: a hull that
is nobody's current ship but is still wearing its parts -- the frame you have
just traded in. `ShipBuild.fitted_out` composes it; this is how it gets here.
```

## Preview crop

Inside `setup_preview()`, above `expand_mode = TextureRect.EXPAND_IGNORE_SIZE`:

```text
A hull occupies about a third of the canvas vertically and is centred
in it, so cropping symmetrically trims empty space without moving the
ship. Horizontally it is NOT centred, so the width stays full.

EXPAND_IGNORE_SIZE is load-bearing and its absence is silent: a
TextureRect derives its minimum size from its TEXTURE, so without this
the control kept claiming the full 120 rows whatever custom_minimum_size
said. The card's own labels were pushed out of the button and drew on
top of the attribute block underneath it.
```

## Real art

Above `func arriving() -> bool:`:

```text
Real art. The hull sprite goes down whole; everything the procedural path
layers on top of it — heat glow, battle damage, module shapes — is not drawn
here, because that is the shader's job now and the modules are their own
sprites. See shaders/heat.gdshader.
Flying in (`arrive` called and not yet parked: held off screen, or on its
approach). LOCAL's sky camera holds still for it (`LocalSky._follow`).
```

## Spool

Above `func set_spool(look: StringName, amount: float, secs: float) -> void:`:

```text
THE HULL AS THE SPOOL STARTS: one look of `JumpFx.SPOOLS`, at `amount`, pushed
in every frame from the flare's clock by `ShipSlot`, the way the melt is.

On the hull's own pixels and nowhere else, in whole pixels and cold light --
the rules the melt and the beam keep. Nothing is scaled, and nothing warm is
drawn: EMBER, FLARE and HOT mean heat.
```

## Interlace

Above `const INTERLACE_SHADER := preload("res://shaders/interlace.gdshader")`:

```text
INTERLACE IS A SHADER, NOT A PASS OVER THE HULL IMAGE, because Jon wants the
modules to slip with the hull and the modules are not in that image --
`MountPoints` draws them in its own `_draw()`. The material goes on this view
and the children draw through it, so one set of rows moves the whole ship.
See shaders/interlace.gdshader.
```

## Hidden fittings

Above `var _fittings_hidden: Array[Control] = []`:

```text
Children are the fitted modules, added by whichever slot built this view.

PUT BACK ONLY WHAT IT TOOK AWAY. A child that was hidden for its own reasons
stays hidden: the cutaway's hover outline (`CutawayView.Outline`) is a child
too, and `park()` -- which every arrival ends with -- used to switch it on,
so your ship lit up amber the moment it came to rest with nobody pointing at
it (Jon, Oct 13: "the ship is highlighted... No highlight").
```

## Hull rect

Above `func hull_rect() -> Rect2:`:

```text
Where the hull actually is inside this control, in local coordinates.

The control is as big as the layout gave it -- most of half the arena on the
sector screen -- and `STRETCH_KEEP_CENTERED` puts the canvas in the middle of
that at its native size. So anything that wants to aim at the SHIP rather
than at the box it lives in has to ask, and the first thing that did aimed at
the box: a jump flare sized to the slot drew a ring with a radius bigger than
the hull is long.
```

## Hull body

Above `func hull_body() -> Rect2:`:

```text
The part of `hull_rect()` that is actually ship: the same box, narrowed to the
sprite's opaque columns, and MOVED so its middle is the middle of the HULL.

It used to keep the canvas's own centre row, and the line sat there -- which is
the middle of the picture, not of the ship. A heavy's masts and spires stretch
the picture upward, so the beam ran along its top rail, 28 px above the body
it was meant to split ("It sits slightly above the middle of the hull"). The
middle is now `_body_mid`, and the melt collapses onto the same row, so the
beam still comes out of the line the hull goes to.
```

## Park

Above `func park() -> void:`:

```text
At rest, wherever that was decided.

ONE END STATE, THREE CALLERS: the approach finishing, a departure beginning,
and the player clicking through the whole thing. It was the tail of
`_tick_arrival` and only the first of those could reach it, so a skip had to
reproduce six assignments from memory and a departure had to undo them.

Safe on a view that never left. `_arrive_bob` is 2 unless somebody asked for
less, and everything else here is already where this puts it.
```

## Melt

Above `func _paste_hull(img: Image, dy: int, blend: bool) -> void:`:

```text
The hull, or what is left of it.

ROWS DROPPED, NEVER SCALED. Only the rows within `half` of the sprite's own
centre line survive, and `half` falls to one -- so the ship is eaten from the
outside in and every surviving pixel is still exactly where it was authored.
Squashing the sprite instead would resample a pixel face, which the art
direction forbids outright and which would look like a bug rather than an
effect.
```

## Left edge clip

Above `func _paste(img: Image, dx: int, dy: int, blend: bool) -> void:`:

```text
Copy `img` at (dx, dy), clipping whatever falls off the left edge.

The canvas is only as wide as the ship, so a fly-in has nowhere to start
from — the ship enters from behind its own panel edge. A negative destination
is not allowed, so the offset comes out of the SOURCE rect instead. Nose
first, which is correct: the nose points right.
```

## Hull art

Above `static func hull_art(h: HullData, pilot: String, half: bool) -> Texture2D:`:

```text
THE PICTURE A HULL IS DRAWN FROM, before a fight marks it. One question
asked in one place, so the sector map's ship (`MapHull`) is always the hull
LOCAL draws.

The half sheet when it is asked for and the hull has one. Falls through to
full art rather than refusing to draw, so a hull that has not been reduced
yet still appears — at the wrong size, which is visible, and not at all,
which is not.

THE GRADE FIRST, THE FIGHTS ON TOP OF IT: a graded weight's one hull baked at
this ship's grade (HullGrade: wear, paint, markings, lights, kit), and its
registry the ship's own; `_blit_sprite` lays HullWear's damage over that, so
a beaten S still reads as a good ship that got shot.
```

## Hull wear

Inside `_blit_sprite()`, above `var h := _hull()`:

```text
The hull BEATEN UP IN PROPORTION TO ITS HULL POINTS. This is the line that
closes an old gap: everything the procedural path layers on — heat glow,
battle damage, module shapes — was skipped for real art on the grounds that
the shader would take it over, and the shader never did. A hull with a
sprite looked showroom fresh at one hull point.

A showroom hull is undamaged because ShipBuild.showroom() hands it full
hull points, not because this branch knows what a showroom is — the same
reason the flag went from the procedural path.

worn_cached and band_for, never worn(): this runs every time the idle bob
changes offset, several times a second, and wear is a pass over every pixel
in the sprite. Band 0 returns it untouched, so an intact ship costs what it
always did.
```

## Exhaust layering

Inside `_blit_sprite()`, above `var behind := _blit_exhaust(dy, true)`:

```text
BEHIND FIRST, THEN THE HULL OVER IT, THEN THE REST. A thruster buried in
the ship's own body has to be occluded by the plating or its flame paints
across the hull it is supposed to be firing out of.

The hull is BLENDED rather than blitted when anything is under it: blit
copies alpha, so the hull's transparent pixels would punch a hole straight
through the flame behind it. Onto an empty canvas the two are the same and
blit is cheaper, so the unlayered case keeps it.
```

Above `func _blit_exhaust(dy: int, back: bool) -> int:`:

```text
The plume, over the hull, at this step of the cycle.

blend_rect and not blit_rect: blit COPIES alpha, so it would punch the flame
frame's empty pixels straight through the hull underneath it.
Every plume on this layer, and how many were drawn.

Called twice per repaint — once for the thrusters flagged `back` and once for
the rest — so a ship with engines at different depths composites in the right
order. Returns the count so the caller knows whether anything is underneath
the hull, which decides how the hull itself is pasted.
```

## Resize order

Inside `_resize_canvas()`, above `if _fit_h > 0:`:

```text
A HEIGHT THE CALLER ASKED FOR WINS AT ANY MAGNIFICATION, and the order of
these two branches is the whole fix. This read `if _k <= 1` first, which
was harmless while every screen magnified by 2 and became silent breakage
the moment they stopped: at 1x the canvas size overwrote the box three
screens had set for themselves — ShipScreen's HULL_VIEW_H, StationScreen's
crop, ChassisSelect's HERO_H — and the ship went on drawing correctly
inside a panel that had quietly resized itself. Nothing threw.
```

## Manufacturer livery

Inside `draw_ship()`, above `var m: ManufacturerData = DB.manufacturers.get(hull.manufacturer)`:

```text
Manufacturer livery: a pigment shift on the plating, not a light.

Hulls are built by somebody now, and two chassis in the same weight class
draw the same silhouette here — so colour is currently the only channel
saying whose ship this is. Kept deliberately weak (0.16) and kept OFF the
glow and core tones, because those are the heat channel and the art
direction allows exactly one source of warmth in frame: the reactor.
Paint is a property of the object; light is not.
```

## Mount positions

Above `func _draw_modules(hx: int, hy: int, hw: int, hh: int, metal: Color, outline: Color) -> void:`:

```text
Installed modules are bolted onto hardpoints in their manufacturer's colours.

Position comes from `m.mount`, never from the order of `installed`. These
have always been fixed places on the hull — weapon 0 is the dorsal ordnance,
1 the ventral barrels — but the index used to be read off the array, so
taking the dorsal gun off slid the ventral one up onto the spine and the ship
rebuilt itself under a change the player had not made. The mount is now a
choice the refit screen records and this view reports.
```

## Idle hum

Above `var hums := false:`:

```text
YOUR ENGINES AT IDLE, HEARD (Jon, Oct 13: "Let's have a low burn sound for
the idle engines"). Set on the view that is YOUR ship: on LOCAL and in
fights (`SectorScreen`), on the refit (`ShipScreen`) and on the transfer's
new hull (`TransferScreen`), because the sound follows the picture and each
of those draws your idle flame. Every other ship idles in silence -- a pack
of enemies, a convoy and you each with a bed would be mud. `Audio` keeps the view
and asks `idle_heard()` every frame; the sound follows the picture, so
nothing here starts or stops it.
```

Above `func idle_heard() -> bool:`:

```text
Whether the idle bed should be sounding for this view right now: it hums,
it is drawn, the hull is on screen, and its flame is the IDLE. An arrival's
coughs after its clean burn count as idle too: the drive is settling into
the idle there and the coughs are flashes over it, so the bed comes up in
the first gap and stays up rather than pumping with each flash (its fade is
longer than a cough). The clean burn, a departure's FULL and a hyperdrive's
dark (`_engines_off`) are not.
```

## Arrival sputter

Above `static func arrive_thrust(window: int) -> int:`:

```text
THE ARRIVAL SPUTTERS DOWN TO THE IDLE; IT NEVER GOES OUT (Jon, Oct 13: "I
don't want the engines to turn off... I just want them to sputter to an
idle"). `window` is the FLAMEOUTS window the approach is in, or -1 between
them and after the last. The clean burn and the first two coughs are FULL,
the later coughs CRUISE (shrinking flashes as the drive starves), and every
gap between them, and the coast after the last, is the IDLE the ship then
sits at. So the engines settle into the burn they keep. They used to go
dark in the gaps and through the coast (1.8 s at the end of an arrival), and
the idle came on with the park: off, then on again.
```

## Engine glow

Above `func engine_glow() -> Dictionary:`:

```text
THE ENGINES' LIGHT, for RADIANT's backdrop to catch (Nov 7, direction B,
`LocalSky._engine_light`): where the flames start (the middle of the nozzles,
global px), the way they burn (+1 or -1 along x), how hard (IDLE 0.55, CRUISE 1,
FULL 1.4), the flame's own ramp (warm or cold) and the ship's scale on screen.
Empty when no flame is drawn.
```
