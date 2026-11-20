// Cutting Torch: cut a loop round a cargo crate in a wreck's hull without slicing the live lines.
(function(){
'use strict';
const ID='wreck1';
const W=304,H=200;      // sim units: two per art pixel
const SPEED=34;      // torch cut speed, px/s: the torch is slow and goes straight toward your finger
const TR=2;          // torch hit radius
const SR=1.5;        // scorch margin on the crate
const HITS_MAX=3;
const CFG={
  1:{lines:3,fuel:0,gap:[22,30],gas:1.8,faint:0,feed:0},
  2:{lines:4,fuel:1,gap:[17,25],gas:1.65,faint:0,feed:0},
  3:{lines:5,fuel:2,gap:[14,21],gas:1.5,faint:0,feed:0},
  4:{lines:5,fuel:2,gap:[13,19],gas:1.45,faint:2,feed:0},
  5:{lines:5,fuel:2,gap:[12,18],gas:1.45,faint:1,feed:1},
};
const PULSE={per:2.6,live:1.5};
// Every status the HUD can show. Each must fit right of the HITS boxes: 14 characters at most.
const MSG={zap:'ZAP! LIVE LINE',fuel:'FUEL LINE!',burn:'CRATE BURNT',piece:'EMPTY PIECE',free:'CUT FREE',gas:'OUT OF GAS',fire:'TORCH OUT'};
// HUD strip layout in art pixels: GAS label + bar, HITS label + boxes, then the status, right-aligned.
const HUDL={gasX:3,barX:17,barW:32,hitsX:55,boxX:73,boxP:5,statusR:149};
HUDL.boxEnd=HUDL.boxX+HITS_MAX*HUDL.boxP-1;HUDL.statusL=HUDL.boxEnd+5;HUDL.maxChars=Math.floor((HUDL.statusR-HUDL.statusL+2)/4);
const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));
const rr=(rng,a,b)=>a+rng()*(b-a);

function spline(P,n){
  const out=[];
  for(let i=0;i<P.length-1;i++){
    const p0=P[Math.max(0,i-1)],p1=P[i],p2=P[i+1],p3=P[Math.min(P.length-1,i+2)];
    for(let k=0;k<n;k++){const t=k/n,t2=t*t,t3=t2*t;const f=j=>0.5*(2*p1[j]+(-p0[j]+p2[j])*t+(2*p0[j]-5*p1[j]+4*p2[j]-p3[j])*t2+(-p0[j]+3*p1[j]-3*p2[j]+p3[j])*t3);out.push([f(0),f(1)])}
  }
  out.push(P[P.length-1].slice());return out;
}
function rectDist(R,x,y){const dx=Math.max(R.x0-x,0,x-R.x1),dy=Math.max(R.y0-y,0,y-R.y1);return Math.hypot(dx,dy)}
function segDist(px,py,ax,ay,bx,by){const vx=bx-ax,vy=by-ay,l=vx*vx+vy*vy;let t=l?((px-ax)*vx+(py-ay)*vy)/l:0;t=clamp(t);return Math.hypot(px-ax-vx*t,py-ay-vy*t)}
function polyDist(pts,x,y){let d=Infinity;for(let i=0;i<pts.length-1;i++){const a=pts[i],b=pts[i+1];if(Math.abs(a[0]-x)>d+12&&Math.abs(b[0]-x)>d+12)continue;const e=segDist(x,y,a[0],a[1],b[0],b[1]);if(e<d)d=e}return d}
function live(L,t){return !L.pulse||((t+L.phase)%PULSE.per)<PULSE.live}

// A line that passes one side of the crate at a set gap, edge to edge.
function makeLine(R,side,g,half,rng){
  const horiz=side<2;
  let pass;
  if(side===0)pass=[rr(rng,R.x0+6,R.x1-6),R.y0-g-half];
  else if(side===1)pass=[rr(rng,R.x0+6,R.x1-6),R.y1+g+half];
  else if(side===2)pass=[R.x0-g-half,rr(rng,R.y0+6,R.y1-6)];
  else pass=[R.x1+g+half,rr(rng,R.y0+6,R.y1-6)];
  let a,b;
  if(horiz){
    a=rng()<0.75?[-12,clamp(pass[1]+rr(rng,-60,60),6,H-6)]:[rr(rng,10,pass[0]-30),side===0?-12:H+12];
    b=rng()<0.75?[W+12,clamp(pass[1]+rr(rng,-60,60),6,H-6)]:[rr(rng,pass[0]+30,W-10),side===0?-12:H+12];
  }else{
    a=rng()<0.75?[clamp(pass[0]+rr(rng,-55,55),6,W-6),-12]:[side===2?-12:W+12,rr(rng,10,pass[1]-30)];
    b=rng()<0.75?[clamp(pass[0]+rr(rng,-55,55),6,W-6),H+12]:[side===2?-12:W+12,rr(rng,pass[1]+30,H-10)];
  }
  const m1=[(a[0]+pass[0])/2+rr(rng,-14,14),(a[1]+pass[1])/2+rr(rng,-14,14)];
  const m2=[(b[0]+pass[0])/2+rr(rng,-14,14),(b[1]+pass[1])/2+rr(rng,-14,14)];
  return spline([a,m1,pass,m2,b],14);
}
function gapOf(R,L){let g=Infinity;for(const p of L.pts){const d=rectDist(R,p[0],p[1])-L.half;if(d<g)g=d}return g}
function clashes(R,A,B){
  // near the crate, two lines must not touch or run on top of each other
  for(const p of A.pts){if(rectDist(R,p[0],p[1])>55)continue;for(const q of B.pts){if(rectDist(R,q[0],q[1])>55)continue;if(Math.hypot(p[0]-q[0],p[1]-q[1])<A.half+B.half+6)return true}}
  return false;
}

