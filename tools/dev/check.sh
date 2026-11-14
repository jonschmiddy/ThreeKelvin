#!/usr/bin/env bash
# check.sh [--tests] [--staged] [--base REV] [--static [--quiet]]
#
# The one command to run before saying a change is done. In seconds: the gate's
# static checks (the ones that start no Godot: tabs, changes/, code_check,
# code_graph, comment_check, prose, vocab, ...; the same code as
# `GATE_STATIC=1 .github/scripts/validate.sh`), then `-- parseall` if Godot is found.
# --tests also runs the headless test rows this change needs (tests_for.py --run).
# --staged limits the test advice to what is staged. The merge gate is still the gate.
# --static stops after the static checks (the pre-commit hook's call); --quiet then
# prints only failures. A full pass also records the state of the tree it passed on
# (.git/tk-check-ok), which the Stop hook reads to know whether a check covers the work.
# Output: one line per check, each failure's own message, then `check: PASS` or
# `check: FAIL (n problems)`; exit 1 on failure. Why: docs/why/check.md#check
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
cd "$ROOT" || exit 2

RUN_TESTS=0; PARSED=0; STAGED=""; BASE="main"; STATIC_ONLY=0; QUIET=0
while [ $# -gt 0 ]; do
	case "$1" in
		--tests) RUN_TESTS=1 ;;
		--staged) STAGED="--staged" ;;
		--static) STATIC_ONLY=1 ;;
		--quiet) QUIET=1 ;;
		--base) shift; BASE="${1:-main}" ;;
		-h|--help) sed -n '2,14p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
		*) echo "check.sh: unknown option '$1' (try --help)" >&2; exit 2 ;;
	esac
	shift
done

# env.sh (Godot, python, scratch folders) is only needed past the static checks.
[ "$STATIC_ONLY" -eq 1 ] || source "$HERE/env.sh"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT
PROBLEMS=0
ESC="$(printf '\033')"

line() {  # line ok|FAIL "what" "secs"
	if [ "$1" = ok ]; then [ "$QUIET" -eq 1 ] || printf '  \033[32mok\033[0m    %s%s\n' "$2" "${3:+  ($3 s)}"
	else printf '  \033[31mFAIL\033[0m  %s%s\n' "$2" "${3:+  ($3 s)}"; fi
}

# --- 1. the static gate units ------------------------------------------------
T0=$SECONDS
GATE_STATIC=1 GATE_JOBS="${GATE_JOBS:-6}" LOG_DIR="$OUT/logs" bash "$ROOT/.github/scripts/validate.sh" >"$OUT/static.raw" 2>&1
SCODE=$?
sed "s/${ESC}\[[0-9;]*m//g" "$OUT/static.raw" >"$OUT/static.txt"
# Each "=== title" block up to the "Time per unit" summary is one check; its
# ok/FAIL lines are the unit's own words.
awk -v out="$OUT" '
	/^=== Time per unit/ { stop = 1 }
	stop { next }
	/^=== / { n++; title[n] = substr($0, 5); next }
	n > 0 { body[n] = body[n] $0 "\n"; if ($0 ~ /^  FAIL /) failed[n] = 1 }
	END {
		for (i = 1; i <= n; i++) {
			f = out "/step_" i ".txt"
			printf "%s\n%s", (failed[i] ? "FAIL" : "ok"), title[i] > f
			printf "\n%s", body[i] >> f
			close(f)
		}
		print n > (out "/steps")
	}' "$OUT/static.txt"
STEPS="$(cat "$OUT/steps" 2>/dev/null || echo 0)"
i=1
while [ "$i" -le "$STEPS" ]; do
	state="$(sed -n 1p "$OUT/step_$i.txt")"
	title="$(sed -n 2p "$OUT/step_$i.txt")"
	if [ "$state" = ok ]; then
		line ok "$title"
	else
		line FAIL "$title"
		sed -n '3,$p' "$OUT/step_$i.txt" | grep -v '^$' | head -n 30 | sed 's/^/        /'
		PROBLEMS=$((PROBLEMS + $(sed -n '3,$p' "$OUT/step_$i.txt" | grep -c '^  FAIL ')))
	fi
	i=$((i + 1))
done
if [ "$SCODE" -ne 0 ] && [ "$PROBLEMS" -eq 0 ]; then
	# validate.sh itself refused to run (a duplicate unit, a bad name): its words are the message.
	line FAIL "the static checks did not run"
	head -n 12 "$OUT/static.txt" | sed 's/^/        /'
	PROBLEMS=$((PROBLEMS + 1))
