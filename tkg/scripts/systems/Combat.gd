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
	var armor: int
	var block: int = 0
	var step: int = 0
	var intent: IntentData

	func pick_intent() -> void:
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

var energy: int = 0
var armor: int = 0
var block: int = 0
var lock_on: int = 0
var riposte: int = 0
var adapt_bonus: int = 0
var negate_next: bool = false
var drones: Array[Drone] = []
var drone_armor: int = 0
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

var turn: int = 1
var attacks_this_turn: int = 0
var peaceful_turns: int = 0
var new_dross: int = 0
var finished: bool = false
var result: StringName = &""
var summary: String = ""

# ------------------------------------------------------------------------- setup

func start(template: EnemyTemplate, danger: int, extras: Array = []) -> void:
	enemies.clear()
	var share := 1.0 if extras.is_empty() else 0.6
	enemies.append(_spawn(template, danger, share))
	for t in extras:
		enemies.append(_spawn(t as EnemyTemplate, danger, share))

	deck = DeckBuilder.build()
	Rng.shuffle(Rng.fight, deck)
	hand.clear()
	discard.clear()
	negate_next = Run.has_set(&"redline", 5)
	Sig.combat_started.emit(enemies[0].template.name)
	begin_turn()

## Builds one enemy at this danger. Bosses are hand-tuned, never scaled. HP
## scales faster than damage so deeper fights are longer rather than lethal.
func _spawn(template: EnemyTemplate, danger: int, hp_share: float = 1.0) -> EnemyState:
	var e := EnemyState.new()
	# Halved from 0.20/0.10 when danger went from five tiers to ten, so the
	# top of the ladder lands in the same place it always did and only the
	# steps between got finer. HP still climbs twice as fast as damage: deeper
	# fights should be longer, not one-shot lethal.
	var hp_mult := 1.0 if template.boss else 1.0 + (danger - 1) * 0.05
	var dmg_mult := 1.0 if template.boss else 1.0 + (danger - 1) * 0.025
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
	e.armor = int(round(template.armor * hp_mult))
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
	if reinforced or finished or Run.node_at().danger < 3:
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
	if drone_armor > 0:
		armor += drone_armor
		_log("Shield wasps add %d armor." % drone_armor, &"good")

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
	discard.append_array(hand)
	hand.clear()

	if armor > 0:
		Run.heat += 1
		_log("+1 heat maintaining armor.", &"heat")

	var shed := mini(Run.heat, Run.dissipation())
	if shed > 0:
		Run.heat -= shed
		_log("Dissipated %d heat." % shed, &"sys")

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
	if enemy.template.fauna and peaceful_turns >= 2:
		_pacify()
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
	# Armor was unaffected, which is what hid it: the defensive cards that
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
	_log("◂ %s: %s" % [e.template.name, I.name], &"them")
	if I.block > 0:
		e.block += I.block
	if I.heal > 0:
		e.hp = mini(e.max_hp, e.hp + I.heal)
		_log("  healed %d." % I.heal, &"them")
	if I.dross > 0:
		new_dross += I.dross
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
				if d > 0 and armor > 0:
					var a2 := mini(armor, d)
					armor -= a2
					d -= a2
				total += d
			if total > 0:
				_log("  %d hull damage." % total, &"them")
				Sig.damage_dealt.emit(total, true, enemies.find(e))
				Run.take_hull_damage(total, "Hull integrity lost. The cold gets in fast.")
			if riposte > 0:
				damage_enemy(riposte, 1, "Riposte")
			if Run.dead:
				_finish(&"dead", Run.death_reason)
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
	return not finished and energy >= c.energy

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
## armor. Mirrors CardResolver's attack maths without mutating anything — if the
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
		var salvo_ok := attacks_this_turn > 0
		if c.manufacturer == &"korvan" and Run.has_set(&"korvan", 5):
			salvo_ok = true
		if c.salvo > 0 and salvo_ok:
			per += c.salvo
		per += lock_on
	if per <= 0:
		return 0

	# Spend a copy of the enemy's mitigation so multi-hit cards read correctly.
	var block_left := e.block
	var armor_left := e.armor
	var total := 0
	for i in maxi(1, c.hits):
		var d := per
		var a := mini(block_left, d)
		block_left -= a
		d -= a
		if d > 0:
			var a2 := mini(armor_left, d)
			armor_left -= a2
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

	var total := 0
	for i in maxi(1, hits):
		var d := amount
		if e.block > 0:
			var a := mini(e.block, d)
			e.block -= a
			d -= a
		if d > 0 and e.armor > 0:
			var a2 := mini(e.armor, d)
			e.armor -= a2
			d -= a2
		e.hp -= d
		total += d
	var who := "" if enemies.size() < 2 else " → %s" % e.template.name
	_log("%s%s → %d%s" % [label, who, total, "" if hits <= 1 else " (%d hits)" % hits], &"you")
	Sig.damage_dealt.emit(total, false, enemies.find(e))
	Sig.enemy_changed.emit()

	if e.hp <= 0:
		e.hp = 0
		Sig.enemy_destroyed.emit(enemies.find(e))
		if enemies.size() > 1:
			_log("%s is wreckage." % e.template.name, &"good")
	if alive().is_empty():
		_victory()
	return total

