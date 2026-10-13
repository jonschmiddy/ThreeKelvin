class_name ThrusterFx
extends RefCounted

## A STEADY ENGINE FLAME DRAWN IN CODE, from the overload death's plume (Oct 13).
##
## Jon saw the plume in the F OVERLOAD enemy death and wanted it as the normal
## engine flame, side by side with the PixelLab strips. This is the MOCKUP for
## that pick: nothing live draws it yet. `-- sheet=ThrusterSheet` films it.
##
## COPIED, NOT SHARED. `_hull_pic` (its mask half), `_engines` and the plume
## builder are copies of ShipBreakup's (branch fx/deaths), because that file is
## not on main and its owner is still working in it. When both land, ShipBreakup's
## `_plume_tex` should become `ThrusterFx.plume_image` with Look.OVERLOAD and its
## `_engines` should call `ThrusterFx.engines` -- one helper, two callers. The
## differences from the death's copy, each on purpose:
##   - one picture per NOZZLE per length, not one for all engine points, so each
##     engine can flicker on its own;
##   - the 2x2 Bayer is read in CANVAS coordinates, not the plume's own. A plume
##     streaming left grows its box to the left, so a plume-local pattern would
##     flip parity every time the length changed by one pixel: the whole dithered
##     tail would crawl on every flicker step. Fixed to the ship, it holds;
##   - the plume is cut out wherever the hull is opaque, so the flame can be
##     drawn as ONE additive layer over the finished ship and still never paints
##     over plating. Today's strips need a `back` flag and a draw order for that
##     (HullData.thrusters, "kept off the hull plate"); this needs neither;
##   - on a rigged hull each stream starts at the strip's own attach pixels and
##     the hull blocks it except where the strip itself burns through (see
##     `for_hull`);
##   - `_engines` keeps only points on the hull's back EDGE for a steady flame:
##     the death's lit-pixel test also catches warm windows and stripes, and a
##     flame streaming out of a window is fine in an explosion and absurd at rest.
##
## THE LIFE. The bands are held; only the LENGTH moves, by one or two pixels, in
## held steps a few times a second on one clock per ship (a quarter to two fifths
## of a second each, irregular so it is not a metronome). Never every frame: at
## five or more changes a second the steps fuse into jitter (memory: judge
## animation per second). Not every engine changes on every step, so a ship
## with three never pulses as one.

enum Look { OVERLOAD, DRIVE, SPILL }
enum Thrust { IDLE, CRUISE, FULL }

const LOOK_NAMES := ["A  OVERLOAD", "B  DRIVE", "C  SPILL"]
const LOOK_BLURB := [
	"The overload's own plume as it is: four held heat bands, white core to red, the outer two dithered.",
	"A tighter jet with bright knots held along its axis: blue-white for your drive, the warm ramp for theirs.",
	"A short, dense flame, and its light spilled onto the hull's own stern so the engine sits in the ship.",
]
const THRUST_NAMES := ["IDLE", "CRUISE", "FULL"]

## COPIED from ShipBreakup.HEAT_RAMP: white core, yellow, orange, red, ember, soot-red.
const HEAT_RAMP: Array[Color] = [Color("#fff6e2"), Color("#ffdca0"), Color("#ffa63c"),
	Color("#cc641c"), Color("#964214"), Color("#5c280c")]
## B's drive for the player: the same four steps, cold.
const COOL_RAMP: Array[Color] = [Color("#f2fbff"), Color("#bfe2ff"), Color("#5ea6ff"),
	Color("#2c58c8")]

## Plume length as a share of the hull's ink width, per thrust. The overload grew
## to 28 px on a 187 px pool ship (0.15); idle sits well under it, full past it.
const THRUST_K: Array[float] = [0.06, 0.12, 0.20]
## How far the length wanders, in px, per thrust.
const FLICK: Array[int] = [1, 2, 2]
const HOLD_MIN := 0.24
const HOLD_MAX := 0.42
const STEPS := 48

## Per look: falloff exponent, widening per px, length factor, and the four band
## thresholds with their levels. A is the overload's numbers exactly.
const SHAPE := {
	Look.OVERLOAD: {expo = 1.3, spread = 0.12, len = 1.0, thr = [0.72, 0.48, 0.28, 0.12],
		lv = [1.0, 0.8, 0.55, 0.4], dith = [1.0, 1.0, 0.75, 0.5]},
	Look.DRIVE: {expo = 0.9, spread = 0.06, len = 1.15, thr = [0.74, 0.5, 0.3, 0.14],
		lv = [1.0, 0.85, 0.6, 0.42], dith = [1.0, 1.0, 0.75, 0.5]},
	Look.SPILL: {expo = 0.6, spread = 0.2, len = 0.6, thr = [0.7, 0.45, 0.25, 0.1],
		lv = [1.0, 0.85, 0.65, 0.42], dith = [1.0, 1.0, 1.0, 0.5]},
}
const BAYER: Array[float] = [0.0, 0.5, 0.75, 0.25]

var look: int = Look.OVERLOAD
## Warm ramp (enemies, and A and C for everyone) or cold (B on the player).
var warm: bool = true
## Each nozzle: {pts: PackedVector2Array (first air pixel per row, canvas px), dir: +1 or -1}.
var nozzles: Array = []
var ink_w: int = 0

var _w := 0
var _h := 0
var _solid := PackedByteArray()   ## 1 where the hull is opaque, over the whole canvas
var _cache := {}                  ## Vector3i(nozzle, L, loop frame) -> {tex, at}
var _spill := {}                  ## thrust -> {tex, at}
var _hold := PackedFloat32Array() ## step start times, STEPS of them, then the loop length
var _offs: Array = []             ## [step] -> PackedInt32Array, one -1..1 per nozzle
var _loop := 1.0
var _seed := 0
## THE DIALS of the living flame: loop frames a second (0 is the calm flame of
## the first round, length steps only) and raggedness (tongue size, ember
## rate, breathing). "lively" is 8 fps / 1.0, "wild" 12 fps / 1.8.
var fps := 8.0
var rag := 1.0
const LOOP := 8
## THE DYNAMIC FLAME (Jon picked A at the lively speed, Oct 13, then: "I want
## it to be more visually dynamic" and "more sparks and fire coming off the
## back"). `dynamic` swaps in the bigger frame loop (`_frame`, `_stream`):
## 2-4 licks a frame and longer, sometimes a forked tip, band edges moving 1-2
## px, the length breathing 2-3 px with the odd surge, the outline wobbling a
## pixel side to side along its length, over `loop_n` (12) frames so the loop
## does not read as repeating. `particles` adds sparks and torn-off fire
## (`particles_at`). Both off is the lively flame as filmed before.
var dynamic := false
var particles := false
var loop_n := LOOP
## Particles a second per engine, per thrust.
const SPARK_RATE: Array[float] = [6.0, 16.0, 24.0]
const BLOB_RATE: Array[float] = [1.5, 4.0, 6.0]
## The ragged clumps a fire blob is drawn as, by size (1-4 px across).
const CLUMPS := [
	[Vector2i(0, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 0), Vector2i(1, -1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, -1),
		Vector2i(3, 0), Vector2i(1, 2), Vector2i(-1, 0)],
]
## What the particles cost, summed over every `draw`, for the harness.
var particle_us := 0
var particle_px := 0
var _tails := {}
## The picture a found engine's rim rows are read off (for_sprite).
var _pic: Image = null


# ------------------------------------------------------------------ making one

