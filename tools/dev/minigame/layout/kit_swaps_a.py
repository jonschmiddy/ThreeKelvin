"""The UI kit (kit.js) on set A: Coolant, Centrifuge, Ice Core, Sample Tray, Signal Tuning, on top of their
fit4 layouts (fit4_swaps_a.py). KIT_<ID> lists are (old, new) swaps applied after the fit4 ones, every `old`
asserted present exactly once. Coolant is the kit's own reference (kit_swaps_ref.KIT_COOLANT), used as is.
Every game stays exactly 150 x 130.

    from kit_swaps_a import kit_patched, fit4_js
    js = kit_patched("centrifuge")      # kit.js + centrifuge2.js with fit4 and kit swaps
"""
from __future__ import annotations

import fit4_swaps_a as A
from kit_swaps_ref import KIT_COOLANT, KIT_JS, apply

# ---- Centrifuge: header ROTOR n / MOVES n; no control row (the bowl is 105 rows: it cannot sit over a deck
# at 98), so the deck is the 121 one: status line READY / SPINNING / BALANCED / WOBBLE n% / ROTOR FAULT.
# The bowl is centred in rows 13-117 (play rows 10-120). The 8 px backdrop grid comes off: the border is solid.
# SPIN is a kit button (19 tall, spin icon over the label) under the rack; the tell card in the kit's spot.
KIT_CENTRIFUGE = [
    ("const CX=53,CY=61;          // rotor hub", "const KIT=TK.KIT;\nconst CX=53,CY=65;          // rotor hub: bowl in rows 13-117"),
    ("const RACK={x:109,y:8,w:40,h:82},SPIN={x:110,y:94,w:38,h:17};",
     "const RACK={x:108,y:12,w:40,h:82},SPIN={x:111,y:98,w:33,h:KIT.BTN.HL}; // SPIN centred under the rack"),
    ("    p.clear(PAL.void);\n    // terminal backdrop: faint grid\n"
     "    g.fillStyle=PAL.panel;for(let x=4;x<W;x+=8)g.fillRect(x,8,1,H-16);for(let y=12;y<H-8;y+=8)g.fillRect(0,y,W,1);\n",
     "    p.clear(KIT.BORDER);\n"),
    ("    TK.text(g,'ROTOR '+N,2,1,PAL.cold);\n    TK.text(g,'MOVES '+moves,W-2,1,PAL.chill,'right');\n", ""),
    ("    fill(b.x,b.y,b.w,b.h,PAL.bevelLo);\n"
     "    if(ready){fill(b.x+1,b.y+1+pr,b.w-2,b.h-2-pr,PAL.ember);if(!pr)fill(b.x+1,b.y+1,b.w-2,1,PAL.flare);fill(b.x+1,b.y+b.h-2,b.w-2,1,'#8a4a14')}\n"
     "    else{fill(b.x+1,b.y+1,b.w-2,b.h-2,PAL.panel);fill(b.x+1,b.y+1,b.w-2,1,PAL.line)}\n"
     "    TK.text(g,'SPIN',b.x+b.w/2,b.y+6+pr,ready?PAL.void:PAL.line,'center');",
     "    KIT.button(g,b.x,b.y,b.w,b.h,'SPIN',ready?(pr?'active-pressed':'active'):spinning?'pressed':'disabled','spin');"),
    ("    if(!acted&&!over){// start frame: the goal, and the inputs as icons\n"
     "      const tt=(performance.now()-t0)/1000,hw=71,x0=Math.round((W-(22+5+hw))/2);\n"
     "      fill(0,H-15,W,15,PAL.void);fill(0,H-15,W,1,PAL.line);\n"
     "      TK.icon(g,'drag',x0,H-14,{t:tt});\n"
     "      TK.text(g,'BALANCE THE TUBES.',x0+27,H-10,PAL.hot);\n"
     "    }else TK.text(g,msgTxt,W/2,H-7,msgCol,'center');",
     "    KIT.header(g,{label:'ROTOR',value:N},[['MOVES',moves]]);\n"
     "    KIT.deck(g,false);\n"
     "    if(!acted&&!over)KIT.tell(g,'BALANCE THE TUBES.',['click','drag'],(performance.now()-t0)/1000);\n"
     "    else KIT.status(g,msgTxt,msgCol===PAL.good?'good':msgCol===PAL.bad?'bad':'neutral',false);"),
    ("msgTxt=r<1e-6?'BALANCED. NO WOBBLE':", "msgTxt=r<1e-6?'BALANCED':"),
]

