"""The fifteen shop rooms, all of them Jon's, and the grammar they were built by.

    python tools/room_compose.py      # writes tools/room_stage/layouts_levels.json

ALL FIFTEEN ARE HIS (2026-09-27, "Capital are in."). Level by level he touched
up what this composed and sent it back, and each round's changes were carried
to the levels he had not reached; the capital was the last. This now seeds the
bench with his rooms exactly as exported, and keeps the grammar -- the notes
below and the checks, calibrated on his rooms -- for any room added later.

Supersedes tools/layout_gen.py for the level rooms (its output moved aside).

JON'S THREE UNCLAIMED ROOMS ARE THE REFERENCE (his second export, 2026-09-26:
"I hope this gives you a better idea of how I am designing these spatially").
They are copied verbatim. Set against the versions they replaced, his edits
took OUT the small filler -- boarded panels, notices, valves, candles, tyres,
a mattress -- and put IN a second window, a bigger counter, and two identical
lamps where they light something. Measured, every one of the three does this:

  * THREE OR FOUR BIG BLOCKS -- the rack, the one way in, a window or hatch --
    set nearly edge to edge. The rack touches its neighbour or overlaps it.
  * THE RACK'S TOP LINES UP with the top of the tallest opening in the room
    (scrap 113 against a window at 105, closet 91 against the arch's 108,
    plywood 70 against the hatch's 80). Its foot follows: 374 to 417.
  * THE COUNTER STANDS IN FRONT OF A WINDOW OR HATCH, at 125%, its top within
    about 30px of that opening's bottom edge (a hatch's sill it overlaps),
    its foot at 417-424, in front of everything else.
  * TWO LAMPS, ONE FIXTURE, ONE COLOUR, one each side of the room: in his
    unclaimed rooms over the rack and over the counter (one failing), in his
    outposts on the side walls. A level may add one accent lamp.
  * The gaps between blocks are 40-100px and hold ONE SMALL COLUMN: a
    junction box over an extinguisher, a box over the hard hats.
  * THE CEILING: pipes in the corners, a vent, one thing hanging.
  * THE FLOOR: two pieces. One at the rack's foot, half behind a post, clear
    of the stock; one in a corner or beside the way in. He pushes these to
    the wall band, so they sit behind the furniture and cast no shadow.
  * 13 to 15 things in all, and two or three openings.

HIS OUTPOSTS FOLLOWED ("outposts done", the same day), and are copied verbatim
too. What he changed in mine: every tall standing thing -- lockers, two water
coolers -- went back against the wall (see BACK), behind the rack and counter;
the work lights moved from the ceiling onto the side walls, with a cage lamp at
each edge; two of the three coloured accents went (one alarm stays); dither
went off in all six of his rooms; a tool chest, a water cooler and a hanging
plant came in.

HIS SETTLEMENTS FOLLOWED ("settlements done", 2026-09-27), verbatim as well.
What he changed in mine: every small thing on the floor went to the wall band,
the cats included (one now sits between the quilted rack's legs); the plant and
the baskets came down from 150% to 125%; the bunting moved to the middle of the
room, between the lamps, and the drying herbs over a rack; racks, windows and
the vitrine went higher; quilt's window became tall and narrow.

HIS CITY FOLLOWED ("City in.", 2026-09-27), verbatim too: the LED tray moved
from the ceiling onto the top of each glass case, a lit crown; the last pink
accent lamp went (with the outposts' alarm already turned white, no level keeps
a coloured accent); the lanterns hang from the ceiling edge; the racks went up;
a security camera went into a top corner of every room, and a screen over the
panels door.

Capital follows all of that -- its gold crown already does what the tray does,
it had no accent to lose, and its cases went up 10px -- in three block orders
taken from his rooms and their mirrors. The velvet ropes alone stay on the floor band:
they exist to stand in front of the case, and behind it they would vanish. Development changes what fills them: outpost is
cold work light and utility; settlement warm and homely; city neon; capital
bright, polished and gilded. The dust thins as the levels rise.

SIZE. Props are doubled art, and the bench scales one in steps; 1.5 and 2 keep
every art pixel whole. The counters stand at 125% as his do (the settlement
stall was drawn at that width already).
"""
import io
import json
import os
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
STAGE = os.path.join(HERE, "room_stage")
STATION = os.path.join(HERE, "..", "tkg", "art", "sprites", "station")
# Jon's own export from the bench (2026-09-26, the second): his three unclaimed
# rooms are taken from it verbatim.
JON = os.path.join(STAGE, "room-layouts.json")
OUT = os.path.join(STAGE, "layouts_levels.json")
W, H, FLOOR = 740, 431, 353
NL = chr(10)


