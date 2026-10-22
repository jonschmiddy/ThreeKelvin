#!/usr/bin/env bash
# Two processes flown the way two friends fly. See scripts/sim/CoJoinTest.gd.
#
#   tools/cojoin.sh            HOST DIRECT on loopback: one system, one fight,
#                              apart and together again
#   tools/cojoin.sh relay      the same through the relay (HOST PARTY)
#   tools/cojoin.sh late       the guest joins a dive already under way
#
# Each process gets its own user folder (APPDATA on Windows, XDG_DATA_HOME and
# HOME elsewhere), so neither touches the player's profile or the other's.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
command -v "$GODOT" >/dev/null 2>&1 || GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
MODE="${*:-}"
OUT="$(mktemp -d)"
mkdir -p "$OUT/host" "$OUT/guest"

as_user() {
	local dir="$1"; shift
	local win="$dir"
	command -v cygpath >/dev/null 2>&1 && win="$(cygpath -w "$dir")"
	APPDATA="$win" XDG_DATA_HOME="$dir" "$@"
}

as_user "$OUT/host" "$GODOT" --headless --path "$HERE" -- cojoin host $MODE >"$OUT/host.log" 2>&1 &
HOST_PID=$!

CODE=""
for _ in $(seq 1 120); do
	CODE="$(grep -m1 '^\[cojoin\] code ' "$OUT/host.log" 2>/dev/null | sed 's/^\[cojoin\] code //' | tr -d '\r')"
	[ -n "$CODE" ] && break
	kill -0 "$HOST_PID" 2>/dev/null || break
	sleep 0.5
done
if [ -z "$CODE" ]; then
	echo "the host never printed a code:"; cat "$OUT/host.log"
	kill "$HOST_PID" 2>/dev/null; wait "$HOST_PID" 2>/dev/null
	exit 1
fi
echo "code $CODE"
# The late guest arrives once the host has dived and flown.
case " $MODE " in *" late "*) sleep 6 ;; esac

as_user "$OUT/guest" "$GODOT" --headless --path "$HERE" -- cojoin join "$CODE" $MODE >"$OUT/guest.log" 2>&1 &
GUEST_PID=$!
wait "$GUEST_PID"; GUEST_RC=$?
wait "$HOST_PID";  HOST_RC=$?

for who in host guest; do
	echo; echo "--- $who ---"
	grep -E '^  (ok|FAIL)|^  (HOST|GUEST)|^cojoin|SCRIPT ERROR|^ERROR' "$OUT/$who.log" | tr -d '\r'
done

RC=0
same() {
	local what="$1" tag="$2" a b
	a="$(grep -m1 "^\[cojoin\] $tag " "$OUT/host.log" | sed "s/^\[cojoin\] $tag //" | tr -d '\r')"
	b="$(grep -m1 "^\[cojoin\] $tag " "$OUT/guest.log" | sed "s/^\[cojoin\] $tag //" | tr -d '\r')"
	if [ -z "$a" ] || [ -z "$b" ]; then echo "  FAIL $what -- one ship never reported ($tag)"; RC=1; return; fi
	if [ "$a" = "$b" ]; then echo "  ok   $what: $a"; else echo "  FAIL $what"; echo "         host:  $a"; echo "         guest: $b"; RC=1; fi
}
one_of() {
	local what="$1" tag="$2" a b
	a="$(grep -m1 "^\[cojoin\] $tag " "$OUT/host.log" | sed "s/^\[cojoin\] $tag //" | tr -d '\r')"
	b="$(grep -m1 "^\[cojoin\] $tag " "$OUT/guest.log" | sed "s/^\[cojoin\] $tag //" | tr -d '\r')"
	if [ "$a" = "skip" ] && [ "$b" = "skip" ]; then
		echo "  ok   $what (the wreck rolled empty: nothing to take)"; return; fi
	if { [ "$a" = "none" ] && [ "$b" = "yes" ]; } || { [ "$a" = "yes" ] && [ "$b" = "none" ]; }; then
		echo "  ok   $what"; else echo "  FAIL $what (host $a, guest $b)"; RC=1; fi
}

echo; echo "--- across both ---"
same "one galaxy on both machines" "galaxy"
case " $MODE " in
*" late "*) ;;
*)
	same "one system both ships flew to" "target"
	same "one fight, ended the same way" "outcome"
	same "and one pile of wrecks" "wreck"
	one_of "and exactly one ship took the part" "took"
	same "and both agree who has it" "taker"
;; esac
# Script errors are failures whatever the assertions said.
if grep -q "SCRIPT ERROR" "$OUT/host.log" "$OUT/guest.log"; then echo "  FAIL script errors in a log"; RC=1; fi

echo; echo "full logs in $OUT"
[ "$GUEST_RC" -eq 0 ] && [ "$HOST_RC" -eq 0 ] && [ "$RC" -eq 0 ] \
	&& echo "cojoin: PASS" || { echo "cojoin: FAIL"; exit 1; }
