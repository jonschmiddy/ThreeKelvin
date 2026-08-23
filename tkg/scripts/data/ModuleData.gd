class_name ModuleData
extends Resource

enum Slot { WEAPON, SYSTEM, UTILITY }
## THE GRADE LADDER, and it is a ladder of PROVENANCE as much as of power.
##
## Common through Legendary is one house doing its job better. Exotic and
## Artifact leave the houses entirely — grown and precursor, which is why
## LootGen gates both behind `allow_unbranded`.
##
## CONTRABAND is the eighth and the only one that is a fact about WHO, not
## about what: a part nobody will admit to selling. RULING, NOT YET BUILT —
## contraband comes only from the Probate Combine, Redline and Cygnet, the
## scrappers, the hackers and the technologists, because those are the three
## houses with a reason to move something off the manifest. Recorded here
## rather than in a note because the enum is what a future module will pick
## from; the sourcing belongs in LootGen's pool filter beside the
## `allow_unbranded` gate, which currently swallows CONTRABAND along with
## EXOTIC and ARTIFACT and will need saying differently when the parts exist.
enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, EXOTIC, ARTIFACT,
	CONTRABAND }

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

## What this part adds to the SHIP'S GAUGES — not to a display number.
##
## These were missing, and the gap was invisible because the two above are not.
## Sensors and Stealth had no gauge anywhere in the game, so they were summed
## across `installed` from the day they existed. The other four attributes are
## derived from hp, heat and dodge — gauges that predate modules having any
## passive stat at all — so `RunState.max_hp()` returned `hull.max_hull` and
## stopped there. A ship with three armour plates bolted on had exactly the hull
## of a ship with none, on the ship tab AND in every fight.
##
## Deliberately the same field names as HullData, because the sum is literally
## `hull.x + Σ module.x` and two vocabularies for one quantity is how the two
## halves drift apart.
##
## `fuel_factor` is signed and does DOUBLE DUTY: it drives Thrust upward and the
## price of a jump upward with it, which is the trade a bigger engine is. No
## module in the catalog carries a value for it today — see _seed_module_passives.
@export_group("Passive")
@export var max_hull: int = 0
@export var heat_cap: int = 0
@export var dissipation: int = 0
@export var dodge: float = 0.0
@export var initiative: int = 0
@export var fuel_factor: float = 0.0

## How far this part raises the ship's REACTOR, in levels.
##
## LEVELS AND NOT CELLS, since the reactor turned round. A coupling used to
## grant six cells and the gauge worked out what that was worth; now it grants
## two levels and RunState.REACTOR_TABLE says what those are worth — six cells
## and, at some steps, a point of energy. The part's number and the number on
## the bar are the same number.
##
## SELF-LIMITING BY CONSTRUCTION, which is why it is safe on a module at all: a
## part that grants capacity also OCCUPIES capacity, so a 2x2 armature granting
## six cells leaves two. The ceiling is how many mounts the frame has.
@export var reactor: int = 0
@export_group("")

## Issued with a ship, never found on one.
##
## The generic kit every chassis launches with. Kept out of the loot pool
## deliberately: they exist so the deck has a floor, and a floor that keeps
## turning up in wrecks would crowd out the branded parts you are flying around
## to collect. You start with them and you replace them.
@export var starter_only: bool = false

## WHICH hardpoint this is bolted to, within its slot type. -1 when in the hold.
##
## ShipView has always drawn the fitted modules at fixed places on the hull —
## weapon 0 is the dorsal ordnance, 1 the ventral barrels, 2 the aft mount — but
## it read that index from the ORDER of the installed array, so the positions
## were an accident of how you happened to fit things and shuffled when you
## removed something. Storing it makes a mount a place you choose: leave the
## dorsal empty and hang everything off the spine if that is the ship you want.
##
## Runtime state, not content. Every template in DB carries -1; the value only
## means anything on the duplicate actually bolted to a hull, and SaveGame
## carries it so a reloaded ship looks like the one you built.
@export var mount: int = -1

