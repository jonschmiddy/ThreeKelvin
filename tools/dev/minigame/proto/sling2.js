// Gravity Sling v2: turn the ANGLE dial, pull the sling back and let go.
(function(){
'use strict';
const ID='sling2';
const FW=1000,FH=640,DT=0.5,MAXS=1600;
const CFG={
  1:{masses:1,move:0,zone:0,tr:36,shots:5},
  2:{masses:2,move:0,zone:0,tr:34,shots:5},
  3:{masses:3,move:0,zone:0,tr:32,shots:5},
  4:{masses:2,move:1,zone:0,tr:32,shots:5},
  5:{masses:3,move:1,zone:1,tr:30,shots:5},
};
const K=1.15; // gm = K * r^2
const AMIN=-80,AMAX=80,PMIN=10,PMAX=100;
const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));
const speed=p=>2+p*0.08;
function tpos(P,t){return P.move?[P.tx,P.ty+P.amp*Math.sin(2*Math.PI*t/P.per)]:[P.tx,P.ty]}

function sim(P,ang,pow,steps){
  const a=ang*Math.PI/180,v=speed(pow);
  let x=P.ox,y=P.oy,vx=v*Math.cos(a),vy=-v*Math.sin(a);
  const pts=[[x,y]];let best=Infinity,inside=false,end='lost',hitD=Infinity;
  const N=steps||MAXS;
  for(let s=1;s<=N;s++){
    let ax=0,ay=0,crash=false;
    for(const m of P.masses){const dx=m.x-x,dy=m.y-y,r2=dx*dx+dy*dy;if(r2<m.r*m.r){crash=true;break}const f=m.gm/(r2*Math.sqrt(r2));ax+=f*dx;ay+=f*dy}
    if(crash){end='crash';break}
    vx+=ax*DT;vy+=ay*DT;x+=vx*DT;y+=vy*DT;
    if(s%2===0)pts.push([x,y]);
    if(steps)continue;
    const[tx,ty]=tpos(P,s*DT);const d=Math.hypot(x-tx,y-ty);
    if(d<best)best=d;
    if(d<P.tr){inside=true;if(d<hitD)hitD=d;else{end='hit';break}}
    else if(inside){end='hit';break}
    if(P.zone&&x>P.zone.x&&x<P.zone.x+P.zone.w&&y>P.zone.y&&y<P.zone.y+P.zone.h){end='zone';break}
    if(x<-60||x>FW+60||y<-60||y>FH+60)break;
  }
  const l=pts[pts.length-1];if(l[0]!==x||l[1]!==y)pts.push([x,y]);
  return{pts,end,best,hitD};
}
function aimAt(P){return Math.round(Math.atan2(P.oy-P.ty,P.tx-P.ox)*180/Math.PI)}

