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
	await _banner_cloth(cs)
	await _tarp_click(cs)
	await _pick(cs)
	await _locked(cs)
	await _away(cs)
	await _launch(cs)
	await _dev()
	_finish()


## Nothing picked: the instruction alone, no LAUNCH (Jon, Nov 11), seven banners, one named.
func _rest(cs: ChassisSelect) -> void:
	_ok("a fresh profile shows Korvan's set: the first banner's manufacturer", cs.manufacturer() == &"korvan" and cs.open())
	_ok("nothing is picked and LAUNCH is hidden", cs._picked < 0 and not cs.launchable()
		and not cs._band.key.visible and not cs._band.armed)
	_ok("the band says SELECT A SHIP", _band_says(cs, "SELECT A SHIP"))
	_ok("the yard plays no score, and its bed is the room (asks %s, room %s)" % [Audio.music_asked, Router._room_for(cs)],
		Audio.music_asked == &"yard" and Router._room_for(cs) == Audio.YARD_ROOM)
	_ok("a hull's tooltip is its blurb, without its size first", cs._yard.sets.values().all(_blurb_only))
	_ok("seven banners hang, Korvan's named and six ???", cs._yard.banners.size() == DB.STARTABLE.size()
		and cs._yard.banners[0].open and cs._yard.banners.slice(1).all(func(b: YardBanner) -> bool: return not b.open))
	_ok("three hulls stand, none under a tarp", cs._yard.sets.size() == 3
		and cs._yard.sets.values().all(func(s: YardStandSet) -> bool: return not s.tarped))
	_ok("and no visible LAUNCH for the hints to find", Harness.button_with_text(cs, "LAUNCH") == null)
	var was := Router.current
	cs._launch()
	_ok("and launching with nothing picked does nothing", Router.current == was)
	_fit(cs, "at rest")


func _blurb_only(s: YardStandSet) -> bool:
	var blurb := ChassisSelect.WEIGHT_BLURB[int(s.weight)]
	return s.tooltip_text == Widgets.tip(blurb) and not blurb.begins_with(HullData.weight_name(s.weight))


## A banner is its cloth (Jon, Nov 11): below its foot, on the floor or the band, it is not there.
func _banner_cloth(cs: ChassisSelect) -> void:
	var solari: YardBanner = cs._yard.banners[1]
	var top := float(YardBanner.ROD_Y - YardBanner.TRUSS_Y + 4)
	var mid := Vector2(YardBanner.MARGIN + YardBanner.BW / 2.0, top + YardBanner.CLOTH / 2.0)
	var below := Vector2(mid.x, top + YardBanner.CLOTH + 6.0)
	_ok("a point on the cloth is the banner, one under its foot and one on the band are not",
		solari._has_point(mid) and not solari._has_point(below)
		and not solari._has_point(Vector2(mid.x, 470.0 - solari.global_position.y)))
	_ok("the cloth is %d rows, a third more than the mockup's 76" % YardBanner.CLOTH, YardBanner.CLOTH >= 100)
	await _click(cs, solari.global_position + below)
	await _click(cs, Vector2(solari.global_position.x + mid.x, 470.0))
	_ok("clicks under a banner, on the wall and the band, pick nothing", cs.manufacturer() == &"korvan" and cs.open())


## A ??? set with nothing picked: no LAUNCH until a tarp is clicked, then grey by the lock line.
func _tarp_click(cs: ChassisSelect) -> void:
	var solari: YardBanner = cs._yard.banners[1]
	await _click(cs, solari.global_position + Vector2(YardBanner.MARGIN + 24, 50))
	_ok("a ??? banner with nothing picked: tarps, the lock line, no LAUNCH", not cs.open()
		and _band_says(cs, "LOCKED MANUFACTURER") and not cs._band.key.visible)
	await _click(cs, _mid(cs._yard.set_of(HullData.Weight.MEDIUM)))
	_ok("a click on a tarp brings LAUNCH up grey beside the lock line", cs._band.key.visible
		and cs._band.key.disabled and _band_says(cs, Unlocks.lock_line(&"solari").to_upper()) and cs._picked < 0)
	_fit(cs, "a tarp clicked")
	await _click(cs, cs._yard.banners[0].global_position + Vector2(YardBanner.MARGIN + 24, 50))
	_ok("Korvan's banner again: nothing picked, LAUNCH hidden", cs.open() and cs._picked < 0 and not cs._band.key.visible)


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
	_ok("a click picks it: LAUNCH appears, on", cs._picked == int(HullData.Weight.MEDIUM) and cs.launchable()
		and cs._band.key.visible and not cs._band.key.disabled and not _band_says(cs, "CLICK TO MAKE IT YOURS"))
	_ok("the band spells the hardpoints and the hand out", _band_says(cs, "%d WEAPON" % Run.slots_for(ModuleData.Slot.WEAPON))
		and _band_says(cs, "%d SYSTEM" % Run.slots_for(ModuleData.Slot.SYSTEM))
		and _band_says(cs, "%d UTILITY" % Run.slots_for(ModuleData.Slot.UTILITY))
		and _band_says(cs, "%d CARDS A TURN" % Run.hand_size()))
	var block := Harness.first(cs._band, func(n: Node) -> bool: return n is AttrBlock) as AttrBlock
	_ok("the seven attributes are the picker's block", block != null and block._rows.size() == Run.attributes().size()
		and Run.attributes().size() == 7)
	# the medium stands far right, under the fifth lamp (Jon, Nov 12)
	_ok("the picked ship's lamps are spotlights, the rest a shade down", is_equal_approx(cs._yard._lamp_gains()[4], 1.5)
		and is_equal_approx(cs._yard._lamp_gains()[0], 0.9))
	_fit(cs, "medium picked")
	await _enter(heavy)
	_ok("pointing at the heavy shows the heavy, not yet yours", cs._hover == int(HullData.Weight.HEAVY)
		and Run.hull.weight == HullData.Weight.HEAVY and _band_says(cs, "CLICK TO MAKE IT YOURS"))
	_fit(cs, "medium picked, pointing at the heavy")
	await _enter(null)
	_ok("pointing away goes back to the picked ship", cs._hover < 0 and Run.hull.weight == HullData.Weight.MEDIUM
		and not _band_says(cs, "CLICK TO MAKE IT YOURS") and cs.launchable())
	await Harness.frames(_tree, 20)
	_ok("the blur holds round the picked ship with the pointer gone (k %.2f)" % cs._yard._k,
		is_equal_approx(cs._yard._k, 1.0) and cs._yard._ghost.visible and cs._yard._ghost.source == medium)


