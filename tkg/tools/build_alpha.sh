#!/usr/bin/env bash
# Make an alpha build for friends, from a CLEAN tree: both platforms exported
# by tools/export.sh (stamped, release, smoke-tested), each zipped, the paths
# printed. Uploading and tagging are left as commented steps at the end -- they
# are outward-facing and done by hand, on purpose.
#
#   tools/build_alpha.sh
#
# The Windows zip is made here: the game's folder (ThreeKelvin.exe, its .pck
# beside it -- a friend who runs the exe from inside the zip without the pck
# gets "Couldn't load project data", so the README says Extract All first --
# and ThreeKelvin.console.exe), plus README-ALPHA.txt / LICENSES.txt if they
# exist at the repo root.
#
# The Mac zip is Godot's own, NOT re-zipped: re-zipping on Windows drops the
# app's run permission, and anything put inside the .app after signing breaks
# its signature ("damaged", with no Open Anyway). The README and licence go
# BESIDE it in a folder of their own, never inside.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERE="$ROOT/tkg/tools"

# A build somebody plays must be one anybody can check out again.
if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
	echo "build_alpha: the working tree is not clean -- commit or stash first:"
	git -C "$ROOT" status --short | head -20
	exit 1
fi

bash "$HERE/export.sh" all || { echo "build_alpha: export failed"; exit 1; }

VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$ROOT/tkg/project.godot" | head -1)"
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD)"
OUT="$ROOT/builds/$VERSION-$COMMIT"
NAME="ThreeKelvin-$VERSION"

zip_dir() {
	# PowerShell's Compress-Archive on Windows (no zip there by default), zip elsewhere.
	local src="$1" dst="$2"
	rm -f "$dst"
	if command -v zip >/dev/null 2>&1; then
		(cd "$src" && zip -qr "$dst" .)
	else
		powershell.exe -NoProfile -Command "Compress-Archive -Path '$(cygpath -w "$src")\\*' -DestinationPath '$(cygpath -w "$dst")'"
	fi
	[ -f "$dst" ]
}

extras() {
	local into="$1"
	for f in README-ALPHA.txt LICENSES.txt; do
		[ -f "$ROOT/$f" ] && cp "$ROOT/$f" "$into/"
	done
}

# --- Windows ------------------------------------------------------------------
extras "$OUT/windows"
WIN="$OUT/$NAME-win64.zip"
zip_dir "$OUT/windows" "$WIN" || { echo "build_alpha: could not zip Windows"; exit 1; }

# --- macOS --------------------------------------------------------------------
# Godot's zip as written, with the texts beside it in one folder, zipped once
# more around the outside (the .app inside Godot's zip is untouched).
MACDIR="$OUT/mac-pack"
rm -rf "$MACDIR"; mkdir -p "$MACDIR"
cp "$OUT/macos/ThreeKelvin.zip" "$MACDIR/$NAME-mac.zip"
extras "$MACDIR"
MAC="$OUT/$NAME-mac.zip"
if [ "$(ls "$MACDIR" | wc -l)" -gt 1 ]; then
	zip_dir "$MACDIR" "$OUT/$NAME-mac-with-readme.zip" || { echo "build_alpha: could not zip Mac"; exit 1; }
	MAC="$OUT/$NAME-mac-with-readme.zip"
else
	cp "$MACDIR/$NAME-mac.zip" "$MAC"
fi

echo
echo "build_alpha: $VERSION · $COMMIT"
echo "  windows: $WIN ($(du -h "$WIN" | cut -f1))"
echo "  mac:     $MAC ($(du -h "$MAC" | cut -f1))"

# --- by hand, after a look -----------------------------------------------------
# Upload (itch, restricted page, password), one channel per platform:
#   butler push "$WIN" jonschmiddy/three-kelvin:windows-a1 --userversion "$VERSION"
#   butler push "$MAC" jonschmiddy/three-kelvin:mac-a1     --userversion "$VERSION"
# Tag the commit that was built:
#   git tag "alpha-$VERSION" "$COMMIT" && git push origin "alpha-$VERSION"
