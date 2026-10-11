"""seamfix.py <plate> <x0> <y0> <mx0> <mx1> [--go]: one /v1/inpaint call (200 x 200, the plate's crop at x0,y0) that
repaints only the painted side's first columns mx0..mx1 (plate px, all >= 399) so they meet the seen plate; the seen
pixels are never in the mask. Counts against the same ledger and cap as ends.py."""
import base64, io, json, os, sys, time, urllib.request, urllib.error
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import ends  # noqa: E402

API = "https://api.pixellab.ai/v1/inpaint"
name = sys.argv[1]
x0, y0, mx0, mx1 = map(int, sys.argv[2:6])
assert mx0 >= 399
plate_p = os.path.join(HERE, "joined", name + ".png")
full = np.asarray(Image.open(plate_p).convert("RGBA")).copy()
crop = full[y0:y0 + 200, x0:x0 + 200].copy()
mask = np.zeros((200, 200), np.uint8)
my0 = int(sys.argv[sys.argv.index("--my0") + 1]) if "--my0" in sys.argv else y0
mask[my0 - y0:, mx0 - x0:mx1 - x0] = 255
os.makedirs(os.path.join(HERE, "seam"), exist_ok=True)
Image.fromarray(crop).save(os.path.join(HERE, "seam", "%s_%d_in.png" % (name, y0)))
Image.fromarray(mask).save(os.path.join(HERE, "seam", "%s_%d_mask.png" % (name, y0)))


def b64img(a):
    b = io.BytesIO(); Image.fromarray(a).save(b, "PNG"); return base64.b64encode(b.getvalue()).decode("ascii")


if "--go" not in sys.argv:
    print("prepared; nothing sent"); sys.exit(0)
L = ends.ledger()
if L["spent"] + 1 > ends.CAP:
    sys.exit("cap: nothing sent")
k = os.environ.get("PIXELLAB_API_KEY", "").strip()
if not k:
    sys.exit("no key; nothing sent")
j = ends.PLATES[name]
body = {"description": j["prompt"], "negative_description": ends.NEG, "image_size": {"width": 200, "height": 200},
        "view": "side", "outline": "single color black outline", "shading": "detailed shading", "detail": "highly detailed",
        "text_guidance_scale": 6, "seed": 62001 + y0, "inpainting_image": {"type": "base64", "base64": b64img(crop)},
        "mask_image": {"type": "base64", "base64": b64img(mask)},
        "color_image": {"type": "base64", "base64": base64.b64encode(open(os.path.join(HERE, "pal_%s.png" % name), "rb").read()).decode("ascii")}}
t0 = time.time()
req = urllib.request.Request(API, data=json.dumps(body).encode("utf-8"), headers={"Authorization": "Bearer " + k, "Content-Type": "application/json"})
try:
    with urllib.request.urlopen(req, timeout=300) as r:
        out = json.loads(r.read().decode("utf-8"))
except urllib.error.HTTPError as e:
    sys.exit("refused: HTTP %d %s" % (e.code, e.read()[:300].decode("utf-8", "replace")))
u = out.get("usage") or {}
img = base64.b64decode(out["image"]["base64"].split(",")[-1])
open(os.path.join(HERE, "seam", "%s_%d_out.png" % (name, y0)), "wb").write(img)
gens = float(u.get("generations", 0)) if u.get("type") == "generations" else None
L["spent"] += gens if gens is not None else 1.0
L["takes"].append(dict(tag="%s__seam_%d_%d" % (name, x0, y0), plate=name, tool="inpaint (HTTP API v1)", usage=u, seconds=round(time.time() - t0, 1)))
json.dump(L, open(ends.LEDGER, "w"), indent=1)
print("seam take usage", u, "spent now %.0f of %d" % (L["spent"], ends.CAP))
if gens != 1.0:
    print("USAGE NOT EXACTLY 1 GENERATION: STOP"); sys.exit(2)
