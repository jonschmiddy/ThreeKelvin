extends Node
## Every roll that decides something, and where its seed comes from.
##
## Before this, 175 call sites reached for the global `randi()`/`randf()`, which
## is one generator shared by the galaxy, the loot, the enemies, the events and
## the star field. That has three costs, and only the first one is about co-op:
##
## 1. **Four machines cannot share a galaxy.** A seed is only worth sending if
##    the receiver draws the same numbers from it in the same order.
## 2. **A bug cannot be handed to anyone.** "It stranded me on jump 60" is not
##    reproducible when the run cannot be replayed. With a master seed it is one
##    number: `godot --path . -- seed 12345`.
## 3. **The balance sim cannot replay a failure.** It reports that 40% of runs
##    strand. It could not, until now, show you one of them twice.
##
## ## Streams, and why there is more than one
##
## One generator for everything means every draw moves every other system. Roll
## one extra affix on a module and the next galaxy is different, because the
## galaxy is downstream of the same cursor. That makes tuning impossible: you
## change a loot weight, the whole world changes, and the sim reports a number
## you cannot attribute to anything.
##
## So each concern gets its own generator, each seeded from the master by a
## different constant. Combat can draw ten thousand times without moving the
## map by one system. This is the property that makes seeded runs useful rather
## than merely deterministic.
##
## ## Streams versus positions
##
## A stream is a cursor, so it only agrees across machines when everybody draws
## from it in the same order. That holds for the world: it is generated once, at
## run start, before anybody has done anything.
##
## It does NOT hold for anything a player triggers. Four ships dock at four
## stations in whatever order they choose, and a shared cursor would hand them
## each other's shelves. So anything a player can reach out of order is seeded
## from WHERE it is rather than from WHEN it was asked for — see derive(). The
## codebase already had this instinct: `StarchartScreen`, `NebulaField` and
## `MapGen.star_name()` all salt `Run.galaxy_seed` with a position. derive() is
## that pattern, named and given a mixer that is better than `* 2654435761`.
##
## ## What is deliberately NOT here
##
## Cosmetic rolls. Audio pitch variation, damage-number jitter, the launcher's
## background galaxy. They decide nothing, they must not be identical on four
## machines, and routing them through a stream would only let a particle effect
## move the loot table. They keep the global generator, and that is correct.

## The one number a run is. Everything below is derived from it, and it is
## already saved: `RunState.galaxy_seed` is this seed, which is why loading a
## run rebuilds the same sky.
var master: int = 0

## Set by `-- seed N` before the run starts. Zero means roll one.
var forced: int = 0

## WHICH SHIP IN THE PARTY THIS MACHINE IS. Zero when flying alone.
##
## A shared seed gives four machines an identical galaxy, which is exactly what
## is wanted for the WORLD and exactly wrong for anything paid to a PLAYER. The
## streams below are cursors, not derivations: four machines that have made the
## same number of draws are at the same place in them, so two ships that kill
## the same frigate on the same turn are handed the same two modules — and a
## party's loot is duplicated rather than distributed. Worse, the moment the
## cursors drift apart the duplication stops for no reason anybody can see,
## which makes it look like a network bug instead of a seeding one.
##
## So the streams that decide what happens TO you are salted by your seat, and
## `world` is not, because the galaxy has to agree. See reseed().
##
## Zero is a real value and it is deliberately a NO-OP rather than a salt of
## zero: a solo run must replay bit-for-bit from `-- seed N`, and every seed
## anybody has ever written in a bug report was rolled without this.
var seat: int = 0

## Generated once at run start, in a fixed order, before play begins.
var world: RandomNumberGenerator = RandomNumberGenerator.new()
## Modules, hulls, affixes.
var loot: RandomNumberGenerator = RandomNumberGenerator.new()
## Which event, and every skill check inside it.
var event: RandomNumberGenerator = RandomNumberGenerator.new()
## Who is waiting at a node, and whether an ambush rolls.
var foe: RandomNumberGenerator = RandomNumberGenerator.new()
## Inside a fight: dodges, reinforcements, deck shuffles.
var fight: RandomNumberGenerator = RandomNumberGenerator.new()

