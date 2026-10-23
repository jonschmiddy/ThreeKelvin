#!/usr/bin/env bash
# What .github/scripts/validate.sh is given as GODOT by gate_land.sh: the real
# binary with the dummy audio driver. validate.sh gives every unit its own
# profile folder itself, so this does not.
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"
exec "$GODOT" --audio-driver Dummy "$@"
