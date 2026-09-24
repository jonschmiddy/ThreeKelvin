"""Build the room bench: the shop's back wall, and a stock of things to arrange on it.

    python tools/room_bench.py [--out tools/out/room-bench.html]

A self-contained page, like the rigging bench: the wall at game size, every
backdrop, window frame, porthole plate, door, shelf and till on disk as stock,
and layouts you drag, nudge and resize until they work. It saves
`room-layouts.json` to your downloads through the `downloads` capability; the
install step reads it from there.

WHY A BENCH. Placing a window by editing a Rect2 and re-shooting the game is a
two-minute round trip per pixel, and the four hand-placed layouts took an
afternoon of exactly that. Arranging a room is a thing you do by looking.

WHAT IT RENDERS IS WHAT THE GAME DRAWS, in the same order: wall; each opening
filled with the part of the backdrop behind it, then glass and its frame; haze;
furniture standing on the floor. The frames are the same nine-slices at the same
margins, and the backdrop is placed the way `StationRoom._draw_openings` places
it until you move it yourself.

THE FOUR LAYOUTS THE GAME HAS NOW ARE THE SEED, so the bench opens on what is
already approved rather than on a blank wall.
"""

import base64
import io
import json
import os
import re
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))

import pixeltools  # noqa: E402

# WHAT JON CUT, kept here rather than in the page's own cut list so it stays
# cut across a rebuild. The bench's Cut panel is a working state -- it has a
# restore button beside every row and it lives in the browser; this is the
# verdict. Anything named here never reaches the page at all.
CUT_BACKDROPS = ["concourse", "galley", "scrap", "tanks"]
CUT_ROOMS = ["hex_a", "hex_b", "lab_a", "lab_b", "pipes_a", "quilt_a",
             "ribbed_a", "ribbed_b", "rust_a", "rust_b", "slab"]
CUT_OPENINGS = ["angled", "breach", "canopy", "cracked", "double", "grid",
                "rail", "roundbig"]


def _apply_cuts(data):
    """Drop what was cut, and anything in the seed that stood on it."""
    before = (len(data["backdrops"]), len(data["walls"]),
              len(data["skins"]["opening"]))
    data["backdrops"] = [b for b in data["backdrops"] if b["id"] not in CUT_BACKDROPS]
    data["walls"] = [w for w in data["walls"] if w["id"] not in CUT_ROOMS]
    for k in CUT_OPENINGS:
        data["skins"]["opening"].pop(k, None)
    # A SEEDED LAYOUT CANNOT STAND ON A CUT OPENING. Leaving the item in would
    # draw nothing and read as a hole in the wall, so it comes out -- and the
    # layouts are being redone anyway, which is why this is a removal and not a
    # substitution nobody asked for.
    live = set(data["skins"]["opening"])
    dropped = 0
    for lay in data["seed"]:
        keep = []
        for o in lay.get("items", []):
            if o.get("type") == "open" and o.get("skin") not in live:
                dropped += 1
                continue
            keep.append(o)
        lay["items"] = keep
        if lay.get("backdrop", {}).get("id") in CUT_BACKDROPS and data["backdrops"]:
            lay["backdrop"]["id"] = data["backdrops"][0]["id"]
    # AND THE ART GOES WITH THEM. Every picture registers itself in ASSETS as
    # it is read, which happens before any of this, so a cut backdrop would
    # still be published beside the page and fetched by nobody. Keep only what
    # the page can still name.
    keep = set()
    for b in data["backdrops"]:
        keep.add(b.get("src", ""))
    for w in data["walls"]:
        keep.add(w.get("src", ""))
    for v in data["skins"]["opening"].values():
        keep.add(v.get("src", ""))
    pruned = 0
    for ref in list(ASSETS):
        base = os.path.basename(ref)
        if not (base.startswith("backdrop_") or base.startswith("room_")
                or base.startswith("opening_") or base.startswith("open_")):
            continue
        if ref not in keep:
            del ASSETS[ref]
            pruned += 1
    after = (len(data["backdrops"]), len(data["walls"]),
             len(data["skins"]["opening"]))
    print("  cut: %d backdrop(s), %d room(s), %d opening style(s); "
          "%d placed opening(s) came out of the seed"
          % (before[0] - after[0], before[1] - after[1],
             before[2] - after[2], dropped))
    print("       left: %d backdrops, %d rooms, %d openings (%s)"
          % (after[0], after[1], after[2], ", ".join(sorted(live))))
    if pruned:
        print("       %d file(s) no longer published beside the page" % pruned)


def _check_glow_keys(html, data):
    """PROP_GLOW is keyed by prop id, and a wrong key fails silently.

    Every lit prop is looked up as PROP_GLOW[o.id]. A key taken from the
    filename instead of the id -- `floor_vend_a` rather than `vend_a` -- just
    returns undefined, so the prop gives off no light and its lit face is
    never redrawn. Nothing throws and nothing looks broken in the source. It
    cost three builds, so the build refuses it now.
    """
    import re as _re
    m = _re.search(r"var PROP_GLOW = \{(.*?)\};", html, _re.S)
    if not m:
        raise SystemExit("room_bench: PROP_GLOW is gone from the template")
    keys = _re.findall(r"([A-Za-z_][A-Za-z0-9_]*)\s*:", m.group(1))
    have = set(p["id"] for p in data.get("props", []))
    bad = [k for k in keys if k not in have]
    if bad:
        raise SystemExit(
            "room_bench: PROP_GLOW names %d prop(s) that do not exist: %s\n"
            "  real prop ids: %s"
            % (len(bad), ", ".join(bad), ", ".join(sorted(have))))
    print("  lit props: %d, all keyed to real ids" % len(keys))


