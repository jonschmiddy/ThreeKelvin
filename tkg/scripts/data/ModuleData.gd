class_name ModuleData
extends Resource

enum Slot { WEAPON, SYSTEM, UTILITY }
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, EXOTIC, ARTIFACT }

@export var id: StringName = &""
@export var name: String = ""
@export var manufacturer: StringName = &""   ## empty = unbranded (relic/organic)
@export var slot: Slot = Slot.WEAPON
@export var rarity: Rarity = Rarity.COMMON
@export_multiline var flavour: String = ""
@export var cards: Array[CardData] = []

## Rolled at generation time
@export var affixes: Array[AffixData] = []
@export var scrap_value: int = 8

@export_group("Art")
## Transparent, trimmed to bounding box, same 3/4 angle and light direction as hulls.
@export var sprite: Texture2D
## Offset applied to the sprite when placed on its hardpoint anchor.
@export var mount_offset: Vector2 = Vector2.ZERO
## Illustration used on the cards this module contributes (one per module, not per card).
@export var card_art: Texture2D

var contraband: bool:
	get:
		for a in affixes:
			if a.contraband:
				return true
		return false

static func slot_name(s: Slot) -> String:
	match s:
		Slot.WEAPON: return "weapon"
		Slot.SYSTEM: return "system"
		_: return "utility"

static func rarity_name(r: Rarity) -> String:
	return ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Exotic", "Artifact"][r]

static func rarity_colour(r: Rarity) -> Color:
	return [
		Color("#8fa3ba"), Color("#7fb89a"), Color("#6a9ad4"), Color("#a97fd4"),
		Color("#d99b29"), Color("#4fbfa8"), Color("#d4614f"),
	][r]

## Cards with affixes baked in, ready for the deck.
func resolved_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	for base in cards:
		for i in maxi(1, base.copies):
			var c: CardData = base.duplicate(true)
			c.copies = 1
			for a in affixes:
				a.apply_to(c)
			c.source_module = name
			c.manufacturer = manufacturer
			out.append(c)
	return out
