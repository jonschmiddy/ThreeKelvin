extends Node

## EACH WRECK HOLDS ITS OWN SHIP'S LOOT (Jon, Oct 13: "Each ship you kill has a
## chance to get credits and modules and other parts").
##   godot --headless --path . -- sheet=WreckLootTest
##
## Five claims, each one a way the per-wreck roll could quietly be wrong:
##   - a won fight's wrecks each hold what THEIR OWN template rolls at their own
##     place, and the victory line says what they hold;
##   - the credit chance and the amount stay inside their bounds over thousands
##     of wrecks, the Hellbender always pays its number, fauna pay exotic and no
##     money, and the parts follow the table (bigger hulls more, lawless double);
##   - a two-ship fight pays about the sum of its two ships, not the last one's;
##   - two machines in a party, on different seats with their streams at
##     different places, roll every wreck identically, sized for the crew;
##   - a save keeps every wreck's contents, and what was taken out of it.

var h := Harness.new()

const SHIPS: Array[StringName] = [&"cutter", &"lancer", &"hulk", &"marauder", &"sentinel"]


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	h.seed_run(5150)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	_bounds()
	_own_template()
	_pair_sum()
	_coop()
	_save()
	h.verdict("wreckloottest")
	get_tree().quit(h.code())


## Every system a fight can happen at, in map order.
func _systems() -> Array[MapGen.MapNode]:
	var out: Array[MapGen.MapNode] = []
	for n: MapGen.MapNode in Run.map:
		if n.type == MapGen.NodeType.SYSTEM:
			out.append(n)
	return out


func _wrecks(n: MapGen.MapNode) -> Array[MapGen.Jetsam]:
	var out: Array[MapGen.Jetsam] = []
	for raw in n.jetsam:
		if (raw as MapGen.Jetsam).is_wreck():
			out.append(raw)
	return out


## One item, as text two machines (or a save) can be compared by.
static func _say(m: Variant) -> String:
	if m is CreditChit:
		return "cr:%d" % (m as CreditChit).amount
	if m is MaterialData:
		return "mat:%s" % (m as MaterialData).id
	var mod := m as ModuleData
	var affixes := PackedStringArray()
	for a in mod.affixes:
		affixes.append(String(a.name))
	return "%s/%d/%d/%s" % [mod.id, mod.rarity, mod.scrap_value, ",".join(affixes)]


static func _says(items: Array) -> PackedStringArray:
	var out := PackedStringArray()
	for m in items:
		out.append(_say(m))
	return out


static func _credits(items: Array) -> int:
	var c := 0
	for m in items:
		if m is CreditChit:
			c += (m as CreditChit).amount
	return c


static func _parts(items: Array) -> int:
	var c := 0
	for m in items:
		if m is ModuleData:
			c += 1
	return c


## Win a fight at `n` against `lead` and `extras` through the real fight: every
## hull shot to nothing, `_victory` from the last shot. Returns the fight.
func _win(n: MapGen.MapNode, lead: StringName, extras: Array[StringName] = []) -> Combat:
	Run.at = n.index
	var more: Array = []
	for id in extras:
		more.append(DB.enemies[id])
	var cb := Combat.new()
	cb.start(DB.enemies[lead], n.danger, more)
	for e in cb.enemies:
		cb.damage_enemy(9999, 1, "test", e)
	return cb