HARNESS = r"""
var OUT = [], TRACE = {};
for (var m = 1; m < FLICKS.length; m++){
  for (var ri = 0; ri < SPEEDS.length; ri++){
    var o = {x: 294, y: 96}, r = SPEEDS[ri][1];
    if (r > 0) o.rate = r;
    var v = [], lo = 2, hi = -1, tintSpan = 0, tn = [1, 1, 1];
    var warm = [];
    // Ninety seconds at the REAL redraw rate. The slow settings only
    // misbehave a couple of times a minute, so a short window proves nothing,
    // and a 60fps trace would judge a signal nobody is shown.
    for (var t = 0; t < 90000; t += FLICK_MS){
      var x = flickerAt(m, 0, t, o, tn);
      if (!(x >= 0 && x <= 1.0001))
        throw new Error(FLICKS[m] + " at " + SPEEDS[ri][0] + " gave " + x);
      for (var c = 0; c < 3; c++)
        if (!(tn[c] >= 0 && tn[c] <= 3))
          throw new Error(FLICKS[m] + " tint channel " + c + " = " + tn[c]);
      v.push(x);
      // How far the fault pushes the light off white, either way.
      warm.push(tn[0] - tn[2]);
      if (x < lo) lo = x;
      if (x > hi) hi = x;
    }
    var wlo = Math.min.apply(null, warm), whi = Math.max.apply(null, warm);
    tintSpan = whi - wlo;
    var sum = 0, full = 0, dark = 0;
    for (var i = 1; i < v.length; i++) sum += Math.abs(v[i] - v[i - 1]);
    v.forEach(function(x2){ if (x2 > 0.98) full++; if (x2 < 0.15) dark++; });
    OUT.push([FLICKS[m], SPEEDS[ri][0], sum / (v.length - 1), lo, hi,
              full / v.length, dark / v.length, tintSpan]);
    // Keep one speed's trace per mode so the modes can be compared to each
    // other -- "they all look the same" is a statement about PAIRS.
    if (SPEEDS[ri][0] === "steady") TRACE[FLICKS[m]] = v;
  }
}
function corr(a, b){
  var n = Math.min(a.length, b.length), ma = 0, mb = 0, i;
  for (i = 0; i < n; i++){ ma += a[i]; mb += b[i]; }
  ma /= n; mb /= n;
  var num = 0, da = 0, db = 0;
  for (i = 0; i < n; i++){
    num += (a[i] - ma) * (b[i] - mb);
    da += (a[i] - ma) * (a[i] - ma);
    db += (b[i] - mb) * (b[i] - mb);
  }
  return (da <= 0 || db <= 0) ? 0 : num / Math.sqrt(da * db);
}
var PAIRS = [], names = Object.keys(TRACE);
for (var a1 = 0; a1 < names.length; a1++)
  for (var b1 = a1 + 1; b1 < names.length; b1++)
    PAIRS.push([names[a1], names[b1], corr(TRACE[names[a1]], TRACE[names[b1]])]);
console.log(JSON.stringify({rows: OUT, pairs: PAIRS}));
"""


