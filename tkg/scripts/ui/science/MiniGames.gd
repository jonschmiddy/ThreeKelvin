class_name MiniGames
extends RefCounted

## The science mini games in the game, and which one a science site deals: picked, and its puzzle
## seeded, from `Rng.derive(&"minigame", index)`, so a site deals the same puzzle every visit.
## Why: docs/why/MiniGame.md#the-contract

## Behind a switch, as the desk is: on, a reading at the desk plays a game.
static var enabled := true
## A developer's pick (`-- minigame coolant depth=3 sensors=1`): any of id, depth, sensors.
static var force: Dictionary = {}
## Every ported game (the dev flag opens any).
const ORDER: Array[StringName] = [&"coolant", &"centrifuge", &"icecore", &"pulsar", &"tray", &"anomaly", &"beams", &"spectrum", &"fourkelvin", &"torch", &"leak"]
## What a site deals, by the phone page's grouping (Jon, Nov 18): a reading at a world, a belt or a
## comet is rock, which deals the rock games and the lab games. Sky, life and wreck games wait for
## their own sites.
## Why: docs/why/MiniGame.md#which-game-a-site-deals
const ROCK: Array[StringName] = [&"coolant", &"centrifuge", &"tray", &"icecore", &"fourkelvin"]


static func make(id: StringName) -> MiniGame:
	match id:
		&"coolant":
			return GameCoolant.new()
		&"centrifuge":
			return GameCentrifuge.new()
		&"icecore":
			return GameIceCore.new()
		&"pulsar":
			return GamePulsar.new()
		&"tray":
			return GameTray.new()
		&"anomaly":
			return GameAnomaly.new()
		&"beams":
			return GameBeams.new()
		&"spectrum":
			return GameSpectrum.new()
		&"fourkelvin":
			return GameFourKelvin.new()
		&"torch":
			return GameTorch.new()
		&"leak":
			return GameLeak.new()
	return null


## The ship's sensors as the games' 0 to 5 (each two points of SENSORS one step).
static func sensors_of(attr: int) -> int:
	return clampi(attr / 2, 0, 5)


## What system `n`'s science site deals: {id, depth, sensors, seed}.
static func deal(n: MapGen.MapNode) -> Dictionary[String, Variant]:
	var r := Rng.derive(&"minigame", n.index if n != null else 0)
	var out: Dictionary[String, Variant] = {}
	out.assign({
		id = ROCK[r.randi() % ROCK.size()],
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


## Starts the dealt game's slow search on a worker as its card goes up (only the tray needs it).
static func prefetch(d: Dictionary) -> void:
	if StringName(d.get("id", &"")) == &"tray":
		GameTray.prefetch(int(d.depth), stream(int(d.seed)))


## Waits for any search still out (the desk calls it on leaving).
static func settle() -> void:
	GameTray.settle()
