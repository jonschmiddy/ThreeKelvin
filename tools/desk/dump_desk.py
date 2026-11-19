"""The approved science desk page, run by its own code, for the game's port (`DeskRoom`).

    uv run --with playwright python tools/desk/dump_desk.py bake desk_1
        writes tkg/art/desk/bake/desk_1/: meta.json and the planes (gzipped float32, row major,
        384 x 216 unless named): a2c (RGBA, the art with its keyboard and settled dust), fields (RGBA:
        lamp, screen, porthole), small_i / small_v (RGBA: up to four string bulbs a pixel, index + 1 and
        value), px (RGBA: tone gain, occlusion, room vignette, skip; not "aux", a device name on Windows), role (R: DeskRoom.ROLE_*),
        glass (150 x 140 RGBA: shade, boot type time)
    uv run --with playwright python tools/desk/dump_desk.py frames desk_1 OUTDIR
        writes the page's own 1920 x 1080 frames at FRAMES' times and manifest.json, which
        `-- sheet=DeskRooms frames=OUTDIR/manifest.json` reads to draw the game's frames at the same times

The page is tools/desk/page/ (a copy of Jon's approved deskpower page, Nov 19); dump.html loads its
sources verbatim. Uses the installed Chrome (or Edge), no browser download; deletes its temp profile
and any %TEMP% cdp-* / playwright-* folders that appeared during the run.
"""
import base64, functools, gzip, http.server, json, os, shutil, socketserver, sys, tempfile, threading
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
BAKE = REPO / "tkg" / "art" / "desk" / "bake"
TMP = Path(tempfile.gettempdir())
PATTERNS = ("cdp-*", "playwright-artifacts-*", "playwright_*")

# The shell's timeline (page/index.html): act 1 stretched to ZOOM_S, the power-on SPEED x fast, idle from KNEE.
A, ZOOM_S, SPEED, KNEE, OFF_SPEED = 2.5, 2.9, 1.25, 10.0, 2.2
PK = ZOOM_S + (KNEE - A) / SPEED


def real_of(ts):
    return ts * ZOOM_S / A if ts < A else ZOOM_S + (ts - A) / SPEED if ts < KNEE else PK + (ts - KNEE)


def frames_list():
    out = []
    for ts in (3.0, 3.45, 3.6, 4.0, 4.4, 4.8, 5.2, 5.5, 6.0, 6.5, 7.0, 8.0, 9.0, 10.0, 11.5, 13.0):
        out.append({"name": "on_%05.2f.png" % ts, "ts": ts, "real": real_of(ts), "leaving": False})
    for k in range(8):  # idle, an eighth of a second apart
        real = 20.0 + k / 8.0
        out.append({"name": "idle_%d.png" % k, "ts": KNEE + real - PK, "real": real, "leaving": False})
    frm = 11.8
    for ts in (11.0, 9.0, 7.0, 5.5, 5.2, 5.0, 4.0, 3.0):
        out.append({"name": "off_%05.2f.png" % ts, "ts": ts, "real": 30.0 + (frm - ts) / OFF_SPEED, "leaving": True})
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


def with_page(fn):
    before = temp_dirs()
    private = tempfile.mkdtemp(prefix="playwright_desk-")
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
                logs = []
                page.on("console", lambda m: logs.append(m.text) if m.type == "error" else None)
                page.goto("http://127.0.0.1:%d/tools/desk/dump.html" % port)
                page.wait_for_function("document.body.dataset.ready === '1' || !!document.body.dataset.error", timeout=60000)
                e = page.evaluate("document.body.dataset.error || ''")
                if e:
                    raise SystemExit("the page failed: " + e)
                got = fn(page)
                if logs:
                    print("page console errors:\n  " + "\n  ".join(logs))
                return got
            finally:
                ctx.close()
    finally:
        httpd.shutdown()
        httpd.server_close()
        shutil.rmtree(private, ignore_errors=True)
        for d in sorted(temp_dirs() - before):
            if Path(d).name.startswith("playwright_desk-"):
                continue
            shutil.rmtree(d, ignore_errors=True)
            print(("deleted stray " if not os.path.exists(d) else "could not delete ") + d)


def bake(room):
    got = with_page(lambda page: page.evaluate("id => window.__bake(id)", room))
    out = BAKE / room
    out.mkdir(parents=True, exist_ok=True)
    for name, b in got["planes"].items():
        raw = base64.b64decode(b)
        # mtime 0: the same bake writes the same bytes
        (out / (name + ".bin.gz")).write_bytes(gzip.compress(raw, 9, mtime=0))
        print("%-8s %8d bytes raw, %8d gz" % (name, len(raw), (out / (name + ".bin.gz")).stat().st_size))
    meta = got["meta"]
    (out / "meta.json").write_text(json.dumps(meta, separators=(",", ":")), encoding="utf-8")
    print("meta: %d small lights (%d pixel overflows past eight), tube scale %.6f"
          % (meta["smallCount"], meta["smallOver"], meta["tubeScale"]))
    if meta["smallOver"]:
        raise SystemExit("more than eight string bulbs light one pixel: widen small_i/small_v")


def frames(room, outdir):
    outdir = Path(outdir)
    outdir.mkdir(parents=True, exist_ok=True)
    fl = frames_list()

    def go(page):
        res = []
        for f in fl:
            res.append(page.evaluate("([id, ts, real, lv]) => window.__frame(id, ts, real, lv)", [room, f["ts"], f["real"], f["leaving"]]))
        return res
    got = with_page(go)
    for f, url in zip(fl, got):
        (outdir / f["name"]).write_bytes(base64.b64decode(url.split(",", 1)[1]))
    (outdir / "manifest.json").write_text(json.dumps({"room": room, "frames": fl}, indent=1), encoding="utf-8")
    print("%d frames in %s" % (len(fl), outdir))


def main():
    a = sys.argv[1:]
    if len(a) >= 2 and a[0] == "bake":
        bake(a[1])
    elif len(a) >= 3 and a[0] == "frames":
        frames(a[1], a[2])
    else:
        raise SystemExit(__doc__)


if __name__ == "__main__":
    main()
