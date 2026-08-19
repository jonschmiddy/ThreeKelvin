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

## Contribution to the ship's Sensors and Stealth attributes, added to the
## hull's baseline. Most modules are 0 — these exist so that an Auspex Array
## makes you see and a Ghost Drive makes you unseen, rather than requiring a
## parallel catalog of modules that do nothing in combat.
@export var sensors: int = 0
@export var stealth: int = 0

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

## THE GRANT COUNT LAW.
##
## How many cards this module puts in the deck. Fixed by module CLASS, never by
## rarity — a legendary drop must not make the deck clumsier, because "declining
## the reward" arithmetic has no place in a loot game. Rarity buys better verbs
## and bigger magnitudes; it never buys more cards.
##
## Making the count a function of class rather than a per-module number means
## the invariant "a rarer module never produces a larger deck than its common
## sibling" is true BY CONSTRUCTION. There is no review step to forget.
##
## Manufacturer is allowed to vary it, because that is build identity with a
## number behind it: Halcyon grants fewer, better cards — the thin perfect deck
## the house is named for, made mechanical instead of flavourful.
## The class table. card-design names two classes — "primary weapons: 2,
## utilities: 1" — and this game has three slots, so SYSTEM is a reading rather
## than a quotation. It grants 2, because a system is the primary DEFENSIVE
## module the way a weapon is the primary offensive one; utilities are the
## situational third. Measured: at 1 it halved every ship's defensive card
## volume and average kills per run fell from 5.2 to 3.3.
func grant_count() -> int:
	var base := 1 if slot == Slot.UTILITY else 2
	if manufacturer == &"halcyon":
		base = maxi(1, base - 1)
	for a in affixes:
		base += a.grant_delta
	return maxi(1, base)

## Cards with affixes baked in, ready for the deck.
##
## Exactly grant_count() of them, drawn from the authored list and cycling if
## the module authors fewer distinct verbs than it grants. `copies` on a card is
## now a WEIGHT within that draw rather than a count of its own — the number of
## cards is the class's business, not the card's.
func resolved_cards() -> Array[CardData]:
	var out: Array[CardData] = []
	if cards.is_empty():
		return out
	var pool: Array[CardData] = []
	for base in cards:
		for i in maxi(1, base.copies):
			pool.append(base)
	for i in grant_count():
		var c: CardData = pool[i % pool.size()].duplicate(true)
		c.copies = 1
		for a in affixes:
			a.apply_to(c)
		c.source_module = name
		c.source_id = id
		c.manufacturer = manufacturer
		c.source_rarity = int(rarity)
		out.append(c)
	return out
