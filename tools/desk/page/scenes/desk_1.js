// DESK 1: the lived-in bridge desk. Evening power-on, then a cozy idle.
// Lighting is done at art resolution (384x216) into a light map, then scaled 5x.
// Each light's field is precomputed and stepped (plateaus with a dithered edge);
// per frame only the weights move, so band edges never crawl.
(function(){
  const W = 384, H = 216, N = W * H, S = 5;
  const GX = 117, GY = 22, GW = 150, GH = 140;            // CRT glass
  const BAYER = [0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5].map(v => (v + .5) / 16);
  const bay = (x, y) => BAYER[(y & 3) * 4 + (x & 3)];
  const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
  const sat = v => v < 0 ? 0 : v > 1 ? 1 : v;
  const lerp = (a, b, k) => a + (b - a) * k;
  const ease = t => { t = sat(t); return t * t * (3 - 2 * t); };
  const hash = n => { const s = Math.sin(n * 12.9898 + 78.233) * 43758.5453; return s - Math.floor(s); };

  // Hand-checked light positions (art px), round 4 / monitor A. The lamp is a green dome shade:
  // only the bulb's bottom sliver (y 135-137) and the shade's warm inside lip (y 134) show.
  // The bulbs that touched monitor A are gone from the art ((105,13), (251,6), (258,16)).
  const BULB = { x: 85, y: 136, box: [72, 134, 99, 137] };
  const RIM_Y = 134;                            // the shade's rim: the light falls from here down
  const LAMP_BZ = 129, LAMP_T = 3.2;            // v5: the bulb's centre inside the dome; the cone's spread (half-width per px down)
  const STR_L = [[113,4],[97,21],[85,31],[74,38],[59,46],[40,50],[23,52],[3,51]];
  const STR_R = [[286,39],[298,47],[311,52],[328,56],[348,57],[369,57]];
  const CASE = [105, 8, 278, 176];              // monitor A's case
  const PORT = { x: 311, y: 23 };
  const PIPE_LED = [38, 93, 41, 97];           // amber indicator on the pipe junction box
  const SOLDER_LED = [[340,163],[341,163]];    // heater lamp on the soldering station
  const MON_LED = [[128,169],[129,169],[128,170],[129,170]];   // monitor A's power lamp, chin left
  const MUGS = [{x: 272, y: 180, seed: 1, life: 2.3}];         // one mug; its steam stops short of the glass
  // the soldering iron's tip (v6: found in the art at load, see findTip; these are fallbacks)
  let TIP = [[327,171],[328,170],[329,169]], TIPC = { x: 327, y: 171 };
  const SMOKE = { x: 327, y: 169, seed: 4, life: 5.5, np: 6, rise: 5, alpha: .3 };
  // The iron runs from the blue grip down-left into the stand; its shaft is a thin line of pale grey.
  // Walk from the grip's low end down the line of pale pixels; the last one is the tip.
  function findTip(){
    const pale = (x, y) => { const i = y * W + x, r = A[i*3], g = A[i*3+1], b = A[i*3+2];
      return lum(i) >= 120 && Math.max(r, g, b) - Math.min(r, g, b) < 40; };
    const blue = (x, y) => { const i = y * W + x; return A[i*3+2] > A[i*3] + 50 && A[i*3+2] > 120; };
    // the grip's lowest-left blue pixel
    let gx = -1, gy = -1;
    for (let y = 150; y <= 172; y++) for (let x = 322; x <= 345; x++) if (blue(x, y) && (y > gy || (y === gy && x < gx))){ gx = x; gy = y; }
    if (gx < 0) return;
    let x = gx, y = gy, path = [];
    for (let n = 0; n < 20; n++){
      let nx = -1, ny = -1;
      for (const [dx, dy] of [[-1, 1], [0, 1], [-1, 0], [-1, 2], [-2, 1]]) if (pale(x + dx, y + dy)){ nx = x + dx; ny = y + dy; break; }
      if (nx < 0) break;
      x = nx; y = ny; path.push([x, y]);
    }
    if (path.length < 3) return;
    const t = path.slice(-3);
    TIP = t; TIPC = { x: t[t.length - 1][0], y: t[t.length - 1][1] };
    SMOKE.x = TIPC.x; SMOKE.y = TIPC.y - 1;
  }

  let local, artImg, cultImg, nrmImg;
  let A;                    // art rgb, Float32 3N
  let glass;                // Uint8 N
  let Fl, Fm, Fp, Fw;       // stepped fields: lamp, monitor spill, porthole, string wash
  let bulbPx = [], filPx = [], strings = [], portGlass = [], pipeLed = [];
  let M, Ad;                // per-frame multiply / add accumulators (3N)
  let cult, cultMean = [0,0,0], glassShade;
  let off, octx, odata, out;
  let stars = [];
  let glassArc;
  let C = 0, LEAVING = false;   // C: free clock for idle motion (keeps running while leaving)

  // ---------- precompute ----------
  function bandStep(d, bands, E, b){
    let s = 0;
    for (let k = 0; k < bands.length; k++){
      const f = (bands[k][0] - d) / E + .5;
      if (f >= 1 || (f > 0 && f > b)) s += bands[k][1];
    }
    return s;
  }
  function lum(i){ return .3 * A[i*3] + .59 * A[i*3+1] + .11 * A[i*3+2]; }
  function flood(sx, sy, box, ok){
    const seen = new Uint8Array(N), outp = [], st = [[sx, sy]];
    while (st.length){
      const [x, y] = st.pop();
      if (x < box[0] || x > box[2] || y < box[1] || y > box[3]) continue;
      const i = y * W + x;
      if (seen[i]) continue; seen[i] = 1;
      if (!ok(i)) continue;
      outp.push(i);
      st.push([x+1,y],[x-1,y],[x,y+1],[x,y-1]);
    }
    return outp;
  }
  function segDist(px, py, ax, ay, bx, by){
    const dx = bx - ax, dy = by - ay, l = dx*dx + dy*dy;
    let t = l ? ((px-ax)*dx + (py-ay)*dy) / l : 0; t = sat(t);
    const qx = ax + dx*t - px, qy = ay + dy*t - py;
    return Math.sqrt(qx*qx + qy*qy);
  }

  function build(){
    const c = document.createElement('canvas'); c.width = W; c.height = H;
    const cx = c.getContext('2d'); cx.drawImage(artImg, 0, 0);
    const d = cx.getImageData(0, 0, W, H).data;
    A = new Float32Array(N * 3);
    for (let i = 0; i < N; i++){ A[i*3] = d[i*4]; A[i*3+1] = d[i*4+1]; A[i*3+2] = d[i*4+2]; }
    const cc = document.createElement('canvas'); cc.width = GW; cc.height = GH;
    const ccx = cc.getContext('2d'); ccx.drawImage(cultImg, 0, 0);
    cult = ccx.getImageData(0, 0, GW, GH).data;
    for (let i = 0; i < GW*GH; i++){ cultMean[0] += cult[i*4]; cultMean[1] += cult[i*4+1]; cultMean[2] += cult[i*4+2]; }
    const mm = Math.max(...cultMean); cultMean = cultMean.map(v => v / mm);

    glass = new Uint8Array(N);
    for (let y = GY; y < GY + GH; y++) for (let x = GX; x < GX + GW; x++) glass[y*W + x] = 1;

    // bulb: everything inside its outline, flood-filled from the middle
    bulbPx = flood(BULB.x, BULB.y, BULB.box, i => {
      const r = A[i*3], b = A[i*3+2];
      return lum(i) >= 110 && r >= b + 10;
    });
    filPx = bulbPx.filter(i => {
      const x = i % W, y = (i / W) | 0;
      const r = A[i*3], g = A[i*3+1], b = A[i*3+2];
      return y >= 135 && y <= 137 && r > 220 && g > 215 && b > 200;                  // the white-hot filament sliver
    });

    // string bulbs: bright warm pixels in a tight box round each hand-marked centre
    const mkStr = (list, side) => list.map(([x0, y0], k) => {
      const px = [];
      for (let y = y0 - 3; y <= y0 + 3; y++) for (let x = x0 - 3; x <= x0 + 3; x++){
        if (x < 0 || x >= W || y < 0 || y >= H) continue;
        const i = y*W + x;
        if (lum(i) >= 120 && A[i*3] >= A[i*3+2] + 15) px.push(i);
      }
      const R = 14, x0b = Math.max(0, x0 - R), y0b = Math.max(0, y0 - 10), x1b = Math.min(W-1, x0 + R), y1b = Math.min(H-1, y0 + 24);
      const bw = x1b - x0b + 1, bh = y1b - y0b + 1, f = new Float32Array(bw * bh);
      for (let y = y0b; y <= y1b; y++) for (let x = x0b; x <= x1b; x++){
        const dd = Math.hypot(x - x0, (y - y0) * (y > y0 ? .62 : 1.1));   // v3: the halo falls down the wall
        f[(y - y0b) * bw + (x - x0b)] = bandStep(dd, [[2.5,.55],[5.5,.38],[9,.24],[13,.12]], 2, bay(x, y));   // pass 2: a wider halo on the wall
      }
      return { x: x0, y: y0, px, k, side, box: [x0b, y0b, bw, bh], f,
               f1: .11 + hash(x0*3.1 + y0) * .2, f2: .27 + hash(x0 + y0*7.7) * .35,
               p1: hash(x0*1.7) * 6.28, p2: hash(y0*2.3 + 5) * 6.28,
               dipEvery: 7 + hash(x0 + 11) * 11, dipOff: hash(x0*9 + y0) * 20,
               jit: hash(x0 * 5.5 + y0 * 1.3) };
    });
    strings = mkStr(STR_L, 0).concat(mkStr(STR_R, 1));
    // one bulb on each string catches on the second try
    strings[3].stutter = true; strings[STR_L.length + 4].stutter = true;

    // pipe LED pixels
    pipeLed = [];
    for (let y = PIPE_LED[1]; y <= PIPE_LED[3]; y++) for (let x = PIPE_LED[0]; x <= PIPE_LED[2]; x++){
      const i = y*W + x; if (A[i*3] >= 165 && A[i*3] > A[i*3+2] + 60) pipeLed.push(i);
    }

    // porthole glass: the dark disc inside the ring
    portGlass = flood(PORT.x, PORT.y, [296, 8, 327, 39], i => lum(i) < 60);
    const pg = new Set(portGlass);
    stars = [];
    // hand-spread stars (x along a 34 px loop that drifts, y fixed), so none bunch up
    const SP = [[3,-5],[8,4],[12,-9],[15,1],[19,7],[22,-3],[26,9],[29,-7],[31,2],[6,-1],[17,-6],[24,4],[33,-2],[10,8]];
    SP.forEach(([sx, sy], k) => stars.push({ x: sx, y: PORT.y + sy,
      b: .3 + hash(k * 7.3) * .55, f: .2 + hash(k * 2.9) * .5, p: hash(k * 1.3) * 6.28 }));
    stars._set = pg;

    // glass shade: CRT vignette and rounded corners, in whole steps
    // The glass sits back in the bezel: the bezel shades its top and the lamp side
    // (left), a little less the other two; the tube darkens toward its curved corners.
    glassShade = new Float32Array(GW * GH);
    glassArc = new Float32Array(GW * GH);
    const edgeStep = (d, lv, b) => d < lv.length - 1 ? lv[d] : d === lv.length - 1 ? (b < .5 ? lv[d] : 1) : 1;
    for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++){
      const b = bay(x, y);
      // v5 (Jon: "the glass effect doesn't work well"): no recess lips, no sheen; one faint, even
      // darkening toward the rounded corners, so the game reads clean through the glass
      const nx = (x - 74.5) / 75, ny = (y - 69.5) / 70, c = nx ** 4 + ny ** 4 + (b - .5) * .1;
      let s = c > 1.2 ? .9 : c > .8 ? .95 : 1;
      const cxr = Math.min(x, GW - 1 - x), cyr = Math.min(y, GH - 1 - y);
      if (cxr < 4 && cyr < 4){ const dc = Math.hypot(4 - cxr, 4 - cyr); if (dc > 4.6) s = .07; else if (dc > 3.6) s = Math.min(s, .5); }   // v5: a small corner, the tube rounds the rest
      glassShade[y * GW + x] = s;
      // convex sheen: a thin curved highlight across the top-right of the glass
      const dr = Math.hypot(x - 60, y - 100) - 104;
      if (x > 84 && y < 50 && dr > -3.5 && dr < .9){
        const ang = Math.atan2(y - 100, x - 60), t0 = Math.atan2(-100, 28.6), t1 = Math.atan2(-54, 89);
        const fpos = Math.sin(Math.PI * sat((ang - t0) / (t1 - t0)));
        const core = dr > -.9 ? 1 : .35;
        const v = fpos * core;
        glassArc[y * GW + x] = v > .55 ? v : (v > .2 && b < .5 ? v : 0);
      }
    }

    findTip();
    buildC();
    M = new Float32Array(N * 3); Ad = new Float32Array(N * 3);
    off = document.createElement('canvas'); off.width = W; off.height = H;
    octx = off.getContext('2d'); odata = octx.createImageData(W, H); out = odata.data;
    for (let i = 0; i < N; i++) out[i*4+3] = 255;
  }

  let SCH = [.55, .95, .9], schN = 0;   // the screen's colour, sampled off the glass and smoothed
  function poly(pts){
    const m = new Uint8Array(N); let x0 = W, y0 = H, x1 = 0, y1 = 0;
    for (const [x, y] of pts){ x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++){
      let ins = false;
      for (let a = 0, b = pts.length - 1; a < pts.length; b = a++){
        const [xa, ya] = pts[a], [xb, yb] = pts[b];
        if ((ya > y + .5) !== (yb > y + .5) && x + .5 < (xb - xa) * (y + .5 - ya) / (yb - ya) + xa) ins = !ins;
      }
      if (ins) m[y * W + x] = 1;
    }
    return m;
  }
  // ---------- tiny pixel font (3x5) for the boot lines ----------
  const FONT = {
    'A':'010101111101101','B':'110101110101110','C':'011100100100011','D':'110101101101110','E':'111100110100111',
    'G':'011100101101011','I':'111010010010111','K':'101101110101101','L':'100100100100111','M':'101111111101101',
    'N':'110101101101101','P':'110101110100100','O':'010101101101010','R':'110101110101101','S':'011100010001110','T':'111010010010010',
    'U':'101101101101111','0':'010101101101010','3':'110001010001110','4':'101101111001001','6':'011100110101010',
    '-':'000000111000000','>':'100010001010100','.':'000000000000010',' ':'000000000000000','_':'000000000000111'
  };
  function textPx(str, sc){
    const pts = [];
    for (let c = 0; c < str.length; c++){
      const gph = FONT[str[c]] || FONT[' '];
      for (let gy = 0; gy < 5; gy++) for (let gx = 0; gx < 3; gx++) if (gph[gy*3 + gx] === '1')
        for (let sy = 0; sy < sc; sy++) for (let sx = 0; sx < sc; sx++) pts.push([c * 4 * sc + gx * sc + sx, gy * sc + sy]);
    }
    return pts;
  }
  const BOOT = [
    { s: 'SCI-TERM 03', sc: 2, x: 31, y: 38, t: 3.74 },
    { s: 'MEM 64K OK', sc: 1, x: 12, y: 66, t: 4.40 },
    { s: 'SCOPE LINK OK', sc: 1, x: 12, y: 74, t: 4.78 },
    { s: '> CULTURE', sc: 1, x: 12, y: 86, t: 5.18 },
  ];
  BOOT.forEach(l => { l.px = []; for (let c = 0; c < l.s.length; c++) l.px.push(textPx(l.s[c], l.sc).map(([x, y]) => [x + c * 4 * l.sc, y])); });

  // ---------- timeline (u = seconds since act 1 went black) ----------
  // Nov 17 (Jon: "the opening sequence for the screen could be a bit slower. Maybe with a title screen"):
  // the CRT's own warm-up (dot, line, raster, boot text) runs 1.5x longer, then the game's title card
  // holds (DESK.TITLE.hold), then wipes into the game. The room's lights keep their beats before it.
  const T = { fade: .6, click: .95, strings: 1.9, monLed: 2.45, dot: 2.6, line: 2.87, open: 3.17, boot: 3.62, title: 5.82, solder: 2.3 };
  T.roll = T.title + DESK.TITLE.hold; T.idle = T.roll + DESK.TITLE.wipe + .5;

  function lampState(u){
    // filament: strike, catch, drop, catch, then warm up
    let fil = 0;
    if (u < T.click) fil = 0;
    else if (u < 1.03) fil = .5;
    else if (u < 1.10) fil = .06;
    else if (u < 1.22) fil = .72;
    else if (u < 1.30) fil = .32;
    else fil = lerp(.32, 1, ease((u - 1.30) / .85));
    const k = ease((u - 1.05) / 1.5);                  // colour temperature: deep orange -> warm
    let breathe = 1, brown = 0, drift = 0;
    if (u > 2.2){
      const b = sat((u - 2.2) / 2);
      breathe = 1 + b * (.045 * Math.sin(C * 2 * Math.PI * .13) + .024 * Math.sin(C * 2 * Math.PI * .41 + 1.3) + .01 * Math.sin(C * 2 * Math.PI * 1.7 + .4));
      // v6 (Jon: "a little bit of light flicker"): the filament wavers on two irregular clocks, and
      // every 7-13 s dips 6-9% for about half a second, eased in and out
      breathe *= 1 + b * (.022 * vnoise(C * 1.7, 61) + .012 * vnoise(C * 4.3, 67));
      { const P = 10, ci = Math.floor(C / P), at = 1.5 + hash(ci * 3.9 + 1) * 6, a = C - ci * P - at, len = .45 + hash(ci * 2.2) * .25;
        if (a > 0 && a < len) breathe *= 1 - b * (.06 + hash(ci * 7.1) * .03) * Math.sin(Math.PI * a / len); }
      drift = b * Math.sin(C * 2 * Math.PI / 23 + .7);      // slow warm <-> cool drift of the filament
    }
    if (u > T.idle + 2 && !LEAVING){
      // rare brown-out: the filament sags 15-25% for a moment, wobbles, and recovers
      const P = 17, ci = Math.floor(C / P), ph = C - ci * P;
      if (hash(ci * 7.7 + 3) > .25){
        const a = ph - (3 + hash(ci * 5.3) * 10), depth = .15 + hash(ci * 2.1) * .1;
        if (a > 0 && a < .95){
          const d = a < .08 ? a / .08 : a < .3 ? 1 - .3 * Math.sin(Math.PI * (a - .08) / .22) : 1 - ease((a - .3) / .65);
          brown = depth * d;
        }
      }
    }
    return { fil, k, brown, drift, w: Math.pow(fil, 1.25) * breathe * (1 - brown) };
  }
  function stringLevel(s, u){
    const order = s.k;
    const on = T.strings + order * .12 + s.jit * .05 + (s.side ? .04 : 0);
    const a = u - on;
    if (a < 0) return 0;
    let lv;
    if (s.stutter){
      if (a < .07) lv = .8; else if (a < .2) lv = 0; else if (a < .26) lv = 1.3; else lv = 1;
    } else lv = a < .05 ? 1.35 : 1;
    if (u > T.idle - 3){
      // idle twinkle: two slow sines per bulb, never in sync, and a rare soft dip
      const ib = sat((u - T.idle + 3) / 2);
      lv *= 1 + ib * (.18 * Math.sin(C * 6.283 * s.f1 + s.p1) + .1 * Math.sin(C * 6.283 * s.f2 + s.p2));
      // every ~10 s a slow swell runs out along the wire (the two strings take turns)
      const sw = ((C + (s.side ? 5.2 : 0)) % 10.5 + 10.5) % 10.5, pos = sw * 3.2 - 2, dk = s.k - pos;
      lv *= 1 + .32 * ib * Math.exp(-dk * dk / 2.2);
      const dc = ((C + s.dipOff) % s.dipEvery + s.dipEvery) % s.dipEvery;
      if (dc < .9) lv *= 1 - .35 * ib * Math.sin(Math.PI * dc / .9);
    }
    return lv;
  }
  function screenLevel(u){
    if (u < T.dot) return 0;
    if (u < T.line) return .12 * ease((u - T.dot) / .1);
    if (u < T.open) return .22;
    if (u < T.boot) return lerp(.5, .2, ease((u - T.open) / .3));
    if (u < T.title) return .2;
    if (u < T.roll) return .4;                 // the title card
    if (u < T.idle) return lerp(.35, .7, ease((u - T.roll) / .5));
    return .62;
  }

  function addGlow(cx, cy, v, col, R){
    if (v <= 0) return;
    for (let y = Math.floor(cy - R); y <= Math.ceil(cy + R); y++) for (let x = Math.floor(cx - R); x <= Math.ceil(cx + R); x++){
      const d = Math.hypot(x - cx, y - cy);
      const f = bandStep(d, [[R * .45, .5], [R, .3]], 1.5, bay(x, y)); if (!f) continue;
      const j = (y * W + x) * 3, e = f * v;
      M[j] += e * 1.3 * col[0]; M[j+1] += e * 1.3 * col[1]; M[j+2] += e * 1.3 * col[2];
      Ad[j] += e * 34 * col[0]; Ad[j+1] += e * 34 * col[1]; Ad[j+2] += e * 34 * col[2];
    }
  }
  function put(i, r, g2, b){ const o = i * 4; out[o] = r; out[o+1] = g2; out[o+2] = b; }

  function drawBulb(u, L, fade){
    const fil = L.fil, k = L.k;
    const filSet = new Set(filPx);
    for (const i of bulbPx){
      const r = A[i*3], g2 = A[i*3+1], b = A[i*3+2];
      const lm = .3*r + .59*g2 + .11*b;
      // unlit: a pale glass bulb in a dark room
      const offR = lm * .5 * .32 * fade + 3, offG = lm * .52 * .32 * fade + 4, offB = lm * .56 * .32 * fade + 6;
      if (fil <= 0){ put(i, offR, offG, offB); continue; }
      const isFil = filSet.has(i);
      let onR, onG, onB;
      if (isFil){
        // filament: dull orange at the strike, near-white hot once warm
        const ke = sat(k - L.brown * 1.6 + L.drift * .06); onR = 255; onG = lerp(120, 236, ke); onB = lerp(40, 190, ke);
        const f = sat(fil * 1.4);
        put(i, lerp(offR, onR, f), lerp(offG, onG, f), lerp(offB, onB, f));
      } else {
        // glass: the art's own colour, brighter, warming from deep orange
        const gl = fil * (L.w / Math.max(fil, .001));
        onR = r * 1.12 + 14; onG = g2 * lerp(.6, 1.06, k) + 6; onB = b * lerp(.3, .92, k);
        const f = sat(gl * lerp(.55, 1, k));
        put(i, lerp(offR, onR, f), lerp(offG, onG, f), lerp(offB, onB, f));
      }
    }
  }
  function drawStrings(sLv, fade){
    for (let n = 0; n < strings.length; n++){
      const s = strings[n], v = sLv[n];
      for (const i of s.px){
        const r = A[i*3], g2 = A[i*3+1], b = A[i*3+2];
        const offR = r * .16 * fade + 2, offG = g2 * .15 * fade + 2, offB = b * .17 * fade + 3;
        if (v <= 0){ put(i, offR, offG, offB); continue; }
        const f = Math.min(v, 1.35);
        put(i, lerp(offR, r * 1.06 + 16, sat(f)) + (f > 1 ? (f - 1) * 120 : 0),
               lerp(offG, g2 * 1.0 + 8, sat(f)) + (f > 1 ? (f - 1) * 90 : 0),
               lerp(offB, b * .85, sat(f)) + (f > 1 ? (f - 1) * 50 : 0));
      }
    }
  }
  function pipeLedLevel(u){
    // standby amber: a slow breath in the dark; once the desk is up, steady with a double blink
    if (u < T.strings + .5){
      return .35 + .3 * (.5 + .5 * Math.sin(C * 2.4));
    }
    const c = ((C % 3.1) + 3.1) % 3.1;
    if (c < .09 || (c > .2 && c < .29)) return .25;
    return 1;
  }
  function solderLevel(u){
    if (u < T.solder) return 0;
    // a heater lamp regulating: on/off in uneven spells
    const a = u - T.solder;
    if (a < 1.6) return 1;
    let tt = ((C % 40) + 40) % 40, n = 0;
    while (true){
      const on = .5 + hash(n * 3.3 + 1) * 1.1, offd = .35 + hash(n * 5.9 + 2) * .7;
      if (tt < on) return 1;
      tt -= on;
      if (tt < offd) return 0;
      tt -= offd; n++;
      if (n > 200) return 1;
    }
  }
  function drawLeds(pipeOn, solderOn, monOn){
    for (const i of pipeLed){
      const r = A[i*3], g2 = A[i*3+1], b = A[i*3+2], v = .25 + .75 * pipeOn;
      put(i, Math.min(255, r * v * 1.15 + 20 * pipeOn), g2 * v * .95, b * v * .6);
    }
    for (const [x, y] of SOLDER_LED){ const i = y*W + x; const o = i*4;
      if (solderOn) put(i, 255, 70, 50); else put(i, out[o] * .9 + 20, out[o+1] * .9, out[o+2] * .9); }
    for (const [x, y] of MON_LED){ const i = y*W + x; const o = i*4;
      if (monOn) put(i, 120, 255, 140); else put(i, out[o] + 8, out[o+1] + 12, out[o+2] + 8); }
  }
  function drawPorthole(u, fade){
    const set = stars._set;
    // the glass: deep space, a hint of a far nebula at the lower left
    for (const i of portGlass){
      const x = i % W, y = (i / W) | 0;
      const dn = Math.hypot(x - (PORT.x - 6), y - (PORT.y + 6));
      const neb = bandStep(dn, [[5, .5], [9, .5]], 2, bay(x, y));
      put(i, 5 + neb * 9, 8 + neb * 6, 18 + neb * 14);
    }
    // a far ship's beacon crosses the glass every ~26 s, white with a slow red blink
    if (u > 4){
      const bc = ((u - 4) % 26 + 26) % 26, bi = Math.floor((u - 4) / 26);
      if (bc < 8){
        const p = bc / 8, y0 = PORT.y + 7 - hash(bi * 3.1) * 6;
        const bx = Math.round(PORT.x - 15 + 30 * p), by = Math.round(y0 - 10 * p);
        const bi2 = by * W + bx;
        if (set.has(bi2)){
          const red = (bc % 1.3) < .22;
          if (red) put(bi2, 255, 80, 70); else put(bi2, 120, 125, 150);
        }
      }
    }
    // stars drift very slowly past (the ship turns); one glints now and then
    const drift = u * .22;
    const gi = Math.floor(u / 4.3), gStar = Math.floor(hash(gi * 7.1) * stars.length), gA = (((u % 4.3) + 4.3) % 4.3) / .9;
    for (let k = 0; k < stars.length; k++){
      const s = stars[k];
      const x = Math.round(PORT.x - 17 + (((s.x + drift) % 34) + 34) % 34), y = Math.round(s.y);
      const i = y * W + x; if (!set.has(i)) continue;
      let v = s.b * (.85 + .15 * Math.sin(u * s.f * 6.283 + s.p));
      let glint = 0;
      if (k === gStar && gA < 1) glint = Math.sin(Math.PI * gA);
      v = Math.min(1, v + glint * .6);
      put(i, 140 + 115 * v, 150 + 105 * v, 170 + 85 * v);
      if (glint > .45){
        for (const [dx, dy] of [[1,0],[-1,0],[0,1],[0,-1]]){
          const j = (y + dy) * W + x + dx; if (!set.has(j)) continue;
          const o = j * 4; put(j, out[o] + 70 * glint, out[o+1] + 75 * glint, out[o+2] + 85 * glint);
        }
      }
    }
  }
  // v5 (Jon: "the steam can be more prominent"): taller wisps that curl, more of them; each pixel
  // keeps the strongest wisp over it (no bright blobs where wisps cross), alpha in dithered steps;
  // lit by the room, warm on the lamp's side of each wisp and teal on the screen's
  const SB = { x0: 250, y0: 120, w: 50, h: 66 }, SA = new Float32Array(SB.w * SB.h);
  let steamWarm = [0, 0, 0], steamCool = [0, 0, 0];
  function drawSteam(u){
    for (const m of MUGS){
      const NP = 16, LIFE = 4.6;
      SA.fill(0);
      const sway = Math.sin(u * .31 + m.seed) * 1.6;
      const mark = (x, y, a) => {
        const bx = x - SB.x0, by = y - SB.y0;
        if (bx < 0 || by < 0 || bx >= SB.w || by >= SB.h) return;
        const k = by * SB.w + bx; if (a > SA[k]) SA[k] = a;
      };
      for (let p = 0; p < NP; p++){
        const age = ((u + p * LIFE / NP + m.seed * .37) % LIFE + LIFE) % LIFE, a = age / LIFE;
        const ph = hash(p * 3.1 + m.seed) * 6.28, env = Math.pow(Math.sin(Math.PI * Math.min(1, a * 1.25)), .7) * (1 - a * .35);
        for (let tr = 0; tr < 5; tr++){
          const ag = age - tr * .1; if (ag < 0) continue;
          const yy = Math.round(m.y - 2 - ag * 8.2);
          const amp = .5 + ag * 1.25;
          const xx = Math.round(m.x + amp * Math.sin(ag * 1.7 + ph + Math.sin(u * .45 + p) * .8) + ag * (.5 + sway * .25) - .5);
          const al = .62 * env * (1 - tr * .14);
          mark(xx, yy, al);
          if (ag > .5) mark(xx + 1, yy, al * .75);
          if (ag > 1.4){ mark(xx - 1, yy, al * .6); mark(xx, yy - 1, al * .6); }
          if (ag > 2.4){ mark(xx + 2, yy, al * .4); mark(xx - 2, yy + 1, al * .3); }
        }
      }
      const cx = m.x + 1;
      for (let by = 0; by < SB.h; by++) for (let bx = 0; bx < SB.w; bx++){
        const al0 = SA[by * SB.w + bx]; if (al0 <= .02) continue;
        const x = SB.x0 + bx, y = SB.y0 + by, i = y * W + x;
        if (glass[i]) continue;
        const al = Math.min(.56, Math.floor(al0 / .14 + bay(x, y)) * .14); if (al <= 0) continue;
        const j = i * 3, o = i * 4, warmSide = x <= cx;
        const t = warmSide ? steamWarm : steamCool;
        // steam scatters light: even over the dark wall it reads as a pale veil, brighter where the room is lit
        const sr = 150 * Math.min(M[j] * 1.4 + .4, 1.3) + t[0], sg = 156 * Math.min(M[j+1] * 1.4 + .4, 1.3) + t[1], sb = 162 * Math.min(M[j+2] * 1.4 + .4, 1.3) + t[2];
        // steam only ever lightens (it sat dark on the mug's bright rim)
        out[o] = Math.max(out[o], lerp(out[o], sr, al)); out[o+1] = Math.max(out[o+1], lerp(out[o+1], sg, al)); out[o+2] = Math.max(out[o+2], lerp(out[o+2], sb, al));
      }
    }
  }

  // the iron's smoke: one thin, slow thread, lit by whatever light is at that spot (mostly the screen)
  function drawWisp(m, u, k){
    const LIFE = m.life;
    for (let p = 0; p < m.np; p++){
      const age = ((u + p * LIFE / m.np + m.seed * .37) % LIFE + LIFE) % LIFE, a = age / LIFE;
      for (let tr = 0; tr < 3; tr++){
        const ag = age - tr * .15; if (ag < 0) continue;
        const yy = Math.round(m.y - ag * m.rise), amp = .3 + ag * .7;
        const xx = Math.round(m.x + amp * Math.sin(ag * 1.9 + m.seed + Math.sin(u * .35 + m.seed) * 1.4) + ag * .5);
        if (yy < 0 || yy >= H || xx < 0 || xx >= W) continue;
        const i = yy * W + xx; if (glass[i]) continue;
        const alpha = m.alpha * k * Math.pow(Math.sin(Math.PI * a), .9) * (1 - tr * .25);
        const j = i * 3, o = i * 4;
        const sr = 190 * Math.min(M[j] * 1.6 + .12, 1.2), sg = 200 * Math.min(M[j+1] * 1.6 + .12, 1.2), sb = 210 * Math.min(M[j+2] * 1.6 + .12, 1.2);
        out[o] = lerp(out[o], sr, alpha); out[o+1] = lerp(out[o+1], sg, alpha); out[o+2] = lerp(out[o+2], sb, alpha);
      }
    }
  }

  // ---------- the CRT: an old monitor that is never quite still ----------
  // Glitches: one per 5.5 s slot at a random moment in it (gaps 1.5-9.5 s), each a
  // different kind, never two at once. They run on the free clock C.
  const GL_SLOT = 5.5;
  function glitchAt(u){
    if (u < T.idle + 1.5 || LEAVING) return null;
    const v = C, si = Math.floor(v / GL_SLOT), ph = v - si * GL_SLOT;
    const at = .3 + hash(si * 4.1 + 2) * 4;
    const hk = hash(si * 6.7 + 9);
    // kinds: row jitter 34%, rgb split 26%, static band 28%, v-hold hiccup 12%
    const kind = hk < .5 ? 'jit' : hk < .88 ? 'rgb' : 'hold';   // static band removed (Jon)
    const dur = { jit: .26, rgb: .05, static: .65, hold: .2 }[kind];
    const a = ph - at;
    if (a < 0 || a >= dur) return null;
    return { kind, a, dur, si, y0: 8 + Math.floor(hash(si * 9.1) * 118), h: 3 + Math.floor(hash(si * 4.4) * 6) };
  }
  // smooth value noise on its own irregular clock
  function vnoise(t, seed){ const i = Math.floor(t), f = t - i, s = f * f * (3 - 2 * f); return lerp(hash(i * 1.91 + seed), hash((i + 1) * 1.91 + seed), s) * 2 - 1; }
  function crtState(u){
    let b = 1;
    if (u >= T.dot){
      // faint constant flicker (1-3%) on two irregular clocks
      b *= 1 + .014 * vnoise(C * 3.3, 11) + .009 * vnoise(C * 7.1, 23);
    }
    const ib = sat((u - T.idle + 1));
    b *= 1 + ib * (.04 * Math.sin(C * 2 * Math.PI / 9.3) + .02 * Math.sin(C * 2 * Math.PI / 3.7 + 1));
    const gl = glitchAt(u);
    if (gl){
      if (gl.kind === 'jit') b *= .95;
      else if (gl.kind === 'hold') b *= gl.a < .1 ? .88 : .95;
      else if (gl.kind === 'static') b *= 1.05;
      else if (gl.kind === 'rgb') b *= .96;
    }
    return { b, gl };
  }
  // Leaving runs the timeline backwards; the tube switches off its own way:
  // picture -> squeezed to a bright line -> line shrinks to a dot -> dot fades.
  const OFF = { pic: 4.6, squeeze: 3.6, line: 3.05, dot: 2.5 };
  function screenLevelLeaving(u){
    if (u >= OFF.pic) return .62;
    if (u >= OFF.squeeze) return lerp(.28, .62, (u - OFF.squeeze) / (OFF.pic - OFF.squeeze));
    if (u >= OFF.line) return lerp(.06, .22, (u - OFF.line) / (OFF.squeeze - OFF.line));
    if (u >= OFF.dot) return .08 * (u - OFF.dot) / (OFF.line - OFF.dot);
    return 0;
  }
  const GB = new Float32Array(GW * GH * 3);
  function drawGlass(u, bandY, crt, glare){
    const fd = ease(u / T.fade), off0 = [2 + 2 * fd, 3 + 3 * fd, 5 + 5 * fd];
    const Lr = lampState(u), refl = Lr.w * fd;
    const fr = Math.floor(C * 15);
    const gl = crt.gl;
    let rollOff = 0, rollGain = 1;
    if (!LEAVING && u >= T.roll && u < T.idle){
      const p = (u - T.roll) / (T.idle - T.roll);
      rollGain = 1 + .15 * (1 - p);              // the picture settles; the title's wipe brings it in (no roll)
    }
    if (gl && gl.kind === 'hold') rollOff = gl.a < .1 ? 2 : gl.a < .15 ? -1 : 1;   // hops, overshoots, settles
    const cxg = 75, cyg = 70;
    // phase: 0 off, 1 dot, 2 line, 3 raster opening, 4 boot text, 5 picture, 6 squeeze (leaving)
    let phase, pDot = 0, pLine = 0, pSq = 0;
    if (!LEAVING){
      phase = u < T.dot ? 0 : u < T.line ? 1 : u < T.open ? 2 : u < T.boot ? 3 : u < T.title ? 4 : u < T.roll ? 7 : 5;
      pDot = ease((u - T.dot) / .18); pLine = ease((u - T.line) / (T.open - T.line));
    } else {
      if (u >= OFF.pic) phase = 5;
      else if (u >= OFF.squeeze){ phase = 6; pSq = (u - OFF.squeeze) / (OFF.pic - OFF.squeeze); }
      else if (u >= OFF.line){ phase = 2; pLine = ease((u - OFF.line) / (OFF.squeeze - OFF.line)); }
      else if (u >= OFF.dot){ phase = 1; pDot = ease((u - OFF.dot) / (OFF.line - OFF.dot)); }
      else phase = 0;
    }
    // a faint interference line that drifts slowly up the glass
    const ifY = -99;   // interference line removed (Jon: looked bad)
    // a thin band of static rolling down (glitch)
    const stY = gl && gl.kind === 'static' ? -4 + (gl.a / gl.dur) * (GH + 8) : -99;
    let jitDx = 0;
    if (gl && gl.kind === 'jit'){ const q = Math.floor(gl.a * 16); jitDx = [1, -1, 2, -2, 1][Math.floor(hash(q * 3.3 + gl.si) * 5)]; }
    const rgb = gl && gl.kind === 'rgb';
    const span = GH + 8;
    const sample = (sy, sx, ch) => {
      sy = ((sy % span) + span) % span;
      if (sy >= GH || sx < 0 || sx >= GW) return 3 + ch;
      return cult[(sy * GW + sx) * 4 + ch];
    };
    const hhSq = 70 * Math.pow(pSq, 1.6);
    for (let y = 0; y < GH; y++){
      let rowG = 1;
      if (bandY > -100){ const db = Math.abs(y - bandY); rowG = db < 5 ? 1.14 : db < 11 ? 1.07 : 1; }
      if (y === ifY) rowG *= 1.06; else if (y === ifY + 1) rowG *= .95;
      const inJit = gl && gl.kind === 'jit' && y >= gl.y0 && y < gl.y0 + gl.h;
      const dx = inJit ? (y % 2 ? jitDx : Math.trunc(jitDx / 2)) : 0;
      const inStatic = Math.abs(y - stY) < 2;
      for (let x = 0; x < GW; x++){
        const k = (y * GW + x) * 3;
        let r = off0[0], g2 = off0[1], b = off0[2];
        if (phase === 1){
          const d = Math.hypot(x - cxg, y - cyg), p = pDot;
          const f = LEAVING ? bandStep(d, [[1.4, .7], [3.2 * p + .8, .25]], 1.2, bay(x, y)) * (.35 + .65 * p)   // the last bright dot, fading
                            : bandStep(d, [[1.2 * p + .3, .65], [3.5 * p, .25]], 1.2, bay(x, y));
          r += 220 * f; g2 += 240 * f; b += 250 * f;
        } else if (phase === 2){
          const p = pLine, hw = 2 + 73 * p;
          const ddx = Math.max(0, Math.abs(x - cxg + .5) - hw), dy = Math.abs(y - cyg + .5);
          const f = ddx > 0 ? 0 : bandStep(dy, [[1, .75], [3, .18]], 1, bay(x, y));
          r += 225 * f * (1 - .25 * p); g2 += 245 * f * (1 - .25 * p); b += 255 * f * (1 - .25 * p);
        } else if (phase === 3){
          const p = ease((u - T.open) / (T.boot - T.open)), hh = 1 + 69 * p;
          const dy = Math.abs(y - cyg + .5);
          if (dy < hh){
            const edge = dy > hh - 1.5 ? .5 : 0;
            const nz = hash(x * 13.1 + y * 71.7 + fr * 3.3) * .12;
            const lv = .55 * (1 - p) + .1 + nz + edge;
            r = 10 + 170 * lv; g2 = 14 + 195 * lv; b = 16 + 205 * lv;
          }
        } else if (phase === 4){
          r = 8; g2 = 14; b = 11;
        } else if (phase === 5){
          const sy = y + rollOff, sx = x - dx;
          if (rgb){ r = sample(sy, sx - 1, 0); g2 = sample(sy, sx, 1); b = sample(sy, sx + 1, 2); }
          else { r = sample(sy, sx, 0); g2 = sample(sy, sx, 1); b = sample(sy, sx, 2); }
          r *= rollGain; g2 *= rollGain; b *= rollGain;
        } else if (phase === 6){
          // the picture squeezes into a hot line as the deflection dies
          const dy = y - cyg + .5;
          if (Math.abs(dy) < Math.max(hhSq, 1)){
            const sy = Math.round(cyg + dy * 70 / Math.max(hhSq, 1));
            const w = 1 - pSq;
            r = lerp(sample(sy, x, 0), 230, w * .7) * (1 + w * .6);
            g2 = lerp(sample(sy, x, 1), 245, w * .7) * (1 + w * .6);
            b = lerp(sample(sy, x, 2), 255, w * .7) * (1 + w * .6);
          }
        }
        if (inStatic && phase === 5){
          const nz = hash(x * 7.3 + y * 31.1 + fr * 5.7);
          r = lerp(r, 40 + 150 * nz, .55); g2 = lerp(g2, 44 + 150 * nz, .55); b = lerp(b, 50 + 150 * nz, .55);
        }
        GB[k] = r * rowG; GB[k+1] = g2 * rowG; GB[k+2] = b * rowG;
      }
    }
    // boot lines, typed (into the glass buffer, so they glow too); never when leaving
    if (phase === 4){
      const gp = (x, y, r, g2, b) => { const k = (y * GW + x) * 3; GB[k] = r; GB[k+1] = g2; GB[k+2] = b; };
      for (const l of BOOT){
        for (let c = 0; c < l.px.length; c++){
          if (u < l.t + c * .05) break;
          for (const [px, py] of l.px[c]) gp(l.x + px, l.y + py, 140, 236, 172);
        }
      }
      const last = BOOT[BOOT.length - 1];
      if (u > last.t + last.s.length * .05 && Math.floor(C * 2.2) % 2 === 0){
        const cx0 = last.x + last.s.length * 4 + 1;
        for (let yy = 0; yy < 5; yy++) for (let xx = 0; xx < 3; xx++) gp(cx0 + xx, last.y + yy, 120, 220, 150);
      }
    }
    // the title card, and its wipe into the game (never when leaving)
    if (!LEAVING && u >= T.title && u < T.roll + DESK.TITLE.wipe){
      DESK.titleCard(GB, u - T.title, u < T.roll ? 0 : (u - T.roll) / DESK.TITLE.wipe);
    }
    // phosphor glow (bright content bleeds a little into its neighbours), then the
    // tube's shade (recess shadow, curved corners), its brightness, and reflections
    const bb = phase >= 1 ? crt.b : 1;
    for (let y = 0; y < GH; y++) for (let x = 0; x < GW; x++){
      const k = (y * GW + x) * 3;
      let r = GB[k], g2 = GB[k+1], b = GB[k+2];
      if (phase >= 1){
        let nr = 0, ng = 0, nb = 0, n = 0;
        if (x > 0){ nr += GB[k-3]; ng += GB[k-2]; nb += GB[k-1]; n++; }
        if (x < GW - 1){ nr += GB[k+3]; ng += GB[k+4]; nb += GB[k+5]; n++; }
        if (y > 0){ const q = k - GW * 3; nr += GB[q]; ng += GB[q+1]; nb += GB[q+2]; n++; }
        if (y < GH - 1){ const q = k + GW * 3; nr += GB[q]; ng += GB[q+1]; nb += GB[q+2]; n++; }
        nr /= n; ng /= n; nb /= n;
        r += Math.max(0, nr - r) * .22 + Math.max(0, nr - 120) * .06;
        g2 += Math.max(0, ng - g2) * .22 + Math.max(0, ng - 120) * .06;
        b += Math.max(0, nb - b) * .22 + Math.max(0, nb - 120) * .06;
      }
      const sh = glassShade[y * GW + x] * bb;
      r *= sh; g2 *= sh; b *= sh;
      // the lamp, reflected low on the left of the glass
      // the lamp, a faint warm smudge low on the left of the glass
      if (refl > 0 && x < 24 && y > 88 && y < 140){
        const dd = Math.hypot((x - 9) * 1.9, (y - 114) * .75);
        const f = bandStep(dd, [[4, .35], [9, .35], [15, .3]], 2.5, bay(x, y)) * refl;
        r += 9 * f; g2 += 6 * f; b += 2.5 * f;          // v5: barely there
      }
      // convex glass: a curved sheen across the top right that never moves with the picture
      // (v5: the fixed sheen is gone)
      put((GY + y) * W + GX + x, r, g2, b);
    }
  }
  // the opening is a hole the glass sits behind: the inner lip facing the lamp
  // (right, and the top) catches light, the lips facing away (left, bottom) go dark
  function drawLips(lw){
    const warm = 18 * sat(lw);
    const tape = i => { const r = A[i*3], g2 = A[i*3+1], b = A[i*3+2]; return Math.max(r, g2, b) - Math.min(r, g2, b) > 70; };
    const mul = (i, m, add) => { if (tape(i)) return; const o = i * 4; out[o] = out[o] * m + add; out[o+1] = out[o+1] * m + add * .78; out[o+2] = out[o+2] * m + add * .5; };
    for (let y = GY - 1; y <= GY + GH; y++){
      mul(y * W + GX + GW, 1.3, warm);          // right lip, faces the lamp
      mul(y * W + GX + GW + 1, 1.1, warm * .4);
      mul(y * W + GX - 1, .5, 0);               // left lip, in its own shadow
      mul(y * W + GX - 2, .78, 0);
    }
    for (let x = GX; x < GX + GW; x++){
      mul((GY - 1) * W + x, 1.15, warm * .5);   // top lip
      mul((GY + GH) * W + x, .58, 0);           // bottom lip
      mul((GY + GH + 1) * W + x, .84, 0);
    }
  }
  // scanlines: the tube's raster, drawn on the 5x canvas (a dark screen row per art row)
  function drawScanlines(g, u){
    if (u < (LEAVING ? OFF.dot : T.dot)) return;
    g.fillStyle = 'rgba(0,0,0,.34)';
    for (let y = 0; y < GH; y++) g.fillRect(GX * S, (GY + y) * S + S - 1, GW * S, 1);
    g.fillStyle = 'rgba(0,0,0,.12)';
    for (let y = 0; y < GH; y++) g.fillRect(GX * S, (GY + y) * S, GW * S, 1);
  }

  function debugPaint(g){
    g.fillStyle = 'rgba(255,0,255,.85)';
    const sets = [bulbPx, portGlass, pipeLed].concat(strings.map(s => s.px));
    for (const set of sets) for (const i of set) g.fillRect((i % W) * S, ((i / W) | 0) * S, S, S);
    g.fillStyle = 'rgba(0,255,255,.9)';
    for (const i of filPx) g.fillRect((i % W) * S, ((i / W) | 0) * S, S, S);
    g.fillStyle = 'rgba(255,255,0,.9)';
    for (const [x, y] of SOLDER_LED.concat(MON_LED)) g.fillRect(x * S, y * S, S, S);
  }

  // =====================================================================================================
  // LIGHTING: C (Jon's pick, Nov 18: "hand-shaded ramps: A's light, but every colour steps along its own ramp,
  // cool and violet in shadow, warm where lit"), now the room's only light, on the shared engine in
  // roomfx.js (ROOMFX.makeLit). Nov 18 (Jon: "the lights are square in some spots"): option C took the lamp
  // from option A, which switched from a wall shape to a desk shape at row 169 (a straight edge across the book
  // stack), cut its shadows at fixed rows, halved it inside the monitor's bounding box, and took the screen's
  // spill from the 10x pass, which was built from rectangles round the case. Now every light falls off by
  // distance and angle from its source in the room's own space, props are flood-filled, and the C ramp steps
  // the summed light, so every band edge follows the light.
  // Each light keeps [steady, flicker]: the power-on sets the steady weights (composed and stepped once, cached
  // by a key); the tired-bulb flicker, the string twinkle and the tube's life only multiply afterwards.
  // =====================================================================================================
  const D2R = Math.PI / 180;
  const KB_POLY = [[140,185],[246,185],[250,210],[135,210]];
  let LIT = null, CC = {}, FAc, A2c, FLD = {}, SMALL = [], DUSTc, SKYc, Lc, KBd;
  function buildC(){
    const FX = window.ROOMFX;
    // ---- the keyboard, drawn in code over the old one's footprint (Jon: "flat and dimensionless") ----
    const fp = FX.findKeyboard(A, W, H, KB_POLY, [192, 197], 22);
    const deskAt = (x, y) => { for (let r = 1; r < 12; r++) for (const xx of [x - r, x + r]){ const i = y * W + xx;
      if (xx >= 0 && xx < W && !fp.m[i]) return [A[i*3], A[i*3+1], A[i*3+2]]; } return [93, 102, 112]; };
    KBd = FX.drawKeyboard(A, W, H, fp, { pal: FX.kbPalette([176, 168, 164]), lay: FX.KB_FULL, seed: 1, desk: deskAt,
      rim: 1, bezel: 0, rows: [[1,1,1],[2,1,1],[2,1,1],[2,1,1],[2,1,1],[2,1,0]], fbezel: 1, face: 1, side: 2 });
    // ---- props, flood-filled from inside each (never a box) ----
    const L = i => lum(i), inB = (i, b) => { const x = i % W, y = (i / W) | 0; return x >= b[0] && x <= b[2] && y >= b[1] && y <= b[3]; };
    const MON = FX.propMask(A, W, H, [104, 6, 279, 184], [110, 100], i => { const x = i % W, y = (i / W) | 0;
      return !glass[i] && L(i) >= 50 && (y <= 176 || (x >= 178 && x <= 208)); }, 26);
    const STK = FX.propMask(A, W, H, [10, 112, 82, 200], [40, 180], i => L(i) >= 34 && !(A[i*3+2] > A[i*3] + 4 && L(i) < 50), 24);
    const ROB = FX.propMask(A, W, H, [34, 112, 60, 152], [47, 138], i => L(i) >= 34 && !(A[i*3+2] > A[i*3] + 4 && L(i) < 50), 24);
    for (let i = 0; i < N; i++) if (ROB[i]) STK[i] = 1;                       // the robot stands on the stack
    const LMP = FX.propMask(A, W, H, [70, 108, 102, 180], [85, 160], i => L(i) >= 40 && !(A[i*3+2] > A[i*3] + 4 && L(i) < 56), 24);
    const MUGm = FX.propMask(A, W, H, [260, 174, 291, 210], [272, 195], i => A[i*3] >= A[i*3+2] - 5 && L(i) >= 36, 20);
    const CUPm = FX.propMask(A, W, H, [292, 128, 320, 181], [305, 170], i => L(i) >= 40 && !(A[i*3+2] > A[i*3] + 4 && L(i) < 56), 24);
    const SLD = FX.propMask(A, W, H, [316, 132, 364, 188], [336, 180], i => L(i) >= 40 && !(A[i*3+2] > A[i*3] + 4 && L(i) < 56), 24);
    CC.masks = { MON, STK, LMP, MUGm, CUPm, SLD };
    const skip = new Uint8Array(N);
    for (let i = 0; i < N; i++) if (glass[i]) skip[i] = 1;
    for (const i of portGlass) skip[i] = 1;
    LIT = FX.makeLit({ W, H, A, skip, deskY: 169, deskF: 208, kz: 3, kb: KBd,
      props: [ { m: MON, foot: 183, deep: 40, up: .15, contact: false, bounce: .25, wrap: 0, gain: .6 },     // 0 the monitor: a deep box
               { m: STK, foot: 197, heavy: true, bounce: .3 },                          // 1 the book stack and the robot on it
               { m: LMP, foot: 178, up: .05, wrap: 0, bounce: .35 },        // 2 the lamp (its stem sits under its own shade)
               { m: MUGm, foot: 208, heavy: true, cyl: true, up: .2 },       // 3 the mug, a cylinder
               { m: CUPm, foot: 179, cyl: true },                           // 4 the plant tin
               { m: SLD, foot: 186 } ] });                                  // 5 the soldering station
    // ---- the lights ----
    // the lamp: the bulb up in the dome; light leaves the dome's mouth down and a little forward
    FLD.lamp = LIT.norm(LIT.point({ x: 85, y: 131, z: 27, I: 1, r0: 30, rMax: 300, axis: [0, -.96, .28],
      cosIn: Math.cos(58 * D2R), cosOut: Math.cos(86 * D2R), spill: .1, wrap: .15, occ: [0, 1, 3, 4, 5], spread: 12, samples: 5 }), 86, 183, 1);
    // the screen: a panel of light at the glass, facing the room; the props on the desk cast its shadows
    FLD.scr = LIT.norm(LIT.panel({ rect: [118, 23, 265, 160], z: 22, I: 1, r0: 200, rMax: 380, nx: 6, ny: 4, wrap: .1, occ: [1, 2, 3, 4, 5] }), 124, 203, 1.1);
    // the porthole: starlight off a small disc on the wall
    FLD.port = LIT.norm(LIT.panel({ rect: [298, 10, 325, 37], z: 3, I: 1, r0: 30, rMax: 150, nx: 4, ny: 4, wrap: .6, disc: true }), 311, 44, .2);
    // string bulbs: each a small point a few px off the wall; its halo falls further down the wall than up
    SMALL = strings.map(s => { const b = LIT.pointBox({ x: s.x + .5, y: s.y + .5, z: 5, I: 1, r0: 5, rMax: 24, wrap: .8, squash: .62, bounce: false });
      let mx = 0; for (const v of b.f) mx = Math.max(mx, v); if (mx > 0) for (let k = 0; k < b.f.length; k++) b.f[k] *= .7 / mx; return b; });
    // ---- the room: darker toward its edges (an ellipse, dithered steps) and under the desk's front lip ----
    FAc = new Float32Array(N);
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++){
      const i = y * W + x, q = ((x - 192) / 235) ** 2 + ((y - 112) / 150) ** 2 + (bay(x, y) - .5) * .1;
      let a = q < .5 ? 1 : q < .8 ? .74 : q < 1.15 ? .54 : .4;
      if (y >= 209) a *= y >= 212 ? .45 : .65;
      FAc[i] = a;
    }
    // settled dust on the desk top (lit with everything else, so it shows only in the light)
    A2c = FX.settleDust(A, W, H, { seed: 3, density: .045, amount: .2,
      mask: (x, y) => { const i = y * W + x; return y >= 170 && y <= 208 && !glass[i] && !KBd.part[i] && L(i) > 45 && L(i) < 205; } });
    // dust in the air: denser and brighter where the light is
    DUSTc = FX.makeDust({ W, H, count: 130, seed: 5, box: [2, 4, 380, 210],
      density: (x, y) => { const i = y * W + x; return .1 + .9 * sat(FLD.lamp[i] * .9 + FLD.scr[i] * 1.1); },
      skip: i => glass[i] === 1 });
    SKYc = FX.makeSky({ W, idx: portGlass, cx: 311.5, cy: 22.5, r: 12, seed: 1 });
    (window.__C = window.__C || {}).desk_1 = { LIT, FLD, KB: KBd };
    Lc = new Float32Array(N * 3);
    LIT.A = A2c;
  }

  function frameC(g, t, info){
    if (DESK.act1(g, t, local)) return;
    const u = t - DESK.ACT1.black;
    LEAVING = !!(info && info.leaving);
    C = info && info.real != null ? info.real - DESK.ACT1.black : u;
    const FX = window.ROOMFX;
    const fade = ease(u / T.fade);
    const L = lampState(u);
    // the lamp's weight = [steady, flicker]: the strike and warm-up are steady; the tired bulb and the
    // brown-outs are flicker, multiplied in after the light is composed and stepped
    const steadyL = Math.pow(L.fil, 1.25);
    const flickL = (1 - L.brown) * (u > 1.4 ? FX.tiredBulb(C, 3, { depth: 1.2 }) : 1);
    const kq = Math.round(L.k * 12) / 12;
    const lampCol = [1, lerp(.42, .72, kq), lerp(.12, .4, kq)];
    const sLv = strings.map(s => stringLevel(s, u));
    const son = sLv.map(v => v > 0 ? 1 : 0);
    const sFl = sLv.map((v, n) => v > 0 ? Math.min(v, 1.35) * FX.tiredBulb(C, 50 + n * 7, { depth: .9, every: 5 + (n % 4), stutterEvery: 23 + n }) : 0);
    const scr = LEAVING ? screenLevelLeaving(u) : screenLevel(u);
    const crt = crtState(u);
    const bootTint = (!LEAVING && u >= T.boot && u < T.roll) ? 1 : 0;
    const mc = bootTint ? [.45, 1, .7] : [.55, 1, .89];
    const stL = Math.round(steadyL * fade * 24) / 24, stS = Math.round(scr * 32) / 32, stF = Math.round(fade * 24) / 24;
    const key = [stL, stS, stF, son.join(''), kq, bootTint].join('|');
    if (!CC.S || CC.key !== key){
      const tl = [lerp(1, lampCol[0], .7), lerp(1, lampCol[1], .7), lerp(1, lampCol[2], .7)];
      const tm = [lerp(1, mc[0], .5), lerp(1, mc[1], .5), lerp(1, mc[2], .5)];
      CC.S = LIT.compose({ A: A2c, amb: [.17, .18, .23], fa: FAc, fade: stF, ov: .3, hot: 6, hotCol: lampCol,
        big: [ { F: FLD.lamp, w: stL * 1.3, tint: tl, ch: 0 },
               { F: FLD.scr, w: stS * 1.05, tint: tm, ch: 1 },
               { F: FLD.port, w: .6 * stF, tint: [.8, .88, 1], ch: 2 } ],
        small: SMALL.map((b, n) => ({ f: b.f, box: b.box, w: son[n] * 1.3 * stF, tint: [1, .82, .62] })) });
      CC.key = key;
    }
    // per frame: the flicker of each light multiplies its share of the stepped light; the LEDs glow on top
    const fM = crt.b * crt.b;
    LIT.frame(CC.S, out, { lamp: flickL, scr: fM, small: sFl.map((v, n) => son[n] ? v : 1) }, Lc);
    M.fill(0); Ad.fill(0);
    const pipeOn = pipeLedLevel(u), solderOn = solderLevel(u), monOn = u >= T.monLed ? 1 : 0;
    addGlow(39, 95, pipeOn * .9, [1, .55, .15], 4.5);
    addGlow(340.5, 163, solderOn * .8, [1, .18, .1], 3.5);
    const tipOn = ease((u - T.solder - .3) / 1.2) * (1 + .07 * vnoise(C * 5.3, 41) + .04 * vnoise(C * 13.1, 43)) * fade;
    addGlow(TIPC.x, TIPC.y, tipOn * .75, [1, .42, .12], 5);
    addGlow(TIPC.x, TIPC.y + 2, tipOn * .3, [1, .45, .15], 11);
    addGlow(128.5, 169.5, monOn * .6, [.35, 1, .45], 3);
    for (let i = 0, j = 0; i < N; i++, j += 3){
      if (glass[i]) continue;
      const o4 = i * 4, gr = M[j], gg = M[j+1], gb = M[j+2];
      if (gr || gg || gb || Ad[j] || Ad[j+1] || Ad[j+2]){
        out[o4] += A2c[j] * gr + Ad[j]; out[o4+1] += A2c[j+1] * gg + Ad[j+1]; out[o4+2] += A2c[j+2] * gb + Ad[j+2]; }
      M[j] = Lc[j] + gr; M[j+1] = Lc[j+1] + gg; M[j+2] = Lc[j+2] + gb;     // the room's light, for steam and dust
    }
    const lwf = steadyL * flickL * fade;
    for (const [x, y] of TIP){ const i = y * W + x, k = sat(tipOn);
      put(i, lerp(out[i*4], 255, k), lerp(out[i*4+1], 150 + 40 * (tipOn - 1 + .1), k), lerp(out[i*4+2], 60, k)); }
    drawBulb(u, Object.assign({}, L, { w: steadyL * flickL }), fade);
    drawStrings(sFl, fade);
    drawLeds(pipeOn, solderOn, monOn);
    FX.drawSky(SKYc, put, C, 1);
    steamWarm = [44 * lwf * lampCol[0], 44 * lwf * lampCol[1], 44 * lwf * lampCol[2]];
    steamCool = [46 * scr * fM * mc[0], 46 * scr * fM * mc[1], 46 * scr * fM * mc[2]];
    drawSteam(C);
    if (tipOn > .05) drawWisp(SMOKE, C, sat(tipOn));
    // dust: lit by the light where each mote is ("more dust overall")
    FX.drawDust(DUSTc, out, C, i => [M[i*3], M[i*3+1], M[i*3+2]], 72, .03, fade);
    drawLips(lwf);
    drawGlass(u, -999, crt, sat(.55 * sat(steadyL) + .45 * (son.reduce((a, b) => a + b, 0) / strings.length)) * fade);
    octx.putImageData(odata, 0, 0);
    g.imageSmoothingEnabled = false;
    g.drawImage(off, 0, 0, W * S, H * S);
    drawScanlines(g, u);
    if (window.__deskC) window.__deskC.desk_1 = { LIT, CC, FLD, KBd, W, H };
  }

  function init(){
    return built || (built = (async () => {
      [local, artImg, cultImg] = await Promise.all([
        DESK.img('assets/local.png'), DESK.img('assets/desk_1_clean.png'), DESK.img('assets/screen_culture.png')]);
      build();
    })());
  }
  let built = null;
  // Nov 18: C is the room's only light (Jon's pick); the 10x, normal-map, simple and A/B variants are gone
  // (backups: desk_1.bak-options.js, desk_1.bak-keys.js)
  DESK.register({ id: 'desk_1', name: 'DESK 1', line: 'Hand-shaded light: cool in shadow, warm where lit.', section: 'lit', init, doneAt: 11.8,
    times: { lamp: DESK.ACT1.black + T.click, crt: DESK.ACT1.black + T.dot }, frame: frameC });
})();
