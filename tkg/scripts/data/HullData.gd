class_name HullData
extends Resource

enum Weight { LIGHT, MEDIUM, HEAVY }

## Hulls are BUILT BY A MANUFACTURER. This reverses an earlier ruling that hulls
## were neutral size-and-tier frames; see the rulings table in CLAUDE.md, which
## records why and what it costs.
##
## The short version: `attributes-and-checks.md` §1.5 assigns an attribute
## signature to each manufacturer — Korvan thermal and slow, Redline evasive and
## fragile — and every one of those is a property of a CHASSIS, not of a module
## you bolt onto it. The doc could not be implemented while hulls were anonymous.
##
## Empty means unbranded salvage: the three plain frames a derelict can still
## offer, which belong to nobody and count toward no set.
@export var manufacturer: StringName = &""
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

## Sensors and Stealth have no gauge anywhere else in the game — unlike Hull,
## Thrust, Maneuverability and Thermal, which RunState derives from hp, fuel,
## dodge and heat. So the chassis carries their baseline and modules adjust it,
## which keeps all six attributes working the same way instead of making these
## two the odd pair that comes only from cargo.
##
## Signed on purpose: Solari runs negative on stealth, because a ship that hot
## cannot hide, and that is a real cost of flying one.
@export var sensors: int = 0
@export var stealth: int = 0

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