## A player hull: the nozzles are its RIGGED thrusters (HullData.thrusters).
## `img` is the hull picture drawn at canvas (0, 0).
##
## THE FLAME LEAVES WHERE THE PIXELLAB FLAME LEAVES (Jon, Oct 13: "the coded
## thrusters should emanate from the same place the pixellab thrusters
## emanate from"). Each nozzle is the strip's own attach end: the column its
## frames end on (the most common last column, frame by frame) and the rows lit
## there in at least half the frames, at exactly those canvas pixels; for a
## `back` strip, the column and rows where it first shows past the plating
## (behind the hull it is hidden, so that is where it is seen to leave). If that
## is a point, the flame starts as a point and gets its body by widening: a
## nozzle under ten rows widens up to 3x faster (`widen`), so heavy S's 4-row
## apex is not a needle at full burn.
## A first try walked heavy S's start out to its cavity's mouth at the dome's
## base, and every look then engulfed the dome and read as pasted on.
##
## Nor does it draw over any hull pixel the strip leaves visible: the hull
## blocks the flame everywhere except where a FRONT strip covers it in every
## frame (the channel the PixelLab flame itself burns through). A `back` strip
## covers nothing, so its flame shows only where the hull ends, as today.
## `ThrusterSheet` checks both against the strips (`starts`).
static func for_hull(h: HullData, img: Image, the_look: int, seed: int) -> ThrusterFx:
	var fx := ThrusterFx.new()
	fx._take_canvas(img)
	fx.look = the_look
	fx.warm = the_look != Look.DRIVE
	var n := maxi(1, h.exhaust_frames)
	# Every strip's flame axis (open space only) and size, first: a mouth goes
	# to the strip nearest it, and the hull's biggest strip is its MAIN drive.
	var axes: Array = []
	var strip_h := {}
	var main_h := 0
	for tj in h.thrusters.size():
		var e0: Dictionary = h.thrusters[tj]
		var t0: Texture2D = e0.get("tex")
		if t0 == null:
			continue
		var im0 := t0.get_image()
		if im0.is_compressed():
			im0.decompress()
		im0.convert(Image.FORMAT_RGBA8)
		var fw0 := im0.get_width() / n
		var at0: Vector2i = e0.at
		var ys := 0.0
		var cnt := 0
		for f0 in n:
			for x0 in fw0:
				for y0 in im0.get_height():
					if im0.get_pixel(f0 * fw0 + x0, y0).a > 0.5 and not _px_solid(img, at0.x + x0, at0.y + y0):
						ys += float(y0)
						cnt += 1
		if cnt > 0:
			axes.append([tj, float(at0.y) + ys / float(cnt)])
		strip_h[tj] = im0.get_height()
		main_h = maxi(main_h, im0.get_height())
	for ti in h.thrusters.size():
		var e: Dictionary = h.thrusters[ti]
		var tex: Texture2D = e.get("tex")
		if tex == null:
			continue
		var strip := tex.get_image()
		if strip.is_compressed():
			strip.decompress()
		strip.convert(Image.FORMAT_RGBA8)
		var fw := strip.get_width() / n
		var sh := strip.get_height()
		var at: Vector2i = e.at
		# The channel: hull pixels a front strip paints over in EVERY frame. Kept
		# per engine too: a channel deep enough is a BELL (heavy S's stern cavity)
		# that the flame has to fill, not just pass down the middle of.
		var cells := PackedVector2Array()
		if not bool(e.get("back", false)):
			for y in sh:
				for x in fw:
					var all := true
					for i in n:
						if strip.get_pixel(i * fw + x, y).a <= 0.5:
							all = false
							break
					var cx := at.x + x
					var cy := at.y + y
					if all and cx >= 0 and cy >= 0 and cx < fx._w and cy < fx._h:
						if fx._solid[cy * fx._w + cx] == 1:
							cells.append(Vector2(cx, cy))
						fx._solid[cy * fx._w + cx] = 0
		# The start: each frame's last column holding a strip pixel that SHOWS
		# (a `back` strip's pixels under the plating do not), the most common one
		# over the frames, and the rows showing there in at least half of them.
		# For a front strip that is its attach end; for a back strip it is where
		# the flame comes out from behind the hull, already as wide as it is there.
		var back := bool(e.get("back", false))
		var votes := {}
		for i2 in n:
			var last := -1
			for x2 in fw:
				for y2 in sh:
					if strip.get_pixel(i2 * fw + x2, y2).a > 0.5 and not (back and _px_solid(img, at.x + x2, at.y + y2)):
						last = x2
			if last >= 0:
				votes[last] = int(votes.get(last, 0)) + 1
		if votes.is_empty():
			continue
		var xr := -1
		for k in votes:
			if xr < 0 or int(votes[k]) > int(votes[xr]) or (int(votes[k]) == int(votes[xr]) and int(k) > xr):
				xr = int(k)
		var rows := PackedInt32Array()
		for y3 in sh:
			if back and _px_solid(img, at.x + xr, at.y + y3):
				continue
			var lit := 0
			for i3 in n:
				if strip.get_pixel(i3 * fw + xr, y3).a > 0.5:
					lit += 1
			if lit * 2 >= n:
				rows.append(y3)
		if rows.is_empty():
			continue
		# THE ENGINE'S SIZE (Jon, Oct 13, on the gallery: "the exhaust of these
		# looks too small on the main body"). The rows the strip starts on are its
		# narrowest; the flame he is used to is as tall as the engine. So measure
		# the strip: how tall its visible flame is 2-6 px out from the start, the
		# middle frame's worth (and its tallest anywhere, for the record). The
		# coded flame starts that tall, centred on the same axis, at the same
		# column; a row the start column has under plating walks out to open
		# space (at most 6 px), as an override's rows do.
		var spans: Array = []
		var max_h := 0
		var n_lo := 1 << 20
		var n_hi := -1
		var ysum := 0.0
		var ycnt := 0
		for i5 in n:
			var r0 := 1 << 20
			var r1 := -1
			var a0 := 1 << 20
			var a1 := -1
			for x5 in fw:
				for y5 in sh:
					if strip.get_pixel(i5 * fw + x5, y5).a <= 0.5:
						continue
					# only flame in open space counts: a front strip painted over
					# plating it does not always cover is drawing on the hull, which
					# the coded flame never does
					if fx._is_solid(at.x + x5, at.y + y5):
						continue
					a0 = mini(a0, y5)
					a1 = maxi(a1, y5)
					ysum += float(y5)
					ycnt += 1
					var out := xr - x5
					if out >= 2 and out <= 6:
						r0 = mini(r0, y5)
						r1 = maxi(r1, y5)
						n_lo = mini(n_lo, y5)
						n_hi = maxi(n_hi, y5)
			if r1 >= r0:
				spans.append(r1 - r0 + 1)
			if a1 >= a0:
				max_h = maxi(max_h, a1 - a0 + 1)
		spans.sort()
		var near_h: int = spans[spans.size() / 2] if not spans.is_empty() else rows.size()
		var target := maxi(near_h, rows.size())
		# THE AXIS is where the strip's flame centres -- every visible pixel, every
		# frame -- not the middle of its start rows. A back strip shows first at
		# the TOP of a slanted or rounded stern, so its start rows sat 4-5 px
		# above the flame (light A 47 against 51.8, medium B 65.5 against 70.6,
		# heavy C 95 against 99.6); heavy A's front strips start 2 px high. Jon:
		# "flame slightly too high".
		var centre := float(rows[0] + rows[-1]) * 0.5
		if ycnt > 0:
			centre = ysum / float(ycnt)
		# THE MOUTHS, read off the hull's own pixels (Oct 13). The stern edge is
		# found row by row from well behind the strip's start (the first try began
		# 3 px in front of it, and every nozzle sticking further out than that read
		# as one flat face: light A's three stacked nozzles became one big flame).
		# A MOUTH is a local minimum of that edge -- rows standing furthest out,
		# with the edge receding above and below -- grown to the rows within 1 px
		# of it. Every mouth in the strip's own flame band that this strip is the
		# nearest to, and that stands within 6 px of the furthest one, is an
		# engine: three stacked nozzles are three flames, which merge after they
		# leave. One mouth at least as tall as the strip's flame (read across small
		# bumps) is a FLAT STERN, and the strip's height sets the start (heavy C,
		# heavy B). A shallow bell (a front strip lapping its nozzle by a few px)
		# is a nozzle like any other; only a deep one (heavy S's cavity) keeps the
		# bell's own shape.
		var start_col: int = at.x + xr
		var axis_y := int(round(float(at.y) + centre))
		var band_lo := at.y + (n_lo if n_lo <= n_hi else rows[0]) - 2
		var band_hi := at.y + (n_hi if n_lo <= n_hi else rows[-1]) + 2
		var edge := {}
		for yy in range(mini(band_lo, axis_y - 16) - 4, maxi(band_hi, axis_y + 16) + 5):
			for xx in range(start_col - 24, start_col + 31):
				if _px_solid(img, xx, yy):
					edge[yy] = xx
					break
		var mouths: Array = []       # [lo, hi, min edge]
		var y6 := band_lo
		while y6 <= band_hi:
			if not edge.has(y6):
				y6 += 1
				continue
			var v := int(edge[y6])
			var y7 := y6
			while edge.has(y7 + 1) and int(edge[y7 + 1]) == v:
				y7 += 1
			var up_ok := (not edge.has(y6 - 1)) or int(edge[y6 - 1]) > v
			var dn_ok := (not edge.has(y7 + 1)) or int(edge[y7 + 1]) > v
			if up_ok and dn_ok:
				var a6 := y6
				var b6 := y7
				while edge.has(a6 - 1) and int(edge[a6 - 1]) <= v + 1:
					a6 -= 1
				while edge.has(b6 + 1) and int(edge[b6 + 1]) <= v + 1:
					b6 += 1
				# INSIDE THE OUTLINE: a row at either end whose 4 px from the edge
				# into the hull are all dark is the nozzle's rim drawn as a line,
				# not its opening (light B's top pipe: 9 rows with its two rim
				# rows, 7 inside them)
				# (a rim is a dark line against a lighter inside: on a hull dark all
				# through, no row is a rim)
				while b6 - a6 >= 2 and _rim_row(img, int(edge[a6]), a6, 1) and not _rim_row(img, int(edge[a6 + 1]), a6 + 1, 1):
					a6 += 1
				while b6 - a6 >= 2 and _rim_row(img, int(edge[b6]), b6, 1) and not _rim_row(img, int(edge[b6 - 1]), b6 - 1, 1):
					b6 -= 1
				mouths.append([a6, b6, v])
			y6 = y7 + 1
		var front := 1 << 20
		for m in mouths:
			front = mini(front, int(m[2]))
		var kept: Array = []
		for m2 in mouths:
			if int(m2[2]) > front + 6:
				continue
			var mc := float(int(m2[0]) + int(m2[1])) * 0.5
			var mine := true
			for ax2 in axes:
				if int(ax2[0]) != ti and absf(float(ax2[1]) - mc) < absf(float(at.y) + centre - mc):
					mine = false
			if mine:
				kept.append(m2)
		var deep_bell := false
		var bell := _bell(cells, at.x + xr)
		if not bell.is_empty() and int(bell.depth) >= 10:
			deep_bell = true
		# flat or not, for one mouth: read across small bumps (a seam a row or
		# three standing out up to 4 px does not end a flat stern)
		var flat := kept.is_empty() or deep_bell
		if kept.size() == 1:
			var m3: Array = kept[0]
			var fa := int(m3[0])
			var fb := int(m3[1])
			var vv := int(m3[2])
			for step: int in [-1, 1]:
				var y5 := (fa if step < 0 else fb) + step
				var gap := 0
				while edge.has(y5) and gap <= 3:
					if int(edge[y5]) <= vv + 1:
						if step < 0:
							fa = y5
						else:
							fb = y5
						gap = 0
					elif int(edge[y5]) <= vv + 4:
						gap += 1
					else:
						break
					y5 += step
			flat = (fb - fa + 1) >= near_h
		var groups: Array = []       # each: {lo, hi (canvas rows), mouth}
		if flat:
			var lo_f := mini(at.y + rows[0], int(floor(float(at.y) + centre - float(target - 1) * 0.5)))
			groups.append({lo = lo_f, hi = maxi(at.y + rows[-1], lo_f + target - 1), mouth = 0})
		else:
			for m4 in kept:
				groups.append({lo = int(m4[0]), hi = int(m4[1]), mouth = int(m4[1]) - int(m4[0]) + 1})
		var is_main: bool = int(strip_h.get(ti, 0)) >= main_h
		for g in groups:
			var pts := PackedVector2Array()
			for cy4 in range(int(g.lo), int(g.hi) + 1):
				var cx4 := start_col
				var k4 := 0
				if fx._is_solid(cx4, cy4):
					# out of the plating (a nozzle standing proud of the start)
					while k4 <= 40 and fx._is_solid(cx4, cy4):
						cx4 -= 1
						k4 += 1
					if k4 > 40:
						continue
				elif not flat:
					# up to the nozzle (the start column is in air in front of it)
					while k4 < 10 and not fx._is_solid(cx4 + 1, cy4):
						cx4 += 1
						k4 += 1
				pts.append(Vector2(cx4, cy4))
			if pts.is_empty():
				continue
			var start_h := pts.size()
			var mouth_h := int(g.mouth)
			# A point of a nozzle widens faster, so it is not a needle; its start
			# stays where it is. The MAIN drive (the hull's biggest strip) grows to
			# the strip's body, shared between its nozzles, by a quarter of its
			# length off a flat stern and by half out of nozzles; a secondary
			# engine just spreads (Jon on light B's top pipe: "too big").
			var widen := clampf(10.0 / float(start_h), 1.0, 3.0)
			var size: int = near_h if (flat or is_main) else mini(near_h, mouth_h)
			var l_full := float(fx.ink_w) * THRUST_K[Thrust.FULL] * clampf(sqrt(float(size) / 8.0), 0.85, 1.8)
			if flat or is_main:
				var body := float(max_h) / float(maxi(1, groups.size()))
				var need := maxf(0.0, body - float(start_h)) * 0.5 / maxf(1.0, l_full * (0.25 if flat else 0.5))
				widen = clampf(maxf(widen, need / float(SHAPE[the_look].spread)), 1.0, 3.0)
			var nz := {pts = pts, dir = -1, thruster = ti, widen = widen, strip_near_h = near_h,
				strip_max_h = max_h, nozzle = not flat, mouth = [int(g.lo), int(g.hi)], start_ref = start_h if not flat else target,
				main = is_main}
			if deep_bell:
				nz.bell = bell
				fx._grow_mouth(bell, target)
			# LENGTH: the main drive's goes with its strip's size; a secondary
			# engine's with its own mouth (Jon: the top pipe's flame was "taller and
			# longer than that thin pipe nozzle can carry"). Sparks with the mouth.
			_size_nozzle(nz, size)
			if not flat:
				nz.pscale = clampf(float(start_h) / 8.0, 0.75, 2.5)
			fx.nozzles.append(nz)
	fx._plan(seed)
	return fx


