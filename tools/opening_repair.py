"""Repair the station opening sprites, and recut their holes from the result.

    python tools/opening_repair.py [--dry] [name ...]

FOUR FAULTS, NAMED BY JON, all in the same sprites:

  1. the backdrop bleeds past the frame
  2. there are gaps inside the frame itself
  3. loose fragments sit on the wall beside it
  4. the border is too thin or ragged to read

They are related. A frame with a gap in it lets the view leak out; a 2px
mullion reads as ragged AND is one bad pixel away from being a gap. So the
passes run in order and each one is measured, because "it looks better" is not
something a script can tell you.

WHAT A HOLE IS. An opening's transparent pixels are two different things: the
VIEW, which the frame encloses and the backdrop shows through, and the AIR
round the outside of the frame, where the wall belongs. The two cannot be told
apart by looking at a pixel -- only by asking whether it can reach the edge of
the sprite without crossing the frame. Everything here rests on that test.
"""

import io
import json
import os
import sys
from collections import deque

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))

import pixeltools  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
STATION = os.path.abspath(os.path.join(HERE, "..", "tkg", "art", "sprites", "station"))
HOLES = os.path.join(STATION, "opening_holes.json")

# A frame thinner than this reads as a line rather than as structure. Measured
# against the set: the three openings Jon kept never go below 12px, and `grid`
# spends 81% of its border at 2px.
MIN_BORDER = 6
# An opaque piece smaller than this, not joined to the frame, is debris.
FRAGMENT = 400
# A gap inside the frame smaller than this share of the biggest enclosed region
# is a hole in the art, not a pane of glass.
GAP_SHARE = 0.06
GAP_FLOOR = 400
# Measured across the set: every piece that belongs to its opening sits 3-7px
# off the frame; debris sits 11 or more.
DETACHED = 8
# ...unless it is big enough to be a panel in its own right, like grid's second
# window, which stands 13px clear of the first.
PANEL = 1500
# Below this a piece is a speck, wherever it sits.
SPECK = 200
# Seals a see-through slit up to 2*CRACK pixels wide.
CRACK = 2


def load(path):
    w, h, rows = pixeltools.decode(path)
    return w, h, rows


def alpha(w, h, rows):
    a = bytearray(w * h)
    for y in range(h):
        r = rows[y]
        for x in range(w):
            if r[x * 4 + 3] >= 40:
                a[y * w + x] = 1
    return a


def components(w, h, mask, diagonal=True):
    """Connected runs of set pixels, as lists of indices, biggest first."""
    seen = bytearray(w * h)
    steps = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    if diagonal:
        steps += [(1, 1), (1, -1), (-1, 1), (-1, -1)]
    out = []
    for i in range(w * h):
        if seen[i] or not mask[i]:
            continue
        stack, pts = [i], []
        seen[i] = 1
        while stack:
            c = stack.pop()
            pts.append(c)
            cx, cy = c % w, c // w
            for dx, dy in steps:
                nx, ny = cx + dx, cy + dy
                if 0 <= nx < w and 0 <= ny < h:
                    k = ny * w + nx
                    if not seen[k] and mask[k]:
                        seen[k] = 1
                        stack.append(k)
        out.append(pts)
    out.sort(key=len, reverse=True)
    return out


def outside(w, h, op):
    """Transparent pixels reachable from the sprite's edge: the air, not the view."""
    out = bytearray(w * h)
    q = deque()

    def push(x, y):
        i = y * w + x
        if not op[i] and not out[i]:
            out[i] = 1
            q.append((x, y))

    for x in range(w):
        push(x, 0)
        push(x, h - 1)
    for y in range(h):
        push(0, y)
        push(w - 1, y)
    while q:
        cx, cy = q.pop()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = cx + dx, cy + dy
            if 0 <= nx < w and 0 <= ny < h:
                push(nx, ny)
    return out


