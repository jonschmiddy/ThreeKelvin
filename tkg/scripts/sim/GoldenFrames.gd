extends Node

## On demand, never gated: a few frames of drawing code, captured before and after a refactor into two
## temp folders for `tools/dev/golden_diff.py`. Windowed, `--fixed-fps 60`: `-- sheet=GoldenFrames out=<dir> [only=<group>,...]`.
## Why: docs/why/GoldenFrames.md#golden-frames

const DeathStylesS := preload("res://scripts/sim/DeathStyles.gd")
const BossDeathSheetS := preload("res://scripts/sim/BossDeathSheet.gd")
const HullDamageFilmS := preload("res://scripts/sim/HullDamageFilm.gd")

const SEED := 4242
const STEP := 1.0 / 30.0
const GROUPS: Array[String] = ["breakup", "hitfx", "planets", "boards", "station"]
const LCD_CLOCK := "the marketplace's header, side column and ticker read PostingBoard._t(), the wall clock"
const SHUFFLE := "FaunaBrace._flake shuffles with the global generator"
## Frames known to vary between runs of the same code: "group/name" to why. They are written under
## `_varies/` and the diff skips them; `-- sheet=GoldenFrames` prints each.
const VARIES := {
	"boards/lcd_dev3_live": LCD_CLOCK,
	"hitfx/fauna_brace_hit": SHUFFLE,
	"hitfx/fauna_hit0": SHUFFLE + ", and this frame has the brace up",
}
## Left out as not repeatable: the sector screen (its sky and system map seed from the wall clock) and
## the station's SERVICES deck (the yard's flames).

var _out := ""
var _gv: Viewport
var _layer: CanvasLayer
var _counts := {}
var _varied: Array[String] = []
var _ds: Node
var _bs: Node


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	_out = Harness.arg("out")
	if _out == "":
		push_error("GoldenFrames: out=<dir> is required")
		tree.quit(1)
		return
	var only := Harness.arg("only")
	var want: PackedStringArray = only.split(",", false) if only != "" else PackedStringArray(GROUPS)
	for g in want:
		if not g in GROUPS:
			push_error("GoldenFrames: no group '%s' (%s)" % [g, ", ".join(GROUPS)])
			tree.quit(1)
			return
	Harness.new().seed_run(SEED)
	DirAccess.make_dir_recursive_absolute(_out)
	_gv = GameShell.input_target(tree)
	_layer = CanvasLayer.new()
	_layer.layer = 120
	_gv.add_child(_layer)
	_ds = DeathStylesS.new()
	_bs = BossDeathSheetS.new()
	for g in GROUPS:
		if g in want:
			_counts[g] = 0
			await call("_" + g)
			print("goldenframes: %-8s %d frames" % [g, _counts[g]])
	for v in _varied:
		print("goldenframes: VARIES %s: %s" % [v, VARIES[v]])
	_ds.free()
	_bs.free()
	tree.quit()


# ---------------------------------------------------------------- shared

## The game's picture after `n` drawn frames.
func _shot(n := 2) -> Image:
	for i in n:
		await RenderingServer.frame_post_draw
	return _gv.get_texture().get_image()


## Writes `img` as `<group>/<name>.png`, or under `_varies/` when the name is listed as varying.
func _save(group: String, name: String, img: Image) -> void:
	var key := "%s/%s" % [group, name]
	var dir := _out.path_join("_varies" if VARIES.has(key) else "").path_join(group)
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir.path_join(name + ".png"))
	_counts[group] += 1
	if VARIES.has(key):
		_varied.append(key)


## The whole picture, or `rect` of it, as one frame.
func _snap(group: String, name: String, n := 2, rect := Rect2i()) -> void:
	var img: Image = await _shot(n)
	_save(group, name, img.get_region(rect) if rect.size != Vector2i.ZERO else img)


## A dark stage the group draws on, in front of the game's own screen.
func _stage() -> Control:
	var s := ColorRect.new()
	s.color = Color("#070a10")
	s.size = Vector2(960, 540)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_layer.add_child(s)
	return s


## A ship's picture on `stage`, `k` times its size with its top left at `at`.
func _pic(stage: Control, img: Image, at: Vector2, k := 1.0) -> Control:
	var host := Control.new()
	host.position = at
	host.scale = Vector2(k, k)
	host.size = Vector2(img.get_size())
	var tr := TextureRect.new()
	tr.texture = ImageTexture.create_from_image(img)
	tr.size = host.size
	host.add_child(tr)
	stage.add_child(host)
	return host