## A ship picture with no rig (an enemy, a PixelLab pool ship): the nozzles are
## found the overload's way, `_engines`, then kept to the hull's back edge and
## split into engines. Enemies face left, so they burn to the right.
static func for_sprite(img: Image, used: Rect2i, the_look: int, seed: int, id: String = "",
		scale: float = 1.0, pic_at: Vector2i = Vector2i.ZERO) -> ThrusterFx:
	var fx := ThrusterFx.new()
	fx._take_canvas(img)
	fx._pic = img
	fx.look = the_look
	fx.warm = true
	# HAND-PLACED ENGINES first (art/engines.json): the six pictures whose
	# rearmost pixels are not an engine -- a towed rock, a dish rim, a scoop's
	# prong, fin and sail tips. `pic_at` is where the picture's (0, 0) sits on
	# `img`; `scale` is its size against the file the table was read off.
	var ov = engine_override(id)
	if ov != null:
		fx._override(ov as Array, pic_at, scale, img)
		fx.ink_w = used.size.x
		for nz0 in fx.nozzles:
			_size_nozzle(nz0, (nz0.pts as PackedVector2Array).size())
		fx._plan(seed)
		return fx
	var H := _hull_pic(img, used, 2)
	if int(H.n) == 0:
		return fx
	var raw_pts := engines(H)
	# Keep the back edge: a point inside the hull counts only if open space is
	# within three pixels behind it; it then streams from that first open pixel.
	var by_row := {}
	for p in raw_pts:
		var x := int(p.x)
		var y := int(p.y)
		var k := 0
		while k < 4 and fx._is_solid(x, y):
			x += 1
			k += 1
		if k >= 4:
			continue
		by_row[y] = maxi(int(by_row.get(y, -1)), x)
	var ys: Array = by_row.keys()
	ys.sort()
	var ink_h := used.size.y
	var cap := maxi(4, int(round(float(ink_h) * 0.16)))
	var run: Array = []
	for y2 in ys:
		if not run.is_empty() and (int(y2) - int(run[-1]) > 1
				or absi(int(by_row[y2]) - int(by_row[run[-1]])) > 3):
			fx._add_run(run, by_row, cap)
			run = []
		run.append(y2)
	fx._add_run(run, by_row, cap)
	fx.ink_w = used.size.x
	fx._keep_sternmost(used)
	for nz in fx.nozzles:
		_size_nozzle(nz, (nz.pts as PackedVector2Array).size())
	fx._plan(seed)
	return fx


## A STEADY FLAME COMES OUT OF THE STERN. The gallery of every ship (Oct 13)
## showed the death's detection lighting towers, hull bumps and spires half way
## along the body (the Honeycomb's pods, the Spires' masts, the Barnacle's
## turret): fine for a breakup, wrong for an engine. Keep only engines within
## 8% of the hull's length (at least 6 px) of its rearmost pixel, and drop a
## one-row sliver when there is anything else.
func _keep_sternmost(used: Rect2i) -> void:
	if nozzles.is_empty():
		return
	var stern := -(1 << 20)
	for nz in nozzles:
		for p in (nz.pts as PackedVector2Array):
			stern = maxi(stern, int(p.x))
	var reach := maxf(6.0, float(used.size.x) * 0.08)
	var kept: Array = []
	for nz2 in nozzles:
		var pts: PackedVector2Array = nz2.pts
		var x := 0.0
		for p2 in pts:
			x += p2.x
		x /= float(pts.size())
		if float(stern) - x <= reach:
			kept.append(nz2)
	var thick: Array = []
	for nz3 in kept:
		if (nz3.pts as PackedVector2Array).size() > 1:
			thick.append(nz3)
	nozzles = thick if not thick.is_empty() else kept


