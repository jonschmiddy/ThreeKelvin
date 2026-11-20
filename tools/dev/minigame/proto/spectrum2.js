// Star Light: match a star's light. Each gas tube glows with its own coloured lines.
// Switch tubes on until your light matches the star's, line for line.
(function(){
'use strict';
const ID='spectrum2';
const BINS=21;
const CFG={
  1:{tray:3,pick:2,lines:[2,3],overlap:false,budget:false},
  2:{tray:4,pick:2,lines:[2,3],overlap:true, budget:false},
  3:{tray:5,pick:3,lines:[2,3],overlap:true, budget:false},
  4:{tray:6,pick:3,lines:[2,4],overlap:true, budget:false},
  5:{tray:7,pick:3,lines:[3,4],overlap:true, budget:false},
};
const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));

// ---------- logic ----------
function mkEl(rng,c,favour){
  const n=c.lines[0]+Math.floor(rng()*(c.lines[1]-c.lines[0]+1));
  for(let g=0;g<200;g++){
    const out=[];
    let guard=0;
    while(out.length<n&&guard++<100){
      const p=favour&&favour.length&&rng()<0.45?favour[Math.floor(rng()*favour.length)]:Math.floor(rng()*BINS);
      if(out.some(q=>Math.abs(q-p)<2))continue;
      out.push(p);
    }
    if(out.length===n)return out.sort((a,b)=>a-b);
  }
  return null;
}
const maskOf=l=>l.reduce((a,p)=>a|(1<<p),0);
function union(tray,set){let m=0;tray.forEach((e,i)=>{if(set&(1<<i))m|=maskOf(e)});return m}
function solutions(tray,target){const out=[];for(let s=1;s<(1<<tray.length);s++)if(union(tray,s)===target)out.push(s);return out}
function gen(rng,depth){
  const c=CFG[depth];
  for(let tries=0;tries<2000;tries++){
    const real=[];let bad=false;
    for(let i=0;i<c.pick;i++){const e=mkEl(rng,c,null);if(!e){bad=true;break}real.push(e)}
    if(bad)continue;
    if(!c.overlap){const ps=real.flat();if(new Set(ps).size!==ps.length)continue}
    const fav=[...new Set(real.flat())];
    const els=real.slice();
    while(els.length<c.tray){const e=mkEl(rng,c,fav);if(e)els.push(e)}
    const keys=els.map(e=>e.join(','));if(new Set(keys).size!==keys.length)continue;
    const order=els.map((_,i)=>i);for(let i=order.length-1;i>0;i--){const j=Math.floor(rng()*(i+1));[order[i],order[j]]=[order[j],order[i]]}
    const tray=order.map(i=>els[i]);let set=0;order.forEach((o,pos)=>{if(o<c.pick)set|=1<<pos});
    const target=union(tray,set);
    const sols=solutions(tray,target);
    if(sols.length!==1||sols[0]!==set)continue;
    // every decoy must share at least one line with the star, so it is a real choice
    if(tray.some((e,i)=>!(set&(1<<i))&&!(maskOf(e)&target)))continue;
    return {tray,set,target,depth};
  }
  throw new Error('spectrum2: no puzzle');
}
function scoreOf(toggles,minT,secs,t1){
  const extra=Math.max(0,toggles-minT),p=Math.max(0,1-0.1*extra);
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

TK.css(ID,`.spectrum2-cv{cursor:pointer}`);

function mount(stage,ctx){
  const P=gen(ctx.rng,ctx.depth),c=CFG[ctx.depth],s=ctx.sensors|0,PAL=TK.PAL;
  const T=P.tray.length,W=150,SX=21,BW=6,SW=BINS*BW,ROW=13,TY=50,H=TY+T*ROW+12;
  const pix=TK.pixel(stage,{w:W,h:H}),g=pix.g;pix.cv.classList.add('spectrum2-cv');
  // the rainbow, from palette hues: violet, blue, cyan, green, yellow, orange, red
  const HUES=[PAL.t3,PAL.t2,PAL.tractor,PAL.t1,PAL.hot,PAL.flare,PAL.bad];
  const binCol=b=>HUES[Math.min(6,Math.floor(b*7/BINS))];
  const GAS=[PAL.bad,PAL.hot,PAL.flare,PAL.t3,PAL.tractor,PAL.t4,PAL.ice,PAL.t2];
  const gasOf=TK.shuffle(GAS,ctx.rng).slice(0,T);
  let on=0,over=false,toggles=0,won=0,AC=null;const t0=performance.now();
  const broken=new Set(),locked=new Set();
  const realI=[],fakeI=[];P.tray.forEach((_,i)=>((P.set>>i)&1?realI:fakeI).push(i));
  const rr=TK.shuffle(realI,ctx.rng),ff=TK.shuffle(fakeI,ctx.rng);
  if(s>=1&&ff[0]!=null)broken.add(ff[0]);
  if(s>=5&&ff[1]!=null)broken.add(ff[1]);
  if(s>=3){locked.add(rr[0]);on|=1<<rr[0]}
  const minT=realI.length-locked.size;
  let power=c.budget?c.pick+3+(s>=2)+(s>=4):Infinity;const powerMax=power;
  const t1=18+8*ctx.depth+((s>=2)+(s>=4))*8;
  const fly=[];         // lines flying up to your strip
  const landT={};       // bin -> time it landed
  function tone(f,d,type,v,to){if(window.TK_MUTE_TONES)return;try{AC=AC||new (window.AudioContext||window.webkitAudioContext)();const t=AC.currentTime,o=AC.createOscillator(),gg=AC.createGain();o.type=type||'sine';o.frequency.setValueAtTime(f,t);if(to)o.frequency.exponentialRampToValueAtTime(to,t+d);gg.gain.setValueAtTime(v||.04,t);gg.gain.exponentialRampToValueAtTime(.0001,t+d);o.connect(gg).connect(AC.destination);o.start(t);o.stop(t+d+.02)}catch(e){}}

  // ---- static parts ----
  const bgc=document.createElement('canvas');bgc.width=W;bgc.height=H;const b=bgc.getContext('2d');
  R(b,0,0,W,H,PAL.panel);
  const strip=(y,h)=>{R(b,SX-1,y-1,SW+2,h+2,'#000');R(b,SX-2,y-2,SW+4,1,PAL.bevelLo);R(b,SX-2,y+h+1,SW+4,1,PAL.bevelHi);
    for(let x=0;x<SW;x++)for(let j=0;j<h;j++)R(b,SX+x,y+j,1,1,bay(SX+x,y+j)<.28?mix(binCol(x/BW),'#000000',.6):PAL.void)};
  strip(4,10);strip(22,10);
  TK.text(b,'STAR',2,7,PAL.chill);TK.text(b,'YOU',2,25,PAL.chill);
  for(let i=0;i<T;i++){const y=TY+i*ROW;strip(y+2,8)}
  R(b,0,TY-3,W,1,PAL.bevelLo);R(b,0,TY-2,W,1,PAL.bevelHi);

  const lineX=bin=>SX+bin*BW+2;
  function drawLine(x,y,h,col,glow,bright){
    if(glow>0)for(let j=0;j<h;j++){if(bay(x-1,y+j)<glow)R(g,x-1,y+j,1,1,mix(col,'#000000',.3));if(bay(x+2,y+j)<glow)R(g,x+2,y+j,1,1,mix(col,'#000000',.3))}
    R(g,x,y,2,h,bright?mix(col,'#ffffff',.5):col);R(g,x,y,1,h,bright?'#ffffff':mix(col,'#ffffff',.3));
  }
  function tube(i,x,y,now){
    const lit=(on>>i)&1,gc=gasOf[i];
    // glow halo
    if(lit){const fl=.35+.15*Math.sin(now/90+i*2);for(let xx=x-1;xx<=x+17;xx++){if(bay(xx,y-1)<fl)R(g,xx,y-1,1,1,mix(gc,'#000000',.4));if(bay(xx,y+9)<fl)R(g,xx,y+9,1,1,mix(gc,'#000000',.4))}}
    // metal caps
    R(g,x,y+1,3,7,'#000');R(g,x+1,y+2,2,5,PAL.cold);R(g,x+1,y+2,1,5,PAL.chill);
    R(g,x+15,y+1,3,7,'#000');R(g,x+15,y+2,2,5,PAL.cold);R(g,x+15,y+2,1,1,PAL.chill);
    // glass body
    R(g,x+3,y,12,1,'#000');R(g,x+3,y+8,12,1,'#000');
    if(lit){
      for(let xx=0;xx<12;xx++)for(let j=1;j<8;j++){const core=j>=3&&j<=5,f=bay(x+3+xx+((now/70)|0),y+j);
        R(g,x+3+xx,y+j,1,1,core?(f<.5?'#ffffff':mix(gc,'#ffffff',.55)):(f<.6?gc:mix(gc,'#000000',.3)))}
      R(g,x+4,y+1,10,1,mix(gc,'#ffffff',.7));
    }else{
      R(g,x+3,y+1,12,7,'#151c26');R(g,x+4,y+1,10,1,'#3d4d61');R(g,x+4,y+6,10,1,mix(gc,'#000000',.7));
      R(g,x+6,y+4,6,1,'#0b0f15');
    }
    if(broken.has(i)){R(g,x+3,y+1,12,7,'#0b0f15');R(g,x+6,y+1,1,2,PAL.chill);R(g,x+7,y+3,1,2,PAL.chill);R(g,x+8,y+5,1,1,PAL.chill);R(g,x+9,y+6,2,1,PAL.chill)}
    if(locked.has(i)){R(g,x+1,y,1,1,PAL.warn);R(g,x+16,y,1,1,PAL.warn);R(g,x+1,y+8,1,1,PAL.warn);R(g,x+16,y+8,1,1,PAL.warn)}
  }
  function render(now){
    g.drawImage(bgc,0,0);
    const mine=union(P.tray,on);
    // star lines
    for(let bn=0;bn<BINS;bn++)if((P.target>>bn)&1){const m=(mine>>bn)&1;drawLine(lineX(bn),4,10,binCol(bn),m?.7:.35,won||m&&landT[bn]&&now-landT[bn]<250)}
    // your lines, and links where they match
    for(let bn=0;bn<BINS;bn++){
      if(!((mine>>bn)&1)||fly.some(f=>f.bin===bn&&f.up))continue;
      const match=(P.target>>bn)&1,x=lineX(bn),age=landT[bn]?now-landT[bn]:999;
      if(match){
        drawLine(x,22,10,binCol(bn),.6,won||age<250);
        // the click: a bright bracket joins the two lines
        R(g,x,15,2,1,PAL.good);R(g,x,20,2,1,PAL.good);for(let y=16;y<20;y++)if(y%2===0||age<300)R(g,x,y,2,1,age<300?'#ffffff':PAL.good);
      }else{
        const wob=age<400?Math.round(Math.sin(age/40)*1):0;
        drawLine(x+wob,22,10,binCol(bn),0,false);R(g,x-1+wob,21,4,1,PAL.bad);R(g,x-1+wob,32,4,1,PAL.bad);
      }
    }
    // flying lines
    for(let k=fly.length-1;k>=0;k--){const f=fly[k],u=(now-f.t)/260;
      if(u>=1){fly.splice(k,1);if(f.up){landT[f.bin]=now;if((P.target>>f.bin)&1)tone(880+f.bin*30,.07,'square',.03,1200);else tone(140,.12,'square',.025)}continue}
      const y=Math.round(f.up?(f.y0+(22-f.y0)*u*u):(22+(f.y0-22)*u));
      drawLine(lineX(f.bin),y,f.up?10-Math.round(2*(1-u)):Math.max(1,10-Math.round(8*u)),binCol(f.bin),0,true)}
    // match meter
    const tc=P.tray.length,tgt=[];for(let bn=0;bn<BINS;bn++)if((P.target>>bn)&1)tgt.push(bn);
    const matched=tgt.filter(bn=>(mine>>bn)&1).length;let extras=0;for(let bn=0;bn<BINS;bn++)if(((mine>>bn)&1)&&!((P.target>>bn)&1))extras++;
    const frac=Math.max(0,matched-extras)/tgt.length;
    const MX=SX,MW=c.budget?84:SW,MY=36;
    R(g,MX-1,MY-1,MW+2,10,'#000');R(g,MX,MY,MW,8,PAL.void);
    const fw=Math.round(MW*frac);
    const mcol=frac===1&&!extras?PAL.good:extras?PAL.flare:PAL.t1;
    for(let x=0;x<fw;x++)for(let y=0;y<8;y++)R(g,MX+x,MY+y,1,1,y===0?mix(mcol,'#ffffff',.5):y>5?mix(mcol,'#000000',.35):mcol);
    for(let k=1;k<tgt.length;k++){const x=MX+Math.round(MW*k/tgt.length);R(g,x,MY,1,8,'#000')}
    TK.text(g,Math.round(frac*100)+'%',MX+MW-2,MY+2,frac>0.55?'#0a0e15':PAL.ice,'right');
    if(c.budget){TK.text(g,'PWR',MX+MW+5,MY+2,PAL.cold);for(let k=0;k<powerMax;k++)R(g,MX+MW+19+k*3,MY+1,2,6,k<power?PAL.ember:PAL.line)}
    // tube rows
    for(let i=0;i<T;i++){
      const y=TY+i*ROW,lit=(on>>i)&1;
      tube(i,1,y+1,now);
      for(const bn of P.tray[i]){const x=lineX(bn);if(broken.has(i)){R(g,x,y+4,2,4,'#1f2935');continue}drawLine(x,y+2,8,binCol(bn),lit?.5:0,false);if(!lit)R(g,x,y+2,2,8,mix(binCol(bn),'#000000',.55))}
    }
    if(won)TK.text(g,'MATCH!',W>>1,H-8,PAL.good,'center');
    else if(power<=0&&!over)TK.text(g,'NO POWER',W>>1,H-8,PAL.bad,'center');

    if(!toggles&&!over&&now-t0<4500)card(g,SX-2,18,SW+4,'MATCH THE STAR.',(now-t0)/1000);
    if(over&&!won)TK.text(g,'NO MATCH',W>>1,H-8,PAL.bad,'center');
  }
  function toggle(i,now){
    if(over||broken.has(i)||locked.has(i))return;
    if(power<=0)return;
    on^=1<<i;toggles++;TK.sfx('spectrum2','tube');if(c.budget)power--;
    const lit=(on>>i)&1,y=TY+i*ROW+2;
    for(const bn of P.tray[i]){
      // a line only flies if it changes your strip
      const still=union(P.tray,on);
      if(lit)fly.push({bin:bn,y0:y,t:now+Math.random()*60,up:true});
      else if(!((still>>bn)&1)){fly.push({bin:bn,y0:y,t:now,up:false});delete landT[bn]}
    }
    tone(lit?320:200,.18,'sawtooth',.02,lit?640:100);
    if(union(P.tray,on)===P.target){
      over=true;setTimeout(()=>{won=performance.now();TK.sfx('spectrum2','match');TK.sfx('spectrum2','win');tone(523,.25,'triangle',.05);setTimeout(()=>tone(784,.4,'triangle',.05),140)},300);
      const secs=(now-t0)/1000;
      ctx.done({score:scoreOf(toggles,minT,secs,t1),detail:`Matched in ${toggles} switch${toggles===1?'':'es'} (best ${minT})`});
      return;
    }
    if(c.budget&&power<=0){
      const mine=union(P.tray,on);let m=0,x=0,n=0;for(let bn=0;bn<BINS;bn++){const a=(mine>>bn)&1,t=(P.target>>bn)&1;if(t){n++;if(a)m++}else if(a)x++}
      over=true;ctx.done({score:0.2*Math.max(0,m-x)/n,detail:'Out of power, no match'});
    }
  }
  function onDown(e){
    e.preventDefault();const q=pix.pt(e);
    if(q.y>=TY&&q.y<TY+T*ROW)toggle(Math.floor((q.y-TY)/ROW),performance.now());
  }
  pix.cv.addEventListener('pointerdown',onDown);
  let raf=0,last=0,alive=true;
  const loop=now=>{if(!alive)return;raf=requestAnimationFrame(loop);if(now-last<32)return;last=now;render(now)};
  raf=requestAnimationFrame(loop);render(performance.now());
  return {
    _p:P,_row:i=>({x:60,y:TY+i*ROW+6}),
    destroy(){alive=false;over=true;cancelAnimationFrame(raf);pix.destroy();try{AC&&AC.close()}catch(e){}},
    giveUp(){if(over)return;over=true;ctx.done({score:0,detail:'Gave up after '+toggles+' switches'})},
  };
}

TK.register({
  id:ID,name:'Star Light',where:'Stars, nebulae',skill:'Pattern matching',
  blurb:'Light gas tubes until your light matches the star’s.',
  how:[
    'Each tube glows with its own coloured lines.',
    'Tap a tube to switch it on. Its lines jump up to YOUR strip.',
    'Match the STAR strip exactly: every line, no extras.',
  ],
  deeper:'More tubes, and tubes that share lines.',
  sensors:'1: one wrong tube burnt out. 3: one right tube starts on. 5: a second wrong tube burnt out. 2 and 4: more time.',
  hint:'Match the star.',controls:['click'],
  mount,
  _t:{gen,solutions,union,scoreOf,CFG,BINS},
});
})();
