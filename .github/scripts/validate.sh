#!/usr/bin/env bash
#
# Three Kelvin — everything that has to pass before a merge.
#
#   .github/scripts/validate.sh            # the full gate
#   SIM_RUNS=200 .github/scripts/validate.sh
#   GODOT=/path/to/Godot .github/scripts/validate.sh
#   LOG_DIR=./ci-logs .github/scripts/validate.sh
#
# CI runs this exact file, so a green pull request and a green laptop mean the
# same thing. Nothing in here is CI-specific: the workflow's only job is to
# install Godot and call this.
#
# The one thing worth knowing before editing: **Godot exits 0 even when a
# script fails to compile.** It prints the failure and carries on to the next
# resource. So every check below reads the OUTPUT rather than the exit status,
# and `run_godot` is the only place that logic lives.
#
# STEPS RUN SIDE BY SIDE. Serially the gate took about 42 minutes, nearly all of
# it Godot runs that wait on nothing but themselves. Each check is a `unit_*`
# function below, and the scheduler at the bottom runs them:
#
#   1. `import` first, alone: nothing compiles without the class cache it writes.
#   2. the pool, GATE_JOBS at once (default 6, fewer on a machine with fewer
#      cores), the longest first so the long tail starts early;
#   3. the SOLO units, one at a time after the pool: the steps that measure
#      wall-clock time, frame-to-frame motion or threads, which other processes
#      competing for the CPU could fail for reasons that are not the code's.
#
#   GATE_JOBS=1 .github/scripts/validate.sh   # one at a time, in file order
#
# Every unit runs in its own subshell with its OWN USER FOLDER: user:// is
# pointed at a scratch folder per unit (APPDATA on Windows, as tkg/tools/
# export.sh does; XDG_DATA_HOME and HOME on Linux and macOS), so no two units
# share settings, hints, saves or harness files, and no unit touches the
# machine's real profile. Each unit's output is held and printed whole, in file
# order, so the log reads as it did when the steps ran one after another. The
# summary lists every FAIL and the time each unit took.
#
# ADDING A STEP: write a `unit_<name>() { ... }` function anywhere among the
# others; it runs in the pool, in its file position for output. The function's
# name is all the scheduler needs. If the step times anything, add it to
# SOLO_UNITS; if it is long, give it a weight in `gate_weight` so it starts
# early. A unit sees only its own variables: anything two units both need is
# set once at the top of the file, before the units.

set -uo pipefail

GODOT="${GODOT:-godot}"
PROJECT="${PROJECT:-tkg}"
SIM_RUNS="${SIM_RUNS:-40}"
# Overridable so CI can put the logs somewhere it can upload from.
LOG_DIR="${LOG_DIR:-$(mktemp -d)}"
mkdir -p "$LOG_DIR"

FAIL=0
step()  { printf '\n\033[1m=== %s\033[0m\n' "$1"; }
ok()    { printf '  \033[32mok\033[0m    %s\n' "$1"; }
# A unit's FAILs are also written to its own list, for the summary at the end.
bad()   {
	printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=1
	if [ -n "${GATE_UNIT_DIR:-}" ]; then printf '%s\n' "$1" >>"$GATE_UNIT_DIR/fails"; fi
}

# The interpreter, found once for every unit. In one shell the steps used to
# hand it on: the audio step's `PY` was what the encounter and prose steps ran.
# A unit is its own subshell and inherits nothing from the unit before it, so
# the steps that only READ it get it from here.
PY=""
for candidate in python3 python; do
	if "$candidate" -c "" >/dev/null 2>&1; then
		PY="$candidate"
		break
	fi
done
RIPY="$PY"
VGPY="$PY"

# Anything Godot prints that means a script did not survive. `ERROR:` is in
# here deliberately: a null dereference at runtime prints one and nothing else,
# and a simulator that quietly errors through forty runs is worse than no
# simulator. If a benign one ever shows up, add it to ALLOW rather than
# loosening this.
ERROR_PATTERNS='SCRIPT ERROR|Parse Error|Compile Error|^ERROR:|^USER ERROR:'
ALLOW='^$'
# PER-STEP, NOT GLOBAL. Set `ALLOW_EXTRA` on the run_godot line that needs it:
#
#   ALLOW_EXTRA='...' run_godot stowtest 120 ...
#
# The first version of this put the exit-time leak messages straight into ALLOW,
# which is global — so a genuine leak introduced in `boot`, `savetest` or the
# simulator would have stopped failing the gate too. An allowance made for one
# step has to end at that step, or it is not an allowance, it is a hole.

# Run a command under a wall-clock limit. `timeout` is GNU coreutils and is not
# on a stock macOS, so this is done by hand: background it, poll, kill it if it
# outstays its welcome. Not optional — the first script that failed to compile
# left Godot wedged, and without this a pull request would have sat open for the
# runner's full six-hour limit instead of failing in three minutes.
#
# Under the scheduler the command gets the unit's own user folder (see the top
# of the file), set on the command itself so the PID polled and killed here is
# the program's, not a wrapper's. Its PID is written down too, so an
# interrupted gate can stop every Godot it started.
run_limited() {
	local limit="$1"; shift
	if [ -n "${GATE_USER_DIR:-}" ]; then
		APPDATA="$GATE_APPDATA" HOME="$GATE_USER_DIR" XDG_DATA_HOME="$GATE_USER_DIR/.local/share" \
			"$@" &
	else
		"$@" &
	fi
	local pid=$!
	if [ -n "${GATE_UNIT_DIR:-}" ]; then printf '%s\n' "$pid" >>"$GATE_UNIT_DIR/pids"; fi
	local waited=0
	while kill -0 "$pid" 2>/dev/null; do
		if [ "$waited" -ge "$limit" ]; then
			kill -9 "$pid" 2>/dev/null
			wait "$pid" 2>/dev/null
			return 124
		fi
		sleep 1
		waited=$((waited + 1))
	done
	wait "$pid"
}

run_godot() {
	local name="$1"; local limit="$2"; shift 2
	local log="$LOG_DIR/$name.log"
	run_limited "$limit" "$GODOT" "$@" >"$log" 2>&1
	local code=$?
	if [ $code -eq 124 ]; then
		bad "$name: still running after ${limit}s, killed"
		tail -n 25 "$log" | sed 's/^/        /'
		return 1
	fi
	if [ $code -ne 0 ]; then
		bad "$name: godot exited $code"
		tail -n 40 "$log" | sed 's/^/        /'
		return 1
	fi
	local hits
	hits="$(grep -nE "$ERROR_PATTERNS" "$log" \
		| grep -vE "${ALLOW}${ALLOW_EXTRA:+|$ALLOW_EXTRA}" || true)"
	if [ -n "$hits" ]; then
		bad "$name: godot reported script errors"
		printf '%s\n' "$hits" | head -n 40 | sed 's/^/        /'
		return 1
	fi
	ok "$name"
	return 0
}

unit_tabs() {
step "Indentation is tabs (Godot requires it)"
SPACE_INDENTED="$(grep -rln '^ ' --include='*.gd' "$PROJECT" || true)"
if [ -n "$SPACE_INDENTED" ]; then
	bad "space-indented GDScript:"
	printf '%s\n' "$SPACE_INDENTED" | sed 's/^/        /'
else
	ok "no space-indented .gd files"
fi
}

unit_import() {
step "Global class cache builds"
# REQUIRED before anything compiles at all: class_name registration lives in
# .godot/global_script_class_cache.cfg, which only --import writes, and .godot/
# is gitignored — so a fresh clone (which is what CI always is) has none.
run_godot import 420 --headless --path "$PROJECT" --import
}

unit_boot() {
step "Project boots and builds its UI"
# Not the simulator: this path constructs the theme, the HUD and a real screen,
# so it compiles the UI classes the simulator never touches. `gateboot` is no
# harness Main knows (it boots as normal) but marks the run as a test, so it
# reads and writes the harness settings, never the player's settings.cfg.
run_godot boot 240 --headless --path "$PROJECT" --quit-after 240 -- gateboot
}

unit_market() {
step "Market invariant holds and prices round-trip"
# Two checks the gate had no equivalent of, added with the economy they guard.
# Both fail SILENTLY in the running game, which is the only reason a check is
# worth its seconds: a market whose melt price creeps above its ask price does
# not crash, it pays for the rest of the run, and a save that drops a field
# does not crash either, it comes back as a default.
run_godot market 120 --headless --path "$PROJECT" -- market
if run_godot savetest 120 --headless --path "$PROJECT" -- savetest; then
	if grep -qE '^=== (PASS|FAIL)' "$LOG_DIR/savetest.log"; then
		if grep -qE '^=== FAIL' "$LOG_DIR/savetest.log"; then
			bad "save round-trip reported mismatches"
			grep -E 'MISMATCH|before:|after:|FAIL' "$LOG_DIR/savetest.log" \
				| head -n 40 | sed 's/^/        /'
		fi
	else
		bad "save round-trip never reached its verdict"
		tail -n 20 "$LOG_DIR/savetest.log" | sed 's/^/        /'
	fi
fi
# The market test prints its verdict the same way and reports no error line of
# its own, so the violations have to be read out of the log as well.
if grep -qE '^=== FAIL' "$LOG_DIR/market.log" 2>/dev/null; then
	bad "market invariant violated — a part can be bought and melted for profit"
	grep -E 'BUY-AND-MELT|SELL-BACK' "$LOG_DIR/market.log" | head -n 20 | sed 's/^/        /'
fi
}

unit_boardsigntest() {
step "SIGN on the Hiring Board changes its one note"
# Jon, Oct 22: "When you pick a quest from the hiring board... the whole hiring
# board resets." On the cork, the whiteboard and the screen: the signed note
# stays in place stamped SIGNED, every other note, the tab, the scatter, the
# listings, the popup and the lamp stay as they were, and no offer re-rolls.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot boardsigntest 120 --headless --path "$PROJECT" -- sheet=BoardSignTest; then
	if grep -qE '^boardsigntest: PASS' "$LOG_DIR/boardsigntest.log"; then
		ok "SIGN stamps its note in place and nothing else on the board moves"
	else
		bad "SIGN moved the Hiring Board's other notes or its scatter, or did not sign"
		grep -E 'FAIL|^boardsigntest' "$LOG_DIR/boardsigntest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "boardsigntest did not finish"
fi
}

unit_contracttest() {
step "Contracts, standing, and the salvage rail's dismissal rule"
# Three claims, and the middle one is the one no other step can make. `-- market`
# proves the price invariant at standing zero, which is the only standing it can
# reach; every price in the game is fine until a player delivers four contracts
# to one house and their berths start paying over the odds for parts. The last
# one is the salvage rail's dismissal rule, which is pure logic on `Run` and has
# been got wrong twice.
if run_godot contracttest 120 --headless --path "$PROJECT" -- contracttest; then
	if grep -qE '^contracttest: PASS' "$LOG_DIR/contracttest.log"; then
		ok "contracts"
	else
		bad "contract test failed"
		grep -E '^  FAIL|^contracttest' "$LOG_DIR/contracttest.log" | head -n 20 \
			| sed 's/^/        /'
	fi
fi
}

unit_stowtest() {
step "The salvage rail survives a jump"
# Driven through the REAL screen, because the rule has been wrong three times
# and the first of those was not about the rule at all — the flag lived on
# `SectorScreen`, which Router rebuilds on every jump. No assertion on the
# predicate can see that. This one presses the button, jumps, and checks the
# rail on the screen Router built afterwards.
# The two exit-time reports Godot emits when a headless run has had a Control
# tree in it: the process ends holding the theme's font. A statement about
# teardown, printed after the test's own verdict — and scoped to this line, so
# no other step stops failing on a real leak.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
		run_godot stowtest 120 --headless --path "$PROJECT" -- stowtest; then
	if grep -qE '^stowtest: PASS' "$LOG_DIR/stowtest.log"; then
		ok "stow"
	else
		bad "salvage rail test failed"
		grep -E '^  FAIL|^stowtest' "$LOG_DIR/stowtest.log" | head -n 20 \
			| sed 's/^/        /'
	fi
fi
}

unit_quittest() {
step "Leaving a run draws nothing without a ship"
# QUIT and SAVE & QUIT clear the hull and then swap to the title screen, and the
# screen they leave is still in the tree for the rest of that frame. The
# starchart redrew there once with no ship and logged hundreds of errors that no
# player ever saw, because the frame is never shown. The same leak allowance as
# stowtest, for the same reason: it builds real screens.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
		run_godot quittest 120 --headless --path "$PROJECT" -- quittest; then
	if grep -qE '^quittest: PASS' "$LOG_DIR/quittest.log"; then
		ok "quit"
	else
		bad "a screen drew after the run it belonged to was gone"
		grep -E '^  FAIL|^quittest' "$LOG_DIR/quittest.log" | head -n 20 \
			| sed 's/^/        /'
	fi
fi
}

unit_bindtest() {
step "Key bindings rebind, fire, persist and clash"
# Every key the game listens for is a binding (`Keys`), and a wrong default
# moves a key with nobody deciding to. Rebinds through Settings with real key
# events, presses the result on the ship screen, the star chart and Main's Tab,
# reloads the settings file, and checks the clash rules. In a scratch file, so
# the player's own settings are never touched. The same leak allowance as
# quittest: it builds real screens.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
		run_godot bindtest 120 --headless --path "$PROJECT" -- bindtest; then
	if grep -qE '^bindtest: PASS' "$LOG_DIR/bindtest.log"; then
		ok "keys"
	else
		bad "a key binding did not do what it said"
		grep -E '^  FAIL|^bindtest' "$LOG_DIR/bindtest.log" | head -n 20 \
			| sed 's/^/        /'
	fi
fi
}

