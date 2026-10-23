#!/usr/bin/env bash
# render.sh [-t SECONDS] [-C DIR] <godot args...>
#
# A WINDOWED Godot run for stills and films (the shot and film sheets need a
# real window and GPU), with a fresh throwaway profile and the dummy audio
# driver, like godot.sh. At most two run at once across every agent on the
# machine: a third waits for a slot.
#
#   tools/dev/render.sh -t 300 --path tkg -- sheet=QuestLogShot
#
# WHERE THE WINDOW GOES:
#   Windows: if TK_HIDDESK points at hiddesk.exe, the window opens on a hidden
#            desktop and never shows on Jon's screens. Without it, it shows.
#   Mac:     there is no hidden desktop. The window shows on screen while it
#            runs, so ask Jon before a batch (it steals focus mid-game), and
#            never run one while he is playing.
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$D/env.sh"
limit=600
while [ $# -gt 0 ]; do
	case "$1" in
		-t) limit="$2"; shift 2 ;;
		-C) cd "$2" || exit 1; shift 2 ;;
		*) break ;;
	esac
done
tk_guard || exit 3

LOCKS="$TK_SCRATCH/render_locks"; mkdir -p "$LOCKS"
SLOT=""
while [ -z "$SLOT" ]; do
	for s in 1 2; do
		d="$LOCKS/slot$s"
		if mkdir "$d" 2>/dev/null; then SLOT="$d"; break; fi
		# Abandoned: its owner is gone, or it is older than 40 minutes.
		pid="$(cut -d' ' -f1 "$d/owner" 2>/dev/null)"
		if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then rm -rf "$d"
		elif [ -n "$(find "$d" -maxdepth 0 -mmin +40 2>/dev/null)" ]; then rm -rf "$d"
		fi
	done
	[ -z "$SLOT" ] && sleep 5
done
echo "$$ $(date +%H:%M:%S) $*" >"$SLOT/owner"
p="$(tk_new_profile)"
trap 'rm -rf "$SLOT" "$p"' EXIT INT TERM

if [ "$TK_OS" = win ] && [ -n "${TK_HIDDESK:-}" ] && [ -x "$TK_HIDDESK" ]; then
	log="$TK_SCRATCH/logs/render-$$.log"
	tk_isolated "$p" tk_timeout "$limit" "$TK_HIDDESK" "$(cygpath -w "$log")" "$(cygpath -w "$GODOT")" \
		--audio-driver Dummy "$@"
	code=$?
	cat "$log" 2>/dev/null; rm -f "$log"
	exit $code
fi
tk_isolated "$p" tk_timeout "$limit" "$GODOT" --audio-driver Dummy "$@"
