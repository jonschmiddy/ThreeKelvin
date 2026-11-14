class_name Combat
extends RefCounted

## Turn-based combat with telegraphed intent. The deck reshuffles only at turn start, or
## free draws loop.
## Why: docs/why/Combat.md#combat-rulings

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
	## Which of its kind's pictures this one is (`DB.enemy_sprite`). Set once,
	## from where the fight is (`Combat.look_for`), and handed to its wreck.
	var look: int = 0

	func pick_intent() -> void:
		# A miniboss escape is checked when the next move is chosen, so burst damage mid-turn
		# still kills.
		# Why: docs/why/Combat.md#miniboss-escape
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

## Held on Combat, not the screen: saves, bots and the sim must see the turn is waiting.
var choosing: int = 0
var choose_kind: StringName = &""

var energy: int = 0
var brace: int = 0
## Counts carried braces so the first-run hint reports what holding it cost, not a guess.
var brace_held: int = 0
var block: int = 0
var lock_on: int = 0
var feedback: int = 0
var adapt_bonus: int = 0
var negate_next: bool = false
var drones: Array[Drone] = []
var drone_brace: int = 0
var charging: Array[ChargingCard] = []

## Presentation only. Reading the last `card_played` drew every shot as the card before it.
## Why: docs/why/Combat.md#resolving-card
var resolving: CardData = null

## Which enemy the card being played is aimed at. Set by play(); damage_enemy
## falls back to it so the resolver never has to know about targeting.
var current_target: EnemyState = null
## False for an ambush, or killing what jumped you would mark the dock resolved unopened.
## Why: docs/why/Combat.md#node-clearing
var clears_node: bool = true

## Only the enemy is shared. Your deck, hand, energy and hull stay local, so no rewrite was
## needed.
## Why: docs/why/Combat.md#shared-fight
var shared: SharedFight = null
## Kept apart because `shared` is replaced on every push and the signal names a place.
var shared_at: int = -1
## The serial of the last partner shot this machine has already drawn. See
## SharedFight.last_hit.
var _seen_hit: int = 0
## Ended your turn and waiting on the rest of the party. The only moment in a
## shared fight that blocks — see SharedFight.end_turn().
var waiting: bool = false
## A fight can be planned but not begun while the host answers, and END TURN or flee there
## broke state.
## Why: docs/why/Combat.md#planned-but-not-begun
var asking_at: int = -1
## Hull growth count for the log to say when the boss grows; followed from the host in
## `_adopt`.
var grown: int = -1
## THE PLAYERS THIS FIGHT WAS BUILT FOR (`PartyScale`, Jon, Nov 5): the game's
## count as it was planned, then the party's fight's own (`SharedFight.party`,
## the host's) once it is attached. Its hull is `PartyScale.hull` of it and its
## wrecks pay `PartyScale.loot` of it. 1 alone.
var party: int = 1
## STUNNED: joined the party's fight after its first turn (Jon, Nov 5), and
## sitting out the rest of that turn and the enemy's. No hand and no energy;
## END TURN, HAIL, FLEE and every card are shut; it can still be shot. The hand
## comes when the turn moves (`_on_fight_changed`). The fight says who is
## (`SharedFight.stunned`); this is this ship's copy.
var stunned: bool = false
## Who was in the party's fight at the last push this ship saw, so a partner
## joining is said once, and nobody already here when this ship arrived is
## announced (`_on_fight_changed`).
var _last_crew: PackedInt32Array = PackedInt32Array()

var turn: int = 1
## THIS SHIP'S FIRST TURN OF THE FIGHT is still to come: WARM START and FIRST
## LOOK (science) read it in `begin_turn`, which clears it. A flag and not
## `turn == 1`, because `_attach` sets `turn` to the party's, so a ship joining
## a fight on turn seven would never see a first turn of its own.
var _opening := true
var attacks_this_turn: int = 0
var peaceful_turns: int = 0
var new_dross: int = 0

## Kept because what an enemy lodges in you is rolled against danger.
var danger: int = 1

## A list, not a count: an intent that names its own malfunction needs an entry per point.
var named_dross: Array[StringName] = []
var finished: bool = false
var result: StringName = &""
var summary: String = ""

## 35%: a fight going well ends in a kill, a timid one watches it leave.
const MINIBOSS_BREAKS_AT := 0.35

## Built fresh per call: template intents are scaled per fight, so a shared constant would
## be mutated.
static func escape_intent() -> IntentData:
	var i := IntentData.new()
	i.name = "ESCAPE BURN"
	i.text = "Spooling a blind jump: finish it now or lose it"
	i.telegraph = true
	i.escape = true
	return i

# ------------------------------------------------------------------------- setup

func start(template: EnemyTemplate, danger: int, extras: Array = []) -> void:
	plan(template, danger, extras)
	begin(null)

## Split from `start()` so a shared fight opens with the host's numbers; scaling stays in
## `_spawn`.
## Why: docs/why/Combat.md#plan-then-begin
## `players`: the game's count to build for (`PartyScale`); -1 asks the session, 1 alone.
func plan(template: EnemyTemplate, danger: int, extras: Array = [], players: int = -1) -> void:
	self.danger = danger
	enemies.clear()
	grown = -1
	party = clampi(PartyScale.players() if players < 0 else players, 1, NetTransport.MAX_PLAYERS)
	for t in [template] + extras:
		if (t as EnemyTemplate).grow_after >= 0:
			grown = Run.custodian_jumps()
	var share := 1.0 if extras.is_empty() else 0.6
	enemies.append(_spawn(template, danger, share))
	for t in extras:
		enemies.append(_spawn(t as EnemyTemplate, danger, share))
	for i in enemies.size():
		enemies[i].look = look_for(i)
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

