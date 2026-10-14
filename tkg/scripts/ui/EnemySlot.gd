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
## Where this ship's wreck will lie (`node * 64 + nth`), or -1: keys its
## marked wreck and seeds its hit effects, so they are the same on every screen.
var wreck_id: int = -1
## This ship's hits, block and brace, drawn (`HitLayers`), once a fight arms it.
var layers: HitLayers = null
var _bound_e = null
var _bound_tel := false
var _baked := -1
## Where the art sits at rest inside its holder. The holder is the ship's own
## box (`_fit_holder`), not the canvas, so the canvas, drawn centred, sits at a
## negative offset inside it.
var _art_base: Vector2 = Vector2.ZERO
## The entrance in flight, and when it lands: a holder that resizes mid-flight
## (the ship's picture arriving after `enter`) sends it to the new resting place.
var _enter_tw: Tween
## The slot's own fade up with the entrance.
var _fade_tw: Tween
var _enter_end: int = 0
## How far this slot's column sits off the row's middle, down positive: a pack
## no longer used: packs are placed by `EncounterView._layout_pack`.
var _lift_top: Control
var _lift_bot: Control
## THE SAME ROOM UNDER EVERY HULL (Jon: "The hellbender is a bit close to its
## text box"). Between the ship's own ink and the top of its name there is
## always UNDER_GAP: the holder's margin under the ink varies by a pixel with
## the picture's size, and this spacer makes up the rest.
const UNDER_GAP := 6
var _under: Control
## THE SHIELD'S ROOM (Jon, "shield:A"). A ship in a fight keeps room above and
## below its hull for the bubble its block raises (`ShieldFx.fit`'s own oval for
## this picture at this size), and RIM_GAP from the oval's rim to its words
## above and to its name below -- shield up or not, so nothing moves when one
## comes or goes. `_over` is the spacer between the words and the hull.
const RIM_GAP := 6
var _over: Control
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
## comes off the slot index for the same reason. The clock is `GameClock`: one
## clock the whole pack reads, so the phases hold, and game time, so a film
## made with the movie writer bobs at 4.76 s a cycle like play does.
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


## Lay this ship's `HitLayers` over its picture, from the picture as drawn now.
func _arm(e) -> void:
	art.set_enemy(e, false, shown_hp, true, death_style)
	layers = HitLayers.new()
	layers.size = art.size
	layers.kind = FaunaMotion.kind_of(e.template.id)
	var seed := int(Rng.derive(&"hitfx", wreck_id).randi() & 0x7fffffff)
	# shots come from your side, the left
	# marks at the picture's own scale: 0.5 on a half sheet (`EnemyArt.draw_scale`)
	layers.setup(art.snapshot(), art.used_rect(), seed, -1, e.max_hp, art.draw_scale, true)
	art.marks = layers.hits
	_art_holder.add_child(layers)


func _process(_dt: float) -> void:
	if _art_holder == null:
		return
	if layers != null:
		layers.position = art.position
		# a crack runs over several frames after the shot that made it: the
		# picture the marks are baked into catches up as it does
		if layers.hits.version != _baked and _bound_e != null and not _dead:
			_baked = layers.hits.version
			art.set_enemy(_bound_e, _bound_tel, shown_hp, true, death_style)
	# ROUNDED. A sub-pixel offset resamples the sprite and undoes the
	# nearest-neighbour crispness the whole art direction rests on.
	var t := GameClock.now()
	art.position.y = _art_base.y + roundf(sin((t + _bob_phase) * TAU * BOB_HZ) * BOB_AMP)
	_fauna_step(_dt)
	# a creature's guard rides the body on this frame's bob, not last frame's
	if layers != null and layers.body != null:
		layers.position = art.position
		_guard_keep()


