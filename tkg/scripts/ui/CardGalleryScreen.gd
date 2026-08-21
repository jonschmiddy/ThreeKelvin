class_name CardGalleryScreen
extends Control

## Every card in the game, on one page.
##
## A development screen, reached with the CARDS tab or `godot --path . -- cards`.
## Card work is the most iterated thing in this project and the only way to see a
## card used to be to draw it in a fight — which shows you five, chosen by the
## shuffle, from whatever you happen to have installed. Half the catalog could be
## wrong for a week and nothing would say so.
##
## Grouped by manufacturer, because the banner, the emblem and the cut are the
## one part of a card that is meaningless in isolation — a house's mark only
## works if it does not look like the other six.
##
## Hovering lifts the card off the grid and opens a readout beside it. It is a
## LIFT and not a zoom: there are exactly two card scales, frozen an octave
## apart, because anything between them puts the frame on half-pixels and softens
## the 8px font. "Slightly bigger" is not a size this game has, and doubling — the
## only other integer option — swallows a third of the screen.
##
## The lifted copy floats in an overlay rather than the real card moving, because
## moving it means a child of a flow container changing position, and the
## container answers by reflowing the entire catalog under your cursor.

## How far the hovered card comes off the grid. Enough that the row it left is
## visibly a row with a gap in it — a two or three pixel nudge reads as a
## rendering wobble rather than as a deliberate lift.
const LIFT := 18.0

var _overlay: Control
var _hot: CardView = null
## Which module granted each view, so the readout can name it. The card itself
## only carries the module's NAME, and a dev screen should be able to say more
## than a string.
var _owner: Dictionary = {}

func setup() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()

func _build() -> void:
	var col_root := VBoxContainer.new()
	col_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	col_root.add_theme_constant_override("separation", 4)
	add_child(col_root)

	var head := HBoxContainer.new()
	head.add_child(UITheme.header("CARD GALLERY"))
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(gap)
	var count := UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	head.add_child(count)
	col_root.add_child(head)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col_root.add_child(scroll)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	var total := _fill(col)
	count.text = "%d cards · %d modules" % [total, DB.modules.size()]

	# Above everything, and deaf to the mouse: the pop must never become the
	# thing the cursor is pointing at, or hovering it would count as leaving the
	# card underneath and the two would fight.
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)

## One block per manufacturer, houses first and the unbranded last: precursor
## and grown things have no banner to compare, so they are not part of the
## comparison the grouping exists to make.
func _fill(col: VBoxContainer) -> int:
	var by_maker: Dictionary = {}
	for k in DB.modules:
		var m: ModuleData = DB.modules[k]
		var key := String(m.manufacturer)
		if not by_maker.has(key):
			by_maker[key] = []
		by_maker[key].append(m)

	var order: Array = []
	for id in DB.manufacturers:
		if by_maker.has(String(id)):
			order.append(String(id))
	if by_maker.has(""):
		order.append("")

	var total := 0
	for key in order:
		var label := DB.manufacturer_name(StringName(key)) if key != "" else "Unbranded"
		var bar := HBoxContainer.new()
		bar.add_theme_constant_override("separation", 5)
		var swatch := ColorRect.new()
		swatch.color = DB.manufacturer_colour(StringName(key))
		swatch.custom_minimum_size = Vector2(4, 12)
		bar.add_child(swatch)
		bar.add_child(UITheme.body(label.to_upper(), UITheme.ICE, UITheme.FS_SMALL))
		col.add_child(bar)

		var flow := HFlowContainer.new()
		flow.add_theme_constant_override("h_separation", 4)
		flow.add_theme_constant_override("v_separation", 4)
		flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_child(flow)

		for raw in by_maker[key]:
			var m: ModuleData = raw
			# resolved_cards(), not `cards`. The Grant Count Law decides how many
			# a module actually puts in a deck, so authoring two verbs on a
			# module that grants one means only one of them is ever seen. This
			# page shows what the deck sees.
			for c in m.resolved_cards():
				var v := CardView.new()
				v.setup(c, true, 1)
				v.mouse_filter = Control.MOUSE_FILTER_PASS
				v.hovered.connect(_on_hover)
				flow.add_child(v)
				total += 1
	return total

