"""Turn a PixelLab walk cycle into a strip the room can draw.

    python tools/walker_install.py <name> <frame0.png> <frame1.png> ...

Writes `tkg/art/sprites/station/walker_<name>.png` (one horizontal strip) and
adds an entry to `walker_strips.json` carrying everything the room needs:
frame size, frame count, and the measured stride.

THREE THINGS THIS DOES THAT DOING IT BY HAND GOT WRONG:

  * ONE CROP BOX FOR EVERY FRAME. Arms and legs swing, so a walk's own frame
    bounding boxes run 28-51px wide. Cropping each frame to its own ink looks
    tidier and destroys the animation -- the body slides sideways by the
    difference every frame. The union is the only box that holds still.

  * ANCHORED ON THE FEET. The room places a walker by where it stands, so the
    contact point must be the same pixel in every frame or the whole person
    bobs through the deck. Anchored, the head rises and falls instead, which is
    what a walk does. PixelLab's raw frames drift 2px.

  * THE STRIDE TRAVELS WITH THE ART. How far a cycle carries the body is a fact
    about the sprite -- not about its frame count, its height, or the template
    it came from. `walk_stride.py` measures it and it is written into the JSON,
    so nothing downstream has to pick a number. Picking one is what made the
    first walkers skate.

PixelLab returns each frame on its own padded canvas (ask for 80px, get 112),
so the padding is stripped here rather than anywhere later.
"""

import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
STATION = os.path.abspath(os.path.join(HERE, "..", "tkg", "art", "sprites",
                                       "station"))
INDEX = os.path.join(STATION, "walker_strips.json")

sys.path.insert(0, os.path.join(HERE, "..", "tkg", "art", "tools"))
import pixeltools  # noqa: E402

sys.path.insert(0, HERE)
from walk_stride import stride  # noqa: E402

ALPHA = 40
# The pace the station walks at, and the one every frame-rate figure here is
# quoted against. A walker's animation speed follows from its stride, so this
# is the only number that turns a stride into frames a second.
#
# DROPPED FROM 30 TO 20, AND THAT IS WHAT BUYS THE FRAME COUNT. Frames advance
# by distance, so frames a second is pace x frames / cycle: at 30 a ~55px cycle
# could not carry more than 8-10 frames without crossing into the jitter band,
# which is why every walker so far had to be halved down to five or six. At 20
# the same cycle carries 13-15. Nothing is regenerated to get that -- the art
# was always capable of it and the speed was the constraint. It also reads
# better: these are people crossing a concourse in the middle distance, not
# marching.
WALK_PACE = 40


def lock_palette(strip, cw, ch, n, keep=20):
    """One palette for the whole strip, so a pixel is painted the same in every
    frame.

    THE SHIMMER IS PAINT, NOT SHAPE. Measured on a skeleton-posed cycle, the
    silhouette agrees 89% between consecutive frames while the exact colour
    agrees 47% -- the generator draws the same man in slightly different
    shades each time, and at eight frames a second that reads as a figure
    boiling. Sixty-seven colours across a strip that uses about forty in any
    one frame.

    Collapsing them to one palette costs nothing and no generations: take the
    commonest colours across the WHOLE strip and snap every pixel to the
    nearest. Frame-to-frame drift within a snap radius disappears entirely,
    because both frames land on the same entry.
    """
    count = {}
    for y in range(ch):
        for x in range(cw * n):
            o = x * 4
            if strip[y][o + 3] < 40:
                continue
            c = (strip[y][o], strip[y][o + 1], strip[y][o + 2])
            count[c] = count.get(c, 0) + 1
    if len(count) <= keep:
        return len(count), len(count)
    pal = [c for c, _ in sorted(count.items(), key=lambda kv: -kv[1])[:keep]]
    cache = {}

    def near(c):
        if c in cache:
            return cache[c]
        best, bd = pal[0], 1 << 30
        for q in pal:
            d = ((c[0]-q[0]) * (c[0]-q[0]) * 3 + (c[1]-q[1]) * (c[1]-q[1]) * 4
                 + (c[2]-q[2]) * (c[2]-q[2]) * 2)      # eye-weighted
            if d < bd:
                bd, best = d, q
        cache[c] = best
        return best

    for y in range(ch):
        for x in range(cw * n):
            o = x * 4
            if strip[y][o + 3] < 40:
                continue
            q = near((strip[y][o], strip[y][o + 1], strip[y][o + 2]))
            strip[y][o], strip[y][o + 1], strip[y][o + 2] = q
    return len(count), len(pal)


def deck_contacts(strip, fw, h, n):
    """-> how many separate things touch the deck, per frame.

    The same bottom-three-rows test `foot_report` uses, asked of the strip
    still in memory so `build` can warn before it returns rather than after
    something downstream has already trusted the result.
    """
    out = []
    for i in range(n):
        on = [False] * fw
        for y in range(h - 3, h):
            for x in range(fw):
                if strip[y][(i * fw + x) * 4 + 3] >= ALPHA:
                    on[x] = True
        blobs, run = 0, False
        for x in range(fw):
            if on[x] and not run:
                blobs, run = blobs + 1, True
            elif not on[x]:
                run = False
        out.append(blobs)
    return out


