"""Status A for the science mini games (Jon, Nov 20: "I like A. You can just get rid of the bottom bar
with GIVE UP. You can just press ESC to give up."): each game's swaps on top of its approved kit page
(kit.js + the prototype + its fit and kit swaps), applied by `layout.page_js` after the kit swaps.

What a game's list does (kit_spec.md, "Status A"): the page is exactly 150x140 (152x140 for the torch,
the leak, the dock); the play area grows into every freed row (the status line's and the strip's);
status words go to the result card (END: `pop.finish`), toasts (LIVE: `pop.say`) or their own spot
(STANDING, per fit/status_inventory.md); the tell's icons never list ESC (its second line has it). Every `old` must be in
the page exactly once. One list per game; add yours to SWAPS.
"""
from __future__ import annotations

# ---- Coolant Routing (no controls: no deck; play rows 10-139). The grid is centred in rows 11-138 and the
# tile size takes 1 px less margin each side (W-2-2E, not W-4-2E: the core sits 1 in at the left), so tiles
# grow 22 -> 24 at sectors 1-2 and 18 -> 20 at 3-4 (16 at 5, its 7 columns bind). COLD n/m and VALVE drop
# (the grid shows both: coolant at the chambers, the valve's wheel lit or dry). LEAK is a toast when a leak
# opens; ROUTED / OVERHEAT go on the result card.
COOLANT = [
    ("const W=150,H=130,E=14; // canvas size (every deal); core/chamber column width",
     "const W=150,H=140,E=14; // canvas size (every deal): the whole glass (A); core/chamber column width"),
    ("  const S=Math.min(Math.floor((W-4-2*E)/w),Math.floor(PH/h))&~1; // tile size, even: as big as the play rows allow",
     "  const S=Math.min(Math.floor((W-2-2*E)/w),Math.floor(PH/h))&~1; // tile size, even: as big as the play rows allow (1 px margins)"),
    ("let taps=0,over=false,heat=0,last=-1,phase=0,F=null,won=false,lost=false;",
     "let taps=0,over=false,heat=0,last=-1,phase=0,F=null,won=false,lost=false;const pop=KIT.popups(ctx);"),
    ("    KIT.deck(g,false);\n"
     "    if(won){KIT.status(g,'ROUTED','good',false);return}\n"
     "    if(lost){KIT.status(g,'OVERHEAT','bad',false);return}\n"
     "    if(taps===0){KIT.tell(g,'COOL THE SAMPLE.',['click'],(performance.now()-t0p)/1000);return}\n"
     "    const n=F.reached.filter(Boolean).length,parts=[[`COLD ${n}/${P.rows.length}`,n===P.rows.length?'good':'neutral']];\n"
     "    if(P.valve>=0)parts.push(F.lit.has(P.valve)?['VALVE OPEN','good']:['VALVE DRY','neutral']);\n"
     "    if(F.leaks.length)parts.push(['LEAK','bad']);\n"
     "    KIT.status(g,parts,null,false);\n",
     "    if(!over&&taps===0)KIT.tell(g,'COOL THE SAMPLE.',['click'],(performance.now()-t0p)/1000);\n"),
    ("tiles.forEach((_,i)=>drawTile(i));drawEnds();hud()}",
     "tiles.forEach((_,i)=>drawTile(i));drawEnds();hud();pop.draw(g,performance.now()/1000)}"),
    ("    F=flood(P);\n    if(win(P,F)){",
     "    const leaks=F.leaks.length;F=flood(P);\n"
     "    if(F.leaks.length>leaks)pop.say('LEAK','bad',performance.now()/1000);\n"
     "    if(win(P,F)){"),
    ("      const s=scoreOf(heat,taps,P.par);\n",
     "      const s=scoreOf(heat,taps,P.par);pop.finish('ROUTED','good',performance.now()/1000);\n"),
    ("if(heat>=1){over=true;lost=true;clearInterval(timer);last=-1;render();",
     "if(heat>=1){over=true;lost=true;clearInterval(timer);last=-1;pop.finish('OVERHEAT','bad',performance.now()/1000);render();"),
    ("  function onDown(e){\n    if(over)return;",
     "  function onDown(e){\n    if(pop.click(performance.now()/1000))return;\n    if(over)return;"),
]

# ---- Beam Bench (no controls: no deck). The table, its frame and the emitter's housing sit in rows 11-138
# with 1 px side margins; cells are as big as those allow (the old 106-px cap was fit2's LIT column, gone
# with the kit's header): 21 -> 24 / 17 -> 20 / 15 -> 17 with the emitter at a side, 19 -> 22 / 16 -> 18 /
# 13 -> 16 with it above or below (5x5 / 6x6 / 7x7). ALL LIT goes on the result card; no live words.
BEAMS = [
    ("  const KIT=TK.KIT,W=150,H=130,PY0=KIT.ROW.PLAY.y,PH=KIT.deckY(false)-PY0,sd=P.src.d,vert=sd===0||sd===2;\n"
     "  const CS=Math.min(Math.floor(106/n),Math.floor((vert?PH-15:PH-6)/n)),BW=n*CS;",
     "  const KIT=TK.KIT,W=150,H=140,PY0=KIT.ROW.PLAY.y+1,PH=KIT.deckY(false)-1-PY0,sd=P.src.d;const pop=KIT.popups(ctx);\n"
     "  const CS=Math.min(Math.floor((W-2-(sd===1||sd===3?15:6))/n),Math.floor((PH-(sd===0||sd===2?15:6))/n)),BW=n*CS;"),
    ("    if(!taps&&!over&&now-t0<4500)KIT.tell(g,'LIGHT EVERY SENSOR.',['click'],(now-t0)/1000);\n"
     "    if(won)KIT.status(g,'ALL LIT','good',false);\n"
     "    if(!over&&lit===P.sensors.length&&settled)win(now);\n",
     "    if(!taps&&!over&&now-t0<4500)KIT.tell(g,'LIGHT EVERY SENSOR.',['click'],(now-t0)/1000);\n"
     "    if(!over&&lit===P.sensors.length&&settled)win(now);\n"
     "    pop.draw(g,now/1000);\n"),
    ("    over=true;won=now;\n", "    over=true;won=now;pop.finish('ALL LIT','good',now/1000);\n"),
    ("    e.preventDefault();if(over)return;", "    e.preventDefault();if(pop.click(performance.now()/1000))return;if(over)return;"),
]

SWAPS: dict[str, list[tuple[str, str]]] = {
    "coolant": COOLANT,
}
SWAPS["beams"] = BEAMS

