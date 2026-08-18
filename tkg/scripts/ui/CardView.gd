class_name CardView
extends PanelContainer

## One card in hand. Manufacturer colour on the top edge, energy and heat on the
## footer, effect text generated from CardData so new cards need no UI work.

signal chosen(view: CardView)
signal hovered(view: CardView, entered: bool)

const CARD_W := 132
const CARD_H := 150

var card: CardData
var playable: bool = true

var _tween: Tween
var _base_y: float = 0.0
var _name_label: Label
var _text_label: Label
var _energy_label: Label
var _heat_label: Label
var _panel: StyleBoxFlat

func setup(c: CardData, can_play: bool) -> void:
	card = c
	playable = can_play
	custom_minimum_size = Vector2(CARD_W, CARD_H)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var colour := DB.manufacturer_colour(c.manufacturer)
	_panel = UITheme.flat(UITheme.PANEL2, UITheme.LINE, 3, 8, 9)
	_panel.border_width_top = 3
	_panel.border_color = colour
	if c.unplayable:
		_panel.bg_color = Color("#1a1418")
	add_theme_stylebox_override("panel", _panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	add_child(box)

	_name_label = UITheme.body(c.name, UITheme.ICE, UITheme.FS_SMALL)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_name_label)

	_text_label = UITheme.body(c.describe(), UITheme.CHILL, 10)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_text_label)

	box.add_child(UITheme.hsep())

	var footer := HBoxContainer.new()
	box.add_child(footer)
	_energy_label = UITheme.body("%d NRG" % c.energy, UITheme.ICE, 10)
	footer.add_child(_energy_label)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	_heat_label = UITheme.body("%d HEAT" % c.heat if c.heat > 0 else "—", UITheme.EMBER, 10)
	footer.add_child(_heat_label)

	set_playable(can_play)

func set_playable(can_play: bool) -> void:
	playable = can_play
	modulate.a = 1.0 if can_play else 0.34

func _ready() -> void:
	_base_y = position.y
	mouse_entered.connect(_on_hover_in)
	mouse_exited.connect(_on_hover_out)
	gui_input.connect(_on_input)

## Deliberately does nothing on click. A card is played by dragging it onto a
## target — your hull for defence and utility, an enemy for anything that hits.
## Click-to-play would quietly pick a target for you, which is the decision the
## drag exists to make.
func _on_input(_event: InputEvent) -> void:
	pass

func _on_hover_in() -> void:
	emitted_hover(true)
	if not playable:
		return
	_panel.border_color = UITheme.FLARE
	_animate_lift(-8.0)

func _on_hover_out() -> void:
	emitted_hover(false)
	_panel.border_color = DB.manufacturer_colour(card.manufacturer)
	_animate_lift(0.0)

func _animate_lift(offset: float) -> void:
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "position:y", _base_y + offset, 0.12)

## Fly the card toward the enemy as it resolves, then fade.
func play_flourish(target: Vector2) -> void:
	var tw := create_tween().set_parallel(true)
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tw.tween_property(self, "global_position", target, 0.18)
	tw.tween_property(self, "modulate:a", 0.0, 0.18)
	tw.tween_property(self, "scale", Vector2(0.7, 0.7), 0.18)
	tw.chain().tween_callback(queue_free)

func emitted_hover(entered: bool) -> void:
	hovered.emit(self, entered)

## Dragging a card onto an enemy targets it. The preview is a shrunken copy so
## the cursor still shows what is being thrown.
func _get_drag_data(_pos: Vector2) -> Variant:
	if not playable:
		return null
	# The card itself follows the cursor. A stand-in rectangle makes you track
	# two things at once: what you grabbed, and what the blob represents.
	var ghost := CardView.new()
	ghost.setup(card, true)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var wrap := Control.new()
	wrap.add_child(ghost)
	ghost.position = -Vector2(CARD_W, CARD_H) * 0.5
	set_drag_preview(wrap)
	# Hide the original outright rather than ghosting it. A half-faded copy reads
	# as a rendering fault; an empty slot reads as "you are holding that one".
	# Alpha rather than visible so the hand does not reflow mid-drag.
	modulate = Color(1, 1, 1, 0)
	# And stop it intercepting. The reorder preview parks this card under the
	# cursor by design, so leaving it clickable means the drop lands on the card
	# being dragged, gets refused, and snaps back.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return {"card": card, "view": self}

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END:
		modulate = Color.WHITE
		mouse_filter = Control.MOUSE_FILTER_STOP

## A card sits on top of the hand and would otherwise swallow the drop, so it
## forwards: releasing over a card means "put it here", which is the whole point
## of dropping on that card rather than beside it.
func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	if not (data is Dictionary and data.has("card")) or data["card"] == card:
		return false
	var hand := get_parent() as HandView
	if hand != null:
		# Hand-local x, so the slot is chosen by where the cursor is rather than
		# by which card is currently sliding underneath it.
		hand.preview_at(position.x + _pos.x, data["card"])
	return true

func _drop_data(_pos: Vector2, data: Variant) -> void:
	var hand := get_parent() as HandView
	if hand != null:
		hand.reorder_onto(data["card"], self)
