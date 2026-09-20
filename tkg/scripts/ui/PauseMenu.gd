class_name PauseMenu
extends Control
## Escape menu. Overlays the game rather than replacing it, so the run behind it
## stays intact and visible — the ship never disappears, which is the same rule
## the encounter layout follows.
##
## A DRAWER DOWN THE LEFT EDGE, built from Jon's picks across four rounds of
## mockups: the drawer itself (over a centred box of full-width buttons that
## read as a different game), the CHART INSET version of it ("clean"), and
## chamfered plates with a second line under each label and a doubled-pixel
## icon. It says where you are before it asks what next.
##
## Built in code against UITheme like every other screen. Nothing here pauses
## the tree: the game is turn-based and advances only on input, and this
## control swallows every click. It lives on Main's overlay layer -- see
## `Main._overlay` for why.

signal resume_requested
signal quit_requested
signal save_and_quit_requested

const DRAWER_W := 290.0
const SIDE := 20
## TIMED TO THE SOUNDS. `menu_open` is a rising whoosh that snaps at 0.21 s, so
## the drawer accelerates in and lands on the snap; the game behind keeps
## breaking up a little longer. `menu_close` hits hardest at 0.14 s, and the
## drawer is gone on that hit (Jon: "the big plink ... should match when the
## drawer is 100% gone"). Measured off the files; change them with the sounds.
const OPEN_S := 0.21
const BACKDROP_S := 0.5
const CLOSE_S := 0.14
const INSET_H := 92.0
## The chart inset's zoom. Close enough that the systems around you read as
## places, far enough that the nearest of them are in the frame.
const INSET_ZOOM := 3.0
const BACKDROP := preload("res://shaders/pause_backdrop.gdshader")

var _drawer: Control
var _mat: ShaderMaterial
var _closing := false
## The drawer's own contents, and Settings when it is swapped in over them.
var _main: Control
var _pad: Control
var _settings: SettingsPanel
var _exits: VBoxContainer
const SWAP_S := 0.1

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Swallow clicks so the screen underneath cannot be interacted with.
	mouse_filter = Control.MOUSE_FILTER_STOP

	# The run behind, pixelated, split and darkened (see the shader). Present
	# but plainly not live: the drawer is the only sharp thing on screen.
	var scrim := ColorRect.new()
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = BACKDROP
	scrim.material = mat
	_mat = mat
	add_child(scrim)

	var drawer := PanelContainer.new()
	drawer.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	drawer.offset_right = DRAWER_W
	var face := UITheme.flat(UITheme.PANEL, Color(0, 0, 0, 0), 0, 0, 0)
	face.border_width_right = 1
	face.border_color = UITheme.BEVEL_HI
	face.shadow_color = Color(0, 0, 0, 0.35)
	face.shadow_size = 12
	drawer.add_theme_stylebox_override("panel", face)
	add_child(drawer)
	_drawer = drawer

	var pad := Widgets.pad(null, SIDE, 20)
	drawer.add_child(pad)
	_pad = pad
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	pad.add_child(col)
	_main = col

	# PAUSED on an ember tab, then the name. The tab is the one loud thing in the
	# drawer: it is what tells you the game is not running.
	var tab := PanelContainer.new()
	tab.add_theme_stylebox_override("panel", UITheme.flat(UITheme.EMBER, Color(0, 0, 0, 0), 0, 3, 5))
	tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tab.add_child(UITheme.body("PAUSED", UITheme.VOID, UITheme.FS_SMALL))
	col.add_child(tab)
	col.add_child(UITheme.body("THREE KELVIN", UITheme.ICE, UITheme.FS_HEAD))

	if Run.hull != null and not Run.map.is_empty():
		# The order Jon asked for: where you are, then how deep, then what you
		# are flying, then the three numbers.
		col.add_child(_inset())
		col.add_child(_ladder())
		col.add_child(_gap(2))
		col.add_child(_ship())
		col.add_child(_gap(2))
		col.add_child(_tiles())
		col.add_child(_gap(2))

	var resume := DrawerPlate.plate(&"resume", "RESUME",
		"BACK TO THE FIGHT" if Router.in_combat() else "BACK TO THE SHIP",
		func() -> void: resume_requested.emit())
	resume.tone = DrawerPlate.Tone.GOOD
	col.add_child(resume)
	col.add_child(DrawerPlate.plate(&"settings", "SETTINGS", "SOUND, DISPLAY, CONTROLS",
		func() -> void: show_settings()))

	# Everything that leaves the run is pinned to the bottom.
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(fill)

	_exits = VBoxContainer.new()
	_exits.add_theme_constant_override("separation", 4)
	col.add_child(_exits)
	_show_exits()

	# In from the edge, with the game breaking up behind. Not under a shot tool
	# or the sim: a menu that is still arriving would be photographed half off
	# the screen.
	if Router.animating():
		drawer.position.x = -DRAWER_W - 16.0
		mat.set_shader_parameter(&"amount", 0.0)
		var tw := create_tween().set_parallel(true)
		# EASE IN: the sound accelerates into its snap, so the drawer does too.
		tw.tween_property(drawer, "position:x", 0.0, OPEN_S) 			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"amount", v),
			0.0, 1.0, BACKDROP_S).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## THE TWO WAYS OUT, and the difference between them is the whole save model.
