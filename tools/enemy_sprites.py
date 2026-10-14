"""The enemies' pictures, from Jon's kept pool art.

    python tools/enemy_sprites.py          # writes tkg/art/sprites/enemies/
    python tools/enemy_sprites.py --check  # fails if the install is out of date

WHAT EACH ENEMY IS. Jon's picks (2026-10-13): the five ordinary kinds fly all
three of their candidates, one chosen per fight (`DB.enemy_sprite(id, look)`,
`Combat.look_for`); the Hellbender is `helix`; the Custodian is take 1 ("grown") of the
boss-size batch in `art_pool/custodian`; the calf is `fan` drawn smaller and the Leviathan is
`lev_spine`. `VARIANTS` below is the whole table, in the order the game indexes
them.

HOW EACH PICTURE IS MADE, all of it arithmetic on Jon's kept pixels:
- turned to the orientation he judged it in (`picks.json` `flip`), which points
  every one of these at you, left, as the drawn ships did;
- `gyro` loses the display stand it was generated on (a pole and a floor line,
  rows 82 down of the pool file): a model on a stand is an Earth picture;
- specks are dropped: a piece under 64 px more than 8 px from any other ink
  (tp_spires' sparkle, quills' blob), and a 1-row line wider than 40 px;
- the calf is shrunk to 70% as pixel art: each new pixel takes the area it
  covers (light weighted by cover), is kept where a third of it is creature,
  and snaps back to the creature's own colours -- no new colours, hard alpha,
  nothing resampled at run time (a plain nearest-neighbour drops every third
  row and snaps the 1 px spines);
- cropped to the ink, hard alpha (0 or 255).
Writes `<enemy>_<source>.png`, its half sheet `<enemy>_<source>_half.png` (for
fights with three or more ships), and `index.json` ({enemy id: [file, ...]},
and the same under "half"), which
also records a hash of this script, of every source picture and of every file
written, so `--check` (plain python, no numpy) can say the install is stale.
"""

import hashlib
import io
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
POOL = os.path.join(HERE, "art_pool")
OUT = os.path.join(HERE, "..", "tkg", "art", "sprites", "enemies")

VARIANTS = {
    "cutter": ["coiled", "swarm", "saucer"],
    "lancer": ["gp_barrel", "enginebar", "solarsail"],
    "marauder": ["gn_barnacle", "tp_spires", "dc_comb"],
    "hulk": ["rg_hulk", "rs_net", "honeycomb"],
    "sentinel": ["gyro", "scales", "hl_column"],
    "hellbender": ["helix"],
    # Jon picked take 1 of the boss-size batch (Oct 13: "custodian:t1"), grown
    # from tetra; generated facing you, so it is not turned
    "custodian": ["custodian/t1_grown"],
    "whale": ["mega/fan@70"],
    "leviathan": ["mega/lev_spine"],
}
CUT_BELOW = {"gyro": 82}
SPECK = 64


def sha(path):
    """A file's hash; text with its line ends made plain, so a checkout that
    turns them into CRLF is not "out of date"."""
    data = open(path, "rb").read()
    if not path.endswith(".png"):
        data = data.replace(b"\r\n", b"\n")
    return hashlib.sha256(data).hexdigest()[:16]


def sources():
    """Every file the install reads, by path relative to tools/."""
    out = ["enemy_sprites.py", "art_pool/picks.json"]
    for srcs in VARIANTS.values():
        for src in srcs:
            name = src.split("@")[0]
            out.append("art_pool/megafauna/%s.png" % name[5:] if name.startswith("mega/")
                       else "art_pool/%s.png" % name if name.startswith("custodian/")
                       else "art_pool/ships/%s.png" % name)
    return out


def components(mask):
    h, w = mask.shape
    lab = np.zeros((h, w), np.int32)
    out = []
    for y0, x0 in zip(*np.nonzero(mask)):
        if lab[y0, x0]:
            continue
        k = len(out) + 1
        st = [(y0, x0)]
        lab[y0, x0] = k
        ys, xs = [], []
        while st:
            y, x = st.pop()
            ys.append(y)
            xs.append(x)
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                yy, xx = y + dy, x + dx
                if 0 <= yy < h and 0 <= xx < w and mask[yy, xx] and not lab[yy, xx]:
                    lab[yy, xx] = k
                    st.append((yy, xx))
        out.append((len(ys), np.array(ys), np.array(xs)))
    return out, lab


def despeck(a):
    comps, lab = components(a[..., 3] > 0)
    gone = 0
    for k, (size, ys, xs) in enumerate(comps, 1):
        line = ys.max() - ys.min() <= 1 and xs.max() - xs.min() > 40
        if size >= SPECK and not line:
            continue
        oy, ox = np.nonzero((lab > 0) & (lab != k))
        if oy.size == 0:
            continue
        far = line or np.min((oy - ys.mean()) ** 2 + (ox - xs.mean()) ** 2) > 8 ** 2
        if far:
            a[ys, xs, 3] = 0
            gone += size
    return a, gone


def trim(a):
    ys, xs = np.nonzero(a[..., 3] > 0)
    return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


