"""A science mini game as the game draws it, beside the approved prototype drawing the same deal.

    tools/dev/godot.sh --headless --path tkg -- sheet=MiniGameTest seeds=1 dump=<dir>/game [games=a,b]
    uv run --with playwright --with pillow python tools/dev/minigame/diff.py <dir> [game ...]

`dump=` writes each game's deal (depth 3, sensors 1, seed 5) as the page names it, the stream's draws
after the deal, its canvas at the start, and its canvas after the scripted run's moves but the last
and the frames the page's loop draws them on. This runs the prototype's own file (`proto/`, copied
from tk-scratch/science/minigames/phone/src, Nov 18) in the installed Chrome on that same deal, its
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
}

# The layouts Jon picked to fit the glass (Nov 19, "fit2"): the prototype's own file with these swaps
# is what the game is held to. Beams: LIT and TURNS in a left column, the table the square beside it.
# Spectrum: a tighter header, a 5-px meter carrying MATCH! (its dividers gone once full).
BEAMS_FIT = [
    ("const W=150,H=150,CS=Math.floor(118/n),BW=n*CS,BX=Math.floor((W-BW)/2),BY=14+Math.floor((H-14-BW)/2);",
     "const W=150,H=130,CS=Math.floor(106/n),BW=n*CS,BX=20+Math.floor((130-BW)/2),BY=Math.floor((H-BW)/2);"),
    ("TK.text(g,'LIT',4,3,PAL.cold);", "TK.text(g,'LIT',4,4,PAL.cold);"),
    ("R(g,19+k*7,3,5,5,'#000');R(g,20+k*7,4,3,3,on?col:'#1f2935')", "R(g,5,12+k*7,5,5,'#000');R(g,6,13+k*7,3,3,on?col:'#1f2935')"),
    ("TK.text(g,'TURNS '+taps,W-4,3,PAL.cold,'right');", "TK.text(g,'TURNS',1,H-20,PAL.cold);TK.text(g,String(taps),10,H-13,PAL.cold,'center');"),
    ("if(won)TK.text(g,'ALL LIT',W>>1,H-7,PAL.hot,'center');", "if(won){TK.text(g,'ALL',10,48,PAL.hot,'center');TK.text(g,'LIT',10,55,PAL.hot,'center')}"),
]

SPECTRUM_FIT = [
    ("ROW=13,TY=50,H=TY+T*ROW+12;", "ROW=13,TY=40,H=TY+T*ROW-1;"),
    ("strip(4,10);strip(22,10);", "strip(2,10);strip(17,10);"),
    ("TK.text(b,'STAR',2,7,PAL.chill);TK.text(b,'YOU',2,25,PAL.chill);", "TK.text(b,'STAR',2,5,PAL.chill);TK.text(b,'YOU',2,20,PAL.chill);"),
    ("drawLine(lineX(bn),4,10,", "drawLine(lineX(bn),2,10,"),
    ("drawLine(x,22,10,binCol(bn),.6,", "drawLine(x,17,10,binCol(bn),.6,"),
    ("R(g,x,15,2,1,PAL.good);R(g,x,20,2,1,PAL.good);for(let y=16;y<20;y++)", "R(g,x,13,2,1,PAL.good);R(g,x,15,2,1,PAL.good);for(let y=14;y<15;y++)"),
    ("drawLine(x+wob,22,10,binCol(bn),0,false);R(g,x-1+wob,21,4,1,PAL.bad);R(g,x-1+wob,32,4,1,PAL.bad);",
     "drawLine(x+wob,17,10,binCol(bn),0,false);R(g,x-1+wob,16,4,1,PAL.bad);R(g,x-1+wob,27,4,1,PAL.bad);"),
    ("(f.y0+(22-f.y0)*u*u):(22+(f.y0-22)*u)", "(f.y0+(17-f.y0)*u*u):(17+(f.y0-17)*u)"),
    ("MY=36;", "MY=31;"),
    ("R(g,MX-1,MY-1,MW+2,10,'#000');R(g,MX,MY,MW,8,PAL.void);", "R(g,MX-1,MY-1,MW+2,7,'#000');R(g,MX,MY,MW,5,PAL.void);"),
    ("for(let y=0;y<8;y++)R(g,MX+x,MY+y,1,1,y===0?mix(mcol,'#ffffff',.5):y>5?", "for(let y=0;y<5;y++)R(g,MX+x,MY+y,1,1,y===0?mix(mcol,'#ffffff',.5):y>3?"),
    ("for(let k=1;k<tgt.length;k++){const x=MX+Math.round(MW*k/tgt.length);R(g,x,MY,1,8,'#000')}",
     "if(!(frac===1&&!extras))for(let k=1;k<tgt.length;k++){const x=MX+Math.round(MW*k/tgt.length);R(g,x,MY,1,5,'#000')}"),
    ("MX+MW-2,MY+2,frac>0.55", "MX+MW-2,MY,frac>0.55"),
    ("if(won)TK.text(g,'MATCH!',W>>1,H-8,PAL.good,'center');", "if(won)TK.text(g,'MATCH!',SX+(SW>>1),MY,'#0a0e15','center');"),
    ("TK.text(g,'NO POWER',W>>1,H-8,PAL.bad,'center');", "TK.text(g,'NO POWER',SX+(SW>>1),MY,PAL.bad,'center');"),
    ("if(over&&!won)TK.text(g,'NO MATCH',W>>1,H-8,PAL.bad,'center');", "if(over&&!won)TK.text(g,'NO MATCH',SX+(SW>>1),MY,PAL.bad,'center');"),
]
LAYOUT = {"beams": BEAMS_FIT, "spectrum": SPECTRUM_FIT}


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
  if(gid==='fourkelvin'&&window.__raf){window.__now=1000;window.__raf(1000)}
  const start=cv.toDataURL();
  const r=cv.getBoundingClientRect();
  const codes={w:'KeyW',a:'KeyA',d:'KeyD'};
  for(const e of data.events){
    if(e.k==='key'||e.k==='keyup'){window.dispatchEvent(new KeyboardEvent(e.k==='key'?'keydown':'keyup',{code:codes[e.key]}));continue}
    const at={clientX:r.left+e.p[0]*r.width/cv.width,clientY:r.top+e.p[1]*r.height/cv.height,pointerId:1,bubbles:true};
    cv.dispatchEvent(new PointerEvent(e.k==='down'?'pointerdown':e.k==='move'?'pointermove':'pointerup',at));
  }
  for(const t of data.raf){window.__now=t;const f=window.__raf;if(f)f(t)}
  return [start,cv.toDataURL()];
}
"""


def page_for(gid: str) -> str:
    name, deal, mine = GAMES[gid]
    js = (PROTO / (name + ".js")).read_text(encoding="utf-8")
    assert deal in js, gid
    js = js.replace(deal, mine, 1)
    for a, b in LAYOUT.get(gid, []):
        assert a in js, (gid, a)
        js = js.replace(a, b)
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
