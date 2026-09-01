class_name HoldGrid
extends Control

## The hold, as a grid you pack.
##
## Not a GridContainer, and it cannot be one: a container gives every child a
## cell, and half the catalogue is wider or taller than one. A part is placed at
## `hold_at` and drawn across its own footprint, so the layout is arithmetic on
## a fixed cell rather than something a container decides.
##
## Everything here reads Run and writes nothing. Drops are reported upward and
## the screen owns the state change, which is the same split ModuleCell already
## uses — one place to read when a part ends up somewhere it should not.

## One cell.
##
## 30, up from 24 and 22 before that. The parts on the HULL now draw at the
## hull's own magnification, which doubled them, and a hold plate has to hold
## its own beside that — the two are meant to read as the same object and the
## whole reason they share a silhouette is so you can recognise the gun you are
## about to bolt on. ModuleIcon divides by 26 for its scale, so a 1x1 plate
## went from 0.92 to 1.15 of the authored size for free.
##
## FORTY, so the hull draws a cell at TWENTY.
##
## A fitted part is sized at half the hold (MountPoints.part_rect), so this
## number is really a decision about the ART: at 30 the hull cell was 15 and
## every module footprint — 15x15 up to 62x15 — sat under PixelLab's floor of
## 1024px of area, so no module could be generated at the size it is drawn.
## At 40 the hull cell is a round 20 and the boxes become 20x20, 40x20, 60x20,
## 80x20 and 40x40; the 3x1 and 4x1 clear the floor outright and can be
## generated native, with no crop and no reduction.
##
## It costs panel: 5 columns go from 154px to 200px. That is the trade, and it
## was made knowingly — fidelity in the thing you look at, paid for in a
## workbench that is a third larger.
const CELL := 40

## ZERO, and the lattice is now DRAWN rather than left as a hole.
##
## It used to be background showing between cells, which was subtle and cost
## nothing to maintain. It also made every cell 31 wide instead of 30, and a
## part five cells long 154 instead of 155 — fine on its own, and not fine once
## the hull's box is meant to be exactly half of it. A gap of one does not
## halve. So the cells now abut and `_draw` strokes the boundaries, which reads
## the same and divides cleanly.
const GAP := 0

## The outer edge, which is a stroke and is meant to be seen. The hold is one
## object with an inside; before this every cell drew its own full border, so
## the boundary between two cells was two strokes and a gap while the boundary
## of the whole grid was one — reading, wrongly, as the least important line on
## the block.
const EDGE := 2.0

## How far from the cursor a refused drop will look for room, in cells.
##
## Two. Far enough that a near miss lands where the hand was going, close enough
## that a part never appears somewhere you were not looking — which is the whole
## complaint about first-fit, and the reason this is a radius and not a search.
const NUDGE := 2

signal dropped(payload: Dictionary, at: Vector2i)

var _cols: int = 4
var _rows: int = 5
## Lit cells during a drag: where the thing being carried would actually fit.
var _beam: Dictionary = {}
var _beam_phase: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_process(false)

func refresh() -> void:
	var g := Run.hold_grid()
	_cols = maxi(1, g.x)
	_rows = maxi(1, g.y)
	custom_minimum_size = Vector2(_cols * (CELL + GAP) - GAP,
		_rows * (CELL + GAP) - GAP)
	Widgets.clear(self)
	for m in Run.cargo:
		if m.hold_at.x < 0:
			continue
		# TWO KINDS IN ONE GRID. A module draws the part, because recognising
		# the gun you are about to bolt on is the whole point of it sharing a
		# silhouette with the thing on the hull. A material has no hull form to
		# echo, so it draws a crate. See `MaterialIcon`.
		# A chit should never be in here -- `stow` cashes it. If one is, it
		# is a bug, and a bug you can SEE beats an invisible occupied cell.
		var icon := ItemIcon.make(m, &"cargo")
		# PASS, not STOP: the icon is what you pick UP, and the grid under it is
		# what you drop ONTO. A child that swallowed the hover would leave the
		# grid unable to say which cell the cursor is over.
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		add_child(icon)
		# SIZED AFTER add_child, AND the minimum cleared first. Both halves are
		# load-bearing and neither is obvious.
		#
		# ModuleIcon.setup puts a 44x44 floor under itself, which is right for a
		# rack cell and is two hold cells wide. Assigning `size` before the node
		# entered the tree let the minimum-size pass on entry overwrite it, so a
		# 1x1 fitting drew at 44 and hung a whole cell past the right edge of the
		# grid — visible only as plates overlapping, since the DATA underneath
		# was correctly in bounds the whole time. `-- holdtest` passes either way
		# and always would: this was never a packing bug.
		icon.custom_minimum_size = Vector2.ZERO
		icon.position = _origin(m.hold_at)
		icon.size = _footprint(m)
	queue_redraw()

