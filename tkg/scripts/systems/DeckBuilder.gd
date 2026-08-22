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

	# One card per malfunction actually lodged, built from the table. This used
	# to synthesise a Dross inline, which is why there was exactly one kind of
	# junk in the game no matter what put it there.
	for id in Run.dross:
		out.append(DB.malfunction(id))

	return out

## Preview for the ship screen: what the deck currently looks like.
static func summarise() -> Dictionary:
	var cards := build()
	var by_cost := {}
	var total_damage := 0
	var total_heat := 0
	for c in cards:
		by_cost[c.energy] = int(by_cost.get(c.energy, 0)) + 1
		total_damage += c.damage * maxi(1, c.hits)
		total_heat += c.heat
	return {
		size = cards.size(),
		by_cost = by_cost,
		total_damage = total_damage,
		total_heat = total_heat,
	}
