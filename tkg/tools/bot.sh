#!/usr/bin/env bash
# A ship in the party that nobody is sitting in front of.
#
#   tools/bot.sh                    a window for you, a bot flying alongside
#   tools/bot.sh ABC-123            send a bot to join a party already running
#   tools/bot.sh ABC-123 /tmp/crew  ...and take orders from that mailbox
#
# With no code it opens a playable window, waits for it to print its lobby code
# and joins that code with a headless bot — so "play a co-op run with a crewmate"
# is one command rather than two terminals and a copy-paste.
#
# THE MAILBOX IS THE INTERESTING PART. Point one at the bot and it stops flying
# itself: before every decision it writes `board.json` — the fight, the hand,
# the enemy's telegraphed intent, the systems in range, the shelf — and waits
# for `move.json` to come back holding `{"seq": N, "do": "play 2"}`. Anything
# that can write a file can fly it. When nothing answers inside the shot clock
# the autopilot takes the turn, so a slow brain never becomes the party's
# latency. See scripts/net/BotPilot.gd.
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT="${GODOT:-godot}"
command -v "$GODOT" >/dev/null 2>&1 || GODOT="/Applications/Godot.app/Contents/MacOS/Godot"

CODE="${1:-}"
MAILBOX="${2:-}"
NAME="${BOT_NAME:-Claude}"
THINK="${BOT_THINK:-25}"
OUT="$(mktemp -d)"
PIDS=()

bot_args=(-- bot join "" name="$NAME" think="$THINK")

if [ -z "$CODE" ]; then
	echo "opening a window and hosting..."
	"$GODOT" --path "$HERE" --resolution 1100x700 --position 40,80 \
		-- lobby host relay auto wait 2 >"$OUT/host.log" 2>&1 &
	PIDS+=($!)
	for _ in $(seq 1 120); do
		CODE="$(grep -m1 '^\[lobby\] code ' "$OUT/host.log" 2>/dev/null | sed 's/^\[lobby\] code //')"
		[ -n "$CODE" ] && break
		kill -0 "${PIDS[0]}" 2>/dev/null || break
		sleep 0.5
	done
	if [ -z "$CODE" ]; then
		echo "the host never printed a code:"; cat "$OUT/host.log"; exit 1
	fi
fi

echo "code $CODE"
[ -n "$MAILBOX" ] && { mkdir -p "$MAILBOX"; echo "mailbox $MAILBOX"; }

args=(--headless --path "$HERE" -- bot join "$CODE" name="$NAME" think="$THINK")
[ -n "$MAILBOX" ] && args+=("mailbox=$MAILBOX")

"$GODOT" "${args[@]}" 2>&1 | tee "$OUT/bot.log" &
PIDS+=($!)

echo "logs in $OUT"
for p in "${PIDS[@]}"; do wait "$p"; done
