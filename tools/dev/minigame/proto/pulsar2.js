// Pulsar Fold v2: turn the tuning dial until the pulses stack, then LOCK.
(function(){
'use strict';
const ID='pulsar2';

// ---------- logic ----------
const CFG={
  // round 3 (Jon: "Could be harder. Much harder."): noise from sector 1, a period that drifts while
  // you play, and from sector 3 a fainter decoy pulsar near the real one
  1:{N:1400,dec:false,noise:.62,two:false,chirp:false,drift:.05,decoy:false},
  2:{N:1400,dec:false,noise:.75,two:false,chirp:false,drift:.06,decoy:false},
  3:{N:1600,dec:true,noise:.65,two:false,chirp:false,drift:.03,decoy:true},
  4:{N:1600,dec:false,noise:.6,two:true,chirp:false,drift:.05,decoy:true},
  5:{N:1800,dec:true,noise:.75,two:false,chirp:true,drift:.035,decoy:true},
};
const PMIN=30,PMAX=58,B=40,WID=1.6;
const DRIFT_MAX=3;       // the drift wanders at most this far from the dealt period, then turns back
function int(r,lo,hi){return lo+Math.floor(r()*(hi-lo+1))}
function gauss(r){let u=0;while(!u)u=r();return Math.sqrt(-2*Math.log(u))*Math.cos(2*Math.PI*r())}
const U=v=>Math.round(v*10); // work in tenths

function pulses(N,P0,t0,chirp,amp){
  const sig=new Float64Array(N);let t=t0;
  while(t<N+5){
    const P=P0+chirp*(t/N-.5);
    for(let i=Math.max(0,Math.floor(t-5));i<=Math.min(N-1,Math.ceil(t+5));i++){const d=i-t;sig[i]+=amp*Math.exp(-d*d/(2*WID*WID))}
    t+=P;
  }
  return sig;
}
function fold(sig,Pf){
  const N=sig.length,R=Math.floor(N/Pf),rows=[],cnt=[];
  for(let r=0;r<R;r++){rows.push(new Float64Array(B));cnt.push(new Float64Array(B))}
  for(let i=0;i<R*Pf&&i<N;i++){const r=Math.floor(i/Pf);if(r>=R)break;const b=Math.min(B-1,Math.floor((i-r*Pf)/Pf*B));rows[r][b]+=sig[i];cnt[r][b]++}
  const prof=new Float64Array(B),pc=new Float64Array(B);
  for(let r=0;r<R;r++)for(let b=0;b<B;b++){if(cnt[r][b]){prof[b]+=rows[r][b];pc[b]+=cnt[r][b];rows[r][b]/=cnt[r][b]}}
  for(let b=0;b<B;b++)prof[b]=pc[b]?prof[b]/pc[b]:0;
  return {rows,prof};
}
// the folded profile alone, without the rows (the same numbers fold() gives, no allocations per row)
function profile(sig,Pf){const N=sig.length,R=Math.floor(N/Pf),end=Math.min(N,R*Pf),prof=new Float64Array(B),pc=new Float64Array(B);
  for(let i=0;i<end;i++){const r=Math.floor(i/Pf);if(r>=R)break;const b=Math.min(B-1,Math.floor((i-r*Pf)/Pf*B));prof[b]+=sig[i];pc[b]++}
  for(let b=0;b<B;b++)prof[b]=pc[b]?prof[b]/pc[b]:0;return prof}
// how sharp the folded profile is: smoothed peak over the mean
function sharp(prof){let m=0,pk=-1e9;for(let b=0;b<B;b++)m+=prof[b];m/=B;
  for(let b=0;b<B;b++){const v=.25*prof[(b+B-1)%B]+.5*prof[b]+.25*prof[(b+1)%B];if(v>pk)pk=v}return pk-m}
// how far the true periods have drifted after t seconds of play: a slow walk that turns back at DRIFT_MAX
function drift(g,t){const x=Math.abs(g.rate)*t,A=DRIFT_MAX,y=x%(4*A),v=y<A?y:y<3*A?2*A-y:y-4*A;return Math.sign(g.rate)*v}
function gen(rng,depth,sensors){
  const c=CFG[depth]||CFG[1],sn=sensors|0;
  const noise=c.noise*(1-.1*sn);
  const per=()=>c.dec?int(rng,U(PMIN+DRIFT_MAX),U(PMAX-DRIFT_MAX))/10:int(rng,PMIN+DRIFT_MAX,PMAX-DRIFT_MAX);
  for(let tries=0;tries<200;tries++){
    const P=[per()];
    if(c.two){let p2;do{p2=per()}while(Math.abs(p2-P[0])<8);P.push(p2)}
    // the decoy: a fainter pulsar 2.5 to 4 from the first one, clear of the second
    let decoy=null;
    if(c.decoy){for(let k=0;k<50&&decoy==null;k++){let d=P[0]+(rng()<.5?-1:1)*(2.5+rng()*1.5);d=c.dec?U(d)/10:Math.round(d);
      if(d<PMIN+1||d>PMAX-1||P.some(p=>Math.abs(p-d)<2.5))continue;decoy=d}
      if(decoy==null)continue}
    const chirp=c.chirp?(rng()<.5?-1:1)*(.45+rng()*.3):0;
    const clean=P.map((p,k)=>pulses(c.N,p,rng()*p,k?0:chirp,k?.85:1));
    if(decoy!=null)clean.push(pulses(c.N,decoy,rng()*decoy,0,.7));
    const sig=new Float64Array(c.N);
    for(let i=0;i<c.N;i++){let v=noise*gauss(rng);for(const cl of clean)v+=cl[i];sig[i]=v}
    let start;do{start=c.dec?int(rng,U(PMIN),U(PMAX))/10:int(rng,PMIN,PMAX)}while(P.some(p=>Math.abs(p-start)<6)||(decoy!=null&&Math.abs(decoy-start)<3));
    // sharpness at every tenth the effective setting (dial minus drift) can reach, on the noisy signal
    const step=c.dec?.1:1,S=new Map();
    for(let u=U(PMIN-DRIFT_MAX);u<=U(PMAX+DRIFT_MAX);u++)S.set(u,sharp(profile(sig,u/10)));
    const vals=[...S.values()].sort((a,b)=>a-b),base=vals[Math.floor(vals.length/2)];
    // each pulsar's own best setting near its period
    const peaks=P.map(p=>{let bu=U(p),bv=-1e9;for(const[u,v]of S)if(Math.abs(u-U(p))<=U(1.5)&&v>bv){bv=v;bu=u}return{u:bu,v:bv}});
    // the decoy's peak must read fainter than the weakest real one
    let dpk=0;
    if(decoy!=null){for(const[u,v]of S)if(Math.abs(u-U(decoy))<=U(.6))dpk=Math.max(dpk,v);
      if(dpk-base>.8*(Math.min(...peaks.map(q=>q.v))-base))continue}
    const rate=(rng()<.5?-1:1)*c.drift*(.7+.6*rng());
    return {cfg:c,P,sig,clean,start,chirp,noise,S,base,peaks,step,decoy,dpk,rate};
  }
  throw new Error('pulsar2: no deal');
}
// how close a lock is: within 0.6 of a dial step keeps it all, within 1.6 steps half, else a miss
function periodAcc(c,err,chirp){
  const unit=c.dec?.1:1;let k=err/unit;if(chirp)k=Math.max(0,k-1);
  return k<=.6?1:k<=1.6?.55:k<=3?.2:.05;
}
const ACCEPT=.5;         // a lock this close (period accuracy) holds; worse is a miss
// 0..1 lock-lamp glow at the EFFECTIVE setting Pe (dial minus drift), for the pulsars not locked yet.
// The lamp is honest: it is fully on (>= 0.9) only where a LOCK would hold, and white (1) only on an
// exact lock. Anything else, the decoy included, glows at most 0.8.
function glow(g,Pe,skip){
  const v=g.S.get(U(Pe));if(v==null)return 0;let best=0;
  const cl=x=>Math.max(0,Math.min(1,x));
  g.P.forEach((p,k)=>{if(skip&&skip.includes(k))return;const err=Math.abs(Pe-p);if(err>3)return;
    let s=cl((v-g.base)/Math.max(1e-6,g.peaks[k].v-g.base));const pa=periodAcc(g.cfg,err,!!(g.chirp&&k===0));
    s=pa>=1?1:pa>=ACCEPT?Math.max(.9,Math.min(.95,s)):Math.min(.8,s);best=Math.max(best,s)});
  if(g.decoy!=null&&Math.abs(Pe-g.decoy)<=3){const top=Math.max(...g.peaks.map(q=>q.v));
    best=Math.max(best,Math.min(.8,cl((v-g.base)/Math.max(1e-6,top-g.base))))}
  return best;
}
// The receiver's SIGNAL fades from full to nothing in this many seconds (from the first touch).
// Sector 4 has two pulsars to find, so its whole fade is longer but each pulsar gets less.
const FADE={1:28,2:26,3:30,4:40,5:30};
function fadeSecs(depth,sensors){return (FADE[depth]||28)*(1+.1*(sensors|0))}
const MISS=.3;           // a wrong LOCK costs this much signal
// what is left of the signal at the last lock sets how much of the accuracy you keep:
// 80%+ left keeps it all, then it falls in step with the signal
function keep(sig){return Math.max(0,Math.min(1,sig/.8))}
function finalScore(locks,nT,sig){
  let sum=0;for(const l of locks)sum+=l.pa;
  return (sum/nT)*keep(sig);
}
// the signal ran out or you gave up: locks already made still pay a little
function lostScore(locks,nT){let sum=0;for(const l of locks)sum+=l.pa;return .05+.15*sum/nT}

const logic={CFG,PMIN,PMAX,B,gen,fold,sharp,glow,periodAcc,finalScore,lostScore,fadeSecs,keep,drift,MISS,ACCEPT,FADE,U,DRIFT_MAX};
if(typeof TK==='undefined'){if(typeof module!=='undefined'&&module.exports)module.exports=logic;return}

// ---------- pixel view: the ship's radio receiver ----------
const PAL=TK.PAL;
function hex(c){return[parseInt(c.slice(1,3),16),parseInt(c.slice(3,5),16),parseInt(c.slice(5,7),16)]}
function shade(c,f){const[r,g,b]=hex(c),m=v=>Math.max(0,Math.min(255,Math.round(f<0?v*(1+f):v+(255-v)*f)));return'#'+[m(r),m(g),m(b)].map(v=>v.toString(16).padStart(2,'0')).join('')}
const BAY=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5];
const bay=(x,y)=>(BAY[(y&3)*4+(x&3)]+.5)/16;
function dot(g,x,y,c){g.fillStyle=c;g.fillRect(Math.round(x),Math.round(y),1,1)}
function line(g,x0,y0,x1,y1,c){x0=Math.round(x0);y0=Math.round(y0);x1=Math.round(x1);y1=Math.round(y1);
  const dx=Math.abs(x1-x0),dy=-Math.abs(y1-y0),sx=x0<x1?1:-1,sy=y0<y1?1:-1;let e=dx+dy;g.fillStyle=c;
  for(;;){g.fillRect(x0,y0,1,1);if(x0===x1&&y0===y1)break;const e2=2*e;if(e2>=dy){e+=dy;x0+=sx}if(e2<=dx){e+=dx;y0+=sy}}}
function bigText(g,s,x,y,col,tmp){const w=TK.text(tmp.g,s,0,0,col);void w;}

const W=144,H=124;
const CONTROLS=['dial'];
const ICW={click:13,hold:21,drag:22,'drag-h':22,'drag-v':22,dial:13};
// the start frame: the goal in words, the input as icons
function startCard(g,hint,ctl,cx,y,t,bg,edge){const tw=hint.length*4-1,iw=ctl.reduce((a,k)=>a+ICW[k]+4,-4),w=Math.max(tw,iw)+10,h=26,x=Math.round(cx-w/2);
  g.fillStyle=edge;g.fillRect(x-1,y-1,w+2,h+2);g.fillStyle=bg;g.fillRect(x,y,w,h);TK.text(g,hint,cx,y+3,TK.PAL.hot,'center');
  let ix=Math.round(cx-iw/2);for(const k of ctl){TK.icon(g,k,ix,y+11,{t});ix+=ICW[k]+4}}
const GX=12,GW=120;                 // waterfall / profile x span (40 bins x 3 px)
const RAWY=12,RAWH=13,WFY=27,WFH=40,PRY=69,PRH=16;
const DX=18,DY=106,DR=15;          // tuning dial
const SX=40,SW=100,SY=101;          // tuning strip
const LB={x:98,y:113,w:43,h:10};    // LOCK button

function mount(stage,ctx){
  const sn=ctx.sensors|0,g0=gen(ctx.rng,ctx.depth,sn),c=g0.cfg;
  let started=false,Pf=g0.start,finished=false,t0=performance.now(),lit=0,stampT=0,stampTxt='',msg='',raf=0,last=0,clock=0,dirty=true;
  const FADE_S=fadeSecs(ctx.depth,sn);let sig=1,burst=0,lost=false; // SIGNAL left (0..1); burst: glitch after a miss
  // the true periods drift while you play; the receiver folds at the dial minus that drift
  let play=0;const dNow=()=>drift(g0,play),Pe=()=>Pf-dNow();
  // the glitch pattern: re-rolled about 8 times a second so it tears and jitters without strobing
  let gl={t:-1,I:0,tear:[],noise:[],drop:[],jit:new Int8Array(WFH)},gseed=(ctx.seed|0)^0x5bd1e995;
  const grnd=()=>{gseed=(Math.imul(gseed,1103515245)+12345)|0;return((gseed>>>8)&0xffff)/65536};
  const locks=[],timers=[];let misses=0;
  const nT=g0.P.length;
  const fmt=v=>c.dec?v.toFixed(1):String(Math.round(v));
  const p=TK.pixel(stage,{w:W,h:H});const g=p.g;
  const RAMP=['#06110b',shade(PAL.good,-.72),shade(PAL.good,-.45),PAL.good,PAL.mark,'#effff7'];
  const RAMPON=['#06110b',shade(PAL.good,-.55),PAL.good,PAL.mark,'#effff7','#ffffff'];
  const ramp=(v,x,y,R)=>{const f=Math.max(0,Math.min(R.length-1.001,v*(R.length-1)));const i=Math.floor(f);return R[bay(x,y)<f-i?i+1:i]};
  // band for sensors 3+
  let band=null;
  if(sn>=3){const half=sn>=5?2.5:4;const tgt=g0.P[0];const lo=Math.max(PMIN,tgt-half+(ctx.rng()-.5)*half),hi=Math.min(PMAX,lo+2*half);band=[lo,hi]}
  const sxOf=v=>SX+Math.round((v-PMIN)/(PMAX-PMIN)*(SW-1));
  // a 2x text helper: draw small text on a scratch canvas and blow it up
  const tmp=document.createElement('canvas');tmp.width=40;tmp.height=5;const tg=tmp.getContext('2d');
  function text2(s,x,y,col){tg.clearRect(0,0,40,5);const w=TK.text(tg,s,0,0,col);g.imageSmoothingEnabled=false;g.drawImage(tmp,0,0,w,5,x,y,w*2,10);return w*2}

  // static plate
  const plate=document.createElement('canvas');plate.width=W;plate.height=H;const b=plate.getContext('2d');
  b.fillStyle=PAL.panel;b.fillRect(0,0,W,H);
  // bezel round the phosphor glass
  b.fillStyle=PAL.bevelHi;b.fillRect(1,1,W-2,1);b.fillRect(1,1,1,86);b.fillStyle=PAL.bevelLo;b.fillRect(1,87,W-2,1);b.fillRect(W-2,1,1,87);
  b.fillStyle='#06110b';b.fillRect(3,3,W-6,83);
  // graticule
  for(let x=GX;x<=GX+GW;x+=15)for(let y=WFY;y<WFY+WFH;y+=2)dot(b,x,y,'#0d2116');
  for(let y=WFY;y<=WFY+WFH;y+=10)for(let x=GX;x<GX+GW;x+=2)dot(b,x,y,'#0d2116');
  for(let x=4;x<W-4;x+=2){dot(b,x,RAWY+RAWH-4,'#0d2116');dot(b,x,PRY+PRH-1,'#0d2116')}
  // corner screws
  for(const[x,y]of[[4,90],[W-5,90],[4,H-4],[W-5,H-4]]){dot(b,x,y,PAL.cold);dot(b,x+1,y+1,PAL.bevelLo)}
  // dial face ring with detent marks
  for(let y=-DR-2;y<=DR+2;y++)for(let x=-DR-2;x<=DR+2;x++){const r=Math.hypot(x,y);if(r>DR+1.5)continue;
    dot(b,DX+x,DY+y,r>DR+.5?PAL.bevelLo:PAL.void)}
  void 0;
  TK.text(b,'PERIOD',SX,92,PAL.cold);
  // strip
  b.fillStyle=PAL.bevelLo;b.fillRect(SX-1,SY-1,SW+2,8);b.fillStyle='#0b120e';b.fillRect(SX,SY,SW,6);
  for(let v=PMIN;v<=PMAX;v+=2){const x=sxOf(v);b.fillStyle=v%10===0?PAL.cold:PAL.line;b.fillRect(x,SY+(v%10===0?0:3),1,v%10===0?6:3)}
  TK.text(b,String(PMIN),SX,SY+8,PAL.line);TK.text(b,String(PMAX),SX+SW,SY+8,PAL.line,'right');

  let cur=null;
  // how hard the video glitches: nothing above 50% signal, rising to full at 0, plus a burst after a miss
  function glitchI(){return Math.min(1,Math.max(0,(.5-sig)/.5)*.85+burst)}
  function rollGlitch(){
    const I=glitchI();gl.I=I;gl.tear=[];gl.noise=[];gl.drop=[];gl.jit.fill(0);if(I<=0)return;
    for(let y=RAWY;y<PRY+PRH;y+=2+Math.floor(grnd()*6)){const h=2+Math.floor(grnd()*(3+5*I));
      if(grnd()<.45*I)gl.tear.push([y,h,(grnd()<.5?-1:1)*(1+Math.floor(grnd()*(1+4*I)))])}
    if(grnd()<.6*I)gl.noise.push([RAWY+Math.floor(grnd()*(PRY+PRH-RAWY-3)),2+Math.floor(grnd()*2)]);
    if(grnd()<.35*I)gl.drop.push([WFY+Math.floor(grnd()*WFH),1+Math.floor(grnd()*2)]);
    for(let y=0;y<WFH;y++)if(grnd()<.5*I)gl.jit[y]=Math.round((grnd()-.5)*2*(1+2*I));
  }
  // tear rows sideways, lay static bands, drop lines: inside the glass only, never over the dial
  const snap=document.createElement('canvas');snap.width=W;snap.height=H;const sg=snap.getContext('2d');
  function applyGlitch(){
    if(gl.I<=0)return;
    sg.clearRect(0,0,W,H);sg.drawImage(p.cv,0,0);
    g.save();g.beginPath();g.rect(3,RAWY,W-6,PRY+PRH-RAWY);g.clip();
    for(const[y,h,dx]of gl.tear){g.fillStyle='#06110b';g.fillRect(3,y,W-6,h);g.drawImage(snap,3,y,W-6,h,3+dx,y,W-6,h)}
    for(const[y,h]of gl.noise)for(let yy=y;yy<y+h;yy++)for(let x=3;x<W-3;x++){const r=grnd();if(r<.35)dot(g,x,yy,r<.08?shade(PAL.good,-.2):r<.2?shade(PAL.good,-.5):'#0d2116')}
    for(const[y,h]of gl.drop){g.fillStyle='#06110b';g.fillRect(3,y,W-6,h)}
    g.restore();
  }
  function drawScreen(){
    const pe=Pe();cur=fold(g0.sig,pe);
    const skip=locks.map(l=>l.k);
    lit=finished&&locks.length?1:glow(g0,pe,skip);
    const on=lit>=.9,R=on?RAMPON:RAMP;
    // raw trace
    const n=Math.min(g0.sig.length,272);let py=null;
    for(let i=0;i<n;i+=2){const x=4+(i>>1),v=Math.max(g0.sig[i],g0.sig[i+1]||0),y=Math.round(RAWY+RAWH-4-v*6);const yy=Math.max(RAWY,Math.min(RAWY+RAWH-1,y));
      if(py!=null)line(g,x-1,py,x,yy,shade(PAL.good,-.2));py=yy}
    // stacked rows
    const rows=cur.rows,RN=rows.length;
    for(let y=0;y<WFH;y++){
      const r0=Math.floor(y*RN/WFH),r1=Math.max(r0+1,Math.floor((y+1)*RN/WFH));
      for(let bn=0;bn<B;bn++){
        let s=0;for(let r=r0;r<r1;r++){const row=rows[r];s+=.25*row[(bn+B-1)%B]+.5*row[bn]+.25*row[(bn+1)%B]}s/=(r1-r0);
        const v=Math.max(0,Math.min(1,(s-.12)/.75));if(v<.04)continue;
        for(let k=0;k<3;k++){const X=GX+bn*3+k+gl.jit[y],Y=WFY+y;g.fillStyle=ramp(v*.95,X,Y,R);g.fillRect(X,Y,1,1)}
      }
    }
    // profile
    let pk=0;for(let bn=1;bn<B;bn++)if(cur.prof[bn]>cur.prof[pk])pk=bn;
    for(let bn=0;bn<B;bn++){
      const v=Math.max(0,Math.min(1,(cur.prof[bn]+.05)/.75)),h=Math.round(v*(PRH-2));
      for(let k=0;k<3;k++){const X=GX+bn*3+k;
        for(let j=0;j<h;j++){const Y=PRY+PRH-2-j;g.fillStyle=j===h-1?(on?'#effff7':PAL.mark):(on?(bay(X,Y)<.6?PAL.good:shade(PAL.good,-.45)):(bay(X,Y)<.35?shade(PAL.good,-.35):shade(PAL.good,-.68)));g.fillRect(X,Y,1,1)}}
    }
    if(on)for(let y=WFY-2;y<PRY+PRH;y+=2)dot(g,GX+pk*3+1,y,PAL.ember);
  }
  function draw(){
    g.drawImage(plate,0,0);
    drawScreen();
    const on=lit>=.9;
    // header in the glass
    // SIGNAL: a segmented bar that drains, cold while strong, ember when it is nearly gone
    TK.text(g,'SIG',5,5,sig<.5?PAL.flare:PAL.chill);
    {const x0=19,segs=nT>1?19:22,lit_=Math.ceil(sig*segs-1e-9);
      g.fillStyle=PAL.bevelLo;g.fillRect(x0-1,4,segs*4+1,7);
      for(let k=0;k<segs;k++){const on=k<lit_,f=(k+1)/segs;
        const col=!on?'#0d1a14':sig<.15?PAL.bad:sig<.5?PAL.ember:sig<.8?PAL.cold:PAL.chill;
        const top=!on?'#0d1a14':sig<.5?PAL.flare:sig<.8?PAL.chill:PAL.ice;
        g.fillStyle=col;g.fillRect(x0+k*4,5,3,5);g.fillStyle=top;g.fillRect(x0+k*4,5,3,1);void f}
      if(nT>1)TK.text(g,Math.min(locks.length+1,nT)+'/'+nT,x0+segs*4+3,5,PAL.good)}
    TK.text(g,'LOCK',W-14,5,on?PAL.mark:shade(PAL.good,-.45),'right');
    // lamp: a bulb with a dithered halo that grows with the glow
    const lx=W-9,ly=7,a=Math.pow(lit,2);
    for(let y=-4;y<=4;y++)for(let x=-4;x<=4;x++){const r=Math.hypot(x,y);
      if(r<=2.2)dot(g,lx+x,ly+y,on?(r<1.2&&lit>=.99?'#ffffff':PAL.mark):a>.5?PAL.good:a>.2?shade(PAL.good,-.4):shade(PAL.good,-.7));
      else if(r<=4.2&&on&&bay(lx+x,ly+y)<(4.2-r)/2.6)dot(g,lx+x,ly+y,PAL.good)}
    if(stampTxt&&clock<stampT){const w=stampTxt.length*8;g.fillStyle='#06110b';g.fillRect(W/2-w/2-3,WFY+13,w+5,14);text2(stampTxt,W/2-w/2,WFY+15,stampTxt==='LOCKED'?PAL.mark:stampTxt==='LOCKED.'?PAL.mark:stampTxt==='NO LOCK'||stampTxt==='LOST'?PAL.bad:PAL.hot)}
    applyGlitch();
    if(msg)TK.text(g,msg,W/2,RAWY+RAWH-2,PAL.hot,'center');
    else if(!started)startCard(g,'TUNE IN THE PULSAR',CONTROLS,W/2,WFY+6,clock,'#06110b',PAL.good);
    // dial: knurled knob that turns with the period
    const rot=(Pf-PMIN)*36*Math.PI/180;
    for(let y=-DR;y<=DR;y++)for(let x=-DR;x<=DR;x++){const r=Math.hypot(x,y);if(r>DR-.5)continue;
      const lt=(-x-y)/DR;let col=lt>.5?PAL.chill:lt>0?PAL.cold:lt>-.5?PAL.line:PAL.bevelLo;
      if(r>DR-3){const ang=Math.atan2(y,x)-rot;if(((Math.floor((ang/(2*Math.PI))*24+48))&1))col=PAL.bevelLo}
      else if(r>DR-4)col=PAL.bevelLo;
      dot(g,DX+x,DY+y,col)}
    for(let y=-6;y<=6;y++)for(let x=-6;x<=6;x++){const r=Math.hypot(x,y);if(r<=6)dot(g,DX+x,DY+y,r>5?PAL.bevelLo:(-x-y)>3?PAL.cold:PAL.line)}
    const mx=DX+Math.sin(rot)*9,my=DY-Math.cos(rot)*9;g.fillStyle=PAL.ember;g.fillRect(Math.round(mx)-1,Math.round(my)-1,2,2);
    // readout
    text2(fmt(Pf),SX+28,90,on?PAL.mark:PAL.good);
    // sensors 3+: a coarse lit band near the period, riding the drift
    if(band){for(let x=sxOf(band[0]+dNow());x<=sxOf(band[1]+dNow());x++)for(let y=SY;y<SY+6;y++)if(x>=SX&&x<SX+SW&&bay(x,y)<.4)dot(g,x,y,shade(PAL.good,-.3))}
    // needle and locks on the strip
    for(const l of locks){const x=sxOf(l.Pf);g.fillStyle=PAL.good;g.fillRect(x,SY,1,6)}
    {const x=sxOf(Pf);g.fillStyle=PAL.ember;g.fillRect(x,SY-2,1,10);dot(g,x-1,SY-2,PAL.ember);dot(g,x+1,SY-2,PAL.ember)}
    // LOCK button
    const hot=on&&!finished,pressed=lockDown;
    g.fillStyle=PAL.bevelLo;g.fillRect(LB.x,LB.y,LB.w,LB.h);
    g.fillStyle=hot?PAL.good:PAL.line;g.fillRect(LB.x+1,LB.y+1+(pressed?1:0),LB.w-2,LB.h-2-(pressed?1:0));
    g.fillStyle=hot?PAL.mark:PAL.bevelHi;g.fillRect(LB.x+1,LB.y+1+(pressed?1:0),LB.w-2,1);
    TK.text(g,'LOCK',LB.x+(LB.w>>1),LB.y+3+(pressed?1:0),hot?'#0d1a12':finished?PAL.cold:PAL.ice,'center');
    if(hot&&Math.floor(clock*2)%2){for(let x=LB.x-1;x<=LB.x+LB.w;x+=2){dot(g,x,LB.y-2,PAL.good);dot(g,x+1,LB.y+LB.h+1,PAL.good)}}
  }
  function frame(now){raf=requestAnimationFrame(frame);if(now-last<32)return;const dt=Math.min(.1,(now-last)/1000);clock+=dt;last=now;
    if(started&&!finished){play+=dt;sig=Math.max(0,sig-dt/FADE_S);if(sig<=0)lose()}
    burst=Math.max(0,burst-dt*1.4);
    if(clock-gl.t>=.12||(gl.I>0&&glitchI()<=0)){gl.t=clock;rollGlitch()}
    draw()}
  function setP(v){const st=g0.step;let n=Math.round(v/st)*st;n=Math.max(PMIN,Math.min(PMAX,n));n=U(n)/10;if(n!==Pf){Pf=n;msg='';TK.sfx('pulsar2','tick');return true}return false}

  // input: drag round the dial (one turn = 10 on the period), tap or drag the strip to jump, tap LOCK
  const ptf=e=>{const r=p.cv.getBoundingClientRect();return{x:(e.clientX-r.left)*W/r.width,y:(e.clientY-r.top)*H/r.height}};
  let dr=null,sd=null,lockDown=false;
  const dAng=q=>Math.atan2(q.x-DX,-(q.y-DY))*180/Math.PI;
  const inLock=q=>q.x>=LB.x-2&&q.x<=LB.x+LB.w+2&&q.y>=LB.y-2&&q.y<=LB.y+LB.h+2;
  p.cv.addEventListener('pointerdown',e=>{
    if(finished)return;const q=ptf(e);if(q.y<88)return;started=true;e.preventDefault();try{p.cv.setPointerCapture(e.pointerId)}catch(_){}
    if(q.x<37){dr={id:e.pointerId,last:dAng(q),acc:Pf}}
    else if(inLock(q)){lockDown=e.pointerId}
    else if(q.y>=SY-4&&q.y<=SY+10&&q.x>=SX-3&&q.x<=SX+SW+3){sd={id:e.pointerId};setP(PMIN+(q.x-SX)/(SW-1)*(PMAX-PMIN))}
  });
  p.cv.addEventListener('pointermove',e=>{
    const q=ptf(e);
    if(dr&&e.pointerId===dr.id){e.preventDefault();let d=dAng(q)-dr.last;if(d>180)d-=360;if(d<-180)d+=360;dr.last=dAng(q);dr.acc=Math.max(PMIN,Math.min(PMAX,dr.acc+d/36));setP(dr.acc)}
    else if(sd&&e.pointerId===sd.id){e.preventDefault();setP(PMIN+(q.x-SX)/(SW-1)*(PMAX-PMIN))}
    else p.cv.style.cursor=!finished&&q.y>=88&&(q.x<37||inLock(q)||(q.y>=SY-4&&q.y<=SY+10))?'pointer':'default';
  });
  const up=e=>{if(dr&&e.pointerId===dr.id)dr=null;if(sd&&e.pointerId===sd.id)sd=null;
    if(lockDown!==false&&e.pointerId===lockDown){lockDown=false;if(e.type==='pointerup'&&inLock(ptf(e)))lock()}};
  p.cv.addEventListener('pointerup',up);p.cv.addEventListener('pointercancel',up);
  p.cv.addEventListener('wheel',e=>{if(finished)return;const q=ptf(e);if(q.y<88)return;e.preventDefault();setP(Pf+(e.deltaY<0?1:-1)*g0.step)},{passive:false});

  function lock(){
    if(finished)return;
    const free=g0.P.map((_,k)=>k).filter(k=>!locks.some(l=>l.k===k));
    const pe=Pe(),k=free.reduce((a,q)=>Math.abs(g0.P[q]-pe)<Math.abs(g0.P[a]-pe)?q:a,free[0]);
    const pa=periodAcc(c,Math.abs(g0.P[k]-pe),!!(g0.chirp&&k===0));
    if(pa<ACCEPT){ // a miss: the receiver drops signal and the video tears for a moment
      started=true;sig=Math.max(0,sig-MISS);burst=.9;gl.t=-1;stampTxt='NO LOCK';stampT=clock+1;misses++;
      if(sig<=0)lose();return}
    locks.push({k,Pf,pa,tru:g0.P[k]+dNow()});
    TK.sfx('pulsar2','lock');stampTxt=pa>=.7?'LOCKED':'WEAK';stampT=clock+1.2;
    if(locks.length<nT){msg='';return}
    finished=true;msg='';TK.sfx('pulsar2','win');
    const secs=(performance.now()-t0)/1000;
    const sc=finalScore(locks,nT,sig);stampT=clock+99;
    timers.push(setTimeout(()=>ctx.done({score:sc,detail:locks.map(l=>`P ${fmt(l.Pf)} (true ${fmt(l.tru)})`).join(', ')+`, ${Math.round(sig*100)}% signal left, ${Math.round(secs)} s`}),900));
  }
  // the signal ran out: the lock is lost; any pulsar already locked still pays a little
  function lose(){
    if(finished)return;finished=true;lost=true;sig=0;stampTxt='LOST';stampT=clock+99;
    const sc=lostScore(locks,nT);
    timers.push(setTimeout(()=>ctx.done({score:sc,detail:`Signal lost, ${locks.length}/${nT} locked`}),900));
  }
  draw();raf=requestAnimationFrame(frame);
  return {
    destroy(){finished=true;cancelAnimationFrame(raf);timers.forEach(clearTimeout);p.destroy()},
    giveUp(){if(finished)return;finished=true;timers.forEach(clearTimeout);
      ctx.done({score:locks.length?lostScore(locks,nT):0,detail:'Gave up'})},
    _test:{get sig(){return sig},set sig(v){sig=v},get glitch(){return gl.I},get misses(){return misses},lock:()=>lock(),setP:v=>setP(v),get Pf(){return Pf},get Pe(){return Pe()},set play(v){play=v},get lit(){return lit},get locks(){return locks.length},cv:p.cv,g:g0,DX,DY,LB,SX,SW,SY},
  };
}

TK.register({
  id:ID,name:'Pulsar Fold 2',hint:'Tune in the pulsar.',controls:CONTROLS,where:'Pulsars, neutron stars',skill:'Pattern finding',
  blurb:'Tune a receiver until a hidden pulse stacks into a line.',
  how:[
    'The signal stacks in rows. A leaning line means the period is off.',
    'A straight line lights the lamp. White is exact. LOCK it then.',
    'SIG fades from the first touch. The period drifts, so keep tuning.',
    'A wrong LOCK costs a lot of signal. Fast, exact locks score most.',
  ],
  deeper:'Sector 2+: more noise, faster fade. Sector 3+: periods to 0.1, and a fainter decoy pulsar nearby. Sector 4: two pulsars, find both. Sector 5: the pulse itself speeds up or slows.',
  sensors:'Each point: less noise and a 10% slower fade. 3+: a lit band on the scale near the period. 5: a narrower band.',
  mount,
  _t:logic,
});
})();
