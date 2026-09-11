class_name TutorialOverlay
extends Control

## The first flight, guided. A small panel that rides above every screen and
## walks a new player through one loop of the game: open the chart, jump, read
## a system, resolve one encounter, win one fight, and then the run is theirs.
##
## IT IS AN ORDINARY RUN ON A CURATED SEED, not a scripted level. Nothing here
## spawns anything, forces anything or blocks anything -- the galaxy the player
## is standing in is exactly the galaxy `-- seed SEED` produces, and every rule
## of a real run applies, including dying. The overlay only watches the bus and
## says what is worth doing next. Two consequences fall out of that and both
## are deliberate:
##
## 1. **The steps are conditions, not locations.** The player cannot be walked
##    off a rail because there is no rail: whichever system they jump to and
##    whichever order they do things in, the overlay checks "has an encounter
##    been resolved" and "has a fight been fought" and moves on when both are
##    true. The curated seed guarantees the RECOMMENDED path has both within
##    one jump; wandering just takes longer.
##
## 2. **The overlay is not saved.** A tutorial run autosaves like any run, and
##    CONTINUE resumes it as a plain run with no panel. That is accepted: the
##    save's job is the ship, and a player who quit mid-tutorial and came back
##    has already seen the screens the panel was narrating.
##
## The seed lives in SEED below and `-- seed N` on the command line still wins,
## which is how a candidate seed is auditioned without touching this file.
## `godot --headless --path . -- tutseed` scans for seeds that pass the same
## test the CHART step's recommendation runs, and prints replacements.

## The curated seed. Picked by `-- tutseed` (see TutorialSeedScan.gd): from the
## start system, at least one in-reach neighbour offers BOTH a declared fight
## and a peaceful encounter in different groups, with no ambush possible on the
## way in. Re-run the scan and change this number whenever the option table or
## the map generator moves under it.
## Seed 1: one jump from the start, ALPHA ABYSSAL GATE (danger 1) offers
## `hostile_contact` -- the plainest declared fight in the table -- alongside
## `drifting_lifepod` and `dead_station`. Re-picked 2026-09-01 after the
## eighty-encounter commission moved the positional rolls out from under
## seed 10 -- the merge gate caught it, which is the gate doing its job.
const SEED := 1

enum Step { OFF, WELCOME, CHART, SETTLE, FIGHT, WRAP }

## The one live instance, so Router can start a tutorial without holding a
## reference to a node Main owns. Follows FpsMeter's shape: built once at boot,
## over everything, part of no layout.
static var _live: TutorialOverlay = null

var _step: Step = Step.OFF
## The two things a first flight exists to show. Set and never cleared, so the
## order the player does them in does not matter.
var _did_calm: bool = false
var _did_fight: bool = false
## The system the CHART step recommends, or -1 when the seed (or the player's
## position) offers nothing better than "anywhere in reach".
var _target: int = -1
## What SETTLE last rendered, so _process can redraw only on change rather
## than sixty times a second. Compared as a string because it is four small
## facts and a tuple type is not worth inventing for them.
var _drawn: String = ""

var _panel: PanelContainer
var _title: Label
var _count: Label
var _body: Label
var _instr: Label
var _buttons: HBoxContainer


## Start the tutorial. Called by Router after the curated run exists, so
## everything read here -- the node, the chart -- is the tutorial's own galaxy.
static func begin() -> void:
	if _live != null:
		_live._begin()


func _ready() -> void:
	_live = self
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# The overlay covers the window but must cost the game nothing to click
	# through -- only the panel itself stops the mouse.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	visible = false
	set_process(false)
	Sig.screen_changed.connect(_on_screen_changed)
	Sig.jumped.connect(_on_jumped)
	Sig.combat_started.connect(_on_combat_started)
	Sig.combat_ended.connect(_on_combat_ended)
	# Any run beginning that is not the one begin() was called for ends the
	# lesson: a new run from the launcher, a save resumed. begin() runs AFTER
	# start_new_run's own emission, so the tutorial does not end itself.
	Sig.run_started.connect(func() -> void: _end())
	Sig.run_ended.connect(func(_w: bool, _r: String) -> void: _end())


func _exit_tree() -> void:
	if _live == self:
		_live = null


func _build() -> void:
	_panel = PanelContainer.new()
	# EMBER edge on the left, like a result panel: the same "this is the game
	# talking about the game" register, distinct from any place's own chrome.
	var sb := UITheme.flat(UITheme.PANEL2, UITheme.LINE, 0, 8, 10)
	sb.border_width_left = 2
	sb.border_color = UITheme.EMBER
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	# Top right, under the HUD row. Anchored rather than laid out because this
	# node is a sibling of the whole shell, not a member of it.
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.offset_left = -272
	_panel.offset_right = -10
	_panel.offset_top = 36
	add_child(_panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	_panel.add_child(col)

	var head := HBoxContainer.new()
	_title = UITheme.body("FIRST FLIGHT", UITheme.EMBER, UITheme.FS_SMALL)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_count = UITheme.body("", UITheme.COLD, UITheme.FS_SMALL)
	head.add_child(_count)
	col.add_child(head)

	_body = UITheme.body("", UITheme.CHILL, UITheme.FS_SMALL)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_body)

	_instr = UITheme.body("", UITheme.HOT, UITheme.FS_SMALL)
	_instr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_instr)

	_buttons = HBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	_buttons.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(_buttons)


