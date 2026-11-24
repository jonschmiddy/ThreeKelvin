// FLICK (comet H): the comet is breaking up as it nears the sun. Chunks crumble off its nucleus (top) and
// drift down at your ship (bottom), whose cargo bay stands open in the middle (blue). Ice (pale, white-blue)
// is the haul: it counts when it goes into the bay. Rock (dark, red rim) must not hit the ship: a rock on the
// hull or in the bay spills ice out of the hold. Grab any chunk and throw it: it hangs off the pointer on a
// spring and keeps its speed when you let go. Flick the rocks away; steer stray ice into the bay. Chunks knock
// each other, so a thrown rock can clear another.
//
// Control: press on a chunk to grab it, move to swing it, let go to throw. Rocks are heavier (they lag more).
// Score: ice in the bay against what the comet sent (a share of it fills the hold); every rock that hits
// spills some. Depth: more chunks, faster, more rocks, a narrower bay, less time. Sensors: slower chunks, a
// wider bay; 2+ a red dotted path on each rock headed for the ship.
(function(){
'use strict';
const ID='comet_h',W=150,H=140,DT=1/60;
function mulberry(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
const BAY=[0,2,3,1],on=(x,y,d)=>(BAY[(y&1)*2+(x&1)]+.5)/4<d;
const hash=(a,b)=>{let h=Math.imul(a|0,374761393)+Math.imul(b|0,668265263);h=Math.imul(h^h>>>13,1274126177);return((h^h>>>16)>>>0)/4294967296};
function mount(stage,ctx){
  const KIT=TK.KIT,P=TK.PAL,px=TK.pixel(stage,{w:W,h:H}),g=px.g,pop=KIT.popups(ctx),r=ctx.rng;
  const D=ctx.depth,S=ctx.sensors,PY=KIT.ROW.PLAY.y;
  const now=()=>performance.now()/1000;
  // ---- tuning ----
  const T=[12.5,11.5,10.5,10,9.5][D-1];          // the run
  const SPAWN_END=T-4.2;                         // the last chunk leaves the comet then
  const N=[10,12,14,16,18][D-1];                 // chunks
  const RS=[.3,.35,.4,.45,.5][D-1];              // the share that is rock
  const SPD=[19,21,23,25,27][D-1]*(1-.04*S);     // drift speed, px/s
  const HULL=121;                                // the hull's top row
  const BW=[46,42,38,34,30][D-1]+2*S,BX0=Math.round(75-BW/2),BX1=BX0+BW; // the bay
  const LOSS=2;                                  // ice spilled by a rock hit
  const NC={x:75,y:22};                          // the nucleus
  // ---- the chunks the comet will shed, all from the seed ----
  const plan=[];{const nRock=Math.round(N*RS),kinds=TK.shuffle(Array.from({length:N},(_,i)=>i<nRock?'rock':'ice'),r);
    if(kinds[0]==='rock'){const j=kinds.indexOf('ice');kinds[0]='ice';kinds[j]='rock'}  // the first one is ice: catch one before you meet a rock
    for(let i=0;i<N;i++){const at=.25+(SPAWN_END-.25)*(i/(N-1))+(r()-.5)*.5*(SPAWN_END/N),kind=kinds[i],big=kind==='ice'&&r()<.22;
      const inBay=r()<(kind==='rock'?.55:.45);
      let xi=inBay?BX0+4+r()*(BW-8):(r()<.5?6+r()*(BX0-12):BX1+6+r()*(W-BX1-12));
      plan.push({at:Math.max(.2,at),kind,big,xi,sp:SPD*(.85+.3*r()),rad:kind==='rock'?3+Math.floor(r()*3):big?5:3+Math.floor(r()*2),ph:r()*6.28,ph2:r()*6.28,spin:(r()-.5)*4})}
    plan.sort((a,b)=>a.at-b.at)}
  const totalIce=plan.reduce((a,c)=>a+(c.kind==='ice'?(c.big?2:1):0),0);
  const TARGET=Math.max(3,Math.round(totalIce*[.85,.8,.78,.75,.72][D-1]));
  const nz=mulberry((ctx.seed^0x3c5)>>>0);
  // ---- state ----
  const chunks=[],bits=[],sparks=[];
  let started=false,over=false,t=0,endT=null,acc=0,last=now(),t0=last,raf=0,pi=0,ice=0,hits=0,held=null,flashBay=0,flashHull=0,said={},uid=0;
  const ptr={x:-1,y:-1,vx:0,vy:0};
  // background: stars, the sun's glow in the top-left corner
  const bg=document.createElement('canvas');bg.width=W;bg.height=H;{const b=bg.getContext('2d');b.fillStyle=P.void;b.fillRect(0,0,W,H);
    const sun={x:-40,y:-10};
    for(let y=PY;y<70;y++)for(let x=0;x<60;x++){const d=Math.hypot(x-sun.x,y-sun.y);
      if(d<50){b.fillStyle=on(x,y,(50-d)/4)?P.warn:'#5a4320';b.fillRect(x,y,1,1)}
      else if(d<58){b.fillStyle=on(x,y,(58-d)/8)?'#5a4320':'#2a2216';b.fillRect(x,y,1,1)}
      else if(d<68&&on(x,y,(68-d)/10*.6)){b.fillStyle='#2a2216';b.fillRect(x,y,1,1)}}
    const sr=mulberry(ctx.seed^0x9e37);for(let i=0;i<55;i++){const x=Math.floor(sr()*W),y=PY+Math.floor(sr()*(HULL-PY));if(Math.hypot(x+40,y+10)<62)continue;b.fillStyle=sr()<.2?P.cold:P.line;b.fillRect(x,y,1,1)}}
  const mass=c=>(c.kind==='rock'?2.2:1)*c.r*c.r/9;
  function spawn(p){const dx=p.xi-NC.x,dy=HULL-NC.y,d=Math.hypot(dx,dy),ux=dx/d,uy=dy/d;
    chunks.push({id:++uid,kind:p.kind,big:p.big,r:p.rad,x:NC.x+ux*11,y:NC.y+uy*11,vx:ux*p.sp,vy:uy*p.sp,ang:0,spin:p.spin,ph:p.ph,ph2:p.ph2,age:0});
    for(let i=0;i<4;i++)bits.push({x:NC.x+ux*11,y:NC.y+uy*11,vx:ux*8+(nz()-.5)*10,vy:uy*8+(nz()-.5)*10,age:0,c:P.cold})}
  function burst(x,y,n,cols,sp){for(let i=0;i<n;i++){const a=nz()*6.28,s=(sp||14)*(.4+nz()*.8);bits.push({x,y,vx:Math.cos(a)*s,vy:Math.sin(a)*s-6,age:0,c:cols[i%cols.length]})}}
  function hit(c,inBay){hits++;const lost=Math.min(ice,LOSS);ice-=lost;flashHull=.5;if(inBay)flashBay=.5;TK.sfx(ID,'hit');
    pop.say(inBay?'ROCK IN THE HOLD':'HULL HIT','bad',now());burst(c.x,HULL-1,10,[P.bad,P.cold,'#5a2a22'],20);
    for(let i=0;i<lost*3;i++){const a=-Math.PI/2+(nz()-.5)*1.6,s=20+nz()*25;bits.push({x:75+(nz()-.5)*BW*.6,y:HULL+4,vx:Math.cos(a)*s,vy:Math.sin(a)*s,age:0,c:P.ice})}}
  function sim(){
    if(!started||over)return;
    t+=DT;flashBay=Math.max(0,flashBay-DT);flashHull=Math.max(0,flashHull-DT);
    while(pi<plan.length&&t>=plan[pi].at)spawn(plan[pi++]);
    // the held chunk hangs off the pointer on a spring: heavier rock lags more
    for(const c of chunks){c.age+=DT;c.ang+=c.spin*DT;
      if(c===held){const m=mass(c),k=520/m,dmp=2*.75*Math.sqrt(k);c.vx+=((ptr.x-c.x)*k-c.vx*dmp)*DT;c.vy+=((ptr.y-c.y)*k-c.vy*dmp)*DT;
        const sp=Math.hypot(c.vx,c.vy);if(sp>170){c.vx*=170/sp;c.vy*=170/sp}c.spin=c.vx*.08}
      c.x+=c.vx*DT;c.y+=c.vy*DT}
    // chunks knock each other (the held one counts as heavy: you can bat with it)
    for(let i=0;i<chunks.length;i++)for(let j=i+1;j<chunks.length;j++){const a=chunks[i],b=chunks[j],dx=b.x-a.x,dy=b.y-a.y,d=Math.hypot(dx,dy),m=a.r+b.r-.5;
      if(d>=m||d===0)continue;const nx=dx/d,ny=dy/d,ma=mass(a)*(a===held?5:1),mb=mass(b)*(b===held?5:1),ov=m-d;
      a.x-=nx*ov*mb/(ma+mb);a.y-=ny*ov*mb/(ma+mb);b.x+=nx*ov*ma/(ma+mb);b.y+=ny*ov*ma/(ma+mb);
      const rv=(b.vx-a.vx)*nx+(b.vy-a.vy)*ny;if(rv>=0)continue;const jj=-(1.8)*rv/(1/ma+1/mb);
      a.vx-=jj/ma*nx;a.vy-=jj/ma*ny;b.vx+=jj/mb*nx;b.vy+=jj/mb*ny;if(Math.abs(rv)>12)TK.sfx(ID,'knock')}
    // the ship and the edges
    for(let i=chunks.length-1;i>=0;i--){const c=chunks[i];
      if(c.y+c.r>=HULL&&c.vy>=0||c.y+c.r>=HULL+2){const inBay=c.x>BX0+1&&c.x<BX1-1;
        if(c.kind==='rock')hit(c,inBay);
        else if(inBay){const v=c.big?2:1;ice+=v;flashBay=.25;TK.sfx(ID,'bank');for(let k=0;k<5;k++)sparks.push({x:Math.round(c.x+(nz()-.5)*6),y:HULL-1-Math.floor(nz()*4),age:0})}
        else{burst(c.x,HULL-1,8,[P.ice,P.chill,P.cold],12);TK.sfx(ID,'miss');if(!said.miss){said.miss=1;pop.say('ICE LOST','neutral',now())}}
        if(c===held)held=null;chunks.splice(i,1);continue}
      if(c.x<-10||c.x>W+10||c.y<PY-12||c.y>H+10){if(c===held)held=null;chunks.splice(i,1)}}
    if(ice>=TARGET/2&&!said.half){said.half=1;pop.say('HALF FULL','goal',now())}
    if(t>=T||ice>=TARGET||(pi>=plan.length&&!chunks.length))end();
  }
  function score(){return Math.max(0,Math.min(1,ice/TARGET))}
  function end(){if(over)return;over=true;endT=t;held=null;const s=score();if(s>=.5)TK.sfx(ID,'win');
    pop.finish(s>=.93?'HOLD FULL':s>=.5?'GOOD HAUL':'THIN HAUL',s>=.93?'good':'neutral',now());
    ctx.done({score:s,detail:ice+' of '+TARGET+' ice, '+hits+' rock hits'})}
  // ---- drawing ----
  function drawChunk(c,n){const R=c.r+1,cx=Math.round(c.x),cy=Math.round(c.y),rock=c.kind==='rock';
    const rr=a=>c.r*(1+.16*Math.sin(3*(a-c.ang)+c.ph)+.09*Math.sin(5*(a-c.ang)+c.ph2));
    for(let y=-R-1;y<=R+1;y++)for(let x=-R-1;x<=R+1;x++){const d=Math.hypot(x,y),a=Math.atan2(y,x),e=rr(a);if(d>e+1)continue;const X=cx+x,Y=cy+y;if(Y<PY||Y>=H)continue;
      if(d>e){g.fillStyle=rock?P.bad:P.bevelLo;g.fillRect(X,Y,1,1);continue}
      const l=(-x-y)/(c.r*1.4),tex=hash(Math.round(x*Math.cos(c.ang)+y*Math.sin(c.ang))+c.id*7,Math.round(-x*Math.sin(c.ang)+y*Math.cos(c.ang)));
      let col;
      if(rock)col=l>.45?'#4a5a70':l>-.1?(tex<.2?P.line:P.bevelHi):l>-.6?P.line:'#18212d';
      else col=l>.5?(tex<.15?P.chill:'#ffffff'):l>.05?(tex<.2?P.chill:P.ice):l>-.5?P.chill:P.cold;
      if(rock&&d>e-1&&l<-.2)col='#5a2a22';
      g.fillStyle=col;g.fillRect(X,Y,1,1)}
    if(c===held){g.fillStyle=P.ember;const rr2=c.r+3,N2=Math.round(rr2*4);for(let k=0;k<N2;k+=2){const a=k/N2*6.283+n*3;g.fillRect(Math.round(c.x+Math.cos(a)*rr2),Math.round(c.y+Math.sin(a)*rr2),1,1)}}}
  function draw(){const n=now();
    g.drawImage(bg,0,0);
    // the coma round the breaking nucleus
    for(let y=PY;y<52;y++)for(let x=40;x<110;x++){const d=Math.hypot(x-NC.x,y-NC.y);if(d<30&&on(x,y,(30-d)/30*.35)){g.fillStyle=P.line;g.fillRect(x,y,1,1)}}
    // the nucleus: a lumpy rock with glowing cracks (it is coming apart)
    for(let y=-15;y<=15;y++)for(let x=-15;x<=15;x++){const X=NC.x+x,Y=NC.y+y;if(Y<PY)continue;const a=Math.atan2(y,x),d=Math.hypot(x,y),
        e=12+1.6*Math.sin(3*a+1.1)+1.1*Math.sin(5*a+.4)+(a>.3&&a<2.8?-.8:0);if(d>e+1)continue;
      if(d>e){g.fillStyle=P.bevelLo;g.fillRect(X,Y,1,1);continue}
      const l=(-x-y)/16,h=hash(x+50,y+50);let col=l>.45?'#4a5a70':l>0?P.bevelHi:l>-.45?P.line:'#18212d';if(h<.1)col=P.line;
      const crack=Math.abs(Math.sin(x*.7+y*1.3)*7+Math.sin(x*.3-y*.9)*5)<1.1&&d<e-1;
      if(crack)col=Math.floor(n*3+x)%5===0?P.flare:P.ember;
      g.fillStyle=col;g.fillRect(X,Y,1,1)}
    // the ship: hull plates across the bottom, the open bay (blue) in the middle
    const hullC=flashHull>0&&Math.floor(n*12)%2===0?P.bad:P.bevelHi;
    g.fillStyle=P.bevelLo;g.fillRect(0,HULL,W,H-HULL);
    g.fillStyle=P.line;g.fillRect(0,HULL+1,BX0-1,H-HULL-1);g.fillRect(BX1+2,HULL+1,W-BX1-2,H-HULL-1);
    g.fillStyle=hullC;g.fillRect(0,HULL,BX0-1,1);g.fillRect(BX1+2,HULL,W-BX1-2,1);
    g.fillStyle='#18212d';for(let x=8;x<W;x+=16){if(x>BX0-3&&x<BX1+3)continue;g.fillRect(x,HULL+2,1,H-HULL-2)}
    g.fillStyle='#18212d';g.fillRect(0,HULL+9,BX0-1,1);g.fillRect(BX1+2,HULL+9,W-BX1-2,1);
    {const blink=Math.floor(n*2)%2===0;g.fillStyle=blink?P.flare:P.ember;g.fillRect(4,HULL+4,2,2);g.fillRect(W-6,HULL+4,2,2)}  // running lights
    // the bay: dark well, blue rims and glow, the ice you have banked stacked in it
    g.fillStyle=P.void;g.fillRect(BX0,HULL,BW+1,H-HULL);
    const rim=flashBay>0&&Math.floor(n*12)%2===0?(hits&&flashHull>0?P.bad:P.ice):P.t2;
    g.fillStyle=rim;g.fillRect(BX0-1,HULL-2,1,H-HULL+2);g.fillRect(BX1+1,HULL-2,1,H-HULL+2);g.fillRect(BX0-3,HULL-2,3,1);g.fillRect(BX1+1,HULL-2,3,1);
    for(let x=BX0;x<=BX1;x++)if(on(x,HULL,.5)){g.fillStyle='#26364a';g.fillRect(x,HULL,1,1)}
    {const full=Math.min(1,ice/TARGET),rows=Math.round(full*(H-HULL-3)*(BW-1));let k=0;
      for(let y=H-2;y>HULL+1&&k<rows;y--)for(let x=BX0+1;x<BX1&&k<rows;x++,k++){g.fillStyle=hash(x,y)<.2?P.ice:hash(x+3,y)<.5?P.chill:P.cold;g.fillRect(x,y,1,1)}}
    // red marks where rocks will hit, and (sensors 2+) their paths
    if(started&&!over)for(const c of chunks){if(c.kind!=='rock'||c===held||c.vy<=1)continue;const tt=(HULL-c.r-c.y)/c.vy;if(tt>2.2)continue;
      const xh=c.x+c.vx*tt;if(xh<0||xh>=W)continue;const blink=Math.floor(n*8)%2===0;
      if(S>=2){g.fillStyle='#5a2a22';for(let k=4;k<tt*60;k+=6){const s=k/60,x=Math.round(c.x+c.vx*s),y=Math.round(c.y+c.vy*s);if(y>=PY&&y<HULL)g.fillRect(x,y,1,1)}}
      if(blink){g.fillStyle=P.bad;const x=Math.round(xh);g.fillRect(x-2,HULL-1,5,1);g.fillRect(x,HULL-3,1,2)}}
    for(const c of chunks)drawChunk(c,n);
    // the pointer's pull on a held chunk
    if(held){g.fillStyle='#8a4a16';const dx=ptr.x-held.x,dy=ptr.y-held.y,L=Math.hypot(dx,dy),st=Math.floor(L/2);for(let i=1;i<st;i++)g.fillRect(Math.round(held.x+dx*i/st),Math.round(held.y+dy*i/st),1,1)}
    for(let i=bits.length-1;i>=0;i--){const b=bits[i];b.age+=1/60;b.x+=b.vx/60;b.y+=b.vy/60;if(b.age>.7){bits.splice(i,1);continue}
      const x=Math.round(b.x),y=Math.round(b.y);if(y<PY||y>=H)continue;g.fillStyle=b.age>.45?P.cold:b.c;g.fillRect(x,y,1,1)}
    for(let i=sparks.length-1;i>=0;i--){const s=sparks[i];s.age+=1/60;if(s.age>.3){sparks.splice(i,1);continue}
      const a=s.age<.1?1:s.age<.2?2:3;g.fillStyle=a===1?'#ffffff':a===2?P.ice:P.chill;g.fillRect(s.x,s.y,1,1);
      if(a<3){g.fillRect(s.x-a,s.y,1,1);g.fillRect(s.x+a,s.y,1,1);g.fillRect(s.x,s.y-a,1,1)}}
    const left=Math.max(0,T-(over&&endT!=null?endT:t));
    KIT.header(g,{label:'ICE',meter:{w:57,frac:ice/TARGET,kind:'goal'},value:Math.round(Math.min(1,ice/TARGET)*100)+'%'},[['TIME',Math.ceil(started?left:T)]]);
    KIT.tell(g,'ICE IN. ROCKS OUT.',['drag'],n-t0);
    pop.draw(g,n);
  }
  function step(){const n=now();acc+=Math.min(.1,n-last);last=n;
    while(acc>=DT){acc-=DT;sim()}
    draw();raf=requestAnimationFrame(step)}
  const onMove=e=>{const p=px.pt(e);ptr.x=p.x;ptr.y=p.y};
  const onDown=e=>{if(pop.click(now()))return;if(over)return;onMove(e);
    if(!started){started=true}
    let best=null,bd=1e9;for(const c of chunks){const d=Math.hypot(c.x-ptr.x,c.y-ptr.y);if(d<c.r+5&&d<bd){bd=d;best=c}}
    if(best){held=best;TK.sfx(ID,'grab')}
    try{px.cv.setPointerCapture(e.pointerId)}catch(_){}};
  const onUp=()=>{if(held){const sp=Math.hypot(held.vx,held.vy);if(sp>40)TK.sfx(ID,'throw')}held=null};
  px.cv.addEventListener('pointermove',onMove);px.cv.addEventListener('pointerdown',onDown);
  window.addEventListener('pointerup',onUp);window.addEventListener('pointercancel',onUp);
  raf=requestAnimationFrame(step);
  // ---- the film's bot: grab the most urgent rock and fling it off the side; steer stray ice into the bay ----
  let job=null;
  const impactX=c=>c.vy>1?c.x+c.vx*(HULL-c.r-c.y)/c.vy:null,eta=c=>c.vy>1?(HULL-c.r-c.y)/c.vy:99;
  function pickJob(){let best=null,bs=1e9;
    for(const c of chunks){const xi=impactX(c);if(xi==null||xi<-4||xi>W+4)continue;const e=eta(c);if(e<.25)continue;
      const inBay=xi>BX0+2&&xi<BX1-2;let need=c.kind==='rock'||!inBay;if(!need)continue;
      const reach=Math.hypot(c.x-(ptr.x<0?75:ptr.x),c.y-(ptr.y<0?80:ptr.y))/6/60;const sc=e-(c.kind==='rock'?.6:0)+reach*.5;
      if(e<reach+.15)continue;if(sc<bs){bs=sc;best=c}}
    return best}
  return{
    destroy(){over=true;cancelAnimationFrame(raf);px.cv.removeEventListener('pointermove',onMove);px.cv.removeEventListener('pointerdown',onDown);
      window.removeEventListener('pointerup',onUp);window.removeEventListener('pointercancel',onUp);px.destroy()},
    giveUp(){if(over)return;over=true;held=null;ctx.done({score:.3*score(),detail:'Gave up at '+ice+' of '+TARGET+' ice'})},
    bot(tt,api){if(tt<2.2){if(api.pointer.x<0)return[{type:'move',x:110,y:70}];return}
      const p=api.pointer;
      if(!started)return[{type:'click',x:p.x,y:p.y}];
      const mv=(x,y,v)=>{const dx=x-p.x,dy=y-p.y,d=Math.hypot(dx,dy),s=Math.min(d,v);return{type:'move',x:p.x+(d?dx/d*s:0),y:p.y+(d?dy/d*s:0)}};
      if(job&&job.c&&!chunks.includes(job.c))job=null;
      if(p.down){
        if(!held){job=null;return[{type:'up'}]}
        if(!job||job.c!==held)job={c:held,f:job?job.f:0};
        const c=job.c;job.f++;
        if(c.kind==='rock'){if(!job.dir){const side=c.x<75?-1:1;job.dir={x:side*.85,y:-.5}}
          if(job.f>9)return[{type:'up'}];return[mv(p.x+job.dir.x*12,p.y+job.dir.y*12,7)]}
        // ice: carry it down into the bay's middle
        if(job.f>70)return[{type:'up'}];return[mv(75,HULL+6,4.5)]}
      if(!job){const c=pickJob();if(c)job={c,f:0}}
      if(job){const c=job.c,lead=.12,tx=c.x+c.vx*lead,ty=c.y+c.vy*lead;const d=Math.hypot(tx-p.x,ty-p.y);
        if(Math.hypot(c.x-p.x,c.y-p.y)<c.r+2)return[{type:'down',x:p.x,y:p.y}];
        if(d>0)return[mv(tx,ty,6)];return}
      return[mv(75,78,2)]},
  }}
TK.register({id:ID,name:'Flick',hint:'Ice in. Rocks out.',controls:['drag'],mount,
  sounds:{grab:'tray2_slide.wav',throw:'sling2_launch.wav',knock:'sling2_hit.wav',bank:'icecore2_place.wav',miss:'tomo2_crack.wav',hit:'fourkelvin_bump.wav',win:{file:'fourkelvin_win.wav',off:300}}});
})();
