"""The approved badge's own frames, for the game's port to be held to.

    uv run --with playwright --with pillow python tools/dev/badge/dump_golden.py golden
        writes tkg/scripts/sim/badge_golden.json, which `-- sheet=BadgeTest` compares
        `CustodianBadge.paint` with, pixel for pixel (digits included)
    uv run --with playwright --with pillow python tools/dev/badge/dump_golden.py frames OUTDIR
        writes the web's PNGs of the frames `-- sheet=BadgeFrames` writes from the game
        (the same names and manifest), for tools/dev/badge/diff_frames.py

The source is badge 9b, "The eye opens, loud" (eye-1b), approved by Jon on Nov 4: core.js and
fin_eye.js, which live in this folder now. dump.html draws it on a
transparent 40 x 15 canvas at x 0, cy 7 with the game's own Silkscreen file.

Chrome draws canvas text with antialiasing; Silkscreen sits on a 125-unit grid (1 px at 8 px), so
its digits come out whole, but any pixel under 0.7 opacity (`CUT`) is cleared and any over is made solid in
the nearest of the colours the number is drawn in (the count is printed). Everything else is solid
fills and is kept as drawn.

Uses the installed Chrome (or Edge), no browser download, and deletes its temp profile and any
%TEMP% cdp-* / playwright-artifacts-* / playwright_* folders that appeared during the run, as the
badge harness's render.py does.
"""
import base64, functools, gzip, http.server, json, os, shutil, socketserver, sys, tempfile, threading
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
GOLDEN = REPO / "tkg" / "scripts" / "sim" / "badge_golden.json"
TMP = Path(tempfile.gettempdir())
PATTERNS = ("cdp-*", "playwright-artifacts-*", "playwright_*")
W, H, X, CY = 40, 15, 0, 7

# core.js's tables (contract 2)
IDLE = {"S0": (9, 3.0), "WAKE": (10, 2.0), "S1": (10, 2.0), "S2": (12, 1.5), "S3": (12, 1.0), "FULL": (12, 1.0)}
TRANS = {"wake": 12, "worse": 8, "full": 10, "tick": 4, "none": 0}


def stage(j):
    return "S0" if j <= 15 else "WAKE" if j == 16 else "S1" if j <= 19 else "S2" if j <= 24 else "S3" if j < 33 else "FULL"


def kind(j):  # the page's changeKind: it had no jump 0, so jump 1 has no tick there
    return "wake" if j == 16 else "worse" if j in (20, 25) else "full" if j == 33 else "tick" if 2 <= j <= 15 else "none"


def idle_frame(j, n):
    rate = IDLE[stage(j)][0]
    return {"j": j, "t": (n + 0.5) / rate, "since": -1.0, "what": "idle %d" % n}


def arrive_frames(j, tail=4):
    out, n, rate = [], TRANS[kind(j)], IDLE[stage(j)][0]
    for s in range(n):
        since = (s + 0.5) / 10.0
        out.append({"j": j, "t": since, "since": since, "what": "arrive %d/%d" % (s, n)})
    for k in range(tail):  # idling after it, on the clock that starts when it ends
        since = n / 10.0 + (k + 0.5) / rate
        out.append({"j": j, "t": since, "since": since, "what": "after %d" % k})
    return out


def golden_list():
    out = []
    for j in (0, 1, 7, 14, 15, 16, 17, 19, 20, 22, 24, 25, 28, 32, 33, 34, 40):
        rate, period = IDLE[stage(j)]
        out += [idle_frame(j, n) for n in range(int(round(rate * period)))]
    for j in (2, 12, 15, 16, 20, 25, 33):
        out += arrive_frames(j)
    return out


def frames_list():
    """The frame dumper's set (BadgeFrames.gd builds the same names)."""
    out = []
    for j in (1, 10, 15, 16, 18, 20, 28, 35):
        for n in range(16):
            f = idle_frame(j, n)
            f["name"] = "j%02d_idle_%02d.png" % (j, n)
            out.append(f)
    for j in (12, 16, 20, 25, 33):
        for s, f in enumerate(arrive_frames(j, tail=1)):
            f["name"] = "j%02d_arrive_%02d.png" % (j, s)
            out.append(f)
    return out


def temp_dirs():
    out = set()
    for p in PATTERNS:
        out.update(str(x) for x in TMP.glob(p))
    return out