## art/engines.json, read once: picture id -> [{x, y0, y1}], or null when the
## finder is trusted for that picture. An empty list means no flame at all.
static var _overrides = null
const OVERRIDES_PATH := "res://art/engines.json"

static func engine_override(id: String):
	if id == "":
		return null
	if _overrides == null:
		_overrides = {}
		if FileAccess.file_exists(OVERRIDES_PATH):
			var d = JSON.parse_string(FileAccess.get_file_as_string(OVERRIDES_PATH))
			if d is Dictionary:
				_overrides = d
	var key := id.trim_suffix("_half").trim_suffix("_quarter")
	return _overrides.get(key, null)


## Engines from the table: each row of each entry finds the hull's back edge
## from its column -- forward through plating to the first open pixel, or back
## through open space to the plating, at most 12 px -- and the flame starts
## there; a row that never finds one (a tow cable running on) is left out.
func _override(list: Array, at: Vector2i, scale: float, img: Image = null) -> void:
	for e in list:
		var d: Dictionary = e
		var pts := PackedVector2Array()
		var y0 := int(floor(float(d.y0) * scale))
		var y1 := int(floor(float(d.y1) * scale))
		for y in range(y0, y1 + 1):
			var x := at.x + int(floor(float(d.x) * scale))
			var cy := at.y + y
			var k := 0
			if _is_solid(x, cy):
				# through the plating to the first open pixel
				while k <= 12 and _is_solid(x, cy):
					x += 1
					k += 1
			else:
				# back through open space to the plating, so the flame starts on
				# the hull and not in the air beside it
				while k <= 12 and not _is_solid(x - 1, cy):
					x -= 1
					k += 1
			if k > 12:
				continue
			# FLUSH WITH THE NOZZLE (Jon on the domes ship: "Doesn't quite fit
			# nozzle"): most of these pictures end in a 1 px dark outline, and a
			# flame starting past it reads as starting a pixel off the engine.
			# Where the last hull pixel is that outline, the flame starts on it.
			pts.append(Vector2(x, cy))
		# INSIDE THE OUTLINE first, then onto it: the rim rows at either end
		# go (they are not the opening), and each remaining row may start ON
		# the outline's dark column, flush with the nozzle (the domes ship)
		pts = _trim_rim(img, pts)
		for k5 in pts.size():
			var p5 := pts[k5]
			var x5 := int(p5.x)
			var y5 := int(p5.y)
			if img != null and _is_solid(x5 - 1, y5) and img.get_pixel(x5 - 1, y5).get_luminance() < 0.2:
				_solid[y5 * _w + x5 - 1] = 0
				pts[k5] = Vector2(x5 - 1, y5)
		if not pts.is_empty():
			var nzo := {pts = pts, dir = 1, behind = bool(d.get("behind", false)),
				widen = float(d.get("widen", 1.0))}
			# A `behind` flame passes behind what is in its way instead of
			# stopping (the orbit-arm ship's drive, behind its end weight -- Jon:
			# "go BEHIND the middle pod"), and its length is measured from the far
			# side of it, so it reads as the main drive past the weight.
			if nzo.behind:
				nzo.over_span = _blocked_span(pts[pts.size() / 2], 1)
			nozzles.append(nzo)


## A bell's mouth at least as tall as its engine (`target` rows, centred): a
## strip that laps the stern by a few pixels makes a shallow bell whose mouth
## is only the rows it always covers, and the flame left it thinner than the
## strip it replaces. Each added row walks out to open space from the mouth's
## column, at most 10 px.
func _grow_mouth(bell: Dictionary, target: int) -> void:
	var mouth: PackedVector2Array = bell.mouth
	if mouth.size() >= target or mouth.is_empty():
		return
	var y0 := int(mouth[0].y)
	var y1 := int(mouth[-1].y)
	var mx := 0.0
	var have := {}
	for p in mouth:
		mx += p.x
		have[int(p.y)] = true
	var x0 := int(round(mx / float(mouth.size())))
	var lo := int(floor(float(y0 + y1) * 0.5 - float(target - 1) * 0.5))
	var out := PackedVector2Array()
	for y in range(mini(lo, y0), maxi(lo + target - 1, y1) + 1):
		if have.has(y):
			for p2 in mouth:
				if int(p2.y) == y:
					out.append(p2)
			continue
		var x := x0
		var k := 0
		while k <= 10 and _is_solid(x, y):
			x -= 1
			k += 1
		if k <= 10:
			out.append(Vector2(x, y))
	bell.mouth = out


## The rim rows off either end of a left-facing engine's rows (`_rim_row`, the
## hull to the left of each row's first open pixel), keeping at least 2.
func _trim_rim(img: Image, pts: PackedVector2Array) -> PackedVector2Array:
	if img == null or pts.size() <= 2:
		return pts
	var a := 0
	var b := pts.size() - 1
	# a rim is a dark line against a lighter inside: on a hull dark all through
	# (the dome market's stern), no row is a rim
	while b - a >= 2 and _rim_row(img, int(pts[a].x) - 1, int(pts[a].y), -1) 			and not _rim_row(img, int(pts[a + 1].x) - 1, int(pts[a + 1].y), -1):
		a += 1
	while b - a >= 2 and _rim_row(img, int(pts[b].x) - 1, int(pts[b].y), -1) 			and not _rim_row(img, int(pts[b - 1].x) - 1, int(pts[b - 1].y), -1):
		b -= 1
	return pts.slice(a, b + 1)


## One engine from a run of stern rows. A tall flat stern is not one tall engine:
## keep the rows that stand furthest back (the bells), then the middle `cap`.
func _add_run(run: Array, by_row: Dictionary, cap: int) -> void:
	if run.is_empty():
		return
	# SEPARATE MOUTHS ARE SEPARATE ENGINES (Oct 13, light A's three stacked
	# nozzles): the rows standing furthest back, each a local maximum of the
	# stern edge with the edge receding on both sides, within 6 px of the
	# furthest, each grown to the rows within 1 px of it. Two or more is that
	# many engines; one falls through to the rule below.
	var mouths: Array = []
	var i := 0
	while i < run.size():
		var v := int(by_row[run[i]])
		var j := i
		while j + 1 < run.size() and int(by_row[run[j + 1]]) == v and int(run[j + 1]) == int(run[j]) + 1:
			j += 1
		var up_ok := i == 0 or int(by_row[run[i - 1]]) < v
		var dn_ok := j == run.size() - 1 or int(by_row[run[j + 1]]) < v
		if up_ok and dn_ok:
			var a := i
			var b := j
			while a - 1 >= 0 and int(by_row[run[a - 1]]) >= v - 1:
				a -= 1
			while b + 1 < run.size() and int(by_row[run[b + 1]]) >= v - 1:
				b += 1
			mouths.append([a, b, v])
		i = j + 1
	var far := -(1 << 20)
	for m in mouths:
		far = maxi(far, int(m[2]))
	# at least 3 rows (a 2-row step is a seam, not a nozzle), and never two
	# mouths over the same rows
	var real: Array = []
	var taken := {}
	for m2 in mouths:
		if int(m2[2]) < far - 6 or int(m2[1]) - int(m2[0]) + 1 < 3:
			continue
		var clash := false
		for k0 in range(int(m2[0]), int(m2[1]) + 1):
			if taken.has(k0):
				clash = true
		if clash:
			continue
		for k1 in range(int(m2[0]), int(m2[1]) + 1):
			taken[k1] = true
		real.append(m2)
	if real.size() >= 2:
		for m3 in real:
			var pts0 := PackedVector2Array()
			for k in range(int(m3[0]), int(m3[1]) + 1):
				pts0.append(Vector2(int(by_row[run[k]]), int(run[k])))
			nozzles.append({pts = _trim_rim(_pic, pts0), dir = 1})
		return
	var keep: Array = run
	if run.size() > cap:
		var mx := -1
		for y in run:
			mx = maxi(mx, int(by_row[y]))
		keep = []
		for y2 in run:
			if int(by_row[y2]) >= mx - 1:
				keep.append(y2)
		if keep.size() > cap:
			var mid := keep.size() / 2
			keep = keep.slice(mid - cap / 2, mid - cap / 2 + cap)
	var pts := PackedVector2Array()
	for y3 in keep:
		pts.append(Vector2(int(by_row[y3]), int(y3)))
	nozzles.append({pts = _trim_rim(_pic, pts), dir = 1})


