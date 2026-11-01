"""Builds the flight-length decision sheet from the study's replays.

    python3 assemble.py REPLAYS.json COPY.json OUT.html

REPLAYS is tk-scratch/twin-build/flightlen/replays.json (the study's export:
every x, y in the map frame's game px at the zoom the map opened at). COPY is
the page's words (copy.json beside this file). The page plays each flight at
game speed, A, B and C side by side, cropped to the part of the frame the
flight uses.
"""
import json
import math
import sys
from pathlib import Path

HERE = Path(__file__).parent
OPTS = ["A", "B", "C"]
PAD = 18.0
MIN_W, MIN_H = 170.0, 96.0


def r1(v):
    return round(float(v), 1)


def thin_line(line, hidden):
    """Keep a point about every game px along the line (the dots are 3 px
    apart), and every point where a burn starts or stops."""
    hid = set(hidden or [])
    out = []
    acc = 0.0
    last = None
    prev_b = None
    for j, p in enumerate(line):
        x, y, b = float(p[0]), float(p[1]), int(p[2])
        if last is not None:
            acc += math.hypot(x - last[0], y - last[1])
        last = (x, y)
        keep = j == 0 or j == len(line) - 1 or acc >= 1.0 or b != prev_b
        prev_b = b
        if keep:
            out.append([r1(x), r1(y), b, 1 if j in hid else 0])
            acc = 0.0
    return out


def crop_of(fl, frame_w, frame_h):
    xs, ys = [], []
    for k, run in fl["runs"].items():
        for s in run.get("samples", []):
            xs.append(s[1]); ys.append(s[2])
        for p in run.get("line", []):
            xs.append(p[0]); ys.append(p[1])
    sc = fl["scene"]
    for ride in sc.get("rides", []):
        if "c" in ride:
            continue  # a settled orbit of the sun is the size of the system; the picture shows its stretch
        if ride.get("centre") == "star":
            st = next((s for s in sc["stars"] if s.get("p") == ride["place"]), None)
            c, r = (st["centre"], st["r"]) if st else (None, 0)
        else:
            w = next((w for w in sc["worlds"] if w["i"] == ride["place"]), None)
            c, r = (w["centre"][0], w["r"]) if w else (None, 0)
        if c:
            xs += [c[0] - ride["rx"] - 4, c[0] + ride["rx"] + 4]
            ys += [c[1] - ride["ry"] - r - 4, c[1] + ride["ry"] + r + 4]
    x0, x1, y0, y1 = min(xs) - PAD, max(xs) + PAD, min(ys) - PAD, max(ys) + PAD
    # the suns the flight passes near stay whole in the picture
    for st in sc["stars"]:
        cx, cy = st["centre"]
        reach = st["r"] * 2.2
        if x0 - 30 <= cx <= x1 + 30 and y0 - 30 <= cy <= y1 + 30:
            x0, x1 = min(x0, cx - reach), max(x1, cx + reach)
            y0, y1 = min(y0, cy - reach), max(y1, cy + reach)
    if x1 - x0 < MIN_W:
        m = (x0 + x1) / 2; x0, x1 = m - MIN_W / 2, m + MIN_W / 2
    if y1 - y0 < MIN_H:
        m = (y0 + y1) / 2; y0, y1 = m - MIN_H / 2, m + MIN_H / 2
    x0, y0 = max(0.0, math.floor(x0)), max(0.0, math.floor(y0))
    x1, y1 = min(frame_w, math.ceil(x1)), min(frame_h, math.ceil(y1))
    return [int(x0), int(y0), int(x1 - x0), int(y1 - y0)]


