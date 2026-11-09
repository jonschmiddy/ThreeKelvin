extends Harness

## Needs a window: headless has no gui input, so the drag checks would pass by never running.
## Other hold tests check data; this one drives the refit interaction itself.
## Why: docs/why/FitTest.md#fit-test-purpose

## How much clear space a part's art must leave inside its own cell. Stated
## here rather than read off `ModuleIcon.PAD`, which is the thing being checked.
const WANT_PAD := 4.0

var _tree: SceneTree
var _at: Vector2 = Vector2.ZERO


## Seed is forced via `Rng.forced`: `start_new_run` used to discard the reseed. Failing seeds stay.
## Why: docs/why/FitTest.md#seeds
const SEEDS: Array[int] = [7711, 1360870258]


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	var seeds: Array[int] = SEEDS.duplicate()
	if Rng.forced != 0:
		seeds = [Rng.forced]
	for s in seeds:
		var before := _fails
		print("  fittest: seed %d" % s)
		await _pass(s)
		if _fails > before:
			_fail("seed %d: %d checks failed (replay: -- fittest seed %d)" % [s, _fails - before, s])
	Rng.forced = 0
	verdict("fittest")
	# It runs across frames, so nothing quits it: it printed its verdict and hung in the gate.
	# Why: docs/why/FitTest.md#self-ending
	_tree.quit(code())


## Every check, on a new run of seed `s` and a new refit screen.
func _pass(s: int) -> void:
	Rng.forced = s
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_ship()
	for i in 4:
		await _tree.process_frame

	var screen := Router.current
	if not _ok("the refit screen is up", screen is ShipScreen):
		return
	var grid := first(screen, func(n: Node) -> bool: return n is HoldGrid) as HoldGrid
	var mounts := first(screen, func(n: Node) -> bool: return n is MountPoints) as MountPoints
	if not _ok("the hold and the hardpoints are both on it",
			grid != null and mounts != null):
		return

	await _to_hull(grid, mounts)
	await _to_hold(grid, mounts)
	await _wrong_slot(grid, mounts)
	await _stripping(grid, mounts)
	await _lifting(grid, mounts)
	await _turning(grid)
	_geometry()
	_nothing_cut(screen)
	_nudging(grid)
	_hold_ladder()
	_pinned(screen)


# ---------------------------------------------------------------- the crossings

## Hold to hull: pick a part out of the grid and bolt it to a free mount.
func _to_hull(grid: HoldGrid, mounts: MountPoints) -> void:
	var m := _stow(ModuleData.Slot.WEAPON, true)
	if m == null:
		_fail("nothing in the catalogue fits a weapon mount")
		return
	await _settle(grid)
	var icon := _icon_for(grid, m)
	if not _ok("the part has a plate in the hold", icon != null):
		return
	var spot := _free_mount(mounts, ModuleData.Slot.WEAPON)
	if not _ok("the hull has a free weapon mount", spot != Vector2.INF):
		return

	var live := await _carry(_centre(icon), mounts, spot - mounts.get_global_rect().position)
	_ok("a plate in the hold can be picked up", live)
	_ok("dragged from the hold onto the hull: it is installed",
		Run.installed.has(m))
	_ok("dragged from the hold onto the hull: it left the hold",
		not Run.cargo.has(m))
	_ok("dragged from the hold onto the hull: it knows its mount", m.mount >= 0)


## Hull to hold: the drop branch was unreachable until something could start that drag.
func _to_hold(grid: HoldGrid, mounts: MountPoints) -> void:
	var m: ModuleData = null
	for x in Run.installed:
		if (x as ModuleData).slot == ModuleData.Slot.WEAPON:
			m = x
			break
	if not _ok("something is bolted on to take off", m != null):
		return
	var from := _mount_of(mounts, m)
	if not _ok("the fitted part has a place on the hull", from != Vector2.INF):
		return
	await _settle(grid)

	var cell := _room_for(grid, m)
	if not _ok("the hold has room for the part being taken off", cell != Vector2.INF):
		return
	var live := await _carry(from, grid, cell - grid.get_global_rect().position)
	await _became(func() -> bool: return Run.cargo.has(m))
	_ok("a part bolted to the hull can be picked up", live)
	_ok("dragged off the hull into the hold: it is stowed", Run.cargo.has(m))
	_ok("dragged off the hull into the hold: it is off the ship",
		not Run.installed.has(m))
	_ok("dragged off the hull into the hold: its mount is released", m.mount < 0)
	_ok("dragged off the hull into the hold: it has a cell", m.hold_at.x >= 0)


