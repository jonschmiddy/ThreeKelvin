"""THE THREE IRISES AT THE NEW HEIGHT (Jon: "Irises: A", hard cap 12 generations). Each kept iris take, its ring kept
round and centred in the taller recess (128 x 126), the 48 new rows drawn in code from its own wall (columns beside
the ring tile their own wall rows; columns under/over the ring take that row's wall colour), set in Drum 3's taller
entrance (plate x 63..246, rows 185..352, 184 x 168), re-rendered by pixflux at the strength its take held at; the
recess only pasted back after aligning the take on everything outside it.

    python iris.py --plan                          inits, nothing spent
    python iris.py --go <iris id> [--seed N] [--strength S]
    python iris.py --post <iris id> <take tag>     the recess, flat and lit, into joined/
Key: PIXELLAB_API_KEY in the environment, never printed. Ledger: ledger_iris.json (cap 12).
"""
import base64, json, os, sys, time, urllib.request, urllib.error
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ST = "C:/Users/Jon/Documents/GitHub/tk-wt/stations/tkg/art/stations"
sys.path.insert(0, ST)
import mouth  # noqa: E402

API = "https://api.pixellab.ai/v1/generate-image-pixflux"
CAP = 12
LEDGER = os.path.join(HERE, "ledger_iris.json")
CX, CY, CW, CH = 63, 185, 184, 168
RX0, RY0, RX1, RY1 = 84, 206, 212, 332          # the taller recess (plate px)
TALL = 48
IRISES = {
    "iris_90_0": dict(strength=90, seed=71000, ring=(36, 101)),
    "iris_90_1": dict(strength=90, seed=71100, ring=(38, 104)),
    "iris_220_1": dict(strength=220, seed=71200, ring=(37, 98)),
}
PROMPT = ("Seen strictly head-on, a flat elevation: a tall landing-bay recess inside a riveted steel frame, a thin lip "
          "above and a deep lip below with small amber lamps along their edges, a strip of small amber lamps on the "
          "frame's right. Inside the recess: a round airlock iris door of six overlapping steel blades set in a heavy "
          "bolted ring centred on the back wall, a perfectly round ring, plain steel wall panels above and below it, a "
          "pin of warm light where the blades meet, a red warning lamp in a housing on each side, yellow and black "
          "hazard paint along the sill. Pixel art, crisp dark outline, detailed shading. No text, no letters, no "
          "numbers, no people.")
NEG = ("text, letters, numbers, writing, signage, logo, people, person, perspective, vanishing point, corridor in "
       "perspective, isometric, three-quarter view, top-down view, landscape, sky, clouds, hills, trees, sunset, "
       "painting, picture frame, window with a view of a planet, oval, ellipse, stretched, capsule, pill shape, gun, "
       "rifle, cannon, missile, submarine, boat, car, truck, house")
GAME_PAL = "C:/Users/Jon/Documents/GitHub/ThreeKelvin/tkg/art/sprites/palette_three_kelvin.png"


def taller_iris(k):
    """the iris picture (flat) at 128 x 126: its frame rows top and bottom kept, 24 rows of its own wall above and
    below the rest"""
    a = np.asarray(Image.open(os.path.join(ST, "src", "interiors", k + "_flat.png")).convert("RGB")).astype(float)
    H, W = a.shape[:2]
    r0, r1 = IRISES[k]["ring"]
    outside = np.ones(W, bool); outside[r0:r1] = False

    def band(rows):
        seg = a[rows[0]:rows[1]]
        b = np.zeros((24, W, 3))
        for y in range(24):
            src = seg[y % seg.shape[0]]
            row = src.copy()
            med = np.median(src[outside], 0)
            row[~outside] = med
            b[y] = row
        return b

    top = band((30, 38))
    bot = band((30, 38))
    return np.concatenate([a[:4], top, a[4:H - 4], bot, a[H - 4:]], 0)


def plate():
    p = np.asarray(Image.open(os.path.join(ST, "src", "drum3.png")).convert("RGBA"))
    t, _, _, _ = mouth.taller(p)
    return t


def init(k):
    t = plate().copy()
    ir = taller_iris(k)
    t[RY0:RY1, RX0:RX1, :3] = np.clip(ir, 0, 255).astype(np.uint8)
    t[RY0:RY1, RX0:RX1, 3] = 255
    return t[CY:CY + CH, CX:CX + CW]


def palette(k):
    cols = [tuple(int(v) for v in c) for c in np.asarray(Image.open(GAME_PAL).convert("RGB")).reshape(-1, 3)]
    a = np.asarray(Image.open(os.path.join(ST, "src", "interiors", k + "_flat.png")).convert("RGB")).reshape(-1, 3)
    q = Image.fromarray(a.reshape(1, -1, 3).astype(np.uint8)).quantize(24, method=Image.MEDIANCUT).getpalette()[:72]
    cols += [tuple(q[i * 3:i * 3 + 3]) for i in range(24)]
    u = list(dict.fromkeys(cols))
    o = Image.new("RGB", (len(u), 1)); o.putdata(u)
    path = os.path.join(HERE, "pal_%s.png" % k); o.save(path)
    return path


def ledger():
    return json.load(open(LEDGER)) if os.path.exists(LEDGER) else {"spent": 0.0, "takes": []}


def b64(path):
    return base64.b64encode(open(path, "rb").read()).decode("ascii")