## Salts. Arbitrary, large, odd, and never reused — the only requirement is that
## no two are equal, because two streams sharing a salt are one stream wearing
## two names and would drift into lockstep without anything looking wrong.
const S_WORLD: int = 0x1F3B9C27
const S_LOOT: int = 0x7A4E1D53
const S_EVENT: int = 0x2C8F60B1
const S_FOE: int = 0x5D91A3E7
const S_FIGHT: int = 0x3E27C4F9

const _GOLDEN: int = 6364136223846793005
const _ODD: int = 1442695040888963407


## Start a run's rolls. Call once, before anything is generated.
##
## `seat_index` is which ship in the party this machine is flying — see `seat`.
## The galaxy is NOT salted with it: `world` builds the map, the regions and the
## names, and four players who disagree about those are not in the same game.
## Everything else here decides something that happens to one player, so it is
## salted, and the whole party is not handed the same drop off the same kill.
func reseed(seed_value: int, seat_index: int = 0) -> void:
	master = seed_value
	seat = maxi(0, seat_index)
	world.seed = _mix(master, S_WORLD)
	loot.seed = _seat(_mix(master, S_LOOT))
	event.seed = _seat(_mix(master, S_EVENT))
	foe.seed = _seat(_mix(master, S_FOE))
	fight.seed = _seat(_mix(master, S_FIGHT))


## Salt one stream by the seat, or leave it exactly as it was when flying alone.
func _seat(base: int) -> int:
	return base if seat == 0 else _mix(base, seat)


## The master seed for a new run: the one from `-- seed N` if there is one, and
## otherwise a fresh one from the global generator, which Godot has already
## randomised by the time this runs.
func roll_master() -> int:
	if forced != 0:
		return forced
	# Positive, because it is shown to the player and typed back in.
	return randi() & 0x7FFFFFFF


## A generator for a thing that has a place rather than a turn.
##
## Use this wherever a player can reach the same content in a different order
## than another player would: station shelves, a derelict's contents, whatever
## is sitting at node 46. The result depends only on the master seed and the
## salt, so all four ships find the same thing there, and finding it does not
## move anything else.
##
## `tag` is folded in so that two different things at the same node — the shop
## and the hull on the rack — do not draw the same numbers.
func derive(tag: StringName, index: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = _mix(_mix(master, hash(tag)), index * 2 + 1)
	return r


## Where every stream's cursor is, for the save file.
##
## Without this, loading a run would rewind every stream to its start, and the
## next module rolled after a load would be the first module of the run again.
## That is both a save-scum and a bug that only shows up on the second session.
func state() -> Dictionary:
	return {
		"master": master, "seat": seat,
		"world": world.state, "loot": loot.state, "event": event.state,
		"foe": foe.state, "fight": fight.state,
	}


func restore(d: Dictionary) -> void:
	# Seat first, so a save that predates it lands on 0 and a resumed co-op run
	# does not quietly change which ship it is. The cursors below overwrite the
	# seeds anyway; this only matters for a field the save is missing.
	reseed(int(d.get("master", 0)), int(d.get("seat", 0)))
	world.state = int(d.get("world", world.state))
	loot.state = int(d.get("loot", loot.state))
	event.state = int(d.get("event", event.state))
	foe.state = int(d.get("foe", foe.state))
	fight.state = int(d.get("fight", fight.state))


# --- what Array gives you for free, and RandomNumberGenerator does not -----
#
# `Array.pick_random()` and `Array.shuffle()` are hard-wired to the global
# generator, so every one of them had to be replaced rather than redirected.
# These are the replacements and they are the reason the diff is large.

static func pick(r: RandomNumberGenerator, from: Array) -> Variant:
	if from.is_empty():
		return null
	return from[r.randi() % from.size()]


## Fisher-Yates, in place, to match `Array.shuffle()`'s signature exactly so
## that call sites change by one word.
static func shuffle(r: RandomNumberGenerator, arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := r.randi() % (i + 1)
		var t: Variant = arr[i]
		arr[i] = arr[j]
		arr[j] = t


## SplitMix-shaped. The codebase's existing `* 2654435761` salt is a single
## multiply, which leaves low bits correlated — two adjacent node indices give
## two seeds that start their sequences suspiciously close together. This
## avalanches properly, which matters now that map position is a seed source.
static func _mix(a: int, b: int) -> int:
	var x: int = a ^ (b + _ODD)
	x = x * _GOLDEN
	x = x ^ (x >> 29)
	x = x * _ODD
	x = x ^ (x >> 32)
	return x & 0x7FFFFFFFFFFFFFF
