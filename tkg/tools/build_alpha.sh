#!/usr/bin/env bash
# Make an alpha build for friends, from a CLEAN tree: both platforms exported
# by tools/export.sh (stamped, release, pack-checked, smoke-tested), each zipped
# with README-ALPHA.txt and LICENSES.txt from the repo root, the sizes and
# checksums printed. Uploading and tagging are left as commented steps at the
# end -- they are outward-facing and done by hand, on purpose.
#
#   GODOT=<path to godot_console.exe> tkg/tools/build_alpha.sh
#
# Writes builds/<version>-<commit>/ThreeKelvin-<version>-win64.zip and
# ThreeKelvin-<version>-mac.zip (the repo's builds/ is gitignored).
#
# The Windows zip holds ONE folder, ThreeKelvin-<version>/, so "Extract All"
# makes a tidy folder: ThreeKelvin.exe (the game, its data embedded -- it runs
# even double-clicked inside the zip), ThreeKelvin.console.exe (the same game
# with a text window, for when it will not start), and the two texts.
#
# The Mac zip holds Godot's own zip NOT re-zipped: re-zipping the .app on
# Windows drops the app's run permission, and anything put inside the .app
# after signing breaks its signature ("damaged", with no Open Anyway). The
# README and licence go BESIDE it, never inside.
#
# ZIPS ARE MADE WITH bsdtar (Windows' own tar.exe, or `zip` elsewhere), never
# PowerShell's Compress-Archive: Windows PowerShell 5.1 writes its paths with
# backslashes, which a Mac unzips as one file with "\" in its name.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
HERE="$ROOT/tkg/tools"

# A build somebody plays must be one anybody can check out again.
if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
	echo "build_alpha: the working tree is not clean -- commit or stash first:"
	git -C "$ROOT" status --short | head -20
	exit 1
fi
for f in README-ALPHA.txt LICENSES.txt; do
	# LICENSES.txt is not optional: Godot's MIT licence and the font's OFL
	# both have to travel with the binaries.
	[ -f "$ROOT/$f" ] || { echo "build_alpha: $f is missing from the repo root"; exit 1; }
done

bash "$HERE/export.sh" all || { echo "build_alpha: export failed -- nothing zipped"; exit 1; }

VERSION="$(sed -n 's/^config\/version="\(.*\)"/\1/p' "$ROOT/tkg/project.godot" | head -1)"
COMMIT="$(git -C "$ROOT" rev-parse --short HEAD)"
OUT="$ROOT/builds/$VERSION-$COMMIT"
NAME="ThreeKelvin-$VERSION"

# zip_dir <parent> <zip> <entries...>: each entry (a folder or a file) under
# <parent> into <zip>, its paths relative to <parent>.
zip_dir() {
	local parent="$1" dst="$2"; shift 2
	rm -f "$dst"
	if command -v zip >/dev/null 2>&1; then
		(cd "$parent" && zip -qr "$dst" "$@")
	elif [ -x /c/Windows/System32/tar.exe ]; then
		(cd "$parent" && /c/Windows/System32/tar.exe -a -c -f "$(cygpath -w "$dst")" "$@")
	else
		echo "build_alpha: no zip tool (zip, or Windows' tar.exe)"; return 1
	fi
	[ -s "$dst" ]
}
# Every name given must be in the zip, or the build stops.
expect() {
	local z="$1" list; shift
	list="$(unzip -Z1 "$z")" || { echo "build_alpha: cannot read $z"; return 1; }
	for e in "$@"; do
		grep -qxF "$e" <<<"$list" || { echo "build_alpha: $z is missing $e"; return 1; }
	done
	if grep -q '\\' <<<"$list"; then echo "build_alpha: $z has backslashes in its paths"; return 1; fi
}

# --- Windows ------------------------------------------------------------------
STAGE="$OUT/stage"
rm -rf "$STAGE"; mkdir -p "$STAGE/$NAME"
cp "$OUT/windows/ThreeKelvin.exe" "$OUT/windows/ThreeKelvin.console.exe" \
	"$ROOT/README-ALPHA.txt" "$ROOT/LICENSES.txt" "$STAGE/$NAME/"
WIN="$OUT/$NAME-win64.zip"
zip_dir "$STAGE" "$WIN" "$NAME" || { echo "build_alpha: could not zip Windows"; exit 1; }
expect "$WIN" "$NAME/ThreeKelvin.exe" "$NAME/ThreeKelvin.console.exe" \
	"$NAME/README-ALPHA.txt" "$NAME/LICENSES.txt" || exit 1

# --- macOS --------------------------------------------------------------------
# Godot's zip as written, with the texts beside it, zipped once around the
# outside (the .app inside Godot's zip is untouched).
rm -rf "$STAGE"; mkdir -p "$STAGE"
cp "$OUT/macos/ThreeKelvin.zip" "$STAGE/Three Kelvin (Mac app).zip"
cp "$ROOT/README-ALPHA.txt" "$ROOT/LICENSES.txt" "$STAGE/"
MAC="$OUT/$NAME-mac.zip"
zip_dir "$STAGE" "$MAC" "Three Kelvin (Mac app).zip" README-ALPHA.txt LICENSES.txt \
	|| { echo "build_alpha: could not zip Mac"; exit 1; }
expect "$MAC" "Three Kelvin (Mac app).zip" README-ALPHA.txt LICENSES.txt || exit 1
rm -rf "$STAGE"

echo
echo "build_alpha: $VERSION · $COMMIT"
for z in "$WIN" "$MAC"; do
	printf '  %-6s %s\n         sha256 %s\n' "$(du -h "$z" | cut -f1)" "$z" "$(sha256sum "$z" | cut -d' ' -f1)"
done

# --- by hand, after a look -----------------------------------------------------
# Upload (itch, restricted page, password), one channel per platform:
#   butler push "$WIN" jonschmiddy/three-kelvin:windows-a1 --userversion "$VERSION"
#   butler push "$MAC" jonschmiddy/three-kelvin:mac-a1     --userversion "$VERSION"
# Tag the commit that was built:
#   git tag "alpha-$VERSION" "$COMMIT" && git push origin "alpha-$VERSION"
