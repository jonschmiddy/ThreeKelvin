class_name Harness
extends RefCounted

## The one verdict, argument and frame-wait path for the sim tools. A RefCounted test extends it;
## a Node test composes it (`var h := Harness.new()`, `h._ok`, `h.verdict`, `quit(h.code())`).
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
	var s := seed_arg(n)
	Rng.forced = s
	if not s in seeds:
		seeds.append(s)
		print("  [seed] %d" % s)
	return s


## The seed on the command line, as `seed=N` or `seed N` (the last given wins), else `fallback`.
static func seed_arg(fallback: int) -> int:
	var s := fallback
	var args := OS.get_cmdline_user_args()
	for i in args.size():
		var a := args[i]
		if a.begins_with("seed=") and a.substr(5).is_valid_int():
			s = int(a.substr(5))
		elif a == "seed" and i + 1 < args.size() and args[i + 1].is_valid_int():
			s = int(args[i + 1])
	return s


## The value of the first `key=value` on the command line after `--`, else `fallback`.
static func arg(key: String, fallback: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback


## Wait `n` rendered frames of `tree`: `await Harness.frames(_tree, 3)`.
static func frames(tree: SceneTree, n: int) -> void:
	for i in n:
		await tree.process_frame


## Takes a predicate: a harness knows a button's text
## or an inner class, not the name `find_child` needs.
## Why: docs/why/Harness.md#finding-nodes
static func first(root: Node, matches: Callable) -> Node:
	if root == null:
		return null
	if matches.call(root):
		return root
	for c in root.get_children():
		var found := first(c, matches)
		if found != null:
			return found
	return null


## The first VISIBLE button whose text is `text` (or starts with it), so a hidden overlay's twin is
## never pressed; `enabled_only` also skips a disabled one.
static func button_with_text(root: Node, text: String, starts_with := false, enabled_only := false) -> Button:
	return first(root, func(n: Node) -> bool:
		if not n is Button or not (n as Button).is_visible_in_tree():
			return false
		if enabled_only and (n as Button).disabled:
			return false
		var shown := (n as Button).text
		return shown.begins_with(text) if starts_with else shown == text) as Button


## The first node under `root` running exactly `script` that is not on its way out.
static func node_with_script(root: Node, script: Script) -> Node:
	return first(root, func(n: Node) -> bool:
		return n.get_script() == script and not n.is_queued_for_deletion())


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
