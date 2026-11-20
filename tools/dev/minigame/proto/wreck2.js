// Tumble Dock: a wreck tumbles under your docking clamp. Tap the thrusters against its spin (and, sector 3+,
// its drift) until it is still with its lit port in the bracket under the clamp. Pushes build up slowly,
// so lead every stop. The curved arrow IS the spin; the cyan arrow IS the drift.
(function(){
'use strict';
const ID='wreck2';
const PW=152,VH=104,HUD=30,PH=VH+HUD;   // art pixels: dock camera view, then the control strip
const STEP=12;      // deg/s of spin per thruster pulse
const DSTEP=2;      // px/s of drift per slide pulse
const TOLX=4;       // px the port may sit off the clamp and still be grabbed
const SWAY=5,SWT=10; // sector 5: the clamp sways this far (px), once per SWT seconds
// lag: a tap's push builds over `lag` seconds (time constant), so the wreck keeps turning after you tap
const CFG={
  1:{k:[2,3],tol:12,wMax:16,vMax:3,  lag:0.15,drift:0,sway:0,gasX:2.0, secs:70},
  2:{k:[3,4],tol:10,wMax:13,vMax:3,  lag:0.22,drift:0,sway:0,gasX:1.85,secs:75},
  3:{k:[3,5],tol:9, wMax:11,vMax:3,  lag:0.30,drift:0,sway:0,gasX:1.7, secs:80},
  4:{k:[3,5],tol:8, wMax:9, vMax:2.5,lag:0.38,drift:1,sway:0,gasX:1.6, secs:90},
  5:{k:[4,5],tol:8, wMax:8, vMax:2.2,lag:0.45,drift:1,sway:1,gasX:1.5, secs:100},
};
const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));
const wrap=a=>((a%360)+540)%360-180;

function gen(depth,sensors,rng){
  const c=CFG[depth];
  const k=(c.k[0]+Math.floor(rng()*(c.k[1]-c.k[0]+1)))*(rng()<0.5?-1:1);
  let th0=Math.floor(rng()*360);if(Math.abs(wrap(th0))<40)th0+=90;
  const shiftDir=rng()<0.5?-1:1;
  let vk=0,x0=0;
  if(c.drift){vk=(1+Math.floor(rng()*1.5))*(rng()<0.5?-1:1);x0=Math.round((rng()-.5)*20)}
  const par=Math.abs(k)+2+(c.drift?Math.abs(vk)+1:0);
  const gas=Math.ceil(par*c.gasX)+2*sensors;
  const T=c.secs+8*sensors;
  const tol=c.tol+(sensors>=3?2:0);
  const tPar=15+3*depth;
  return{k,th0,vk,x0,drift:c.drift,shift:0,wMax:c.wMax,vMax:c.vMax,shiftDir,sway:c.sway,lag:c.lag,tol,par,gas,T,tPar,depth};
}
function newSim(P){return{t:0,th:P.th0,w:P.k*STEP,wk:P.k,x:P.x0,vx:P.vk*DSTEP,vk:P.vk,used:0,hold:0,zeroT:0,shifted:false,docked:false,over:false,events:[]}}
function err(S){return wrap(S.th)}           // 0 = port straight up, under the clamp
function clampX(S,P){if(S.latch)return S.latch.kx;return P.sway?SWAY*Math.sin(S.t*2*Math.PI/SWT):0}
function still(S){return S.wk===0&&S.vk===0&&Math.abs(S.w)<2&&Math.abs(S.vx)<0.6}
// the capture window: port near the clamp and slow enough. Exact zero is never needed.
function placed(S,P){return Math.abs(err(S))<=P.tol&&Math.abs(S.x-clampX(S,P))<=TOLX}
function slowSpin(S,P){return Math.abs(S.w)<=P.wMax}
function slowDrift(S,P){return Math.abs(S.vx)<=P.vMax}
function lined(S,P){return placed(S,P)&&slowSpin(S,P)&&slowDrift(S,P)}
function close(S,P){return Math.abs(err(S))<=P.tol*1.8&&Math.abs(S.x-clampX(S,P))<=TOLX*2}
function tap(S,P,what){
  if(S.over||S.used>=P.gas)return false;
  S.used++;
  if(what==='cw')S.wk++;else if(what==='ccw')S.wk--;else if(what==='right')S.vk++;else if(what==='left')S.vk--;
  S.events.push({type:'puff',what});
  return true;
}
function step(S,P,dt){
  if(S.over)return;
  S.t+=dt;
  const f=1-Math.exp(-dt/P.lag);
  S.w+=(S.wk*STEP-S.w)*f;S.vx+=(S.vk*DSTEP-S.vx)*f;
  S.th+=S.w*dt;S.x+=S.vx*dt;
  if(Math.abs(S.x)>50){S.x=Math.sign(S.x)*50}
  if(lined(S,P)){S.docked=true;S.over=true;S.latch={t:S.t,th0:S.th,x0:S.x,kx:clampX(S,P),slow:1-0.5*(Math.abs(S.w)/P.wMax+(P.drift?Math.abs(S.vx)/P.vMax:0))};S.events.push({type:'docked'})}
  if(!S.over&&S.t>=P.T){S.over=true;S.events.push({type:'fail',why:'time'})}
  const settled=Math.abs(S.w-S.wk*STEP)<1&&Math.abs(S.vx-S.vk*DSTEP)<0.3;
  if(!S.over&&S.used>=P.gas&&settled&&(Math.abs(S.wk*STEP)>P.wMax||Math.abs(S.vk*DSTEP)>P.vMax||S.wk===0&&Math.abs(err(S))>P.tol||S.vk===0&&Math.abs(S.x)>(P.sway?SWAY:0)+TOLX)){S.over=true;S.events.push({type:'fail',why:'gas'})}
}
// Docked: gas left, speed, and arriving slow all count. A clean dock is 1.0; a sloppy one about 0.5.
function scoreOf(S,P){
  if(!S.docked)return S.used===0?0:0.1;
  const fuel=clamp(1-Math.max(0,S.used-P.par)/6);
  const time=clamp(1-Math.max(0,S.t-P.tPar)/(2*P.tPar));
  return clamp(0.4+0.3*fuel+0.2*time+0.1*clamp(S.latch.slow),0.4,1);
}

