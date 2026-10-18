"""Install Jon's picks from round four of the Solari modules.

    python tools/briefs/solari_modules_install4.py crucible:12 flare:69 [...]

Each pick is a take in tools/briefs/solari_module_takes4/<id>_<n>.png, made by
PixelLab Pro at the part's shipping box at 1x (20 px a cell), so it is copied
as drawn: no reduce, no snap, no scale_to_box. Jon picked off renders of the
raw take, and every take is already its box's size with hard alpha. `:flip`
after the number mirrors it left to right (`crucible:12:flip`).

Then: `godot --headless --path tkg --import`, and `-- artcheck` must list the
part as drawn at its size.

Installed Oct 17 (Jon's picks): annealer:85 bleedvalve:13 heliograph:25
heliostat:1 mirrorarray:4 plasma:5 radiatorsail:65 starfurnace:16 sunheart:7.
Still procedural, waiting on take numbers: crucible, flare, heathaze,
incinerator.
"""
import os
import sys

from PIL import Image

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
TAKES = os.path.join(ROOT, "tools", "briefs", "solari_module_takes4")
MODULES = os.path.join(ROOT, "tkg", "art", "sprites", "modules")

# The box each part ships at, in pixels (ArtCheck._module_box).
BOX = {
    "annealer": (40, 20), "bleedvalve": (20, 20), "crucible": (40, 40),
    "flare": (40, 20), "heathaze": (40, 20), "heliograph": (20, 20),
    "heliostat": (80, 20), "incinerator": (20, 20), "mirrorarray": (40, 20),
    "plasma": (60, 20), "radiatorsail": (40, 20), "starfurnace": (40, 40),
    "sunheart": (40, 40),
}


def main(picks):
    for pick in picks:
        parts = pick.split(":")
        pid, n = parts[0], int(parts[1])
        flip = len(parts) > 2 and parts[2] == "flip"
        src = os.path.join(TAKES, "%s_%d.png" % (pid, n))
        im = Image.open(src).convert("RGBA")
        if im.size != BOX[pid]:
            sys.exit("%s take %d is %dx%d, its box is %dx%d" % (pid, n, im.size[0], im.size[1], *BOX[pid]))
        if flip:
            im = im.transpose(Image.FLIP_LEFT_RIGHT)
        im.save(os.path.join(MODULES, pid + ".png"))
        print("installed %s <- take %d%s" % (pid, n, " (flipped)" if flip else ""))


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    main(sys.argv[1:])
