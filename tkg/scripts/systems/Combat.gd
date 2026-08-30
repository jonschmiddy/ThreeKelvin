class_name Combat
extends RefCounted

## Turn-based ship combat. Slay the Spire grammar: telegraphed enemy intent,
## energy as the only cost you pay, heat as a printed byproduct.
##
## Key rulings baked in here (learned the hard way in the web prototype):
##  * Charge fires automatically when ready.
##  * Overheat = predictable self-damage, no cliff, no cap on heat.
##  * The deck ONLY reshuffles at the start of your turn. Without this,
##    zero-cost draw cards loop forever once the discard recycles.
##  * Your attacks never miss; enemies have no dodge.

class ChargingCard extends RefCounted:
	var card: CardData
	var turns_left: int

class Drone extends RefCounted:
	var damage: int
	var fresh: bool = true

class EnemyState extends RefCounted:
	var template: EnemyTemplate
	var hp: int
	var max_hp: int
	var brace: int
	var block: int = 0
	var step: int = 0
	var intent: IntentData

	func pick_intent() -> void:
		# A miniboss on the ropes stops fighting and starts leaving. One full
		# player turn of warning — the intent IS the telegraph — and if it acts
		# on it, the fight ends with the enemy gone rather than dead. The
		# threshold check lives here, at the moment the next move is chosen,
		# so burst damage past it mid-turn still kills: the escape can only
		# happen on the enemy's own clock.
		if template.miniboss and hp > 0 \
				and hp <= int(ceil(max_hp * Combat.MINIBOSS_BREAKS_AT)):
			intent = Combat.escape_intent()
			return
		if not template.pool.is_empty():
			var total := 0
			for i in template.pool:
				total += i.weight
			var roll := Rng.fight.randi() % maxi(1, total)
			var acc := 0
			for i in template.pool:
				acc += i.weight
				if roll < acc:
					intent = i
					return
			intent = template.pool[0]
		else:
			intent = template.loop[step % template.loop.size()]
			step += 1

var enemies: Array[EnemyState] = []
## The database ids behind `enemies`, in the same order. See foe_ids().
var _ids: PackedStringArray = PackedStringArray()

## The current target: the first enemy still standing. Most of the game asks
## about "the enemy" and means exactly this. Explicit targeting passes an index.
var enemy: EnemyState:
	get:
		for e in enemies:
			if e.hp > 0:
				return e
		return null if enemies.is_empty() else enemies[enemies.size() - 1]

var deck: Array[CardData] = []
var hand: Array[CardData] = []
var discard: Array[CardData] = []

## Cards out of this fight entirely. Never reshuffled — that is the whole
## difference between decommissioning something and discarding it.
var decommissioned: Array[CardData] = []

## A card has asked you to pick some of your hand. `choosing` is how many are
## still to pick and `choose_kind` is what happens to them. Held on Combat and
## not on the screen because the RULE is combat's: a save, a bot and the
## simulator all have to be able to see that the turn is waiting on something.
var choosing: int = 0
var choose_kind: StringName = &""

var energy: int = 0
var brace: int = 0
var block: int = 0
var lock_on: int = 0
var feedback: int = 0
var adapt_bonus: int = 0
var negate_next: bool = false
var drones: Array[Drone] = []
var drone_brace: int = 0
var charging: Array[ChargingCard] = []

## Which enemy the card being played is aimed at. Set by play(); damage_enemy
## falls back to it so the resolver never has to know about targeting.
var current_target: EnemyState = null
## At most one wave of reinforcements per fight.
var reinforced: bool = false
## Whether winning consumes the system. True for the contact a node was
## generated holding; FALSE for an ambush, which is something that followed you
## to a station rather than the reason the station is there. Without it, killing
## whatever jumped you on the approach would mark the dock resolved and you
## would fly away from a shop you never opened.
var clears_node: bool = true

## The party's copy of the enemy, when more than one ship is in this fight.
## Null in the solo game, in every headless sim, and in a party of one — and
## everything below falls back to the fight the game has always had.
##
## THE ENEMY IS THE ONLY SHARED THING. Your deck, hand, energy, block, brace,
## heat and hull stay exactly where they are, in `Run` and in this object, on
## your own machine. No other player targets them, spends them or reads them, so
## nothing about them has to cross. That asymmetry is why joint combat fits in
## one field here instead of a rewrite of this file.
var shared: SharedFight = null
## Which system the shared fight is at. Kept separately because `shared` is
## replaced wholesale by every push and the signal that carries it names a
## place, not an object.
var shared_at: int = -1
## The serial of the last partner shot this machine has already drawn. See
## SharedFight.last_hit.
var _seen_hit: int = 0
## Ended your turn and waiting on the rest of the party. The only moment in a
## shared fight that blocks — see SharedFight.end_turn().
var waiting: bool = false

var turn: int = 1
var attacks_this_turn: int = 0
var peaceful_turns: int = 0
var new_dross: int = 0

## How deep this fight is. Kept because what an enemy LODGES in you is rolled
## against it — a spore at layer nine should be able to fuse something into the
## rack that one at layer one cannot.
var danger: int = 1

## The malfunctions this fight has actually lodged, in order, one per point of
## `new_dross`. An empty entry means "roll one" — an intent that names its own
## is the whole reason this is a list rather than a count.
var named_dross: Array[StringName] = []
var finished: bool = false
var result: StringName = &""
var summary: String = ""

## Below this fraction of hull a miniboss spools its escape burn. 35%: low
## enough that a fight that goes well ends in a kill, high enough that a
## fight fought timidly ends watching it leave.
const MINIBOSS_BREAKS_AT := 0.35

## The one intent that is not in any template. Built fresh per call because
## intents on templates are duplicated and scaled per fight — a shared
## constant object would be written to by _spawn's scaling pass.
static func escape_intent() -> IntentData:
	var i := IntentData.new()
	i.name = "ESCAPE BURN"
	i.text = "Spooling a blind jump — finish it now or lose it"
	i.telegraph = true
	i.escape = true
	return i

# ------------------------------------------------------------------------- setup

func start(template: EnemyTemplate, danger: int, extras: Array = []) -> void:
	plan(template, danger, extras)
	begin(null)