def foot_report(path, fw, adv):
    """Which frames have a planted boot that does not stay planted.

    Jon spotted this by eye before any measurement did: "the back foot kinda
    wiggles right before it lifts up." A planted boot slides back through the
    sprite by exactly one stride each frame -- anything else is the generator
    redrawing the foot somewhere it has no business being, and it reads as a
    twitch however good the stride is.

    Frames where the weight changes feet are excluded: the rear edge jumps a
    long way there for an honest reason.
    """
    w, h, r = pixeltools.decode(path)
    n = w // fw
    rear = []
    for i in range(n):
        on = [False] * fw
        for y in range(h - 3, h):
            for x in range(fw):
                if r[y][(i * fw + x) * 4 + 3] >= ALPHA:
                    on[x] = True
        xs = [x for x in range(fw) if on[x]]
        # How many separate things are touching the deck. More than two is
        # never a person.
        blobs, run = 0, False
        for x in range(fw):
            if on[x] and not run:
                blobs += 1
                run = True
            elif not on[x]:
                run = False
        rear.append((min(xs) if xs else None, blobs))
    bad, errs = [], []
    for i in range(n):
        a = rear[i - 1][0]
        b = rear[i][0]
        if a is None or b is None:
            continue
        moved = a - b
        # THE WEIGHT CHANGING FEET IS EXCLUDED ON SIGN, NOT ON A MULTIPLE OF
        # THE ADVANCE.
        #
        # A planted boot travels BACKWARD through the sprite, so `moved` is
        # positive; when the other foot takes the weight the rear edge jumps
        # forward and `moved` goes negative. That is honest and must not count.
        #
        # The old test was `moved < -adv * 2`, which scales with the stride --
        # so on a big-strided cycle it swallowed real errors and on a small one
        # it did not, and the same walker scored differently for a reason that
        # had nothing to do with its feet. It made dock_walk, the cycle Jon
        # approved, look WORSE than the ones he rejected.
        if moved < 0:
            continue
        errs.append(abs(moved - adv))
        if abs(moved - adv) > adv * 0.6:
            bad.append((i, moved, rear[i][1]))
    # How far the planted boot misses its own stride by, as a share of that
    # stride. This is the number that tracks what Jon sees:
    #     dock_walk  9%  approved      cargo 28%  "the foot slips"
    #     traveller 18%  no complaint  guard 62%  "the foot slips"
    #     hauler    20%  no complaint  elder 73%  "glitching out"
    # The line is about 25%.
    skate = (sum(errs) / len(errs) / adv) if errs and adv else 0.0
    return n, bad, [b for _, b in rear], skate