function gen(depth,rng){
  const c=CFG[depth];
  for(let att=0;att<400;att++){
    const P={ox:60,oy:120+rng()*400,tx:900+rng()*40,ty:110+rng()*420,tr:c.tr,masses:[],move:c.move,zone:null};
    if(c.move){P.amp=60+rng()*40;P.per=260+rng()*160;P.ty=Math.max(P.amp+P.tr+20,Math.min(FH-P.amp-P.tr-20,P.ty))}
    let ok=true;
    for(let k=0;k<c.masses&&ok;k++){
      let placed=false;
      for(let t=0;t<60&&!placed;t++){
        const r=22+rng()*22;const m={x:260+rng()*470,y:70+rng()*500,r};m.gm=K*r*r;
        if(Math.hypot(m.x-P.ox,m.y-P.oy)<r+120||Math.hypot(m.x-P.tx,m.y-P.ty)<r+(P.move?P.amp:0)+110)continue;
        if(P.masses.some(o=>Math.hypot(o.x-m.x,o.y-m.y)<o.r+m.r+70))continue;
        P.masses.push(m);placed=true;
      }
      ok=placed;
    }
    if(!ok)continue;
    // at least one mass sits near the straight line, so the sling matters
    const lx=P.tx-P.ox,ly=P.ty-P.oy,ll=Math.hypot(lx,ly);
    if(!P.masses.some(m=>{const u=((m.x-P.ox)*lx+(m.y-P.oy)*ly)/(ll*ll);const px=P.ox+u*lx,py=P.oy+u*ly;return u>0.15&&u<0.85&&Math.hypot(m.x-px,m.y-py)<m.r+90}))continue;
    if(c.zone){
      const w=110,h=150;P.zone={x:380+rng()*220,y:60+rng()*(FH-h-120),w,h};
      if(P.masses.some(m=>m.x>P.zone.x-m.r&&m.x<P.zone.x+w+m.r&&m.y>P.zone.y-m.r&&m.y<P.zone.y+h+m.r)){continue}
    }
    // scan the control space
    let hits=0,good=[],total=0;
    for(let a=-76;a<=76;a+=2)for(let p=10;p<=100;p+=3){total++;const r=sim(P,a,p);if(r.end==='hit'){hits++;if(r.hitD<P.tr*0.5)good.push([a,p])}}
    const frac=hits/total;
    if(good.length<2||frac>0.06)continue;
    const a0=aimAt(P);if(sim(P,a0,50).end==='hit')continue;
    P.sol=good[Math.floor(rng()*good.length)];P.frac=frac;P.a0=a0;
    return P;
  }
  throw new Error('sling2: no puzzle');
}
function scoreHit(k,d,tr){return clamp(1-0.12*(k-1))*(0.78+0.22*(1-clamp(d/tr)))}
function scoreMiss(best,tr){return 0.2*clamp(1-best/(5*tr))}

const logic={gen,sim,scoreHit,scoreMiss,CFG};
if(typeof TK==='undefined'){if(typeof module!=='undefined')module.exports=logic;return}

// ---------- pixel view: the ship's nav plot ----------
const PAL=TK.PAL;
function hex(c){return[parseInt(c.slice(1,3),16),parseInt(c.slice(3,5),16),parseInt(c.slice(5,7),16)]}
function shade(c,f){const[r,g,b]=hex(c),m=v=>Math.max(0,Math.min(255,Math.round(f<0?v*(1+f):v+(255-v)*f)));return'#'+[m(r),m(g),m(b)].map(v=>v.toString(16).padStart(2,'0')).join('')}
const BAY=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5];
const bay=(x,y)=>(BAY[(y&3)*4+(x&3)]+.5)/16;
function dot(g,x,y,c){g.fillStyle=c;g.fillRect(Math.round(x),Math.round(y),1,1)}
function line(g,x0,y0,x1,y1,c,dash){x0=Math.round(x0);y0=Math.round(y0);x1=Math.round(x1);y1=Math.round(y1);
  const dx=Math.abs(x1-x0),dy=-Math.abs(y1-y0),sx=x0<x1?1:-1,sy=y0<y1?1:-1;let e=dx+dy,n=0;g.fillStyle=c;
  for(;;){if(!dash||(n%dash[0])<dash[1])g.fillRect(x0,y0,1,1);n++;if(x0===x1&&y0===y1)break;const e2=2*e;if(e2>=dy){e+=dy;x0+=sx}if(e2<=dx){e+=dx;y0+=sy}}}
function ringPx(g,cx,cy,r,c,every){const n=Math.max(8,Math.round(r*7));const seen=new Set();g.fillStyle=c;
  for(let k=0;k<n;k++){if(every&&k%every)continue;const a=k/n*2*Math.PI,x=Math.round(cx+r*Math.cos(a)),y=Math.round(cy+r*Math.sin(a)),key=x*999+y;if(seen.has(key))continue;seen.add(key);g.fillRect(x,y,1,1)}}
function poly(g,pts,c,dash){for(let i=1;i<pts.length;i++)line(g,pts[i-1][0],pts[i-1][1],pts[i][0],pts[i][1],c,dash)}