def _check_flicker(html):
    """Every fault mode must run, and must flash rather than drift.

    `FR` was a local inside `flickerAt` while the shape functions that used it
    were their own functions, so every mode threw a ReferenceError the moment a
    lamp was set to anything but steady. The page still loaded, the draw check
    still passed and the probe still passed -- because the default layout has
    no flickering lamp in it. The gate could not see the feature. So the gate
    drives the feature now: every mode, at every speed, sampled at the rate the
    bench actually redraws.

    It also measures the fault that was reported. Something that moves a little
    each frame is a pulse; something that jumps is a flash. Smooth noise faster
    than half the redraw rate folds DOWN into a slow beat, which is how
    `trembling` came to swell instead of stutter -- so the check is on
    frame-to-frame jump, and not on anything about how the value is arrived at.
    """
    import re as _re
    import subprocess
    import tempfile
    import os as _os
    import json as _json

    names = _re.search(r"var FLICKS = \[(.*?)\];", html, _re.S)
    if not names:
        raise SystemExit("room_bench: FLICKS is gone from the template")
    modes = _re.findall(r'"([a-z]+)"', names.group(1))
    body = _re.search(r"<script>(.*?)</script>\s*</body>", html, _re.S).group(1)

    # THE FAULTS ONLY, not the page. Running the whole script needs a document,
    # and a stubbed one is how the last gate came to pass on a dead feature.
    # These functions touch nothing but numbers, so they are lifted out whole
    # and run for real.
    def fn(name):
        i = body.index("function %s(" % name)
        d, j = 0, body.index("{", i)
        for k in range(j, len(body)):
            if body[k] == "{":
                d += 1
            elif body[k] == "}":
                d -= 1
                if d == 0:
                    return body[i:k + 1]
        raise SystemExit("room_bench: %s() is unterminated" % name)

    need = ["hash1", "vnoise", "fnoise", "lastEvent", "tintNone", "tintStrike",
            "tintSpent", "tintEmber", "shapeStrike", "flickerAt"]
    for want in need:
        if ("function %s(" % want) not in body:
            raise SystemExit("room_bench: flickerAt lost its helper %s()" % want)
    # A LINE ANCHOR CANNOT FIND THESE. The built page has its newlines
    # collapsed and `FR` carries a trailing comment, so "var FR = ...;" at the
    # end of a line matches nothing -- and a regex that finds nothing is how a
    # gate quietly stops checking. Read to the semicolon that actually closes
    # the statement instead, brackets and all.
    def konst(name):
        i = body.index("var %s = " % name)
        depth = 0
        for k in range(i, len(body)):
            ch = body[k]
            if ch in "[{(":
                depth += 1
            elif ch in "]})":
                depth -= 1
            elif ch == ";" and depth == 0:
                return body[i:k + 1]
        raise SystemExit("room_bench: var %s is unterminated" % name)

    consts = []
    for c in ["FLICKS", "SPEEDS", "FLICK_MS", "FR", "BURST"]:
        if ("var %s = " % c) not in body:
            raise SystemExit("room_bench: %s is gone from the template" % c)
        consts.append(konst(c))
    nl = chr(10)
    harness = nl.join(consts) + nl + nl.join(fn(x) for x in need) + HARNESS
    fd, path = tempfile.mkstemp(suffix=".js")
    _os.write(fd, harness.encode("utf-8"))
    _os.close(fd)
    try:
        r = subprocess.run(["node", path], capture_output=True, text=True)
    finally:
        _os.unlink(path)
    if r.returncode != 0:
        raise SystemExit("room_bench: a fault mode threw --\n"
                         + (r.stderr or r.stdout).strip()[:700])
    got = _json.loads(r.stdout.strip().splitlines()[-1])
    rows, pairs = got["rows"], got["pairs"]

    # FOUR FAULTS THAT LOOK LIKE FOUR THINGS. Jon cut the set from eight
    # because "all the fault animations kinda look the same" -- so the check
    # that matters is not whether each one moves, it is whether any TWO of them
    # move alike. Correlation between a pair's traces is that, measured.
    bad = []
    for nm_a, nm_b, c in pairs:
        if abs(c) > 0.6:
            bad.append("%s and %s move alike (correlation %.2f)"
                       % (nm_a, nm_b, c))

    # And the set has to SPAN the ways a light fails, or four distinct curves
    # are still four curves. One that mostly sits at full and blinks, one that
    # goes properly dark, one that throws colour.
    fast = [r2 for r2 in rows if r2[1] == "frantic"]
    if not any(r2[5] > 0.55 for r2 in fast):
        bad.append("nothing holds steady between faults -- no isolated blink")
    if not any(r2[6] > 0.12 for r2 in fast):
        bad.append("nothing goes properly dark")
    if not any(r2[7] > 0.25 for r2 in fast):
        bad.append("no fault changes the colour of its light")
    for nm, sp, jump, lo, hi, full, dark, tint in fast:
        if hi - lo < 0.2:
            bad.append("%s barely moves (span %.2f)" % (nm, hi - lo))
    if bad:
        raise SystemExit("room_bench: " + "; ".join(bad))
    worst = max(abs(c) for _, _, c in pairs) if pairs else 0.0
    print("  faults: %d run clean at %d speeds; the closest pair of them "
          "correlates %.2f" % (len(modes) - 1, len(rows) // max(1, len(modes) - 1),
                               worst))


def _check_stage_shadows():
    """A staged sprite silently replaces the installed one of the same name.

    `--stage` exists so a new cut can be judged before it ships, and an opening
    staged as `open_<name>.png` overrides the installed `opening_<name>.png`
    completely. That is the point of it -- but it means an edit to the installed
    file changes nothing you can see, and four rounds of repairs to the opening
    art went into files the bench never loaded. Nothing failed; the bench just
    kept drawing the old ones. So say it out loud every build.
    """
    if "--stage" not in sys.argv:
        return
    import hashlib
    stage = sys.argv[sys.argv.index("--stage") + 1]
    shadowed = []
    for f in sorted(os.listdir(stage)):
        if not (f.startswith("open_") and f.endswith(".png")):
            continue
        inst = os.path.join(STATION, "opening_" + f[5:])
        if not os.path.exists(inst):
            continue
        a = hashlib.sha1(open(os.path.join(stage, f), "rb").read()).hexdigest()
        b = hashlib.sha1(open(inst, "rb").read()).hexdigest()
        if a != b:
            shadowed.append(f[5:-4])
    if shadowed:
        print("  NOTE: the stage overrides %d installed opening(s), so edits to"
              % len(shadowed))
        print("        the installed art will NOT show: " + ", ".join(shadowed))
    else:
        print("  stage and installed openings agree")


def _stamp():
    """A short, increasing label for this build: the minute it was made."""
    import time
    return time.strftime("%m-%d %H:%M")