## The chance, the amount, the set pieces, fauna, and the parts table.
func _bounds() -> void:
	var nodes := _systems()
	var plain: Array[MapGen.MapNode] = []
	var lawless: Array[MapGen.MapNode] = []
	for n in nodes:
		if n.region == MapGen.Region.LAWLESS:
			lawless.append(n)
		elif n.region != MapGen.Region.FAUNA:
			plain.append(n)
	h._ok("the galaxy has ordinary and lawless systems to roll at (%d, %d)"
		% [plain.size(), lawless.size()], plain.size() >= 40 and lawless.size() >= 5)
	var mean_parts := {}
	for id in SHIPS:
		var t: EnemyTemplate = DB.enemies[id]
		var rolls := 0
		var paid := 0
		var outside := 0
		var ratio_sum := 0.0
		var lo := 9.0
		var hi := 0.0
		var parts := 0
		for n in plain:
			var purse := Combat.wreck_purse(t, n.danger)
			var low := maxi(1, int(round(purse * (1.0 - Combat.WRECK_CREDIT_SPREAD))))
			var high := int(round(purse * (1.0 + Combat.WRECK_CREDIT_SPREAD)))
			for k in 40:
				var got := Combat.roll_wreck(n, t, k)
				rolls += 1
				parts += _parts(got)
				var chits := 0
				for m in got:
					if m is CreditChit:
						chits += 1
						var a := (m as CreditChit).amount
						paid += 1
						if a < low or a > high:
							outside += 1
						var ratio := float(a) / purse
						ratio_sum += ratio
						lo = minf(lo, ratio)
						hi = maxf(hi, ratio)
				if chits > 1:
					outside += 1
		var rate := float(paid) / float(rolls)
		var mean := ratio_sum / float(maxi(1, paid))
		var per := float(parts) / float(rolls)
		mean_parts[id] = per
		h._ok("%s: pays in %.1f%% of %d wrecks (chance %.0f%%)" % [id, 100.0 * rate, rolls,
			100.0 * Combat.WRECK_CREDIT_CHANCE], absf(rate - Combat.WRECK_CREDIT_CHANCE) < 0.03)
		h._ok("%s: every chit inside its own purse +-%.0f%%, one at most (%d outside)"
			% [id, 100.0 * Combat.WRECK_CREDIT_SPREAD, outside], outside == 0)
		h._ok("%s: the amounts average the purse (x%.3f) and use the whole spread (x%.2f to x%.2f)"
			% [id, mean, lo, hi], absf(mean - 1.0) < 0.02 and lo < 0.84 and hi > 1.16)
		var want: float = Combat.WRECK_PARTS[id]
		h._ok("%s: %.3f parts a wreck against the table's %.2f" % [id, per, want],
			absf(per - want) < 0.04)
		# Lawless doubles it.
		var lparts := 0
		var lrolls := 0
		for n in lawless:
			for k in 40:
				lparts += _parts(Combat.roll_wreck(n, t, k))
				lrolls += 1
		var lper := float(lparts) / float(maxi(1, lrolls))
		h._ok("%s: %.3f parts a wreck in lawless space, double the table (%.2f)"
			% [id, lper, want * Combat.WRECK_LAWLESS],
			absf(lper - want * Combat.WRECK_LAWLESS) < 0.08)
	h._ok("bigger hulls lean to more parts (cutter %.2f < lancer %.2f < hulk %.2f, sentinel %.2f the most)"
		% [mean_parts[&"cutter"], mean_parts[&"lancer"], mean_parts[&"hulk"], mean_parts[&"sentinel"]],
		mean_parts[&"cutter"] < mean_parts[&"lancer"] and mean_parts[&"lancer"] < mean_parts[&"hulk"]
		and mean_parts[&"sentinel"] >= mean_parts[&"marauder"] and mean_parts[&"sentinel"] > mean_parts[&"hulk"])

	# The Hellbender always pays, its number exactly, and three parts a hand.
	var hb: EnemyTemplate = DB.enemies[&"hellbender"]
	var hb_bad := 0
	for n in plain.slice(0, 30):
		for k in 8:
			for hands in [1, 3]:
				var got := Combat.roll_wreck(n, hb, k, hands)
				if _credits(got) != int(round(Combat.wreck_purse(hb, n.danger))) \
						or _parts(got) != Combat.HELLBENDER_PARTS * hands:
					hb_bad += 1
	h._ok("the Hellbender always pays its purse exactly and 3 parts a hand (%d wrong)" % hb_bad,
		hb_bad == 0)
	# Fauna: exotic in the body, no money, no parts.
	for id in [&"whale", &"leviathan"]:
		var t2: EnemyTemplate = DB.enemies[id]
		var fauna_bad := 0
		for n in nodes.slice(0, 30):
			for k in 8:
				var got := Combat.roll_wreck(n, t2, k)
				var exotic := 0
				for m in got:
					if m is MaterialData and (m as MaterialData).id == &"exotic":
						exotic += 1
				if _credits(got) != 0 or _parts(got) != 0 or exotic != Combat.FAUNA_EXOTIC:
					fauna_bad += 1
				var calyx := Combat.roll_wreck(n, t2, k, 1, false, true)
				if calyx.size() != Combat.FAUNA_EXOTIC + 1:
					fauna_bad += 1
		h._ok("%s: %d exotic in the body (one more with the calyx set), no money, no parts (%d wrong)"
			% [id, Combat.FAUNA_EXOTIC, fauna_bad], fauna_bad == 0)
	# Probate is half as much again on the same roll.
	var cut: EnemyTemplate = DB.enemies[&"sentinel"]
	var n0 := plain[0]
	var plain_cr := 0
	var probate_cr := 0
	for k in 64:
		plain_cr += _credits(Combat.roll_wreck(n0, cut, k))
		probate_cr += _credits(Combat.roll_wreck(n0, cut, k, 1, true))
	h._ok("the probate set pays half as much again on the same wrecks (%d -> %d)"
		% [plain_cr, probate_cr], absf(float(probate_cr) / maxf(1.0, plain_cr) - 1.5) < 0.02)


