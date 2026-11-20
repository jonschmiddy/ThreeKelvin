"""fit4 (agent b): Pulsar Fold, Anomaly Count, Gravity Sling, Four Kelvin and Star Light re-laid out to
fill the 150x130 game area exactly at every depth and deal. Same rules, same puzzle sizes: each list is
(old, new) string swaps on the prototype's own JS, every `old` asserted present exactly once.

    from fit4_swaps_b import PULSAR, ANOMALY, SLING, FOURKELVIN, SPECTRUM, patched
    js = patched("pulsar2.js", PULSAR)
"""
from __future__ import annotations

from pathlib import Path

PROTO = Path(__file__).resolve().parent.parent / "proto"

# ---- Pulsar Fold: 144x124 -> 150x130. The phosphor glass grows 6 wide and 6 tall: the stacked rows
# (waterfall) 40 -> 46 rows, the raw trace 6 px longer; the 40-bin x 3 px plot is centred. The control
# deck moves down 6; the period strip is 4 px longer and sits 5 lower; LOCK moves up beside the PERIOD
# readout (it used to cover a row of the strip's 58 label, and would sit right on GIVE UP).
PULSAR = [
    ("const W=144,H=124;", "const W=150,H=130;"),
    ("const GX=12,GW=120;", "const GX=15,GW=120;"),
    ("const RAWY=12,RAWH=13,WFY=27,WFH=40,PRY=69,PRH=16;", "const RAWY=12,RAWH=13,WFY=27,WFH=46,PRY=75,PRH=16;"),
    ("const DX=18,DY=106,DR=15;", "const DX=18,DY=112,DR=15;"),
    ("const SX=40,SW=100,SY=101;", "const SX=40,SW=104,SY=112;"),
    ("const LB={x:98,y:113,w:43,h:10};", "const LB={x:104,y:96,w:43,h:10};"),
    ("b.fillRect(1,1,1,86);b.fillStyle=PAL.bevelLo;b.fillRect(1,87,W-2,1);b.fillRect(W-2,1,1,87);\n"
     "  b.fillStyle='#06110b';b.fillRect(3,3,W-6,83);",
     "b.fillRect(1,1,1,92);b.fillStyle=PAL.bevelLo;b.fillRect(1,93,W-2,1);b.fillRect(W-2,1,1,93);\n"
     "  b.fillStyle='#06110b';b.fillRect(3,3,W-6,89);"),
    ("for(const[x,y]of[[4,90],[W-5,90],", "for(const[x,y]of[[4,96],[W-5,96],"),
    ("TK.text(b,'PERIOD',SX,92,PAL.cold);", "TK.text(b,'PERIOD',SX,98,PAL.cold);"),
    ("const n=Math.min(g0.sig.length,272);", "const n=Math.min(g0.sig.length,284);"),
    ("text2(fmt(Pf),SX+28,90,", "text2(fmt(Pf),SX+28,96,"),
    ("if(q.y<88)return;started=true;", "if(q.y<94)return;started=true;"),
    ("!finished&&q.y>=88&&(q.x<37", "!finished&&q.y>=94&&(q.x<37"),
    ("if(q.y<88)return;e.preventDefault();setP(", "if(q.y<94)return;e.preventDefault();setP("),
]