## The party's answer is the fight: a mismatched id rebuilds the foes (`replan_foes`)
## before any deal.
## Joined late: held hits play first, and a stunned ship is dealt nothing (PROTOCOL 18).
## Why: docs/why/Combat.md#party-answer-wins
func begin(f: SharedFight) -> void:
	if f != null:
		if f.foe_ids != _ids:
			replan_foes(templates_of(f.foe_ids))
		_attach(f)
	Sig.combat_started.emit(enemies[0].template.name)
	# COLD OPEN (science): heat off before the first hand, never below 0, and a
	# line only when it moved.
	if Run.has_routine(&"cold_open"):
		var was := Run.heat
		Run.heat = maxi(0, Run.heat - 4)
		if Run.heat != was:
			_log("Cold open. %d heat vented before the first shot." % (was - Run.heat), &"good")
			Sig.resources_changed.emit()
	if f != null and f.over:
		_settle_over(f)
		if finished:
			return
	if f != null:
		for row: Array in Net.take_held_swings(f.at):
			var which := int(row[1])
			if which >= 0 and which < enemies.size():
				_log("%s hit you as you arrived." % enemies[which].template.name, &"them")
			_on_swing(int(row[0]), which, int(row[2]), int(row[3]))
			if finished:
				return
		if f.stunned.has(Net.local_id()):
			stunned = true
			energy = 0
			_log("Stunned. You act after the enemy's turn.", &"them")
			Sig.turn_started.emit(turn)
			Sig.hand_changed.emit()
			Sig.player_combat_state_changed.emit()
			return
	begin_turn()


## Rebuilds only the enemy from templates; no deck shuffle or intent roll, so streams stay
## aligned.
func replan_foes(templates: Array) -> void:
	if templates.is_empty():
		return
	enemies.clear()
	current_target = null
	grown = -1
	var share := 1.0 if templates.size() == 1 else 0.6
	_ids = PackedStringArray()
	for t in templates:
		var tpl := t as EnemyTemplate
		if tpl.grow_after >= 0:
			grown = Run.custodian_jumps()
		enemies.append(_spawn(tpl, danger, share, false))
		_ids.append(String(tpl.id))
	for i in enemies.size():
		enemies[i].look = look_for(i)


## The templates behind a fight's ids, or empty if any is unknown here.
static func templates_of(ids: PackedStringArray) -> Array:
	var out: Array = []
	for id in ids:
		var t: EnemyTemplate = DB.enemies.get(StringName(id))
		if t == null:
			return []
		out.append(t)
	return out

## What this fight is made of, by database id, in enemy order. What the host is
## told so a ship arriving mid-fight can build the same hulls.
func foe_ids() -> PackedStringArray:
	return _ids

func foe_hp() -> PackedInt32Array:
	var out := PackedInt32Array()
	for e in enemies:
		out.append(e.max_hp)
	return out

## Current hull, not capacity: a hurt hellbender must start the party copy at the same
## number.
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

## Positional, never a fresh roll: every party machine draws the same ship with nothing on
## the wire.
## Why: docs/why/Combat.md#enemy-picture
func look_for(i: int) -> int:
	var n: MapGen.MapNode = Run.node_at()
	if n == null:
		return i
	var wrecks := 0
	for raw in n.jetsam:
		if (raw as MapGen.Jetsam).is_wreck():
			wrecks += 1
	return Rng.derive(&"look", (n.index * 64 + wrecks) * 8 + i).randi() & 0xffff

## Halved when danger went from 5 to 10 tiers, so the ladder top is unchanged and HP climbs
## 2x damage.
static func hp_mult_for(template: EnemyTemplate, danger: int) -> float:
	return 1.0 if template.boss or template.miniboss else 1.0 + (danger - 1) * 0.05

## A private copy with the intents scaled, so the template stays pristine. The host builds the same
## copy to grant a shared foe's block and heal (`NetSession._foe_acts`).
static func scaled_for(template: EnemyTemplate, danger: int) -> EnemyTemplate:
	var hp_mult := hp_mult_for(template, danger)
	var dmg_mult := 1.0 if template.boss or template.miniboss else 1.0 + (danger - 1) * 0.025
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
	return t

## HP scales faster than damage. Bosses are hand-tuned; the Custodian's hull grows with
## jumps.
## Why: docs/why/Combat.md#enemy-spawn-scaling
func _spawn(template: EnemyTemplate, danger: int, hp_share: float = 1.0, pick: bool = true) -> EnemyState:
	var e := EnemyState.new()
	var hand_tuned := template.boss or template.miniboss
	var hp_mult := hp_mult_for(template, danger)
	var t := scaled_for(template, danger)
	e.template = t
	var base := template.hull_at(Run.custodian_jumps()) if hand_tuned else template.max_hull
	# AND THE PARTY'S SIZE (Jon, Nov 5): every fight in an n-player game is
	# built for n, bosses too. 1 alone, so the solo numbers are untouched.
	e.max_hp = maxi(1, int(round(base * hp_mult * hp_share * PartyScale.hull(party))))
	e.hp = e.max_hp
	e.brace = int(round(template.brace * hp_mult))
	if pick:
		e.pick_intent()
	elif not t.pool.is_empty():
		e.intent = t.pool[0]
	elif not t.loop.is_empty():
		e.intent = t.loop[0]
	return e

