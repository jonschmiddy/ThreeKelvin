extends Node

## DOCK BY THE MOUTH (Jon, Nov 15): on LOCAL at a station the bay's opening is the dock button,
## lit as look A with W1's word on the grating; LOCAL's dock goes on from the picture as it is,
## your ship where it sat; and the yard's ship card opens and wears as every tooltip does.
##   tools/dev/godot.sh --headless --path tkg -- sheet=DockMouthTest
## Why: docs/why/DockMouth.md#the-mouth-is-the-button

var _tree: SceneTree
var h := Harness.new()


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	ZoomLadder.force = 1
	ZoomLadder.fixed_dt = 1.0 / 30.0
	Rng.forced = 7
	_bakes()
	_hint()
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var loc := await _at_station()
	if loc != null:
		await _offered(loc)
		await _hover(loc)
		await _docks_from_here(loc)
		await _yard_card()
	h.verdict("dockmouthtest")
	_tree.quit(h.code())


## THE LIGHT AND THE WORD, baked: the grating read off the art, the word on its ridges only,
## the spill in three steps reaching further out of the open side than along the plate.
func _bakes() -> void:
	print("\n--- the bakes")
	var drum := StationSides.side(&"drum1")
	var rows := StationFace.slats(drum.bay_lit, drum.bay_at)
	var per := StationFace.slat_period(rows)
	var grooves := rows.count(0)
	_ok("the Drum's own bay is a grating, read off its art: a groove every %d rows (%d groove rows over the word)" % [per, grooves],
		per >= 2 and grooves > 0 and rows.count(2) > 0)
	var tex := StationFace.word_texture(drum.bay_lit, drum.bay_at)
	var img := tex.get_image()
	var wr := StationFace.word_rect()
	var lit_groove := 0
	var lit := 0
	var top_wrong := 0
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			lit += 1
			if rows[y + 1] == 0:
				lit_groove += 1
			if rows[y + 1] == 2 and absf(c.a - StationFace.RIDGE_TOP_A) > 0.01:
				top_wrong += 1
	_ok("the word (%s) lights the ridges only: %d px lit, %d of them on a groove, %d top rows not at the top's light" % [wr.size, lit, lit_groove, top_wrong],
		lit > 100 and lit_groove == 0 and top_wrong == 0 and wr.size == Vector2(92, 28))
	var flat_in := StationSides.interior(&"hallway_90_1")
	if not flat_in.is_empty():
		var fr := StationFace.slats(flat_in[1], StationSides.INTERIOR_AT)
		_ok("a flat back wall (a hallway) has no grooves, so the word is lit whole (period %d)" % StationFace.slat_period(fr), fr.count(0) == 0)
	var sp := StationFace.spill_texture().get_image()
	var box := StationFace.spill_rect()
	var alphas := {}
	var far_out := 0.0
	var far_side := 0.0
	var row := int(StationFace.SLOT.get_center().y - box.position.y)
	for x in sp.get_width():
		var a := sp.get_pixel(x, row).a
		if a > 0.0:
			var px := box.position.x + float(x)
			far_out = maxf(far_out, StationFace.SLOT.position.x - px)
			far_side = maxf(far_side, px - StationFace.SLOT.end.x)
	for y in range(0, sp.get_height(), 3):
		for x in range(0, sp.get_width(), 3):
			var a := snappedf(sp.get_pixel(x, y).a, 0.01)
			if a > 0.0:
				alphas[a] = true
	_ok("the spill is three steps of light (%s), reaching %.0f px out of the open side and %.0f px along the plate" % [alphas.keys(), far_out, far_side],
		alphas.size() <= 3 and alphas.size() >= 2 and far_out > 60.0 and far_side <= StationFace.SPILL_PLATE and far_out > 3.0 * maxf(far_side, 1.0))


func _hint() -> void:
	print("\n--- the hint line")
	DockMouth.forget(true)
	_ok("never docked by the mouth: \"%s\"" % DockMouth.hint_line("A STATION HERE"),
		DockMouth.hint_line("A STATION HERE") == (DockMouth.HINT_LINE if DockMouth.HINT else "A STATION HERE"))
	DockMouth.forget(false)
	_ok("once docked by it: \"%s\"" % DockMouth.hint_line("A STATION HERE"), DockMouth.hint_line("A STATION HERE") == "A STATION HERE")
	DockMouth.forget(true)