func _on_hover(v: CardView, entered: bool) -> void:
	if not entered:
		# Only the card that owns the pop may dismiss it. Moving between two
		# adjacent cards fires exited on the old one AFTER entered on the new,
		# so trusting every exited would clear a pop that had just been built.
		if _hot == v:
			_clear()
		return
	if _hot != null and _hot != v:
		_hot.modulate.a = 1.0
	_hot = v
	Widgets.clear(_overlay)
	# The card in the grid goes invisible while its lifted copy is out, or the
	# two overlap and the bottom of the original shows below the copy as a
	# duplicate banner. Alpha rather than `visible`, because a flow container
	# skips hidden children and would close the gap the lift just opened —
	# which is the gap that makes the lift read as a lift.
	v.modulate.a = 0.0

	# A LIFT, not a zoom.
	#
	# There are exactly two card scales and they are frozen an octave apart —
	# 1x and 2x — because anything between them puts the frame on half-pixels
	# and softens the 8px font, which is the one thing the frozen sizes exist to
	# prevent. So "slightly bigger" is not a size this game has. Doubling was
	# the only other integer option and it swallowed a third of the screen.
	#
	# The feel comes from the card rising off the grid instead: same size, six
	# pixels up, an ember frame around it, and the readout opening to the right.
	# That is what the hand does when you hover a card, and it costs no
	# resolution at all.
	var rest := v.global_position - global_position
	# Never above the top edge: a card on the first visible row still has to
	# have somewhere to rise to.
	var pos := Vector2(rest.x, maxf(2.0, rest.y - LIFT))

	# Frame and card ride in one wrapper so a single tween moves both, and so
	# the tween dies with them: a tween bound to a node Godot has already freed
	# is an error the next hover would trip over.
	var wrap := Control.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.position = rest
	_overlay.add_child(wrap)

	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel",
		UITheme.flat(Color(0, 0, 0, 0), UITheme.FLARE, 0, 0, 0))
	frame.position = Vector2(-2, -2)
	frame.size = Vector2(CardView.CARD_W + 4, CardView.CARD_H + 4)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(frame)

	var pop := CardView.new()
	pop.setup(v.card, true, 1)
	pop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(pop)

	# Rises from where the card is sitting rather than appearing above it. The
	# travel is what says "this one came out of the grid" — a card that simply
	# blinks into a higher position reads as a second card, not as the one you
	# are pointing at.
	var tw := wrap.create_tween()
	tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(wrap, "position", pos, 0.14)

	# The readout opens to the right, or to the left when there is no room —
	# a panel that runs off the edge is worse than no panel, because the part
	# that goes missing is the part you hovered for.
	var info := Widgets.card_readout(v.card)
	_overlay.add_child(info)
	var iw := info.custom_minimum_size.x
	var ix := pos.x + CardView.CARD_W + 6
	if ix + iw > size.x - 2.0:
		ix = pos.x - iw - 6.0
	info.position = Vector2(maxf(2.0, ix), pos.y)
	# Fades rather than slides. Two things travelling on different vectors reads
	# as two events; the card moves, the readout simply arrives with it.
	info.modulate.a = 0.0
	var it := info.create_tween()
	it.tween_property(info, "modulate:a", 1.0, 0.12)

	# Only now can it be kept on screen.
	#
	# The panel's height is not a number this function knows: every label in it
	# wraps, so how tall it ends up depends on how much text wrapped, and that
	# is settled by the layout pass rather than by the code that builds it. The
	# previous clamp used a flat 200px guess, which was fine for a two-keyword
	# card and ran off the bottom of the screen for anything wordier.
	#
	# One frame later the real height exists. The fade covers the correction,
	# and is_instance_valid covers the case where the cursor has already moved
	# on and taken this panel with it.
	await get_tree().process_frame
	if is_instance_valid(info):
		info.position.y = clampf(pos.y, 2.0,
			maxf(2.0, size.y - info.size.y - 2.0))

func _clear() -> void:
	if _hot != null:
		_hot.modulate.a = 1.0
	_hot = null
	Widgets.clear(_overlay)

