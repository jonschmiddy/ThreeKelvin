// Sample Tray v2: drag canisters so the sample canister reaches the exit.
(function(){
'use strict';
const ID='tray2';
const S=6,ROW=2,GOAL=4; // 6x6 tray, exit on the right of row 2
const CFG={
  1:{lo:6,hi:10,nb:[8,9],lock:0},
  2:{lo:8,hi:13,nb:[9,10],lock:0},
  3:{lo:10,hi:16,nb:[10,11],lock:0},
  4:{lo:9,hi:15,nb:[10,11],lock:3},
  5:{lo:12,hi:20,nb:[11,12],lock:4},
};
const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));
function occ(B,pos){const g=new Int8Array(S*S).fill(-1);B.forEach((b,i)=>{for(let k=0;k<b.len;k++){const c=b.h?b.fix*S+pos[i]+k:(pos[i]+k)*S+b.fix;g[c]=i}});return g}
const cellOf=(b,p,k)=>b.h?b.fix*S+p+k:(p+k)*S+b.fix;
// all single slides: [block, newPos]
function moves(B,pos,locked){
  const g=occ(B,pos),out=[];
  B.forEach((b,i)=>{
    if(i===locked)return;
    for(let p=pos[i]-1;p>=0&&g[cellOf(b,p,0)]<0;p--)out.push([i,p]);
    for(let p=pos[i]+1;p+b.len<=S&&g[cellOf(b,p,b.len-1)]<0;p++)out.push([i,p]);
  });
  return out;
}
function layout(c,rng){
  const B=[{h:true,len:2,fix:ROW}],pos=[Math.floor(rng()*3)];
  const want=c.nb[0]+Math.floor(rng()*(c.nb[1]-c.nb[0]+1));
  for(let t=0;t<300&&B.length<want;t++){
    const h=rng()<0.5,len=rng()<0.72?2:3,fix=Math.floor(rng()*S),p=Math.floor(rng()*(S-len+1));
    if(h&&fix===ROW)continue;
    const b={h,len,fix};const g=occ(B,pos);let ok=true;
    for(let k=0;k<len;k++)if(g[cellOf(b,p,k)]>=0)ok=false;
    if(ok){B.push(b);pos.push(p)}
  }
  return{B,pos};
}
// distance-to-goal for every state in the start's component (moves are reversible)
function weights(n){const W=[];let w=1;for(let i=0;i<n;i++){W.push(w);w*=S}return W}
function fillOcc(B,p,g){g.fill(-1);for(let i=0;i<B.length;i++){const b=B[i];for(let k=0;k<b.len;k++)g[b.h?b.fix*S+p[i]+k:(p[i]+k)*S+b.fix]=i}}
function component(B,pos0,cap){
  const nb=B.length,W=weights(nb),enc=p=>{let k=0;for(let i=0;i<nb;i++)k+=p[i]*W[i];return k};
  const keys=new Map(),states=[pos0.slice()];keys.set(enc(pos0),0);
  const edges=[],st=[],en=[];const g=new Int8Array(S*S);
  for(let i=0;i<states.length;i++){
    const s=states[i];fillOcc(B,s,g);const k0=enc(s);st.push(edges.length);
    for(let b=0;b<nb;b++){
      const bk=B[b];
      for(let dir=-1;dir<=1;dir+=2)for(let p=s[b]+dir;p>=0&&p+bk.len<=S;p+=dir){
        if(g[cellOf(bk,p,dir<0?0:bk.len-1)]>=0)break;
        const k=k0+(p-s[b])*W[b];let j=keys.get(k);
        if(j===undefined){if(states.length>=cap)return null;j=states.length;keys.set(k,j);const n=s.slice();n[b]=p;states.push(n)}
        edges.push(j);
      }
    }
    en.push(edges.length);
  }
  const dist=new Int32Array(states.length).fill(-1);const q=[];
  states.forEach((s,i)=>{if(s[0]===GOAL){dist[i]=0;q.push(i)}});
  for(let h=0;h<q.length;h++){const i=q[h];for(let e=st[i];e<en[i];e++){const j=edges[e];if(dist[j]<0){dist[j]=dist[i]+1;q.push(j)}}}
  return{states,dist};
}
// forward BFS with a lock: block lk cannot move until N moves are made; a move = slide of a block different from the last one
function solve(B,pos,lk,N,cap){
  if(pos[0]===GOAL)return{dist:0,path:[]};
  const nb=B.length,W=weights(nb),enc=p=>{let k=0;for(let i=0;i<nb;i++)k+=p[i]*W[i];return k};
  const tag=(k,last)=>k<N?k*16+last+1:255;
  const start={p:pos.slice(),k:0,last:-1,prev:null,mv:null};
  const seen=new Set([enc(pos)*256+tag(0,-1)]);let fr=[start],d=0;const g=new Int8Array(S*S);
  while(fr.length){
    const nx=[];d++;
    for(const s of fr){
      fillOcc(B,s.p,g);const k0=enc(s.p);const locked=s.k<N?lk:-1;
      for(let b=0;b<nb;b++){
        if(b===locked||b===s.last)continue; // sliding the same block again is the same move
        const bk=B[b];
        for(let dir=-1;dir<=1;dir+=2)for(let p=s.p[b]+dir;p>=0&&p+bk.len<=S;p+=dir){
          if(g[cellOf(bk,p,dir<0?0:bk.len-1)]>=0)break;
          const nk=Math.min(N,s.k+1);
          if(b===0&&p===GOAL){const path=[[b,p]];for(let t=s;t.mv;t=t.prev)path.unshift(t.mv);return{dist:d,path}}
          const key=(k0+(p-s.p[b])*W[b])*256+tag(nk,b);
          if(seen.has(key))continue;seen.add(key);
          const n={p:s.p.slice(),k:nk,last:b,prev:s,mv:[b,p]};n.p[b]=p;nx.push(n);
          if(seen.size>(cap||300000))return null;
        }
      }
    }
    fr=nx;
  }
  return null;
}
function gen(depth,rng){
  const c=CFG[depth];
  for(let att=0;att<400;att++){
    const{B,pos}=layout(c,rng);
    const comp=component(B,pos,15000);if(!comp)continue;
    let bestD=-1;comp.dist.forEach(d=>{if(d<=c.hi&&d>bestD)bestD=d});
    if(bestD<c.lo)continue;
    const cand=[];comp.dist.forEach((d,i)=>{if(d===bestD)cand.push(i)});
    const start=comp.states[cand[Math.floor(rng()*cand.length)]];
    let par=bestD,lock=-1;
    if(c.lock){
      let best=null;
      for(const b of TKshuffle(B.map((_,i)=>i).slice(1),rng)){
        const r=solve(B,start,b,c.lock);
        if(r&&r.dist>par&&r.dist<=c.hi+3&&(!best||r.dist>best.dist))best={b,dist:r.dist};
      }
      if(!best)continue;
      lock=best.b;par=best.dist;
    }
    const sol=solve(B,start,lock,lock<0?0:c.lock);
    if(!sol||sol.dist!==par)continue;
    return{B,pos:start,par,lock,N:lock<0?0:c.lock,first:sol.path[0],path:sol.path};
  }
  throw new Error('tray2: no puzzle');
}
function TKshuffle(a,r){a=a.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(r()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a}
function scoreOf(moves,par){return clamp(0.15+0.85*Math.pow(Math.min(1,par/Math.max(1,moves)),1.3))}

const logic={gen,solve,moves,scoreOf,CFG,GOAL,S,ROW};
if(typeof TK==='undefined'){if(typeof module!=='undefined')module.exports=logic;return}

// ---------- pixel view: the sample-bay camera ----------
const PAL=TK.PAL;
function hex(c){return[parseInt(c.slice(1,3),16),parseInt(c.slice(3,5),16),parseInt(c.slice(5,7),16)]}
function shade(c,f){const[r,g,b]=hex(c),m=v=>Math.max(0,Math.min(255,Math.round(f<0?v*(1+f):v+(255-v)*f)));return'#'+[m(r),m(g),m(b)].map(v=>v.toString(16).padStart(2,'0')).join('')}
const BAY=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5];
const bay=(x,y)=>(BAY[(y&3)*4+(x&3)]+.5)/16;
function dot(g,x,y,c){g.fillStyle=c;g.fillRect(Math.round(x),Math.round(y),1,1)}
const CONTROLS=['drag'];
const ICW={click:13,hold:21,drag:22,'drag-h':22,'drag-v':22,dial:13};
function startCard(g,hint,ctl,cx,y,t,bg,edge){const tw=hint.length*4-1,iw=ctl.reduce((a,k)=>a+ICW[k]+4,-4),w=Math.max(tw,iw)+10,h=26,x=Math.round(cx-w/2);
  g.fillStyle=edge;g.fillRect(x-1,y-1,w+2,h+2);g.fillStyle=bg;g.fillRect(x,y,w,h);TK.text(g,hint,cx,y+3,TK.PAL.hot,'center');
  let ix=Math.round(cx-iw/2);for(const k of ctl){TK.icon(g,k,ix,y+11,{t});ix+=ICW[k]+4}}

