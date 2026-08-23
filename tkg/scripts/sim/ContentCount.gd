extends Harness

## How much of the catalogue actually exists:
##   godot --headless --path . -- content
##
## A MEASUREMENT, not a gate. It prints what each house has and what it is
## supposed to have, and passes either way — the same shape as `-- glyphs` and
## for the same reason: a number nobody can see does not get acted on, and a
## test that fails for a year because content has not been written yet is a test
## everybody learns to ignore.
##
## Counts UNIQUE CARDS BY NAME, not grants. The module gallery says "98 cards"
## and that is the honest count of what a deck can be handed, because two
## modules can grant the same verb — a house with eight parts that all fit a
## Brace is not a house with eight cards. This asks the other question: how many
## DIFFERENT things can this house do.
##
## MALFUNCTIONS ARE NOT ON MODULES, and this used to count them as though they
## were — it reported 1, and that 1 was a dead `dross` module nothing could hand
## out. They live in `DB.MALFUNCTIONS` now, which is where a thing that arrives
## unasked belongs: it costs a deck slot and nothing else.

## What the catalogue is aiming at. Korvan, the unbranded stock and the
## malfunctions first, because those are the three being written; the other six
## houses are listed so the shortfall is visible rather than forgotten.
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


## Every module as JSON, for building a review page out of.
##   godot --headless --path . -- content json
##
## Exists because the alternative is retyping the catalogue by hand into
## whatever is reviewing it, and a hand-copied catalogue is wrong the day after
## it is copied. The picking page for one house is going to be made seven times;
## this is the half that must not be done seven times by eye.
func _dump() -> void:
	var out: Array = []
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		var cards: Array = []
		for c in m.resolved_cards():
			var cd: CardData = c
			# RARITY PER CARD, not just per part. The card rarity law is a claim
			# about the pair a module grants — one at its own grade and one at or
			# below — and a dump that only carried the PART's grade could not be
			# used to check it. `resolved_cards` has already applied the law, so
			# this is the answer rather than the input.
			cards.append({name = cd.name, text = cd.describe(),
				energy = cd.energy, heat = cd.heat,
				rarity = ModuleData.rarity_name(cd.rarity) if cd.rarity >= 0 else ""})
		# THE GAUGE IT MOVES, and by how much. Both halves, because a part can
		# grant on one axis and be priced on another, and a page that showed only
		# the grant would say a Voidwhale Ganglion is free.
		# A LIST, since a part may name two gauges. It was String() on the raw
		# value, which quietly stringified the array into "[\"hull\"]" the moment
		# parts stopped having exactly one — the export kept working and every page
		# reading it stopped grouping.
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
			house = String(m.manufacturer),
			house_name = DB.manufacturer_name(m.manufacturer) if m.manufacturer != &"" else "Unbranded",
			slot = ModuleData.slot_name(m.slot),
			rarity = ModuleData.rarity_name(m.rarity),
			w = f.x, h = f.y, cells = m.cells(),
			flavour = m.flavour,
			axis = axis, axes = axes, pips = pips,
			cost_axis = cost_axis, cost_pips = cost_pips,
			reactor = m.reactor,
			cards = cards,
		})
	# The malfunctions travel with them. They are not modules and never will be
	# — that was a bug once — but anything reviewing the catalogue is reviewing
	# what can end up in a deck, and sixteen of these can.
	var junk: Array = []
	for row in DB.MALFUNCTIONS:
		var c := DB.malfunction(row[0])
		junk.append({id = String(row[0]), name = c.name, text = c.describe(),
			corrode = int(row[2]), smoulder = int(row[3]), fused = bool(row[4])})

	_vet(out, junk)

	var path := "user://modules.json"
	var fh := FileAccess.open(path, FileAccess.WRITE)
	fh.store_string(JSON.stringify({modules = out, malfunctions = junk}, "  "))
	fh.close()
	print("  wrote %s (%d modules)" % [ProjectSettings.globalize_path(path), out.size()])


## THE EXPORT IS A CONTRACT AND NOTHING WAS CHECKING IT.
##
## `PASSIVE_AXIS` values became arrays and the line above was still doing
## `String()` on one. GDScript will stringify anything, so a gauge name came
## out as the four characters `["hull"]`, the JSON stayed valid, the file kept
## being written, and every page reading it stopped grouping. Nothing errored
## at either end. It was found by looking at a table that had gone blank.
##
## THE VOCABULARY IS BUILT FROM THE GAME, not typed here. A hand-written list
## of legal gauge names is a second place for the truth to live and it goes
## stale the first time somebody adds a gauge; asking PER_PIP what the gauges
## are cannot.
##
## Fails the harness rather than warning, because an export nobody can trust is
## worse than no export: it produces a page that looks right and is not, and
## the whole argument for generating the manifest was that a hand-copied one
## goes wrong silently.
func _vet(rows: Array, junk: Array) -> void:
	var gauges := {}
	# `Run`, the singleton, and not `RunState` — that script carries no
	# class_name, so the identifier does not exist and the whole harness fails to
	# COMPILE. Which does not look like a compile error from outside: `.new()`
	# returns nothing, `get_tree().quit()` never runs, and Godot sits there until
	# the gate’s watchdog kills it at 120 seconds. Database reaches the same
	# constants through a preload because it runs before the autoload exists; a
	# harness runs after, so the singleton is right here.
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