## How much room the part takes UP IN THE HOLD, in grid cells. Never on the ship.
##
## The hold is a grid you pack; a hardpoint still takes exactly one module
## however big it is. Those are two different questions — "will this fit in the
## truck" and "does this ship have a mount for it" — and tying them together
## would put cell counts into `slots_used()`, set-bonus counting, `Policy` and
## `HeadlessSim`, none of which are asking about volume.
##
## Four shapes, and the shape is a description rather than a rating:
##
##   1x1  a fitting        sights, a patch kit, a coolant line
##   1x2  a compact unit   most systems, a short weapon
##   1x3  something LONG   a barrel, a lance, a rail
##   2x2  something BULKY  a bay, an array, heavy plating, a reactor
##
## So a hold full of long things is visibly a hold full of guns, before any word
## is read. Deliberately NOT keyed to rarity: a Legendary sight is still a sight,
## and making the good ones big would turn packing into a second power budget
## rather than a physical one.
@export var size: Vector2i = Vector2i.ONE

## Turned on its side in the hold. A 1x3 lance laid flat is a 3x1.
##
## Kept as a FLAG rather than by rewriting `size`, so the part's authored shape
## survives being turned and turned back — and so a hull swap, which repacks the
## whole hold, does not slowly grind every long thing into whatever orientation
## it last happened to fit in.
@export var turned: bool = false

## The shape it actually occupies right now. Everything that asks where a part
## fits asks THIS; `size` is what it was authored as.
func footprint() -> Vector2i:
	var w := maxi(1, size.x)
	var h := maxi(1, size.y)
	return Vector2i(h, w) if turned else Vector2i(w, h)

## Cells consumed. Convenience, and the one place the multiply is written.
## Turning cannot change it, which is why the hold's totals need no rotation.
func cells() -> int:
	return maxi(1, size.x) * maxi(1, size.y)

## WHERE in the hold grid, top-left cell. (-1, -1) while not in the hold.
##
## Runtime state exactly as `mount` is, and stored for the same reason: the hold
## is a place you arrange, so a part has to come back where you left it. Deriving
## it from array order would re-pack the hold every time something was removed,
## which is the behaviour `mount` was changed away from.
@export var hold_at: Vector2i = -Vector2i.ONE

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

## What a part is worth broken down, by rarity.
##
## Lived in three files — Database's seeder, LootGen's roller and MarketTest's
## fixture — all spelling the same seven numbers. That is the same "one price,
## defined once" discipline the rest of the economy is held to by Market.gd, and
## a rarity tuning pass had to be remembered in three places, one of them a test
## that would have gone on agreeing with an old table.
const SCRAP_VALUE := [8, 16, 30, 55, 95, 120, 160]


static func rarity_name(r: Rarity) -> String:
	return ["Common", "Uncommon", "Rare", "Epic", "Legendary", "Exotic", "Artifact",
		"Contraband"][r]

## WHAT A GRADE IS. The ground its plate is painted on, and — for seven of
## the eight — the colour its name is written in as well.
##
## Exotic is PINK and Artifact is RED. Exotic was a teal that sat two steps
## from Rare's blue, so the two rarest branded grades read as cool neighbours
## of the middle of the ladder instead of as the end of it. Pink and red are
## the two hues nothing else on the ladder uses, and they are warm where
## Common through Epic are cold, so the top of the ladder now separates from
## the body of it before any name is read.
##
## COMMON IS NEUTRAL GREY AND UNCOMMON IS A REAL GREEN, and measuring the old
## pair says the same thing the Epic one did. Common was #8fa3ba at 23%
## saturation and Uncommon #7fb89a at 31%: 60 degrees of hue between them and
## it did not matter, because at that saturation and that lightness they were
## two tints of the same pale nothing.
##
## The bigger find was that Common was BLUE — 208 degrees, five degrees off
## Rare's 213 — so the bottom of the ladder was in Rare's own hue family and
## told apart only by being washed out. Making Common a near-neutral grey
## fixes both collisions with one value, and it is what Common should have
## been anyway: the grade that has no colour, because it has no claim.
##
## EPIC IS A DEEPER VIOLET for the same reason one rung lower, and the fix is
## SATURATION rather than hue. It was #a97fd4, and measuring it says why that
## did not work: 270 degrees against Rare's 213, which is a real 57 degrees of
## separation — but at 40% saturation and the same blue channel, so two
## adjacent rungs arrived as one pale cool family and the word underneath was
## doing all the work. #8b4fd4 is the same hue at 63%. The plate is 30 pixels
## across and the name is not on it.
##
## CONTRABAND IS BLACK, and black is darker than the screen it is drawn on.
## That is deliberate and it is the reason `rarity_ink` exists below: a
## contraband plate has no ground you can see, only an edge — the shape of a
## part with nothing filled in, which is what a thing that is not on the
## manifest should look like.
static func rarity_colour(r: Rarity) -> Color:
	return [
		Color("#98a0a8"), Color("#4fbf82"), Color("#6a9ad4"), Color("#8b4fd4"),
		Color("#d99b29"), Color("#e05fa8"), Color("#e0402e"), Color("#05070a"),
	][r]

