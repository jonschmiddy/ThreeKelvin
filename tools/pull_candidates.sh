#!/usr/bin/env bash
# Pull the four candidates of each finished create_image_pro job.
#
#   tools/pull_candidates.sh <outdir> <n> < jobs.txt      # "<job-id> <name>"
#
# create_image_pro returns a SET, reached as ?index=0..n-1 on the same download
# URL. pull_jobs.sh predates the pro model and fetches index 0 only, which is
# why it cannot be used for a card round: three of every four candidates are
# simply never downloaded.
set -u
out="$1"; n="${2:-4}"; mkdir -p "$out"
while read -r id name; do
  [ -z "${id:-}" ] && continue
  for i in $(seq 0 $((n - 1))); do
    f="$out/${name}_$((i + 1)).png"
    ok=""
    for _ in $(seq 1 40); do
      curl -sS -L -o "$f" "https://api.pixellab.ai/mcp/images/$id/download?index=$i"
      if [ "$(head -c 4 "$f" | od -An -tx1 | tr -d ' \n')" = "89504e47" ]; then
        ok=1; break
      fi
      curl -sS -o /dev/null "https://api.pixellab.ai/mcp/images/$id/download?index=$i"
    done
    [ -n "$ok" ] || echo "FAIL ${name}_$((i + 1))"
  done
done
