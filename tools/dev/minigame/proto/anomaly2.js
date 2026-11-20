// Anomaly Count v2: a microscope feed. Mark every critter that fits the rule.
(function(){
'use strict';
const ID='anomaly2';

// ---------- logic ----------
const CFG={
  // fewer, bigger critters (Jon: "hard to see tiny details"). Round 3 put the feed on the same
  // 144x124 screen as the other games, so the dish holds 9-10 at the same big size, not 10-13.
  1:{n:9,kinds:['and2'],k:[3,4],time:32,swim:0},
  2:{n:10,kinds:['and3','and2'],k:[3,4],time:35,swim:0},
  3:{n:10,kinds:['or','and3'],k:[3,4],time:38,swim:0},
  4:{n:10,kinds:['and3','or'],k:[3,4],time:42,swim:1},
  5:{n:10,kinds:['switch'],k:[2,3],time:50,swim:1},
};
const DISH_R=39,MIN_GAP=23;
const SHAPES=['ROUND','ROD','STAR'];
const ATTRS={shape:[0,1,2],spots:[0,1,2,3],ring:[0,1],tail:[0,1]};
const KEYS=['shape','spots','ring','tail'];
function word(k,v){
  if(k==='shape')return SHAPES[v];
  if(k==='spots')return v===0?'NO SPOTS':v===1?'1 SPOT':v+' SPOTS';
  if(k==='ring')return v?'HALO':'NO HALO';
  return v?'TAIL':'NO TAIL';
}
function shuffle(a,r){a=a.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(r()*(i+1));const t=a[i];a[i]=a[j];a[j]=t}return a}
function pick(a,r){return a[Math.floor(r()*a.length)]}
function int(r,lo,hi){return lo+Math.floor(r()*(hi-lo+1))}
function randSpec(r){return {shape:pick(ATTRS.shape,r),spots:pick(ATTRS.spots,r),ring:pick(ATTRS.ring,r),tail:pick(ATTRS.tail,r),rot:Math.floor(r()*8)}}
function termHolds(t,s){return t.every(c=>s[c.k]===c.v)}
function makeTerm(r,n){return shuffle(KEYS,r).slice(0,n).map(k=>({k,v:pick(ATTRS[k],r)}))}
function makeRule(kind,r){
  if(kind==='and2')return {terms:[makeTerm(r,2)]};
  if(kind==='and3')return {terms:[makeTerm(r,3)]};
  const a=makeTerm(r,2);let b;do{b=makeTerm(r,2)}while(b.every(c=>a.some(q=>q.k===c.k)));
  return {terms:[a,b]};
}
function ruleText(rule){return rule.terms.map(t=>t.map(c=>word(c.k,c.v)).join(' + '))}
function matches(rule,specs){const out=[];specs.forEach((s,i)=>{if(rule.terms.some(t=>termHolds(t,s)))out.push(i)});return out}
function nearMiss(rule,r){
  for(let g=0;g<50;g++){
    const s=randSpec(r),t=pick(rule.terms,r);t.forEach(c=>s[c.k]=c.v);
    const c=pick(t,r),alts=ATTRS[c.k].filter(v=>v!==c.v);s[c.k]=pick(alts,r);
    if(!rule.terms.some(tt=>termHolds(tt,s)))return s;
  }
  return null;
}
function genAttr(rule,total,k,r){
  const specs=[];let guard=0;
  while(specs.length<k&&guard++<5000){const s=randSpec(r);pick(rule.terms,r).forEach(c=>s[c.k]=c.v);specs.push(s)}
  guard=0;
  while(specs.length<total&&guard++<20000){
    const s=r()<.5?nearMiss(rule,r):randSpec(r);
    if(!s||rule.terms.some(t=>termHolds(t,s)))continue;
    specs.push(s);
  }
  return specs.length===total?shuffle(specs,r):null;
}
// scatter critters in the dish, never touching
function place(n,r){
  for(let att=0;att<50;att++){
    const pos=[];let guard=0;
    while(pos.length<n&&guard++<6000){
      const a=r()*2*Math.PI,d=Math.sqrt(r())*DISH_R,x=Math.cos(a)*d,y=Math.sin(a)*d;
      if(pos.every(q=>Math.hypot(q[0]-x,q[1]-y)>=MIN_GAP))pos.push([x,y]);
    }
    if(pos.length===n)return pos;
  }
  return null;
}
function gen(rng,depth){
  const c=CFG[depth]||CFG[1],total=c.n;
  for(let tries=0;tries<300;tries++){
    const kind=pick(c.kinds,rng);
    const k=int(rng,c.k[0],c.k[1]);
    let out=null;
    if(kind==='switch'){
      const A=makeRule(pick(['and2','and3'],rng),rng);let B;
      do{B=makeRule(pick(['and2','or'],rng),rng)}while(JSON.stringify(A)===JSON.stringify(B));
      const specs=[];let guard=0;
      while(specs.length<k&&guard++<5000){const s=randSpec(rng);pick(A.terms,rng).forEach(q=>s[q.k]=q.v);if(!B.terms.some(t=>termHolds(t,s)))specs.push(s)}
      const kb=int(rng,c.k[0],c.k[1]);guard=0;
      while(specs.length<k+kb&&guard++<5000){const s=randSpec(rng);pick(B.terms,rng).forEach(q=>s[q.k]=q.v);if(!A.terms.some(t=>termHolds(t,s)))specs.push(s)}
      guard=0;
      while(specs.length<total&&guard++<20000){
        const s=rng()<.5?nearMiss(rng()<.5?A:B,rng):randSpec(rng);
        if(!s||A.terms.some(t=>termHolds(t,s))||B.terms.some(t=>termHolds(t,s)))continue;specs.push(s);
      }
      if(specs.length!==total)continue;
      const sh=shuffle(specs,rng);
      const ma=matches(A,sh),mb=matches(B,sh);
      if(ma.length!==k||mb.length!==kb)continue;
      out={specs:sh,rules:[A,B],answers:[ma,mb]};
    }else{
      const rule=makeRule(kind,rng);
      const specs=genAttr(rule,total,k,rng);
      if(!specs)continue;
      const m=matches(rule,specs);
      if(m.length!==k)continue;
      out={specs,rules:[rule],answers:[m]};
    }
    const pos=place(total,rng);if(!pos)continue;
    return Object.assign(out,{pos,time:c.time,swim:c.swim});
  }
  throw new Error('anomaly2: no puzzle');
}
function score(found,total,wrong,timeLeftFrac){
  const base=total?found/total:0;
  return Math.max(0,base*Math.max(0,1-.12*wrong)*(.85+.15*Math.min(1,timeLeftFrac/.3)));
}

const logic={CFG,gen,matches,score,ruleText,makeRule,DISH_R,MIN_GAP};
if(typeof TK==='undefined'){if(typeof module!=='undefined'&&module.exports)module.exports=logic;return}

// ---------- pixel view: the microscope feed ----------
const PAL=TK.PAL;
function hex(c){return[parseInt(c.slice(1,3),16),parseInt(c.slice(3,5),16),parseInt(c.slice(5,7),16)]}
function shade(c,f){const[r,g,b]=hex(c),m=v=>Math.max(0,Math.min(255,Math.round(f<0?v*(1+f):v+(255-v)*f)));return'#'+[m(r),m(g),m(b)].map(v=>v.toString(16).padStart(2,'0')).join('')}
const BAY=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5];
const bay=(x,y)=>(BAY[(y&3)*4+(x&3)]+.5)/16;
function dot(g,x,y,c){g.fillStyle=c;g.fillRect(Math.round(x),Math.round(y),1,1)}
function ringPx(g,cx,cy,r,c,every){const n=Math.max(8,Math.round(r*7)),seen=new Set();g.fillStyle=c;
  for(let k=0;k<n;k++){if(every&&k%every)continue;const a=k/n*2*Math.PI,x=Math.round(cx+r*Math.cos(a)),y=Math.round(cy+r*Math.sin(a)),key=x*999+y;if(seen.has(key))continue;seen.add(key);g.fillRect(x,y,1,1)}}