## A real fight won: each wreck holds its own template's roll at its own place,
## and the line says what they hold.
func _own_template() -> void:
	var n: MapGen.MapNode = null
	for c in _systems():
		if c.region != MapGen.Region.FAUNA and _wrecks(c).is_empty():
			n = c
			break
	var before := _wrecks(n).size()
	var cb := _win(n, &"cutter", [&"sentinel", &"hulk"])
	h._ok("the three-ship fight was won", cb.result == &"victory")
	var ws := _wrecks(n)
	h._ok("one wreck per hull (%d)" % (ws.size() - before), ws.size() - before == 3)
	var credits := 0
	var parts := 0
	var empty := 0
	for i in range(before, ws.size()):
		var w := ws[i]
		var t: EnemyTemplate = cb.enemies[i - before].template
		h._ok("wreck %d is the %s's" % [i, t.id], w.art == t.id)
		var own := Combat.roll_wreck(n, DB.enemies[w.art], i)
		h._ok("wreck %d (%s) holds its own roll: %s" % [i, w.art, _says(w.items)],
			_says(w.items) == _says(own))
		var purse := Combat.wreck_purse(DB.enemies[w.art], n.danger)
		var c := _credits(w.items)
		h._ok("wreck %d's money, if any, is its own ship's purse (%d of %.0f)" % [i, c, purse],
			c == 0 or (c >= int(round(purse * 0.8)) and c <= int(round(purse * 1.2))))
		credits += c
		parts += _parts(w.items)
		if w.items.is_empty():
			empty += 1
	var line := Combat.wreck_line(credits, parts, 0, 3, empty)
	print("  the line: %s" % cb.summary)
	h._ok("the victory line says what the wrecks hold (%s)" % line,
		cb.summary.begins_with(line))
	# Over many places, a wreck's money always falls in its own ship's band:
	# the sentinel's chit never in the cutter's range and the other way round.
	var crossed := 0
	var nodes := _systems()
	for i in 80:
		var m := nodes[(i * 7) % nodes.size()]
		var cb2 := _win(m, &"cutter", [&"sentinel"])
		var ws2 := _wrecks(m)
		for j in 2:
			var w2 := ws2[ws2.size() - 2 + j]
			var mine: EnemyTemplate = DB.enemies[w2.art]
			var c2 := _credits(w2.items)
			var p := Combat.wreck_purse(mine, m.danger)
			if c2 > 0 and (c2 < int(round(p * 0.8)) or c2 > int(round(p * 1.2))):
				crossed += 1
			if w2.art != cb2.enemies[j].template.id:
				crossed += 1
	h._ok("over 80 cutter-and-sentinel fights every chit is its own ship's (%d crossed)" % crossed,
		crossed == 0)


## A two-ship fight pays about what its two ships would have paid apart.
func _pair_sum() -> void:
	var nodes := _systems()
	var got := 0
	var want := 0.0
	var old := 0.0
	var fights := 0
	for n in nodes.slice(0, mini(nodes.size(), 150)):
		for k in 3:
			var cb := _win(n, &"cutter", [&"marauder"])
			if cb.result != &"victory":
				continue
			fights += 1
			var ws := _wrecks(n)
			for j in 2:
				got += _credits(ws[ws.size() - 2 + j].items)
			var c: EnemyTemplate = DB.enemies[&"cutter"]
			var m: EnemyTemplate = DB.enemies[&"marauder"]
			want += Combat.WRECK_CREDIT_CHANCE * (Combat.wreck_purse(c, n.danger)
				+ Combat.wreck_purse(m, n.danger))
			# The old rule: the last ship's purse, once.
			old += m.credit_reward * (1.0 + (n.danger - 1) * 0.2)
	var f := float(maxi(1, fights))
	print("  %d cutter-and-marauder fights: %.1f credits a fight, the two ships' own %.1f, the old rule %.1f"
		% [fights, got / f, want / f, old / f])
	h._ok("a two-ship fight pays the sum of its two ships (%.1f against %.1f a fight, %.1f%% off)"
		% [got / f, want / f, 100.0 * (got - want) / want], fights >= 300 and absf(got - want) / want < 0.06)