# ---- Ice Core: header CHECKS n / LAYERS n; deck at 98 with CLEAR and CHECK as kit buttons (33 x 13, CHECK
# over GIVE UP, active when the tube is full); status line n/10 IN PLACE / ORDER CONFIRMED; tell card.
# The play area packs into rows 10-97: cores 53 rows tall at most (bottom row 53), the two rule notes under
# them (neutral, no longer warn), the tray at 73 on a 13 row pitch, the tube's slots 9 -> 7 px at 9-10 layers
# (70 rows for the slots: 9 px up to 7 layers, 8 at 8, 7 at 9-10) with NEW / OLD above and below it.
KIT_ICECORE = [
    ("const CX0=17,CDX=18,CW=14,LH=8,GH=5,CB=68;", "const KIT=TK.KIT;\nconst CX0=17,CDX=18,CW=14,LH=8,GH=5,CB=53;"),
    ("const SX=113,SW=26,SH=9,SB=106;", "const SX=113,SW=26,SB=89; // slot height SH: per deal, in mount"),
    ("const PX0=4,PDX=20,PW=18,PHh=11,PY0=86,PDY=14;", "const PX0=4,PDX=20,PW=18,PHh=10,PY0=73,PDY=13;"),
    ("const BY=115,BH=13,BCL=[86,30],BCK=[118,30];",
     "const BY=KIT.BTN.YS,BH=KIT.BTN.H,BCK=[KIT.W-KIT.GUT-33,33],BCL=[KIT.W-KIT.GUT-33-KIT.GAP-33,33]; // CHECK over GIVE UP"),
    ("  const p=gen(ctx.rng,ctx.depth),s=ctx.sensors|0,n=p.n;",
     "  const p=gen(ctx.rng,ctx.depth),s=ctx.sensors|0,n=p.n;\n  const SH=Math.min(9,Math.floor(70/n)); // the tube's 70 rows of slots"),
    ("    // faint frost on the bench\n    TK.dither(g,0,H-6,W,6,PAL.void,PAL.panel,.5);\n", ""),
    ("    if(!acted){R(0,0,W,8,PAL.panel);R(0,8,W,1,PAL.line);TK.text(g,'STACK THE LAYERS IN ORDER',W/2,2,PAL.hot,'center')}else{\n"
     "    TK.text(g,'CHECKS '+(checks-used),2,2,PAL.hot);\n"
     "    TK.text(g,'LAYERS '+n,105,2,PAL.cold,'right')}",
     "    KIT.header(g,{label:'CHECKS',value:checks-used,vkind:checks-used<1?'bad':null},[['LAYERS',n]]);"),
    ("    let ny=CB+6;\n    if(p.flips){TK.text(g,'ONE UPSIDE DOWN',CX0-4,ny,PAL.warn);ny+=6}",
     "    let ny=CB+7;\n    if(p.flips){TK.text(g,'ONE UPSIDE DOWN',CX0-4,ny,PAL.chill);ny+=6}"),
    ("    button(BCL,'CLEAR',false,pressed==='clear');\n"
     "    button(BCK,'CHECK',full&&!finished,pressed==='check');\n"
     "    // message\n"
     "    const m=msg;\n"
     "    if(!acted&&!m){const tt=now/1000;const w1=TK.icon(g,'click',2,BY+1,{t:tt});TK.icon(g,'drag',2+w1+4,BY+1,{t:tt})}\n"
     "    if(m)TK.text(g,m,2,BY+4,finished&&winAt?PAL.good:PAL.hot);",
     "    KIT.deck(g,true);\n"
     "    KIT.button(g,BCL[0],BY,BCL[1],BH,'CLEAR',finished?'disabled':pressed==='clear'?'pressed':'normal');\n"
     "    KIT.button(g,BCK[0],BY,BCK[1],BH,'CHECK',finished||!full?'disabled':pressed==='check'?'active-pressed':'active');\n"
     "    // message: the deck's status line; the start card in the kit's place\n"
     "    const m=msg;\n"
     "    if(m)KIT.status(g,m,finished?(winAt?'good':'bad'):'neutral',true);\n"
     "    if(!acted&&!m)KIT.tell(g,'STACK THE LAYERS IN ORDER.',['drag'],now/1000);"),
]