## SAVE & EXIT writes a bookmark you resume from once; the other throws the run
## away. The autosave means the first is what happens anyway if the process
## dies — this button exists so the player knows that. (There were three.
## ABANDON RUN — START OVER went: it was ABANDON with one screen skipped, and
## the title is one click from a new run anyway.)
##
## Both land on the TITLE SCREEN rather than closing the game. Leaving a run and
## leaving the program are different intentions, and the title screen is where
## the answer to "what now" lives — including CONTINUE, which is the thing
## SAVE & EXIT just created.
##
## Mid-fight, the fight starts over when you come back: combat is outside the
## save, so the run on disk is the one from before it, and SaveGame.mark_fight
## notes which fight to restart.
func _show_exits() -> void:
	Widgets.clear(_exits)
	var fighting := Router.in_combat()
	var save := DrawerPlate.plate(&"save", "SAVE & EXIT TO TITLE",
		"THE FIGHT STARTS OVER" if fighting else "PICK UP HERE LATER",
		func() -> void: confirm(false))
	save.tone = DrawerPlate.Tone.GOOD
	_exits.add_child(save)
	var abandon := DrawerPlate.plate(&"abandon", "ABANDON — EXIT TO TITLE", "THIS RUN ENDS",
		func() -> void: confirm(true))
	abandon.tone = DrawerPlate.Tone.BAD
	_exits.add_child(abandon)

## NEITHER WAY OUT HAPPENS ON ONE CLICK. Both end the run you are in -- one
## keeps it on disk and one does not -- so both ask first, in place of the two
## buttons rather than in a box over them (Jon: "just to give user consent
## before ending a run").
func confirm(destroys: bool) -> void:
	Widgets.clear(_exits)
	var fighting := Router.in_combat()
	var ask := UITheme.body("ABANDON THIS RUN?" if destroys else "SAVE AND LEAVE?",
		UITheme.ICE, UITheme.FS_SMALL)
	_exits.add_child(ask)
	var why := "SHIP, CARGO AND MAP GONE. IT GOES ON THE RECORD."
	if not destroys:
		why = "CONTINUE FROM THE TITLE. THE FIGHT STARTS OVER." if fighting 			else "CONTINUE FROM THE TITLE, WHERE YOU LEFT OFF."
	var note := UITheme.body(why, UITheme.COLD, UITheme.FS_SMALL)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_exits.add_child(note)
	var yes := DrawerPlate.plate(&"abandon" if destroys else &"save",
		"YES, ABANDON" if destroys else "YES, SAVE AND EXIT", "",
		func() -> void:
			if destroys:
				quit_requested.emit()
			else:
				save_and_quit_requested.emit())
	yes.tone = DrawerPlate.Tone.BAD if destroys else DrawerPlate.Tone.GOOD
	_exits.add_child(yes)
	# Grey, not green: backing out is not a choice, it is the absence of one.
	# Colour here would make the two answers compete (Jon).
	_exits.add_child(DrawerPlate.plate(&"resume", "NO, KEEP PLAYING", "", _show_exits))


