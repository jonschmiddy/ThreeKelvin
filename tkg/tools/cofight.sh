#!/usr/bin/env bash
# Two processes, one enemy. See scripts/sim/CoFightTest.gd.
#
# Starts a host, waits for it to print its lobby code, starts a guest against
# that code, and reports both. Paired by the printed code rather than by a fixed
# port, because the code is what a player actually types and testing the thing
# players use is the point.
#
#   tools/cofight.sh
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
command -v "$GODOT" >/dev/null 2>&1 || GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
OUT="$(mktemp -d)"

"$GODOT" --headless --path "$HERE" -- cofight host >"$OUT/host.log" 2>&1 &
HOST_PID=$!

# The host prints its code once, on its own line. Waiting for that line rather
# than for a fixed number of seconds: a cold start on a slow disk is not a
# failure, and a host that died is not something to keep waiting for.
CODE=""
for _ in $(seq 1 120); do
	CODE="$(grep -m1 '^\[cofight\] code ' "$OUT/host.log" 2>/dev/null | sed 's/^\[cofight\] code //')"
	[ -n "$CODE" ] && break
	kill -0 "$HOST_PID" 2>/dev/null || break
	sleep 0.5
done

if [ -z "$CODE" ]; then
	echo "the host never printed a code:"
	cat "$OUT/host.log"
	wait "$HOST_PID" 2>/dev/null
	exit 1
fi
echo "code $CODE"

"$GODOT" --headless --path "$HERE" -- cofight join "$CODE" >"$OUT/guest.log" 2>&1 &
GUEST_PID=$!

wait "$GUEST_PID"; GUEST_RC=$?
wait "$HOST_PID";  HOST_RC=$?

echo
echo "--- host ---";  grep -E '^  (ok|FAIL)|^  (HOST|GUEST)|^cofight' "$OUT/host.log"
echo
echo "--- guest ---"; grep -E '^  (ok|FAIL)|^  (HOST|GUEST)|^cofight' "$OUT/guest.log"
# The claims neither process can check alone. A shared seed gives both machines
# an identical galaxy, which is the point, and must NOT give them an identical
# hold — the streams that decide what happens to a PLAYER are salted by seat.
# Only a third observer can compare the two.
RC=0
pair() {
	local what="$1" tag="$2"
	local a b
	a="$(grep -m1 "^\[cofight\] $tag " "$OUT/host.log"  | sed "s/^\[cofight\] $tag //")"
	b="$(grep -m1 "^\[cofight\] $tag " "$OUT/guest.log" | sed "s/^\[cofight\] $tag //")"
	if [ -z "$a" ] || [ -z "$b" ]; then
		echo "  FAIL $what — one ship never reported ($tag)"; RC=1; return
	fi
	if [ "$a" = "$b" ]; then
		echo "  FAIL $what"; echo "         both: $a"; RC=1
	else
		echo "  ok   $what"; echo "         host:  $a"; echo "         guest: $b"
	fi
}

echo
echo "--- across both ---"
pair "the two ships are different seats" "seat"
pair "and therefore draw loot from different streams" "lootseed"
pair "so one kill pays two ships two different parts" "loot"

echo
echo "full logs in $OUT"
[ "$GUEST_RC" -eq 0 ] && [ "$HOST_RC" -eq 0 ] && [ "$RC" -eq 0 ] \
	&& echo "cofight: PASS" || { echo "cofight: FAIL"; exit 1; }