# ---- Anomaly Count: 144x124 -> 150x130. The lens grows to fill the height (radius 52 -> 55, centre
# 72,69 -> 75,72); the dish's spacing scales with it (x 55/52) and every critter is drawn bigger
# (scale 1.6 -> 1.7, sprite box 35 -> 37); mark rings and the tap reach grow 1 px. The corners outside
# the round lens are the shared border colour (#111823) with the lens's bevelled rim, as before.
ANOMALY = [
    ("const W=144,H=124,CX=72,CY=69,LENS=52;", "const W=150,H=130,CX=75,CY=72,LENS=55,PS=LENS/52;"),
    ("const K=1.6;", "const K=1.7;"),
    ("const SP=35,SH=17;", "const SP=37,SH=18;"),
    ("({s,x:pz.pos[i][0],y:pz.pos[i][1],", "({s,x:pz.pos[i][0]*PS,y:pz.pos[i][1]*PS,"),
    ("c.x+=Math.sin(a)*3.2*dt;c.y-=Math.cos(a)*3.2*dt;", "c.x+=Math.sin(a)*3.2*PS*dt;c.y-=Math.cos(a)*3.2*PS*dt;"),
    ("if(Math.hypot(c.x,c.y)>DISH_R){c.x*=DISH_R/Math.hypot(c.x,c.y);", "if(Math.hypot(c.x,c.y)>DISH_R*PS){c.x*=DISH_R*PS/Math.hypot(c.x,c.y);"),
    ("ringPx(g,CX+c.x,CY+c.y,12.5,PAL.ember);ringPx(g,CX+c.x,CY+c.y,13.5,PAL.ember);ringPx(g,CX+c.x,CY+c.y,14.5,",
     "ringPx(g,CX+c.x,CY+c.y,13.5,PAL.ember);ringPx(g,CX+c.x,CY+c.y,14.5,PAL.ember);ringPx(g,CX+c.x,CY+c.y,15.5,"),
    ("if(f.bad){ringPx(g,x,y,13.5,", "if(f.bad){ringPx(g,x,y,14.5,"),
    ("let best=-1,bd=13;", "let best=-1,bd=14;"),
]

# ---- Gravity Sling: 144x124 -> 150x130. The nav plot keeps its 1000x640 field and draws it at 0.150
# px per unit, not 0.144: 144x92 -> 150x96, every mass, ring and path 4% bigger. The deck below is 2
# rows taller (32 -> 34) and its parts sit 1 row lower; the sling and fork move right 6 with the edge.
SLING = [
    ("const W=144,H=124,FY=92,SC=W/FW; // field is 144 x 92 art px", "const W=150,H=130,FY=96,SC=W/FW; // field is 150 x 96 art px"),
    ("const DX=15,DY=108,DRAD=13;", "const DX=15,DY=113,DRAD=13;"),
    ("const FKX=136,RY=109,PULLMAX=72;", "const FKX=142,RY=114,PULLMAX=72;"),
    ("TK.text(d,'AIM',33,4,PAL.cold);", "TK.text(d,'AIM',33,5,PAL.cold);"),
    ("  line(d,FKX+3,30,FKX+3,19,PAL.bevelLo);line(d,FKX+4,30,FKX+4,19,PAL.cold);\n"
     "  line(d,FKX+3,19,FKX,9,PAL.cold);line(d,FKX+4,19,FKX+1,9,PAL.chill);\n"
     "  line(d,FKX+3,19,FKX,26,PAL.cold);line(d,FKX+4,19,FKX+1,26,PAL.bevelLo);\n"
     "  void fork;for(let x=128-PULLMAX;x<124;x+=3)dot(d,x,RY-FY,PAL.line);\n"
     "  for(let k=0;k<=9;k++){const x=Math.round(128-14-k*(PULLMAX-14)/9);dot(d,x,29,k%5===0?PAL.chill:PAL.line);if(k%5===0)dot(d,x,28,PAL.chill)}",
     "  line(d,FKX+3,31,FKX+3,20,PAL.bevelLo);line(d,FKX+4,31,FKX+4,20,PAL.cold);\n"
     "  line(d,FKX+3,20,FKX,10,PAL.cold);line(d,FKX+4,20,FKX+1,10,PAL.chill);\n"
     "  line(d,FKX+3,20,FKX,27,PAL.cold);line(d,FKX+4,20,FKX+1,27,PAL.bevelLo);\n"
     "  void fork;for(let x=134-PULLMAX;x<130;x+=3)dot(d,x,RY-FY,PAL.line);\n"
     "  for(let k=0;k<=9;k++){const x=Math.round(134-14-k*(PULLMAX-14)/9);dot(d,x,30,k%5===0?PAL.chill:PAL.line);if(k%5===0)dot(d,x,29,PAL.chill)}"),
    ("Math.abs(ang),33,FY+12,PAL.hot);", "Math.abs(ang),33,FY+13,PAL.hot);"),
    ("const PX=Math.round(128-off),", "const PX=Math.round(134-off),"),
    ("line(g,FKX,FY+9,PX-1,PY-2,band);line(g,FKX,FY+26,PX-1,PY+2,band);", "line(g,FKX,FY+10,PX-1,PY-2,band);line(g,FKX,FY+27,PX-1,PY+2,band);"),
    ("const lx=Math.round(128-offOf(lastPow));g.fillStyle=PAL.t2;g.fillRect(lx-1,FY+26,3,1);dot(g,lx,FY+25,PAL.t2)",
     "const lx=Math.round(134-offOf(lastPow));g.fillStyle=PAL.t2;g.fillRect(lx-1,FY+27,3,1);dot(g,lx,FY+26,PAL.t2)"),
    ("W-14,FY+4,shownP?PAL.hot:PAL.cold,'right');", "W-14,FY+5,shownP?PAL.hot:PAL.cold,'right');"),
]

