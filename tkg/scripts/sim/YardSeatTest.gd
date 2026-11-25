extends Node

## Jon: the medium Korvan sat too high and left. Measured off the pictures, not `_stand`'s numbers.
## Each picture is stood once, as hulls share pictures. Stands one height, hull inside the hall.
## Why: docs/why/YardSeatTest.md#yard-seat

const LEVELS := {"unclaimed": MapGen.Development.UNCLAIMED, "outpost": MapGen.Development.OUTPOST,
	"settlement": MapGen.Development.SETTLEMENT, "city": MapGen.Development.CITY,
	"capital": MapGen.Development.CAPITAL}

## Solari's light keel drops 11 rows, so the best pair sinks 6; Korvan's Nov 16 light keel
## (x 126-168) sinks its pair 8. Why: docs/why/YardSeatTest.md#sink-limit
const SINK_MAX := 8

## Where each tarp's drawn emblem is (centre x, centre y, px a mark unit), measured off the art (Nov 24);
## the stencilled ones are `TarpMark.AT`'s. Why: docs/why/TarpMark.md#stencil
const DRAWN_MARKS := {
	"solari_light": [90, 54, 3], "solari_medium": [145, 67, 4], "solari_heavy": [154, 81, 5],
	"probate_medium": [121, 65, 4], "probate_heavy": [150, 78, 5],
	"redline_light": [90, 54, 3], "redline_medium": [61, 63, 4], "redline_heavy": [152, 79, 5],
	"verity_light": [89, 54, 3], "verity_medium": [148, 65, 4], "verity_heavy": [151, 78, 5],
	"cygnet_light": [89, 53, 3], "cygnet_medium": [146, 68, 4], "cygnet_heavy": [151, 78, 5],
}
## Of an emblem's pixels, at least this share sit further toward the mark colour than nine in ten of the
## cloth round it: the drawn marks measure 0.59 to 0.88, Calyx's tarps without a stencil 0.03 to 0.13.
const MARK_SHARE := 0.45

var harness := Harness.new()


## Korvan's launch kit's posts (centre, centre, top) by PORT.md's table, Nov 22. The mock's guns
## stood a pixel off the game's own mounts, so the game's posts may stand a pixel off them.
const KORVAN_POSTS := {HullData.Weight.HEAVY: [377, 521, 258], HullData.Weight.LIGHT: [128, 266, 278],
	HullData.Weight.MEDIUM: [696, 783, 284]}


func _ok(what: String, c: bool) -> bool:
	if not c:
		harness._fail(what)
	return c


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# one picture each, with the frames that draw it
	var by_sprite := {}
	var order: Array[String] = []
	for f: HullData in DB.hull_frames:
		for tier in 4:
			var h := DB.at_tier(f, tier)
			if h.sprite == null:
				continue
			var key := h.sprite.resource_path
			if not by_sprite.has(key):
				by_sprite[key] = {"hull": h, "names": []}
				order.append(key)
			(by_sprite[key]["names"] as Array).append("%s %s" % [h.name, DB.tier_name(tier)])
	print("yardseattest: %d frames x 4 grades draw %d pictures" % [DB.hull_frames.size(), order.size()])
	var worst_c := 0.0
	var worst_sink := 0
	for level: String in LEVELS:
		var sc := YardScene.new()
		sc.dev = LEVELS[level]
		add_child(sc)
		sc.setup()
		var berths: Array = YardScene.doc().get("berths", [190, 585])
		for key in order:
			var h: HullData = by_sprite[key]["hull"]
			for bi in 2:
				var v := ShipView.new()
				v.setup_preview(h, 0, 1)
				var P: Dictionary = sc._stand(v, float(berths[bi]))
				var tag := "%s %s berth %d" % [level, key.get_file().get_basename(), bi]
				if not _ok("%s: stood" % tag, not P.is_empty() and (P["supports"] as Array).size() == 2):
					v.free()
					continue
				var r := _measure(v.canvas(), Vector2i(v.position), P)
				worst_c = maxf(worst_c, absf(float(r["off"])))
				worst_sink = maxi(worst_sink, int(r["sink"]))
				if bi == 0:
					print("  %-10s %-14s centre %+.2f px  depth below contact %d,%d (sink %d)  floor showing %d,%d px  stands at %s  apart %.0f%%" % [
						level, key.get_file().get_basename(), r["off"], r["d"][0], r["d"][1], r["sink"],
						r["gap"][0], r["gap"][1], r["at"], 100.0 * float(r["apart"])])
				_ok("%s: no floor between the hull and a cap (%s px)" % [tag, r["gap"]], int(r["gap"][0]) == 0 and int(r["gap"][1]) == 0)
				_ok("%s: the hull rests on a cap's contact row (depths %s, sink %d)" % [tag, r["d"], r["sink"]],
					mini(int(r["d"][0]), int(r["d"][1])) == int(r["sink"]) and int(r["sink"]) <= SINK_MAX)
				_ok("%s: centred on its stands (%+.2f px)" % [tag, r["off"]], absf(float(r["off"])) <= 1.0)
				_ok("%s: both stands one height" % tag, r["heights"][0] == r["heights"][1])
				_ok("%s: inside the hall (%s)" % [tag, r["span"]], int(r["span"][0]) >= 0 and int(r["span"][1]) < YardScene.W)
				v.free()
		sc.free()
	print("  the worst centring %.2f px, the most sunk %d rows" % [worst_c, worst_sink])
	for key in order:
		print("  %s: %s" % [key.get_file().get_basename(), ", ".join(by_sprite[key]["names"])])
	_front()
	_berths()
	harness.verdict("yardseattest")
	get_tree().quit(harness.code())


