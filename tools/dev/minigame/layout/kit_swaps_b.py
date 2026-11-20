"""The UI kit (kit.js) applied to agent b's five games, on top of their fit4 layouts (fit4_swaps_b.py):
KIT_PULSAR, KIT_ANOMALY, KIT_SLING, KIT_FOURKELVIN, KIT_SPECTRUM. Each list is (old, new) string swaps,
every `old` asserted present exactly once in the fit4-patched text. Every game stays 150 x 130.
kit.js is loaded first (kit_patched() returns kit.js + the patched game).

    from kit_swaps_b import kit_patched, fit4_js
    js = kit_patched("sling")
"""
from __future__ import annotations

from pathlib import Path

import fit4_swaps_b as B
import kit_swaps_ref as REF

HERE = Path(__file__).parent


def _ref(prefix: str) -> tuple[str, str]:
    """One of the reference KIT_PULSAR swaps, found by the start of its `old`."""
    hits = [p for p in REF.KIT_PULSAR if p[0].startswith(prefix)]
    assert len(hits) == 1, prefix
    return hits[0]


# ---- Pulsar Fold: the reference KIT_PULSAR (header with SIG meter + LOCK lamp, tell card, status line,
# LOCK as a kit button over GIVE UP, PERIOD readout as a kit pair), but Pulsar keeps ITS OWN dial at its
# fit4 size and look (r 15 knurled knob in its void socket, Jon: "can keep their individual dials"). The
# deck is fitted round that dial: rule on row 95 (3 above the kit's 98), status text 98-102, the dial in
# rows 97-129 at the left; to its right the PERIOD readout and LOCK (rows 104-116) over the period strip,
# which keeps its fit4 length (104 px) and its own slider, the strip's face recoloured to the kit's void.
# The phosphor glass is rows 11-93 (stacked rows 46 -> 45).
KIT_PULSAR = [
    ("const RAWY=12,RAWH=13,WFY=27,WFH=46,PRY=75,PRH=16;", "const RAWY=14,RAWH=13,WFY=29,WFH=45,PRY=75,PRH=16;"),
    ("const DX=18,DY=112,DR=15;",
     "const KIT=TK.KIT,DECK=95; // the deck's rule: 3 rows above the kit's 98, to hold Pulsar's own 31 px dial\n"
     "const DX=KIT.GUT+15,DY=112,DR=14; // r 14 (was 15), raised 1: its foot on row 127, 4 rows clear of the haul line (Jon, Nov 20)"),
    ("const SX=40,SW=104,SY=112;", "const SX=DX+DR+7,SW=104,SY=120;"),
    ("const LB={x:104,y:96,w:43,h:10};", "const LB={x:KIT.W-KIT.GUT-33,y:104,w:33,h:KIT.BTN.H}; // over GIVE UP"),
    ("b.fillStyle=PAL.bevelHi;b.fillRect(1,1,W-2,1);b.fillRect(1,1,1,92);b.fillStyle=PAL.bevelLo;b.fillRect(1,93,W-2,1);b.fillRect(W-2,1,1,93);\n"
     "  b.fillStyle='#06110b';b.fillRect(3,3,W-6,89);",
     "b.fillStyle=PAL.bevelHi;b.fillRect(1,11,W-2,1);b.fillRect(1,11,1,82);b.fillStyle=PAL.bevelLo;b.fillRect(1,93,W-2,1);b.fillRect(W-2,11,1,83);\n"
     "  b.fillStyle='#06110b';b.fillRect(3,13,W-6,79);\n"
     "  b.fillStyle=KIT.BORDER;b.fillRect(0,DECK,W,H-DECK);b.fillStyle=PAL.line;b.fillRect(0,DECK,W,1);"),
    _ref("for(const[x,y]of[[4,96]"),                       # no corner screws
    _ref("TK.text(b,'PERIOD',SX,98"),                       # PERIOD is the readout's label now
    ("b.fillStyle='#0b120e';b.fillRect(SX,SY,SW,6);", "b.fillStyle=PAL.void;b.fillRect(SX,SY,SW,6);"),
    ("TK.text(b,String(PMIN),SX,SY+8,PAL.line);TK.text(b,String(PMAX),SX+SW,SY+8,PAL.line,'right');",
     "TK.text(b,PMIN+'-'+PMAX,LB.x-5,LB.y+4,PAL.line,'right');"),
    _ref("    TK.text(g,'SIG',5,5"),                         # kit header: SIG meter (+ 1/2), LOCK + lamp
    _ref("const lx=W-9,ly=7"),
    ("if(stampTxt&&clock<stampT){const w=stampTxt.length*8;g.fillStyle='#06110b';g.fillRect(W/2-w/2-3,WFY+13,w+5,14);"
     "text2(stampTxt,W/2-w/2,WFY+15,stampTxt==='LOCKED'?PAL.mark:stampTxt==='LOCKED.'?PAL.mark:stampTxt==='NO LOCK'||stampTxt==='LOST'?PAL.bad:PAL.hot)}",
     # KIT.status, on this deck's line (DECK+3, not the kit's 101)
     "if(stampTxt&&clock<stampT){const k=stampTxt==='LOCKED'?'good':stampTxt==='NO LOCK'||stampTxt==='LOST'?'bad':'neutral';"
     "TK.text(g,stampTxt,(W>>1)-((stampTxt.length*4-1)>>1),DECK+KIT.ROW.STATUS_TY,KIT.KIND[k].text)}"),
    _ref("else if(!started)startCard("),                    # tell card
    ("text2(fmt(Pf),SX+28,96,on?PAL.mark:PAL.good);", "KIT.pair(g,SX,LB.y+4,'PERIOD',fmt(Pf),{vkind:on?'good':null});"),
    _ref("    const hot=on&&!finished,pressed=lockDown;"),    # LOCK: the kit button
    ("if(q.y<94)return;started=true;", "if(q.y<DECK)return;started=true;"),
    ("if(q.x<37){dr=", "if(q.x<SX-2){dr="),
    ("!finished&&q.y>=94&&(q.x<37", "!finished&&q.y>=DECK&&(q.x<SX-2"),
    ("if(q.y<94)return;e.preventDefault();setP(", "if(q.y<DECK)return;e.preventDefault();setP("),
]

