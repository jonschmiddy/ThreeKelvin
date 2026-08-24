class_name CardData
extends Resource

## A single card contributed to the deck by a module (or the hull itself).
## Effects are declarative: CardResolver reads these fields, so new cards
## are data, not code.

@export var name: String = ""
@export var energy: int = 1
@export var heat: int = 0
@export var copies: int = 1
## The verb-pool key this card was drawn from — "ballistics", "ordnance",
## "drone". Printed on the type line, because set-bonus play needs the lane
## scannable and because it is the key that decides WHICH verbs a module of this
## family can grant. Empty on hull-innate cards and on junk.
@export var lane: StringName = &""

@export_group("Attack")
@export var damage: int = 0
@export var hits: int = 1
@export var salvo: int = 0              ## bonus per hit if not your first attack this turn
@export var charge_turns: int = 0       ## fires automatically after N turns
@export var heat_scale: int = 0         ## +1 damage per N current heat
@export var damage_equals_heat: bool = false
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
## +1 hull healed for every N hull you are MISSING. Zero for a flat repair.
##
## THE LIFELINE DIAL, and the reason it exists rather than a bigger flat number.
##
## A flat heal is priced for the turn you play it on, which means it is priced
## for a healthy turn — and the turn that actually needs it is three hull and one
## energy, where a card that costs two is not a card at all. Raising the flat
## number instead fixes that turn by also handing free value to every turn that
## did not need it, which is how a repair card becomes a power creep card.
##
## Scaling on what is MISSING solves both ends at once. At full hull these cards
## are nearly dead weight, so nothing is inflated. At three hull they are the
## biggest thing in the deck. The card is worth exactly as much as the trouble
## you are in, which is what a lifeline is.
##
## It also sharpens the greed clock rather than blunting it, and that ordering
## matters: `design-doc.md`'s third pillar says deaths are self-authored — you
## went one jump too far. An out does not remove that. It means you go one jump
## FURTHER because you have one, and then die there. A player who never had the
## option was stopped by arithmetic; a player who spent it and pushed anyway
## authored the death, which is the pillar working rather than bending.
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

## Junk you are still holding when the turn ends.
##
## AT THE END OF THE TURN, not when it is drawn. A card that hurt you on the
## draw is a tax you cannot see coming and cannot answer — it has happened by
## the time you know about it. Charged at the end, the same card is a QUESTION:
## you are holding something that will cost you, you have a turn to find a way
## to throw it away, and the discard verbs below are the answer. Same numbers,
## and the difference between a punishment and a decision.
##
## Every unplayed card is discarded at end of turn anyway, so "still in hand"
## means every malfunction you drew and could not get rid of.
## CORRODE and SMOULDER, as they read on a card.
@export var hand_damage: int = 0
@export var hand_heat: int = 0

## FUSED. Not discarded at the end of your turn — it stays in your hand until
## you get rid of it, and discarding works, it just costs you a card.
##
## The only malfunction keyword that COMPOUNDS. Everything else charges you once
## and goes with the hand; a fused card charges you again every turn you leave
## it there, and it is holding a hand slot the whole time.
@export var fused: bool = false

## GETTING RID OF THINGS. Two verbs, because they are two different sizes of
## decision.
##
## DISCARD is the ordinary one: you pick, it goes to the discard pile, and it is
## back in the deck the moment that pile reshuffles. `discard_hand` is the same
## verb at the scale of a whole hand and pairs with `draw` — a real cost,
## because it throws away what you wanted too.
##
## DECOMMISSION is the expensive one: the card is off the books for the rest of
## the fight. Against junk that is the whole difference, because a discarded
## malfunction comes back and a decommissioned one does not. The word is the
## setting's own register — this is a universe of filings, riders and invoices,
## and a part struck off the register is exactly what has happened.
##
## `self_decommission` is a card that takes ITSELF off the books when played,
## which is how a card earns the right to be much stronger than its cost.
@export var discard: int = 0
@export var discard_hand: bool = false
@export var decommission: int = 0
@export var self_decommission: bool = false