def png(path):
    with open(path, "rb") as f:
        h = f.read(24)
    return struct.unpack(">II", h[16:24])


PROPS, LAMPS, RACKS, TILLS, OPENS = {}, {}, {}, {}, {}
for f in os.listdir(STAGE):
    p = os.path.join(STAGE, f)
    if f.startswith("prop_") and f.endswith(".png"):
        layer, name = f[5:-4].split("_", 1)
        PROPS[name] = (png(p), layer)
    elif f.startswith("lampskin_"):
        LAMPS[f[9:-4]] = png(p)
    elif f.startswith("rack2_"):
        w, h = png(p)
        RACKS[f[6:-4]] = (w * 2, h * 2)
    elif f.startswith("till_"):
        TILLS[f[5:-4]] = png(p)
# A crown above the body, px on the wall: a rack lines up with the openings
# by its cornice, not by the top of its crown. (None now: the crowned hutch
# was redrawn as the quilted rack, which has a flat rail.)
RACK_CROWN = {}
# Board rows at 1x, where a rack style has its own (tools/furniture_seat.py).
RACK_BOARDS = {}
if os.path.exists(os.path.join(STAGE, "rack_boards.json")):
    RACK_BOARDS = json.load(io.open(os.path.join(STAGE, "rack_boards.json"), encoding="utf-8"))
for name, e in json.load(io.open(os.path.join(STATION, "opening_holes.json"), encoding="utf-8")).items():
    OPENS[name] = (e["w"], e["h"])
OPENS.setdefault("strip", (360, 120))
# Where each opening's frame is drawn inside its picture (x0, y0, x1, y1),
# measured from the art: the picture has clear margins, and the rack lines up
# with the frame, not the picture.
OPEN_INK = {
    "angled": (26, 8, 277, 205), "arch": (18, 14, 223, 287), "bay": (10, 10, 271, 183),
    "breach": (22, 18, 251, 219), "canopy": (94, 26, 225, 195), "clerestory": (0, 2, 397, 95),
    "cracked": (32, 4, 249, 197), "double": (40, 24, 359, 235), "grid": (0, 4, 319, 239),
    "hex": (4, 6, 235, 237), "rail": (0, 0, 359, 179), "roundbig": (14, 10, 251, 257),
    "shutter": (4, 10, 275, 229), "slot": (0, 0, 119, 311), "strip": (4, 6, 355, 115),
    "vitrine": (6, 8, 231, 187),
}
WAYS_IN = ("arch",)          # an opening you walk through; the rest are windows


def _cut_openings():
    """The openings Jon cut, read out of room_bench.py. The bench build drops a
    seeded item that stands on one, so a room built on it loses a window
    without a word -- three did, the first time this composer ran."""
    import ast
    src = io.open(os.path.join(HERE, "room_bench.py"), encoding="utf-8").read()
    for node in ast.parse(src).body:
        if isinstance(node, ast.Assign) and getattr(node.targets[0], "id", "") == "CUT_OPENINGS":
            return set(ast.literal_eval(node.value))
    return set()


CUT_OPENINGS = _cut_openings()
# AND OF THE ONES LEFT, only four: "shutter, vitrine, slot, and arch are the
# only openings that look good" (Jon), and later "no hex opening". A window
# anywhere else is a framed window (chamfer, round, octa).
GOOD_OPENINGS = ("shutter", "vitrine", "slot", "arch")

# Free-standing things a person stands next to; clutter is not listed.
SCALE = {
    "vend_a": 1.5, "vend_b": 1.5, "city_arcade": 1.5, "city_atm": 1.5,
    "plant_a": 1.5, "plant_b": 1.5, "city_palm": 1.5,
    "capital_bust": 1.5, "capital_clock": 1.5,
    "outpost_sacks": 1.5, "cabledrum": 1.5, "unclaimed_trashbags": 1.5,
    "unclaimed_crt": 1.5, "settlement_baskets": 1.5, "settlement_grain": 1.5,
    "city_stools": 1.5, "city_neon": 1.5,
}
# Jon stands his counters at 125% (all three unclaimed rooms). The settlement
# stall was drawn at that width already, so it stays whole.
TILL_SCALE = {"unclaimed": 1.25, "outpost": 1.25, "city": 1.25, "capital": 1.25}


def psize(pid, scale):
    (w, h), _ = PROPS[pid]
    return int(round(w * scale)), int(round(h * scale))