## Two machines, two seats, streams at different places: the same wrecks.
func _coop() -> void:
	var gseed := Run.galaxy_seed
	var pick := -1
	for n in _systems():
		if n.region != MapGen.Region.FAUNA and _wrecks(n).is_empty():
			pick = n.index
			break
	var seen: Array = []
	var loot_seeds: Array = []
	var parts_seen: Array = []
	for seat in [0, 1, 3]:
		Rng.forced = gseed
		Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
		# This machine's own seat, and its private streams somewhere else.
		Rng.reseed(Run.galaxy_seed, seat)
		for i in 17 + seat * 11:
			Rng.loot.randf()
			Rng.fight.randf()
			LootGen.roll_module(4)
		loot_seeds.append(Rng.loot.seed)
		var n: MapGen.MapNode = Run.map[pick]
		Run.at = n.index
		var cb := Combat.new()
		cb.start(DB.enemies[&"hulk"], n.danger, [DB.enemies[&"lancer"]])
		var f := SharedFight.new()
		f.paid = 2
		cb.shared = f
		cb.shared_at = n.index
		for e in cb.enemies:
			e.hp = 0
		cb._victory()
		var all := PackedStringArray()
		var parts := 0
		var expect := 0
		var ws := _wrecks(n)
		for i in ws.size():
			all.append("%s[%s]" % [ws[i].art, ",".join(_says(ws[i].items))])
			parts += _parts(ws[i].items)
			expect += _parts(Combat.roll_wreck(n, DB.enemies[ws[i].art], i, 2))
		seen.append(all)
		parts_seen.append([parts, expect, cb.wreck_hands])
	h._ok("the three machines' private streams really were apart",
		loot_seeds[0] != loot_seeds[1] and loot_seeds[1] != loot_seeds[2])
	print("  seat 0: %s" % " | ".join(seen[0]))
	h._ok("every seat rolls every wreck identically",
		seen[0] == seen[1] and seen[1] == seen[2] and seen[0].size() == 2)
	h._ok("sized for a crew of two: each wreck rolled per hand (%s)" % str(parts_seen[0]),
		parts_seen[0][2] == 2 and parts_seen[0][0] == parts_seen[0][1])
	# Two hands hold more parts than one, over many wrecks.
	var one := 0
	var two := 0
	for n2 in _systems().slice(0, 60):
		for k in 8:
			one += _parts(Combat.roll_wreck(n2, DB.enemies[&"hulk"], k, 1))
			two += _parts(Combat.roll_wreck(n2, DB.enemies[&"hulk"], k, 2))
	h._ok("two hands hold about twice the parts of one (%d against %d)" % [two, one],
		absf(float(two) / float(maxi(1, one)) - 2.0) < 0.12)
	# The money does not multiply with the crew: one hull, one purse.
	var purse1 := 0
	var purse2 := 0
	for n3 in _systems().slice(0, 60):
		for k in 8:
			purse1 += _credits(Combat.roll_wreck(n3, DB.enemies[&"hulk"], k, 1))
			purse2 += _credits(Combat.roll_wreck(n3, DB.enemies[&"hulk"], k, 2))
	h._ok("the money is the same however many hands (%d, %d)" % [purse1, purse2], purse1 == purse2)


## A save keeps every wreck, what it holds and what was taken out of it.
func _save() -> void:
	Rng.forced = 777
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var n: MapGen.MapNode = null
	for c in _systems():
		if c.region != MapGen.Region.FAUNA:
			n = c
			break
	_win(n, &"marauder", [&"lancer"])
	_win(n, &"whale")
	var ws := _wrecks(n)
	h._ok("two fights left three wrecks", ws.size() == 3)
	# Take something out of the first wreck that holds anything.
	var took := -1
	for w in ws:
		if not w.items.is_empty():
			took = w.option(0)
			n.taken.append(took)
			break
	var back := SaveGame._node_from(SaveGame._node_to(n))
	var bws := _wrecks(back)
	h._ok("the save kept three wrecks (%d)" % bws.size(), bws.size() == 3)
	for i in mini(ws.size(), bws.size()):
		h._ok("wreck %d (%s) comes back holding the same: %s" % [i, ws[i].art, _says(bws[i].items)],
			bws[i].art == ws[i].art and _says(bws[i].items) == _says(ws[i].items)
			and bws[i].slot == ws[i].slot)
	h._ok("and what was taken stays taken", took < 0 or back.taken.has(took))