func _begin() -> void:
	_did_calm = false
	_did_fight = false
	_target = -1
	_enter(Step.WELCOME)


func _end() -> void:
	if _step == Step.OFF:
		return
	_step = Step.OFF
	visible = false
	set_process(false)


func _enter(s: Step) -> void:
	_step = s
	visible = true
	set_process(true)
	_drawn = ""
	_render()


# ------------------------------------------------------------------ advancing

func _on_screen_changed() -> void:
	if _step == Step.WELCOME and Router.current is StarchartScreen:
		_enter(Step.CHART)


func _on_jumped(_index: int) -> void:
	if _step == Step.CHART or _step == Step.SETTLE:
		_enter(Step.SETTLE)


func _on_combat_started(_who: String) -> void:
	# From any live step: an ambush on the way in is as good a first fight as
	# the one the drawer offered, and the lesson is the same either way.
	if _step != Step.OFF and _step != Step.FIGHT:
		_enter(Step.FIGHT)


func _on_combat_ended(_result: StringName, _summary: String) -> void:
	if _step != Step.FIGHT:
		return
	if Run.dead:
		# The game over screen says everything worth saying about this.
		_end()
		return
	# Fled counts. The step exists to show the fight screen, not to demand a
	# kill, and the option that opened the fight is spent either way.
	_did_fight = true
	_enter(Step.WRAP if _did_calm else Step.SETTLE)


## SETTLE has no signal to ride: an option resolved in the drawer swaps no
## screen. So while the overlay is up it checks its two conditions each frame
## -- a read of one node's small arrays, and a redraw only when the answer
## moves.
func _process(_delta: float) -> void:
	if _step != Step.SETTLE:
		return
	_scan_taken()
	if _did_calm and _did_fight:
		_enter(Step.WRAP)
		return
	var n: MapGen.MapNode = Run.node_at()
	# The option count is in the key because the overlay hears a jump BEFORE
	# Router rolls what the system offers -- it connected to the bus first --
	# so the first SETTLE render always sees an empty list and must not be the
	# last.
	var key := "%d/%s/%s/%d/%d" % [Run.at, _did_calm, _did_fight,
		n.taken.size() if n != null else 0,
		n.options.size() if n != null else 0]
	if key != _drawn:
		_drawn = key
		_render()


## Read what the current system says has been done. Set-only: an encounter
## resolved three jumps ago stays counted wherever the ship is now.
func _scan_taken() -> void:
	var n: MapGen.MapNode = Run.node_at()
	if n == null:
		return
	# OPTION_WHOLE is deliberately NOT read here, though a stripped wreck is a
	# resolved encounter in spirit. The marker is overloaded: MapGen stamps it
	# on the start node at generation, and consume_node appends it when a
	# system finishes for ANY reason -- so jumping back to the start, or
	# winning a system whose only option was the fight, would tick the calm
	# half of a lesson nobody was taught. The drawer options carry results per
	# slot; the whole-system marker carries nothing to tell those cases apart.
	for i in n.options.size():
		if not n.taken.has(MapGen.OPTION_SITE + i):
			continue
		# Spent is not the same as RESOLVED BY YOU: foreclosure and a party
		# partner's claim both append to `taken` and both write R_GONE. Only a
		# slot with a recorded outcome that is not "gone" was seen through.
		if n.results.get(i, MapGen.R_GONE) == MapGen.R_GONE:
			continue
		if not _fights(OptionTable.by_id(n.options[i])):
			_did_calm = true


## Whether any of this option's choices declares a fight. The declaration on
## the CHOICE, not the trigger in the outcome -- same read the sector's contact
## badge uses, and for the same reason: it has to be answerable without
## resolving anything.
static func _fights(opt: Dictionary) -> bool:
	for c in opt.get("choices", []):
		if bool((c as Dictionary).get("fight", false)):
			return true
	return false


## The neighbour worth recommending: in reach, and offering both halves of the
## lesson in groups that do not foreclose each other. On the curated seed this
## always answers; off it, -1 falls back to "anywhere in reach".
##
## `OptionTable.ensure` on an unvisited node is safe here because options are
## positional -- what is written is exactly what arrival would write.
func _pick_target() -> int:
	var here: MapGen.MapNode = Run.node_at()
	if here == null:
		return -1
	for i in here.links:
		var n: MapGen.MapNode = Run.map[i]
		if n.type != MapGen.NodeType.SYSTEM or not Run.can_jump_to(n):
			continue
		if lesson_at(n):
			return i
	return -1