def prop(pid, x, y=None, bottom=None, layer=None, fx=False, scale=None):
    s = SCALE.get(pid, 1) if scale is None else scale
    w, h = psize(pid, s)
    if bottom is not None:
        y = bottom - h
    o = {"type": "prop", "id": pid, "x": int(x), "y": int(y), "layer": layer or PROPS[pid][1]}
    if s != 1:
        o["scale"] = s
    if fx:
        o["fx"] = True
    return o


def ceiling(pid, x, y=0, fx=False):
    """Pipes, vents, trays and anything hung from the deckhead: on the wall
    band, as Jon has every one of his."""
    return prop(pid, x, y, layer="wall", fx=fx)


def foot(pid, x, bottom, scale=None):
    """A small thing on the floor, on the wall band as Jon puts his: behind the
    furniture, with no shadow of its own. KEEP IT MOSTLY CLEAR OF A LEVEL RACK:
    those have solid bases, so one tucked behind is simply gone (his crate and
    wire racks have open legs, which is why his tucked props still show)."""
    return prop(pid, x, bottom=bottom, layer="wall", scale=scale)


def stand(pid, x, bottom, scale=None):
    """A big free-standing thing -- lockers, a vending machine, a bust -- that
    stands on the deck and casts a shadow."""
    return prop(pid, x, bottom=bottom, layer="floor", scale=scale)


# THE BACK ROW. His outposts moved every tall standing thing -- the lockers, both
# water coolers -- back against the wall, feet on 356, on the wall band, so the
# rack and the counter stand in front of them. The small clutter stays forward.
BACK = 356


def back(pid, x, scale=None):
    """Something tall that stands against the wall: lockers, a vending machine,
    a bust on its plinth, a potted plant."""
    return prop(pid, x, bottom=BACK, layer="wall", scale=scale)


def lamp(skin, cx, col, pow=1.0, reach=700, glass=1.0, flick=None, y=0):
    w, h = LAMPS[skin]
    o = {"type": "lamp", "skin": skin, "x": int(round(cx - w / 2.0)), "y": y, "col": col,
         "pow": pow, "reach": reach, "glass": glass, "placed": True}
    if flick:
        o["flick"] = flick
    return o


def lamps(skin, col, xs, pow=1.0, reach=750, flicker=None):
    """The room's two lamps: one fixture, one colour, one over the rack and one
    over the counter. `flicker` is {index: fault} for one that is failing."""
    flicker = flicker or {}
    return [lamp(skin, x, col, pow=pow, reach=reach, flick=flicker.get(i)) for i, x in enumerate(xs)]


def shelf(skin, x, top):
    """The rack, its top set level with the tallest opening's."""
    return {"type": "shelf", "x": x, "y": top, "boards": 2, "skin": skin}


def till(skin, x, bottom=420):
    s = TILL_SCALE.get(skin, 1)
    w, h = TILLS[skin]
    o = {"type": "till", "x": x, "y": bottom - int(round(h * s)), "skin": skin}
    if s != 1:
        o["scale"] = s
    return o


def door(skin, x):
    return {"type": "door", "skin": skin, "x": x, "y": FLOOR - 190, "w": 56, "h": 190}


def opening(skin, x, y):
    return {"type": "open", "skin": skin, "x": x, "y": y}


def window(x, y, w, h, style="chamfer"):
    return {"type": "window", "style": style, "x": x, "y": y, "w": w, "h": h}


def room(level, name, wall, backdrop, amb, motes, items):
    return {"name": "%s · %s" % (level, name), "levels": [level],
            "room": {"wall": wall, "floor": "current"},
            "backdrop": {"id": backdrop, "auto": True},
            # dither off: he turned it off in all six of his rooms
            "light": {"amb": amb, "shadowk": 0.55, "dither": False, "shadows": True, "contact": True},
            "air": {"people": 1, "motes": motes},
            "items": items}


# ------------------------------------------------------------ the levels' kit
O_WORK, O_ALARM, O_AMBER = "#e8eef8", "#ff4a3a", "#ff9a3c"
S_WARM = "#ffc27a"
C_TEAL, C_PINK = "#7fe3ff", "#ff7ad9"
K_WHITE = "#fff1dc"
# LIGHT CLIMBS WITH THE LEVEL. His settlements came back brighter than my city
# (their lanterns at 1.28, the quilted rack a bright mustard), so city and
# capital were lifted to stay above them; he kept city's 1.6.
CAPITAL_POW = 2.0
# The dust thins as a level is cleaned up. Unclaimed is Jon's 400.
MOTES = {"outpost": 280, "settlement": 200, "city": 120, "capital": 60}

