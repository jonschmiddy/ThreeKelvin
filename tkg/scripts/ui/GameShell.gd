class_name GameShell
extends Control
## THE WINDOW THE GAME IS SHOWN IN, and the reason it exists is the curve.
##
## The game draws at 960x540 and always has. Until now Godot scaled that whole
## frame to the window for us (`stretch/mode = viewport`), which meant any
## screen shader ran INSIDE the 960x540 frame -- and a curve computed there can
## only blur the art or stagger it, because there is no room between one game
## pixel and the next to put the bend in. Jon, on the blurred version: "REALLY
## blurry and unreadable"; on the staggered one: "the pixels are jagged and
## really bad looking". Both were true.
##
## So the game now renders into a SubViewport of exactly 960x540 -- unchanged,
## every coordinate in the game still means what it meant -- and THIS node draws
## that texture to the window through `screen_filter.gdshader`. The shader runs
## once per SCREEN pixel, so the curve is computed at the size you are actually
## looking at, and each screen pixel still picks one game pixel: crisp art, bent
## glass.
##
## What Godot used to do and this now does by hand:
##   * INTEGER SCALE. The game is drawn at a whole multiple of 960x540 or not at
##     all. A 1.5x picture of pixel art is two different pixel sizes in one
##     image, which is the one thing the art cannot survive.
##   * LETTERBOX. Whatever is left over is black, and the shader paints the
##     corners the curve pushes off the glass to match.
##
## Everything else in the game is inside the SubViewport and does not know this
## node exists. The shot tools still photograph `get_viewport()` from in there,
## so they still write a 960x540 png.

const BASE := Vector2i(960, 540)
const FILTER := preload("res://shaders/screen_filter.gdshader")
const GAME := preload("res://scenes/Main.tscn")

static var instance: GameShell = null
## HOW THE TUBE ENDS. Jon's pick, from the four ways other games do it and then
## from four roundings of the one he chose: OVERSCAN with the corner rounded by
## 26 px and the picture darkening slightly into it. Overscan is what a
## television did -- the outer few per cent of the picture fell off the glass --
## so there is no empty wedge to finish; the rounding is only there because a
## right-angled corner on a bowed picture "is just not nice to look at".
##
## The others are kept for `-- edge=N`: 0 hard edge, 1 overscan square,
## 2 shaped glass, 3 in a bezel, 4 a deeper bezel, 5 and 7 the same rounding at
## 14 and 40 px.
static var _edge_style: int = 6
## AND HOW DARK THE CORNERS GO, while Jon judges it: `-- vig=0.5`. Below zero
## means the look's own number stands.
static var _vig_override: float = -1.0

var view: SubViewport
var _frame: SubViewportContainer
var _mat: ShaderMaterial
## WHAT THE GLASS IS DOING TO THE PICTURE RIGHT NOW, kept so the mouse can be
## put through the same bend. Zero curve means the two spaces agree and there
## is nothing to do.
## WHERE THE UNNUDGED RECT SITS. `_fit` owns it; `_nudge` moves the rect off it
## every frame and back.
var _home: Vector2 = Vector2.ZERO
## A harness has no real pointer, so it can say where to pretend one is.
var _pointer: Vector2 = Vector2(-1, -1)
## How far the straight transform is from the bent one, in game px: the error
## this whole mechanism exists to remove. Read by `-- warptest`.
var _slip: float = 0.0
var _curve: float = 0.0
var _overscan: float = 1.0