def go(k, seed=None, strength=None):
    L = ledger()
    if L["spent"] + 1 > CAP:
        sys.exit("cap: nothing sent")
    key = os.environ.get("PIXELLAB_API_KEY", "").strip()
    if not key:
        sys.exit("no key; nothing sent")
    j = IRISES[k]
    seed = seed if seed is not None else j["seed"]
    strength = strength if strength is not None else j["strength"]
    ip = os.path.join(HERE, "inits", k + ".png")
    body = {"description": PROMPT, "negative_description": NEG, "image_size": {"width": CW, "height": CH},
            "no_background": True, "view": "side", "outline": "single color black outline", "shading": "detailed shading",
            "detail": "highly detailed", "text_guidance_scale": 8, "seed": seed,
            "init_image": {"type": "base64", "base64": b64(ip)}, "init_image_strength": strength,
            "color_image": {"type": "base64", "base64": b64(palette(k))}}
    t0 = time.time()
    req = urllib.request.Request(API, data=json.dumps(body).encode("utf-8"),
                                 headers={"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            out = json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        sys.exit("refused: HTTP %d %s" % (e.code, e.read()[:300].decode("utf-8", "replace")))
    u = out.get("usage") or {}
    tag = "%s__s%d_%d" % (k, strength, seed)
    os.makedirs(os.path.join(HERE, "raw_iris"), exist_ok=True)
    open(os.path.join(HERE, "raw_iris", tag + ".png"), "wb").write(base64.b64decode(out["image"]["base64"].split(",")[-1]))
    gens = float(u.get("generations", 0)) if u.get("type") == "generations" else None
    L["spent"] += gens if gens is not None else 1.0
    L["takes"].append(dict(tag=tag, iris=k, seed=seed, strength=strength, usage=u, seconds=round(time.time() - t0, 1)))
    json.dump(L, open(LEDGER, "w"), indent=1)
    print("take", tag, "usage", u, "spent now %.0f of %d" % (L["spent"], CAP))
    if gens != 1.0:
        print("USAGE NOT EXACTLY 1 GENERATION: STOP"); sys.exit(2)


def post(k, tag):
    ini = np.asarray(Image.open(os.path.join(HERE, "inits", k + ".png")).convert("RGBA")).astype(float)
    raw = np.asarray(Image.open(os.path.join(HERE, "raw_iris", tag + ".png")).convert("RGBA")).astype(float)
    lum = lambda a: a[..., 0] * 0.299 + a[..., 1] * 0.587 + a[..., 2] * 0.114
    li, lr = lum(ini), lum(raw)
    outside = np.ones((CH, CW), bool)
    outside[RY0 - CY:RY1 - CY, RX0 - CX:RX1 - CX] = False
    outside &= ini[..., 3] > 0
    outside[:5] = outside[-5:] = False; outside[:, :5] = outside[:, -5:] = False
    best = None
    for dy in range(-4, 5):
        for dx in range(-4, 5):
            e = float(np.abs(np.roll(np.roll(lr, -dy, 0), -dx, 1) - li)[outside].mean())
            if best is None or e < best[0]:
                best = (e, dx, dy)
    e, dx, dy = best
    y0, x0 = RY0 - CY + dy, RX0 - CX + dx
    rec = raw[y0:y0 + (RY1 - RY0), x0:x0 + (RX1 - RX0), :3]
    os.makedirs(os.path.join(HERE, "joined_iris"), exist_ok=True)
    Image.fromarray(rec.astype(np.uint8)).save(os.path.join(HERE, "joined_iris", k + "_flat.png"))
    Image.fromarray(lit_version(rec).astype(np.uint8)).save(os.path.join(HERE, "joined_iris", k + "_lit.png"))
    print(k, tag, "shift", dx, dy, "align error %.1f" % e)


BAY = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0
RED2 = (214, 74, 58)
WARM = [(92, 40, 12), (150, 66, 20), (204, 100, 28), (255, 166, 60), (255, 220, 160)]


def lit_version(c):
    """the entrances stream's lit-bay rule (interiors.lit_version) on the taller recess: the iris's lights 24 rows
    lower than round four's"""
    H, W = c.shape[:2]
    L = [(22, 44, 14, RED2, 0.75), (114, 44, 14, RED2, 0.75), (68, 59, 30, WARM[3], 0.35), (68, H - 8, 24, WARM[2], 0.25)]
    lum = c[..., 0] * 0.299 + c[..., 1] * 0.587 + c[..., 2] * 0.114
    emis = (lum > 170) | ((c[..., 0] > 140) & (c[..., 0] - c[..., 2] > 70))
    out = c * 0.62
    yy, xx = np.mgrid[0:H, 0:W]
    acc = np.zeros((H, W)); tint = np.zeros((H, W, 3))
    for (x, y, r, col, k) in L:
        v = np.clip(1 - np.hypot(xx - x, yy - y) / r, 0, 1) ** 1.5 * k
        acc += v
        tint += v[..., None] * np.array(col, float)
    q = np.clip(acc, 0, 1.6) * 4
    lo = np.floor(q); lo = lo + ((q - lo) > BAY[yy % 4, xx % 4]); s = lo / 4
    col = tint / np.maximum(acc[..., None], 1e-6)
    out = out * (1 + 2.2 * s[..., None]) + col * 0.16 * s[..., None]
    out[emis] = c[emis]
    return np.clip(out, 0, 255)


if __name__ == "__main__":
    a = sys.argv[1:]
    if "--plan" in a:
        os.makedirs(os.path.join(HERE, "inits"), exist_ok=True)
        for k in IRISES:
            Image.fromarray(init(k)).save(os.path.join(HERE, "inits", k + ".png"))
        print("inits written; spent %.0f of %d" % (ledger()["spent"], CAP))
    elif "--go" in a:
        k = a[a.index("--go") + 1]
        go(k, int(a[a.index("--seed") + 1]) if "--seed" in a else None, int(a[a.index("--strength") + 1]) if "--strength" in a else None)
    elif "--post" in a:
        post(a[a.index("--post") + 1], a[a.index("--post") + 2])