## THE SHIP-SELECT POSTS (PORT.md's rule, Jon Nov 22: "The stands go through the guns?"):
## every manufacturer's three hulls at every grade on two level posts, clear of the belly guns,
## tucked behind the belly, their feet on the berth's row; each locked set's tarp on two.
## Why: docs/why/ShipRoom.md#posts-clear-the-guns
func _front() -> void:
	var front := YardFront.new()
	add_child(front)
	front.setup()
	for m: StringName in DB.STARTABLE:
		for tier in 4:
			front.show_set(m, true, tier)
			for w: HullData.Weight in front.sets:
				var s: YardStandSet = front.sets[w]
				var tag := "posts %s %s %s" % [m, HullData.weight_name(w), DB.tier_name(tier)]
				if not _ok("%s: a hull on two posts" % tag, s._view != null and s.post_x.size() == 2):
					continue
				_post_rule(s, tag, tier == 0)
	# Korvan's launch kit as PORT.md measured it (centres, the level top)
	front.show_set(&"korvan", true, 0)
	for w: HullData.Weight in KORVAN_POSTS:
		var s: YardStandSet = front.sets[w]
		var got := [s.post_x[0] + YardStandSet.POST_HALF, s.post_x[1] + YardStandSet.POST_HALF, s.post_top]
		var near := true
		for k in 3:
			near = near and absi(int(got[k]) - int(KORVAN_POSTS[w][k])) <= 1
		_ok("posts korvan %s within a pixel of PORT.md's %s (got %s)" % [HullData.weight_name(w), KORVAN_POSTS[w], got], near)
	for m: StringName in DB.STARTABLE:
		front.show_set(m, false)
		for w: HullData.Weight in front.sets:
			var s: YardStandSet = front.sets[w]
			var tag := "posts %s %s tarp" % [m, HullData.weight_name(w)]
			if not _ok("%s: a tarp on two posts" % tag, s._tarp != null and s._tarp.image != null and s.post_x.size() == 2):
				continue
			var path := s._tarp.file
			_ok("%s: the manufacturer's own tarp, else Solari's (%s)" % [tag, path.get_file()],
				path.get_file() == "%s_%s.png" % [m, YardStandSet.TARP_WEIGHT[w]] or path.get_file().begins_with("solari_"))
			_post_rule(s, tag, false)
			if m != &"korvan":
				_emblem_on(s, m, tag)
	front.free()