## Nothing joins a fight (Jon, Oct 13). The old turn-3 wave of reinforcements was removed.
## Why: docs/why/Combat.md#no-reinforcements

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
	# CLEARED HERE, before anything can return: a charge that ends the fight
	# below leaves no first turn behind it either.
	var opening := _opening
	_opening = false
	# WARM START (science): one more energy on this ship's first turn only.
	if opening and Run.has_routine(&"warm_start"):
		energy += 1

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

	# FIRST LOOK (science): two more cards on this ship's first turn only.
	var first_look := 2 if opening and Run.has_routine(&"first_look") else 0
	draw_cards(maxi(0, Run.hand_size() - hand.size()) + first_look, true)

	for d in drones:
		var times := 2 if (Run.has_set(&"cygnet", 3) and d.fresh) else 1
		for i in times:
			damage_enemy(d.damage, 1, "Drone")
		d.fresh = false
	# A drone can kill the last foe: the fight is over, so nothing below may run.
	if finished:
		return
	if drone_brace > 0:
		brace += drone_brace
		_log("Shield wasps add %d brace." % drone_brace, &"good")

	for c in fired:
		_log("▸ %s detonates." % c.name, &"big")
		Sig.charge_fired.emit(c.name)
		resolving = c
		CardResolver.resolve(c, self, true)
		resolving = null
		# A charge firing can end the fight. Nothing after this point should run.
		if finished:
			return

	Sig.turn_started.emit(turn)
	Sig.hand_changed.emit()
	Sig.player_combat_state_changed.emit()

func end_turn() -> void:
	if finished or asking_at >= 0 or stunned:
		return
	# A choice cannot outlive its turn: `can_play` refuses all while one is pending, locking
	# the next turn.
	choosing = 0
	choose_kind = &""
	# Held malfunctions charge here, not on draw, which gives a turn to get rid of them.
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
		Sig.hull_burned.emit(stuck, &"junk")
		Run.take_hull_damage(stuck, "Malfunctions left too long broke the hull.", true)

	# Fused cards stay in hand so they charge you again until you spend something on them.
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
		brace_held += 1
		_log("+1 heat maintaining brace.", &"heat")

	# No end-of-turn shed: it was too small to plan around and fought the cards that want heat
	# high. Dissipation multiplies venting instead. Do not soften overheat to compensate.
	# Why: docs/why/Combat.md#no-end-of-turn-heat-shed

	# Overheat: predictable self-damage. Heat is a second health bar you spend.
	if _overheat():
		return

	if attacks_this_turn == 0:
		peaceful_turns += 1
	else:
		peaceful_turns = 0

	# Solo only: pacifying needs the whole room's behaviour, which means the host counting
	# quiet turns.
	# Why: docs/why/Combat.md#pacifying-fauna
	if enemy.template.fauna and peaceful_turns >= 2 and not is_shared():
		_pacify()
		return

	if is_shared():
		# The one blocking moment: the enemy is one object acting for several ships
		# (`SharedFight.end_turn`).
		waiting = true
		# The hand is empty after discard, and its panel holds the button that now says WAITING.
		Sig.hand_changed.emit()
		Sig.player_combat_state_changed.emit()
		Net.report_end_turn(shared_at)
		return

	_enemy_act()
	if finished:
		return
	# Block clears after the enemy swings. It used to clear before, so Block cards bought
	# nothing.
	# Why: docs/why/Combat.md#block-expiry
	block = 0
	turn += 1
	begin_turn()

## The end of a turn's overheat burn. True when it killed the ship (the fight
## is finished). Also run once when a stun clears, for the turn sat out.
func _overheat() -> bool:
	if Run.heat <= Run.heat_cap():
		return false
	var burn := Run.heat - Run.heat_cap()
	if Run.has_set(&"solari", 5):
		burn = int(ceil(burn / 2.0))
	_log("⚠ OVERHEAT: %d hull burned (%d/%d)." % [burn, Run.heat, Run.heat_cap()], &"heat")
	Sig.overheated.emit(burn)
	Sig.hull_burned.emit(burn, &"overheat")
	Run.take_hull_damage(burn, "The ship overheated and burned through its own hull.", true)
	if Run.dead:
		_finish(&"dead", Run.death_reason)
		return true
	return false

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
	# Enemy block expires as it acts again. At the function end it was granted and removed in
	# one call.
	# Why: docs/why/Combat.md#block-expiry
	if not is_shared():
		e.block = 0
	# Solo only: in a shared fight the host turns this intent into a fight end before any
	# swing.
	if I.escape and not is_shared():
		_log("◂ %s: %s" % [e.template.name, I.name], &"them")
		# its hull between fights is one ship's worth (`PartyScale.solo_hull`)
		Run.hellbender_breaks_off(PartyScale.solo_hull(e.hp, party))
		_finish(&"broke_off",
			"It makes a blind jump and gets away hurt. It mends as it feeds. No salvage.")
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
			Sig.combat_hit.emit(true, enemies.find(e), 0, 0, maxi(1, I.hits), maxi(1, I.hits))
		else:
			var total := 0
			var absorbed := 0
			var missed := 0
			for i in maxi(1, I.hits):
				var d := I.damage
				# Uses `Run.dodge()`, not `Run.hull.dodge`, so a Ghost Drive evades in the fight
				# too.
				if Rng.fight.randf() < Run.dodge():
					_log("  missed.", &"good")
					missed += 1
					continue
				if block > 0:
					var a := mini(block, d)
					block -= a
					d -= a
					absorbed += a
				if d > 0 and brace > 0:
					var a2 := mini(brace, d)
					brace -= a2
					d -= a2
					absorbed += a2
				total += d
			Sig.combat_hit.emit(true, enemies.find(e), total, absorbed, missed, maxi(1, I.hits))
			if total > 0:
				_log("  %d hull damage." % total, &"them")
				Sig.damage_dealt.emit(total, true, enemies.find(e))
				Run.take_hull_damage(total, "Enemy fire broke the hull open.", true)
			# Feedback ran before the death check, so a killing hit could win and lose at once
			# (`PlayerDeathTest`).
			# Why: docs/why/Combat.md#dead-ship-returns-no-fire
			if feedback > 0 and not Run.dead:
				damage_enemy(feedback, 1, "Feedback")
			if Run.dead:
				_finish(&"dead", Run.death_reason)
				return
	if is_shared():
		# Host's: block is shared and the next intent is an ordered `Rng.fight` stream, not
		# positional.
		return
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
	# Nothing is playable mid-choice, or two cards would resolve in an order neither stated.
	return not finished and asking_at < 0 and not stunned and choosing <= 0 \
		and energy >= c.energy and Run.credits >= c.credit_cost

