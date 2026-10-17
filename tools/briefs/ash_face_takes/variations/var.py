import base64, json, os, sys, time, urllib.request, urllib.error
D = os.path.dirname(os.path.abspath(__file__))
API = "https://api.pixellab.ai/v2"
B15 = base64.b64encode(open(os.path.join(D, "raw", "B_15.png"), "rb").read()).decode()
PROMPT = {
 "V1": ("Pixel art portrait of the same holographic woman as the reference: just her floating head, no neck, no shoulders, "
        "close-cropped hair, calm half-lidded eyes, mildly unimpressed, a pale white-blue wireframe hologram with glowing "
        "lines and a few horizontal glitch streaks, inside a dark ship console with cold indicator lights, deep indigo dark "
        "filling every edge, no lettering"),
 "V2": ("Pixel art portrait of the same holographic woman as the reference, her floating head only, no neck, no shoulders, "
        "a dry little almost-smile, one eyebrow slightly raised, pale white-blue wireframe hologram light with scanlines and "
        "glitch streaks, dark ship console frame, deep indigo dark filling every edge, no lettering"),
}
def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method,
        data=json.dumps(body).encode() if body is not None else None, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode())
def roll(k, seed):
    ref = {"image": {"type": "base64", "base64": B15}, "size": {"width": 64, "height": 64}}
    body = {"description": PROMPT[k], "image_size": {"width": 64, "height": 64}, "no_background": False, "seed": seed,
            "reference_images": [dict(ref, usage_description="this exact character: keep her face, features and close-cropped head")],
            "style_image": ref, "style_options": {"color_palette": True, "outline": True, "detail": True, "shading": True}}
    for _ in range(8):
        try: job = call("POST", "/generate-image-v2", body); break
        except urllib.error.HTTPError as e:
            if e.code == 429: time.sleep(20); continue
            return "FAIL %s %s" % (e.code, e.read()[:200])
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
                open(os.path.join(D, "var", "%s_%02d.png" % (k, i + 1)), "wb").write(base64.b64decode(b))
            return "ok %d" % len(imgs)
        if st["status"] == "failed": return "FAIL job " + json.dumps(st)[:200]
    return "TIMEOUT"
if __name__ == "__main__":
    print(sys.argv[1], roll(sys.argv[1], int(sys.argv[2])), flush=True)