func enter(delay: float = 0.0) -> void:
	if _art_holder == null:
		return
	art.position.x = _art_base.x + ENTER_FROM
	# THE READOUT ARRIVES WITH THE SHIP. The name and the hull bar belong to the
	# slot rather than to the art, so they do not move -- and a bar sitting at
	# full for a ship that is still off-screen reads as a rendering fault. Fading
	# the whole slot up over the same window keeps the two halves one event.
	modulate.a = 0.0
	if _fade_tw != null and _fade_tw.is_valid():
		_fade_tw.kill()
	_fade_tw = create_tween()
	_fade_tw.tween_property(self, "modulate:a", 1.0, ENTER_SECS * 0.7).set_delay(delay)
	if _enter_tw != null and _enter_tw.is_valid():
		_enter_tw.kill()
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(art, "position:x", _art_base.x, ENTER_SECS)
	_enter_tw = tw
	_enter_end = GameClock.now_ms() + int((delay + ENTER_SECS) * 1000.0)


## Off screen and unseen, waiting to `enter` (`EncounterView.hold_entrances`).
func hold_entrance() -> void:
	if _art_holder == null:
		return
	for tw in [_enter_tw, _fade_tw]:
		if tw != null and (tw as Tween).is_valid():
			(tw as Tween).kill()
	_enter_tw = null
	_fade_tw = null
	modulate.a = 0.0
	art.position.x = _art_base.x + ENTER_FROM


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
	_over = Control.new()
	_over.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_over)
	col.move_child(_over, 2)

	# The column centres itself and the art stops expanding, so name and bars
	# sit directly under the ship instead of being shoved to the floor of a slot
	# that happens to be tall. A health bar half a screen below its ship is a
	# health bar you have to go looking for.
	# TOP-ALIGNED, with the intent's lines reserved (`reserve_readout`), so the
	# ship stands at the same height whatever its readout says -- a kill or a
	# new intent changes the words, never where the hull is.
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
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
	_under = Control.new()
	_under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_under)

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
	# A LIVE SHIP IN A FIGHT carries its damage, block and brace on its picture
	# (`HitLayers`); armed the first time it is bound alive with a place to lie.
	if layers == null and not _dead and wreck_id >= 0:
		_arm(e)
	art.wreck_id = wreck_id
	_bound_e = e
	_bound_tel = telegraphed
	if layers != null:
		_baked = layers.hits.version
	_last_e = e
	_last_tele = telegraphed
	art.set_enemy(e, telegraphed, shown_hp, true, death_style)
	if layers != null and _dead:
		layers.visible = false
	_fit_holder()
	_fauna_bind(e, telegraphed)
	art.modulate = Color(0.4, 0.4, 0.45) if _dead else Color.WHITE
	_reserve_for(e.template)
	_intent.text = "" if _dead or e.intent == null else e.intent.name.to_upper()
	_intent.visible = reserve_intent or _intent.text != ""
	_intent_text.text = "" if _dead or e.intent == null else e.intent.describe()
	_intent_text.visible = reserve_intent or _intent_text.text != ""
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
			var left := maxf(0.05, float(_enter_end - GameClock.now_ms()) / 1000.0)
			_enter_tw.tween_property(art, "position:x", base.x, left)
	_fit_under()


## The spacers round the hull at its current size (`_spacers`).
func _fit_under() -> void:
	if _under == null or art == null:
		return
	var sp := _spacers(art.draw_scale)
	if _over.custom_minimum_size.y != sp.x:
		_over.custom_minimum_size.y = sp.x
	_over.visible = reserve_intent and not side
	if _under.custom_minimum_size.y != sp.y:
		_under.custom_minimum_size.y = sp.y

