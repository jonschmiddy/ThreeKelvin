// BUNK 1: the bunk-side fold-out shelf. Late night: starlight through the porthole lies on the
// blanket, then the clip lamp, the string lights round the photos, and the old CRT come on.
// Light is worked at art resolution (384x216): each light is a fixed, stepped field (its shape),
// and everything that moves in time (power-on, breathing, twinkle) only multiplies it.
(function(){
  const W = 384, H = 216, N = W*H, SCALE = 5;
  const GX = 117, GY = 22, GW = 150, GH = 140;            // CRT glass
  const PC = {x:335, y:60, r:24.2};                        // porthole glass
  const LAMP = {x:287, y:136};                            // architect lamp bulb, under its dome shade (round 4, PixelLab lamp)
  const DESK_L = 95, DESK_R = 291, DESK_TOP = 200, DESK_FRONT = 201, DESK_UNDER = 206;   // round 4: the shelf is deeper

  // ---- timeline (seconds since start) ----
  const T_FADE = 2.5, T_LAMP = 3.55, T_STRING = 4.35, T_CRT = 5.95, T_LEDS = 5.6;

  let R = 0, LEAVING = false;      // idle clock (always forward) and whether we are leaving
  const BAYER = [0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5];
  const clamp = (v,a,b)=> v<a?a:v>b?b:v;
  const sstep = (a,b,v)=>{ const u = clamp((v-a)/(b-a),0,1); return u*u*(3-2*u); };
  const lerp = (a,b,u)=> a+(b-a)*u;
  const easeOut = u=> 1-Math.pow(1-clamp(u,0,1),3);
  function hash(n){ n = (n|0) * 374761393 + 668265263; n = (n ^ (n>>>13)) * 1274126177; n = n ^ (n>>>16); return ((n>>>0) % 100000) / 100000; }

  // ---- the 24 bulbs on the string (4x4 ring + 2x2 core each), found by their ring pattern ----
  const BULB_TL = [[11,33],[99,36],[5,37],[20,38],[92,38],[27,40],[36,43],[7,44],[75,44],[46,45],[56,45],
    [66,45],[98,45],[100,53],[6,54],[98,62],[10,64],[99,70],[9,73],[4,78],[98,80],[8,86],[97,89],[5,97],
    [84,42]];  // the last one sits half behind the wire; the brightness search missed it
  // ---- indicator LEDs, by hand off the picture ----
  const LEDS = [
    {x:289, y:120, col:[255,92,60],  kind:'standby'},          // power strip, red standby: on even in the dark
    {x:293, y:120, col:[110,255,150], kind:'strip'},           // power strip, green: comes on with the power
    {x:312, y:156, col:[110,255,140], kind:'beat'},            // junction box heartbeat
    {x:350, y:127, col:[255,170,70],  kind:'amber'},           // switch box
    {x:352, y:121, col:[255,180,80],  kind:'amber2'},
  ];
  const JB_SCREEN = {x:313, y:142, w:8, h:5};
  const PILLOW_BULBS = [];         // filled in build(): the lowest bulbs on each side
  let refBottom = -1;              // the lower glass's brightness with the plain picture on it
  function baseBottom(){
    let sum = 0;
    for(let y=GH-70; y<GH; y+=2) for(let x=0; x<GW; x+=3){ const j=(y*GW+x)*3; sum += cult[j]+cult[j+1]+cult[j+2]; }
    return sum * 1.02;             // about what vignette and glow leave of it, at rest
  }                  // the junction box's tiny readout

  // 3x5 pixel font for the boot line
  const FONT = {
    'S':'111100111001111','C':'111100100100111','I':'111010010010111','-':'000000111000000',
    'T':'111010010010010','E':'111100110100111','R':'110101110101101','M':'101111111101101',
    '0':'111101101101111','3':'111001011001111','O':'010101101101010','K':'101101110101101',
    'B':'110101110101110',' ':'000000000000000','>':'100010001010100'
  };

  let local, artImg, cultImg;
  let art;            // Float32 rgb of the art (with the lamp bulb painted in)
  let cult;           // Uint8 rgb 150x140 of the mini game frame
  let isGlass, isPort, isUnder;
  let lights = [];    // {x0,y0,w,h,f,col,key}
  let bulbs = [];     // {pix:[[x,y,core]], order, ph, w1, w2, jit, light}
  let stars = [];     // {i, base:[r,g,b], ph, w}
  let lampPix = [];   // [x,y,core]
  let Pr, Pg, Pb;     // per-frame light products
  let off, offc, imgData, out;
  let scr;            // CRT frame buffer, Float32 rgb 150x140
  let SHADE, LIP;         // glass depth: bezel shadow on the glass, inner lip (the fixed reflection is gone, Nov 17)
  // Nov 17 lighting pass (desk_1's approved look): a darker room toward the edges, the lamp as a cone
  // from its dome (arch on the wall, pool on the shelf, haze and dust), the screen's glow sampled off the
  // glass and weighted by the art's own values on the keys and the mug, the mug as a cylinder, clean
  // contact shadows under things, the mug's cast shadow from the lamp, string halos falling down the wall.
  let FA, AO, KEYB, MUG, TONE, KSPEC, coneI, coneV, coneF, KBd = null;
  let SCH = [.55, .95, .9], schN = 0;     // the screen's colour, sampled off the glass and smoothed
  const KB_BOX = [158, 185, 227, 199], MUG_BOX = [268, 179, 288, 199];
  const DEBUG = /bunkdebug/.test(location.search);

  function lum(i){ return (art[i*3]+art[i*3+1]+art[i*3+2])/3; }
  // A prop's own pixels, never the desk or wall that share its box: its body flood-filled from a seed inside
  // it, then the dark outline (lum3 <= lineMax) touching the body, and the dark shading the body encloses
  // (the inside of the rim). Holes that show the shelf (the handle) stay shelf.
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

  // Build one light: fn(x,y) -> 0..1 (continuous shape), quantised to `lv` levels with an
  // ordered dither only near each step edge (k sets how wide the dither seam is).
  function makeLight(key, x0,y0,x1,y1, fn, lv, k, col, opts){
    opts = opts||{};
    x0 = Math.max(0,Math.floor(x0)); y0 = Math.max(0,Math.floor(y0));
    x1 = Math.min(W-1,Math.ceil(x1)); y1 = Math.min(H-1,Math.ceil(y1));
    const w = x1-x0+1, h = y1-y0+1, f = new Float32Array(w*h);
    for(let y=y0;y<=y1;y++) for(let x=x0;x<=x1;x++){
      const i = y*W+x;
      if(isGlass[i] || isPort[i]) continue;
      let v = fn(x+0.5, y+0.5, i);
      if(v<=0) continue;
      if(opts.raw && opts.raw(i)){ f[(y-y0)*w + (x-x0)] = Math.min(v, 1.4) * (opts.top||1); continue; }
      const d = (BAYER[(y&3)*4+(x&3)]+0.5)/16 - 0.5;
      let q = Math.floor(v*lv + 0.5 + d*k) / lv;
      q = clamp(q,0,1) * (opts.top||1);
      f[(y-y0)*w + (x-x0)] = q;
    }
    const L = {key, x0, y0, w, h, f, col};
    lights.push(L);
    return L;
  }
  const plateau = (d,r0,r1)=> d<=r0 ? 1 : d>=r1 ? 0 : 1 - sstep(0,1,(d-r0)/(r1-r0));

  function build(){
    // --- art, with a bulb added in the clip lamp's dark mouth ---
    const c = document.createElement('canvas'); c.width=W; c.height=H;
    const cc = c.getContext('2d'); cc.drawImage(artImg,0,0);
    const d = cc.getImageData(0,0,W,H).data;
    art = new Float32Array(N*3);
    for(let i=0;i<N;i++){ art[i*3]=d[i*4]; art[i*3+1]=d[i*4+1]; art[i*3+2]=d[i*4+2]; }
    // Nov 18 (Jon: "the keyboards still look really bad... flat and dimensionless"): the shelf's keyboard was a
    // brown-grey smear; it is redrawn in code over its footprint (ROOMFX.drawKeyboard): three rows of keycaps
    // with lit tops, dark front lips and gaps, a case with a rim and a front face, a contact shadow
    { const FX = window.ROOMFX;
      const fp = FX.findKeyboard(art, W, H, [[159,187],[225,187],[226,199],[158,199]], [192, 193], 20);
      const deskAt = (x, y) => { for(let r=1;r<12;r++) for(const xx of [x-r, x+r]){ const i = y*W+xx; if(xx>=0 && xx<W && !fp.m[i]) return [art[i*3],art[i*3+1],art[i*3+2]]; } return [115,124,134]; };
      KBd = FX.drawKeyboard(art, W, H, fp, { pal: FX.kbPalette([150,156,164], { amber: [214,150,70] }), lay: FX.KB_COMPACT, seed: 3, desk: deskAt,
        rim: 1, bezel: 0, rows: [[2,1,0],[2,1,0],[2,1,0]], fbezel: 1, face: 1, side: 2, legend: .35, specks: 3 }); }
    // the bulb under the cone shade: the art's own warm pixels (cream core, amber rim)
    lampPix = [];
    for(let y=131;y<=149;y++) for(let x=280;x<=296;x++){   // the bulb and the shade's warm inside lip
      const i=(y*W+x)*3, r=art[i], g=art[i+1], b=art[i+2];
      if(r>=200 && g>=180 && r>b+20) lampPix.push([x,y, b>=180 ? 1 : 0]);
    }

    const c2 = document.createElement('canvas'); c2.width=GW; c2.height=GH;
    const c2c = c2.getContext('2d'); c2c.drawImage(cultImg,0,0);
    const cd = c2c.getImageData(0,0,GW,GH).data;
    cult = new Float32Array(GW*GH*3);
    for(let i=0;i<GW*GH;i++){ cult[i*3]=cd[i*4]; cult[i*3+1]=cd[i*4+1]; cult[i*3+2]=cd[i*4+2]; }
    scr = new Float32Array(GW*GH*3);

    // --- masks ---
    isGlass = new Uint8Array(N); isPort = new Uint8Array(N); isUnder = new Float32Array(N);
    for(let y=GY;y<GY+GH;y++) for(let x=GX;x<GX+GW;x++) isGlass[y*W+x]=1;
    for(let y=30;y<92;y++) for(let x=305;x<366;x++){
      const i=y*W+x, r=Math.hypot(x+.5-PC.x, y+.5-PC.y);
      if(r>PC.r) continue;
      // the inner edge of the frame is neutral grey; the glass is navy (or a star)
      const R=art[i*3],G=art[i*3+1],B=art[i*3+2];
      const navy = B > R+8;
      if(navy || r < PC.r-2.5) isPort[i]=1;
    }
    for(let y=0;y<H;y++) for(let x=DESK_L;x<=DESK_R;x++){
      const i=y*W+x;
      if(y>=DESK_UNDER) isUnder[i]=1; else if(y>=DESK_FRONT) isUnder[i]=0.5;
    }
    for(let y=30;y<92;y++) for(let x=305;x<366;x++){
      const i=y*W+x; if(!isPort[i]) continue;
      if(lum(i) > 70) stars.push({i, base:[art[i*3],art[i*3+1],art[i*3+2]], ph:hash(i)*6.28, w:0.5+hash(i+7)*1.4, bright: lum(i)>150});
    }

    // --- lights (shape only; time multiplies) ---
    // Starlight: a pool round the porthole (frame, shelf, plant, mascot) ...
    makeLight('portpool', PC.x-62, PC.y-62, PC.x+62, PC.y+66, (x,y)=>{
      const r = Math.hypot(x-PC.x, (y-PC.y)*0.92);
      return 0.85*plateau(r, 24, 33) + 0.35*plateau(r, 28, 48);
    }, 3, 0.35, [0.66,0.80,1.0]);
    // ... and the porthole's own shape thrown across the room onto the blanket and pillow.
    const PA = -0.3, ca = Math.cos(PA), sa = Math.sin(PA);
    makeLight('patch', 0, 125, 120, 216, (x,y,i)=>{
      const dx = x-44, dy = y-181;
      const u = (dx*ca + dy*sa)/40, v = (-dx*sa + dy*ca)/12;
      const e = Math.hypot(u,v);
      let f = e<0.72 ? 1 : e>1.08 ? 0 : 1 - (e-0.72)/0.36;
      return f * (1 - 0.7*isUnder[i]);
    }, 3, 0.5, [0.42,0.62,1.0]);

    // ---- masks found in the art: the keyboard and the mug (by colour inside their boxes) ----
    const lumA = i => (art[i*3]+art[i*3+1]+art[i*3+2])/3;
    KEYB = new Uint8Array(N); MUG = new Uint8Array(N); TONE = new Float32Array(N).fill(1);
    for(let y=KB_BOX[1]; y<=KB_BOX[3]; y++) for(let x=KB_BOX[0]; x<=KB_BOX[2]; x++){
      const i = y*W+x; if(y >= 187 || lumA(i) < 150) KEYB[i] = 1;      // the keyboard's body, not the shelf behind it
    }
    // the mug's own pixels, flood-filled from inside it (Nov 17, Jon: "boxy background"): the colour rule over
    // its whole box also took the warm shadow painted beside it and the dark wall strip over its rim, which
    // were lit as the mug and threw the mug's cast shadow as a box
    MUG = propMask(MUG_BOX, [277,190], i => art[i*3] >= art[i*3+2] - 2 && lumA(i) >= 36, lumA, 20);
    for(let i=0;i<N;i++) if(KEYB[i] || MUG[i]) TONE[i] = 0.4 + 0.8*clamp((lumA(i)-55)/110, 0, 1);
    KSPEC = [];
    for(let y=KB_BOX[1]+1; y<=KB_BOX[3]; y++) for(let x=KB_BOX[0]; x<=KB_BOX[2]; x++){
      const i = y*W+x; if(KEYB[i] && lumA(i) >= 105 && lumA(i) - lumA(i-W) >= 22) KSPEC.push(i);
    }
    KSPEC = Int32Array.from(KSPEC);
    const BAYF = (x,y)=> (BAYER[(y&3)*4+(x&3)]+0.5)/16;

    // ---- the lamp: a cone from the dome's mouth, down and to the left ----
    // The bulb sits in the dome a few px in front of the wall; the cone meets the wall in an arch and
    // the shelf in an elliptical pool round where its axis lands. Outside the cone only a faint spill.
    const AX = (()=>{ const v=[-0.5, 0.8, 0.33], l=Math.hypot(...v); return v.map(c=>c/l); })();
    const cosIn = Math.cos(33*Math.PI/180), cosOut = Math.cos(44*Math.PI/180);
    const coneAt = (x, y, dz) => {
      const vx = x-LAMP.x, vy = y-LAMP.y, vz = dz, dd = Math.hypot(vx,vy,vz)||1;
      const cs = (vx*AX[0] + vy*AX[1] + vz*AX[2])/dd;
      return { a: cs>=cosIn ? 1 : cs<=cosOut ? 0 : (cs-cosOut)/(cosIn-cosOut), dd };
    };
    const POOL = {x:254, y:191};
    // the mug's shadow on the shelf, from three samples across the bulb (soft, one clean shape)
    const LXS = [282, 285, 288, 291, 294];
    const mugShadow = (x, y) => {
      if(y < 181 || y > 199 || x > 272 || x < 215) return 1;
      let vis = 0;
      for(const sx of LXS){
        const dx = sx-x, dy = LAMP.y-y, d = Math.hypot(dx,dy), ux = dx/d, uy = dy/d;
        let hit = false;
        for(let k=1; k<=Math.min(40,d); k++){ const px=Math.round(x+ux*k), py=Math.round(y+uy*k); if(MUG[py*W+px] && py >= 181){ hit = true; break; } }
        if(!hit) vis++;
      }
      const q = Math.floor(vis/LXS.length*3 + BAYF(x,y)*0.999)/3;
      return 0.32 + 0.68*q;
    };
    const lampShape = (x, y, i) => {
      const u = isUnder[i];
      let f;
      if(y < 182 || x > 296){
        const onCase = x >= 105 && x <= 280 && y >= 8 && y <= 180;
        const c = coneAt(x, y, onCase ? -4 : -10);
        f = c.a * (0.55*plateau(c.dd, 10, 34) + 0.45*plateau(c.dd, 20, 80));
        if(c.a <= 0) f = 0.05*plateau(c.dd, 4, 22);          // a faint spill round the head only
        if(onCase) f *= 0.25 * sstep(128, 172, y);            // the case only takes it at a grazing angle, most low down
      } else {
        const c = coneAt(x, y, 14);
        const dp = Math.hypot(x-POOL.x, (y-POOL.y)*2.4);
        f = Math.max(0.15, c.a) * (0.55*plateau(dp, 14, 36) + 0.45*plateau(dp, 26, 78));
        f *= mugShadow(x, y);
      }
      if(u) f *= (u>=1 ? 0.1 : 0.55);
      return f;
    };
    // things read the light at their own feet, then by the art's own value and their shape
    const MUG_C = 277.5, mugCyl = (x, side) => {      // side -1: lit from the left (screen); +1 from the right (lamp)
      if(x >= 284) return side > 0 ? 0.95 : 0.6;      // the handle
      const nx = (x - MUG_C)/8.5 * side;
      return nx > 0.35 ? 1.25 : nx > -0.3 ? 1.0 : 0.72;
    };
    const lampFootM = lampShape(276, 197, 197*W+276);
    makeLight('lampcone', 96, 110, 330, 216, (x,y,i)=>{
      if(MUG[i]) return lampFootM * mugCyl(x|0, 1) * TONE[i];
      return lampShape(x, y, i);
    }, 5, 0.35, [1,1,1], {raw: i => MUG[i]===1});

    // CRT spill: strongest onto the desk and keyboard in front of the glass.
    const crtShape = (x, y, i) => {
      const dx = Math.max(GX-x, 0, x-(GX+GW)), dy = Math.max(GY-y, 0, y-(GY+GH));
      const dd = Math.hypot(dx, dy);
      if(dd<=0) return 0;
      const below = sstep(GY+GH-14, GY+GH+8, y);
      let f = below * (0.6*plateau(dd, 4, 30) + 0.4*plateau(dd, 18, 62)) + (1-below) * 0.4 * plateau(dd, 1, 10);   // reaches the keys and the mug
      if(x >= 105 && x <= 278 && y >= GY+GH+6 && y <= 180) f = Math.max(f * 0.35, 0.12);   // the chin: a gentle lift
      const u = isUnder[i]; if(u) f *= (u>=1 ? 0.08 : 0.6);
      return f;
    };
    const crtFootK = crtShape(192, 190, 190*W+192), crtFootM = crtShape(272, 186, 186*W+272) * 1.2;   // read where each stands
    makeLight('crt', GX-44, GY-30, GX+GW+44, H-1, (x,y,i)=>{
      if(KEYB[i]) return crtFootK * TONE[i];
      if(MUG[i]) return crtFootM * mugCyl(x|0, -1) * TONE[i];
      return crtShape(x, y, i);
    }, 3, 0.35, [0.62,0.92,0.95], {raw: i => KEYB[i]===1 || MUG[i]===1});

    // ---- the air in the lamp's cone: a faint warm haze (smooth inside, dithered edge), and dust ----
    const ci = [], cv = []; coneF = new Float32Array(N);
    for(let y=134; y<=200; y++) for(let x=200; x<=300; x++){
      const i = y*W+x; if(isGlass[i] || MUG[i]) continue;
      const vx = x-LAMP.x, vy = y-LAMP.y, dd = Math.hypot(vx, vy);
      if(dd < 3) continue;
      const cs2 = (vx*(-0.548) + vy*0.837)/dd;                 // in the picture plane: the cone's own angle
      // Nov 17: 22 deg, not 30. At 30 the cone's right edge ran straight down beside the dark panel under the
      // lamp, so the haze showed only on that panel, as a lit box; now its edge crosses the panel as a wedge
      const e = (cs2 - Math.cos(22*Math.PI/180))/0.04 + 0.5;
      if(!(e >= 1 || (e > 0 && e > BAYF(x,y)))) continue;
      const v = Math.pow(clamp(1 - dd/56, 0, 1), 1.4); if(v <= 0.02) continue;
      coneF[i] = v; ci.push(i); cv.push(v);
    }
    coneI = Int32Array.from(ci); coneV = Float32Array.from(cv);

    // ---- contact shadows: one row (two, dithered, under the heavier things) where an outline meets the shelf ----
    AO = new Float32Array(N).fill(1);
    for(const [x0, x1, yh, rows] of [[270, 283, 198, 2], [159, 226, 199, 2], [107, 155, 199, 1]]) for(let x=x0; x<=x1; x++){
      for(let y=yh-4; y<=yh+3 && y<H-1; y++){
        const i = y*W+x;
        if(lumA(i-W) < 48 && lumA(i) >= 55 && !MUG[i] && !KEYB[i]){
          AO[i] = Math.min(AO[i], 0.74);
          if(rows > 1 && BAYF(x, y+1) < 0.5) AO[i+W] = Math.min(AO[i+W], 0.88);
          break;
        }
      }
    }
    // ---- the room darker toward its edges and top, in dithered steps ----
    FA = new Float32Array(N);
    for(let y=0;y<H;y++) for(let x=0;x<W;x++){
      const q = ((x-200)/235)**2 + ((y-125)/150)**2 + (BAYF(x,y)-0.5)*0.1;
      FA[y*W+x] = q < .5 ? 1 : q < .8 ? .86 : q < 1.15 ? .72 : .6;   // lifted: a cosy cabin, not a cave
    }

    // String lights: each bulb a small bright pool; together they warm the photo wall.
    const order = BULB_TL.map(([x,y],k)=>{
      const cx=x+0.5, cy=y+1.5;
      let s;                                   // position along the wire: left side up, across, right side down
      if(cx < 16) s = 200 - cy;                // left column, bottom to top
      else if(cx < 95 || (cx<99 && cy<42)) s = 200 + cx;   // the swag
      else s = 400 + cy;                       // right column, top to bottom
      return {k,s};
    }).sort((a,b)=>a.s-b.s);
    BULB_TL.forEach(([x,y],k)=>{
      const cx=x+0.5, cy=y+1.5;
      const pix = [[x,y,0],[x+1,y,0],[x-1,y+1,0],[x,y+1,1],[x+1,y+1,1],[x+2,y+1,0],[x-1,y+2,0],[x,y+2,1],[x+1,y+2,1],[x+2,y+2,0],[x,y+3,0],[x+1,y+3,0]];
      const L = makeLight('bulb'+k, cx-16, cy-12, cx+16, cy+26, (px,py)=>{
        const dd = Math.hypot(px-cx, (py-cy)*(py > cy ? 0.62 : 1.1));   // the halo falls down the wall
        return 0.55*plateau(dd, 2.5, 6.5) + 0.45*plateau(dd, 5, 15);
      }, 3, 0.35, [1.0,0.80,0.52]);
      bulbs.push({pix, order: order.findIndex(o=>o.k===k), ph:hash(k*31+3)*6.283, ph2:hash(k*17+5)*6.283,
        w1:0.55+hash(k*13+1)*0.9, w2:1.7+hash(k*7+2)*1.6, jit:hash(k*5+9), light:L});
    });
    BULB_TL.forEach(([x,y],k)=>{ if(y >= 78) PILLOW_BULBS.push(k); });
    // A broad warm wash from the whole string, reaching the pillow.
    makeLight('wash', 0, 0, 160, 200, (x,y)=>{
      // centred on the photos, falling off in round contours; its last step reaches the pillow
      const dd = Math.hypot((x-50)/66, (y-64)/62);
      return 0.6*plateau(dd, 0.5, 1.35);
    }, 3, 0.35, [1.0,0.78,0.5]);
    // The pillow's top catches the string's light as one even glow (a step across it read as a stain),
    // ending where the pillow meets the blanket.
    makeLight('pillow', 10, 112, 104, 170, (x,y)=>{
      const fy = 1 - sstep(150, 162, y), fx = sstep(12, 22, x) * (1 - sstep(92, 102, x));
      return fy * fx * sstep(112, 122, y);
    }, 2, 0.5, [1.0,0.78,0.5], {top:0.45});
    // The strings are the bunk's main warm light: a broad glow over the bed and blanket from the
    // right-hand column of bulbs and the swag above, falling off toward the floor and the left edge.
    makeLight('bedglow', 0, 90, 140, 216, (x,y)=>{
      const dd = Math.hypot((x-62)/78, (y-128)/64);
      return 0.5*plateau(dd, 0.35, 1.25) + 0.25*plateau(dd, 0.2, 0.6);
    }, 4, 0.35, [1.0,0.76,0.48]);

    // LEDs: tiny coloured pools
    for(const L of LEDS){
      L.light = makeLight('led', L.x-4, L.y-4, L.x+4, L.y+4, (x,y)=>{
        const dd = Math.hypot(x-(L.x+.5), y-(L.y+.5));
        return dd<0.8 ? 0 : 0.6*plateau(dd, 1, 3.2);
      }, 3, 0.6, L.col.map(v=>0.35+0.65*v/255));
    }
    // the junction box readout lights its bezel a touch
    JB_SCREEN.light = makeLight('jb', JB_SCREEN.x-3, JB_SCREEN.y-3, JB_SCREEN.x+JB_SCREEN.w+3, JB_SCREEN.y+JB_SCREEN.h+3, (x,y)=>{
      const dx = Math.max(JB_SCREEN.x-x,0,x-(JB_SCREEN.x+JB_SCREEN.w)), dy = Math.max(JB_SCREEN.y-y,0,y-(JB_SCREEN.y+JB_SCREEN.h));
      const dd = Math.hypot(dx,dy); return dd<=0 ? 0 : 0.5*plateau(dd,0.5,2.6);
    }, 2, 0.5, [0.5,1,0.9]);

    SHADE = new Float32Array(GW*GH);
    for(let y=0;y<GH;y++) for(let x=0;x<GW;x++) SHADE[y*GW+x] = glassShade(x,y);
    // the bezel's inner lip (monitor A's step): bottom and right faces catch the light, top and left
    // sit in shadow, as the art draws them;
    // the screen's glow also bleeds onto the lip (index of the nearest glass pixel).
    LIP = [];
    for(let y=GY-2; y<GY+GH+2; y++) for(let x=GX-2; x<GX+GW+2; x++){
      if(x>=GX && x<GX+GW && y>=GY && y<GY+GH) continue;
      const gx = clamp(x, GX, GX+GW-1), gy = clamp(y, GY, GY+GH-1);
      const d = Math.max(Math.abs(x-gx), Math.abs(y-gy));
      let face = 0;
      if(x >= GX+GW && y >= GY && y < GY+GH) face = d===1 ? 0.6 : 0.3;   // right lip: lit
      else if(y >= GY+GH && x >= GX && x < GX+GW) face = d===1 ? 0.8 : 0.4; // bottom lip: lit
      else if(y < GY) face = -0.45; else if(x < GX) face = -0.3;         // top, left: shadow
      LIP.push({i: y*W+x, g: (gy-GY)*GW + (gx-GX), d, face});
    }
    buildC();
    buildGlitches();
    Pr = new Float32Array(N); Pg = new Float32Array(N); Pb = new Float32Array(N);
    off = document.createElement('canvas'); off.width=W; off.height=H;
    offc = off.getContext('2d');
    imgData = offc.createImageData(W,H); out = imgData.data;
    for(let i=0;i<N;i++) out[i*4+3]=255;
  }

  // ---------- C LIGHTING (Jon's pick, Nov 18; desk 1's, on the shared engine ROOMFX.makeLit) ----------
  // The old fields here were clipped to boxes: the strings' broad wash stopped at x 160 and their glow on the bed at
  // x 140 (straight vertical edges across the wall and the blanket), the shelf's shadow was a rectangle (x 95-291),
  // and the lamp switched shape at row 182. Now every light falls off by distance and angle from its source in the
  // room's own space (the shelf faces up, the bed's top faces up and comes toward you, the wall faces you), props
  // are flood-filled, and the C ramp steps the summed light. Each light keeps [steady, flicker].
  let LIT = null, CCB = {}, FLD = {}, SMALL = [], NB = 0, NL = 0, DUSTC = null, SKY = null, Lc = null, A2 = null, portIdx = [];
  function buildC(){
    const FX = window.ROOMFX, D2R = Math.PI/180, L = i => 0.3*art[i*3]+0.59*art[i*3+1]+0.11*art[i*3+2];
    const MON = FX.propMask(art, W, H, [104, 6, 279, 186], [110, 100], i => { const x = i%W, y = (i/W)|0;
      return !isGlass[i] && L(i) >= 50 && (y <= 176 || (x >= 178 && x <= 208)); }, 26);
    const skip = new Uint8Array(N); for(let i=0;i<N;i++) if(isGlass[i] || isPort[i]){ skip[i] = 1; if(isPort[i]) portIdx.push(i); }
    LIT = FX.makeLit({ W, H, A: art, skip, deskY: 181, deskF: 200, kz: 3, kb: KBd,
      surf: (x, y) => (x >= DESK_L && x <= DESK_R) ? (y < 181 ? 0 : y <= 200 ? 1 : 2) : 0,
      // the bed's top faces up and comes toward you; under the shelf is the wall in the shelf's shadow
      geo: (x, y) => x < DESK_L - 2 && y >= 141 ? [(y - 141)*3, 40, 0, 1, 0, 1]
                   : (x >= DESK_L && x <= DESK_R && y >= DESK_UNDER) ? [0, 181 - y, 0, 0, 1, .3] : null,
      props: [ { m: MON, foot: 182, deep: 2, up: .15, contact: false, bounce: .25, wrap: 0, gain: .6 },   // 0 the monitor
               { m: MUG, foot: 198, heavy: true, cyl: true, up: .2, bounce: .9 } ] });  // 1 the mug
    const ax = [-0.5, -0.8, 0.33], al = Math.hypot(...ax);
    FLD.lamp = LIT.norm(LIT.point({ x: LAMP.x, y: LAMP.y - 2, z: 10, I: 1, r0: 34, rMax: 300, axis: ax.map(v=>v/al),
      cosIn: Math.cos(30*D2R), cosOut: Math.cos(50*D2R), spill: 0, wrap: .15, occ: [0, 1], spread: 8, samples: 5 }), 254, 191, 1);
    FLD.scr = LIT.norm(LIT.panel({ rect: [118,23,265,160], z: 2, I: 1, r0: 200, rMax: 380, nx: 6, ny: 4, wrap: .1, occ: [1] }), 150, 196, .8);
    FLD.port = LIT.norm(LIT.panel({ rect: [311,36,359,84], z: 3, I: 1, r0: 34, rMax: 170, nx: 4, ny: 4, wrap: .6, disc: true }), 335, 92, .22);
    // the starlight's own shape thrown across the room onto the blanket (as before: a soft rotated ellipse)
    const pl = (d, r0, r1) => d <= r0 ? 1 : d >= r1 ? 0 : 1 - sstep(0, 1, (d - r0)/(r1 - r0));
    FLD.patch = new Float32Array(N); FLD.pillow = new Float32Array(N); FLD.ring = new Float32Array(N);
    // the whole string's warm wash on the photo wall it frames (an ellipse over the whole picture, never clipped)
    FLD.wash = new Float32Array(N);
    const PA = -0.3, ca = Math.cos(PA), sa = Math.sin(PA);
    for(let y=0;y<H;y++) for(let x=0;x<W;x++){ const i = y*W+x; if(skip[i]) continue;
      const dx = x+.5-44, dy = y+.5-181, u = (dx*ca + dy*sa)/40, v = (-dx*sa + dy*ca)/12, e = Math.hypot(u, v);
      { const rr = Math.hypot(x+.5-PC.x, (y+.5-PC.y)*0.92); FLD.ring[i] = (.85*pl(rr, 24, 33) + .35*pl(rr, 28, 48))*LIT.AO[i]; }   // starlight round the porthole's ring
      FLD.wash[i] = .6*pl(Math.hypot((x+.5-50)/66, (y+.5-64)/62), .5, 1.35)*LIT.AO[i];
      FLD.patch[i] = .54*(e < .72 ? 1 : e > 1.08 ? 0 : 1 - (e - .72)/.36) * LIT.AO[i];
      // the pillow's top catches the string's light as one even glow
      FLD.pillow[i] = .45*(1 - sstep(150, 162, y+.5))*sstep(12, 22, x+.5)*(1 - sstep(92, 102, x+.5))*sstep(112, 122, y+.5); }
    // string bulbs: each a small point a few px off the wall, its halo falling further down than up
    SMALL = bulbs.map((b, n) => { const [x, y] = BULB_TL[n];
      const q = LIT.pointBox({ x: x + 1, y: y + 2, z: 5, I: 1, r0: 5, rMax: 24, wrap: .45, squash: .62, bounce: false });
      let mx = 0; for(const v of q.f) mx = Math.max(mx, v); if(mx > 0) for(let k=0;k<q.f.length;k++) q.f[k] *= .55/mx;
      q.tint = [1, .82, .58]; return q; });
    NB = SMALL.length;
    // LEDs and the junction box's readout: tiny coloured pools
    for(const Ld of LEDS){ const q = LIT.pointBox({ x: Ld.x + .5, y: Ld.y + .5, z: 2, I: 1, r0: 1.6, rMax: 6, wrap: .8, bounce: false });
      let mx = 0; for(const v of q.f) mx = Math.max(mx, v); if(mx > 0) for(let k=0;k<q.f.length;k++) q.f[k] *= .5/mx;
      q.tint = Ld.col.map(v => .35 + .65*v/255); SMALL.push(q); }
    { const q = LIT.pointBox({ x: JB_SCREEN.x + JB_SCREEN.w/2, y: JB_SCREEN.y + JB_SCREEN.h/2, z: 2, I: 1, r0: 4, rMax: 9, wrap: .8, bounce: false });
      let mx = 0; for(const v of q.f) mx = Math.max(mx, v); if(mx > 0) for(let k=0;k<q.f.length;k++) q.f[k] *= .4/mx;
      q.tint = [.5, 1, .9]; SMALL.push(q); }
    NL = LEDS.length;
    A2 = FX.settleDust(art, W, H, { seed: 5, density: .045, amount: .2,
      mask: (x, y) => { const i = y*W+x; return x >= DESK_L && x <= DESK_R && y >= 182 && y <= 200 && !KBd.part[i] && !MUG[i] && L(i) > 45 && L(i) < 205; } });
    DUSTC = FX.makeDust({ W, H, count: 140, seed: 7, box: [2, 4, 380, 212],
      density: (x, y) => { const i = y*W+x; return .1 + .9*clamp(FLD.lamp[i]*.9 + FLD.scr[i]*1.1 + FLD.patch[i], 0, 1); }, skip: i => isGlass[i] === 1 });
    SKY = FX.makeSky({ W, idx: portIdx, cx: PC.x, cy: PC.y, r: 23, seed: 3 });
    (window.__C = window.__C || {}).bunk_1 = { LIT, FLD, KB: KBd };
    Lc = new Float32Array(N*3);
  }

  function apply(L, m, cr, cg, cb){
    if(m <= 0.002) return;
    const {x0,y0,w,h,f} = L;
    for(let yy=0; yy<h; yy++){
      let i = (y0+yy)*W + x0, j = yy*w;
      for(let xx=0; xx<w; xx++, i++, j++){
        const v = f[j]; if(v===0) continue;
        const s = v*m;
        Pr[i] *= 1 - Math.min(0.97, s*cr); Pg[i] *= 1 - Math.min(0.97, s*cg); Pb[i] *= 1 - Math.min(0.97, s*cb);
      }
    }
  }

  // ---- clocks ----
  function lampLevel(t){
    const a = t - T_LAMP;
    if(a < 0) return 0;
    // click, filament stutter, then it settles and warms
    if(a < 0.05) return 0.55;
    if(a < 0.11) return 0.06;
    if(a < 0.20) return 0.7;
    if(a < 0.26) return 0.22;
    const u = easeOut((a-0.26)/0.75);
    let breathe = 1 + 0.04*Math.sin(R*1.3) + 0.02*Math.sin(R*3.1+1.2);
    // Nov 17 (desk_1's flicker): the filament wavers on two irregular clocks, and every 7-13 s eases
    // down 6-9% for about half a second
    breathe *= 1 + 0.022*vnoise(R*1.7, 61) + 0.012*vnoise(R*4.3, 67);
    { const P = 10, ci = Math.floor(R/P), at = 1.5 + hash(ci*39+1)*6, q = R - ci*P - at, len = 0.45 + hash(ci*22)*0.25;
      if(q > 0 && q < len) breathe *= 1 - (0.06 + hash(ci*71)*0.03)*Math.sin(Math.PI*q/len); }
    return lerp(0.45, 1, u) * (a > 1.0 ? breathe * lampBrown(R) : 1);
  }
  function vnoise(t, seed){ const i = Math.floor(t), f = t - i, u = f*f*(3-2*f); return lerp(hash(i*191+seed*7), hash((i+1)*191+seed*7), u)*2 - 1; }
  // A rare brown-out: the filament sags 15-25% for a fraction of a second, wavers once, recovers.
  // About one slot in two (slots of 10 s) has one; the first comes a few seconds into the idle.
  function lampBrown(t){
    const slot = 10, k = Math.floor((t - 9)/slot);
    if(k < 0) return 1;
    if(k > 0 && hash(k*71+5) > 0.5) return 1;
    const at = 9 + k*slot + (k===0 ? 3.2 : 1 + 7*hash(k*37+2));
    const q = t - at;
    if(q < 0 || q > 0.75) return 1;
    const depth = 0.15 + 0.1*hash(k*13+9);
    const env = q < 0.08 ? q/0.08 : q < 0.42 ? 1 : 1 - sstep(0.42, 0.75, q);
    const waver = Math.max(0, Math.sin((q-0.08)*Math.PI/0.17));      // one small wobble in the sag
    return 1 - depth*env*(1 - 0.3*waver);
  }
  function lampWarmth(t){
    const w = sstep(0, 1.4, t - T_LAMP);           // 0 = deep orange filament, 1 = warm amber
    // idle: a slow drift between warmer and a touch cooler, and warmer while it sags
    const drift = 0.12*Math.sin(R*0.23 + 0.7) + 0.06*Math.sin(R*0.61);
    const sag = (1 - lampBrown(R)) * 2.2;
    return clamp(w*(0.9 + drift) - sag, 0, 1.08);
  }

  function bulbLevel(b, t){
    const a = t - (T_STRING + b.order*0.058 + b.jit*0.035);
    if(a < 0) return 0;
    let v;
    if(a < 0.06) v = 0.3;                       // the first glow of the filament
    else v = lerp(0.3, 1, easeOut((a-0.06)/0.4));
    if(b.jit < 0.3 && a > 0.14 && a < 0.2) v *= 0.45;    // a few stutter once on the way up
    // idle: each bulb breathes on its own two clocks, never in step with its neighbours
    const tw = (1 + 0.13*Math.sin(R*b.w1 + b.ph) + 0.07*Math.sin(R*b.w2 + b.ph2)) * stringSwell(R, b.order);
    // and now and then one dips, briefly and gently
    const slot = 9 + b.jit*7, k = Math.floor((R + b.ph)/slot);
    let dip = 1;
    if(hash(k*97 + b.order*13) < 0.3){
      const at = (k + 0.2 + 0.6*hash(k*41 + b.order)) * slot - b.ph;
      const q = (R - at)/0.5;
      if(q>0 && q<1) dip = 1 - 0.42*Math.sin(q*Math.PI);
    }
    return v * tw * dip;
  }

  // Every so often a slow swell of brightness travels along the wire, from the bottom of the left
  // side, over the top, down the right: about 4 bulbs a second, ~5 bulbs wide. Each bulb keeps
  // its own clock on top.
  function stringSwell(t, order){
    const slot = 11, k = Math.floor((t - 9)/slot);
    if(k < 0) return 1;
    let v = 1;
    for(const kk of [k-1, k]){
      if(kk < 0) continue;
      if(kk > 0 && hash(kk*53+11) > 0.7) continue;
      const at = 9 + kk*slot + (kk===0 ? 1.0 : 2*hash(kk*19+4));
      const head = (t - at) * 4.2 - 4;               // where the swell is along the wire, in bulbs
      const d = (order - head) / 2.6;
      if(Math.abs(d) < 3) v += 0.32*Math.exp(-d*d);
    }
    return v;
  }
  // Something drifting past outside catches the star's light: a small glint crosses the porthole
  // and the starlight on the blanket swells with it.
  function passing(t){
    const slot = 16, k = Math.floor((t - 10)/slot);
    if(k < 0) return null;
    if(k > 0 && hash(k*89+3) > 0.65) return null;
    const at = 10 + k*slot + (k===0 ? 2.5 : 1 + 8*hash(k*23+6));
    const q = (t - at) / 5.5;                        // 5.5 s to cross
    if(q < 0 || q > 1) return null;
    const ang = -0.5 + hash(k*31+1)*0.6;             // a shallow path, mostly sideways
    const x = PC.x - 30*Math.cos(ang) + 60*Math.cos(ang)*q;
    const y = PC.y - 6 - 30*Math.sin(ang) + 60*Math.sin(ang)*q + 8*hash(k*7);
    return {g: Math.sin(q*Math.PI), x: Math.round(x), y: Math.round(y)};
  }

  // ---- the old monitor's glitches: one at a time, every 3-8 s, each brief and each different ----
  let GLITCH = null, gIdx = 0;
  function buildGlitches(){
    GLITCH = [];
    let at = T_CRT + CRT_ON + 1.6, ki = 0;
    const KINDS = ['jitter','split','jitter','split','vhold'];   // static band removed (Jon)   // the hiccup is the rare one
    for(let n=0; n<4000; n++){
      ki = (ki + 1 + Math.floor(hash(n*157+11)*2)) % KINDS.length;      // never the same twice running
      const kind = KINDS[ki];
      const dur = kind==='jitter' ? 0.3 : kind==='split' ? 0.08 : kind==='static' ? 0.75 : 0.34;
      GLITCH.push({at, kind, dur, n, y0: 8 + Math.floor(hash(n*29+3)*112), rows: 3 + Math.floor(hash(n*43+1)*4)});
      at += dur + 3 + 5*hash(n*61+7);
    }
  }
  function glitchAt(t){
    if(gIdx >= GLITCH.length || GLITCH[gIdx].at > t) gIdx = 0;
    while(gIdx+1 < GLITCH.length && GLITCH[gIdx+1].at <= t) gIdx++;
    const e = GLITCH[gIdx];
    return (t >= e.at && t < e.at + e.dur) ? e : null;
  }

  // Nov 17 (Jon: "the opening sequence for the screen could be a bit slower. Maybe with a title screen"):
  // the warm-up (dot, line, raster, boot line) runs 1.5x longer, then the game's title card holds
  // (DESK.TITLE.hold), then wipes into the game, which settles. Leaving keeps its old collapse, no card.
  const WARM = 1.5, CRT_BOOT_END = 1.75*WARM, CRT_TITLE_END = CRT_BOOT_END + DESK.TITLE.hold,
        CRT_WIPE_END = CRT_TITLE_END + DESK.TITLE.wipe, CRT_ON = CRT_WIPE_END + 0.5;
  function crtState(t){
    const p = t - T_CRT;
    if(p < 0) return {phase:'off', p, po:p, level:0};
    if(LEAVING && p >= 0.32 && p < 2.45) return {phase:'collapse', p, po:p, level: lerp(0.18, 1, sstep(0.4, 1.9, p))};
    if(LEAVING && p >= 2.45) return {phase:'on', p, po:p, level:1};
    const po = p / WARM;                                   // the old warm-up's own clock, 1.5x slower
    if(LEAVING && p < 0.32){ const pl = p; return pl < 0.12 ? {phase:'dot', p, po:pl, level:0.12} : {phase:'line', p, po:pl, level:0.2}; }
    if(po < 0.12) return {phase:'dot', p, po, level:0.12};
    if(po < 0.32) return {phase:'line', p, po, level:0.2};
    if(po < 0.62) return {phase:'open', p, po, level:0.45 - 0.2*(po-0.32)/0.3};
    if(po < 1.75) return {phase:'boot', p, po, level:0.2};
    if(p < CRT_TITLE_END) return {phase:'title', p, po, level:0.45};
    if(p < CRT_WIPE_END) return {phase:'wipe', p, po, level:lerp(0.45, 1, (p-CRT_TITLE_END)/DESK.TITLE.wipe)};
    if(p < CRT_ON) return {phase:'settle', p, po, level:1};
    return {phase:'on', p, po, level:1};
  }

  // ---- the screen ----
  function putGlyphs(str, x0, y0, col, upTo){
    let x = x0;
    for(let n=0; n<str.length && n<upTo; n++){
      const g = FONT[str[n]] || FONT[' '];
      for(let r=0;r<5;r++) for(let c=0;c<3;c++) if(g[r*3+c]==='1'){
        const j = ((y0+r)*GW + x+c)*3; scr[j]=col[0]; scr[j+1]=col[1]; scr[j+2]=col[2];
      }
      x += 4;
    }
    return x;
  }
  function drawScreen(t, st){
    scr.fill(0);
    const p = st.po, ph = st.phase;
    const PH = [120,235,200];
    if(ph==='off') return;
    if(ph==='dot'){
      const k = sstep(0,0.08,p);
      const cx=74, cy=69;
      for(let y=cy-1;y<=cy+2;y++) for(let x=cx-1;x<=cx+2;x++){
        const core = (x===cx||x===cx+1)&&(y===cy||y===cy+1);
        const v = core ? 255*k : 70*k, j=(y*GW+x)*3;
        scr[j]=v*0.85; scr[j+1]=v; scr[j+2]=v;
      }
      return;
    }
    if(ph==='line'){
      const u = easeOut((p-0.12)/0.2), half = Math.max(2, Math.round(75*u));
      for(let x=75-half;x<75+half;x++){
        if(x<0||x>=GW) continue;
        for(let y=68;y<=71;y++){
          const v = (y===69||y===70) ? 245 : 60, j=(y*GW+x)*3;
          scr[j]=v*0.85; scr[j+1]=v; scr[j+2]=v;
        }
      }
      return;
    }
    if(ph==='open'){
      const u = easeOut((p-0.32)/0.3), half = Math.max(2, Math.round(70*u));
      const fr = Math.floor(p*15);              // snow changes at 15 a second
      const fade = 1 - 0.65*u;
      for(let y=70-half;y<70+half;y++){
        if(y<0||y>=GH) continue;
        const nearLine = Math.abs(y-69.5) < 2 ? (1-u) : 0;
        for(let x=0;x<GW;x++){
          const n = hash(x*7 + y*1031 + fr*7919);
          const v = (25 + 70*n*n)*fade + 200*nearLine, j=(y*GW+x)*3;
          scr[j]=v*0.8; scr[j+1]=v; scr[j+2]=v*0.95;
        }
      }
      return;
    }
    if(ph==='boot'){
      // a faint lit raster, the boot line typed in, a blinking cursor
      for(let j=0;j<GW*GH;j++){ scr[j*3]=6; scr[j*3+1]=14; scr[j*3+2]=13; }
      const a = p - 0.72;
      const n1 = a<0 ? 0 : Math.floor(a/0.055)+1;
      let cx = putGlyphs('SCI-TERM 03', 6, 7, PH, n1);
      let cy = 7;
      if(a > 0.75){ const n2 = Math.floor((a-0.75)/0.07)+1; cx = putGlyphs('BOOT OK', 6, 15, PH, n2); cy = 15; }
      if(Math.floor(p*3) % 2 === 0 && a > -0.3){
        for(let y=cy;y<cy+5;y++) for(let x=cx;x<cx+3;x++){ const j=(y*GW+x)*3; scr[j]=PH[0]*0.8; scr[j+1]=PH[1]*0.8; scr[j+2]=PH[2]*0.8; }
      }
      return;
    }
    if(ph==='collapse'){
      // switching off: the picture squeezes to the centre line, brightening as it goes
      const k = sstep(0.4, 1.9, p), half = Math.max(1, Math.round(70*k));
      const boost = 1 + 0.9*(1-k);
      for(let y=70-half; y<70+half; y++){
        if(y<0||y>=GH) continue;
        const sy = clamp(Math.floor((y-(70-half)) * GH/(2*half)), 0, GH-1);
        for(let x=0;x<GW;x++){
          const j=(y*GW+x)*3, s2=(sy*GW+x)*3;
          if(half <= 2){ scr[j]=210; scr[j+1]=245; scr[j+2]=240; continue; }
          scr[j]=Math.min(255,cult[s2]*boost); scr[j+1]=Math.min(255,cult[s2+1]*boost); scr[j+2]=Math.min(255,cult[s2+2]*boost);
        }
      }
      return;
    }
    if(ph==='title'){ DESK.titleCard(scr, st.p - CRT_BOOT_END, 0); return; }
    // wipe / settle / on: the picture (the title's wipe brings it in; it settles a touch bright)
    let off = 0, bright = 1;
    if(ph==='settle') bright = lerp(1.15, 1, (st.p - CRT_WIPE_END)/0.5);
    for(let y=0;y<GH;y++){
      let sy = y - off;
      const seam = false;
      sy = ((sy % (GH+6)) + (GH+6)) % (GH+6);
      for(let x=0;x<GW;x++){
        const j=(y*GW+x)*3;
        if(seam){ scr[j]=3; scr[j+1]=5; scr[j+2]=6; continue; }
        const s=(sy*GW+x)*3;
        scr[j]=cult[s]*bright; scr[j+1]=cult[s+1]*bright; scr[j+2]=cult[s+2]*bright;
      }
    }
    if(ph==='wipe') DESK.titleCard(scr, st.p - CRT_BOOT_END, (st.p - CRT_TITLE_END)/DESK.TITLE.wipe);
  }
  // The old monitor on top of whatever is on the glass. Returns what the desk light should do:
  // {flick: the fast 1-3% flicker (not amplified), spill: glitch effect on the spill}.
  let crtWobble = 1;
  const gl = new Float32Array(GW*GH*3), tmp = new Float32Array(GW*GH*3);
  function crtFilter(t, st){
    const on = st.phase==='on' || st.phase==='settle' || st.phase==='wipe' || st.phase==='title' || st.phase==='boot' || st.phase==='collapse';
    const live = st.phase==='on';
    // the old supply wanders: the whole picture brightens and dims a few percent, slowly
    crtWobble = live ? 1 + 0.035*Math.sin(t*0.37 + 1) + 0.02*Math.sin(t*1.05) : 1;
    // and a faint quick flicker on its own irregular clock (1-2%)
    const flick = on ? 1 + 0.011*Math.sin(t*5.3)*Math.sin(t*1.9+1) + 0.007*Math.sin(t*8.7+2)*Math.sin(t*0.7) : 1;
    let spill = 1;
    const e = live ? glitchAt(t) : null;
    const q = e ? (t - e.at)/e.dur : 0;

    // vertical-hold hiccup: the picture hops down a row or two and settles
    if(e && e.kind==='vhold'){
      const off = q < 0.3 ? 3 : q < 0.65 ? 1 : 0;
      if(off){
        for(let y=GH-1; y>=0; y--) for(let x=0; x<GW; x++){
          const j=(y*GW+x)*3, k=((y-off)*GW+x)*3;
          if(y-off >= 0){ scr[j]=scr[k]; scr[j+1]=scr[k+1]; scr[j+2]=scr[k+2]; } else { scr[j]=2; scr[j+1]=3; scr[j+2]=4; }
        }
      }
      spill *= q < 0.6 ? 0.9 : 1;
    }
    // a thin band of static rolling down through the picture
    if(e && e.kind==='static'){
      const by = Math.round(e.y0 - 24 + q*56), fr = Math.floor(t*20);
      for(let y=by; y<by+4; y++){
        if(y<0||y>=GH) continue;
        const a = (y===by||y===by+3) ? 0.35 : 0.6;
        for(let x=0; x<GW; x++){
          const n = 40 + 150*hash(x*13 + y*977 + fr*7907), j=(y*GW+x)*3;
          scr[j]=lerp(scr[j],n*0.9,a); scr[j+1]=lerp(scr[j+1],n,a); scr[j+2]=lerp(scr[j+2],n*0.95,a);
        }
      }
      spill *= 1.05;
    }
    // a few rows jitter sideways 1-2 px, the offset changing every ~0.07 s
    if(e && e.kind==='jitter'){
      const step = Math.floor(q*4.3);
      const sh = [1,-2,2,-1,1][(step + e.n) % 5];
      for(let y=e.y0; y<e.y0+e.rows && y<GH; y++){
        const s2 = (y - e.y0) % 2 ? sh : Math.sign(sh);
        for(let x=0; x<GW; x++){
          const sx = clamp(x - s2, 0, GW-1), j=(y*GW+x)*3, k=(y*GW+sx)*3;
          tmp[j]=scr[k]; tmp[j+1]=scr[k+1]; tmp[j+2]=scr[k+2];
        }
        for(let x=0; x<GW; x++){ const j=(y*GW+x)*3; scr[j]=tmp[j]; scr[j+1]=tmp[j+1]; scr[j+2]=tmp[j+2]; }
      }
      spill *= 0.95;
    }
    // a brief RGB split: red one pixel right, blue one pixel left, for a few frames
    if(e && e.kind==='split'){
      for(let y=0; y<GH; y++){
        for(let x=GW-1; x>0; x--){ const j=(y*GW+x)*3; scr[j] = scr[j-3]; }
        for(let x=0; x<GW-1; x++){ const j=(y*GW+x)*3; scr[j+2] = scr[j+5]; }
      }
      spill *= 0.93;
    }

    // the rolling band (24 rows, two steps) and a faint interference line drifting up
    const bandY = -999;   // rolling band removed (Jon)
    const intY = -999;   // interference line removed (Jon: looked bad)
    for(let y=0; y<GH; y++){
      const db = Math.abs(y - bandY);
      let m0 = (db < 5 ? 1.13 : db < 12 ? 1.06 : 1) * crtWobble;
      if(y === intY) m0 *= 1.1; else if(y === intY+1) m0 *= 0.93;
      // curvature: a soft fall-off toward the corners
      const ny = (y - (GH-1)/2) / (GH/2);
      for(let x=0; x<GW; x++){
        const nx = (x - (GW-1)/2) / (GW/2);
        const r2 = (nx*nx + ny*ny)*0.5;
        const vig = 1 - 0.24*r2*r2;
        const m = m0*vig, j=(y*GW+x)*3;
        scr[j]*=m; scr[j+1]*=m; scr[j+2]*=m;
      }
    }
    // phosphor glow: bright content bleeds a little into its neighbours (3x3, only above a floor)
    if(on){
      for(let y=0; y<GH; y++) for(let x=0; x<GW; x++){
        const j=(y*GW+x)*3, l=(x>0?j-3:j), r=(x<GW-1?j+3:j);
        for(let c=0;c<3;c++) tmp[j+c] = (scr[l+c] + 2*scr[j+c] + scr[r+c])*0.25;
      }
      for(let y=0; y<GH; y++) for(let x=0; x<GW; x++){
        const j=(y*GW+x)*3, u=(y>0?j-GW*3:j), d=(y<GH-1?j+GW*3:j);
        for(let c=0;c<3;c++){ const v = (tmp[u+c] + 2*tmp[j+c] + tmp[d+c])*0.25; gl[j+c] = v; scr[j+c] += Math.max(0, v - 45)*0.3; }
      }
    } else gl.fill(0);
    return {flick, spill};
  }

  // ---- depth: the glass sits back in the bezel ----
  // Shadow the bezel throws on the glass: stepped, deeper along the top and the left (away from
  // the lamp), a thin one on the right and bottom; and the tube's rounded corners.
  function glassShade(x, y){
    // Nov 17 (Jon: "the glass effect doesn't work well"): no recess lips; one faint, even darkening
    // toward the corners and a small rounded corner (the shell's tube rounds the rest)
    const nx = (x - 74.5)/75, ny = (y - 69.5)/70, c = nx**4 + ny**4;
    let s = c > 1.2 ? 0.9 : c > 0.8 ? 0.95 : 1;
    const cxd = x < 4 ? 4-x : x > GW-5 ? x-(GW-5) : 0;
    const cyd = y < 4 ? 4-y : y > GH-5 ? y-(GH-5) : 0;
    const rc = Math.hypot(cxd, cyd);
    return s * (rc > 4.6 ? 0.08 : rc > 3.6 ? 0.5 : 1);
  }

  // dust in the lamp's cone: 10 motes, slow, whole art pixels, eased in and out; one in three a 2 px fleck
  const DUST = Array.from({length:10}, (_, k) => ({ x0: 262 + hash(k*37+1)*24, y0: 142 + hash(k*29+3)*10,
    life: 7 + hash(k*51)*4, off: hash(k*93)*11, ph: hash(k*19)*6.28, fall: 22 + hash(k*7)*14, drift: 10 + hash(k*13)*14,
    gain: 0.6 + hash(k*61)*0.4, big: k % 3 === 0 }));
  // ---- steam (Nov 17): desk_1's steam, the one Jon approved ("the steam can be more prominent") ----
  // Jon, Nov 17: "some of the coffee cups have no steam". The old puffs here rose from x 266-272, left of
  // the mug (its mouth is x 274-281 in this art), single pixels lit only by the lamp, so they barely showed.
  // This is desk 1's: wisps curl up off the opening (x, y: the opening's centre and two rows below the rim's
  // top, as on desk 1), each pixel keeps the strongest wisp over it, alpha in dithered steps. It scatters the
  // room's light, so it reads as a pale veil even where the room is dark, and only ever lightens. It thins
  // out by distance before the glass, so no edge cuts it.
  const MUGS = [{x:277, y:183, seed:5, dir:1}];    // rim top y 181, the coffee x 274-281
  const SBW = 36, SBH = 48, SA = new Float32Array(SBW*SBH);
  function steamField(m, u){
    SA.fill(0);
    const NP = 16, LIFE = 4.6, dir = m.dir||1, x0 = m.x-18, y0 = m.y-46;
    const sway = Math.sin(u*0.31 + m.seed)*1.6;
    const mark = (x,y,a)=>{ const bx = x-x0, by = y-y0; if(bx<0||by<0||bx>=SBW||by>=SBH) return; const k = by*SBW+bx; if(a > SA[k]) SA[k] = a; };
    for(let p=0;p<NP;p++){
      const age = ((u + p*LIFE/NP + m.seed*0.37) % LIFE + LIFE) % LIFE, a = age/LIFE;
      const ph = hash(p*31 + m.seed*7)*6.28, env = Math.pow(Math.sin(Math.PI*Math.min(1, a*1.25)), 0.7)*(1 - a*0.35);
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
  // lightAt(i) -> the light multiplier [r,g,b] at a pixel; as on desk 1 the side facing a light takes a little of
  // its colour: the lamp's amber on the right, the screen's teal on the left
  function drawSteam(u, lightAt, warm, cool){
    for(const m of MUGS){
      const [x0, y0] = steamField(m, u);
      for(let by=0;by<SBH;by++) for(let bx=0;bx<SBW;bx++){
        let al0 = SA[by*SBW+bx]; if(al0 <= 0.02) continue;
        const x = x0+bx, y = y0+by; if(x<0||x>=W||y<0||y>=H) continue;
        const i = y*W+x; if(isGlass[i] || isPort[i]) continue;
        const gdx = Math.max(GX-x, 0, x-(GX+GW-1)), gdy = Math.max(GY-y, 0, y-(GY+GH-1));
        al0 *= Math.min(1, Math.hypot(gdx, gdy)/4);
        const al = Math.min(0.56, Math.floor(al0/0.14 + (BAYER[(y&3)*4+(x&3)]+0.5)/16)*0.14); if(al <= 0) continue;
        const M = lightAt(i), T = x > m.x+1 ? warm : cool, o = i*4;
        const sr = 150*Math.min(M[0]*1.4 + 0.4, 1.3) + T[0], sg = 156*Math.min(M[1]*1.4 + 0.4, 1.3) + T[1], sb = 162*Math.min(M[2]*1.4 + 0.4, 1.3) + T[2];
        out[o] = Math.max(out[o], out[o]+(sr-out[o])*al); out[o+1] = Math.max(out[o+1], out[o+1]+(sg-out[o+1])*al); out[o+2] = Math.max(out[o+2], out[o+2]+(sb-out[o+2])*al);
      }
    }
  }


  function frame(g, t, info){
    R = info && info.real != null ? info.real : t;
    LEAVING = !!(info && info.leaving);
    if(DESK.act1(g, t, local)) return;
    const fadeIn = sstep(T_FADE, T_FADE + 0.6, t);

    // levels
    const lamp = lampLevel(t), warm = lampWarmth(t);
    const st = crtState(t);
    const bl = bulbs.map(b=>bulbLevel(b,t));
    let strAvg = 0; for(const v of bl) strAvg += v; strAvg /= bl.length;
    // the pillow takes half its light from the bulbs that hang nearest it
    let pillowAvg = 0; for(const k of PILLOW_BULBS) pillowAvg += bl[k];
    pillowAvg = 0.5*strAvg + 0.5*pillowAvg/PILLOW_BULBS.length;
    const crtL = st.level;
    const star = 0.93 + 0.06*Math.sin(R*0.31) + 0.03*Math.sin(R*0.83+2);   // a slow swell
    const powered = sstep(T_LAMP, T_CRT + 2.4, t);
    const amb = 0.085 + 0.065*powered;              // Nov 17: richer blacks; FA darkens the edges further

    // CRT first: the light it throws on the desk follows its glass (mostly the lower half)
    drawScreen(t, st);
    const fx = crtFilter(R, st);
    if((schN++ % 3) === 0 && st.phase !== 'off'){
      let r = 0, g2 = 0, b = 0;
      for(let y=4; y<GH-4; y+=7) for(let x=4; x<GW-4; x+=7){ const j=(y*GW+x)*3; r+=scr[j]; g2+=scr[j+1]; b+=scr[j+2]; }
      const m = Math.max(r, g2, b);
      if(m > 500){ const k = 0.3; SCH = [lerp(SCH[0], r/m, k), lerp(SCH[1], g2/m, k), lerp(SCH[2], b/m, k)]; }
    }
    let crtSpill = fx.flick * fx.spill;
    if(st.phase==='on'){
      let sum = 0;
      for(let y=GH-70; y<GH; y+=2) for(let x=0; x<GW; x+=3){ const j=(y*GW+x)*3; sum += scr[j]+scr[j+1]+scr[j+2]; }
      if(refBottom < 0) refBottom = baseBottom();
      crtSpill *= clamp(1 + 3*(sum/refBottom - 1), 0.7, 1.5);
    }
    const pass = passing(R);
    const passG = pass ? pass.g : 0;

    // ---- C lighting (Nov 18): steady weights composed and stepped once (cached), flicker multiplied after ----
    const FX = window.ROOMFX;
    const aL = t - T_LAMP;
    const lS = aL < 0 ? 0 : aL < .05 ? .55 : aL < .11 ? .06 : aL < .2 ? .7 : aL < .26 ? .22 : lerp(.45, 1, easeOut((aL - .26)/.75));
    const flL = aL > 1 ? FX.tiredBulb(R, 9, { depth: 1.2 }) * lampBrown(R) : 1;   // a tired bulb, and the rare brown-out
    const lampQ = Math.round(lS*24)/24, warmQ = Math.round(clamp(warm, 0, 1)*12)/12, fadeQ = Math.round(fadeIn*24)/24;
    const lcS = [1, lerp(0.56, 0.75, warmQ), lerp(0.28, 0.47, warmQ)];
    const ledLv = LEDS.map(L=>{
      switch(L.kind){
        case 'standby': return 0.85;
        case 'strip': return t > T_LEDS ? 1 : 0;
        case 'beat': { if(t < T_LEDS+0.5) return 0; const q = (R - T_LEDS) % 2.3; return q < 0.14 ? 1 : 0.12; }
        case 'amber': return t > T_LEDS+0.25 ? 0.9 : 0;
        case 'amber2': return t > T_LEDS+0.35 ? 0.7 : 0;
      }
      return 0;
    });
    const jbOn = t > T_LEDS + 0.6 ? 1 : 0;
    const son = bl.map(v => v > 0 ? 1 : 0), lon = ledLv.map(v => v > 0 ? 1 : 0);
    const pillowS = PILLOW_BULBS.reduce((s, k) => s + son[k], 0)/PILLOW_BULBS.length;
    const crtQ = Math.round(crtL*16)/16;
    const key = [lampQ, warmQ, crtQ, fadeQ, son.join(''), lon.join(''), jbOn].join('|');
    if(!CCB.S || CCB.key !== key){
      const tl = lcS.map(v => 1 + (v - 1)*0.7), tm = [0.6, 0.92, 0.9].map(v => 1 + (v - 1)*0.5);
      CCB.S = LIT.compose({ A: A2, amb: [.17, .18, .23], fa: FA, fade: fadeQ, ov: .3, hot: 6, hotCol: lcS,
        big: [ { F: FLD.lamp, w: lampQ*1.3, tint: tl, ch: 0 }, { F: FLD.scr, w: crtQ*1.3, tint: tm, ch: 1 },
               { F: FLD.port, w: .6*fadeQ, tint: [.8, .88, 1], ch: 2 }, { F: FLD.patch, w: .9*fadeQ, tint: [.62, .78, 1], ch: 2 },
               { F: FLD.pillow, w: 1.3*pillowS*fadeQ, tint: [1, .8, .55], ch: 2 }, { F: FLD.ring, w: .5*fadeQ, tint: [.66, .8, 1], ch: 2 },
               { F: FLD.wash, w: .85*fadeQ*son.reduce((a, b) => a + b, 0)/son.length, tint: [1, .78, .5], ch: 2 } ],
        small: SMALL.map((q, n) => ({ f: q.f, box: q.box, tint: q.tint,
          w: (n < NB ? son[n]*1.3 : n < NB + NL ? lon[n - NB]*1.2 : jbOn) * fadeQ })) });
      CCB.key = key;
    }
    const sFl = SMALL.map((q, n) => n < NB ? (son[n] ? Math.min(bl[n], 1.35)*FX.tiredBulb(R, 40 + n*7, { depth: .9, every: 5 + (n % 4), stutterEvery: 23 + n }) : 1)
      : n < NB + NL ? (lon[n - NB] ? ledLv[n - NB] : 1) : 1);
    LIT.frame(CCB.S, out, { lamp: flL, scr: crtSpill, small: sFl }, Lc);
    for(let i=0;i<N;i++){ Pr[i] = 1 - Math.min(1, Lc[i*3]); Pg[i] = 1 - Math.min(1, Lc[i*3+1]); Pb[i] = 1 - Math.min(1, Lc[i*3+2]); }
    const G = 1.55, ar = amb*0.80, ag = amb*0.92, ab = amb*1.18;
    // the glass: its own emitter
    for(let y=0;y<GH;y++) for(let x=0;x<GW;x++){
      const i = (GY+y)*W + GX + x, o = i*4, j = (y*GW + x)*3, sh = SHADE[y*GW + x] * fx.flick;
      out[o] = (3 + scr[j])*sh; out[o+1] = (5 + scr[j+1])*sh; out[o+2] = (8 + scr[j+2])*sh; out[o+3] = 255;
    }
    const lc = [1, lerp(0.56, 0.75, warm), lerp(0.28, 0.47, warm)];
    // dust in the air ("more dust overall"), lit by the light where each mote is
    FX.drawDust(DUSTC, out, R, i => [Lc[i*3], Lc[i*3+1], Lc[i*3+2]], 72, .03, fadeIn);
    // the bezel lip: lit faces take the room's light, shadowed ones darken; the screen bleeds onto it
    for(const L of LIP){
      const o = L.i*4, j = L.g*3;
      if(L.face > 0){
        const lr = 1-Pr[L.i], lg = 1-Pg[L.i], lb = 1-Pb[L.i];
        out[o]+=L.face*(10+60*lr); out[o+1]+=L.face*(10+56*lg); out[o+2]+=L.face*(12+52*lb);
      } else { const k = 1 + L.face; out[o]*=k; out[o+1]*=k; out[o+2]*=k; }
      const bl2 = (L.d===1 ? 0.22 : 0.09) * fx.flick;
      out[o]+=gl[j]*bl2; out[o+1]+=gl[j+1]*bl2; out[o+2]+=gl[j+2]*bl2;
    }
    // the porthole: a living window (parallax stars, twinkle, rare passers-by), outside light from the start
    FX.drawSky(SKY, (i, r0, g0, b0) => { const o = i*4; out[o] = r0; out[o+1] = g0; out[o+2] = b0; out[o+3] = 255; }, R, 1);
    // string bulbs: off = dark glass, warming through ember orange to the art's own warm white
    bulbs.forEach((b,k)=>{
      const v = bl[k];
      for(const [x,y,core] of b.pix){
        const i = y*W+x, o=i*4, a3=i*3;
        const offc = [art[a3]*0.07, art[a3+1]*0.06, art[a3+2]*0.06];
        const ember = core ? [190,95,40] : [150,62,22];
        const on = [Math.min(255, art[a3]*1.1+12), Math.min(255, art[a3+1]*1.1+8), Math.min(255, art[a3+2]*1.08)];
        let c;
        if(v <= 0.3) c = [lerp(offc[0],ember[0],v/0.3), lerp(offc[1],ember[1],v/0.3), lerp(offc[2],ember[2],v/0.3)];
        else { const u = Math.min(1,(v-0.3)/0.7); c = [lerp(ember[0],on[0],u), lerp(ember[1],on[1],u), lerp(ember[2],on[2],u)]; }
        const over = v > 1 ? v : 1;
        out[o]=c[0]*over; out[o+1]=c[1]*over; out[o+2]=c[2]*over;
      }
    });
    // the lamp bulb: a hot core that may blow out
    for(const [x,y,core] of lampPix){
      const i=y*W+x, o=i*4;
      const hot = core ? [255, lerp(150,240,warm), lerp(70,200,warm)] : [255, lerp(110,200,warm), lerp(40,130,warm)];
      const i3 = i*3, offc = [art[i3]*0.12, art[i3+1]*0.12, art[i3+2]*0.12];
      const v = Math.min(1, lamp);
      out[o]=lerp(offc[0],hot[0],v); out[o+1]=lerp(offc[1],hot[1],v); out[o+2]=lerp(offc[2],hot[2],v);
    }
    // LEDs
    LEDS.forEach((L,k)=>{
      const v = ledLv[k], o=(L.y*W+L.x)*4;
      if(v<=0) return;
      out[o]=lerp(out[o],L.col[0],v); out[o+1]=lerp(out[o+1],L.col[1],v); out[o+2]=lerp(out[o+2],L.col[2],v);
    });
    // junction box readout: three tiny bars, one moves every half second
    if(t > T_LEDS + 0.6){
      const s = Math.floor(R*2);
      for(let r=0;r<3;r++){
        const len = 2 + Math.floor(hash(s*3 + r*101 + (r===1?0:Math.floor(t/3)*7))*6);
        for(let x=0;x<len;x++){ const o=((JB_SCREEN.y+r*2)*W + JB_SCREEN.x + x)*4; out[o]=60; out[o+1]=190; out[o+2]=150; }
      }
    }
    // steam off the mug, lit by the room's light where it is (the same multiplier the pixels below take)
    { const lw = Math.min(1, lamp), cw = Math.min(1, crtL);
      drawSteam(R, i => [Lc[i*3], Lc[i*3+1], Lc[i*3+2]],
        [44*lw*lc[0], 44*lw*lc[1], 44*lw*lc[2]], [46*cw*0.6, 46*cw*0.92, 46*cw*0.9]); }
    if(DEBUG){
      for(let i=0;i<N;i++) if(isPort[i] && (i%W + (i/W|0))%2===0){ out[i*4]=255; out[i*4+1]=0; out[i*4+2]=255; }
      for(const b of bulbs) for(const [x,y] of b.pix){ const o=(y*W+x)*4; out[o]=255; out[o+1]=0; out[o+2]=255; }
      for(const [x,y] of lampPix){ const o=(y*W+x)*4; out[o]=0; out[o+1]=255; out[o+2]=0; }
      for(const L of LEDS){ const o=(L.y*W+L.x)*4; out[o]=255; out[o+1]=0; out[o+2]=255; }
      for(const s of stars){ const o=s.i*4; out[o]=255; out[o+1]=255; out[o+2]=0; }
    }
    offc.putImageData(imgData, 0, 0);
    g.imageSmoothingEnabled = false;
    g.drawImage(off, 0, 0, W*SCALE, H*SCALE);
    if(st.phase !== 'off'){
      g.fillStyle = 'rgba(0,0,0,0.38)';
      for(let y=0; y<GH; y++) g.fillRect(GX*SCALE, (GY+y)*SCALE + SCALE-1, GW*SCALE, 1);
    }
    if(fadeIn < 1){ g.fillStyle = 'rgba(0,0,0,'+(1-fadeIn)+')'; g.fillRect(0,0,1920,1080); }
  }

  let built = null;
  DESK.register({
    id: 'bunk_1', name: 'BUNK', line: 'Your bunk, late, lights coming on', doneAt: 12.1, times: { lamp: T_LAMP, crt: T_CRT },
    init(){   // built once (a second build would add every bulb twice)
      return built || (built = (async () => {
        [local, artImg, cultImg] = await Promise.all([
          DESK.img('assets/local.png'), DESK.img('assets/bunk_1.png'), DESK.img('assets/screen_culture.png')]);
        build();
      })());
    },
    frame
  });
})();
