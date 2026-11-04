"""Compare the game's badge frames with the approved page's, file by file.

    uv run --with pillow python tools/dev/badge/diff_frames.py GAME_DIR WEB_DIR [SHEET.png]

GAME_DIR from the game:      tools/dev/godot.sh --headless --path tkg -- sheet=BadgeFrames out=GAME_DIR
WEB_DIR from the page:       uv run --with playwright --with pillow python tools/dev/badge/dump_golden.py frames WEB_DIR
Both write the same names and a manifest.json. Prints each frame that differs (its first differing
pixel) and a total; exit 0 when every frame is identical. SHEET.png, if given, is a contact sheet at
4x: each row a jump, game over web, on the chart's dark.
"""
import json, sys
from pathlib import Path


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    from PIL import Image
    game, web = Path(sys.argv[1]), Path(sys.argv[2])
    names = [f["name"] for f in json.loads((game / "manifest.json").read_text(encoding="utf-8"))["frames"]]
    web_names = {f["name"] for f in json.loads((web / "manifest.json").read_text(encoding="utf-8"))["frames"]}
    bad = 0
    for n in names:
        if n not in web_names:
            print("only in the game:", n)
            bad += 1
            continue
        a = Image.open(game / n).convert("RGBA")
        b = Image.open(web / n).convert("RGBA")
        if a.size != b.size:
            print("%s: %s against %s" % (n, a.size, b.size))
            bad += 1
            continue
        pa, pb = a.load(), b.load()
        diff = [(x, y) for y in range(a.size[1]) for x in range(a.size[0]) if pa[x, y] != pb[x, y]]
        if diff:
            x, y = diff[0]
            print("%s: %d pixels differ, first at (%d,%d): game %s, page %s" % (n, len(diff), x, y, pa[x, y], pb[x, y]))
            bad += 1
    print("%d of %d frames identical to the page" % (len(names) - bad, len(names)))
    if len(sys.argv) > 3:
        rows = {}
        for n in names:
            rows.setdefault(n.split("_", 1)[0] + "_" + n.split("_")[1], []).append(n)
        z, w, h, pad = 4, 40, 15, 4
        cols = max(len(v) for v in rows.values())
        sheet = Image.new("RGBA", (pad + cols * (w * z + pad), pad + len(rows) * (2 * h * z + 3 * pad)), (10, 14, 21, 255))
        for r, (k, ns) in enumerate(sorted(rows.items())):
            for c, n in enumerate(ns):
                for i, d in enumerate((game, web)):
                    im = Image.open(d / n).convert("RGBA").resize((w * z, h * z), Image.NEAREST)
                    sheet.alpha_composite(im, (pad + c * (w * z + pad), pad + r * (2 * h * z + 3 * pad) + i * (h * z + pad)))
        sheet.save(sys.argv[3])
        print("wrote", sys.argv[3])
    return 0 if bad == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
