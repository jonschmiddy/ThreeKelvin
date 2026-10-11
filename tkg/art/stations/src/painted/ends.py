"""THE RIGHT ENDS OF THE FIVE RECOVERED PLATES, painted by PixelLab (Jon's 1B: "about 5 to 10 generations"; hard
cap 10). One pixflux take per plate (400 x 400, 1 generation): the canvas is plate x 230..629, rows 50..449; its
left 169 columns are the plate's own seen pixels, its right is a blockout (each row carried on in that row's own
tones where the hull reaches the cut at x 398), and the take's right part is joined to the real plate along a seam
cut where the two agree.

    python ends.py --plan              inits + palettes, the cost; nothing spent
    python ends.py --go <id> [--seed N] [--strength S]   one take (refuses past the cap; stops on any usage not 1 generation)

The key: PIXELLAB_API_KEY in the environment (never printed).
"""
import base64, json, os, sys, time, urllib.request, urllib.error
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = "C:/Users/Jon/Documents/GitHub/tk-wt/stations/tkg/art/stations/src"
API = "https://api.pixellab.ai/v1/generate-image-pixflux"
BAL = "https://api.pixellab.ai/v1/balance"
GAME_PAL = "C:/Users/Jon/Documents/GitHub/ThreeKelvin/tkg/art/sprites/palette_three_kelvin.png"
EXTRA = ["#07090e", "#10141d", "#1a202b", "#283041", "#3f4a5c", "#5f6d82", "#8f9db0", "#c4d0de",
         "#5a4824", "#8f7134", "#c9a04a", "#e9c46a"]
CAP = 10
LEDGER = os.path.join(HERE, "ledger.json")
CX, CY, CW, CH = 230, 50, 400, 400
SEEN = 399
# how the init carries on past the cut: "smear" (each row in its own tones) or "flip" (the plate's own detail)
FILL = {"pile1": "flip", "pile3": "flip", "pile4": "flip", "drum3": ("mirror", 278, 399), "shanty3": "patch"}

LIGHT = ("Lit by a star from the upper left: top edges bright, undersides in deep shadow. Seen strictly side-on, a flat "
         "side elevation, hanging in empty black space, running off the right edge of the picture. Transparent "
         "background. Pixel art, crisp dark outline, detailed shading.")
NEG = ("text, letters, numbers, writing, signage, logo, label, perspective, isometric, three-quarter view, top-down view, "
       "vanishing point, ground, floor, horizon, scenery, planet, border, frame, divider, vertical seam line down the "
       "picture, grid, tiles, tiled pattern, repeating pattern, wallpaper, mirror image, symmetrical copy, boat, sea, "
       "truck, train, building on land, people")
PLATES = {
    "drum3": dict(src="drum3.png", seed=61001, strength=300, prompt=(
        "The long side of a huge steel drum hull, seen side-on: big smooth blue-grey plating panels in rows with thin "
        "dark seams, two long rust-orange rails running along its length, the upper half pale and the lower half falling "
        "into dark shadow. " + LIGHT)),
    "pile1": dict(src="pile1.png", seed=61101, strength=300, prompt=(
        "A tall pile of steel shipping containers stacked in space, seen side-on: corrugated boxes in rust red, orange, "
        "teal, cream, navy and olive, every box a different length and offset from its neighbours, dark gaps between "
        "them, a corner casting at each corner. " + LIGHT)),
    "pile3": dict(src="pile3.png", seed=61201, strength=300, prompt=(
        "A tall pile of steel shipping containers stacked in space, seen side-on: corrugated boxes in rust red, orange, "
        "teal, grey, navy and slate, every box a different length and offset from its neighbours, dark gaps between "
        "them, a corner casting at each corner. " + LIGHT)),
    "pile4": dict(src="pile4.png", seed=61301, strength=300, prompt=(
        "A tall pile of steel shipping containers stacked in space, seen side-on: corrugated boxes in rust red, orange, "
        "teal, cream, slate and olive, every box a different length and offset from its neighbours, dark gaps between "
        "them, a corner casting at each corner. " + LIGHT)),
    "shanty3": dict(src="shanty3.png", seed=61401, strength=300, prompt=(
        "A ragged patchwork hull of mismatched riveted metal plates in rust, cream, olive and dark grey, bolted together "
        "over dark steel, small square hatches and patches, one sheet of crumpled gold foil hanging down; along its top "
        "lies an old white capsule with round lit windows; below the hull small tanks hang on thin cables. " + LIGHT)),
}


