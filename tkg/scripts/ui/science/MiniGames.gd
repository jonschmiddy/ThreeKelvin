class_name MiniGames
extends RefCounted

## The science mini games in the game, and which one a science site deals: picked, and its puzzle
## seeded, from `Rng.derive(&"minigame", index)`, so a site deals the same puzzle every visit.
## Why: docs/why/MiniGame.md#the-contract

## Behind a switch, as the desk is: on, a reading at the desk plays a game.
static var enabled := true
## A developer's pick (`-- minigame coolant depth=3 sensors=1 site=star`): any of id, depth, sensors, and
## the site whose source pays the haul.
static var force: Dictionary = {}
## Every ported game (the dev flag opens any).
const ORDER: Array[StringName] = [&"coolant", &"centrifuge", &"icecore", &"pulsar", &"tray", &"anomaly", &"beams", &"spectrum", &"fourkelvin", &"torch", &"leak", &"sling", &"tuning", &"seismic", &"corescan", &"culture", &"dock"]
## The games by the site they are played at (Jon, Nov 18, page 6pDoF6JJ9CGLB8xiD4ytoQ). LAB games
## go with any site; Centrifuge is both LIFE and LAB. Only rock sites exist today (a reading at a
## world, a belt or a comet): they deal ROCK and LAB, unless the site has its own deal (`OWN`).
## The rest wait for their sites (the dev flag opens any). A game not yet ported is skipped.
## Why: docs/why/MiniGame.md#which-game-a-site-deals
const WRECKS: Array[StringName] = [&"torch", &"dock", &"leak"]
const LIFE: Array[StringName] = [&"culture", &"centrifuge", &"anomaly"]
const ROCK: Array[StringName] = [&"seismic", &"corescan", &"icecore", &"fourkelvin"]
const SKY: Array[StringName] = [&"pulsar", &"spectrum", &"sling", &"tuning", &"beams"]
const LAB: Array[StringName] = [&"coolant", &"tray", &"centrifuge"]


## A SITE'S OWN DEAL, in place of its group's and the lab's. A comet deals Ice Core (Jon, Nov 21,
## "C"); the comet games he picks from the prototypes join this list when they are ported.
## Why: docs/why/MiniGame.md#a-sites-own-deal
const OWN: Dictionary[StringName, Array] = {&"comet": [&"icecore"]}


## The games a reading at `site` deals: the site's own deal when it has one, else `pool(ROCK)`
## (every reading today, at any site). Ported games only; none ported, the group's.
static func pool_at(site: StringName, own: Dictionary = OWN) -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in own.get(site, []):
		if ORDER.has(id) and not out.has(id):
			out.append(id)
	return out if not out.is_empty() else pool(ROCK)


## The games a site of `group` deals: its own and the lab's, ported ones only, each once.
static func pool(group: Array[StringName]) -> Array[StringName]:
	var out: Array[StringName] = []
	for id in group + LAB:
		if ORDER.has(id) and not out.has(id):
			out.append(id)
	return out


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
		&"sling":
			return GameSling.new()
		&"tuning":
			return GameTuning.new()
		&"seismic":
			return GameSeismic.new()
		&"corescan":
			return GameCoreScan.new()
		&"culture":
			return GameCulture.new()
		&"dock":
			return GameDock.new()
	return null


## The ship's sensors as the games' 0 to 5 (each two points of SENSORS one step).
static func sensors_of(attr: int) -> int:
	return clampi(attr / 2, 0, 5)


## What system `n`'s science site deals at `site`: {id, depth, sensors, seed}.
static func deal(n: MapGen.MapNode, site: StringName = &"") -> Dictionary[String, Variant]:
	var r := Rng.derive(&"minigame", n.index if n != null else 0)
	var ids := pool_at(site)
	var out: Dictionary[String, Variant] = {}
	out.assign({
		id = ids[r.randi() % ids.size()],
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


## Starts the dealt game's slow search on a worker as its card goes up (the tray and the sling).
static func prefetch(d: Dictionary) -> void:
	if StringName(d.get("id", &"")) == &"tray":
		GameTray.prefetch(int(d.depth), stream(int(d.seed)))
	if StringName(d.get("id", &"")) == &"sling":
		GameSling.prefetch(int(d.depth), stream(int(d.seed)))


## Waits for any search still out (the desk calls it on leaving).
static func settle() -> void:
	GameTray.settle()
	GameSling.settle()
