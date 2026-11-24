// GEYSER (comet I): you are low over a comet's nucleus, close enough to see its gas jets. Where the sun warms
// the ground (the right side), a vent wakes, glows and fires a column of gas straight up. Your sampler (amber)
// has no lift of its own: it floats only while it sits in a jet, like a ball on a fountain, and fills with gas
// while it does (fastest in the jet's bright core). Off the jet it sinks toward the ground; touch the ground
// and the run ends. The nucleus turns, so every vent drifts left into the night, sputters and dies, and a new
// one wakes on the right: hop across before your jet goes out. The jets sway and gust as they blow.
//
// Control: the sampler's side thrusters steer it toward the pointer's x (it lags; no button held).
// Score: how full the sampler is. Depth: the nucleus turns faster (shorter jets, more hops), wider gaps,
// narrower and gustier jets that sway more. Sensors: wider jets; 2+ a blue mark where the next vent will wake.
(function(){
'use strict';
const ID='comet_i',W=150,H=140,DT=1/60;
function mulberry(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
const BAY=[0,2,3,1],on=(x,y,d)=>(BAY[(y&1)*2+(x&1)]+.5)/4<d;
const hash=(a,b)=>{let h=Math.imul(a|0,374761393)+Math.imul(b|0,668265263);h=Math.imul(h^h>>>13,1274126177);return((h^h>>>16)>>>0)/4294967296};
const cl=(v,a,b)=>v<a?a:v>b?b:v;
function mount(stage,ctx){
  const KIT=TK.KIT,P=TK.PAL,px=TK.pixel(stage,{w:W,h:H}),g=px.g,pop=KIT.popups(ctx),r=ctx.rng;
  const D=ctx.depth,S=ctx.sensors,PY=KIT.ROW.PLAY.y;
  const now=()=>performance.now()/1000;
  // ---- tuning ----
  const T=[12.5,11.5,10.5,10,9.5][D-1];          // the run
  const V=[8,9.5,11,12.5,14][D-1];               // how fast the ground turns past (px/s at the top of the arc)
  const GAP=[[34,46],[40,54],[46,60],[50,66],[54,72]][D-1]; // px between one vent and the next
  const W0=(4.2-.3*(D-1))*(1+.06*S);             // the jet's half-width at the mouth
  const SPREAD=.16;                              // and how it widens as it rises
  const SWAY=[.06,.1,.14,.18,.22][D-1];          // how far a jet leans as it sways (rad)
  const GUST=[.1,.14,.18,.22,.26][D-1];          // how hard it gusts
  const PUSH=[4,7,10,13,16][D-1];                // off the core, the gas shoves you out sideways
  const G=14,L0=38,HMAX=104;                     // pull, lift at the mouth, how high a jet reaches
  const CY=330,RR=220,TOP=CY-RR;                 // the nucleus: a big arc across the bottom
  const TERM=58,IGN=134;                         // night begins left of TERM; a vent wakes when it reaches IGN
  const surfY=x=>CY-Math.sqrt(RR*RR-(x-75)*(x-75));
  // ---- the vents, all from the seed: arc positions at t=0 (px from the top of the arc; they move left) ----
  const vents=[];{let s=26+r()*10;vents.push({s0:s,first:true});
    while(s-V*T<IGN-75+40){s+=GAP[0]+r()*(GAP[1]-GAP[0]);vents.push({s0:s})}
    for(const v of vents){v.ph=r()*6.28;v.w=1.2+r()*.9;v.gp=r()*6.28;v.tilt=(r()-.5)*.1}}
  const posOf=(v,t)=>{const s=v.s0-V*t,a=s/RR;return{x:75+RR*Math.sin(a),y:CY-RR*Math.cos(a),a}};
  const tIgn=v=>v.first?-9:(v.s0-RR*Math.asin((IGN-75)/RR))/V;      // when a vent reaches IGN
  const tDie=v=>(v.s0-RR*Math.asin((TERM-75)/RR))/V;                  // and TERM
  function strength(v,t){const ti=tIgn(v),td=tDie(v);if(t<ti||t>td+.05)return 0;
    let k=Math.min(1,(t-ti)/.5);const left=td-t;if(left<1.1){k*=Math.max(0,left/1.1)*(.55+.45*Math.sin(t*37+v.ph))}return Math.max(0,k)}
  const warm=(v,t)=>{const ti=tIgn(v);return t>ti-.8&&t<ti+.2};      // the mouth glows just before it wakes
  function axis(v,t){const p=posOf(v,t),a=p.a+v.tilt+SWAY*Math.sin(t*v.w+v.ph);return{ox:p.x,oy:p.y,ux:Math.sin(a),uy:-Math.cos(a)}}
  // the gas at a point: lift (along the jet), a shove off the core, and how rich it is
  function gas(x,y,t){let ax=0,ay=0,rich=0;
    for(const v of vents){const k=strength(v,t);if(k<=0)continue;const A=axis(v,t),dx=x-A.ox,dy=y-A.oy,al=dx*A.ux+dy*A.uy;if(al<=0)continue;
      const off=-dx*A.uy+dy*A.ux,w=W0+al*SPREAD,core=Math.exp(-2*(off/w)*(off/w)),f=Math.max(0,1-al/HMAX);if(core<.01||f<=0)continue;
      const gust=1+GUST*Math.sin(t*4.3+v.gp)+GUST*.6*Math.sin(t*9.1+v.gp*2),L=L0*k*f*core*gust;
      ax+=A.ux*L+(-A.uy)*Math.sign(off)*PUSH*k*f*core*Math.min(1,Math.abs(off)/w)*2;ay+=A.uy*L+A.ux*Math.sign(off)*PUSH*k*f*core*Math.min(1,Math.abs(off)/w)*2;
      rich=Math.max(rich,k*core*(.35+.65*f))}
    return{ax,ay,rich}}
  // ---- state ----
  const H0=HMAX*(1-G/L0);                        // where a centred sampler floats
  const v0=vents[0],a0=axis(v0,0);
  const pr={x:a0.ox+a0.ux*H0,y:a0.oy+a0.uy*H0,vx:0,vy:0};
  const ptr={x:pr.x};
  let started=false,over=false,t=0,endT=null,acc=0,last=now(),t0=last,raf=0,fill=0,said={},crashed=false,thr=0,fillOn=false;
  const RATE=1/(.42*T);                          // a full core fills this fast (tuned on the bot: a clean d3 run about fills it)
  const motes=[];const nz=mulberry((ctx.seed^0x6b1)>>>0);
  // background: stars and the sun's glow in the top-right corner
  const bg=document.createElement('canvas');bg.width=W;bg.height=H;{const b=bg.getContext('2d');b.fillStyle=P.void;b.fillRect(0,0,W,H);
    const sun={x:W+36,y:-6};
    for(let y=PY;y<80;y++)for(let x=80;x<W;x++){const d=Math.hypot(x-sun.x,y-sun.y);
      if(d<46){b.fillStyle=on(x,y,(46-d)/4)?P.warn:'#5a4320';b.fillRect(x,y,1,1)}
      else if(d<54){b.fillStyle=on(x,y,(54-d)/8)?'#5a4320':'#2a2216';b.fillRect(x,y,1,1)}
      else if(d<66&&on(x,y,(66-d)/12*.6)){b.fillStyle='#2a2216';b.fillRect(x,y,1,1)}}
    const sr=mulberry(ctx.seed^0x9e37);for(let i=0;i<60;i++){const x=Math.floor(sr()*W),y=PY+Math.floor(sr()*(H-PY));if(Math.hypot(x-sun.x,y-sun.y)<60)continue;b.fillStyle=sr()<.2?P.cold:P.line;b.fillRect(x,y,1,1)}}
  function sim(){
    // the jets' motes always stream (the glass is alive before the first press); the world waits for it
    const tt=started?t:0;
    for(const v of vents){const k=strength(v,tt);if(k<=0)continue;const A=axis(v,tt);const n=k*3.2;let c=Math.floor(n)+(nz()<n%1?1:0);
      while(c--){const sp=50+nz()*30,o=(nz()-.5)*W0*1.2;motes.push({x:A.ox-A.uy*o,y:A.oy+A.ux*o,vx:A.ux*sp+(nz()-.5)*6,vy:A.uy*sp,age:0,life:.9+nz()*.8})}}
    for(let i=motes.length-1;i>=0;i--){const m=motes[i];m.age+=DT;m.vx*=.985;m.vy*=.985;m.x+=m.vx*DT;m.y+=m.vy*DT;if(m.age>m.life||m.y<PY)motes.splice(i,1)}
    if(!started||over)return;
    t+=DT;
    const gs=gas(pr.x,pr.y,t);
    // side thrusters chase the pointer's x; gravity pulls toward the nucleus
    const want=cl((ptr.x-pr.x)*10-pr.vx*4.5,-55,55);thr=want;
    const gx=(75-pr.x)/(CY-pr.y)*G;
    pr.vx+=(want+gs.ax+gx)*DT;pr.vy+=(G+gs.ay)*DT;pr.vx*=.995;pr.vy*=.985;
    pr.x+=pr.vx*DT;pr.y+=pr.vy*DT;
    if(pr.x<3){pr.x=3;pr.vx=0}if(pr.x>W-4){pr.x=W-4;pr.vx=0}
    if(pr.y<PY+4){pr.y=PY+4;pr.vy=Math.max(0,pr.vy)}
    const gy=surfY(pr.x);
    if(gs.rich>.05){fill=Math.min(1,fill+RATE*gs.rich*DT)}
    const rich=gs.rich>.3;if(rich!==fillOn){fillOn=rich;TK.sfx(ID,'hum',rich?1:0)}
    if(fill>=.5&&!said.half){said.half=1;pop.say('HALF FULL','goal',now())}
    if(gy-pr.y<24&&pr.vy>0&&!said.low){said.low=1;pop.say('TOO LOW','bad',now())}
    if(gy-pr.y>34)said.low=0;
    if(pr.y+3>=gy){crashed=true;pr.y=gy-3;TK.sfx(ID,'hit');end();return}
    if(t>=T||fill>=1)end();
  }
  function score(){return Math.max(0,Math.min(1,fill*(crashed?.85:1)))}
  function end(){if(over)return;over=true;endT=t;TK.sfx(ID,'hum',0);const s=score();if(s>=.5&&!crashed)TK.sfx(ID,'win');
    pop.finish(crashed?'CRASHED':s>=.93?'SAMPLER FULL':s>=.5?'GOOD SAMPLE':'THIN SAMPLE',crashed?'bad':s>=.93?'good':'neutral',now());
    ctx.done({score:s,detail:Math.round(fill*100)+'% full'+(crashed?', crashed':'')})}
  // ---- drawing ----
  function drawGround(tt){const sc=V*tt,blink=Math.floor(now()*8)%2===0;
    const low=started&&!over&&surfY(pr.x)-pr.y<26;
    for(let x=0;x<W;x++){const top=surfY(x),ty=Math.ceil(top),night=x<TERM;
      for(let y=ty;y<H;y++){const dd=y-top,bx=Math.round(x+sc+(x-75)*0),hh=hash((bx>>1)+999,(Math.round(dd)>>1));
        let lv=dd<1.5?4:dd<4?3:dd<9?2:1;if(hh<.15)lv-=1;else if(hh>.92)lv+=1;
        const cr=hash((bx+5)>>2,(Math.round(dd)+3)>>2);if(cr<.07&&dd>3)lv-=1;
        if(night){lv-=x<TERM-6?2:on(x,y,.5)?1:2}
        const RAMP=[P.bevelLo,'#111823','#18212d',P.line,P.bevelHi,'#4a5a70',P.cold];
        let c=RAMP[cl(lv+1,0,6)];
        if(low&&dd<1.5&&Math.abs(x-pr.x)<12&&blink)c=P.bad;
        g.fillStyle=c;g.fillRect(x,y,1,1)}
      if(ty-1>=PY){g.fillStyle=P.bevelLo;g.fillRect(x,ty-1,1,1)}}}
  function drawJet(v,tt){const k=strength(v,tt),p=posOf(v,tt),A=axis(v,tt);if(p.x<-4||p.x>W+4)return;
    // the column: a dithered glow, brightest in the core and low down
    if(k>0)for(let al=1;al<HMAX;al++){const f=1-al/HMAX,w=W0+al*SPREAD,cx=A.ox+A.ux*al,cy=A.oy+A.uy*al;if(cy<PY)break;
      for(let o=-Math.ceil(w*1.4);o<=Math.ceil(w*1.4);o++){const x=Math.round(cx-A.uy*o),y=Math.round(cy+A.ux*o);if(y<PY||y>=H)continue;
        const core=Math.exp(-2*(o/w)*(o/w)),d=k*core*(.25+.75*f);if(d<.08)continue;
        if(d>.55&&on(x,y,(d-.55)*2.2)){g.fillStyle=d>.8?P.ice:P.chill;g.fillRect(x,y,1,1)}
        else if(on(x,y,Math.min(.75,d*1.3))){g.fillStyle=d>.3?'#34495e':'#26364a';g.fillRect(x,y,1,1)}}}
    // the mouth: dark, glowing before it wakes, bright while it blows
    const mx=Math.round(p.x),my=Math.round(p.y),bl=Math.floor(now()*8)%2===0;
    g.fillStyle=P.bevelLo;g.fillRect(mx-2,my,5,2);
    if(warm(v,tt)&&k<.5){g.fillStyle=bl?P.flare:P.ember;g.fillRect(mx-1,my,3,1)}
    else if(k>0){g.fillStyle=k>.6?P.ice:P.chill;g.fillRect(mx-1,my,3,1)}}
  function draw(){const n=now(),tt=started?t:0;
    g.drawImage(bg,0,0);
    for(const v of vents)drawJet(v,tt);
    for(const m of motes){const x=Math.round(m.x),y=Math.round(m.y),f=m.age/m.life;g.fillStyle=f<.3?P.ice:f<.6?P.chill:P.cold;g.fillRect(x,y,1,1)}
    drawGround(tt);
    // sensors 2+: where the next vent will wake
    if(S>=2&&!over){for(const v of vents){const ti=tIgn(v);if(ti>tt&&ti-tt<3){const p=posOf(v,tt);if(p.x<W-1){g.fillStyle=P.t2;const x=Math.round(p.x),y=Math.round(p.y)-3;g.fillRect(x,y,1,1);g.fillRect(x-1,y-1,1,1);g.fillRect(x+1,y-1,1,1)}break}}}
    // the sampler: an amber pod with a scoop; thruster puffs on the side it pushes from
    {const x=Math.round(pr.x),y=Math.round(pr.y),R=(xx,yy,w,h,c)=>{g.fillStyle=c;g.fillRect(x+xx,y+yy,w,h)};
      R(-3,-3,7,6,P.bevelLo);R(-2,-2,5,4,P.ember);R(-2,-2,5,1,P.flare);R(-1,-1,3,1,P.hot);R(-3,-4,1,2,P.bevelLo);R(3,-4,1,2,P.bevelLo);   // pod and scoop lips
      const fc=Math.round(fill*3);if(fc>0)R(-1,1-Math.min(2,fc-1),3,Math.min(2,fc),P.ice);   // the gas it holds shows in its window
      if(started&&!over&&Math.abs(thr)>12){const sd=thr>0?-1:1,fl=Math.floor(n*20)%2;R(sd>0?4:-5-fl,0,1+fl,1,P.hot)}
      if(started&&!over&&!fillOn&&pr.vy>2){R(-1,4,1,1,'#5a3414');R(1,5,1,1,'#5a3414')}}
    // the pointer's mark on the sampler's track
    if(started&&!over){g.fillStyle='#8a4a16';const y=Math.round(pr.y),xp=Math.round(ptr.x);g.fillRect(xp,y-6,1,2);g.fillRect(xp,y+5,1,2)}
    const left=Math.max(0,T-(over&&endT!=null?endT:t));
    KIT.header(g,{label:'GAS',meter:{w:57,frac:fill,kind:'goal'},value:Math.round(fill*100)+'%'},[['TIME',Math.ceil(started?left:T)]]);
    KIT.tell(g,'RIDE THE GAS JETS.',['drag-h'],n-t0,{y:KIT.ROW.TELL.top});
    pop.draw(g,n);
  }
  function step(){const n=now();acc+=Math.min(.1,n-last);last=n;
    while(acc>=DT){acc-=DT;sim()}
    draw();raf=requestAnimationFrame(step)}
  const onMove=e=>{if(over)return;const p=px.pt(e);ptr.x=cl(p.x,2,W-3)};
  const onDown=e=>{if(pop.click(now()))return;if(over)return;if(!started){started=true;ptr.x=pr.x}else onMove(e)};
  px.cv.addEventListener('pointermove',onMove);px.cv.addEventListener('pointerdown',onDown);
  raf=requestAnimationFrame(step);
  // the film's bot: sit in the core of the strongest jet, leading its drift; hop to the next one before it dies
  return{
    destroy(){over=true;cancelAnimationFrame(raf);TK.sfx(ID,'hum',0);px.cv.removeEventListener('pointermove',onMove);px.cv.removeEventListener('pointerdown',onDown);px.destroy()},
    giveUp(){if(over)return;over=true;TK.sfx(ID,'hum',0);ctx.done({score:.3*score(),detail:'Gave up at '+Math.round(fill*100)+'%'})},
    bot(tt,api){if(tt<2.2){if(api.pointer.x<0)return[{type:'move',x:pr.x,y:pr.y+14}];return}
      if(!started)return[{type:'click',x:api.pointer.x,y:api.pointer.y}];
      let best=null,bs=-1;
      for(const v of vents){const k=strength(v,t+.35),life=tDie(v)-t;if(k<=0&&!(tIgn(v)>t&&tIgn(v)-t<.5))continue;
        const sc=(life>1.4?1:0)+(k>0?.5:0)-Math.abs(posOf(v,t).x-pr.x)/300;if(sc>bs){bs=sc;best=v}}
      let gx=pr.x;
      if(best){const A=axis(best,t+.2),al=Math.max(0,(A.oy-pr.y)/-A.uy||0);gx=A.ox+A.ux*al-V*.25}
      const p=api.pointer,dx=gx-p.x,v=Math.min(Math.abs(dx),3.2)*Math.sign(dx);
      return[{type:'move',x:p.x+v,y:Math.round(pr.y)+14}]},
  }}
TK.register({id:ID,name:'Geyser',hint:'Ride the gas jets.',controls:['drag-h'],mount,
  sounds:{hum:{file:'wreck1_torch.wav',loop:true},hit:'fourkelvin_bump.wav',win:{file:'fourkelvin_win.wav',off:300}}});
})();
