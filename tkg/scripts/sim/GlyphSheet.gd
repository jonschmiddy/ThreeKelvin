extends RefCounted

## Glyph spread is a distribution problem, checked over the whole set, not eight cards.
## It caught the old scheme: attack drew 40% and defend 20%.
## Why: docs/why/GlyphSheet.md#glyph-sheet

## A smoke alarm, not a law: over a third means a `CardData.glyph_kind()` rung catches all.
const CROWDED := 0.34


func run() -> void:
	var by: Dictionary = {}
	var total := 0
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		for c in m.resolved_cards():
			var card: CardData = c
			var k := card.glyph_kind()
			if not by.has(k):
				by[k] = []
			# Names rather than a count, because the useful question when a glyph
			# is crowded is WHICH cards fell into it.
			var names: Array = by[k]
			if not names.has(card.name):
				names.append(card.name)
			total += 1

	var keys: Array = by.keys()
	keys.sort_custom(func(a, b) -> bool: return by[a].size() > by[b].size())

	print("\nGlyphs — %d cards across %d modules\n" % [total, DB.modules.size()])
	var worst := 0.0
	for k in keys:
		var names: Array = by[k]
		var share := float(names.size()) / float(maxi(1, _unique(by)))
		worst = maxf(worst, share)
		print("%-12s %3d  %s" % [String(k), names.size(),
			", ".join(PackedStringArray(names.slice(0, 6)))
			+ ("..." if names.size() > 6 else "")])

	# A kind nothing draws is a dead rung: the fields moved, or it awaits a missing card.
	print("")
	for k in ["slug", "burst", "pyre", "charge", "drone", "brace", "block",
			"feedback", "slip", "vent", "repair", "lock", "draw", "power",
			"scrip", "malfunction", "utility"]:
		if not by.has(StringName(k)):
			print("  unused  %s — nothing in the catalogue draws it" % k)

	print("")
	print("busiest glyph is %.0f%% of the distinct cards (ceiling %.0f%%)" % [
		worst * 100.0, CROWDED * 100.0])
	print("glyphs: %s" % ("PASS" if worst <= CROWDED else "CROWDED"))


func _unique(by: Dictionary) -> int:
	var n := 0
	for k in by:
		n += (by[k] as Array).size()
	return n
