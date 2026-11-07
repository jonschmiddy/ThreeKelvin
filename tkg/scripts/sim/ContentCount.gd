extends Harness

## A measurement, not a gate: a test failing for a year over unwritten content gets ignored.
## Counts unique cards by name, not grants. Malfunctions live in `DB.MALFUNCTIONS`, not on modules.
## Why: docs/why/ContentCount.md#content-count

## Korvan, unbranded stock and malfunctions first, as those are being written.
const TARGET := {
	&"korvan": 40,
	&"(unbranded)": 20,
	&"solari": 40, &"probate": 40, &"redline": 40,
	&"cygnet": 40, &"verity": 40, &"calyx": 40,
}
const MALFUNCTION_TARGET := 15


func run() -> void:
	var modules := {}
	var cards := {}
	var seen := {}
	var malfunctions := {}
	for row in DB.MALFUNCTIONS:
		malfunctions[row[1]] = true
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		var k: StringName = m.manufacturer if m.manufacturer != &"" else &"(unbranded)"
		modules[k] = int(modules.get(k, 0)) + 1
		for c in m.cards:
			var cd: CardData = c
			if cd.unplayable:
				continue
			if seen.has(cd.name):
				continue
			seen[cd.name] = k
			cards[k] = int(cards.get(k, 0)) + 1

	print("  %-22s %7s %7s %7s %7s" % ["", "parts", "cards", "want", "short"])
	var keys: Array = TARGET.keys()
	var short := 0
	for k in keys:
		var have: int = int(cards.get(k, 0))
		var want: int = TARGET[k]
		var gap: int = maxi(0, want - have)
		short += gap
		print("  %-22s %7d %7d %7d %7s"
			% [k, int(modules.get(k, 0)), have, want, "-" if gap == 0 else str(gap)])
	var mg: int = maxi(0, MALFUNCTION_TARGET - malfunctions.size())
	short += mg
	print("  %-22s %7s %7d %7d %7s"
		% ["malfunctions", "-", malfunctions.size(), MALFUNCTION_TARGET,
			"-" if mg == 0 else str(mg)])

	print("  %d unique cards across %d modules; %d still to write"
		% [seen.size(), DB.modules.size(), short])
	_ok("the catalogue was counted", not seen.is_empty())
	if "json" in OS.get_cmdline_user_args():
		_dump()
	verdict("content")