## Choice takes a hand index so the sim and bot pick like the screen. Junk first, never
## random.
## Why: docs/why/Combat.md#default-choice
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
		resolving = c
		CardResolver.resolve(c, self, false)
		resolving = null
	Sig.card_played.emit(c)
	Sig.hand_changed.emit()
	Sig.player_combat_state_changed.emit()

## Mirrors CardResolver without mutating, per hit; drift would make the on-screen number a
## lie. Separate from `preview_damage` since mitigation depends on the target.
## Why: docs/why/Combat.md#card-output-preview
func card_output(c: CardData) -> int:
	if finished:
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
		if c.flashpoint > 0 and Run.heat > Run.heat_cap():
			per += c.flashpoint
		if c.adapt > 0:
			per += adapt_bonus
		if c.salvo > 0 and salvo_live(c):
			per += c.salvo
		# LOCK-ON IS INSIDE THE `elif`, deliberately and as it always was: a card
		# whose damage IS your heat does not also get the sight bonus.
		per += lock_on
	return per


## Reports only clauses actually contributing; lock-on is on the ship, so lighting SALVO
## would mislead.
## Why: docs/why/Combat.md#card-hot-clauses
func card_hot(c: CardData) -> PackedStringArray:
	var out := PackedStringArray()
	if c.damage <= 0:
		return out
	if c.heat_scale > 0 and int(Run.heat / c.heat_scale) > 0:
		out.append("Heat scaling")
	if c.flashpoint > 0 and Run.heat > Run.heat_cap():
		out.append("Flashpoint")
	if c.adapt > 0 and adapt_bonus > 0:
		out.append("Grows")
	if c.salvo > 0 and salvo_live(c):
		out.append("Salvo")
	return out


func preview_damage(c: CardData, target_index: int = -1) -> int:
	if finished:
		return 0
	var e := enemy
	if target_index >= 0 and target_index < enemies.size() and enemies[target_index].hp > 0:
		e = enemies[target_index]
	if e == null:
		return 0
	var per := card_output(c)
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

	# The shot is fired here, whatever fired it: drones and feedback hit without a played
	# card.
	struck = true

	var total := 0
	var absorbed := 0
	for i in maxi(1, hits):
		var d := amount
		if e.block > 0:
			var a := mini(e.block, d)
			e.block -= a
			d -= a
			absorbed += a
		if d > 0 and e.brace > 0:
			var a2 := mini(e.brace, d)
			e.brace -= a2
			d -= a2
			absorbed += a2
		e.hp -= d
		total += d
	var which := enemies.find(e)
	Sig.combat_hit.emit(false, which, total, absorbed, 0, maxi(1, hits))
	var who := "" if enemies.size() < 2 else " → %s" % e.template.name
	_log("%s%s → %d%s" % [label, who, total, "" if hits <= 1 else " (%d hits)" % hits], &"you")
	Sig.damage_dealt.emit(total, false, which)
	Sig.enemy_changed.emit()

	if is_shared():
		# Applied locally and sent, so your card reads as alone. The raw amount goes; the host
		# redoes mitigation.
		# Why: docs/why/Combat.md#shared-hits
		Net.hurt_foe(shared_at, which, amount, hits)
		# Death is not decided here: a client would pay itself for a kill the host has not seen.
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

## 1 of a 45 tank (Jon, Oct 17: "flee:A"), taken through the floor so a burn cannot strand
## you.
## Why: docs/why/Combat.md#flee-cost
const FLEE_FUEL := 1

## Hail rolls Stealth, as `inspection_sweep` does. It closes only once you shoot, not on
## other actions.
## Why: docs/why/Combat.md#hail-rules
var struck := false

const HAIL_ATTR := &"stealth"
const HAIL_NEED := 3

## A failed hail costs heat, never hull: a sneak costs detection, so a botch surprises in
## degree.
const HAIL_HEAT_PARTIAL := 6
const HAIL_HEAT_BOTCHED := 14


