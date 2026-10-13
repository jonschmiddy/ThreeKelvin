extends Node

## THE BOSSES' OWN DEATHS, FILMED WITH THEIR SCREEN HOOKS APPLIED (Oct 13).
##   godot --path . --fixed-fps 30 --windowed --position 3840,0 -- sheet=BossDeathSheet
##       out=<dir> [styles=16,17,...] [custodian=<png>] [hellbender=<png>]
## Each style alone, as the fight frames it: your ship on the left, the boss on
## the right, on a dark sky. The set piece's `moment`s that are screen hooks are
## played here as the screen would: `shake` moves the whole view in whole
## pixels, `slowmo` slows the death's own clock (the film runs on), `flash`
## lays white over the screen, and the music cues (`duck`, `stinger`) show as a
## caption, since the film is silent. Out: out/<id>/f_####.png and meta.json
## (every moment with the death's time and the film's, and whether the last
## frame is `wreck_image` pixel for pixel).

## Room round the boss for its pieces to settle in: H3 scatters its rib
## sections up to about 30 px.
const PAD := 40

var _args: PackedStringArray
var _dir := ""


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


class StarSky extends Control:
	var stars: Array = []
	func _ready() -> void:
		var r := RandomNumberGenerator.new()
		r.seed = 11
		for i in 260:
			stars.append([Vector2(r.randi_range(-20, 979), r.randi_range(-20, 559)), r.randf()])
	func _draw() -> void:
		draw_rect(Rect2(Vector2(-20, -20), size + Vector2(40, 40)), Color("#070a10"))
		for s in stars:
			var b: float = s[1]
			draw_rect(Rect2(s[0], Vector2.ONE), Color("#2a3446") if b < 0.8 else Color("#5d6f88"))


class Pic extends Control:
	var tex: Texture2D
	var at := Vector2.ZERO
	func _draw() -> void:
		draw_texture(tex, at)


## A boss picture on a canvas with room round it for the pieces to settle in.
func _boss_image(path: String) -> Array:
	var src: Image
	if path.begins_with("res://"):
		src = (load(path) as Texture2D).get_image()
		if src.is_compressed():
			src.decompress()
	else:
		src = Image.load_from_file(path)
	src.convert(Image.FORMAT_RGBA8)
	var ink := src.get_used_rect()
	var canvas := Image.create(ink.size.x + PAD * 2, ink.size.y + PAD * 2, false, Image.FORMAT_RGBA8)
	canvas.blend_rect(src, ink, Vector2i(PAD, PAD))
	return [canvas, Rect2i(Vector2i(PAD, PAD), ink.size)]


func _player_image() -> Array:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var view := ShipView.new()
	get_tree().root.add_child(view)
	view.magnify(1, 0)
	await get_tree().process_frame
	view.refresh()
	await get_tree().process_frame
	var img: Image = view.canvas().duplicate()
	view.queue_free()
	img.convert(Image.FORMAT_RGBA8)
	return [img]


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	_dir = _arg("out")
	DirAccess.make_dir_recursive_absolute(_dir)
	var layer := CanvasLayer.new()
	layer.layer = 120
	GameShell.input_target(tree).add_child(layer)
	var cust := _boss_image(_arg("custodian", "res://art/sprites/enemies/custodian_tetra.png"))
	var hell := _boss_image(_arg("hellbender", "res://art/sprites/enemies/hellbender_helix.png"))
	var player: Array = await _player_image()
	var list: Array[int] = []
	var arg := _arg("styles", "")
	if arg == "":
		for s in range(ShipBreakup.Style.CUST_CASCADE, ShipBreakup.Style.CUST_SPLIT + 1):
			list.append(s)
	else:
		for s2 in arg.split(","):
			list.append(int(s2))
	for st in list:
		await _film(layer, st, cust if _custodian(st) else hell, player)
	tree.quit()


func _custodian(st: int) -> bool:
	return st in [ShipBreakup.Style.CUST_CASCADE, ShipBreakup.Style.CUST_UNMAKING, ShipBreakup.Style.CUST_SUPERNOVA,
		ShipBreakup.Style.CUST_COLLAPSE, ShipBreakup.Style.CUST_SPLIT]