unit_menutest() {
step "The escape menu still answers after the motion settings change"
# A menu opened under REDUCED MOTION and closed after it was turned off threw
# on the animated way out and stayed up, swallowing every click. Headless never
# animates, so this harness turns the animations on (`Router.animate_in_harness`)
# and walks the menu through each change. Same leak allowance as quittest.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
		run_godot menutest 120 --headless --path "$PROJECT" -- menutest; then
	if grep -qE '^menutest: PASS' "$LOG_DIR/menutest.log"; then
		ok "menu"
	else
		bad "the escape menu stopped answering"
		grep -E '^  FAIL|^menutest' "$LOG_DIR/menutest.log" | head -n 20 \
			| sed 's/^/        /'
	fi
fi
}

unit_devtest() {
step "Developer mode exists only in the editor"
# An exported game has no workshop: DevMode.available is the editor binary, so
# a friend's install gets no switch, no CARDS tab, no tier row, no star chart
# dev buttons and one manufacturer, whatever settings.cfg says. Both sides are
# checked from one scratch settings file that says [dev] enabled=true, the
# release side by forcing it and again by booting with `asrelease`, the flag
# that turns developer mode off in the editor. Never the player's own files.
for DEVRUN in devtest devtest_release; do
	DEVARGS="devtest"
	[ "$DEVRUN" = devtest_release ] && DEVARGS="devtest asrelease"
	# shellcheck disable=SC2086
	if run_godot "$DEVRUN" 120 --headless --path "$PROJECT" -- $DEVARGS; then
		if grep -qE '^devtest: PASS' "$LOG_DIR/$DEVRUN.log"; then
			ok "dev mode ($DEVARGS)"
		else
			bad "developer mode reached somewhere it should not ($DEVARGS)"
			grep -E '^  FAIL|^devtest' "$LOG_DIR/$DEVRUN.log" | head -n 20 \
				| sed 's/^/        /'
		fi
	fi
done
}

unit_holdtest() {
step "The hold never overlaps itself"
# Invisible in the data, which is the whole reason it is here. Two parts sharing
# a cell still add up to a sensible "17 of 28", still save and load, still sell
# for the right price — the only symptom is one plate drawn over another. Run
# against all three hulls because the grid is a property of the hull.
if run_godot holdtest 120 --headless --path "$PROJECT" -- holdtest; then
	if grep -qE '^holdtest: PASS' "$LOG_DIR/holdtest.log"; then
		ok "hold"
	else
		bad "the hold packing rule is broken"
		grep -E '^  FAIL|^holdtest' "$LOG_DIR/holdtest.log" | head -n 20 			| sed 's/^/        /'
	fi
fi
}

unit_transfertest() {
step "The container draws what the ship actually holds"
# THE VIEW, NOT THE MODEL. One bug was reported three times with three different
# triggers -- a drop, a right-click, a drag that looked refused -- and every time
# the model was already correct and the SCREEN had not been told. Every probe
# written to chase it asserted on `Run.cargo` and `n.bag`, which is the half that
# was never broken. This one counts icons, because an icon is what a player sees.
if run_godot transfertest 120 --headless --path "$PROJECT" -- transfertest; then
	if grep -qE '^transfertest: PASS' "$LOG_DIR/transfertest.log"; then
		ok "the container"
	else
		bad "the container and the hold disagree about what you are carrying"
		grep -E '^  FAIL|^transfertest' "$LOG_DIR/transfertest.log" | head -n 20 | sed 's/^/        /'
	fi
fi
}

unit_cutawaytest() {
step "The cutaway moves parts by the refit rule"
# LOCAL's cutaway is a third place a part can be moved and loot claimed, beside
# the refit screen and the map's SECTOR LOOT. It calls the same rule
# (`lift_part`, `fit_at_mount`, `stow_at`) and the same claims (`take_item`,
# `take_from_jetsam`), so the three cannot disagree; this drives its own drop
# handlers and counts what it draws, like the container check above. It ends
# on the real LOCAL (a wreck clicked through the cutaway, a fight), so it ends
# with the same exit-time teardown reports as stowtest, allowed the same way.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 		run_godot cutawaytest 180 --headless --path "$PROJECT" -- cutawaytest; then
	if grep -qE '^cutawaytest: PASS' "$LOG_DIR/cutawaytest.log"; then
		ok "the cutaway"
	else
		bad "the cutaway moves parts or claims loot outside the refit rule"
		grep -E '^  FAIL|^cutawaytest' "$LOG_DIR/cutawaytest.log" | head -n 20 | sed 's/^/        /'
	fi
fi
}

unit_subjecttest() {
step "Every encounter's subject is real art and fits LOCAL"
# An option's `subject` names pieces of art and how they are staged
# (`LocalSubject`). A misspelt piece draws nothing and says nothing, and a
# staging one tank too wide runs under the event's band or onto your ship; this
# resolves every piece against art/subjects/index.json and fits every staging to
# LOCAL's own view. It ends on the real LOCAL, so it ends with the same exit-time
# teardown reports as stowtest, allowed the same way.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 		run_godot subjecttest 180 --headless --path "$PROJECT" -- subjecttest; then
	if grep -qE '^subjecttest: PASS' "$LOG_DIR/subjecttest.log"; then
		ok "the subjects"
	else
		bad "an encounter's subject names art that is not there, or does not fit"
		grep -E '^  FAIL|^subjecttest' "$LOG_DIR/subjecttest.log" | head -n 20 | sed 's/^/        /'
	fi
fi
}

unit_moontest() {
step "LOCAL's moons keep out of what is staged"
# The moons of the world you orbit go round it (`LocalLife`). Jon: a moon must
# never pass over an event's subject, a station or your ship during the dock.
# On every world with moons in four galaxies (every station system's among
# them) each chosen orbit, run for ten minutes, keeps clear of your ship, the
# station's side and the dock's corridor; with a subject up, in a fight and
# through the dock every moon holds still. Ends on the real LOCAL and the
# station, so the same exit-time teardown reports as subjecttest are allowed.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot moontest 300 --headless --path "$PROJECT" -- sheet=MoonTest; then
	if grep -qE '^moontest: PASS' "$LOG_DIR/moontest.log"; then
		ok "the moons keep clear"
	else
		bad "a moon crosses a subject, a station or your ship, or moves while something is staged"
		grep -E '^  FAIL|^moontest' "$LOG_DIR/moontest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "moontest did not finish"
fi
}

unit_dockflytest() {
step "Leaving a station without UNDOCK leaves nothing of it behind"
# DOCK only at the station itself (Jon, Oct 18, "dock:A"): at the system's edge
# and at a world, no DOCK on LOCAL or the map, no station side, and the door
# refuses; flown to the station, DOCK is offered and docks.
# Docked, the ship flown off by the map (a world, the star, open space) and back
# to LOCAL by the HUD's tab and by Tab, and by the chart's JUMP and GO beyond it:
# LOCAL as after a proper UNDOCK (ship, zoom, the sky's place, no berth left,
# the ladder idle), and where UNDOCK refuses, the flight and the jump refuse too.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot dockflytest 300 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=DockFlyTest; then
	if grep -qE '^dockflytest: PASS' "$LOG_DIR/dockflytest.log"; then
		ok "every way off the berth undocks, or is refused"
	else
		bad "a way off the berth left the station behind"
		grep -E 'FAIL|^dockflytest' "$LOG_DIR/dockflytest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "dockflytest did not finish"
fi
}

unit_swaptest() {
step "A hull swap never strands the pad or shuts the station door"
# Jon, Oct 23, 0.4.1-alpha.1: "after swapping/upgrading my ship all the parts no
# longer appear for me to transfer and now i can no longer undock from a
# station". His own save (tools/fixtures/) loads with nothing lost and every
# mount valid, docks onto the move with every pad item drawn, and undocks once
# they are aboard. Then the yard's TAKE IT through Tab, another door and back,
# and SAVE AND EXIT/CONTINUE in one process; then a hull found in space, which
# opens the move, refuses Tab and the jump, and BACKs OUT onto the rail.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot swaptest 180 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=SwapTest; then
	if grep -qE '^swaptest: PASS' "$LOG_DIR/swaptest.log"; then
		ok "the pad is always shown, and the ship always leaves once it is empty"
	else
		bad "a hull swap can strand the pad or hold the ship"
		grep -E 'FAIL|^swaptest' "$LOG_DIR/swaptest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "swaptest did not finish"
fi
}

unit_derelicttest() {
step "The derelict hauler names its frame, and claiming it never costs the strip"
# Jeremy, friends' alpha: a heavy pilot claimed the hull blind, got a light frame,
# and had given up "Strip it for scrap" for it. On the real LOCAL at a light, a
# medium and a heavy frame, in all three layouts: the claim's card names the
# weight, the page passes the box test, YOU CHOSE names it, and the hull found is
# that one, the same with the loot stream moved and another seat. Then the
# frame's SCRAP on the rail (where LEAVE IT was) pays the strip's credits and
# crate, once, after a backed-out TRANSFER and a save and load; and on the map.
# A frame still on offer is paid, not lost, when a second claim or the yard's
# TAKE IT replaces it, and the log says its crate is in SECTOR LOOT. SCRAP +105
# fits the rail and the map; a VERSION 36 save's found hull keeps LEAVE IT.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot derelicttest 240 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=DerelictTest; then
	if grep -qE '^derelicttest: PASS' "$LOG_DIR/derelicttest.log"; then
		ok "the claim names its frame, and a frame not flown pays the strip"
	else
		bad "the derelict hauler hides its frame, or declining it loses the strip"
		grep -E 'FAIL|^derelicttest' "$LOG_DIR/derelicttest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "derelicttest did not finish"
fi
}

unit_orbitworldtest() {
step "LOCAL draws the world you orbit, close, from its first frame"
# Jon, Oct 21: "I want the planet you are orbiting to be large in the
# background (you are close to it)." Four seeds through the real doors with the
# ladder on: launch, every world of the start system, a jump on and a station's
# system flown to for the first time (FLY HERE, GO), LOCAL by the HUD's tab, by
# Tab and by GO, and CONTINUE: the sky's world on LOCAL's first frame is the one
# the ship orbits, at least the look's size, under your ship and clear of the
# HUD and the goal line; LOCAL pressed mid-arrival draws that world too.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot orbitworldtest 300 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=OrbitWorldTest; then
	if grep -qE '^orbitworldtest: PASS' "$LOG_DIR/orbitworldtest.log"; then
		ok "LOCAL draws the world you orbit, close"
	else
		bad "LOCAL drew the wrong world, none, or too small"
		grep -E 'FAIL|^orbitworldtest' "$LOG_DIR/orbitworldtest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "orbitworldtest did not finish"
fi
}

unit_fightlogtest() {
step "The fight log is hidden until LOG is pressed, and records all the same"
# Jon, Oct 18, "fightlog:hidden". From a used settings file: hidden by default,
# recording while hidden, LOG clicked shows every line and moves nothing that can
# be clicked, the choice kept in the settings file; and the box test, LOG and the
# open log against everything on the fight's screen in every hull and pack.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot fightlogtest 300 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=FightLogTest; then
	if grep -qE '^fightlogtest: PASS' "$LOG_DIR/fightlogtest.log"; then
		ok "the fight log hides, records, opens, and covers nothing"
	else
		bad "the fight log shows by default, loses lines, moves a control or covers something"
		grep -E 'FAIL|^fightlogtest' "$LOG_DIR/fightlogtest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "fightlogtest did not finish"
fi
}

unit_fightwordstest() {
step "The fight's and LOCAL's words say what the rules do"
# The tutorial audit, Oct 22: the status chips named by the card's keyword
# (NEGATE, GROWS, not SLIP and ADAPT), the DISCARD's tooltip naming the hand
# swept in at END TURN, and no dash in LOCAL's bar line anywhere in the galaxy.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot fightwordstest 180 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=FightWordsTest; then
	if grep -qE '^fightwordstest: PASS' "$LOG_DIR/fightwordstest.log"; then
		ok "the chips, the discard and the bar line say what the rules do"
	else
		bad "a chip, the discard's tooltip or the bar line says something the rules do not"
		grep -E 'FAIL|^fightwordstest' "$LOG_DIR/fightwordstest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "fightwordstest did not finish"
fi
}

unit_materialtest() {
step "Every material is a thing the hold can actually hold"
# `MaterialTable` authored 64 rows a day before anything could carry one, so its
# shapes had never met the grid that has to accept them. A row whose `cells`
# reads wider than the smallest hull's hold parses fine, builds fine, and can
# never be placed -- and nothing would say why. Checked against the LIGHTEST
# hull, because an item that fits a heavy and not a light vanishes for half the
# roster, quietly.
if run_godot materialtest 120 --headless --path "$PROJECT" -- materialtest; then
	if grep -qE '^materialtest: PASS' "$LOG_DIR/materialtest.log"; then
		ok "materials"
	else
		bad "a material cannot be carried"
		grep -E '^  FAIL|^ +refused|^materialtest' "$LOG_DIR/materialtest.log" | head -n 20 | sed 's/^/        /'
	fi
fi
}

unit_content() {
step "The catalogue export is a shape the manifest can read"
# NEITHER OF THESE WAS IN THE GATE AT ALL, which is how the export and the page
# drifted apart in silence. PASSIVE_AXIS values became arrays while the exporter
# still called String() on one; a gauge came out as the four characters
# ["hull"], the JSON stayed valid, the page kept rendering, and every gauge chip
# vanished. Nothing errored at either end â it was found by looking at a table
# that had gone blank.
#
# Both ends check now and both run here. The exporter vets its own rows against
# the vocabulary the GAME defines, and the page throws on a gauge it does not
# recognise rather than rendering an empty cell.
if run_godot content 120 --headless --path "$PROJECT" -- content json; then
	if grep -qE '^content: PASS' "$LOG_DIR/content.log"; then
		if command -v node >/dev/null 2>&1; then
			MANIFEST_OUT="$LOG_DIR/manifest.html"
			# (the export is in this unit's user folder, so the page is pointed
			# at the same one: manifest.mjs finds it by APPDATA or the home folder)
			if APPDATA="${GATE_APPDATA:-${APPDATA:-}}" HOME="${GATE_USER_DIR:-$HOME}" \
					node "$PROJECT/tools/manifest.mjs" "$MANIFEST_OUT" >"$LOG_DIR/manifest.log" 2>&1; then
				ok "export and manifest"
			else
				bad "the manifest refused the export"
				tail -n 12 "$LOG_DIR/manifest.log" | sed 's/^/        /'
			fi
		else
			ok "export (node absent, manifest not built)"
		fi
	else
		bad "the export carries rows the manifest cannot read"
		grep -E '^  FAIL|^content' "$LOG_DIR/content.log" | head -n 20 | sed 's/^/        /'
	fi
fi
}

