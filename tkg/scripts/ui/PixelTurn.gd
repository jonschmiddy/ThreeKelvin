class_name PixelTurn
extends RefCounted

## HOW PIXEL ART TURNS, game-wide (Jon: "can these rotate smoothly WITHOUT
## shimmer? like can we just fix that for the whole game?").
##
## A picture turned by a fraction of a pixel a frame re-picks its pixels every
## frame, and where a thin line or a corner sits across the pixel grid a pixel
## goes A, B, A: shimmer. Three ways to turn, one switch:
##
##   SMOOTH   as the game has always done it (the default): a tumbling piece
##            turned live on screen, a world's surface turned by any fraction
##            of a pixel a frame, the mines a picture every 15 degrees.
##   STEPPED  held still and moved a whole pixel at a time (the farthest pixel
##            of a piece, a world's equator). No shimmer, but it ticks. Jon has
##            turned this down twice ("i guess i kinda just liked the smoother
##            one"); kept only to compare against.
##   BLENDED  turned every frame and held steady: each pixel is worked out from
##            many points across it (a piece: 16, the commonest colour wins; a
##            world: 4, the commonest ground wins, its brightness the average),
##            and a pixel keeps what it showed until the new answer is clearly
##            better (hysteresis), letting go after `RELEASE` frames so nothing
##            low-contrast freezes. A world's value is also eased 0.35 a frame.
##            The star-chart mockup's planets, which Jon took, for every world
##            and for every turning sprite (`Turner`, `pixel_turn.gdshader`).
##
## WORLDS BLENDED, SPRITES SOFT. Every world the planet painter draws
## (`PlanetView`: LOCAL's world and its moons and rocks, the painter's moons on
## LOCAL, the map's worlds, the panel's portrait) turns BLENDED (`world_mode`;
## Jon of the giant, the ice moon and a map world: "THESE LOOK GREAT!!!
## Especially for rotating bodies"). The turning sprites (`mode`) turn SOFT:
## BLENDED still shimmered to his eye ("This still shimmers a lot"), and of
## the round-two trials he took the soft turn ("I kinda like C soft turn").
## Harness switches: `turn=blended|stepped|smooth` sets both; `worldmem=off`
## puts the worlds back on today's path, to measure against.
## `rolllive` (harness): the mines' roll turned live in SMOOTH, for the
## comparison page's left-hand clip.
##
## THE SPRITE TRIALS (harness only, `turn=still|rot8|fade|small`, sprites alone;
## the worlds stay BLENDED), after "This still shimmers a lot":
##   STILL    not turned at all: the picture held whole, its drift in whole
##            pixels, and the tumble (or the roll) shown in its LIGHT instead --
##            the star's side swinging round it and a glint rolling across the
##            hull (`local_subject.gdshader`'s `glint`), as a world's terminator
##            and surface move while its outline stays put.
##   ROT8     BLENDED from a picture blown up 8x by Scale2x three times
##            (RotSprite's way: corners and diagonals rounded before the turn),
##            so the turn re-picks fewer stair-steps.
##   SOFT     turned with its 16 points averaged in linear light and its edge
##            partly clear: a soft turn, no pixel ever picked.
##   `small`  ROT8 with the tumble and the roll cut to `TUMBLE_K` (0.35).
##   FADE     STEPPED's pictures -- each held whole, the next a whole pixel on at
##            its farthest point -- but each step dissolved into the next over
##            `FADE_F` frames in linear light, so the step is a soft move, not a
##            tick, and between steps nothing changes at all.

enum Mode { SMOOTH, STEPPED, BLENDED, STILL, ROT8, SOFT, FADE }

## the turning sprites (`Turner`)
static var mode: Mode = _sprite_mode()
## how much of a piece's tumble and roll is shown (`turn=small`, `tumblek=K`)
static var TUMBLE_K: float = _num("tumblek", 0.35 if "turn=small" in OS.get_cmdline_user_args() else 1.0)
## STILL: how far the light swings for a degree of tumble
static var LIGHT_K: float = _num("lightk", 1.5)
## FADE: frames a step takes to dissolve into the next
static var FADE_F: float = _num("fadef", 8.0)
## the worlds (`PlanetView`'s surface memory)
static var world_mode: Mode = Mode.SMOOTH if "worldmem=off" in OS.get_cmdline_user_args() else _from_args(Mode.BLENDED)
## SMOOTH only: a `roll` (the mines) turned live on screen instead of a picture
## every `roll_step` degrees -- not in the game, only to film what "smooth" is
static var roll_live: bool = "rolllive" in OS.get_cmdline_user_args()