def shrink(a, f, cover=0.34):
    """`a` at `f` of its size as pixel art: area cover, edge at `cover`, own colours."""
    h, w = a.shape[:2]
    W, H = int(round(w * f)), int(round(h * f))
    al = (a[..., 3] > 0).astype(np.float64)
    pre = a[..., :3].astype(np.float64) * al[..., None]
    pal = np.unique(a[a[..., 3] > 0][:, :3], axis=0).astype(np.float64)
    k = 8
    big_al = np.kron(al, np.ones((k, k)))
    big = np.stack([np.kron(pre[..., c], np.ones((k, k))) for c in range(3)], -1)
    ys = (np.arange(H + 1) * h * k / H).round().astype(int)
    xs = (np.arange(W + 1) * w * k / W).round().astype(int)
    out = np.zeros((H, W, 4), np.uint8)
    for j in range(H):
        for i in range(W):
            blk = big_al[ys[j]:ys[j + 1], xs[i]:xs[i + 1]]
            if blk.mean() < cover:
                continue
            rgb = big[ys[j]:ys[j + 1], xs[i]:xs[i + 1]].sum((0, 1)) / max(blk.sum(), 1e-9)
            out[j, i, :3] = pal[np.argmin(((pal - rgb) ** 2).sum(1))].astype(np.uint8)
            out[j, i, 3] = 255
    return out


def make(src, picks):
    name, pct = (src.split("@") + [None])[:2]
    if name.startswith("mega/"):
        a = np.array(Image.open(os.path.join(POOL, "megafauna", name[5:] + ".png")).convert("RGBA"))
    elif name.startswith("custodian/"):
        a = np.array(Image.open(os.path.join(POOL, name + ".png")).convert("RGBA"))
    else:
        v = picks["ships"].get(name, {})
        if v.get("verdict") != "keep":
            raise SystemExit("enemy_sprites: %s is not a kept ship" % name)
        a = np.array(Image.open(os.path.join(POOL, "ships", name + ".png")).convert("RGBA"))
        if name in CUT_BELOW:
            a[CUT_BELOW[name]:, :, 3] = 0
        if v.get("flip"):
            a = a[:, ::-1].copy()
    a[..., 3] = np.where(a[..., 3] >= 128, 255, 0).astype(np.uint8)
    a, gone = despeck(a)
    a = trim(a)
    if pct:
        a = trim(shrink(a, int(pct) / 100.0))
    return a, gone


def build():
    global np, Image
    import numpy as np
    from PIL import Image
    picks = json.load(io.open(os.path.join(POOL, "picks.json"), encoding="utf-8"))
    files = {}
    index = {}
    halves = {}
    for enemy, srcs in VARIANTS.items():
        index[enemy] = []
        halves[enemy] = []
        for src in srcs:
            a, gone = make(src, picks)
            if a.shape[1] > 340 or a.shape[0] > 160:
                raise SystemExit("enemy_sprites: %s is %dx%d, the canvas is 340x160" % (src, a.shape[1], a.shape[0]))
            fn = "%s_%s.png" % (enemy, src.split("/")[-1].split("@")[0])
            buf = io.BytesIO()
            Image.fromarray(a, "RGBA").save(buf, "PNG", optimize=True)
            files[fn] = buf.getvalue()
            index[enemy].append(fn)
            # THE HALF SHEET, for a fight with three or more ships in it (Jon:
            # "render them at 1X, kinda like how we do for multiplayer"). Made
            # the way the hulls' half sheets are (`HullData.sprite_half`):
            # nearest, keeping the top-left pixel of every 2x2 block, which read
            # better than an averaged-and-snapped reduction side by side.
            h = trim(a[::2, ::2])
            hn = fn[:-4] + "_half.png"
            buf = io.BytesIO()
            Image.fromarray(np.ascontiguousarray(h), "RGBA").save(buf, "PNG", optimize=True)
            files[hn] = buf.getvalue()
            halves[enemy].append(hn)
            print("  %-10s %-24s %3dx%-3d specks %d" % (enemy, fn, a.shape[1], a.shape[0], gone))
    record = {"source": "tools/enemy_sprites.py", "enemies": index, "half": halves,
              "inputs": {p: sha(os.path.join(HERE, p)) for p in sources()},
              "outputs": {fn: hashlib.sha256(data).hexdigest()[:16] for fn, data in files.items()}}
    files["index.json"] = (json.dumps(record, indent=1) + "\n").encode()
    return files


def check():
    p = os.path.join(OUT, "index.json")
    if not os.path.exists(p):
        raise SystemExit("enemy_sprites --check: no install (tkg/art/sprites/enemies/index.json)")
    rec = json.load(io.open(p, encoding="utf-8"))
    bad = []
    if sorted(rec.get("inputs", {})) != sorted(sources()):
        bad.append("the table of pictures changed")
    for rel, h in rec.get("inputs", {}).items():
        q = os.path.join(HERE, rel)
        if not os.path.exists(q) or sha(q) != h:
            bad.append(rel)
    for fn, h in rec.get("outputs", {}).items():
        q = os.path.join(OUT, fn)
        if not os.path.exists(q) or sha(q) != h:
            bad.append(fn)
    if bad:
        raise SystemExit("enemy_sprites --check: out of date, run python tools/enemy_sprites.py: %s"
                         % ", ".join(bad[:8]))
    print("enemy_sprites --check: %d pictures for %d kinds, current" % (len(rec["outputs"]), len(rec["enemies"])))


def main():
    if "--check" in sys.argv:
        check()
        return
    files = build()
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".png") and f not in files:
            os.remove(os.path.join(OUT, f))
        elif f.endswith(".png.import") and f[:-7] not in files:
            os.remove(os.path.join(OUT, f))
    for fn, data in files.items():
        open(os.path.join(OUT, fn), "wb").write(data)
    print("enemy_sprites: %d pictures in %s" % (len(files) - 1, os.path.relpath(OUT, os.path.join(HERE, ".."))))


if __name__ == "__main__":
    main()