## A refused drop leaves the part put. The failure is a part refused after lifting, in neither.
func _wrong_slot(grid: HoldGrid, mounts: MountPoints) -> void:
	var m := _stow(ModuleData.Slot.WEAPON)
	if m == null:
		return
	await _settle(grid)
	var icon := _icon_for(grid, m)
	var spot := _free_mount(mounts, ModuleData.Slot.SYSTEM)
	if icon == null or spot == Vector2.INF:
		# No system mount free is not a failure of the rule under test.
		return
	var was := m.hold_at

	await _carry(_centre(icon), mounts, spot - mounts.get_global_rect().position)
	_ok("a weapon refused by a system mount stays in the hold", Run.cargo.has(m))
	_ok("a weapon refused by a system mount does not move", m.hold_at == was)
	_ok("a weapon refused by a system mount is not installed",
		not Run.installed.has(m))


## Reported: pulling one module off made the rest vanish. Data and tally looked right.
## Why: docs/why/FitTest.md#stripping
func _stripping(grid: HoldGrid, mounts: MountPoints) -> void:
	# Two weapons on the hull, fitted through the real drop handler.
	for i in 2:
		var w := _stow(ModuleData.Slot.WEAPON, true)
		if w == null:
			break
		await _settle(grid)
		var icon := _icon_for(grid, w)
		var spot := _free_mount(mounts, ModuleData.Slot.WEAPON)
		if icon == null or spot == Vector2.INF:
			break
		await _carry(_centre(icon), mounts, spot - mounts.get_global_rect().position)

	var held := _held(mounts)
	if not _ok("two parts are on the hull to start with", held.size() >= 2):
		return
	var goes: ModuleData = held[0]
	var stays: ModuleData = held[1]

	var from := _mount_of(mounts, goes)
	if not _ok("the part being taken off has a place on the hull",
			from != Vector2.INF):
		return
	await _settle(grid)
	var target := _room_for(grid, goes)
	# Seed 1360870258 left no 2x2 hole. A full hold refuses the drop: check that, then make room.
	# Why: docs/why/FitTest.md#full-hold
	if target == Vector2.INF:
		var parts := Run.installed.size() + Run.cargo.size()
		var mount := goes.mount
		await _carry(from, grid, Vector2(HoldGrid.CELL, HoldGrid.CELL) * 0.5)
		await _settle(grid)
		_ok("a part dragged off into a full hold stays on the ship",
			Run.installed.has(goes) and goes.mount == mount and not Run.cargo.has(goes))
		_ok("...and nothing is lost: %d parts before, %d after"
			% [parts, Run.installed.size() + Run.cargo.size()],
			Run.installed.size() + Run.cargo.size() == parts)
		while target == Vector2.INF and not Run.cargo.is_empty():
			Run.take_from_hold(Run.cargo[Run.cargo.size() - 1])
			Sig.ship_changed.emit()
			await _settle(grid)
			target = _room_for(grid, goes)
	if not _ok("the hold has room for the part being stripped", target != Vector2.INF):
		return
	await _carry(from, grid, target - grid.get_global_rect().position)
	await _became(func() -> bool: return not Run.installed.has(goes))
	_ok("the part that was dragged off is off", not Run.installed.has(goes))
	_ok("the part that was NOT touched is still installed",
		Run.installed.has(stays))
	_ok("...and still has its mount", stays.mount >= 0)
	var now := _held(mounts)
	_ok("...and the hull still draws it: %d of %d parts held after taking 1 off"
		% [now.size(), held.size()], now.has(stays))
	await _lit_keeps_the_parts(mounts, stays)


