class_name EnemySlot
extends Control

## Brace as countable cells, sitting on the hull bar.
##
## Brace was a small bar with "2 ARMOR" written under it, which is a bar doing
## a number's job and a number doing a bar's. Brace values are small and every
## point is one hit's worth of nothing happening — so what matters is HOW MANY,
## exactly, the same reason heat and energy are cells rather than bars. Read
## them and the label is redundant; the label goes.
class BracePips extends Control:
	const CELL := Vector2(6, 4)
	const GAP := 1
	var value: int = 0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		custom_minimum_size = Vector2(0, CELL.y)

	func set_value(v: int) -> void:
		if v == value:
			return
		value = maxi(0, v)
		queue_redraw()

	func _draw() -> void:
		if value <= 0:
			return
		# Centred over the hull bar below, so the two read as one stack.
		var n: int = mini(value, 14)
		var w: float = n * CELL.x + (n - 1) * GAP
		var x: float = (size.x - w) * 0.5
		for i in n:
			draw_rect(Rect2(Vector2(x + i * (CELL.x + GAP), 0), CELL),
				EnemySlot.ARMOR_COL, true)
		# More than the strip can hold says so rather than lying about the count.
		if value > n:
			draw_rect(Rect2(Vector2(x + w + 2, 1), Vector2(2, CELL.y - 2)),
				EnemySlot.ARMOR_COL, true)

## One enemy in the encounter, and the thing you drop a card onto to target it.
##
## The slot owns the art, the name and the health bar together so a target is a
## single object on screen rather than a sprite here and a readout somewhere
## else. Dropping a card here aims it; hovering shows what it would land.

signal card_dropped(index: int, view: CardView)
signal hovered(index: int, entered: bool)

var index: int = 0
var art: EnemyArt
var _name: Label
var _hp: Label
## Status chips for this enemy, filled by the screen that owns the Combat.
var chips: HBoxContainer
var _intent: Label
var _intent_text: Label
## How wide a ship's readout is, regardless of how much arena it was given.
const BAR_W := 120

var _bar: ProgressBar
var _brace_bar: BracePips
## Gives `art` a position of its own that the column does not overwrite.
var _art_holder: Control
## Steel, so it never reads as a second kind of hull.
const ARMOR_COL := Color("#9fb0c4")
var _hot: bool = false
## Told by the view when another slot takes the cursor.
var claim: Callable
var _dead: bool = false
## The hull this slot SHOWS, when the screen is holding a number back until the
## shot that changed it lands (combat polish, Oct 13). -1 shows the real one.
var shown_hp: int = -1
## Which `ShipBreakup` style this ship dies in (or died in), so a dead slot
## draws the wreck that death left. -1: its pool's first.
var death_style: int = -1
## Where the art sits at rest inside its holder. The holder is the ship's own
## box (`_fit_holder`), not the canvas, so the canvas, drawn centred, sits at a
## negative offset inside it.
var _art_base: Vector2 = Vector2.ZERO
## The entrance in flight, and when it lands: a holder that resizes mid-flight
## (the ship's picture arriving after `enter`) sends it to the new resting place.
var _enter_tw: Tween
var _enter_end: int = 0
## How far this slot's column sits off the row's middle, down positive: a pack
## no longer used: packs are placed by `EncounterView._layout_pack`.
var _lift_top: Control
var _lift_bot: Control
## The column everything hangs in, the bars' box, and -- in a column pack (layout
## C) -- the row that puts the readout beside the ship instead of under it.
var _col: VBoxContainer
var _bars: VBoxContainer
var _side_row: HBoxContainer
var _side_box: VBoxContainer
var side: bool = false

## The idle drift: whole pixels, up and down, so a contact reads as floating
## rather than pinned to the panel.
##
## Done by MOVING THE ART, which `ShipView` explicitly cannot do -- its note says
## animating the Control's position "would fight the containers every screen puts
## this inside", so it bobs inside its own canvas instead. This one can, because
## the entrance already gave the art a plain holder to move in, and moving a
## Control is far cheaper than regenerating an image eight times a second.
##
## Slower and shallower than your ship's `bob(2)`: they are further away, and a
## pack drifting in step reads as one object rather than three ships. The phase
## comes off the slot index for the same reason.
const BOB_AMP := 2.0
const BOB_HZ := 0.21
var _bob_phase: float = 0.0