## Steps a hand-driven effect `n` times a thirtieth of a second.
func _run_for(fx: Object, n: int) -> void:
	for i in n:
		fx.advance(STEP)


# ---------------------------------------------------------------- breakup

## Seven death styles, four moments each, from whole to wreck.
func _breakup() -> void:
	var ship: Array = _ds._ship_image("cutter")
	var beast: Array = _ds._creature_image("lev_spine", 1.0)
	var cust: Array = _bs._boss_image("res://art/sprites/enemies/custodian_t1_grown.png")
	var hell: Array = _bs._boss_image("res://art/sprites/enemies/hellbender_helix.png")
	for st in [ShipBreakup.Style.SNAP, ShipBreakup.Style.BURN, ShipBreakup.Style.IMPLODE, ShipBreakup.Style.DISSOLVE,
			ShipBreakup.Style.GLOWOUT, ShipBreakup.Style.CUST_CASCADE, ShipBreakup.Style.HELL_CHAIN]:
		var pic: Array = ship
		if st == ShipBreakup.Style.GLOWOUT:
			pic = beast
		elif st >= ShipBreakup.Style.CUST_CASCADE:
			pic = cust if _bs._custodian(st) else hell
		var stage := _stage()
		var b := ShipBreakup.new()
		b.size = Vector2(960, 540)
		b.auto = false
		var img: Image = pic[0]
		b.setup(img, pic[1], Vector2(480, 270) - Vector2(img.get_size()) * 0.5, st, SEED, false)
		stage.add_child(b)
		var steps := 0
		for k in 4:
			var want := int(round(float(k) / 3.0 * b.duration / STEP)) + (0 if k < 3 else 12)
			while steps < want:
				b.advance(STEP)
				steps += 1
			await _snap("breakup", "%s_%d" % [DeathStylesS.style_id(st), k])
		stage.queue_free()
		await get_tree().process_frame


# ---------------------------------------------------------------- hitfx

## Hull marks (three looks) and the brace on one ship, then a leviathan's wounds and brace.
func _hitfx() -> void:
	var pic: Array = _ds._ship_image("cutter")
	var img: Image = pic[0]
	for look in [0, 2, 4]:
		ShipHitFx.look = look
		var h: ShipHitFx
		if look > 0:
			var hh := HullHitFx.new()
			hh.style = look
			h = hh
		else:
			h = ShipHitFx.new()
		h.auto = false
		var stage := _stage()
		var host := _pic(stage, img, Vector2(300, 100), 2.0)
		h.size = host.size
		h.setup(img, pic[1], Vector2.ZERO, SEED, -1)
		host.add_child(h)
		var hp := 100
		var shots := HullDamageFilmS.SHOTS
		for i in shots.size():
			hp -= shots[i]
			h.hit(shots[i], hp, 100)
			_run_for(h, 6)
			if i in [2, 8]:
				await _snap("hitfx", "hull%d_%d" % [look, i])
			_run_for(h, 27)
		stage.queue_free()
		await get_tree().process_frame
	ShipHitFx.look = 0
	var brace := BraceFx.new()
	brace.auto = false
	var bstage := _stage()
	var bhost := _pic(bstage, img, Vector2(300, 100), 2.0)
	brace.size = bhost.size
	brace.setup(img, pic[1], Vector2.ZERO, SEED, -1)
	bhost.add_child(brace)
	brace.gain(12)
	_run_for(brace, 30)
	await _snap("hitfx", "brace_held")
	brace.absorb(6)
	_run_for(brace, 10)
	await _snap("hitfx", "brace_hit")
	bstage.queue_free()
	await get_tree().process_frame
	await _fauna_fx()


