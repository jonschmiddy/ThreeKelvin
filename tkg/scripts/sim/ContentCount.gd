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
## Malfunctions are counted separately and belong to nobody. They are the cards
## that arrive without being chosen — the dross a hot reactor coughs into your
## deck — so they are not part of any house's forty.

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
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		var k: StringName = m.manufacturer if m.manufacturer != &"" else &"(unbranded)"
		modules[k] = int(modules.get(k, 0)) + 1
		for c in m.cards:
			var cd: CardData = c
			if cd.unplayable:
				malfunctions[cd.name] = true
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
	verdict("content")