## WHAT A GRADE IS WRITTEN IN. The same colour, except where the colour
## cannot be written.
##
## Black text on a black background is not a style, it is a card whose name
## you cannot read — and rarity_colour is used as an ink in five places (the
## card's name, three readouts, and the plate's edge) as well as a ground in
## one. Those are two different jobs and they only looked like one job while
## every grade happened to be a mid-tone.
##
## Contraband's ink is BONE, not white: white is the theme's emphasis colour
## and would make the rarest thing in the game read as merely selected.
## Enforced by `-- holdtest`, which will not let an ink onto the void the eye
## cannot separate from it.
static func rarity_ink(r: Rarity) -> Color:
	return Color("#b9b3a6") if r == Rarity.CONTRABAND else rarity_colour(r)

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
## number behind it: Verity grants fewer, better cards — the thin perfect deck
## the house is named for, made mechanical instead of flavourful.
## TWO, FROM EVERY MODULE. It was 2 for weapons and systems and 1 for utilities,
## on the reading that a utility is the situational third slot — and the reading
## was sound but the result was not: a utility was a part you found, packed and
## bolted on for a single card, which made half the catalogue feel like a
## rounding error next to a gun.
##
## Two lets a module be a COMBINATION rather than a verb with a name on it. A
## part can carry its headline card and a plain one beside it, and two parts can
## share a card while each keeping something of their own — which is what makes
## a catalogue of sixty read as more than sixty things.
##
## Measured before and after at seed 4242 over 200 runs; the numbers are in the
## commit that made the change.
##
## VERITY IS THE EXCEPTION AND STILL GRANTS ONE. That is a ruling, not an
## oversight — the house is named for the thin perfect deck and this is the only
## place that claim is mechanical rather than flavour. It does now mean "every
## module grants two" is true of six houses out of seven.
func grant_count() -> int:
	var base := 2
	if manufacturer == &"verity":
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
## THE CARD RARITY LAW. What the two cards a module grants are allowed to be.
##
## Decided by how many CELLS the part occupies, because that is what it costs
## you. A part you can slip into any gap gives one card at its own grade and one
## plainer; a part you gave three or four cells of hold to gives two at grade.
##
##   1-2 cells   one at the module's rarity, one BELOW it
##   3-4 cells   two at the module's rarity
##
## "Below it" and not "one step below": the second card may be anything lower,
## which is what lets the shared commons sit on a legendary 1x1 without a
## special case. A common module has nothing below it, so both of its cards are
## common and the rule collapses to the obvious thing.
##
## Which means a legendary 4x1 does grant two legendary cards — and that is
## fine, because it costs a whole row of a light hull's twelve. The power is
## bought with space rather than handed over. A legendary 1x1 could not be
## allowed the same thing and this is the line that says so.
##
## Like `grant_count`, a function of the part rather than a number typed per
## module, so "a small part never grants two top-grade cards" is true BY
## CONSTRUCTION and there is no review step to forget.
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
		# BEFORE the affixes, and that ordering is the whole point — an affix can
		# add damage, brace, heal, draw or credits, and a picture chosen after
		# they land describes the roll instead of the part. See CardData.base_glyph.
		c.base_glyph = c.glyph_kind()
		for a in affixes:
			a.apply_to(c)
		c.source_module = name
		c.source_id = id
		c.manufacturer = manufacturer
		c.source_rarity = int(rarity)
		# The law fills in whatever the card did not declare. Authoring a rarity
		# is for the exceptions; the shape of the part decides the rest.
		if c.rarity < 0:
			var law := card_rarities()
			c.rarity = law[mini(i, law.size() - 1)]
		out.append(c)
	return out
