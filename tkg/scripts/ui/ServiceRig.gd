class_name ServiceRig
extends BaseButton

## One of the yard's machines, standing in the service bay under your ship.
##
## THE SERVICES WERE A TABLE ABOVE THE PICTURE. Four rows of label-and-price in a
## panel over a hangar -- which is a spreadsheet sitting on top of a place, and
## the place was doing all the work of saying where you were while the panel did
## all the work of saying what you could do. A yard's services ARE machines. Put
## the machines on the yard's floor and the deck stops being a picture with a
## menu over it.
##
## AND THE MACHINES TOUCH THE SHIP. Standing in a row they were four buttons that
## happened to be drawn as machines -- a welding cart nowhere near a weld. Given
## `hull`, each one reaches the ship it works on: the welder's arm to the belly
## with a spark where it meets it, a jack whose saddle comes up under the hull,
## a fuel hose to a port, a diagnostic cable plugged in. When a machine has
## nothing to do it stands PARKED -- arm folded, jack down -- which says "your
## hull is fine" without a word of text.
##
## `BaseButton` and not `Button`: everything visible is `_draw`, and all that is
## wanted from the base class is hover, press and disabled.
##
## Drawn rather than loaded, like the rest of the station's furniture.

## Which machine this is. Only the silhouette and what it reaches with change --
## the plinth, the label and the tag are the same on all of them, because they
## are the same yard's kit.
enum Kind { WELD, GANTRY, BOWSER, POST }
var kind: int = Kind.WELD

## What it does, stencilled on the bay floor under the machine.
var label: String = ""
## What the yard charges. -1 draws no tag at all, for a machine with nothing to
## do -- an undamaged hull has no price for repairing it.
var price: int = -1
## A small gauge painted on the machine: how much of `y` is filled. Zero draws
## none. It is the reason a rig can say WHY it is dark -- a full tank and an
## empty purse look nothing alike on a bowser with a gauge on it.
var gauge: Vector2i = Vector2i.ZERO
## Where your ship's hull is, in this machine's own coordinates. Empty when there
## is no ship to reach, and then every machine stands parked.
##
## ITS OWN COORDINATES, so the machine never has to know where it was put. The
## screen stands it in the bay and hands it the hull relative to itself; the
## drawing below is all offsets from the machine's own centre.
var hull: Rect2 = Rect2()

const BODY := Color("#25344a")
const BODY_LIT := Color("#3d5273")
const DARK := Color("#141c28")
const SHADE := Color("#070a10")
const PIPE := Color("#4a6180")
const HOT := Color("#d97b29")
const LIVE := Color("#7fb89a")
const BAD := Color("#d4614f")
const CARD := Color("#c2ae86")
const CARD_DIM := Color("#6e6858")
const INK := Color("#241d14")
const INK_DIM := Color("#3f3a30")

## How much of the rig's box the price tag and the stencil take off the bottom.
const TAG_H := 15.0
const NAME_H := 12.0

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	# HOVER AND PRESS ARE THE ONLY FEEDBACK, so they have to repaint.
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


## Ink for the machine's casing right now: lit under the pointer, flat at rest,
## and drained when the yard will not do it.
func _casing() -> Color:
	if disabled:
		return BODY.lerp(DARK, 0.55)
	return BODY.lerp(BODY_LIT, 0.45) if is_hovered() else BODY


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 40.0 or h < 50.0:
		return
	# The machine's own box: everything above the stencil and the tag.
	var base := h - TAG_H - NAME_H
	var body := _casing()
	var live := not disabled

	# --- WHAT IT REACHES THE SHIP WITH, drawn FIRST so the machine's own body
	# covers the root of every hose and arm and they come OUT of it.
	if hull.size.x > 0.0:
		_reach(w, base, live)

	# --- THE SHADOW IT STANDS IN. Every rig gets one, so none of them floats and
	# all of them agree about where the floor is.
	draw_rect(Rect2(4.0, base - 3.0, w - 8.0, 3.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.5))

	match kind:
		Kind.WELD: _weld(w, base, body, live)
		Kind.GANTRY: _gantry(w, base, body, live)
		Kind.BOWSER: _bowser(w, base, body, live)
		Kind.POST: _post(w, base, body, live)

	# --- WHAT IT DOES, stencilled on the deck under it.
	var f := UITheme.pixel_font()
	var name_ink: Color = UITheme.CHILL if live else UITheme.QUOTE
	var nw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UITheme.FS_SMALL).x
	draw_string(f, Vector2((w - nw) * 0.5, base + 9.0), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, name_ink)

	# --- AND WHAT IT COSTS, on the same card the shop hangs on its shelves.
	#
	# THE SAME TAG DELIBERATELY. A price is a price wherever you are standing,
	# and one station that writes them two ways is two stations.
	if price >= 0:
		_tag(w, base + NAME_H, "%d CR" % price, live)


