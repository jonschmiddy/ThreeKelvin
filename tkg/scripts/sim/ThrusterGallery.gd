extends Node

## EVERY SHIP IN THE GAME WITH THE CODED FLAME (Jon, Oct 13: "Can I see these
## thrusters for EVERY ship in the game?"). Look A, dynamic, with sparks: the
## one he picked.
##   godot --path . --windowed --position 3840,0 -- sheet=ThrusterGallery out=<dir>
##       [groups=player,pool,enemy] [frames=75]
## One contact sheet per group at 1x, every ship labelled, `frames` at IDLE then
## `frames` at FULL, into out/<group>/f_####.png with layout.json (each ship's
## tile, its engines, its checks). The groups:
##   player  every Korvan hull sprite (light/medium/heavy x C/B/A/S), rigged;
##   pool    every PixelLab pool ship (art/subjects/ships, ship_*): LOCAL's
##           traders and subjects;
##   enemy   every enemy picture in art/sprites/enemies but the Custodian, the
##           Voidwhale Calf and the Leviathan (they get their own movement).
## CHECKS, per ship: player hulls run ThrusterSheet's nozzle/bell/particle check
## against their strips; every ship counts flame and particle pixels on its hull
## (must be 0), and flags engines that look wrong: none found, an engine far
## forward of the stern (a window or a tower, not a nozzle), or a flame whose
## stream runs into the hull (most of its length blocked).

const ENEMY_SKIP := ["custodian_tetra", "whale_fan", "leviathan_lev_spine"]
const LABEL_H := 12

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


class Flame extends Control:
	var fx: ThrusterFx
	var origin := Vector2.ZERO
	var thrust := 0
	var clock: Callable
	func _draw() -> void:
		fx.draw(self, origin, thrust, clock.call())


func _image(tex: Texture2D) -> Image:
	var im := tex.get_image()
	if im.is_compressed():
		im.decompress()
	im.convert(Image.FORMAT_RGBA8)
	return im


func _player_hulls() -> Array:
	var out: Array = []
	for mf: StringName in DB.HULL_ART:
		for w in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
			for tier in 4:
				var name := DB.hull_art_key(w, tier, mf)
				var h: HullData = null
				for hh in DB.hull_frames:
					if hh.sprite != null and DB.hull_art_key(hh.weight, hh.tier, hh.manufacturer) == name:
						h = hh
						break
				if h == null:
					h = HullData.new()
					h.weight = w
					h.tier = tier
					h.manufacturer = mf
					h.sprite = DB.hull_sprite(w, tier, false, mf)
					DB.set_exhaust(h, DB.DEFAULT_EXHAUST, tier)
				if out.any(func(e: Dictionary) -> bool: return e.id == name):
					continue
				out.append({id = name, hull = h, img = _image(h.sprite)})
	return out


func _pictures(dir: String, prefix: String, skip: Array) -> Array:
	var out: Array = []
	var names: Array = []
	# Pictures may come from outside the project (`enemydir=`: art that landed
	# on main after this branch was cut), read as plain files.
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".png") and f.begins_with(prefix) and not ("_half" in f) and not ("_quarter" in f):
			var id := f.get_basename()
			if not (id in skip):
				names.append(id)
	names.sort()
	for id2 in names:
		var img: Image
		if dir.begins_with("res://"):
			img = _image(load(dir.path_join(id2 + ".png")))
		else:
			img = Image.load_from_file(dir.path_join(id2 + ".png"))
			img.convert(Image.FORMAT_RGBA8)
		out.append({id = id2, hull = null, img = img})
	return out


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	var out := _arg("out")
	var frames := int(_arg("frames", "75"))
	var groups := _arg("groups", "player,pool,enemy").split(",")
	var layer := CanvasLayer.new()
	layer.layer = 120
	GameShell.input_target(tree).add_child(layer)
	for g in groups:
		var ships: Array = []
		match g:
			"player":
				ships = _player_hulls()
			"pool":
				ships = _pictures("res://art/subjects/ships", "ship_", [])
			"enemy":
				ships = _pictures(_arg("enemydir", "res://art/sprites/enemies"), "", ENEMY_SKIP)
		# `only=<id>,...`: just those ships (a re-film of the ones that changed)
		var only := _arg("only", "")
		if only != "":
			var keep: Array = []
			for sh in ships:
				if String(sh.id) in only.split(","):
					keep.append(sh)
			ships = keep
			if ships.is_empty():
				continue
		await _film(g, ships, out.path_join(g), frames, layer)
	tree.quit()