## LOCAL at a station, moored on its left, the arrival over.
func _at_station() -> SectorScreen:
	var st := -1
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type == MapGen.NodeType.STATION:
			st = n.index
			break
	if not _ok("the run has a station", st >= 0):
		return null
	Run.at = st
	Run.map[st].visited = true
	SectorScreen._approached_at = st
	Moored.at = -1
	Router.park_at_station()
	Router.show_local()
	var loc: SectorScreen = null
	for i in 900:
		await _tree.process_frame
		loc = Router.current as SectorScreen
		if loc != null and not ZoomLadder.busy() and loc.settled_local() and loc.find_child("DockMouth", true, false) != null:
			break
	await _frames(10)
	loc = Router.current as SectorScreen
	_ok("LOCAL at the station, at rest, the station's side up", loc != null and loc.settled_local() and loc._face != null)
	return loc


## Offered where the bar's DOCK was: the mouth there, the bar without DOCK, its box the opening.
func _offered(loc: SectorScreen) -> void:
	print("\n--- offered")
	var m := loc.find_child("DockMouth", true, false) as DockMouth
	if not _ok("the station's mouth is a button on LOCAL", m != null):
		return
	var bar_dock := false
	for b in loc.find_children("*", "Button", true, false):
		if (b as Button).text == "DOCK" and (b as Button).is_visible_in_tree():
			bar_dock = true
	_ok("no DOCK on the bar any more", not bar_dock)
	var want := loc._face.get_global_transform() * loc._face.mouth()
	_ok("its box is the bay's opening (%s, the opening %s), the pointing hand over it" % [UiRect.of(m), want],
		UiRect.of(m).is_equal_approx(want) and m.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND)
	_ok("pressable at rest (%s), and the bar says a station is here" % m.live(), m.live() and _bar_line(loc).begins_with("A STATION HERE"))
	Run.dead = true
	var dead := m.live()
	Run.dead = false
	_ok("not pressable with the run over (%s): only pressable things look pressable" % dead, not dead)


func _bar_line(loc: SectorScreen) -> String:
	var l := loc.find_child("HereLine", true, false) as Label
	return l.text if l != null else ""


## The pointer on it lights the bay over HOVER_S and off again; nothing that takes clicks moves.
## (Headless keeps no GUI hover, so the pointer's enter is set as the GUI sets it.)
func _hover(loc: SectorScreen) -> void:
	print("\n--- hover")
	var m := loc.find_child("DockMouth", true, false) as DockMouth
	if m == null:
		return
	var box0 := UiRect.of(m)
	m.over = true
	var up := -1
	for i in 120:
		await _tree.process_frame
		if loc._face.hover >= 1.0 and loc._face_front.hover >= 1.0:
			up = i
			break
	_ok("the pointer on the mouth lights the bay (both faces at %.2f, %d frames)" % [loc._face.hover, up], up > 0)
	_ok("the mouth's box does not move while it lights (%s, was %s)" % [UiRect.of(m), box0], UiRect.of(m).is_equal_approx(box0))
	m.over = false
	var down := -1
	for i in 120:
		await _tree.process_frame
		if loc._face.hover <= 0.0 and loc._face_front.hover <= 0.0:
			down = i
			break
	_ok("and off when it leaves (%d frames)" % down, down > 0)


