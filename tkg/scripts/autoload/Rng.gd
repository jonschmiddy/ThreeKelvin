extends Node
## Every deciding roll uses a seeded stream, so machines share a galaxy and runs replay.
## `derive` seeds by position for what players trigger out of order; cosmetic rolls stay global.
## Why: docs/why/Rng.md#rng-streams

## The one number a run is, already saved as `RunState.galaxy_seed`.
var master: int = 0

## Set by `-- seed N` before the run starts. Zero means roll one.
var forced: int = 0

## Streams that decide what happens to you are salted by seat, or a party gets duplicate loot.
## Seat zero is a no-op, not a zero salt, so solo seeds replay bit for bit.
## Why: docs/why/Rng.md#seat
var seat: int = 0

## Generated once at run start, in a fixed order, before play begins.
var world: RandomNumberGenerator = RandomNumberGenerator.new()
## Modules, hulls, affixes.
var loot: RandomNumberGenerator = RandomNumberGenerator.new()
## Which event, and every skill check inside it.
var event: RandomNumberGenerator = RandomNumberGenerator.new()
## Who is waiting at a node, and whether an ambush rolls.
var foe: RandomNumberGenerator = RandomNumberGenerator.new()
## Inside a fight: dodges, deck shuffles.
var fight: RandomNumberGenerator = RandomNumberGenerator.new()

## Salts must differ: two streams sharing one are a single stream and drift into lockstep.
const S_WORLD: int = 0x1F3B9C27
const S_LOOT: int = 0x7A4E1D53
const S_EVENT: int = 0x2C8F60B1
const S_FOE: int = 0x5D91A3E7
const S_FIGHT: int = 0x3E27C4F9

const _GOLDEN: int = 6364136223846793005
const _ODD: int = 1442695040888963407


## `world` is not salted by seat, as the galaxy must agree; everything else is.
## Why: docs/why/Rng.md#reseed
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


## The master seed: `-- seed N` if given, else fresh from the global generator.
func roll_master() -> int:
	if forced != 0:
		return forced
	# Positive, because it is shown to the player and typed back in.
	return randi() & 0x7FFFFFFF


## For things with a place, not a turn: seeded from position so all ships find the same.
## Why: docs/why/Rng.md#derive
func derive(tag: StringName, index: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = _mix(_mix(master, hash(tag)), index * 2 + 1)
	return r


## Stream cursors are saved, or a load would rewind them and repeat the first module.
## The 64-bit ones go as strings: JSON reads a number back as a double, which keeps 53 bits.
func state() -> Dictionary:
	return {
		"master": master, "seat": seat,
		"world": str(world.state), "loot": str(loot.state), "event": str(event.state),
		"foe": str(foe.state), "fight": str(fight.state),
	}


func restore(d: Dictionary) -> void:
	# Seat first, so a pre-seat save lands on 0 and a co-op resume keeps its ship.
	reseed(int(d.get("master", 0)), int(d.get("seat", 0)))
	world.state = _cursor(d.get("world", world.state))
	loot.state = _cursor(d.get("loot", loot.state))
	event.state = _cursor(d.get("event", event.state))
	foe.state = _cursor(d.get("foe", foe.state))
	fight.state = _cursor(d.get("fight", fight.state))


## A string (what state() writes) or the number an older save holds.
static func _cursor(v: Variant) -> int:
	return (v as String).to_int() if typeof(v) == TYPE_STRING else int(v)


# --- what Array gives you for free, and RandomNumberGenerator does not -----
# `Array.pick_random()` and `shuffle()` use the global generator, so they are replaced.

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


## SplitMix-shaped: a single multiply leaves low bits correlated for adjacent node indices.
static func _mix(a: int, b: int) -> int:
	var x: int = a ^ (b + _ODD)
	x = x * _GOLDEN
	x = x ^ (x >> 29)
	x = x * _ODD
	x = x ^ (x >> 32)
	return x & 0x7FFFFFFFFFFFFFF
