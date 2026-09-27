"""Fifteen shop layouts, one per room of the per-level set (Jon, 2026-09-25).

    python tools/layout_gen.py        # writes tools/room_stage/layouts_levels_gen.json

SUPERSEDED (2026-09-26) by tools/room_compose.py, which writes the rooms the
bench seeds from. This one writes beside them so running it cannot overwrite
the composed set.

Each is a fit-out for one room plate: that plate as its wall, tagged with the
room's development level, a preview backdrop from the same level, and furniture,
openings, props and lamps chosen to read as that level --

    unclaimed   crate racks and tills, shutters and slots, clutter, sodium light,
                one lamp failing
    outpost     wire and peg racks, booth tills, work lights, tools and first aid
    settlement  crate and peg racks, brass tills, arches and bays, plants, lanterns

No hex opening anywhere (Jon, 2026-09-25).
    city        glass racks, the holo till, vitrines, vending, cold teal bars
    capital     glass racks, brass and holo, symmetry, little clutter, cold rings

Everything is placed by hand below and then CHECKED, the same rules the bench
warns on plus the ones it does not: openings may not touch each other or run off
the wall; nothing on the floor may overlap anything else on the floor or stand in
front of a door or a floor-length opening; a wall prop may not sit on an opening;
every opening must be covered by the preview backdrop at its set height. A
layout that breaks one fails the run -- the point is that none reaches the bench
needing a fix.
"""

import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
STATION = os.path.abspath(os.path.join(HERE, "..", "tkg", "art", "sprites", "station"))
OUT = os.path.join(HERE, "room_stage", "layouts_levels_gen.json")

W, H, FLOOR, T = 740, 431, 353, 12
SHELF_K = 2
OPEN = {"arch": (240, 300), "bay": (280, 200), "clerestory": (400, 96),
        "shutter": (280, 240), "slot": (120, 312), "vitrine": (240, 200)}
DOOR = (56, 190)                 # a skinned door: its art less the frame (doors raised 34px for doubled people)
RACK = (116 * SHELF_K, 152 * SHELF_K)
TILL = (180, 128)
PROPS = {"barrels": (52, 60, "floor"), "bin_a": (44, 68, "floor"), "cabledrum": (54, 56, "floor"),
         "chairtable": (58, 40, "floor"), "crates_a": (76, 76, "floor"), "fan": (48, 62, "floor"),
         "mopbucket": (30, 88, "floor"), "plant_a": (52, 80, "floor"), "plant_b": (54, 76, "floor"),
         "stepladder": (28, 90, "floor"), "tarpcrates": (76, 48, "floor"), "toolchest": (62, 48, "floor"),
         "tree": (46, 104, "floor"), "trolley_a": (44, 66, "floor"), "trolley_b": (56, 62, "floor"),
         "vend_a": (64, 122, "floor"), "vend_b": (60, 122, "floor"), "watercooler": (44, 102, "floor"),
         "caglamp": (32, 62, "wall"), "clock": (52, 52, "wall"), "extinguisher": (34, 80, "wall"),
         "firstaid": (44, 48, "wall"), "jarshelf": (84, 44, "wall"), "junction": (44, 48, "wall"),
         "notices": (64, 48, "wall"), "pegboard": (72, 46, "wall"), "pipes_a": (192, 36, "wall"),
         "screen_a": (80, 50, "wall"), "screen_b": (80, 46, "wall"), "valves": (96, 30, "wall"),
         "vent_a": (52, 54, "wall"), "vent_b": (52, 50, "wall")}
LAMPS = {"cage": (28, 52), "bulb": (24, 80), "worklight": (56, 58), "bulkhead": (44, 52),
         "flood": (66, 40), "lantern": (24, 66), "paper": (32, 68), "globe": (40, 76),
         "lightbar": (106, 12), "panel": (66, 28), "batten": (124, 14), "ring": (24, 56),
         "dome": (68, 62), "enamel": (60, 56)}

# The look of each level's light, and how many fixtures hang.
LIGHT = {"unclaimed": ("#ff9a3c", 2), "outpost": ("#e8eef8", 2), "settlement": ("#ffb457", 3),
         "city": ("#7fe3ff", 4), "capital": ("#e6f0ff", 5)}

