extends Node

## Jon: the medium Korvan sat too high and left. Measured off the pictures, not `_stand`'s numbers.
## Each picture is stood once, as hulls share pictures. Stands one height, hull inside the hall.
## Why: docs/why/YardSeatTest.md#yard-seat

const LEVELS := {"unclaimed": MapGen.Development.UNCLAIMED, "outpost": MapGen.Development.OUTPOST,
	"settlement": MapGen.Development.SETTLEMENT, "city": MapGen.Development.CITY,
	"capital": MapGen.Development.CAPITAL}

## Solari's light keel drops 11 rows, so the best pair sinks 6, still above the slab's row 7.
## Why: docs/why/YardSeatTest.md#sink-limit
const SINK_MAX := 6

var harness := Harness.new()


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
	harness.verdict("yardseattest")
	get_tree().quit(harness.code())


## THE FRONT DOOR (Jon, Nov 11: "the ships are floating above their stands"):
## every manufacturer's three hulls at every grade on the banner yard's stands,
## measured off the pictures as above: no floor between the belly and either
## cradle, the belly on a cradle's seat row, centred, inside the picture; and
## each locked set's tarp down over both cradles' tops.
func _front() -> void:
	var front := YardFront.new()
	add_child(front)
	front.setup()
	if not _ok("front door: the city hall is installed", front.ready_hall):
		front.free()
		return
	var worst := 0
	for m: StringName in DB.STARTABLE:
		for tier in 4:
			front.show_set(m, true, tier)
			for w: HullData.Weight in front.sets:
				var s: YardStandSet = front.sets[w]
				var tag := "front %s %s %s" % [m, HullData.weight_name(w), DB.tier_name(tier)]
				if not _ok("%s: a hull on two stands" % tag, s._view != null and s._stand_x.size() == 2):
					continue
				var r := _measure(s._view.canvas(), Vector2i(s.position + s._view.position), _stood(s))
				worst = maxi(worst, int(r["sink"]))
				if tier == 0:
					print("  front %-8s %-6s hull to cradle top %d,%d rows (0 on the seat, sink %d)  floor showing %d,%d px  centre %+.2f px" % [
						m, HullData.weight_name(w), r["d"][0], r["d"][1], r["sink"], r["gap"][0], r["gap"][1], r["off"]])
				_ok("%s: no rows of floor between the hull and a cradle top (%s px)" % [tag, r["gap"]],
					int(r["gap"][0]) == 0 and int(r["gap"][1]) == 0)
				_ok("%s: the belly rests on a cradle's seat row (rows past it %s, sink %d)" % [tag, r["d"], r["sink"]],
					mini(int(r["d"][0]), int(r["d"][1])) == int(r["sink"]) and int(r["sink"]) <= SINK_MAX)
				_ok("%s: centred on its stands (%+.2f px)" % [tag, r["off"]], absf(float(r["off"])) <= 1.0)
				_ok("%s: the stands' feet on the berth's floor row" % tag,
					s._stand_top + s._stand_img.get_height() == s.feet)
				_ok("%s: inside the picture (%s)" % [tag, r["span"]], int(r["span"][0]) >= 0 and int(r["span"][1]) < YardFront.W)
	print("  front door: the most sunk %d rows" % worst)
	front.show_set(&"solari", false)
	for w: HullData.Weight in front.sets:
		var s: YardStandSet = front.sets[w]
		var tag := "front tarp %s" % HullData.weight_name(w)
		if not _ok("%s: a tarp on two stands" % tag, s._tarp != null and s._tarp.image != null and s._stand_x.size() == 2):
			continue
		var r := _measure(s._tarp.image, s.thing.position, _stood(s))
		print("  %s: tarp hem past the cradle top %d,%d rows, floor showing %d,%d px" % [tag, r["d"][0], r["d"][1], r["gap"][0], r["gap"][1]])
		_ok("%s: the tarp lies down over both cradle tops (%s px of floor)" % [tag, r["gap"]],
			int(r["gap"][0]) == 0 and int(r["gap"][1]) == 0)
	front.free()


## A front berth's stands in `_stand`'s shape, for `_measure`.
func _stood(s: YardStandSet) -> Dictionary:
	var sup: Array = []
	for sx in s._stand_x:
		sup.append({"img": s._stand_img, "x": sx, "y": s._stand_top})
	return {"supports": sup, "seat": s.seat, "pair": {"sink": s.sink}}


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
