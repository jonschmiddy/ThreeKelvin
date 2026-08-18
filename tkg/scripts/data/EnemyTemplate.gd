class_name EnemyTemplate
extends Resource

@export var id: StringName = &""
@export var name: String = ""
@export var tag: String = ""
@export var max_hull: int = 26
@export var armor: int = 0
@export var fauna: bool = false
@export var boss: bool = false
@export var scrap_reward: int = 15
@export var art: StringName = &"cutter"
## Ships use a fixed loop (machines are predictable).
@export var loop: Array[IntentData] = []
## Fauna use a weighted random pool (animals are not).
@export var pool: Array[IntentData] = []
