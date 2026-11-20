"""The UI kit (kit.js) on agent C's games, on top of their fit4 layouts (fit4_swaps_c.py): Cutting Torch,
Leak Hunt, Beams, Seismic Scan, Culture Dish, Tumble Dock, Core Scan. Each KIT_<ID> list is applied after
the game's fit4 swaps. An entry is (old, new), `old` asserted present exactly once in the fit4 text, or
(Cut(start, end), new): the one span from `start` through `end` (each marker unique) is replaced.
The game stays exactly 150 x 130 (152 x 130 for the wreck games: the kit is drawn 1 px in, so the glass's
middle 150 columns carry it).

    from kit_swaps_c import kit_patched, fit4_js
    js = kit_patched("seismic")                 # kit.js + seismic2.js with fit4 and kit swaps (rings B)
    js = kit_patched("seismic", rings="A")      # the same with today's dotted echo rings
"""
from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

import fit4_swaps_c as F4

HERE = Path(__file__).parent
KIT_JS = (HERE / "kit.js").read_text(encoding="utf-8")


@dataclass(frozen=True)
class Cut:
    start: str
    end: str


# New 9x9 button icons in the kit's style (one colour, 1 px strokes), for these games' buttons:
# scan / dig (Seismic's tools), left / right (Tumble Dock's drift thrusters).
KIT_ICONS_C = r"""
(function(){const I=TK.KIT.ICONS;
I.scan=I.scan||['..#####..','.#.....#.','#..###..#','#.#...#.#','#.#.#.#.#','#.#...#.#','#..###..#','.#.....#.','..#####..'];
I.dig=I.dig||['.#######.','.#######.','...###...','...###...','...###...','....#....','....#....','....#....','.........'];
I.left=I.left||['.........','...#.....','..#......','.#.......','#########','.#.......','..#......','...#.....','.........'];
I.right=I.right||['.........','.....#...','......#..','.......#.','#########','.......#.','......#..','.....#...','.........'];
})();
"""

# ---- Cutting Torch (152 x 130): the camera (152 x 100) stays where it is; the header takes its top 10 rows
# (ARM CAM + the REC lamp move into it) and the deck its rows 98-99 and the old HUD strip: status line
# (ZAP! LIVE LINE ... CUT FREE), then the control row with GAS (kit meter, 27 segments) and HITS (kit meter,
# bad, 2 segments a hit) side by side. Tell card at the kit's spot. Taps on the header or deck do not cut.
KIT_TORCH = [
    ("for(const[x,y,dx,dy]of[[1,1,1,1],[PW-2,1,-1,1],[1,PH-2,1,-1],[PW-2,PH-2,-1,-1]])",
     "for(const[x,y,dx,dy]of[[1,11,1,1],[PW-2,11,-1,1],[1,96,1,-1],[PW-2,96,-1,-1]])"),
    (Cut("    g.fillStyle=A.bevelLo;g.fillRect(3,3,36,7);TK.text(g,'ARM CAM',4,4,M[6]);",
         "if((statusT>0||S.over)&&status)TK.text(g,status.slice(0,Lh.maxChars),Lh.statusR,PH+20,statusCol,'right');"),
     "    // the kit: header over the camera's top rows; deck (status line, GAS + HITS meters) over its foot\n"
     "    {const K=TK.KIT;g.save();g.translate(1,0);\n"
     "      const hd=K.header(g,'ARM CAM',null);if(Math.floor(t*2)%2)put(g,hd.lx,4,A.bad);\n"
     "      if(!S.over&&S.pts.length<=1&&!path.length)K.tell(g,'CUT OUT THE CRATE.',['click'],t);\n"
     "      K.deck(g,true);\n"
     "      const gl=clamp(1-S.used/P.gas),low=gl<0.2,hx=K.W-K.GUT-25,cy=K.ROW.CTRL.cy;\n"
     "      TK.text(g,'GAS',K.GUT,cy-6,low?A.bad:K.LABEL);K.meter(g,K.GUT,cy,hx-4-K.GUT,gl,low?'bad':'neutral');\n"
     "      TK.text(g,'HITS',hx,cy-6,S.hits?A.bad:K.LABEL);K.meter(g,hx,cy,25,S.hits/HITS_MAX,'bad');\n"
     "      if((statusT>0||S.over)&&status)K.status(g,status,statusCol===A.bad?'bad':statusCol===A.good?'good':'neutral',true);\n"
     "      g.restore()}"),
    ("const p=toWorld(e);if(p[1]>H)return;",
     "const p=toWorld(e);if(p[1]>=2*TK.KIT.deckY(true)||p[1]<2*TK.KIT.ROW.PLAY.y)return;"),
]

