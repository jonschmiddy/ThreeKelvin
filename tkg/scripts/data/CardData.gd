class_name CardData
extends Resource

## A single card contributed to the deck by a module (or the hull itself).
## Effects are declarative: CardResolver reads these fields, so new cards
## are data, not code.

@export var name: String = ""
@export var energy: int = 1
@export var heat: int = 0
@export var copies: int = 1

@export_group("Attack")
@export var damage: int = 0
@export var hits: int = 1
@export var salvo: int = 0              ## bonus per hit if not your first attack this turn
@export var charge_turns: int = 0       ## fires automatically after N turns
@export var heat_scale: int = 0         ## +1 damage per N current heat
@export var damage_equals_heat: bool = false
@export var adapt: int = 0              ## permanently grows this combat

@export_group("Defence")
@export var armor: int = 0              ## persists between turns, costs heat to hold
@export var block: int = 0              ## decays at end of enemy turn
@export var armor_from_heat: bool = false
@export var riposte: int = 0
@export var negate_next: bool = false

@export_group("Utility")
@export var vent: int = 0
@export var vent_all: bool = false
@export var heal: int = 0
@export var draw: int = 0
@export var lock_on: int = 0
@export var energy_gain: int = 0
@export var scrap_gain: int = 0
@export var scrap_cost: int = 0
@export var drone_damage: int = 0
@export var drone_armor: int = 0
@export var evoke: int = 0
@export var unplayable: bool = false    ## Dross and other junk

## Runtime-only, set by DeckBuilder
var source_module: String = ""
var manufacturer: StringName = &""

## Short human-readable effect line for the card face.
func describe() -> String:
	var bits: PackedStringArray = []
	if damage > 0:
		bits.append("Deal %d%s" % [damage, "" if hits <= 1 else " × %d" % hits])
	if damage_equals_heat:
		bits.append("Deal damage equal to heat")
	if heat_scale > 0:
		bits.append("+1 per %d heat" % heat_scale)
	if charge_turns > 0:
		bits.append("Charge %d" % charge_turns)
	if salvo > 0:
		bits.append("Salvo +%d" % salvo)
	if adapt > 0:
		bits.append("Grows +%d" % adapt)
	if armor > 0:
		bits.append("Brace %d" % armor)
	if armor_from_heat:
		bits.append("Armor from heat")
	if block > 0:
		bits.append("Block %d" % block)
	if riposte > 0:
		bits.append("Riposte %d" % riposte)
	if negate_next:
		bits.append("Negate next attack")
	if vent > 0:
		bits.append("Vent %d" % vent)
	if vent_all:
		bits.append("Vent all")
	if heal > 0:
		bits.append("Heal %d" % heal)
	if draw > 0:
		bits.append("Draw %d" % draw)
	if lock_on > 0:
		bits.append("Next attack +%d" % lock_on)
	if energy_gain > 0:
		bits.append("+%d energy" % energy_gain)
	if scrap_gain > 0:
		bits.append("+%d scrap" % scrap_gain)
	if scrap_cost > 0:
		bits.append("Spend %d scrap" % scrap_cost)
	if drone_damage > 0:
		bits.append("Launch drone %d" % drone_damage)
	if drone_armor > 0:
		bits.append("Wasp screen %d" % drone_armor)
	if evoke > 0:
		bits.append("Evoke %d per drone" % evoke)
	if unplayable:
		bits.append("Unplayable. 1 energy to purge")
	return ". ".join(bits) + "."
