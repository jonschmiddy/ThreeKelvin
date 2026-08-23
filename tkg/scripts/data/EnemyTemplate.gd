class_name EnemyTemplate
extends Resource

@export var id: StringName = &""
@export var name: String = ""
@export var tag: String = ""
@export var max_hull: int = 26
@export var armor: int = 0
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