unit_attrtest() {
step "A part moves the gauge its grade promised"
# The ladder converts a grade into pips, _lay_pips converts pips into whatever
# raw unit a gauge is kept in, and attr_* converts that back. Two ways the round
# trip breaks and neither throws: an int field rounding a fractional pip into
# two, and a retuned attr_ formula that PER_PIP was not told about. Either one
# silently puts a whole axis off the ladder on every hull in the game.
if run_godot attrtest 120 --headless --path "$PROJECT" -- attrtest; then
	if grep -qE '^attrtest: PASS' "$LOG_DIR/attrtest.log"; then
		ok "attribute ladder"
	else
		bad "a part does not move its gauge by what its grade promised"
		grep -E '^  FAIL|OFF' "$LOG_DIR/attrtest.log" \
			| head -n 20 | sed 's/^/        /'
	fi
fi
}

unit_maptest() {
step "Every galaxy can be crossed, and every enum still has its labels"
# NOT GATED UNTIL NOW, which is how MapTest lost its verdict line without
# anything noticing: it prints four results and nothing was reading them. It
# checks that a core exists, is reachable, and can be FLOWN to in 120 rolled
# galaxies -- three of the most expensive failures the generator can produce --
# plus that no label array has drifted from its enum. Since Oct 22 also the
# one-ring rule (`RunState.DEPTH_STEP`) and a sweep of 255 galaxies, 15 of every
# kind, flown one ring at a time by the slowest ship: ~130s alone, so 300.
if run_godot maptest 300 --headless --path "$PROJECT" -- maptest; then
	if grep -qE '^maptest: PASS' "$LOG_DIR/maptest.log"; then
		ok "every galaxy is crossable"
	else
		bad "a galaxy cannot be crossed, or a label array has drifted"
		grep -E '^  FAIL|^maptest' "$LOG_DIR/maptest.log" \
			| head -n 10 | sed 's/^/        /'
	fi
fi
}

unit_hinttest() {
step "Each first-run hint shows once, where it belongs"
# Hints watch the screens for their moment; each must fire once, sit clear of
# what it points at, never come back, and come back after SHOW HINTS AGAIN.
# Tutorial direction B (Oct 17): the ones a moment decides -- the intent after
# the first card, END TURN with nothing playable, brace held over a turn, heat
# risen, fuel short -- are held to not firing before it; the wreck's points at
# a wreck a click opens, never an event's derelict; the ship's waits for an
# idle LOCAL. Same exit-time leak allowance as stowtest.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot hinttest 300 --headless --path "$PROJECT" -- hinttest; then
	if grep -qE '^hinttest: PASS' "$LOG_DIR/hinttest.log"; then
		ok "hints show once, in place"
	else
		bad "a first-run hint misbehaved"
		grep -E 'FAIL|^hinttest' "$LOG_DIR/hinttest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "hinttest did not finish"
fi
}

unit_goaltest() {
step "The goal line: always the goal, the next step, never over anything"
# Tutorial direction B (Oct 17): GOAL: REACH THE CORE under the HUD, and the
# step while one is pending (open STARCHART and jump; click an event and GO),
# through a new run on LOCAL, the chart, the map, an event's band and a fight:
# box-tested against the HUD, the side bar, the toolbar row, the event band, the
# hand and every hull and its words; done steps never come back; not pressable.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot goaltest 180 --headless --path "$PROJECT" -- sheet=GoalTest; then
	if grep -qE '^goaltest: PASS' "$LOG_DIR/goaltest.log"; then
		ok "the goal line says the goal and the next step, clear of everything"
	else
		bad "the goal line is wrong or covers something"
		grep -E 'FAIL|^goaltest' "$LOG_DIR/goaltest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "goaltest did not finish"
fi
}

unit_questlogtest() {
step "The QUESTS tab: its table, SHOW ON STARCHART, PLOT ROUTE, nothing covered"
# Jon's design A (Oct 22): a QUESTS tab after STARCHART opens a table of the
# quests you hold; a row's SHOW ON STARCHART and PLOT ROUTE open the chart on
# its place, tagged, with its route. Three galaxies, the real screens: the tab's
# rect the same with 0, 1 and 5 held, the HUD row fitting with and without
# ARCHIVE, a row per quest with its fields, the chart's destination, tag and
# legal route, and the table and the tag box-tested.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot questlogtest 180 --headless --path "$PROJECT" -- sheet=QuestLogTest; then
	if grep -qE '^questlogtest: PASS' "$LOG_DIR/questlogtest.log"; then
		ok "the quests table: every quest, shown and routed on the chart, nothing covered"
	else
		bad "the quests table or its chart tag is wrong or covers something"
		grep -E 'FAIL|^questlogtest|^    ' "$LOG_DIR/questlogtest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "questlogtest did not finish"
fi
}

unit_fueltest() {
# The 45 tank (Jon, Oct 17: "fuel:A warn:A events:A"): the cap on every write
# and a refuel's top-up, the event floor and the 45-scale events, the fuel hint
# at a third of the tank naming the nearest dock in reach (against the test's
# own search), and the HUD's "FUEL [bar] 23/45" at full, a third and near empty:
# its colours with hints on and off, and the box test on LOCAL and the chart,
# dev mode on and off.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot fueltest 180 --headless --path "$PROJECT" -- sheet=FuelTest; then
	if grep -qE '^fueltest: PASS' "$LOG_DIR/fueltest.log"; then
		ok "the 45 tank: cap, event floor, the hint and its dock, the HUD readout"
	else
		bad "the fuel tank, its hint or its readout is wrong"
		grep -E 'FAIL|^fueltest' "$LOG_DIR/fueltest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "fueltest did not finish"
fi
}

unit_ashtest() {
step "A.S.H. speaks at her moments, within her limits, and never over anything"
# The ship's AI (Jon and Ashlee, Oct 17; docs/ash.md). Her thirty approved
# lines, character for character against docs/ash_lines.json; each moment fires
# its own (launch, a new hull, the hull failing, over the heat cap, a big haul,
# one more wreck, doubt); the quiet after a line, one line a fight, never during
# a drag or the enemy's turn; nothing after the ship is lost; hints win; her face
# 8 to 12 changes a second while she talks; and the box test on 65 screens, LOCAL
# and fights of one to three ships in every weight, against the HUD, the goal
# line, the hand, both ships and their words, plates, ovals and numbers.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot ashtest 600 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=AshTest; then
	if grep -qE '^ashtest: PASS' "$LOG_DIR/ashtest.log"; then
		ok "A.S.H. at her moments, within her limits, clear of everything"
	else
		bad "A.S.H. spoke out of turn, or over something"
		grep -E 'FAIL|^ashtest' "$LOG_DIR/ashtest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "ashtest did not finish"
fi
}

unit_ashtutortest() {
step "A.S.H. teaches: the hints in her corner, clear of everything, and the cards when she is off"
# Jon's tutorial A (Oct 17): each first-run hint said in her corner in his
# words with its subject outlined, the goal steps said as they start, on LOCAL,
# fights, the chart, the map and the station, over the cutaway, the band and a
# wreck's window; held until a click; a bark never over one; the box test on
# every screen against a list gathered by the test and the pictures' own hit
# tests; her switch off brings today's cards back; nothing in a party.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot ashtutortest 600 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=AshTutorTest; then
	if grep -qE '^ashtutortest: PASS' "$LOG_DIR/ashtutortest.log"; then
		ok "A.S.H. teaches every hint and step, clear of everything"
	else
		bad "A.S.H.'s teaching failed"
		grep -E 'FAIL|^ashtutortest' "$LOG_DIR/ashtutortest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "ashtutortest did not finish"
fi
}

unit_ashteachcosttest() {
step "A.S.H. teaching the chart costs a frame nothing"
# Jon, Oct 20: the chart "SUPER laggy and unresponsive" while she taught its
# list -- 840 ms a frame, her box's check asking every system at every 3 px.
# Every frame timed while she says the list's line and the step's on a
# 410-system chart, against the chart with her silent; and her check finds what
# the old point-by-point scan found. Times frames: one of SOLO_UNITS.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot ashteachcosttest 300 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=AshTeachCostTest; then
	if grep -qE '^AshTeachCostTest: PASS' "$LOG_DIR/ashteachcosttest.log"; then
		ok "her teaching on the chart costs a frame nothing"
	else
		bad "her teaching on the chart lags the game"
		grep -E 'FAIL|^AshTeachCostTest' "$LOG_DIR/ashteachcosttest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "ashteachcosttest did not finish"
fi
}

unit_maplagtest() {
step "The sector map's worlds keep up with a pan"
# Each world's picture sits on its place (its ring, label and beacons) on every
# frame of a pan; an ease that chased the place left it trailing by frames.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot maplagtest 180 --headless --path "$PROJECT" -- maplagtest; then
	if grep -qE '^maplagtest: PASS' "$LOG_DIR/maplagtest.log"; then
		ok "worlds keep up with the camera"
	else
		bad "a world's picture trails the camera"
		grep -E 'FAIL|^maplagtest' "$LOG_DIR/maplagtest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "maplagtest did not finish"
fi
}

unit_laddertest() {
step "One camera: every move between chart, map, LOCAL and station lands"
# Each seam's designs both ways, input mid-move, scroll past a zoom's end, a
# fight from the map, DOCK/UNDOCK, and the switch off giving a plain swap.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot laddertest 420 --headless --path "$PROJECT" -- sheet=LadderTest; then
	if grep -qE '^laddertest: PASS' "$LOG_DIR/laddertest.log"; then
		ok "every move lands where it should"
	else
		bad "a move between distances failed"
		grep -E 'FAIL|^laddertest' "$LOG_DIR/laddertest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "laddertest did not finish"
fi
}

unit_lowhulltest() {
step "Low hull: the edges, every text decoding worse as the hull falls, her voice breaking up"
# Jon's strong (Oct 20). Off above 30%, rising to 5%, nothing on screen moving,
# every scrambled letter read back as itself, the escape menu clean, reduced
# motion still; her voice's glitches inside her words and baked on a worker.
# SOLO: it times frames and the worker's bake.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot lowhulltest 300 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=LowHullTest; then
	if grep -qE '^LowHullTest: PASS' "$LOG_DIR/lowhulltest.log"; then
		ok "the low-hull warning rises as the hull falls and moves nothing"
	else
		bad "the low-hull warning failed a check"
		grep -E 'FAIL|^LowHullTest' "$LOG_DIR/lowhulltest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "lowhulltest did not finish"
fi
}

unit_calmladdertest() {
step "One motion: every hop between LOCAL, the map and the chart is the calm move"
# Jon's pick A (Oct 17). Every hop by tab, Tab and a rebound key, from a world's
# orbit and the system's edge, frame by frame at 60 fps: one ship on one
# straight line, no cut or one-frame swap, the side bar and toolbar still while
# the camera moves, the hop within 10% of its length, a press mid-move hurried
# and not lost, the goal line away for the move and back after it.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot calmladdertest 300 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=CalmLadderTest; then
	if grep -qE '^calmladdertest: PASS' "$LOG_DIR/calmladdertest.log"; then
		ok "every hop is one calm move about your ship"
	else
		bad "a hop between distances was not the calm move"
		grep -E 'FAIL|^calmladdertest' "$LOG_DIR/calmladdertest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "calmladdertest did not finish"
fi
}

unit_sidebartest() {
step "The side bar never goes blank between distances"
# Every hop with a side bar at one end (LOCAL, map, chart), frame by frame at
# 60 fps for every look of the swap: no frame with the side bar empty, a click
# on content not yet resolved eaten, and an instant swap headless and under
# reduced motion (Jon, Oct 13).
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot sidebartest 300 --headless --path "$PROJECT" -- sheet=SideBarTest; then
	if grep -qE '^sidebartest: PASS' "$LOG_DIR/sidebartest.log"; then
		ok "the side bar swaps in place, never blank"
	else
		bad "the side bar went blank or took a click it should not"
		grep -E 'FAIL|^sidebartest' "$LOG_DIR/sidebartest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "sidebartest did not finish"
fi
}

unit_deathpooltest() {
step "Ships and creatures die the ways Jon kept"
# Every kept death style reachable, the cut ones (E CHAIN, H SLICE) never
# played, ships and creatures never crossing, and a won fight's wrecks dying
# the way the fight chose, so LOCAL's wreck is the one the animation left.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot deathpooltest 120 --headless --path "$PROJECT" -- sheet=DeathPoolTest; then
	if grep -qE '^deathpooltest: PASS' "$LOG_DIR/deathpooltest.log"; then
		ok "every kept style is reachable and nothing crosses"
	else
		bad "a death style rolled where it should not"
		grep -E 'FAIL|^deathpooltest' "$LOG_DIR/deathpooltest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "deathpooltest did not finish"
fi
}

unit_popplacetest() {
step "Fight numbers sit on the hull's ink, and land above it"
# Jon, Oct 13 ("Pops: B"): a held card's number centred on the ship's ink both
# ways; a landing's pops centred across on the ink and wholly above its top.
# Every enemy picture and every player hull (manufacturer x weight), in a fight.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot popplacetest 240 --headless --path "$PROJECT" -- sheet=PopPlaceTest; then
	if grep -qE '^popplacetest: PASS' "$LOG_DIR/popplacetest.log"; then
		ok "previews on the ink, pops above it, on every hull"
	else
		bad "a fight number is off its hull"
		grep -E 'FAIL|^popplacetest' "$LOG_DIR/popplacetest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "popplacetest did not finish"
fi
}

