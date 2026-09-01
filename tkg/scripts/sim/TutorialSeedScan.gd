extends RefCounted

## Which seeds can carry the first flight?
##   godot --headless --path . -- tutseed [from=1] [want=8]
##
## A PICKER, not a gate. `TutorialOverlay.SEED` is a curated number, and this
## is where the curation happens: the tutorial promises a fight and a peaceful
## encounter within one jump of the start, and a seed either delivers that or
## it does not. The judgement here is the SAME test the overlay's CHART step
## runs to pick its recommendation (`TutorialOverlay._pick_target`), plus the
## two things only a scan can afford to demand:
##
## - **No ambush can fire on the way in.** The first jump should land on the
##   drawer, not in a fight nobody chose. The launch ship runs cold, so this
##   holds for every seed today -- it is checked anyway, because the day
##   `signature()` starts reading something a fresh hull has is the day every
##   seed in this file quietly stops meaning what it meant.
##
## - **The two halves cannot foreclose each other.** An exclusive group taking
##   the peaceful option down with the fight would strand step three.
##
## Re-run this and update the constant whenever the option table, the map
## generator or the starting loadout changes. The tutorial does not break when
## the seed rots -- the overlay falls back to "jump anywhere in reach" -- but a
## first flight that has to wander is a worse first flight.

func run() -> void:
	var from := 1
	var want := 8
	for a in OS.get_cmdline_user_args():
		if a.begins_with("from="):
			from = maxi(1, int(a.split("=")[1]))
		if a.begins_with("want="):
			want = clampi(int(a.split("=")[1]), 1, 100)

	print("scanning for tutorial seeds from %d..." % from)
	var found := 0
	var s := from
	# A bound, not a budget: candidates pass at well over one in three today,
	# so hitting it means the criteria have become impossible, not unlucky.
	while found < want and s < from + 20000:
		var verdict := _judge(s)
		if verdict != "":
			print("  seed %-6d  %s" % [s, verdict])
			found += 1
		s += 1
	if found < want:
		print("only %d of %d found in 20000 seeds -- the criteria are broken, not the luck" % [found, want])
	print("tutseed: DONE")


## Non-empty when the seed carries the lesson: what the recommended system is
## and what it offers, for the log. Empty when it does not.
func _judge(seed_value: int) -> String:
	Rng.forced = seed_value
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Rng.forced = 0
	var start: MapGen.MapNode = Run.node_at()
	Run.chart_from(start)
	for i in start.links:
		var n: MapGen.MapNode = Run.map[i]
		if n.type != MapGen.NodeType.SYSTEM or not Run.can_jump_to(n):
			continue
		# The launch ship must arrive cold enough that nothing can follow it
		# in. Checked against the CHANCE rather than by replaying the draw, so
		# the answer does not depend on how many foe-stream draws precede it.
		if Run.ambush_chance(n) > 0.0:
			continue
		# The verdict is the overlay's own predicate, so a certified seed and a
		# recommended system cannot drift apart. Only the log line is local.
		if not TutorialOverlay.lesson_at(n):
			continue
		var fight_ids: Array[String] = []
		var calm_ids: Array[String] = []
		for oid in n.options:
			if TutorialOverlay._fights(OptionTable.by_id(oid)):
				fight_ids.append(String(oid))
			else:
				calm_ids.append(String(oid))
		return "%s (danger %d): %s + %s" % [MapGen.star_name(n), n.danger,
			fight_ids[0], ", ".join(calm_ids)]
	return ""