# ---- Star Light (no controls: no deck). The tube rows take rows 36-139 (104, was 85): the pitch is
# floor(104/T), the tubes up to their 14-row cap (3-4 tubes: wider gaps; 5 tubes 12 -> 14, 6: 9 -> 12,
# 7: 7 -> 9). LINES m/n moves to the header (its value red while extras are on); the MATCH meter shrinks to
# fit the widest right side (n/n and a two-digit SWITCHES) and its percentage goes. n EXTRA is a toast when
# a wrong tube goes on; MATCH! (and NO POWER, a budget sector's end) go on the result card.
SPECTRUM = [
    ("ROW=Math.floor(85/T),TY=36+((85-T*ROW)>>1),H=130,",
     "ROW=Math.floor(104/T),TY=36+((104-T*ROW)>>1),H=140,"),
    ("  let on=0,over=false,toggles=0,won=0,AC=null;const t0=performance.now();\n",
     "  let on=0,over=false,toggles=0,won=0,AC=null;const t0=performance.now();const pop=TK.KIT.popups(ctx);\n"
     "  const extrasOf=m=>{let k=0;for(let bn=0;bn<BINS;bn++)if(((m>>bn)&1)&&!((P.target>>bn)&1))k++;return k};\n"),
    ("    {const KIT=TK.KIT,full=frac===1&&!extras;\n"
     "      KIT.header(g,{label:'MATCH',meter:{w:53,frac,kind:full?'good':'neutral'},value:Math.round(frac*100)+'%',vkind:full?'good':null},\n"
     "        c.budget?[['PWR',power,power<=1?'bad':null]]:[['SWITCHES',toggles]])}\n",
     "    {const KIT=TK.KIT,full=frac===1&&!extras,n=tgt.length,mw=44-(String(n).length*8+3);\n"
     "      KIT.header(g,{label:'MATCH',meter:{w:mw,frac,kind:full?'good':'neutral'}},\n"
     "        [['LINES',matched+'/'+n,extras?'bad':matched===n?'good':null]].concat(c.budget?[['PWR',power,power<=1?'bad':null]]:[['SWITCHES',toggles]]))}\n"),
    ("    // the kit deck: status line only (the tubes are the controls)\n"
     "    {const KIT=TK.KIT;KIT.deck(g,false);\n"
     "      if(won)KIT.status(g,'MATCH!','good',false);\n"
     "      else if(over)KIT.status(g,'NO MATCH','bad',false);\n"
     "      else if(power<=0)KIT.status(g,'NO POWER','bad',false);\n"
     "      else if(toggles){const parts=[['LINES '+matched+'/'+tgt.length,matched===tgt.length?'good':'neutral']];if(extras)parts.push([extras+' EXTRA','bad']);KIT.status(g,parts,null,false)}}\n"
     "\n"
     "    if(!toggles&&!over)TK.KIT.tell(g,'MATCH THE STAR.',['click'],(now-t0)/1000);\n",
     "    if(!toggles&&!over)TK.KIT.tell(g,'MATCH THE STAR.',['click'],(now-t0)/1000);\n"
     "    pop.draw(g,now/1000);\n"),
    ("    if(power<=0)return;\n    on^=1<<i;",
     "    if(power<=0)return;\n    const xb=extrasOf(union(P.tray,on));\n    on^=1<<i;"),
    ("    tone(lit?320:200,.18,'sawtooth',.02,lit?640:100);\n",
     "    tone(lit?320:200,.18,'sawtooth',.02,lit?640:100);\n"
     "    {const xa=extrasOf(union(P.tray,on));if(lit&&xa>xb)pop.say(xa+' EXTRA','bad',now/1000)}\n"),
    ("      const secs=(now-t0)/1000;\n      ctx.done(",
     "      const secs=(now-t0)/1000;pop.finish('MATCH!','good',now/1000);\n      ctx.done("),
    ("      over=true;ctx.done({score:0.2*",
     "      over=true;pop.finish('NO POWER','bad',now/1000);ctx.done({score:0.2*"),
    ("    e.preventDefault();const q=pix.pt(e);",
     "    e.preventDefault();if(pop.click(performance.now()/1000))return;const q=pix.pt(e);"),
]
SWAPS["spectrum"] = SPECTRUM

# ---- Four Kelvin (controls: the deck's rule on 116). The belt grows 82 -> 100 rows (rows 10-109; the
# progress bar 112-113), world 1:1; rocks are dealt per area (dens x BH/82), so the belt is no emptier.
# IMPACT / BELT CLEAR go on the result card when the run ends (no live words; the WARNING: ROCK tag
# stays in the view). The page keeps drawing after the end only for the card (the run is frozen, as in Godot).
FOURKELVIN = [
    ("const W=150,H=130,GENW=140,VY=10,BH=82,SHIPX=46,DT=1/30,KIT=TK.KIT;   // view: kit header 0-9, belt rows 10-91, progress bar 94-95, kit deck 98-129",
     "const W=150,H=140,GENW=140,VY=10,BH=100,SHIPX=46,DT=1/30,KIT=TK.KIT;   // view: kit header 0-9, belt rows 10-109, progress bar 112-113, kit deck 116-139 (A)"),
    ("const rocks=[];const want=Math.round(c.dens*len/1000);",
     "const rocks=[];const want=Math.round(c.dens*len/1000*BH/82);"),
    ("    const F=gen(ctx.rng,ctx.depth),sens=ctx.sensors|0,rng=ctx.rng;\n",
     "    const F=gen(ctx.rng,ctx.depth),sens=ctx.sensors|0,rng=ctx.rng;const pop=KIT.popups(ctx);\n"),
    ("      if(fired)return;fired=true;\n",
     "      if(fired)return;fired=true;pop.finish(crashed?'IMPACT':'BELT CLEAR',crashed?'bad':'good',performance.now()/1000);\n"),
    ("      if(mode==='ready')KIT.tell(g,'FLY THE SHIP.',['keys:WAD'],clock);\n"
     "      else if(mode==='end'){intentTag();\n"
     "        if(endT>(crashed?1:0.5))KIT.status(g,crashed?'IMPACT':'BELT CLEAR',crashed?'bad':'good',true)}\n",
     "      if(mode==='ready')KIT.tell(g,'FLY THE SHIP.',['keys:WAD'],clock,{y:KIT.ROW.TELL.top});\n"
     "      else if(mode==='end')intentTag();\n"
     "      pop.draw(g,performance.now()/1000);\n"),
    ("      if(!last)last=now;acc+=Math.min(0.25,(now-last)/1000);last=now;\n"
     "      while(acc>=DT){update();acc-=DT}\n"
     "      render();\n"
     "      if(!fired)raf=requestAnimationFrame(frame);\n",
     "      if(!last)last=now;acc+=Math.min(0.25,(now-last)/1000);last=now;\n"
     "      if(!fired)while(acc>=DT){update();acc-=DT}\n"
     "      render();\n"
     "      if(!fired||pop.endTx!=null&&!pop.left)raf=requestAnimationFrame(frame);\n"),
    ("    const pdown=e=>{e.preventDefault();",
     "    const pdown=e=>{e.preventDefault();if(pop.click(performance.now()/1000))return;"),
]
SWAPS["fourkelvin"] = FOURKELVIN

