class_name Harness
extends RefCounted

## What every pass/fail harness in `scripts/sim/` counts and prints.
##
## Four of them carried a byte-identical `_ok()` and a verdict line that differed
## only in the name it printed. Harmless right up until the format changes, at
## which point the merge gate's ERROR_PATTERNS have to match four spellings of
## the same sentence.
##
## NOT every harness extends this, deliberately. `HeadlessSim`, `MarketSim`,
## `SaveTest`, `GlyphSheet` and `RepairSheet` report a MEASUREMENT rather than a
## pass count — a win rate, a price sweep, a distribution — and folding those
## into a failure counter would be imposing a shape on them rather than sharing
## one they already had.

var _fails: int = 0


## Print one assertion and remember whether it held. Returns the condition, so a
## caller can guard what comes next on it: `if not _ok(...): return`.
func _ok(what: String, condition: bool) -> bool:
	if condition:
		print("  ok   %s" % what)
	else:
		print("  FAIL %s" % what)
		_fails += 1
	return condition


## A failure with no assertion behind it — a timeout, a thing that never arrived.
func _fail(why: String) -> void:
	print("  FAIL %s" % why)
	_fails += 1


## The line the merge gate reads. `label` is the flag the harness runs under, so
## a failure in a 400-line log says which command to re-run.
func verdict(label: String) -> void:
	print("%s: %s" % [label, "PASS" if _fails == 0 else "%d FAILURES" % _fails])


## The first node under `root` that `matches` accepts, depth-first, or null.
##
## Godot's `find_child` matches on a NAME, and a harness driving a real screen
## almost never knows the name — it knows the button reads "STOW", or that the
## node it wants is an inner class the engine has no name for. Both of those are
## a predicate, so this takes one. `ConvoyTest._find_slot` is the second copy of
## this walk and is left alone until that file has some other reason to move.
func first(root: Node, matches: Callable) -> Node:
	if matches.call(root):
		return root
	for c in root.get_children():
		var found := first(c, matches)
		if found != null:
			return found
	return null


## Nonzero when anything failed, for `SceneTree.quit()`.
func code() -> int:
	return 1 if _fails > 0 else 0
