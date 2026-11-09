extends Node

## Too-deep stars are drawn dimmed (ruling 13 A, Jon, Oct 27); read via `Run.too_deep_only`.
## Why: docs/why/ChartDeepTest.md#chart-deep-test

var _tree: SceneTree
var h := Harness.new()

const SEEDS := [4242, 11, 777]
## Zoomed out (dots, under `0.78`) and zoomed in (glyphs).
const ZOOMS := [0.5, 1.6]


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await Harness.frames(_tree, 2)
	for a in OS.get_cmdline_user_args():
		if (a as String).begins_with("depthcap="):
			Run.depth_step = int((a as String).substr(9))
	print("  [depth step] %d" % Run.depth_step)
	for sd in SEEDS:
		print("  [seed] %d" % sd)
		await _galaxy(sd)
	Run.depth_step = Run.DEPTH_STEP
	h.verdict("chartdeeptest")
	_tree.quit(h.code())


## Park where the chart shows both too-deep stars and jumpable ones.
static func park_spot() -> int:
	var best := -1
	var best_n := 0
	for ra in Run.map:
		var a: MapGen.MapNode = ra
		if a.type == MapGen.NodeType.CORE:
			continue
		var sight := Run.sense_radius_of(a)
		var deep := 0
		var ok := 0
		for rb in Run.map:
			var b: MapGen.MapNode = rb
			if b.index == a.index or b.type == MapGen.NodeType.CORE:
				continue
			if MapGen.hop_distance(a, b) > sight:
				continue
			if Run.too_deep_only(a, b):
				deep += 1
			elif Run.reachable_from(a, b):
				ok += 1
		if deep > best_n and ok > 0:
			best = a.index
			best_n = deep
	return best


## Park the ship at `idx`, as if it had flown there.
static func park(idx: int) -> void:
	var a: MapGen.MapNode = Run.map[idx]
	Run.at = idx
	a.visited = true
	Run.trail = PackedInt32Array([idx])
	Run.chart_from(a)


func _galaxy(sd: int) -> void:
	Rng.forced = sd
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	var at := park_spot()
	if not _ok("a system with stars in reach both too deep and not", at >= 0):
		return
	park(at)
	var here: MapGen.MapNode = Run.node_at()
	var deep: Array[int] = []
	var reach: Array[int] = []
	var other: Array[int] = []
	for rn in Run.map:
		var n: MapGen.MapNode = rn
		if n.index == here.index or not Run.charted(n) or n.type == MapGen.NodeType.CORE:
			continue
		if Run.too_deep_only(here, n):
			deep.append(n.index)
		elif Run.reachable_from(here, n):
			reach.append(n.index)
		else:
			other.append(n.index)
	print("    parked at %d (ring %d of %d): %d too deep, %d in reach, %d else on the chart"
		% [at, here.layer + 1, MapGen.LAYERS, deep.size(), reach.size(), other.size()])
	_ok("too-deep stars and reachable stars charted", not deep.is_empty() and not reach.is_empty())

	Router.show_starchart()
	await Harness.frames(_tree, 6)
	var ch := Router.current as StarchartScreen
	if not _ok("the star chart is up", ch != null and ch._chart != null):
		return
	ch.dismiss_primer()
	var mc := ch._chart
	for z: float in ZOOMS:
		mc.hovered = -1
		mc.center_on_ship(z)
		mc.queue_redraw()
		await Harness.frames(_tree, 3)
		var tag := "zoomed out" if mc.zoom < 0.78 else "zoomed in"
		_look(mc, tag, deep, reach, other)

		# under the cursor and picked, still dimmed
		var d0: int = deep[0]
		mc.hovered = d0
		mc._hover_t = 1.0
		mc.queue_redraw()
		await Harness.frames(_tree, 2)
		_ok("%s: the too-deep star under the cursor is still dimmed" % tag, _dimmed(mc, d0))
		ch._on_node_picked(d0)
		mc.queue_redraw()
		await Harness.frames(_tree, 2)
		_ok("%s: picked, still dimmed" % tag, _dimmed(mc, d0))
	mc.hovered = -1

	# THE WORDS: hover readout and JUMP
	var dn: MapGen.MapNode = Run.map[deep[0]]
	var rn2: MapGen.MapNode = Run.map[reach[0]]
	var tip_d := mc.tip_lines(dn, here)
	var tip_r := mc.tip_lines(rn2, here)
	_ok("the too-deep star's hover readout ends TOO DEEP (\"%s\")" % tip_d[3],
		tip_d[3].ends_with("TOO DEEP"))
	_ok("a reachable star's does not (\"%s\")" % tip_r[3], not tip_r[3].contains("TOO DEEP"))
	ch._on_node_picked(deep[0])
	await Harness.frames(_tree, 2)
	_ok("picked, JUMP reads TOO DEEP and is off (\"%s\")" % ch._jump.text,
		ch._jump.text == "TOO DEEP" and ch._jump.disabled)
	ch._on_node_picked(reach[0])
	await Harness.frames(_tree, 2)
	_ok("a reachable star picked, JUMP does not (\"%s\")" % ch._jump.text,
		ch._jump.text != "TOO DEEP")