# ---- Anomaly Count: kit header (FOUND n/m left; RULE 1/2 when the rule changes, WRONG, TIME right), the
# rule on the deck's status line in goal blue (an OR rule on one line, OR in neutral; "+" closes up only
# when the spaced rule would pass the gutters), ALL LOGGED / TIME UP on the same line at the end, the tell
# card at the kit's spot. The lens goes back to its prototype size (r 52, critters x1.6) to sit between
# the header and the deck: rim rows 10-120, centre row 65. No corner texts; corners are the border colour.
KIT_ANOMALY = [
    ("const W=150,H=130,CX=75,CY=72,LENS=55,PS=LENS/52;", "const W=150,H=130,CX=75,CY=65,LENS=52,PS=LENS/52,KIT=TK.KIT;"),
    ("const K=1.7;", "const K=1.6;"),
    ("const SP=37,SH=18;", "const SP=35,SH=17;"),
    ("  function drawRule(){\n"
     "    const r=pz.rules[phase],lines=ruleText(r),fl=clock-ruleFlash<1.2;\n"
     "    g.fillStyle=fl?shade(PAL.ember,-.6):PAL.panel;g.fillRect(0,0,W,13);g.fillStyle=PAL.bevelLo;g.fillRect(0,13,W,1);\n"
     "    if(lines.length===1)TK.text(g,lines[0],W/2,4,PAL.hot,'center');\n"
     "    else{TK.text(g,lines[0],2,1,PAL.hot);TK.text(g,'OR',W-2,4,PAL.cold,'right');TK.text(g,lines[1],2,7,PAL.hot)}\n"
     "    if(pz.rules.length>1)TK.text(g,'RULE '+(phase+1),W-2,15,PAL.ember,'right');\n"
     "  }",
     "  // the deck: the rule to match on the status line (goal blue, blinking for a moment when it changes)\n"
     "  function drawRule(){\n"
     "    KIT.deck(g,false);\n"
     "    if(finished){const all=found===total;KIT.status(g,all?'ALL LOGGED':'TIME UP',all?'good':'bad',false);return}\n"
     "    let lines=ruleText(pz.rules[phase]);const room=W-2*KIT.GUT,len=ls=>ls.join(' OR ').length*4-1;\n"
     "    if(len(lines)>room)lines=lines.map(l=>l.split(' + ').join('+'));\n"
     "    const fl=clock-ruleFlash<1.2&&Math.floor(clock*5)%2===0,col=fl?PAL.ice:KIT.KIND.goal.text,y=KIT.deckY(false)+KIT.ROW.STATUS_TY;\n"
     "    let x=(W>>1)-(len(lines)>>1);\n"
     "    lines.forEach((l,i)=>{if(i){TK.text(g,'OR',x+4,y,KIT.KIND.neutral.text);x+=16}TK.text(g,l,x,y,col);x+=l.length*4});\n"
     "  }"),
    ("    TK.text(g,'FOUND',2,17,PAL.cold);TK.text(g,got+'/'+need,2,23,got===need?PAL.good:PAL.hot);\n"
     "    TK.text(g,'TIME',W-2,pz.rules.length>1?22:17,PAL.cold,'right');TK.text(g,String(Math.ceil(timeLeft)),W-2,pz.rules.length>1?28:23,fr<.25?PAL.bad:PAL.hot,'right');\n"
     "    TK.text(g,'WRONG',2,H-12,PAL.cold);TK.text(g,String(wrong),2,H-6,wrong?PAL.bad:PAL.chill);\n"
     "    if(finished)TK.text(g,found===total?'ALL LOGGED':'TIME',W-2,H-6,found===total?PAL.good:PAL.hot,'right');\n"
     "    if(!started)startCard(g,'FIND EVERY MATCH',CONTROLS,W/2,CY-13,clock,PAL.panel,PAL.bevelHi);",
     "    const right=[];if(pz.rules.length>1)right.push(['RULE',(phase+1)+'/'+pz.rules.length]);\n"
     "    right.push(['WRONG',wrong,wrong?'bad':null],['TIME',Math.ceil(timeLeft),fr<.25?'bad':null]);\n"
     "    KIT.header(g,{label:'FOUND',value:got+'/'+need,vkind:got===need?'good':null},right);\n"
     "    if(!started)KIT.tell(g,'FIND EVERY MATCH.',CONTROLS,clock);"),
    # the loupe stays between the header and the deck
    ("ly=fy-LR-14>LR+1?fy-LR-14:Math.min(H-LR-2,fy+LR+14);", "ly=fy-LR-14>LR+11?fy-LR-14:Math.min(KIT.deckY(false)-LR-3,fy+LR+14);"),
]

