"""THE IRISES REMADE BIG, AND CARGO 130_0 / 130_1 AT NATURAL PROPORTIONS (Jon: "The irises look bad, like a tiny hole in
a big room, can we remake those"; cargo "B"). Hard cap 20 generations for both jobs (ledger_remake.json).

Inits drawn in code at the new recess size (128 x 126):
  - an iris: its own take scaled 1.5x about its ring (nearest), so the ring fills ~78% of the recess height, its own
    wall behind, its red lamp housings at 1x back in the corners beside the ring, its hazard sill scaled with it;
  - a cargo bay: its own picture cut across at one row (below the clamp jaws / the hanging crate, above the crates
    under it), 48 rows of its own back wall put in there (each column's rows from the nearest column where the wall
    runs clear, a whole number of brick courses), so the chain and the clamp arm keep their length.
Each init set in Drum 3's taller entrance (184 x 168) and re-rendered by pixflux; the recess pasted back (`iris.post`).

    python remake.py --plan | --go <id> [--seed N] [--strength S] | --post <id> <tag>
"""
import base64, json, os, sys, time, urllib.request, urllib.error
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import iris  # noqa: E402

ST = iris.ST
CAP = 20
LEDGER = os.path.join(HERE, "ledger_remake.json")
W, H = 128, 126
JOBS = {
    "iris_90_0": dict(kind="iris", strength=200, seed=81000, ring=(36, 101, 3, 70), lamps=[(18, 5, 30, 32), (99, 5, 111, 32)]),
    "iris_90_1": dict(kind="iris", strength=200, seed=81100, ring=(38, 104, 2, 72), lamps=[(13, 12, 29, 24), (99, 12, 115, 24)]),
    "iris_220_1": dict(kind="iris", strength=200, seed=81200, ring=(37, 98, 6, 66), lamps=[(15, 12, 29, 27), (110, 12, 124, 27)]),
    "cargo_130_0": dict(kind="cargo", strength=300, seed=82000, cut=46, period=8),
    "cargo_130_1": dict(kind="cargo", strength=300, seed=82100, cut=30, period=4),
}
PROMPT_IRIS = ("Seen strictly head-on, a flat elevation: a tall landing-bay recess inside a riveted steel frame, a thin "
               "lip above and a deep lip below with small amber lamps along their edges, a strip of small amber lamps on "
               "the frame's right. Inside the recess, filling it: a huge round airlock iris door of six overlapping steel "
               "blades in a heavy bolted ring, the ring almost as tall as the recess, a pin of warm light where the "
               "blades meet, a red warning lamp in a housing in each upper corner beside the ring, yellow and black "
               "hazard paint along the sill under it. Pixel art, crisp dark outline, detailed shading. No text, no "
               "letters, no numbers, no signs, no plaques, no people.")
PROMPT_CARGO = ("Seen strictly head-on, a flat elevation: a tall landing-bay recess inside a riveted steel frame, a thin "
                "lip above and a deep lip below with small amber lamps along their edges, a strip of small amber lamps "
                "on the frame's right. Inside the recess: a cargo bay, dark brick back wall, crates stacked on the floor, "
                "short docking clamps and chains hanging from the ceiling, a cold blue light strip set into the floor. "
                "Pixel art, crisp dark outline, detailed shading. No text, no letters, no numbers, no people.")


def flat(k):
    return np.asarray(Image.open(os.path.join(ST, "src", "interiors", k + "_flat.png")).convert("RGB"))


def iris_init(k):
    j = JOBS[k]
    a = flat(k).astype(float)
    r0, r1, t0, t1 = j["ring"]
    cx, cy = (r0 + r1) / 2.0, (t0 + t1) / 2.0
    s = 1.5
    big = np.asarray(Image.fromarray(a.astype(np.uint8)).resize((int(round(128 * s)), int(round(78 * s))), Image.NEAREST)).astype(float)
    out = np.zeros((H, W, 3))
    # (its own wall behind: the wall columns left of the ring, tiled)
    wall = a[:, 2:max(3, r0 - 18)]
    for y in range(H):
        for x in range(W):
            out[y, x] = wall[min(77, int(y * 78 / H)), x % wall.shape[1]]
    ox, oy = int(round(W / 2 - cx * s)), int(round(H / 2 + 2 - cy * s))
    for y in range(big.shape[0]):
        for x in range(big.shape[1]):
            X, Y = x + ox, y + oy
            if 0 <= X < W and 0 <= Y < H:
                out[Y, X] = big[y, x]
    # the red lamps at their own size in the corners beside the ring
    for (lx0, ly0, lx1, ly1), side in zip(j["lamps"], (0, 1)):
        lamp = a[ly0:ly1, lx0:lx1]
        px = 3 if side == 0 else W - 3 - lamp.shape[1]
        out[8:8 + lamp.shape[0], px:px + lamp.shape[1]] = lamp
    return out


