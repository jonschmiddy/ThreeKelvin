class_name HitLayers
extends Control

## Jon's picks, Oct 13: hits D, bubble shield, brace I. Seeded, so shared fights draw the
## same marks.
## Why: docs/why/HitLayers.md#hit-layers

signal moment(kind: StringName, strength: float, length: float)

var hits: ShipHitFx
var shield: ShieldFx
var brace: BraceFx
var max_hp := 1
var _img: Image
var _used: Rect2i
## A living creature takes the creature looks and keeps off its words; -1 is a ship.
var kind := -1
var body: FaunaGuard.Body = null
var motion: FaunaMotion = null
var keep: Array = []
## The art's own modulate (a hit's white flash), for a look that covers the
## hide (the hardened hide), so the flash still shows on it.
var skin_mod := Color.WHITE


## `facing` -1 for enemy shots from the left; `bake` true when the owner draws marks into
## its picture.
func setup(img: Image, used: Rect2i, seed: int, facing: int, hull_max: int, scale: float = 1.0,
		bake: bool = false) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_img = img
	_used = used
	max_hp = maxi(1, hull_max)
	# Drawn in this order: the marks, the armour over them, the bubble over both.
	if FaunaGuard.wants(kind):
		body = FaunaGuard.body(img, kind, scale)
		var fb := FaunaBrace.new()
		fb.body = body
		brace = fb
		var fh := FaunaHitFx.new()
		fh.body = body
		hits = fh
		var fs := FaunaShield.new()
		fs.body = body
		shield = fs
	else:
		brace = BraceFx.new()
		hits = _hull_hits()
		shield = ShieldFx.new()
	brace.setup(img, used, Vector2.ZERO, seed + 3, facing)
	hits.mark_scale = scale
	hits.draw_marks = not bake
	hits.setup(img, used, Vector2.ZERO, seed + 1, facing)
	shield.setup(img, used, Vector2.ZERO, seed + 2, facing)
	for n in [hits, brace, shield]:   # marks under the armour, the bubble over both
		var c: Control = n
		c.size = size if size != Vector2.ZERO else Vector2(img.get_size())
		add_child(c)
		c.moment.connect(func(k: StringName, s: float, l: float) -> void: moment.emit(k, s, l))


## Custodian keeps ShipHitFx's older marks: it is grown, not built.
func _hull_hits() -> ShipHitFx:
	if ShipHitFx.look > 0 and kind != FaunaMotion.Kind.CUSTODIAN:
		var h := HullHitFx.new()
		h.style = ShipHitFx.look
		return h
	return ShipHitFx.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		for c in get_children():
			(c as Control).size = size


## A volley landed: `absorbed` went into block, then brace, as Combat spends
## them; `dealt` reached the hull, leaving it at `hp_after`.
func land(dealt: int, absorbed: int, hp_after: int) -> void:
	var left := absorbed
	if left > 0 and shield.block > 0:
		var s := mini(left, shield.block)
		shield.hit(s)
		left -= s
	if left > 0 and brace.brace > 0:
		brace.absorb(left)
	if dealt > 0:
		hits.hit(dealt, maxi(0, hp_after), max_hp)
	hits.set_hull(float(hp_after) / float(max_hp))


## Rises shimmer or clamp on; a fall in block with nothing in flight is the turn clearing,
## so it fizzles.
func sync(block: int, brace_now: int, hp: int, settle_falls: bool) -> void:
	if block > shield.block:
		shield.gain(block - shield.block)
	elif block < shield.block and settle_falls:
		if block <= 0:
			shield.expire()
		else:
			shield.block = block
	if brace_now > brace.brace:
		brace.gain(brace_now - brace.brace)
	elif brace_now < brace.brace and settle_falls:
		brace.shed_to(brace_now)
	hits.set_hull(float(hp) / float(max_hp))


# ---------------------------------------------------------------- your ship

## Read, never changed: ShipView is drawn by others, so this follows its origin,
## magnification and bob.
var follow: ShipView = null
var bob0 := 0


## Over your own ship: the picture from `v` as drawn now, shots from the right.
static func for_ship(v: ShipView, seed: int, hull_max: int) -> HitLayers:
	if v == null or v.canvas() == null:
		return null
	var img := v.canvas().duplicate() as Image
	if img.get_format() != Image.FORMAT_RGBA8:
		img.convert(Image.FORMAT_RGBA8)
	var L := HitLayers.new()
	L.follow = v
	L.bob0 = v.bob_offset()
	L.size = Vector2(img.get_size())
	L.setup(img, img.get_used_rect(), seed, 1, hull_max, 0.6 if v.is_half() else 1.0, false)
	return L


func _process(_dt: float) -> void:
	if follow == null:
		return
	if not is_instance_valid(follow):
		queue_free()
		return
	var k := float(maxi(1, follow.zoom_level()))
	var tex := Vector2(follow.canvas().get_size()) * k
	var origin := ((follow.size - tex) * 0.5).floor()
	position = follow.position + origin + Vector2(0.0, float(follow.bob_offset() - bob0) * k)
	scale = Vector2(k, k)
	visible = follow.is_visible_in_tree() and follow.self_modulate.a > 0.0 and follow.modulate.a > 0.0


## The turn opened: what block is left goes.
func expire_block() -> void:
	shield.expire()


## The ship's picture with every mark on it (for a death and its wreck).
func damaged(img: Image) -> Image:
	return hits.damaged(img)


## Anything still to finish (a crack still running): a death waits for it.
func busy() -> bool:
	return hits.busy()