## The two spacers at size `s`: over the hull (between its words and the
## shield's top) and under it (between the shield's bottom, or a wreck's ink,
## and its name). Each makes up what the holder's own margin, the shield's
## reach and the column's 1 px separations leave of the gap.
func _spacers(s: float) -> Vector2:
	var top_m := 3.0
	var bot_m := 3.0
	if art != null and is_equal_approx(art.draw_scale, s) and art.ink_rect().size != Vector2i.ZERO:
		var ink := art.ink_rect()
		top_m = _art_base.y + float(ink.position.y)
		bot_m = _art_holder.custom_minimum_size.y - (_art_base.y + float(ink.end.y))
	if not reserve_intent:
		return Vector2(0.0, maxf(0.0, float(UNDER_GAP) - bot_m - 2.0))
	var rc := _reach(s)
	return Vector2(maxf(0.0, float(RIM_GAP) - 2.0 - (top_m - rc.x)),
		maxf(0.0, float(RIM_GAP) - 2.0 - (bot_m - rc.y)))

## What the spacer adds to the column's height, its separation included.
func _under_h() -> float:
	return (_under.custom_minimum_size.y + 1.0) if _under != null and _under.visible else 0.0

## How far the shield's oval reaches past a picture's ink: up, down, left,
## right, in its pixels. Measured once per picture with `ShieldFx.fit`, the fit
## the shield itself is drawn with.
static var _reach_cache: Dictionary = {}

static func shield_reach(tex: Texture2D) -> Vector4:
	if tex == null:
		return Vector4.ZERO
	var key := tex.resource_path
	if _reach_cache.has(key):
		return _reach_cache[key]
	var img := tex.get_image()
	if img.is_compressed():
		img = img.duplicate()
		img.decompress()
	if img.get_format() != Image.FORMAT_RGBA8:
		img = img.duplicate()
		img.convert(Image.FORMAT_RGBA8)
	var used := img.get_used_rect()
	var f := ShieldFx.fit(img, used)
	var cc: Vector2 = f.cc
	var rx: float = f.rx
	var ry: float = f.ry
	var r := Vector4(maxf(0.0, float(used.position.y) - floorf(cc.y - ry)),
		maxf(0.0, ceilf(cc.y + ry) - float(used.end.y)),
		maxf(0.0, float(used.position.x) - floorf(cc.x - rx)),
		maxf(0.0, ceilf(cc.x + rx) - float(used.end.x)))
	_reach_cache[key] = r
	return r

## This ship's shield reach at size `s` (none for a wreck row).
func _reach(s: float) -> Vector4:
	if _last_e == null or not reserve_intent:
		return Vector4.ZERO
	# (asked many times a layout: kept by picture and size, not looked up)
	var key := "%s/%d/%s" % [_last_e.template.id, _last_e.look, s < 1.0]
	if not _reach_by_pic.has(key):
		_reach_by_pic[key] = shield_reach(DB.enemy_sprite(_last_e.template.id, _last_e.look, s < 1.0))
	return _reach_by_pic[key]

static var _reach_by_pic: Dictionary = {}


## THE ROOM THE SHIP KEEPS, IN ITS PARTS, for packing a rank behind into the
## shoulders of the rank in front (Jon's formation, "shield:A"): its words'
## lines (as wide as the widest it can say), its shield's oval (`ShieldFx.fit`,
## the shield's own), and its plate (name, brace and hull bars, number, one row
## of chips). In the slot's own coordinates, the slot `unit(s)` in size; drawn
## at `s` already (the layout sets the size first). Each is [kind, Rect2]:
## &"box", or &"oval" for the ellipse inside the rect. Empty for a wreck row,
## a side readout, or a slot not drawn at `s`.
static var _fit_cache: Dictionary = {}

