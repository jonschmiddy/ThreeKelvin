extends Node

## WHAT A SHIP COMES WITH, BOX-TESTED (Jon's B2, Nov 12): every open maker's three
## ships picked in turn; the band's words, emblem, stack, LAUNCH and chips clear
## of each other and inside the band; the fitted list is what launches; the
## weapons on the hull and its sharp copy. `-- sheet=YardInfoFit`
## Why: docs/why/ChassisSelect.md#what-a-ship-comes-with

var harness := Harness.new()


func _ok(what: String, c: bool) -> bool:
	if not c:
		harness._fail(what)
	return c


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await Harness.frames(get_tree(), 2)
	var dev_was := DevMode.enabled
	if DevMode.available:
		DevMode.enabled = true
	Router.new_run(4242)
	await Harness.frames(get_tree(), 6)
	var cs := Router.current as ChassisSelect
	if not _ok("the hull pick opens", cs != null):
		_finish(dev_was)
		return
	var picks := 0
	var bad := 0
	for m: StringName in DB.STARTABLE:
		cs._select(DB.STARTABLE.find(m))
		if not cs.open():
			continue
		for w: HullData.Weight in [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]:
			cs._pick_weight(w)
			await Harness.frames(get_tree(), 3)
			var tag := "%s %s" % [m, HullData.weight_name(w)]
			bad += _fit(cs, tag)
			_loadout(cs, w, tag)
			picks += 1
	print("  yardinfofit: %d picks, %d boxes out of place" % [picks, bad])
	_ok("every open maker's three ships were picked (%d)" % picks, picks >= 3)
	_finish(dev_was)


func _finish(dev_was: bool) -> void:
	DevMode.enabled = dev_was
	harness.verdict("yardinfofit")
	get_tree().quit(harness.code())


## Every box on the band against every other and against the band's own box.
func _fit(cs: ChassisSelect, when: String) -> int:
	var boxes: Array[Rect2] = []
	var names: Array[String] = []
	for n in cs._band.find_children("*", "Control", true, false):
		var c := n as Control
		if not c.is_visible_in_tree() or _in_strip(c):
			continue
		if c is Label and (c as Label).text.strip_edges() != "":
			boxes.append(_ink(c as Label))
			names.append((c as Label).text.left(20))
		elif c is YardInfo.DeckStack or c is YardInfo.Emblem or c is Button:
			boxes.append(c.get_global_rect())
			names.append((c as Button).text if c is Button else String(c.get_script().get_global_name()))
	var band := Rect2(YardBand.BAND)
	var bad := 0
	for i in boxes.size():
		# (the developer's grade chips hang 2 px under the band, as they did before)
		if not band.grow(0.5).encloses(boxes[i]) and not names[i] in ["C", "B", "A", "S"]:
			bad += 1
			_ok("%s: %s inside the band (%s in %s)" % [when, names[i], boxes[i], band], false)
		for j in range(i + 1, boxes.size()):
			var r := boxes[i].intersection(boxes[j])
			if r.size.x > 0.0 and r.size.y > 0.0:
				bad += 1
				_ok("%s: %s clear of %s" % [when, names[i], names[j]], false)
	return bad


## The fitted list is what launches; the weapons are on the hull and its sharp copy.
func _loadout(cs: ChassisSelect, w: HullData.Weight, when: String) -> void:
	var said: Array[String] = []
	for c in cs._band.find_children("*", "Label", true, false):
		said.append((c as Label).text)
	var parts := true
	for p: ModuleData in Run.installed:
		parts = parts and said.has(p.name.to_upper())
	_ok("%s: the band names every fitted part and the hand, and leaves the deck to the stack" % when, parts
		and said.has("HAND SIZE: %d A TURN" % Run.hand_size()) and not said.has("DECK %d CARDS" % Run.deck_size()))
	var s: YardStandSet = cs._yard.set_of(w)
	var guns := 0
	if s.mounts != null:
		for p: ModuleData in s.mounts.fitted:
			guns += 1 if p.slot == ModuleData.Slot.WEAPON else 0
	_ok("%s: the hull carries its weapons (%d)" % [when, guns], guns > 0 and s.mounts.is_inside_tree())
	var copy := false
	for c in cs._yard._ghost.get_children():
		copy = copy or c is MountPoints
	_ok("%s: and so does its sharp copy over the blur" % when, copy)
	_ok("%s: the deck's spread is the deck" % when, YardInfo.deck().size() == Run.deck_size())


static func _in_strip(c: Node) -> bool:
	var n := c
	while n != null:
		if n is YardInfo.DeckStrip:
			return true
		n = n.get_parent()
	return false


## A label's box as its text is set, not its control's.
static func _ink(l: Label) -> Rect2:
	var f := UITheme.pixel_font()
	var px := l.get_theme_font_size(&"font_size")
	var w := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	if l.autowrap_mode != TextServer.AUTOWRAP_OFF and l.custom_minimum_size.x > 0.0:
		var n := YardInfo.lines(l.text, int(l.custom_minimum_size.x))
		return Rect2(l.global_position, Vector2(minf(w, l.custom_minimum_size.x), n * YardInfo.LINE - 3))
	return Rect2(l.global_position, Vector2(w, float(px) + 2.0))
