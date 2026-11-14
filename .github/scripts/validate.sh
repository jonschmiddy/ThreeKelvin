#!/usr/bin/env bash
#
# Three Kelvin — everything that has to pass before a merge.
#
#   .github/scripts/validate.sh            # the full gate
#   SIM_RUNS=200 .github/scripts/validate.sh
#   GODOT=/path/to/Godot .github/scripts/validate.sh
#   GATE_STATIC=1 .github/scripts/validate.sh        # only the checks that need no Godot
#   GATE_UNITS="tabs codecheck" .github/scripts/validate.sh   # just those units
#   GATE_LIST=1 .github/scripts/validate.sh          # print the units it would run, in order, and stop
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
#   GATE_PART=2/4 .github/scripts/validate.sh # the second of four equal parts
#
# CI runs the four parts on four runners at once, which is how 108 CPU minutes
# of gate come back in about eight. The dealing is at THE PARTS, below.
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
# others (a sheet is one `gate_sheet` call); it runs in the pool, in its file
# position for output. The function's name is all the scheduler needs. A step
# must not depend on how fast the machine is (tkg/CLAUDE.md), so do not add to
# SOLO_UNITS, which holds older steps that still time something. If it is long,
# give it a weight in `gate_weight` so it starts early. A unit sees only its own
# variables: anything two units both need is set once at the top of the file,
# before the units.

set -uo pipefail

GODOT="${GODOT:-godot}"
PROJECT="${PROJECT:-tkg}"
SIM_RUNS="${SIM_RUNS:-40}"
# Digits only: it goes into shell arithmetic below.
case "$SIM_RUNS" in ''|*[!0-9]*) echo "SIM_RUNS must be a whole number, not '$SIM_RUNS'" >&2; exit 2 ;; esac
# How many units FlightTest and SolveTest run split into: as many as there are
# `unit_flighttest_<K>` and `unit_solvetest_<K>` functions (checked below).
# SolveTest 8 since the x12 flights (Jon, Nov 8, "split: yes"): its 4 shards
# took 312 to 363 s side by side and 302 s alone on the PC, past the 300 they
# had then and close to the 420 of #54.
GATE_FLIGHT_SHARDS=4
GATE_SOLVE_SHARDS=8
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
#   ALLOW_EXTRA="$GATE_LEAKS" gate_sheet stowtest 120 ...
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
# A limit catches a hang, not a slow day: set it to about twice the unit's time
# on the CI runner, which runs four Godots on four cores and is 2.2x slower than
# a Mac. Every red main of early Nov was a passing test killed at its limit.
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

# The exit-time reports Godot prints after a headless run that built a Control
# tree. Passed per call, as `ALLOW_EXTRA="$GATE_LEAKS" gate_sheet ...`, so it ends there.
GATE_LEAKS='resources still in use at exit|RID allocations of type .* were leaked at exit'

# One harness: run it, then need its `LABEL: PASS` line. A failed run is already
# reported by run_godot. GATE_LABEL, GATE_FAIL_RE and GATE_TAIL override the label
# (default NAME), the failure grep and the lines shown.
#   gate_sheet NAME LIMIT OK-MESSAGE FAIL-MESSAGE GODOT-ARGS...   (FAIL|^LABEL, 12 lines)
#   gate_check NAME LIMIT OK-MESSAGE FAIL-MESSAGE GODOT-ARGS...   (^  FAIL|^LABEL, 20 lines)
gate_run() {
	local failre="$1" tail_n="$2" name="$3" limit="$4" okmsg="$5" badmsg="$6"
	shift 6
	local label="${GATE_LABEL:-$name}"
	if run_godot "$name" "$limit" "$@"; then
		if grep -qE "^$label: PASS" "$LOG_DIR/$name.log"; then
			ok "$okmsg"
		else
			bad "$badmsg"
			grep -E "${GATE_FAIL_RE:-$failre|^$label}" "$LOG_DIR/$name.log" \
				| head -n "${GATE_TAIL:-$tail_n}" | sed 's/^/        /'
		fi
	fi
}
gate_sheet() { gate_run 'FAIL' 12 "$@"; }
gate_check() { gate_run '^  FAIL' 20 "$@"; }

# No interpreter: a check that cannot run has not passed.
gate_no_python() { bad "no python for $1"; }

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

