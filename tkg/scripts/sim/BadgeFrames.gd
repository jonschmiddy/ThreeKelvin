extends Node

## Names and clock match `dump_golden.py` so `diff_frames.py` can compare game and web.
## Why: docs/why/BadgeFrames.md#badge-frames

var _tree: SceneTree


func _ready() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await _tree.process_frame


func _out() -> String:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			return a.substr(4)
	return ""


func _run() -> void:
	_tree = get_tree()
	var out := _out()
	if out == "":
		print("badgeframes: give out=<dir>")
		_tree.quit(2)
		return
	DirAccess.make_dir_recursive_absolute(out)
	await _frames(2)
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	await _frames(40)
	var g: GoalLine = Router.hud.goal
	var b := g.badge()
	var list: Array = []
	for j: int in [1, 10, 15, 16, 18, 20, 28, 35]:
		var rate := float(CustodianBadge.idle_of(j, 0.0, -1.0).rate)
		for n in 16:
			list.append({name = "j%02d_idle_%02d.png" % [j, n], j = j, t = (float(n) + 0.5) / rate, since = -1.0, what = "idle %d" % n})
	for j: int in [12, 16, 20, 25, 33]:
		var steps: int = CustodianBadge.TRANS_STEPS[CustodianBadge.change_kind(j)]
		var rate := float(CustodianBadge.idle_of(j, 0.0, -1.0).rate)
		for s in steps:
			var since := (float(s) + 0.5) / 10.0
			list.append({name = "j%02d_arrive_%02d.png" % [j, s], j = j, t = since, since = since, what = "arrive %d/%d" % [s, steps]})
		var after := float(steps) / 10.0 + 0.5 / rate
		list.append({name = "j%02d_arrive_%02d.png" % [j, steps], j = j, t = after, since = after, what = "after 0"})
	var wrote := 0
	for f: Dictionary in list:
		Run.jumps = int(f.j)
		Run.custodian_seen = int(f.j)
		b.fixed = {t = float(f.t), since = float(f.since)}
		g.refresh()
		var img := b.image()
		if img == null or not b.is_visible_in_tree():
			print("badgeframes: the badge is not up at jump %d" % int(f.j))
			_tree.quit(1)
			return
		if img.save_png(out.path_join(String(f.name))) == OK:
			wrote += 1
	b.fixed = {}
	var manifest := {source = "game (-- sheet=BadgeFrames)", w = CustodianBadge.IMG_W, h = CustodianBadge.IMG_H, x = 0, cy = 7, frames = list}
	var fa := FileAccess.open(out.path_join("manifest.json"), FileAccess.WRITE)
	fa.store_string(JSON.stringify(manifest, " "))
	fa.close()
	print("badgeframes: wrote %d PNGs and manifest.json to %s" % [wrote, out])
	_tree.quit(0 if wrote == list.size() else 1)
