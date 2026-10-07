extends Harness

## Developer mode exists only where the editor does:
##   godot --headless --path . -- devtest
##   godot --headless --path . -- devtest asrelease
##
## Jon: "Dev mode shouldn't even be accessible in the released version." It was
## on for a fresh install, so a friend's first launch would have opened every
## manufacturer, the card gallery and the whole galaxy. `DevMode.available` is
## the editor binary now, and an exported game has no workshop at all.
##
## BOTH SIDES, FROM THE SAME SETTINGS FILE. A scratch file that says
## [dev] enabled=true, because Jon's own file says that and a check against an
## empty one would pass on a build that still read it. In the editor that file
## gives developer mode: the title screen builds its switch, the HUD its CARDS
## and MODULES tabs, the chassis select its tier row, the star chart its four
## dev buttons, and every manufacturer is open. As released, the same file gives
## none of it: the switch is not built, toggle() changes nothing and writes
## nothing, and a fresh profile flies Korvan alone. The editor half is the
## proof that the release half can see what it is looking for.
##
## THE PLAYER'S FILES ARE NEVER TOUCHED. `DevMode.path` and `RunHistory.path`
## point at scratch files for the whole run, and both are deleted at the end.
## Screens are built in a holder of the test's own and never through Router, so
## no screen swap autosaves a run. With `asrelease` on the command line the boot
## itself is checked too: Main came up without dev mode or its tabs, whatever
## the settings file says.

const SCRATCH := "user://devtest.cfg"
const HISTORY := "user://devtest_history.json"

## Every face the star chart's dev buttons can wear. Four are built in the
## editor, one of each pair, and none as released.
const CHART_DEV := ["HIDE SYSTEMS", "SHOW SYSTEMS", "SHOW REACH", "HIDE REACH",
	"SHOW ALL SYSTEMS", "SHOW KNOWN ONLY", "REGENERATE GALAXY"]

var _tree: SceneTree
var _holder: Control
## How many times Sig.dev_mode_changed fired since it was last zeroed.
var _changes: int = 0


func run(tree: SceneTree) -> void:
	_tree = tree
	await tree.process_frame
	var boot_available := DevMode.available
	var boot_enabled := DevMode.enabled

	print("boot")
	_boot()
	# EVERY HARNESS KEEPS OFF THE PLAYER'S SETTINGS: the boot's own save (and
	# Audio's and Keys') goes to the scratch file. A `sheet=` shot once rewrote
	# the player's settings.cfg on every boot that did not pass `keepwindow`.
	_ok("a harness's display, audio and key settings live in a scratch file, never the player's settings.cfg",
		TestRun.active() and DisplaySettings.path != DisplaySettings.PATH and Keys.path != DisplaySettings.PATH)

	DevMode.path = SCRATCH
	RunHistory.path = HISTORY
	_drop_scratch()
	Sig.dev_mode_changed.connect(_on_changed)
	_holder = Control.new()
	_holder.size = Vector2(960, 540)
	tree.root.add_child(_holder)
	_seed_settings()

	print("title screen, in the editor")
	DevMode.available = true
	DevMode.load_settings()
	_ok("[dev] enabled=true gives developer mode", DevMode.enabled)
	await _launcher(true)
	await _toggle_in_editor()

	print("title screen, as released")
	DevMode.available = false
	# Before load_settings: the flag was on, and it reads off the moment the
	# workshop is gone, not at the next load.
	_ok("a flag already on reads off once it is not available", not DevMode.enabled)
	DevMode.load_settings()
	_ok("the same file still gives no developer mode", not DevMode.enabled)
	await _launcher(false)
	_toggle_as_released()

	Rng.reseed(4471, 0)
	Run.start_new_run(&"korvan", int(HullData.Weight.MEDIUM))

	print("a run, in the editor")
	DevMode.available = true
	DevMode.load_settings()
	_ok("developer mode is back on from the file", DevMode.enabled)
	await _screens(true)
	_unlocks(true)

	print("a run, as released")
	DevMode.available = false
	DevMode.load_settings()
	_ok("developer mode is off from the same file", not DevMode.enabled)
	await _screens(false)
	_unlocks(false)

	await _finish(boot_available, boot_enabled)


