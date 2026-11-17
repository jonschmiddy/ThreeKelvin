extends Node

## Korvan's three hulls at grades C to S with their guns on, as the game draws them
## (`ShipView` and a passive `MountPoints`), one still each, and a fight with a medium.
## Windowed, through `tools/dev/render.sh`: `-- nolauncher sheet=GunSheet out=<dir> [fight]`.
## Why: docs/why/Database.md#on-ship-guns

## A typical loadout per weight: [module id, weapon mount index] (`HULL_MOUNTS` order).
const LOADOUT := {
	HullData.Weight.LIGHT: [[&"kh20", 0], [&"kh88", 1]],
	HullData.Weight.MEDIUM: [[&"kh20", 0], [&"km4", 1], [&"kh500", 2]],
	HullData.Weight.HEAVY: [[&"km4", 0], [&"kh40", 1], [&"widow", 3]],
}
const NAMES := ["light", "medium", "heavy"]
## Room round a ship for the guns that stand past its canvas, in screen px.
const MARGIN := Vector2(40, 120)

var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := Harness.arg("out", "user://gunsheet")
	DirAccess.make_dir_recursive_absolute(out)
	await Harness.frames(get_tree(), 5)
	var bg := ColorRect.new()
	bg.color = Color("#10151c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	layer.add_child(bg)
	for w: HullData.Weight in LOADOUT:
		for t in 4:
			await _still(bg, w, t, out)
	if "fight" in OS.get_cmdline_user_args():
		layer.queue_free()
		await _fight(out)
	h.verdict("gunsheet")
	get_tree().quit(h.code())


## One hull at one grade with its loadout, at 2x, cropped to the ship and its guns.
func _still(bg: Control, w: HullData.Weight, t: int, out: String) -> void:
	var hull := DB.at_tier(DB.hull_for(&"korvan", w) as HullData, t)
	var kit: Array[ModuleData] = []
	for e: Array in LOADOUT[w]:
		var m := (DB.modules[e[0]] as ModuleData).duplicate(true) as ModuleData
		m.mount = int(e[1])
		kit.append(m)
	var v := ShipView.new()
	v.self_clip = false
	v.setup_preview(hull, 0, 2)
	v.position = MARGIN
	bg.add_child(v)
	var mp := YardMounts.mount(v, hull, kit)
	await Harness.frames(get_tree(), 4)
	mp.refresh()
	await Harness.frames(get_tree(), 2)
	var guns := 0
	for s: Dictionary in mp.spots():
		if s.held != null and mp.gun_for(s.held, s.slot) != null:
			guns += 1
	var name := "%s_%s" % [NAMES[w], HullData.TIER_NAMES[t]]
	h._ok("%s: %d guns drawn at full size" % [name, kit.size()], guns == kit.size() and mp.drawn == kit.size())
	var parts := mp.parts_rect()
	var ship := Rect2(Vector2.ZERO, Vector2(v.canvas_width(), v.canvas_height()))
	var all := ship.merge(Rect2(parts.position, parts.size))
	print("  %-10s canvas %s  guns %s  over the canvas by top %d, bottom %d, nose %d px (2x)" % [name,
		ship.size, parts, maxi(0, int(-all.position.y)), maxi(0, int(all.end.y - ship.end.y)),
		maxi(0, int(all.end.x - ship.end.x))])
	var img := get_viewport().get_texture().get_image()
	var crop := Rect2i(Rect2(v.global_position + all.position - Vector2(16, 16), all.size + Vector2(32, 32)))
	crop = crop.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(crop).save_png("%s/%s.png" % [out, name])
	v.queue_free()
	await Harness.frames(get_tree(), 1)


## Your medium at grade A in a fight, carrying the medium's loadout.
func _fight(out: String) -> void:
	Run.start_new_run(&"korvan", HullData.Weight.MEDIUM)
	Run.hull = DB.at_tier(DB.hull_for(&"korvan", HullData.Weight.MEDIUM) as HullData, 2)
	Run.installed.clear()
	for e: Array in LOADOUT[HullData.Weight.MEDIUM]:
		var m := (DB.modules[e[0]] as ModuleData).duplicate(true) as ModuleData
		m.mount = int(e[1])
		Run.installed.append(m)
	Run.hp = Run.max_hp()
	Sig.ship_changed.emit()
	var pool := DB.fight_pool(3, false)
	Router.start_combat(DB.enemies[pool[0]])
	# past the system's title card
	await Harness.frames(get_tree(), 900)
	get_tree().root.get_texture().get_image().save_png("%s/fight.png" % out)
	h._ok("fight still taken", FileAccess.file_exists("%s/fight.png" % out))