func _ready() -> void:
	instance = self
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var back := ColorRect.new()
	back.color = Color.BLACK
	back.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(back)

	_mat = ShaderMaterial.new()
	_mat.shader = FILTER

	_frame = SubViewportContainer.new()
	# STRETCH AND SHRINK TOGETHER. `stretch` alone resizes the SubViewport to the
	# container, which would hand the game a 1920x1080 frame and draw the whole
	# interface at half the size it is designed at. `stretch_shrink` is the
	# factor between them: container 1920x1080, shrink 2, frame 960x540.
	_frame.stretch = true
	_frame.stretch_shrink = 2
	# The shader does its own sampling and wants the real texels either side of
	# an edge, so the container hands it a linear tap rather than a snapped one.
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_frame.material = _mat
	add_child(_frame)

	view = SubViewport.new()
	# NEAREST, LIKE THE REST OF THE PROJECT. `textures/canvas_textures/
	# default_texture_filter` is applied to the ROOT viewport only; a Viewport
	# made in code starts on LINEAR whatever the project says. Every stretched
	# texture in the game was being blended -- which showed up as a sheen across
	# the buttons, because a StyleBoxTexture stretches a 4x4 image over the
	# whole plate and linear sampling smeared its bevel into the middle.
	view.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	# Set for the first frame; `stretch_shrink` owns it from then on.
	view.size = BASE
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	# The game handles its own input; this viewport is where that happens.
	view.handle_input_locally = true
	view.gui_embed_subwindows = true
	_frame.add_child(view)
	view.add_child(GAME.instantiate())
	get_tree().get_root().size_changed.connect(_fit)
	_fit()
	refresh()

	# `-- shellshot[=path]` photographs THE WINDOW, tube and all. `-- shot`
	# photographs the game's own frame from inside the SubViewport, which is
	# what every art harness wants and which no longer shows the glass.
	for a in OS.get_cmdline_user_args():
		if a == "shellshot" or (a as String).begins_with("shellshot="):
			_shell_shot((a as String).split("=")[1] if "=" in a else "user://shell.png")
			break

func _shell_shot(path: String) -> void:
	for _i in 12:
		await RenderingServer.frame_post_draw
	var img := get_tree().get_root().get_texture().get_image()
	img.save_png(path)
	print("[shellshot] %s  %dx%d" % [ProjectSettings.globalize_path(path),
		img.get_width(), img.get_height()])
	get_tree().quit()

