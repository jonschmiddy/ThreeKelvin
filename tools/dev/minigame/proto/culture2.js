// Culture Dish: the ship's microscope camera on a petri dish. Drop seed droplets, then press GROW:
// each press, the culture grows one ring outward, into every free spot that touches it.
// A faint ghost always shows the rings still to come. Reach every food speck; a stain kills what touches it.
(function(){
'use strict';
const ID='culture2';
const CFG={
  1:{R:4,s:6,steps:3,seeds:1,food:3,stain:3},
  2:{R:4,s:6,steps:3,seeds:2,food:4,stain:4},
  3:{R:5,s:5,steps:3,seeds:2,food:5,stain:6},
  4:{R:5,s:5,steps:3,seeds:3,food:6,stain:7},
  5:{R:5,s:5,steps:4,seeds:2,food:6,stain:6},
};
const DIRS=[[1,0],[1,-1],[0,-1],[-1,0],[-1,1],[0,1]];

// ---------- logic (hex dish) ----------
function board(R){
  const cells=[],idx=new Map();
  for(let q=-R;q<=R;q++)for(let r=-R;r<=R;r++){if(Math.abs(q+r)>R)continue;idx.set(q+','+r,cells.length);cells.push({q,r})}
  const nb=cells.map(c=>DIRS.map(d=>idx.get((c.q+d[0])+','+(c.r+d[1]))).filter(v=>v!=null));
  return {R,cells,nb};
}
function hd(B,a,b){const A=B.cells[a],C=B.cells[b];return(Math.abs(A.q-C.q)+Math.abs(A.r-C.r)+Math.abs(A.q+A.r-C.q-C.r))/2}
function shuffle(a,r){a=a.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(r()*(i+1));const t=a[i];a[i]=a[j];a[j]=t}return a}
// The one rule: each step, every free spot touching the culture grows. A spot on a stain dies and stays dead.
function simulate(B,steps,seeds,stains){
  const N=B.cells.length,alive=new Int8Array(N),born=new Int8Array(N).fill(-1),dead=new Set(),frames=[];
  for(const i of seeds){alive[i]=1;born[i]=0}
  for(let t=1;t<=steps;t++){
    const births=[];
    for(let i=0;i<N;i++){
      if(alive[i]||dead.has(i))continue;
      let par=-1;for(const j of B.nb[i])if(alive[j]&&born[j]<t){par=j;break}
      if(par>=0)births.push({i,par,ok:!(stains&&stains.has(i))});
    }
    for(const b of births){if(b.ok){alive[b.i]=1;born[b.i]=t}else dead.add(b.i)}
    frames.push(births);
  }
  return {alive,born,dead,frames};
}
function evaluate(p,seeds){
  const r=simulate(p.B,p.steps,seeds,new Set(p.stains));
  const covered=p.food.filter(f=>r.alive[f]).length,hits=r.dead.size;
  return {r,covered,hits,frac:Math.max(0,covered-hits)/p.food.length};
}
const wins=(p,sd)=>{const v=evaluate(p,sd);return v.frac===1&&v.hits===0};
function gen(rng,depth){
  const c=CFG[depth]||CFG[1],B=board(c.R),N=B.cells.length;
  for(let tries=0;tries<3000;tries++){
    const seeds=[];let ok=true;
    for(let k=0;k<c.seeds;k++){
      let placed=false;
      for(let a=0;a<60&&!placed;a++){
        const i=Math.floor(rng()*N);
        if(hd(B,i,0)>c.R-1)continue;
        if(seeds.some(j=>hd(B,i,j)<Math.min(4,c.steps+1)))continue;
        seeds.push(i);placed=true;
      }
      if(!placed){ok=false;break}
    }
    if(!ok)continue;
    const r=simulate(B,c.steps,seeds,null);
    // stains sit just past the reach, so a seed one spot off touches one
    const edge=[];for(let i=0;i<N;i++)if(!r.alive[i]&&B.nb[i].some(j=>r.alive[j]))edge.push(i);
    if(edge.length<c.stain)continue;
    const stains=[];for(const i of shuffle(edge,rng)){if(stains.every(s=>hd(B,s,i)>=2))stains.push(i);if(stains.length===c.stain)break}
    if(stains.length<c.stain)continue;
    // food sits near the far edge of the reach
    const cand=[];for(let i=0;i<N;i++)if(r.born[i]>=Math.max(2,c.steps-1))cand.push(i);
    const food=[];
    for(const i of shuffle(cand,rng).sort((a,b)=>r.born[b]-r.born[a])){if(food.every(f=>hd(B,f,i)>=2))food.push(i);if(food.length===c.food)break}
    if(food.length<c.food)continue;
    const p={B,R:c.R,steps:c.steps,nSeeds:c.seeds,food,stains,solution:seeds};
    if(!wins(p,seeds))continue;
    const banned=new Set(food.concat(stains));
    // every seed must matter
    if(seeds.length>1&&seeds.some((_,k)=>evaluate(p,seeds.filter((_,j)=>j!==k)).covered===food.length))continue;
    // few other winning spots: move one seed at a time, keep the rest
    let alt=0;
    for(let k=0;k<seeds.length&&alt<=2;k++)for(let i=0;i<N;i++){if(banned.has(i)||seeds.includes(i))continue;const sd=seeds.slice();sd[k]=i;if(wins(p,sd))alt++}
    if(alt>(tries<1500?1:2))continue;
    return p;
  }
  throw new Error('culture2: no puzzle');
}
function scoreOf(frac,idx,secs,t1){
  const tf=secs<=t1?1:Math.max(0,1-(secs-t1)/(2*t1));
  return Math.max(0,Math.min(1,frac*(1-0.15*idx)*(0.8+0.2*tf)));
}

// ---------- pixel helpers ----------
const B4=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5];
const bay=(x,y)=>(B4[(y&3)*4+(x&3)]+.5)/16;
function rgb(c){const n=parseInt(c.slice(1),16);return[n>>16&255,n>>8&255,n&255]}
function hx(a){return'#'+a.map(v=>Math.max(0,Math.min(255,Math.round(v))).toString(16).padStart(2,'0')).join('')}
function mix(a,b,t){const A=rgb(a),B=rgb(b);return hx(A.map((v,i)=>v+(B[i]-v)*t))}
function R(g,x,y,w,h,c){g.fillStyle=c;g.fillRect(x,y,w,h)}
function card(g,x,y,w,txt,t){const P=TK.PAL;R(g,x,y,w,19,P.bevelLo);R(g,x,y,w,1,P.ember);R(g,x,y+18,w,1,P.ember);const tw=txt.length*4-1,tot=16+tw,x0=x+((w-tot)>>1);if(TK.icon)TK.icon(g,'click',x0,y+3,{t});TK.text(g,txt,x0+16,y+7,P.hot)}
function circ(g,cx,cy,r,c,t){g.fillStyle=c;let x=r,y=0,e=1-r;const seen=new Set();
  while(x>=y){for(const[a,b]of[[x,y],[y,x],[-y,x],[-x,y],[-x,-y],[-y,-x],[y,-x],[x,-y]]){const X=cx+a,Y=cy+b,k=X*1000+Y;if(seen.has(k))continue;seen.add(k);if(t!=null&&bay(X,Y)>=t)continue;g.fillRect(X,Y,1,1)}
    y++;if(e<0)e+=2*y+1;else{x--;e+=2*(y-x)+1}}}