## Whether one system offers both halves of the lesson: a declared fight, and
## a peaceful encounter that no fight can foreclose. THE ONE COPY of this
## predicate -- the CHART step's recommendation and the seed scan both call
## it, so a seed the scan certifies is a seed the overlay will recommend, by
## construction rather than by keeping two files in step.
##
## The fight GROUPS are collected as a set, not a survivor: with one variable,
## two grouped fights would leave only the second's group held, and a calm
## option sharing the first's would pass -- certified by the scan, foreclosed
## in play, stranding step three. All of today's fight options are ungrouped,
## which is exactly when a latent bug gets written.
static func lesson_at(n: MapGen.MapNode) -> bool:
	OptionTable.ensure(n)
	var fight_groups: Dictionary = {}
	var has_fight := false
	for oid in n.options:
		var o := OptionTable.by_id(oid)
		if _fights(o):
			has_fight = true
			var g := StringName(o.get("group", &""))
			if g != &"":
				fight_groups[g] = true
	if not has_fight:
		return false
	for oid in n.options:
		var o := OptionTable.by_id(oid)
		if _fights(o):
			continue
		var g2 := StringName(o.get("group", &""))
		if g2 == &"" or not fight_groups.has(g2):
			return true
	return false


# ------------------------------------------------------------------ rendering

func _render() -> void:
	Widgets.clear(_buttons)
	match _step:
		Step.WELCOME:
			_count.text = "1/5"
			_body.text = "This is the sector: your ship, the log of what has happened to it, and along the bottom, everything this system offers. The start is quiet on purpose."
			_instr.text = "Press PLOT NEXT JUMP to open the chart."
		Step.CHART:
			if _target < 0:
				_target = _pick_target()
			_count.text = "2/5"
			_body.text = "Every jump costs fuel, and fuel is the run's clock. You can only see what your dish reaches; the rings run deeper and meaner toward the core."
			# Guarded rather than ternaried: the %-format must not run at all
			# when there is no target, because Run.map[-1] is the last node in
			# the galaxy wearing a recommendation it never earned.
			if _target >= 0:
				_instr.text = "Jump to %s." % MapGen.star_name(Run.map[_target])
			else:
				_instr.text = "Jump to any system in reach."
		Step.SETTLE:
			_count.text = "3/5"
			_body.text = "A system offers up to five encounters. Walking away is always free -- an encounter only ever guards a reward, never the way out."
			_instr.text = _settle_lines()
		Step.FIGHT:
			_count.text = "4/5"
			_body.text = "Your modules are your cards, and ENERGY is what a turn lets you spend. Heat builds as you fire and burns hull past the cap at end of turn. The enemy prints its intent before it acts -- answer what is coming, then END TURN."
			_instr.text = "Fight it out."
		Step.WRAP:
			_count.text = "5/5"
			_body.text = "That is the whole loop: jump, read the system, take what pays. A won fight drops what the other ship carried onto the sector floor -- SECTOR LOOT -- and the SHIP tab is where you fit what you take."
			_instr.text = "The run is yours now. The core is at the centre."
		_:
			return
	if _step == Step.WRAP:
		_add_button("FINISH", _end, true)
	else:
		_add_button("END TUTORIAL", _end)


## The 3/5 checklist, written as text rather than widgets: two lines, each
## either done or the next thing to do.
func _settle_lines() -> String:
	var lines: Array[String] = []
	var n: MapGen.MapNode = Run.node_at()
	var here_fights := false
	var here_calm := false
	if n != null:
		for i in n.options.size():
			if n.taken.has(MapGen.OPTION_SITE + i):
				continue
			if _fights(OptionTable.by_id(n.options[i])):
				here_fights = true
			else:
				here_calm = true
	if _did_calm:
		lines.append("[x] An encounter, seen through.")
	elif here_calm:
		lines.append("[ ] Open an encounter from the drawer and see it through.")
	if _did_fight:
		lines.append("[x] A fight, fought.")
	elif here_fights:
		lines.append("[ ] Open the contact marked in red and engage.")
	# EITHER half still owed and not on offer here means the chart. Checked per
	# half rather than for the whole system, because a spent system and a
	# system that never held a fight both leave the player standing somewhere
	# the lesson cannot finish.
	if (not _did_calm and not here_calm) or (not _did_fight and not here_fights):
		lines.append("The rest is elsewhere. PLOT NEXT JUMP and read the next system.")
	return "\n".join(lines)


func _add_button(text: String, action: Callable, primary: bool = false) -> void:
	var b := Widgets.cta(text, action) if primary else Widgets.button(text, action)
	b.custom_minimum_size = Vector2(110, 17)
	_buttons.add_child(b)
