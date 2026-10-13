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
		var pts := PackedVector2Array()
		for y4 in rows:
			pts.append(Vector2(at.x + xr, at.y + y4))
		# A point of a nozzle widens faster, so at full burn it is a flame and
		# not a needle; its start stays where it is.
		var widen := clampf(10.0 / float(rows.size()), 1.0, 3.0)
		var nz := {pts = pts, dir = -1, thruster = ti, widen = widen}
		var bell := _bell(cells, int(pts[0].x))
		if not bell.is_empty():
			nz.bell = bell
		fx.nozzles.append(nz)
	fx._plan(seed)
	return fx


## A ship picture with no rig (an enemy, a PixelLab pool ship): the nozzles are
## found the overload's way, `_engines`, then kept to the hull's back edge and
## split into engines. Enemies face left, so they burn to the right.
static func for_sprite(img: Image, used: Rect2i, the_look: int, seed: int) -> ThrusterFx:
	var fx := ThrusterFx.new()
	fx._take_canvas(img)
	fx.look = the_look
	fx.warm = true
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
	fx._plan(seed)
	return fx


## One engine from a run of stern rows. A tall flat stern is not one tall engine:
## keep the rows that stand furthest back (the bells), then the middle `cap`.
func _add_run(run: Array, by_row: Dictionary, cap: int) -> void:
	if run.is_empty():
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
	nozzles.append({pts = pts, dir = 1})


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
		return base_length(thrust)
	var o: PackedInt32Array = _offs[step_at(t)]
	var amp := FLICK[thrust]
	if look == Look.SPILL:
		amp = maxi(1, amp - 1)
	return maxi(2, base_length(thrust) + o[n] * amp)


## Which of the LOOP shapes engine `n` shows at `t`: held frames at `fps`, each
## engine's loop offset by three frames from the last so a multi-engine ship
## never pulses in unison.
func frame_at(n: int, t: float) -> int:
	if fps <= 0.0:
		return 0
	return posmod(int(floor(t * fps)) + n * 3 + _seed, LOOP)


func frames() -> int:
	return LOOP if fps > 0.0 else 1


## Every picture this thrust can ask for, built now rather than on first sight.
func warm_up(thrust: int) -> void:
	var b := base_length(thrust)
	for n in nozzles.size():
		if fps > 0.0:
			for f in LOOP:
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
		streams.append({pts = nz.pts, L = Lf, spk = float(s.spread) * float(nz.get("widen", 1.0))})
	# Embers: one spawned this frame or either of the two before, carried a
	# further 2 px a frame and dimmer each time.
	if not streams.is_empty():
		var st0: Dictionary = streams[-1]
		var src: PackedVector2Array = st0.pts
		for j in 3:
			var ep: Dictionary = _frame(n, posmod(fr - j, LOOP)).ember
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
		var sl: int = int(round(float(st.L) * (1.0 + 0.5 * rag))) + 2
		var sp := 2 + int(float(sl) * float(st.spk))
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
			float(st2.get("gain", 1.0)), fp)
	var out := _quantize(buf, W, Hh, at, s)
	_cache[key] = out
	return out


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
	var lout := Lf if idle else int(round(float(Lf) * 0.7))
	if lout > 0:
		streams.append({pts = bell.mouth, L = lout, spk = spread, gain = 0.75 if idle else 1.0})


## One nozzle's light streaming back over `L` px into `buf` (canvas box `at`,
## W x Hh): every point of the nozzle streams, falling off as
## pow(1 - d/(L+1), expo), widening 1 px every 1/spk, overlaps taking the max.
## `fp` is the loop frame's shape (`_frame`): each row's tongue, the band shift.
func _stream(buf: PackedFloat32Array, W: int, Hh: int, at: Vector2i, em: PackedVector2Array, L: int,
		spk: float, expo: float, dir: int, gain: float = 1.0, fp: Dictionary = {}) -> void:
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
		var licks := 1 + (1 if rr.randf() < 0.5 * rag else 0)
		for k in licks:
			var at_row := rr.randi_range(0, cnt - 1)
			var extra := rr.randf_range(0.18, 0.38) * rag
			tongue[at_row] += extra
			if at_row > 0:
				tongue[at_row - 1] += extra * 0.5
			if at_row < cnt - 1:
				tongue[at_row + 1] += extra * 0.5
	for idx in cnt:
		var e2 := em[idx]
		var ex := int(e2.x)
		var ey := int(e2.y)
		var u := (float(ey) - mid_y) / (half + 0.5)
		var Lr := maxi(1, int(round(float(L) * (1.0 - 0.5 * u * u) * tongue[idx])))
		var dim := 1.0 - 0.25 * u * u
		for d in Lr + 1:
			# The band edges move a pixel along the flame with `shift`; the
			# nozzle's own pixel (d = 0) is never moved off its band.
			var de := clampi(d + shift, 0, Lr) if d > 0 else 0
			var fall := gain * dim * pow(1.0 - float(de) / float(Lr + 1), expo)
			var spread := 1 + int(float(d) * spk)
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
