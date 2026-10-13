extends Node

## THE DEATH-ANIMATION STYLES SIDE BY SIDE, for Jon to pick one (Oct 13).
##   godot --path . --fixed-fps 30 --windowed --position 3840,0 -- sheet=DeathStyles
##       out=<dir> [boss] [style=0|1|2] [ships=cutter,sprite] [frames=N]
## Without `boss`: three columns (SNAP, BURN, IMPLODE), a row per ship, every
## column breaking at the same moment on a dark sky. `cutter` is the drawn
## Rustjaw (EnemyArt's own canvas, starfield and all); `sprite` is a kept pool
## ship (art/subjects/ships), standing in for the PixelLab enemy sprites that are
## replacing the drawings -- the cut must work on either. `boss` films The
## Custodian's long version in the chosen `style`, ending on its body.
## Every clock is stepped 1/30 s a frame, so f_####.png at 30 fps is true speed.
##
## `each [styles=3,4,...]` films every style on its own (default all sixteen)
## into out/<id>/f_####.png, the same layout every time so a page can tile
## them: A-M on the Cutter and the pool ship, N-P (the creature deaths) on the
## Voidwhale Calf at 70% and the Void Leviathan (tools/art_pool/megafauna);
## `eachships=custodian,cutter` puts other enemies in the two ship rows.
## Each folder gets meta.json: the moments the breakup fired and when (what
## sounds follow), its length, and whether its last frame is `wreck_image`
## pixel for pixel (`rest_image` against `wreck_image`, both ships).

var _args: PackedStringArray
var _breaks: Array[ShipBreakup] = []
var _stage: Control
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
		for i in 220:
			stars.append([Vector2(r.randi_range(0, 959), r.randi_range(0, 539)), r.randf()])
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("#070a10"))
		for s in stars:
			var b: float = s[1]
			draw_rect(Rect2(s[0], Vector2.ONE), Color("#2a3446") if b < 0.8 else Color("#5d6f88"))


func _ship_image(kind: String) -> Array:
	if kind == "sprite":
		var tex: Texture2D = load("res://art/subjects/ships/%s.png" % _arg("sprite", "ship_armedtrader"))
		var src := tex.get_image()
		if src.is_compressed():
			src.decompress()
		src.convert(Image.FORMAT_RGBA8)
		var ink := src.get_used_rect()
		var canvas := Image.create(EnemyArt.W, EnemyArt.H, false, Image.FORMAT_RGBA8)
		var at := Vector2i((EnemyArt.W - ink.size.x) / 2, (EnemyArt.H - ink.size.y) / 2)
		canvas.blend_rect(src, ink, at)
		return [canvas, Rect2i(at, ink.size)]
	var art := EnemyArt.new()
	var e := Combat.EnemyState.new()
	e.template = DB.enemies[StringName(kind)]
	e.max_hp = 30
	e.hp = 30
	art.set_enemy(e, false)
	var img: Image = art._img.duplicate()
	var used := art.used_rect()
	art.free()
	return [img, used]


func _label(text: String, at: Vector2) -> void:
	var l := UITheme.body(text, UITheme.CHILL, UITheme.FS_SMALL)
	l.position = at
	_stage.add_child(l)


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	_dir = _arg("out")
	DirAccess.make_dir_recursive_absolute(_dir)
	var layer := CanvasLayer.new()
	layer.layer = 120
	GameShell.input_target(tree).add_child(layer)
	if "each" in _args:
		await _run_each(layer)
		tree.quit()
		return
	_stage = StarSky.new()
	_stage.size = Vector2(960, 540)
	_stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(_stage)
	var boss := "boss" in _args
	var frames := int(_arg("frames", "120" if boss else "84"))
	if boss:
		var pic := _ship_image(_arg("ship", "custodian"))
		var b := ShipBreakup.new()
		b.size = Vector2(960, 540)
		b.auto = false
		b.setup(pic[0], pic[1], Vector2(360, 200), int(_arg("style", "0")), 4242, true)
		_stage.add_child(b)
		_breaks.append(b)
		_label("THE CUSTODIAN - %s, boss version" % ShipBreakup.NAMES[int(_arg("style", "0"))], Vector2(24, 20))
		frames = int(ceil((b.duration + 0.9) * 30.0)) + 15
	else:
		var names := ["A  SNAP (fast break-apart)", "B  BURN (slower burning tumble)", "C  IMPLODE (cracked light)"]
		var ships := _arg("ships", "cutter,sprite").split(",")
		for col in 3:
			_label(names[col], Vector2(col * 320 + 18, 14))
		for row in ships.size():
			var pic2 := _ship_image(ships[row])
			for col2 in 3:
				var b2 := ShipBreakup.new()
				b2.size = Vector2(960, 540)
				b2.auto = false
				var cell := Vector2(col2 * 320 + 160, 150 + row * 230)
				b2.setup(pic2[0], pic2[1], cell - Vector2(EnemyArt.W, EnemyArt.H) * 0.5, col2, 4242 + row, false)
				_stage.add_child(b2)
				_breaks.append(b2)
				var tag := "%.2f s" % b2.duration
				_label(tag, cell + Vector2(-20, 70))
		var longest := 0.0
		for bb in _breaks:
			longest = maxf(longest, bb.duration)
		frames = int(ceil((longest + 0.7) * 30.0)) + 15
	var beats: Array = []
	for bi in _breaks.size():
		_breaks[bi].broke.connect(func(s: float) -> void: beats.append([_breaks[bi].t, bi, s]))
	var k := 0
	for f in frames:
		# 15 frames of the whole ship first, then the break.
		if f >= 15:
			for b3 in _breaks:
				b3.advance(1.0 / 30.0)
		await RenderingServer.frame_post_draw
		tree.root.get_texture().get_image().save_png("%s/f_%04d.png" % [_dir, k])
		k += 1
	print("deathstyles: %d frames, breaks %s" % [k, str(beats)])
	tree.quit()