# ---- Four Kelvin: 140x112 -> 150x130. The belt keeps its 82 rows (it is the world, 1 px a unit) and
# shows 10 more columns ahead; the field is still dealt for a 140 view, so deals are unchanged. The top
# bar grows 10 -> 12 rows; the bottom panel 20 -> 36: a 2-row progress bar and touch buttons 13 -> 26
# tall (turns 20 -> 22 wide, THRUST 42 -> 46), ENERGY with them.
FOURKELVIN = [
    ("const W=140,H=112,VY=10,BH=82,SHIPX=46,DT=1/30;   // view: HUD 0-9, belt rows 10-91, bar 93-95, buttons 96-111",
     "const W=150,H=130,GENW=140,VY=12,BH=82,SHIPX=46,DT=1/30;   // view: HUD 0-11, belt rows 12-93, bar 96-97, buttons 100-128"),
    ("len=target+W+40;", "len=target+GENW+40;"),
    ("const BTN={a:[2,97,20,13],d:[25,97,20,13],w:[W-44,97,42,13]};", "const BTN={a:[2,101,22,26],d:[27,101,22,26],w:[W-48,101,46,26]};"),
    ("g.fillStyle=P.panel;g.fillRect(0,0,W,9);g.fillStyle=P.bevelHi;g.fillRect(0,9,W,1);",
     "g.fillStyle=P.panel;g.fillRect(0,0,W,11);g.fillStyle=P.bevelHi;g.fillRect(0,11,W,1);"),
    ("TK.text(g,'HULL',2,2,fresh?P.hot:P.cold);hullBar(19,1);", "TK.text(g,'HULL',2,3,fresh?P.hot:P.cold);hullBar(19,2);"),
    (".padStart(4,'0')+'M',W-2,2,P.hot,'right');", ".padStart(4,'0')+'M',W-2,3,P.hot,'right');"),
    ("g.fillStyle=P.panel;g.fillRect(0,92,W,H-92);g.fillStyle=P.bevelHi;g.fillRect(0,92,W,1);",
     "g.fillStyle=P.panel;g.fillRect(0,94,W,H-94);g.fillStyle=P.bevelHi;g.fillRect(0,94,W,1);"),
    ("g.fillStyle=P.line;g.fillRect(2,94,bw,1);g.fillStyle=P.chill;g.fillRect(2,94,Math.round(bw*f),1);g.fillStyle=P.hot;g.fillRect(2+Math.round(bw*f),94,1,1);",
     "g.fillStyle=P.line;g.fillRect(2,96,bw,2);g.fillStyle=P.chill;g.fillRect(2,96,Math.round(bw*f),2);g.fillStyle=P.hot;g.fillRect(2+Math.round(bw*f),96,1,2);"),
    ("const ex=50,ew=W-44-6-ex;g.fillStyle=P.bevelLo;g.fillRect(ex,96,ew,15);g.fillStyle=P.void;g.fillRect(ex+1,97,ew-2,13);\n"
     "      TK.text(g,'ENERGY',ex+Math.floor(ew/2),98,P.cold,'center');\n"
     "      for(let i=0;i<4;i++){g.fillStyle=P.ember;g.fillRect(ex+Math.floor(ew/2)-8+i*4,105,3,3)}",
     "const ex=52,ew=W-48-3-ex;g.fillStyle=P.bevelLo;g.fillRect(ex,100,ew,28);g.fillStyle=P.void;g.fillRect(ex+1,101,ew-2,26);\n"
     "      TK.text(g,'ENERGY',ex+Math.floor(ew/2),106,P.cold,'center');\n"
     "      for(let i=0;i<4;i++){g.fillStyle=P.ember;g.fillRect(ex+Math.floor(ew/2)-8+i*4,115,3,3)}"),
]

