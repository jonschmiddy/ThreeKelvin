// Core Scan: the ship's scanner reads a buried find in slices. Each glowing bar says how
// many solid cells that slice holds, in runs. Fill the solid cells to bring the find up on screen.
(function(){
'use strict';
const ID='tomo2';
// pictures: name, palette hue key, rows
const PICS={
5:{
CRYSTAL:['t2',['..#..','.###.','#####','.###.','..#..']],
HEART:  ['bad',['.#.#.','#####','#####','.###.','..#..']],
ROCKET: ['flare',['..#..','.###.','.###.','.###.','#.#.#']],
TREE:   ['t1',['..#..','.###.','#####','..#..','..#..']],
SKULL:  ['ice',['.###.','#####','#.#.#','#####','.#.#.']],
ANCHOR: ['chill',['..#..','#####','..#..','#.#.#','.###.']],
SHIP:   ['cold',['..#..','.###.','##.##','#####','#.#.#']],
MUG:    ['ember',['####.','#..##','#..##','####.','.##..']],
},
6:{
CRYSTAL:['t2',['..##..','.####.','######','.####.','..##..','..##..']],
SHELL:  ['hot',['.####.','######','#.##.#','######','.####.','..##..']],
SCREW:  ['chill',['.####.','.####.','..##..','.###..','..##..','...#..']],
WRENCH: ['cold',['#...#.','#####.','.###..','..##..','...##.','....##']],
GEAR:   ['warn',['#.##.#','.####.','##..##','##..##','.####.','#.##.#']],
BONE:   ['ice',['##....','####..','.###..','..###.','...###','....##']],
LEAF:   ['t1',['...###','..####','.#.##.','####..','.##...','#.....']],
},
8:{
CRYSTAL:['t2',['...#....','..###.#.','..###.##','.####.##','.####.##','#####.##','########','.######.']],
SHELL:  ['hot',['..####..','.##...#.','#..##..#','#.#..#.#','#.#.##.#','#..#...#','.#....#.','..#####.']],
WRENCH: ['cold',['.#.#....','.#.#....','.###....','..###...','...####.','....###.','.....###','......##']],
SCREW:  ['chill',['.######.','.######.','...##...','..####..','...##...','..####..','...##...','....#...']],
GEAR:   ['warn',['...##...','.######.','.##..##.','###..###','###..###','.##..##.','.######.','...##...']],
BONE:   ['ice',['........','.#....#.','###..###','.######.','.######.','###..###','.#....#.','........']],
LEAF:   ['t1',['......##','....####','...#####','..#####.','.##.##..','.####...','.#......','#.......']],
},
10:{
CRYSTAL:['t2',['....#.....','...###....','...###..#.','..#####.##','..#####.##','..#####.##','.######.##','.#########','##########','.########.']],
SHELL:  ['hot',['...####...','.########.','##.#..#.##','#.##..##.#','##.####.##','.##.##.##.','..######..','...####...','..######..','..######..']],
WRENCH: ['cold',['.#..#.....','.#..#.....','.####.....','..####....','...####...','....#####.','.....####.','......####','.......###','........#.']],
GEAR:   ['warn',['....##....','.#.####.#.','.########.','..##..##..','####..####','####..####','..##..##..','.########.','.#.####.#.','....##....']],
SKULL:  ['ice',['..######..','.########.','##########','##..##..##','##..##..##','##########','.###..###.','..######..','..#.##.#..','..######..']],
LEAF:   ['t1',['........##','......####','.....#####','....######','...#.####.','..######..','.######...','.####.....','.#........','#.........']],
},
};
const CFG=[null,{n:5,lives:4,par:40},{n:6,lives:4,par:60},{n:8,lives:4,par:95},{n:8,lives:3,par:95},{n:10,lives:3,par:140}];

// ---------- logic ----------
function runs(line){const r=[];let c=0;for(const v of line){if(v)c++;else if(c){r.push(c);c=0}}if(c)r.push(c);return r}
function cluesOf(g){const n=g.length;return{rows:g.map(runs),cols:[...Array(n)].map((_,j)=>runs(g.map(r=>r[j])))}}
function lineSolve(clue,known){
  const n=known.length,canF=new Array(n).fill(false),canE=new Array(n).fill(false),cur=new Array(n).fill(0);let any=false;
  (function rec(ci,pos){
    if(ci===clue.length){for(let i=pos;i<n;i++)if(known[i]===1)return;for(let i=0;i<n;i++){if(i>=pos)cur[i]=0;if(cur[i])canF[i]=true;else canE[i]=true}any=true;return}
    const len=clue[ci];let rest=0;for(let k=ci+1;k<clue.length;k++)rest+=clue[k]+1;
    for(let s=pos;s+len+rest<=n;s++){
      let ok=true;for(let i=pos;i<s;i++)if(known[i]===1){ok=false;break}
      if(!ok)break;
      for(let i=s;i<s+len;i++)if(known[i]===0){ok=false;break}
      if(!ok)continue;
      if(s+len<n&&known[s+len]===1)continue;
      for(let i=pos;i<s;i++)cur[i]=0;for(let i=s;i<s+len;i++)cur[i]=1;if(s+len<n)cur[s+len]=0;
      rec(ci+1,Math.min(n,s+len+1));
    }
  })(0,0);
  if(!any)return null;
  return known.map((v,i)=>v!==-1?v:(canF[i]&&!canE[i]?1:(!canF[i]&&canE[i]?0:-1)));
}
function lineSolvable(g){
  const n=g.length,{rows,cols}=cluesOf(g),k=[...Array(n)].map(()=>new Array(n).fill(-1));
  let changed=true;
  while(changed){changed=false;
    for(let i=0;i<n;i++){const r=lineSolve(rows[i],k[i]);if(!r)return false;r.forEach((v,j)=>{if(v!==k[i][j]){k[i][j]=v;changed=true}})}
    for(let j=0;j<n;j++){const r=lineSolve(cols[j],k.map(r=>r[j]));if(!r)return false;r.forEach((v,i)=>{if(v!==k[i][j]){k[i][j]=v;changed=true}})}
  }
  return k.every((r,i)=>r.every((v,j)=>v===g[i][j]));
}
function toGrid(rows,flip){return rows.map(r=>{const a=[...r].map(ch=>ch==='#'?1:0);return flip?a.reverse():a})}
function options(n){const out=[];for(const[name,[hue,rows]]of Object.entries(PICS[n]))for(const flip of[false,true]){const g=toGrid(rows,flip);if(lineSolvable(g))out.push({name,hue,flip,grid:g})}return out}
const OPT={};
function gen(rng,depth){
  const n=CFG[depth].n;OPT[n]=OPT[n]||options(n);
  const o=OPT[n][Math.floor(rng()*OPT[n].length)];
  return {name:o.name,hue:o.hue,grid:o.grid,n};
}
function score(mistakes,secs,par){const tp=Math.min(0.25,Math.max(0,0.25*(secs-par)/par));return Math.max(0.3,1-0.14*mistakes-tp)}

// ---------- pixel helpers ----------
const B4=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5];
const bay=(x,y)=>(B4[(y&3)*4+(x&3)]+.5)/16;
function rgb(c){const n=parseInt(c.slice(1),16);return[n>>16&255,n>>8&255,n&255]}
function hx(a){return'#'+a.map(v=>Math.max(0,Math.min(255,Math.round(v))).toString(16).padStart(2,'0')).join('')}
function mix(a,b,t){const A=rgb(a),B=rgb(b);return hx(A.map((v,i)=>v+(B[i]-v)*t))}
function R(g,x,y,w,h,c){g.fillStyle=c;g.fillRect(x,y,w,h)}
function card(g,x,y,w,txt,t){const P=TK.PAL;R(g,x,y,w,19,P.bevelLo);R(g,x,y,w,1,P.ember);R(g,x,y+18,w,1,P.ember);const tw=txt.length*4-1,tot=16+tw,x0=x+((w-tot)>>1);if(TK.icon)TK.icon(g,'click',x0,y+3,{t});TK.text(g,txt,x0+16,y+7,P.hot)}

TK.css(ID,`.tomo2-cv{cursor:pointer}`);

TK.register({
  id:ID,name:'Core Scan',hint:'Fill in the scan.',controls:['click'],where:'Moons, fossil beds, wrecks',skill:'Logic',
  blurb:'Fill the scan to bring up what is buried.',
  how:[
    'Each bar’s numbers are runs of solid cells: “2 1” is two, a gap, then one.',
    'Tap a cell to fill it. A full row or column lights green.',
    'A wrong fill cracks the glass. Too many cracks and the scan is lost.',
  ],
  deeper:'Sector 1: 5 by 5. Sector 2: 6 by 6. Sector 3–4: 8 by 8. Sector 5: 10 by 10. Fewer cracks allowed from sector 4.',
  sensors:'1, 3, 5: one row filled in at the start. 2 and 4: one crack forgiven each.',
  _t:{gen,lineSolvable,cluesOf,toGrid,PICS,score,CFG,options},
  mount(stage,ctx){
    const c=CFG[ctx.depth],P=gen(ctx.rng,ctx.depth),n=P.n,G=P.grid,PAL=TK.PAL;
    const {rows,cols}=cluesOf(G);
    const st=G.map(r=>r.map(()=>0)); // 0 unknown, 1 filled, 2 known empty, 3 cracked
    const crackT={},fillT={};
    let forgive=Math.floor(ctx.sensors/2),mistakes=0,over=false,won=0,lost=0,AC=null,touched=false;
    const t0=performance.now(),timers=[];
    const solvedRows=TK.shuffle([...Array(n).keys()],ctx.rng).slice(0,Math.min(Math.ceil(ctx.sensors/2),Math.floor(n/3)));
    solvedRows.forEach(i=>{for(let j=0;j<n;j++)st[i][j]=G[i][j]?1:2});
    const total=G.flat().filter(Boolean).length;
    function tone(f,d,type,v,to){if(window.TK_MUTE_TONES)return;try{AC=AC||new (window.AudioContext||window.webkitAudioContext)();const t=AC.currentTime,o=AC.createOscillator(),gg=AC.createGain();o.type=type||'sine';o.frequency.setValueAtTime(f,t);if(to)o.frequency.exponentialRampToValueAtTime(to,t+d);gg.gain.setValueAtTime(v||.04,t);gg.gain.exponentialRampToValueAtTime(.0001,t+d);o.connect(gg).connect(AC.destination);o.start(t);o.stop(t+d+.02)}catch(e){}}

    // ---- layout ----
    const wNum=v=>String(v).length*4-1;
    const rowW=r=>(r.length?r:[0]).reduce((a,v)=>a+wNum(v)+3,-3);
    const CLW=Math.max(...rows.map(rowW))+11,maxC=Math.max(...cols.map(c=>Math.max(1,c.length))),CLH=maxC*6+5;
    const W=150,CS=Math.min(18,Math.floor((W-6-CLW)/n)),GW=n*CS;
    const GX=Math.floor((W-CLW-GW)/2)+CLW,GY=11+CLH,H=GY+GW+12;
    const pix=TK.pixel(stage,{w:W,h:H}),g=pix.g;pix.cv.classList.add('tomo2-cv');
    const hue=PAL[P.hue]||PAL.ice;
    const RAMP=[mix(hue,'#000000',.75),mix(hue,'#000000',.4),hue,mix(hue,'#ffffff',.45)];
    const pic=(i,j)=>i>=0&&j>=0&&i<n&&j<n&&G[i][j]===1;
    let lastRow=-1,lastCol=-1,lastT=0;
    const sweepRow={},sweepCol={};

    const rowDone=i=>G[i].every((v,j)=>!v||st[i][j]===1);
    const colDone=j=>G.every((r,i)=>!r[j]||st[i][j]===1);

    function cell(i,j,now){
      const x=GX+j*CS,y=GY+i*CS,s=st[i][j];
      if(s===1||won){
        if(!G[i][j]){R(g,x,y,CS,CS,won?'#05070a':'#0b0f15');return}
        const age=fillT[i+','+j]?now-fillT[i+','+j]:999;
        R(g,x,y,CS,CS,RAMP[2]);
        for(let yy=0;yy<CS;yy++)for(let xx=0;xx<CS;xx++)if(bay(x+xx,y+yy)<.12)R(g,x+xx,y+yy,1,1,RAMP[3]);
        if(!pic(i-1,j))R(g,x,y,CS,2,RAMP[3]);
        if(!pic(i,j-1))R(g,x,y,2,CS,RAMP[3]);
        if(!pic(i+1,j))R(g,x,y+CS-2,CS,2,RAMP[1]);
        if(!pic(i,j+1))R(g,x+CS-2,y,2,CS,RAMP[1]);
        if(!pic(i-1,j))R(g,x,y,CS,1,RAMP[0]);if(!pic(i,j-1))R(g,x,y,1,CS,RAMP[0]);
        if(!pic(i+1,j))R(g,x,y+CS-1,CS,1,RAMP[0]);if(!pic(i,j+1))R(g,x+CS-1,y,1,CS,RAMP[0]);
        if(age<220){const t=1-age/220;for(let yy=1;yy<CS-1;yy++)for(let xx=1;xx<CS-1;xx++)if(bay(x+xx,y+yy)<t*.8)R(g,x+xx,y+yy,1,1,'#ffffff')}
        return;
      }
      // scanner glass
      R(g,x,y,CS,CS,s===2?'#080b11':'#101824');
      R(g,x,y,CS,1,s===2?'#0b0f15':'#1a2533');R(g,x,y,1,CS,s===2?'#0b0f15':'#1a2533');
      R(g,x+CS-1,y,1,CS,'#05070a');R(g,x,y+CS-1,CS,1,'#05070a');
      if(s===0&&(i===lastRow||j===lastCol)&&now-lastT<600){const t=.3*(1-(now-lastT)/600);for(let yy=1;yy<CS-1;yy++)for(let xx=1;xx<CS-1;xx++)if(bay(x+xx,y+yy)<t)R(g,x+xx,y+yy,1,1,'#1f3a44')}
      if(s===2)R(g,x+(CS>>1),y+(CS>>1),1,1,'#1f2935');
      if(s===3){
        const age=now-crackT[i+','+j],grow=Math.min(1,age/250),cx=x+(CS>>1),cy=y+(CS>>1);
        R(g,x+1,y+1,CS-2,CS-2,'#140a0b');
        const arms=[[1,-1],[-1,-.6],[.4,1],[-.8,.9],[1,.3]];
        arms.forEach(([dx,dy],k)=>{const L=(CS/2-1)*grow*(k%2?0.8:1);let px=cx,py=cy;
          for(let t=0;t<L;t++){px+=dx*.9+(Math.sin(t*1.7+k)*.4);py+=dy*.9+(Math.cos(t*1.3+k)*.4);R(g,Math.round(px),Math.round(py),1,1,t<2?'#ffffff':PAL.chill)}});
        R(g,cx,cy,1,1,'#ffffff');
        if(age<300){const sh=age<150?((age/40)|0)%2:0;if(sh)R(g,x,y,CS,1,PAL.bad)}
      }
    }
    function bar(x,y,w,h,horiz,done,hot,now,sweep){
      R(g,x,y,w,h,'#000');
      R(g,x+1,y+1,w-2,h-2,done?'#10261c':'#0a1520');
      const ec=done?PAL.good:(hot?'#ffffff':PAL.tractor);
      if(horiz){R(g,x+w-2,y+1,1,h-2,ec);for(let yy=y+1;yy<y+h-1;yy++)if(bay(x+w-3,yy)<.5)R(g,x+w-3,yy,1,1,mix(ec,'#000000',.4))}
      else{R(g,x+1,y+h-2,w-2,1,ec);for(let xx=x+1;xx<x+w-1;xx++)if(bay(xx,y+h-3)<.5)R(g,xx,y+h-3,1,1,mix(ec,'#000000',.4))}
      R(g,x+1,y+1,horiz?w-3:1,1,'#1f3a44');
    }
    function render(now){
      R(g,0,0,W,H,PAL.panel);
      // HUD: cracks left
      TK.text(g,'GLASS',3,3,PAL.cold);
      for(let k=0;k<c.lives;k++){const x=26+k*7,broke=k<mistakes;R(g,x,2,6,7,'#000');R(g,x+1,3,4,5,broke?'#140a0b':'#1f3a44');R(g,x+1,3,4,1,broke?'#140a0b':PAL.chill);if(broke){R(g,x+2,4,1,1,PAL.chill);R(g,x+3,5,1,2,PAL.chill)}}
      if(forgive)TK.text(g,'+'+forgive,26+c.lives*7+2,3,PAL.good);
      TK.text(g,'SLICE '+n+'X'+n,W-3,3,PAL.cold,'right');
      // screen bezel
      R(g,GX-2,GY-2,GW+4,GW+4,PAL.bevelLo);R(g,GX-1,GY-1,GW+2,GW+2,'#000');R(g,GX-2,GY+GW+1,GW+4,1,PAL.bevelHi);R(g,GX+GW+1,GY-2,1,GW+4,PAL.bevelHi);
      // row bars
      for(let i=0;i<n;i++){
        const d=rowDone(i),y=GY+i*CS,x0=GX-CLW+1;
        bar(x0,y,CLW-3,CS,true,d,i===lastRow&&now-lastT<500,now);
        let x=GX-6;const nums=(rows[i].length?rows[i]:[0]).slice().reverse();
        for(const v of nums){const w=wNum(v);x-=w;TK.text(g,String(v),x,y+((CS-5)>>1),d?PAL.mark:PAL.ice);x-=3}
        const sw=sweepRow[i];if(sw&&now-sw<450){const u=(now-sw)/450,sx=GX+Math.round(u*GW);R(g,sx,y,1,CS,PAL.mark);if(sx-1>=GX)R(g,sx-1,y,1,CS,PAL.good)}
      }
      for(let j=0;j<n;j++){
        const d=colDone(j),x=GX+j*CS,y0=GY-CLH+1;
        bar(x,y0,CS,CLH-3,false,d,j===lastCol&&now-lastT<500,now);
        let y=GY-6;const nums=(cols[j].length?cols[j]:[0]).slice().reverse();
        for(const v of nums){y-=5;TK.text(g,String(v),x+(CS>>1),y,d?PAL.mark:PAL.ice,'center');y-=1}
        const sw=sweepCol[j];if(sw&&now-sw<450){const u=(now-sw)/450,sy=GY+Math.round(u*GW);R(g,x,sy,CS,1,PAL.mark);if(sy-1>=GY)R(g,x,sy-1,CS,1,PAL.good)}
      }
      for(let i=0;i<n;i++)for(let j=0;j<n;j++)cell(i,j,now);
      // scan line idles down the glass
      if(!over){const sy=GY+Math.floor(((now-t0)/30)%(GW+30));if(sy<GY+GW)for(let x=GX;x<GX+GW;x++)if(bay(x,sy)<.35)R(g,x,sy,1,1,'#2b4a55')}
      if(won){const u=Math.min(1,(now-won)/600);const sy=GY+Math.round(u*GW);if(u<1)R(g,GX,sy,GW,1,'#ffffff');TK.text(g,'FOUND: '+P.name,W>>1,H-8,PAL.hot,'center')}
      else if(lost)TK.text(g,'SCAN LOST',W>>1,H-8,PAL.bad,'center');
      if(!touched&&now-t0<4500)card(g,GX,GY+(GW>>1)-9,GW,'FILL IN THE SCAN.',(now-t0)/1000);
    }
    function settle(now){
      // a finished row or column clears its leftover cells and sweeps green
      for(let i=0;i<n;i++)if(rowDone(i)&&!sweepRow[i]){sweepRow[i]=now;for(let j=0;j<n;j++)if(st[i][j]===0)st[i][j]=2;tone(660,.12,'triangle',.03,990)}
      for(let j=0;j<n;j++)if(colDone(j)&&!sweepCol[j]){sweepCol[j]=now;for(let i=0;i<n;i++)if(st[i][j]===0)st[i][j]=2;tone(740,.12,'triangle',.03,1100)}
    }
    // rows filled by sensors count as done, without the sweep sound
    for(let i=0;i<n;i++)if(rowDone(i))sweepRow[i]=1;for(let j=0;j<n;j++)if(colDone(j))sweepCol[j]=1;
    function found(){let f=0;for(let i=0;i<n;i++)for(let j=0;j<n;j++)if(st[i][j]===1)f++;return f}
    function tap(i,j,now){
      if(over||st[i][j]!==0)return;
      touched=true;lastRow=i;lastCol=j;lastT=now;
      if(G[i][j]){st[i][j]=1;TK.sfx('tomo2','fill');fillT[i+','+j]=now;tone(420+i*30,.06,'square',.025);settle(now);if(found()===total)win(now);return}
      st[i][j]=3;crackT[i+','+j]=now;TK.sfx('tomo2','crack');tone(1800,.08,'square',.03,600);setTimeout(()=>tone(300,.15,'sawtooth',.02,120),40);
      if(forgive>0)forgive--;else mistakes++;
      settle(now);
      if(mistakes>=c.lives){
        over=true;lost=now;const f=found();
        ctx.done({score:0.15*f/total,detail:'Glass broke, '+f+'/'+total+' found'});
      }
    }
    function win(now){TK.sfx('tomo2','win');
      over=true;won=now;const secs=Math.round((now-t0)/1000);
      tone(523,.2,'triangle',.05);setTimeout(()=>tone(659,.2,'triangle',.05),120);setTimeout(()=>tone(784,.35,'triangle',.05),240);
      ctx.done({score:score(mistakes,secs,c.par),detail:P.name.toLowerCase()+', '+mistakes+' crack'+(mistakes===1?'':'s')});
    }
    pix.cv.addEventListener('pointerdown',e=>{e.preventDefault();const q=pix.pt(e),j=Math.floor((q.x-GX)/CS),i=Math.floor((q.y-GY)/CS);if(i>=0&&j>=0&&i<n&&j<n)tap(i,j,performance.now())});
    let raf=0,last=0,alive=true;
    const loop=now=>{if(!alive)return;raf=requestAnimationFrame(loop);if(now-last<32)return;last=now;render(now)};
    raf=requestAnimationFrame(loop);render(performance.now());
    return {
      _p:P,_cell:(i,j)=>({x:GX+j*CS+(CS>>1),y:GY+i*CS+(CS>>1)}),
      destroy(){alive=false;over=true;cancelAnimationFrame(raf);timers.forEach(clearTimeout);pix.destroy();try{AC&&AC.close()}catch(e){}},
      giveUp(){if(over)return;over=true;const f=found();ctx.done({score:0.15*f/total,detail:f+' of '+total+' found'})},
    };
  },
});
})();