function disc(g,cx,cy,r,c,t){for(let y=-r;y<=r;y++)for(let x=-r;x<=r;x++){if(x*x+y*y>r*r+r*.6)continue;if(t!=null&&bay(cx+x,cy+y)>=t)continue;R(g,cx+x,cy+y,1,1,c)}}
function ball(g,cx,cy,r,ramp){const rr=r*r+r*.8;
  for(let y=-r;y<=r;y++)for(let x=-r;x<=r;x++){if(x*x+y*y>rr)continue;
    const edge=(x-1)*(x-1)+y*y>rr||(x+1)*(x+1)+y*y>rr||x*x+(y-1)*(y-1)>rr||x*x+(y+1)*(y+1)>rr;let col;
    if(edge)col=ramp[0];else{const nx=x/(r+.5),ny=y/(r+.5),nz=Math.sqrt(Math.max(0,1-nx*nx-ny*ny));const l=Math.max(0,-nx*.55-ny*.62+nz*.56);
      col=ramp[Math.max(1,Math.min(ramp.length-1,Math.round(l*(ramp.length-1)+bay(cx+x,cy+y)-.5)))]}
    g.fillStyle=col;g.fillRect(cx+x,cy+y,1,1)}}
function bevel(g,x,y,w,h,face,on){const P=TK.PAL;
  R(g,x,y,w,h,'#000');R(g,x+1,y+1,w-2,h-2,face);R(g,x+1,y+1,w-2,1,on?mix(face,'#ffffff',.35):P.bevelHi);R(g,x+1,y+1,1,h-2,on?mix(face,'#ffffff',.35):P.bevelHi);
  R(g,x+1,y+h-2,w-2,1,on?mix(face,'#000000',.4):P.bevelLo);R(g,x+w-2,y+1,1,h-2,on?mix(face,'#000000',.4):P.bevelLo)}