## Where along the hull's underside a machine standing at `x` would reach.
##
## CLAMPED INSIDE THE HULL, so a machine standing past the end of a short ship
## reaches back to its end rather than into empty air beside it.
func _contact_x(x: float) -> float:
	return clampf(x, hull.position.x + 10.0, hull.end.x - 10.0)


## The arm, jack, hose or cable that connects this machine to the ship.
func _reach(w: float, base: float, live: bool) -> void:
	var cx := w * 0.5
	var belly := hull.end.y - 3.0
	var line := PIPE.lightened(0.25) if (live and is_hovered()) else PIPE
	match kind:
		Kind.WELD:
			# PARKED WHEN THERE IS NOTHING TO WELD. The arm stays folded on the
			# cart and nothing reaches the ship at all.
			if not live:
				return
			var tip := Vector2(cx + 17.0, base - 52.0)
			var weld := Vector2(_contact_x(cx + 28.0), belly)
			_elbow(tip, weld, line, 3.0)
			# The spark, where the torch meets the plate. It is the one bright
			# point on the machine, and it is ON THE SHIP.
			draw_rect(Rect2(weld.x - 1.0, weld.y - 1.0, 3.0, 3.0), HOT)
			draw_rect(Rect2(weld.x - 4.0, weld.y + 2.0, 9.0, 2.0),
				Color(HOT.r, HOT.g, HOT.b, 0.35))
			draw_rect(Rect2(weld.x - 3.0, weld.y - 4.0, 1.0, 2.0),
				Color(HOT.r, HOT.g, HOT.b, 0.65))
			draw_rect(Rect2(weld.x + 3.0, weld.y - 3.0, 1.0, 1.0),
				Color(HOT.r, HOT.g, HOT.b, 0.65))
		Kind.GANTRY:
			# A JACK, NOT A CRANE. A jib swung over the hull would draw a bar
			# straight across the silhouette of the ship you are looking at; a
			# column rising under it touches the ship only where a lift would.
			var top := base - 60.0
			var under := hull.position.x + 6.0 <= cx and cx <= hull.end.x - 6.0
			var reach_y := belly + 2.0 if (live and under) else top - 12.0
			var mid := floorf((top + reach_y) * 0.5)
			# Telescoping: a wide lower stage and a narrower upper one.
			draw_rect(Rect2(cx - 4.0, mid, 8.0, top - mid), _casing())
			draw_rect(Rect2(cx - 4.0, mid, 1.0, top - mid), BODY_LIT)
			draw_rect(Rect2(cx - 2.0, reach_y, 4.0, mid - reach_y), line)
			var seam := mid + 6.0
			while seam < top - 2.0:
				draw_rect(Rect2(cx - 4.0, seam, 8.0, 1.0),
					Color(SHADE.r, SHADE.g, SHADE.b, 0.5))
				seam += 7.0
			# The saddle the hull sits on.
			draw_rect(Rect2(cx - 12.0, reach_y - 3.0, 24.0, 3.0), BODY_LIT)
			draw_rect(Rect2(cx - 12.0, reach_y - 3.0, 24.0, 1.0),
				Color(LIVE.r, LIVE.g, LIVE.b, 0.7) if (live and under) else BODY_LIT)
		Kind.BOWSER:
			var neck := Vector2(cx + 16.0, base - 46.0)
			var port := Vector2(_contact_x(cx + 6.0), belly)
			# A HOSE HANGS. Sampled along a curve bowed out to the side and down,
			# so it reads as something heavy slung between two points rather than
			# a line somebody ruled.
			_hose(neck, port, Vector2(24.0, 0.0),
				line if live else line.lerp(DARK, 0.45), 2.0)
			# The fuel port on the hull, with a lit collar while it can flow.
			draw_rect(Rect2(port.x - 3.0, port.y - 1.0, 7.0, 3.0), BODY_LIT)
			if live:
				draw_rect(Rect2(port.x - 1.0, port.y, 3.0, 1.0), LIVE)
		Kind.POST:
			var from := Vector2(cx + 13.0, base - 42.0)
			var plug := Vector2(_contact_x(cx - 10.0), belly)
			_hose(from, plug, Vector2(-14.0, 0.0),
				Color(PIPE.r, PIPE.g, PIPE.b, 0.85), 1.0)
			# The plug, lit red because what it is reading is the fault.
			draw_rect(Rect2(plug.x - 1.0, plug.y - 1.0, 3.0, 3.0),
				BAD if live else BAD.lerp(DARK, 0.6))