# ---- Leak Hunt (152 x 130): the room (152 x 92) stays; the header takes its ceiling rows (DRONE 2 moves in,
# PUFFS and PATCHES left are its counters); its floor grating runs on to row 97; deck from 98: status line
# (SEALED / STILL LEAKING / AIR GONE), control row with AIR (kit meter) and SMOKE / PATCH as 19-tall kit
# buttons (icon over label), PATCH right over GIVE UP. The chosen mode is the amber (active) button.
KIT_LEAK = [
    ("const st=document.createElement('canvas');st.width=PW;st.height=VH;",
     "const st=document.createElement('canvas');st.width=PW;st.height=98;"),
    ("  for(let y=0;y<VH;y++)for(let x=0;x<PW;x++){\n    let c;", "  for(let y=0;y<98;y++)for(let x=0;x<PW;x++){\n    let c;"),
    ("const BTN=[{id:'smoke',x:2,w:46,lab:'SMOKE'},{id:'patch',x:50,w:46,lab:'PATCH'}];const by=VH+6,bh=28;",
     "const KB=[{id:'smoke',x:1+TK.KIT.W-TK.KIT.GUT-33-TK.KIT.GAP-33,lab:'SMOKE'},{id:'patch',x:1+TK.KIT.W-TK.KIT.GUT-33,lab:'PATCH'}]\n"
     "    .map(b=>Object.assign(b,{y:TK.KIT.BTN.YL,w:33,h:TK.KIT.BTN.HL})); // canvas x (the kit is drawn 1 px in)"),
    ("if(y>=VH){for(const b of BTN)if(x>=b.x&&x<b.x+b.w&&y>=by-1&&y<=by+bh){mode=b.id}return}\n    if(y<5||y>=78)return;",
     "if(y>=TK.KIT.deckY(true)){for(const b of KB)if(x>=b.x&&x<b.x+b.w&&y>=b.y&&y<b.y+b.h&&!(b.id==='patch'&&S.used>=P.patches)){mode=b.id}return}\n"
     "    if(y<TK.KIT.ROW.PLAY.y||y>=78)return;"),
    ("for(const[x,y,dx,dy]of[[1,1,1,1],[PW-2,1,-1,1],[1,VH-2,1,-1],[PW-2,VH-2,-1,-1]])",
     "for(const[x,y,dx,dy]of[[1,11,1,1],[PW-2,11,-1,1],[1,96,1,-1],[PW-2,96,-1,-1]])"),
    (Cut("    TK.text(g,'DRONE 2',4,VH-8,M[6]);",
         "else TK.text(g,'PUFFS '+S.puffs,PW-3,VH+24,M[6],'right');"),
     "    if(mode==='patch'&&!S.over){for(let x=2;x<PW-2;x++){if(bt(x,0)<0.5){put(g,x,11,A.ember);put(g,x,96,A.ember)}}}\n"
     "    // the kit: header (camera label, counters); deck: status line, AIR meter, SMOKE / PATCH\n"
     "    {const K=TK.KIT,cy=K.ROW.CTRL.cy,left=P.patches-S.used,low=S.air<0.25;g.save();g.translate(1,0);\n"
     "      K.header(g,'DRONE 2',[['PUFFS',S.puffs],['PATCHES',left,left?null:'bad']]);\n"
     "      if(!S.puffs&&!S.over)K.tell(g,'PATCH THE LEAK.',['click'],t);\n"
     "      K.deck(g,true);\n"
     "      TK.text(g,'AIR',K.GUT,cy-6,low?A.bad:K.LABEL);K.meter(g,K.GUT,cy,KB[0].x-1-K.GAP-K.GUT,S.air,low?'bad':'neutral');\n"
     "      for(const b of KB){const on=mode===b.id,dis=S.over||(b.id==='patch'&&!left);K.button(g,b.x-1,b.y,b.w,b.h,b.lab,dis?'disabled':on?'active':'normal',b.id)}\n"
     "      if(statusT>0||S.over)K.status(g,status,statusCol===A.good?'good':statusCol===A.bad?'bad':'neutral',true);\n"
     "      g.restore()}"),
    ("    _sim:S,_P:P,\n", "    _sim:S,_P:P,_btn:id=>{const b=KB.find(b=>b.id===id);return{x:b.x+(b.w>>1),y:b.y+(b.h>>1)}},\n"),
]

