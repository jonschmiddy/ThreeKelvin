class_name Harness
extends RefCounted

## Shared so the merge gate's ERROR_PATTERNS need not match four spellings of one verdict.
## Measurement harnesses do not extend it: a pass count would impose a shape on them.
## Why: docs/why/Harness.md#harness-base

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


## The line the merge gate reads; `label` is the flag, so a failure says which command to re-run.
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


## `Rng.reseed` did nothing, as `start_new_run` rolls its own seed first, so checks came and went
## between gate runs. This sets `Rng.forced`, which sticks.
## Why: docs/why/Harness.md#seed-run
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


## Takes a predicate: a harness knows a button's text
## or an inner class, not the name `find_child` needs.
## Why: docs/why/Harness.md#finding-nodes
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


## Shards split a slow harness over N processes: FlightTest and
## SolveTest took ten minutes each and set the battery's length.
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


## An assertion over every case no shard can judge alone:
## shards print numbers and `ShardSum` judges the sums.
## Why: docs/why/Harness.md#totals-over-shards
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