## Counts what the draw loop did, since pixel reads passed against the bug twice.
## Waits for the redraw to happen: one frame sampled the old counters about one run in five.
## Why: docs/why/FitTest.md#redraw-counting
func _redrawn(mounts: MountPoints) -> void:
	mounts.queue_redraw()
	await _tree.process_frame
	await _tree.process_frame

func _lit_keeps_the_parts(mounts: MountPoints, m: ModuleData) -> void:
	mounts.light(null)
	await _redrawn(mounts)
	var quiet := mounts.drawn

	mounts.light(m)
	await _redrawn(mounts)
	var lit := mounts.drawn
	var pings := mounts.pinged

	mounts.light(null)
	await _tree.process_frame
	_ok("the hull draws its parts with nothing in hand: %d" % quiet, quiet > 0)
	_ok("a part in hand does not blank the hull: %d drawn against %d"
		% [lit, quiet], lit == quiet)

	# Only empty mounts ping: rings drawn over an installed part swamped it (27 px on a 30 px gun).
	# Why: docs/why/FitTest.md#mount-ping-and-hint
	var free := 0
	for sp in mounts.spots():
		if sp.held == null and sp.slot == m.slot:
			free += 1
	_ok("only empty hardpoints ping: %d pings for %d free mounts of that kind"
		% [pings, free], pings == free)

	# Hover hints every empty mount of any slot; the ping is filtered to the held part's slot.
	# Counted, not looked at, as a pixel check passed against the bug twice.
	# Why: docs/why/FitTest.md#mount-ping-and-hint
	mounts.light(null)
	mounts.hover(_mount_local(mounts, m))
	await _redrawn(mounts)
	var hints := mounts.hinted
	var bare := 0
	for sp in mounts.spots():
		if sp.held == null:
			bare += 1
	_ok("hovering hints every empty mount: %d hints for %d empty mounts"
		% [hints, bare], hints == bare)

	# Hint and ping are never both up: they would be two answers to one question.
	mounts.light(m)
	await _redrawn(mounts)
	_ok("a part in hand replaces the hints with pings: %d hints, %d pings"
		% [mounts.hinted, mounts.pinged],
		mounts.hinted == 0 and mounts.pinged == free)
	mounts.light(null)
	mounts.hover(Vector2.INF)
	await _redrawn(mounts)
	_ok("and the hull goes quiet when the pointer leaves: %d hints"
		% mounts.hinted, mounts.hinted == 0)

	# The phase is asserted: hints shipped as a still, and drawn counts cannot see that.
	# Why: docs/why/FitTest.md#animated-hints
	mounts.hover(_mount_local(mounts, m))
	await _tree.process_frame
	var was: float = mounts._phase
	await _tree.process_frame
	await _tree.process_frame
	_ok("the hints animate: phase moved %.3f -> %.3f"
		% [was, mounts._phase], not is_equal_approx(was, mounts._phase))
	mounts.hover(Vector2.INF)
	await _tree.process_frame

	# Uses the live magnification, not a hardcoded 2, or a grabbable part failed the probe.
	# Why: docs/why/FitTest.md#grab-anywhere
	var r := mounts.part_rect(m, m.slot, _mount_local(mounts, m), mounts._mag())
	var far := r.position + r.size - Vector2(2, 2)
	_ok("a fitted part can be grabbed at its far corner", mounts.spot_at(far) >= 0)
	_ok("...and the far corner finds THAT part",
		mounts.spot_at(far) >= 0
		and mounts.spots()[mounts.spot_at(far)].held == m)