# ---- Centrifuge (no controls: no deck; play rows 10-139). The bowl is bound by the width (rows 1-105 beside
# the 40 px rack), so it keeps its size and the whole set drops 9 to the glass's middle: the hub CY 65 -> 74
# (the bowl in rows 22-126), the rack 12 -> 21, SPIN 98 -> 107. READY and SPINNING drop (SPIN turns amber;
# the rotor spins). BALANCED / WOBBLE n% / ROTOR FAULT go on the result card, 0.6 s after the game's 0.7 s.
CENTRIFUGE = [
    ("const W=150,H=130;\nconst KIT=TK.KIT;\nconst CX=53,CY=65;          // rotor hub: bowl in rows 13-117",
     "const W=150,H=140;\nconst KIT=TK.KIT;\nconst CX=53,CY=74;          // rotor hub: bowl in rows 22-126 (A: the glass's middle)"),
    ("const RACK={x:108,y:12,w:40,h:82},SPIN={x:111,y:98,w:33,h:KIT.BTN.HL};",
     "const RACK={x:108,y:21,w:40,h:82},SPIN={x:111,y:107,w:33,h:KIT.BTN.HL};"),
    ("  const fixed=new Set();\n", "  const fixed=new Set();const pop=KIT.popups(ctx,{delay:1.3});\n"),
    ("    KIT.deck(g,false);\n"
     "    if(!acted&&!over)KIT.tell(g,'BALANCE THE TUBES.',['click','drag'],(performance.now()-t0)/1000);\n"
     "    else KIT.status(g,msgTxt,msgCol===PAL.good?'good':msgCol===PAL.bad?'bad':'neutral',false);\n"
     "    // a tube in your hand\n"
     "    if(drag&&drag.moved)tubeSide(drag.x-3,drag.y-7,drag.m,true);\n",
     "    if(!acted&&!over)KIT.tell(g,'BALANCE THE TUBES.',['click','drag'],(performance.now()-t0)/1000);\n"
     "    // a tube in your hand\n"
     "    if(drag&&drag.moved)tubeSide(drag.x-3,drag.y-7,drag.m,true);\n"
     "    pop.draw(g,performance.now()/1000);\n"),
    ("msgCol=r<1e-6?PAL.good:r>0.3?PAL.bad:PAL.warn;",
     "msgCol=r<1e-6?PAL.good:r>0.3?PAL.bad:PAL.warn;pop.finish(msgTxt,r<1e-6?'good':r>0.3?'bad':'neutral',performance.now()/1000);"),
    ("  function down(e){\n    if(over||spinning)return;",
     "  function down(e){\n    if(pop.click(performance.now()/1000))return;\n    if(over||spinning)return;"),
]
SWAPS["centrifuge"] = CENTRIFUGE

# ---- Ice Core (controls: the deck's rule 98 -> 116, play rows 10-115, +18). Core layers 8 -> 10 rows (the
# tallest core, 4 layers, still tops out at row 18), so the cores' foot CB 53 -> 61 and the two rule notes
# follow; the tray's sockets 18x10 -> 18x12 on a 16 row pitch (rows 83-110); the tube's 88 rows of slots,
# 11 px (a 10-row layer, the cores' own) up to 8 layers, 9 at 9, 8 at 10, foot SB 89 -> 108 (OLD rows 111-115).
# n/N IN PLACE after a CHECK is a toast (the ticks and crosses stay); ORDER CONFIRMED, or n/N IN PLACE on the
# last check, is the card, 0.6 s after the game's own wait.
ICECORE = [
    ("const W=150,H=130;\n// each layer kind", "const W=150,H=140;\n// each layer kind"),
    ("const CX0=17,CDX=18,CW=14,LH=8,GH=5,CB=53;", "const CX0=17,CDX=18,CW=14,LH=10,GH=5,CB=61;"),
    ("const SX=113,SW=26,SB=89;", "const SX=113,SW=26,SB=108;"),
    ("const PX0=4,PDX=20,PW=18,PHh=10,PY0=73,PDY=13;", "const PX0=4,PDX=20,PW=18,PHh=12,PY0=83,PDY=16;"),
    ("  const SH=Math.min(9,Math.floor(70/n)); // the tube's 70 rows of slots",
     "  const SH=Math.min(11,Math.floor(88/n)); // the tube's 88 rows of slots (A)\n"
     "  const pop=KIT.popups(ctx,{delay:.09*n+1.1});"),
    ("    const m=msg;\n    if(m)KIT.status(g,m,finished?(winAt?'good':'bad'):'neutral',true);\n"
     "    if(!acted&&!m)KIT.tell(g,'STACK THE LAYERS IN ORDER.',['drag'],now/1000);",
     "    if(!acted)KIT.tell(g,'STACK THE LAYERS IN ORDER.',['drag'],now/1000);"),
    ("layer(drag.kind,x,y,w,h,.08)}\n  }", "layer(drag.kind,x,y,w,h,.08)}\n    pop.draw(g,now/1000);\n  }"),
    ("msg='ORDER CONFIRMED';", "msg='ORDER CONFIRMED';pop.finish(msg,'good',performance.now()/1000);"),
    ("    msg=`${right}/${n} IN PLACE`;\n    if(used>=checks){finished=true;",
     "    msg=`${right}/${n} IN PLACE`;pop.say(msg,'neutral',performance.now()/1000);\n"
     "    if(used>=checks){finished=true;pop.delay=1.5;pop.finish(msg,'bad',performance.now()/1000);"),
    ("  function down(e){\n    if(finished)return;",
     "  function down(e){\n    if(pop.click(performance.now()/1000))return;\n    if(finished)return;"),
]
SWAPS["icecore"] = ICECORE

# ---- Sample Tray (no controls: no deck; play rows 10-139). Cells 17 -> 18 px (fit4's size; canisters 15 -> 16
# across): the tray in rows 10-125 (rim 2-117 across). UNDO n (33 x 13) leaves the right column for the foot
# of it, under the rim with a row clear (rows 127-139). SAMPLE OUT goes on the result card; no live words.
TRAY = [
    ("const W=150,H=130,C=17,GX=6,GY=14;     // 6x6 cells of 17 art px: the tray in rows 10-119",
     "const W=150,H=140,C=18,GX=6,GY=14;     // 6x6 cells of 18 art px: the tray in rows 10-125 (A)"),
    ("const UB={x:KIT.W-KIT.GUT-33,y:106,w:33,h:KIT.BTN.H}; // over GIVE UP",
     "const UB={x:KIT.W-KIT.GUT-33,y:127,w:33,h:KIT.BTN.H}; // the foot of the right column, a row under the rim"),
    ("  KIT.deck(b,false);\n", ""),
    ("    if(outT>=0&&clock-outT>1)KIT.status(g,'SAMPLE OUT','good',false);\n", ""),
    ("    if(!started)KIT.tell(g,'GET THE SAMPLE OUT.',CONTROLS,clock);\n",
     "    if(!started)KIT.tell(g,'GET THE SAMPLE OUT.',CONTROLS,clock,{y:KIT.ROW.TELL.top});\n    pop.draw(g,clock);\n"),
    ("  const hist=[];", "  const hist=[];const pop=KIT.popups(ctx);"),
    ("outT=clock+.05;", "outT=clock+.05;pop.finish('SAMPLE OUT','good',clock);"),
    ("  p.cv.addEventListener('pointerdown',e=>{\n    if(over)return;",
     "  p.cv.addEventListener('pointerdown',e=>{\n    if(pop.click(clock))return;\n    if(over)return;"),
]
SWAPS["tray"] = TRAY