## What Main came up with, before the test moves anything.
func _boot() -> void:
	var as_release := "asrelease" in OS.get_cmdline_user_args()
	var editor := OS.has_feature("editor")
	print("  (editor binary: %s, asrelease: %s, dev mode at boot: %s)" % [
		editor, as_release, DevMode.enabled])
	_ok("available at boot is the editor binary, less asrelease",
		DevMode.available == (editor and not as_release))
	# The rule, asked for the build this process is not. From the editor binary
	# has_feature("editor") is always true, so the check above would pass a rule
	# that forgot it, or one that asked is_debug_build(), which a debug export
	# also is. Only these see that.
	_ok("an export, which has no editor feature, gets none",
		not DevMode._detect(PackedStringArray(["devtest"]), false))
	_ok("the editor binary gets it",
		DevMode._detect(PackedStringArray(["devtest"]), true))
	_ok("asrelease turns it off",
		not DevMode._detect(PackedStringArray(["devtest", "asrelease"]), true))
	# Run on an exported build (the export's smoke test), this is the one that
	# counts: the real feature, the real settings file, no workshop.
	if not editor:
		_ok("this is an export, and it came up with no developer mode",
			not DevMode.available and not DevMode.enabled)
	if not DevMode.available:
		_ok("not available, so dev mode came up off whatever settings.cfg says",
			not DevMode.enabled)
	# The title screen Main itself built at boot, not one this test builds after
	# moving the flag by hand.
	if _ok("Main booted to the title screen", Router.current is LauncherScreen):
		_ok("and it has the switch exactly when developer mode is available",
			_with_text(Router.current, "DEVELOPER MODE") == (1 if DevMode.available else 0))
	if Router.hud != null:
		_ok("Main's HUD has a CARDS tab exactly when dev mode came up on",
			_buttons(Router.hud, ["CARDS"]) == (1 if DevMode.enabled else 0))


func _launcher(dev: bool) -> void:
	var l := LauncherScreen.new()
	_holder.add_child(l)
	l.setup()
	await _tree.process_frame
	var named := _with_text(l, "DEVELOPER MODE")
	var wired := _wired_to(l, &"_on_dev_toggle")
	if dev:
		_ok("the title screen builds DEVELOPER MODE", named == 1)
		_ok("and one button is wired to the switch", wired == 1)
	else:
		_ok("the title screen builds no DEVELOPER MODE", named == 0)
		_ok("and no button is wired to the switch", wired == 0)
		_ok("and nothing describes what it did", _with_text(l, "Card gallery") == 0)
	_ok("the menu is all there", _buttons(l, ["NEW RUN", "SETTINGS", "QUIT"]) == 3)
	await _drop(l)


## The switch works, and the bytes check below can see a write when one happens.
func _toggle_in_editor() -> void:
	var before := FileAccess.get_file_as_bytes(SCRATCH)
	_changes = 0
	DevMode.toggle()
	_ok("toggle turns it off", not DevMode.enabled)
	_ok("and says so once", _changes == 1)
	var cfg := ConfigFile.new()
	cfg.load(SCRATCH)
	_ok("and saves it beside the display section",
		cfg.get_value("dev", "enabled", true) == false
		and int(cfg.get_value("display", "brightness", 0)) == 1)
	_ok("so the file's bytes changed", FileAccess.get_file_as_bytes(SCRATCH) != before)
	# Off is not gone. The switch is built wherever dev mode is AVAILABLE, on or
	# off, or the first untick in the editor would be the last one short of
	# editing settings.cfg by hand.
	print("title screen, in the editor, developer mode off")
	await _launcher(true)
	DevMode.toggle()
	_ok("toggle again turns it back on", DevMode.enabled)
	cfg = ConfigFile.new()
	cfg.load(SCRATCH)
	_ok("and the file says enabled=true again", cfg.get_value("dev", "enabled", false) == true)


func _toggle_as_released() -> void:
	var before := FileAccess.get_file_as_bytes(SCRATCH)
	_changes = 0
	DevMode.toggle()
	_ok("toggle leaves it off", not DevMode.enabled)
	_ok("and says nothing", _changes == 0)
	DevMode.save()
	_ok("toggle and save wrote nothing: the file is byte for byte the same",
		FileAccess.get_file_as_bytes(SCRATCH) == before)
	DevMode.enabled = true
	_ok("setting it by hand leaves it off", not DevMode.enabled)

	# A fresh install: no settings file at all. Nothing may create one.
	_drop_file(SCRATCH)
	DevMode.load_settings()
	DevMode.toggle()
	DevMode.save()
	_ok("a fresh install is off and no settings file is written",
		not DevMode.enabled and not FileAccess.file_exists(SCRATCH))
	_seed_settings()


func _screens(dev: bool) -> void:
	var hud := HudBar.new()
	_holder.add_child(hud)
	await _tree.process_frame
	var tabs := _buttons(hud, ["CARDS", "MODULES"])
	if dev:
		_ok("the HUD builds CARDS and MODULES", tabs == 2)
	else:
		_ok("the HUD builds no CARDS or MODULES", tabs == 0)
	_ok("and the rest of the bar", _buttons(hud, ["STARCHART", "ARCHIVE"]) == 2)
	_ok("and no SHIP tab (your ship opens where it is drawn)", _buttons(hud, ["SHIP"]) == 0)
	await _drop(hud)

	var pick := ChassisSelect.new()
	_holder.add_child(pick)
	pick.setup()
	await _tree.process_frame
	var tiers := _tier_buttons(pick)
	if dev:
		_ok("the chassis select builds the C-B-A-S tier row", tiers == HullData.TIER_NAMES.size())
	else:
		_ok("the chassis select builds no tier row", tiers == 0)
	_ok("and still says the grade", _with_text(pick, "TIER") >= 1)
	await _drop(pick)

	Run.chart_from(Run.node_at())
	# SHOW ALL SYSTEMS is remembered from chart to chart, like the other view
	# toggles. Left on when developer mode goes off, it must stop revealing.
	var was_all := StarchartScreen._show_all
	StarchartScreen._show_all = true
	var chart := StarchartScreen.new()
	_holder.add_child(chart)
	chart.setup()
	await _tree.process_frame
	var devs := _buttons(chart, CHART_DEV)
	var regen := _buttons(chart, ["REGENERATE GALAXY"])
	if dev:
		_ok("the star chart builds its four dev buttons", devs == 4)
		_ok("REGENERATE GALAXY among them", regen == 1)
		_ok("a remembered SHOW ALL SYSTEMS shows them all", chart._chart.show_all)
	else:
		_ok("the star chart builds none of its dev buttons", devs == 0)
		_ok("REGENERATE GALAXY is not built", regen == 0
			and _with_text(chart, "REGENERATE") == 0)
		_ok("a SHOW ALL SYSTEMS left on reveals nothing", not chart._chart.show_all)
	StarchartScreen._show_all = was_all
	await _drop(chart)