## A refused drop lands next door or nowhere: first-fit from the corner made nudges destructive.
## Why: docs/why/FitTest.md#nudged-drop
func _nudging(grid: HoldGrid) -> void:
	for x in Run.cargo.duplicate():
		Run.take_from_hold(x)
	var g := Run.hold_grid()
	var blocker := _fitting()
	var mover := _fitting()
	if not _ok("two 1x1 parts to push around", blocker != null and mover != null):
		return
	# A part sitting at (1,1), and the one being dragged aimed straight at it.
	Run.place_in_hold(blocker, Vector2i(1, 1))
	Run.place_in_hold(mover, Vector2i(3, 3))
	Run.take_from_hold(mover)
	var step := float(HoldGrid.CELL + HoldGrid.GAP)
	var onto := Vector2(1.5, 1.5) * step

	var t := grid.target_for(mover, onto)
	_ok("a drop onto an occupied cell lands beside it, not across the hold: %s"
		% t, t != -Vector2i.ONE and (t - Vector2i(1, 1)).length() <= HoldGrid.NUDGE)

	# And with everything within reach taken, it goes nowhere at all rather
	# than to the one free cell in the opposite corner.
	var wall: Array[ModuleData] = []
	for y in g.y:
		for x2 in g.x:
			if Vector2i(x2, y) == Vector2i(g.x - 1, g.y - 1):
				continue
			var f := _fitting()
			if f != null and Run.can_place(f, Vector2i(x2, y)):
				Run.place_in_hold(f, Vector2i(x2, y))
				wall.append(f)
	var far := grid.target_for(mover, onto)
	_ok("with nothing within reach, the drop is refused rather than teleported: %s"
		% far, far == -Vector2i.ONE)


## A 1x1 part, for filling cells with.
func _fitting() -> ModuleData:
	var m := LootGen.roll_module(3, &"", true)
	m.size = Vector2i.ONE
	m.turned = false
	return m


## Where a fitted part's mount is, in the hardpoint layer's own coordinates.
func _mount_local(mounts: MountPoints, m: ModuleData) -> Vector2:
	for sp in mounts.spots():
		if sp.held == m:
			return sp.at
	return Vector2.INF


## No layout assertion on purpose: four tried passed with the heavy hold blown up to 48 cells.
## A check that cannot fail is worse than none, as it reads as coverage.
## Why: docs/why/FitTest.md#hold-ladder
func _hold_ladder() -> void:
	var want := {HullData.Weight.LIGHT: 12, HullData.Weight.MEDIUM: 20,
		HullData.Weight.HEAVY: 30}
	for w in want:
		Run.start_new_run(&"korvan", int(w))
		var g := Run.hold_grid()
		_ok("%s hold is %dx%d = %d cells, wanted %d"
			% [HullData.weight_name(w), g.x, g.y, g.x * g.y, want[w]],
			g.x * g.y == want[w])


## Every module the hardpoints currently believe is bolted on.
func _held(mounts: MountPoints) -> Array[ModuleData]:
	var out: Array[ModuleData] = []
	for sp in mounts.spots():
		if sp.held != null:
			out.append(sp.held)
	return out


## Between grab and drop the part is in neither list, so an abandoned drag must put it back.
## Why: docs/why/FitTest.md#lifting
func _lifting(grid: HoldGrid, mounts: MountPoints) -> void:
	var screen := Router.current as ShipScreen
	var m: ModuleData = null
	for sp in mounts.spots():
		if sp.held != null:
			m = sp.held
			break
	if not _ok("something is on the hull to pick up", m != null):
		return
	var was := m.mount

	screen._on_lift(m)
	_ok("a part in hand is off the ship", not Run.installed.has(m))
	_ok("...and is in neither the ship nor the hold",
		not Run.installed.has(m) and not Run.cargo.has(m))
	_ok("...and its hardpoint is free again",
		Run.module_at(m.slot, was) == null)

	screen._on_release()
	_ok("let go over nothing, it goes back on the ship", Run.installed.has(m))
	_ok("...onto the same hardpoint it came off", m.mount == was)

	# A lifted part still trades with an occupied mount. `installed.has(m)` is false for that move.
	var other: ModuleData = null
	for sp in mounts.spots():
		if sp.held != null and sp.held != m and sp.held.slot == m.slot:
			other = sp.held
			break
	if other == null:
		return
	var theirs := other.mount
	screen._on_lift(m)
	screen._on_mount_drop({module = m, origin = &"hull"}, m.slot, theirs)
	_ok("two fitted parts trade hardpoints: %s to %d, %s to %d"
		% [m.name, m.mount, other.name, other.mount],
		m.mount == theirs and other.mount == was)
	_ok("...and neither of them ended up in the hold",
		Run.installed.has(m) and Run.installed.has(other)
		and not Run.cargo.has(m) and not Run.cargo.has(other))