// Test bot: lead every stop by the lag. Kill the big spin and drift, then nudge one notch at a time.
function bot(P){
  const S=newSim(P);const dt=1/30,GAP=0.25;let cool=0,guard=0;
  const xt=()=>P.sway?SWAY*0.85:0;
  while(!S.over&&guard++<30*240){
    cool-=dt;
    if(cool<=0){
      let act=null;const e=err(S);
      if(Math.abs(S.wk)>1)act=S.wk>0?'ccw':'cw';
      else if(P.drift&&Math.abs(S.vk)>1)act=S.vk>0?'left':'right';
      if(!act){
        const pe=wrap(e+S.w*P.lag);   // where the port ends up if the spin is stopped now
        if(S.wk!==0){if(Math.abs(pe)<=P.tol*0.5||Math.sign(pe)===Math.sign(S.wk))act=S.wk>0?'ccw':'cw'}
        else if(Math.abs(S.w)<3&&Math.abs(e)>P.tol*0.6&&!(P.shift&&!S.shifted&&Math.abs(e)<=P.tol))act=e>0?'ccw':'cw';
      }
      if(!act&&P.drift){
        const d=S.x+S.vx*P.lag-xt();
        if(S.vk!==0){if(Math.abs(d)<=1||Math.sign(d)===Math.sign(S.vk))act=S.vk>0?'left':'right'}
        else if(Math.abs(S.vx)<0.5&&Math.abs(S.x-xt())>TOLX*0.6)act=S.x>xt()?'left':'right';
      }
      if(act){tap(S,P,act);cool=GAP}
    }
    step(S,P,dt);S.events.length=0;
  }
  return{S,score:scoreOf(S,P)};
}