## What KIND of card this is, derived rather than authored.
##
## Type is carried by structure on the card face — a charge pip track, a
## persists tag, a negative heat pip — never by colour, which belongs to the
## manufacturer. Deriving it means a card cannot be drawn as one type and
## resolve as another: the pips appear because charge_turns is set, and
## charge_turns is what CardResolver reads.
## Three types, not six.
##
## Attack, Skill, Malfunction. The earlier roster split Defend, Charge, Drone
## and Utility into types of their own, which confused two different questions:
## what a card IS in the rules, and what it happens to do. Charge is not a type
## — a charged slug is an ATTACK that banks a turn first. A drone that deals
## damage is an attack; one that only screens is a skill.
##
## Nothing is lost by collapsing them, because the behaviours never lived on
## the type line anyway. They live in STRUCTURE — the charge pip track, the
## negative heat pip, the art silhouette — and structure is where a player reads
## them at 96px. See glyph_kind(), which still tells all six apart.
func type_name() -> String:
	if unplayable:
		return "Malfunction"
	if damage > 0 or damage_equals_heat or heat_scale > 0 or drone_damage > 0:
		return "Attack"
	return "Skill"

## What the art window draws. Finer than the type, on purpose: the type line
## answers "how do the rules treat this", the silhouette answers "what does it
## do", and those are different questions with different right answers.
## What the art window draws.
##
## THE VERB, NOT THE TYPE, and it used to be the type. There were five kinds —
## attack, defend, charge, drone, utility — and the type line prints the same
## answer one row below the picture, so the largest element on the card was also
## the most redundant thing on it. Suppressing Fire, Full Auto, Ripple Fire,
## Drumfire and Siege Round drew one identical round; Brace, Bulwark, Sink Plate,
## Dig In and Bulkhead drew one identical plate. A hand of eight was two pictures.
##
## So this answers "what does playing it DO" instead, which is the question a
## player is actually asking when they look at a card they cannot yet read.
##
## PRIORITY IS THE HEADLINE, and it is why this is a ladder rather than a set of
## flags. Dig In braces, blocks AND vents; the picture has to pick one, and the
## one it picks is the thing you played the card for. Defence outranks the vent
## that came with it, an attack outranks the draw stapled to it, and the two
## kinds that change how a card is USED rather than what it does — a charge that
## fires later, a drone that fires without you — outrank everything, because
## getting those wrong costs you a turn.
##
## Shape, never colour. Colour is the manufacturer channel and the two must never
## share an encoding, so every one of these reads for a colourblind player.
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
	if damage_equals_heat or heat_scale > 0:
		return &"pyre"
	# THE SPLIT THAT DOES THE MOST WORK. "Deal 2 x 5" and "Deal 40" are the same
	# picture under the old scheme and are not remotely the same card.
	if damage > 0:
		return &"burst" if hits > 1 else &"slug"
	# Defence, finest first. Brace is a wall you keep, Block is one that falls
	# down at the end of the turn, and Feedback is one that bites back — three
	# different plans, and the old glyph called them one plate.
	if feedback > 0:
		return &"feedback"
	if negate_next:
		return &"slip"
	# THE BIGGER NUMBER WINS when a card does both. Dig In braces 2 and blocks
	# 8, and calling that a Brace card because Brace is checked first would draw
	# a picture of the smaller half. A ladder is right for kinds that cannot be
	# compared; these two are the same kind of thing in different amounts.
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

## What the heat pip prints: what playing this leaves behind, net of what it
## takes away. A vent card is not a second corner — it is the same corner
## running backwards, which is how the card teaches that heat is bidirectional.
func net_heat() -> int:
	return heat - vent

## What this card's picture was before any affix touched it.
##
## Affixes MUTATE THESE FIELDS — `ModuleData.resolved_cards()` calls
## `AffixData.apply_to()` on a duplicate — so a rolled part can hand a card
## properties its designer never gave it. Grafted adds `heal`, Salvaged adds
## `credit_gain`, Autoloader adds `draw`, Overbored adds `damage`.
##
## Read straight, the ladder in glyph_kind() then draws the AFFIX rather than the
## card: a Lock On that happens to roll Grafted stops being a reticle and becomes
## a weld, and a Brace Frame that rolls Overbored draws a round. The picture is
## supposed to say what the card is for, and +2 damage on a plate is not what the
## plate is for.
##
## So the answer is decided once, on the base card, before any affix is applied,
## and the affixes are left to do their talking in the rules text where the
## numbers actually are. Empty on a card nothing has resolved — the gallery and
## the tests build cards directly — and glyph_kind() falls through to computing
## it, which is the same answer for an unaffixed card.
var base_glyph: StringName = &""