func _film(group: String, ships: Array, dir: String, frames: int, layer: CanvasLayer) -> void:
	var tree := get_tree()
	DirAccess.make_dir_recursive_absolute(dir)
	var player := group == "player"
	var tw := 0
	var th := 0
	for s in ships:
		var im: Image = s.img
		# Room for the longest flame and its sparks, so no ship's flame reaches
		# into its neighbour's tile: a player hull's canvas carries some at the
		# stern, given 60 more; a pool ship or an enemy gets 128 behind it. (At
		# 76 the Rustjaw hulk's flame burned across the net ship's nose, and Jon
		# asked what the flame on its front was.)
		tw = maxi(tw, im.get_width() + (76 if player else 136))
		th = maxi(th, im.get_height() + 12 + LABEL_H)
	var cols := 3 if player else 4
	var rows := int(ceil(float(ships.size()) / float(cols)))
	var vw := cols * tw
	var vh := LABEL_H + rows * th
	var sub := SubViewport.new()
	sub.size = Vector2i(vw, vh)
	sub.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sub.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	layer.add_child(sub)
	var bg := Stars.new()
	bg.size = Vector2(vw, vh)
	sub.add_child(bg)
	var phase := UITheme.body("IDLE", UITheme.CHILL, UITheme.FS_SMALL)
	phase.position = Vector2(4, 0)
	sub.add_child(phase)
	var clock := func() -> float: return _t
	var flames: Array[Flame] = []
	var entries: Array = []
	var checker = load("res://scripts/sim/ThrusterSheet.gd").new()
	var fx_us := 0
	for i in ships.size():
		var s2: Dictionary = ships[i]
		var img: Image = s2.img
		var used := img.get_used_rect()
		var tx := (i % cols) * tw
		var ty := LABEL_H + (i / cols) * th
		var at := Vector2(tx + (60 if player else 8), ty + LABEL_H + 4)
		var lab := UITheme.body(s2.id, UITheme.CHILL, UITheme.FS_SMALL)
		lab.position = Vector2(tx + 6, ty)
		sub.add_child(lab)
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(img)
		tr.position = at
		tr.size = Vector2(img.get_size())
		sub.add_child(tr)
		var fx := ThrusterFx.for_hull(s2.hull, img, ThrusterFx.Look.OVERLOAD, 7 + i) if player \
			else ThrusterFx.for_sprite(img, used, ThrusterFx.Look.OVERLOAD, 7 + i, s2.id)
		fx.dynamic = true
		fx.particles = true
		fx.loop_n = 12
		fx.fps = 8.0
		var t0 := Time.get_ticks_usec()
		fx.warm_up(ThrusterFx.Thrust.IDLE)
		fx.warm_up(ThrusterFx.Thrust.FULL)
		var build_ms := (Time.get_ticks_usec() - t0) / 1000.0
		var fl := Flame.new()
		fl.fx = fx
		fl.origin = at
		fl.clock = clock
		fl.size = Vector2(vw, vh)
		fl.material = ThrusterFx.add_material()
		sub.add_child(fl)
		flames.append(fl)
		var e := {id = s2.id, tile = [tx, ty, tw, th], hull_at = [at.x, at.y], size = [img.get_width(), img.get_height()],
			engines = [], build_ms = snappedf(build_ms, 0.1)}
		e.merge(_diagnose(fx, img, used, player or ThrusterFx.engine_override(s2.id) != null), true)
		e.override = ThrusterFx.engine_override(s2.id) != null
		if e.override:
			var fit := _fit_check(fx, img, ThrusterFx.engine_override(s2.id) as Array)
			e.fit = fit
			for f in fit:
				if not bool(f.ok):
					(e.flags as Array).append("engine %d does not fit its nozzle: lights %d of the opening's %d rows at their edge" % [
						int(f.engine), int(f.start_h), int(f.opening_h)])
		if player:
			var looks := {0: {fx = fx, info = {look = "A  DYNAMIC"}}}
			var st: Array = checker._check_starts(s2.hull, img, looks)
			var bad := 0
			for r in st:
				if not bool(r.get("ok", true)):
					bad += 1
			e.nozzle_check = {rows = st.size(), off = bad}
			if bad > 0:
				e.flags.append("nozzle check: %d rows off" % bad)
		entries.append(e)
		print("thrustergallery %-7s %-22s engines %d  flags %s" % [group, s2.id, (e.engines as Array).size(),
			str(e.flags) if not (e.flags as Array).is_empty() else "-"])
	checker.free()
	await RenderingServer.frame_post_draw
	var k := 0
	for thrust in [ThrusterFx.Thrust.IDLE, ThrusterFx.Thrust.FULL]:
		phase.text = ThrusterFx.THRUST_NAMES[thrust]
		for fl2 in flames:
			fl2.thrust = thrust
		for f in frames:
			_t = float(f) / 30.0
			var t1 := Time.get_ticks_usec()
			for fl3 in flames:
				fl3.queue_redraw()
			fx_us += Time.get_ticks_usec() - t1
			await RenderingServer.frame_post_draw
			sub.get_texture().get_image().save_png("%s/f_%04d.png" % [dir, k])
			k += 1
	var meta := {group = group, frames = k, idle_frames = frames, fps = 30, view = [vw, vh], ships = entries,
		look = "A dynamic + sparks, 12 loop frames at 8 fps"}
	var fa := FileAccess.open(dir.path_join("layout.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify(meta, "  "))
	fa.close()
	sub.queue_free()
	await tree.process_frame


## A HAND-PLACED ENGINE FITS ITS NOZZLE (Jon on the domes ship: "Doesn't quite
## fit nozzle"). The opening at the placed column: the contiguous rows round the
## entry's middle whose hull edge is within 2 px of the deepest (not rows
## another engine of the ship claims; a `port` entry is its own opening). The
## flame's start: how many of those rows it lights right at their own edge (on
## the outline, the edge or one past), on its worst loop frame at full burn. It
## fits when that is at least 90% of the opening.
func _fit_check(fx: ThrusterFx, img: Image, entries: Array) -> Array:
	var out: Array = []
	var solid := func(x: int, y: int) -> bool:
		return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height() and img.get_pixel(x, y).a > 0.5
	# rows another engine of this ship claims are not this one's opening
	var claimed := {}
	for i0 in entries.size():
		for y0 in range(int(entries[i0].y0), int(entries[i0].y1) + 1):
			claimed[y0] = i0
	for i in mini(entries.size(), fx.nozzles.size()):
		var d: Dictionary = entries[i]
		var x0 := int(d.x)
		var edges := {}
		for y in range(maxi(0, int(d.y0) - 12), mini(img.get_height(), int(d.y1) + 13)):
			if claimed.has(y) and int(claimed[y]) != i:
				continue
			var x := x0
			var k := 0
			if solid.call(x, y):
				while k <= 12 and solid.call(x, y):
					x += 1
					k += 1
			else:
				while k <= 12 and not solid.call(x - 1, y):
					x -= 1
					k += 1
			if k <= 12:
				edges[y] = x
		var deep := -1
		for y2 in range(int(d.y0), int(d.y1) + 1):
			if edges.has(y2):
				deep = maxi(deep, int(edges[y2]))
		var a := int(d.y0)
		var b := int(d.y1)
		# a deliberate port (a lit engine smaller than the flat stern it sits in,
		# the dish ship's) is its own opening
		if not bool(d.get("port", false)):
			while edges.has(a - 1) and deep - int(edges[a - 1]) <= 2:
				a -= 1
			while edges.has(b + 1) and deep - int(edges[b + 1]) <= 2:
				b += 1
		# the opening is inside the nozzle's rim: a dark rim row at either end is
		# its outline, not its mouth
		while b - a >= 2 and edges.has(a) and edges.has(a + 1) and ThrusterFx._rim_row(img, int(edges[a]) - 1, a, -1) 				and not ThrusterFx._rim_row(img, int(edges[a + 1]) - 1, a + 1, -1):
			a += 1
		while b - a >= 2 and edges.has(b) and edges.has(b - 1) and ThrusterFx._rim_row(img, int(edges[b]) - 1, b, -1) 				and not ThrusterFx._rim_row(img, int(edges[b - 1]) - 1, b - 1, -1):
			b -= 1
		var rows := 0
		for y3 in range(a, b + 1):
			if edges.has(y3):
				rows += 1
		# the flame's start: how many of the opening's rows it lights at their own
		# edge (on the outline, on the edge or one past), on its worst frame
		var covered := 1 << 20
		for fr in fx.frames():
			var p := fx.plume(i, fx.nozzle_length(i, ThrusterFx.Thrust.FULL), fr)
			if p.tex == null:
				covered = 0
				continue
			var pim: Image = (p.tex as ImageTexture).get_image()
			var pat: Vector2i = p.at
			var n := 0
			for y4 in range(a, b + 1):
				if not edges.has(y4):
					continue
				var hit := false
				for dx: int in [-1, 0, 1]:
					var px := int(edges[y4]) + dx - pat.x
					var py := y4 - pat.y
					if px >= 0 and py >= 0 and px < pim.get_width() and py < pim.get_height() and pim.get_pixel(px, py).a > 0.0:
						hit = true
				if hit:
					n += 1
			covered = mini(covered, n)
		out.append({engine = i, opening_rows = [a, b], opening_h = rows, start_h = covered,
			ok = covered >= int(ceil(0.9 * float(rows)))})
	return out


## What can be measured about a ship's engines without looking at it:
##   engines    each nozzle's rows and where it sits;
##   on_hull    flame (every loop frame, idle and full) and particle (five
##              seconds) pixels on the hull's opaque pixels -- must be 0;
##   flags      none found; a nozzle more than 15% of the hull's length
##              forward of its stern; a stream that is mostly blocked by hull.
func _diagnose(fx: ThrusterFx, img: Image, used: Rect2i, player: bool) -> Dictionary:
	var flags: Array = []
	var engines: Array = []
	if fx.nozzles.is_empty():
		flags.append("no engines found")
	var stern_x := used.position.x if player else used.end.x
	for nz in fx.nozzles:
		var pts: PackedVector2Array = nz.pts
		var dir: int = nz.dir
		var x := 0.0
		for p in pts:
			x += p.x
		x /= float(pts.size())
		var fwd := (stern_x - x) * float(dir) if not player else (x - stern_x)
		# blocked: of every stream's first L pixels, how many land on hull
		var L := fx.nozzle_length(fx.nozzles.find(nz), ThrusterFx.Thrust.FULL)
		var blocked := 0
		var total := 0
		for p2 in pts:
			for d in range(1, L + 1):
				total += 1
				if fx._is_solid(int(p2.x) + d * dir, int(p2.y)):
					blocked += 1
		var bfrac := float(blocked) / float(maxi(1, total))
		engines.append({rows = pts.size(), x = snappedf(x, 0.1), y0 = pts[0].y, y1 = pts[-1].y,
			forward_px = snappedf(fwd, 0.1), blocked = snappedf(bfrac, 0.01), bell = nz.has("bell")})
		if not player and fwd > float(used.size.x) * 0.15:
			flags.append("engine %d sits %d px forward of the stern (window or tower?)" % [engines.size() - 1, int(fwd)])
		if bfrac > 0.5 and not nz.has("bell") and not bool(nz.get("behind", false)):
			flags.append("engine %d streams into the hull (%d%% blocked)" % [engines.size() - 1, int(bfrac * 100.0)])
	var on_hull := 0
	var solid := func(px: int, py: int) -> bool:
		return px >= 0 and py >= 0 and px < img.get_width() and py < img.get_height() and img.get_pixel(px, py).a > 0.5
	var chan := {}
	if player:
		# a front strip's always-covered pixels are the flame's own channel
		for y in img.get_height():
			for x2 in img.get_width():
				if img.get_pixel(x2, y).a > 0.5 and not fx._is_solid(x2, y):
					chan[Vector2i(x2, y)] = true
	for n in fx.nozzles.size():
		for thrust in [ThrusterFx.Thrust.IDLE, ThrusterFx.Thrust.FULL]:
			for fr in fx.frames():
				var p3 := fx.plume(n, fx.nozzle_length(n, thrust), fr)
				if p3.tex == null:
					continue
				var pim: Image = (p3.tex as ImageTexture).get_image()
				var pat: Vector2i = p3.at
				for yy in pim.get_height():
					for xx in pim.get_width():
						if pim.get_pixel(xx, yy).a > 0.0 and solid.call(pat.x + xx, pat.y + yy) \
								and not chan.has(Vector2i(pat.x + xx, pat.y + yy)):
							on_hull += 1
			for f in 150:
				for q in fx.particles_at(n, thrust, float(f) / 30.0):
					if solid.call(int(q.x), int(q.y)):
						on_hull += 1
	if on_hull > 0:
		flags.append("%d flame/particle px on the hull" % on_hull)
	# no engine burns shorter at full than one with a smaller mouth, in the same
	# role (a player hull's main drive is its biggest strip; ThrusterSheet)
	for i9 in fx.nozzles.size():
		for j9 in fx.nozzles.size():
			if i9 == j9 or (fx.nozzles[i9] as Dictionary).has("bell") or (fx.nozzles[j9] as Dictionary).has("bell"):
				continue
			var ma := (fx.nozzles[i9].pts as PackedVector2Array).size()
			var mb := (fx.nozzles[j9].pts as PackedVector2Array).size()
			var same_role := bool(fx.nozzles[i9].get("main", false)) == bool(fx.nozzles[j9].get("main", false))
			if same_role and ma > mb + 1 and fx.nozzle_length(i9, ThrusterFx.Thrust.FULL) < fx.nozzle_length(j9, ThrusterFx.Thrust.FULL):
				flags.append("engine %d (%d rows) burns shorter than engine %d (%d rows)" % [i9, ma, j9, mb])
	return {engines = engines, on_hull_px = on_hull, flags = flags}
