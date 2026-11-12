class_name YardSlot
extends RefCounted

## THE FRONT DOOR'S THREE BERTHS, fixed: the light far left, the medium far
## right, the heavy centred behind, higher on the floor and its stands smaller
## by the yard's depth. Every manufacturer's ships stand on the same stands;
## only the hull moves to sit on them (Jon, Nov 12).
## Why: docs/why/ChassisSelect.md#fixed-berths

## The front berths' floor row and the heavy's, further back.
const FRONT_FEET := 372
const BACK_FEET := 334
## The floor's vanishing row (`YardLife.zat`): size goes as the row's distance from it.
const HORIZON := 30.0
## Each berth's middle, and its stands' middles apart, in hall pixels.
const CENTRE := {HullData.Weight.LIGHT: 200, HullData.Weight.MEDIUM: 776, HullData.Weight.HEAVY: 480}
const APART := {HullData.Weight.LIGHT: 84, HullData.Weight.MEDIUM: 108, HullData.Weight.HEAVY: 180}
## The stand picture at the front row.
const STAND_W := 46
const STAND_H := 88
## How far a hull may slide off its mass middle to sit level on the fixed stands.
const DRIFT := 14
## The floor a berth takes, from its feet back under the hull at the front row's
## size, and a little room before its feet and beside its stands; walkers keep
## out of it (`YardFrontLife.avoid`).
const DEPTH := 24
const FRONT := 12
const PAD := 6


static func feet(w: HullData.Weight) -> int:
	return BACK_FEET if w == HullData.Weight.HEAVY else FRONT_FEET


## A thing's size on this berth's row against the front row's.
static func depth_k(w: HullData.Weight) -> float:
	return (float(feet(w)) - HORIZON) / (float(FRONT_FEET) - HORIZON)


static func stand_size(w: HullData.Weight) -> Vector2i:
	var k := depth_k(w)
	return Vector2i(roundi(float(STAND_W) * k), roundi(float(STAND_H) * k))


## The two stands' pictures' boxes in the hall: the same for every manufacturer.
static func stand_rects(w: HullData.Weight) -> Array[Rect2i]:
	var s := stand_size(w)
	var c := int(CENTRE[w])
	var half := int(APART[w]) / 2
	var out: Array[Rect2i] = []
	for m: int in [c - half, c + int(APART[w]) - half]:
		out.append(Rect2i(m - s.x / 2, feet(w) - s.y, s.x, s.y))
	return out


## The floor the berth stands on, stand to stand and back under the hull.
static func footprint(w: HullData.Weight) -> Rect2i:
	var r := stand_rects(w)
	var d := roundi(float(DEPTH) * depth_k(w))
	var x0 := r[0].position.x - PAD
	var x1 := r[1].end.x + PAD
	return Rect2i(x0, feet(w) - d, x1 - x0, d + FRONT)


## A stand picture at this berth's size: whole columns dropped where a column
## matches its neighbour best (never two side by side), then `_sized` for height.
static func shrink_width(si: Image, w_to: int) -> Image:
	var w := si.get_width()
	var h := si.get_height()
	if w_to >= w:
		return si
	var cost: Array[float] = []
	for x in w:
		var t := 0.0
		if x > 0:
			for y in h:
				var a := si.get_pixel(x, y)
				var b := si.get_pixel(x - 1, y)
				t += absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) + absf(a.a - b.a)
		else:
			t = 1e9
		cost.append(t)
	var drop := {}
	for _n in w - w_to:
		var best := -1
		for x in range(1, w):
			if drop.has(x) or drop.has(x - 1) or drop.has(x + 1):
				continue
			if best < 0 or cost[x] < cost[best]:
				best = x
		if best < 0:
			break
		drop[best] = true
	var out := Image.create(w - drop.size(), h, false, Image.FORMAT_RGBA8)
	var ox := 0
	for x in w:
		if drop.has(x):
			continue
		out.blit_rect(si, Rect2i(x, 0, 1, h), Vector2i(ox, 0))
		ox += 1
	return out


## Where a hull sits on the berth's fixed stands: its ink's left column in the
## hall, the belly row over the higher cradle (`cmin`, the row it rests on), how
## far it is let in past the seat (`sink`) and the cradles' rows. The same
## score as `YardScene.seat_pair`, with the stands held and the hull slid.
## Returns [x0, cmin, sink, c0, c1].
static func seat(under: PackedInt32Array, iw: int, mass: float, cap: Dictionary, seat_rows: int,
		hang: PackedByteArray, lefts: Array[int]) -> PackedInt32Array:
	var a := int(cap["a"])
	var b := int(cap["b"])
	var tops: PackedInt32Array = cap["top"]
	# the hull's mass middle over the cradles' middles, then slid as it must
	var home := roundi(float(lefts[0] + lefts[1]) * 0.5 + float(cap["mid"]) - mass)
	var best := 1e18
	var out := PackedInt32Array([home, 0, 0, 0, 0])
	for d in range(-DRIFT, DRIFT + 1):
		var x0 := home + d
		var cs := PackedInt32Array([0, 0])
		var spread := 0
		var under_part := 0
		var ok := true
		for k in 2:
			var L := lefts[k] - x0
			if L + a < 0 or L + b >= iw:
				ok = false
				break
			var lo := 1 << 30
			var hi := -1
			for j in range(a, b + 1):
				var u := under[L + j]
				if u < 0:
					ok = false
					break
				lo = mini(lo, u)
				hi = maxi(hi, u)
				if L + j < hang.size() and hang[L + j] != 0:
					under_part += 1
			if not ok:
				break
			cs[k] = hi
			spread += hi - lo
		if not ok:
			continue
		var cmin := mini(cs[0], cs[1])
		var gap := 0
		var sink := 0
		for k in 2:
			var L2 := lefts[k] - x0
			for j in range(a, b + 1):
				var hb := under[L2 + j] - cmin + seat_rows - 1
				gap += maxi(0, tops[j] - 1 - hb)
				sink = maxi(sink, tops[j] - 1 - hb)
		var sc := 40.0 * float(gap) + 25.0 * float(under_part) + 12.0 * float(sink) \
			+ 6.0 * float(absi(cs[0] - cs[1])) + 2.0 * float(spread) + 3.0 * float(absi(d))
		if sc < best:
			best = sc
			out = PackedInt32Array([x0, cmin, sink, cs[0], cs[1]])
	if best >= 1e18:
		# no slide puts both cradles under ink: rest on the lowest pixel over each
		for k in 2:
			for j in range(a, b + 1):
				var c := lefts[k] - home + j
				if c >= 0 and c < iw:
					out[3 + k] = maxi(out[3 + k], under[c])
		out[1] = mini(out[3], out[4])
	return out
