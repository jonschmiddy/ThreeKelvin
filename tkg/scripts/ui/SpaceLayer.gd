class_name SpaceLayer
extends Control
## One sky above the open screen, or each swap rebakes a world. Station interiors turn it
## off by ruling.
## Why: docs/why/SpaceLayer.md#one-sky-for-all

## The sky itself, and the gas blowing through it. Child order is depth order:
## a Control draws itself, then its children, in order.
var backdrop: SpaceBackdrop
var weather: NebulaWeather

## Whether the sky belongs behind what is currently on screen. Interiors set
## this false; everything that happens in space leaves it true.
var _active: bool = true
## Inert headless: a balance run should not pay for scenery it cannot see, as in
## `Audio._ready`.
var _enabled: bool = true


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if "sim" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		_enabled = false
		return
	backdrop = SpaceBackdrop.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	weather = NebulaWeather.new()
	weather.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	weather.visible = false
	add_child(weather)


## Safe to repeat: the backdrop returns early on the same node index.
func setup(n: MapGen.MapNode) -> void:
	if not _enabled or n == null:
		return
	backdrop.setup(n)
	weather.visible = n.in_nebula and _active
	if n.in_nebula:
		weather.setup(n.nebula_emission,
			Color("#8a5f7a") if n.nebula_emission else Color("#4a7a8a"))


## Separate from `visible` so hiding for an interior keeps the bake and a return does not
## rebake.
func set_active(on: bool) -> void:
	_active = on
	if not _enabled:
		return
	visible = on
	if not on:
		weather.visible = false