## Each locked tarp shows its manufacturer's emblem (Jon, Nov 24: "The Calyx Biosystems logo isn't on these
## ships"): on the yard's art and on the Old hangar's wind texture, which is what the hangar draws.
func _emblem_on(s: YardStandSet, m: StringName, tag: String) -> void:
	var stem := s._tarp.file.get_file().get_basename()
	var at: Array = TarpMark.AT.get(stem, DRAWN_MARKS.get(stem, []))
	if not _ok("%s: where its emblem is, known (%s)" % [tag, stem], at.size() >= 3 and stem.begins_with(String(m))):
		return
	var share := mark_share(s._tarp.image, TarpMark.art_rect(s._tarp.image, 0), m, at)
	_ok("%s: its %s emblem is on the cloth (share %.2f)" % [tag, m, share], share >= MARK_SHARE)
	var wind := s._tarp.wind.get_image() if s._tarp.wind != null else null
	if not _ok("%s: the Old hangar's wind texture" % tag, wind != null):
		return
	var ws := mark_share(wind, TarpMark.art_rect(wind, YardStandSet.Tarp.WIND_PAD), m, at)
	_ok("%s: and in the Old hangar's wind (share %.2f)" % [tag, ws], ws >= MARK_SHARE)


## The share of the emblem's opaque pixels further along the mark colour's direction (from the mean of the
## cloth round it, a unit's margin) than the ring's 90th percentile.
static func mark_share(img: Image, art: Rect2i, m: StringName, at: Array) -> float:
	var u := int(at[2])
	var cells := TarpMark.cells_of(m, Vector2i(int(at[0]), int(at[1])), u)
	var lo := Vector2i(1 << 20, 1 << 20)
	var hi := -lo
	for p: Vector2i in cells:
		lo = lo.min(p)
		hi = hi.max(p)
	var inside: Array[Vector3] = []
	var ring: Array[Vector3] = []
	var mo := Vector3.ZERO
	for y in range(lo.y - u, hi.y + u + 1):
		for x in range(lo.x - u, hi.x + u + 1):
			if x < 0 or y < 0 or x >= art.size.x or y >= art.size.y:
				continue
			var c := img.get_pixel(art.position.x + x, art.position.y + y)
			if c.a8 < 255:
				continue
			if cells.has(Vector2i(x, y)):
				inside.append(Vector3(c.r, c.g, c.b))
			else:
				ring.append(Vector3(c.r, c.g, c.b))
				mo += Vector3(c.r, c.g, c.b)
	if inside.is_empty() or ring.is_empty():
		return 0.0
	mo /= float(ring.size())
	var mc: Color = (DB.manufacturers[m] as ManufacturerData).colour
	var d := (Vector3(mc.r, mc.g, mc.b) - mo).normalized()
	var along := PackedFloat32Array()
	for c in ring:
		along.append((c - mo).dot(d))
	along.sort()
	var q := along[int(along.size() * 0.9)]
	var n := 0
	for c in inside:
		if (c - mo).dot(d) > q:
			n += 1
	return float(n) / float(inside.size())


## One berth against the rule, measured off the pictures where they stand in the frame.
func _post_rule(s: YardStandSet, tag: String, show: bool) -> void:
	var img: Image = s._view.canvas() if s._view != null else s._tarp.image
	var at := Vector2i(s.position + s._view.position) if s._view != null else s.thing.position
	var under := YardStandSet.undersides(img, at.x, at.y)
	var seats: Array[int] = []
	for px in s.post_x:
		seats.append(YardStandSet.seat_at(under, px + YardStandSet.POST_HALF))
	var clear := true
	for g in s.guns:
		for px in s.post_x:
			clear = clear and (px + s.post_w - 1 < g.x or px > g.y)
	var old := float(ShipRoom.APART[s.weight])
	var spread := float(s.post_x[1] - s.post_x[0])
	var b := YardStandSet.belly_of(img)
	if show:
		print("  %s: posts %d/%d top %d (seats %s, tuck %d) guns %s belly row %d" % [tag, s.post_x[0] + 19,
			s.post_x[1] + 19, s.post_top, seats, s.room.tuck(), s.guns, at.y + b.x])
	_ok("%s: each post seats on the hull (%s)" % [tag, seats], seats[0] >= 0 and seats[1] >= 0)
	_ok("%s: both level, the higher seat less the tuck (top %d, seats %s)" % [tag, s.post_top, seats],
		s.post_top == mini(seats[0], seats[1]) - s.room.tuck())
	_ok("%s: clear of the belly guns %s" % [tag, s.guns], clear)
	_ok("%s: still holding it (spread %.0f of the old %.0f)" % [tag, spread, old], spread >= 0.8 * old)
	_ok("%s: feet on the berth's row %d" % [tag, s.feet], s.feet == int(ShipRoom.FEET[s.weight]))
	if s._view != null:
		_ok("%s: the belly two under the seat row" % tag, at.y + b.x == int(ShipRoom.SEAT[s.weight]) + 2)
	_ok("%s: inside the picture" % tag, s.thing.position.x >= 0 and s.thing.end.x <= YardFront.W)


