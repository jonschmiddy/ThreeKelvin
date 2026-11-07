class_name CardData
extends Resource

## A card a module (or the hull) contributes. Effects are declarative, read by CardResolver.

@export var name: String = ""
@export var energy: int = 1
@export var heat: int = 0
@export var copies: int = 1
## The verb-pool key, printed on the type line so set-bonus play can scan the lane.
@export var lane: StringName = &""

@export_group("Attack")
@export var damage: int = 0
@export var hits: int = 1
@export var salvo: int = 0              ## bonus per hit if not your first attack this turn
@export var charge_turns: int = 0       ## fires automatically after N turns
@export var heat_scale: int = 0         ## +1 damage per N current heat
@export var damage_equals_heat: bool = false
## Heat over the cap is a cost elsewhere; here it is Solari's trigger.
@export var flashpoint: int = 0
@export var adapt: int = 0              ## permanently grows this combat

@export_group("Defence")
@export var brace: int = 0              ## persists between turns, costs heat to hold
@export var block: int = 0              ## decays at end of enemy turn
@export var brace_from_heat: bool = false
@export var feedback: int = 0
@export var negate_next: bool = false

@export_group("Utility")
@export var vent: int = 0
@export var vent_all: bool = false
@export var heal: int = 0
## Scales on hull you are MISSING: a flat heal is priced for a healthy turn.
## An out sharpens the greed clock: you push one jump further, so the death is still self-authored.
## Why: docs/why/CardData.md#heal-scale
@export var heal_scale: int = 0
@export var draw: int = 0
@export var lock_on: int = 0
@export var energy_gain: int = 0
@export var credit_gain: int = 0
@export var credit_cost: int = 0
@export var drone_damage: int = 0
@export var drone_brace: int = 0
@export var evoke: int = 0
@export var unplayable: bool = false

## Charged at end of turn, not on draw: a cost you can answer is a decision, not a punishment.
## Why: docs/why/CardData.md#junk-charging
@export var hand_damage: int = 0
@export var hand_heat: int = 0

## The only malfunction keyword that compounds: it charges again every turn it stays in hand.
## Why: docs/why/CardData.md#fused
@export var fused: bool = false

## Discard returns on reshuffle; decommission removes the card for the fight, which beats junk.
## Why: docs/why/CardData.md#discard-and-decommission
@export var discard: int = 0
@export var discard_hand: bool = false
@export var decommission: int = 0
@export var self_decommission: bool = false

## Derived from structure, so a card cannot be drawn as one type and resolve as another.
## Three types, not six: Charge, Drone and Defend were behaviours, which live in structure.
## Why: docs/why/CardData.md#card-type
func type_name() -> String:
	if unplayable:
		return "Malfunction"
	if damage > 0 or damage_equals_heat or heat_scale > 0 or drone_damage > 0:
		return "Attack"
	return "Skill"

## The picture says what playing it does, not the type, which the type line already prints.
## A priority ladder by headline. Shape, never colour, so it reads for colourblind players.
## Why: docs/why/CardData.md#glyph-kind
func glyph_kind() -> StringName:
	# THE PART, NOT THE ROLL. See base_glyph.
	if base_glyph != &"":
		return base_glyph
	# Sequencing first: these two change WHEN the card acts, and a player who
	# misreads them loses a turn rather than a few points.
	if unplayable:
		return &"malfunction"
	if charge_turns > 0:
		return &"charge"
	if drone_damage > 0 or drone_brace > 0:
		return &"drone"
	# An attack whose number is your heat is a different animal from one with a
	# number printed on it — it is the build asking you to run hot on purpose.
	if damage_equals_heat or heat_scale > 0 or flashpoint > 0:
		return &"pyre"
	# THE SPLIT THAT DOES THE MOST WORK. "Deal 2 x 5" and "Deal 40" are the same
	# picture under the old scheme and are not remotely the same card.
	if damage > 0:
		return &"burst" if hits > 1 else &"slug"
	# Defence, finest first: Brace, Block and Feedback are three plans, not one plate.
	if feedback > 0:
		return &"feedback"
	if negate_next:
		return &"slip"
	# The bigger number wins when a card does both, or Dig In would draw its smaller half.
	if brace_from_heat:
		return &"brace"
	if brace > 0 or block > 0:
		return &"brace" if brace >= block else &"block"
	# Utility, in the order a player would name the card by.
	if vent > 0 or vent_all:
		return &"vent"
	if heal > 0 or heal_scale > 0:
		return &"repair"
	if lock_on > 0:
		return &"lock"
	if draw > 0:
		return &"draw"
	if energy_gain > 0:
		return &"power"
	if credit_gain > 0:
		return &"scrip"
	return &"utility"

## The heat pip prints the net, so a vent card is the same corner running backwards.
func net_heat() -> int:
	return heat - vent

