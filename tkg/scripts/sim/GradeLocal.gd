extends Node

## A GRADED HULL WHERE IT IS SEEN: your ship refitted to a Korvan frame at one
## grade and parked on LOCAL, its lights live.
##   godot --path . --resolution 1920x1080 --write-movie <dir>/f.png --fixed-fps 30
##       -- sheet=GradeLocal [weight=medium] [grade=0..3] [hold=4] [seed=N] [maker=solari]
## `maker=` puts that manufacturer's picture on the hull, bare: its parts and
## flame are still placed for Korvan's shape, so they are taken off.
## Prints `mark parked <frame>` so the film's held stretch can be cut out, and
## the hull's art name and grade key, so a wrong base shows in the log.

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
	Run.start_new_run(&"korvan", int(w))
	Run.fit_chassis(&"korvan", w, int(_arg("grade", "3")))
	var mk := _arg("maker", "")
	if mk != "":
		var path := "res://art/sprites/hulls/%s/hull_%s_a.png" % [mk, _arg("weight", "medium")]
		Run.hull.sprite = load(path) as Texture2D
		Run.hull.sprite_half = null
		Run.hull.thrusters = []
		Run.installed.clear()
		Sig.ship_changed.emit()
	print("  hull %s tier %d, art %s, key '%s'" % [Run.hull.name, Run.hull.tier,
		DB.hull_art_name(Run.hull.weight, Run.hull.tier), HullGrade.key_for(Run.hull)])
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