## SETTINGS IN THE SAME DRAWER. The menu's contents fade out and Settings fades
## in where they were -- same drawer, same backdrop, nothing re-rendered on top.
## A MarginContainer lays every child over the same rect, so both are simply
## children of the pad and only one is visible.
func show_settings() -> void:
	if _settings != null or _closing:
		return
	_settings = SettingsPanel.new()
	_settings.build()
	_settings.back_requested.connect(hide_settings)
	_swap(_main, _settings)

func hide_settings() -> void:
	if _settings == null:
		return
	Audio.back()
	var s := _settings
	_settings = null
	_swap(s, _main, true)

func in_settings() -> bool:
	return _settings != null

func _swap(from: Control, to: Control, free_from: bool = false) -> void:
	if to.get_parent() == null:
		_pad.add_child(to)
	to.visible = true
	if not Router.animating():
		from.visible = false
		to.modulate.a = 1.0
		if free_from:
			from.queue_free()
		return
	to.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(from, "modulate:a", 0.0, SWAP_S)
	tw.tween_callback(func() -> void:
		from.visible = false
		if free_from:
			from.queue_free())
	tw.tween_property(to, "modulate:a", 1.0, SWAP_S)

## Out the way it came, and gone on the close sound's hit. The game sharpens as
## it goes. Instant under shot tools and the sim, and when leaving the run --
## `Main` frees the menu outright for those.
func close() -> void:
	if _closing:
		return
	_closing = true
	if not Router.animating():
		queue_free()
		return
	var from := _mat.get_shader_parameter(&"amount") as float
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(_drawer, "position:x", -DRAWER_W - 16.0, CLOSE_S)
	tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter(&"amount", v),
		from, 0.0, CLOSE_S)
	tw.chain().tween_callback(queue_free)


## The star chart around you: the chart's own MapChart, not a picture of it, so
## it is the real galaxy at this moment, with the reticle on your ship and the
## galaxy and sector printed in its corner.
func _inset() -> Control:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", UITheme.flat(Color.BLACK, UITheme.LINE, 0, 1, 1))
	var box := Control.new()
	box.custom_minimum_size = Vector2(0, INSET_H)
	box.clip_contents = true
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(box)
	var chart := StarchartScreen.MapChart.new()
	chart.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	chart.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chart.free_pan = true
	chart.show_scale = false
	# MapChart asks for 220 px of height (it is sized for the chart screen); in
	# a 132 px box that drew it taller than its frame and centred it off-screen.
	chart.custom_minimum_size = Vector2.ZERO
	box.add_child(chart)
	# Framed once it has a size: centring reads `size`, which is zero until the
	# container has laid the inset out.
	var over := InsetMarks.new()
	over.chart = chart
	over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(over)
	chart.resized.connect(func() -> void:
		if chart.size.x > 0.0 and Run.node_at() != null:
			chart.center_on_ship(INSET_ZOOM)
			over.queue_redraw())
	# On a dark plate, so a star behind the name does not run through it.
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UITheme.flat(Color(UITheme.VOID, 0.8), Color(0, 0, 0, 0), 0, 4, 5))
	plate.position = Vector2(1, INSET_H - 38)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var lab := VBoxContainer.new()
	lab.add_theme_constant_override("separation", 3)
	lab.add_child(UITheme.body(Run.galaxy_title.to_upper(), UITheme.ICE, UITheme.FS_SMALL))
	var here: MapGen.MapNode = Run.node_at()
	if here != null:
		lab.add_child(UITheme.body(MapGen.star_name(here).to_upper(), UITheme.COLD, UITheme.FS_SMALL))
	plate.add_child(lab)
	box.add_child(plate)
	return frame