const easeOut=t=>1-Math.pow(1-t,3);
const easeBack=t=>{const c1=1.6,c3=c1+1;return 1+c3*Math.pow(t-1,3)+c1*Math.pow(t-1,2)};

TK.css(ID,`.culture2-cv{cursor:pointer}`);

function mount(stage,ctx){
  const p=gen(ctx.rng,ctx.depth),c=CFG[ctx.depth],s=ctx.sensors|0,B=p.B,N=B.cells.length;
  const PAL=TK.PAL;
  const W=150,H=140,CX=75,CY=60,AR=51,RO=57;
  const tries=2+(s>=1)+(s>=3)+(s>=5),t1=25+10*ctx.depth+((s>=2)+(s>=4))*10;
  const P=TK.pixel(stage,{w:W,h:H}),g=P.g;P.cv.classList.add('culture2-cv');
  const pos=B.cells.map(cl=>({x:Math.round(CX+c.s*Math.sqrt(3)*(cl.q+cl.r/2)),y:Math.round(CY+c.s*1.5*cl.r)}));
  const RAD=c.s*0.86;
  const foodSet=new Set(p.food),stainSet=new Set(p.stains);
  let hs=(p.food[0]*7919+p.solution[0]*104729+N)|1;const hr=()=>{hs=(hs*1103515245+12345)&0x7fffffff;return hs/0x7fffffff};

  // ---- colour ramps (palette hues, stepped) ----
  const GREEN=['#14301f','#2c5a40','#4f8a6c','#7fb89a','#b8f5d8'].map(rgb);
  const GREY=['#15181d','#2f353d','#4a525c','#6b7d94','#8fa3ba'].map(rgb);
  const AGAR=['#2c200d','#3d2d13','#523d1a','#6a5022','#83642b','#9c7834'].map(rgb);
  const DROP=['#0b3531','#1c7c72','#4fe0cc','#b8f5f0'];

  // ---- static background: bench, lamp, dish glass, agar, stains ----
  const bg=new Uint8ClampedArray(W*H*4);
  const put=(x,y,c)=>{if(x<0||y<0||x>=W||y>=H)return;const k=(y*W+x)*4;bg[k]=c[0];bg[k+1]=c[1];bg[k+2]=c[2];bg[k+3]=255};
  const VOID=rgb(PAL.void),PANEL=rgb(PAL.panel),LO=rgb(PAL.bevelLo);
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){
    const lamp=1-Math.hypot(x-30,y-18)/150;
    put(x,y,bay(x,y)<lamp*.9?PANEL:(bay(x,y)<lamp*1.6-.6?PANEL:VOID));
  }
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){const d=Math.hypot(x-CX-3,y-CY-4);if(d<=RO+1&&Math.hypot(x-CX,y-CY)>RO-1)put(x,y,bay(x,y)<.75?LO:VOID)}
  const noise=new Float32Array(W*H),phase=new Float32Array(W*H);
  for(let i=0;i<W*H;i++){noise[i]=hr();phase[i]=hr()}
  const sm=new Float32Array(W*H);
  for(let y=1;y<H-1;y++)for(let x=1;x<W-1;x++){let a=0;for(let j=-1;j<=1;j++)for(let i=-1;i<=1;i++)a+=noise[(y+j)*W+x+i];sm[y*W+x]=a/9}
  const dishIdx=[];
  for(let y=0;y<H;y++)for(let x=0;x<W;x++){
    const dx=x-CX,dy=y-CY,d=Math.hypot(dx,dy);
    if(d<=AR-0.5){
      dishIdx.push(y*W+x);
      const lit=.5+.32*(-dx-dy)/(AR*1.41)+(sm[y*W+x]-.5)*.5;
      let k=lit*(AGAR.length-1.2)+bay(x,y)-.5;
      put(x,y,AGAR[Math.max(1,Math.min(AGAR.length-2,Math.round(k)))]);
    }else if(d<=RO+.4){
      const a=Math.atan2(dy,dx),lt=(-Math.cos(a)-Math.sin(a))/1.41;
      let col;
      if(d>RO-.6||d<AR+.6)col=LO;
      else{const t=.45+.4*lt+(d>RO-2.5?.1:0);col=t+bay(x,y)*.3>.95?rgb(PAL.ice):t+bay(x,y)*.3>.62?rgb(PAL.chill):t>.25?rgb(PAL.cold):rgb('#3b4a5c')}
      put(x,y,col);
    }
  }
  for(const i of dishIdx){const x=i%W,y=i/W|0,d=Math.hypot(x-CX,y-CY);if(d>AR-2.2){const a=Math.atan2(y-CY,x-CX);if(Math.cos(a)+Math.sin(a)<.3||d>AR-1.2)put(x,y,AGAR[0])}}
  for(let a=-2.55;a<=-1.75;a+=0.01){const x=Math.round(CX+(RO-2)*Math.cos(a)),y=Math.round(CY+(RO-2)*Math.sin(a));put(x,y,[255,255,255])}
  for(let a=0.75;a<=1.0;a+=0.01){const x=Math.round(CX+(RO-2)*Math.cos(a)),y=Math.round(CY+(RO-2)*Math.sin(a));put(x,y,rgb(PAL.chill))}
  for(let k=0;k<26;k++){const a=hr()*Math.PI*2,r=hr()*(AR-6),x=Math.round(CX+r*Math.cos(a)),y=Math.round(CY+r*Math.sin(a));
    if(hr()<.5){put(x,y,AGAR[5]);put(x+1,y+1,AGAR[1])}else{put(x,y,AGAR[1])}}
  // stains: dark blots with a red rim
  const STA=['#120709','#21090d','#3a1013'].map(rgb),BAD=rgb(PAL.bad);
  for(const t of p.stains){
    const o=pos[t],rr=c.s*.95,wob=[hr(),hr(),hr()];
    for(let y=-9;y<=9;y++)for(let x=-9;x<=9;x++){
      const a=Math.atan2(y,x),d=Math.hypot(x,y),edge=rr*(1+.18*Math.sin(3*a+wob[0]*6)+.12*Math.sin(5*a+wob[1]*6));
      if(d>edge+1.2)continue;
      const X=o.x+x,Y=o.y+y;
      if(d>edge)put(X,Y,bay(X,Y)<.45?BAD:STA[2]);
      else put(X,Y,d<edge*.45?STA[0]:(d<edge*.8||bay(X,Y)<.5?STA[1]:STA[2]));
    }
  }
  for(const[a,b]of[[0,-1],[0,1],[-1,0],[1,0]])for(let k=0;k<3;k++)put(CX+a*(RO+3+k),CY+b*(RO+3+k),rgb(PAL.line));

  // ---- state ----
  const frame=new ImageData(W,H),FL=new Float32Array(W*H),FD=new Float32Array(W*H),inside=new Uint8Array(W*H);
  const STEPMS=520;
  let mode='place',attempt=0,best={frac:-1,idx:0,covered:0,hits:0},finished=false;
  let seeds=[];
  let touched=false,hover=-1,pressed=null,pressT=0,banner='',bannerCol=PAL.hot;
  const drops=[],parts=[],ripples=[],pulses=[];
  let run=null;               // {seeds, ev, stepT:[], seen, covered, hits}
  let buttons=[];
  const t0=performance.now();
  let AC=null;
  function tone(f,d,type,v,to){if(window.TK_MUTE_TONES)return;try{AC=AC||new (window.AudioContext||window.webkitAudioContext)();const t=AC.currentTime,o=AC.createOscillator(),gg=AC.createGain();o.type=type||'sine';o.frequency.setValueAtTime(f,t);if(to)o.frequency.exponentialRampToValueAtTime(to,t+d);gg.gain.setValueAtTime(v||.04,t);gg.gain.exponentialRampToValueAtTime(.0001,t+d);o.connect(gg).connect(AC.destination);o.start(t);o.stop(t+d+.02)}catch(e){}}

  function addField(F,bx,by,rad,wt){
    const Ri=rad*1.9,Ri2=Ri*Ri,x0=Math.max(0,Math.floor(bx-Ri)),x1=Math.min(W-1,Math.ceil(bx+Ri)),y0=Math.max(0,Math.floor(by-Ri)),y1=Math.min(H-1,Math.ceil(by+Ri));
    for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){const dx=x-bx,dy=y-by,d2=dx*dx+dy*dy;if(d2>=Ri2)continue;const u=1-d2/Ri2;F[y*W+x]+=u*u*wt}
  }
  function colonyBlobs(now){
    const out=[];
    if(!run)return out;
    for(const i of run.seeds)out.push({x:pos[i].x,y:pos[i].y,r:RAD,dead:false});
    run.stepT.forEach((st,k)=>{
      const el=now-st,u=Math.min(1,el/(STEPMS*0.75));
      for(const b of run.ev.r.frames[k]){
        const a=pos[b.par],z=pos[b.i],m=easeOut(u),gr=easeBack(Math.min(1,u*1.1));
        const x=a.x+(z.x-a.x)*m,y=a.y+(z.y-a.y)*m;let r=RAD*Math.max(.15,Math.min(1.08,gr)),dead=false;
        if(!b.ok){const w=Math.max(0,(el-STEPMS*.55)/(STEPMS*.5));if(w>0){dead=true;r=RAD*Math.max(.55,.9-.35*Math.min(1,w))}}
        out.push({x,y,r,dead});
      }
    });
    return out;
  }
  function render(now){
    const t=now-t0;
    if(run)tickRun(now);
    FL.fill(0);FD.fill(0);inside.fill(0);
    const blobs=colonyBlobs(now);
    for(const b of blobs)addField(b.dead?FD:FL,b.x,b.y,b.r,1);
    const buf=frame.data;buf.set(bg);
    if(blobs.length){
      for(const i of dishIdx){const v=FL[i]+FD[i];if(v<0.2)continue;const th=.5+(sm[i]-.5)*.55+.035*Math.sin(t/380+phase[i]*6.28);if(v>=th)inside[i]=1}
      for(const i of dishIdx){
        if(!inside[i])continue;
        const x=i%W,y=i/W|0,ramp=FD[i]>FL[i]?GREY:GREEN;
        let col;
        if(!inside[i-1]||!inside[i+1]||!inside[i-W]||!inside[i+W])col=ramp[0];
        else{
          const V=j=>FL[j]+FD[j];
          const gx=V(i+1)-V(i-1),gy=V(i+W)-V(i-W),v=V(i);
          let lv=2+(gx+gy)*5.5/(v+.4)+(v>1.15?.35:0);
          if(!inside[i-W-1]||!inside[i-2*W]||!inside[i-2])lv+=.8;
          if(!inside[i+W+1]||!inside[i+2*W])lv-=.9;
          let k=Math.round(lv+bay(x,y)-.5);k=Math.max(1,Math.min(4,k));
          if(k<4&&phase[i]>.992&&((t/140+phase[i]*40)|0)%5===0)k=4;
          col=ramp[k];
        }
        const q=i*4;buf[q]=col[0];buf[q+1]=col[1];buf[q+2]=col[2];
      }
    }
    g.putImageData(frame,0,0);
    // the ghost: every ring still to come, the next one brightest
    const gh=ghost();
    drawGhost(gh,t);
    // food specks
    for(const f of p.food){
      const o=pos[f];if(inside[o.y*W+o.x])continue;
      const tw=((t/220+f*3)|0)%9===0;
      R(g,o.x-2,o.y-1,5,3,PAL.bevelLo);R(g,o.x-1,o.y-2,3,5,PAL.bevelLo);
      R(g,o.x-1,o.y-1,2,2,PAL.ice);R(g,o.x+1,o.y,1,1,PAL.chill);R(g,o.x,o.y+1,1,1,PAL.chill);R(g,o.x-1,o.y-1,1,1,tw?'#ffffff':PAL.ice);
      if(gh){const fed=gh.fed.has(f);circ(g,o.x,o.y,4,fed?PAL.mark:PAL.bad,fed?.9:.55+.3*Math.sin(t/200))}
    }
    for(let k=pulses.length-1;k>=0;k--){const pu=pulses[k],u=(now-pu.t)/600;if(u>=1){pulses.splice(k,1);continue}
      circ(g,pu.x,pu.y,Math.round(3+u*9),PAL.mark,1-u);if(u>.15)circ(g,pu.x,pu.y,Math.round(2+u*6),PAL.hot,.7*(1-u))}
    // seeds
    if(mode==='place')for(const i of seeds){if(drops.some(d=>d.i===i))continue;ball(g,pos[i].x,pos[i].y,3,DROP)}
    if(run)for(const i of run.seeds)R(g,pos[i].x,pos[i].y,1,1,PAL.mark);
    for(let k=drops.length-1;k>=0;k--){
      const d=drops[k],u=(now-d.t)/280,o=pos[d.i];
      if(u>=1){drops.splice(k,1);splash(o.x,o.y,now);continue}
      const y=Math.round(o.y-34*(1-u*u));
      const sh=Math.round(1+u*2);R(g,o.x-sh,o.y+2,sh*2+1,1,'#1e160a');
      drawDrop(o.x,y);
    }
    for(let k=ripples.length-1;k>=0;k--){const r=ripples[k],u=(now-r.t)/450;if(u>=1){ripples.splice(k,1);continue}circ(g,r.x,r.y,Math.round(2+u*7),r.c,.8*(1-u))}
    for(let k=parts.length-1;k>=0;k--){const q=parts[k],u=(now-q.t)/q.life;if(u>=1){parts.splice(k,1);continue}
      R(g,Math.round(q.x+q.vx*u),Math.round(q.y+q.vy*u+10*u*u),1,1,q.c)}
    if(mode==='place'&&hover>=0&&!seeds.includes(hover)){const o=pos[hover];circ(g,o.x,o.y,4,PAL.tractor,.55)}
    TK.text(g,'TRY '+Math.min(attempt+1,tries)+'/'+tries,3,3,PAL.cold);
    TK.text(g,'X40',W-3,3,PAL.cold,'right');
    if(banner){const w=banner.length*4+7;R(g,CX-(w>>1),104,w,9,PAL.bevelLo);TK.text(g,banner,CX,106,bannerCol,'center')}
    if(!touched&&t<6000)card(g,CX-48,95,96,'EAT EVERY SPECK.',t/1000);
    drawPanel(now);
  }
  // what the ghost shows: the rings from here to the end, and which food they reach
  function ghost(){
    let sd,from;
    if(mode==='place'){
      sd=seeds.slice();
      if(hover>=0&&!seeds.includes(hover)&&!foodSet.has(hover)&&!stainSet.has(hover)){if(sd.length>=p.nSeeds)sd.shift();sd.push(hover)}
      if(!sd.length)return null;from=0;
    }else if(run&&mode==='grow'){sd=run.seeds;from=run.stepT.length}
    else return null;
    const r=sd===(run&&run.seeds)?run.ev.r:simulate(B,p.steps,sd,stainSet);
    const fed=new Set(p.food.filter(f=>r.alive[f]));
    return {r,from,fed,partial:mode==='place'&&sd.length<p.nSeeds};
  }
  function drawGhost(gh,t){
    if(!gh)return;
    const pulse=.55+.25*Math.sin(t/220);
    gh.r.frames.forEach((fr,k)=>{
      if(k<gh.from)return;
      const next=k===gh.from,a=next?pulse:Math.max(.18,.42-(k-gh.from)*.08);
      for(const b of fr){const o=pos[b.i];
        if(!b.ok){const fl=((t/250)|0)%2;R(g,o.x-2,o.y-2,1,1,PAL.bad);R(g,o.x+2,o.y-2,1,1,PAL.bad);R(g,o.x-1,o.y-1,3,3,fl?PAL.bad:'#5a1a14');R(g,o.x-2,o.y+2,1,1,PAL.bad);R(g,o.x+2,o.y+2,1,1,PAL.bad);continue}
        if(next){disc(g,o.x,o.y,Math.round(RAD)-1,PAL.mark,a*.3);circ(g,o.x,o.y,Math.round(RAD)-1,PAL.mark,a+.2);continue}
        // later rings: a seed-dot per spot, and the final edge outlined
        R(g,o.x-1,o.y-1,2,2,'#14301f');R(g,o.x-1,o.y-1,1,1,PAL.good);
        if(k===gh.r.frames.length-1)circ(g,o.x,o.y,Math.round(RAD)-1,PAL.good,.5);
      }
    });
  }
  function drawDrop(x,y){
    const rows=[[0,1],[0,1],[-1,2],[-1,2],[-2,3],[-2,3],[-2,3],[-1,2]];
    rows.forEach(([a,w],j)=>{R(g,x+a-1,y-7+j,w+2,1,DROP[0])});R(g,x-1,y+1,3,1,DROP[0]);
    rows.forEach(([a,w],j)=>{if(j===0)return;R(g,x+a,y-7+j,w,1,j<4?DROP[2]:DROP[1])});
    R(g,x-1,y-3,1,2,DROP[3]);
  }
  function splash(x,y,now){
    ripples.push({x,y,t:now,c:PAL.tractor});
    for(let k=0;k<7;k++){const a=-Math.PI*(.1+.8*k/6);parts.push({x,y,vx:Math.cos(a)*(5+hr()*4),vy:Math.sin(a)*(5+hr()*3),t:now,life:380+hr()*120,c:k%2?PAL.tractor:PAL.mark})}
    tone(900,.12,'sine',.04,300);
  }
  function animating(now){return run&&run.stepT.length&&now-run.stepT[run.stepT.length-1]<STEPMS*.9}
  function drawPanel(now){
    buttons=[];
    const y0=122;
    R(g,0,y0-1,W,1,PAL.bevelLo);R(g,0,y0,W,H-y0,PAL.panel);R(g,0,y0,W,1,PAL.bevelHi);
    const food=run?run.covered:0;
    const fx=62;R(g,fx,y0+6,3,3,PAL.ice);R(g,fx+1,y0+7,2,2,PAL.chill);
    TK.text(g,food+'/'+p.food.length,fx+6,y0+5,food===p.food.length?PAL.mark:PAL.ice);
    const btn=(x,w,label,on,fn)=>{const pr=pressed===label&&now-pressT<140;bevel(g,x,y0+2+(pr?1:0),w,14,on?PAL.ember:PAL.line,on);TK.text(g,label,x+(w>>1),y0+7+(pr?1:0),on?'#1a0e04':PAL.cold,'center');if(on)buttons.push({x,y:y0+1,w,h:16,label,fn})};
    if(mode==='place'){
      R(g,4,y0+7,11,3,PAL.bevelLo);R(g,5,y0+8,9,1,PAL.chill);R(g,14,y0+6,4,5,PAL.bad);R(g,15,y0+6,2,1,'#e07a66');R(g,2,y0+8,2,1,PAL.chill);
      for(let k=0;k<p.nSeeds;k++){const x=22+k*8;if(k<seeds.length)circ(g,x+1,y0+9,2,PAL.cold,.5);else ball(g,x+1,y0+9,2,DROP)}
    }
    if(mode==='place'||mode==='grow'){
      // growth steps left, as little rings
      const done=run?run.stepT.length:0;
      if(mode==='grow')for(let k=0;k<p.steps;k++){const x=6+k*9;circ(g,x,y0+9,3,k<done?PAL.cold:PAL.mark,k<done?.4:null);if(k>=done)R(g,x,y0+9,1,1,PAL.mark)}
      const can=mode==='place'?seeds.length===p.nSeeds:!animating(now)&&done<p.steps;
      btn(104,43,'GROW',can,grow);
    }else if(mode==='result'){
      btn(3,40,'KEEP',true,finish);
      btn(104,43,'AGAIN',true,again);
    }
  }

  function cellAt(x,y){let best=-1,bd=1e9;for(let i=0;i<N;i++){const d=Math.hypot(pos[i].x-x,pos[i].y-y);if(d<bd){bd=d;best=i}}return bd<=c.s*1.05?best:-1}
  function onDown(e){
    if(finished)return;e.preventDefault();touched=true;
    const q=P.pt(e);const now=performance.now();
    for(const b of buttons)if(q.x>=b.x&&q.x<b.x+b.w&&q.y>=b.y&&q.y<b.y+b.h){pressed=b.label;pressT=now;tone(220,.06,'square',.03);b.fn();return}
    if(mode!=='place')return;
    const i=cellAt(q.x,q.y);if(i<0)return;
    const at=seeds.indexOf(i);
    if(at>=0){seeds.splice(at,1);ripples.push({x:pos[i].x,y:pos[i].y,t:now,c:PAL.cold});tone(500,.08,'sine',.03,900);return}
    // phone: press and slide to see the rings this seed would grow (the mouse's hover preview), lift to drop it
    if(e.pointerType!=='mouse'){touchPend=e.pointerId;try{P.cv.setPointerCapture(e.pointerId)}catch(_){}hover=i;return}
    drop(i,now);
  }
  function drop(i,now){
    if(foodSet.has(i)||stainSet.has(i)){ripples.push({x:pos[i].x,y:pos[i].y,t:now,c:PAL.bad});tone(140,.12,'square',.03);return}
    if(seeds.includes(i))return;
    if(seeds.length>=p.nSeeds)seeds.shift();
    seeds.push(i);drops.push({i,t:now});TK.sfx('culture2','drop');
  }
  let touchPend=null;
  function onMove(e){
    if(e.pointerType!=='mouse'){if(touchPend!==e.pointerId)return;e.preventDefault();if(mode!=='place'){hover=-1;return}const q=P.pt(e);hover=cellAt(q.x,q.y);return}
    if(mode!=='place'){hover=-1;return}const q=P.pt(e);hover=cellAt(q.x,q.y)}
  function onUp(e){
    if(touchPend===null||touchPend!==e.pointerId)return;touchPend=null;
    const q=P.pt(e),i=e.type==='pointerup'?cellAt(q.x,q.y):-1;hover=-1;
    if(i>=0&&mode==='place'&&!finished)drop(i,performance.now());
  }
  P.cv.addEventListener('pointerdown',onDown);
  P.cv.addEventListener('pointermove',onMove);
  P.cv.addEventListener('pointerup',onUp);
  P.cv.addEventListener('pointercancel',onUp);
  P.cv.addEventListener('pointerleave',e=>{if(e.pointerType==='mouse')hover=-1});

  function grow(){
    const now=performance.now();
    if(mode==='place'){
      if(seeds.length!==p.nSeeds)return;
      mode='grow';banner='';hover=-1;
      run={seeds:seeds.slice(),ev:evaluate(p,seeds),stepT:[],seen:new Set(),covered:0,hits:0,doneT:0};
    }
    if(mode!=='grow'||animating(now)||run.stepT.length>=p.steps)return;
    run.stepT.push(now);TK.sfx('culture2','grow');
    tone(260+run.stepT.length*60,.25,'sine',.04,420+run.stepT.length*60);
  }
  function tickRun(now){
    run.stepT.forEach((st,k)=>{
      const el=now-st;
      for(const b of run.ev.r.frames[k]){
        if(run.seen.has(b.i))continue;
        if(b.ok&&el>=STEPMS*.6){run.seen.add(b.i);if(foodSet.has(b.i)){run.covered++;pulses.push({x:pos[b.i].x,y:pos[b.i].y,t:now});tone(660+run.covered*110,.18,'triangle',.05)}}
        if(!b.ok&&el>=STEPMS*.7){run.seen.add(b.i);run.hits++;tone(110,.3,'sawtooth',.03,60)}
      }
    });
    if(mode==='grow'&&run.stepT.length===p.steps&&now-run.stepT[p.steps-1]>STEPMS*1.1&&!run.doneT){
      run.doneT=now;
      const ev=run.ev;
      if(ev.frac>best.frac)best={frac:ev.frac,idx:attempt,covered:ev.covered,hits:ev.hits,secs:(now-t0)/1000};
      if(ev.frac===1&&!ev.hits){TK.sfx('culture2','win');banner='ALL FED';bannerCol=PAL.mark;mode='done';later(finish,900);return}
      banner=ev.covered+'/'+p.food.length+' FED'+(ev.hits?' '+ev.hits+' DEAD':'');bannerCol=ev.hits?PAL.flare:PAL.hot;
      if(attempt+1>=tries){mode='done';banner+=' . NO TRIES';later(finish,1300);return}
      mode='result';
    }
  }
  function again(){if(mode!=='result')return;attempt++;run=null;banner='';mode='place'}
  const timers=[];function later(f,ms){timers.push(setTimeout(f,ms))}
  function finish(){
    if(finished)return;finished=true;if(mode!=='done')mode='done';
    const bf=Math.max(0,best.frac);
    ctx.done({score:scoreOf(bf,best.idx,best.secs||999,t1),detail:best.frac<0?'Never grew':`Fed ${best.covered}/${p.food.length}${best.hits?', '+best.hits+' died':''} on try ${best.idx+1}`});
  }
  let raf=0,last=0,alive=true;
  const loop=now=>{if(!alive)return;raf=requestAnimationFrame(loop);if(now-last<32)return;last=now;render(now)};
  raf=requestAnimationFrame(loop);render(performance.now());
  return {
    _p:p,
    _pt:(i)=>pos[i],
    get _mode(){return mode},get _seeds(){return seeds.slice()},get _hover(){return hover},_n:N,
    destroy(){alive=false;cancelAnimationFrame(raf);timers.forEach(clearTimeout);P.destroy();try{AC&&AC.close()}catch(e){}},
    giveUp(){timers.forEach(clearTimeout);if(!finished){mode='done';finish()}},
  };
}

TK.register({
  id:ID,name:'Culture Dish',hint:'Eat every speck.',controls:['click'],where:'Living worlds',skill:'Prediction',
  blurb:'Drop seeds so the growing culture reaches every food speck and no stain.',
  how:[
    'Tap the dish to drop a seed. Tap it again to lift it. Press and slide to preview.',
    'Each GROW, the culture grows one ring out. The faint rings show where.',
    'Reach every white speck. A dark stain kills what touches it.',
  ],
  deeper:'Sector 2+: more seeds and more stains. Sector 3+: a bigger dish. Sector 4: three seeds. Sector 5: one more ring.',
  sensors:'1, 3, 5: one extra try. 2 and 4: more time for the speed bonus.',
  mount,
  _t:{CFG,board,simulate,evaluate,gen,scoreOf,wins},
});
})();
