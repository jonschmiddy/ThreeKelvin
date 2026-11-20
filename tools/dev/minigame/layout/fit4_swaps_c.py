"""fit4 (Jon, Nov 19): every game draws exactly 150x130 (152x130 for the wreck games) at every deal.
Agent C's games: Cutting Torch, Leak Hunt, Beams, Seismic Scan, Culture Dish, Tumble Dock, Core Scan.
Same rules and puzzle sizes; each list is (old, new) string swaps on the prototype's own JS file, every
`old` asserted present exactly once.

    from fit4_swaps_c import FILES, patched
    js = patched("wreck1.js", TORCH)
"""
from __future__ import annotations

from pathlib import Path

PROTO = Path(__file__).resolve().parent.parent / "proto"

# ---- Cutting Torch (152x116 -> 152x130): the hull plate and its puzzle are untouched (sim 304x200, the
# camera 152x100). The HUD strip grows 16 -> 30 rows and splits in two lines: GAS with a long bar
# (32 -> 130 px, 7 px tall), then HITS with bigger boxes (4x5 -> 7x7) and the status on the right.
TORCH = [
    ("const HUDL={gasX:3,barX:17,barW:32,hitsX:55,boxX:73,boxP:5,statusR:149};",
     "const HUDL={gasX:3,barX:17,barW:130,hitsX:3,boxX:21,boxP:9,statusR:149};"),
    ("const PW=W/2,PH=H/2,HUD=16;", "const PW=W/2,PH=H/2,HUD=30;"),
    ("    TK.text(g,'GAS',Lh.gasX,PH+6,A.chill);\n"
     "    const gl=clamp(1-S.used/P.gas);\n"
     "    g.fillStyle=A.bevelLo;g.fillRect(Lh.barX,PH+5,bw+2,7);g.fillStyle=A.line;g.fillRect(Lh.barX+1,PH+6,bw,5);\n"
     "    const fillw=Math.round(bw*gl);const gc=gl<0.2?A.bad:A.flare;\n"
     "    for(let i=0;i<fillw;i++){put(g,Lh.barX+1+i,PH+6,gl<0.2?'#e07a62':A.hot);for(let j=1;j<5;j++)put(g,Lh.barX+1+i,PH+6+j,j===4?(gl<0.2?'#7a2f24':A.ember):gc)}\n"
     "    TK.text(g,'HITS',Lh.hitsX,PH+6,A.chill);\n"
     "    for(let i=0;i<HITS_MAX;i++){const x=Lh.boxX+i*Lh.boxP,y=PH+6;const on=i<S.hits;g.fillStyle=A.bevelLo;g.fillRect(x,y,4,5);g.fillStyle=on?A.bad:A.line;g.fillRect(x+1,y+1,2,3);if(on)put(g,x+1,y+1,'#e07a62')}",
     "    TK.text(g,'GAS',Lh.gasX,PH+7,A.chill);\n"
     "    const gl=clamp(1-S.used/P.gas);\n"
     "    g.fillStyle=A.bevelLo;g.fillRect(Lh.barX,PH+5,bw+2,9);g.fillStyle=A.line;g.fillRect(Lh.barX+1,PH+6,bw,7);\n"
     "    const fillw=Math.round(bw*gl);const gc=gl<0.2?A.bad:A.flare;\n"
     "    for(let i=0;i<fillw;i++){put(g,Lh.barX+1+i,PH+6,gl<0.2?'#e07a62':A.hot);for(let j=1;j<7;j++)put(g,Lh.barX+1+i,PH+6+j,j===6?(gl<0.2?'#7a2f24':A.ember):gc)}\n"
     "    TK.text(g,'HITS',Lh.hitsX,PH+20,A.chill);\n"
     "    for(let i=0;i<HITS_MAX;i++){const x=Lh.boxX+i*Lh.boxP,y=PH+19;const on=i<S.hits;g.fillStyle=A.bevelLo;g.fillRect(x,y,7,7);g.fillStyle=on?A.bad:A.line;g.fillRect(x+1,y+1,5,5);if(on){g.fillStyle='#e07a62';g.fillRect(x+1,y+1,5,1);g.fillRect(x+1,y+1,1,5)}}"),
    ("TK.text(g,status.slice(0,Lh.maxChars),Lh.statusR,PH+6,statusCol,'right');",
     "TK.text(g,status.slice(0,Lh.maxChars),Lh.statusR,PH+20,statusCol,'right');"),
]

