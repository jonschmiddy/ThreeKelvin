// Four Kelvin: turn and thrust a probe east through an asteroid belt. Further in, richer ore.
// W thrust, A/D turn (arrows mirror). Touch: two turn buttons bottom-left, thrust bottom-right.
(function(){
const ID='fourkelvin';
const W=140,H=112,VY=10,BH=82,SHIPX=46,DT=1/30;   // view: HUD 0-9, belt rows 10-91, bar 93-95, buttons 96-111
const TURN=3.6,ACC=72,DRAG=0.9,VMAX=52,HULLN=2;     // rad/s, px/s^2, 1/s, px/s, hull blocks before shields
const SHIPR=3.2,FACINGS=32,LEAD=70,NODE=48;
const CFG=[null,
  {hw:18,  step:10,dens:95, amp:2,spinLo:0.2,spinHi:0.6,len:1150},
  {hw:16,  step:12,dens:120,amp:3,spinLo:0.3,spinHi:0.9,len:1250},
  {hw:14.5,step:14,dens:145,amp:4,spinLo:0.4,spinHi:1.2,len:1350},
  {hw:13,  step:16,dens:165,amp:5,spinLo:0.5,spinHi:1.5,len:1450},
  {hw:12,  step:18,dens:185,amp:6,spinLo:0.6,spinHi:1.8,len:1550}];

// ---------- field: rocks keep clear of a hidden lane (by their full drift), so every seed has a way through ----------
function mkRock(rng,x,y,r,c){
  const prof=new Float32Array(32),a2=rng(),a3=rng(),p2=rng()*6.28,p3=rng()*6.28,p5=rng()*6.28,k=r<3.5?0.5:1;
  for(let i=0;i<32;i++){const t=i/32*6.2832;prof[i]=r*(1+k*(0.13*a2*Math.cos(2*t+p2)+0.1*a3*Math.cos(3*t+p3)+0.05*Math.cos(5*t+p5)))}
  const craters=[];if(r>=4){const n=1+Math.floor(rng()*(r>7?3:2));for(let i=0;i<n;i++){const a=rng()*6.28,d=rng()*0.55*r;craters.push({x:Math.cos(a)*d,y:Math.sin(a)*d,r:0.9+rng()*r*0.2})}}
  const da=rng()*6.28,am=c.amp*(0.4+0.6*rng());
  return {x,y,r,prof,craters,rot0:rng()*6.28,rs:(rng()<.5?-1:1)*(c.spinLo+rng()*(c.spinHi-c.spinLo)),rust:rng()<0.3,
    ax:Math.cos(da)*am,ay:Math.sin(da)*am,w1:0.25+rng()*0.35,w2:0.25+rng()*0.35,p1:rng()*6.28,p2:rng()*6.28,amp:am};
}
function gen(rng,depth){
  const c=CFG[depth],target=c.len,len=target+W+40;
  const nodes=[];let y=BH/2;const lo=c.hw+3,hi=BH-c.hw-3;
  for(let i=0;i*NODE<=len+NODE*2;i++){if(i>1){y+=(rng()*2-1)*c.step;y=Math.max(lo,Math.min(hi,y))}nodes.push(y)}
  const cen=x=>{x=Math.max(0,x);const i=Math.floor(x/NODE),f=x/NODE-i;const a=nodes[Math.min(i,nodes.length-1)],b=nodes[Math.min(i+1,nodes.length-1)];return a+(b-a)*f*f*(3-2*f)};
  const clear=(x,yy,R)=>{for(let xs=x-R-c.hw;xs<=x+R+c.hw;xs+=1)if(Math.hypot(xs-x,cen(xs)-yy)<R+c.hw)return false;return true};
  const rocks=[];const want=Math.round(c.dens*len/1000);
  for(let t=0;t<want*6&&rocks.length<want;t++){
    const u=rng();const r=u<0.5?2.8+rng()*2:u<0.82?4.8+rng()*3:7.8+rng()*4;
    const x=LEAD+r*1.3+c.amp+rng()*(len-LEAD),yy=-3+rng()*(BH+6);
    const o=mkRock(rng,x,yy,r,c);
    if(!clear(x,yy,r*1.15+0.5+o.amp))continue;
    if(rocks.some(q=>Math.abs(q.x-x)<q.r+r+q.amp+o.amp+2&&Math.hypot(q.x-x,q.y-yy)<(q.r+r)*0.8+q.amp+o.amp+1))continue;
    rocks.push(o);
  }
  rocks.sort((a,b)=>a.x-b.x);
  // ore glints sit in the lane; their tier climbs with distance
  const glints=[];let gx=LEAD+10;
  while(gx<target-10){const tier=Math.min(4,Math.floor(gx/target*5));glints.push({x:gx,y:cen(gx)+(rng()*2-1)*(c.hw-6),tier,val:tier+1,got:false,ph:rng()*6});gx+=50+rng()*35}
  return {rocks,glints,cen,nodes,hw:c.hw,target,depth};
}
function rockPos(o,t){return {x:o.x+o.ax*Math.sin(o.w1*t+o.p1),y:o.y+o.ay*Math.sin(o.w2*t+o.p2)}}
function lower(arr,x){let lo=0,hi=arr.length;while(lo<hi){const m=(lo+hi)>>1;if(arr[m].x<x)lo=m+1;else hi=m}return lo}
function shields(sens){return Math.ceil((sens|0)/2)}   // blue blocks: one at 1, 3 and 5
function scoreOf(F,dist,oreVal){
  const tot=F.glints.reduce((a,g)=>a+g.val,0)||1;
  return Math.max(0,Math.min(1,0.65*Math.max(0,Math.min(1,dist/F.target))+0.35*Math.min(1,oreVal/tot)));
}

// ---------- drawing ----------
const P=TK.PAL;
function rgb(h){const n=parseInt(h.slice(1),16);return (255<<24)|((n&255)<<16)|(n&0xff00)|((n>>16)&255)}
const C={};for(const k in P)C[k]=rgb(P[k]);
const STONE=['#080b11','#141b25','#22303f','#3d4d61','#6b7d94','#8fa3ba'].map(rgb);
const RUST=['#080b11','#24171a','#4a2e2a','#7a4c40','#a5705f','#c98d7a'].map(rgb);
const HULL=[C.bevelHi,C.cold,C.chill,C.ice];
const TIER=[P.t0,P.t1,P.t2,P.t3,P.t4].map(rgb);
const TIER_HI=['#d8dde2','#b6f0cf','#c8dcf5','#d6b8f5','#ffe0a0'].map(rgb);
const M4=[0,2,3,1];
const CRACK=[[-0.8,-1.5],[-0.2,-0.5],[-1,0.5]];   // local coords, behind the window
const dith=(x,y,t)=>(M4[(y&1)*2+(x&1)]+.5)/4<t;
// probe shape in local coords (nose along +x): an egg-shaped body and two swept fins
function inTri(px,py,a,b,c){const d=(p,q,r)=>(p[0]-r[0])*(q[1]-r[1])-(q[0]-r[0])*(p[1]-r[1]);const p=[px,py],d1=d(p,a,b),d2=d(p,b,c),d3=d(p,c,a);return !((d1<0||d2<0||d3<0)&&(d1>0||d2>0||d3>0))}
function shipPart(lx,ly){
  const ex=(lx-0.6)/(lx>0.6?5:4.2),ey=ly/2.7;if(ex*ex+ey*ey<=1)return 1;
  if(inTri(lx,ly,[-5,-4.6],[-0.5,-2],[-4.2,-1.5])||inTri(lx,ly,[-5,4.6],[-0.5,2],[-4.2,1.5]))return 2;
  return 0;
}
// pixel arrow icons for the touch buttons (9x9)
const ICON={
  l:['...###...','..#...#..','.#.....#.','#.......#','#.......#','#........','###......','.##......','..#......'],
  r:['...###...','..#...#..','.#.....#.','#.......#','#.......#','........#','......###','......##.','......#..'],
  w:['....#....','...###...','..##.##..','.##...##.','##.....##','....#....','...###...','..#.#.#..','....#....']};

TK.register({
  id:ID,name:'Four Kelvin',where:'Asteroid belts',skill:'Nerve',
  hint:'Fly the ship. Get the ore.',
  controls:['keys:WAD'],
  blurb:'Fly a probe east through an asteroid belt. Go far for better ore.',
  how:[
    'A and D turn the ship. W fires the engine. You keep drifting after.',
    'Fly east through the gaps. Fly through sparkles to get ore.',
    'Each bump breaks one HULL block. Blue shield blocks break first. Lose the last block and the run ends.',
  ],
  deeper:'Each sector: a denser field, narrower gaps, faster tumbling and drift.',
  sensors:'Each point: earlier rock warnings at the screen edge. 1, 3 and 5: one blue shield block each, on top of 2 HULL blocks.',
  _t:{gen,rockPos,scoreOf,shields,HULLN,CFG,BH,SHIPR,LEAD,VMAX},
  mount(stage,ctx){
    const F=gen(ctx.rng,ctx.depth),sens=ctx.sensors|0,rng=ctx.rng;
    const p=TK.pixel(stage,{w:W,h:H}),g=p.g;
    const img=g.createImageData(W,H),buf=new Uint32Array(img.data.buffer);
    const stars=[];for(let i=0;i<70;i++){const l=i<34?0:i<58?1:2;stars.push({x:rng()*W,y:VY+rng()*BH,l,tw:rng()<0.3})}
    const SF=[0.1,0.25,0.5],SC=[C.line,C.cold,C.chill];
    const s={x:20,y:F.cen(20),vx:0,vy:0,ang:0},keys={w:false,a:false,d:false},ptrs=new Map();
    let mode='ready',thrust=false,shield=shields(sens),hull=HULLN,inv=0,oreN=0,oreVal=0,clock=0,tick=0,endT=0,crashed=false,fired=false,raf=0,last=0,acc=0;
    let maxX=s.x,camX=s.x-SHIPX;
    const parts=[],NSEG=HULLN+shields(sens),lostAt=new Array(NSEG).fill(-1);let culprit=null,hitT=-9,hitShield=false;
    const want=k=>keys[k]||[...ptrs.values()].includes(k);
    const dist=()=>Math.max(0,maxX-20);

    const px=(x,y,c)=>{x|=0;y|=0;if(x>=0&&y>=0&&x<W&&y<H)buf[y*W+x]=c};
    function burst(x,y,n,cols,sp){for(let i=0;i<n;i++){const a=rng()*6.283,v=sp*(0.3+rng()*0.7);parts.push({x,y,vx:Math.cos(a)*v,vy:Math.sin(a)*v,life:0.5+rng()*0.5,cols})}}
    const facing=()=>Math.round(s.ang/(2*Math.PI/FACINGS))*(2*Math.PI/FACINGS);

    function finish(){
      if(fired)return;fired=true;
      const m=Math.floor(dist()*5),sc=scoreOf(F,dist(),oreVal);
      ctx.done({score:sc,detail:(crashed?'Hull broke at ':'Cleared the belt, ')+m+' m, ore '+oreN+' of '+F.glints.length});
    }
    function update(){
      tick++;clock+=DT;{const th=mode==='run'&&want('w');if(th!==!!window.__fkTh){window.__fkTh=th;TK.sfx('fourkelvin','thrust',th?1:0)}}
      if(mode==='run'){
        const a=want('a'),d=want('d');thrust=want('w');
        if(a&&!d)s.ang-=TURN*DT;else if(d&&!a)s.ang+=TURN*DT;
        const fa=facing();
        if(thrust){s.vx+=Math.cos(fa)*ACC*DT;s.vy+=Math.sin(fa)*ACC*DT}
        const k=1-DRAG*DT;s.vx*=k;s.vy*=k;
        const sp=Math.hypot(s.vx,s.vy);if(sp>VMAX){s.vx*=VMAX/sp;s.vy*=VMAX/sp}
        s.x+=s.vx*DT;s.y+=s.vy*DT;
        // the belt's edges are soft: you slide along them
        if(s.y<SHIPR+1){s.y=SHIPR+1;if(s.vy<0)s.vy*=-0.3}
        if(s.y>BH-SHIPR-1){s.y=BH-SHIPR-1;if(s.vy>0)s.vy*=-0.3}
        if(s.x<6){s.x=6;if(s.vx<0)s.vx=0}
        maxX=Math.max(maxX,s.x);
        for(let i=lower(F.glints,s.x-6);i<F.glints.length&&F.glints[i].x<s.x+6;i++){const q=F.glints[i];
          if(!q.got&&Math.hypot(q.x-s.x,q.y-s.y)<5.5){q.got=true;oreN++;oreVal+=q.val;burst(q.x,q.y,5,[TIER_HI[q.tier],TIER[q.tier]],14)}}
        if(inv>0)inv-=DT;
        const R=F.rocks;
        for(let i=lower(R,s.x-20);i<R.length&&R[i].x<s.x+20&&mode==='run';i++){const o=R[i];
          const rp=rockPos(o,clock),dx=s.x-rp.x,dy=s.y-rp.y,dd=Math.hypot(dx,dy),min=o.r*0.85+SHIPR;
          if(dd>=min)continue;
          const nx=dd?dx/dd:-1,ny=dd?dy/dd:0,vn=s.vx*nx+s.vy*ny;
          s.x=rp.x+nx*min;s.y=rp.y+ny*min;                       // push clear either way
          if(inv>0){if(vn<0){s.vx-=1.5*vn*nx;s.vy-=1.5*vn*ny}continue}
          // every bump breaks one block, blue shields first; the last block going is the crash
          TK.sfx('fourkelvin','bump');const wasShield=shield>0;if(wasShield)shield--;else hull--;
          lostAt[hull+shield]=clock;hitT=clock;hitShield=wasShield;
          if(hull<=0){crashed=true;culprit=o;mode='end';thrust=false;burst(s.x,s.y,16,[C.hot,C.flare,C.ember,C.bevelHi],22)}
          else{inv=1;s.vx-=1.6*vn*nx;s.vy-=1.6*vn*ny;burst(s.x-nx*SHIPR,s.y-ny*SHIPR,6,wasShield?[C.ice,TIER[2],C.cold]:[C.hot,C.flare,C.ember],12)}
        }
        if(mode==='run'&&maxX>=F.target+20){mode='end';thrust=false;TK.sfx('fourkelvin','win');}
      }else if(mode==='end'){endT+=DT;if(endT>(crashed?2.6:1.6))finish()}
      if(mode==='run'&&hull<HULLN&&tick%5===0){const fa=facing();parts.push({x:s.x-Math.cos(fa)*2,y:s.y-Math.sin(fa)*2,vx:-s.vx*0.2+(rng()-.5)*4,vy:-s.vy*0.2-3,life:0.9,cols:[C.chill,C.cold,C.line]})}
      camX+=((s.x-SHIPX)-camX)*0.12;
      for(let i=parts.length-1;i>=0;i--){const q=parts[i];q.x+=q.vx*DT;q.y+=q.vy*DT;q.vx*=0.94;q.vy*=0.94;q.life-=DT;if(q.life<=0)parts.splice(i,1)}
    }

    // world -> screen
    const SX=x=>x-camX,SY=y=>y+VY;
    function drawRock(o,sx,sy){
      const cx=Math.round(sx),cy=Math.round(sy),R=Math.ceil(o.r*1.25)+1;
      const st=Math.PI/12,ang=Math.round((o.rot0+o.rs*clock)/st)*st,ca=Math.cos(ang),sa=Math.sin(ang),ramp=o.rust?RUST:STONE;
      for(let j=-R;j<=R;j++){const y=cy+j;if(y<VY||y>=VY+BH)continue;
        for(let i=-R;i<=R;i++){const x=cx+i;if(x<0||x>=W)continue;
          const lx=i*ca+j*sa,ly=-i*sa+j*ca,rho=Math.hypot(lx,ly);
          const pr=o.prof[((Math.round(Math.atan2(ly,lx)/6.2832*32)%32)+32)%32];
          if(rho>pr)continue;
          if(rho>pr-1){buf[y*W+x]=ramp[0];continue}
          const z=Math.sqrt(Math.max(0,1-(rho/pr)*(rho/pr)));
          let t=((-i*0.6-j*0.75)/pr)*0.55+z*0.6+0.05;
          for(const q of o.craters){if(Math.hypot(lx-q.x,ly-q.y)<q.r)t-=0.3}
          const v=Math.max(0,Math.min(1,t))*4;let b=Math.floor(v);if(b<4&&dith(x,y,v-b))b++;
          buf[y*W+x]=ramp[1+Math.min(4,b)];
        }}
    }
    function drawGlint(q,sx,sy){
      const x=Math.round(sx),y=Math.round(sy),ph=Math.floor(tick/4+q.ph*3)%6,arm=ph<2?1:ph<4?2:1;
      for(let j=-4;j<=4;j++)for(let i=-4;i<=4;i++){const d=Math.hypot(i,j);if(d>2.5&&d<4.2&&dith(x+i,y+j,0.25)&&y+j>=VY)px(x+i,y+j,TIER[q.tier])}
      for(let a=1;a<=arm;a++){const c=a===1?TIER_HI[q.tier]:TIER[q.tier];px(x+a,y,c);px(x-a,y,c);px(x,y+a,c);px(x,y-a,c)}
      px(x,y,C.hot);
    }
    function drawShip(){
      const fa=facing(),ca=Math.cos(fa),sa=Math.sin(fa),cx=Math.round(SX(s.x)),cy=Math.round(SY(s.y));
      // engine plume out the back, with a dithered glow
      if(thrust&&mode==='run'){
        const L=3+(tick>>1)%3;
        for(let j=-6;j<=6;j++)for(let i=-6;i<=6;i++){const lx=i*ca+j*sa,ly=-i*sa+j*ca;
          if(lx>-4)continue;const d=Math.hypot((lx+5+L/2)/1.4,ly);if(d<3.4&&dith(cx+i,cy+j,d<2?0.5:0.25))px(cx+i,cy+j,C.ember)}
        for(let k=0;k<L;k++){const fx=cx+Math.round(-ca*(5+k)),fy=cy+Math.round(-sa*(5+k));px(fx,fy,k===0?C.hot:k<L-1?C.flare:C.ember)}
      }
      const inside=(i,j)=>shipPart(i*ca+j*sa,-i*sa+j*ca);
      for(let j=-7;j<=7;j++)for(let i=-7;i<=7;i++){const part=inside(i,j);if(!part)continue;
        const x=cx+i,y=cy+j;
        if(!inside(i+1,j)||!inside(i-1,j)||!inside(i,j+1)||!inside(i,j-1)){px(x,y,STONE[0]);continue}
        const lx=i*ca+j*sa,ly=-i*sa+j*ca;
        if(Math.hypot(lx-2.2,ly)<1.3){px(x,y,(i+j)<0?C.hot:C.flare);continue}        // window
        let t=part===2?0.25:0.62-(i*0.5+j*0.65)/5;const v=Math.max(0,Math.min(1,t))*3;let b=Math.floor(v);if(b<3&&dith(x,y,v-b))b++;
        px(x,y,HULL[Math.min(3,b)]);
      }
      // a broken HULL block shows as a crack across the hull, with a hot fleck in it
      if(hull<HULLN){const seen=new Set();CRACK.forEach(([lx,ly],k)=>{const i=Math.round(lx*ca-ly*sa),j=Math.round(lx*sa+ly*ca);
        if(seen.has(i+','+j)||!inside(i,j)||!inside(i+1,j)||!inside(i-1,j)||!inside(i,j+1)||!inside(i,j-1))return;seen.add(i+','+j);
        px(cx+i,cy+j,k===1&&(tick>>3)%2?C.ember:STONE[0])})}
      if(inv>0){const t=0.5*inv,col=hitShield?TIER[2]:C.flare;for(let j=-8;j<=8;j++)for(let i=-8;i<=8;i++){const d=Math.hypot(i,j);if(d>6.6&&d<7.6&&dith(cx+i,cy+j,t)&&cy+j>=VY&&cy+j<VY+BH)px(cx+i,cy+j,col)}}
    }
    function drawWarn(){
      if(sens<1||mode!=='run')return;
      const range=8+4*sens;let up=false,dn=false,rt=false,lf=false;
      const R=F.rocks;
      for(let i=lower(R,s.x-30);i<R.length&&R[i].x<s.x+30;i++){const o=R[i],rp=rockPos(o,clock),dx=rp.x-s.x,dy=rp.y-s.y;
        if(Math.hypot(dx,dy)-o.r-SHIPR>range)continue;
        if(Math.abs(dy)>Math.abs(dx)){if(dy<0)up=true;else dn=true}else{if(dx>0)rt=true;else lf=true}}
      const t=(Math.floor(clock*3)&1)?0.25:0.12,cx=Math.round(SX(s.x)),cy=Math.round(SY(s.y));
      for(let k=-14;k<=14;k++){
        if(up&&dith(cx+k,VY,t))px(cx+k,VY,C.ember);if(dn&&dith(cx+k,VY+BH-1,t))px(cx+k,VY+BH-1,C.ember);
        if(rt&&dith(W-1,cy+k,t)&&cy+k>=VY&&cy+k<VY+BH)px(W-1,cy+k,C.ember);if(lf&&dith(0,cy+k,t)&&cy+k>=VY&&cy+k<VY+BH)px(0,cy+k,C.ember)}
    }
    function render(){
      buf.fill(C.void);
      for(const st of stars){const x=Math.floor(((st.x-camX*SF[st.l])%W+W)%W);px(x,st.y,st.l===2&&st.tw&&((tick>>3)+x)%7===0?C.ice:SC[st.l])}
      // the belt's far edge: a dotted marker column
      const ex=Math.round(SX(F.target+20));if(ex>=0&&ex<W)for(let y=VY;y<VY+BH;y+=3)px(ex,y,C.good);
      const lo=camX-16,hi=camX+W+16;
      for(let i=lower(F.glints,lo);i<F.glints.length&&F.glints[i].x<hi;i++){const q=F.glints[i];if(!q.got)drawGlint(q,SX(q.x),SY(q.y))}
      for(let i=lower(F.rocks,lo-10);i<F.rocks.length&&F.rocks[i].x<hi+10;i++){const o=F.rocks[i],rp=rockPos(o,clock);drawRock(o,SX(rp.x),SY(rp.y))}
      if(!crashed)drawShip();
      drawWarn();
      for(const q of parts){const c=q.life>0.7?q.cols[0]:q.life>0.35?(q.cols[1]||q.cols[0]):(q.cols[2]||q.cols[q.cols.length-1]);const y=SY(q.y);if(y>=VY&&y<VY+BH)px(SX(q.x),y,c)}
      if(crashed&&endT<0.15){for(let j=-1;j<=1;j++)for(let i=-1;i<=1;i++)px(SX(s.x)+i,SY(s.y)+j,i||j?C.flare:C.hot)}
      g.putImageData(img,0,0);
      hud();
    }
    // Three Kelvin's own fight-screen chrome, earnestly reused for an arcade run.
    function btn(x,y,w,h,lit,edge,label){
      g.fillStyle=P.bevelLo;g.fillRect(x-1,y-1,w+2,h+2);
      g.fillStyle=lit?P.line:P.void;g.fillRect(x,y,w,h);
      g.fillStyle=edge;g.fillRect(x,y,w,1);g.fillRect(x,y+h-1,w,1);g.fillRect(x,y,1,h);g.fillRect(x+w-1,y,1,h);
      if(ICON[label]){const m=ICON[label],ix=x+Math.floor((w-9)/2),iy=y+Math.floor((h-9)/2);g.fillStyle=lit?P.hot:edge;
        for(let r=0;r<9;r++)for(let c=0;c<9;c++)if(m[r][c]==='#')g.fillRect(ix+c,iy+r,1,1)}
      else TK.text(g,label,x+Math.floor(w/2),y+Math.floor((h-5)/2),lit?P.hot:P.ice,'center');
    }
    // HULL: one block per bump left. Green hull blocks, blue shield blocks on the right; the right-most goes first.
    const SEGW=7,cellX=i=>i*(SEGW+1)+(i>=HULLN?2:0);
    function hullBar(x,y){
      for(let i=0;i<NSEG;i++){const cx=x+cellX(i),sh=i>=HULLN,on=i<hull+shield,age=lostAt[i]<0?9:clock-lostAt[i];
        g.fillStyle=P.bevelLo;g.fillRect(cx,y,SEGW,7);
        if(on){g.fillStyle=sh?P.t2:P.good;g.fillRect(cx+1,y+1,SEGW-2,5);g.fillStyle=sh?P.ice:P.mark;g.fillRect(cx+1,y+1,SEGW-2,1);
          g.fillStyle=sh?'#3f5f8a':'#4f7a63';g.fillRect(cx+1,y+5,SEGW-2,1)}
        else if(age<0.9&&(Math.floor(age*10)%2===0)){g.fillStyle=P.hot;g.fillRect(cx+1,y+1,SEGW-2,5);g.fillStyle='#fff4dc';g.fillRect(cx+2,y+2,SEGW-4,3)}
        else{g.fillStyle=P.line;g.fillRect(cx+1,y+1,SEGW-2,5);g.fillStyle=sh?'#2a3a52':P.bad;   // gone: an empty cell, a broken hull block slashed red
          for(let k=0;k<5;k++)g.fillRect(cx+1+k,y+5-k,1,1)}
      }
      return cellX(NSEG-1)+SEGW;
    }
    // A WARNING tag over the rock that did it, raised once it is far too late (Jon, Nov 17)
    function intentTag(){
      if(!culprit||endT<0.3)return null;
      const rp=rockPos(culprit,clock),sx=Math.round(SX(rp.x)),sy=Math.round(SY(rp.y)),r=Math.ceil(culprit.r*1.25)+1;
      const label='WARNING: ROCK',w=label.length*4-1+6,h=9;
      const x=Math.max(1,Math.min(W-w-1,sx-Math.floor(w/2)));let y=sy-r-h-3,up=true;if(y<VY+1){y=sy+r+3;up=false}
      g.fillStyle=P.bevelLo;g.fillRect(x-1,y-1,w+2,h+2);g.fillStyle=P.panel;g.fillRect(x,y,w,h);g.fillStyle=P.them;g.fillRect(x,y,w,1);
      TK.text(g,label,x+3,y+2,P.them);
      g.fillStyle=P.them;const tx=Math.max(x+2,Math.min(x+w-3,sx));if(up)g.fillRect(tx,y+h+1,1,2);else g.fillRect(tx,y-3,1,2);
      return {x:x-1,y:y-1,w:w+2,h:h+2,rx:sx-r,ry:sy-r,rw:2*r+1};
    }
    const BTN={a:[2,97,20,13],d:[25,97,20,13],w:[W-44,97,42,13]};
    function hud(){
      // top bar: HULL, HEAT, FUEL and, where CREDITS would be, distance
      g.fillStyle=P.panel;g.fillRect(0,0,W,9);g.fillStyle=P.bevelHi;g.fillRect(0,9,W,1);
      const fresh=clock-hitT<0.9&&Math.floor((clock-hitT)*10)%2===0;
      TK.text(g,'HULL',2,2,fresh?P.hot:P.cold);hullBar(19,1);
      TK.text(g,String(Math.floor(dist()*5)).padStart(4,'0')+'M',W-2,2,P.hot,'right');
      // bottom panel
      g.fillStyle=P.panel;g.fillRect(0,92,W,H-92);g.fillStyle=P.bevelHi;g.fillRect(0,92,W,1);
      const f=Math.min(1,dist()/F.target),bw=W-4;      // how far into the belt
      g.fillStyle=P.line;g.fillRect(2,94,bw,1);g.fillStyle=P.chill;g.fillRect(2,94,Math.round(bw*f),1);g.fillStyle=P.hot;g.fillRect(2+Math.round(bw*f),94,1,1);
      btn(...BTN.a,want('a'),P.warn,'l');btn(...BTN.d,want('d'),P.warn,'r');btn(...BTN.w,want('w'),P.ice,'THRUST');
      // ENERGY: always full, never used
      const ex=50,ew=W-44-6-ex;g.fillStyle=P.bevelLo;g.fillRect(ex,96,ew,15);g.fillStyle=P.void;g.fillRect(ex+1,97,ew-2,13);
      TK.text(g,'ENERGY',ex+Math.floor(ew/2),98,P.cold,'center');
      for(let i=0;i<4;i++){g.fillStyle=P.ember;g.fillRect(ex+Math.floor(ew/2)-8+i*4,105,3,3)}
      if(mode==='ready'){const y=box(['FLY THE SHIP.','GET THE ORE.'],[P.hot,P.hot],24);g.save();g.translate(Math.floor((W-30)/2),y+30);TK.icon(g,'keys',0,0,{label:'WAD',t:clock});g.restore()}
      else if(mode==='end'){const tag=intentTag();
        if(endT>(crashed?1:0.5)){const lines=crashed?['IMPACT']:['BELT CLEAR'];let at=null;
          // the box sits clear of the intent tag and the rock: first free spot wins
          if(tag){const w=Math.max(...lines.map(l=>l.length*4-1))+14,h=lines.length*8+8,hit=(x,y,a)=>x<a.x+a.w&&x+w>a.x&&y<a.y+a.h&&y+h>a.y;
            const rock={x:tag.rx,y:tag.ry,w:tag.rw,h:tag.rw},mid=VY+Math.floor((BH-h)/2);
            for(const[x,y]of[[Math.floor((W-w)/2),mid],[W-w-2,mid],[W-w-2,VY+3],[W-w-2,VY+BH-h-2],[Math.floor((W-w)/2),VY+BH-h-2],[Math.floor((W-w)/2),VY+3],[2,VY+3],[2,VY+BH-h-2]])
              if(!hit(x,y,tag)&&!hit(x,y,rock)){at=[x+1,y+1];break}}
          box(lines,[crashed?P.bad:P.good],0,at)}}
    }
    function box(lines,cols,extra,at){
      const w=Math.max(...lines.map(l=>l.length*4-1))+12,h=lines.length*8+6+(extra||0),x=at?at[0]:Math.floor((W-w)/2),y=at?at[1]:VY+Math.floor((BH-h)/2);
      g.fillStyle=P.bevelLo;g.fillRect(x-1,y-1,w+2,h+2);g.fillStyle=P.panel;g.fillRect(x,y,w,h);
      g.fillStyle=P.bevelHi;g.fillRect(x,y,w,1);g.fillRect(x,y,1,h);g.fillStyle=P.line;g.fillRect(x,y+h-1,w,1);g.fillRect(x+w-1,y,1,h);
      lines.forEach((l,i)=>TK.text(g,l,x+Math.floor(w/2),y+4+i*8,cols[i],'center'));
      return y;
    }
    function frame(now){
      if(!last)last=now;acc+=Math.min(0.25,(now-last)/1000);last=now;
      while(acc>=DT){update();acc-=DT}
      render();
      if(!fired)raf=requestAnimationFrame(frame);
    }

    // ---------- input: keys, plus multi-touch buttons ----------
    function begin(){if(!fired&&mode==='ready')mode='run'}
    const zone=e=>{const q=p.pt(e);for(const k in BTN){const [x,y,w,h]=BTN[k];if(q.x>=x-1&&q.x<x+w+1&&q.y>=y-2&&q.y<y+h+1)return k}return null};
    const pdown=e=>{e.preventDefault();try{p.cv.setPointerCapture(e.pointerId)}catch(_){}const z=zone(e);if(z)ptrs.set(e.pointerId,z);begin()};
    const pmove=e=>{if(!ptrs.has(e.pointerId))return;const z=zone(e);if(z)ptrs.set(e.pointerId,z);else ptrs.delete(e.pointerId)};
    const pup=e=>{ptrs.delete(e.pointerId)};
    const KEY={KeyW:'w',ArrowUp:'w',KeyA:'a',ArrowLeft:'a',KeyD:'d',ArrowRight:'d'};
    const typing=e=>{const t=e.target;return t&&(t.tagName==='TEXTAREA'||t.tagName==='INPUT'||t.isContentEditable)};
    const kdown=e=>{const k=KEY[e.code];if(!k||typing(e)||!stage.isConnected||fired)return;e.preventDefault();
      if(document.activeElement&&document.activeElement.tagName==='BUTTON')document.activeElement.blur();keys[k]=true;begin()};
    const kup=e=>{const k=KEY[e.code];if(!k||typing(e))return;if(!fired)e.preventDefault();keys[k]=false};
    const blur=()=>{keys.w=keys.a=keys.d=false;ptrs.clear()};
    p.cv.addEventListener('pointerdown',pdown);p.cv.addEventListener('pointermove',pmove);
    window.addEventListener('pointerup',pup);window.addEventListener('pointercancel',pup);
    window.addEventListener('keydown',kdown);window.addEventListener('keyup',kup);window.addEventListener('blur',blur);
    raf=requestAnimationFrame(frame);

    function unhook(){cancelAnimationFrame(raf);raf=0;p.cv.removeEventListener('pointerdown',pdown);p.cv.removeEventListener('pointermove',pmove);
      window.removeEventListener('pointerup',pup);window.removeEventListener('pointercancel',pup);
      window.removeEventListener('keydown',kdown);window.removeEventListener('keyup',kup);window.removeEventListener('blur',blur)}
    return {
      destroy(){fired=true;unhook();p.destroy()},
      giveUp(){if(fired)return;fired=true;unhook();render();
        ctx.done({score:mode==='ready'?0:scoreOf(F,dist(),oreVal),detail:'Gave up at '+Math.floor(dist()*5)+' m, ore '+oreN+' of '+F.glints.length})},
      _ship:s,_F:F,
      _state:()=>({mode,x:s.x,y:s.y,vx:s.vx,vy:s.vy,ang:s.ang,dist:dist(),ore:oreN,shield,hull,nseg:NSEG,crashed,target:F.target,clock}),
    };
  },
});
})();