## Not fauna and not a boss (ruled). `hail_check` prints the odds the roll uses.
## Why: docs/why/Combat.md#hail-rules
func hail_check() -> Dictionary:
	return {attr = HAIL_ATTR, need = HAIL_NEED}


## One attempt, as with `flee_failed`: a repeatable check is eventually passed, and hail
## was louder.
## Why: docs/why/Combat.md#hail-rules
var hail_failed := false


## One definition: with five Korvan aboard salvo is unconditional, and the chip said
## otherwise.
## Why: docs/why/Combat.md#salvo-live
func salvo_live(c: CardData) -> bool:
	if attacks_this_turn > 0:
		return true
	return c.manufacturer == &"korvan" and Run.has_set(&"korvan", 5)


func can_hail() -> bool:
	if finished or waiting or stunned or asking_at >= 0 or enemies.is_empty():
		return false
	if struck or hail_failed:
		return false
	for e in enemies:
		var t: EnemyTemplate = (e as EnemyState).template
		if t.fauna or t.boss or t.miniboss:
			return false
	return true


## Separate from `hail_reason`: the button wants one word, the tooltip the cause.
func hail_cause() -> StringName:
	if enemies.is_empty():
		return &""
	if stunned:
		return &"stunned"
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


## Ruling 8: a disabled button states what it wants, so HAIL greyed with no reason does not
## read as a bug.
func hail_reason() -> String:
	if enemies.is_empty():
		return ""
	# One label (NO REPLY) for every shut door so it reads as one mechanic and fits the 68px
	# rail.
	# Why: docs/why/Combat.md#hail-button-label
	var why := hail_cause()
	# STUNNED keeps the button's name, greyed: the reason is in the tooltip,
	# and END TURN already says STUNNED (one word on three buttons is noise)
	if why == &"stunned":
		return "HAIL"
	return "" if why == &"" else "NO REPLY"


## Same exit as `flee` bought with words, without fuel. Failure is loud rather than
## damaging.
## Why: docs/why/Combat.md#hail-exit
func hail() -> void:
	if not can_hail():
		return
	var band := SkillCheck.roll(hail_check())
	match band:
		SkillCheck.Band.MET, SkillCheck.Band.CLEAN:
			Run.node_at().fled = true
			Sig.resources_changed.emit()
			_finish(&"hailed",
				"They listen, decide you are not worth a fight, and leave.")
		SkillCheck.Band.PARTIAL:
			Run.heat += HAIL_HEAT_PARTIAL
			Run.node_at().fled = true
			Sig.resources_changed.emit()
			_finish(&"hailed",
				"They break off slowly and scan you as they pass.")
		_:
			Run.heat += HAIL_HEAT_BOTCHED
			Sig.resources_changed.emit()
			hail_failed = true
			exit_note = "Your hail on an open channel gives away your position, and they take the turn. They will not answer another hail."
			Run.log_line(exit_note, &"heat")
			end_turn()


## One attempt: a repeatable flee check is eventually passed, so failing closes the door.
## Why: docs/why/Combat.md#flee-attempt
var flee_failed := false


## Not from the core guard. The hellbender is allowed: breaking off banks the damage you
## did.
## Why: docs/why/Combat.md#flee-eligibility
func can_flee() -> bool:
	if finished or waiting or stunned or asking_at >= 0 or flee_failed:
		return false
	for e in enemies:
		if (e as EnemyState).template.boss:
			return false
	return true


## What the button says when it cannot. Empty when it can.
func flee_reason() -> String:
	if stunned and not finished:
		return "FLEE"
	return "" if can_flee() else "NO ESCAPE"


## Which shut it, for the tooltip. Empty when open.
func flee_cause() -> StringName:
	if can_flee():
		return &""
	if stunned:
		return &"stunned"
	if flee_failed:
		return &"failed"
	return &"boss"


## Flee is a MANEUVER check against 4/6/8 by class; a purchase made it the safest button.
## Why: docs/why/Combat.md#flee-check
const FLEE_ATTR := &"maneuver"
const FLEE_NEED := 3

## The ugly version of getting away. Beyond `FLEE_FUEL`, not instead of it.
## 2 of 45 (was 10 of 279), through the same floor.
const FLEE_FUEL_PARTIAL := 2


## A failed hail or burn ends nothing, so `exit_note` tells the player what it cost.
## Why: docs/why/Combat.md#failed-exit-note
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
		Run.drain_fuel(FLEE_FUEL)
		Sig.resources_changed.emit()
		exit_note = "You commit to the burn and they are still on you when it ends."
		Run.log_line(exit_note, &"heat")
		end_turn()
		return
	# One number, named once. The line said 2 while the code took 6 — a
	# discrepancy the player pays and the log denies.
	var fuel0 := Run.fuel
	Run.drain_fuel(FLEE_FUEL)
	if band == SkillCheck.Band.PARTIAL:
		# Out, but the expensive way round. In domain: a burn costs fuel.
		Run.drain_fuel(FLEE_FUEL_PARTIAL)
	# What the burn really took: the floor can hold it under the price.
	var burned := fuel0 - Run.fuel
	# So the sector you are dropped back onto offers a jump rather than the
	# fight you just paid fuel to leave.
	Run.node_at().fled = true
	# The hellbender heals per move, so fleeing banks damage. Solo; the host writes it back in
	# a party.
	if not is_shared() and not enemies.is_empty() and enemies[0].template.miniboss:
		Run.hellbender_scarred(PartyScale.solo_hull(enemies[0].hp, party))
	Sig.resources_changed.emit()
	_finish(&"fled", "You burned %d fuel breaking contact. No salvage." % burned)

