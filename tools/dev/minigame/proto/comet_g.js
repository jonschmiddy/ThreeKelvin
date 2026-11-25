// TOUCHDOWN (comet G): land a probe on a comet's nucleus, as Philae did on 67P. The nucleus turns slowly in
// front of you, a lumpy dark rock with one flat patch of clean ice (blue lights over it). Its pull is weak but
// real, and the probe comes in fast. LEFT button: the main thruster pushes the probe toward the pointer (it is
// weak, about the pull's size: it steers, it cannot stop you). RIGHT button (Jon, Nov 22: "a right click to slow
// the approach"): the retro thruster fires out of the probe's front, the side facing the comet, and cancels the
// approach: it stops your fall and holds you against the pull, but leaves sideways motion alone, so the main
// thruster can still steer while you brake. Holding it hovers; let go to sink, brake again before the ground.
// Touch down on the ice slower than the safe speed. Too fast and you BOUNCE (Philae bounced twice); fast and the
// probe breaks. The nucleus turns, so at depth 4-5 the ground under the ice moves faster than the safe speed:
// you match it sideways with the main thruster. Both engines burn one tank (the main one faster).
//
// Score: on the ice, soft and centred = 1. Each bounce costs a share. Soft on rock = a small score.
// Depth: faster spin, a smaller patch, a stronger pull, a faster arrival, a weaker brake, less fuel, a gas vent
// (3+) that puffs beside the patch (two at 5). Sensors: a higher safe speed; 2+ a dotted path shows where you
// will fall; 4+ more fuel.
(function(){
'use strict';
const ID='comet_g',W=150,H=140,DT=1/60;
function mulberry(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
const BAY=[0,2,3,1],on=(x,y,d)=>(BAY[(y&1)*2+(x&1)]+.5)/4<d;
const wrap=a=>{a=(a+Math.PI)%(2*Math.PI);if(a<0)a+=2*Math.PI;return a-Math.PI};
const hash=(a,b)=>{let h=Math.imul(a|0,374761393)+Math.imul(b|0,668265263);h=Math.imul(h^h>>>13,1274126177);return((h^h>>>16)>>>0)/4294967296};
// the probe, legs down (+y). # body, o window, l legs, f feet
const SPR=['...###...','..#ooo#..','.#######.','.#######.','..#####..','..l...l..','.l.....l.','f.......f'];
function mount(stage,ctx){
  const KIT=TK.KIT,P=TK.PAL,px=TK.pixel(stage,{w:W,h:H}),g=px.g,pop=KIT.popups(ctx),r=ctx.rng;
  const D=ctx.depth,S=ctx.sensors,PY=KIT.ROW.PLAY.y;
  const now=()=>performance.now()/1000;
  // ---- tuning ----
  const T=[24,22,20,18,16][D-1];                 // time to get down
  const SPIN=(r()<.5?-1:1)*[.18,.22,.26,.3,.34][D-1]; // rad/s: the ground under the patch moves 5 to 10 px/s (a dead stop lands soft to depth 3)
  const HW=[.42,.36,.31,.27,.23][D-1]*(1+.05*S); // the ice patch, half its width in radians
  const SAFE=[10,9.5,9,8.5,8][D-1]+.8*S;         // the softest touchdown counts if slower than this (px/s)
  const BREAK=SAFE*2;                          // faster than this the probe breaks (an unbraked arrival does)
  const G0=[8,8.8,9.6,10.4,11.2][D-1];           // the pull at the surface (px/s^2)
  const THR=[11,10.5,10.5,10.5,10.5][D-1];           // the main thruster (px/s^2): about the pull's size, so it steers but cannot stop you
  const MAINBURN=2;                              // and it drinks fuel twice as fast as the brake
  const BRK=[32,30,28,26,24][D-1];               // the retro brake's most push (px/s^2)
  const V0=[12,15,18,21,24][D-1];                // how fast the probe arrives, toward the nucleus
  const FUEL=[14,12,10.5,9,8][D-1]*(S>=4?1.25:1); // seconds of one engine at full burn (the brake burns by how hard it pushes)
  const NVENT=D>=5?2:D>=3?1:0;
  const C={x:80,y:94},R0=28;
  // ---- the nucleus, from the seed ----
  const p1=r()*6.28,p2=r()*6.28,p3=r()*6.28,TP=r()*6.28;        // TP: the patch's own angle on the body
  const raw=a=>R0+3*Math.sin(2*a+p1)+2.1*Math.sin(3*a+p2)+1.1*Math.sin(5*a+p3);
  const RP=raw(TP);
  const rad=a=>{const d=Math.abs(wrap(a-TP)),w=d<HW+.08?1:d>HW+.55?0:1-(d-HW-.08)/.47;return raw(a)*(1-w)+RP*w};
  // the patch comes up toward the top as the run starts (it reaches the top in about 2.5 s)
  let rot=-Math.PI/2-TP-SPIN*2.6;
  const vents=[];for(let i=0;i<NVENT;i++){const side=i===0?(r()<.5?-1:1):-vents[0].side;
    vents.push({side,a:TP+side*(HW+.5+r()*.2),per:2.6+r()*.8,ph:r()*2,glow:.7})}
  const ventState=(v,t)=>{const u=(t+v.ph)%v.per;return u<v.per-1.5?0:u<v.per-.8?1:2}; // 0 quiet, 1 glowing, 2 puffing
  const nz=mulberry((ctx.seed^0x7a11)>>>0);
  // ---- state ----
  const pr={x:78+(r()-.5)*40,y:22,vx:0,vy:0};{const dx=C.x-pr.x,dy=C.y-pr.y,d=Math.hypot(dx,dy),side=(r()<.5?-1:1)*(4+r()*4);
    pr.vx=dx/d*V0-dy/d*side;pr.vy=dy/d*V0+dx/d*side}
  const aim={x:pr.x,y:pr.y+20,inside:false};
  let started=false,over=false,hold=false,brake=false,told=false,brakeOn=false,bax=0,bay=0,t=0,endT=null,acc=0,last=now(),t0=last,raf=0;
  let fuel=1,bounces=0,landed=null,said={},hurt=0,thrusting=false,lastSpeed=0,thrustOn=false;
  const motes=[];for(let i=0;i<40;i++)motes.push({x:nz()*W,y:PY+nz()*(H-PY),v:6+nz()*10,k:nz()});
  const puffs=[],plume={t:-9,m:0,x:0,y:1};
  // background: stars and the sun's limb on the left (the tail streams right)
  const bg=document.createElement('canvas');bg.width=W;bg.height=H;{const b=bg.getContext('2d');b.fillStyle=P.void;b.fillRect(0,0,W,H);
    const sun={x:-56,y:84};
    for(let y=PY;y<H;y++)for(let x=0;x<40;x++){const d=Math.hypot(x-sun.x,y-sun.y);
      if(d<60){b.fillStyle=on(x,y,(60-d)/4)?P.warn:'#5a4320';b.fillRect(x,y,1,1)}
      else if(d<69){b.fillStyle=on(x,y,(69-d)/9)?'#5a4320':'#2a2216';b.fillRect(x,y,1,1)}
      else if(d<80&&on(x,y,(80-d)/11*.6)){b.fillStyle='#2a2216';b.fillRect(x,y,1,1)}}
    const sr=mulberry(ctx.seed^0x9e37);for(let i=0;i<50;i++){const x=Math.floor(sr()*W),y=PY+Math.floor(sr()*(H-PY));if(x<34)continue;b.fillStyle=sr()<.2?P.cold:P.line;b.fillRect(x,y,1,1)}}
  const surfAt=(x,y)=>{const a=Math.atan2(y-C.y,x-C.x);return{a,rr:rad(a-rot),d:Math.hypot(x-C.x,y-C.y)}};
  const gravAt=(x,y)=>{const dx=C.x-x,dy=C.y-y,d=Math.hypot(dx,dy)||1,gg=G0*Math.pow(R0/Math.max(d,R0),.35);return{x:dx/d*gg,y:dy/d*gg}};
  const surfVel=(x,y)=>({x:-SPIN*(y-C.y),y:SPIN*(x-C.x)});
  // the ground's own speed under a point (the spot on the surface straight below it), so far away it reads sanely
  const groundVel=(x,y)=>{const s=surfAt(x,y),k=Math.min(1,(s.rr+FOOT)/(s.d||1));return surfVel(C.x+(x-C.x)*k,C.y+(y-C.y)*k)};
  const FOOT=4;                                  // the feet are this far from the probe's middle
  function speedRel(){const sv=groundVel(pr.x,pr.y);return Math.hypot(pr.vx-sv.x,pr.vy-sv.y)}
  function sim(){
    if(!started||over){return}
    t+=DT;rot+=SPIN*DT;hurt=Math.max(0,hurt-DT);
    const gr=gravAt(pr.x,pr.y);let ax=gr.x,ay=gr.y;
    thrusting=false;
    if(hold&&fuel>0){const dx=aim.x-pr.x,dy=aim.y-pr.y,d=Math.hypot(dx,dy);if(d>1.5){ax+=dx/d*THR;ay+=dy/d*THR;thrusting=true;fuel=Math.max(0,fuel-DT/FUEL*MAINBURN)}}
    if(thrusting!==thrustOn){thrustOn=thrusting;TK.sfx(ID,'hum',thrusting?1:0)}
    // the retro brake: cancels the approach (the motion toward the nucleus, and the pull), up to BRK; sideways is free
    bax=0;bay=0;
    if(brake&&fuel>0){const dd=Math.hypot(pr.x-C.x,pr.y-C.y)||1,ux=(pr.x-C.x)/dd,uy=(pr.y-C.y)/dd,vr=pr.vx*ux+pr.vy*uy,gr0=gr.x*ux+gr.y*uy;
      const m=Math.max(0,Math.min(BRK,-vr/.12-gr0));
      if(m>.5){bax=ux*m;bay=uy*m;ax+=bax;ay+=bay;fuel=Math.max(0,fuel-DT/FUEL*Math.max(.25,m/BRK))}}
    const bOn=Math.hypot(bax,bay)>1;if(bOn!==brakeOn){brakeOn=bOn;TK.sfx(ID,'brake',bOn?1:0)}
    if((hold||brake)&&fuel<=0&&!said.fuel){said.fuel=1;pop.say('NO FUEL','bad',now())}
    // gas vents puff beside the patch: a puff pushes the probe away from the nucleus
    for(const v of vents){const st=ventState(v,t);if(st!==2)continue;const a=v.a+rot,rr=rad(v.a),vx=C.x+Math.cos(a)*rr,vy=C.y+Math.sin(a)*rr;
      const dx=pr.x-vx,dy=pr.y-vy,d=Math.hypot(dx,dy),al=dx*Math.cos(a)+dy*Math.sin(a),off=Math.abs(-dx*Math.sin(a)+dy*Math.cos(a));
      if(al>-1&&al<44&&off<3+al*.35){ax+=Math.cos(a)*60*(1-al/50);ay+=Math.sin(a)*60*(1-al/50);if(!said['v'+t.toFixed(0)]&&hurt<=0){said['v'+t.toFixed(0)]=1;pop.say('GAS PUFF','bad',now());hurt=.6;TK.sfx(ID,'puff')}}
      if(nz()<.7){const s=12+nz()*20,sp=(nz()-.5)*.6;puffs.push({x:vx,y:vy,vx:Math.cos(a+sp)*s,vy:Math.sin(a+sp)*s,age:0})}}
    pr.vx+=ax*DT;pr.vy+=ay*DT;pr.x+=pr.vx*DT;pr.y+=pr.vy*DT;
    lastSpeed=speedRel();
    const s=surfAt(pr.x,pr.y);
    if(s.d-s.rr<26&&lastSpeed>SAFE&&!said.fast&&!bounces){said.fast=1;pop.say('TOO FAST','bad',now())}   // early enough to brake
    if(s.d<=s.rr+FOOT){                          // touchdown
      const sv=groundVel(pr.x,pr.y),rvx=pr.vx-sv.x,rvy=pr.vy-sv.y,sp=Math.hypot(rvx,rvy),nx=(pr.x-C.x)/s.d,ny=(pr.y-C.y)/s.d;
      const off=wrap(s.a-rot-TP),onIce=Math.abs(off)<=HW;
      pr.x=C.x+nx*(s.rr+FOOT);pr.y=C.y+ny*(s.rr+FOOT);
      if(sp>BREAK){landed={ok:false,broke:true,sp};pr.vx=sv.x;pr.vy=sv.y;TK.sfx(ID,'hit');end();return}
      if(sp<=SAFE){landed={ok:true,onIce,off,sp};pr.vx=sv.x;pr.vy=sv.y;TK.sfx(ID,onIce?'land':'hit');end();return}
      // a bounce: the normal part reflects, softened; the probe skids along with the ground a little
      const vn=rvx*nx+rvy*ny,tx=rvx-vn*nx,ty=rvy-vn*ny,e=.5;
      pr.vx=sv.x+tx*.7-vn*e*nx;pr.vy=sv.y+ty*.7-vn*e*ny;
      bounces++;hurt=.7;TK.sfx(ID,'hit');pop.say('BOUNCED','bad',now());
      for(let i=0;i<8;i++){const an=nz()*6.28,v=6+nz()*10;puffs.push({x:pr.x-nx*FOOT,y:pr.y-ny*FOOT,vx:Math.cos(an)*v+nx*8,vy:Math.sin(an)*v+ny*8,age:.2})}
    }
    if(pr.x<-12||pr.x>W+12||pr.y<PY-14||pr.y>H+12){landed={ok:false,lost:true};end();return}
    if(t>=T){landed={ok:false,time:true};end()}
  }
  function score(){if(!landed)return 0;if(landed.ok){const soft=Math.max(0,1-landed.sp/SAFE);
      if(landed.onIce){const q=1-Math.abs(landed.off)/HW;return Math.max(0,Math.min(1,(.7+.18*q+.12*soft)*Math.pow(.75,bounces)))}
      return (.25+.08*soft)*Math.pow(.75,bounces)}
    return landed.broke?.05:landed.time?.1:0}
  function end(){if(over)return;over=true;endT=t;hold=false;brake=false;TK.sfx(ID,'hum',0);TK.sfx(ID,'brake',0);const s=score(),n=now();
    if(s>=.5)TK.sfx(ID,'win');
    const L=landed||{};
    const top=Math.min(4,2+Math.floor((D-1)/2)),best=Math.floor(s*top+.15)>=top;
    pop.finish(L.ok&&L.onIce?(best?'PERFECT LANDING':'LANDED'):L.ok?'LANDED ON ROCK':L.broke?'PROBE BROKE':L.lost?'LOST IN SPACE':'NO LANDING',
      L.ok&&L.onIce?'good':L.ok?'neutral':'bad',n);
    ctx.done({score:s,detail:L.ok?(L.onIce?'On the ice':'On rock')+' at '+L.sp.toFixed(1)+' px/s, '+bounces+' bounces':L.broke?'Hit at '+L.sp.toFixed(0)+' px/s':L.lost?'Drifted off':'Out of time'})}
  // ---- drawing ----
  const ROCK=['#111823','#1a2430','#22303f','#2e3d4f','#3d4d61','#4a5a70'];
  function drawNucleus(){const cx=C.x,cy=C.y,M=R0+6;
    for(let y=-M;y<=M;y++)for(let x=-M;x<=M;x++){const X=cx+x,Y=cy+y;if(Y<PY)continue;const d=Math.hypot(x,y);if(d>M)continue;
      const a=Math.atan2(y,x),ba=a-rot,rr=rad(ba);
      if(d>rr){if(d<=rr+1){g.fillStyle=P.bevelLo;g.fillRect(X,Y,1,1)}continue}
      // body coordinates (they turn with the nucleus): craters and grit stay put on the body
      const bx=Math.round(Math.cos(ba)*d),by=Math.round(Math.sin(ba)*d);
      const lightN=-Math.cos(a),depthIn=(rr-d)/rr;      // the sun is to the left
      let lv=1.6+lightN*1.7+(depthIn<.12?.6*lightN:0)-depthIn*1.2;
      const h=hash(bx>>1,by>>1);if(h<.12)lv-=1;else if(h>.9)lv+=.6;
      const cr=hash((bx+40)>>2,(by+40)>>2);if(cr<.06)lv-=1.2;
      let c=ROCK[Math.max(0,Math.min(5,Math.round(lv)))];
      const off=Math.abs(wrap(ba-TP));
      if(off<=HW&&d>rr-4.5){c=d>rr-1.5?(lightN>-.5?P.ice:P.chill):d>rr-3?P.chill:(on(X,Y,.5)?P.chill:P.cold)}
      g.fillStyle=c;g.fillRect(X,Y,1,1)}
    // the landing zone: a row of blue lights over the ice, blinking in turn, and a chevron over its middle
    {const nL=Math.max(5,Math.round(HW*RP/2.2)),ph=Math.floor(now()*6);
      for(let i=0;i<=nL;i++){const ba=TP-HW+2*HW*i/nL,a=ba+rot,rr=rad(ba)+4;const x=Math.round(cx+Math.cos(a)*rr),y=Math.round(cy+Math.sin(a)*rr);if(y<PY)continue;
        g.fillStyle=(i+ph)%3===0?P.ice:P.t2;g.fillRect(x,y,1,1)}
      const a=TP+rot,b=(Math.floor(now()*3)%2)?1:0,ux=Math.cos(a),uy=Math.sin(a),rr=RP+8+b;g.fillStyle=P.t2;
      for(let k=-2;k<=2;k++){const x=Math.round(cx+ux*(rr+Math.abs(k))-uy*k),y=Math.round(cy+uy*(rr+Math.abs(k))+ux*k);if(y>=PY)g.fillRect(x,y,1,1)}}
    // vents: dark holes that glow before they puff
    for(const v of vents){const st=started&&!over?ventState(v,t):0,a=v.a+rot,rr=rad(v.a)-.5,x=Math.round(cx+Math.cos(a)*rr),y=Math.round(cy+Math.sin(a)*rr);
      const blink=Math.floor(now()*8)%2===0;g.fillStyle=st===2?P.hot:st===1?(blink?P.flare:P.ember):'#5a3414';g.fillRect(x-1,y-1,2,2)}}
  function drawProbe(n){const s=surfAt(pr.x,pr.y),ang=Math.atan2(pr.y-C.y,pr.x-C.x)+Math.PI/2;  // legs point at the nucleus
    const q=Math.round(ang/(Math.PI/8))*(Math.PI/8),ca=Math.cos(q),sa=Math.sin(q);
    const fast=lastSpeed>SAFE&&!(landed&&landed.ok),blink=hurt>0&&Math.floor(n*12)%2===0;
    const legC=landed&&landed.ok?P.good:started?(fast?P.bad:P.good):P.cold;
    const cx=Math.round(pr.x),cy=Math.round(pr.y);
    if(blink)return;
    for(let y=-7;y<=7;y++)for(let x=-7;x<=7;x++){                       // rotate by whole 22.5 degree steps
      const sx=Math.round(x*ca+y*sa)+4,sy=Math.round(-x*sa+y*ca+3.5);if(sx<0||sx>8||sy<0||sy>7)continue;
      const ch=SPR[sy][sx];if(ch==='.')continue;
      g.fillStyle=ch==='#'?(sy===0?P.flare:P.ember):ch==='o'?P.hot:legC;g.fillRect(cx+x,cy+y,1,1)}}
  function draw(){const n=now();
    g.drawImage(bg,0,0);
    // the coma's haze round the nucleus and gas streaming off to the right, away from the sun
    for(let y=C.y-42;y<=C.y+42;y++)for(let x=C.x-42;x<W;x++){if(y<PY||y>=H)continue;const dx=x-C.x,dy=y-C.y,d=Math.hypot(dx,dy);
      const k=d<44?(44-d)/44*.32:0,tl=dx>0?Math.max(0,1-Math.abs(dy)/(10+dx*.25))*.22*(1-dx/90):0,v=Math.max(k,tl);
      if(v>0&&on(x,y,v)){g.fillStyle=P.line;g.fillRect(x,y,1,1)}}
    for(const m of motes){if(started&&!over)m.x+=m.v*DT;if(m.x>W+2){m.x=C.x+(nz()-.5)*20;m.y=C.y+(nz()-.5)*40}
      const dy=Math.abs(m.y-C.y);if(m.x<C.x-30||dy>14+(m.x-C.x)*.3)continue;g.fillStyle=m.k<.3?P.cold:'#26364a';g.fillRect(Math.round(m.x),Math.round(m.y),1,1)}
    drawNucleus();
    for(let i=puffs.length-1;i>=0;i--){const p=puffs[i];if(started&&!over){p.age+=DT;p.x+=p.vx*DT;p.y+=p.vy*DT}if(p.age>1.1){puffs.splice(i,1);continue}
      const x=Math.round(p.x),y=Math.round(p.y);if(y<PY)continue;g.fillStyle=p.age<.3?P.hot:p.age<.6?P.chill:P.cold;g.fillRect(x,y,1,1)}
    // sensors 2+: the path you are on (no thrust), 1.6 s ahead
    if(S>=2&&started&&!over){let x=pr.x,y=pr.y,vx=pr.vx,vy=pr.vy,rt=rot;g.fillStyle='#5a3414';
      for(let i=1;i<=96;i++){const gr=gravAt(x,y);vx+=gr.x*DT;vy+=gr.y*DT;x+=vx*DT;y+=vy*DT;rt+=SPIN*DT;
        const a=Math.atan2(y-C.y,x-C.x);if(Math.hypot(x-C.x,y-C.y)<=rad(a-rt)+FOOT)break;if(i%6===0&&y>=PY)g.fillRect(Math.round(x),Math.round(y),1,1)}}
    // the thrust line (where the push goes) and the flame on the far side
    if(started&&!over&&aim.inside){const dx=aim.x-pr.x,dy=aim.y-pr.y,L=Math.hypot(dx,dy)||1,ux=dx/L,uy=dy/L;
      g.fillStyle=hold&&fuel>0?P.ember:'#5a3414';for(let k=6;k<Math.min(L,26);k+=2)g.fillRect(Math.round(pr.x+ux*k),Math.round(pr.y+uy*k),1,1);
      g.fillStyle=P.ember;const ax=Math.round(aim.x),ay=Math.round(aim.y);g.fillRect(ax-2,ay,1,1);g.fillRect(ax+2,ay,1,1);g.fillRect(ax,ay-2,1,1);g.fillRect(ax,ay+2,1,1);
      if(thrusting){const fl=Math.floor(n*20)%3;for(let k=4;k<=6+fl;k++){g.fillStyle=k<6?P.hot:k<7?P.flare:P.ember;g.fillRect(Math.round(pr.x-ux*k),Math.round(pr.y-uy*k),1,1);
        if(k===5){g.fillRect(Math.round(pr.x-ux*k-uy),Math.round(pr.y-uy*k+ux),1,1);g.fillRect(Math.round(pr.x-ux*k+uy),Math.round(pr.y-uy*k-ux),1,1)}}}}
    drawProbe(n);
    // the brake's plume: out of the probe's front (the side facing the comet): a wide fan of flame that grows with
    // the push and flickers, with gas puffing ahead of it (so the brake reads at a glance)
    if(Math.hypot(bax,bay)>1){plume.m=Math.hypot(bax,bay);plume.x=-bax/plume.m;plume.y=-bay/plume.m;plume.t=n}
    if(started&&!over&&n-plume.t<.14){const m=plume.m,ux=plume.x,uy=plume.y,fl=Math.floor(n*24)%3,k0=Math.min(1,m/BRK),len=6+Math.round(k0*5)+fl;
      for(const o of[-3,-1.5,0,1.5,3]){const ll=len-Math.abs(o)*1.2;for(let k=5;k<=ll;k++){const sp=o*(1+(k-4)*.12);
        g.fillStyle=k<6?'#ffffff':k<8?P.hot:k<10?P.flare:P.ember;g.fillRect(Math.round(pr.x+ux*k-uy*sp),Math.round(pr.y+uy*k+ux*sp),1,1)}}
      if(n-plume.t<.02&&nz()<.8)puffs.push({x:pr.x+ux*(len+1),y:pr.y+uy*(len+1),vx:ux*(14+nz()*10)+(nz()-.5)*14,vy:uy*(14+nz()*10)+(nz()-.5)*14,age:.25})}
    // the header: fuel (yours), the speed (red when too fast to land), time
    const left=Math.max(0,T-(over&&endT!=null?endT:t)),sp=started?Math.round(lastSpeed):0;
    KIT.header(g,{label:'FUEL',meter:{w:37,frac:fuel,kind:fuel<.2?'bad':'yours'}},[['SPEED',sp,started&&lastSpeed>SAFE&&!(landed&&landed.ok)?'bad':'good'],['TIME',Math.ceil(left)]]);
    if(!told)drawCard(n-t0);
    pop.draw(g,n);
  }
  // the start card, three lines (the kit's card has one line of controls): left hold, right hold, Esc
  function mouseIcon(x,y,t,right){const M=['...#####...','..#..#..#..','.#...#...#.','.#...#...#.','.#########.','.#.......#.','.#.......#.','.#.......#.','.#.......#.','..#.....#..','...#####...'];
    const pxl=(c,xx,yy,w,h)=>{g.fillStyle=c;g.fillRect(x+xx,y+yy,w||1,h||1)};
    for(let r2=0;r2<M.length;r2++)for(let c=0;c<11;c++)if(M[r2][c]==='#')pxl(P.ice,c,r2+1);
    for(let r2=1;r2<4;r2++)for(let c=2;c<9;c++){if(c===5)continue;pxl((c<5)!==right?P.ember:P.line,c,r2+1)}
    for(let r2=5;r2<10;r2++)for(let c=2;c<9;c++)if(M[r2][c]==='.')pxl(P.panel,c,r2+1);
    for(let i=0;i<4;i++)pxl(i<1+Math.floor((t*3)%4)?P.ember:P.line,13+i*2,10,1,2);return 21}
  function drawCard(t){const L1='LAND ON THE ICE.',L2='RIGHT-CLICK TO BRAKE.',L3='TO GIVE UP',tw=s=>s.length*4-1;
    const w=Math.max(24+tw(L1),24+tw(L2),20+tw(L3))+12,x=75-(w>>1),y=44,h=42;
    g.fillStyle=P.bevelLo;g.fillRect(x,y,w,h);g.fillStyle=KIT.BORDER;g.fillRect(x+1,y+1,w-2,h-2);g.fillStyle=P.bevelHi;g.fillRect(x+1,y+1,w-2,1);
    const x1=x+((w-24-tw(L1))>>1);mouseIcon(x1,y+2,t,false);TK.text(g,L1,x1+24,y+6,P.hot);
    const x2=x+((w-24-tw(L2))>>1);mouseIcon(x2,y+15,t+.5,true);TK.text(g,L2,x2+24,y+19,P.hot);
    const x3=x+((w-20-tw(L3))>>1);g.save();g.translate(x3,y+28);TK.icon(g,'key',0,0,{label:'ESC',t:.5});g.restore();TK.text(g,L3,x3+20,y+33,KIT.LABEL)}
  function step(){const n=now();acc+=Math.min(.1,n-last);last=n;
    while(acc>=DT){acc-=DT;sim()}
    draw();raf=requestAnimationFrame(step)}
  const onMove=e=>{const p=px.pt(e);aim.x=Math.max(0,Math.min(W-1,p.x));aim.y=Math.max(PY,Math.min(H-1,p.y));aim.inside=true};
  // left = main thruster, right = brake. A second button pressed while one is held arrives as a pointermove whose
  // e.button names it (pointer events chord that way), so moves change the buttons only when e.button says so.
  const onDown=e=>{if(pop.click(now()))return;if(over)return;onMove(e);
    if(e.button===2){brake=true;started=true}else if(e.button===0){hold=true;started=true}else return;
    try{px.cv.setPointerCapture(e.pointerId)}catch(_){} };
  const onMoveB=e=>{if(e.button===0)hold=!!(e.buttons&1);else if(e.button===2)brake=!!(e.buttons&2)};
  const onUp=e=>{if(!e||e.type==='blur'){hold=false;brake=false;return}if(e.button===0)hold=false;else if(e.button===2)brake=false};
  const onCtx=e=>e.preventDefault();             // no browser menu on the glass: the right button is the brake
  const onTold=()=>{told=true};
  const onLeave=()=>{aim.inside=hold};
  px.cv.addEventListener('pointermove',onMove);px.cv.addEventListener('pointermove',onMoveB);px.cv.addEventListener('pointerdown',onDown);
  window.addEventListener('pointerup',onUp);window.addEventListener('pointercancel',onUp);window.addEventListener('blur',onUp);px.cv.addEventListener('pointerleave',onLeave);
  px.cv.addEventListener('contextmenu',onCtx);window.addEventListener('pointerdown',onTold,true);
  raf=requestAnimationFrame(step);
  // the film's bot: brake hard on the way in (real right-button events), steer over the patch with the main
  // thruster while matching the turning ground, then come straight down slowly
  let bphase=0,bBrake=false;
  function rbtn(down,api){const rc=px.cv.getBoundingClientRect(),p=api.pointer,
      o={bubbles:true,cancelable:true,composed:true,clientX:rc.left+(p.x+.5)*rc.width/W,clientY:rc.top+(p.y+.5)*rc.height/H,pointerId:1,pointerType:'mouse',isPrimary:true,
        button:2,buttons:(p.down?1:0)|(down?2:0),view:window};
    px.cv.dispatchEvent(new PointerEvent(down?'pointerdown':'pointerup',o));px.cv.dispatchEvent(new MouseEvent(down?'mousedown':'mouseup',o));
    if(!down)px.cv.dispatchEvent(new MouseEvent('contextmenu',o));bBrake=down}
  return{
    destroy(){over=true;cancelAnimationFrame(raf);TK.sfx(ID,'hum',0);TK.sfx(ID,'brake',0);px.cv.removeEventListener('pointermove',onMove);px.cv.removeEventListener('pointermove',onMoveB);
      px.cv.removeEventListener('pointerdown',onDown);window.removeEventListener('pointerup',onUp);window.removeEventListener('pointercancel',onUp);window.removeEventListener('blur',onUp);
      px.cv.removeEventListener('pointerleave',onLeave);px.cv.removeEventListener('contextmenu',onCtx);window.removeEventListener('pointerdown',onTold,true);px.destroy()},
    giveUp(){if(over)return;over=true;hold=false;brake=false;TK.sfx(ID,'hum',0);TK.sfx(ID,'brake',0);ctx.done({score:0,detail:'Gave up'})},
    dbg(){return{t:+t.toFixed(2),hold,brake,braking:Math.hypot(bax,bay)>1,v:+Math.hypot(pr.vx,pr.vy).toFixed(1),rel:+lastSpeed.toFixed(1),fuel:+fuel.toFixed(2),bphase,alt:+(surfAt(pr.x,pr.y).d-surfAt(pr.x,pr.y).rr).toFixed(1),started,told}},
    bot(tt,api){if(tt<2.2){if(api.pointer.x<0)return[{type:'move',x:pr.x+18,y:pr.y-14}];return}
      if(over)return;
      const a=TP+rot,rr=RP,nx=Math.cos(a),ny=Math.sin(a),hx=C.x+nx*rr,hy=C.y+ny*rr;
      const hgt=bphase===0?9:0,tx=hx+nx*(hgt+FOOT),ty=hy+ny*(hgt+FOOT),tv=surfVel(tx,ty);
      const s1=surfAt(pr.x,pr.y),alt=s1.d-s1.rr-FOOT,un=(pr.x-C.x)/s1.d,vn=(pr.y-C.y)/s1.d;
      const ex=tx-pr.x,ey=ty-pr.y,dist=Math.hypot(ex,ey),kp=1.6,kd=2.4;
      if(bphase===0&&dist<6&&Math.hypot(pr.vx-tv.x,pr.vy-tv.y)<4.5)bphase=1;
      // the brake keeps the fall under a speed that shrinks with height (and in the last metres, slow)
      const gv=groundVel(pr.x,pr.y),closing=-((pr.vx-gv.x)*un+(pr.vy-gv.y)*vn);
      const allow=bphase===1?(alt>6?5:3):Math.max(2.5,1.1*(alt-9)),wantB=started&&closing>allow+(bBrake?-1.5:0);
      if(wantB!==bBrake&&!window.__noBrake)rbtn(wantB,api);   // __noBrake: a test switch (does a landing need the brake?)
      // the main thruster steers: over the patch, moving with the ground (sideways only while the brake holds the fall)
      const gr=gravAt(pr.x,pr.y);let nx2=kp*ex+kd*(tv.x-pr.vx)-gr.x,ny2=kp*ey+kd*(tv.y-pr.vy)-gr.y;
      if(bBrake||bphase===1){const rad0=nx2*un+ny2*vn;nx2-=rad0*un;ny2-=rad0*vn}
      const need=Math.hypot(nx2,ny2),want=need>(api.pointer.down?THR*.25:THR*.55)||!started;
      const gx=pr.x+(need?nx2/need:0)*20,gy=pr.y+(need?ny2/need:0)*20;
      const p=api.pointer.x<0?{x:gx,y:gy}:api.pointer,dx=gx-p.x,dy=gy-p.y,dd=Math.hypot(dx,dy),v=Math.min(dd,5);
      const mx=Math.max(0,Math.min(W-1,p.x+(dd?dx/dd*v:0))),my=Math.max(PY,Math.min(H-1,p.y+(dd?dy/dd*v:0))),ok=dd<8;
      const ev=[{type:'move',x:mx,y:my}];
      if(want&&ok&&!api.pointer.down)ev.push({type:'down',x:mx,y:my});
      else if((!want||!ok)&&api.pointer.down&&started)ev.push({type:'up',x:mx,y:my});
      return ev},
  }}
TK.register({id:ID,name:'Touchdown',hint:'Land on the ice.',controls:['hold'],mount,
  sounds:{hum:{file:'fourkelvin_thrust.wav',loop:true},brake:{file:'wreck1_torch.wav',loop:true},hit:'fourkelvin_bump.wav',land:'wreck2_dock.wav',puff:'wreck2_puff.wav',win:{file:'fourkelvin_win.wav',off:300}}});
})();