## A leviathan's guard: `HitLayers` builds the creature's brace and wounds from its picture.
func _fauna_fx() -> void:
	var pic: Array = _ds._ship_image("leviathan")
	var img: Image = pic[0]
	for kind in 2:
		FaunaHitFx.force_kind = kind
		var layers := HitLayers.new()
		layers.kind = FaunaMotion.Kind.LEVIATHAN
		layers.size = Vector2(img.get_size())
		layers.setup(img, pic[1], SEED, -1, 100, 1.0, false)
		layers.hits.auto = false
		layers.brace.auto = false
		var stage := _stage()
		_pic(stage, img, Vector2(240, 60)).add_child(layers)
		if kind == 0:
			layers.brace.gain(12)
			_run_for(layers.brace, 8)
			layers.brace.absorb(5)
			_run_for(layers.brace, 4)
			await _snap("hitfx", "fauna_brace_hit")
		var hp := 100
		for i in 3:
			hp -= 14
			layers.hits.hit(14, hp, 100)
			_run_for(layers.hits, 12)
		await _snap("hitfx", "fauna_hit%d" % kind)
		stage.queue_free()
		await get_tree().process_frame
	FaunaHitFx.force_kind = -1


# ---------------------------------------------------------------- planets

## Eight worlds, among them the shattered one, laid out as the planet sheet lays them.
func _planets() -> void:
	var stage := _stage()
	var kinds: Array[StringName] = [&"rock", &"desert", &"ice", &"lava", &"ocean", &"banded", &"shattered", &"city"]
	for i in kinds.size():
		var w := kinds[i]
		var giant: bool = Worlds.WORLD[w].get("giant", false)
		var pv := Worlds.view_for(w)
		pv.position = Vector2(48 + i * 96, 40)
		stage.add_child(pv)
		pv.call("set_world", w, (Worlds.WORLD_ORDER.find(w) + 1) * 3 + 11, 20.0 if giant else 24.0, {})
		pv.call("step", 3.0, Vector3(-0.83, -0.31, 0.47))
	var img: Image = await _shot(4)
	for i in kinds.size():
		_save("planets", "%s_t3" % kinds[i], img.get_region(Rect2i(i * 96, 0, 96, 76)))
	stage.queue_free()
	await get_tree().process_frame


# ---------------------------------------------------------------- boards

## The cork, white and LCD boards: the first page of each pool, and the cork and white boards live.
## The lamp is hidden: its dust and flicker run on the wall clock.
func _boards() -> void:
	for level in [0, 2, 3]:
		var scr: StationScreen = await _dock(level)
		scr._show_tab(&"work")
		for c in scr._work.get_children():
			(c as CanvasItem).visible = false
		scr._board_lamp.visible = false
		await Harness.frames(get_tree(), 3)
		var bd := scr._board
		var box := Rect2i(bd.get_global_rect())
		var kind: String = PostingBoard.KINDS[level]["kind"]
		await _snap("boards", "%s_dev%d_live" % [kind, level], 4, box)
		bd.gallery_from = 0
		bd.queue_redraw()
		await _snap("boards", "%s_dev%d_pool01" % [kind, level], 3, box)


# ---------------------------------------------------------------- station

## The shelf, hold, fabricator and hiring-board decks of a settlement, the rail's lift car parked: its
## lit floor plays a picture on the wall clock.
func _station() -> void:
	for deck in [&"stock", &"hold", &"bench", &"work"]:
		var scr: StationScreen = await _dock(MapGen.Development.SETTLEMENT)
		scr._show_tab(deck)
		await Harness.frames(get_tree(), 40)
		scr._spine.car = -1.0
		if deck == &"work":
			scr._board_lamp.visible = false
		await _snap("station", str(deck), 10)


## A station of `level` with a ship docked, its shelf stocked by the screen's own rule.
func _dock(level: int) -> StationScreen:
	ShopScene.steady = true
	ShopScene.no_motes = true
	ShopScene.pin_clock_ms = 6000.0
	LabScene.pin_clock = 6.0
	YardScene.pin_clock = 6.0
	Rng.forced = SEED
	Run.start_new_run(&"solari", 1)
	var here: MapGen.MapNode = Run.node_at()
	here.type = MapGen.NodeType.STATION
	here.development = level
	here.security = 4
	Router.park_at_station(here)
	here.berths.clear()
	here.berths.append(&"solari")
	here.manufacturer = &"solari"
	here.danger = 5
	for i in 3:
		Run.stow(LootGen.roll_module(4 + i, &"", true))
	Run.hp = maxi(1, Run.max_hp() - 12)
	Run.add_dross(3)
	Run.add_credits(900)
	Router.show_station()
	await Harness.frames(get_tree(), 2)
	return Router.current as StationScreen