HERE = os.path.dirname(os.path.abspath(__file__))
TKG = os.path.abspath(os.path.join(HERE, "..", "tkg"))
STATION = os.path.join(TKG, "art", "sprites", "station")
TEMPLATE = os.path.join(HERE, "room_bench.tmpl.html")

PANEL = (740, 431)
FLOOR_Y = 353
# `ShopScene` constants the seed layouts are built from.
SKY_Y, SKY_H = 16, 52
# Frame margins as `StationRoom._bezel` loads them.
FRAMES = {"chamfer": ("frame_window.png", 18), "round": ("frame_window_round.png", 24),
          "octa": ("frame_window_octa.png", 24)}


# ART BESIDE THE PAGE, NOT INSIDE IT. Every picture used to be a data: URI in
# the HTML, and with twenty-six backdrops that came to a 3 MB page the artifact
# viewer sat on for a minute before it drew anything. Published as files the
# page is a few hundred lines, each sprite is fetched when something draws it,
# and the browser caches them between visits. `--inline` puts them back in the
# page for a copy you can open straight off disk.
ASSETS = {}
INLINE = "--inline" in sys.argv


def _ref(path, name):
    if INLINE:
        with open(path, "rb") as f:
            return "data:image/png;base64," + base64.b64encode(f.read()).decode("ascii")
    ASSETS["art/" + name] = os.path.abspath(path)
    return "art/" + name


def b64(name):
    return _ref(os.path.join(STATION, name), name)


WALK_JSON = os.path.join(STATION, "backdrop_walk.json")


def _walk():
    """The floor lines each backdrop's crowds walk on, and how tall they are.

    Drawn by hand in the walk-line bench, one picture at a time, and keyed by
    backdrop -- any room may draw any backdrop, so this cannot live on a room.
    Two numbers per line: where the floor is, and a person's height standing on
    it. The height is also the DEPTH: the tallest line on a picture is the
    nearest, and everything else is measured against it, so nobody has to state
    distance twice.
    """
    if not os.path.exists(WALK_JSON):
        return {}
    return json.load(io.open(WALK_JSON, encoding="utf-8"))


WALKERS_JSON = os.path.join(STATION, "walker_strips.json")


def _walkers():
    """The generated walk strips, with the stride measured off each one.

    A strip carries its own frame size, frame count and advance, because none
    of those can be inferred: two cycles from the same generator stride
    different distances, and how fast a cycle PLAYS follows from its stride
    rather than from its frame count. See PIXELLAB_WORKFLOW.md.
    """
    if not os.path.exists(WALKERS_JSON):
        return {}
    idx = json.load(io.open(WALKERS_JSON, encoding="utf-8"))
    out = {}
    for name, m in idx.items():
        path = os.path.join(STATION, m["file"])
        if not os.path.exists(path):
            continue
        d = dict(m)
        d["src"] = _ref(path, m["file"])
        out[name] = d
    return out


def _check_walk(walk, backdrops):
    """A walk line is measured ON THE PICTURE, and must stay that way.

    The lines are drawn in the walk bench, where the backdrop fills the canvas
    and y runs from 0 to the image height. The room hangs that same picture at
    y=-47 and may scale it, so a picture y used as a canvas y puts every walker
    47px below where it was drawn -- which is what happened, uniformly, across
    all 36 lines. Nothing threw and the room still looked plausible.

    A value that strayed into canvas space would fall outside the picture, so
    that is what this checks: every y on its own image, every height able to
    fit on it.
    """
    size = dict((b["id"], b["size"]) for b in backdrops)
    bad = []
    for bid, lines in sorted(walk.items()):
        if bid not in size:
            bad.append("%s has lines but is not a backdrop here" % bid)
            continue
        h = size[bid][1]
        for i, ln in enumerate(lines):
            if not (0 <= ln["y"] <= h):
                bad.append("%s line %d: y=%d is off a %dpx picture"
                           % (bid, i + 1, ln["y"], h))
            if not (4 <= ln["tall"] <= h):
                bad.append("%s line %d: a %dpx person does not fit a %dpx "
                           "picture" % (bid, i + 1, ln["tall"], h))
    if bad:
        raise SystemExit("room_bench: walk lines are not in picture space --"
                         + chr(10) + "  "
                         + (chr(10) + "  ").join(bad))
    n = sum(len(v) for v in walk.values())
    if n:
        tall = sorted(l["tall"] for v in walk.values() for l in v)
        print("  walk lines: %d across %d backdrops, people %d-%dpx"
              % (n, len(walk), tall[0], tall[-1]))


DECKS_JSON = os.path.join(STATION, "backdrop_decks.json")


def _decks():
    """How far each backdrop's own floor is above the bottom of its file.

    Measured by `room_plate.py decks`. Without it the picture is placed with its
    BOTTOM EDGE on the room's floor line, which is only the same thing as the
    two floors meeting if the hall's deck is drawn right at the bottom -- and
    across the set it sits 18 to 172 pixels up.
    """
    if not os.path.exists(DECKS_JSON):
        return {}
    return json.load(io.open(DECKS_JSON, encoding="utf-8"))


