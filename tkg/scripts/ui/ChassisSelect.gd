class_name ChassisSelect
extends Control

## Two axes: manufacturer is who you are, weight class is how much ship.
## Selecting really refits (`Run.fit_chassis()`), so there is no second calculation to drift.
## The banner shipyard since Nov 10: `YardFront` is the hall, `YardBand` the
## facts; this is what a click means.
## Why: docs/why/ChassisSelect.md#chassis-select

signal launched

const WEIGHTS := [HullData.Weight.LIGHT, HullData.Weight.MEDIUM, HullData.Weight.HEAVY]
## One line on what a class buys, not its numbers, which are already on screen.
## Specification, not condition: a class grows hardpoints, and wear lives in `HullWear`.
## Why: docs/why/ChassisSelect.md#tier-blurbs
const TIER_BLURB: Array[String] = [
	"The base specification that every run starts on.",
	"An uprated frame with more hull and heat capacity, on the same hardpoints.",
	"The line specification, with an extra weapon hardpoint.",
	"The top model, with an extra weapon and system mount and the reactor to run them.",
]

const WEIGHT_BLURB: Array[String] = [
	"Thin plate and the smallest hold, but it draws the biggest hand and can dodge.",
	"In the middle on every stat, with no big strength and no big weakness.",
	"The most plate and the biggest hold, but it cannot dodge at all.",
]
## The name, then one sentence, never restating the number beside it.
const MOUNT_TIP := {
	"weapon": "Weapon mounts
Where guns, launchers and charged ordnance bolt on. Each one grants two cards to your deck.",
	"system": "System mounts
Armour, coolant and shielding — the defensive half of a build. Each one grants two cards.",
	"utility": "Utility mounts
Masts, dishes, drone racks and sensors. The situational parts, and they grant two cards like everything else.",
	"hand": "Hand
How many cards you are dealt at the start of each combat turn.",
	"hold": "Hold
Loose parts you can carry between fights. A full hold means leaving the next wreck where it lies.",
	"reactor": "Reactor
Total cells of hardware this frame can RUN. The hold is what you can haul; this is what you can power, and a part has to satisfy both.",
}
## The attribute column's width on the band (`HullNumberTest` holds it).
const SIDE_W := YardBand.SIDE_W

## The manufacturer whose set is on the stands (an index into `DB.STARTABLE`).
var _sel: int = 0
## The picked ship's weight, or -1 for none: LAUNCH stays grey until one is.
var _picked: int = -1
## The condition grade to launch on. DEV ONLY — a real run always starts at C,
## because a graded frame is something you cut out of a wreck.
var _tier: int = 0
var _yard: YardFront
var _band: YardBand
## The weight the pointer is on, or -1: its facts show while it is.
var _hover: int = -1
## A tarp was clicked under this locked set: LAUNCH shows, grey.
var _tarp_tried: bool = false
## The open banners' hulls not yet handed to the worker (`_bake_ahead`).
var _to_bake: Array[HullData] = []
## LAUNCH pressed: it never fires twice.
var _launching := false


func setup() -> void:
	# The whole picture, not the shell's content box: the hall runs edge to edge
	# and there is no HUD over it (`Router.show_chassis_select` hides the bar).
	top_level = true
	position = Vector2.ZERO
	size = Vector2(YardFront.W, YardFront.H)
	# NO SCIENCE CLEARED HERE.
	# Why: docs/why/ChassisSelect.md#no-science-cleared-here
	_bake_ahead()
	_yard = YardFront.new()
	add_child(_yard)
	_yard.setup()
	_yard.banner_pressed.connect(_select)
	_yard.ship_pressed.connect(func(w: HullData.Weight) -> void: _pick_weight(w))
	_yard.ship_hover.connect(_on_hover)
	_band = YardBand.new()
	add_child(_band)
	_band.setup(DevMode.enabled, _tier)
	_band.launch.connect(_launch)
	_band.tier_picked.connect(_pick_tier)
	_select(0)


## Every open banner's hulls baked on a worker, Korvan's alongside the hall's
## build, then one at a time behind the hall: a banner's first click baked its
## three here, 0.6 s. Twenty-one side by side starved the first three.
## Why: docs/why/ChassisSelect.md#hulls-baked-ahead
func _bake_ahead() -> void:
	for m: StringName in DB.STARTABLE:
		if Unlocks.unlocked(m):
			for w: HullData.Weight in [HullData.Weight.HEAVY, HullData.Weight.MEDIUM, HullData.Weight.LIGHT]:
				_to_bake.append(DB.at_tier(DB.hull_for(m, w), _tier))
	HullGrade.bake_ahead(_to_bake.slice(0, 3), _bake_seed)
	_to_bake = _to_bake.slice(3)