def flight_out(fl, frame, copy):
    x0, y0, w, h = crop_of(fl, frame["w"], frame["h"])
    sc = fl["scene"]

    def inside(p, m=4):
        return x0 - m <= p[0] <= x0 + w + m and y0 - m <= p[1] <= y0 + h + m

    orbit = []
    for o in sc.get("orbit_lines", []):
        pts = [[r1(p[0]), r1(p[1])] for p in o["pts"] if inside(p)]
        if pts:
            orbit.append({"pts": pts, "rgba": o["rgba"]})
    worlds = []
    for wd in sc["worlds"]:
        worlds.append({
            "i": wd["i"], "name": wd["name"], "kind": wd["kind"], "r": wd["r"],
            "rgb": wd["rgb"], "atm": wd.get("atm_rgb"),
            "c": [[r1(c[0]), r1(c[1])] for c in wd["centre"]],
            "ct": [r1(t) for t in wd["centre_t"]],
            "soi": [wd["capture_ring"]["rx"], wd["capture_ring"]["ry"]] if wd.get("capture_ring") else None,
        })
    zoom = float(sc.get("zoom") or fl.get("zoom"))
    stars = [{"p": s.get("p", -1), "c": s["centre"], "r": s["r"], "rgb": s["rgb"], "hot": s["rgb_hot"],
              "limb": s["rgb_limb"], "glow": s["glow_rgb"], "name": s["name"]} for s in sc["stars"]]
    # each ring the flight leaves or arrives on: round a world, round a sun, or
    # a settled orbit of the sun (a fixed centre); disc is what its far half hides behind
    rides = []
    for rd in sc.get("rides", []):
        what = "leaves" if str(rd["what"]).startswith("leaves") else "arrives"
        o = {"what": what, "rx": rd["rx"], "ry": rd["ry"], "w": None, "s": None, "c": None, "disc": 0, "wide": False,
             "life": rd.get("life_rx", rd["rx"]), "pace": 0.0}
        if rd.get("life_rx"):
            v = 45.0 if rd.get("centre") == "star" else 35.0
            o["pace"] = round(v * zoom / rd["life_rx"], 4)  # rad/s on the plane: V / ring radius
        if "c" in rd:
            o["c"] = rd["c"]; o["wide"] = True
        elif rd.get("centre") == "star":
            st = next((x for x in stars if x["p"] == rd["place"]), None)
            o["s"] = rd["place"]; o["c"] = st["c"] if st else None; o["disc"] = st["r"] if st else 0
        else:
            wd = next((x for x in sc["worlds"] if x["i"] == rd["place"]), None)
            o["w"] = rd["place"]; o["disc"] = wd["r"] if wd else 0
        rides.append(o)
    runs = {}
    for k in OPTS + ["TODAY"]:
        run = fl["runs"].get(k)
        if not run or "samples" not in run:
            continue
        sp = run.get("spread") or {}
        lo, hi = sp.get("min", run["secs"]), sp.get("max", run["secs"])
        runs[k] = {
            "ca": round(float(run.get("click_at", 0.0)), 3),
            "rng": [round(lo, 1), round(hi, 1)],
            "n": len(sp.get("secs", [])) or 1,
            "secs": round(run["secs"], 2),
            "s": [[round(s[0], 3), r1(s[1]), r1(s[2]), r1(s[3]), int(s[4]), s[5]] for s in run["samples"]],
            "line": thin_line(run.get("line", []), run.get("hidden", [])),
            # the ship's own point (not drawn out on its ring), for nearness to a world's pull
            "rw": [[r1(q[0]), r1(q[1])] for q in run.get("raw", [])],
            # when the re-export has them: flame length px, the overlay's ring scale, 1.4 s before the click
            "fl": [int(v) for v in run["fl"]] if run.get("fl") else None,
            "ok": [round(float(q[0]), 3) for q in run["ok"]] if run.get("ok") else None,
            "pre": [[round(q[0], 3), r1(q[1]), r1(q[2]), r1(q[3]), int(q[4]), q[5]] for q in run["pre"]] if run.get("pre") else None,
            "wa": round(float(run["warp_at"]), 3) if run.get("warp_at") is not None else None,
            "legs": (run.get("plan") or {}).get("legs", 1),
        }
    c = copy["flights"].get(fl["id"], {})
    return {
        "id": fl["id"], "kind": fl["kind"], "label": c.get("label", fl["id"]),
        "sub": c.get("sub", ""), "crop": [x0, y0, w, h], "orbit": orbit, "worlds": worlds,
        "stars": stars, "rides": rides, "runs": runs, "tilt": sc.get("tilt", 0.38),
    }


def main():
    rp, cp, out = sys.argv[1], sys.argv[2], sys.argv[3]
    d = json.loads(Path(rp).read_text())
    copy = json.loads(Path(cp).read_text())
    order = copy.get("order") or [f["id"] for f in d["flights"]]
    byid = {f["id"]: f for f in d["flights"]}
    flights = [flight_out(byid[i], d["frame"], copy) for i in order if i in byid]
    data = {"frame": d["frame"], "flights": flights}
    js = json.dumps(data, separators=(",", ":"))
    tmpl = (HERE / "template.html").read_text()
    html = tmpl.replace("__DATA__", js.replace("</", "<\\/"))
    for k, v in copy["text"].items():
        html = html.replace("__" + k + "__", v)
    if "__" in html.split("<script")[0].replace("__DATA__", ""):
        left = [s for s in html.split("__") if s.isupper() and len(s) < 30]
        print("unfilled placeholders?", left[:10])
    Path(out).write_text(html)
    print(out, round(len(html) / 1024), "KB,", len(flights), "flights",
          [(f["id"], f["crop"][2:]) for f in flights])


if __name__ == "__main__":
    main()
