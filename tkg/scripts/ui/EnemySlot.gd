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
	art.position.y = roundf(sin((t + _bob_phase) * TAU * BOB_HZ) * BOB_AMP)


func enter(delay: float = 0.0) -> void:
	if _art_holder == null:
		return
	art.position.x = ENTER_FROM
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
	tw.tween_property(art, "position:x", 0.0, ENTER_SECS)


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

	mouse_entered.connect(func() -> void: hovered.emit(index, true))
	mouse_exited.connect(func() -> void: hovered.emit(index, false))

func bind(i: int, e, telegraphed: bool) -> void:
	# A third of a cycle apart, so three contacts never reach the top together.
	_bob_phase = float(i) * (1.0 / BOB_HZ) / 3.0
	index = i
	_dead = e.hp <= 0
	art.set_enemy(e, telegraphed)
	art.modulate = Color(0.4, 0.4, 0.45) if _dead else Color.WHITE
	_intent.text = "" if _dead or e.intent == null else e.intent.name.to_upper()
	_intent.visible = _intent.text != ""
	_intent_text.text = "" if _dead or e.intent == null else e.intent.text
	_intent_text.visible = _intent_text.text != ""
	_name.text = e.template.name.to_upper()
	_name.add_theme_color_override("font_color",
		Color("#4a5c72") if _dead else UITheme.THEM)
	_bar.max_value = e.max_hp
	_bar.value = e.hp
	_brace_bar.visible = not _dead and e.brace > 0
	_brace_bar.set_value(e.brace)
	# SALVAGE, not WRECKED, once there is a reason to touch it.
	#
	# "WRECKED" is a state and states are not affordances -- it told you the
	# thing was dead and said nothing about it being the way into what it was
	# carrying. The word only changes when the slot can actually be opened, so
	# a hull with nothing left in it goes back to being a fact.
	_hp.text = ("SALVAGE" if opened.is_valid() else "WRECKED") if _dead \
		else "%d / %d" % [e.hp, e.max_hp]
	if _dead and opened.is_valid():
		_hp.add_theme_color_override("font_color", UITheme.TRACTOR)
		tooltip_text = Widgets.tip(
			"%s\n\nDead in the water and still loaded. Open it." % e.template.name.to_upper())
	else:
		# ONLY HERE. This override used to run unconditionally after the branch
		# above, which repainted the SALVAGE word in corpse-grey the instant it
		# had been lit — so the one clickable thing in the sector wore the same
		# ink as a fact you could not touch, and read as disabled.
		tooltip_text = ""
		_hp.add_theme_color_override("font_color",
			Color("#4a5c72") if _dead else UITheme.GOOD)
	queue_redraw()


## THE COUNT IS THE AFFORDANCE. "SALVAGE" said the door existed and nothing
## about whether walking through it was worth it — so a stripped wreck and a
## loaded one wore the same word, and a fight's whole payout could sit behind a
## label indistinguishable from scenery. The number is what makes the sector
## answer "is there loot here" without being opened.
##
## Asked after `bind`, by the view that knows the container — the slot only
## knows the ghost. A wreck with nothing left goes back to being a fact:
## grey, still openable, no longer advertising.
func set_salvage(left: int) -> void:
	if not _dead:
		return
	if left > 0:
		_hp.text = "SALVAGE · %d" % left
		_hp.add_theme_color_override("font_color", UITheme.TRACTOR)
		tooltip_text = Widgets.tip(
			"%s\n\nDead in the water and still loaded — %d aboard. Open it."
			% [_name.text, left])
	elif opened.is_valid():
		_hp.text = "STRIPPED"
		_hp.add_theme_color_override("font_color", Color("#4a5c72"))
		tooltip_text = Widgets.tip(
			"%s\n\nPicked clean. The hull stays; what it carried is yours or gone." % _name.text)
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
	# THE HOLDER'S RECT, NOT THE ART'S. EnemyArt sizes itself to the hull, so
	# either box is the ship -- but the art's position is measured inside the
	# holder now and is zero at rest, which would draw the brackets in the
	# slot's top corner. The holder is the one that sits where the column put
	# it.
	#
	# It is also the one that does not move: a reticle should frame the place
	# the ship is going to be, not chase it in from off-screen.
	var pad := 2.0
	var r := Rect2(_art_holder.position - Vector2(pad, pad),
		_art_holder.size + Vector2(pad, pad) * 2.0)
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
