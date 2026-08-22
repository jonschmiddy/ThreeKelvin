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

	var path := "user://modules.json"
	var fh := FileAccess.open(path, FileAccess.WRITE)
	fh.store_string(JSON.stringify({modules = out, malfunctions = junk}, "  "))
	fh.close()
	print("  wrote %s (%d modules)" % [ProjectSettings.globalize_path(path), out.size()])