function gen(depth,sensors,rng){
  const c=CFG[depth];
  for(let tries=0;tries<600;tries++){
    const cw=Math.round(rr(rng,70,90)),ch=Math.round(rr(rng,46,58));
    const x0=Math.round(rr(rng,52,W-52-cw)),y0=Math.round(rr(rng,48,H-48-ch));
    const R={x0,y0,x1:x0+cw,y1:y0+ch};
    const lines=[];
    let feed=null;
    if(c.feed){
      // the crate's own power cable, plugged into one side; it must be crossed while dark
      const side=Math.floor(rng()*4);
      let plug,a;
      if(side===0){plug=[rr(rng,R.x0+14,R.x1-14),R.y0];a=[clamp(plug[0]+rr(rng,-50,50),10,W-10),-12]}
      else if(side===1){plug=[rr(rng,R.x0+14,R.x1-14),R.y1];a=[clamp(plug[0]+rr(rng,-50,50),10,W-10),H+12]}
      else if(side===2){plug=[R.x0,rr(rng,R.y0+12,R.y1-12)];a=[-12,clamp(plug[1]+rr(rng,-40,40),10,H-10)]}
      else{plug=[R.x1,rr(rng,R.y0+12,R.y1-12)];a=[W+12,clamp(plug[1]+rr(rng,-40,40),10,H-10)]}
      const out=[plug[0]+[0,0,-26,26][side],plug[1]+[-26,26,0,0][side]];
      const mid=[(a[0]+out[0])/2+rr(rng,-12,12),(a[1]+out[1])/2+rr(rng,-12,12)];
      feed={kind:'power',half:3.5,pts:spline([a,mid,out,plug],14),pulse:true,phase:rng()*PULSE.per,feed:true,side,faint:false};
    }
    const kinds=[];for(let i=0;i<c.lines;i++)kinds.push(i<c.fuel?'fuel':'power');
    let sides=TK_shuffle([0,1,2,3],rng);
    let att=0;
    while(lines.length<c.lines&&att<160){
      att++;
      const kind=kinds[lines.length];const half=kind==='fuel'?4.5:3.5;
      const side=sides[lines.length%4];
      const g=rr(rng,c.gap[0],c.gap[1])+(lines.length>=4?rr(rng,8,20):0);
      const L={kind,half,pts:makeLine(R,side,g,half,rng),pulse:false,phase:0,faint:false};
      if(gapOf(R,L)<c.gap[0]-0.01)continue;
      if(lines.some(M=>clashes(R,L,M)))continue;
      if(feed&&clashes(R,L,feed))continue;
      lines.push(L);
    }
    if(lines.length<c.lines)continue;
    const gmin=Math.min(...lines.map(L=>gapOf(R,L)));
    const o=Math.max(4,Math.min(9,gmin/2));
    const loop=loopPath(R,o,feed);
    // the reference loop must be clean
    let bad=false;
    for(const p of loop.pts){for(const L of lines)if(polyDist(L.pts,p[0],p[1])<L.half+TR+1.5){bad=true;break}if(bad)break}
    if(bad)continue;
    const faintN=Math.min(c.faint,lines.length);
    TK_shuffle(lines.map((_,i)=>i),rng).slice(0,faintN).forEach(i=>lines[i].faint=true);
    const all=feed?lines.concat([feed]):lines;
    const gas=loop.len*(c.gas+0.1*sensors);
    return {R,lines:all,o,gmin,ref:loop.len,gas,loop:loop.pts};
  }
  throw new Error('wreck1: no puzzle');
}
function TK_shuffle(a,r){a=a.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(r()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a}

// Rounded loop at offset o round the crate, sampled every ~2 px, starting on the side away from the feed.
function loopPath(R,o,feed){
  const pts=[];const cx=[R.x0,R.x1,R.x1,R.x0],cy=[R.y0,R.y0,R.y1,R.y1];
  const a0=[Math.PI,1.5*Math.PI,0,0.5*Math.PI];
  for(let k=0;k<4;k++){
    for(let j=0;j<=8;j++){const a=a0[k]+j/8*Math.PI/2;pts.push([cx[k]+o*Math.cos(a),cy[k]+o*Math.sin(a)])}
  }
  pts.push(pts[0].slice());
  // resample
  const out=[pts[0].slice()];let len=0;
  for(let i=1;i<pts.length;i++){const a=pts[i-1],b=pts[i];const d=Math.hypot(b[0]-a[0],b[1]-a[1]);const n=Math.max(1,Math.ceil(d/2));for(let k=1;k<=n;k++)out.push([a[0]+(b[0]-a[0])*k/n,a[1]+(b[1]-a[1])*k/n]);len+=d}
  out.pop();
  // start away from the feed: rotate the list
  let start=Math.floor(out.length*0.1);
  if(feed){const plug=feed.pts[feed.pts.length-1];let far=0,fd=-1;out.forEach((p,i)=>{const d=Math.hypot(p[0]-plug[0],p[1]-plug[1]);if(d>fd){fd=d;far=i}});start=far}
  const rot=out.slice(start).concat(out.slice(0,start));
  return {pts:rot,len};
}

// ---- the torch simulation (shared by the game and the test bot) ----
function newSim(P){return{t:0,torch:null,pts:[],used:0,hits:0,scorch:0,touch:new Set(),inCrate:false,over:false,freed:false,poly:null,pieces:[],events:[],near:Infinity}}
function segX(a,b,c,d){
  const r1=(b[0]-a[0]),r2=(b[1]-a[1]),s1=(d[0]-c[0]),s2=(d[1]-c[1]);const den=r1*s2-r2*s1;if(Math.abs(den)<1e-9)return null;
  const t=((c[0]-a[0])*s2-(c[1]-a[1])*s1)/den,u=((c[0]-a[0])*r2-(c[1]-a[1])*r1)/den;
  if(t>0&&t<=1&&u>=0&&u<=1)return[a[0]+r1*t,a[1]+r2*t];return null;
}
function inPoly(poly,x,y){let c=false;for(let i=0,j=poly.length-1;i<poly.length;j=i++){const a=poly[i],b=poly[j];if((a[1]>y)!==(b[1]>y)&&x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0])c=!c}return c}
function contact(S,P){
  const[x,y]=S.torch;let near=Infinity;
  P.lines.forEach((L,i)=>{
    const d=polyDist(L.pts,x,y)-L.half;if(d<near&&live(L,S.t))near=d;
    if(d<TR){if(!S.touch.has(i)&&live(L,S.t)){S.touch.add(i);S.hits++;S.events.push({type:'hit',kind:L.kind,x,y,i})}}
    else S.touch.delete(i);
  });
  S.near=near;
  const R=P.R;const inC=x>R.x0-SR&&x<R.x1+SR&&y>R.y0-SR&&y<R.y1+SR;
  if(inC&&!S.inCrate){S.scorch++;S.events.push({type:'scorch',x,y})}
  S.inCrate=inC;
  if(S.hits>=HITS_MAX&&!S.over){S.over=true;S.events.push({type:'fail',why:'hits'})}
}
function pierce(S,P,x,y){
  if(S.torch||S.over)return;
  S.torch=[clamp(x,2,W-2),clamp(y,2,H-2)];S.pts.push([S.torch[0],S.torch[1],S.t]);contact(S,P);
}
function addPoint(S,P){
  const n=S.pts.length;const b=S.pts[n-1],a=S.pts[n-2];
  if(!a)return;
  // closing: the new segment crosses an old one, or comes back onto an old point
  for(let i=0;i<n-10;i++){
    const c=S.pts[i],d=S.pts[i+1];
    const X=segX(a,b,c,d);
    const hit=X||(Math.hypot(b[0]-c[0],b[1]-c[1])<2.2?[c[0],c[1]]:null);
    if(!hit)continue;
    const poly=S.pts.slice(i+1,n-1).map(p=>[p[0],p[1]]);poly.unshift(hit);poly.push(hit);
    if(poly.length<6)continue;
    const R=P.R;
    const crateIn=[[R.x0,R.y0],[R.x1,R.y0],[R.x1,R.y1],[R.x0,R.y1],[(R.x0+R.x1)/2,(R.y0+R.y1)/2]].every(q=>inPoly(poly,q[0],q[1]));
    if(crateIn){S.freed=true;S.over=true;S.poly=poly;S.events.push({type:'freed'});return}
    if(!S.pieces.some(pc=>pc.i===i)){S.pieces.push({i,poly,t:S.t});S.events.push({type:'piece',poly})}
    return;
  }
}
function step(S,P,tx,ty,dt){
  S.t+=dt;
  if(!S.torch||S.over)return;
  const[x,y]=S.torch;tx=clamp(tx,2,W-2);ty=clamp(ty,2,H-2);
  const dx=tx-x,dy=ty-y,d=Math.hypot(dx,dy);
  const left=P.gas-S.used;
  let m=Math.min(d,SPEED*dt,left);
  if(m>1e-6){
    // sub-steps of at most 1 px so thin lines can't be skipped
    const n=Math.ceil(m);
    for(let k=0;k<n&&!S.over;k++){
      const s=m/n;S.torch=[S.torch[0]+dx/d*s,S.torch[1]+dy/d*s];S.used+=s;
      const l=S.pts[S.pts.length-1];
      if(Math.hypot(S.torch[0]-l[0],S.torch[1]-l[1])>=1.6){S.pts.push([S.torch[0],S.torch[1],S.t]);addPoint(S,P)}
      contact(S,P);
    }
  }else contact(S,P);
  if(!S.over&&S.used>=P.gas-1e-6){S.over=true;S.events.push({type:'fail',why:'gas'})}
}
function scoreOf(S,P){
  if(!S.freed)return S.hits>=HITS_MAX?0.08:0.12;
  const waste=clamp((S.used/P.ref-1.2)/Math.max(0.1,P.gas/P.ref-1.2));
  if(S.scorch>=3)return 0.15; // three burns: the sample inside is cooked (Jon: cut the box twice and still got legendary)
  return clamp(1-0.22*S.hits-0.32*S.scorch-0.3*waste,0.15,1);
}