ROOMS = []

# ------------------------------------------------------------ all five levels
# His, exactly as exported: the unclaimed three, the outposts he touched up
# (2026-09-26, "outposts done"), the settlements (2026-09-27, "settlements
# done"), the city ("City in.") and the capital ("Capital are in."). Two things
# are settled on the way in, so the
# seed matches the tab he has and the bench does not add a copy of it:
#   * a tab the bench kept as "<name> (new)" -- his edit went into the copy --
#     is seeded under its own name, and the bench gives the copy its name back;
#   * a door with a skin stands on the floor, where the bench puts it on load.
# And what he asked for since the export:
ASKED = {}   # e.g. {"outpost · modular": [("door", {"skin": "blast_a"})]} -- done in his own export now
jon = json.load(io.open(JON, encoding="utf-8"))
for l in jon["layouts"]:
    if l["name"].split(" · ")[0] not in ("unclaimed", "outpost", "settlement", "city", "capital"):
        continue
    l = json.loads(json.dumps(l))
    l["name"] = l["name"].replace(" (new)", "")
    l["backdrop"] = {"id": l["backdrop"]["id"], "auto": True}
    for o in l["items"]:
        for kind, change in ASKED.get(l["name"], []):
            if o["type"] == kind:
                o.update(change)
        if o["type"] == "door" and o.get("skin"):
            o["y"], o["w"], o["h"] = FLOOR - 190, 56, 190
    assert l["name"] not in [r["name"] for r in ROOMS], l["name"]
    ROOMS.append(l)

# ------------------------------------------------------------------ checks
def rect(o):
    t = o["type"]
    k = o.get("scale", 1)
    if t == "prop":
        (w, h), _ = PROPS[o["id"]]
        return o["x"], o["y"], int(round(w * k)), int(round(h * k))
    if t == "lamp":
        w, h = LAMPS[o["skin"]]
        return o["x"], o["y"], w, h
    if t == "shelf":
        w, h = RACKS[o["skin"]]
        return o["x"], o["y"], w, h
    if t == "till":
        w, h = TILLS[o["skin"]] if o.get("skin") in TILLS else (180, 128)
        return o["x"], o["y"], int(round(w * k)), int(round(h * k))
    if t == "door":
        return o["x"] - 12, o["y"] - 12, 80, 202
    if t == "open":
        w, h = OPENS[o["skin"]]
        return o["x"], o["y"], w, h
    if t == "window":
        return o["x"] - 12, o["y"] - 12, o["w"] + 24, o["h"] + 24


def frame(o):
    """The drawn frame of an opening, door or window: (x0, y0, x1, y1)."""
    if o["type"] == "open":
        ix0, iy0, ix1, iy1 = OPEN_INK[o["skin"]]
        return o["x"] + ix0, o["y"] + iy0, o["x"] + ix1, o["y"] + iy1
    x, y, w, h = rect(o)
    return x, y, x + w, y + h


def overlap(a, b):
    ax, ay, aw, ah = a
    bx, by, bw, bh = b
    return max(0, min(ax + aw, bx + bw) - max(ax, bx)), max(0, min(ay + ah, by + bh) - max(ay, by))