## Kept though its hazard is gone: the glyph is decided once, on the base card.
## Empty on unresolved cards; `glyph_kind()` then computes the same answer.
## Why: docs/why/CardData.md#base-glyph
var base_glyph: StringName = &""

## Empty means `art_key()` slugs the card's name, saving 76 bookkeeping lines that fail quietly.
## Set it when a file cannot follow the name: shared art, or a rename that must not orphan it.
## Why: docs/why/CardData.md#card-art
@export var art: StringName = &""

## Written once here: a slug rule in two places disagrees the first time a name has a hyphen.
## Why: docs/why/CardData.md#card-art
func art_key() -> StringName:
	if art != &"":
		return art
	var out := ""
	var gap := false
	for ch in name.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
			gap = false
		elif not gap and out != "":
			out += "_"
			gap = true
	return StringName(out.rstrip("_"))

## Never load this inside `_draw`: it paints a solid white rectangle, the GPU texture being unbound.
## Exported, as `duplicate()` drops other properties and a plain var is null on held cards.
## Why: docs/why/CardData.md#resolved-sprite
@export var sprite: Texture2D

## Runtime-only, set by DeckBuilder
var source_module: String = ""
## The module's id, for lookups; `source_module` is a name for printing. Combat has only cards.
var source_id: StringName = &""
var manufacturer: StringName = &""

## A shared card must look the same wherever it came from: four Ranges wore two makers.
## The card is common and unbranded; the part it came off is a fact about the part.
## Why: docs/why/CardData.md#shared-cards
@export var shared: bool = false
## Rarity of the module that granted this, for the footer's rarity tick.
var source_rarity: int = 0

## The card's own rarity; -1 means the module decides. Separate from `source_rarity`, the part's.
## Why: docs/why/CardData.md#card-rarity
@export var rarity: int = -1

## Lives beside the fields it explains so they go stale together; checked against Combat.gd.
## Why: docs/why/CardData.md#keyword-glossary
const KW_NEGATE := "Negate"
const KW_GROWS := "Grows"

func keywords() -> Array:
	var out: Array = []
	if block > 0:
		out.append(["Block", "Stops damage before your brace does. Gone at the end of the enemy's turn."])
	if brace > 0 or brace_from_heat:
		# BRACE, not 'brace': it is the word the card prints, and a glossary must match the card.
		out.append(["Brace", "Stops damage. Stays up between turns, and costs 1 heat a turn to hold."])
	if brace_from_heat:
		out.append(["Brace from heat", "You brace for however much heat you are carrying."])
	if feedback > 0:
		out.append(["Feedback", "Deals this straight back to any enemy that attacks you."])
	if negate_next:
		out.append([KW_NEGATE, "Cancels the next attack against you outright, whatever its size."])
	if salvo > 0:
		out.append(["Salvo", "Adds this to every hit, but only if you have already attacked this turn."])
	if charge_turns > 0:
		out.append(["Charge", "Fires on its own after this many turns instead of when you play it."])
	if adapt > 0:
		out.append([KW_GROWS, "Gains this permanently every time you play it, for the rest of the fight."])
	if heat_scale > 0:
		out.append(["Heat scaling", "One more damage for every %d heat you are carrying." % heat_scale])
	if heal_scale > 0:
		out.append(["Emergency repair",
			"One more hull for every %d you are missing." % heal_scale])
	if flashpoint > 0:
		out.append(["Flashpoint", "Deals this much more per hit if your heat is over your capacity when it is played."])
	if damage_equals_heat:
		out.append(["Damage from heat", "Hits for exactly however much heat you are carrying."])
	if lock_on > 0:
		out.append(["Lock on", "Your next attack this turn deals this much more per hit. Lock on from more cards adds up."])
	if vent > 0 or vent_all:
		out.append(["Vent", "Sheds heat. Its heat corner shows a minus number."])
	if drone_damage > 0 or drone_brace > 0:
		out.append(["Drone", "Keeps fighting after the card is gone. It stays out until the fight ends."])
	if fused:
		out.append(["Fused", "It is not discarded at the end of your turn. Discarding it costs you the card that does it."])
	if hand_damage > 0:
		out.append(["Corrode", "Damage at the end of your turn, for as long as it is still in your hand."])
	if hand_heat > 0:
		out.append(["Smoulder", "Heat at the end of your turn, for as long as it is still in your hand."])
	if decommission > 0 or self_decommission:
		out.append(["Decommission", "Removed for the rest of this fight. It does not return when the deck reshuffles."])
	if discard > 0 or discard_hand:
		out.append(["Discard", "Goes to the discard pile, and back into the deck when that pile reshuffles."])
	if evoke > 0:
		out.append(["Evoke", "Adds this much for each drone you have out."])
	if credit_cost > 0:
		out.append(["Credit cost", "Paid from the same balance you repair and refit with."])
	if unplayable:
		# One word, one entry: Purge does nothing but leave, so 'unplayable' was never true.
		out.append(["Purge", "Removes this card from combat. It returns next combat."])
	return out