## In the editor everything is open with no record at all. As released a fresh
## profile has Korvan, and a win with Korvan opens Solari and nothing past it:
## the chain is honoured, so the release side is not simply "everything shut".
func _unlocks(dev: bool) -> void:
	_drop_file(HISTORY)
	var open: Array[StringName] = []
	for m in Unlocks.CHAIN:
		if Unlocks.unlocked(m):
			open.append(m)
	if dev:
		_ok("developer mode opens every manufacturer", open.size() == Unlocks.CHAIN.size())
		return
	_ok("a fresh profile flies Korvan", open.has(&"korvan"))
	_ok("and every other manufacturer is locked", open.size() == 1)
	var f := FileAccess.open(HISTORY, FileAccess.WRITE)
	f.store_string(JSON.stringify({version = RunHistory.VERSION, runs = [
		{outcome = int(RunHistory.Outcome.WON), chassis_manufacturer = "korvan"}]}))
	f.close()
	_ok("a win with Korvan opens Solari", Unlocks.unlocked(&"solari"))
	_ok("and not the one after it", not Unlocks.unlocked(&"probate"))
	_drop_file(HISTORY)


# ------------------------------------------------------------------- helpers

## Jon's used state: the switch on and saved, beside another section.
func _seed_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "brightness", 1)
	cfg.set_value("dev", "enabled", true)
	cfg.save(SCRATCH)


func _on_changed() -> void:
	_changes += 1


## Buttons under `root` whose text is exactly one of `texts`.
func _buttons(root: Node, texts: Array) -> int:
	var n := 0
	var b := root as Button
	if b != null and b.text in texts:
		n += 1
	for c in root.get_children():
		n += _buttons(c, texts)
	return n


## Nodes under `root` whose words or tooltip contain `needle`.
func _with_text(root: Node, needle: String) -> int:
	var n := 0
	var said := ""
	if root is Button:
		said = (root as Button).text
	elif root is Label:
		said = (root as Label).text
	if root is Control:
		said += " " + (root as Control).tooltip_text
	if said.contains(needle):
		n += 1
	for c in root.get_children():
		n += _with_text(c, needle)
	return n


## Buttons under `root` whose press calls `method`.
func _wired_to(root: Node, method: StringName) -> int:
	var n := 0
	var b := root as Button
	if b != null:
		for c: Dictionary in b.pressed.get_connections():
			if (c.callable as Callable).get_method() == method:
				n += 1
	for c in root.get_children():
		n += _wired_to(c, method)
	return n


## The chassis select's grade buttons: a tier letter, and a tooltip naming the
## tier. The weight buttons beside them are single letters too.
func _tier_buttons(root: Node) -> int:
	var n := 0
	var b := root as Button
	if b != null and b.text in HullData.TIER_NAMES and b.tooltip_text.contains("tier"):
		n += 1
	for c in root.get_children():
		n += _tier_buttons(c)
	return n


func _drop(n: Node) -> void:
	n.queue_free()
	await _tree.process_frame


func _drop_file(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _drop_scratch() -> void:
	_drop_file(SCRATCH)
	_drop_file(HISTORY)


## Everything put back as Main left it, then torn down as `BindTest._finish`
## does: a headless run that quits holding a live Control tree reports leaks the
## gate reads as errors.
func _finish(boot_available: bool, boot_enabled: bool) -> void:
	Sig.dev_mode_changed.disconnect(_on_changed)
	_drop_scratch()
	DevMode.path = DevMode.PATH
	RunHistory.path = RunHistory.PATH
	DevMode.available = boot_available
	DevMode.enabled = boot_enabled
	_ok("the scratch files are gone",
		not FileAccess.file_exists(SCRATCH) and not FileAccess.file_exists(HISTORY))
	_holder.queue_free()
	if Router.current != null:
		var last := Router.current
		Router.current = null
		last.get_parent().remove_child(last)
		last.free()
	await _tree.process_frame
	print("")
	verdict("devtest")
	_tree.quit(code())
