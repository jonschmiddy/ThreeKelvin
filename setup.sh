#!/usr/bin/env bash
#
# Three Kelvin — one-time setup for a fresh clone.
#
#   ./setup.sh
#
# Safe to run twice. It changes nothing but your local git config, and it
# prints what it did.
#
# The only thing it currently does is point git at the hooks this repository
# ships. That needs saying, because it is the one piece of project setup git
# genuinely cannot do for you: `.git/hooks/` is NOT version controlled, by
# design — a repository that could install executables that run on `git
# commit` just by being cloned would be a security hole. So hooks live in
# `.githooks/` where they can be reviewed in a diff like everything else, and
# `core.hooksPath` is the one switch that has to be thrown per clone.
#
# If you would rather not run hooks at all, don't run this. Nothing in the
# merge gate depends on it; the graph just goes stale, which is what it did
# for the hundred and sixteen commits before this script existed.

set -uo pipefail

cd "$(dirname "$0")" || exit 1

say()  { printf '  %s\n' "$1"; }
ok()   { printf '  \033[32mok\033[0m    %s\n' "$1"; }
note() { printf '  \033[33mnote\033[0m  %s\n' "$1"; }

printf '\n\033[1m=== Three Kelvin setup ===\033[0m\n'

if [ ! -d .git ]; then
	note "not a git checkout — nothing to configure"
	exit 0
fi

# --- git hooks -------------------------------------------------------------
#
# `core.hooksPath` REPLACES `.git/hooks/` rather than adding to it. So any hook
# previously installed there stops running the moment this is set, which is
# what we want — otherwise a graphify rebuild fires twice per commit.

current="$(git config core.hooksPath || true)"
if [ "$current" = ".githooks" ]; then
	ok "hooks already pointed at .githooks"
else
	git config core.hooksPath .githooks
	ok "hooks now run from .githooks (was: ${current:-.git/hooks})"
fi

for h in post-commit post-checkout; do
	if [ -f ".git/hooks/$h" ]; then
		mv ".git/hooks/$h" ".git/hooks/$h.superseded"
		note "moved stale .git/hooks/$h aside (superseded by .githooks/$h)"
	fi
	[ -x ".githooks/$h" ] || chmod +x ".githooks/$h"
done

# --- what the hooks need ---------------------------------------------------
#
# Reported, not installed. A setup script that silently pulls a Python package
# down is a setup script nobody reads twice.

if command -v graphify >/dev/null 2>&1; then
	ok "graphify found — the knowledge graph will rebuild after each commit"
else
	note "graphify is NOT installed, so the hooks will no-op (harmlessly)."
	say  "The graph under graphify-out/ is how the project answers questions"
	say  "about itself. To enable it:  uv tool install graphifyy"
fi

if command -v godot >/dev/null 2>&1; then
	ok "godot found — .github/scripts/validate.sh will run"
else
	note "godot is NOT on PATH. The merge gate needs it:"
	say  "  GODOT=/path/to/Godot .github/scripts/validate.sh"
fi

printf '\n  Done. The gate is:  .github/scripts/validate.sh\n\n'