## WHICH ILLUSTRATION this card shows, without the folder or the extension.
##
## Empty is the ordinary case: `art_key()` then slugs the card's own name, so a
## card called "Scored Barrel" looks for `scored_barrel.png` and no entry has to
## be written for it. Seventy-six cards times one bookkeeping line each is the
## kind of edit that goes wrong quietly, and the name is already the identity a
## player uses.
##
## Set it when the file cannot follow the name: two cards that should share one
## picture, or a card whose name changes and whose art should not be orphaned by
## the rename.
@export var art: StringName = &""

## The file this card's illustration lives under, name-derived unless overridden.
##
## Lowercased, spaces and punctuation to underscores, runs collapsed. Written
## once here rather than at each call site, because a slug rule that exists in
## two places is a slug rule that disagrees with itself the first time a card is
## named with a hyphen.
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

## THE RESOLVED ILLUSTRATION, looked up ONCE when the catalogue is built.
##
## NEVER LOAD THIS FROM INSIDE `_draw`. That is not a style preference, it is
## the bug this field exists to prevent: `load()` called during a draw pass
## hands back a resource whose CPU image is perfectly correct and whose GPU
## texture is not yet bound, so the card paints a SOLID WHITE RECTANGLE of
## exactly the right size. Every probe says the texture is fine, because it is
## -- it simply is not on the card when the draw command is recorded.
##
## `ModuleData.sprite` was right by accident on both counts: Database assigns it
## while building the catalogue, which is nowhere near a frame, and it is
## EXPORTED.
##
## Exported matters here as much as the timing. A card is `duplicate()`d on its
## way into a deck, and Resource.duplicate copies exported properties and drops
## everything else -- so a plain `var` holding the picture survives the
## catalogue and is null on every card a player actually holds. The failure is
## quiet and looks exactly like "the art did not load".
@export var sprite: Texture2D

## Runtime-only, set by DeckBuilder
var source_module: String = ""
## The granting module's id. source_module is its NAME, which is for printing;
## this is for looking the module back up. Without it the readout had to be
## handed a module alongside every card — which worked in the gallery, where the
## screen builds both, and not in combat, where a hand is only cards.
var source_id: StringName = &""
var manufacturer: StringName = &""
## Rarity of the module that granted this, for the footer's rarity tick.
var source_rarity: int = 0

## THIS CARD'S OWN rarity, as a ModuleData.Rarity. -1 means "the module decides",
## which is what almost every card wants — see ModuleData.card_rarities for the
## law that fills it in.
##
## Separate from `source_rarity`, which is the rarity of the PART it came off. A
## legendary bay grants a legendary card and a common one; both have the same
## source and only one of them is legendary.
@export var rarity: int = -1

## The rules words on this card, each with what it actually does.
##
## Lives here, beside the fields it explains, because these two go stale
## together or not at all: a keyword whose definition sits in a UI file drifts
## from the mechanic the first time somebody tunes the mechanic. Every entry
## below was written against Combat.gd rather than from memory — brace really
## is charged a heat per turn, feedback really does fire once per attacking
## enemy — and if that changes, this is the file already open.
##
## Only the words that need explaining. "Deal 6" explains itself; Salvo does
## not.
func keywords() -> Array:
	var out: Array = []
	if block > 0:
		out.append(["Block", "Mitigates damage before your brace does. Gone at the end of the enemy's turn."])
	if brace > 0 or brace_from_heat:
		# BRACE, not "brace". Brace is the resource; Brace is the word the game
		# actually says — it is what the card text prints and what Probate's set
		# bonus calls this whole class of card. A glossary that explains a term
		# appearing nowhere on the card is a glossary for a different game.
		out.append(["Brace", "Mitigates damage. Stays up between turns, and costs 1 heat a turn to hold."])
	if brace_from_heat:
		out.append(["Brace from heat", "You brace for however much heat you are carrying."])
	if feedback > 0:
		out.append(["Feedback", "Deals this straight back to any enemy that attacks you."])
	if negate_next:
		out.append(["Negate", "Cancels the next attack against you outright, whatever its size."])
	if salvo > 0:
		out.append(["Salvo", "Adds this to every hit — but only if you have already attacked this turn."])
	if charge_turns > 0:
		out.append(["Charge", "Fires on its own after this many turns instead of when you play it."])
	if adapt > 0:
		out.append(["Grows", "Gains this permanently every time you play it, for the rest of the fight."])
	if heat_scale > 0:
		out.append(["Heat scaling", "One more damage for every %d heat you are carrying." % heat_scale])
	if heal_scale > 0:
		out.append(["Emergency repair",
			"One more hull for every %d you are missing." % heal_scale])
	if damage_equals_heat:
		out.append(["Damage from heat", "Hits for exactly however much heat you are carrying."])
	if lock_on > 0:
		out.append(["Lock on", "Your next attack this turn deals this much more."])
	if vent > 0 or vent_all:
		out.append(["Vent", "Sheds heat. The one corner on a card that runs backwards."])
	if drone_damage > 0 or drone_brace > 0:
		out.append(["Drone", "Keeps fighting after the card is gone. It stays out until the fight ends."])
	if fused:
		out.append(["Fused", "It is not discarded at the end of your turn. Discarding it works — it just costs you a card."])
	if hand_damage > 0:
		out.append(["Corrode", "Damage at the end of your turn, for as long as it is still in your hand."])
	if hand_heat > 0:
		out.append(["Smoulder", "Heat at the end of your turn, for as long as it is still in your hand."])
	if decommission > 0 or self_decommission:
		out.append(["Decommission", "Off the books for the rest of this fight. It does not come back when the deck reshuffles."])
	if discard > 0 or discard_hand:
		out.append(["Discard", "Straight to the discard pile — and back in the deck when that pile reshuffles."])
	if evoke > 0:
		out.append(["Evoke", "Adds this much for each drone you have out."])
	if credit_cost > 0:
		out.append(["Credit cost", "Paid from the same balance you repair and refit with."])
	if unplayable:
		# One word, one entry. "Unplayable" was never true anyway — you can play
		# this, it simply does nothing except leave — and with the card printing
		# nothing but PURGE, that it does nothing else is the obvious reading
		# rather than a second thing to be told.
		out.append(["Purge", "Removes this card from combat. Returns next combat."])
	return out

