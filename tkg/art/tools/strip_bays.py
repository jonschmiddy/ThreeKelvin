"""Take the fittings OUT of a hull sprite, leaving the chassis.

The medium was drawn as a finished ship: amber cargo panels, slotted vent boxes,
a lit sensor strip, portholes. Measured, those sit on a grid — three rows at
y~5, y~36 and y~64, with columns repeating at x 74, 94 and 109 in both the
dorsal and ventral rows. They are not surface detail. They are things dropped
into BAYS.

Which means the hull can be a chassis and the fittings can be drawn per module,
by class and by loadout. This removes them so that becomes possible.

WHAT STAYS: the silhouette, the panel seams (they are the grid), the banded
lighting, the nose cone and the stern nozzles. What goes is only what sits IN a
bay.

Fill colour is sampled from the plating immediately outside each bay rather than
picked, so a bay in the lit dorsal band fills light and one in the shadowed
ventral band fills dark, with nobody having to write the ramp down twice.

    python art/tools/strip_bays.py in.png out.png
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixeltools as pt

# Measured off hull_medium_cold.png, not guessed. The five large regions the
# scan also found — the stern shoulder, the nose shoulder, the two lower
# skirts and the small nose plate — are NOT here: they are plating, not bays.
BAYS = [
    # dorsal row
    (63, 5, 72, 21),       # amber, outboard
    (74, 7, 92, 19),       # amber
    (94, 5, 105, 19),      # vent box
    (109, 5, 129, 19),     # long box
    # middle row
    (46, 38, 57, 50),      # dark inset, outboard
    (63, 35, 72, 50),      # amber, outboard
    (70, 26, 93, 34),      # amber strip, upper
    (74, 36, 90, 49),      # amber
    (93, 36, 133, 51),     # the lit strip and its recess
    (70, 57, 86, 63),      # amber strip, lower
    # ventral row
    (48, 64, 56, 78),      # amber, outboard
    (57, 65, 72, 77),      # amber
    (74, 64, 92, 77),      # amber
    (94, 65, 105, 77),     # vent box
    (109, 65, 129, 77),    # long box
]

DARK = {(0x1a, 0x1e, 0x26), (0x13, 0x1a, 0x23), (0x10, 0x16, 0x1f), (0x1e, 0x27, 0x32)}


def rgb(rows, x, y):
    o = x * 4
    return (rows[y][o], rows[y][o + 1], rows[y][o + 2])


def solid(rows, w, h, x, y):
    return 0 <= x < w and 0 <= y < h and rows[y][x * 4 + 3] > 0


def in_a_bay(x, y):
    for (a, b, c, d) in BAYS:
        if a <= x <= c and b <= y <= d:
            return True
    return False


def is_plating(c):
    """Steel, not livery and not a highlight.

    The bays sit shoulder to shoulder, so probing outward hits the NEXT BAY as
    often as it hits plating — the first cut of this filled a vent box with the
    amber of the cargo panel beside it. Two rules fix it: never sample inside
    another bay, and only accept a COLD colour, because the plating ramp is
    steel-blue and everything warm on this hull is livery."""
    r, g, b = c
    if c in DARK:
        return False
    if r > b:               # amber, and anything else warm
        return False
    if r > 200 and g > 200:  # #cfe8f5 and friends: a lit edge, not a surface
        return False
    return True


def clone_source(rows, w, h, bw, bh, y0, y1):
    """A patch of REAL PLATING the size of this bay, taken from the same band.

    The first version filled each bay with one flat colour and it looked like
    somebody had painted grey rectangles onto a ship. Plating on this hull is not
    flat: it carries rivet dots, a lit lip along the top of each panel and a
    shadowed one beneath. A single colour has none of that, so every cleared bay
    read as a hole in the artwork rather than as bare hull.

    Copying actual pixels gets all of it for free, and from the SAME BAND so the
    lighting still runs light at the top of the ship and dark at the bottom.

    TILED, not stamped once. Four of the fifteen bays are larger than any clear
    patch on the ship — which stands to reason, since the bays ARE most of the
    ship — so a source is found at whatever size the hull can offer and then
    repeated across the bay. Plating is a regular texture of rivets and panel
    lines, so it tiles without anybody noticing the join.
    """
    # Shrink the ask until the hull can answer it.
    for shrink in range(0, 14):
        got = _find(rows, w, h, max(4, bw - shrink * 3), max(4, bh - shrink * 2),
                    y0, y1)
        if got is not None:
            return got
    return None


def _find(rows, w, h, bw, bh, y0, y1):
    best = None
    best_score = -1
    for sy in range(max(0, y0 - 8), max(1, min(h - bh, y1 + 9))):
        for sx in range(max(1, w - bw)):
            score = 0
            ok = True
            for dy in range(bh):
                for dx in range(bw):
                    x, y = sx + dx, sy + dy
                    if not solid(rows, w, h, x, y) or in_a_bay(x, y):
                        ok = False
                        break
                    c = rgb(rows, x, y)
                    # seams and rivets are WANTED - they are the texture. Only
                    # livery and lit edges disqualify a source.
                    if c[0] > c[2] + 8 or (c[0] > 200 and c[1] > 200):
                        ok = False
                        break
                    if c not in DARK:
                        score += 1
                if not ok:
                    break
            if ok and score > best_score:
                best_score = score
                best = (sx, sy, bw, bh)
    return best


def strip(src, dst):
    w, h, rows = pt.decode(src)
    out = [bytearray(r) for r in rows]
    filled = 0
    for (bx0, by0, bx1, by1) in BAYS:
        # GROWN BY ONE. A bay's contents include its own border — the amber
        # panels carry a dark surround, and clearing only the face left 475px of
        # fringe outlining a hole. The seams BETWEEN bays are two pixels of dark
        # and survive losing one.
        x0, y0, x1, y1 = bx0 - 1, by0 - 1, bx1 + 1, by1 + 1
        bw_, bh_ = x1 - x0 + 1, y1 - y0 + 1
        src = clone_source(rows, w, h, bw_, bh_, y0, y1)
        if src is None:
            print('  bay x %3d..%-3d y %2d..%-2d  no clear plating anywhere'
                  % (x0, x1, y0, y1))
            continue
        sx, sy, sw, sh = src
        for dy in range(bh_):
            for dx in range(bw_):
                x, y = x0 + dx, y0 + dy
                if not solid(rows, w, h, x, y):
                    continue
                out[y][x * 4:x * 4 + 3] = bytes(rgb(rows, sx + dx % sw, sy + dy % sh))
                filled += 1
        print('  bay x %3d..%-3d y %2d..%-2d  cloned %dx%d from %d,%d'
              % (x0, x1, y0, y1, sw, sh, sx, sy))
    pt.encode(dst, w, h, out)
    print('\nemptied %d bays, %d px' % (len(BAYS), filled))
    return w, h, out


if __name__ == '__main__':
    a = sys.argv[1] if len(sys.argv) > 1 else 'art/sprites/hull_medium_cold.png'
    b = sys.argv[2] if len(sys.argv) > 2 else 'art/sprites/hull_medium_chassis.png'
    strip(a, b)
