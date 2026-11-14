class_name BossPlan
extends RefCounted
## The boss plan phase of ShipBreakup: the set pieces laid out as events, lights, emitters and
## shard releases at setup. The film's state stays on `film`; this only plans it.
## Why: docs/why/ShipBreakup.md#boss-set-pieces

var film: ShipBreakup


func _init(the_film: ShipBreakup) -> void:
	film = the_film


func plan_boss() -> void:
	var core: Vector2 = film._bp.core
	var cs := film._origin + core
	var order: Array = range(film._majors.size())
	order.sort_custom(func(a: int, b: int) -> bool: return (film._majors[a].mid as Vector2).x > (film._majors[b].mid as Vector2).x)
	match film.style:
		ShipBreakup.Style.CUST_CASCADE, ShipBreakup.Style.CUST_COLLAPSE, ShipBreakup.Style.CUST_SPLIT:
			_plan_c1(order, core, cs)
		ShipBreakup.Style.CUST_UNMAKING:
			_plan_unmaking(order)
		ShipBreakup.Style.CUST_SUPERNOVA:
			_plan_supernova(core, cs)
		ShipBreakup.Style.HELL_CHAIN:
			_plan_hell_chain()
		ShipBreakup.Style.HELL_BURNOUT:
			_plan_burnout()
		ShipBreakup.Style.HELL_UNCOIL:
			_plan_h3()
	# every shard released lives out before the end
	for s7 in film._shards:
		if float(s7.release) < 90.0:
			s7.life = minf(float(s7.life), ShipBreakup.LIFE[film.style] - 0.1 - float(s7.release))


func _plan_unmaking(order: Array) -> void:
	film._ev(0.0, &"groan", 0.5, 2.8)
	film._hook(0.0, &"duck", 0.5, 7.5)
	for oi2 in order.size():
		var m2: Dictionary = film._majors[order[oi2]]
		m2.glow_col = 1
		m2.glow_keys = [[0.3, 0.25, 0.0], [0.6, 0.5, 0.0], [3.0, 0.25, 0.0], [3.4, 0.0, 0.0]]
		m2.keys = [[0.0, Vector2.ZERO], [0.6, Vector2.ZERO], [3.0, Vector2(m2.own)], [ShipBreakup.LIFE[film.style], Vector2(m2.own)]]
	# the lights go out one by one; a piece goes dark with its last light
	var lt := 0.8
	var last_off := {}
	for L3 in film._bp.lights:
		var lp2: Vector2 = L3.p
		var to := lt + film._rng.randf_range(0.0, 0.1)
		film._blight(lp2, [[0.0, 0.7, 3], [to, 1.0, 5], [to + 0.07, 0.45, 3], [to + 0.14, 0.0, 0]], ShipBreakup.HEAT_RAMP[1])
		var pi := film._piece_of_point(lp2)
		last_off[pi] = maxf(float(last_off.get(pi, 0.0)), to + 0.07)
		film._ev(to, &"light_out", 0.2)
		lt += 2.4 / float(maxi(1, film._bp.lights.size()))
	for pi2 in film._majors.size():
		film._majors[pi2].stage_t = [float(last_off.get(pi2, 3.2))]
	# each facet shatters in turn, slowly, glass glinting
	for oi3 in order.size():
		var mi: int = order[oi3]
		var ts := 3.2 + 0.42 * oi3
		film._ev(ts, &"shatter", 0.45 + 0.05 * oi3)
		film._hook(ts, &"shake", 1.0, 0.15)
		for s2 in film._shards:
			var lab_of: int = int(s2.mark) - 10 if int(s2.mark) >= 10 else -1
			if lab_of == int(film._majors[mi].lab) or (int(s2.mark) < 10 and int(s2.piece) == mi):
				s2.release = ts + film._rng.randf_range(0.0, 0.12)
				s2.speed = film._rng.randf_range(12.0, 30.0)
				s2.life = minf(film._rng.randf_range(1.3, 1.9), ShipBreakup.LIFE[film.style] - 0.15 - float(s2.release))
				s2.glass = true
				s2.spin = film._rng.randf_range(1.2, 2.5) * (1.0 if film._rng.randf() < 0.5 else -1.0)
	film._hook(3.2, &"slowmo", 0.6, 3.6)
	film._hook(3.2 + 0.42 * (order.size() - 1), &"stinger", 0.7, 0.0)
	film._ev(6.6, &"settle", 0.2, 1.2)


