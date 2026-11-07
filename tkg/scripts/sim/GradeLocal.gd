extends Node

## Parks a graded hull on LOCAL with lights live; the log shows the art name and grade key.
## Why: docs/why/GradeLocal.md#graded-hull

var _args: PackedStringArray


func _ready() -> void:
	_args = OS.get_cmdline_user_args()
	_run.call_deferred()


func _arg(k: String, d: String = "") -> String:
	for a in _args:
		if a.begins_with(k + "="):
			return a.substr(k.length() + 1)
	return d


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	Rng.forced = int(_arg("seed", "4242"))
	var weights := {"light": HullData.Weight.LIGHT, "medium": HullData.Weight.MEDIUM, "heavy": HullData.Weight.HEAVY}
	var w: HullData.Weight = weights.get(_arg("weight", "medium"), HullData.Weight.MEDIUM)
	var mk := StringName(_arg("manufacturer", "korvan"))
	Run.start_new_run(mk, int(w))
	Run.fit_chassis(mk, w, int(_arg("grade", "3")))
	print("  hull %s tier %d, art %s, key '%s'" % [Run.hull.name, Run.hull.tier,
		DB.hull_art_key(Run.hull.weight, Run.hull.tier, Run.hull.manufacturer), HullGrade.key_for(Run.hull)])
	Router.show_local()
	var frame := 0
	for i in 60 * 30:
		await tree.process_frame
		frame += 1
		var sc := Router.current as SectorScreen
		var art: ShipView = sc._view.ship_view() if sc != null and sc._view != null else null
		if art != null and art._arrive_at < 0 and art.visible:
			break
	print("mark parked %d" % frame)
	await get_tree().create_timer(float(_arg("hold", "4"))).timeout
	tree.quit()