func rooms(s: float) -> Array:
	var out: Array = []
	if art == null or _last_e == null or not reserve_intent or side \
			or not is_equal_approx(art.draw_scale, s):
		return out
	var u := unit(s, false)
	var lh := _name.get_minimum_size().y
	var r := _reserved(u.x)
	var names := 0.0
	for t in _res_names:
		names = maxf(names, _str_w(_intent, t))
	var it_w: float = r.text
	var words_h := lh + 1.0 + lh * float(_lines(it_w, u.x))
	var ww := ceilf(minf(u.x, maxf(names, it_w)))
	out.append([&"box", Rect2(floorf((u.x - ww) * 0.5), 0.0, ww, words_h)])
	var sp := _spacers(s)
	var hold := _art_holder.custom_minimum_size
	var hold_at := Vector2(floorf((u.x - hold.x) * 0.5), words_h + 1.0 + sp.x + 1.0)
	var ink := art.ink_rect()
	var key := "%s/%d/%.2f/%s" % [_last_e.template.id, _last_e.look, s, ink]
	if not _fit_cache.has(key):
		_fit_cache[key] = ShieldFx.fit(art.snapshot(), ink)
	var f: Dictionary = _fit_cache[key]
	var cc: Vector2 = hold_at + _art_base + (f.cc as Vector2)
	var rad := Vector2(float(f.rx), float(f.ry))
	out.append([&"oval", Rect2(cc - rad, rad * 2.0)])
	var name_top := hold_at.y + hold.y + 1.0 + sp.y + 1.0
	var pw := ceilf(minf(u.x, float(r.widest)))
	out.append([&"box", Rect2(floorf((u.x - pw) * 0.5), name_top, pw, u.y - name_top)])
	return out


## What the last bind drew, so the pack layout can redraw it at another size.
var _last_e = null
var _last_tele: bool = false

## Draw the ship at `s`: 1, or 0.5 from its half sheet (`EnemyArt.draw_scale`).
func apply_scale(s: float) -> void:
	if art == null or is_equal_approx(art.draw_scale, s):
		return
	art.set_draw_scale(s)
	# the hit layers were fitted to the picture at its old size: fitted again to
	# this one (a pack's size is set once, as its fight opens, before any hit)
	if layers != null and _last_e != null and not _dead:
		var old := layers
		layers = null
		art.marks = null
		old.queue_free()
		_arm(_last_e)
	if _last_e != null:
		art.set_enemy(_last_e, _last_tele, shown_hp, true, death_style)
	_fit_holder()


## THE READOUT'S ROOM IS RESERVED FOR THE FIGHT. Whatever this kind can say --
## every move in its loop and its pool, and a set piece's escape -- has its
## lines kept above the hull, and the rows under it (name, brace and hull bars,
## number, one row of chips) are counted whether showing or not. So the slot is
## one size from the opening to the wreck: a kill or an intent changes words,
## never the formation (Jon: "the enemy dips down and then pops up"). LOCAL's
## wreck rows say no intent and reserve none (`reserve_intent` false).
var reserve_intent := true
var _res_names: PackedStringArray = PackedStringArray()
var _res_texts: PackedStringArray = PackedStringArray()

func _reserve_for(t: EnemyTemplate) -> void:
	_res_names = PackedStringArray()
	_res_texts = PackedStringArray()
	var moves: Array = []
	moves.append_array(t.loop)
	moves.append_array(t.pool)
	if t.miniboss:
		moves.append(Combat.escape_intent())
	for it in moves:
		_res_names.append((it as IntentData).name.to_upper())
		_res_texts.append((it as IntentData).describe())

func _str_w(l: Label, text: String) -> float:
	var f := l.get_theme_font("font")
	if f == null:
		return float(text.length()) * 6.0
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x

static var _chip_h := -1.0

static func _chip_row_h() -> float:
	if _chip_h < 0.0:
		# the row holds the block chip, an icon now (`StatusChip`,
		# `SectorScreen._refresh_enemy`)
		var c := StatusChip.make(&"block", "99", Color("#3a4a6e"), "")
		_chip_h = c.get_combined_minimum_size().y
		c.free()
	return _chip_h