def hole_runs(path):
    """The mask as [y, x, width] runs of opaque pixels, row by row."""
    w, h, rows = pixeltools.decode(path)
    out = []
    for y in range(h):
        x = 0
        while x < w:
            if rows[y][x * 4 + 3] > 40:
                x0 = x
                while x < w and rows[y][x * 4 + 3] > 40:
                    x += 1
                out.append([y, x0, x - x0])
            else:
                x += 1
    return out


def png_size(name):
    with open(os.path.join(STATION, name), "rb") as f:
        head = f.read(24)
    return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")


# The rack's width, read off the art rather than typed twice.
RACK_W = png_size("shop_shelf2.png")[0]


# WHAT SURVIVED THE CUTS, as of Jon's last pass: the rooms and backdrops he
# kept, and the openings whose holes came out usable. `grid` is back in: the
# cutter only ever took ONE transparent region, so a frame made of bars gave up
# a single gap and the wall showed through the other twenty. The hole is every
# gap the frame encloses now, which took grid from 9348 to 42176 pixels of
# view. `strip` stays out and is dropped at build time -- nothing in it is
# enclosed at all, so it can only ever be a frame with wall behind it.
ROOMS = ["brick", "crate", "foil", "ice", "pipes_b", "reactor",
         "scaffold_a", "scaffold_b", "wood_a", "wood_b"]
# The far-distance set that replaced the first twenty-six, all 800x400 so the
# picture reaches past the top and sides of the wall. Keep this in step with
# `StationRoom.BACKDROPS`; the bench draws from the same installed files.
VIEWS = ["arches", "archive", "arrivals", "atrium", "bazaar", "capsule",
         "cargo", "concourse", "farm", "food", "freightlift", "fuel", "galley",
         "garden", "hab", "halfbuilt", "lifts", "lockers", "nightatrium",
         "nightwatch", "parcel", "ports", "rigging", "scrap", "servers",
         "sorting", "tanks", "vending", "vitrine"]
# name -> size at wall scale, so a layout can be composed by arithmetic rather
# than by eye.
HOLES_JSON = os.path.join(STATION, "opening_holes.json")


def _installed_openings():
    """name -> (w, h) for every opening the GAME has, read off its hole table.

    This was a dict typed out here, which meant the bench believed an arch was
    240x300 because someone wrote that down. It is whatever the art is.
    """
    if not os.path.exists(HOLES_JSON):
        return {}
    table = json.load(io.open(HOLES_JSON, encoding="utf-8"))
    return dict((k, (v["w"], v["h"])) for k, v in table.items())


OPENINGS = _installed_openings()
RACK_H, TILL_W, TILL_H = 152, 180, 128
# The shortest backdrop stands 284 tall with its walkway on the floor line, so
# nothing opened above this is certain to have a view behind it.
SKY = 70


def _open(name, x, y):
    w, h = OPENINGS[name]
    return {"type": "open", "skin": name, "x": int(x), "y": int(y)}


def _window(style, x, y, w, h):
    return {"type": "window", "style": style, "x": int(x), "y": int(y), "w": w, "h": h}


def _door(x, h=150, skin=None):
    o = {"type": "door", "x": int(x), "y": FLOOR_Y - h, "w": 56, "h": h}
    if skin:
        o["skin"] = skin
    return o


# WHERE THE LAYOUTS COME FROM: the game, not this file.
#
# The bench used to hold its own ten, composed here, and the game held four of
# its own computed from the wall's width. Two sets of numbers for one question
# -- where are the holes in a shop wall -- and nothing to stop them drifting the
# moment either was edited. `ShopScene.ARRANGEMENTS` is the answer now, and this
# reads it, so a layout dragged into shape here and written back there shows up
# in the bench next build.
SHOP_GD = os.path.join(TKG, "scripts", "ui", "ShopScene.gd")


def _gd_arrangements(path=None):
    """`ShopScene.ARRANGEMENTS`, as a list of {order, cuts}.

    Brace-matched rather than regexed whole: the table is nested and a single
    pattern across it either stops at the first `}` or swallows the lot.
    """
    src = io.open(path or SHOP_GD, encoding="utf-8").read()
    # Past the `=`, or the first bracket found is the one in `Array[Dictionary]`
    # and the table read as the single word "Dictionary".
    i = src.index("=", src.index("const ARRANGEMENTS"))
    i = src.index("[", i)
    depth, j = 0, i
    while j < len(src):
        if src[j] == "[":
            depth += 1
        elif src[j] == "]":
            depth -= 1
            if depth == 0:
                break
        j += 1
    body = src[i + 1:j]
    rows, depth, start = [], 0, None
    for k, ch in enumerate(body):
        if ch == "{":
            if depth == 0:
                start = k
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth == 0:
                rows.append(body[start:k + 1])
    out = []
    for row in rows:
        order = int(re.search(r"order\s*=\s*(\d+)", row).group(1))
        cuts = []
        for m in re.finditer(r"\{([^{}]*)\}", row):
            piece = m.group(1)
            skin = re.search(r'skin\s*=\s*&"(\w+)"', piece)
            if skin:
                cuts.append({"skin": skin.group(1),
                             "x": int(re.search(r"x\s*=\s*(-?\d+)", piece).group(1)),
                             "y": int(re.search(r"y\s*=\s*(-?\d+)", piece).group(1))})
                continue
            door = re.search(r"door\s*=\s*(-?\d+)", piece)
            if door:
                cuts.append({"door": int(door.group(1))})
        out.append({"order": order, "cuts": cuts})
    return out


