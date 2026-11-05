#!/usr/bin/env bash
# new_things_check.sh <version> [NewThings.gd]
#
# The title menu's NEW THINGS page lists what changed in each build, newest
# first (tkg/scripts/data/NewThings.gd). A release must ship with its own entry
# on top: the version it is cut as, dated, and no NEXT entry left over (NEXT is
# work on main that has not gone out yet; the cut renames it). release.sh runs
# this before it lands anything, and again on the landed main.
#
# Exit 0 and one OK line, or exit 1 and say what is missing.
set -uo pipefail
VER="${1:?usage: new_things_check.sh <version> [NewThings.gd]}"
F="${2:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/tkg/scripts/data/NewThings.gd}"
[ -f "$F" ] || { echo "NEW THINGS: no $F"; exit 1; }
# the first entry's version and date, as written
top=$(grep -m1 -E '^\s*version = ' "$F" | sed -E 's/^\s*version = //; s/,\s*$//')
day=$(grep -m1 -E '^\s*date = ' "$F" | sed -E 's/^\s*date = "?//; s/"?,\s*$//')
if grep -qE '^\s*version = NEXT,' "$F"; then
	echo "NEW THINGS: the NEXT entry is still there. Rename it to \"$VER\" and date it before releasing $VER."
	exit 1
fi
if [ "$top" != "\"$VER\"" ]; then
	echo "NEW THINGS: no entry for $VER on top (the newest is $top). Add $VER's lines to $F before releasing."
	exit 1
fi
if ! echo "$day" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
	echo "NEW THINGS: $VER's entry has no date (YYYY-MM-DD), it has \"$day\"."
	exit 1
fi
echo "NEW THINGS: OK, $VER ($day) is the newest entry."