## How far off to starboard a contact starts when it engages.
##
## Past the edge of the SCREEN rather than the edge of the slot: it should look
## like it came from somewhere, and a ship that slides in from half a slot away
## reads as a rendering fault rather than as an approach.
const ENTER_FROM := 520.0
const ENTER_SECS := 0.5


## Fly in, as the fight opens.
##
## Your own approach is `ShipView.arrive()` and is deliberately NOT played when
## a fight starts -- you were already here, parked. The contact was not: it is
## the thing that just turned up, so it is the thing that moves.
## Where the brackets go, in screen space. For `-- sectorshot entrance`, which
## checks it against the art's own rect -- the two are the same box, and the
## reticle is wrong the moment they stop being.
func holder_rect() -> Rect2:
	return Rect2(_art_holder.global_position, _art_holder.size)


func _process(_dt: float) -> void:
	if _art_holder == null:
		return
	# ROUNDED. A sub-pixel offset resamples the sprite and undoes the
	# nearest-neighbour crispness the whole art direction rests on.
	var t := float(Time.get_ticks_msec()) / 1000.0
	art.position.y = _art_base.y + roundf(sin((t + _bob_phase) * TAU * BOB_HZ) * BOB_AMP)


func enter(delay: float = 0.0) -> void:
	if _art_holder == null:
		return
	art.position.x = _art_base.x + ENTER_FROM
	# THE READOUT ARRIVES WITH THE SHIP. The name and the hull bar belong to the
	# slot rather than to the art, so they do not move -- and a bar sitting at
	# full for a ship that is still off-screen reads as a rendering fault. Fading
	# the whole slot up over the same window keeps the two halves one event.
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, ENTER_SECS * 0.7) 		.set_delay(delay)
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(art, "position:x", _art_base.x, ENTER_SECS)
	_enter_tw = tw
	_enter_end = Time.get_ticks_msec() + int((delay + ENTER_SECS) * 1000.0)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(true)
	var col := VBoxContainer.new()
	col.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# One pixel. Everything in this column belongs to the ship in the middle of
	# it — intent above, name and bars below — and a gap wide enough to notice is
	# a gap that makes them look like separate readouts that happen to line up.
	col.add_theme_constant_override("separation", 1)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Behind this slot's own _draw. A Control paints itself first and its
	# children after, so the damage number was being drawn and then buried under
	# the ship, the name and the health bar it was meant to sit over.
	col.show_behind_parent = true
	add_child(col)
	_col = col
	_lift_top = Control.new()
	_lift_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lift_top.visible = false
	col.add_child(_lift_top)

	# What THIS one is about to do, over its own hull. One strip at the bottom
	# of the screen could only ever name a turn's worth of intent for the whole
	# pack — with two enemies it printed "Lancer: Strafe   Hulk: Ram", which is
	# a sentence you parse rather than a thing you see. Above each ship it is
	# just a label on the thing it describes.
	# The move, then what the move does. The name alone tells you a Lancer is
	# about to Strafe, which is only useful if you already know what a Strafe
	# costs you — and the number underneath is the half you actually plan
	# against.
	_intent = UITheme.body("", UITheme.THEM, UITheme.FS_SMALL)
	_intent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_intent)
	col.move_child(_intent, 0)
	_intent_text = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	_intent_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intent_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_intent_text)
	col.move_child(_intent_text, 1)

	# The column centres itself and the art stops expanding, so name and bars
	# sit directly under the ship instead of being shoved to the floor of a slot
	# that happens to be tall. A health bar half a screen below its ship is a
	# health bar you have to go looking for.
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	art = EnemyArt.new()
	# No custom_minimum_size here. EnemyArt already declares its own native
	# W x H and draws the ship at 1:1 inside it — overriding that with a width
	# of zero let the Control stretch to whatever share of the arena the slot
	# had, which is what the reticle was then framing. Shrink on both axes and
	# the Control is the ship's own box.
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A PLAIN CONTROL BETWEEN THE ART AND THE COLUMN, so the art has a position
	# of its own to animate. A container child's position belongs to the
	# container -- it is rewritten on the next sort -- so `enter()` tweening it
	# directly would hold until the next layout pass and then snap back.
	# `ShipView` needs none of this because its slot is not a container.
	#
	# The holder is what the column measures, so the size flags move onto it and
	# the art fills it.
	_art_holder = Control.new()
	_art_holder.custom_minimum_size = Vector2(EnemyArt.W, EnemyArt.H)
	_art_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_art_holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_art_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_holder.clip_contents = false
	# SIZED, NOT ANCHORED. A full-rect preset would tie the art's position to
	# the holder's edges, and Godot recomputes an anchored control's position
	# whenever its parent resizes -- which the holder does on the first layout
	# pass, a frame after `enter()` has already put the ship off-screen. Free
	# position, fixed size: the same shape `ShipView` gets for free.
	art.size = Vector2(EnemyArt.W, EnemyArt.H)
	_art_holder.add_child(art)
	col.add_child(_art_holder)

	_name = UITheme.body("", UITheme.THEM, UITheme.FS_SMALL)
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_name)
	# Bars sized to the SHIP, not to the slot.
	#
	# The slot expands to share the arena, so a lone enemy owned the full width
	# and its health bar with it — a seven-hundred-pixel readout for one
	# freighter. A health bar belongs to the thing it measures: read at a
	# glance, its length should say how much is left, not how much room the
	# layout had. Centred in a fixed BAR_W so two enemies read the same as one.
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override("separation", 1)
	bars.custom_minimum_size = Vector2(BAR_W, 0)
	bars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	bars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(bars)
	_bars = bars

	# Brace ON TOP, hull beneath — the order damage goes through them. Brace is
	# a second pool that has to be chewed away before the first one moves, so it
	# gets a bar rather than a chip: that is what a second bar says and what a
	# word and a number do not.
	_brace_bar = BracePips.new()
	_brace_bar.custom_minimum_size = Vector2(BAR_W, BracePips.CELL.y)
	_brace_bar.visible = false
	bars.add_child(_brace_bar)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(BAR_W, 6)
	_bar.show_percentage = false
	bars.add_child(_bar)
	# Both numbers on one line, each in the colour of the bar it belongs to —
	# so the pair reads as two pools rather than as one stat with a prefix.
	_hp = UITheme.body("", UITheme.GOOD, UITheme.FS_SMALL)
	_hp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_hp)

	# Whatever this one is carrying — block, a charge, a debuff — under its own
	# hull. In a pack, a chip row at the bottom of the screen has to name which
	# ship it belongs to before it can say anything; here the position says it.
	chips = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 3)
	chips.alignment = BoxContainer.ALIGNMENT_CENTER
	chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(chips)
	_lift_bot = Control.new()
	_lift_bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lift_bot.visible = false
	col.add_child(_lift_bot)

	mouse_entered.connect(func() -> void: hovered.emit(index, true))
	mouse_exited.connect(func() -> void: hovered.emit(index, false))

