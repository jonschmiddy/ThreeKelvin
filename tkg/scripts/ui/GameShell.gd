class_name GameShell
extends Control
## The game renders in a 960x540 SubViewport the shell draws, so the curve is per screen pixel.
## Integer scale only: a 1.5x pixel-art picture mixes two pixel sizes.
## Why: docs/why/GameShell.md#shell-window

const BASE := Vector2i(960, 540)
const FILTER := preload("res://shaders/screen_filter.gdshader")
const GAME := preload("res://scenes/Main.tscn")

static var instance: GameShell = null
## Overscan with a 26 px rounded corner is Jon's pick; the others stay for `-- edge=N`.
## Why: docs/why/GameShell.md#tube-edge
static var _edge_style: int = 6
## AND HOW DARK THE CORNERS GO, while Jon judges it: `-- vig=0.5`. Below zero
## means the look's own number stands.
static var _vig_override: float = -1.0

var view: SubViewport
var _frame: SubViewportContainer
## The black round the glass: above, below, left, right (`_fit_bands`).
var _bands: Array[ColorRect] = []
var _mat: ShaderMaterial
## Kept so the mouse goes through the same bend; `_fit` owns `_home`, `_nudge` moves off it.
var _home: Vector2 = Vector2.ZERO
## What draws the picture through the glass: the game's frame, at `_home`,
## always. The container that takes input moves under the pointer; this does not.
var _glass: TextureRect = null
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

	# Four bands round the glass, not one rect under the window, which drew 4.7M pixels for nobody.
	# Until the glass exists band one is the whole window, as the game boots inside `add_child`.
	# Why: docs/why/GameShell.md#letterbox-bands
	for i in 4:
		var band := ColorRect.new()
		band.color = Color.BLACK
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.visible = i == 0
		add_child(band)
		_bands.append(band)
	_bands[0].set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_mat = ShaderMaterial.new()
	_mat.shader = FILTER

	_frame = SubViewportContainer.new()
	# Stretch and shrink together, or the game gets a 1920x1080 frame at half the design size.
	_frame.stretch = true
	_frame.stretch_shrink = 2
	# The shader does its own sampling and wants the real texels either side of
	# an edge, so the container hands it a linear tap rather than a snapped one.
	_frame.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# The container takes input only and is unseen, so `_nudge` cannot drag the glass edge in.
	# Modulate, not self_modulate or visible: Godot skips drawing at zero modulate; input stays.
	# Why: docs/why/GameShell.md#input-container
	_frame.modulate = Color(1, 1, 1, 0)
	add_child(_frame)

	view = SubViewport.new()
	# Set NEAREST here: the project filter covers the root viewport only, so code-made ones blur.
	# Why: docs/why/GameShell.md#texture-filter
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
	_glass = TextureRect.new()
	_glass.texture = view.get_texture()
	_glass.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glass.stretch_mode = TextureRect.STRETCH_SCALE
	_glass.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glass.material = _mat
	add_child(_glass)
	get_tree().get_root().size_changed.connect(_fit)
	_fit()
	refresh()

	# `shellshot` photographs the window, tube and all; `-- shot` no longer shows the glass.
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

## Bend the container, not events: pushed events never hover and `warp_mouse` drags the cursor.
## The picture is drawn by `_glass` from a still rect, so it does not move with the nudge.
## Why: docs/why/GameShell.md#pointer-through-glass
func _nudge() -> void:
	if _frame == null or view == null:
		return
	var k := float(_frame.stretch_shrink)
	if _curve <= 0.0:
		_frame.position = _home
		_mat.set_shader_parameter(&"uv_shift", Vector2.ZERO)
		return
	var p := _pointer if _pointer.x >= 0.0 else get_viewport().get_mouse_position()
	# Nudge only with the pointer on the glass: a far point sent the rect off screen.
	# Why: docs/why/GameShell.md#pointer-through-glass
	if not Rect2(_home, _frame.size).has_point(p):
		_frame.position = _home
		_mat.set_shader_parameter(&"uv_shift", Vector2.ZERO)
		_slip = 0.0
		return
	# Where the engine would put it, and where the picture says it should be.
	var straight := (p - _home) / k
	var bent := _bend_at(p, _home)
	var want := p - bent * k
	# The nudge is capped by the bend; anything larger is arithmetic going wrong.
	var cap := _frame.size * 0.06
	var delta := (want - _home).clamp(-cap, cap)
	# Nudge in whole game pixels: a fractional shift changes texel sampling and pixel art crawls.
	# Why: docs/why/GameShell.md#pointer-through-glass
	delta = (delta / k).round() * k
	_frame.position = _home + delta
	_slip = (straight - bent).length()


func _process(_delta: float) -> void:
	_nudge()


