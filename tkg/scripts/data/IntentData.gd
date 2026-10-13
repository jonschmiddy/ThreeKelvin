class_name IntentData
extends Resource

@export var name: String = ""
@export var text: String = ""
@export var damage: int = 0
@export var hits: int = 1
@export var block: int = 0
@export var heal: int = 0
@export var dross: int = 0

## WHICH malfunction this lodges, or empty to roll one against the fight's
## danger. Named, because what a thing does to your ship is characterisation: a
## spore should fuse something into the rack and a shattered hulk should score a
## barrel, and "some junk, rolled" says neither. See DB.MALFUNCTIONS.
@export var dross_id: StringName = &""
@export var telegraph: bool = false   ## "winding up" turn, no effect
@export var weight: int = 100         ## for fauna random pools
## Acting on this intent takes the enemy OUT of the fight — the Hellbender's
## escape burn. Resolved in Combat._act_one (solo) and NetSession._swing
## (host), never by damage maths. See Combat.escape_intent().
@export var escape: bool = false


## WHAT THIS DOES, WRITTEN FROM ITS OWN NUMBERS.
##
## `text` is authored against the danger-1 numbers, and `Combat._spawn` scales
## `damage`, `block` and `heal` per fight -- so at danger 5 a RAM printed "Deal
## 14" and hit for 15, and a Barrage printed "5 x 3" and killed a ship at 5 hull
## with 6 x 3 (combat polish audit, item 4). The screen reads this, never
## `text`, for anything with a number in it. A wind-up or an escape has no
## number and keeps its authored line.
func describe() -> String:
	if telegraph or escape:
		return text
	var parts := PackedStringArray()
	if damage > 0:
		parts.append("Deal %d" % damage if hits <= 1 else "Deal %d × %d" % [damage, hits])
	if block > 0:
		parts.append("Gain %d block" % block)
	if heal > 0:
		parts.append("Heals %d" % heal)
	if dross > 0:
		parts.append("+%d Dross" % dross)
	return text if parts.is_empty() else ", ".join(parts)