func _origin(cell: Vector2i) -> Vector2:
	return Vector2(cell.x * (CELL + GAP), cell.y * (CELL + GAP))

func _footprint(m: HoldItem) -> Vector2:
	return ModuleIcon.footprint_box(m)

## The plate under a point in SCREEN coordinates, or null. What R turns when
## nothing is being carried.
func icon_at(p: Vector2) -> ModuleIcon:
	for c in get_children():
		if c is ModuleIcon and (c as Control).get_global_rect().has_point(p):
			return c
	return null

## Which cell a point falls in. Outside the grid returns (-1,-1).
func cell_at(p: Vector2) -> Vector2i:
	var c := Vector2i(int(floor(p.x / float(CELL + GAP))),
		int(floor(p.y / float(CELL + GAP))))
	if c.x < 0 or c.y < 0 or c.x >= _cols or c.y >= _rows:
		return -Vector2i.ONE
	return c

func _process(delta: float) -> void:
	_beam_phase = fmod(_beam_phase + delta * 2.4, TAU)
	queue_redraw()

func _draw() -> void:
	for y in _rows:
		for x in _cols:
			var r := Rect2(_origin(Vector2i(x, y)), Vector2(CELL, CELL))
			draw_rect(r, Color("#0b1017"), true)
	# THE LATTICE, drawn. With GAP at zero the cells abut, so the boundary
	# between two of them has to be a stroke — one line per interior edge,
	# shared by both cells, in the same ink as the outer edge so the hold
	# still reads as one object with an inside rather than as a stack of
	# separate tiles.
	for x in range(1, _cols):
		var px := float(x * CELL)
		draw_line(Vector2(px, 0.0), Vector2(px, size.y), UITheme.LINE, 1.0)
	for y in range(1, _rows):
		var py := float(y * CELL)
		draw_line(Vector2(0.0, py), Vector2(size.x, py), UITheme.LINE, 1.0)
	draw_rect(Rect2(Vector2.ZERO, size), UITheme.LINE, false, EDGE)
	if _beam.is_empty():
		return
	# The same pulse the hardpoints use, for the same reason: the hold and the
	# hull are answering one question — where does this go — and two different
	# idioms for it would read as two different answers.
	var pulse := 0.62 + 0.38 * sin(_beam_phase)
	var c := UITheme.TRACTOR
	for key in _beam:
		var cell: Vector2i = key
		var r := Rect2(_origin(cell), Vector2(CELL, CELL))
		draw_rect(r, Color(c.r, c.g, c.b, 0.16 * pulse), true)
		draw_rect(r, Color(c.r, c.g, c.b, 0.75 * pulse), false, 1.0)