unit_hitfxlivetest() {
step "Hits, block and brace drawn on every ship in a fight"
# Through the real screen, a pack of three: each ship carries its hit marks, the
# bubble for block and the plated overlay for brace; every kind of landing
# makes its visual (soak, fizzle, armour taking it and shedding, a mark); a
# kill's wreck keeps its marks, in the slot and on LOCAL.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot hitfxlivetest 120 --headless --path "$PROJECT" -- sheet=HitFxLiveTest; then
	if grep -qE '^hitfxlivetest: PASS' "$LOG_DIR/hitfxlivetest.log"; then
		ok "every landing draws, and the wreck keeps its marks"
	else
		bad "a hit, the bubble or the armour did not draw"
		grep -E 'FAIL|^hitfxlivetest' "$LOG_DIR/hitfxlivetest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "hitfxlivetest did not finish"
fi
}

unit_hulldamagetest() {
step "Hull damage looks leave no holes"
# James, a playtester (Oct 17): ships get big holes in them, and ships can't
# have holes. Jon picked D (A+B+C mixed per hit, `HullHitFx`), the game's; A, B
# and C are its parts. Each on a light, a dark and a white hull at both sheet
# sizes: no near-black blob, every mark on the hull's own pixels in its own
# colours (or burnt metal), every glow the heat ramp's and changing shape 8-12
# times a second, the same seed the same marks, more marks as the hull goes, D
# quieter than the older marks; then the real fight, D the default on every
# ship but the Custodian (the older marks).
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot hulldamagetest 300 --headless --path "$PROJECT" -- sheet=HullDamageTest; then
	if grep -qE '^hulldamagetest: PASS' "$LOG_DIR/hulldamagetest.log"; then
		ok "no holes, on the hull, in its colours, glows that move"
	else
		bad "a hull damage look broke one of its rules"
		grep -E 'FAIL|^hulldamagetest' "$LOG_DIR/hulldamagetest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "hulldamagetest did not finish"
fi
}

unit_gameclocktest() {
step "The bobs run on game time, not the wall's"
# Jon, Oct 13, of the full fight films: "the hovering animation is REALLY fast".
# The movie writer steps 1/60 s a frame however long a frame takes to write, so
# the wall's clock raced (the cutter's bob at 0.375 s a cycle, not 4.76). In a
# real fight of three: time stopped with the wall running, no bob moves; time
# at 20x, every bob goes top to bottom; a slot made later bobs in step with the
# first; `ShipView.shot_clock` still drives your ship.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot gameclocktest 120 --headless --path "$PROJECT" -- sheet=GameClockTest; then
	if grep -qE '^gameclocktest: PASS' "$LOG_DIR/gameclocktest.log"; then
		ok "the bobs keep game time, in step"
	else
		bad "a bob ran on the wall's clock, or out of step"
		grep -E 'FAIL|^gameclocktest' "$LOG_DIR/gameclocktest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "gameclocktest did not finish"
fi
}

unit_fightopentest() {
step "A fight opens by easing up out of LOCAL, not with a pop"
# Jon, Oct 13: "When the enemy ship enters.... the ships pop up and the drawer
# pops into view.... can we have the opposite of the fight ending screen".
# Animated headless at 60 fps, through the real screens: the core's ENGAGE, an
# event's THEY ARE FIRING, a pack of three started on LOCAL, and an ambush met
# on arrival. Every frame: nothing (your ship, plate, bands, rails, each
# contact's box, readout and intent) jumps over 10 px or pops in or out, no
# frame is faded dark, nothing overlaps the rising band, no card / END TURN /
# FLEE / HAIL / pile takes a click before the band settles (and they do after);
# an ambush keeps its contacts and hand until your ship has arrived.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot fightopentest 180 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=FightOpenTest; then
	if grep -qE '^fightopentest: PASS' "$LOG_DIR/fightopentest.log"; then
		ok "the fight's hand comes up out of LOCAL, eased, and takes no early click"
	else
		bad "a fight's opening jumped, popped, went dark or took an early click"
		grep -E 'FAIL|^fightopentest' "$LOG_DIR/fightopentest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "fightopentest did not finish"
fi
}

unit_playerdeathtest() {
step "Dying: your ship breaks up, a beat on the wreck, then the run's screen"
# Jon, Oct 13: "When you die... let's have your ship crack and explode... pause
# for a beat... then the run ended popup shows up." The same fight twice from
# one seed, 5 hull into Strafe 5 through END TURN: animated, the hull comes
# apart (a ship style, boss length, mirrored for a right-facing ship, over the
# hull, the explosion after the break) and RUN ENDED waits for it and the hold;
# without motion, RUN ENDED at once; the run left behind identical both ways.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot playerdeathtest 180 --headless --path "$PROJECT" -- sheet=PlayerDeathTest; then
	if grep -qE '^playerdeathtest: PASS' "$LOG_DIR/playerdeathtest.log"; then
		ok "your ship breaks up before the run ends, and the run is the same"
	else
		bad "the death's breakup or its timing failed"
		grep -E 'FAIL|^playerdeathtest' "$LOG_DIR/playerdeathtest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "playerdeathtest did not finish"
fi
}

unit_corewintest() {
step "Beating the core's boss: its body looted, then the win screen"
# Jon, Oct 12: the custodian's body lootable, then a win popup with the death
# screen's music. ENGAGE at the core, the custodian killed through the real
# fight: the body open with its loot and no win screen yet, the run recorded as
# won, DONE / Escape / any other door ending on the win screen (Jon's note whole,
# the stats, TITLE, &"gameover"); an ordinary fight won never comes near it.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot corewintest 180 --headless --path "$PROJECT" -- sheet=CoreWinTest; then
	if grep -qE '^corewintest: PASS' "$LOG_DIR/corewintest.log"; then
		ok "the core's win loots the body, then ends the run"
	else
		bad "the core's win flow failed"
		grep -E 'FAIL|^corewintest' "$LOG_DIR/corewintest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "corewintest did not finish"
fi
}

unit_wreckloottest() {
step "Each wreck holds its own ship's loot"
# Jon, Oct 13: "Each ship you kill has a chance to get credits and modules and
# other parts." Every wreck holds its own template's roll at its own place; the
# credit chance and amount stay in bounds over thousands of wrecks; a two-ship
# fight pays about the sum of its ships; three seats with their streams apart
# roll identical wrecks, sized for the crew; a save keeps every wreck.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot wreckloottest 240 --headless --path "$PROJECT" -- sheet=WreckLootTest; then
	if grep -qE '^wreckloottest: PASS' "$LOG_DIR/wreckloottest.log"; then
		ok "every wreck pays its own ship, the same on every machine"
	else
		bad "a wreck's loot is not its own ship's, or not the same everywhere"
		grep -E 'FAIL|^wreckloottest' "$LOG_DIR/wreckloottest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "wreckloottest did not finish"
fi
}

unit_lockedpooltest() {
step "A locked manufacturer appears nowhere"
# Jon, Oct 20: "Solari things should NOT show up in the game until Solari is
# unlocked (win the game once)." Over seeded galaxies, every wreck, kill bag,
# shelf, yard hull, derelict hull, event part, relic analysis, contract item
# and the custodian's body: a fresh profile finds Korvan and unbranded only and
# every roll still rolls something; a Korvan win finds Solari too; developer
# mode finds it; a save keeps its pool across CONTINUE; a party rolls the host's.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot lockedpooltest 240 --headless --path "$PROJECT" -- sheet=LockedPoolTest; then
	if grep -qE '^lockedpooltest: PASS' "$LOG_DIR/lockedpooltest.log"; then
		ok "a manufacturer appears only once it is unlocked"
	else
		bad "a locked manufacturer's part or hull reached a player, or a pool ran dry"
		grep -E 'FAIL|^lockedpooltest' "$LOG_DIR/lockedpooltest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "lockedpooltest did not finish"
fi
}

unit_deeploottest() {
step "Going deep pays: material gates are module gates, no commons past halfway"
# Jon, Oct 22: a hard game where going deep is worth it. Materials read danger
# through MapGen.tier with LootGen's own gates (they compared tier numbers to
# raw danger and opened Epic, Legendary and Artifact twice as shallow), and from
# tier 3 no source rolls a COMMON module or material -- wrecks, bags, derelicts,
# event parts, relic analysis, shelves, the custodian, every material table --
# while a pool the rule would empty falls back to its own commons.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot deeploottest 240 --headless --path "$PROJECT" -- sheet=DeepLootTest; then
	if grep -qE '^deeploottest: PASS' "$LOG_DIR/deeploottest.log"; then
		ok "materials gate like modules, and nothing common rolls deep"
	else
		bad "a material opens shallower than its module, or a common rolled deep"
		grep -E 'FAIL|^deeploottest' "$LOG_DIR/deeploottest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "deeploottest did not finish"
fi
}

unit_wrecksitetest() {
step "Each place in a system keeps its own wrecks"
# Jon, Oct 14: "each planet or POI you can visit should contain its own
# wrecks/fights." A wreck lies where your ship was when it died (Jetsam.site);
# LOCAL draws that place's wrecks and no other's, each with its own death and
# marks; a save keeps the place, and an older save's wrecks show everywhere.
# Jon, Oct 15: what is left in a wreck you have opened is under SECTOR LOOT too,
# from anywhere in the system, claimed as the wreck's own.
# Jon, Oct 17: "fix destroyed ships from going on top of you when you edit your
# ship after a fight" -- every door off LOCAL and back (the cutaway with a part
# moved in it was the one) leaves the wrecks where they lay, off your hull; and
# "destroyed ships still show up in other systems" -- a real jump draws none.
# Fit means nothing overlaps: no wreck's words on the world you orbit, and no
# wreck's picture on it while the pile is a fight's worth.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit|were leaked at exit' \
	run_godot wrecksitetest 180 --headless --path "$PROJECT" -- sheet=WreckSiteTest; then
	if grep -qE '^wrecksitetest: PASS' "$LOG_DIR/wrecksitetest.log"; then
		ok "a world keeps its wrecks, the next one and the next system have none, and they stay off your hull"
	else
		bad "a wreck shows at a place it did not die at, or on your hull"
		grep -E 'FAIL|^wrecksitetest' "$LOG_DIR/wrecksitetest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "wrecksitetest did not finish"
fi
}

unit_arriveidletest() {
step "A new run's arrival: the engines sputter to the idle, no highlight"
# Jon, Oct 13: "I don't want the engines to turn off... I just want them to
# sputter to an idle. No highlight." LOCAL launched as the hull pick launches
# it, stepped a frame at a time: the flame never fully off from the clean burn
# to the idle, the cutaway outline never lit by the ship coming to rest, and a
# pointer left where it parked does not light it.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot arriveidletest 180 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=ArriveIdleTest; then
	if grep -qE '^arriveidletest: PASS' "$LOG_DIR/arriveidletest.log"; then
		ok "the arrival sputters to the idle, never off, no highlight"
	else
		bad "the arrival's engines or highlight are wrong"
		grep -E 'FAIL|^arriveidletest' "$LOG_DIR/arriveidletest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "arriveidletest did not finish"
fi
}

unit_banddroptest() {
step "The event band drops without a jump"
# It moved up to 29 px a frame on a middle-length event (a cubic ease-in ends at
# three times its average speed). LOCAL's band opened on the shortest, a middle
# and the longest event, NOT NOW pressed, and its top edge measured every frame
# of the drop: never over LocalEventDrawer.DROP_MAX_PX, and gone at the end.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot banddroptest 180 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=BandDropTest; then
	if grep -qE '^banddroptest: PASS' "$LOG_DIR/banddroptest.log"; then
		ok "the band drops under ten pixels a frame"
	else
		bad "the band jumps as it drops"
		grep -E 'FAIL' "$LOG_DIR/banddroptest.log" | sed 's/^/        /'
	fi
fi
}

unit_outcometest() {
step "An event's result says what you end up with"
# OutcomeRow's six looks (today, A big, B a ledger, C flown to the HUD, D a
# table over the buttons, E that table and the things you got drawn big) on the
# real LOCAL with the HUD: the real outcomes OutcomeCheck finds (Jon's lifepod,
# credits and a part, credits and fuel, a part alone, nothing, credits alone,
# the most changes), the numbers the run moved said in every look and layout, every
# entry box-tested against the band, the buttons and the text, CONTINUE where
# today's look has it; then C animated and under reduced motion: the HUD holds
# its old number until the flight lands, flickers, and nothing pressable moves.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot outcometest 240 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=OutcomeTest; then
	if grep -qE '^outcometest: PASS' "$LOG_DIR/outcometest.log"; then
		ok "every look says what moved, fits, and C flies without moving a button"
	else
		bad "an event's result misstates or overlaps what you end up with"
		grep -E 'FAIL' "$LOG_DIR/outcometest.log" | head -n 12 | sed 's/^/        /'
	fi
fi
}

unit_rewardshowntest() {
step "A result that gave you something to take shows REWARD"
# Every option, every choice, every band of a checked one (SkillCheck.forced),
# through LOCAL's event band: what landed on the system's pile, read off the
# run, has REWARD on the result, and nothing else does; nothing that paid out
# skips its result; CONTINUE past an unopened REWARD leaves it under SECTOR
# LOOT; the quest events are in the sweep. REWARD was keyed on `module` alone
# and 160 material outcomes said CONTINUE (Jon, Oct 22).
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot rewardshowntest 300 --headless --path "$PROJECT" -- sheet=RewardShownTest; then
	if grep -qE '^rewardshowntest: PASS' "$LOG_DIR/rewardshowntest.log"; then
		ok "every outcome that put something on the pile shows REWARD"
	else
		bad "an event paid into SECTOR LOOT with no REWARD on its result"
		grep -E 'FAIL' "$LOG_DIR/rewardshowntest.log" | head -n 12 | sed 's/^/        /'
	fi
fi
}

