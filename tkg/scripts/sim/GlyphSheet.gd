extends RefCounted

## Which picture every card in the game draws:
##   godot --headless --path . -- glyphs
##
## The card gallery shows one manufacturer at a time and the glyph problem is a
## DISTRIBUTION problem — "they all look the same" is a claim about the whole set
## that cannot be checked by looking at eight cards from one manufacturer. This
## counts every card, prints the split, and names the cards behind each picture
## so a glyph that has quietly become a catch-all is obvious in one screen.
##
## It caught the thing it was written for: under the old five-kind scheme
## `attack` drew 40% of the card set and `defend` another 20%, so three cards in
## five were one of two pictures.

## No picture may be more than this share of the set.
##
## Not a law of nature — a smoke alarm. A glyph over a third means the ladder in
## `CardData.glyph_kind()` has a rung that is catching everything below it, which
## is exactly how the old scheme got to where it was.
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

	# Every kind the ladder can return should be reachable. One that nothing
	# draws is a rung that is dead — either the fields moved under it or it was
	# written for a card that does not exist yet, and both are worth knowing.
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
