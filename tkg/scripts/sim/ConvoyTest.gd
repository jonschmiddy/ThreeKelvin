extends RefCounted

## Two contact sheets for the party display.
##
##   godot --headless --path . -- shipsheet     one ship per build, no renderer
##   godot --path . -- convoy                   the real sector, with a party
##   godot --path . -- convoy chart             the star chart, with a party
##   godot --path . -- convoy hold              the same, left open to play with
##   godot --path . -- convoy hold 7            and with a party that overflows
##
## They answer two different questions and only the first one can be automated.
##
## **Does a build draw as that build?** `shipsheet` writes one PNG per ship
## straight out of `ShipView`'s own canvas. No viewport, no window, no frame
## timing — the view composites into an `Image` and that image is the file. So
## it runs headless, in CI, and it is the check that a gun bolted to the third
## hardpoint is drawn on the third hardpoint.
##
## **Does the convoy fit on screen?** `convoy` fakes a full party and screenshots
## the real sector. That one needs a window, cannot assert anything, and exists
## because four ships in an arena sized for one is a layout question and layout
## questions are answered by looking.
##
## The fake party is a fake ROSTER, not a fake network. `NetSession.build_of()`
## reads `roster[id].build`, so filling that in puts four ships on screen with
## no peer, no port and nobody to connect to — which is what makes this runnable
## by one person on one machine.

const SHEET_DIR := "user://shipsheet"


func run(tree: SceneTree) -> void:
	# One frame before anything is added. Main is still inside _ready() here and
	# a node cannot take children while it is setting up its own.
	await tree.process_frame
	if "shipsheet" in OS.get_cmdline_user_args():
		_ship_sheet()
		tree.quit()
		return
	if "flare" in OS.get_cmdline_user_args():
		await _flare_shot(tree)
		tree.quit()
		return
	if "chart" in OS.get_cmdline_user_args():
		await _chart_shot(tree)
		tree.quit()
		return
	await _convoy_shot(tree)
	# `-- convoy hold` leaves it on screen instead of quitting.
	#
	# The shot answers "does the convoy fit"; holding answers the questions a
	# still cannot — what it looks like while the ships bob, what happens when
	# you open the ship screen and come back, whether a size reads differently
	# when you can move between the tabs. Same fabricated roster, so it is still
	# one person on one machine with no port open.
	if "hold" in OS.get_cmdline_user_args():
		print("holding — close the window when you are done")
		return
	tree.quit()


# --- one ship per build ----------------------------------------------------

## Every case is a pair: the same hull bare, then the same hull wearing
## something. The pair is the point — a sheet of loaded ships proves only that
## the renderer draws SOMETHING, and the question is whether what it draws
## follows the build.
func _ship_sheet() -> void:
	DirAccess.make_dir_recursive_absolute(SHEET_DIR)
	var cases: Array = [
		["light_bare", _build(&"redline", HullData.Weight.LIGHT, [])],
		["light_armed", _build(&"redline", HullData.Weight.LIGHT, [
			[ModuleData.Slot.WEAPON, 0, &"redline"],
			[ModuleData.Slot.SYSTEM, 0, &"verity"]])],
		["medium_bare", _build(&"korvan", HullData.Weight.MEDIUM, [])],
		["medium_armed", _build(&"korvan", HullData.Weight.MEDIUM, [
			[ModuleData.Slot.WEAPON, 0, &"korvan"],
			[ModuleData.Slot.WEAPON, 1, &"solari"],
			[ModuleData.Slot.UTILITY, 0, &"cygnet"]])],
		["heavy_bare", _build(&"probate", HullData.Weight.HEAVY, [])],
		["heavy_armed", _build(&"probate", HullData.Weight.HEAVY, [
			[ModuleData.Slot.WEAPON, 0, &"probate"],
			[ModuleData.Slot.WEAPON, 1, &"probate"],
			[ModuleData.Slot.WEAPON, 2, &"calyx"],
			[ModuleData.Slot.SYSTEM, 0, &"probate"],
			[ModuleData.Slot.SYSTEM, 1, &"korvan"],
			[ModuleData.Slot.UTILITY, 0, &"probate"]])],
	]
	# And the two gauges the art reads, on a ship that is otherwise unchanged.
	var hot := _build(&"solari", HullData.Weight.MEDIUM, [
		[ModuleData.Slot.WEAPON, 0, &"solari"], [ModuleData.Slot.WEAPON, 1, &"solari"]])
	hot.heat = hot.heat_cap + 4
	hot.hp = int(hot.max_hp * 0.35)
	cases.append(["solari_cold", _build(&"solari", HullData.Weight.MEDIUM, [
		[ModuleData.Slot.WEAPON, 0, &"solari"], [ModuleData.Slot.WEAPON, 1, &"solari"]])])
	cases.append(["solari_overheating", hot])

	for c in cases:
		var view := ShipView.new()
		view.show_build(c[1])
		var img := view.canvas()
		var path := "%s/%s.png" % [SHEET_DIR, c[0]]
		img.save_png(path)
		var built: ShipBuild = c[1]
		print("%-20s %dx%d  %s art  %s" % [c[0], img.get_width(), img.get_height(),
			"real" if built.hull.sprite != null else "drawn",
			ProjectSettings.globalize_path(path)])
		# Freed by hand. A Control that never entered a tree is not collected by
		# one, and eight of them is eight canvases.
		view.free()


