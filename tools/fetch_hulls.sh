#!/usr/bin/env bash
# Download every finished job in $JOBS (default tools/out/jobs.txt) into $DEST
# (default tools/out/hull_candidates). Backgrounds are NOT stripped here --
# that is tools/strip_hulls.py, run afterwards. Safe to re-run: a file already
# there and non-trivial in size is skipped, so this can be called while jobs
# are still generating and again once they finish.
cd "$(dirname "$0")/.." || exit 1
JOBS="${JOBS:-tools/out/jobs.txt}"
DEST="${DEST:-tools/out/hull_candidates}"
mkdir -p "$DEST"
got=0; skip=0; wait=0
while read -r name id; do
  [ -z "$name" ] && continue
  out="$DEST/$name.png"
  if [ -s "$out" ] && [ "$(stat -c%s "$out")" -gt 1000 ]; then skip=$((skip+1)); continue; fi
  curl -s -o "$out" "https://api.pixellab.ai/mcp/images/$id/download"
  if [ "$(stat -c%s "$out" 2>/dev/null || echo 0)" -gt 1000 ]; then got=$((got+1));
  else rm -f "$out"; wait=$((wait+1)); fi
done < "$JOBS"
echo "downloaded $got, already had $skip, still generating $wait"
