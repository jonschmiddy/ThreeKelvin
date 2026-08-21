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

## How many SLOTS the hold has.
##
## Counted in slots rather than in modules because a slot is a PLACE — a module
## is only one of the things that can sit in one.
##
## The heavy's compensation for being slow and clumsy: it cannot dodge and it
## cannot turn, but it out-carries a skiff two to one, which turns every wreck it
## passes into a choice rather than a shrug. A light frame full of loot has to
## leave something behind.
##
## 8 / 12 / 16, widened from 4 / 8 / 12. Every frame gained four slots and the
## spread narrowed from 3x to 2x, which is a real cost to heavies and was taken
## deliberately: valuables are coming, they occupy the same hold, and a skiff
## with four slots could not carry a trade good and a spare weapon at once.
@export var cargo_slots: int = 8

## The hold as a GRID, which is what it now is. Cells, not modules.
##
## Four columns on every hull — the refit screen measured that at 201px against
## six columns' 303px in a 944px viewport, and the ship beside it cannot give any
## width back. So capacity is rows, and the row count is the weight class.
##
## Sized to hold the SAME NUMBER OF PARTS the slot counts above used to promise.
## The catalogue averages 2.40 cells a module across 55 of them, so 20 / 28 / 40
## cells carry 8.3 / 11.7 / 16.7 — against the 8 / 12 / 16 that `cargo_slots`
## meant when a module was a module whatever its shape. The grid is meant to make
## packing a decision, not to quietly halve what a ship can haul; those are
## different changes and only one of them was asked for.
@export var hold_grid: Vector2i = Vector2i(4, 5)

@export var weapon_slots: int = 3
@export var system_slots: int = 2
@export var utility_slots: int = 1
@export var perk_id: StringName = &"salvage_rack"

@export_group("Art")
## The engine plume: a horizontal STRIP of equal frames, kept off the hull plate
## because a static flame reads as a decal.
##
## A strip rather than one image per frame, and rather than the palette cycle
## this replaced. PixelLab animated the plume itself, so the frames change SHAPE
## — the flame swells and gutters — which brightness cycling cannot do at all.
## Every frame was snapped back onto the source flame's own twelve colours
## afterwards, because the generator drifted 90 pixels off-palette.
@export var exhaust: Texture2D
@export var exhaust_frames: int = 1
## Where the strip's top-left corner sits on the hull canvas. The frames are
## cropped tight to the flame, so unlike `sprite` they do not composite at 0,0.
@export var exhaust_offset: Vector2i = Vector2i.ZERO
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

## The four specification classes, worst to best. Lives HERE rather than in
## Database because a class is part of what a hull IS, and because HullData
## carries a class_name and the Database autoload does not — so this is the copy
## every other script can reach without going through a singleton. DB.TIER_DELTA
## holds what each class DOES; this holds what they are called.
##
## NOT a condition. An S is not a better-kept C, it is a better-specified one:
## more frame, more hardpoints, a bigger reactor. Condition is `hp` and is drawn
## by HullWear.
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
