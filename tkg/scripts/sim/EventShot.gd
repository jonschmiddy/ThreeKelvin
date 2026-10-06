extends Node

## EVENTS RESOLVED ON LOCAL, photographed (`LocalEventDrawer`):
##   godot --path . --windowed --position 3840,0 -- sheet=EventShot keepwindow
##       out=<dir> [seed=1] [node=11] [layout=row|column|card] [flow] [compare] [reveal]
##
## `flow`     the map's list, an event's page (one sentence and GO), GO -- the
##            flight and the zoom down, filmed into `flow/` -- the band up, the
##            result, the bar under the view after CONTINUE, the map with the
##            event stamped, and a fight event to its hand. Stills `01_`..`08_`.
## `compare`  a short, a medium and a long event (the shortest, middle and
##            longest bodies in `OptionTable`) in all three layouts, each still
##            as the game draws it (`cmp_<layout>_<size>.png`), with the empty
##            area of the drawer -- pixels that are bare panel, no text or card --
##            printed as `[eventshot] empty <layout> <size> <px> <of> <share>`.
## `reveal`   the medium event's text arriving (`SignalText`), one layout,
##            stepped on a fixed 30 fps clock so the frames play at true speed,
##            into `reveal_<layout>/`.
## Needs a window.

const FPS := 30.0

var _args: PackedStringArray
var _out := ""


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _secs(t: float) -> void:
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < int(t * 1000.0):
		await RenderingServer.frame_post_draw


func _img() -> Image:
	return GameShell.input_target(get_tree()).get_texture().get_image()


func _shot(name: String) -> void:
	_img().save_png("%s/%s.png" % [_out, name])
	print("  eventshot: %s" % name)


func _run() -> void:
	var tree := get_tree()
	_out = _arg("out", "user://eventshot")
	DirAccess.make_dir_recursive_absolute(_out)
	await tree.process_frame
	Rng.forced = int(_arg("seed", "1"))
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	LocalEventDrawer.layout = StringName(_arg("layout", "row"))
	var idx := int(_arg("node", "11"))
	var n: MapGen.MapNode = Run.map[idx]
	Run.at = idx
	n.visited = true
	OptionTable.ensure(n)
	SectorScreen._approached_at = idx
	print("  eventshot: %s (node %d), %d options: %s" % [MapGen.star_name(n), idx, n.options.size(), n.options])
	if "flow" in _args:
		await _flow(n)
	if "compare" in _args:
		await _compare(n)
	if "reveal" in _args:
		await _reveal(n)
	tree.quit()


# ------------------------------------------------------------------ the flow

func _flow(n: MapGen.MapNode) -> void:
	Router.show_system()
	await _secs(1.5)
	_shot("01_map_list")
	var map := Router.current as SystemMapScreen
	if map == null:
		print("  eventshot: FAIL no map")
		return
	# the first event with a checked choice, to show its odds on LOCAL
	var pick := -1
	var pick_b := -1
	var pick_bc = null
	for bi in map.view.layout.bodies.size():
		for bc in map.view.layout.bodies[bi].beacons:
			if bc.opt < 0:
				continue
			var o := OptionTable.by_id(n.options[bc.opt])
			for c in o.get("choices", []):
				if (c as Dictionary).has("check") and pick < 0:
					pick = bc.opt
					pick_b = bi
					pick_bc = bc
	if pick < 0:
		print("  eventshot: FAIL no checked event here")
		return
	map.open_beacon(pick_b, pick_bc)
	await _secs(0.4)
	_shot("02_event_page")
	# GO: the flight, the zoom down, the band lifting and its text arriving
	var flow := _out + "/flow"
	DirAccess.make_dir_recursive_absolute(flow)
	map.go_event(pick)
	var k := 0
	var t0 := Time.get_ticks_msec()
	var settle := 0
	while Time.get_ticks_msec() - t0 < 20000:
		await _secs(0.033)
		_img().save_png("%s/f_%04d.png" % [flow, k])
		k += 1
		var lo := Router.current as SectorScreen
		var d: LocalEventDrawer = lo.get("_events") if lo != null else null
		if d != null and d.page == &"event" and d.text != null and d.text.done:
			settle += 1
			if settle > 20:
				break
	print("  eventshot: flow %d frames, %.1f s" % [k, (Time.get_ticks_msec() - t0) / 1000.0])
	_shot("03_drawer_open")
	var lo2 := Router.current as SectorScreen
	var d2: LocalEventDrawer = lo2.get("_events")
	var o2 := OptionTable.by_id(n.options[pick])
	var j := 0
	for jj in (o2.get("choices", []) as Array).size():
		if ((o2.choices as Array)[jj] as Dictionary).has("check"):
			j = jj
			break
	await d2.choose(j)
	await _secs(0.1)
	d2.text.skip()
	await _secs(0.5)
	_shot("04_result")
	d2.continue_on()
	await _secs(0.8)
	_shot("05_local_bar")
	Router.show_system()
	await _secs(1.5)
	_shot("06_map_stamped")
	# A FIGHT EVENT, to its hand
	var fo := -1
	var fj := -1
	for i in n.options.size():
		if EncounterDrawer.option_state(n, i).kind != &"open":
			continue
		var choices: Array = OptionTable.by_id(n.options[i]).get("choices", [])
		for jj in choices.size():
			if bool((choices[jj] as Dictionary).get("fight", false)) and fo < 0:
				fo = i
				fj = jj
	if fo < 0:
		print("  eventshot: no fight event open here")
		return
	Router.show_local()
	await _secs(0.8)
	var lo3 := Router.current as SectorScreen
	var d3: LocalEventDrawer = lo3.get("_events")
	d3.open(fo)
	await _secs(0.15)
	d3.text.skip()
	await _secs(0.6)
	_shot("07_fight_event")
	await d3.choose(fj)
	await _secs(0.3)
	if is_instance_valid(d3) and d3.page == &"result":
		d3.text.skip()
		await _secs(0.5)
		_shot("07b_fight_result")
		d3._drop()
		d3._fight()
	await _secs(2.5)
	_shot("08_fight_hand")