## THE POINTER GOES THROUGH THE GLASS, AND SO DOES THE HOVER.
##
## The shader bends the picture per screen pixel and the container that feeds
## the game maps the window to the viewport with a straight divide, so a button
## DRAWN in the corner sat a long way from where it could be CLICKED -- 45 game
## pixels at the top-left tab on the arcade setting. Jon found it by hand and
## his diagnosis was exactly right: the picture moved and the hit boxes did not.
##
## TWO SEPARATE THINGS HAD TO BE BENT, and missing the second is why this took
## three goes and two wrong "fixed" claims:
##
##   THE EVENT decides where a click LANDS. Bending it in place is enough for
##   that, and `-- warptest` measures the whole chain at 0.00 game px.
##
##   THE VIEWPORT'S OWN MOUSE POSITION decides which control is HOVERED. Godot
##   keeps that separately and takes it from the container's local mouse
##   position -- the OS pointer through a straight transform -- so the click
##   goes where the picture says and the highlight goes somewhere else: 6.7
##   game px at the top-left tab on the default look, 45 on the arcade one.
##
##   THIS IS NOT FIXED, and here is what does not work, so nobody spends the
##   day again. Pushing bent events into the SubViewport does not move it --
##   `gui_get_hovered_control()` returns null for every one. Taking the
##   container out of the mouse path (`mouse_filter = IGNORE`) stops the wrong
##   updates and stops the right ones too: the viewport then believes the
##   pointer is outside it and skips GUI picking entirely.
##
##   `view.warp_mouse(bent)` DOES fix it, and it cost Jon his cursor: a
##   SubViewport has no window of its own, so the warp goes to the real one and
##   drags the hardware pointer toward the bend, which feeds the next warp.
##   "My cursor is floating to the center of the screen." It is out.
## `relative` is left alone. It drives panning, the scale it would want differs
## across the screen, and a pan that changed speed toward the corners would be a
## worse bug than the one being fixed.
## THE GLASS MOVES SO THE POINTER DOES NOT HAVE TO.
##
## Everything before this bent the EVENT, which fixed the click and left the
## highlight behind -- Godot works out what is hovered from the container's own
## transform and never looks at an event. Three ways round that are dead:
## pushing bent events (nothing is ever hovered), `mouse_target` (judged by
## hand, no better), and `warp_mouse` (works, and drags the real cursor).
##
## So bend the CONTAINER instead. Godot maps a window point to the game with
## `(point - position) / stretch_shrink`; that is affine and the bend is not,
## but it only has to be right AT ONE POINT -- the pointer. Put the container
## where that arithmetic comes out at the bent pixel and the engine does the
## rest: hover, clicks, drags, tooltips, everything, from the one transform it
## already trusts.
##
## THE PICTURE MUST NOT MOVE WITH IT, so the shader is handed the same nudge in
## UV and samples that much further along. The rect under the image shifts; the
## image does not.
##
## WHAT IT COSTS is a sliver at one edge, however far the nudge went, showing
## the backdrop instead of the picture. It is bounded by the bend itself -- 21
## window px on the default look, about one per cent of the width -- and it
## lands where the tube is already dark, inside the 3% the overscan throws away.
func _nudge() -> void:
	if _frame == null or view == null:
		return
	var k := float(_frame.stretch_shrink)
	if _curve <= 0.0:
		_frame.position = _home
		_mat.set_shader_parameter(&"uv_shift", Vector2.ZERO)
		return
	var p := _pointer if _pointer.x >= 0.0 else get_viewport().get_mouse_position()
	# THE POINTER HAS TO BE ON THE GLASS. Off it -- outside the window, or
	# anywhere at all before the player has moved the mouse -- there is nothing
	# to line up, and lining up with a point a thousand pixels away sends the
	# rect off the screen. The first version of this rendered pure black for
	# exactly that reason, on a shot tool where the cursor was somewhere else.
	if not Rect2(_home, _frame.size).has_point(p):
		_frame.position = _home
		_mat.set_shader_parameter(&"uv_shift", Vector2.ZERO)
		_slip = 0.0
		return
	# Where the engine would put it, and where the picture says it should be.
	var straight := (p - _home) / k
	var bent := _bend_at(p, _home)
	var want := p - bent * k
	# AND THE NUDGE IS BOUNDED BY THE BEND, never more. The bend cannot move a
	# point further than the curve does, so anything past that is arithmetic
	# going wrong rather than a picture to follow.
	var cap := _frame.size * 0.06
	var delta := (want - _home).clamp(-cap, cap)
	# WHOLE GAME PIXELS, NOT FRACTIONS OF ONE. The compensation keeps the
	# picture in the same place -- measured, the best match between a frame with
	# the pointer at the middle and one with it in a corner is at zero shift --
	# but a fractional nudge changes which texel each screen pixel lands on, and
	# on pixel art that crawls as the mouse moves. Rounded to a texel, the
	# sampling is identical and only the rect moves. It costs half a game pixel
	# of aim, which is the precision the snap already worked to.
	delta = (delta / k).round() * k
	_frame.position = _home + delta
	_mat.set_shader_parameter(&"uv_shift", delta / _frame.size)
	_slip = (straight - bent).length()


func _process(_delta: float) -> void:
	_nudge()


## WHERE THE PICTURE IS, in window pixels. A harness asking "which window pixel
## shows this game pixel" needs the rect the glass is drawn in, and should not
## have to go looking for a node to find it.
func frame_rect() -> Rect2:
	return Rect2(_frame.position, _frame.size) if _frame != null else Rect2()


## Window pixel -> the game pixel actually drawn there: the bend, then the snap.
##
## THE SNAP MATTERS. The bend is continuous; the picture is not. `sharp_uv` in
## the shader gives each screen pixel one whole game texel, so the edge you can
## SEE is on a game-pixel boundary while a continuous map puts the hit edge
## anywhere inside that pixel -- half a pixel out, which is what "better, but
## not pixel perfect" feels like. Landing on the middle of the texel the shader
## shows makes the two the same edge by construction.
func _game_at(win: Vector2) -> Vector2:
	return _bend(win).floor() + Vector2(0.5, 0.5)


