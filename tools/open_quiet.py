"""Roll the openings as a frame and nothing else, into their own silhouette.

    python tools/open_quiet.py --all [--takes N]

THREE THINGS THE PROBES SETTLED, each one costing generations to learn:

  * `init_image` SETS the silhouette, it does not guide it. A keeper as init
    gave arches for a hexagon prompt and a porthole prompt alike.
  * `color_image` is what keeps it quiet. Jon rejected 45 takes as "so busy";
    measured, that was 61-250 colours against 13-43 in the four he kept, at
    near-identical edge density. Forcing the keepers' own palette brings it out
    of the generator at 24-32.
  * `no_background` does nothing here -- 0% transparent on every take. The
    generator fills its canvas and has no notion of where a sprite stops.

So the alpha is authored, not asked for: the old sprite's outline is the frame,
the hole table is the window, and everything else is dropped. That also means
no plate round the opening, which is what Jon asked for.
"""
import base64, json, os, sys
import urllib.request, urllib.error
sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)),
                                "..", "tkg", "art", "tools"))
import pixeltools  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
TKG = os.path.abspath(os.path.join(HERE, "..", "tkg"))
ST = os.path.join(TKG, "art", "sprites", "station")
INIT = os.path.join(TKG, "art", "ref", "open_init2")
PAL = os.path.join(TKG, "art", "ref", "open_palette.png")
OUT = os.path.join(HERE, "out", "opennoplate")
API = "https://api.pixellab.ai/v1/generate-image-pixflux"

# One frame, at most one feature. Six parts per prompt got six parts, stacked.
PARTS = {
    "angled":     "a steel window frame canted to one side, one row of bolts",
    "bay":        "a steel window frame with a deep sill",
    "breach":     "a torn steel hole with the plating peeled back",
    "canopy":     "a steel window frame under a slatted awning",
    "clerestory": "a long shallow steel window frame with even mullions",
    "cracked":    "a steel window frame with a split pane",
    "double":     "a steel window frame with two panes and one mullion",
    "grid":       "a steel window frame with thick bars across it",
    "hex":        "a six-sided steel window frame, one row of bolts",
    "rail":       "a rounded steel window frame with a guard rail",
    "roundbig":   "a round steel window frame, one row of bolts",
}
NEG = ("a plate behind it, a panel around it, a background, a border, clutter, "
       "many small parts, nested frames, corner brackets, labels, text, "
       "letters, numbers, gradients, noise, perspective")


def roll(name, strength, seed):
    ip = os.path.join(INIT, name + ".png")
    w, h, _ = pixeltools.decode(ip)
    body = {
        "description": PARTS[name] + ", dark blue-grey steel, worn paint, "
                                     "flat elevation, nothing behind it",
        "negative_description": NEG,
        "image_size": {"width": w, "height": h},
        "init_image": {"type": "base64",
                       "base64": base64.b64encode(open(ip, "rb").read()).decode()},
        "init_image_strength": strength,
        "color_image": {"type": "base64",
                        "base64": base64.b64encode(open(PAL, "rb").read()).decode()},
        "shading": "flat shading", "detail": "low detail", "view": "side",
        "text_guidance_scale": 7, "seed": seed,
    }
    req = urllib.request.Request(
        API, data=json.dumps(body).encode(),
        headers={"Authorization": "Bearer " + os.environ["PIXELLAB_API_KEY"],
                 "Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=300) as r:
        return base64.b64decode(json.loads(r.read())["image"]["base64"]), w, h


def shape(name, path):
    """Pour the take into the old sprite's outline; drop everything else."""
    H = json.load(open(os.path.join(ST, "opening_holes.json")))
    w, h, r = pixeltools.decode(path)
    _, _, o = pixeltools.decode(os.path.join(ST, "opening_%s.png" % name))
    hole = set()
    for y, a, ln in H[name]["runs"]:
        for x in range(a, a + ln):
            hole.add((x, y))
    for y in range(h):
        q = r[y]
        src = o[y]              # decode() hands back ROWS, not a flat buffer
        for x in range(w):
            if (x, y) in hole or src[x * 4 + 3] < 40:
                q[x * 4 + 3] = 0
    pixeltools.encode(path, w, h, r)
    cols = len({(r[y][x * 4], r[y][x * 4 + 1], r[y][x * 4 + 2])
                for y in range(h) for x in range(w) if r[y][x * 4 + 3] >= 40})
    return cols


def main():
    argv = sys.argv[1:]
    takes = 4
    if "--takes" in argv:
        i = argv.index("--takes"); takes = int(argv[i + 1]); del argv[i:i + 2]
    names = sorted(PARTS) if "--all" in argv else [a for a in argv if not a.startswith("--")]
    os.makedirs(OUT, exist_ok=True)
    strengths = [100, 130, 160, 190]
    print("name".ljust(12) + "take  strength  colours")
    for nm in names:
        for t in range(takes):
            s = strengths[t % len(strengths)]
            try:
                png, w, h = roll(nm, s, 3000 + t * 11)
            except urllib.error.HTTPError as e:
                print("  %s take %d FAILED %s" % (nm, t + 1, e.code)); continue
            p = os.path.join(OUT, "%s_n%d_t%d.png" % (nm, s, t + 1))
            open(p, "wb").write(png)
            print(nm.ljust(12) + str(t + 1).ljust(6) + str(s).ljust(10) + str(shape(nm, p)).rjust(7))


if __name__ == "__main__":
    main()
