"""Box test for status A (Nov 20): every kit frame is the whole glass, 150x140 (152x140 for the torch, the
leak, the dock). The old deck clearance (nothing lit in rows 128-131 above the haul line at 132) is gone
with the strip. Prints each frame's size.

    uv run --with pillow python kit_boxtest.py [frames dir]
"""
import sys
from pathlib import Path
from PIL import Image

d = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / "kit_frames"
bad = 0
for p in sorted(d.glob("*.png")):
    w, h = Image.open(p).size
    ok = h == 140 and w in (150, 152)
    bad += 0 if ok else 1
    print("%-28s %dx%d  %s" % (p.name, w, h, "ok" if ok else "NOT 150x140 (152x140)"))
print("FAIL: %d frames" % bad if bad else "PASS")