const W=144,H=108,C=15,GX=8,GY=9;      // 6x6 cells of 15 art px
const EXY=GY+ROW*C;                     // exit row top
const RX=104;                           // right column
const UB={x:RX,y:88,w:37,h:12};         // UNDO button
// metal ramp across a canister, top-left light
const STEEL=[PAL.ice,PAL.chill,PAL.chill,PAL.cold,PAL.cold,PAL.cold,PAL.line,PAL.line,PAL.bevelLo];
function canister(g,x,y,len,h,kind,sel){
  // x,y: top-left of the cell span; len in cells; h: horizontal
  const L=len*C-2,T=C-2,w=h?L:T,ht=h?T:L,X=Math.round(x)+1,Y=Math.round(y)+1;
  for(let j=0;j<ht;j++)for(let i=0;i<w;i++){
    const edge=(i===0||j===0||i===w-1||j===ht-1),corner=(i===0||i===w-1)&&(j===0||j===ht-1);if(corner)continue;
    const a=h?j:i,along=h?i:j,alen=h?w:ht; // a: across 0..12, along the length
    let col;
    if(edge)col=PAL.bevelLo;
    else if(kind==='sample'){
      const cap=along<4||along>alen-5;
      if(cap)col=a<3?PAL.hot:a<8?PAL.flare:a<11?PAL.ember:shade(PAL.ember,-.4);
      else{ // glass tube with glowing sample
        if(a===1||a===11)col=shade(PAL.tractor,-.5);
        else if(a===2)col=PAL.ice;
        else{const f=Math.abs(a-6.5)/4.5;col=f<.35?PAL.mark:f<.75?PAL.tractor:shade(PAL.tractor,-.35);
          if(((along*7+a*3)%23===0))col=PAL.mark;}
      }
    }else{
      col=STEEL[Math.min(8,Math.floor(a*9/T))];
      const cap=along<3||along>alen-4;
      if(cap)col=shade(col,-.35);
      if(along===3||along===alen-4)col=PAL.bevelLo;
      if((along===1||along===alen-2)&&a===6)col=PAL.chill; // rivet
      if(kind==='bolt'&&a>4&&a<8&&along%6===0&&along>3&&along<alen-4)col=PAL.warn; // hazard band
    }
    g.fillStyle=col;g.fillRect(X+i,Y+j,1,1);
  }
  if(sel){g.fillStyle=PAL.ember;g.fillRect(X-1,Y-2,w+2,1);g.fillRect(X-1,Y+ht+1,w+2,1);g.fillRect(X-2,Y-1,1,ht+2);g.fillRect(X+w+1,Y-1,1,ht+2)}
  return[X,Y,w,ht];
}

