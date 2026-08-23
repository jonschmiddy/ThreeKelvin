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