# ---- Beams (150 x 130): the header takes LIT (its sensor lamps in the free span) and TURNS; ALL LIT goes to
# the status line (deck 121, no controls); the table is centred in rows 10-120 with its emitter. Cells keep
# their fit4 size, except when the emitter sits above or below the table: then the table and emitter must
# fit 111 rows, so cells are floor(96 / n) (5x5 19 px, was 21; 6x6 16, was 17; 7x7 13, was 15). Corner
# screws off the border.
KIT_BEAMS = [
    ("const W=150,H=130,CS=Math.floor(106/n),BW=n*CS,BX=20+Math.floor((130-BW)/2),BY=Math.floor((H-BW)/2);",
     "const KIT=TK.KIT,W=150,H=130,PY0=KIT.ROW.PLAY.y,PH=KIT.deckY(false)-PY0,sd=P.src.d,vert=sd===0||sd===2;\n"
     "  const CS=Math.min(Math.floor(106/n),Math.floor((vert?PH-15:PH-6)/n)),BW=n*CS; // the table + its frame (+ the emitter) in the play rows\n"
     "  const EL=sd===1?12:3,ER=sd===3?12:3,ET=sd===2?12:3,EB=sd===0?12:3,BX=EL+((W-EL-ER-BW)>>1),BY=PY0+ET+((PH-ET-EB-BW)>>1);"),
    ("for(const[x,y]of[[3,3],[W-5,3],[3,H-5],[W-5,H-5]]){R(b,x,y,2,2,PAL.bevelHi);R(b,x+1,y+1,1,1,PAL.bevelLo)}",
     "KIT.deck(b,false);"),
    (Cut("    TK.text(g,'LIT',4,4,PAL.cold);", "if(won){TK.text(g,'ALL',10,48,PAL.hot,'center');TK.text(g,'LIT',10,55,PAL.hot,'center')}"),
     "    const hd=KIT.header(g,'LIT',[['TURNS',taps]]);\n"
     "    P.sensors.forEach((i,k)=>{const on=isLit(board[i],tr.hits.get(i)),col=SCOL[board[i].c];R(g,hd.lx+k*7,2,5,5,'#000');R(g,hd.lx+1+k*7,3,3,3,on?col:'#1f2935')});\n"
     "    if(!taps&&!over&&now-t0<4500)KIT.tell(g,'LIGHT EVERY SENSOR.',['click'],(now-t0)/1000);\n"
     "    if(won)KIT.status(g,'ALL LIT','good',false);"),
]