// Test bot: follow the reference loop; wait at the feed until it goes dark.
function bot(P,opts){
  opts=opts||{};const S=newSim(P);const dt=1/60;
  const path=P.loop.concat([P.loop[0]]);
  pierce(S,P,path[0][0],path[0][1]);
  let k=1,guard=0;
  while(!S.over&&guard++<60*200){
    const tgt=path[Math.min(k,path.length-1)];
    // look ahead: would the next few px touch a live line within the next 0.4 s?
    const[x,y]=S.torch;const d=Math.hypot(tgt[0]-x,tgt[1]-y);
    let wait=false;
    if(d>0){const ax=x+(tgt[0]-x)/d*6,ay=y+(tgt[1]-y)/d*6;
      for(const L of P.lines){if(!L.pulse)continue;const dd=polyDist(L.pts,ax,ay)-L.half;const here=polyDist(L.pts,x,y)-L.half;if(dd<TR+5&&here>=TR){for(let f=0;f<=0.45;f+=0.05)if(live(L,S.t+f)){wait=true;break}}}}
    if(wait){step(S,P,x,y,dt);continue}
    step(S,P,tgt[0],tgt[1],dt);
    if(Math.hypot(S.torch[0]-tgt[0],S.torch[1]-tgt[1])<0.5)k++;
    if(k>=path.length+3)break;
  }
  return{S,score:scoreOf(S,P)};
}

// ---- pixel art ----
function banner(g,A,PW,y,big,ctrls,t){const iw=ctrls.reduce((a,k)=>a+(k==='click'?13:k==='hold'?21:22)+3,-3);const w=Math.max(big.length*4-1,iw)+10;const x=Math.floor(PW/2-w/2);g.fillStyle=A.bevelLo;g.fillRect(x,y,w,27);g.fillStyle=A.panel;g.fillRect(x+1,y+1,w-2,25);g.fillStyle=A.bevelHi;g.fillRect(x+1,y+1,w-2,1);TK.text(g,big,PW/2,y+4,A.hot,'center');let ix=Math.floor(PW/2-iw/2);for(const k of ctrls)ix+=TK.icon(g,k,ix,y+12,{t})+3}
const PW=W/2,PH=H/2,HUD=16;          // art pixels: the camera view is 152x100, the HUD strip 16 rows
const BAYER=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5];
const bt=(x,y)=>(BAYER[(y&3)*4+(x&3)]+.5)/16;
function ramps(){
  const A=TK.PAL;
  return{
    metal:['#080b11','#111823','#182230','#22303f','#2d3c4e','#3d4d61','#6b7d94','#8fa3ba'],
    cable:['#1c1609','#3e3016','#6e5626',A.warn,'#e0bd6a'],
    pipe:['#2a0f0b','#4a1c16','#7a2f24',A.bad,'#e07a62'],
    crate:['#080b11','#26333f','#3a4a5c',A.cold,A.chill,A.ice],
    heat:['#2a160b','#5a2e10',A.ember,A.flare,A.hot,'#fff4dc'],
    smoke:['#1a222c','#2d3c4e',A.cold,A.chill],
  };
}
// stamp a thick polyline into a pixel set; keep the nearest sample and its normal for shading
function rasterLine(L){
  const r=L.half/2;const map=new Map();
  for(let i=0;i<L.pts.length-1;i++){
    const a=L.pts[i],b=L.pts[i+1];const len=Math.hypot(b[0]-a[0],b[1]-a[1]);const n=Math.max(1,Math.ceil(len));
    const tx=(b[0]-a[0])/(len||1),ty=(b[1]-a[1])/(len||1);
    for(let k=0;k<=n;k++){
      const x=(a[0]+(b[0]-a[0])*k/n)/2,y=(a[1]+(b[1]-a[1])*k/n)/2;
      for(let py=Math.floor(y-r-1);py<=Math.ceil(y+r+1);py++)for(let px=Math.floor(x-r-1);px<=Math.ceil(x+r+1);px++){
        if(px<0||py<0||px>=PW||py>=PH)continue;
        const dx=px+.5-x,dy=py+.5-y,d=Math.hypot(dx,dy);if(d>r+.35)continue;
        const key=py*PW+px;const old=map.get(key);
        if(!old||d<old.d){let nx=-ty,ny=tx;if(nx*-.7+ny*-.7<0){nx=-nx;ny=-ny}map.set(key,{d,s:(dx*nx+dy*ny)/Math.max(.5,r),u:(i+k/n)})}
      }
    }
  }
  return map;
}