# ---- Signal Tuning (controls: the deck's rule 98 -> 116; it keeps its own knobs, r 7). The knobs sit on the
# control row's centre (KY 116 -> 128): their ticks fill rows 117-139, the lit 180 deg tick too. The two 74 px
# scopes are bound by the width (two side by side fill it), so they keep their size and drop 9 to the middle
# of rows 10-115 (labels row 23, glass 29-102). The knob values (X 2  Y 3  PH 90 ...) drop: a right dial wears
# its green collar and YOURS draws the value. MATCH! / NO MATCH go on the result card; no live words.
TUNING = [
    ("const PW=150,PH=130;", "const PW=150,PH=140;"),
    ("const SY=20,SS=74,R=32,HS=SS>>1;", "const SY=29,SS=74,R=32,HS=SS>>1;"),
    ("const KY=KIT.ROW.CTRL.cy-2,KR=7; // knob centre row (2 above the control row's), knob radius: ticks reach rows 105-127 (the lit 180 deg tick too), 4 rows clear of the haul line (Jon, Nov 20)",
     "const KY=KIT.ROW.CTRL.cy,KR=7; // knob centre row (the control row's), knob radius: ticks fill rows 117-139 (the lit 180 deg tick too)"),
    ("const LOCK={x:KIT.W-KIT.GUT-25,y:KIT.BTN.YS,w:25,h:KIT.BTN.H}; // right edge on GIVE UP's",
     "const LOCK={x:KIT.W-KIT.GUT-25,y:KIT.BTN.YS,w:25,h:KIT.BTN.H}; // right edge on the gutter"),
    ("    if(finished)KIT.status(G,d<MATCH?'MATCH!':'NO MATCH',d<MATCH?'good':'bad',true);\n"
     "    else KIT.status(G,knobs.map(k=>[k.lab+' '+k.fmt(cur[k.key]),isRight(k)?'good':'neutral']),null,true);\n"
     "    if(!acted&&!finished)KIT.tell(G,'MATCH THE WAVE.',['dial','click'],(now-t0)/1000);\n",
     "    if(!acted&&!finished)KIT.tell(G,'MATCH THE WAVE.',['dial','click'],(now-t0)/1000);\n"
     "    pop.draw(G,now/1000);\n"),
    ("  let drag=null,lastFrame=0,acted=false;", "  let drag=null,lastFrame=0,acted=false;const pop=KIT.popups(ctx,{delay:1.3});"),
    ("    TK.sfx('tuning2','lock');const sc=score(d,taps,parNow,free);",
     "    pop.finish(d<MATCH?'MATCH!':'NO MATCH',d<MATCH?'good':'bad',performance.now()/1000);\n"
     "    TK.sfx('tuning2','lock');const sc=score(d,taps,parNow,free);"),
    ("  function down(e){\n    if(finished)return;const q=p.pt(e);",
     "  function down(e){\n    if(pop.click(performance.now()/1000))return;\n    if(finished)return;const q=p.pt(e);"),
]
SWAPS["tuning"] = TUNING


# ---- The three 152-wide camera games (the kit drawn 1 px in on a 150-wide layer): each camera view runs
# under the deck's rule at 116 (it ran to the old deck at 98): +18 rows. A say() of 99 s was an END word:
# it goes on the result card (pop.finish); every other say() is a toast (pop.say). warn (EMPTY PIECE,
# CARGO SHIFT) is a neutral toast, as the status line drew it. pop draws last, on the kit's layer.
def _say_pop(secs: str, clock: str) -> str:
    return ("{const k=c===A.good?'good':c===A.bad?'bad':'neutral';"
            "if((%s)>=99)pop.finish(t,k,%s);else pop.say(t,k,%s)}") % (secs, clock, clock)


# Cutting Torch: the wreck plate is 304x232 sim units (152x116 art px, was 200 / 100): the crate, the lines
# and the gaps keep their sizes, the plate they lie on is 16 px taller. GAS and HITS stay in the control
# row. ZAP! LIVE LINE, FUEL LINE!, CRATE BURNT, EMPTY PIECE are toasts; CUT FREE / OUT OF GAS / TORCH OUT
# go on the card.
TORCH = [
    ("const W=304,H=200;      // sim units: two per art pixel",
     "const W=304,H=232;      // sim units: two per art pixel (A: the camera runs to the deck's rule, row 116)"),
    ("const PW=W/2,PH=H/2,HUD=30;          // art pixels: the camera view is 152x100, the HUD strip 16 rows",
     "const PW=W/2,PH=H/2,HUD=24;          // art pixels: the camera view is 152x116, the control rows 24"),
    ("  function say(t,c,secs){status=t;statusCol=c;statusT=secs||2.5}",
     "  const pop=TK.KIT.popups(ctx);\n  function say(t,c,secs)" + _say_pop("secs||2.5", "S.t")),
    ("  function onDown(e){\n    if(S.over)return;e.preventDefault();try{px.cv.setPointerCapture(e.pointerId)}catch(_){}",
     "  function onDown(e){\n    if(pop.click(S.t))return;\n    if(S.over)return;e.preventDefault();try{px.cv.setPointerCapture(e.pointerId)}catch(_){}"),
    ("[[1,11,1,1],[PW-2,11,-1,1],[1,96,1,-1],[PW-2,96,-1,-1]])for(let i=0;i<5;i++){put(g,x+dx*i,y,M[6]);put(g,x,y+dy*i,M[6])}\n"
     "    // the kit: header over the camera's top rows; deck (status line, GAS + HITS meters) over its foot",
     "[[1,11,1,1],[PW-2,11,-1,1],[1,PH-4,1,-1],[PW-2,PH-4,-1,-1]])for(let i=0;i<5;i++){put(g,x+dx*i,y,M[6]);put(g,x,y+dy*i,M[6])}\n"
     "    // the kit: header over the camera's top rows; deck (GAS + HITS meters) under its foot; the toast last"),
    ("      if((statusT>0||S.over)&&status)K.status(g,status,statusCol===A.bad?'bad':statusCol===A.good?'good':'neutral',true);\n"
     "      g.restore()}",
     "      pop.draw(g,t);\n      g.restore()}"),
]
SWAPS["torch"] = TORCH

