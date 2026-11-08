class_name HoldItem
extends Resource

## Holds only what is about having a shape; materials never stack, so every item is an instance.
## Why: docs/why/HoldItem.md#hold-items


@export var name: String = ""

## The authored footprint shares the hold's vocabulary, so a hold of long things reads as guns.
## Why: docs/why/HoldItem.md#authored-shape
@export var size: Vector2i = Vector2i.ONE

## Rotated a quarter turn in the hold. Packing, not identity.
@export var turned: bool = false

## Stored runtime state: array order would re-pack the hold on every removal.
@export var hold_at: Vector2i = -Vector2i.ONE


## The shape it actually occupies right now. Everything that asks where an item
## fits asks THIS; `size` is what it was authored as.
func footprint() -> Vector2i:
	var w := maxi(1, size.x)
	var h := maxi(1, size.y)
	return Vector2i(h, w) if turned else Vector2i(w, h)


## Cells consumed. Convenience, and the one place the multiply is written.
## Turning cannot change it, which is why the hold's totals need no rotation.
func cells() -> int:
	return maxi(1, size.x) * maxi(1, size.y)


## What the hold shows when you point at it. Overridden by each kind, because a
## module says its grade and a material says its tier.
func hold_line() -> String:
	return name
