// Ice Core v2: the same puzzle, drawn as pixel art at the ship's science terminal.
(function(){
'use strict';
const ID='icecore2';

// ---------- logic (verbatim from icecore.js) ----------
const CFG={
  1:{n:6,flip:0,gap:0},
  2:{n:7,flip:0,gap:0},
  3:{n:8,flip:1,gap:0},
  4:{n:9,flip:1,gap:1},
  5:{n:10,flip:1,gap:1},
};
// layer kinds: colour + texture (0 plain, 1 dots, 2 stripes, 3 cross)
const KINDS=[
  {c:'#cfe3ee',t:0},{c:'#55585f',t:1},{c:'#b08850',t:2},{c:'#5d8fc9',t:0},{c:'#6fae8a',t:3},
  {c:'#b5553f',t:1},{c:'#e9e6dc',t:2},{c:'#8a6cc2',t:0},{c:'#d6b54a',t:3},{c:'#3f9fa3',t:2},
];
function shuffle(a,r){a=a.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(r()*(i+1));const t=a[i];a[i]=a[j];a[j]=t}return a}
function int(r,lo,hi){return lo+Math.floor(r()*(hi-lo+1))}

// core: {layers:[ids bottom->top], gap:k (crack between layers[k-1] and layers[k]) or -1}
function orient(core,flip){
  if(!flip)return core;
  const L=core.layers.length;
  return {layers:core.layers.slice().reverse(),gap:core.gap<0?-1:L-core.gap};
}
// count distinct full orders consistent with the cores, given exactly `flips` cores are shown upside down
function solve(n,cores,flips,limit){
  limit=limit||2;
  const found=new Set();
  const choices=flips===0?[[]]:cores.map((_,i)=>[i]);
  for(const ch of choices){
    const oc=cores.map((c,i)=>orient(c,ch.includes(i)));
    // weighted union-find: off[x] = pos[x]-pos[root]
    const par=[],off=[];for(let i=0;i<n;i++){par[i]=i;off[i]=0}
    const find=x=>{if(par[x]===x)return x;const r=find(par[x]);off[x]+=off[par[x]];par[x]=r;return r};
    let ok=true;
    for(const c of oc){
      for(let k=1;k<c.layers.length;k++){
        const a=c.layers[k-1],b=c.layers[k],d=(c.gap===k)?2:1;
        const ra=find(a),rb=find(b);
        if(ra===rb){if(off[b]-off[a]!==d){ok=false;break}}
        else{par[rb]=ra;off[rb]=off[a]+d-off[b]}
      }
      if(!ok)break;
    }
    if(!ok)continue;
    const comps={};
    for(let i=0;i<n;i++){const r=find(i);(comps[r]=comps[r]||[]).push([i,off[i]])}
    const list=Object.values(comps).map(cp=>{const m=Math.min(...cp.map(x=>x[1]));return cp.map(x=>[x[0],x[1]-m])});
    // check internal distinctness
    if(list.some(cp=>new Set(cp.map(x=>x[1])).size!==cp.length))continue;
    list.sort((a,b)=>b.length-a.length);
    const pos=new Array(n).fill(-1);
    const rec=ci=>{
      if(found.size>=limit)return;
      if(ci===list.length){found.add(pos.join(','));return}
      const cp=list[ci],span=Math.max(...cp.map(x=>x[1]));
      for(let s=0;s+span<n;s++){
        if(cp.some(x=>pos[s+x[1]]>=0))continue;
        cp.forEach(x=>pos[s+x[1]]=x[0]);rec(ci+1);cp.forEach(x=>pos[s+x[1]]=-1);
      }
    };
    rec(0);
    if(found.size>=limit)break;
  }
  return [...found].map(s=>s.split(',').map(Number));
}

function gen(rng,depth){
  const c=CFG[depth]||CFG[1],n=c.n;
  for(let tries=0;tries<2000;tries++){
    const kinds=shuffle(KINDS.map((_,i)=>i),rng).slice(0,n);
    const truth=kinds; // truth[pos] = kind, pos 0 = oldest
    const wins=[];let pos=0;
    while(true){
      const len=n<=7?3:int(rng,3,4),end=Math.min(n-1,pos+len-1);
      const st=Math.max(0,end-len+1);
      wins.push([st,end]);
      if(end>=n-1)break;
      pos=end-int(rng,c.flip?1:0,1);
    }
    if(wins.length<3||wins.length>5)continue;
    let cores=wins.map(w=>({layers:truth.slice(w[0],w[1]+1),gap:-1}));
    if(c.gap){
      const cand=cores.map((x,i)=>i).filter(i=>cores[i].layers.length>=4);
      if(!cand.length)continue;
      const gi=cand[Math.floor(rng()*cand.length)],L=cores[gi].layers;
      const k=int(rng,1,L.length-2);
      cores[gi]={layers:L.slice(0,k).concat(L.slice(k+1)),gap:k};
    }
    let flipped=-1;
    if(c.flip){flipped=Math.floor(rng()*cores.length);cores[flipped]=orient(cores[flipped],true)}
    const seen=new Set();cores.forEach(x=>x.layers.forEach(l=>seen.add(l)));
    if(seen.size!==n)continue;
    const sols=solve(n,cores,c.flip,2);
    if(sols.length!==1||sols[0].join()!==truth.join())continue;
    const order=shuffle(cores.map((x,i)=>i),rng);
    return {n,truth,cores:order.map(i=>cores[i]),flipped:order.indexOf(flipped),flips:c.flip,gaps:c.gap};
  }
  throw new Error('icecore2: no puzzle');
}

const CHECK_SCORE=[1,.75,.58,.48,.42];
function score(solvedAt,lastFrac){return solvedAt>0?CHECK_SCORE[Math.min(solvedAt,5)-1]:.3*lastFrac}

const logic={CFG,KINDS,solve,gen,score,orient};
if(typeof TK==='undefined'){if(typeof module!=='undefined'&&module.exports)module.exports=logic;return}

// ---------- view: pixel art ----------
const W=144,H=120;
// each layer kind in the game's palette; t = texture (0 plain, 1 dots, 2 stripes, 3 cross), same as KINDS
function kindCols(){const P=TK.PAL;return[P.ice,P.bevelHi,P.warn,P.t2,P.good,P.bad,P.hot,P.t3,P.t4,P.tractor]}
function hex2(c){const n=parseInt(c.slice(1),16);return[n>>16&255,n>>8&255,n&255]}
function toHex(r,g,b){return'#'+[r,g,b].map(v=>Math.max(0,Math.min(255,Math.round(v))).toString(16).padStart(2,'0')).join('')}
// stepped lighter (f>0) or darker (f<0) step of the same hue
const shadeCache=new Map();
function sh(c,f){const k=c+f;let v=shadeCache.get(k);if(v)return v;const[r,g,b]=hex2(c);
  v=f>=0?toHex(r+(255-r)*f,g+(255-g)*f,b+(255-b)*f):toHex(r*(1+f),g*(1+f),b*(1+f));shadeCache.set(k,v);return v}
function mix(a,b,t){const A=hex2(a),B=hex2(b);return toHex(A[0]+(B[0]-A[0])*t,A[1]+(B[1]-A[1])*t,A[2]+(B[2]-A[2])*t)}
const hash=(a,b,c)=>{let h=(a*73856093)^(b*19349663)^(c*83492791);h=(h^(h>>>13))*1274126177;return((h^(h>>>16))>>>0)/4294967296};

// geometry
const CX0=16,CDX=16,CW=12,LH=7,GH=5,CB=62;          // cores
const SX=104,SW=24,SH=8,SB=96;                        // the stack tube
const PX0=4,PDX=18,PW=16,PHh=10,PY0=80,PDY=13;        // the layer tray
const BY=106,BH=12,BCL=[91,26],BCK=[118,26];          // buttons

function mount(stage,ctx){
  const p=gen(ctx.rng,ctx.depth),s=ctx.sensors|0,n=p.n;
  const checks=3+(s>=2?1:0)+(s>=4?1:0);
  const given=new Set();
  if(s>=1)given.add(0);if(s>=3)given.add(n-1);if(s>=5)given.add(Math.floor(n/2));
  const slots=new Array(n).fill(-1);given.forEach(i=>slots[i]=p.truth[i]);
  let used=0,finished=false,acted=false,lastFrac=0,msg='',winAt=0;const marks=new Array(n).fill('');
  const timers=[];const placedAt=new Array(n).fill(0);
  const palKinds=shuffle(p.truth,ctx.rng);
  const PAL=TK.PAL,KC=kindCols();
  const px=TK.pixel(stage,{w:W,h:H});const g=px.g,cv=px.cv;
  cv.style.cursor='pointer';
  const R=(x,y,w,h,c)=>{g.fillStyle=c;g.fillRect(x,y,w,h)};

  // ---- drawing pieces ----
  // one ice layer seen as part of a lit cylinder: highlight left, shadow right, light from the top
  function layer(kind,x,y,w,h,lift){
    const iced=mix(KC[kind],TK.PAL.ice,.16),t=KINDS[kind].t,b=lift?sh(iced,lift):iced;
    for(let i=0;i<w;i++){
      let f=0;
      if(i===0)f=.18;else if(i===1)f=.42;else if(i===2)f=.2;else if(i===w-1)f=-.42;else if(i===w-2)f=-.26;else if(i===w-3)f=-.1;
      R(x+i,y,1,h,f?sh(b,f):b);
    }
    R(x+2,y,w-4,1,sh(b,.12)); // top edge catches light
    const dk=sh(b,-.38);
    if(t===1){for(let j=2;j<h-1;j+=3)for(let i=3+((j/3|0)%2)*2;i<w-2;i+=4)R(x+i,y+j,1,1,dk)}
    else if(t===2){for(let j=2;j<h;j+=3)R(x+2,y+j,w-4,1,sh(b,-.24))}
    else if(t===3){for(let j=1;j<h;j++)for(let i=2;i<w-2;i++)if((i+j)%4===0)R(x+i,y+j,1,1,dk)}
    // trapped air bubbles
    for(let i=0;i<2;i++){const hx=hash(kind,i,7),hy=hash(kind,i,11);if(hash(kind,i,3)<.6)R(x+3+Math.floor(hx*(w-6)),y+1+Math.floor(hy*(h-2)),1,1,sh(b,.62))}
  }
  function crack(x,y,w){
    R(x,y,w,GH,PAL.bevelLo);
    const zz=[2,1,3,1,2,3,1,2,3,2,1,3,2,1];
    for(let i=0;i<w;i++)R(x+i,y+zz[i%zz.length]-0,1,1,PAL.chill);
  }
  // frosted cap at a core end
  function cap(x,y,w){R(x,y,w,2,PAL.cold);TK.dither(g,x+1,y,w-2,2,PAL.chill,PAL.ice,.35)}
  function core(c,i){
    const x=CX0+i*CDX,L=c.layers.length,hgt=L*LH+(c.gap>=0?GH:0);
    const top=CB-hgt;
    R(x-1,top-3,CW+2,hgt+6,PAL.bevelLo); // outline
    TK.dither(g,x-1,top-1,1,hgt+2,PAL.bevelLo,PAL.cold,.3);TK.dither(g,x+CW,top-1,1,hgt+2,PAL.bevelLo,PAL.line,.5); // frost on the rim
    cap(x,top-2,CW);cap(x,CB,CW);
    let y=CB;
    for(let k=0;k<L;k++){
      if(c.gap===k){y-=GH;crack(x,y,CW)}
      y-=LH;layer(c.layers[k],x,y,CW,LH,0);
      R(x+1,y+LH-1,CW-2,1,sh(KC[c.layers[k]],-.3));
    }
    TK.text(g,'C'+(i+1),x+CW/2,12,PAL.chill,'center');
  }
  function glyph(kind,x,y,col){ // 5x5 tick or cross
    const T=kind==='ok'?['....#','...#.','#.#..','.#...','.....']:['#...#','.#.#.','..#..','.#.#.','#...#'];
    for(let j=0;j<5;j++)for(let i=0;i<5;i++)if(T[j][i]==='#')R(x+i,y+j,1,1,col);
  }
  function button(b,label,hot,down){
    const[x,w]=b;
    R(x,BY,w,BH,PAL.bevelLo);
    const face=hot?PAL.ember:PAL.panel;
    R(x+1,BY+1,w-2,BH-2,face);
    R(x+1,BY+1,w-2,1,down?sh(face,-.35):hot?PAL.flare:PAL.bevelHi);R(x+1,BY+1,1,BH-2,down?sh(face,-.35):hot?PAL.flare:PAL.bevelHi);
    R(x+1,BY+BH-2,w-2,1,down?sh(face,.2):sh(face,-.4));R(x+w-2,BY+1,1,BH-2,down?sh(face,.2):sh(face,-.4));
    TK.text(g,label,x+Math.floor(w/2)+(down?1:0),BY+4+(down?1:0),hot?PAL.void:PAL.cold,'center');
  }
  const slotY=i=>SB-(i+1)*SH;
  const palXY=j=>[PX0+(j%5)*PDX,PY0+Math.floor(j/5)*PDY];

  // ---- input state ----
  let drag=null,pressed='';

  function draw(now){
    R(0,0,W,H,PAL.void);
    // faint frost on the bench
    TK.dither(g,0,H-6,W,6,PAL.void,PAL.panel,.5);
    // the cold drawer the cores sit in: a soft frosted panel
    {const bx=CX0-3,bw=CDX*p.cores.length+2;R(bx,18,bw,49,PAL.panel);TK.dither(g,bx,18,bw,6,PAL.panel,PAL.line,.5);R(bx,18,bw,1,PAL.line);R(bx,18,1,49,PAL.line)}
    // HUD
    if(!acted){R(0,0,W,8,PAL.panel);R(0,8,W,1,PAL.line);TK.text(g,'STACK THE LAYERS IN ORDER',W/2,2,PAL.hot,'center')}else{
    TK.text(g,'CHECKS '+(checks-used),2,2,PAL.hot);
    TK.text(g,'LAYERS '+n,92,2,PAL.cold,'right')}
    // core rack
    R(CX0-4,CB+3,CDX*p.cores.length+4,2,PAL.bevelHi);R(CX0-4,CB+5,CDX*p.cores.length+4,1,PAL.bevelLo);
    TK.text(g,'NEW',1,24,PAL.cold);TK.text(g,'OLD',1,56,PAL.cold);
    for(let y=31;y<=53;y++)R(6,y,1,1,PAL.line);R(5,31,3,1,PAL.line);
    p.cores.forEach(core);
    let ny=68;
    if(p.flips){TK.text(g,'ONE UPSIDE DOWN',CX0-4,ny,PAL.warn);ny+=6}
    if(p.gaps){TK.text(g,'CRACK = 1 LOST',CX0-4,ny,PAL.chill)}
    // layer tray: the loose samples to place
    const placed=new Set(slots.filter(x=>x>=0));
    palKinds.forEach((k,j)=>{
      const[x,y]=palXY(j);
      if(placed.has(k)||(drag&&drag.from==='pal'&&drag.moved&&drag.kind===k)){ // empty socket
        R(x,y,PW,PHh,PAL.bevelLo);TK.dither(g,x+1,y+1,PW-2,PHh-2,PAL.void,PAL.line,.25);return}
      R(x-1,y-1,PW+2,PHh+2,PAL.bevelLo);layer(k,x,y,PW,PHh,0);
    });
    // stack tube
    const top=slotY(n-1);
    TK.text(g,'NEW',SX+SW/2,top-8,PAL.cold,'center');
    R(SX-2,top-2,SW+4,n*SH+4,PAL.bevelLo);R(SX-1,top-1,SW+2,n*SH+2,PAL.line);
    for(let i=0;i<n;i++){
      const y=slotY(i);
      const showK=(drag&&drag.from==='slot'&&drag.moved&&drag.idx===i)?-1:slots[i];
      if(showK>=0){
        let lift=0;
        if(winAt){const d=Math.abs((now-winAt)/1000-i*.09);if(d<.18)lift=.45}
        layer(showK,SX,y,SW,SH-1,lift);
      }else{
        R(SX,y,SW,SH-1,PAL.void);TK.dither(g,SX+1,y+1,SW-2,SH-3,PAL.void,PAL.panel,.5);
        R(SX,y,1,SH-1,sh(PAL.chill,-.5));
      }
      R(SX,y+SH-1,SW,1,PAL.bevelLo);
      // glass sheen on the tube
      R(SX+1,y,1,SH-1,showK>=0?sh(KC[showK],.55):PAL.line);
      if(placedAt[i]&&now-placedAt[i]<350){R(SX-1,y-1,SW+2,1,PAL.flare);R(SX-1,y+SH-1,SW+2,1,PAL.flare)}
      if(drag&&drag.moved&&drag.over===i){R(SX-1,y-1,SW+2,1,PAL.ember);R(SX-1,y+SH-1,SW+2,1,PAL.ember);R(SX-1,y,1,SH-1,PAL.ember);R(SX+SW,y,1,SH-1,PAL.ember)}
      if(given.has(i)){R(SX+SW+3,y+3,2,2,PAL.hot)}
      else if(marks[i])glyph(marks[i],SX+SW+3,y+1,marks[i]==='ok'?PAL.good:PAL.bad);
    }
    TK.text(g,'OLD',SX+SW/2,SB+3,PAL.cold,'center');
    // buttons
    const full=!slots.includes(-1);
    button(BCL,'CLEAR',false,pressed==='clear');
    button(BCK,'CHECK',full&&!finished,pressed==='check');
    // message
    const m=msg;
    if(!acted&&!m){const tt=now/1000;const w1=TK.icon(g,'click',2,106,{t:tt});TK.icon(g,'drag',2+w1+4,106,{t:tt})}
    if(m)TK.text(g,m,2,108+6,finished&&winAt?PAL.good:PAL.hot);
    // the dragged layer follows the finger
    if(drag&&drag.moved){const w=drag.from==='pal'?PW:SW,h=drag.from==='pal'?PHh:SH-1;const x=drag.x-(w>>1),y=drag.y-(h>>1);R(x-1,y-1,w+2,h+2,PAL.bevelLo);layer(drag.kind,x,y,w,h,.08)}
  }

  // ---- hit tests ----
  function hitPal(x,y){const placed=new Set(slots.filter(k=>k>=0));for(let j=0;j<palKinds.length;j++){const[px0,py0]=palXY(j);if(x>=px0-1&&x<=px0+PW&&y>=py0-2&&y<=py0+PHh+1&&!placed.has(palKinds[j]))return j}return -1}
  function hitSlot(x,y,loose){if(x<SX-(loose?6:1)||x>SX+SW+(loose?6:1))return -1;for(let i=0;i<n;i++){const y0=slotY(i);if(y>=y0-1&&y<y0+SH)return i}return -1}
  function hitBtn(x,y){if(y<BY-1||y>BY+BH)return '';if(x>=BCL[0]&&x<BCL[0]+BCL[1])return 'clear';if(x>=BCK[0]&&x<BCK[0]+BCK[1])return 'check';return ''}

  function place(at,k){TK.sfx('icecore2','place');slots[at]=k;marks[at]='';placedAt[at]=performance.now();msg=''}
  function down(e){
    if(finished)return;e.preventDefault();
    const q=px.pt(e);
    const b=hitBtn(q.x,q.y);
    if(b){acted=true;pressed=b;try{cv.setPointerCapture(e.pointerId)}catch(_){}drag={id:e.pointerId,btn:b};return}
    const j=hitPal(q.x,q.y);
    if(j>=0){drag={id:e.pointerId,from:'pal',kind:palKinds[j],sx:q.x,sy:q.y,x:q.x,y:q.y,moved:false,over:-1}}
    else{const i=hitSlot(q.x,q.y);if(i>=0&&!given.has(i)&&slots[i]>=0)drag={id:e.pointerId,from:'slot',idx:i,kind:slots[i],sx:q.x,sy:q.y,x:q.x,y:q.y,moved:false,over:-1}}
    if(drag){acted=true;try{cv.setPointerCapture(e.pointerId)}catch(_){}}
  }
  function move(e){
    if(!drag||e.pointerId!==drag.id)return;e.preventDefault();
    const q=px.pt(e);
    if(drag.btn){pressed=hitBtn(q.x,q.y)===drag.btn?drag.btn:'';return}
    drag.x=q.x;drag.y=q.y;
    if(!drag.moved&&Math.abs(q.x-drag.sx)+Math.abs(q.y-drag.sy)>3)drag.moved=true;
    if(drag.moved){const i=hitSlot(q.x,q.y,true);drag.over=i>=0&&!given.has(i)?i:-1}
  }
  function up(e){
    if(!drag||e.pointerId!==drag.id)return;
    const d=drag;drag=null;pressed='';
    if(finished||e.type==='pointercancel')return;
    const q=px.pt(e);
    if(d.btn){if(hitBtn(q.x,q.y)===d.btn){if(d.btn==='check')check();else clear()}return}
    if(!d.moved){ // a tap
      if(d.from==='pal'){const at=slots.indexOf(-1);if(at>=0)place(at,d.kind)}
      else{slots[d.idx]=-1;marks[d.idx]=''}
      return;
    }
    const t=d.over;
    if(d.from==='pal'){if(t>=0)place(t,d.kind);return}
    if(t<0){slots[d.idx]=-1;marks[d.idx]='';return} // dropped off the tube: back to the tray
    if(t===d.idx)return;
    const old=slots[t];place(t,d.kind);slots[d.idx]=old;marks[d.idx]='';if(old>=0)placedAt[d.idx]=performance.now();
  }
  cv.addEventListener('pointerdown',down);cv.addEventListener('pointermove',move);
  cv.addEventListener('pointerup',up);cv.addEventListener('pointercancel',up);

  function clear(){if(finished)return;for(let i=0;i<n;i++)if(!given.has(i)){slots[i]=-1;marks[i]=''}msg=''}
  function check(){
    if(finished||slots.includes(-1))return;
    used++;let right=0;
    for(let i=0;i<n;i++){const ok=slots[i]===p.truth[i];if(ok)right++;marks[i]=given.has(i)?'':ok?'ok':'no'}
    lastFrac=right/n;
    if(right===n){
      finished=true;winAt=performance.now();msg='ORDER CONFIRMED';TK.sfx('icecore2','confirm');TK.sfx('icecore2','win');
      timers.push(setTimeout(()=>ctx.done({score:score(used,1),detail:`Ordered ${n} layers on check ${used} of ${checks}`}),90*n+500));
      return;
    }
    msg=`${right}/${n} IN PLACE`;
    if(used>=checks){finished=true;
      timers.push(setTimeout(()=>ctx.done({score:score(0,lastFrac),detail:`${right}/${n} layers in place after ${checks} checks`}),900))}
  }

  // ---- loop, about 30 fps ----
  let raf=0,last=0,alive=true;
  const loop=now=>{if(!alive)return;raf=requestAnimationFrame(loop);if(now-last<32)return;last=now;draw(now)};
  draw(performance.now());raf=requestAnimationFrame(loop);
  let gaveUp=false;
  return {
    destroy(){alive=false;cancelAnimationFrame(raf);timers.forEach(clearTimeout);finished=true;
      cv.removeEventListener('pointerdown',down);cv.removeEventListener('pointermove',move);cv.removeEventListener('pointerup',up);cv.removeEventListener('pointercancel',up);px.destroy()},
    giveUp(){if(finished||gaveUp)return;gaveUp=true;finished=true;timers.forEach(clearTimeout);let right=0;for(let i=0;i<n;i++)if(slots[i]===p.truth[i]&&!given.has(i))right++;
      ctx.done({score:.2*right/n,detail:'Gave up'})},
    _test:{p,slots,given,palKinds,palXY,slotY,SX,SW,SH,BY,BCK,BCL,get used(){return used},get finished(){return finished},px},
  };
}

TK.register({
  id:ID,name:'Ice Core 2',where:'Ice moons, comets',skill:'Deduction',
  hint:'Stack the layers in order.',
  controls:['click','drag'],
  blurb:'Line up short ice cores to find the order the layers fell.',
  how:[
    'Each core holds layers in order, oldest at the bottom.',
    'Cores overlap. Match shared layers to join them.',
    'Tap or drag layers into the tube, oldest first.',
    'CHECK marks the right slots. Fewer checks score more.',
  ],
  deeper:'Sector 2+: more layers. Sector 3+: one core is upside down. Sector 4+: a crack marks one lost layer.',
  sensors:'1: oldest layer given. 2: one extra check. 3: newest layer given. 4: another check. 5: middle layer given.',
  mount,
  _t:logic,
});
})();
