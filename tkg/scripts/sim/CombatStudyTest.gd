extends Node

## Called through `call()`, so a HeadlessSim without the flags prints FAIL, not a compile error.
## Why: docs/why/CombatStudyTest.md#combat-study-flags

var h := Harness.new()

const HP := 2.0
const DMG := 1.3


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await get_tree().process_frame
	_scaling()
	_closing_line()
	h.verdict("combatstudytest")
	get_tree().quit(h.code())


## Every template's numbers, by id: hull, and each intent's damage, hits, block
## and heal, loop then pool.
func _snapshot() -> Dictionary:
	var out := {}
	for id in DB.enemies:
		var t: EnemyTemplate = DB.enemies[id]
		var ints: Array = []
		for raw in t.loop + t.pool:
			var i := raw as IntentData
			ints.append([i.damage, i.hits, i.block, i.heal])
		out[id] = {hull = t.max_hull, boss = t.boss, ints = ints}
	return out


func _scaling() -> void:
	print("=== SCALING ===")
	var sim: Variant = HeadlessSim.new()
	if not h._ok("HeadlessSim has scale_enemies (the enemyhp= / enemydmg= flags)",
			(sim as Object).has_method("scale_enemies")):
		return
	var before := _snapshot()
	var bosses := 0
	for id in before:
		if before[id].boss:
			bosses += 1
	h._ok("the Custodian is the one boss (%d)" % bosses,
		bosses == 1 and before.has(&"custodian") and bool(before[&"custodian"].boss))
	var said: PackedStringArray = (sim as Object).call("scale_enemies", HP, DMG)
	h._ok("it names every template it scaled (%d): %s" % [said.size(), " / ".join(said)],
		said.size() == before.size() - bosses)
	var after := _snapshot()
	var bad: Array[String] = []
	for id in before:
		var b: Dictionary = before[id]
		var a: Dictionary = after[id]
		if b.boss:
			if a.hull != b.hull or a.ints != b.ints:
				bad.append("%s moved (a boss)" % id)
			continue
		if a.hull != maxi(1, int(round(b.hull * HP))):
			bad.append("%s hull %d from %d" % [id, a.hull, b.hull])
		for k in b.ints.size():
			var bi: Array = b.ints[k]
			var ai: Array = a.ints[k]
			if ai[0] != int(round(bi[0] * DMG)):
				bad.append("%s intent %d damage %d from %d" % [id, k, ai[0], bi[0]])
			if ai[1] != bi[1] or ai[2] != bi[2] or ai[3] != bi[3]:
				bad.append("%s intent %d hits/block/heal moved" % [id, k])
	h._ok("every enemy but the boss: hull x%.1f, damage x%.1f, nothing else%s"
		% [HP, DMG, "" if bad.is_empty() else ": " + ", ".join(bad)], bad.is_empty())
	var cust: EnemyTemplate = DB.enemies[&"custodian"]
	var cdmg: Array = []
	for raw in cust.loop:
		cdmg.append((raw as IntentData).damage)
	h._ok("the Custodian keeps hull 200 and Volley 6 / Annihilate 40 (hull %d, %s)"
		% [cust.max_hull, str(cdmg)], cust.max_hull == 200 and cdmg == [6, 0, 40])

	# What a fight actually fields, through Combat's own spawn.
	h.seed_run(777)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var cb := Combat.new()
	cb.plan(DB.enemies[&"lancer"], 1)
	var e: Combat.EnemyState = cb.enemies[0]
	var lance := (e.template.loop[0] as IntentData).damage
	# (from the template's own hull, never a typed number: the lancer's went
	# 34 -> 68 on Oct 29 and 68 -> 136 on Nov 3, and a typed one went stale each time)
	var want_hull := maxi(1, int(round(int(before[&"lancer"].hull) * HP)))
	h._ok("a danger-1 Corsair Lancer fields hull %d and a Lance of 12 (%d, %d)"
		% [want_hull, e.max_hp, lance], e.max_hp == want_hull and lance == 12)
	var hb: EnemyTemplate = DB.enemies[&"hellbender"]
	h._ok("the Hellbender's template is hull 180 (%d), and a run's Hellbender opens at it (%d of %d)"
		% [hb.max_hull, Run.hellbender_hp, Run.hellbender_max],
		hb.max_hull == 180 and (Run.hellbender_max == 0
			or (Run.hellbender_max == 180 and Run.hellbender_hp == 180)))


func _closing_line() -> void:
	print("=== CLOSING LINE ===")
	var sim: Variant = HeadlessSim.new()
	if not h._ok("HeadlessSim has end_line", (sim as Object).has_method("end_line")):
		return
	var line: String = (sim as Object).call("end_line", [300, 100, 200, 950], 3, 1)
	h._ok("four won runs: median 250, max 950, 3 on an empty tank, 1 a dry-tank strand (%s)" % line,
		line.contains("won runs 4 · credits median 250 max 950 · ended on an empty tank 3 (dry-tank strands 1)"))
	var none: String = (sim as Object).call("end_line", [], 0, 0)
	h._ok("no won runs reads zeros (%s)" % none,
		none.contains("won runs 0 · credits median 0 max 0 · ended on an empty tank 0"))
