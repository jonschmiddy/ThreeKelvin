// Leak Hunt: puff smoke in a dead station room, watch where it gets sucked, and patch the hidden hull leak.
(function(){
'use strict';
const ID='wreck3';
const PW=152,VH=92,HUD=26,PH=VH+HUD;   // art pixels: the drone's view of the room, then the control strip
const RX0=6,RX1=146,RY0=10,RY1=70;      // where a leak can be (the back wall above the consoles)
const CFG={
  1:{leaks:1,wind:0,S:450,life:2.6,tol:5,secs:60,spare:2},
  2:{leaks:1,wind:0,S:320,life:2.2,tol:4.5,secs:60,spare:2},
  3:{leaks:2,wind:0,S:400,life:2.4,tol:4.5,secs:85,spare:1},
  4:{leaks:1,wind:1,S:400,life:2.4,tol:4.5,secs:70,spare:1},
  5:{leaks:2,wind:1,S:330,life:2.2,tol:4,secs:95,spare:1},
};
const WIND=6;
const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));

function gen(depth,sensors,rng){
  const c=CFG[depth];
  const leaks=[];
  while(leaks.length<c.leaks){
    const x=RX0+6+rng()*(RX1-RX0-12),y=RY0+4+rng()*(RY1-RY0-8);
    if(leaks.some(l=>Math.hypot(l.x-x,l.y-y)<34))continue;
    leaks.push({x,y,open:true});
  }
  let wind=null;
  if(c.wind){const side=rng()<0.5?-1:1;wind={dir:-side,x:side<0?2:PW-3,y:22+rng()*40}}
  const patches=c.leaks+c.spare+(sensors>=3?1:0);
  const life=c.life+0.4*sensors;
  const T=c.secs+8*sensors;
  const parPuffs=3*c.leaks+(c.wind?1:0);
  return{leaks,wind,S:c.S,life,tol:c.tol,patches,T,parPuffs};
}
// the air flow: each open leak is a sink (speed falls off as 1/r), plus the fan's draft
function field(P,x,y){
  let vx=0,vy=0;
  for(const l of P.leaks){if(!l.open)continue;const dx=l.x-x,dy=l.y-y,r2=dx*dx+dy*dy+4;vx+=P.S*dx/r2;vy+=P.S*dy/r2}
  if(P.wind){const f=0.45+0.55*Math.exp(-(((y-P.wind.y)/26)**2));vx+=P.wind.dir*WIND*f}
  return[vx,vy];
}
function newSim(P){return{t:0,air:1,puffs:0,used:0,wrong:0,sealed:0,parts:[],over:false,won:false,events:[],patchesAt:[]}}
function puff(S,P,x,y,rnd){
  if(S.over)return;S.puffs++;
  for(let i=0;i<24;i++){const a=rnd()*6.283,r=Math.sqrt(rnd())*3;S.parts.push({x:x+Math.cos(a)*r,y:y+Math.sin(a)*r,age:0,life:P.life*(0.7+0.3*rnd()),trail:[],gone:false,j:rnd()*6.283})}
  S.events.push({type:'puff',x,y});
}
function patch(S,P,x,y){
  if(S.over||S.used>=P.patches)return;
  S.used++;
  let hit=null;for(const l of P.leaks)if(l.open&&Math.hypot(l.x-x,l.y-y)<=P.tol){hit=l;break}
  if(hit){hit.open=false;S.sealed++;S.patchesAt.push({x:hit.x,y:hit.y,ok:true});S.events.push({type:'sealed',x:hit.x,y:hit.y})}
  else{S.wrong++;S.patchesAt.push({x,y,ok:false});S.events.push({type:'wrong',x,y})}
  if(P.leaks.every(l=>!l.open)){S.won=true;S.over=true;S.events.push({type:'won'})}
  else if(S.used>=P.patches){S.over=true;S.events.push({type:'fail',why:'patches'})}
}
function step(S,P,dt){
  S.t+=dt;
  for(const p of S.parts){
    if(p.gone)continue;p.age+=dt;if(p.age>p.life){p.gone=true;continue}
    const[vx,vy]=field(P,p.x,p.y);
    const jx=Math.cos(p.j+p.age*3)*1.2,jy=Math.sin(p.j*1.3+p.age*2.5)*1.2; // a little curl so it reads as smoke
    let sx=(vx+jx)*dt,sy=(vy+jy)*dt;const m=Math.hypot(sx,sy);if(m>3){sx*=3/m;sy*=3/m}
    p.x+=sx;p.y+=sy;
    if(P.leaks.some(l=>l.open&&Math.hypot(l.x-p.x,l.y-p.y)<2.2)){p.gone=true;p.sucked=true}
    if(p.x<1||p.x>PW-2||p.y<1||p.y>VH-2)p.gone=true;
  }
  S.parts=S.parts.filter(p=>!p.gone||false);
  if(S.over)return;
  const open=P.leaks.filter(l=>l.open).length;
  S.air-=dt/P.T*(open/P.leaks.length)*(P.leaks.length>1?1:1);
  if(S.air<=0){S.air=0;S.over=true;S.events.push({type:'fail',why:'air'})}
}
function scoreOf(S,P){
  if(!S.won)return clamp(0.1+0.25*S.sealed/P.leaks.length,0,0.35);
  const extra=Math.max(0,S.puffs-P.parPuffs);
  return clamp(1-0.05*extra-0.2*S.wrong-0.25*clamp((0.55-S.air)/0.55),0.3,1);
}

