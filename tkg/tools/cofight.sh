#!/usr/bin/env bash
# Two processes, one enemy. See scripts/sim/CoFightTest.gd.
#
# Starts a host, waits for it to print its lobby code, starts a guest against
# that code, and reports both. Paired by the printed code rather than by a fixed
# port, because the code is what a player actually types and testing the thing
# players use is the point.
#
#   tools/cofight.sh          an ordinary contact at an ordinary system
#   tools/cofight.sh boss     the core, which reaches Combat down its own branch
#   tools/cofight.sh late     the guest arrives at a fight already in progress
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
command -v "$GODOT" >/dev/null 2>&1 || GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
MODE="${*:-}"
OUT="$(mktemp -d)"

"$GODOT" --headless --path "$HERE" -- cofight host $MODE >"$OUT/host.log" 2>&1 &
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

"$GODOT" --headless --path "$HERE" -- cofight join "$CODE" $MODE >"$OUT/guest.log" 2>&1 &
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

# The other half: some things MUST agree. A station's shelf belongs to the
# station, so both machines drawing the same stock is correct and its opposite
# would be the bug.
same() {
	local what="$1" tag="$2"
	local a b
	a="$(grep -m1 "^\[cofight\] $tag " "$OUT/host.log"  | sed "s/^\[cofight\] $tag //")"
	b="$(grep -m1 "^\[cofight\] $tag " "$OUT/guest.log" | sed "s/^\[cofight\] $tag //")"
	if [ -z "$a" ] || [ -z "$b" ]; then
		echo "  FAIL $what — one ship never reported ($tag)"; RC=1; return
	fi
	if [ "$a" = "$b" ]; then
		echo "  ok   $what"; echo "         both: $a"
	else
		echo "  FAIL $what"; echo "         host:  $a"; echo "         guest: $b"; RC=1
	fi
}

# And one thing that must be true of the pair rather than of either: exactly one
# ship walks away with the part.
one_of() {
	local what="$1" tag="$2"
	local a b
	a="$(grep -m1 "^\[cofight\] $tag " "$OUT/host.log"  | sed "s/^\[cofight\] $tag //")"
	b="$(grep -m1 "^\[cofight\] $tag " "$OUT/guest.log" | sed "s/^\[cofight\] $tag //")"
	if [ -z "$a" ] || [ -z "$b" ]; then
		echo "  FAIL $what — one ship never reported ($tag)"; RC=1; return
	fi
	if { [ "$a" = "none" ] && [ "$b" != "none" ]; } || { [ "$a" != "none" ] && [ "$b" = "none" ]; }; then
		echo "  ok   $what"; echo "         host:  $a"; echo "         guest: $b"
	else
		echo "  FAIL $what"; echo "         host:  $a"; echo "         guest: $b"; RC=1
	fi
}

echo
echo "--- across both ---"
pair "the two ships are different seats" "seat"
pair "and therefore draw loot from different streams" "lootseed"
# The core pays no modules and ends the run, so there is no hold to compare and
# no station left to dock at. Those three claims are about an ordinary contact.
case " $MODE " in *" boss "*) ;; *)
	same "so one kill leaves both ships ONE bag" "bag"
	one_of "and only one of them can take a part out of it" "took"
	same "and one station shows both ships one shelf" "shelf"
	one_of "but only one of them can buy the part off it" "bought"
;; esac

echo
echo "full logs in $OUT"
[ "$GUEST_RC" -eq 0 ] && [ "$HOST_RC" -eq 0 ] && [ "$RC" -eq 0 ] \
	&& echo "cofight: PASS" || { echo "cofight: FAIL"; exit 1; }