func bind(i: int, e, telegraphed: bool) -> void:
	# A third of a cycle apart, so three contacts never reach the top together.
	_bob_phase = float(i) * (1.0 / BOB_HZ) / 3.0
	index = i
	var hull: int = e.hp if shown_hp < 0 else shown_hp
	_dead = hull <= 0
	_last_e = e
	_last_tele = telegraphed
	art.set_enemy(e, telegraphed, shown_hp, true, death_style)
	_fit_holder()
	art.modulate = Color(0.4, 0.4, 0.45) if _dead else Color.WHITE
	_intent.text = "" if _dead or e.intent == null else e.intent.name.to_upper()
	_intent.visible = _intent.text != ""
	_intent_text.text = "" if _dead or e.intent == null else e.intent.describe()
	_intent_text.visible = _intent_text.text != ""
	_name.text = e.template.name.to_upper()
	_name.add_theme_color_override("font_color",
		Color("#4a5c72") if _dead else UITheme.THEM)
	_bar.max_value = e.max_hp
	_bar.value = hull
	_brace_bar.visible = not _dead and e.brace > 0
	_brace_bar.set_value(e.brace)
	# SALVAGE, not WRECKED, once there is a reason to touch it.
	#
	# "WRECKED" is a state and states are not affordances -- it told you the
	# thing was dead and said nothing about it being the way into what it was
	# carrying. The word only changes when the slot can actually be opened, so
	# a hull with nothing left in it goes back to being a fact.
	_hp.text = ("SALVAGE" if opened.is_valid() else "WRECKED") if _dead \
		else "%d / %d" % [hull, e.max_hp]
	if _dead and opened.is_valid():
		_hp.add_theme_color_override("font_color", UITheme.TRACTOR)
		tooltip_text = Widgets.tip(
			"%s\n\nDisabled, with cargo still aboard. Open it." % e.template.name.to_upper())
	else:
		# ONLY HERE. This override used to run unconditionally after the branch
		# above, which repainted the SALVAGE word in corpse-grey the instant it
		# had been lit — so the one clickable thing in the sector wore the same
		# ink as a fact you could not touch, and read as disabled.
		tooltip_text = ""
		_hp.add_theme_color_override("font_color",
			Color("#4a5c72") if _dead else UITheme.GOOD)
	queue_redraw()