## The switch-off is one uniform, runs even with the curve off, and the quit is timer guaranteed.
## Three seconds, spent on the bright line (Jon), not on a slower fold.
## Why: docs/why/GameShell.md#power-off
const OFF_S := 3.0
## Where the line becomes a dot, in seconds. The shader's own 0.50 of the way
## through; kept here because the sound has to land on it.
const CLOSE_S := 0.50 * OFF_S
## A black second after the light (Jon): a window vanishing with the light reads as a transition.
## Why: docs/why/GameShell.md#power-off
const BLACK_S := 1.0

static func shut_down(tree: SceneTree) -> void:
	if instance == null or DisplaySettings.reduced_motion:
		tree.quit()
		return
	instance._fade_out(tree)


func _fade_out(tree: SceneTree) -> void:
	set_process(false)          # the nudge stops; the rect holds still to die
	Audio.play(&"power_off")
	# Audio slows with the picture and is cut on the bend, so the cut sounds like power going.
	Audio.power_down(CLOSE_S - 0.06)
	# The hole: everything else is cut just before the `power_off` click so it lands in silence.
	# Why: docs/why/GameShell.md#power-off
	tree.create_timer(CLOSE_S - 0.06).timeout.connect(func() -> void:
		# 40 ms, not SWAP's 2.5 s fade, or music stayed audible; not a hard stop, which clicks.
		# Why: docs/why/GameShell.md#power-off
		Audio.stop_music(0.04)
		Audio.room(&"", 0.04))
	var t := create_tween()
	t.tween_method(func(v: float) -> void:
		if _mat != null:
			_mat.set_shader_parameter(&"power_off", v), 0.0, 1.0, OFF_S) \
		.set_trans(Tween.TRANS_LINEAR)
	t.tween_interval(BLACK_S)
	t.tween_callback(tree.quit)
	# And a floor under it, in case the tween is killed with the tree.
	tree.create_timer(OFF_S + BLACK_S + 0.4).timeout.connect(tree.quit)


## Hold the set part-way off, for a shot. `-- off=0.5`.
func hold_off(v: float) -> void:
	set_process(false)
	if _mat != null:
		_mat.set_shader_parameter(&"power_off", clampf(v, 0.0, 1.0))


## Harnesses ask for the glass rect instead of searching for a node.
func frame_rect() -> Rect2:
	return Rect2(_frame.position, _frame.size) if _frame != null else Rect2()


## Kept apart from the snap because it is invertible and `-- warptest` runs it backwards.
func _bend_at(win: Vector2, origin: Vector2) -> Vector2:
	if _frame.size.x <= 0.0 or _frame.size.y <= 0.0:
		return Vector2.ZERO
	var uv := (win - origin) / _frame.size
	var q := (uv - Vector2(0.5, 0.5)) * 2.0
	q *= 1.0 + _curve * q.dot(q)
	q /= _overscan
	uv = (q * 0.5 + Vector2(0.5, 0.5)).clamp(Vector2.ZERO, Vector2.ONE)
	return uv * Vector2(BASE)


## Harnesses push here, in game space; at `tree.root` the container would halve the position.
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
	if _glass != null:
		_glass.size = px
		_glass.position = _home
		_fit_bands(win, px)
	if _mat != null:
		_mat.set_shader_parameter(&"out_scale", float(k))
	refresh()

## Black is only where the glass is not; the root clear stays navy, so the bands are drawn.
## Why: docs/why/GameShell.md#letterbox-bands
func _fit_bands(win: Vector2, px: Vector2) -> void:
	var top := clampf(_home.y, 0.0, win.y)
	var bottom := clampf(_home.y + px.y, top, win.y)
	var left := clampf(_home.x, 0.0, win.x)
	var right := clampf(_home.x + px.x, left, win.x)
	var rects: Array[Rect2] = [
		Rect2(0.0, 0.0, win.x, top),
		Rect2(0.0, bottom, win.x, win.y - bottom),
		Rect2(0.0, top, left, bottom - top),
		Rect2(right, top, win.x - right, bottom - top)]
	for i in _bands.size():
		var band := _bands[i]
		var r := rects[i]
		band.set_anchors_preset(Control.PRESET_TOP_LEFT)
		band.position = r.position
		band.size = r.size
		band.visible = r.size.x > 0.0 and r.size.y > 0.0

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
	## Corner depth was set by Jon's eye: the old 0.35 was measurable but invisible on dark edges.
	## Why: docs/why/GameShell.md#vignette
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
	# Corner and edge styles are picked by `-- corner=N` and `-- edge=N` while Jon judges them.
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
	# Measured costs, not guesses: vignette mean 0.412, mask 2/3, scanlines 1/2.
	# The floor is gone: a soft knee rolls highlights off, so a gain of two does not clip.
	# Why: docs/why/GameShell.md#brightness-gain
	const VIGNETTE_MEAN := 0.412
	_mat.set_shader_parameter(&"gain",
		1.0 / maxf(0.2, (1.0 - scan * 0.5) * (1.0 - mask * 2.0 / 3.0)
			* (1.0 - vign * VIGNETTE_MEAN)))
