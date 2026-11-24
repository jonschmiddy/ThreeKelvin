class_name ShipRoomSolari
extends ShipRoom

## Solari's Casting bed (Jon, Nov 24: show18 approved): six furnaces and the bed they pour on.
## Why: docs/why/ShipRoom.md#rooms


func hull_amb() -> float:
	return 0.5


func _build() -> void:
	# the warm under-light on the hulls (PORT.md: (255, 150, 50) at 110, rising with row cubed)
	(hull_material() as ShaderMaterial).set_shader_parameter(&"under", Vector4(1.0, 150.0 / 255.0, 50.0 / 255.0, 110.0))


func band_colour() -> Color:
	return Color8(12, 8, 6)
