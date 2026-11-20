// Signal Tuning v2: pixel-art scope at the ship's science terminal. Same rules as tuning.js.
(function(){
'use strict';
const ID='tuning2';

// ---------- logic (verbatim from tuning.js) ----------
const CFG={
  1:{fmax:4,phase:false,amp:false,noise:0},
  2:{fmax:5,phase:false,amp:false,noise:0},
  3:{fmax:5,phase:true,amp:false,noise:0},
  4:{fmax:6,phase:true,amp:false,noise:.022},
  5:{fmax:6,phase:true,amp:true,noise:.032},
};
const AMPS=[.4,.55,.7,.85,1];
const BASE_PH=1,BASE_AMP=4,M=1200;
function gcd(a,b){return b?gcd(b,a%b):a}
function int(r,lo,hi){return lo+Math.floor(r()*(hi-lo+1))}

// s = {a,b,ph (0..7, steps of pi/4), amp (index)}
function points(s,from,to,m){
  m=m||M;from=from||0;to=to==null?Math.PI*2:to;const out=new Float64Array(m*2),A=AMPS[s.amp];
  for(let i=0;i<m;i++){const t=from+(to-from)*i/m;out[i*2]=A*Math.sin(s.a*t+s.ph*Math.PI/4);out[i*2+1]=Math.sin(s.b*t)}
  return out;
}
function oneWay(P,Q){
  let sum=0;const n=P.length/2,m=Q.length/2;
  for(let i=0;i<n;i+=4){let best=1e9;const x=P[i*2],y=P[i*2+1];
    for(let j=0;j<m;j++){const dx=x-Q[j*2],dy=y-Q[j*2+1],d=dx*dx+dy*dy;if(d<best)best=d}
    sum+=Math.sqrt(best)}
  return sum/Math.ceil(n/4);
}
function dist(P,Q){return Math.max(oneWay(P,Q),oneWay(Q,P))}
const MATCH=.012;
function degenerate(s){const full=points(s,0,Math.PI*2,600),half=points(s,0,Math.PI,600);return oneWay(full,half)<.02}
function par(c,from,to){
  let t=Math.abs(from.a-to.a)+Math.abs(from.b-to.b);
  if(c.phase){const d=Math.abs(from.ph-to.ph);t+=Math.min(d,8-d)}
  if(c.amp)t+=Math.abs(from.amp-to.amp);
  return t;
}
function bestPar(c,from,eq){return Math.min(...eq.map(t=>par(c,from,t)))}
function gen(rng,depth){
  const c=CFG[depth]||CFG[1];
  for(let tries=0;tries<500;tries++){
    const a=int(rng,1,c.fmax),b=int(rng,1,c.fmax);
    if(gcd(a,b)!==1||(a===1&&b===1))continue;
    const target={a,b,ph:c.phase?int(rng,0,7):BASE_PH,amp:c.amp?int(rng,0,3):BASE_AMP};
    if(degenerate(target))continue;
    const start={a:int(rng,1,c.fmax),b:int(rng,1,c.fmax),ph:c.phase?int(rng,0,7):BASE_PH,amp:c.amp?int(rng,1,4):BASE_AMP};
    const T=points(target);
    const eq=[];
    for(let ph=0;ph<8;ph++)for(let amp=0;amp<5;amp++){
      if((!c.phase&&ph!==target.ph)||(!c.amp&&amp!==target.amp))continue;
      const s2={a,b,ph,amp};if(dist(points(s2),T)<MATCH)eq.push(s2);
    }
    const pr=bestPar(c,start,eq);
    if(pr<3)continue;
    if(dist(points(start),T)<.15)continue;
    return {cfg:c,target,start,par:pr,T,eq};
  }
  throw new Error('tuning2: no puzzle');
}
function score(d,taps,pr,free){
  if(d<MATCH){const extra=Math.max(0,taps-pr-2-(free|0));return Math.max(.55,1-.05*extra)}
  return .35*Math.max(0,1-d/.25);
}
// the dials this sector has, as [key, lo, hi, wraps]
function dials(c){const k=[['a',1,c.fmax],['b',1,c.fmax]];if(c.phase)k.push(['ph',0,7,true]);if(c.amp)k.push(['amp',0,4]);return k}
// a dial sits on a right value when some matching setting has that value on it
function rightOn(g,key,v){return g.eq.some(e=>e[key]===v)}
// MATCH: how close you are in dial steps, 0 (as far as it gets) to 1 (there). It moves one notch
// per step, so turning the right way always shows.
function closeness(g,cur){const c=g.cfg;let mx=0;for(const[k,lo,hi,wrap]of dials(c))mx+=wrap?4:hi-lo;return Math.max(0,1-bestPar(c,cur,g.eq)/mx)}

const logic={CFG,AMPS,points,dist,gen,score,par,bestPar,MATCH,degenerate,dials,rightOn,closeness};
if(typeof TK==='undefined'){if(typeof module!=='undefined'&&module.exports)module.exports=logic;return}

// ---------- view: one pixel canvas ----------
const PW=144,PH=108;
const SC=[{x:1,lab:'TARGET'},{x:61,lab:'YOURS'}]; // scope frames, 58x58 at y=7
const SY=7,SS=58,R=24;
const KY=85,KR=8; // knob centre row, knob radius
const LOCK={x:118,y:74,w:25,h:22};

function mount(stage,ctx){
  const g=gen(ctx.rng,ctx.depth),c=g.cfg,sn=ctx.sensors|0;
  const cur=Object.assign({},g.start);
  if(sn>=3)cur.a=g.target.a;
  if(sn>=5){if(c.phase)cur.ph=g.target.ph;else cur.b=g.target.b}
  const parNow=bestPar(c,cur,g.eq);
  let taps=0,finished=false,destroyed=false,raf=0,curP=points(cur),d=dist(curP,g.T),meterV=0;
  const free=Math.floor(sn/2); // sensors: a spare step per two points before the score drops
  // noisy target: fixed jitter per point (same rng draws as round 1)
  const jit=new Float64Array(M*2);{const w=[0,1,2,3].map(()=>[2*Math.PI*(30+Math.floor(ctx.rng()*50))/M,ctx.rng()*7]);for(let i=0;i<M;i++){jit[i*2]=c.noise*(Math.sin(i*w[0][0]+w[0][1])+Math.sin(i*w[1][0]+w[1][1]))*.7;jit[i*2+1]=c.noise*(Math.sin(i*w[2][0]+w[2][1])+Math.sin(i*w[3][0]+w[3][1]))*.7}}

  const p=TK.pixel(stage,{w:PW,h:PH}),G=p.g,PAL=TK.PAL;
  p.cv.style.cursor='pointer';
  const px=(x,y,w,h,col)=>{G.fillStyle=col;G.fillRect(x,y,w||1,h||1)};

  // knobs: selector switches with detents
  const knobs=[];
  const addKnob=(lab,key,lo,hi,fmt,wrap)=>knobs.push({lab,key,lo,hi,fmt,wrap});
  addKnob('X FREQ','a',1,c.fmax,v=>String(v));
  addKnob('Y FREQ','b',1,c.fmax,v=>String(v));
  if(c.phase)addKnob('PHASE','ph',0,7,v=>String(v*45),true);
  if(c.amp)addKnob('X SIZE','amp',0,4,v=>AMPS[v].toFixed(2).slice(1));
  const slot=116/knobs.length;
  knobs.forEach((k,i)=>{k.cx=Math.round(slot*i+slot/2);k.cy=KY;k.n=k.wrap?8:k.hi-k.lo+1});
  // detent angle in degrees, 0 = straight up, clockwise
  const detA=(k,v)=>k.wrap?(v-k.lo)*45:(k.n===1?0:-135+270*(v-k.lo)/(k.n-1));
  // the detent nearest the finger; a right value pulls a little harder (it snaps in)
  function nearest(k,deg){
    let best=k.lo,bd=1e9;
    if(!k.wrap){deg=deg>180?deg-360:deg;deg=Math.max(-135,Math.min(135,deg))}
    for(let v=k.lo;v<=k.hi;v++){let dd=k.wrap?Math.abs(((deg-detA(k,v))%360+540)%360-180):Math.abs(deg-detA(k,v));if(rightOn(g,k.key,v))dd*=.6;if(dd<bd){bd=dd;best=v}}
    return best;
  }
  const isRight=k=>rightOn(g,k.key,cur[k.key]);
  function setKnob(k,v){acted=true;
    if(finished||v===cur[k.key])return;
    let dlt=Math.abs(v-cur[k.key]);if(k.wrap)dlt=Math.min(dlt,8-dlt);
    TK.sfx('tuning2','detent');cur[k.key]=v;taps+=dlt;curP=points(cur);d=dist(curP,g.T);near=nearMap(curP);
    if(isRight(k))k.click=performance.now(); // the detent clicks in: a short glow round the knob
  }

  // ---- drawing helpers ----
  function bevel(x,y,w,h,fill){px(x,y,w,h,PAL.bevelLo);px(x+1,y+1,w-2,h-2,fill);px(x+1,y+1,w-2,1,PAL.bevelHi);px(x+1,y+1,1,h-2,PAL.bevelHi)}
  function scopeFrame(x){
    // metal bezel, light top-left
    px(x,SY,SS,SS,PAL.bevelLo);px(x+1,SY+1,SS-2,SS-2,PAL.line);
    px(x+1,SY+1,SS-2,1,PAL.bevelHi);px(x+1,SY+1,1,SS-2,PAL.bevelHi);
    px(x+2,SY+SS-2,SS-3,1,'#151d28');px(x+SS-2,SY+2,1,SS-3,'#151d28');
    // glass, corners rounded
    const gx=x+3,gy=SY+3,gs=SS-6;
    px(gx,gy,gs,gs,'#05080d');
    for(const[cx,cy]of[[gx,gy],[gx+gs-1,gy],[gx,gy+gs-1],[gx+gs-1,gy+gs-1]])px(cx,cy,1,1,PAL.line);
    // graticule, dotted
    const cx=x+29,cy=SY+29;
    for(let k=-2;k<=2;k++){
      for(let t=-R;t<=R;t+=2){px(cx+k*R/2,cy+t,1,1,k?'#0f1824':'#16212f');px(cx+t,cy+k*R/2,1,1,k?'#0f1824':'#16212f')}
    }
    // faint glass glare, top-left (dithered)
    TK.dither(G,gx+2,gy+2,10,2,'#05080d','#101a26',.5);TK.dither(G,gx+2,gy+4,2,8,'#05080d','#101a26',.5);
  }
  // phosphor ramps (dim to hot) from the palette hues
  const RAMP_T=['#1b2d47','#2f4f78','#6a9ad4','#c3d2e2'];
  const RAMP_Y=['#3a2310','#7a4518','#d97b29','#ffd28a'];
  const RAMP_G=['#1f3328','#3f6a52','#7fb89a','#b8f5d8'];
  // which points of your curve already lie on the target's shape (within about a pixel): those
  // stretches draw green, so the match grows along the curve as you tune in. Nothing of the target
  // is drawn in YOURS.
  const NEAR=1.1/R;let near=null;
  function nearMap(P){const out=new Uint8Array(M),T=g.T,n2=NEAR*NEAR;
    for(let i=0;i<M;i++){const x=P[i*2],y=P[i*2+1];for(let j=0;j<M;j+=2){const dx=x-T[j*2],dy=y-T[j*2+1];if(dx*dx+dy*dy<n2){out[i]=1;break}}}
    // a lone near point where two curves only cross reads as noise: keep runs of 12 or more
    for(let i=0;i<M;){if(!out[i]){i++;continue}let j=i;while(j<M&&out[j])j++;if(j-i<12)for(let k=i;k<j;k++)out[k]=0;i=j}
    return out}
  near=nearMap(curP);
  function trace(x,P,ramp,head,jitter,wob,now,nr){
    const cx=x+29,cy=SY+29;
    // wob: a slow wander, a pixel or two, that dies away as each dial comes right
    const wx=i=>wob?Math.round(Math.sin(i*.031+now*.0021)*wob):0,wy=i=>wob?Math.round(Math.cos(i*.027+now*.0017)*wob):0;
    const pos=i=>[Math.round(cx+(P[i*2]+(jitter?jitter[i*2]:0))*R)+wx(i),Math.round(cy-(P[i*2+1]+(jitter?jitter[i*2+1]:0))*R)+wy(i)];
    // whole figure, dim
    for(let i=0;i<M;i+=2){const q=pos(i);G.fillStyle=nr&&nr[i]?RAMP_G[1]:ramp[0];G.fillRect(q[0],q[1],1,1)}
    // fading tail toward the head
    const tail=300;
    for(let j=0;j<tail;j++){const i=(head-tail+j+M)%M,q=pos(i),rr=nr&&nr[i]?RAMP_G:ramp;G.fillStyle=rr[j<tail*.45?1:j<tail*.85?2:3];G.fillRect(q[0],q[1],1,1)}
    // head with a dithered glow ring
    const h=pos(head);
    G.fillStyle=ramp[1];for(const[dx,dy]of[[-2,0],[2,0],[0,-2],[0,2],[-1,-1],[1,1],[1,-1],[-1,1]])G.fillRect(h[0]+dx,h[1]+dy,1,1);
    G.fillStyle=ramp[3];G.fillRect(h[0]-1,h[1],3,1);G.fillRect(h[0],h[1]-1,1,3);
  }
  function knob(k,active,now){
    const{cx,cy}=k,ok=isRight(k)&&!finished;
    // detent click: a dithered green ring that fades over half a second
    if(k.click&&now-k.click<500){const a=1-(now-k.click)/500;
      for(let y=-KR-6;y<=KR+6;y++)for(let x=-KR-6;x<=KR+6;x++){const r=Math.hypot(x,y);if(r>KR+4.5&&r<KR+6.5&&((x+y)&1)===0&&((x*7+y*13)&3)<a*4)px(cx+x,cy+y,1,1,PAL.good)}}
    // a right dial wears a steady green collar
    if(ok)for(let y=-KR-2;y<=KR+2;y++)for(let x=-KR-2;x<=KR+2;x++){const r2=x*x+y*y;if(r2>(KR+1)*(KR+1)&&r2<=(KR+2)*(KR+2)&&((x+y)&1)===0)px(cx+x,cy+y,1,1,'#3f6a52')}
    // detent ticks around the switch
    for(let v=k.lo;v<=k.hi;v++){const a=detA(k,v)*Math.PI/180,on=v===cur[k.key];
      const tx=Math.round(cx+Math.sin(a)*(KR+3)),ty=Math.round(cy-Math.cos(a)*(KR+3));
      px(tx,ty,1,1,on?(ok?PAL.mark:PAL.flare):PAL.cold);
      if(on){const tx2=Math.round(cx+Math.sin(a)*(KR+4)),ty2=Math.round(cy-Math.cos(a)*(KR+4));px(tx2,ty2,1,1,ok?PAL.mark:PAL.hot)}
    }
    // knob body: stepped metal, light from top-left, 1 px dark outline
    for(let y=-KR;y<=KR;y++)for(let x=-KR;x<=KR;x++){
      const r2=x*x+y*y;if(r2>KR*KR+KR)continue;
      let col;
      if(r2>(KR-1)*(KR-1)+KR-1)col=PAL.bevelLo;
      else{const l=(-x-y)/(KR*1.4);col=l>.45?PAL.chill:l>.05?PAL.cold:l>-.4?'#4a5a70':PAL.bevelHi;
        // grip notches on the rim
        if(r2>(KR-2)*(KR-2)&&((x+y)&1)===0&&r2<=(KR-1)*(KR-1)+KR-1)col=l>.05?'#56677d':'#2b3849'}
      px(cx+x,cy+y,1,1,col);
    }
    // cap
    for(let y=-4;y<=4;y++)for(let x=-4;x<=4;x++){const r2=x*x+y*y;if(r2>18)continue;px(cx+x,cy+y,1,1,r2>12?'#2b3849':(x+y<-2?PAL.chill:'#4a5a70'))}
    // pointer line
    const a=detA(k,cur[k.key])*Math.PI/180;
    for(let t=2;t<=KR-1;t++)px(Math.round(cx+Math.sin(a)*t),Math.round(cy-Math.cos(a)*t),1,1,active?PAL.hot:PAL.ember);
    TK.text(G,k.lab,cx,66,PAL.cold,'center');
    TK.text(G,k.fmt(cur[k.key]),cx,KY+KR+5,ok?PAL.mark:PAL.hot,'center');
  }
  let lockDown=false;
  function lockBtn(){
    const{x,y,w,h}=LOCK,pressed=lockDown||finished;
    px(x,y,w,h,PAL.bevelLo);
    const f=finished?(d<MATCH?PAL.good:PAL.cold):PAL.ember;
    px(x+1,y+1,w-2,h-2,f);
    if(!pressed){px(x+1,y+1,w-2,1,finished?f:PAL.hot);px(x+1,y+1,1,h-2,finished?f:PAL.flare);px(x+1,y+h-2,w-2,1,'#8a4a16');px(x+w-2,y+1,1,h-2,'#8a4a16')}
    else{px(x+1,y+1,w-2,1,'#8a4a16');px(x+1,y+1,1,h-2,'#8a4a16')}
    TK.text(G,'LOCK',Math.round(x+w/2)+(pressed?1:0),Math.round(y+h/2-2)+(pressed?1:0),PAL.void,'center');
  }
  let drag=null,lastFrame=0,acted=false;
  function draw(now){
    p.clear(PAL.panel);
    // faint panel texture and screw heads
    for(const[sx,sy]of[[1,1],[142,1],[1,106],[142,106]])px(sx,sy,1,1,PAL.bevelHi);
    const head=Math.floor(((now-t0)/4200%1)*M);
    SC.forEach((s,i)=>{scopeFrame(s.x);TK.text(G,s.lab,s.x+29,1,i?PAL.flare:PAL.t2,'center')});
    trace(SC[0].x,g.T,RAMP_T,head,c.noise?jit:null);
    const wrong=knobs.filter(k=>!isRight(k)).length;
    trace(SC[1].x,curP,(finished||!wrong)&&d<MATCH?RAMP_G:RAMP_Y,head,null,finished?0:wrong/knobs.length*1.6,now,near);
    if(finished){const ok=d<MATCH;const s=ok?'MATCH':'OFF';const wpx=s.length*4-1,bx=SC[1].x+29-Math.floor(wpx/2)-2;
      px(bx,SY+44,wpx+4,9,PAL.bevelLo);TK.text(G,s,SC[1].x+29,SY+46,ok?PAL.mark:PAL.bad,'center')}
    // right column: par, steps, fit meter
    const rx=131;
    TK.text(G,'PAR',rx,9,PAL.cold,'center');TK.text(G,String(parNow),rx,16,PAL.hot,'center');
    TK.text(G,'STEP',rx,25,PAL.cold,'center');TK.text(G,String(taps),rx,32,taps>parNow+2+free?PAL.flare:PAL.hot,'center');
    {// MATCH: a segmented meter that climbs as you tune in; a fine needle eases to it
      const mx=125,my=40,mh=24,f=closeness(g,cur);meterV+=(f-meterV)*.25;
      const segs=11,n=Math.round(meterV*segs);
      px(mx,my,13,mh,PAL.bevelLo);px(mx+1,my+1,11,mh-2,'#05080d');
      for(let j=0;j<segs;j++){const yy=my+mh-3-j*2,on=j<n,top=f>=.999;
        px(mx+2,yy,9,1,!on?'#0f1824':top?PAL.mark:j>=segs-3?PAL.good:j>=segs-6?'#5f9a7c':'#3f6a52')}
      TK.text(G,'MATCH',rx,my+mh+2,f>=.999?PAL.mark:PAL.cold,'center');
    }
    knobs.forEach(k=>knob(k,drag&&drag.k===k,now));
    if(!acted&&!finished){const s='MATCH THE WAVE.',tw=s.length*4-1,iw=13+3+13,W=tw+4+iw,bx=72-Math.floor(W/2);px(bx-3,45,W+6,17,PAL.bevelLo);px(bx-2,46,W+4,15,PAL.panel);TK.text(G,s,bx,51,PAL.hot);const ts=(now-t0)/1000;let ix=bx+tw+4;ix+=TK.icon(G,'dial',ix,47,{t:ts})+3;TK.icon(G,'click',ix,47,{t:ts})}
    lockBtn();
  }
  const t0=performance.now();
  function frame(now){
    if(destroyed)return;
    if(now-lastFrame>=32){lastFrame=now;draw(now)}
    raf=requestAnimationFrame(frame);
  }
  raf=requestAnimationFrame(frame);

  // ---- input ----
  const inLock=q=>q.x>=LOCK.x-2&&q.x<LOCK.x+LOCK.w+2&&q.y>=LOCK.y-2&&q.y<LOCK.y+LOCK.h+2;
  function knobAt(q){let best=null,bd=1e9;for(const k of knobs){const dd=Math.hypot(q.x-k.cx,q.y-k.cy);if(dd<=KR+7&&dd<bd){bd=dd;best=k}}return best}
  function turnTo(k,q){const dx=q.x+.5-k.cx,dy=q.y+.5-k.cy;if(dx*dx+dy*dy<4)return;
    const deg=(Math.atan2(dx,-dy)*180/Math.PI+360)%360;setKnob(k,nearest(k,deg))}
  function down(e){
    if(finished)return;const q=p.pt(e);
    const k=knobAt(q);
    if(k){e.preventDefault();try{p.cv.setPointerCapture(e.pointerId)}catch(_){}drag={k,id:e.pointerId};turnTo(k,q);return}
    if(inLock(q)){e.preventDefault();try{p.cv.setPointerCapture(e.pointerId)}catch(_){}lockDown=true;drag={lock:true,id:e.pointerId}}
  }
  function move(e){
    if(!drag||e.pointerId!==drag.id)return;e.preventDefault();const q=p.pt(e);
    if(drag.k)turnTo(drag.k,q);else lockDown=inLock(q);
  }
  function up(e){
    if(!drag||e.pointerId!==drag.id)return;const q=p.pt(e);
    const wasLock=drag.lock;drag=null;lockDown=false;
    if(wasLock&&e.type==='pointerup'&&inLock(q))doLock();
  }
  p.cv.addEventListener('pointerdown',down);p.cv.addEventListener('pointermove',move);
  p.cv.addEventListener('pointerup',up);p.cv.addEventListener('pointercancel',up);
  let doneT=0;
  function doLock(){acted=true;
    if(finished)return;finished=true;
    TK.sfx('tuning2','lock');const sc=score(d,taps,parNow,free);if(d<MATCH)TK.sfx('tuning2','win');
    doneT=setTimeout(()=>{if(!destroyed)ctx.done({score:sc,detail:d<MATCH?`Matched in ${taps} taps (par ${parNow})`:'Locked off target'})},700);
  }
  return {
    destroy(){destroyed=true;finished=true;cancelAnimationFrame(raf);clearTimeout(doneT);p.destroy();
      p.cv.removeEventListener('pointerdown',down);p.cv.removeEventListener('pointermove',move);p.cv.removeEventListener('pointerup',up);p.cv.removeEventListener('pointercancel',up)},
    giveUp(){if(finished)return;finished=true;ctx.done({score:0,detail:'Gave up'})},
    _test:{get match(){return closeness(g,cur)},isRight,knobs,LOCK,cur,g,get d(){return d},get taps(){return taps},canvas:p.cv},
  };
}

TK.register({
  id:ID,name:'Signal Tuning 2',where:'Beacons, pulsars, relay buoys',skill:'Pattern matching',
  blurb:'Tune two dials until your curve matches the beacon’s.',
  hint:'Match the wave.',
  controls:['dial','click'],
  how:[
    'Make YOURS match the TARGET. Parts that already match turn green.',
    'Turn a dial by dragging round it, or tap a tick. MATCH climbs as you get closer.',
    'A dial on a right value clicks in and goes green, and your curve steadies.',
    'Press LOCK when they match. Few steps score more.',
  ],
  deeper:'Sector 1-2: two dials. Sector 2+: higher frequencies. Sector 3+: a PHASE dial. Sector 4+: a noisy target. Sector 5: an X SIZE dial.',
  sensors:'Every two points: one spare step before the score drops. 3+: X FREQ starts right. 5: PHASE (or Y FREQ) starts right too.',
  mount,
  _t:logic,
});
})();