## The berths in their places: the light far left, the medium far right, the heavy between and behind.
func _berths() -> void:
	var front := YardFront.new()
	add_child(front)
	front.setup()
	front.show_set(&"korvan", true, 0)
	var L: YardStandSet = front.sets[HullData.Weight.LIGHT]
	var M: YardStandSet = front.sets[HullData.Weight.MEDIUM]
	var Hv: YardStandSet = front.sets[HullData.Weight.HEAVY]
	_ok("berths: the light far left, the medium far right, the heavy between and behind",
		L.post_x.max() < Hv.post_x.min() and Hv.post_x.max() < M.post_x.min() and Hv.feet < L.feet and L.feet == M.feet)
	_ok("berths: the posts stand behind the hull (each set draws its hull last)",
		front.sets.values().all(func(s: YardStandSet) -> bool: return s.get_child(s.get_child_count() - 1) is ShipView))
	front.free()


## Off the pictures: the hull's canvas `img` with its corner at `at` in the
## hall, and each stand's picture where it stands.
func _measure(img: Image, at: Vector2i, P: Dictionary) -> Dictionary:
	var w := img.get_width()
	var hgt := img.get_height()
	# the hull's lowest pixel per hall column, and its mass middle in the hall
	var low := {}
	var sum := 0.0
	var n := 0.0
	var x_lo := 1 << 30
	var x_hi := -1
	for x in w:
		var k := 0
		for y in hgt:
			if img.get_pixel(x, y).a8 >= 128:
				k += 1
				low[at.x + x] = at.y + y
		if k > 0:
			x_lo = mini(x_lo, at.x + x)
			x_hi = maxi(x_hi, at.x + x)
		sum += (float(at.x + x) + 0.5) * float(k)
		n += float(k)
	var mass := sum / n
	var seat := int(P["seat"])
	var d: Array[int] = []
	var gap: Array[int] = []
	var mids: Array[float] = []
	var heights: Array[int] = []
	var xs: Array[int] = []
	for s: Dictionary in P["supports"]:
		var J: Image = s["img"]
		var sx := int(s["x"])
		var sy := int(s["y"])
		heights.append(J.get_height())
		xs.append(sx)
		var first := -1
		var last := -1
		var deepest := -(1 << 30)
		var showing := 0
		var least := 1 << 30
		var tops: Array[int] = []
		for x in J.get_width():
			var t := 1 << 30
			for y in J.get_height():
				if J.get_pixel(x, y).a8 >= 128:
					t = y
					break
			tops.append(t)
			least = mini(least, t)
		for x in J.get_width():
			if tops[x] > maxi(seat - 1, least):
				continue
			if first < 0:
				first = x
			last = x
			var hb: int = low.get(sx + x, -(1 << 20))
			# rows the hull's bottom is below this column's top, less one: -1 is
			# floor showing, 0 touching
			showing += maxi(0, (sy + tops[x] - 1) - hb)
			deepest = maxi(deepest, hb)
		d.append(deepest - (sy + seat - 1))
		gap.append(showing)
		mids.append(float(sx) + float(first + last + 1) * 0.5)
	var pair: Dictionary = P.get("pair", {})
	return {"d": d, "gap": gap, "off": (mids[0] + mids[1]) * 0.5 - mass, "heights": heights,
		"sink": int(pair.get("sink", 0)), "at": xs, "span": [x_lo, x_hi],
		"apart": (mids[1] - mids[0]) / float(x_hi - x_lo + 1)}