## THE COUNT CAME OFF THE HULL, 2026-09-03, by Jonathan: a wreck says
## "SALVAGE" and nothing more.
##
## IT WAS PUT THERE ON PURPOSE and the reasoning still reads: "SALVAGE" alone
## said the door existed and nothing about whether walking through it was worth
## it — a stripped wreck and a loaded one wore the same word, and a fight's
## whole payout could sit behind a label indistinguishable from scenery. That is
## why the tooltip still carries the number: the wreck stops advertising, but
## the answer is one hover away rather than gone.
##
## A wreck with nothing left is still told apart, by STRIPPED and by colour, so
## the case the count was added for is the one case it was never needed in.
##
## Asked after `bind`, by the view that knows the container — the slot only
## knows the ghost. A wreck with nothing left goes back to being a fact:
## grey, still openable, no longer advertising.
func set_salvage(left: int) -> void:
	if not _dead:
		return
	if left > 0:
		_hp.text = "SALVAGE"
		_hp.add_theme_color_override("font_color", UITheme.TRACTOR)
		tooltip_text = Widgets.tip(
			"%s\n\nDisabled, with %d still aboard. Open it."
			% [_name.text, left])
	elif opened.is_valid():
		_hp.text = "STRIPPED"
		_hp.add_theme_color_override("font_color", Color("#4a5c72"))
		tooltip_text = Widgets.tip(
			"%s\n\nPicked clean. The hull stays, but its cargo is gone." % _name.text)
	queue_redraw()

## What this card would do here, asked at drop-test time.
##
## Returns the string to paint over the target. Set by EncounterView, which gets
## it from the screen that owns the Combat — the slot knows the card and the
## target, and nothing else, which is exactly as much as it should.
var preview: Callable
var _drag_text: String = ""

## Godot asks this continuously while a drag hovers, which doubles as the
## "is this a legal target" highlight without any extra plumbing.

## Told when a WRECK is clicked. Set by the screen that owns the slot.
##
## Only when dead: a live ship is a target you drop cards on, and a hull with
## nothing left in it is a container you open. Same object, and which one it is
## depends entirely on whether it is still shooting.
var opened: Callable


## THE HULL, NOT THE SLOT. A slot expands to share the arena, so it is most of
## a screen -- and answering a click anywhere in it made a wreck something you
## opened by aiming near it. The art is where the ship is.
func _on_hull(p: Vector2) -> bool:
	if _art_holder == null:
		return false
	return Rect2(_art_holder.position, _art_holder.size).has_point(p)


func _gui_input(e: InputEvent) -> void:
	if not _dead:
		return
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if opened.is_valid() and _on_hull(mb.position):
		accept_event()
		opened.call()


