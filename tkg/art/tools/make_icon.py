#!/usr/bin/env python3
"""The game's icon: a galaxy going out from the edges in.

    python3 art/tools/make_icon.py

Writes `icon.png` at the project root, and `art/sprites/icon@4x.png` for store
listings and anywhere a 512 is wanted.

WHY A GALAXY AND NOT A SHIP. The old icon was a hull with lit windows, which is
a picture of the thing you fly rather than of the thing the game is about. This
is the premise in one image and it needs no text to say it: the core is warm and
the rim is cold, and everything the player does is a trip between those two
facts. It is also the picture they already spend the most time looking at —
`StarchartScreen` draws this same disc every time they plot a jump.

DRAWN AT 64 AND SCALED BY WHOLE NUMBERS. The art direction allows integer
magnification and nothing else, so the icon is authored at the size its pixels
are real and multiplied up. A 512 icon downsampled to 32 in a taskbar turns a
pixel-art game into a blurry smudge; a 64 tripled and quadrupled stays itself.

DETERMINISTIC. One seed, no randomness that is not derived from it, so re-running
this produces the identical file and the icon does not silently change every time
somebody regenerates it.
"""

import math
from pathlib import Path

from PIL import Image

# The game's own palette. Same hexes as scripts/ui/UITheme.gd — if those move,
# these move with them, because an icon in last season's colours is worse than
# no icon at all.
VOID = (10, 14, 21)
HOT = (255, 210, 138)
FLARE = (255, 157, 61)
EMBER = (217, 123, 41)
CHILL = (143, 163, 186)
ICE = (195, 210, 226)
LINE = (34, 48, 63)

N = 64  # authored size, in real pixels
SEED = 30_011  # arbitrary, fixed, and never to be changed casually


def lcg(seed):
    """A generator with no dependencies and no surprises across Python versions.

    `random` is seeded identically across runs but not guaranteed across
    releases, and this file's whole promise is that it produces the same bytes
    in five years. Sixteen lines of arithmetic is cheaper than that risk.
    """
    state = seed & 0xFFFFFFFF
    while True:
        state = (1103515245 * state + 12345) & 0x7FFFFFFF
        yield state / 0x7FFFFFFF


def ramp(t):
    """Core to rim, warm to cold, as a function of how far out you are.

    THE WHOLE IMAGE IS THIS FUNCTION. The four stops are the game's argument
    about temperature, in the order a player meets them flying inward: ice at the
    rim, chill through the middle distance, ember and then flare as the core
    starts to matter, and the last of the heat white at the centre.
    """
    stops = [(0.00, HOT), (0.18, FLARE), (0.38, EMBER), (0.66, CHILL), (1.00, ICE)]
    for i in range(len(stops) - 1):
        a, ca = stops[i]
        b, cb = stops[i + 1]
        if t <= b:
            k = 0.0 if b == a else (t - a) / (b - a)
            return tuple(int(round(ca[j] + (cb[j] - ca[j]) * k)) for j in range(3))
    return stops[-1][1]


def dim(c, k):
    return tuple(int(round(c[i] * k + VOID[i] * (1.0 - k))) for i in range(3))


def build():
    img = Image.new("RGB", (N, N), VOID)
    px = img.load()
    rnd = lcg(SEED)
    mid = (N - 1) / 2.0
    # Squashed, because every galaxy in the game is — `RunState.galaxy.squash`
    # foreshortens the disc and the chart draws it that way. A perfectly round
    # icon would be the one picture of this galaxy that is not the game's.
    squash = 0.58
    # Margin. An icon that runs to its own edge has nowhere to sit in a dock or a
    # rounded mask, and the void around a galaxy is half of what a galaxy looks
    # like.
    reach = mid * 0.82

    # Two arms, wound loosely enough to read at 32px. Tighter is prettier at 512
    # and mush in a taskbar, and the taskbar is where an icon actually lives.
    # ABOUT ONE AND A HALF TURNS, and that number is the difference between a
    # spiral and a smudge. The first pass wound three and a half times: at 512 it
    # is a galaxy and at 64 every arm overlaps every other one and the whole thing
    # resolves to a filled ellipse. Fewer turns, tighter scatter, and the arms
    # survive being small — which is the only size that matters here.
    arms, turns = 2, 1.45
    for _ in range(2600):
        arm = int(next(rnd) * arms)
        # Biased inward: t*t puts most of the population in the bright half,
        # which is what makes the core read as a core rather than as a dot.
        t = next(rnd)
        t = t * t
        ang = t * turns * 2.0 * math.pi + arm * (2.0 * math.pi / arms)
        r = t * reach
        # Scatter, wider further out, so the arms fray at the rim instead of
        # ending in two clean lines.
        spread = 0.05 + 0.13 * t
        ang += (next(rnd) - 0.5) * spread * 2.4 * math.pi
        r += (next(rnd) - 0.5) * reach * 0.10

        x = mid + math.cos(ang) * r
        y = mid + math.sin(ang) * r * squash
        xi, yi = int(round(x)), int(round(y))
        if not (0 <= xi < N and 0 <= yi < N):
            continue
        # Brightness falls with radius as well as hue: the rim is not just colder,
        # it is fainter, which is the difference between a cold galaxy and a
        # galaxy with a blue edge painted on.
        k = 0.35 + 0.65 * (1.0 - t) ** 1.4
        if next(rnd) < 0.18:
            k = min(1.0, k * 1.5)
        px[xi, yi] = dim(ramp(t), k)

    # The core, painted rather than accumulated. Enough stars to make a solid
    # centre would take ten thousand draws and still be lumpy.
    for yy in range(N):
        for xx in range(N):
            dx = (xx - mid) / reach
            dy = (yy - mid) / (reach * squash)
            d = math.sqrt(dx * dx + dy * dy)
            if d < 0.21:
                k = 1.0 - (d / 0.21) ** 1.5
                base = ramp(d / 0.21 * 0.30)
                cur = px[xx, yy]
                px[xx, yy] = tuple(
                    min(255, int(round(cur[i] * (1 - k) + base[i] * k)))
                    for i in range(3)
                )

    # A few stars that are not in the galaxy at all, because the void is not
    # empty and a disc floating on flat colour reads as a logo rather than a place.
    for _ in range(70):
        xi = int(next(rnd) * N)
        yi = int(next(rnd) * N)
        if not (0 <= xi < N and 0 <= yi < N):
            continue
        if px[xi, yi] != VOID:
            continue
        px[xi, yi] = dim(ICE, 0.20 + next(rnd) * 0.30)

    return img


def main():
    root = Path(__file__).resolve().parents[2]
    img = build()
    # 256 for the project icon: four whole pixels per authored one, which is what
    # Godot's window and the exporters want, and still integer at 32 and 64.
    img.resize((256, 256), Image.NEAREST).save(root / "icon.png")
    img.resize((512, 512), Image.NEAREST).save(root / "art" / "sprites" / "icon@4x.png")
    print("wrote %s" % (root / "icon.png"))
    print("wrote %s" % (root / "art" / "sprites" / "icon@4x.png"))


if __name__ == "__main__":
    main()