## R turns a part in the hold, and a turn that will not fit costs nothing.
func _turning(grid: HoldGrid) -> void:
	# Emptied first: `_stripping` fills the hold and a turn needs room, or it looked like a bug.
	for x in Run.cargo.duplicate():
		Run.take_from_hold(x)
	var m := _long()
	if m == null:
		_fail("nothing long enough in the catalogue to turn")
		return
	await _settle(grid)
	var icon := _icon_for(grid, m)
	if not _ok("the long part has a plate", icon != null):
		return
	var before := m.footprint()
	var cells := m.cells()
	var faced := ModuleIcon.part_turn(m.slot, before)

	_turn(_centre(icon))
	_ok("R turns a %dx%d into a %dx%d" % [before.x, before.y, before.y, before.x],
		m.footprint() == Vector2i(before.y, before.x))
	_ok("turning does not change how much room it takes", m.cells() == cells)
	_ok("a turned part is still somewhere legal",
		m.hold_at.x >= 0 and Run.can_place(m, m.hold_at))
	# The hull part faces as the hold part is packed, or a turned lance fired the wrong way.
	_ok("the silhouette stands the other way up once turned",
		ModuleIcon.part_turn(m.slot, m.footprint()) != faced)
	_same_size(m)
	_no_overlap()

	await _settle(grid)
	var again := _icon_for(grid, m)
	if again != null:
		_turn(_centre(again))
		_ok("R again turns it back", m.footprint() == before)

	# And a turn with nowhere to go leaves the part exactly as it was.
	var packed := _pack_solid()
	await _settle(grid)
	if _ok("a hold packed solid around a long part", packed != null):
		var shape := packed.footprint()
		var where := packed.hold_at
		_turn(_plate_centre(grid, packed))
		_ok("a turn with no room for it changes nothing",
			packed.footprint() == shape and packed.hold_at == where)


## Plate inside a wrapper: a plate given straight to `set_drag_preview` would grip rigidly.
## The easing itself cannot be asserted, as pushed events do not move the cursor.
## Why: docs/why/FitTest.md#carried-plate
var _ghost_checked: bool = false

func _ghost_once() -> void:
	if _ghost_checked:
		return
	_ghost_checked = true
	var plate := ItemIcon.carried
	if not _ok("something is being carried", plate != null):
		return
	var wrap := plate.get_parent() as Control
	_ok("the carried plate sits inside a wrapper of its own", wrap != null
		and wrap.get_class() == "Control" and wrap != plate)
	_ok("what you are carrying is see-through",
		wrap != null and wrap.modulate.a < 1.0)


## Every slot and shape is checked: only weapons draw off-centre, and one random module missed it.
## Why: docs/why/FitTest.md#geometry
func _geometry() -> void:
	var shapes: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1),
		Vector2i(1, 3), Vector2i(3, 1), Vector2i(2, 2)]
	var slots: Array[ModuleData.Slot] = [ModuleData.Slot.WEAPON,
		ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]
	var out := ""
	for slot in slots:
		for f in shapes:
			var step := float(HoldGrid.CELL + HoldGrid.GAP)
			var box := Rect2(Vector2.ZERO,
				Vector2(f) * step - Vector2(HoldGrid.GAP, HoldGrid.GAP))
			var up := ModuleIcon.part_turn(slot, f)
			var sc := ModuleIcon.part_scale(slot, f, box.size)
			var o := ModuleIcon.part_origin(slot, box, sc, up)
			var off := ModuleIcon.part_offset(slot) * sc
			if up:
				off = Vector2(off.y, -off.x)
			var ext := ModuleIcon.part_rect(slot, box, sc, up).size
			var ink := Rect2(o + off - ext * 0.5, ext)
			# Uses WANT_PAD, not ModuleIcon.PAD: reading the code's own constant passed at zero.
			# (1 px of rounding slack, so the clearance checked is 3 px, as the label says)
			# Why: docs/why/FitTest.md#geometry
			if not box.grow(-WANT_PAD + 1.0).encloses(ink):
				out += " %s %dx%d" % [ModuleData.slot_name(slot), f.x, f.y]
	_ok("every silhouette clears its plate by %dpx" % int(WANT_PAD - 1.0)
		if out == "" else "art crowding the border:%s" % out, out == "")
	_anchors()