def ledger():
    return json.load(open(LEDGER)) if os.path.exists(LEDGER) else {"spent": 0.0, "takes": []}


def blockout(name):
    """the init canvas (RGBA, 400 x 400) and its space mask"""
    p = np.asarray(Image.open(os.path.join(SRC, PLATES[name]["src"])).convert("RGBA")).copy()
    # (the hull as the game cuts it: the recovered plates' leftover sky taken off, sides.py's own rule)
    sys.path.insert(0, os.path.dirname(SRC))
    import sides
    kind, _, rule, keep = sides.SIDES[name]
    al, _ = sides.clean_mask(p[..., 3] > 0, p[..., :3].astype(float), rule, keep)
    p[~al] = 0
    can = np.zeros((CH, CW, 4), np.uint8)
    sub = p[CY:CY + CH, CX:SEEN]
    can[:, :SEEN - CX] = sub
    if FILL.get(name) == "flip":
        # DETAILED, NOT A REPEAT (a flat init gives a flat result): the plate's own boxes right of the entrance,
        # upside down (another order of rows), and the last of them mirrored too, for the generator to re-render
        flip = p[::-1]
        fl = flip[CY:CY + CH, 238:SEEN]
        w = CW - (SEEN - CX)
        part = fl[:, :w]
        if part.shape[1] < w:
            rest = fl[:, ::-1][:, :w - part.shape[1]]
            part = np.concatenate([part, rest], 1)
        can[:, SEEN - CX:] = part
        return can
    if FILL.get(name) == "patch":
        # THE SHANTY: a patchwork, so its plates may be shuffled. Columns 238..328 of the body (no curtain), each
        # copy's body rows (plate 140..339) rolled down by a different amount so no plate sits beside its twin; the
        # capsule above and the hanging tanks below as they are, alternately mirrored; and first, the gold drape's
        # own left edge mirrored to close it a dozen pixels past the cut
        blk = p[:, 238:329].copy()
        w = CW - (SEEN - CX)
        pieces = []
        for k, sh in enumerate((97, 173, 53, 131)):
            b = blk.copy()
            b[140:340] = np.roll(blk[140:340], sh, 0)
            if k % 2 == 1:
                b[:140] = blk[:140, ::-1]
                b[340:] = blk[340:, ::-1]
            pieces.append(b)
        right = np.concatenate(pieces, 1)[:, :w].copy()
        drape = p[110:250, 360:376][:, ::-1]
        dm = drape[..., 3] > 0
        lum_d = drape[..., :3].astype(int).sum(-1)
        warm = (drape[..., 0].astype(int) - drape[..., 2].astype(int) > 40) & dm
        sub_r = right[110:250, :16]
        sub_r[warm] = drape[warm]
        can[:, SEEN - CX:] = right[CY:CY + CH]
        return can
    if isinstance(FILL.get(name), tuple):
        # ("mirror", a, b): the plate's own columns a..b, mirrored then as they are, alternately, from the cut on
        # (no seam, no row out of place; the generator re-renders it at a low strength)
        _, a, b = FILL[name]
        blk = p[CY:CY + CH, a:b]
        w = CW - (SEEN - CX)
        pieces = []
        k = 0
        while sum(x.shape[1] for x in pieces) < w:
            pieces.append(blk[:, ::-1] if k % 2 == 0 else blk)
            k += 1
        can[:, SEEN - CX:] = np.concatenate(pieces, 1)[:, :w]
        return can
    # each row carried on where the hull reaches the cut: that row's own tones (its median over the last 60 seen
    # columns, a little darker toward the right so the init carries no hard stripe of one colour)
    for y in range(CH):
        row = sub[y]
        op = row[:, 3] > 0
        if not op[-1]:
            continue
        tail = row[-60:][op[-60:]][:, :3]
        if len(tail) == 0:
            continue
        med = np.median(tail, 0)
        can[y, SEEN - CX:, :3] = np.clip(med, 0, 255).astype(np.uint8)
        can[y, SEEN - CX:, 3] = 255
    return can


