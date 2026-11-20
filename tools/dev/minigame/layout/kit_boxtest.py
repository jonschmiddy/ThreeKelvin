"""Box test (Jon, Nov 20: "the dials come right up to the reward line"): the haul line is at row 132,
so rows 128-131 must hold nothing lit: in every kit frame, rows 128-129 of the 150x130 game area hold
nothing brighter than the border colour (#111823). Prints each frame's lowest non-border row in the deck (>= 98).

    uv run --with pillow python kit_boxtest.py [frames dir]
"""
import sys
from pathlib import Path
from PIL import Image

BORDER = (0x11, 0x18, 0x23)
d = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent / "kit_frames"
bad = 0
for p in sorted(d.glob("*.png")):
    im = Image.open(p).convert("RGB")
    w, h = im.size
    x0 = 1 if w == 152 else 0
    low = -1
    for y in range(h - 1, 97, -1):
        # lit: brighter than the border (a dimming veil over the deck is darker, not lit)
        if any(sum(im.getpixel((x, y))) > sum(BORDER) for x in range(x0, w - x0)):
            low = y
            break
    ok = low < 128
    bad += 0 if ok else 1
    print("%-28s lowest lit row %3d  %s" % (p.name, low, "ok" if ok else "TOO LOW (needs <= 127)"))
print("FAIL: %d frames" % bad if bad else "PASS")
