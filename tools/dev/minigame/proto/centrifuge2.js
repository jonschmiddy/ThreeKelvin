// Centrifuge 2: the round-1 rules, drawn as pixel art at the ship's science terminal.
// Load every tube so the rotor's centre of mass sits on the hub, then spin.
(function(){
'use strict';
const ID='centrifuge2';

// ---------- logic (verbatim from centrifuge.js) ----------
const CFG=[null,
  {Ns:[12],tubes:[5,7],masses:[1,1],overlap:false,blocked:0,uneven:false},
  {Ns:[12],tubes:[4,6],masses:[1,2],overlap:true,blocked:0,uneven:true},
  {Ns:[12,10],tubes:[5,7],masses:[1,2],overlap:true,blocked:2,uneven:true},
  {Ns:[15],tubes:[5,7],masses:[1,2],overlap:true,blocked:2,uneven:true},
  {Ns:[15,18],tubes:[6,8],masses:[1,3],overlap:true,blocked:3,uneven:true}];

function vec(N,slots){let x=0,y=0,m=0;for(let i=0;i<N;i++)if(slots[i]){const a=2*Math.PI*i/N-Math.PI/2;x+=slots[i]*Math.cos(a);y+=slots[i]*Math.sin(a);m+=slots[i]}return{x,y,m}}
function imbalance(N,slots){const v=vec(N,slots);return v.m?Math.hypot(v.x,v.y)/v.m:0}
function gen(rng,depth){
  const c=CFG[depth];
  for(let t=0;t<2000;t++){
    const N=c.Ns[Math.floor(rng()*c.Ns.length)];
    const ks=[];for(let k=2;k<N;k++)if(N%k===0&&k<=6)ks.push(k);
    const slots=new Array(N).fill(0);let clash=false;
    const np=2+Math.floor(rng()*2);
    for(let p=0;p<np;p++){
      const k=ks[Math.floor(rng()*ks.length)],o=Math.floor(rng()*N),m=c.masses[0]+Math.floor(rng()*(c.masses[1]-c.masses[0]+1));
      for(let j=0;j<k;j++){const s=(o+j*N/k)%N;if(slots[s])clash=true;slots[s]+=m}
    }
    if(clash!==c.overlap)continue;
    const tubes=slots.filter(Boolean);
    if(tubes.length<c.tubes[0]||tubes.length>c.tubes[1])continue;
    if(Math.max(...tubes)>4)continue;
    if(!c.uneven&&tubes.length%2===0)continue;
    if(c.uneven&&new Set(tubes).size<2)continue;
    if(c.uneven&&[...new Set(tubes)].every(m=>imbalance(N,slots.map(v=>v===m?v:0))<1e-9))continue;
    if(imbalance(N,slots)>1e-9)continue;
    const free=[...Array(N).keys()].filter(i=>!slots[i]);
    if(free.length<c.blocked+1)continue;
    for(let i=free.length-1;i>0;i--){const j=Math.floor(rng()*(i+1));[free[i],free[j]]=[free[j],free[i]]}
    const blocked=free.slice(0,c.blocked);
    return {N,sol:slots,tubes:tubes.slice().sort((a,b)=>b-a),blocked};
  }
  throw new Error('centrifuge2: no puzzle');
}
function score(r,moves,nTubes){
  if(r>0.3)return 0.1;
  const base=r<1e-6?1:Math.max(0.15,0.85-r*2.5);
  return Math.max(0.1,base-Math.min(0.2,0.03*Math.max(0,moves-nTubes)));
}
const logic={gen,imbalance,score,vec,CFG};
if(typeof TK==='undefined'){if(typeof module!=='undefined'&&module.exports)module.exports=logic;return}

// ---------- view ----------
const W=144,H=118;
const CX=50,CY=58;          // rotor hub
const RB=50,RR=44,RS=32,HUB=14; // bowl, rotor, slot ring, hub window radii
const RACK={x:101,y:9,w:42,h:74},SPIN={x:103,y:87,w:38,h:15};

function mount(stage,ctx){
  const P=gen(ctx.rng,ctx.depth),N=P.N,s=ctx.sensors|0;
  const PAL=TK.PAL;
  const slots=new Array(N).fill(0);const blocked=new Set(P.blocked);
  let tray=P.tubes.slice();let sel=0,moves=0,over=false,spinning=false;const timers=[];let raf=0;
  const fixed=new Set();
  if(s>=3){const m=P.tubes[0];const at=P.sol.findIndex(v=>v===m);slots[at]=m;fixed.add(at);tray.splice(0,1)}
  const nPlace=tray.length;
  const quant=[0.09,0.065,0.045,0.03,0.015,0][Math.min(5,s)];
  const halo=[4,3,3,2,1,0][Math.min(5,s)]; // a blurrier dot at low sensors
  const HR=N>15?4:5; // slot hole radius

  const p=TK.pixel(stage,{w:W,h:H});const g=p.g;
  const LIQ=[null,PAL.tractor,PAL.hot,PAL.flare,PAL.bad];
  const LIQD=[null,'#2f8f84','#b8923f','#b86a24','#7f3328'];

  // ---- static art, drawn once ----
  const mk=()=>{const c=document.createElement('canvas');c.width=W;c.height=H;const x=c.getContext('2d');x.imageSmoothingEnabled=false;return[c,x]};
  const pix=(x,X,Y,c)=>{x.fillStyle=c;x.fillRect(X,Y,1,1)};
  const chk=(X,Y,t)=>{const M=[0,2,3,1];return (M[(Y&1)*2+(X&1)]+.5)/4<t};
  // housing: bowl with a lit rim and bolts
  const[hc,hx]=mk();
  for(let y=CY-RB-1;y<=CY+RB+1;y++)for(let x=CX-RB-1;x<=CX+RB+1;x++){
    const dx=x-CX,dy=y-CY,d=Math.hypot(dx,dy);if(d>RB+.5)continue;
    const l=(-dx-dy)/(d||1)/1.414; // +1 top-left
    if(d>RB-.7)pix(hx,x,y,PAL.bevelLo);
    else if(d>RB-4){const t=.5+.5*l;pix(hx,x,y,t>.8?PAL.chill:t>.6?PAL.cold:t>.35?PAL.bevelHi:t>.15?PAL.line:PAL.bevelLo)}
    else if(d>RB-5)pix(hx,x,y,PAL.bevelLo);
    else pix(hx,x,y,chk(x,y,.3+.25*(-l))?'#05070b':PAL.bevelLo); // the dark well under the rotor
  }
  for(let k=0;k<8;k++){const a=k*Math.PI/4+Math.PI/8,bx=Math.round(CX+(RB-2)*Math.cos(a)),by=Math.round(CY+(RB-2)*Math.sin(a));
    pix(hx,bx,by,PAL.ice);pix(hx,bx+1,by+1,PAL.bevelLo)}
  // rotor body: brushed metal disc, rotationally symmetric so it never needs turning
  const[rc,rx]=mk();
  for(let y=CY-RR;y<=CY+RR;y++)for(let x=CX-RR;x<=CX+RR;x++){
    const dx=x-CX,dy=y-CY,d=Math.hypot(dx,dy);if(d>RR+.4||d<HUB+1.5)continue;
    const l=(-dx-dy)/(d||1)/1.414;
    let c;
    if(d>RR-.6)c=PAL.bevelLo;
    else if(d>RR-2)c=l>.3?PAL.ice:l>-.2?PAL.chill:PAL.cold;
    else if(Math.abs(d-(RS+HR+3))<.5)c=l>0?PAL.bevelHi:PAL.line;           // outer groove
    else if(Math.abs(d-(HUB+4))<.5)c=PAL.bevelLo;                         // inner groove
    else{const t=.45+.35*l+.08*Math.sin(d*1.7);c=chk(x,y,t)?PAL.cold:PAL.bevelHi}
    pix(rx,x,y,c);
  }
  // hub cap rim
  for(let y=CY-HUB-2;y<=CY+HUB+2;y++)for(let x=CX-HUB-2;x<=CX+HUB+2;x++){
    const dx=x-CX,dy=y-CY,d=Math.hypot(dx,dy);if(d>HUB+1.6||d<HUB-.4)continue;
    const l=(-dx-dy)/(d||1)/1.414;pix(rx,x,y,d>HUB+.6?(l>0?PAL.chill:PAL.line):(l>0?PAL.bevelLo:PAL.cold))}

  // ---- drawing helpers ----
  const fill=(x,y,w,h,c)=>{g.fillStyle=c;g.fillRect(x,y,w,h)};
  function disc(cx,cy,r,fn){for(let y=-r;y<=r;y++)for(let x=-r;x<=r;x++){const d2=x*x+y*y;if(d2<=r*r+r*.8){const c=fn(x,y,d2);if(c){g.fillStyle=c;g.fillRect(cx+x,cy+y,1,1)}}}}
  function digit(m,x,y,c){TK.text(g,String(m),x-1,y-2,c)}
  function slotXY(i,ang,ox,oy){const a=2*Math.PI*i/N-Math.PI/2+ang;return[Math.round(CX+ox+RS*Math.cos(a)),Math.round(CY+oy+RS*Math.sin(a))]}
  // a tube seen from above: glass rim, coloured liquid, a glint
  function tubeTop(cx,cy,m,isFixed){
    const r=HR;
    disc(cx,cy,r,(x,y,d2)=>{
      if(d2>(r-1)*(r-1)+(r-1)*.8)return isFixed?PAL.ice:PAL.bevelLo;
      const l=-(x+y);return l>2?LIQ[m]:l<-2?LIQD[m]:LIQ[m];
    });
    g.fillStyle=PAL.ice;g.fillRect(cx-2,cy-2,1,1);
    digit(m,cx,cy,PAL.void);
  }
  function hole(cx,cy,isBlocked){
    const r=HR;
    disc(cx,cy,r,(x,y,d2)=>{
      if(d2>(r-1)*(r-1)+(r-1)*.8)return (x+y)>0?PAL.chill:PAL.bevelLo; // rim lit bottom-right inside a hole
      return (x+y)<-1?'#05070b':PAL.bevelLo;
    });
    if(isBlocked){g.fillStyle=PAL.bad;for(let k=-2;k<=2;k++){g.fillRect(cx+k,cy+k,1,1);g.fillRect(cx+k,cy-k,1,1)}}
  }
  // a tube seen from the side, for the rack and the drag ghost
  function tubeSide(x,y,m,hot){
    const h=13;
    for(let j=0;j<h;j++){const bottom=j===h-1;
      for(let i=0;i<6;i++){
        if(bottom&&(i===0||i===5))continue;
        const edge=i===0||i===5||bottom||(j===h-2&&(i===0||i===5));
        let c;
        const lvl=h-1-j; // pixels up from the bottom
        if(edge)c=hot?PAL.flare:PAL.chill;
        else if(lvl<=m*3)c=i===1?PAL.ice:i>=4?LIQD[m]:LIQ[m];
        else c=i===1?PAL.bevelHi:PAL.void;
        g.fillStyle=c;g.fillRect(x+i,y+j,1,1);
      }
    }
    g.fillStyle=hot?PAL.flare:PAL.cold;g.fillRect(x-1,y,8,1); // lip
  }
  function cellRect(j){const col=j%2,row=(j/2)|0;return{x:RACK.x+2+col*20,y:RACK.y+9+row*16,w:19,h:15}}

  // ---- state for input + animation ----
  let pick=-1; // a rotor tube picked by a tap
  let ang=0,ox=0,oy=0,hox=0,hoy=0,drag=null,msgTxt='',msgCol=PAL.cold,press=0,acted=false;

  // the rotor as it would be with the tube in your hand dropped where it hovers (a live preview)
  function view(){
    if(!drag||!drag.moved)return slots;
    const v=slots.slice();if(drag.src==='slot')v[drag.i]=0;
    if(drag.over>=0&&!blocked.has(drag.over)&&!fixed.has(drag.over)&&!v[drag.over])v[drag.over]=drag.m;
    return v;
  }
  function indicator(){
    const v=vec(N,view());const tot=P.tubes.reduce((a,b)=>a+b,0);
    let dx=v.x/tot,dy=v.y/tot;
    if(quant>0){const r=Math.hypot(dx,dy),qr=Math.round(r/quant)*quant;const k=r?qr/r:0;dx*=k;dy*=k}
    const gain=33,len=Math.hypot(dx,dy)*gain,cl=len>HUB-3?(HUB-3)/len:1;
    return{x:Math.round(dx*gain*cl),y:Math.round(dy*gain*cl),centred:Math.hypot(dx,dy)<1e-9};
  }

  function render(){
    p.clear(PAL.void);
    // terminal backdrop: faint grid
    g.fillStyle=PAL.panel;for(let x=4;x<W;x+=8)g.fillRect(x,8,1,H-16);for(let y=12;y<H-8;y+=8)g.fillRect(0,y,W,1);
    g.drawImage(hc,hox,hoy);
    g.drawImage(rc,ox,oy);
    // slots and tubes ride the rotor
    const lifted=drag&&drag.moved&&drag.src==='slot'?drag.i:-1;
    for(let i=0;i<N;i++){
      const[x,y]=slotXY(i,ang,ox,oy);
      if(slots[i]&&i!==lifted)tubeTop(x,y,slots[i],fixed.has(i));else hole(x,y,blocked.has(i));
      const free=!blocked.has(i)&&!fixed.has(i)&&(!slots[i]||i===lifted);
      if(drag&&drag.moved&&!spinning&&free&&drag.over===i)disc(x,y,HR+1,(a,b,d2)=>d2>HR*HR?PAL.flare:null);
      if(pick===i&&!drag)disc(x,y,HR+1,(a,b,d2)=>d2>HR*HR&&((a+b)&1)?PAL.flare:null); // a picked tube: tap a free slot to move it
    }
    // hub window (fixed to the housing, so it reads during the spin)
    const hx0=CX+hox,hy0=CY+hoy;
    disc(hx0,hy0,HUB-1,(x,y,d2)=>chk(x+hx0,y+hy0,.15)?PAL.panel:PAL.void);
    g.fillStyle=PAL.line;g.fillRect(hx0-HUB+2,hy0,2*HUB-3,1);g.fillRect(hx0,hy0-HUB+2,1,2*HUB-3);
    const ind=indicator();
    const done=ind.centred&&view().filter(Boolean).length===P.tubes.length;
    // target ring at the very centre
    disc(hx0,hy0,3,(x,y,d2)=>d2>=5&&d2<=12?(done?PAL.good:PAL.bevelHi):null);
    const dx=hx0+ind.x,dy=hy0+ind.y;
    if(halo)disc(dx,dy,halo,(x,y,d2)=>{const t=1-Math.sqrt(d2)/(halo+1);return chk(dx+x,dy+y,t*.9)?PAL.flare:null});
    g.fillStyle=PAL.hot;g.fillRect(dx,dy,1,1);g.fillRect(dx-1,dy,1,1);g.fillRect(dx+1,dy,1,1);g.fillRect(dx,dy-1,1,1);g.fillRect(dx,dy+1,1,1);
    g.fillStyle=PAL.ice;g.fillRect(dx,dy,1,1);
    // HUD
    TK.text(g,'ROTOR '+N,2,1,PAL.cold);
    TK.text(g,'MOVES '+moves,W-2,1,PAL.chill,'right');
    // rack
    fill(RACK.x,RACK.y,RACK.w,RACK.h,PAL.bevelLo);fill(RACK.x+1,RACK.y+1,RACK.w-2,RACK.h-2,PAL.panel);
    fill(RACK.x+1,RACK.y+1,RACK.w-2,1,PAL.bevelHi);fill(RACK.x+1,RACK.y+1,1,RACK.h-2,PAL.line);
    TK.text(g,'RACK',RACK.x+RACK.w/2,RACK.y+3,PAL.cold,'center');
    if(!tray.length)TK.text(g,'EMPTY',RACK.x+RACK.w/2,RACK.y+30,PAL.line,'center');
    // a rotor tube held over the rack, or picked by a tap: the rack lights to take it back
    if((drag&&drag.moved&&drag.src==='slot'&&inR({x:drag.x,y:drag.y},RACK))||(pick>=0&&!drag)){const c=pick>=0&&!drag?PAL.ember:PAL.flare;fill(RACK.x,RACK.y,RACK.w,1,c);fill(RACK.x,RACK.y+RACK.h-1,RACK.w,1,c);fill(RACK.x,RACK.y,1,RACK.h,c);fill(RACK.x+RACK.w-1,RACK.y,1,RACK.h,c)}
    tray.forEach((m,j)=>{
      const r=cellRect(j);const on=j===sel;
      if(on){fill(r.x,r.y,r.w,r.h,PAL.ember);fill(r.x+1,r.y+1,r.w-2,r.h-2,'#2a1a0c')}
      if(drag&&drag.moved&&drag.src==='rack'&&drag.j===j)return; // the tube is in your hand
      tubeSide(r.x+3,r.y+1,m,on);
      TK.text(g,String(m),r.x+13,r.y+5,on?PAL.hot:PAL.chill);
    });
    // spin button
    const ready=!over&&!spinning&&!tray.length;
    const b=SPIN,pr=press>0?1:0;
    fill(b.x,b.y,b.w,b.h,PAL.bevelLo);
    if(ready){fill(b.x+1,b.y+1+pr,b.w-2,b.h-2-pr,PAL.ember);if(!pr)fill(b.x+1,b.y+1,b.w-2,1,PAL.flare);fill(b.x+1,b.y+b.h-2,b.w-2,1,'#8a4a14')}
    else{fill(b.x+1,b.y+1,b.w-2,b.h-2,PAL.panel);fill(b.x+1,b.y+1,b.w-2,1,PAL.line)}
    TK.text(g,'SPIN',b.x+b.w/2,b.y+5+pr,ready?PAL.void:PAL.line,'center');
    // message
    if(!acted&&!over){// start frame: the goal, and the inputs as icons
      const tt=(performance.now()-t0)/1000,hw=71,x0=Math.round((W-(22+5+hw))/2);
      fill(0,H-15,W,15,PAL.void);fill(0,H-15,W,1,PAL.line);
      TK.icon(g,'drag',x0,H-14,{t:tt});
      TK.text(g,'BALANCE THE TUBES.',x0+27,H-10,PAL.hot);
    }else TK.text(g,msgTxt,W/2,H-7,msgCol,'center');
    // a tube in your hand
    if(drag&&drag.moved)tubeSide(drag.x-3,drag.y-7,drag.m,true);
  }
  function setMsg(){
    if(over)return;
    if(!acted)return;
    if(tray.length){msgTxt='';msgCol=PAL.cold}
    else{msgTxt='READY';msgCol=PAL.ember}
  }
  function paint(){setMsg();render()}

  // ---- rules (same as round 1) ----
  // rack -> slot
  function place(j,i){
    if(over||spinning||blocked.has(i)||fixed.has(i)||slots[i]||tray[j]==null)return false;
    slots[i]=tray[j];tray.splice(j,1);moves++;TK.sfx('centrifuge2','seat');
    sel=tray.length?Math.min(j,tray.length-1):null;pick=-1;paint();return true;
  }
  // slot -> slot
  function shift(a,b){
    if(over||spinning||a===b||!slots[a]||fixed.has(a)||blocked.has(b)||fixed.has(b)||slots[b])return false;
    slots[b]=slots[a];slots[a]=0;moves++;TK.sfx('centrifuge2','seat');pick=-1;paint();return true;
  }
  // slot -> rack
  function unload(i){
    if(over||spinning||!slots[i]||fixed.has(i))return false;
    const m=slots[i];slots[i]=0;tray.push(m);tray.sort((x,y)=>y-x);sel=tray.indexOf(m);pick=-1;paint();return true;
  }
  // taps do the same jobs as drags: tap a tube (rack or rotor), then tap where it goes
  function tapSlot(i){
    if(over||spinning||blocked.has(i)||fixed.has(i))return;
    if(slots[i]){pick=pick===i?-1:i;paint();return}       // pick it up; a second tap sets it down again
    if(pick>=0){shift(pick,i);return}
    if(sel!=null&&tray[sel]!=null)place(sel,i);
  }
  function doSpin(){
    if(over||spinning||tray.length)return;
    TK.sfx('centrifuge2','spin');spinning=true;msgTxt='SPINNING';msgCol=PAL.chill;
    const r=imbalance(N,slots);
    const t0=performance.now(),dur=2200;let last=0,ph=0;
    const frame=now=>{
      if(over&&!spinning)return;
      const t=Math.min(1,(now-t0)/dur);
      if(now-last>=33||t>=1){
        last=now;
        const sp=t<0.25?t/0.25:t>0.8?(1-t)/0.2:1;
        ang+=sp*0.34;ph+=sp*1.9;
        // an off-centre load shakes the rotor; a whole pixel even for a small lean
        const amp=r>1e-6?Math.max(1,Math.min(6,r*30))*sp:0;
        ox=Math.round(amp*Math.cos(ph));oy=Math.round(amp*Math.sin(ph));
        hox=Math.round(ox/2);hoy=Math.round(oy/2);
        render();
      }
      if(t<1){raf=requestAnimationFrame(frame);return}
      ox=oy=hox=hoy=0;
      finish(r);
    };
    raf=requestAnimationFrame(frame);
  }
  function finish(r){
    over=true;spinning=false;
    const sc=score(r,moves,nPlace);
    const pct=Math.round(r*100);
    msgTxt=r<1e-6?'BALANCED. NO WOBBLE':r>0.3?'ROTOR FAULT':'WOBBLE '+pct+'%';
    msgCol=r<1e-6?PAL.good:r>0.3?PAL.bad:PAL.warn;if(r<1e-6)TK.sfx('centrifuge2','win');
    render();
    timers.push(setTimeout(()=>ctx.done({score:sc,detail:(r<1e-6?'balanced':pct+'% off')+', '+moves+' moves'}),700));
  }

  // ---- input ----
  const inR=(q,r)=>q.x>=r.x&&q.x<r.x+r.w&&q.y>=r.y&&q.y<r.y+r.h;
  function slotAt(q){let best=-1,bd=1e9;for(let i=0;i<N;i++){const[x,y]=slotXY(i,0,0,0);const d=Math.hypot(q.x-x,q.y-y);if(d<bd){bd=d;best=i}}return bd<=HR+2.5?best:-1}
  function rackAt(q){for(let j=0;j<tray.length;j++)if(inR(q,cellRect(j)))return j;return -1}
  const cv=p.cv;
  function down(e){
    if(over||spinning)return;e.preventDefault();
    const q=p.pt(e);acted=true;
    if(inR(q,SPIN)){if(!tray.length){press=1;render();timers.push(setTimeout(()=>{press=0;doSpin()},90))}return}
    if(pick>=0&&inR(q,RACK)){unload(pick);return}  // a picked rotor tube, then the rack: back it goes
    const j=rackAt(q);
    if(j>=0){try{cv.setPointerCapture(e.pointerId)}catch(_){}drag={id:e.pointerId,src:'rack',j,m:tray[j],x:q.x,y:q.y,x0:q.x,y0:q.y,moved:false,over:-1};render();return}
    const i=slotAt(q);
    if(i>=0&&slots[i]&&!fixed.has(i)){try{cv.setPointerCapture(e.pointerId)}catch(_){}drag={id:e.pointerId,src:'slot',i,m:slots[i],x:q.x,y:q.y,x0:q.x,y0:q.y,moved:false,over:-1};render();return}
    if(i>=0)tapSlot(i);
  }
  function move(e){
    if(!drag||e.pointerId!==drag.id)return;e.preventDefault();
    const q=p.pt(e);drag.x=q.x;drag.y=q.y;
    if(!drag.moved&&Math.hypot(q.x-drag.x0,q.y-drag.y0)>2){drag.moved=true;pick=-1}
    drag.over=slotAt(q);render();
  }
  const offRotor=q=>Math.hypot(q.x-CX,q.y-CY)>RR+2;
  function up(e){
    if(!drag||e.pointerId!==drag.id)return;
    const d=drag;drag=null;const q=p.pt(e);
    if(e.type!=='pointerup'){paint();return}
    if(!d.moved){ // a tap
      if(d.src==='rack'){sel=d.j;pick=-1;paint()}else tapSlot(d.i);
      return}
    const i=slotAt(q);
    if(d.src==='rack'){if(i>=0&&place(d.j,i))return;sel=d.j;paint();return}
    if(i>=0&&i!==d.i&&shift(d.i,i))return;
    if(i<0&&offRotor(q)){unload(d.i);return}  // dragged off the rotor: back to the rack
    paint();                                  // dropped on the rotor but not in a free slot: it stays put
  }
  cv.addEventListener('pointerdown',down);cv.addEventListener('pointermove',move);
  cv.addEventListener('pointerup',up);cv.addEventListener('pointercancel',up);
  cv.style.cursor='pointer';
  const t0=performance.now();const iconTimer=setInterval(()=>{if(acted||over){clearInterval(iconTimer);if(!spinning)render();return}if(!drag)render()},66);timers.push(iconTimer);
  paint();

  return {
    destroy(){over=true;spinning=false;cancelAnimationFrame(raf);timers.forEach(clearTimeout);
      cv.removeEventListener('pointerdown',down);cv.removeEventListener('pointermove',move);cv.removeEventListener('pointerup',up);cv.removeEventListener('pointercancel',up);p.destroy()},
    giveUp(){if(over)return;over=true;spinning=false;cancelAnimationFrame(raf);ox=oy=hox=hoy=0;msgTxt='GAVE UP';msgCol=PAL.cold;render();ctx.done({score:0,detail:'Gave up'})},
    _test:{get pick(){return pick},indicator,get slots(){return slots.slice()},get tray(){return tray.slice()},get over(){return over},P,slotXY:i=>slotXY(i,0,0,0),cellRect,SPIN,p},
  };
}

TK.register({
  id:ID,name:'Centrifuge 2',where:'Gas giants, labs',skill:'Spatial maths',
  blurb:'Balance a rotor before you spin it.',
  hint:'Balance the tubes.',
  controls:['drag'],
  how:[
    'Drag tubes from the RACK into slots, and from slot to slot. Or tap a tube, then where it goes.',
    'More liquid, heavier tube. The dot in the hub leans to the heavy side. Hold a tube over a slot to see where the dot would go.',
    'Get the dot to the centre ring, then press SPIN. A lean makes it shake.',
    'Drag a tube off the rotor to put it back in the rack.',
  ],
  deeper:'Sector 2+: tubes of different weights. Sector 3+: blocked slots. Sector 4+: 15 slots, an odd count. Sector 5: heavier tubes.',
  sensors:'The centre dot gets sharper with each point. 3+: the heaviest tube starts in a right slot.',
  mount,
  _t:logic,
});
})();