## THE HOLDER IS THE SHIP'S BOX, NOT THE CANVAS (pack clipping, Oct 13).
##
## Every slot reserved the whole canvas whatever was painted in it, so two
## contacts asked for more than the arena's half and the second was cut off at
## the screen's edge. The art measures its own ship (`custom_minimum_size`,
## symmetric about the canvas middle); the holder takes that, and the canvas
## sits centred inside it at a negative offset, which is `_art_base`.
func _fit_holder() -> void:
	if _art_holder == null or art == null:
		return
	var want := art.custom_minimum_size.ceil()
	want.x = minf(want.x, float(EnemyArt.W))
	want.y = minf(want.y, float(EnemyArt.H))
	if not _art_holder.custom_minimum_size.is_equal_approx(want):
		_art_holder.custom_minimum_size = want
	# And the slot asks the row for that width. It is a plain Control, so its
	# column's size never reached the row: two slots were laid out narrower than
	# their ships and the column spilled off the right edge.
	if custom_minimum_size.x != want.x:
		custom_minimum_size.x = want.x
	var base := ((want - Vector2(EnemyArt.W, EnemyArt.H)) * 0.5).round()
	if not base.is_equal_approx(_art_base):
		# Moved by the difference, and an entrance still in flight sent on to the
		# new resting place in the time it had left -- its tween was flying to
		# the old one, and would have parked the ship off its holder.
		art.position += base - _art_base
		_art_base = base
		if _enter_tw != null and _enter_tw.is_valid() and _enter_tw.is_running():
			_enter_tw.kill()
			_enter_tw = create_tween()
			_enter_tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			var left := maxf(0.05, float(_enter_end - Time.get_ticks_msec()) / 1000.0)
			_enter_tw.tween_property(art, "position:x", base.x, left)


## What the last bind drew, so the pack layout can redraw it at another size.
var _last_e = null
var _last_tele: bool = false

## Draw the ship at `s`: 1, or 0.5 from its half sheet (`EnemyArt.draw_scale`).
func apply_scale(s: float) -> void:
	if art == null or is_equal_approx(art.draw_scale, s):
		return
	art.set_draw_scale(s)
	if _last_e != null:
		art.set_enemy(_last_e, _last_tele, shown_hp, true, death_style)
	_fit_holder()


## THE SLOT'S SIZE AT A SCALE AND A MODE, worked out rather than read off the
## column, so the layout can try a size before drawing at it: the ship's box at
## `s` (its own picture's size, plus the holder's 6), the readout in its lines,
## under the ship or (`beside`) to its near side.
func unit(s: float, beside: bool) -> Vector2:
	# drawn at `s` already: the holder it really has; else what it will have
	var ship := art.custom_minimum_size if art.full_ink == Vector2i.ZERO \
		or is_equal_approx(art.draw_scale, s) \
		else Vector2(art.half_ink if s < 1.0 else art.full_ink) + Vector2(6, 6)
	var lh := _name.get_minimum_size().y
	var parts := 0
	var lab_h := 0.0
	var w_it := 0.0
	var widest := float(BAR_W)
	for l: Label in [_intent, _name, _hp]:
		if l.visible and l.text != "":
			widest = maxf(widest, _text_w(l))
			lab_h += lh
			parts += 1
	if _intent_text.visible and _intent_text.text != "":
		w_it = _text_w(_intent_text)
		parts += 1
	var bars_h := _bars.get_combined_minimum_size().y
	lab_h += bars_h
	parts += 1
	if chips.visible and chips.get_child_count() > 0:
		widest = maxf(widest, chips.get_combined_minimum_size().x)
		lab_h += chips.get_combined_minimum_size().y
		parts += 1
	if beside:
		var lw := maxf(widest, w_it)
		if w_it > 0.0:
			lab_h += lh
		lab_h += float(maxi(0, parts - 1))
		return Vector2(lw + 8.0 + ship.x, maxf(ship.y, lab_h))
	var w := maxf(ship.x, widest)
	if w_it > 0.0:
		w = maxf(w, minf(w_it, maxf(w, WRAP_W)))
		lab_h += lh * ceilf(w_it / w)
	return Vector2(ceilf(w), ship.y + lab_h + float(parts))


## THE BLOCK YOU SEE inside the slot at `s` (readout under the ship): the
## ship's own ink and every line of its readout, without the holder's 3 px of
## margin round the ink. What the formation spaces evenly (Jon: "evenly spaced
## around each other"), so a gap is a gap between things drawn, not between
## boxes.
func block(s: float) -> Rect2:
	var u := unit(s, false)
	var ink := art.custom_minimum_size - Vector2(6, 6) if art.full_ink == Vector2i.ZERO 		else Vector2(art.half_ink if s < 1.0 else art.full_ink)
	var labels := float(BAR_W)
	for l: Label in [_intent, _name, _hp]:
		if l.visible and l.text != "":
			labels = maxf(labels, _text_w(l))
	if _intent_text.visible and _intent_text.text != "":
		labels = maxf(labels, minf(_text_w(_intent_text), u.x))
	if chips.visible and chips.get_child_count() > 0:
		labels = maxf(labels, chips.get_combined_minimum_size().x)
	var w := minf(u.x, maxf(ink.x, labels))
	var said := (_intent.visible and _intent.text != "") or (_intent_text.visible and _intent_text.text != "")
	var top := 0.0 if said else 3.0
	return Rect2(round((u.x - w) * 0.5), top, w, u.y - top)