function mount(stage,ctx){
  const P=gen(ctx.depth,ctx.sensors,ctx.rng);
  const S=newSim(P);const sens=ctx.sensors;const A=TK.PAL;const RP=ramps();
  // the torch starts already on the plate, at the head of the dashed loop: every tap is a cut, there's no 'place it first' tap
  pierce(S,P,P.loop[0][0],P.loop[0][1]);
  const px=TK.pixel(stage,{w:PW,h:PH+HUD});const g=px.g;px.cv.style.cursor='crosshair';
  let path=[],down=false,drag=false,downAt=null,raf=0,last=0,acc=0,doneFired=false,endT=0;const timers=[];const fx=[];
  let status='',statusCol=A.chill,statusT=0,shakeT=0,torchA=null;
  // the flame burns only while the torch is cutting (moving to a point); otherwise a small pilot light
  const flameOn=()=>!!S.torch&&!S.over&&path.length>0&&Math.hypot(path[0][0]-S.torch[0],path[0][1]-S.torch[1])>0.6;
  const rnd=ctx.rng;
  // --- static layer: torn hull plate, crate, lines ---
  const st=document.createElement('canvas');st.width=PW;st.height=PH;const s=st.getContext('2d');
  const put=(c,x,y,col)=>{c.fillStyle=col;c.fillRect(x,y,1,1)};
  const M=RP.metal;
  // torn corner: the corner farthest from the crate is ripped open to space
  const R=P.R,ccx=(R.x0+R.x1)/4,ccy=(R.y0+R.y1)/4;
  const corner=[[0,0],[PW,0],[0,PH],[PW,PH]].reduce((a,b)=>Math.hypot(b[0]-ccx,b[1]-ccy)>Math.hypot(a[0]-ccx,a[1]-ccy)?b:a);
  const tornR=[];for(let i=0;i<=24;i++)tornR.push(16+rnd()*14+(i%3===0?rnd()*8:0));
  const torn=(x,y)=>{const dx=x-corner[0],dy=y-corner[1];const d=Math.hypot(dx,dy);const a=Math.atan2(Math.abs(dy),Math.abs(dx))/(Math.PI/2)*24;const i=Math.floor(a),f=a-i;const lim=tornR[i]*(1-f)+tornR[Math.min(24,i+1)]*f;return d<lim};
  const stars=[];for(let i=0;i<60;i++)stars.push([Math.floor(rnd()*PW),Math.floor(rnd()*PH),rnd()]);
  // plates
  const plates=[];const PWt=38,PHt=25;
  for(let row=0;row*PHt<PH;row++){const off=row%2?19:0;for(let x=-off;x<PW;x+=PWt)plates.push({x,y:row*PHt,w:PWt,h:PHt,tone:Math.floor(rnd()*3)})}
  for(let y=0;y<PH;y++)for(let x=0;x<PW;x++){
    if(torn(x,y)){put(s,x,y,A.void);continue}
    const pl=plates.find(p=>x>=p.x&&x<p.x+p.w&&y>=p.y&&y<p.y+p.h);
    const lx=x-pl.x,ly=y-pl.y;
    let c=2+(pl.tone===2?1:0);
    // light from the top-left: a soft falloff across each plate
    const shade=(lx/pl.w+ly/pl.h)/2;
    if(bt(x,y)<0.35-shade*0.5)c++;
    if(bt(x+1,y+2)<shade*0.35)c--;
    // grime
    const n=Math.sin(x*0.37+y*0.11)*Math.sin(x*0.13-y*0.29)+Math.sin(x*0.05+y*0.21);
    if(n>1.05&&bt(x,y)<0.5)c--;
    if(lx===0||ly===0)c=5;                       // lit edge
    if(lx===pl.w-1||ly===pl.h-1)c=0;             // seam shadow
    put(s,x,y,M[Math.max(0,Math.min(7,c))]);
  }
  // rivets
  for(const pl of plates)for(const[ox,oy]of[[3,3],[pl.w-4,3],[3,pl.h-4],[pl.w-4,pl.h-4],[Math.floor(pl.w/2),3]]){const x=pl.x+ox,y=pl.y+oy;if(x<0||x>=PW-1||y>=PH-1||torn(x,y))continue;put(s,x,y,M[6]);put(s,x+1,y+1,M[0]);put(s,x+1,y,M[4])}
  // old scorch and a stencil
  TK.text(s,'HOLD 3',corner[0]?3:PW-26,corner[1]?3:PH-8,M[3]);
  // torn rim: bright bent metal, dark underside
  for(let y=0;y<PH;y++)for(let x=0;x<PW;x++){
    if(torn(x,y))continue;let edge=false,below=false;
    for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]]){const nx=x+dx,ny=y+dy;if(nx>=0&&ny>=0&&nx<PW&&ny<PH&&torn(nx,ny)){edge=true;if(dx+dy>0)below=true}}
    if(edge)put(s,x,y,below?M[7]:M[6]);
  }
  for(let y=0;y<PH;y++)for(let x=0;x<PW;x++){if(!torn(x,y))continue;let near=false;for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]]){const nx=x+dx,ny=y+dy;if(nx>=0&&ny>=0&&nx<PW&&ny<PH&&!torn(nx,ny))near=true}if(near)put(s,x,y,M[0])}
  // crate (sim units /2), with a dithered drop shadow to the lower right
  const cx0=Math.round(R.x0/2),cy0=Math.round(R.y0/2),cx1=Math.round(R.x1/2)-1,cy1=Math.round(R.y1/2)-1;
  for(let y=cy0+2;y<=cy1+3;y++)for(let x=cx0+2;x<=cx1+3;x++)if((x>cx1||y>cy1)&&bt(x,y)<0.6)put(s,x,y,M[0]);
  const CR=RP.crate;
  for(let y=cy0;y<=cy1;y++)for(let x=cx0;x<=cx1;x++){
    let c=2;const lx=(x-cx0)/(cx1-cx0),ly=(y-cy0)/(cy1-cy0);
    if(bt(x,y)<0.45-(lx+ly)*0.3)c=3;
    if(x===cx0||y===cy0||x===cx1||y===cy1)c=0;
    else if(x===cx0+1||y===cy0+1)c=4;
    else if(x===cx1-1||y===cy1-1)c=1;
    put(s,x,y,CR[c]);
  }
  // straps and teal salvage corners
  for(const fx0 of[0.28,0.72]){const x=Math.round(cx0+(cx1-cx0)*fx0);for(let y=cy0+1;y<cy1;y++){put(s,x,y,CR[1]);put(s,x+1,y,CR[4])}}
  for(const[x,y,dx,dy]of[[cx0+2,cy0+2,1,1],[cx1-2,cy0+2,-1,1],[cx0+2,cy1-2,1,-1],[cx1-2,cy1-2,-1,-1]]){put(s,x,y,A.tractor);put(s,x+dx,y,A.tractor);put(s,x,y+dy,A.tractor)}
  TK.text(s,'SAMPLE',Math.round((cx0+cx1)/2),Math.round((cy0+cy1)/2)-2,A.mark,'center');
  // lines: body only (the live glow is drawn per frame)
  const LR=P.lines.map(L=>({L,map:rasterLine(L)}));
  function paintLine(c,o,faintA){
    const ramp=o.L.kind==='power'?RP.cable:RP.pipe;
    const outl=new Set();
    for(const k of o.map.keys()){const x=k%PW,y=(k/PW)|0;for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1]]){const nx=x+dx,ny=y+dy;if(nx<0||ny<0||nx>=PW||ny>=PH)continue;const nk=ny*PW+nx;if(!o.map.has(nk))outl.add(nk)}}
    for(const k of outl){const x=k%PW,y=(k/PW)|0;if(faintA<1&&bt(x,y)>faintA)continue;put(c,x,y,ramp[0])}
    for(const[k,v]of o.map){const x=k%PW,y=(k/PW)|0;if(faintA<1&&bt(x,y)>faintA)continue;
      let i=2;if(v.s>0.45)i=3;if(v.s>0.9)i=4;if(v.s<-0.45)i=1;
      if(o.L.kind==='fuel'&&Math.floor(v.u*0.9)%3===0&&Math.abs(v.s)<0.6)i=Math.max(1,i-1); // pipe bands
      put(c,x,y,ramp[i]);}
    if(o.L.feed){const p=o.L.pts[o.L.pts.length-1];const x=Math.round(p[0]/2),y=Math.round(p[1]/2);for(let j=-2;j<=1;j++)for(let i=-2;i<=1;i++)put(c,x+i,y+j,(i===-2||j===-2)?M[6]:(i===1||j===1)?M[0]:M[5])}
  }
  const faintCv=document.createElement('canvas');faintCv.width=PW;faintCv.height=PH;const fcx=faintCv.getContext('2d');
  for(const o of LR){if(o.L.faint&&sens<4){paintLine(fcx,o,1);paintLine(s,o,0.22)}else paintLine(s,o,1)}
  const SD=s.getImageData(0,0,PW,PH).data;
  // cut pixels
  const cut=new Float32Array(PW*PH).fill(-1);const cutList=[];
  const debris=[];for(let i=0;i<7;i++)debris.push({x:rnd()*PW,y:rnd()*PH,vx:(rnd()-.5)*3,vy:(rnd()-.5)*2,sz:1+Math.floor(rnd()*2),c:rnd()<0.5?M[6]:M[5],ph:rnd()*6});

  function toWorld(e){const r=px.cv.getBoundingClientRect();return[(e.clientX-r.left)/r.width*PW*2,(e.clientY-r.top)/r.height*(PH+HUD)*2]}
  // Click: the first click lights the torch; each click after adds a point to its path, and it cuts
  // to each point in turn. Holding and moving still steers it live, straight at the pointer.
  const cl=p=>[clamp(p[0],2,W-2),clamp(p[1],2,H-2)];
  function onDown(e){
    if(S.over)return;e.preventDefault();try{px.cv.setPointerCapture(e.pointerId)}catch(_){}
    const p=toWorld(e);if(p[1]>H)return;down=true;drag=false;downAt=p;
    if(!S.torch)return;
    if(path.length<12)path.push(cl(p));
  }
  function onMove(e){if(!down||S.over)return;e.preventDefault();const p=toWorld(e);
    if(!drag&&Math.hypot(p[0]-downAt[0],p[1]-downAt[1])>8)drag=true;
    if(drag)path=[cl(p)];}
  function onUp(){down=false;drag=false}
  px.cv.addEventListener('pointerdown',onDown);px.cv.addEventListener('pointermove',onMove);
  px.cv.addEventListener('pointerup',onUp);px.cv.addEventListener('pointercancel',onUp);
  function say(t,c,secs){status=t;statusCol=c;statusT=secs||2.5}
  function sparks(x,y,n,cols,sp){for(let i=0;i<n;i++){const a=Math.random()*6.283,v=(0.3+Math.random())*sp;fx.push({k:'spark',x,y,vx:Math.cos(a)*v,vy:Math.sin(a)*v,age:0,life:0.25+Math.random()*0.45,c:cols[Math.floor(Math.random()*cols.length)]})}}
  function events(){
    while(S.events.length){const ev=S.events.shift();const x=ev.x/2,y=ev.y/2;
      if(ev.type==='hit'){fx.push({k:'flash',x,y,age:0,life:0.3});shakeT=0.4;
        if(ev.kind==='power'){fx.push({k:'arc',x,y,age:0,life:0.5});sparks(x,y,24,[A.ice,A.tractor,A.mark],40);say(MSG.zap,A.bad,2.5)}
        else{fx.push({k:'puff',x,y,age:0,life:1.6});sparks(x,y,14,[A.flare,A.hot,A.ember],26);say(MSG.fuel,A.bad,2.5)}
      }else if(ev.type==='scorch'){fx.push({k:'burn',x,y,age:0,life:1e9});say(MSG.burn,A.bad,2)}
      else if(ev.type==='piece'){fx.push({k:'piece',poly:ev.poly,age:0,life:1.5});say(MSG.piece,A.warn,2.5)}
      else if(ev.type==='freed'){endT=S.t;TK.sfx('wreck1','free');TK.sfx('wreck1','win');path=[];say(MSG.free,A.good,99)}
      else if(ev.type==='fail'){endT=S.t;path=[];say(ev.why==='gas'?MSG.gas:MSG.fire,A.bad,99)}
    }
  }
  function finish(){
    if(doneFired)return;doneFired=true;
    const sc=scoreOf(S,P);
    ctx.done({score:sc,detail:S.freed?`Freed · ${S.hits} hit${S.hits===1?'':'s'}, ${S.scorch} burn${S.scorch===1?'':'s'}, ${Math.round(S.used/P.gas*100)}% gas`:(S.hits>=HITS_MAX?'Too many lines cut':'Ran out of gas')});
  }
  function inPolyPx(poly,x,y){return inPoly(poly,x*2+1,y*2+1)}
  function draw(){
    const t=S.t;
    g.drawImage(st,0,0);
    // space through the torn corner and any holes
    for(const sr of stars){const[x,y,b]=sr;if(!torn(x,y))continue;put(g,x,y,b>0.8?A.ice:b>0.5?M[6]:M[4])}
    const holes=S.pieces.map(p=>p.poly);if(S.freed&&S.poly)holes.push(S.poly);
    for(const poly of holes){let x0=1e9,y0=1e9,x1=-1,y1=-1;for(const p of poly){x0=Math.min(x0,p[0]);y0=Math.min(y0,p[1]);x1=Math.max(x1,p[0]);y1=Math.max(y1,p[1])}
      for(let y=Math.floor(y0/2);y<=Math.ceil(y1/2);y++)for(let x=Math.floor(x0/2);x<=Math.ceil(x1/2);x++){if(x<0||y<0||x>=PW||y>=PH)continue;if(inPolyPx(poly,x,y)){const sr=(x*7+y*13)%23===0;put(g,x,y,sr?M[5]:A.void)}}}
    // faint lines show near the torch
    if(sens<4&&S.torch){const tx=S.torch[0]/2,ty=S.torch[1]/2;const rad=26;
      g.save();g.beginPath();for(let y=-rad;y<=rad;y++){const w=Math.floor(Math.sqrt(rad*rad-y*y));g.rect(Math.floor(tx)-w,Math.floor(ty)+y,2*w+1,1)}g.clip();g.drawImage(faintCv,0,0);g.restore()}
    // live current running along power lines
    for(const o of LR){const L=o.L;if(L.kind!=='power'||(L.faint&&sens<4&&!(S.torch&&near(L,40))))continue;
      if(!live(L,t)){continue}
      for(const[k,v]of o.map){if(Math.abs(v.s)>0.5)continue;const ph=(v.u*1.6-t*9)%6;if(ph<0?ph>-1.2:ph<1.2){put(g,k%PW,(k/PW)|0,(ph+6)%6<0.6?A.hot:A.flare)}}
    }
    // the planned cut: a dashed loop round the crate (the clean route); where it has been cut the kerf replaces it
    if(!S.freed)P.loop.forEach((q,i)=>{if((i>>1)%2)return;const x=Math.round(q[0]/2),y=Math.round(q[1]/2);if(x<0||y<0||x>=PW||y>=PH)return;
      for(let j=-2;j<=2;j++)for(let k=-2;k<=2;k++){const nx=x+k,ny=y+j;if(nx>=0&&ny>=0&&nx<PW&&ny<PH&&cut[ny*PW+nx]>=0)return}
      put(g,x+1,y+1,M[0]);put(g,x,y,A.mark)});
    // until the first point is set, chevrons march along the loop from the torch, the way round to go
    if(!S.over&&S.pts.length<=1&&!path.length){
      const Lp=P.loop,N=Lp.length,s0=Lp[0],sx=Math.round(s0[0]/2),sy=Math.round(s0[1]/2);
      for(let c=0;c<3;c++){const i=(4+c*5+Math.floor(t*10)%5)%N,a=Lp[(i+N-1)%N],b=Lp[(i+1)%N],q=Lp[i];
        let dx=b[0]-a[0],dy=b[1]-a[1];const dl=Math.hypot(dx,dy)||1;dx/=dl;dy/=dl;const qx=q[0]/2,qy=q[1]/2;
        for(let w=0;w<=2;w++){put(g,Math.round(qx+dx*(1.5-w)+dy*w),Math.round(qy+dy*(1.5-w)-dx*w),A.hot);put(g,Math.round(qx+dx*(1.5-w)-dy*w),Math.round(qy+dy*(1.5-w)+dx*w),A.hot)}}
    }
    // kerf: a black slit with molten edges cooling hot -> ember -> dark
    for(const k of cutList){const x=k%PW,y=(k/PW)|0;const age=t-cut[k];
      for(const[dx,dy]of[[1,0],[-1,0],[0,1],[0,-1],[1,1],[-1,-1],[1,-1],[-1,1]]){const nx=x+dx,ny=y+dy;if(nx<0||ny<0||nx>=PW||ny>=PH)continue;const nk=ny*PW+nx;if(cut[nk]>=0)continue;
        const diag=dx&&dy;let c;
        if(age<0.4)c=diag?RP.heat[3]:RP.heat[4];else if(age<0.9)c=diag?RP.heat[2]:RP.heat[3];else if(age<1.6)c=diag?RP.heat[1]:RP.heat[2];else if(age<2.4)c=bt(nx,ny)<0.5?RP.heat[1]:RP.heat[0];else c=RP.heat[0];
        if(diag&&age>=1.6)continue;put(g,nx,ny,c)}}
    for(const k of cutList){const x=k%PW,y=(k/PW)|0;const age=t-cut[k];put(g,x,y,age<0.3?RP.heat[5]:A.void)}
    // burns on the crate
    for(const f of fx)if(f.k==='burn'){for(let j=-2;j<=2;j++)for(let i=-2;i<=2;i++){const d=i*i+j*j;if(d>5)continue;const x=Math.round(f.x)+i,y=Math.round(f.y)+j;if(d<=2||bt(x,y)<0.5)put(g,x,y,d<=1?A.void:M[0])}}
    // the freed piece floats out toward the ship (grows by whole pixels)
    if(S.freed&&S.poly){
      const k=clamp((t-endT)/1.4);const e=k*k*(3-2*k);const ox=Math.round(e*10),oy=Math.round(-e*14);
      let x0=1e9,y0=1e9,x1=-1,y1=-1;for(const p of S.poly){x0=Math.min(x0,p[0]);y0=Math.min(y0,p[1]);x1=Math.max(x1,p[0]);y1=Math.max(y1,p[1])}
      for(let y=Math.floor(y0/2);y<=Math.ceil(y1/2);y++)for(let x=Math.floor(x0/2);x<=Math.ceil(x1/2);x++){if(!inPolyPx(S.poly,x,y))continue;const o4=(y*PW+x)*4;const d=[SD[o4],SD[o4+1],SD[o4+2]];put(g,x+ox,y+oy,`rgb(${d[0]},${d[1]},${d[2]})`)}
      // a hot rim on the piece while it cools
      if(k<1)for(const p of S.poly)if(bt(Math.round(p[0]/2),Math.round(p[1]/2))<1-k)put(g,Math.round(p[0]/2)+ox,Math.round(p[1]/2)+oy,k<0.5?A.flare:A.ember);
      if(k>=1&&!timers.length)timers.push(setTimeout(finish,300));
    }
    // floating debris
    for(const d of debris){const x=Math.floor(d.x),y=Math.floor(d.y);const c=Math.sin(t*2+d.ph)>0.3?M[7]:d.c;put(g,x,y,c);if(d.sz>1){put(g,x+1,y,M[3]);put(g,x,y+1,M[2])}}
    // effects
    for(const f of fx){const k=f.age/f.life;
      if(f.k==='spark'){const x=Math.round(f.x),y=Math.round(f.y);if(x>=0&&y>=0&&x<PW&&y<PH){put(g,x,y,k<0.5?f.c:A.ember);if(k<0.3)put(g,Math.round(f.x-f.vx*0.03),Math.round(f.y-f.vy*0.03),A.ember)}}
      else if(f.k==='arc'){if(Math.floor(f.age*20)%2===0)for(let j=0;j<4;j++){let x=f.x,y=f.y;const a=(j/4)*6.283+f.age*3;for(let st2=0;st2<7;st2++){x+=Math.cos(a)*1.6+(Math.random()-.5)*2.4;y+=Math.sin(a)*1.6+(Math.random()-.5)*2.4;put(g,Math.round(x),Math.round(y),st2<2?A.ice:A.tractor)}}}
      else if(f.k==='puff'){const r=2+9*k,cy=f.y-4*k;for(let j=-Math.ceil(r);j<=r;j++)for(let i=-Math.ceil(r);i<=r;i++){const d=Math.hypot(i,j)/r;if(d>1)continue;const x=Math.round(f.x+i),y=Math.round(cy+j);const dens=(1-d)*(1-k)*1.6;if(bt(x,y)>dens)continue;
          put(g,x,y,k<0.25&&d<0.5?(d<0.25?A.hot:A.flare):k<0.45&&d<0.6?A.ember:RP.smoke[Math.min(3,Math.floor((1-d)*3))])}}
      else if(f.k==='flash'){const r=2+7*k;for(let a=0;a<24;a++){const x=Math.round(f.x+Math.cos(a/24*6.283)*r),y=Math.round(f.y+Math.sin(a/24*6.283)*r);if(x>=0&&y>=0&&x<PW&&y<PH&&bt(x,y)<1-k)put(g,x,y,k<0.4?'#fff4dc':A.bad)}if(k<0.3)for(let j=-1;j<=1;j++)for(let i=-1;i<=1;i++)put(g,Math.round(f.x)+i,Math.round(f.y)+j,'#fff4dc')}
      else if(f.k==='piece'){if(Math.floor(f.age*6)%2===0)for(const p of f.poly)put(g,Math.round(p[0]/2),Math.round(p[1]/2),A.warn)}
    }
    // the planned cut: a dotted line from the torch through each clicked point, each point a pin
    if(S.torch&&!S.over&&path.length){
      let ax=S.torch[0]/2,ay=S.torch[1]/2,n=0;
      path.forEach((q,qi)=>{const bx=q[0]/2,by=q[1]/2,len=Math.hypot(bx-ax,by-ay),m=Math.max(1,Math.round(len));
        for(let k=0;k<=m;k++){const x=Math.round(ax+(bx-ax)*k/m),y=Math.round(ay+(by-ay)*k/m);if(((n+k)>>1)%2===0&&Math.hypot(x-S.torch[0]/2,y-S.torch[1]/2)>3)put(g,x,y,qi===0?A.flare:A.ember)}
        n+=m;ax=bx;ay=by;
        const x=Math.round(bx),y=Math.round(by),lit=qi===0;
        for(const[i,j]of[[-2,0],[2,0],[0,-2],[0,2],[-1,-1],[1,-1],[-1,1],[1,1]])put(g,x+i,y+j,RP.heat[0]);
        for(const[i,j]of[[-1,0],[1,0],[0,-1],[0,1]])put(g,x+i,y+j,lit?A.flare:A.ember);put(g,x,y,lit?A.hot:A.flare)});
    }
    // the torch: a hose from the bottom-right corner to a handle, a brass ring and a nozzle aimed at the cut point.
    // Cutting: a flickering jet from the nozzle to the metal, a hot glow and sparks spraying away. Idle: a blue pilot light.
    if(!S.freed&&!(S.over&&t-endT>0.8))drawTorch(t);
    // camera framing: corner brackets, vignette, label
    for(let y=0;y<PH;y++)for(let x=0;x<PW;x++){const dx=Math.max(0,Math.abs(x-PW/2)-PW*0.38)/(PW*0.12),dy=Math.max(0,Math.abs(y-PH/2)-PH*0.36)/(PH*0.14);const v=Math.hypot(dx,dy);if(v>0&&bt(x,y)<v*0.45)put(g,x,y,A.bevelLo)}
    for(const[x,y,dx,dy]of[[1,1,1,1],[PW-2,1,-1,1],[1,PH-2,1,-1],[PW-2,PH-2,-1,-1]])for(let i=0;i<5;i++){put(g,x+dx*i,y,M[6]);put(g,x,y+dy*i,M[6])}
    g.fillStyle=A.bevelLo;g.fillRect(3,3,36,7);TK.text(g,'ARM CAM',4,4,M[6]);
    if(Math.floor(t*2)%2)put(g,33,5,A.bad);
    if(!S.over&&S.pts.length<=1&&!path.length)banner(g,A,PW,(P.R.y0+P.R.y1)/4<PH/2?PH-31:3,'CUT OUT THE CRATE',['click'],t);
    // HUD strip
    g.fillStyle=A.panel;g.fillRect(0,PH,PW,HUD);g.fillStyle=A.bevelHi;g.fillRect(0,PH,PW,1);g.fillStyle=A.bevelLo;g.fillRect(0,PH+1,PW,1);
    const Lh=HUDL,bw=Lh.barW;
    TK.text(g,'GAS',Lh.gasX,PH+6,A.chill);
    const gl=clamp(1-S.used/P.gas);
    g.fillStyle=A.bevelLo;g.fillRect(Lh.barX,PH+5,bw+2,7);g.fillStyle=A.line;g.fillRect(Lh.barX+1,PH+6,bw,5);
    const fillw=Math.round(bw*gl);const gc=gl<0.2?A.bad:A.flare;
    for(let i=0;i<fillw;i++){put(g,Lh.barX+1+i,PH+6,gl<0.2?'#e07a62':A.hot);for(let j=1;j<5;j++)put(g,Lh.barX+1+i,PH+6+j,j===4?(gl<0.2?'#7a2f24':A.ember):gc)}
    TK.text(g,'HITS',Lh.hitsX,PH+6,A.chill);
    for(let i=0;i<HITS_MAX;i++){const x=Lh.boxX+i*Lh.boxP,y=PH+6;const on=i<S.hits;g.fillStyle=A.bevelLo;g.fillRect(x,y,4,5);g.fillStyle=on?A.bad:A.line;g.fillRect(x+1,y+1,2,3);if(on)put(g,x+1,y+1,'#e07a62')}
    // the status owns the space right of the HITS boxes and nothing else
    if((statusT>0||S.over)&&status)TK.text(g,status.slice(0,Lh.maxChars),Lh.statusR,PH+6,statusCol,'right');
  }
  function drawTorch(t){
    const lit=!!S.torch,flame=flameOn();
    const hx=lit?S.torch[0]/2:PW-30,hy=lit?S.torch[1]/2:PH-38;          // the cut point (the torch starts on the loop, so it is always lit)
    // the body points away from the crate (leaning a little down-right), so it never lies over it; it turns smoothly as it goes round
    {let ox=hx-(P.R.x0+P.R.x1)/4,oy=hy-(P.R.y0+P.R.y1)/4;const ol=Math.hypot(ox,oy)||1;ox=ox/ol+0.25;oy=oy/ol+0.25;const ta=Math.atan2(oy,ox);
      if(torchA==null)torchA=ta;else{let d=ta-torchA;d=Math.atan2(Math.sin(d),Math.cos(d));torchA+=d*0.18}}
    let ux=Math.cos(torchA),uy=Math.sin(torchA);const ax=hx+ux*90,ay=hy+uy*90;   // the hose runs on out of frame the same way
    const sh=shakeT>0?(Math.floor(t*36)%2?1:-1):0;const ox=sh*-uy,oy=sh*ux;                     // a hit shakes the head sideways
    const tipD=flame?5:4;
    const pt=(d,o)=>[hx+ux*d-uy*o+ox,hy+uy*d+ux*o+oy];
    const dot=(x,y,c)=>{x=Math.round(x);y=Math.round(y);if(x>=0&&y>=0&&x<PW&&y<PH)put(g,x,y,c)};
    // hose: a sagging curve of dark rubber with a highlight, from the handle's end off the bottom-right edge
    const[h0x,h0y]=pt(tipD+16,0);const HO=['#2f4a3c','#4f7a62',A.good];   // a green gas hose, unlike any cable or pipe
    const mx=(h0x+ax)/2+6,my=Math.max(h0y,ay)+4;
    for(let k=0;k<=48;k++){const q=k/48,x=(1-q)*(1-q)*h0x+2*(1-q)*q*mx+q*q*ax,y=(1-q)*(1-q)*h0y+2*(1-q)*q*my+q*q*ay;
      dot(x-1,y+1,M[0]);dot(x+1,y+2,M[0]);dot(x,y+1,HO[0]);dot(x+1,y+1,HO[0]);dot(x,y,HO[1]);dot(x+1,y,HO[1]);dot(x,y-1,HO[2])}
    // handle: 3 px of shaded metal inside a dark outline, the lit side toward the top-left
    const litSide=(-uy-ux)<0?1:-1;
    for(let d=tipD+6;d<=tipD+16;d+=0.5)for(let o=-2;o<=2;o++){const[x,y]=pt(d,o);dot(x,y,M[0])}
    for(let d=tipD+6.5;d<=tipD+15.5;d+=0.5)for(let o=-1;o<=1;o++){const[x,y]=pt(d,o);dot(x,y,o===0?M[6]:o===litSide?M[7]:M[4])}
    for(const d of[tipD+9,tipD+12])for(let o=-1;o<=1;o++){const[x,y]=pt(d,o);dot(x,y,M[3])}   // grip bands
    // brass ring, and a red gas valve knob on the handle
    for(const d of[tipD+4.5,tipD+5.5])for(let o=-2;o<=2;o++){const[x,y]=pt(d,o);dot(x,y,o===-2||o===2?M[0]:o===litSide?'#e0bd6a':A.warn)}
    {const[x,y]=pt(tipD+11,-litSide*3);dot(x,y,A.bad);const[x2,y2]=pt(tipD+11.5,-litSide*3);dot(x2,y2,'#7a2f24')}
    // nozzle: a thin pipe from the ring to the tip
    for(let d=tipD;d<=tipD+4.5;d+=0.5){const[x,y]=pt(d,0);dot(x,y,d<tipD+1?A.ice:M[7]);const[x2,y2]=pt(d,-litSide);dot(x2,y2,M[0])}
    if(!flame){
      // pilot light: a small blue flame at the tip, flickering, short of the metal
      const f=Math.floor(t*14)%3;const[x1,y1]=pt(tipD-1,0),[x2,y2]=pt(tipD-2,0);dot(x1,y1,A.tractor);if(f)dot(x2,y2,f===1?A.ice:A.cold);
      if(lit){dot(hx,hy,A.ember)}
      return}
    // the jet: nozzle tip to metal, a white core with flare edges; its reach flickers a pixel
    const L=tipD+(Math.floor(t*30)%2?0:1);
    for(let d=0;d<=L;d+=0.5){const[x,y]=pt(d,0);dot(x,y,d<1.5?'#fff4dc':A.hot);if(d<3.5){const[a1,b1]=pt(d,1),[a2,b2]=pt(d,-1);dot(a1,b1,A.flare);dot(a2,b2,A.flare)}}
    // the bite: a hot glow on the plate (red when a live line is close, with sensors), then sparks sprayed away from the torch
    const warn=sens>=2&&S.near<6;const rad=6;
    for(let j=-rad;j<=rad;j++)for(let i=-rad;i<=rad;i++){const d=Math.hypot(i,j);if(d>rad||d<1.5)continue;const x=Math.round(hx)+i,y=Math.round(hy)+j;const v=1-d/rad;if(bt(x,y)>v*0.7)continue;dot(x,y,warn?(v>0.5?A.bad:'#5a2018'):(v>0.55?A.flare:v>0.3?A.ember:RP.heat[1]))}
    dot(hx,hy,'#fff4dc');dot(hx-1,hy,A.hot);dot(hx+1,hy,A.hot);dot(hx,hy-1,A.hot);dot(hx,hy+1,A.hot);
    if(Math.random()<0.9)for(let i=0;i<2;i++){const a=Math.atan2(-uy,-ux)+(Math.random()-.5)*2.2,v=14+Math.random()*24;fx.push({k:'spark',x:hx,y:hy,vx:Math.cos(a)*v,vy:Math.sin(a)*v,age:0,life:0.2+Math.random()*0.35,c:Math.random()<0.5?A.hot:'#fff4dc'})}
  }
  function seg(c,x0,y0,x1,y1,w){const n=Math.ceil(Math.hypot(x1-x0,y1-y0));for(let k=0;k<=n;k++){const x=Math.round(x0+(x1-x0)*k/n),y=Math.round(y0+(y1-y0)*k/n);for(let j=-1;j<=w;j++)for(let i=-1;i<=w;i++){const edge=i<0||j<0||i>=w||j>=w;if(edge){continue}put(c,x+i-1,y+j-1,j===0?M[6]:i===w-1||j===w-1?M[2]:M[4])}}
    for(let k=0;k<=n;k+=1){const x=Math.round(x0+(x1-x0)*k/n),y=Math.round(y0+(y1-y0)*k/n);put(c,x-2,y-1,M[0]);put(c,x+w-1,y+w,M[0])}}
  function near(L,r){if(!S.torch)return false;for(const p of L.pts)if(Math.hypot(p[0]-S.torch[0],p[1]-S.torch[1])<r*2)return true;return false}
  function tick(dt){{const on=flameOn();if(on!==!!window.__w1T){window.__w1T=on;TK.sfx('wreck1','torch',on?1:0)}}
    const n0=S.pts.length;
    const tg=path[0];
    if(!S.over&&S.torch){step(S,P,tg?tg[0]:S.torch[0],tg?tg[1]:S.torch[1],dt);
      if(tg&&!(down&&drag)&&Math.hypot(tg[0]-S.torch[0],tg[1]-S.torch[1])<0.6)path.shift()}
    else S.t+=dt;
    for(let i=Math.max(0,n0-1);i<S.pts.length;i++){const p=S.pts[i];const x=Math.floor(p[0]/2),y=Math.floor(p[1]/2);const k=y*PW+x;if(x>=0&&y>=0&&x<PW&&y<PH&&cut[k]<0){cut[k]=S.t;cutList.push(k)}}
    events();
    statusT-=dt;shakeT=Math.max(0,shakeT-dt);
    for(let i=fx.length-1;i>=0;i--){const f=fx[i];f.age+=dt;if(f.age>f.life){fx.splice(i,1);continue}if(f.k==='spark'){f.x+=f.vx*dt;f.y+=f.vy*dt;f.vx*=0.97;f.vy*=0.97}}
    for(const d of debris){d.x=(d.x+d.vx*dt+PW)%PW;d.y=(d.y+d.vy*dt+PH)%PH}
    if(S.over&&!S.freed&&S.t-endT>1.6&&!timers.length)timers.push(setTimeout(finish,100));
  }
  function frame(now){
    const dt=last?Math.min(0.05,(now-last)/1000):0;last=now;
    tick(dt);acc+=dt;
    if(acc>=1/30){acc=0;draw()}
    raf=requestAnimationFrame(frame);
  }
  draw();raf=requestAnimationFrame(frame);
  return{
    destroy(){cancelAnimationFrame(raf);timers.forEach(clearTimeout);S.over=true;doneFired=true;px.destroy()},
    giveUp(){if(doneFired)return;S.over=true;doneFired=true;cancelAnimationFrame(raf);ctx.done({score:0,detail:'Gave up'})},
    _sim:S,_P:P,_path:()=>path,
  };
}