# ---- Gravity Sling: kit header (LAUNCH n left; PWR while pulling, else LAST n right), the nav plot in the
# play rows 10-97 (the same 1000 x 640 field at 0.1375 px a unit: 138 x 88, centred, solid border either
# side), the kit deck from row 98: status line (HIT / MISS 12 / IMPACT / NO-FLY / TOO WEAK / OUT OF
# PROBES), and the control row with Sling's OWN dial (r 13, same look; AIM label + value at its right as the
# kit dial has them) and its own pull (fork, bands, pouch, power ticks) unchanged, 2 rows lower than fit4.
KIT_SLING = [
    ("const W=150,H=130,FY=96,SC=W/FW; // field is 150 x 96 art px",
     "const KIT=TK.KIT,W=150,H=130,FY=98,FT=10,FHP=FY-FT,SC=FHP/FH,FWP=Math.ceil(FW*SC),FX=(W-FWP)>>1; // FY: the deck's rule; the field: rows 10-97, 138 x 88 art px"),
    ("const DX=15,DY=113,DRAD=13;", "const DX=KIT.GUT+13,DY=114,DRAD=13; // raised 2: its foot on row 127, 4 rows clear of the haul line (Jon, Nov 20)"),
    ("const FKX=142,RY=114,PULLMAX=72;", "const FKX=142,RY=FY+16,PULLMAX=72;"),
    # the pull rides 2 rows higher (Jon, Nov 20: nothing lit within 4 rows of the haul line at 132): fork,
    # rest line, power ticks, bands, pouch and the last-power mark all end by row 127
    ("  line(d,FKX+3,31,FKX+3,20,PAL.bevelLo);line(d,FKX+4,31,FKX+4,20,PAL.cold);\n"
     "  line(d,FKX+3,20,FKX,10,PAL.cold);line(d,FKX+4,20,FKX+1,10,PAL.chill);\n"
     "  line(d,FKX+3,20,FKX,27,PAL.cold);line(d,FKX+4,20,FKX+1,27,PAL.bevelLo);\n",
     "  line(d,FKX+3,29,FKX+3,18,PAL.bevelLo);line(d,FKX+4,29,FKX+4,18,PAL.cold);\n"
     "  line(d,FKX+3,18,FKX,8,PAL.cold);line(d,FKX+4,18,FKX+1,8,PAL.chill);\n"
     "  line(d,FKX+3,18,FKX,25,PAL.cold);line(d,FKX+4,18,FKX+1,25,PAL.bevelLo);\n"),
    ("dot(d,x,30,k%5===0?PAL.chill:PAL.line);if(k%5===0)dot(d,x,29,PAL.chill)}",
     "dot(d,x,28,k%5===0?PAL.chill:PAL.line);if(k%5===0)dot(d,x,27,PAL.chill)}"),
    ("line(g,FKX,FY+10,PX-1,PY-2,band);line(g,FKX,FY+27,PX-1,PY+2,band);", "line(g,FKX,FY+8,PX-1,PY-2,band);line(g,FKX,FY+25,PX-1,PY+2,band);"),
    ("g.fillRect(lx-1,FY+27,3,1);dot(g,lx,FY+26,PAL.t2)", "g.fillRect(lx-1,FY+25,3,1);dot(g,lx,FY+24,PAL.t2)"),
    ("bg.width=W;bg.height=FY;const b=bg.getContext('2d');\n  b.fillStyle=PAL.void;b.fillRect(0,0,W,FY);",
     "bg.width=FWP;bg.height=FHP;const b=bg.getContext('2d');\n  b.fillStyle=PAL.void;b.fillRect(0,0,FWP,FHP);"),
    ("dot(b,hr()*W,hr()*FY,", "dot(b,hr()*FWP,hr()*FHP,"),
    ("for(let x=0;x<W;x+=12)for(let y=0;y<FY;y+=12)dot(b,x,y,PAL.line);", "for(let x=0;x<FWP;x+=12)for(let y=0;y<FHP;y+=12)dot(b,x,y,PAL.line);"),
    ("d.fillStyle=PAL.panel;d.fillRect(0,0,W,H-FY);d.fillStyle=PAL.bevelHi;d.fillRect(0,0,W,1);d.fillStyle=PAL.bevelLo;d.fillRect(0,1,W,1);",
     "d.fillStyle=KIT.BORDER;d.fillRect(0,0,W,H-FY);d.fillStyle=PAL.line;d.fillRect(0,0,W,1);"),
    ("TK.text(d,'AIM',33,5,PAL.cold);", "TK.text(d,'AIM',DX+DRAD+4,DY-FY-6,KIT.LABEL);"),
    ("g.drawImage(bg,0,0);",
     "g.fillStyle=KIT.BORDER;g.fillRect(0,0,W,FY);\n"
     "    g.save();g.beginPath();g.rect(FX,FT,FWP,FHP);g.clip();g.translate(FX,FT);g.drawImage(bg,0,0);"),
    ("    // field HUD\n"
     "    TK.text(g,'LAUNCH '+(maxShots-used),2,2,PAL.chill);\n"
     "    if(missTxt)TK.text(g,missTxt,W-2,2,missTxt==='HIT'?PAL.good:missTxt==='IMPACT'||missTxt==='NO-FLY'?PAL.bad:PAL.hot,'right');\n"
     "    if(note&&clock<noteT)TK.text(g,note,W/2,FY-7,PAL.hot,'center');\n"
     "    else if(!started)startCard(g,'HIT THE TARGET',CONTROLS,W/2,FY-30,clock,PAL.void,PAL.bevelHi);\n"
     "    g.fillStyle=PAL.bevelLo;g.fillRect(0,FY-1,W,1);",
     "    g.restore();\n"
     "    // the kit's header: launches left; the sling's power right (PWR while pulling, else the last launch's)\n"
     "    const shownP=pow>0?pow:0,left=maxShots-used;\n"
     "    KIT.header(g,{label:'LAUNCH',value:left,vkind:left<=1?'bad':null},shownP?[['PWR',shownP,'yours']]:lastPow>0?[['LAST',lastPow]]:[['PWR','-']]);\n"
     "    if(!started)KIT.tell(g,'HIT THE TARGET.',CONTROLS,clock);"),
    ("Math.abs(ang),33,FY+13,PAL.hot);", "Math.abs(ang),DX+DRAD+4,DY+1,KIT.VALUE);"),
    ("    const shownP=pow>0?pow:0;\n"
     "    TK.text(g,shownP?'PWR '+shownP:lastPow>0?'LAST '+lastPow:'PWR',W-14,FY+5,shownP?PAL.hot:PAL.cold,'right');\n", ""),
    ("if(dim){g.globalAlpha=.35;g.fillStyle=PAL.void;g.fillRect(0,FY+2,W,H-FY-2);g.globalAlpha=1}",
     "if(dim){g.globalAlpha=.35;g.fillStyle=PAL.void;g.fillRect(0,FY+1,W,H-FY-1);g.globalAlpha=1}\n"
     "    {let s=null,k=null;if(note&&clock<noteT){s=note;k=note==='OUT OF PROBES'?'bad':'neutral'}\n"
     "      else if(missTxt){s=missTxt;k=missTxt==='HIT'?'good':missTxt==='IMPACT'||missTxt==='NO-FLY'?'bad':'neutral'}\n"
     "      KIT.status(g,s,k,true)}"),
    ("if(q.x<31){dial=", "if(q.x<DX+DRAD+3){dial="),
    ("(q.x<31||q.x>=52)", "(q.x<DX+DRAD+3||q.x>=52)"),
    ("if(q.y<FY||q.x>=31)return;", "if(q.y<FY||q.x>=DX+DRAD+3)return;"),
]

