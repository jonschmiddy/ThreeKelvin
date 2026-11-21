extends Node

## Korvan's and Solari's colours where the game shows them, for a decision sheet: a card of each,
## their adverts and sponsored posts on the board, drawn by the game's own code. Windowed, through
## `render.sh`: `-- sheet=ManufacturerColourShot out=<png> [mfcolours=korvan:#mark:#field,solari:...]`.
## Why: docs/why/Database.md#manufacturer-colour-options

const POSTER := Vector2(104, 150)
const SPONSOR := Vector2(120, 120)
const STRIP := Vector2(236, 30)

var h := Harness.new()


## One of the board's own adverts (`_ad`), a strip as the board draws one, or a sponsored post.
class Piece extends PostingBoard:
	var kind := ""
	var k := 0
	var mid: StringName = &""

	func _process(_dt: float) -> void:
		pass

	func _draw() -> void:
		match kind:
			"ad":
				_ad(size, k)
			"strip":
				var S := BoardScreen.branded(BoardScreen.STRIPS[k], true)
				draw_rect(Rect2(Vector2.ZERO, size), S["bg"])
				centre_text_at(String(S["t"]), 0.0, 13.0, size.x, UITheme.FS_SMALL, S["ink"])
				centre_text_at(String(S["s"]), 0.0, 25.0, size.x, UITheme.FS_SMALL, Color(S["ink"]).darkened(0.25))
			"sponsor":
				_sponsored(size, mid)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var out := Harness.arg("out", "user://colours.png")
	var bg := ColorRect.new()
	bg.color = UITheme.VOID
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var x := 8.0
	for mf: StringName in [&"korvan", &"solari"]:
		var card := _card(mf)
		var view := CardView.new()
		view.position = Vector2(x, 8)
		bg.add_child(view)
		view.setup(card, true, 1)
		x += CardView.CARD_W + 10.0
	# each one's own adverts, then its sponsored post
	var y := 8.0
	for i in BoardScreen.ADS.size():
		if (BoardScreen.ADS[i] as Dictionary).has("manufacturer"):
			_piece(bg, "ad", i, &"", Vector2(x, y), POSTER)
			x += POSTER.x + 8.0
	x = 8.0
	y = 8.0 + CardView.CARD_H + 12.0
	for i in BoardScreen.STRIPS.size():
		if (BoardScreen.STRIPS[i] as Dictionary).has("manufacturer"):
			_piece(bg, "strip", i, &"", Vector2(x, y), STRIP)
			x += STRIP.x + 8.0
	for mf: StringName in [&"korvan", &"solari"]:
		_piece(bg, "sponsor", 0, mf, Vector2(x, y), SPONSOR)
		x += SPONSOR.x + 8.0
	await Harness.frames(get_tree(), 6)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out)
	h._ok("shot written", FileAccess.file_exists(out))
	h.verdict("manufacturercolourshot")
	get_tree().quit(h.code())


func _card(mf: StringName) -> CardData:
	for id in DB.modules:
		var m: ModuleData = DB.modules[id]
		if m.manufacturer == mf and m.slot == ModuleData.Slot.WEAPON and not m.resolved_cards().is_empty():
			return m.resolved_cards()[0]
	return null


func _piece(parent: Control, kind: String, k: int, mid: StringName, at: Vector2, sz: Vector2) -> void:
	var p := Piece.new()
	p.kind = kind
	p.k = k
	p.mid = mid
	p.position = at
	p.size = sz
	parent.add_child(p)