function mount(stage,ctx){
  const P=gen(ctx.depth,ctx.rng);const B=P.B;
  let pos=P.pos.slice(),moves_=0,last=-1,sel=-1,over=false,undos=2+ctx.sensors,started=false,clock=0,raf=0,lastT=0,outT=-1;
  const vis=pos.map(v=>v);                 // drawn position, eases toward pos
  const hist=[];
  const showHint=ctx.sensors>=2;
  const p=TK.pixel(stage,{w:W,h:H});const g=p.g;
  const lockOn=()=>P.lock>=0&&moves_<P.N;

  // static plate: tray, floor, exit chute, right column
  const plate=document.createElement('canvas');plate.width=W;plate.height=H;const b=plate.getContext('2d');
  b.fillStyle=PAL.panel;b.fillRect(0,0,W,H);
  // tray rim, bevelled
  b.fillStyle=PAL.bevelHi;b.fillRect(GX-4,GY-4,S*C+8,2);b.fillRect(GX-4,GY-4,2,S*C+8);
  b.fillStyle=PAL.bevelLo;b.fillRect(GX-4,GY+S*C+2,S*C+8,2);b.fillRect(GX+S*C+2,GY-4,2,S*C+8);
  b.fillStyle=PAL.line;b.fillRect(GX-2,GY-2,S*C+4,S*C+4);
  // floor plate with machined grooves and holes
  for(let y=0;y<S*C;y++)for(let x=0;x<S*C;x++){const X=GX+x,Y=GY+y,cx=x%C,cy=y%C;
    let col=bay(X,Y)<.18?PAL.panel:PAL.void;
    if(cx===0||cy===0)col=PAL.bevelLo;else if(cx===1||cy===1)col=PAL.line;
    if(cx>=6&&cx<=8&&cy>=6&&cy<=8)col=(cx===7&&cy===7)?PAL.bevelLo:shade(PAL.panel,.1);
    b.fillStyle=col;b.fillRect(X,Y,1,1)}
  // exit gap in the right rim, chute and receiver port
  b.fillStyle=PAL.void;b.fillRect(GX+S*C-1,EXY+1,6,C-2);
  for(let x=GX+S*C+5;x<W-1;x++){b.fillStyle=PAL.bevelLo;b.fillRect(x,EXY-1,1,1);b.fillRect(x,EXY+C-1,1,1);
    b.fillStyle=PAL.bevelHi;b.fillRect(x,EXY,1,1);for(let y=EXY+1;y<EXY+C-1;y++){b.fillStyle=(y-EXY)%4===2?PAL.line:PAL.void;b.fillRect(x,y,1,1)}}
  // HUD labels
  TK.text(b,'MOVES',RX,GY,PAL.cold);TK.text(b,'PAR',RX,GY+20,PAL.cold);
  TK.text(b,'BAY',RX,EXY+C+3,PAL.cold);

  const cellXY=(i,v)=>{const bk=B[i];return[GX+(bk.h?v:bk.fix)*C,GY+(bk.h?bk.fix:v)*C]};
  function range(i){
    if(i===P.lock&&lockOn())return[pos[i],pos[i]];
    const bk=B[i],gr=occ(B,pos);let lo=pos[i],hi=pos[i];
    while(lo-1>=0&&gr[cellOf(bk,lo-1,0)]<0)lo--;
    while(hi+1+bk.len<=S&&gr[cellOf(bk,hi+1,bk.len-1)]<0)hi++;
    return[lo,hi];
  }
  function draw(){
    g.drawImage(plate,0,0);
    // the dashed first-move hint
    if(showHint&&moves_===0&&!over&&P.first){const[bi,pp]=P.first,bk=B[bi];const[x,y]=cellXY(bi,pp);const w=bk.h?bk.len*C:C,h=bk.h?C:bk.len*C;
      for(let k=0;k<w;k+=2){dot(g,x+k,y,PAL.hot);dot(g,x+k,y+h-1,PAL.hot)}for(let k=0;k<h;k+=2){dot(g,x,y+k,PAL.hot);dot(g,x+w-1,y+k,PAL.hot)}}
    // shadows then canisters
    B.forEach((bk,i)=>{const[x,y]=cellXY(i,vis[i]);const w=bk.h?bk.len*C-2:C-2,h=bk.h?C-2:bk.len*C-2;
      for(let j=0;j<h;j++)for(let k=0;k<w;k++)if(bay(x+k,y+j)<.5){g.fillStyle=PAL.bevelLo;g.fillRect(Math.round(x)+2+k,Math.round(y)+2+j,1,1)}});
    B.forEach((bk,i)=>{
      if(i===0&&outT>=0)return;
      const[x,y]=cellXY(i,vis[i]);
      const[X,Y,w,h]=canister(g,x,y,bk.len,bk.h,i===0?'sample':i===P.lock?'bolt':'steel',i===sel&&!over);
      if(i===P.lock&&lockOn()){const cx=X+(w>>1),cy=Y+(h>>1);
        g.fillStyle=PAL.bevelLo;g.fillRect(cx-4,cy-4,9,9);g.fillStyle=PAL.chill;g.fillRect(cx-3,cy-3,7,7);g.fillStyle=PAL.cold;g.fillRect(cx-3,cy+2,7,1);g.fillRect(cx+2,cy-3,1,7);
        TK.text(g,String(P.N-moves_),cx-1,cy-2,PAL.void)}
    });
    // fallback arrows on the selected canister
    if(sel>=0&&!over&&!drag){const[lo,hi]=range(sel),bk=B[sel];
      if(lo<pos[sel])arrow(sel,pos[sel]-1,-1);if(hi>pos[sel])arrow(sel,pos[sel]+bk.len,1)}
    // the sample leaving the tray
    if(outT>=0){
      const t=Math.min(1,(clock-outT)/1.1),e=t*t;
      const x=GX+GOAL*C+e*(W-(GX+GOAL*C)+4),y=GY+ROW*C;
      g.save();g.beginPath();g.rect(0,0,W-2,H);g.clip();canister(g,x,y,2,true,'sample',false);g.restore();
      // port hatch lip over the end
      g.fillStyle=PAL.bevelHi;g.fillRect(W-3,EXY-2,1,C+3);g.fillStyle=PAL.bevelLo;g.fillRect(W-2,EXY-2,2,C+3);
    }
    // HUD
    big(String(moves_),RX,GY+7,PAL.hot);TK.text(g,String(P.par),RX+14,GY+20,PAL.chill);
    // bay lamp
    const ok=outT>=0&&clock-outT>1;const lx=RX+16,ly=EXY+C+5;
    g.fillStyle=PAL.bevelLo;g.fillRect(lx-1,ly-1,7,7);g.fillStyle=ok?PAL.good:PAL.line;g.fillRect(lx,ly,5,5);if(ok){dot(g,lx+1,ly+1,PAL.mark);
      for(let y=-4;y<=8;y++)for(let x=-4;x<=8;x++){const r=Math.hypot(x-2,y-2);if(r>3.6&&r<6&&bay(lx+x,ly+y)<(6-r)/4)dot(g,lx+x,ly+y,shade(PAL.good,-.3))}}
    if(ok)TK.text(g,'OUT',RX,ly+9,PAL.good);
    // UNDO button
    const can=undos>0&&hist.length&&!over,pr=undoDown!==false;
    g.fillStyle=PAL.bevelLo;g.fillRect(UB.x,UB.y,UB.w,UB.h);g.fillStyle=can?PAL.bevelHi:PAL.line;g.fillRect(UB.x+1,UB.y+1+(pr?1:0),UB.w-2,UB.h-2-(pr?1:0));
    g.fillStyle=can?PAL.chill:PAL.bevelHi;g.fillRect(UB.x+1,UB.y+1+(pr?1:0),UB.w-2,1);if(!can){g.fillStyle=PAL.line;g.fillRect(UB.x+1,UB.y+1,UB.w-2,1)}
    TK.text(g,'UNDO '+undos,UB.x+(UB.w>>1),UB.y+4+(pr?1:0),can?PAL.ice:PAL.cold,'center');
    if(!started)startCard(g,'GET THE SAMPLE OUT',CONTROLS,GX+S*C/2,GY+S*C/2-13,clock,PAL.panel,PAL.bevelHi);
  }
  function arrow(i,cell,dir){const bk=B[i];const[x,y]=bk.h?[GX+cell*C,GY+bk.fix*C]:[GX+bk.fix*C,GY+cell*C];const cx=x+7,cy=y+7;
    g.fillStyle=PAL.ember;
    for(let k=0;k<4;k++){if(bk.h){g.fillRect(cx+(dir>0?k-2:2-k),cy-3+k,1,7-2*k)}else{g.fillRect(cx-3+k,cy+(dir>0?k-2:2-k),7-2*k,1)}}}
  const tmp=document.createElement('canvas');tmp.width=24;tmp.height=5;const tg=tmp.getContext('2d');
  function big(s,x,y,col){tg.clearRect(0,0,24,5);const w=TK.text(tg,s,0,0,col);g.drawImage(tmp,0,0,w,5,x,y,w*2,10)}

  function frame(now){raf=requestAnimationFrame(frame);if(now-lastT<32)return;const dt=Math.min(.1,(now-lastT)/1000);lastT=now;clock+=dt;
    B.forEach((_,i)=>{if(drag&&drag.i===i&&drag.moved)return;const d=pos[i]-vis[i];vis[i]=Math.abs(d)<.02?pos[i]:vis[i]+d*Math.min(1,dt*18)});
    if(wob){wob.t+=dt;if(wob.t>.3){vis[wob.i]=pos[wob.i];wob=null}else vis[wob.i]=pos[wob.i]+Math.sin(wob.t*60)*.06*(1-wob.t/.3)}
    draw()}

  // ---- input: drag a canister along its length; tap to select, tap an arrow to nudge ----
  const ptf=e=>{const r=p.cv.getBoundingClientRect();return{x:(e.clientX-r.left)*W/r.width,y:(e.clientY-r.top)*H/r.height}};
  const hitBlock=q=>{for(let i=0;i<B.length;i++){const bk=B[i],[x,y]=cellXY(i,pos[i]),w=bk.h?bk.len*C:C,h=bk.h?C:bk.len*C;if(q.x>=x&&q.x<x+w&&q.y>=y&&q.y<y+h)return i}return -1};
  const cellAt=q=>{const cx=Math.floor((q.x-GX)/C),cy=Math.floor((q.y-GY)/C);return cx>=0&&cy>=0&&cx<S&&cy<S?[cx,cy]:null};
  let drag=null,wob=null,undoDown=false;
  const inUndo=q=>q.x>=UB.x-2&&q.x<=UB.x+UB.w+2&&q.y>=UB.y-2&&q.y<=UB.y+UB.h+2;
  p.cv.addEventListener('pointerdown',e=>{
    if(over)return;const q=ptf(e);started=true;e.preventDefault();try{p.cv.setPointerCapture(e.pointerId)}catch(_){}
    if(inUndo(q)){undoDown=e.pointerId;return}
    const i=hitBlock(q);
    if(i>=0){const bk=B[i];drag={id:e.pointerId,i,a0:bk.h?q.x:q.y,v0:pos[i],moved:false,rng:range(i)};
      if(drag.rng[0]===drag.rng[1]&&i===P.lock&&lockOn())wob={i,t:0};return}
    // arrow cells next to the selected canister
    const c=cellAt(q);if(sel>=0&&c){const bk=B[sel],[lo,hi]=range(sel),along=bk.h?c[0]:c[1],across=bk.h?c[1]:c[0];
      if(across===bk.fix){if(along===pos[sel]-1&&lo<pos[sel]){commit(sel,pos[sel]-1);return}if(along===pos[sel]+bk.len&&hi>pos[sel]){commit(sel,pos[sel]+1);return}}}
    sel=-1;
  });
  p.cv.addEventListener('pointermove',e=>{
    const q=ptf(e);
    if(!drag||e.pointerId!==drag.id){if(!over){const i=hitBlock(q);p.cv.style.cursor=i>=0?'grab':inUndo(q)?'pointer':'default'}return}
    e.preventDefault();const bk=B[drag.i];const d=((bk.h?q.x:q.y)-drag.a0)/C;
    if(!drag.moved&&Math.abs(d)*C>2.5)drag.moved=true;
    if(drag.moved){let v=drag.v0+d;const[lo,hi]=drag.rng;
      let top=hi;if(drag.i===0&&hi===GOAL)top=GOAL+.35; // the sample tugs toward the gap
      v=Math.max(lo-.12,Math.min(top+.12,v));if(v<lo)v=lo-(lo-v)*.4;if(v>top)v=top+(v-top)*.4;vis[drag.i]=v}
  });
  const up=e=>{
    if(undoDown!==false&&e.pointerId===undoDown){undoDown=false;if(e.type==='pointerup'&&inUndo(ptf(e)))undo();return}
    if(!drag||e.pointerId!==drag.id)return;const d=drag;drag=null;
    if(!d.moved){sel=(sel===d.i)?-1:d.i;return}
    const[lo,hi]=d.rng;const n=Math.max(lo,Math.min(hi,Math.round(vis[d.i])));
    if(n!==pos[d.i])commit(d.i,n);else sel=d.i;
  };
  p.cv.addEventListener('pointerup',up);p.cv.addEventListener('pointercancel',up);

  function commit(i,np){
    hist.push({pos:pos.slice(),moves:moves_,last});
    pos[i]=np;if(i!==last){moves_++;last=i}TK.sfx('tray2','slide');
    if(pos[0]===GOAL){
      over=true;sel=-1;vis[0]=GOAL;outT=clock+.05;TK.sfx('tray2','out');TK.sfx('tray2','win');
      ctx.done({score:scoreOf(moves_,P.par),detail:`Out in ${moves_} moves (par ${P.par})`});return}
    sel=i;
  }
  function undo(){if(over||undos<=0||!hist.length)return;const h=hist.pop();pos=h.pos;moves_=h.moves;last=h.last;undos--;sel=-1}
  draw();raf=requestAnimationFrame(frame);
  return{
    destroy(){over=true;cancelAnimationFrame(raf);p.destroy()},
    giveUp(){if(over)return;over=true;ctx.done({score:0,detail:'Gave up'})},
    _test:{get pos(){return pos.slice()},get moves(){return moves_},get sel(){return sel},get over(){return over},cv:p.cv,P,C,GX,GY,UB},
  };
}

TK.register({
  id:ID,name:'Sample Tray 2',hint:'Get the sample out.',controls:CONTROLS,where:'Stations, labs on wrecks',skill:'Planning',
  blurb:'Slide canisters aside to get the sample out of the tray.',
  how:[
    'Canisters only move along their length.',
    'The glowing sample leaves by the gap on the right.',
    'Match PAR to score full. One canister moved twice in a row counts once.',
  ],
  deeper:'Longer solutions. Sector 4+: one canister is bolted down until you make a few moves.',
  sensors:'Each point: one more undo. 2+: a dashed outline shows the first move.',
  mount,
  _t:logic,
});
})();
