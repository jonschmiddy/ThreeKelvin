extends Harness

## Parts can actually be picked up and put down:
##   godot --path . -- fittest
##
## NEEDS A WINDOW. This drives Godot's own drag-and-drop state machine with real
## input events, and that machine lives in Viewport — headless there is no gui
## input to hand it, so the whole thing would pass by never running.
##
## Written because every other test of the hold checks the DATA. `-- holdtest`
## proves two parts never share a cell and `-- mounts` proves a hardpoint sits on
## the hull, and both of them pass in full on a screen where nothing can be
## picked up at all. The refit screen is the one place in the game whose entire
## job is an interaction, and it was the one place with no test of one.
##
## Four crossings, because the hold and the hull are two containers and a part
## has to survive every trip between them: hold to hull, hull to hold, hull to
## hull, and a refusal — a part dropped on a mount of the wrong kind must not
## move, and must not vanish on the way.

## How much clear space a part's art must leave inside its own cell. Stated
## here rather than read off `ModuleIcon.PAD`, which is the thing being checked.
const WANT_PAD := 4.0

var _tree: SceneTree
var _at: Vector2 = Vector2.ZERO


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame

	Rng.reseed(7711, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_ship()
	for i in 4:
		await tree.process_frame

	var screen := Router.current
	if not _ok("the refit screen is up", screen is ShipScreen):
		verdict("fittest")
		_tree.quit()
		return
	var grid := first(screen, func(n: Node) -> bool: return n is HoldGrid) as HoldGrid
	var mounts := first(screen, func(n: Node) -> bool: return n is MountPoints) as MountPoints
	if not _ok("the hold and the hardpoints are both on it",
			grid != null and mounts != null):
		verdict("fittest")
		_tree.quit()
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
	verdict("fittest")
	# AND IT ENDS ITSELF. Every other harness is dispatched with a
	# `get_tree().quit()` on the line after it; this one runs ACROSS
	# frames, so Main returns immediately and there is nobody left to
	# end it. It has therefore always printed its verdict and then sat
	# there until something killed it -- which read as "still running
	# after 240s" the moment it went into the gate, on a run where
	# every one of its checks had passed.
	_tree.quit()


# ---------------------------------------------------------------- the crossings

## Hold to hull: pick a part out of the grid and bolt it to a free mount.
func _to_hull(grid: HoldGrid, mounts: MountPoints) -> void:
	var m := _stow(ModuleData.Slot.WEAPON)
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


## Hull to hold. THE HALF THAT DID NOT EXIST: `_on_hold_drop` has always handled
## a part arriving off the ship, and nothing could ever start that drag, so the
## branch was unreachable and looked written.
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


## A part dropped on a mount that will not take it stays exactly where it was.
## The interesting failure is not the refusal, it is a part that is refused
## AFTER being lifted and belongs to neither container afterwards.
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


## TAKING ONE PART OFF DOES NOT TAKE THE OTHERS WITH IT.
##
## Reported from the game: pull a module off the hull and the rest of them
## vanish. Nothing throws, the hold is right, the tally is right — the hull just
## comes back bare, which makes it a drawing fault or a lookup one and the two
## look identical from the outside.
func _stripping(grid: HoldGrid, mounts: MountPoints) -> void:
	# Two weapons on the hull, fitted through the real drop handler.
	for i in 2:
		var w := _stow(ModuleData.Slot.WEAPON)
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


## PICKING SOMETHING UP DOES NOT BLANK THE SHIP.
##
## Counted off what the draw loop DID, not off the data and not off the frame.
## The data was never wrong — `spots()` reported every fitted part the whole
## time the hull was coming back bare — and a rendered-pixel version of this
## check was written first and thrown away: it read the last presented frame and
## returned identical counts either side of a real visual change, so it passed
## against the very bug it was written for. Twice.
func _lit_keeps_the_parts(mounts: MountPoints, m: ModuleData) -> void:
	mounts.light(null)
	mounts.queue_redraw()
	await _tree.process_frame
	var quiet := mounts.drawn

	mounts.light(m)
	mounts.queue_redraw()
	await _tree.process_frame
	var lit := mounts.drawn
	var pings := mounts.pinged

	mounts.light(null)
	await _tree.process_frame
	_ok("the hull draws its parts with nothing in hand: %d" % quiet, quiet > 0)
	_ok("a part in hand does not blank the hull: %d drawn against %d"
		% [lit, quiet], lit == quiet)

	# AND ONLY THE EMPTY MOUNTS PING. Drawn over an installed part the rings
	# swamped the thing they were pointing at — 27px of them over a gun 30px
	# tall — which is most of why a whole slot looked like it had emptied.
	var free := 0
	for sp in mounts.spots():
		if sp.held == null and sp.slot == m.slot:
			free += 1
	_ok("only empty hardpoints ping: %d pings for %d free mounts of that kind"
		% [pings, free], pings == free)

	# AND A PART IS GRABBED ANYWHERE ON ITSELF, not just at the dot it hangs
	# from. A three-cell rail used to be pickable only by its breech.
	# THE LIVE MAGNIFICATION, not a hardcoded 2. The refit screen draws at 1x
	# unless the zoom is on, so asking for the rect at 2x measured a part twice
	# the size of the one on screen and probed a corner well outside it. The
	# assertion then failed for a part that was perfectly grabbable, which is
	# the exact breakage ShipView warns about: harmless while every screen
	# magnified by 2, silent the moment one stopped.
	var r := mounts.part_rect(m, m.slot, _mount_local(mounts, m), mounts._mag())
	var far := r.position + r.size - Vector2(2, 2)
	_ok("a fitted part can be grabbed at its far corner", mounts.spot_at(far) >= 0)
	_ok("...and the far corner finds THAT part",
		mounts.spot_at(far) >= 0
		and mounts.spots()[mounts.spot_at(far)].held == m)


## A REFUSED DROP LANDS NEXT DOOR, OR NOWHERE. Never across the hold.
##
## The old fallback was `Run.find_hold_slot` — first fit from the top-left — so
## a part nudged one cell left that clipped a neighbour reappeared in the far
## corner. Packing is a game of small adjustments and that made every imprecise
## one destructive.
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


## THE HOLD LADDER IS 12, 20, 30.
##
## Small, and it earns its place: the three sizes are one table entry each and
## the medium's and the heavy's were transposed the first time they were written,
## which nothing else would have caught — a hold of the wrong size still packs,
## still saves and still totals correctly.
##
## THERE IS NO LAYOUT ASSERTION HERE, and that is deliberate rather than an
## omission. The heavy's six rows come within 16px of the manufacturer abilities
## and it would be worth a guard, but four versions of one were written and every
## one of them passed with the heavy hold blown up to 48 cells. A column pushes
## rather than overlaps, so a clearance check between the grid and the block
## below sees nothing wrong; and re-running `start_new_run` inside this harness
## does not re-lay-out a screen that is already built, so measuring per weight
## measures the same frame three times. A check that cannot fail is worse than no
## check, because it is read as coverage. If this needs guarding, it wants a
## screen rebuilt per hull, which is a bigger harness than this one.
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


## GRABBING A PART TAKES IT OFF THE SHIP, and letting go of it nowhere puts it
## back.
##
## The second half is the one worth writing: between the grab and the drop the
## part is in neither `installed` nor `cargo`, so a drag abandoned over empty
## space is a module deleted. Picking a thing up is not a decision to get rid
## of it.
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

	# And a lifted part still TRADES with an occupied mount rather than pushing
	# the resident into the hold. `installed.has(m)` is false for exactly this
	# move, which is what made it the easy one to get wrong.
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
	# Emptied first. `_stripping` runs before this and fills the hold on its way
	# through, and a turn needs somewhere to turn INTO — inherited, this failed
	# for lack of room and read as a rotation bug.
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
	# The part on the HULL faces the way the part in the hold is packed. Without
	# this a turned lance was three cells long lying down and still drawn firing
	# across its own short axis.
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


## WHAT YOU CARRY IS A PLATE INSIDE A WRAPPER, and it is see-through.
##
## Checked once, on the first drag of the run. The wrapper is the thing Godot
## pins to the pointer; the plate inside it is what eases toward the cursor, and
## a plate handed straight to `set_drag_preview` would be gripped rigidly at
## whatever corner it was picked up by. So "the carried plate has a parent that
## is not the drag layer" is the whole mechanism, stated.
##
## The EASING itself is not asserted here and cannot be: it is driven by the
## real cursor, which pushed input events do not move. See `_carry`.
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


## A part is drawn at ONE size, in the hold and on the hull, and its ink stays
## inside its own plate.
##
## EVERY SLOT AND EVERY SHAPE, not whichever part the loot roll happened to hand
## over. Only a weapon has a silhouette that is off-centre from the point it is
## drawn at — it is drawn from its breech — so a version of this that checked one
## random module passed with the offset set to a deliberately wrong number three
## times out of four. The shapes are cheap and there are six of them.
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
			# WANT_PAD, not ModuleIcon.PAD. Reading the constant under test is
			# how the first version of this passed with the padding set to
			# zero: the assertion relaxed by exactly as much as the code did.
			# A test states the requirement; it does not ask the code what the
			# requirement is.
			if not box.grow(-WANT_PAD + 1.0).encloses(ink):
				out += " %s %dx%d" % [ModuleData.slot_name(slot), f.x, f.y]
	_ok("every silhouette clears its plate by %dpx" % int(WANT_PAD)
		if out == "" else "art crowding the border:%s" % out, out == "")
	_anchors()


## NOTHING BOLTED TO THE HULL IS CUT OFF BY THE VIEW IT IS DRAWN IN.
##
## The hardpoint layer is a CHILD of the ship view, so the view's clip applies
## to it — and a gun mounted on the last hardpoint on the spine reaches past the
## hull it is mounted on, which is the whole point of a barrel. It was losing
## its muzzle to a rectangle that had nothing else to cut: the view is sized to
## show the entire canvas here, so the clip could only ever remove a child.
func _nothing_cut(screen: Node) -> void:
	var view := first(screen, func(n: Node) -> bool: return n is ShipView) as ShipView
	if not _ok("the refit screen has a ship view", view != null):
		return
	_ok("the view does not clip what is bolted to the hull", not view.clip_contents)
	_ok("the view is showing the whole canvas, so it has nothing to clip",
		view.size.y >= view.canvas_height())

	# AND ZOOMED, which is the case this check was blind to for as long as it
	# has existed. At 1x the row is taller than the canvas so `magnify` leaves
	# clipping off and the assertion above passes for free. The zoom doubles the
	# canvas past the row, `magnify` turns clipping back on, and every gun that
	# reaches past its hull loses its muzzle — the exact thing this test names,
	# in the one state it never entered.
	var sc := screen as ShipScreen
	if sc == null:
		return
	sc._set_zoom(true)
	_ok("the view does not clip what is bolted to the hull WHEN ZOOMED",
		not view.clip_contents)
	sc._set_zoom(false)


## THE HARDPOINT SITS AT THE RIGHT POINT INSIDE THE PART.
##
## Written as the rule rather than as a copy of the arithmetic: a gun hangs off
## its breech and everything else hangs off its middle. Restating the formula
## here would pass against any formula, including the centred one this replaced.
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

	# Stood on end the breech is at the BOTTOM, because the drawing turns
	# anticlockwise. Mounted anywhere else, turning a rail in the hold would
	# fire it through its own hardpoint.
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
	_ok("the plate in the hold is the part's own footprint",
		plate == null or plate.size == box)
	# Scaled off the plate's OWN rect against the box the hull uses. Comparing
	# part_scale with itself would have been the shape of a test and none of the
	# substance — it cannot fail, whatever the hold does.
	_ok("the hold and the hull scale the part identically",
		plate == null or is_equal_approx(
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


## A hold with EXACTLY no room to turn in, built rather than hoped for.
##
## A 1x3 down the first column and every other cell filled with fittings. Turned
## it wants three cells in a ROW and the only three free are the ones it just
## vacated, in a column — so the move has to be refused, and refused is the
## branch worth testing: the part is out of the hold at that moment and has to
## get back exactly where it was.
##
## Built by hand because the first version of this filled the hold with whatever
## the loot table rolled and then asserted a refusal. There was room, the turn
## succeeded, and the test failed while the code was right.
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

## One crossing: pick up at `from` on the screen, put down at `local` on
## `onto`. Returns whether a drag actually started.
##
## THE PICK-UP IS REAL AND THE DROP IS NOT, and the split is deliberate rather
## than lazy. Real events start a genuine drag — `gui_is_dragging()` goes true
## and the payload comes back through `_get_drag_data` — but Godot then follows
## the OS CURSOR for the rest of it, so pushed motion does not steer the hover.
## Driving the rest would mean warping the physical mouse on whatever machine is
## running the gate, which is a real side effect to inflict for a test.
##
## So the engine's routing is out of scope here and everything of ours is in it:
## that a plate hands over a payload, that a target accepts or refuses it, and
## that the run's state afterwards is right.
func _carry(from: Vector2, onto: Control, local: Vector2) -> bool:
	var vp := _tree.root
	await _move(from, 0)
	await _press(from, true)
	# Small, and along the part rather than off it. An installed module is
	# grabbed anywhere on its own rectangle now, so a nudge that used only to
	# have to stay inside a 22px radius has to stay inside the PART — and -24
	# put the pointer off the top of a one-cell gun before the drag began.
	await _move(from + Vector2(10.0, -10.0), MOUSE_BUTTON_MASK_LEFT)
	var data: Variant = vp.gui_get_drag_data()
	var live := vp.gui_is_dragging() and typeof(data) == TYPE_DICTIONARY
	if live:
		_ghost_once()
	if live:
		if onto._can_drop_data(local, data):
			onto._drop_data(local, data)
	await _press(_at, false)
	# LET THE DROP LAND. One frame is not enough and it is not a fixed number
	# of frames either: a drop is handled through signals and deferred calls,
	# so a caller that asserts on the frame the drag ended is reading the
	# state from BEFORE the part arrived. It only bites sometimes, which is
	# worse than always -- this test failed about one run in four, on an
	# assertion about a part that had moved perfectly well.
	#
	# Every caller asserts something about `Run` right after this returns, so
	# the wait belongs here rather than repeated at each of them.
	for i in 12:
		await _tree.process_frame
	return live


func _win(p: Vector2) -> Vector2:
	return _tree.root.get_final_transform() * p


func _move(to: Vector2, mask: int) -> void:
	var e := InputEventMouseMotion.new()
	e.position = _win(to)
	e.global_position = e.position
	e.relative = _win(to) - _win(_at)
	e.velocity = Vector2.ZERO
	e.button_mask = mask
	_at = to
	_tree.root.push_input(e)
	await _tree.process_frame


func _press(at: Vector2, down: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.position = _win(at)
	e.global_position = e.position
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	_at = at
	_tree.root.push_input(e)
	await _tree.process_frame


# -------------------------------------------------------------------- fixtures

## Put a part of `slot` in the hold and hand it back.
func _stow(slot: ModuleData.Slot) -> ModuleData:
	for i in 40:
		var m := LootGen.roll_module(3 + (i % 5), &"", true)
		if m.slot == slot and Run.place_in_hold(m):
			Sig.ship_changed.emit()
			return m
	return null


## Wait until `cond` holds, or give up. Returns whether it ever did.
##
## THE CONDITION, NOT A COUNT OF FRAMES. A drop is handled through signals and
## deferred calls, so how many frames it takes to land is not a number anybody
## knows -- it is however long the engine feels like taking on the day. This
## test asserted on a fixed count and failed about one run in four, always on
## an assertion about a part that had moved perfectly well.
##
## A flaky check in a gate is worse than no check at all: it teaches everybody
## to re-run until it is green, which is the same as not having it.
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


## The middle of a cell where `m` would actually FIT, or INF if it would not.
##
## THE PART'S SIZE IS THE POINT, and leaving it out is what made this test
## flaky. It used to return the first cell nothing was sitting in, which is a
## fine answer for a one-cell part and a wrong one for a Widowmaker: four cells
## wide in a five-wide hold, dropped on a cell with no four free columns after
## it, is a drop the hold correctly REFUSES -- so the part went back on the
## hull and the assertion "the part that was dragged off is off" failed.
##
## It looked random because it depended on whether the four-cell gun happened
## to come first in mount order, which is why chasing it as a timing problem
## got nowhere: a bounded wait on the fact did not help, because the fact was
## never going to become true.
func _room_for(grid: HoldGrid, m: ModuleData) -> Vector2:
	var g := Run.hold_grid()
	var taken := {}
	for c in Run.cargo:
		if c.hold_at.x < 0:
			continue
		for dy in maxi(1, c.size.y):
			for dx in maxi(1, c.size.x):
				taken[c.hold_at + Vector2i(dx, dy)] = true
	var w := maxi(1, m.size.x)
	var h := maxi(1, m.size.y)
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

## THE SHIP HOLDS STILL AT 1x, and still pans when zoomed.
##
## `_on_clip_input` documented itself as panning "only while zoomed" and then
## never checked, which is the whole bug: at 1x `_ship_x` centres the ship and
## there is nothing off screen to reach for, but `_clamp_pan` still allows it as
## far as +85 -- so a press on the hull and a few pixels of motion slid the ship
## off centre and LEFT it there, through every later refresh, because nothing
## zeroes `_pan` except turning the zoom off.
##
## It was reported as the ship moving when a part was moved in the HOLD. The
## hold was innocent: `_panning` was still set from an earlier press whose
## release landed outside the hull window and so never arrived to clear it.
##
## Events go STRAIGHT to the handler rather than through the input system, for
## the reason `_turn_in_hold` takes its position as an argument: a synthetic
## drag never moves the OS cursor, so a pushed event is swallowed on the way.
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
