"""Roll station openings against PixelLab's HTTP API and write the PNGs to disk.

    python tools/open_roll.py <name> [<name> ...] [--takes N] [--strength S]
    python tools/open_roll.py --all [--takes N]

WHY NOT THE MCP TOOL. `create_image_pixflux` returns the picture inline for
looking at and gives back a job id, but no URL the shell can fetch -- so a take
can be judged and never installed. The public API is a single POST that answers
with the PNG as base64 in the body, which is the same generator and the same
cost, and it lands in a file. `PIXELLAB_API_KEY` is already in the environment.

WHAT THE INIT FRAME IS. Measured over nine probe generations:

  * a keeper as the init gives the KEEPER'S SHAPE -- a hexagon prompt and a
    porthole prompt both came back as arches. init_image does not guide the
    silhouette, it sets it.
  * the opening's own sprite as the init gives the right shape and brings its
    SPARSENESS with it, which is the fault being fixed.

So `open_init3/` carries both: a keeper's plate stretched over the whole
rectangle, the target's window punched through it from the hole table, and the
target's own frame laid back on top. Bare wall in those frames is 0%, against
7-70% in the sprites they replace.
"""

import base64
import io
import json
import os
import sys
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
TKG = os.path.abspath(os.path.join(HERE, "..", "tkg"))
STATION = os.path.join(TKG, "art", "sprites", "station")
INIT = os.path.join(TKG, "art", "ref", "open_init3")
OUT = os.path.join(HERE, "out", "openrolls")
API = "https://api.pixellab.ai/v1/generate-image-pixflux"

# Parts, never the category: naming "porthole" or "window" lets one noun
# overwrite the rest of the prompt. No readable lettering anywhere.
BASE = ("a heavy steel surround filling the frame edge to edge, %s, "
        "bolted flanges, a deep sill along the bottom, dark blue-grey plate "
        "with warm lit glass behind it, worn paint, no text, no letters, "
        "flat elevation, no perspective")

PARTS = {
    "angled":     "glass canted away from the wall, a folded corner post, a bolted return down each side",
    "bay":        "a deep projecting sill, three panes in one surround, brackets under the sill",
    "breach":     "plating peeled back around a hole, a welded patch frame holding it, bare ribs",
    "canopy":     "a slatted awning across the top, the surround carried down past it to the sill",
    "clerestory": "a long shallow light-well, evenly spaced mullions, a lintel above and a sill below",
    "cracked":    "a split pane, a braced strap across it, blank hazard tape with no markings",
    "double":     "two leaves sharing one heavy mullion, matching sills, a continuous head",
    "grid":       "a bolted bar grid over the glass, the bars thick enough to read, a solid surround",
    "hex":        "a six-sided pressure collar, bolts at every corner, a thick rim",
    "rail":       "a rounded viewport, a guard rail across the lower third, stanchions into the sill",
    "roundbig":   "a bolted collar round a circular light, a thick rim, a dogged handle below",
}

NEGATIVE = ("bare wall, empty corners, thin frame, floating pieces, text, "
            "letters, numbers, signage, perspective, vanishing point")


def _png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    return (int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big"))


def roll(name, seed, strength):
    init = os.path.join(INIT, "%s.png" % name)
    if not os.path.exists(init):
        raise SystemExit("no init frame for %s -- expected %s" % (name, init))
    w, h = _png_size(init)
    with open(init, "rb") as f:
        b64 = base64.b64encode(f.read()).decode("ascii")
    body = {
        "description": BASE % PARTS[name],
        "negative_description": NEGATIVE,
        "image_size": {"width": w, "height": h},
        "init_image": {"type": "base64", "base64": b64},
        "init_image_strength": strength,
        "shading": "detailed shading",
        "view": "side",
        "text_guidance_scale": 9,
        "seed": seed,
    }
    req = urllib.request.Request(
        API, data=json.dumps(body).encode("utf-8"),
        headers={"Authorization": "Bearer " + os.environ["PIXELLAB_API_KEY"],
                 "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as r:
        out = json.loads(r.read().decode("utf-8"))
    return base64.b64decode(out["image"]["base64"]), w, h


def main():
    argv = sys.argv[1:]
    takes = 4
    strengths = [110, 140, 170, 200]
    if "--takes" in argv:
        i = argv.index("--takes")
        takes = int(argv[i + 1])
        del argv[i:i + 2]
    if "--strength" in argv:
        i = argv.index("--strength")
        strengths = [int(argv[i + 1])]
        del argv[i:i + 2]
    names = sorted(PARTS) if "--all" in argv else [a for a in argv if not a.startswith("--")]
    if not names:
        raise SystemExit(__doc__.strip().splitlines()[2])
    os.makedirs(OUT, exist_ok=True)
    done = 0
    for name in names:
        for t in range(takes):
            s = strengths[t % len(strengths)]
            seed = 1000 + t * 7
            try:
                png, w, h = roll(name, seed, s)
            except urllib.error.HTTPError as e:
                print("  %s take %d FAILED %s: %s"
                      % (name, t + 1, e.code, e.read()[:160].decode("utf-8", "replace")))
                continue
            p = os.path.join(OUT, "%s_s%d_t%d.png" % (name, s, t + 1))
            with open(p, "wb") as f:
                f.write(png)
            done += 1
            print("  %-11s take %d  strength %-4d %dx%d  %5d bytes"
                  % (name, t + 1, s, w, h, len(png)))
    print("\n%d take(s) written to %s" % (done, OUT))


if __name__ == "__main__":
    main()
