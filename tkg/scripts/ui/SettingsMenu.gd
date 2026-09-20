class_name SettingsMenu
extends Control

## Settings in a drawer of its own, for the title screen.
##
## In a run, Settings is not this: it swaps into the escape drawer in place of
## the menu (PauseMenu.show_settings). The title screen has no escape drawer to
## borrow, so this is the same drawer -- same width, same edge, same backdrop,
## same motion -- holding the same SettingsPanel.

signal closed

var _drawer: Control
var _mat: ShaderMaterial
var _closing := false

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = PauseMenu.BACKDROP
	scrim.material = _mat
	add_child(scrim)

	var drawer := PanelContainer.new()
	drawer.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	drawer.offset_right = PauseMenu.DRAWER_W
	var face := UITheme.flat(UITheme.PANEL, Color(0, 0, 0, 0), 0, 0, 0)
	face.border_width_right = 1
	face.border_color = UITheme.BEVEL_HI
	face.shadow_color = Color(0, 0, 0, 0.35)
	face.shadow_size = 12
	drawer.add_theme_stylebox_override("panel", face)
	add_child(drawer)
	_drawer = drawer

	var pad := Widgets.pad(null, PauseMenu.SIDE, 20)
	drawer.add_child(pad)
	var panel := SettingsPanel.new()
	panel.build()
	panel.back_requested.connect(func() -> void: closed.emit())
	pad.add_child(panel)

	if Router.animating():
		drawer.position.x = -PauseMenu.DRAWER_W - 16.0
		_mat.set_shader_parameter(&"amount", 0.0)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(drawer, "position:x", 0.0, PauseMenu.OPEN_S) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter(&"amount", v),
			0.0, 1.0, PauseMenu.BACKDROP_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Out the way it came, as the escape drawer leaves. Whoever opened it calls
## this instead of freeing it.
func close() -> void:
	if _closing:
		return
	_closing = true
	if not Router.animating():
		queue_free()
		return
	var from := _mat.get_shader_parameter(&"amount") as float
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_drawer, "position:x", -PauseMenu.DRAWER_W - 16.0, PauseMenu.CLOSE_S)
	tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter(&"amount", v),
		from, 0.0, PauseMenu.CLOSE_S)
	tw.chain().tween_callback(queue_free)