unit_gradesheet() {
step "A graded hull keeps its palette"
# HullGrade bakes each weight's one hull at C, B, A and S (Jon's AB+DEF) and
# may only use colours the sprite already has, plus the manufacturer's band
# ramp; the lights are additive and drawn apart. Each weight on the base
# DB.GRADE_BASE names.
for wb in light:c medium:a heavy:a; do
	w="${wb%%:*}"; b="${wb##*:}"
	if run_godot "gradesheet_$w" 180 --headless --path "$PROJECT" -- sheet=GradeSheet weight="$w" base="$b" out="$LOG_DIR/gradesheet_$w"; then
		if grep -qE '^gradesheet: PASS' "$LOG_DIR/gradesheet_$w.log"; then
			ok "the $w hull's grades use only its own colours"
		else
			bad "a graded $w hull drew a colour it does not have"
			grep -E 'colours not in the base' "$LOG_DIR/gradesheet_$w.log" | grep -v ': 0 colours' | sed 's/^/        /'
		fi
	fi
done
}

unit_idlesoundtest() {
step "Your idle engines are heard exactly while the idle flame is seen"
# Jon, Oct 13: "Let's have a low burn sound for the idle engines". Audio is off
# headless, but its decision (`Audio.idle_want`) and fade are not: silent
# through the arrival's clean burn, up from the first gap, full when parked;
# down in a hyperdrive's dark, a departure, hidden or off screen; heard in a
# fight, on the refit and on the transfer's new hull; silent on the chart; one
# view only, yours.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot idlesoundtest 180 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=IdleSoundTest; then
	if grep -qE '^idlesoundtest: PASS' "$LOG_DIR/idlesoundtest.log"; then
		ok "the idle bed follows the idle flame"
	else
		bad "the idle bed does not follow the idle flame"
		grep -E 'FAIL|^idlesoundtest' "$LOG_DIR/idlesoundtest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "idlesoundtest did not finish"
fi
}

unit_soundmomenttest() {
step "October's effects are heard, once, on the frame each picture acts"
# The free half of the Oct 17 sound plan (`Audio.FX`, one switchable row a
# moment). Audio is off headless, but while it tapes it makes every decision
# (limits, suppression, the pick, the caps) and writes it down: through the real
# fights, deaths, your ship's loss and the ladder, each picture's own `moment`
# against what was heard -- the band, plates on and off, a hit partly taken,
# vents and their sputters, deaths G, N, O, P, the Hellbender's furnace and pops,
# C1c's split, power_off and no page click into RUN ENDED, the chrome sliding
# and the side bar's decode.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot soundmomenttest 300 --headless --fixed-fps 60 --path "$PROJECT" -- sheet=SoundMomentTest; then
	if grep -qE '^soundmomenttest: PASS' "$LOG_DIR/soundmomenttest.log"; then
		ok "every moment's sound plays once, on its frame, at its level"
	else
		bad "a moment's sound is missing, doubled, early or late"
		grep -E 'FAIL|^soundmomenttest' "$LOG_DIR/soundmomenttest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "soundmomenttest did not finish"
fi
}

unit_welcometest() {
step "Jon's welcome note: once per profile, and on the title menu"
# Opens by itself on a fresh profile's title, word for word and inside the
# screen; marked seen only when CLOSED; never again after; MESSAGE FROM JON
# above QUIT opens it again. Then a first launch (Oct 17): NEW RUN on a fresh
# profile goes straight to the hull pick, no seed panel (it stays with a save),
# and LAUNCH lands on LOCAL with no tour. `welcome` lets it run under the
# harness, in its own scratch settings.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot welcometest 120 --headless --path "$PROJECT" -- sheet=WelcomeTest welcome; then
	if grep -qE '^welcometest: PASS' "$LOG_DIR/welcometest.log"; then
		ok "the welcome note shows once and comes back from the menu"
	else
		bad "the welcome note failed"
		grep -E 'FAIL|^welcometest' "$LOG_DIR/welcometest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "welcometest did not finish"
fi
}

unit_scrollcheck() {
step "No scroll bar on the sector map's panel covers a word"
# Jon, Oct 20, on the WORLD card: "the scroll bar covers up text". Over the
# run's first 40 systems, the sector's list and every world's page, unscrolled
# and scrolled to the end: no text and nothing that takes the mouse within
# UITheme.BAR_GAP of the bar as drawn. It fails if no page scrolled at all.
if run_godot scrollcheck 240 --headless --path "$PROJECT" -- sheet=SystemShot scrollcheck; then
	if grep -qE '^scrollcheck: PASS' "$LOG_DIR/scrollcheck.log"; then
		ok "the sector panel's words stay clear of its scroll bar"
	else
		bad "something on the sector panel sits under its scroll bar"
		grep -E 'FAIL|^scrollcheck|  scrollcheck' "$LOG_DIR/scrollcheck.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "scrollcheck did not finish"
fi
}

unit_yardseattest() {
step "Every hull sits on its yard stands, centred"
# Jon: "The ship needs to sit lower. Like actually be on the stands and centered
# on them." Every hull frame at every grade on every level's stands, measured
# off the pictures: no floor between belly and cap, resting on the cap's seat
# row, the stands' middle within 1 px of the hull's mass middle, one height.
if run_godot yardseattest 120 --headless --path "$PROJECT" -- sheet=YardSeatTest; then
	if grep -qE '^yardseattest: PASS' "$LOG_DIR/yardseattest.log"; then
		ok "every hull on its stands"
	else
		bad "a hull floats over, or stands off the middle of, its yard stands"
		grep -E 'FAIL|^yardseattest' "$LOG_DIR/yardseattest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "yardseattest did not finish"
fi
}

unit_enemyarttest() {
step "Every enemy wears Jon's kept ships, and every pack fits"
# The enemies are kept PixelLab ships (`art/sprites/enemies`, from
# `tools/enemy_sprites.py`): every kind names one, every picture loads, fits the
# canvas, is hard-edged and is what EnemyArt draws with nothing else on the
# canvas; a fight's pictures are positional (the same fight, the same galaxy,
# the same ships; all three of a kind turn up), go into its wrecks and survive
# the save; and every pair a fight can roll, in every combination of pictures,
# stays on screen without moving your ship or sitting on it.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot enemyarttest 300 --headless --path "$PROJECT" -- sheet=EnemyArtTest; then
	if grep -qE '^enemyarttest: PASS' "$LOG_DIR/enemyarttest.log"; then
		ok "$(grep -E '^enemyarttest: [0-9]+ kinds' "$LOG_DIR/enemyarttest.log" | head -n 1 | sed 's/^enemyarttest: //'), every pack on screen"
	else
		bad "an enemy is missing its picture, changes picture, or a pack runs off screen"
		grep -E 'FAIL|^enemyarttest' "$LOG_DIR/enemyarttest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "enemyarttest did not finish"
fi
}

unit_fightcounttest() {
step "Nothing joins a fight"
# Jon: "No reinforcements anywhere." Every kind, alone and in a pack, over
# seeded fights at a lawless danger-5 system played to turn 7: the enemy
# count never rises, and the Custodian and the Hellbender stand alone.
# 480 s: 168 fights take ~310 s on a slow container (Oct 15), on main as on this branch.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot fightcounttest 480 --headless --path "$PROJECT" -- sheet=FightCountTest; then
	if grep -qE '^fightcounttest: PASS' "$LOG_DIR/fightcounttest.log"; then
		ok "$(grep -E '^fightcounttest: [0-9]+ fights' "$LOG_DIR/fightcounttest.log" | head -n 1 | sed 's/^fightcounttest: //')"
	else
		bad "a ship joined a fight"
		grep -E 'FAIL|^fightcounttest' "$LOG_DIR/fightcounttest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "fightcounttest did not finish"
fi
}

unit_killholdtest() {
step "A kill moves nothing"
# Jon: "The enemy dips down and then pops up after the death animation?" A
# seeded pack of three (half) and a pair (full size), the first ship killed
# with the animations on: no slot or resting place moves from the kill to a
# second after the breakup, the breakup stands where the ship rests, and its
# last frame is the wreck the slot draws, pixel for pixel.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot killholdtest 180 --headless --path "$PROJECT" -- sheet=KillHoldTest; then
	if grep -qE '^killholdtest: PASS' "$LOG_DIR/killholdtest.log"; then
		ok "a kill leaves the pack where it stood"
	else
		bad "a kill moved the pack, or the breakup and its wreck disagree"
		grep -E 'FAIL|^killholdtest' "$LOG_DIR/killholdtest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "killholdtest did not finish"
fi
}

unit_packlayouttest() {
step "Nothing in a fight sits on anything else"
# Jon, on three enemies piled on each other: no ship, wreck, name, hull bar,
# chips or intent may overlap another enemy's, or yours. Every pair and triple
# of the pictures a fight can bring, every triple with a wreck in it, and
# LOCAL's rows of up to twelve wrecks, in the formation (B, the game's) and the
# column (C): three or more blocks drawn from their half sheets, every box
# apart, inside the view, your ship where it stood; each fighting ship's shield
# oval clear of its words, name, bars and chips and of every other block (Jon,
# "shield:A"); in B the gaps across a rank even (within 4 px at 1080p), the
# gaps between ranks even, every gap at least 24 px.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot packlayouttest 420 --headless --path "$PROJECT" -- sheet=PackLayoutTest; then
	if grep -qE '^packlayouttest: PASS' "$LOG_DIR/packlayouttest.log"; then
		ok "$(grep -cE '^packlayouttest: layout' "$LOG_DIR/packlayouttest.log") layouts, every pack apart"
	else
		bad "something in a fight sits on something else"
		grep -E 'FAIL|^packlayouttest' "$LOG_DIR/packlayouttest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "packlayouttest did not finish"
fi
}

unit_oneholetest() {
step "One black hole at the core, one pulsar at a pulsar"
# LOCAL's sky draws the system's own star; the encounter's place picture must
# not draw the core's hole or a pulsar a second time (Jon, Oct 13: "why are
# there two black holes"). Every other system keeps its place picture.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot oneholetest 120 --headless --path "$PROJECT" -- sheet=OneHoleTest; then
	if grep -qE '^oneholetest: PASS' "$LOG_DIR/oneholetest.log"; then
		ok "the core and the pulsars are drawn once, every other place keeps its picture"
	else
		bad "a star is drawn twice on LOCAL, or a place lost its picture"
		grep -E 'FAIL|^oneholetest' "$LOG_DIR/oneholetest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "oneholetest did not finish"
fi
}

unit_faunatest() {
step "The Custodian and the megafauna move, and are still for their deaths"
# FaunaMotion, headless: the cut at full size and from a half sheet, idle,
# the wind-up, and settle() at rest in four frames on the picture it was cut
# from; then the real fight, animated, on each of the three: the art hands its
# picture to the motion, the bob is the motion's, Charging and a creature's
# strike wind it up, a kill is at rest when the breakup is cut, and the dead
# slot is the art's wreck again. Reduced motion has none of it.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot faunatest 300 --headless --path "$PROJECT" -- sheet=FaunaTest; then
	if grep -qE '^faunatest: PASS' "$LOG_DIR/faunatest.log"; then
		ok "the three move, wind up and come to rest for their deaths"
	else
		bad "a creature's or the Custodian's motion is wrong"
		grep -E 'FAIL|^faunatest' "$LOG_DIR/faunatest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "faunatest did not finish"
fi
}

unit_threadstress() {
step "Worker threads make no textures, nodes or materials"
# The fight's off-thread cuts (a creature's or the Custodian's motion, a
# breakup ahead of a kill, a wreck) run back to back for 20 s while the main
# thread loads card art and makes textures: no engine error at all. Before
# Oct 14 the cuts made their textures on the worker and raced the main
# thread's (26 errors in 20 s here; faunatest's rare "wrong RID").
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot threadstress 120 --headless --path "$PROJECT" -- sheet=ThreadStress secs=20; then
	if grep -qE '^threadstress: PASS' "$LOG_DIR/threadstress.log"; then
		ok "the cuts run on workers beside the main thread's textures without a race"
	else
		bad "an off-thread cut raced the main thread's textures"
		grep -E 'error:|^threadstress' "$LOG_DIR/threadstress.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "threadstress did not finish"
fi
}

unit_localeventtest() {
step "Every event opens and resolves on LOCAL"
# The one place a choice is taken now: LOCAL's event band. Every authored
# option is opened and every choice resolved through it, in all three layouts.
if run_godot localeventtest 300 --headless --path "$PROJECT" -- localeventtest; then
	if grep -qE '^localeventtest: PASS' "$LOG_DIR/localeventtest.log"; then
		ok "every event resolves on LOCAL"
	else
		bad "an event failed to open or resolve on LOCAL"
		grep -E 'FAIL|^localeventtest' "$LOG_DIR/localeventtest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "localeventtest did not finish"
fi
}

unit_optiontest() {
step "The option table rolls a legal system every time"
# Also never gated, and it is the only thing checking the content that landed
# tonight: 42 options, unique ids, every rolled option admitted by its own gate,
# counts and groups inside the tier plan, and no system left with nothing to do.
if run_godot optiontest 180 --headless --path "$PROJECT" -- optiontest; then
	if grep -qE '^optiontest: PASS' "$LOG_DIR/optiontest.log"; then
		ok "options roll legally"
	else
		bad "the option table rolled something illegal"
		grep -E '^  FAIL|^optiontest' "$LOG_DIR/optiontest.log" \
			| head -n 12 | sed 's/^/        /'
	fi
fi
}

unit_foetagtest() {
step "An event's fight brings what its text set up"
# Jon, Oct 17: an event's fight may bring a creature, but only when the text
# before it is about that creature. Every `foe` tag names a creature, sits on a
# fauna-gated event that fights and whose body names it; no untagged fight
# follows creature text; over 24 galaxies every event fight brings a creature
# exactly when tagged, and a build that drops the tag or takes creatures from
# the region is caught; the real LOCAL band opens the tagged creature.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot foetagtest 300 --headless --path "$PROJECT" -- sheet=FoeTagTest; then
	if grep -qE '^foetagtest: PASS' "$LOG_DIR/foetagtest.log"; then
		ok "$(grep -E 'fight choices asked' "$LOG_DIR/foetagtest.log" | head -n 1 | sed 's/^ *//')"
	else
		bad "an event's fight brought something its text did not set up"
		grep -E 'FAIL|^foetagtest' "$LOG_DIR/foetagtest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "foetagtest did not finish"
fi
}

