"""Frames on PixelLab -> an installed walk strip, without a judgement call.

    python tools/walker_roll.py <manifest.json> [--dry]

The manifest is {"<name>": ["<frame url>", ...], ...} -- whatever
`get_character` handed back. Everything after that is arithmetic:

    download -> find the true lap -> trim -> choose how many of those frames
    to keep -> install -> one line of report

WHY THIS EXISTS. Every walker so far cost eight separate decisions from me:
how long is the lap, is that the half cycle, which phase to halve on, does the
stride reading agree with the other stride reading, is it in the jitter band.
Each one was a chance to be wrong and several times I was. A cast of seventy
cannot be built that way -- not because of the generations, which are cheap,
but because eight judgement calls times seventy is a week of me being the
bottleneck. All eight are now measurements with a rule attached.

WHAT IS STILL NOT AUTOMATED, deliberately: whether the character is any good.
That is Jon's, and it is why this prints a contact sheet rather than a verdict.
"""

import io
import json
import os

import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "tkg", "art", "tools"))

import walk_period  # noqa: E402
import walker_install  # noqa: E402

WALK_PACE = walker_install.WALK_PACE

# The band the eye reads as footsteps rather than shimmer.
#
# ONLY TWO POINTS ON THIS CURVE WERE EVER ACTUALLY JUDGED: Jon rejected a cycle
# playing 6.3 a second as jitter and accepted one playing 3.4. "Five" is an
# interpolation between them, not a measurement, and treating it as a cliff
# costs more than it saves -- a 16-frame lap landing at 5.16 would be halved to
# 8 frames at 2.58, throwing away half the smoothness to dodge a number nobody
# has seen fail. So the ceiling sits at 5.5, nearer the midpoint of what is
# known, and 4.5 is what a cycle aims for.
FPS_MAX = 5.5
FPS_AIM = 4.5

CACHE = os.path.join(HERE, "out", "_frames")


def fetch(url, path):
    # A manifest entry may be a local file -- the character download endpoint
    # hands back every animation in one zip, which is both faster and far
    # cheaper than pulling a few hundred signed URLs through a conversation.
    if not str(url).startswith("http"):
        return os.path.abspath(url)
    if os.path.exists(path) and os.path.getsize(path) > 200:
        return path
    with urllib.request.urlopen(url, timeout=60) as r:
        d = r.read()
    # A short read is a truncated PNG, and a truncated PNG fails later in
    # pixeltools with a struct error that says nothing about the download.
    # One of sixteen arrived at 16 bytes the first time this ran.
    if len(d) < 200:
        raise IOError("%s came back %d bytes" % (url, len(d)))
    io.open(path, "wb").write(d)
    return path


def lap(paths):
    """-> the number of frames the walk actually takes.

    Colour, not silhouette. Side on, a walker at the half cycle is nearly its
    own mirror, so the silhouette peaks at half the true period and would ship
    a cycle whose near and far legs trade shading every step. Seen on the very
    first character this ran against.
    """
    w = h = None
    frames = []
    for p in paths:
        fw, fh, sil, rgb = walk_period.load(p)
        if w is None:
            w, h = fw, fh
        frames.append((sil, rgb))
    rows = list(walk_period.period(frames, w, h))
    pick, _top, _base = walk_period.decide(rows, len(frames))
    return pick