const CONTROLS=['click'];
const ICW={click:13,hold:21,drag:22,'drag-h':22,'drag-v':22,dial:13};
function startCard(g,hint,ctl,cx,y,t,bg,edge){const tw=hint.length*4-1,iw=ctl.reduce((a,k)=>a+ICW[k]+4,-4),w=Math.max(tw,iw)+10,h=26,x=Math.round(cx-w/2);
  g.fillStyle=edge;g.fillRect(x-1,y-1,w+2,h+2);g.fillStyle=bg;g.fillRect(x,y,w,h);TK.text(g,hint,cx,y+3,TK.PAL.hot,'center');
  let ix=Math.round(cx-iw/2);for(const k of ctl){TK.icon(g,k,ix,y+11,{t});ix+=ICW[k]+4}}

const W=144,H=124,CX=72,CY=69,LENS=52; // the same 144x124 screen as Pulsar Fold 2 and Gravity Sling 2; dish centre, lens radius
const K=1.6;                            // critter scale: every telling detail drawn big
const SP=35,SH=17;                       // sprite box and its centre

// colours of a stained brightfield slide
const MEM=shade(PAL.good,-.62),CYTO=shade(PAL.good,.18),CYTO2=PAL.good,LIT=shade(PAL.good,.55),NUC=PAL.t3,NUC2=shade(PAL.t3,.45),NUCD=shade(PAL.t3,-.55),HALO=shade(PAL.t2,-.25),HALO2=shade(PAL.t2,.3);

