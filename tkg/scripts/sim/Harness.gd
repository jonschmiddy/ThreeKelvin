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
## a failure in a 400-line log says which command to re-run -- and with which
## seed, when it started runs (`seed_run`).
func verdict(label: String) -> void:
	if _fails > 0 and not seeds.is_empty():
		var names := PackedStringArray()
		for s in seeds:
			names.append(str(s))
		print("  on seed%s %s (replay: -- %s seed %d)" % ["s" if seeds.size() > 1 else "",
			", ".join(names), label, seeds[0]])
	print("%s: %s" % [label, "PASS" if _fails == 0 else "%d FAILURES" % _fails])


## THE SEEDS THIS HARNESS'S RUNS STARTED FROM, in order, each once.
var seeds: Array[int] = []


## THE NEXT RUN STARTS FROM SEED `n`: call it right before `Run.start_new_run`.
##
## A `Rng.reseed(n)` there did nothing. `start_new_run` draws the run's own seed
## first (`Rng.roll_master`: `Rng.forced`, or else the global generator) and
## reseeds every stream from THAT, so each harness that reseeded drove a fresh
## random galaxy, ship and hold every time it ran -- and a check that depended
## on any of them came and went between gate runs (maptest, fittest and
## subjecttest all did, Oct 11-12). This sets `Rng.forced`, which sticks.
##
## `-- <harness> seed N` on the command line wins over `n`, so a failure's seed
## (printed here and by `verdict`) replays it.
func seed_run(n: int) -> int:
	var s := n
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		if args[i] == "seed" and i + 1 < args.size() and (args[i + 1] as String).is_valid_int():
			s = int(args[i + 1])
	Rng.forced = s
	if not s in seeds:
		seeds.append(s)
		print("  [seed] %d" % s)
	return s


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


## SHARDS: a slow harness split over N processes run side by side, each its K-th
## share of the cases (`-- shard=K/N`, K from 1). FlightTest and SolveTest each
## took ten minutes as one process and set the battery's length. A case is a
## shard's when its index modulo N is K - 1, so neighbours (alike in cost) are
## dealt round. [K, N]; [1, 1] when unsplit.
static func shard() -> Vector2i:
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("shard="):
			var kn := s.substr(6).split("/")
			if kn.size() == 2 and int(kn[1]) >= 1 and int(kn[0]) >= 1 and int(kn[0]) <= int(kn[1]):
				return Vector2i(int(kn[0]), int(kn[1]))
	return Vector2i(1, 1)


## Whether case `i` is this process's (always, unsplit).
func mine(i: int) -> bool:
	if _shard.y == 0:
		_shard = shard()
	return i % _shard.y == _shard.x - 1


var _shard := Vector2i.ZERO


## AN ASSERTION OVER EVERY CASE (a share, a count against a limit), which no
## shard can judge on its own cases: unsplit it is `_ok(what, expr)`; split,
## each shard prints its numbers and `ShardSum` adds them up across the shards'
## logs and judges `expr` on the sums. `vars` are the expression's inputs:
## lower-case names are added up, UPPER-case ones are constants every shard
## must agree on. `key` names the assertion the same way in every shard.
func total(key: String, what: String, expr: String, vars: Dictionary) -> bool:
	if shard().y > 1:
		var parts := PackedStringArray()
		for v in vars:
			parts.append("%s=%s" % [v, var_to_str(vars[v])])
		print("SHARD_TOTAL %s|%s|%s" % [key, expr, ";".join(parts)])
		print("  (left to the shards' sum) %s" % what)
		return true
	var e := Expression.new()
	var held := false
	if e.parse(expr, PackedStringArray(vars.keys())) == OK:
		var r = e.execute(vars.values(), null, false)
		held = not e.has_execute_failed() and bool(r)
	else:
		print("  (expression %s: %s)" % [expr, e.get_error_text()])
	return _ok(what, held)


## The line ShardSum checks coverage by: this shard ran `mine` of the `of` cases
## every shard counts alike (all of them, summed over the shards).
func shard_end(label: String, mine_n: int, of_n: int) -> void:
	var s := shard()
	if s.y > 1:
		print("SHARD_DONE %s %d/%d mine=%d of=%d" % [label, s.x, s.y, mine_n, of_n])