## A nozzle's rim drawn as a dark line: the 4 px from the hull's edge `x` into
## the hull (`into` +1: rightwards, a player hull; -1: leftwards, a ship facing
## left) all darker than 0.15.
static func _rim_row(img: Image, x: int, y: int, into: int) -> bool:
	if img == null:
		return false
	for k in 4:
		var xx := x + k * into
		if xx < 0 or y < 0 or xx >= img.get_width() or y >= img.get_height():
			return false
		var c := img.get_pixel(xx, y)
		if c.a > 0.5 and c.get_luminance() >= 0.15:
			return false
	return true


static func _px_solid(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and img.get_pixel(x, y).a > 0.5


## A BELL: the hull pixels a front strip always covers, when they run at least
## four columns back from the apex (heavy S's stern cavity; a strip that only
## laps the hull's edge by a pixel has none). Today's PixelLab flame FILLS it,
## wall to wall, and leaves past the rim at the full mouth width. Returns
## {cells, depth (columns from the apex to the furthest-out cell), mouth (one
## start per row: the first open pixel past that row's last cell)}, or {}.
static func _bell(cells: PackedVector2Array, apex_x: int) -> Dictionary:
	if cells.size() < 12:
		return {}
	var rim := 1 << 20
	for c in cells:
		rim = mini(rim, int(c.x))
	var depth := apex_x - rim
	if depth < 4:
		return {}
	var first := {}
	for c2 in cells:
		var y := int(c2.y)
		first[y] = mini(int(first.get(y, 1 << 20)), int(c2.x))
	var mouth := PackedVector2Array()
	var ys: Array = first.keys()
	ys.sort()
	# Every row's own last cell: the rim is curved (heavy S's is the dome's
	# edge), so a "within a pixel of the furthest-out cell" rule kept three
	# rows and the flame left the full bell as a thread.
	for y2 in ys:
		mouth.append(Vector2(int(first[y2]) - 1, int(y2)))
	return {cells = cells, depth = depth, mouth = mouth, apex = apex_x}


func _take_canvas(img: Image) -> void:
	_w = img.get_width()
	_h = img.get_height()
	_solid.resize(_w * _h)
	var x0 := _w
	var x1 := -1
	for y in _h:
		for x in _w:
			if img.get_pixel(x, y).a > 0.5:
				_solid[y * _w + x] = 1
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
	ink_w = maxi(0, x1 - x0 + 1)


func _is_solid(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < _w and y < _h and _solid[y * _w + x] == 1


## The flicker plan: STEPS held steps of irregular length, each engine's offset
## in -1..1 per step (times FLICK[thrust] when drawn). About half the engines
## move on a step; one that moves never lands where it was.
func _plan(seed: int) -> void:
	_seed = seed
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 6271 + 3
	_hold.resize(STEPS)
	var acc := 0.0
	var prev := PackedInt32Array()
	prev.resize(nozzles.size())
	_offs.clear()
	for s in STEPS:
		_hold[s] = acc
		acc += rng.randf_range(HOLD_MIN, HOLD_MAX)
		var o := prev.duplicate()
		var moved := false
		for n in o.size():
			if rng.randf() < 0.55 or (n == o.size() - 1 and not moved):
				var v := o[n]
				while v == o[n]:
					v = rng.randi_range(-1, 1)
				o[n] = v
				moved = true
		_offs.append(o)
		prev = o
	_loop = acc


# ------------------------------------------------------------------ reading it

## A BIG ENGINE THROWS A BIGGER FLAME: an engine's length goes with the square
## root of its height against an 8-row one (0.85x to 1.8x), and its sparks and
## fire with its height (0.75x to 2.5x). A bell (heavy S) keeps 1: its size is
## the bell's.
static func _size_nozzle(nz: Dictionary, h: int) -> void:
	nz.height = h
	if nz.has("bell"):
		nz.lscale = 1.0
		nz.pscale = clampf(float(h) / 8.0, 0.75, 2.5)
		return
	nz.lscale = clampf(sqrt(float(h) / 8.0), 0.85, 1.8)
	nz.pscale = clampf(float(h) / 8.0, 0.75, 2.5)


## Engine `n`'s own length at this thrust: the hull's length, scaled by the
## engine's size (`_size_nozzle`).
func nozzle_length(n: int, thrust: int) -> int:
	var nz: Dictionary = nozzles[n]
	return maxi(3, int(round(float(base_length(thrust)) * float(nz.get("lscale", 1.0))))) + int(nz.get("over_span", 0))


## How much hull an engine's middle row crosses after it first leaves the
## hull: the first solid run past open space, in px (0 if none within 400).
func _blocked_span(e: Vector2, dir: int) -> int:
	var seen := false
	var run := 0
	for d in 400:
		var x := int(e.x) + d * dir
		if _is_solid(x, int(e.y)):
			if seen:
				run += 1
		else:
			if run > 0:
				return run
			seen = true
	return run


func base_length(thrust: int) -> int:
	var s: Dictionary = SHAPE[look]
	return maxi(3, int(round(float(ink_w) * THRUST_K[thrust] * float(s.len))))


func step_at(t: float) -> int:
	var tt := fposmod(t, _loop)
	var lo := 0
	var hi := STEPS - 1
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if _hold[mid] <= tt:
			lo = mid
		else:
			hi = mid - 1
	return lo


## The length drawn. A LIVING flame (`fps` > 0) keeps its base length: its
## frames already breathe and lick. The CALM one (`fps` 0, the first round)
## wanders 1-2 px in held steps a few times a second.
func length_at(n: int, thrust: int, t: float) -> int:
	if fps > 0.0:
		return nozzle_length(n, thrust)
	var o: PackedInt32Array = _offs[step_at(t)]
	var amp := FLICK[thrust]
	if look == Look.SPILL:
		amp = maxi(1, amp - 1)
	return maxi(2, nozzle_length(n, thrust) + o[n] * amp)


## Which of the LOOP shapes engine `n` shows at `t`: held frames at `fps`, each
## engine's loop offset by three frames from the last so a multi-engine ship
## never pulses in unison.
func frame_at(n: int, t: float) -> int:
	if fps <= 0.0:
		return 0
	return posmod(int(floor(t * fps)) + n * 3 + _seed, loop_n)


func frames() -> int:
	return loop_n if fps > 0.0 else 1


## Every picture this thrust can ask for, built now rather than on first sight.
func warm_up(thrust: int) -> void:
	for n in nozzles.size():
		var b := nozzle_length(n, thrust)
		if fps > 0.0:
			for f in loop_n:
				plume(n, b, f)
		else:
			var amp := FLICK[thrust]
			for d in range(-amp, amp + 1):
				plume(n, maxi(2, b + d))
	if look == Look.SPILL:
		spill(thrust)


## Draw every engine at time `t`, the canvas's (0, 0) at `origin`, onto a canvas
## item that blends ADD (`add_material`). This is the whole per-frame cost: a
## frame lookup and one cached texture per engine.
func draw(ci: CanvasItem, origin: Vector2, thrust: int, t: float) -> void:
	if look == Look.SPILL:
		var sp := spill(thrust)
		if sp.tex != null:
			ci.draw_texture(sp.tex, origin + (sp.at as Vector2))
	for n in nozzles.size():
		var p := plume(n, length_at(n, thrust, t), frame_at(n, t))
		if p.tex != null:
			ci.draw_texture(p.tex, origin + (p.at as Vector2))
	if particles:
		var t0 := Time.get_ticks_usec()
		var s: Dictionary = SHAPE[look]
		var ramp := _ramp()
		for n2 in nozzles.size():
			for q in particles_at(n2, thrust, t):
				var band: int = q.band
				ci.draw_rect(Rect2(origin + Vector2(q.x, q.y), Vector2.ONE), _lv(ramp[band], float(s.lv[band]) * float(q.k)))
				particle_px += 1
		particle_us += Time.get_ticks_usec() - t0


static func add_material() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _ramp() -> Array[Color]:
	return HEAT_RAMP if warm else COOL_RAMP


static func _lv(c: Color, lvl: float) -> Color:
	return Color(c.r * lvl, c.g * lvl, c.b * lvl, 1.0)


# ------------------------------------------------------------------ the plume

## THE LIVING FLAME (Jon, Oct 13: "They still read as too still... they should
## be an active flame"; today's strips change ten times a second and that is
## the bar). Each engine cycles LOOP distinct shapes at `fps`, as held frames:
##   - the tail is ragged and different every frame: each row's tongue is its
##     own length, and one or two rows lick further out (`rag` scales both);
##   - the band edges shift a pixel along the flame (`shift`);
##   - the length breathes by up to 3 px, so the core with it (`dL`);
##   - now and then an ember breaks off the tail and fades over three frames.
## What never moves: the nozzle's start (d = 0 is always lit, whatever the
## frame), and inside heavy S's bell only the bands shift, gently.
## Pure in (engine, frame): the same frame is the same picture every loop.
func _frame(n: int, fr: int) -> Dictionary:
	if fps <= 0.0 or rag <= 0.0:
		return {dL = 0, shift = 0, bshift = 0, rows = 0, ember = {}}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([_seed, look, n, fr])
	var out := {}
	if dynamic:
		out.dL = rng.randi_range(-2, 3)
		if rng.randf() < 0.15:
			out.dL = rng.randi_range(4, 6)   # the surge frame
		out.shift = rng.randi_range(-2, 2)
		out.bshift = rng.randi_range(0, 2)
		out.rows = rng.randi() | 1
		out.wob = rng.randf() * TAU
		out.ember = {}
		return out
	var big := rag >= 1.5
	out.dL = rng.randi_range(-1, 1) * (2 if big else 1) + (rng.randi_range(0, 1) if big else 0)
	out.shift = rng.randi_range(-1, 1)
	out.bshift = rng.randi_range(0, 2)
	out.rows = rng.randi() | 1
	out.ember = {}
	if rng.randf() < clampf(0.35 * rag, 0.0, 0.8):
		out.ember = {row = rng.randf(), past = rng.randi_range(1, 3)}
	return out


## One engine's light at length `L` and loop frame `fr`, cached. The overload's
## `_plume_tex` with the changes listed at the top: light streams back from
## every point of the nozzle, falls off as pow(1 - d/(L+1), expo), widens by
## 1 px every 1/spread, overlaps take the max; then four held bands, the outer
## ones Bayer-thinned.
func plume(n: int, L: int, fr: int = 0) -> Dictionary:
	var key := Vector3i(n, L, fr)
	if _cache.has(key):
		return _cache[key]
	var s: Dictionary = SHAPE[look]
	var nz: Dictionary = nozzles[n]
	var dir: int = nz.dir
	var expo: float = s.expo
	var fp := _frame(n, fr)
	var Lf := maxi(2, L + int(fp.dL))
	# What lights: streams {pts, L, spk, gain} and fixed cells {x, y, v}.
	var streams: Array = []
	var fills: Array = []
	if nz.has("bell"):
		_bell_light(nz.bell, L, Lf, float(s.spread), streams, fills, fp)
	else:
		streams.append({pts = nz.pts, L = Lf, spk = float(s.spread) * float(nz.get("widen", 1.0)),
			behind = bool(nz.get("behind", false)), skip = int(nz.get("over_span", 0))})
	# Embers: one spawned this frame or either of the two before, carried a
	# further 2 px a frame and dimmer each time.
	if not streams.is_empty():
		var st0: Dictionary = streams[-1]
		var src: PackedVector2Array = st0.pts
		for j in 3:
			var ep: Dictionary = _frame(n, posmod(fr - j, loop_n)).ember
			if ep.is_empty() or src.is_empty():
				continue
			var row := clampi(int(float(ep.row) * float(src.size())), 0, src.size() - 1)
			var e0 := src[row]
			var reach := int(st0.L) + int(ep.past) + 2 * j
			var ev: float = [0.6, 0.4, 0.2][j]
			fills.append({x = int(e0.x) + reach * dir, y = int(e0.y), v = ev, air = true})
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for st in streams:
		var sl: int = int(round(float(st.L) * (1.0 + (1.0 if dynamic else 0.5) * rag))) + 2
		var sp := 3 + int(float(sl) * float(st.spk))
		for e in (st.pts as PackedVector2Array):
			var x2 := int(e.x) + sl * dir
			lo = Vector2i(mini(lo.x, mini(int(e.x), x2)), mini(lo.y, int(e.y) - sp))
			hi = Vector2i(maxi(hi.x, maxi(int(e.x), x2)), maxi(hi.y, int(e.y) + sp))
	for f in fills:
		lo = Vector2i(mini(lo.x, int(f.x)), mini(lo.y, int(f.y)))
		hi = Vector2i(maxi(hi.x, int(f.x)), maxi(hi.y, int(f.y)))
	if hi.x < lo.x:
		_cache[key] = {tex = null, at = Vector2i.ZERO}
		return _cache[key]
	var at := lo
	var W := hi.x - lo.x + 1
	var Hh := hi.y - lo.y + 1
	var buf := PackedFloat32Array()
	buf.resize(W * Hh)
	for f2 in fills:
		if f2.get("air", false) and _is_solid(int(f2.x), int(f2.y)):
			continue
		var i := (int(f2.y) - at.y) * W + (int(f2.x) - at.x)
		buf[i] = maxf(buf[i], float(f2.v))
	for st2 in streams:
		_stream(buf, W, Hh, at, st2.pts, int(st2.L), float(st2.spk), expo, dir,
			float(st2.get("gain", 1.0)), fp, bool(st2.get("behind", false)), int(st2.get("skip", 0)))
	var out := _quantize(buf, W, Hh, at, s)
	_cache[key] = out
	return out


## SPARKS AND FIRE OFF THE BACK (Jon: "more sparks and fire coming off the
## back"). Particles, not frames, so they never repeat with the loop, and
## STATELESS: particle i of engine n is born at a time, place and speed drawn
## from (ship seed, engine, kind, i), so any `t` can be drawn on its own and a
## film is the same every run.
##   sparks  bright single pixels shed along the TAIL (55-100% of its length,
##           never at the nozzle), flying back 1-2 px a frame (at 30 a second)
##           with a little drift, cooling white, yellow, orange, red over 4-8
##           frames;
##   fire    ragged 2-4 px clumps torn off the tail tip, drifting back slower,
##           cooling and shrinking over 6-10 frames.
## The heat ramp and the look's own levels and dither (the canvas's Bayer, so
## the pattern is the ship's). A pixel on the hull is never drawn: they fly
## into the open space behind the ship. On heavy S they leave past the rim.
## Returns [{x, y, band, k}] in canvas pixels.
func particles_at(n: int, thrust: int, t: float) -> Array:
	var out: Array = []
	var tail := _tail(n, thrust)
	var pts: PackedVector2Array = tail.pts
	if pts.is_empty():
		return out
	var L: int = tail.L
	var dir: int = tail.dir
	var s: Dictionary = SHAPE[look]
	var dith: Array = s.dith
	var rng := RandomNumberGenerator.new()
	for kind in 2:
		var rate: float = (SPARK_RATE[thrust] if kind == 0 else BLOB_RATE[thrust]) \
			* float((nozzles[n] as Dictionary).get("pscale", 1.0))
		var period := 1.0 / rate
		var max_life := (8.0 if kind == 0 else 10.0) / 30.0
		var i0 := int(floor((t - max_life) / period)) - 1
		var i1 := int(floor(t / period))
		for i in range(i0, i1 + 1):
			rng.seed = hash([_seed, look, n, kind, i])
			var born := (float(i) + rng.randf()) * period
			if born > t:
				continue
			var age := int(floor((t - born) * 30.0))
			var life := rng.randi_range(4, 8) if kind == 0 else rng.randi_range(6, 10)
			if age >= life:
				continue
			var e := pts[rng.randi() % pts.size()]
			var d0 := rng.randf_range(0.55, 1.0) * float(L) if kind == 0 else rng.randf_range(0.85, 1.05) * float(L)
			var vx := rng.randf_range(1.0, 2.0) if kind == 0 else rng.randf_range(0.6, 1.2)
			var vy := rng.randf_range(-0.35, 0.35) if kind == 0 else rng.randf_range(-0.2, 0.2)
			var yo := rng.randi_range(-2, 2) if kind == 0 else rng.randi_range(-1, 1)
			var size0 := rng.randi_range(2, 4)
			var x := int(e.x) + int(round((d0 + vx * float(age)) * float(dir)))
			var y := int(e.y) + yo + int(round(vy * float(age)))
			var heat := float(age) / float(life)
			var band := clampi(int(heat * 4.0), 0, 3) if kind == 0 else clampi(1 + int(heat * 3.0), 1, 3)
			var cells: Array = [Vector2i.ZERO]
			if kind == 1:
				var sz := clampi(int(ceil(float(size0) * (1.0 - heat))), 1, 4)
				cells = CLUMPS[sz - 1]
			for c in cells:
				var px := x + (c as Vector2i).x * dir
				var py := y + (c as Vector2i).y
				if _is_solid(px, py):
					continue
				# A spark is one moving pixel: thinned by the pattern it would
				# blink on and off as it crosses it, so only its last, reddest
				# step is dithered. Fire clumps take the look's own dither.
				var bz: float = BAYER[posmod(py, 2) * 2 + posmod(px, 2)]
				var cut: float = dith[band] if kind == 1 or band == 3 else 1.0
				if bz >= cut:
					continue
				out.append({x = px, y = py, band = band, k = 1.0 if kind == 0 else 0.9})
	return out


## Where the particles leave from, per engine and thrust: the stream that
## reaches open space (for a bell, the mouth past the rim) and its length.
func _tail(n: int, thrust: int) -> Dictionary:
	var key := Vector2i(n, thrust)
	if _tails.has(key):
		return _tails[key]
	var nz: Dictionary = nozzles[n]
	var L := nozzle_length(n, thrust)
	if not bool(nz.get("behind", false)):
		L = mini(L, _clear_run(nz.pts, nz.dir))
	var out := {pts = nz.pts, L = L, dir = nz.dir}
	if nz.has("bell"):
		var idle := thrust == Thrust.IDLE
		out = {pts = nz.bell.mouth, L = L if idle else int(round(float(L) * 0.7)), dir = nz.dir}
	_tails[key] = out
	return out


## How far the middle row of an engine runs through open space before it hits
## hull again (the flame stops there, and so do its sparks), up to 400 px.
func _clear_run(pts: PackedVector2Array, dir: int) -> int:
	if pts.is_empty():
		return 0
	var e := pts[pts.size() / 2]
	var seen := false
	for d in 400:
		var x := int(e.x) + d * dir
		if _is_solid(x, int(e.y)):
			if seen:
				return d
		else:
			seen = true
	return 400


## THE BELL'S LIGHT (heavy S). The cavity is always FILLED, every cell the
## strip always covers, brighter toward the rim as today's flame is, and past
## the rim the flame leaves at the mouth's full width with the look's own
## spread and falloff. Jon, on idle: "The flame should extend slightly out of
## the ship ... that little depression is the entire exhaust" -- so idle is the
## same shape, dimmer: the bell held in the second band (0.52 to 0.70, no white
## core) and the full idle length past the rim, at 0.75 of the light.
## Cruise and full: the bell 0.55 to 0.95 and 0.7 of the length past it.
## Living: the bell only shifts its bands (0 to +0.08); the part past the rim
## gets the whole loop. Nothing here touches a hull pixel the strip leaves
## visible: cells are the strip's own, and the streams are cut out by the hull.
func _bell_light(bell: Dictionary, L: int, Lf: int, spread: float, streams: Array,
		fills: Array, fp: Dictionary) -> void:
	var depth: int = bell.depth
	var apex: int = bell.apex
	var idle := L <= base_length(Thrust.IDLE) + FLICK[Thrust.IDLE]
	var v0 := 0.52 if idle else 0.55
	var v1 := 0.70 if idle else 0.95
	var lift := 0.04 * float(fp.bshift)
	for c in (bell.cells as PackedVector2Array):
		var d := float(apex - int(c.x))
		fills.append({x = int(c.x), y = int(c.y), v = lerpf(v0, v1, clampf(d / float(depth), 0.0, 1.0)) + lift})
	# past the rim: 0.7 of the length out of a deep bell, but never less than
	# what is left of it once the bell is crossed
	var lout := Lf if idle else maxi(int(round(float(Lf) * 0.7)), Lf - depth)
	if lout > 0:
		streams.append({pts = bell.mouth, L = lout, spk = spread, gain = 0.75 if idle else 1.0})


## One nozzle's light streaming back over `L` px into `buf` (canvas box `at`,
## W x Hh): every point of the nozzle streams, falling off as
## pow(1 - d/(L+1), expo), widening 1 px every 1/spk, overlaps taking the max.
## `fp` is the loop frame's shape (`_frame`): each row's tongue, the band shift.
func _stream(buf: PackedFloat32Array, W: int, Hh: int, at: Vector2i, em: PackedVector2Array, L: int,
		spk: float, expo: float, dir: int, gain: float = 1.0, fp: Dictionary = {}, behind: bool = false,
		skip: int = 0) -> void:
	if em.is_empty():
		return
	var lo_y := 1 << 20
	var hi_y := -(1 << 20)
	for e in em:
		lo_y = mini(lo_y, int(e.y))
		hi_y = maxi(hi_y, int(e.y))
	# THE TAPER. The death's stern rows each streamed the full length, which on
	# a ragged stern staggers into a point; on a rigged nozzle eight rows tall
	# it is a flat-ended slab. Rows off the nozzle's middle run shorter and a
	# little dimmer, so the flame comes to a rounded tip like the overload's did.
	var mid_y := float(lo_y + hi_y) * 0.5
	var half := float(hi_y - lo_y) * 0.5 + 0.5
	# THE TONGUES: each row's own length this frame, smoothed over its
	# neighbours so the edge is ragged and not noise, and one or two rows
	# licking further out.
	var cnt := em.size()
	var tongue := PackedFloat32Array()
	tongue.resize(cnt)
	tongue.fill(1.0)
	var shift := int(fp.get("shift", 0))
	if int(fp.get("rows", 0)) != 0 and rag > 0.0:
		var rr := RandomNumberGenerator.new()
		rr.seed = int(fp.rows)
		var raw := PackedFloat32Array()
		raw.resize(cnt)
		for i in cnt:
			raw[i] = rr.randf_range(-0.24, 0.06) * rag
		for i2 in cnt:
			var a := raw[maxi(0, i2 - 1)]
			var c := raw[mini(cnt - 1, i2 + 1)]
			tongue[i2] = maxf(0.45, 1.0 + (a + 2.0 * raw[i2] + c) * 0.25)
		if dynamic:
			for i3 in cnt:
				raw[i3] = rr.randf_range(-0.32, 0.1) * rag
			for i4 in cnt:
				var a2 := raw[maxi(0, i4 - 1)]
				var c2 := raw[mini(cnt - 1, i4 + 1)]
				tongue[i4] = maxf(0.4, 1.0 + (a2 + 2.0 * raw[i4] + c2) * 0.25)
		var licks := 1 + (1 if rr.randf() < 0.5 * rag else 0)
		if dynamic:
			licks = rr.randi_range(2, 4)
			# A FORKED TIP: two rows licking out with a short one between.
			if cnt >= 3 and rr.randf() < 0.35:
				var fk := rr.randi_range(0, cnt - 3)
				var fx2 := rr.randf_range(0.3, 0.55) * rag
				tongue[fk] += fx2
				tongue[fk + 2] += fx2 * 0.9
				tongue[fk + 1] = maxf(0.4, tongue[fk + 1] - 0.25)
		for k in licks:
			var at_row := rr.randi_range(0, cnt - 1)
			var extra := rr.randf_range(0.18, 0.38) * rag
			if dynamic:
				extra = rr.randf_range(0.3, 0.65) * rag
			tongue[at_row] += extra
			if at_row > 0:
				tongue[at_row - 1] += extra * 0.5
			if at_row < cnt - 1:
				tongue[at_row + 1] += extra * 0.5
	var wob_ph := float(fp.get("wob", -1.0))
	for idx in cnt:
		var e2 := em[idx]
		var ex := int(e2.x)
		var ey := int(e2.y)
		var u := (float(ey) - mid_y) / (half + 0.5)
		var Lr := maxi(1, int(round(float(L) * (1.0 - 0.5 * u * u) * tongue[idx])))
		var dim := 1.0 - 0.25 * u * u
		# A FLAME STOPS AT WHAT IT HITS: once its row has been in open space, the
		# next hull pixel on it ends the row. Masking alone let a stream pass
		# behind an obstacle and come out the far side -- the orbit-arm ship's
		# drive "burned" out of the sphere behind it.
		var seen_air := false
		for d in Lr + 1:
			var ax := ex + d * dir
			if behind and d > 0:
				pass        # passes behind what is in its way (art/engines.json `behind`)
			elif _is_solid(ax, ey):
				if seen_air:
					break
			else:
				seen_air = true
			# The band edges move a pixel along the flame with `shift`; the
			# nozzle's own pixel (d = 0) is never moved off its band.
			var de := clampi(d + shift, 0, Lr) if d > 0 else 0
			var fall := gain * dim * pow(1.0 - float(de) / float(Lr + 1), expo)
			# behind a weight it burns hot until it is past it, then falls off over
			# the length left -- so it comes out the far side as a drive, not embers
			if skip > 0 and Lr > skip:
				var de2 := maxi(0, de - skip)
				fall = gain * dim * pow(1.0 - float(de2) / float(Lr - skip + 1), expo)
			# NOT WIDER THAN THE NOZZLE AT ITS MOUTH: the first two columns are the
			# nozzle's own rows; the flame spreads from the third. (A spread of 1 at
			# the start made every flame 2 rows taller than its opening -- Jon:
			# "still slightly bigger than nozzle".)
			var spread := int(float(d) * spk) + (1 if d >= 2 else 0)
			# B's knots: every fifth pixel along the AXIS (the nozzle's middle
			# rows only), held where they are, lifted a band while the jet is
			# still hot enough to carry them.
			var knot := 0.0
			if look == Look.DRIVE and absf(u) < 0.4 and d >= 3 and d % 5 == 3 and float(d) < float(L) * 0.75:
				knot = 0.24
			for dyy in range(-spread, spread + 1):
				var v := fall * (1.0 - absf(float(dyy)) / float(spread + 1))
				if knot > 0.0 and absi(dyy) <= 1:
					v = minf(1.0, v + knot * (1.0 if dyy == 0 else 0.5))
				var cx := ex + d * dir
				var cy := ey + dyy
				# THE WOBBLE: the outline sways a pixel side to side along the
				# flame. Never in the first three pixels: the start stays put.
				if wob_ph >= 0.0 and d > 4:
					cy += int(round(sin(float(d) * 0.22 + wob_ph)))
				if _is_solid(cx, cy):
					continue
				var xx := cx - at.x
				var yy := cy - at.y
				if xx >= 0 and yy >= 0 and xx < W and yy < Hh:
					buf[yy * W + xx] = maxf(buf[yy * W + xx], v)


## Light into the look's four held bands, the outer ones Bayer-thinned in
## CANVAS coordinates.
func _quantize(buf: PackedFloat32Array, W: int, Hh: int, at: Vector2i, s: Dictionary) -> Dictionary:
	var im := Image.create(W, Hh, false, Image.FORMAT_RGBA8)
	var ramp := _ramp()
	var thr: Array = s.thr
	var lvs: Array = s.lv
	var dith: Array = s.dith
	var any := false
	for y in Hh:
		for x in W:
			var v2 := buf[y * W + x]
			if v2 <= float(thr[3]):
				continue
			var band := 3
			for b in 4:
				if v2 > float(thr[b]):
					band = b
					break
			# The pattern is the SHIP's: read in canvas coordinates.
			var bz: float = BAYER[(posmod(at.y + y, 2)) * 2 + posmod(at.x + x, 2)]
			if bz >= float(dith[band]):
				continue
			im.set_pixel(x, y, _lv(ramp[band], float(lvs[band])))
			any = true
	return {tex = ImageTexture.create_from_image(im) if any else null, at = at}


## C's light on the hull: every hull pixel near a nozzle, on the ship's side of
## it, lit by distance in three held steps, the outer two dithered. Keyed to the
## thrust and NOT to the flicker -- the stern is lit by the burn, and a stern
## that stepped with every flicker would double the pixels that change.
func spill(thrust: int) -> Dictionary:
	if _spill.has(thrust):
		return _spill[thrust]
	var R := clampf(3.0 + float(base_length(thrust)) * 0.5, 4.0, 11.0)
	var ir := int(ceil(R))
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := Vector2i(-(1 << 20), -(1 << 20))
	for nz in nozzles:
		for e in (nz.pts as PackedVector2Array):
			lo = Vector2i(mini(lo.x, int(e.x)), mini(lo.y, int(e.y)))
			hi = Vector2i(maxi(hi.x, int(e.x)), maxi(hi.y, int(e.y)))
	if nozzles.is_empty():
		_spill[thrust] = {tex = null, at = Vector2i.ZERO}
		return _spill[thrust]
	var at := lo - Vector2i(ir, ir)
	var W := hi.x - lo.x + 2 * ir + 1
	var Hh := hi.y - lo.y + 2 * ir + 1
	var buf := PackedFloat32Array()
	buf.resize(W * Hh)
	for nz2 in nozzles:
		var dir: int = nz2.dir
		for e2 in (nz2.pts as PackedVector2Array):
			for dy in range(-ir, ir + 1):
				for dx in range(-ir, ir + 1):
					if dx * dir > 0:
						continue
					var cx := int(e2.x) + dx
					var cy := int(e2.y) + dy
					if not _is_solid(cx, cy):
						continue
					var dist := sqrt(float(dx * dx + dy * dy))
					if dist > R:
						continue
					var v := pow(1.0 - dist / R, 1.6)
					var i := (cy - at.y) * W + (cx - at.x)
					buf[i] = maxf(buf[i], v)
	var im := Image.create(W, Hh, false, Image.FORMAT_RGBA8)
	var ramp := _ramp()
	var any := false
	for y in Hh:
		for x in W:
			var v2 := buf[y * W + x]
			var bz: float = BAYER[posmod(at.y + y, 2) * 2 + posmod(at.x + x, 2)]
			var c := Color()
			if v2 > 0.5:
				c = _lv(ramp[2], 0.55)
			elif v2 > 0.25:
				if bz >= 0.75:
					continue
				c = _lv(ramp[3], 0.46)
			elif v2 > 0.08:
				if bz >= 0.5:
					continue
				c = _lv(ramp[3], 0.3)
			else:
				continue
			im.set_pixel(x, y, c)
			any = true
	_spill[thrust] = {tex = ImageTexture.create_from_image(im) if any else null, at = at}
	return _spill[thrust]


# ------------------------------------------------------------------ copied from ShipBreakup

## COPY of ShipBreakup._hull_pic, the mask half only (no dead-engine recolour):
## the ship's box grown by `margin`, which pixels are hull (lone pixels are the
## canvas's starfield, dropped), the hull's middle and its box.
static func _hull_pic(img: Image, used: Rect2i, margin: int) -> Dictionary:
	var canvas := Rect2i(Vector2i.ZERO, img.get_size())
	var u := used.intersection(canvas)
	var r := u.grow(margin).intersection(canvas)
	var w := r.size.x
	var h := r.size.y
	var n := w * h
	var raw := PackedColorArray()
	raw.resize(n)
	var pre := PackedByteArray()
	pre.resize(n)
	for y in h:
		for x in w:
			var g := r.position + Vector2i(x, y)
			if not u.has_point(g):
				continue
			var c := img.get_pixel(g.x, g.y)
			raw[y * w + x] = c
			if c.a > 0.6:
				pre[y * w + x] = 1
	var mask := PackedByteArray()
	mask.resize(n)
	var sx := 0.0
	var cnt := 0
	var x1 := -1
	for y in h:
		for x in w:
			var i := y * w + x
			if pre[i] == 0:
				continue
			var nb := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var xx: int = x + dx
					var yy: int = y + dy
					if xx >= 0 and yy >= 0 and xx < w and yy < h and pre[yy * w + xx] == 1:
						nb += 1
			if nb < 2:
				continue
			mask[i] = 1
			sx += x
			cnt += 1
			x1 = maxi(x1, x)
	if cnt == 0:
		return {n = 0, r = r, w = w, h = h}
	return {r = r, w = w, h = h, raw = raw, mask = mask, n = cnt, cx = sx / cnt, x1 = x1}


## COPY of ShipBreakup._engines, unchanged: the end of every row that reaches the
## stern (enemies face left, so the stern is the right), and every lit engine
## pixel in the back half. `for_sprite` filters it for a steady flame.
static func engines(H: Dictionary) -> PackedVector2Array:
	var w: int = H.w
	var h: int = H.h
	var mask: PackedByteArray = H.mask
	var raw: PackedColorArray = H.raw
	var r: Rect2i = H.r
	var x1: int = H.x1
	var out := PackedVector2Array()
	for y in h:
		var xr := -1
		for x in w:
			if mask[y * w + x] == 1:
				xr = x
		if xr >= x1 - 5:
			out.append(Vector2(r.position) + Vector2(xr + 1, y))
	for y in h:
		for x in w:
			if mask[y * w + x] == 0 or float(x) < float(H.cx):
				continue
			var c := raw[y * w + x]
			if c.r > 0.75 and c.r >= c.b + 0.25 and c.get_luminance() > 0.55:
				out.append(Vector2(r.position) + Vector2(x, y))
	return out