## The hardpoint layer is a child of the ship view, so its clip cut a gun's muzzle.
## Why: docs/why/FitTest.md#nothing-cut
func _nothing_cut(screen: Node) -> void:
	var view := first(screen, func(n: Node) -> bool: return n is ShipView) as ShipView
	if not _ok("the refit screen has a ship view", view != null):
		return
	_ok("the view does not clip what is bolted to the hull", not view.clip_contents)
	_ok("the view is showing the whole canvas, so it has nothing to clip",
		view.size.y >= view.canvas_height())

	# Zoomed too: at 1x clipping is off, so the check was blind to the clip until the zoom.
	# Why: docs/why/FitTest.md#nothing-cut
	var sc := screen as ShipScreen
	if sc == null:
		return
	sc._set_zoom(true)
	_ok("the view does not clip what is bolted to the hull WHEN ZOOMED",
		not view.clip_contents)
	sc._set_zoom(false)


## Stated as the rule, not the arithmetic: a copy of the formula passes against any formula.
func _anchors() -> void:
	var cell := float(HoldGrid.CELL)
	var wide := Vector2i(3, 1)
	var tall := Vector2i(1, 3)
	var box_w := ModuleIcon.footprint_box(_shaped(ModuleData.Slot.WEAPON, wide))
	var box_t := ModuleIcon.footprint_box(_shaped(ModuleData.Slot.WEAPON, tall))

	# A three-cell gun lying along the hull: mounted in its FIRST cell, well
	# short of its own middle, so the barrel runs forward of the hardpoint.
	var a := ModuleIcon.mount_anchor(ModuleData.Slot.WEAPON, box_w, false)
	_ok("a 3x1 gun mounts inside its leftmost cell",
		a.x > 0.0 and a.x < cell and a.x < box_w.x * 0.5)
	_ok("a 3x1 gun mounts halfway up itself",
		is_equal_approx(a.y, box_w.y * 0.5))

	# Stood on end the breech is at the bottom, as the drawing turns anticlockwise.
	var b := ModuleIcon.mount_anchor(ModuleData.Slot.WEAPON, box_t, true)
	_ok("a 1x3 gun stood on end mounts inside its bottom cell",
		b.y > box_t.y - cell and b.y < box_t.y and b.y > box_t.y * 0.5)

	# Everything else hangs off its middle, whatever shape it is.
	var off := ""
	for slot in [ModuleData.Slot.SYSTEM, ModuleData.Slot.UTILITY]:
		for f in [Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 3), Vector2i(2, 2)]:
			var box := ModuleIcon.footprint_box(_shaped(slot, f))
			for up in [false, true]:
				if not ModuleIcon.mount_anchor(slot, box, up).is_equal_approx(box * 0.5):
					off += " %s %dx%d" % [ModuleData.slot_name(slot), f.x, f.y]
	_ok("systems and utilities mount at their own centre" if off == ""
		else "mounted off-centre:%s" % off, off == "")


## A bare part of a given slot and shape, for asking geometry questions of.
func _shaped(slot: ModuleData.Slot, f: Vector2i) -> ModuleData:
	var m := ModuleData.new()
	m.slot = slot
	m.size = f
	m.turned = false
	return m


## The plate the hold draws is the part's own footprint, and the hull scales
## against the same box.
func _same_size(m: ModuleData) -> void:
	var box := ModuleIcon.footprint_box(m)
	var plate := _icon_for(_grid(), m)
	if not _ok("the turned part still has a plate", plate != null):
		return
	_ok("the plate in the hold is the part's own footprint", plate.size == box)
	# Scaled off the plate's own rect: comparing `part_scale` with itself cannot fail.
	_ok("the hold and the hull scale the part identically", is_equal_approx(
		ModuleIcon.part_scale(m.slot, m.footprint(), plate.size),
		ModuleIcon.part_scale(m.slot, m.footprint(), box)))


func _grid() -> HoldGrid:
	return first(Router.current, func(n: Node) -> bool: return n is HoldGrid) as HoldGrid


