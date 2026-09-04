# -*- coding: utf-8 -*-
"""Put a bench export into Database.gd.

    python tools/install_rigging.py [rigging.json]

Without a path it takes the newest export it can find. LOOKS ON THE DESKTOP AS
WELL AS IN DOWNLOADS: `read_rig.py` only knew about Downloads and reported "no
rigging export yet" twice while the file sat on the Desktop, which is where the
browser actually put it.

It writes two tables, both GENERATED -- edit the bench, not the block:

    HULL_MOUNTS    where things bolt on, per slot
    HULL_EXHAUST   every plume, with its strip, its offset and its draw order

MASKED STRIPS ARE SUBSTITUTED ON THE WAY IN, and this is the whole reason the
tool exists rather than a one-off script. The bench has no notion of a masked
strip: it offers the 24 plumes that are on disk, so it rigs `id: 3` for heavy_s
and every install faithfully writes that, silently undoing the cut plume made
for that hull's stern. That happened once already. `MASKED` below is the list of
hulls whose rigged strip is replaced by its masked twin, applied every time, so
placement stays the bench's job and masking stays this file's.
"""
import glob
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
GD = os.path.join(HERE, "..", "tkg", "scripts", "autoload", "Database.gd")
LOOK = ["C:/Users/Jon/Desktop", "C:/Users/Jon/Downloads"]
SLOTS = ("weapon", "system", "utility")
ORDER = ["hull_%s_%s" % (w, t)
         for w in ("light", "medium", "heavy") for t in "cbas"]

# hull -> {rigged id: masked id}. See the module docstring.
MASKED = {"hull_heavy_s": {3: 24}}


def newest():
    found = []
    for d in LOOK:
        found += glob.glob(os.path.join(d, "rigging*.json"))
    if not found:
        raise SystemExit("no rigging export in %s" % " or ".join(LOOK))
    return max(found, key=os.path.getmtime)


def splice(src, const, block):
    i = src.index("const %s := {" % const)
    j = src.index("\n}\n", i) + 3
    return src[:i] + block + "\n" + src[j:]


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else newest()
    rig = json.load(io.open(path, encoding="utf-8"))["hulls"]
    missing = [k for k in ORDER if k not in rig]
    if missing:
        raise SystemExit("export is missing %s" % ", ".join(missing))

    mo = ["const HULL_MOUNTS := {"]
    ex = ["const HULL_EXHAUST := {"]
    swapped = []
    for k in ORDER:
        h = rig[k]
        mo.append('\t"%s": {' % k)
        for slot in SLOTS:
            pts = ", ".join("Vector2(%d, %d)" % (p[0], p[1]) for p in h[slot])
            mo.append("\t\t%s = [%s]," % (slot, pts))
        mo.append("\t},")
        ex.append('\t"%s": [' % k)
        for t in h["thrusters"]:
            i = int(t["id"])
            if i in MASKED.get(k, {}):
                swapped.append("%s: %d -> %d" % (k, i, MASKED[k][i]))
                i = MASKED[k][i]
            ex.append("\t\t{id = %d, at = Vector2i(%d, %d), back = %s},"
                      % (i, t["x"], t["y"], "true" if t.get("back") else "false"))
        ex.append("\t],")
    mo.append("}")
    ex.append("}")

    s = io.open(GD, encoding="utf-8").read()
    s = splice(s, "HULL_MOUNTS", "\n".join(mo))
    s = splice(s, "HULL_EXHAUST", "\n".join(ex))
    io.open(GD, "w", encoding="utf-8", newline="").write(s)

    n = sum(len(rig[k][x]) for k in ORDER for x in SLOTS)
    t = sum(len(rig[k]["thrusters"]) for k in ORDER)
    b = sum(1 for k in ORDER for x in rig[k]["thrusters"] if x.get("back"))
    print("  from %s" % path)
    print("  %d mounts, %d thrusters (%d behind) over %d hulls" % (n, t, b, len(ORDER)))
    for line in swapped:
        print("  masked strip substituted -- %s" % line)
    print("  run `-- mounts` and `-- exhaust` next")


if __name__ == "__main__":
    main()
