class_name EnemyTemplate
extends Resource

@export var id: StringName = &""
@export var name: String = ""
@export var tag: String = ""
@export var max_hull: int = 26
@export var brace: int = 0
@export var fauna: bool = false
@export var boss: bool = false
## A set piece that is not the run's end: hand-tuned, never danger-scaled, and it pays loot.
@export var miniboss: bool = false
@export var credit_reward: int = 15
@export var art: StringName = &"cutter"
## Ships use a fixed loop (machines are predictable).
@export var loop: Array[IntentData] = []
## Fauna use a weighted random pool (animals are not).
@export var pool: Array[IntentData] = []

## Only the Custodian grows (Jon, Nov 3, G3 with cap B), hull only, off unless `grow_after` is set.
## Why: docs/why/EnemyTemplate.md#growth-with-the-run
@export var grow_after: int = -1
@export var grow_rate: float = 1.0
@export var grow_cap: float = 1.0


## Pure: reads only the template, so a fight and anything showing the growth can both ask.
func hull_at(jumps: int) -> int:
	if grow_after < 0 or jumps <= grow_after:
		return max_hull
	# Cap as a float, then round: rounding first made a long run's figure the most negative int.
	# Why: docs/why/EnemyTemplate.md#hull-cap-rounding
	return roundi(minf(max_hull * grow_cap,
		max_hull * pow(grow_rate, float(jumps - grow_after))))