## The block as it is actually drawn now, in the slot's own coordinates: the
## union of `boxes()`. Zero until the slot has been laid out at `s` with its
## readout under the ship; the formation prefers it to `block`'s prediction
## once it exists, since a wreck's scattered chunks or a label's own width can
## differ from the prediction by a few pixels.
func drawn_block(s: float) -> Rect2:
	if side or not is_inside_tree() or not is_equal_approx(art.draw_scale, s):
		return Rect2()
	var u := Rect2()
	for b in boxes():
		var r: Rect2 = b[1]
		u = r if u.size == Vector2.ZERO else u.merge(r)
	if u.size == Vector2.ZERO:
		return Rect2()
	return Rect2(u.position - get_global_rect().position, u.size)


## THE READOUT BESIDE THE SHIP, or under it (the default). Layout C stacks a
## pack top to bottom, and a readout under each ship would stack three readouts
## between them; beside, each ship's row is only as tall as the taller of the
## two. The readout sits on the ship's near side (toward you), right-aligned to
## it, intent first, the way it reads under the ship.
func set_side(on: bool) -> void:
	if on == side or _col == null:
		return
	side = on
	var parts: Array[Control] = [_intent, _intent_text, _name, _bars, _hp, chips]
	if on:
		if _side_row == null:
			_side_row = HBoxContainer.new()
			_side_row.add_theme_constant_override("separation", 8)
			_side_row.alignment = BoxContainer.ALIGNMENT_END
			_side_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_side_box = VBoxContainer.new()
			_side_box.add_theme_constant_override("separation", 1)
			_side_box.alignment = BoxContainer.ALIGNMENT_CENTER
			_side_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_side_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_side_row.add_child(_side_box)
		_col.add_child(_side_row)
		_col.move_child(_side_row, _art_holder.get_index())
		_art_holder.reparent(_side_row, false)
		for p in parts:
			p.reparent(_side_box, false)
			if p is Label:
				(p as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				(p as Label).autowrap_mode = TextServer.AUTOWRAP_OFF
		_bars.size_flags_horizontal = Control.SIZE_SHRINK_END
		chips.alignment = BoxContainer.ALIGNMENT_END
	else:
		var at := _side_row.get_index()
		_art_holder.reparent(_col, false)
		_col.move_child(_art_holder, at)
		_col.remove_child(_side_row)
		# back in the order the column reads: intent, what it does, ship, name,
		# bars, number, chips
		var order: Array[Control] = [_intent, _intent_text]
		for k in order.size():
			order[k].reparent(_col, false)
			_col.move_child(order[k], 1 + k)
		var after: Array[Control] = [_name, _bars, _hp, chips]
		for k in after.size():
			after[k].reparent(_col, false)
			_col.move_child(after[k], _art_holder.get_index() + 1 + k)
		for p in parts:
			if p is Label:
				(p as Label).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				(p as Label).autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if (p == _intent or p == _intent_text) \
					else TextServer.AUTOWRAP_OFF
		_bars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		chips.alignment = BoxContainer.ALIGNMENT_CENTER


## WHAT THIS SLOT NEEDS, for the pack layout: the width its widest part asks
## for (the ship, the bars, a name, an intent up to WRAP_W before it wraps)
## and, at that width, the height of the whole column. Read off the column
## itself once it has been laid out at that width, so a wrapped intent counts.
const WRAP_W := 170.0

func need() -> Vector2:
	var ship := _art_holder.custom_minimum_size if _art_holder != null else Vector2(EnemyArt.W, EnemyArt.H)
	var text := 0.0
	for l: Label in [_intent, _intent_text, _name, _hp]:
		if l.visible and l.text != "":
			text = maxf(text, minf(_text_w(l), WRAP_W if l == _intent_text and not side else 9999.0))
	var labels := maxf(float(BAR_W), text)
	if chips.visible and chips.get_child_count() > 0:
		labels = maxf(labels, chips.get_combined_minimum_size().x)
	if side:
		return Vector2(labels + 8.0 + ship.x, _col.get_combined_minimum_size().y)
	return Vector2(maxf(ship.x, labels), _col.get_combined_minimum_size().y)

static func _text_w(l: Label) -> float:
	var f := l.get_theme_font("font")
	if f == null:
		return l.get_minimum_size().x
	return f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x


## Every box this slot draws, in global coordinates, with what it is: the ship
## (its own ink, at rest), and each readout's own text or bar -- not the
## label's full width. What the pack layout keeps apart, and what the test
## checks.
func boxes() -> Array:
	var out: Array = []
	if art != null:
		var u := Rect2(art.ink_rect())
		var at := _art_holder.get_global_rect().position + _art_base
		out.append(["art", Rect2(at + u.position, u.size)])
	for l: Label in [_intent, _intent_text, _name, _hp]:
		if l.is_visible_in_tree() and l.text.strip_edges() != "":
			out.append(["text:" + l.text, text_rect(l)])
	if _brace_bar.is_visible_in_tree():
		out.append(["brace", _brace_bar.get_global_rect()])
	if _bar.is_visible_in_tree():
		out.append(["bar", _bar.get_global_rect()])
	if chips.is_visible_in_tree() and chips.get_child_count() > 0:
		var r := Rect2()
		for c in chips.get_children():
			if c is Control and (c as Control).visible:
				r = (c as Control).get_global_rect() if r.size == Vector2.ZERO else r.merge((c as Control).get_global_rect())
		if r.size != Vector2.ZERO:
			out.append(["chips", r])
	return out

## A label's ink: its text's own width where it fits on one line, the label's
## width where it wraps, aligned as the label aligns it; the label's height.
static func text_rect(l: Label) -> Rect2:
	var r := l.get_global_rect()
	var w := minf(_text_w(l), r.size.x)
	var x := r.position.x
	match l.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x += (r.size.x - w) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			x += r.size.x - w
	return Rect2(x, r.position.y, w, r.size.y)


## The ship's width on screen, for the row's packing.
func ship_width() -> float:
	return _art_holder.custom_minimum_size.x if _art_holder != null else float(EnemyArt.W)


## Off the row's middle by `dy`, down positive: the column grows a spacer on
## the far side and stays centred, so the ship, its intent and its bars all move
## together.
func set_lift(dy: float) -> void:
	if _lift_top == null:
		return
	var top := maxf(0.0, dy) * 2.0
	var bot := maxf(0.0, -dy) * 2.0
	if _lift_top.custom_minimum_size.y != top:
		_lift_top.custom_minimum_size.y = top
	if _lift_bot.custom_minimum_size.y != bot:
		_lift_bot.custom_minimum_size.y = bot


## Hidden while a breakup draws the ship coming apart in its place, and back,
## as the wreck, when it is done. The slot keeps its place, its name and its bar.
func hide_art(on: bool) -> void:
	if art != null:
		# The whole colour, not just the alpha: a hit's white flash may still be
		# on it, and bringing the wreck back at 2.4x white was a bright ghost.
		art.self_modulate = Color(1, 1, 1, 0.0 if on else 1.0)


## AND SO DOES THE CURSOR. `mouse_default_cursor_shape` is a property of the
## whole control, and the control is most of the arena -- so a pointing hand
## appeared halfway across the screen from the only thing it could point at.
## Godot asks this per position, which is the shape the question actually has.
func _get_cursor_shape(at: Vector2) -> CursorShape:
	if _dead and opened.is_valid() and _on_hull(at):
		return Control.CURSOR_POINTING_HAND
	return Control.CURSOR_ARROW


## And the tooltip only exists over the hull, for the same reason. Godot asks
## per position, which is exactly the hook this needs -- an empty string is no
## tooltip rather than an empty one.
func _get_tooltip(at: Vector2) -> String:
	if not _dead or not opened.is_valid() or not _on_hull(at):
		return ""
	return tooltip_text


## NO `_can_drop_data`. Nothing is dropped on an enemy any more -- see `aim`
## directly above, which is the same rule driven by the screen instead of by the
## engine, and `CardView`'s note on why the drag had to go.


## CAN THIS CARD BE AIMED HERE. The rule the drop path used to hold, kept when
## the drop path went: brace does nothing to a Rustjaw, and a dead slot is not a
## target at all.
func aimable(c: CardData) -> bool:
	if c == null:
		return false
	return (c.damage > 0 or c.damage_equals_heat or c.evoke > 0) and not _dead


## Light up under an aimed line, with what the card would do written on it.
##
## The same `_hot` and `_drag_text` the drop path set, driven by the screen
## instead of by the engine. `set_drag_preview` pinned the card over the target,
## so the figure appeared at the exact moment the thing it applied to went
## behind a 112x160 card; the line leaves the board visible and this puts the
## number back on it.
func aim(on: bool, text: String = "") -> void:
	set_hot(on)
	var t := text if on else ""
	if t != _drag_text:
		_drag_text = t
		queue_redraw()


func set_hot(v: bool) -> void:
	if _hot == v:
		return
	_hot = v
	queue_redraw()

## AND NO `_drop_data`. Kept as a comment because leaving the body in place was
## a live hazard rather than dead weight: it emits `card_dropped`, which is
## still wired to `SectorScreen._on_card_dropped`, so any Godot drop that ever
## reached a slot would play a card straight past the aiming gesture.


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and _hot:
		_hot = false
		queue_redraw()

func _draw() -> void:
	if not _hot:
		return
	# Corner brackets rather than a filled panel: a full wash buries the sprite
	# you are aiming at, which is the one thing you need to still see.
	var c := UITheme.FLARE
	var n := 7.0
	# THE HOLDER'S POSITION, THE ART'S EXTENT.
	#
	# The holder is a fixed 240x120 -- EnemyArt.W by .H -- whatever is painted in
	# it, so bracketing the holder framed the same big empty box around a cutter
	# as around a hulk. `used_rect()` is the bounds EnemyArt tracks as it paints,
	# which is the ship and nothing else; it keeps its own rather than asking the
	# image, because a starfield goes down first and would swallow the answer.
	#
	# The holder still supplies the ORIGIN. The art's own position is measured
	# inside it and is zero at rest, so using that would put the brackets in the
	# slot's top corner -- and the holder is the one that does not move, which is
	# what lets a reticle frame where the ship is going to be rather than chase
	# it in from off-screen.
	var pad := 3.0
	var u: Rect2i = art.used_rect() if art != null else Rect2i(0, 0, EnemyArt.W, EnemyArt.H)
	var r := Rect2(_art_holder.position + _art_base + Vector2(u.position) - Vector2(pad, pad),
		Vector2(u.size) + Vector2(pad, pad) * 2.0)
	var x0 := r.position.x
	var y0 := r.position.y
	var w := r.end.x
	var h := r.end.y
	for corner in [
			[Vector2(x0, y0), Vector2(1, 1)],
			[Vector2(w, y0), Vector2(-1, 1)],
			[Vector2(x0, h), Vector2(1, -1)],
			[Vector2(w, h), Vector2(-1, -1)]]:
		var o: Vector2 = corner[0]
		var d: Vector2 = corner[1]
		draw_rect(Rect2(o + Vector2(0, -1 if d.y < 0 else 0), Vector2(n * d.x, 1)), c, true)
		draw_rect(Rect2(o + Vector2(-1 if d.x < 0 else 0, 0), Vector2(1, n * d.y)), c, true)

	# The number, over the target, while a card is held above it.
	#
	# It used to live as a small label under the health bar and it read as part
	# of the enemy's own readout — a permanent stat that happened to change.
	# Painted across the target only while you are holding a card over it, it is
	# obviously a QUESTION being answered: this card, this enemy, this much.
	if _hot and _drag_text != "":
		var f := UITheme.pixel_font()
		var fs := UITheme.FS_HEAD
		var tw := f.get_string_size(_drag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var at := Vector2((size.x - tw) * 0.5, size.y * 0.5 + fs * 0.4)
		draw_string(f, at + Vector2(1, 1), _drag_text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.75))
		draw_string(f, at, _drag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.FLARE)
