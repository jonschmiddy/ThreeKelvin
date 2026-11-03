extends Node

## A SPLIT HARNESS'S TOTALS, judged across its shards' logs:
##   godot --headless --path . -- sheet=ShardSum label=<name> logs=<log>,<log>,...
## A slow harness run as N shards (`-- shard=K/N`, `Harness.shard`) judges each
## case in the shard that ran it, but an assertion over every case (found and
## clean in at least 99% of a sweep, at most so many left) needs them all: each
## shard prints its numbers for it (`Harness.total`, a SHARD_TOTAL line) and
## this adds them up and judges the expression on the sums, as the harness
## unsplit would have. It also holds the split itself: every shard's log ended
## (its SHARD_DONE line), K from 1 to N each once with N the logs given, and the
## cases the shards ran add up to every case, once, and every total came from
## every shard (each prints all of them, nought for a sweep it has no case of).
## PASS: `<label>_total: PASS`. Each shard's own verdict (`<label>: PASS`) is
## read by whoever ran it.

var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var label := ""
	var logs := PackedStringArray()
	for a in OS.get_cmdline_user_args():
		var s := a as String
		if s.begins_with("label="):
			label = s.substr(6)
		elif s.begins_with("logs="):
			logs = s.substr(5).split(",", false)
	if label == "" or logs.is_empty():
		h._fail("usage: -- sheet=ShardSum label=<name> logs=<log>,<log>,...")
		_end(label)
		return
	var n := logs.size()
	var seen := {}
	var mine_sum := 0
	var of_n := -1
	## key -> {expr, vars (name -> summed value), shards}
	var tot := {}
	var order: Array = []
	for path in logs:
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			h._fail("no log at %s" % path)
			continue
		var done := false
		while not f.eof_reached():
			var line := f.get_line()
			if line.begins_with("SHARD_DONE %s " % label):
				# SHARD_DONE <label> K/N mine=M of=T
				var w := line.split(" ")
				var kn := w[2].split("/")
				var k := int(kn[0])
				h._ok("%s: shard %d of %d (as the %d logs given)" % [path.get_file(), k, int(kn[1]), n], int(kn[1]) == n and k >= 1 and k <= n and not seen.has(k))
				seen[k] = true
				mine_sum += int(w[3].substr(5))
				var of_k := int(w[4].substr(3))
				if of_n >= 0 and of_k != of_n:
					h._fail("%s counts %d cases in all, another shard %d" % [path.get_file(), of_k, of_n])
				of_n = of_k
				done = true
			elif line.begins_with("SHARD_TOTAL "):
				# SHARD_TOTAL <key>|<expr>|name=value;name=value
				var p := line.substr(12).split("|")
				if p.size() != 3:
					h._fail("a SHARD_TOTAL line not in three parts: %s" % line)
					continue
				var key: String = p[0]
				if not tot.has(key):
					tot[key] = {"expr": p[1], "vars": {}, "shards": 0}
					order.append(key)
				var T: Dictionary = tot[key]
				if String(T.expr) != p[1]:
					h._fail("%s: the shards judge it differently (%s, %s)" % [key, T.expr, p[1]])
				T.shards = int(T.shards) + 1
				for kv in p[2].split(";", false):
					var eq := (kv as String).find("=")
					var nm := (kv as String).substr(0, eq)
					var v = str_to_var((kv as String).substr(eq + 1))
					var vars: Dictionary = T.vars
					if nm == nm.to_upper():
						if vars.has(nm) and vars[nm] != v:
							h._fail("%s: the shards' %s differ (%s, %s)" % [key, nm, vars[nm], v])
						vars[nm] = v
					else:
						vars[nm] = (vars[nm] + v) if vars.has(nm) else v
		if not done:
			h._fail("%s never ended (no SHARD_DONE %s line)" % [path.get_file(), label])
	h._ok("%s: every case run once across the %d shards (%d of %d)" % [label, n, mine_sum, of_n], seen.size() == n and mine_sum == of_n and of_n > 0)
	for key: String in order:
		var T2: Dictionary = tot[key]
		var vars2: Dictionary = T2.vars
		var e := Expression.new()
		var held := false
		var parts := PackedStringArray()
		for nm2 in vars2:
			parts.append("%s %s" % [nm2, vars2[nm2]])
		if e.parse(String(T2.expr), PackedStringArray(vars2.keys())) == OK:
			var r = e.execute(vars2.values(), null, false)
			held = not e.has_execute_failed() and bool(r)
		h._ok("%s, over %d shards: %s (%s)" % [key, T2.shards, T2.expr, ", ".join(parts)], held)
		# (every shard prints every total, its own cases' numbers, nought where
		# it has none: one printed by fewer lost a shard's numbers for it)
		h._ok("%s: printed by %d of the %d shards" % [key, T2.shards, n], int(T2.shards) == n)
	_end(label)


func _end(label: String) -> void:
	h.verdict("%s_total" % label)
	get_tree().quit(h.code())