# ---- Seismic Scan (150 x 130): full bleed: the field sits under the header (rows 10-119 at G=10, its frame
# where it fits), border texture off (solid #111823). Header: FINDS dug / total left, SCANS and DIGS left as
# counters (they were pips on the tool tabs). SCAN / DIG become kit buttons (icon + label, 33 x 13, active =
# the tool in hand, disabled = none left) at the top of the right column: the field takes the whole play
# height, so there is no room for a control row under it. The echo graph stays on its side under them,
# 77 rows (was 94): tiers 11 rows apart (were 13). Status line (deck 121): RARE / CLOSE / EMPTY / ALL DUG,
# QUIET. Tell card at the kit's spot.
KIT_SEISMIC = [
    ("const PAL=TK.PAL,G=S.G,CP=CPOF(G),FW=G*CP,W=150,H=130,FX=2,FY=(H-FW)>>1;\n"
     "    const CXL=FX+FW+4,CW=W-1-CXL,GY=29,GH=94,BL=CXL+5,BR=CXL+CW-3,T0=GY+9,T1=GY+75;",
     "const KIT=TK.KIT,PAL=TK.PAL,G=S.G,CP=CPOF(G),FW=G*CP,W=150,H=130,PY0=KIT.ROW.PLAY.y,PH=KIT.deckY(false)-PY0,FX=1+((110-FW)>>1),FY=PY0+((PH-FW)>>1);\n"
     "    const CXL=KIT.W-KIT.GUT-33,CW=33,GY=44,GH=78,BL=CXL+5,BR=CXL+CW-3,T0=GY+8,T1=T0+55; // right column: tools, then the graph to row 120"),
    ("    for(let y=0;y<H;y+=2)for(let x=(y>>1)&1;x<W;x+=4)if(bay(x,y)<.2)R(b,x,y,1,1,PAL.line);\n", ""),
    ("    R(b,BL,T1+9,BR-BL+1,1,PAL.line);R(b,BR-1,T1+8,1,3,PAL.line);\n"
     "    TK.text(b,'COMMON',CXL+2,GY+2,PAL.cold);TK.text(b,'RARE',CXL+2,T1+2,PAL.cold);\n"
     "    TK.text(b,'FAR',CXL+2,T1+12,PAL.line);TK.text(b,'NEAR',BR+1,T1+12,PAL.cold,'right');",
     "    R(b,BL,T1+7,BR-BL+1,1,PAL.line);R(b,BR-1,T1+6,1,3,PAL.line);\n"
     "    TK.text(b,'COMMON',CXL+2,GY+2,PAL.cold);TK.text(b,'RARE',CXL+2,T1+1,PAL.cold);\n"
     "    TK.text(b,'FAR',CXL+2,T1+9,PAL.line);TK.text(b,'NEAR',BR+1,T1+9,PAL.cold,'right');\n"
     "    KIT.deck(b,false);"),
    ("const TB=[{id:'scan',x:CXL-1,y:1,w:CW+2},{id:'dig',x:CXL-1,y:15,w:CW+2}];",
     "const TB=[{id:'scan',x:CXL,y:12,w:CW},{id:'dig',x:CXL,y:12+KIT.BTN.H+KIT.GAP,w:CW}];"),
    (Cut("      for(const tb of TB){\n        const on=tool===tb.id,live=", "if(i<l&&on)R(g,x,yy,sp-2,1,PAL.hot)}\n      }"),
     "      const got=S.deps.filter(q=>q.got).length;\n"
     "      KIT.header(g,{label:'FINDS',value:got+'/'+S.deps.length,vkind:got===S.deps.length?'good':null},[['SCANS',scansLeft],['DIGS',digsLeft,digsLeft?null:'bad']]);\n"
     "      for(const tb of TB){const on=tool===tb.id,live=tb.id==='scan'?scansLeft>0:digsLeft>0;\n"
     "        KIT.button(g,tb.x,tb.y,tb.w,KIT.BTN.H,tb.id==='scan'?'SCAN':'DIG',!live?'disabled':on?'active':'normal',tb.id)}"),
    ("      g.drawImage(bgc,0,0);\n      drawTools();", "      g.drawImage(bgc,0,0);\n      drawTools();let quiet=false;"),
    ("if(!sp.length&&(!live||sweep.end))TK.text(g,'QUIET',(BL+BR)>>1,((T0+T1)>>1)-2,PAL.cold,'center');",
     "if(!sp.length&&(!live||sweep.end))quiet=true;"),
    ("      if(!touched&&!scans.length&&now-t00<6000)card(g,FX+4,FY+(FW>>1)-9,FW-8,'SCAN, THEN DIG.',(now-t00)/1000);\n"
     "      if(msg){const w=msg.length*4+7;R(g,FX+((FW-w)>>1),FY+FW-12,w,9,PAL.bevelLo);TK.text(g,msg,FX+(FW>>1),FY+FW-10,msgCol,'center')}",
     "      if(!touched&&!scans.length&&now-t00<6000)KIT.tell(g,'SCAN, THEN DIG.',['click'],(now-t00)/1000);\n"
     "      if(msg)KIT.status(g,msg,msg==='ALL DUG'||TN.includes(msg)?'good':msg==='EMPTY'||msg==='NO DIGS LEFT'?'bad':'neutral',false);\n"
     "      else if(quiet)KIT.status(g,'QUIET','neutral',false);"),
    ("if(q.x>=CXL-1&&q.y<=27){for(const tb of TB)if(q.y>=tb.y&&q.y<tb.y+12&&tool!==tb.id){",
     "if(q.x>=CXL&&q.y<GY-1){for(const tb of TB)if(q.y>=tb.y&&q.y<tb.y+KIT.BTN.H&&tool!==tb.id){"),
]
# Rings B (Jon: "Why are there dots on seismic scan?"): the echo rings drawn solid, 1 px, in the find's tier
# colour (the graph's colours); the picked scan's rings full colour, the others a step darker, and when one
# spike is picked the other rings sink to a dark trace. Rings A is today's dithered (dotted) rings.
KIT_SEISMIC_RINGS_B = [
    ("else circ(g,ccx(p.x),ccy(p.y),r,TC[e.t],.12);continue}", "else circ(g,ccx(p.x),ccy(p.y),r,mix(TC[e.t],'#000000',.7));continue}"),
    ("circ(g,ccx(p.x),ccy(p.y),r,TC[e.t],k===ci?.8:.45);", "circ(g,ccx(p.x),ccy(p.y),r,k===ci?TC[e.t]:mix(TC[e.t],'#000000',.35));"),
    ("circ(g,x,y,ringR(f.e.d),fu<.3?'#ffffff':TC[f.e.t],fu<1?null:.6)", "circ(g,x,y,ringR(f.e.d),fu<.3?'#ffffff':TC[f.e.t])"),
]

