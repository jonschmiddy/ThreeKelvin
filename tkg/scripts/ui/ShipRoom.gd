class_name ShipRoom
extends RefCounted

## THE SHIP-SELECT ROOM behind a maker's three stands (Jon, Nov 22-24): `under` is the
## room and its back life, `above` its front life and air (over the hulls, under the banners).
## Why: docs/why/ShipRoom.md#rooms

const W := 960
const H := 540
const DIR := "res://art/sprites/station/shiprooms/%s/"
## The wall's foot row: the floor starts on the next.
const WALL_FOOT := 207
## Each weight's berth (PORT.md): its middle, the stands' old spread, the feet's row,
## and the row a hull's belly sits two below.
const CENTRE := {HullData.Weight.LIGHT: 200, HullData.Weight.MEDIUM: 776, HullData.Weight.HEAVY: 480}
const APART := {HullData.Weight.LIGHT: 84, HullData.Weight.MEDIUM: 108, HullData.Weight.HEAVY: 180}
const FEET := {HullData.Weight.LIGHT: 372, HullData.Weight.MEDIUM: 372, HullData.Weight.HEAVY: 334}
const SEAT := {HullData.Weight.LIGHT: 295, HullData.Weight.MEDIUM: 295, HullData.Weight.HEAVY: 267}
## A tarp's hem row over the stand tops, by weight (PORT.md, Old's tarps).
const HEM := {HullData.Weight.LIGHT: 34, HullData.Weight.MEDIUM: 34, HullData.Weight.HEAVY: 30}

var id: StringName = &""
var under: Control
var above: Control
var layout: Dictionary = {}
## Seconds on the room's own clock (GameClock time, so films run true).
var t := 0.0
## The lamps' beat from outside (a launch's stutter): 1 is as the room lights itself.
var lamp_k := 1.0
## Light a launch throws (`ShipLift`): [x, y, rx, ry, k, Color, ...] each, as `YardLife.extra`.
var extra: Array = []
## The stand sets, once the hulls are placed (`placed`).
var sets: Array = []

## How many rooms have been built: once a room change, never a pick (`YardPerfTest`).
static var builds := 0

var _mat_room: ShaderMaterial
var _mat_thing: ShaderMaterial
var _mat_hull: ShaderMaterial
var _post_img: Image = null
var _shadows: TextureRect = null


## The room a set is shown in: a locked maker's tarps in the Old hangar, Solari's ships on
## the casting bed, and every other open maker's in Korvan's depot.
static func id_for(m: StringName, open: bool) -> StringName:
	if not open:
		return &"old"
	return &"solari" if m == &"solari" else &"korvan"


static func make(room_id: StringName) -> ShipRoom:
	var r: ShipRoom
	match room_id:
		&"solari":
			r = ShipRoomSolari.new()
		&"old":
			r = ShipRoomOld.new()
		_:
			r = ShipRoomKorvan.new()
	r.id = room_id
	return r


static func tex(room_id: StringName, file: String) -> Texture2D:
	var p := (DIR % String(room_id)) + file
	return load(p) as Texture2D if ResourceLoader.exists(p) else null


## Build the layers and the room's own life (`_build`).
func build() -> void:
	builds += 1
	var f := FileAccess.get_file_as_string((DIR % String(id)) + "layout.json")
	var d: Variant = JSON.parse_string(f) if f != "" else null
	layout = d if d is Dictionary else {}
	under = _layer("ShipRoomUnder")
	above = _layer("ShipRoomAbove")
	var post := tex(id, "post.png")
	_post_img = post.get_image() if post != null else null
	if _post_img != null and _post_img.get_format() != Image.FORMAT_RGBA8:
		_post_img.convert(Image.FORMAT_RGBA8)
	_mat_room = _material(0)
	_mat_thing = _material(1)
	_mat_hull = _material(2)
	var pic := ColorRect.new()
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.size = Vector2(W, H)
	pic.material = _mat_room
	under.add_child(pic)
	_shadows = TextureRect.new()
	_shadows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shadows.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mul := CanvasItemMaterial.new()
	mul.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_shadows.material = mul
	under.add_child(_shadows)
	_build()


