extends RefCounted

func _outs(ch: Dictionary) -> String:
	var o: Array[String] = []
	for k in ["met", "clean", "partial", "botched", "effect"]:
		if ch.has(k):
			o.append(k)
	return "/".join(o)

func run(tree: SceneTree) -> void:
	var rows := OptionTable.all()
	print("TOTAL %d" % rows.size())
	for raw in rows:
		var o: Dictionary = raw
		var gates: Array[String] = []
		for g in ["needs_star", "needs_giant", "needs_pulsar", "needs_fauna",
				"needs_nebula", "needs_region", "needs_development",
				"needs_security", "needs_manufacturer", "min_danger",
				"max_danger", "needs_layer", "placed"]:
			if o.has(g):
				gates.append("%s=%s" % [g, o[g]])
		var chs: Array[String] = []
		for c in o.get("choices", []):
			var ch: Dictionary = c
			var chk := ""
			if ch.has("check"):
				var k: Dictionary = ch.check
				chk = " [%s %s]" % [k.get("attr", "?"), k.get("need", "?")]
			chs.append("%s%s (%s)" % [ch.get("label", "?"), chk, _outs(ch)])
		print("---")
		print("ID %s | TITLE %s | TAGS %s | GROUP %s | WEIGHT %s" % [
			o.get("id", "?"), o.get("title", "?"), o.get("tags", []),
			o.get("group", ""), o.get("weight", "?")])
		print("GATES %s" % ("none" if gates.is_empty() else ", ".join(gates)))
		print("BODY %s" % o.get("body", ""))
		for s in chs:
			print("  CHOICE %s" % s)
	tree.quit()
