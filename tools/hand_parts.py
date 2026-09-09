# -*- coding: utf-8 -*-
"""The two modules the generator never drew, authored in code instead.

    python tools/hand_parts.py [outdir]

WHY THESE TWO AND NOT THE OTHER FORTY-ONE. `module_batch.py` records the finding
that flat rectangular panels do not work at 40x20: four of them were cut twice,
in two different framings, because at that size the rectangle IS the silhouette
and the only thing telling two panels apart is face detail, which is the first
thing to go at 2x. It also records the way out -- "the plate that DOES work in
the game was drawn by hand". `plating` took a dozen-plus cuts before anyone took
that seriously.

READING THE FLAVOUR CHANGED WHAT THESE ARE. Only ONE of the two is a panel:

    plating  "Hull Plating"           -- Steel, bolted on. It does not have to
                                         be clever.
    plate    "Ablative Plate Welder"  -- Armor that persists, heat that lingers.

`plate` is a WELDER. It was cut a dozen times as a flat sheet because its id
says plate and nobody read past the id to the name. A welder is a machine with a
head, a feed and an arc -- exactly the kind of subject that has always worked
here, and exactly the kind of silhouette the hold needs.

WHAT MAKES A PANEL READ WHEN IT CANNOT HAVE A SILHOUETTE. `plating` really is a
rectangle and its flavour is not apologising for that, so the answer is not to
invent a shape it does not have. It is to break the outline in the two places a
bolted-on plate is genuinely broken: the LAP, where one slab oversails the next
and the edge steps, and the DAMAGE, where a corner has been taken off. Bolt rows
along the lap then give the interior a rhythm at 2x, which is the job the comb of
fins does for `sinkplate` and the trace does for `board`.

SLOT REDUNDANCY. These are the last two 2x1s and they have to avoid the eleven
already drawn: `blowout` owns panel bays in a frame, `board` a bordered board
with a gold trace, `sinkplate` a comb of fins, `bracing` an X, `standfast` a rail
frame, `coolant` a pipe with a valve. A stepped lap with bolt rows collides with
none of them; a welding head on a rail collides with none of them either.

COLOURS ARE TAKEN FROM THE MODULE PALETTE, so nothing here can drift off the ramp
the other forty-one landed on. Every accepted module is a dark body with ONE hot
point, and both of these keep to it -- the scorch on the plating, the arc on the
welder.
"""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools as pt  # noqa: E402

# The ramp, darkest to lightest, lifted out of the module palette by hand so the
# names below say what each tone is FOR rather than what it measures.
EDGE = (0x1f, 0x1a, 0x28)
DEEP = (0x25, 0x30, 0x43)
BODY = (0x2c, 0x38, 0x4a)
FACE = (0x37, 0x41, 0x50)
LIFT = (0x44, 0x50, 0x61)
RIM = (0x5c, 0x6b, 0x7e)
LIT = (0x73, 0x8b, 0x91)
WHITE = (0xca, 0xcc, 0xd1)
SCORCH = (0x4c, 0x16, 0x13)
RUST = (0x93, 0x3c, 0x01)
EMBER = (0xd8, 0x6a, 0x03)
HOT = (0xd4, 0xae, 0x08)


def blank(w, h):
    return [bytearray(w * 4) for _ in range(h)]


def px(r, x, y, c, w, h):
    if 0 <= x < w and 0 <= y < h:
        o = x * 4
        r[y][o], r[y][o + 1], r[y][o + 2], r[y][o + 3] = c[0], c[1], c[2], 255


def clear(r, x, y, w, h):
    if 0 <= x < w and 0 <= y < h:
        r[y][x * 4 + 3] = 0


def rect(r, x0, y0, x1, y1, c, w, h):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            px(r, x, y, c, w, h)


