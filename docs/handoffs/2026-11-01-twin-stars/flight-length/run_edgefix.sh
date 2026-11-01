#!/usr/bin/env bash
# The flight-length study's replays again after the edge fix (Nov 1): the
# detached copy (ee5ef1d3 + study.patch + FlightLen.gd) in ../wt2, imported,
# parsed, and FlightLen's replay mode flown as run_v3.sh flew it.
# ONE GODOT AT A TIME: each run through the machine-wide lock, headless, on a
# throwaway profile (tools/dev/godot.sh). A watcher logs how many Godots run.
#   bash run_edgefix.sh import|parseall|replay <out.json> <log>
FL=/Users/jon/Documents/GitHub/tk-scratch/twin-build/flightlen
OUT=$FL/edgefix
WT=$FL/wt2
cd /Users/jon/Documents/GitHub/ThreeKelvin
L1() { bash /Users/jon/Documents/GitHub/tk-scratch/godot1.sh tools/dev/godot.sh -t "$1" -C $WT --headless --path tkg "${@:2}"; }
G() { L1 "$1" -- "${@:2}"; }
( while true; do echo "$(date -u +%H:%M:%SZ) godots $(pgrep -x Godot | wc -l | tr -d ' ') $(pgrep -fl 'Godot' | grep -c -- '--path tkg') load $(sysctl -n vm.loadavg)"; sleep 15; done ) >> $OUT/watch.log 2>&1 &
W=$!
trap 'kill $W 2>/dev/null' EXIT
stamp() { echo "$(date -u +%H:%M:%SZ) $*" >> $OUT/runs.out; }
case "$1" in
	import)
		stamp "import start"
		L1 900 --import > $OUT/import.log 2>&1
		stamp "import exit $?"
		;;
	parseall)
		stamp "parseall start"
		G 900 parseall > $OUT/parseall.log 2>&1
		stamp "parseall exit $? $(grep -c 'parseall: PASS' $OUT/parseall.log)"
		;;
	replay)
		stamp "replay start ($2)"
		G 1500 sheet=FlightLen mode=replay set.B=1:23:40::30:both set.C=16:16:40::30:both out=$2 > $3 2>&1
		stamp "replay exit $? ($2)"
		;;
esac