# Where the rack and the till stand for each of the four furniture orders. The
# game lays these out in an HBox and never writes an x down; the bench needs
# one, so the orders are spelled out here -- the only numbers in this file that
# describe the game rather than come from it.
def _furniture(order, W):
    edge = 34
    mid = (W - TILL_W) // 2
    if order == 1:
        return W - RACK_W - edge, edge
    if order == 2:
        return edge, mid
    if order == 3:
        return W - RACK_W - edge, mid
    return edge, W - TILL_W - edge


NAMES = ["band and rail", "the arch", "two ports", "double window",
         "slots and vitrine", "torn hull", "shopfront", "bay and crack",
         "canted", "band over crack"]


def seed_layouts(first_backdrop):
    """The game's ten shop fit-outs, to open in the bench and drag about.

    THE BACKDROP IS NOT PART OF A LAYOUT. Which hall is behind the wall comes
    off the station's seed in the game, so a fit-out has no business naming one.
    Each layout opens on a different installed backdrop purely so the sheet does
    not show the same hall ten times; switch it freely, it changes nothing about
    the layout.
    """
    W = PANEL[0]
    lay = []
    rows = _gd_arrangements()
    for i, row in enumerate(rows):
        items = []
        for cut in row["cuts"]:
            if "door" in cut:
                items.append(_door(cut["door"]))
            elif cut["skin"] in OPENINGS:
                items.append(_open(cut["skin"], cut["x"], cut["y"]))
        rack_x, till_x = _furniture(row["order"], W)
        items.append({"type": "shelf", "boards": 2, "x": rack_x})
        items.append({"type": "till", "x": till_x})
        name = NAMES[i] if i < len(NAMES) else "layout %d" % i
        lay.append({"name": "%d %s" % (i, name),
                    "room": {"wall": ROOMS[i % len(ROOMS)], "floor": "current"},
                    "backdrop": {"id": VIEWS[(i * 7 + 3) % len(VIEWS)], "auto": True},
                    "items": items})
    return lay