## The same line, with every explainable word marked up.
##
## Derived from describe() rather than written beside it: two strings that must
## say the same thing are one string with a transform. The terms come from
## keywords(), so a word is highlighted if and only if this card can explain it
## — there is no list to keep in step, and a keyword that stops applying stops
## being underlined on the same edit.
##
## Longest first. "Brace from heat" contains "Brace", and replacing the short
## one first would leave markup inside the long one.
func describe_rich() -> String:
	var terms: Array = []
	for raw in keywords():
		terms.append(String((raw as Array)[0]))
	terms.sort_custom(func(x: String, y: String) -> bool: return x.length() > y.length())
	var out := describe()
	for t in terms:
		out = out.replace(t, "[u][color=#c3d2e2]%s[/color][/u]" % t)
	return out

## Short human-readable effect line for the card face.
func describe() -> String:
	var bits: PackedStringArray = []
	if damage > 0:
		bits.append("Deal %d%s" % [damage, "" if hits <= 1 else " × %d" % hits])
	if damage_equals_heat:
		bits.append("Damage from heat")
	if heat_scale > 0:
		bits.append("Heat scaling per %d" % heat_scale)
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
		# A WORD PLUS ITS FLOOR, which is the pattern Brace and Salvo already use:
		# the number on the face is what the card is guaranteed to do and the RULE
		# lives in the keyword, where there is room to say it properly.
		#
		# It also has to be spelled this way to work at all. describe_rich() marks
		# up only the terms this card's own keywords() can explain, by literal
		# string match — so a face reading "Heal 2 +1 per 4 missing" contains no
		# keyword, gets no underline, and the rule explaining the whole card is
		# unreachable from the card. The phrase on the face and the key in
		# keywords() are one string or the feature does not exist.
		#
		# Never the number it happens to be worth right now. A printed value that
		# changes as you take damage is a card you cannot plan around before you
		# take it.
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
	if self_decommission:
		bits.append("Decommissions itself")
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
	# "Attack drone" and "Screen drone", not "Launch drone" and "Wasp screen".
	# A keyword is a RULE and has to be house-neutral: "Wasp screen" is Cygnet's
	# own flavour standing in for a mechanic any house could have, and it made
	# the Shield Wasp Cradle's card read "Wasp Screen — Wasp screen 3." Both now
	# point at the one glossary entry that explains them, which is Drone.
	if drone_damage > 0:
		bits.append("Attack drone %d" % drone_damage)
	if drone_brace > 0:
		bits.append("Screen drone %d" % drone_brace)
	if evoke > 0:
		bits.append("Evoke %d per drone" % evoke)
	if unplayable:
		# Just the verb. The cost gem already says what it costs — corner
		# grammar is the card's only job — and the type line already says
		# MALFUNCTION, so "unplayable" was a third statement of a thing the
		# card had twice said. What is left is the one word that is news.
		bits.append("Purge")
	return ". ".join(bits) + "."
