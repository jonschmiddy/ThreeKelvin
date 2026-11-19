class_name DeskLife
extends RefCounted

## What every science desk room's scalar half gives `DeskRoom` and `DeskScene`: its sound and
## card times, the small CPU layers its shader reads (steam, the porthole sky, dust, noise) and
## the uniforms of one frame. Each room is a port of its own page script (`DeskOne`, `DeskTwo`).
## Why: docs/why/DeskScene.md#porting-a-room

var meta: Dictionary
## Scene seconds of the lamp's click and the CRT's power-on (audio.js TIMES).
var lamp_at := 0.0
var crt_at := 0.0
## When the power-on is done (the page's `doneAt`): a leave from later starts here.
var done_at := 0.0
## Seconds after act 1 (u) when the title card is up: a tap before it does nothing.
var title_u := 0.0
var title_wipe := 0.4
## vec4s in the shader's small-light arrays (w_small, fl_small): four lights each.
var small_q := 4
## The page's scanlines over the glass on its 5x canvas: the multiplier on the fifth row of each
## art row, on the first (1: none), and 1 when the fifth is truncated rather than rounded.
var scan := Vector3(168.0 / 255.0, 224.0 / 255.0, 0.0)
var steam_box := Rect2i(0, 0, 1, 1)
var port_box := Rect2i(0, 0, 1, 1)
var steam_img: Image
var sky_img: Image
var dust_img: Image
var noise_img: Image
var noise_new := false


func _make_images(glass: Vector2i) -> void:
	steam_img = Image.create(steam_box.size.x, steam_box.size.y, false, Image.FORMAT_RF)
	sky_img = Image.create(port_box.size.x, port_box.size.y, false, Image.FORMAT_RGBA8)
	dust_img = Image.create(DeskFx.W, DeskFx.H, false, Image.FORMAT_RGF)
	noise_img = Image.create(glass.x, glass.y, false, Image.FORMAT_RF)


## The game's card: it waits for a tap instead of the page's 2.5 s.
func hold_title() -> void:
	pass


## The tap at u: the card wipes into the picture now (never before it is up).
func release(_u: float) -> void:
	pass


## What the picture phase shows (RGBA8, 150 x 140), for a room whose screen light follows it.
func set_screen(_img: Image) -> void:
	pass


## The title card (DeskCard.title: RGB 0..255, alpha 1 on the blinking prompt).
func set_card(_img: Image) -> void:
	pass


## Everything the room's shader needs at scene time `ts` (backwards while leaving) on the free clock `real`.
func frame(_ts: float, _real: float, _is_leaving: bool) -> Dictionary[StringName, Variant]:
	return {} as Dictionary[StringName, Variant]
