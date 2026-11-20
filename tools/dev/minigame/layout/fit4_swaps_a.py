"""fit4, set A: Coolant, Centrifuge, Ice Core, Sample Tray and Signal Tuning re-laid out to fill the
150 x 130 game area exactly at every deal. Same rules, same puzzle sizes: each list is (old, new)
string swaps on the prototype's own JS, every `old` asserted present exactly once.

    from fit4_swaps_a import COOLANT, CENTRIFUGE, ICECORE, TRAY, TUNING, patched
    js = patched("coolant2.js", COOLANT)
"""
from __future__ import annotations

from pathlib import Path

PROTO = Path(__file__).resolve().parent.parent / "proto"

# ---- Coolant Routing: 150 x 130 always. Tiles are as big as the area allows (the 18 px cap goes):
# 18 -> 22 px at sector 1, 18 -> 20 at 2, 18 at 3, 16 -> 18 at 4, 16 at 5 (7 columns: width-bound).
# The grid is centred in rows 9-116, HEAT/TURNS on top, the status line (and the start hint) at the bottom.
COOLANT = [
    ("const W=144,E=14; // canvas width; core/chamber column width",
     "const W=150,H=130,E=14; // canvas size (every deal); core/chamber column width"),
    ("  const S=Math.min(18,Math.floor((W-4-2*E)/w),Math.floor(96/h))&~1; // tile size, even\n"
     "  const GX=Math.floor((W-w*S)/2),GY=11,H=GY+h*S+19,TY=H-12; // bottom strip: hint with its icon, then status",
     "  const S=Math.min(Math.floor((W-4-2*E)/w),Math.floor(108/h))&~1; // tile size, even: as big as rows 9-116 allow\n"
     "  const GX=Math.floor((W-w*S)/2),GY=9+((108-h*S)>>1),TY=H-8; // grid centred in rows 9-116; hint / status at the bottom"),
]

# ---- Centrifuge: 144x118 -> 150x130. Bowl radius 50 -> 52 (rotor 44 -> 46, slot ring 32 -> 34), hub
# at (53, 61) so the bowl ends above the start hint. Rack 40 wide down the right, cells 19x15 -> 18x17 on an
# 18-row pitch, SPIN 15 -> 17 tall under it. The round bowl's corners keep the terminal's gridded backdrop.
CENTRIFUGE = [
    ("const W=144,H=118;\n"
     "const CX=50,CY=58;          // rotor hub\n"
     "const RB=50,RR=44,RS=32,HUB=14; // bowl, rotor, slot ring, hub window radii\n"
     "const RACK={x:101,y:9,w:42,h:74},SPIN={x:103,y:87,w:38,h:15};",
     "const W=150,H=130;\n"
     "const CX=53,CY=61;          // rotor hub\n"
     "const RB=52,RR=46,RS=34,HUB=14; // bowl, rotor, slot ring, hub window radii\n"
     "const RACK={x:109,y:8,w:40,h:82},SPIN={x:110,y:94,w:38,h:17};"),
    ("return{x:RACK.x+2+col*20,y:RACK.y+9+row*16,w:19,h:15}}",
     "return{x:RACK.x+2+col*19,y:RACK.y+9+row*18,w:18,h:17}}"),
    ("if(!tray.length)TK.text(g,'EMPTY',RACK.x+RACK.w/2,RACK.y+30,",
     "if(!tray.length)TK.text(g,'EMPTY',RACK.x+RACK.w/2,RACK.y+38,"),
    ("      tubeSide(r.x+3,r.y+1,m,on);\n      TK.text(g,String(m),r.x+13,r.y+5,",
     "      tubeSide(r.x+3,r.y+2,m,on);\n      TK.text(g,String(m),r.x+12,r.y+6,"),
    ("TK.text(g,'SPIN',b.x+b.w/2,b.y+5+pr,", "TK.text(g,'SPIN',b.x+b.w/2,b.y+6+pr,"),
]

