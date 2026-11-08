class_name AffixData
extends Resource

## Affixes pay in ship attributes, not cards: card clauses overflowed and made cards unlearnable.
## Authored in pips; `PER_PIP` translates, so an affix cannot drift from its gauge.
## Why: docs/why/AffixData.md#affix-design

## Names match `RunState.PER_PIP`, as a missing gauge pays nothing and says nothing.
const GAUGES: Array[StringName] = [&"hull", &"reactor", &"thrust", &"maneuver",
	&"thermal", &"sensors", &"stealth"]

@export var name: String = ""

## Generated from the pips, not authored beside them, as that is two things to keep in step.
## Why: docs/why/AffixData.md#affix-text
@export var text: String = ""

## Runs hot, loud or illegal. Gated by `LootGen` in policed space and read by
## `ModuleData.contraband`, which is what the market and the patrols check.
@export var contraband: bool = false

## A reactor pip is the dearest, so the two reactor affixes are scarce rather than weakened.
## Why: docs/why/AffixData.md#affix-weight
@export var weight: float = 1.0

## Changes how many cards a module grants; nothing rolls it today.
@export var grant_delta: int = 0

@export_group("Pips")
@export var hull: int = 0
@export var reactor: int = 0
@export var thrust: int = 0
@export var maneuver: int = 0
@export var thermal: int = 0
@export var sensors: int = 0
@export var stealth: int = 0
@export_group("")


## Computed on demand, never baked: `SaveGame._module_from` rebuilds from the template by name.
## Panel text is three letters, gain before cost, as full words wrapped in a card-wide readout.
## Why: docs/why/AffixData.md#affix-maths
func gauge_text(long: bool = false) -> String:
	var up: PackedStringArray = []
	var down: PackedStringArray = []
	var names: Dictionary = Run.ATTR_LABEL if long else Run.ATTR_SHORT
	for g in GAUGES:
		var pips: int = int(get(g))
		if pips == 0:
			continue
		var nm: String = names.get(g, String(g).to_upper())
		if pips > 0:
			up.append("+%d %s" % [pips, nm])
		else:
			down.append("%d %s" % [pips, nm])
	return ", ".join(up + down)


func raw_for(field: StringName) -> float:
	var total := 0.0
	for g in GAUGES:
		var pips: int = int(get(g))
		if pips == 0:
			continue
		var per: Dictionary = Run.PER_PIP.get(g, {})
		if per.has(field):
			total += float(per[field]) * float(pips)
	return total
