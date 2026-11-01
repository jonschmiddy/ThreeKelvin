#!/usr/bin/env bash
# The merged twin-stars tree (feat/twin-stars, all three wave-2 parts), every
# touched harness one after another through godot1.sh. Each log in
# merged/logs/<name>.log, a line a run in merged/logs/summary.txt.
# Pass names to run only those.
#   name label gate_limit_s [godot args...]
cd /Users/jon/Documents/GitHub/ThreeKelvin || exit 1
W=/Users/jon/Documents/GitHub/tk-wt/twin-stars
OUT=/Users/jon/Documents/GitHub/tk-scratch/twin-build/merged/logs
mkdir -p "$OUT"
ONLY=" $* "
run() {
	local name="$1" label="$2" gl="$3"; shift 3
	if [ "$ONLY" != "  " ] && [[ "$ONLY" != *" $name "* ]]; then
		return
	fi
	local lim=$(( gl * 3 ))
	[ "$lim" -lt 600 ] && lim=600
	local t0=$(date +%s)
	bash /Users/jon/Documents/GitHub/tk-scratch/godot1.sh tools/dev/godot.sh -t "$lim" -C "$W" "$@" > "$OUT/$name.log" 2>&1
	local code=$?
	local t1=$(date +%s)
	local pass=$(grep -cE "^($label: PASS|=== PASS)" "$OUT/$name.log")
	local errs=$(grep -E "SCRIPT ERROR|Parse Error|Compile Error|^ERROR:" "$OUT/$name.log" | grep -vcE "resources still in use at exit|RID allocations of type .* were leaked at exit")
	local over=""
	[ $((t1 - t0)) -gt "$gl" ] && over=" OVER_GATE_LIMIT($gl)"
	echo "$name exit=$code pass=$pass errors=$errs secs=$((t1 - t0))$over" >> "$OUT/summary.txt"
}
run import import 1800 --headless --path tkg --import
run parseall parseall 180 --headless --path tkg -- parseall
run twinsitetest twinsitetest 300 --headless --fixed-fps 60 --path tkg -- sheet=TwinSiteTest
run twinsitetest_all twinsitetest 300 --headless --fixed-fps 60 --path tkg -- sheet=TwinSiteTest twin=all
run twindrawtest twindrawtest 300 --headless --path tkg -- sheet=TwinDrawTest
run systemtest systemtest 180 --headless --path tkg -- systemtest
run savetest savetest 120 --headless --path tkg -- savetest
run nettest nettest 180 --headless --path tkg -- nettest
run contracttest contracttest 120 --headless --path tkg -- contracttest
run orbitworldtest orbitworldtest 300 --headless --fixed-fps 60 --path tkg -- sheet=OrbitWorldTest
run dockflytest dockflytest 300 --headless --fixed-fps 60 --path tkg -- sheet=DockFlyTest
run subjecttest subjecttest 180 --headless --path tkg -- subjecttest
run localeventtest localeventtest 300 --headless --path tkg -- localeventtest
run mapperftest mapperftest 300 --headless --path tkg -- sheet=MapPerfTest
run maplagtest maplagtest 180 --headless --path tkg -- maplagtest
run maplagtest_twin maplagtest 180 --headless --path tkg -- maplagtest twin=all
run threadstress threadstress 120 --headless --path tkg -- sheet=ThreadStress secs=20
run fueltest fueltest 180 --headless --path tkg -- sheet=FuelTest
run arriveidletest arriveidletest 180 --headless --fixed-fps 60 --path tkg -- sheet=ArriveIdleTest
run wrecksitetest wrecksitetest 180 --headless --path tkg -- sheet=WreckSiteTest
run laddertest laddertest 420 --headless --path tkg -- sheet=LadderTest
run calmladdertest calmladdertest 300 --headless --fixed-fps 60 --path tkg -- sheet=CalmLadderTest
run sidebartest sidebartest 300 --headless --path tkg -- sheet=SideBarTest
run sidebartest_twin sidebartest 300 --headless --path tkg -- sheet=SideBarTest twin=all
run moontest moontest 300 --headless --path tkg -- sheet=MoonTest
run moontest_twin moontest 300 --headless --path tkg -- sheet=MoonTest twin=all
run oneholetest oneholetest 120 --headless --path tkg -- sheet=OneHoleTest
run scrollcheck scrollcheck 240 --headless --path tkg -- sheet=SystemShot scrollcheck
run scrollcheck_twin scrollcheck 240 --headless --path tkg -- sheet=SystemShot scrollcheck twin=all
run corewintest corewintest 180 --headless --path tkg -- sheet=CoreWinTest
run fightopentest fightopentest 180 --headless --fixed-fps 60 --path tkg -- sheet=FightOpenTest
run ashtutortest ashtutortest 600 --headless --fixed-fps 60 --path tkg -- sheet=AshTutorTest
run goaltest goaltest 180 --headless --path tkg -- sheet=GoalTest
run flighttest flighttest 900 --headless --path tkg -- sheet=FlightTest
run solvetest solvetest 900 --headless --path tkg -- sheet=SolveTest
echo "DONE $*" >> "$OUT/summary.txt"
