#!/usr/bin/env bash
# godot.sh [-t SECONDS] [-C DIR] <godot args...>
#
# Runs Godot with a FRESH, THROWAWAY PROFILE (never the real one), the dummy
# audio driver, and a time limit (default 600 s). The profile is deleted after.
# Refuses to run at all if tools/dev/env.sh `tk_guard` cannot prove the
# isolation works on this machine.
#
#   tools/dev/godot.sh --headless --path tkg -- sheet=AshTutorTest
#   tools/dev/godot.sh -t 900 -C ../tk-wt/my-branch --headless --path tkg --import
#
# AshTutorTest and other timed sheets want --fixed-fps 60. A fresh worktree
# needs one `--import` before its first test, or class names will not resolve.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
limit=600
while [ $# -gt 0 ]; do
	case "$1" in
		-t) limit="$2"; shift 2 ;;
		-C) cd "$2" || exit 1; shift 2 ;;
		*) break ;;
	esac
done
tk_guard || exit 3
p="$(tk_new_profile)"
tk_isolated "$p" tk_timeout "$limit" "$GODOT" --audio-driver Dummy "$@"
code=$?
rm -rf "$p"
exit $code