## A locked banner: tarps, the lock line, no launch; Korvan's brings it all back.
func _locked(cs: ChassisSelect) -> void:
	var solari: YardBanner = cs._yard.banners[1]
	await _click(cs, solari.global_position + Vector2(YardBanner.MARGIN + 24, 50))
	if not _ok("clicking a ??? banner brings its set in, locked", cs.manufacturer() == &"solari" and not cs.open()):
		return
	_ok("its ships sit under their tarps", cs._yard.sets.values().all(func(s: YardStandSet) -> bool: return s.tarped))
	_ok("LAUNCH is grey and nothing can launch", not cs.launchable() and cs._band.key.visible and cs._band.key.disabled)
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


## A click away from the ships clears the pick; only a hull's own pixels pick (Jon, Nov 11).
func _away(cs: ChassisSelect) -> void:
	var medium: YardStandSet = cs._yard.set_of(HullData.Weight.MEDIUM)
	var heavy: YardStandSet = cs._yard.set_of(HullData.Weight.HEAVY)
	await _click(cs, Vector2(480, 392))
	await Harness.frames(_tree, 20)
	_ok("a click on the floor clears the pick: SELECT A SHIP, no LAUNCH, the blur gone",
		cs._picked < 0 and not cs._band.key.visible and _band_says(cs, "SELECT A SHIP") and cs._yard._k == 0.0)
	var off := _spot(medium, false)
	var on := _spot(medium, true)
	if not _ok("the medium's box has air and hull in it", off.x >= 0.0 and on.x >= 0.0):
		return
	await _click(cs, off)
	_ok("a click in the medium's box but off its pixels picks nothing", cs._picked < 0)
	await _click(cs, on)
	_ok("a click on its pixels picks it", cs._picked == int(HullData.Weight.MEDIUM) and cs._band.key.visible)
	await _click(cs, _spot(heavy, true))
	_ok("a click on another ship switches the pick", cs._picked == int(HullData.Weight.HEAVY) and cs.launchable())
	await _click(cs, cs._yard.banners[0].global_position + Vector2(YardBanner.MARGIN + 24, 50))
	_ok("a click on a banner is not away: the pick stays", cs._picked == int(HullData.Weight.HEAVY))
	await _click(cs, on)
	_ok("and the medium again", cs._picked == int(HullData.Weight.MEDIUM))
	var word := Harness.first(cs._band, func(n: Node) -> bool:
		return n is Label and (n as Label).mouse_filter == Control.MOUSE_FILTER_PASS) as Label
	if _ok("the band has a word with a tooltip", word != null):
		await _click(cs, word.get_global_rect().get_center())
		_ok("a click on it is not away: the pick stays", cs._picked == int(HullData.Weight.MEDIUM))


## The first hall point in a berth's box that is (or is not) on its pixels.
func _spot(s: YardStandSet, ink: bool) -> Vector2:
	var b := Rect2(s.thing)
	for y in range(int(b.position.y) + 2, int(b.end.y) - 1, 3):
		for x in range(int(b.position.x) + 2, int(b.end.x) - 1, 3):
			var p := Vector2(x, y) + Vector2(0.5, 0.5)
			if s.on_ink(p) == ink:
				return p
	return Vector2(-1, -1)


## LAUNCH starts the run in the picked hull. A click on it is not "away"; the
## press itself is emitted, as every harness presses a Button (a pushed click
## does not press one headless).
func _launch(cs: ChassisSelect) -> void:
	var launch := Harness.button_with_text(cs, "LAUNCH")
	if not _ok("LAUNCH is on", launch != null and not launch.disabled):
		return
	await _click(cs, launch.get_global_rect().get_center())
	_ok("a click on LAUNCH is not away: the pick stays", cs._picked == int(HullData.Weight.MEDIUM))
	if Router.current == cs:
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
	_ok("the grade chips wait for a pick, as LAUNCH does", cs._band._tiers.size() == 4
		and cs._band._tiers.all(func(b: Button) -> bool: return not b.visible))
	cs._select(DB.STARTABLE.find(&"calyx"))
	_ok("the last manufacturer's ships stand uncovered", cs.open() and cs.manufacturer() == &"calyx"
		and cs._yard.sets.values().all(func(s: YardStandSet) -> bool: return not s.tarped))
	cs._pick_weight(HullData.Weight.HEAVY)
	await Harness.frames(_tree, 3)
	_ok("and its heavy can be picked and launched", cs.launchable() and Run.hull.manufacturer == &"calyx")
	_ok("the grade chips appear with LAUNCH", cs._band.key.visible
		and cs._band._tiers.all(func(b: Button) -> bool: return b.visible))
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
	for k: Control in [cs._band.key] + cs._band._tiers:
		if k.visible:
			boxes.append(k.get_global_rect())
			names.append("LAUNCH key" if k == cs._band.key else "grade chip")
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