// one critter drawn into a small sprite, rotation in 45 degree steps, tail phase 0..3
function critter(s,rot,phase,seed){
  const cv=document.createElement('canvas');cv.width=SP;cv.height=SP;const g=cv.getContext('2d');
  const a=rot*Math.PI/4,ca=Math.cos(a),sa=Math.sin(a);
  const loc=(x,y)=>{const dx=x-SH,dy=y-SH;return[dx*ca+dy*sa,-dx*sa+dy*ca]}; // into the critter's frame, head toward -v
  const wob=k=>Math.sin(k*3+seed)*.2;
  const inside=(u,v,sc)=>{sc=(sc||1)*K;u/=sc;v/=sc;
    if(s.shape===0){const r=Math.hypot(u,v),t=Math.atan2(v,u);return r<=4.4+wob(t)}
    if(s.shape===1){const vv=Math.max(-3.4,Math.min(3.4,v));return Math.hypot(u+Math.sin(v*.35+seed)*.4,v-vv)<=2.6}
    const r=Math.hypot(u,v),t=Math.atan2(v,u);return r<=3.1+2.6*Math.pow(Math.abs(Math.cos(2.5*t+seed*.2)),1.6)};
  // tail first, behind the body: a wavy flagellum off the back end
  // a bold whip: two pixels thick, long, waving
  if(s.tail){const back=(s.shape===1?5.6:s.shape===0?4.2:4.0)*K;
    for(let k=0;k<20;k++){const v=back+k*.55,u=Math.sin(k*.42+phase*Math.PI/2)*(.5+k*.16);
      const x=SH+u*ca-v*sa,y=SH+u*sa+v*ca;g.fillStyle=k<14?MEM:shade(PAL.good,-.4);g.fillRect(Math.round(x-.5),Math.round(y-.5),k<14?2:1,k<14?2:1)}}
  // body, membrane, halo
  for(let y=0;y<SP;y++)for(let x=0;x<SP;x++){
    const[u,v]=loc(x+.5,y+.5);
    if(inside(u,v)){
      const edge=!inside(u+.95,v)||!inside(u-.95,v)||!inside(u,v+.95)||!inside(u,v-.95);
      const lt=(-(x-SH)-(y-SH))/(6*K);
      g.fillStyle=edge?MEM:lt>.55?LIT:lt>-.2?CYTO:(bay(x,y)<.5?CYTO2:CYTO);g.fillRect(x,y,1,1);
    }else if(s.ring&&inside(u,v,1.62)&&!inside(u,v,1.3)){g.fillStyle=inside(u,v,1.46)?HALO2:HALO;g.fillRect(x,y,1,1)} // a thick blue halo
  }
  // stained nuclei
  const spots=[[0,0],[[-1.7,-1.2],[1.7,1.2]],[[-1.9,-1.5],[1.9,-1.5],[0,2.1]]];
  const rodSpots=[[0,0],[[0,-1.9],[0,1.9]],[[0,-3.1],[0,0],[0,3.1]]];
  // bold stained nuclei: 3x3 with a dark rim, set well apart so they count at a glance
  if(s.spots){const L=(s.shape===1?rodSpots:spots);const set=s.spots===1?[[0,0]]:L[s.spots-1];
    for(const[u0,v0]of set){const u=u0*K,v=v0*K,x=SH+u*ca-v*sa,y=SH+u*sa+v*ca,X=Math.round(x-1.5),Y=Math.round(y-1.5);
      g.fillStyle=NUCD;g.fillRect(X-1,Y,5,3);g.fillRect(X,Y-1,3,5);g.fillStyle=NUC;g.fillRect(X,Y,3,3);g.fillStyle=NUC2;g.fillRect(X,Y,1,1)}}
  return cv;
}

