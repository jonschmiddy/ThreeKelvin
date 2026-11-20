"""The UI kit (kit.js) applied to two games as worked references, on top of their fit4 layouts:
KIT_COOLANT after fit4_swaps_a.COOLANT, KIT_PULSAR after fit4_swaps_b.PULSAR. Each list is (old, new)
string swaps, every `old` asserted present exactly once in the fit4 text. The game stays 150 x 130.
kit.js must be loaded first (kit_js() + the patched game, see kit_ref_sheets.py).

    from kit_swaps_ref import kit_patched
    js = kit_patched("coolant")      # kit.js + coolant2.js with fit4 and kit swaps
"""
from __future__ import annotations

from pathlib import Path

import fit4_swaps_a as A
import fit4_swaps_b as B

HERE = Path(__file__).parent

# ---- Coolant Routing: header row (HEAT bar + TURNS / PAR), play rows 10-120, deck 121-129 with the status
# line (COLD 1/2, VALVE, LEAK; ROUTED / OVERHEAT), tell card at the kit's spot. No controls (the grid is the control).
# The grid is centred in rows 11-119 (109 rows; it was 9-116 in 108): tiles keep their fit4 sizes.
KIT_COOLANT = [
    ("  const S=Math.min(Math.floor((W-4-2*E)/w),Math.floor(108/h))&~1; // tile size, even: as big as rows 9-116 allow\n"
     "  const GX=Math.floor((W-w*S)/2),GY=9+((108-h*S)>>1),TY=H-8; // grid centred in rows 9-116; hint / status at the bottom",
     "  const KIT=TK.KIT,PY0=KIT.ROW.PLAY.y+1,PH=KIT.deckY(false)-1-PY0; // the kit's play rows, inside the grid's 1 px frame\n"
     "  const S=Math.min(Math.floor((W-4-2*E)/w),Math.floor(PH/h))&~1; // tile size, even: as big as the play rows allow\n"
     "  const GX=Math.floor((W-w*S)/2),GY=PY0+((PH-h*S)>>1); // grid centred in the play rows"),
    ("  function hud(){\n"
     "    TK.text(g,'HEAT',2,2,heat>.75?C.bad:C.chill);\n"
     "    const bx=20,bw=W-2-62-bx;\n"
     "    R(bx,2,bw,5,C.bevelLo);const fw=Math.round((bw-2)*heat);\n"
     "    if(fw>0){R(bx+1,3,fw,3,heat>.75?C.bad:C.ember);R(bx+1,3,fw,1,heat>.75?C.flare:C.hot)}\n"
     "    TK.text(g,`TURNS ${taps} PAR ${P.par}`,W-2,2,C.ice,'right');\n"
     "    const n=F.reached.filter(Boolean).length,parts=[];\n"
     "    let s;\n"
     "    if(won)s=['ROUTED',C.good];else if(lost)s=['OVERHEAT',C.bad];\n"
     "    if(s){TK.text(g,s[0],W/2,TY,s[1],'center');return}\n"
     "    if(taps===0){const str='COOL THE SAMPLE.',tw=str.length*4-1,x0=Math.floor(W/2-(IW+5+tw)/2);\n"
     "      TK.icon(g,'click',x0,TY-4,{t:(performance.now()-t0p)/1000});TK.text(g,str,x0+IW+5,TY,C.hot);return}\n"
     "    parts.push([`COLD ${n}/${P.rows.length}`,n===P.rows.length?C.good:C.chill]);\n"
     "    if(P.valve>=0)parts.push(F.lit.has(P.valve)?['VALVE OPEN',C.good]:['VALVE DRY',C.warn]);\n"
     "    if(F.leaks.length)parts.push(['LEAK',C.bad]);\n"
     "    const str=parts.map(p=>p[0]).join('  ');let x=Math.floor(W/2-(str.length*4-1)/2);\n"
     "    for(const[t,c]of parts){TK.text(g,t,x,TY,c);x+=t.length*4+8}\n"
     "  }",
     "  function hud(){\n"
     "    const hot=heat>.75;\n"
     "    KIT.header(g,{label:'HEAT',kind:hot?'bad':null,meter:{w:53,frac:heat,kind:hot?'bad':'neutral'}},[['TURNS',taps],['PAR',P.par]]);\n"
     "    KIT.deck(g,false);\n"
     "    if(won){KIT.status(g,'ROUTED','good',false);return}\n"
     "    if(lost){KIT.status(g,'OVERHEAT','bad',false);return}\n"
     "    if(taps===0){KIT.tell(g,'COOL THE SAMPLE.',['click'],(performance.now()-t0p)/1000);return}\n"
     "    const n=F.reached.filter(Boolean).length,parts=[[`COLD ${n}/${P.rows.length}`,n===P.rows.length?'good':'neutral']];\n"
     "    if(P.valve>=0)parts.push(F.lit.has(P.valve)?['VALVE OPEN','good']:['VALVE DRY','neutral']);\n"
     "    if(F.leaks.length)parts.push(['LEAK','bad']);\n"
     "    KIT.status(g,parts,null,false);\n"
     "  }"),
]