class Quiet(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()


def run_page(frames):
    before = temp_dirs()
    private = tempfile.mkdtemp(prefix="playwright_badge-")
    profile = os.path.join(private, "profile")
    os.makedirs(os.path.join(private, "tmp"))
    for k in ("TEMP", "TMP", "TMPDIR"):
        os.environ[k] = os.path.join(private, "tmp")
    httpd = socketserver.TCPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=str(REPO)))
    port = httpd.server_address[1]
    threading.Thread(target=httpd.serve_forever, daemon=True).start()
    try:
        from playwright.sync_api import sync_playwright
        with sync_playwright() as p:
            ctx, err = None, None
            for ch in ("chrome", "msedge"):
                try:
                    ctx = p.chromium.launch_persistent_context(profile, channel=ch, headless=True,
                                                               viewport={"width": 400, "height": 300}, device_scale_factor=1)
                    break
                except Exception as e:
                    err = e
            if ctx is None:
                raise SystemExit("no Chrome or Edge to launch: %s" % err)
            try:
                page = ctx.pages[0] if ctx.pages else ctx.new_page()
                page.goto("http://127.0.0.1:%d/tools/dev/badge/dump.html" % port)
                page.wait_for_selector("body[data-ready='1']", state="attached", timeout=60000)
                info = page.evaluate("window.__info()")
                got = page.evaluate("([l, w, h, x, cy]) => window.__dump(l, w, h, x, cy)", [frames, W, H, X, CY])
            finally:
                ctx.close()
    finally:
        httpd.shutdown()
        httpd.server_close()
        shutil.rmtree(private, ignore_errors=True)
        for d in sorted(temp_dirs() - before):
            if Path(d).name.startswith("playwright_badge-"):
                continue
            shutil.rmtree(d, ignore_errors=True)
            print(("deleted stray " if not os.path.exists(d) else "could not delete ") + d)
    return info, got


# The colours the page draws its number in (fin_eye.js closed(): chill, hot under 4, white on a tick).
# Chrome hands back an antialiased pixel's colour unpremultiplied, a unit or so off; such a pixel
# takes the nearest of these.
TEXT = [(0x8f, 0xa3, 0xba), (0xff, 0xd2, 0x8a), (0xff, 0xff, 0xff)]
# The cut: an ink pixel comes back at 0.8 or more, its spill at 0.4 or less, and Chrome's gamma for
# light text lifts the one-pixel gap inside a white 4 to about 0.55, so the cut is at 0.7.
CUT = 179


def solid(raw):
    """Clear or fill each pixel by its alpha; returns (bytes, partial count)."""
    b = bytearray(raw)
    part = 0
    for i in range(0, len(b), 4):
        a = b[i + 3]
        if a in (0, 255):
            continue
        part += 1
        if a < CUT:
            b[i:i + 4] = b"\0\0\0\0"
        else:
            c = min(TEXT, key=lambda t: sum((t[k] - b[i + k]) ** 2 for k in range(3)))
            b[i:i + 4] = bytes(c) + b"\xff"
    return bytes(b), part


def main():
    a = sys.argv[1:]
    if not a or a[0] not in ("golden", "frames") or (a[0] == "frames" and len(a) < 2):
        print(__doc__)
        return 2
    frames = golden_list() if a[0] == "golden" else frames_list()
    info, got = run_page(frames)
    print("LS %s, cap %s px, digit widths %s, '15' %s px, '16' %s px, s0w %s, goal %s px" % (
        info["LS"], info["capH"], info["digitW"], info["w15"], info["w16"], info["s0w"], info["goal"]))
    blob, partial = bytearray(), 0
    for f, g in zip(frames, got):
        px, p = solid(base64.b64decode(g["px"]))
        partial += p
        f["box"] = [g["box"]["x"], g["box"]["y"], g["box"]["w"], g["box"]["h"]]
        f["_px"] = px
    print("%d frames, %d pixels under full opacity made solid or clear" % (len(frames), partial))
    if a[0] == "golden":
        for f in frames:
            blob += f.pop("_px")
        doc = {"about": "badge 9b (eye-1b) as the approved page draws it: tools/dev/badge/dump_golden.py golden",
               "w": W, "h": H, "x": X, "cy": CY, "letter_spacing": info["LS"],
               "tooltips": info["tips"], "frames": frames,
               "rgba_gzip_b64": base64.b64encode(gzip.compress(bytes(blob), 9, mtime=0)).decode()}
        GOLDEN.write_text(json.dumps(doc, separators=(",", ":")) + "\n", encoding="utf-8")
        print("wrote", GOLDEN, GOLDEN.stat().st_size, "bytes")
    else:
        from PIL import Image
        out = Path(a[1])
        out.mkdir(parents=True, exist_ok=True)
        man = []
        for f in frames:
            Image.frombytes("RGBA", (W, H), f.pop("_px")).save(out / f["name"])
            man.append(f)
        (out / "manifest.json").write_text(json.dumps({"source": "web (dump_golden.py frames)", "w": W, "h": H, "x": X, "cy": CY,
                                                       "frames": man}, indent=1), encoding="utf-8")
        print("wrote %d PNGs to %s" % (len(man), out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