## Build the fight without starting it.
##
## Split out of start() because a shared fight has to be opened with numbers
## this function produces — the host is told what a frigate is worth rather than
## working it out again, so danger scaling, the boss exemption and the pack
## split stay in `_spawn` where they have always been. Router calls plan(), asks
## the party, then calls begin().
func plan(template: EnemyTemplate, danger: int, extras: Array = []) -> void:
	self.danger = danger
	enemies.clear()
	var share := 1.0 if extras.is_empty() else 0.6
	enemies.append(_spawn(template, danger, share))
	for t in extras:
		enemies.append(_spawn(t as EnemyTemplate, danger, share))
	_ids = PackedStringArray([String(template.id)])
	for t in extras:
		_ids.append(String((t as EnemyTemplate).id))

	deck = DeckBuilder.build()
	Rng.shuffle(Rng.fight, deck)
	hand.clear()
	discard.clear()
	decommissioned.clear()
	choosing = 0
	negate_next = Run.has_set(&"redline", 5)

## Open the first turn. `f` is the party's copy of the enemy, or null for the
## fight the game has always had.
func begin(f: SharedFight) -> void:
	if f != null:
		_attach(f)
	Sig.combat_started.emit(enemies[0].template.name)
	begin_turn()

## What this fight is made of, by database id, in enemy order. What the host is
## told so a ship arriving mid-fight can build the same hulls.
func foe_ids() -> PackedStringArray:
	return _ids

func foe_hp() -> PackedInt32Array:
	var out := PackedInt32Array()
	for e in enemies:
		out.append(e.max_hp)
	return out

## Current hull rather than capacity. Differs from foe_hp() only when a fight
## opens against something already hurt — the hellbender carrying last
## engagement's damage — and the party's copy has to start from the same
## number this machine's does.
func foe_hp_now() -> PackedInt32Array:
	var out := PackedInt32Array()
	for e in enemies:
		out.append(e.hp)
	return out

func foe_brace() -> PackedInt32Array:
	var out := PackedInt32Array()
	for e in enemies:
		out.append(e.brace)
	return out

## Whether this fight is the party's rather than yours.
func is_shared() -> bool:
	return shared != null and shared_at >= 0

## Builds one enemy at this danger. Bosses are hand-tuned, never scaled. HP
## scales faster than damage so deeper fights are longer rather than lethal.
func _spawn(template: EnemyTemplate, danger: int, hp_share: float = 1.0) -> EnemyState:
	var e := EnemyState.new()
	# Halved from 0.20/0.10 when danger went from five tiers to ten, so the
	# top of the ladder lands in the same place it always did and only the
	# steps between got finer. HP still climbs twice as fast as damage: deeper
	# fights should be longer, not one-shot lethal.
	var hand_tuned := template.boss or template.miniboss
	var hp_mult := 1.0 if hand_tuned else 1.0 + (danger - 1) * 0.05
	var dmg_mult := 1.0 if hand_tuned else 1.0 + (danger - 1) * 0.025
	# Scale a private copy of the intents so the template stays pristine.
	var scaled: Array[IntentData] = []
	for i in template.loop:
		var c := i.duplicate(true) as IntentData
		c.damage = int(round(c.damage * dmg_mult))
		c.block = int(round(c.block * hp_mult))
		scaled.append(c)
	var scaled_pool: Array[IntentData] = []
	for i in template.pool:
		var c := i.duplicate(true) as IntentData
		c.damage = int(round(c.damage * dmg_mult))
		c.heal = int(round(c.heal * hp_mult))
		scaled_pool.append(c)
	var t := template.duplicate(true) as EnemyTemplate
	t.loop = scaled
	t.pool = scaled_pool
	e.template = t
	e.max_hp = maxi(1, int(round(template.max_hull * hp_mult * hp_share)))
	e.hp = e.max_hp
	e.brace = int(round(template.brace * hp_mult))
	e.pick_intent()
	return e

## Something else arrives mid-fight. Spawned at full health rather than a pack
## share: it did not agree to split anything, it just turned up.
func reinforce(template: EnemyTemplate, danger: int) -> void:
	if finished:
		return
	var e := _spawn(template, danger, 0.75)
	enemies.append(e)
	reinforced = true
	_log("◂ %s answers the call." % e.template.name, &"them")
	Sig.enemy_changed.emit()

## Rolled at the top of a turn. Lawless space is where nobody flies alone, and
## a fight that has already run long is the one worth interrupting.
func _maybe_reinforce() -> void:
	# Solo only, for now. A shared fight's enemy list is the host's, and adding
	# a hull to it mid-fight means every machine spawning the same reinforcement
	# at the same index and agreeing what it is worth. That is a real feature
	# and a short one — the wire already carries foe ids — but it is not this
	# one, and half of it silently would be four different rooms.
	if reinforced or finished or is_shared() or Run.node_at().danger < 3:
		return
	# One roll, on one turn. Rolling every turn compounds: 12% a turn over a ten
	# turn fight is a ~72% chance, which is not "sometimes", it is "usually".
	if enemies.size() > 1 or turn != 3:
		return
	var lawless := Run.node_at().region == MapGen.Region.LAWLESS
	if Rng.fight.randf() >= (0.25 if lawless else 0.10):
		return
	var pool := DB.fight_pool(Run.node_at().danger, false)
	reinforce(DB.enemies[Rng.pick(Rng.fight, pool)], Run.node_at().danger)

func alive() -> Array[EnemyState]:
	var out: Array[EnemyState] = []
	for e in enemies:
		if e.hp > 0:
			out.append(e)
	return out

# -------------------------------------------------------------------- turn cycle

func begin_turn() -> void:
	energy = Run.reactor()
	attacks_this_turn = 0
	lock_on = 0

	# Charge weapons fire on their own schedule.
	var fired: Array[CardData] = []
	var still: Array[ChargingCard] = []
	for c in charging:
		c.turns_left -= 1
		if c.turns_left <= 0:
			fired.append(c.card)
		else:
			still.append(c)
	charging = still

	draw_cards(maxi(0, Run.hand_size() - hand.size()), true)

	for d in drones:
		var times := 2 if (Run.has_set(&"cygnet", 3) and d.fresh) else 1
		for i in times:
			damage_enemy(d.damage, 1, "Drone")
		d.fresh = false
	if drone_brace > 0:
		brace += drone_brace
		_log("Shield wasps add %d brace." % drone_brace, &"good")

	for c in fired:
		_log("▸ %s detonates." % c.name, &"big")
		Sig.charge_fired.emit(c.name)
		CardResolver.resolve(c, self, true)
		# A charge firing can end the fight. Nothing after this point should run.
		if finished:
			return

	_maybe_reinforce()
	Sig.turn_started.emit(turn)
	Sig.hand_changed.emit()
	Sig.player_combat_state_changed.emit()

