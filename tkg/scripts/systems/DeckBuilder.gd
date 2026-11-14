class_name DeckBuilder
extends RefCounted

## Your deck IS your installed modules. Swap a module, reshape the deck.

static func build() -> Array[CardData]:
	var out: Array[CardData] = []

	# Every chassis contributes basics, regardless of manufacturer.
	for i in 2:
		var snap := CardData.new()
		snap.name = "Snap Shot"
		snap.energy = 1
		snap.damage = 4
		snap.source_module = "chassis"
		out.append(snap)

	for m in Run.installed:
		for c in m.resolved_cards():
			if c.manufacturer == &"verity" and Run.has_set(&"verity", 3):
				c.energy = maxi(0, c.energy - 1)
			out.append(c)

	# One card per lodged malfunction, built from the table, not a single synthesised Dross.
	for id in Run.dross:
		out.append(DB.malfunction(id))

	return out