# ---- Ice Core: 144x120 -> 150x130. Core layers 12x7 -> 14x8 on an 18 px pitch (was 16), the drawer
# 6 rows taller; tray samples 16x10 -> 18x11 on 20x14; the stack tube 24 -> 26 wide, slots 8 -> 9 tall;
# CLEAR / CHECK 26x12 -> 30x13 along the bottom; the check message and start icons beside them.
ICECORE = [
    ("const W=144,H=120;", "const W=150,H=130;"),
    ("const CX0=16,CDX=16,CW=12,LH=7,GH=5,CB=62;", "const CX0=17,CDX=18,CW=14,LH=8,GH=5,CB=68;"),
    ("const SX=104,SW=24,SH=8,SB=96;", "const SX=113,SW=26,SH=9,SB=106;"),
    ("const PX0=4,PDX=18,PW=16,PHh=10,PY0=80,PDY=13;", "const PX0=4,PDX=20,PW=18,PHh=11,PY0=86,PDY=14;"),
    ("const BY=106,BH=12,BCL=[91,26],BCK=[118,26];", "const BY=115,BH=13,BCL=[86,30],BCK=[118,30];"),
    ("R(bx,18,bw,49,PAL.panel);TK.dither(g,bx,18,bw,6,PAL.panel,PAL.line,.5);R(bx,18,bw,1,PAL.line);R(bx,18,1,49,PAL.line)",
     "R(bx,18,bw,CB-13,PAL.panel);TK.dither(g,bx,18,bw,6,PAL.panel,PAL.line,.5);R(bx,18,bw,1,PAL.line);R(bx,18,1,CB-13,PAL.line)"),
    ("TK.text(g,'LAYERS '+n,92,2,PAL.cold,'right')", "TK.text(g,'LAYERS '+n,105,2,PAL.cold,'right')"),
    ("TK.text(g,'NEW',1,24,PAL.cold);TK.text(g,'OLD',1,56,PAL.cold);\n"
     "    for(let y=31;y<=53;y++)R(6,y,1,1,PAL.line);",
     "TK.text(g,'NEW',1,24,PAL.cold);TK.text(g,'OLD',1,CB-6,PAL.cold);\n"
     "    for(let y=31;y<=CB-9;y++)R(6,y,1,1,PAL.line);"),
    ("let ny=68;", "let ny=CB+6;"),
    ("const w1=TK.icon(g,'click',2,106,{t:tt});TK.icon(g,'drag',2+w1+4,106,{t:tt})",
     "const w1=TK.icon(g,'click',2,BY+1,{t:tt});TK.icon(g,'drag',2+w1+4,BY+1,{t:tt})"),
    ("if(m)TK.text(g,m,2,108+6,", "if(m)TK.text(g,m,2,BY+4,"),
]

# ---- Sample Tray: 144x108 -> 150x130. Cells 15 -> 18 px (canisters 13 -> 16 across; the canister,
# floor-hole and arrow art is drawn from the cell size, same bands and pixel rules). The MOVES / PAR /
# BAY / UNDO column moves right to x 120; UNDO 37x12 -> 28x14. The plate is the panel colour throughout.
TRAY = [
    ("const W=144,H=108,C=15,GX=8,GY=9;      // 6x6 cells of 15 art px",
     "const W=150,H=130,C=18,GX=6,GY=11;     // 6x6 cells of 18 art px"),
    ("const RX=104;                           // right column", "const RX=120;                           // right column"),
    ("const UB={x:RX,y:88,w:37,h:12};", "const UB={x:RX,y:105,w:28,h:14};"),
    ("if(cap)col=a<3?PAL.hot:a<8?PAL.flare:a<11?PAL.ember:shade(PAL.ember,-.4);",
     "if(cap)col=a<3?PAL.hot:a<T-5?PAL.flare:a<T-2?PAL.ember:shade(PAL.ember,-.4);"),
    ("if(a===1||a===11)col=shade(PAL.tractor,-.5);", "if(a===1||a===T-2)col=shade(PAL.tractor,-.5);"),
    ("else{const f=Math.abs(a-6.5)/4.5;", "else{const f=Math.abs(a-T/2)/((T-4)/2);"),
    ("if((along===1||along===alen-2)&&a===6)col=PAL.chill; // rivet",
     "if((along===1||along===alen-2)&&a===((T-1)>>1))col=PAL.chill; // rivet"),
    ("if(kind==='bolt'&&a>4&&a<8&&", "if(kind==='bolt'&&a>((T-1)>>1)-2&&a<((T-1)>>1)+2&&"),
    ("if(cx>=6&&cx<=8&&cy>=6&&cy<=8)col=(cx===7&&cy===7)?",
     "if(Math.abs(cx-(C>>1))<=1&&Math.abs(cy-(C>>1))<=1)col=(cx===(C>>1)&&cy===(C>>1))?"),
    ("const cx=x+7,cy=y+7;\n    g.fillStyle=PAL.ember;", "const cx=x+(C>>1),cy=y+(C>>1);\n    g.fillStyle=PAL.ember;"),
]

