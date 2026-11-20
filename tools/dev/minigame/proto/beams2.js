// Beam Bench: a laser on an optical table. Tap a mirror to turn it. Light every sensor.
(function(){
'use strict';
const ID='beams2';
const DX=[0,1,0,-1],DY=[-1,0,1,0]; // 0 N, 1 E, 2 S, 3 W
const SL=[1,0,3,2],BS=[3,2,1,0];   // '/' and '\' reflections
const CFG={
  1:{n:5,pm:3,dec:1,rocks:0,glass:0,sens:2,minPar:2,t1:25},
  2:{n:6,pm:4,dec:1,rocks:2,glass:0,sens:2,minPar:2,t1:35},
  3:{n:6,pm:4,dec:2,rocks:2,glass:1,sens:3,minPar:3,t1:45},
  4:{n:7,pm:5,dec:2,rocks:3,glass:1,sens:3,minPar:3,t1:55},
  5:{n:7,pm:5,dec:3,rocks:3,glass:2,sens:3,minPar:3,t1:65},
};
const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));

// ---------- logic ----------
// One beam. Sensors and glass let it through; glass tints it; mirrors turn it; rocks stop it.
function trace(n,board,src){
  const segs=[],hits=new Map(),seen=new Set(),path=[],pcol=[];
  let x=src.x,y=src.y,d=src.d,c='w',sx=x+.5-DX[d]*.5,sy=y+.5-DY[d]*.5,end='edge';
  for(let guard=0;guard<500;guard++){
    if(x<0||y<0||x>=n||y>=n){segs.push([sx,sy,x+.5-DX[d]*.5,y+.5-DY[d]*.5,c]);break}
    const i=y*n+x,key=i*4+d;
    if(seen.has(key)){segs.push([sx,sy,x+.5,y+.5,c]);end='loop';break}
    seen.add(key);
    const cell=board[i],t=cell&&cell.t;
    if(t==='rock'){segs.push([sx,sy,x+.5-DX[d]*.5,y+.5-DY[d]*.5,c]);end='rock';break}
    path.push(i);
    if(t==='glass'){segs.push([sx,sy,x+.5,y+.5,c]);c=cell.c;sx=x+.5;sy=y+.5}
    pcol.push(c);
    if(t==='sensor'){if(!hits.has(i))hits.set(i,new Set());hits.get(i).add(c)}
    if(t==='m'){segs.push([sx,sy,x+.5,y+.5,c]);d=(cell.o?BS:SL)[d];sx=x+.5;sy=y+.5}
    x+=DX[d];y+=DY[d];
  }
  return {segs,hits,path,pcol,end};
}
function isLit(cell,h){return !!h&&(cell.c==='w'?h.size>0:h.has(cell.c))}
function litCount(P,board,tr){let k=0;for(const s of P.sensors)if(isLit(board[s],tr.hits.get(s)))k++;return k}
function shuffle(a,r){a=a.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(r()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a}
function withO(board,mir,mask){const b=board.slice();mir.forEach((i,k)=>{b[i]={t:'m',o:(mask>>k)&1}});return b}
function solutions(P,board){const out=[];for(let m=0;m<(1<<P.mir.length);m++){const b=withO(board,P.mir,m);if(litCount(P,b,trace(P.n,b,P.src))===P.sensors.length)out.push(m)}return out}
const pop=v=>{let k=0;while(v){k+=v&1;v>>=1}return k};

function gen(rng,depth,sensors){
  const c=CFG[depth],n=c.n;
  for(let att=0;att<4000;att++){
    const board=new Array(n*n).fill(null);
    const side=Math.floor(rng()*4),k=1+Math.floor(rng()*(n-2));
    const src=[{x:k,y:n-1,d:0},{x:0,y:k,d:1},{x:k,y:0,d:2},{x:n-1,y:k,d:3}][side];
    const srcI=src.y*n+src.x;
    for(let r=0;r<c.rocks;r++){const i=Math.floor(rng()*n*n);if(i!==srcI&&!board[i])board[i]={t:'rock'}}
    let ok=true,lastIdx=-1;const pathM=[];
    for(let m=0;m<c.pm;m++){
      const tr=trace(n,board,src);
      const cand=tr.path.slice(lastIdx+2).filter(i=>!board[i]&&i!==srcI);
      if(!cand.length){ok=false;break}
      const i=cand[Math.floor(rng()*cand.length)];
      board[i]={t:'m',o:rng()<.5?0:1};pathM.push(i);
      lastIdx=trace(n,board,src).path.indexOf(i);
    }
    if(!ok)continue;
    let tr=trace(n,board,src);
    if(tr.end==='loop'||pathM.some(i=>!tr.path.includes(i)))continue;
    const firstM=tr.path.indexOf(pathM[0]);
    for(let gI=0;gI<c.glass;gI++){
      const cand=tr.path.slice(firstM+1).filter(i=>!board[i]);if(!cand.length){ok=false;break}
      board[cand[Math.floor(rng()*cand.length)]]={t:'glass',c:gI===0?(rng()<.5?'r':'b'):(board.some(b=>b&&b.t==='glass'&&b.c==='r')?'b':'r')};
      tr=trace(n,board,src);
    }
    if(!ok||tr.end==='loop')continue;
    // sensors: one past the last turn, the rest anywhere after the first turn
    const lastM=tr.path.lastIndexOf(pathM[pathM.length-1]);
    const tail=tr.path.map((i,j)=>j).filter(j=>j>lastM&&!board[tr.path[j]]);
    const mid=tr.path.map((i,j)=>j).filter(j=>j>firstM&&j<lastM&&!board[tr.path[j]]);
    if(!tail.length||mid.length<c.sens-1)continue;
    const pickJ=[tail[Math.floor(rng()*tail.length)]];
    for(const j of shuffle(mid,rng)){if(pickJ.length>=c.sens)break;if(pickJ.every(q=>Math.abs(q-j)>1))pickJ.push(j)}
    if(pickJ.length<c.sens)continue;
    const sens=pickJ.map(j=>tr.path[j]);
    if(new Set(sens).size!==sens.length)continue;
    pickJ.forEach(j=>{board[tr.path[j]]={t:'sensor',c:c.glass?tr.pcol[j]:'w'}});
    if(c.glass&&!sens.some(i=>board[i].c!=='w'))continue;
    // decoy mirrors off the path
    const off=[];for(let i=0;i<n*n;i++)if(!board[i]&&!tr.path.includes(i)&&i!==srcI)off.push(i);
    if(off.length<c.dec)continue;
    for(const i of shuffle(off,rng).slice(0,c.dec))board[i]={t:'m',o:rng()<.5?0:1};
    const mir=[];for(let i=0;i<n*n;i++)if(board[i]&&board[i].t==='m')mir.push(i);
    const P={n,src,sensors:sens,mir};
    const solMask=mir.reduce((a,i,k)=>a|(board[i].o<<k),0);
    const sols=solutions(P,board);
    if(!sols.includes(solMask))continue;
    if(sols.length>Math.max(2,(1<<mir.length)/8))continue;
    // locks from sensors: path mirrors bolted the right way
    const nLock=Math.min((sensors>=1)+(sensors>=3)+(sensors>=5),c.pm-2);
    const lockI=shuffle(pathM,rng).slice(0,nLock).map(i=>mir.indexOf(i));
    const lockMask=lockI.reduce((a,k)=>a|(1<<k),0);
    const okSols=sols.filter(m=>(m&lockMask)===(solMask&lockMask));
    // the starting turn of each mirror
    let start=-1,par=0;
    for(let t=0;t<60;t++){
      let m=Math.floor(rng()*(1<<mir.length));m=(m&~lockMask)|(solMask&lockMask);
      const pr=Math.min(...okSols.map(s=>pop(s^m)));
      if(pr<Math.min(c.minPar,c.pm-nLock))continue;
      const b=withO(board,mir,m);if(litCount(P,b,trace(n,b,src))===sens.length)continue;
      start=m;par=pr;break;
    }
    if(start<0)continue;
    const deal=withO(board,mir,start);
    lockI.forEach(k=>{deal[mir[k]].lock=true});
    Object.assign(P,{board:deal,par,sols:okSols,start,lockMask});
    return P;
  }
  throw new Error('beams2: no puzzle');
}
function scoreOf(taps,par,secs,t1){
  const extra=taps-par,p=extra<=0?1:Math.max(0,1-0.12*extra);
  const t=secs<=t1?1:Math.max(0,1-(secs-t1)/(2*t1));
  return clamp(0.3+0.45*p+0.25*t);
}

// ---------- pixel helpers ----------
const B4=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5];
const bay=(x,y)=>(B4[(y&3)*4+(x&3)]+.5)/16;
function rgb(c){const n=parseInt(c.slice(1),16);return[n>>16&255,n>>8&255,n&255]}
function hx(a){return'#'+a.map(v=>Math.max(0,Math.min(255,Math.round(v))).toString(16).padStart(2,'0')).join('')}
function mix(a,b,t){const A=rgb(a),B=rgb(b);return hx(A.map((v,i)=>v+(B[i]-v)*t))}
function R(g,x,y,w,h,c){g.fillStyle=c;g.fillRect(x,y,w,h)}
function card(g,x,y,w,txt,t){const P=TK.PAL;R(g,x,y,w,19,P.bevelLo);R(g,x,y,w,1,P.ember);R(g,x,y+18,w,1,P.ember);const tw=txt.length*4-1,tot=16+tw,x0=x+((w-tot)>>1);if(TK.icon)TK.icon(g,'click',x0,y+3,{t});TK.text(g,txt,x0+16,y+7,P.hot)}
function circ(g,cx,cy,r,c,t){if(r<1){R(g,cx,cy,1,1,c);return}g.fillStyle=c;let x=r,y=0,e=1-r;const seen=new Set();
  while(x>=y){for(const[a,b]of[[x,y],[y,x],[-y,x],[-x,y],[-x,-y],[-y,-x],[y,-x],[x,-y]]){const X=cx+a,Y=cy+b,k=X*1000+Y;if(seen.has(k))continue;seen.add(k);if(t!=null&&bay(X,Y)>=t)continue;g.fillRect(X,Y,1,1)}
    y++;if(e<0)e+=2*y+1;else{x--;e+=2*(y-x)+1}}}
