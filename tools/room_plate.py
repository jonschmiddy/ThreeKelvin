"""Station room plates: screenshot in, installed plate out.

WHY THIS EXISTS. A room plate is the one texture in the game that is STRETCHED
to its panel rather than blitted at 1:1, so it has to be authored at exactly the
panel's size -- and the panel size is written down nowhere. It was measured by
instrumenting the live layout: 740x431 for the Shop and the Exchange, 740x447
for the Lab, whose floor is 60 rather than 78.

THE GENERATOR CAPS AT 400px A SIDE, so a plate cannot be generated at native
size. It is generated at half and scaled by exactly 2, which is lossless for
pixel art -- one art pixel becomes a 2x2 block and nothing is resampled at draw
time. The half size has to be divisible by 4 or pixflux rejects it, and 740/2 is
370 which is not, so the round trip crops 4 columns and pads them back by
repeating the edge. The wall runs to the panel edge, so the repeat is invisible.

THE INIT FRAME IS THE REAL ROOM. Feeding the procedural deck back in as
`init_image` is what makes a plate agree with the code: the lamp count, the lamp
positions, the floor line and the proportions come out where `StationRoom` puts
them instead of wherever the generator felt like. Ships learned the opposite
lesson -- an init image there forced a silhouette we wanted changed -- but here
the composition is the thing worth keeping.

    python tools/room_plate.py init  <shot.png> <out.png> [--lab]
    python tools/room_plate.py plate <gen.png>  <out.png> [--lab]
    python tools/room_plate.py trim  <out.png> [--lab] [--deck stock|hold|bench]
    python tools/room_plate.py level <plate.png> <out.png> <first floor row>
    python tools/room_plate.py seat  <gen.png> <out.png> [first floor row at 1x]
    python tools/room_plate.py unletter <in.png> <out.png> x,y,w,h [x,y,w,h ...]
"""

import glob
import io
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools  # noqa: E402

# The panel, measured off the live layout (see the module docstring).
PANEL = (740, 431)
PANEL_LAB = (740, 447)
FLOOR_H = 78.0
FLOOR_H_LAB = 60.0
# The screenshot is the whole 960x540 window at 2x, and the deck panel sits here.
PANEL_AT = (192, 64)

# StationRoom's own palette, so an authored trim layer lands on the same steel.
EDGE = (0x20, 0x2d, 0x3d, 255)
# Wall joints: horizontal every 46 from y=30, vertical every 124 from x=62.
JOINT_Y0, JOINT_DY = 30, 46
JOINT_X0, JOINT_DX = 62, 124
# Floor courses start 16 below the junction and the gap grows 5 a course.
COURSE_Y0, COURSE_GAP0, COURSE_GROW = 16, 16, 5


WALL = (0x0d, 0x14, 0x1d)
DEEP = (0x08, 0x0c, 0x12)
FLOOR = (0x12, 0x1a, 0x24)
FLOOR_LINE = (0x1c, 0x28, 0x36)
LAMP = (0xd9, 0x7b, 0x29)
COOL = (0xb8, 0xd2, 0xe2)
STAR = (0xc3, 0xd2, 0xe2)
LAMPS = {"outpost": 2, "settlement": 3, "city": 4, "capital": 6}


def panel_of(lab: bool) -> tuple:
    return PANEL_LAB if lab else PANEL


def floor_of(lab: bool) -> float:
    return FLOOR_H_LAB if lab else FLOOR_H


def _halve(w: int, h: int, rows: list) -> tuple:
    out = []
    for y in range(0, h - 1, 2):
        nr = bytearray()
        for x in range(0, w - 1, 2):
            nr.extend(rows[y][x * 4:x * 4 + 4])
        out.append(nr)
    return w // 2, len(out), out


def _double(w: int, h: int, rows: list) -> tuple:
    out = []
    for row in rows:
        nr = bytearray()
        for x in range(w):
            nr.extend(row[x * 4:x * 4 + 4] * 2)
        out.append(nr)
        out.append(bytearray(nr))
    return w * 2, h * 2, out


def _blank(w: int, h: int, rgb: tuple) -> list:
    px = bytes(rgb) + b"\xff"
    return [bytearray(px * w) for _ in range(h)]


def _fill(rows, w, h, r, rgb, a=1.0):
    x0, y0, x1, y1 = int(r[0]), int(r[1]), int(r[0] + r[2]), int(r[1] + r[3])
    for y in range(max(0, y0), min(h, y1)):
        row = rows[y]
        for x in range(max(0, x0), min(w, x1)):
            o = x * 4
            if a >= 1.0:
                row[o:o + 3] = bytes(rgb)
            else:
                for i in range(3):
                    row[o + i] = int(round(row[o + i] + (rgb[i] - row[o + i]) * a))