// Test bot: watch each puff's first moments, step toward where the flow points, then patch.
function bot(P,rnd){
  const S=newSim(P);const dt=1/30;
  // where most of the vanished smoke went (two leaks can split a puff)
  const cluster=sk=>{let best=null,bn=-1;for(const p of sk){const n=sk.filter(q=>Math.hypot(q.x-p.x,q.y-p.y)<4).length;if(n>bn){bn=n;best=p}}if(!best)return{sx:0,sy:0,sn:0};const c=sk.filter(q=>Math.hypot(q.x-best.x,q.y-best.y)<4);return{sx:c.reduce((a,p)=>a+p.x,0)/c.length,sy:c.reduce((a,p)=>a+p.y,0)/c.length,sn:c.length}};
  const observe=(x,y)=>{
    const n0=S.parts.length;puff(S,P,x,y,rnd);const mine=S.parts.slice(n0);
    const cx0=mine.reduce((a,p)=>a+p.x,0)/mine.length,cy0=mine.reduce((a,p)=>a+p.y,0)/mine.length;
    let tt=0,lastC=[cx0,cy0];
    while(tt<0.4){step(S,P,dt);tt+=dt;const live=mine.filter(p=>!p.gone);if(live.length<12)break;lastC=[live.reduce((a,p)=>a+p.x,0)/live.length,live.reduce((a,p)=>a+p.y,0)/live.length];if(tt>=0.12&&Math.hypot(lastC[0]-cx0,lastC[1]-cy0)>3)break}
    const tObs=tt;
    while(tt<P.life){step(S,P,dt);tt+=dt}  // watch it out: where does the smoke vanish?
    const sk=mine.filter(p=>p.sucked);
    return{vx:(lastC[0]-cx0)/Math.max(tObs,dt),vy:(lastC[1]-cy0)/Math.max(tObs,dt),sucked:sk.length,...cluster(sk)};
  };
  let guard=0;
  while(!S.over&&guard++<12){
    let x=(RX0+RX1)/2,y=(RY0+RY1)/2;
    // start each search from a spot not already patched
    if(S.sealed||S.wrong){const done=S.patchesAt;let best=null,bd=-1;for(let gx=RX0+10;gx<RX1;gx+=20)for(let gy=RY0+6;gy<RY1;gy+=12){const d=Math.min(...done.map(p=>Math.hypot(p.x-gx,p.y-gy)));if(d>bd){bd=d;best=[gx,gy]}}x=best[0];y=best[1]}
    let est=[x,y];
    for(let it=0;it<4;it++){
      const o=observe(est[0],est[1]);
      if(o.sn>=3){est=[o.sx,o.sy];break}
      let vx=o.vx,vy=o.vy;if(P.wind){const f=0.45+0.55*Math.exp(-(((est[1]-P.wind.y)/26)**2));vx-=P.wind.dir*WIND*f}
      const sp=Math.hypot(vx,vy);if(sp<0.05)break;
      const r=Math.min(80,P.S/sp);
      const nx=clamp(est[0]+vx/sp*r,RX0,RX1),ny=clamp(est[1]+vy/sp*r,RY0,RY1);
      const moved=Math.hypot(nx-est[0],ny-est[1]);est=[nx,ny];
      if(moved<1.5)break;
    }
    patch(S,P,est[0],est[1]);
    for(let k=0;k<10;k++)step(S,P,dt);
  }
  return{S,score:scoreOf(S,P)};
}

