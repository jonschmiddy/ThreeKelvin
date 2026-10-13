extends Node

## THE CODED ENGINE FLAME BESIDE TODAY'S, for Jon to pick a look (Oct 13).
##   godot --path . --windowed --position 3840,0 -- sheet=ThrusterSheet out=<dir>
##       [ships=hull_light_s,...,ship_armedtrader,...] [frames=150]
## One film per ship, at the game's own pixel size (1x), each frame a grid:
## columns TODAY | A OVERLOAD | B DRIVE | C SPILL (ThrusterFx.Look), rows IDLE,
## CRUISE, FULL (ThrusterFx.Thrust). TODAY on a player hull is what the game
## shows: no flame at idle (the engines are off in a fight -- ShipView `_burning`)
## and the rigged PixelLab strips at cruise and full (the chassis select, the
## arrival and departure), composited the way ShipView does it: `back` strips,
## then the hull, then the rest, the strip frame at FLAME_HZ. TODAY on a pool
## ship is no flame at all; they have none.
##
## Drawn into a SubViewport as big as the grid, so a heavy's four columns fit
## at 1x. Every clock is the film's, stepped 1/30 s a frame: f_####.png at 30
## fps is true speed. No bob, so the flicker measures the flame alone.
## Each folder gets layout.json: every tile's rect, and per coded look its
## nozzles, its lengths, the ms to build its pictures, and the CPU a frame its
## `draw` costs (measured round the calls, per ship).

const PLAYER := ["hull_light_s", "hull_medium_c", "hull_medium_s", "hull_heavy_s"]
const POOL := ["ship_armedtrader", "ship_ringdrive", "ship_pr_drum"]
const LABEL_H := 14
const ROW_LABEL_W := 44

var _args: PackedStringArray
var _t := 0.0


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


class Stars extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#070a10"))
		var r := RandomNumberGenerator.new()
		r.seed = 11
		for i in int(size.x * size.y / 2400.0):
			var b := r.randf()
			draw_rect(Rect2(Vector2(r.randi_range(0, int(size.x) - 1), r.randi_range(0, int(size.y) - 1)), Vector2.ONE),
				Color("#2a3446") if b < 0.8 else Color("#5d6f88"))


## The coded flame's layer: one additive canvas item over the finished ship.
class FlameLayer extends Control:
	var fx: ThrusterFx
	var thrust := 0
	var origin := Vector2.ZERO
	var clock: Callable
	var cost_us := 0
	func _draw() -> void:
		var t0 := Time.get_ticks_usec()
		fx.draw(self, origin, thrust, clock.call())
		cost_us += Time.get_ticks_usec() - t0


func _image(tex: Texture2D) -> Image:
	var im := tex.get_image()
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	return im


func _hull(name: String) -> HullData:
	for h in DB.hull_frames:
		if h.sprite != null and DB.hull_art_name(h.weight, h.tier) == name:
			return h
	# Not every frame is in the table (no Korvan heavy S): rig one the way the
	# table would, from its art and DB.HULL_EXHAUST.
	var parts := name.split("_")
	var hd := HullData.new()
	hd.weight = {"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM,
		"heavy": HullData.Weight.HEAVY}[parts[1]]
	hd.tier = HullData.TIER_NAMES.find(parts[2].to_upper())
	hd.sprite = DB.hull_sprite(hd.weight, hd.tier)
	DB.set_exhaust(hd, DB.DEFAULT_EXHAUST, hd.tier)
	return hd


## Today's frames for a rigged hull, the ShipView way (`_refresh` -> `_blit_exhaust`).
func _today_frames(h: HullData, hull_img: Image) -> Array:
	var out: Array = []
	var n := maxi(1, h.exhaust_frames)
	for f in n:
		var c := Image.create(hull_img.get_width(), hull_img.get_height(), false, Image.FORMAT_RGBA8)
		for back in [true, false]:
			if not back:
				c.blend_rect(hull_img, Rect2i(Vector2i.ZERO, hull_img.get_size()), Vector2i.ZERO)
			for e in h.thrusters:
				if bool(e.get("back", false)) != back or e.get("tex") == null:
					continue
				var strip := _image(e.tex)
				var fw := strip.get_width() / n
				var fr := strip.get_region(Rect2i(f * fw, 0, fw, strip.get_height()))
				c.blend_rect(fr, Rect2i(Vector2i.ZERO, fr.get_size()), e.at as Vector2i)
		out.append(ImageTexture.create_from_image(c))
	return out


