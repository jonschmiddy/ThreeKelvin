class_name MiniGames
extends RefCounted

## The science mini games in the game, and which one a science site deals: picked, and its puzzle
## seeded, from `Rng.derive(&"minigame", index)`, so a site deals the same puzzle every visit.
## Why: docs/why/MiniGame.md#the-contract

## Behind a switch, as the desk is: on, a reading at the desk plays a game.
static var enabled := true
## A developer's pick (`-- minigame coolant depth=3 sensors=1`): any of id, depth, sensors.
static var force: Dictionary = {}
const ORDER: Array[StringName] = [&"coolant", &"centrifuge"]


static func make(id: StringName) -> MiniGame:
	match id:
		&"coolant":
			return GameCoolant.new()
		&"centrifuge":
			return GameCentrifuge.new()
	return null


## The ship's sensors as the games' 0 to 5 (each two points of SENSORS one step).
static func sensors_of(attr: int) -> int:
	return clampi(attr / 2, 0, 5)


## What system `n`'s science site deals: {id, depth, sensors, seed}.
static func deal(n: MapGen.MapNode) -> Dictionary[String, Variant]:
	var r := Rng.derive(&"minigame", n.index if n != null else 0)
	var out: Dictionary[String, Variant] = {}
	out.assign({
		id = ORDER[r.randi() % ORDER.size()],
		depth = MapGen.tier(n.danger) if n != null else 1,
		sensors = sensors_of(Run.attr_sensors()),
		seed = r.randi(),
	})
	for k: String in ["id", "depth", "sensors"]:
		if force.has(k):
			out[k] = force[k]
	out.id = StringName(out.id)
	return out


## The puzzle's own stream from a dealt seed.
static func stream(seed: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed
	return r
