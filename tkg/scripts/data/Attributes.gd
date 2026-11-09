class_name Attributes
extends RefCounted

## The gauge tables, in a class of their own because `Database` reads `PER_PIP` while the catalogue
## is built, before the `Run` autoload exists. `Run` keeps an alias of each, so callers are unchanged.

## Ten is how many cells the bar draws, not a ceiling: each consumer caps its own use.
## Why: docs/why/Attributes.md#attribute-scale
const ATTR_MAX := 10

## A fixed reference so frame size and damage both count; 70 leaves the biggest hull room to grow.
## Why: docs/why/Attributes.md#hull-reference
const HULL_REF := 70.0

## Three cells a pip, named because a coupling is priced in it.
## Why: docs/why/RunState.md#reactor-level
const CELLS_PER_PIP := 3.0

## One pip's cost in raw units, inverted from the formulas above; `-- attrtest` checks they agree.
## Why: docs/why/Attributes.md#pip-costs
const PER_PIP := {
	&"hull": {&"max_hull": 7.0},                       ## HULL_REF / ATTR_MAX
	&"thermal": {&"heat_cap": 1.0, &"dissipation": 1.0},
	# Dodge alone: nothing in combat reads initiative, so a maneuver pip must buy dodge.
	# Why: docs/why/Attributes.md#pip-costs
	&"maneuver": {&"dodge": 1.0 / 23.0},
	&"sensors": {&"sensors": 1.0},
	&"stealth": {&"stealth": 1.0},
	# Reactor and thrust pips are one for one.
	# Why: docs/why/Attributes.md#pip-costs
	&"reactor": {&"reactor": 1.0},
	&"thrust": {&"thrust": 1.0},
}

## Short and full gauge names are spelled once; the short forms fit a 93 px card readout.
## Why: docs/why/Attributes.md#gauge-names
const ATTR_LABEL := {
	&"hull": "HULL",
	&"reactor": "REACTOR",
	&"thrust": "THRUST",
	&"maneuver": "MANEUVERABILITY",
	&"thermal": "THERMAL",
	&"sensors": "SENSORS",
	&"stealth": "STEALTH",
}

const ATTR_SHORT := {
	&"hull": "HUL",
	&"reactor": "RCT",
	&"thrust": "THR",
	&"maneuver": "MNV",
	&"thermal": "THM",
	&"sensors": "SEN",
	&"stealth": "STL",
}