# ---- Sample Tray: header MOVES n  PAR n (right; the 2x MOVES stamp goes); no control row (a 6x6 grid over a
# deck at 98 would be 13 px cells), so the deck is the 121 one: status line SAMPLE OUT. Cells 18 -> 17 px, the
# tray in rows 10-119. UNDO n is a kit button (33 x 13, lined up with GIVE UP) at the foot of the right column;
# the BAY lamp, MOVES / PAR labels leave the column. Tell card in the kit's spot.
KIT_TRAY = [
    ("const W=150,H=130,C=18,GX=6,GY=11;     // 6x6 cells of 18 art px",
     "const KIT=TK.KIT;\nconst W=150,H=130,C=17,GX=6,GY=14;     // 6x6 cells of 17 art px: the tray in rows 10-119"),
    ("const UB={x:RX,y:105,w:28,h:14};", "const UB={x:KIT.W-KIT.GUT-33,y:106,w:33,h:KIT.BTN.H}; // over GIVE UP"),
    ("  // HUD labels\n  TK.text(b,'MOVES',RX,GY,PAL.cold);TK.text(b,'PAR',RX,GY+20,PAL.cold);\n  TK.text(b,'BAY',RX,EXY+C+3,PAL.cold);\n",
     "  KIT.deck(b,false);\n"),
    ("    // HUD\n    big(String(moves_),RX,GY+7,PAL.hot);TK.text(g,String(P.par),RX+14,GY+20,PAL.chill);\n"
     "    // bay lamp\n"
     "    const ok=outT>=0&&clock-outT>1;const lx=RX+16,ly=EXY+C+5;\n"
     "    g.fillStyle=PAL.bevelLo;g.fillRect(lx-1,ly-1,7,7);g.fillStyle=ok?PAL.good:PAL.line;g.fillRect(lx,ly,5,5);if(ok){dot(g,lx+1,ly+1,PAL.mark);\n"
     "      for(let y=-4;y<=8;y++)for(let x=-4;x<=8;x++){const r=Math.hypot(x-2,y-2);if(r>3.6&&r<6&&bay(lx+x,ly+y)<(6-r)/4)dot(g,lx+x,ly+y,shade(PAL.good,-.3))}}\n"
     "    if(ok)TK.text(g,'OUT',RX,ly+9,PAL.good);\n",
     "    KIT.header(g,null,[['MOVES',moves_],['PAR',P.par]]);\n"
     "    if(outT>=0&&clock-outT>1)KIT.status(g,'SAMPLE OUT','good',false);\n"),
    ("    g.fillStyle=PAL.bevelLo;g.fillRect(UB.x,UB.y,UB.w,UB.h);g.fillStyle=can?PAL.bevelHi:PAL.line;g.fillRect(UB.x+1,UB.y+1+(pr?1:0),UB.w-2,UB.h-2-(pr?1:0));\n"
     "    g.fillStyle=can?PAL.chill:PAL.bevelHi;g.fillRect(UB.x+1,UB.y+1+(pr?1:0),UB.w-2,1);if(!can){g.fillStyle=PAL.line;g.fillRect(UB.x+1,UB.y+1,UB.w-2,1)}\n"
     "    TK.text(g,'UNDO '+undos,UB.x+(UB.w>>1),UB.y+4+(pr?1:0),can?PAL.ice:PAL.cold,'center');\n"
     "    if(!started)startCard(g,'GET THE SAMPLE OUT',CONTROLS,GX+S*C/2,GY+S*C/2-13,clock,PAL.panel,PAL.bevelHi);",
     "    KIT.button(g,UB.x,UB.y,UB.w,UB.h,'UNDO '+undos,!can?'disabled':pr?'pressed':'normal');\n"
     "    if(!started)KIT.tell(g,'GET THE SAMPLE OUT.',CONTROLS,clock);"),
]

