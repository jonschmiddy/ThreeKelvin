#!/usr/bin/env bash
# gate_land.sh <worktree> <branch> <label>
#
# The only way anything reaches main. In the worktree: merge main, import, run
# the full gate (.github/scripts/validate.sh, about 12 minutes); on a pass,
# fast-forward main in the main checkout to the branch and push it.
# Last line: "LANDED <label> <sha>" or "FAILED <label> (why)".
#
# ONE AT A TIME. The gate's timing steps fail when the machine is busy, so never
# run two, and pause other Godot work while one runs.
#
# A conflict in CHANGELOG.md alone is two branches adding lines under
# [Unreleased]; resolve_changelog.py keeps both sides and the merge carries on.
# Any other conflict stops it: resolve by hand in the worktree, commit, rerun.
set -uo pipefail
D="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$D/env.sh"
W="$1"; B="$2"; L="$3"
LOG="$TK_SCRATCH/logs/gate_${L}.log"
tk_guard || { echo "FAILED $L (profile guard)"; exit 1; }
cd "$W" || { echo "FAILED $L (no worktree)"; exit 1; }
git merge --no-edit -q main 2>&1 | tail -2
if [ "$(git diff --name-only --diff-filter=U)" = "CHANGELOG.md" ]; then
	"$PY" "$D/resolve_changelog.py" CHANGELOG.md && ! grep -q "^<<<<<<<" CHANGELOG.md \
		&& git add CHANGELOG.md && git commit -q --no-edit && echo "(CHANGELOG conflict resolved, both sides kept)"
fi
if git status --short | grep -qE "^(UU|AA|DU|UD)"; then
	git status --short | grep -E "^(UU|AA|DU|UD)"; echo "FAILED $L (merge conflict)"; exit 1
fi
p="$(tk_new_profile)"
tk_isolated "$p" tk_timeout 900 "$GODOT" --headless --audio-driver Dummy --path tkg --import >/dev/null 2>&1 \
	|| tk_isolated "$p" tk_timeout 900 "$GODOT" --headless --audio-driver Dummy --path tkg --import >/dev/null 2>&1
rm -rf "$p"
GODOT="$D/godot_quiet.sh" bash .github/scripts/validate.sh >"$LOG" 2>&1
grep -E "FAIL" "$LOG" | head -12
if ! grep -q "VALIDATION PASSED" "$LOG"; then echo "FAILED $L (gate, log $LOG)"; exit 1; fi
cd "$TK_REPO" && git merge-base --is-ancestor main "$B" && git merge --ff-only -q "$B" \
	&& git push -q origin main && echo "LANDED $L $(git rev-parse --short main)" && exit 0
echo "FAILED $L (ff/push: is the main checkout on main and clean?)"; exit 1
