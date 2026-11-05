#!/usr/bin/env bash
# run_battery.sh: the twin-stars battery on the PC or the Mac. The Mac's
# twin-build/run_all.sh list (docs/handoffs/2026-11-01-twin-stars/twin-build/
# run_all.sh), each run through tools/dev/godot.sh with its own throwaway
# profile, JOBS at once (default 8). It is the wide set of tests, not the gate.
#
# usage: bash tools/dev/run_battery.sh [WORKTREE] [names...]
#   WORKTREE defaults to the checkout this script is in. Names limit it to those
#   runs (`import` first whenever a change added a class_name or a file); the
#   name of a split test (`flighttest`, `solvetest`) runs all its shards and
#   their total.
# Logs in $OUT (default $TK_SCRATCH/battery)/<name>.log; one line a run in
# summary.txt, and the wall clock at the end.
#
# THE ORDER: one import; then every run that does not time itself, JOBS at a
# time, the longest first; then the totals of the split tests (below); then the
# four runs that time things (map perf and lag, thread stress), ALONE, so the
# parallel load cannot fail them. SOLO=0 skips those four (for agents running
# beside each other).
#
# THE SPLIT TESTS: FlightTest and SolveTest took about 600 and 690 s as one
# process each, and the battery about 17 minutes in their shadow. Each runs as
# FLIGHT_SHARDS and SOLVE_SHARDS processes (`-- shard=K/N`, every Nth case), and
# `sheet=ShardSum` judges what needs every case (a sweep's found-and-clean
# share, the flights left put there) from the shards' logs: `<name>_total`. A
# worktree from before the split (no ShardSum.gd) runs them whole, as before.
#
# HOW LONG (the PC, Nov 2, SOLO=0, one other Godot running): 9:00, where the
# runs whole took 16:43 back to back on the same tree; the four timed runs add
# about 1:30. The pool is now bound by its total work (about 4,000 s over 8),
# not by any one run. JOBS=12 took 8:17 but starved FlightTest's clicks (shard
# 3), which hold every frame's step to 20 ms: keep 8 unless the clicks move.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
W="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"; shift || true
JOBS="${JOBS:-8}"
OUT="${OUT:-$TK_SCRATCH/battery}"
FLIGHT_SHARDS="${FLIGHT_SHARDS:-4}"
SOLVE_SHARDS="${SOLVE_SHARDS:-4}"
mkdir -p "$OUT"; : >"$OUT/summary.txt"
# (the logs' folder as Godot reads it: C:/... under Git Bash)
OUT_G="$(cygpath -m "$OUT" 2>/dev/null || printf '%s' "$OUT")"
ONLY=" $* "
T_ALL=$(date +%s)

# name label gate_limit_s phase godot args...
#   phase 0: the parallel pool; 2: after the pool (a split test's total);
#   1: alone, after everything (it times itself)
# The pool runs in this order, the longest first (the seconds each took in the
# Nov 2 battery), so no long run is the last to start: LadderTest (about 230 s)
# and OrbitWorldTest (about 200), the split tests' shards, then the rest.
LIST=(
"laddertest laddertest 420 0 --headless --path tkg -- sheet=LadderTest"
"orbitworldtest orbitworldtest 300 0 --headless --fixed-fps 60 --path tkg -- sheet=OrbitWorldTest"
)
split_rows() {  # split_rows NAME SHARDS LIMIT godot args (before the shard)...
	local name="$1" n="$2" lim="$3"; shift 3
	local k logs=""
	for ((k = 1; k <= n; k++)); do
		LIST+=("${name}_$k $name $lim 0 $* shard=$k/$n")
		logs="$logs${logs:+,}$OUT_G/${name}_$k.log"
	done
	LIST+=("${name}_total ${name}_total 120 2 --headless --path tkg -- sheet=ShardSum label=$name logs=$logs")
}
if [ -f "$W/tkg/scripts/sim/ShardSum.gd" ]; then
	split_rows solvetest "$SOLVE_SHARDS" 900 --headless --path tkg -- sheet=SolveTest
	split_rows flighttest "$FLIGHT_SHARDS" 900 --headless --path tkg -- sheet=FlightTest
else
	LIST+=("solvetest solvetest 900 0 --headless --path tkg -- sheet=SolveTest")
	LIST+=("flighttest flighttest 900 0 --headless --path tkg -- sheet=FlightTest")
