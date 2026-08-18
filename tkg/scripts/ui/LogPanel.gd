class_name LogPanel
extends VBoxContainer

## Scrolling combat/run log. Colour-coded by who did what.

var _rt: RichTextLabel

func _init() -> void:
	add_theme_constant_override("separation", 6)

func _ready() -> void:
	add_child(UITheme.header("log"))
	add_child(UITheme.hsep())
	_rt = RichTextLabel.new()
	_rt.bbcode_enabled = true
	_rt.scroll_following = true
	_rt.custom_minimum_size = Vector2(0, 140)
	_rt.fit_content = false
	_rt.add_theme_font_size_override("normal_font_size", 11)
	var sb := UITheme.flat(Color("#0c1219"), UITheme.LINE, 0, 7, 8)
	_rt.add_theme_stylebox_override("normal", sb)
	add_child(_rt)
	Sig.log_line.connect(_on_line)

func _on_line(text: String, kind: StringName) -> void:
	var c := UITheme.log_colour(kind)
	_rt.append_text("[color=#%s]%s[/color]\n" % [c.to_html(false), text])
