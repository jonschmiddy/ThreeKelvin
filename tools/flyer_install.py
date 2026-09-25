"""Turn a hovering object's frames into a strip the room can draw.

    python tools/flyer_install.py <name> <frame0.png> <frame1.png> ...

Writes `walker_flyer_<name>.png` beside the walkers and adds an entry to
`walker_strips.json` carrying `by_time: true`.

A FLYER IS NOT A WALKER, IN THE TWO WAYS THAT MATTER.

  * ITS FRAMES ARE DRIVEN BY TIME, NOT DISTANCE. Everything about the walkers
    rests on the opposite: a boot stays planted only if the frame advances with
    the body, which is why every strip carries a measured stride. A drone
    touches nothing. Its rotors turn at their own rate whether it is crossing
    the room or sitting still, so asking `walk_stride` for its advance would
    invent a number and then tie the rotors to the travel -- the drone would
    visibly speed up and slow down for no reason. The entry carries `fps`
    instead of `advance`, and the room must play it on a clock.

  * IT MUST NOT BE ANCHORED. `walker_install` slides every frame so the lowest
    ink row lines up, which is what stops a walker bobbing through the deck.
    Doing that here would cancel the animation: for a hovering drone the rise
    and fall IS the content, and anchoring on the bottom row would hold the
    lowest pixel still and delete the hover entirely. So frames are placed in
    one union box exactly where they were drawn.

The union crop and the palette lock are kept -- those are about cropping and
shimmer, and both apply to anything that moves.
"""

import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "tkg", "art", "tools"))

import pixeltools  # noqa: E402
import walker_install as W  # noqa: E402

# How fast a hover loop plays. Not measured from the art, because there is
# nothing in a hovering sprite to measure against -- no contact, no stride.
# Chosen to sit in the same band a walk does, so a drone crossing the room
# reads at the same rhythm as the people under it rather than buzzing.
FLY_FPS = 10.0


def build(name, paths):
    fr = []
    for p in paths:
        w, h, r = pixeltools.decode(p)
        xs = [x for y in range(h) for x in range(w) if r[y][x * 4 + 3] >= W.ALPHA]
        ys = [y for y in range(h) for x in range(w) if r[y][x * 4 + 3] >= W.ALPHA]
        if not xs:
            raise SystemExit("flyer_install: %s is empty" % p)
        fr.append({"w": w, "h": h, "r": r, "x0": min(xs), "x1": max(xs),
                   "y0": min(ys), "y1": max(ys)})

    # ONE BOX, AND EVERY FRAME STAYS WHERE IT WAS DRAWN INSIDE IT.
    x0 = min(f["x0"] for f in fr)
    x1 = max(f["x1"] for f in fr)
    y0 = min(f["y0"] for f in fr)
    y1 = max(f["y1"] for f in fr)
    cw, ch = x1 - x0 + 1, y1 - y0 + 1
    n = len(fr)

    strip = [bytearray(cw * n * 4) for _ in range(ch)]
    for i, f in enumerate(fr):
        for y in range(ch):
            sy = y + y0
            if sy < 0 or sy >= f["h"]:
                continue
            for x in range(cw):
                sx = x + x0
                if sx < 0 or sx >= f["w"]:
                    continue
                o, d = sx * 4, (i * cw + x) * 4
                if f["r"][sy][o + 3] < W.ALPHA:
                    continue
                strip[y][d:d + 4] = f["r"][sy][o:o + 4]

    was, now = W.lock_palette(strip, cw, ch, n)

    out = os.path.join(W.STATION, "walker_flyer_%s.png" % name)
    pixeltools.encode(out, cw * n, ch, strip)

    # How far the sprite moves inside its own box across the loop. For a hover
    # this is the whole point -- a flyer that measures zero has no motion in it
    # and the generator has drawn the same frame twelve times.
    lows = [f["y1"] for f in fr]
    bob = max(lows) - min(lows)

    return out, {"file": "walker_flyer_%s.png" % name, "frames": n,
                 "frame_w": cw, "frame_h": ch,
                 "colours": now, "colours_before": was,
                 "by_time": True, "fps": FLY_FPS, "bob_px": bob,
                 "advance": None, "cycle": None}


def main():
    if len(sys.argv) < 3:
        raise SystemExit(__doc__.strip().splitlines()[2].strip())
    name, paths = sys.argv[1], sys.argv[2:]
    out, meta = build(name, paths)
    idx = {}
    if os.path.exists(W.INDEX):
        idx = json.load(io.open(W.INDEX, encoding="utf-8"))
    idx["flyer_" + name] = meta
    io.open(W.INDEX, "w", encoding="utf-8", newline="\n").write(
        json.dumps(idx, indent=1, sort_keys=True))
    print("flyer %s: %d frames of %dx%d, plays on a clock at %.0f fps, "
          "bobs %dpx" % (name, meta["frames"], meta["frame_w"],
                         meta["frame_h"], meta["fps"], meta["bob_px"]))
    print("  palette locked: %d colours -> %d" % (was_now(meta)))
    print("  %s" % out)
    if meta["bob_px"] == 0:
        print("  NOTHING MOVES VERTICALLY -- check it is not twelve copies of "
              "one frame")


def was_now(m):
    return (m["colours_before"], m["colours"])


if __name__ == "__main__":
    main()
