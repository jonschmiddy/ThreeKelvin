class_name TagLayer
extends Control

## THE GAME'S TOOLTIPS, as one torn tag at the thing (stripped-down UI T1, Jon, Nov 9). Godot's
## own tooltips open at the cursor in a framed panel with a title; this layer turns them off
## and shows `TornTag` right above whatever the pointer rests on, from the control's own
## `tooltip_text`. A control that builds a rich tooltip gets that body on the tag's plate.
## Why: docs/why/TagLayer.md#one-tag-at-the-thing

## How long the pointer rests before the tag shows; the badge reads the same number.
const DELAY := 0.25
## A tag never shows a leading title line in caps: the tag is the sentence, the thing is the title.
const TITLE_MAX_WORDS := 4

static var instance: TagLayer = null

var _over: Control = null
var _since := 0.0
var _tag: Control = null
var _text := ""
## The control the tag up now belongs to.
var _owner: Control = null
## Tags this layer should not show, by control: the fight's keyword tags are their own (T2).
var _quiet: Dictionary = {}


func _init() -> void:
	instance = self
	name = "TagLayer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Godot's own tooltips are off in project.godot (gui/timers/tooltip_delay_sec, read once at
	# start): this layer is the tooltip.


## Where the pointer last was, in this layer's coordinates, from the motion events it sees.
var _pointer := Vector2.INF


func _input(e: InputEvent) -> void:
	var mm := e as InputEventMouseMotion
	if mm != null:
		_pointer = get_global_transform().affine_inverse() * mm.position


func _process(dt: float) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var h: Control = vp.gui_get_hovered_control()
	# Headless keeps no GUI hover (BadgeTest's note): the control under the last motion then.
	if h == null and _pointer != Vector2.INF and DisplayServer.get_name() == "headless":
		h = under(get_tree().root, _pointer)
	if vp.gui_is_dragging() or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		h = null
	if h != _over:
		_over = h
		_since = 0.0
		_hide()
		return
	_since += dt
	if _over == null:
		return
	var owner := _owner_of(_over)
	var text := _text_of(owner) if owner != null else ""
	if _tag != null:
		# The words can change under a resting pointer (a gauge refreshes, the hull moves off a
		# wreck): a changed text rebuilds the tag, an empty one takes it down.
		if text != _text or owner != _owner:
			_hide()
			if text != "":
				_show(owner, text)
		else:
			_tag.position = _spot(owner, _tag.size)
		return
	if _since >= DELAY and text != "":
		_show(owner, text)


## The control whose tooltip the pointer gets: the hovered one, or the nearest parent with words
## for this spot, as Godot's own tooltip walked up (a wreck's hit layers sit over its hull).
func _owner_of(h: Control) -> Control:
	var c := h
	while c != null:
		if _text_of(c) != "":
			return c
		c = c.get_parent_control()
	return null


## The topmost visible Control under `p` that takes the mouse, children before parents and later
## children first, as the GUI picks one; a parent that clips hides what it clips.
static func under(n: Node, p: Vector2) -> Control:
	var c := n as Control
	if c != null and (not c.visible or not c.is_inside_tree()):
		return null
	if n is CanvasItem and not (n as CanvasItem).visible:
		return null
	if c != null and c.clip_contents and not c.get_global_rect().has_point(p):
		return null
	for i in range(n.get_child_count() - 1, -1, -1):
		var hit := under(n.get_child(i), p)
		if hit != null:
			return hit
	if c != null and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(p):
		return c
	return null


## The control's tooltip for where the pointer is on it, or "" for none.
func _text_of(c: Control) -> String:
	if not is_instance_valid(c) or not c.is_visible_in_tree() or _quiet.has(c):
		return ""
	# The pointer this layer saw move, not the viewport's reading of it: on a hidden desktop
	# the viewport read garbage and every per-position tooltip (a wreck's hull) stayed shut.
	var at := c.get_local_mouse_position()
	if _pointer != Vector2.INF:
		at = c.get_global_transform().affine_inverse() * (get_global_transform() * _pointer)
	return c.get_tooltip(at)


func _show(c: Control, text: String) -> void:
	_text = text
	_owner = c
	# Main's theme, by hand: a CanvasLayer passes none down, and a rich body wants the font.
	if theme == null:
		var host := get_parent().get_parent() as Control if get_parent() != null else null
		if host != null:
			theme = host.theme
	var body: Control = null
	if c.has_method("_make_custom_tooltip"):
		body = c.call("_make_custom_tooltip", text) as Control
	if body != null:
		var plate := PanelContainer.new()
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_theme_stylebox_override("panel", UITheme.torn_box())
		body.mouse_filter = Control.MOUSE_FILTER_IGNORE
		plate.add_child(body)
		_tag = plate
		add_child(_tag)
		_tag.reset_size()
		_tag.size = _tag.get_combined_minimum_size()
	else:
		var tag := TornTag.new()
		tag.set_lines(TornTag.sentence(plain(text)))
		_tag = tag
		add_child(_tag)
	_tag.position = _spot(c, _tag.size)


func _hide() -> void:
	if _tag != null:
		if is_instance_valid(_tag):
			remove_child(_tag)
			_tag.queue_free()
		_tag = null
	_text = ""
	_owner = null


## How big a control can be before its tag sits by the pointer instead: a whole scene (the
## yard) answers per position, and its tag belongs to the drone under the pointer, not the hall.
const WIDE := Vector2(300.0, 200.0)


## Above the thing, clear of it, inside the screen (`TornTag.place`).
func _spot(c: Control, sz: Vector2) -> Vector2:
	var about := c.get_global_rect()
	var inv := get_global_transform().affine_inverse()
	about = Rect2(inv * about.position, about.size)
	if (about.size.x > WIDE.x or about.size.y > WIDE.y) and _pointer != Vector2.INF:
		about = Rect2(_pointer - Vector2(12, 22), Vector2(24, 44))
	return TornTag.place(sz, about, Rect2(Vector2(2, 2), size - Vector2(4, 4)))


## The sentence out of a tooltip's text: a short title line in caps goes (the thing under the
## pointer is the title), and the rest reads as one run of words.
static func plain(text: String) -> String:
	var paras: Array = []
	for p in text.replace("\r", "").split("\n\n"):
		var one := " ".join(Array((p as String).split("\n")).filter(func(l: String) -> bool: return l.strip_edges() != ""))
		if one.strip_edges() != "":
			paras.append(one.strip_edges())
	if paras.size() > 1:
		var head: String = paras[0]
		if head == head.to_upper() and head.split(" ").size() <= TITLE_MAX_WORDS:
			paras.pop_front()
	return "  ".join(paras)


## Keep this layer's tag off `c` (a control with a tag of its own) until `release`.
func hold_off(c: Control, on: bool) -> void:
	if on:
		_quiet[c] = true
	else:
		_quiet.erase(c)
	if on and _over == c:
		_hide()


## The tag up now, for the harness: null, a `TornTag`, or a plate round a rich body.
func shown() -> Control:
	return _tag