## Nothing shares a cell after a turn. The failure this is looking for does not
## throw and does not show up in a total: two parts overlapping still add up.
func _no_overlap() -> void:
	var seen := {}
	var clash := ""
	for x in Run.cargo:
		var f: Vector2i = x.footprint()
		for dy in f.y:
			for dx in f.x:
				var c: Vector2i = x.hold_at + Vector2i(dx, dy)
				if seen.has(c):
					clash = "%s over %s at %s" % [x.name, seen[c], c]
				seen[c] = x.name
	_ok("no two parts share a cell after turning" if clash == "" else clash,
		clash == "")


## A part that is not square, so turning it is visible.
func _long() -> ModuleData:
	for i in 60:
		var m := LootGen.roll_module(3 + (i % 5), &"", true)
		if m.size.x != m.size.y and Run.place_in_hold(m):
			Sig.ship_changed.emit()
			return m
	return null


## What R does, at a point of our choosing. See ShipScreen._turn_in_hold for
## why the point is passed rather than read off the cursor.
func _turn(at: Vector2) -> void:
	(Router.current as ShipScreen)._turn_in_hold(at)


## Built by hand: a rolled hold had room, the turn succeeded and the test failed on right code.
## Why: docs/why/FitTest.md#no-room-to-turn
func _pack_solid() -> ModuleData:
	for m in Run.cargo.duplicate():
		Run.take_from_hold(m)
	var long := LootGen.roll_module(3, &"", true)
	long.size = Vector2i(1, 3)
	long.turned = false
	if not Run.place_in_hold(long, Vector2i.ZERO):
		return null
	var g := Run.hold_grid()
	var guard := 0
	while Run.cargo_used() < g.x * g.y and guard < 200:
		guard += 1
		var fill := LootGen.roll_module(3, &"", true)
		fill.size = Vector2i.ONE
		fill.turned = false
		if not Run.place_in_hold(fill):
			break
	Sig.ship_changed.emit()
	return long


func _plate_centre(grid: HoldGrid, m: ModuleData) -> Vector2:
	var o := grid.get_global_rect().position
	var f := m.footprint()
	var step := float(HoldGrid.CELL + HoldGrid.GAP)
	return o + Vector2(m.hold_at) * step + Vector2(f) * step * 0.5


# ------------------------------------------------------------------- the mouse

## Pick-up is real, drop is not: Godot follows the OS cursor, and we will not warp the mouse.
## Why: docs/why/FitTest.md#carry-crossing
func _carry(from: Vector2, onto: Control, local: Vector2) -> bool:
	var vp := _tree.root
	await _move(from, 0)
	await _press(from, true)
	# Small and along the part: -24 put the pointer off the top of a one-cell gun.
	await _move(from + Vector2(10.0, -10.0), MOUSE_BUTTON_MASK_LEFT)
	var data: Variant = vp.gui_get_drag_data()
	var live := vp.gui_is_dragging() and typeof(data) == TYPE_DICTIONARY
	if live:
		_ghost_once()
	if live:
		if onto._can_drop_data(local, data):
			onto._drop_data(local, data)
	await _press(_at, false)
	# Waits for the drop to land: it is signal-driven, and a fixed wait failed one run in four.
	# Why: docs/why/FitTest.md#carry-crossing
	for i in 12:
		await _tree.process_frame
	return live


## Game space, unchanged: events go into the SubViewport, so no window conversion is needed.
func _win(p: Vector2) -> Vector2:
	return p


func _move(to: Vector2, mask: int) -> void:
	var e := InputEventMouseMotion.new()
	e.position = _win(to)
	e.global_position = e.position
	e.relative = _win(to) - _win(_at)
	e.velocity = Vector2.ZERO
	e.button_mask = mask
	_at = to
	GameShell.input_target(_tree).push_input(e)
	await _tree.process_frame


