// NOOK 1: the science nook. Evening power-on: desk switch, string lights run along the wire,
// the rack bulb strikes, the CRT warms up, the oscilloscope and rack wake, the little robot looks up.
// Light is a stepped light map at art resolution (384x216), scaled 5x. Every frame is a pure function of t.
(function(){
const W=384, H=216, N=W*H, S=5;
const GX=117, GY=22, GW=150, GH=140;            // CRT glass
const SC={x0:16,y0:96,x1:32,y1:109};             // oscilloscope glass
const BX=358, BY=113;                            // rack bulb: the sliver under the cone's rim (rim, warm inside lip, at y 112)
const RIM_Y=112, RIM_HALF=10;                    // the cone's mouth: x 348..368
const MON={x0:105,y0:8,x1:278,y1:183};           // monitor A's case and foot (never a string bulb)
// beats (seconds since start; act 1 owns t < 2.5)
const T={fade:2.5, main:3.2, str:3.45, bulb:4.3, crt:4.9, rack:5.95, scope:6.15, arm:6.9, bot:7.55};

let ok=false, local, cult, art, emitId, fields=[], off, offg, img, out, Lr, Lg, Lb;
const em={};   // emitter pixel lists
let strBulbs=[], ledList=[];
const BAY=[0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5].map(v=>(v+0.5)/16);

// ---------- helpers ----------
function hh(n){ n=(n|0)^0x9e3779b9; n=Math.imul(n^(n>>>16),0x85ebca6b); n=Math.imul(n^(n>>>13),0xc2b2ae35); n^=n>>>16; return (n>>>0)/4294967296; }
const cl=(v,a,b)=>v<a?a:v>b?b:v;
const seg=(t,a,b)=>cl((t-a)/(b-a),0,1);
const ease=t=>t<=0?0:t>=1?1:t*t*(3-2*t);
const eOut=t=>t<=0?0:t>=1?1:1-Math.pow(1-t,3);
const lum=(r,g,b)=>.299*r+.587*g+.114*b;
function plateau(d,r0,r1,p){ if(d<=r0) return 1; if(d>=r1) return 0; return Math.pow(1-(d-r0)/(r1-r0), p||1.5); }
function rectDist(x,y,x0,y0,x1,y1){ const dx=Math.max(x0-x,0,x-x1), dy=Math.max(y0-y,0,y-y1); return Math.hypot(dx,dy); }
function soft(v){ return v<200?v:200+55*(v-200)/(v-200+55); }

// stepped field: few levels, ordered dither between them, cut below half a level (quick edge)
function stepField(raw, levels){
  const idx=[], val=[];
  for(let y=0;y<H;y++) for(let x=0;x<W;x++){
    const i=y*W+x, v=raw[i];
    if(v < 0.5/levels) continue;
    // dither only near a level change: bands are solid, edges are a quick checker
    const f=v*levels, b=Math.floor(f), fr=f-b;
    const q=(b + ((fr-0.5)*3.5+0.5 > BAY[(y&3)*4+(x&3)] ? 1 : 0))/levels;
    if(q>0){ idx.push(i); val.push(q); }
  }
  return {idx:Int32Array.from(idx), val:Float32Array.from(val)};
}
function flood(seedX,seedY,box,test){
  const seen=new Uint8Array(N), list=[], st=[[seedX,seedY]];
  while(st.length){ const [x,y]=st.pop(); if(x<box[0]||x>box[2]||y<box[1]||y>box[3]) continue;
    const i=y*W+x; if(seen[i]) continue; seen[i]=1; if(!test(i)) continue; list.push(i);
    st.push([x+1,y],[x-1,y],[x,y+1],[x,y-1]); }
  return list;
}
// Nov 17 lighting pass (desk_1 v7, no normal map, is the model Jon approved: "oh YEAH WAYYYY BETTER"):
// lights lift the art's own values (a multiply, barely any add); fields are plateaus with dithered
// edges, and faint light stays flat (no checker on the dark walls).
const bayN=(x,y)=>BAY[(y&3)*4+(x&3)];
function bandStepN(d,bands,E,b){ let s=0; for(const [r,v] of bands){ const e=v<0.1?0.5:E; const f=(r-d)/e+0.5; if(f>=1||(f>0&&f>b)) s+=v; } return s; }
function qN(v,b){ return v<0.14 ? Math.round(v*40)/40 : Math.floor(v*10+b)/10; }
function fieldFrom(f){ const idx=[], val=[]; for(let i=0;i<N;i++) if(f[i]>0.004){ idx.push(i); val.push(f[i]); } return {idx:Int32Array.from(idx), val:Float32Array.from(val)}; }
function poly(pts){ const m=new Uint8Array(N); let x0=W,y0=H,x1=0,y1=0;
  for(const [x,y] of pts){ x0=Math.min(x0,x); x1=Math.max(x1,x); y0=Math.min(y0,y); y1=Math.max(y1,y); }
  for(let y=y0;y<=y1;y++) for(let x=x0;x<=x1;x++){ let ins=false;
    for(let a=0,b=pts.length-1;a<pts.length;b=a++){ const [xa,ya]=pts[a],[xb,yb]=pts[b];
      if((ya>y+.5)!==(yb>y+.5) && x+.5 < (xb-xa)*(y+.5-ya)/(yb-ya)+xa) ins=!ins; }
    if(ins) m[y*W+x]=1; }
  return m; }
function vnoise(t,seed){ const i=Math.floor(t), f=t-i, k=f*f*(3-2*f); return (hh(i*13+seed)*(1-k)+hh((i+1)*13+seed)*k)*2-1; }
let Fa, KSPEC, coneI, coneV, Fc, SCH=[.55,.95,.9], schN=0, crtF=null, KBd=null;
const LAMP_BZ=109, LAMP_T=2.2;                   // the bulb's centre up inside the cone shade; the cone's spread
function boxPick(box,test){ const l=[]; for(let y=box[1];y<=box[3];y++) for(let x=box[0];x<=box[2];x++){ const i=y*W+x; if(test(i,x,y)) l.push(i);} return l; }
// A prop's own pixels, never the desk or wall that share its box (Nov 17, Jon: "the coffee cup in the nook
// has a boxy background"; picking by colour inside a box lit the dark desk round the mug as if it were the
// mug). Its body is flood-filled from a seed inside it; then the dark outline that touches the body, and
// the dark shading the body encloses (the inside of the rim). Holes that show the desk stay desk.
function propMask(box,seed,body,lum3,lineMax){
  const [x0,y0,x1,y1]=box, m=new Uint8Array(N), inb=(x,y)=>x>=x0&&x<=x1&&y>=y0&&y<=y1, st=[seed];
  while(st.length){ const [x,y]=st.pop(); if(!inb(x,y)) continue; const i=y*W+x; if(m[i]||!body(i)) continue; m[i]=1; st.push([x+1,y],[x-1,y],[x,y+1],[x,y-1]); }
  for(let y=y0;y<=y1;y++) for(let x=x0;x<=x1;x++){ const i=y*W+x; if(m[i]||lum3(i)>lineMax) continue;
    for(let dy=-1;dy<=1&&!m[i];dy++) for(let dx=-1;dx<=1;dx++) if(inb(x+dx,y+dy) && m[(y+dy)*W+x+dx]===1){ m[i]=2; break; } }
  const outside=new Uint8Array(N), q=[];
  for(let x=x0;x<=x1;x++) q.push([x,y0],[x,y1]); for(let y=y0;y<=y1;y++) q.push([x0,y],[x1,y]);
  while(q.length){ const [x,y]=q.pop(); if(!inb(x,y)) continue; const i=y*W+x; if(outside[i]||m[i]) continue; outside[i]=1; q.push([x+1,y],[x-1,y],[x,y+1],[x,y-1]); }
  for(let y=y0;y<=y1;y++) for(let x=x0;x<=x1;x++){ const i=y*W+x; if(!m[i] && !outside[i] && lum3(i)<=30) m[i]=1; }
  for(let i=0;i<N;i++) if(m[i]) m[i]=1;
  return m;
}
// ---------- steam (Nov 17): desk_1's steam, the one Jon approved ("the steam can be more prominent") ----------
// Wisps curl up off the mug's opening (x, y: the opening's centre and two rows below the rim's top, as on
// desk 1); each pixel keeps the strongest wisp over it, alpha in dithered steps. It scatters the room's light,
// so even over the dark wall it reads as a pale veil, and it only ever lightens. dir -1 leans it left.
const MUGS=[{x:118, y:185, seed:3, dir:-1}];   // the mug under the chin: rim top y 183, opening x 114-124
const SBW=36, SBH=48, SA=new Float32Array(SBW*SBH);
function steamField(m,u){
  SA.fill(0);
  const NP=16, LIFE=4.6, dir=m.dir||1, x0=m.x-18, y0=m.y-46;
  const sway=Math.sin(u*.31+m.seed)*1.6;
  const mark=(x,y,a)=>{ const bx=x-x0, by=y-y0; if(bx<0||by<0||bx>=SBW||by>=SBH) return; const k=by*SBW+bx; if(a>SA[k]) SA[k]=a; };
  for(let p=0;p<NP;p++){
    const age=((u+p*LIFE/NP+m.seed*.37)%LIFE+LIFE)%LIFE, a=age/LIFE;
    const ph=hh(p*31+m.seed*7)*6.28, env=Math.pow(Math.sin(Math.PI*Math.min(1,a*1.25)),.7)*(1-a*.35);
    for(let tr=0;tr<5;tr++){
      const ag=age-tr*.1; if(ag<0) continue;
      const yy=Math.round(m.y-2-ag*8.2), amp=.5+ag*1.25;
      const xx=Math.round(m.x+amp*Math.sin(ag*1.7+ph+Math.sin(u*.45+p)*.8)+dir*ag*(.5+sway*.25)-.5);
      const al=.62*env*(1-tr*.14);
      mark(xx,yy,al);
      if(ag>.5) mark(xx+dir,yy,al*.75);
      if(ag>1.4){ mark(xx-dir,yy,al*.6); mark(xx,yy-1,al*.6); }
      if(ag>2.4){ mark(xx+2*dir,yy,al*.4); mark(xx-2*dir,yy+1,al*.3); }
    }
  }
  return [x0,y0];
}
// lightAt(i) -> the light multiplier [r,g,b] at a pixel; tint(x, cx) -> the light each side of the wisp takes
// (as desk 1 does: the side facing a light takes a little of its colour). Near the glass the steam thins out (by distance to
// the glass, dithered), so no edge ever cuts it.
function drawSteam(u,lightAt,tint){
  for(const m of MUGS){
    const [x0,y0]=steamField(m,u);
    for(let by=0;by<SBH;by++) for(let bx=0;bx<SBW;bx++){
      let al0=SA[by*SBW+bx]; if(al0<=.02) continue;
      const x=x0+bx, y=y0+by; if(x<0||x>=W||y<0||y>=H) continue;
      const i=y*W+x; if(emitId[i]) continue;
      al0*=Math.min(1, rectDist(x,y,GX,GY,GX+GW-1,GY+GH-1)/4);
      const al=Math.min(.56, Math.floor(al0/.14+bayN(x,y))*.14); if(al<=0) continue;
      const M=lightAt(i), T=tint(x,m.x+1), o=i*4;
      const sr=150*Math.min(M[0]*1.4+.4,1.3)+T[0], sg=156*Math.min(M[1]*1.4+.4,1.3)+T[1], sb=162*Math.min(M[2]*1.4+.4,1.3)+T[2];
      out[o]=Math.max(out[o],out[o]+(sr-out[o])*al); out[o+1]=Math.max(out[o+1],out[o+1]+(sg-out[o+1])*al); out[o+2]=Math.max(out[o+2],out[o+2]+(sb-out[o+2])*al);
    }
  }
}

// 3x5 font for the boot lines
const FONT={S:'111100111001111',C:'111100100100111',I:'111010010010111','-':'000000111000000',T:'111010010010010',
  E:'111100110100111',R:'110101110101101',M:'101111111101101','0':'111101101101111','3':'111001011001111',
  A:'010101111101101',D:'110101101101110',Y:'101101010010010',' ':'000000000000000','.':'000000000000010'};

// ---------- init ----------
async function init(){
  const [b, l, c]=await Promise.all([DESK.img('assets/nook_1_base.png'), DESK.img('assets/local.png'), DESK.img('assets/screen_culture.png')]);
  local=l;
  const cv=document.createElement('canvas'); cv.width=W; cv.height=H; const cg=cv.getContext('2d');
  cg.drawImage(b,0,0); const d=cg.getImageData(0,0,W,H).data;
  art=new Float32Array(N*3); for(let i=0;i<N;i++){ art[i*3]=d[i*4]; art[i*3+1]=d[i*4+1]; art[i*3+2]=d[i*4+2]; }
  // Nov 18 (Jon: "the keyboards still look really bad... flat and dimensionless"): the keyboard is redrawn in code
  // over its footprint (ROOMFX.drawKeyboard): keycap rows with lit tops, dark front lips and gaps, a case with a rim,
  // bevels and a front face, a contact shadow; painted into the art so every pass reads it
  { const FX=window.ROOMFX;
    const fp=FX.findKeyboard(art, W, H, [[143,189],[243,189],[248,209],[136,209]], [192,199], 22);
    const deskAt=(x,y)=>{ for(let r=1;r<12;r++) for(const xx of [x-r,x+r]){ const i=y*W+xx; if(xx>=0&&xx<W&&!fp.m[i]) return [art[i*3],art[i*3+1],art[i*3+2]]; } return [42,47,54]; };
    KBd=FX.drawKeyboard(art, W, H, fp, { pal: FX.kbPalette([162,156,140]), lay: FX.KB_FULL, seed: 4, desk: deskAt,
      rim: 1, bezel: 0, rows: [[1,1,0],[2,1,0],[2,1,0],[2,1,0],[2,1,0],[2,1,0]], fbezel: 1, face: 1, side: 2 }); }
  const cc=document.createElement('canvas'); cc.width=GW; cc.height=GH; const ccg=cc.getContext('2d'); ccg.drawImage(c,0,0);
  cult=ccg.getImageData(0,0,GW,GH).data;
  const R=i=>art[i*3], G=i=>art[i*3+1], B=i=>art[i*3+2], L=i=>lum(R(i),G(i),B(i));

  // --- emitters, picked by flood fill / tight boxes, never by a broad colour rule ---
  // the shade covers the bulb: only its warm inside lip (y 112) and the bulb's bottom sliver (y 113-114) show
  em.bulb=boxPick([348,112,368,114],i=>L(i)>=95 && R(i)>B(i)+20);
  em.port=flood(57,29,[44,15,68,42],i=>L(i)<48);
  em.portStars=[[50,22],[50,23],[50,24],[49,32]].map(([x,y])=>y*W+x);
  // string bulbs: bright warm components along the wire, top band only
  { const seen=new Uint8Array(N); const isB=i=>L(i)>=165 && R(i)>=B(i);
    for(let y=0;y<34;y++) for(let x=50;x<296;x++){ const i=y*W+x; if(seen[i]||!isB(i)) continue;
      if(x>=MON.x0 && x<=MON.x1 && y>=MON.y0) continue;   // monitor A's putty highlights are not bulbs
      const comp=[], st=[[x,y]];
      while(st.length){ const [a,q]=st.pop(); if(a<0||a>=W||q<0||q>=34||(a>=MON.x0&&a<=MON.x1&&q>=MON.y0)) continue; const j=q*W+a; if(seen[j]||!isB(j)) continue; seen[j]=1; comp.push(j); st.push([a+1,q],[a-1,q],[a,q+1],[a,q-1]); }
      if(comp.length>=4){ let sx=0,sy=0; for(const j of comp){sx+=j%W; sy+=(j/W)|0;} strBulbs.push({px:comp, x:sx/comp.length, y:sy/comp.length}); }
    }
    strBulbs.sort((a,b)=>a.x-b.x);
    strBulbs.forEach((s,k)=>{ s.on=T.str + k*0.043 + hh(k*7+1)*0.05; s.flick=hh(k*13+5)<0.4; s.p=2.4+hh(k*3+2)*3.6; s.ph=hh(k*5+9)*6.283; s.p2=0.9+hh(k*11+3)*0.8; s.seg=Math.min(3,(k*4/strBulbs.length)|0); });
  }
  // LEDs: tight boxes, explicit colour tests
  const sat=i=>Math.max(R(i),G(i),B(i))-Math.min(R(i),G(i),B(i));
  const green=i=>G(i)>R(i)+25 && G(i)>=90;
  const addLed=(name,px,on,col,mode)=>{ if(px.length) ledList.push({name,px,on,col,mode}); };
  addLed('desk',  boxPick([65,195,67,197],i=>R(i)>150 && R(i)>B(i)+40), T.main, [1.35,1.05,0.6],'steady');   // the switch panel's amber lamp
  addLed('mon',   boxPick([127,168,130,171],i=>green(i)), T.crt, [0.75,1.4,0.9],'steady');                  // monitor A's power LED, on the chin
  addLed('barA',  boxPick([346,15,354,17],i=>green(i)), T.rack, [0.9,1.35,1.1],'steady');
  addLed('barB',  boxPick([346,23,354,25],i=>green(i)), T.rack+0.18, [0.9,1.35,1.1],'busy');
  addLed('pipA',  boxPick([348,18,353,20],i=>R(i)>110 && R(i)>B(i)+40), T.rack+0.32, [1.4,1.15,0.7],'steady');
  addLed('pipB',  boxPick([348,26,353,28],i=>R(i)>150 && R(i)>B(i)+40), T.rack+0.44, [1.4,1.15,0.7],'heart');
  addLed('pipC',  boxPick([348,34,356,43],i=>R(i)>150 && R(i)>B(i)+40), T.rack+0.55, [1.4,1.0,0.6],'steady');
  addLed('disp',  boxPick([357,14,368,18],i=>green(i)), T.rack+0.25, [0.9,1.3,1.0],'blinkdot');
  addLed('arm',   boxPick([317,39,323,41],i=>green(i)), T.arm, [0.85,1.4,1.1],'breathe');
  addLed('keypad',boxPick([354,151,363,159],i=>R(i)>150 && R(i)>B(i)+50), T.rack+0.7, [1.35,1.0,0.55],'lcd');
  addLed('scopeL',boxPick([34,94,46,125],i=>sat(i)>=40 && L(i)>=90 && G(i)>=R(i)-30), T.scope+0.1, [1.0,1.3,0.9],'steady');
  addLed('scopeG',boxPick([7,118,12,124],i=>green(i)), T.scope, [0.8,1.4,0.8],'steady');
  addLed('eyes',  boxPick([70,120,75,124],i=>green(i)), T.bot, [0.9,1.4,1.1],'eyes');
  // rack readout strip (drawn by code): y16, x305..329
  em.readout=[]; for(let x=305;x<=329;x++) em.readout.push(16*W+x);

  emitId=new Int8Array(N);   // 1 = handled by an emitter pass, skip room light
  const mark=l=>{ for(const i of l) emitId[i]=1; };
  mark(em.bulb); mark(em.port); mark(em.portStars); strBulbs.forEach(s=>mark(s.px)); ledList.forEach(e=>mark(e.px)); mark(em.readout);
  for(let y=GY;y<GY+GH;y++) for(let x=GX;x<GX+GW;x++) emitId[y*W+x]=1;
  for(let y=SC.y0;y<=SC.y1;y++) for(let x=SC.x0;x<=SC.x1;x++) emitId[y*W+x]=1;

  // --- light fields (steady shape, stepped once) ---
  const raw=()=>new Float32Array(N);
  // 1 rack bulb (Nov 17): light leaves the cone shade's mouth DOWN and out. Where the cone meets the cubby's
  // back wall it draws an arch, lowest at the sides; below it the wall falls off with 3D distance from the
  // bulb in plateaus; above it only a faint flat bounce. The shelf plank and the shelf over the cubby keep
  // their shadows. An elliptical pool lies on the plank under the shade.
  { const f=raw();
    const bands=[[8,.32],[14,.26],[22,.2],[32,.16],[46,.12],[64,.08],[86,.05]];
    for(let y=0;y<H;y++) for(let x=0;x<W;x++){
      const b=bayN(x,y), dz=6, hz=Math.hypot(x-BX,dz), yTop=LAMP_BZ+hz/LAMP_T;
      const r=Math.hypot(x-BX,y-LAMP_BZ,dz);
      let v=bandStepN(r,bands,3,b);
      const fe=(y-yTop)/2.5+0.5;
      if(!(fe>=1||(fe>0&&fe>b))) v*=0.06;
      // the pool on the plank, under the shade
      if(y>=121 && y<=127 && x>=300 && x<=373) v=Math.max(v, bandStepN(Math.hypot(x-BX,(y-124)*3), [[10,.5],[20,.35],[32,.22]], 2, b));
      const shelf=(yy,x0,x1,dark)=>{ const tt=(yy-BY)/(y-BY); const cx=BX+(x-BX)*tt; const e=Math.min(cx-x0,x1-cx); if(e>-3){ v*=1-(1-dark)*cl((e+3)/6,0,1);} };
      if(y>127) shelf(127,300,374,0.3);   // a faint warm spill gets past the plank's edge onto the shelf's things
      if(x>374) v*=0.3;            // past the rack's side wall
      if(x>=MON.x0 && x<=MON.x1 && y>=MON.y0 && y<=MON.y1) v*=0.5;
      f[y*W+x]=qN(v,b);
    }
    fields.push({name:'bulb',...fieldFrom(f),col:[1,0.8,0.55]});
  }
  // 2-5 string light segments: each bulb a small warm pool along the wire, brighter wins
  for(let s=0;s<4;s++){ const f=raw();
    for(const b of strBulbs.filter(q=>q.seg===s)){
      for(let y=Math.max(0,(b.y-44)|0);y<Math.min(H,b.y+44);y++) for(let x=Math.max(0,(b.x-44)|0);x<Math.min(W,b.x+44);x++){
        const onMon=(x>=MON.x0&&x<=MON.x1&&y>=MON.y0);
        const d=Math.hypot(x-b.x,(y-b.y)*(y>b.y && !onMon?0.62:1.1));   // Nov 17: each halo falls down the wall below its bulb (not down the monitor's face)
        const v=Math.max(0.8*plateau(d,1.5,9,1.5), 0.42*plateau(d,0,20,1.2), 0.2*plateau(d,0,42,1.3));
        const i=y*W+x, mk=(x>=MON.x0&&x<=MON.x1&&y>=MON.y0)?0.6:1; if(v*mk>f[i]) f[i]=v*mk; }   // softer on monitor A's case
    }
    fields.push({name:'str'+s,...stepField(f,5),col:[1,0.78,0.5]});
  }
  // 6 CRT (Nov 17): the screen is the room's big light. A glow on the bezel's inner lip, a gentle lift on
  // the chin, and a wide fan over the desk. Things standing on the desk read the light at their own feet
  // (no band edge crosses them), weighted by the art's own value: lit key tops lift most, fronts and gaps
  // barely; the mug is a cylinder lit from the screen's side. The book pile and the microscope throw one
  // soft shadow each, forward and left, away from the glass. Contact shadows sit only under feet.
  { const f=raw(), Lm=i=>L(i);
    const KEYB=poly([[143,189],[243,189],[248,209],[136,209]]);
    const BOOKS=poly([[11,167],[51,167],[53,197],[11,197]]);
    const SCOPE=poly([[78,160],[100,160],[102,197],[76,197]]);
    // the mug's own pixels (Nov 17: a box by colour took in the dark desk round it, lit as the mug)
    const avg3=i=>(R(i)+G(i)+B(i))/3;
    const MUG=propMask([106,180,132,205],[119,193],i=>R(i)>=B(i)-5 && avg3(i)>=36,avg3,20);
    // the book pile, the bottles and the microscope are lit as things, but only on their own pixels (Nov 17).
    // The boxes above also hold the wall behind them, which lit as pale boxes; skipping the wall's colours
    // then darkened the microscope's own dark head and eyepiece (Jon: "the top of the microscope is cut off?").
    // So each is a shape traced round the prop, minus the wall that reaches in from outside it through the
    // wall's own colours; the prop's dark parts sit inside its black outline, so they stay lit.
    const WALLC=new Set([0x111823,0x1b2027,0x22303f,0x05080d,0x16202c]);
    const wallc=i=>WALLC.has((Math.round(R(i))<<16)|(Math.round(G(i))<<8)|Math.round(B(i)));
    const silhouette=pts=>{ const m=poly(pts), st=[];
      for(let i=0;i<N;i++) if(m[i] && wallc(i)){ const x=i%W; if(!m[i-1]||!m[i+1]||!m[i-W]||!m[i+W]||x===0||x===W-1) st.push(i); }
      while(st.length){ const i=st.pop(); if(m[i]!==1 || !wallc(i)) continue; m[i]=2; const x=i%W;
        if(x>0) st.push(i-1); if(x<W-1) st.push(i+1); if(i>=W) st.push(i-W); if(i<N-W) st.push(i+W); }
      for(let i=0;i<N;i++) if(m[i]===2) m[i]=0;
      return m; };
    const BOOKS_L=silhouette([[11,167],[51,167],[53,197],[11,197]]);                    // the pile fills its box
    const SCOPE_L=silhouette([[80,162],[97,162],[100,165],[102,168],[102,198],[74,198],[74,177],[76,176],[76,169],[79,166]]);
    for(let y=0;y<H;y++) for(let x=0;x<W;x++){
      const i=y*W+x, b=bayN(x,y);
      if(x>=GX && x<GX+GW && y>=GY && y<GY+GH) continue;
      let v=0;
      const dr=rectDist(x,y,GX,GY,GX+GW-1,GY+GH-1);
      if(dr<4) v=bandStepN(dr,[[2.5,.5]],1.5,b);
      if(x>=MON.x0 && x<=MON.x1 && y>=GY+GH+2 && y<=176) v=Math.max(v, 0.1);
      const beside = x<MON.x0 || x>MON.x1;
      if(y>MON.y1 || (y>=183) || (y>=150 && beside && L(i)>=58)){
        const d=Math.hypot(Math.max(0,Math.abs(x-192)-72), Math.max(0,y-176)*1.15);
        v=Math.max(v, bandStepN(d,[[10,.46],[26,.38],[46,.29],[72,.2],[105,.12],[150,.06]],3,b));
      }
      f[i]=v;
    }
    const tone=i=>.4+.8*cl((L(i)-55)/110,0,1);
    const footK=f[200*W+192]; let footM=0; for(let x=104;x<=134;x++) for(let y=203;y<=207;y++) footM=Math.max(footM,f[y*W+x]); footM*=1.3;
    const ks=[];
    for(let i=0;i<N;i++){
      if(MUG[i]){ const x=i%W, y=(i/W)|0, nx=(x-120)/7.5+(bayN(x,y)-.5)*.14;
        const cyl= x<114 ? .8 : nx>.35 ? 1.25 : nx>-.3 ? 1.02 : .76;     // the screen is to its right
        f[i]=footM*cyl*tone(i); }
      else if(KEYB[i]){ f[i]=footK*tone(i); if(L(i)>=105 && L(i)-L(i-W)>=22) ks.push(i); }
    }
    KSPEC=Int32Array.from(ks);
    // the book pile, the bottles and the microscope stand in the screen's glow too: read at their feet,
    // weighted by the art's own value (spines and brass lift, the dark between stays dark), and the warm
    // string swag over the left wall falls on their tops
    const BOTTLES=poly([[55,158],[75,158],[76,198],[54,198]]);
    const fsw=raw();
    const BOTTLES_L=silhouette([[57,163],[62,163],[62,168],[66,170],[66,172],[72,172],[72,176],[74,177],[74,198],[54,198],[54,170],[57,168]]);
    for(let i=0;i<N;i++){ if(!(BOOKS_L[i]||SCOPE_L[i]||BOTTLES_L[i])) continue;
      const y=(i/W)|0, foot=SCOPE_L[i]?.4:BOTTLES_L[i]?.36:.32;
      f[i]=Math.max(f[i], foot*tone(i));
      fsw[i]=qN(.34*tone(i)*cl(1-(y-158)/50,.25,1), bayN(i%W,y)); }
    fields.push({name:'str0',...fieldFrom(fsw),col:[1,0.74,0.45]});
    // cast shadows: march toward the lower glass, nine points across it; three dithered steps
    const SX=[140,152,164,176,188,200,212,224,236], SY=150;
    for(let y=183;y<H;y++) for(let x=0;x<130;x++){
      const i=y*W+x; if(!f[i] || BOOKS[i] || SCOPE[i]) continue;
      let vis=0;
      for(const sx of SX){ const dx=sx-x, dy=SY-y, d=Math.hypot(dx,dy), ux=dx/d, uy=dy/d; let hit=false;
        for(let k=1;k<=14;k++){ const j=Math.round(y+uy*k)*W+Math.round(x+ux*k); if(BOOKS[j]||SCOPE[j]){ hit=true; break; } }
        if(!hit) vis++; }
      const q=Math.floor(vis/SX.length*3+bayN(x,y)*.999)/3;
      f[i]*= .35+.65*q;
    }
    // contact shadows, found in the art: where an outline gives way to desk, one row (two, dithered, under heavier things)
    const ao=new Float32Array(N).fill(1);
    const BASES=[[12,50,198,2],[77,101,197,2],[113,127,203,1],[56,74,197,1],[287,300,183,1]];
    for(const [x0,x1,yh,rows] of BASES) for(let x=x0;x<=x1;x++) for(let y=yh-5;y<=yh+4&&y<H-1;y++){
      const i=y*W+x; if(L(i-W)<48 && L(i)>=55 && !BOOKS[i] && !SCOPE[i]){ ao[i]=Math.min(ao[i],.74); if(rows>1 && bayN(x,y+1)<.5) ao[i+W]=Math.min(ao[i+W],.88); break; } }
    for(let i=0;i<N;i++) f[i]*=ao[i];
    for(const F of fields) for(let j=0;j<F.idx.length;j++) F.val[j]*=ao[F.idx[j]];
    window.__nookAO=ao;
    crtF={name:'crt',...fieldFrom(f),col:[.55,1,.89]};
    fields.push(crtF);
  }
  // 7 oscilloscope: a small green glow on its own bezel and case round the glass, falling off within a few
  // pixels. (Nov 17, Jon: "the circular light here makes no sense?": a third, 74 px wide term lit the notes,
  // the jar shelf and the wall as one big green disc no small screen could throw.)
  { const f=raw();
    for(let y=SC.y0-20;y<=SC.y1+20;y++) for(let x=0;x<=SC.x1+20;x++){
      const d=rectDist(x,y,SC.x0,SC.y0,SC.x1,SC.y1);
      f[y*W+x]=Math.max(0.85*plateau(d,0,5,1.2), 0.32*plateau(d,0,13,1.3)); }
    fields.push({name:'scope',...stepField(f,5),col:[0.5,1,0.6]});
  }
  // 8 porthole: faint cold starlight on its ring
  { const f=raw();
    for(let y=6;y<54;y++) for(let x=30;x<86;x++){ const d=Math.hypot(x-56.5,y-29); f[y*W+x]=0.32*plateau(d,12,20,1.2); }
    fields.push({name:'port',...stepField(f,4),col:[0.6,0.75,1]});
  }

  // the room falls darker toward its edges and top, in dithered steps (Nov 17); contact shadows darken it too
  Fa=new Float32Array(N);
  for(let y=0;y<H;y++) for(let x=0;x<W;x++){ const i=y*W+x, q=((x-192)/235)**2+((y-118)/150)**2+(bayN(x,y)-.5)*.1;
    let a=q<.5?1:q<.8?.74:q<1.15?.54:.4;
    if(y>=158 && y<209) a=Math.max(a, y>=170 ? .88 : (bayN(x,y)<.5?.88:a));   // the desk reads, as on desk 1
    if(y>=209) a*= y>=212?.45:.65; Fa[i]=a*window.__nookAO[i]; }
  // the light under the rack lamp's shade: a short warm cone, smooth inside, dithered edge
  { Fc=new Float32Array(N); const ci=[], cv=[];
    for(let y=114;y<=124;y++) for(let x=338;x<=378;x++){ const i=y*W+x; if(emitId[i]) continue;
      const tt=(y-112)/13, hw=10+tt*8, e=(hw-Math.abs(x+.5-BX-.5))/2+.5; if(!(e>=1||(e>0&&e>bayN(x,y)))) continue;
      const v=Math.pow(cl(1-tt/.9,0,1),1.3); if(v<=.02) continue; Fc[i]=v; ci.push(i); cv.push(v); }
    coneI=Int32Array.from(ci); coneV=Float32Array.from(cv); }
  off=document.createElement('canvas'); off.width=W; off.height=H; offg=off.getContext('2d');
  img=offg.createImageData(W,H); out=img.data;
  Lr=new Float32Array(N); Lg=new Float32Array(N); Lb=new Float32Array(N);
  window.__nook={fields, strBulbs, ledList, em, hh, debug:false};
  buildGlass();
  buildC();
  ok=true;
}
// ---------- C LIGHTING (Jon's pick, Nov 18; desk 1's, on the shared engine ROOMFX.makeLit) ----------
// The old fields here were cut by boxes and rows: the rack bulb's pool was a rectangle on the plank (x 300-373,
// y 121-127) and stopped at x 374, the screen's spill switched on at row 183, the monitor's box halved the bulb's
// light, and each string halo was cut by its own 88 px box. Now every light falls off by distance and angle from its
// source in the room's own space (the desk and the rack's plank face up, the wall faces you), props are flood-filled
// or traced round their own pixels, the plank throws the bulb's shadow, and the C ramp steps the summed light.
let LIT=null, CCN={}, FLD={}, SMALL=[], NS=0, DUSTC=null, SKY=null, Lc=null, A2=null;
function buildC(){
  const FX=window.ROOMFX, D2R=Math.PI/180, L=i=>lum(art[i*3],art[i*3+1],art[i*3+2]);
  const R0=i=>art[i*3], B0=i=>art[i*3+2], avg3=i=>(art[i*3]+art[i*3+1]+art[i*3+2])/3;
  const MONm=FX.propMask(art, W, H, [104,6,279,188], [110,100], i=>{ const x=i%W, y=(i/W)|0;
    return !(x>=GX&&x<GX+GW&&y>=GY&&y<GY+GH) && L(i)>=50 && (y<=176 || (x>=178&&x<=208)); }, 26);
  const MUGm=FX.propMask(art, W, H, [106,180,132,205], [119,193], i=>R0(i)>=B0(i)-5 && avg3(i)>=36, 20);
  const WALLC=new Set([0x111823,0x1b2027,0x22303f,0x05080d,0x16202c]);
  const notWall=i=>!WALLC.has((Math.round(art[i*3])<<16)|(Math.round(art[i*3+1])<<8)|Math.round(art[i*3+2]));
  const BOOKm=FX.propMask(art, W, H, [8,160,56,200], [30,185], i=>notWall(i) && L(i)>=28, 22);
  const SCOPEm=FX.propMask(art, W, H, [72,158,104,200], [88,190], i=>notWall(i) && L(i)>=28, 22);
  const BOTm=FX.propMask(art, W, H, [52,156,77,200], [64,190], i=>notWall(i) && L(i)>=28, 22);
  // the rack's plank (Nov 19, Jon: "weird shadow here"): in the art it is a thin shelf seen almost edge-on, a dark
  // front face on rows 126-128 between outline rows 125 and 129. Its old mask was flood-filled through rows 120-129,
  // so it leaked up into the dark wall and the things standing on it; rows 121-125 were then lit as an up-facing top
  // (the hard bright band), and its shadow was tested at three depth slices, which a thin flat shelf falls between
  // (the straight dark band under it, with lit wall above and below). Now the mask is the plank's own rows only,
  // its front face faces you, and its shadow is a ray test against its own plane (below).
  const PLANK=FX.propMask(art, W, H, [296,124,376,129], [350,127], i=>L(i)>=26 && ((i/W)|0)>=126, 22);
  const PCOL=new Uint8Array(W); for(let i=0;i<N;i++) if(PLANK[i]) PCOL[i%W]=1;
  const skip=new Uint8Array(N); for(let i=0;i<N;i++) if(emitId[i]) skip[i]=1;
  LIT=FX.makeLit({ W, H, A: art, skip, deskY: 185, deskF: 209, kz: 5, kb: KBd,
    // the plank's front face faces you, at its front edge (15 deep), under its top (63 over the desk)
    geo: (x,y)=> PLANK[y*W+x] ? [15, 63-(y-125), 0, 0, 1, 1] : null,
    props: [ { m: MONm, foot: 188, deep: 14, up: .15, contact: false, bounce: .25, wrap: 0, gain: .6 },   // 0 the monitor
             { m: MUGm, foot: 204, heavy: true, cyl: true, up: .2, bounce: .9 },              // 1 the mug
             { m: BOOKm, foot: 197, heavy: true },                                           // 2 the book pile
             { m: SCOPEm, foot: 198, heavy: true },                                          // 3 the microscope
             { m: BOTm, foot: 197, cyl: true } ] });                                         // 4 the bottles
  FLD.bulb=LIT.norm(LIT.point({ x: BX+.5, y: 108, z: 8, I: 1, r0: 16, rMax: 200, axis: [0,-.98,.2],
    cosIn: Math.cos(52*D2R), cosOut: Math.cos(80*D2R), spill: .06, wrap: .15, occ: [0], spread: 6, samples: 5 }), 330, 140, .45);
  // the plank's shadow: from each pixel, a ray to five points across the bulb; where it crosses the plank's top plane
  // (its underside, 60 over the desk) inside the plank's depth (0-15) and inside its length, the plank is in the way. Soft at the
  // plank's ends (the bulb's width), the same 12% floor as every other shadow, stepped by the C ramp like the rest.
  { const F=FLD.bulb, PX=LIT.PX, PH=LIT.PH, PZ=LIT.PZ, LX=BX+.5, LZ=8, LH=185+LZ/5-108, HP=60, NSm=5;   // HP: the plank's underside (its front face is 3 rows thick)
    // the cubby's two side walls (the rack's frame posts at x 373 and 299, 15 deep, up to its top rail at row 90)
    // stop the light the same way: a ray that crosses either inside the cubby's depth and height is blocked
    const SIDES=[373.5, 299.5], HTOP=185-90;
    for(let i=0;i<N;i++){ if(!F[i] || PLANK[i]) continue;
      const ph=PH[i], px=PX[i], pz=PZ[i];
      const under=ph<HP, out=px>SIDES[0]+.5 || px<SIDES[1]-.5;
      if(!under && !out) continue;                                  // inside the cubby, above the plank: open to the bulb
      let vis=0;
      for(let s2=0;s2<NSm;s2++){ const lx=LX+(s2/(NSm-1)-.5)*6;
        let hit=false;
        if(under){ const t=(HP-ph)/(LH-ph);
          if(t>0 && t<1){ const qz=pz+t*(LZ-pz), qx=Math.floor(px+t*(lx-px)); if(qz>=0 && qz<=15 && qx>=0 && qx<W && PCOL[qx]) hit=true; } }
        if(!hit && out) for(const sx of SIDES){ const t=(sx-px)/(lx-px);
          if(!(t>0 && t<1)) continue;
          const qz=pz+t*(LZ-pz), qh=ph+t*(LH-ph); if(qz>=0 && qz<=15 && qh>=0 && qh<=HTOP){ hit=true; break; } }
        if(!hit) vis++; }
      if(vis<NSm) F[i]*=.12+.88*vis/NSm; } }
  FLD.scr=LIT.norm(LIT.panel({ rect: [118,23,265,160], z: 10, I: 1, r0: 200, rMax: 380, nx: 6, ny: 4, wrap: .1, occ: [1,2,3,4] }), 128, 206, 1.1);
  FLD.scope=LIT.norm(LIT.panel({ rect: [SC.x0,SC.y0,SC.x1+1,SC.y1+1], z: 3, I: 1, r0: 8, rMax: 40, nx: 3, ny: 3, wrap: .5 }), 24, 114, .5);
  FLD.port=LIT.norm(LIT.panel({ rect: [44,17,70,42], z: 3, I: 1, r0: 24, rMax: 120, nx: 4, ny: 4, wrap: .6, disc: true }), 57, 48, .2);
  SMALL=strBulbs.map(b=>{ const q=LIT.pointBox({ x: b.x+.5, y: b.y+.5, z: 5, I: 1, r0: 5, rMax: 24, wrap: .8, squash: .62, bounce: false });
    let mx=0; for(const v of q.f) mx=Math.max(mx,v); if(mx>0) for(let k=0;k<q.f.length;k++) q.f[k]*=.7/mx; q.tint=[1,.8,.55]; return q; });
  NS=SMALL.length;
  for(const e of ledList){ let sx=0, sy=0; for(const i of e.px){ sx+=i%W; sy+=(i/W)|0; }
    const q=LIT.pointBox({ x: sx/e.px.length+.5, y: sy/e.px.length+.5, z: 2, I: 1, r0: 1.6, rMax: 6, wrap: .8, bounce: false });
    let mx=0; for(const v of q.f) mx=Math.max(mx,v); if(mx>0) for(let k=0;k<q.f.length;k++) q.f[k]*=.4/mx;
    const m=Math.max(...e.col); q.tint=e.col.map(v=>v/m); SMALL.push(q); }
  A2=FX.settleDust(art, W, H, { seed: 6, density: .045, amount: .2,
    mask: (x,y)=>{ const i=y*W+x; return y>=186 && y<=209 && !KBd.part[i] && !skip[i] && L(i)>30 && L(i)<205; } });
  DUSTC=FX.makeDust({ W, H, count: 140, seed: 8, box: [2,4,380,212],
    density: (x,y)=>{ const i=y*W+x; return .1+.9*cl(FLD.bulb[i]*.9+FLD.scr[i]*1.1, 0, 1); }, skip: i=>x_glass(i) });
  SKY=FX.makeSky({ W, idx: em.port.concat(em.portStars), cx: 56.5, cy: 29, r: 11, seed: 4 });
  (window.__C=window.__C||{}).nook_1={ LIT, FLD, KB: KBd };
  Lc=new Float32Array(N*3);
}
function x_glass(i){ const x=i%W, y=(i/W)|0; return x>=GX&&x<GX+GW&&y>=GY&&y<GY+GH; }

// ---------- clocks ----------
// t is the timeline (it runs backwards when the player leaves); R is real time, always forward,
// and drives everything that is idle life, so steam never sinks and the scope never runs backwards.
let R=0, LEAV=false;

// ---------- the CRT glass: recess, tube shape, reflection (built once) ----------
let gMask, gRefl, scr, glowB;
const RING={top:[],top2:[],bot:[],bot2:[],left:[],right:[],right2:[]};
function buildGlass(){
  gMask=new Float32Array(GW*GH); scr=new Float32Array(GW*GH*3); glowB=new Float32Array(GW*GH*3);
  const bay=(x,y)=>BAY[(y&3)*4+(x&3)];
  // the bezel's shadow on the glass: stepped, the last step dithered
  const sh=(d,x,y)=> d===0?0.1 : d===1?0.38 : d===2?0.6 : d===3?0.78 : d===4?(bay(x,y)<0.5?0.8:0.92) : d===5?(bay(x,y)<0.5?0.92:1) : 1;
  for(let ly=0;ly<GH;ly++) for(let lx=0;lx<GW;lx++){
    let m=1;
    // rounded tube corners
    const cxD= lx<7?7-lx : lx>GW-8?lx-(GW-8) : 0, cyD= ly<7?7-ly : ly>GH-8?ly-(GH-8) : 0;
    if(cxD>3&&cyD>3){ const d=Math.hypot(cxD-3,cyD-3); if(d>4.3) m=0.04; else if(d>3.3) m=0.4; }   // a small corner; the tube rounds the rest
    // Nov 17 (Jon: the glass effect "doesn't work well"): no recess lips, one faint even darkening toward the corners
    const nx=(lx-74.5)/75, ny=(ly-69.5)/70, c=nx**4+ny**4+(bay(lx,ly)-.5)*.1;
    m*= c>1.2?.9 : c>.8?.95 : 1;
    if(Math.min(lx,ly,GW-1-lx,GH-1-ly)===0) m=Math.min(m,.6);
    gMask[ly*GW+lx]=m;
  }
  // a curved reflection of the string lights in the bulging glass, top right; it never moves with the picture
  gRefl=[]; const C=[118,34], Rr=30; const arc=[];
  for(let ly=0;ly<40;ly++) for(let lx=110;lx<GW;lx++){
    const d=Math.hypot(lx-C[0],ly-C[1]), off=Math.abs(d-Rr);
    const ang=Math.atan2(ly-C[1],lx-C[0]);             // ~1.75 (left end) .. ~0.6 (right end)
    const along=(ang+1.4)/1.25; if(along<0||along>1) continue;
    const fade=Math.ceil(Math.min(1,Math.sin(Math.PI*along)*1.6)*3)/3;
    let w=0; if(off<1) w=0.5; else if(off<2) w=0.32; else if(off<3 && bay(lx,ly)<0.5) w=0.16;
    if(w>0){ gRefl.push([ly*GW+lx, w*fade, 0]); if(off<0.5) arc.push([ang, ly*GW+lx, fade]); }
  }
  arc.sort((a,b)=>a[0]-b[0]); arc.forEach((p,k)=>{ if(k%5===2) gRefl.push([p[1], 0.9*p[2], 1]); });   // the bulbs themselves, as small warm dots
  // the bezel's inner lip: the lower edge faces up at the string lights and catches them; the top edge faces down, dark
  for(let x=GX-1;x<=GX+GW;x++){ RING.top.push((GY-1)*W+x); RING.top2.push((GY-2)*W+x); RING.bot.push((GY+GH)*W+x); RING.bot2.push((GY+GH+1)*W+x); }
  for(let y=GY;y<GY+GH;y++){ RING.left.push(y*W+GX-1); RING.right.push(y*W+GX+GW); RING.right2.push(y*W+GX+GW+1); }
}

// ---------- glitches: one every 3-8 s, a different kind each time, never two at once ----------
const GL=[]; { let tt=6, prev=''; for(let n=0;tt<4000;n++){ const kinds=['jit','rgb','jit','rgb','jit','vhold'];   /* static band removed (Jon) */
  let k=kinds[Math.floor(hh(n*7+301)*kinds.length)]; if(k===prev) k=kinds[(kinds.indexOf(k)+1+Math.floor(hh(n+9)*3))%3]; prev=k;
  GL.push({at:tt,type:k,n}); tt+=3+hh(n*11+303)*5; } }
const GDUR={jit:0.24, rgb:0.05, static:0.5, vhold:0.27};
function glitchAt(r){
  if(r<GL[0].at) return null; const span=GL[GL.length-1].at-GL[0].at; if(r>GL[GL.length-1].at) r=GL[0].at+((r-GL[0].at)%span);
  let lo=0,hi=GL.length-1; while(lo<hi){ const m=(lo+hi+1)>>1; if(GL[m].at<=r) lo=m; else hi=m-1; }
  const e=GL[lo], v=r-e.at; return v<GDUR[e.type]?{type:e.type,n:e.n,v}:null;
}
function glLight(g){ if(!g) return 1;
  switch(g.type){ case 'jit': return 0.97+0.03*hh(Math.floor(g.v*15)+g.n); case 'rgb': return 0.95;
    case 'static': return 1.03+0.03*hh(Math.floor(g.v*12)+g.n*3); case 'vhold': return g.v<0.09?0.88:g.v<0.17?1.05:1; } return 1; }
// faint, irregular brightness life of the tube (1-3%)
function flick(r){ return 1+0.012*Math.sin(r*7.3)+0.009*Math.sin(r*12.1+1)+0.006*Math.sin(r*19.3+2); }

// ---------- states ----------
function strB(s,k,t){
  const u=t-s.on; if(u<0) return 0;
  let b;
  if(s.flick && u<0.16) b = u<0.05?0.45 : u<0.09?0.04 : u<0.13?0.7 : 0.3;
  else b=0.2+0.8*eOut((u-(s.flick?0.16:0))/0.35);
  // idle: each bulb on its own slow clocks, never in sync, plus the swell that runs along the wire
  b*=1+0.12*Math.sin(R*6.283/s.p+s.ph)+0.05*Math.sin(R*6.283/s.p2+s.ph*2.1);
  b*=1+swell(k,R);
  if(k===9){ const P=13, e=Math.floor((R-6)/P), at=6+e*P+3+hh(e+31)*8, v=R-at;   // one loose bulb
    if(e>=0 && v>=0 && v<0.3) b*= v<0.06?0.55 : v<0.12?1 : v<0.18?0.65 : 1; }
  return b;
}
function strWarm(s,t){ return seg(t, s.on, s.on+0.6); }
function bulbB(t){
  const u=t-T.bulb; if(u<0) return 0;
  let b;
  if(u<0.12) b=0.22; else if(u<0.18) b=0.05; else if(u<0.25) b=0.55; else if(u<0.3) b=0.18;
  else b=0.32+0.68*ease((u-0.3)/0.75);
  let k=(1+0.045*Math.sin(R*6.283/5.3)+0.02*Math.sin(R*6.283/1.37+1))*(1-brown(R));
  // Nov 17: the filament wavers on two irregular clocks, and every 7-13 s eases down 6-9% for half a second
  k*=1+0.022*vnoise(R*1.7,61)+0.012*vnoise(R*4.3,67);
  { const P=10, ci=Math.floor(R/P), at=1.5+hh(ci*39+1)*6, a=R-ci*P-at, len=.45+hh(ci*22)*.25;
    if(a>0 && a<len) k*=1-(.06+hh(ci*71)*.03)*Math.sin(Math.PI*a/len); }
  return b*k;
}
// Leaving (Nov 19, Jon: "the lamp turning off sound doesn't match the light"): the switched-filament afterglow,
// AFTER scene seconds (0.14 s real at the 2.2x leave), eased out ((1 - x)^2), held in eighths, as in the other rooms
const AFTER=.3;
let LV_HOLD=1, LV_K=1;
function afterglow(a){ if(a<=0) return 1; if(a>=AFTER) return 0; const x=1-a/AFTER; return Math.round(x*x*8)/8; }
function bulbWarm(t){ return ease(seg(t,T.bulb+0.25,T.bulb+1.4)); }
// a swell that runs along the string every 7-11 s, one way or the other (about 3 s end to end)
function swell(k,r){ const P=9, e=Math.floor((r-8)/P); let g=0;
  for(let q=e-1;q<=e;q++){ if(q<0) continue; const at=8+q*P+hh(q*7+41)*3, v=r-at; if(v<0||v>4.5) continue;
    const n=strBulbs.length, dir=hh(q*3+17)<0.5, pos=-4+v*((n+8)/4.5), kk=dir?k:n-1-k, z=(kk-pos)/3.2;
    g+=0.45*Math.exp(-z*z); }
  return g; }
// the rack bulb: now and then the filament wavers and browns out for a moment
function brown(r){ const P=10.5, e=Math.floor((r-9)/P); if(e<0) return 0;
  if(hh(e*5+61)>0.75) return 0; const at=9+e*P+1+hh(e*3+67)*7, v=r-at; if(v<0||v>0.55) return 0;
  const depth=0.15+0.1*hh(e+71); const env= v<0.06? v/0.06 : v<0.3? 1 : 1-(v-0.3)/0.25;
  return depth*env*(0.8+0.2*Math.sin(v*40)); }
// slow warm-cool drift of the bulb's colour (0 = cooler, 1 = warmer)
function bulbDrift(r){ return 0.5+0.4*Math.sin(r*6.283/11.3+0.7)+0.1*Math.sin(r*6.283/4.1); }
// the CRT's own life: a slow mains breath, the rolling band, a drifting interference line
function screenGain(r){ return 1+0.035*Math.sin(r*6.283/6.7)+0.02*Math.sin(r*6.283/2.3+1.3); }
function bandYAt(r){ return -999; }   // rolling band removed (Jon)                        // glass-local row
function bandPulse(r){ const z=(bandYAt(r)-(GH-30))/28; return Math.exp(-z*z); }
function interfY(r){ return -999; }   // interference line removed (Jon: "the horizontal white scan line looks bad")
// the scope's glow swells as the beam draws the spike
const SCP=1.45, SCVIS=1.2;
function scopePulse(r){ const ph=r%SCP; const z=(ph-0.55)/0.16; return Math.exp(-z*z); }
function crtIdleAmp(){ return 0.72*screenGain(R)*(1+0.16*bandPulse(R))*flick(R)*(LEAV?1:glLight(glitchAt(R))); }
// Nov 17 (Jon: "a bit slower... maybe with a title screen"): the warm-up beats run 1.5x longer (u = t - T.crt):
// dot to .255, line to .495, raster to 1.35, boot text to 3.45; the title card holds DESK.TITLE.hold, wipes
// into the game over DESK.TITLE.wipe, and the picture settles for half a second. Leaving is unchanged.
const CW={d0:.075, d1:.255, l1:.495, o1:1.35, b1:3.45}; CW.t1=CW.b1+DESK.TITLE.hold; CW.w1=CW.t1+DESK.TITLE.wipe; CW.s1=CW.w1+.5;
function crtAmp(t){
  const u=t-T.crt; if(u<0.05) return 0;
  if(LEAV){   // switching off: picture, squash to a line, line to a dot, dot fades
    if(u>=1.4) return crtIdleAmp();
    if(u>=0.7){ const s=(u-0.7)/0.7; return crtIdleAmp()*(0.25+0.75*s)*(1+0.5*(1-s)); }
    if(u>=0.4) return 0.12;
    return 0.05*(u-0.05)/0.35;
  }
  if(u<CW.d1) return 0.04; if(u<CW.l1) return 0.12;
  if(u<0.825) return 0.12+0.6*ease((u-CW.l1)/0.33);
  if(u<CW.o1) return 0.72-0.42*ease((u-0.825)/0.525);
  if(u<CW.b1) return 0.3;
  if(u<CW.t1) return 0.42;                       // the title card
  if(u<CW.s1) return 0.42+(crtIdleAmp()-0.42)*ease((u-CW.t1)/(CW.s1-CW.t1));
  return crtIdleAmp();
}
function scopeGlow(t){ return ease(seg(t,T.scope,T.scope+0.45)); }
function ledB(e,t){
  const u=t-e.on; if(u<0) return 0;
  let b = u<0.06?1.35 : u<0.14?0.85 : 1;     // pop
  switch(e.mode){
    case 'busy': { const k=Math.floor(R*7); if(hh(k*3+11)<0.22) b*=0.15; break; }
    case 'heart': b*= (R%1.6)<0.8?1:0.25; break;
    case 'breathe': b*=0.55+0.45*(0.5+0.5*Math.sin(R*6.283/3.1)); break;
    case 'lcd': b*=0.96+0.04*Math.sin(R*2.3); break;
    case 'eyes': { const P=5.2, k=Math.floor(R/P), at=k*P+1+hh(k+71)*3, v=R-at; if(v>=0&&v<0.13) b*=0.08; if(u<0.4) b*= (u<0.1?1: u<0.18?0.1: 1); break; }
  }
  return b;
}

// ---------- CRT ----------
function put(x,y,r,g,b){ const o=(y*W+x)*4; out[o]=soft(r); out[o+1]=soft(g); out[o+2]=soft(b); }
function sput(lx,ly,r,g,b){ if(lx<0||lx>=GW||ly<0||ly>=GH) return; const o=(ly*GW+lx)*3; scr[o]=r; scr[o+1]=g; scr[o+2]=b; }
function sfill(r,g,b){ for(let i=0;i<GW*GH;i++){ scr[i*3]=r; scr[i*3+1]=g; scr[i*3+2]=b; } }
function stxt(s,x0,y0,col,f){ for(let c=0;c<s.length;c++){ const g=FONT[s[c]]||FONT[' '];
  for(let r=0;r<5;r++) for(let q=0;q<3;q++) if(g[r*3+q]==='1') sput(x0+c*4+q,y0+r,col[0]*f,col[1]*f,col[2]*f); } }
const CX=75, CY=70;
function sdot(k){ sput(CX,CY,230*k,255*k,250*k); sput(CX-1,CY,230*k,255*k,250*k); sput(CX,CY-1,90*k,120*k,120*k); sput(CX-1,CY-1,90*k,120*k,120*k);
  sput(CX+1,CY,70*k,95*k,95*k); sput(CX-2,CY,70*k,95*k,95*k); sput(CX,CY+1,70*k,95*k,95*k); sput(CX-1,CY+1,70*k,95*k,95*k); }
function sline(w){ for(let x=CX-w;x<CX+w;x++){ sput(x,CY,215,245,245); sput(x,CY-1,60,85,90); sput(x,CY+1,60,85,90); } }
function picture(t,u,squash){
  // the culture frame with the tube's life on it; squash (1..0) collapses it to a line when switching off
  let offY=0, gain=1;
  if(!LEAV && u<CW.s1){ const k=eOut((u-CW.t1)/(CW.s1-CW.t1)); gain=0.65+0.35*k; }   // the wipe brings it in; it settles
  const gl=(!LEAV && u>CW.s1+0.3)?glitchAt(R):null;
  if(gl && gl.type==='vhold') offY += gl.v<0.09?2 : gl.v<0.17?-1 : 0;
  const by=bandYAt(R), iy=interfY(R), k0=gain*flick(R)*screenGain(R)*1.03;
  const rgb=gl && gl.type==='rgb';
  let j0=-1,j1=-1, sc=-99; const gf=gl?Math.floor(gl.v*15):0;
  if(gl && gl.type==='jit'){ j0=8+Math.floor(hh(gl.n*5+1)*118); j1=j0+3+Math.floor(hh(gl.n*5+2)*6); }
  if(gl && gl.type==='static'){ sc=Math.floor(4+hh(gl.n*7+3)*80 + gl.v/0.5*44); }
  const nf=Math.floor(R*20);
  let hgt=GH/2;
  if(squash!=null) hgt=Math.max(0.5,70*eOut(squash));
  for(let ly=0;ly<GH;ly++){
    let sy;
    if(squash!=null){ const d=ly-CY+0.5; if(Math.abs(d)>hgt){ for(let lx=0;lx<GW;lx++) sput(lx,ly,4,6,9); continue; } sy=Math.round(CY+d*70/hgt); }
    else { const per=GH+6; sy=(((ly-offY)%per)+per)%per; }
    const db=ly-by; let band = Math.abs(db)<=3?1.12 : Math.abs(db)<=7?1.06 : (db>7&&db<=11)?0.97 : 1;
    if(ly===iy) band*=1.08; else if(Math.abs(ly-iy)===1) band*=1.03;
    let sh=0; if(ly>=j0 && ly<j1 && hh(ly*13+gf*7+gl.n)>=0.25) sh=(hh(ly*3+gf*11+gl.n)<0.6?1:2)*(hh(ly+gf*5+gl.n*3)<0.5?-1:1);
    const stat=Math.abs(ly-sc)<=1;
    const boost=squash!=null?1+0.8*(1-squash):1;
    for(let lx=0;lx<GW;lx++){
      let r=4,g=7,b=10;
      if(sy<GH){ const sx=Math.min(GW-1,Math.max(0,lx-sh)); const o=(sy*GW+sx)*4; r=cult[o]; g=cult[o+1]; b=cult[o+2];
        if(rgb){ r=cult[(sy*GW+Math.max(0,sx-1))*4]; b=cult[(sy*GW+Math.min(GW-1,sx+1))*4+2]; } }
      let k=k0*band*boost; if(ly===iy && ((lx>>1)&1)) k*=1.03;
      r=r*k+2; g=g*k+4; b=b*k+6;
      if(stat){ const n=30+150*hh((lx*7+ly*131)^(nf*977)); r=r*0.45+n*0.5; g=g*0.45+n*0.55; b=b*0.45+n*0.6; }
      sput(lx,ly,r,g,b);
    }
  }
}
function drawCRT(t){
  const u=t-T.crt;
  if(LEAV){
    if(u<0.05) sfill(5,8,13);
    else if(u<0.4){ sfill(7,10,14); sdot(ease((u-0.05)/0.35)); }
    else if(u<0.7){ sfill(7,10,14); sline(Math.max(1,Math.round(75*ease((u-0.4)/0.3)))); }
    else if(u<1.4) picture(t,u,(u-0.7)/0.7);
    else picture(t,u,null);
  } else if(u<CW.d0){ sfill(u>=0?8:5, u>=0?11:8, u>=0?15:13); }
  else if(u<CW.d1){ sfill(7,10,14); sdot(ease((u-CW.d0)/(CW.d1-CW.d0))); }
  else if(u<CW.l1){ sfill(7,10,14); sline(Math.max(1,Math.round(75*eOut((u-CW.d1)/(CW.l1-CW.d1))))); }
  else if(u<CW.o1){
    const open=eOut((u-CW.l1)/0.33), h=Math.max(1,Math.round(70*open)), fade=u<0.825?1:1-ease((u-0.825)/0.525);
    const fr=Math.floor(t*12);
    for(let ly=0;ly<GH;ly++){ const dy=Math.abs(ly-CY);
      for(let lx=0;lx<GW;lx++){
        if(dy>h){ sput(lx,ly,7,10,14); continue; }
        const n=hh((lx*7+ly*131)^(fr*977)); const edge=dy>=h-1?1.3:1;
        const v=18+(68*fade+22*n*fade)*edge;
        sput(lx,ly,v*0.82+6,v*0.95+10,v+14);
      } }
  } else if(u<CW.b1){
    sfill(8,14,18);
    const ink=[150,232,180], ub=u-CW.o1;
    const l1='SCI-TERM 03', n1=Math.min(l1.length, Math.floor((ub-0.075)*10.7));
    if(n1>0) stxt(l1.slice(0,n1), 9, 9, ink, 1);
    if(ub>=1.275) stxt('READY', 9, 17, ink, 0.9);
    const cur=ub<1.275? [9+Math.max(0,n1)*4, 9] : [9+20, 17];
    if(Math.floor(ub*2.2)%2===0) for(let r=0;r<5;r++) for(let q=0;q<3;q++) sput(cur[0]+q,cur[1]+r,ink[0]*0.85,ink[1]*0.85,ink[2]*0.85);
  } else if(u<CW.t1){ DESK.titleCard(scr, u-CW.b1, 0); }
  else { picture(t,u,null); if(u<CW.w1) DESK.titleCard(scr, u-CW.b1, (u-CW.t1)/DESK.TITLE.wipe); }
  glassPost(t);
}
// phosphor glow, tube mask, reflection, then onto the frame; the bezel lip gets a little of the glow
function glassPost(t){
  for(let ly=0;ly<GH;ly++) for(let lx=0;lx<GW;lx++){
    const o=(ly*GW+lx)*3; let gr=0,gg=0,gb=0;
    const add=(q)=>{ const a=scr[q]-80, b2=scr[q+1]-80, c=scr[q+2]-80; if(a>0) gr+=a; if(b2>0) gg+=b2; if(c>0) gb+=c; };
    if(lx>0) add(o-3); if(lx<GW-1) add(o+3); if(ly>0) add(o-GW*3); if(ly<GH-1) add(o+GW*3);
    glowB[o]=scr[o]+0.09*gr; glowB[o+1]=scr[o+1]+0.09*gg; glowB[o+2]=scr[o+2]+0.09*gb;
  }
  const sAvg=(window.__nook.strAvg||0);
  for(let ly=0;ly<GH;ly++) for(let lx=0;lx<GW;lx++){
    const i=ly*GW+lx, o=i*3, m=gMask[i];
    put(GX+lx,GY+ly, glowB[o]*m, glowB[o+1]*m, glowB[o+2]*m);
  }
  for(const [i,w,dot] of []){   // the string lights' reflection arc on the glass is gone (Nov 17) const ly=(i/GW)|0, lx=i%GW, o=((GY+ly)*W+GX+lx)*4, k=w*sAvg;
    if(dot){ out[o]=soft(out[o]+60*k); out[o+1]=soft(out[o+1]+44*k); out[o+2]=soft(out[o+2]+22*k); }
    else { out[o]=soft(out[o]+34*k); out[o+1]=soft(out[o+1]+32*k); out[o+2]=soft(out[o+2]+30*k); } }
  // phosphor spilling onto the inner lip
  const lip=(ring,lx0,ly0,dx,dy)=>{ for(let j=0;j<ring.length;j++){ const lx=Math.min(GW-1,Math.max(0,lx0+dx*j)), ly=Math.min(GH-1,Math.max(0,ly0+dy*j)), q=(ly*GW+lx)*3, o=ring[j]*4;
    out[o]=soft(out[o]+0.07*glowB[q]); out[o+1]=soft(out[o+1]+0.07*glowB[q+1]); out[o+2]=soft(out[o+2]+0.07*glowB[q+2]); } };
  lip(RING.bot,-1,GH-2,1,0); lip(RING.left,1,0,0,1);
}
// the bezel's inner lip as a bevel: top edge dark, lower edge catches the string lights
function bevel(strAvg,ca){
  const mul=(l,f,ar,ag,ab)=>{ for(const i of l){ const o=i*4; out[o]=soft(out[o]*f+(ar||0)); out[o+1]=soft(out[o+1]*f+(ag||0)); out[o+2]=soft(out[o+2]*f+(ab||0)); } };
  mul(RING.top,0.5); mul(RING.top2,0.78); mul(RING.right,0.58); mul(RING.right2,0.84);
  mul(RING.bot,1.3,22*strAvg+5*ca,16*strAvg+8*ca,8*strAvg+10*ca); mul(RING.bot2,1.1); mul(RING.left,1.15,6*strAvg,4*strAvg,2*strAvg);
}

// ---------- oscilloscope ----------
const WAVE=[0,0,0,-1,0,0,1,-5,4,1,0,0,-1,-2,-1,0,0];
function scopeY(cx,k){ const a=0.75+0.45*hh(k*17+3); const base=103; return base+Math.round(WAVE[cx]*a); }
function drawScope(t){
  const g=scopeGlow(t), w=SC.x1-SC.x0+1;
  for(let y=SC.y0;y<=SC.y1;y++) for(let x=SC.x0;x<=SC.x1;x++){
    let r=12,gg=19,b=19;
    if(g>0){ r=r*(1-g)+9*g; gg=gg*(1-g)+34*g; b=b*(1-g)+24*g;
      const rx=x-SC.x0, ry=y-SC.y0;
      if(rx%4===0 && ry%4===3){ r+=10*g; gg+=26*g; b+=15*g; }
      else if(y===103 && rx%2===0){ r+=5*g; gg+=14*g; b+=8*g; } }
    if(y===SC.y0){ r*=0.7; gg*=0.7; b*=0.7; }
    put(x,y,r,gg,b);
  }
  const vis=seg(t,T.scope+0.4,T.scope+0.75); if(vis<=0) return;
  // the sweep runs on real time: it never runs backwards
  const s=R/SCP, k=Math.floor(s), ph=(s-k)*SCP;
  const levels=[[0.06,[215,255,205]],[0.3,[120,232,112]],[0.7,[72,176,78]],[1.15,[52,124,58]],[99,[40,96,48]]];
  const bg=[9,34,24];
  let prevY=null;
  for(let cx=0;cx<w;cx++){
    const hit=cx/w*SCVIS; let kk=k, at=k*SCP+hit; if(hit>ph){ kk=k-1; at=(k-1)*SCP+hit; }
    const age=R-at; let col=null; for(const [a,c] of levels) if(age<a){ col=c; break; }
    const y=scopeY(cx,kk), x=SC.x0+cx;
    const lo=prevY==null?y:Math.min(y,prevY), hi=prevY==null?y:Math.max(y,prevY);
    for(let yy=lo; yy<=hi; yy++){ const f=((yy===y)?1:0.8)*vis; put(x,yy,bg[0]+(col[0]-bg[0])*f,bg[1]+(col[1]-bg[1])*f,bg[2]+(col[2]-bg[2])*f); }
    prevY=y;
  }
}

// ---------- frame ----------
function frame(g,t,info){
  if(DESK.act1(g,t,local)) return;
  if(!ok) return;
  R = info && info.real!=null ? info.real : t;
  LEAV = !!(info && info.leaving);
  const fade=ease(seg(t,T.fade,T.fade+0.55));
  // light weights: steady shapes, multiplied after stepping
  const sb=strBulbs.map((s,k)=>strB(s,k,t));
  const segA=[0,0,0,0], segN=[0,0,0,0]; strBulbs.forEach((s,k)=>{ segA[s.seg]+=Math.min(1.5,sb[k]); segN[s.seg]++; });
  let bb=bulbB(t), bw=bulbWarm(t);
  const ca=crtAmp(t), sg=scopeGlow(t);
  // Leaving (Nov 19): the rack bulb holds its full living light until the timeline reaches T.bulb (its click), then
  // goes out like a switched filament (afterglow below); a leave that starts while it warms holds the level it had
  const ub0=t-T.bulb, bulbSteady=ub0<0?0 : ub0<0.12?0.22 : ub0<0.18?0.05 : ub0<0.25?0.55 : ub0<0.3?0.18 : 0.32+0.68*ease((ub0-0.3)/0.75);
  if(!LEAV){ LV_HOLD=bulbSteady; LV_K=bw; }
  const lvG = LEAV ? (t>=T.bulb ? 1 : afterglow(T.bulb-t))*LV_HOLD : -1;
  if(lvG>=0){ if(t>=T.bulb){ bb=bulbB(Math.max(t,T.bulb+2))*LV_HOLD; bw=Math.min(bulbWarm(Math.max(t,T.bulb+2)),LV_K); } else { bb=lvG; bw=.35*lvG; } }
  const amp={bulb:bb*1.05, str0:segA[0]/Math.max(1,segN[0]), str1:segA[1]/Math.max(1,segN[1]), str2:segA[2]/Math.max(1,segN[2]), str3:segA[3]/Math.max(1,segN[3]),
    crt:ca, scope:sg*(0.6+0.3*scopePulse(R)), port:1};
  const dr=bulbDrift(R)*bw, br=brown(R);
  // the screen's light: a soft green-teal leaning toward what is on the glass (sampled, smoothed, desaturated)
  { const u=t-T.crt, pic=(!LEAV && u>=CW.t1) || (LEAV && u>=0.7) ? 1 : 0, boot=!LEAV && u>=CW.o1 && u<CW.t1;
    let mc=boot?[.45,1,.7]:[.55,1,.89]; const sm=(SCH[0]+SCH[1]+SCH[2])/3, sd=SCH.map(v=>sm+(v-sm)*.5);
    crtF.col=mc.map((v,k)=>v+(sd[k]-v)*.35*pic); }
  const bulbCol=[1, 0.5+0.26*bw+0.08*(1-dr)-0.12*br, 0.22+0.26*bw+0.14*(1-dr)-0.15*br];
  // ---- C lighting (Nov 18): steady weights composed and stepped once (cached), flicker multiplied after ----
  const FX=window.ROOMFX;
  const on=(amp.str0+amp.str1+amp.str2+amp.str3)/4;
  window.__nook.strAvg=Math.min(1.3,on);
  const ub=t-T.bulb;
  const bS= lvG>=0 ? lvG : bulbSteady;
  const flB= (lvG>=0 ? t>=T.bulb && LV_HOLD>=1 : ub>1.2) ? FX.tiredBulb(R, 11, {depth:1.2})*(1-brown(R)) : 1;      // a tired bulb, and the rare brown-out
  const bulbQ=Math.round(bS*24)/24, bwQ=Math.round(bw*12)/12;
  const son=sb.map(v=>v>0?1:0), lv=ledList.map(e=>ledB(e,t)), lon=lv.map(v=>v>0?1:0);
  const caOn=ca>0?1:0, scQ=Math.round(sg*12)/12;
  const key=[bulbQ,bwQ,caOn,scQ,son.join(''),lon.join('')].join('|');
  const bulbColS=[1, 0.5+0.26*bwQ+0.04, 0.22+0.26*bwQ+0.07];
  if(!CCN.S || CCN.key!==key){
    const tl=bulbColS.map(v=>1+(v-1)*.7), tm=[.55,1,.89].map(v=>1+(v-1)*.5);
    CCN.S=LIT.compose({ A: A2, amb: [.17,.18,.23], fa: Fa, fade: 1, ov: .3, hot: 6, hotCol: bulbColS,
      big: [ { F: FLD.bulb, w: bulbQ*1.3, tint: tl, ch: 0 }, { F: FLD.scr, w: caOn*1.05, tint: tm, ch: 1 },
             { F: FLD.scope, w: scQ*.8, tint: [.6,1,.7], ch: 2 }, { F: FLD.port, w: .6, tint: [.8,.88,1], ch: 2 } ],
      small: SMALL.map((q,n)=>({ f: q.f, box: q.box, tint: q.tint, w: n<NS ? son[n]*1.3 : lon[n-NS]*1.1 })) });
    CCN.key=key;
  }
  const sFl=SMALL.map((q,n)=> n<NS ? (son[n] ? Math.min(sb[n],1.35)*FX.tiredBulb(R, 60+n*7, { depth:.9, every: 5+(n%4), stutterEvery: 23+n }) : 1)
    : (lon[n-NS] ? lv[n-NS] : 1));
  LIT.frame(CCN.S, out, { lamp: flB, scr: ca/0.72, small: sFl }, Lc);
  for(let i=0;i<N;i++){ Lr[i]=Lc[i*3]; Lg[i]=Lc[i*3+1]; Lb[i]=Lc[i*3+2]; }
  const ar=0, ag=0, ab=0, GN=1;
  bevel(Math.min(1.3,on), Math.min(1.2,ca/0.72));
  // dust in the air ("more dust overall"), lit by the light where each mote is
  FX.drawDust(DUSTC, out, R, i=>[Lc[i*3],Lc[i*3+1],Lc[i*3+2]], 72, .03, 1);
  // --- emitters ---
  const dim=(i,f)=>{ const a=i*3; put(i%W,(i/W)|0, art[a]*f*0.9, art[a+1]*f*0.95, art[a+2]*f*1.1); };
  // porthole: a living window (parallax stars, twinkle, rare passers-by), outside light from the start
  FX.drawSky(SKY, (i,r0,g0,b0)=>put(i%W,(i/W)|0,r0,g0,b0), R, 1);
  // rack bulb: filament orange at first, then warm white; off it is dull glass
  for(const i of em.bulb){ const a=i*3, x=i%W, y=(i/W)|0;
    const offc=[art[a]*0.1,art[a+1]*0.1,art[a+2]*0.12];
    const lip=(y===RIM_Y);                    // the shade's inside lip, lit by the bulb
    const dc=Math.abs(x-BX);                  // the sliver: hottest in the middle
    const k=bb*(lip?(dc<7?0.92:0.8) : dc<3?1.3 : dc<6?1.1 : 0.95);
    const fil=!lip && dc<3;
    const hr=255*k*1.15, hg=(140+85*bw+15*(bw-dr)-40*br)*k*(fil?1.12:1.0), hb=(50+110*bw+30*(bw-dr)-50*br)*k*(fil?1.05:0.92);
    put(x,y, Math.max(offc[0],hr), Math.max(offc[1],hg), Math.max(offc[2],hb)); }
  // string bulbs
  strBulbs.forEach((s,k)=>{ const b=sb[k], w=strWarm(s,t);
    for(const i of s.px){ const a=i*3; const rim=art[a+2]<170;
      const cr=255*b*(rim?1.0:1.15), cg=(150+75*w)*b*(rim?0.85:1.08), cb=(60+110*w)*b*(rim?0.6:1);
      put(i%W,(i/W)|0, Math.max(art[a]*0.15,cr), Math.max(art[a+1]*0.15,cg), Math.max(art[a+2]*0.17,cb)); } });
  // LEDs
  for(const e of ledList){ const b=ledB(e,t);
    for(const i of e.px){ const a=i*3; const f=Math.max(0.14, b);
      put(i%W,(i/W)|0, art[a]*(b>0?e.col[0]*f:0.14), art[a+1]*(b>0?e.col[1]*f:0.15), art[a+2]*(b>0?e.col[2]*f:0.18)); } }
  // rack readout: a level meter, held a third of a second at a time
  { const u=t-(T.rack+0.35);
    for(let j=0;j<em.readout.length;j++){ const i=em.readout[j], x=i%W; const segOn=((x-305)%3)!==2;
      let lit=false;
      if(u>=0 && segOn){ const fill=Math.min(1,u/0.5); const k=Math.floor(R*3);
        const lvl=Math.round((0.45+0.25*hh(k*7+1)+0.1*Math.sin(R*0.7))*25);
        lit=(x-305)<Math.min(lvl, Math.floor(fill*25)); }
      if(lit) put(x,16, 110,215,150); else if(segOn) put(x,16, 16,30,26); else put(x,16, 12,16,20); } }
  drawScope(t);
  drawCRT(t);
  if((schN++%3)===0){ let r=0,g2=0,b=0; for(let ly=4;ly<GH-4;ly+=7) for(let lx=4;lx<GW-4;lx+=7){ const o=(ly*GW+lx)*3; r+=scr[o]; g2+=scr[o+1]; b+=scr[o+2]; }
    const m=Math.max(r,g2,b); if(m>1e3){ SCH=[SCH[0]+(r/m-SCH[0])*.3, SCH[1]+(g2/m-SCH[1])*.3, SCH[2]+(b/m-SCH[2])*.3]; } }
  // steam off the mug (Nov 17, Jon: "some of the coffee cups have no steam"): it rises off the opening under
  // the chin and leans left, past the glass's edge, lit by the room's light where it is
  { const sl=l=>l/(1+0.35*l)*1.35;
    // the screen right above lights it: its teal on the side under the glass, less on the far side
    const kc=crtF.col, w=46*Math.min(1.2,ca/0.72)*fade, cool=[w*kc[0],w*kc[1],w*kc[2]], half=cool.map(v=>v*.6);
    drawSteam(R, i=>[Lr[i], Lg[i], Lb[i]], (x,cx)=>x>=cx?cool:half); }
  // debug: selections in magenta
  if(window.__nook.debug){ const m=l=>{ for(const i of l){ const o=i*4; out[o]=255; out[o+1]=0; out[o+2]=255; } };
    m(em.bulb); m(em.port); strBulbs.forEach(s=>m(s.px)); ledList.forEach(e=>m(e.px)); m(em.portStars); }
  if(fade<1) for(let i=0;i<N*4;i+=4){ out[i]*=fade; out[i+1]*=fade; out[i+2]*=fade; }
  offg.putImageData(img,0,0);
  g.imageSmoothingEnabled=false;
  g.drawImage(off,0,0,W*S,H*S);
  // the tube's raster: a thin dark line between art rows on the CRT (lighter on the scope)
  if(t-T.crt>=0.05){ g.fillStyle='rgba(0,0,0,0.42)'; for(let ly=0;ly<GH;ly++) g.fillRect(GX*S,(GY+ly)*S+S-1,GW*S,1); }
  if(scopeGlow(t)>0){ g.fillStyle='rgba(0,0,0,0.22)'; for(let y=SC.y0+1;y<=SC.y1;y++) g.fillRect(SC.x0*S,y*S+S-1,(SC.x1-SC.x0+1)*S,1); }
}

DESK.register({ id:'nook_1', name:'NOOK', line:'Scope, rack and strings wake up.', doneAt:12.3, init, frame, times:{ lamp:T.bulb, crt:T.crt } });   // Nov 19: the lamp click goes with the rack bulb it switches, both ways
})();
