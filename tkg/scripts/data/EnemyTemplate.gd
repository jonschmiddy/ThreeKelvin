class_name EnemyTemplate
extends Resource

@export var id: StringName = &""
@export var name: String = ""
@export var tag: String = ""
@export var max_hull: int = 26
@export var brace: int = 0
@export var fauna: bool = false
@export var boss: bool = false
## A set piece that is NOT the run's end. Hand-tuned like a boss — never
## danger-scaled — but killing one pays loot rather than opening the core.
## The Hellbender is the first of these; see `RunState`'s hellbender block.
@export var miniboss: bool = false
@export var credit_reward: int = 15
@export var art: StringName = &"cutter"
## Ships use a fixed loop (machines are predictable).
@export var loop: Array[IntentData] = []
## Fauna use a weighted random pool (animals are not).
@export var pool: Array[IntentData] = []

## GROWTH WITH THE RUN, by jumps flown (`Run.custodian_jumps()`: yours alone,
## the lead ship's in co-op), for a set piece whose hull should follow how long
## the ship took to get there. Off unless
## `grow_after` is set. Hull only: the intents are not touched. Only the
## Custodian grows (Jon, Nov 3, rule G3 with cap B; see its note in
## `Database._seed_enemies`).
##
## `grow_after`: the jumps that are free; -1 means it never grows.
## `grow_rate`: the hull's multiple for each jump past them, compounding.
## `grow_cap`: the most it can reach, as a multiple of `max_hull`, so the cap
## stays "twice its strength" if the base ever moves.
@export var grow_after: int = -1
@export var grow_rate: float = 1.0
@export var grow_cap: float = 1.0


## The hull this enemy fields after `jumps` jumps. PURE: reads only the
## template, writes nothing, so a fight can ask it (`Combat._spawn`) and so can
## anything that shows the growth.
func hull_at(jumps: int) -> int:
	if grow_after < 0 or jumps <= grow_after:
		return max_hull
	# Capped as a float, then rounded: rounding first turned a long run's
	# uncapped figure (past int64 near jump 994, or inf) into the most negative
	# int, which `mini` kept and `Combat._spawn` floored to a 1-hull boss.
	return roundi(minf(max_hull * grow_cap,
		max_hull * pow(grow_rate, float(jumps - grow_after))))
