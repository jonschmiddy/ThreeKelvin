#!/usr/bin/env bash
# The flight-length study's runs after the review of Nov 1, second pass: B and
# C keep the as-built guesses beside the scaled ones, and where their own
# search finds nothing the as-built search and the wider one both look and
# the sooner flight is kept. A's runs (unchanged code) are in v2 already.
# ONE GODOT AT A TIME: each run through the machine-wide lock. A watcher logs
# how many Godots run, every 15 s, so a run alone can be shown.
#   bash run_v3.sh
FL=/Users/jon/Documents/GitHub/tk-scratch/twin-build/flightlen
OUT=$FL/v2
cd /Users/jon/Documents/GitHub/ThreeKelvin
G() { bash /Users/jon/Documents/GitHub/tk-scratch/godot1.sh tools/dev/godot.sh -t "$1" -C $FL/wt --headless --path tkg -- "${@:2}"; }
B="fs.tw=1 fs.cap=23 fs.capw=40 fs.back=30 fs.both=1"
C="fs.tw=16 fs.cap=16 fs.capw=40 fs.back=30 fs.both=1"
( while true; do echo "$(date -u +%H:%M:%SZ) godots $(pgrep -x Godot | wc -l | tr -d ' ') $(pgrep -fl 'Godot' | grep -c -- '--path tkg') load $(sysctl -n vm.loadavg)"; sleep 15; done ) >> $OUT/watch.log 2>&1 &
W=$!
trap 'kill $W 2>/dev/null' EXIT
stamp() { echo "$(date -u +%H:%M:%SZ) $*" >> $OUT/runs.out; }
stamp "v3 parseall start"
G 900 parseall > $FL/logs2/parseall2.log 2>&1
stamp "v3 parseall exit $? $(grep -c 'parseall: PASS' $FL/logs2/parseall2.log)"
grep -q 'parseall: PASS' $FL/logs2/parseall2.log || { stamp "all done (parseall failed)"; exit 1; }
stamp "replay start"
G 1500 sheet=FlightLen mode=replay set.B=1:23:40::30:both set.C=16:16:40::30:both out=$OUT/replays_raw.json > $OUT/replay.log 2>&1
stamp "replay exit $?"
for s in B C; do
	eval "args=\$$s"
	stamp "solve $s start"
	G 2400 sheet=SolveTest $args > $OUT/solve_$s.log 2>&1
	stamp "solve $s exit $?"
done
for s in B C; do
	eval "args=\$$s"
	stamp "ft $s start"
	G 2400 sheet=FlightTest $args lenout=$OUT/ft_$s.json > $OUT/ft_$s.log 2>&1
	stamp "ft $s exit $?"
done
stamp "probe3 start"
G 3600 sheet=FlightLen mode=probe3 "grid=A:0.5:30;B:1:23:40::30:both;C:16:16:40::30:both;Bd:1:23:40:::both;Cd:16:16:40:::both" out=$OUT/probe3.json > $OUT/probe3.log 2>&1
stamp "probe3 exit $?"
stamp "explore start"
G 1800 sheet=FlightLen mode=explore "grid=A:0.5:30;B:1:23:40::30:both;C:16:16:40::30:both" seeds=4242,7,1999 one=6 giant=3 twin=4 out=$OUT/explore.json > $OUT/explore.log 2>&1
stamp "explore exit $?"
stamp "all done"