# Leak Hunt: the drone's room is 116 rows (was 98) and its view VH 110 (was 92). The back wall is 18 rows
# taller: the consoles, the chair and the floor (20 rows, as before) move down 18, and the leaks' band (the
# back wall above the consoles) runs 18 further down with it (RY1 70 -> 88); a tap on the floor (96+) still
# does nothing. Leak count, pull, tolerance, smoke, air and patches are as they were. AIR, SMOKE and PATCH
# stay in the control row. ONE SEALED / STILL LEAKING are toasts; SEALED / AIR GONE / NO PATCHES the card.
LEAK = [
    ("const RX0=6,RX1=146,RY0=10,RY1=70;      // where a leak can be (the back wall above the consoles)",
     "const RX0=6,RX1=146,RY0=10,RY1=88;      // where a leak can be (the back wall above the consoles; A: 70 -> 88)"),
    ("    else if(y>=78){c=((x+(y>>1))%4===0||y===78)?1:2;if(y===79)c=4}   // floor grating",
     "    else if(y>=96){c=((x+(y>>1))%4===0||y===96)?1:2;if(y===97)c=4}   // floor grating"),
    ("for(let y=66;y<78;y++)for(let x=cx;x<cx+w;x++){const e=x===cx||y===66||x===cx+w-1;put(s,x,y,e?(y===66||x===cx?M[6]:M[0]):(y<69?M[5]:M[3]))}",
     "for(let y=84;y<96;y++)for(let x=cx;x<cx+w;x++){const e=x===cx||y===84||x===cx+w-1;put(s,x,y,e?(y===84||x===cx?M[6]:M[0]):(y<87?M[5]:M[3]))}"),
    ("for(let x=cx+3;x<cx+w-3;x+=4)put(s,x,68,", "for(let x=cx+3;x<cx+w-3;x+=4)put(s,x,86,"),
    ("  for(let i=0;i<7;i++){put(s,60+i,74-Math.floor(i/2),M[5]);put(s,60+i,75-Math.floor(i/2),M[0])}for(let y=0;y<5;y++){put(s,60,70+y,M[5]);put(s,66,71+y,M[4])}",
     "  for(let i=0;i<7;i++){put(s,60+i,92-Math.floor(i/2),M[5]);put(s,60+i,93-Math.floor(i/2),M[0])}for(let y=0;y<5;y++){put(s,60,88+y,M[5]);put(s,66,89+y,M[4])}"),
    ("    if(y<TK.KIT.ROW.PLAY.y||y>=78)return;", "    if(y<TK.KIT.ROW.PLAY.y||y>=96)return;"),
    ("if(j.y<11||j.y>72){j.vy*=-1;j.y=clamp(j.y,11,72)}", "if(j.y<11||j.y>90){j.vy*=-1;j.y=clamp(j.y,11,90)}"),
    ("const PW=152,VH=92,HUD=38,PH=VH+HUD;   // art pixels: the drone's view of the room, then the control strip",
     "const PW=152,VH=110,HUD=30,PH=VH+HUD;  // art pixels: the drone's view of the room, then the control rows (A)"),
    ("st.width=PW;st.height=98;const s=st.getContext('2d');", "st.width=PW;st.height=116;const s=st.getContext('2d');"),
    ("  for(let y=0;y<98;y++)for(let x=0;x<PW;x++){", "  for(let y=0;y<116;y++)for(let x=0;x<PW;x++){"),
    ("  function say(t,c,sec){status=t;statusCol=c;statusT=sec||2}",
     "  const pop=TK.KIT.popups(ctx);\n  function say(t,c,sec)" + _say_pop("sec||2", "S.t")),
    ("  function onDown(e){\n    if(S.over)return;e.preventDefault();const[x,y]=toArt(e);",
     "  function onDown(e){\n    if(pop.click(S.t))return;\n    if(S.over)return;e.preventDefault();const[x,y]=toArt(e);"),
    ("[[1,11,1,1],[PW-2,11,-1,1],[1,96,1,-1],[PW-2,96,-1,-1]])for(let i=0;i<5;i++){put(g,x+dx*i,y,M[6]);put(g,x,y+dy*i,M[6])}\n"
     "    if(mode==='patch'&&!S.over){for(let x=2;x<PW-2;x++){if(bt(x,0)<0.5){put(g,x,11,A.ember);put(g,x,96,A.ember)}}}",
     "[[1,11,1,1],[PW-2,11,-1,1],[1,VH+4,1,-1],[PW-2,VH+4,-1,-1]])for(let i=0;i<5;i++){put(g,x+dx*i,y,M[6]);put(g,x,y+dy*i,M[6])}\n"
     "    if(mode==='patch'&&!S.over){for(let x=2;x<PW-2;x++){if(bt(x,0)<0.5){put(g,x,11,A.ember);put(g,x,VH+4,A.ember)}}}"),
    ("      if(statusT>0||S.over)K.status(g,status,statusCol===A.good?'good':statusCol===A.bad?'bad':'neutral',true);\n"
     "      g.restore()}",
     "      pop.draw(g,t);\n      g.restore()}"),
]
SWAPS["leak"] = LEAK

# Tumble Dock: the camera view is 116 rows (VH 98 -> 116, the control rows 32 -> 24) and the spin centre
# drops 9 (CY 52 -> 61), half the gain, as the mock's 4 of 8. SPIN n / DRIFT n / STILL drop (the spin arc
# and the drift arrow turn green when slow enough; STILL is the bracket with no arrow). TOO FAST is a toast
# each time the wreck comes in too fast; NO GAS and CARGO SHIFT are toasts; DOCKED / WINDOW LOST / OUT OF
# GAS go on the card.
DOCK = [
    ("const PW=152,VH=98,HUD=32,PH=VH+HUD;", "const PW=152,VH=116,HUD=24,PH=VH+HUD;"),
    ("const CX=PW/2,CY=52,PR=WR.hh+2;", "const CX=PW/2,CY=61,PR=WR.hh+2;"),
    ("  function say(t,c,s){status=t;statusCol=c;statusT=s||2}",
     "  const pop=TK.KIT.popups(ctx);let wasNear=false;\n  function say(t,c,s)" + _say_pop("s||2", "performance.now()/1000")),
    ("  function onDown(e){\n    if(S.over)return;e.preventDefault();\n    const p=px.pt(e);",
     "  function onDown(e){\n    if(pop.click(performance.now()/1000))return;\n    if(S.over)return;e.preventDefault();\n    const p=px.pt(e);"),
    ("      if(S.t>=6||S.used)rd.push(['SPIN '+Math.abs(S.wk),sl?'good':'neutral']);\n", ""),
    ("      if(S.t>=6||S.used)rd.push(['STILL','good']);\n", ""),
    (";\n      if(S.t>=6||S.used)rd.push(['DRIFT '+Math.abs(S.vk),dc===A.good?'good':'neutral'])}", "}"),
    # TOO FAST only when the port is in the bracket and the clamp did not grab it (it was too fast): the
    # status line said it whenever the port was close, which every slow approach is too
    ("    if(near)rd.push(['TOO FAST','bad']);\n",
     "    {const fast=near&&placed(S,P);if(fast&&!wasNear)pop.say('TOO FAST','bad',now);wasNear=fast}\n"),
    ("KT.tell(g,'STOP IT UNDER THE CLAMP.',['click'],now);", "KT.tell(g,'STOP IT UNDER THE CLAMP.',['click'],now,{y:KT.ROW.TELL.high});"),
    ("      if(statusT>0||S.over)KT.status(g,status,statusCol===A.good?'good':statusCol===A.bad?'bad':'neutral',true);\n"
     "      else if(rd.length)KT.status(g,rd,null,true);\n"
     "      for(const b of B)button(b,now);\n      g.restore()}",
     "      for(const b of B)button(b,now);\n      pop.draw(g,now);\n      g.restore()}"),
]
SWAPS["dock"] = DOCK

