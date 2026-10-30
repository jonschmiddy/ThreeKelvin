extends Node

## THE DERELICT HAULER'S SCRAP, photographed for Jon's Phase 10 pick (Oct 29:
## "I don't understand Derelict hauler · SCRAP"):
##   godot --path . --windowed --resolution 1920x1080 -- sheet=DerelictShot out=<dir> [seed=4242]
##
## A heavy Korvan at a derelict whose frame is light, as Jeremy met it:
##   1_page      the derelict's page on LOCAL, the claim naming the frame
##   2_result    YOU CHOSE, the frame claimed
##   3_rail_A    LOCAL's rail with the frame on offer: TAKE IT and SCRAP (as built, pick A)
##   4_rail_B    the same row with LEAVE IT put back beside SCRAP (pick B, the real
##               row's own button added, not built anywhere else)
## Each also as `<name>_crop.png`, the part that matters at 2x. Prints what the
## strip pays and what SCRAP pays. Needs a window.

const ID := &"derelict_hauler"

var h := Harness.new()
var _tree: SceneTree
var _args: PackedStringArray
var _out := ""


func _ready() -> void:
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _frames(k: int) -> void:
	for i in k:
		await _tree.process_frame


func _img() -> Image:
	return GameShell.input_target(_tree).get_texture().get_image()


func _shot(name: String, crop: Rect2 = Rect2()) -> void:
	var img := _img()
	img.save_png("%s/%s.png" % [_out, name])
	if crop.size != Vector2.ZERO:
		# the image may be the window's size or the game's 960x540
		var k := float(img.get_width()) / 960.0
		var r := Rect2(crop.position * k, crop.size * k).grow(8 * k)
		var ri := Rect2i(r.intersection(Rect2(Vector2.ZERO, Vector2(img.get_size()))))
		var c := img.get_region(ri)
		var up := maxf(1.0, round(2.0 / k))
		if up > 1.0:
			c.resize(int(ri.size.x * up), int(ri.size.y * up), Image.INTERPOLATE_NEAREST)
		c.save_png("%s/%s_crop.png" % [_out, name])
	print("  derelictshot: %s" % name)


func _run() -> void:
	_tree = get_tree()
	_args = OS.get_cmdline_user_args()
	_out = _arg("out", "user://derelictshot")
	DirAccess.make_dir_recursive_absolute(_out)
	await _frames(2)
	LocalEventDrawer.quiet = true
	Router.animate_in_harness = false
	h.seed_run(int(_arg("seed", "4242")))
	Run.start_new_run(&"korvan", int(HullData.Weight.HEAVY))
	var n: MapGen.MapNode = await _light_derelict()
	if n == null:
		print("  derelictshot: FAIL no derelict with a light frame")
		_tree.quit(1)
		return
	print("  derelictshot: %s, danger %d" % [MapGen.star_name(n), n.danger])

	var d: LocalEventDrawer = await _open(n)
	if d == null:
		print("  derelictshot: FAIL the derelict's page did not come up")
		_tree.quit(1)
		return
	# in a window the band slides up on the real clock; let it land and the text finish
	for i in 120:
		if d.text != null and not d.text.done:
			d.text.skip()
		await _tree.process_frame
	_shot("1_page", d.panel.get_global_rect())
	var r: Dictionary = await d.choose(0)
	for i in 10:
		if d.text != null and not d.text.done:
			d.text.skip()
		await _tree.process_frame
	await _frames(10)
	_shot("2_result", d.panel.get_global_rect())
	print("  derelictshot: claimed %s, ok %s" % [Run.found_hull.name if Run.found_hull else "nothing", r.get("ok", false)])

	d.continue_on()
	var sc: SectorScreen = await _rail()
	var wrap: Control = sc.get("_salvage_wrap") if sc != null else null
	if wrap == null:
		print("  derelictshot: FAIL no rail")
		_tree.quit(1)
		return
	await _frames(10)
	_shot("3_rail_A", wrap.get_global_rect())
	var scrap := _button(wrap, "SCRAP")
	print("  derelictshot: the rail's buttons: %s" % ", ".join(_buttons(wrap)))
	print("  derelictshot: SCRAP pays %d credits (the strip's own pay)" % Run.found_scrap_credits())
	if scrap != null:
		var leave := Widgets._btn("LEAVE IT", func() -> void: pass)
		scrap.get_parent().add_child(leave)
		await _frames(10)
		_shot("4_rail_B", wrap.get_global_rect())
		print("  derelictshot: B's buttons: %s" % ", ".join(_buttons(wrap)))
	LocalEventDrawer.quiet = false
	_tree.quit()


## A derelict in its band whose frame is light, found by claiming it.
func _light_derelict() -> MapGen.MapNode:
	var band: Dictionary = OptionTable.by_id(ID)
	for raw in Run.map:
		var n: MapGen.MapNode = raw
		if n.type != MapGen.NodeType.SYSTEM or n.danger < int(band.get("min_danger", 1)) \
				or n.danger > int(band.get("max_danger", 99)):
			continue
		_fresh(n)
		await OptionResolve.take(n, 0, 0)
		if Run.found_hull != null and Run.found_hull.weight == HullData.Weight.LIGHT:
			return n
	return null


## The system holding the derelict alone, untouched, the ship at it, whole.
func _fresh(n: MapGen.MapNode) -> void:
	n.options.clear()
	n.options.append(ID)
	n.taken.clear()
	n.results.clear()
	n.left.clear()
	n.said.clear()
	n.jetsam.clear()
	n.cleared = false
	n.ambush_pending = false
	Run.at = n.index
	Run.dead = false
	Run.found_hull = null
	Run.hp = Run.max_hp()
	Run.heat = 0
	Run.credits = 180


## The derelict's page up on the real LOCAL (as the map's GO opens it).
func _open(n: MapGen.MapNode) -> LocalEventDrawer:
	_fresh(n)
	n.visited = true
	SectorScreen._approached_at = n.index
	SystemMapScreen._parked.erase(n.index)
	LocalEventDrawer.request(n.index, 0)
	Router.show_local()
	var d: LocalEventDrawer = null
	for i in 240:
		await _tree.process_frame
		var lo := Router.current as SectorScreen
		d = lo.get("_events") if lo != null else null
		if d != null and d.page == &"event" and not ZoomLadder.busy():
			break
	if d == null or d.page != &"event":
		return null
	for i in 10:
		if d.text != null and not d.text.done:
			d.text.skip()
		await _tree.process_frame
	return d


## The rail on LOCAL, once the band is down and the rail has caught up.
func _rail() -> SectorScreen:
	Router.show_local()
	for i in 90:
		await _tree.process_frame
		var lo := Router.current as SectorScreen
		if lo != null and not ZoomLadder.busy() and (lo.get("_events") == null
				or (lo.get("_events") as LocalEventDrawer).page == &""):
			lo._refresh_salvage()
			await _frames(3)
			return lo
	return Router.current as SectorScreen


func _button(root: Node, head: String) -> Button:
	return h.first(root, func(x: Node) -> bool:
		return x is Button and (x as Button).is_visible_in_tree() \
			and (x as Button).text.begins_with(head)) as Button


func _buttons(root: Node) -> PackedStringArray:
	var out := PackedStringArray()
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var x: Node = stack.pop_back()
		if x is Button and (x as Button).is_visible_in_tree():
			out.append((x as Button).text)
		for c in x.get_children():
			stack.append(c)
	return out