## What the chart drew, star by star, against the rule.
func _look(mc: MapChart, tag: String, deep: Array[int], reach: Array[int],
		other: Array[int]) -> void:
	var bad: Array[String] = []
	for i in deep:
		if not _dimmed(mc, i):
			bad.append("%d drawn %s, its star %s" % [i, _hex(mc.drawn_ink.get(i)),
				_hex(MapGen.star_colour(Run.map[i]))])
	_ok("%s: all %d too-deep stars in reach drawn dimmed" % [tag, deep.size()], bad.is_empty())
	_say(bad)
	bad = []
	for i in reach:
		if mc.drawn_dim.has(i) or not mc.drawn_ink.has(i):
			bad.append("%d dimmed or not drawn" % i)
			continue
		var ink: Color = mc.drawn_ink[i]
		var own := MapGen.star_colour(Run.map[i])
		if (Run.map[i] as MapGen.MapNode).cleared:
			continue
		# its own colour, lifted: as bright or brighter, and still coloured (a
		# lift toward white takes some saturation: red keeps half of it)
		if ink.v < own.v or ink.s < own.s * 0.4:
			bad.append("%d drawn %s, its star %s" % [i, _hex(ink), _hex(own)])
	_ok("%s: all %d reachable stars drawn in their own colour, not dimmed" % [tag, reach.size()],
		bad.is_empty())
	_say(bad)
	bad = []
	for i in mc.drawn_dim:
		if not deep.has(int(i)):
			bad.append("%d dimmed and not too deep" % int(i))
	for i in other:
		if mc.drawn_dim.has(i):
			bad.append("%d dimmed, out of reach" % i)
	_ok("%s: nothing else dimmed (%d stars dimmed, %d others on the chart)"
		% [tag, mc.drawn_dim.size(), other.size()], bad.is_empty())
	_say(bad)


## Drawn dimmed: grey, and half its own star's value or less; zoomed in, every
## ink of its glyph grey too (the lights and the glass included).
func _dimmed(mc: MapChart, i: int) -> bool:
	if not mc.drawn_ink.has(i) or not mc.drawn_dim.has(i):
		return false
	var ink: Color = mc.drawn_ink[i]
	var own := MapGen.star_colour(Run.map[i])
	if ink.s > 0.15 or ink.v > own.v * 0.5:
		return false
	if mc.zoom >= 0.78:
		var ramp := StarchartScreen.Glyph.ramp_for(own, StarchartScreen.Glyph.BAND, true)
		for k: String in ramp:
			# (all but the outline, near black in every glyph alike)
			if k != "o" and (ramp[k] as Color).s > 0.15:
				return false
	return true


func _hex(c: Variant) -> String:
	return "#" + (c as Color).to_html(false) if c is Color else "nothing"


func _say(bad: Array[String]) -> void:
	for b in bad.slice(0, 6):
		print("    %s" % b)
