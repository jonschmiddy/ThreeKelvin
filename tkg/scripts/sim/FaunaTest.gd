extends Node

## THE CUSTODIAN'S AND THE MEGAFAUNA'S OWN MOVEMENT, LIVE (`FaunaMotion`,
## `EnemySlot._fauna_*`, the two hooks in `SectorScreen`), headless:
##   godot --headless --path . -- sheet=FaunaTest
## One: the cut, for each of the three, at full size and from a half sheet (the
## picture sampled the way `tools/enemy_sprites.py` makes them): it finds its
## parts and lights; idle moves something within six seconds; the wind-up
## (the Custodian's charge, a creature's strike) takes it further -- the charge
## lit full, the swell to its deepest; `settle()` is back at rest in four frames
## or fewer and then draws the very picture it was cut from.
## Two: the real fight, animated (`Router.animate_in_harness`), on each of the
## three: the slot's art hands its picture to the motion (its texture off, the
## motion a child of it) and takes its bob from the motion's steps; the
## Custodian's Charging intent winds it up and another intent lets go; a
## creature's attack, played through END TURN, strikes; a kill settles it
## before the breakup is cut (at rest on the frame the art is hidden), and the
## dead slot is the art's own wreck again, no motion left. With reduced motion
## there is no motion at all.
## No pixels are looked at here (headless draws nothing): the flicker and the
## hand-off to the pixel are `-- sheet=FaunaSheet`'s, in a window.

const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")
const IDS := ["custodian", "whale", "leviathan"]

var _tree: SceneTree
var _fails := 0


func _ok(what: String, c: bool) -> bool:
	print("  %s %s" % ["ok  " if c else "FAIL", what])
	if not c:
		_fails += 1
	return c


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_tree = get_tree()
	await _tree.process_frame
	print("faunatest: the cut")
	for id in IDS:
		for half in [false, true]:
			_cut_one(id, half)
	print("faunatest: the real fight")
	Router.animate_in_harness = true
	for id in IDS:
		await _fight(id)
	DisplaySettings.reduced_motion = true
	await _reduced()
	DisplaySettings.reduced_motion = false
	Router.animate_in_harness = false
	print("faunatest: %s (%d failed)" % ["PASS" if _fails == 0 else "FAIL", _fails])
	_tree.quit(1 if _fails > 0 else 0)


func _enemy(id: String) -> Combat.EnemyState:
	var e := Combat.EnemyState.new()
	e.template = DB.enemies[StringName(id)]
	e.max_hp = e.template.max_hull
	e.hp = e.max_hp
	e.look = 0
	return e


## The picture at half, the way the half sheets are made: the top-left pixel of
## every 2x2 block, centred on the canvas.
static func _halve(img: Image) -> Image:
	var r := img.get_used_rect()
	var w := (r.size.x + 1) / 2
	var h := (r.size.y + 1) / 2
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	var at := Vector2i((img.get_width() - w) / 2, (img.get_height() - h) / 2)
	for y in h:
		for x in w:
			out.set_pixel(at.x + x, at.y + y, img.get_pixel(r.position.x + x * 2, r.position.y + y * 2))
	return out


func _cut_one(id: String, half: bool) -> void:
	var e := _enemy(id)
	var img := FaunaMotion.still_canvas(e, e.hp, 1.0)
	if half:
		img = _halve(img)
	var fm := FaunaMotion.new()
	fm.auto = false
	var k := FaunaMotion.kind_of(StringName(id))
	fm.cut(img, k, 0.5 if half else 1.0, FaunaMotion.picture_name(e))
	add_child(fm)
	fm.attach()
	var tag := "%s%s" % [id, " (half)" if half else ""]
	var st := fm.state()
	_ok("%s: cut into %d parts and %d lights in %.0f ms" % [tag, st.parts, st.lights, fm.setup_ms],
		int(st.parts) >= (3 if k == FaunaMotion.Kind.CUSTODIAN else 20) and int(st.lights) > 0)
	var moved := 0
	for f in 180:
		fm.advance(1.0 / 30.0)
		var s2 := fm.state()
		moved = maxi(moved, int(s2.off) + int(s2.lit))
	_ok("%s: idle moves (up to %d parts and lights off rest)" % [tag, moved], moved > 0)
	if k == FaunaMotion.Kind.CUSTODIAN:
		fm.windup(true)
	else:
		fm.strike()
	var deep := 0
	var pool := 0.0
	var wind := 0.0
	for f in 30:
		fm.advance(1.0 / 30.0)
		var s3 := fm.state()
		deep = maxi(deep, int(s3.swell))
		pool = maxf(pool, float(s3.pool))
		wind = maxf(wind, float(s3.wind))
	if k == FaunaMotion.Kind.CUSTODIAN:
		_ok("%s: the charge winds it up (pool %.2f)" % [tag, pool], pool >= 1.0 and wind >= 1.0)
	else:
		_ok("%s: the strike winds it up (swell %d px)" % [tag, deep], wind > 0.5 and deep >= (2 if half else 3))
	fm.settle()
	var n := 0
	while not fm.rested and n < 10:
		fm.advance(1.0 / 30.0)
		n += 1
	var s4 := fm.state()
	_ok("%s: settles in %d frames (at most 4), every part and light at rest" % [tag, n],
		fm.rested and n <= 4 and int(s4.off) == 0 and int(s4.lit) == 0 and float(s4.pool) == 0.0)
	_ok("%s: at rest it draws the picture it was cut from" % tag,
		fm.rest_image().get_data() == img.get_data() and fm.material == null)
	fm.queue_free()