func end_turn() -> void:
	if finished:
		return
	# A CHOICE CANNOT OUTLIVE THE TURN THAT ASKED IT. Ending the turn with one
	# open would carry "pick 2" into a hand that no longer contains what it was
	# asked about — and `can_play` refuses everything while a choice is pending,
	# so a leaked one locks the next turn solid with no way to clear it.
	choosing = 0
	choose_kind = &""
	# WHAT YOU ARE STILL HOLDING COSTS YOU, before the hand is thrown away.
	# Malfunctions are unplayable, so "still in hand" is every one you drew —
	# and charging here rather than on the draw is what gives you a turn to find
	# a way to get rid of them. See CardData.hand_damage.
	var stuck := 0
	var stuck_heat := 0
	for c in hand:
		stuck += (c as CardData).hand_damage
		stuck_heat += (c as CardData).hand_heat
	if stuck_heat > 0:
		Run.heat += stuck_heat
		_log("+%d heat from what you could not shift." % stuck_heat, &"heat")
	if stuck > 0:
		_log("%d hull from junk left in hand." % stuck, &"them")
		Run.take_hull_damage(stuck, "Malfunctioning systems, left too long.")

	# FUSED CARDS DO NOT GO. Everything else in the hand is swept into the
	# discard; a fused card stays, which is what makes it charge you again next
	# turn and the turn after until you spend something on it.
	var kept: Array[CardData] = []
	for c in hand:
		if (c as CardData).fused:
			kept.append(c)
		else:
			discard.append(c)
	hand.assign(kept)
	if stuck > 0 and Run.dead:
		_finish(&"dead", Run.death_reason)
		return

	if brace > 0:
		Run.heat += 1
		_log("+1 heat maintaining brace.", &"heat")

	# NO END-OF-TURN SHED, and this is where it used to be. It was one point --
	# dissipation runs 2/1/1 across light, medium and heavy -- against card heat
	# of 1 to 6 with two or three cards a turn. Too small to plan around and too
	# present to ignore: it printed a line, nudged the gauge and asked for
	# arithmetic every turn for a change that never altered a decision.
	#
	# It was also why the interesting half of heat was never built. `heat_scale`
	# appears on one card of 149, `damage_equals_heat` on one, `brace_from_heat`
	# on one. Those cards want heat HIGH, and automatic cooling worked against
	# them every turn in a direction the player could not switch off.
	#
	# Dissipation now multiplies venting instead -- see CardResolver. In a fight
	# you generate faster than any radiator sheds, so heat comes off only when
	# you deliberately dump it; between systems you drift, which is
	# `cool_in_transit`.
	#
	# REMOVING IT MOVES THE OVERHEAT CHECK ONE STEP CLOSER to the heat you just
	# generated, which is the intended effect: the burn now measures what you
	# did rather than what survived a free refund. Do not compensate by
	# softening overheat -- it is deliberately a linear 1:1 hull burn with no
	# cliff and no cap, and Solari's 5-set halving it is a set bonus that should
	# stay worth having.

	# Overheat: predictable self-damage. Heat is a second health bar you spend.
	if Run.heat > Run.heat_cap():
		var burn := Run.heat - Run.heat_cap()
		if Run.has_set(&"solari", 5):
			burn = int(ceil(burn / 2.0))
		_log("⚠ OVERHEAT — %d hull burned (%d/%d)." % [burn, Run.heat, Run.heat_cap()], &"heat")
		Sig.overheated.emit(burn)
		Run.take_hull_damage(burn, "Your reactor cooked the hull from the inside.")
		if Run.dead:
			_finish(&"dead", Run.death_reason)
			return

	if attacks_this_turn == 0:
		peaceful_turns += 1
	else:
		peaceful_turns = 0

	# Not every fight wants fighting.
	#
	# Solo only. Pacifying is a claim about how the WHOLE room behaved for two
	# turns, and this object only knows what one ship did — three players
	# shooting while a fourth sits still is not a pod being left alone. Making
	# it work in a party means the host counting quiet turns per ship, which is
	# a real feature rather than a guard, so it is off rather than wrong.
	if enemy.template.fauna and peaceful_turns >= 2 and not is_shared():
		_pacify()
		return

	if is_shared():
		# The one blocking moment. Everything up to here ran at your own pace;
		# the enemy cannot swing until the last ship is done, because it is one
		# object acting on several. See SharedFight.end_turn().
		waiting = true
		# The hand really is empty — it was discarded at the top of this
		# function — and the panel that draws it is the one holding the button
		# that now says WAITING.
		Sig.hand_changed.emit()
		Sig.player_combat_state_changed.emit()
		Net.report_end_turn(shared_at)
		return

	_enemy_act()
	if finished:
		return
	# AFTER the enemy swings, not before.
	#
	# This line used to sit above _enemy_act(), which zeroed the player's block
	# on the way into the one function that spends it — so every Block card in
	# the game bought exactly nothing, silently, for as long as the field has
	# existed. CardData has said "decays at end of enemy turn" the whole time;
	# the code was clearing it at the start of one.
	#
	# Brace was unaffected, which is what hid it: the defensive cards that
	# obviously worked were the ones that used the other field.
	block = 0
	turn += 1
	begin_turn()

func _enemy_act() -> void:
	# Everything still standing acts, in order. A downed enemy is skipped rather
	# than removed, so indexes stay stable for targeting and for the UI.
	for e in alive():
		_act_one(e)
		if finished:
			return
	Sig.enemy_changed.emit()