## An arm with one elbow in it: up, across, up.
func _elbow(a: Vector2, b: Vector2, col: Color, t: float) -> void:
	var my := floorf((a.y + b.y) * 0.5)
	var x0 := minf(a.x, b.x)
	draw_rect(Rect2(a.x - t * 0.5, my, t, a.y - my), col)
	draw_rect(Rect2(x0 - t * 0.5, my - t * 0.5, absf(b.x - a.x) + t, t), col)
	draw_rect(Rect2(b.x - t * 0.5, b.y, t, my - b.y), col)


## A slung line between two points, sampled a pixel at a time along a curve.
func _hose(a: Vector2, b: Vector2, bow: Vector2, col: Color, t: float) -> void:
	var c := (a + b) * 0.5 + bow + Vector2(0.0, 10.0)
	var steps := maxi(8, int(a.distance_to(b)))
	for i in steps + 1:
		var u := float(i) / float(steps)
		var p := a.lerp(c, u).lerp(c.lerp(b, u), u)
		draw_rect(Rect2(floorf(p.x), floorf(p.y), t, t), col)


## The shop's price tag, drawn here rather than instanced.
##
## `ShelfDisplay.PriceTag` is a Control and these are drawn inside a BaseButton's
## own `_draw` -- adding a child would put a node between the pointer and the
## machine it is trying to press. The card is thirty rectangles; the node is not
## worth the hit-test it costs.
func _tag(w: float, top: float, text: String, live: bool) -> void:
	var f := UITheme.pixel_font()
	var nose := 8.0
	var tw := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		UITheme.FS_SMALL).x
	var cw := nose + 10.0 + tw
	var x0 := (w - cw) * 0.5
	var card := CARD if live else CARD_DIM
	var ink := INK if live else INK_DIM
	var mid := TAG_H * 0.5

	draw_rect(Rect2(x0 + 2.0, top + 2.0, cw - 1.0, TAG_H - 1.0),
		Color(SHADE.r, SHADE.g, SHADE.b, 0.5))
	draw_rect(Rect2(x0 + nose, top, cw - nose, TAG_H), card)
	# The point, stepped a row at a time: nothing here can trust a slope to land
	# on the pixel grid.
	var row := 0.0
	while row < TAG_H:
		var x0n := nose * absf(row + 0.5 - mid) / mid
		draw_rect(Rect2(x0 + floorf(x0n), top + row, nose - floorf(x0n) + 1.0, 1.0), card)
		row += 1.0
	draw_rect(Rect2(x0 + nose, top, cw - nose, 1.0), card.lightened(0.3))
	draw_rect(Rect2(x0 + nose - 2.0, top + mid - 1.5, 3.0, 3.0), Color("#100c08"))
	draw_string(f, Vector2(x0 + nose + 6.0, top + mid + 3.5), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, UITheme.FS_SMALL, ink)