def check(l):
    bad = []
    items = l["items"]
    ways = [o for o in items if o["type"] == "door" or (o["type"] == "open" and o["skin"] in WAYS_IN)]
    wins = [o for o in items if o["type"] == "window" or (o["type"] == "open" and o["skin"] not in WAYS_IN)]
    if len(ways) != 1:
        bad.append("%d ways in" % len(ways))
    if len(wins) > 2:
        bad.append("%d windows" % len(wins))
    for o in items:
        if o["type"] == "open" and o["skin"] in CUT_OPENINGS:
            bad.append("the %s opening was cut" % o["skin"])
        elif o["type"] == "open" and o["skin"] not in GOOD_OPENINGS:
            bad.append("the %s opening is not one Jon likes" % o["skin"])
    for o in items:
        x, y, w, h = rect(o)
        if o["type"] == "open":
            x0, y0, x1, y1 = frame(o)
            x, y, w, h = x0, y0, x1 - x0, y1 - y0
        if x < -12 or x + w > W + 12 or y + h > H + 1:
            bad.append("%s %s off the wall" % (o["type"], o.get("id", o.get("skin", ""))))
    standing = [o for o in items if (o["type"] == "prop" and o.get("layer") == "floor") or o["type"] == "till"]
    for way in ways:
        wr = rect(way)
        for o in standing:
            ox, oy = overlap(wr, rect(o))
            if ox > 0.25 * wr[2] and rect(o)[1] + rect(o)[3] > FLOOR:
                bad.append("%s stands in the way in" % o.get("id", "till"))
    # the stock stays in view: each board's parts stand up to 40 art px (80
    # on the wall) above it, and the tags hang 11 (22) below it. Only what is
    # drawn in front of the rack can hide it.
    racks = [o for o in items if o["type"] == "shelf"]
    for sh in racks:
        sx, sy = sh["x"], sh["y"]
        after = items[items.index(sh) + 1:]
        front = [o for o in standing if o in after or o["type"] == "till"] + \
                [o for o in items if o["type"] == "prop" and o.get("layer") == "near"]
        for b in RACK_BOARDS.get(sh.get("skin"), (59, 122)):
            zone = (sx + 24, sy + 2 * b - 80, 184, 102)
            for o in front:
                ox, oy = overlap(zone, rect(o))
                if ox > 4 and oy > 4:
                    bad.append("%s covers the stock (%dx%d)" % (o.get("id", "till"), ox, oy))
    # HIS GRAMMAR. The rack's top level with the tallest opening's
    tops = [frame(o)[1] for o in ways + wins]
    for sh in racks:
        # his twelve rooms put it from 32px above the tallest opening's top
        # (city panels) to 40px below it (the settlements hang theirs lowest)
        body = sh["y"] + RACK_CROWN.get(sh.get("skin"), 0)
        if tops and not -35 <= body - min(tops) <= 45:
            bad.append("rack top %d, tallest opening %d" % (body, min(tops)))
    # the counter in front of a window or hatch, its top near that one's foot
    tills = [o for o in items if o["type"] == "till"]
    for t in tills:
        tx, ty, tw, th = rect(t)
        fronted = False
        for wn in wins:
            x0, y0, x1, y1 = frame(wn)
            share = max(0, min(tx + tw, x1) - max(tx, x0))
            if share >= 0.4 * tw and -45 <= ty - y1 <= 60:
                fronted = True
        if not fronted:
            bad.append("counter fronts no window")
        if not 404 <= ty + th <= 431:          # his twelve: 406 to 431
            bad.append("counter foot at %d" % (ty + th))
    # two lamps of one fixture, one over the rack and one over the counter,
    # and at most one accent
    kinds = {}
    for o in items:
        if o["type"] == "lamp":
            kinds.setdefault((o.get("skin"), o.get("col")), []).append(o)
    main = max(kinds.values(), key=len) if kinds else []
    if len(main) != 2 or len(kinds) > 2 or (len(kinds) == 2 and min(len(v) for v in kinds.values()) > 1):
        bad.append("lamps are not two of one fixture plus an accent: %s" %
                   {k: len(v) for k, v in kinds.items()})
    # one each side of the room. Over the rack and over the counter is how his
    # unclaimed rooms hang them; his outposts moved them to the side walls.
    cxs = [rect(o)[0] + rect(o)[2] / 2.0 for o in main]
    if cxs and not (min(cxs) < W / 2.0 <= max(cxs)):
        bad.append("both lamps on one side")
    if not 11 <= len(items) <= 16:
        bad.append("%d things" % len(items))
    cov = [[0] * W for _ in range(FLOOR)]
    for o in items:
        x, y, w, h = rect(o)
        for yy in range(max(0, y), min(FLOOR, y + h)):
            row = cov[yy]
            for xx in range(max(0, x), min(W, x + w)):
                row[xx] = 1
    covered = sum(map(sum, cov)) / float(W * FLOOR)
    return bad, covered


if __name__ == "__main__":
    out = []
    his = {x["name"].replace(" (new)", "") for x in jon["layouts"]}
    for l in ROOMS:
        bad, cov = check(l)
        # The checks are the composing grammar. His rooms are the ground truth,
        # so where one of his departs from it that is noted, not failed.
        verdict = ("his -- departs: " + "; ".join(bad)) if (bad and l["name"] in his) else ("; ".join(bad) or "ok")
        print("%-24s %2d items  %3d%% of the wall covered  %s" % (l["name"], len(l["items"]), 100 * cov, verdict))
        out.append(l)
    io.open(OUT, "w", encoding="utf-8", newline=NL).write(
        json.dumps(out, ensure_ascii=False, indent=1) + NL)
    print("wrote %d rooms to %s" % (len(out), OUT))