unit_systemtest() {
step "Every system lays out its map with every option on a body"
# SystemLayout is derived and never saved, so what it gets wrong is wrong
# silently: an option with no body is an encounter nobody can click, an
# unstable layout moves a planet between a save and a load, and an orbit run
# through a body draws one world on top of another.
if run_godot systemtest 180 --headless --path "$PROJECT" -- systemtest; then
	if grep -qE '^systemtest: PASS' "$LOG_DIR/systemtest.log"; then
		ok "every system lays out cleanly"
	else
		bad "a system laid out wrong"
		grep -E '^  FAIL|^systemtest' "$LOG_DIR/systemtest.log" \
			| head -n 12 | sed 's/^/        /'
	fi
fi
}

unit_weathertest() {
step "The sector map's weather keeps its schedule"
# The weather's scheduler alone (`SkyWeather`), two hours of every sky at every
# temperament with no picture: one event at a time, showpieces rare, nothing
# under a busy hold or with reduced motion, and every event in the table able
# to fire -- a dead entry is weather nobody will ever see, and nothing else
# would notice.
if run_godot weathertest 180 --headless --path "$PROJECT" -- weathertest; then
	if grep -qE '^weathertest: PASS' "$LOG_DIR/weathertest.log"; then
		ok "the weather keeps its schedule"
	else
		bad "the weather's scheduler broke a rule"
		grep -E '^  FAIL|^weathertest' "$LOG_DIR/weathertest.log" \
			| head -n 12 | sed 's/^/        /'
	fi
fi
}

unit_namefit() {
step "A destination name fits the height the panel reserves for it"
# The right-hand panel is as tall as its content and the chart shares a row with
# it, so a name that wraps one line further than the panel reserves moves the
# whole screen -- reported as the chart changing size when a particular system
# was selected. The reserve is two lines; this says two is still enough.
if run_godot namefit 120 --headless --path "$PROJECT" -- namefit; then
	if grep -qE '^namefit: PASS' "$LOG_DIR/namefit.log"; then
		ok "every destination name fits two lines"
	else
		bad "a system name needs more lines than the panel reserves"
		grep -E '^  FAIL|^  worst|^namefit' "$LOG_DIR/namefit.log" \
			| head -n 10 | sed 's/^/        /'
	fi
fi
}

unit_chartfilter() {
step "The chart's filtered view is mostly filtered"
# An exception that grows until it swallows the rule. Stations are on the
# chart before you visit them, deliberately, and the range that exception
# reached was the ENTIRE GALAXY — so KNOWN ONLY drew your one visited system
# and every station out to the rim, a quarter of the map, before a player had
# flown anywhere. Nothing errored; the view simply stopped answering the
# question it exists for, and the only symptom was a screen that looked wrong
# to somebody who opened it.
if run_godot chartfilter 120 --headless --path "$PROJECT" -- chartfilter; then
	if grep -qE '^chartfilter: PASS' "$LOG_DIR/chartfilter.log"; then
		ok "chart filter"
	else
		bad "the chart's KNOWN ONLY view reveals too much of the galaxy"
		grep -E '^  FAIL|^chartfilter' "$LOG_DIR/chartfilter.log" \
			| head -n 20 | sed 's/^/        /'
	fi
fi
}

unit_reactor() {
step "Every frame launches with a deck it can play"
# The reactor cap decides how many modules a frame can RUN, and a cap set too
# low does not produce a small ship â it produces a ship whose every turn is
# identical, because the deck is no bigger than the hand. That failure is
# invisible in every other check: the save is valid, the numbers add up, the
# simulator still finishes its runs. It only shows up as a game with nothing to
# decide, and the medium's second utility mount exists because it happened once
# already.
if run_godot reactor 120 --headless --path "$PROJECT" -- reactor; then
	if grep -qE '^reactor: PASS' "$LOG_DIR/reactor.log"; then
		ok "reactor"
	else
		bad "a frame cannot launch with a playable deck"
		grep -E '^  FAIL|THIN|^reactor' "$LOG_DIR/reactor.log" | head -n 20 			| sed 's/^/        /'
	fi
fi
}

unit_mounts() {
step "Every hull's mounts land on the hull"
# Cheap, and it guards a failure with no other symptom. The dorsal, ventral and
# flank lines are measured off ONE image each by art/tools/anchors.py, so
# replacing a hull sprite without re-running the tool leaves the old line
# describing art that no longer exists — the ship draws its guns in clear space
# beside itself, nothing throws, and the only way to see it is to open that hull
# at that class. It caught exactly that on the swap of Korvan's heavy B.
if run_godot mounts 120 --headless --path "$PROJECT" -- mounts; then
	if grep -qE '^mounts: PASS' "$LOG_DIR/mounts.log"; then
		ok "mounts"
	else
		bad "a hardpoint is not on its hull"
		grep -E '^  FAIL|^mounts' "$LOG_DIR/mounts.log" | head -n 20 			| sed 's/^/        /'
	fi
fi
}

unit_artcheck() {
step "No sprite is the wrong size for the box it sits in"
# THE SIZE MISTAKE IS THE INVISIBLE ONE. Everything else about a sprite is
# visible the moment you look at it; a module eight pixels too wide, or a card
# illustration that is 92x61, is not — it draws, it reads, and it is quietly
# wrong on one screen nobody opened. This check has existed since the module
# batch and was never in the gate, which meant 119 assets were vouched for by a
# command somebody had to remember to type.
#
# IT PASSES WITH ART MISSING, on purpose. Enemies and sector places are still
# drawn procedurally and that is the designed fallback, so what is counted is
# coverage and what FAILS is a file that exists and does not fit.
if run_godot artcheck 120 --headless --path "$PROJECT" -- artcheck; then
	if grep -qE '^artcheck: PASS' "$LOG_DIR/artcheck.log"; then
		ok "artcheck"
	else
		bad "a sprite does not fit the box it is drawn in"
		grep -E '^  FAIL|OVERHANGS|UNDERSIZED|TOO BIG|^artcheck' "$LOG_DIR/artcheck.log" \
			| head -n 20 | sed 's/^/        /'
	fi
fi
}

unit_rooms() {
step "The shop rooms are the ones Jon laid out"
# THE ROOMS ARE BAKED, SO THEY CAN GO STALE. `tools/room_install.py` turns the
# room bench's export into the pictures, layouts and light the game draws, and
# nothing about the game notices when the export moves on without it -- the
# old rooms keep drawing, looking exactly as right as they did. `--check`
# compares the export with the one the install recorded and confirms every file
# the rooms name is there. It needs no numpy; installing does.
RIPY=""
for candidate in python3 python; do
	if "$candidate" -c "" >/dev/null 2>&1; then
		RIPY="$candidate"
		break
	fi
done
if [ -n "$RIPY" ]; then
	if "$RIPY" tools/room_install.py --check >"$LOG_DIR/rooms.log" 2>&1; then
		ok "$(tail -n 1 "$LOG_DIR/rooms.log")"
	else
		bad "the game's shop rooms are not the room bench's export"
		sed 's/^/        /' "$LOG_DIR/rooms.log" | head -n 6
	fi
else
	ok "python absent, skipped"
fi
}

unit_labs() {
step "The laboratories are the ones Jon passed"
# THE LABS ARE BAKED TOO. `tools/lab_install.py` turns the five pictures on the
# lab stage and their settings (`tools/room_stage/lab/`) into the pictures,
# light pools and emitter maps `LabScene` draws, and the old labs would keep
# drawing if the stage moved on without it. `--check` compares the stage -- and
# the installer itself -- with what the install recorded, and confirms every
# file is there. It needs no numpy; installing does.
if [ -n "$RIPY" ]; then
	if "$RIPY" tools/lab_install.py --check >"$LOG_DIR/labs.log" 2>&1; then
		ok "$(tail -n 1 "$LOG_DIR/labs.log")"
	else
		bad "the game's laboratories are not the lab stage's"
		sed 's/^/        /' "$LOG_DIR/labs.log" | head -n 6
	fi
else
	ok "python absent, skipped"
fi
}

unit_yard() {
step "The yard is the one Jon passed"
# THE SHIPYARD IS BAKED TOO. `tools/yard_install.py` turns the five halls on the
# yard stage and everything the Yard Drones page drew (`tools/room_stage/yard/`)
# into the pictures, light maps and measurements `YardScene` draws, and the old
# yard would keep drawing if the stage moved on without it. `--check` compares
# the stage -- and the installer itself -- with what the install recorded, and
# confirms every file is there. It needs no numpy; installing does.
if [ -n "$RIPY" ]; then
	if "$RIPY" tools/yard_install.py --check >"$LOG_DIR/yard.log" 2>&1; then
		ok "$(tail -n 1 "$LOG_DIR/yard.log")"
	else
		bad "the game's yard is not the yard stage's"
		sed 's/^/        /' "$LOG_DIR/yard.log" | head -n 6
	fi
else
	ok "python absent, skipped"
fi
}

unit_enemysprites() {
step "The enemies' pictures are the ones Jon picked"
# `tools/enemy_sprites.py` turns Jon's kept pool ships (`tools/art_pool`) into
# the enemies' pictures: turned to how he judged them, specks and gyro's stand
# taken off, the calf shrunk as pixel art. `--check` compares the installer,
# the table and every source picture with what the install recorded, and every
# picture written. Plain python.
if [ -n "$RIPY" ]; then
	if "$RIPY" tools/enemy_sprites.py --check >"$LOG_DIR/enemies.log" 2>&1; then
		ok "$(tail -n 1 "$LOG_DIR/enemies.log")"
	else
		bad "the game's enemy pictures are not the installer's"
		sed 's/^/        /' "$LOG_DIR/enemies.log" | head -n 6
	fi
else
	ok "python absent, skipped"
fi
}

unit_rail() {
step "The elevator's pictures are the ones Jon picked"
# `tools/rail_install.py` copies the floor pictures on the rail stage
# (`tools/room_stage/rail/`) into the game, where `StationSpine` draws them.
# `--check` compares the two byte for byte. Plain python.
if [ -n "$RIPY" ]; then
	if "$RIPY" tools/rail_install.py --check >"$LOG_DIR/rail.log" 2>&1; then
		ok "$(tail -n 1 "$LOG_DIR/rail.log")"
	else
		bad "the game's elevator pictures are not the rail stage's"
		sed 's/^/        /' "$LOG_DIR/rail.log" | head -n 6
	fi
else
	ok "python absent, skipped"
fi
}

unit_fittest() {
step "A part can be moved between the hold and the hull"
# THE GATE'S BLIND SPOT, CLOSED. This has existed for a long time and never ran
# here, so it went eight failures deep without anybody hearing -- six of them a
# real break: a module could not be picked up off the hull at all, because an
# overlay had been added to a PanelContainer, which lays out every child it has
# and ignores their anchors, so an invisible box the size of the panel sat in
# front of the ship eating the drag. Nothing looked wrong.
#
# It was left out for a while as "flaky, about one run in six". It was not
# flaky. It picked the first EMPTY cell in the hold to drop onto without asking
# whether the part fit there, and a Widowmaker is four cells wide in a five-wide
# hold -- so when the mount order happened to put the big gun first, the hold
# correctly refused the drop and the assertion failed. Calling that flakiness
# and reaching for a timing fix is why it took two tries: a bounded wait cannot
# make a fact true that was never going to be.
#
# Six seconds, and fourteen consecutive passes.
if run_godot fittest 120 --headless --path "$PROJECT" -- fittest; then
	if grep -qE '^fittest: PASS' "$LOG_DIR/fittest.log"; then
		ok "fittest"
	else
		bad "a part cannot be moved between the hold and the hull"
		grep -E '^  FAIL|^fittest' "$LOG_DIR/fittest.log" | head -n 20 			| sed 's/^/        /'
	fi
fi
}

unit_parseall() {
step "Every script in the project parses"
# `--check-only` DOES NOT SEE EVERY FILE. CoFightTest.gd sat un-parseable for
# five days while it reported zero errors, because it only reaches scripts the
# scene tree pulls in -- and the out-of-band harnesses are loaded by hand, at
# the moment somebody runs them, which is never in CI. This loads every .gd in
# the project and reports the ones that will not.
if run_godot parseall 180 --headless --path "$PROJECT" -- parseall; then
	# THE LOG, NOT THE VERDICT. The harness only guarantees every file was
	# LOADED; Godot is the thing that knows whether one parsed, and it says so
	# on stderr. Three attempts to have the harness judge for itself were all
	# wrong in different ways -- see ParseAll.gd -- so it touches, and this
	# reads.
	if grep -qE 'Parse Error|Failed to load script' "$LOG_DIR/parseall.log"; then
		bad "a script in the project does not parse"
		grep -E 'Parse Error|Failed to load script' "$LOG_DIR/parseall.log" 			| head -n 20 | sed 's/^/        /'
	elif grep -qE '^parseall: PASS' "$LOG_DIR/parseall.log"; then
		ok "every script parses"
	else
		bad "the parse sweep did not finish"
	fi
fi
}

unit_rngtest() {
step "Seeded RNG replays, and four machines agree"
# Neither of these was in the gate, and both guard a rule the codebase leans on
# hard. `-- rngtest` is what enforces the named-stream rule: draw from the
# global generator for anything that decides something and a run stops replaying
# from its seed, which in co-op means four machines quietly disagreeing about
# the galaxy. `-- nettest` stands four — now eight — peers up in one process.
#
# The cost of their absence was not hypothetical. MAX_PLAYERS went from four to
# eight and NetTest went on asserting four in nine places; it had been failing
# ever since and nothing said so, because nothing ran it. That is the whole
# argument for these two steps being here.
if run_godot rngtest 120 --headless --path "$PROJECT" -- rngtest; then
	if grep -qE '^rngtest: PASS' "$LOG_DIR/rngtest.log"; then
		ok "rng replays from its seed"
	else
		bad "seeded RNG test failed"
		grep -E '^  FAIL|^rngtest' "$LOG_DIR/rngtest.log" | head -n 20 \
			| sed 's/^/        /'
	fi
fi
}

