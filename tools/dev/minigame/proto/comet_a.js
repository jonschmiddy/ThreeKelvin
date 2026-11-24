// SKIM (comet A): a comet swings past the sun; its ice tail streams away from the sun, swings as the comet
// turns and ripples as it drifts. Your probe hangs on a tether from the pointer: lead it into the tail and
// it scoops the ice it passes through (the bright young ice near the head counts double). Grit flies out of
// the head down the tail: a hit spills some of your ice back into space. The run ends when the tail fades.
//
// Control: the probe follows the pointer on a spring tether (no button held). Why: the tether IS the
// momentum (the probe lags, swings and overshoots, so you lead it like a weight on a string), and ten
// seconds of holding a button adds nothing but a tired finger. On touch it is a drag, as pointer moves are.
// Depth: shorter pass, faster tail, stronger ripples, more grit. Sensors: a wider scoop, ice lasts longer.
(function(){
'use strict';
const ID='comet_a',W=150,H=140,DT=1/60;
function mulberry(a){return function(){a|=0;a=a+0x6D2B79F5|0;let t=Math.imul(a^a>>>15,1|a);t=t+Math.imul(t^t>>>7,61|t)^t;return((t^t>>>14)>>>0)/4294967296}}
const BAY=[0,2,3,1],on=(x,y,d)=>(BAY[(y&1)*2+(x&1)]+.5)/4<d;
function mount(stage,ctx){
  const KIT=TK.KIT,P=TK.PAL,px=TK.pixel(stage,{w:W,h:H}),g=px.g,pop=KIT.popups(ctx),r=ctx.rng;
  const D=ctx.depth,S=ctx.sensors,PY=KIT.ROW.PLAY.y;
  const now=()=>performance.now()/1000;
  // ---- the comet, all from the seed ----
  const T=[10.5,9.5,8.6,7.4,6.4][D-1];           // the pass, shorter with depth
  const FADE=2.2;                                // the tail thins out over the pass's last seconds
  const VS=11+3*D;                               // tail drift speed, px/s
  const CURL=2+1.6*D;                            // ripple strength, px/s^2
  const LIFE=3.4*(1+.07*S);                      // how long a grain of ice lasts
  const CATCH=3+.35*S;                           // scoop radius
  const EMIT=150;                                // grains per second
  const KEEP=6.5+.75*D;                          // keep-out round the head (red ring): 7.25 at depth 1, 8.75 at 3, 10.25 at 5
  const DBL=.26-.03*(D-1);                       // ice younger than this share of its life counts double
  const THIN=.15*(D-1),SPLIT=D>=3?.07*(D-2):0;   // the tail comes in pulses and splits in two (radians apart, each side)
  const SPRING=30-2*D,DAMP=5.2;                  // the tether: softer with depth (more lag, more swing)
  const SPILL=.12+.02*D;                         // share of the hold a hit spills
  const sunLeft=r()<.5,down=r()<.5,mir=x=>sunLeft?x:W-1-x;
  const sun={x:mir(-52),y:70+r()*12};
  const yA=36+r()*10,yB=116-r()*10,P0={x:mir(30+r()*12),y:down?yA:yB},P2={x:mir(34+r()*12),y:down?yB:yA},
        P1={x:mir(14+r()*10+D*3),y:(yA+yB)/2+(r()-.5)*16};
  const PRE=2.4;                                 // the tail is already there when the glass opens
  const head=t=>{const u=Math.max(0,Math.min(1,(t+PRE)/(T+PRE+.6))),a=(1-u)*(1-u),b=2*u*(1-u),c=u*u;
    return{x:a*P0.x+b*P1.x+c*P2.x,y:a*P0.y+b*P1.y+c*P2.y}};
  const phase=r()*6.28,curlK=.15+r()*.06;
  // grit: when it leaves the head and how far off the tail's line, fixed by the seed
  // grit comes in bursts: a line of rocks down one lane, the head flashing red WARN s before each burst
  const WARN=.5,grit=[],bursts=[];{const rate=.25+.17*(D-1),nb=2+D;let tt=1+r()*1.2;
    while(tt<T-.5){const off=(r()-.5)*.6,sp=1.55+r()*.2;bursts.push(tt);for(let i=0;i<nb;i++)grit.push({at:tt+i*.09,off:off+(r()-.5)*.05,sp:sp+(r()-.5)*.05});tt+=(.7+r()*.6)/rate}}
  const phase2=r()*6.28;
  let gi=0;
  const nz=mulberry((r()*4294967296)>>>0);       // grain noise (the comet above is fixed by the seed)
  // ---- state ----
  const parts=[];                                // ice grains {x,y,vx,vy,age,life}
  const rocks=[];                                // grit {x,y,vx,vy}
  const sparks=[];                               // {x,y,age,k}
  const pr={x:mir(118),y:down?122:28,vx:0,vy:0}; // the probe, parked away from the head
  const aim={x:pr.x,y:pr.y};
  let endT=null,hits=0,started=false,over=false,t=-PRE,acc=0,last=now(),t0=last,raf=0,ice=0,hurt=0,lastTick=0,said={},flash=0;
  const TARGET=Math.round(EMIT*(T-FADE/2)*[.62,.56,.5,.4,.3][D-1]); // ice for a full hold (tuned on the bot: it fills d3 about half the time)
  // background: stars and the sun's glow on its edge, drawn once
  const bg=document.createElement('canvas');bg.width=W;bg.height=H;{const b=bg.getContext('2d');b.fillStyle=P.void;b.fillRect(0,0,W,H);
    for(let y=PY;y<H;y++)for(let x=0;x<W;x++){const d=Math.hypot(x-sun.x,y-sun.y);   // the sun's limb just off the edge
      if(d<57){b.fillStyle=on(x,y,(57-d)/4)?P.warn:'#5a4320';b.fillRect(x,y,1,1)}
      else if(d<66){b.fillStyle=on(x,y,(66-d)/9)?'#5a4320':'#2a2216';b.fillRect(x,y,1,1)}
      else if(d<78&&on(x,y,(78-d)/12*.6)){b.fillStyle='#2a2216';b.fillRect(x,y,1,1)}}
    const sr=mulberry(ctx.seed^0x9e37);for(let i=0;i<55;i++){const x=Math.floor(sr()*W),y=PY+Math.floor(sr()*(H-PY));b.fillStyle=sr()<.2?P.cold:P.line;b.fillRect(x,y,1,1)}}
  function dirAt(h){const dx=h.x-sun.x,dy=h.y-sun.y,d=Math.hypot(dx,dy)||1;return{x:dx/d,y:dy/d}}
  function emit(h,hv,k){const d0=dirAt(h),n=EMIT*DT*k*(1-THIN*(.5+.5*Math.sin(t*2.6+phase2)));let c=Math.floor(n)+(nz()<n%1?1:0);
    while(c--){const sp=VS*(.7+.6*nz()),sd=(nz()-.5)*4,sa=(nz()<.5?-1:1)*SPLIT,ca=Math.cos(sa),sn=Math.sin(sa),d={x:d0.x*ca-d0.y*sn,y:d0.x*sn+d0.y*ca};
      parts.push({x:h.x+(nz()-.5)*2,y:h.y+(nz()-.5)*2,vx:d.x*sp-d.y*sd+hv.x*.4,vy:d.y*sp+d.x*sd+hv.y*.4,age:0,life:LIFE*(.7+.5*nz())})}}
  function spill(n){for(let i=0;i<n;i++){const a=nz()*6.28,s=10+nz()*18;parts.push({x:pr.x,y:pr.y,vx:Math.cos(a)*s+pr.vx*.3,vy:Math.sin(a)*s+pr.vy*.3,age:LIFE*.3,life:LIFE})}}
  // one fixed step; adv=false holds the head still (before the first press the tail streams but the pass waits)
  function sim(adv){
    const h=head(t),h2=head(t+DT),hv=adv?{x:(h2.x-h.x)/DT,y:(h2.y-h.y)/DT}:{x:0,y:0};
    const left=T-t,k=t<0?1:left>FADE?1:Math.max(0,left/FADE);
    if(t<T)emit(h,hv,k);
    // ice: drifts away from the sun, rippling across the tail's line
    for(let i=parts.length-1;i>=0;i--){const p=parts[i];p.age+=DT;if(p.age>=p.life||p.x<-4||p.x>W+4||p.y<PY-4||p.y>H+4){parts.splice(i,1);continue}
      const d=dirAt(p),dist=Math.hypot(p.x-h.x,p.y-h.y),w=CURL*Math.sin(dist*curlK-t*2.1+phase);
      p.vx+=(-d.y*w+d.x*4)*DT;p.vy+=(d.x*w+d.y*4)*DT;p.x+=p.vx*DT;p.y+=p.vy*DT}
    // grit leaves the head on the seed's schedule
    while(adv&&gi<grit.length&&t>=grit[gi].at){const q=grit[gi++],d=dirAt(h),a=Math.atan2(d.y,d.x)+q.off,s=VS*q.sp;
      rocks.push({x:h.x,y:h.y,vx:Math.cos(a)*s+hv.x*.4,vy:Math.sin(a)*s+hv.y*.4})}
    for(let i=rocks.length-1;i>=0;i--){const o=rocks[i];o.x+=o.vx*DT;o.y+=o.vy*DT;if(o.x<-4||o.x>W+4||o.y<PY-4||o.y>H+4)rocks.splice(i,1)}
    // the probe: a spring tether to the pointer, with drag (it lags, swings, overshoots)
    const kS=SPRING,kD=DAMP;pr.vx+=((aim.x-pr.x)*kS-pr.vx*kD)*DT;pr.vy+=((aim.y-pr.y)*kS-pr.vy*kD)*DT;
    pr.x+=pr.vx*DT;pr.y+=pr.vy*DT;
    if(pr.x<2){pr.x=2;pr.vx=Math.abs(pr.vx)*.4}if(pr.x>W-3){pr.x=W-3;pr.vx=-Math.abs(pr.vx)*.4}
    if(pr.y<PY+2){pr.y=PY+2;pr.vy=Math.abs(pr.vy)*.4}if(pr.y>H-3){pr.y=H-3;pr.vy=-Math.abs(pr.vy)*.4}
    if(adv)t+=DT;
    if(!started||over)return;
    hurt=Math.max(0,hurt-DT);flash=Math.max(0,flash-DT);
    // scoop: every grain inside the scoop is yours; young ice (near the head) counts double
    let got=0;for(let i=parts.length-1;i>=0;i--){const p=parts[i];if(Math.abs(p.x-pr.x)>CATCH||Math.abs(p.y-pr.y)>CATCH)continue;
      if((p.x-pr.x)**2+(p.y-pr.y)**2>CATCH*CATCH)continue;
      const v=p.age<p.life*DBL?2:1;got+=v;parts.splice(i,1);if(nz()<.5)sparks.push({x:Math.round(p.x),y:Math.round(p.y),age:0,k:v})}
    if(got){ice+=got;flash=.08;const n=now();if(n-lastTick>.085){lastTick=n;TK.sfx(ID,'tick')}}
    const f=ice/TARGET;
    if(f>=.5&&!said.half){said.half=1;pop.say('HALF FULL','goal',now())}
    if(T-t<FADE&&!said.fade&&f<1){said.fade=1;pop.say('TAIL FADING','neutral',now())}
    // hits: grit, or the head itself
    if(hurt<=0){let hitBy=null;
      for(const o of rocks)if(Math.hypot(o.x-pr.x,o.y-pr.y)<3.4){hitBy=o;break}
      const hd=Math.hypot(h.x-pr.x,h.y-pr.y);
      if(hitBy||hd<KEEP){const lost=Math.min(ice,Math.round(TARGET*SPILL));ice-=lost;spill(Math.min(18,lost));hurt=.9;hits++;
        const sx=hitBy?hitBy.vx*.9:(pr.x-h.x)/(hd||1)*60,sy=hitBy?hitBy.vy*.9:(pr.y-h.y)/(hd||1)*60;pr.vx+=sx;pr.vy+=sy;
        TK.sfx(ID,'hit');pop.say(hitBy?'GRIT HIT':'TOO CLOSE','bad',now())}}
    if(t>=T||f>=1)end();
  }
  function score(){return Math.max(0,Math.min(1,ice/TARGET))}
  function end(){if(over)return;over=true;endT=t;const s=score();if(s>=.5)TK.sfx(ID,'win');
    pop.finish(s>=.93?'HOLD FULL':s>=.5?'TAIL GONE':'TAIL LOST',s>=.93?'good':'neutral',now());
    ctx.done({score:s,detail:ice+' of '+TARGET+' ice, '+hits+' hits'})}
  // ---- drawing ----
  const CW=75,CH=65,dens=new Float32Array(CW*CH),blur=new Float32Array(CW*CH);
  function draw(){
    const n=now(),h=head(t);
    g.drawImage(bg,0,0);
    // the tail's glow: a density field on 2 px cells, blurred, dithered under the grains
    dens.fill(0);for(const p of parts){const cx=Math.floor(p.x/2),cy=Math.floor((p.y-PY)/2);if(cx>=0&&cx<CW&&cy>=0&&cy<CH)dens[cy*CW+cx]+=p.age<p.life*.5?1.5:1}
    for(let cy=0;cy<CH;cy++)for(let cx=0;cx<CW;cx++){let s=0;for(let j=-1;j<=1;j++)for(let i=-1;i<=1;i++){const x=cx+i,y=cy+j;if(x>=0&&x<CW&&y>=0&&y<CH)s+=dens[y*CW+x]*(i||j?(i&&j?.5:1):2)}blur[cy*CW+cx]=s/8}
    for(let y=PY;y<H;y++)for(let x=0;x<W;x++){const v=blur[((y-PY)>>1)*CW+(x>>1)];if(v<.35)continue;
      if(v>1.6&&on(x,y,Math.min(1,(v-1.6)/2.5))){g.fillStyle='#34495e';g.fillRect(x,y,1,1)}
      else if(on(x,y,Math.min(.9,v/1.4))){g.fillStyle=v>.9?'#26364a':P.line;g.fillRect(x,y,1,1)}}
    // the grains: bright when young, dimming as they age
    for(const p of parts){const f=p.age/p.life,x=Math.round(p.x),y=Math.round(p.y);if(y<PY)continue;
      g.fillStyle=f<.2?P.ice:f<.45?P.chill:f<.75?P.cold:'#3a4a5e';g.fillRect(x,y,1,1)}
    // the coma and the nucleus
    if(t<T+3){const hx=Math.round(h.x),hy=Math.round(h.y),fade=t<T?1:Math.max(0,1-(t-T)/3);
      for(let y=-7;y<=7;y++)for(let x=-7;x<=7;x++){const d=Math.hypot(x,y),k=(1-d/7.5)*fade;
        if(k>0&&on(hx+x,hy+y,k)){g.fillStyle=k>.55?P.chill:k>.3?P.cold:P.line;g.fillRect(hx+x,hy+y,1,1)}}
      const R=(x,y,w,hh,c)=>{g.fillStyle=c;g.fillRect(hx+x,hy+y,w,hh)};
      R(-1,-2,3,1,'#4a5a70');R(-2,-1,4,3,'#4a5a70');R(-1,2,3,1,'#4a5a70');R(-1,-1,2,1,P.cold);R(-2,0,1,1,P.cold);R(-1,0,1,1,P.ice)}
    // the keep-out ring round the head (red dashes, brighter when the probe is near), and the warning before a burst
    if(t<T+.5&&started){const hx=h.x,hy=h.y,near=Math.hypot(pr.x-hx,pr.y-hy)<KEEP+6,warn=bursts.some(b=>t>=b-WARN&&t<b+.1),
        blinkOn=Math.floor(n*10)%2===0,col=warn&&blinkOn||near?P.bad:'#5a2a22',N=Math.round(KEEP*1.6)*2;g.fillStyle=col;
      for(let a=0;a<N;a+=2){const an=a/N*6.283+t*.6;g.fillRect(Math.round(hx+Math.cos(an)*KEEP),Math.round(hy+Math.sin(an)*KEEP),1,1)}
      if(warn&&blinkOn){const gq=grit[gi],d=dirAt(h);if(gq){const a=Math.atan2(d.y,d.x)+gq.off;g.fillStyle='#5a2a22';   // the lane the burst will take
        for(let k=KEEP+2;k<KEEP+40;k+=3)g.fillRect(Math.round(hx+Math.cos(a)*k),Math.round(hy+Math.sin(a)*k),1,1)}}}
    // grit: dark rock with a red edge (danger) and a short red streak behind it, so a burst reads as a lane
    for(const o of rocks){const sp=Math.hypot(o.vx,o.vy)||1;g.fillStyle='#5a2a22';
      for(let k=2;k<=6;k+=2)g.fillRect(Math.round(o.x-o.vx/sp*k),Math.round(o.y-o.vy/sp*k),1,1)}
    for(const o of rocks){const x=Math.round(o.x),y=Math.round(o.y);g.fillStyle=P.bad;g.fillRect(x-1,y-1,3,3);g.fillStyle='#5a2a20';g.fillRect(x,y,2,2);g.fillStyle=P.bevelLo;g.fillRect(x,y,1,1)}
    // sparkles where ice was scooped
    for(let i=sparks.length-1;i>=0;i--){const s=sparks[i];s.age+=1/60;if(s.age>.26){sparks.splice(i,1);continue}
      const a=s.age<.09?1:s.age<.18?2:3,c=a===1?P.ice:a===2?P.chill:P.cold;g.fillStyle=a===1&&s.k>1?'#ffffff':c;g.fillRect(s.x,s.y,1,1);g.fillStyle=c;
      if(a<3){g.fillRect(s.x-a,s.y,1,1);g.fillRect(s.x+a,s.y,1,1);g.fillRect(s.x,s.y-a,1,1);g.fillRect(s.x,s.y+a,1,1)}else{g.fillRect(s.x-1,s.y-1,1,1);g.fillRect(s.x+1,s.y+1,1,1)}}
    // the tether: a dotted amber line from the pointer to the probe (once you have hold of it)
    if(started){const dx=pr.x-aim.x,dy=pr.y-aim.y,L=Math.hypot(dx,dy),steps=Math.floor(L/2);g.fillStyle='#8a4a16';
      for(let i=1;i<steps;i++){const u=i/steps;g.fillRect(Math.round(aim.x+dx*u),Math.round(aim.y+dy*u),1,1)}
      g.fillStyle=P.ember;const ax=Math.round(aim.x),ay=Math.round(aim.y);g.fillRect(ax-2,ay,1,1);g.fillRect(ax+2,ay,1,1);g.fillRect(ax,ay-2,1,1);g.fillRect(ax,ay+2,1,1)}
    // the probe: an amber scoop; a dotted ring shows its catch, it flashes when it scoops, blinks when hit
    {const x=Math.round(pr.x),y=Math.round(pr.y),blink=hurt>0&&Math.floor(n*12)%2===0;
      if(started&&!over){g.fillStyle='#5a3414';const rr=CATCH+1.2;for(let a=0;a<16;a+=2){const an=a/16*6.283;g.fillRect(Math.round(x+Math.cos(an)*rr),Math.round(y+Math.sin(an)*rr),1,1)}}
      if(!blink){g.fillStyle=P.bevelLo;g.fillRect(x-2,y-2,5,5);g.fillStyle=P.ember;g.fillRect(x-2,y-1,5,3);g.fillRect(x-1,y-2,3,5);
        g.fillStyle=flash>0?P.hot:P.flare;g.fillRect(x-1,y-1,2,1);g.fillStyle=P.bevelLo;g.fillRect(x,y,1,1)}}
    const left=Math.max(0,T-Math.max(0,over&&endT!=null?endT:t));
    KIT.header(g,{label:'ICE',meter:{w:57,frac:ice/TARGET,kind:'goal'},value:Math.round(Math.min(1,ice/TARGET)*100)+'%'},[['TIME',started?Math.ceil(left):Math.ceil(T)]]);
    KIT.tell(g,'SKIM THE ICE.',['drag'],n-t0);
    pop.draw(g,n);
  }
  function step(){const n=now();acc+=Math.min(.1,n-last);last=n;
    while(acc>=DT){acc-=DT;sim(started)}
    draw();raf=requestAnimationFrame(step)}
  // the tail is there when the glass opens
  while(t<0)sim(true);t=0;
  const onMove=e=>{if(over)return;const p=px.pt(e);aim.x=Math.max(1,Math.min(W-2,p.x));aim.y=Math.max(PY+1,Math.min(H-2,p.y))};
  const onDown=e=>{if(pop.click(now()))return;if(over)return;started=true;onMove(e)};
  px.cv.addEventListener('pointermove',onMove);px.cv.addEventListener('pointerdown',onDown);
  raf=requestAnimationFrame(step);
  return{
    destroy(){over=true;cancelAnimationFrame(raf);px.cv.removeEventListener('pointermove',onMove);px.cv.removeEventListener('pointerdown',onDown);px.destroy()},
    giveUp(){if(over)return;over=true;ctx.done({score:.3*score(),detail:'Gave up at '+ice+' of '+TARGET+' ice'})},
    // the film's bot: ride just behind the head in the dense young ice, weave across it, sidestep grit
    bot(tt,api){if(tt<1.2)return;
      if(!started)return[{type:'click',x:pr.x,y:pr.y}];
      const h=head(t+.25),d=dirAt(h),back=KEEP+4.5;
      let gx=h.x+d.x*back,gy=h.y+d.y*back;
      // a burst coming or in flight: sit beside its lane, on the side nearer the tail's middle
      let lat=Math.sin(t*2.2)*(3+back*SPLIT),lane=null;
      if(gi<grit.length&&grit[gi].at-t<WARN+.25)lane=grit[gi].off;
      else if(gi>0&&t-grit[gi-1].at<1.1)lane=grit[gi-1].off;
      if(lane!=null){const ll=back*Math.sin(lane),c1=ll+7.5,c2=ll-7.5;lat=Math.abs(c1)<Math.abs(c2)?c1:c2}
      gx+=-d.y*lat;gy+=d.x*lat;
      for(const o of rocks){const fx=o.x+o.vx*.3,fy=o.y+o.vy*.3,dd=Math.hypot(fx-pr.x,fy-pr.y);
        if(dd<7){const sx=-o.vy,sy=o.vx,sl=Math.hypot(sx,sy)||1,side=((pr.x-o.x)*sx+(pr.y-o.y)*sy)>=0?1:-1;gx+=sx/sl*side*6;gy+=sy/sl*side*6}}
      const p=api.pointer.x<0?{x:pr.x,y:pr.y}:api.pointer,dx=gx-p.x,dy=gy-p.y,dist=Math.hypot(dx,dy),v=Math.min(dist,2.6);
      return[{type:'move',x:p.x+(dist?dx/dist*v:0),y:p.y+(dist?dy/dist*v:0)}]},
  }}
TK.register({id:ID,name:'Skim',hint:'Skim the ice.',controls:['drag'],mount,
  sounds:{tick:'pulsar2_tick.wav',hit:'fourkelvin_bump.wav',win:{file:'fourkelvin_win.wav',off:300}}});
})();
