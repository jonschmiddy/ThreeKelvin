extends Node

## Every set bonus does what its text says, from a used run: `-- sheet=SetBonusTest`.
## Why: docs/why/SetBonusTest.md#the-promise

var _fails := 0

const SEED := 5151

## The text each check below proves. A changed text fails here until its check is
## changed to match (or the code is).
const TEXTS: Array = [
	[&"korvan", 3, "After a turn where you fire nothing, you start with 1 more energy."],
	[&"korvan", 5, "When a charge shot fires, you get 2 more energy that turn."],
	[&"solari", 3, "Solari attacks deal 2 more damage per hit."],
	[&"solari", 5, "Overheat damage halved."],
	[&"probate", 3, "+50% credits from wrecks."],
	[&"probate", 5, "Brace cards give +2."],
	[&"redline", 3, "Draw 1 extra card each turn."],
	[&"redline", 5, "First enemy attack each combat is negated."],
	[&"verity", 3, "Verity cards cost 1 less energy."],
	[&"verity", 5, "1 extra energy every turn."],
	[&"cygnet", 3, "A drone attacks twice the first time it attacks."],
	[&"cygnet", 5, "Up to 3 attack drones stay out into the next fight."],
	[&"calyx", 3, "Mend 3 hull after every fight you win."],
	[&"calyx", 5, "Each creature you kill leaves 1 more exotic material."],
]


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	print("-- the texts")
	_texts()
	print("-- korvan")
	_korvan_3()
	_korvan_5()
	_feed()
	_shared_stamp()
	print("-- solari")
	_solari_3()
	_solari_5()
	print("-- probate")
	_probate_3()
	_probate_5()
	print("-- redline")
	_redline_3()
	_redline_5()
	print("-- verity")
	_verity_3()
	_verity_5()
	print("-- cygnet")
	_cygnet_3()
	_cygnet_5()
	print("-- calyx")
	_calyx_3()
	_calyx_5()
	print("setbonustest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	get_tree().quit(1 if _fails > 0 else 0)


# ------------------------------------------------------------------- helpers

## A used run: the kit fitted, 9 hull down, some heat, then `n` parts of `id`
## (the hull counts as one; 0 is no set at all).
func _used(id: StringName, n: int, at_seed := SEED) -> void:
	Rng.forced = at_seed
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.hp = maxi(1, Run.max_hp() - 9)
	Run.heat = 5
	while Run.installed.size() < 5:
		Run.installed.append((DB.modules[&"plate"] as ModuleData).duplicate(true))
	Run.hull.manufacturer = id if n > 0 else &""
	for i in Run.installed.size():
		Run.installed[i].manufacturer = id if i < n - 1 else &""
	Sig.ship_changed.emit()


func _fight(enemy: StringName = &"cutter") -> Combat:
	var cb := Combat.new()
	cb.plan(DB.enemies[enemy], 1)
	cb.begin(null)
	_soak(cb)
	return cb


## The foe soaks anything without dying, armour off.
func _soak(cb: Combat) -> void:
	for e in cb.enemies:
		e.max_hp = 9999
		e.hp = 9999
		e.brace = 0
		e.block = 0


func _card(who: StringName, fields: Dictionary) -> CardData:
	var c := CardData.new()
	c.name = "Test %s" % who
	c.manufacturer = who
	c.energy = 0
	for k in fields:
		c.set(k, fields[k])
	return c


## Plays `c` and returns the damage the foe took.
func _play(cb: Combat, c: CardData) -> int:
	_soak(cb)
	cb.energy = 9
	cb.hand.insert(0, c)
	var hp0 := cb.enemies[0].hp
	cb.play(0)
	return hp0 - cb.enemies[0].hp


func _exotic_in(items: Array) -> int:
	var n := 0
	for m in items:
		if m is MaterialData and (m as MaterialData).id == &"exotic":
			n += 1
	return n


func _credits_in(items: Array) -> int:
	var n := 0
	for m in items:
		if m is CreditChit:
			n += (m as CreditChit).amount
	return n


## What a won fight left in the new wrecks: [credits, exotic].
func _won(cb: Combat) -> Array:
	var node: MapGen.MapNode = Run.node_at()
	var before := node.jetsam.size()
	cb._victory()
	var items: Array = []
	for i in range(before, node.jetsam.size()):
		items.append_array((node.jetsam[i] as MapGen.Jetsam).items)
	return [_credits_in(items), _exotic_in(items)]


# ------------------------------------------------------------------- checks

func _texts() -> void:
	for row: Array in TEXTS:
		var m: ManufacturerData = DB.manufacturers[row[0]]
		var said: String = m.set3_text if row[1] == 3 else m.set5_text
		_ok("%s %d says \"%s\"" % [row[0], row[1], row[2]], said == row[2])
	_ok("every manufacturer's two bonuses have a check", TEXTS.size() == DB.manufacturers.size() * 2)


func _korvan_3() -> void:
	for on in [false, true]:
		_used(&"korvan", 3 if on else 2)
		var cb := _fight()
		cb.peaceful_turns = 1
		cb.begin_turn()
		var quiet := cb.energy
		cb.peaceful_turns = 0
		cb.begin_turn()
		_ok("after a quiet turn %d energy, after a shot %d, %s" % [quiet, cb.energy, "set" if on else "no set"],
			quiet == Run.reactor() + (1 if on else 0) and cb.energy == Run.reactor())
		_play(cb, _card(&"korvan", {damage = 10, charge_turns = 1}))
		_ok("a 1-turn charge still waits its turn", cb.charging.size() == 1 and cb.charging[0].turns_left == 1)


func _korvan_5() -> void:
	for on in [false, true]:
		_used(&"korvan", 5 if on else 4)
		var cb := _fight()
		_play(cb, _card(&"korvan", {damage = 10, charge_turns = 1}))
		_play(cb, _card(&"solari", {damage = 10, charge_turns = 1}))
		cb.peaceful_turns = 0
		cb.begin_turn()
		_ok("a Korvan and a Solari charge land, %s: %d energy" % ["set" if on else "no set", cb.energy],
			cb.energy == Run.reactor() + (2 if on else 0))
		var c := _card(&"korvan", {damage = 2, salvo = 3})
		var cb2 := _fight()
		var hit := _play(cb2, c)
		_ok("the first attack gets no Salvo, %s: %d" % ["set" if on else "no set", hit], hit == 2)


## Feed (salvo, no damage) is not an attack; every gun gets its Salvo until next turn ends.
func _feed() -> void:
	_used(&"korvan", 2)
	var cb := _fight()
	_play(cb, _card(&"", {salvo = 2}))
	_ok("Feed is not an attack", cb.attacks_this_turn == 0)
	cb.turn += 1
	cb.begin_turn()
	_play(cb, _card(&"", {damage = 1}))
	var gun := _card(&"", {damage = 1, hits = 2})
	var preview := cb.card_output(gun)
	var hit := _play(cb, gun)
	_ok("next turn a gun with no Salvo of its own gets 2 a hit: %d (shown %d a hit)" % [hit, preview],
		hit == 6 and preview == 3)
	cb.turn += 1
	cb.begin_turn()
	_play(cb, _card(&"", {damage = 1}))
	_ok("and the turn after, it is gone", _play(cb, _card(&"", {damage = 1, hits = 2})) == 2)


## A shared card counts as its part's for the rules but is drawn unbranded (Jon, Oct 18).
func _shared_stamp() -> void:
	var slug: CardData = null
	for c in (DB.modules[&"kh20"] as ModuleData).resolved_cards():
		if (c as CardData).shared:
			slug = c
	_ok("the Chatterbox grants a shared card", slug != null)
	if slug == null:
		return
	_ok("its shared card is Korvan's for the rules (%s)" % slug.manufacturer, slug.manufacturer == &"korvan")
	_ok("and drawn unbranded, common", slug.look_manufacturer() == &"" and slug.source_rarity == 0)


func _solari_3() -> void:
	for on in [false, true]:
		_used(&"solari", 3 if on else 2)
		Run.heat = 0
		var cb := _fight()
		var add := 2 if on else 0
		var rows := [
			["a plain Solari hit", _card(&"solari", {damage = 4}), 4 + add],
			["a Solari heat-scaling hit", _card(&"solari", {damage = 4, heat_scale = 3}), 4 + add],
			["a Solari three-hit card", _card(&"solari", {damage = 2, hits = 3}), 3 * (2 + add)],
			["a Solari damage-from-heat card", _card(&"solari", {damage_equals_heat = true}), 2 + add],
			["a Korvan hit", _card(&"korvan", {damage = 4}), 4],
		]
		for row: Array in rows:
			var c: CardData = row[1]
			var per := cb.card_output(c)
			var hit := _play(cb, c)
			_ok("%s, %s: %d (want %d, shown %d a hit)" % [row[0], "set" if on else "no set", hit, row[2], per],
				hit == row[2] and per * maxi(1, c.hits) == hit)


func _solari_5() -> void:
	for on in [false, true]:
		_used(&"solari", 5 if on else 4)
		var cb := _fight()
		Run.heat = Run.heat_cap() + 6
		var hp0 := Run.hp
		cb._overheat()
		_ok("6 over the cap, %s: %d burned" % ["set" if on else "no set", hp0 - Run.hp],
			hp0 - Run.hp == (3 if on else 6))


func _probate_3() -> void:
	var paid := [0, 0]
	# A wreck pays by chance, so find a seed whose wreck holds money.
	for s in 12:
		for on in [false, true]:
			_used(&"probate", 3 if on else 2, SEED + s)
			var got := _won(_fight())
			paid[1 if on else 0] = got[0]
		if paid[0] > 0:
			break
	_ok("a wreck's credits, no set %d, set %d (half again, to a credit)" % [paid[0], paid[1]],
		paid[0] > 0 and absf(paid[1] - paid[0] * 1.5) <= 1.0)


func _probate_5() -> void:
	for on in [false, true]:
		_used(&"probate", 5 if on else 4)
		var cb := _fight()
		var b0 := cb.brace
		_play(cb, _card(&"probate", {brace = 3}))
		_ok("Brace 3, %s: +%d" % ["set" if on else "no set", cb.brace - b0], cb.brace - b0 == (5 if on else 3))


func _redline_3() -> void:
	var hands := [0, 0]
	for on in [false, true]:
		_used(&"redline", 3 if on else 2)
		var cb := _fight()
		hands[1 if on else 0] = cb.hand.size()
		cb.hand.clear()
		cb.begin_turn()
		_ok("turn 2's hand is the hand size (%d)" % cb.hand.size(), cb.hand.size() == Run.hand_size())
	_ok("one more card a turn with the set (%d, %d)" % [hands[0], hands[1]], hands[1] == hands[0] + 1)


func _redline_5() -> void:
	for on in [false, true]:
		_used(&"redline", 5 if on else 4)
		var cb := _fight()
		cb.brace = 0
		cb.block = 0
		var e: Combat.EnemyState = cb.enemies[0]
		var hit := IntentData.new()
		hit.name = "TEST"
		hit.damage = 7
		e.intent = hit
		_ok("the first attack is waiting to be negated: %s" % on, cb.negate_next == on)
		if on:
			var hp0 := Run.hp
			cb._act_one(e)
			_ok("the first attack takes nothing (%d)" % (hp0 - Run.hp), Run.hp == hp0 and not cb.negate_next)


func _verity_3() -> void:
	for on in [false, true]:
		# Mark I is a Verity part too: 2 + 1 is the set, 1 + 1 is not.
		_used(&"verity", 2 if on else 1)
		Run.installed.append((DB.modules[&"markone"] as ModuleData).duplicate(true))
		var base := {}
		for m in Run.installed:
			for c in m.resolved_cards():
				base[c.name] = c.energy
		var checked := 0
		var right := true
		for c in DeckBuilder.build():
			if c.manufacturer == &"verity" and base.has(c.name) and int(base[c.name]) > 0:
				checked += 1
				right = right and c.energy == int(base[c.name]) - (1 if on else 0)
		_ok("%d Verity cards cost %s" % [checked, "1 less" if on else "what they say"], checked > 0 and right)


func _verity_5() -> void:
	var seen := []
	for on in [false, true]:
		_used(&"verity", 5 if on else 4)
		var cb := _fight()
		var first := cb.energy
		cb.begin_turn()
		seen.append([first, cb.energy])
	_ok("energy on turns 1 and 2, no set %s, set %s" % [seen[0], seen[1]],
		seen[1][0] == seen[0][0] + 1 and seen[1][1] == seen[0][1] + 1)


func _cygnet_3() -> void:
	for on in [false, true]:
		_used(&"cygnet", 3 if on else 2)
		var cb := _fight()
		_play(cb, _card(&"cygnet", {drone_damage = 5}))
		_soak(cb)
		cb.begin_turn()
		var first := 9999 - cb.enemies[0].hp
		_soak(cb)
		cb.begin_turn()
		var second := 9999 - cb.enemies[0].hp
		_ok("a drone's first and second attacks, %s: %d, %d" % ["set" if on else "no set", first, second],
			first == (10 if on else 5) and second == 5)


func _cygnet_5() -> void:
	for on in [false, true]:
		_used(&"cygnet", 5 if on else 4)
		var cb := _fight()
		for dmg in [2, 5, 4, 3]:
			_play(cb, _card(&"cygnet", {drone_damage = dmg}))
		cb._victory()
		var next := _fight()
		var kept: Array[int] = []
		var fresh := false
		for d in next.drones:
			kept.append(d.damage)
			fresh = fresh or d.fresh
		if on:
			_ok("the three strongest drones are out at the next fight's start: %s" % str(kept),
				kept == [5, 4, 3] and not fresh)
			_soak(next)
			next.begin_turn()
			_ok("and attack once each (%d)" % (9999 - next.enemies[0].hp), 9999 - next.enemies[0].hp == 12)
			next._finish(&"dead", "test")
			_ok("a ship that died keeps none", Run.hive_drones.is_empty())
		else:
			_ok("without the set the next fight starts with none: %s" % str(kept), kept.is_empty())
	# Kept, then the set broken before the next fight: none come out.
	_used(&"cygnet", 5)
	var cb2 := _fight()
	_play(cb2, _card(&"cygnet", {drone_damage = 3}))
	cb2._victory()
	_ok("one drone kept", Run.hive_drones.size() == 1)
	Run.hull.manufacturer = &""
	Sig.ship_changed.emit()
	_ok("the set broken, the next fight starts with none", _fight().drones.is_empty())


func _calyx_3() -> void:
	for on in [false, true]:
		_used(&"calyx", 3 if on else 2)
		Run.hp = Run.max_hp() - 10
		var hp0 := Run.hp
		_fight()._victory()
		_ok("a fight won, %s: +%d" % ["set" if on else "no set", Run.hp - hp0], Run.hp - hp0 == (3 if on else 0))


func _calyx_5() -> void:
	var got := [0, 0]
	for on in [false, true]:
		_used(&"calyx", 5 if on else 4)
		got[1 if on else 0] = _won(_fight(&"whale"))[1]
	_ok("a creature killed leaves %d exotic, %d with the set" % [got[0], got[1]],
		got[0] == Combat.FAUNA_EXOTIC and got[1] == got[0] + 1)