# ---- Star Light: Jon's approved fit2 (header 40 rows: STAR / YOU strips, thin meter with MATCH! on
# it, dividers gone when full; diff.py's SPECTRUM_FIT) taken to every tube count. The tube rows share
# the 90 rows under the header: row pitch floor(91/T) (3 tubes 30, 4: 22, 5: 18, 6: 15, 7: 13), the
# spare row or two split above and below. Each row's line strip and its tube grow with the pitch
# (strip 8 -> up to 14 rows, tube 9 -> up to 15), centred in the row; at 7 tubes it is fit2 exactly.
SPECTRUM = [
    ("ROW=13,TY=50,H=TY+T*ROW+12;",
     "ROW=Math.floor(91/T),TY=40+((91-T*ROW)>>1),H=130,SH=Math.min(ROW-5,14),OY=(ROW-SH-5)>>1;"),
    ("strip(4,10);strip(22,10);", "strip(2,10);strip(17,10);"),
    ("TK.text(b,'STAR',2,7,PAL.chill);TK.text(b,'YOU',2,25,PAL.chill);", "TK.text(b,'STAR',2,5,PAL.chill);TK.text(b,'YOU',2,20,PAL.chill);"),
    ("for(let i=0;i<T;i++){const y=TY+i*ROW;strip(y+2,8)}\n  R(b,0,TY-3,W,1,PAL.bevelLo);R(b,0,TY-2,W,1,PAL.bevelHi);",
     "for(let i=0;i<T;i++){const y=TY+i*ROW+OY;strip(y+2,SH)}\n  R(b,0,37,W,1,PAL.bevelLo);R(b,0,38,W,1,PAL.bevelHi);"),
    ("  function tube(i,x,y,now){\n"
     "    const lit=(on>>i)&1,gc=gasOf[i];\n"
     "    // glow halo\n"
     "    if(lit){const fl=.35+.15*Math.sin(now/90+i*2);for(let xx=x-1;xx<=x+17;xx++){if(bay(xx,y-1)<fl)R(g,xx,y-1,1,1,mix(gc,'#000000',.4));if(bay(xx,y+9)<fl)R(g,xx,y+9,1,1,mix(gc,'#000000',.4))}}\n"
     "    // metal caps\n"
     "    R(g,x,y+1,3,7,'#000');R(g,x+1,y+2,2,5,PAL.cold);R(g,x+1,y+2,1,5,PAL.chill);\n"
     "    R(g,x+15,y+1,3,7,'#000');R(g,x+15,y+2,2,5,PAL.cold);R(g,x+15,y+2,1,1,PAL.chill);\n"
     "    // glass body\n"
     "    R(g,x+3,y,12,1,'#000');R(g,x+3,y+8,12,1,'#000');\n"
     "    if(lit){\n"
     "      for(let xx=0;xx<12;xx++)for(let j=1;j<8;j++){const core=j>=3&&j<=5,f=bay(x+3+xx+((now/70)|0),y+j);\n"
     "        R(g,x+3+xx,y+j,1,1,core?(f<.5?'#ffffff':mix(gc,'#ffffff',.55)):(f<.6?gc:mix(gc,'#000000',.3)))}\n"
     "      R(g,x+4,y+1,10,1,mix(gc,'#ffffff',.7));\n"
     "    }else{\n"
     "      R(g,x+3,y+1,12,7,'#151c26');R(g,x+4,y+1,10,1,'#3d4d61');R(g,x+4,y+6,10,1,mix(gc,'#000000',.7));\n"
     "      R(g,x+6,y+4,6,1,'#0b0f15');\n"
     "    }\n"
     "    if(broken.has(i)){R(g,x+3,y+1,12,7,'#0b0f15');R(g,x+6,y+1,1,2,PAL.chill);R(g,x+7,y+3,1,2,PAL.chill);R(g,x+8,y+5,1,1,PAL.chill);R(g,x+9,y+6,2,1,PAL.chill)}\n"
     "    if(locked.has(i)){R(g,x+1,y,1,1,PAL.warn);R(g,x+16,y,1,1,PAL.warn);R(g,x+1,y+8,1,1,PAL.warn);R(g,x+16,y+8,1,1,PAL.warn)}\n"
     "  }",
     # the same tube, TH rows tall (9 at fit2's 13 px rows: identical there)
     "  function tube(i,x,y,now){\n"
     "    const lit=(on>>i)&1,gc=gasOf[i],th=SH+1,cm=(th-1)/2,cr=(th-2)*1.5/7,cy=(th-9)>>1;\n"
     "    // glow halo\n"
     "    if(lit){const fl=.35+.15*Math.sin(now/90+i*2);for(let xx=x-1;xx<=x+17;xx++){if(bay(xx,y-1)<fl)R(g,xx,y-1,1,1,mix(gc,'#000000',.4));if(bay(xx,y+th)<fl)R(g,xx,y+th,1,1,mix(gc,'#000000',.4))}}\n"
     "    // metal caps\n"
     "    R(g,x,y+1,3,th-2,'#000');R(g,x+1,y+2,2,th-4,PAL.cold);R(g,x+1,y+2,1,th-4,PAL.chill);\n"
     "    R(g,x+15,y+1,3,th-2,'#000');R(g,x+15,y+2,2,th-4,PAL.cold);R(g,x+15,y+2,1,1,PAL.chill);\n"
     "    // glass body\n"
     "    R(g,x+3,y,12,1,'#000');R(g,x+3,y+th-1,12,1,'#000');\n"
     "    if(lit){\n"
     "      for(let xx=0;xx<12;xx++)for(let j=1;j<th-1;j++){const core=Math.abs(j-cm)<=cr,f=bay(x+3+xx+((now/70)|0),y+j);\n"
     "        R(g,x+3+xx,y+j,1,1,core?(f<.5?'#ffffff':mix(gc,'#ffffff',.55)):(f<.6?gc:mix(gc,'#000000',.3)))}\n"
     "      R(g,x+4,y+1,10,1,mix(gc,'#ffffff',.7));\n"
     "    }else{\n"
     "      R(g,x+3,y+1,12,th-2,'#151c26');R(g,x+4,y+1,10,1,'#3d4d61');R(g,x+4,y+th-3,10,1,mix(gc,'#000000',.7));\n"
     "      R(g,x+6,y+(th>>1),6,1,'#0b0f15');\n"
     "    }\n"
     "    if(broken.has(i)){R(g,x+3,y+1,12,th-2,'#0b0f15');R(g,x+6,y+cy+1,1,2,PAL.chill);R(g,x+7,y+cy+3,1,2,PAL.chill);R(g,x+8,y+cy+5,1,1,PAL.chill);R(g,x+9,y+cy+6,2,1,PAL.chill)}\n"
     "    if(locked.has(i)){R(g,x+1,y,1,1,PAL.warn);R(g,x+16,y,1,1,PAL.warn);R(g,x+1,y+th-1,1,1,PAL.warn);R(g,x+16,y+th-1,1,1,PAL.warn)}\n"
     "  }"),
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
    # the tube rows: tube, lines and burnt stubs follow the row's strip
    ("const y=TY+i*ROW,lit=(on>>i)&1;", "const y=TY+i*ROW+OY,lit=(on>>i)&1;"),
    ("if(broken.has(i)){R(g,x,y+4,2,4,'#1f2935');continue}drawLine(x,y+2,8,binCol(bn),lit?.5:0,false);if(!lit)R(g,x,y+2,2,8,mix(",
     "if(broken.has(i)){R(g,x,y+2+(SH>>2),2,SH>>1,'#1f2935');continue}drawLine(x,y+2,SH,binCol(bn),lit?.5:0,false);if(!lit)R(g,x,y+2,2,SH,mix("),
    ("const lit=(on>>i)&1,y=TY+i*ROW+2;", "const lit=(on>>i)&1,y=TY+i*ROW+OY+2;"),
    ("_row:i=>({x:60,y:TY+i*ROW+6})", "_row:i=>({x:60,y:TY+i*ROW+(ROW>>1)})"),
]

FILES = {"pulsar2.js": PULSAR, "anomaly2.js": ANOMALY, "sling2.js": SLING, "fourkelvin.js": FOURKELVIN, "spectrum2.js": SPECTRUM}


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
