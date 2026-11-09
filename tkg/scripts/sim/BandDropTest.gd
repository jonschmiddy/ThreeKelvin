extends Node

## The drop moved up to 29 px a frame, as a cubic
## ease-in ends at three times average speed. Now capped.
## Why: docs/why/BandDropTest.md#band-drop

var _tree: SceneTree
var h := Harness.new()
var _frame := 0


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _process(_d: float) -> void:
	_frame += 1


func _wait(s: float) -> void:
	for i in int(ceil(s * 60.0)):
		await _tree.process_frame


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	Router.animate_in_harness = true
	Rng.forced = 1
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	LocalEventDrawer.layout = &"column"
	var idx := 11
	var n: MapGen.MapNode = Run.map[idx]
	Run.at = idx
	n.visited = true
	OptionTable.ensure(n)
	SectorScreen._approached_at = idx
	var all: Array = OptionTable.all().duplicate()
	all.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("body", "")).length() < String(b.get("body", "")).length())
	var sizes := [["short", all[0].id], ["medium", all[all.size() / 2].id],
		["long", all[all.size() - 1].id]]
	var film := "film" in OS.get_cmdline_user_args()
	if film:
		sizes = [sizes[1]]
	for id in sizes:
		n.options.append(id[1])
	Router.show_local()
	await _wait(2.0)
	for si in sizes.size():
		var sc := Router.current as SectorScreen
		var d: LocalEventDrawer = sc.get("_events") if sc != null else null
		if not _ok("LOCAL's band is there", d != null):
			break
		d.open(n.options.size() - sizes.size() + si)
		await _wait(0.2)
		if d.text != null:
			d.text.skip()
		await _wait(0.8 if film else 0.4)
		var top := d.get_global_rect().position.y
		var band_h := d.size.y
		print("mark drop %d" % _frame)
		d.not_now()
		var worst := 0.0
		var frames := 0
		var bar_early := 0
		var last := top
		while d.visible and frames < 240:
			await _tree.process_frame
			frames += 1
			var y := d.get_global_rect().position.y
			worst = maxf(worst, absf(y - last))
			last = y
			# the bar under the view: parked below the floor until the band has gone
			if d.visible and sc._quiet_wrap.position.y < 1.0:
				bar_early += 1
		_ok("%s (%d px band): gone in %d frames, at most %d px a frame"
				% [sizes[si][0], int(band_h), frames, int(worst)],
				not d.visible and worst <= LocalEventDrawer.DROP_MAX_PX + 1.0)
		var bar_from: float = sc._quiet_wrap.position.y
		var bar_frames := 0
		while sc._quiet_wrap.position.y > 0.0 and bar_frames < 120:
			await _tree.process_frame
			bar_frames += 1
		_ok("  and the bar under it waited (%d frames up while the band was), then eased up from %d px in %d frames"
				% [bar_early, int(bar_from), bar_frames],
				bar_early == 0 and bar_from > 0.0 and bar_frames > 1 and sc._quiet_wrap.position.y == 0.0)
		await _wait(1.0 if film else 0.3)
	h.verdict("banddroptest")
	_tree.quit(h.code())
