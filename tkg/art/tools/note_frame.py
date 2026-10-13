"""The letter's button and its heart, authored pixel by pixel.

Jon's two notes (`AlphaNotes`, drawn by `NoteCard`) end in a pixel heart for
"<3" and move on with one primary button. Both are drawn here rather than with
draw_rect, so they read as made art beside the game's other art: the heart a
small shaded sprite, the button an amber plate with a dark rim, a bevel lit from
the top left (pressed: lit from the bottom right) and chamfered corners.

AT 1x: these sit beside the interface's type. The game nine-slices the button
with its edges tiled and draws the heart doubled.

    python tkg/art/tools/note_frame.py        (writes into tkg/art/sprites/ui/)

Outputs:
    note_button.png        16x16, margin 5, the primary button at rest
    note_button_hover.png  the same, lit
    note_button_down.png   the same, pressed in
    note_heart.png         9x8, the "<3" under each note
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixeltools  # noqa: E402

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "sprites", "ui")

DEEP = (8, 12, 18)
AMBER = (0xff, 0x9d, 0x3d)      # UITheme.FLARE
AMBER_HOT = (0xff, 0xd2, 0x8a)  # UITheme.HOT


def blank(w, h):
    return [bytearray(w * 4) for _ in range(h)]


def put(rows, x, y, c, a=255):
    rows[y][x * 4:x * 4 + 4] = bytes((c[0], c[1], c[2], a))


def button(state):
    S, CH = 16, 2
    fill = {"rest": (74, 40, 12), "hover": (112, 60, 18), "down": (52, 28, 9)}[state]
    hi = {"rest": AMBER, "hover": AMBER_HOT, "down": (122, 58, 16)}[state]
    lo = {"rest": (122, 58, 16), "hover": (160, 80, 22), "down": AMBER}[state]
    rows = blank(S, S)
    for y in range(S):
        for x in range(S):
            cut = min(x + y, (S - 1 - x) + y, x + (S - 1 - y), (S - 1 - x) + (S - 1 - y))
            if cut < CH:
                continue
            d = {"top": y, "left": x, "bottom": S - 1 - y, "right": S - 1 - x}
            side = min(d, key=lambda k: d[k])
            depth = d[side]
            if cut == CH or depth == 0:
                put(rows, x, y, DEEP)
            elif depth == 1 or cut == CH + 1:
                put(rows, x, y, hi if side in ("top", "left") else lo)
            else:
                put(rows, x, y, fill)
    return S, S, rows


HEART = [
    ".XX...XX.",
    "XHXX.XXXX",
    "XHXXXXXXX",
    "XXXXXXXXS",
    ".XXXXXXS.",
    "..XXXXS..",
    "...XXS...",
    "....S....",
]


def heart():
    body, hi, shade = (0xd4, 0x61, 0x4f), (0xf0, 0x9a, 0x86), (0x93, 0x3c, 0x30)
    w, h = len(HEART[0]), len(HEART)
    rows = blank(w, h)
    for y, line in enumerate(HEART):
        for x, ch in enumerate(line):
            if ch != ".":
                put(rows, x, y, {"X": body, "H": hi, "S": shade}[ch])
    return w, h, rows


def main():
    os.makedirs(OUT, exist_ok=True)
    jobs = [("note_button.png", button("rest")), ("note_button_hover.png", button("hover")),
            ("note_button_down.png", button("down")), ("note_heart.png", heart())]
    for name, (w, h, rows) in jobs:
        dst = os.path.join(OUT, name)
        pixeltools.encode(dst, w, h, rows)
        print("%s  %dx%d" % (os.path.normpath(dst), w, h))


if __name__ == "__main__":
    main()