static func _layer(n: String) -> Control:
	var c := Control.new()
	c.name = n
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.size = Vector2(W, H)
	return c


func _material(mode: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/ship_room.gdshader")
	m.set_shader_parameter(&"mode", mode)
	m.set_shader_parameter(&"albedo", tex(id, "albedo.png"))
	m.set_shader_parameter(&"light", tex(id, "light.png"))
	m.set_shader_parameter(&"emissive", tex(id, "emissive.png"))
	m.set_shader_parameter(&"gain", float(layout.get("light_gain", 1.0)))
	m.set_shader_parameter(&"hull_amb", hull_amb())
	return m


## The room's own layers on top of the package's picture (a room class's life).
func _build() -> void:
	pass


## A hull's light where it stands: each hull sets its `rows` (top, foot) itself.
func hull_material() -> Material:
	return _mat_hull


## A post, a tarp's stand or anything standing in the room, lit as the room is there.
func thing_material() -> Material:
	return _mat_thing


func hull_amb() -> float:
	return 0.6


## The near-black the floor fades into under the band (`YardFront.fall_texture`).
func band_colour() -> Color:
	return Color8(14, 16, 22)


## The room's ceiling lamps as (x, reach), for a launch's smoke tops (`ShipLift.lamps`).
func ceiling_lamps() -> Array[Vector2]:
	return []


## Rows a post's top is tucked up behind the belly (PORT.md: 3, Old's 4).
func tuck() -> int:
	return 3


## The tallest post of the room's stand A, every post built from it (`post_rows`).
func post_image() -> Image:
	return _post_img


## The hulls (or tarps) and their posts are placed: the posts' contact shadows go down.
func placed(s: Array) -> void:
	sets = s
	_shadows.texture = ImageTexture.create_from_image(contact_shadows(s))
	_placed()


func _placed() -> void:
	pass


func tick(dt: float) -> void:
	t += dt
	for m in [_mat_room, _mat_thing, _mat_hull]:
		(m as ShaderMaterial).set_shader_parameter(&"lamp_k", lamp_k)
	_tick(dt)


func _tick(_dt: float) -> void:
	pass


## The 4x4 ordered dither the films stepped light on, at a frame pixel: 0 to 15/16.
static func bayer4(x: int, y: int) -> float:
	const B := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]
	return float(B[(y & 3) * 4 + (x & 3)]) / 16.0


## Every post's contact shadow (PORT.md, "Contact shadow"), as a multiply over the frame:
## an ellipse round its feet, solid inside, its rim ordered-dithered, never a block.
## Why: docs/why/ShipRoom.md#contact-shadows
static func contact_shadows(s: Array) -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	for st: Variant in s:
		var set := st as YardStandSet
		if set == null:
			continue
		for x in set.post_x:
			_contact(img, x - 2, x + set.post_w + 2, set.feet, 6, 0.5)
	return img


static func _contact(img: Image, x0: int, x1: int, feet: int, length: int, dark: float) -> void:
	var cx := (x0 + x1) / 2.0
	var rx := maxf(2.0, (x1 - x0) / 2.0 + 3.0)
	var ry := float(length)
	for dy in range(-1, length + 1):
		var y := feet + dy
		if y < 0 or y >= H:
			continue
		for x in range(maxi(0, int(cx - rx) - 1), mini(W, int(cx + rx) + 2)):
			var r := sqrt(pow((x - cx) / rx, 2.0) + pow((dy + 1) / (ry + 1.0), 2.0))
			var k := clampf(1.0 - r, 0.0, 1.0)
			var on := k > 0.35 or (k > 0.0 and bayer4(x, y) < k / 0.35)
			if not on:
				continue
			var f := 1.0 - dark * clampf(0.45 + k, 0.0, 1.0)
			var c := img.get_pixel(x, y)
			img.set_pixel(x, y, Color(c.r * f, c.g * f, c.b * f, 1.0))
