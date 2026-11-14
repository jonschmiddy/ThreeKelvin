#!/usr/bin/env bash
# Parse/compile check for the Godot project, for use as a Claude Code PostToolUse
# hook (and by hand: tools/gdcheck.sh).
#
# Reads the hook's stdin JSON, does nothing unless a .gd file was just written,
# and otherwise re-imports the project and reports GDScript errors.
#
# It starts Godot through tools/dev/godot.sh, never directly: that finds the right
# binary on this machine (the WinGet console build on Windows, the app on a Mac;
# neither is on PATH as `godot`) and runs it with a throwaway profile, so the real
# player profile is never read or written (the first rule in CLAUDE.md).
# Why this is built this way: docs/why/claude_hooks.md
#
# Why --import and not --check-only --script:
#   `--script` replaces the main loop and never creates the autoloads, so every
#   file that touches Sig, DB, Run or Router -- which is most of them -- fails
#   with a false "Identifier not found". CLAUDE.md says the same thing about the
#   balance sim. `--import` compiles the project the way the editor does, with
#   the autoloads and the global class cache in place, so what it reports is
#   real. It is also the command CLAUDE.md already tells you to run after adding
#   a class_name, so this is not a second way to build the project.
#
# Godot exits 0 even when scripts fail to compile, so the errors are detected by
# reading its output rather than its status. Exit 2 is what feeds the message
# back to Claude; exit 0 is silent success.
set -uo pipefail

ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -f "$ROOT/tools/dev/godot.sh" ] || ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Fail open, never block work: a machine without Godot or without the project
# still gets to edit files. A hook that halts the session because a tool is
# missing is worse than no hook. (No jq needed: the payload is read with grep.)
[ -f "$ROOT/tkg/project.godot" ] || exit 0
[ -f "$ROOT/tools/dev/godot.sh" ] || exit 0

# No stdin (run by hand) means check unconditionally.
if [ -t 0 ]; then
	file="manual"
else
	payload="$(cat)"
	file="$(printf '%s' "$payload" | grep -Eo '"(file_path|filePath)"[[:space:]]*:[[:space:]]*"[^"]*\.gd"' | head -n 1 \
		| sed -E 's/^"[A-Za-z_]+"[[:space:]]*:[[:space:]]*"//; s/"$//')"
	[ -n "$file" ] || exit 0   # not GDScript, nothing to compile
fi

# The tree that holds the edited file is the one to import: a session started in the main checkout that
# edits ../tk-wt/x/tkg/scripts/A.gd must check x, not itself. Same rule as claude_hooks.py's tree_of():
# the part before /tkg/scripts/, backslashes read as slashes. No match: keep $CLAUDE_PROJECT_DIR / this tree.
if [ "$file" != manual ]; then
	fnorm="${file//\\//}"
	case "$fnorm" in
		*/tkg/scripts/*) froot="${fnorm%%/tkg/scripts/*}"; [ -n "$froot" ] || froot="/" ;;
		tkg/scripts/*) froot="" ;;
		*) froot="" ;;
	esac
	case "$froot" in
		[A-Za-z]:) froot="$froot/" ;;
	esac
	# On Git Bash a C:/ path works as is; elsewhere it is simply not a directory and the fallback stays.
	if [ -n "$froot" ] && [ -f "$froot/tkg/project.godot" ] && [ -f "$froot/tools/dev/godot.sh" ]; then
		ROOT="$froot"
	fi
fi

source "$ROOT/tools/dev/env.sh"
# The binary env.sh found, or nothing to run: say nothing and let the edit stand.
if ! [ -x "$GODOT" ] && ! command -v "$GODOT" >/dev/null 2>&1; then exit 0; fi

# Godot 4.7.1's --import does NOT report a syntax error in a script nothing has loaded yet (tried with a
# planted broken class_name file: exit 0, no message), but `-- parseall` does, in ~14 s instead of ~9 s.
# TK_GDCHECK=parseall in the environment switches to it (a new class_name then needs --import first, or it
# reports a false "unknown class"). Default stays --import, as before. See docs/why/claude_hooks.md.
if [ "${TK_GDCHECK:-import}" = parseall ]; then
	run=(-t 90 -C "$ROOT" --headless --path tkg -- parseall)
else
	run=(-t 50 -C "$ROOT" --headless --path tkg --import)
fi
errors="$(bash "$ROOT/tools/dev/godot.sh" "${run[@]}" 2>&1 \
	| grep -E 'SCRIPT ERROR|Parse Error|Compile Error' \
	| head -30)"

[ -z "$errors" ] && exit 0

{
	echo "GDScript check failed after writing ${file}:"
	echo "$errors"
	echo
	echo "(tkg/tools/gdcheck.sh -- run 'bash tools/dev/godot.sh ${run[*]}' to reproduce)"
} >&2
exit 2