unit_changes() {
step "Each change is a file in changes/, and CHANGELOG.md's [Unreleased] holds none"
# A CHANGELOG line under [Unreleased] is a merge conflict with every other
# branch; changes/ (one dated file a change) is how they stay out of it.
CHANGES_BAD=""
for f in changes/*.md; do
	[ "$f" = "changes/README.md" ] && continue
	case "$(basename "$f")" in
		[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]-*.md) ;;
		*) CHANGES_BAD="$CHANGES_BAD  $f: name it YYYY-MM-DD-what-changed.md"$'\n' ;;
	esac
	while IFS= read -r line; do
		case "$line" in
			''|'  '*|'- **Fixed** — '*|'- **Changed** — '*|'- **Added** — '*) ;;
			*) CHANGES_BAD="$CHANGES_BAD  $f: a line is not a CHANGELOG bullet or its continuation: ${line:0:60}"$'\n' ;;
		esac
	done <"$f"
done
UNRELEASED_BULLETS="$(sed -n '/^## \[Unreleased\]/,/^## [0-9]/p' CHANGELOG.md | grep -c '^- ' || true)"
[ "$UNRELEASED_BULLETS" -eq 0 ] || CHANGES_BAD="$CHANGES_BAD  CHANGELOG.md: $UNRELEASED_BULLETS bullets under [Unreleased]; each belongs in its own changes/ file"$'\n'
if [ -n "$CHANGES_BAD" ]; then
	bad "changes/ and CHANGELOG.md:"
	printf '%s' "$CHANGES_BAD" | sed 's/^/      /'
else
	ok "changes/*.md are dated CHANGELOG bullets, and [Unreleased] is a pointer to them"
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
	# SaveTest prints three verdicts (round trip, history, version gates); all three must be there,
	# so change the count with SaveTest's sections.
	if [ "$(grep -cE '^=== (PASS|FAIL)' "$LOG_DIR/savetest.log")" -ge 3 ]; then
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
if ! grep -qE '^=== (PASS|FAIL)' "$LOG_DIR/market.log" 2>/dev/null; then
	bad "market never reached its verdict"
elif grep -qE '^=== FAIL' "$LOG_DIR/market.log"; then
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
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet boardsigntest 120 \
	"SIGN stamps its note in place and nothing else on the board moves" \
	"SIGN moved the Hiring Board's other notes or its scatter, or did not sign" \
	--headless --path "$PROJECT" -- sheet=BoardSignTest
}

unit_hellbendergatetest() {
step "The Hellbender flies only at ascension 7 and up"
# Jon, Nov 8: "ONLY have the hellbender show up on Ascention 7+", and the
# hiring boards' signs stay as a hint. Level 0 over 60 seeds: none spawns, its
# clock moves nothing, nothing eaten, no body, ENGAGE, drawer or log line names
# it, no poster stamped DESTROYED; level 7 spawns it as before, in a ball galaxy
# (the tier's form), on the world tier 7 rolls with it kept off (its place moves
# nothing else); a VERSION 40 save loads at 0; a dev fight with none opens at full hull.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot hellbendergatetest 240 --headless --path "$PROJECT" -- sheet=HellbenderGateTest; then
	if grep -qE '^hellbendergatetest: PASS' "$LOG_DIR/hellbendergatetest.log"; then
		ok "no Hellbender below ascension 7, and nothing names it but the boards"
	else
		bad "a Hellbender (or a word of it) below ascension 7, or none at 7"
		grep -E 'FAIL|^hellbendergatetest' "$LOG_DIR/hellbendergatetest.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "hellbendergatetest did not finish"
fi
}

unit_stationdecktest() {
step "Every station has all five decks, at every level"
# Jon, Nov 3: the LABORATORY used to hide below a city and the HIRING BOARD
# where no manufacturer berths. Through the real station screen at all five
# levels, with and without a berth: five tabs and five floors, RELIC ANALYSIS
# at the level's price inside the lab's screen, a dock desk's work posted and
# handed in where nobody berths, and NO WORK POSTED. on a bare board.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet stationdecktest 240 \
	"all five decks at every station, the lab priced by level, a dock desk where nobody berths" \
	"a station is missing a deck, the lab or a dock desk is wrong, or a bare board says nothing" \
	--headless --path "$PROJECT" -- sheet=StationDeckTest
}

unit_contracttest() {
step "Contracts, standing, and the salvage rail's dismissal rule"
# Three claims, and the middle one is the one no other step can make. `-- market`
# proves the price invariant at standing zero, which is the only standing it can
# reach; every price in the game is fine until a player delivers four contracts
# to one house and their berths start paying over the odds for parts. The last
# one is the salvage rail's dismissal rule, which is pure logic on `Run` and has
# been got wrong twice.
gate_check contracttest 120 \
	"contracts" \
	"contract test failed" \
	--headless --path "$PROJECT" -- contracttest
}

unit_stowtest() {
step "The salvage rail survives a jump"
# Drives the real screen through a jump: the rail's flag once lived on a screen Router rebuilds.
# Why: docs/why/validate.md#unit_stowtest
ALLOW_EXTRA="$GATE_LEAKS" gate_check stowtest 120 \
	"stow" \
	"salvage rail test failed" \
	--headless --path "$PROJECT" -- stowtest
}

unit_quittest() {
step "Leaving a run draws nothing without a ship"
# QUIT and SAVE & QUIT clear the hull and then swap to the title screen, and the
# screen they leave is still in the tree for the rest of that frame. The
# starchart redrew there once with no ship and logged hundreds of errors that no
# player ever saw, because the frame is never shown. The same leak allowance as
# stowtest, for the same reason: it builds real screens.
ALLOW_EXTRA="$GATE_LEAKS" gate_check quittest 120 \
	"quit" \
	"a screen drew after the run it belonged to was gone" \
	--headless --path "$PROJECT" -- quittest
}

unit_bindtest() {
step "Key bindings rebind, fire, persist and clash"
# Every key the game listens for is a binding (`Keys`), and a wrong default
# moves a key with nobody deciding to. Rebinds through Settings with real key
# events, presses the result on the ship screen, the star chart and Main's Tab,
# reloads the settings file, and checks the clash rules. In a scratch file, so
# the player's own settings are never touched. The same leak allowance as
# quittest: it builds real screens.
ALLOW_EXTRA="$GATE_LEAKS" gate_check bindtest 120 \
	"keys" \
	"a key binding did not do what it said" \
	--headless --path "$PROJECT" -- bindtest
}

unit_menutest() {
step "The escape menu still answers after the motion settings change"
# A menu opened under REDUCED MOTION and closed after it was turned off threw
# on the animated way out and stayed up, swallowing every click. Headless never
# animates, so this harness turns the animations on (`Router.animate_in_harness`)
# and walks the menu through each change. Same leak allowance as quittest.
ALLOW_EXTRA="$GATE_LEAKS" gate_check menutest 120 \
	"menu" \
	"the escape menu stopped answering" \
	--headless --path "$PROJECT" -- menutest
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
gate_check holdtest 120 \
	"hold" \
	"the hold packing rule is broken" \
	--headless --path "$PROJECT" -- holdtest
}

unit_transfertest() {
step "The container draws what the ship actually holds"
# THE VIEW, NOT THE MODEL. One bug was reported three times with three different
# triggers -- a drop, a right-click, a drag that looked refused -- and every time
# the model was already correct and the SCREEN had not been told. Every probe
# written to chase it asserted on `Run.cargo` and `n.bag`, which is the half that
# was never broken. This one counts icons, because an icon is what a player sees.
gate_check transfertest 120 \
	"the container" \
	"the container and the hold disagree about what you are carrying" \
	--headless --path "$PROJECT" -- transfertest
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
ALLOW_EXTRA="$GATE_LEAKS" gate_check cutawaytest 240 \
	"the cutaway" \
	"the cutaway moves parts or claims loot outside the refit rule" \
	--headless --path "$PROJECT" -- cutawaytest
}

unit_subjecttest() {
step "Every encounter's subject is real art and fits LOCAL"
# An option's `subject` names pieces of art and how they are staged
# (`LocalSubject`). A misspelt piece draws nothing and says nothing, and a
# staging one tank too wide runs under the event's band or onto your ship; this
# resolves every piece against art/subjects/index.json and fits every staging to
# LOCAL's own view. It ends on the real LOCAL, so it ends with the same exit-time
# teardown reports as stowtest, allowed the same way.
ALLOW_EXTRA="$GATE_LEAKS" gate_check subjecttest 240 \
	"the subjects" \
	"an encounter's subject names art that is not there, or does not fit" \
	--headless --path "$PROJECT" -- subjecttest
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
GATE_TAIL=12 ALLOW_EXTRA="$GATE_LEAKS" gate_check moontest 300 \
	"the moons keep clear" \
	"a moon crosses a subject, a station or your ship, or moves while something is staged" \
	--headless --path "$PROJECT" -- sheet=MoonTest
}

unit_dockflytest() {
step "UNDOCK is the only way out of a station"
# Only UNDOCK leaves a station; every older way off the berth is refused and leaves nothing of it.
# Why: docs/why/validate.md#unit_dockflytest
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet dockflytest 300 \
	"only UNDOCK leaves the berth, and leaves nothing of it behind" \
	"a way off the berth bypassed UNDOCK, or left the station behind" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=DockFlyTest
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
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet swaptest 180 \
	"the pad is always shown, and the ship always leaves once it is empty" \
	"a hull swap can strand the pad or hold the ship" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=SwapTest
}

unit_derelicttest() {
step "The derelict hauler names its frame, and claiming it never costs the strip"
# A derelict's frame is named before it is claimed, and a frame not flown still pays the strip.
# Why: docs/why/validate.md#unit_derelicttest
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet derelicttest 240 \
	"the claim names its frame, and a frame not flown pays the strip" \
	"the derelict hauler hides its frame, or declining it loses the strip" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=DerelictTest
}

unit_orbitworldtest() {
step "LOCAL draws the world you orbit, close, from its first frame"
# LOCAL's first frame draws the world you orbit. The limit is high: its tour flies every leg on map time.
# Why: docs/why/validate.md#unit_orbitworldtest
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet orbitworldtest 840 \
	"LOCAL draws the world you orbit, close" \
	"LOCAL drew the wrong world, none, or too small" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=OrbitWorldTest
}

unit_fightlogtest() {
step "The fight log is hidden until LOG is pressed, and records all the same"
# Jon, Oct 18, "fightlog:hidden". From a used settings file: hidden by default,
# recording while hidden, LOG clicked shows every line and moves nothing that can
# be clicked, the choice kept in the settings file; and the box test, LOG and the
# open log against everything on the fight's screen in every hull and pack.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet fightlogtest 300 \
	"the fight log hides, records, opens, and covers nothing" \
	"the fight log shows by default, loses lines, moves a control or covers something" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=FightLogTest
}

unit_fightwordstest() {
step "The fight's and LOCAL's words say what the rules do"
# The tutorial audit, Oct 22: the status chips named by the card's keyword
# (NEGATE, GROWS, not SLIP and ADAPT), the DISCARD's tooltip naming the hand
# swept in at END TURN, and no dash in LOCAL's bar line anywhere in the galaxy.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet fightwordstest 180 \
	"the chips, the discard and the bar line say what the rules do" \
	"a chip, the discard's tooltip or the bar line says something the rules do not" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=FightWordsTest
}

unit_materialtest() {
step "Every material is a thing the hold can actually hold"
# `MaterialTable` authored 64 rows a day before anything could carry one, so its
# shapes had never met the grid that has to accept them. A row whose `cells`
# reads wider than the smallest hull's hold parses fine, builds fine, and can
# never be placed -- and nothing would say why. Checked against the LIGHTEST
# hull, because an item that fits a heavy and not a light vanishes for half the
# roster, quietly.
GATE_FAIL_RE='^  FAIL|^ +refused|^materialtest' gate_check materialtest 120 \
	"materials" \
	"a material cannot be carried" \
	--headless --path "$PROJECT" -- materialtest
}

unit_content() {
step "The catalogue export is a shape the manifest can read"
# The catalogue export and the manifest page each vet every row, so the two cannot drift apart unseen.
# Why: docs/why/validate.md#unit_content
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
GATE_FAIL_RE='^  FAIL|OFF' gate_check attrtest 180 \
	"attribute ladder" \
	"a part does not move its gauge by what its grade promised" \
	--headless --path "$PROJECT" -- attrtest
}

unit_maptest() {
step "Every galaxy can be crossed, and every enum still has its labels"
# NOT GATED UNTIL NOW, which is how MapTest lost its verdict line without
# anything noticing: it prints four results and nothing was reading them. It
# checks that a core exists, is reachable, and can be FLOWN to in 120 rolled
# galaxies -- three of the most expensive failures the generator can produce --
# plus that no label array has drifted from its enum. Since Oct 22 also the
# depth rule (`RunState.DEPTH_STEP`, two rings since Oct 27) and a sweep of 255
# galaxies, 15 of every kind, flown by the slowest ship: ~130s alone, so 300.
GATE_TAIL=10 gate_check maptest 480 \
	"every galaxy is crossable" \
	"a galaxy cannot be crossed, or a label array has drifted" \
	--headless --path "$PROJECT" -- maptest
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
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet hinttest 300 \
	"hints show once, in place" \
	"a first-run hint misbehaved" \
	--headless --path "$PROJECT" -- hinttest
}

unit_goaltest() {
step "The goal line: always the goal, the next step, never over anything"
# Tutorial direction B (Oct 17): GOAL: REACH THE CORE under the HUD, and the
# step while one is pending (open STARCHART and jump; click an event and GO),
# through a new run on LOCAL, the chart, the map, an event's band and a fight:
# box-tested against the HUD, the side bar, the toolbar row, the event band, the
# hand and every hull and its words; done steps never come back; not pressable.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet goaltest 180 \
	"the goal line says the goal and the next step, clear of everything" \
	"the goal line is wrong or covers something" \
	--headless --path "$PROJECT" -- sheet=GoalTest
}

unit_badgetest() {
step "The Custodian's badge: the approved eye, on every screen, once a jump"
# Badge 9b, "The eye opens, loud" (Jon, Nov 4), on the goal line. Every frame
# pixel for pixel as the approved page's own code draws it; its stages from the
# core boss's growth; on LOCAL, the map, the chart and a fight at every jump 0
# to 40, clear of everything the goal line keeps off; the arrival once a jump,
# never on the chart a jump left from or after a load; the tooltip's words, no
# hull figure; it takes no click.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet badgetest 240 \
	"the badge is the approved eye, where it belongs, once a jump" \
	"the badge differs from the approved page, covers something, or replays" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=BadgeTest
}

unit_questlogtest() {
step "The QUESTS tab: its table, SHOW ON STARCHART, PLOT ROUTE, nothing covered"
# Jon's design A (Oct 22): a QUESTS tab after STARCHART opens a table of the
# quests you hold; a row's SHOW ON STARCHART and PLOT ROUTE open the chart on
# its place, tagged, with its route. Three galaxies, the real screens: the tab's
# rect the same with 0, 1 and 5 held, the HUD row fitting with and without
# ARCHIVE, a row per quest with its fields, the chart's destination, tag and
# legal route, and the table and the tag box-tested.
GATE_FAIL_RE='FAIL|^questlogtest|^    ' ALLOW_EXTRA="$GATE_LEAKS" gate_sheet questlogtest 180 \
	"the quests table: every quest, shown and routed on the chart, nothing covered" \
	"the quests table or its chart tag is wrong or covers something" \
	--headless --path "$PROJECT" -- sheet=QuestLogTest
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
# A.S.H.'s approved lines fire at their moments, within her limits, and clear of everything on screen.
# Why: docs/why/validate.md#unit_ashtest
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet ashtest 600 \
	"A.S.H. at her moments, within her limits, clear of everything" \
	"A.S.H. spoke out of turn, or over something" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=AshTest
}

unit_ashtutortest() {
step "A.S.H. teaches: the hints in her corner, clear of everything, and the cards when she is off"
# Jon's tutorial A (Oct 17): each first-run hint said in her corner in his
# words with its subject outlined, the goal steps said as they start, on LOCAL,
# fights, the chart, the map and the station, over the cutaway, the band and a
# wreck's window; held until a click; a bark never over one; the box test on
# every screen against a list gathered by the test and the pictures' own hit
# tests; her switch off brings today's cards back; nothing in a party.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet ashtutortest 600 \
	"A.S.H. teaches every hint and step, clear of everything" \
	"A.S.H.'s teaching failed" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=AshTutorTest
}

unit_ashteachcosttest() {
step "A.S.H. teaching the chart costs a frame nothing"
# Jon, Oct 20: the chart "SUPER laggy and unresponsive" while she taught its
# list -- 840 ms a frame, her box's check asking every system at every 3 px.
# Every frame timed while she says the list's line and the step's on a
# 410-system chart, against the chart with her silent; and her check finds what
# the old point-by-point scan found. Times frames: one of SOLO_UNITS.
GATE_LABEL=AshTeachCostTest ALLOW_EXTRA="$GATE_LEAKS" gate_sheet ashteachcosttest 300 \
	"her teaching on the chart costs a frame nothing" \
	"her teaching on the chart lags the game" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=AshTeachCostTest
}

unit_maplagtest() {
step "The sector map's worlds keep up with a pan"
# Each world's picture sits on its place (its ring, label and beacons) on every
# frame of a pan; an ease that chased the place left it trailing by frames.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet maplagtest 180 \
	"worlds keep up with the camera" \
	"a world's picture trails the camera" \
	--headless --path "$PROJECT" -- maplagtest
}

unit_twinsitetest() {
step "Star B is a place, as the one star is"
# Star B is a place wherever the one star is (rulings 20 and 23). Long: 289 s on the CI runner.
# Why: docs/why/validate.md#unit_twinsitetest
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet twinsitetest 600 \
	"star B is a place everywhere the star is" \
	"star B is not a place somewhere the star is, or a ship is put back wrong" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=TwinSiteTest
}

unit_twindrawtest() {
step "Two suns and heavy giants are drawn as they are"
# Ruling 20 (Oct 30): a twin's sun floor shrinks with the zoom below its fit,
# a world round one star is drawn in front of its sun on the near side and
# behind it on the far, every orbit round its own centre, each world lit from
# its own sun, the floor read off the map's own SunViews, and LOCAL's two suns
# as far as headless reaches. Shaders are not compiled headless.
gate_sheet twindrawtest 420 \
	"two suns and heavy giants are drawn as they are" \
	"a twin or a heavy giant is drawn wrong" \
	--headless --path "$PROJECT" -- sheet=TwinDrawTest
}

unit_pairlocaltest() {
step "LOCAL holds a turning pair where the map left it"
# Ruling 23 (Nov 1, the orbiting pair): LOCAL built at a system's kept map
# clock holds that clock and the pair's angle there, at 8 angles of a wide pair
# and a close one (star B on the band on the map's side, the nearer sun drawn
# over the farther, a close pair end on crossing on the band); map -> LOCAL ->
# map keeps one clock, in co-op too with a partner's clock ahead, the zoom
# ladder off and on, the map then catching up with no jump; a save keeps the
# angle; one sun is untouched.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet pairlocaltest 120 \
	"LOCAL holds the pair where the map left it" \
	"LOCAL shows the pair at another angle than the map, or a handover moved its clock" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=PairLocalTest
}

unit_cometflighttest() {
step "Every comet spot can be flown to, in time"
# The comet's three spots as flights, under Jon's limits (Nov 9, "M1").
# Why: docs/why/validate.md#unit_cometflighttest
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet cometflighttest 300 \
	"every comet spot is found, flown and held, within the time limits" \
	"a comet spot flight is missing, misses the spot or the comet, or is too slow" \
	--headless --path "$PROJECT" -- sheet=CometFlightTest
}

unit_cometcatchtest() {
step "The comet catch plays through on the real map"
# The race, the wait, the pass in LOCAL and TOO LATE (Jon, Nov 9, "CC").
# Why: docs/why/validate.md#unit_cometcatchtest
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet cometcatchtest 180 \
	"the comet's spots are raced, waited at and caught; late spots are refused" \
	"the catch broke: a spot, the pass in LOCAL or TOO LATE" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=CometCatchTest
}

unit_arrivesidetest() {
step "A click on either half of a world, Shift or not, arrives on its lit side with its spin"
# Jon, Nov 10, "S3", the choice dropped Nov 11: the real map's tag, click and arrival; then the solver's sides.
# Why: docs/why/validate.md#unit_arrivesidetest
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet arrivesidetest 300 \
	"every click arrives on the lit side with the spin, the tag says nothing of sides" \
	"an arrival side, the way round or the hover tag is wrong" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=ArriveSideTest
}

# FlightTest and SolveTest run SPLIT, GATE_FLIGHT_SHARDS and GATE_SOLVE_SHARDS
# units each (`-- shard=K/N`: every Nth system or case, `Harness.mine`), side by
# side in the pool. Each shard judges its own cases (FlightTest's worker plans
# and hand phase pick their flights from every system, as unsplit); then
# `flighttest` and `solvetest`, after the pool, add up what needs every case (a
# sweep's found-and-clean share, the flights left put there, the replans found
# again) from the shards' logs (`sheet=ShardSum`), and check every case ran
# once. A shard's unit is one of `unit_flighttest_<K>` below: as many as the
# count. FlightTest's hand phase (flying by hand in a twin and the turning
# pair's checks, `_hand_phase`) is a unit of its own, `flighthand`
# (`phase=hand`), and the shards run without it (`phase=rest`): at x12 it took
# about 205 s and held the 4th shard to 328 s, past the 300 it had then (Jon,
# Nov 8).
gate_flight_shard() {
step "FlightTest, shard $1 of $GATE_FLIGHT_SHARDS"
# Ruling 20 (Oct 30): FlightSolve's flights on map time, one sun, a heavy
# giant and two suns, from every start to every place, planned as the
# preview is, clicked, flown and landed; the far places (the Hellbender, where
# a job's place goes too) and the core's black hole (kept out of its lens) and
# the start system; the same plans on a worker; flying by hand in a twin. The
# full run is about 700 s: this is its `short` one (one seed, four systems a
# sweep; about 120 s unsplit with the pair turning), its clicks apart in
# `flightclicks`, which times frames. Split, a shard took 40 s with all eight
# shards of both tests at once on the PC (Nov 3); the hand phase is
# `flighthand`'s (below), so no shard holds it.
if run_godot "flighttest_$1" 420 --headless --path "$PROJECT" -- sheet=FlightTest short clicks=0 phase=rest "shard=$1/$GATE_FLIGHT_SHARDS"; then
	if grep -qE '^flighttest: PASS' "$LOG_DIR/flighttest_$1.log"; then
		ok "its flights solved (or today's planner, with one sun), flown as drawn, landed"
	else
		bad "a flight was not found, not flown as drawn, or did not land"
		grep -E 'FAIL|^flighttest' "$LOG_DIR/flighttest_$1.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "flighttest shard $1 did not finish"
fi
}

unit_flighttest_1() {
gate_flight_shard 1
}

unit_flighttest_2() {
gate_flight_shard 2
}

unit_flighttest_3() {
gate_flight_shard 3
}

unit_flighttest_4() {
gate_flight_shard 4
}

unit_flighthand() {
step "FlightTest's flying by hand in a twin and the turning pair"
# The `short clicks=0` run's hand phase alone (`phase=hand`): its systems the
# same wide and close pairs the shards' starts give (picked from every system,
# as the shard that held it picked them), nothing else flown. Let go far out
# and between the stars it settles inside the map, taken by no ring; W at a
# sun never takes it inside its keep-out; then the turning pair (ruling 23).
# About 205 s at x12 (it was the 4th shard's, which took 328 s side by side);
# 221 s in a gate-like run on the PC and 327 s beside other jobs. Its limit is
# twice the 221 s, rounded up, and above its shards' 420.
if run_godot flighthand 450 --headless --path "$PROJECT" -- sheet=FlightTest short clicks=0 phase=hand; then
	if grep -qE '^flighttest: PASS' "$LOG_DIR/flighthand.log"; then
		ok "let go anywhere in a twin it settles inside the map, W never takes it into a sun, and the turning pair holds"
	else
		bad "flying by hand in a twin left the map, was taken by a ring or a sun, or the turning pair failed"
		grep -E 'FAIL|^flighttest' "$LOG_DIR/flighthand.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "flighthand did not finish"
fi
}

# The totals of a split test (above), from its shards' logs: one of AFTER_UNITS.
gate_shard_sum() {
	local name="$1" n="$2" k logs="" dir="$LOG_DIR"
	case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) dir="$(cygpath -m "$LOG_DIR")" ;; esac
	for ((k = 1; k <= n; k++)); do logs="$logs${logs:+,}$dir/${name}_$k.log"; done
	if run_godot "$name" 120 --headless --path "$PROJECT" -- sheet=ShardSum "label=$name" "logs=$logs"; then
		if grep -qE "^${name}_total: PASS" "$LOG_DIR/$name.log"; then
			return 0
		fi
		grep -E 'FAIL|_total' "$LOG_DIR/$name.log" | head -n 12 | sed 's/^/        /'
	fi
	return 1
}

unit_flighttest() {
step "Every autopilot flight on the map is solved, flown as drawn and lands (the shards' totals)"
if gate_shard_sum flighttest "$GATE_FLIGHT_SHARDS"; then
	ok "every system flown once across the shards, every sweep found and clean in at least 99%, and the flights put there within PUT_LEFT"
else
	bad "a sweep's flights were not found and clean often enough, more flights were put there than PUT_LEFT allows, or a shard did not run its share"
fi
}

unit_flightclicks() {
step "A click on the map flies the flight drawn, planned on a worker"
# FlightTest's clicks through the map's own path (`fly_bg`, the preview as the
# overlay keeps it) at 60 and 30 frames a second, paced to the wall clock
# while a plan is made: every click flown and landed with its callback once, W
# letting go of one still planned, no step over 20 ms (nothing planned on the
# main thread), every flight on the line drawn for it, no engine error. It
# times frames: one of SOLO_UNITS.
GATE_LABEL=flighttest gate_sheet flightclicks 180 \
	"every click flew the flight drawn, planned off the main thread" \
	"a click flew another flight, waited on the main thread, or lost its callback" \
	--headless --path "$PROJECT" -- sheet=FlightTest clicks
}

gate_solve_shard() {
step "SolveTest, shard $1 of $GATE_SOLVE_SHARDS"
# FlightSolve (ruling 20, Oct 30) from every start to every place at several
# line-ups: one sun, the giant at 1/10 and 1/4, the layout's own twins and
# hand-built ones: found and clean in at least 99% (97% of the hand twins),
# starting and landing where it should, no cusp in a burn, the same plan
# rebuilt from its choice, a sample flown again by plain RK4, and the same
# results on WorkerThreadPool, and the pair-phase sweep (ruling 23). The full
# run is about 1,200 s: this is `short`, about 250 s alone unsplit since the
# pair turns (the twins' plans cost about a fifth more, and the phase sweep at 4
# angles of two pairs); split, a shard took 92 to 114 s with all eight shards of
# both tests at once on the PC (Nov 3), and 4 shards 312 to 363 s at x12 (Nov
# 8), so 8 shards now, each about half of that.
if run_godot "solvetest_$1" 420 --headless --path "$PROJECT" -- sheet=SolveTest short "shard=$1/$GATE_SOLVE_SHARDS"; then
	if grep -qE '^solvetest: PASS' "$LOG_DIR/solvetest_$1.log"; then
		ok "its flights are found, clean, replayed and the same on a worker"
	else
		bad "a solved flight was not found, not clean, or not the same again"
		grep -E 'FAIL|^solvetest' "$LOG_DIR/solvetest_$1.log" | head -n 12 | sed 's/^/        /'
	fi
else
	bad "solvetest shard $1 did not finish"
fi
}

unit_solvetest_1() {
gate_solve_shard 1
}

unit_solvetest_2() {
gate_solve_shard 2
}

unit_solvetest_3() {
gate_solve_shard 3
}

unit_solvetest_4() {
gate_solve_shard 4
}

unit_solvetest_5() {
gate_solve_shard 5
}

unit_solvetest_6() {
gate_solve_shard 6
}

unit_solvetest_7() {
gate_solve_shard 7
}

unit_solvetest_8() {
gate_solve_shard 8
}

unit_solvetest() {
step "The solver finds clean flights, replays them and agrees on a worker (the shards' totals)"
if gate_shard_sum solvetest "$GATE_SOLVE_SHARDS"; then
	ok "every case solved once across the shards, every sweep found and clean in at least 99% (97% of the hand twins)"
else
	bad "a sweep's flights were not found and clean often enough, or a shard did not run its share"
fi
}

unit_mapperftest() {
step "The sector map's trims draw what they replaced"
# The Mac's map trims (Oct 27) work out the orbit lines, the dust sheets' seeds
# and the ship's forecast lines their own faster way. Held here to the old loop
# (which calls `screen` and `orbit_point`) point for point, so a change to
# either that the trimmed copy misses fails here, not as a line off its world.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet mapperftest 300 \
	"the map's orbits, dust and forecast lines are as they were" \
	"a map trim draws something else" \
	--headless --path "$PROJECT" -- sheet=MapPerfTest
}

unit_laddertest() {
step "One camera: every move between chart, map, LOCAL and station lands"
# Each seam's designs both ways, input mid-move, scroll past a zoom's end, a
# fight from the map, DOCK/UNDOCK, and the switch off giving a plain swap.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet laddertest 540 \
	"every move lands where it should" \
	"a move between distances failed" \
	--headless --path "$PROJECT" -- sheet=LadderTest
}

unit_lowhulltest() {
step "Low hull: the edges, every text decoding worse as the hull falls, her voice breaking up"
# Jon's strong (Oct 20). Off above 30%, rising to 5%, nothing on screen moving,
# every scrambled letter read back as itself, the escape menu clean, reduced
# motion still; her voice's glitches inside her words and baked on a worker.
# SOLO: it times frames and the worker's bake.
GATE_LABEL=LowHullTest ALLOW_EXTRA="$GATE_LEAKS" gate_sheet lowhulltest 300 \
	"the low-hull warning rises as the hull falls and moves nothing" \
	"the low-hull warning failed a check" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=LowHullTest
}

unit_calmladdertest() {
step "One motion: every hop between LOCAL, the map and the chart is the calm move"
# Jon's pick A (Oct 17). Every hop by tab, Tab and a rebound key, from a world's
# orbit and the system's edge, frame by frame at 60 fps: one ship on one
# straight line, no cut or one-frame swap, the side bar and toolbar still while
# the camera moves, the hop within 10% of its length, a press mid-move hurried
# and not lost, the goal line away for the move and back after it.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet calmladdertest 300 \
	"every hop is one calm move about your ship" \
	"a hop between distances was not the calm move" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=CalmLadderTest
}

unit_sidebartest() {
step "The side bar never goes blank between distances"
# Every hop with a side bar at one end (LOCAL, map, chart), frame by frame at
# 60 fps for every look of the swap: no frame with the side bar empty, a click
# on content not yet resolved eaten, and an instant swap headless and under
# reduced motion (Jon, Oct 13).
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet sidebartest 300 \
	"the side bar swaps in place, never blank" \
	"the side bar went blank or took a click it should not" \
	--headless --path "$PROJECT" -- sheet=SideBarTest
}

unit_deathpooltest() {
step "Ships and creatures die the ways Jon kept"
# Every kept death style reachable, the cut ones (E CHAIN, H SLICE) never
# played, ships and creatures never crossing, and a won fight's wrecks dying
# the way the fight chose, so LOCAL's wreck is the one the animation left.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet deathpooltest 120 \
	"every kept style is reachable and nothing crosses" \
	"a death style rolled where it should not" \
	--headless --path "$PROJECT" -- sheet=DeathPoolTest
}

unit_popplacetest() {
step "Fight numbers sit on the hull's ink, and land above it"
# Jon, Oct 13 ("Pops: B"): a held card's number centred on the ship's ink both
# ways; a landing's pops centred across on the ink and wholly above its top.
# Every enemy picture and every player hull (manufacturer x weight), in a fight.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet popplacetest 240 \
	"previews on the ink, pops above it, on every hull" \
	"a fight number is off its hull" \
	--headless --path "$PROJECT" -- sheet=PopPlaceTest
}

unit_hitfxlivetest() {
step "Hits, block and brace drawn on every ship in a fight"
# Through the real screen, a pack of three: each ship carries its hit marks, the
# bubble for block and the plated overlay for brace; every kind of landing
# makes its visual (soak, fizzle, armour taking it and shedding, a mark); a
# kill's wreck keeps its marks, in the slot and on LOCAL.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet hitfxlivetest 120 \
	"every landing draws, and the wreck keeps its marks" \
	"a hit, the bubble or the armour did not draw" \
	--headless --path "$PROJECT" -- sheet=HitFxLiveTest
}

unit_hulldamagetest() {
step "Hull damage looks leave no holes"
# Hull damage marks leave no holes: on the hull's own pixels, in its colours, glows that move.
# Why: docs/why/validate.md#unit_hulldamagetest
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet hulldamagetest 300 \
	"no holes, on the hull, in its colours, glows that move" \
	"a hull damage look broke one of its rules" \
	--headless --path "$PROJECT" -- sheet=HullDamageTest
}

unit_gameclocktest() {
step "The bobs run on game time, not the wall's"
# Jon, Oct 13, of the full fight films: "the hovering animation is REALLY fast".
# The movie writer steps 1/60 s a frame however long a frame takes to write, so
# the wall's clock raced (the cutter's bob at 0.375 s a cycle, not 4.76). In a
# real fight of three: time stopped with the wall running, no bob moves; time
# at 20x, every bob goes top to bottom; a slot made later bobs in step with the
# first; `ShipView.shot_clock` still drives your ship.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet gameclocktest 120 \
	"the bobs keep game time, in step" \
	"a bob ran on the wall's clock, or out of step" \
	--headless --path "$PROJECT" -- sheet=GameClockTest
}

unit_fightopentest() {
step "A fight opens by easing up out of LOCAL, not with a pop"
# A fight opens by easing up out of LOCAL: nothing jumps over 10 px, no click lands before the band settles.
# Why: docs/why/validate.md#unit_fightopentest
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet fightopentest 180 \
	"the fight's hand comes up out of LOCAL, eased, and takes no early click" \
	"a fight's opening jumped, popped, went dark or took an early click" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=FightOpenTest
}

unit_playerdeathtest() {
step "Dying: your ship breaks up, a beat on the wreck, then the run's screen"
# Jon, Oct 13: "When you die... let's have your ship crack and explode... pause
# for a beat... then the run ended popup shows up." The same fight twice from
# one seed, 5 hull into Strafe 5 through END TURN: animated, the hull comes
# apart (a ship style, boss length, mirrored for a right-facing ship, over the
# hull, the explosion after the break) and RUN ENDED waits for it and the hold;
# without motion, RUN ENDED at once; the run left behind identical both ways.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet playerdeathtest 180 \
	"your ship breaks up before the run ends, and the run is the same" \
	"the death's breakup or its timing failed" \
	--headless --path "$PROJECT" -- sheet=PlayerDeathTest
}

unit_corewintest() {
step "Beating the core's boss: its body looted, then the win screen"
# Jon, Oct 12: the custodian's body lootable, then a win popup with the death
# screen's music. ENGAGE at the core, the custodian killed through the real
# fight: the body open with its loot and no win screen yet, the run recorded as
# won, DONE / Escape / any other door ending on the win screen (Jon's note whole,
# the stats, TITLE, &"gameover"); an ordinary fight won never comes near it.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet corewintest 180 \
	"the core's win loots the body, then ends the run" \
	"the core's win flow failed" \
	--headless --path "$PROJECT" -- sheet=CoreWinTest
}

unit_midjointest() {
step "Co-op: starting and leaving a shared fight through Router, Combat and the menu"
# A shared fight is the host's fight on every ship, and leaving or rejoining it is clean.
# Why: docs/why/validate.md#unit_midjointest
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet midjointest 180 \
	"a shared fight is the host's fight on every ship, and leaving it leaves" \
	"starting or leaving a shared fight failed" \
	--headless --path "$PROJECT" -- sheet=MidJoinTest
}

unit_wreckloottest() {
step "Each wreck holds its own ship's loot"
# Jon, Oct 13: "Each ship you kill has a chance to get credits and modules and
# other parts." Every wreck holds its own template's roll at its own place; the
# credit chance and amount stay in bounds over thousands of wrecks; a two-ship
# fight pays about the sum of its ships; three seats with their streams apart
# roll identical wrecks, sized for the crew; a save keeps every wreck.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet wreckloottest 240 \
	"every wreck pays its own ship, the same on every machine" \
	"a wreck's loot is not its own ship's, or not the same everywhere" \
	--headless --path "$PROJECT" -- sheet=WreckLootTest
}

unit_lockedpooltest() {
step "A locked manufacturer appears nowhere"
# Jon, Oct 20: "Solari things should NOT show up in the game until Solari is
# unlocked (win the game once)." Over seeded galaxies, every wreck, kill bag,
# shelf, yard hull, derelict hull, event part, relic analysis, contract item
# and the custodian's body: a fresh profile finds Korvan and unbranded only and
# every roll still rolls something; a Korvan win finds Solari too; developer
# mode finds it; a save keeps its pool across CONTINUE; a party rolls the host's.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet lockedpooltest 240 \
	"a manufacturer appears only once it is unlocked" \
	"a locked manufacturer's part or hull reached a player, or a pool ran dry" \
	--headless --path "$PROJECT" -- sheet=LockedPoolTest
}

unit_deeploottest() {
step "Going deep pays: material gates are module gates, no commons past halfway"
# Jon, Oct 22: a hard game where going deep is worth it. Materials read danger
# through MapGen.tier with LootGen's own gates (they compared tier numbers to
# raw danger and opened Epic, Legendary and Artifact twice as shallow), and from
# tier 3 no source rolls a COMMON module or material -- wrecks, bags, derelicts,
# event parts, relic analysis, shelves, the custodian, every material table --
# while a pool the rule would empty falls back to its own commons.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet deeploottest 240 \
	"materials gate like modules, and nothing common rolls deep" \
	"a material opens shallower than its module, or a common rolled deep" \
	--headless --path "$PROJECT" -- sheet=DeepLootTest
}

unit_wrecksitetest() {
step "Each place in a system keeps its own wrecks"
# Each place keeps its own wrecks, off your hull, and a real jump draws none.
# Why: docs/why/validate.md#unit_wrecksitetest
ALLOW_EXTRA="$GATE_LEAKS|were leaked at exit" gate_sheet wrecksitetest 420 \
	"a world keeps its wrecks, the next one and the next system have none, and they stay off your hull" \
	"a wreck shows at a place it did not die at, or on your hull" \
	--headless --path "$PROJECT" -- sheet=WreckSiteTest
}

unit_arriveidletest() {
step "A new run's arrival: the engines sputter to the idle, no highlight"
# Jon, Oct 13: "I don't want the engines to turn off... I just want them to
# sputter to an idle. No highlight." LOCAL launched as the hull pick launches
# it, stepped a frame at a time: the flame never fully off from the clean burn
# to the idle, the cutaway outline never lit by the ship coming to rest, and a
# pointer left where it parked does not light it.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet arriveidletest 180 \
	"the arrival sputters to the idle, never off, no highlight" \
	"the arrival's engines or highlight are wrong" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=ArriveIdleTest
}

unit_jumpseqtest() {
step "The jump films commit on time, their cues land on their frames, the HUD never moves"
# Every landed film (JumpRegistry.ALL) through Router.begin_jump on a fixed clock: the commit
# at the film's commit time, the build cue on the first frame and the hit cue on the frame the
# clock crosses the cut, the stage last in EncounterView and gone with the commit, a skip that
# commits and hushes, deterministic picks, REDUCE FLASHES capping the flash.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet jumpseqtest 300 	"the jump films play as filmed" 	"a jump film is off its clock, moved the HUD or left something behind" 	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=JumpSeqTest
}

unit_jumpshadertest() {
step "Every jump shader compiles in a real renderer, and every film's stage draws"
# Headless compiles no shaders, so a jump shader that does not compile passed JumpSeqTest.
# The gate's one windowed unit: a hidden desktop on Windows, xvfb-run on Linux.
# Why: docs/why/validate.md#unit_jumpshadertest
local log="$LOG_DIR/jumpshadertest.log" limit=600 code=0 bin="${TK_GODOT_BIN:-$GODOT}"
local args=(--audio-driver Dummy --disable-vsync --fixed-fps 60 --path "$PROJECT" -- sheet=JumpShaderTest)
case "$(uname -s)" in
	MINGW*|MSYS*|CYGWIN*)
		if [ -n "${TK_HIDDESK:-}" ] && [ -x "$TK_HIDDESK" ] && [ "${bin%.sh}" = "$bin" ]; then
			local wlog="$LOG_DIR/jumpshadertest.win.log"
			run_limited "$limit" "$TK_HIDDESK" "$(cygpath -w "$wlog")" "$(cygpath -w "$bin")" "${args[@]}"
			code=$?
			cat "$wlog" >"$log" 2>/dev/null
		else
			run_limited "$limit" "$GODOT" "${args[@]}" >"$log" 2>&1
			code=$?
		fi ;;
	Linux)
		if [ -n "${DISPLAY:-}" ]; then
			run_limited "$limit" "$GODOT" "${args[@]}" >"$log" 2>&1
			code=$?
		elif command -v xvfb-run >/dev/null 2>&1; then
			run_limited "$limit" xvfb-run -a -s "-screen 0 1280x800x24" "$GODOT" "${args[@]}" >"$log" 2>&1
			code=$?
		else
			bad "jumpshadertest: no display and no xvfb-run, so nothing can compile the jump shaders"
			return
		fi ;;
	*)
		run_limited "$limit" "$GODOT" "${args[@]}" >"$log" 2>&1
		code=$? ;;
esac
if [ "$code" -eq 124 ]; then
	bad "jumpshadertest: still running after ${limit}s, killed"
	tail -n 25 "$log" | sed 's/^/        /'
	return
fi
# the leaks a windowed run reports at exit; anything while the films play fails in the sheet
local hits
hits="$(grep -nE "SHADER ERROR|$ERROR_PATTERNS" "$log" 	| grep -vE "$GATE_LEAKS|Texture with GL ID of [0-9]+: leaked|Parameter \"RenderingServer::get_singleton\(\)\" is null" || true)"
if [ -n "$hits" ]; then
	bad "jumpshadertest: a shader or script error"
	printf '%s
' "$hits" | head -n 20 | sed 's/^/        /'
elif [ "$code" -eq 0 ] && grep -qE '^jumpshadertest: PASS' "$log"; then
	ok "every jump shader compiles and every film's stage draws"
else
	bad "a jump shader did not compile or a film's stage did not draw (godot exited $code)"
	grep -E 'FAIL|^jumpshadertest' "$log" | head -n 12 | sed 's/^/        /'
fi
}

unit_marktest() {
step "One outline means this one, and the rest steps back"
# Stripped-down UI C1 and C2 (Jon, Nov 9): the one mint outline on what you
# point at and what a card will hit, a dashed line between them, nothing at
# rest; out of moves, the screen dims round END TURN, which lights ember,
# and nothing clickable moves.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet marktest 300 \
	"the one outline, the dashed line and the dim round END TURN hold" \
	"the highlight or the dim is wrong (sheet=MarkTest)" \
	--headless --path "$PROJECT" -- sheet=MarkTest
}

unit_tagtest() {
step "Tooltips are one sentence at the thing; a card's words answer the pointer; JUMP is the plate"
# Stripped-down UI T1, T2 and C3 (Jon, Nov 9): the torn tag above the thing,
# one sentence, no title; each keyword on a card its own hover target with
# its sentence on the card's picture; the chart's JUMP a big ember plate with
# the star's name, the panel down to danger, fuel and warnings.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet tagtest 300 \
	"the tags, the keyword tags and the jump plate hold" \
	"a tooltip, a keyword tag or the chart's plate is wrong (sheet=TagTest)" \
	--headless --path "$PROJECT" -- sheet=TagTest
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
# An event's result says what moved, in every look and layout, and nothing pressable moves.
# Why: docs/why/validate.md#unit_outcometest
GATE_FAIL_RE='FAIL' ALLOW_EXTRA="$GATE_LEAKS" gate_sheet outcometest 240 \
	"every look says what moved, fits, and C flies without moving a button" \
	"an event's result misstates or overlaps what you end up with" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=OutcomeTest
}

unit_rewardshowntest() {
step "A result that gave you something to take shows REWARD"
# Every option, every choice, every band of a checked one (SkillCheck.forced),
# through LOCAL's event band: what landed on the system's pile, read off the
# run, has REWARD on the result, and nothing else does; nothing that paid out
# skips its result; CONTINUE past an unopened REWARD leaves it under SECTOR
# LOOT; the quest events are in the sweep. REWARD was keyed on `module` alone
# and 160 material outcomes said CONTINUE (Jon, Oct 22).
GATE_FAIL_RE='FAIL' ALLOW_EXTRA="$GATE_LEAKS" gate_sheet rewardshowntest 300 \
	"every outcome that put something on the pile shows REWARD" \
	"an event paid into SECTOR LOOT with no REWARD on its result" \
	--headless --path "$PROJECT" -- sheet=RewardShownTest
}

unit_lootopentest() {
step "Loot opens where it is"
# Jon, Nov 9 (stripped-down UI A2): a wreck's loot is no window. Through the
# real LOCAL, animated: a click on the wreck pushes the camera in on it, its
# things float out on a plate, the hold slides in, nothing takes a click till
# it rests, the box test at rest, a take and a put-back through the view's
# handlers, a partner's claim greyed, DONE eases out and the scene is back to
# the pixel; SECTOR LOOT and REWARD open the pile at your ship; reduced motion
# at rest at once; no camera off LOCAL.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet lootopentest 180 \
	"a wreck's loot opens where it lies and shuts back to the pixel" \
	"the loot view's camera, hold or plate is off, or the scene did not come back" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=LootOpenTest
}

unit_gradesheet() {
step "A graded hull keeps its palette"
# HullGrade bakes each weight's one hull at C, B, A and S (Jon's AB+DEF) and
# may only use colours the sprite already has, plus the manufacturer's band
# ramp; the lights are additive and drawn apart. Each weight on its own base
# sprite: light c, medium a, heavy a.
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
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet idlesoundtest 180 \
	"the idle bed follows the idle flame" \
	"the idle bed does not follow the idle flame" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=IdleSoundTest
}

unit_soundmomenttest() {
step "October's effects are heard, once, on the frame each picture acts"
# Each picture's sound is heard once, on its frame, read from the audio tape (audio is off headless).
# Why: docs/why/validate.md#unit_soundmomenttest
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet soundmomenttest 300 \
	"every moment's sound plays once, on its frame, at its level" \
	"a moment's sound is missing, doubled, early or late" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=SoundMomentTest
}

unit_welcometest() {
step "Jon's welcome note: once per profile, and on the title menu"
# Opens by itself on a fresh profile's title, word for word and inside the
# screen; marked seen only when CLOSED; never again after; MESSAGE FROM JON
# above QUIT opens it again. Then a first launch (Oct 17): NEW RUN on a fresh
# profile goes straight to the hull pick, no seed panel (it stays with a save),
# and LAUNCH lands on LOCAL with no tour. `welcome` lets it run under the
# harness, in its own scratch settings.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet welcometest 120 \
	"the welcome note shows once and comes back from the menu" \
	"the welcome note failed" \
	--headless --path "$PROJECT" -- sheet=WelcomeTest welcome
}

unit_yardfronttest() {
step "The banner shipyard: pick a manufacturer, pick a ship, LAUNCH"
# Jon's W2 v10 front door (Nov 10). A fresh profile's hall: Korvan named, six
# ??? banners, SELECT A SHIP and no LAUNCH; pointing at a hull shows its facts
# off the live refit, a click picks it and LAUNCH appears, a click away clears it; a ??? banner brings
# tarps, the lock line, and nothing can launch; Korvan's brings the ships and
# the pick back; LAUNCH lands on LOCAL in the picked hull; developer mode opens
# every banner. Every state box-tested. Same exit-time leak allowance as stowtest.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet yardfronttest 240 \
	"the banner yard picks, locks and launches" \
	"the banner yard misbehaved" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=YardFrontTest
}

unit_shiplifttest() {
step "The heavy lift: LAUNCH and UNDOCK lift off and go"
# Jon's L1 (Nov 12) on both screens: LAUNCH lifts the hull off its stands and
# burns it off right before the run starts, once, with no click reaching the
# hall meanwhile, and reduced motion cuts straight to LOCAL; UNDOCK runs the
# same lift on the Shipyard deck, off to the right, and lands on LOCAL undocked.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet shiplifttest 240 	"the heavy lift lifts off and lands where it should" 	"the heavy lift misbehaved" 	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=ShipLiftTest
}

unit_mirrorlocaltest() {
step "LOCAL moored on the station's right, and the partners in it"
# Jon's (c) and his co-op rules (Nov 13): after an undock LOCAL at the station is
# drawn mirrored; everyone faces right, names read, partners come out of the
# mouth, go into it or fade, the mooring is saved, and clicks land where drawn.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet mirrorlocaltest 240 	"LOCAL is drawn both ways round with its partners" 	"LOCAL moored on the right misbehaved" 	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=MirrorLocalTest
}

unit_yardperftest() {
step "The banner shipyard's click stays cheap and looks the same"
# Nov 12, Jon: "VERY laggy". A banner's first click baked three hulls on the main
# thread (0.6 s); now every open banner's are baked ahead on a worker, each the
# main thread's picture byte for byte. The ship map in bytes equals the old
# per-pixel one for every set, and the floor pools bake once. Counts, never times.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet yardperftest 240 	"the banner yard bakes ahead and its ship map is unchanged" 	"the banner yard's bakes or ship map changed" 	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=YardPerfTest
}

unit_launchtiertest() {
step "LAUNCH A RUN: the tier stops, the galaxy by tier, the record"
# Jon's T1 (Nov 10). On a scratch flight record: no win opens tier 0 alone, and a
# tier 0 win opens 1; a stop past best + 1 refuses a click; a pick reaches the run's level and the
# galaxy's form, and the won run goes on the record with its tier, which opens the
# next; the fresh-profile skip still launches at 0; the box on screen at every tier.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet launchtiertest 180 \
	"the tiers pick, lock and reach the run" \
	"the tier box misbehaved" \
	--headless --fixed-fps 60 --path "$PROJECT" -- sheet=LaunchTierTest
}

unit_scrollcheck() {
step "No scroll bar on the sector map's panel covers a word"
# Jon, Oct 20, on the WORLD card: "the scroll bar covers up text". Over the
# run's first 40 systems, the sector's list and every world's page, unscrolled
# and scrolled to the end: no text and nothing that takes the mouse within
# UITheme.BAR_GAP of the bar as drawn, and no page asking for more than the
# text column (Nov 1: an event card asked for 231 px of the 226, widening the
# panel under its bar). It fails if no page scrolled at all.
GATE_FAIL_RE='FAIL|^scrollcheck|  scrollcheck' gate_sheet scrollcheck 240 \
	"the sector panel's words stay clear of its scroll bar" \
	"something on the sector panel sits under its scroll bar" \
	--headless --path "$PROJECT" -- sheet=SystemShot scrollcheck
}

unit_yardseattest() {
step "Every hull sits on its yard stands, centred"
# Jon: "The ship needs to sit lower. Like actually be on the stands and centered
# on them." Every hull frame at every grade on every level's stands, measured
# off the pictures: no floor between belly and cap, resting on the cap's seat
# row, the stands' middle within 1 px of the hull's mass middle, one height.
gate_sheet yardseattest 120 \
	"every hull on its stands" \
	"a hull floats over, or stands off the middle of, its yard stands" \
	--headless --path "$PROJECT" -- sheet=YardSeatTest
}

unit_yardinfofit() {
step "What a picked ship comes with fits the band"
# Jon's B2 (Nov 12): the maker, the fitted parts spelled out, the hand and the
# deck, every open maker's three ships picked; nothing overlaps, nothing leaves
# the band, the weapons are on the hull and on its sharp copy over the blur.
gate_sheet yardinfofit 180 	"what a ship comes with fits the band" 	"the ship pick's maker block, parts list or deck stack overlaps or leaves the band" 	--headless --path "$PROJECT" -- sheet=YardInfoFit
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
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' 	run_godot fightcounttest 660 --headless --path "$PROJECT" -- sheet=FightCountTest; then
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
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet killholdtest 180 \
	"a kill leaves the pack where it stood" \
	"a kill moved the pack, or the breakup and its wreck disagree" \
	--headless --path "$PROJECT" -- sheet=KillHoldTest
}

unit_packlayouttest() {
step "Nothing in a fight sits on anything else"
# Nothing in a fight overlaps another ship, wreck, name, bar, chip or intent, in the formation and the column.
# Why: docs/why/validate.md#unit_packlayouttest
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
	run_godot packlayouttest 660 --headless --path "$PROJECT" -- sheet=PackLayoutTest; then
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
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet oneholetest 120 \
	"the core and the pulsars are drawn once, every other place keeps its picture" \
	"a star is drawn twice on LOCAL, or a place lost its picture" \
	--headless --path "$PROJECT" -- sheet=OneHoleTest
}

unit_faunatest() {
step "The Custodian and the megafauna move, and are still for their deaths"
# FaunaMotion, headless: the cut at full size and from a half sheet, idle,
# the wind-up, and settle() at rest in four frames on the picture it was cut
# from; then the real fight, animated, on each of the three: the art hands its
# picture to the motion, the bob is the motion's, Charging and a creature's
# strike wind it up, a kill is at rest when the breakup is cut, and the dead
# slot is the art's wreck again. Reduced motion has none of it.
ALLOW_EXTRA="$GATE_LEAKS" gate_sheet faunatest 300 \
	"the three move, wind up and come to rest for their deaths" \
	"a creature's or the Custodian's motion is wrong" \
	--headless --path "$PROJECT" -- sheet=FaunaTest
}

unit_threadstress() {
step "Worker threads make no textures, nodes or materials"
# The fight's off-thread cuts (a creature's or the Custodian's motion, a
# breakup ahead of a kill, a wreck) run back to back for 20 s while the main
# thread loads card art and makes textures: no engine error at all. Before
# Oct 14 the cuts made their textures on the worker and raced the main
# thread's (26 errors in 20 s here; faunatest's rare "wrong RID").
GATE_FAIL_RE='error:|^threadstress' ALLOW_EXTRA="$GATE_LEAKS" gate_sheet threadstress 120 \
	"the cuts run on workers beside the main thread's textures without a race" \
	"an off-thread cut raced the main thread's textures" \
	--headless --path "$PROJECT" -- sheet=ThreadStress secs=20
}

unit_chartaheadtest() {
step "The run's star chart is built ahead, star for star"
# The run's star chart is built ahead on a worker, star for star the field the chart builds itself.
# Why: docs/why/validate.md#unit_chartaheadtest
GATE_FAIL_RE='FAIL|error:|^chartaheadtest' ALLOW_EXTRA="$GATE_LEAKS" gate_sheet chartaheadtest 180 \
	"the first chart of a run is built ahead, the same field it would build" \
	"the chart's field built ahead is wrong, unused, or read what it should not" \
	--headless --path "$PROJECT" -- sheet=ChartAheadTest
}

unit_localeventtest() {
step "Every event opens and resolves on LOCAL"
# The one place a choice is taken now: LOCAL's event band. Every authored
# option is opened and every choice resolved through it, in all three layouts.
gate_sheet localeventtest 300 \
	"every event resolves on LOCAL" \
	"an event failed to open or resolve on LOCAL" \
	--headless --path "$PROJECT" -- localeventtest
}

unit_optiontest() {
step "The option table rolls a legal system every time"
# Also never gated, and it is the only thing checking the content that landed
# tonight: 42 options, unique ids, every rolled option admitted by its own gate,
# counts and groups inside the tier plan, and no system left with nothing to do.
GATE_TAIL=12 gate_check optiontest 180 \
	"options roll legally" \
	"the option table rolled something illegal" \
	--headless --path "$PROJECT" -- optiontest
}

unit_routinetest() {
step "Every routine does what it says, where it happens"
# Science (Phase 12): the twelve routines the Lab writes into the flight
# computer, each read where the thing it changes happens (RunState's stat
# functions, Combat, `take_hull_damage`), every check from a USED run: the six
# stat routines before and after, the pips by exactly 1, WARM START and FIRST
# LOOK on the first turn only, COLD OPEN, PATCH CREW, BLACK BOX holding the ship
# at 1 once (and on the fight screen), all twelve through a hull swap, a new
# run's and a load's order, and the sim's `routines=`.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
		run_godot routinetest 180 --headless --path "$PROJECT" -- sheet=RoutineTest; then
	if grep -qE '^routinetest: PASS' "$LOG_DIR/routinetest.log"; then
		ok "each routine changes its one thing and nothing else"
	else
		bad "a routine changed the wrong thing, or nothing"
		grep -E '^  FAIL|^routinetest' "$LOG_DIR/routinetest.log" | head -n 12 | sed 's/^/        /'
	fi
fi
}

unit_augmenttest() {
step "The Lab's services: augment, strip, the board and the bench"
# Science (Phase 12), with no screen in the way: AUGMENT's offer is three of
# the eight, the same three each look and drawn from no stream; one affix a
# part, ever, and its price, quote and cards do not move; STRIP; the board's
# steps at 6, 10, 15 and DATA never below 0; the bench's DEVELOP FILM and READ
# FOR DATA; and with `Run.science_off` every service refuses.
if run_godot augmenttest 120 --headless --path "$PROJECT" -- sheet=AugmentTest; then
	if grep -qE '^augmenttest: PASS' "$LOG_DIR/augmenttest.log"; then
		ok "the Lab augments, strips, sells steps and reads film by its rules"
	else
		bad "a Lab service broke its rule"
		grep -E '^  FAIL|^augmenttest' "$LOG_DIR/augmenttest.log" | head -n 12 | sed 's/^/        /'
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
GATE_TAIL=12 gate_check systemtest 180 \
	"every system lays out cleanly" \
	"a system laid out wrong" \
	--headless --path "$PROJECT" -- systemtest
}

unit_weathertest() {
step "The sector map's weather keeps its schedule"
# The weather's scheduler alone (`SkyWeather`), two hours of every sky at every
# temperament with no picture: one event at a time, showpieces rare, nothing
# under a busy hold or with reduced motion, and every event in the table able
# to fire -- a dead entry is weather nobody will ever see, and nothing else
# would notice.
GATE_TAIL=12 gate_check weathertest 180 \
	"the weather keeps its schedule" \
	"the weather's scheduler broke a rule" \
	--headless --path "$PROJECT" -- weathertest
}

unit_namefit() {
step "A destination name fits the height the panel reserves for it"
# The right-hand panel is as tall as its content and the chart shares a row with
# it, so a name that wraps one line further than the panel reserves moves the
# whole screen -- reported as the chart changing size when a particular system
# was selected. The reserve is two lines; this says two is still enough.
GATE_FAIL_RE='^  FAIL|^  worst|^namefit' GATE_TAIL=10 gate_check namefit 120 \
	"every destination name fits two lines" \
	"a system name needs more lines than the panel reserves" \
	--headless --path "$PROJECT" -- namefit
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
gate_check chartfilter 120 \
	"chart filter" \
	"the chart's KNOWN ONLY view reveals too much of the galaxy" \
	--headless --path "$PROJECT" -- chartfilter
}

unit_chartdeeptest() {
step "The chart dims stars in reach that are too deep to jump to"
# Ruling 13 A (Jon, Oct 27): a star inside the reach ring that a jump refuses
# for depth looked like any other until JUMP said TOO DEEP (Geno, near the top
# of the tilted map). Three galaxies through the real chart, zoomed out and in:
# every such star drawn dimmed, read off its ink as drawn, under the cursor and
# picked too; every reachable star in its own colour; nothing else dimmed; the
# readout and JUMP saying TOO DEEP.
GATE_FAIL_RE='FAIL|^chartdeeptest|^    ' ALLOW_EXTRA="$GATE_LEAKS" gate_sheet chartdeeptest 180 \
	"too-deep stars in reach drawn dimmed, reachable ones not" \
	"the chart draws a too-deep star in reach like a reachable one, or says it wrong" \
	--headless --path "$PROJECT" -- sheet=ChartDeepTest
}

unit_reactor() {
step "Every frame launches with a deck it can play"
# The reactor cap decides how many modules a frame can RUN, and a cap set too
# low does not produce a small ship — it produces a ship whose every turn is
# identical, because the deck is no bigger than the hand. That failure is
# invisible in every other check: the save is valid, the numbers add up, the
# simulator still finishes its runs. It only shows up as a game with nothing to
# decide, and the medium's second utility mount exists because it happened once
# already.
GATE_FAIL_RE='^  FAIL|THIN|^reactor' gate_check reactor 120 \
	"reactor" \
	"a frame cannot launch with a playable deck" \
	--headless --path "$PROJECT" -- reactor
}

unit_mounts() {
step "Every hull's mounts land on the hull"
# Cheap, and it guards a failure with no other symptom. The dorsal, ventral and
# flank lines are measured off ONE image each by art/tools/anchors.py, so
# replacing a hull sprite without re-running the tool leaves the old line
# describing art that no longer exists — the ship draws its guns in clear space
# beside itself, nothing throws, and the only way to see it is to open that hull
# at that class. It caught exactly that on the swap of Korvan's heavy B.
gate_check mounts 120 \
	"mounts" \
	"a hardpoint is not on its hull" \
	--headless --path "$PROJECT" -- mounts
}

unit_artcheck() {
step "No sprite is the wrong size for the box it sits in"
# A wrong-sized sprite draws fine and is quietly wrong. Passes with art missing; fails a file that does not fit.
# Why: docs/why/validate.md#unit_artcheck
GATE_FAIL_RE='^  FAIL|OVERHANGS|UNDERSIZED|TOO BIG|^artcheck' gate_check artcheck 120 \
	"artcheck" \
	"a sprite does not fit the box it is drawn in" \
	--headless --path "$PROJECT" -- artcheck
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
	gate_no_python "the shop-room check"
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
	gate_no_python "the lab check"
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
	gate_no_python "the yard check"
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
	gate_no_python "the enemy-picture check"
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
	gate_no_python "the rail check"
fi
}

unit_fittest() {
step "A part can be moved between the hold and the hull"
# A part moves between the hold and the hull. Once written off as flaky; it was a real drop-target bug.
# Why: docs/why/validate.md#unit_fittest
gate_check fittest 120 \
	"fittest" \
	"a part cannot be moved between the hold and the hull" \
	--headless --path "$PROJECT" -- fittest
}

unit_parseall() {
step "Every script in the project parses"
# `--check-only` misses scripts loaded by hand, so this loads every .gd and reports the ones that fail.
# Why: docs/why/validate.md#unit_parseall
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
# rngtest enforces the named-stream rule: a run must replay from its seed, or co-op peers disagree about the galaxy.
# Why: docs/why/validate.md#unit_rngtest
gate_check rngtest 120 \
	"rng replays from its seed" \
	"seeded RNG test failed" \
	--headless --path "$PROJECT" -- rngtest
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

unit_sciencesimtest() {
step "The sim pilot flies science"
# Science (Phase 12): `-- sim science=on|off|ignore` and Policy's choices. The
# flag sets the world and the pilot; with science off no science event rolls
# and DATA stays 0; a reading takes the risky line on a full tank, the careful
# one when hurt, the buyer's credits behind the fuel gate; at a dock film is
# read before it is sold, the cheapest step is bought, AUGMENT keeps the
# reserve and goes on once a visit; and five seeded runs of the sim's own loop
# earn DATA, buy a step and print the report's `science:` lines.
if ALLOW_EXTRA='resources still in use at exit|RID allocations of type .* were leaked at exit' \
		run_godot sciencesimtest 300 --headless --path "$PROJECT" -- sheet=ScienceSimTest; then
	if grep -qE '^sciencesimtest: PASS' "$LOG_DIR/sciencesimtest.log"; then
		ok "the sim pilot reads, buys and augments by its rules"
	else
		bad "the sim pilot broke a science rule"
		grep -E '^  FAIL|^  on seed|^sciencesimtest' "$LOG_DIR/sciencesimtest.log" | head -n 12 | sed 's/^/        /'
	fi
fi
}

unit_sim() {
step "Simulator plays $SIM_RUNS complete runs"
# A smoke test, not a measurement: read `errors`, never `wins` (unseeded, about +/-15 points at 40 runs).
# Why: docs/why/validate.md#unit_sim
if run_godot sim $((90 + SIM_RUNS * 9)) --headless --path "$PROJECT" -- sim "runs=$SIM_RUNS"; then
	if grep -qE '^runs [0-9]+ · wins' "$LOG_DIR/sim.log"; then
		ok "simulator reached its report"
		grep -E '^runs |^avg |^looted |^death causes|^stranded|^science:|^routines:' "$LOG_DIR/sim.log" | sed 's/^/        /'
		# SCIENCE (Phase 12). The gate's sim flies science on (the default), so
		# the report has its `science: DATA` line, and forty runs that earned
		# no DATA at all mean the readings, the bench or the pilot stopped
		# paying. (`science=ignore` prints DATA 0.0 on purpose; the gate never
		# runs it.)
		if ! grep -qE '^science: DATA ' "$LOG_DIR/sim.log"; then
			bad "the sim's report has no science: DATA line (science on is the default)"
		elif grep -qE '^science: DATA 0\.0 a run' "$LOG_DIR/sim.log"; then
			bad "the sim earned no DATA in $SIM_RUNS runs with science on"
		fi
	else
		bad "simulator never printed its report — a run is stuck or the boot path changed"
		tail -n 20 "$LOG_DIR/sim.log" | sed 's/^/        /'
	fi
fi
}

unit_pysyntax() {
step "Audio generators are valid Python"
# Syntax only: rendering needs numpy and 850 MB. The interpreter is found by running it, not `command -v`.
# Why: docs/why/validate.md#unit_pysyntax
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
	gate_no_python "the audio syntax check"
fi
}

unit_musiclab() {
step "The music lab still holds together"
# The lab HTML is the music's source, so check_cue.mjs and check_lab.mjs gate it. Skipped without node or its deps.
# Why: docs/why/validate.md#unit_musiclab
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
# A changed save, wire or persistence shape must take its version with it; run against the diff from main.
# Why: docs/why/validate.md#unit_versionguard
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
	# A base git cannot find must fail the guard, not read as an empty diff.
	if "$PY" .github/scripts/version_guard.py no-such-rev-for-the-guard 2>&1 | grep -q 'version guard: PASS'; then
		bad "the version guard passed a base that does not exist"
	fi
else
	gate_no_python "the version guard"
fi
}

unit_enclint() {
step "Encounters follow their own rulings"

# Encounter rules found by hand are patterns, baselined so the gate could be switched on: --strict fails on new findings only.
# Why: docs/why/validate.md#unit_enclint
if [ -n "$PY" ]; then
	if "$PY" tools/encounter_lint.py --strict >"$GATE_UNIT_DIR/enclint.out" 2>&1; then
		ok "encounters: no new findings"
	else
		sed -n '/^ERRORS/,$p' "$GATE_UNIT_DIR/enclint.out" | grep "NEW" | head -20
		bad "encounters: new lint findings (see above)"
	fi
else
	gate_no_python "the encounter linter"
fi
}

unit_prose() {
step "The prose reads plainly, and does not explain itself"

# prose_grade holds encounters to the reading level; prose_tells reads every player-facing string, baselined like the linter.
# Why: docs/why/validate.md#unit_prose
if [ -n "$PY" ]; then
	if "$PY" tools/prose_grade.py >"$GATE_UNIT_DIR/prosegrade.out" 2>&1; then
		ok "prose grade: $(tail -n 1 "$GATE_UNIT_DIR/prosegrade.out")"
	else
		tail -n 1 "$GATE_UNIT_DIR/prosegrade.out" | sed 's/^/        /'
		bad "prose grade: encounters over the reading-level target (python tools/prose_grade.py)"
	fi
	if "$PY" tools/prose_tells.py --strict --quiet >"$GATE_UNIT_DIR/prosetells.out" 2>&1; then
		ok "prose tells: no new findings"
	else
		grep -A1 "NEW " "$GATE_UNIT_DIR/prosetells.out" | head -20 | sed 's/^/      /'
		bad "prose tells: new findings (see above; python tools/prose_tells.py)"
	fi
else
	gate_no_python "the prose checks"
fi
}

unit_commentcheck() {
step "Long reasoning lives in docs/why/, and every pointer to it resolves"
# No .gd file holds a comment run over five lines, and every
# `docs/why/<file>.md#<anchor>` in the code names a real heading.
if [ -n "$PY" ]; then
	if "$PY" tools/comment_check.py >"$GATE_UNIT_DIR/commentcheck.out" 2>&1; then
		ok "$(tail -n 1 "$GATE_UNIT_DIR/commentcheck.out")"
	else
		head -n 20 "$GATE_UNIT_DIR/commentcheck.out" | sed 's/^/        /'
		bad "comment check: broken why-pointers or long comment runs (python tools/comment_check.py)"
	fi
else
	gate_no_python "the comment check"
fi
}

unit_codecheck() {
step "No new long functions, huge files or bare Dictionary/Array/Variant returns"
# A ratchet: game code (not sim) may have no function over 100 lines, no file over
# 3000, no new function returning a bare Dictionary, Array or Variant. What predates
# it is in `tools/code_check_baseline.txt` and may not grow (docs/why/code_check.md).
if [ -n "$PY" ]; then
	if "$PY" tools/code_check.py >"$GATE_UNIT_DIR/codecheck.out" 2>&1; then
		ok "$(tail -n 1 "$GATE_UNIT_DIR/codecheck.out")"
	else
		head -n 20 "$GATE_UNIT_DIR/codecheck.out" | sed 's/^/        /'
		bad "code check: new long functions, huge files or bare returns (python tools/code_check.py)"
	fi
else
	gate_no_python "the code check"
fi
}

unit_codegraph() {
step "No new link that breaks the layering, no new call into another class's private method"
# A ratchet: game code may not reach into sim; systems, data and net may not reach into ui;
# data may not reach into systems or net; no new call to an unrelated class's `_private`.
# What predates it is in `tools/code_graph_baseline.txt` (docs/why/code_graph.md).
if [ -n "$PY" ]; then
	# The self-test first: the extractor must read a tiny synthetic tree exactly, or its verdict on the real one is not trusted.
	if ! "$PY" tools/code_graph.py --selftest >"$GATE_UNIT_DIR/codegraph.out" 2>&1; then
		head -n 20 "$GATE_UNIT_DIR/codegraph.out" | sed 's/^/        /'
		bad "code graph self-test failed: the extractor misread its synthetic tree (python3 tools/code_graph.py --selftest)"
	elif "$PY" tools/code_graph.py >>"$GATE_UNIT_DIR/codegraph.out" 2>&1; then
		ok "$(tail -n 1 "$GATE_UNIT_DIR/codegraph.out")"
	else
		head -n 20 "$GATE_UNIT_DIR/codegraph.out" | sed 's/^/        /'
		bad "code graph: a new layering break or private reach-in (python3 tools/code_graph.py)"
	fi
else
	gate_no_python "the code graph"
fi
}

unit_framecheck() {
step "No new work in a per-frame function that belongs in _ready"
# A ratchet: a function the engine runs every frame (`_process`, `_physics_process`, `_draw`, and what
# those call in the same file) may not load a resource, build an Image or texture, parse a colour from a
# string, search the tree, open a file, parse JSON, deep-copy or build a material, unless it is lazy
# initialisation. What predates it is in `tools/frame_check_baseline.txt` (docs/why/frame_check.md).
if [ -n "$PY" ]; then
	# The self-test first: the detector must read a tiny synthetic tree exactly, or its verdict on the real one is not trusted.
	if ! "$PY" tools/frame_check.py --selftest >"$GATE_UNIT_DIR/framecheck.out" 2>&1; then
		head -n 20 "$GATE_UNIT_DIR/framecheck.out" | sed 's/^/        /'
		bad "frame check self-test failed: the detector misread its synthetic tree (python3 tools/frame_check.py --selftest)"
	elif "$PY" tools/frame_check.py >>"$GATE_UNIT_DIR/framecheck.out" 2>&1; then
		ok "$(tail -n 1 "$GATE_UNIT_DIR/framecheck.out")"
	else
		grep -v 'selftest: PASS' "$GATE_UNIT_DIR/framecheck.out" | head -n 40 | sed 's/^/        /'
		bad "frame check: new work in a per-frame function (python3 tools/frame_check.py; --report lists all of it)"
	fi
else
	gate_no_python "the frame check"
fi
}

unit_testsmap() {
step "Every runnable harness has a row in docs/tests.md"
# A ratchet: each harness in tkg/scripts/sim that DevFlags can start is named in docs/tests.md; no row
# names a harness or flag that is gone; validate.sh names none that is gone. What predates it is in
# `tools/tests_map_check_baseline.txt` (docs/why/tests_map_check.md).
if [ -n "$PY" ]; then
	if ! "$PY" tools/tests_map_check.py --selftest >"$GATE_UNIT_DIR/testsmap.out" 2>&1; then
		head -n 20 "$GATE_UNIT_DIR/testsmap.out" | sed 's/^/        /'
		bad "tests map self-test failed: the check misread its synthetic tree (python3 tools/tests_map_check.py --selftest)"
	elif "$PY" tools/tests_map_check.py >>"$GATE_UNIT_DIR/testsmap.out" 2>&1; then
		ok "$(tail -n 1 "$GATE_UNIT_DIR/testsmap.out")"
	else
		grep -v 'selftest: PASS' "$GATE_UNIT_DIR/testsmap.out" | head -n 40 | sed 's/^/        /'
		bad "tests map: a harness with no row in docs/tests.md, or a row or unit naming one that is gone (python3 tools/tests_map_check.py)"
	fi
else
	gate_no_python "the tests map check"
fi
}

unit_gatelint() {
step "The gate script is sound: no unit defined twice, no list or weight naming a missing unit, no dead why-pointer"
# No baseline: all of it is zero and stays zero (docs/why/gate_lint.md).
if [ -n "$PY" ]; then
	if ! "$PY" tools/gate_lint.py --selftest >"$GATE_UNIT_DIR/gatelint.out" 2>&1; then
		head -n 20 "$GATE_UNIT_DIR/gatelint.out" | sed 's/^/        /'
		bad "gate lint self-test failed: the lint misread its synthetic script (python3 tools/gate_lint.py --selftest)"
	elif "$PY" tools/gate_lint.py >>"$GATE_UNIT_DIR/gatelint.out" 2>&1; then
		ok "$(tail -n 1 "$GATE_UNIT_DIR/gatelint.out")"
	else
		grep -v 'selftest: PASS' "$GATE_UNIT_DIR/gatelint.out" | head -n 20 | sed 's/^/        /'
		bad "gate lint: validate.sh has a duplicate unit, a name no unit has, or a dead pointer (python3 tools/gate_lint.py)"
	fi
else
	gate_no_python "the gate lint"
fi
}

unit_vocab() {
step "One word for the thing: manufacturer"
# One word for the thing: `manufacturer`. Case-insensitive, an underscore is a separator, the exemptions are narrow.
# Why: docs/why/validate.md#unit_vocab
VOCAB=$(
	{
		# Pass A -- house/maker, everywhere, no prose exemption.
		grep -rniE '(^|[^A-Za-z0-9])(house|houses|maker|makers|brand|brands|marque|marques)([^A-Za-z0-9]|$)' "$PROJECT/scripts" --include='*.gd' 2>/dev/null
		# Pass B -- the short word, everywhere.
		grep -rniE '(^|[^A-Za-z0-9])(man|hull_man)([^A-Za-z0-9]|$)' "$PROJECT/scripts" --include='*.gd' 2>/dev/null
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

# The same check on prose; docs/archive/ and this rule's own explanation are out of scope.
# Why: docs/why/validate.md#unit_vocab
VOCAB_DOCS=$(
	grep -rniE '(^|[^A-Za-z0-9])(house|houses|maker|makers|brand|brands|marque|marques)([^A-Za-z0-9]|$)' docs tkg/*.md 2>/dev/null \
	  | grep -v '^docs/archive/' \
	  | grep -v '^docs/why/validate.md:' \
	  | grep -viE 'widowmaker|gatehouse' \
	  | grep -v "maker's mark" \
	  | grep -v 'house style' \
	  | grep -v 'never .house. or .maker.' \
	  | grep -v 'wrong for anyone outside the house' \
	  | grep -v '`maker`' \
	  | grep -v '`makers`' \
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
#   calmladdertest   fixed fps, but a partner's ship eases on by the wall clock
#                    (`_draw_partners`), so one slow frame is one jump past 40 px
SOLO_UNITS="maplagtest gameclocktest playerdeathtest faunatest threadstress lowhulltest ashteachcosttest flightclicks sim calmladdertest"
# THE STATIC UNITS: GATE_STATIC=1, tools/dev/check.sh and the pre-commit hook run
# exactly these. A unit qualifies when nothing in its body starts Godot (no
# run_godot, gate_sheet, gate_check or $GODOT): plain shell, python or node, so
# it needs no import and runs in seconds. A new unit of that kind goes here too.
STATIC_UNITS="tabs changes pysyntax musiclab versionguard enclint prose commentcheck codecheck codegraph framecheck testsmap gatelint vocab enemysprites labs rail rooms yard"
# Run first and alone, because every other unit needs what it writes: the class
# cache in .godot/, without which nothing compiles.
FIRST_UNITS="import"
# Run after the pool, before the SOLO units: the split tests' totals, which read
# their shards' logs (`gate_shard_sum`); each takes a few seconds.
AFTER_UNITS="flighttest solvetest"

# Seconds each unit took on the 4-core CI runner (Nov 8; about half that on a
# Mac). The pool starts the heaviest first, so the longest runs are never the
# last to begin, and GATE_PART deals by these. Only the ORDER and the balance
# depend on them; a wrong one costs minutes, never a result. Unlisted units
# count as 15.
gate_weight() {
	case "$1" in
		orbitworldtest) echo 407 ;; packlayouttest) echo 328 ;; fightcounttest) echo 314 ;;
		twinsitetest) echo 289 ;; laddertest) echo 254 ;; ashtest) echo 250 ;;
		maptest) echo 222 ;; twindrawtest) echo 187 ;; flighthand) echo 187 ;;
		wrecksitetest) echo 187 ;; ashtutortest) echo 159 ;; enemyarttest) echo 149 ;;
		dockflytest) echo 141 ;; localeventtest) echo 116 ;;
		soundmomenttest) echo 114 ;; cutawaytest) echo 112 ;; subjecttest) echo 91 ;;
		stationdecktest) echo 86 ;; popplacetest) echo 75 ;; attrtest) echo 72 ;;
		fightlogtest) echo 66 ;; midjointest) echo 61 ;; flighttest_1) echo 59 ;;
		sidebartest) echo 56 ;; hinttest) echo 52 ;; gradesheet) echo 52 ;;
		flighttest_2) echo 50 ;; badgetest) echo 49 ;; mapperftest) echo 48 ;;
		lockedpooltest) echo 48 ;; outcometest) echo 48 ;; flighttest_3) echo 47 ;;
		calmladdertest) echo 47 ;; moontest) echo 46 ;; fightopentest) echo 46 ;;
		wreckloottest) echo 45 ;; menutest) echo 42 ;; pairlocaltest) echo 40 ;;
		rewardshowntest) echo 40 ;; scrollcheck) echo 40 ;; faunatest) echo 37 ;;
		marktest) echo 45 ;; tagtest) echo 35 ;;
		flightclicks) echo 36 ;; hulldamagetest) echo 35 ;; corewintest) echo 35 ;;
		threadstress) echo 32 ;; foetagtest) echo 32 ;; killholdtest) echo 31 ;;
		lowhulltest) echo 30 ;; contracttest) echo 27 ;; questlogtest) echo 26 ;;
		devtest) echo 25 ;; parseall) echo 25 ;; market) echo 24 ;;
		boardsigntest) echo 24 ;; systemtest) echo 24 ;; derelicttest) echo 23 ;;
		fueltest) echo 22 ;; deeploottest) echo 22 ;; goaltest) echo 21 ;;
		bindtest) echo 20 ;; swaptest) echo 20 ;; arriveidletest) echo 20 ;;
		nettest) echo 20 ;; solvetest_*) echo 170 ;;
		cometflighttest) echo 90 ;; cometcatchtest) echo 34 ;; arrivesidetest) echo 60 ;;
		sciencesimtest) echo 51 ;; routinetest) echo 28 ;; jumpshadertest) echo 90 ;;
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
# The same name defined twice means the later one silently wins (unit_codecheck
# was, for a week). Looser than the list above so `unit_x()` on a line of its own is seen too.
GATE_DUPS="$(sed -n 's/^unit_\([A-Za-z0-9_]*\)().*/\1/p' "$GATE_SELF" | sort | uniq -d | tr '\n' ' ')"
if [ -n "$GATE_DUPS" ]; then
	printf 'validate.sh: unit_%s is defined more than once; the later definition silently replaces the earlier. Rename or delete one.\n' "${GATE_DUPS%% *}" >&2
	exit 2
fi
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
for u in $SOLO_UNITS $FIRST_UNITS $AFTER_UNITS $STATIC_UNITS; do
	if ! gate_has_unit "$u" || ! declare -F "unit_$u" >/dev/null; then
		printf 'validate.sh: SOLO_UNITS, FIRST_UNITS, AFTER_UNITS or STATIC_UNITS names %s, and there is no unit_%s\n' "$u" "$u" >&2
		exit 2
	fi
done
# Nor a split test run in fewer shards than its totals add up, or more.
for gate_split in "flighttest $GATE_FLIGHT_SHARDS" "solvetest $GATE_SOLVE_SHARDS"; do
	set -- $gate_split
	gate_k=0
	for u in "${UNITS[@]}"; do
		case "$u" in "$1"_[0-9]*) gate_k=$((gate_k + 1)) ;; esac
	done
	if [ "$gate_k" -ne "$2" ]; then
		printf 'validate.sh: %s is split %s ways and has %s unit_%s_<K> functions\n' "$1" "$2" "$gate_k" "$1" >&2
		exit 2
	fi
	for ((gate_i = 1; gate_i <= $2; gate_i++)); do
		if ! gate_has_unit "$1_$gate_i"; then
			printf 'validate.sh: %s is split %s ways and has no unit_%s_%s\n' "$1" "$2" "$1" "$gate_i" >&2
			exit 2
		fi
	done
