// Seismic Scan II: the ship's sensor map of a barren field. Tap a spot to scan it: a radar ring
// sweeps out, and each buried find it passes pops up on the graph (right = rarer, tall = nearer).
// Every scan leaves a beacon; tap or hover one to bring its graph and rings back. Then dig.
(function(){
'use strict';
const ID='seismic2';
const VAL=[1,2,4,7,11];
const TN=['COMMON','UNCOMMON','RARE','EPIC','LEGENDARY'];
const TC=['#a3abb3','#4fbf82','#6a9ad4','#9a62e6','#d99b29'];
const CFG=[null,
  {G:8, tiers:[0,1,2],       scans:4,range:4.5},
  {G:9, tiers:[0,1,2,3],     scans:5,range:4.5},
  {G:9, tiers:[0,1,1,2,3],   scans:5,range:4.5},
  {G:10,tiers:[0,1,2,3,4],   scans:6,range:4.5},
  {G:10,tiers:[0,1,1,2,3,4], scans:6,range:4.2}];
const CPOF=G=>Math.floor(110/G);

function params(depth,s){
  const c=CFG[depth];
  return {G:c.G,tiers:c.tiers,scans:c.scans+(s>=1)+(s>=3)+(s>=5),digs:c.tiers.length+1+(s>=4),range:c.range+(s>=2?1:0),tol:0.6/CPOF(c.G)};
}
const dist=(ax,ay,bx,by)=>Math.hypot(ax-bx,ay-by);
// What one scan hears: every find within range, with its tier and distance.
function scanAt(S,x,y){
  const out=[];
  S.deps.forEach((q,i)=>{const d=dist(q.x,q.y,x,y);if(d<=S.range+1e-9)out.push({i,t:q.t,d})});
  return out.sort((a,b)=>a.d-b.d);
}
// Cells a find of tier t could sit in, given what every scan heard.
function candidates(S,scans,t,ruled){
  const G=S.G,c=[];
  for(let y=0;y<G;y++)for(let x=0;x<G;x++){
    if(ruled&&ruled.has(y*G+x))continue;
    let ok=true;
    for(const p of scans){const d=dist(x,y,p.x,p.y);
      if(d<=S.range+1e-9){if(!p.out.some(e=>e.t===t&&Math.abs(e.d-d)<=S.tol)){ok=false;break}}}
    if(ok)c.push(y*G+x);
  }
  return c;
}
// The find a dig at (x,y) reaches: the nearest one not yet dug within reach cells (square).
function nearFind(S,x,y,reach,got){let best=null,bd=1e9;S.deps.forEach((q,i)=>{if(q.got||got&&got.has(i))return;const c=Math.max(Math.abs(q.x-x),Math.abs(q.y-y));if(c<=reach){const d=dist(q.x,q.y,x,y);if(d<bd){bd=d;best=q}}});return best}
// A player who only uses what the screen shows: scan to cover the field, then scan to split
// the spots still in doubt, then dig the surest spot first.
function solver(S){
  const G=S.G,scans=[],ruled=new Set(),got=new Set();
  const tiers=[...new Set(S.tiers)];
  const cover=new Uint8Array(G*G);
  for(let k=0;k<S.scans;k++){
    let best=null,bv=-1e9;
    const unc=[];for(let i=0;i<G*G;i++)if(!cover[i])unc.push(i);
    const amb=scans.length?tiers.map(t=>candidates(S,scans,t)).filter((c,j)=>c.length>S.tiers.filter(q=>q===tiers[j]).length):[];
    for(let y=0;y<G;y++)for(let x=0;x<G;x++){
      if(scans.some(p=>p.x===x&&p.y===y))continue;
      let v=0;
      for(const i of unc)if(dist(i%G,(i/G)|0,x,y)<=S.range)v+=10;
      for(const c of amb){const ds=new Set(c.map(i=>{const d=dist(i%G,(i/G)|0,x,y);return d<=S.range?Math.round(d/S.tol):-1}));v+=ds.size}
      v-=dist(x,y,(G-1)/2,(G-1)/2)*0.01;
      if(v>bv){bv=v;best=[x,y]}
    }
    const [x,y]=best;scans.push({x,y,out:scanAt(S,x,y)});
    for(let i=0;i<G*G;i++)if(dist(i%G,(i/G)|0,x,y)<=S.range)cover[i]=1;
  }
  let digs=S.digs;
  while(digs>0&&got.size<S.deps.length){
    let pick=null;
    for(const t of tiers.slice().sort((a,b)=>b-a)){
      const need=S.deps.filter((q,i)=>q.t===t&&!got.has(i)).length;if(!need)continue;
      const c=candidates(S,scans,t,ruled);if(!c.length)continue;
      if(!pick||c.length/need<pick.c.length/pick.need)pick={t,c,need};
    }
    if(!pick)break;
    const cell=pick.c[0];digs--;ruled.add(cell);
    const q=nearFind(S,cell%G,(cell/G)|0,1,got);
    if(q)got.add(S.deps.indexOf(q));
  }
  return {got:got.size,all:got.size===S.deps.length,scans};
}
function gen(rng,depth,s){
  const P=params(depth,s),G=P.G,mid=(G-1)/2;
  let fallback=null;
  for(let a=0;a<400;a++){
    const deps=[];let ok=true;
    for(const t of P.tiers){
      let placed=false;
      for(let k=0;k<80&&!placed;k++){
        const x=Math.floor(rng()*G),y=Math.floor(rng()*G);
        if(t>=2&&Math.hypot(x-mid,y-mid)<G*0.22)continue; // rare ones hide out from the middle
        if(deps.some(q=>Math.hypot(q.x-x,q.y-y)<2.2))continue;
        deps.push({x,y,t,got:false});placed=true;
      }
      if(!placed){ok=false;break}
    }
    if(!ok)continue;
    const S=Object.assign({deps},P);
    if(solver(S).all)return S;
    if(!fallback)fallback=S;
  }
  if(fallback){fallback.unproven=true;return fallback}
  throw new Error('seismic2: no layout');
}
function value(S){return S.deps.filter(q=>q.got).reduce((a,q)=>a+VAL[q.t],0)}
function total(S){return S.deps.reduce((a,q)=>a+VAL[q.t],0)}
function score(S,spare){const f=value(S)/total(S);return Math.min(1,f*(0.85+0.15*Math.min(1,spare/2)))}

// ---------- pixel helpers ----------
const B4=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5];
const bay=(x,y)=>(B4[(y&3)*4+(x&3)]+.5)/16;
function rgb(c){const n=parseInt(c.slice(1),16);return[n>>16&255,n>>8&255,n&255]}
function hx(a){return'#'+a.map(v=>Math.max(0,Math.min(255,Math.round(v))).toString(16).padStart(2,'0')).join('')}
function mix(a,b,t){const A=rgb(a),B=rgb(b);return hx(A.map((v,i)=>v+(B[i]-v)*t))}
function R(g,x,y,w,h,c){g.fillStyle=c;g.fillRect(x,y,w,h)}
function card(g,x,y,w,txt,t){const P=TK.PAL;R(g,x,y,w,19,P.bevelLo);R(g,x,y,w,1,P.ember);R(g,x,y+18,w,1,P.ember);const tw=txt.length*4-1,tot=16+tw,x0=x+((w-tot)>>1);if(TK.icon)TK.icon(g,'click',x0,y+3,{t});TK.text(g,txt,x0+16,y+7,P.hot)}
function circ(g,cx,cy,r,c,t,dash){if(r<1){R(g,cx,cy,1,1,c);return}g.fillStyle=c;let x=r,y=0,e=1-r;const seen=new Set();
  while(x>=y){for(const[a,b]of[[x,y],[y,x],[-y,x],[-x,y],[-x,-y],[-y,-x],[y,-x],[x,-y]]){const X=cx+a,Y=cy+b,k=X*1000+Y;if(seen.has(k))continue;seen.add(k);if(t!=null&&bay(X,Y)>=t)continue;if(dash&&(((Math.atan2(b,a)+4)*r/2.5)|0)%2)continue;g.fillRect(X,Y,1,1)}
    y++;if(e<0)e+=2*y+1;else{x--;e+=2*(y-x)+1}}}
function gemSprite(g,x,y,t){
  const c=TC[t],hi=mix(c,'#ffffff',.55),lo=mix(c,'#000000',.45),ol=mix(c,'#000000',.75);
  const rows=['.ooo.','ohccl','occcl','.ocl.','..o..'];
  R(g,x-2,y-3,5,1,ol);
  rows.forEach((r,j)=>{for(let i=0;i<5;i++){const ch=r[i];if(ch==='.')continue;R(g,x-2+i,y-2+j,1,1,ch==='o'?ol:ch==='h'?hi:ch==='l'?lo:c)}});
  R(g,x-1,y-2,3,1,hi);
}

TK.css(ID,`.seismic2-cv{cursor:crosshair}`);

TK.register({
  id:ID,name:'Seismic Scan II',hint:'Scan, then dig.',controls:['click'],where:'Asteroid belts, barren worlds',skill:'Spatial reasoning',
  blurb:'Scan the ground from orbit, read the echoes, and dig out the buried finds.',
  how:[
    'Tap the ground: the ship scans there. A ring sweeps out.',
    'Each find the ring passes jumps up on the graph. Right is rarer. Tall is nearer.',
    'Each scan leaves a beacon. Tap one to see its graph again; press and slide to peek.',
    'Same-colour rings from two beacons cross on a find. Dig there.',
  ],
  deeper:'Bigger fields and more finds. Sector 5: two of a kind, and a shorter scan.',
  sensors:'1, 3, 5: one extra scan. 2: the scan reaches further. 4: one extra dig.',
  _t:{gen,nearFind,CPOF,scanAt,candidates,solver,score,value,total,params,CFG,VAL},
  mount(stage,ctx){
    const S=gen(ctx.rng,ctx.depth,ctx.sensors);
    const PAL=TK.PAL,G=S.G,CP=CPOF(G),FW=G*CP,W=150,FX=Math.floor((W-FW)/2),FY=15;
    const GY=FY+FW+4,GH=30,GB=GY+GH-3,GT=GY+3,X0=FX+18,X1=FX+FW-4,H=GY+GH+8;
    const P=TK.pixel(stage,{w:W,h:H}),g=P.g;P.cv.classList.add('seismic2-cv');
    let scansLeft=S.scans,digsLeft=S.digs,tool='scan',over=false,busy=false,AC=null,touched=false;
    const timers=[],later=(f,ms)=>timers.push(setTimeout(f,ms));
    const scans=[],holes=[],gems=[],parts=[];
    let closeT=0,sel=-1,peek=-1,hoverCell=null,hoverSpike=null,sweep=null,drillA=null,msg='',msgCol=PAL.hot,endGhost=false;
    const t00=performance.now();
    function tone(f,d,type,v,to){if(window.TK_MUTE_TONES)return;try{AC=AC||new (window.AudioContext||window.webkitAudioContext)();const t=AC.currentTime,o=AC.createOscillator(),gg=AC.createGain();o.type=type||'sine';o.frequency.setValueAtTime(f,t);if(to)o.frequency.exponentialRampToValueAtTime(to,t+d);gg.gain.setValueAtTime(v||.05,t);gg.gain.exponentialRampToValueAtTime(.0001,t+d);o.connect(gg).connect(AC.destination);o.start(t);o.stop(t+d+.02)}catch(e){}}
    const ccx=x=>FX+x*CP+(CP>>1),ccy=y=>FY+y*CP+(CP>>1);
    const ringR=d=>d<0.5?3:Math.round(d*CP);   // true distance in art pixels

    // ---- static ground ----
    let hs=(S.deps[0].x*131+S.deps[0].y*977+G)|1;const hr=()=>{hs=(hs*1103515245+12345)&0x7fffffff;return hs/0x7fffffff};
    const SOIL=['#140e08','#21180e','#2e2214','#3d2e1b','#4f3d25','#625031'];
    const bgc=document.createElement('canvas');bgc.width=W;bgc.height=H;const b=bgc.getContext('2d');
    R(b,0,0,W,H,PAL.panel);
    for(let y=0;y<H;y+=2)for(let x=(y>>1)&1;x<W;x+=4)if(bay(x,y)<.2)R(b,x,y,1,1,PAL.line);
    const NS=8,nz=[];for(let i=0;i<(W/NS+2)*(H/NS+2);i++)nz.push(hr());
    const vn=(x,y,s)=>{const gw=Math.ceil(W/s)+2,X=x/s,Y=y/s,x0=Math.floor(X),y0=Math.floor(Y),fx=X-x0,fy=Y-y0,v=(i,j)=>nz[((j*gw+i)*7)%nz.length];
      const a=v(x0,y0)+(v(x0+1,y0)-v(x0,y0))*fx,c=v(x0,y0+1)+(v(x0+1,y0+1)-v(x0,y0+1))*fx;return a+(c-a)*fy};
    for(let y=0;y<FW;y++)for(let x=0;x<FW;x++){
      const v=vn(x,y,10)*.6+vn(x+40,y+17,4)*.4,lit=(-(x-FW/2)-(y-FW/2))/FW*.25;
      const k=Math.round((v+lit)*5-.3+bay(x,y)-.5);
      R(b,FX+x,FY+y,1,1,SOIL[Math.max(1,Math.min(4,k))]);
    }
    for(let k=0;k<G*G*.35;k++){const x=FX+2+Math.floor(hr()*(FW-4)),y=FY+2+Math.floor(hr()*(FW-4)),big=hr()<.35;
      if(big){R(b,x-1,y,3,2,SOIL[1]);R(b,x-1,y-1,2,1,SOIL[4]);R(b,x,y,2,1,SOIL[4]);R(b,x+1,y+1,1,1,SOIL[0])}
      else{R(b,x,y,1,1,SOIL[1])}}
    for(let k=0;k<4;k++){let x=FX+Math.floor(hr()*FW),y=FY+Math.floor(hr()*FW);for(let s=0;s<18;s++){R(b,x,y,1,1,SOIL[0]);x+=hr()<.6?1:0;y+=hr()<.5?1:-1;if(x>=FX+FW||y<FY||y>=FY+FW)break}}
    for(let j=1;j<G;j++)for(let i=1;i<G;i++)R(b,FX+i*CP,FY+j*CP,1,1,SOIL[3]);
    R(b,FX-2,FY-2,FW+4,1,PAL.bevelLo);R(b,FX-2,FY-2,1,FW+4,PAL.bevelLo);R(b,FX-2,FY+FW+1,FW+4,1,PAL.bevelHi);R(b,FX+FW+1,FY-2,1,FW+4,PAL.bevelHi);
    R(b,FX-1,FY-1,FW+2,1,'#000');R(b,FX-1,FY-1,1,FW+2,'#000');R(b,FX-1,FY+FW,FW+2,1,'#000');R(b,FX+FW,FY-1,1,FW+2,'#000');
    // the graph screen
    R(b,FX-1,GY-1,FW+2,GH+1,'#000');R(b,FX,GY,FW,GH-1,PAL.void);
    for(let t=0;t<5;t++){const lx=Math.round(X0+(t+.5)*(X1-X0)/5);for(let y=GT;y<=GB;y+=2)R(b,lx,y,1,1,PAL.panel);R(b,lx-3,GB+1,7,1,TC[t])}
    R(b,X0-3,GT,1,GB-GT+1,PAL.line);R(b,X0-4,GT+1,3,1,PAL.line);
    R(b,X0,GB,X1-X0+1,1,PAL.line);
    TK.text(b,'NEAR',FX+2,GT,PAL.cold);TK.text(b,'FAR',FX+2,GB-4,PAL.line);
    TK.text(b,'COMMON',X0,GY+GH+1,PAL.cold);
    TK.text(b,'RARE',X1,GY+GH+1,PAL.cold,'right');

    const gx=(t,slot)=>Math.round(X0+(t+.5)*(X1-X0)/5)+slot*5;
    const gh=d=>Math.max(2,Math.round((GB-GT)*(1-d/(S.range+0.6))));
    function spikesOf(p,upTo){
      const out=[],per={};
      for(const e of p.out){if(upTo!=null&&e.d>upTo)continue;const n=per[e.t]||0;per[e.t]=n+1;
        out.push({e,x:gx(e.t,n%2?Math.ceil(n/2):-Math.ceil(n/2)),h:gh(e.d)})}
      return out;
    }

    // ---- HUD: two tools, scanner and drill, each with its charges ----
    const TW=Math.min(68,(FW>>1)-1),TB=[{id:'scan',x:FX-1,w:TW},{id:'dig',x:FX+FW+1-TW,w:TW}];
    function radarIcon(x,y,c){R(g,x,y+7,7,1,c);R(g,x+3,y+4,1,3,c);for(const[a,b2]of[[0,2],[1,1],[2,0],[3,0],[4,0],[5,1],[6,2],[1,3],[5,3]])R(g,x+a,y+b2,1,1,c);R(g,x+3,y+2,1,1,PAL.hot)}
    function drillIcon(x,y,c){R(g,x,y,7,2,c);R(g,x+2,y+2,3,1,c);R(g,x+2,y+3,3,2,c);R(g,x+3,y+5,1,3,c);R(g,x+2,y+4,1,1,PAL.bevelLo)}
    function drawTools(){
      for(const tb of TB){
        const on=tool===tb.id,live=tb.id==='scan'?scansLeft>0:digsLeft>0,y=1;
        R(g,tb.x,y,tb.w,12,'#000');R(g,tb.x+1,y+1,tb.w-2,10,on?'#3a2410':PAL.panel);
        R(g,tb.x+1,y+1,tb.w-2,1,on?PAL.ember:PAL.bevelHi);
        if(on)R(g,tb.x+1,y+10,tb.w-2,1,PAL.ember);
        const ic=on?PAL.hot:live?PAL.chill:PAL.line;
        (tb.id==='scan'?radarIcon:drillIcon)(tb.x+3,y+2,ic);
        const n=tb.id==='scan'?S.scans:S.digs,l=tb.id==='scan'?scansLeft:digsLeft,sp=Math.min(5,Math.floor((tb.w-15)/n));
        for(let i=0;i<n;i++){const x=tb.x+13+i*sp;R(g,x,y+3,sp-1,6,'#000');R(g,x,y+3,sp-2,5,i<l?(on?PAL.ember:PAL.cold):PAL.line);if(i<l&&on)R(g,x,y+3,sp-2,1,PAL.hot)}
      }
    }

    function curScan(){return peek>=0?peek:sel}
    function render(now){
      g.drawImage(bgc,0,0);
      drawTools();
      g.save();g.beginPath();g.rect(FX,FY,FW,FW);g.clip();
      // echo rings from EVERY scan, each in its find's tier colour, radius = the true distance.
      // Same-colour rings from two beacons cross on the find. A picked spike lights that find's rings only.
      const ci=curScan(),cs=ci>=0?scans[ci]:null,focus=hoverSpike?hoverSpike.i:-1;
      if(cs&&!(sweep&&sweep.p===cs))circ(g,ccx(cs.x),ccy(cs.y),Math.round(S.range*CP),PAL.line,.3,true);
      const lateRings=[];
      scans.forEach((p,k)=>{
        if(sweep&&sweep.p===p)return;
        for(const e of p.out){
          const r=ringR(e.d);
          if(focus>=0){if(e.i===focus)lateRings.push([p,r,mix(TC[e.t],'#ffffff',.25),null]);else circ(g,ccx(p.x),ccy(p.y),r,TC[e.t],.12);continue}
          circ(g,ccx(p.x),ccy(p.y),r,TC[e.t],k===ci?.8:.45);
        }
      });
      for(const[p,r,c,t]of lateRings)circ(g,ccx(p.x),ccy(p.y),r,c,t);
      // hover preview: where a scan here would reach
      if(hoverCell&&tool==='scan'&&!busy&&!over&&scansLeft>0&&!scans.some(p=>p.x===hoverCell.x&&p.y===hoverCell.y))
        circ(g,ccx(hoverCell.x),ccy(hoverCell.y),Math.round(S.range*CP),PAL.tractor,.35,true);
      // holes
      for(const h of holes){const x=ccx(h.x),y=ccy(h.y);R(g,x-2,y-1,5,3,'#050304');R(g,x-1,y-2,3,5,'#050304');R(g,x-1,y+2,3,1,SOIL[5]);if(!h.hit){const xc=h.close?PAL.hot:PAL.bad;R(g,x-1,y-1,1,1,xc);R(g,x+1,y+1,1,1,xc);R(g,x+1,y-1,1,1,xc);R(g,x-1,y+1,1,1,xc);R(g,x,y,1,1,xc)}if(h.close&&h===holes[holes.length-1]){const u=(now-closeT)/700;if(u<1){circ(g,x,y,Math.round(3+u*CP*1.5),PAL.hot,1-u);circ(g,x,y,Math.round(2+u*CP),PAL.flare,.7*(1-u))}}}
      // the sweep: a beam drops from the ship, then a ring sweeps out with a turning arm
      if(sweep){
        const el=now-sweep.t0,x=ccx(sweep.p.x),y=ccy(sweep.p.y);
        if(el<250){const yy=FY+Math.round((y-FY)*el/250);for(let j=FY;j<yy;j+=2)R(g,x,j,1,1,PAL.tractor)}
        else{
          const u=Math.min(1,(el-250)/sweep.dur),d=u*S.range,r=Math.round(d*CP);
          for(let k=1;k<=3;k++){const rr=r-k*2;if(rr>1)circ(g,x,y,rr,PAL.tractor,.35-k*.1)}
          if(r>=1)circ(g,x,y,r,u<.85?PAL.mark:PAL.tractor);
          const a=el/160;for(let k=0;k<=r;k++){const px=Math.round(x+Math.cos(a)*k),py=Math.round(y+Math.sin(a)*k);if(bay(px,py)<.8)R(g,px,py,1,1,PAL.tractor)}
          sweep.p.out.forEach(e=>{if(sweep.heard.has(e)||e.d>d)return;sweep.heard.add(e);tone(260+e.t*110,.16,'square',.02,200+e.t*90);sweep.flash.push({e,t:now})});
          for(const f of sweep.flash){const fu=(now-f.t)/500;circ(g,x,y,ringR(f.e.d),fu<.3?'#ffffff':TC[f.e.t],fu<1?null:.6)}
          if(u>=1&&!sweep.end){sweep.end=true;later(endSweep,150)}
        }
      }
      // beacons
      scans.forEach((p,k)=>{
        const x=ccx(p.x),y=ccy(p.y),on=k===ci,pulse=on&&((now/300)|0)%2;
        R(g,x-2,y-2,5,5,'#000');R(g,x-1,y-1,3,3,on?PAL.ember:PAL.chill);R(g,x,y,1,1,on?PAL.hot:PAL.ice);
        R(g,x,y-4,1,2,on?PAL.ember:PAL.cold);if(pulse)R(g,x,y-5,1,1,PAL.hot);
      });
      // drill
      if(drillA){
        const u=(now-drillA.t)/520,x=ccx(drillA.x),y=ccy(drillA.y);
        if(u<1){
          const dy=Math.round(-14*(1-Math.min(1,u/.5))),sh=u>.5?(((now/40)|0)%2?1:-1):0,yy=y+dy;
          R(g,x-3+sh,yy-13,7,1,'#000');R(g,x-3+sh,yy-12,7,2,PAL.ember);R(g,x-3+sh,yy-12,7,1,PAL.hot);
          R(g,x-2+sh,yy-10,5,6,'#000');R(g,x-1+sh,yy-10,3,6,PAL.cold);R(g,x-1+sh,yy-10,1,6,PAL.ice);
          const sp=((now/50)|0)%2;
          R(g,x-1+sh,yy-4,3,2,PAL.chill);R(g,x-1+sh+sp*2,yy-4,1,1,PAL.cold);R(g,x+sh,yy-2,1,2,PAL.ice);R(g,x+sh,yy-3+sp,1,1,PAL.cold);
          if(u>.5&&!drillA.dust){drillA.dust=1;for(let k=0;k<7;k++){const a=-Math.PI*(.05+.9*k/6);parts.push({x,y,vx:Math.cos(a)*(4+hr()*4),vy:Math.sin(a)*(3+hr()*3),t:now,life:420,c:k%2?SOIL[5]:SOIL[4]})}}
        }
      }
      for(const q of gems){const u=Math.min(1,(now-q.t)/650),x=ccx(q.d.x),y=ccy(q.d.y)-Math.round(Math.sin(Math.PI*u)*12*(1-u*.3));
        if(u<1&&u>.1)circ(g,ccx(q.d.x),ccy(q.d.y),Math.round(2+u*6),TC[q.d.t],.6*(1-u));
        gemSprite(g,x,y,q.d.t)}
      if(endGhost)for(const q of S.deps)if(!q.got){const x=ccx(q.x),y=ccy(q.y),c=TC[q.t];circ(g,x,y,3,c,.6);R(g,x,y,1,1,c)}
      for(let k=parts.length-1;k>=0;k--){const q=parts[k],u=(now-q.t)/q.life;if(u>=1){parts.splice(k,1);continue}R(g,Math.round(q.x+q.vx*u),Math.round(q.y+q.vy*u+8*u*u),1,1,q.c)}
      // hover cursor on the field
      if(hoverCell&&!over&&!busy){const x=FX+hoverCell.x*CP,y=FY+hoverCell.y*CP,c=tool==='scan'?PAL.tractor:PAL.ember;
        R(g,x,y,2,1,c);R(g,x,y,1,2,c);R(g,x+CP-2,y,2,1,c);R(g,x+CP-1,y,1,2,c);R(g,x,y+CP-1,2,1,c);R(g,x,y+CP-2,1,2,c);R(g,x+CP-2,y+CP-1,2,1,c);R(g,x+CP-1,y+CP-2,1,2,c)}
      g.restore();
      // the graph
      const gp=sweep?sweep.p:cs;
      if(gp){
        const live=sweep&&sweep.p===gp;
        const sp=spikesOf(gp,live?(sweep.end?null:Math.max(0,(now-sweep.t0-250)/sweep.dur*S.range)):null);
        for(const s of sp){
          const f=live?sweep.flash.find(q=>q.e===s.e):null,age=f?Math.min(1,(now-f.t)/180):1;
          const h=Math.max(1,Math.round(s.h*(age<1?age*1.15:1))),c=TC[s.e.t],ol=mix(c,'#000000',.6),hi=mix(c,'#ffffff',.45);
          const lit=!!hoverSpike&&hoverSpike.i===s.e.i;
          for(let j=0;j<h;j++){const w=Math.round(2*(j/h));const y=GB-h+j;R(g,s.x-w,y,w*2+1,1,lit?hi:c);R(g,s.x-w-1,y,1,1,ol);R(g,s.x+w+1,y,1,1,ol);if(j<h*.6)R(g,s.x-w,y,1,1,hi)}
          R(g,s.x,GB-h-1,1,1,lit?'#ffffff':ol);
        }
        if(!sp.length&&(!live||sweep.end))TK.text(g,'QUIET',(X0+X1)>>1,GT+9,PAL.cold,'center');
        const k=scans.indexOf(gp);if(k>=0)TK.text(g,'#'+(k+1),FX+FW-2,GT,peek>=0?PAL.hot:PAL.chill,'right');
      }
      if(!touched&&!scans.length&&now-t00<6000)card(g,FX+4,FY+(FW>>1)-9,FW-8,'SCAN, THEN DIG.',(now-t00)/1000);
      if(msg){const w=msg.length*4+7;R(g,(W-w)>>1,FY+FW-12,w,9,PAL.bevelLo);TK.text(g,msg,W>>1,FY+FW-10,msgCol,'center')}
    }
    function endSweep(){
      if(!sweep)return;const p=sweep.p;sweep=null;busy=false;sel=scans.indexOf(p);
      if(!p.out.length)tone(140,.2,'sine',.03);
      if(scansLeft<=0&&tool==='scan'){tool='dig';tone(330,.1,'square',.03,500)}
    }
    function scan(x,y,now){
      if(over||busy||scansLeft<=0)return;
      busy=true;scansLeft--;msg='';peek=-1;hoverSpike=null;
      const p={x,y,out:scanAt(S,x,y)};scans.push(p);sel=scans.length-1;
      sweep={p,t0:now,dur:900*S.range/4.5,heard:new Set(),flash:[],end:false};
      TK.sfx('seismic2','scan');tone(520,.35,'sine',.04,1400);
    }
    function dig(x,y,now){
      if(over||busy||digsLeft<=0||holes.some(h=>h.x===x&&h.y===y))return;
      busy=true;digsLeft--;msg='';
      drillA={x,y,t:now};TK.sfx('seismic2','dig');tone(110,.4,'sawtooth',.035,45);
      later(()=>{
        if(over)return;drillA=null;busy=false;
        const q=nearFind(S,x,y,1),near=q?null:nearFind(S,x,y,2);
        holes.push({x,y,hit:!!q,close:!!near});
        if(q){q.got=true;TK.sfx('seismic2','ore');gems.push({d:q,t:performance.now()});msg=TN[q.t];msgCol=TC[q.t];tone(520,.18,'triangle',.06,880);later(()=>tone(880+q.t*120,.3,'sine',.05),120)}
        else if(near){msg='CLOSE';msgCol=PAL.hot;closeT=performance.now();tone(300,.2,'square',.03,420)}
        else{msg='EMPTY';msgCol=PAL.cold;tone(90,.25,'square',.03,60)}
        if(S.deps.every(q=>q.got))later(()=>{TK.sfx('seismic2','win');finish('ALL DUG')},500);
        else if(digsLeft<=0)later(()=>finish('NO DIGS LEFT'),500);
      },520);
    }
    function cellAt(q){if(q.x>=FX&&q.x<FX+FW&&q.y>=FY&&q.y<FY+FW)return{x:Math.floor((q.x-FX)/CP),y:Math.floor((q.y-FY)/CP)};return null}
    function spikeAt(q){
      const cs=curScan()>=0?scans[curScan()]:null;if(!cs||q.y<GY-2||q.y>GB+2)return null;
      let best=null,bd=4;for(const s of spikesOf(cs)){const d=Math.abs(s.x-q.x);if(d<bd){bd=d;best=s.e}}return best;
    }
    function onDown(e){
      e.preventDefault();if(over)return;touched=true;
      const q=P.pt(e),now=performance.now();
      if(q.y<=13){for(const tb of TB)if(q.x>=tb.x&&q.x<tb.x+tb.w&&tool!==tb.id){tool=tb.id;tone(tb.id==='scan'?600:240,.08,'square',.03)}return}
      const c=cellAt(q);
      if(c){
        // phone: press and slide to preview (the hover cursor, scan reach and old-scan peek), lift to act
        if(e.pointerType!=='mouse'){touchPend=e.pointerId;try{P.cv.setPointerCapture(e.pointerId)}catch(_){}hoverAt(q);return}
        act(c,now);
        return;
      }
      const sp=spikeAt(q);if(sp){hoverSpike=hoverSpike&&hoverSpike.i===sp.i?null:sp;tone(400+sp.t*80,.08,'sine',.03)}
    }
    function act(c,now){
        const k=scans.findIndex(p=>p.x===c.x&&p.y===c.y);
        if(k>=0&&(tool==='scan'||sel!==k)){sel=k;peek=-1;hoverSpike=null;tone(700,.06,'sine',.03);return}
        if(tool==='scan'){if(scansLeft>0)scan(c.x,c.y,now);else tool='dig'}
        else dig(c.x,c.y,now);
    }
    let touchPend=null;
    function hoverAt(q){
      const c=cellAt(q);hoverCell=c;
      const k=c?scans.findIndex(p=>p.x===c.x&&p.y===c.y):-1;
      peek=k===sel?-1:k;
      if(!c)hoverSpike=spikeAt(q)||null;
    }
    function onMove(e){
      if(e.pointerType!=='mouse'){if(touchPend!==e.pointerId)return;e.preventDefault();hoverAt(P.pt(e));return}
      hoverAt(P.pt(e));
    }
    function onUp(e){
      if(touchPend===null||touchPend!==e.pointerId)return;touchPend=null;
      const q=P.pt(e),c=e.type==='pointerup'?cellAt(q):null;hoverCell=null;peek=-1;
      if(c&&!over)act(c,performance.now());
    }
    P.cv.addEventListener('pointerdown',onDown);
    P.cv.addEventListener('pointermove',onMove);
    P.cv.addEventListener('pointerup',onUp);
    P.cv.addEventListener('pointercancel',onUp);
    P.cv.addEventListener('pointerleave',e=>{if(e.pointerType==='mouse'){hoverCell=null;peek=-1}});
    function finish(why){
      if(over)return;over=true;endGhost=true;msg=why;msgCol=PAL.hot;busy=false;
      const got=S.deps.filter(q=>q.got);
      ctx.done({score:score(S,scansLeft+digsLeft),detail:got.length+' of '+S.deps.length+' finds dug · '+scans.length+' scans'});
    }
    let raf=0,last=0,alive=true;
    const loop=now=>{if(!alive)return;raf=requestAnimationFrame(loop);if(now-last<32)return;last=now;render(now)};
    raf=requestAnimationFrame(loop);render(performance.now());
    return {
      _p:S,get _scans(){return scans.length},get _hoverCell(){return hoverCell},_cell:(x,y)=>({x:ccx(x),y:ccy(y)}),_tool:(id)=>{const t=TB.find(t=>t.id===id);return{x:t.x+(t.w>>1),y:6}},get _busy(){return busy},
      destroy(){alive=false;over=true;cancelAnimationFrame(raf);timers.forEach(clearTimeout);P.destroy();try{AC&&AC.close()}catch(e){}},
      giveUp(){if(over)return;timers.forEach(clearTimeout);sweep=null;drillA=null;finish('STOPPED')},
    };
  },
});
})();
