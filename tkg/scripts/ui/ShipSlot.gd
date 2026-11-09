class_name ShipSlot
extends AimTarget

## Your own hull as a drop target. Attacks are refused here — dropping a weapon
## on yourself should not silently do something else.

var art: ShipView
var claim: Callable
var preview: Callable

## Hull is centred in the left two thirds by anchor, as `ShipView.arrive()` resets position.
## Why: docs/why/ShipSlot.md#own-ship-slot
const HULL_BIAS := 0.68

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	art = ShipView.new()
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# `set_anchor()`, not `anchor_right =`: the property setter keeps the offset, a no-op.
	art.set_anchor(SIDE_RIGHT, HULL_BIAS, false)
	# Behind the slot's own `_draw`, or the brace number is covered by the ship.
	art.show_behind_parent = true
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# `zoom()`, not `magnify()`: the slot width is anchored, so a minimum size would fight it.
	# Why: docs/why/ShipSlot.md#own-ship-slot
	art.zoom(1)
	# The idle bob is 2, as on the ship screen; it moves inside the canvas, not the Control.
	# Why: docs/why/ShipSlot.md#own-ship-slot
	art.bob(2)
	# The hull is now bigger than its slot on the deepest frames, and the
	# enemy panel is immediately to the right of it.
	art.clip_contents = true
	add_child(art)

	# Fitted parts show passively here; refit stays the only place to change them.
	var mounts := MountPoints.new()
	mounts.attach(art)
	mounts.passive()
	art.add_child(mounts)
	# The one outline on your hull while a card is aimed at it (C1).
	mark = MarkOutline.new()
	mark.view = art
	mark.visible = false
	art.add_child(mark)

	# Column sized to the hull, not the slot, or 20 px reads as a drawn rule, not a beam.
	# Why: docs/why/ShipSlot.md#jump-flare
	_flare_box = Control.new()
	_flare_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flare_box)
	# `JumpFx` not `JumpFlare`: every style peaks on one frame, so the swap frame is fixed.
	flare = JumpFx.new()
	flare.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flare_box.add_child(flare)

var flare: JumpFx
var _flare_box: Control

## Re-measured at play time and tracked each frame, so the beam does not miss the moving hull.
## Why: docs/why/ShipSlot.md#jump-flare
func _process(_d: float) -> void:
	if not flare.visible:
		set_process(false)
		return
	# One clock: charge, snap and run live in `JumpFx`; the hull is told where it is on it.
	if flare.melts():
		art.set_melt(flare.melt_amount())
		art.set_shake(flare.shake_amount())
		art.set_spool(flare.spool_look(), flare.spool_amount(), flare.charge_secs())
	_aim()

func _aim() -> void:
	# THE BODY, NOT THE CANVAS. The canvas carries empty columns at the stern
	# for the exhaust art, so a box sized to it put every beam past the tail.
	var b := art.hull_body()
	_flare_box.position = art.position + b.position
	_flare_box.size = b.size

func pulse() -> JumpFx:
	# Hull, not slot: sizing to the slot drew rings wider than the ship is long.
	_aim()
	flare.centre = 0.5
	flare.play(0.0)
	set_process(true)
	return flare

## Your hull refuses attacks, same rule the drop path uses.
func aimable(c: CardData) -> bool:
	if c == null:
		return false
	return c.damage <= 0 and not c.damage_equals_heat and c.evoke <= 0


## NO `_can_drop_data`. See `AimTarget.aim` and `CardView`'s note: your hull is
## aimed at, not dropped on.

func _notification(what: int) -> void:
	# The hull's box follows the slot's: a shudder written while the column was in kept a clamped size.
	# The offsets keep only the move the shudder made.
	# Why: docs/why/ShipSlot.md#hull-box-follows-the-slot
	if what == NOTIFICATION_RESIZED and art != null:
		art.offset_right = art.offset_left
		art.offset_bottom = art.offset_top

func _draw() -> void:
	if not _hot:
		return
	# The outline is `mark`, on the hull's own pixels. Only the number is drawn here.
	# Card benefit shows over your hull, centred on its ink.
	# Why: docs/why/ShipSlot.md#drag-preview
	if _drag_text != "":
		HitText.draw_centred(self, ink_rect().get_center(), _drag_text, HitText.colour(&"gain"))

## Your hull's ink in this slot's coordinates, the bob taken out.
func ink_rect() -> Rect2:
	if art == null:
		return Rect2(Vector2.ZERO, size)
	var r := art.ship_rect()
	r.position += art.position
	return r
