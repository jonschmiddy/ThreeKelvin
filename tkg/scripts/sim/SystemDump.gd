extends RefCounted
## Real systems, written out as JSON, for laying out the system map against the
## game's own data:  godot --path . -- systemdump=<path> [seed=N]
##
## Six of them, chosen to cover the cases the map has to draw: a red star with
## a gas giant and options, a station, a pulsar, a deep system holding an
## exclusive group, a system inside a nebula, and the core. Each with its star
## and sky facts, its place line, and every
## option it rolled -- title, full text, tags, group, and each choice with its
## check, cost and flags, and the text of one outcome (taken by running it, so
## the run this harness made up is spent: it quits straight after).

func _choice(c: Dictionary) -> Dictionary:
	var out := {"label": String(c.get("label", "")), "stay": bool(c.get("stay", false)),
		"fight": bool(c.get("fight", false))}
	if c.has("check"):
		out["check"] = {"attr": String(c.check.get("attr", "")), "need": int(c.check.get("need", 0))}
		out["odds"] = SkillCheck.odds_line(c.check)
	if c.has("cost_credits"):
		out["cost"] = int(c.cost_credits)
	if c.has("needs_material"):
		out["material"] = String(c.needs_material)
	return out


func _node(n: MapGen.MapNode) -> Dictionary:
	OptionTable.ensure(n)
	var opts := []
	for id in n.options:
		var o := OptionTable.by_id(id)
		var chs := []
		for c in o.get("choices", []):
			chs.append(_choice(c))
		opts.append({"id": String(id), "title": String(o.get("title", "")), "body": String(o.get("body", "")),
			"tags": o.get("tags", []).map(func(t): return String(t)), "group": String(o.get("group", "")),
			"choices": chs})
	return {"index": n.index, "name": MapGen.star_name(n), "type": MapGen.NodeType.keys()[n.type],
		"star": MapGen.Star.keys()[n.star], "star_kind": MapGen.star_kind(n), "gas_giant": n.gas_giant,
		"near_pulsar": n.near_pulsar, "in_nebula": n.in_nebula, "nebula_emission": n.nebula_emission, "fauna": n.fauna, "danger": n.danger,
		"layer": n.layer, "development": MapGen.Development.keys()[n.development],
		"region": MapGen.Region.keys()[n.region], "place": MapGen.place_line(n), "options": opts}


func _has_group(n: MapGen.MapNode) -> bool:
	var seen := {}
	for id in n.options:
		var g := String(OptionTable.by_id(id).get("group", ""))
		if g == "":
			continue
		if seen.has(g):
			return true
		seen[g] = true
	return false


func run(tree: SceneTree) -> void:
	await tree.process_frame
	Rng.forced = 4242
	var path := ""
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("seed="):
			Rng.forced = int((a as String).substr(5))
		elif (a as String).begins_with("systemdump="):
			path = (a as String).substr(11)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var red: MapGen.MapNode = null
	var station: MapGen.MapNode = null
	var pulsar: MapGen.MapNode = null
	var deep: MapGen.MapNode = null
	var nebula: MapGen.MapNode = null
	var core: MapGen.MapNode = null
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		match n.type:
			MapGen.NodeType.STATION:
				if station == null or (n.gas_giant and not station.gas_giant):
					station = n
			MapGen.NodeType.PULSAR:
				if pulsar == null:
					pulsar = n
			MapGen.NodeType.CORE:
				core = n
			MapGen.NodeType.SYSTEM:
				OptionTable.ensure(n)
				if red == null and n.star == MapGen.Star.RED and n.gas_giant and n.options.size() >= 3:
					red = n
				if _has_group(n) and (deep == null or n.layer > deep.layer):
					deep = n
				if n.in_nebula and n.options.size() >= 3 and (nebula == null or (n.nebula_emission and not nebula.nebula_emission)):
					nebula = n
	var out := []
	for n in [red, station, pulsar, deep, nebula, core]:
		if n != null:
			out.append(_node(n))
	# one outcome's text per choice, for the RESULT state: run each choice's
	# first outcome on the throwaway run, keeping whatever text it returns
	for sys in out:
		var n2: MapGen.MapNode = Run.map[int(sys["index"])]
		for i in n2.options.size():
			var o := OptionTable.by_id(n2.options[i])
			var chs: Array = o.get("choices", [])
			for j in chs.size():
				var c: Dictionary = chs[j]
				var call: Callable = c.get("met", c.get("effect", Callable()))
				if call.is_valid() and not Run.dead:
					Run.at = n2.index
					var res: Variant = call.call()
					if typeof(res) == TYPE_DICTIONARY:
						sys["options"][i]["choices"][j]["outcome"] = String((res as Dictionary).get("text", ""))
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(out, "\t"))
	f.close()
	print("  systemdump: %d systems to %s" % [out.size(), path])
	tree.quit()
