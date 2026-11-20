// Three Kelvin science mini games: THE ONE UI KIT (Nov 19). The chrome round every game: header row,
// bottom deck (status line + control row), buttons, dial, meter, tell card. Play areas stay each game's own.
// Load after tk_helpers.js and tk_font.js (it uses TK.PAL, TK.text, TK.icon). Rules: kit_spec.md.
//
//   rows   0-8   HEADER band (border colour), text on rows 2-6; row 9 its rule
//   rows  10-..  PLAY area (the game's own)
//   DECK  top rule, then the STATUS line, then (games with controls) the CONTROL row; it runs down to row 129
//         games with controls:    deck 98-129  (rule 98, status text 100-104, controls 107-129, centred on row 118)
//         games without controls: deck 121-129 (rule 121, status text 123-127; the haul line at 132 keeps 4 rows clear)
//   rows 130-139 the shell's strip (GIVE UP / haul line + LEAVE): not the game's
(function(){
'use strict';
const P=TK.PAL;
const W=150,H=130;                       // the game area: every game draws exactly this
const GUT=3,GAP=4;                       // side gutter (text, buttons, GIVE UP all start/end 3 in); gap between controls
const ROW={
  HEAD:{y:0,h:10,ty:2,rule:9},           // band rows 0-8, rule row 9, text rows 2-6
  PLAY:{y:10},                           // first play row
  DECK_C:98,DECK_N:121,                  // bottom deck top row: with controls / no controls
  STATUS_TY:2,                           // status text row, from the deck's top (100 or 123): 4 clear rows above the haul line (132)
  CTRL:{y:107,h:23,cy:118},              // control row: rows 107-129, every control centred on row 118
  TELL:{y:45,h:17,cx:75},                // the tell card: rows 45-61, centred on x 75
  STRIP:{y:130,h:10},                    // the shell's (for mockups only)
};
const BTN={H:13,HL:19,W:[25,33,45],YS:112,YL:109}; // heights: standard (label or icon+label in a line) / large (icon over label); widths S/M/L; their y in the control row
const DIAL={R:9};                        // 19 px across: the large button's height
const METER={H:7,PITCH:4};               // 1 px frame, 3x5 segments on a 4 px pitch
const BORDER='#111823';                  // the one border colour (PAL.panel): header, deck, strip

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

// ---- DECK: the bottom band: border colour from its top rule down to row 129. controls: true/false.
function deckY(controls){return controls?ROW.DECK_C:ROW.DECK_N}
function deck(g,controls){const y=deckY(controls);R(g,0,y,W,H-y,BORDER);R(g,0,y,W,1,P.line)}

// ---- STATUS: the one place for status words, centred on the deck's status line.
// parts: 'ROUTED' (with kind) or [['COLD 1/2','neutral'],['VALVE DRY','bad']] (two spaces between).
function status(g,parts,kind,controls){if(!parts)return;
  const list=typeof parts==='string'?[[parts,kind]]:parts,y=deckY(controls)+ROW.STATUS_TY;
  const w=list.reduce((a,p)=>a+tw(p[0]),0)+8*(list.length-1);let x=(W>>1)-(w>>1);
  for(const[t,k]of list){TK.text(g,t,x,y,K(k).text);x+=tw(t)+9}
}

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

// ---- TELL card: the one-line start card. icons first, then the words, in one box at ROW.TELL.
// icons: TK.icon kinds ('click','hold','drag','drag-h','drag-v','dial') or 'key:SPACE' / 'keys:WAD' (a row of key caps).
const ICW={click:13,hold:21,drag:22,'drag-h':22,'drag-v':22,dial:13};
function iconW(k){if(k.startsWith('key:'))return k.slice(4).length*4+5;if(k.startsWith('keys:'))return k.slice(5).length*11-2;return ICW[k]||13}
function drawIcon(g,k,x,y,t){
  const key=(lab,xx)=>{g.save();g.translate(xx,y);TK.icon(g,'key',0,0,{label:lab,t});g.restore()};
  if(k.startsWith('key:'))key(k.slice(4),x);
  else if(k.startsWith('keys:'))k.slice(5).split('').forEach((ch,i)=>key(ch,x+i*11));
  else TK.icon(g,k,x,y,{t});
}
function tellRect(text,icons){icons=icons||[];const iw=icons.reduce((a,k)=>a+iconW(k)+3,0),w=iw+tw(text)+12;
  return{x:ROW.TELL.cx-(w>>1),y:ROW.TELL.y,w,h:ROW.TELL.h,iw}}
function tell(g,text,icons,t){icons=icons||[];const b=tellRect(text,icons);
  R(g,b.x,b.y,b.w,b.h,P.bevelLo);R(g,b.x+1,b.y+1,b.w-2,b.h-2,BORDER);R(g,b.x+1,b.y+1,b.w-2,1,P.bevelHi);
  let x=b.x+6;for(const k of icons){drawIcon(g,k,x,b.y+2,t||0);x+=iconW(k)+3}
  TK.text(g,text,x,b.y+6,CARD_TX);return b}

// ---- the shell's strip (mockups only: the game never draws it) ----
function strip(g,o){o=o||{};const y=ROW.STRIP.y;R(g,0,y,W,10,BORDER);
  const bx=W-GUT-33;R(g,bx,y,33,9,P.bevelLo);R(g,bx+1,y+1,31,7,BORDER);R(g,bx+1,y+1,31,1,P.line);
  TK.text(g,o.result?'LEAVE':'GIVE UP',bx+16,y+2,P.chill,'center');
  if(o.result){TK.text(g,o.name||'FLARE GLASS',GUT,y+1,o.col||P.t3);TK.text(g,o.tag||'[EPIC]',GUT+((o.name||'FLARE GLASS').length+1)*4,y+1,P.cold)}}

const KIT={W,H,GUT,GAP,ROW,BTN,DIAL,METER,BORDER,KIND,LABEL,VALUE,ICONS,
  pair,meter,header,deckY,deck,status,button,btnW,glyph,dial,dialAngle,tell,tellRect,iconW,strip};
TK.KIT=KIT;if(typeof window!=='undefined')window.KIT=KIT;
})();