func _press(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = _win(at)
	e.global_position = e.position
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	_at = at
	GameShell.input_target(_tree).push_input(e)
	await _tree.process_frame


# -------------------------------------------------------------------- fixtures

## `powered` gives a part the reactor can run, as refit refuses any other (tutorial audit, Oct 22).
func _stow(slot: ModuleData.Slot, powered: bool = false) -> ModuleData:
	for i in 40:
		var m := LootGen.roll_module(3 + (i % 5), &"", true)
		if powered and not Run.can_power(m):
			continue
		if m.slot == slot and Run.place_in_hold(m):
			Sig.ship_changed.emit()
			return m
	return null


## Waits on the condition, not a frame count: a flaky check teaches people to re-run it.
## Why: docs/why/FitTest.md#waiting-on-conditions
func _became(cond: Callable, frames: int = 90) -> bool:
	for i in frames:
		if cond.call():
			return true
		await _tree.process_frame
	return bool(cond.call())


func _settle(grid: HoldGrid) -> void:
	grid.refresh()
	for i in 3:
		await _tree.process_frame


func _icon_for(grid: HoldGrid, m: ModuleData) -> Control:
	for c in grid.get_children():
		if c is ModuleIcon and (c as ModuleIcon).module == m:
			return c
	return null


func _centre(c: Control) -> Vector2:
	var r := c.get_global_rect()
	return r.position + r.size * 0.5


## Where a free mount of this kind sits, in screen coordinates, or INF.
func _free_mount(mounts: MountPoints, slot: ModuleData.Slot) -> Vector2:
	return _mount_where(mounts, func(s: Dictionary) -> bool:
		return s.slot == slot and s.held == null)


func _mount_of(mounts: MountPoints, m: ModuleData) -> Vector2:
	return _mount_where(mounts, func(s: Dictionary) -> bool: return s.held == m)


func _mount_where(mounts: MountPoints, want: Callable) -> Vector2:
	for s in mounts.spots():
		if want.call(s):
			return mounts.get_global_rect().position + (s.at as Vector2)
	return Vector2.INF


## Part size matters: a first-empty-cell drop of a 4-wide gun was correctly refused, looking random.
## Why: docs/why/FitTest.md#room-for-part
func _room_for(grid: HoldGrid, m: ModuleData) -> Vector2:
	var g := Run.hold_grid()
	var taken := {}
	for c in Run.cargo:
		if c.hold_at.x < 0:
			continue
		for dy in c.footprint().y:
			for dx in c.footprint().x:
				taken[c.hold_at + Vector2i(dx, dy)] = true
	var w := m.footprint().x
	var h := m.footprint().y
	for y in maxi(0, g.y - h + 1):
		for x in maxi(0, g.x - w + 1):
			var fits := true
			for dy in h:
				for dx in w:
					if taken.has(Vector2i(x + dx, y + dy)):
						fits = false
			if fits:
				var step := float(HoldGrid.CELL + HoldGrid.GAP)
				return (grid.get_global_rect().position
					+ Vector2((x + 0.5) * step, (y + 0.5) * step))
	return Vector2.INF

## The ship holds still at 1x: `_clamp_pan` allowed a slide that was never cleared.
## Events go straight to the handler, as a synthetic drag never moves the OS cursor.
## Why: docs/why/FitTest.md#pinned-ship
func _pinned(screen: Node) -> void:
	var sc := screen as ShipScreen
	if not _ok("the ship screen is still up to test panning", sc != null):
		return
	var mm := InputEventMouseMotion.new()
	mm.relative = Vector2(30.0, 0.0)
	mm.button_mask = MOUSE_BUTTON_MASK_LEFT

	sc._set_zoom(false)
	sc._panning = true
	sc._on_clip_input(mm)
	_ok("the ship cannot be panned at 1x", is_equal_approx(sc._pan.x, 0.0))

	sc._set_zoom(true)
	var was := sc._pan.x
	sc._panning = true
	sc._on_clip_input(mm)
	_ok("the ship can still be panned while zoomed",
		not is_equal_approx(sc._pan.x, was))

	# The press-started-here-released-elsewhere case, which is what left the
	# flag set with nothing held down.
	var up := InputEventMouseMotion.new()
	up.relative = Vector2(30.0, 0.0)
	up.button_mask = 0
	var held := sc._pan.x
	sc._panning = true
	sc._on_clip_input(up)
	_ok("a stuck pan flag with no button held moves nothing",
		is_equal_approx(sc._pan.x, held))
	sc._set_zoom(false)