// ---- pixel art ----
function banner(g,A,PW,y,big,ctrls,t){const iw=ctrls.reduce((a,k)=>a+(k==='click'?13:k==='hold'?21:22)+3,-3);const w=Math.max(big.length*4-1,iw)+10;const x=Math.floor(PW/2-w/2);g.fillStyle=A.bevelLo;g.fillRect(x,y,w,27);g.fillStyle=A.panel;g.fillRect(x+1,y+1,w-2,25);g.fillStyle=A.bevelHi;g.fillRect(x+1,y+1,w-2,1);TK.text(g,big,PW/2,y+4,A.hot,'center');let ix=Math.floor(PW/2-iw/2);for(const k of ctrls)ix+=TK.icon(g,k,ix,y+12,{t})+3}
const BAYER=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5];
const bt=(x,y)=>(BAYER[(y&3)*4+(x&3)]+.5)/16;

function mount(stage,ctx){
  const P=gen(ctx.depth,ctx.sensors,ctx.rng);const S=newSim(P);const A=TK.PAL;
  const M=['#080b11','#111823','#182230','#22303f','#2d3c4e','#3d4d61','#6b7d94','#8fa3ba','#c3d2e2'];
  const RED=['#1a0d0b','#2e1410','#4a1c16','#7a2f24',A.bad];
  const px=TK.pixel(stage,{w:PW,h:PH});const g=px.g;px.cv.style.cursor='crosshair';
  const put=(c,x,y,col)=>{c.fillStyle=col;c.fillRect(x,y,1,1)};
  const rnd=ctx.rng;
  let mode='smoke',raf=0,last=0,acc=0,doneFired=false,endT=0,status='',statusCol=A.chill,statusT=0;const timers=[];const fx=[];
  // --- static room ---
  const st=document.createElement('canvas');st.width=PW;st.height=VH;const s=st.getContext('2d');
  const lamp={x:14,y:6};
  for(let y=0;y<VH;y++)for(let x=0;x<PW;x++){
    let c;
    if(y<5){c=y===4?0:(y===1?3:2)}                                  // ceiling
    else if(y>=78){c=((x+(y>>1))%4===0||y===78)?1:2;if(y===79)c=4}   // floor grating
    else{
      const pxl=(x-1)%30,py=(y-5)%24;
      c=2;
      if(bt(x,y)<0.25)c=3;
      if(pxl===0||py===0)c=4;                       // lit panel edge (top-left)
      if(pxl===29||py===23)c=1;                     // seam shadow
    }
    // the emergency lamp's light pool, top-left, falls off in dithered steps
    const d=Math.hypot(x-lamp.x,(y-lamp.y)*1.3);
    let light=clamp(1-d/90);
    if(bt(x,y)<light*0.7&&c<6)c++;
    put(s,x,y,M[Math.min(7,c)]);
    if(d<34&&y>4&&bt(x,y)<(1-d/34)*0.9)put(s,x,y,d<12?RED[3]:d<22?RED[2]:RED[1]);
  }
  // ceiling pipe
  for(let x=0;x<PW;x++){put(s,x,6,M[5]);put(s,x,7,M[4]);put(s,x,8,M[2]);put(s,x,9,M[0]);if(x%24===5){put(s,x,5,M[6]);put(s,x,6,M[7]);put(s,x,7,M[5]);put(s,x,8,M[3])}}
  // the dead screen and a vent grille
  const scr={x:52+Math.floor(rnd()*30),y:20};
  for(let y=0;y<14;y++)for(let x=0;x<22;x++){const e=x===0||y===0||x===21||y===13;put(s,scr.x+x,scr.y+y,e?(x===0||y===0?M[5]:M[0]):(bt(x,y)<0.12?M[3]:M[1]))}
  TK.text(s,'NO SIG',scr.x+11,scr.y+5,M[3],'center');
  const vg={x:110,y:16};for(let y=0;y<10;y++)for(let x=0;x<16;x++){put(s,vg.x+x,vg.y+y,y%2?M[0]:M[4])}
  // a porthole: stars and a slice of planet outside
  const po={x:scr.x<80?122:28,y:44,r:9};
  for(let y=-po.r-2;y<=po.r+2;y++)for(let x=-po.r-2;x<=po.r+2;x++){const d=Math.hypot(x,y);const X=po.x+x,Y=po.y+y;
    if(d<=po.r){let c=A.void;const pd=Math.hypot(x-10,y-12);if(pd<13)c=pd>12?M[6]:(bt(X,Y)<0.4?'#1a2628':'#0f1719');else if((X*31+Y*17)%29===0)c=M[7];
      if(x+y<-9&&d>po.r-2&&bt(X,Y)<0.5)c=M[4]; // glare on the glass
      put(s,X,Y,c)}
    else if(d<=po.r+1.2)put(s,X,Y,(x+y<0)?M[6]:M[3]);
    else if(d<=po.r+2.2)put(s,X,Y,M[0])}
  // a loose cable hanging from the ceiling pipe
  {const cx=scr.x<80?96:44;for(let i=0;i<18;i++){const x=cx+Math.round(Math.sin(i*0.35)*2),y=10+i;put(s,x,y,A.warn);put(s,x+1,y,'#3e3016')}put(s,cx,28,A.hot)}
  // consoles along the floor, and a tipped chair
  for(const[cx,w]of[[4,30],[104,44]]){for(let y=66;y<78;y++)for(let x=cx;x<cx+w;x++){const e=x===cx||y===66||x===cx+w-1;put(s,x,y,e?(y===66||x===cx?M[6]:M[0]):(y<69?M[5]:M[3]))}
    for(let x=cx+3;x<cx+w-3;x+=4)put(s,x,68,(x*13)%5===0?A.bad:M[2])}
  for(let i=0;i<7;i++){put(s,60+i,74-Math.floor(i/2),M[5]);put(s,60+i,75-Math.floor(i/2),M[0])}for(let y=0;y<5;y++){put(s,60,70+y,M[5]);put(s,66,71+y,M[4])}
  TK.text(s,'DECK 4',PW-28,VH-10,M[3]);
  // the lamp itself
  for(let y=0;y<3;y++)for(let x=-3;x<=3;x++)put(s,lamp.x+x,lamp.y-1+y,y===0?M[6]:RED[4]);
  // the fan (sector 4+)
  // floating junk drifts on the flow, slowly
  const junk=[];const kinds=['mug','pad','tool','sheet','sheet'];
  for(let i=0;i<5;i++)junk.push({k:kinds[i],x:RX0+10+rnd()*(RX1-RX0-20),y:RY0+20+rnd()*40,vx:(rnd()-.5)*2,vy:(rnd()-.5)*2,ang:rnd()*4});
  const motes=[];for(let i=0;i<14;i++)motes.push({x:rnd()*PW,y:10+rnd()*60,ph:rnd()*6});

  function toArt(e){const r=px.cv.getBoundingClientRect();return[(e.clientX-r.left)/r.width*PW,(e.clientY-r.top)/r.height*PH]}
  const BTN=[{id:'smoke',x:2,w:44,lab:'SMOKE'},{id:'patch',x:48,w:44,lab:'PATCH'}];const by=VH+8,bh=16;
  function onDown(e){
    if(S.over)return;e.preventDefault();const[x,y]=toArt(e);
    if(y>=VH){for(const b of BTN)if(x>=b.x&&x<b.x+b.w&&y>=by-1&&y<=by+bh){mode=b.id}return}
    if(y<5||y>=78)return;
    if(mode==='smoke'){TK.sfx('wreck3','puff');puff(S,P,x,y,Math.random)}
    else{if(S.used>=P.patches)return;patch(S,P,x,y);mode='smoke'}
  }
  px.cv.addEventListener('pointerdown',onDown);
  function say(t,c,sec){status=t;statusCol=c;statusT=sec||2}
  function events(){
    while(S.events.length){const ev=S.events.shift();
      if(ev.type==='sealed'){TK.sfx('wreck3','seal');fx.push({k:'clank',x:ev.x,y:ev.y,age:0,life:0.6,ok:true});say(S.won?'SEALED':'ONE SEALED',A.good,S.won?99:2.5)}
      else if(ev.type==='wrong'){fx.push({k:'clank',x:ev.x,y:ev.y,age:0,life:0.6,ok:false});say('STILL LEAKING',A.bad,2.5)}
      else if(ev.type==='won'){endT=S.t;TK.sfx('wreck3','win');}
      else if(ev.type==='fail'){endT=S.t;say(ev.why==='air'?'AIR GONE':'NO PATCHES',A.bad,99)}
    }
  }
  function finish(){if(doneFired)return;doneFired=true;ctx.done({score:scoreOf(S,P),detail:S.won?`Sealed with ${S.puffs} puffs, ${S.wrong} wrong patch${S.wrong===1?'':'es'}, ${Math.round(S.air*100)}% air left`:(`${S.sealed} of ${P.leaks.length} sealed`)})}
  function draw(){
    const t=S.t;
    g.drawImage(st,0,0);
    // the lamp flickers: its pool dims a step now and then
    if(Math.sin(t*7)+Math.sin(t*13.3)>1.6)for(let y=5;y<40;y++)for(let x=0;x<50;x++)if(bt(x,y)<0.3)put(g,x,y,M[1]);
    // fan
    if(P.wind){const w=P.wind;const fx0=w.dir>0?0:PW-7;for(let y=-8;y<=8;y++)for(let x=0;x<7;x++){const e=y===-8||y===8||x===0||x===6;put(g,fx0+x,Math.round(w.y)+y,e?M[5]:M[1])}
      const a=t*14;for(let k=0;k<3;k++){const aa=a+k*2.094;for(let r=1;r<=6;r++){put(g,Math.round(fx0+3+Math.cos(aa)*r*0.45),Math.round(w.y+Math.sin(aa)*r),M[6])}}
      put(g,fx0+3,Math.round(w.y),A.hot);
      // ribbon streamers flutter in the draft
      for(const dy of[-6,0,6]){for(let i=1;i<=6;i++){const x=w.dir>0?7+i:PW-8-i;put(g,x,Math.round(w.y+dy+Math.sin(t*12+i+dy)*i*0.25),i%2?A.ember:A.flare)}}}
    // motes drift idly in the lamp light
    for(const m of motes){const x=Math.round(m.x+Math.sin(t*0.3+m.ph)*4),y=Math.round(m.y+Math.cos(t*0.25+m.ph)*3);if(bt(x,y)<0.6)put(g,x,y,M[4])}
    // patches on the wall
    for(const p of S.patchesAt){const x=Math.round(p.x)-3,y=Math.round(p.y)-3;for(let j=0;j<7;j++)for(let i=0;i<7;i++){const e=i===0||j===0||i===6||j===6;put(g,x+i,y+j,e?(i===0||j===0?M[7]:M[0]):M[5])}
      for(const[i,j]of[[1,1],[5,1],[1,5],[5,5]])put(g,x+i,y+j,M[7]);put(g,x+3,y+3,p.ok?A.good:A.bad)}
    // junk
    for(const j of junk){const x=Math.round(j.x),y=Math.round(j.y);
      if(j.k==='mug'){for(let yy=0;yy<4;yy++)for(let xx=0;xx<3;xx++)put(g,x+xx,y+yy,xx===0?M[8]:M[6]);put(g,x+3,y+1,M[6]);put(g,x+3,y+2,M[6]);for(let xx=0;xx<3;xx++)put(g,x+xx,y+4,M[0])}
      else if(j.k==='pad'){for(let yy=0;yy<5;yy++)for(let xx=0;xx<4;xx++)put(g,x+xx,y+yy,yy===0?M[7]:(yy===2&&xx>0?A.tractor:M[4]));for(let xx=0;xx<4;xx++)put(g,x+xx,y+5,M[0])}
      else if(j.k==='tool'){const c=Math.cos(j.ang),s2=Math.sin(j.ang);for(let i=-3;i<=3;i++)put(g,Math.round(x+c*i),Math.round(y+s2*i),i>1?A.warn:M[7]);put(g,Math.round(x+c*4-s2),Math.round(y+s2*4+c),A.warn)}
      else{const f=Math.sin(t*3+j.ang)>0;for(let i=0;i<4;i++)put(g,x+i,y+(f&&i>1?1:0),M[8]);put(g,x,y+1,M[6])}
    }
    // smoke: a head pixel and a short fading trail per particle
    for(const p of S.parts){const k=p.age/p.life;
      for(let i=0;i<p.trail.length;i++){const q=p.trail[i];const tk=k+(p.trail.length-i)*0.06;if(bt(Math.round(q[0]),Math.round(q[1]))>(1-tk)*0.8)continue;put(g,Math.round(q[0]),Math.round(q[1]),tk<0.5?A.chill:A.cold)}
      const x=Math.round(p.x),y=Math.round(p.y);
      if(k<0.4){for(let j=-1;j<=1;j++)for(let i=-1;i<=1;i++){if(Math.abs(i)+Math.abs(j)>1&&bt(x+i,y+j)>0.5-k)continue;put(g,x+i,y+j,i+j<0?'#e6eef6':A.ice)}}
      else if(k<0.7){put(g,x,y,A.ice);if(bt(x+1,y)<0.7-k)put(g,x+1,y,A.chill)}
      else if(bt(x,y)<1.3-k)put(g,x,y,A.chill);
    }
    // effects
    for(const f of fx){const k=f.age/f.life;if(f.k==='clank'){const r=3+k*6;for(let a=0;a<16;a++){const aa=a/16*6.283;const x=Math.round(f.x+Math.cos(aa)*r),y=Math.round(f.y+Math.sin(aa)*r);if(bt(x,y)<1-k)put(g,x,y,f.ok?A.good:A.bad)}}}
    // drone light reticle in the middle, view frame
    for(const[x,y,dx,dy]of[[1,1,1,1],[PW-2,1,-1,1],[1,VH-2,1,-1],[PW-2,VH-2,-1,-1]])for(let i=0;i<5;i++){put(g,x+dx*i,y,M[6]);put(g,x,y+dy*i,M[6])}
    TK.text(g,'DRONE 2',4,VH-8,M[6]);
    if(!S.puffs&&!S.over)banner(g,A,PW,26,'PATCH THE LEAK',['click'],t);
    if(mode==='patch'&&!S.over){for(let x=2;x<PW-2;x++){if(bt(x,0)<0.5){put(g,x,1,A.ember);put(g,x,VH-2,A.ember)}}}
    // control strip
    g.fillStyle=A.panel;g.fillRect(0,VH,PW,HUD);g.fillStyle=A.bevelHi;g.fillRect(0,VH,PW,1);g.fillStyle=A.bevelLo;g.fillRect(0,VH+1,PW,1);
    for(const b of BTN){const on=mode===b.id;
      g.fillStyle=M[0];g.fillRect(b.x,by,b.w,bh);g.fillStyle=on?'#3a2416':M[4];g.fillRect(b.x+1,by+1,b.w-2,bh-2);
      g.fillStyle=on?A.ember:M[6];g.fillRect(b.x+1,by+1,b.w-2,1);g.fillRect(b.x+1,by+1,1,bh-2);g.fillStyle=on?'#1c120c':M[2];g.fillRect(b.x+1,by+bh-2,b.w-2,1);g.fillRect(b.x+b.w-2,by+1,1,bh-2);
      const ox=b.x+Math.floor(b.w/2),oy=by+8;
      if(b.id==='smoke'){for(const[i,j,r]of[[-5,1,3],[0,-1,4],[5,1,3],[2,2,3]])for(let yy=-r;yy<=r;yy++)for(let xx=-r;xx<=r;xx++){if(xx*xx+yy*yy>r*r)continue;put(g,ox+i+xx,oy+j+yy,(xx+yy<-1)?A.ice:A.chill)}for(let k=0;k<4;k++)put(g,ox-10+k,oy+4-k%2,M[6])}
      else{const n=P.patches-S.used;const x0=ox-12,y0=oy-5;for(let j=0;j<10;j++)for(let i=0;i<10;i++){const e=i===0||j===0||i===9||j===9;put(g,x0+i,y0+j,e?(i===0||j===0?M[7]:M[0]):M[5])}for(const[i,j]of[[2,2],[7,2],[2,7],[7,7]])put(g,x0+i,y0+j,M[8]);for(let i=0;i<n;i++){g.fillStyle=on?A.hot:A.flare;g.fillRect(ox+2+i*4,oy-2,3,5)}}}
    TK.text(g,'AIR',97,VH+5,A.chill);
    const aw=36;g.fillStyle=A.bevelLo;g.fillRect(111,VH+4,aw+2,7);g.fillStyle=A.line;g.fillRect(112,VH+5,aw,5);
    const fw=Math.round(aw*S.air);for(let i=0;i<fw;i++){put(g,112+i,VH+5,S.air<0.25?'#e07a62':A.ice);for(let j=1;j<5;j++)put(g,112+i,VH+5+j,j===4?(S.air<0.25?'#7a2f24':A.cold):(S.air<0.25?A.bad:A.chill))}
    if(statusT>0||S.over)TK.text(g,status,PW-3,VH+15,statusCol,'right');else TK.text(g,'PUFFS '+S.puffs,PW-3,VH+15,M[6],'right');
  }
  function tick(dt){
    for(const p of S.parts){p.trail.push([p.x,p.y]);if(p.trail.length>5)p.trail.shift()}
    step(S,P,dt);events();statusT-=dt;
    for(let i=fx.length-1;i>=0;i--){fx[i].age+=dt;if(fx[i].age>fx[i].life)fx.splice(i,1)}
    for(const j of junk){const[vx,vy]=field(P,j.x,j.y);j.vx+=vx*0.05*dt;j.vy+=vy*0.05*dt;const sp=Math.hypot(j.vx,j.vy);if(sp>2.5){j.vx*=2.5/sp;j.vy*=2.5/sp}j.x+=j.vx*dt;j.y+=j.vy*dt;j.ang+=dt*0.6;
      if(j.x<4||j.x>PW-8){j.vx*=-1;j.x=clamp(j.x,4,PW-8)}if(j.y<11||j.y>72){j.vy*=-1;j.y=clamp(j.y,11,72)}}
    if(S.over&&!timers.length&&S.t-endT>1.0)timers.push(setTimeout(finish,100));
  }
  function frame(now){const dt=last?Math.min(0.05,(now-last)/1000):0;last=now;tick(dt);acc+=dt;if(acc>=1/30){acc=0;draw()}raf=requestAnimationFrame(frame)}
  draw();raf=requestAnimationFrame(frame);
  return{
    destroy(){cancelAnimationFrame(raf);timers.forEach(clearTimeout);S.over=true;doneFired=true;px.destroy()},
    giveUp(){if(doneFired)return;S.over=true;doneFired=true;cancelAnimationFrame(raf);ctx.done({score:clamp(0.25*S.sealed/P.leaks.length),detail:'Gave up'})},
    _sim:S,_P:P,
  };
}

TK.register({
  id:ID,name:'Leak Hunt',hint:'Patch the leak.',controls:['click'],where:'Dead stations',skill:'Observation',
  blurb:'Puff smoke to find a hidden hull leak, then patch it.',
  how:[
    'Tap the room to puff smoke. The leak sucks it in.',
    'Watch where it drifts. It speeds up near the hole.',
    'Tap PATCH, then tap the leak to seal it.',
    'Air is running out. Wrong patches cost.',
  ],
  deeper:'Sector 2+: a weaker leak and smoke that fades sooner. Sector 3+: two leaks. Sector 4+: a fan blows a draft across the room.',
  sensors:'Each point: smoke lasts longer and the air lasts longer. 3+: one spare patch.',
  mount,
  _t:{gen,field,newSim,puff,patch,step,scoreOf,bot,CFG,
    check(rng,depth,sens){const P=gen(depth,sens,rng);const r=bot(P,rng);return{ok:r.S.won,score:r.score,x:r.S.t,info:{sealed:r.S.sealed,wrong:r.S.wrong,puffs:r.S.puffs,air:+r.S.air.toFixed(2)}}}},
});
})();