# ------------------------------------------------------------------------ endings

## What breaking contact costs. Read by the confirmation prompt too, so the
## warning cannot drift from the charge.
const FLEE_FUEL := 6

func flee() -> void:
	if finished:
		return
	# One number, named once. The line said 2 while the code took 6 — a
	# discrepancy the player pays and the log denies.
	Run.fuel = maxi(0, Run.fuel - FLEE_FUEL)
	# So the sector you are dropped back onto offers a jump rather than the
	# fight you just paid six fuel to leave.
	Run.node_at().fled = true
	Sig.resources_changed.emit()
	_finish(&"fled", "You burned %d fuel breaking contact. No salvage." % FLEE_FUEL)

func _victory() -> void:
	Run.kills += 1
	var node: MapGen.MapNode = Run.node_at()
	var gained := int(round(enemy.template.credit_reward * (1.0 + (node.danger - 1) * 0.2)))
	if Run.has_set(&"dredge", 3):
		gained = int(round(gained * 1.5))
	Run.add_credits(gained)
	Run.dross += new_dross
	var bits: PackedStringArray = ["%d credits" % gained]
	if enemy.template.fauna:
		Run.exotic += 2
		bits.append("2 exotic")
		if Run.has_set(&"calyx", 5):
			Run.exotic += 1
	if Run.has_set(&"calyx", 3):
		Run.heal(3)
	if clears_node:
		node.cleared = true

	if enemy.template.boss:
		Run.win()
		_finish(&"won", "The core opens.")
		return

	var drops := 2 if node.region == MapGen.Region.LAWLESS else 1
	if node.region == MapGen.Region.FAUNA:
		drops = 0
	for i in drops:
		var force := node.manufacturer if node.region == MapGen.Region.TERRITORY else &""
		Run.stow(LootGen.roll_module(node.danger, force,
			node.region == MapGen.Region.CORE))
	if drops > 0:
		bits.append("%d module%s" % [drops, "" if drops == 1 else "s"])
	if new_dross > 0:
		bits.append("%d Dross" % new_dross)
	_finish(&"victory", " · ".join(bits))

func _pacify() -> void:
	var node: MapGen.MapNode = Run.node_at()
	if clears_node:
		node.cleared = true
	Run.exotic += 1
	Run.dross += new_dross
	Run.whale_boon = true
	if Run.has_set(&"calyx", 3):
		Run.heal(3)
	_finish(&"pacified",
		"It stops circling and drifts off singing. 1 exotic material. The pod remembers.")

func _finish(res: StringName, text: String) -> void:
	finished = true
	result = res
	summary = text
	Sig.combat_ended.emit(res, text)

func _log(text: String, kind: StringName) -> void:
	Run.log_line(text, kind)
