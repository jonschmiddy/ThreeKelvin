"""The Custodian at boss size: 8 pixflux takes grown from tetra. HARD CAP 8.

    python boss.py <worktree> inits      # builds the init pictures (free)
    python boss.py <worktree> go <n>     # sends take n (0..7); refuses past the cap
    python boss.py <worktree> post       # strips, crops, measures, contact sheet

Key: PIXELLAB_API_KEY in the environment, never printed. Ledger: ledger.json.
Four ideas, two takes each: two with tetra as the init (scaled up; tetra
with a second cluster behind it), two from words alone. Every prompt names
the parts (pyramids, octahedra, spine, struts, core light) and never the
category (no ship, vessel, hull, station, boss).
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
WT = sys.argv[1]
TETRA = os.path.join(WT, "tools", "art_pool", "ships", "tetra.png")
API = "https://api.pixellab.ai/v1/generate-image-pixflux"
LEDGER = os.path.join(HERE, "ledger.json")
CAP = 8
CW, CH = 320, 144

NEG = ("planet, landscape, ground, horizon, sky, clouds, mountains, buildings, city, water, sea, "
       "text, letters, frame, border, picture frame, background scene, people, isometric, top-down view")

IDEAS = {
    "grown": ("a looming cluster of faceted dark-glass pyramids and octahedra joined point to point "
              "along a thin silver spine, one huge central octahedron twice the size of the others, "
              "cold blue-white light glowing inside its facets, tiny orange pinpoint lights at the "
              "vertices, sharp polished edges catching a cold rim light, side view, the cluster "
              "tapering to a point at the left"),
    "chain": ("a long chain of dark faceted glass pyramids, large in the middle and smaller toward both "
              "ends, each pyramid pointing up with its mirrored twin pointing down beneath it, threaded on "
              "a thin silver spine with black gaps between them, a pale cold glow seeping from the seams "
              "where they meet, orange pinpoint lights on the vertices, side view"),
    "core": ("a huge octahedron of black glass at the centre with a bright cold white core of light "
             "showing between its facets, flanked left and right by ranks of smaller dark glass pyramids "
             "pointing up and down, every pyramid held apart from the core by thin silver struts with "
             "black gaps between them, pinpoint orange lights on the vertices, side view"),
    "tiers": ("three tiers of dark glass pyramids stacked around a glowing pale blue sphere of light, "
              "held apart by thin silver rods, sharp faceted edges with cold blue highlights, a few orange "
              "pinpoint lights, the whole arrangement much wider than tall, its left end a single long "
              "point, side view"),
}
# take -> (idea, init or None, strength, seed)
TAKES = [
    ("grown", "init_scaled.png", 150, 11),
    ("grown", "init_scaled.png", 210, 12),
    ("chain", "init_pair.png", 130, 21),
    ("chain", "init_pair.png", 190, 22),
    ("core", None, None, 31),
    ("core", None, None, 32),
    ("tiers", None, None, 41),
    ("tiers", None, None, 42),
]


def tetra():
    im = Image.open(TETRA).convert("RGBA")
    im = im.transpose(Image.FLIP_LEFT_RIGHT)  # judged orientation (picks.json flip: true)
    return im.crop(im.getbbox())


def place(canvas, im, cx, cy):
    canvas.alpha_composite(im, (int(cx - im.width / 2), int(cy - im.height / 2)))


def inits():
    t = tetra()
    # 1. tetra grown 1.55x (nearest), centred: the same cluster, bigger
    big = t.resize((round(t.width * 1.55), round(t.height * 1.55)), Image.NEAREST)
    c = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    place(c, big, CW / 2, CH / 2)
    c.save(os.path.join(HERE, "init_scaled.png"))
    # 2. a longer chain: tetra 1.3x in front, a second copy at 1x behind it to the right
    c = Image.new("RGBA", (CW, CH), (0, 0, 0, 0))
    back = t.resize((round(t.width * 1.0), round(t.height * 1.0)), Image.NEAREST)
    place(c, back, CW * 0.70, CH / 2)
    front = t.resize((round(t.width * 1.3), round(t.height * 1.3)), Image.NEAREST)
    place(c, front, CW * 0.40, CH / 2)
    c.save(os.path.join(HERE, "init_pair.png"))
    t.save(os.path.join(HERE, "palette_tetra.png"))
    print("inits written", big.size)


def ledger():
    return json.load(open(LEDGER)) if os.path.exists(LEDGER) else {"spent": 0.0, "takes": []}


def b64(path):
    return base64.b64encode(open(path, "rb").read()).decode("ascii")


def go(n):
    L = ledger()
    if any(t["n"] == n for t in L["takes"]):
        sys.exit("take %d already made; nothing sent" % n)
    if L["spent"] + 1 > CAP or len(L["takes"]) >= CAP:
        sys.exit("cap: nothing sent")
    key = os.environ.get("PIXELLAB_API_KEY", "").strip()
    if not key:
        sys.exit("no key; nothing sent")
    idea, init, strength, seed = TAKES[n]
    body = {"description": IDEAS[idea], "negative_description": NEG,
            "image_size": {"width": CW, "height": CH}, "no_background": True,
            "view": "side", "direction": "west", "outline": "single color black outline",
            "shading": "detailed shading", "detail": "highly detailed", "text_guidance_scale": 8,
            "seed": seed, "color_image": {"type": "base64", "base64": b64(os.path.join(HERE, "palette_tetra.png"))}}
    if init:
        body["init_image"] = {"type": "base64", "base64": b64(os.path.join(HERE, init))}
        body["init_image_strength"] = strength
    t0 = time.time()
    req = urllib.request.Request(API, data=json.dumps(body).encode("utf-8"),
                                 headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=400) as r:
            out = json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        sys.exit("refused: HTTP %d %s" % (e.code, e.read()[:300].decode("utf-8", "replace")))
    u = out.get("usage") or {}
    os.makedirs(os.path.join(HERE, "raw"), exist_ok=True)
    tag = "t%d_%s" % (n, idea)
    open(os.path.join(HERE, "raw", tag + ".png"), "wb").write(base64.b64decode(out["image"]["base64"].split(",")[-1]))
    gens = float(u.get("generations", 0)) if u.get("type") == "generations" else None
    L["spent"] += gens if gens is not None else 1.0
    L["takes"].append(dict(n=n, tag=tag, idea=idea, init=init, strength=strength, seed=seed, usage=u,
                           seconds=round(time.time() - t0, 1)))
    json.dump(L, open(LEDGER, "w"), indent=1)
    print("take", tag, "usage", u, "spent now %.1f of %d" % (L["spent"], CAP))
    if gens is not None and gens != 1.0:
        print("USAGE NOT EXACTLY 1 GENERATION: STOP")
        sys.exit(2)


def strip(a, exact=False):
    """Transparent background: flood in from the border over the border's own colour."""
    if (a[..., 3] == 0).mean() > 0.2:
        a[..., 3] = np.where(a[..., 3] >= 128, 255, 0)
        return a
    h, w = a.shape[:2]
    # the background is the border's own few colours (pixflux dithers two
    # greys); flood over exactly those, in from the edge, so it stops at the
    # black outline and never punches into a facet of the same grey
    border = np.concatenate([a[0], a[-1], a[:, 0], a[:, -1]])[:, :3]
    cols = np.unique(border, axis=0)
    near = np.zeros((h, w), bool)
    if not exact:
        # one flat colour: near it, as before (a black field must not be
        # matched exactly, or it runs into the black glass)
        near = np.abs(a[..., :3].astype(int) - cols[0].astype(int)).sum(-1) < 40
    else:
        for c in cols:
            near |= (a[..., :3] == c).all(-1)
    seen = np.zeros((h, w), bool)
    st = [(y, x) for y in (0, h - 1) for x in range(w)] + [(y, x) for x in (0, w - 1) for y in range(h)]
    while st:
        y, x = st.pop()
        if 0 <= y < h and 0 <= x < w and near[y, x] and not seen[y, x]:
            seen[y, x] = True
            st += [(y + 1, x), (y - 1, x), (y, x + 1), (y, x - 1)]
    a[seen, 3] = 0
    a[~seen, 3] = 255
    return a