## A creature's picture from the art pool (outside res://), on EnemyArt's canvas,
## `scale` < 1 made smaller (bilinear, then every pixel either solid or gone).
func _creature_image(file: String, scale: float) -> Array:
	var path := ProjectSettings.globalize_path("res://").path_join("../tools/art_pool/megafauna/%s.png" % file)
	var src := Image.load_from_file(path)
	src.convert(Image.FORMAT_RGBA8)
	if scale < 0.999:
		src.resize(int(round(src.get_width() * scale)), int(round(src.get_height() * scale)), Image.INTERPOLATE_BILINEAR)
		for y in src.get_height():
			for x in src.get_width():
				var c := src.get_pixel(x, y)
				if c.a < 0.5:
					src.set_pixel(x, y, Color(0, 0, 0, 0))
				else:
					src.set_pixel(x, y, Color(c.r / c.a if c.a < 1.0 else c.r, c.g / c.a if c.a < 1.0 else c.g,
						c.b / c.a if c.a < 1.0 else c.b, 1.0).clamp())
	var ink := src.get_used_rect()
	var canvas := Image.create(EnemyArt.W, EnemyArt.H, false, Image.FORMAT_RGBA8)
	var at := Vector2i((EnemyArt.W - ink.size.x) / 2, (EnemyArt.H - ink.size.y) / 2)
	canvas.blend_rect(src, ink, at)
	return [canvas, Rect2i(at, ink.size)]


static func style_id(st: int) -> String:
	var parts := (ShipBreakup.NAMES[st] as String).to_lower().split(" ", false)
	return "_".join(parts)


func _run_each(layer: CanvasLayer) -> void:
	var tree := get_tree()
	var list: Array[int] = []
	var arg := _arg("styles", "")
	if arg == "":
		for i in ShipBreakup.Style.size():
			list.append(i)
	else:
		for s in arg.split(","):
			list.append(int(s))
	# `eachships=a,b`: the two ship rows (default the Cutter and a pool ship)
	var ships := []
	for k in _arg("eachships", "cutter,sprite").split(","):
		ships.append(_ship_image(k))
	var beasts := [_creature_image("fan", 0.7), _creature_image("lev_spine", 1.0)]
	for st in list:
		var dir := _dir.path_join(style_id(st))
		DirAccess.make_dir_recursive_absolute(dir)
		var stage := StarSky.new()
		stage.size = Vector2(960, 540)
		stage.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.add_child(stage)
		_stage = stage
		var pics: Array = beasts if st >= ShipBreakup.Style.GLOWOUT else ships
		var bs: Array[ShipBreakup] = []
		var t0 := Time.get_ticks_usec()
		for row in 2:
			var b := ShipBreakup.new()
			b.size = Vector2(960, 540)
			b.auto = false
			var cell := Vector2(480, 192 + row * 172)
			b.setup(pics[row][0], pics[row][1], cell - Vector2(EnemyArt.W, EnemyArt.H) * 0.5, st, 4242 + row, false)
			stage.add_child(b)
			bs.append(b)
		var setup_ms := (Time.get_ticks_usec() - t0) / 2000.0
		_label("%s   %.2f s" % [ShipBreakup.NAMES[st], bs[0].duration], Vector2(312, 110))
		_label(ShipBreakup.BLURB[st], Vector2(24, 14))
		var moments: Array = []
		bs[0].moment.connect(func(kind: StringName, s: float, len: float) -> void:
			moments.append({t = snappedf(bs[0].t, 0.001), kind = String(kind), s = snappedf(s, 0.01), len = len}))
		var frames := 15 + int(ceil(bs[0].duration * 30.0)) + 21
		var tick_us := 0
		var worst_us := 0
		for f in frames:
			if f >= 15:
				var t1 := Time.get_ticks_usec()
				for b2 in bs:
					b2.advance(1.0 / 30.0)
				tick_us += Time.get_ticks_usec() - t1
				worst_us = maxi(worst_us, Time.get_ticks_usec() - t1)
			await RenderingServer.frame_post_draw
			tree.root.get_texture().get_image().save_png("%s/f_%04d.png" % [dir, f])
		var ok := []
		for row2 in 2:
			var a := bs[row2].rest_image()
			var w := ShipBreakup.wreck_image(pics[row2][0], pics[row2][1], 4242 + row2, false, st)
			ok.append(a.get_data() == w.get_data() and bs[row2].done)
		var meta := {id = style_id(st), name = ShipBreakup.NAMES[st], blurb = ShipBreakup.BLURB[st],
			sound = ShipBreakup.SOUND[st], duration = bs[0].duration, start_frame = 15, frames = frames,
			moments = moments, wreck_ok = ok, setup_ms = snappedf(setup_ms, 0.1),
			tick_ms = snappedf(tick_us / 1000.0 / float(frames - 15) / 2.0, 0.01),
			worst_frame_ms = snappedf(worst_us / 2000.0, 0.1),
			creature = st >= ShipBreakup.Style.GLOWOUT}
		var fa := FileAccess.open(dir.path_join("meta.json"), FileAccess.WRITE)
		fa.store_string(JSON.stringify(meta, "  "))
		fa.close()
		print("deathstyles each: %s frames=%d wreck_ok=%s setup=%.1fms tick=%.2fms worst=%.1fms moments=%d" % [
			style_id(st), frames, str(ok), setup_ms, meta.tick_ms, meta.worst_frame_ms, moments.size()])
		stage.queue_free()
		await tree.process_frame