## Custodian body: two precursor parts, two branded legendaries and the instrument shadow
## (Jon, Oct 13). Positional like every wreck, so a party opens the same body.
## Why: docs/why/Combat.md#custodian-body-loot
const CORE_PRECURSOR := 2
const CORE_LEGENDARY := 2
const CORE_PARTS := CORE_PRECURSOR + CORE_LEGENDARY
const CORE_TRIES := 300

static func core_body(node: MapGen.MapNode, t: EnemyTemplate) -> MapGen.Jetsam:
	var wrecks_before := 0
	for raw in node.jetsam:
		if (raw as MapGen.Jetsam).is_wreck():
			wrecks_before += 1
	var r := Rng.derive(&"wreck", node.index * 64 + wrecks_before)
	var h := Run.new_wreck(node, t)
	var have: Array[StringName] = []
	for i in CORE_PARTS:
		var precursor := i < CORE_PRECURSOR
		var best: ModuleData = null
		for k in CORE_TRIES:
			var m := LootGen.roll_module(MapGen.DANGER_MAX, &"", precursor, r)
			if m.id in have:
				continue
			var fits := m.rarity == ModuleData.Rarity.ARTIFACT if precursor \
				else (m.rarity == ModuleData.Rarity.LEGENDARY and m.manufacturer != &"")
			if fits:
				best = m
				break
			if best == null or m.rarity > best.rarity:
				best = m
		if best == null:
			best = LootGen.roll_module(MapGen.DANGER_MAX, &"", precursor, r)
		have.append(best.id)
		h.items.append(best)
	var row := MaterialTable.by_id(&"custodian_shadow")
	if not row.is_empty():
		h.items.append(MaterialData.of(row))
	return h

## Each wreck is rolled on its own (Jon, Oct 13), positionally by place. In a party its purse,
## parts and exotic are multiplied by `PartyScale.loot` of the fight's players (Nov 5).
## Why: docs/why/Combat.md#wreck-contents
const WRECK_CREDIT_CHANCE := 0.75
const WRECK_CREDIT_SPREAD := 0.20
## `WRECK_CREDIT_SCALE` 1.27 is measured with `-- sim runs=200 seed=777` to hold money per
## run at 92.
## Why: docs/why/Combat.md#wreck-credit-scale
const WRECK_CREDIT_SCALE := 1.27
## Parts one hand can expect from a hull of each kind. The tuning table: an
## enemy missing from it gets `WRECK_PARTS_DEFAULT`.
const WRECK_PARTS := {
	&"cutter": 0.95,
	&"lancer": 1.0,
	&"hulk": 1.15,
	&"marauder": 1.15,
	&"sentinel": 1.3,
}
const WRECK_PARTS_DEFAULT := 1.0
const WRECK_LAWLESS := 2.0
const HELLBENDER_PARTS := 3
const FAUNA_EXOTIC := 2

## A ship's purse before the chance and the spread: its reward at this danger.
static func wreck_purse(t: EnemyTemplate, danger: int, probate: bool = false) -> float:
	var base := t.credit_reward * (1.0 + (danger - 1) * 0.2)
	if not (t.boss or t.miniboss):
		base *= WRECK_CREDIT_SCALE
	return base * 1.5 if probate else base

## The chance a wreck of this kind holds money at all.
static func wreck_credit_chance(t: EnemyTemplate) -> float:
	if t.credit_reward <= 0:
		return 0.0
	return 1.0 if (t.boss or t.miniboss) else WRECK_CREDIT_CHANCE

## The parts one hand can expect from a wreck of this kind, here.
static func wreck_parts(t: EnemyTemplate, region: MapGen.Region) -> float:
	if t.fauna or region == MapGen.Region.FAUNA:
		return 0.0
	if t.miniboss:
		return float(HELLBENDER_PARTS)
	var per: float = WRECK_PARTS.get(t.id, WRECK_PARTS_DEFAULT)
	return per * WRECK_LAWLESS if region == MapGen.Region.LAWLESS else per

## Pure: the same node, kind, index and hands give the same items on every machine.
## `loot` is the party's pay multiplier (`PartyScale.loot`); 1 alone, the roll it always was.
static func roll_wreck(node: MapGen.MapNode, t: EnemyTemplate, index: int,
		loot: float = 1.0, probate: bool = false, calyx: bool = false) -> Array[HoldItem]:
	var r := Rng.derive(&"wreck", node.index * 64 + index)
	var out: Array[HoldItem] = []
	# Both drawn every time, so the parts below sit at the same place in the
	# stream whether or not there was money.
	var pays := r.randf() < wreck_credit_chance(t)
	var swing := r.randf_range(-WRECK_CREDIT_SPREAD, WRECK_CREDIT_SPREAD)
	if pays:
		var purse := wreck_purse(t, node.danger, probate)
		if not (t.boss or t.miniboss):
			purse *= 1.0 + swing
		out.append(CreditChit.of(maxi(1, int(round(purse * maxf(1.0, loot))))))
	# ONE ROLL OF THE PARTY'S PARTS, not one per hand: the expected count is the
	# kind's times the multiplier, and a single ship's roll is the old one
	var per := wreck_parts(t, node.region) * maxf(1.0, loot)
	var force := node.manufacturer if node.region == MapGen.Region.TERRITORY else &""
	var deep := node.region == MapGen.Region.DEEP
	var n := int(per)
	if r.randf() < per - n:
		n += 1
	for i in n:
		out.append(LootGen.roll_module(node.danger, force, deep, r))
	if t.fauna:
		var row := MaterialTable.by_id(&"exotic")
		if not row.is_empty():
			for i in int(round((FAUNA_EXOTIC + (1 if calyx else 0)) * maxf(1.0, loot))):
				out.append(MaterialData.of(row))
	return out