func _plan_supernova(core: Vector2, cs: Vector2) -> void:
	film._ev(0.0, &"whine", 0.4, 2.6)
	film._hook(1.0, &"duck", 0.8, 4.0)
	film._hook(1.6, &"shake", 1.0, 0.6)
	film._hook(2.2, &"shake", 2.0, 0.5)
	film._bmaps.append({stages = _nova_maps(), keys = [[0.0, 0, 0.6], [0.35, 1, 0.7], [0.7, 2, 0.75], [1.05, 3, 0.8],
		[1.4, 4, 0.85], [1.75, 5, 0.9], [2.1, 6, 1.0], [2.65, -1, 0.0]], col = Color.WHITE, add = true})
	film._blight(core, [[0.0, 0.6, 4], [0.7, 0.8, 7], [1.4, 1.0, 12], [2.1, 1.0, 20], [2.65, 0.0, 0]], ShipBreakup.HEAT_RAMP[0])
	for m3 in film._majors:
		m3.stage_t = [2.66]
	film._ev(2.6, &"nova", 1.0, 0.0, cs, {fx = &"nova"})
	film._hook(2.6, &"flash", 1.0, 0.45)
	film._hook(2.6, &"slowmo", 0.3, 0.6)
	film._hook(2.6, &"shake", 9.0, 1.4)
	film._hook(2.6, &"stinger", 1.0, 0.0)
	film._ev(2.9, &"ring", 0.5, 1.2, cs, {fx = &"dark"})
	film._bmaps.append({stages = [_ember_map()], keys = [[2.65, 0, 1.0], [3.5, 0, 0.75], [4.5, 0, 0.5], [5.5, 0, 0.25], [6.5, -1, 0.0]],
		col = ShipBreakup.HEAT_RAMP[2], add = true})
	film._emit(3.0, 6.6, 40.0, 9, film._hull_edge_points(3), {v0 = 5.0, v1 = 14.0, l0 = 1.0, l1 = 1.8})
	film._ev(3.0, &"smoulder", 0.3, 4.0)
	for tc2 in [3.4, 4.1, 4.9, 5.8]:
		film._ev(tc2, &"crackle", 0.15)