def paint(w, h, rows, targets):
    """Give each target pixel the average of its opaque neighbours, ring by ring.

    Ring by ring rather than all at once so a gap in a dark strut takes the
    strut's colour instead of an average of the whole frame.
    """
    todo = set(targets)
    while todo:
        done = []
        for i in sorted(todo):
            x, y = i % w, i // w
            sr = sg = sb = c = 0
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1),
                           (1, 1), (-1, -1), (1, -1), (-1, 1)):
                nx, ny = x + dx, y + dy
                if not (0 <= nx < w and 0 <= ny < h):
                    continue
                if ny * w + nx in todo:
                    continue
                r = rows[ny]
                o = nx * 4
                if r[o + 3] < 40:
                    continue
                sr += r[o]
                sg += r[o + 1]
                sb += r[o + 2]
                c += 1
            if not c:
                continue
            r = rows[y]
            o = x * 4
            r[o], r[o + 1], r[o + 2], r[o + 3] = sr // c, sg // c, sb // c, 255
            done.append(i)
        if not done:
            break
        for i in done:
            todo.discard(i)
    return len(targets) - len(todo)


def near_window(w, h, comps, declared):
    """How many pixels each piece stands clear of the declared window."""
    if len(comps) < 2:
        return {}
    reach = bytearray(w * h)
    seed = []
    for y, x0, ln in declared:
        if not (0 <= y < h):
            continue
        for x in range(max(0, x0), min(w, x0 + ln)):
            i = y * w + x
            if not reach[i]:
                reach[i] = 1
                seed.append(i)
    if not seed:
        return {}
    front, out = seed, {}
    for d in range(1, DETACHED + 4):
        nxt = []
        for c in front:
            cx, cy = c % w, c // w
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < w and 0 <= ny < h:
                        k = ny * w + nx
                        if not reach[k]:
                            reach[k] = 1
                            nxt.append(k)
        front = nxt
        for j, pts in enumerate(comps):
            if j not in out and any(reach[p] for p in pts):
                out[j] = d
        if len(out) == len(comps):
            break
    return out