# ONE WAY IN, AND AT MOST ONE WINDOW (Jon, 2026-09-26: "a smarter layout. one
# door or opening. maybe a window"). The entrance is a door or the arch; the
# window, when there is one, faces the concourse over the till, so the rack
# stands against the other end of the wall and the door clears both. Rooms of a
# level alternate hands, so the three do not read as one room mirrored.
#
# name, room, preview backdrop, lamp skin, openings [(skin, x, y)], door (skin, x) | None,
# rack (skin, x), till (skin, x), props [(id, x, y|None)], flicker lamp index | None
SPEC = [
 ("unclaimed · scrap", "unclaimed_scrap", "unclaimed_gutted14u", "cage",
  [("shutter", 400, 50)], ("shutter_a", 20), ("crate_a", 100), ("crate_a", 450),
  [("barrels", 350, None), ("junction", 680, 120)], 1),
 ("unclaimed · closet", "unclaimed_closet2b", "unclaimed_habtrash14u", "bulb",
  [], ("shutter_b", 664), ("crate_b", 420), ("crate_a", 60),
  [("mopbucket", 300, None), ("bin_a", 350, None), ("valves", 120, 80)], 0),
 ("unclaimed · plywood", "unclaimed_plywood5a", "unclaimed_pawn15u", "cage",
  [("shutter", 420, 50)], ("shutter_a", 300), ("crate_b", 20), ("crate_b", 470),
  [("cabledrum", 380, None), ("crates_a", 660, None), ("notices", 20, 60)], 1),

 ("outpost · prefab", "outpost_prefab", "outpost_junk8a", "worklight",
  [("bay", 330, 80)], ("slide_a", 660), ("wire_a", 40), ("booth_a", 380),
  [("trolley_b", 290, None), ("toolchest", 580, None), ("firstaid", 280, 90)], None),
 ("outpost · corrugated", "outpost_corrugated", "outpost_canteen11a", "flood",
  [("bay", 110, 80)], ("blast_a", 24), ("peg_a", 490), ("booth_b", 110),
  [("watercooler", 420, None), ("vent_a", 400, 64)], None),
 ("outpost · modular", "outpost_modular7a", "outpost_shack11a", "bulkhead",
  [], ("airlock_a", 340), ("wire_b", 20), ("booth_a", 520),
  [("cabledrum", 270, None), ("toolchest", 420, None), ("pegboard", 420, 110), ("junction", 600, 150)], None),

 ("settlement · quilt", "settlement_quilt", "settlement_homes9a", "lantern",
  [("arch", 250, 53)], None, ("crate_a", 10), ("brass_a", 280),
  [("plant_a", 520, None), ("chairtable", 600, None), ("clock", 560, 96), ("jarshelf", 60, 62)], None),
 ("settlement · timber", "settlement_timber", "settlement_noodle10a", "paper",
  [("vitrine", 330, 80)], ("slide_b", 660), ("peg_b", 30), ("brass_b", 360),
  [("plant_b", 580, None), ("jarshelf", 90, 62)], None),
 ("settlement · render", "settlement_render2b", "settlement_pharmacy10a", "globe",
  [("bay", 110, 80)], ("slide_b", 24), ("crate_b", 490), ("brass_a", 110),
  [("plant_a", 400, None), ("clock", 400, 70)], None),

 ("city · chevron", "city_chevron", "city_gates8a", "lightbar",
  [("vitrine", 40, 90)], ("slide_a", 400), ("glass_a", 490), ("holo_a", 70),
  [("vend_a", 300, None), ("screen_a", 290, 64)], None),
 ("city · ribbed", "city_ribbed", "city_bar11a", "lightbar",
  [("clerestory", 170, 24)], ("slide_b", 340), ("glass_b", 20), ("holo_a", 480),
  [("bin_a", 420, None), ("screen_b", 600, 150)], None),
 ("city · panels", "city_panels2a", "city_hotel11a", "panel",
  [], ("airlock_b", 660), ("glass_a", 30), ("holo_a", 420),
  [("vend_b", 300, None), ("screen_a", 300, 100)], None),

 ("capital · alloy", "capital_alloy", "capital_embassy8a", "ring",
  [("arch", 250, 53)], None, ("glass_a", 10), ("brass_b", 280),
  [("tree", 600, None), ("clock", 560, 100)], None),
 ("capital · stone", "capital_stone", "capital_bank6a", "dome",
  [], ("airlock_b", 342), ("glass_b", 20), ("holo_a", 490),
  [("clock", 344, 62)], None),
 ("capital · fluted", "capital_fluted2a", "capital_boutique9b", "enamel",
  [("bay", 250, 80)], ("blast_b", 640), ("glass_a", 10), ("brass_b", 300),
  [("plant_b", 244, None), ("tree", 560, None)], None),
]


def hit(a, b):
    return a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3]