const W=144,H=124,FY=92,SC=W/FW; // field is 144 x 92 art px
const CONTROLS=['dial','drag-h'];
const ICW={click:13,hold:21,drag:22,'drag-h':22,'drag-v':22,dial:13};
// the start frame: the goal in words, the input as icons
function startCard(g,hint,ctl,cx,y,t,bg,edge){const tw=hint.length*4-1,iw=ctl.reduce((a,k)=>a+ICW[k]+4,-4),w=Math.max(tw,iw)+10,h=26,x=Math.round(cx-w/2);
  g.fillStyle=edge;g.fillRect(x-1,y-1,w+2,h+2);g.fillStyle=bg;g.fillRect(x,y,w,h);TK.text(g,hint,cx,y+3,TK.PAL.hot,'center');
  let ix=Math.round(cx-iw/2);for(const k of ctl){TK.icon(g,k,ix,y+11,{t});ix+=ICW[k]+4}}
const DX=15,DY=108,DRAD=13;       // aim dial
const FKX=136,RY=109,PULLMAX=72;  // sling fork, rest line, pull length

function mount(stage,ctx){
  const P=gen(ctx.depth,ctx.rng);const c=CFG[ctx.depth];const s=ctx.sensors|0;
  const maxShots=c.shots+(s>=2?1:0)+(s>=4?1:0);
  const stubSteps=s*32;
  let ang=P.a0,pow=0,lastPow=-1,used=0,over=false,flying=null,bestMiss=Infinity,missTxt='',note='',noteT=0;
  let off=0,twang=null,fx=null,raf=0,last=0,clock=0,started=false;
  const old=[];
  const p=TK.pixel(stage,{w:W,h:H});const g=p.g;
  const S=v=>v*SC;

  // static nav plot, drawn once
  const bg=document.createElement('canvas');bg.width=W;bg.height=FY;const b=bg.getContext('2d');
  b.fillStyle=PAL.void;b.fillRect(0,0,W,FY);
  let hs=Math.floor(P.oy*977+P.ty*131)|1;const hr=()=>{hs=(hs*1103515245+12345)&0x7fffffff;return hs/0x7fffffff};
  for(let k=0;k<70;k++){const q=hr();dot(b,hr()*W,hr()*FY,q>.92?PAL.hot:q>.6?PAL.chill:PAL.cold)}
  // plot grid ticks
  for(let x=0;x<W;x+=12)for(let y=0;y<FY;y+=12)dot(b,x,y,PAL.line);
  const starI=P.masses.reduce((a,m,i)=>m.r>P.masses[a].r?i:a,0);
  const PLAN=[[PAL.ice,PAL.chill,PAL.cold],[PAL.hot,PAL.them,shade(PAL.them,-.45)],[shade(PAL.good,.4),PAL.good,shade(PAL.good,-.45)]];
  let pk=0;
  P.masses.forEach((m,i)=>{
    const cx=S(m.x),cy=S(m.y),r=S(m.r);
    for(const f of[4.2,2.9,1.9])ringPx(b,cx,cy,r*f,i===starI?shade(PAL.ember,-.55):PAL.line,3);
    const R=Math.ceil(r*3.4);
    if(i===starI){
      for(let y=-R;y<=R;y++)for(let x=-R;x<=R;x++){
        const d=Math.hypot(x+.5-(cx%1),y+.5-(cy%1)),X=Math.floor(cx)+x,Y=Math.floor(cy)+y;
        if(d<=r){const l=Math.hypot(x+r*.35,y+r*.35)/r;dot(b,X,Y,l<.45?'#fff4dc':l<.85?PAL.hot:l<1.15?PAL.flare:PAL.ember)}
        else{const t=(d-r)/(r*2.4);if(t<1){const dens=Math.pow(1-t,2.2)*.85;if(bay(X,Y)<dens)dot(b,X,Y,t<.35?PAL.flare:t<.7?PAL.ember:shade(PAL.ember,-.4))}}
      }
      for(let k=1;k<Math.round(r*2.6);k++){const a=k>r*1.6?shade(PAL.flare,-.4):PAL.flare;if(k%2)continue;
        dot(b,cx+k,cy,a);dot(b,cx-k,cy,a);dot(b,cx,cy+k,a);dot(b,cx,cy-k,a)}
    }else{
      const pal=PLAN[pk++%3];
      for(let y=-R;y<=R;y++)for(let x=-R;x<=R;x++){
        const fx_=x+.5-(cx%1),fy_=y+.5-(cy%1),d=Math.hypot(fx_,fy_),X=Math.floor(cx)+x,Y=Math.floor(cy)+y;
        if(d<=r-.6){
          const lt=(-fx_*.7-fy_*.7)/r; // light from top-left
          const band=((Math.floor((fy_+r)/Math.max(1.5,r*.4)))&1);
          let col=lt>.35?pal[0]:lt>-.25?pal[1]:pal[2];
          if(lt>-.25&&lt<=.35&&band&&bay(X,Y)<.5)col=lt>0?pal[0]:pal[2];
          if(lt<-.55)col=bay(X,Y)<.6?PAL.bevelLo:pal[2];
          dot(b,X,Y,col);
        }else if(d<=r+.4)dot(b,X,Y,PAL.bevelLo);
        else if(d<=r+1.4&&bay(X,Y)<.35)dot(b,X,Y,shade(pal[1],-.35)); // thin atmosphere
      }
      if(pk%3===2){for(let k=0;k<40;k++){const a=k/40*2*Math.PI,x=cx+Math.cos(a)*r*1.9,y=cy+Math.sin(a)*r*.45-Math.cos(a)*r*.35;
        if(Math.sin(a)<0&&Math.hypot(x-cx,y-cy)<r)continue;dot(b,x,y,PAL.warn)}}
    }
  });
  if(P.zone){const z=P.zone,x0=Math.round(S(z.x)),y0=Math.round(S(z.y)),w=Math.round(S(z.w)),h=Math.round(S(z.h));
    for(let y=0;y<h;y++)for(let x=0;x<w;x++){const e=x===0||y===0||x===w-1||y===h-1;
      if(e?((x+y)%4<2):((x+y)%5===0))dot(b,x0+x,y0+y,e?PAL.bad:shade(PAL.bad,-.45))}}
  if(P.move)line(b,S(P.tx),S(P.ty-P.amp),S(P.tx),S(P.ty+P.amp),shade(PAL.good,-.5),[3,1]);
  // cradle
  ringPx(b,S(P.ox),S(P.oy),3.2,PAL.bevelHi);

  // the control deck, drawn each frame over a static plate
  const deck=document.createElement('canvas');deck.width=W;deck.height=H-FY;const d=deck.getContext('2d');
  d.fillStyle=PAL.panel;d.fillRect(0,0,W,H-FY);d.fillStyle=PAL.bevelHi;d.fillRect(0,0,W,1);d.fillStyle=PAL.bevelLo;d.fillRect(0,1,W,1);
  // dial face
  for(let y=-DRAD-1;y<=DRAD+1;y++)for(let x=-DRAD-1;x<=DRAD+1;x++){const r=Math.hypot(x,y);const X=DX+x,Y=DY-FY+y;
    if(r<=DRAD-.5){const lt=(-x-y)/DRAD;dot(d,X,Y,r>DRAD-2.5?(lt>.2?PAL.bevelHi:lt<-.3?PAL.bevelLo:PAL.line):PAL.void)}
    else if(r<=DRAD+.5)dot(d,X,Y,PAL.bevelLo)}
  for(let a=AMIN;a<=AMAX;a+=20){const rad=a*Math.PI/180;dot(d,DX+(DRAD-3)*Math.cos(rad),DY-FY-(DRAD-3)*Math.sin(rad),a===0?PAL.ice:PAL.cold)}
  TK.text(d,'AIM',33,4,PAL.cold);
  // sling fork: a Y of dark metal
  const fork=[[FKX+3,30],[FKX+3,20],[FKX,13],[FKX,6],[FKX+3,20],[FKX,27]];
  line(d,FKX+3,30,FKX+3,19,PAL.bevelLo);line(d,FKX+4,30,FKX+4,19,PAL.cold);
  line(d,FKX+3,19,FKX,9,PAL.cold);line(d,FKX+4,19,FKX+1,9,PAL.chill);
  line(d,FKX+3,19,FKX,26,PAL.cold);line(d,FKX+4,19,FKX+1,26,PAL.bevelLo);
  void fork;for(let x=128-PULLMAX;x<124;x+=3)dot(d,x,RY-FY,PAL.line);
  for(let k=0;k<=9;k++){const x=Math.round(128-14-k*(PULLMAX-14)/9);dot(d,x,29,k%5===0?PAL.chill:PAL.line);if(k%5===0)dot(d,x,28,PAL.chill)}

  const pl=(pts)=>pts.map(q=>[S(q[0]),S(q[1])]);
  const powNow=()=>pow>0?pow:(lastPow>0?lastPow:50);
  const offOf=pw=>pw<=0?0:14+(pw-PMIN)/(PMAX-PMIN)*(PULLMAX-14);
  let stubPts=null;
  function restub(){stubPts=stubSteps&&!over?pl(sim(P,ang,powNow(),stubSteps).pts):null}

  function draw(){
    g.drawImage(bg,0,0);
    // target
    const tt=flying?flying.k*2*DT:0;const[tx,ty]=tpos(P,tt);const TX=S(tx),TY=S(ty),TR=S(P.tr);
    ringPx(g,TX,TY,TR,PAL.good);ringPx(g,TX,TY,TR*.5,(Math.floor(clock*2)%2)?PAL.mark:shade(PAL.good,-.4));
    g.fillStyle=PAL.mark;g.fillRect(Math.round(TX)-1,Math.round(TY),3,1);g.fillRect(Math.round(TX),Math.round(TY)-1,1,3);
    old.forEach((o,i)=>poly(g,o.pts,o.hit?PAL.good:i===old.length-1?PAL.cold:PAL.line));
    if(stubPts&&!flying)poly(g,stubPts,PAL.ember,[3,2]);
    // aim line and parked probe
    const a=ang*Math.PI/180,OX=S(P.ox),OY=S(P.oy);
    if(!flying&&!over){const L=5+powNow()*0.12;line(g,OX,OY,OX+L*Math.cos(a),OY-L*Math.sin(a),PAL.ember,[2,1]);
      g.fillStyle=PAL.ice;g.fillRect(Math.round(OX)-1,Math.round(OY)-1,2,2)}
    if(flying){
      const pts=flying.pts,k=flying.k;poly(g,pts.slice(Math.max(0,k-400),k+1),PAL.hot);
      const q=pts[k],q0=pts[Math.max(0,k-3)];const hx=q[0]-q0[0],hy=q[1]-q0[1],hl=Math.hypot(hx,hy)||1;
      if(clock*30%2<1.2)dot(g,q[0]-hx/hl*2,q[1]-hy/hl*2,PAL.flare);
      g.fillStyle=PAL.ice;g.fillRect(Math.round(q[0])-1,Math.round(q[1])-1,2,2);dot(g,q[0]+hx/hl*1.5,q[1]+hy/hl*1.5,PAL.ember);
    }
    if(fx){const t=(clock-fx.t0)/0.7;if(t>=1)fx=null;else{ringPx(g,fx.x,fx.y,2+t*10,fx.c,t>.5?2:0);if(t<.5)ringPx(g,fx.x,fx.y,1+t*5,PAL.hot,2)}}
    // field HUD
    TK.text(g,'LAUNCH '+(maxShots-used),2,2,PAL.chill);
    if(missTxt)TK.text(g,missTxt,W-2,2,missTxt==='HIT'?PAL.good:missTxt==='IMPACT'||missTxt==='NO-FLY'?PAL.bad:PAL.hot,'right');
    if(note&&clock<noteT)TK.text(g,note,W/2,FY-7,PAL.hot,'center');
    else if(!started)startCard(g,'HIT THE TARGET',CONTROLS,W/2,FY-30,clock,PAL.void,PAL.bevelHi);
    g.fillStyle=PAL.bevelLo;g.fillRect(0,FY-1,W,1);
    // deck
    g.drawImage(deck,0,FY);
    const dim=over||flying;
    // dial knob and needle
    const nx=DX+(DRAD-5)*Math.cos(a),ny=DY-(DRAD-5)*Math.sin(a);
    for(let y=-6;y<=6;y++)for(let x=-6;x<=6;x++){const r=Math.hypot(x,y);if(r>6.4)continue;const lt=(-x-y)/6;dot(g,DX+x,DY+y,r>5.4?PAL.bevelLo:lt>.45?PAL.chill:lt>-.2?PAL.cold:PAL.line)}
    line(g,DX,DY,nx,ny,dim?PAL.cold:PAL.ember);line(g,DX+Math.cos(a)*6,DY-Math.sin(a)*6,DX+(DRAD-1)*Math.cos(a),DY-(DRAD-1)*Math.sin(a),dim?PAL.cold:PAL.flare);
    dot(g,DX,DY,PAL.hot);
    TK.text(g,(ang>0?'+':ang<0?'-':'')+Math.abs(ang),33,FY+12,PAL.hot);
    // sling: pouch and bands
    const sh=twang?twang.wob:0;
    const PX=Math.round(128-off),PY=Math.round(RY+sh);
    const t=Math.min(1,off/PULLMAX),band=t<.35?PAL.them:t<.75?PAL.ember:PAL.bad;
    line(g,FKX,FY+9,PX-1,PY-2,band);line(g,FKX,FY+26,PX-1,PY+2,band);
    g.fillStyle=PAL.bevelLo;g.fillRect(PX-3,PY-4,5,9);g.fillStyle=shade(PAL.them,-.4);g.fillRect(PX-2,PY-3,3,7);
    g.fillStyle=PAL.ice;g.fillRect(PX,PY-1,2,2);dot(g,PX+2,PY,PAL.ember);
    if(lastPow>0){const lx=Math.round(128-offOf(lastPow));g.fillStyle=PAL.t2;g.fillRect(lx-1,FY+26,3,1);dot(g,lx,FY+25,PAL.t2)}
    const shownP=pow>0?pow:0;
    TK.text(g,shownP?'PWR '+shownP:lastPow>0?'LAST '+lastPow:'PWR',W-14,FY+4,shownP?PAL.hot:PAL.cold,'right');
    if(!pull&&!dim&&lastPow<0&&used===0&&(Math.floor(clock*1.5)%2)){TK.text(g,'<',PX-8,PY-2,PAL.ember)}
    if(dim){g.globalAlpha=.35;g.fillStyle=PAL.void;g.fillRect(0,FY+2,W,H-FY-2);g.globalAlpha=1}
  }
  function frame(now){
    raf=requestAnimationFrame(frame);
    if(now-last<32)return;const dt=Math.min(.1,(now-last)/1000);last=now;clock+=dt;
    if(twang){twang.t+=dt;const k=twang.t;
      if(k<.06){off=twang.from*(1-k/.06);twang.wob=0}
      else{const q=k-.06,amp=Math.min(5,twang.from*.08)*Math.exp(-q*6);off=Math.max(0,-amp*Math.sin(q*36));twang.wob=amp*Math.sin(q*44)*.6;if(q>.8){twang=null;off=0}}}
    if(flying){flying.k=Math.min(flying.pts.length-1,flying.k+Math.max(1,Math.round(260*dt)));if(flying.k>=flying.pts.length-1)land(flying)}
    draw();
  }

  // ---- input ----
  const ptf=e=>{const r=p.cv.getBoundingClientRect();return{x:(e.clientX-r.left)*W/r.width,y:(e.clientY-r.top)*H/r.height}};
  let dial=null,pull=null;
  const dAng=q=>Math.atan2(DY-q.y,q.x-DX)*180/Math.PI;
  p.cv.addEventListener('pointerdown',e=>{
    if(over||flying)return;const q=ptf(e);
    if(q.y<FY)return;started=true;
    e.preventDefault();try{p.cv.setPointerCapture(e.pointerId)}catch(_){}
    if(q.x<31){dial={id:e.pointerId,last:dAng(q),acc:ang}}
    else if(q.x>=52){pull={id:e.pointerId,x0:q.x};twang=null}
  });
  p.cv.addEventListener('pointermove',e=>{
    const q=ptf(e);
    if(dial&&e.pointerId===dial.id){e.preventDefault();let dd=dAng(q)-dial.last;if(dd>180)dd-=360;if(dd<-180)dd+=360;dial.last=dAng(q);
      dial.acc=clamp(dial.acc+dd,AMIN,AMAX);const n=Math.round(dial.acc);if(n!==ang){ang=n;restub()}}
    else if(pull&&e.pointerId===pull.id){e.preventDefault();off=clamp(pull.x0-q.x,0,PULLMAX);
      const np=off<14?0:Math.round(PMIN+(off-14)/(PULLMAX-14)*(PMAX-PMIN));if(np!==pow){pow=np;restub()}}
    else p.cv.style.cursor=q.y>=FY&&(q.x<31||q.x>=52)&&!over?'grab':'default';
  });
  const up=e=>{
    if(dial&&e.pointerId===dial.id){dial=null;return}
    if(!pull||e.pointerId!==pull.id)return;pull=null;
    const pw=pow;pow=0;twang={t:0,from:off,wob:0};
    if(e.type==='pointercancel'||pw<PMIN){if(off>3){note='TOO WEAK';noteT=clock+1.2}restub();return}
    TK.sfx('sling2','launch');lastPow=pw;launch(pw);
  };
  p.cv.addEventListener('pointerup',up);p.cv.addEventListener('pointercancel',up);
  p.cv.addEventListener('wheel',e=>{if(over||flying)return;const q=ptf(e);if(q.y<FY||q.x>=31)return;e.preventDefault();ang=clamp(ang+(e.deltaY<0?1:-1),AMIN,AMAX);restub()},{passive:false});

  function launch(pw){
    if(over||flying)return;used++;
    const r=sim(P,ang,pw);flying={r,pts:pl(r.pts),k:0};
  }
  function land(f){
    const r=f.r;flying=null;
    const hit=r.end==='hit';old.push({pts:f.pts,hit});while(old.length>4)old.shift();
    const e=f.pts[f.pts.length-1];
    if(hit){over=true;missTxt='HIT';TK.sfx('sling2','hit');TK.sfx('sling2','win');fx={x:e[0],y:e[1],c:PAL.good,t0:clock};
      ctx.done({score:scoreHit(used,r.hitD,P.tr),detail:`Hit on launch ${used} of ${maxShots}, ${Math.round(100*r.hitD/P.tr)}% off centre`});return}
    if(r.end==='crash')fx={x:e[0],y:e[1],c:PAL.bad,t0:clock};
    const miss=Math.round(Math.max(0,r.best-P.tr));bestMiss=Math.min(bestMiss,r.best);
    missTxt=r.end==='crash'?'IMPACT':r.end==='zone'?'NO-FLY':'MISS '+miss;
    if(used>=maxShots){over=true;note='OUT OF PROBES';noteT=clock+99;ctx.done({score:scoreMiss(bestMiss,P.tr),detail:`No hit in ${maxShots} launches`});return}
    restub();
  }
  restub();draw();raf=requestAnimationFrame(frame);
  return{
    destroy(){over=true;cancelAnimationFrame(raf);p.destroy()},
    giveUp(){if(over)return;over=true;ctx.done({score:used?scoreMiss(bestMiss,P.tr)*0.5:0,detail:'Gave up'})},
    _test:{get ang(){return ang},get used(){return used},get lastPow(){return lastPow},get flying(){return !!flying},get over(){return over},cv:p.cv,P,FY,DX,DY,W,H},
  };
}

TK.register({
  id:ID,name:'Gravity Sling 2',hint:'Hit the target.',controls:CONTROLS,where:'Binary stars, giant planets',skill:'Physics intuition',
  blurb:'Bend a probe around heavy masses into a target ring.',
  how:[
    'The dial sets the aim. The further back the sling, the faster the probe.',
    'Stars and planets bend the path. Old paths stay faint.',
    'Fewer launches score more.',
  ],
  deeper:'More masses. Sector 4+: the target moves while the probe flies. Sector 5: a red no-fly zone.',
  sensors:'Each point: a longer predicted path from the launcher. 2+ and 4+: one extra launch.',
  mount,
  _t:logic,
});
})();
