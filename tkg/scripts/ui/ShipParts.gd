class_name ShipParts
extends RefCounted

## THE PARTS OF YOUR OWN SHIP a choice sits on (Jon, Nov 15, "C · use your own ship"): which part a
## choice lands on, read off the choice itself, and where each part is on any hull, as fractions of
## the hull's own drawn box, so every hull works with no new art. Why: docs/why/ShipParts.md#parts

## x runs rear (0) to bow (1), y top (0) to keel (1); `side` is where its label goes.
const SPOTS := {
	&"engines": {rect = Rect2(0.0, 0.28, 0.14, 0.44), side = &"left", word = "ENGINES"},
	&"radiators": {rect = Rect2(0.16, 0.0, 0.2, 0.36), side = &"up", word = "RADIATORS"},
	&"mast": {rect = Rect2(0.4, 0.0, 0.18, 0.36), side = &"up", word = "COMM"},
	&"guns": {rect = Rect2(0.62, 0.0, 0.18, 0.4), side = &"up", word = "GUNS"},
	&"bow": {rect = Rect2(0.86, 0.28, 0.14, 0.44), side = &"right", word = "BOW"},
	&"plating": {rect = Rect2(0.64, 0.62, 0.2, 0.38), side = &"down", word = "PLATING"},
	&"flank": {rect = Rect2(0.38, 0.64, 0.24, 0.36), side = &"down", word = "FLANK"},
	&"hold": {rect = Rect2(0.14, 0.62, 0.22, 0.38), side = &"down", word = "HOLD"},
}

## A check's stat picks the part that does the work.
const BY_ATTR := {
	&"thrust": &"engines",
	&"maneuver": &"flank",
	&"sensors": &"mast",
	&"stealth": &"radiators",
	&"thermal": &"radiators",
	&"hull": &"plating",
}

## Where a choice goes when its part is taken: the nearest part round the hull first.
const NEXT := {
	&"bow": [&"engines", &"plating", &"guns", &"flank", &"mast", &"hold", &"radiators"],
	&"engines": [&"hold", &"radiators", &"flank", &"mast", &"plating", &"guns"],
	&"radiators": [&"mast", &"engines", &"hold", &"guns", &"flank", &"plating"],
	&"mast": [&"radiators", &"guns", &"flank", &"hold", &"plating", &"engines"],
	&"guns": [&"mast", &"plating", &"radiators", &"flank", &"engines", &"hold"],
	&"plating": [&"flank", &"guns", &"hold", &"mast", &"engines", &"radiators"],
	&"flank": [&"hold", &"plating", &"mast", &"engines", &"radiators", &"guns"],
	&"hold": [&"flank", &"engines", &"radiators", &"plating", &"mast", &"guns"],
}

## NOT NOW (and, after, FLY ON) always holds the bow.
const LEAVE := &"bow"


## The part choice `c` wants, before any other choice is placed: a hand `part` key first, then the
## check's stat, a reading, a fight, what it spends, and walking away.
static func wanted(c: Dictionary) -> StringName:
	var hand := StringName(c.get("part", &""))
	if SPOTS.has(hand):
		return hand
	if c.has("check"):
		var by := StringName((c.check as Dictionary).get("attr", &""))
		if BY_ATTR.has(by):
			return BY_ATTR[by]
	if c.has("reads"):
		return &"mast"
	if bool(c.get("fight", false)):
		return &"guns"
	if bool(c.get("burns", false)):
		return &"engines"
	if c.has("cost_credits") or c.has("needs_material"):
		return &"hold"
	if bool(c.get("stay", false)):
		return LEAVE
	return &"hold"


## Every choice's part, in order, none sharing (the bow is NOT NOW's when `bow_taken`): a choice
## whose part is taken goes to the next free one round the hull (`NEXT`).
static func assign(choices: Array, bow_taken: bool = true) -> Array[StringName]:
	var used := {}
	if bow_taken:
		used[LEAVE] = true
	var out: Array[StringName] = []
	for c: Dictionary in choices:
		var p := wanted(c)
		if used.has(p):
			for q: StringName in NEXT[p]:
				if not used.has(q):
					p = q
					break
		used[p] = true
		out.append(p)
	return out


## How many choices in `choices` asked for a part another had already: [among the choices
## themselves, counting NOT NOW's bow too].
static func collisions(choices: Array) -> Array[int]:
	var seen := {}
	var own := 0
	var bow := 0
	for c: Dictionary in choices:
		var p := wanted(c)
		if seen.has(p):
			own += 1
		elif p == LEAVE:
			bow += 1
		seen[p] = true
	return [own, own + bow]


## Part `p`'s box on a hull drawn at `hull` (global px), the bow to the right unless `bow_left`.
static func rect_of(p: StringName, hull: Rect2, bow_left: bool = false) -> Rect2:
	var f: Rect2 = (SPOTS.get(p, SPOTS[LEAVE]) as Dictionary).rect
	var fx := 1.0 - f.end.x if bow_left else f.position.x
	var r := Rect2(hull.position + Vector2(fx * hull.size.x, f.position.y * hull.size.y),
		Vector2(f.size.x * hull.size.x, f.size.y * hull.size.y))
	return Rect2(r.position.round(), r.size.round().max(Vector2(6, 6)))


## Which way the part's label stands off the hull, with the bow's side flipped when it faces left.
static func side_of(p: StringName, bow_left: bool = false) -> StringName:
	var s := StringName((SPOTS.get(p, SPOTS[LEAVE]) as Dictionary).side)
	if bow_left and s == &"left":
		return &"right"
	if bow_left and s == &"right":
		return &"left"
	return s


static func word_of(p: StringName) -> String:
	return String((SPOTS.get(p, SPOTS[LEAVE]) as Dictionary).word)