# ---- Culture Dish (150 x 130): the header takes TRY and FED (the food count, was under TRY); X40 off. The
# dish (agar unchanged, R 51) sits in rows 10-120: centre 64 -> 65, its glass rim 6 -> 4 px. The bench's
# lamp dither and the shadow's dither go solid. Deck 121 (status line: 3/3 FED  3 DEAD  NO TRIES, ALL FED):
# the round dish leaves no room for a control row, so GROW / KEEP / AGAIN are kit buttons (33 x 13, GROW
# with its icon, active while it can be pressed) in the bottom corners right above the deck rule; the seed
# drops and growth rings stay in the bottom-left corner.
KIT_CULTURE = [
    ("const W=150,H=130,CX=75,CY=64,AR=51,RO=57;", "const KIT=TK.KIT,W=150,H=130,CX=75,CY=65,AR=51,RO=55;"),
    ("    const lamp=1-Math.hypot(x-30,y-18)/150;\n    put(x,y,bay(x,y)<lamp*.9?PANEL:(bay(x,y)<lamp*1.6-.6?PANEL:VOID));", "    put(x,y,PANEL);"),
    ("put(x,y,bay(x,y)<.75?LO:VOID)}", "put(x,y,LO)}"),
    ("for(const[a,b]of[[0,-1],[0,1],[-1,0],[1,0]])for(let k=0;k<3;k++)", "for(const[a,b]of[[-1,0],[1,0]])for(let k=0;k<3;k++)"),
    ("let touched=false,hover=-1,pressed=null,pressT=0,banner='',bannerCol=PAL.hot;",
     "let touched=false,hover=-1,pressed=null,pressT=0,banner='',bannerCol=PAL.hot,bparts=null;"),
    ("    TK.text(g,'TRY '+Math.min(attempt+1,tries)+'/'+tries,3,3,PAL.cold);\n"
     "    TK.text(g,'X40',W-3,3,PAL.cold,'right');\n"
     "    if(banner){const w=banner.length*4+7;R(g,CX-(w>>1),CY+44,w,9,PAL.bevelLo);TK.text(g,banner,CX,CY+46,bannerCol,'center')}\n"
     "    if(!touched&&t<6000)card(g,CX-48,CY+35,96,'EAT EVERY SPECK.',t/1000);",
     "    {const food=run?run.covered:0;KIT.header(g,{label:'TRY',value:Math.min(attempt+1,tries)+'/'+tries},[['FED',food+'/'+p.food.length,food===p.food.length?'good':null]])}\n"
     "    KIT.deck(g,false);\n"
     "    if(banner&&bparts)KIT.status(g,bparts,null,false);\n"
     "    if(!touched&&t<6000)KIT.tell(g,'EAT EVERY SPECK.',['click'],t/1000);"),
    ("    const y0=112;\n    const food=run?run.covered:0;\n"
     "    const fx=3,fy=6;R(g,fx,fy+6,3,3,PAL.ice);R(g,fx+1,fy+7,2,2,PAL.chill);\n"
     "    TK.text(g,food+'/'+p.food.length,fx+6,fy+5,food===p.food.length?PAL.mark:PAL.ice);\n"
     "    const btn=(x,w,label,on,fn)=>{const pr=pressed===label&&now-pressT<140;bevel(g,x,y0+2+(pr?1:0),w,14,on?PAL.ember:PAL.line,on);TK.text(g,label,x+(w>>1),y0+7+(pr?1:0),on?'#1a0e04':PAL.cold,'center');if(on)buttons.push({x,y:y0+1,w,h:16,label,fn})};",
     "    const y0=104,BY=KIT.deckY(false)-2-KIT.BTN.H; // seeds / rings centred on row 113; buttons rows 106-118\n"
     "    const btn=(x,w,label,on,fn,act)=>{const pr=pressed===label&&now-pressT<140;\n"
     "      KIT.button(g,x,BY,w,KIT.BTN.H,label,!on?'disabled':act?(pr?'active-pressed':'active'):(pr?'pressed':'normal'),label==='GROW'?'grow':null);\n"
     "      if(on)buttons.push({x,y:BY,w,h:KIT.BTN.H,label,fn})};"),
    ("btn(114,34,'GROW',can,grow);", "btn(KIT.W-KIT.GUT-33,33,'GROW',can,grow,true);"),
    ("btn(2,34,'KEEP',true,finish);\n      btn(114,34,'AGAIN',true,again);",
     "btn(KIT.GUT,33,'KEEP',true,finish);\n      btn(KIT.W-KIT.GUT-33,33,'AGAIN',true,again);"),
    ("banner='ALL FED';bannerCol=PAL.mark;", "banner='ALL FED';bparts=[['ALL FED','good']];"),
    ("banner=ev.covered+'/'+p.food.length+' FED'+(ev.hits?' '+ev.hits+' DEAD':'');bannerCol=ev.hits?PAL.flare:PAL.hot;",
     "banner=ev.covered+'/'+p.food.length+' FED';bparts=[[banner,'neutral']];if(ev.hits)bparts.push([ev.hits+' DEAD','bad']);"),
    ("banner+=' . NO TRIES';", "bparts.push(['NO TRIES','bad']);"),
    ("    _pt:(i)=>pos[i],\n", "    _pt:(i)=>pos[i],_btn:()=>({x:KIT.W-KIT.GUT-17,y:KIT.deckY(false)-2-KIT.BTN.H+6}),\n"),
]

