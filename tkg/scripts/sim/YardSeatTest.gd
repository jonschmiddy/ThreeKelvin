extends Node

## EVERY HULL ON ITS STANDS, headless (`YardScene._stand`):
##   godot --headless --path . -- sheet=YardSeatTest
## Jon, on the medium Korvan in the yard: "The ship needs to sit lower. Like
## actually be on the stands and centered on them. It's too high and to the
## left." For every hull frame the game has (each manufacturer's three, the
## three salvage frames) at every grade, on every level's stands, measured off
## the pictures themselves and not off the numbers `_stand` kept:
##   - ON THE STANDS: across each cap (the stand's columns that reach its seat
##     row), no floor shows between the hull's lowest pixel and the stand's top;
##     the hull's lowest pixel over one of the two caps lies exactly on its
##     contact row (`seat - 1`, plus `sink` rows where a step in the belly
##     needed it, never more than `SINK_MAX`), and over the other it is on
##     it or below it (a fin, a pod, that stand standing up behind it), never
##     above;
##   - CENTRED: the two caps' middles stand within 1 px either side of the
##     hull's mass middle (its opaque pixels' balance, column by column);
##   - the two stands one height (Jon: "Why are the stands two different
##     heights"), and the hull inside the hall.
## Hulls share pictures (only Korvan art exists; every chassis and salvage frame
## draws a Korvan sprite of its weight and grade), so each picture is stood once
## and the frames drawing it are named beside it.

const LEVELS := {"unclaimed": MapGen.Development.UNCLAIMED, "outpost": MapGen.Development.OUTPOST,
	"settlement": MapGen.Development.SETTLEMENT, "city": MapGen.Development.CITY,
	"capital": MapGen.Development.CAPITAL}

## The most rows a hull may be let down past its seat to close a step in its
## belly over a cap: the light B on the unclaimed slab takes 4, its lowest pixel
## then on the slab's row 6, still on the 9-row top face.
const SINK_MAX := 4

var _fails := 0


func _ok(what: String, c: bool) -> bool:
	if not c:
		print("  FAIL %s" % what)
		_fails += 1
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
				var r := _measure(v, P)
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
	print("yardseattest: %s" % ("PASS" if _fails == 0 else "FAIL (%d)" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


## Off the pictures: the hull's canvas where its view stands, and each stand's
## picture where it stands.
func _measure(v: ShipView, P: Dictionary) -> Dictionary:
	var img: Image = v.canvas()
	var at := Vector2i(v.position)
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
