class_name ModuleData
extends HoldItem

enum Slot { WEAPON, SYSTEM, UTILITY }
## A ladder of provenance as much as power: Exotic and Artifact leave the manufacturers.
## Contraband sourcing is a ruling not yet built; it belongs in LootGen's pool filter.
## Why: docs/why/ModuleData.md#grade-ladder
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, EXOTIC, ARTIFACT,
	CONTRABAND }

@export var id: StringName = &""
@export var manufacturer: StringName = &""   ## empty = unbranded (relic/organic)
@export var slot: Slot = Slot.WEAPON
@export var rarity: Rarity = Rarity.COMMON
@export_multiline var flavour: String = ""
@export var cards: Array[CardData] = []

## Added to the hull's baseline, so an Auspex or Ghost Drive needs no do-nothing module.
@export var sensors: int = 0
@export var stealth: int = 0

## Module stats feed the ship's gauges: armour plates once left `max_hp()` unchanged.
## Same field names as HullData. `fuel_factor` is signed and drives thrust and jump price.
## Why: docs/why/ModuleData.md#passive-gauges
@export_group("Passive")
@export var max_hull: int = 0
@export var heat_cap: int = 0
@export var dissipation: int = 0
@export var dodge: float = 0.0
@export var initiative: int = 0
@export var fuel_factor: float = 0.0

## Separate from `fuel_factor`: a thriftier part must not make the pilot worse at thrust checks.
## Why: docs/why/ModuleData.md#thrust
@export var thrust: int = 0

## Levels, not cells, so the part's number is the number on the bar. Self-limiting by capacity.
## Why: docs/why/ModuleData.md#reactor
@export var reactor: int = 0
@export_group("")

## Issued with a ship, never found: kept out of loot so they do not crowd out branded parts.
## Why: docs/why/ModuleData.md#starter-parts
@export var starter_only: bool = false

## Stored, not derived from array order, so a mount is a place you choose. Saved runtime state.
## Why: docs/why/ModuleData.md#mounts
@export var mount: int = -1

## Hold cells are separate from hardpoints, or cell counts leak into set bonuses and the sim.
## Not keyed to rarity, so packing is a physical budget, not a second power budget.
## Why: docs/why/ModuleData.md#hold-size

## A flag, not a rewrite of `size`, so a hull swap repack does not grind shapes.
## Why: docs/why/ModuleData.md#hold-turning

## Mirrored on the hull is drawing only, unrelated to `turned`; the sim never reads it.
## Why: docs/why/ModuleData.md#hull-mirroring
@export var flipped: bool = false

## Runtime state like `mount`, so a part returns where you left it, not re-packed.
## Why: docs/why/ModuleData.md#hold-position

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

## Computed, not baked into fields, as a saved module is a fresh template plus affix names.
## Why: docs/why/ModuleData.md#affix-sums
func affix_raw(field: StringName) -> float:
	var total := 0.0
	for a in affixes:
		total += (a as AffixData).raw_for(field)
	return total


## Same, rounded, for the fields that are ints. Every PER_PIP unit except dodge
## is a whole number, so this is exact rather than approximate.
func affix_int(field: StringName) -> int:
	return int(round(affix_raw(field)))


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

## Defined once: the seven numbers lived in three files, one a test that kept agreeing.
## Why: docs/why/ModuleData.md#scrap-value
const SCRAP_VALUE := [8, 16, 30, 55, 95, 120, 160]


static func rarity_name(r: Rarity) -> String:
	return ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Exotic", "Artifact",
		"Contraband"][r]

## Exotic is pink and Artifact red, the hues nothing else on the ladder uses.
## Common neutral grey, Epic a deeper violet, Contraband black: each fixes a measured collision.
## Why: docs/why/ModuleData.md#rarity-colours
static func rarity_colour(r: Rarity) -> Color:
	return [
		Color("#98a0a8"), Color("#4fbf82"), Color("#6a9ad4"), Color("#8b4fd4"),
		Color("#d99b29"), Color("#e05fa8"), Color("#e0402e"), Color("#05070a"),
	][r]

## Ink differs from the ground only where black on black cannot be read; contraband is bone.
## Why: docs/why/ModuleData.md#rarity-ink
static func rarity_ink(r: Rarity) -> Color:
	return Color("#b9b3a6") if r == Rarity.CONTRABAND else rarity_colour(r)

## Fixed by class, never rarity, so a rarer module never makes a larger deck by construction.
## Two for all but Verity, which keeps its thin deck as a ruling.
## Why: docs/why/ModuleData.md#grant-count-law
func grant_count() -> int:
	var base := 2
	if manufacturer == &"verity":
		base = maxi(1, base - 1)
	for a in affixes:
		base += a.grant_delta
	return maxi(1, base)

## Cell count decides card grades: 1-2 cells give one at grade and one below, 3-4 give two.
## Why: docs/why/ModuleData.md#card-rarity-law
func card_rarities() -> Array[int]:
	var top := int(rarity)
	var second := top if cells() >= 3 else maxi(0, top - 1)
	return [top, second]

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
		# Before the affixes, or the picture would describe the roll instead of the part.
		c.base_glyph = c.glyph_kind()
		c.source_module = name
		c.source_id = id
		# Shared cards stay common and unbranded; only `source_module` points back at the part.
		# Why: docs/why/ModuleData.md#shared-card-identity
		if not c.shared:
			c.manufacturer = manufacturer
			c.source_rarity = int(rarity)
		# The law fills in whatever the card did not declare. Authoring a rarity
		# is for the exceptions; the shape of the part decides the rest.
		if c.rarity < 0:
			var law := card_rarities()
			c.rarity = law[mini(i, law.size() - 1)]
		out.append(c)
	return out