fi
[ "$QUIET" -eq 1 ] || echo "  static checks: $((SECONDS - T0)) s"
if [ "$STATIC_ONLY" -eq 1 ]; then
	if [ "$PROBLEMS" -eq 0 ]; then echo "check: PASS"; exit 0; fi
	echo "check: FAIL ($PROBLEMS problems)"
	exit 1
fi

# --- 2. every script still loads ----------------------------------------------
if [ -x "$GODOT" ] || command -v "$GODOT" >/dev/null 2>&1; then
	T1=$SECONDS
	bash "$HERE/godot.sh" -t 300 --headless --path tkg -- parseall >"$OUT/parseall.log" 2>&1
	PCODE=$?
	if [ "$PCODE" -eq 0 ] && grep -q '^parseall: PASS' "$OUT/parseall.log" \
		&& ! grep -E 'SCRIPT ERROR|Parse Error|Compile Error|^ERROR:' "$OUT/parseall.log" >/dev/null; then
		line ok "parseall: every script loads" "$((SECONDS - T1))"
		PARSED=1
	else
		line FAIL "parseall: a script does not load (godot exit $PCODE)" "$((SECONDS - T1))"
		grep -E 'SCRIPT ERROR|Parse Error|Compile Error|^ERROR:|FAIL' "$OUT/parseall.log" | head -n 12 | sed 's/^/        /'
		echo "        If it names an unknown class, a class_name is new: run  bash tools/dev/godot.sh --headless --path tkg --import  and try again."
		PROBLEMS=$((PROBLEMS + 1))
	fi
else
	echo "  skip  parseall: no Godot found (set GODOT=/path/to/Godot to include it); no stamp is written, so the Stop reminder stays on"
fi

# --- 3. the tests this change needs -------------------------------------------
TF=("$PY" "$HERE/tests_for.py" --base "$BASE")
[ -n "$STAGED" ] && TF+=("$STAGED")
if [ "$RUN_TESTS" -eq 1 ]; then
	T2=$SECONDS
	"${TF[@]}" --run >"$OUT/tests.txt" 2>&1
	TCODE=$?
	grep -E '^  (ok  |FAIL) |^        |^tests_for: (PASS|FAIL)|no test row covers|^[a-z].*\.(gd|gdshader)$' "$OUT/tests.txt" | head -n 60 | sed 's/^  ok  /  ok    test: /; s/^  FAIL /  FAIL  test: /'
	if [ "$TCODE" -ne 0 ]; then
		BADN="$(grep -c '^  FAIL ' "$OUT/tests.txt")"
		[ "$BADN" -eq 0 ] && BADN=1
		PROBLEMS=$((PROBLEMS + BADN))
	fi
	echo "  tests: $((SECONDS - T2)) s"
else
	"${TF[@]}" >"$OUT/tests.txt" 2>&1
	N="$(grep -E 'rows to run by machine' "$OUT/tests.txt" | tail -n 1)"
	if [ -n "$N" ]; then echo "  tests this change needs: $N  (run them: tools/dev/check.sh --tests; list: python3 tools/dev/tests_for.py)"; fi
	awk '/^tkg\// { f = $1 } /no test row covers/ { print "  note  " f ": no test row covers this file: say so in the PR, or add a row to docs/tests.md" }' "$OUT/tests.txt"
fi

echo
if [ "$PROBLEMS" -eq 0 ]; then
	# Record that this exact tree passed, for the Stop hook's reminder (tools/dev/claude_hooks.py,
	# docs/why/claude_hooks.md): a file under this worktree's .git directory. Never fails the check.
	# Only a check that parsed the scripts counts (no Godot: no stamp), and --tests is marked only
	# when the tests really ran.
	if [ "$PARSED" -eq 1 ]; then
		if [ "$RUN_TESTS" -eq 1 ]; then
			"$PY" "$HERE/claude_hooks.py" stamp --tests >/dev/null 2>&1 || true
		else
			"$PY" "$HERE/claude_hooks.py" stamp >/dev/null 2>&1 || true
		fi
	fi
	echo "check: PASS"
	exit 0
fi
echo "check: FAIL ($PROBLEMS problems)"
echo "The merge gate (tools/dev/gate_land.sh) runs all of this and more; fix these first."
exit 1