## THE DOCK GOES ON FROM WHERE YOUR SHIP SITS (Jon, Nov 15: DOCK "resets the LOCAL scene"):
## the same LOCAL, the same scene, your ship where it was on the dock's first frame, no black
## and no arrival over LOCAL, and it docks.
func _docks_from_here(loc: SectorScreen) -> void:
	print("\n--- docks from here")
	var m := loc.find_child("DockMouth", true, false) as DockMouth
	var art := loc._view.ship_view() if loc._view != null else null
	if m == null or art == null:
		_ok("the mouth and your ship are on LOCAL", false)
		return
	var view0 := loc._view
	var pos0 := art.position
	var rect0 := UiRect.of(art)
	m.pressed.emit()
	_ok("the click docks from where your ship sits (from here %s, fade %s)" % [ZoomLadder.dock_from_here, ZoomLadder.dock_fade_only],
		ZoomLadder.busy() and ZoomLadder.dock_from_here and not ZoomLadder.dock_fade_only)
	var first_pos := Vector2.INF
	var first_rect := Rect2()
	var rebuilt := 0
	var black := 0.0
	var beats: Array[StringName] = []
	for i in 900:
		await _tree.process_frame
		if Router.current is StationScreen:
			break
		if Router.current != loc or not is_instance_valid(loc) or loc._view != view0 or loc._view.ship_view() != art:
			rebuilt += 1
			continue
		var hall: Dictionary = loc._lad.get("hall", {})
		if hall.is_empty():
			continue
		var beat: StringName = hall.get("beat", &"")
		if beat != &"" and (beats.is_empty() or beats[-1] != beat):
			beats.append(beat)
		if first_pos == Vector2.INF and beat != &"":
			first_pos = art.position
			first_rect = UiRect.of(art)
		if beat != &"enter":
			black = maxf(black, float(hall.get("black", 0.0)))
	_ok("the same LOCAL and the same scene and ship through the dock (%d frames otherwise)" % rebuilt, rebuilt == 0)
	_ok("your ship where it sat on the dock's first frame (%s on screen %s; it sat at %s, %s)" % [first_pos, first_rect, pos0, rect0],
		first_pos != Vector2.INF and first_rect.position.distance_to(rect0.position) <= 2.0 and first_rect.size.is_equal_approx(rect0.size))
	_ok("no black over LOCAL before your ship goes in (%.2f), no arrival: %s" % [black, beats],
		black <= 0.01 and not beats.has(&"arrive") and beats.has(&"power") and beats.has(&"enter"))
	await _frames(1)
	for i in 900:
		if Router.current is StationScreen and not ZoomLadder.busy():
			break
		await _tree.process_frame
	_ok("docked, and the flag let go", Router.current is StationScreen and Router.docked and not ZoomLadder.dock_from_here)
	_ok("the hint has done its job: the bar's line is plain again", DockMouth.docked_once())


## THE YARD'S SHIP CARD glitches in as the tooltips do: the tag's scanlines wipe down under it
## as it is shown, steady for D_AFTER, then the tag's bursts; put back as it was when hidden.
func _yard_card() -> void:
	print("\n--- the yard's ship card")
	var st := Router.current as StationScreen
	var slab: Control = null
	for i in 300:
		await _tree.process_frame
		st = Router.current as StationScreen
		if st != null and st._mine_slab != null and is_instance_valid(st._mine_slab):
			slab = st._mine_slab
			break
	if not _ok("the yard's card for your ship is there", slab != null):
		return
	var wear: HoloTag.Wear = null
	var scan: HoloTag.WearScan = null
	for k in slab.get_children():
		if k is HoloTag.Wear:
			wear = k
		elif k is HoloTag.WearScan:
			scan = k
	_ok("it wears the tag's glitch (%s) with the scanlines under its words (%s, first)" % [wear != null, scan != null],
		wear != null and scan != null and scan.get_index() == 0)
	if wear == null:
		return
	var x0 := slab.position.x
	slab.visible = true
	# (its clock set rather than waited on, so a slow machine cannot miss a 2-frame burst)
	var t0 := GameClock.now()
	await _tree.process_frame
	var step := GameClock.now() - t0
	var opening := scan.t < 1.0 or step >= HoloTag.OPEN
	wear._born = GameClock.now() - (HoloTag.OPEN + HoloTag.D_AFTER * 0.5)
	await _tree.process_frame
	await _tree.process_frame
	var g0 := wear.glitch()
	var steady := scan.t >= 1.0 and (g0 == null or not g0.on)
	# (the first burst starts as D_AFTER runs out, `HoloTag.glitch_at`'s frame 0)
	wear._born = GameClock.now() - (HoloTag.OPEN + HoloTag.D_AFTER + 0.01)
	var g := wear.glitch()
	var burst := g != null and g.on and not g.tears.is_empty()
	_ok("shown, its scanlines wipe down over the tag's open (%s; a frame %.3f s), steady half-way to %.0f s (%s), then the tag's burst (%s)" % [
		opening, step, HoloTag.D_AFTER, steady, burst], opening and steady and burst)
	wear._born = GameClock.now() - 1.0
	await _tree.process_frame
	slab.visible = false
	await _frames(2)
	_ok("hidden, it is put back as it was (alpha %.2f, x %.1f, was %.1f)" % [slab.modulate.a, slab.position.x, x0],
		is_equal_approx(slab.modulate.a, 1.0) and is_equal_approx(slab.position.x, x0))