func _plan_hell_chain() -> void:
	var alarm_pts: Array = []
	for L4 in film._bp.lights:
		alarm_pts.append(L4.p)
		if alarm_pts.size() >= 6:
			break
	if alarm_pts.size() < 4:
		for f in [0.2, 0.45, 0.7]:
			alarm_pts.append(Vector2(film._bp.box.position) + Vector2(float(film._bp.bw) * f, 2.0))
	for ap in alarm_pts:
		var keys: Array = [[0.0, 0.0, 0]]
		var tt := 0.0
		while tt < 2.8:
			var period := 0.33 if tt < 1.6 else 0.2
			keys.append([tt, 1.0, 4])
			keys.append([tt + period * 0.4, 0.0, 0])
			tt += period
		keys.append([2.8, 0.0, 0])
		film._blight(ap, keys, ShipBreakup.ALARM)
	film._ev(0.0, &"alarm", 0.6, 2.8)
	film._hook(0.0, &"duck", 0.5, 6.5)
	var bt := [1.2, 1.55, 1.85, 2.15, 2.4, 2.62]
	for i in bt.size():
		var bp: Vector2 = film._bp.blasts[i]
		film._ev(bt[i], &"blast", 0.4 + 0.08 * i, 0.0, film._origin + bp, {fx = &"pop", mark = 2 + i})
		film._hook(bt[i], &"shake", 2.0, 0.2)
		for s3 in film._shards:
			if int(s3.mark) == 2 + i:
				s3.release = bt[i] + 0.02
				s3.life = film._rng.randf_range(0.7, 1.0)
				s3.speed = film._rng.randf_range(80.0, 160.0)
				var d3 := (Vector2(s3.at) + Vector2(s3.size) * 0.5 - bp)
				s3.dir = d3.normalized() if d3.length() > 0.3 else s3.dir
	for m4 in film._majors:
		var st4: Array = []
		for i2 in bt.size():
			st4.append(bt[i2] + 0.03)
		st4.append(4.62)
		m4.stage_t = st4
		m4.keys = [[0.0, Vector2.ZERO], [4.6, Vector2.ZERO], [5.4, Vector2(m4.own)], [ShipBreakup.LIFE[film.style], Vector2(m4.own)]]
		m4.glow_keys = [[4.6, 1.0, 1.0], [5.2, 1.0, 0.7], [6.0, 0.6, 0.4], [6.8, 0.25, 0.1], [7.2, 0.0, 0.0]]
	# the holds burst and the stolen cargo spills, glowing
	film._ev(3.0, &"rupture", 0.7, 0.0, film._origin + (film._bp.holds[0] as Vector2), {fx = &"hold"})
	film._ev(3.2, &"rupture", 0.6, 0.0, film._origin + (film._bp.holds[1] as Vector2), {fx = &"hold"})
	film._ev(3.0, &"spill", 0.5, 1.6)
	for hi in 2:
		var hp: Vector2 = film._bp.holds[hi]
		var out := (hp - Vector2(film._bp.r.position) - Vector2(float(film._bp.cx), float(film._bp.cy))).normalized()
		film._emit(3.0 + 0.2 * hi, 4.6, 150.0, 8, PackedVector2Array([hp]), {mode = &"dir", dir = out, spread = 0.7,
			v0 = 20.0, v1 = 70.0, l0 = 0.9, l1 = 1.7, big = 0.45})
	# the main reactor
	film._ev(4.6, &"reactor", 1.0, 0.0, film._origin + (film._bp.reactor as Vector2), {fx = &"reactor"})
	film._hook(4.6, &"flash", 0.7, 0.3)
	film._hook(4.6, &"slowmo", 0.4, 0.5)
	film._hook(4.6, &"shake", 7.0, 1.0)
	film._hook(4.6, &"stinger", 1.0, 0.0)
	for s4 in film._shards:
		if int(s4.mark) == 1:
			s4.release = 4.6 + film._rng.randf_range(0.0, 0.05)
			s4.life = film._rng.randf_range(1.0, 1.6)
			s4.speed = film._rng.randf_range(90.0, 200.0)
	film._emit(4.6, 6.6, 60.0, 1, PackedVector2Array(), {mode = &"crack"})
	film._ev(4.7, &"debris", 0.5, 2.0)
	film._ev(5.5, &"cool", 0.2, 1.8)