## The readout's widths and lines at slot width `w`: the widest line, the
## intent's own width, and the lines the longest intent text takes.
func _reserved(w: float) -> Dictionary:
	var widest := float(BAR_W)
	widest = maxf(widest, _text_w(_name))
	for t in ["SALVAGE", "WRECKED", "STRIPPED", _hp.text]:
		widest = maxf(widest, _str_w(_hp, t))
	var names := 0.0
	var texts := 0.0
	if reserve_intent:
		for t in _res_names:
			names = maxf(names, _str_w(_intent, t))
		for t in _res_texts:
			texts = maxf(texts, _str_w(_intent_text, t))
	widest = maxf(widest, names)
	if chips.visible and chips.get_child_count() > 0:
		widest = maxf(widest, chips.get_combined_minimum_size().x)
	return {widest = widest, text = texts}

## THE SLOT'S SIZE AT A SCALE AND A MODE, worked out rather than read off the
## column, so the layout can try a size before drawing at it: the ship's box at
## `s` (its own picture's size, plus the holder's 6), and the readout's reserved
## room, under the ship or (`beside`) to its near side.
func unit(s: float, beside: bool) -> Vector2:
	# drawn at `s` already: the holder it really has; else what it will have
	var ship := art.custom_minimum_size if art.full_ink == Vector2i.ZERO \
		or is_equal_approx(art.draw_scale, s) \
		else Vector2(art.half_ink if s < 1.0 else art.full_ink) + Vector2(6, 6)
	var lh := _name.get_minimum_size().y
	var r := _reserved(0.0)
	var widest: float = r.widest
	var it_w: float = r.text
	# under the hull: name, brace and hull bars, number, a row of chips
	# (a wreck on LOCAL has no brace and carries nothing: just its name, its
	# empty bar and its word)
	var under := _spacers(s).y + 1.0
	var below := under + lh + 1.0 + float(EnemySlot.BracePips.CELL.y) + 1.0 + 6.0 + 1.0 + lh + 1.0 + _chip_row_h() \
		if reserve_intent else under + lh + 1.0 + 6.0 + 1.0 + lh
	if beside:
		var lw := maxf(widest, it_w)
		var lab_h := below + ((lh + 1.0) * 2.0 if reserve_intent else 0.0)
		return Vector2(lw + 8.0 + ship.x, maxf(ship.y, lab_h))
	var rc := _reach(s)
	var ink_w := ship.x - 6.0
	var w := maxf(maxf(ship.x, widest), ink_w + rc.z + rc.w)
	var above := 0.0
	if reserve_intent:
		if it_w > 0.0:
			w = maxf(w, minf(it_w, maxf(w, WRAP_W)))
		w = ceilf(w)
		# the words, the spacer to the shield's top, and their separations
		above = lh + 1.0 + lh * float(_lines(it_w, w)) + 1.0 + _spacers(s).x + 1.0
	return Vector2(ceilf(w), above + ship.y + 1.0 + below)

## How many lines an intent text of width `tw` takes in a slot `w` wide, with
## room for where its words break.
static func _lines(tw: float, w: float) -> int:
	return maxi(1, int(ceil(tw * 1.15 / maxf(1.0, w))))

## Hold the readout to the room `unit` reserved, for a slot `u`: the intent's
## lines take their full height whatever they say, so the hull below them
## never moves.
func reserve_readout(u: Vector2) -> void:
	var lh := _name.get_minimum_size().y
	if reserve_intent:
		var r := _reserved(u.x)
		_intent.custom_minimum_size = Vector2(0, lh)
		_intent_text.custom_minimum_size = Vector2(0, lh * float(_lines(float(r.text), u.x)))
		_intent.visible = true
		_intent_text.visible = true
	else:
		_intent.custom_minimum_size = Vector2.ZERO
		_intent_text.custom_minimum_size = Vector2.ZERO
		_intent.visible = _intent.text != ""
		_intent_text.visible = _intent_text.text != ""