## The ship, as the ship screen names it: what you call it, who built it, what
## frame it is, and what it deals you a turn.
func _ship() -> Control:
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UITheme.flat(Color(0, 0, 0, 0), UITheme.LINE, 0, 7, 7))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	box.add_child(v)
	var m: ManufacturerData = DB.manufacturers.get(Run.hull.manufacturer)
	# WHAT THE PLAYER CALLS IT. `Run.display_name` is the one function that
	# answers that -- the name you gave the ship, the frame's own until you do
	# (Jon: "user's name of the ship should be here"). The tier goes beside it
	# rather than in front, since a named ship is not "C-TIER ODYSSEY".
	var top := HBoxContainer.new()
	var name := UITheme.body(Run.display_name().to_upper(), UITheme.ICE, UITheme.FS_SMALL)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.clip_text = true
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(name)
	top.add_child(UITheme.body("%s TIER" % Run.hull.tier_letter(),
		m.colour if m != null else UITheme.CHILL, UITheme.FS_SMALL))
	v.add_child(top)
	v.add_child(UITheme.body(m.name.to_upper() if m != null else "UNBRANDED SALVAGE",
		m.colour if m != null else UITheme.CHILL, UITheme.FS_SMALL))
	v.add_child(UITheme.body("%s CHASSIS · %d CARDS A TURN · %d IN DECK" % [
		HullData.weight_name(Run.hull.weight).to_upper(), Run.hand_size(), Run.deck_size()],
		UITheme.COLD, UITheme.FS_SMALL))
	return box

## How deep, as the chart's own layer strip: one cell a layer, lit to here.
func _ladder() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var here: MapGen.MapNode = Run.node_at()
	var at := 0 if here == null else here.layer
	var row := HBoxContainer.new()
	var k := UITheme.body("LAYER", UITheme.COLD, UITheme.FS_SMALL)
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(k)
	row.add_child(UITheme.body("%d / %d" % [at + 1, MapGen.LAYERS], UITheme.ICE, UITheme.FS_SMALL))
	v.add_child(row)
	var cells := HBoxContainer.new()
	cells.add_theme_constant_override("separation", 2)
	for i in MapGen.LAYERS:
		var c := ColorRect.new()
		c.custom_minimum_size = Vector2(0, 6)
		c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		c.color = UITheme.EMBER if i <= at else UITheme.LINE
		cells.add_child(c)
	v.add_child(cells)
	return v

## The three numbers you would check before leaving.
func _tiles() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	var low := Run.hp < Run.max_hp() * 0.35
	for pair in [["HULL", "%d/%d" % [Run.hp, Run.max_hp()], Color("#d4614f") if low else UITheme.ICE],
			["CREDITS", str(Run.credits), UITheme.ICE], ["FUEL", str(Run.fuel), UITheme.ICE]]:
		var t := PanelContainer.new()
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.add_theme_stylebox_override("panel", UITheme.flat(Color(0, 0, 0, 0), UITheme.LINE, 0, 6, 6))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		v.add_child(UITheme.body(pair[0], UITheme.COLD, UITheme.FS_SMALL))
		v.add_child(UITheme.body(pair[1], pair[2], UITheme.FS_SMALL))
		t.add_child(v)
		h.add_child(t)
	return h

func _gap(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


## The reticle on the inset: the chart's dashed crosshair, on your ship.
##
## ON THE SHIP, NOT THE MIDDLE. The chart will not pan past the galaxy's rim,
## so near the edge `center_on_ship` cannot put you in the centre -- and a
## reticle on the centre then marks empty space beside you.
class InsetMarks extends Control:
	var chart: StarchartScreen.MapChart

	func _draw() -> void:
		var here: MapGen.MapNode = Run.node_at()
		if chart == null or here == null:
			return
		var c := chart._screen_pos(here).floor()
		var col := Color(UITheme.ICE, 0.25)
		var x := 0.0
		while x < size.x:
			draw_rect(Rect2(x, c.y, minf(2.0, size.x - x), 1.0), col)
			x += 5.0
		var y := 0.0
		while y < size.y:
			draw_rect(Rect2(c.x, y, 1.0, minf(2.0, size.y - y)), col)
			y += 5.0