// ---- the wreck sprite: a mask with materials and outward normals so the light stays top-left as it turns ----
function buildWreck(rng){
  const N=64,C=32;const mat=new Int8Array(N*N).fill(-1);
  const set=(x,y,m)=>{if(x>=0&&y>=0&&x<N&&y<N)mat[y*N+x]=m};
  const hl=19+Math.floor(rng()*4),hh=7+Math.floor(rng()*2);
  const tear=[];for(let y=-hh;y<=hh;y++)tear.push(Math.floor(rng()*5));
  for(let y=-hh;y<=hh;y++)for(let x=-hl;x<=hl-tear[y+hh];x++){
    if(x<-hl+3&&Math.abs(y)>hh-(x+hl))continue;
    set(C+x,C+y,1);
  }
  for(let y=-4;y<=4;y++)for(let x=-hl-5;x<-hl;x++)set(C+x,C+y,2);
  const mx=-6+Math.floor(rng()*8);for(let y=hh;y<hh+7;y++){set(C+mx,C+y,1);set(C+mx+1,C+y,1)}for(let x=mx-3;x<=mx+4;x++)set(C+x,C+hh+7,1);
  for(let i=0;i<7;i++){set(C+hl-2+i,C-2+Math.round(i*0.4),1)}
  for(let y=-hh;y<=hh;y++)for(let x=hl-10;x<=hl;x++){const i=(C+y)*N+C+x;if(mat[i]===1&&rng()<0.55+(x-hl+10)*0.04)mat[i]=3}
  for(let x=-hl+6;x<hl-12;x+=3)if(Math.abs(x)>4)set(C+x,C-1,4);
  // the port on top, right over the spin centre
  const px=0;
  for(let y=-hh-3;y<=-hh;y++)for(let x=px-3;x<=px+3;x++)set(C+x,C+y,(Math.abs(x-px)<=1&&y<=-hh-1)?6:5);
  const nrm=new Float32Array(N*N*2);
  for(let y=0;y<N;y++)for(let x=0;x<N;x++){if(mat[y*N+x]<0)continue;let nx=0,ny=0;
    for(let j=-2;j<=2;j++)for(let i=-2;i<=2;i++){const X=x+i,Y=y+j;if(X<0||Y<0||X>=N||Y>=N||mat[Y*N+X]<0){nx+=i;ny+=j}}
    const l=Math.hypot(nx,ny);nrm[(y*N+x)*2]=l?nx/l*Math.min(1,l/3):0;nrm[(y*N+x)*2+1]=l?ny/l*Math.min(1,l/3):0}
  const cables=[];for(let i=0;i<3;i++){const y0=-hh+2+Math.floor(rng()*(2*hh-3));cables.push({x:hl-tear[y0+hh]+1,y:y0,len:4+Math.floor(rng()*5),ph:rng()*6})}
  return{N,C,mat,nrm,port:[px,-hh-2],cables,hl,hh};
}

function banner(g,A,PW,y,big,ctrls,t){const tw=big.length*4-1,w=tw+13+4+8,x=Math.floor(PW/2-w/2);g.fillStyle=A.bevelLo;g.fillRect(x,y,w,15);g.fillStyle=A.panel;g.fillRect(x+1,y+1,w-2,13);g.fillStyle=A.ember;g.fillRect(x+1,y+1,w-2,1);g.fillRect(x+1,y+13,w-2,1);TK.icon(g,ctrls[0],x+4,y+1,{t});TK.text(g,big,x+4+13+4,y+5,A.hot)}
const BAYER=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5];
const bt=(x,y)=>(BAYER[(y&3)*4+(x&3)]+.5)/16;