## THE BLOCK inside the slot at `s` (readout under the ship): the ship's own ink
## and the readout's reserved room, without the holder's 3 px of margin round
## the ink. What the formation spaces evenly (Jon: "evenly spaced around each
## other"); every line it can show lies inside it.
func block(s: float) -> Rect2:
	var u := unit(s, false)
	var ink := art.custom_minimum_size - Vector2(6, 6) if art.full_ink == Vector2i.ZERO \
		else Vector2(art.half_ink if s < 1.0 else art.full_ink)
	var r := _reserved(u.x)
	var labels: float = maxf(float(r.widest), minf(float(r.text), u.x))
	var rc := _reach(s)
	var w := minf(u.x, maxf(maxf(ink.x, labels), ink.x + rc.z + rc.w))
	var top := 0.0 if reserve_intent else 3.0
	# (the column centres the holder by floor, as a container does)
	return Rect2(floorf((u.x - w) * 0.5), top, w, u.y - top)


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
		_under.visible = false
		_over.visible = false
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
		_col.move_child(_under, _art_holder.get_index() + 1)
		_under.visible = true
		# just above the hull (`move_child` takes the final index, so one less
		# when the spacer comes from above it: a column, then a row, had put it
		# under the hull, and the shield's room with it)
		var hi := _art_holder.get_index()
		_col.move_child(_over, hi - 1 if _over.get_index() < hi else hi)
		_over.visible = reserve_intent
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
	# the bubble, the armour and the light go with the ship, and a wreck has none
	if layers != null:
		layers.visible = not on and not _dead


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
	# The same letters the shot will pop when it lands (`HitText`).
	if _hot and _drag_text != "":
		# On the hull's ink, both ways, not the slot's middle: in a pack the
		# slot runs down past the hull and the number sat on the name.
		HitText.draw_centred(self, ink_rect().get_center(), _drag_text, HitText.colour(&"damage"))


## A CREATURE'S BLOCK, BRACE AND DAMAGE KEEP OFF ITS WORDS (`FaunaGuard`): the
## intent words and the readout, in the layers' own pixels, a pixel round, and
## the art's flash for a look that covers its hide.
func _guard_keep() -> void:
	var inv := layers.get_global_transform().affine_inverse()
	var ks: Array = []
	for r in [intent_rect_global(), readout_rect_global()]:
		var rr: Rect2 = r
		if rr.size != Vector2.ZERO:
			ks.append((inv * rr).grow(1.0))
	layers.keep = ks
	layers.skin_mod = art.self_modulate


## THE HULL'S INK in this slot's coordinates: the picture's own box
## (`EnemyArt.ink_rect`, without the light a wind-up throws), placed where the
## holder puts it -- wherever the column has the holder, readout above or
## beside it (the brackets above are this, padded).
func ink_rect() -> Rect2:
	var u: Rect2i = art.ink_rect() if art != null else Rect2i(0, 0, EnemyArt.W, EnemyArt.H)
	var at := _art_holder.global_position - global_position + _art_base
	return Rect2(at + Vector2(u.position), Vector2(u.size))


## Where the held card's number is drawn, its letters' own box, in this slot's
## coordinates (`HitText.ink_rect`). For the test that holds it to the ink.
func preview_rect(text: String) -> Rect2:
	return HitText.ink_rect(HitText.centred_at(ink_rect().get_center(), text), text)


## THE WORDS OVER THIS SHIP (its intent: STRAFE / DEAL 5), in global px: the
## lines' own text, centred as they are drawn, not their full-width labels.
## Empty when nothing is written there. A landed number goes above these
## (Jon, Oct 13, "C": it sat on them and read "ST-8E").
func intent_rect_global() -> Rect2:
	return _text_rect([_intent, _intent_text])


