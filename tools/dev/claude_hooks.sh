#!/usr/bin/env bash
# claude_hooks.sh bash-guard|edit-ratchets|stop-nudge|stamp [--tests]|--selftest
#
# The launcher for tools/dev/claude_hooks.py, which holds the Claude Code hooks (.claude/settings.json
# calls this). It finds a working python the way tools/dev/env.sh does (python3, else python) without
# sourcing env.sh, because the command guard runs before every Bash call and has to be quick.
# No python: it says nothing and exits 0, so a hook never stops work because a tool is missing.
# Why: docs/why/claude_hooks.md
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -z "${PY:-}" ]; then
	if python3 -c "" >/dev/null 2>&1; then PY=python3; else PY=python; fi
fi
"$PY" -c "" >/dev/null 2>&1 || exit 0
exec "$PY" "$HERE/claude_hooks.py" "$@"