## How long a pixel may be held against a clearly different answer, frames.
static var RELEASE: int = _num("turnrelease", 40)
## A world's value eased this much of the way a frame.
static var EASE: float = _num("turnease", 0.35)
## A world's pixel keeps its shade until its value has moved this far past where
## it last changed.
static var HYST: float = _num("turnhyst", 0.085)
## A sprite's pixel keeps its colour while that colour still covers at least
## this many of its 16 points fewer than the commonest one.
static var MARGIN: int = _num("turnmargin", 4)
## (each settable on a harness's command line, `turnrelease=N` and so on, to tune)

const SHADER := preload("res://shaders/pixel_turn.gdshader")


static func _from_args(d: Mode) -> Mode:
	for a in OS.get_cmdline_user_args():
		match a:
			"turn=blended":
				return Mode.BLENDED
			"turn=stepped":
				return Mode.STEPPED
			"turn=smooth":
				return Mode.SMOOTH
	return d


static func _sprite_mode() -> Mode:
	for a in OS.get_cmdline_user_args():
		match a:
			"turn=still":
				return Mode.STILL
			"turn=rot8", "turn=small":
				return Mode.ROT8
			"turn=soft":
				return Mode.SOFT
			"turn=fade":
				return Mode.FADE
	return _from_args(Mode.SOFT)


## Whether a sprite is turned in a picture of its own (`Turner`).
static func turner() -> bool:
	return mode in [Mode.STEPPED, Mode.BLENDED, Mode.ROT8, Mode.SOFT, Mode.FADE]


## A sprite's turned picture is stored premultiplied with a partly clear edge
## (SOFT, FADE), not picked whole.
static func soft_edge() -> bool:
	return mode == Mode.SOFT or mode == Mode.FADE


## A picture blown up 2x `times` times by Scale2x (EPX): each pixel split in
## four, a quarter taking a neighbour's colour where two neighbours agree across
## its corner, so stair-steps come out as diagonals. Clear is one colour.
static func scale2x(tex: Texture2D, times: int) -> ImageTexture:
	var img := tex.get_image()
	img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var src := PackedInt32Array()
	src.resize(w * h)
	var data := img.get_data()
	for i in w * h:
		var a := data[i * 4 + 3]
		src[i] = 0 if a < 128 else (data[i * 4] << 16 | data[i * 4 + 1] << 8 | data[i * 4 + 2] | 0x1000000)
	for _k in times:
		var out := PackedInt32Array()
		out.resize(w * h * 4)
		var W2 := w * 2
		for y in h:
			for x in w:
				var P := src[y * w + x]
				var A := src[maxi(y - 1, 0) * w + x]
				var B := src[y * w + mini(x + 1, w - 1)]
				var C := src[y * w + maxi(x - 1, 0)]
				var D := src[mini(y + 1, h - 1) * w + x]
				var o := (2 * y) * W2 + 2 * x
				out[o] = A if (C == A and C != D and A != B) else P
				out[o + 1] = B if (A == B and A != C and B != D) else P
				out[o + W2] = C if (D == C and D != B and C != A) else P
				out[o + W2 + 1] = D if (B == D and B != A and D != C) else P
		src = out
		w *= 2
		h *= 2
	var bytes := PackedByteArray()
	bytes.resize(w * h * 4)
	for i in w * h:
		var c := src[i]
		if c != 0:
			bytes[i * 4] = (c >> 16) & 255
			bytes[i * 4 + 1] = (c >> 8) & 255
			bytes[i * 4 + 2] = c & 255
			bytes[i * 4 + 3] = 255
	return ImageTexture.create_from_image(Image.create_from_data(w, h, false, Image.FORMAT_RGBA8, bytes))