func _label(parent: Node, text: String, at: Vector2) -> void:
	var l := UITheme.body(text, UITheme.CHILL, UITheme.FS_SMALL)
	l.position = at
	parent.add_child(l)


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	var dir := _arg("out")
	DirAccess.make_dir_recursive_absolute(dir)
	var frames := int(_arg("frames", "150"))
	var list: Array = []
	var arg := _arg("ships", "")
	if arg == "":
		list = PLAYER + POOL
	else:
		list = Array(arg.split(","))
	var layer := CanvasLayer.new()
	layer.layer = 120
	GameShell.input_target(tree).add_child(layer)
	for ship in list:
		await _film(ship, dir.path_join(ship), frames, layer)
	tree.quit()


func _film(ship: String, dir: String, frames: int, layer: CanvasLayer) -> void:
	var tree := get_tree()
	DirAccess.make_dir_recursive_absolute(dir)
	var player := ship.begins_with("hull_")
	var hull_img: Image
	var used: Rect2i
	var h: HullData = null
	if player:
		h = _hull(ship)
		hull_img = _image(h.sprite)
		used = hull_img.get_used_rect()
	else:
		var src := _image(load("res://art/subjects/ships/%s.png" % ship))
		hull_img = src
		used = src.get_used_rect()
	var cw := hull_img.get_width()
	var chh := hull_img.get_height()
	# Room for the flame: player canvases carry their own clearance at the
	# stern; a pool ship is cropped to itself, so its burn needs space behind.
	var pad_r := 8 if player else 66
	var tw := cw + 16 + pad_r
	var th := chh + 16
	# THE COLUMNS: today, then one per flame setting. By default the three
	# looks at `fps=`/`rag=`; `set=a_dyn` is Jon's pick, A at the lively speed,
	# before and after "more visually dynamic" and "more sparks and fire".
	var configs: Array = []
	if _arg("set", "") == "a_dyn":
		configs = [{look = 0, name = "A  LIVELY (before)", fps = 8.0, rag = 1.0, dyn = false},
			{look = 0, name = "A  DYNAMIC + SPARKS", fps = 8.0, rag = 1.0, dyn = true}]
	else:
		for lk in 3:
			configs.append({look = lk, name = ThrusterFx.LOOK_NAMES[lk], fps = float(_arg("fps", "8")),
				rag = float(_arg("rag", "1.0")), dyn = false})
	var cols := 1 + configs.size()
	var vw := ROW_LABEL_W + cols * tw
	var vh := LABEL_H + 3 * th
	var sub := SubViewport.new()
	sub.size = Vector2i(vw, vh)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.transparent_bg = false
	sub.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	layer.add_child(sub)
	var bg := Stars.new()
	bg.size = Vector2(vw, vh)
	sub.add_child(bg)
	var heads := ["TODAY"]
	for cf in configs:
		heads.append(cf.name)
	for c in cols:
		_label(sub, heads[c], Vector2(ROW_LABEL_W + c * tw + 8, 1))
	for r in 3:
		_label(sub, ThrusterFx.THRUST_NAMES[r], Vector2(4, LABEL_H + r * th + th / 2 - 6))
	var hull_tex := ImageTexture.create_from_image(hull_img)
	var today: Array = _today_frames(h, hull_img) if player else []
	var today_rects: Array[TextureRect] = []
	var flames: Array[FlameLayer] = []
	var tiles: Array = []
	var looks: Dictionary = {}
	var clock := func() -> float: return _t
	for ci in configs.size():
		var cfg: Dictionary = configs[ci]
		var look: int = cfg.look
		var t0 := Time.get_ticks_usec()
		var fx := ThrusterFx.for_hull(h, hull_img, look, 7) if player else ThrusterFx.for_sprite(hull_img, used, look, 7)
		fx.fps = float(cfg.fps)
		fx.rag = float(cfg.rag)
		fx.dynamic = bool(cfg.dyn)
		fx.particles = bool(cfg.dyn)
		fx.loop_n = 12 if bool(cfg.dyn) else ThrusterFx.LOOP
		var find_ms := (Time.get_ticks_usec() - t0) / 1000.0
		var t1 := Time.get_ticks_usec()
		var lens := []
		for thrust in 3:
			fx.warm_up(thrust)
			lens.append(fx.base_length(thrust))
		var build_ms := (Time.get_ticks_usec() - t1) / 1000.0
		var nz := []
		for n in fx.nozzles:
			var pts: PackedVector2Array = n.pts
			nz.append({rows = pts.size(), first = [pts[0].x, pts[0].y], last = [pts[-1].x, pts[-1].y]})
		looks[ci] = {fx = fx, info = {look = cfg.name, blurb = ThrusterFx.LOOK_BLURB[look], dynamic = bool(cfg.dyn),
			loop_frames = fx.frames(), flame_fps = fx.fps,
			nozzles = nz, lengths = lens, find_ms = snappedf(find_ms, 0.01), build_ms = snappedf(build_ms, 0.01),
			pictures = fx._cache.size() + fx._spill.size()}}
	var starts: Array = _check_starts(h, hull_img, looks) if player else []
	for r2 in 3:
		for c2 in cols:
			var at := Vector2(ROW_LABEL_W + c2 * tw + 8, LABEL_H + r2 * th + 8)
			tiles.append({col = c2, row = r2, rect = [ROW_LABEL_W + c2 * tw, LABEL_H + r2 * th, tw, th]})
			var tr := TextureRect.new()
			tr.texture = hull_tex
			tr.position = at
			tr.size = Vector2(cw, chh)
			tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sub.add_child(tr)
			if c2 == 0:
				if player and r2 > 0:
					today_rects.append(tr)
				continue
			var fl := FlameLayer.new()
			fl.fx = looks[c2 - 1].fx
			fl.thrust = r2
			fl.origin = at
			fl.clock = clock
			fl.size = Vector2(vw, vh)
			fl.material = ThrusterFx.add_material()
			fl.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			sub.add_child(fl)
			flames.append(fl)
	await RenderingServer.frame_post_draw
	for fl2 in flames:
		fl2.cost_us = 0
	var draws := 0
	var worst := 0
	for f in frames:
		_t = float(f) / 30.0
		var step := int(_t * ShipView.FLAME_HZ) % maxi(1, today.size())
		for trr in today_rects:
			trr.texture = today[step]
		var before := 0
		for fl3 in flames:
			before += fl3.cost_us
			fl3.queue_redraw()
		await RenderingServer.frame_post_draw
		var after := 0
		for fl4 in flames:
			after += fl4.cost_us
		worst = maxi(worst, after - before)
		draws += 1
		sub.get_texture().get_image().save_png("%s/f_%04d.png" % [dir, f])
	var per_look := {}
	for look2 in looks.size():
		var tot := 0
		for fl5 in flames:
			if fl5.fx == looks[look2].fx:
				tot += fl5.cost_us
		# three tiles (idle, cruise, full) per look: the cost of ONE ship a frame
		var fx5: ThrusterFx = looks[look2].fx
		looks[look2].info.draw_us_per_ship_frame = snappedf(float(tot) / float(draws) / 3.0, 0.01)
		looks[look2].info.particle_us_per_ship_frame = snappedf(float(fx5.particle_us) / float(draws) / 3.0, 0.01)
		looks[look2].info.particle_px_per_ship_frame = snappedf(float(fx5.particle_px) / float(draws) / 3.0, 0.1)
		per_look[look2] = looks[look2].info
	var meta := {ship = ship, player = player, frames = frames, fps = 30, flame_fps = float(_arg("fps", "8")), flame_rag = float(_arg("rag", "1.0")), set = _arg("set", ""), tile = [tw, th],
		canvas = [cw, chh], hull_at_in_tile = [8, 8], ink_w = looks[0].fx.ink_w, tiles = tiles,
		columns = heads, rows = ThrusterFx.THRUST_NAMES, looks = per_look,
		worst_frame_us_all_tiles = worst, starts = starts,
		today = {strips = h.thrusters.size() if player else 0, frames = today.size(), hz = ShipView.FLAME_HZ}}
	var fa := FileAccess.open(dir.path_join("layout.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify(meta, "  "))
	fa.close()
	var cost := []
	for k9 in per_look:
		cost.append("%s draw %.2f us (particles %.2f us, %.1f px) build %.1f ms" % [per_look[k9].look,
			per_look[k9].draw_us_per_ship_frame, per_look[k9].particle_us_per_ship_frame,
			per_look[k9].particle_px_per_ship_frame, per_look[k9].build_ms])
	print("thrustersheet: %s %dx%d frames=%d nozzles=%d lengths=%s | %s" % [
		ship, vw, vh, frames, looks[0].fx.nozzles.size(), str(looks[0].info.lengths), " | ".join(cost)])
	sub.queue_free()
	await tree.process_frame


## THE NOZZLE CHECK (Jon, Oct 13: the coded flame must leave from where the
## PixelLab flame leaves). Measured on what each draws, not on the rig:
##   today  each strip's VISIBLE start -- per frame, the last column holding a
##          strip pixel that shows (a `back` strip's pixels under the hull do
##          not); the most common one over the frames; the rows showing there in
##          at least half of them.
##   coded  each look's flame picture at every thrust: its last lit column and
##          the rows lit there.
## FAIL when the column is more than 1 px off, or the flame's HEIGHT 2-6 px
## out from its start is under 90% of the strip's there (the strip's middle
## frame; the coded flame's lowest frame). The row span used to have to match
## the strip's start rows, which are its narrowest, and every blunt stern got
## a thin stream out of a big engine (Jon, Oct 13: "too small on the main body").
## Also counts flame pixels on a hull pixel the strip leaves visible (one it
## does not cover in every frame); that must be 0 (heavy S's dome).
func _check_starts(h: HullData, hull_img: Image, looks: Dictionary) -> Array:
	var n := maxi(1, h.exhaust_frames)
	var out: Array = []
	var bad := 0
	var cw := hull_img.get_width()
	var chh := hull_img.get_height()
	# Hull pixels some strip leaves visible: opaque hull not covered by a front strip in every frame.
	var shown := PackedByteArray()
	shown.resize(cw * chh)
	for y in chh:
		for x in cw:
			if hull_img.get_pixel(x, y).a > 0.5:
				shown[y * cw + x] = 1
	var strips: Array = []
	for e in h.thrusters:
		var im := _image(e.tex) if e.get("tex") != null else null
		strips.append(im)
		if im == null or bool(e.get("back", false)):
			continue
		var fw0 := im.get_width() / n
		var at0: Vector2i = e.at
		for y2 in im.get_height():
			for x2 in fw0:
				var all := true
				for i in n:
					if im.get_pixel(i * fw0 + x2, y2).a <= 0.5:
						all = false
						break
				var cx := at0.x + x2
				var cy := at0.y + y2
				if all and cx >= 0 and cy >= 0 and cx < cw and cy < chh:
					shown[cy * cw + cx] = 0
	print("thrustersheet starts: %s" % DB.hull_art_name(h.weight, h.tier))
	print("  %-3s %-5s %-12s %-12s | %-10s %-6s %-12s %-5s %s" % ["eng", "strip", "today col", "today rows", "look", "thrust", "coded col/height", "over", ""])
	for ti in h.thrusters.size():
		var e2: Dictionary = h.thrusters[ti]
		var im2: Image = strips[ti]
		if im2 == null:
			continue
		var fw := im2.get_width() / n
		var at: Vector2i = e2.at
		var back := bool(e2.get("back", false))
		var votes := {}
		var per_frame: Array = []
		for f in n:
			var last := -1
			for x3 in fw:
				for y3 in im2.get_height():
					if im2.get_pixel(f * fw + x3, y3).a <= 0.5:
						continue
					var cx2 := at.x + x3
					var cy2 := at.y + y3
					var hid := back and cx2 >= 0 and cy2 >= 0 and cx2 < cw and cy2 < chh and hull_img.get_pixel(cx2, cy2).a > 0.5
					if not hid:
						last = x3
			per_frame.append(last)
			if last >= 0:
				votes[last] = int(votes.get(last, 0)) + 1
		var col := -1
		for k in votes:
			if col < 0 or int(votes[k]) > int(votes[col]) or (int(votes[k]) == int(votes[col]) and int(k) > col):
				col = int(k)
		var r0 := 1 << 20
		var r1 := -1
		for y4 in im2.get_height():
			var cnt := 0
			for f2 in n:
				if im2.get_pixel(f2 * fw + col, y4).a > 0.5:
					var hid2 := back and hull_img.get_pixel(at.x + col, at.y + y4).a > 0.5
					if not hid2:
						cnt += 1
			if cnt * 2 >= n:
				r0 = mini(r0, at.y + y4)
				r1 = maxi(r1, at.y + y4)
		var today_col := at.x + col
		# The strip's height 2-6 px out from its start, per frame; the middle one.
		var hs: Array = []
		for f3 in n:
			var q0 := 1 << 20
			var q1 := -1
			for x6 in fw:
				var out6 := col - x6
				if out6 < 2 or out6 > 6:
					continue
				for y7 in im2.get_height():
					if im2.get_pixel(f3 * fw + x6, y7).a <= 0.5:
						continue
					# open space only: over plating the strip leaves visible is the
					# hull, and no flame may be drawn there
					var hx := at.x + x6
					var hy := at.y + y7
					if hx >= 0 and hy >= 0 and hx < cw and hy < chh and shown[hy * cw + hx] == 1:
						continue
					q0 = mini(q0, y7)
					q1 = maxi(q1, y7)
			if q1 >= q0:
				hs.append(q1 - q0 + 1)
		hs.sort()
		var today_h: int = hs[hs.size() / 2] if not hs.is_empty() else 0
		for look in looks.size():
			var fx: ThrusterFx = looks[look].fx
			var ni := -1
			for k2 in fx.nozzles.size():
				if int(fx.nozzles[k2].get("thruster", -1)) == ti:
					ni = k2
			for thrust in 3:
				var row := {engine = ti, strip = int(e2.id), back = back, today_col = today_col, today_rows = [r0, r1],
					today_h = today_h,
					look = looks[look].info.look, thrust = ThrusterFx.THRUST_NAMES[thrust]}
				# Every loop frame of a living flame: the start must hold on all of
				# them. The worst frame's numbers are kept.
				var c_lo := 1 << 20
				var c_hi := -1
				var r0_lo := 1 << 20
				var r0_hi := -(1 << 20)
				var r1_lo := 1 << 20
				var r1_hi := -(1 << 20)
				var over := 0
				var ok := ni >= 0
				var h_lo := 1 << 20
				if ni >= 0:
					for fr in fx.frames():
						var c_col := -1
						var c0 := 1 << 20
						var c1 := -1
						var p := fx.plume(ni, fx.nozzle_length(ni, thrust), fr)
						if p.tex != null:
							var pim: Image = (p.tex as ImageTexture).get_image()
							var pat: Vector2i = p.at
							for x5 in pim.get_width():
								for y5 in pim.get_height():
									if pim.get_pixel(x5, y5).a <= 0.0:
										continue
									var gx := pat.x + x5
									var gy := pat.y + y5
									if gx > c_col:
										c_col = gx
									if gx >= 0 and gy >= 0 and gx < cw and gy < chh and shown[gy * cw + gx] == 1:
										over += 1
							for y6 in pim.get_height():
								if c_col - pat.x < pim.get_width() and pim.get_pixel(c_col - pat.x, y6).a > 0.0:
									c0 = mini(c0, pat.y + y6)
									c1 = maxi(c1, pat.y + y6)
							# its height 2-6 px out, the strip's own measure
							var g0 := 1 << 20
							var g1 := -1
							for x8 in pim.get_width():
								var out8 := c_col - (pat.x + x8)
								if out8 < 2 or out8 > 6:
									continue
								for y8 in pim.get_height():
									if pim.get_pixel(x8, y8).a > 0.0:
										g0 = mini(g0, y8)
										g1 = maxi(g1, y8)
							h_lo = mini(h_lo, g1 - g0 + 1 if g1 >= g0 else 0)
						c_lo = mini(c_lo, c_col)
						c_hi = maxi(c_hi, c_col)
						r0_lo = mini(r0_lo, c0)
						r0_hi = maxi(r0_hi, c0)
						r1_lo = mini(r1_lo, c1)
						r1_hi = maxi(r1_hi, c1)
						if c_col < 0 or absi(c_col - today_col) > 1:
							ok = false
				if h_lo < int(ceil(0.9 * float(today_h))):
					ok = false
				if over > 0:
					ok = false
				row.coded_col = [c_lo, c_hi]
				row.coded_rows = [[r0_lo, r0_hi], [r1_lo, r1_hi]]
				row.over_hull = over
				row.coded_h_min = h_lo
				row.frames = fx.frames()
				row.ok = ok
				if not ok:
					bad += 1
				out.append(row)
				if thrust == 2 or not ok:
					var cc := "%d" % c_lo if c_lo == c_hi else "%d..%d" % [c_lo, c_hi]
					var a0 := "%d" % r0_lo if r0_lo == r0_hi else "%d..%d" % [r0_lo, r0_hi]
					var a1 := "%d" % r1_lo if r1_lo == r1_hi else "%d..%d" % [r1_lo, r1_hi]
					print("  %-3d %-5d %-12s %-12s | %-10s %-6s %-18s %-5d %s" % [ti, int(e2.id), "%d%s" % [today_col, " back" if back else ""],
						"%d-%d" % [r0, r1], (looks[look].info.look as String).substr(0, 10), ThrusterFx.THRUST_NAMES[thrust],
						"%s / h%d (strip h%d)" % [cc, h_lo, today_h], over, "ok" if ok else "FAIL"])
	# THE BELL IS FULL: at full burn the hull pixels a strip always covers (heavy
	# S's stern cavity) are at least 90% lit by the coded flame, every look.
	var channel := 0
	for y7 in chh:
		for x7 in cw:
			if hull_img.get_pixel(x7, y7).a > 0.5 and shown[y7 * cw + x7] == 0:
				channel += 1
	var has_bell := false
	for nzb in (looks[0].fx as ThrusterFx).nozzles:
		if (nzb as Dictionary).has("bell"):
			has_bell = true
	# Only a hull with a bell: a strip that laps the hull's edge by a pixel
	# covers a few hull pixels the stream is not meant to fill.
	# And at IDLE (Jon: "The flame should extend slightly out of the ship ...
	# that little depression is the entire exhaust"): the bell at least 90% lit
	# and the flame at least 8 px past the rim, at the idle length and at the
	# shortest its flicker takes it to.
	var rim_x := 1 << 20
	for y10 in chh:
		for x10 in cw:
			if hull_img.get_pixel(x10, y10).a > 0.5 and shown[y10 * cw + x10] == 0:
				rim_x = mini(rim_x, x10)
	if channel > 0 and has_bell:
		for look2 in looks.size():
			var fx2: ThrusterFx = looks[look2].fx
			var cases := [["FULL", fx2.base_length(ThrusterFx.Thrust.FULL)],
				["IDLE", fx2.base_length(ThrusterFx.Thrust.IDLE)],
				["IDLE-1", fx2.base_length(ThrusterFx.Thrust.IDLE) - ThrusterFx.FLICK[ThrusterFx.Thrust.IDLE]]]
			for cs in cases:
				var worst_frac := 2.0
				var worst_past := 1 << 20
				var worst_cov := 0
				for fr2 in fx2.frames():
					var lit := {}
					var min_x := 1 << 20
					for k3 in fx2.nozzles.size():
						var p2 := fx2.plume(k3, int(cs[1]), fr2)
						if p2.tex == null:
							continue
						var pim2: Image = (p2.tex as ImageTexture).get_image()
						var pat2: Vector2i = p2.at
						for y8 in pim2.get_height():
							for x8 in pim2.get_width():
								if pim2.get_pixel(x8, y8).a > 0.0:
									lit[Vector2i(pat2.x + x8, pat2.y + y8)] = true
									min_x = mini(min_x, pat2.x + x8)
					var covered := 0
					for y9 in chh:
						for x9 in cw:
							if hull_img.get_pixel(x9, y9).a > 0.5 and shown[y9 * cw + x9] == 0 and lit.has(Vector2i(x9, y9)):
								covered += 1
					var fr_frac := float(covered) / float(channel)
					if fr_frac < worst_frac:
						worst_frac = fr_frac
						worst_cov = covered
					worst_past = mini(worst_past, rim_x - min_x)
				var idle_case := (cs[0] as String).begins_with("IDLE")
				# 8 px past the rim on heavy S (its idle burn is 19 px); a light hull's
				# shallow bell, with an 11 px idle burn, needs half its burn
				var need_past := mini(8, int(fx2.base_length(ThrusterFx.Thrust.IDLE) / 2))
				var ok2 := worst_frac >= 0.9 and (worst_past >= need_past or not idle_case)
				if not ok2:
					bad += 1
				out.append({fill_check = looks[look2].info.look, thrust = cs[0], length = cs[1], channel_px = channel,
					covered_px = worst_cov, fraction = snappedf(worst_frac, 0.001), past_rim_px = worst_past,
					frames = fx2.frames(), ok = ok2})
				print("  bell at %-6s L=%-3d %-11s worst of %d frames: %d of %d always-covered hull px lit (%.1f%%), %d px past the rim (x %d) %s" % [
					cs[0], cs[1], (looks[look2].info.look as String).substr(0, 11), fx2.frames(), worst_cov, channel, worst_frac * 100.0, worst_past, rim_x,
					"ok" if ok2 else "FAIL"])
	# SPARKS AND FIRE never on the hull: every particle pixel over five seconds
	# at every thrust, against the hull pixels the strip leaves visible.
	for look3 in looks.size():
		var fx3: ThrusterFx = looks[look3].fx
		if not fx3.particles:
			continue
		for thrust3 in 3:
			var on_hull := 0
			var drawn := 0
			for f3 in 150:
				for k4 in fx3.nozzles.size():
					for q in fx3.particles_at(k4, thrust3, float(f3) / 30.0):
						drawn += 1
						var qx: int = q.x
						var qy: int = q.y
						if qx >= 0 and qy >= 0 and qx < cw and qy < chh and shown[qy * cw + qx] == 1:
							on_hull += 1
			var ok3 := on_hull == 0
			if not ok3:
				bad += 1
			out.append({particle_check = looks[look3].info.look, thrust = ThrusterFx.THRUST_NAMES[thrust3],
				particle_px = drawn, on_hull_px = on_hull, ok = ok3})
			print("  particles %-6s %-20s %d px over 150 frames, %d on visible hull %s" % [ThrusterFx.THRUST_NAMES[thrust3],
				looks[look3].info.look, drawn, on_hull, "ok" if ok3 else "FAIL"])
	print("thrustersheet starts %s: %s (%d rows, %d off)" % [DB.hull_art_name(h.weight, h.tier),
		"PASS" if bad == 0 else "FAIL", out.size(), bad])
	return out