unit_nettest() {
# Same exit-time teardown reports as stowtest, and scoped the same way: eight
# peers in one process end holding the theme's font.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
		run_godot nettest 180 --headless --path "$PROJECT" -- nettest; then
	if grep -qE '^nettest: PASS' "$LOG_DIR/nettest.log"; then
		ok "the party agrees"
	else
		bad "netcode test failed"
		grep -E '^  FAIL|^nettest' "$LOG_DIR/nettest.log" | head -n 20 \
			| sed 's/^/        /'
	fi
fi
}

unit_sim() {
step "Simulator plays $SIM_RUNS complete runs"
# The repo's actual regression test. It has already caught an infinite draw
# loop and a structural map flaw; a balance change that crashes a run shows up
# here and nowhere else.
#
# READ `errors`, NOT `wins`. This is a smoke test, not a measurement. The run is
# unseeded and 40 runs is far too few to say anything about balance: three
# consecutive runs at one unchanged commit gave 23%, 30% and 35%, and across one
# day of pure UI work the same gate printed 45%, 40%, 25% and 8%. Nothing in
# those numbers was a change to the game.
#
# So a win rate here is worth roughly +/-15 points and cannot detect a real
# economy shift. `ROADMAP.md` records the honest figures: 200 runs is +/-4, and
# 500 is what a conclusion costs. Quoting this line as a result -- which is easy
# to do, because it is the number the gate prints -- says something the gate did
# not measure.
if run_godot sim $((90 + SIM_RUNS * 9)) --headless --path "$PROJECT" -- sim "runs=$SIM_RUNS"; then
	if grep -qE '^runs [0-9]+ · wins' "$LOG_DIR/sim.log"; then
		ok "simulator reached its report"
		grep -E '^runs |^avg |^looted |^death causes|^stranded' "$LOG_DIR/sim.log" | sed 's/^/        /'
	else
		bad "simulator never printed its report — a run is stuck or the boot path changed"
		tail -n 20 "$LOG_DIR/sim.log" | sed 's/^/        /'
	fi
fi
}

unit_pysyntax() {
step "Audio generators are valid Python"
# Syntax only. Rendering needs numpy, scipy and soundfile and writes ~850 MB,
# which is not what a pull request check is for.
#
# The interpreter is found by RUNNING it, not by `command -v`. On Windows,
# `python3` is a Microsoft Store alias stub that exists on PATH, satisfies
# `command -v`, and then refuses to run — so the absent-and-skipped branch never
# fired and this step failed on every laptop in the project for a reason that
# had nothing to do with the code. Windows installs the real one as `python`.
PY=""
for candidate in python3 python; do
	if "$candidate" -c "" >/dev/null 2>&1; then
		PY="$candidate"
		break
	fi
done
if [ -n "$PY" ]; then
	if "$PY" -m compileall -q "$PROJECT/audio" >"$LOG_DIR/py.log" 2>&1; then
		ok "audio/*.py compile ($PY)"
	else
		bad "audio/*.py failed to compile"
		sed 's/^/        /' "$LOG_DIR/py.log"
	fi
else
	ok "python absent, skipped"
fi
}

unit_musiclab() {
step "The music lab still holds together"
# THE LAB IS THE SOURCE OF THE MUSIC, so it gets checked like source.
#
# `music/lab/tk_music_lab.html` is the one file every cue lives in -- the notes,
# the instruments, the effects, the arrangement. The oggs under
# `assets/audio/music/` are RENDERED from it and the JSON under `music/songs/`
# is DUMPED from it, so neither is worth checking: they cannot be wrong on their
# own, only stale.
#
# `check_cue.mjs` fails on exactly two things, a held note grinding against its
# chord and a cue playing a pitch it has sworn off, and prints everything else
# as a note -- off-chord strong beats and repeated notes are usually deliberate.
# `check_lab.mjs` drives the page headless: tabs, transport, scrubbing,
# settings lines, and no errors on the console.
#
# SKIPPED RATHER THAN FAILED when node or the dependencies are absent, the same
# bargain the Python check above makes. The tools need `npm install` in
# `music/tools` once per machine, and a fresh clone has not done it.
if command -v node >/dev/null 2>&1 && [ -d music/tools/node_modules ]; then
	if (cd music/tools && node check_cue.mjs) >"$LOG_DIR/cues.log" 2>&1; then
		ok "every cue follows its own musical rules ($(grep -c 'BPM,' "$LOG_DIR/cues.log") cues)"
	else
		bad "a cue broke a musical rule"
		sed 's/^/        /' "$LOG_DIR/cues.log" | tail -20
	fi
	if (cd music/tools && node check_lab.mjs) >"$LOG_DIR/lab.log" 2>&1; then
		ok "the lab page plays, seeks and settles"
	else
		bad "the music lab is broken"
		sed 's/^/        /' "$LOG_DIR/lab.log" | tail -20
	fi
else
	ok "node or music/tools/node_modules absent, skipped"
fi
}

unit_versionguard() {
step "A shape that changed took its version with it"
# THE GUARD THE VOCABULARY PASS NEEDED AND DID NOT HAVE. That pass renamed keys
# in three persistence surfaces and raised none of the numbers guarding them.
# Nothing failed: a save stamped with the current version was read with keys
# that were not in it and came back as a galaxy with no contracts, two co-op
# builds shook hands and drew every partner unbranded, and every run ever flown
# stopped unlocking its manufacturer.
#
# The vocabulary check below could not have caught it and neither could any word
# grep, because BOTH SPELLINGS ARE LEGAL. What changed was the shape.
#
# Run against this branch's diff from main, or against the last commit when
# there is none. It found all four surfaces of the August break when pointed at
# it after the fact, and a fifth nobody knew about -- five save keys renamed
# stoker_* to hellbender_* at a version that did not move.
# FOUND BY RUNNING IT, for the reason the audio step below already gives: on
# Windows `python3` is a Store alias stub that satisfies `command -v` and then
# refuses to run. This step was written with `command -v` first and failed on
# this machine immediately, which is the comment down there doing its job.
VGPY=""
for candidate in python3 python; do
	if "$candidate" -c "" >/dev/null 2>&1; then
		VGPY="$candidate"
		break
	fi
done
if [ -n "$VGPY" ]; then
	PY="$VGPY"
	VG="$("$PY" .github/scripts/version_guard.py 2>&1)"
	if printf '%s' "$VG" | grep -q 'version guard: PASS'; then
		ok "$(printf '%s' "$VG" | tail -n 1)"
	else
		bad "a serialised shape changed without its version"
		printf '%s
' "$VG" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "no python for the version guard"
fi
}

unit_enclint() {
step "Encounters follow their own rulings"

# WHY THIS IS A GATE AND NOT A HABIT. Every fault it finds was found by hand
# first, one encounter at a time, by a person reading prose -- a dominated
# choice, a walk-away that spent the encounter, credits paid to an empty sky, an
# encounter reaching into the hold. All of them are patterns. Only "this reads
# weird" needs eyes, and eyes are wasted on the rest.
#
# BASELINED, so it could be switched on the day it was written. The table had 35
# findings the moment the linter existed; a gate that failed on all of them
# could only ever be turned on after a cleanup nobody had time for, and eighty
# new encounters were about to arrive. `--strict` fails on what is NOT in
# `tools/encounter_lint_baseline.txt`, so old debt stays visible and stops
# blocking new work.
if [ -n "$PY" ]; then
	if "$PY" tools/encounter_lint.py --strict >/tmp/enclint.$$ 2>&1; then
		ok "encounters: no new findings"
	else
		sed -n '/^ERRORS/,$p' /tmp/enclint.$$ | grep "NEW" | head -20
		bad "encounters: new lint findings (see above)"
	fi
	rm -f /tmp/enclint.$$
else
	warn "no python for the encounter linter"
fi
}

unit_prose() {
step "The prose reads plainly, and does not explain itself"

# Two tools, one question each. `prose_grade.py` holds the encounters to the
# reading level: grade 7 or under, 17 words a sentence on average, no sentence
# over 22 words (re-ruled 2026-10-13 for all player-facing text; it was grade 5
# from 2026-09-12). Every encounter meets it, so it needs no baseline. The rest
# of the text is reported by `prose_grade.py --all`, not gated. The grade is a
# ceiling, not a goal: prose_tells' "fragments" flag is the floor.
# `prose_tells.py` reads EVERY player-facing string for the tells the
# encounter-prose skill lists -- "It is not X. It is Y." past one an encounter,
# "which is the point", a summing-up closer, a dash, "round", hands in an
# encounter -- and is BASELINED like the linter above: what predates it is a
# ruling for Jon, not a lint failure. Its REVIEW list never fails the gate.
if [ -n "$PY" ]; then
	if "$PY" tools/prose_grade.py >/tmp/prosegrade.$$ 2>&1; then
		ok "prose grade: $(tail -n 1 /tmp/prosegrade.$$)"
	else
		tail -n 1 /tmp/prosegrade.$$ | sed 's/^/        /'
		bad "prose grade: encounters over the reading-level target (python tools/prose_grade.py)"
	fi
	if "$PY" tools/prose_tells.py --strict --quiet >/tmp/prosetells.$$ 2>&1; then
		ok "prose tells: no new findings"
	else
		grep -A1 "NEW " /tmp/prosetells.$$ | head -20 | sed 's/^/      /'
		bad "prose tells: new findings (see above; python tools/prose_tells.py)"
	fi
	rm -f /tmp/prosegrade.$$ /tmp/prosetells.$$
else
	warn "no python for the prose checks"
fi
}