function mount(stage,ctx){
  const P=gen(ctx.depth,ctx.sensors,ctx.rng);const S=newSim(P);const A=TK.PAL;
  const M=['#080b11','#111823','#182230','#22303f','#2d3c4e','#3d4d61','#6b7d94','#8fa3ba','#c3d2e2'];
  const BURN=['#080b11','#1c120c','#3a2416','#5a3a22'];
  const WR=buildWreck(ctx.rng);
  const px=TK.pixel(stage,{w:PW,h:PH});const g=px.g;
  const put=(x,y,c)=>{g.fillStyle=c;g.fillRect(x,y,1,1)};
  const stars=[];for(let i=0;i<60;i++)stars.push({x:Math.floor(ctx.rng()*PW),y:Math.floor(ctx.rng()*VH),b:ctx.rng()});
  const bits=[],fx=[];
  let raf=0,last=0,acc=0,doneFired=false,endT=0,status='',statusCol=A.chill,statusT=0,press=null,pressT=0,arcFlash=0;const timers=[];
  const CX=PW/2,CY=50,PR=WR.hh+2;     // spin centre and port radius
  const B=P.drift?[{id:'ccw',x:2,w:35},{id:'left',x:40,w:35},{id:'right',x:77,w:35},{id:'cw',x:115,w:35}]:[{id:'ccw',x:2,w:72},{id:'cw',x:78,w:72}];
  const by=VH+11,bh=17;
  function onDown(e){
    if(S.over)return;e.preventDefault();
    const p=px.pt(e);
    for(const b of B)if(p.x>=b.x&&p.x<b.x+b.w&&p.y>=by-3&&p.y<by+bh+2){if(tap(S,P,b.id)){press=b.id;pressT=0.15;arcFlash=0.25}else say('NO GAS',A.bad,1.5)}
  }
  px.cv.addEventListener('pointerdown',onDown);
  let AC=null;function clunk(){if(window.TK_MUTE_TONES)return;try{AC=AC||new (window.AudioContext||window.webkitAudioContext)();const t=AC.currentTime;for(const[fq,d,v]of[[90,.25,.08],[180,.08,.05]]){const o=AC.createOscillator(),gg=AC.createGain();o.type='square';o.frequency.setValueAtTime(fq,t);o.frequency.exponentialRampToValueAtTime(fq*0.5,t+d);gg.gain.setValueAtTime(v,t);gg.gain.exponentialRampToValueAtTime(.0001,t+d);o.connect(gg).connect(AC.destination);o.start(t);o.stop(t+d+.02)}}catch(e){}}
  function say(t,c,s){status=t;statusCol=c;statusT=s||2}
  function events(){
    while(S.events.length){const ev=S.events.shift();
      if(ev.type==='puff'){TK.sfx('wreck2','puff');const side=ev.what==='cw'||ev.what==='left'?1:0;fx.push({k:'puff',x:side?PW-6:5,y:VH-8,age:0,life:0.6,dir:side?-1:1})}
      else if(ev.type==='shift'){say('CARGO SHIFT',A.warn,2.5);arcFlash=0.4;for(let i=0;i<6;i++)bits.push({lx:WR.hl-2,ly:(Math.random()-.5)*10,vx:6+Math.random()*10,vy:(Math.random()-.5)*10,age:0})}
      else if(ev.type==='docked'){endT=S.t;say('DOCKED',A.good,99);TK.sfx('wreck2','dock');clunk();TK.sfx('wreck2','win');}
      else if(ev.type==='fail'){endT=S.t;say(ev.why==='time'?'WINDOW LOST':'OUT OF GAS',A.bad,99)}
    }
  }
  function finish(){if(doneFired)return;doneFired=true;ctx.done({score:scoreOf(S,P),detail:S.docked?`Docked in ${Math.round(S.t)} s with ${S.used} pulses (par ${P.par})`:(S.used>=P.gas?'Ran out of gas':'Ran out of time')})}

  function drawWreck(cx,cy,th){
    const a=th*Math.PI/180,ca=Math.cos(a),sa=Math.sin(a);const N=WR.N,C=WR.C;
    const inside=(sx,sy)=>{const dx=sx+.5-cx,dy=sy+.5-cy;const lx=Math.round(dx*ca+dy*sa),ly=Math.round(-dx*sa+dy*ca);const X=lx+C,Y=ly+C;if(X<0||Y<0||X>=N||Y>=N)return -1;return Y*N+X};
    const r=34,lit6=lined(S,P)||S.docked;
    for(let sy=Math.floor(cy-r);sy<=cy+r;sy++)for(let sx=Math.floor(cx-r);sx<=cx+r;sx++){
      if(sy<0||sy>=VH||sx<0||sx>=PW)continue;
      const i=inside(sx,sy);const m=i<0?-1:WR.mat[i];
      if(m<0){let edge=false;for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]]){const j=inside(sx+dx,sy+dy);if(j>=0&&WR.mat[j]>=0){edge=true;break}}
        if(edge)put(sx,sy,M[0]);continue}
      const nx=WR.nrm[i*2],ny=WR.nrm[i*2+1];const snx=nx*ca-ny*sa,sny=nx*sa+ny*ca;
      const lit=-(snx+sny)*0.707,body=-((sx-cx)+(sy-cy))/40,v=lit*1.6+body+bt(sx,sy)*0.9-0.45;
      let c;
      if(m===1)c=M[Math.max(1,Math.min(7,4+Math.round(v)))];
      else if(m===2)c=M[Math.max(1,Math.min(6,3+Math.round(v)))];
      else if(m===3){c=BURN[Math.max(0,Math.min(3,2+Math.round(v)))];if(Math.sin(S.t*3+sx*1.7+sy)>0.97)c=A.ember}
      else if(m===4)c=((sx*7+sy*3)%11===0&&Math.sin(S.t*2+sx)>0)?A.hot:M[1];
      else if(m===5)c=M[Math.max(2,Math.min(8,5+Math.round(v)))];
      else if(m===6)c=lit6?A.mark:(Math.floor(S.t*3)%2?A.flare:A.hot);
      put(sx,sy,c);
    }
    for(const cb of WR.cables){for(let i=0;i<cb.len;i++){const lx=cb.x+i,ly=cb.y+Math.round(Math.sin(S.t*2+cb.ph+i*0.6)*i*0.25);const sx=Math.round(cx+lx*ca-ly*sa),sy=Math.round(cy+lx*sa+ly*ca);if(sx>=0&&sy>=0&&sx<PW&&sy<VH)put(sx,sy,i===cb.len-1&&Math.floor(S.t*5+cb.ph)%3===0?A.hot:A.warn)}}
    for(const b of bits){const lx=b.lx+b.vx*b.age,ly=b.ly+b.vy*b.age;const sx=Math.round(cx+lx*ca-ly*sa),sy=Math.round(cy+lx*sa+ly*ca);if(sx>=0&&sy>=0&&sx<PW&&sy<VH)put(sx,sy,M[7])}
  }
  // a thick pixel arc from angle a0 to a1 (degrees, canvas: 0 = right, 90 = down) with a head at a1
  function arrowArc(r,a0,a1,col,dark,chev,t){const OX=CX+Math.round(S.x);
    const dir=Math.sign(a1-a0)||1,len=Math.abs(a1-a0);
    for(let d=0;d<=len;d+=1.2){const a=(a0+dir*d)*Math.PI/180;
      for(const rr of[r-1,r,r+1]){const x=Math.round(OX+Math.cos(a)*rr),y=Math.round(CY+Math.sin(a)*rr);if(y<VH)put(x,y,rr===r?col:dark)}}
    // chevrons running along it, faster with more spin
    if(chev)for(let d=(t*chev*40)%14;d<len-6;d+=14){const a=(a0+dir*d)*Math.PI/180,x=Math.round(OX+Math.cos(a)*r),y=Math.round(CY+Math.sin(a)*r);put(x,y,A.hot)}
    // head: a filled triangle pointing along the arc
    const a=a1*Math.PI/180,hx=OX+Math.cos(a)*r,hy=CY+Math.sin(a)*r,tx=-Math.sin(a)*dir,ty=Math.cos(a)*dir,nx=Math.cos(a),ny=Math.sin(a);
    for(let s=0;s<=5;s++)for(let w=-(5-s);w<=5-s;w++){const x=Math.round(hx+tx*s+nx*w),y=Math.round(hy+ty*s+ny*w);if(y<VH)put(x,y,s===0||Math.abs(w)===5-s?dark:col)}
  }
  function button(b,now){
    const on=press===b.id&&pressT>0;const y=by+(on?1:0);
    // the button that slows the spin, or that turns the port the short way, glows
    const want=S.over||P.depth>3?null:S.wk!==0?(S.wk>0?'ccw':'cw'):null;
    const glow=want===b.id&&Math.floor(now*2.5)%2===0;
    g.fillStyle=glow?A.ember:M[0];g.fillRect(b.x-1,by-1,b.w+2,bh+3);
    g.fillStyle=M[0];g.fillRect(b.x,by,b.w,bh+1);
    g.fillStyle=on?M[3]:M[4];g.fillRect(b.x+1,y+1,b.w-2,bh-2);
    g.fillStyle=on?M[4]:M[6];g.fillRect(b.x+1,y+1,b.w-2,1);g.fillRect(b.x+1,y+1,1,bh-2);
    g.fillStyle=M[1];g.fillRect(b.x+1,y+bh-2,b.w-2,1);g.fillRect(b.x+b.w-2,y+1,1,bh-2);
    const cx=b.x+Math.floor(b.w/2),cy=y+7;const col=S.used>=P.gas?M[5]:want===b.id?A.hot:A.flare;
    if(b.id==='left'||b.id==='right'){const s=b.id==='right'?1:-1;for(let i=-5;i<=5;i++)put(cx+i,cy+1,col);for(let j=1;j<=3;j++){put(cx+5*s-j*s,cy+1-j,col);put(cx+5*s-j*s,cy+1+j,col)}return}
    const s=b.id==='cw'?1:-1;const rw=b.w>40?7:6;
    for(let d=150;d<=360;d+=6){const a=d*Math.PI/180;put(Math.round(cx+s*Math.cos(a)*rw),Math.round(cy+1+Math.sin(a)*5),col)}
    const ex=cx+rw*s,ey=cy+2;for(let i=-2;i<=2;i++)put(ex+i,ey,col);put(ex-1,ey+1,col);put(ex,ey+1,col);put(ex+1,ey+1,col);put(ex,ey+2,col);
  }
  function draw(now){
    const t=S.t;
    g.fillStyle=A.void;g.fillRect(0,0,PW,VH);
    for(const s of stars){const tw=s.b>0.9&&Math.floor(now*1.5+s.x)%5===0;put(s.x,s.y,tw?A.hot:s.b>0.8?A.ice:s.b>0.5?M[6]:M[4])}
    // a still planet limb, bottom-left, for depth
    const pcx=-60,pcy=VH+70;
    for(let y=40;y<VH;y++)for(let x=0;x<70;x++){const d=Math.hypot(x-pcx,y-pcy);if(d<120){const lx=(x-pcx)/120,ly=(y-pcy)/120;const l=-(lx+ly)*0.7;put(x,y,120-d<1.5?M[5]:l+bt(x,y)*0.5>0.55?'#2a3a3a':l+bt(x,y)*0.5>0.2?'#1a2628':'#0f1719')}}
    const ok=S.docked,near=!ok&&!S.over&&close(S,P),late=[];
    // the target: a dashed drop line from the clamp to a bracket where the port must sit
    const ty=CY-PR,tc=ok?A.good:near?(placed(S,P)?A.flare:A.warn):A.hot,bl=Math.floor(now*3)%2,KX=CX+Math.round(clampX(S,P)),WX=CX+Math.round(S.x);
    if(!S.docked)for(let y=10;y<ty-6;y+=2)put(KX,y,(y+Math.floor(now*8))%4<2?tc:M[3]);
    if(!S.docked){put(KX-1,ty-8,tc);put(KX+1,ty-8,tc);put(KX,ty-7,tc)}
    // the wreck
    drawWreck(WX,CY,S.th);
    const bw=7;
    // the bracket: where the port must sit, drawn over the hull
    for(const sgn of[-1,1]){const x=KX+sgn*bw;for(let y=ty-5;y<=ty+4;y++){put(x,y,tc);put(x+sgn,y,M[0])}put(x-sgn,ty-5,tc);put(x-sgn,ty+4,tc);put(x-2*sgn,ty-5,tc);put(x-2*sgn,ty+4,tc);if(!ok&&bl)put(x+sgn,ty,tc)}
    if(ok&&!S.docked){for(let y=ty-6;y<=ty+5;y++)for(let x=KX-bw-2;x<=KX+bw+2;x++){const d=Math.max(Math.abs(x-KX)-bw,Math.abs(y-ty)-4);if(d===1||d===2){if(bt(x,y)<(d===1?.6:.3))put(x,y,A.good)}}}
    // the spin arrow under the wreck: its length and running chevrons are the spin
    const n=Math.abs(S.w)/STEP;
    if((n>0.15||S.wk)&&!S.docked){
      const span=Math.min(200,20+n*28),dir=Math.sign(S.w)||Math.sign(S.wk),a0=90-dir*span/2,a1=90+dir*span/2;
      const fl=arcFlash>0,sl=slowSpin(S,P);
      arrowArc(35,a0,a1,fl?A.hot:sl?A.good:A.flare,fl?A.ember:sl?'#1c3a2a':'#5a2e10',n,t);
      if(S.t>=6||S.used)late.push(()=>TK.text(g,'SPIN '+Math.abs(S.wk),3,VH-7,sl?A.good:A.flare));
    }else if(!S.docked&&!S.over){
      // stopped: a thin arc from the port to the bracket shows the short way round
      const e=err(S);
      if(Math.abs(e)>P.tol){const a0=-90+e,a1=-90+(e>0?3:-3);
        for(let d=Math.min(a0,a1);d<=Math.max(a0,a1);d+=2){const a=d*Math.PI/180,x=Math.round(WX+Math.cos(a)*(PR+7)),y=Math.round(CY+Math.sin(a)*(PR+7));if((d/2|0)%2===0)put(x,y,A.hot)}
        const a=a1*Math.PI/180,hx=Math.round(WX+Math.cos(a)*(PR+7)),hy=Math.round(CY+Math.sin(a)*(PR+7)),s=e>0?-1:1;put(hx+s,hy,A.hot);put(hx,hy-1,A.hot);put(hx,hy+1,A.hot);put(hx-s,hy-1,A.hot);put(hx-s,hy+1,A.hot)}
      if(S.t>=6||S.used)late.push(()=>TK.text(g,'STILL',3,VH-7,A.good));
    }
    // the drift: a cyan arrow above the wreck, as long as the drift is fast
    const dn=Math.abs(S.vx)/DSTEP;
    if(P.drift&&!S.docked&&(dn>0.12||S.vk)){const dir=Math.sign(S.vx)||Math.sign(S.vk),L=Math.round(4+dn*7),y=15,dc=slowDrift(S,P)?A.good:A.tractor;
      for(let i=-L;i<=L;i++){put(WX+i,y,dc);put(WX+i,y+1,'#0b3531')}
      const hx=WX+dir*L;for(let j=1;j<=3;j++){put(hx-dir*j,y-j,dc);put(hx-dir*j,y+j,dc)}put(hx+dir,y,dc);
      if(S.t>=6||S.used)late.push(()=>TK.text(g,'DRIFT '+Math.abs(S.vk),PW-3,VH-7,dc,'right'))}
    // your docking clamp at the top
    const ext=S.docked?Math.min(ty-13,Math.round((t-endT)*40)):0;
    for(let y=0;y<6+ext;y++)for(let x=-9;x<=9;x++){const ax=Math.abs(x);if(ax<4&&y<6+ext-2)continue;if(ax>9-(y>4+ext?2:0))continue;const c=ax===9||y===0?M[6]:ax>=7?M[4]:M[5];put(KX+x,y,c)}
    for(const x of[-9,9])for(let y=0;y<6+ext;y++)put(KX+x+(x>0?1:-1),y,M[0]);
    for(const x of[-6,6])put(KX+x,2,ok?A.good:(Math.floor(t*2)%2?A.ember:M[3]));
    if(near){const lx=KX>CX?KX-46:KX+14;TK.text(g,'TOO FAST',lx,ty-2,A.flare)}
    if(ok&&S.latch&&S.t-S.latch.t<0.25){for(const sgn of[-1,1])for(let k=0;k<3;k++)put(KX+sgn*(12+k),ty-3+k*3,A.hot)}
    // thruster puffs at the frame edges
    for(const f of fx){const k=f.age/f.life;const r=1+k*6;for(let j=-Math.ceil(r);j<=r;j++)for(let i=0;i<=r*1.6;i++){const d=Math.hypot(i/1.6,j)/r;if(d>1)continue;const x=Math.round(f.x+f.dir*i),y=Math.round(f.y+j-k*3);if(bt(x,y)>(1-d)*(1-k)*1.8)continue;put(x,y,d<0.4&&k<0.3?A.ice:A.chill)}}
    for(let y=0;y<VH;y++)for(let x=0;x<PW;x++){const dx=Math.max(0,Math.abs(x-PW/2)-PW*0.4)/(PW*0.1),dy=Math.max(0,Math.abs(y-VH/2)-VH*0.38)/(VH*0.12);const v=Math.hypot(dx,dy);if(v>0&&bt(x,y)<v*0.5)put(x,y,A.bevelLo)}
    for(const f of late){g.fillStyle=A.void;f()}
    if(S.t<6&&!S.used)banner(g,A,PW,VH-15,'STOP IT UNDER THE CLAMP.',['click'],now);
    // control strip
    g.fillStyle=A.panel;g.fillRect(0,VH,PW,HUD);g.fillStyle=A.bevelHi;g.fillRect(0,VH,PW,1);g.fillStyle=A.bevelLo;g.fillRect(0,VH+1,PW,1);
    TK.text(g,'GAS',3,VH+4,A.chill);
    const left=P.gas-S.used,sp=Math.max(2,Math.min(4,Math.floor(80/P.gas)));for(let i=0;i<P.gas;i++){const x=17+i*sp;g.fillStyle=i<left?(left<=3?A.bad:A.flare):M[3];g.fillRect(x,VH+4,sp-1,5)}
    const tl=Math.max(0,Math.ceil(P.T-S.t));
    if(statusT>0||S.over)TK.text(g,status,PW-3,VH+4,statusCol,'right');else TK.text(g,'TIME '+tl,PW-3,VH+4,tl<10?A.bad:A.chill,'right');
    for(const b of B)button(b,now);
  }
  function tick(dt){
    if(!S.over)step(S,P,dt);else S.t+=dt;
    // the latch: the clamp grabs and pulls the last bit in
    if(S.latch){const u=Math.min(1,(S.t-S.latch.t)/0.5),e=1-Math.pow(1-u,3);S.th=S.latch.th0-wrap(S.latch.th0)*e;S.x=S.latch.x0+(S.latch.kx-S.latch.x0)*e}
    events();statusT-=dt;pressT-=dt;arcFlash-=dt;
    for(let i=fx.length-1;i>=0;i--){fx[i].age+=dt;if(fx[i].age>fx[i].life)fx.splice(i,1)}
    for(const b of bits)b.age+=dt;
    if(S.over&&!timers.length&&S.t-endT>(S.docked?1.0:1.2))timers.push(setTimeout(finish,100));
  }
  function frame(now){const dt=last?Math.min(0.05,(now-last)/1000):0;last=now;tick(dt);acc+=dt;if(acc>=1/30){acc=0;draw(now/1000)}raf=requestAnimationFrame(frame)}
  draw(performance.now()/1000);raf=requestAnimationFrame(frame);
  return{
    destroy(){cancelAnimationFrame(raf);try{AC&&AC.close()}catch(e){}timers.forEach(clearTimeout);S.over=true;doneFired=true;px.destroy()},
    giveUp(){if(doneFired)return;S.over=true;doneFired=true;cancelAnimationFrame(raf);ctx.done({score:0,detail:'Gave up'})},
    _sim:S,_P:P,_btn:id=>{const b=B.find(b=>b.id===id);return{x:b.x+(b.w>>1),y:by+8}},
  };
}

TK.register({
  id:ID,name:'Tumble Dock',hint:'Stop it under the clamp.',controls:['click'],where:'Wrecks',skill:'Feel for momentum',
  blurb:'Stop a spinning wreck with its lit port right under your clamp.',
  how:[
    'The orange arrow is the spin. Tap the other way to shrink it.',
    'Pushes build up slowly, so tap early or you overshoot.',
    'Bring the lit port into the bracket slowly. Green means slow enough: the clamp grabs it.',
    'Gas left and speed both score.',
  ],
  deeper:'Slower thrusters and a tighter bracket. Sector 4+: it drifts too (the cyan arrow); slide to stop it. Sector 5: the clamp sways slowly.',
  sensors:'Each point: more gas and time. 3+: a wider bracket.',
  mount,
  _t:{gen,newSim,tap,step,err,lined,placed,clampX,scoreOf,bot,CFG,
    check(rng,depth,sens){const P=gen(depth,sens,rng);const r=bot(P);return{ok:r.S.docked,score:r.score,info:{used:r.S.used,par:P.par,gas:P.gas,t:+r.S.t.toFixed(1)}}}},
});
})();