# --- the real screen, with a party in it -----------------------------------

func _convoy_shot(tree: SceneTree) -> void:
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	# `-- convoy solo` is the control shot. The convoy cell is hidden when
	# nobody is flying with you, and "hidden" has to mean the sector is pixel
	# for pixel the screen it always was — an HBoxContainer still spends its
	# separation on an empty child, and a solo game that gained a left margin
	# would be a regression nothing in the party display would ever reveal.
	# `-- convoy 7` overrides the party size. The default is three partners,
	# which is the party the strip was measured for; any larger number is the
	# experiment.
	var partners := 3
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			partners = clampi(int(a), 1, CREW.size())
	fake_party(0 if "solo" in OS.get_cmdline_user_args() else partners)
	Router.show_sector()
	# Long enough for the fly-in to land. The ship enters from off screen and
	# coasts for ARRIVE_MS, so a shot taken on the next frame is a shot of an
	# empty arena — which looks exactly like a convoy strip that failed to build.
	# Long enough for the LAST ship to land. The approach runs four and a half
	# seconds and the convoy is staggered behind it, so a shot timed for one
	# ship catches the others still coasting in.
	for i in 460:
		await RenderingServer.frame_post_draw
	var path := "user://convoy_solo.png" if "solo" in OS.get_cmdline_user_args() \
		else "user://convoy.png"
	tree.root.get_texture().get_image().save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))


## A jump, frozen. Six frames of the flash side by side.
##
##   godot --path . -- convoy flare
##
## Its own mode because the effect is 24 frames long and a screenshot of a
## screenshot's worth of it says nothing: what has to be checked is the SHAPE
## over time — that the column opens, flares, and closes, and that the hull
## changes hands behind the widest frame rather than beside it.
##
## Driven by hand rather than by the clock. `_process` on the flare advances
## with delta, so a capture loop racing it lands on six arbitrary moments; this
## sets `_t` directly and photographs a known one.
func _flare_shot(tree: SceneTree) -> void:
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	fake_party(1)
	Router.show_sector()
	# 460, for the reason _convoy_shot records: the approach runs four and a
	# half seconds. Photographing a jump while the ship is still flying its
	# arrival puts the hull somewhere it will not be, and the beam then looks
	# misaligned when it is the ship that has not landed.
	for i in 460:
		await RenderingServer.frame_post_draw

	var slot := _find_slot(tree.root)
	if slot == null:
		print("no convoy slot on screen — the strip did not build")
		return
	print("slot rect %s | art rect %s | art tex %s" % [
		slot.get_global_rect(), slot.art.get_global_rect(),
		slot.art.texture.get_size() if slot.art.texture != null else Vector2.ZERO])
	var strip: Array[Image] = []
	# Across the whole life, including 0.0 (nothing) and past the peak, so a
	# flare that never closes is visible in the sheet rather than only in play.
	for at in [0.08, 0.22, 0.42, 0.62, 0.80, 0.96]:
		slot.art.visible = at >= EncounterView.JumpFlare.PEAK
		slot.flare.visible = true
		slot.flare.set("_t", at)
		slot.flare.set("_delay", 0.0)
		slot.flare.queue_redraw()
		slot.queue_redraw()
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var whole := tree.root.get_texture().get_image()
		# Just the column. The rest of the sector is the same in all six and
		# would make the sheet six copies of a screen with a detail in it.
		var r := slot.get_global_rect()
		strip.append(whole.get_region(Rect2i(
			maxi(0, int(r.position.x) - 8), maxi(0, int(r.position.y)),
			mini(whole.get_width(), int(r.size.x) + 16), int(r.size.y))))

	# A gap between frames, so the sheet reads as six pictures rather than as one
	# wide one — the effect is a vertical bar and so is a cell boundary.
	var w := strip[0].get_width() + 4
	var sheet := Image.create_empty(w * strip.size(), strip[0].get_height(),
		false, strip[0].get_format())
	sheet.fill(Color("#c0392b"))
	for i in strip.size():
		sheet.blit_rect(strip[i], Rect2i(Vector2i.ZERO, strip[i].get_size()),
			Vector2i(w * i + 2, 0))
	sheet.save_png("user://jump_flare.png")
	print("wrote ", ProjectSettings.globalize_path("user://jump_flare.png"))


