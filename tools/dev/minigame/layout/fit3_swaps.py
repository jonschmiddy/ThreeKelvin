"""Seismic Scan, Culture Dish, Tumble Dock and Core Scan re-laid out to the game area every game gets
(150 wide, 130 tall; a 152 canvas shows cropped a column each side). Same rules, same puzzle sizes:
each list is (old, new) string swaps on the prototype's own JS, every `old` asserted present.

    from fit3_swaps import SEISMIC, CULTURE, DOCK, TOMO, patched
    js = patched("seismic2.js", SEISMIC)
"""
from __future__ import annotations

from pathlib import Path

PROTO = Path(__file__).resolve().parent.parent / "proto"

# ---- Seismic Scan: the field keeps its cells and moves to the left; the two tools and the echo graph
# stack in a column on the right. The graph lies on its side: tiers run down (common at the top, rare
# at the bottom), spikes run right (longer = nearer, same 24 px as today); FAR / NEAR sit inside the screen (it ends at row 122). 150 x 130 at every depth.
SEISMIC = [
    ("const PAL=TK.PAL,G=S.G,CP=CPOF(G),FW=G*CP,W=150,FX=Math.floor((W-FW)/2),FY=15;\n"
     "    const GY=FY+FW+4,GH=30,GB=GY+GH-3,GT=GY+3,X0=FX+18,X1=FX+FW-4,H=GY+GH+8;",
     "const PAL=TK.PAL,G=S.G,CP=CPOF(G),FW=G*CP,W=150,H=130,FX=2,FY=(H-FW)>>1;\n"
     "    const CXL=FX+FW+4,CW=W-1-CXL,GY=29,GH=94,BL=CXL+5,BR=CXL+CW-3,T0=GY+9,T1=GY+75;"),
    ("    // the graph screen\n"
     "    R(b,FX-1,GY-1,FW+2,GH+1,'#000');R(b,FX,GY,FW,GH-1,PAL.void);\n"
     "    for(let t=0;t<5;t++){const lx=Math.round(X0+(t+.5)*(X1-X0)/5);for(let y=GT;y<=GB;y+=2)R(b,lx,y,1,1,PAL.panel);R(b,lx-3,GB+1,7,1,TC[t])}\n"
     "    R(b,X0-3,GT,1,GB-GT+1,PAL.line);R(b,X0-4,GT+1,3,1,PAL.line);\n"
     "    R(b,X0,GB,X1-X0+1,1,PAL.line);\n"
     "    TK.text(b,'NEAR',FX+2,GT,PAL.cold);TK.text(b,'FAR',FX+2,GB-4,PAL.line);\n"
     "    TK.text(b,'COMMON',X0,GY+GH+1,PAL.cold);\n"
     "    TK.text(b,'RARE',X1,GY+GH+1,PAL.cold,'right');",
     "    // the graph screen, on its side: tiers run down (common at the top), spikes run right (longer = nearer)\n"
     "    R(b,CXL-1,GY-1,CW+2,GH+1,'#000');R(b,CXL,GY,CW,GH-1,PAL.void);\n"
     "    for(let t=0;t<5;t++){const ly=Math.round(T0+(t+.5)*(T1-T0)/5);for(let x=BL+2;x<=BR;x+=2)R(b,x,ly,1,1,PAL.panel);R(b,BL-2,ly-3,1,7,TC[t])}\n"
     "    R(b,BL,T0,1,T1-T0+1,PAL.line);\n"
     "    R(b,BL,T1+9,BR-BL+1,1,PAL.line);R(b,BR-1,T1+8,1,3,PAL.line);\n"
     "    TK.text(b,'COMMON',CXL+2,GY+2,PAL.cold);TK.text(b,'RARE',CXL+2,T1+2,PAL.cold);\n"
     "    TK.text(b,'FAR',CXL+2,T1+12,PAL.line);TK.text(b,'NEAR',BR+1,T1+12,PAL.cold,'right');"),
    ("const gx=(t,slot)=>Math.round(X0+(t+.5)*(X1-X0)/5)+slot*5;\n"
     "    const gh=d=>Math.max(2,Math.round((GB-GT)*(1-d/(S.range+0.6))));",
     "const gx=(t,slot)=>Math.round(T0+(t+.5)*(T1-T0)/5)+slot*5;\n"
     "    const gh=d=>Math.max(2,Math.round(24*(1-d/(S.range+0.6))));"),
    ("const TW=Math.min(68,(FW>>1)-1),TB=[{id:'scan',x:FX-1,w:TW},{id:'dig',x:FX+FW+1-TW,w:TW}];",
     "const TB=[{id:'scan',x:CXL-1,y:1,w:CW+2},{id:'dig',x:CXL-1,y:15,w:CW+2}];"),
    ("live=tb.id==='scan'?scansLeft>0:digsLeft>0,y=1;", "live=tb.id==='scan'?scansLeft>0:digsLeft>0,y=tb.y;"),
    # charges: one row up to 4, two rows of 3 px pips past that (sensors take scans to 9)
    ("const n=tb.id==='scan'?S.scans:S.digs,l=tb.id==='scan'?scansLeft:digsLeft,sp=Math.min(5,Math.floor((tb.w-15)/n));\n"
     "        for(let i=0;i<n;i++){const x=tb.x+13+i*sp;R(g,x,y+3,sp-1,6,'#000');R(g,x,y+3,sp-2,5,i<l?(on?PAL.ember:PAL.cold):PAL.line);if(i<l&&on)R(g,x,y+3,sp-2,1,PAL.hot)}",
     "const n=tb.id==='scan'?S.scans:S.digs,l=tb.id==='scan'?scansLeft:digsLeft,two=n>4,m=two?Math.ceil(n/2):n,sp=Math.min(5,Math.floor((tb.w-15)/m)),ph=two?3:5;\n"
     "        for(let i=0;i<n;i++){const r=two&&i>=m?1:0,x=tb.x+13+(i-r*m)*sp,yy=y+(two?2+r*4:3);R(g,x,yy,sp-1,ph+1,'#000');R(g,x,yy,sp-2,ph,i<l?(on?PAL.ember:PAL.cold):PAL.line);if(i<l&&on)R(g,x,yy,sp-2,1,PAL.hot)}"),
    ("const y=GB-h+j;R(g,s.x-w,y,w*2+1,1,lit?hi:c);R(g,s.x-w-1,y,1,1,ol);R(g,s.x+w+1,y,1,1,ol);if(j<h*.6)R(g,s.x-w,y,1,1,hi)}",
     "const x=BL+h-j;R(g,x,s.x-w,1,w*2+1,lit?hi:c);R(g,x,s.x-w-1,1,1,ol);R(g,x,s.x+w+1,1,1,ol);if(j<h*.6)R(g,x,s.x-w,1,1,hi)}"),
    ("R(g,s.x,GB-h-1,1,1,lit?'#ffffff':ol);", "R(g,BL+h+1,s.x,1,1,lit?'#ffffff':ol);"),
    ("TK.text(g,'QUIET',(X0+X1)>>1,GT+9,PAL.cold,'center');", "TK.text(g,'QUIET',(BL+BR)>>1,((T0+T1)>>1)-2,PAL.cold,'center');"),
    ("TK.text(g,'#'+(k+1),FX+FW-2,GT,peek>=0?PAL.hot:PAL.chill,'right');", "TK.text(g,'#'+(k+1),CXL+CW-2,T1+2,peek>=0?PAL.hot:PAL.chill,'right');"),
    ("R(g,(W-w)>>1,FY+FW-12,w,9,PAL.bevelLo);TK.text(g,msg,W>>1,FY+FW-10,msgCol,'center')",
     "R(g,FX+((FW-w)>>1),FY+FW-12,w,9,PAL.bevelLo);TK.text(g,msg,FX+(FW>>1),FY+FW-10,msgCol,'center')"),
    ("if(!cs||q.y<GY-2||q.y>GB+2)return null;\n      let best=null,bd=4;for(const s of spikesOf(cs)){const d=Math.abs(s.x-q.x);",
     "if(!cs||q.x<CXL||q.y<GY||q.y>GY+GH)return null;\n      let best=null,bd=4;for(const s of spikesOf(cs)){const d=Math.abs(s.x-q.y);"),
    ("if(q.y<=13){for(const tb of TB)if(q.x>=tb.x&&q.x<tb.x+tb.w&&tool!==tb.id){",
     "if(q.x>=CXL-1&&q.y<=27){for(const tb of TB)if(q.y>=tb.y&&q.y<tb.y+12&&tool!==tb.id){"),
    ("return{x:t.x+(t.w>>1),y:6}", "return{x:t.x+(t.w>>1),y:t.y+6}"),
    ("Right is rarer. Tall is nearer.", "Lower is rarer. Longer is nearer."),
]

