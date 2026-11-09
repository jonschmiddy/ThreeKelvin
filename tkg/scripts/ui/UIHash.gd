class_name UIHash
extends RefCounted

## The one hash and scatter the shop, the yard and the boards draw their seeded marks with.
## Seeded art moves if these formulas do, so change them in no other place.


## A repeatable scatter in 0..1 (`hash1`).
static func hash1(v: float) -> float:
	var x := sin(v * 127.1) * 43758.5453
	return x - floorf(x)


## A repeatable position in 0..span for index `i`, or twinkles shift on each redraw.
static func scatter(i: int, span: float) -> float:
	return fmod(float(i) * 2654435761.0 / 65536.0, span)
