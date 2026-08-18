#!/bin/bash
# Three Kelvin launcher. Double-click to play.
cd "$(dirname "$0")"

# Prefer godot on PATH; fall back to the standard app bundle location.
GODOT=""
command -v godot >/dev/null 2>&1 && GODOT="godot"
if [ -z "$GODOT" ] && [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
  GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
fi

if [ -z "$GODOT" ]; then
  echo
  echo "  Could not find Godot."
  echo "  Install it with:  brew install --cask godot"
  echo
  read -r -p "Press Return to close." _
  exit 1
fi

exec "$GODOT" --path tkg
