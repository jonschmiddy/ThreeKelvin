"""A science mini game as the game draws it, beside the approved prototype drawing the same deal.

    tools/dev/godot.sh --headless --path tkg -- sheet=MiniGameTest seeds=1 dump=<dir>/game [games=a,b]
    uv run --with playwright --with pillow python tools/dev/minigame/diff.py <dir> [game ...]

`dump=` writes each game's deal (depth 3, sensors 1, seed 5) as the page names it, the stream's draws
after the deal, its canvas at the start, and its canvas after the scripted run's moves but the last
and the frames the page's loop draws them on. This runs the prototype's own file (`proto/`, copied
from tk-scratch/science/minigames/phone/src, Nov 18; the comet games' `comet_*.js` from tk-scratch/science/comet/games, Nov 21-22) as Jon approved it re-laid out and in the one UI
kit (`layout/`, Nov 20) in the installed Chrome on that same deal, its
clock held, the same moves sent as pointer and key events, counts the pixels that differ and writes
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

sys.path.insert(0, str(Path(__file__).resolve().parent))
import layout  # noqa: E402

HERE = Path(__file__).resolve().parent
PROTO = HERE / "proto"
# each game: its prototype file, and the line in its mount that deals (replaced by the dumped deal)
GAMES = {
    "coolant": ("coolant2", "const P=gen(ctx.depth,ctx.sensors,ctx.rng);", "const P=window.__P;"),
    "centrifuge": ("centrifuge2", "const P=gen(ctx.rng,ctx.depth),N=P.N", "const P=window.__P,N=P.N"),
    "icecore": ("icecore2", "const p=gen(ctx.rng,ctx.depth)", "const p=window.__P"),
    "pulsar": ("pulsar2", "g0=gen(ctx.rng,ctx.depth,sn)", "g0=window.__P"),
    "tray": ("tray2", "const P=gen(ctx.depth,ctx.rng)", "const P=window.__P"),
    "anomaly": ("anomaly2", "const pz=gen(ctx.rng,ctx.depth)", "const pz=window.__P"),
    "beams": ("beams2", "const P=gen(ctx.rng,ctx.depth,ctx.sensors)", "const P=window.__P"),
    "spectrum": ("spectrum2", "const P=gen(ctx.rng,ctx.depth)", "const P=window.__P"),
    "fourkelvin": ("fourkelvin", "const F=gen(ctx.rng,ctx.depth)", "const F=window.__P"),
    "torch": ("wreck1", "const P=gen(ctx.depth,ctx.sensors,ctx.rng);", "const P=window.__P;"),
    "leak": ("wreck3", "const P=gen(ctx.depth,ctx.sensors,ctx.rng);", "const P=window.__P;"),
    "sling": ("sling2", "const P=gen(ctx.depth,ctx.rng);", "const P=window.__P;"),
    "tuning": ("tuning2", "const g=gen(ctx.rng,ctx.depth),c=g.cfg", "const g=window.__P,c=g.cfg"),
    "seismic": ("seismic2", "const S=gen(ctx.rng,ctx.depth,ctx.sensors);", "const S=window.__P;"),
    "corescan": ("tomo2", "const c=CFG[ctx.depth],P=gen(ctx.rng,ctx.depth),n=P.n", "const c=CFG[ctx.depth],P=window.__P,n=P.n"),
    "culture": ("culture2", "const p=gen(ctx.rng,ctx.depth),c=CFG[ctx.depth]", "const p=window.__P,c=CFG[ctx.depth]"),
    "dock": ("wreck2", "const P=gen(ctx.depth,ctx.sensors,ctx.rng);", "const P=window.__P;"),
    # the comet games deal in their mounts, from the dumped draws (the stream's from its start)
    "skim": ("comet_a", ",r=ctx.rng;", ",r=ctx.rng;"),
    "flick": ("comet_h", ",r=ctx.rng;", ",r=ctx.rng;"),
    "geyser": ("comet_i", ",r=ctx.rng;", ",r=ctx.rng;"),
}
# The comet games were written in the kit (tk-scratch/science/comet, Nov 21-22): no layout swaps.
KIT_ONLY = {"skim", "flick", "geyser"}

# The layouts (fit2 for Beams and Spectrum, fit3, fit4, the kit) are in layout/: `layout.page_js`.


# The prototype's helpers with nothing that runs on its own: the clock is `__now`, frames are queued
# and run when the driver says, timers never fire, sound is silent, Math.random is a constant.
SHELL = """
window.TK={register(d){window.__reg=d},css(){},
el(tag,props,...kids){const e=document.createElement(tag);for(const[k,v]of Object.entries(props||{})){if(k==='class')e.className=v;else if(k==='style')e.style.cssText=v;else if(k==='text')e.textContent=v;else e.setAttribute(k,v)}return e},
%s};
%s
TK.pixel=function(stage,o){const w=o.w,h=o.h;const cv=document.createElement('canvas');cv.width=w;cv.height=h;
  cv.style.cssText='display:block;width:'+(w*4)+'px;height:'+(h*4)+'px';const g=cv.getContext('2d');g.imageSmoothingEnabled=false;stage.appendChild(cv);
  return{cv,g,w,h,scale:4,fit(){},pt(e){const r=cv.getBoundingClientRect();return{x:Math.floor((e.clientX-r.left)*w/r.width),y:Math.floor((e.clientY-r.top)*h/r.height)}},
    clear(c){g.fillStyle=c||TK.PAL.void;g.fillRect(0,0,w,h)},destroy(){}}};