def choose(n, cycle_px):
    """Which frames of an n-frame lap to keep, so it plays inside the band.

    Frames advance by DISTANCE, so frames a second is pace x frames / cycle.
    Keeping every k-th frame divides the rate by k for free -- no new art. Take
    the smallest k that lands under the ceiling, because every frame dropped is
    smoothness dropped.

    Only k that divides n evenly is allowed. An uneven subsample leaves the
    wrap from the last frame to the first a part-step short, which is a hitch
    once per cycle in the one place a single play never shows.
    """
    best = None
    for k in range(1, max(2, n // 3 + 1)):
        if n % k:
            continue
        kept = n // k
        if kept < 4:
            continue
        fps = WALK_PACE * kept / float(cycle_px)
        if fps > FPS_MAX:
            continue
        score = abs(fps - FPS_AIM)
        if best is None or score < best[0]:
            best = (score, k, kept, fps)
    if best is None:
        # Nothing fits: keep the fewest frames that divide evenly and say so.
        ks = [k for k in range(1, n + 1) if n % k == 0 and n // k >= 4]
        k = max(ks) if ks else 1
        kept = n // k
        return k, kept, WALK_PACE * kept / float(cycle_px), False
    return best[1], best[2], best[3], True


def roll(name, urls, dry=False):
    d = os.path.join(CACHE, name)
    os.makedirs(d, exist_ok=True)
    paths = []
    for i, u in enumerate(urls):
        paths.append(fetch(u, os.path.join(d, "%d.png" % i)))

    n = lap(paths)
    lapped = paths[:n]

    # The cycle distance is measured on the TRIMMED lap -- a strip still
    # carrying a partial second lap fits a stride that explains neither. Built
    # under the real name so nothing temporary is left in the station folder;
    # if a subsample wins it is rebuilt over the top a moment later.
    out, meta = walker_install.build(name, lapped)
    cycle = meta["cycle"]

    k, kept, fps, fitted = choose(n, cycle)
    frames = lapped[::k]

    row = {
        "name": name, "returned": len(urls), "lap": n, "keep_every": k,
        "frames": kept, "cycle": round(cycle, 1), "fps": round(fps, 2),
        "in_band": fitted, "frame_h": meta["frame_h"],
    }
    if dry:
        os.remove(out)
        return row, None

    if k > 1:
        out, meta = walker_install.build(name, frames)
    m2 = meta
    row["advance"] = m2["advance"]
    row["frame_h"] = m2["frame_h"]
    row["frame_w"] = m2["frame_w"]
    row["cycle"] = round(m2["cycle"], 1)
    row["fps"] = round(WALK_PACE / m2["advance"], 2)
    _n, bad, _c, skate = walker_install.foot_report(
        out, m2["frame_w"], m2["advance"])
    row["foot"] = len(bad)
    row["skate"] = skate
    m2["foot_wander"] = len(bad)
    m2["skate"] = round(skate, 3)
    m2["fps"] = row["fps"]
    m2["pace"] = WALK_PACE
    m2["lap"] = n
    # HOW SURE THE STRIDE IS -- the BAND, not the fit.
    #
    # walk_stride reports both how well one advance explained every frame
    # ("fit") and the band of advances that explained them nearly as well.
    #
    # FIT IS NOT A QUALITY SIGNAL AND MUST NOT BE GATED ON. It is an average
    # over pairs, so a six-frame cycle and a sixteen-frame cycle are not on the
    # same scale at all. Gated at 0.5 it rejected seven of eight new walkers --
    # and also dock_walk, the one Jon had already approved, which scores 0.26,
    # worse than every walker it was being used to reject. A threshold that
    # fails the reference is measuring the wrong thing.
    #
    # The band is scale-free and does track what Jon sees:
    #     hauler     0%   the cleanest of the batch
    #     dock_walk  6%   approved
    #     cargo     19%   "the cargo's foot slips"
    #     elder     33%   "the walking stick is glitching out"
    # A wide band means the soles carry too little detail to pin the advance
    # down, and a stride nobody can measure is a boot that skates -- the body
    # is being moved by a number that was a guess.
    lo, hi = m2.get("within_3pct", [m2["advance"], m2["advance"]])
    row["fit"] = m2.get("fit", 0.0)
    row["band"] = 0.0 if not m2["advance"] else (hi - lo) / float(m2["advance"])
    # THE GATE. Not the fit (not comparable across frame counts, and it failed
    # the approved reference) and not the band (guard scored 0% and slipped).
    # How far the planted boot misses its own stride is the only measure that
    # has agreed with every call Jon has made.
    row["shaky"] = skate > 0.25

    # A CYCLE THIS SHORT IS NOT A WALK, and saying so is not a matter of taste.
    # A person's stride is about 0.75 of their height; the shortest Jon has
    # ever accepted is 0.28, on a shuffling elder. The clown "cone" came back
    # with a 5px cycle on a 73px figure -- 0.07 -- which made the optimiser
    # report a 1px advance and the room play it at 20 frames a second. That is
    # the generator handing back a figure marking time, not a take to judge.
    ratio = m2["cycle"] / float(m2["frame_h"]) if m2["frame_h"] else 0
    row["ratio"] = ratio
    row["broken"] = ratio < 0.20
    return row, m2


def main(argv):
    dry = "--dry" in argv
    argv = [a for a in argv if a != "--dry"]
    man = json.load(io.open(argv[0], encoding="utf-8"))

    idx = {}
    if os.path.exists(walker_install.INDEX) and not dry:
        idx = json.load(io.open(walker_install.INDEX, encoding="utf-8"))

    print("%-13s %4s %4s %6s %7s %6s %5s %5s %5s %5s"
          % ("name", "got", "lap", "frames", "cycle", "px/f", "fps", "foot",
             "skate", "band"))
    rows = []
    for name in sorted(man):
        try:
            row, meta = roll(name, man[name], dry)
        except Exception as e:  # one bad cycle must not stop the batch
            print("%-15s FAILED  %s" % (name, e))
            continue
        rows.append(row)
        if meta:
            idx[name] = meta
        print("%-13s %4d %4d %6d %7.1f %6.2f %5.2f %5s %4.0f%% %4.0f%% %s%s"
              % (name, row["returned"], row["lap"], row["frames"],
                 row["cycle"], row.get("advance", 0), row["fps"],
                 row.get("foot", "-"), 100 * row.get("skate", 0),
                 100 * row.get("band", 0),
                 "  NOT A WALK" if row.get("broken") else
                 ("  SKATES" if row.get("shaky") else ""),
                 "  OUT OF BAND" if not row["in_band"] else ""))

    if not dry:
        io.open(walker_install.INDEX, "w", encoding="utf-8",
                newline="\n").write(json.dumps(idx, indent=1, sort_keys=True))
        print("\n%d installed, index has %d" % (len(rows), len(idx)))


if __name__ == "__main__":
    main(sys.argv[1:])