# ---- Pulsar Fold: header row (SIG meter + 1/2 left, LOCK + its lamp right), the phosphor glass in rows
# 11-96, deck 98-129: status line (LOCKED / WEAK / NO LOCK / LOST, no longer stamped 2x over the glass),
# control row with the kit dial (19 across, was 31), PERIOD readout over the strip, and LOCK as a kit
# button (33x13) right above GIVE UP. The glass loses 7 rows to the header band but its rows grow 46 -> 48.
# The strip is 84 px (was 104): the dial does the fine tuning, the strip the jumps; 30-58 sits on the readout row.
KIT_PULSAR = [
    ("const RAWY=12,RAWH=13,WFY=27,WFH=46,PRY=75,PRH=16;", "const RAWY=14,RAWH=13,WFY=29,WFH=48,PRY=78,PRH=16;"),
    ("const DX=18,DY=112,DR=15;", "const KIT=TK.KIT,CY=KIT.ROW.CTRL.cy;\nconst DX=KIT.GUT+KIT.DIAL.R,DY=CY,DR=KIT.DIAL.R;"),
    ("const SX=40,SW=104,SY=112;", "const SX=DX+DR+5,SW=84,SY=CY+1;"),
    ("const LB={x:104,y:96,w:43,h:10};", "const LB={x:KIT.W-KIT.GUT-33,y:KIT.BTN.YS,w:33,h:KIT.BTN.H}; // over GIVE UP"),
    ("b.fillStyle=PAL.bevelHi;b.fillRect(1,1,W-2,1);b.fillRect(1,1,1,92);b.fillStyle=PAL.bevelLo;b.fillRect(1,93,W-2,1);b.fillRect(W-2,1,1,93);\n"
     "  b.fillStyle='#06110b';b.fillRect(3,3,W-6,89);",
     "b.fillStyle=PAL.bevelHi;b.fillRect(1,11,W-2,1);b.fillRect(1,11,1,85);b.fillStyle=PAL.bevelLo;b.fillRect(1,96,W-2,1);b.fillRect(W-2,11,1,86);\n"
     "  b.fillStyle='#06110b';b.fillRect(3,13,W-6,82);\n"
     "  KIT.deck(b,true);"),
    ("for(const[x,y]of[[4,96],[W-5,96],[4,H-4],[W-5,H-4]])", "for(const[x,y]of[])"),
    ("  for(let y=-DR-2;y<=DR+2;y++)for(let x=-DR-2;x<=DR+2;x++){const r=Math.hypot(x,y);if(r>DR+1.5)continue;\n"
     "    dot(b,DX+x,DY+y,r>DR+.5?PAL.bevelLo:PAL.void)}\n", ""),
    ("TK.text(b,'PERIOD',SX,98,PAL.cold);", ""),
    ("TK.text(b,String(PMIN),SX,SY+8,PAL.line);TK.text(b,String(PMAX),SX+SW,SY+8,PAL.line,'right');",
     "TK.text(b,PMIN+'-'+PMAX,SX+SW,CY-6,PAL.line,'right');"),
    ("    TK.text(g,'SIG',5,5,sig<.5?PAL.flare:PAL.chill);\n"
     "    {const x0=19,segs=nT>1?19:22,lit_=Math.ceil(sig*segs-1e-9);\n"
     "      g.fillStyle=PAL.bevelLo;g.fillRect(x0-1,4,segs*4+1,7);\n"
     "      for(let k=0;k<segs;k++){const on=k<lit_,f=(k+1)/segs;\n"
     "        const col=!on?'#0d1a14':sig<.15?PAL.bad:sig<.5?PAL.ember:sig<.8?PAL.cold:PAL.chill;\n"
     "        const top=!on?'#0d1a14':sig<.5?PAL.flare:sig<.8?PAL.chill:PAL.ice;\n"
     "        g.fillStyle=col;g.fillRect(x0+k*4,5,3,5);g.fillStyle=top;g.fillRect(x0+k*4,5,3,1);void f}\n"
     "      if(nT>1)TK.text(g,Math.min(locks.length+1,nT)+'/'+nT,x0+segs*4+3,5,PAL.good)}\n"
     "    TK.text(g,'LOCK',W-14,5,on?PAL.mark:shade(PAL.good,-.45),'right');",
     "    {const low=sig<.25;\n"
     "      KIT.header(g,{label:'SIG',kind:low?'bad':null,meter:{w:nT>1?77:89,frac:sig,kind:low?'bad':'neutral'},value:nT>1?Math.min(locks.length+1,nT)+'/'+nT:null},\n"
     "        [['LOCK',null,null,on?'good':null]],{padR:10})}"),
    ("const lx=W-9,ly=7,a=Math.pow(lit,2);", "const lx=W-8,ly=4,a=Math.pow(lit,2);"),
    ("if(stampTxt&&clock<stampT){const w=stampTxt.length*8;g.fillStyle='#06110b';g.fillRect(W/2-w/2-3,WFY+13,w+5,14);"
     "text2(stampTxt,W/2-w/2,WFY+15,stampTxt==='LOCKED'?PAL.mark:stampTxt==='LOCKED.'?PAL.mark:stampTxt==='NO LOCK'||stampTxt==='LOST'?PAL.bad:PAL.hot)}",
     "if(stampTxt&&clock<stampT)KIT.status(g,stampTxt,stampTxt==='LOCKED'?'good':stampTxt==='NO LOCK'||stampTxt==='LOST'?'bad':'neutral',true);"),
    ("else if(!started)startCard(g,'TUNE IN THE PULSAR',CONTROLS,W/2,WFY+6,clock,'#06110b',PAL.good);",
     "else if(!started)KIT.tell(g,'TUNE IN THE PULSAR.',CONTROLS,clock);"),
    ("    for(let y=-DR;y<=DR;y++)for(let x=-DR;x<=DR;x++){const r=Math.hypot(x,y);if(r>DR-.5)continue;\n"
     "      const lt=(-x-y)/DR;let col=lt>.5?PAL.chill:lt>0?PAL.cold:lt>-.5?PAL.line:PAL.bevelLo;\n"
     "      if(r>DR-3){const ang=Math.atan2(y,x)-rot;if(((Math.floor((ang/(2*Math.PI))*24+48))&1))col=PAL.bevelLo}\n"
     "      else if(r>DR-4)col=PAL.bevelLo;\n"
     "      dot(g,DX+x,DY+y,col)}\n"
     "    for(let y=-6;y<=6;y++)for(let x=-6;x<=6;x++){const r=Math.hypot(x,y);if(r<=6)dot(g,DX+x,DY+y,r>5?PAL.bevelLo:(-x-y)>3?PAL.cold:PAL.line)}\n"
     "    const mx=DX+Math.sin(rot)*9,my=DY-Math.cos(rot)*9;g.fillStyle=PAL.ember;g.fillRect(Math.round(mx)-1,Math.round(my)-1,2,2);",
     "    KIT.dial(g,DX,DY,rot,{state:finished?'disabled':dr?'active':'normal'});"),
    ("text2(fmt(Pf),SX+28,96,on?PAL.mark:PAL.good);", "KIT.pair(g,SX,CY-6,'PERIOD',fmt(Pf),{vkind:on?'good':null});"),
    ("    const hot=on&&!finished,pressed=lockDown;\n"
     "    g.fillStyle=PAL.bevelLo;g.fillRect(LB.x,LB.y,LB.w,LB.h);\n"
     "    g.fillStyle=hot?PAL.good:PAL.line;g.fillRect(LB.x+1,LB.y+1+(pressed?1:0),LB.w-2,LB.h-2-(pressed?1:0));\n"
     "    g.fillStyle=hot?PAL.mark:PAL.bevelHi;g.fillRect(LB.x+1,LB.y+1+(pressed?1:0),LB.w-2,1);\n"
     "    TK.text(g,'LOCK',LB.x+(LB.w>>1),LB.y+3+(pressed?1:0),hot?'#0d1a12':finished?PAL.cold:PAL.ice,'center');\n"
     "    if(hot&&Math.floor(clock*2)%2){for(let x=LB.x-1;x<=LB.x+LB.w;x+=2){dot(g,x,LB.y-2,PAL.good);dot(g,x+1,LB.y+LB.h+1,PAL.good)}}\n",
     "    const hot=on&&!finished,pressed=lockDown!==false;\n"
     "    KIT.button(g,LB.x,LB.y,LB.w,LB.h,'LOCK',finished?'disabled':hot?(pressed?'active-pressed':'active'):(pressed?'pressed':'normal'));\n"),
    # input: the control row starts at KIT.ROW.CTRL.y (was the deck at 94); the dial's reach is its column
    ("if(q.y<94)return;started=true;", "if(q.y<KIT.ROW.CTRL.y)return;started=true;"),
    ("if(q.x<37){dr=", "if(q.x<SX-2){dr="),
    ("!finished&&q.y>=94&&(q.x<37", "!finished&&q.y>=KIT.ROW.CTRL.y&&(q.x<SX-2"),
    ("if(q.y<94)return;e.preventDefault();setP(", "if(q.y<KIT.ROW.CTRL.y)return;e.preventDefault();setP("),
]

KIT_JS = (HERE / "kit.js").read_text(encoding="utf-8")
GAMES = {"coolant": ("coolant2.js", A.COOLANT, KIT_COOLANT, A.patched), "pulsar": ("pulsar2.js", B.PULSAR, KIT_PULSAR, B.patched)}


def apply(js: str, swaps: list[tuple[str, str]], name: str) -> str:
    for a, b in swaps:
        assert js.count(a) == 1, (name, js.count(a), a[:90])
        js = js.replace(a, b)
    return js


def fit4_js(game: str) -> str:
    name, fit4, _kit, patched = GAMES[game]
    return patched(name, fit4)


def kit_patched(game: str) -> str:
    """kit.js, then the game with its fit4 swaps and then its kit swaps."""
    name, _fit4, kit, _p = GAMES[game]
    return KIT_JS + "\n" + apply(fit4_js(game), kit, name)


if __name__ == "__main__":
    for g in GAMES:
        kit_patched(g)
        print(g, len(GAMES[g][2]), "kit swaps apply")
