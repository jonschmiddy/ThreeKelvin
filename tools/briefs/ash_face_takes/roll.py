import base64, json, os, sys, time, urllib.request, urllib.error
D = os.path.dirname(os.path.abspath(__file__))
API = "https://api.pixellab.ai/v2"
BASE = ("Pixel art portrait, head and shoulders, of a ship's AI shown as a hologram of a woman's face, "
        "calm, half-lidded and mildly unimpressed, a dry little almost-smile, short hair, facing the viewer, "
        "%s, faint glitch at the edges, projected inside a dark ship console with a few cold indicator lights, "
        "deep indigo dark filling every edge, no lettering")
LOOKS = {
 "A": "made of cyan projector light with horizontal scanlines running through her",
 "B": "drawn as a pale white-blue wireframe of glowing lines over translucent light",
 "C": "made of warm amber projector light with soft scanlines, like a heat glow",
}
def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method,
        data=json.dumps(body).encode() if body is not None else None,
        headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode())
def roll(look, seed):
    body = {"description": BASE % LOOKS[look], "image_size": {"width": 64, "height": 64},
            "no_background": False, "seed": seed}
    for _ in range(8):
        try:
            job = call("POST", "/generate-image-v2", body); break
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(20); continue
            return "FAIL %s" % e.code
        except Exception: time.sleep(10)
    jid = job["background_job_id"]
    for _ in range(120):
        time.sleep(10)
        try: st = call("GET", "/background-jobs/" + jid)
        except Exception: continue
        if st["status"] == "completed":
            imgs = (st.get("last_response") or {}).get("images") or []
            for i, im in enumerate(imgs):
                b = im.get("base64") if isinstance(im, dict) else im
                if b and "," in b[:40]: b = b.split(",", 1)[1]
                open(os.path.join(D, "raw", "%s_%02d.png" % (look, i + 1)), "wb").write(base64.b64decode(b))
            json.dump(body, open(os.path.join(D, "raw", look + ".json"), "w"))
            return "ok %d" % len(imgs)
        if st["status"] == "failed": return "FAIL job"
    return "TIMEOUT"
if __name__ == "__main__":
    print(sys.argv[1], roll(sys.argv[1], int(sys.argv[2])), flush=True)
