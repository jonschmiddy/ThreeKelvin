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
echo
echo "full logs in $OUT"
[ "$GUEST_RC" -eq 0 ] && [ "$HOST_RC" -eq 0 ] && echo "cofight: PASS" || { echo "cofight: FAIL"; exit 1; }
