extends Node

## Korvan's three hulls at grades C to S with their guns on, as the game draws them
## (`ShipView` and a passive `MountPoints`), one still each, and a fight with a medium.
## Windowed (`render.sh`): `-- nolauncher sheet=GunSheet out=<dir> [fight] [manufacturer=solari]`;
## `ids=beam,slug,torch` instead: each on the medium's top and belly mount, and a Korvan still.
## Why: docs/why/Database.md#on-ship-guns

## A typical loadout per weight: [module id, weapon mount index] (`HULL_MOUNTS` order).
const LOADOUT := {
	HullData.Weight.LIGHT: [[&"kh20", 0], [&"kh88", 1]],
	HullData.Weight.MEDIUM: [[&"km4", 0], [&"kh20", 1], [&"kh500", 2]],
	HullData.Weight.HEAVY: [[&"km4", 0], [&"kh40", 1], [&"widow", 2]],
}
## Solari's, a weapon on every mount the S grade opens.
const SOLARI := {
	HullData.Weight.LIGHT: [[&"emberlance", 0], [&"sparkthrower", 1], [&"sunspot", 2]],
	HullData.Weight.MEDIUM: [[&"emberlance", 0], [&"sunspot", 1], [&"plasma", 2], [&"sparkthrower", 3]],
	HullData.Weight.HEAVY: [[&"emberlance", 0], [&"overpressure", 1], [&"heliostat", 2], [&"sunspot", 3], [&"plasma", 4]],
}
const NAMES := ["light", "medium", "heavy"]
## Room round a ship for the guns that stand past its canvas, in screen px.
const MARGIN := Vector2(40, 120)

var h := Harness.new()
var _vp: SubViewport
var _mf: StringName = &"korvan"


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := Harness.arg("out", "user://gunsheet")
	_mf = StringName(Harness.arg("manufacturer", "korvan"))
	DirAccess.make_dir_recursive_absolute(out)
	await Harness.frames(get_tree(), 5)
	var bg := ColorRect.new()
	bg.color = Color("#10151c")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# its own viewport, wider than the game's: a heavy at 2x with a spinal past its nose
	var layer := SubViewport.new()
	layer.size = Vector2i(1400, 720)
	layer.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(layer)
	layer.add_child(bg)
	_vp = layer
	var ids := Harness.arg("ids")
	if ids != "":
		var m := HullData.Weight.MEDIUM
		for id in ids.split(","):
			await _still(bg, m, 3, out, _kit(m, 3, [[StringName(id), 0], [StringName(id), 2]]), id)
		await _still(bg, m, 3, out, _kit(m, 3, [[&"km4", 0], [&"kh20", 1], [&"km4", 2], [&"kh20", 3]]), "korvan")
		h.verdict("gunsheet")
		get_tree().quit(h.code())
		return
	var loadout: Dictionary = SOLARI if _mf == &"solari" else LOADOUT
	for w: HullData.Weight in loadout:
		for t in 4:
			await _still(bg, w, t, out, _kit(w, t, loadout[w]))
		# the worst case: on every mount of the top grade, the longest gun it takes
		if _mf == &"korvan":
			await _still(bg, w, 3, out, _worst(w), "worst")
	if "fight" in OS.get_cmdline_user_args():
		layer.queue_free()
		await _fight(out)
	h.verdict("gunsheet")
	get_tree().quit(h.code())


func _kit(_w: HullData.Weight, _t: int, rows: Array) -> Array[ModuleData]:
	var kit: Array[ModuleData] = []
	for e: Array in rows:
		var m := (DB.modules[e[0]] as ModuleData).duplicate(true) as ModuleData
		m.mount = int(e[1])
		kit.append(m)
	return kit


## Korvan's longest gun each mount takes, by its picture's width on that side.
func _worst(w: HullData.Weight) -> Array[ModuleData]:
	var hull := DB.at_tier(DB.hull_for(_mf, w) as HullData, 3)
	var rows: Array = []
	for i in hull.slots_for(ModuleData.Slot.WEAPON):
		var best: StringName = &""
		var best_w := -1.0
		for id: StringName in ShipGun.ids():
			var m := DB.modules.get(id) as ModuleData
			var g := ShipGun.of(id, hull.gun_sides[i])
			if m != null and g != null and g.size().x > best_w:
				best = id
				best_w = g.size().x
		if best != &"":
			rows.append([best, i])
	return _kit(w, 3, rows)


## One hull at one grade with its loadout, at 2x, cropped to the ship and its guns.
func _still(bg: Control, w: HullData.Weight, t: int, out: String, kit: Array[ModuleData], tag: String = "") -> void:
	var hull := DB.at_tier(DB.hull_for(_mf, w) as HullData, t)
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
	var name := "%s_%s" % [NAMES[w], tag if tag != "" else HullData.TIER_NAMES[t]]
	# (a hull without gun sides draws its weapons' hold pictures)
	# (a grade below S opens fewer mounts: a weapon on a closed one is not drawn)
	var want := 0
	var fits := 0
	for m in kit:
		if m.mount >= hull.slots_for(ModuleData.Slot.WEAPON):
			continue
		fits += 1
		if not hull.gun_sides.is_empty() and ShipGun.of(m.id, hull.gun_sides[m.mount]) != null:
			want += 1
	h._ok("%s: %d weapons drawn, %d with an on-ship picture" % [name, kit.size(), want], guns == want and mp.drawn == fits)
	var parts := mp.parts_rect()
	var ship := Rect2(Vector2.ZERO, Vector2(v.canvas_width(), v.canvas_height()))
	var all := ship.merge(Rect2(parts.position, parts.size))
	print("  %-10s canvas %s  guns %s  over the canvas by top %d, bottom %d, nose %d px (2x)" % [name,
		ship.size, parts, maxi(0, int(-all.position.y)), maxi(0, int(all.end.y - ship.end.y)),
		maxi(0, int(all.end.x - ship.end.x))])
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	var crop := Rect2i(Rect2(v.global_position + all.position - Vector2(16, 16), all.size + Vector2(32, 32)))
	crop = crop.intersection(Rect2i(Vector2i.ZERO, img.get_size()))
	img.get_region(crop).save_png("%s/%s.png" % [out, name])
	# the picture the ship-loss breakup cuts, guns and all
	if t == 3 and tag == "":
		var pic := ShipLoss.picture(v)
		if not pic.is_empty():
			(pic.img as Image).save_png("%s/%s_loss.png" % [out, NAMES[w]])
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
