"""Draft the Exchange's five rooms from Jon's shop rooms, one per level.

    python tools/exchange_compose.py      # writes tools/room_stage/exchange_levels.json

(numpy and PIL, like `room_install.py`: the openings are measured the way the
installer measures them.)

A DRAFT FOR JON TO TOUCH UP, not a design. Each level's first shop room is
taken as he left it -- plate, lamps, props -- and made into a loading dock the
way the original Exchange was one (Jon, 2026-09-27: "the original exchange had
more of a hanger door situation going on. I think that's best."):

  * the hold stands at the left, where the old dock kept its cage: the heavy
    hull's frame, the biggest there is, feet where his rack's were, hanging
    from a crane hook on a cable to the ceiling (Jon: "a box that is
    suspended by a wire");
  * the hangar door (`open`, skin `hangar_<level>`, from `exchange_art.py`)
    is the main thing (Jon: "the hanger doors should be MUCH bigger. like the
    main thing"): most of the back wall, centred, its threshold on the floor
    line, with the hold and the machine standing in front of it. Under its
    raised leaf is the station's sky;
  * the machine you sell at (`till`, skin `exchange_<level>`) stands at the
    right, feet where his counter's were -- "quite a bit more mechanical
    instead of a store kinda deal";
  * his windows, doors and wall props come out where any of the three stands
    across them; his lamps all stay;
  * the level's cargo props stand in front, near the machine, clear of the
    hold's grid and the door's gap;
  * nobody walks past.

Everything else is his. The rooms are laid out on the shop's plates, and in
the game each Exchange stands in its own station's shop plate, so any of the
level's three plates may be behind it. Which window frames the station's world
is `room_install.sky_frame`'s call, made at install from whatever he leaves.
"""

import io
import json
import os
import struct

HERE = os.path.dirname(os.path.abspath(__file__))
STAGE = os.path.join(HERE, "room_stage")
EXPORT = os.path.join(STAGE, "room-layouts.json")
BOXES = os.path.join(STAGE, "exchange", "hold_boxes.json")
EXCHANGE = os.path.join(STAGE, "exchange")
# How far a hold hangs above where it would stand.
LIFT = 24
# THE FLOOR IS THE SELLING BENCH'S (Jon, 2026-09-27: "the bottom right of these
# suck. it should just be the selling bench."): nothing of his stands on the
# deck in a draft, and no cargo prop is placed; they stay in the stock to be
# put back by hand. The machine is drawn at MACHINE_K.
MACHINE_K = 2
PLACE_CARGO = False
OUT = os.path.join(STAGE, "exchange_levels.json")
W, H, FLOOR = 740, 431, 353
FIRST = ["unclaimed · scrap", "outpost · prefab", "settlement · quilt",
         "city · chevron", "capital · alloy"]
# Jon cut the hook scale, the balance and the baskets (2026-09-27): "doesn't
# make sense". The settlement's drums and hand truck came after.
CARGO = {"unclaimed": ["unclaimed_scrappallet"],
         "outpost": ["outpost_platformscale", "outpost_palletjack"],
         "settlement": ["settlement_cargodrums", "settlement_handtruck"],
         "city": ["city_chromescale", "city_cargocrates"],
         "capital": ["capital_marblescale", "capital_luggagetrolley"]}


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return struct.unpack(">II", head[16:24])


def prop_size(pid):
    for f in os.listdir(STAGE):
        if f.startswith("prop_") and f.endswith(".png") and f[5:-4].split("_", 1)[1] == pid:
            return png_size(os.path.join(STAGE, f))
    raise SystemExit("exchange_compose: no prop %s in the stage" % pid)


def rect(o):
    t = o["type"]
    if t == "shelf":
        w, h = png_size(os.path.join(STAGE, "rack2_%s.png" % o["skin"]))
        return o["x"], o["y"], w * 2, h * 2
    if t == "open":
        w, h = png_size(os.path.join(STAGE, "open_%s.png" % o["skin"]))
        return o["x"], o["y"], w, h
    if t == "till":
        w, h = png_size(os.path.join(STAGE, "till_%s.png" % o["skin"]))
        k = o.get("scale") or 1
        return o["x"], o["y"], w * k, h * k
    if t == "prop":
        w, h = prop_size(o["id"])
        k = o.get("scale") or 1
        return o["x"], o["y"], round(w * k), round(h * k)
    return None


def overlap(a, b):
    w = min(a[0] + a[2], b[0] + b[2]) - max(a[0], b[0])
    h = min(a[1] + a[3], b[1] + b[3]) - max(a[1], b[1])
    return max(0, w) * max(0, h)


