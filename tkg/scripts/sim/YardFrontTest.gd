extends Node

## THE BANNER SHIPYARD, driven as a player drives it (Jon's W2 v10, Nov 10):
## rest, point, pick, a locked banner, back, LAUNCH, developer mode; every
## state box-tested. `docs/tests.md` has the list.
## Why: docs/why/ChassisSelect.md#banner-yard

var _tree: SceneTree
var h := Harness.new()
var _history_was := ""
var _dev_was := false


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await Harness.frames(_tree, 2)
	_history_was = RunHistory.path
	RunHistory.path = TestRun.scratch("yardfront_history", "json")
	var f := FileAccess.open(RunHistory.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": RunHistory.VERSION, "runs": []}))
	f.close()
	_dev_was = DevMode.enabled
	DevMode.enabled = false

	Router.new_run(4242)
	await Harness.frames(_tree, 6)
	var cs := Router.current as ChassisSelect
	if not _ok("NEW RUN opens the hull pick", cs != null):
		return _finish()
	if not _ok("the city hall is installed", cs._yard.ready_hall):
		return _finish()
	await _rest(cs)
	await _pick(cs)
	await _locked(cs)
	await _launch(cs)
	await _dev()
	_finish()


## Nothing picked: the instruction, LAUNCH grey, seven banners, one of them named.
func _rest(cs: ChassisSelect) -> void:
	_ok("a fresh profile shows Korvan's set: the first banner's manufacturer", cs.manufacturer() == &"korvan" and cs.open())
	_ok("nothing is picked and LAUNCH is grey", cs._picked < 0 and not cs.launchable() and cs._band.key.disabled)
	_ok("the band says SELECT A SHIP", _band_says(cs, "SELECT A SHIP"))
	_ok("seven banners hang, Korvan's named and six ???", cs._yard.banners.size() == DB.STARTABLE.size()
		and cs._yard.banners[0].open and cs._yard.banners.slice(1).all(func(b: YardBanner) -> bool: return not b.open))
	_ok("three hulls stand, none under a tarp", cs._yard.sets.size() == 3
		and cs._yard.sets.values().all(func(s: YardStandSet) -> bool: return not s.tarped))
	var launch := Harness.button_with_text(cs, "LAUNCH")
	_ok("LAUNCH is a button the hints can find, disabled", launch != null and launch.disabled)
	var was := Router.current
	cs._launch()
	_ok("and pressing it with nothing picked does nothing", Router.current == was)
	_fit(cs, "at rest")


## Pointing and clicking the hulls themselves.
func _pick(cs: ChassisSelect) -> void:
	var medium: YardStandSet = cs._yard.set_of(HullData.Weight.MEDIUM)
	var heavy: YardStandSet = cs._yard.set_of(HullData.Weight.HEAVY)
	await _enter(medium)
	_ok("pointing at the medium hull shows its facts", cs._hover == int(HullData.Weight.MEDIUM)
		and _band_says(cs, Run.hull.name.to_upper()) and _band_says(cs, "CLICK TO MAKE IT YOURS"))
	_ok("and the live refit is that hull", Run.hull.weight == HullData.Weight.MEDIUM and Run.hull.manufacturer == &"korvan")
	_ok("the blur comes up behind it", cs._yard.hover_w == int(HullData.Weight.MEDIUM))
	_fit(cs, "pointing at the medium")
	await _click(cs, _mid(medium))
	_ok("a click picks it: LAUNCH comes on", cs._picked == int(HullData.Weight.MEDIUM) and cs.launchable()
		and not cs._band.key.disabled and not _band_says(cs, "CLICK TO MAKE IT YOURS"))
	_ok("the band spells the hardpoints and the hand out", _band_says(cs, "%d WEAPON" % Run.slots_for(ModuleData.Slot.WEAPON))
		and _band_says(cs, "%d SYSTEM" % Run.slots_for(ModuleData.Slot.SYSTEM))
		and _band_says(cs, "%d UTILITY" % Run.slots_for(ModuleData.Slot.UTILITY))
		and _band_says(cs, "%d CARDS A TURN" % Run.hand_size()))
	var block := Harness.first(cs._band, func(n: Node) -> bool: return n is AttrBlock) as AttrBlock
	_ok("the seven attributes are the picker's block", block != null and block._rows.size() == Run.attributes().size()
		and Run.attributes().size() == 7)
	_ok("the picked ship's lamps are spotlights, the rest a shade down", is_equal_approx(cs._yard._lamp_gains()[1], 1.5)
		and is_equal_approx(cs._yard._lamp_gains()[0], 0.9))
	_fit(cs, "medium picked")
	await _enter(heavy)
	_ok("pointing at the heavy shows the heavy, not yet yours", cs._hover == int(HullData.Weight.HEAVY)
		and Run.hull.weight == HullData.Weight.HEAVY and _band_says(cs, "CLICK TO MAKE IT YOURS"))
	_fit(cs, "medium picked, pointing at the heavy")
	await _enter(null)
	_ok("pointing away goes back to the picked ship", cs._hover < 0 and Run.hull.weight == HullData.Weight.MEDIUM
		and not _band_says(cs, "CLICK TO MAKE IT YOURS") and cs.launchable())


## A locked banner: tarps, the lock line, no launch; Korvan's brings it all back.
func _locked(cs: ChassisSelect) -> void:
	var solari: YardBanner = cs._yard.banners[1]
	await _click(cs, solari.global_position + Vector2(YardBanner.MARGIN + 24, 50))
	if not _ok("clicking a ??? banner brings its set in, locked", cs.manufacturer() == &"solari" and not cs.open()):
		return
	_ok("its ships sit under their tarps", cs._yard.sets.values().all(func(s: YardStandSet) -> bool: return s.tarped))
	_ok("LAUNCH is grey and nothing can launch", not cs.launchable() and cs._band.key.disabled)
	_ok("the band says what unlocks it: \"%s\"" % Unlocks.lock_line(&"solari"),
		_band_says(cs, Unlocks.lock_line(&"solari").to_upper()) and _band_says(cs, "LOCKED MANUFACTURER"))
	_ok("the hall goes dim and two lamps stutter", cs._yard.locked and cs._yard._lamp_gains()[0] == 0.5
		and cs._yard._lamp_gains()[2] <= 0.5)
	var was := Router.current
	cs._launch()
	cs._band.key.pressed.emit()
	_ok("pressing LAUNCH under a locked set does nothing", Router.current == was)
	await _enter(cs._yard.set_of(HullData.Weight.LIGHT))
	_ok("pointing at a tarp keeps the lock line", _band_says(cs, "LOCKED MANUFACTURER") and not cs.launchable())
	_fit(cs, "a locked manufacturer")
	await _enter(null)
	var korvan: YardBanner = cs._yard.banners[0]
	await _click(cs, korvan.global_position + Vector2(YardBanner.MARGIN + 24, 50))
	_ok("Korvan's banner brings the ships and the pick back", cs.manufacturer() == &"korvan" and cs.open()
		and cs._picked == int(HullData.Weight.MEDIUM) and cs.launchable()
		and cs._yard.sets.values().all(func(s: YardStandSet) -> bool: return not s.tarped))


## LAUNCH starts the run in the picked hull.
func _launch(cs: ChassisSelect) -> void:
	var launch := Harness.button_with_text(cs, "LAUNCH")
	_ok("LAUNCH is on", launch != null and not launch.disabled)
	launch.pressed.emit()
	await Harness.frames(_tree, 20)
	_ok("LAUNCH puts you on LOCAL", Router.current is SectorScreen)
	_ok("in the picked hull: a Korvan medium", Run.hull != null and Run.hull.weight == HullData.Weight.MEDIUM
		and Run.hull.manufacturer == &"korvan")


## Developer mode opens every banner (the editor side only: a release has no switch).
func _dev() -> void:
	if not DevMode.available:
		print("  (no developer mode in this binary: the all-open case is skipped)")
		return
	DevMode.enabled = true
	Router.new_run(4242)
	await Harness.frames(_tree, 6)
	var cs := Router.current as ChassisSelect
	if not _ok("developer mode: a new run opens the hull pick", cs != null):
		return
	_ok("every banner is open", cs._yard.banners.all(func(b: YardBanner) -> bool: return b.open))
	cs._select(DB.STARTABLE.find(&"calyx"))
	_ok("the last manufacturer's ships stand uncovered", cs.open() and cs.manufacturer() == &"calyx"
		and cs._yard.sets.values().all(func(s: YardStandSet) -> bool: return not s.tarped))
	cs._pick_weight(HullData.Weight.HEAVY)
	await Harness.frames(_tree, 3)
	_ok("and its heavy can be picked and launched", cs.launchable() and Run.hull.manufacturer == &"calyx")
	_fit(cs, "developer mode, a Calyx heavy")
	Run.hull = null


# ------------------------------------------------------------------ driving

func _mid(s: YardStandSet) -> Vector2:
	return Vector2(s.thing.position) + Vector2(s.thing.size) * 0.5


## The pointer over a berth (or over nothing), as the other harnesses hover:
## the enter and exit notifications, which a pushed motion event does not send.
var _over: Control = null

func _enter(c: Control) -> void:
	if _over != null and is_instance_valid(_over):
		_over.notification(Control.NOTIFICATION_MOUSE_EXIT)
	_over = c
	if c != null:
		c.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await Harness.frames(_tree, 3)


## The pointer put at a game-pixel place, through the game's own viewport.
func _point(cs: ChassisSelect, at: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = at
	ev.global_position = at
	cs.get_viewport().push_input(ev)
	await Harness.frames(_tree, 3)


func _click(cs: ChassisSelect, at: Vector2) -> void:
	await _point(cs, at)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.position = at
		ev.global_position = at
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		cs.get_viewport().push_input(ev)
		await Harness.frames(_tree, 1)
	await Harness.frames(_tree, 3)


func _band_says(cs: ChassisSelect, needle: String) -> bool:
	for l in _labels(cs._band):
		if l.text.contains(needle):
			return true
	return false


func _labels(root: Node) -> Array[Label]:
	var out: Array[Label] = []
	if root is Label and (root as Label).is_visible_in_tree():
		out.append(root)
	for c in root.get_children():
		out.append_array(_labels(c))
	return out


## FIT: every word and the key on screen, none over another, none over a hull
## or a banner; the hulls clear of each other and the banners in their row.
func _fit(cs: ChassisSelect, when: String) -> void:
	var screen := Rect2(0, 0, 960, 540)
	var boxes: Array[Rect2] = []
	var names: Array[String] = []
	for l in _labels(cs._band):
		if l.text.strip_edges() == "":
			continue
		boxes.append(l.get_global_rect())
		names.append(l.text)
	boxes.append(cs._band.key.get_global_rect())
	names.append("LAUNCH key")
	var off: Array[String] = []
	for i in boxes.size():
		if not screen.grow(0.5).encloses(boxes[i]):
			off.append("%s %s" % [names[i], boxes[i]])
	_ok("%s: every word and the key on screen%s" % [when, "" if off.is_empty() else ": " + ", ".join(off)], off.is_empty())
	var hits: Array[String] = []
	for i in boxes.size():
		for j in range(i + 1, boxes.size()):
			var r := boxes[i].intersection(boxes[j])
			if r.size.x > 0.0 and r.size.y > 0.0:
				hits.append("%s x %s" % [names[i], names[j]])
	_ok("%s: nothing on the band overlaps%s" % [when, "" if hits.is_empty() else ": " + ", ".join(hits)], hits.is_empty())
	var things: Array[Rect2] = []
	for s: YardStandSet in cs._yard.sets.values():
		things.append(Rect2(s.thing))
	for b in cs._yard.banners:
		things.append(b.get_global_rect())
	var over: Array[String] = []
	for i in boxes.size():
		for t in things:
			var r2 := boxes[i].intersection(t)
			if r2.size.x > 0.0 and r2.size.y > 0.0:
				over.append("%s over %s" % [names[i], t])
	_ok("%s: no word over a hull, a tarp or a banner%s" % [when, "" if over.is_empty() else ": " + ", ".join(over)], over.is_empty())
	var cross := false
	for i in things.size():
		if not screen.grow(0.5).encloses(things[i]):
			cross = true
		for j in range(i + 1, things.size()):
			var r3 := things[i].intersection(things[j])
			if r3.size.x > 0.0 and r3.size.y > 0.0:
				cross = true
	_ok("%s: the hulls and banners clear of each other and on screen" % when, not cross)


func _finish() -> void:
	DevMode.enabled = _dev_was
	if _history_was != "":
		RunHistory.clear()
		RunHistory.path = _history_was
	h.verdict("yardfronttest")
	_tree.quit(h.code())