## How many players the last won fight paid its wrecks for (`party`). Read by
## the co-op harness, which cannot see `shared` once the fight has let go of it.
var wreck_hands: int = 1

func _victory() -> void:
	Run.kills += 1
	var node: MapGen.MapNode = Run.node_at()
	var probate := Run.has_set(&"probate", 3)
	for i in new_dross:
		var which: StringName = named_dross[i] if i < named_dross.size() else &""
		Run.add_dross(danger, which)
	if Run.has_set(&"calyx", 3):
		Run.heal(3)
	_patch_crew()
	if clears_node:
		Run.consume_node(node)
	# And anybody who paid to have this stop moving.
	Run.clear_contract_target(node.index)

	# Asked of every hull, not just `enemy`.
	var boss: EnemyState = null
	var set_piece := false
	for e in enemies:
		if e.template.boss:
			boss = e
		if e.template.miniboss:
			set_piece = true

	if boss != null:
		# Credits go straight to the ledger: a chit left in the body would be money the summary
		# never saw.
		Run.add_credits(int(round(wreck_purse(boss.template, node.danger, probate))))
		# The boss body is looted before the run ends (Jon, Oct 12). The win is recorded at the
		# kill.
		# Why: docs/why/Combat.md#custodian-win
		Combat.core_body(node, boss.template)
		Run.win()
		_finish(&"won", "The core opens.")
		return

	# The roamer stops roaming -- idempotent, because in a party every crew
	# machine runs this and the host may have run it already in _apply_hurt().
	if set_piece:
		Run.hellbender_defeated()

	# One way to be paid: wrecks. Solo `Run.stow` lost rewards on a full hold. Rolled
	# positionally, not by seat.
	# Why: docs/why/Combat.md#wreck-payout
	# Paid for the players in the game, the count the fight was built for, not the ships in it.
	var hands := maxi(1, party)
	wreck_hands = hands
	var calyx := Run.has_set(&"calyx", 5)
	var wrecks_before := 0
	for raw in node.jetsam:
		if (raw as MapGen.Jetsam).is_wreck():
			wrecks_before += 1
	var credits := 0
	var parts := 0
	var exotic := 0
	var empty := 0
	for i in enemies.size():
		var e: EnemyState = enemies[i]
		var h := Run.new_wreck(node, e.template, e.look)
		var got := roll_wreck(node, e.template, wrecks_before + i, PartyScale.loot(hands), probate, calyx)
		h.items.append_array(got)
		if got.is_empty():
			empty += 1
		for m in got:
			if m is CreditChit:
				credits += (m as CreditChit).amount
			elif m is ModuleData:
				parts += 1
			elif m is MaterialData:
				exotic += 1
	var bits: PackedStringArray = [wreck_line(credits, parts, exotic, enemies.size(), empty)]
	if new_dross > 0:
		bits.append("%d Dross" % new_dross)
	_finish(&"victory", " · ".join(bits))

## The money is in the wrecks, not yet in your account, so the line says where it is.
static func wreck_line(credits: int, parts: int, exotic: int, wrecks: int, empty: int) -> String:
	var held := PackedStringArray()
	if credits > 0:
		held.append("%d credits" % credits)
	if parts > 0:
		held.append("%d part%s" % [parts, "" if parts == 1 else "s"])
	if exotic > 0:
		held.append("%d exotic" % exotic)
	if held.is_empty():
		return "The wreck is empty" if wrecks <= 1 else "The wrecks are empty"
	var listed := held[0]
	if held.size() == 2:
		listed = "%s and %s" % [held[0], held[1]]
	elif held.size() > 2:
		listed = "%s, %s and %s" % [held[0], held[1], held[2]]
	var line := "%s in the wreck%s" % [listed, "" if wrecks <= 1 else "s"]
	if wrecks > 1 and empty > 0:
		line += " · %d wreck%s empty" % [empty, " is" if empty == 1 else "s are"]
	return line

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
	_patch_crew()
	_finish(&"pacified",
		"It stops circling and drifts off, singing. You get 1 exotic material.")

## PATCH CREW (science): 3 hull mended after a fight won or pacified, on top of
## Calyx's 3, never past full. Not after a flee.
func _patch_crew() -> void:
	if Run.has_routine(&"patch_crew"):
		var got := Run.heal(3)
		if got > 0:
			_log("Patch crew. %d hull mended." % got, &"good")

