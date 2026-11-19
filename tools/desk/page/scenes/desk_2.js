// DESK 2: the sparser bridge desk. A shaded lamp on an arm throws a warm pool down-left
// onto the desk, two strings of lights come on along their wires, then the old CRT warms up.
// All light is computed at art resolution (384x216) and scaled 5x.
// Every light keeps [steady, breathing]: fields are stepped once at init (bands never move);
// power-on, twinkle and breathing only multiply brightness after the stepping.
(function(){
  const W = 384, H = 216, N = W*H;
  const GX = 117, GY = 22, GW = 150, GH = 140;          // CRT glass
  // Round 4: the bulb sits up inside a cone shade; only a sliver (ebbb77) and the shade's warm inside lip
  // (daa559) show. Light leaves the mouth, so the fields start at the sliver.
  const BULB = {x:332, y:133};                          // the visible sliver's centre
  const LAMP_BOX = [322, 120, 345, 140];                // sliver + inside lip, nothing else warm in here
  const AXIS = (()=>{ const l = Math.hypot(-0.45,1); return {x:-0.45/l, y:1/l}; })();
  const SHADE = (()=>{ const l = Math.hypot(0.62,-0.78); return {x:0.62/l, y:-0.78/l}; })();
  const PORT = {x:325, y:37, r:13.6};
  // Lighting pass (Nov 17, desk_1 v7's approved model, no normal map): the bulb sits inside the cone
  // shade a few px off the wall; the light leaves the mouth along AXIS in a cone of half-angle LAMP_CONE.
  const LZ = 9, LAMP_CONE = 34*Math.PI/180;
  const KEYB_P = [[141,189],[244,189],[249,209],[137,209]];          // the keyboard, by hand off the art
  const MUG_BOX = [261, 184, 285, 208];                             // the mug: its pixels are flood-filled inside this box
  const ROBOT_BOX = [348, 166, 368, 189];                           // the little figure by the lamp
  const BASES = [[263,281,208,1], [78,96,189,2], [351,364,189,1]];  // feet: mug, plant tin, figure (row found in the art)
  // Timeline (seconds since replay)
  const T = { room:2.5, roomIn:0.6, lamp:3.45, str:4.7, crt:5.6, iron:7.2 };
  const DEBUG = /dbg2/.test(location.hash);

  const BAYER = [0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5].map(v=>(v+0.5)/16);
  const bay = (x,y)=>BAYER[(y&3)*4+(x&3)];
  const rnd = n => { const s = Math.sin(n*127.1+311.7)*43758.5453; return s-Math.floor(s); };
  const clamp = (v,a,b)=>v<a?a:v>b?b:v;
  const sstep = (a,b,v)=>{ const k = clamp((v-a)/(b-a),0,1); return k*k*(3-2*k); };
  const easeOut = k => 1-Math.pow(1-clamp(k,0,1),3);

  // Stepped light: L levels, each band a plateau with a dithered edge `e` wide.
  function quant(F, L, e, x, y){
    if(F<=0) return 0;
    const v = Math.min(F,1)*L, b = Math.floor(v), f = v-b;
    const up = f > 1-e && (f-(1-e))/e > bay(x,y) ? 1 : 0;
    return Math.min(L, b+up)/L;
  }

  let local, cv, cx, out, base;
  let glassM, portM, portPts = [], lampBulb = [], lampHot = [], strBulbs = [], stars = [];
  let cultMean = 0.3, Slamp, Scrt, Srim, Gr, Gg, Gb, culture;
  let Ar, Ag, Ab, Fa, Sport, KSPEC, coneI, coneV, Fc, scrCol = [0.5, 0.95, 0.9];
  // String light centres (round 4 seeds, flood-checked against the art), each strand ordered from its
  // plug end outward. Strand index = side: it sets the switch-on stagger and the swell's clock.
  const LEFT  = [[123,2],[98,22],[89,28],[77,34],[64,40],[54,43],[44,47],[32,48],[15,50],[4,49]];
  const RIGHT = [[288,64],[294,72],[302,78],[315,84],[327,86],[340,84],[350,80],[361,76],[370,69],[378,62],[383,53],[376,108],[368,111]];
  const LOW   = [[85,73],[74,76],[61,75],[38,74],[25,76],[14,70]];     // the second left strand, over the photo
  const TOP   = [[149,3],[186,2],[221,3],[258,2]];                      // swags along the top of the wall
  const STR_ON = [0, 0.32, 0.16, 0.5], STR_P = [11.3, 13.7, 12.4, 15.1], STR_T0 = [0, 5.5, 2.7, 8.1];

  // ---------- tiny 3x5 font for the boot lines ----------
  const FONT = {
    A:'010101111101101',B:'110101110101110',C:'011100100100011',D:'110101101101110',E:'111100110100111',
    F:'111100110100100',G:'011100101101011',H:'101101111101101',I:'111010010010111',K:'101101110101101',
    L:'100100100100111',M:'101111111101101',N:'110101101101101',O:'010101101101010',P:'110101110100100',
    R:'110101110101101',S:'011100010001110',T:'111010010010010',U:'101101101101111',Y:'101101010010010',
    '0':'111101101101111','3':'110001010001110','4':'101101111001001','6':'011100110101010',
    '-':'000000111000000','>':'100010001010100','.':'000000000000010',' ':'000000000000000'
  };
  const BOOT = ['SCI-TERM 03','MEM 64K OK','PROBE LINK OK','> CULTURE'];

  async function init(){
    const [art, loc, cul] = await Promise.all([DESK.img('assets/desk_2.png'), DESK.img('assets/local.png'), DESK.img('assets/screen_culture.png')]);
    local = loc;
    cv = document.createElement('canvas'); cv.width = W; cv.height = H;
    cx = cv.getContext('2d', {willReadFrequently:true});
    cx.drawImage(art,0,0);
    base = new Uint8ClampedArray(cx.getImageData(0,0,W,H).data);
    out = cx.createImageData(W,H);
    drawKeyboardC();
    const c2 = document.createElement('canvas'); c2.width = GW; c2.height = GH;
    const g2 = c2.getContext('2d'); g2.drawImage(cul,0,0);
    culture = g2.getImageData(0,0,GW,GH).data;
    { let sm=0,n=0; for(let y=1;y<GH;y+=3) for(let x=1;x<GW;x+=3){ const i=(y*GW+x)*4; sm += 0.3*culture[i]+0.59*culture[i+1]+0.11*culture[i+2]; n++; } cultMean = sm/n/255; }

    // (the painted steam stub is gone from the art itself, round 4)
    findEmitters();
    buildFields();
    Gr = new Float32Array(N); Gg = new Float32Array(N); Gb = new Float32Array(N);
    Ar = new Float32Array(N); Ag = new Float32Array(N); Ab = new Float32Array(N);
    buildPass();
    buildC();
  }
  // ---------- the keyboard, drawn in code (Nov 18, Jon: "the keyboards still look really bad... flat and
  // dimensionless"): rows of keycaps with lit tops, dark front lips and gaps, a case with a rim, bevels and a
  // front face, a contact shadow; see ROOMFX.drawKeyboard. Painted into the art, so everything reads it. ----------
  let KBd = null, AF = null;
  function drawKeyboardC(){
    const FX = window.ROOMFX;
    AF = new Float32Array(N*3); for(let j=0;j<N;j++){ AF[j*3]=base[j*4]; AF[j*3+1]=base[j*4+1]; AF[j*3+2]=base[j*4+2]; }
    const fp = FX.findKeyboard(AF, W, H, KEYB_P, [192, 199], 22);
    const deskAt = (x, y) => { for(let r=1;r<12;r++) for(const xx of [x-r, x+r]){ const j = y*W+xx; if(xx>=0 && xx<W && !fp.m[j]) return [AF[j*3],AF[j*3+1],AF[j*3+2]]; } return [42,47,54]; };
    KBd = FX.drawKeyboard(AF, W, H, fp, { pal: FX.kbPalette([170,166,154]), lay: FX.KB_FULL, seed: 2, desk: deskAt,
      rim: 1, bezel: 0, rows: [[1,1,0],[2,1,0],[2,1,0],[2,1,0],[2,1,0],[2,1,0]], fbezel: 1, face: 1, side: 2 });
    for(let j=0;j<N;j++){ base[j*4]=AF[j*3]; base[j*4+1]=AF[j*3+1]; base[j*4+2]=AF[j*3+2]; }
  }
  // ---------- C LIGHTING (Jon's pick, Nov 18; desk 1's, on the shared engine ROOMFX.makeLit) ----------
  // Every light falls off by distance and angle from its source in the room's own space; props are flood-filled;
  // the summed light is stepped once by the C ramp (six levels, a dithered seam, cool-violet shadows, warm
  // light). The old fields here were cut by straight rows (the lamp's wall/desk switch at row 187, the screen's
  // spill starting at row 184) and boxes (the string halos). Each light keeps [steady, flicker].
  let LIT = null, CC2 = {}, FLD = {}, SMALL = [], DUSTC = null, SKY = null, Lc = null, A2 = null;
  function buildC(){
    const FX = window.ROOMFX, D2R = Math.PI/180;
    for(let j=0;j<N;j++){ AF[j*3]=base[j*4]; AF[j*3+1]=base[j*4+1]; AF[j*3+2]=base[j*4+2]; }
    const L = j => 0.3*AF[j*3]+0.59*AF[j*3+1]+0.11*AF[j*3+2];
    const MON = FX.propMask(AF, W, H, [104, 6, 279, 190], [110, 100], j => { const x = j%W, y = (j/W)|0;
      return !glassM[j] && L(j) >= 50 && (y <= 176 || (x >= 178 && x <= 208)); }, 26);
    const MUGm = FX.propMask(AF, W, H, MUG_BOX, [270,200], j => AF[j*3] >= AF[j*3+2]-5 && L(j) >= 36, 20);
    const ROB = FX.propMask(AF, W, H, [344, 164, 370, 188], [352,172], j => L(j) >= 45 && !isWall(j%W,(j/W)|0), 20);
    const TIN = FX.propMask(AF, W, H, [66, 140, 104, 190], [88,182], j => L(j) >= 36 && !isWall(j%W,(j/W)|0), 20);
    const skip = new Uint8Array(N); for(let j=0;j<N;j++) if(glassM[j]||portM[j]) skip[j] = 1;
    LIT = FX.makeLit({ W, H, A: AF, skip, deskY: 186, deskF: 210, kz: 5, kb: KBd,
      props: [ { m: MON, foot: 188, deep: 9, up: .15, contact: false, bounce: .25, wrap: 0, gain: .6 },   // 0 the monitor
               { m: MUGm, foot: 208, heavy: true, cyl: true, up: .2, bounce: 1 },     // 1 the mug
               { m: ROB, foot: 186 },                                                // 2 the figure
               { m: TIN, foot: 189, cyl: true } ] });                                // 3 the plant tin
    const ax = [-0.4, -0.9, 0.2], al = Math.hypot(...ax);
    FLD.lamp = LIT.norm(LIT.point({ x: 333, y: 130, z: 14, I: 1, r0: 34, rMax: 300, axis: ax.map(v=>v/al),
      cosIn: Math.cos(30*D2R), cosOut: Math.cos(52*D2R), spill: 0, wrap: .15, occ: [0,1,2,3], spread: 8, samples: 5 }), 300, 198, 1);
    FLD.scr = LIT.norm(LIT.panel({ rect: [118,23,265,160], z: 8, I: 1, r0: 200, rMax: 380, nx: 6, ny: 4, wrap: .1, occ: [1,2,3] }), 128, 206, 1.1);
    FLD.port = LIT.norm(LIT.panel({ rect: [312,24,338,50], z: 3, I: 1, r0: 30, rMax: 150, nx: 4, ny: 4, wrap: .6, disc: true }), 325, 56, .2);
    SMALL = strBulbs.map(b => { const q = LIT.pointBox({ x: b.cx+.5, y: b.cy+.5, z: 5, I: 1, r0: 5, rMax: 24, wrap: .8, squash: b.side === 3 ? 1 : .62, bounce: false });
      let mx = 0; for(const v of q.f) mx = Math.max(mx, v); if(mx > 0) for(let k=0;k<q.f.length;k++) q.f[k] *= .7/mx; return q; });
    A2 = FX.settleDust(AF, W, H, { seed: 4, density: .045, amount: .2,
      mask: (x, y) => { const j = y*W+x; return y >= 188 && y <= 210 && !KBd.part[j] && L(j) > 30 && L(j) < 205; } });
    DUSTC = FX.makeDust({ W, H, count: 130, seed: 6, box: [2, 4, 380, 212],
      density: (x, y) => { const j = y*W+x; return .1 + .9*clamp(FLD.lamp[j]*.9 + FLD.scr[j]*1.1, 0, 1); }, skip: j => glassM[j] === 1 });
    (window.__C = window.__C || {}).desk_2 = { LIT, FLD, KB: KBd };
    SKY = FX.makeSky({ W, idx: portPts, cx: PORT.x+.5, cy: PORT.y+.5, r: 13, seed: 2 });
    Lc = new Float32Array(N*3);
  }
  const vnoise = (t, sd)=>{ const i = Math.floor(t), f = t-i, k = f*f*(3-2*f); return (rnd(i*1.91+sd)*(1-k) + rnd((i+1)*1.91+sd)*k)*2 - 1; };
  function bandStep(d, bands, E, b){ let v = 0; for(const [r, a] of bands){ const f = (r-d)/E + 0.5; if(f >= 1 || (f > 0 && f > b)) v += a; } return v; }
  function poly(pts){
    const m = new Uint8Array(N); let x0=W,y0=H,x1=0,y1=0;
    for(const [x,y] of pts){ x0=Math.min(x0,x); x1=Math.max(x1,x); y0=Math.min(y0,y); y1=Math.max(y1,y); }
    for(let y=y0;y<=y1;y++) for(let x=x0;x<=x1;x++){ let ins=false;
      for(let a=0,b=pts.length-1;a<pts.length;b=a++){ const [xa,ya]=pts[a],[xb,yb]=pts[b];
        if((ya>y+.5)!==(yb>y+.5) && x+.5 < (xb-xa)*(y+.5-ya)/(yb-ya)+xa) ins=!ins; }
      if(ins) m[y*W+x]=1; }
    return m;
  }
  // A prop's own pixels, never the desk or wall that share its box: its body flood-filled from a seed inside
  // it, then the dark outline (lum3 <= lineMax) touching the body, and the dark shading the body encloses
  // (the inside of the rim). Holes that show the desk (the handle) stay desk.
  function propMask(box, seed, body, lum3, lineMax){
    const [x0,y0,x1,y1] = box, m = new Uint8Array(N), inb = (x,y)=>x>=x0&&x<=x1&&y>=y0&&y<=y1, st = [seed];
    while(st.length){ const [x,y] = st.pop(); if(!inb(x,y)) continue; const i = y*W+x; if(m[i] || !body(i)) continue; m[i] = 1; st.push([x+1,y],[x-1,y],[x,y+1],[x,y-1]); }
    for(let y=y0;y<=y1;y++) for(let x=x0;x<=x1;x++){ const i = y*W+x; if(m[i] || lum3(i) > lineMax) continue;
      for(let dy=-1;dy<=1&&!m[i];dy++) for(let dx=-1;dx<=1;dx++) if(inb(x+dx,y+dy) && m[(y+dy)*W+x+dx]===1){ m[i] = 2; break; } }
    const outside = new Uint8Array(N), q = [];
    for(let x=x0;x<=x1;x++) q.push([x,y0],[x,y1]); for(let y=y0;y<=y1;y++) q.push([x0,y],[x1,y]);
    while(q.length){ const [x,y] = q.pop(); if(!inb(x,y)) continue; const i = y*W+x; if(outside[i] || m[i]) continue; outside[i] = 1; q.push([x+1,y],[x-1,y],[x,y+1],[x,y-1]); }
    for(let y=y0;y<=y1;y++) for(let x=x0;x<=x1;x++){ const i = y*W+x; if(!m[i] && !outside[i] && lum3(i) <= 30) m[i] = 1; }
    for(let i=0;i<N;i++) if(m[i]) m[i] = 1;
    return m;
  }
  // ---------- the lighting pass: everything static, folded into the fields once ----------
  function buildPass(){
    const L = new Float32Array(N); for(let j=0;j<N;j++) L[j] = lum(j*4);
    // Nov 17 (Jon: "some of the lighting is weird... boxy background"): the mug and the figure are their own
    // pixels, found by flood fill from inside them, not every pixel of a colour in a box (the box took in
    // the dark desk and wall round the mug, which then lit and cast shadow as one rectangle; the figure's
    // box cut the pipe behind it at the box's top edge)
    const avg3 = j => (base[j*4]+base[j*4+1]+base[j*4+2])/3;
    const KEYB = poly(KEYB_P);
    const MUG = propMask(MUG_BOX, [270,200], j => base[j*4] >= base[j*4+2]-5 && avg3(j) >= 36, avg3, 20);
    const ROB = propMask([346, ROBOT_BOX[1], ROBOT_BOX[2], 184], [352,172], j => L[j] >= 45 && !isWall(j%W,(j/W)|0), avg3, -1);
    // the feet: the two rows under the legs, where they stand on the desk's back edge (same grey as the edge)
    for(let y=185;y<=186;y++) for(let x=346;x<=ROBOT_BOX[2];x++){ const j=y*W+x; if(ROB[j-W] && L[j] >= 45 && !isWall(x,y)) ROB[j] = 1; }
    // the mug's cast shadow from the lamp: one soft shape (nine samples across the bulb, three dithered steps)
    for(let y=188;y<H;y++) for(let x=200;x<300;x++){
      const j=y*W+x; if(MUG[j] || !Slamp[j]) continue;
      let vis = 0;
      for(let k=0;k<9;k++){ const sx = 326 + k*1.5, dx = sx-x, dy = 131-y, d = Math.hypot(dx,dy), ux=dx/d, uy=dy/d;
        let hit = false; for(let q=1;q<=30;q++){ const px2=Math.round(x+ux*q), py2=Math.round(y+uy*q); if(MUG[py2*W+px2]){ hit=true; break; } }
        if(!hit) vis++; }
      if(vis < 9){ const qv = Math.floor(vis/9*3 + bay(x,y)*0.999)/3; Slamp[j] *= 0.3 + 0.7*qv; }
    }
    // contact shadows: one row (two, dithered, under heavier things) where the art's outline meets the desk
    const ao = new Float32Array(N).fill(1);
    for(const [x0,x1,yh,rows] of BASES) for(let x=x0;x<=x1;x++) for(let y=yh-5;y<=yh+4&&y<H-1;y++){
      const j=y*W+x; if(L[j-W] < 48 && L[j] >= 55 && !MUG[j]){ ao[j]=Math.min(ao[j],0.74); if(rows>1 && bay(x,y+1)<0.5) ao[j+W]=Math.min(ao[j+W],0.88); break; }
    }
    // the room falls to blue-black toward its edges and top; deepest under the desk's lip
    Fa = new Float32Array(N);
    for(let y=0;y<H;y++) for(let x=0;x<W;x++){ const j=y*W+x;
      const q = ((x-205)/235)**2 + ((y-180)/145)**2 + (bay(x,y)-0.5)*0.1;
      let a = q < 0.5 ? 1 : q < 0.8 ? 0.74 : q < 1.15 ? 0.54 : 0.4;
      if(y >= 211) a *= y >= 213 ? 0.45 : 0.65;
      // the top-left wall under the two strands is lived-in, not a void: lift it a step (dithered edge)
      if(x < 128 && y < 100){ const q2 = ((x-50)/85)**2 + ((y-50)/55)**2 + (bay(x,y)-0.5)*0.12; if(q2 < 1) a = Math.max(a, q2 < 0.55 ? 0.74 : 0.6); }
      Fa[j] = a*ao[j];
      Slamp[j] *= ao[j]; Scrt[j] *= ao[j];
    }
    // things standing on the desk read the light at their own feet (no band edge across them), weighted by
    // the art's own value, so lit key tops lift and fronts and gaps stay dark; the mug is a cylinder,
    // lit from the screen on its left and from the lamp on its right
    const tone = j => 0.4 + 0.8*clamp((L[j]-55)/110, 0, 1);
    // the keys read the lamp at their foot as the mean along the keyboard's front edge (Nov 17: one sample at x 243
    // read the old box-shaped mug shadow, which kept the keys dark; with the mug's real shadow that one point
    // sits in the pool and lit the whole keyboard warm)
    const footK = Scrt[199*W+192];
    let footKL = 0; for(let x=137;x<=249;x++) footKL += Slamp[199*W+x]; footKL /= 113;
    let footM = 0, footML = 0; for(let x=256;x<=290;x++) for(let y=206;y<=210;y++){ footM = Math.max(footM, Scrt[y*W+x]); footML = Math.max(footML, Slamp[y*W+x]); }
    const footR = Slamp[188*W+357];
    const ks = [];
    for(let j=0;j<N;j++){
      const x = j%W, y = (j/W)|0;
      if(MUG[j]){
        const nx = (x-272)/10 + (bay(x,y)-0.5)*0.14;
        const cs = x > 282 ? 0.8 : nx < -0.35 ? 1.25 : nx < 0.3 ? 1.0 : 0.74;     // screen, from the left
        const cl = x > 282 ? 0.9 : nx > 0.35 ? 1.25 : nx > -0.3 ? 1.0 : 0.72;     // lamp, from the right
        Scrt[j] = footM*0.9*cs*tone(j); Slamp[j] = footML*0.75*cl*tone(j);
      } else if(KEYB[j]){
        Scrt[j] = footK*tone(j); Slamp[j] = footKL*tone(j);
        if(L[j] >= 105 && L[j]-L[j-W] >= 22) ks.push(j);
      } else if(ROB[j]){
        Slamp[j] = footR*tone(j);
      }
    }
    KSPEC = Int32Array.from(ks);
    // the porthole's starlight: a faint cold rim round the ring and on the wall beside it
    Sport = new Float32Array(N);
    for(let y=PORT.y-24;y<=PORT.y+24;y++) for(let x=PORT.x-24;x<=PORT.x+24;x++){
      if(x<0||y<0||x>=W||y>=H) continue; const j=y*W+x; if(portM[j]) continue;
      const d = Math.hypot(x-PORT.x, y-PORT.y) - PORT.r;
      Sport[j] = bandStep(d, [[3,0.14],[8,0.08],[16,0.04]], 2, bay(x,y));
    }
    // the cone's air: smooth inside, a dithered edge, gone 3/4 of the way down (Jon's beam rules)
    Fc = new Float32Array(N); const ci = [], cvv = [];
    for(let y=BULB.y-4;y<190;y++) for(let x=250;x<W;x++){
      const j=y*W+x; if(glassM[j]) continue;
      const vx=x-BULB.x, vy=y-BULB.y, d=Math.hypot(vx,vy); if(d<4) continue;
      const ca = (vx*AXIS.x+vy*AXIS.y)/d, e = (ca - Math.cos(LAMP_CONE*0.85))/0.05 + 0.5;
      if(!(e >= 1 || (e > 0 && e > bay(x,y)))) continue;
      const v = Math.pow(clamp(1 - d/58, 0, 1), 1.4); if(v <= 0.02) continue;
      Fc[j] = v; ci.push(j); cvv.push(v);
    }
    coneI = Int32Array.from(ci); coneV = Float32Array.from(cvv);
  }
  // dust in the cone: 14 motes drifting slowly down the beam, whole art pixels, eased in and out
  const DUST = Array.from({length:14}, (_,k)=>({ off: rnd(k*9.3+1)*11, life: 7 + rnd(k*5.1)*4, side: (rnd(k*3.7)-0.5)*18, ph: rnd(k*1.9)*6.28, big: k%3===0 }));
  function drawAir(o, a, lc, f){
    if(a <= 0) return;
    const kr = 30*a*lc[0]*f, kg = 30*a*lc[1]*f, kb = 30*a*lc[2]*f;
    for(let n=0;n<coneI.length;n++){ const i=coneI[n]*4, v=coneV[n]; o[i]+=kr*v; o[i+1]+=kg*v; o[i+2]+=kb*v; }
    const px_ = -AXIS.y, py_ = AXIS.x;
    for(const d of DUST){
      const age = ((R_ + d.off) % d.life + d.life) % d.life, p = age/d.life;
      const along = 8 + p*42, sw = d.side*(0.3 + p*0.7) + 1.6*Math.sin(R_*0.45 + d.ph);
      const x = Math.round(BULB.x + AXIS.x*along + px_*sw), y = Math.round(BULB.y + AXIS.y*along + py_*sw);
      if(x<0||y<0||x>=W-1||y>=H) continue;
      const j = y*W+x, fv = Fc[j]; if(!fv) continue;
      const b = Math.pow(Math.sin(Math.PI*p), 1.5)*a*(0.3 + 0.9*fv*fv)*(0.55 + d.life/11*0.45);
      const i = j*4; o[i]+=66*b*lc[0]*f; o[i+1]+=66*b*lc[1]*f; o[i+2]+=66*b*lc[2]*f;
      if(d.big && Fc[j+1]){ o[i+4]+=33*b*lc[0]*f; o[i+5]+=33*b*lc[1]*f; o[i+6]+=33*b*lc[2]*f; }
    }
  }
  let R_ = 0;

  const px = (x,y)=>(y*W+x)*4;
  function setPx(x,y,hex){ const i = px(x,y); base[i]=parseInt(hex.slice(0,2),16); base[i+1]=parseInt(hex.slice(2,4),16); base[i+2]=parseInt(hex.slice(4,6),16); }

  // The painted steam stub over the mug's rim is static; paint it back to the desk's back edge and draw live steam.
  function cleanSteam(){
    for(let x=268;x<=274;x++) setPx(x,185,'5d6670');
    for(let x=269;x<=273;x++) setPx(x,186,'4c545d');
    for(let x=268;x<=274;x++) setPx(x,187,'2a2f36');
  }

  const WALL = new Set([0x1b2027, 0x111823, 0x080b11, 0x22303f, 0x05080d]);
  function isWall(x,y){ const i = px(x,y); return WALL.has((base[i]<<16)|(base[i+1]<<8)|base[i+2]); }
  function lum(i){ return 0.3*base[i]+0.59*base[i+1]+0.11*base[i+2]; }

  function findEmitters(){
    glassM = new Uint8Array(N); portM = new Uint8Array(N);
    for(let y=GY;y<GY+GH;y++) for(let x=GX;x<GX+GW;x++) glassM[y*W+x] = 1;
    // porthole glass: inside the ring
    for(let y=PORT.y-15;y<=PORT.y+15;y++) for(let x=PORT.x-15;x<=PORT.x+15;x++){
      if(Math.hypot(x-PORT.x,y-PORT.y) <= PORT.r){ portM[y*W+x] = 1; portPts.push(y*W+x);
        const i = px(x,y); if(lum(i) > 70) stars.push({x,y,i:y*W+x,ph:rnd(x*7+y*13),per:1.6+rnd(x+y*3)*2.6,b:lum(i)}); }
    }
    // lamp: the sliver of bulb and the shade's warm inside lip (the shade itself is grey, so warmth is enough)
    for(let y=LAMP_BOX[1];y<=LAMP_BOX[3];y++) for(let x=LAMP_BOX[0];x<=LAMP_BOX[2];x++){
      const i = px(x,y), r=base[i], b=base[i+2];
      if(!(r>b+18 && r>140)) continue;
      lampBulb.push({x,y,i:y*W+x,d:Math.hypot(x-BULB.x,y-BULB.y)});
    }
    // hot core: the bulb's own pixels (the pale sliver), not the lip
    for(const p of lampBulb){ const i=px(p.x,p.y); if(base[i+1]>175) lampHot.push(p); }
    // string bulbs: flood fill from each seed through warm pixels in a tight box
    const mk = (list, side)=> list.forEach(([sx,sy],k)=>{
      const pts=[], seen=new Set(), st=[[sx,sy]];
      const ok=(x,y)=>{ if(x<0||y<0||x>=W||y>=H) return false; if(Math.abs(x-sx)>2||Math.abs(y-sy)>2) return false; const i=px(x,y); return base[i]>110 && base[i]>base[i+2]+22; };
      // find a start pixel near the seed
      let start=null; for(let r=0;r<3&&!start;r++) for(let dy=-r;dy<=r&&!start;dy++) for(let dx=-r;dx<=r&&!start;dx++) if(ok(sx+dx,sy+dy)) start=[sx+dx,sy+dy];
      if(!start) return;
      st[0]=start; seen.add(start[0]+','+start[1]);
      while(st.length){ const [x,y]=st.pop(); pts.push({x,y,i:y*W+x}); for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){ const q=(x+dx)+','+(y+dy); if(!seen.has(q)&&ok(x+dx,y+dy)){ seen.add(q); st.push([x+dx,y+dy]); } } }
      let mx=0,my=0,cream=0; for(const p of pts){ mx+=p.x; my+=p.y; const i=px(p.x,p.y); cream += base[i+2]>100?1:0; }
      mx/=pts.length; my/=pts.length;
      const isCream = cream > pts.length*0.35;
      // the brightest pixel is the filament
      let hot=pts[0], hb=-1; for(const p of pts){ const l=lum(px(p.x,p.y)); if(l>hb){hb=l;hot=p;} }
      strBulbs.push({side, k, cx:mx, cy:my, pts, hot, cream:isCream,
        col: isCream ? [1.0,0.80,0.52] : [1.0,0.58,0.26],
        ph: rnd(k*31+side*7), per: 2.4+rnd(k*17+side*3)*3.1, ph2: rnd(k*5+side), per2: 0.9+rnd(k*11+side*9)*0.8});
    });
    mk(LEFT,0); mk(RIGHT,1); mk(LOW,2); mk(TOP,3);
  }

  function buildFields(){
    Slamp = new Float32Array(N); Scrt = new Float32Array(N); Srim = new Float32Array(N);
    for(let y=0;y<H;y++) for(let x=0;x<W;x++){
      const j = y*W+x; if(glassM[j]||portM[j]) continue;
      // --- lamp (v7 model): a cone out of the shade's mouth. On the wall it draws an arch from the mouth,
      // brightest just below it and falling off with true 3D distance from the bulb; on the desk, an
      // elliptical pool where the axis lands. Plateaus by distance, dithered only at their edges.
      const b0 = bay(x,y);
      let F = 0;
      if(y < 187){
        const vx = x-BULB.x, vy = y-BULB.y, r3 = Math.hypot(vx, vy, LZ);
        const ca = (vx*AXIS.x + vy*AXIS.y)/r3, e = (ca - Math.cos(LAMP_CONE))/0.05 + 0.5;
        if(ca > 0){
          F = bandStep(r3, [[10,.3],[18,.24],[28,.18],[42,.13],[60,.09],[84,.05],[115,.03]], 3, b0);
          if(!(e >= 1 || (e > 0 && e > b0))) F *= 0.06;
        }
      } else {
        const dl = Math.hypot(x-302, (y-197)*3.0);
        F = bandStep(dl, [[16,.4],[30,.34],[48,.26],[70,.18],[98,.1],[135,.05]], 3, b0);   // the pool, a little stronger than the wall
      }
      Slamp[j] = F;
      // --- CRT spill onto the desk in front of it ---
      if(y >= 184){          // round 4: from the keyboard down; A's foot sits in the chin's shadow
        // v7: one wide soft fan, fine steps (faint light stays flat, no checker)
        const w = 92 + (y-181)*2.9, hx = Math.abs(x-192)/w;
        const f = hx<0.45 ? 1 : Math.max(0,(1-hx)/0.55);
        const fy = 1 - (y-181)/62, v = Math.max(0, f*fy);
        Scrt[j] = v < 0.14 ? Math.round(v*40)/40 : Math.floor(v*10 + bay(x,y))/10;
      }
      // --- the bezel's inner lip catches the glass ---
      const dx = x<GX ? GX-x : x>=GX+GW ? x-(GX+GW-1) : 0;
      const dy = y<GY ? GY-y : y>=GY+GH ? y-(GY+GH-1) : 0;
      const dr = Math.max(dx,dy);
      // the opening's inner bevel: the left wall faces the lamp and the bottom faces up, so they catch
      // light; the top and right walls are in shadow. That is what makes the glass read as set back.
      const side = x<GX ? 1 : y>=GY+GH ? 0.8 : y<GY ? 0.22 : 0.3;
      if(dr>0 && dr<=4) Srim[j] = side * (dr<=1 ? 1 : dr<=2 ? 0.6 : (dr<=3 && bay(x,y)<0.5 ? 0.3 : 0));
    }
    // string bulbs: one small local field each
    for(const b of strBulbs){
      const R = 17, x0 = Math.max(0,Math.floor(b.cx-R)), x1 = Math.min(W-1,Math.ceil(b.cx+R));
      const y0 = Math.max(0,Math.floor(b.cy-12)), y1 = Math.min(H-1,Math.ceil(b.cy+26));
      b.box = [x0,y0,x1,y1]; b.S = new Float32Array((x1-x0+1)*(y1-y0+1));
      for(let y=y0;y<=y1;y++) for(let x=x0;x<=x1;x++){
        const j = y*W+x; if(glassM[j]||portM[j]) continue;
        const d = Math.hypot(x-b.cx, (y-b.cy)*(y > b.cy && b.side !== 3 ? 0.62 : 1.1));   // v7: the halo falls down the wall (the top swags hang over the case: kept round)
        const core = d<3 ? 1 : Math.max(0, 1-(d-3)/8);
        const wide = Math.max(0, 1-d/R)*(b.side === 0 || b.side === 2 ? 0.72 : 0.5);   // the left strands wash their wall a little more
        b.S[(y-y0)*(x1-x0+1)+(x-x0)] = quant(Math.max(core,wide), 4, 0.45, x, y);
      }
    }
  }

  // Short contact shadows away from the lamp (mugs and the chip bag on the desk).
  function shadowAt(x,y){
    // the mug: footprint x 263..280 at y ~208; lamp is up-right, shadow falls left
    let s = 1;
    if(y>=196 && y<=209 && x>=250 && x<263){ const k=(263-x)/13; if(y >= 196 + k*5) s = Math.min(s, 0.35 + 0.65*k*k); }
    return s;
  }

  // ---------- timeline helpers ----------
  function lampPower(t){
    const s = t - T.lamp; if(s<0) return {p:0, warm:0};
    // the filament catches: two stutters, then it warms from deep orange to amber
    if(s<0.06) return {p:0.35, warm:0};
    if(s<0.13) return {p:0.04, warm:0};
    if(s<0.21) return {p:0.5, warm:0.05};
    if(s<0.27) return {p:0.12, warm:0.05};
    const k = easeOut((s-0.27)/1.1);
    return {p: 0.55 + 0.45*k, warm: k};
  }
  function bulbPower(b, t, r){
    const on = T.str + STR_ON[b.side] + b.k*0.085 + (rnd(b.k*3+b.side*50)-0.5)*0.05;
    const s = t - on; if(s<0) return 0;
    if(s<0.04) return 0.7; if(s<0.09) return 0.1;
    const k = clamp((s-0.09)/0.22,0,1);
    // idle twinkle: slow breathing, never in sync, and now and then one bulb dips (loose contact)
    // (idle clocks run on real time r, so they keep going forward while leaving reverses t)
    const tw = 0.8 + 0.12*Math.sin(r*2*Math.PI/b.per + b.ph*6.28) + 0.08*Math.sin(r*2*Math.PI/(b.per*0.43) + b.ph2*6.28);
    const ep = Math.floor((r + b.ph*13)/ (9 + b.per*2)); const tin = (r + b.ph*13) - ep*(9+b.per*2);
    const dip = rnd(ep*7 + b.k + b.side*40) < 0.22 && tin < 0.5 ? (tin<0.12 ? 0.5 : tin<0.2 ? 0.85 : tin<0.32 ? 0.55 : 0.85 + (tin-0.32)/0.18*0.15) : 1;
    return (0.25+0.75*k) * tw * (k<1 ? 1 : dip * swell(b, r));
  }
  // Every so often a slow swell of brightness drifts along each string, from the monitor end outward.
  function swell(b, t){
    const P = STR_P[b.side], t0 = 7 + STR_T0[b.side];
    if(t < t0) return 1;
    const n = Math.floor((t-t0)/P), s = (t-t0) - n*P;
    if(rnd(n*5.1 + b.side*9) < 0.25) return 1;            // sometimes it skips a beat
    const pos = -2 + s*3.2;                                // bulbs per second along the wire
    const d = (b.k - pos)/1.8;
    return 1 + 0.38*Math.exp(-d*d);
  }
  // The lamp: slow breathing, a warm-cool drift, and a rare filament brown-out.
  function lampLife(t){
    let breath = 1 + 0.045*Math.sin(t*2*Math.PI/6.3) + 0.025*Math.sin(t*2*Math.PI/2.7+1.3);
    // v7: the filament wavers on two irregular clocks, and every 7-13 s dips 6-9% for about half a second
    breath *= 1 + 0.022*vnoise(t*1.7, 61) + 0.012*vnoise(t*4.3, 67);
    { const P = 10, ci = Math.floor(t/P), at = 1.5 + rnd(ci*3.9+1)*6, a = t - ci*P - at, len = 0.45 + rnd(ci*2.2)*0.25;
      if(a > 0 && a < len) breath *= 1 - (0.06 + rnd(ci*7.1)*0.03)*Math.sin(Math.PI*a/len); }
    const drift = 0.6*Math.sin(t*2*Math.PI/13.1) + 0.4*Math.sin(t*2*Math.PI/5.3+2.0);   // -1 cool .. +1 warm
    let brown = 1;
    const t0 = 8; if(t > t0){
      const P = 8.7, n = Math.floor((t-t0)/P), s = (t-t0) - n*P - rnd(n*3.3)*4;
      if(rnd(n*7.7) < 0.3 && s >= 0 && s < 0.7){      // v7: rarer
        const depth = 0.16 + 0.1*rnd(n*1.9);
        // sag, a small catch, sag again, then ease back
        brown = s<0.08 ? 1 - depth*(s/0.08) : s<0.16 ? 1 - depth*0.55 : s<0.28 ? 1 - depth : 1 - depth*(1 - easeOut((s-0.28)/0.42));
      }
    }
    return {breath, drift, brown};
  }
  // CRT: returns {stage, k} and the spill level
  // Nov 17 (Jon: "the opening sequence for the screen could be a bit slower. Maybe with a title screen"):
  // the tube's own warm-up runs 1.5x longer, then the game's title card holds, then wipes into the game.
  const CB = { dot:0.105, line:0.405, open:0.78, boot:3.68 };
  const CB_ON = CB.boot + DESK.TITLE.hold + DESK.TITLE.wipe + 0.5;
  function crtState(t){
    const s = t - (T.crt + 0.12);
    if(s<0) return {st:'off', spill:0};
    if(s<CB.dot) return {st:'dot', k:s/CB.dot, spill:0.06};
    if(s<CB.line){ const k=(s-CB.dot)/(CB.line-CB.dot); return {st:'line', k, spill:0.1+0.15*k}; }
    if(s<CB.open){ const k=(s-CB.line)/(CB.open-CB.line); return {st:'open', k, spill:0.25+0.25*k}; }
    if(s<CB.boot) return {st:'boot', k:(s-CB.open)/1.5, spill:0.5};
    const tt = s - CB.boot, Hh = DESK.TITLE.hold, Wp = DESK.TITLE.wipe;
    if(tt<Hh) return {st:'title', k:tt, spill:0.45};
    if(tt<Hh+Wp) return {st:'wipe', k:(tt-Hh)/Wp, tt, spill:0.6};
    if(tt<Hh+Wp+0.5) return {st:'settle', k:(tt-Hh-Wp)/0.5, spill:0.8};
    return {st:'on', k:tt, spill:0.8};
  }

  // Leaving: the same window of scene time, but the tube switches off the way a CRT does:
  // the picture flares, collapses to a bright line, the line shrinks to a dot, the dot fades.
  function crtStateLeaving(t){
    const s = t - (T.crt + 0.12), u = Math.min(1, s/3.4);
    if(s<0) return {st:'off'};
    if(u>0.86) return {st:'on', k:0, flare:clamp((1-u)/0.14, 0, 1)};
    if(u>0.45) return {st:'shrink', k:(u-0.45)/0.41};
    if(u>0.2)  return {st:'line', k:(u-0.2)/0.25};
    return {st:'dot', k:u/0.2, fadeDot:true};
  }

  // ---------- frame ----------
  function frame(g, t, info){
    if(DESK.act1(g, t, local)) return;
    const leaving = !!(info && info.leaving);
    const r = info && info.real != null ? info.real : t;   // idle clocks: always forward
    const o = out.data;
    const fade = clamp((t-T.room)/T.roomIn, 0, 1);
    const lp = lampPower(t);
    // the lamp's life only once it is fully up (so the strike and the switch-off stay clean)
    const lf = lampLife(r), full = t >= T.lamp + 1.4;
    // lamp colour: deep filament orange warming to amber; drifts warm/cool; a brown-out runs warmer
    const dr = full ? 0.035*lf.drift - 0.25*(1-lf.brown) : 0;
    const lc = [1.0, 0.40 + 0.34*lp.warm + dr, Math.max(0.08, 0.12 + 0.30*lp.warm + 1.2*dr)];
    const crt = leaving ? crtStateLeaving(t) : crtState(t);
    crt.r = r;
    const mean = fillScreen(r, crt);
    const gl = (crt.st==='on' && !leaving && t >= T.crt + 0.12 + CB_ON + 1.5) ? glitchAt(r) : null;
    crt.gl = gl;
    // the screen's light follows the screen: its picture, its breathing, the band, the glitches
    const bandP = crt.st==='on' ? Math.exp(-Math.pow((bandRow(r)-112)/26, 2)) : 0;
    const crtW = crt.st==='off' ? 0 : clamp(0.8*mean/cultMean, 0, 1.6) * (crt.st==='on' ? crtLife(r) : 1) * (1 + 0.28*bandP) * glitchSpill(gl);
    // phosphor teal (#5fae9a), leaning toward what is on the glass, desaturated; green while it boots
    let cc = [0.55, 1, 0.89];
    if(crt.st==='boot' || crt.st==='open' || crt.st==='title') cc = [0.45, 1, 0.7];
    else if(crt.st==='on' || crt.st==='settle' || crt.st==='wipe'){ const sm=(scrCol[0]+scrCol[1]+scrCol[2])/3;
      cc = [cc[0]+((sm+scrCol[0])/2-cc[0])*0.35, cc[1]+((sm+scrCol[1])/2-cc[1])*0.35, cc[2]+((sm+scrCol[2])/2-cc[2])*0.35]; }
    // ---- C lighting (Nov 18): steady weights composed and stepped once (cached), flicker multiplied after ----
    R_ = r;
    const FX = window.ROOMFX;
    const lpS = Math.round(lp.p*24)/24, warmQ = Math.round(lp.warm*12)/12, fadeQ = Math.round(fade*24)/24;
    const lcS = [1.0, 0.40 + 0.34*warmQ, Math.max(0.08, 0.12 + 0.30*warmQ)];
    // the lamp flickers a little (a tired bulb) and browns out now and then; the strings twinkle
    const flickL = full ? FX.tiredBulb(r, 7, { depth: 1.2 }) * lf.brown : 1;
    const bw = strBulbs.map(b => bulbPower(b, t, r));
    const son = bw.map(v => v > 0 ? 1 : 0);
    const sFl = bw.map((v, n) => v > 0 ? Math.min(v, 1.35) * FX.tiredBulb(r, 30 + n*7, { depth: .9, every: 5 + (n % 4), stutterEvery: 23 + n }) : 1);
    const crtOn = crt.st === 'off' ? 0 : 1, boot = (crt.st==='boot' || crt.st==='open' || crt.st==='title') ? 1 : 0;
    const mcS = boot ? [0.45, 1, 0.7] : [0.55, 1, 0.89];
    const key = [lpS, warmQ, crtOn, boot, fadeQ, son.join('')].join('|');
    if(!CC2.S || CC2.key !== key){
      const tl = lcS.map(v => 1 + (v - 1)*0.7), tm = mcS.map(v => 1 + (v - 1)*0.5);
      CC2.S = LIT.compose({ A: A2, amb: [.17, .18, .23], fa: Fa, fade: fadeQ, ov: .3, hot: 6, hotCol: lcS,
        big: [ { F: FLD.lamp, w: lpS*1.3, tint: tl, ch: 0 }, { F: FLD.scr, w: crtOn*1.05, tint: tm, ch: 1 },
               { F: FLD.port, w: .6*fadeQ, tint: [.8, .88, 1], ch: 2 } ],
        small: SMALL.map((q, n) => ({ f: q.f, box: q.box, w: son[n]*1.3*fadeQ, tint: [1, .82, .62].map((v, k) => v*0.5 + strBulbs[n].col[k]*0.5) })) });
      CC2.key = key;
    }
    LIT.frame(CC2.S, o, { lamp: flickL, scr: crtW, small: sFl }, Lc);
    for(let j=0;j<N;j++){ Gr[j] = Lc[j*3]; Gg[j] = Lc[j*3+1]; Gb[j] = Lc[j*3+2]; }
    const lampW = lp.p * flickL, flick = flickL;
    // dust in the air, lit by the light where each mote is ("more dust overall")
    FX.drawDust(DUSTC, o, r, j => [Gr[j], Gg[j], Gb[j]], 72, .03, fade);
    drawEmitters(o, t, r, lp, flick, bw, fade);
    FX.drawSky(SKY, (j, R0, G0, B0) => put(o, j, R0, G0, B0, fade), r, 1);
    drawScreen(o, r, crt, fade);
    drawSheen(o, lampW, lc, fade);
    { const lw = Math.min(1, lampW), cw = Math.min(1.2, crtW);
      drawSteam(o, r, fade, [44*lw*lc[0], 44*lw*lc[1], 44*lw*lc[2]], [46*cw*cc[0], 46*cw*cc[1], 46*cw*cc[2]]); }
    if(DEBUG) debugMarks(o);
    cx.putImageData(out,0,0);
    g.imageSmoothingEnabled = false;
    g.drawImage(cv, 0, 0, 1920, 1080);
    drawRaster(g, crt);
  }

  function put(o, j, R, G, B, f){ const i=j*4; o[i]=R*f; o[i+1]=G*f; o[i+2]=B*f; }
  function addGlow(o, x, y, col, w, f){
    // a two-ring stepped glow round a small LED, on whole art pixels
    for(let dy=-2;dy<=2;dy++) for(let dx=-2;dx<=3;dx++){
      const xx=x+dx, yy=y+dy; if(xx<0||yy<0||xx>=W||yy>=H) continue;
      const d = Math.max(Math.abs(dx-0.5)-0.5, Math.abs(dy)); const s = d<=1 ? 0.5 : (bay(xx,yy)<0.5 ? 0.2 : 0);
      if(!s) continue; const i=(yy*W+xx)*4;
      o[i]  = Math.min(255, o[i]  + base[i]  *s*w*col[0]*0.9*f + 40*s*w*col[0]*f);
      o[i+1]= Math.min(255, o[i+1]+ base[i+1]*s*w*col[1]*0.9*f + 40*s*w*col[1]*f);
      o[i+2]= Math.min(255, o[i+2]+ base[i+2]*s*w*col[2]*0.9*f + 40*s*w*col[2]*f);
    }
  }

  function drawEmitters(o, t, r, lp, flick, bw, f){
    // lamp bulb: dark glass when off, the filament catches first, then the whole bulb
    const p = lp.p;
    for(const q of lampBulb){
      const i = q.i*4, r0=base[i], g0=base[i+1], b0=base[i+2];
      const fil = clamp(1 - q.d/7, 0, 1);              // centre catches first
      const lit = p<0.5 ? p*(0.4+1.2*fil) : 0.6 + 0.4*(p-0.5)/0.5;
      const k = Math.min(1, lit);
      const offR = r0*0.16+4, offG = g0*0.13+4, offB = b0*0.12+5;
      // warming: early light is deep orange
      const fl = 0.55 + 0.45*flick;                    // the glass dims with the filament, less than the light does
      const onR = Math.min(255, r0*1.12*fl), onG = g0*(0.62+0.5*lp.warm)*fl*fl, onB = b0*(0.35+0.55*lp.warm)*fl*fl*fl;
      put(o, q.i, offR+(onR-offR)*k, offG+(onG-offG)*k, offB+(onB-offB)*k, f);
    }
    if(p>0.5){ const h = clamp((p-0.55)/0.4,0,1)*lp.warm*clamp((flick-0.72)/0.25,0,1);
      for(const q of lampHot){ const i=q.i*4; o[i]=Math.min(255,o[i]+(255-o[i])*h)*1; o[i+1]=Math.min(255,o[i+1]+(248-o[i+1])*h); o[i+2]=Math.min(255,o[i+2]+(222-o[i+2])*h); } }
    // string bulbs
    strBulbs.forEach((b,n)=>{
      const w = clamp(bw[n],0,1.1);
      for(const q of b.pts){
        const i=q.i*4, r0=base[i], g0=base[i+1], b0=base[i+2];
        const offR=r0*0.13+3, offG=g0*0.11+3, offB=b0*0.11+4;
        const onR=Math.min(255,r0*1.1+12), onG=Math.min(255,g0*1.05+6), onB=b0*0.95;
        put(o, q.i, offR+(onR-offR)*w, offG+(onG-offG)*w, offB+(onB-offB)*w, f);
      }
      if(w>0.6){ const h=Math.min(1,(w-0.6)/0.5), i=b.hot.i*4; const hc = b.cream ? [255,246,222] : [255,214,150];
        o[i]+= (hc[0]-o[i])*h*0.8; o[i+1]+=(hc[1]-o[i+1])*h*0.8; o[i+2]+=(hc[2]-o[i+2])*h*0.8; }
    });
    // porthole: outside, so always on; stars glint on their own slow clocks (whole pixels, held)
    for(const j of portPts){ const i=j*4; o[i]=base[i]*0.9*f; o[i+1]=base[i+1]*0.9*f; o[i+2]=base[i+2]*f; }
    for(const s of stars){
      const n = Math.floor(r/s.per + s.ph*5), v = rnd(n*13 + s.x*3 + s.y);
      const lvl = v<0.2 ? 0.55 : v<0.75 ? 0.85 : 1.08;
      const i = s.i*4; o[i]=Math.min(255,base[i]*lvl)*f; o[i+1]=Math.min(255,base[i+1]*lvl)*f; o[i+2]=Math.min(255,base[i+2]*lvl+6)*f;
    }
    // now and then a far-off ship crawls across the porthole (about 5 art px a second, whole pixels)
    const SHIPP = 21, sn = Math.floor((r-11)/SHIPP), st = (r-11) - sn*SHIPP;
    if(r > 11 && st < 7){
      const k = st/7, y0 = PORT.y - 9 + Math.floor(rnd(sn*4.3)*12), dir = rnd(sn*2.9) < 0.5 ? 1 : -1;
      const x = Math.round(PORT.x + dir*(-17 + 34*k)), y = Math.round(y0 + 5*k);
      const j = y*W + x;
      if(x>0 && x<W && portM[j]){ const blink = (st % 1.3) < 0.25; put(o, j, blink?255:205, blink?110:215, blink?90:228, f);
        // a faint trail one pixel behind it
        const jt = y*W + x - dir; if(portM[jt] && !blink){ const i=jt*4; o[i]=Math.min(255,o[i]+40*f); o[i+1]=Math.min(255,o[i+1]+45*f); o[i+2]=Math.min(255,o[i+2]+55*f); } }
    }
    // monitor power LED (green), on A's chin just right of the button (A's own LED spot is under the blue note)
    const pl = t >= T.crt ? 1 : 0;
    for(const [x,y] of [[142,169],[143,169]]){ const j=y*W+x; pl ? put(o,j,120,255,150,f) : put(o,j,40,52,44,f); }
    if(pl) addGlow(o, 142, 169, [0.25,1,0.45], 0.7, f);
    // soldering station heater LED (red): cycles like a real one holding temperature
    let ir = 0;
    if(t >= T.iron){ const s = t - T.iron; ir = s<1.6 ? 1 : (r % 2.9) < 1.9 ? 1 : 0.0; if(s<0.05) ir=0.6; }
    for(const [x,y] of [[339,191],[340,191]]){ const j=y*W+x; ir ? put(o,j,255,70,46,f) : put(o,j,46,16,12,f); }
    if(ir) addGlow(o, 339, 191, [1,0.25,0.15], 0.9, f);
  }

  // ---------- CRT ----------
  function glyph(buf, ch, x0, y0, col){
    const s = FONT[ch]; if(!s) return;
    for(let r=0;r<5;r++) for(let c=0;c<3;c++) if(s[r*3+c]==='1'){ const x=x0+c, y=y0+r; if(x>=0&&x<GW&&y>=0&&y<GH){ const i=(y*GW+x)*3; buf[i]=col[0]; buf[i+1]=col[1]; buf[i+2]=col[2]; } }
  }
  const scr = new Float32Array(GW*GH*3);
  function bandRow(t){ return -999; }   // rolling band removed (Jon)
  // Fill the glass's picture for this frame; returns the picture's mean brightness (0..1)
  // so the light it throws on the desk follows what is on it.
  function fillScreen(t, crt){
    const st = crt.st;
    if(st==='off') return 0;
    scr.fill(0);
    const blank = [14,24,30];
    if(st==='dot'){
      const dk = crt.fadeDot ? crt.k : 1;
      for(let y=69;y<=70;y++) for(let x=74;x<=75;x++){ const i=(y*GW+x)*3; scr[i]=230*dk; scr[i+1]=250*dk; scr[i+2]=255*dk; }
    } else if(st==='line'){
      const hw = Math.max(1, Math.round(easeOut(crt.k)*75));
      for(let x=75-hw;x<75+hw;x++){ const i=(69*GW+x)*3, i2=(70*GW+x)*3; scr[i]=210; scr[i+1]=240; scr[i+2]=250; scr[i2]=120; scr[i2+1]=170; scr[i2+2]=190; }
    } else if(st==='shrink'){
      // switching off: the picture squeezes into a brightening line
      const k = crt.k, hh = Math.max(1, Math.round(easeOut(k)*70)), boost = 1 + (1-k)*1.4;
      for(let y=70-hh;y<70+hh;y++){ const sy = Math.min(GH-1, Math.floor((y-(70-hh))/(2*hh)*GH));
        for(let x=0;x<GW;x++){ const s=(sy*GW+x)*4, i=(y*GW+x)*3; scr[i]=Math.min(255,culture[s]*boost+40*(1-k)); scr[i+1]=Math.min(255,culture[s+1]*boost+55*(1-k)); scr[i+2]=Math.min(255,culture[s+2]*boost+60*(1-k)); } }
    } else if(st==='open'){
      const hh = Math.max(1, Math.round(easeOut(crt.k)*70));
      const gl = 1 - crt.k;
      for(let y=70-hh;y<70+hh;y++){ const e = Math.abs(y-69.5)<2 ? gl : 0;
        for(let x=0;x<GW;x++){ const i=(y*GW+x)*3; scr[i]=blank[0]*(1+1.5*gl)+190*e; scr[i+1]=blank[1]*(1+1.5*gl)+220*e; scr[i+2]=blank[2]*(1+1.5*gl)+230*e; } }
    } else if(st==='title'){
      DESK.titleCard(scr, crt.k, 0);
    } else if(st==='boot'){
      for(let j=0;j<GW*GH;j++){ scr[j*3]=blank[0]; scr[j*3+1]=blank[1]; scr[j*3+2]=blank[2]; }
      const col = [150,222,186];
      let shown = Math.floor(crt.k*33) - 4; // chars typed
      let cy = 6, cxp = 6, lastX = 6, lastY = 6;
      for(let L=0; L<BOOT.length; L++){
        const line = BOOT[L]; cxp = 6;
        for(let c=0;c<line.length;c++){ if(shown<=0) break; glyph(scr, line[c], cxp, cy, col); cxp += 4; shown--; }
        lastX = cxp; lastY = cy;
        if(shown<=0) break;
        shown -= 3; // a beat between lines
        cy += 8;
      }
      if(Math.floor(t*2.6)%2===0) for(let y=lastY;y<lastY+5;y++) for(let x=lastX;x<lastX+3;x++){ const i=(y*GW+x)*3; scr[i]=col[0]*0.85; scr[i+1]=col[1]*0.85; scr[i+2]=col[2]*0.85; }
    } else {
      // the picture: rolls in with the vertical hold, then locks
      let off = 0, bright = crt.flare != null ? 1 + 0.25*(1-crt.flare) : 1;
      if(st==='roll'){ const k = crt.k; off = Math.round((1-easeOut(k))*1.6*(GH+5)); bright = Math.min(1, 0.2 + 0.8*k/0.35)*(0.8+0.2*k); }
      for(let y=0;y<GH;y++){
        let sy = y - off; sy = ((sy % (GH+5)) + (GH+5)) % (GH+5);
        if(sy>=GH){ continue; }   // sync bar: black
        const nb = Math.max(0, 1-bright);
        for(let x=0;x<GW;x++){ const s=(sy*GW+x)*4, i=(y*GW+x)*3; scr[i]=culture[s]*bright+blank[0]*nb; scr[i+1]=culture[s+1]*bright+blank[1]*nb; scr[i+2]=culture[s+2]*bright+blank[2]*nb; }
      }
      if(st==='wipe') DESK.titleCard(scr, crt.tt, crt.k);   // the title wipes off top-down into the game
    }
    let sum = 0, n = 0, sr = 0, sg = 0, sb = 0;
    for(let y=1;y<GH;y+=3) for(let x=1;x<GW;x+=3){ const i=(y*GW+x)*3; sum += 0.3*scr[i]+0.59*scr[i+1]+0.11*scr[i+2]; sr+=scr[i]; sg+=scr[i+1]; sb+=scr[i+2]; n++; }
    const m = Math.max(sr, sg, sb);
    if(m > 1e3){ const k = 0.3; scrCol = [scrCol[0]+(sr/m-scrCol[0])*k, scrCol[1]+(sg/m-scrCol[1])*k, scrCol[2]+(sb/m-scrCol[2])*k]; }
    return sum/n/255;
  }
  function drawScreen(o, t, crt, f){
    const st = crt.st;
    if(st==='off'){ for(let y=0;y<GH;y++) for(let x=0;x<GW;x++){ const i=((GY+y)*W+GX+x)*4; o[i]=5*f; o[i+1]=8*f; o[i+2]=13*f; } return; }
    const mxC = GW/2, myC = GH/2;
    // the old monitor: scanlines, curved corners, a slow brighter band, a rare one-pixel tear
    const on = st==='on' || st==='roll' || st==='boot' || st==='title' || st==='wipe' || st==='settle';
    const live = on ? crtLife(t) : 1, bandY = bandRow(t);
    const gl = crt.gl;
    // interference: one faint brighter row with a darker row under it, drifting slowly upward
    const intY = -99;   // interference line removed (Jon: looked bad)
    // glitch set-up (one at a time)
    let jitY0 = -1, jitY1 = -1, jitSh = 0, rgb = 0, statY = -99, vhold = 0;
    if(gl){
      const s = gl.s, r1 = gl.r1, r2 = gl.r2;
      if(gl.type==='jitter'){ jitY0 = 8 + Math.floor(r1*110); jitY1 = jitY0 + 2 + Math.floor(r2*5);
        const step = Math.floor(s/0.07); jitSh = [1,2,-1,1,0,2,-1][step % 7] * (r1<0.5?1:-1); }
      else if(gl.type==='rgb') rgb = 1;
      else if(gl.type==='static') statY = Math.floor(-6 + s/gl.dur*(GH+12));
      else if(gl.type==='vhold') vhold = s<0.09 ? 2 : s<0.2 ? -1 : s<0.3 ? 1 : 0;
    }
    // phosphor glow: bright picture bleeds a little into its neighbours
    bloomPass();
    const nq = Math.floor(t*14);                      // static grain refreshes at 14 Hz, not every frame
    for(let y=0;y<GH;y++){
      const db = Math.abs(y-bandY);
      let rowK = on ? (db<3 ? 1.18 : db<7 ? 1.1 : db<11 ? 1.04 : 1) : 1;
      if(y===intY) rowK *= 1.07; else if(y===intY+1) rowK *= 0.95;
      const shift = (y>=jitY0 && y<=jitY1) ? jitSh : 0;
      const sy = clamp(y - vhold, 0, GH-1);
      const isStat = statY>-99 && y>=statY && y<statY+3;
      for(let x=0;x<GW;x++){
        const sx = clamp(x - shift, 0, GW-1);
        const i = (sy*GW+sx)*3;
        // vignette: dimmer toward the corners of the tube
        const ex = (x-mxC)/mxC, ey = (y-myC)/myC; const vig = 1 - 0.2*(ex*ex*ey*ey*2.2 + 0.25*(ex*ex+ey*ey));
        let k = rowK*vig*live;
        // recess: the tube's rounded corners and the bezel's shadow on the glass (static, stepped)
        k *= recess[y*GW+x];
        let r0 = scr[i]+bloom[i], g0 = scr[i+1]+bloom[i+1], b0 = scr[i+2]+bloom[i+2];
        if(rgb){ const ir = (sy*GW+clamp(sx-1,0,GW-1))*3, ib = (sy*GW+clamp(sx+1,0,GW-1))*3; r0 = scr[ir]+bloom[ir]; b0 = scr[ib+2]+bloom[ib+2]; }
        if(isStat){ const v = rnd(nq*977 + y*151 + x*7.3); const a = 0.55; const nv = 40 + v*120; r0 = r0*(1-a)+nv*a; g0 = g0*(1-a)+nv*a; b0 = b0*(1-a)+(nv+10)*a; }
        const R = 5 + r0*k, G = 8 + g0*k*1.01, B = 13 + b0*k*1.03;
        const oi = ((GY+y)*W+GX+x)*4;
        o[oi]=Math.min(255,R)*f; o[oi+1]=Math.min(255,G)*f; o[oi+2]=Math.min(255,B)*f;
      }
    }
  }
  // Static depth for the glass: rounded tube corners, a thin dark gap at the edge, and the
  // bezel's shadow along the top (room light from above) and the right (the lamp's side).
  const recess = (()=>{
    const a = new Float32Array(GW*GH);
    for(let y=0;y<GH;y++) for(let x=0;x<GW;x++){
      let k = 1;
      const qx = Math.min(x, GW-1-x), qy = Math.min(y, GH-1-y);
      const R = 6;
      if(qx<R && qy<R){ const d = Math.hypot(R-0.5-qx, R-0.5-qy); if(d > R) k = 0; else if(d > R-1.2) k = 0.45; }
      if(qx===0 || qy===0) k = Math.min(k, 0.4);
      // shadow steps, dithered between steps
      const top = y, right = GW-1-x;
      const st = (dist, steps)=>{ for(let n=0;n<steps.length;n++) if(dist===n) return steps[n]; return 1; };
      // (v7: the uneven top/right lip shading is gone; the tube darkens the corners evenly)
      a[y*GW+x] = k;
    }
    return a;
  })();
  // The glass bulges: a fixed curved sheen near the top-right corner and a small glint of the lamp.
  function drawSheen(o, lampW, lc, f){
    if(lampW <= 0) return;
    const add = (x,y,a)=>{ if(x<0||x>=GW||y<0||y>=GH) return; const i=((GY+y)*W+GX+x)*4;
      o[i]=Math.min(255,o[i]+a*255*lc[0]*f); o[i+1]=Math.min(255,o[i+1]+a*235*lc[1]*f); o[i+2]=Math.min(255,o[i+2]+a*215*Math.max(lc[2],0.5)*f); };
    const w = Math.min(1, lampW);
    // an arc following the tube's curve, top right
    // v7 (Jon on desk_1: "the glass effect doesn't work well"): no fixed sheen; the lamp only a faint smudge
    const gx = GW-16, gy = 9;
    for(let dy=0;dy<2;dy++) for(let dx=0;dx<2;dx++) add(gx+dx, gy+dy, 0.05*w);
  }
  const bloom = new Float32Array(GW*GH*3), bright = new Float32Array(GW*GH*3);
  function bloomPass(){
    // bright-pass, then a 3x3 box spread at art pixels, added at low strength
    for(let j=0;j<GW*GH;j++){ const i=j*3, l = 0.3*scr[i]+0.59*scr[i+1]+0.11*scr[i+2];
      const k = l>95 ? (l-95)/160 : 0; bright[i]=scr[i]*k; bright[i+1]=scr[i+1]*k; bright[i+2]=scr[i+2]*k; }
    for(let y=0;y<GH;y++) for(let x=0;x<GW;x++){
      let r=0,g=0,b=0;
      for(let dy=-1;dy<=1;dy++){ const yy=y+dy; if(yy<0||yy>=GH) continue;
        for(let dx=-1;dx<=1;dx++){ const xx=x+dx; if(xx<0||xx>=GW) continue; const i=(yy*GW+xx)*3; r+=bright[i]; g+=bright[i+1]; b+=bright[i+2]; } }
      const i=(y*GW+x)*3; bloom[i]=r*0.07; bloom[i+1]=g*0.07; bloom[i+2]=b*0.07;
    }
  }
  // Constant faint life on the tube: 1-3% brightness on its own irregular clock.
  function crtLife(t){
    return 1 + 0.014*Math.sin(t*2*Math.PI/4.1) + 0.009*Math.sin(t*2*Math.PI/1.7 + 0.8) + 0.006*Math.sin(t*2*Math.PI/0.53 + 2.1);
  }
  // Glitches: one every 3-8 s, each brief, never two at once, never the same kind twice running.
  const GL = { starts:[], types:[] };
  const GL_KINDS = ['jitter','rgb','jitter','vhold'];   // static band removed (Jon)
  const GL_DUR = { jitter:0.32, rgb:0.05, static:0.55, vhold:0.36 };
  function glitchAt(t){
    const t0 = T.crt + 0.12 + CB_ON + 1.5;
    if(t < t0) return null;
    while(!GL.starts.length || GL.starts[GL.starts.length-1] < t){
      const n = GL.starts.length, prev = n ? GL.starts[n-1] : t0;
      GL.starts.push(prev + 3 + 5*rnd(n*2.71+0.3));
      // a fixed round of five, so no kind repeats back to back; the hold hiccup only every other round
      let ty = GL_KINDS[n % 5];
      if(ty==='vhold' && Math.floor(n/5) % 2) ty = 'rgb';
      GL.types.push(ty);
    }
    // find the latest start <= t
    let lo = 0, hi = GL.starts.length-1, k = -1;
    while(lo<=hi){ const m=(lo+hi)>>1; if(GL.starts[m] <= t){ k=m; lo=m+1; } else hi=m-1; }
    if(k<0) return null;
    const ty = GL.types[k], s = t - GL.starts[k], dur = GL_DUR[ty];
    if(s > dur) return null;
    return { type:ty, s, dur, r1:rnd(k*3.1+0.7), r2:rnd(k*4.9+0.2) };
  }
  // How a glitch shows in the light the screen throws (faint).
  function glitchSpill(gl){
    if(!gl) return 1;
    if(gl.type==='static') return 1.06;
    if(gl.type==='vhold') return gl.s<0.09 ? 0.9 : 0.97;
    if(gl.type==='jitter') return Math.floor(gl.s/0.07)%2 ? 0.96 : 1.03;
    return 0.95;
  }
  // The tube's raster: a thin dark line under every art row, drawn on the 5x canvas.
  function drawRaster(g, crt){
    if(crt.st==='off') return;
    g.fillStyle = 'rgba(0,0,0,0.3)';
    for(let r=0;r<GH;r++) g.fillRect(GX*5, (GY+r)*5+4, GW*5, 1);
  }

  // ---------- steam (Nov 17): desk_1's steam, the one Jon approved ("the steam can be more prominent") ----------
  // Jon, Nov 17: "some of the coffee cups have no steam". The old puffs here were clipped to a small box
  // over the mug, so they were cut off flat a few pixels up ("weird steam?"); this is desk 1's: wisps curl
  // up off the opening (x, y: the opening's centre and two rows below the rim's top, as on desk 1), each
  // pixel keeps the strongest wisp over it, alpha in dithered steps. It scatters the room's light, so even
  // over the dark wall it reads as a pale veil, and only ever lightens. It thins out by distance before the
  // glass, so no edge cuts it.
  const MUGS = [{x:270, y:190, seed:2, dir:1}];    // rim top y 188, the coffee x 264-277
  const SBW = 36, SBH = 48, SA = new Float32Array(SBW*SBH);
  function steamField(m, u){
    SA.fill(0);
    const NP = 16, LIFE = 4.6, dir = m.dir||1, x0 = m.x-18, y0 = m.y-46;
    const sway = Math.sin(u*0.31 + m.seed)*1.6;
    const mark = (x,y,a)=>{ const bx = x-x0, by = y-y0; if(bx<0||by<0||bx>=SBW||by>=SBH) return; const k = by*SBW+bx; if(a > SA[k]) SA[k] = a; };
    for(let p=0;p<NP;p++){
      const age = ((u + p*LIFE/NP + m.seed*0.37) % LIFE + LIFE) % LIFE, a = age/LIFE;
      const ph = rnd(p*3.1 + m.seed)*6.28, env = Math.pow(Math.sin(Math.PI*Math.min(1, a*1.25)), 0.7)*(1 - a*0.35);
      for(let tr=0;tr<5;tr++){
        const ag = age - tr*0.1; if(ag < 0) continue;
        const yy = Math.round(m.y - 2 - ag*8.2), amp = 0.5 + ag*1.25;
        const xx = Math.round(m.x + amp*Math.sin(ag*1.7 + ph + Math.sin(u*0.45 + p)*0.8) + dir*ag*(0.5 + sway*0.25) - 0.5);
        const al = 0.62*env*(1 - tr*0.14);
        mark(xx, yy, al);
        if(ag > 0.5) mark(xx+dir, yy, al*0.75);
        if(ag > 1.4){ mark(xx-dir, yy, al*0.6); mark(xx, yy-1, al*0.6); }
        if(ag > 2.4){ mark(xx+2*dir, yy, al*0.4); mark(xx-2*dir, yy+1, al*0.3); }
      }
    }
    return [x0, y0];
  }
  // lit by the light multiplier at each pixel (Gr/Gg/Gb, this frame's), faded with the room; as on desk 1 the
  // side facing a light takes a little of its colour: the lamp's amber on the right, the screen's teal on the left
  function drawSteam(o, u, f, warm, cool){
    for(const m of MUGS){
      const [x0, y0] = steamField(m, u);
      for(let by=0;by<SBH;by++) for(let bx=0;bx<SBW;bx++){
        let al0 = SA[by*SBW+bx]; if(al0 <= 0.02) continue;
        const x = x0+bx, y = y0+by; if(x<0||x>=W||y<0||y>=H) continue;
        const j = y*W+x; if(glassM[j]) continue;
        const gdx = Math.max(GX-x, 0, x-(GX+GW-1)), gdy = Math.max(GY-y, 0, y-(GY+GH-1));
        al0 *= Math.min(1, Math.hypot(gdx, gdy)/4);
        const al = Math.min(0.56, Math.floor(al0/0.14 + bay(x,y))*0.14); if(al <= 0) continue;
        const i = j*4;
        const T = x > m.x+1 ? warm : cool;
        const sr = (150*Math.min(Gr[j]*1.4 + 0.4, 1.3) + T[0])*f, sg = (156*Math.min(Gg[j]*1.4 + 0.4, 1.3) + T[1])*f, sb = (162*Math.min(Gb[j]*1.4 + 0.4, 1.3) + T[2])*f;
        o[i] = Math.max(o[i], o[i]+(sr-o[i])*al); o[i+1] = Math.max(o[i+1], o[i+1]+(sg-o[i+1])*al); o[i+2] = Math.max(o[i+2], o[i+2]+(sb-o[i+2])*al);
      }
    }
  }

  function debugMarks(o){
    const mark = (j)=>{ const i=j*4; o[i]=255; o[i+1]=0; o[i+2]=255; };
    lampBulb.forEach(q=>mark(q.i)); strBulbs.forEach(b=>b.pts.forEach(q=>mark(q.i))); stars.forEach(s=>mark(s.i));
    lampHot.forEach(q=>{ const i=q.i*4; o[i]=0; o[i+1]=255; o[i+2]=255; });
  }

  DESK.register({ id:'desk_2', name:'DESK 2', line:'Lamp, string lights, then the old terminal.', doneAt:12.8, init, frame, times:{ lamp:T.lamp, crt:T.crt },
    _dbg:{ get Slamp(){return Slamp;}, get Scrt(){return Scrt;}, get strBulbs(){return strBulbs;}, get stars(){return stars;}, get lampBulb(){return lampBulb;} } });
})();