# ---- Signal Tuning (keeps its own knobs): header MATCH meter (11 segments, was the right column's) left,
# STEP n  PAR n right; the two 74 px scopes in rows 14-93 (labels 14, glass 20-93); deck at 98. The status
# line carries the dial readout (X 3  Y 2  PH 90  SIZE .85, a right dial's part green), then MATCH! or
# NO MATCH (the stamp on YOURS goes). Control row: the knobs (radius 8 -> 7 so the detent ticks fit rows
# 107-129) each with its short label at its lower right, then LOCK as a kit button (25 x 13, right edge on
# GIVE UP's), amber when it matches. The detent click flashes the collar (the outer ring would leave the row).
# The corner screws come off the border.
KIT_TUNING = [
    ("const SY=7,SS=74,R=32,HS=SS>>1;", "const SY=20,SS=74,R=32,HS=SS>>1;"),
    ("const KLY=84,KY=102,KR=8,KW=106; // knob label row, knob centre row, knob radius, the knobs' width\n"
     "const LOCK={x:110,y:112,w:39,h:16};",
     "const KIT=TK.KIT;\n"
     "const KY=KIT.ROW.CTRL.cy-1,KR=7; // knob centre row (1 above the control row's), knob radius: ticks reach rows 106-127, 4 rows clear of the haul line (Jon, Nov 20)\n"
     "const LOCK={x:KIT.W-KIT.GUT-25,y:KIT.BTN.YS,w:25,h:KIT.BTN.H}; // right edge on GIVE UP's"),
    ("  addKnob('X FREQ','a',", "  addKnob('X','a',"),
    ("  addKnob('Y FREQ','b',", "  addKnob('Y','b',"),
    ("  if(c.phase)addKnob('PHASE','ph',", "  if(c.phase)addKnob('PH','ph',"),
    ("  if(c.amp)addKnob('X SIZE','amp',", "  if(c.amp)addKnob('SIZE','amp',"),
    ("  const slot=KW/knobs.length;\n  knobs.forEach((k,i)=>{k.cx=Math.round(slot*i+slot/2);k.cy=KY;k.n=k.wrap?8:k.hi-k.lo+1});",
     "  // the knobs across the control row left of LOCK: each knob (ticks out to 11), its label at its lower right\n"
     "  // (cx+10, rows cy+1..cy+5, where no detent tick falls); a label may run under the next knob's left ticks\n"
     "  {const lw=k=>k.lab.length*4-1,pitch=k=>Math.max(23,19+lw(k)),n=knobs.length;\n"
     "    let need=11+knobs.slice(0,-1).reduce((a,k)=>a+pitch(k),0)+Math.max(11,9+lw(knobs[n-1]));\n"
     "    const room=LOCK.x-KIT.GAP-KIT.GUT,gap=n>1?Math.min(14,Math.floor((room-need)/(n-1))):0;need+=gap*(n-1);\n"
     "    let x=KIT.GUT+11+((room-need)>>1);\n"
     "    knobs.forEach(k=>{k.cx=x;k.cy=KY;k.n=k.wrap?8:k.hi-k.lo+1;x+=pitch(k)+gap})}"),
    ("    if(k.click&&now-k.click<500){const a=1-(now-k.click)/500;\n"
     "      for(let y=-KR-6;y<=KR+6;y++)for(let x=-KR-6;x<=KR+6;x++){const r=Math.hypot(x,y);if(r>KR+4.5&&r<KR+6.5&&((x+y)&1)===0&&((x*7+y*13)&3)<a*4)px(cx+x,cy+y,1,1,PAL.good)}}",
     "    if(k.click&&now-k.click<500){const a=1-(now-k.click)/500;\n"
     "      for(let y=-KR-2;y<=KR+2;y++)for(let x=-KR-2;x<=KR+2;x++){const r2=x*x+y*y;if(r2>(KR+1)*(KR+1)&&r2<=(KR+2)*(KR+2)&&((x*7+y*13)&3)<a*4)px(cx+x,cy+y,1,1,PAL.mark)}}"),
    ("    TK.text(G,k.lab,cx,KLY,PAL.cold,'center');\n    TK.text(G,k.fmt(cur[k.key]),cx,KY+KR+5,ok?PAL.mark:PAL.hot,'center');",
     "    TK.text(G,k.lab,cx+10,cy+1,PAL.cold);"),
    ("    const{x,y,w,h}=LOCK,pressed=lockDown||finished;\n"
     "    px(x,y,w,h,PAL.bevelLo);\n"
     "    const f=finished?(d<MATCH?PAL.good:PAL.cold):PAL.ember;\n"
     "    px(x+1,y+1,w-2,h-2,f);\n"
     "    if(!pressed){px(x+1,y+1,w-2,1,finished?f:PAL.hot);px(x+1,y+1,1,h-2,finished?f:PAL.flare);px(x+1,y+h-2,w-2,1,'#8a4a16');px(x+w-2,y+1,1,h-2,'#8a4a16')}\n"
     "    else{px(x+1,y+1,w-2,1,'#8a4a16');px(x+1,y+1,1,h-2,'#8a4a16')}\n"
     "    TK.text(G,'LOCK',Math.round(x+w/2)+(pressed?1:0),Math.round(y+h/2-2)+(pressed?1:0),PAL.void,'center');",
     "    const{x,y,w,h}=LOCK,on=d<MATCH;\n"
     "    KIT.button(G,x,y,w,h,'LOCK',finished?'disabled':on?(lockDown?'active-pressed':'active'):(lockDown?'pressed':'normal'));"),
    ("    p.clear(PAL.panel);\n    // faint panel texture and screw heads\n"
     "    for(const[sx,sy]of[[1,1],[PW-2,1],[1,PH-2],[PW-2,PH-2]])px(sx,sy,1,1,PAL.bevelHi);\n",
     "    p.clear(KIT.BORDER);\n"),
    ("TK.text(G,s.lab,s.x+HS,1,i?PAL.flare:PAL.t2,'center')", "TK.text(G,s.lab,s.x+HS,SY-6,i?PAL.flare:PAL.t2,'center')"),
    ("    if(finished){const ok=d<MATCH;const s=ok?'MATCH':'OFF';const wpx=s.length*4-1,bx=SC[1].x+HS-Math.floor(wpx/2)-2;\n"
     "      px(bx,SY+SS-14,wpx+4,9,PAL.bevelLo);TK.text(G,s,SC[1].x+HS,SY+SS-12,ok?PAL.mark:PAL.bad,'center')}\n", ""),
    ("    const rx=LOCK.x+2,rr=PW-3;px(LOCK.x-1,KLY-3,LOCK.w+1,31,PAL.bevelLo);px(LOCK.x,KLY-2,LOCK.w-1,29,PAL.void);\n"
     "    TK.text(G,'PAR',rx,KLY,PAL.cold);TK.text(G,String(parNow),rr,KLY,PAL.hot,'right');\n"
     "    TK.text(G,'STEP',rx,KLY+7,PAL.cold);TK.text(G,String(taps),rr,KLY+7,taps>parNow+2+free?PAL.flare:PAL.hot,'right');\n"
     "    {// MATCH: a segmented meter that climbs as you tune in; a fine needle eases to it\n"
     "      const mx=LOCK.x+1,my=KLY+20,mw=LOCK.w-2,mh=7,f=closeness(g,cur);meterV+=(f-meterV)*.25;\n"
     "      const segs=11,n=Math.round(meterV*segs);\n"
     "      px(mx,my,mw,mh,PAL.bevelLo);px(mx+1,my+1,mw-2,mh-2,'#05080d');\n"
     "      for(let j=0;j<segs;j++){const xx=mx+((mw-segs*3+1)>>1)+j*3,on=j<n,top=f>=.999;\n"
     "        px(xx,my+2,2,mh-4,!on?'#0f1824':top?PAL.mark:j>=segs-3?PAL.good:j>=segs-6?'#5f9a7c':'#3f6a52')}\n"
     "      TK.text(G,'MATCH',rx,my-6,f>=.999?PAL.mark:PAL.cold);\n"
     "    }\n"
     "    knobs.forEach(k=>knob(k,drag&&drag.k===k,now));\n"
     "    if(!acted&&!finished){const s='MATCH THE WAVE.',tw=s.length*4-1,iw=13+3+13,W=tw+4+iw,bx=(PW>>1)-Math.floor(W/2);px(bx-3,45,W+6,17,PAL.bevelLo);px(bx-2,46,W+4,15,PAL.panel);TK.text(G,s,bx,51,PAL.hot);const ts=(now-t0)/1000;let ix=bx+tw+4;ix+=TK.icon(G,'dial',ix,47,{t:ts})+3;TK.icon(G,'click',ix,47,{t:ts})}\n"
     "    lockBtn();",
     "    {// MATCH: the header's meter (11 segments) climbs as you tune in; STEP / PAR on the right\n"
     "      const f=closeness(g,cur);meterV+=(f-meterV)*.25;\n"
     "      KIT.header(G,{label:'MATCH',kind:f>=.999?'good':null,meter:{w:45,frac:meterV,kind:f>=.999?'good':'neutral'}},\n"
     "        [['STEP',taps,taps>parNow+2+free?'bad':null],['PAR',parNow]]);\n"
     "    }\n"
     "    KIT.deck(G,true);\n"
     "    knobs.forEach(k=>knob(k,drag&&drag.k===k,now));\n"
     "    lockBtn();\n"
     "    if(finished)KIT.status(G,d<MATCH?'MATCH!':'NO MATCH',d<MATCH?'good':'bad',true);\n"
     "    else KIT.status(G,knobs.map(k=>[k.lab+' '+k.fmt(cur[k.key]),isRight(k)?'good':'neutral']),null,true);\n"
     "    if(!acted&&!finished)KIT.tell(G,'MATCH THE WAVE.',['dial','click'],(now-t0)/1000);"),
]

GAMES = {
    "coolant": ("coolant2.js", A.COOLANT, KIT_COOLANT),
    "centrifuge": ("centrifuge2.js", A.CENTRIFUGE, KIT_CENTRIFUGE),
    "icecore": ("icecore2.js", A.ICECORE, KIT_ICECORE),
    "tray": ("tray2.js", A.TRAY, KIT_TRAY),
    "tuning": ("tuning2.js", A.TUNING, KIT_TUNING),
}


def fit4_js(game: str) -> str:
    name, fit4, _kit = GAMES[game]
    return A.patched(name, fit4)


def patched(game: str) -> str:
    """The game with its fit4 swaps, then its kit swaps (no kit.js)."""
    name, _fit4, kit = GAMES[game]
    return apply(fit4_js(game), kit, name)


def kit_patched(game: str) -> str:
    """kit.js, then the game with its fit4 and kit swaps: what the page runs."""
    return KIT_JS + "\n" + patched(game)


if __name__ == "__main__":
    for g in GAMES:
        kit_patched(g)
        print(g, len(GAMES[g][2]), "kit swaps apply")