## A row of pips on a machine's face: what it is going to work on.
func _gauge(at: Rect2, live: bool, ink: Color) -> void:
	if gauge.y <= 0:
		return
	draw_rect(at, DARK)
	draw_rect(at, PIPE, false, 1.0)
	var cells := maxi(1, gauge.y)
	var pw := (at.size.x - 3.0) / float(cells)
	for i in cells:
		if i >= gauge.x:
			break
		draw_rect(Rect2(at.position.x + 2.0 + float(i) * pw, at.position.y + 2.0,
			maxf(1.0, pw - 1.0), at.size.y - 4.0),
			ink if live else ink.lerp(DARK, 0.6))


## THE WELDING CART: a bottle, an arm and a torch. Spot repair.
func _weld(w: float, base: float, body: Color, live: bool) -> void:
	var cx := w * 0.5
	# The cart, on castors.
	draw_rect(Rect2(cx - 20.0, base - 24.0, 40.0, 24.0), body)
	draw_rect(Rect2(cx - 20.0, base - 24.0, 40.0, 1.0), BODY_LIT)
	draw_rect(Rect2(cx - 17.0, base, 5.0, 3.0), DARK)
	draw_rect(Rect2(cx + 12.0, base, 5.0, 3.0), DARK)
	# The gas bottle strapped to it.
	draw_rect(Rect2(cx - 16.0, base - 46.0, 13.0, 22.0), body.lerp(BODY_LIT, 0.3))
	draw_rect(Rect2(cx - 16.0, base - 46.0, 13.0, 1.0), BODY_LIT)
	draw_rect(Rect2(cx - 16.0, base - 36.0, 13.0, 2.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.5))
	# The arm, and the torch on the end of it.
	draw_rect(Rect2(cx + 2.0, base - 52.0, 3.0, 28.0), PIPE)
	draw_rect(Rect2(cx + 2.0, base - 52.0, 16.0, 3.0), PIPE)
	draw_rect(Rect2(cx + 16.0, base - 52.0, 3.0, 8.0), body)
	# THE SPARK AT THE TORCH only when there is no ship to put it on. With a hull
	# in the berth the spark is drawn where the arm meets the plate instead --
	# see `_reach` -- because that is where welding happens.
	if live and hull.size.x <= 0.0:
		draw_rect(Rect2(cx + 16.0, base - 43.0, 3.0, 3.0), HOT)
		draw_rect(Rect2(cx + 15.0, base - 41.0, 5.0, 2.0), Color(HOT.r, HOT.g, HOT.b, 0.35))
	_gauge(Rect2(cx - 1.0, base - 20.0, 19.0, 8.0), live, LIVE)


## THE REPAIR GANTRY: an A-frame with a jack. Every missing point of hull.
func _gantry(w: float, base: float, body: Color, live: bool) -> void:
	var cx := w * 0.5
	var top := base - 60.0
	# Two legs and a head beam.
	draw_rect(Rect2(cx - 24.0, top, 48.0, 5.0), body)
	draw_rect(Rect2(cx - 24.0, top, 48.0, 1.0), BODY_LIT)
	for lx in [cx - 22.0, cx + 18.0]:
		draw_rect(Rect2(lx, top + 5.0, 4.0, base - top - 5.0), body)
		draw_rect(Rect2(lx, top + 5.0, 1.0, base - top - 5.0), BODY_LIT)
		draw_rect(Rect2(lx - 3.0, base - 3.0, 10.0, 3.0), body.lerp(DARK, 0.3))
	# A cross-brace, because a frame this tall would have one.
	draw_rect(Rect2(cx - 20.0, base - 26.0, 40.0, 2.0), body)
	# The hoist: a block on a chain inside the frame.
	draw_rect(Rect2(cx - 1.0, top + 5.0, 2.0, 16.0), PIPE)
	draw_rect(Rect2(cx - 7.0, top + 21.0, 14.0, 10.0), body.lerp(BODY_LIT, 0.35))
	draw_rect(Rect2(cx - 7.0, top + 21.0, 14.0, 1.0), BODY_LIT)
	if live:
		draw_rect(Rect2(cx - 4.0, top + 24.0, 8.0, 2.0), LIVE)
	_gauge(Rect2(cx - 17.0, base - 20.0, 34.0, 8.0), live, LIVE)


