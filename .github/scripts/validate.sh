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
bad()   { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAIL=1; }

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
run_limited() {
	local limit="$1"; shift
	"$@" &
	local pid=$!
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

step "Indentation is tabs (Godot requires it)"
SPACE_INDENTED="$(grep -rln '^ ' --include='*.gd' "$PROJECT" || true)"
if [ -n "$SPACE_INDENTED" ]; then
	bad "space-indented GDScript:"
	printf '%s\n' "$SPACE_INDENTED" | sed 's/^/        /'
else
	ok "no space-indented .gd files"
fi

step "Global class cache builds"
# REQUIRED before anything compiles at all: class_name registration lives in
# .godot/global_script_class_cache.cfg, which only --import writes, and .godot/
# is gitignored — so a fresh clone (which is what CI always is) has none.
run_godot import 420 --headless --path "$PROJECT" --import

step "Project boots and builds its UI"
# Not the simulator: this path constructs the theme, the HUD and a real screen,
# so it compiles the UI classes the simulator never touches.
run_godot boot 240 --headless --path "$PROJECT" --quit-after 240

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

step "The archive round-trips, and none of it has become an essay"
# Half machinery and half STYLE GATE. `docs/lore.md` §5 says an entry is a
# primary source that fits on one screen, and that is prose — it rots, and its
# failure mode is not a crash but an archive that has quietly turned into a
# wiki. This is the only thing that reads every entry on every commit.
if run_godot archivetest 120 --headless --path "$PROJECT" -- archivetest; then
	if grep -qE '^archivetest: PASS' "$LOG_DIR/archivetest.log"; then
		ok "archive"
	else
		bad "archive test failed"
		grep -E '^  FAIL|^archivetest' "$LOG_DIR/archivetest.log" | head -n 20 \
			| sed 's/^/        /'
	fi
fi

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

step "Simulator plays $SIM_RUNS complete runs"
# The repo's actual regression test. It has already caught an infinite draw
# loop and a structural map flaw; a balance change that crashes a run shows up
# here and nowhere else.
if run_godot sim $((90 + SIM_RUNS * 9)) --headless --path "$PROJECT" -- sim "runs=$SIM_RUNS"; then
	if grep -qE '^runs [0-9]+ · wins' "$LOG_DIR/sim.log"; then
		ok "simulator reached its report"
		grep -E '^runs |^avg |^death causes|^stranded' "$LOG_DIR/sim.log" | sed 's/^/        /'
	else
		bad "simulator never printed its report — a run is stuck or the boot path changed"
		tail -n 20 "$LOG_DIR/sim.log" | sed 's/^/        /'
	fi
fi

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

printf '\n'
if [ $FAIL -ne 0 ]; then
	printf '\033[31mVALIDATION FAILED\033[0m  logs in %s\n' "$LOG_DIR"
	exit 1
fi
printf '\033[32mVALIDATION PASSED\033[0m  logs in %s\n' "$LOG_DIR"