# ------------------------------------------------------------------ layouts

## The shortest, the middle and the longest event bodies in the table.
func _sizes() -> Array:
	var all: Array = OptionTable.all().duplicate()
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("body", "")).length() < String(b.get("body", "")).length())
	return [["short", all[0].id], ["medium", all[all.size() / 2].id], ["long", all[all.size() - 1].id]]


func _plant(n: MapGen.MapNode, id: StringName) -> int:
	n.options.append(id)
	return n.options.size() - 1


func _compare(n: MapGen.MapNode) -> void:
	Router.show_local()
	await _secs(1.0)
	var lo := Router.current as SectorScreen
	var d: LocalEventDrawer = lo.get("_events")
	var sizes := _sizes()
	var at := {}
	for s: Array in sizes:
		at[s[0]] = _plant(n, StringName(s[1]))
	for layout: StringName in [&"row", &"column", &"card"]:
		LocalEventDrawer.layout = layout
		for s: Array in sizes:
			d.open(int(at[s[0]]))
			await _secs(0.15)
			if d.text != null:
				d.text.skip()
			await _secs(0.6)
			var img := _img()
			img.save_png("%s/cmp_%s_%s.png" % [_out, layout, s[0]])
			var r := d.panel.get_global_rect()
			var e := _empty(img, Rect2i(r))
			print("[eventshot] empty %s %s %d %d %.3f h%d" % [layout, s[0], e[0], e[1], float(e[0]) / maxf(1.0, float(e[1])), int(r.size.y)])
			d._drop()
			await _secs(0.5)
	LocalEventDrawer.layout = &"row"


## [bare panel pixels, all pixels] inside r: bare is the panel's own colour,
## with no text, card or rule on it.
func _empty(img: Image, r: Rect2i) -> Array:
	r = r.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	var bg := UITheme.PANEL
	var bare := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := img.get_pixel(x, y)
			if absf(c.r - bg.r) < 0.035 and absf(c.g - bg.g) < 0.035 and absf(c.b - bg.b) < 0.035:
				bare += 1
	return [bare, r.get_area()]


# ------------------------------------------------------------------ the text arriving

func _reveal(n: MapGen.MapNode) -> void:
	Router.show_local()
	await _secs(1.0)
	var lo := Router.current as SectorScreen
	var d: LocalEventDrawer = lo.get("_events")
	var i := _plant(n, StringName(_sizes()[1][1]))
	var dir := "%s/reveal_%s" % [_out, LocalEventDrawer.layout]
	DirAccess.make_dir_recursive_absolute(dir)
	d.open(i)
	# its clock stepped by hand at 30 a second, so the frames are true speed
	var k := 0
	var tail := 0
	while k < 600:
		if d.text != null:
			d.text.set_process(false)
			d.text._process(1.0 / FPS)
		await RenderingServer.frame_post_draw
		_img().save_png("%s/f_%04d.png" % [dir, k])
		k += 1
		if d.text != null and d.text.done:
			tail += 1
			if tail > 20:
				break
	print("  eventshot: reveal %d frames (%.1f s at %d fps)" % [k, k / FPS, int(FPS)])
