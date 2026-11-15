#!/usr/bin/env bash
# Two playable clients on one machine, side by side.
#
# Hosts a party in one window, waits for it to print its lobby code, and joins
# that code from a second — so a co-op playtest is one command instead of two
# terminals and a copy-paste. `auto` presses READY and LAUNCH, so both windows
# land on the chassis select in the same galaxy and you fly from there.
#
#   tools/coplay.sh                 two ships
#   tools/coplay.sh 3               three (opens three windows)
#
# To share a fight, fly both ships to the SAME system. A fight is opened by the
# first ship to arrive and joined by everyone who lands on it after — the enemy
# grows, the turn waits for both of you, and the convoy strip marks whoever is
# in the room with a green arrow.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Godot, and a throwaway user folder for every process, from tools/dev/env.sh: never the
# real profile. tk_guard refuses to start anything it cannot prove is isolated.
source "$HERE/../tools/dev/env.sh"
tk_guard || exit 3
SHIPS="${1:-2}"
OUT="$(mktemp -d)"
W=960; H=600
PROFS=()
trap 'rm -rf "${PROFS[@]}"' EXIT

echo "hosting..."
PROFS+=("$(tk_new_profile)")
tk_isolated "${PROFS[0]}" "$GODOT" --path "$HERE" --resolution "${W}x${H}" --position 40,80 \
	-- lobby host auto wait "$SHIPS" >"$OUT/host.log" 2>&1 &
PIDS=($!)

CODE=""
for _ in $(seq 1 120); do
	CODE="$(grep -m1 '^\[lobby\] code ' "$OUT/host.log" 2>/dev/null | sed 's/^\[lobby\] code //')"
	[ -n "$CODE" ] && break
	kill -0 "${PIDS[0]}" 2>/dev/null || break
	sleep 0.5
done

if [ -z "$CODE" ]; then
	echo "the host never printed a code:"; cat "$OUT/host.log"; exit 1
fi
echo "code $CODE"

for i in $(seq 1 $((SHIPS - 1))); do
	PROFS+=("$(tk_new_profile)")
	tk_isolated "${PROFS[$i]}" "$GODOT" --path "$HERE" --resolution "${W}x${H}" \
		--position $((40 + i * (W + 20))),80 \
		-- lobby join "$CODE" auto >"$OUT/guest$i.log" 2>&1 &
	PIDS+=($!)
	sleep 1
done

echo "$SHIPS windows up. Fly both to the same system to share a fight."
echo "logs in $OUT"
for p in "${PIDS[@]}"; do wait "$p"; done