## A hand-copied catalogue is wrong the day after, so the review page is built from this export.
## Why: docs/why/ContentCount.md#catalogue-dump
func _dump() -> void:
	var out: Array = []
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		var cards: Array = []
		for c in m.resolved_cards():
			var cd: CardData = c
			# Rarity per card, not per part: the card rarity law is about the pair a module grants.
			cards.append({name = cd.name, text = cd.describe(),
				energy = cd.energy, heat = cd.heat,
				rarity = ModuleData.rarity_name(cd.rarity) if cd.rarity >= 0 else ""})
		# Both the grant and the price, so a Voidwhale Ganglion does not read as free.
		# A list: `String()` on the raw array stringified it and pages stopped grouping.
		# Why: docs/why/ContentCount.md#catalogue-dump
		var axes: Array = []
		for raw in DB.PASSIVE_AXIS.get(id, []):
			axes.append(String(raw))
		var axis: String = String(axes[0]) if not axes.is_empty() else ""
		var pips: int = DB.ATTR_BUMP[int(m.rarity)] if not axes.is_empty() else 0
		var cost_axis := ""
		var cost_pips := 0
		if DB.PASSIVE_COST.has(id):
			var row: Array = DB.PASSIVE_COST[id]
			cost_axis = String(row[0])
			cost_pips = int(row[1])
		var f := m.footprint()
		out.append({
			id = String(id),
			name = m.name,
			manufacturer = String(m.manufacturer),
			manufacturer_name = DB.manufacturer_name(m.manufacturer) if m.manufacturer != &"" else "Unbranded",
			slot = ModuleData.slot_name(m.slot),
			rarity = ModuleData.rarity_name(m.rarity),
			w = f.x, h = f.y, cells = m.cells(),
			flavour = m.flavour,
			axis = axis, axes = axes, pips = pips,
			cost_axis = cost_axis, cost_pips = cost_pips,
			reactor = m.reactor,
			cards = cards,
		})
	# Malfunctions travel with it: not modules, but reviewers review what can end up in a deck.
	var junk: Array = []
	for row in DB.MALFUNCTIONS:
		var c := DB.malfunction(row[0])
		junk.append({id = String(row[0]), name = c.name, text = c.describe(),
			corrode = int(row[2]), smoulder = int(row[3]), fused = bool(row[4])})

	_vet(out, junk)

	# Collected from the cards: `CardData.keywords()` is the only definition, so none goes stale.
	# Why: docs/why/ContentCount.md#keyword-glossary
	var glossary := {}
	for id in DB.modules:
		for c in (DB.modules[id] as ModuleData).resolved_cards():
			for pair in (c as CardData).keywords():
				glossary[String(pair[0])] = String(pair[1])
	for row in DB.MALFUNCTIONS:
		for pair in DB.malfunction(row[0]).keywords():
			glossary[String(pair[0])] = String(pair[1])
	var words: Array = []
	for w in glossary:
		words.append({word = w, text = glossary[w]})
	words.sort_custom(func(x, y): return String(x.word) < String(y.word))

	var path := "user://modules.json"
	var fh := FileAccess.open(path, FileAccess.WRITE)
	fh.store_string(JSON.stringify({modules = out, malfunctions = junk,
		keywords = words}, "  "))
	fh.close()
	print("  wrote %s (%d modules)" % [ProjectSettings.globalize_path(path), out.size()])


## `String()` turned an array gauge name into text and nothing errored: pages stopped grouping.
## Vocabulary is built from the game, and it fails the harness: a distrusted export is worse.
## Why: docs/why/ContentCount.md#export-vetting
func _vet(rows: Array, junk: Array) -> void:
	var gauges := {}
	# `Run`, not `RunState`: no class_name, so the harness fails to compile and hangs 120 s.
	# Why: docs/why/ContentCount.md#export-vetting
	for g in Run.PER_PIP:
		gauges[String(g)] = true
	var grades := {}
	for r in ModuleData.Rarity.size():
		grades[ModuleData.rarity_name(r)] = true
	var slots := {}
	for sl in ModuleData.Slot.size():
		slots[ModuleData.slot_name(sl)] = true

	var bad: Array[String] = []
	for row in rows:
		var d: Dictionary = row
		var who: String = str(d.get("name", "?"))
		if not grades.has(str(d.get("rarity", ""))):
			bad.append("%s: rarity %s" % [who, d.get("rarity")])
		if not slots.has(str(d.get("slot", ""))):
			bad.append("%s: slot %s" % [who, d.get("slot")])
		for a in d.get("axes", []):
			if not gauges.has(str(a)):
				bad.append("%s: gauge %s" % [who, a])
		var ca: String = str(d.get("cost_axis", ""))
		if ca != "" and not gauges.has(ca):
			bad.append("%s: cost gauge %s" % [who, ca])
		if int(d.get("cells", 0)) < 1:
			bad.append("%s: %d cells" % [who, int(d.get("cells", 0))])
		if (d.get("cards", []) as Array).is_empty():
			bad.append("%s: no cards" % who)
		for c in d.get("cards", []):
			if str((c as Dictionary).get("name", "")) == "":
				bad.append("%s: a card with no name" % who)
	for row in junk:
		if str((row as Dictionary).get("name", "")) == "":
			bad.append("a malfunction with no name")

	_ok("every row of the export is a shape the page can read", bad.is_empty())
	for b in bad:
		_fail(b)
