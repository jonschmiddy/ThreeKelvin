#!/usr/bin/env bash
# Parse/compile check for the Godot project, for use as a Claude Code PostToolUse
# hook (and by hand: tools/gdcheck.sh).
#
# Reads the hook's stdin JSON, does nothing unless a .gd file was just written,
# and otherwise re-imports the project and reports GDScript errors.
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

ROOT="${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
PROJECT="$ROOT/tkg"

# Fail open, never block work: a machine without Godot, without jq, or without
# the project still gets to edit files. A hook that halts the session because a
# tool is missing is worse than no hook.
command -v godot >/dev/null 2>&1 || exit 0
command -v jq    >/dev/null 2>&1 || exit 0
[ -f "$PROJECT/project.godot" ] || exit 0

# No stdin (run by hand) means check unconditionally.
if [ -t 0 ]; then
	file="manual"
else
	file="$(jq -r '.tool_input.file_path // .tool_response.filePath // empty' 2>/dev/null)"
	case "$file" in
		*.gd) ;;
		*) exit 0 ;;   # not GDScript, nothing to compile
	esac
fi

errors="$(cd "$PROJECT" && godot --headless --path . --import 2>&1 \
	| grep -E 'SCRIPT ERROR|Parse Error|Compile Error' \
	| head -30)"

[ -z "$errors" ] && exit 0

{
	echo "GDScript check failed after writing ${file}:"
	echo "$errors"
	echo
	echo "(tkg/tools/gdcheck.sh -- run 'godot --headless --path tkg --import' to reproduce)"
} >&2
exit 2