func _find_slot(n: Node) -> EncounterView.ConvoySlot:
	if n is EncounterView.ConvoySlot:
		return n
	for c in n.get_children():
		var found := _find_slot(c)
		if found != null:
			return found
	return null


## The chart with the party on it: three partners at three depths, and a handful
## of systems the party has already used up.
##
## The one thing `-- nettest` cannot check. It proves a claim reaches every
## machine and a position lands in the right slot; whether a partner four shells
## coreward is actually VISIBLE is a drawing question, and the chart hides any
## system you have not been to and cannot reach.
func _chart_shot(tree: SceneTree) -> void:
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	fake_party(3)
	# Somewhere to be, at three different depths, so the marker is tested
	# against the visibility filter rather than beside your own ship where it
	# would have been drawn anyway.
	var spots := _spots_by_depth(3)
	for i in spots.size():
		Net.roster[2 + i].at = spots[i]
	# And a few systems used up, which the chart already greys out — so the
	# shared-map half shows without a single new pixel of chrome.
	var used: Dictionary = {}
	for i in spots:
		used[int(i)] = {MapGen.OPTION_WHOLE: 2}
	Net.claims = used
	Run.adopt_party_claims()
	Sig.party_changed.emit()
	Sig.party_map_changed.emit()
	Router.show_starchart()
	for i in 40:
		await RenderingServer.frame_post_draw
	var path := "user://convoy_chart.png"
	tree.root.get_texture().get_image().save_png(path)
	print("wrote ", ProjectSettings.globalize_path(path))


## One system per shell, spread from the rim inward, skipping the one you are
## standing in.
static func _spots_by_depth(count: int) -> Array:
	var out: Array = []
	for step in count:
		var want := 2 + step * 2
		for n in Run.map:
			var node: MapGen.MapNode = n
			if node.layer == want and node.index != Run.at:
				out.append(node.index)
				break
	return out


# --- the fake party --------------------------------------------------------

## Seven, so the column can be photographed past the four it was measured for.
## `fake_party(n)` takes as many as it is asked for, so `-- convoy 7` is the
## question "does the convoy strip survive a bigger party" asked in the one way
## that answers it — a picture.
const CREW: Array = [
	["MERCER", &"solari", HullData.Weight.HEAVY],
	["VELA", &"redline", HullData.Weight.LIGHT],
	["OKONKWO", &"calyx", HullData.Weight.MEDIUM],
	["ASWORTH", &"korvan", HullData.Weight.HEAVY],
	["DIALLO", &"probate", HullData.Weight.MEDIUM],
	["NAKATA", &"verity", HullData.Weight.LIGHT],
	["BRENNAN", &"cygnet", HullData.Weight.MEDIUM],
]

## Three friends who are not there. Public so `-- convoy` and anything else that
## wants to look at the party display can borrow it.
static func fake_party(count: int) -> void:
	Net.roster.clear()
	# `at` matters now: EncounterView draws only the ships in the room with you,
	# so a fabricated party with no position in it photographs an empty column.
	var here := Run.at if not Run.map.is_empty() else 0
	Net.roster[1] = {"id": 1, "name": "YOU", "hull": &"", "ready": true,
		"order": 0, "build": {}, "at": here}
	for i in mini(count, CREW.size()):
		var who: Array = CREW[i]
		var b := _build(who[1], who[2], [
			[ModuleData.Slot.WEAPON, 0, who[1]],
			[ModuleData.Slot.WEAPON, 1, &"verity"],
			[ModuleData.Slot.SYSTEM, 0, who[1]],
			[ModuleData.Slot.UTILITY, 0, &"cygnet"]])
		b.pilot = who[0]
		# Each one visibly worse off than the last, so the gauges are testable
		# from the picture rather than only from the code.
		b.hp = int(b.max_hp * (1.0 - 0.3 * float(i)))
		b.heat = int(b.heat_cap * (0.2 + 0.45 * float(i)))
		Net.roster[2 + i] = {"id": 2 + i, "name": who[0], "hull": who[1],
			"ready": true, "order": 1 + i, "build": b.to_wire(), "at": here}
	Sig.party_changed.emit()


static func _build(manufacturer: StringName, w: HullData.Weight, parts: Array) -> ShipBuild:
	var b := ShipBuild.new()
	b.hull = DB.hull_for(manufacturer, w)
	for p in parts:
		b.parts.append({"slot": int(p[0]), "mount": int(p[1]), "manufacturer": p[2],
			"id": &"beam"})
	b.hp = b.hull.max_hull
	b.max_hp = b.hull.max_hull
	b.heat_cap = b.hull.heat_cap
	return b