done
set --

# GATE_UNITS="a b c" or GATE_STATIC=1 runs only the units named (in file order);
# neither runs `import`, so a Godot unit named here needs an import already done.
GATE_PICK=""
if [ "${GATE_STATIC:-}" = 1 ]; then GATE_PICK="$STATIC_UNITS"; fi
if [ -n "${GATE_UNITS:-}" ]; then
	if [ -n "$GATE_PICK" ]; then
		printf 'validate.sh: give GATE_UNITS or GATE_STATIC=1, not both\n' >&2; exit 2
	fi
	GATE_PICK="$GATE_UNITS"
fi
if [ -n "$GATE_PICK" ]; then
	for u in $GATE_PICK; do
		if ! gate_has_unit "$u"; then
			printf 'validate.sh: GATE_UNITS names %s, and there is no such unit. The units are:\n' "$u" >&2
			printf '  %s\n' "${UNITS[*]}" | fold -s -w 100 >&2
			exit 2
		fi
	done
	GATE_KEPT=()
	for u in "${UNITS[@]}"; do
		if gate_in "$u" "$GATE_PICK"; then GATE_KEPT+=("$u"); fi
	done
	UNITS=(${GATE_KEPT[@]+"${GATE_KEPT[@]}"})
fi

# THE PARTS. GATE_PART=K/N runs the Kth of N parts of the gate, so CI can run
# the N parts on N machines at once (the whole gate is 108 CPU minutes on a
# 4-core runner). The units are dealt heaviest first by `gate_weight`, each
# to the part with the least so far; a split test's shards go with their total,
# which reads their logs. `import` runs in every part.
GATE_PART="${GATE_PART:-1/1}"
GATE_PART_K="${GATE_PART%/*}"
GATE_PART_N="${GATE_PART#*/}"
case "$GATE_PART" in
	*/*) case "$GATE_PART_K$GATE_PART_N" in ''|*[!0-9]*) GATE_PART_K=0 ;; esac ;;
	*) GATE_PART_K=0 ;;
esac
if [ "$GATE_PART_K" -lt 1 ] || [ "$GATE_PART_K" -gt "$GATE_PART_N" ]; then
	printf 'validate.sh: GATE_PART must be K/N with 1 <= K <= N, such as 2/4 (got %s)\n' "$GATE_PART" >&2
	exit 2
fi
gate_dealt_as() {  # the name a unit is dealt under: a split test's shard as its total
	local a
	for a in $AFTER_UNITS; do
		case "$1" in "$a"_[0-9]*) printf '%s\n' "$a"; return ;; esac
	done
	printf '%s\n' "$1"
}
gate_dealt_weights() {  # "weight name", heaviest first, a split test's shards added into its total
	local u g w last="" sum=0
	for u in "${UNITS[@]}"; do
		gate_in "$u" "$FIRST_UNITS" || printf '%s %s\n' "$(gate_dealt_as "$u")" "$(gate_weight "$u")"
	done | sort | {
		while read -r g w; do
			if [ "$g" = "$last" ]; then sum=$((sum + w)); else
				[ -n "$last" ] && printf '%s %s\n' "$sum" "$last"
				last="$g"; sum="$w"
			fi
		done
		[ -n "$last" ] && printf '%s %s\n' "$sum" "$last"
	} | sort -k1,1nr -k2,2
}
if [ "$GATE_PART_N" -gt 1 ]; then
	GATE_LOAD=()
	for ((gate_i = 0; gate_i < GATE_PART_N; gate_i++)); do GATE_LOAD[$gate_i]=0; done
	GATE_MINE=""
	while read -r gate_w gate_g; do
		gate_best=0
		for ((gate_i = 1; gate_i < GATE_PART_N; gate_i++)); do
			[ "${GATE_LOAD[$gate_i]}" -lt "${GATE_LOAD[$gate_best]}" ] && gate_best=$gate_i
		done
		GATE_LOAD[$gate_best]=$((GATE_LOAD[gate_best] + gate_w))
		[ "$((gate_best + 1))" -eq "$GATE_PART_K" ] && GATE_MINE="$GATE_MINE $gate_g"
	done < <(gate_dealt_weights)
	GATE_KEPT=()
	for u in "${UNITS[@]}"; do
		if gate_in "$u" "$FIRST_UNITS" || gate_in "$(gate_dealt_as "$u")" "$GATE_MINE"; then GATE_KEPT+=("$u"); fi
	done
	UNITS=(${GATE_KEPT[@]+"${GATE_KEPT[@]}"})
fi

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

# The order the units will run in. GATE_LIST=1 prints it and stops: nothing runs.
GATE_FIRST=()
GATE_AFTER=()
GATE_SOLO=()
GATE_POOL=()
GATE_POOL_ORDER=()
if [ "$GATE_JOBS" -gt 1 ]; then
	i=0
	for u in "${UNITS[@]}"; do
		if gate_in "$u" "$FIRST_UNITS"; then
			GATE_FIRST+=("$u")
		elif gate_in "$u" "$AFTER_UNITS"; then
			GATE_AFTER+=("$u")
		elif gate_in "$u" "$SOLO_UNITS"; then
			GATE_SOLO+=("$u")
		else
			# heaviest first; file order among equals
			GATE_POOL+=("$(gate_weight "$u") $i $u")
		fi
		i=$((i + 1))
	done
	while read -r _w _i u; do
		GATE_POOL_ORDER+=("$u")
	done < <(printf '%s\n' "${GATE_POOL[@]}" | sort -k1,1nr -k2,2n)
fi
if [ "${GATE_LIST:-}" = 1 ]; then
	if [ "$GATE_JOBS" -eq 1 ]; then
		for u in "${UNITS[@]}"; do printf 'serial\t%s\n' "$u"; done
	else
		for u in ${GATE_FIRST[@]+"${GATE_FIRST[@]}"}; do printf 'first\t%s\n' "$u"; done
		for u in ${GATE_POOL_ORDER[@]+"${GATE_POOL_ORDER[@]}"}; do printf 'pool\t%s\n' "$u"; done
		for u in ${GATE_AFTER[@]+"${GATE_AFTER[@]}"}; do printf 'after\t%s\n' "$u"; done
		for u in ${GATE_SOLO[@]+"${GATE_SOLO[@]}"}; do printf 'solo\t%s\n' "$u"; done
	fi
	rmdir "$LOG_DIR" 2>/dev/null
	exit 0
fi

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
	run_phase 1 ${GATE_FIRST[@]+"${GATE_FIRST[@]}"}
	run_phase "$GATE_JOBS" ${GATE_POOL_ORDER[@]+"${GATE_POOL_ORDER[@]}"}
	# (a part may hold none of these; bash 3.2 reads an empty array as unbound)
	run_phase "$GATE_JOBS" ${GATE_AFTER[@]+"${GATE_AFTER[@]}"}
	run_phase 1 ${GATE_SOLO[@]+"${GATE_SOLO[@]}"}
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
	gate_in "$u" "$AFTER_UNITS" && tag="  (after the pool)"
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
GATE_PART_NOTE=""
[ "$GATE_PART_N" -gt 1 ] && GATE_PART_NOTE=" (part $GATE_PART_K of $GATE_PART_N)"
printf '  wall %s with %d at once; the units add up to %s%s\n' \
	"$(gate_mmss "$GATE_WALL")" "$GATE_JOBS" "$(gate_mmss "$GATE_SUM")" "$GATE_PART_NOTE"

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