func _act_one(e: EnemyState) -> void:
	var I := e.intent
	if I == null:
		return
	# Acting on the escape burn IS the escape. Solo only: in a shared fight the
	# host converts this intent into the fight ending before any swing message
	# goes out, so no client ever reaches here with it. See NetSession._swing().
	if I.escape and not is_shared():
		_log("◂ %s: %s" % [e.template.name, I.name], &"them")
		Run.hellbender_breaks_off(e.hp)
		_finish(&"broke_off",
			"A blind jump, furnace-bright. It is gone — hurt, hot, and mending. No salvage.")
		return
	_log("◂ %s: %s" % [e.template.name, I.name], &"them")
	if I.block > 0:
		e.block += I.block
	if I.heal > 0:
		e.hp = mini(e.max_hp, e.hp + I.heal)
		_log("  healed %d." % I.heal, &"them")
	if I.dross > 0:
		new_dross += I.dross
		for i in I.dross:
			named_dross.append(I.dross_id)
		_log("  %d Dross lodges in your systems." % I.dross, &"them")
	if I.damage > 0:
		if negate_next:
			negate_next = false
			_log("  slipped entirely.", &"good")
		else:
			var total := 0
			for i in maxi(1, I.hits):
				var d := I.damage
				# Light hulls dodge; the player never misses, only the enemy does.
				# Run.dodge(), not Run.hull.dodge: a Ghost Drive is worth evasion
				# in the fight, not only on the ship tab's Maneuverability row.
				if Rng.fight.randf() < Run.dodge():
					_log("  missed.", &"good")
					continue
				if block > 0:
					var a := mini(block, d)
					block -= a
					d -= a
				if d > 0 and brace > 0:
					var a2 := mini(brace, d)
					brace -= a2
					d -= a2
				total += d
			if total > 0:
				_log("  %d hull damage." % total, &"them")
				Sig.damage_dealt.emit(total, true, enemies.find(e))
				Run.take_hull_damage(total, "Hull integrity lost. The cold gets in fast.")
			if feedback > 0:
				damage_enemy(feedback, 1, "Feedback")
			if Run.dead:
				_finish(&"dead", Run.death_reason)
				return
	if is_shared():
		# Both of these are the host's. Its block is one number several ships
		# are spending, and its next intent comes off `Rng.fight` — an ordered
		# stream, not a positional derivation, so four machines rolling it
		# independently would agree about nothing. See NetSession._pick_intent().
		return
	e.block = 0
	e.pick_intent()

# ------------------------------------------------------------------------- cards

func draw_cards(n: int, allow_reshuffle: bool) -> void:
	for i in n:
		if deck.is_empty():
			# Reshuffling mid-turn makes zero-cost draw cards loop forever.
			if not allow_reshuffle or discard.is_empty():
				return
			deck = discard.duplicate()
			Rng.shuffle(Rng.fight, deck)
			discard.clear()
			_log("Reshuffled.", &"sys")
		hand.append(deck.pop_back())
	Sig.hand_changed.emit()

func can_play(c: CardData) -> bool:
	# Nothing is playable while a card is waiting for you to pick. A hand that
	# accepted a play mid-choice would resolve two cards in an order neither of
	# them stated.
	return not finished and choosing <= 0 and energy >= c.energy

## Pick one of the cards a discard or a decommission is waiting on.
##
## Deliberately NOT "the player clicked" — it takes an index into the hand, so
## the simulator and the bot reach it the same way the screen does. A choice
## only a mouse can make is a choice `Policy` cannot play around.
## What to pick when nobody is looking — the simulator, the bot, or a turn that
## ended with a choice still open.
##
## JUNK FIRST, then whatever costs the most energy. It is the answer a person
## would give: unplayable cards are the reason these verbs exist, and past that
## the card you are least likely to be able to afford is the one you can most
## afford to lose. Deliberately not random — `Policy` is the number the gate
## reports before every merge, and a coin flip inside it makes that number noisy
## for a reason that has nothing to do with balance.
func best_choice() -> int:
	var best := -1
	var score := -1
	for i in hand.size():
		var c := hand[i]
		var s2: int = (100 if c.unplayable else 0) + c.energy
		if s2 > score:
			score = s2
			best = i
	return best

func choose(index: int) -> void:
	if choosing <= 0 or index < 0 or index >= hand.size():
		return
	var c := hand[index]
	hand.remove_at(index)
	if choose_kind == &"decommission":
		decommissioned.append(c)
		_log("Decommissioned %s." % c.name, &"sys")
	else:
		discard.append(c)
		_log("Discarded %s." % c.name, &"sys")
	choosing -= 1
	if choosing <= 0 or hand.is_empty():
		choosing = 0
		choose_kind = &""
	Sig.hand_changed.emit()
	Sig.player_combat_state_changed.emit()

## target_index picks which enemy this card is aimed at; -1 means "whatever is
## still standing", which is what a click without a drag means.
func play(index: int, target_index: int = -1) -> void:
	current_target = null
	if target_index >= 0 and target_index < enemies.size() and enemies[target_index].hp > 0:
		current_target = enemies[target_index]
	if index < 0 or index >= hand.size():
		return
	var c := hand[index]
	if not can_play(c):
		return
	energy -= c.energy
	hand.remove_at(index)
	if c.unplayable:
		_log("Purged %s." % c.name, &"sys")
		Sig.hand_changed.emit()
		Sig.player_combat_state_changed.emit()
		return
	# A card that decommissions itself never reaches the discard, so it cannot come
	# back when the deck reshuffles. That is what buys it the right to be strong.
	if c.self_decommission:
		decommissioned.append(c)
		_log("%s decommissioned." % c.name, &"sys")
	else:
		discard.append(c)
	if c.charge_turns > 0:
		var cc := ChargingCard.new()
		cc.card = c
		cc.turns_left = c.charge_turns
		if Run.has_set(&"korvan", 3) and c.manufacturer == &"korvan":
			cc.turns_left = maxi(1, cc.turns_left - 1)
		charging.append(cc)
		_log("%s charging (%d turn)." % [c.name, cc.turns_left], &"you")
	else:
		CardResolver.resolve(c, self, false)
	Sig.card_played.emit(c)
	Sig.hand_changed.emit()
	Sig.player_combat_state_changed.emit()

## What this card would actually land, right now, after the enemy's block and
## brace. Mirrors CardResolver's attack maths without mutating anything — if the
## two ever drift, the number on screen becomes a lie, so keep them together.
func preview_damage(c: CardData, target_index: int = -1) -> int:
	if finished:
		return 0
	var e := enemy
	if target_index >= 0 and target_index < enemies.size() and enemies[target_index].hp > 0:
		e = enemies[target_index]
	if e == null:
		return 0
	var per := 0
	if c.damage_equals_heat:
		per = maxi(1, Run.heat + 2)
	elif c.damage > 0:
		per = c.damage
		if c.heat_scale > 0:
			per += int(Run.heat / c.heat_scale)
		if c.manufacturer == &"solari" and c.heat_scale > 0 and Run.has_set(&"solari", 3):
			per += 2
		if c.adapt > 0:
			per += adapt_bonus
		if c.salvo > 0 and salvo_live(c):
			per += c.salvo
		per += lock_on
	if per <= 0:
		return 0

	# Spend a copy of the enemy's mitigation so multi-hit cards read correctly.
	var block_left := e.block
	var brace_left := e.brace
	var total := 0
	for i in maxi(1, c.hits):
		var d := per
		var a := mini(block_left, d)
		block_left -= a
		d -= a
		if d > 0:
			var a2 := mini(brace_left, d)
			brace_left -= a2
			d -= a2
		total += maxi(0, d)
	return total