# ---- Four Kelvin: kit header (HULL + its blocks in the header's free span, DIST right), the belt right
# under it (rows 10-91, 1 px a unit as before), the belt-progress bar on rows 94-95, the kit deck from 98:
# status line (IMPACT / BELT CLEAR; the WARNING: ROCK tag stays on the culprit rock), control row of kit
# buttons 19 tall: turn left / right (icons) and THRUST (icon over label), ENERGY as a kit meter between
# them. Tell card: W A D keys, FLY THE SHIP.
KIT_FOURKELVIN = [
    ("const W=150,H=130,GENW=140,VY=12,BH=82,SHIPX=46,DT=1/30;   // view: HUD 0-11, belt rows 12-93, bar 96-97, buttons 100-128",
     "const W=150,H=130,GENW=140,VY=10,BH=82,SHIPX=46,DT=1/30,KIT=TK.KIT;   // view: kit header 0-9, belt rows 10-91, progress bar 94-95, kit deck 98-129"),
    ("const BTN={a:[2,101,22,26],d:[27,101,22,26],w:[W-48,101,46,26]};",
     "const BTN={a:[KIT.GUT,KIT.BTN.YL,25,KIT.BTN.HL],d:[KIT.GUT+25+KIT.GAP,KIT.BTN.YL,25,KIT.BTN.HL],w:[W-KIT.GUT-45,KIT.BTN.YL,45,KIT.BTN.HL]};"),
    ("      g.fillStyle=P.panel;g.fillRect(0,0,W,11);g.fillStyle=P.bevelHi;g.fillRect(0,11,W,1);\n"
     "      const fresh=clock-hitT<0.9&&Math.floor((clock-hitT)*10)%2===0;\n"
     "      TK.text(g,'HULL',2,3,fresh?P.hot:P.cold);hullBar(19,2);\n"
     "      TK.text(g,String(Math.floor(dist()*5)).padStart(4,'0')+'M',W-2,3,P.hot,'right');",
     "      const fresh=clock-hitT<0.9&&Math.floor((clock-hitT)*10)%2===0;\n"
     "      const sp=KIT.header(g,{label:'HULL',kind:fresh?'bad':null},[['DIST',String(Math.floor(dist()*5)).padStart(4,'0')+'M']]);\n"
     "      hullBar(sp.lx,1);   // the blocks in the header's free span, at the kit meter's place"),
    ("      g.fillStyle=P.panel;g.fillRect(0,94,W,H-94);g.fillStyle=P.bevelHi;g.fillRect(0,94,W,1);\n"
     "      const f=Math.min(1,dist()/F.target),bw=W-4;      // how far into the belt\n"
     "      g.fillStyle=P.line;g.fillRect(2,96,bw,2);g.fillStyle=P.chill;g.fillRect(2,96,Math.round(bw*f),2);g.fillStyle=P.hot;g.fillRect(2+Math.round(bw*f),96,1,2);",
     "      const DK=KIT.deckY(true),by=VY+BH+2;g.fillStyle=P.panel;g.fillRect(0,VY+BH,W,DK-VY-BH);\n"
     "      const f=Math.min(1,dist()/F.target),bw=W-2*KIT.GUT;      // how far into the belt\n"
     "      g.fillStyle=P.line;g.fillRect(KIT.GUT,by,bw,2);g.fillStyle=P.chill;g.fillRect(KIT.GUT,by,Math.round(bw*f),2);g.fillStyle=P.hot;g.fillRect(KIT.GUT+Math.round(bw*f),by,1,2);\n"
     "      KIT.deck(g,true);"),
    ("      btn(...BTN.a,want('a'),P.warn,'l');btn(...BTN.d,want('d'),P.warn,'r');btn(...BTN.w,want('w'),P.ice,'THRUST');",
     "      const st=k=>mode==='end'?'disabled':want(k)?'pressed':'normal';\n"
     "      KIT.button(g,...BTN.a,null,st('a'),'ccw');KIT.button(g,...BTN.d,null,st('d'),'cw');KIT.button(g,...BTN.w,'THRUST',st('w'),'thrust');"),
    ("      const ex=52,ew=W-48-3-ex;g.fillStyle=P.bevelLo;g.fillRect(ex,100,ew,28);g.fillStyle=P.void;g.fillRect(ex+1,101,ew-2,26);\n"
     "      TK.text(g,'ENERGY',ex+Math.floor(ew/2),106,P.cold,'center');\n"
     "      for(let i=0;i<4;i++){g.fillStyle=P.ember;g.fillRect(ex+Math.floor(ew/2)-8+i*4,115,3,3)}",
     "      {const ex=BTN.d[0]+BTN.d[2]+KIT.GAP,ew=BTN.w[0]-KIT.GAP-ex;TK.text(g,'ENERGY',ex,KIT.ROW.CTRL.cy-6,KIT.LABEL);KIT.meter(g,ex,KIT.ROW.CTRL.cy,ew,1,'yours')}"),
    ("      if(mode==='ready'){const y=box(['FLY THE SHIP.','GET THE ORE.'],[P.hot,P.hot],24);g.save();g.translate(Math.floor((W-30)/2),y+30);TK.icon(g,'keys',0,0,{label:'WAD',t:clock});g.restore()}\n"
     "      else if(mode==='end'){const tag=intentTag();\n"
     "        if(endT>(crashed?1:0.5)){const lines=crashed?['IMPACT']:['BELT CLEAR'];let at=null;\n"
     "          // the box sits clear of the intent tag and the rock: first free spot wins\n"
     "          if(tag){const w=Math.max(...lines.map(l=>l.length*4-1))+14,h=lines.length*8+8,hit=(x,y,a)=>x<a.x+a.w&&x+w>a.x&&y<a.y+a.h&&y+h>a.y;\n"
     "            const rock={x:tag.rx,y:tag.ry,w:tag.rw,h:tag.rw},mid=VY+Math.floor((BH-h)/2);\n"
     "            for(const[x,y]of[[Math.floor((W-w)/2),mid],[W-w-2,mid],[W-w-2,VY+3],[W-w-2,VY+BH-h-2],[Math.floor((W-w)/2),VY+BH-h-2],[Math.floor((W-w)/2),VY+3],[2,VY+3],[2,VY+BH-h-2]])\n"
     "              if(!hit(x,y,tag)&&!hit(x,y,rock)){at=[x+1,y+1];break}}\n"
     "          box(lines,[crashed?P.bad:P.good],0,at)}}",
     # the outcome word goes to the deck's status line; the WARNING tag stays on the rock
     "      if(mode==='ready')KIT.tell(g,'FLY THE SHIP.',['keys:WAD'],clock);\n"
     "      else if(mode==='end'){intentTag();\n"
     "        if(endT>(crashed?1:0.5))KIT.status(g,crashed?'IMPACT':'BELT CLEAR',crashed?'bad':'good',true)}"),
]