# ---- Signal Tuning: 144x108 -> 150x130. The two scopes grow 58 -> 74 px (trace radius 24 -> 32) and
# take the whole width; PAR / STEP / MATCH move under YOURS beside the knobs, in a dark readout box (the
# MATCH meter lies on its side, 11 segments left to right), LOCK 25x22 -> 39x16 under it. Knobs keep their
# size, labels and values.
TUNING = [
    ("const PW=144,PH=108;\n"
     "const SC=[{x:1,lab:'TARGET'},{x:61,lab:'YOURS'}]; // scope frames, 58x58 at y=7\n"
     "const SY=7,SS=58,R=24;\n"
     "const KY=85,KR=8; // knob centre row, knob radius\n"
     "const LOCK={x:118,y:74,w:25,h:22};",
     "const PW=150,PH=130;\n"
     "const SC=[{x:0,lab:'TARGET'},{x:76,lab:'YOURS'}]; // scope frames, 74x74 at y=7\n"
     "const SY=7,SS=74,R=32,HS=SS>>1; // HS: the glass centre's offset in a frame\n"
     "const KLY=84,KY=102,KR=8,KW=106; // knob label row, knob centre row, knob radius, the knobs' width\n"
     "const LOCK={x:110,y:112,w:39,h:16};"),
    ("const slot=116/knobs.length;", "const slot=KW/knobs.length;"),
    ("    const cx=x+29,cy=SY+29;\n    for(let k=-2;", "    const cx=x+HS,cy=SY+HS;\n    for(let k=-2;"),
    ("    const cx=x+29,cy=SY+29;\n    // wob", "    const cx=x+HS,cy=SY+HS;\n    // wob"),
    ("TK.text(G,k.lab,cx,66,PAL.cold,'center');", "TK.text(G,k.lab,cx,KLY,PAL.cold,'center');"),
    ("for(const[sx,sy]of[[1,1],[142,1],[1,106],[142,106]])", "for(const[sx,sy]of[[1,1],[PW-2,1],[1,PH-2],[PW-2,PH-2]])"),
    ("TK.text(G,s.lab,s.x+29,1,", "TK.text(G,s.lab,s.x+HS,1,"),
    ("bx=SC[1].x+29-Math.floor(wpx/2)-2;\n      px(bx,SY+44,wpx+4,9,PAL.bevelLo);TK.text(G,s,SC[1].x+29,SY+46,",
     "bx=SC[1].x+HS-Math.floor(wpx/2)-2;\n      px(bx,SY+SS-14,wpx+4,9,PAL.bevelLo);TK.text(G,s,SC[1].x+HS,SY+SS-12,"),
    ("    const rx=131;\n"
     "    TK.text(G,'PAR',rx,9,PAL.cold,'center');TK.text(G,String(parNow),rx,16,PAL.hot,'center');\n"
     "    TK.text(G,'STEP',rx,25,PAL.cold,'center');TK.text(G,String(taps),rx,32,taps>parNow+2+free?PAL.flare:PAL.hot,'center');",
     "    const rx=LOCK.x+2,rr=PW-3;px(LOCK.x-1,KLY-3,LOCK.w+1,31,PAL.bevelLo);px(LOCK.x,KLY-2,LOCK.w-1,29,PAL.void);\n"
     "    TK.text(G,'PAR',rx,KLY,PAL.cold);TK.text(G,String(parNow),rr,KLY,PAL.hot,'right');\n"
     "    TK.text(G,'STEP',rx,KLY+7,PAL.cold);TK.text(G,String(taps),rr,KLY+7,taps>parNow+2+free?PAL.flare:PAL.hot,'right');"),
    ("const mx=125,my=40,mh=24,", "const mx=LOCK.x+1,my=KLY+20,mw=LOCK.w-2,mh=7,"),
    ("      px(mx,my,13,mh,PAL.bevelLo);px(mx+1,my+1,11,mh-2,'#05080d');\n"
     "      for(let j=0;j<segs;j++){const yy=my+mh-3-j*2,on=j<n,top=f>=.999;\n"
     "        px(mx+2,yy,9,1,",
     "      px(mx,my,mw,mh,PAL.bevelLo);px(mx+1,my+1,mw-2,mh-2,'#05080d');\n"
     "      for(let j=0;j<segs;j++){const xx=mx+((mw-segs*3+1)>>1)+j*3,on=j<n,top=f>=.999;\n"
     "        px(xx,my+2,2,mh-4,"),
    ("TK.text(G,'MATCH',rx,my+mh+2,f>=.999?PAL.mark:PAL.cold,'center');", "TK.text(G,'MATCH',rx,my-6,f>=.999?PAL.mark:PAL.cold);"),
    ("bx=72-Math.floor(W/2);", "bx=(PW>>1)-Math.floor(W/2);"),
]

FILES = {"coolant2.js": COOLANT, "centrifuge2.js": CENTRIFUGE, "icecore2.js": ICECORE, "tray2.js": TRAY, "tuning2.js": TUNING}


def patched(name: str, swaps: list[tuple[str, str]]) -> str:
    js = (PROTO / name).read_text(encoding="utf-8")
    for a, b in swaps:
        assert js.count(a) == 1, (name, js.count(a), a[:80])
        js = js.replace(a, b)
    return js


if __name__ == "__main__":
    for f, sw in FILES.items():
        patched(f, sw)
        print(f, len(sw), "swaps apply")