# ---- Culture Dish: the dish is untouched and moves down 4; the control bar goes. Seeds / growth rings
# sit in the bottom-left corner beside the dish, GROW / AGAIN in the bottom-right, KEEP bottom-left,
# the food count under TRY at the top-left. 150 x 130 at every depth.
CULTURE = [
    ("const W=150,H=140,CX=75,CY=60,AR=51,RO=57;", "const W=150,H=130,CX=75,CY=64,AR=51,RO=57;"),
    ("R(g,CX-(w>>1),104,w,9,PAL.bevelLo);TK.text(g,banner,CX,106,bannerCol,'center')",
     "R(g,CX-(w>>1),CY+44,w,9,PAL.bevelLo);TK.text(g,banner,CX,CY+46,bannerCol,'center')"),
    ("card(g,CX-48,95,96,", "card(g,CX-48,CY+35,96,"),
    ("    const y0=122;\n"
     "    R(g,0,y0-1,W,1,PAL.bevelLo);R(g,0,y0,W,H-y0,PAL.panel);R(g,0,y0,W,1,PAL.bevelHi);\n"
     "    const food=run?run.covered:0;\n"
     "    const fx=62;R(g,fx,y0+6,3,3,PAL.ice);R(g,fx+1,y0+7,2,2,PAL.chill);\n"
     "    TK.text(g,food+'/'+p.food.length,fx+6,y0+5,",
     "    const y0=112;\n"
     "    const food=run?run.covered:0;\n"
     "    const fx=3,fy=6;R(g,fx,fy+6,3,3,PAL.ice);R(g,fx+1,fy+7,2,2,PAL.chill);\n"
     "    TK.text(g,food+'/'+p.food.length,fx+6,fy+5,"),
    ("btn(104,43,'GROW',can,grow);", "btn(114,34,'GROW',can,grow);"),
    ("btn(3,40,'KEEP',true,finish);\n      btn(104,43,'AGAIN',true,again);",
     "btn(2,34,'KEEP',true,finish);\n      btn(114,34,'AGAIN',true,again);"),
]