# ---- Star Light: diff.py's approved SPECTRUM_FIT as fit4 took it to every tube count, under the kit:
# the match meter goes up into the kit header (MATCH + meter + %, SWITCHES right), the STAR / YOU strips
# sit right under it (8 rows of lines each, the link bracket between them as before), the tube rows share
# rows 36-120 (pitch floor(85/T): 3 tubes 28, 4: 21, 5: 17, 6: 14, 7: 12), and the deck's status line has
# the running readout (LINES 2/4, n EXTRA) and MATCH! / NO MATCH / NO POWER (no longer on the meter).
KIT_SPECTRUM = [
    ("ROW=Math.floor(91/T),TY=40+((91-T*ROW)>>1),", "ROW=Math.floor(85/T),TY=36+((85-T*ROW)>>1),"),
    ("strip(2,10);strip(17,10);", "strip(12,8);strip(25,8);"),
    ("TK.text(b,'STAR',2,5,PAL.chill);TK.text(b,'YOU',2,20,PAL.chill);", "TK.text(b,'STAR',2,14,PAL.chill);TK.text(b,'YOU',2,27,PAL.chill);"),
    ("  R(b,0,37,W,1,PAL.bevelLo);R(b,0,38,W,1,PAL.bevelHi);\n", ""),
    ("drawLine(lineX(bn),2,10,", "drawLine(lineX(bn),12,8,"),
    ("drawLine(x,17,10,binCol(bn),.6,", "drawLine(x,25,8,binCol(bn),.6,"),
    ("R(g,x,13,2,1,PAL.good);R(g,x,15,2,1,PAL.good);for(let y=14;y<15;y++)", "R(g,x,21,2,1,PAL.good);R(g,x,23,2,1,PAL.good);for(let y=22;y<23;y++)"),
    ("drawLine(x+wob,17,10,binCol(bn),0,false);R(g,x-1+wob,16,4,1,PAL.bad);R(g,x-1+wob,27,4,1,PAL.bad);",
     "drawLine(x+wob,25,8,binCol(bn),0,false);R(g,x-1+wob,24,4,1,PAL.bad);R(g,x-1+wob,33,4,1,PAL.bad);"),
    ("(f.y0+(17-f.y0)*u*u):(17+(f.y0-17)*u)", "(f.y0+(25-f.y0)*u*u):(25+(f.y0-25)*u)"),
    ("f.up?10-Math.round(2*(1-u)):Math.max(1,10-Math.round(8*u))", "f.up?8-Math.round(2*(1-u)):Math.max(1,8-Math.round(6*u))"),
    ("    const MX=SX,MW=c.budget?84:SW,MY=31;\n"
     "    R(g,MX-1,MY-1,MW+2,7,'#000');R(g,MX,MY,MW,5,PAL.void);\n"
     "    const fw=Math.round(MW*frac);\n"
     "    const mcol=frac===1&&!extras?PAL.good:extras?PAL.flare:PAL.t1;\n"
     "    for(let x=0;x<fw;x++)for(let y=0;y<5;y++)R(g,MX+x,MY+y,1,1,y===0?mix(mcol,'#ffffff',.5):y>3?mix(mcol,'#000000',.35):mcol);\n"
     "    if(!(frac===1&&!extras))for(let k=1;k<tgt.length;k++){const x=MX+Math.round(MW*k/tgt.length);R(g,x,MY,1,5,'#000')}\n"
     "    TK.text(g,Math.round(frac*100)+'%',MX+MW-2,MY,frac>0.55?'#0a0e15':PAL.ice,'right');\n"
     "    if(c.budget){TK.text(g,'PWR',MX+MW+5,MY+2,PAL.cold);for(let k=0;k<powerMax;k++)R(g,MX+MW+19+k*3,MY+1,2,6,k<power?PAL.ember:PAL.line)}",
     "    // the kit header: the match meter left; switches (or power, if a sector has a budget) right\n"
     "    {const KIT=TK.KIT,full=frac===1&&!extras;\n"
     "      KIT.header(g,{label:'MATCH',meter:{w:53,frac,kind:full?'good':'neutral'},value:Math.round(frac*100)+'%',vkind:full?'good':null},\n"
     "        c.budget?[['PWR',power,power<=1?'bad':null]]:[['SWITCHES',toggles]])}"),
    ("    if(won)TK.text(g,'MATCH!',SX+(SW>>1),MY,'#0a0e15','center');\n"
     "    else if(power<=0&&!over)TK.text(g,'NO POWER',SX+(SW>>1),MY,PAL.bad,'center');\n",
     "    // the kit deck: status line only (the tubes are the controls)\n"
     "    {const KIT=TK.KIT;KIT.deck(g,false);\n"
     "      if(won)KIT.status(g,'MATCH!','good',false);\n"
     "      else if(over)KIT.status(g,'NO MATCH','bad',false);\n"
     "      else if(power<=0)KIT.status(g,'NO POWER','bad',false);\n"
     "      else if(toggles){const parts=[['LINES '+matched+'/'+tgt.length,matched===tgt.length?'good':'neutral']];if(extras)parts.push([extras+' EXTRA','bad']);KIT.status(g,parts,null,false)}}\n"),
    ("    if(!toggles&&!over&&now-t0<4500)card(g,SX-2,18,SW+4,'MATCH THE STAR.',(now-t0)/1000);\n"
     "    if(over&&!won)TK.text(g,'NO MATCH',SX+(SW>>1),MY,PAL.bad,'center');",
     "    if(!toggles&&!over)TK.KIT.tell(g,'MATCH THE STAR.',['click'],(now-t0)/1000);"),
]