func damage_enemy(amount: int, hits: int, label: String,
		target: EnemyState = null) -> int:
	if finished:
		return 0
	var e := target
	if e == null or e.hp <= 0:
		e = current_target if current_target != null and current_target.hp > 0 else enemy
	if e == null:
		return 0

	# THE SHOT IS FIRED HERE, whatever fired it. Gating on the card that was
	# played would miss drones and feedback, which damage a contact without you
	# aiming anything at it -- and from their side that is the same thing.
	struck = true

	var total := 0
	for i in maxi(1, hits):
		var d := amount
		if e.block > 0:
			var a := mini(e.block, d)
			e.block -= a
			d -= a
		if d > 0 and e.brace > 0:
			var a2 := mini(e.brace, d)
			e.brace -= a2
			d -= a2
		e.hp -= d
		total += d
	var which := enemies.find(e)
	var who := "" if enemies.size() < 2 else " → %s" % e.template.name
	_log("%s%s → %d%s" % [label, who, total, "" if hits <= 1 else " (%d hits)" % hits], &"you")
	Sig.damage_dealt.emit(total, false, which)
	Sig.enemy_changed.emit()

	if is_shared():
		# Applied locally AND sent. Locally so that your own card reads exactly
		# as it does alone — you played it, you see the number, there is no
		# round trip between the click and the hit. Sent because the host owns
		# the hull: its push arrives a moment later and overwrites hp, block and
		# brace with the answer that counts, which is how two ships firing in
		# the same instant end up agreeing about what is left.
		#
		# The RAW amount goes, not `total`. The host redoes the mitigation
		# itself against the block it actually has, because the copy this
		# machine just spent may already have been spent by somebody else.
		Net.hurt_foe(shared_at, which, amount, hits)
		# And death is NOT decided here. A client that called _victory() off its
		# own optimistic view would pay itself for a kill the host has not seen,
		# which is `docs/coop-design.md` §3's closed economy paid out four times over
		# in the one place it is easiest to do by accident.
		return total

	if e.hp <= 0:
		e.hp = 0
		Sig.enemy_destroyed.emit(which)
		if enemies.size() > 1:
			_log("%s is wreckage." % e.template.name, &"good")
	if alive().is_empty():
		_victory()
	return total

# ------------------------------------------------------------------------ endings

## What breaking contact costs. Read by the confirmation prompt too, so the
## warning cannot drift from the charge.
const FLEE_FUEL := 6

## What a hail is checked against, and how hard.
##
## STEALTH, because talking your way out of this universe is not charm, it is
## looking like a ship nobody wants the paperwork of. There is precedent in the
## option table: `inspection_sweep`'s "talk your way to the front" is a Stealth
## check for exactly the same act.
##
## 3 is a real ladder rather than a formality: a hull with no stealth at all is
## on the 20% band and a Redline launches at 2, which puts it on 65%. That is
## the manufacturer difference showing up in a button rather than in a tooltip.
## Whether you have put a shot into anything this fight.
##
## HAIL closes the moment you do, and only then: bracing, venting, patching and
## every other thing you do to your OWN ship leave it open. That is the line the
## rule is actually drawn on -- not "have you acted" but "have you shot at them",
## which is what they would care about.
##
## Set in `damage_enemy`, which is the one place a hit on a contact lands
## whatever card, drone or feedback effect caused it.
var struck := false

const HAIL_ATTR := &"stealth"
const HAIL_NEED := 3

## What a failed hail costs. Heat, never hull.
##
## `ENCOUNTER_GENERATION.md` §1: a sneak costs DETECTION. Broadcasting on an open
## channel to something that did not take the offer is exactly that, and a botch
## must surprise in degree rather than in kind -- so this is never damage.
const HAIL_HEAT_PARTIAL := 6
const HAIL_HEAT_BOTCHED := 14


## Can this contact be talked to at all?
##
## RULED: not fauna and not a boss. You do not negotiate with something that
## hunts by smell, and the thing guarding the core is not there to be reasoned
## with -- it is the run's ending. `EnemyTemplate` already carries both flags, so
## the gate needs no new data.
## What hailing rolls. The mirror of `flee_check`, and it exists for the same
## reason: the panel that asks whether you mean it has to print the odds you are
## about to take, and it must be reading the number the roll uses rather than
## the one somebody typed twice.
func hail_check() -> Dictionary:
	return {attr = HAIL_ATTR, need = HAIL_NEED}


## Whether the channel has been tried and refused.
##
## ONE ATTEMPT, and the argument is `flee_failed`'s word for word: a check you
## may repeat is a check you will eventually pass, so a hail you could re-open
## every turn was a stealth roll with unlimited retries and a heat bill. It was
## also the louder of the two -- fourteen heat and the turn handed back -- which
## made it the one you could least afford to spam and the only one you could.
var hail_failed := false


## IS THIS SALVO CARD WORTH MORE RIGHT NOW. One definition, because three
## places asked and one of them asked differently.
##
## Salvo pays "if you have already attacked this turn" -- except with five
## Korvan aboard, which makes a Korvan card's salvo unconditional. The resolver
## knew that and the preview knew that; the CHIP on your ship only tested the
## counter, so a Korvan-5 pilot was told SALVO was down at the top of every turn
## while the cards in their hand were quietly already paying it. A readout that
## contradicts the rule is worse than no readout.
func salvo_live(c: CardData) -> bool:
	if attacks_this_turn > 0:
		return true
	return c.manufacturer == &"korvan" and Run.has_set(&"korvan", 5)


func can_hail() -> bool:
	if finished or waiting or enemies.is_empty():
		return false
	if struck or hail_failed:
		return false
	for e in enemies:
		var t: EnemyTemplate = (e as EnemyState).template
		if t.fauna or t.boss or t.miniboss:
			return false
	return true