func _plan_burnout() -> void:
	var emb: Vector2 = film._bp.core
	var bowmost := 1e9
	for L5 in film._bp.lights:
		if (L5.p as Vector2).x < bowmost:
			bowmost = (L5.p as Vector2).x
			emb = L5.p
	film._bp.emblem = emb
	film._ev(0.0, &"ignite", 0.5, 0.0, film._origin + emb, {fx = &"ember_pop"})
	film._ev(0.0, &"roar", 0.5, 5.4)
	film._hook(0.0, &"duck", 0.5, 7.5)
	film._blight(emb, [[0.0, 0.5, 4], [0.6, 0.7, 6], [1.2, 0.85, 8], [1.8, 1.0, 11], [5.0, 1.0, 11], [5.2, 0.0, 0]], Color("#ff4a1e"))
	film._bmaps.append({stages = _fire_maps(emb), keys = [[0.0, 0, 0.7], [0.4, 1, 0.8], [0.8, 2, 0.85], [1.2, 3, 0.9],
		[1.6, 4, 0.95], [2.0, 5, 1.0], [2.4, 6, 1.0], [5.0, 6, 0.6], [5.2, -1, 0.0]], col = ShipBreakup.HEAT_RAMP[2], add = true})
	film._emit(0.2, 5.2, 90.0, 1, PackedVector2Array(), {mode = &"fire"})
	var wt := [2.6, 3.0, 3.35, 3.9, 4.3]
	for i3 in wt.size():
		var xp: float = float(film._bp.box.position.x) + float(film._bp.bw) * film._rng.randf_range(0.2, 0.9)
		var yp: float = float(film._bp.box.position.y) + float(film._bp.bh) * film._rng.randf_range(0.3, 0.7)
		film._ev(wt[i3], &"blast", 0.5, 0.0, film._origin + Vector2(xp, yp), {fx = &"pop"})
		film._hook(wt[i3], &"shake", 2.5, 0.25)
	for m5 in film._majors:
		var j5: int = m5.lab
		var lst := Vector2(0, (2 - j5) * 2)
		m5.keys = [[0.0, Vector2.ZERO], [3.0, Vector2.ZERO], [5.0, lst], [5.2, lst], [7.0, Vector2(m5.own)], [ShipBreakup.LIFE[film.style], Vector2(m5.own)]]
		m5.stage_t = [2.0, 4.5]
		m5.glow_keys = [[5.2, 1.0, 0.9], [5.8, 0.9, 0.6], [6.5, 0.6, 0.35], [7.2, 0.3, 0.1], [7.6, 0.0, 0.0]]
		# trailing fire from each piece's broken edges, against its drift
		film._emit(5.2, 7.4, 45.0, 1, PackedVector2Array(), {mode = &"trail", piece = film._majors.find(m5)})
	film._ev(3.0, &"list", 0.4, 2.0)
	film._ev(5.2, &"break", 0.8, 0.0, film._centre, {fx = &"break"})
	film._hook(5.2, &"shake", 4.0, 0.6)
	film._hook(5.2, &"stinger", 0.8, 0.0)
	for s5 in film._shards:
		s5.release = 5.2 + film._rng.randf_range(0.0, 0.06)
		s5.life = film._rng.randf_range(0.9, 1.4)
		s5.speed = film._rng.randf_range(50.0, 120.0)
	film._ev(5.3, &"debris", 0.4, 2.0)


## SUPERNOVA: the core's light through the glass, a step further each map.
func _nova_maps() -> Array:
	var out: Array = []
	var r: Rect2i = film._bp.r
	var H := {}
	var core: Vector2 = film._bp.core
	var maxd := 1.0
	var pts: Array = []
	for m in film._majors:
		var im: Image = (m.images as Array)[0]
		for y in im.get_height():
			for x in im.get_width():
				if im.get_pixel(x, y).a > 0.0:
					var p := Vector2(m.at) + Vector2(x, y)
					pts.append(p)
					maxd = maxf(maxd, p.distance_to(core))
	for st in 7:
		var reach := maxd * (0.15 + 0.85 * float(st) / 6.0)
		var im2 := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
		for p2 in pts:
			var d := (p2 as Vector2).distance_to(core)
			var lp := Vector2i(p2) - r.position
			var odd := ((lp.x + lp.y) & 1) == 0
			var lv := 0.0
			if d < reach * 0.4:
				lv = 1.0
			elif d < reach * 0.7:
				lv = 0.7
			elif d < reach:
				lv = 0.45 if odd or st == 6 else 0.3
			elif d < reach * 1.15 and odd:
				lv = 0.2
			if st == 6:
				lv = maxf(lv, 0.55)
			if lv > 0.0:
				var c: Color = ShipBreakup.HEAT_RAMP[0].lerp(ShipBreakup.HEAT_RAMP[2], clampf(d / maxd, 0.0, 1.0) * (1.0 - float(st) / 7.0))
				im2.set_pixel(lp.x, lp.y, Color(c.r * lv, c.g * lv, c.b * lv, 1.0))
		out.append(film._tex(im2))
	return out


## SUPERNOVA's embers: a scatter of hull pixels still glowing in the char.
func _ember_map() -> ImageTexture:
	var r: Rect2i = film._bp.r
	var im2 := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	for m in film._majors:
		var im: Image = (m.images as Array)[0]
		for y in im.get_height():
			for x in im.get_width():
				if im.get_pixel(x, y).a > 0.0 and film._rng.randf() < 0.07:
					var lp := Vector2i(m.at) - r.position + Vector2i(x, y)
					var lv := 0.9 if film._rng.randf() < 0.3 else 0.5
					im2.set_pixel(lp.x, lp.y, Color(lv, lv, lv, 1.0))
	return film._tex(im2)