KIT_JS = (HERE / "kit.js").read_text(encoding="utf-8")
GAMES = {
    "pulsar": ("pulsar2.js", B.PULSAR, KIT_PULSAR),
    "anomaly": ("anomaly2.js", B.ANOMALY, KIT_ANOMALY),
    "sling": ("sling2.js", B.SLING, KIT_SLING),
    "fourkelvin": ("fourkelvin.js", B.FOURKELVIN, KIT_FOURKELVIN),
    "spectrum": ("spectrum2.js", B.SPECTRUM, KIT_SPECTRUM),
}


def apply(js: str, swaps: list[tuple[str, str]], name: str) -> str:
    for a, b in swaps:
        assert js.count(a) == 1, (name, js.count(a), a[:90])
        js = js.replace(a, b)
    return js


def fit4_js(game: str) -> str:
    name, fit4, _kit = GAMES[game]
    return B.patched(name, fit4)


def kit_patched(game: str) -> str:
    """kit.js, then the game with its fit4 swaps and then its kit swaps."""
    name, _fit4, kit = GAMES[game]
    return KIT_JS + "\n" + apply(fit4_js(game), kit, name)


if __name__ == "__main__":
    for g in GAMES:
        kit_patched(g)
        print(g, len(GAMES[g][2]), "kit swaps apply")