def post():
    L = ledger()
    os.makedirs(os.path.join(HERE, "takes"), exist_ok=True)
    try:
        F = ImageFont.truetype("C:/Windows/Fonts/consola.ttf", 15)
    except OSError:
        F = ImageFont.load_default()
    rows = []
    meta = []
    for t in sorted(L["takes"], key=lambda t: t["n"]):
        a = np.array(Image.open(os.path.join(HERE, "raw", t["tag"] + ".png")).convert("RGBA"))
        a = strip(a, t["idea"] in ("chain", "grown"))
        im = Image.fromarray(a)
        bb = im.getbbox()
        im = im.crop(bb) if bb else im
        im.save(os.path.join(HERE, "takes", t["tag"] + ".png"))
        m = np.array(im)[..., 3] > 0
        meta.append(dict(t, size=[im.width, im.height], fill=round(float(m.mean()), 3),
                         colours=int(len(np.unique(np.array(im)[m][:, :3], axis=0)))))
        rows.append((t, im))
    json.dump(meta, open(os.path.join(HERE, "takes.json"), "w"), indent=1)
    cw, ch = CW * 2 + 20, CH * 2 + 120
    sheet = Image.new("RGB", (cw * 2, ch * ((len(rows) + 1) // 2)), (11, 15, 22))
    d = ImageDraw.Draw(sheet)
    for i, (t, im) in enumerate(rows):
        x, y = (i % 2) * cw, (i // 2) * ch
        j = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
        sheet.paste(j, (x + 10 + (CW * 2 - j.width) // 2, y + 10 + (CH * 2 - j.height) // 2), j)
        txt = "take %d  %s  %s  %dx%d" % (t["n"], t["idea"], ("init %s @%d" % (t["init"], t["strength"])) if t["init"] else "words only",
                                         im.width, im.height)
        d.text((x + 10, y + CH * 2 + 16), txt, fill=(200, 210, 225), font=F)
        words = IDEAS[t["idea"]].split()
        line, ly = "", y + CH * 2 + 36
        for w_ in words:
            if len(line) + len(w_) > 88:
                d.text((x + 10, ly), line, fill=(120, 132, 150), font=F)
                ly += 17
                line = ""
            line += w_ + " "
        d.text((x + 10, ly), line, fill=(120, 132, 150), font=F)
    sheet.save(os.path.join(HERE, "takes_2x.png"))
    print(json.dumps([(m["tag"], m["size"], m["fill"]) for m in meta]))


cmd = sys.argv[2]
if cmd == "inits":
    inits()
elif cmd == "go":
    go(int(sys.argv[3]))
elif cmd == "post":
    post()