def palette(name, can):
    cols = [tuple(int(v) for v in c) for c in np.asarray(Image.open(GAME_PAL).convert("RGB")).reshape(-1, 3)]
    for h in EXTRA:
        h = h.lstrip("#"); cols.append((int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16)))
    p = np.asarray(Image.open(os.path.join(SRC, PLATES[name]["src"])).convert("RGBA"))[:, :SEEN]
    px = p[p[..., 3] > 200][:, :3]
    q = Image.fromarray(px.reshape(1, -1, 3).astype(np.uint8))
    pal = q.quantize(24, method=Image.MEDIANCUT).getpalette()[:72]
    cols += [tuple(pal[i * 3:i * 3 + 3]) for i in range(24)]
    uniq = list(dict.fromkeys(cols))
    o = Image.new("RGB", (len(uniq), 1)); o.putdata(uniq)
    path = os.path.join(HERE, "pal_%s.png" % name)
    o.save(path)
    return path


def plan():
    os.makedirs(os.path.join(HERE, "inits"), exist_ok=True)
    for name in PLATES:
        can = blockout(name)
        Image.fromarray(can).save(os.path.join(HERE, "inits", name + ".png"))
        palette(name, can)
    L = ledger()
    print("inits written; spent so far %.0f of %d generations; one take = 1 generation (pixflux 400 x 400)" % (L["spent"], CAP))


def b64(path):
    return base64.b64encode(open(path, "rb").read()).decode("ascii")


def go(name, seed=None, strength=None):
    L = ledger()
    if L["spent"] + 1 > CAP:
        sys.exit("cap: %.0f of %d spent, nothing sent" % (L["spent"], CAP))
    k = os.environ.get("PIXELLAB_API_KEY", "").strip()
    if not k:
        sys.exit("no key in the environment; nothing sent")
    req = urllib.request.Request(BAL, headers={"Authorization": "Bearer " + k})
    with urllib.request.urlopen(req, timeout=60) as r:
        print("balance before:", r.read().decode("utf-8")[:200])
    j = PLATES[name]
    seed = seed if seed is not None else j["seed"]
    strength = strength if strength is not None else j["strength"]
    init = os.path.join(HERE, "inits", name + ".png")
    body = {"description": j["prompt"], "negative_description": NEG, "image_size": {"width": CW, "height": CH},
            "no_background": True, "view": "side", "outline": "single color black outline", "shading": "detailed shading",
            "detail": "highly detailed", "text_guidance_scale": 8, "seed": seed,
            "init_image": {"type": "base64", "base64": b64(init)}, "init_image_strength": strength,
            "color_image": {"type": "base64", "base64": b64(os.path.join(HERE, "pal_%s.png" % name))}}
    t0 = time.time()
    req = urllib.request.Request(API, data=json.dumps(body).encode("utf-8"),
                                 headers={"Authorization": "Bearer " + k, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            out = json.loads(r.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        sys.exit("refused: HTTP %d %s" % (e.code, e.read()[:300].decode("utf-8", "replace")))
    u = out.get("usage") or {}
    tag = "%s__s%d_%d" % (name, strength, seed)
    os.makedirs(os.path.join(HERE, "raw"), exist_ok=True)
    open(os.path.join(HERE, "raw", tag + ".png"), "wb").write(base64.b64decode(out["image"]["base64"]))
    gens = float(u.get("generations", 0)) if u.get("type") == "generations" else None
    L["spent"] += gens if gens is not None else 1.0
    L["takes"].append(dict(tag=tag, plate=name, seed=seed, strength=strength, usage=u, seconds=round(time.time() - t0, 1)))
    json.dump(L, open(LEDGER, "w"), indent=1)
    print("take", tag, "usage", u, "spent now %.0f of %d" % (L["spent"], CAP))
    if gens != 1.0:
        print("USAGE NOT EXACTLY 1 GENERATION: STOP")
        sys.exit(2)


if __name__ == "__main__":
    a = sys.argv[1:]
    if "--plan" in a:
        plan()
    elif "--go" in a:
        name = a[a.index("--go") + 1]
        seed = int(a[a.index("--seed") + 1]) if "--seed" in a else None
        st = int(a[a.index("--strength") + 1]) if "--strength" in a else None
        go(name, seed, st)