## The ship's readout under it (name, bars, hull, chips), in global px.
func readout_rect_global() -> Rect2:
	var r := _text_rect([_name, _hp])
	for c: Control in [_brace_bar, _bar, chips]:
		if c != null and c.is_visible_in_tree() and c.size.x > 0.0:
			var g := c.get_global_rect()
			if c == chips and c.get_child_count() == 0:
				continue
			r = g if r.size == Vector2.ZERO else r.merge(g)
	return r


## The intent words step back for `secs` (a landed number written on the hull
## because there was no room above them: `SectorScreen._pop_at`).
var _hush_until := 0
var _hush_tw: Tween = null

func hush_intent(secs: float) -> void:
	_hush_until = GameClock.now_ms() + int(secs * 1000.0)
	if _hush_tw != null and _hush_tw.is_valid():
		_hush_tw.kill()
	_hush_tw = create_tween()
	for l: Label in [_intent, _intent_text]:
		_hush_tw.parallel().tween_property(l, "modulate:a", 0.12, 0.08)
	_hush_tw.tween_interval(secs)
	for l2: Label in [_intent, _intent_text]:
		_hush_tw.parallel().tween_property(l2, "modulate:a", 1.0, 0.2)


func intent_hushed() -> bool:
	return GameClock.now_ms() < _hush_until


func _text_rect(labels: Array) -> Rect2:
	var r := Rect2()
	for l: Label in labels:
		if l == null or not l.is_visible_in_tree() or l.text == "":
			continue
		var g := l.get_global_rect()
		var f := l.get_theme_font(&"font")
		var fs := l.get_theme_font_size(&"font_size")
		var w := minf(g.size.x, f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x) \
			if f != null else g.size.x
		var t := Rect2(g.position.x + (g.size.x - w) * 0.5, g.position.y, w, g.size.y)
		r = t if r.size == Vector2.ZERO else r.merge(t)
	return r


# --- Its own movement --------------------------------------------------------

## THE CUSTODIAN AND THE MEGAFAUNA MOVE ON THEIR OWN (`FaunaMotion`, Jon's
## picks of Oct 13). The motion draws in the art's place, as a child of it, so
## the fly-in, the bob and the hit's flash (said to the art's `self_modulate`,
## which the motion copies) all still reach it; the art keeps drawing every
## picture as it always has, only its texture is off while the motion shows.
##
## The motion is cut from the picture the art would show WITHOUT a wind-up (its
## own charge is the motion's to light) and WITH the fight's hit marks
## (`art.marks`, `HitLayers`), drawn here and cut on a worker thread, once per
## picture: a new mark, a new wound band or the pack's half sheet cuts again
## (one cut at a time; the newest picture is cut next), and the old cut moves
## on until the new one is in. Without motion (reduced motion, headless,
## `FaunaMotion.enabled` off) none of this exists.
var _fauna: FaunaMotion
var _fauna_key := ""
var _fauna_job := -1
var _fauna_held := {}
var _fauna_tex: Texture2D
var _fauna_tele := false
var _fauna_e = null
## Not before (ms): a crack grows over many frames, each a new version of the
## marks, and a cut a frame would cost a picture drawn on the main thread each.
var _fauna_next := 0
## Settling for the death: nothing more is cut.
var _fauna_done := false


## Wired from `bind`.
func _fauna_bind(e, telegraphed: bool) -> void:
	if FaunaMotion.kind_of(e.template.id) < 0 or _dead or not FaunaMotion.enabled 			or not Router.animating():
		_fauna_off()
		return
	if _fauna_done:
		return
	_fauna_e = e
	_fauna_tele = telegraphed
	if _fauna != null:
		_fauna.windup(telegraphed)
	_fauna_recut()


