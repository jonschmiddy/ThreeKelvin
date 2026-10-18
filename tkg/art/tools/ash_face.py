"""A.S.H.'s face as the game reads it: ONE sheet, eight 64x64 frames in a row.

    uv run --with pillow --with numpy python art/tools/ash_face.py
    uv run --with pillow --with numpy python art/tools/ash_face.py --face <64x64.png>

Writes `art/ash/face.png` (512x64), the frames left to right:

    0 closed   1 slight   2 open   3 round
    4 closed+blink  5 slight+blink  6 open+blink  7 round+blink

`AshPortrait` cuts it by index and nothing else in the game knows her face, so
swapping her face is swapping this one file.

WHERE THE FRAMES COME FROM. Jon picked B15 (`tools/briefs/ash_face_takes/round2/
B_15.png`) and the talking frames were drawn by hand on it, free, in
`tools/briefs/ash_face_takes/talk/` (the mock-up he liked: "this is good"). By
default this copies those eight drawings as they are.

`--face` IS FOR THE DAY HE PICKS A VARIATION (32 of B15 sit in `variations/`,
none picked yet, Oct 17). The mouths and the blink are stored as what each
drawing changed on B15 -- a handful of pixels round the mouth and across the
eyes -- and laid onto the new face at the same place. That is right only while
the new face keeps B15's mouth and eyes where B15 has them, so the tool prints
how far the new face's own pixels there differ from B15's; a large number means
the patches will sit on the wrong features and the frames want redrawing by
hand (free, as these were). Look at the sheet at 2x before keeping it.
"""

import argparse
import os
import sys

import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
TKG = os.path.dirname(os.path.dirname(HERE))
REPO = os.path.dirname(TKG)
TAKES = os.path.join(REPO, "tools", "briefs", "ash_face_takes")
TALK = os.path.join(TAKES, "talk")
BASE = os.path.join(TAKES, "round2", "B_15.png")
OUT = os.path.join(TKG, "art", "ash", "face.png")

ORDER = ["closed", "slight", "open", "round",
         "closed_blink", "slight_blink", "open_blink", "round_blink"]
SIZE = 64


def load(path: str) -> np.ndarray:
    im = Image.open(path).convert("RGBA")
    if im.size != (SIZE, SIZE):
        sys.exit("%s is %dx%d, not %dx%d" % (path, im.size[0], im.size[1], SIZE, SIZE))
    return np.array(im)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--face", help="a 64x64 face to lay B15's mouths and blink onto")
    ap.add_argument("--out", default=OUT)
    a = ap.parse_args()

    base = load(BASE)
    talk = {n: load(os.path.join(TALK, n + ".png")) for n in ORDER}
    if not np.array_equal(talk["closed"], base):
        print("note: talk/closed.png is not B15 pixel for pixel")

    frames = [talk[n] for n in ORDER]
    if a.face:
        face = load(a.face)
        changed = np.zeros((SIZE, SIZE), bool)
        for n in ORDER:
            changed |= np.any(talk[n] != base, axis=2)
        moved = int(np.any(face[changed] != base[changed], axis=1).sum())
        print("%d of the %d pixels the mouths and blink change differ on the new face"
              % (moved, int(changed.sum())))
        frames = []
        for n in ORDER:
            f = face.copy()
            d = np.any(talk[n] != base, axis=2)
            f[d] = talk[n][d]
            frames.append(f)

    sheet = np.concatenate(frames, axis=1)
    os.makedirs(os.path.dirname(a.out), exist_ok=True)
    Image.fromarray(sheet, "RGBA").save(a.out)
    print("wrote %s (%dx%d, %d frames)" % (a.out, sheet.shape[1], sheet.shape[0], len(frames)))


if __name__ == "__main__":
    main()
