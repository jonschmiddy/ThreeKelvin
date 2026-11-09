class_name IntentData
extends Resource

@export var name: String = ""
@export var text: String = ""
@export var damage: int = 0
@export var hits: int = 1
@export var block: int = 0
@export var heal: int = 0
@export var dross: int = 0

## Named, because what a thing does to your ship is characterisation, and rolled junk says neither.
@export var dross_id: StringName = &""
@export var telegraph: bool = false   ## "winding up" turn, no effect
@export var weight: int = 100         ## for fauna random pools
## Takes the enemy out of the fight, resolved in `Combat._act_one`
## and `NetSession._swing`, never by damage maths.
@export var escape: bool = false


## Text is authored at danger 1 and scaled per fight, so the screen reads this for any number:
## at danger 5 a RAM printed Deal 14 and hit for 15.
## Why: docs/why/IntentData.md#describe
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