## Derived from `describe()`, so two strings that must agree are one string with a transform.
## Longest term first, as 'Brace from heat' contains 'Brace'. `live` stops the face double-counting.
## Why: docs/why/CardData.md#rich-description
func describe_rich(live: int = -1,
		hot: PackedStringArray = PackedStringArray()) -> String:
	var terms: Array = []
	for raw in keywords():
		terms.append(String((raw as Array)[0]))
	terms.sort_custom(func(x: String, y: String) -> bool: return x.length() > y.length())
	var out := describe(live)
	for t in terms:
		out = out.replace(t, "[u][color=%s]%s[/color][/u]"
			% ["#7fb89a" if hot.has(t) else "#c3d2e2", t])
	# The value goes green with its keyword, up to the next period, or the number looks still owed.
	for t in hot:
		var tag := "[u][color=#7fb89a]%s[/color][/u] " % t
		var i := out.find(tag)
		if i < 0:
			continue
		var from := i + tag.length()
		var j := out.find(".", from)
		if j < 0:
			j = out.length()
		var val := out.substr(from, j - from)
		out = out.replace(tag + val, tag + "[color=#7fb89a]%s[/color]" % val)
	# Coloured after the keywords, not in `describe`: a silently changed number confuses.
	# Safe in this order, as no keyword is 'Deal' or a digit.
	# Why: docs/why/CardData.md#rich-description
	if live >= 0 and damage > 0 and live != damage:
		var col := "#7fb89a" if live > damage else "#d4614f"
		out = out.replace("Deal %d" % live,
			"Deal [color=%s]%d[/color]" % [col, live])
	return out

## Default -1 prints the card as authored: in a shop you compare cards, not lock-on figures.
## Why: docs/why/CardData.md#describe
func describe(live: int = -1) -> String:
	var bits: PackedStringArray = []
	if damage > 0:
		var n := live if live >= 0 else damage
		bits.append("Deal %d%s" % [n, "" if hits <= 1 else " × %d" % hits])
	if damage_equals_heat:
		bits.append("Damage from heat")
	if heat_scale > 0:
		bits.append("Heat scaling per %d" % heat_scale)
	if flashpoint > 0:
		bits.append("Flashpoint +%d" % flashpoint)
	if charge_turns > 0:
		bits.append("Charge %d" % charge_turns)
	if salvo > 0:
		bits.append("Salvo +%d" % salvo)
	if adapt > 0:
		bits.append("Grows +%d" % adapt)
	if brace > 0:
		bits.append("Brace %d" % brace)
	if brace_from_heat:
		bits.append("Brace from heat")
	if block > 0:
		bits.append("Block %d" % block)
	if feedback > 0:
		bits.append("Feedback %d" % feedback)
	if negate_next:
		bits.append("Negate next attack")
	if vent > 0:
		bits.append("Vent %d" % vent)
	if vent_all:
		bits.append("Vent all")
	if heal > 0 or heal_scale > 0:
		# A word plus its floor, as Brace and Salvo: the face guarantees, the keyword has the rule.
		# The face phrase and the `keywords()` key must be one string, or nothing underlines.
		# Why: docs/why/CardData.md#heal-scale-text
		if heal_scale > 0:
			bits.append("Emergency repair %d" % heal)
		else:
			bits.append("Heal %d" % heal)
	if discard > 0:
		bits.append("Discard %d" % discard)
	if discard_hand:
		bits.append("Discard your hand")
	if decommission > 0:
		bits.append("Decommission %d" % decommission)
	# The bare keyword, no number: this card is what goes (Jon, Oct 15: "change
	# ... decomissions itself to just DECOMISSION"). A number means you choose.
	if self_decommission:
		bits.append("Decommission")
	if fused:
		bits.append("Fused")
	if hand_damage > 0:
		bits.append("Corrode %d" % hand_damage)
	if hand_heat > 0:
		bits.append("Smoulder %d" % hand_heat)
	if draw > 0:
		bits.append("Draw %d" % draw)
	if lock_on > 0:
		bits.append("Lock on +%d" % lock_on)
	if energy_gain > 0:
		bits.append("+%d energy" % energy_gain)
	if credit_gain > 0:
		bits.append("+%d credits" % credit_gain)
	if credit_cost > 0:
		bits.append("Spend %d credits" % credit_cost)
	# 'Attack drone' and 'Screen drone': keywords are maker-neutral; 'Wasp screen' was Cygnet's.
	if drone_damage > 0:
		bits.append("Attack drone %d" % drone_damage)
	if drone_brace > 0:
		bits.append("Screen drone %d" % drone_brace)
	if evoke > 0:
		bits.append("Evoke %d per drone" % evoke)
	if unplayable:
		# Just the verb: the cost gem and type line already say the rest, so the word is the news.
		bits.append("Purge")
	return ". ".join(bits) + "."