## BURN-OUT: fire across the hull from the emblem, edges brightest.
func _fire_maps(from: Vector2) -> Array:
	var out: Array = []
	var r: Rect2i = film._bp.r
	var maxd := 1.0
	var pts: Array = []
	var edges := {}
	for m in film._majors:
		var im: Image = (m.images as Array)[0]
		for y in im.get_height():
			for x in im.get_width():
				if im.get_pixel(x, y).a <= 0.0:
					continue
				var p := Vector2(m.at) + Vector2(x, y)
				pts.append(p)
				maxd = maxf(maxd, p.distance_to(from))
				if x == 0 or y == 0 or x == im.get_width() - 1 or y == im.get_height() - 1 or im.get_pixel(x - 1, y).a <= 0.0 \
						or im.get_pixel(x + 1, y).a <= 0.0 or im.get_pixel(x, y - 1).a <= 0.0 or im.get_pixel(x, y + 1).a <= 0.0:
					edges[Vector2i(p)] = true
	for st in 7:
		var reach := maxd * (0.12 + 0.88 * float(st) / 6.0)
		var im2 := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
		for p2 in pts:
			var d := (p2 as Vector2).distance_to(from)
			if d > reach:
				continue
			var lp := Vector2i(p2) - r.position
			var odd := ((lp.x + lp.y) & 1) == 0
			var lv := 0.0
			if edges.has(Vector2i(p2)):
				lv = 1.0
			elif d > reach - 6.0:
				lv = 0.6 if odd else 0.4
			else:
				lv = 0.35 if odd else 0.2
			im2.set_pixel(lp.x, lp.y, Color(lv, lv * 0.8, lv * 0.6, 1.0))
		out.append(film._tex(im2))
	return out


# ---------------------------------------------------------------- C1: the cascade, three ways to end

## Jon picked C1, centred, with variants: shatter outward, collapse inward, split along the
## spine.
## Why: docs/why/ShipBreakup.md#custodian-variants
func _plan_c1(order: Array, core: Vector2, cs: Vector2) -> void:
	var n := order.size()
	var crush_at := 4.2 if film.style == ShipBreakup.Style.CUST_COLLAPSE else 4.4
	var blast_at := 5.0 if film.style == ShipBreakup.Style.CUST_COLLAPSE else 4.9
	# 1 the cascade, crack by crack from the small end to the big one
	for oi in n:
		var m: Dictionary = film._majors[order[oi]]
		var tc := 0.25 + 0.32 * float(oi) * 8.0 / float(n)
		m.glow_keys = [[tc, 0.5, 1.0], [tc + 0.1, 0.75, 1.0], [crush_at, 1.0, 1.0], [blast_at, 1.0, 1.0],
			[blast_at + 0.5, 1.0, 0.75], [blast_at + 1.0, 0.75, 0.5], [blast_at + 1.5, 0.5, 0.25],
			[blast_at + 2.0, 0.25, 0.0], [7.3, 0.0, 0.0]]
		m.stage_t = [blast_at + 0.02]
		if n > 8 and oi % 2 == 1:
			continue
		film._ev(tc, &"crack", 0.35 + 0.05 * oi * 8.0 / float(n))
		film._hook(tc, &"shake", 1.0, 0.15)
		var cr := film._crack_points(m)
		if cr.is_empty():
			continue
		var cm := Vector2.ZERO
		for p in cr:
			cm += p
		cm /= float(cr.size())
		var up := -1.0 if (oi / (2 if n > 8 else 1)) % 2 == 0 else 1.0
		var L := film._rng.randf_range(80.0, 140.0)
		film._beam(cm, Vector2(film._rng.randf_range(-0.35, 0.35), up), [[tc, 0.0, 1.0], [tc + 0.12, L, 1.0], [crush_at, L, 1.0],
			[crush_at + 0.2, L * 0.4, 0.7], [crush_at + 0.35, 0.0, 0.0]], true)
		film._flash(film._origin + cm, 10, 0.7, ShipBreakup.GLASS, 0.2)
		film._ev(tc + 0.02, &"beam", 0.3, crush_at - tc)
	for L2 in film._bp.lights:
		film._blight(L2.p, [[0.0, 0.5, 3], [1.0 + film._rng.randf() * 1.5, 0.9, 4], [blast_at, 0.0, 0]], ShipBreakup.HEAT_RAMP[1])
	film._bp.unst_t0 = 3.0
	film._bp.unst_t1 = crush_at
	# 2 the centre swells: a ball of light at the true middle
	film._bspheres.append({p = cs, keys = [[3.0, 2.0, 0.6], [3.4, 6.0, 0.75], [3.8, 11.0, 0.9], [crush_at, 18.0, 1.0],
		[blast_at - 0.05, 3.0, 1.0], [blast_at, 0.0, 0.0]]})
	film._ev(3.0, &"swell", 0.6, crush_at - 3.0)
	film._hook(3.0, &"duck", 0.7, 3.5)
	var lifeT: float = ShipBreakup.LIFE[film.style]
	match film.style:
		ShipBreakup.Style.CUST_CASCADE:
			_plan_c1_cascade(cs, lifeT)
		ShipBreakup.Style.CUST_COLLAPSE:
			_plan_c1_collapse(core, cs, lifeT)
		ShipBreakup.Style.CUST_SPLIT:
			_plan_c1_split(core, cs, lifeT)
	film._hook(blast_at, &"flash", 1.0, 0.3)
	film._hook(blast_at, &"shake", 6.0, 0.9)
	film._hook(blast_at, &"stinger", 1.0, 0.0)
	film._emit(blast_at, 6.8, 70.0, 1, PackedVector2Array(), {mode = &"crack"})
	film._ev(blast_at + 0.1, &"debris", 0.5, 2.0)
	film._ev(blast_at + 0.7, &"cool", 0.2, 1.6)


