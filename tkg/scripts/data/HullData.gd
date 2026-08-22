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
## FIVE WIDE BY FOUR TALL ON EVERY HULL, and that is a capacity change worth
## seeing rather than inheriting.
##
## It was 4x5 / 4x7 / 4x10 — 20 / 28 / 40 cells, which at the catalogue's average
## of 2.40 cells a module carried 8.3 / 11.7 / 16.7 parts and matched the 8 / 12 /
## 16 the old slot counts promised. One box for every class is 20 cells and about
## 8 parts, so A HEAVY NOW HAULS WHAT A LIGHT DOES: half what it used to.
##
## Taken deliberately, for the screen. The hold moved under the ship, and a
## heavy's ten rows at a legible cell size put the attributes, the hardpoints and
## the manufacturer abilities off the bottom of the panel. A hold you cannot see
## the consequences of is worse than a smaller one.
##
## The ladder is one line to restore — rows of 4 / 6 / 8 gives back 20 / 30 / 40
## — and it wants the panel to scroll, or the cells to shrink again, first.
@export var hold_grid: Vector2i = Vector2i(5, 4)

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
##
## EMPTY ON EVERY HULL, and superseded by the three LINES below. They were
## authored for the 3/4 camera — a far row and a near row is a statement about a
## visible deck, and an edge-on elevation has one plane. Kept because
## `ShipSprite.gd` still reads them and that file is the module-compositing path
## nobody has retired yet; anything new should ask `mounts_along()`.
@export var weapon_anchors: Array[Vector2] = []
@export var system_anchors: Array[Vector2] = []
@export var utility_anchors: Array[Vector2] = []

func anchors_for(s: ModuleData.Slot) -> Array[Vector2]:
	match s:
		ModuleData.Slot.WEAPON: return weapon_anchors
		ModuleData.Slot.SYSTEM: return system_anchors
		_: return utility_anchors

## The three lines things bolt to, in sprite pixel coordinates.
##
## Measured off the hull's own silhouette by `art/tools/anchors.py` and assigned
## from `DB.HULL_LINES`. A LINE rather than a list of mount points, because how
## many mounts a hull has is not a property of the hull art: weight sets a base,
## `TIER_DELTA` grants more at A and S, and six of the seven makers move it
## again. Five authored points used two at a time put both mounts at one end of
## the ship; a line spreads however many there are.
@export var dorsal: PackedVector2Array = PackedVector2Array()
@export var ventral: PackedVector2Array = PackedVector2Array()
@export var flank: PackedVector2Array = PackedVector2Array()

func line_for(s: ModuleData.Slot) -> PackedVector2Array:
	match s:
		ModuleData.Slot.WEAPON: return dorsal
		ModuleData.Slot.SYSTEM: return ventral
		_: return flank

## `n` mount positions spread along a slot's line.
##
## Inset from both ends — a mount sits at the CENTRE of its share of the line
## rather than on the endpoints, which is what keeps the first one off the nose
## and the last one out of the exhaust. One mount therefore sits mid-hull rather
## than at the front, which is also what you want: a ship with a single gun
## carries it amidships.
func mounts_along(s: ModuleData.Slot, n: int) -> PackedVector2Array:
	var line := line_for(s)
	var out := PackedVector2Array()
	if n <= 0 or line.is_empty():
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