# ---- Tumble Dock (152 x 130): the header takes GAS (kit meter, a segment per unit) and TIME; the clamp now
# hangs from the header rule (rows 10-15, was 0-5) and the view's centre moves 47 -> 52 so the wreck clears
# it; the drift arrow 15 -> 19. SPIN / STILL / DRIFT and TOO FAST (were stamped in the view) are the status
# line's running readout; DOCKED / OUT OF GAS / NO GAS take it over. Thrusters are kit buttons, 19 tall,
# icon only (33 wide x4 with drift, 45 wide x2 without); the one that slows the spin is the amber (active)
# one, pressed while it fires, all disabled when the gas is gone.
KIT_DOCK = [
    ("const CX=PW/2,CY=47,PR=WR.hh+2;", "const CX=PW/2,CY=52,PR=WR.hh+2;"),
    ("const B=P.drift?[{id:'ccw',x:2,w:35},{id:'left',x:40,w:35},{id:'right',x:77,w:35},{id:'cw',x:115,w:35}]:[{id:'ccw',x:2,w:72},{id:'cw',x:78,w:72}];\n"
     "  const by=VH+11,bh=17;",
     "const KT=TK.KIT,B=(P.drift?[{id:'ccw',x:3,w:33},{id:'left',x:40,w:33},{id:'right',x:77,w:33},{id:'cw',x:114,w:33}]:[{id:'ccw',x:3,w:45},{id:'cw',x:102,w:45}])\n"
     "    .map(b=>Object.assign(b,{x:b.x+1})); // canvas x: the kit is drawn 1 px in\n"
     "  const by=KT.BTN.YL,bh=KT.BTN.HL;"),
    (Cut("  function button(b,now){\n", "put(ex,ey+2,col);\n  }"),
     "  function button(b,now){\n"
     "    const on=press===b.id&&pressT>0;\n"
     "    // the button that slows the spin is the one to press now (sectors 1-3)\n"
     "    const want=S.over||P.depth>3?null:S.wk!==0?(S.wk>0?'ccw':'cw'):null;\n"
     "    const st=S.over||S.used>=P.gas?'disabled':want===b.id?(on?'active-pressed':'active'):(on?'pressed':'normal');\n"
     "    KT.button(g,b.x-1,by,b.w,bh,null,st,b.id);\n"
     "  }"),
    ("const ok=S.docked,near=!ok&&!S.over&&close(S,P),late=[];", "const ok=S.docked,near=!ok&&!S.over&&close(S,P),late=[],rd=[];"),
    ("if(!S.docked)for(let y=10;y<ty-6;y+=2)", "if(!S.docked)for(let y=20;y<ty-6;y+=2)"),
    ("      if(S.t>=6||S.used)late.push(()=>TK.text(g,'SPIN '+Math.abs(S.wk),3,VH-7,sl?A.good:A.flare));",
     "      if(S.t>=6||S.used)rd.push(['SPIN '+Math.abs(S.wk),sl?'good':'neutral']);"),
    ("      if(S.t>=6||S.used)late.push(()=>TK.text(g,'STILL',3,VH-7,A.good));", "      if(S.t>=6||S.used)rd.push(['STILL','good']);"),
    ("L=Math.round(4+dn*7),y=15,", "L=Math.round(4+dn*7),y=19,"),
    ("      if(S.t>=6||S.used)late.push(()=>TK.text(g,'DRIFT '+Math.abs(S.vk),PW-3,VH-7,dc,'right'))}",
     "      if(S.t>=6||S.used)rd.push(['DRIFT '+Math.abs(S.vk),dc===A.good?'good':'neutral'])}"),
    ("    const ext=S.docked?Math.min(ty-13,Math.round((t-endT)*40)):0;\n"
     "    for(let y=0;y<6+ext;y++)for(let x=-9;x<=9;x++){const ax=Math.abs(x);if(ax<4&&y<6+ext-2)continue;if(ax>9-(y>4+ext?2:0))continue;const c=ax===9||y===0?M[6]:ax>=7?M[4]:M[5];put(KX+x,y,c)}\n"
     "    for(const x of[-9,9])for(let y=0;y<6+ext;y++)put(KX+x+(x>0?1:-1),y,M[0]);\n"
     "    for(const x of[-6,6])put(KX+x,2,",
     "    const CT=KT.ROW.PLAY.y,ext=S.docked?Math.min(ty-13-CT,Math.round((t-endT)*40)):0; // the clamp hangs from the header rule\n"
     "    for(let y=0;y<6+ext;y++)for(let x=-9;x<=9;x++){const ax=Math.abs(x);if(ax<4&&y<6+ext-2)continue;if(ax>9-(y>4+ext?2:0))continue;const c=ax===9||y===0?M[6]:ax>=7?M[4]:M[5];put(KX+x,CT+y,c)}\n"
     "    for(const x of[-9,9])for(let y=0;y<6+ext;y++)put(KX+x+(x>0?1:-1),CT+y,M[0]);\n"
     "    for(const x of[-6,6])put(KX+x,CT+2,"),
    ("if(near){const lx=KX>CX?KX-46:KX+14;TK.text(g,'TOO FAST',lx,ty-2,A.flare)}", "if(near)rd.push(['TOO FAST','bad']);"),
    (Cut("    if(S.t<6&&!S.used)banner(g,A,PW,VH-15,'STOP IT UNDER THE CLAMP.',['click'],now);", "    for(const b of B)button(b,now);"),
     "    {g.save();g.translate(1,0);\n"
     "      const left=P.gas-S.used,tl=Math.max(0,Math.ceil(P.T-S.t)),low=left<=3;\n"
     "      KT.header(g,{label:'GAS',kind:low?'bad':null,meter:{w:Math.min(P.gas*4+1,89),frac:left/P.gas,kind:low?'bad':'neutral'}},[['TIME',tl,tl<10?'bad':null]]);\n"
     "      if(S.t<6&&!S.used)KT.tell(g,'STOP IT UNDER THE CLAMP.',['click'],now);\n"
     "      KT.deck(g,true);\n"
     "      if(statusT>0||S.over)KT.status(g,status,statusCol===A.good?'good':statusCol===A.bad?'bad':'neutral',true);\n"
     "      else if(rd.length)KT.status(g,rd,null,true);\n"
     "      for(const b of B)button(b,now);\n"
     "      g.restore()}"),
    ("_btn:id=>{const b=B.find(b=>b.id===id);return{x:b.x+(b.w>>1),y:by+8}}", "_btn:id=>{const b=B.find(b=>b.id===id);return{x:b.x+(b.w>>1),y:by+(bh>>1)}}"),
]