def main():
    import room_install
    stage = room_install.Stage()
    rooms = dict((l["name"], l) for l in json.load(io.open(EXPORT, encoding="utf-8"))["layouts"])
    boxes = json.load(io.open(BOXES, encoding="utf-8"))
    out = []
    for name in FIRST:
        src = json.loads(json.dumps(rooms[name]))
        level = name.split(" · ")[0]
        shelf = [o for o in src["items"] if o["type"] == "shelf"][0]
        old_till = [o for o in src["items"] if o["type"] == "till"][0]
        sx, sy, sw, sh = rect(shelf)
        tx0, ty0, tw0, th0 = rect(old_till)
        # the hold at the left, feet where the rack's were
        hw, hh = [v * 2 for v in boxes[level]["l"]["size"]]
        # HUNG, NOT STOOD: lifted clear of where it would stand, as far as the
        # hook it hangs from still fits under the ceiling (`exchange_art.py`)
        from PIL import Image
        import numpy as np
        fa = np.array(Image.open(os.path.join(EXCHANGE, boxes[level]["l"]["file"])).convert("RGBA"))
        catch = int(np.argmax(fa[:, fa.shape[1] // 2, 3] > 40)) * 2
        hook_h, into = png_size(os.path.join(EXCHANGE, "hook.png"))[1], 6
        hx, hy = 8, max(sy + sh - hh - LIFT, hook_h - into - catch)
        hold = {"type": "hold", "skin": level, "x": hx, "y": hy, "layer": "wall"}
        # the machine at the right, feet where the counter's were
        mw, mh = [v * MACHINE_K for v in png_size(os.path.join(STAGE, "till_exchange_%s.png" % level))]
        mx, my = W - 8 - mw, int(round(ty0 + th0)) - mh
        machine = {"type": "till", "skin": "exchange_" + level, "x": mx, "y": my, "layer": "wall"}
        if MACHINE_K != 1:
            machine["scale"] = MACHINE_K
        # the door across the middle of the wall, behind them both
        dw, dh = png_size(os.path.join(STAGE, "open_hangar_%s.png" % level))
        dx = int(round((W - dw) / 2.0))
        door = {"type": "open", "skin": "hangar_" + level, "x": dx, "y": FLOOR - dh}
        taken = [(hx, hy, hw, hh), (mx, my, mw, mh), (dx, FLOOR - dh, dw, dh)]
        items = [door, hold]
        for o in src["items"]:
            if o is shelf or o is old_till:
                continue
            if o["type"] == "lamp":
                items.append(o)
                continue
            if room_install.is_opening(o):
                q = room_install.rect_of(o, stage, src.get("light", {}))
                q = (q["x"], q["y"], q["w"], q["h"])
                if any(overlap(q, t) for t in taken):
                    continue
                items.append(o)
                continue
            r = rect(o)
            if r and o.get("layer", "wall") == "wall" and \
                    sum(overlap(r, t) for t in taken) > 0.4 * r[2] * r[3]:
                continue
            # nothing stands on the deck but the bench
            if r and r[1] + r[3] >= FLOOR - 12:
                continue
            items.append(o)
        items.append(machine)
        foot = my + mh
        # THE CARGO PROPS STAND IN FRONT, NEAR THE MACHINE, clear of the hold's
        # grid, the machine and the door's gap -- the view is what the door is
        # for. They may overlap his props, the less the better, and he moves
        # them where he wants them.
        op = boxes[level]["l"]["opening"]
        grid = (hx + op[0] * 2, hy + op[1] * 2, op[2] * 2, op[3] * 2)
        runs = stage.holes["hangar_" + level]["runs"]
        gap = (dx + min(q[1] for q in runs), FLOOR - dh + min(q[0] for q in runs),
               max(q[1] + q[2] for q in runs) - min(q[1] for q in runs),
               max(q[0] for q in runs) - min(q[0] for q in runs) + 1) if runs else (dx, FLOOR - dh, dw, dh)
        hard = [grid, (mx, my, mw, mh)]
        standing = [r for r in (rect(o) for o in items if o["type"] == "prop") if r and r[1] + r[3] >= foot - 12]
        for pid in (CARGO[level] if PLACE_CARGO else []):
            pw, ph = prop_size(pid)
            best, best_cost = None, None
            for px in range(4, W - 4 - pw + 1):
                pr = (px, foot - ph, pw, ph)
                if any(overlap(pr, b) for b in hard):
                    continue
                near = min(abs(px + pw - mx), abs(px - (mx + mw)))
                cost = sum(overlap(pr, b) for b in standing) / float(pw * ph) * 400 + near                     + overlap(pr, gap) / float(pw * ph) * 200
                if best_cost is None or cost < best_cost:
                    best, best_cost = pr, cost
            if not best:
                print("  no floor for %s in %s" % (pid, level))
                continue
            standing.append(best)
            items.append({"type": "prop", "x": best[0], "y": best[1], "id": pid, "layer": "floor"})
        room = {"name": "%s · exchange" % level, "levels": [level], "room": src["room"],
                "light": src["light"], "air": {"people": 0, "motes": src["air"].get("motes", 90)},
                "backdrop": {"id": "space_" + level, "auto": True}, "items": items}
        out.append(room)
        print("  %-22s hold at %d, door %dx%d at %d, machine %dx%d at %d; %d items"
              % (room["name"].replace(" · ", " / "), hx, dw, dh, dx, mw, mh, mx, len(items)))
    with io.open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write(json.dumps(out, indent=1, ensure_ascii=False) + "\n")
    print("wrote %d rooms to %s" % (len(out), os.path.relpath(OUT, os.path.dirname(HERE))))


if __name__ == "__main__":
    main()