function mount(stage,ctx){
  const pz=gen(ctx.rng,ctx.depth),sn=ctx.sensors|0;
  const T=pz.time+4*sn;
  let phase=0,found=0,wrong=0,finished=false,timeLeft=T,started=false,clock=0,last=0,raf=0,ruleFlash=-9;
  const total=pz.answers.reduce((a,b)=>a+b.length,0);
  const marked=new Set(),fx=[];
  const p=TK.pixel(stage,{w:W,h:H});const g=p.g;
  // critters: position, heading, sprite cache
  const seeds=pz.specs.map((_,i)=>((i*2654435761)>>>0)%100/16);
  const crit=pz.specs.map((s,i)=>({s,x:pz.pos[i][0],y:pz.pos[i][1],rot:s.rot,swim:pz.swim&&s.tail,ph:i%4}));
  const cache=new Map();
  const sprite=(i,rot,ph)=>{const k=i*64+rot*4+ph;let c=cache.get(k);if(!c){c=critter(pz.specs[i],rot,ph,seeds[i]);cache.set(k,c)}return c};
  let hints=[];
  function pickHints(){const left=pz.answers[phase].filter(i=>!marked.has(i));const nh=sn>=4?2:sn>=2?1:0;hints=shuffle(left,ctx.rng).slice(0,nh)}
  pickHints();

  // static layers: the lit slide under the critters, and the lens over them
  const under=document.createElement('canvas');under.width=W;under.height=H;const u=under.getContext('2d');
  u.fillStyle=PAL.void;u.fillRect(0,0,W,H);
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){const r=Math.hypot(x+.5-CX,y+.5-CY);if(r>LENS)continue;
    const t=r/LENS;let col=t<.45?PAL.ice:t<.72?(bay(x,y)<(t-.45)/.27?PAL.chill:PAL.ice):(bay(x,y)<(t-.72)/.28?PAL.cold:PAL.chill);
    u.fillStyle=col;u.fillRect(x,y,1,1)}
  {let hs=(pz.pos.length*7919+pz.specs[0].rot)|1;const hr=()=>{hs=(hs*1103515245+12345)&0x7fffffff;return hs/0x7fffffff};
    for(let k=0;k<40;k++){const a=hr()*6.28,d=Math.sqrt(hr())*LENS*.9;dot(u,CX+Math.cos(a)*d,CY+Math.sin(a)*d,hr()<.5?PAL.chill:PAL.cold)}}
  const over=document.createElement('canvas');over.width=W;over.height=H;const o=over.getContext('2d');
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){const r=Math.hypot(x+.5-CX,y+.5-CY);
    if(r>LENS+3){o.fillStyle=PAL.panel;o.fillRect(x,y,1,1);continue}
    if(r>LENS){const lt=(-(x-CX)-(y-CY))/r;o.fillStyle=r>LENS+2?PAL.bevelLo:lt>.3?PAL.bevelHi:lt<-.3?PAL.bevelLo:PAL.line;o.fillRect(x,y,1,1);continue}
    // soft focus and lens fall-off toward the rim
    const t=(r-LENS*.82)/(LENS*.18);if(t>0&&bay(x,y)<t*.85){o.fillStyle=t>.7?PAL.line:PAL.cold;o.fillRect(x,y,1,1)}}
  // a faint reticle
  for(let k=-LENS+8;k<=LENS-8;k+=2){if(Math.abs(k)<4)continue;o.fillStyle=shade(PAL.cold,.2);o.fillRect(CX+k,CY,1,1);o.fillRect(CX,CY+k,1,1)}

  function drawRule(){
    const r=pz.rules[phase],lines=ruleText(r),fl=clock-ruleFlash<1.2;
    g.fillStyle=fl?shade(PAL.ember,-.6):PAL.panel;g.fillRect(0,0,W,13);g.fillStyle=PAL.bevelLo;g.fillRect(0,13,W,1);
    if(lines.length===1)TK.text(g,lines[0],W/2,4,PAL.hot,'center');
    else{TK.text(g,lines[0],2,1,PAL.hot);TK.text(g,'OR',W-2,4,PAL.cold,'right');TK.text(g,lines[1],2,7,PAL.hot)}
    if(pz.rules.length>1)TK.text(g,'RULE '+(phase+1),W-2,15,PAL.ember,'right');
  }
  function draw(){
    g.drawImage(under,0,0);
    const t=Math.floor(clock*6)%4;
    for(const i of hints){const c=crit[i];const X=Math.round(CX+c.x),Y=Math.round(CY+c.y);
      for(let y=-15;y<=15;y++)for(let x=-15;x<=15;x++){const r=Math.hypot(x,y);if(r>10&&r<15&&bay(X+x,Y+y)<(15-r)/10)dot(g,X+x,Y+y,PAL.hot)}}
    crit.forEach((c,i)=>{const X=Math.round(CX+c.x)-SH,Y=Math.round(CY+c.y)-SH;g.drawImage(sprite(i,c.rot,c.s.tail?(t+c.ph)%4:0),X,Y)});
    // marks
    for(const i of marked){const c=crit[i];ringPx(g,CX+c.x,CY+c.y,12.5,PAL.ember);ringPx(g,CX+c.x,CY+c.y,13.5,PAL.ember);ringPx(g,CX+c.x,CY+c.y,14.5,shade(PAL.ember,-.4),2)}
    for(let k=fx.length-1;k>=0;k--){const f=fx[k],a=clock-f.t0;if(a>f.life){fx.splice(k,1);continue}
      const c=crit[f.i];const x=CX+c.x,y=CY+c.y;
      if(f.bad){ringPx(g,x,y,13.5,PAL.bad,a>.6?2:0);if(a<.6){for(let d=-5;d<=5;d++){dot(g,x+d,y+d,PAL.bad);dot(g,x+d,y-d,PAL.bad)}}}
      else ringPx(g,x,y,14+a*16,PAL.flare,2)}
    g.drawImage(over,0,0);
    // timer arc round the lens
    const fr=timeLeft/T;const n=Math.round(fr*120);
    for(let k=0;k<n;k++){const a=-Math.PI/2+k/120*2*Math.PI;dot(g,CX+(LENS+1.5)*Math.cos(a),CY+(LENS+1.5)*Math.sin(a),fr<.25?PAL.bad:PAL.ember)}
    drawRule();
    // corners
    const need=pz.answers[phase].length,got=pz.answers[phase].filter(i=>marked.has(i)).length;
    TK.text(g,'FOUND',2,17,PAL.cold);TK.text(g,got+'/'+need,2,23,got===need?PAL.good:PAL.hot);
    TK.text(g,'TIME',W-2,pz.rules.length>1?22:17,PAL.cold,'right');TK.text(g,String(Math.ceil(timeLeft)),W-2,pz.rules.length>1?28:23,fr<.25?PAL.bad:PAL.hot,'right');
    TK.text(g,'WRONG',2,H-12,PAL.cold);TK.text(g,String(wrong),2,H-6,wrong?PAL.bad:PAL.chill);
    if(finished)TK.text(g,found===total?'ALL LOGGED':'TIME',W-2,H-6,found===total?PAL.good:PAL.hot,'right');
    if(!started)startCard(g,'FIND EVERY MATCH',CONTROLS,W/2,CY-13,clock,PAL.panel,PAL.bevelHi);
    drawLoupe();
  }
  function step(dt){
    if(!started||finished)return;
    timeLeft=Math.max(0,timeLeft-dt);
    if(pz.rules.length>1&&phase===0&&timeLeft<T*.5)nextPhase();
    // swimmers drift head-first and turn at the glass
    for(const c of crit){if(!c.swim)continue;const a=c.rot*Math.PI/4;
      c.x+=Math.sin(a)*3.2*dt;c.y-=Math.cos(a)*3.2*dt;
      if(Math.hypot(c.x,c.y)>DISH_R){c.x*=DISH_R/Math.hypot(c.x,c.y);const toC=Math.atan2(-c.x,c.y);c.rot=((Math.round(toC/(Math.PI/4))%8)+8)%8}}
    if(timeLeft<=0)end();
  }
  function frame(now){raf=requestAnimationFrame(frame);if(now-last<32)return;const dt=Math.min(.1,(now-last)/1000);last=now;clock+=dt;step(dt);draw()}

  const ptf=e=>{const r=p.cv.getBoundingClientRect();return{x:(e.clientX-r.left)*W/r.width,y:(e.clientY-r.top)*H/r.height}};
  // a quick tap marks; press and hold opens a loupe over the slide instead (release to close it)
  const nearest=q=>{let best=-1,bd=13;crit.forEach((c,i)=>{const d=Math.hypot(CX+c.x-q.x,CY+c.y-q.y);if(d<bd){bd=d;best=i}});return best};
  let press=null;
  p.cv.addEventListener('pointerdown',e=>{
    if(finished)return;e.preventDefault();
    if(!started){started=true;last=performance.now()}
    try{p.cv.setPointerCapture(e.pointerId)}catch(_){}
    const q=ptf(e);press={id:e.pointerId,q,t:performance.now(),loupe:false};
  });
  p.cv.addEventListener('pointermove',e=>{const q=ptf(e);
    if(press&&e.pointerId===press.id){press.q=q;e.preventDefault()}
    p.cv.style.cursor=!finished&&Math.hypot(q.x-CX,q.y-CY)<LENS?'crosshair':'default'});
  const release=e=>{if(!press||e.pointerId!==press.id)return;const pr=press;press=null;
    if(e.type!=='pointerup'||pr.loupe||finished)return;const i=nearest(ptf(e));if(i>=0)tap(i)};
  p.cv.addEventListener('pointerup',release);p.cv.addEventListener('pointercancel',release);
  const LOUPE_MS=300,LR=24; // loupe radius in canvas pixels, 2x zoom
  const snap=document.createElement('canvas');snap.width=W;snap.height=H;const sg=snap.getContext('2d');
  function drawLoupe(){
    if(!press||finished)return;
    if(!press.loupe&&performance.now()-press.t>=LOUPE_MS)press.loupe=true;
    if(!press.loupe)return;
    sg.clearRect(0,0,W,H);sg.drawImage(p.cv,0,0);
    const fx=Math.round(press.q.x),fy=Math.round(press.q.y);
    // sit the loupe above the finger, or below it near the top
    const lx=Math.max(LR+2,Math.min(W-LR-3,fx)),ly=fy-LR-14>LR+1?fy-LR-14:Math.min(H-LR-2,fy+LR+14);
    g.save();g.beginPath();g.arc(lx,ly,LR,0,Math.PI*2);g.clip();g.imageSmoothingEnabled=false;
    g.fillStyle=PAL.ice;g.fillRect(lx-LR,ly-LR,LR*2,LR*2);
    g.drawImage(snap,fx-LR/2,fy-LR/2,LR,LR,lx-LR,ly-LR,LR*2,LR*2);g.restore();
    ringPx(g,lx,ly,LR,PAL.bevelLo);ringPx(g,lx,ly,LR+1,PAL.chill);ringPx(g,lx,ly,LR+2,PAL.bevelLo);
  }
  function tap(i){
    if(finished||marked.has(i))return;
    if(pz.answers[phase].includes(i)){
      TK.sfx('anomaly2','mark');marked.add(i);found++;fx.push({i,t0:clock,life:.4});hints=hints.filter(h=>h!==i);
      if(pz.answers[phase].every(j=>marked.has(j)))nextPhase();
    }else{wrong++;fx.push({i,t0:clock,life:1.1,bad:true})}
  }
  function nextPhase(){TK.sfx('anomaly2','clear');
    if(phase+1<pz.rules.length){phase++;ruleFlash=clock;pickHints()}
    else{TK.sfx('anomaly2','win');end()}
  }
  function end(){
    if(finished)return;finished=true;
    ctx.done({score:score(found,total,wrong,timeLeft/T),detail:`Found ${found}/${total}, ${wrong} wrong`});
  }
  draw();raf=requestAnimationFrame(frame);
  return {
    destroy(){finished=true;cancelAnimationFrame(raf);p.destroy()},
    giveUp(){if(finished)return;finished=true;ctx.done({score:.5*score(found,total,wrong,0),detail:`Gave up, found ${found}/${total}`})},
    _test:{get phase(){return phase},get found(){return found},get wrong(){return wrong},get finished(){return finished},
      where(i){const c=crit[i];return[CX+c.x,CY+c.y]},answers:pz.answers,n:crit.length,cv:p.cv},
  };
}

TK.register({
  id:ID,name:'Anomaly Count 2',hint:'Find every match.',controls:CONTROLS,where:'Any survey site',skill:'Observation',
  blurb:'Spot every critter under the microscope that fits the rule.',
  how:[
    'The rule up top says what to look for.',
    'Wrong picks cost points.',
    'The ring round the lens is your time.',
    'Press and hold on the slide for a closer look.',
  ],
  deeper:'Sector 2+: three-part rules. Sector 3+: OR rules. Sector 4+: critters with tails swim. Sector 5: the rule changes halfway.',
  sensors:'Each point: 4 more seconds. 2+: one match faintly lit. 4+: two lit.',
  mount,
  _t:logic,
});
})();