unit_vocab() {
step "One word for the thing: manufacturer"
# A VOCABULARY RULING WITH NOTHING CHECKING IT DECAYS BACK. This project spent
# months with four words for one concept -- house, maker, man, manufacturer --
# spread across 42 code files, a save key, a network wire key and eleven
# documents. Ruled 2026-08-24: the word is `manufacturer`. They manufacture
# parts for spaceships; they are corporations, not families, and `house`
# imported a dynastic register the setting does not have.
#
# THE MATCH IS CASE-INSENSITIVE. It was not, at first, and `GROUPED BY HOUSE`,
# `THE HOUSE PERK IS REROLLED` and eleven more upper-case comments walked
# straight past a guard whose whole job was to catch them. A vocabulary check
# that only sees one casing is a vocabulary check that lies.
#
# Three exemptions, all deliberate, all narrow:
#
#   1. The LAN idiom -- "friends in the house", "outside the house" -- is
#      English about people under your roof, describing local-network play.
#      Renaming it produces nonsense.
#   2. "maker's mark" -- the stamp a craftsman leaves on the work. A real
#      English term, used in an art prompt and in an insurance document.
#   3. "Widowmaker" (a gun) and "gatehouse" (a building) are words that merely
#      contain the string.
#
#   4. A retired word in BACKTICKS or as a QUOTED KEY is being NAMED, not used.
#      `"chassis_maker"` and `"makers"` are keys sitting in files on players'
#      disks. The readers that still honour them are the fix for a rename that
#      shipped without raising the numbers guarding it, and a version ladder
#      saying a key moved from `makers` to `berths` is doing the same job.
#      Banning the old spelling from the code that has to READ the old spelling
#      would force a choice between a green gate and a working load.
#
#      Deliberately narrow: the quotes or the backticks have to be there.
#      `var maker := ...` is still caught, which is the vocabulary this rule was
#      written for -- checked by dropping such a file in and watching it fail.
#
# BRAND AND MARQUE were added after they were used to route AROUND this check:
# a rename hit the guard on `maker`, and a synonym went in instead -- first as a
# local called `brand`, then as `marque` in a comment. Neither was on the list,
# so neither failed, and the vocabulary the list exists to protect drifted
# anyway. A guard that only knows two of a word's synonyms teaches people the
# third.
#
# BRANDED AND UNBRANDED ARE DELIBERATELY NOT HERE, and this is the line: the
# banned usage is the NOUN standing in for `manufacturer`. `unbranded` means
# "carries no manufacturer", which is a real state a part can be in -- it is on
# screen as UNBRANDED SALVAGE and there is no one-word replacement -- and
# retiring `branded` while keeping its antonym would leave the pair incoherent.
# `-w` treats both as their own words, so they pass by construction.
#
# NOT `-w`, AND THAT IS THE POINT. To grep, an underscore is a word character,
# so `-w house` does not match inside `delivery_houses` -- and every compound
# identifier in the codebase was invisible to this check. It was found the
# expensive way: `RunState.delivery_houses()` was renamed, `StarchartScreen`
# was not, and opening the chart printed "Nonexistent function" while the
# guard stayed green. The boundary below treats an underscore as a separator
# and still ignores `widowmaker` and `gatehouse`, where the preceding letter
# is alphanumeric and there is no boundary to match.
#
# If you are adding a sixth, the bar is: would a person say this out loud?
# Two passes once, while the archive's prose needed a skip for the short
# word. That prose went with the ARCHIVE (Oct 22), and both passes now run
# everywhere.
VOCAB=$(
	{
		# Pass A -- house/maker, everywhere, no prose exemption.
		grep -rniE '(^|[^A-Za-z0-9])(house|houses|maker|makers|brand|brands|marque|marques)([^A-Za-z0-9]|$)' "$PROJECT/scripts" --include='*.gd' 2>/dev/null
		# Pass B -- the short word, everywhere.
		grep -rnwiE 'man|hull_man' "$PROJECT/scripts" --include='*.gd' 2>/dev/null
	} | grep -viE 'widowmaker|gatehouse' \
	  | grep -v "maker's mark" \
	  | grep -v 'friends in the house' \
	  | grep -v 'wrong for anyone outside the house' \
	  | grep -v '"chassis_maker"' \
	  | grep -v '"makers"' \
	  | grep -v '`maker`' \
	  | grep -v '`makers`' \
	  | grep -v '`chassis_maker`'
)

# The same check for prose. docs/archive/ is out of scope on purpose -- those
# files describe a moment and are kept stale deliberately.
#
# Two exemptions here that the code does not need: "house style", the
# publishing idiom for a publication's own conventions, and the line in
# docs/README.md that states the rule, which has to name the words it bans.
VOCAB_DOCS=$(
	grep -rniE '(^|[^A-Za-z0-9])(house|houses|maker|makers|brand|brands|marque|marques)([^A-Za-z0-9]|$)' docs tkg/*.md 2>/dev/null \
	  | grep -v '^docs/archive/' \
	  | grep -viE 'widowmaker|gatehouse' \
	  | grep -v "maker's mark" \
	  | grep -v 'house style' \
	  | grep -v 'never .house. or .maker.' \
	  | grep -viE 'never house, maker, brand, or marque' \
	  | grep -v '`chassis_maker`'
)
if [ -z "$VOCAB" ]; then
	ok "no retired vocabulary in $PROJECT/scripts"
else
	bad "retired vocabulary (house/maker/man/brand/marque) outside the allow-list"
	printf '%s\n' "$VOCAB" | head -n 20 | sed 's/^/        /'
fi
if [ -z "$VOCAB_DOCS" ]; then
	ok "no retired vocabulary in the docs"
else
	bad "retired vocabulary in the docs"
	printf '%s\n' "$VOCAB_DOCS" | head -n 20 | sed 's/^/        /'
fi
}

# =============================================================================
# THE SCHEDULER. Everything above is a unit; nothing above runs until here.
# Plain bash 3.2 (a stock macOS), so no associative arrays and no `wait -n`.
# =============================================================================

# RUN ALONE, after the pool. Each of these measures time, motion from one frame
# to the next, or threads, so a CPU shared with five other Godots could fail it
# where the code is fine. Frames are not fixed in any of them (no
# --fixed-fps), so a starved frame is a longer step of the game too.
#   maplagtest       a world's picture against its place on every frame of a
#                    pan; one long frame is a bigger lag
#   gameclocktest    the bobs read against wall-clock windows of 800 and 400 ms
#   playerdeathtest  RUN ENDED timed by the wall clock from the break, to 0.1 s
#                    early and 1 s late
#   faunatest        the wind-up must lead the shot by 300 ms of wall clock, and
#                    its cuts run on worker threads (its rare "wrong RID" was a
#                    thread race)
#   threadstress     workers racing the main thread for 20 s, each take timed in
#                    microseconds
#   ashteachcosttest every frame's wall time while A.S.H. teaches the chart,
#                    none over 100 ms (fixed fps, but a starved CPU is a slow
#                    frame all the same)
#   sim              forty whole runs, the regression test of last resort; run
#                    alone so its limit is never spent waiting for a CPU
SOLO_UNITS="maplagtest gameclocktest playerdeathtest faunatest threadstress lowhulltest ashteachcosttest sim"
# Run first and alone, because every other unit needs what it writes: the class
# cache in .godot/, without which nothing compiles.
FIRST_UNITS="import"

# Seconds each unit took serially (Oct 20). The pool starts the heaviest first,
# so the longest runs are never the last to begin. Only the ORDER depends on
# these; a wrong one costs minutes, never a result. Unlisted units count as 15.
gate_weight() {
	case "$1" in
		packlayouttest) echo 225 ;; laddertest) echo 170 ;; fightcounttest) echo 166 ;;
		ashtest) echo 133 ;; localeventtest) echo 109 ;; ashtutortest) echo 104 ;;
		enemyarttest) echo 95 ;; wrecksitetest) echo 80 ;; orbitworldtest) echo 70 ;; dockflytest) echo 62 ;;
		subjecttest) echo 61 ;; outcometest) echo 58 ;; soundmomenttest) echo 57 ;;
		maptest) echo 53 ;; sidebartest) echo 50 ;; popplacetest) echo 45 ;;
		cutawaytest) echo 44 ;; gradesheet) echo 44 ;; moontest) echo 40 ;;
		fightlogtest) echo 38 ;; killholdtest) echo 31 ;; wreckloottest) echo 29 ;;
		hinttest) echo 28 ;; calmladdertest) echo 28 ;; foetagtest) echo 28 ;;
		menutest) echo 25 ;; market) echo 24 ;; parseall) echo 24 ;;
		devtest) echo 22 ;; hulldamagetest) echo 22 ;; fightopentest) echo 22 ;;
		lockedpooltest) echo 41 ;; rewardshowntest) echo 33 ;;
		*) echo 15 ;;
	esac
}

GATE_T0=$SECONDS
GATE_SELF="${BASH_SOURCE[0]}"

# The units, in file order: every `unit_<name>() {` above. Output is printed in
# this order whatever order they run in. The prefix is the whole registration,
# so no helper may be named `unit_*` (one was, and ran as a unit, and failed).
UNITS=()
for u in $(sed -n 's/^unit_\([A-Za-z0-9_]*\)() {$/\1/p' "$GATE_SELF"); do
	UNITS+=("$u")
done
gate_has_unit() {
	local u
	for u in "${UNITS[@]}"; do [ "$u" = "$1" ] && return 0; done
	return 1
}
gate_in() {  # gate_in NAME "LIST OF NAMES"
	case " $2 " in *" $1 "*) return 0 ;; esac
	return 1
}
# A renamed unit must not quietly lose its place in the order.
for u in $SOLO_UNITS $FIRST_UNITS; do
	if ! gate_has_unit "$u" || ! declare -F "unit_$u" >/dev/null; then
		printf 'validate.sh: SOLO_UNITS or FIRST_UNITS names %s, and there is no unit_%s\n' "$u" "$u" >&2
		exit 2
	fi
done

GATE_CORES="$(getconf _NPROCESSORS_ONLN 2>/dev/null || nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 6)"
case "$GATE_CORES" in ''|*[!0-9]*|0) GATE_CORES=6 ;; esac
if [ -z "${GATE_JOBS:-}" ]; then
	# Six at once, or one a core where there are fewer (a 4-core CI runner):
	# more Godots than cores only makes each one slower against its limit.
	GATE_JOBS=6
	[ "$GATE_CORES" -lt "$GATE_JOBS" ] && GATE_JOBS="$GATE_CORES"
fi
case "$GATE_JOBS" in
	''|*[!0-9]*|0) printf 'validate.sh: GATE_JOBS must be a whole number, 1 or more (got %s)\n' "$GATE_JOBS" >&2; exit 2 ;;
esac

# Each unit's held output, its verdict, its Godot PIDs and its user folder. Not
# LOG_DIR: that is kept, and this is not.
GATE_TMP="$(mktemp -d)"
gate_native_path() {
	case "$(uname -s)" in
		MINGW*|MSYS*|CYGWIN*) cygpath -w "$1" ;;
		*) printf '%s\n' "$1" ;;
	esac
}

RUN_PIDS=()
RUN_NAMES=()
RUN_COUNT=0

start_unit() {
	local u="$1"
	local d="$GATE_TMP/$u"
	mkdir -p "$d/u"
	local appdata
	appdata="$(gate_native_path "$d/u")"
	(
		GATE_UNIT_DIR="$d"
		GATE_USER_DIR="$d/u"
		GATE_APPDATA="$appdata"
		FAIL=0
		t0=$SECONDS
		"unit_$u"
		printf '%s %s\n' "$FAIL" "$((SECONDS - t0))" >"$d/verdict"
	) >"$d/out" 2>&1 </dev/null &
	RUN_PIDS[$RUN_COUNT]=$!
	RUN_NAMES[$RUN_COUNT]="$u"
	RUN_COUNT=$((RUN_COUNT + 1))
}

# Print every finished unit's output that is next in file order.
GATE_NEXT_OUT=0
flush_output() {
	local u
	while [ "$GATE_NEXT_OUT" -lt "${#UNITS[@]}" ]; do
		u="${UNITS[$GATE_NEXT_OUT]}"
		[ -e "$GATE_TMP/$u/done" ] || break
		cat "$GATE_TMP/$u/out"
		GATE_NEXT_OUT=$((GATE_NEXT_OUT + 1))
	done
}

# Collect every unit that has ended; keep the rest.
reap_units() {
	local i n=$RUN_COUNT kept=0
	local -a kp kn
	for ((i = 0; i < n; i++)); do
		if kill -0 "${RUN_PIDS[$i]}" 2>/dev/null; then
			kp[$kept]="${RUN_PIDS[$i]}"
			kn[$kept]="${RUN_NAMES[$i]}"
			kept=$((kept + 1))
		else
			wait "${RUN_PIDS[$i]}" 2>/dev/null
			: >"$GATE_TMP/${RUN_NAMES[$i]}/done"
		fi
	done
	RUN_PIDS=()
	RUN_NAMES=()
	for ((i = 0; i < kept; i++)); do
		RUN_PIDS[$i]="${kp[$i]}"
		RUN_NAMES[$i]="${kn[$i]}"
	done
	RUN_COUNT=$kept
	flush_output
}

# run_phase MAX UNIT... : run the units in the order given, MAX at a time.
run_phase() {
	local max="$1"; shift
	local u
	for u in "$@"; do
		while [ "$RUN_COUNT" -ge "$max" ]; do
			if [ "$max" -eq 1 ]; then wait "${RUN_PIDS[0]}" 2>/dev/null; fi
			reap_units
			[ "$RUN_COUNT" -ge "$max" ] && sleep 0.5
		done
		start_unit "$u"
	done
	while [ "$RUN_COUNT" -gt 0 ]; do
		if [ "$max" -eq 1 ]; then wait "${RUN_PIDS[0]}" 2>/dev/null; fi
		reap_units
		[ "$RUN_COUNT" -gt 0 ] && sleep 0.5
	done
}

# Interrupted: stop every unit, then every Godot one started (a killed subshell
# leaves its children running), and keep nothing but LOG_DIR.
gate_stop() {
	trap - INT TERM
	printf '\nvalidate.sh: interrupted, stopping every unit and its Godot\n' >&2
	local i p f
	for ((i = 0; i < RUN_COUNT; i++)); do kill -9 "${RUN_PIDS[$i]}" 2>/dev/null; done
	for f in "$GATE_TMP"/*/pids; do
		[ -f "$f" ] || continue
		while read -r p; do kill -9 "$p" 2>/dev/null; done <"$f"
	done
	exit 130
}
gate_cleanup() {
	if [ -n "${GATE_TMP:-}" ] && [ -d "$GATE_TMP" ]; then rm -rf "$GATE_TMP"; fi
}
trap gate_stop INT TERM
trap gate_cleanup EXIT

if [ "$GATE_JOBS" -eq 1 ]; then
	# The old gate: one at a time, in file order, nothing moved.
	run_phase 1 "${UNITS[@]}"
else
	GATE_FIRST=()
	GATE_SOLO=()
	GATE_POOL=()
	i=0
	for u in "${UNITS[@]}"; do
		if gate_in "$u" "$FIRST_UNITS"; then
			GATE_FIRST+=("$u")
		elif gate_in "$u" "$SOLO_UNITS"; then
			GATE_SOLO+=("$u")
		else
			# heaviest first; file order among equals
			GATE_POOL+=("$(gate_weight "$u") $i $u")
		fi
		i=$((i + 1))
	done
	GATE_POOL_ORDER=()
	while read -r _w _i u; do
		GATE_POOL_ORDER+=("$u")
	done < <(printf '%s\n' "${GATE_POOL[@]}" | sort -k1,1nr -k2,2n)
	run_phase 1 "${GATE_FIRST[@]}"
	run_phase "$GATE_JOBS" "${GATE_POOL_ORDER[@]}"
	run_phase 1 "${GATE_SOLO[@]}"
fi
flush_output

# The verdicts, the times, and every FAIL by its unit.
gate_mmss() { printf '%d:%02d' "$(($1 / 60))" "$(($1 % 60))"; }
GATE_WALL=$((SECONDS - GATE_T0))
GATE_SUM=0
GATE_FAILS=""
printf '\n\033[1m=== Time per unit\033[0m\n'
for u in "${UNITS[@]}"; do
	d="$GATE_TMP/$u"
	tag=""
	gate_in "$u" "$FIRST_UNITS" && tag="  (first, alone)"
	gate_in "$u" "$SOLO_UNITS" && tag="  (solo)"
	if [ -f "$d/verdict" ]; then
		read -r ufail usecs <"$d/verdict"
		GATE_SUM=$((GATE_SUM + usecs))
		printf '  %6s  %s%s\n' "$(gate_mmss "$usecs")" "$u" "$tag"
		if [ "$ufail" != 0 ]; then
			FAIL=1
			if [ -s "$d/fails" ]; then
				while IFS= read -r line; do
					GATE_FAILS="$GATE_FAILS  $u: $line"$'\n'
				done <"$d/fails"
			else
				GATE_FAILS="$GATE_FAILS  $u: failed"$'\n'
			fi
		fi
	else
		FAIL=1
		printf '  %6s  %s%s\n' "-" "$u" "$tag"
		GATE_FAILS="$GATE_FAILS  $u: ended without a verdict (the unit itself broke; see its output above)"$'\n'
	fi
done
printf '  wall %s with %d at once; the units add up to %s\n' \
	"$(gate_mmss "$GATE_WALL")" "$GATE_JOBS" "$(gate_mmss "$GATE_SUM")"

if [ -n "$GATE_FAILS" ]; then
	printf '\n\033[1m=== Failed\033[0m\n'
	printf '%s' "$GATE_FAILS" | sed "s/^  /  $(printf '\033[31m')FAIL$(printf '\033[0m')  /"
fi

printf '\n'
if [ $FAIL -ne 0 ]; then
	printf '\033[31mVALIDATION FAILED\033[0m  logs in %s\n' "$LOG_DIR"
	exit 1
fi
printf '\033[32mVALIDATION PASSED\033[0m  logs in %s\n' "$LOG_DIR"