# ---- Tumble Dock: the camera view loses 3 rows of empty space top and bottom (104 -> 98 tall, the spin
# centre 50 -> 47); the strip gets 2 more rows under the thrusters so they clear GIVE UP. The wreck, arrows,
# bracket and the strip's contents are untouched. 152 x 130.
DOCK = [
    ("const PW=152,VH=104,HUD=30,PH=VH+HUD;", "const PW=152,VH=98,HUD=32,PH=VH+HUD;"),
    ("const CX=PW/2,CY=50,PR=WR.hh+2;", "const CX=PW/2,CY=47,PR=WR.hh+2;"),
]

# ---- Core Scan: the GLASS / SLICE row tightens (11 -> 9 rows) and the FOUND / SCAN LOST line moves into
# it at the end (it took 12 rows under the grid). The grid then takes what height is left: cells are
# min(18, width fit, (119 - clue height) / n), so the tallest deal is 130.
TOMO = [
    ("const W=150,CS=Math.min(18,Math.floor((W-6-CLW)/n)),GW=n*CS;\n"
     "    const GX=Math.floor((W-CLW-GW)/2)+CLW,GY=11+CLH,H=GY+GW+12;",
     "const W=150,CS=Math.min(18,Math.floor((W-6-CLW)/n),Math.floor((119-CLH)/n)),GW=n*CS;\n"
     "    const GX=Math.floor((W-CLW-GW)/2)+CLW,GY=9+CLH,H=GY+GW+2;"),
    ("      TK.text(g,'GLASS',3,3,PAL.cold);\n"
     "      for(let k=0;k<c.lives;k++){const x=26+k*7,broke=k<mistakes;R(g,x,2,6,7,'#000');R(g,x+1,3,4,5,broke?'#140a0b':'#1f3a44');R(g,x+1,3,4,1,broke?'#140a0b':PAL.chill);if(broke){R(g,x+2,4,1,1,PAL.chill);R(g,x+3,5,1,2,PAL.chill)}}\n"
     "      if(forgive)TK.text(g,'+'+forgive,26+c.lives*7+2,3,PAL.good);\n"
     "      TK.text(g,'SLICE '+n+'X'+n,W-3,3,PAL.cold,'right');",
     "      if(!won&&!lost){\n"
     "      TK.text(g,'GLASS',3,2,PAL.cold);\n"
     "      for(let k=0;k<c.lives;k++){const x=26+k*7,broke=k<mistakes;R(g,x,1,6,7,'#000');R(g,x+1,2,4,5,broke?'#140a0b':'#1f3a44');R(g,x+1,2,4,1,broke?'#140a0b':PAL.chill);if(broke){R(g,x+2,3,1,1,PAL.chill);R(g,x+3,4,1,2,PAL.chill)}}\n"
     "      if(forgive)TK.text(g,'+'+forgive,26+c.lives*7+2,2,PAL.good);\n"
     "      TK.text(g,'SLICE '+n+'X'+n,W-3,2,PAL.cold,'right');}"),
    ("TK.text(g,'FOUND: '+P.name,W>>1,H-8,PAL.hot,'center')", "TK.text(g,'FOUND: '+P.name,W>>1,2,PAL.hot,'center')"),
    ("else if(lost)TK.text(g,'SCAN LOST',W>>1,H-8,PAL.bad,'center');", "else if(lost)TK.text(g,'SCAN LOST',W>>1,2,PAL.bad,'center');"),
]

FILES = {"seismic2.js": SEISMIC, "culture2.js": CULTURE, "wreck2.js": DOCK, "tomo2.js": TOMO}


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
