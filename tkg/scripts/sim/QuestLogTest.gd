extends Node

## THE QUESTS ON THE STAR CHART, headless:
##   godot --headless --path . -- sheet=QuestLogTest
##
## The chart's side panel lists every quest you hold under QUESTS (`QuestLog`,
## Jon's design B, Oct 22), the chart tags each one's place, and picking one
## makes it the destination with its route drawn from YOU. On three galaxies,
## through the real screen:
##
## - the QUESTS tab is the same rect with none, one and five quests held (Jon:
##   "no number after quests in the tab (so it doesn't change size)"), and so
##   is NEARBY;
## - with none, the list says so in a plain line and the chart has no tag;
## - every quest held has a card and a tag, and the tag stands on the right
##   system: a signed fetch's or hunt's target, and for a READY quest or a heat
##   quest the yard that pays it fewest jumps away;
## - picking a card sets the destination to its place and the route to a
##   chain of legal jumps from YOU to it; picking a star off the chart clears it;
## - FIT MEANS NOTHING OVERLAPS: every tag clear of the HUD, the goal line,
##   A.S.H.'s first place, the chart's own words, every star a click could pick
##   and every other tag, inside the chart, at the opening view and framed on
##   the quests.

var _fails := 0
var _tree: SceneTree

const SEEDS := [4242, 11, 777]


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_tree = get_tree()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _run() -> void:
	await _tree.process_frame
	for sd in SEEDS:
		print("  [seed] %d" % sd)
		await _galaxy(sd)
	print("questlogtest: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	_tree.quit(1 if _fails > 0 else 0)


## A ship three layers in at an ordinary system, the chart up on QUESTS.
func _galaxy(sd: int) -> void:
	Rng.forced = sd
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.SYSTEM and n.layer == 3:
			Run.at = n.index
			n.visited = true
			break
	Run.chart_from(Run.node_at())
	QuestLog.forget()
	StarchartScreen._side_quests = true
	Router.show_starchart()
	await _frames(4)
	var ch := Router.current as StarchartScreen
	if not _ok("the chart is up", ch != null):
		return

	# NONE
	ch._refresh()
	await _frames(2)
	var tab0 := ch._tab_quests.get_global_rect()
	var near0 := ch._tab_near.get_global_rect()
	_ok("the tab reads QUESTS", ch._tab_quests.text == "QUESTS")
	_ok("with no quest the list says so: \"%s\"" % ch._hint.text, ch._hint.text == QuestLog.EMPTY)
	_ok("and holds no card", _cards(ch).is_empty())
	_ok("and the chart no tag", ch._chart.quest_tags.is_empty())

	# ONE, then FIVE: a fetch, a hunt, a heat job, a fetch and a hunt, the
	# first fetch done (READY), some heat on the hull
	var want := [ContractData.Kind.FETCH, ContractData.Kind.HUNT, ContractData.Kind.HEAT,
		ContractData.Kind.FETCH, ContractData.Kind.HUNT]
	var held: Array = []
	for kind in want:
		var job := _offer(kind)
		if job == null:
			_ok("a %s offer within reach" % ContractData.Kind.keys()[kind], false)
			continue
		held.append(Run.take_contract(job))
		if held.size() == 1:
			ch._refresh()
			await _frames(2)
			_ok("one quest: the QUESTS tab has not moved or changed size",
				ch._tab_quests.get_global_rect() == tab0 and ch._tab_near.get_global_rect() == near0)
			_ok("and the tab still reads QUESTS", ch._tab_quests.text == "QUESTS")
	Run.reach_contract_target((held[0] as ContractData).at)
	Run.heat = 3
	ch._refresh()
	await _frames(2)
	_ok("five quests: the QUESTS tab has not moved or changed size (%s / %s)"
		% [ch._tab_quests.get_global_rect(), tab0],
		ch._tab_quests.get_global_rect() == tab0 and ch._tab_near.get_global_rect() == near0)

	# A CARD AND A TAG EACH, AT THE RIGHT PLACE
	var cards := _cards(ch)
	var list := QuestLog.entries()
	_ok("a card for every quest held (%d of %d)" % [cards.size(), held.size()], cards.size() == held.size())
	_ok("a tag for every quest held (%d)" % ch._chart.quest_tags.size(), ch._chart.quest_tags.size() == held.size())
	var right := true
	for i in list.size():
		var e: Dictionary = list[i]
		var job: ContractData = e.job
		var place := int(e.place)
		var ok_place := false
		if job.state == ContractData.State.READY or job.kind == ContractData.Kind.HEAT:
			ok_place = place >= 0 and ContractData.berth_of(Run.map[place], job.manufacturer)
			for raw in Run.map:
				var n: MapGen.MapNode = raw
				if ContractData.berth_of(n, job.manufacturer) and QuestLog.jumps(n.index) >= 0 \
						and QuestLog.jumps(n.index) < QuestLog.jumps(place):
					ok_place = false
		else:
			ok_place = place == job.at
		var tag_ok := i < ch._chart.quest_tags.size() and int(ch._chart.quest_tags[i].index) == place \
			and String(ch._chart.quest_tags[i].text).begins_with("%d " % (i + 1))
		var card_ok := i < cards.size() and int(cards[i].get_meta(&"quest")) == job.id
		if not (ok_place and tag_ok and card_ok):
			right = false
			print("    quest %d (%s, %s): place %d ok %s, tag %s, card %s" % [i + 1,
				ContractData.Kind.keys()[job.kind], ContractData.State.keys()[job.state], place, ok_place, tag_ok, card_ok])
	_ok("each card is its quest and each tag stands on its place (READY and heat: the nearest paying yard)", right)
	var ready_tag := String(ch._chart.quest_tags[0].text) if not ch._chart.quest_tags.is_empty() else ""
	_ok("the READY quest's tag says HAND IN (%s)" % ready_tag, ready_tag == "1 HAND IN")

	# PICKING ONE
	var hunt: ContractData = held[1]
	var card: Button = null
	for c in _cards(ch):
		if int(c.get_meta(&"quest")) == hunt.id:
			card = c
	if _ok("the hunt has a card to press", card != null):
		card.pressed.emit()
		await _frames(2)
		_ok("picking it makes its target the destination", ch._selected == hunt.at and ch._chart.selected == hunt.at)
		_ok("and the panel names it", ch._dest_name.text == MapGen.star_name(Run.map[hunt.at]))
		var r: Array[int] = ch._chart.quest_route
		var legal := r.size() >= 2 and r[0] == Run.at and r[r.size() - 1] == hunt.at
		for k in range(1, r.size()):
			legal = legal and Run.reachable_from(Run.map[r[k - 1]], Run.map[r[k]])
		_ok("and its route runs from YOU to it, a legal jump a hop (%d hops)" % maxi(0, r.size() - 1), legal)
		_ok("its tag is the picked one", bool(ch._chart.quest_tags[1].picked))
		await _boxes(ch, "picked")
		# framed on every quest's place, as a player zooms out to see them
		var span := 0.1
		for e2 in list:
			if int((e2 as Dictionary).place) >= 0:
				span = maxf(span, MapGen.hop_distance(Run.node_at(), Run.map[int((e2 as Dictionary).place)]) + 0.03)
		ch._chart.frame_region(Run.node_at(), span, false)
		await _frames(2)
		await _boxes(ch, "framed on the quests")
		# a star picked off the chart is not the quest
		var other := -1
		for raw in Run.in_range():
			var n2: MapGen.MapNode = raw
			if n2.index != hunt.at and n2.index != Run.at:
				other = n2.index
				break
		if other >= 0:
			ch._on_node_picked(other)
			await _frames(1)
			_ok("picking another star drops the quest's route", ch._chart.quest_route.is_empty() and ch._picked_quest == -1)

	StarchartScreen._side_quests = false


func _offer(kind: int) -> ContractData:
	for raw in Run.map:
		for c in Contracts.board(raw as MapGen.MapNode):
			var job: ContractData = c
			if job.kind != kind or Run.holds_contract(job):
				continue
			if job.at >= 0 and (job.at == Run.at or QuestLog.jumps(job.at) < 1 or QuestLog.jumps(job.at) > 4):
				continue
			return job
	return null


func _cards(ch: StarchartScreen) -> Array:
	var out: Array = []
	for c in ch._quests.get_children():
		if c is Button and c.has_meta(&"quest"):
			out.append(c)
	return out


## Every tag against everything it must keep off, global.
func _boxes(ch: StarchartScreen, when: String) -> void:
	var mc := ch._chart
	var near: Dictionary = mc.nodes_near(Rect2(Vector2.ZERO, mc.size))
	var pts := PackedVector2Array()
	for e: Array in near.nodes:
		pts.append(e[1] as Vector2)
	mc._pickable = pts
	var rects: Array = mc.place_quest_tags()
	var g := mc.get_global_transform()
	var avoid: Array = ch._quest_avoid()
	var bad: Array[String] = []
	var rad: float = near.rad
	for i in rects.size():
		var r: Rect2 = rects[i]
		if r.size == Vector2.ZERO:
			bad.append("tag %d not laid" % (i + 1))
			continue
		if not Rect2(Vector2.ZERO, mc.size).encloses(r):
			bad.append("tag %d leaves the chart" % (i + 1))
		var gr := g * r
		for a in avoid:
			if gr.intersects(a as Rect2):
				bad.append("tag %d %s over %s" % [i + 1, gr, a])
		for j in range(i + 1, rects.size()):
			if r.intersects(rects[j] as Rect2):
				bad.append("tag %d over tag %d" % [i + 1, j + 1])
		for sp in pts:
			if MapChartDist.d(r, sp) < rad:
				bad.append("tag %d over a star a click could pick at %s" % [i + 1, sp])
				break
	print("    %s: %d stars a click could pick (radius %.0f), %d rects to keep off" % [when, pts.size(), rad, avoid.size()])
	for b in bad:
		print("    %s" % b)
	_ok("%s: every tag clear of the HUD, the goal line, A.S.H., the chart's words, every pickable star and each other (%d tags)" % [when, rects.size()], bad.is_empty())


class MapChartDist:
	static func d(r: Rect2, p: Vector2) -> float:
		var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
		return q.distance_to(p)