# ---- Pulsar Fold (its own deck; +10 rows to the glass). Its 29 px dial KEEPS r 14 (Jon); the deck moves down
# the 10 freed rows whole (rule 95 -> 105, dial centre 112 -> 122, LOCK 104 -> 114, strip 120 -> 130), so
# the dial's ring sits on rows 107-137. The phosphor glass grows to rows 11-103: the waterfall 45 -> 55 rows,
# the profile drops 10. NO LOCK / WEAK (and LOCKED on the first of two) are toasts; LOCKED / WEAK / LOST at
# the end is the card.
PULSAR = [
    ("const W=150,H=130;\nconst CONTROLS=['dial'];", "const W=150,H=140;\nconst CONTROLS=['dial'];"),
    ("const RAWY=14,RAWH=13,WFY=29,WFH=45,PRY=75,PRH=16;", "const RAWY=14,RAWH=13,WFY=29,WFH=55,PRY=85,PRH=16;"),
    ("const KIT=TK.KIT,DECK=95; // the deck's rule: 3 rows above the kit's 98, to hold Pulsar's own 31 px dial",
     "const KIT=TK.KIT,DECK=105; // the deck's rule: its own, 11 rows above the kit's 116, to hold Pulsar's own 29 px dial"),
    ("const DX=KIT.GUT+15,DY=112,DR=14; // r 14 (was 15), raised 1: its foot on row 127, 4 rows clear of the haul line (Jon, Nov 20)",
     "const DX=KIT.GUT+15,DY=122,DR=14; // r 14 (Jon, Nov 20: kept), its ring on rows 107-137"),
    ("const SX=DX+DR+7,SW=104,SY=120;", "const SX=DX+DR+7,SW=104,SY=130;"),
    ("const LB={x:KIT.W-KIT.GUT-33,y:104,w:33,h:KIT.BTN.H}; // over GIVE UP",
     "const LB={x:KIT.W-KIT.GUT-33,y:114,w:33,h:KIT.BTN.H};"),
    ("b.fillRect(1,11,1,82);b.fillStyle=PAL.bevelLo;b.fillRect(1,93,W-2,1);b.fillRect(W-2,11,1,83);\n"
     "  b.fillStyle='#06110b';b.fillRect(3,13,W-6,79);",
     "b.fillRect(1,11,1,92);b.fillStyle=PAL.bevelLo;b.fillRect(1,103,W-2,1);b.fillRect(W-2,11,1,93);\n"
     "  b.fillStyle='#06110b';b.fillRect(3,13,W-6,89);"),
    ("const locks=[],timers=[];let misses=0;", "const locks=[],timers=[];let misses=0;const pop=KIT.popups(ctx);"),
    ("    if(stampTxt&&clock<stampT){const k=stampTxt==='LOCKED'?'good':stampTxt==='NO LOCK'||stampTxt==='LOST'?'bad':'neutral';"
     "TK.text(g,stampTxt,(W>>1)-((stampTxt.length*4-1)>>1),DECK+KIT.ROW.STATUS_TY,KIT.KIND[k].text)}\n", ""),
    ("KIT.button(g,LB.x,LB.y,LB.w,LB.h,'LOCK',finished?'disabled':hot?(pressed?'active-pressed':'active'):(pressed?'pressed':'normal'));",
     "KIT.button(g,LB.x,LB.y,LB.w,LB.h,'LOCK',finished?'disabled':hot?(pressed?'active-pressed':'active'):(pressed?'pressed':'normal'));\n"
     "    pop.draw(g,clock);"),
    ("stampTxt='NO LOCK';stampT=clock+1;", "stampTxt='NO LOCK';stampT=clock+1;pop.say('NO LOCK','bad',clock);"),
    ("stampTxt=pa>=.7?'LOCKED':'WEAK';stampT=clock+1.2;",
     "stampTxt=pa>=.7?'LOCKED':'WEAK';stampT=clock+1.2;pop.say(stampTxt,pa>=.7?'good':'neutral',clock);"),
    ("finished=true;msg='';TK.sfx('pulsar2','win');",
     "finished=true;msg='';TK.sfx('pulsar2','win');pop.finish(stampTxt,stampTxt==='LOCKED'?'good':'neutral',clock);"),
    ("stampTxt='LOST';stampT=clock+99;", "stampTxt='LOST';stampT=clock+99;pop.finish('LOST','bad',clock);"),
    ("if(finished)return;const q=ptf(e);if(q.y<DECK)return;started=true;",
     "if(pop.click(clock))return;if(finished)return;const q=ptf(e);if(q.y<DECK)return;started=true;"),
]

# ---- Anomaly Count (no deck; play rows 10-139). The lens goes back to its prototype size (r 55, critters x1.7)
# centred in the play rows (centre row 75: lens and bezel rows 17-132, 7 rows clear above and below). The rule
# is a STANDING readout in the bottom corners the round lens leaves free, one term a line in goal blue (blinking
# when it changes, as before): the rule's first line bottom-left, an OR line bottom-right under a neutral OR,
# the last text on rows 133-137. WRONG is a toast on a wrong pick (the mock's). ALL LOGGED / TIME UP is the card.
ANOMALY = [
    ("const W=150,H=130,CX=75,CY=65,LENS=52,PS=LENS/52,KIT=TK.KIT;", "const W=150,H=140,CX=75,CY=75,LENS=55,PS=LENS/52,KIT=TK.KIT;"),
    ("const K=1.6;", "const K=1.7;"),
    ("const SP=35,SH=17;", "const SP=37,SH=18;"),
    ("    KIT.deck(g,false);\n"
     "    if(finished){const all=found===total;KIT.status(g,all?'ALL LOGGED':'TIME UP',all?'good':'bad',false);return}\n"
     "    let lines=ruleText(pz.rules[phase]);const room=W-2*KIT.GUT,len=ls=>ls.join(' OR ').length*4-1;\n"
     "    if(len(lines)>room)lines=lines.map(l=>l.split(' + ').join('+'));\n"
     "    const fl=clock-ruleFlash<1.2&&Math.floor(clock*5)%2===0,col=fl?PAL.ice:KIT.KIND.goal.text,y=KIT.deckY(false)+KIT.ROW.STATUS_TY;\n"
     "    let x=(W>>1)-(len(lines)>>1);\n"
     "    lines.forEach((l,i)=>{if(i){TK.text(g,'OR',x+4,y,KIT.KIND.neutral.text);x+=16}TK.text(g,l,x,y,col);x+=l.length*4});\n",
     "    if(finished)return;\n"
     "    // the rule in the corners the lens leaves free: one term a line, '+' before the 2nd and 3rd\n"
     "    const terms=pz.rules[phase].terms.map(t=>t.map(c=>word(c.k,c.v)));\n"
     "    const fl=clock-ruleFlash<1.2&&Math.floor(clock*5)%2===0,col=fl?PAL.ice:KIT.KIND.goal.text,YB=H-7;\n"
     "    const block=(ts,right)=>{const rows=ts.map((s,i)=>(i?'+':'')+s);if(right)rows.unshift('OR');\n"
     "      rows.forEach((s,i)=>{const y=YB-(rows.length-1-i)*6,x=right?W-KIT.GUT-(s.length*4-1):KIT.GUT;\n"
     "        TK.text(g,s,x,y,right&&i===0?KIT.KIND.neutral.text:col)})};\n"
     "    block(terms[0],false);if(terms[1])block(terms[1],true);\n"),
    ("ruleFlash=-9;", "ruleFlash=-9;const pop=KIT.popups(ctx);"),
    ("    drawLoupe();\n  }\n  function step(dt){", "    drawLoupe();\n    pop.draw(g,clock);\n  }\n  function step(dt){"),
    ("}else{wrong++;fx.push({i,t0:clock,life:1.1,bad:true})}", "}else{wrong++;fx.push({i,t0:clock,life:1.1,bad:true});pop.say('WRONG','bad',clock)}"),
    ("    if(finished)return;finished=true;\n    ctx.done(",
     "    if(finished)return;finished=true;pop.finish(found===total?'ALL LOGGED':'TIME UP',found===total?'good':'bad',clock);\n    ctx.done("),
    ("  p.cv.addEventListener('pointerdown',e=>{\n    if(finished)return;",
     "  p.cv.addEventListener('pointerdown',e=>{\n    if(pop.click(clock))return;\n    if(finished)return;"),
]