## Cut the picture shown now, if it is not the one cut (and nothing is being
## cut: the next frame asks again).
func _fauna_recut() -> void:
	if _fauna_e == null or _fauna_done or _fauna_job >= 0 or GameClock.now_ms() < _fauna_next:
		return
	var e = _fauna_e
	var hull: int = e.hp if shown_hp < 0 else shown_hp
	var sc := _fauna_scale()
	var key := FaunaMotion.picture_key(e, hull, sc) + "|marks %d" % (art.marks.version if art.marks != null else -1)
	if key == _fauna_key:
		return
	_fauna_key = key
	_fauna_next = GameClock.now_ms() + 120
	var k := FaunaMotion.kind_of(e.template.id)
	var img := FaunaMotion.still_canvas(e, hull, sc, art.marks)
	var pic := FaunaMotion.picture_name(e)
	var held := {key = key}
	_fauna_held = held
	_fauna_job = WorkerThreadPool.add_task(func() -> void:
		var fm := FaunaMotion.new()
		fm.cut(img, k, sc, pic)
		held.fm = fm)


## How big the art draws the picture: its half sheet in a pack of three or more
## (`EnemyArt.draw_scale`, where it exists).
func _fauna_scale() -> float:
	var s = art.get("draw_scale")
	return float(s) if s != null else 1.0


## Wired from `_process`: the cut taken in when it is done, the motion kept
## over the art and stepped HERE, then the bob taken from that same step -- a
## motion stepped in its own `_process` could land a frame apart from the bob
## read here, and a part's step and the bob's on neighbouring frames put
## pixels back where they were (flip-backs 0.1-0.4 x1e-4 a frame, 0.011 still).
func _fauna_step(dt: float) -> void:
	if _fauna_job >= 0 and WorkerThreadPool.is_task_completed(_fauna_job):
		WorkerThreadPool.wait_for_task_completion(_fauna_job)
		_fauna_job = -1
		var fm: FaunaMotion = _fauna_held.get("fm")
		# a cut that comes in once the death has started is too late to show
		if fm != null and String(_fauna_held.get("key", "")) == _fauna_key and _fauna_key != "" 				and not _fauna_done:
			var t0 := GameClock.now()
			if _fauna != null:
				t0 = _fauna.t
				_fauna.queue_free()
			_fauna = fm
			art.add_child(fm)
			fm.auto = false
			fm.attach()
			fm.t = t0
			fm.bob_phase = _bob_phase
			fm.windup(_fauna_tele)
			if layers != null:
				layers.motion = fm
			if _fauna_tex == null:
				_fauna_tex = art.texture
			art.texture = null
		elif fm != null:
			fm.free()
	_fauna_recut()
	if _fauna == null:
		return
	_fauna.advance(dt)
	# where the art draws its canvas (`STRETCH_KEEP_CENTERED`): a half pixel
	# there lands on the next whole one, so this rounds the same way
	_fauna.position = ((art.size - _fauna.size) * 0.5).round()
	art.position.y = _art_base.y + _fauna.bob_px()


## The death is coming (`SectorScreen._prebuild_death`): back to the still
## picture before the breakup is cut from it.
func fauna_settle() -> void:
	_fauna_done = true
	if _fauna != null:
		_fauna.settle()


## A creature is about to fire: its strike (`SectorScreen._play_turn` waits
## for it). False when there is no creature's motion to wind up.
func fauna_strike() -> bool:
	if _fauna != null and _fauna.kind != FaunaMotion.Kind.CUSTODIAN and not _fauna_done:
		_fauna.strike()
		return true
	return false


func fauna_motion() -> FaunaMotion:
	return _fauna


## No cut outlives the slot that asked for it.
func _exit_tree() -> void:
	if _fauna_job >= 0:
		WorkerThreadPool.wait_for_task_completion(_fauna_job)
		_fauna_job = -1
		var fm: FaunaMotion = _fauna_held.get("fm")
		if fm != null:
			fm.free()


func _fauna_off() -> void:
	_fauna_key = ""
	_fauna_e = null
	if layers != null:
		layers.motion = null
	if _fauna != null:
		_fauna.queue_free()
		_fauna = null
	if _fauna_tex != null:
		art.texture = _fauna_tex
		_fauna_tex = null