## Which of the three shut the door, for a tooltip to explain. Empty when open.
##
## Separate from `hail_reason` on purpose: the button wants one word for the
## state and the tooltip wants the cause, and folding them together is what made
## the button carry three vocabularies.
func hail_cause() -> StringName:
	if enemies.is_empty():
		return &""
	if hail_failed:
		return &"failed"
	if struck:
		return &"struck"
	for e in enemies:
		var t: EnemyTemplate = (e as EnemyState).template
		if t.fauna:
			return &"fauna"
		if t.boss or t.miniboss:
			return &"boss"
	return &""


## Why not, for the button to say. Empty when it can.
##
## RULING 8's shape: a disabled thing states what it wants. "HAIL" greyed with no
## reason reads as a bug in a way that "NOT LISTENING" never does.
func hail_reason() -> String:
	if enemies.is_empty():
		return ""
	# ONE LABEL FOR A SHUT DOOR, and it has to fit the rail -- which is 68,
	# because END TURN sets that and the pile is cut to it. "NOT NEGOTIATING"
	# needed 93 and took the rail to 100, which made the pile landscape; this
	# needs 58. Three different words for "no" made the button
	# read as three different mechanics -- a player would learn NO REPLY, NO
	# TERMS and YOU FIRED separately before noticing they are the same greyed
	# state. The BUTTON says what is true of the button; the TOOLTIP says why,
	# and why is where the three actually differ.
	if struck or hail_failed:
		return "NO REPLY"
	for e in enemies:
		var t: EnemyTemplate = (e as EnemyState).template
		if t.fauna or t.boss or t.miniboss:
			return "NO REPLY"
	return ""


## Talk your way out.
##
## The same exit `flee` buys, bought with words: the contact breaks off, there is
## no salvage, and the node is marked so the sector offers a jump rather than the
## fight again. What it does NOT cost is the six fuel -- that is the whole point
## of having stealth on the ship.
##
## Failure is loud rather than damaging. You have broadcast, and they did not
## take it.
func hail() -> void:
	if not can_hail():
		return
	var band := SkillCheck.roll(hail_check())
	match band:
		SkillCheck.Band.MET, SkillCheck.Band.CLEAN:
			Run.node_at().fled = true
			Sig.resources_changed.emit()
			_finish(&"hailed",
				"They listen, decide you are not worth the paperwork, and go.")
		SkillCheck.Band.PARTIAL:
			Run.heat += HAIL_HEAT_PARTIAL
			Run.node_at().fled = true
			Sig.resources_changed.emit()
			_finish(&"hailed",
				"They break off, slowly, and take a long look at you on the way past.")
		_:
			Run.heat += HAIL_HEAT_BOTCHED
			Sig.resources_changed.emit()
			hail_failed = true
			exit_note = "You hail on an open channel. It tells them exactly where you are, and the turn is theirs. They will not take another."
			Run.log_line(exit_note, &"heat")
			end_turn()


## Whether the burn has been tried and missed.
##
## ONE ATTEMPT. Fleeing used to be a purchase, then a check you could re-roll
## every turn until it landed -- which is the same thing with extra steps, since
## a check you may repeat is a check you will eventually pass. Failing it now
## closes the door: you committed to the burn, they are still on you, and the
## fight is the only thing left.
var flee_failed := false


## Can you still try to run?
##
## Not from the core's guard: that is the fight the run has been travelling
## towards and there is nowhere past it to run TO. The hellbender is deliberately
## NOT included -- breaking off it banks the damage you did, which is the whole
## shape of that chase, and taking that away would quietly delete a mechanic.
func can_flee() -> bool:
	if finished or waiting or flee_failed:
		return false
	for e in enemies:
		if (e as EnemyState).template.boss:
			return false
	return true


## What the button says when it cannot. Empty when it can.
func flee_reason() -> String:
	return "" if can_flee() else "NO ESCAPE"


## Which shut it, for the tooltip. Empty when open.
func flee_cause() -> StringName:
	if can_flee():
		return &""
	if flee_failed:
		return &"failed"
	return &"boss"


## Breaking contact is MANEUVER, and it can fail.
##
## It used to be a purchase: six fuel, always granted. That made FLEE the safest
## button on the panel -- every fight had a guaranteed exit and the only question
## was whether you minded the price. A check makes leaving a thing your ship is
## either good at or is not, and puts MANEUVER -- which had almost nothing to do
## outside dodge -- on a button you reach for under pressure.
##
## 3 against a ladder that runs 4/6/8 by hull class: a light frame is on the good
## bands and a heavy is on the bad ones, which is what a light frame is FOR.
const FLEE_ATTR := &"maneuver"
const FLEE_NEED := 3

## The ugly version of getting away. Beyond `FLEE_FUEL`, not instead of it.
const FLEE_FUEL_PARTIAL := 10


## What a flee would roll, for the panel to print before you commit.
## WHAT A FAILED EXIT DID, for the panel that asked to print.
##
## A hail or a burn that WORKS ends the fight, and `_finish` carries its own
## summary out on `combat_ended`. One that fails does not end anything: it spends
## the fuel or the heat, logs a line into a feed you are not looking at, and
## hands the turn back -- so the one moment the player is owed an answer is the
## one moment nothing was telling them. Set on every path through both, cleared
## by the caller before it asks.
var exit_note: String = ""


func flee_check() -> Dictionary:
	return {attr = FLEE_ATTR, need = FLEE_NEED}


func flee() -> void:
	if not can_flee():
		return
	var band := SkillCheck.roll(flee_check())
	if band == SkillCheck.Band.BOTCHED:
		flee_failed = true
		# YOU HAVE TO STAY. The burn is spent whether or not it worked, which is
		# the honest cost of trying: you turned your back to do it.
		Run.fuel = maxi(0, Run.fuel - FLEE_FUEL)
		Sig.resources_changed.emit()
		exit_note = "You commit to the burn and they are still on you when it ends."
		Run.log_line(exit_note, &"heat")
		end_turn()
		return
	# One number, named once. The line said 2 while the code took 6 — a
	# discrepancy the player pays and the log denies.
	Run.fuel = maxi(0, Run.fuel - FLEE_FUEL)
	if band == SkillCheck.Band.PARTIAL:
		# Out, but the expensive way round. In domain: a burn costs fuel.
		Run.fuel = maxi(0, Run.fuel - FLEE_FUEL_PARTIAL)
	# So the sector you are dropped back onto offers a jump rather than the
	# fight you just paid six fuel to leave.
	Run.node_at().fled = true
	# Running from the hellbender banks the damage you did — it does not heal
	# between engagements, it heals per MOVE, which is the chase. Solo only:
	# in a party the host writes this back when the last ship leaves the
	# shared fight, in NetSession._apply_leave().
	if not is_shared() and not enemies.is_empty() and enemies[0].template.miniboss:
		Run.hellbender_scarred(enemies[0].hp)
	Sig.resources_changed.emit()
	_finish(&"fled", "You burned %d fuel breaking contact. No salvage."
		% (FLEE_FUEL + (FLEE_FUEL_PARTIAL if band == SkillCheck.Band.PARTIAL else 0)))

