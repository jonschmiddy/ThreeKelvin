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
			var roll := randi() % maxi(1, total)
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

var enemy: EnemyState
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

var turn: int = 1
var attacks_this_turn: int = 0
var peaceful_turns: int = 0
var new_dross: int = 0
var finished: bool = false
var result: StringName = &""
var summary: String = ""

# ------------------------------------------------------------------------- setup

func start(template: EnemyTemplate, danger: int) -> void:
	enemy = EnemyState.new()
	enemy.template = template
	# Bosses are hand-tuned, not scaled. HP scales faster than damage so that
	# deeper fights are longer rather than one-shot lethal.
	var hp_mult := 1.0 if template.boss else 1.0 + (danger - 1) * 0.20
	var dmg_mult := 1.0 if template.boss else 1.0 + (danger - 1) * 0.10
	enemy.max_hp = int(round(template.max_hull * hp_mult))
	enemy.hp = enemy.max_hp
	enemy.armor = int(round(template.armor * hp_mult))
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
	enemy.template = t

	deck = DeckBuilder.build()
	deck.shuffle()
	hand.clear()
	discard.clear()
	negate_next = Run.has_set(&"redline", 5)
	enemy.pick_intent()
	Sig.combat_started.emit(t.name)
	begin_turn()

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

	block = 0
	_enemy_act()
	if finished:
		return
	turn += 1
	begin_turn()

func _enemy_act() -> void:
	var I := enemy.intent
	if I == null:
		return
	_log("◂ %s: %s" % [enemy.template.name, I.name], &"them")
	if I.block > 0:
		enemy.block += I.block
	if I.heal > 0:
		enemy.hp = mini(enemy.max_hp, enemy.hp + I.heal)
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
				if randf() < Run.hull.dodge:
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
				Sig.damage_dealt.emit(total, true)
				Run.take_hull_damage(total, "Hull integrity lost. The cold gets in fast.")
			if riposte > 0:
				damage_enemy(riposte, 1, "Riposte")
			if Run.dead:
				_finish(&"dead", Run.death_reason)
				return
	enemy.block = 0
	enemy.pick_intent()
	Sig.enemy_changed.emit()

# ------------------------------------------------------------------------- cards

func draw_cards(n: int, allow_reshuffle: bool) -> void:
	for i in n:
		if deck.is_empty():
			# Reshuffling mid-turn makes zero-cost draw cards loop forever.
			if not allow_reshuffle or discard.is_empty():
				return
			deck = discard.duplicate()
			deck.shuffle()
			discard.clear()
			_log("Reshuffled.", &"sys")
		hand.append(deck.pop_back())
	Sig.hand_changed.emit()

func can_play(c: CardData) -> bool:
	return not finished and energy >= c.energy

func play(index: int) -> void:
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

func damage_enemy(amount: int, hits: int, label: String) -> int:
	var total := 0
	for i in maxi(1, hits):
		var d := amount
		if enemy.block > 0:
			var a := mini(enemy.block, d)
			enemy.block -= a
			d -= a
		if d > 0 and enemy.armor > 0:
			var a2 := mini(enemy.armor, d)
			enemy.armor -= a2
			d -= a2
		enemy.hp -= d
		total += d
	_log("%s → %d%s" % [label, total, "" if hits <= 1 else " (%d hits)" % hits], &"you")
	Sig.damage_dealt.emit(total, false)
	Sig.enemy_changed.emit()
	if enemy.hp <= 0:
		enemy.hp = 0
		_victory()
	return total

# ------------------------------------------------------------------------ endings

func flee() -> void:
	if finished:
		return
	Run.fuel = maxi(0, Run.fuel - 2)
	Sig.resources_changed.emit()
	_finish(&"fled", "You burned 2 fuel breaking contact. No salvage.")

func _victory() -> void:
	Run.kills += 1
	var node: MapGen.MapNode = Run.node_at()
	var gained := int(round(enemy.template.scrap_reward * (1.0 + (node.danger - 1) * 0.2)))
	if Run.has_set(&"dredge", 3):
		gained = int(round(gained * 1.5))
	Run.add_scrap(gained)
	Run.dross += new_dross
	var bits: PackedStringArray = ["%d scrap" % gained]
	if enemy.template.fauna:
		Run.exotic += 2
		bits.append("2 exotic")
		if Run.has_set(&"calyx", 5):
			Run.exotic += 1
	if Run.has_set(&"calyx", 3):
		Run.heal(3)
	node.cleared = true

	if enemy.template.boss:
		Run.win()
		_finish(&"won", "The farlight opens.")
		return

	var drops := 2 if node.region == MapGen.Region.LAWLESS else 1
	if node.region == MapGen.Region.FAUNA:
		drops = 0
	for i in drops:
		var force := node.manufacturer if node.region == MapGen.Region.TERRITORY else &""
		Run.cargo.append(LootGen.roll_module(node.danger, force,
			node.region == MapGen.Region.CORE))
	if drops > 0:
		bits.append("%d module%s" % [drops, "" if drops == 1 else "s"])
	if new_dross > 0:
		bits.append("%d Dross" % new_dross)
	_finish(&"victory", " · ".join(bits))

func _pacify() -> void:
	var node: MapGen.MapNode = Run.node_at()
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
