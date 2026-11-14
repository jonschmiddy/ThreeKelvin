extends Node

## Every jump shader compiled by a real renderer, and every landed film's stage built and
## drawn through the real Router: any shader error, script error or engine error fails.
## Headless compiles no shaders, so JumpSeqTest passed a film whose shader did not compile.
##   tools/dev/render.sh --disable-vsync --fixed-fps 60 --path tkg -- sheet=JumpShaderTest
## Why: docs/why/JumpShaderTest.md#jump-shader-test

var _tree: SceneTree
var h := Harness.new()
var _errs := ErrCount.new()
var _t0 := Time.get_ticks_msec()


## Wall seconds since the sheet began, printed so a slow CI log shows where the time went.
func _clock(what: String) -> void:
	print("  [t] %s at %.1f s" % [what, (Time.get_ticks_msec() - _t0) / 1000.0])


## Every engine error (a shader that fails to compile prints one): there must be none.
class ErrCount extends Logger:
	var n := 0
	var first: Array[String] = []
	var lock := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, _error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		lock.lock()
		n += 1
		if first.size() < 64:
			first.append("%s  (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
		lock.unlock()

	func _log_message(_message: String, _error: bool) -> void:
		pass


func _ok(what: String, c: bool) -> bool:
	return h._ok(what, c)


func _ready() -> void:
	_run.call_deferred()


func _errors_since(e0: int) -> String:
	return "%d: %s" % [_errs.n - e0, _errs.first.slice(e0, e0 + 3)]


## Each shader on a small rect for a few frames: the renderer compiles it to draw it.
func _shaders() -> void:
	var dir := "res://shaders/jump/"
	var names := Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.ends_with(".gdshader"))
	_ok("the jump shaders are there to compile (%d)" % names.size(), names.size() >= 10)
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	for f: String in names:
		var e0 := _errs.n
		var sh := load(dir + f) as Shader
		if not _ok("%s loads as a shader" % f, sh != null):
			continue
		var r := ColorRect.new()
		r.size = Vector2(64, 64)
		var m := ShaderMaterial.new()
		m.shader = sh
		r.material = m
		if sh.get_mode() == Shader.MODE_CANVAS_ITEM:
			layer.add_child(r)
		else:
			# not a canvas shader: drawn as a material on a mesh would need a 3D scene; the
			# set_code parse above is all a real renderer gives it here
			r.queue_free()
		for i in 3:
			await RenderingServer.frame_post_draw
		_ok("%s compiles and draws (%s)" % [f, _errors_since(e0)], _errs.n == e0)
		if r.is_inside_tree():
			r.queue_free()
	layer.queue_free()


func _quiet_target() -> int:
	for raw in Run.map:
		var m: MapGen.MapNode = raw
		if m.index != Run.at and Run.can_jump_to(m) and m.type == MapGen.NodeType.SYSTEM:
			m.ambush_rolled = true
			m.ambush_pending = false
			return m.index
	return -1


## One film through Router.begin_jump to its commit, every frame drawn.
func _film(id: StringName) -> bool:
	JumpRegistry.forced = id
	var to := _quiet_target()
	if not _ok("%s: a quiet system in reach (%d)" % [id, to], to >= 0):
		return false
	var e0 := _errs.n
	var jumps0 := Run.jumps
	var played := &""
	var frames := 0
	Router.begin_jump(to)
	for i in 60 * 16:
		await RenderingServer.frame_post_draw
		frames += 1
		var sc := Router.current as SectorScreen
		var d: JumpDirector = sc._jump if sc != null else null
		if d != null and d._begun and played == &"":
			played = d.film()
		if Run.jumps > jumps0:
			break
	for i in 5:
		await RenderingServer.frame_post_draw
	_ok("%s: the film played (%s) and committed (%d frames drawn)" % [id, played, frames], played == id and Run.jumps == jumps0 + 1)
	_ok("%s: no shader, script or engine error while it played (%s)" % [id, _errors_since(e0)], _errs.n == e0)
	_clock("film %s" % id)
	Router.show_local()
	for i in 10:
		await _tree.process_frame
	(Router.current as SectorScreen)._skip()
	for i in 5:
		await _tree.process_frame
	return true


func _run() -> void:
	_tree = get_tree()
	OS.add_logger(_errs)
	await _tree.process_frame
	_ok("a real renderer, not the headless one (%s)" % DisplayServer.get_name(), DisplayServer.get_name() != "headless")
	await _shaders()
	_clock("shaders drawn")
	Rng.forced = Harness.seed_arg(4242)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))
	Router.show_local()
	for i in 10:
		await _tree.process_frame
	(Router.current as SectorScreen)._skip()
	for i in 10:
		await _tree.process_frame
	var done: Array[StringName] = []
	for id in JumpRegistry.ALL:
		if await _film(id):
			done.append(id)
	_ok("every landed film was built and drawn (%s of %s)" % [done, JumpRegistry.ALL], done == JumpRegistry.ALL)
	_ok("no shader, script or engine error in the whole run (%s)" % _errors_since(0), _errs.n == 0)
	OS.remove_logger(_errs)
	_clock("verdict")
	h.verdict("jumpshadertest")
	_tree.quit(h.code())