func _victory() -> void:
	Run.kills += 1
	var node: MapGen.MapNode = Run.node_at()
	var gained := int(round(enemy.template.credit_reward * (1.0 + (node.danger - 1) * 0.2)))
	if Run.has_set(&"probate", 3):
		gained = int(round(gained * 1.5))
	# Held until the wrecks exist, because the money goes INTO one -- see below.
	var purse := gained
	for i in new_dross:
		var which: StringName = named_dross[i] if i < named_dross.size() else &""
		Run.add_dross(danger, which)
	var bits: PackedStringArray = ["%d credits" % gained]
	if enemy.template.fauna:
		# INTO THE HULL YOU JUST KILLED. It was `Run.exotic += 2`, which put two
		# points of a ledger straight into your pocket past a hold that might
		# have had no room for them -- and megafauna are the one enemy whose
		# whole drop IS material. See `RunState.add_material`.
		var got := 2 + (1 if Run.has_set(&"calyx", 5) else 0)
		Run.add_material(&"exotic", got)
		bits.append("%d exotic" % got)
	if Run.has_set(&"calyx", 3):
		Run.heal(3)
	if clears_node:
		Run.consume_node(node)
	# And anybody who paid to have this stop moving.
	Run.clear_contract_target(node.index)

	if enemy.template.boss:
		Run.win()
		_finish(&"won", "The core opens.")
		return

	var drops := 2 if node.region == MapGen.Region.LAWLESS else 1
	if node.region == MapGen.Region.FAUNA:
		drops = 0
	# A set piece pays like one. Three parts a hand rather than one, and the
	# roamer stops roaming — idempotent, because in a party every crew machine
	# runs this and the host may have run it already in _apply_hurt().
	if enemy.template.miniboss:
		drops = 3
		Run.hellbender_defeated()

	# ONE WAY TO BE PAID, and it is the wreck you just made.
	#
	# This used to branch. Alone the parts went straight into your hold, on the
	# reasoning that "a bag with one hand reaching into it is a menu between you
	# and your own loot" -- which was true of a LIST and is not true of a
	# container you open. `MATERIALS_NOTE` 3.6 made every physical payout a
	# place you reach into, and 3.4 is why: `Run.stow` returns false on a full
	# hold, so the solo arm quietly destroyed the reward for winning whenever
	# you were carrying anything.
	#
	# In a party it was always this, and for a reason worth keeping: both ships
	# used to roll their own drop off their own seat-salted stream, which stops
	# two players being handed the identical part and does nothing about one
	# frigate paying the party twice over. `docs/coop-design.md` 3 runs the dive
	# economy as a closed loop, and a kill that pays per-head is not closed. The
	# parts sit where the fight happened until somebody reaches for one, and the
	# reach is first come, first served.
	#
	# So the party rule became the only rule, and solo is a party of one.
	# ONE CONTAINER PER HULL, and the totals do not move.
	#
	# What the fight is worth is unchanged -- `drops` scaled by the crew, the same
	# roll, the same credits. What changes is the PACKAGING: it used to be one
	# pool for the whole fight, and a pool is the right answer to "how much" and
	# the wrong answer to "where is it". A wreck you can point at is a wreck you
	# can go and open, and three of them is three decisions instead of one list.
	#
	# Dealt round-robin so a two-ship fight does not put everything in the first
	# hull and leave the second as an empty box you still have to check.
	var hands := maxi(1, shared.paid if (is_shared() and shared != null) else 1)
	var pool := drops * hands
	var made: Array = []
	for e in enemies:
		made.append(Run.new_wreck(node, (e as EnemyState).template))
	if made.is_empty():
		made.append(Run.sector_jetsam(node))
	var force := node.manufacturer if node.region == MapGen.Region.TERRITORY else &""
	for i in pool:
		var h: MapGen.Jetsam = made[i % made.size()]
		h.items.append(LootGen.roll_module(node.danger, force,
			node.region == MapGen.Region.CORE))
	# THE MONEY IS IN THE FIRST HULL. It has to be somewhere you reach, and the
	# alternative -- a chit in each -- turns one payout into a chore.
	if purse > 0:
		(made[0] as MapGen.Jetsam).items.append(CreditChit.of(purse))
	if pool > 0:
		bits.append("%d in the wreck%s" % [pool, "" if made.size() == 1 else "s"])
	if new_dross > 0:
		bits.append("%d Dross" % new_dross)
	# What was aboard the thing you just killed. Not part of the bag and not
	# claimed: knowledge is the one thing here nobody has to race for, so in a
	# party every ship in the fight reads the same page. See Archive.
	Archive.recover_at(node, "cut out of a wreck you made")
	_finish(&"victory", " · ".join(bits))

func _pacify() -> void:
	var node: MapGen.MapNode = Run.node_at()
	if clears_node:
		Run.consume_node(node)
	# Pacifying pays the same way killing does, in the same place.
	Run.add_material(&"exotic", 1)
	for i in new_dross:
		var which: StringName = named_dross[i] if i < named_dross.size() else &""
		Run.add_dross(danger, which)
	Run.whale_boon = true
	if Run.has_set(&"calyx", 3):
		Run.heal(3)
	# The quiet route reads. Nothing is taken from the animal — found_at only
	# says where you were. Fifth door, same hinge; see Archive.recover_at.
	Archive.recover_at(node, "left alongside")
	_finish(&"pacified",
		"It stops circling and drifts off singing. 1 exotic material. The pod remembers.")

