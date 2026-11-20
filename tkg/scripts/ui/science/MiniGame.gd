class_name MiniGame
extends RefCounted

## One science mini game, as the prototypes' contract has it (tk-scratch/science/minigames/API.md):
## mounted with a depth (1 to 5, the sector), sensors (0 to 5) and a seeded stream; it draws only
## its puzzle on its own canvas and says `done` once, with a score 0..1 and a short detail. The
## shell (`MiniShell`) owns everything round it: the glass, the tell, give-up, the haul, the sounds.
## Why: docs/why/MiniGame.md#the-contract

## Said exactly once, when the puzzle ends (a give-up included).
signal finished(score: float, detail: String)

var depth := 1
var sensors := 0
var rng: RandomNumberGenerator
var px: MiniPix
## Seconds since the mount, on the shell's clock (the desk's, so films and `--fixed-fps` hold).
var t := 0.0
## The sounds asked for since the shell last took them: [name, ...] (`MiniShell.SFX` maps them).
var asked: Array[StringName] = []
## Whether the canvas changed since the shell last copied it.
var dirty := true
## The pointer in canvas pixels before flooring (the prototypes that read `clientX` as a fraction).
var pf := Vector2.ZERO
## The looping sounds wanted on now (name -> true); the shell starts and stops them to match.
var loops: Dictionary = {}
## The seed the puzzle was dealt from (Pulsar's video glitch is drawn from it).
var seed := 0
## Whether frames are drawn as the game runs (a scripted run in the headless test plays thousands of
## steps without looking).
var drawing := true
var _fired := false
## setTimeout's queue: [due seconds, Callable].
var _later: Array = []


## The game's id, one line and controls (`hint`, `controls` in its prototype's register).
func id() -> StringName:
	return &""


func hint() -> String:
	return ""


func controls() -> Array[String]:
	return []


func mount(d: int, s: int, r: RandomNumberGenerator) -> void:
	depth = clampi(d, 1, 5)
	sensors = clampi(s, 0, 5)
	rng = r
	_mount()
	dirty = true


## Advance `dt` seconds: timers first, then the game's own clock.
func tick(dt: float) -> void:
	t += dt
	var due: Array = []
	var keep: Array = []
	for e: Array in _later:
		(due if float(e[0]) <= t else keep).append(e)
	_later = keep
	for e: Array in due:
		(e[1] as Callable).call()
	_tick(dt)


## Pointer at canvas pixel p (may lie off the canvas while a drag holds it).
func down(_p: Vector2i) -> void:
	pass


func move(_p: Vector2i) -> void:
	pass


func up(_p: Vector2i, _cancel := false) -> void:
	pass


## A key the game listens to (W, A, D and the arrows, as `&"w"`, `&"a"`, `&"d"`), pressed or let go.
func key(_k: StringName, _pressed: bool) -> void:
	pass


## The mouse wheel over the canvas: +1 up, -1 down.
func wheel(_dir: int) -> void:
	pass


## `giveUp()`: the partial score earned so far (often 0), unless done already fired.
func give_up() -> void:
	pass


func is_done() -> bool:
	return _fired


func _mount() -> void:
	pass


func _tick(_dt: float) -> void:
	pass


func done(score: float, detail: String) -> void:
	if _fired:
		return
	_fired = true
	finished.emit(clampf(score, 0.0, 1.0), detail)


func after(secs: float, f: Callable) -> void:
	_later.append([t + secs, f])


func sfx(name: StringName) -> void:
	asked.append(name)


func sfx_loop(name: StringName, on: bool) -> void:
	if on:
		loops[name] = true
	else:
		loops.erase(name)