def build():
    drops = json.load(io.open(os.path.join(STATION, "backdrop_drops.json"), encoding="utf-8"))
    out, bad = [], []
    for name, room, bd, lskin, opens, door, rack, till, props, flick in SPEC:
        level = room.split("_")[0]
        ways = (1 if door else 0) + sum(1 for sk, _, _ in opens if sk == "arch")
        if ways != 1:
            bad.append("%s: %d ways in -- one door or one arch" % (name, ways))
        if sum(1 for sk, _, _ in opens if sk != "arch") > 1:
            bad.append("%s: more than one window" % name)
        items, walls, floors, full = [], [], [], []
        top = FLOOR - 400 + drops[bd]           # the preview backdrop's top edge
        for skin, x, y in opens:
            w, h = OPEN[skin]
            r = (x, y, w, h)
            items.append({"type": "open", "skin": skin, "x": x, "y": y})
            if x < 0 or y < 0 or x + w > W or y + h > FLOOR:
                bad.append("%s: %s runs off the wall or below the floor" % (name, skin))
            if y < top:
                bad.append("%s: %s starts above %s (top %d)" % (name, skin, bd, top))
            walls.append((skin, r))
            if y + h >= FLOOR - 1:
                full.append((skin, r))
        if door:
            dx = door[1]
            items.append({"type": "door", "skin": door[0], "x": dx, "y": FLOOR - DOOR[1],
                          "w": DOOR[0], "h": DOOR[1]})
            r = (dx - T, FLOOR - DOOR[1] - T, DOOR[0] + 2 * T, DOOR[1] + T)
            if r[0] < 0 or r[0] + r[2] > W:
                bad.append("%s: the door's frame runs off the wall" % name)
            walls.append(("door", r))
            full.append(("door", (dx, FLOOR - DOOR[1], DOOR[0], DOOR[1])))
        for i in range(len(walls)):
            for j in range(i + 1, len(walls)):
                if hit(walls[i][1], walls[j][1]):
                    bad.append("%s: %s and %s overlap" % (name, walls[i][0], walls[j][0]))
        rr = (rack[1], H - RACK[1], RACK[0], RACK[1])
        items.append({"type": "shelf", "boards": 2, "skin": rack[0], "x": rack[1]})
        floors.append(("rack", rr))
        tr = (till[1], H - TILL[1], TILL[0], TILL[1])
        items.append({"type": "till", "skin": till[0], "x": till[1]})
        floors.append(("till", tr))
        for pid, x, y in props:
            w, h, layer = PROPS[pid]
            o = {"type": "prop", "id": pid, "x": x}
            if layer == "wall":
                o["y"] = y
                r = (x, y, w, h)
                for k, wr in walls:
                    if hit(r, wr):
                        bad.append("%s: %s sits on the %s" % (name, pid, k))
                for k, fr in floors:
                    if hit(r, fr):
                        bad.append("%s: %s is behind the %s" % (name, pid, k))
            else:
                floors.append((pid, (x, H - h, w, h)))
            if x < 0 or x + w > W:
                bad.append("%s: %s runs off the wall" % (name, pid))
            items.append(o)
        for i in range(len(floors)):
            for j in range(i + 1, len(floors)):
                if hit(floors[i][1], floors[j][1]):
                    bad.append("%s: %s and %s overlap" % (name, floors[i][0], floors[j][0]))
        # Nothing stands in front of a door or a floor-length opening: count
        # only the columns, since both reach the floor.
        for k, fr in floors:
            for f, r in full:
                if fr[0] < r[0] + r[2] and r[0] < fr[0] + fr[2]:
                    if not (k == "till" and f == "arch"):   # the till under the arch is the point
                        bad.append("%s: %s stands in front of the %s" % (name, k, f))
        # A rack is tall: it must not cover an opening either.
        for k, wr in walls:
            if hit(rr, wr) and k != "door":
                bad.append("%s: the rack covers the %s" % (name, k))
        # LAMPS: the level's count, spread evenly and slid sideways off any
        # opening they would hang in front of.
        col, n = LIGHT[level]
        lw, lh = LAMPS[lskin]
        hung = []
        for i in range(n):
            cx = W * (i + 0.5) / n
            best = None
            for dx in sorted(range(-220, 221, 2), key=abs):
                x = int(round(cx - lw / 2 + dx))
                if x < 4 or x + lw > W - 4:
                    continue
                r = (x, 0, lw, lh)
                if any(hit(r, wr) for _, wr in walls):
                    continue
                # never within a lamp's width of another
                if any(abs(x - hx) < lw + 24 for hx in hung):
                    continue
                best = x
                break
            if best is not None:
                hung.append(best)
            if best is None:
                bad.append("%s: nowhere to hang lamp %d" % (name, i + 1))
                continue
            lamp = {"type": "lamp", "skin": lskin, "x": best, "y": 0, "col": col,
                    "pow": 1.4, "reach": 280, "glass": 0.62, "placed": True}
            if flick is not None and i == flick:
                lamp["flick"] = 1          # a starter that will not settle
            items.append(lamp)
        out.append({"name": name, "levels": [level],
                    "room": {"wall": room, "floor": "current"},
                    "backdrop": {"id": bd, "auto": True},
                    "light": {"skin": lskin, "n": n, "col": col, "glass": 0.62,
                              "power": 1.4, "amb": 0.30, "rad": 280, "dither": True},
                    "items": items})
    return out, bad


if __name__ == "__main__":
    lays, bad = build()
    if bad:
        print("\n".join(bad))
        sys.exit(1)
    io.open(OUT, "w", encoding="utf-8", newline="\n").write(json.dumps(lays, indent=1) + "\n")
    print("layouts  %d written to %s" % (len(lays), OUT))