static func _bake_seed(h: HullData) -> int:
	return HullWear.seed_for(h, "", Rng.master)


func _process(_dt: float) -> void:
	if not _to_bake.is_empty() and HullGrade.ahead_idle():
		HullGrade.bake_ahead([_to_bake.pop_front()], _bake_seed)


func _exit_tree() -> void:
	HullGrade.finish_ahead()


func manufacturer() -> StringName:
	return DB.STARTABLE[_sel]


func open() -> bool:
	return Unlocks.unlocked(manufacturer())


## A ship is picked and its manufacturer is open to fly.
func launchable() -> bool:
	return _picked >= 0 and open()


## A banner: its ships come onto the stands, or its tarps when it is locked.
## A pick carries across (a medium stays a medium), as the two axes are
## independent; under tarps it waits, LAUNCH grey.
func _select(i: int) -> void:
	_sel = i
	_hover = -1
	_tarp_tried = false
	if open() and _picked >= 0:
		_refit()
	_yard.show_set(manufacturer(), open(), _tier)
	_yard.set_picked(_picked)
	_show_band()
	# The blurb alone: the band and the hull already say its size (Jon, Nov 11).
	for s: YardStandSet in _yard.sets.values():
		s.tooltip_text = Widgets.tip(WEIGHT_BLURB[int(s.weight)]) \
			if open() else Widgets.tip(Unlocks.lock_line(manufacturer()))


## A click on a hull picks it: it is the ship until another is clicked.
## A tarp's click picks nothing, but brings LAUNCH up grey beside the lock line.
func _pick_weight(w: HullData.Weight) -> void:
	if not open():
		_tarp_tried = true
		_show_band()
		return
	_picked = int(w)
	_refit()
	_yard.set_picked(_picked)
	_show_band()


## A click that no ship, banner or key took: away from the ships, so the pick goes
## (Jon, Nov 11). A band word with a tooltip passes its click on, and is not away.
## Why: docs/why/ChassisSelect.md#click-away
func _gui_input(e: InputEvent) -> void:
	var mb := e as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _band.on_word(get_global_transform() * mb.position):
		return
	accept_event()
	deselect()


func deselect() -> void:
	if _picked < 0 and not _tarp_tried:
		return
	_picked = -1
	_tarp_tried = false
	_yard.set_picked(-1)
	_show_band()


func _pick_tier(t: int) -> void:
	_tier = t
	_band.mark_tier(t)
	if _picked >= 0:
		_refit()
	_yard.show_set(manufacturer(), open(), _tier)
	_show_band()


## The live ship is the one the band reads: the picked one, or the one pointed at.
func _refit(w: int = -1) -> void:
	var weight := w if w >= 0 else _picked
	if weight < 0:
		return
	Run.fit_chassis(manufacturer(), weight as HullData.Weight, _tier)


func _on_hover(w: int) -> void:
	_hover = w
	if open() and w >= 0:
		_refit(w)
	elif open() and _picked >= 0:
		_refit()
	_show_band()


func _show_band() -> void:
	var m: ManufacturerData = DB.manufacturers[manufacturer()]
	var shown := _hover if _hover >= 0 else _picked
	if not open():
		_band.show_locked(manufacturer(), _yard.tie_point(_hover as HullData.Weight) if _hover >= 0 else Vector2.ZERO)
	elif shown >= 0:
		_band.show_ship(m, shown == _picked, _yard.tie_point(shown as HullData.Weight), launchable())
	else:
		_band.show_rest()
	_band.arm(_picked >= 0 or (_tarp_tried and not open()))


func _launch() -> void:
	if not launchable():
		return
	_refit()
	# The ship lifts off its stands and burns off right first (Jon's L1, Nov 12);
	# reduced motion, and the harnesses that do not animate, cut straight to the run.
	# Why: docs/why/ShipLift.md#front-door
	if _launching:
		return
	_launching = true
	if Router.animating() and _yard.ready_hall:
		# nothing on the hall or the band answers the pointer from here on
		var block := Control.new()
		block.mouse_filter = Control.MOUSE_FILTER_STOP
		block.size = size
		add_child(block)
		if _yard.lift_off(_picked, self, func() -> void: launched.emit()) != null:
			return
	launched.emit()


## Back to the title: the escape menu's BACK TO TITLE here (Jon, Nov 11), never ABANDON,
## which put a run that never started on the record.
## Why: docs/why/ChassisSelect.md#escape-handling
func escape() -> void:
	# (not once LAUNCH has the ship in the air: the run is on its way)
	if _launching:
		return
	Run.hull = null
	Router.show_launcher()