## The bend alone, in game pixels and without the snap. The same barrel and
## overscan as `screen_filter.gdshader`, in the same order; if that changes,
## this changes with it. Kept separate because it is INVERTIBLE and the snapped
## version is not -- `-- warptest` has to go backwards through it.
func _bend_at(win: Vector2, origin: Vector2) -> Vector2:
	if _frame.size.x <= 0.0 or _frame.size.y <= 0.0:
		return Vector2.ZERO
	var uv := (win - origin) / _frame.size
	var q := (uv - Vector2(0.5, 0.5)) * 2.0
	q *= 1.0 + _curve * q.dot(q)
	q /= _overscan
	uv = (q * 0.5 + Vector2(0.5, 0.5)).clamp(Vector2.ZERO, Vector2.ONE)
	return uv * Vector2(BASE)


## The bend from wherever the rect is now. Kept for `-- warptest`, which asks
## which window pixel draws a given game pixel.
func _bend(win: Vector2) -> Vector2:
	if _frame.size.x <= 0.0 or _frame.size.y <= 0.0:
		return Vector2.ZERO
	var uv := (win - _frame.position) / _frame.size
	var p := (uv - Vector2(0.5, 0.5)) * 2.0
	p *= 1.0 + _curve * p.dot(p)
	p /= _overscan
	uv = (p * 0.5 + Vector2(0.5, 0.5)).clamp(Vector2.ZERO, Vector2.ONE)
	return uv * Vector2(BASE)


## WHERE A SYNTHETIC EVENT GOES. The game lives in the shell's SubViewport now,
## so a harness pushing at `tree.root` is aiming at the window -- the container
## would rescale the position on the way in and the click would land at half the
## coordinate it meant. Harnesses push here instead, in the game's own 960x540
## space. Falls back to the root for anything booted without a shell.
static func input_target(tree: SceneTree) -> Viewport:
	if instance != null and instance.view != null:
		return instance.view
	return tree.root

## The biggest whole multiple of 960x540 that fits, centred.
func _fit() -> void:
	if _frame == null:
		return
	var win := get_viewport_rect().size
	var k := maxi(1, int(floor(minf(win.x / float(BASE.x), win.y / float(BASE.y)))))
	var px := Vector2(BASE) * float(k)
	_frame.stretch_shrink = k
	_frame.size = px
	_home = ((win - px) * 0.5).floor()
	_frame.position = _home
	if _mat != null:
		_mat.set_shader_parameter(&"out_scale", float(k))
	refresh()

## Read the display settings into the shader. Static so DisplaySettings can call
## it without knowing where the shell is.
static func refresh() -> void:
	if instance != null:
		instance._apply()