func _plan_c1_cascade(cs: Vector2, lifeT: float) -> void:
	film._ev(4.4, &"implode", 0.8, 0.5)
	film._hook(4.4, &"slowmo", 0.35, 0.7)
	for m2 in film._majors:
		var d: Vector2 = m2.dir
		m2.keys = [[0.0, Vector2.ZERO], [4.4, Vector2.ZERO], [4.85, -d * 4.0], [4.9, -d * 4.0],
			[5.2, Vector2(m2.own) * 0.75], [6.4, Vector2(m2.own)], [lifeT, Vector2(m2.own)]]
	film._ev(4.9, &"blast", 1.0, 0.0, cs, {fx = &"blast"})
	film._ev(4.9, &"shatter", 0.8, 1.5)
	for s in film._shards:
		s.release = 4.9 + film._rng.randf_range(0.0, 0.05)
		s.life = film._rng.randf_range(1.8, 2.4)
		s.speed = film._rng.randf_range(70.0, 160.0)
		s.spin = film._rng.randf_range(1.5, 3.0) * (1.0 if film._rng.randf() < 0.5 else -1.0)
		s.glass = true
		s.glint2 = float(s.glint) + film._rng.randf_range(0.4, 0.8)


func _plan_c1_collapse(core: Vector2, cs: Vector2, lifeT: float) -> void:
	film._ev(4.2, &"crush", 0.8, 0.8)
	film._hook(4.2, &"shake", 2.0, 0.8)
	film._hook(4.6, &"slowmo", 0.35, 0.6)
	for m3 in film._majors:
		var d3: Vector2 = m3.dir
		var outer := int(m3.lab) % 2 == 1
		var crush := d3 * (-9.0 if outer else -5.0)
		var go := 5.0 if outer else 5.25
		m3.keys = [[0.0, Vector2.ZERO], [4.2, Vector2.ZERO], [4.85, crush], [go, crush],
			[go + 0.25, Vector2(m3.own) * 0.8], [go + 1.2, Vector2(m3.own)], [lifeT, Vector2(m3.own)]]
	film._ev(5.0, &"blast", 1.0, 0.0, cs, {fx = &"ring_light"})
	film._ev(5.0, &"layer", 0.8)
	film._ev(5.25, &"layer", 0.6)
	for s3 in film._shards:
		var dist := (Vector2(s3.at) - core).length()
		var outer2 := dist > 0.3 * float(film._bp.bw)
		s3.release = (5.0 if outer2 else 5.25) + film._rng.randf_range(0.0, 0.05)
		s3.life = film._rng.randf_range(1.3, 1.9)
		s3.speed = film._rng.randf_range(70.0, 150.0)
		s3.glass = true


