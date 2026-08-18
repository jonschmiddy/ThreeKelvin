class_name HullData
extends Resource

enum Weight { LIGHT, MEDIUM, HEAVY }

## Hulls are manufacturer-neutral: size and tier only.
@export var name: String = ""
@export var weight: Weight = Weight.MEDIUM
@export var tier: int = 0                    ## 0=C 1=B 2=A 3=S
@export var reactor: int = 3
@export var hand_size: int = 5
@export var max_hull: int = 35
@export var heat_cap: int = 12
@export var dissipation: int = 3
@export var dodge: float = 0.05
@export var initiative: int = 0
@export var fuel_factor: float = 1.2
@export var weapon_slots: int = 3
@export var system_slots: int = 2
@export var utility_slots: int = 1
@export var perk_id: StringName = &"salvage_rack"

@export_group("Art")
@export var sprite: Texture2D
## Deck hardpoint positions, in sprite pixel coordinates relative to the sprite centre.
## Order matters: FAR ROW FIRST, near row second. Children are added in this order, so
## near-row modules occlude far-row ones for free.
@export var weapon_anchors: Array[Vector2] = []
@export var system_anchors: Array[Vector2] = []
@export var utility_anchors: Array[Vector2] = []

func anchors_for(s: ModuleData.Slot) -> Array[Vector2]:
	match s:
		ModuleData.Slot.WEAPON: return weapon_anchors
		ModuleData.Slot.SYSTEM: return system_anchors
		_: return utility_anchors

static func weight_name(w: Weight) -> String:
	return ["Light", "Medium", "Heavy"][w]

func tier_letter() -> String:
	return ["C", "B", "A", "S"][clampi(tier, 0, 3)]

func display_name() -> String:
	return "%s-tier %s" % [tier_letter(), name]

func slots_for(s: ModuleData.Slot) -> int:
	match s:
		ModuleData.Slot.WEAPON: return weapon_slots
		ModuleData.Slot.SYSTEM: return system_slots
		_: return utility_slots