function ball(g,cx,cy,r,ramp){const rr=r*r+r*.8;
  for(let y=-r;y<=r;y++)for(let x=-r;x<=r;x++){if(x*x+y*y>rr)continue;
    const edge=(x-1)*(x-1)+y*y>rr||(x+1)*(x+1)+y*y>rr||x*x+(y-1)*(y-1)>rr||x*x+(y+1)*(y+1)>rr;let col;
    if(edge)col=ramp[0];else{const nx=x/(r+.5),ny=y/(r+.5),nz=Math.sqrt(Math.max(0,1-nx*nx-ny*ny));const l=Math.max(0,-nx*.55-ny*.62+nz*.56);
      col=ramp[Math.max(1,Math.min(ramp.length-1,Math.round(l*(ramp.length-1)+bay(cx+x,cy+y)-.5)))]}
    g.fillStyle=col;g.fillRect(cx+x,cy+y,1,1)}}

TK.css(ID,`.beams2-cv{cursor:pointer}`);

function mount(stage,ctx){
  const P=gen(ctx.rng,ctx.depth,ctx.sensors),{n}=P,PAL=TK.PAL;
  const t1=CFG[ctx.depth].t1+((ctx.sensors>=2)+(ctx.sensors>=4))*15;
  const board=P.board.map(b=>b?Object.assign({},b):null);
  const W=150,H=150,CS=Math.floor(118/n),BW=n*CS,BX=Math.floor((W-BW)/2),BY=14+Math.floor((H-14-BW)/2);
  const pix=TK.pixel(stage,{w:W,h:H}),g=pix.g;pix.cv.classList.add('beams2-cv');
  let over=false,taps=0,won=0,AC=null;const t0=performance.now();
  const ang={};for(const i of P.mir)ang[i]={cur:board[i].o?45:-45,to:board[i].o?45:-45};
  const litSince={};
  const BEAM={w:[PAL.ember,PAL.flare,'#fff3dc'],r:[mix(PAL.bad,'#000000',.35),PAL.bad,mix(PAL.bad,'#ffffff',.55)],b:[mix(PAL.t2,'#000000',.35),PAL.t2,mix(PAL.t2,'#ffffff',.6)]};
  const SCOL={w:PAL.hot,r:PAL.bad,b:PAL.t2};
  function tone(f,d,type,v,to){if(window.TK_MUTE_TONES)return;try{AC=AC||new (window.AudioContext||window.webkitAudioContext)();const t=AC.currentTime,o=AC.createOscillator(),gg=AC.createGain();o.type=type||'sine';o.frequency.setValueAtTime(f,t);if(to)o.frequency.exponentialRampToValueAtTime(to,t+d);gg.gain.setValueAtTime(.0001,t);gg.gain.exponentialRampToValueAtTime(v||.05,t+.04);gg.gain.exponentialRampToValueAtTime(.0001,t+d);o.connect(gg).connect(AC.destination);o.start(t);o.stop(t+d+.02)}catch(e){}}

  // ---- static: console plate and optical table ----
  const bgc=document.createElement('canvas');bgc.width=W;bgc.height=H;const b=bgc.getContext('2d');
  R(b,0,0,W,H,PAL.panel);
  for(const[x,y]of[[3,3],[W-5,3],[3,H-5],[W-5,H-5]]){R(b,x,y,2,2,PAL.bevelHi);R(b,x+1,y+1,1,1,PAL.bevelLo)}
  R(b,BX-3,BY-3,BW+6,BW+6,PAL.bevelLo);R(b,BX-2,BY-2,BW+4,BW+4,'#000');
  R(b,BX-3,BY+BW+2,BW+6,1,PAL.bevelHi);R(b,BX+BW+2,BY-3,1,BW+6,PAL.bevelHi);
  R(b,BX,BY,BW,BW,'#0d121b');
  for(let y=0;y<BW;y++)for(let x=0;x<BW;x++){const lit=1-(x+y)/(BW*2);if(bay(BX+x,BY+y)<lit*.35)R(b,BX+x,BY+y,1,1,'#111823')}
  for(let j=0;j<n;j++)for(let i=0;i<n;i++){const x=BX+i*CS,y=BY+j*CS;
    R(b,x+(CS>>1),y+(CS>>1),1,1,PAL.line);
    for(const[a,c]of[[2,2],[CS-3,2],[2,CS-3],[CS-3,CS-3]])R(b,x+a,y+c,1,1,'#18212d');}
  // emitter housing on the edge
  const s=P.src,ex=BX+s.x*CS+(CS>>1),ey=BY+s.y*CS+(CS>>1);
  const em=s.d===1?{x:BX-12,y:ey-5,w:10,h:11}:s.d===3?{x:BX+BW+2,y:ey-5,w:10,h:11}:s.d===2?{x:ex-5,y:BY-12,w:11,h:10}:{x:ex-5,y:BY+BW+2,w:11,h:10};
  R(b,em.x,em.y,em.w,em.h,'#000');R(b,em.x+1,em.y+1,em.w-2,em.h-2,PAL.cold);R(b,em.x+1,em.y+1,em.w-2,1,PAL.ice);R(b,em.x+1,em.y+1,1,em.h-2,PAL.chill);
  R(b,em.x+2,em.y+em.h-3,em.w-3,1,'#3b4a5c');R(b,em.x+3,em.y+3,em.w-6,em.h-6,PAL.ember);R(b,em.x+3,em.y+3,1,1,PAL.hot);
  // rocks and glass are fixed
  for(let i=0;i<n*n;i++){const cell=board[i];if(!cell)continue;const x=BX+(i%n)*CS,y=BY+((i/n)|0)*CS,cx=x+(CS>>1),cy=y+(CS>>1);
    if(cell.t==='rock'){ball(b,cx,cy,Math.floor(CS*.36),['#0b0d10','#262b33','#3a4048','#565e69','#7a838f']);R(b,cx+1,cy,2,1,'#262b33');R(b,cx+1,cy-1,1,1,'#565e69')}
    if(cell.t==='glass'){const col=SCOL[cell.c],m=3;
      for(let yy=m;yy<CS-m;yy++)for(let xx=m;xx<CS-m;xx++)if(bay(x+xx,y+yy)<.4)R(b,x+xx,y+yy,1,1,mix(col,'#000000',.35));
      R(b,x+m-1,y+m-1,CS-2*m+2,1,'#000');R(b,x+m-1,y+CS-m,CS-2*m+2,1,'#000');R(b,x+m-1,y+m-1,1,CS-2*m+2,'#000');R(b,x+CS-m,y+m-1,1,CS-2*m+2,'#000');
      R(b,x+m,y+m,CS-2*m,1,mix(col,'#ffffff',.4));R(b,x+m,y+m,1,CS-2*m,mix(col,'#ffffff',.25));R(b,x+m,y+CS-m-1,CS-2*m,1,mix(col,'#000000',.2));R(b,x+CS-m-1,y+m,1,CS-2*m,mix(col,'#000000',.2));
      for(let k=0;k<4;k++){R(b,x+m+3+k,y+CS-m-4-k,1,1,'#ffffff')}}
  }

  function beamPixels(tr){
    // rasterise the axis-aligned segments, remembering each pixel's colour
    const px=[];
    for(const[a,c0,c,d,col]of tr.segs){
      const x0=Math.round(BX+a*CS),y0=Math.round(BY+c0*CS),x1=Math.round(BX+c*CS),y1=Math.round(BY+d*CS);
      const dx=Math.sign(x1-x0),dy=Math.sign(y1-y0),len=Math.max(Math.abs(x1-x0),Math.abs(y1-y0));
      for(let k=0;k<=len;k++)px.push([x0+dx*k,y0+dy*k,col,dx!==0]);
    }
    return px;
  }
  function drawMirror(i,lock){
    const x=BX+(i%n)*CS+(CS>>1),y=BY+((i/n)|0)*CS+(CS>>1),r=Math.floor(CS*.28);
    // mount
    ball(g,x,y,r,['#05070a','#1a222d','#2b3644','#3d4d61','#56677d']);
    const a=ang[i].cur*Math.PI/180,L=CS*.42,ca=Math.cos(a),sa=Math.sin(a);
    // plate: back (dark) then silvered face, 2 px thick, outlined
    const pts=new Map();
    for(let t=-L;t<=L;t+=.35)for(let w=-1.3;w<=1.3;w+=.35){const px=Math.round(x+ca*t-sa*w),py=Math.round(y+sa*t+ca*w);const k=px+','+py;
      const lay=Math.abs(w)>.95?0:(w<0?2:1);if(!pts.has(k)||pts.get(k)[2]<lay)pts.set(k,[px,py,lay,t])}
    for(const[px,py,lay,t]of pts.values()){const shine=Math.abs(t+L*.35)<1.2;R(g,px,py,1,1,lay===0?'#000':lay===2?(shine?'#ffffff':PAL.ice):PAL.cold)}
    if(lock){for(const[dx,dy]of[[-r,-r],[r,-r],[-r,r],[r,r]]){R(g,x+dx,y+dy,1,1,PAL.warn)}}
  }
  function render(now){
    g.drawImage(bgc,0,0);
    for(const i of P.mir){const A=ang[i];if(A.cur!==A.to){const d=A.to-A.cur,st=Math.sign(d)*Math.min(Math.abs(d),18);A.cur+=st}}
    const settled=P.mir.every(i=>ang[i].cur===ang[i].to);
    const tr=trace(n,board,P.src);
    // beam with a dithered glow and a little shimmer running along it
    const bp=beamPixels(tr),ph=(now/60)|0,glow=won?.85:.55;
    for(const[x,y,col,hor]of bp){const C=BEAM[col];
      for(const o of[-2,2]){const X=hor?x:x+o,Y=hor?y+o:y;if(bay(X,Y)<glow*.35)R(g,X,Y,1,1,C[0])}
      for(const o of[-1,1]){const X=hor?x:x+o,Y=hor?y+o:y;if(bay(X+ph,Y+ph)<glow+.2)R(g,X,Y,1,1,C[1])}}
    for(const[x,y,col]of bp)R(g,x,y,1,1,(x+y+ph*2)%9===0?'#ffffff':BEAM[col][2]);
    // emitter glow
    circ(g,ex+(s.d===1?-(CS>>1):s.d===3?(CS>>1):0),ey+(s.d===2?-(CS>>1):s.d===0?(CS>>1):0),2,PAL.flare,.6);
    // pieces
    let lit=0;
    for(let i=0;i<n*n;i++){const cell=board[i];if(!cell)continue;
      if(cell.t==='m')drawMirror(i,cell.lock);
      if(cell.t==='sensor'){
        const x=BX+(i%n)*CS+(CS>>1),y=BY+((i/n)|0)*CS+(CS>>1),r=Math.floor(CS*.3),col=SCOL[cell.c];
        const on=isLit(cell,tr.hits.get(i)),wrong=!on&&tr.hits.has(i);
        if(on){lit++;if(!litSince[i]){litSince[i]=now;TK.sfx('beams2','lit');if(settled||true)tone(165*(1+P.sensors.indexOf(i)*.5),.7,'sine',.05)}}else delete litSince[i];
        // housing: a square receiver with a round lens
        R(g,x-r-2,y-r-2,2*r+5,2*r+5,'#000');R(g,x-r-1,y-r-1,2*r+3,2*r+3,'#2b3644');R(g,x-r-1,y-r-1,2*r+3,1,PAL.bevelHi);R(g,x-r-1,y-r-1,1,2*r+3,PAL.bevelHi);
        if(on){
          const pulse=.5+.3*Math.sin((now-litSince[i])/180);
          circ(g,x,y,r+3,col,pulse*.6);circ(g,x,y,r+2,col,pulse);
          ball(g,x,y,r,[mix(col,'#000000',.6),mix(col,'#000000',.2),col,mix(col,'#ffffff',.45),'#ffffff']);
        }else{
          ball(g,x,y,r,['#000000','#0b0f15','#151c26','#1f2935',mix(col,'#000000',.55)]);
          circ(g,x,y,r,mix(col,'#000000',.25),.75);
          if(wrong&&((now/250)|0)%2)circ(g,x,y,r,PAL.bad,.9);
        }
      }
    }
    // HUD
    TK.text(g,'LIT',4,3,PAL.cold);
    P.sensors.forEach((i,k)=>{const on=isLit(board[i],tr.hits.get(i)),col=SCOL[board[i].c];R(g,19+k*7,3,5,5,'#000');R(g,20+k*7,4,3,3,on?col:'#1f2935')});
    TK.text(g,'TURNS '+taps,W-4,3,PAL.cold,'right');
    if(!taps&&!over&&now-t0<4500)card(g,BX,BY+(BW>>1)-9,BW,'LIGHT EVERY SENSOR.',(now-t0)/1000);
    if(won)TK.text(g,'ALL LIT',W>>1,H-7,PAL.hot,'center');
    if(!over&&lit===P.sensors.length&&settled)win(now);
  }
  function win(now){TK.sfx('beams2','win');
    over=true;won=now;
    const secs=(now-t0)/1000;
    tone(330,.5,'triangle',.05);setTimeout(()=>tone(495,.6,'triangle',.05),120);
    ctx.done({score:scoreOf(taps,P.par,secs,t1),detail:`All ${P.sensors.length} lit with ${taps} turns (best ${P.par})`});
  }
  function onDown(e){
    e.preventDefault();if(over)return;
    const q=pix.pt(e),cx=Math.floor((q.x-BX)/CS),cy=Math.floor((q.y-BY)/CS);
    if(cx<0||cy<0||cx>=n||cy>=n)return;
    const i=cy*n+cx,cell=board[i];
    if(!cell||cell.t!=='m')return;
    if(cell.lock){tone(120,.1,'square',.03);return}
    cell.o^=1;ang[i].to+=90;taps++;TK.sfx('beams2','turn');tone(700,.05,'square',.025,500);
  }
  pix.cv.addEventListener('pointerdown',onDown);
  let raf=0,last=0,alive=true;
  const loop=now=>{if(!alive)return;raf=requestAnimationFrame(loop);if(now-last<32)return;last=now;render(now)};
  raf=requestAnimationFrame(loop);render(performance.now());
  return {
    _p:P,_cell:i=>({x:BX+(i%n)*CS+(CS>>1),y:BY+((i/n)|0)*CS+(CS>>1)}),_board:board,
    destroy(){alive=false;over=true;cancelAnimationFrame(raf);pix.destroy();try{AC&&AC.close()}catch(e){}},
    giveUp(){if(over)return;over=true;const lit=litCount(P,board,trace(n,board,P.src));ctx.done({score:0.1*lit/P.sensors.length,detail:`Gave up with ${lit} of ${P.sensors.length} lit`})},
  };
}

TK.register({
  id:ID,name:'Beam Bench',hint:'Light every sensor.',controls:['click'],where:'Comet ice, nebulae',skill:'Spatial reasoning',
  blurb:'Turn mirrors so the laser lights every sensor.',
  how:[
    'Tap a mirror to turn it. The laser follows at once.',
    'Light every sensor. It glows and hums when the beam hits it.',
    'Fewer turns score higher.',
  ],
  deeper:'Bigger tables, rocks that stop the beam, spare mirrors. Sector 3+: coloured glass tints the beam; a coloured sensor wants its own colour.',
  sensors:'1, 3, 5: one mirror bolted the right way. 2 and 4: more time before the clock costs you.',
  mount,
  _t:{gen,trace,litCount,solutions,scoreOf,CFG,withO,pop},
});
})();
