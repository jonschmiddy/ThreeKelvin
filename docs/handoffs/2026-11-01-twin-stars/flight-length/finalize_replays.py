"""replays.json from v2/replays_raw.json, checked (scratch, Nov 1).
    python3 finalize_replays.py [raw.json [out.json]]
Sets each run's click_at from its own click (click_t) less the scene's clock
zero (scene.click_t), to 0.01 s, and checks every run: settled, on its
target's ring, its first sample at its start, whole-px samples, and the
scene's world tracks covering it; worlds and stars on the 2 px block grid.
(The edge fix, Nov 1: the raw and the output can be named, the defaults as
before; where a run has the fields the edge fix added, it checks fl and ok
parallel to samples (a flame exactly where it burns), pre 42 points from -1.4
to -0.03 s in whole px with its last point next to the first sample, pre_ok
and pre_fl parallel to it, and the world tracks out to the latest click of
any moment plus the longest flight of any plus 3.5 s.)
"""
import json
import os
import sys

FL = os.path.dirname(os.path.abspath(__file__))
src = sys.argv[1] if len(sys.argv) > 1 else os.path.join(FL, "v2", "replays_raw.json")
dst = sys.argv[2] if len(sys.argv) > 2 else os.path.join(FL, "replays.json")
o = json.load(open(src))
fx, fy = 156, 61
bad = []
for f in o["flights"]:
    sc = f["scene"]
    for w in sc["worlds"]:
        for x, y in w["centre"]:
            if (x + fx) % 2 or (y + fy) % 2:
                bad.append("%s world %d off the block grid" % (f["id"], w["i"]))
                break
        for x, y in w.get("centre_pre", []):
            if (x + fx) % 2 or (y + fy) % 2:
                bad.append("%s world %d's centre_pre off the block grid" % (f["id"], w["i"]))
                break
    for s in sc["stars"]:
        x, y = s["centre"]
        if (x + fx) % 2 or (y + fy) % 2:
            bad.append("%s star %d off the block grid" % (f["id"], s["p"]))
    sel_hi = 0.0
    secs_hi = 0.0
    for k, r in f["runs"].items():
        if "secs" not in r:
            continue
        r["click_at"] = round(r["click_t"] - sc["click_t"], 2)
        r["spread"]["sel"] = [round(x, 2) for x in r["spread"]["sel"]]
        sel_hi = max([sel_hi] + r["spread"]["sel"])
        secs_hi = max([secs_hi] + r["spread"]["secs"])
        if not r["settled"] or r["worst"]["ring_px"] != 0:
            bad.append("%s %s not settled on its ring" % (f["id"], k))
        if r["samples"][0][1:3] != r["start"]:
            bad.append("%s %s first sample not at its start" % (f["id"], k))
        if not all(isinstance(s[1], int) and isinstance(s[2], int) for s in r["samples"]):
            bad.append("%s %s samples not whole px" % (f["id"], k))
        if sc["worlds"][0]["centre_t"][-1] < r["click_at"] + r["secs"]:
            bad.append("%s %s runs past the world tracks" % (f["id"], k))
        if r["worst"]["plane_px"] > 0.5:
            bad.append("%s %s %.3f plane px off its drawn line" % (f["id"], k, r["worst"]["plane_px"]))
        if "fl" in r:
            n = len(r["samples"])
            if len(r["fl"]) != n or len(r["ok"]) != n:
                bad.append("%s %s fl/ok not parallel to samples" % (f["id"], k))
            if any((s[4] == 0) != (x == 0) for s, x in zip(r["samples"], r["fl"])):
                bad.append("%s %s a flame where it does not burn, or none where it does" % (f["id"], k))
            p = r["pre"]
            if len(p) != 42 or len(r["pre_ok"]) != 42 or len(r["pre_fl"]) != 42:
                bad.append("%s %s pre not 42 points (%d)" % (f["id"], k, len(p)))
            elif abs(p[0][0] + 1.4) > 0.011 or abs(p[-1][0] + 1.0 / 30.0) > 0.011 or any(b[0] <= a[0] for a, b in zip(p, p[1:])):
                bad.append("%s %s pre's times not -1.4 to -0.03 rising" % (f["id"], k))
            if not all(isinstance(s[1], int) and isinstance(s[2], int) for s in p):
                bad.append("%s %s pre not whole px" % (f["id"], k))
            if p and max(abs(p[-1][1] - r["samples"][0][1]), abs(p[-1][2] - r["samples"][0][2])) > 4:
                bad.append("%s %s pre's last point %s far from the first sample %s" % (f["id"], k, p[-1][1:3], r["samples"][0][1:3]))
    if sel_hi + secs_hi > 0 and "centre_pre" in sc["worlds"][0]:
        if sc["worlds"][0]["centre_t"][-1] < sel_hi + secs_hi + 3.5 - 0.01:
            bad.append("%s world tracks end at %.2f, short of %.2f" % (f["id"], sc["worlds"][0]["centre_t"][-1], sel_hi + secs_hi + 3.5))
# (the run wrote the fallback's wording of the pass before; the code it ran is the sooner of two)
for k in ("B", "C"):
    o["settings"][k]["fallback"] = "where the search to T_CAP finds nothing, the sooner of two: the as-built search (TIME_W 0.5, T_CAP 30, its guess times) and the wider search at this TIME_W; where both find nothing, the as-built wider one; two-leg flights' legs always by the as-built search"
o["checks_ok"] = not bad
json.dump(o, open(dst, "w"), separators=(",", ":"))
print("%s written, %d bytes; problems: %s" % (os.path.basename(dst), os.path.getsize(dst), bad or "none"))
