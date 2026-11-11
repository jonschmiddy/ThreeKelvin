class_name JumpDirector
extends Node

## Runs one jump film on LOCAL (a child of the SectorScreen leaving): picks the film for this
## jump, bakes the hull, builds the stage at the end of EncounterView, steps the film on
## GameClock, fires its cues on the frames they fall, swaps the live hull for the baked
## stand-in on a pixel-identical frame, and commits the jump at the film's commit time.
## Why: docs/why/JumpDirector.md#director

## The old hyperdrive's lead and rev (`JumpFx`), kept for the cine's strips of it.
const DEPART_LEAD := 0.10
const REV_S := 0.90

var sector: SectorScreen
var view: EncounterView
var art: ShipView
var seq: JumpSequence
var stage: JumpStage
var hull: JumpHull
var place: JumpPlace
var t := 0.0
var _t0 := 0.0
var _fired: Array[bool] = []
var _cues: Array = []
var _swapped := false
var _committed := false
var _over := false


## Start the film. The screen is built in the same call that departs, before its first layout,
## so the measuring waits for the first frame the view has a size; the film's clock starts then.
func start(sc: SectorScreen, v: EncounterView) -> void:
	sector = sc
	view = v
	art = v.ship_view()
	set_process(true)


var _begun := false

func _begin() -> void:
	_begun = true
	# the ship goes still: no flame, no bob, as the film's did
	art.depart(true)
	seq = JumpRegistry.make(JumpRegistry.pick(Run.jumps))
	seq.reduce = DisplaySettings.reduce_flashes
	hull = JumpHull.of(art, self)
	place = JumpPlace.measure(view, art)
	stage = JumpStage.new()
	view.add_child(stage)
	seq.setup(stage, place, hull)
	_cues = seq.cues()
	_fired.resize(_cues.size())
	_fired.fill(false)
	_t0 = GameClock.now()
	t = 0.0


func _process(_delta: float) -> void:
	if _over:
		return
	if not _begun:
		if view.get_global_rect().size.x < 10.0 or art.size.x < 10.0:
			return
		_begin()
	t = GameClock.now() - _t0
	_tick()


func _tick() -> void:
	for i in _cues.size():
		var at: float = _cues[i][1]
		if not _fired[i] and t >= at:
			_fired[i] = true
			# the film's own mix from this point, no pitch variance, this take and no other
			Audio.play(_cues[i][0], 0.0, 0, 0.0, 1.0, maxf(0.0, t - at), true)
	# the stand-in takes over on a frame nothing has touched the hull yet
	if not _swapped and hull.poll() and t >= seq.swap_t:
		_swapped = true
		art.visible = false
		seq.hull_ready()
	seq.step(t)
	if not _committed and t >= seq.commit_t:
		_committed = true
		_over = true
		sector._commit(false)


## A skip: the cues are cut, the stage goes, and the sector commits as skipped.
func skip() -> void:
	if _over:
		return
	_over = true
	var names: Array[StringName] = []
	for c in _cues:
		names.append(c[0])
	Audio.hush(names)
	teardown()


func teardown() -> void:
	set_process(false)
	if seq != null:
		seq.teardown()
	if stage != null and is_instance_valid(stage):
		stage.queue_free()
	stage = null


## Which film plays, for the harnesses and the cine.
func film() -> StringName:
	return seq.id if seq != null else &""