# ---- Core Scan (150 x 130): the header takes GLASS (its glass blocks in the free span, +N spares) and
# SLICE NxN; FOUND: name / SCAN LOST go to the status line (deck 121); the clues + grid fit rows 10-119, so
# cells are min(width fit, (109 - clue height) / n): a row or two of pixels smaller than fit4's (5x5 21 -> 19,
# 8x8 SCREW 12 -> 10). Tell card at the kit's spot.
KIT_CORESCAN = [
    ("const W=150,CS=Math.min(Math.floor((W-6-CLW)/n),Math.floor((119-CLH)/n)),GW=n*CS;\n"
     "    const GX=Math.floor((W-CLW-GW)/2)+CLW,GY=9+CLH+((119-CLH-GW)>>1),H=130;",
     "const KIT=TK.KIT,W=150,PY0=KIT.ROW.PLAY.y,AV=KIT.deckY(false)-PY0-2,CS=Math.min(Math.floor((W-6-CLW)/n),Math.floor((AV-CLH)/n)),GW=n*CS;\n"
     "    const GX=Math.floor((W-CLW-GW)/2)+CLW,GY=PY0+CLH+((AV-CLH-GW)>>1),H=130; // clues + grid + bezel in rows 10-120"),
    ("      if(!won&&!lost){\n      TK.text(g,'GLASS',3,2,PAL.cold);\n"
     "      for(let k=0;k<c.lives;k++){const x=26+k*7,broke=k<mistakes;",
     "      {const x0=KIT.header(g,'GLASS',[['SLICE',n+'X'+n]]).lx;\n"
     "      for(let k=0;k<c.lives;k++){const x=x0+k*7,broke=k<mistakes;"),
    ("      if(forgive)TK.text(g,'+'+forgive,26+c.lives*7+2,2,PAL.good);\n      TK.text(g,'SLICE '+n+'X'+n,W-3,2,PAL.cold,'right');}",
     "      if(forgive)TK.text(g,'+'+forgive,x0+c.lives*7+2,2,PAL.good);}\n      KIT.deck(g,false);"),
    ("TK.text(g,'FOUND: '+P.name,W>>1,2,PAL.hot,'center')}", "KIT.status(g,'FOUND: '+P.name,'good',false)}"),
    ("else if(lost)TK.text(g,'SCAN LOST',W>>1,2,PAL.bad,'center');", "else if(lost)KIT.status(g,'SCAN LOST','bad',false);"),
    ("if(!touched&&now-t0<4500)card(g,GX,GY+(GW>>1)-9,GW,'FILL IN THE SCAN.',(now-t0)/1000);",
     "if(!touched&&now-t0<4500)KIT.tell(g,'FILL IN THE SCAN.',['click'],(now-t0)/1000);"),
]

