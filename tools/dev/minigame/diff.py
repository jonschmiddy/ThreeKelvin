"""A science mini game as the game draws it, beside the approved prototype drawing the same puzzle.

    tools/dev/godot.sh --headless --path tkg -- sheet=MiniGameTest seeds=1 dump=<dir>/game
    uv run --with playwright --with pillow python tools/dev/minigame/diff.py <dir>

`dump=` writes each game's puzzle (depth 3, sensors 1, seed 5), its canvas at the start and its canvas
solved but for the last move. This runs the prototype's own game file (`proto/`, copied from
tk-scratch/science/minigames/phone/src, Nov 18) in the installed Chrome on that same puzzle, with the
clock held at 0 and the same moves sent as pointer events, counts the pixels that differ and writes
<dir>/<id>_<frame>_compare.png: prototype, game, and the differing pixels in red, at 4x.
"""
from __future__ import annotations

import base64
import io
import json
import os
import shutil
import sys
import tempfile
from pathlib import Path

from PIL import Image

HERE = Path(__file__).resolve().parent
PROTO = HERE / "proto"
GAMES = {"coolant": "coolant2", "centrifuge": "centrifuge2"}

# The prototype's helpers with nothing that runs later: no clock, no frames, no timers, no sound.
SHELL = """
window.TK={register(d){window.__reg=d},
el(tag,props,...kids){const e=document.createElement(tag);for(const[k,v]of Object.entries(props||{})){if(k==='class')e.className=v;else if(k==='style')e.style.cssText=v;else if(k==='text')e.textContent=v;else e.setAttribute(k,v)}return e},
%s};
%s
TK.pixel=function(stage,o){const w=o.w,h=o.h;const cv=document.createElement('canvas');cv.width=w;cv.height=h;
  cv.style.cssText='display:block;width:'+(w*4)+'px;height:'+(h*4)+'px';const g=cv.getContext('2d');g.imageSmoothingEnabled=false;stage.appendChild(cv);
  return{cv,g,w,h,scale:4,fit(){},pt(e){const r=cv.getBoundingClientRect();return{x:Math.floor((e.clientX-r.left)*w/r.width),y:Math.floor((e.clientY-r.top)*h/r.height)}},
    clear(c){g.fillStyle=c||TK.PAL.void;g.fillRect(0,0,w,h)},destroy(){}}};
TK.sfx=()=>{};
performance.now=()=>1000;Date.now=()=>1000;
window.requestAnimationFrame=()=>0;window.setInterval=()=>0;window.setTimeout=()=>0;
"""

DRIVER = """
([puz, taps]) => {
  const stage=document.createElement('div');document.body.appendChild(stage);
  window.__P=puz;
  const inst=window.__reg.mount(stage,{depth:3,sensors:1,rng:Math.random,done(){}});
  const cv=stage.querySelector('canvas');const start=cv.toDataURL();
  const r=cv.getBoundingClientRect();
  for(const [x,y] of taps){
    const at={clientX:r.left+(x+0.5)*r.width/cv.width,clientY:r.top+(y+0.5)*r.height/cv.height,pointerId:1,bubbles:true};
    cv.dispatchEvent(new PointerEvent('pointerdown',at));cv.dispatchEvent(new PointerEvent('pointerup',at));
  }
  return [start,cv.toDataURL()];
}
"""


def page_for(gid: str) -> str:
    js = (PROTO / (GAMES[gid] + ".js")).read_text(encoding="utf-8")
    # the puzzle comes from the game's dump, not the prototype's own deal
    js = js.replace("const P=gen(ctx.depth,ctx.sensors,ctx.rng);", "const P=window.__P;")
    js = js.replace("const P=gen(ctx.rng,ctx.depth),N=P.N", "const P=window.__P,N=P.N")
    assert "window.__P" in js, gid
    helpers = (PROTO / "tk_helpers.js").read_text(encoding="utf-8").rstrip().rstrip(",")
    font = (PROTO / "tk_font.js").read_text(encoding="utf-8")
    return "<!doctype html><body style='margin:0'><script>%s</script><script>%s</script></body>" % (SHELL % (helpers, font), js)


def as_proto(gid: str, puz: dict) -> dict:
    """The dump's puzzle in the prototype's own names."""
    if gid == "coolant":
        out = dict(puz)
        out["pathLen"] = out.pop("path_len")
        out["tiles"] = [dict(t, goal=None if t["goal"] < 0 else t["goal"]) for t in puz["tiles"]]
        return out
    out = dict(puz)
    out["N"] = out.pop("n")
    return out


def run(dumps: dict) -> dict:
    private = tempfile.mkdtemp(prefix="playwright_minigame-")
    for k in ("TEMP", "TMP", "TMPDIR"):
        os.environ[k] = private
    got = {}
    try:
        from playwright.sync_api import sync_playwright
        with sync_playwright() as p:
            ctx = None
            for ch in ("chrome", "msedge"):
                try:
                    ctx = p.chromium.launch_persistent_context(os.path.join(private, "profile"), channel=ch,
                                                               headless=True, viewport={"width": 800, "height": 700})
                    break
                except Exception:
                    pass
            if ctx is None:
                raise SystemExit("no Chrome or Edge to launch")
            try:
                for gid, (puz, taps) in dumps.items():
                    page = ctx.new_page()
                    page.set_content(page_for(gid))
                    got[gid] = page.evaluate(DRIVER, [as_proto(gid, puz), taps])
                    page.close()
            finally:
                ctx.close()
    finally:
        shutil.rmtree(private, ignore_errors=True)
    return got


def png(url: str) -> Image.Image:
    return Image.open(io.BytesIO(base64.b64decode(url.split(",", 1)[1]))).convert("RGB")


def sheet(a: Image.Image, b: Image.Image, out: Path) -> int:
    w, h = a.size
    diff = Image.new("RGB", (w, h))
    n = 0
    pa, pb, pd = a.load(), b.load(), diff.load()
    for y in range(h):
        for x in range(w):
            if pa[x, y] != pb[x, y]:
                n += 1
                pd[x, y] = (255, 40, 40)
            else:
                pd[x, y] = tuple(v // 4 for v in pa[x, y])
    s = Image.new("RGB", (w * 3 + 16, h), (40, 40, 40))
    for k, im in enumerate((a, b, diff)):
        s.paste(im, (k * (w + 8), 0))
    s.resize((s.width * 4, h * 4), Image.NEAREST).save(out)
    return n


def main() -> int:
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    d = Path(sys.argv[1])
    dumps = {}
    for gid in GAMES:
        j = json.loads((d / "game" / ("%s_puzzle.json" % gid)).read_text(encoding="utf-8"))
        dumps[gid] = (j["puzzle"], j["taps"])
    got = run(dumps)
    bad = 0
    for gid, (start, end) in got.items():
        for frame, url in (("start", start), ("end", end)):
            game = Image.open(d / "game" / ("%s_%s.png" % (gid, frame))).convert("RGB")
            proto = png(url)
            if proto.size != game.size:
                print("%s %s: sizes differ, prototype %s, game %s" % (gid, frame, proto.size, game.size))
                bad += 1
                continue
            n = sheet(proto, game, d / ("%s_%s_compare.png" % (gid, frame)))
            print("%s %s: %d of %d pixels differ" % (gid, frame, n, game.width * game.height))
            bad += 1 if n else 0
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