func _plan_c1_split(core: Vector2, cs: Vector2, lifeT: float) -> void:
	film._ev(4.4, &"implode", 0.8, 0.5)
	film._hook(4.4, &"slowmo", 0.35, 0.6)
	for m4 in film._majors:
		var d4: Vector2 = m4.dir
		m4.keys = [[0.0, Vector2.ZERO], [4.4, Vector2.ZERO], [4.85, -d4 * 3.0], [5.0, -d4 * 3.0],
			[5.6, Vector2(m4.own) * 0.6], [6.8, Vector2(m4.own)], [lifeT, Vector2(m4.own)]]
	film._ev(4.9, &"blast", 1.0, 0.0, cs, {fx = &"blast_small"})
	film._ev(4.95, &"run", 0.7, 0.5)
	var maxd := float(film._bp.bw) * 0.5
	for k5 in 4:
		var dx := maxd * float(k5 + 1) / 4.5
		for side in [-1.0, 1.0]:
			var tp := 4.95 + 0.5 * dx / maxd
			film._ev(tp, &"pop", 0.3, 0.0, cs + Vector2(side * dx, 0.0), {fx = &"spine_pop"})
	film._ev(5.5, &"split", 0.9)
	film._hook(5.5, &"shake", 3.0, 0.4)
	film._ev(5.5, &"shed", 0.4, 1.5)
	for s4 in film._shards:
		var mid4 := Vector2(s4.at) + Vector2(s4.size) * 0.5
		if int(s4.mark) == 3:
			s4.release = 4.95 + 0.5 * absf(mid4.x - core.x) / maxd + film._rng.randf_range(0.0, 0.04)
			s4.dir = Vector2(film._rng.randf_range(-0.4, 0.4), signf(mid4.y - core.y + 0.01)).normalized()
			s4.speed = film._rng.randf_range(25.0, 70.0)
		else:
			s4.release = 5.5 + film._rng.randf_range(0.0, 0.15)
			s4.speed = film._rng.randf_range(40.0, 100.0)
		s4.life = film._rng.randf_range(1.2, 1.8)
		s4.glass = true