func _finish(res: StringName, text: String) -> void:
	finished = true
	waiting = false
	# Out of the crew whatever happened — won, died, fled or pacified. NOT
	# optional: a crew list still holding somebody who will never press END TURN
	# again is a barrier that never closes, and the rest of the party would sit
	# on a WAITING button for the remainder of the run.
	if is_shared():
		Net.leave_fight(shared_at)
		release()
	result = res
	summary = text
	Sig.combat_ended.emit(res, text)

# ------------------------------------------------------------------- the party

## Take the party's copy of the enemy as this fight's enemy.
func _attach(f: SharedFight) -> void:
	shared = f
	shared_at = f.at
	# Whatever has already happened in this fight is history to a ship that just
	# arrived. Adopting the serial rather than zero stops a joiner from drawing
	# the shot that landed before it got here.
	_seen_hit = f.hit_serial
	# And so is the turn number. A ship joining a fight on turn seven is on turn
	# seven — starting at one and catching up would run begin_turn() six times
	# in a row on the next push, which is six hands of cards.
	turn = f.turn
	Sig.party_fight_changed.connect(_on_fight_changed)
	Sig.party_fight_swing.connect(_on_swing)
	# Losing the host mid-fight must not be a softlock. See _on_party_lost().
	Sig.party_failed.connect(_on_party_lost)
	_adopt(f)


## Let go. Public because a fight can end without finishing — ABANDON RUN from
## the pause menu drops `Router.combat` on the floor mid-turn, and a Combat left
## connected to the signal bus is a dead fight still reacting to a live one.
func release() -> void:
	if Sig.party_fight_changed.is_connected(_on_fight_changed):
		Sig.party_fight_changed.disconnect(_on_fight_changed)
	if Sig.party_fight_swing.is_connected(_on_swing):
		Sig.party_fight_swing.disconnect(_on_swing)
	if Sig.party_failed.is_connected(_on_party_lost):
		Sig.party_failed.disconnect(_on_party_lost)
	shared = null
	shared_at = -1
	waiting = false


## Copy the host's answer over the local enemy.
##
## Only the numbers move. The templates, the art and the scaled intent lists
## were built identically on every machine from the same ids and the same
## danger, so what crosses is hull, block, brace and WHICH intent — never the
## intent itself.
func _adopt(f: SharedFight) -> void:
	var n := mini(f.foes.size(), enemies.size())
	for i in n:
		var src := f.foes[i]
		var dst := enemies[i]
		var was := dst.hp
		dst.hp = src.hp
		dst.max_hp = src.max_hp
		dst.brace = src.brace
		dst.block = src.block
		if src.kind == SharedFight.Pick.ESCAPE:
			# Not in any template list — see escape_intent(). The host names
			# the kind and every machine builds the same card.
			dst.intent = Combat.escape_intent()
		else:
			var list: Array[IntentData] = dst.template.pool \
				if src.kind == SharedFight.Pick.POOL else dst.template.loop
			if src.pick >= 0 and src.pick < list.size():
				dst.intent = list[src.pick]
		if was > 0 and dst.hp <= 0:
			Sig.enemy_destroyed.emit(i)
			if enemies.size() > 1:
				_log("%s is wreckage." % dst.template.name, &"good")
	# Somebody else's gun. Drawn here because it is the only place this machine
	# can learn about it — a partner's card was played on a different computer,
	# and without this their hits land silently and the hull bar drops for no
	# visible reason.
	if f.last_hit.size() == 4 and f.hit_serial > _seen_hit:
		_seen_hit = f.hit_serial
		var by := f.last_hit[0]
		if by != Net.local_id():
			var who := Net.name_of(by)
			_log("%s → %d" % [who.to_upper() if who != "" else "PARTNER",
				f.last_hit[2]], &"good")
			Sig.damage_dealt.emit(f.last_hit[2], false, f.last_hit[1])
	Sig.enemy_changed.emit()


## The host said something moved.
func _on_fight_changed(at: int) -> void:
	if at != shared_at or finished:
		return
	var f := Net.fight_at(at)
	if f == null:
		return
	shared = f
	_adopt(f)
	if f.over:
		# The hellbender left before anybody killed it. The host has already moved
		# it and written its hull back; this machine only has to stop fighting.
		if f.broke:
			_finish(&"broke_off",
				"A blind jump, furnace-bright. It is gone — hurt, hot, and mending. No salvage.")
			return
		# The host decides the fight is won, not this machine. Everyone still in
		# it when the last hull came apart is paid, which is the ruling: winning
		# a fight gets you the loot.
		if alive().is_empty():
			_victory()
		return
	# The turn number IS the "everybody go again" message.
	if f.turn > turn:
		# After the swing, never before. Same ordering the solo path has kept
		# since the bug that zeroed Block on the way INTO the enemy's turn.
		block = 0
		turn = f.turn
		waiting = false
		begin_turn()


## The party is gone — the host dropped, or the connection did.
##
## The fight does not stop. It becomes the fight the game has always had: the
## enemy on this machine is whatever the last push said it was, and from here
## this object decides its own hulls again. Anything else is a softlock, because
## the one thing a shared fight waits for is a host that is no longer there.
##
## The enemy is left at party scale. Finishing a frigate sized for four on your
## own is bad; being unable to finish it at all is worse, and FLEE is still on
## the panel.
func _on_party_lost(_reason: String) -> void:
	if finished or not is_shared():
		return
	_log("The convoy channel is gone. You are on your own.", &"them")
	var was_waiting := waiting
	release()
	if was_waiting:
		# Mid-barrier when it dropped. Take the enemy turn this machine was
		# waiting to be told about, so the fight carries on rather than sitting
		# on a button that will never light up again.
		_enemy_act()
		if finished:
			return
		block = 0
		turn += 1
		begin_turn()
	Sig.player_combat_state_changed.emit()
	Sig.hand_changed.emit()


## Something is shooting at you.
##
## Resolved here, on your machine, against your own dodge, block, brace and
## hull, because those numbers exist nowhere else. The host chose the target and
## named the intent; everything after that is local.
func _on_swing(at: int, which: int, kind: int, pick: int) -> void:
	if at != shared_at or finished or which < 0 or which >= enemies.size():
		return
	var e := enemies[which]
	var list: Array[IntentData] = e.template.pool \
		if kind == SharedFight.Pick.POOL else e.template.loop
	if pick < 0 or pick >= list.size():
		return
	e.intent = list[pick]
	_act_one(e)
	Sig.enemy_changed.emit()


func _log(text: String, kind: StringName) -> void:
	Run.log_line(text, kind)