static func _num(k: String, d: Variant) -> Variant:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return type_convert(a.substr(k.length() + 1), typeof(d))
	return d


static func smooth() -> bool:
	return mode == Mode.SMOOTH


## A whole-pixel step of a turn for a picture whose farthest pixel is `reach`
## px from its middle: one step moves that pixel one pixel (STEPPED).
static func step_of(reach: float) -> float:
	return 1.0 / maxf(reach, 4.0)


## A TURNING SPRITE, drawn by `pixel_turn.gdshader` into a picture of its own
## (`texture`), never rotated on screen: show `texture` unrotated, unscaled and
## centred where the sprite's middle is. The picture is even on both sides so
## its pixels sit on the screen's.
##
## BLENDED keeps the picture last frame (a second viewport copies it each frame,
## as `map_palette`'s hold does) for the hold. The picture's alpha carries how
## long a pixel has been held, so whatever shows it snaps alpha at a half
## (`local_subject.gdshader`'s `snap_alpha`).
class Turner extends RefCounted:
	var vp: SubViewport
	var copy: SubViewport
	var rect: ColorRect
	var mat: ShaderMaterial
	var src: Texture2D
	## the picture it turns (ROT8: `src` blown up 8x)
	var drawn: Texture2D
	var scl := 1.0
	var flip := false
	var out_size := Vector2i.ZERO
	var _fresh := 2
	## FADE: the step shown, the one fading out, and how far the fade has gone
	var _key := Vector3.INF
	var _was := Vector3.INF
	var _f := 1.0

	## Built under `parent` (any node in the tree that draws it: the viewport it is
	## in renders after this one) for `tex` shown `k` screen pixels a texel, with
	## `pad` px of room on every side for it to drift in (`turn`'s `shift`).
	func _init(parent: Node, tex: Texture2D, k: float, flipped: bool, pad: int = 0) -> void:
		src = tex
		scl = k
		flip = flipped
		drawn = PixelTurn.scale2x(tex, 3) if PixelTurn.mode == PixelTurn.Mode.ROT8 else tex
		var up := float(drawn.get_width()) / float(tex.get_width())
		var sz := Vector2(tex.get_size()) * k
		var d := ceili(sz.length()) + 2 + 2 * pad
		out_size = Vector2i(d + (d & 1), d + (d & 1))
		vp = SubViewport.new()
		vp.size = out_size
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		rect = ColorRect.new()
		rect.size = Vector2(out_size)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		mat = ShaderMaterial.new()
		mat.shader = SHADER
		mat.set_shader_parameter("src", drawn)
		mat.set_shader_parameter("src_size", Vector2(drawn.get_size()))
		mat.set_shader_parameter("out_size", Vector2(out_size))
		mat.set_shader_parameter("scl", k / up)
		mat.set_shader_parameter("soft", PixelTurn.mode == PixelTurn.Mode.SOFT)
		mat.set_shader_parameter("flip", flipped)
		mat.set_shader_parameter("margin", PixelTurn.MARGIN)
		mat.set_shader_parameter("release", PixelTurn.RELEASE)
		rect.material = mat
		vp.add_child(rect)
		if PixelTurn.mode == PixelTurn.Mode.SOFT or PixelTurn.mode == PixelTurn.Mode.FADE:
			mat.set_shader_parameter("ss", 4)
			mat.set_shader_parameter("memory", false)
			mat.set_shader_parameter("fade_on", PixelTurn.mode == PixelTurn.Mode.FADE)
		elif PixelTurn.mode == PixelTurn.Mode.BLENDED or PixelTurn.mode == PixelTurn.Mode.ROT8:
			# last frame's picture: a viewport inside this one renders first, so it
			# copies what this one drew the frame before
			copy = SubViewport.new()
			copy.size = out_size
			copy.transparent_bg = true
			copy.disable_3d = true
			copy.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			var last := TextureRect.new()
			last.texture = vp.get_texture()
			last.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			last.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			last.size = Vector2(out_size)
			# (copied exactly: its alpha is a count, not a coverage)
			var cm := CanvasItemMaterial.new()
			cm.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
			last.material = cm
			copy.add_child(last)
			vp.add_child(copy)
			mat.set_shader_parameter("prev", copy.get_texture())
			mat.set_shader_parameter("ss", 4)
			mat.set_shader_parameter("memory", true)
		else:
			# STEPPED: a picture turned once, pixel for pixel, as `LocalSubject.turned`
			mat.set_shader_parameter("ss", 1)
			mat.set_shader_parameter("memory", false)
		parent.add_child(vp)
		PixelTurn.timed(vp)
		if copy != null:
			PixelTurn.timed(copy)

	func texture() -> Texture2D:
		return vp.get_texture()

	## Whether this was built for that picture at that size.
	func fits(tex: Texture2D, k: float, flipped: bool) -> bool:
		return tex == src and is_equal_approx(k, scl) and flipped == flip

	## The turn this frame, radians, clockwise as `Node2D.rotation`, and where the
	## piece's middle is from the picture's (px, any fraction: its drift, worked
	## out and held with the turn). STEPPED rounds the turn to a whole pixel at the
	## picture's farthest point, and the drift to whole pixels.
	func turn(a: float, shift: Vector2 = Vector2.ZERO) -> void:
		if PixelTurn.mode == PixelTurn.Mode.STEPPED:
			var st := PixelTurn.step_of(0.5 * Vector2(src.get_size()).length() * scl)
			a = roundf(a / st) * st
			shift = shift.round()
		if PixelTurn.mode == PixelTurn.Mode.FADE:
			var st := PixelTurn.step_of(0.5 * Vector2(src.get_size()).length() * scl)
			var k := Vector3(roundf(a / st), roundf(shift.x), roundf(shift.y))
			if _key == Vector3.INF:
				_key = k
				_was = k
			# a new step only once clearly past the half (a tumble turning back at
			# the edge of a step would dissolve back and forth)
			elif k != _key and (absf(a / st - _key.x) > 0.65 or absf(shift.x - _key.y) > 0.65 or absf(shift.y - _key.z) > 0.65):
				_was = _key if _f >= 0.5 else _was
				_key = k
				_f = 0.0
			_f = minf(1.0, _f + 1.0 / PixelTurn.FADE_F)
			var e := _f * _f * (3.0 - 2.0 * _f)
			mat.set_shader_parameter("angle", _key.x * st)
			mat.set_shader_parameter("shift", Vector2(_key.y, _key.z))
			mat.set_shader_parameter("angle_b", _was.x * st)
			mat.set_shader_parameter("shift_b", Vector2(_was.y, _was.z))
			mat.set_shader_parameter("fade", e)
			return
		mat.set_shader_parameter("angle", a)
		mat.set_shader_parameter("shift", shift)
		mat.set_shader_parameter("fresh", _fresh > 0)
		if _fresh > 0:
			_fresh -= 1

	func free_all() -> void:
		if is_instance_valid(vp):
			vp.queue_free()


# ---------------------------------------------------------------- what it costs
## `turncost` on a harness's command line: every viewport the turning makes is
## timed on the GPU, and the CPU time spent keeping them (`cpu_us`, added by the
## callers), and every 120 frames the averages are printed:
## "pixelturn cost: N viewports, gpu X ms/frame, cpu Y ms/frame".
static var cost_on: bool = "turncost" in OS.get_cmdline_user_args()
static var cpu_us := 0
static var _vps: Array = []
static var _gpu := 0.0
static var _frames := 0


static func timed(vp: SubViewport) -> void:
	if not cost_on:
		return
	if _vps.is_empty():
		RenderingServer.frame_post_draw.connect(_tally)
	_vps.append(weakref(vp))
	RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)


static func _tally() -> void:
	var n := 0
	for w: WeakRef in _vps:
		var vp := w.get_ref() as SubViewport
		if vp != null and vp.is_inside_tree():
			_gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
			n += 1
	_frames += 1
	if _frames >= 120:
		print("pixelturn cost: %d viewports, gpu %.3f ms/frame, cpu %.3f ms/frame" % [n, _gpu / _frames, float(cpu_us) / 1000.0 / _frames])
		_frames = 0
		_gpu = 0.0
		cpu_us = 0