TK.register({
  id:ID,name:'Cutting Torch',hint:'Cut out the crate.',controls:['click'],where:'Wrecks',skill:'Steady hand',
  blurb:'Cut a sample crate out of a wreck without hitting live lines.',
  how:[
    'The torch starts on the dashed line. Tap points round the crate and it cuts to each in turn.',
    'Close the loop all the way round.',
    'Miss the glowing cables and the red fuel pipes. Don’t burn the crate.',
    'Gas is short, so cut close.',
  ],
  deeper:'Sector 2+: fuel pipes, and the lines sit closer. Sector 4+: some lines are faint until the torch is near. Sector 5: the crate has its own power cable. Cut it while it’s dark.',
  sensors:'Each point: more gas. 2+: the flame turns red near a live line. 4+: faint lines show clearly.',
  mount,
  _t:{gen,newSim,pierce,step,scoreOf,bot,loopPath,live,CFG,W,H,MSG,HUDL,
    check(rng,depth,sens){const P=gen(depth,sens,rng);const r=bot(P);return{ok:r.S.freed&&r.S.hits===0&&r.S.scorch===0,score:r.score,x:r.S.t,info:{hits:r.S.hits,sc:r.S.scorch,used:+(r.S.used/P.gas).toFixed(2),freed:r.S.freed}}}},
});
})();
