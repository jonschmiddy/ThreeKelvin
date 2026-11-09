class_name ShipSprite
extends Node2D

## Not instantiated: it reads `Run`, so it can only draw your ship, unlike `ShipView`.
## Why: docs/why/ShipSprite.md#ship-sprite

const HEAT_SHADER := "res://shaders/heat.gdshader"

var _hull_sprite: Sprite2D
var _module_sprites: Array[Sprite2D] = []
var _fallback: ShipView
var _shader_material: ShaderMaterial

func _ready() -> void:
	Sig.ship_changed.connect(rebuild)
	Sig.resources_changed.connect(_update_heat)
	Sig.player_combat_state_changed.connect(_update_heat)
	rebuild()

func rebuild() -> void:
	if Run.hull == null:
		return
	for s in _module_sprites:
		s.queue_free()
	_module_sprites.clear()

	if Run.hull.sprite == null:
		_use_fallback()
		return
	_clear_fallback()

	if _hull_sprite == null:
		_hull_sprite = Sprite2D.new()
		_hull_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_hull_sprite)
		_attach_heat_shader(_hull_sprite)
	_hull_sprite.texture = Run.hull.sprite

	# Far row first, near row second — child order gives correct occlusion.
	for slot in [ModuleData.Slot.WEAPON, ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		var anchors := Run.hull.anchors_for(slot)
		# Anchor by the module's own mount, not list position, or parts shuffle on removal.
		for i in Run.slots_for(slot):
			if i >= anchors.size():
				break  # more hardpoints than the hull has visible mounts
			var m := Run.module_at(slot, i)
			if m == null or m.sprite == null:
				continue
			var s := Sprite2D.new()
			s.texture = m.sprite
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.position = anchors[i] + m.mount_offset
			add_child(s)
			_module_sprites.append(s)
	_update_heat()

func _attach_heat_shader(target: Sprite2D) -> void:
	if not ResourceLoader.exists(HEAT_SHADER):
		return
	var sh: Shader = load(HEAT_SHADER)
	if sh == null:
		return
	_shader_material = ShaderMaterial.new()
	_shader_material.shader = sh
	target.material = _shader_material

func _update_heat() -> void:
	if _shader_material == null or Run.hull == null:
		return
	var cap := maxi(1, Run.heat_cap())
	_shader_material.set_shader_parameter("heat", clampf(float(Run.heat) / cap, 0.0, 1.7))

func _use_fallback() -> void:
	if _fallback != null:
		return
	if _hull_sprite != null:
		_hull_sprite.visible = false
	_fallback = ShipView.new()
	add_child(_fallback)

func _clear_fallback() -> void:
	if _fallback != null:
		_fallback.queue_free()
		_fallback = null
	if _hull_sprite != null:
		_hull_sprite.visible = true