## Where would `m` land if dropped at `p`, and does it fit anywhere near?
##
## NEAREST FREE CELL, within a couple of cells of the cursor, and NOTHING if
## there is none. This used to fall back to `Run.find_hold_slot` — first fit,
## scanning from the top-left — so nudging a part one cell to the left and
## catching a corner of its neighbour teleported it to the other end of the
## hold. Packing a grid is a game of small adjustments and that made every
## imprecise one destructive.
##
## Grabbed by the CELL UNDER THE CURSOR rather than by the part's top-left, so a
## wide part dropped with the cursor over its middle does not jump a cell left.
## Which cell the thing in your hand would land on.
##
## MEASURED FROM THE ITEM, NOT FROM THE POINTER. `ItemIcon.Ghost` centres the
## plate on the cursor -- that is what makes a drag feel like carrying something
## -- but this read the raw pointer position as the item's TOP-LEFT cell. For a
## 1x1 the two agree and nothing looked wrong. For a 3x1 the highlight sat a cell
## and a half to the right of the plate you were looking at, so the cells lit up
## only when the CURSOR crossed them rather than when the item did.
##
## Rounding, not flooring, once the half-footprint is taken off: with the plate
## centred, the nearest cell boundary is the one it is visibly nearest to, and
## flooring biases every drop up and to the left by half a cell.
func target_for(m: HoldItem, p: Vector2) -> Vector2i:
	var g := Run.hold_grid()
	var f := m.footprint()
	var step := float(CELL + GAP)
	var top_left := p - Vector2(f.x, f.y) * step * 0.5
	# Clamped, not rejected: a drop a few pixels outside the grid is aimed at
	# the edge cell, which is what the hand meant.
	var c := Vector2i(
		clampi(int(round(top_left.x / step)), 0, maxi(0, g.x - f.x)),
		clampi(int(round(top_left.y / step)), 0, maxi(0, g.y - f.y)))
	# One occupancy map for the whole probe -- this runs on every drag-over
	# frame, and `can_place` re-derived the map for each of the 26 candidates.
	var taken := Run.hold_taken(m)
	if Run.fits_at(taken, m, c):
		return c
	var best := -Vector2i.ONE
	var best_d := 1e9
	for dy in range(-NUDGE, NUDGE + 1):
		for dx in range(-NUDGE, NUDGE + 1):
			var t := c + Vector2i(dx, dy)
			if t.x < 0 or t.y < 0 or not Run.fits_at(taken, m, t):
				continue
			var d := Vector2(dx, dy).length_squared()
			if d < best_d:
				best_d = d
				best = t
	return best

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY or not data.has("module"):
		return false
	var m: HoldItem = data.module
	if m == null:
		return false
	# MONEY GOES ANYWHERE, so the whole hold lights up. It occupies no cell --
	# see `CreditChit` -- and beaming one square would be asking a question
	# about room that does not apply to it. Lighting all of them says the true
	# thing: wherever you let go, this lands.
	if m is CreditChit:
		_light_all()
		return true
	var target := target_for(m, at)
	_light(m, target)
	return target != -Vector2i.ONE

## Every cell at once, for the one thing that fits in all of them.
func _light_all() -> void:
	var g := Run.hold_grid()
	var want: Dictionary = {}
	for y in g.y:
		for x in g.x:
			want[Vector2i(x, y)] = true
	if want.keys() == _beam.keys():
		return
	_beam = want
	queue_redraw()


func _light(m: HoldItem, target: Vector2i) -> void:
	_beam.clear()
	if target != -Vector2i.ONE:
		var f := m.footprint()
		for dy in f.y:
			for dx in f.x:
				_beam[target + Vector2i(dx, dy)] = true
	set_process(not _beam.is_empty())
	queue_redraw()

func _drop_data(at: Vector2, data: Variant) -> void:
	var m: HoldItem = (data as Dictionary).module
	var target := target_for(m, at)
	_clear_beam()
	if target != -Vector2i.ONE:
		dropped.emit(data as Dictionary, target)

func _clear_beam() -> void:
	_beam.clear()
	set_process(false)
	queue_redraw()

func _notification(what: int) -> void:
	# Godot has no "the drag left me" callback, so the light is put out when the
	# mouse leaves and again when any drag anywhere ends — without the second,
	# a cell stays lit after a drop that landed on the hull instead.
	if what == NOTIFICATION_MOUSE_EXIT or what == NOTIFICATION_DRAG_END:
		_clear_beam()