fi
LIST+=(
"twinsitetest_all twinsitetest 300 0 --headless --fixed-fps 60 --path tkg -- sheet=TwinSiteTest twin=all"
"twinsitetest twinsitetest 300 0 --headless --fixed-fps 60 --path tkg -- sheet=TwinSiteTest"
"pairlocaltest pairlocaltest 120 0 --headless --fixed-fps 60 --path tkg -- sheet=PairLocalTest"
"wrecksitetest wrecksitetest 180 0 --headless --path tkg -- sheet=WreckSiteTest"
"localeventtest localeventtest 300 0 --headless --path tkg -- localeventtest"
"ashtutortest ashtutortest 600 0 --headless --fixed-fps 60 --path tkg -- sheet=AshTutorTest"
"dockflytest dockflytest 300 0 --headless --fixed-fps 60 --path tkg -- sheet=DockFlyTest"
"twindrawtest twindrawtest 300 0 --headless --path tkg -- sheet=TwinDrawTest"
"subjecttest subjecttest 180 0 --headless --path tkg -- subjecttest"
"stationdecktest stationdecktest 240 0 --headless --path tkg -- sheet=StationDeckTest"
"outcometest outcometest 240 0 --headless --fixed-fps 60 --path tkg -- sheet=OutcomeTest"
"sciencesimtest sciencesimtest 300 0 --headless --path tkg -- sheet=ScienceSimTest"
"rewardshowntest rewardshowntest 300 0 --headless --path tkg -- sheet=RewardShownTest"
"sidebartest_twin sidebartest 300 0 --headless --path tkg -- sheet=SideBarTest twin=all"
"sidebartest sidebartest 300 0 --headless --path tkg -- sheet=SideBarTest"
"moontest_twin moontest 300 0 --headless --path tkg -- sheet=MoonTest twin=all"
"moontest moontest 300 0 --headless --path tkg -- sheet=MoonTest"
"scrollcheck_twin scrollcheck 240 0 --headless --path tkg -- sheet=SystemShot scrollcheck twin=all"
"parseall parseall 180 0 --headless --path tkg -- parseall"
"fightopentest fightopentest 180 0 --headless --fixed-fps 60 --path tkg -- sheet=FightOpenTest"
"calmladdertest calmladdertest 300 0 --headless --fixed-fps 60 --path tkg -- sheet=CalmLadderTest"
"scrollcheck scrollcheck 240 0 --headless --path tkg -- sheet=SystemShot scrollcheck"
"contracttest contracttest 120 0 --headless --path tkg -- contracttest"
"routinetest routinetest 180 0 --headless --path tkg -- sheet=RoutineTest"
"augmenttest augmenttest 120 0 --headless --path tkg -- sheet=AugmentTest"
"optiontest optiontest 180 0 --headless --path tkg -- optiontest"
"systemtest systemtest 180 0 --headless --path tkg -- systemtest"
"corewintest corewintest 180 0 --headless --path tkg -- sheet=CoreWinTest"
"fueltest fueltest 180 0 --headless --path tkg -- sheet=FuelTest"
"arriveidletest arriveidletest 180 0 --headless --fixed-fps 60 --path tkg -- sheet=ArriveIdleTest"
"goaltest goaltest 180 0 --headless --path tkg -- sheet=GoalTest"
"nettest nettest 180 0 --headless --path tkg -- nettest"
"savetest savetest 120 0 --headless --path tkg -- savetest"
"oneholetest oneholetest 120 0 --headless --path tkg -- sheet=OneHoleTest"
"mapperftest mapperftest 300 1 --headless --path tkg -- sheet=MapPerfTest"
"maplagtest maplagtest 180 1 --headless --path tkg -- maplagtest"
"maplagtest_twin maplagtest 180 1 --headless --path tkg -- maplagtest twin=all"
"threadstress threadstress 120 1 --headless --path tkg -- sheet=ThreadStress secs=20"
)

one() {
	local name="$1" label="$2" gl="$3" solo="$4"; shift 4
	local lim=$(( gl * 3 )); [ "$lim" -lt 600 ] && lim=600
	local t0; t0=$(date +%s)
	bash "$W/tools/dev/godot.sh" -t "$lim" -C "$W" "$@" >"$OUT/$name.log" 2>&1
	local code=$? t1; t1=$(date +%s)
	local pass errs over=""
	pass=$(grep -cE "^($label: PASS|=== PASS)" "$OUT/$name.log")
	errs=$(grep -E "SCRIPT ERROR|Parse Error|Compile Error|^ERROR:" "$OUT/$name.log" \
		| grep -vcE "resources still in use at exit|RID allocations of type .* were leaked at exit")
	# Only a run that had the machine to itself is held to the gate's limit.
	[ "$solo" = 1 ] && [ $((t1 - t0)) -gt "$gl" ] && over=" OVER_GATE_LIMIT($gl)"
	echo "$name exit=$code pass=$pass errors=$errs secs=$((t1 - t0))$over" >>"$OUT/summary.txt"
}

# A run is wanted when no names were given, when it is named, or when it is a
# shard or the total of a split test that is named.
wanted() {
	[ "$ONLY" = "  " ] || [[ "$ONLY" == *" $1 "* ]] && return 0
	case "$1" in
		*_total) [[ "$ONLY" == *" ${1%_total} "* ]] ;;
		*_[0-9]*) [[ "$ONLY" == *" ${1%_*} "* ]] && [ "${1%_*}" = "$2" ] ;;
		*) return 1 ;;
	esac
}

# The import first, so class names a change added resolve everywhere.
if wanted import import; then one import import 1800 0 --headless --path tkg --import; fi
# The pool: everything that does not time itself, JOBS at a time.
for row in "${LIST[@]}"; do
	set -- $row
	[ "$4" = 0 ] || continue
	wanted "$1" "$2" || continue
	while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do sleep 2; done
	one "$@" &
done
wait
# The split tests' totals, from their shards' logs.
for row in "${LIST[@]}"; do
	set -- $row
	[ "$4" = 2 ] || continue
	wanted "$1" "$2" || continue
	one "$@" &
done
wait
# The timing runs, one at a time, alone.
for row in "${LIST[@]}"; do
	set -- $row
	[ "$4" = 1 ] || continue
	[ "${SOLO:-1}" = 0 ] && continue
	wanted "$1" "$2" || continue
	one "$@"
done
echo "DONE wall=$(( $(date +%s) - T_ALL ))s jobs=$JOBS flight_shards=$FLIGHT_SHARDS solve_shards=$SOLVE_SHARDS" >>"$OUT/summary.txt"
sort "$OUT/summary.txt"