# ---- Leak Hunt (152x118 -> 152x130): the room and its air flow are untouched (152x92). The control
# strip grows 26 -> 38 rows: SMOKE / PATCH buttons 44x16 -> 46x28 with their names under the icons,
# AIR over a longer bar (36 -> 48 px, 7 px tall) on the right, the status / PUFFS line under it.
LEAK = [
    ("const PW=152,VH=92,HUD=26,PH=VH+HUD;", "const PW=152,VH=92,HUD=38,PH=VH+HUD;"),
    ("const BTN=[{id:'smoke',x:2,w:44,lab:'SMOKE'},{id:'patch',x:48,w:44,lab:'PATCH'}];const by=VH+8,bh=16;",
     "const BTN=[{id:'smoke',x:2,w:46,lab:'SMOKE'},{id:'patch',x:50,w:46,lab:'PATCH'}];const by=VH+6,bh=28;"),
    ("const ox=b.x+Math.floor(b.w/2),oy=by+8;",
     "const ox=b.x+Math.floor(b.w/2),oy=by+10;TK.text(g,b.lab,ox,by+18,on?A.hot:M[7],'center');"),
    ("    TK.text(g,'AIR',97,VH+5,A.chill);\n"
     "    const aw=36;g.fillStyle=A.bevelLo;g.fillRect(111,VH+4,aw+2,7);g.fillStyle=A.line;g.fillRect(112,VH+5,aw,5);\n"
     "    const fw=Math.round(aw*S.air);for(let i=0;i<fw;i++){put(g,112+i,VH+5,S.air<0.25?'#e07a62':A.ice);for(let j=1;j<5;j++)put(g,112+i,VH+5+j,j===4?(S.air<0.25?'#7a2f24':A.cold):(S.air<0.25?A.bad:A.chill))}\n"
     "    if(statusT>0||S.over)TK.text(g,status,PW-3,VH+15,statusCol,'right');else TK.text(g,'PUFFS '+S.puffs,PW-3,VH+15,M[6],'right');",
     "    TK.text(g,'AIR',100,VH+7,A.chill);\n"
     "    const aw=47;g.fillStyle=A.bevelLo;g.fillRect(100,VH+13,aw+2,9);g.fillStyle=A.line;g.fillRect(101,VH+14,aw,7);\n"
     "    const fw=Math.round(aw*S.air);for(let i=0;i<fw;i++){put(g,101+i,VH+14,S.air<0.25?'#e07a62':A.ice);for(let j=1;j<7;j++)put(g,101+i,VH+14+j,j===6?(S.air<0.25?'#7a2f24':A.cold):(S.air<0.25?A.bad:A.chill))}\n"
     "    if(statusT>0||S.over)TK.text(g,status,PW-3,VH+24,statusCol,'right');else TK.text(g,'PUFFS '+S.puffs,PW-3,VH+24,M[6],'right');"),
]

# ---- Beams: Jon's approved fit2 layout (BEAMS_FIT in tools/dev/minigame/diff.py), already 150x130 on
# the console plate (#111823, the border colour) at every deal. Unchanged.
BEAMS = [
    ("const W=150,H=150,CS=Math.floor(118/n),BW=n*CS,BX=Math.floor((W-BW)/2),BY=14+Math.floor((H-14-BW)/2);",
     "const W=150,H=130,CS=Math.floor(106/n),BW=n*CS,BX=20+Math.floor((130-BW)/2),BY=Math.floor((H-BW)/2);"),
    ("TK.text(g,'LIT',4,3,PAL.cold);", "TK.text(g,'LIT',4,4,PAL.cold);"),
    ("R(g,19+k*7,3,5,5,'#000');R(g,20+k*7,4,3,3,on?col:'#1f2935')", "R(g,5,12+k*7,5,5,'#000');R(g,6,13+k*7,3,3,on?col:'#1f2935')"),
    ("TK.text(g,'TURNS '+taps,W-4,3,PAL.cold,'right');", "TK.text(g,'TURNS',1,H-20,PAL.cold);TK.text(g,String(taps),10,H-13,PAL.cold,'center');"),
    ("if(won)TK.text(g,'ALL LIT',W>>1,H-7,PAL.hot,'center');", "if(won){TK.text(g,'ALL',10,48,PAL.hot,'center');TK.text(g,'LIT',10,55,PAL.hot,'center')}"),
]

# ---- Seismic Scan, Culture Dish, Tumble Dock: fit3's layouts (fit3_swaps.py) are already exactly
# 150x130 (Dock 152x130) at every deal and fill the area; carried over unchanged.
from fit3_swaps import CULTURE, DOCK, SEISMIC, TOMO as _TOMO3  # noqa: E402

SEISMIC = list(SEISMIC)
CULTURE = list(CULTURE)
DOCK = list(DOCK)

# ---- Core Scan: fit3's layout (HUD row 9, FOUND / SCAN LOST moved into it) was 112-130 tall by
# picture. Now always 130: the 18 px cell cap goes (cells take whatever the height and width allow,
# 5x5 cells 18 -> up to 21 px), and the left-over rows (fewer than n) sit evenly above and below the
# clue + grid block, on the console plate.
TOMO = [
    ("const W=150,CS=Math.min(18,Math.floor((W-6-CLW)/n)),GW=n*CS;\n"
     "    const GX=Math.floor((W-CLW-GW)/2)+CLW,GY=11+CLH,H=GY+GW+12;",
     "const W=150,CS=Math.min(Math.floor((W-6-CLW)/n),Math.floor((119-CLH)/n)),GW=n*CS;\n"
     "    const GX=Math.floor((W-CLW-GW)/2)+CLW,GY=9+CLH+((119-CLH-GW)>>1),H=130;"),
] + list(_TOMO3[1:])

FILES = {"wreck1.js": TORCH, "wreck3.js": LEAK, "beams2.js": BEAMS, "seismic2.js": SEISMIC,
         "culture2.js": CULTURE, "wreck2.js": DOCK, "tomo2.js": TOMO}
IDS = {"torch": "wreck1.js", "leak": "wreck3.js", "beams": "beams2.js", "seismic": "seismic2.js",
       "culture": "culture2.js", "dock": "wreck2.js", "corescan": "tomo2.js"}


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
