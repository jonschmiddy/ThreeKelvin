extends Node

## THE EVENT BAND'S DROP NEVER JUMPS. It moved up to 17 px a frame: a cubic
## ease-in ends at three times its average speed. Measured every frame here:
##   godot --headless --fixed-fps 60 --path . -- sheet=BandDropTest [looks=A,B,C]
##
## The shortest, a middle and the longest event in the table, each opened on
## LOCAL's band, its text finished, then NOT NOW. Every frame of the drop the
## band's top edge (what the eye follows: the slide's band, the shutter's edge,
## the dissolve's sinking panel) moves no more than
## `LocalEventDrawer.DROP_MAX_PX`, and the band is gone at the end. Each look in
## `looks` (default: the one the game uses) is measured.
##
## `film` (in a window, with --write-movie and --fixed-fps 60) runs one look on
## the middle event and prints `mark drop <frame>` for the pick page.

var _tree: SceneTree
var _fails := 0
var _frame := 0


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _arg(k: String, d: String = "") -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(k + "="):
			return a.get_slice("=", 1)
	return d


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
	var looks: Array = []
	for l in _arg("looks", "").split(",", false):
		looks.append(LocalEventDrawer.DROP_LOOKS.get(StringName(l.to_upper()), &""))
	if looks.is_empty():
		looks = [LocalEventDrawer.DROP_LOOK]
	for id in sizes:
		n.options.append(id[1])
	Router.show_local()
	await _wait(2.0)
	for look in looks:
		LocalEventDrawer.DROP_LOOK = look
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
			var last := top
			while d.visible and frames < 240:
				await _tree.process_frame
				frames += 1
				var y := d.get_global_rect().position.y
				if look == &"dissolve":
					y = d.panel.get_global_rect().position.y if d.panel != null else y
				worst = maxf(worst, absf(y - last))
				last = y
			_ok("%s, %s (%d px band): gone in %d frames, at most %d px a frame"
					% [look, sizes[si][0], int(band_h), frames, int(worst)],
					not d.visible and worst <= LocalEventDrawer.DROP_MAX_PX + 1.0)
			await _wait(1.0 if film else 0.3)
	print("banddroptest: %s" % ("PASS" if _fails == 0 else "%d FAILURES" % _fails))
	_tree.quit(0 if _fails == 0 else 1)