TK.sfx=()=>{};window.TK_MUTE_TONES=true;
window.__now=1000;performance.now=()=>window.__now;Date.now=()=>window.__now;Math.random=()=>0.5;
window.__raf=null;window.requestAnimationFrame=f=>{window.__raf=f;return 1};window.cancelAnimationFrame=()=>{};
window.setInterval=()=>0;window.setTimeout=()=>0;
"""

# Godot's shapes made the page's: Pulsar's sharpness is a Map, Four Kelvin's lane centre a function.
FIXUPS = {
    "pulsar": "P.S=new Map(P.S);",
    "fourkelvin": ("const NODE=48;P.cen=x=>{x=Math.max(0,x);const i=Math.floor(x/NODE),f=x/NODE-i;"
                   "const a=P.nodes[Math.min(i,P.nodes.length-1)],b=P.nodes[Math.min(i+1,P.nodes.length-1)];return a+(b-a)*f*f*(3-2*f)};"),
}

DRIVER = """
([gid, data, fix]) => {
  const P=data.puzzle;new Function('P',fix)(P);window.__P=P;
  let di=0;const rng=()=>data.draws[di++];
  const stage=document.createElement('div');document.body.appendChild(stage);
  window.__reg.mount(stage,{depth:3,sensors:1,seed:data.seed,rng,done(){}});
  const cv=stage.querySelector('canvas');
  if((gid==='fourkelvin'||gid==='tuning'||gid==='skim'||gid==='flick'||gid==='geyser')&&window.__raf){window.__now=1000;window.__raf(1000)}
  const start=cv.toDataURL();
  const r=cv.getBoundingClientRect();
  const codes={w:'KeyW',a:'KeyA',d:'KeyD'};
  const send=e=>{
    if(e.k==='key'||e.k==='keyup'){window.dispatchEvent(new KeyboardEvent(e.k==='key'?'keydown':'keyup',{code:codes[e.key]}));return}
    const at={clientX:r.left+e.p[0]*r.width/cv.width,clientY:r.top+e.p[1]*r.height/cv.height,pointerId:1,bubbles:true};
    cv.dispatchEvent(new PointerEvent(e.k==='down'?'pointerdown':e.k==='move'?'pointermove':'pointerup',at));
  };
  // an event with `f` is sent just before frame f (a pilot that played each frame); the rest first
  for(const e of data.events)if(e.f==null)send(e);
  data.raf.forEach((t,i)=>{for(const e of data.events)if(e.f===i)send(e);window.__now=t;const f=window.__raf;if(f)f(t)});
  return [start,cv.toDataURL()];
}
"""


def page_for(gid: str) -> str:
    """The page as Jon approved it (Nov 20): kit.js, then the prototype's own file re-laid out to fill
    150x130 and dressed in the kit (`layout/`), its deal line reading the dumped deal."""
    name, deal, mine = GAMES[gid]
    if gid in KIT_ONLY:
        js = (HERE / "layout" / "kit.js").read_text(encoding="utf-8") + "\n" + (PROTO / (name + ".js")).read_text(encoding="utf-8")
    else:
        js = layout.page_js(gid)
    assert js.count(deal) == 1, gid
    js = js.replace(deal, mine, 1)
    helpers = (PROTO / "tk_helpers.js").read_text(encoding="utf-8").rstrip().rstrip(",")
    font = (PROTO / "tk_font.js").read_text(encoding="utf-8")
    return "<!doctype html><body style='margin:0'><script>%s</script><script>%s</script></body>" % (SHELL % (helpers, font), js)


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
                                                               headless=True, viewport={"width": 800, "height": 900})
                    break
                except Exception:
                    pass
            if ctx is None:
                raise SystemExit("no Chrome or Edge to launch")
            try:
                for gid, data in dumps.items():
                    page = ctx.new_page()
                    page.set_content(page_for(gid))
                    got[gid] = page.evaluate(DRIVER, [gid, data, FIXUPS.get(gid, "")])
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
    want = sys.argv[2:] or [g for g in GAMES if (d / "game" / ("%s_puzzle.json" % g)).exists()]
    dumps = {g: json.loads((d / "game" / ("%s_puzzle.json" % g)).read_text(encoding="utf-8")) for g in want}
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