func _plan_h3() -> void:
	var lifeT: float = ShipBreakup.LIFE[film.style]
	var emb: Vector2 = film._bp.get("emblem", film._bp.core)
	var es := film._origin + emb
	# 1 the hum, and gold climbing the ribs' seams from the hold outward
	var mid_i := (film._majors.size() - 1) / 2
	var step6 := 2.4 / maxf(1.0, float(mid_i))
	for m6 in film._majors:
		var j6: int = m6.lab
		var ton := 0.3 + absf(float(j6 - mid_i)) * step6
		m6.glow_col = 2
		m6.glow_keys = [[ton, 0.5, 0.0], [ton + 0.1, 0.75, 0.0], [5.6, 1.0, 0.0], [7.0, 1.0, 0.0], [7.6, 0.75, 0.0],
			[8.2, 0.5, 0.0], [8.8, 0.25, 0.0], [9.2, 0.0, 0.0]]
		m6.keys = [[0.0, Vector2.ZERO], [7.0, Vector2.ZERO], [7.5, Vector2(m6.own) * 0.7], [8.6, Vector2(m6.own)], [lifeT, Vector2(m6.own)]]
		m6.stage_t = [7.05]
		film._ev(ton, &"charge", 0.2 + 0.05 * absf(float(j6 - mid_i)))
		# each section trails gold and sparks as it flies
		film._emit(7.0, 8.4, 26.0, 8, PackedVector2Array(), {mode = &"trail", piece = film._majors.find(m6), v0 = 10.0, v1 = 30.0})
		film._emit(7.0, 8.0, 16.0, 0, PackedVector2Array(), {mode = &"trail", piece = film._majors.find(m6), v0 = 40.0, v1 = 110.0})
	film._ev(0.0, &"hum", 0.3, 3.0)
	film._hook(0.0, &"duck", 0.5, 9.0)
	# 2 the salamander device heats red, then white, and burns
	film._blight(emb, [[1.5, 0.7, 6], [2.0, 0.8, 8], [2.6, 0.0, 0]], Color(1.0, 0.2, 0.12))
	film._blight(emb, [[2.6, 0.9, 10], [3.7, 0.0, 0]], ShipBreakup.HEAT_RAMP[2])
	film._blight(emb, [[3.7, 1.0, 12], [4.6, 1.0, 16], [5.6, 0.0, 0]], ShipBreakup.HEAT_RAMP[0])
	film._bspheres.append({p = es, keys = [[3.7, 2.0, 0.8], [4.6, 4.0, 1.0], [5.55, 5.0, 1.0], [5.6, 0.0, 0.0]]})
	film._ev(1.5, &"emblem_heat", 0.4, 4.1)
	film._ev(2.0, &"flames", 0.4, 3.6)
	film._emit(2.0, 5.6, 140.0, 1, PackedVector2Array([emb]), {v0 = 12.0, v1 = 45.0, l0 = 0.3, l1 = 0.6, decay = false, big = 0.5})
	film._ev(5.6, &"emblem_burst", 0.7, 0.0, es, {fx = &"emblem_burst"})
	film._hook(5.6, &"shake", 3.0, 0.3)
	# 3 alarms and shakes building
	var alarm_pts: Array = []
	for L4 in film._bp.lights:
		if (L4.p as Vector2).distance_to(emb) > 6.0:
			alarm_pts.append(L4.p)
		if alarm_pts.size() >= 6:
			break
	for ap in alarm_pts:
		var keys: Array = [[0.0, 0.0, 0]]
		var tt := 3.0
		while tt < 6.4:
			var period := 0.3 if tt < 5.0 else 0.18
			keys.append([tt, 1.0, 4])
			keys.append([tt + period * 0.4, 0.0, 0])
			tt += period
		keys.append([6.4, 0.0, 0])
		film._blight(ap, keys, ShipBreakup.ALARM)
	film._ev(3.0, &"alarm", 0.6, 3.4)
	film._hook(3.5, &"shake", 1.0, 0.3)
	film._hook(4.3, &"shake", 2.0, 0.3)
	film._hook(5.0, &"shake", 3.0, 0.4)
	film._hook(5.8, &"shake", 4.0, 0.4)
	# 4 the holds burst, spilling the stolen goods
	for hi in 2:
		var hp: Vector2 = film._bp.holds[hi]
		film._ev(6.0 + 0.15 * hi, &"rupture", 0.7, 0.0, film._origin + hp, {fx = &"hold_cargo", hold = hi})
		var out := (hp - Vector2((film._bp.r as Rect2i).position) - Vector2(float(film._bp.cx), float(film._bp.cy))).normalized()
		film._emit(6.0 + 0.15 * hi, 7.0, 130.0, 8, PackedVector2Array([hp]), {mode = &"dir", dir = out, spread = 0.7,
			v0 = 20.0, v1 = 70.0, l0 = 0.8, l1 = 1.5, big = 0.45})
	film._ev(6.0, &"spill", 0.5, 1.5)
	# 5 the light breaks out
	film._ev(7.0, &"burst", 1.0, 0.0, film._centre, {fx = &"big_burst"})
	film._hook(7.0, &"flash", 1.0, 0.45)
	film._hook(7.0, &"shake", 9.0, 1.5)
	film._hook(7.0, &"slowmo", 0.3, 0.7)
	film._hook(7.0, &"stinger", 1.0, 0.0)
	# 6 the rib sections fly apart, tumbling, and settle
	film._ev(7.05, &"scatter", 0.6, 1.6)
	for s6 in film._shards:
		s6.release = 7.0 + film._rng.randf_range(0.0, 0.05)
		s6.life = film._rng.randf_range(1.0, 1.6)
		s6.speed = film._rng.randf_range(60.0, 160.0)
	film._ev(8.6, &"cool", 0.2, 0.9)
