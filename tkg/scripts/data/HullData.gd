class_name HullData
extends Resource

enum Weight { LIGHT, MEDIUM, HEAVY }

## Hulls are built by a manufacturer, reversing the neutral-frame ruling; empty is unbranded.
## Why: docs/why/HullData.md#manufacturers
@export var manufacturer: StringName = &""
@export var name: String = ""
@export var weight: Weight = Weight.MEDIUM
@export var tier: int = 0                    ## 0=C 1=B 2=A 3=S
## One reactor number set by tier decides both cells and energy; slot counts must still fit.
## Why: docs/why/HullData.md#reactor-level
@export var reactor: int = 4
@export var hand_size: int = 5
@export var max_hull: int = 35
@export var heat_cap: int = 12
@export var dissipation: int = 3
@export var dodge: float = 0.05
@export var initiative: int = 0
@export var fuel_factor: float = 1.2

## Thrust is its own number, seeded to the old weight values so no existing ship moves.
## Why: docs/why/HullData.md#thrust
@export var thrust: int = 6

## Sensors and Stealth have no other gauge, so the chassis carries a signed baseline.
## Why: docs/why/HullData.md#sensors-and-stealth
@export var sensors: int = 0
@export var stealth: int = 0

## Hold slots are 8, 12 and 16, widened from 4, 8 and 12 to make room for valuables.
## Why: docs/why/HullData.md#cargo
@export var cargo_slots: int = 8

## The hold grid is 4x3, 5x4 and 6x5, so its shape tells the class and heavies grow wider.
## Why: docs/why/HullData.md#hold-grid
@export var hold_grid: Vector2i = Vector2i(5, 4)

@export var weapon_slots: int = 3
@export var system_slots: int = 2
@export var utility_slots: int = 1
## THE MANUFACTURER'S PERK. Every hull a manufacturer builds carries it, at every
## grade, so a C-class is never characterless.
@export var perk_id: StringName = &"salvage_rack"

## Tier perks are authored, never rolled: same grade and manufacturer is the same ship.
## Why: docs/why/HullData.md#tier-perks
@export var tier_perks: Array[StringName] = []

## Use `has_perk`: an equality test on one perk id silently missed the other three.
## Why: docs/why/HullData.md#perks
func has_perk(id: StringName) -> bool:
	return id == perk_id or id in tier_perks

## Everything this hull carries, manufacturer first, then the grade's in order.
func perks() -> Array[StringName]:
	var out: Array[StringName] = []
	if perk_id != &"":
		out.append(perk_id)
	for p in tier_perks:
		if p != &"" and not (p in out):
			out.append(p)
	return out

@export_group("Art")
## The plume is a strip of frames that change shape, snapped to the source flame's twelve colours.
## Why: docs/why/HullData.md#exhaust-art
@export var exhaust_frames: int = 1
## A hull carries every plume it has; `back` draws before the hull so plating occludes it.
## Why: docs/why/HullData.md#thrusters
@export var thrusters: Array[Dictionary] = []

## The first plume, for the callers that only want to know whether there is one.
func has_exhaust() -> bool:
	return not thrusters.is_empty()
@export var sprite: Texture2D
## The half sprite is a second file, as `ShipView.zoom()` clamps at 1; nearest reduction read best.
## Why: docs/why/HullData.md#half-sprite
@export var sprite_half: Texture2D
## Far row first so near-row modules occlude it; superseded by the lines and `mounts_along()`.
## Why: docs/why/HullData.md#mount-anchors
@export var weapon_anchors: Array[Vector2] = []
@export var system_anchors: Array[Vector2] = []
@export var utility_anchors: Array[Vector2] = []

func anchors_for(s: ModuleData.Slot) -> Array[Vector2]:
	match s:
		ModuleData.Slot.WEAPON: return weapon_anchors
		ModuleData.Slot.SYSTEM: return system_anchors
		_: return utility_anchors

## Mounts spread along a line: mount counts vary with weight, tier and manufacturer.
## Why: docs/why/HullData.md#mount-lines
@export var dorsal: PackedVector2Array = PackedVector2Array()
@export var ventral: PackedVector2Array = PackedVector2Array()
@export var flank: PackedVector2Array = PackedVector2Array()

func line_for(s: ModuleData.Slot) -> PackedVector2Array:
	match s:
		ModuleData.Slot.WEAPON: return dorsal
		ModuleData.Slot.SYSTEM: return ventral
		_: return flank

## Mounts sit at the centre of their share of the line, keeping the first off the nose.
## Why: docs/why/HullData.md#mount-lines
func mounts_along(s: ModuleData.Slot, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	if n <= 0:
		return out
	# PLACED POINTS WIN. A hull rigged by hand has its mounts on the turret ring
	# and the missile rack; the line only ever knew where the hull's edge was.
	var placed := anchors_for(s)
	if placed.size() >= n:
		for i in n:
			out.append(placed[i])
		return out
	# Rigged for fewer than needed: manufacturers share art, so spread along what was placed.
	var line := PackedVector2Array(placed) if placed.size() > 1 else line_for(s)
	if line.is_empty():
		return out
	if line.size() == 1:
		for i in n:
			out.append(line[0])
		return out
	for i in n:
		var t := (float(i) + 0.5) / float(n)
		var f := t * float(line.size() - 1)
		var a := int(f)
		var b := mini(a + 1, line.size() - 1)
		out.append(line[a].lerp(line[b], f - float(a)))
	return out

## A constant so its length can be checked against `Weight` -- see
## `MapTest._labels`.
const WEIGHT_NAMES: Array[String] = ["Light", "Medium", "Heavy"]

static func weight_name(w: Weight) -> String:
	return WEIGHT_NAMES[w]

## Tier names live here, as a class is part of a hull and `Database` has no `class_name`.
## Why: docs/why/HullData.md#tier-names
const TIER_NAMES := ["C", "B", "A", "S"]

func tier_letter() -> String:
	return TIER_NAMES[clampi(tier, 0, TIER_NAMES.size() - 1)]

func display_name() -> String:
	return "%s-tier %s" % [tier_letter(), name]

func slots_for(s: ModuleData.Slot) -> int:
	match s:
		ModuleData.Slot.WEAPON: return weapon_slots
		ModuleData.Slot.SYSTEM: return system_slots
		_: return utility_slots