def cargo_init(k):
    j = JOBS[k]
    a = flat(k).astype(float)
    c, p = j["cut"], j["period"]
    Hh = a.shape[0]
    med = np.median(a, 1, keepdims=True)
    dev = np.abs(a - med).sum(-1)
    obj = dev > (np.median(dev, 1, keepdims=True) * 2.5 + 24)
    clear = ~obj[max(0, c - 2 * p):c + 2 * p].any(0)            # columns with plain wall about the cut
    band = np.zeros((48, W, 3))
    cols = np.nonzero(clear)[0]
    for x in range(W):
        if clear[x]:
            src = x
        else:
            # the nearest clear column a whole number of brick lengths away (the courses' joints line up)
            cand = cols[np.argsort(np.abs(cols - x))]
            src = int(cand[0]) if len(cand) else x
        blk = a[c - p:c, src]
        band[:, x] = np.concatenate([blk] * (48 // p), 0)
    return np.concatenate([a[:c], band, a[c:]], 0)


def init(k):
    rec = iris_init(k) if JOBS[k]["kind"] == "iris" else cargo_init(k)
    t = iris.plate().copy()
    t[iris.RY0:iris.RY1, iris.RX0:iris.RX1, :3] = np.clip(rec, 0, 255).astype(np.uint8)
    t[iris.RY0:iris.RY1, iris.RX0:iris.RX1, 3] = 255
    return t[iris.CY:iris.CY + iris.CH, iris.CX:iris.CX + iris.CW], rec


def ledger():
    return json.load(open(LEDGER)) if os.path.exists(LEDGER) else {"spent": 0.0, "takes": []}


def go(k, seed=None, strength=None):
    L = ledger()
    if L["spent"] + 1 > CAP:
        sys.exit("cap: nothing sent")
    key = os.environ.get("PIXELLAB_API_KEY", "").strip()
    if not key:
        sys.exit("no key; nothing sent")
    j = JOBS[k]
    seed = seed if seed is not None else j["seed"]
    strength = strength if strength is not None else j["strength"]
    ip = os.path.join(HERE, "inits_remake", k + ".png")
    body = {"description": PROMPT_IRIS if j["kind"] == "iris" else PROMPT_CARGO, "negative_description": iris.NEG,
            "image_size": {"width": iris.CW, "height": iris.CH}, "no_background": True, "view": "side",
            "outline": "single color black outline", "shading": "detailed shading", "detail": "highly detailed",
            "text_guidance_scale": 8, "seed": seed, "init_image": {"type": "base64", "base64": iris.b64(ip)},
            "init_image_strength": strength, "color_image": {"type": "base64", "base64": iris.b64(iris.palette(k))}}
    t0 = time.time()
    req = urllib.request.Request(iris.API, data=json.dumps(body).encode("utf-8"),
                                 headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            out = json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        sys.exit("refused: HTTP %d %s" % (e.code, e.read()[:300].decode("utf-8", "replace")))
    u = out.get("usage") or {}
    tag = "%s__s%d_%d" % (k, strength, seed)
    os.makedirs(os.path.join(HERE, "raw_remake"), exist_ok=True)
    open(os.path.join(HERE, "raw_remake", tag + ".png"), "wb").write(base64.b64decode(out["image"]["base64"].split(",")[-1]))
    gens = float(u.get("generations", 0)) if u.get("type") == "generations" else None
    L["spent"] += gens if gens is not None else 1.0
    L["takes"].append(dict(tag=tag, id=k, seed=seed, strength=strength, usage=u, seconds=round(time.time() - t0, 1)))
    json.dump(L, open(LEDGER, "w"), indent=1)
    print("take", tag, "usage", u, "spent now %.0f of %d" % (L["spent"], CAP))
    if gens != 1.0:
        print("USAGE NOT EXACTLY 1 GENERATION: STOP"); sys.exit(2)


def post(k, tag):
    ini = np.asarray(Image.open(os.path.join(HERE, "inits_remake", k + ".png")).convert("RGBA")).astype(float)
    raw = np.asarray(Image.open(os.path.join(HERE, "raw_remake", tag + ".png")).convert("RGBA")).astype(float)
    lum = lambda a: a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114
    li, lr = lum(ini), lum(raw)
    CH, CW = iris.CH, iris.CW
    outside = np.ones((CH, CW), bool)
    outside[iris.RY0 - iris.CY:iris.RY1 - iris.CY, iris.RX0 - iris.CX:iris.RX1 - iris.CX] = False
    outside &= ini[..., 3] > 0
    outside[:5] = outside[-5:] = False; outside[:, :5] = outside[:, -5:] = False
    best = None
    for dy in range(-4, 5):
        for dx in range(-4, 5):
            e = float(np.abs(np.roll(np.roll(lr, -dy, 0), -dx, 1) - li)[outside].mean())
            if best is None or e < best[0]:
                best = (e, dx, dy)
    e, dx, dy = best
    y0, x0 = iris.RY0 - iris.CY + dy, iris.RX0 - iris.CX + dx
    rec = raw[y0:y0 + H, x0:x0 + W, :3]
    os.makedirs(os.path.join(HERE, "joined_remake"), exist_ok=True)
    Image.fromarray(rec.astype(np.uint8)).save(os.path.join(HERE, "joined_remake", tag + "_flat.png"))
    print(k, tag, "shift", dx, dy, "align error %.1f" % e)


if __name__ == "__main__":
    a = sys.argv[1:]
    if "--plan" in a:
        os.makedirs(os.path.join(HERE, "inits_remake"), exist_ok=True)
        for k in JOBS:
            can, rec = init(k)
            Image.fromarray(can).save(os.path.join(HERE, "inits_remake", k + ".png"))
            Image.fromarray(np.clip(rec, 0, 255).astype(np.uint8)).save(os.path.join(HERE, "inits_remake", k + "_recess.png"))
        print("inits written; spent %.0f of %d" % (ledger()["spent"], CAP))
    elif "--go" in a:
        k = a[a.index("--go") + 1]
        go(k, int(a[a.index("--seed") + 1]) if "--seed" in a else None, int(a[a.index("--strength") + 1]) if "--strength" in a else None)
    elif "--post" in a:
        post(a[a.index("--post") + 1], a[a.index("--post") + 2])


def lit(k, c):
    """the entrances stream's lit-bay rule (interiors.lit_version) with this picture's own lights: the irises' red
    corner lamps, the pin of light at the ring's middle and the sill; the cargo bays' cold floor strip"""
    Hh, Ww = c.shape[:2]
    CY2 = (40, 120, 140)
    if JOBS[k]["kind"] == "iris":
        L = [(10, 16, 16, iris.RED2, 0.75), (118, 16, 16, iris.RED2, 0.75), (64, 63, 52, iris.WARM[3], 0.35),
             (64, Hh - 10, 30, iris.WARM[2], 0.25)]
    else:
        L = [(x, Hh - 7, 18, CY2, 0.4) for x in range(10, Ww - 6, 20)]
    lum = c[..., 0] * 0.299 + c[..., 1] * 0.587 + c[..., 2] * 0.114
    emis = (lum > 170) | ((c[..., 0] > 140) & (c[..., 0] - c[..., 2] > 70))
    out = c * 0.62
    yy, xx = np.mgrid[0:Hh, 0:Ww]
    acc = np.zeros((Hh, Ww)); tint = np.zeros((Hh, Ww, 3))
    for (x, y, r, col, kk) in L:
        v = np.clip(1 - np.hypot(xx - x, yy - y) / r, 0, 1) ** 1.5 * kk
        acc += v
        tint += v[..., None] * np.array(col, float)
    q = np.clip(acc, 0, 1.6) * 4
    lo = np.floor(q); lo = lo + ((q - lo) > iris.BAY[yy % 4, xx % 4]); s = lo / 4
    col = tint / np.maximum(acc[..., None], 1e-6)
    out = out * (1 + 2.2 * s[..., None]) + col * 0.16 * s[..., None]
    out[emis] = c[emis]
    return np.clip(out, 0, 255)


def keep(k, tag):
    """the chosen take into the repo's src/interiors/tall/ (flat and lit)"""
    f = np.asarray(Image.open(os.path.join(HERE, "joined_remake", tag + "_flat.png")).convert("RGB")).astype(float)
    d = os.path.join(ST, "src", "interiors", "tall")
    os.makedirs(d, exist_ok=True)
    Image.fromarray(f.astype(np.uint8)).save(os.path.join(d, k + "_flat.png"))
    Image.fromarray(lit(k, f).astype(np.uint8)).save(os.path.join(d, k + "_lit.png"))
    print("kept", k, tag)


if __name__ == "__main__" and "--keep" in sys.argv:
    keep(sys.argv[sys.argv.index("--keep") + 1], sys.argv[sys.argv.index("--keep") + 2])
