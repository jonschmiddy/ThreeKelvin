#!/usr/bin/env bash
# Pull finished PixelLab jobs into a directory.
#
#   tools/pull_jobs.sh <outdir> <<< "<job-id> <name>" ...
#
# CHECKS THE PNG MAGIC, NOT THE FILE SIZE. The first version called anything
# under 300 bytes a failure, on the reasoning that the "still generating" reply
# is a short JSON body. It is -- and so is a 40x40 sprite of a flat rail, which
# compressed to 291 bytes and was thrown away and refetched forty times before
# being reported as a failure it never was. The body either starts with the PNG
# signature or it does not; nothing else is evidence.
set -u
out="$1"; mkdir -p "$out"
while read -r id name; do
  [ -z "${id:-}" ] && continue
  ok=""
  for _ in $(seq 1 40); do
    curl -sS -L -o "$out/$name.png" "https://api.pixellab.ai/mcp/images/$id/download"
    if [ "$(head -c 4 "$out/$name.png" | od -An -tx1 | tr -d ' \n')" = "89504e47" ]; then
      ok=1; break
    fi
    # The retry IS the wait: another round trip to the same endpoint costs
    # roughly the latency we would otherwise sleep for, and this shell has no
    # sleep to call.
    curl -sS -o /dev/null "https://api.pixellab.ai/mcp/images/$id/download"
  done
  [ -n "$ok" ] || echo "FAIL $name"
done