def limb(r, x0, y0, x1, y1, thick, c, w, h):
    """A straight arm of a given thickness, drawn by stepping the long axis.

    Bresenham with a brush rather than a pen. `expand_box.py` refuses to grow a
    diagonal because a diagonal's footprint moves; the same fact is why a diagonal
    is worth DRAWING here -- it is the one silhouette in the 2x1 slot that a
    rectangle cannot fake.
    """
    dx, dy = x1 - x0, y1 - y0
    n = max(abs(dx), abs(dy))
    if n == 0:
        n = 1
    for i in range(n + 1):
        cx = x0 + int(round(dx * i / float(n)))
        cy = y0 + int(round(dy * i / float(n)))
        for oy in range(thick):
            for ox in range(thick):
                px(r, cx + ox - thick // 2, cy + oy - thick // 2, c, w, h)


def plating(w=40, h=20):
    """Two armour slabs lapped over one another, bolted, one corner shot off.

    The step at x=17 is the whole idea. It puts a notch in the outline that a
    single rectangle cannot have, and it reads at 2x as one plate oversailing
    another rather than as a bevel. The lower slab sits proud at the bottom and
    the upper slab proud at the top, so the silhouette kinks at BOTH ends of the
    seam and not just one -- one kink reads as a chipped corner, two read as a
    lap, and the lap is the thing that makes it a plate rather than a box.
    """
    r = blank(w, h)
    # The two slabs are deliberately two steps apart on the ramp, not one. The
    # first pass put them at BODY and FACE, which are close enough that at 2x the
    # lap vanished and the whole thing went back to being one rectangle -- the
    # exact failure this part has been cut for a dozen times.
    rect(r, 0, 4, 20, 19, DEEP, w, h)          # lower slab, running off the left
    rect(r, 0, 4, 20, 4, LIT, w, h)            # its lit top edge
    rect(r, 0, 19, 20, 19, EDGE, w, h)         # its grounded bottom edge
    rect(r, 17, 1, 39, 16, LIFT, w, h)         # upper slab, oversailing, lighter
    rect(r, 17, 1, 39, 1, LIT, w, h)
    rect(r, 17, 16, 39, 16, EDGE, w, h)
    rect(r, 17, 1, 17, 16, EDGE, w, h)         # the lap: a hard dark seam
    rect(r, 18, 2, 18, 15, WHITE, w, h)        # with a bright lip on the near side

    # Bolt rows, period 5 -- coarse enough to survive the 2x draw, which is where
    # the last four panels lost their faces. Two tones each, so a bolt reads as a
    # dome rather than a dot.
    for x in range(3, 16, 5):
        px(r, x, 8, LIT, w, h)
        px(r, x, 9, EDGE, w, h)
        px(r, x, 15, LIT, w, h)
        px(r, x, 16, EDGE, w, h)
    for x in range(21, 39, 5):
        px(r, x, 4, WHITE, w, h)
        px(r, x, 5, DEEP, w, h)
        px(r, x, 12, WHITE, w, h)
        px(r, x, 13, DEEP, w, h)

    for x in range(2, 20, 2):                  # weld bead along the lower slab
        px(r, x, 6, RIM, w, h)

    # The corner that is gone. It was drawn with a scorch and a rust bloom around
    # it, and it read as "a weird red thing in the corner" rather than as damage --
    # a four-by-three block of dark red on an otherwise cold sprite is a stain,
    # not a story. The cut alone does the silhouette work; what the burn was for
    # was the hot point, and that moves to the paint mark below.
    for i in range(5):
        for x in range(39 - i, 40):
            clear(r, x, 1 + i, w, h)
    for i in range(5):                         # bright torn edge along the cut
        px(r, 39 - i, 2 + i, WHITE, w, h)

    px(r, 3, 17, RIM, w, h)                    # stencilled thickness mark
    px(r, 5, 17, RIM, w, h)
    px(r, 6, 17, RIM, w, h)
    px(r, 8, 17, HOT, w, h)                    # and the paint dab beside it, which
    px(r, 9, 17, RUST, w, h)                   # is now the whole of the hot point
    return w, h, r


def plate(w=40, h=20):
    """A welding arm reaching down to a strip of plate stock, arc lit.

    THE THIRD SUBJECT FOR THIS ID, and the first that is not a box. Cut as a flat
    sheet a dozen times, then drawn as a head on an overhead rail -- which was
    rejected, and rightly: a rail across the top and a stack along the bottom is
    two horizontal bars with a lump between them, which is a box with a bite out
    of it however the lump is detailed. Every other part in the 2x1 slot is built
    out of horizontals too, so it had nothing of its own.

    An ARM is the answer. It is the one silhouette here that a rectangle cannot
    fake: a squat base at the left, a shoulder, an upper arm raked up and right, an
    elbow, a forearm coming back down, and a torch at the end of it with the arc
    under the tip. The outline steps diagonally across the cell and the eye reads a
    machine leaning over its work, at 2x, with no interior detail needed at all.
    """
    r = blank(w, h)
    # Plate stock, running off the right, thin so the arm keeps the mass.
    rect(r, 11, 17, 39, 19, BODY, w, h)
    rect(r, 11, 17, 39, 17, LIT, w, h)
    rect(r, 11, 19, 39, 19, EDGE, w, h)
    for x in range(14, 39, 6):
        px(r, x, 18, DEEP, w, h)               # seams between blanks

    # Base and shoulder tower.
    rect(r, 1, 13, 10, 19, BODY, w, h)
    rect(r, 1, 13, 10, 13, LIFT, w, h)
    rect(r, 0, 19, 11, 19, EDGE, w, h)
    rect(r, 3, 9, 8, 13, FACE, w, h)
    rect(r, 3, 9, 8, 9, RIM, w, h)
    px(r, 2, 16, EDGE, w, h)
    px(r, 9, 16, EDGE, w, h)

    # Upper arm, raked up and to the right, then the forearm coming back down.
    limb(r, 6, 10, 19, 3, 3, FACE, w, h)
    limb(r, 6, 10, 19, 3, 1, LIT, w, h)        # lit top face of the arm
    limb(r, 19, 3, 28, 12, 3, LIFT, w, h)
    limb(r, 19, 3, 28, 12, 1, RIM, w, h)
    rect(r, 17, 1, 21, 5, BODY, w, h)          # the elbow, a solid knuckle
    rect(r, 18, 2, 20, 4, RIM, w, h)
    px(r, 19, 3, EDGE, w, h)                   # its pin
    rect(r, 5, 9, 7, 11, RIM, w, h)            # the shoulder pin
    px(r, 6, 10, EDGE, w, h)

    # Torch at the end of the forearm, angled at the plate.
    rect(r, 27, 11, 30, 13, BODY, w, h)
    rect(r, 27, 11, 30, 11, RIM, w, h)
    rect(r, 28, 14, 29, 15, LIFT, w, h)
    px(r, 28, 16, HOT, w, h)                   # the arc
    px(r, 29, 16, EMBER, w, h)
    px(r, 27, 16, EMBER, w, h)
    px(r, 30, 17, RUST, w, h)
    px(r, 26, 17, RUST, w, h)
    rect(r, 25, 17, 32, 17, LIT, w, h)         # the bead it has just laid
    px(r, 28, 17, HOT, w, h)

    # The feed line, slung from shoulder to elbow the way a real one sags.
    px(r, 8, 12, DEEP, w, h)
    px(r, 11, 13, DEEP, w, h)
    px(r, 14, 13, DEEP, w, h)
    px(r, 17, 11, DEEP, w, h)
    px(r, 19, 8, DEEP, w, h)
    return w, h, r


PARTS = {"plating": plating, "plate": plate}


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join("tools", "out", "hand")
    if not os.path.isdir(out):
        os.makedirs(out)
    for name, fn in sorted(PARTS.items()):
        w, h, rows = fn()
        w, h, rows = pt.trim(w, h, rows)
        w, h, rows, over = pt.fit(w, h, rows, 40, 20)
        pt.encode(os.path.join(out, name + ".png"), w, h, rows)
        print("  %-9s %dx%d%s" % (name, w, h, "  OVERFLOW" if any(over) else ""))


if __name__ == "__main__":
    main()