def clear(rows, w, idx):
    for i in idx:
        rows[i // w][(i % w) * 4 + 3] = 0


def repair(name, declared, dry=False):
    path = os.path.join(STATION, "opening_%s.png" % name)
    w, h, rows = load(path)
    report = {"name": name}

    # 3 -- LOOSE FRAGMENTS. Anything opaque that is not joined to the frame and
    # is small is debris on the wall. The frame is the biggest piece by
    # definition; a real second panel (a double window) is far bigger than this.
    #
    # SIZE ALONE WAS NOT ENOUGH -- `breach` kept two blocks of 848 and 631
    # pixels out on the wall -- and neither was distance from the biggest piece:
    # `breach` is a TORN opening whose frame is a dozen separate plates, so
    # measuring from the largest one deleted the opening itself and left no view
    # at all.
    #
    # The question that actually separates them is what the piece is near. A
    # piece of frame borders the window; debris sits off on the wall with
    # nothing to do with it. So a piece goes if it is small AND stands clear of
    # the window by more than a frame's width.
    op = alpha(w, h, rows)
    comps = components(w, h, op)
    gap = near_window(w, h, comps, declared)
    # ...and anything really small goes whatever it is near. `breach` kept two
    # 60px blocks and `roundbig` two of 48px, floating beside their frames,
    # because they sat within a frame's width of the window and the distance
    # rule spared them. Nothing that small is structure.
    strays = [c for j, c in enumerate(comps, 0)
              if j > 0 and (len(c) < SPECK
                            or (len(c) < PANEL and gap.get(j, 99) >= DETACHED))]
    report["fragments"] = (len(strays), sum(len(c) for c in strays))
    if not dry:
        for c in strays:
            clear(rows, w, c)
        op = alpha(w, h, rows)

    # 2 -- GAPS INSIDE THE FRAME. Of the regions the frame encloses, the big
    # ones are panes and the small ones are holes in the art. "Small" is
    # relative: grid's real panes are 684px and its pin-holes are 4-16px, so a
    # fixed number would be wrong for a differently-scaled sprite.
    out = outside(w, h, op)
    enc = bytearray(w * h)
    for i in range(w * h):
        if not op[i] and not out[i]:
            enc[i] = 1
    regions = components(w, h, enc, diagonal=False)
    biggest = len(regions[0]) if regions else 0
    limit = max(GAP_FLOOR, biggest * GAP_SHARE)
    gaps = [r for r in regions if len(r) < limit]
    report["gaps"] = (len(gaps), sum(len(r) for r in gaps))
    if not dry:
        filled = []
        for r in gaps:
            filled += r
        paint(w, h, rows, filled)
        op = alpha(w, h, rows)
        out = outside(w, h, op)

    # 1a -- SEAL THE FRAME BEFORE ASKING WHAT IT ENCLOSES. `canopy` and
    # `breach` came out of the first pass with NO view at all: their frames have
    # a break in them, so every pixel of their window can walk out to the edge
    # of the sprite and counts as air. The break is what lets the backdrop bleed
    # past the frame in the first place -- the same fault, seen from the other
    # side.
    #
    # So: close the frame (dilate, then erode) at the smallest radius that makes
    # the declared window enclosed, and keep the pixels that closing added. A
    # radius of 1 seals a one-pixel crack; nothing here needs more than a few,
    # and an opening whose window is already enclosed is left alone at radius 0.
    want = bytearray(w * h)
    for y, x0, ln in declared:
        if 0 <= y < h:
            for x in range(max(0, x0), min(w, x0 + ln)):
                want[y * w + x] = 1
    wantn = sum(want)
    sealed_px = 0
    if wantn:
        out = outside(w, h, op)
        leak = sum(1 for i in range(w * h) if want[i] and out[i])
        if leak > wantn * 0.10:
            for rad in range(1, 5):
                grow = bytearray(op)
                for _ in range(rad):
                    nxt = bytearray(grow)
                    for i in range(w * h):
                        if grow[i]:
                            continue
                        x, y = i % w, i // w
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                            nx, ny = x + dx, y + dy
                            if 0 <= nx < w and 0 <= ny < h and grow[ny * w + nx]:
                                nxt[i] = 1
                                break
                    grow = nxt
                for _ in range(rad):
                    nxt = bytearray(grow)
                    for i in range(w * h):
                        if not grow[i]:
                            continue
                        x, y = i % w, i // w
                        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                            nx, ny = x + dx, y + dy
                            if not (0 <= nx < w and 0 <= ny < h) or not grow[ny * w + nx]:
                                nxt[i] = 0
                                break
                    grow = nxt
                for i in range(w * h):
                    if op[i]:
                        grow[i] = 1
                o2 = outside(w, h, grow)
                if sum(1 for i in range(w * h) if want[i] and o2[i]) <= wantn * 0.10:
                    added = [i for i in range(w * h) if grow[i] and not op[i]]
                    if not dry:
                        paint(w, h, rows, added)
                        op = alpha(w, h, rows)
                        out = outside(w, h, op)
                    sealed_px = len(added)
                    break
    report["sealed"] = sealed_px

    # 2b -- CRACKS RIGHT ACROSS THE FRAME. `shutter` had two rows, 220 and 208
    # pixels wide, completely transparent straight through its housing: bare
    # wall showing as a slit across the rolled shade. Every rule so far had
    # missed it, because the slit runs out to the edge of the sprite and so
    # counts as AIR rather than as an enclosed gap.
    #
    # A closing -- dilate then erode -- seals any channel narrower than twice
    # the radius without moving the silhouette, so a 2px radius takes cracks up
    # to 4px and leaves a real gap between two panels alone.
    cracks = 0
    if not dry:
        grow = bytearray(op)
        for _ in range(CRACK):
            nxt = bytearray(grow)
            for i in range(w * h):
                if grow[i]:
                    continue
                x, y = i % w, i // w
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and grow[ny * w + nx]:
                        nxt[i] = 1
                        break
            grow = nxt
        for _ in range(CRACK):
            nxt = bytearray(grow)
            for i in range(w * h):
                if not grow[i]:
                    continue
                x, y = i % w, i // w
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < w and 0 <= ny < h) or not grow[ny * w + nx]:
                        nxt[i] = 0
                        break
            grow = nxt
        # A closing also reaches into the window, which is not a crack. Only
        # take pixels that were AIR: the view is what the frame is there to
        # hold, and filling it in would be the opposite of the repair.
        add = [i for i in range(w * h)
               if grow[i] and not op[i] and out[i]]
        if add:
            paint(w, h, rows, add)
            op = alpha(w, h, rows)
            out = outside(w, h, op)
        cracks = len(add)
    report["cracks"] = cracks

    # 4 -- A BORDER TOO THIN TO READ. Grow the frame inward, into the view,
    # wherever it is thinner than MIN_BORDER. Inward and not outward because the
    # sprite's silhouette against the wall is the shape Jon approved.
    grown = 0
    if not dry:
        for _ in range(MIN_BORDER):
            add = []
            for i in range(w * h):
                if op[i] or out[i]:
                    continue                      # frame, or air outside it
                x, y = i % w, i // w
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < w and 0 <= ny < h):
                        continue
                    if not op[ny * w + nx]:
                        continue
                    # how far the frame runs on from that neighbour
                    d, cx, cy = 0, nx, ny
                    while 0 <= cx < w and 0 <= cy < h and op[cy * w + cx]:
                        d += 1
                        cx += dx
                        cy += dy
                        if d >= MIN_BORDER:
                            break
                    if d < MIN_BORDER:
                        add.append(i)
                        break
            if not add:
                break
            paint(w, h, rows, add)
            grown += len(add)
            op = alpha(w, h, rows)
            out = outside(w, h, op)
    report["thickened"] = grown

    # 1 -- THE VIEW MUST NOT REACH THE WALL. After the repairs, the hole is
    # exactly what the frame encloses. A pixel that can walk out to the sprite's
    # edge is air, and giving the backdrop to it is the bleed Jon saw.
    op = alpha(w, h, rows)
    out = outside(w, h, op)

    # ...AND SEALING A CRACK CAN TRAP A POCKET BEHIND IT. Closing `shutter`'s
    # slit walled off the strip above it, and a walled-off strip is enclosed, so
    # the recut handed it to the backdrop: the housing bar came out with the
    # concourse showing through it. The repair had made a new hole in the act of
    # closing one.
    #
    # The declared window says where the view belongs. Measured: the trapped
    # strip lies 0% inside that box and every real pane of `grid` lies 100%
    # inside it, so half is a wide margin. A pocket is filled, not glazed.
    pockets = 0
    if not dry and declared:
        dx0 = min(r[1] for r in declared)
        dx1 = max(r[1] + r[2] - 1 for r in declared)
        dy0 = min(r[0] for r in declared)
        dy1 = max(r[0] for r in declared)
        enc2 = bytearray(w * h)
        for i in range(w * h):
            if not op[i] and not out[i]:
                enc2[i] = 1
        fill = []
        for reg in components(w, h, enc2, diagonal=False):
            inside = sum(1 for i in reg
                         if dx0 <= i % w <= dx1 and dy0 <= i // w <= dy1)
            if inside * 2 < len(reg):
                fill += reg
        if fill:
            paint(w, h, rows, fill)
            op = alpha(w, h, rows)
            out = outside(w, h, op)
        pockets = len(fill)
    report["pockets"] = pockets

    runs, holepx = [], 0
    for y in range(h):
        x = 0
        while x < w:
            i = y * w + x
            if not op[i] and not out[i]:
                x0 = x
                while x < w and not op[y * w + x] and not out[y * w + x]:
                    x += 1
                runs.append([y, x0, x - x0])
                holepx += x - x0
            else:
                x += 1
    report["hole"] = holepx
    report["runs"] = runs
    if not dry:
        pixeltools.encode(path, w, h, rows)
    return report


def main():
    dry = "--dry" in sys.argv
    names = [a for a in sys.argv[1:] if not a.startswith("--")]
    table = json.load(io.open(HOLES, encoding="utf-8"))
    if not names:
        names = sorted(table)
    print("opening".ljust(13) + "fragments cut   gaps filled   cracks   pockets     sealed   border grown   view px")
    for name in names:
        if name not in table:
            print("  no such opening: " + name)
            continue
        r = repair(name, table[name]["runs"], dry)
        before = sum(x[2] for x in table[name]["runs"])
        print(name.ljust(13)
              + ("%d (%dpx)" % r["fragments"]).rjust(13)
              + ("%d (%dpx)" % r["gaps"]).rjust(14)
              + ("%dpx" % r["cracks"]).rjust(9)
              + ("%dpx" % r["pockets"]).rjust(10)
              + ("%dpx" % r["sealed"]).rjust(11)
              + ("%dpx" % r["thickened"]).rjust(15)
              + ("%d" % r["hole"]).rjust(10)
              + ("  %+d" % (r["hole"] - before)))
        if not dry:
            table[name]["runs"] = r["runs"]
    if not dry:
        json.dump(table, io.open(HOLES, "w", encoding="utf-8"), separators=(",", ":"))
        print("\nrewrote the art and the hole table for %d opening(s)" % len(names))


if __name__ == "__main__":
    main()
