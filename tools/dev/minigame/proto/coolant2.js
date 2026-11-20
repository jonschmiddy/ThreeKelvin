// Coolant Routing 2: pixel art at the ship's science terminal. Same rules as coolant.js.
(function(){
'use strict';
const ID='coolant2';
const DX=[0,1,0,-1],DY=[-1,0,1,0]; // dirs 0 N, 1 E, 2 S, 3 W; bit = 1<<dir
const OPP=d=>(d+2)%4;
const rotm=(m,k)=>{k=((k%4)+4)%4;for(let i=0;i<k;i++)m=((m<<1)|(m>>3))&15;return m};
const CFG={
  // empty: share of off-route squares left bare (fewer dead-end decoys); ok: share of route pipes dealt already right
  1:{w:5,h:4,valve:0,two:0,crack:0,secs:55,empty:0,ok:0},
  2:{w:5,h:5,valve:1,two:0,crack:0,secs:65,empty:.1,ok:.1},
  3:{w:6,h:5,valve:1,two:0,crack:2,secs:75,empty:.18,ok:.15},
  4:{w:6,h:6,valve:1,two:1,crack:2,secs:90,empty:.25,ok:.2},
  5:{w:7,h:6,valve:1,two:1,crack:3,secs:105,empty:.3,ok:.2},
};
const clamp=(v,a=0,b=1)=>Math.max(a,Math.min(b,v));

// ---------- logic: copied verbatim from coolant.js ----------
// Random self-avoiding walk from (sx,sy) that ends in the last column.
function walk(w,h,sx,sy,used,rng,minLen,maxLen,okEnd){
  for(let t=0;t<400;t++){
    const seen=new Set(used);const path=[[sx,sy]];seen.add(sy*w+sx);let x=sx,y=sy;
    while(path.length<=maxLen){
      if(x===w-1&&path.length>=minLen&&okEnd(y)&&rng()<0.65)return path;
      const opts=[];let tot=0;
      for(let d=0;d<4;d++){const nx=x+DX[d],ny=y+DY[d];if(nx<0||ny<0||nx>=w||ny>=h||seen.has(ny*w+nx))continue;const wt=d===3?0.3:1;opts.push([d,wt]);tot+=wt}
      if(!opts.length)break;
      let r=rng()*tot,d=opts[0][0];for(const[o,wt]of opts){if((r-=wt)<=0){d=o;break}}
      x+=DX[d];y+=DY[d];seen.add(y*w+x);path.push([x,y]);
    }
    if(x===w-1&&path.length>=minLen&&path.length<=maxLen&&okEnd(y))return path;
  }
  return null;
}
const dirTo=(a,b)=>{for(let d=0;d<4;d++)if(a[0]+DX[d]===b[0]&&a[1]+DY[d]===b[1])return d;return -1};

function gen(depth,sensors,rng){
  const c=CFG[depth];const{w,h}=c;
  for(let tries=0;tries<200;tries++){
    const r0=Math.floor(rng()*h);
    const main=walk(w,h,0,r0,[],rng,w+2,Math.floor(w*h*0.45),()=>true);
    if(!main)continue;
    const goal=new Array(w*h).fill(0);const onPath=new Array(w*h).fill(false);
    main.forEach((p,i)=>{const ind=i===0?3:OPP(dirTo(main[i-1],p));const out=i===main.length-1?1:dirTo(p,main[i+1]);goal[p[1]*w+p[0]]=(1<<ind)|(1<<out);onPath[p[1]*w+p[0]]=true});
    const rows=[main[main.length-1][1]];
    if(c.two){
      let ok=false;
      for(let a=0;a<60&&!ok;a++){
        const j=1+Math.floor(rng()*(main.length-2));const p=main[j];const pi=p[1]*w+p[0];
        const ds=[0,1,2,3].filter(d=>!(goal[pi]&(1<<d))).filter(d=>{const nx=p[0]+DX[d],ny=p[1]+DY[d];return nx>=0&&ny>=0&&nx<w&&ny<h&&!onPath[ny*w+nx]});
        if(!ds.length)continue;const d=ds[Math.floor(rng()*ds.length)];
        const used=[];onPath.forEach((v,i)=>{if(v)used.push(i)});
        const br=walk(w,h,p[0]+DX[d],p[1]+DY[d],used,rng,2,10,y=>Math.abs(y-rows[0])>=1);
        if(!br)continue;
        goal[pi]|=(1<<d);
        br.forEach((q,i)=>{const ind=i===0?OPP(d):OPP(dirTo(br[i-1],q));const out=i===br.length-1?1:dirTo(q,br[i+1]);goal[q[1]*w+q[0]]=(1<<ind)|(1<<out);onPath[q[1]*w+q[0]]=true});
        rows.push(br[br.length-1][1]);ok=true;
      }
      if(!ok)continue;
    }
    // tiles
    const tiles=[];
    for(let i=0;i<w*h;i++){
      if(onPath[i]){const g=goal[i];const str=(g===5||g===10);const u=rng();let k=str?(rng()<0.5?1:3):(u<0.42?3:u<0.82?2:1);/* turns needed: mostly 1 or 2 */if(rng()<c.ok)k=0;tiles.push({m:rotm(g,k),goal:g,path:true})}
      else if(rng()<c.empty)tiles.push({m:0,goal:null,path:false});
      else{const r=rng();const base=r<0.3?5:r<0.72?3:7;tiles.push({m:rotm(base,Math.floor(rng()*4)),goal:null,path:false})}
    }
    let valve=-1;
    if(c.valve){const cand=main.slice(1,-1).map(p=>p[1]*w+p[0]);valve=cand[Math.floor(rng()*cand.length)]}
    if(c.crack){
      const near=[];for(let i=0;i<w*h;i++){if(onPath[i]||!tiles[i].m)continue;const x=i%w,y=(i/w)|0;if([0,1,2,3].some(d=>{const nx=x+DX[d],ny=y+DY[d];return nx>=0&&ny>=0&&nx<w&&ny<h&&onPath[ny*w+nx]}))near.push(i)}
      const pick=shuffle(near,rng).slice(0,c.crack);
      if(pick.length<c.crack)continue;
      for(const i of pick)tiles[i].crack=true;
    }
    // sensors: some path tiles locked right
    // only tiles that still need turning, so every bolt is real help
    const nLock=Math.min(Math.max(0,sensors-1),Math.floor(main.length/3));
    const pidx=shuffle(tiles.map((t,i)=>t.path&&need(t)>0?i:-1).filter(i=>i>=0),rng).slice(0,nLock);
    for(const i of pidx){tiles[i].m=tiles[i].goal;tiles[i].lock=true}
    const P={w,h,r0,rows,tiles,valve,pathLen:main.length};
    P.par=par(P);
    if(win(P,flood(P)))continue; // never deal it solved
    return P;
  }
  throw new Error('coolant2: no puzzle');
}
function shuffle(a,r){a=a.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(r()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a}
function need(t){if(t.goal==null)return 0;for(let k=0;k<4;k++)if(rotm(t.m,k)===t.goal)return k;return 0}
function par(P){return P.tiles.reduce((s,t)=>s+need(t),0)}
function fixes(P){return P.tiles.filter(t=>need(t)>0).length}
// Seconds a competent player needs once they see the route: read the board, then about 3.5 s per
// pipe to turn and 0.6 s per extra quarter turn, plus time to think about each extra rule.
// Calibrated on Jon's runs (sector 1: 8 pipes in 40 s with a look round).
function paceSecs(P,depth){const c=CFG[depth],f=fixes(P);return 10+3.5*f+0.6*(P.par-f)+(c.valve?5:0)+(c.two?8:0)+2*c.crack}
// The heat limit: the sector's base time, stretched so a competent run always has 30% to spare.
function timeLimit(P,depth,sensors){return Math.max(CFG[depth].secs,Math.round(1.3*paceSecs(P,depth)))*(1+0.12*sensors)}
function flood(P){
  const{w,h,tiles}=P;const lit=new Map();const reached=P.rows.map(()=>false);const leaks=[];
  const s=P.r0*w;const q=[];
  if(tiles[s].m&8){lit.set(s,3);q.push(s)}
  while(q.length){
    const i=q.shift();const t=tiles[i];
    if(t.crack){leaks.push(i);continue}
    const x=i%w,y=(i/w)|0;
    for(let d=0;d<4;d++){
      if(!(t.m&(1<<d))||d===lit.get(i))continue;
      const nx=x+DX[d],ny=y+DY[d];
      if(nx<0||ny<0||nx>=w||ny>=h){if(d===1)P.rows.forEach((r,k)=>{if(r===y)reached[k]=true});continue}
      const j=ny*w+nx;if(lit.has(j))continue;
      if(tiles[j].m&(1<<OPP(d))){lit.set(j,OPP(d));q.push(j)}
    }
  }
  return{lit,reached,leaks};
}
function win(P,f){return f.reached.every(Boolean)&&(P.valve<0||f.lit.has(P.valve))&&f.leaks.length===0}
function scoreOf(heat,taps,par){
  const t=clamp((1-heat)/0.6);const r=clamp(1-Math.max(0,taps-par)/(par+4));
  return clamp(0.3+0.35*t+0.35*r);
}

const logic={gen,flood,win,par,need,rotm,scoreOf,CFG,fixes,paceSecs,timeLimit};
if(typeof TK==='undefined'){if(typeof module!=='undefined'&&module.exports)module.exports=logic;return}

// ---------- view: pixel art ----------
const W=144,E=14; // canvas width; core/chamber column width
function mount(stage,ctx){
  const P=gen(ctx.depth,ctx.sensors,ctx.rng);
  const{w,h,tiles}=P;
  const T=timeLimit(P,ctx.depth,ctx.sensors);
  const S=Math.min(18,Math.floor((W-4-2*E)/w),Math.floor(96/h))&~1; // tile size, even
  const GX=Math.floor((W-w*S)/2),GY=11,H=GY+h*S+19,TY=H-12; // bottom strip: hint with its icon, then status
  const px=TK.pixel(stage,{w:W,h:H});const g=px.g;const C=TK.PAL;
  const t0p=performance.now(),IW=(()=>{const c=document.createElement('canvas');c.width=40;c.height=14;return TK.icon(c.getContext('2d'),'click',0,0,{t:0})})();
  // extra steps of the palette hues
  const K={metalDk:'#4a586a',water:'#2a9e90',waterDk:'#1d6d65',plate:'#151d29',plateLk:'#1a2433',coreDk:'#7a3d12',chamber:'#0d1520',dry:'#364353'};
  let taps=0,over=false,heat=0,last=-1,phase=0,F=null,won=false,lost=false;const t0=Date.now();

  const R=(x,y,w_,h_,c)=>{g.fillStyle=c;g.fillRect(x,y,w_,h_)};
  const dot=(x,y,c)=>{g.fillStyle=c;g.fillRect(x,y,1,1)};
  function line(x0,y0,x1,y1,c){const dx=Math.abs(x1-x0),dy=-Math.abs(y1-y0),sx=x0<x1?1:-1,sy=y0<y1?1:-1;let e=dx+dy;for(;;){dot(x0,y0,c);if(x0===x1&&y0===y1)break;const e2=2*e;if(e2>=dy){e+=dy;x0+=sx}if(e2<=dx){e+=dx;y0+=sy}}}
  function ring(cx,cy,r,c){for(let y=-r-1;y<=r+1;y++)for(let x=-r-1;x<=r+1;x++){const d=Math.hypot(x+.5,y+.5);if(d>r-.5&&d<=r+.5)dot(cx+x,cy+y,c)}}
  function disc(cx,cy,r,c){for(let y=-r-1;y<=r+1;y++)for(let x=-r-1;x<=r+1;x++){if(Math.hypot(x+.5,y+.5)<=r)dot(cx+x,cy+y,c)}}
  // dithered glow ring: pixels between r0 and r1 lit with falling density
  function glow(cx,cy,r0,r1,c,k){const M=[0,2,3,1];for(let y=-r1;y<=r1;y++)for(let x=-r1;x<=r1;x++){const d=Math.hypot(x+.5,y+.5);if(d<r0||d>r1)continue;const t=(1-(d-r0)/(r1-r0))*k;if((M[((cy+y)&1)*2+((cx+x)&1)]+.5)/4<t)dot(cx+x,cy+y,c)}}
  // band of half-width hw along arm d of a tile at (x0,y0)
  function arm(x0,y0,d,hw){const cx=x0+S/2,cy=y0+S/2;
    if(d===0)return[cx-hw,y0,2*hw,cy+hw-y0];if(d===2)return[cx-hw,cy-hw,2*hw,y0+S-(cy-hw)];
    if(d===1)return[cx-hw,cy-hw,x0+S-(cx-hw),2*hw];return[x0,cy-hw,cx+hw-x0,2*hw]}
  function pipeArm(x0,y0,d){const[x,y,w_,h_]=arm(x0,y0,d,3);R(x,y,w_,h_,C.cold);
    if(d===0||d===2){R(x,y,1,h_,C.chill);R(x+5,y,1,h_,K.metalDk)}else{R(x,y,w_,1,C.chill);R(x,y+5,w_,1,K.metalDk)}}
  function drawTile(i){
    const t=tiles[i],x0=GX+(i%w)*S,y0=GY+((i/w)|0)*S,cx=x0+S/2,cy=y0+S/2;
    const lit=F.lit.has(i),leak=F.leaks.includes(i);
    // deck plate
    R(x0,y0,S,S,t.lock?K.plateLk:K.plate);R(x0,y0,S,1,C.line);R(x0,y0,1,S,C.line);R(x0,y0+S-1,S,1,C.bevelLo);R(x0+S-1,y0,1,S,C.bevelLo);
    const dirs=[0,1,2,3].filter(d=>t.m&(1<<d));
    if(dirs.length){
      for(const d of dirs){const[x,y,w_,h_]=arm(x0,y0,d,4);R(x,y,w_,h_,C.bevelLo)}
      for(const d of dirs)pipeArm(x0,y0,d);
      // hub flange, lit from the top-left
      R(cx-4,cy-4,8,8,C.bevelLo);R(cx-3,cy-3,6,6,C.cold);R(cx-3,cy-3,6,1,C.ice);R(cx-3,cy-3,1,6,C.chill);R(cx-3,cy+2,6,1,K.metalDk);R(cx+2,cy-3,1,6,K.metalDk);
      // joints at the tile edge
      for(const d of dirs){if(d===0)R(cx-4,y0,8,1,C.bevelLo);if(d===2)R(cx-4,y0+S-1,8,1,C.bevelLo);if(d===3)R(x0,cy-4,1,8,C.bevelLo);if(d===1)R(x0+S-1,cy-4,1,8,C.bevelLo)}
      // the channel: dry or carrying coolant
      const flow=lit&&!leak;
      const ent=lit?F.lit.get(i):-1,half=S/2;
      for(const d of dirs){
        for(let s=0;s<half;s++){ // s = distance from the tile edge
          const px_=d===0||d===2?cx-1:(d===3?x0+s:x0+S-1-s),py=d===1||d===3?cy-1:(d===0?y0+s:y0+S-1-s);
          let c=lit?C.tractor:K.dry;
          if(flow){const u=d===ent?s:S-s;if(((u-phase)%6+6)%6===0)c=C.mark;else if(((u-phase)%6+6)%6===1)c=C.tractor;else c=K.water}
          if(d===0||d===2)R(px_,py,2,1,c);else R(px_,py,1,2,c);
        }
      }
      if(lit)R(cx-1,cy-1,2,2,flow?K.water:C.tractor);else{R(cx-1,cy-1,2,2,C.cold);dot(cx-1,cy-1,C.chill)}
    }
    if(t.crack){
      const pts=[[.2,.08],[.38,.34],[.28,.5],[.56,.62],[.44,.8],[.72,.94]].map(([a,b])=>[x0+Math.round(a*(S-1)),y0+Math.round(b*(S-1))]);
      for(let k=1;k<pts.length;k++){line(pts[k-1][0]+1,pts[k-1][1],pts[k][0]+1,pts[k][1],C.bevelLo);line(pts[k-1][0],pts[k-1][1],pts[k][0],pts[k][1],C.bad)}
    }
    if(leak){ // coolant spraying out of the crack
      const M=[[.2,.25],[.75,.2],[.7,.75],[.25,.8],[.5,.12],[.85,.5],[.15,.5]];
      M.forEach(([a,b],k)=>{const f=((phase+k*3)%9)/9,xx=Math.round(cx+(a-.5)*S*(.4+.6*f)),yy=Math.round(cy+(b-.5)*S*(.4+.6*f));dot(xx,yy,f<.5?C.mark:C.tractor)});
    }
    if(i===P.valve){ // hand wheel
      const on=lit&&!leak,col=on?C.good:C.warn;
      ring(cx,cy,4,C.bevelLo);ring(cx,cy,3,col);R(cx-1,cy-3,2,6,col);R(cx-3,cy-1,6,2,col);R(cx-1,cy-1,2,2,C.bevelLo);
      dot(cx-3,cy-2,on?C.mark:C.hot);
    }
    if(t.lock)for(const[x,y]of[[x0+1,y0+1],[x0+S-3,y0+1],[x0+1,y0+S-3],[x0+S-3,y0+S-3]]){R(x,y,2,2,C.brace);dot(x+1,y+1,C.bevelLo)}
    if(i===last&&!over){R(x0,y0,S,1,C.ember);R(x0,y0+S-1,S,1,C.ember);R(x0,y0,1,S,C.ember);R(x0+S-1,y0,1,S,C.ember)}
  }
  function drawEnds(){
    // the core: a hot block whose glow grows with HEAT
    const cy=GY+P.r0*S+S/2,bx=GX-E,by=cy-6;
    const pulse=.5+.5*Math.sin(phase*0.25);
    glow(bx+5,cy,4,8+Math.round(heat*5),heat>.75?C.bad:C.flare,.35+.25*heat+.1*pulse);
    R(bx+9,cy-4,E-9,8,C.bevelLo);R(bx+9,cy-3,E-9,6,C.cold);R(bx+9,cy-3,E-9,1,C.chill);
    R(bx,by,11,12,C.bevelLo);R(bx+1,by+1,9,10,K.coreDk);
    const core=heat>.75?[C.bad,C.flare,C.hot]:[C.ember,C.flare,C.hot];
    R(bx+2,by+2,7,8,core[0]);R(bx+3,by+3,5,6,core[1]);R(bx+4,by+4,3,3+(pulse>.5?1:0),core[2]);
    R(bx+1,by+1,9,1,C.bevelHi);
    if(tiles[P.r0*w].m&8)R(bx+11,cy-1,GX-(bx+11),2,K.water);
    // chambers: frost over when coolant arrives
    P.rows.forEach((r,k)=>{
      const on=F.reached[k],y=GY+r*S+S/2,x=GX+w*S;
      R(x,y-4,3,8,C.bevelLo);R(x,y-3,3,6,C.cold);R(x,y-3,3,1,C.chill);R(x,y-1,3,2,on?K.water:C.bevelLo);
      const cx=x+3,ww=E-4;
      R(cx,y-7,ww,14,C.bevelLo);R(cx+1,y-6,ww-2,12,on?C.chill:K.chamber);
      if(on){TK.dither(g,cx+1,y-6,ww-2,12,C.chill,C.ice,.5);R(cx+2,y-5,ww-4,1,C.mark);
        for(let s=0;s<3;s++){const sx=cx+2+((s*4+(phase>>2))%(ww-4)),sy=y-4+((s*5)%9);dot(sx,sy,C.mark)}}
      else{for(let q=0;q<12;q+=2)dot(cx+1+(q%(ww-2)),y-6+q,C.line)}
      R(cx,y-7,ww,1,on?C.ice:C.cold);
    });
  }
  function hud(){
    TK.text(g,'HEAT',2,2,heat>.75?C.bad:C.chill);
    const bx=20,bw=W-2-62-bx;
    R(bx,2,bw,5,C.bevelLo);const fw=Math.round((bw-2)*heat);
    if(fw>0){R(bx+1,3,fw,3,heat>.75?C.bad:C.ember);R(bx+1,3,fw,1,heat>.75?C.flare:C.hot)}
    TK.text(g,`TURNS ${taps} PAR ${P.par}`,W-2,2,C.ice,'right');
    const n=F.reached.filter(Boolean).length,parts=[];
    let s;
    if(won)s=['ROUTED',C.good];else if(lost)s=['OVERHEAT',C.bad];
    if(s){TK.text(g,s[0],W/2,TY,s[1],'center');return}
    if(taps===0){const str='COOL THE SAMPLE.',tw=str.length*4-1,x0=Math.floor(W/2-(IW+5+tw)/2);
      TK.icon(g,'click',x0,TY-4,{t:(performance.now()-t0p)/1000});TK.text(g,str,x0+IW+5,TY,C.hot);return}
    parts.push([`COLD ${n}/${P.rows.length}`,n===P.rows.length?C.good:C.chill]);
    if(P.valve>=0)parts.push(F.lit.has(P.valve)?['VALVE OPEN',C.good]:['VALVE DRY',C.warn]);
    if(F.leaks.length)parts.push(['LEAK',C.bad]);
    const str=parts.map(p=>p[0]).join('  ');let x=Math.floor(W/2-(str.length*4-1)/2);
    for(const[t,c]of parts){TK.text(g,t,x,TY,c);x+=t.length*4+8}
  }
  function render(){px.clear(C.void);R(GX-1,GY-1,w*S+2,h*S+2,C.bevelLo);tiles.forEach((_,i)=>drawTile(i));drawEnds();hud()}
  function tap(i){
    if(over)return;
    tiles[i].m=rotm(tiles[i].m,1);taps++;last=i;TK.sfx('coolant2','turn');
    F=flood(P);
    if(win(P,F)){
      over=true;won=true;last=-1;clearInterval(timer);TK.sfx('coolant2','flow');TK.sfx('coolant2','win');
      const s=scoreOf(heat,taps,P.par);
      ctx.done({score:s,detail:`Routed at ${Math.round(heat*100)}% heat in ${taps} turns (par ${P.par})`});
    }
    render();
  }
  function onDown(e){
    if(over)return;e.preventDefault();
    const p=px.pt(e),x=Math.floor((p.x-GX)/S),y=Math.floor((p.y-GY)/S);
    if(x<0||y<0||x>=w||y>=h)return;const i=y*w+x;
    if(tiles[i].lock||!tiles[i].m)return;tap(i);
  }
  px.cv.addEventListener('pointerdown',onDown);
  px.cv.style.cursor='pointer';
  const timer=setInterval(()=>{
    if(over)return;
    heat=clamp((Date.now()-t0)/(T*1000));
    if(heat>=1){over=true;lost=true;clearInterval(timer);last=-1;render();ctx.done({score:0.1,detail:'Overheated before the route closed'})}
  },100);
  // ~30 fps for the flowing coolant
  let raf=0,lt=0;
  function loop(now){raf=requestAnimationFrame(loop);if(now-lt<33)return;lt=now;phase++;render()}
  F=flood(P);render();raf=requestAnimationFrame(loop);
  return{
    destroy(){over=true;clearInterval(timer);cancelAnimationFrame(raf);px.cv.removeEventListener('pointerdown',onDown);px.destroy()},
    giveUp(){if(over)return;over=true;clearInterval(timer);ctx.done({score:0,detail:'Gave up'})},
    _test:{P,px,get taps(){return taps},get over(){return over},GX,GY,S,tap},
  };
}

TK.register({
  id:ID,name:'Coolant Routing 2',hint:'Cool the sample.',controls:['click'],where:'Derelict reactors, hot stars',skill:'Spatial planning',
  blurb:'Turn pipe tiles to cool a sample chamber before the core overheats.',
  how:[
    'Pipes turn a quarter at a time.',
    'Join the hot core on the left to the chamber on the right.',
    'Finish before HEAT fills. Fewer turns score higher.',
  ],
  deeper:'Bigger grids, with more time to match. Sector 2+: coolant must pass the valve (the hand wheel). Sector 3+: cracked tiles leak if coolant reaches them. Sector 4+: a second chamber.',
  sensors:'Each point: the heat rises slower. 2+: some pipes start bolted in place, already turned right.',
  mount,
  _t:logic,
});
})();