func _apply() -> void:
	if _mat == null:
		return
	var d := DisplaySettings
	_mat.set_shader_parameter(&"cvd", d.colour_help)
	# TWO THIRDS OF THE WAY, not all of it. Full daltonisation turns every ember
	# in the interface magenta -- it works, and it repaints the game doing it.
	_mat.set_shader_parameter(&"cvd_strength", 0.65)
	_mat.set_shader_parameter(&"contrast", 1.22 if d.high_contrast else 1.0)
	_mat.set_shader_parameter(&"saturation", 1.12 if d.high_contrast else 1.0)
	_mat.set_shader_parameter(&"gamma", d.gamma_value())
	_mat.set_shader_parameter(&"tex_size", Vector2(BASE))
	# The tube, in four strengths. The curve is real now: it is computed per
	# screen pixel, so it bends the picture without softening it.
	var curve := 0.0
	var scan := 0.0
	var mask := 0.0
	## HOW DARK THE CORNERS GO. The tube's ladder, and Jon set its middle rung by
	## eye against four depths shot on the card gallery: 0.55 on the look he
	## plays in, where the corner sits at 64% of the middle and the edges at 57%.
	## The old 0.35 was there and measurable and he could not see it, which is
	## the whole lesson -- a vignette on a screen whose edges are already dark
	## has to be deeper than the arithmetic suggests. The other two keep their
	## distance from it rather than their old numbers.
	var vign := 0.0
	match d.screen_look:
		DisplaySettings.Look.SCANLINES:
			scan = 0.16
		DisplaySettings.Look.CRT_GENTLE:
			curve = 0.03
			scan = 0.14
			vign = 0.55
		DisplaySettings.Look.CRT:
			curve = 0.06
			scan = 0.24
			vign = 0.7
		DisplaySettings.Look.CRT_ARCADE:
			curve = 0.11
			scan = 0.3
			mask = 0.18
			vign = 0.85
	if _vig_override >= 0.0 and vign > 0.0:
		vign = _vig_override
	_mat.set_shader_parameter(&"curve", curve)
	_curve = curve
	# The corner treatment, picked by `-- corner=N` while Jon judges it.
	# HOW THE EDGE OF THE TUBE IS FINISHED. The four ways other games do it,
	# from the survey: leave it flat, overscan past the frame, shape the glass,
	# or set the glass in plastic. `-- edge=N` picks one while Jon judges them.
	var e := int(_edge_style)
	var curved := curve > 0.0
	#  0 hard edge          3 glass in a bezel      6 overscan, rounded 26
	#  1 overscan           4 deeper bezel          7 overscan, rounded 40, shaded
	#  2 shaped glass       5 overscan, rounded 14
	_overscan = [1.0, 1.03, 1.03, 1.03, 1.04, 1.03, 1.03, 1.03][e] as float
	_mat.set_shader_parameter(&"overscan", _overscan)
	_mat.set_shader_parameter(&"corner_radius",
		[0.0, 0.0, 26.0, 26.0, 34.0, 14.0, 26.0, 40.0][e] if curved else 0.0)
	_mat.set_shader_parameter(&"rim_shadow",
		[0.0, 0.0, 0.55, 0.45, 0.5, 0.0, 0.25, 0.4][e] if curved else 0.0)
	_mat.set_shader_parameter(&"rim_light",
		[0.0, 0.0, 0.6, 0.35, 0.35, 0.0, 0.0, 0.25][e] if curved else 0.0)
	_mat.set_shader_parameter(&"bezel", [0.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0][e] if curved else 0.0)
	_mat.set_shader_parameter(&"bezel_px", [0.0, 0.0, 0.0, 22.0, 34.0, 0.0, 0.0, 0.0][e])
	_mat.set_shader_parameter(&"scanline", scan)
	_mat.set_shader_parameter(&"mask_amount", mask)
	_mat.set_shader_parameter(&"vignette", vign)
	# GIVE BACK WHAT THE TUBE TOOK, and get the arithmetic right this time.
	#
	# The first version of this line guessed at two of the three costs, and Jon
	# found it by eye: "CRT mode shouldn't darken the screen much." Measured on
	# the same screen, it was 14% down on the gentle setting, 21% on CRT and 33%
	# on the arcade one. Both guesses were the same mistake -- assuming a mark
	# costs what it costs at its own strength rather than what it costs ACROSS
	# THE WHOLE SCREEN:
	#
	#   VIGNETTE. Its profile is `clamp(r * 0.72, 0, 1) ^ 1.6`, whose mean over
	#   the screen is 0.412, not the 0.2 this assumed. That one number is most of
	#   the darkening.
	#   MASK. It dims two subpixels in three, so it costs `mask * 2/3`, not
	#   `mask / 3`.
	#   SCANLINE. Half the rows at full strength: `scan * 0.5`. This one was
	#   right.
	#
	# The floor is gone with them. It existed to stop the old formula asking for
	# a gain it could not deliver; the shader now rolls its highlights off with a
	# soft knee instead, so a gain of two is a brighter picture rather than a
	# clipped one.
	const VIGNETTE_MEAN := 0.412
	_mat.set_shader_parameter(&"gain",
		1.0 / maxf(0.2, (1.0 - scan * 0.5) * (1.0 - mask * 2.0 / 3.0)
			* (1.0 - vign * VIGNETTE_MEAN)))