# ---- Gravity Sling (its own deck). The dial KEEPS r 13 and the sling its pull (Jon); the field grows to the
# whole width at the scale the width allows (0.1375 -> 0.15: 138x88 -> 150x96, rows 10-105, no side borders),
# the deck's rule drops 98 -> 106 and its 34 rows hold the dial and the sling as before, 1 row lower in the deck
# so they sit centred (dial rows 110-136, fork 115-136). The greyed-out deck after a launch stays. TOO WEAK,
# MISS n, IMPACT, NO-FLY are toasts; HIT / OUT OF PROBES is the card; LAST n stays in the header.
SLING = [
    ("const KIT=TK.KIT,W=150,H=130,FY=98,FT=10,FHP=FY-FT,SC=FHP/FH,FWP=Math.ceil(FW*SC),FX=(W-FWP)>>1; // FY: the deck's rule; the field: rows 10-97, 138 x 88 art px",
     "const KIT=TK.KIT,W=150,H=140,FY=106,FT=10,FHP=FY-FT,SC=FHP/FH,FWP=Math.ceil(FW*SC),FX=(W-FWP)>>1; // FY: the deck's rule; the field: rows 10-105, 150 x 96 art px (scale 0.15)"),
    ("const DX=KIT.GUT+13,DY=114,DRAD=13;", "const DX=KIT.GUT+13,DY=FY+17,DRAD=13;"),
    ("const FKX=142,RY=FY+16,PULLMAX=72;", "const FKX=142,RY=FY+17,PULLMAX=72;"),
    ("line(d,FKX+3,29,FKX+3,18,PAL.bevelLo);line(d,FKX+4,29,FKX+4,18,PAL.cold);\n"
     "  line(d,FKX+3,18,FKX,8,PAL.cold);line(d,FKX+4,18,FKX+1,8,PAL.chill);\n"
     "  line(d,FKX+3,18,FKX,25,PAL.cold);line(d,FKX+4,18,FKX+1,25,PAL.bevelLo);",
     "line(d,FKX+3,30,FKX+3,19,PAL.bevelLo);line(d,FKX+4,30,FKX+4,19,PAL.cold);\n"
     "  line(d,FKX+3,19,FKX,9,PAL.cold);line(d,FKX+4,19,FKX+1,9,PAL.chill);\n"
     "  line(d,FKX+3,19,FKX,26,PAL.cold);line(d,FKX+4,19,FKX+1,26,PAL.bevelLo);"),
    ("dot(d,x,28,k%5===0?PAL.chill:PAL.line);if(k%5===0)dot(d,x,27,PAL.chill)",
     "dot(d,x,29,k%5===0?PAL.chill:PAL.line);if(k%5===0)dot(d,x,28,PAL.chill)"),
    ("line(g,FKX,FY+8,PX-1,PY-2,band);line(g,FKX,FY+25,PX-1,PY+2,band);",
     "line(g,FKX,FY+9,PX-1,PY-2,band);line(g,FKX,FY+26,PX-1,PY+2,band);"),
    ("g.fillRect(lx-1,FY+25,3,1);dot(g,lx,FY+24,PAL.t2)", "g.fillRect(lx-1,FY+26,3,1);dot(g,lx,FY+25,PAL.t2)"),
    ("    {let s=null,k=null;if(note&&clock<noteT){s=note;k=note==='OUT OF PROBES'?'bad':'neutral'}\n"
     "      else if(missTxt){s=missTxt;k=missTxt==='HIT'?'good':missTxt==='IMPACT'||missTxt==='NO-FLY'?'bad':'neutral'}\n"
     "      KIT.status(g,s,k,true)}\n",
     "    pop.draw(g,clock);\n"),
    ("  const old=[];\n", "  const old=[];const pop=KIT.popups(ctx);\n"),
    ("if(off>3){note='TOO WEAK';noteT=clock+1.2}", "if(off>3){note='TOO WEAK';noteT=clock+1.2;pop.say('TOO WEAK','neutral',clock)}"),
    ("if(hit){over=true;missTxt='HIT';", "if(hit){over=true;missTxt='HIT';pop.finish('HIT','good',clock);"),
    ("missTxt=r.end==='crash'?'IMPACT':r.end==='zone'?'NO-FLY':'MISS '+miss;\n",
     "missTxt=r.end==='crash'?'IMPACT':r.end==='zone'?'NO-FLY':'MISS '+miss;pop.say(missTxt,r.end==='crash'||r.end==='zone'?'bad':'neutral',clock);\n"),
    ("note='OUT OF PROBES';noteT=clock+99;", "note='OUT OF PROBES';noteT=clock+99;pop.finish('OUT OF PROBES','bad',clock);"),
    ("    if(over||flying)return;const q=ptf(e);\n    if(q.y<FY)return;started=true;",
     "    if(pop.click(clock))return;\n    if(over||flying)return;const q=ptf(e);\n    if(q.y<FY)return;started=true;"),
]
SWAPS["pulsar"] = PULSAR
SWAPS["anomaly"] = ANOMALY
SWAPS["sling"] = SLING

# ---- Core Scan (no controls: no deck). The clues and the glass are centred in rows 10-139 (automatic from
# `KIT.deckY`); the cells grow where the height bound them. FOUND: NAME / SCAN LOST go on the result card;
# no live words.
CORESCAN = [
    ("const GX=Math.floor((W-CLW-GW)/2)+CLW,GY=PY0+CLH+((AV-CLH-GW)>>1),H=130; // clues + grid + bezel in rows 10-120",
     "const GX=Math.floor((W-CLW-GW)/2)+CLW,GY=PY0+CLH+((AV-CLH-GW)>>1),H=140; // clues + grid + bezel in rows 10-139\n"
     "    const pop=KIT.popups(ctx);"),
    ("KIT.status(g,'FOUND: '+P.name,'good',false)}\n      else if(lost)KIT.status(g,'SCAN LOST','bad',false);\n"
     "      if(!touched&&now-t0<4500)KIT.tell(g,'FILL IN THE SCAN.',['click'],(now-t0)/1000);\n",
     "}\n      if(!touched&&now-t0<4500)KIT.tell(g,'FILL IN THE SCAN.',['click'],(now-t0)/1000);\n"
     "      pop.draw(g,now/1000);\n"),
    ("        over=true;lost=now;const f=found();\n",
     "        over=true;lost=now;const f=found();pop.finish('SCAN LOST','bad',now/1000);\n"),
    ("      over=true;won=now;const secs=Math.round((now-t0)/1000);\n",
     "      over=true;won=now;const secs=Math.round((now-t0)/1000);pop.finish('FOUND: '+P.name,'good',now/1000);\n"),
    ("pix.cv.addEventListener('pointerdown',e=>{e.preventDefault();",
     "pix.cv.addEventListener('pointerdown',e=>{e.preventDefault();if(pop.click(performance.now()/1000))return;"),
]
SWAPS["corescan"] = CORESCAN