func _film(layer: CanvasLayer, st: int, boss: Array, player: Array) -> void:
	var tree := get_tree()
	var id := "_".join((ShipBreakup.NAMES[st] as String).to_lower().replace("-", "").split(" ", false))
	var dir := _dir.path_join(id)
	DirAccess.make_dir_recursive_absolute(dir)
	var root := Control.new()
	root.size = Vector2(960, 540)
	layer.add_child(root)
	var stage := StarSky.new()
	stage.size = Vector2(960, 540)
	stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	root.add_child(stage)
	var pp := Pic.new()
	# SIZED. A zero-size Control is dropped from the drawing the moment the
	# shake moves its rect off the origin -- your ship blinked out on every
	# shaken frame (Jon: "the ship disappears still").
	pp.size = Vector2(960, 540)
	pp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pp.tex = ImageTexture.create_from_image(player[0])
	pp.at = (Vector2(220, 300) - Vector2((player[0] as Image).get_size()) * 0.5).round()
	pp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	stage.add_child(pp)
	var bimg: Image = boss[0]
	var origin := (Vector2(660, 262) - Vector2(bimg.get_size()) * 0.5).round()
	var t0 := Time.get_ticks_usec()
	var b := ShipBreakup.new()
	b.size = Vector2(960, 540)
	b.auto = false
	b.setup(bimg, boss[1], origin, st, 4242, false)
	var setup_ms := (Time.get_ticks_usec() - t0) / 1000.0
	stage.add_child(b)
	# `bodyonly`: the hull and its pieces alone -- no light, no hooks -- for the
	# check that the ship itself never blinks
	var body_only := "bodyonly" in _args
	if body_only:
		(b.get_child(1) as CanvasItem).visible = false
	var title := UITheme.body("%s   (%.1f s)" % [ShipBreakup.NAMES[st], b.duration], UITheme.CHILL, UITheme.FS_SMALL)
	title.position = Vector2(24, 14)
	root.add_child(title)
	var cue := UITheme.body("", Color("#e8c37a"), UITheme.FS_SMALL)
	cue.position = Vector2(24, 510)
	root.add_child(cue)
	var flash := ColorRect.new()
	flash.size = Vector2(960, 540)
	flash.color = Color(1, 1, 1, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)
	# the hooks, played
	var moments: Array = []
	var hooks := {shake = [], slow = [], flash = [], cue = []}
	var frame := [0]
	var on_moment := func(kind: StringName, s: float, len: float) -> void:
		moments.append({t = snappedf(b.t, 0.001), film = snappedf(float(frame[0]) / 30.0, 0.001), kind = String(kind),
			s = snappedf(s, 0.01), len = snappedf(len, 0.01)})
		if body_only:
			return
		match kind:
			&"shake":
				hooks.shake.append({f0 = frame[0], frames = int(ceil(len * 30.0)), amp = s})
			&"slowmo":
				hooks.slow.append({f0 = frame[0], frames = int(ceil(len * 30.0)), scale = s})
			&"flash":
				hooks.flash.append({f0 = frame[0], frames = maxi(4, int(ceil(len * 30.0))), s = s})
			&"duck":
				hooks.cue.append({f0 = frame[0], frames = 36, text = "MUSIC: ducks %d%% for %.1f s" % [int(s * 100), len]})
			&"stinger":
				hooks.cue.append({f0 = frame[0], frames = 30, text = "MUSIC: stinger"})
	b.moment.connect(on_moment)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var shake_at := Vector2.ZERO
	var shake_to := Vector2.ZERO
	var offsets: Array = []
	var tick_us := 0
	var worst_us := 0
	var done_at := -1
	var f := 0
	while f < 2000:
		frame[0] = f
		if f >= 15 and not b.done:
			var scale := 1.0
			for sl in hooks.slow:
				if f >= int(sl.f0) and f < int(sl.f0) + int(sl.frames):
					scale = minf(scale, float(sl.scale))
			var u0 := Time.get_ticks_usec()
			b.advance(scale / 30.0)
			var us := Time.get_ticks_usec() - u0
			tick_us += us
			worst_us = maxi(worst_us, us)
		if b.done and done_at < 0:
			done_at = f
		# SHAKE: a jolt that decays, not a random jump every frame (Jon: "Why
		# does the ship flicker in and out when the explosion happen?"). A new
		# direction at most every three frames, eased toward, in whole pixels,
		# its size falling off as (1 - x)^2.
		var amp := 0.0
		for sh in hooks.shake:
			var a := f - int(sh.f0)
			if a >= 0 and a < int(sh.frames):
				var x0 := float(a) / float(sh.frames)
				amp = maxf(amp, float(sh.amp) * (1.0 - x0) * (1.0 - x0))
		if amp >= 0.5:
			if f % 3 == 0:
				var dirv := Vector2.RIGHT.rotated(rng.randf_range(0.0, TAU))
				if shake_to.length() > 0.1 and dirv.dot(shake_to.normalized()) > 0.0:
					dirv = -dirv   # swing back across, so it reads as a jolt
				shake_to = dirv * amp
			shake_at = shake_at.lerp(shake_to, 0.6)
		else:
			shake_to = Vector2.ZERO
			shake_at = shake_at.lerp(Vector2.ZERO, 0.6)
		stage.position = shake_at.round()
		offsets.append([int(stage.position.x), int(stage.position.y)])
		var fa := 0.0
		for fl in hooks.flash:
			var a2 := f - int(fl.f0)
			if a2 >= 0 and a2 < int(fl.frames):
				var x := float(a2) / float(fl.frames)
				# eased out, a new level every frame: no held grey steps
				fa = maxf(fa, float(fl.s) * 0.85 * (1.0 - x) * (1.0 - x))
		flash.color = Color(1, 1, 1, fa)
		var ctext := ""
		for c in hooks.cue:
			if f >= int(c.f0) and f < int(c.f0) + int(c.frames):
				ctext = String(c.text)
		cue.text = ctext
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("%s/f_%04d.png" % [dir, f])
		f += 1
		if done_at >= 0 and f > done_at + 30:
			break
	var ok := b.rest_image().get_data() == ShipBreakup.wreck_image(bimg, boss[1], 4242, false, st).get_data()
	var meta := {id = id, name = ShipBreakup.NAMES[st], blurb = ShipBreakup.BLURB[st], sound = ShipBreakup.SOUND[st],
		boss = "custodian" if _custodian(st) else "hellbender",
		duration = b.duration, film_seconds = snappedf(float(f) / 30.0, 0.01), start_frame = 15, done_frame = done_at,
		frames = f, moments = moments, wreck_ok = ok, offsets = offsets, origin = [origin.x, origin.y],
		canvas = [bimg.get_width(), bimg.get_height()], setup_ms = snappedf(setup_ms, 0.1),
		tick_ms = snappedf(tick_us / 1000.0 / maxf(1.0, float(done_at - 15)), 0.01), worst_ms = snappedf(worst_us / 1000.0, 0.01)}
	var fo := FileAccess.open(dir.path_join("meta.json"), FileAccess.WRITE)
	fo.store_string(JSON.stringify(meta, "  "))
	fo.close()
	print("bossdeath: %s frames=%d wreck_ok=%s setup=%.0fms tick=%.2fms worst=%.1fms moments=%d" % [id, f, str(ok),
		setup_ms, meta.tick_ms, meta.worst_ms, moments.size()])
	if b._plan.has("rib_pts"):
		# the traced rib seams over the sprite, at 2x, to check against it
		var tr: Image = bimg.duplicate()
		for q in (b._plan.rib_pts as PackedVector2Array):
			tr.set_pixel(int(q.x), int(q.y), Color(1.0, 0.1, 0.9))
		tr.resize(tr.get_width() * 2, tr.get_height() * 2, Image.INTERPOLATE_NEAREST)
		tr.save_png(dir.path_join("rib_trace_2x.png"))
		var plain: Image = bimg.duplicate()
		plain.resize(plain.get_width() * 2, plain.get_height() * 2, Image.INTERPOLATE_NEAREST)
		plain.save_png(dir.path_join("rib_plain_2x.png"))
		print("bossdeath: %d rib seams traced" % int(b._plan.rib_count))
	root.queue_free()
	await tree.process_frame
