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

var view: SubViewport
var _frame: SubViewportContainer
var _mat: ShaderMaterial

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
	_frame.position = ((win - px) * 0.5).floor()
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
	var vign := 0.0
	match d.screen_look:
		DisplaySettings.Look.SCANLINES:
			scan = 0.16
		DisplaySettings.Look.CRT_GENTLE:
			curve = 0.03
			scan = 0.14
			vign = 0.35
		DisplaySettings.Look.CRT:
			curve = 0.06
			scan = 0.24
			vign = 0.6
		DisplaySettings.Look.CRT_ARCADE:
			curve = 0.11
			scan = 0.3
			mask = 0.18
			vign = 0.8
	_mat.set_shader_parameter(&"curve", curve)
	# The corner treatment, picked by `-- corner=N` while Jon judges it.
	# HOW THE EDGE OF THE TUBE IS FINISHED. The four ways other games do it,
	# from the survey: leave it flat, overscan past the frame, shape the glass,
	# or set the glass in plastic. `-- edge=N` picks one while Jon judges them.
	var e := int(_edge_style)
	var curved := curve > 0.0
	#  0 hard edge          3 glass in a bezel      6 overscan, rounded 26
	#  1 overscan           4 deeper bezel          7 overscan, rounded 40, shaded
	#  2 shaped glass       5 overscan, rounded 14
	_mat.set_shader_parameter(&"overscan", [1.0, 1.03, 1.03, 1.03, 1.04, 1.03, 1.03, 1.03][e])
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
	# GIVE BACK WHAT THE TUBE TOOK. A scanline costs half its strength on
	# average, a mask a third of its own, the vignette about a fifth at the
	# middle of the screen. Compensating here keeps a look's LOOK separate from
	# how bright it is: switching looks should not change the brightness.
	_mat.set_shader_parameter(&"gain",
		1.0 / maxf(0.35, (1.0 - scan * 0.5) * (1.0 - mask / 3.0) * (1.0 - vign * 0.2)))
