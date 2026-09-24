"""Dump every sprite the bench draws as raw RGBA, for `bench_probe.js`.

    python tools/bench_pixdump.py [--stage <dir>] [--out tools/out/pix]

WHY RAW RGBA AND NOT THE PNGs. The probe backs a stub canvas with real pixels
so the page's own `getImageData` returns something, and node has no PNG decoder
on hand. `pixeltools.decode` already has one, so the decoding happens here once
and the probe just reads bytes.

This is the half of the build gate that can see a feature. `bench_check.js`
runs the page against a stub whose `getImageData` returns undefined -- every
routine that reads pixels falls into its own try/catch and reports nothing
found, so the check goes green on code that draws nothing. That is how a dead
vending-machine glow survived three builds.
"""
import io
import json
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
STATION = os.path.abspath(os.path.join(HERE, "..", "tkg", "art", "sprites", "station"))


def main():
    argv = sys.argv[1:]
    out = os.path.join(HERE, "out", "pix")
    stage = None
    if "--out" in argv:
        out = argv[argv.index("--out") + 1]
    if "--stage" in argv:
        stage = argv[argv.index("--stage") + 1]
    os.makedirs(out, exist_ok=True)
    meta, skipped = {}, 0
    for d in [p for p in (stage, STATION) if p and os.path.isdir(p)]:
        for f in sorted(os.listdir(d)):
            if not f.endswith(".png") or f in meta:
                continue
            try:
                w, h, rows = pixeltools.decode(os.path.join(d, f))
            except Exception:
                skipped += 1
                continue
            buf = bytearray()
            for r in rows:
                buf += r
            with open(os.path.join(out, f + ".rgba"), "wb") as g:
                g.write(buf)
            meta[f] = [w, h]
    json.dump(meta, io.open(os.path.join(out, "_meta.json"), "w", encoding="utf-8"))
    print("%d sprites dumped to %s%s"
          % (len(meta), out, (" (%d unreadable)" % skipped) if skipped else ""))


if __name__ == "__main__":
    main()