## THE FUEL BOWSER: a tank on a chassis with a hose off it.
func _bowser(w: float, base: float, body: Color, live: bool) -> void:
	var cx := w * 0.5
	# The chassis and its wheels.
	draw_rect(Rect2(cx - 24.0, base - 12.0, 48.0, 12.0), body.lerp(DARK, 0.25))
	draw_rect(Rect2(cx - 19.0, base, 6.0, 3.0), DARK)
	draw_rect(Rect2(cx + 13.0, base, 6.0, 3.0), DARK)
	# The tank, lying on its side, with a band round it.
	draw_rect(Rect2(cx - 22.0, base - 38.0, 44.0, 26.0), body)
	draw_rect(Rect2(cx - 22.0, base - 38.0, 44.0, 1.0), BODY_LIT)
	draw_rect(Rect2(cx - 22.0, base - 38.0, 1.0, 26.0), BODY_LIT)
	draw_rect(Rect2(cx - 5.0, base - 38.0, 3.0, 26.0), Color(SHADE.r, SHADE.g, SHADE.b, 0.45))
	# The filler neck. The hose off it is drawn in `_reach`, to the ship, when
	# there is a ship; without one it hangs in a loop to the deck.
	draw_rect(Rect2(cx + 14.0, base - 46.0, 4.0, 9.0), PIPE)
	if hull.size.x <= 0.0:
		draw_rect(Rect2(cx + 17.0, base - 46.0, 8.0, 3.0), PIPE)
		draw_rect(Rect2(cx + 23.0, base - 44.0, 3.0, 20.0), PIPE)
		draw_rect(Rect2(cx + 20.0, base - 25.0, 6.0, 3.0), PIPE)
	if live:
		draw_rect(Rect2(cx + 14.0, base - 49.0, 4.0, 3.0), LIVE)
	_gauge(Rect2(cx - 18.0, base - 32.0, 25.0, 9.0), live, HOT)


## THE FAULT POST: a diagnostic pillar with a beacon on top.
func _post(w: float, base: float, body: Color, live: bool) -> void:
	var cx := w * 0.5
	draw_rect(Rect2(cx - 13.0, base - 50.0, 26.0, 50.0), body)
	draw_rect(Rect2(cx - 13.0, base - 50.0, 26.0, 1.0), BODY_LIT)
	draw_rect(Rect2(cx - 17.0, base - 4.0, 34.0, 4.0), body.lerp(DARK, 0.3))
	# The screen, and three lines of nothing in particular on it.
	var scr := Rect2(cx - 9.0, base - 44.0, 18.0, 16.0)
	draw_rect(scr, DARK)
	draw_rect(scr, PIPE, false, 1.0)
	if live:
		for i in 3:
			draw_rect(Rect2(scr.position.x + 3.0, scr.position.y + 3.0 + float(i) * 4.0,
				12.0 - float(i) * 3.0, 2.0), Color(BAD.r, BAD.g, BAD.b, 0.8))
	# The beacon: the only thing in the bay that is a warning rather than a light.
	draw_rect(Rect2(cx - 4.0, base - 56.0, 8.0, 6.0),
		BAD if live else BAD.lerp(DARK, 0.6))
	draw_rect(Rect2(cx - 5.0, base - 57.0, 10.0, 1.0), body)
	if live:
		draw_rect(Rect2(cx - 9.0, base - 54.0, 18.0, 2.0), Color(BAD.r, BAD.g, BAD.b, 0.22))
