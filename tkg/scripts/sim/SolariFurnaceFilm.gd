extends Node

## Solari's three hulls at C and S side by side, as `ShipView` draws them, their furnaces live
## on the game clock (2x on a 1920x1080 window). Windowed, through `render.sh`:
## `--resolution 1920x1080 --fixed-fps 30 --write-movie <dir>/f.avi -- sheet=SolariFurnaceFilm [s=7]`.
## Why: docs/why/SolariFurnace.md#furnace-light

const WEIGHTS := [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]
const COL_W := 480
const TOP := 26

var h := Harness.new()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var secs := float(Harness.arg("s", "7"))
	var bg := ColorRect.new()
	bg.color = Color("#10121a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var y := TOP
	var drawn := 0
	for gi in 2:
		var lab := Label.new()
		lab.text = ["C  worn", "S  clean"][gi]
		lab.position = Vector2(16 + gi * COL_W, 4)
		bg.add_child(lab)
	for w: HullData.Weight in WEIGHTS:
		var row_h := 0
		for gi in 2:
			var hull := DB.at_tier(DB.hull_for(&"solari", w) as HullData, [0, 3][gi])
			var v := ShipView.new()
			v.self_clip = false
			v.setup_preview(hull, 0, 1)
			# the canvas's empty stern is left off the column: the plume reaches into it
			var ink := hull.sprite.get_image().get_used_rect().position.x
			v.position = Vector2(gi * COL_W - ink + 44, y)
			bg.add_child(v)
			row_h = maxi(row_h, hull.sprite.get_height())
			if SolariFurnace.of(HullGrade.key_for(hull), hull.sprite) != null:
				drawn += 1
		y += row_h + 6
	h._ok("%d of 6 hulls carry a furnace" % drawn, drawn == 6)
	await Harness.frames(get_tree(), int(secs * 30.0))
	h.verdict("solarifurnacefilm")
	get_tree().quit(h.code())
