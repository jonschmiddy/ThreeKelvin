"""The game's desk frames beside the approved page's, file by file.

    uv run --with pillow --with numpy python tools/desk/diff_desk.py GAME_DIR PAGE_DIR OUT_DIR

GAME_DIR is `-- sheet=DeskRooms`'s output, PAGE_DIR `dump_desk.py frames`'s (with manifest.json).
For each frame: the pixels that differ at all, those off by more than 8 in a channel, and the mean
difference; then OUT_DIR/<name> is the page (left) and the game (right) at 2x art scale (half the
page's canvas, as the game is judged), and OUT_DIR/diff_<name> the differing pixels in magenta.
Exits 1 when a frame is missing.
"""
import json, sys
from pathlib import Path

import numpy as np
from PIL import Image


def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    game, page, out = (Path(a) for a in sys.argv[1:])
    out.mkdir(parents=True, exist_ok=True)
    man = json.loads((page / "manifest.json").read_text(encoding="utf-8"))
    missing = 0
    print("%-16s %9s %9s %7s" % ("frame", "differ", "off>8", "mean"))
    for f in man["frames"]:
        n = f["name"]
        if not (game / n).exists():
            print("%-16s missing" % n)
            missing += 1
            continue
        a = np.asarray(Image.open(page / n).convert("RGB")).astype(int)
        b = np.asarray(Image.open(game / n).convert("RGB")).astype(int)
        d = np.abs(a - b).max(axis=2)
        print("%-16s %9d %9d %7.3f" % (n, (d > 0).sum(), (d > 8).sum(), np.abs(a - b).mean()))
        half = lambda x: Image.fromarray(x.astype(np.uint8)).resize((960, 540), Image.NEAREST)
        sb = Image.new("RGB", (1928, 540), (255, 255, 255))
        sb.paste(half(a), (0, 0))
        sb.paste(half(b), (968, 0))
        sb.save(out / n)
        m = (b // 3).astype(np.uint8)
        m[d > 0] = (255, 0, 255)
        m[d > 8] = (255, 255, 0)
        Image.fromarray(m).save(out / ("diff_" + n))
    sys.exit(1 if missing else 0)


if __name__ == "__main__":
    main()