func _finish(res: StringName, text: String) -> void:
	finished = true
	waiting = false
	# Leave the crew however the fight ended, or a stale entry blocks the barrier for
	# everyone.
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
	# Adopt the hit serial, not zero, so a joiner does not draw a shot that landed before it
	# came.
	_seen_hit = f.hit_serial
	# Adopt the turn number, or catching up would run `begin_turn()` six times in one push.
	turn = f.turn
	# And so is its count: the host may have grown it past this machine's
	# before anybody saw it (`NetSession._open_or_join`), which is no news
	if f.grown >= 0:
		grown = f.grown
	# and the players its hull was built for, which its wrecks pay
	party = f.party
	# nobody already here is announced (`_say_joins`)
	_last_crew = f.crew.duplicate()
	Sig.party_fight_changed.connect(_on_fight_changed)
	Sig.party_fight_swing.connect(_on_swing)
	# Losing the host mid-fight must not be a softlock. See _on_party_lost().
	Sig.party_failed.connect(_on_party_lost)
	_adopt(f)


## Public because abandoning mid-turn leaves a dead Combat still reacting on the signal
## bus.
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
	stunned = false


## Menu exits (review, Nov 5) must leave the crew and the signal bus, or partners wait on a
## ghost. Let go before the leave: the host handles it at once and can move the turn.
## Why: docs/why/Combat.md#leaving-mid-fight
func abandon() -> void:
	var at := shared_at
	var leave := is_shared() and not finished
	release()
	if leave:
		Net.leave_fight(at)


## The name of the first live foe whose hull grows from count `from` to `to`
## (`EnemyTemplate.hull_at`), or "" when none does.
func _grew_between(from: int, to: int) -> String:
	for e in enemies:
		var t := e.template
		if e.hp > 0 and t != null and t.grow_after >= 0 and t.hull_at(to) > t.hull_at(from):
			return t.name
	return ""


## Only numbers cross (hull, block, brace, intent index). Templates and art are built
## identically.
## Why: docs/why/Combat.md#adopting-host-state
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
	# The host grew the boss (Jon, Nov 4); said only when a live hull really grows between
	# counts.
	if grown >= 0 and f.grown > grown:
		var who := _grew_between(grown, f.grown)
		grown = f.grown
		if who != "":
			_log("%s grows stronger." % who, &"them")
	# A partner's card played elsewhere, drawn here or their hits land silently.
	if f.last_hit.size() == 4 and f.hit_serial > _seen_hit:
		_seen_hit = f.hit_serial
		var by := f.last_hit[0]
		if by != Net.local_id():
			var who := Net.name_of(by)
			_log("%s → %d" % [who.to_upper() if who != "" else "PARTNER",
				f.last_hit[2]], &"good")
			Sig.damage_dealt.emit(f.last_hit[2], false, f.last_hit[1])
			Sig.combat_hit.emit(false, f.last_hit[1], f.last_hit[2], 0, 0, 1)
	Sig.enemy_changed.emit()


## The host said something moved.
func _on_fight_changed(at: int) -> void:
	if at != shared_at or finished:
		return
	var f := Net.fight_at(at)
	if f == null:
		return
	shared = f
	_say_joins(f)
	_adopt(f)
	if f.over:
		_settle_over(f)
		return
	# The turn number IS the "everybody go again" message.
	if f.turn > turn:
		# After the swing, never before. Same ordering the solo path has kept
		# since the bug that zeroed Block on the way INTO the enemy's turn.
		block = 0
		turn = f.turn
		waiting = false
		# THE STUN ENDS WITH THE ENEMY'S TURN: the hand comes now, and the
		# overheat check runs once for the turn sat out (no cards, so only heat
		# carried in can burn)
		if stunned:
			stunned = false
			_log("Your turn.", &"good")
			if _overheat():
				return
		begin_turn()


## A partner walked into this fight: said once, on this machine, from the
## crew this ship last saw (`_last_crew`, set as it attached, so the ships
## already here when it arrived are not announced) and the fight's stun list.
## Nothing extra on the wire.
func _say_joins(f: SharedFight) -> void:
	var me := Net.local_id()
	for p in f.crew:
		if p == me or _last_crew.has(p):
			continue
		var who := Net.name_of(p)
		who = who.to_upper() if who != "" else "A PARTNER"
		if f.stunned.has(p):
			_log("%s joins the fight, stunned until the enemy's turn is over." % who, &"good")
		else:
			_log("%s joins the fight." % who, &"good")
	_last_crew = f.crew.duplicate()


## The party's fight is over: end this one the way it ended. From a push, or
## from `begin` when the answer to the ask came back already over.
func _settle_over(f: SharedFight) -> void:
	# The hellbender left before anybody killed it. The host has already moved
	# it and written its hull back; this machine only has to stop fighting.
	if f.broke:
		_finish(&"broke_off",
			"It makes a blind jump and gets away hurt. It mends as it feeds. No salvage.")
		return
	# The host decides the win; everyone in the fight at the last kill is paid.
	if alive().is_empty():
		_victory()


## On a lost party the fight becomes solo, left at party scale, since stranding it would
## softlock.
## Why: docs/why/Combat.md#party-lost
func _on_party_lost(_reason: String) -> void:
	if finished or not is_shared():
		return
	_log("The convoy channel is gone. You are on your own.", &"them")
	# stunned is waiting too: the enemy's turn it was sitting out is taken here
	var was_waiting := waiting or stunned
	release()
	if was_waiting:
		# Mid-barrier drop: take the enemy turn it was waiting for, so the fight does not stall.
		_enemy_act()
		if finished:
			return
		block = 0
		turn += 1
		begin_turn()
	Sig.player_combat_state_changed.emit()
	Sig.hand_changed.emit()


## Resolved locally against your own dodge, block, brace and hull: those exist nowhere
## else.
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