KITS = {"torch": KIT_TORCH, "leak": KIT_LEAK, "beams": KIT_BEAMS, "seismic": KIT_SEISMIC, "culture": KIT_CULTURE,
        "dock": KIT_DOCK, "corescan": KIT_CORESCAN}
WIDE = ("torch", "leak", "dock")   # 152-wide canvases


def apply(js: str, swaps: list, name: str) -> str:
    for a, b in swaps:
        if isinstance(a, Cut):
            assert js.count(a.start) == 1 and js.count(a.end) == 1, (name, js.count(a.start), js.count(a.end), a.start[:70])
            i = js.index(a.start)
            j = js.index(a.end, i) + len(a.end)
            js = js[:i] + b + js[j:]
        else:
            assert js.count(a) == 1, (name, js.count(a), a[:90])
            js = js.replace(a, b)
    return js


def fit4_js(game: str) -> str:
    f = F4.IDS[game]
    return F4.patched(f, F4.FILES[f])


def kit_game_js(game: str, rings: str = "B") -> str:
    """The game alone, fit4 + kit swaps (needs kit.js + KIT_ICONS_C loaded first)."""
    swaps = list(KITS[game])
    if game == "seismic" and rings == "B":
        swaps += KIT_SEISMIC_RINGS_B
    return apply(fit4_js(game), swaps, game)


def kit_patched(game: str, rings: str = "B") -> str:
    """kit.js, the extra icons, then the game with its fit4 swaps and its kit swaps."""
    return KIT_JS + "\n" + KIT_ICONS_C + "\n" + kit_game_js(game, rings)


if __name__ == "__main__":
    for g in KITS:
        kit_patched(g)
        print(g, len(KITS[g]), "kit swaps apply")
    kit_patched("seismic", "A")
