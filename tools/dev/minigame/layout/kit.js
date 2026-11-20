// Three Kelvin science mini games: THE ONE UI KIT (Nov 19; status A, Nov 20). The chrome round every game:
// header row, the control deck, buttons, dial, meter, tell card, toasts and the result card. Play areas stay
// each game's own. Load after tk_helpers.js and tk_font.js (it uses TK.PAL, TK.text, TK.icon). Rules: kit_spec.md.
//
//   the whole 150x140 glass is the game (Jon, Nov 20, his A: no strip, no GIVE UP, no haul line; Esc gives up)
//   rows   0-8   HEADER band (border colour), text on rows 2-6; row 9 its rule
//   rows  10-..  PLAY area (the game's own)
//   DECK  games with controls: rule on row 116, the CONTROL row 117-139 (every control centred on row 128)
//         games without controls: no deck; the play area runs to row 139
//   no status line: END words go on the RESULT CARD (the shell's, over the play area, 0.6 s after the end),
//   LIVE words are TOASTS (rows 12-22, gone in 1.2 s); a standing readout finds its own spot or goes
(function(){
'use strict';
const P=TK.PAL;
const W=150,H=140;                       // the game area: every game draws exactly this (the whole glass)
const GUT=3,GAP=4;                       // side gutter (text and buttons start/end 3 in); gap between controls
const ROW={
  HEAD:{y:0,h:10,ty:2,rule:9},           // band rows 0-8, rule row 9, text rows 2-6
  PLAY:{y:10},                           // first play row
  DECK_C:116,DECK_N:140,                 // the deck's top row: with controls (its rule) / no controls (none: H)
  CTRL:{y:117,h:23,cy:128},              // control row: rows 117-139, every control centred on row 128
  TELL:{y:45,h:29,cx:75,high:33,top:12}, // the tell card: rows 45-73, centred on x 75 (high: rows 33-61, top: 12-40)
};
const BTN={H:13,HL:19,W:[25,33,45],YS:122,YL:119}; // heights: standard (label or icon+label in a line) / large (icon over label); widths S/M/L; their y in the control row
const DIAL={R:9};                        // 19 px across: the large button's height
const METER={H:7,PITCH:4};               // 1 px frame, 3x5 segments on a 4 px pitch
const BORDER='#111823';                  // the one border colour (PAL.panel): header, deck, cards

// ---- the four accents (plus neutral): one meaning each, everywhere ----
//   yours  amber: the player's own things: pointer, cursor, active/pressed-for-now button, your trace
//   goal   blue:  the target to match or reach: target trace, goal marker, dock, the chamber to fill
//   good   green: right / done / safe: ROUTED, LOCKED, a matched part
//   bad    red:   wrong / failed / danger: OVERHEAT, IMPACT, a wrong guess, a draining bar at its end
const KIND={
  neutral:{fill:P.cold,hi:P.chill,text:P.chill},
  yours:  {fill:P.ember,hi:P.flare,text:P.flare},
  goal:   {fill:P.t2,hi:P.ice,text:P.t2},
  good:   {fill:P.good,hi:P.mark,text:P.good},
  bad:    {fill:P.bad,hi:'#e07a62',text:P.bad},
  // the tiers' inks (t0 common to t4 legendary), for a toast that names a find's tier (Seismic's dig results)
  t0:{fill:P.t0,hi:P.t0,text:P.t0},t1:{fill:P.t1,hi:P.t1,text:P.t1},t2:{fill:P.t2,hi:P.t2,text:P.t2},
  t3:{fill:P.t3,hi:P.t3,text:P.t3},t4:{fill:P.t4,hi:P.t4,text:P.t4},
};
const K=k=>KIND[k]||KIND.neutral;
const LABEL=P.cold,VALUE=P.ice,CARD_TX=P.hot;

const R=(g,x,y,w,h,c)=>{g.fillStyle=c;g.fillRect(x,y,w,h)};
const tw=s=>String(s).length*4-1;

// a label/value pair: label dim, value bright ("TURNS 3"). align 'right' ends at x. Returns the width.
function pair(g,x,y,label,value,o){o=o||{};
  const hasV=value!=null&&value!=='',w=(label?tw(label):0)+(label&&hasV?4:0)+(hasV?tw(value):0);
  if(o.align==='right')x-=w;else if(o.align==='center')x-=w>>1;
  let cx=x;
  if(label){TK.text(g,label,cx,y,o.lkind?K(o.lkind).text:LABEL);cx+=tw(label)+4}
  if(hasV)TK.text(g,value,cx,y,o.vkind?K(o.vkind).text:VALUE);
  return w;
}

// ---- METER: a segmented bar, 7 tall. w is rounded down to whole segments. Returns the width drawn.
function meter(g,x,y,w,frac,kind,o){o=o||{};const h=o.h||METER.H,n=Math.max(1,Math.floor((w-1)/METER.PITCH)),ww=n*METER.PITCH+1;
  const k=K(kind),on=Math.round(Math.max(0,Math.min(1,frac))*n);
  R(g,x,y,ww,h,P.bevelLo);
  for(let i=0;i<n;i++){const sx=x+1+i*METER.PITCH;
    if(i<on){R(g,sx,y+1,3,h-2,k.fill);R(g,sx,y+1,3,1,k.hi)}else R(g,sx,y+1,3,h-2,o.off||'#18212d')}
  if(o.mark!=null){const mx=x+1+Math.round(Math.max(0,Math.min(1,o.mark))*(n*METER.PITCH-1));R(g,mx,y-1,1,h+2,KIND.goal.hi)} // a goal tick, if the bar has one
  return ww;
}

// ---- HEADER: band + rule; left = the game's main state, right = its counter.
// left: 'HEAT' or {label,value,kind,vkind,meter:{w,frac,kind}}   right: [['TURNS',3],['PAR',16]] or 'TIME 38';
// a right item is [label, value, valueKind, labelKind]. The game sizes the meter so left and right never meet.
// o.padR leaves room at the right for a lamp/icon the game draws itself. Returns {lx,rx}: the free span between.
function header(g,left,right,o){o=o||{};const y=ROW.HEAD.ty;
  R(g,0,0,W,ROW.HEAD.rule,BORDER);R(g,0,ROW.HEAD.rule,W,1,P.line);
  let x=GUT;
  if(left){const L=typeof left==='string'?{label:left}:left;
    x+=pair(g,x,y,L.label,L.meter?null:L.value,{lkind:L.kind,vkind:L.vkind})+4;
    if(L.meter){x+=meter(g,x,y-1,L.meter.w,L.meter.frac,L.meter.kind)+4;
      if(L.value!=null&&L.value!=='')x+=pair(g,x,y,null,L.value,{vkind:L.vkind})+4}}
  let rx=W-GUT-(o.padR||0);
  if(right){const items=typeof right==='string'?[[right,null]]:right;
    for(let i=items.length-1;i>=0;i--){const[l,v,vk,lk]=items[i];rx-=pair(g,rx,y,l,v,{align:'right',vkind:vk,lkind:lk});if(i)rx-=8}}
  return{lx:x,rx:rx-4};
}

// ---- DECK: games with controls: border colour from its top rule (116) down to row 139. Without: none.
function deckY(controls){return controls?ROW.DECK_C:ROW.DECK_N}
function deck(g,controls){if(!controls)return;const y=deckY(true);R(g,0,y,W,H-y,BORDER);R(g,0,y,W,1,P.line)}

// ---- STATUS: GONE (A, Nov 20). A no-op, so a page not yet moved to the card and toasts still runs; never call it.

// ---- small icons for buttons: 9x9, drawn in the button's label colour ----
const ICONS={
  ccw:['...###...','..#...#..','.#.....#.','#.......#','#.......#','#........','###......','.##......','..#......'],
  cw: ['...###...','..#...#..','.#.....#.','#.......#','#.......#','........#','......###','......##.','......#..'],
  thrust:['....#....','...###...','..##.##..','.##...##.','##.....##','....#....','...###...','..#.#.#..','....#....'],
  undo:['...#.....','..##.....','.#######.','..##....#','...#....#','........#','........#','..######.','.........'],
  spin:['..####...','.#....#..','#......#.','#...#..##','#..###.#.','#...#....','.#.......','..####...','.........'],
  check:['.........','........#','.......##','......##.','#....##..','##..##...','.####....','..##.....','.........'],
  clear:['.........','.#.....#.','..#...#..','...#.#...','....#....','...#.#...','..#...#..','.#.....#.','.........'],
  lock:['...###...','..#...#..','..#...#..','.#######.','.##...##.','.###.###.','.###.###.','.#######.','.........'],
  smoke:['.........','...##....','..####.#.','.######..','########.','.######..','..##.##..','.........','.........'],
  patch:['#########','#.......#','#.#...#.#','#.......#','#.......#','#.......#','#.#...#.#','#.......#','#########'],
  grow:['....#....','....#....','..#####..','....#....','.#..#..#.','.#.....#.','..#...#..','...###...','.........'],
};
function glyph(g,name,x,y,col){const m=ICONS[name];if(!m)return 0;g.fillStyle=col;
  for(let r=0;r<9;r++)for(let c=0;c<9;c++)if(m[r][c]==='#')g.fillRect(x+c,y+r,1,1);return 9}

// ---- BUTTON: state 'normal' | 'pressed' | 'active' (amber: the one to press now / the chosen mode)
//      | 'active-pressed' | 'disabled'. h: BTN.H (13: label, or icon+label in a line) or BTN.HL (19: icon over label).
const SKIN={
  normal:   {edge:P.bevelLo,face:P.line,hi:P.bevelHi,lo:'#18212d',tx:P.ice,dy:0},
  pressed:  {edge:P.bevelLo,face:P.line,hi:'#18212d',lo:P.line,tx:P.ice,dy:1},
  active:   {edge:P.bevelLo,face:P.ember,hi:P.flare,lo:'#8a4a16',tx:P.void,dy:0},
  'active-pressed':{edge:P.bevelLo,face:P.ember,hi:'#8a4a16',lo:P.ember,tx:P.void,dy:1},
  disabled: {edge:P.line,face:BORDER,hi:BORDER,lo:BORDER,tx:P.bevelHi,dy:0},
};
function button(g,x,y,w,h,label,state,icon){const s=SKIN[state]||SKIN.normal,d=s.dy;
  R(g,x,y,w,h,s.edge);R(g,x+1,y+1,w-2,h-2,s.face);
  R(g,x+1,y+1,w-2,1,s.hi);R(g,x+1,y+1,1,h-2,s.hi);R(g,x+1,y+h-2,w-2,1,s.lo);R(g,x+w-2,y+1,1,h-2,s.lo);
  const cx=x+(w>>1)+d;
  if(icon&&label&&h>=BTN.HL){glyph(g,icon,cx-4,y+2+d,s.tx);TK.text(g,label,cx,y+h-7+d,s.tx,'center')}
  else if(icon&&label){const ww=9+3+tw(label),x0=cx-(ww>>1);glyph(g,icon,x0,y+((h-9)>>1)+d,s.tx);TK.text(g,label,x0+12,y+((h-5)>>1)+d,s.tx)}
  else if(icon)glyph(g,icon,cx-4,y+((h-9)>>1)+d,s.tx);
  else TK.text(g,label,cx,y+((h-5)>>1)+d,s.tx,'center');
}
// a button's standard width for a label (the smallest of 25 / 33 / 45 it fits, else label + 10)
function btnW(label,icon){const need=(label?tw(label):0)+(icon?12:0)+8;return BTN.W.find(w=>w>=need)||need+2}

// ---- DIAL: a knurled knob, 19 across. a = pointer angle in radians (0 up, clockwise).
// o: {state:'normal'|'active'|'disabled', ring:'good'|'goal'|..., label, value, vkind}
// With label/value they sit right of the knob: label on row cy-6, value on row cy+1. Returns the width taken.
function dial(g,cx,cy,a,o){o=o||{};const r=DIAL.R,st=o.state||'normal';
  if(o.ring){const c=K(o.ring).fill;for(let y=-r-1;y<=r+1;y++)for(let x=-r-1;x<=r+1;x++){const d=Math.hypot(x,y);if(d>r+.5&&d<=r+1.5&&((x+y)&1)===0)R(g,cx+x,cy+y,1,1,c)}}
  for(let y=-r;y<=r;y++)for(let x=-r;x<=r;x++){const d=Math.hypot(x,y);if(d>r+.5)continue;
    const lt=(-x-y)/r;let c;
    if(d>r-.5)c=P.bevelLo;
    else if(d>r-2.5){const an=Math.atan2(y,x)-a;c=(Math.floor(an/(2*Math.PI)*24+48)&1)?P.bevelLo:(lt>.3?P.chill:lt>-.3?P.cold:'#4a5a70')}
    else if(d>r-3.5)c=P.bevelLo;
    else c=lt>.5?P.chill:lt>0?P.cold:lt>-.5?'#4a5a70':P.bevelHi;
    if(st==='disabled')c=c===P.chill?P.cold:c===P.cold?'#4a5a70':c==='#4a5a70'?P.bevelHi:c;
    R(g,cx+x,cy+y,1,1,c)}
  const pc=st==='active'?P.hot:st==='disabled'?P.line:P.ember;
  for(let t=1;t<=r-3;t++)R(g,Math.round(cx+Math.sin(a)*t),Math.round(cy-Math.cos(a)*t),1,1,pc);
  {const tx=Math.round(cx+Math.sin(a)*(r-4.5)-.5),ty=Math.round(cy-Math.cos(a)*(r-4.5)-.5);R(g,tx,ty,2,2,pc)} // a 2x2 tip so it reads at game scale
  let w=2*r+1;
  if(o.label!=null||o.value!=null){const tx=cx+r+4;
    if(o.label!=null)TK.text(g,o.label,tx,cy-6,LABEL);
    if(o.value!=null)TK.text(g,o.value,tx,cy+1,o.vkind?K(o.vkind).text:VALUE);
    w+=4+Math.max(o.label?tw(o.label):0,o.value!=null?tw(o.value):0)}
  return w;
}
// a 0..1 setting as a pointer angle over the usual 270 degree sweep
const dialAngle=v=>(-135+270*Math.max(0,Math.min(1,v)))*Math.PI/180;

// ---- TELL card: the start card, two lines (Jon, Nov 20: "CONTROL [GAME INSTRUCTIONS] / [ESC] TO GIVE UP").
// Line 1: the game's control icons, then its words (hot). Line 2, always: the ESC key cap, then TO GIVE UP in
// the quiet label ink, left-aligned under line 1. The game's icons never list ESC (line 2 has it).
// icons: TK.icon kinds ('click','hold','drag','drag-h','drag-v','dial') or 'key:SPACE' / 'keys:WAD' (a row of key caps).
// o.y: the card's top row (ROW.TELL.y 45; .high 33 or .top 12 where the middle hides what a player needs to start).
const ICW={click:13,hold:21,drag:22,'drag-h':22,'drag-v':22,dial:13};
const ESC='key:ESC',ESC_T=.5,GIVE='TO GIVE UP'; // ESC_T: the cap's resting frame (TK.icon lights a key on t 0-0.5, 1-1.5 ...)
function iconW(k){if(k.startsWith('key:'))return k.slice(4).length*4+5;if(k.startsWith('keys:'))return k.slice(5).length*11-2;return ICW[k]||13}
function drawIcon(g,k,x,y,t){
  if(k===ESC)t=ESC_T;
  const key=(lab,xx)=>{g.save();g.translate(xx,y);TK.icon(g,'key',0,0,{label:lab,t});g.restore()};
  if(k.startsWith('key:'))key(k.slice(4),x);
  else if(k.startsWith('keys:'))k.slice(5).split('').forEach((ch,i)=>key(ch,x+i*11));
  else TK.icon(g,k,x,y,{t});
}
// line 1's icons at y+2, its words at y+6; line 2's cap at y+15 (its edge rows y+16 to y+26), TO GIVE UP at y+20
function tellRect(text,icons,o){icons=icons||[];o=o||{};const iw=icons.reduce((a,k)=>a+iconW(k)+3,0),
    w=Math.max(iw+tw(text),iconW(ESC)+3+tw(GIVE))+12;
  return{x:ROW.TELL.cx-(w>>1),y:o.y!=null?o.y:ROW.TELL.y,w,h:ROW.TELL.h,iw}}
function tell(g,text,icons,t,o){icons=icons||[];const b=tellRect(text,icons,o);
  box(g,b.x,b.y,b.w,b.h);
  let x=b.x+6;for(const k of icons){drawIcon(g,k,x,b.y+2,t||0);x+=iconW(k)+3}
  TK.text(g,text,x,b.y+6,CARD_TX);
  drawIcon(g,ESC,b.x+6,b.y+15,0);TK.text(g,GIVE,b.x+6+iconW(ESC)+3,b.y+20,LABEL);
  return b}

// ---- popups (Jon, Nov 20, his A: "I like A. You can just get rid of the bottom bar with GIVE UP. You can just
// press ESC to give up."): the tell card's box (bevelLo edge, border-colour face, bevelHi top line) twice over.
function box(g,x,y,w,h){R(g,x,y,w,h,P.bevelLo);R(g,x+1,y+1,w-2,h-2,BORDER);R(g,x+1,y+1,w-2,1,P.bevelHi)}
// the kit's 2x2 ordered dither (TK.dither's): whether pixel (x,y) shows at density d
const BAYER=[0,2,3,1],lit=(x,y,d)=>(BAYER[(y&1)*2+(x&1)]+.5)/4<d;

// ---- TIERS: the haul's ink, as the game colours an item: NAME in its tier's ink, [TIER] quiet (cold)
const TIERS=['COMMON','UNCOMMON','RARE','EPIC','LEGENDARY'],TIER_INK=[P.t0,P.t1,P.t2,P.t3,P.t4];
const tierIx=t=>typeof t==='number'?t:Math.max(0,TIERS.indexOf(String(t).toUpperCase()));
// TK.text has no [ ]: the bracket glyphs, 3x5 (MiniPix's font has the same two)
const BR={'[':['##.','#..','#..','#..','##.'],']':['.##','..#','..#','..#','.##']};
function textB(g,s,x,y,c){for(const ch of String(s)){if(BR[ch]){g.fillStyle=c;BR[ch].forEach((row,r)=>{for(let k=0;k<3;k++)if(row[k]==='#')g.fillRect(x+k,y+r,1,1)})}else TK.text(g,ch,x,y,c);x+=4}}

// ---- RESULT CARD (the shell draws it in the game; a page draws it for mockups through KIT.popups). Over the
// play area, centred on x 75 and the tell card's centre row 53: rows 33-73 (41 tall). The END word in its kind's
// colour (y+5), a line rule (y+13), NAME [TIER] (y+17), an amber LEAVE kit button (33x13, active, y+25). A click
// anywhere on the glass, or Esc, leaves (A overrides "only LEAVE leaves" for this card). Width = widest line + 16,
// at least 79, at most 144 (x 3-146); [TIER] drops first if it would not fit. It waits CARD.delay (0.6 s).
const CARD={cx:75,cy:53,pad:8,minW:79,maxW:144,h:41,delay:.6};
// The card's box {x,y,w,h,full,tag,leave:{x,y,w,h}} for an END word, the haul's NAME and its tier (0-4 or 'EPIC').
function cardRect(status,haul,tier){
  const tag='['+TIERS[tierIx(tier)]+']',hl=haul?tw(haul+' '+tag):0;
  let w=Math.max(tw(status),hl,33)+2*CARD.pad,full=true;
  if(w>CARD.maxW&&haul){full=false;w=Math.max(tw(status),tw(haul),33)+2*CARD.pad}
  w=Math.max(CARD.minW,Math.min(CARD.maxW,w));
  const x=CARD.cx-(w>>1),y=CARD.cy-(CARD.h>>1);
  return{x,y,w,h:CARD.h,full,tag,leave:{x:CARD.cx-16,y:y+25,w:33,h:BTN.H}};
}
// t: seconds since the end (nothing before CARD.delay). Returns the box (cardRect's), or null while it waits.
function resultCard(g,status,kind,haul,tier,t){
  if(t<CARD.delay)return null;
  const b=cardRect(status,haul,tier),cx=b.x+(b.w>>1);
  box(g,b.x,b.y,b.w,b.h);
  TK.text(g,status,cx-(tw(status)>>1),b.y+5,K(kind).text);
  R(g,b.x+6,b.y+13,b.w-12,1,P.line);
  if(haul){const s=b.full?haul+' '+b.tag:haul,hx=cx-(tw(s)>>1);
    TK.text(g,haul,hx,b.y+17,TIER_INK[tierIx(tier)]);if(b.full)textB(g,b.tag,hx+(haul.length+1)*4,b.y+17,P.cold)}
  button(g,b.leave.x,b.leave.y,b.leave.w,b.leave.h,'LEAVE','active');
  return b;
}

// ---- TOAST: a LIVE word (NO LOCK, LEAK, TOO FAST ...): the same box, 11 tall, rows 12-22 (2 under the header
// rule), centred on x 75 (o.cx / o.y move it); the text at y+3 in its kind's colour; width = text + 10. Full for
// 0.9 s, then two dimmer steps to 1.2 s (the kit's 2x2 dither: 3 of 4 pixels, then 1 of 4), then gone. Draw-only:
// it never takes a click and never looks pressable. A new toast replaces the old one. age: seconds since the event.
const TOAST={y:12,h:11,cx:75,hold:.9,life:1.2};
function toast(g,text,kind,age,o){o=o||{};
  if(text==null||text===''||age<0||age>=TOAST.life)return false;
  const d=age<TOAST.hold?1:age<TOAST.hold+(TOAST.life-TOAST.hold)/2?.66:.33;
  const w=tw(text)+10,x=(o.cx!=null?o.cx:TOAST.cx)-(w>>1),y=o.y!=null?o.y:TOAST.y,h=TOAST.h;
  const draw=(gg,xx,yy)=>{box(gg,xx,yy,w,h);TK.text(gg,text,xx+5,yy+3,K(kind).text)};
  if(d===1){draw(g,x,y);return true}
  const cv=document.createElement('canvas');cv.width=w;cv.height=h;const c=cv.getContext('2d');draw(c,0,0);
  const im=c.getImageData(0,0,w,h).data;
  for(let j=0;j<h;j++)for(let i=0;i<w;i++)if(lit(x+i,y+j,d)){const k=(j*w+i)*4;R(g,x+i,y+j,1,1,`rgb(${im[k]},${im[k+1]},${im[k+2]})`)}
  return true;
}

// ---- POPUPS: one toast at a time and the end, for a page (in the game: MiniGame.say / .finish and the shell's card).
//   const pop=KIT.popups(ctx);  pop.say('LEAK','bad',now);  pop.finish('ROUTED','good',now);
//   draw last: pop.draw(g,now);  input first: if(pop.click(now))return;  (a click once the card is up leaves)
// The card needs the haul: ctx.haul or window.__HAUL ({name,tier}); a page without one (diff.py) never shows it.
function popups(ctx,o){o=o||{};
  const st={tt:'',tk:'neutral',t0:-9,endTx:null,ek:'good',e0:0,delay:o.delay!=null?o.delay:CARD.delay};
  st.say=(text,kind,now)=>{st.tt=text;st.tk=kind||'neutral';st.t0=now};
  st.finish=(text,kind,now)=>{st.endTx=text;st.ek=kind||'good';st.e0=now;st.tt=''};
  st.haul=()=>(ctx&&ctx.haul)||(typeof window!=='undefined'&&window.__HAUL)||null;
  st.cardUp=now=>st.endTx!=null&&now-st.e0>=st.delay&&!!st.haul();
  st.click=now=>{if(!st.cardUp(now))return false;st.left=true;
    if(ctx&&ctx.leave)ctx.leave();if(typeof window!=='undefined')window.__left=true;return true};
  st.draw=(g,now)=>{if(st.endTx==null){toast(g,st.tt,st.tk,now-st.t0);return}
    const h=st.haul();if(h)resultCard(g,st.endTx,st.ek,h.name,h.tier,now-st.e0-st.delay+CARD.delay)};
  return st;
}

const KIT={W,H,GUT,GAP,ROW,BTN,DIAL,METER,BORDER,KIND,LABEL,VALUE,ICONS,ESC,GIVE,CARD,TOAST,TIERS,TIER_INK,
  pair,meter,header,deckY,deck,button,btnW,glyph,dial,dialAngle,tell,tellRect,iconW,cardRect,resultCard,toast,popups};
TK.KIT=KIT;if(typeof window!=='undefined')window.KIT=KIT;
})();