def build(name, paths):
    fr = []
    for p in paths:
        w, h, r = pixeltools.decode(p)
        xs = [x for y in range(h) for x in range(w) if r[y][x * 4 + 3] >= ALPHA]
        ys = [y for y in range(h) for x in range(w) if r[y][x * 4 + 3] >= ALPHA]
        if not xs:
            raise SystemExit("walker_install: %s is empty" % p)
        fr.append({"w": w, "h": h, "r": r, "x0": min(xs), "x1": max(xs),
                   "y0": min(ys), "y1": max(ys)})

    x0 = min(f["x0"] for f in fr)
    x1 = max(f["x1"] for f in fr)
    bot = max(f["y1"] for f in fr)
    top = min(f["y0"] - (bot - f["y1"]) for f in fr)
    cw, ch = x1 - x0 + 1, bot - top + 1
    n = len(fr)

    strip = [bytearray(cw * n * 4) for _ in range(ch)]
    for i, f in enumerate(fr):
        dy = bot - f["y1"]                    # slide so the feet line up
        for y in range(ch):
            sy = y - dy + top
            if sy < 0 or sy >= f["h"]:
                continue
            src = f["r"][sy]
            for x in range(cw):
                sx = x0 + x
                if sx < 0 or sx >= f["w"] or src[sx * 4 + 3] < 8:
                    continue
                o = (i * cw + x) * 4
                for c in range(4):
                    strip[y][o + c] = src[sx * 4 + c]

    was, now = lock_palette(strip, cw, ch, n)
    out = os.path.join(STATION, "walker_%s.png" % name)
    pixeltools.encode(out, cw * n, ch, strip)

    # THE FEET MUST BE LEVEL, and saying so is cheaper than finding out later.
    feet = []
    for i in range(n):
        low = -1
        for y in range(ch):
            for x in range(cw):
                if strip[y][(i * cw + x) * 4 + 3] >= ALPHA:
                    low = y
        feet.append(low)
    if max(feet) - min(feet) != 0:
        raise SystemExit("walker_install: feet are not level after anchoring "
                         "(%s) -- the crop is wrong" % feet)

    # A THIRD THING ON THE DECK MEANS THE ANCHOR IS NOT ON A BOOT.
    #
    # Every frame is registered by its lowest ink row, which is what holds the
    # boots on the floor. A prop that reaches the ground -- a walking stick, a
    # trolley, a dragged crate -- becomes that lowest row in some frames and
    # not others, so the whole body is re-registered to the prop and shifts
    # underneath it. Jon saw it as "the walking stick is glitching out"; it is
    # really the man moving, not the stick.
    #
    # Two boots are normal and one is normal. Three is the signature, and it
    # costs nothing to say so here rather than after the page is published.
    contacts = deck_contacts(strip, cw, ch, n)
    if max(contacts) > 2:
        meta_warn = ("%d frames put more than two things on the deck (%s) -- "
                     "something other than a boot is touching the floor, and "
                     "the body is anchored to it"
                     % (sum(1 for c in contacts if c > 2), contacts))
    else:
        meta_warn = None

    s = stride(out, cw)
    return out, {"file": "walker_%s.png" % name, "frames": n,
                 "colours": now, "colours_before": was,
                 "frame_w": cw, "frame_h": ch,
                 "advance": s["advance_px"], "cycle": s["cycle_px"],
                 # How well one advance explained every frame, and the band of
                 # advances that explained them nearly as well. Both were
                 # measured all along and thrown away here, so nothing
                 # downstream could tell a pinned-down stride from a guess.
                 "fit": s["fit"], "within_3pct": s["within_3pct"],
                 "feet_level": True, "deck_contacts": max(contacts),
                 "warn": meta_warn}


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__.strip().splitlines()[2].strip())
    name, paths = sys.argv[1], sys.argv[2:]
    out, meta = build(name, paths)
    idx = {}
    if os.path.exists(INDEX):
        idx = json.load(io.open(INDEX, encoding="utf-8"))
    print("walker %s: %d frames of %dx%d, feet level, strides %.1fpx "
          "(%.2f/frame)" % (name, meta["frames"], meta["frame_w"],
                            meta["frame_h"], meta["cycle"], meta["advance"]))
    print("  %s" % out)
    print("  palette locked: %d colours -> %d, shared by every frame"
          % (meta["colours_before"], meta["colours"]))
    n, bad, blobs, skate = foot_report(out, meta["frame_w"],
                                       meta["advance"])
    if bad:
        print("  PLANTED FOOT WANDERS in %d of %d frames:" % (len(bad), n))
        for i, moved, nb in bad:
            print("    frame %-2d moved %+5.1fpx where %.2f was due%s"
                  % (i, moved, meta["advance"],
                     ", %d things on the deck" % nb if nb > 2 else ""))
    else:
        print("  planted foot holds in every frame")
    # STORED AFTER THE CHECK RUNS, not before it. The index used to be written
    # at the top of this function, so `foot_wander` was set afterwards on a
    # dict nobody saved: the check ran, printed, and left no trace in the file.
    # Every comparison I drew off that JSON was quietly reading a default.
    meta["foot_wander"] = len(bad)
    meta["skate"] = round(skate, 3)
    print("  planted boot misses its stride by %.0f%% (under 25%% reads clean)"
          % (100 * skate))
    # A GAIT IS JON'S CALL, NOT A MEASUREMENT, so a reinstall keeps it. It
    # scales this one walker's pace: the elder at 0.5 because at the room's
    # pace his 3.5px step played 11 frames a second -- "walks a little too
    # fast". Absent means 1.
    if "gait" in idx.get(name, {}):
        meta["gait"] = idx[name]["gait"]
    # So is a stride Jon set by eye in the stride editor: the elder's measured
    # 3.5 was half the truth, and he set 4.75 on the 12-frame cycle.
    if idx.get(name, {}).get("advance_by_eye"):
        meta["advance"] = idx[name]["advance"]
        meta["advance_by_eye"] = True
    idx[name] = meta
    io.open(INDEX, "w", encoding="utf-8", newline="\n").write(
        json.dumps(idx, indent=1, sort_keys=True))
    ratio = meta["cycle"] / float(meta["frame_h"])
    print("  stride is %.2f x its height (a person's is about 0.75)" % ratio)

    # WHAT BAND DOES IT PLAY IN. The frame is driven by distance, so a small
    # stride means a fast animation for the same walking pace -- and that, not
    # the number of faulty frames, decides whether the eye reads footsteps or
    # a shimmer.
    #
    # Jon saw it before any measurement did: the 8-frame cycle looked clean and
    # the 12-frame jittered, although the 12 had FEWER faulty frames (3 of 12
    # against 4 of 8). The errors are the same size in both -- 73% and 79% of
    # the stride. What differs is that the 12 delivered them at 6.3 a second
    # against 3.3. Below about four a second the eye separates them into
    # events; above about five they fuse, and fused is what jitter means.
    #
    # Halving the 12-frame cycle -- every other frame, no new art -- doubled
    # its stride and dropped it to 3.4 a second. Same drawing, no longer
    # jittering.
    for pace in (WALK_PACE,):
        fps = pace / meta["advance"]
        band = ("steps" if fps < 4.0 else
                "JITTER BAND -- halve the cycle" if fps > 5.0 else "borderline")
        print("  at %d px/s it plays %.1f frames a second: %s"
              % (pace, fps, band))
    meta["fps"] = round(WALK_PACE / meta["advance"], 2)
    meta["pace"] = WALK_PACE


if __name__ == "__main__":
    main()