def cmd_room(dst: str, lab: bool, deck: str, level: str) -> None:
    """The procedural room, rendered offline, as the init frame.

    NOT A SCREENSHOT, because a screenshot has the deck's furniture in it -- the
    rack, the tags, the till -- and those are sibling controls drawn OVER the
    room. Baking them into the plate would draw them twice. This renders what
    `StationRoom` itself draws, from its own constants, so the init frame is the
    room and nothing else. It also reaches lamp counts the current save cannot.
    """
    pw, ph = panel_of(lab)
    floor_y = int(ph - floor_of(lab))
    n = LAMPS[level]
    glow = COOL if lab else LAMP
    rows = _blank(pw, ph, WALL)

    y = JOINT_Y0
    while y < floor_y - 8:
        _fill(rows, pw, ph, (0, y, pw, 1), (0x20, 0x2d, 0x3d))
        _fill(rows, pw, ph, (0, y + 1, pw, 1), DEEP, 0.45)
        y += JOINT_DY
    x = JOINT_X0
    while x < pw - 20:
        _fill(rows, pw, ph, (x, 0, 2, floor_y), (0x20, 0x2d, 0x3d))
        x += JOINT_DX

    if deck == "stock":
        sky = (26, 16, pw - 52, 52)
        _fill(rows, pw, ph, sky, DEEP)
        for i in range(46):
            sx = int(sky[0] + 3 + pixeltools_scatter(i * 7 + 1, sky[2] - 6))
            sy = int(sky[1] + 3 + pixeltools_scatter(i * 13 + 5, sky[3] - 6))
            b = 0.25 + 0.75 * ((i % 5) / 4.0)
            _fill(rows, pw, ph, (sx, sy, 1, 1), STAR, b)
        for t in range(2):
            _fill(rows, pw, ph, (sky[0], sky[1] + t, sky[2], 1), (0x20, 0x2d, 0x3d))
            _fill(rows, pw, ph, (sky[0], sky[1] + sky[3] - 1 - t, sky[2], 1),
                  (0x20, 0x2d, 0x3d))
        _fill(rows, pw, ph, (sky[0], sky[1] + sky[3], sky[2], 3), glow, 0.22)
        _fill(rows, pw, ph, (0, 81, pw, 3), (0x20, 0x2d, 0x3d))
    elif deck == "hold":
        _fill(rows, pw, ph, (0, 18, pw, 5), (0x15, 0x1e, 0x2a))
        dx, dw = int(pw * 0.40), int(pw * 0.19)
        _fill(rows, pw, ph, (dx, 40, dw, floor_y - 40), DEEP)
        _fill(rows, pw, ph, (dx - 6, 32, 6, floor_y - 32), (0x20, 0x2d, 0x3d))
        _fill(rows, pw, ph, (dx + dw, 32, 6, floor_y - 32), (0x20, 0x2d, 0x3d))
    elif deck == "bench":
        dwid, hood_top = 34, ph - 8 - 260
        _fill(rows, pw, ph, (pw // 2 - 17, 0, dwid, hood_top), (0x15, 0x1e, 0x2a))

    for i in range(n):
        lx = int(pw * (i + 0.5) / n)
        _fill(rows, pw, ph, (lx - 1, 0, 2, 9), (0x20, 0x2d, 0x3d))
        _fill(rows, pw, ph, (lx - 7, 9, 14, 4), (0x20, 0x2d, 0x3d))
        _fill(rows, pw, ph, (lx - 5, 12, 10, 2), glow, 0.85)

    _fill(rows, pw, ph, (0, floor_y, pw, floor_of(lab)), FLOOR)
    _fill(rows, pw, ph, (0, floor_y, pw, 2), FLOOR_LINE)
    _fill(rows, pw, ph, (0, floor_y + 2, pw, 3), DEEP, 0.55)
    fy, gap = floor_y + COURSE_Y0, float(COURSE_GAP0)
    while fy < ph - 2:
        _fill(rows, pw, ph, (0, int(fy), pw, 1), FLOOR_LINE)
        gap += COURSE_GROW
        fy += gap
    for i in range(n):
        lx = int(pw * (i + 0.5) / n)
        for step in range(6):
            spread = 16 + 14 * step
            _fill(rows, pw, ph, (lx - spread, floor_y + 13 * step, spread * 2, 13),
                  glow, 0.075 - 0.011 * step)

    hw, hh, half = _halve(pw, ph, rows)
    out = [bytearray(r[1 * 4:(hw - 1) * 4]) for r in half]
    while len(out) % 4:
        out.append(bytearray(out[-1]))
    pixeltools.encode(dst, hw - 2, len(out), out)
    print("room  %s  %dx%d  deck=%s level=%s lamps=%d%s"
          % (dst, hw - 2, len(out), deck, level, n, "  COLD" if lab else ""))


def _stretch(rows: list, sw: int, sh: int, dw: int, dh: int) -> list:
    """Nearest-neighbour, because anything else stops being pixel art."""
    out = []
    for y in range(dh):
        sy = min(sh - 1, y * sh // dh)
        src = rows[sy]
        nr = bytearray()
        for x in range(dw):
            sx = min(sw - 1, x * sw // dw)
            nr.extend(src[sx * 4:sx * 4 + 4])
        out.append(nr)
    return out


def _lum(r: int, g: int, b: int) -> float:
    return 0.299 * r + 0.587 * g + 0.114 * b


def _fit_value(rows: list, w: int, h: int, target: float) -> float:
    """Pull a generated surface into the room's value range, hue intact.

    THE ROOM IS DARKER THAN A GENERATOR WANTS TO MAKE IT. `StationRoom`'s wall
    is #0d141d and its floor #121a24 -- luminance 20 and 26 -- because the
    furniture standing in the room has to out-read the room, and the first pass
    of the drawn version failed exactly here. A surface generated against the
    hull palette comes back two or three times too bright, so it is scaled to
    the target mean rather than used as delivered.
    """
    tot = 0.0
    for row in rows:
        for x in range(w):
            o = x * 4
            tot += _lum(row[o], row[o + 1], row[o + 2])
    mean = tot / max(1.0, float(w * len(rows)))
    if mean <= 0.5:
        return mean
    gain = target / mean
    for row in rows:
        for x in range(w):
            o = x * 4
            for i in range(3):
                row[o + i] = max(0, min(255, int(round(row[o + i] * gain))))
    return mean


def cmd_build(wall_src: str, floor_src: str, dst: str, lab: bool,
              deck: str, level: str) -> None:
    """Generated SURFACES under the code's own GEOMETRY.

    THE GENERATOR IS BAD AT THE COMPOSITION AND GOOD AT THE MATERIAL. Asked for
    a room it invents its own lamp positions, its own floor line and a pair of
    converging side walls that fight a flat panel -- and the plate replaces the
    lamps, so a wrong lamp count is a wrong room. Asked for a wall it produces
    rivets, grime and worn paint, which is the part worth having.

    So the surfaces are generated and everything that has to agree with
    `StationRoom` -- the lamp count and positions, the floor line, the courses,
    the light pools, the deck's window or shutter -- is drawn over them from the
    same constants the room uses. One pair of surfaces serves every plate.
    """
    pw, ph = panel_of(lab)
    floor_y = int(ph - floor_of(lab))
    n = LAMPS[level]
    glow = COOL if lab else LAMP

    ww, wh, wrows = pixeltools.decode(wall_src)
    fw, fh, frows = pixeltools.decode(floor_src)
    was_w = _fit_value(wrows, ww, wh, _lum(*WALL))
    was_f = _fit_value(frows, fw, fh, _lum(*FLOOR))
    print("      wall %.1f -> %.1f   floor %.1f -> %.1f"
          % (was_w, _lum(*WALL), was_f, _lum(*FLOOR)))
    rows = _stretch(wrows, ww, wh, pw, floor_y)
    rows += _stretch(frows, fw, fh, pw, ph - floor_y)

    # The deck's own fixture, drawn before the light so the light falls on it.
    if deck == "stock":
        sky = (26, 16, pw - 52, 52)
        _fill(rows, pw, ph, sky, DEEP)
        for i in range(46):
            sx = int(sky[0] + 3 + pixeltools_scatter(i * 7 + 1, sky[2] - 6))
            sy = int(sky[1] + 3 + pixeltools_scatter(i * 13 + 5, sky[3] - 6))
            _fill(rows, pw, ph, (sx, sy, 1, 1), STAR,
                  0.25 + 0.75 * ((i % 5) / 4.0))
        _fill(rows, pw, ph, (sky[0], sky[1] + sky[3], sky[2], 3), glow, 0.22)
    elif deck == "hold":
        dx, dw = int(pw * 0.40), int(pw * 0.19)
        _fill(rows, pw, ph, (dx, 40, dw, floor_y - 40), DEEP)
    elif deck == "bench":
        _fill(rows, pw, ph, (pw // 2 - 17, 0, 34, ph - 268), (0x15, 0x1e, 0x2a))

    # The junction: the one line that stops wall and deck being one surface.
    _fill(rows, pw, ph, (0, floor_y, pw, 2), FLOOR_LINE)
    _fill(rows, pw, ph, (0, floor_y + 2, pw, 3), DEEP, 0.55)

    # The lamps, and the light they put down. A lamp that lights nothing is a
    # sticker; the pool underneath is what makes the room have a source.
    # THE LAMPS, AND DRAWN GENEROUSLY. The room's own are a 14x4 hood and a 2px
    # bulb, which is all a rect-drawn wall can carry without the light looking
    # painted on. A plate REPLACES those, so it is free to hang a real fixture
    # and throw a real cone -- and it has to, because a generated wall with a
    # faint glow on it reads as a wall somebody forgot to light. The positions
    # stay the room's: `w * (i + 0.5) / n`, so the plate and `_lamps()` agree.
    # NO LAMPS. They are sprites now, hung by the room at `_lamps()` positions
    # and tinted by `_light()`, so a plate that painted them would fight the
    # ones drawn over it -- and one unlit backdrop then serves every
    # development level instead of needing four.
    pixeltools.encode(dst, pw, ph, rows)
    print("build %s  %dx%d  deck=%s  (backdrop only, lamps are sprites)"
          % (dst, pw, ph, deck))


def _box_blur_lum(lum: list, w: int, h: int, r: int) -> list:
    """Separable box blur over a luminance plane. Pure stdlib, so a prefix sum
    rather than a kernel: the radius wanted here is about a quarter of the
    image and a naive kernel at that size is minutes, not seconds."""
    tmp = [[0.0] * w for _ in range(h)]
    for y in range(h):
        row = lum[y]
        acc = [0.0] * (w + 1)
        for x in range(w):
            acc[x + 1] = acc[x] + row[x]
        out = tmp[y]
        for x in range(w):
            a, b = max(0, x - r), min(w, x + r + 1)
            out[x] = (acc[b] - acc[a]) / float(b - a)
    res = [[0.0] * w for _ in range(h)]
    for x in range(w):
        acc = [0.0] * (h + 1)
        for y in range(h):
            acc[y + 1] = acc[y] + tmp[y][x]
        for y in range(h):
            a, b = max(0, y - r), min(h, y + r + 1)
            res[y][x] = (acc[b] - acc[a]) / float(b - a)
    return res


def cmd_flatten(src: str, dst: str, radius: int = 0) -> None:
    """Take the generator's own lighting out and leave its material behind.

    THE GENERATOR WILL NOT DRAW AN UNLIT ROOM. Told twice, in the plainest
    terms available -- no light source, no bright patches, no glow, evenly lit
    like a diagram -- it hung a lamp on the ceiling and put a bloom on the back
    wall both times. It knows what a room looks like and a room is lit.

    So the lighting comes out here instead. Divide by a heavily blurred copy of
    the image and the low-frequency illumination cancels while the rivets,
    seams, grime and worn paint survive untouched -- which is exactly the split
    wanted, because the light is now sprites the room hangs itself.
    """
    w, h, rows = pixeltools.decode(src)
    if radius <= 0:
        radius = max(8, min(w, h) // 4)
    lum = [[_lum(r[x * 4], r[x * 4 + 1], r[x * 4 + 2]) for x in range(w)]
           for r in rows]
    blur = _box_blur_lum(lum, w, h, radius)
    flat = sum(sum(r) for r in lum) / float(w * h)
    # CLAMP THE GAIN OR THE SHADOWS EXPLODE. A divide lifts a region by how dark
    # it is, so the darkest corner of the room -- which is dark because it is a
    # CORNER, not because a lamp missed it -- gets multiplied by six and comes
    # back an electric blue with the near-blacks crushed into noise behind it.
    # Lighting varies by maybe two stops; anything past that is geometry, and
    # geometry is the one thing here worth keeping.
    for y in range(h):
        row, br = rows[y], blur[y]
        for x in range(w):
            g = min(2.0, max(0.5, flat / max(1.0, br[x])))
            o = x * 4
            for i in range(3):
                row[o + i] = max(0, min(255, int(round(row[o + i] * g))))
    pixeltools.encode(dst, w, h, rows)
    print("flat  %s -> %s  %dx%d  radius %d  mean %.1f"
          % (src, dst, w, h, radius, flat))


def cmd_hood(src: str, dst: str) -> None:
    """Strip the light a generated fixture paints for itself.

    ASKED FOR A LAMP, THE GENERATOR DRAWS THE LAMP AND ITS SPILL -- a soft warm
    blob hanging under the bulb, and a few stray sparks below that. In this
    architecture the spill is the cone sprite's job, drawn at the room's scale
    and tinted by `_light()`, so a blob baked into the fixture is a second light
    that does not match the first and cannot go cold in the Laboratory.

    The split is clean enough to cut mechanically: the fixture's rows are mostly
    cool metal, the spill's are almost entirely warm. So find the first row
    below the hood where warmth takes over and drop everything from there.
    """
    w, h, rows = pixeltools.decode(src)

    def warm(p) -> bool:
        return p[3] > 0 and int(p[0]) - int(p[2]) > 40

    cut = h
    for y in range(h // 2, h):
        op = [x for x in range(w) if rows[y][x * 4 + 3] > 0]
        if not op:
            continue
        hot = sum(1 for x in op if warm(rows[y][x * 4:x * 4 + 4]))
        if hot >= len(op) * 0.75:
            cut = y
            break
    for y in range(cut, h):
        rows[y] = bytearray(w * 4)
    tw, th, tr = pixeltools.trim(w, h, rows)
    pixeltools.encode(dst, tw, th, tr)
    print("hood  %s -> %s  %dx%d  (spill cut at y=%d of %d)"
          % (src, dst, tw, th, cut, h))


def cmd_frames(out_dir: str) -> None:
    """The bezels every opening in a room wears, authored pixel by pixel.

    A FRAME DRAWN WITH `draw_rect` READS AS PROGRAMMER ART. It was a flat band,
    a one-pixel line and four square corners, and next to generated views and a
    generated wall it was the one thing on screen that did not look made. A
    bezel is geometry, which is exactly what a generator is bad at and a loop is
    good at, so this draws one: a dark outer rim, a bevel lit from the top left
    like everything else in the room, a groove with a rivet every tile, bolts in
    the corners, chamfered inner corners -- the thing that makes a window look
    engineered rather than cut -- and on the sill a thin cold light strip.

    AUTHORED AT HALF AND DOUBLED, like the wall, so a frame pixel is the same
    size as a wall pixel. Nine-sliced in the room at a 9px (18 in the room)
    margin with the edges TILED, not stretched, so the rivets stay evenly spaced
    at any size. The door is the same bezel with no bottom -- it runs to the
    deck -- and a bigger chamfer at the head, which is what reads as a bulkhead.
    """
    DEEP_ = (8, 12, 18)
    RIM_HI = (58, 76, 100)
    PLATE_ = (21, 30, 42)
    SHADE = (13, 19, 28)
    GROOVE = (10, 15, 22)
    LIP = (40, 55, 74)
    BOLT = (104, 124, 150)
    GLOW = (111, 211, 224)
    S, T = 24, 6   # tile size and frame thickness, at 1x

    def make(bottom: bool, chamfer: int) -> list:
        rows = [bytearray(S * 4) for _ in range(S)]

        def put(x, y, c, a=255):
            rows[y][x * 4:x * 4 + 4] = bytes((c[0], c[1], c[2], a))

        for y in range(S):
            for x in range(S):
                d = {"top": y, "left": x, "right": S - 1 - x}
                if bottom:
                    d["bottom"] = S - 1 - y
                side = min(d, key=lambda k: (d[k], k not in ("top", "bottom")))
                depth = d[side]
                if depth < T:
                    lit = side in ("top", "left")
                    c = [DEEP_, RIM_HI if lit else PLATE_, PLATE_, GROOVE,
                         PLATE_ if lit else SHADE, LIP][depth]
                    # No light strip on the sill: Jon cut it. The lip stays a lip.
                    # A rivet in the groove, once per tile along each edge.
                    if depth == 3 and ((side in ("top", "bottom") and x % 6 == 3) or
                                       (side in ("left", "right") and y % 6 == 3)):
                        c = BOLT
                    put(x, y, c)
                    continue
                # Inside the frame: the chamfer fills each inner corner.
                ix, iy = x - T, y - T
                jx, jy = S - 1 - T - x, S - 1 - T - y
                cs = []
                cs.append(ix + iy)
                cs.append(jx + iy)
                if bottom:
                    cs.append(ix + jy)
                    cs.append(jx + jy)
                k = min(cs)
                # Chamfered at the HEAD only: the sill stays a straight edge so
                # its light strip runs clean from jamb to jamb.
                top_corner = min(ix + iy, jx + iy) == k
                ch = chamfer if top_corner else 0
                if k < ch:
                    put(x, y, LIP if k == ch - 1 else PLATE_)
        # Bolts at the four corners of the frame body.
        for bx, by in ((2, 2), (S - 3, 2)) + (((2, S - 3), (S - 3, S - 3)) if bottom else ()):
            put(bx, by, BOLT)
            put(min(S - 1, bx + 1), min(S - 1, by + 1), DEEP_)
        return rows

    for name, bottom, chamfer in (("window", True, 3), ("door", False, 5)):
        rows = make(bottom, chamfer)
        dw, dh, big = _double(S, S, rows)
        dst = os.path.join(out_dir, "frame_%s.png" % name)
        pixeltools.encode(dst, dw, dh, big)
        print("frame %s  %dx%d  margin 18" % (dst, dw, dh))


def cmd_window_styles(out_dir: str) -> None:
    """More bezels, so a station's windows are not all one shape.

    A station picks ONE style off its seed and wears it on every window it has,
    because a station is built by somebody and that somebody has a way of
    making windows. Same palette, same rivets and bolts, same cold strip on the
    sill as `frames`; only the corners change:

      round  soft radiused corners inside and out -- the 2001 / Alien look.
      octa   big 45-degree corners -- the hard sci-fi one.

    Nine-sliced like `frames` but at a 12px (24 in the room) margin, because a
    curve needs more corner than a chamfer does. The corner cell covers the
    view's corners, so the view is drawn as a plain rectangle behind it.
    """
    DEEP_ = (8, 12, 18)
    RIM_HI = (58, 76, 100)
    PLATE_ = (21, 30, 42)
    SHADE = (13, 19, 28)
    GROOVE = (10, 15, 22)
    LIP = (40, 55, 74)
    BOLT = (104, 124, 150)
    GLOW = (111, 211, 224)
    M, T = 12, 6
    S = 2 * M + 6

    def make(style: str) -> list:
        state = [[None] * S for _ in range(S)]   # None outside, 'f' frame, 'h' hole
        for y in range(S):
            for x in range(S):
                qx = x if x < S // 2 else S - 1 - x
                qy = y if y < S // 2 else S - 1 - y
                if qx < M and qy < M:
                    if style == "round":
                        ro, ri = 8.0, float(M - T)
                        out = (qx < ro and qy < ro and
                               (ro - qx - 0.5) ** 2 + (ro - qy - 0.5) ** 2 > ro * ro)
                        fill = ((M - qx - 0.5) ** 2 + (M - qy - 0.5) ** 2 > ri * ri)
                        hole = qx >= T and qy >= T and not fill
                    else:
                        out = qx + qy < 5
                        hole = qx >= T and qy >= T and (qx - T) + (qy - T) >= M - T
                    state[y][x] = None if out else ("h" if hole else "f")
                else:
                    state[y][x] = "f" if min(qx, qy) < T else "h"
        rows = [bytearray(S * 4) for _ in range(S)]

        def put(x, y, c):
            rows[y][x * 4:x * 4 + 4] = bytes((c[0], c[1], c[2], 255))

        def at(x, y):
            if 0 <= x < S and 0 <= y < S:
                return state[y][x]
            return None

        for y in range(S):
            for x in range(S):
                if state[y][x] != "f":
                    continue
                qx = x if x < S // 2 else S - 1 - x
                qy = y if y < S // 2 else S - 1 - y
                d = min(qx, qy, T - 1)
                lit = (y < S // 2 and qy <= qx) or (x < S // 2 and qx < qy)
                c = [DEEP_, RIM_HI if lit else PLATE_, PLATE_, GROOVE,
                     PLATE_ if lit else SHADE, LIP][d]
                corner = qx < M and qy < M
                if not corner and d == 3 and ((qx >= M and x % 6 == 3) or
                                              (qy >= M and y % 6 == 3)):
                    c = BOLT
                near = [at(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))]
                if None in near:
                    c = DEEP_ if not lit or corner else RIM_HI
                if "h" in near:
                    c = LIP
                put(x, y, c)
        for bx, by in ((3, 3), (S - 4, 3), (3, S - 4), (S - 4, S - 4)):
            if state[by][bx] == "f":
                put(bx, by, BOLT)
        return rows

    for style in ("round", "octa"):
        rows = make(style)
        dw, dh, big = _double(S, S, rows)
        dst = os.path.join(out_dir, "frame_window_%s.png" % style)
        pixeltools.encode(dst, dw, dh, big)
        print("frame %s  %dx%d  margin 24" % (dst, dw, dh))


def cmd_ports(out_dir: str) -> None:
    """A steel plate with three portholes in it, for the wall over a short rack.

    ONE PLATE, ONE VIEW BEHIND IT. The room draws a single view across the whole
    plate and this covers everything but the holes, so the three portholes look
    onto one place from three angles -- which is what three portholes in one
    wall do. Glass is in the sprite: a faint cold cast and a reflection streak.
    Authored at the size the slot is, 252x96 (228x72 of opening, and the 12 the
    other frames stand proud of it), because a circle does not nine-slice.
    """
    DEEP_ = (8, 12, 18)
    RIM_HI = (58, 76, 100)
    PLATE_ = (21, 30, 42)
    PLATE2 = (27, 38, 52)
    SHADE = (13, 19, 28)
    GROOVE = (10, 15, 22)
    LIP = (40, 55, 74)
    BOLT = (104, 124, 150)
    AMBER = (217, 123, 41)
    W, H = 126, 48
    rows = [bytearray(W * 4) for _ in range(H)]
    centres = ((23, 24), (63, 24), (103, 24))
    R = 16.0
    import math
    for y in range(H):
        for x in range(W):
            # Plate corners knocked off.
            if min(x, W - 1 - x) + min(y, H - 1 - y) < 2:
                continue
            best, bc = 1e9, None
            for cx, cy in centres:
                d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                if d < best:
                    best, bc = d, (cx, cy)
            o = x * 4
            if best < R:
                # Glass: nearly clear, a cold cast, one streak of reflection.
                streak = ((x - bc[0]) - (y - bc[1])) in (-6, -5, 3)
                c, a = ((190, 215, 235), 46) if streak else ((60, 90, 130), 22)
                rows[y][o:o + 4] = bytes((c[0], c[1], c[2], a))
                continue
            ang = math.atan2(y + 0.5 - bc[1], x + 0.5 - bc[0])
            upper_left = -2.6 < ang < 0.55 if False else (ang < -0.8 or ang > 2.4)
            if best < R + 1:
                c = DEEP_
            elif best < R + 2.6:
                c = RIM_HI if upper_left else SHADE
            elif best < R + 3.6:
                c = GROOVE
            elif best < R + 4.6:
                c = LIP if upper_left else PLATE_
            else:
                c = PLATE2 if (y // 2 + x // 7) % 5 else PLATE_
            # Plate edge.
            e = min(x, W - 1 - x, y, H - 1 - y)
            if e == 0:
                c = DEEP_
            elif e == 1:
                c = RIM_HI if (y < H // 2 and y <= x and y <= W - 1 - x) or x < 2 else SHADE
            rows[y][o:o + 4] = bytes((c[0], c[1], c[2], 255))
    # Bolts round each ring, and a status light between the ports.
    for cx, cy in centres:
        for k in range(8):
            a = k * math.pi / 4 + math.pi / 8
            bx = int(round(cx - 0.5 + math.cos(a) * (R + 6.5)))
            by = int(round(cy - 0.5 + math.sin(a) * (R + 6.5)))
            if 1 < bx < W - 2 and 1 < by < H - 2:
                rows[by][bx * 4:bx * 4 + 4] = bytes(BOLT + (255,))
    for lx in (43, 83):
        rows[5][lx * 4:lx * 4 + 4] = bytes(AMBER + (255,))
    dw, dh, big = _double(W, H, rows)
    dst = os.path.join(out_dir, "frame_ports.png")
    pixeltools.encode(dst, dw, dh, big)
    print("ports %s  %dx%d" % (dst, dw, dh))


# The shop's furniture, from `ShelfDisplay` and `TradeCounter`. The boards are
# where the parts stand, so a generated shelf has to put an edge exactly there.
SHELF = (280, 215)
SHELF_BOARDS = (59, 122, 185)   # CAP_H + 6 + PITCH*(i+1) - (PLANK+TICKET_H+HEAD) - 2, PITCH 63
SHELF_PLANK, SHELF_CAP, SHELF_PLINTH, SHELF_POST = 5, 9, 11, 13
# The till: a desk 96 tall, and headroom above it for what stands on the desk.
COUNTER = (180, 96)
COUNTER_HEAD = 32


def cmd_shelf_init(dst: str) -> None:
    """The shelf's geometry at half size, as the init frame for a generated one.

    NOTHING ELSE IN IT: posts, cap, plinth, a back and three boards, on a
    transparent ground. The generator repaints the material and keeps the
    places, so the boards land under the parts `ShelfDisplay` stands on them.
    """
    w, h = SHELF[0] // 2, (SHELF[1] + 1) // 2
    rows = [bytearray(w * 4) for _ in range(h)]
    post, lip, back = (44, 61, 82), (95, 119, 148), (22, 31, 43)

    def box(x, y, bw, bh, c):
        for yy in range(max(0, y), min(h, y + bh)):
            for xx in range(max(0, x), min(w, x + bw)):
                rows[yy][xx * 4:xx * 4 + 4] = bytes((c[0], c[1], c[2], 255))

    p = SHELF_POST // 2
    box(p, 0, w - 2 * p, h, back)
    box(0, 0, p, h, post)
    box(w - p, 0, p, h, post)
    box(0, 0, w, SHELF_CAP // 2, post)
    box(0, 0, w, 1, lip)
    box(0, h - SHELF_PLINTH // 2 - 1, w, SHELF_PLINTH // 2 + 1, post)
    for by in SHELF_BOARDS:
        box(0, by // 2, w, 3, post)
        box(0, by // 2, w, 1, lip)
    pixeltools.encode(dst, w, h, rows)
    print("shelf init %s  %dx%d  boards at %s" % (dst, w, h,
          [b // 2 for b in SHELF_BOARDS]))


def cmd_counter_init(dst: str) -> None:
    """The till at half size: a desk at the foot, air above it for its props.

    Wider by four than half of 180, because pixflux wants multiples of four; the
    install crops it back.
    """
    w, h = 92, (COUNTER[1] + COUNTER_HEAD) // 2
    rows = [bytearray(w * 4) for _ in range(h)]
    top, face, lip, glass = (47, 64, 84), (29, 40, 54), (100, 126, 157), (13, 26, 32)

    def box(x, y, bw, bh, c):
        for yy in range(max(0, y), min(h, y + bh)):
            for xx in range(max(0, x), min(w, x + bw)):
                rows[yy][xx * 4:xx * 4 + 4] = bytes((c[0], c[1], c[2], 255))

    dy = COUNTER_HEAD // 2
    box(1, dy, w - 2, h - dy, face)
    box(1, dy, w - 2, 5, top)
    box(1, dy, w - 2, 1, lip)
    box((w - 66) // 2, dy + 9, 66, 11, glass)
    pixeltools.encode(dst, w, h, rows)
    print("counter init %s  %dx%d  desk top at %d" % (dst, w, h, dy))


def cmd_furniture(src: str, dst: str, w: int, h: int) -> None:
    """A half-size generation doubled, and cropped to the size the code lays out.

    Cropped from the CENTRE across and from the FOOT down, because furniture
    stands on the deck: a row lost has to come off the top, never the base.
    """
    sw, sh, rows = pixeltools.decode(src)
    dw, dh, big = _double(sw, sh, rows)
    x0 = max(0, (dw - w) // 2)
    y0 = max(0, dh - h)
    out = [bytearray(r[x0 * 4:(x0 + w) * 4]) for r in big[y0:y0 + h]]
    pixeltools.encode(dst, w, len(out), out)
    print("furniture %s -> %s  %dx%d" % (src, dst, w, len(out)))


def cmd_shop_art(out_dir: str) -> None:
    """The shop's shelf and till, authored pixel by pixel.

    AUTHORED BECAUSE GENERATING THEM FAILED. Four takes against a flat init frame
    of the shelf's geometry came back as the init frame -- flat panels, no wear,
    nothing lived-in. A flat init locks a flat result; the room plates only
    worked because their init frame had texture in it. So the geometry is drawn
    here, where it lands exactly: the boards at the heights `ShelfDisplay`
    stands parts on, the till's screen exactly where `TradeCounter` prints its
    price. This is also a detailed init frame, if a generated wear pass is wanted.

    AT HALF SIZE AND DOUBLED, like the wall and the bezels. The middle board is a
    pixel high of `ShelfDisplay`'s 199, because an odd pitch cannot land on a
    two-pixel grid; the part standing there overlaps the lip by one pixel.
    """
    DEEP_ = (8, 12, 18)
    RIM_HI = (58, 76, 100)
    PLATE_ = (21, 30, 42)
    PLATE2 = (28, 39, 54)
    SHADE_ = (13, 19, 28)
    GROOVE = (10, 15, 22)
    LIP_ = (40, 55, 74)
    BOLT = (104, 124, 150)
    GLOW = (111, 211, 224)
    GLOW_DIM = (48, 104, 118)
    AMBER = (217, 123, 41)
    GLASS = (13, 26, 32)
    BACK = (17, 24, 34)
    BACK_DOT = (11, 16, 23)
    RED = (178, 64, 54)
    PAPER = (196, 204, 212)
    YELLOW = (214, 178, 64)

    def canvas(w, h):
        return [bytearray(w * 4) for _ in range(h)]

    def px(rows, x, y, c, a=1.0):
        h, w = len(rows), len(rows[0]) // 4
        if not (0 <= x < w and 0 <= y < h):
            return
        o = x * 4
        if a >= 1.0 or rows[y][o + 3] == 0:
            rows[y][o:o + 4] = bytes((c[0], c[1], c[2], 255 if a >= 1.0 else int(255 * a)))
            return
        for i in range(3):
            rows[y][o + i] = int(rows[y][o + i] * (1 - a) + c[i] * a)

    def box(rows, x, y, w, h, c, a=1.0):
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                px(rows, xx, yy, c, a)

    def rnd(i):
        return ((i * 2654435761) % 4294967296) / 4294967296.0

    def _shelf(nb, full_h):
        # POST 4 AND AIR 2, at half size -- an 8px upright and 4px of pad at 1x.
        # They were 7 and 7, which spent 40 of the rack's 132 pixels on furniture
        # and left the goods looking lost inside it. Four columns of parts is 92
        # whatever the frame does, so slimming the frame is the whole of the fix.
        P, AIR = 4, 2
        W, H = 2 * (P + AIR) + 46, (full_h + 1) // 2
        s = canvas(W, H)
        box(s, P, 5, W - P * 2, H - 11, BACK)
        for y in range(5, H - 6):
            for x in range(P, W - P):
                if x % 5 == 2 and y % 5 == 2:
                    px(s, x, y, BACK_DOT)
        for y in range(5, H - 6):
            px(s, W // 2, y, SHADE_)
        for x0 in (0, W - P):
            # Dark outer edge, a lit face, plate, dark inner edge: the same
            # pillar the 7px post read as, with the two flat middles dropped.
            cols = [DEEP_, RIM_HI, PLATE_, DEEP_]
            for i, c in enumerate(cols):
                box(s, x0 + i, 0, 1, H, c)
            for y in range(8, H - 8, 4):
                px(s, x0 + 2, y, DEEP_)
                px(s, x0 + 2, y + 1, LIP_)
        # Cap.
        for i, c in enumerate([DEEP_, RIM_HI, PLATE2, PLATE2, SHADE_]):
            box(s, 0, i, W, 1, c)
        for bx in (2, W - 3):
            px(s, bx, 2, BOLT)
        for lx in (W // 2 - 4, W // 2, W // 2 + 4):
            px(s, lx, 2, AMBER if lx != W // 2 + 4 else GLOW)
        # Boards, with the cyan strip on each front edge, and a faint glow above.
        # `ShelfDisplay`'s boards at 59, 122, 185, on the two-pixel grid.
        for by in (29, 61, 92)[:nb]:
            for k, a in ((1, 0.14), (2, 0.07), (3, 0.03)):
                box(s, P, by - k, W - P * 2, 1, GLOW, a)
            box(s, 2, by, W - 4, 1, LIP_)
            box(s, 2, by + 1, W - 4, 1, PLATE2)
            box(s, 2, by + 2, W - 4, 1, GLOW)
            box(s, P, by + 3, W - P * 2, 1, SHADE_)
            for step, bw in enumerate((3, 2, 1)):
                box(s, P, by + 3 + step, bw, 1, PLATE_)
                box(s, W - P - bw, by + 3 + step, bw, 1, PLATE_)
        # Plinth: vents, a hazard label, feet.
        py = H - 6
        box(s, 0, py, W, 1, LIP_)
        box(s, 0, py + 1, W, 4, PLATE_)
        box(s, 0, py + 5, W, 1, DEEP_)
        for vx in range(34, W - 8, 6):
            box(s, vx, py + 2, 3, 1, DEEP_)
            box(s, vx, py + 3, 3, 1, SHADE_)
        for x in range(8, 28):
            for y in range(py + 1, py + 5):
                px(s, x, y, YELLOW if ((x + y) // 2) % 2 == 0 else DEEP_)
        # Wear: scuffs along the lit edges, stickers on the uprights.
        for i in range(60):
            x = int(rnd(i * 3 + 1) * W)
            y = int(rnd(i * 5 + 7) * H)
            if s[y][x * 4 + 3] and (x < P or x >= W - P):
                px(s, x, y, RIM_HI if i % 3 else LIP_)
        box(s, 1, 70, 3, 4, RED)
        px(s, 2, 71, PAPER)
        box(s, W - 4, 120, 3, 3, PAPER)
        px(s, W - 3, 121, SHADE_)
        box(s, W - 4, 30, 3, 2, YELLOW)
        dw, dh, big = _double(W, H, s)
        pixeltools.encode(os.path.join(out_dir, "shop_shelf%d.png" % nb), dw, full_h,
                          big[:full_h])
        print("shop_shelf%d  %dx%d" % (nb, dw, full_h))

    # --- THE SHELF, cut for parts at 1x: three boards 63 apart (a 2x2 part is
    # 40 tall at 1x), 215 in all -- shorter than the two-board rack it replaces.
    # Four cells and three 4px gaps at 1x: 92, two 8px posts, 4px air inside each.
    for nb in (2, 3):
        _shelf(nb, 9 + 6 + 63 * nb + 11)

    # --- THE TILL, 90x64 -> 180x128: 32 rows of headroom, then the 96 desk.
    W, H = 90, 64
    t = canvas(W, H)
    dy = COUNTER_HEAD // 2
    # Card terminal.
    box(t, 9, 7, 12, 9, PLATE2)
    box(t, 9, 7, 12, 1, RIM_HI)
    box(t, 20, 7, 1, 9, SHADE_)
    box(t, 11, 9, 8, 3, GLOW_DIM)
    box(t, 11, 9, 8, 1, GLOW)
    for kx in (11, 14, 17):
        px(t, kx, 13, BOLT)
        px(t, kx + 1, 14, LIP_)
    # Service bell.
    box(t, 44, 15, 10, 1, PLATE_)
    box(t, 45, 14, 8, 1, LIP_)
    box(t, 46, 13, 6, 1, BOLT)
    box(t, 47, 12, 4, 1, BOLT)
    px(t, 48, 11, PAPER)
    px(t, 49, 11, PAPER)
    # Desk lamp: base, a bent arm, a shade and its light on the desk.
    box(t, 70, 14, 7, 2, PLATE2)
    box(t, 70, 14, 7, 1, RIM_HI)
    for i, (ax, ay) in enumerate(((73, 13), (73, 12), (72, 11), (71, 10), (70, 9),
                                   (69, 8), (68, 7))):
        px(t, ax, ay, LIP_)
    box(t, 61, 4, 9, 1, BOLT)
    box(t, 61, 5, 9, 2, LIP_)
    box(t, 62, 7, 7, 1, AMBER)
    px(t, 65, 7, (255, 206, 140))
    for k in range(1, 9):
        box(t, 62 - k // 2, 7 + k, 7 + k, 1, AMBER, 0.20 - 0.018 * k)
    # The desk: slab, body, the screen the price prints on, vents, kick strip.
    box(t, 0, dy, W, 1, LIP_)
    box(t, 0, dy + 1, W, 1, PLATE2)
    box(t, 0, dy + 2, W, 1, SHADE_)
    box(t, 2, dy + 3, W - 4, H - dy - 3, PLATE_)
    box(t, 2, dy + 3, 1, H - dy - 3, RIM_HI)
    box(t, W - 3, dy + 3, 1, H - dy - 3, SHADE_)
    # Screen: `TradeCounter`'s window is 132x22 centred at desk top + 19.
    sx0, sy0, sw_, sh_ = 12, dy + 9, 66, 12
    box(t, sx0 - 1, sy0 - 1, sw_ + 2, sh_ + 2, DEEP_)
    box(t, sx0, sy0, sw_, sh_, GLASS)
    box(t, sx0 - 1, sy0 + sh_ + 1, sw_ + 2, 1, LIP_)
    box(t, sx0, sy0, sw_, 1, (20, 38, 46))
    # Lower panel: vents, a seam, a sticker, scuffs.
    for vx in range(10, W - 30, 5):
        box(t, vx, dy + 29, 3, 1, DEEP_)
        box(t, vx, dy + 30, 3, 1, SHADE_)
    box(t, W // 2, dy + 26, 1, 14, SHADE_)
    box(t, W - 18, dy + 28, 5, 4, RED)
    box(t, W - 17, dy + 29, 3, 1, PAPER)
    for i in range(25):
        x = 3 + int(rnd(i * 11 + 3) * (W - 6))
        y = dy + 3 + int(rnd(i * 13 + 5) * (H - dy - 8))
        if not (sx0 - 1 <= x <= sx0 + sw_ and sy0 - 1 <= y <= sy0 + sh_):
            px(t, x, y, LIP_ if i % 2 else SHADE_)
    box(t, 3, H - 4, W - 6, 1, GLOW)
    box(t, 3, H - 3, W - 6, 3, DEEP_)
    dw, dh, big = _double(W, H, t)
    pixeltools.encode(os.path.join(out_dir, "shop_counter.png"), dw, dh, big)
    print("shop_counter  %dx%d  desk top at %d" % (dw, dh, dy * 2))


def cmd_backdrop(src: str, dst: str, pad: int = 16) -> None:
    """One place behind the whole wall, at the wall's pixel size.

    EVERY OPENING LOOKS ONTO THE SAME PLACE. Each opening picking its own view
    made the wall a set of pictures -- three portholes onto three things read as
    three posters. So one view goes behind the lot, doubled like the wall, and
    each opening shows the part of it that is behind that hole.

    A view is 320 wide and doubles to 640; the wall's openings span about 700.
    The generated promenade has a dark pillar at each edge, so `pad` columns are
    MIRRORED out from each side and the pillars simply carry on -- no sign text
    is anywhere near them to come out backwards. The generator's dark letterbox
    bands top and bottom are cropped first, or they would sit behind the
    openings as black strips.
    """
    w, h, rows = pixeltools.decode(src)

    def dark(y):
        return sum(_lum(rows[y][x * 4], rows[y][x * 4 + 1], rows[y][x * 4 + 2])
                   for x in range(w)) / float(w) < 12.0

    top, bot = 0, h
    while top < h // 4 and dark(top):
        top += 1
    while bot > h - h // 4 and dark(bot - 1):
        bot -= 1
    out = []
    for y in range(top, bot):
        r = rows[y]
        left = bytearray()
        for x in range(pad, 0, -1):
            left.extend(r[x * 4:x * 4 + 4])
        right = bytearray()
        for x in range(w - 2, w - 2 - pad, -1):
            right.extend(r[x * 4:x * 4 + 4])
        out.append(left + bytearray(r[:w * 4]) + right)
    nw = w + 2 * pad
    dw, dh, big = _double(nw, len(out), out)
    pixeltools.encode(dst, dw, dh, big)
    print("backdrop %s -> %s  %dx%d  (rows %d..%d kept, %d mirrored each side)"
          % (src, dst, dw, dh, top, bot, pad))


def cmd_openings(stage: str, out_dir: str) -> None:
    """The shaped openings, installed with their holes as DATA, not as a mask.

    AN OPENING HAS TWO TRANSPARENCIES and only one of them is a hole: the pixels
    inside the frame that you see the station through, and the pixels outside it
    that are just air around the sprite. They look identical to a draw call, so
    compositing the view behind the sprite paints promenade all round the frame
    as well as through it. The bench solved this twice -- first with a second
    mask image, which meant an opening needed two files to arrive before it drew
    anything, then with the holes measured out as spans. Spans won.

    So each sprite installs as `opening_<name>.png` with BOTH transparencies
    intact, and every hole row is written to `opening_holes.json` as
    [y, x, width]. The room fills those spans with the backdrop and then draws
    the sprite over the top; nothing else on the wall can leak.
    """
    import json
    os.makedirs(out_dir, exist_ok=True)
    table = {}
    for f in sorted(glob.glob(os.path.join(stage, "open_*.png"))):
        name = os.path.basename(f)[5:-4]
        mask = os.path.join(stage, "hole_%s.png" % name)
        if not os.path.exists(mask):
            print("  %-12s SKIPPED -- no hole mask beside it" % name)
            continue
        w, h, rows = pixeltools.decode(f)
        mw, mh, mrows = pixeltools.decode(mask)
        if (mw, mh) != (w, h):
            print("  %-12s SKIPPED -- mask is %dx%d, sprite is %dx%d"
                  % (name, mw, mh, w, h))
            continue
        runs = []
        for y in range(h):
            x = 0
            while x < w:
                if mrows[y][x * 4 + 3] > 40:
                    x0 = x
                    while x < w and mrows[y][x * 4 + 3] > 40:
                        x += 1
                    runs.append([y, x0, x - x0])
                else:
                    x += 1
        if not runs:
            # AN OPENING WITH NO HOLE IS A PLATE. `strip` and `grid` were drawn
            # with frames too thin for the cutter to find an inside in; a room
            # that picked one would hang a solid panel on the wall and call it
            # a window.
            print("  %-12s SKIPPED -- no hole in it, it is a solid plate" % name)
            continue
        dst = os.path.join(out_dir, "opening_%s.png" % name)
        pixeltools.encode(dst, w, h, rows)
        table[name] = {"w": w, "h": h, "runs": runs}
        print("  %-12s %3dx%-3d  %4d runs" % (name, w, h, len(runs)))
    jf = os.path.join(out_dir, "opening_holes.json")
    io.open(jf, "w", encoding="utf-8", newline=chr(10)).write(
        json.dumps(table, separators=(",", ":"), sort_keys=True))
    print("openings  %d installed, holes -> %s (%d KB)"
          % (len(table), jf, os.path.getsize(jf) // 1024))


def cmd_decks(station: str) -> None:
    """Where each backdrop's OWN floor is, so the two floors can line up.

    A backdrop is placed with the bottom of the file on the room's floor line,
    which only lines the two decks up if the hall's floor is drawn at the very
    bottom of the picture. Measured across the installed set it is not: the deck
    edge sits anywhere from 18 to 172 pixels up, so the hall's floor floats
    above the shop's by that much and the room reads as two pictures.

    The deck edge is the strongest brightness step in the bottom half -- the
    dark deck meeting the lit wall above it. Written to `backdrop_decks.json`
    as pixels from the BOTTOM of the file, which is the number a placement
    wants: shift the picture down by it and the floors meet.
    """
    import json
    out = {}
    for f in sorted(glob.glob(os.path.join(station, "backdrop_*.png"))):
        name = os.path.basename(f)[9:-4]
        w, h, rows = pixeltools.decode(f)
        prof = []
        for y in range(h):
            r = rows[y]
            prof.append(sum(_lum(r[x * 4], r[x * 4 + 1], r[x * 4 + 2])
                            for x in range(0, w, 4)) / (w // 4))
        best, besty = 0.0, h - 1
        for y in range(int(h * 0.55), h - 3):
            d = abs(prof[y + 2] - prof[y - 2])
            if d > best:
                best, besty = d, y
        out[name] = h - besty
    jf = os.path.join(station, "backdrop_decks.json")
    io.open(jf, "w", encoding="utf-8", newline=chr(10)).write(
        json.dumps(out, separators=(",", ":"), sort_keys=True))
    vals = sorted(out.values())
    print("decks  %d backdrops -> %s  (median %d px, range %d..%d)"
          % (len(out), jf, vals[len(vals) // 2], vals[0], vals[-1]))


def cmd_unsmear(stage: str) -> None:
    """Fill the short foot of a plate by STRETCHING its floor, not inventing one.

    A PLATE IS SHORT AND SOMETHING HAD TO FILL THE GAP. Generated at half size
    and doubled, so every row appears exactly twice -- that pairing is the
    doubling and is correct. Where the 1x art came out shy of 216 rows the fill
    repeated its LAST ROW, so the foot of the deck is one line held down 12, 18,
    even 38 rows, right where the floor meets the viewer.

    TWO THINGS ARE TRUE ABOUT THIS FLOOR. Its structure runs DOWN, not across --
    a column varies about half as much down its length as a row varies across
    its width, because the plate is vertical plank seams. And the courses widen
    toward the viewer by design. Both of those make a VERTICAL STRETCH the right
    repair: it cannot move a seam sideways, because every column stays in its
    own column, and stretching a floor whose courses already widen downward
    simply widens them a little more.

    It is also all real art. An earlier version here rebuilt the strip from
    per-column tone and synthetic speckle, and before that mirrored a band
    left-to-right -- which shifted every plank seam and was rightly called out.
    Nothing is invented now: the good floor is resampled over the whole band.

    IN PAIRS, ALWAYS. The unit is the 2-row pair, not the row, so a stretch
    duplicates whole pairs and the doubling survives. Stretching row-wise would
    leave odd rows single and even rows tripled, and the eye reads that as the
    material changing halfway down the deck.
    """
    floor_y = FLOOR_Y if "FLOOR_Y" in globals() else 353
    floor_y += floor_y % 2            # pairs start on even rows
    for f in sorted(glob.glob(os.path.join(stage, "plate_*.png"))):
        name = os.path.basename(f)[6:-4]
        w, h, rows = pixeltools.decode(f)
        n = 1
        while n < h - 8 and bytes(rows[h - 1 - n]) == bytes(rows[h - 1]):
            n += 1
        if n <= 2:
            continue
        n -= n % 2
        src_pairs = (h - n - floor_y) // 2      # good floor, in pairs
        dst_pairs = (h - floor_y) // 2          # the whole floor band
        if src_pairs < 4:
            print("  %-13s only %d good pairs of floor, too little to stretch"
                  % (name, src_pairs))
            continue
        keep = [bytearray(rows[floor_y + i]) for i in range(src_pairs * 2)]
        for j in range(dst_pairs):
            k = (j * src_pairs) // dst_pairs    # nearest pair, evenly spread
            rows[floor_y + j * 2] = bytearray(keep[k * 2])
            rows[floor_y + j * 2 + 1] = bytearray(keep[k * 2 + 1])
        pixeltools.encode(f, w, h, rows)
        print("  %-13s %2d smeared rows | %d pairs of floor stretched over %d (x%.2f)"
              % (name, n, src_pairs, dst_pairs, dst_pairs / float(src_pairs)))
    print("unsmear  done")


def cmd_compose(stage: str, out_dir: str) -> None:
    """A wall and a floor, generated apart, cropped into one plate. No stretch.

    431 IS ODD, which is the whole reason the old plates had a smear at the
    foot. Art doubles by twos, so no 1x image can double to 431 rows: something
    always had to make up the difference, and what made it up was the last row
    held down 12 to 38 times.

    AND THE GENERATOR WILL NOT SPLIT A FRAME WHERE YOU ASK. Told to put the
    floor in the bottom fifth it put the junction 59% down -- so one image
    cannot supply both bands at the sizes they need, and the wall and the floor
    are generated separately.

    Each is generated LARGER than its band and cropped down, never scaled:
      wall   372x180 -> 744x360, keep the BOTTOM 353 rows (the junction edge)
      floor  372x44  -> 744x88,  keep the TOP 78 rows (the far edge, which is
                                 the edge that meets the wall)
    and 2 columns come off each side to land on 740. Every pixel is generated
    art at 1:1, the junction falls exactly on FLOOR_Y, and nothing is filled.
    """
    os.makedirs(out_dir, exist_ok=True)
    pw, ph = 740, 431
    fy = FLOOR_Y if "FLOOR_Y" in globals() else 353
    made = 0
    for spec in sorted(glob.glob(os.path.join(stage, "pair_*.txt"))):
        name = os.path.basename(spec)[5:-4]
        wall_f, floor_f = io.open(spec, encoding="utf-8").read().split()
        ww, wh, wrows = pixeltools.decode(os.path.join(stage, wall_f))
        fw, fh, frows = pixeltools.decode(os.path.join(stage, floor_f))
        big_w = [r for row in wrows for r in (_double_row(row, ww),) * 2]
        big_f = [r for row in frows for r in (_double_row(row, fw),) * 2]
        if len(big_w) < fy or len(big_f) < ph - fy:
            print("  %-13s SHORT: wall %d rows, floor %d rows" % (name, len(big_w), len(big_f)))
            continue
        x0 = (ww * 2 - pw) // 2
        out = []
        for r in big_w[len(big_w) - fy:]:
            out.append(bytearray(r[x0 * 4:(x0 + pw) * 4]))
        for r in big_f[:ph - fy]:
            out.append(bytearray(r[x0 * 4:(x0 + pw) * 4]))
        pixeltools.encode(os.path.join(out_dir, "plate_%s.png" % name), pw, ph, out)
        made += 1
        print("  %-13s %s + %s -> %dx%d, junction at %d" % (name, wall_f, floor_f, pw, ph, fy))
    print("compose  %d plates, no row filled or stretched" % made)


def _double_row(row: bytearray, w: int) -> bytearray:
    out = bytearray()
    for x in range(w):
        out.extend(row[x * 4:x * 4 + 4] * 2)
    return out


def cmd_despeckle(stage: str) -> None:
    """Stray lit pixels on a fixture's housing, repainted out.

    The generator strands the odd pixel of glass-white up on the shade. They
    read as dirt, and they are worse than that: the beam is built from the
    BRIGHTEST pixels in the art, so a speck of glass colour on the housing is a
    lamp as far as the bench is concerned.

    NOT BY SIZE -- BY HEIGHT. Sorting on "small patches are strays" was wrong
    twice over. The speck Jon kept seeing on the dome is 16 pixels, larger than
    the threshold, so it survived; and a ring's real hoop breaks into patches of
    4 and 8, so a size rule would have eaten the lamp. What actually separates
    them is WHERE THEY SIT: a lamp's glass is a band at the foot of the fixture,
    and anything floating well above that band is on the shade. On the dome the
    glass runs y42..59 and the speck sits at y24..27; on the ring and the cage
    nothing at all sits above the glass, which is why they should be, and are,
    left alone.
    """
    lift = 8                       # px above the glass before it is a stray
    for f in sorted(glob.glob(os.path.join(stage, "lampskin_*.png"))):
        name = os.path.basename(f)[9:-4]
        w, h, rows = pixeltools.decode(f)

        def at(x, y):
            o = x * 4
            return rows[y][o], rows[y][o + 1], rows[y][o + 2], rows[y][o + 3]

        def lum(p):
            return 0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2]

        peak = max((lum(at(x, y)) for y in range(h) for x in range(w)
                    if at(x, y)[3] >= 40), default=0)
        cut = max(90.0, peak * 0.80)
        bright = [[at(x, y)[3] >= 40 and lum(at(x, y)) >= cut for x in range(w)]
                  for y in range(h)]
        seen = [[False] * w for _ in range(h)]
        comps = []
        for sy in range(h):
            for sx in range(w):
                if seen[sy][sx] or not bright[sy][sx]:
                    continue
                stack, pts = [(sx, sy)], []
                seen[sy][sx] = True
                while stack:
                    x, y = stack.pop()
                    pts.append((x, y))
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        nx, ny = x + dx, y + dy
                        if (0 <= nx < w and 0 <= ny < h and not seen[ny][nx]
                                and bright[ny][nx]):
                            seen[ny][nx] = True
                            stack.append((nx, ny))
                comps.append(pts)
        if not comps:
            print("  %-9s nothing lit to judge" % name)
            continue
        main = max(comps, key=len)
        top = min(y for _, y in main)          # where the glass begins
        fixed = 0
        for pts in comps:
            if pts is main or max(y for _, y in pts) >= top - lift:
                continue                       # in the glass, or just above it
            # ONE COLOUR FOR THE WHOLE PATCH, taken from everything around its
            # edge. Doing it per pixel left the CORE of a 4x4 speck behind: an
            # interior pixel has no unlit neighbour to copy, so the shell was
            # repainted and the middle survived as a smaller speck of its own.
            ring = []
            for (x, y) in pts:
                for dx in (-1, 0, 1):
                    for dy in (-1, 0, 1):
                        nx, ny = x + dx, y + dy
                        if (not (dx or dy)) or not (0 <= nx < w and 0 <= ny < h):
                            continue
                        if at(nx, ny)[3] >= 40 and not bright[ny][nx]:
                            ring.append(at(nx, ny))
            if not ring:
                continue
            ring.sort(key=lum)
            m = ring[len(ring) // 2]
            for (x, y) in pts:
                rows[y][x * 4:x * 4 + 3] = bytes(m[:3])
                fixed += 1
        if fixed:
            pixeltools.encode(f, w, h, rows)
        print("  %-9s glass from y%-3d %2d stray pixel%s repainted"
              % (name, top, fixed, "" if fixed == 1 else "s"))


VIEW_MEDIAN = 30.0


def cmd_view(src: str, dst: str) -> None:
    """A generated view of somewhere else on the station, fitted to the room.

    THE MIDTONES, NOT THE LIGHTS. A view is seen through the room's wall, so it
    has to sit behind the room's own light: a canteen generated at median 70
    against a wall at 19 is the brightest thing on the screen and reads as a
    poster. But what makes a view worth having is its lit signs and lamps, so a
    flat scale is wrong too -- it greys them. A gamma does both: it brings the
    median down to the darkest views that already looked right (the lounges and
    the two-level promenades, about 25-30) and leaves the highlights high.
    A view already that dark is left alone.
    """
    import math
    w, h, rows = pixeltools.decode(src)
    lum = sorted(_lum(rows[y][x * 4], rows[y][x * 4 + 1], rows[y][x * 4 + 2])
                 for y in range(0, h, 2) for x in range(0, w, 2))
    med = max(1.0, lum[len(lum) // 2])
    g = 1.0
    if med > VIEW_MEDIAN:
        g = math.log(VIEW_MEDIAN / 255.0) / math.log(med / 255.0)
    if g != 1.0:
        lut = [int(round(255.0 * (v / 255.0) ** g)) for v in range(256)]
        for r in rows:
            for x in range(w):
                o = x * 4
                for i in range(3):
                    r[o + i] = lut[r[o + i]]
    pixeltools.encode(dst, w, h, rows)
    print("view  %s -> %s  %dx%d  median %.1f  gamma %.2f"
          % (src, dst, w, h, med, g))


def cmd_glow(dst_cone: str, dst_pool: str) -> None:
    """The light a lamp throws, as two white-on-transparent sprites.

    WHITE, SO `_light()` CAN COLOUR THEM. The room draws these modulated by its
    own lamp colour, which is how the Laboratory gets cold light out of the same
    cone every other deck lights warm -- one pair of sprites, four decks. Drawn
    rather than generated because a soft alpha ramp is the one thing the
    generator does worse than arithmetic does.
    """
    cw, chh = 96, 256
    rows = [bytearray(cw * 4) for _ in range(chh)]
    for y in range(chh):
        t = y / float(chh - 1)
        half = 6.0 + (cw * 0.5 - 7.0) * (t ** 0.80)
        # Steep, because a gentle falloff over 250 pixels stops reading as a
        # beam and starts reading as a smudge on the wall. Near zero by the
        # floor, where the pool takes the light over.
        peak = (1.0 - t) ** 2.6
        for x in range(cw):
            d = abs(x + 0.5 - cw * 0.5)
            if d > half:
                continue
            edge = (1.0 - (d / half) ** 2.0) ** 1.4
            a = int(round(255 * min(1.0, 0.78 * peak * edge + 0.035 * edge)))
            if a > 0:
                o = x * 4
                rows[y][o:o + 4] = bytes((255, 255, 255, a))
    pixeltools.encode(dst_cone, cw, chh, rows)

    pw, phh = 160, 96
    rows = [bytearray(pw * 4) for _ in range(phh)]
    for y in range(phh):
        ty = y / float(phh - 1)
        # An ellipse lying on the deck: wide, shallow, brightest at the near lip.
        for x in range(pw):
            tx = (x + 0.5 - pw * 0.5) / (pw * 0.5)
            r = (tx * tx) + ((ty - 0.18) * 1.55) ** 2
            if r >= 1.0:
                continue
            a = int(round(255 * 0.58 * ((1.0 - r) ** 1.7)))
            if a > 0:
                o = x * 4
                rows[y][o:o + 4] = bytes((255, 255, 255, a))
    pixeltools.encode(dst_pool, pw, phh, rows)
    print("glow  %s %dx%d   %s %dx%d  (white, tinted by _light())"
          % (dst_cone, cw, chh, dst_pool, pw, phh))


def pixeltools_scatter(i: int, span: float) -> float:
    """`StationRoom._scatter`, so stars land where the room puts them."""
    return (i * 2654435761.0 / 65536.0) % span


def cmd_init(src: str, dst: str, lab: bool) -> None:
    """The procedural deck, cropped to its panel and halved, as an init frame.

    TWO HALVINGS, not one: the screenshot is the window at 2x, so the first
    halving only gets back to game pixels and the second is the one that makes a
    half-size plate. Then 1 column off each side, because 370 is not divisible
    by 4 and pixflux refuses it; `cmd_plate` pads them back.
    """
    pw, ph = panel_of(lab)
    w, h, px = pixeltools.decode(src)
    x0, y0 = PANEL_AT[0] * 2, PANEL_AT[1] * 2
    shot = [bytearray(px[y0 + y][x0 * 4:(x0 + pw * 2) * 4]) for y in range(ph * 2)]
    gw, gh, game = _halve(pw * 2, ph * 2, shot)          # -> the panel, 740x431
    hw, hh, half = _halve(gw, gh, game)                  # -> 370x215
    out = []
    for row in half:
        out.append(bytearray(row[1 * 4:(hw - 1) * 4]))   # -> 368 wide
    while len(out) % 4:                                  # -> a height div by 4
        out.append(bytearray(out[-1]))
    pixeltools.encode(dst, hw - 2, len(out), out)
    print("init  %s -> %s  %dx%d  (panel %dx%d)"
          % (src, dst, hw - 2, len(out), pw, ph))


def cmd_plate(src: str, dst: str, lab: bool) -> None:
    """A generated half-plate, doubled and edge-padded back to the panel."""
    pw, ph = panel_of(lab)
    w, h, px = pixeltools.decode(src)
    dw, dh, big = _double(w, h, px)
    out = []
    for y in range(ph):
        row = big[min(y, dh - 1)]
        nr = bytearray()
        for x in range(pw):
            # Repeat the edge column over the 2px the init crop took off each
            # side. The wall runs to the panel edge, so a repeat is invisible.
            sx = min(max(x - 2, 0), dw - 1)
            nr.extend(row[sx * 4:sx * 4 + 4])
        out.append(nr)
    pixeltools.encode(dst, pw, ph, out)
    print("plate %s (%dx%d) -> %s  %dx%d" % (src, w, h, dst, pw, ph))


def cmd_trim(dst: str, lab: bool, deck: str) -> None:
    """The livery layer, authored rather than generated.

    `_tint` lerps this 0.18 toward the manufacturer colour and leaves the walls
    alone, so the joints and the floor courses ARE the livery. Drawing them from
    the code's own pitches puts the orange exactly where the room expects it.
    """
    pw, ph = panel_of(lab)
    floor_y = int(ph - floor_of(lab))
    rows = [bytearray(pw * 4) for _ in range(ph)]

    def hline(y: int, x0: int, x1: int) -> None:
        if 0 <= y < ph:
            for x in range(max(0, x0), min(pw, x1)):
                rows[y][x * 4:x * 4 + 4] = bytes(EDGE)

    def vline(x: int, y0: int, y1: int, thick: int = 1) -> None:
        for xx in range(x, min(pw, x + thick)):
            for y in range(max(0, y0), min(ph, y1)):
                rows[y][xx * 4:xx * 4 + 4] = bytes(EDGE)

    y = JOINT_Y0
    while y < floor_y - 8:
        hline(y, 0, pw)
        y += JOINT_DY
    x = JOINT_X0
    while x < pw - 20:
        vline(x, 0, floor_y, 2)
        x += JOINT_DX
    # The junction line, then the courses widening toward the viewer.
    hline(floor_y, 0, pw)
    hline(floor_y + 1, 0, pw)
    fy, gap = floor_y + COURSE_Y0, float(COURSE_GAP0)
    while fy < ph - 2:
        hline(int(fy), 0, pw)
        gap += COURSE_GROW
        fy += gap
    if deck == "stock":
        # The shop's letterbox frame: Rect2(26, 16, w-52, 52), 2px.
        for t in range(2):
            hline(16 + t, 26, pw - 26)
            hline(16 + 52 - 1 - t, 26, pw - 26)
        vline(26, 16, 68, 2)
        vline(pw - 28, 16, 68, 2)
    elif deck == "hold":
        # The crane rail at y=18, and the shutter's posts.
        for t in range(5):
            hline(18 + t, 0, pw)
        dx, dw = int(pw * 0.40), int(pw * 0.19)
        vline(dx - 6, 32, floor_y, 6)
        vline(dx + dw, 32, floor_y, 6)
    n = sum(1 for r in rows for x in range(pw) if r[x * 4 + 3])
    pixeltools.encode(dst, pw, ph, rows)
    print("trim  %s  %dx%d  %d lit px  (deck=%s)" % (dst, pw, ph, n, deck))


def _row_energy(a):
    """How different each row is from the next, averaged across the width."""
    import numpy as np
    d = np.abs(a[1:, :, :3].astype(int) - a[:-1, :, :3].astype(int)).mean(axis=(1, 2))
    return np.concatenate([d, [1e9]])


def _pick_rows(e, n, lo, hi):
    """The n flattest rows in [lo, hi), kept apart where the wall allows."""
    order = sorted(range(lo, hi), key=lambda y: e[y] + e[y - 1])
    for gap in (4, 2, 1):
        got = []
        for y in order:
            if all(abs(y - g) >= gap for g in got):
                got.append(y)
            if len(got) == n:
                return got
    # A wall with fewer flat rows than it needs: repeat the flattest again.
    return (order * (n // max(1, len(order)) + 1))[:n]


def _extend_floor(f, n_out):
    """More deck below the bottom row, in the floor's own perspective.

    Every row of a receding floor is the row above it seen closer: the same
    lines, spread wider about the vanishing point. So the vanishing point is
    FOUND -- the (x, horizon) that best predicts the bottom row from one 24
    rows up -- and the new rows are the bottom row spread by the same rule.
    Plank edges run on straight, and grain follows the boards.
    """
    import numpy as np
    n_in, w = f.shape[0], f.shape[1]
    if n_out <= n_in:
        return f[:n_out]
    lum = f[:, :, :3].astype(float) @ [0.299, 0.587, 0.114]
    r1, r2 = n_in - 25, n_in - 1
    xs = np.arange(w)
    best = None
    for yh in range(-900, -4, 8):
        for xv in range(0, w, 10):
            src = np.clip(np.round(xv + (xs - xv) * (r1 - yh) / (r2 - yh)), 0, w - 1).astype(int)
            loss = np.abs(lum[r1][src] - lum[r2]).mean()
            if best is None or loss < best[0]:
                best = (loss, yh, xv)
    _, yh, xv = best
    out = [f]
    last = f[r2]
    for y in range(n_in, n_out):
        src = np.clip(np.round(xv + (xs - xv) * (r2 - yh) / (y - yh)), 0, w - 1).astype(int)
        out.append(last[src][None])
    print("      floor extended %d rows; vanishing point x %d, horizon %d rows above the deck"
          % (n_out - n_in, xv, -yh))
    return np.concatenate(out, axis=0)


def cmd_level(src: str, dst: str, corner: int, target: int = 353) -> None:
    """Move a plate's wall/floor corner to the room's floor line. No stretch.

    A PLATE WHOSE WALL PICTURE DREW ITS OWN FLOOR meets the deck high: reactor
    at 315, crate at 329, while props, doors and walkers all stand on 353. So
    every room's corner is put on one row.

    Down (corner too high): the wall needs more rows, and they are the wall's
    FLATTEST rows repeated -- rows equal to their neighbours, inside a plain
    panel, where one more is invisible -- and the nearest deck rows come off
    the bottom. Up (corner too low): the flattest wall rows come out, and the
    deck is carried on in its own perspective (`_extend_floor`).
    `corner` is the first row of floor, measured by eye: the shadow line at
    the join belongs to the wall.
    """
    import numpy as np
    w, h, rows = pixeltools.decode(src)
    a = np.frombuffer(b"".join(bytes(r) for r in rows), np.uint8).reshape(h, w, 4)
    floor_n = h - target
    wall = a[:corner]
    if corner < target:
        e = _row_energy(wall)
        extra = {}
        for y in _pick_rows(e, target - corner, 2, corner - 8):
            extra[y] = extra.get(y, 0) + 1
        wall = np.concatenate([np.repeat(wall[y:y + 1], 1 + extra.get(y, 0), axis=0)
                               for y in range(corner)], axis=0)
        floor = a[corner:corner + floor_n]
    elif corner > target:
        e = _row_energy(wall)
        drop = set(_pick_rows(e, corner - target, 2, corner - 8))
        wall = wall[[y for y in range(corner) if y not in drop]]
        floor = _extend_floor(a[corner:], floor_n)
    else:
        floor = a[corner:]
    out = np.concatenate([wall, floor], axis=0)
    assert out.shape[0] == h, out.shape
    pixeltools.encode(dst, w, h, [bytes(r) for r in out.reshape(h, -1)])
    print("level %s  corner %d -> %d  (%s %d wall rows)" % (
        os.path.basename(dst), corner, target,
        "repeated" if corner < target else "removed", abs(target - corner)))


def _seam_guess(w, h, rows):
    """Where a one-picture room probably turns from wall to floor: the biggest
    step in row brightness between 55% and 92% of the way down. A GUESS -- a
    baseboard or a painted light pool can win it -- so every corner is checked
    by eye before it is used."""
    means = [sum(_lum(r[x * 4], r[x * 4 + 1], r[x * 4 + 2]) for x in range(w)) / w for r in rows]
    best, at = -1.0, int(h * 0.8)
    for y in range(int(h * 0.55), int(h * 0.92)):
        d = abs((means[y] + means[y + 1]) - (means[y - 2] + means[y - 1]))
        if d > best:
            best, at = d, y
    return at


def _unlight(part, w):
    """The generator's own light pool divided out of one band (see flatten)."""
    ph = len(part)
    if ph < 8:
        return part
    lum = [[_lum(r[x * 4], r[x * 4 + 1], r[x * 4 + 2]) for x in range(w)] for r in part]
    blur = _box_blur_lum(lum, w, ph, max(8, min(w, ph) // 4))
    mean = sum(sum(r) for r in lum) / float(w * ph)
    for y in range(ph):
        for x in range(w):
            g = min(2.0, max(0.5, mean / max(1.0, blur[y][x])))
            o = x * 4
            for i in range(3):
                part[y][o + i] = max(0, min(255, int(round(part[y][o + i] * g))))
    return part


def cmd_seat(src: str, dst: str, corner: int = -1, target: int = 353) -> None:
    """One generated room, its own corner put on the floor line. Crop only.

    EVERY ROOM MEETS THE FLOOR ON THE SAME ROW (Jon, 2026-09-25), so any
    backdrop can stand behind any room and the walkers stay on its floor.

    The room is generated TALL -- 372x300, wall and floor in one picture, which
    is what keeps them cohesive -- and doubled, so there is room above and below
    the corner to crop 740x431 with the corner's first floor row landing on
    exactly `target`. That needs the corner between 59% and 87% of the way down;
    outside that the take is refused rather than filled or stretched.

    The light pool the generator paints is divided out of the wall and the floor
    separately, and the whole plate pulled into the room's value range -- the
    treatment every kept plate had. `corner` is the first row of floor at 1x;
    leave it out for a guess, which must then be checked by eye.
    """
    w, h, rows = pixeltools.decode(src)
    pw, ph = PANEL
    if corner < 0:
        corner = _seam_guess(w, h, rows)
        print("      corner guessed at %d -- CHECK IT BY EYE" % corner)
    top = 2 * corner - target
    # UP TO 3 ROWS SHORT AT THE BOTTOM IS ALLOWED, and those rows repeat the
    # last one: the corner stays exact, and the bottom edge of the deck is
    # under the rack and the till. More than that is a smear, so it refuses.
    short = max(0, 2 * corner + (ph - target) - 2 * h)
    if top < 0 or short > 3:
        raise SystemExit("seat: corner %d of %d leaves no room to crop %dx%d with "
                         "it on row %d (needs %d..%d)" % (
                             corner, h, pw, ph, target,
                             (target + 1) // 2, h - (ph - target + 1) // 2))
    rows = [bytearray(r) for r in rows]
    rows = _unlight(rows[:corner], w) + _unlight(rows[corner:], w)
    _fit_value(rows, w, h, _lum(*WALL) * 1.1)
    dw, dh, big = _double(w, h, rows)
    x0 = (dw - pw) // 2
    out = [bytearray(big[min(y, dh - 1)][x0 * 4:(x0 + pw) * 4]) for y in range(top, top + ph)]
    if short:
        print("      bottom %d row(s) repeat the last one (corner kept exact)" % short)
    pixeltools.encode(dst, pw, ph, out)
    print("seat  %s  corner %d -> row %d  (%dx%d from %dx%d, %s)"
          % (os.path.basename(dst), corner, target, pw, ph, dw, dh,
             "nothing filled" if not short else "%d bottom row(s) repeated" % short))


def cmd_unletter(src: str, dst: str, boxes: list) -> None:
    """Lettering painted out of a generated backdrop, sign by sign.

    THE GENERATOR WRITES NONSENSE WORDS ("PRICE PICLE", "SALLEOM"), and a word
    is the one thing in a far-off view the eye tries to read, so it reads as
    wrong. The sign stays; only its letters go. A sign with a backing plate
    (its commonest colour fills a third of the box or more) gets its letters
    in the plate's colour -- a clean plate. Lettering glowing straight on the
    wall becomes a block of its own average glow: a lit sign too far off to
    read. `boxes` are x,y,w,h in the picture's own pixels.
    """
    from collections import Counter
    w, h, rows = pixeltools.decode(src)
    rows = [bytearray(r) for r in rows]
    for (bx, by, bw, bh) in boxes:
        px = [(x, y) for y in range(max(0, by), min(h, by + bh)) for x in range(max(0, bx), min(w, bx + bw))]
        if not px:
            continue
        cols = [tuple(rows[y][x * 4:x * 4 + 3]) for x, y in px]
        mode, n = Counter(cols).most_common(1)[0]
        if n >= 0.35 * len(cols):
            fill = mode
        else:
            fill = tuple(int(round(sum(c[i] for c in cols) / len(cols))) for i in range(3))
        for x, y in px:
            rows[y][x * 4:x * 4 + 3] = bytes(fill)
    pixeltools.encode(dst, w, h, rows)
    print("unletter  %s  %d sign(s)" % (os.path.basename(dst), len(boxes)))


if __name__ == "__main__":
    a = sys.argv[1:]
    lab = "--lab" in a
    a = [x for x in a if x != "--lab"]
    deck = "stock"
    if "--deck" in a:
        i = a.index("--deck")
        deck = a[i + 1]
        a = a[:i] + a[i + 2:]
    level = "city"
    if "--level" in a:
        i = a.index("--level")
        level = a[i + 1]
        a = a[:i] + a[i + 2:]
    if not a:
        print(__doc__)
    elif a[0] == "room":
        cmd_room(a[1], lab, deck, level)
    elif a[0] == "build":
        cmd_build(a[1], a[2], a[3], lab, deck, level)
    elif a[0] == "glow":
        cmd_glow(a[1], a[2])
    elif a[0] == "hood":
        cmd_hood(a[1], a[2])
    elif a[0] == "view":
        cmd_view(a[1], a[2])
    elif a[0] == "frames":
        cmd_frames(a[1])
    elif a[0] == "shelf_init":
        cmd_shelf_init(a[1])
    elif a[0] == "counter_init":
        cmd_counter_init(a[1])
    elif a[0] == "window_styles":
        cmd_window_styles(a[1])
    elif a[0] == "backdrop":
        cmd_backdrop(a[1], a[2])
    elif a[0] == "despeckle":
        cmd_despeckle(a[1])
    elif a[0] == "unletter":
        cmd_unletter(a[1], a[2], [tuple(int(v) for v in b.split(",")) for b in a[3:]])
    elif a[0] == "seat":
        cmd_seat(a[1], a[2], int(a[3]) if len(a) > 3 else -1)
    elif a[0] == "level":
        cmd_level(a[1], a[2], int(a[3]))
    elif a[0] == "compose":
        cmd_compose(a[1], a[2])
    elif a[0] == "unsmear":
        cmd_unsmear(a[1])
    elif a[0] == "decks":
        cmd_decks(a[1])
    elif a[0] == "openings":
        cmd_openings(a[1], a[2])
    elif a[0] == "ports":
        cmd_ports(a[1])
    elif a[0] == "shop_art":
        cmd_shop_art(a[1])
    elif a[0] == "furniture":
        cmd_furniture(a[1], a[2], int(a[3]), int(a[4]))
    elif a[0] == "flatten":
        cmd_flatten(a[1], a[2], int(a[3]) if len(a) > 3 else 0)
    elif a[0] == "init":
        cmd_init(a[1], a[2], lab)
    elif a[0] == "plate":
        cmd_plate(a[1], a[2], lab)
    elif a[0] == "trim":
        cmd_trim(a[1], lab, deck)
    else:
        print(__doc__)