def main():
    out_path = os.path.join(HERE, "out", "room-bench.html")
    if "--out" in sys.argv:
        out_path = sys.argv[sys.argv.index("--out") + 1]
    DECKS = _decks()
    backdrops = []
    for f in sorted(os.listdir(STATION)):
        if f.startswith("backdrop_") and f.endswith(".png"):
            # DRAWN AT ITS OWN SIZE. A window shows a lot of the world, so the
            # view wants to be wide rather than close -- and this is as small as
            # it can be drawn and still cover the wall: 808 across against 740,
            # 284 to 352 down against the 353 above the floor.
            backdrops.append({"id": f[9:-4], "src": b64(f), "scale": 1,
                              "size": png_size(f), "deck": DECKS.get(f[9:-4], 0),
                              "label": f[9:-4] + " (wall-size)"})
    # The single views (`view_*`) are not offered: tried behind the whole wall,
    # every one read as too close, and only the wall-size promenade was kept.
    # `--stage DIR`: candidates not yet installed -- `bd_<name>.png` already at
    # wall size, `prop_<layer>_<name>.png` already doubled. Judged in the bench,
    # behind real openings, before any of it goes into the game.
    lampskins = {}
    props, walls, floors = [], [], []
    skins = {"shelf": {}, "till": {}, "door": {}, "opening": {}}
    # THE OPENINGS THE GAME HAS, loaded the way the game loads them: the sprite,
    # and the holes out of `opening_holes.json`. They used to reach the bench
    # only through `--stage`, which was right while they were candidates and
    # wrong the moment they shipped -- a seeded layout would name `arch` and
    # then have no arch to draw. A `--stage` copy still overrides, so a recut
    # can be judged against the installed set.
    if os.path.exists(HOLES_JSON):
        for name, entry in sorted(json.load(io.open(HOLES_JSON, encoding="utf-8")).items()):
            png = os.path.join(STATION, "opening_%s.png" % name)
            if not os.path.exists(png):
                continue
            skins["opening"][name] = {"src": _ref(png, "opening_%s.png" % name),
                                      "size": (entry["w"], entry["h"]),
                                      "runs": entry["runs"]}
    if "--stage" in sys.argv:
        stage = sys.argv[sys.argv.index("--stage") + 1]

        def sb64(path):
            return _ref(path, os.path.basename(path))

        def ssize(path):
            with open(path, "rb") as f:
                head = f.read(24)
            return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")

        for f in sorted(os.listdir(stage)):
            path = os.path.join(stage, f)
            if f.startswith("bd_") and f.endswith(".png"):
                backdrops.insert(0, {"id": f[3:-4], "src": sb64(path), "scale": 1,
                                     "size": ssize(path), "label": f[3:-4] + " (new)"})
            elif f.startswith("plate_") and f.endswith(".png"):
                # A WALL AND ITS FLOOR AS ONE PLATE, generated together so they
                # match, already at the room's size with the seam on the floor line.
                walls.append({"id": f[6:-4], "src": sb64(path), "size": ssize(path)})
            elif f[:6] in ("rack2_", "rack3_") and f.endswith(".png"):
                # STYLES: the same rack, till or door in another look, aligned to
                # the same boards, screen and opening as the standard one.
                skins["shelf"].setdefault(f[6:-4], {})[f[4]] = {"src": sb64(path), "size": ssize(path)}
            elif f.startswith("till_") and f.endswith(".png"):
                skins["till"][f[5:-4]] = {"src": sb64(path), "size": ssize(path)}
            elif f.startswith("door_") and f.endswith(".png"):
                skins["door"][f[5:-4]] = {"src": sb64(path), "size": ssize(path)}
            elif f.startswith("open_") and f.endswith(".png"):
                # A WHOLE OPENING AS ONE SPRITE, its hole already transparent.
                # Unlike a window it is not nine-sliced and does not resize: a
                # generated frame has no middle that tiles, and the shapes worth
                # having -- an arch, a breach, a ribbon -- are not rectangles to
                # be stretched anyway.
                skins["opening"].setdefault(f[5:-4], {}).update(
                    {"src": sb64(path), "size": ssize(path)})
            elif f.startswith("hole_") and f.endswith(".png"):
                # THE HOLE AS RECTANGLES, not as a second picture. Which
                # transparent pixels are the opening and which are the air round
                # the frame cannot be told from the sprite, so it has to be
                # recorded -- but shipping it as a mask image meant an opening
                # needed TWO pictures and offscreen compositing, and drew wrong
                # whenever only one of the two had arrived. As runs of pixels it
                # is data: the bench clips to them and draws the view exactly
                # the way a window does.
                skins["opening"].setdefault(f[5:-4], {})["runs"] = hole_runs(path)
            elif f.startswith("lampskin_") and f.endswith(".png"):
                lampskins[f[9:-4]] = {"src": sb64(path), "size": ssize(path)}
            elif f.startswith("prop_") and f.endswith(".png"):
                layer, name = f[5:-4].split("_", 1)
                props.append({"id": name, "layer": layer, "src": sb64(path),
                              "size": ssize(path),
                              "hang": layer == "near" and not name.startswith("railing")})
    # AN OPENING WITH NO HOLE IS NOT AN OPENING. `strip` reached the bench as a
    # stray `hole_strip.png` in the stage folder that was entirely empty: the
    # sprite is 82% transparent and nothing was marked as hole, so it drew a
    # frame with the WALL behind it and read as an opening you could see
    # straight through. Anything in this state is dropped and named, because a
    # missing opening is obvious and a see-through one looks like a bug in the
    # art.
    _hollow = [k for k, v in skins["opening"].items()
               if not v.get("runs") or not v.get("src")]
    for k in _hollow:
        del skins["opening"][k]
    if _hollow:
        print("  dropped %d opening(s) with no hole: %s"
              % (len(_hollow), ", ".join(sorted(_hollow))))

    # SAMPLE STOCK, so the shelves have parts on them: one of every footprint in
    # the catalogue, with a rarity each, drawn the way `ShelfDisplay` stands them.
    MODS = os.path.join(TKG, "art", "sprites", "modules")
    sample = [("brass", 0, 18), ("coldsights", 2, 64), ("optics", 1, 31),
              ("blowout", 1, 46), ("coolant", 3, 129), ("braceframe", 0, 72),
              ("cryobat", 4, 372), ("lattice", 2, 115), ("beam", 1, 88), ("widow", 3, 236)]
    parts = []
    for name, rarity, price in sample:
        path = os.path.join(MODS, name + ".png")
        if os.path.exists(path):
            with open(path, "rb") as f:
                raw = f.read()
            parts.append({"id": name, "rarity": rarity, "price": price,
                          "src": "data:image/png;base64," + base64.b64encode(raw).decode("ascii"),
                          "size": (int.from_bytes(raw[16:20], "big"), int.from_bytes(raw[20:24], "big"))})
    data = {
        "parts": parts,
        "props": props, "walls": walls, "floors": floors, "skins": skins,
        "panel": PANEL, "floor_y": FLOOR_Y,
        "wall": b64("room_wall.png"),
        "frames": {k: {"src": b64(v[0]), "margin": v[1], "size": png_size(v[0])}
                   for k, v in FRAMES.items()},
        "door": {"src": b64("frame_door.png"), "margin": 18, "size": png_size("frame_door.png")},
        "ports": {"src": b64("frame_ports.png"), "size": png_size("frame_ports.png")},
        # THE RACK, cut for parts at 1x: each board a 6 x 2 strip of 20px cells,
        # two boards or three.
        "shelves": {str(n): {"src": b64("shop_shelf%d.png" % n),
                             "size": png_size("shop_shelf%d.png" % n),
                             "boards": [59, 122, 185][:n]} for n in (2, 3)},
        "till": {"src": b64("shop_counter.png"), "size": png_size("shop_counter.png"),
                 "desk": 96},
        # THE LAMPS THE GAME HANGS OVER THE ROOM, which the bench drew none of.
        # A layout arranged without them is arranged blind: the count comes from
        # how built-up the station is (2 outpost, 3 settlement, 4 city, 6
        # capital) and the positions are fixed at w*(i+0.5)/n, so a prop can be
        # placed exactly where a lamp will hang and nothing here would say so.
        "lamp": {k: {"src": b64("lamp_%s.png" % k), "size": png_size("lamp_%s.png" % k)}
                 for k in ("hood", "cone", "pool")},
        # GENERATED FIXTURES. The procedural hood is three rectangles and looks
        # it beside the rest of the room; these are drawn the way the props
        # were. The cone and the pool stay greyscale masks -- they are the
        # LIGHT, and the bench tints them, which is how one pair of sprites
        # lights a warm promenade and a cold lab.
        "lampskins": lampskins,
        "walk": _walk(),
        "walkers": _walkers(),
        "backdrops": backdrops,
        "seed": seed_layouts(backdrops[0]["id"] if backdrops else "current"),
    }
    html = io.open(TEMPLATE, encoding="utf-8").read()
    _apply_cuts(data)
    html = html.replace("__DATA__", json.dumps(data))
    # A STALE PAGE LOOKS EXACTLY LIKE A BROKEN ONE, and there was no way to
    # tell them apart from a screenshot. Every build gets a stamp the page
    # prints in its toolbar.
    html = html.replace("__BUILD__", _stamp())
    _check_walk(data.get("walk", {}), data["backdrops"])
    _check_glow_keys(html, data)
    _check_flicker(html)
    _check_stage_shadows()
    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    io.open(out_path, "w", encoding="utf-8", newline="\n").write(html)
    print("room bench  %s  %d KB  %d backdrops, %d seed layouts"
          % (out_path, os.path.getsize(out_path) // 1024,
             len(data["backdrops"]), len(data["seed"])))
    # THE PAGE IS RUN BEFORE IT IS CALLED BUILT. Twice now a careless edit has
    # deleted a function the drawing needs, and twice it reached Jon's browser
    # because nothing here executed the script. `bench_check.js` loads it
    # against a stub DOM and calls gallery, ui and draw.
    import subprocess
    check = os.path.join(HERE, "bench_check.js")
    if os.path.exists(check):
        r = subprocess.run(["node", check, out_path], capture_output=True, text=True)
        out = (r.stdout + r.stderr).strip()
        bad = r.returncode != 0 or "THREW" in out
        label = "FAILED" if bad else "ok"
        print("  check: " + label + " -- " + out.replace(chr(10), " | "))
        if bad:
            return 1
    # AND THEN AGAINST REAL PIXELS. `bench_check.js` runs the page against a
    # stub whose `getImageData` returns undefined, so every routine that reads
    # pixels -- the lit panel on a vending machine, the pilots on an opening,
    # the backdrop's tone -- falls into its own try/catch and reports nothing
    # found. It went green on a feature that drew nothing at all, three builds
    # running. `bench_probe.js` backs the canvas with the real sprites, calls
    # the page's own draw(), and records what was actually painted.
    # AND THE PAGE MUST BE OPERABLE, not merely drawable. `bench_probe.js`
    # draws; it does not click. Three freezes reached Jon looking identical --
    # "stuck on a layout" -- because an exception anywhere in a frame aborts
    # the rest of it, and a stubbed DOM never throws where a browser would.
    click = os.path.join(HERE, "bench_click.js")
    pixdir = os.path.join(os.path.dirname(out_path), "pix")
    if os.path.exists(click) and os.path.exists(os.path.join(pixdir, "_meta.json")):
        rc = subprocess.run(["node", click, out_path, pixdir],
                            capture_output=True, text=True)
        txt = (rc.stdout + rc.stderr).strip()
        lines = [l for l in txt.split(chr(10))
                 if l and not l.startswith("bench: could not load")]
        tail = lines[-1] if lines else "(no output)"
        print("  clicks: " + ("FAILED" if rc.returncode else "ok") + " -- " + tail)
        if rc.returncode:
            print(txt)
            return 1

    probe = os.path.join(HERE, "bench_probe.js")
    pix = os.path.join(os.path.dirname(out_path), "pix")
    if os.path.exists(probe) and os.path.exists(os.path.join(pix, "_meta.json")):
        r = subprocess.run(["node", probe, out_path, pix], capture_output=True, text=True)
        out = (r.stdout + r.stderr).strip()
        tail = out.strip().split(chr(10))[-1] if out else "(no output)"
        bad = r.returncode != 0 or "stays dark" in out or "THREW" in out
        print("  probe: " + ("FAILED" if bad else "ok") + " -- " + tail)
        if bad:
            print(out)
            return 1
    elif os.path.exists(probe):
        print("  probe: skipped -- no pixel dump at %s" % pix)
    if ASSETS:
        # The publish step needs {published path: file on disk}; write it out
        # rather than making whoever publishes it reconstruct the list.
        man = os.path.join(os.path.dirname(out_path), "assets.json")
        io.open(man, "w", encoding="utf-8").write(
            json.dumps(ASSETS, indent=1, sort_keys=True))
        print("  %d files beside it, listed in %s" % (len(ASSETS), man))


if __name__ == "__main__":
    main()
