class_name AffixData
extends Resource

## Rolled modifiers applied to every card a module contributes.

@export var name: String = ""
@export var text: String = ""
@export var contraband: bool = false

@export var add_damage: int = 0
@export var add_hits: int = 0
@export var add_armor: int = 0
@export var add_draw: int = 0
@export var add_vent: int = 0
@export var add_heal: int = 0
@export var add_scrap: int = 0
@export var add_heat: int = 0
@export var reduce_heat: int = 0
@export var reduce_energy: int = 0

func apply_to(c: CardData) -> void:
	if add_damage != 0 and c.damage > 0:
		c.damage += add_damage
	if add_hits != 0 and c.damage > 0:
		c.hits += add_hits
	if add_armor != 0 and c.armor > 0:
		c.armor += add_armor
	if add_draw != 0:
		c.draw += add_draw
	if add_vent != 0:
		c.vent += add_vent
	if add_heal != 0:
		c.heal += add_heal
	if add_scrap != 0:
		c.scrap_gain += add_scrap
	if add_heat != 0:
		c.heat += add_heat
	if reduce_heat != 0:
		c.heat = maxi(0, c.heat - reduce_heat)
	if reduce_energy != 0:
		c.energy = maxi(0, c.energy - reduce_energy)
