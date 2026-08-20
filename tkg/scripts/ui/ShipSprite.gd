class_name ShipSprite
extends Node2D

## Composites the ship from real sprites: hull + one Sprite2D per installed module,
## placed at the hull's deck anchors. This is what keeps the design pillar alive —
## the ship on screen is always the build you assembled.
##
## Falls back to the procedural ShipView when the hull has no sprite yet, so the
## game stays playable through a partial art migration. You will not generate all
## ~90 assets in one sitting.
##
## STILL NOT INSTANTIATED, and now one step further behind. `ShipView` draws
## from a `ShipBuild` — a hull, a list of hardpoints and two gauges — so it can
## draw a ship being flown on somebody else's machine; this class reads `Run`
## and can therefore only ever draw yours. Anything that revives it has to take
## the same subject.
##
## That matters because this is the file that closes the one gap the party
## display still has: a hull WITH real art is blitted whole and its modules are
## not drawn on it, which today means a medium chassis shows no fitted weapons
## for anybody. The fix is module sprites plus populated
## `HullData.weapon_anchors`, which is exactly what the loop below already
## expects — see `art/ART_CONTRACT.md` for the order the assets arrive in.

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
		# An anchor is picked by the module's OWN mount, not by its place in the
		# list. Which anchor a part hangs on is a decision the refit screen
		# records; reading it off the array order made the ship rearrange itself
		# whenever something was taken off ahead of it.
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