# ---- Seismic Scan (no controls: no deck; rings B). The field is bound by the width (110 px beside the tool
# column), so it keeps its cells and centres in rows 10-139 (automatic). The graph screen grows 16 rows (GH
# 78 -> 94, to row 137): its five tier rows spread 11 -> 14.2 px apart. Dig results are toasts in the tier's
# ink (COMMON ... LEGENDARY), CLOSE neutral, EMPTY bad; QUIET is a toast when a scan hears nothing. ALL DUG /
# NO DIGS LEFT go on the card (STOPPED, the give-up, is the shell's GAVE UP).
SEISMIC = [
    ("FW=G*CP,W=150,H=130,", "FW=G*CP,W=150,H=140,"),
    ("GY=44,GH=78,BL=CXL+5,BR=CXL+CW-3,T0=GY+8,T1=T0+55; // right column: tools, then the graph to row 120",
     "GY=44,GH=94,BL=CXL+5,BR=CXL+CW-3,T0=GY+8,T1=T0+71; // right column: tools, then the graph to row 137"),
    ("tool='scan',over=false,busy=false,AC=null,touched=false;",
     "tool='scan',over=false,busy=false,AC=null,touched=false;const pop=KIT.popups(ctx);"),
    ("      if(!touched&&!scans.length&&now-t00<6000)KIT.tell(g,'SCAN, THEN DIG.',['click'],(now-t00)/1000);\n"
     "      if(msg)KIT.status(g,msg,msg==='ALL DUG'||TN.includes(msg)?'good':msg==='EMPTY'||msg==='NO DIGS LEFT'?'bad':'neutral',false);\n"
     "      else if(quiet)KIT.status(g,'QUIET','neutral',false);\n",
     "      if(!touched&&!scans.length&&now-t00<6000)KIT.tell(g,'SCAN, THEN DIG.',['click'],(now-t00)/1000);\n"
     "      pop.draw(g,now/1000);\n"),
    ("      if(!p.out.length)tone(140,.2,'sine',.03);\n",
     "      if(!p.out.length){tone(140,.2,'sine',.03);pop.say('QUIET','neutral',performance.now()/1000)}\n"),
    ("msg=TN[q.t];msgCol=TC[q.t];", "msg=TN[q.t];msgCol=TC[q.t];pop.say(TN[q.t],'t'+q.t,performance.now()/1000);"),
    ("msg='CLOSE';msgCol=PAL.hot;", "msg='CLOSE';msgCol=PAL.hot;pop.say('CLOSE','neutral',performance.now()/1000);"),
    ("msg='EMPTY';msgCol=PAL.cold;", "msg='EMPTY';msgCol=PAL.cold;pop.say('EMPTY','bad',performance.now()/1000);"),
    ("      if(over)return;over=true;endGhost=true;msg=why;msgCol=PAL.hot;busy=false;\n",
     "      if(over)return;over=true;endGhost=true;msg=why;msgCol=PAL.hot;busy=false;\n"
     "      if(why!=='STOPPED')pop.finish(why,why==='ALL DUG'?'good':'bad',performance.now()/1000);\n"),
    ("      e.preventDefault();if(over)return;touched=true;",
     "      e.preventDefault();if(pop.click(performance.now()/1000))return;if(over)return;touched=true;"),
]
SWAPS["seismic"] = SEISMIC

# ---- Culture Dish (no controls: no deck; play rows 10-139). The dish grows 55 -> 60 (rim RO; agar AR 51 ->
# 56) and its hex spacing with it (s 6 -> 6.5, 5 -> 5.5: same board, same rule), centred on row 70 (dish rows
# 10-130, its shadow to 135, 1 px clear of GROW / AGAIN at rows 125-137). The seeds / rings left sit on the
# buttons' centre row (BY+6, row 131). The DEAD count joins FED in the header (bad) while a try has any; the
# try's END line (ALL FED; n/m FED  k DEAD  NO TRIES; n/m FED on KEEP) goes on the result card.
CULTURE = [
    ("  1:{R:4,s:6,steps:3,seeds:1,food:3,stain:3},\n  2:{R:4,s:6,steps:3,seeds:2,food:4,stain:4},\n"
     "  3:{R:5,s:5,steps:3,seeds:2,food:5,stain:6},\n  4:{R:5,s:5,steps:3,seeds:3,food:6,stain:7},\n"
     "  5:{R:5,s:5,steps:4,seeds:2,food:6,stain:6},",
     "  1:{R:4,s:6.5,steps:3,seeds:1,food:3,stain:3},\n  2:{R:4,s:6.5,steps:3,seeds:2,food:4,stain:4},\n"
     "  3:{R:5,s:5.5,steps:3,seeds:2,food:5,stain:6},\n  4:{R:5,s:5.5,steps:3,seeds:3,food:6,stain:7},\n"
     "  5:{R:5,s:5.5,steps:4,seeds:2,food:6,stain:6},"),
    ("const KIT=TK.KIT,W=150,H=130,CX=75,CY=65,AR=51,RO=55;",
     "const KIT=TK.KIT,W=150,H=140,CX=75,CY=70,AR=56,RO=60;const pop=KIT.popups(ctx);"),
    ("[['FED',food+'/'+p.food.length,food===p.food.length?'good':null]])}",
     "[['FED',food+'/'+p.food.length,food===p.food.length?'good':null]].concat(run&&run.hits?[['DEAD',run.hits,'bad']]:[]))}"),
    ("    if(banner&&bparts)KIT.status(g,bparts,null,false);\n"
     "    if(!touched&&t<6000)KIT.tell(g,'EAT EVERY SPECK.',['click'],t/1000);\n    drawPanel(now);\n",
     "    if(!touched&&t<6000)KIT.tell(g,'EAT EVERY SPECK.',['click'],t/1000);\n    drawPanel(now);\n"
     "    pop.draw(g,now/1000);\n"),
    ("    const y0=104,BY=KIT.deckY(false)-2-KIT.BTN.H; // seeds / rings centred on row 113; buttons rows 106-118",
     "    const BY=KIT.deckY(false)-2-KIT.BTN.H,y0=BY-3; // seeds / rings centred on row 131 (BY+6); buttons rows 125-137"),
    ("    if(finished)return;e.preventDefault();touched=true;",
     "    if(pop.click(performance.now()/1000))return;if(finished)return;e.preventDefault();touched=true;"),
    ("  function finish(){\n    if(finished)return;finished=true;if(mode!=='done')mode='done';\n",
     "  function finish(quit){\n    if(finished)return;finished=true;if(mode!=='done')mode='done';\n"
     "    if(quit!==true&&bparts)pop.finish(bparts.map(q=>q[0]).join('  '),bparts[0][1]==='good'?'good':"
     "bparts.some(q=>q[0]==='NO TRIES')?'bad':'neutral',performance.now()/1000);\n"),
    ("giveUp(){timers.forEach(clearTimeout);if(!finished){mode='done';finish()}}",
     "giveUp(){timers.forEach(clearTimeout);if(!finished){mode='done';finish(true)}}"),
]
SWAPS["culture"] = CULTURE


def apply(gid: str, js: str) -> str:
    """The page `js` with game `gid`'s status A swaps (unchanged for a game not yet moved)."""
    for a, b in SWAPS.get(gid, []):
        assert js.count(a) == 1, (gid, js.count(a), a[:90])
        js = js.replace(a, b)
    return js
