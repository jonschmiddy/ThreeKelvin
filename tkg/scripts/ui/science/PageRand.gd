class_name PageRand
extends RefCounted

## The comet pages' own 32-bit number generators, bit for bit, so a port draws what its page drew:
## `mulberry` (grain noise, stars) and `hash` (rock and ground texture). Values are kept in
## [0, 2^32), the bits JS's int32 holds. Why: docs/why/MiniGame.md#skim

const M := 0xFFFFFFFF


## `mulberry`'s state after one step, and the draw that state gives.
static func mb_next(a: int) -> int:
	return (a + 0x6D2B79F5) & M


static func mb_value(a: int) -> float:
	var t := imul(a ^ (a >> 15), 1 | a)
	t = ((t + imul(t ^ (t >> 7), 61 | t)) & M) ^ t
	return float((t ^ (t >> 14)) & M) / 4294967296.0


## `Math.imul`: the low 32 bits of the product, without 64-bit overflow.
static func imul(x: int, y: int) -> int:
	x &= M
	y &= M
	return (x * (y & 0xFFFF) + (((x * (y >> 16)) & 0xFFFF) << 16)) & M


## The pages' `hash(a, b)`: a value in [0, 1) for two integers (negatives as JS's `|0` has them).
static func hash(a: int, b: int) -> float:
	var h := (imul(a, 374761393) + imul(b, 668265263)) & M
	h = imul(h ^ (h >> 13), 1274126177)
	return float((h ^ (h >> 16)) & M) / 4294967296.0