func _open(id: String) -> SectorScreen:
	Rng.forced = 4242
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Run.hand_size_override = 5
	for n: MapGen.MapNode in Run.map:
		if n.type != MapGen.NodeType.STATION and n.type != MapGen.NodeType.START \
				and String(SkyWeatherS.sky_of_node(n)) == "calm":
			Run.at = n.index
			break
	SectorScreen._approached_at = Run.at
	Router.start_combat(DB.enemies[StringName(id)], [], false, false)
	for i in 10:
		await _tree.process_frame
	return Router.current as SectorScreen


func _wait_s(s: float) -> void:
	var end := Time.get_ticks_msec() + int(s * 1000.0)
	while Time.get_ticks_msec() < end:
		await _tree.process_frame


func _fight(id: String) -> void:
	var sc := await _open(id)
	if not _ok("%s: the fight opens" % id, sc != null and sc._view != null and sc._view.slot(0) != null):
		return
	var slot: EnemySlot = sc._view.slot(0)
	var fm: FaunaMotion = null
	var end := Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < end:
		fm = slot.fauna_motion()
		if fm != null and fm.ready_to_draw:
			break
		await _tree.process_frame
	if not _ok("%s: the slot's art hands its picture to the motion" % id,
			fm != null and fm.get_parent() == slot.art and slot.art.texture == null):
		return
	var e0: Combat.EnemyState = Router.combat.enemies[0]
	_ok("%s: what it settles to is the art's own picture" % id,
		e0.intent == null or e0.intent.telegraph or
		FaunaMotion.still_canvas(e0, e0.hp, 1.0).get_data() == slot.art.snapshot().get_data())
	await _wait_s(0.6)
	_ok("%s: the bob is the motion's (%.0f px)" % [id, slot.art.position.y - slot._art_base.y],
		is_equal_approx(slot.art.position.y - slot._art_base.y, fm.bob_px()))
	var cb: Combat = Router.combat
	var e: Combat.EnemyState = cb.enemies[0]
	if id == "custodian":
		var tele: IntentData = null
		var other: IntentData = null
		for it in e.template.loop:
			if it.telegraph:
				tele = it
			elif other == null:
				other = it
		e.intent = tele
		Sig.enemy_changed.emit()
		await _wait_s(0.8)
		_ok("custodian: Charging winds it up (charge %.2f)" % float(fm.state().pool),
			fm._wind_on and float(fm.state().pool) >= 1.0)
		e.intent = other
		Sig.enemy_changed.emit()
		await _wait_s(0.8)
		_ok("custodian: another intent lets go (charge %.2f)" % float(fm.state().pool),
			not fm._wind_on and float(fm.state().pool) == 0.0)
	else:
		# its turn, through END TURN, until it has attacked
		var struck := false
		for turn in 4:
			if struck:
				break
			Run.hp = Run.max_hp()
			sc._on_end_turn()
			var t_end := Time.get_ticks_msec() + 4000
			while Time.get_ticks_msec() < t_end:
				if fm._strike_left > 0.0:
					struck = true
				if not sc._playing and not sc._hold and Time.get_ticks_msec() > t_end - 3000:
					break
				await _tree.process_frame
		_ok("%s: its attack, fired, strikes" % id, struck)
	# the kill
	await _settle_turn(sc)
	var rested_at_cut := false
	var cut_seen := false
	var tries := 0
	while not cb.finished and tries < 20:
		tries += 1
		Run.hp = Run.max_hp()
		e.hp = mini(e.hp, 1)
		e.block = 0
		for i in cb.hand.size():
			if cb.can_play(cb.hand[i]):
				cb.play(i, 0)
				break
		var t2 := Time.get_ticks_msec() + 1500
		while Time.get_ticks_msec() < t2:
			if not cut_seen and slot.art.self_modulate.a <= 0.0:
				cut_seen = true
				rested_at_cut = fm == null or not is_instance_valid(fm) or fm.rested
			if e.hp <= 0 and cut_seen:
				break
			await _tree.process_frame
		if e.hp <= 0:
			break
		if not cb.finished:
			sc._on_end_turn()
			await _settle_turn(sc)
	_ok("%s: killed (%s, %d tries)" % [id, cb.result, tries], e.hp <= 0)
	_ok("%s: at rest on the frame the breakup is cut" % id, cut_seen and rested_at_cut)
	await _wait_s(2.5)
	_ok("%s: the dead slot is the art's own wreck again" % id,
		slot.fauna_motion() == null and slot.art.texture != null)


func _settle_turn(sc: SectorScreen) -> void:
	var t := Time.get_ticks_msec() + 6000
	while Time.get_ticks_msec() < t and (sc._playing or sc._hold):
		await _tree.process_frame


func _reduced() -> void:
	var sc := await _open("whale")
	await _wait_s(0.5)
	var slot: EnemySlot = sc._view.slot(0) if sc != null and sc._view != null else null
	_ok("reduced motion: no motion, the art draws its own picture",
		slot != null and slot.fauna_motion() == null and slot.art.texture != null)
