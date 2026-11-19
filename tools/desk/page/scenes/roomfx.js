// ROOMFX: small room effects meant for every desk room (only the desk 1 lighting options use them so far).
//   tiredBulb(C, seed, o)       a lamp's flicker: a brightness multiplier, mostly 1
//   makeDust(o) / drawDust(...)  motes drifting in the room's air, lit by the light where they are
//   settleDust(A, W, H, o)       faint settled specks on a surface, baked into a copy of the art
//   makeSky(o) / drawSky(...)    a porthole that is a living window: parallax stars, twinkle, rare passers-by
// All of it works at art resolution (one value per art pixel, which is 2x2 screen pixels in the game),
// moves in whole pixels, and runs on the scene's free clock C (seconds), so it never jitters or crawls.
window.ROOMFX = (function(){
  const hash = n => { const s = Math.sin(n * 12.9898 + 78.233) * 43758.5453; return s - Math.floor(s); };
  const sat = v => v < 0 ? 0 : v > 1 ? 1 : v;
  const lerp = (a, b, k) => a + (b - a) * k;
  const vnoise = (t, seed) => { const i = Math.floor(t), f = t - i, s = f * f * (3 - 2 * f);
    return lerp(hash(i * 1.91 + seed), hash((i + 1) * 1.91 + seed), s) * 2 - 1; };
  const BAYER = [0,8,2,10,12,4,14,6,3,11,1,9,15,7,13,5].map(v => (v + .5) / 16);
  const bay = (x, y) => BAYER[(y & 3) * 4 + (x & 3)];

  // ---------- flicker: a tired bulb ----------
  // Mostly steady. A slow irregular waver of a percent or two, a small eased dip (5-11%, a quarter to half a
  // second) at a random moment in each `every`-second slot, and in about half of the `stutterEvery` slots a
  // quick stutter: two or three fast drops inside a third of a second. Each seed is its own clock.
  // Use it as the light's flicker part only: the steady part (the power-on) sets where stepped bands fall,
  // and this multiplies brightness after the stepping, so no band edge ever moves.
  function tiredBulb(C, seed, o){
    o = o || {};
    const depth = o.depth == null ? 1 : o.depth, P = o.every || 6.5, P2 = o.stutterEvery || 19;
    const Cs = C + hash(seed * 1.37) * 97;
    let m = 1 + depth * (.012 * vnoise(Cs * 1.3, seed) + .008 * vnoise(Cs * 3.7, seed + 5));
    { const ci = Math.floor(Cs / P), at = hash(ci * 3.1 + seed) * (P - 1), a = Cs - ci * P - at, len = .25 + hash(ci * 1.7 + seed) * .3;
      if (a > 0 && a < len) m *= 1 - depth * (.05 + hash(ci * 5.3 + seed) * .06) * Math.sin(Math.PI * a / len); }
    { const ci = Math.floor(Cs / P2);
      if (hash(ci * 7.7 + seed * 2.3) < .55){
        const a = Cs - ci * P2 - (1 + hash(ci * 4.9 + seed) * (P2 - 2));
        if (a > 0 && a < .34){
          const n3 = hash(ci * 2.2 + seed) < .5;
          if (a < .05) m *= 1 - depth * .28;
          else if (a > .1 && a < .14) m *= 1 - depth * .16;
          else if (n3 && a > .22 && a < .26) m *= 1 - depth * .1;
        }
      }
    }
    return m;
  }

  // ---------- dust in the air ----------
  // o: { W, H, count, box:[x0,y0,x1,y1], seed, density(x,y) -> 0..1 (spawn weight; denser where it is high),
  //      skip(i) -> true where no mote may sit (the glass) }
  // Each mote lives `life` seconds, fades in and out (eased), drifts slowly (a fraction of a pixel a second)
  // on a gentle sway, and is drawn at whole art pixels. One in four is a two-pixel fleck.
  function makeDust(o){
    const motes = [], [x0, y0, x1, y1] = o.box;
    let k = 0, tries = 0;
    while (motes.length < o.count && tries < o.count * 60){
      tries++;
      const x = x0 + hash(o.seed * 31 + tries * 1.37) * (x1 - x0), y = y0 + hash(o.seed * 17 + tries * 2.91) * (y1 - y0);
      const d = o.density ? o.density(x | 0, y | 0) : 1;
      if (hash(o.seed * 7 + tries * 5.13) > d) continue;
      k++;
      motes.push({ x, y, life: 6 + hash(k * 5.1 + o.seed) * 7, off: hash(k * 9.3 + o.seed) * 20,
        vx: (hash(k * 2.3 + o.seed) - .5) * .5, vy: .05 + (hash(k * 3.9 + o.seed) - .35) * .45,     // most settle, a few rise in the warm air
        ax: .8 + hash(k * 4.4 + o.seed) * 1.8, px: 5 + hash(k * 6.6 + o.seed) * 6, ph: hash(k * 1.9 + o.seed) * 6.28,
        fleck: hash(k * 8.8 + o.seed) < .25, gain: .6 + hash(k * 7.2 + o.seed) * .4 });
    }
    return { motes, W: o.W, H: o.H, skip: o.skip };
  }
  // out: Uint8ClampedArray RGBA (W*H*4). light(i) -> [r, g, b] the light at that pixel (multipliers, ~0.1 dark .. ~1.5 lit).
  // amt: how bright a mote in full light is (added, scaled by the light's own colour). floor: how much of a mote shows in the dark.
  function drawDust(D, out, C, light, amt, floor, fade){
    const W = D.W, H = D.H;
    for (const m of D.motes){
      const age = ((C + m.off) % m.life + m.life) % m.life, p = age / m.life;
      const env = Math.pow(Math.sin(Math.PI * p), 1.6) * (fade == null ? 1 : fade);
      if (env < .02) continue;
      const x = Math.round(m.x + m.vx * age + m.ax * Math.sin(age * 6.283 / m.px + m.ph));
      const y = Math.round(m.y + m.vy * age + .6 * Math.sin(age * 6.283 / (m.px * 1.7) + m.ph * 2));
      if (x < 0 || y < 0 || x >= W - 1 || y >= H) continue;
      const i = y * W + x; if (D.skip && D.skip(i)) continue;
      const L = light(i), lv = (L[0] + L[1] + L[2]) / 3;
      const b = env * m.gain * (floor + lv * lv) * amt;
      if (b < 1) continue;
      const nr = L[0] / (lv || 1), ng = L[1] / (lv || 1), nb = L[2] / (lv || 1);
      const o4 = i * 4; out[o4] += b * nr; out[o4+1] += b * ng; out[o4+2] += b * nb;
      if (m.fleck && !(D.skip && D.skip(i + 1))){ const o2 = o4 + 4, b2 = b * .45; out[o2] += b2 * nr; out[o2+1] += b2 * ng; out[o2+2] += b2 * nb; }
    }
  }

  // ---------- dust settled on surfaces ----------
  // Returns a copy of the art (Float32 RGB) with faint pale specks on pixels where mask(x, y) is true.
  // The specks are lit with everything else, so they only show where light falls.
  function settleDust(A, W, H, o){
    const B = Float32Array.from(A), d = o.density || .03, k = o.amount || .16;
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++){
      if (!o.mask(x, y)) continue;
      const h = hash(x * 3.17 + y * 7.71 + (o.seed || 0));
      if (h > d) continue;
      const i = (y * W + x) * 3, kk = k * (h < d * .3 ? 1.4 : 1);
      B[i] = lerp(B[i], 168, kk); B[i+1] = lerp(B[i+1], 164, kk); B[i+2] = lerp(B[i+2], 156, kk);
    }
    return B;
  }

  // ---------- a living porthole ----------
  // o: { W, idx: [pixel indices of the window's glass], cx, cy, r (glass radius), seed }
  // Three star layers drift in one direction at three speeds as the ship turns (far dim stars barely move,
  // near bright ones cross in about a minute), a few bright stars twinkle in held steps, and now and then
  // one thing passes: a far ship with a blinking nav light, a tumbling piece of debris that catches the sun,
  // a slow meteor, or (on its own long clock) a moon's lit limb edging into view and back out.
  function makeSky(o){
    const set = new Set(o.idx), stars = [], S = 2 * o.r + 6;          // stars live on an S x S tile that wraps
    const layer = (n, b0, b1, spd, tw, seed) => { for (let k = 0; k < n; k++) stars.push({
      x: hash(k * 3.7 + seed) * S, y: hash(k * 5.3 + seed + 1) * S, b: b0 + hash(k * 7.9 + seed) * (b1 - b0), spd,
      tw: tw && hash(k * 2.1 + seed) < .6, per: .4 + hash(k * 4.2 + seed) * .5, ph: hash(k * 9.9 + seed) * 10,
      tint: hash(k * 6.1 + seed) }); };
    layer(18, .16, .3, .05, false, 11);
    layer(9, .38, .6, .14, true, 23);
    layer(4, .7, 1, .33, true, 37);
    return { o, set, stars, S };
  }
  function drawSky(K, put, C, fade){
    const o = K.o, W = o.W, f = fade == null ? 1 : fade, S = K.S;
    const ox = o.cx - S / 2, oy = o.cy - S / 2;
    const col = new Map();                     // pixel -> [r,g,b], so later layers paint over earlier ones
    const set = (x, y, r, g, b) => { const i = y * W + x; if (K.set.has(i)) col.set(i, [r, g, b]); };
    const add = (x, y, r, g, b) => { const i = y * W + x; if (!K.set.has(i)) return; const c = col.get(i) || base(i); col.set(i, [c[0] + r, c[1] + g, c[2] + b]); };
    function base(i){ const x = i % W, y = (i / W) | 0, dn = Math.hypot(x - (o.cx - 5), y - (o.cy + 5));
      const neb = dn < 5 ? .5 : dn < 9 && bay(x, y) < .5 ? .5 : 0;
      return [5 + neb * 9, 8 + neb * 6, 18 + neb * 14]; }
    for (const i of o.idx) col.set(i, base(i));
    // the moon: once every 150 s, for 50 s, a big disc's lit limb edges in at a lower corner (a third of the
    // window at most, about a pixel every 1.5 s) and back out
    const MP = 150, mc = Math.floor(C / MP), ma = C - mc * MP - 100;
    let moon = null;
    if (ma > 0 && ma < 50){
      const k = Math.sin(Math.PI * ma / 50), R = 26, dir = hash(mc * 3.3 + 1) < .5 ? 1 : -1;
      const dd = R + o.r + 3 - k * 11;                                   // centre distance: outside -> 8 px into the glass
      moon = { x: Math.round(o.cx + dir * .6 * dd), y: Math.round(o.cy + .8 * dd), R, dir };
    }
    // stars, far to near; the moon hides the ones behind it
    for (const s of K.stars){
      const x = Math.round(ox + (((s.x - C * s.spd) % S) + S) % S), y = Math.round(oy + (((s.y + C * s.spd * .3) % S) + S) % S);
      if (moon && Math.hypot(x - moon.x, y - moon.y) < moon.R) continue;
      let v = s.b;
      if (s.tw){ const n = Math.floor(C / s.per + s.ph), h = hash(n * 13.1 + s.x * 3 + s.y);
        v *= h < .18 ? .45 : h < .7 ? .85 : 1.12; }
      v = Math.min(1.1, v);
      const warm = s.tint < .2, blue = s.tint > .85;
      set(x, y, 30 + 215 * v * (warm ? 1 : .92), 34 + 205 * v * (warm ? .86 : .95), 46 + 200 * v * (blue ? 1.05 : warm ? .7 : 1));
    }
    if (moon){
      // a grey-blue moon lit from the upper left: a bright thin limb, a grey face with two darker seas, a dark side
      for (const i of o.idx){
        const x = i % W, y = (i / W) | 0, dx = x - moon.x, dy = y - moon.y, d = Math.hypot(dx, dy);
        if (d >= moon.R) continue;
        const lit = (-dx * .6 - dy * .8) / moon.R;                       // toward the sun
        const sea = Math.hypot(dx + 8 * moon.dir, dy + 12) < 5 || Math.hypot(dx + 2 * moon.dir, dy + 19) < 3.5;
        let r, g, b;
        if (d > moon.R - 1.5 && lit > .1){ r = 196; g = 200; b = 206; }
        else if (lit > .25 + (bay(x, y) - .5) * .12){ r = sea ? 92 : 128; g = sea ? 96 : 132; b = sea ? 106 : 140; }
        else if (lit > .05){ r = sea ? 54 : 74; g = sea ? 58 : 78; b = sea ? 70 : 90; }
        else { r = 16; g = 19; b = 28; }
        col.set(i, [r, g, b]);
      }
    }
    // passers-by: one per 12 s slot, at most (about two slots in three have one)
    const P = 12, sn = Math.floor(C / P), st = C - sn * P, kh = hash(sn * 5.7 + 2);
    const along = (k, y0, slope, dir) => [Math.round(o.cx + dir * (-o.r - 2 + (2 * o.r + 4) * k)), Math.round(y0 + slope * k)];
    if (!moon && kh < .3){                 // a far ship, about 3 px a second, a white light that blinks red
      const dur = 9, k = st / dur;
      if (k < 1){ const dir = hash(sn * 2.9) < .5 ? 1 : -1, [x, y] = along(k, o.cy - 6 + hash(sn * 4.3) * 10, 4 - hash(sn) * 8, dir);
        const red = (st % 1.3) < .22;
        set(x, y, red ? 255 : 196, red ? 84 : 206, red ? 70 : 222);
        if (!red) add(x - dir, y, 26, 30, 38); }
    } else if (kh < .55){                  // tumbling debris: a 2-px chunk, dull, flashing as a face turns to the sun
      const dur = 10, k = st / dur;
      if (k < 1){ const dir = hash(sn * 3.1) < .5 ? 1 : -1, [x, y] = along(k, o.cy - 8 + hash(sn * 6.1) * 14, 3 - hash(sn * 2) * 6, dir);
        const tum = ((st % 1.4) + 1.4) % 1.4, flash = tum < .12 ? 1 : tum < .25 ? .55 : .18;
        const c = 60 + 190 * flash;
        set(x, y, c, c * .97, c * .9);
        if (tum > .7) set(x + 1, y, 70, 68, 64); else set(x, y + 1, 52, 50, 48); }
    } else if (kh < .66 && !moon){         // a slow meteor: a bright head and a short fading tail, under a second
      const dur = .9, a = st - 4 - hash(sn * 8.1) * 4;
      if (a > 0 && a < dur){ const k = a / dur, dir = hash(sn * 1.3) < .5 ? 1 : -1;
        const hx = o.cx + dir * (-o.r + 2 * o.r * k), hy = o.cy - o.r * .6 + o.r * 1.1 * k;
        for (let tl = 0; tl < 4; tl++){ const x = Math.round(hx - dir * tl * 1.4), y = Math.round(hy - tl * .8), v = (1 - tl / 4) * Math.sin(Math.PI * k) ** .5;
          add(x, y, 210 * v, 215 * v, 200 * v); } }
    }
    for (const [i, c] of col) put(i, Math.min(255, c[0]) * f, Math.min(255, c[1]) * f, Math.min(255, c[2]) * f);
  }


  // =====================================================================================================
  // Nov 18. A prop's mask, a keyboard drawn in code, and the C lighting (Jon's pick) for every room.
  // =====================================================================================================

  // ---------- a prop's own pixels ----------
  // Its body flood-filled from a seed inside it (body(i) true), then the dark outline that touches the body
  // (luminance <= lineMax), then every hole the body encloses (not reachable from the box's border).
  // A: Float32 RGB 3N. Returns Uint8 N.
  function propMask(A, W, H, box, seed, body, lineMax){
    const N = W * H, [x0, y0, x1, y1] = box, m = new Uint8Array(N);
    const inb = (x, y) => x >= x0 && x <= x1 && y >= y0 && y <= y1;
    const L = i => .3 * A[i*3] + .59 * A[i*3+1] + .11 * A[i*3+2];
    const st = [seed];
    while (st.length){ const [x, y] = st.pop(); if (!inb(x, y)) continue; const i = y * W + x;
      if (m[i] || !body(i)) continue; m[i] = 1; st.push([x+1, y], [x-1, y], [x, y+1], [x, y-1]); }
    if (lineMax != null) for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++){
      const i = y * W + x; if (m[i] || L(i) > lineMax) continue;
      for (let dy = -1; dy <= 1 && !m[i]; dy++) for (let dx = -1; dx <= 1; dx++)
        if (inb(x + dx, y + dy) && m[(y + dy) * W + x + dx] === 1){ m[i] = 2; break; }
    }
    const out = new Uint8Array(N), q = [];
    for (let x = x0; x <= x1; x++) q.push([x, y0], [x, y1]);
    for (let y = y0; y <= y1; y++) q.push([x0, y], [x1, y]);
    while (q.length){ const [x, y] = q.pop(); if (!inb(x, y)) continue; const i = y * W + x;
      if (out[i] || m[i]) continue; out[i] = 1; q.push([x+1, y], [x-1, y], [x, y+1], [x, y-1]); }
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++){ const i = y * W + x; if (!m[i] && !out[i]) m[i] = 1; }
    for (let i = 0; i < N; i++) if (m[i]) m[i] = 1;
    return m;
  }

  // ---------- the keyboard, drawn in code ----------
  // Why (Jon, Nov 18: "flat and dimensionless"): every key in the art is one flat grey (luminance 145, the same
  // on its top row as its bottom row) over a 1 px darker line, seen straight down. Nothing says a key has a top
  // and a front, or that the board has a case with a front face standing on the desk. So the board is redrawn
  // over its footprint: rows of keycaps, each a lit top face (its back edge catching the screen behind it), a
  // darker front lip, a dark well between rows and a dark gap between keys; a case with a bright back rim, side
  // bevels, a front face and a dark bottom edge; a contact shadow on the desk. Every pixel also gets a normal,
  // so the room's lights shade the tops, lips and faces differently.
  // Layout units: [kind, width in key units]; kinds: a alpha, m modifier, x accent, s space, g gap.
  const rep = (n, k, u) => Array.from({ length: n }, () => [k, u || 1]);
  const KB_FULL = {
    main: [
      [['x', 1], ['g', .75]].concat(rep(4, 'm'), [['g', .5]], rep(4, 'm'), [['g', .5]], rep(4, 'm'), [['g', .25]]),
      rep(13, 'a').concat([['m', 2]]),
      [['m', 1.5]].concat(rep(12, 'a'), [['a', 1.5]]),
      [['m', 1.75]].concat(rep(11, 'a'), [['m', 2.25]]),
      [['m', 2.25]].concat(rep(10, 'a'), [['m', 2.75]]),
      [['m', 1.5], ['m', 1.25], ['m', 1.25], ['s', 7], ['m', 1.25], ['m', 1.25], ['m', 1.5]]
    ],
    pad: [rep(4, 'm'), rep(4, 'm'), rep(3, 'a').concat([['m', 1]]), rep(3, 'a').concat([['m', 1]]), rep(3, 'a').concat([['m', 1]]), [['a', 2], ['a', 1], ['m', 1]]],
    gapU: .5
  };
  const KB_COMPACT = {
    main: [
      [['x', 1]].concat(rep(12, 'a'), [['m', 2]]),
      [['m', 1.5]].concat(rep(11, 'a'), [['m', 2.5]]),
      [['m', 2]].concat([['m', 1.5], ['s', 7], ['m', 1.5]], rep(3, 'm'))
    ],
    pad: null, gapU: 0
  };
  // parts (each pixel of the board): the normal [x, up, toward the viewer] and an occlusion
  const KP = { TOP: 1, HI: 2, LIP: 3, WELL: 4, CASE: 5, RIM: 6, SIDEL: 7, SIDER: 8, FACEHI: 9, FACE: 10, EDGE: 11, KEYL: 12, KEYR: 13 };
  const KN = { 1: [0, .96, .28, 1], 2: [0, .74, -.67, 1], 3: [0, .8, .6, .95], 4: [0, 1, 0, .7], 5: [0, .98, .2, 1], 6: [0, .7, -.71, 1],
    7: [-.55, .83, .1, 1], 8: [.55, .83, .1, 1], 9: [0, .6, .8, 1], 10: [0, .05, 1, .92], 11: [0, 0, 1, .6], 12: [-.35, .9, .25, 1], 13: [.35, .9, .25, 1] };

  // a board in the room's own putty (the monitor's), grey modifiers, one amber key; darks lean cool
  function kbPalette(P, o){
    o = o || {};
    const mix = (a, b, k) => [a[0] + (b[0] - a[0]) * k, a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k];
    const sh = (c, k) => [c[0] * k * .96, c[1] * k, c[2] * k * 1.05];
    const cream = [228, 224, 210], grey = o.grey || [115, 124, 134], amber = o.amber || [206, 128, 58];
    const keyset = (c, hiK) => ({ top: c, hi: mix(c, cream, hiK), lip: sh(c, .7), lip2: sh(c, .58), side: sh(c, .84), legend: sh(c, .8) });
    return { key: keyset(P, .45), mod: keyset(grey, .3), acc: keyset(amber, .35),
      well: mix(sh(P, .62), [52, 56, 66], .3), case: sh(P, .8), rim: mix(P, cream, .25), sidel: sh(P, .9), sider: sh(P, .68),
      facehi: sh(P, .66), face: sh(P, .5), edge: o.edge || [14, 16, 22] };
  }

  // The old board's footprint: flood fill from inside it through everything brighter than its dark outline,
  // kept to the hand-traced outline grown by 2 px, plus the outline that touches it. Its back and front rows and
  // its two slanted sides (least squares) give the new board's shape.
  function findKeyboard(A, W, H, poly, seed, dark){
    const N = W * H, L = i => .3 * A[i*3] + .59 * A[i*3+1] + .11 * A[i*3+2];
    let x0 = W, y0 = H, x1 = 0, y1 = 0;
    for (const [x, y] of poly){ x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
    const inPoly = (x, y) => { let ins = false;
      for (let a = 0, b = poly.length - 1; a < poly.length; b = a++){ const [xa, ya] = poly[a], [xb, yb] = poly[b];
        if ((ya > y + .5) !== (yb > y + .5) && x + .5 < (xb - xa) * (y + .5 - ya) / (yb - ya) + xa) ins = !ins; }
      return ins; };
    const near = new Uint8Array(N);
    for (let y = y0 - 2; y <= y1 + 2; y++) for (let x = x0 - 2; x <= x1 + 2; x++){
      let k = false; for (let dy = -2; dy <= 2 && !k; dy++) for (let dx = -2; dx <= 2 && !k; dx++) if (inPoly(x + dx, y + dy)) k = true;
      if (k) near[y * W + x] = 1; }
    const m = propMask(A, W, H, [x0 - 2, y0 - 2, x1 + 2, y1 + 2], seed, i => near[i] && L(i) > (dark || 22), dark || 22);
    let yb = H, yf = 0; const rows = [];
    for (let y = y0 - 2; y <= y1 + 2; y++){ let l = W, r = -1;
      for (let x = x0 - 2; x <= x1 + 2; x++) if (m[y * W + x]){ l = Math.min(l, x); r = Math.max(r, x); }
      if (r >= 0 && r - l > (x1 - x0) * .6){ rows.push([y, l, r]); yb = Math.min(yb, y); yf = Math.max(yf, y); } }
    const fit = k => { let sy = 0, sx = 0, syy = 0, sxy = 0; const n = rows.length;
      for (const r of rows){ sy += r[0]; sx += r[k]; syy += r[0] * r[0]; sxy += r[0] * r[k]; }
      const b = (n * sxy - sy * sx) / (n * syy - sy * sy || 1); return [(sx - b * sy) / n, b]; };
    return { m, yb, yf, l: fit(1), r: fit(2) };
  }

  // Draws the board into A (Float32 RGB 3N) over footprint fp. o: { pal, lay (KB_FULL/KB_COMPACT), rows: [[top, lip, well], ...]
  // per main row, rim, bezel, fbezel, face, side, drop (rows the front face hangs below the old footprint), seed, desk(x,y) -> rgb
  // of the desk at a pixel (to paint over what the old board leaves), wear }. Returns { part (Uint8 N), y0, y1 }.
  function drawKeyboard(A, W, H, fp, o){
    const N = W * H, part = new Uint8Array(N), P = o.pal, lay = o.lay, sd = o.seed || 1;
    const set = (x, y, c, p) => { if (x < 0 || y < 0 || x >= W || y >= H) return; const i = y * W + x; A[i*3] = c[0]; A[i*3+1] = c[1]; A[i*3+2] = c[2]; part[i] = p; };
    const xl = y => Math.round(fp.l[0] + fp.l[1] * y), xr = y => Math.round(fp.r[0] + fp.r[1] * y);
    const yb = fp.yb, face = o.face == null ? 2 : o.face;
    // rows of the board, back to front
    let y = yb;
    const rimY = y; y += o.rim == null ? 1 : o.rim;
    const bezY = y; y += o.bezel == null ? 1 : o.bezel;
    const keyRows = [];
    for (let k = 0; k < lay.main.length; k++){ const [t, l, w] = o.rows[k]; keyRows.push({ y0: y, top: t, lip: l, well: w }); y += t + l + w; }
    const fbY = y; y += o.fbezel == null ? 1 : o.fbezel;
    const faceY = y; y += face;
    const edgeY = y;
    const yEnd = edgeY;
    // 1. what the old board leaves outside the new one goes back to desk
    for (let i = 0; i < N; i++) if (fp.m[i]){ const xx = i % W, yy = (i / W) | 0;
      if (yy < yb || yy > yEnd || xx < xl(yy) || xx > xr(yy)){ const c = o.desk(xx, yy); A[i*3] = c[0]; A[i*3+1] = c[1]; A[i*3+2] = c[2]; } }
    // 2. the case: rim, bezel (top surface), side bevels, front face, bottom edge
    const side = o.side == null ? 2 : o.side;
    for (let yy = yb; yy <= yEnd; yy++){
      const a = xl(yy), b = xr(yy);
      for (let xx = a; xx <= b; xx++){
        let c = P.case, p = KP.CASE;
        if (yy === rimY) { c = P.rim; p = KP.RIM; }
        else if (yy >= faceY && yy < edgeY){ c = yy === faceY ? P.facehi : P.face; p = yy === faceY ? KP.FACEHI : KP.FACE; }
        else if (yy === edgeY){ c = P.edge; p = KP.EDGE; }
        else if (xx < a + side){ c = xx === a ? P.edge : P.sidel; p = xx === a ? KP.EDGE : KP.SIDEL; }
        else if (xx > b - side){ c = xx === b ? P.edge : P.sider; p = xx === b ? KP.EDGE : KP.SIDER; }
        if ((xx === a || xx === b) && (yy === rimY || yy >= faceY)) { c = P.edge; p = KP.EDGE; }
        set(xx, yy, c, p);
      }
    }
    // 3. the keys: per row, spans in key units across the well between the side bevels
    const kh = (k, n) => hash(sd * 7.1 + k * 13.7 + n * 3.3);
    const rowsAll = lay.main.map((r, k) => ({ main: r, pad: lay.pad ? lay.pad[k] : null }));
    rowsAll.forEach((R, k) => {
      const KR = keyRows[k], yMid = KR.y0 + (KR.top + KR.lip) / 2;
      const a = xl(Math.round(yMid)) + side, b = xr(Math.round(yMid)) - side;
      // the well behind the row (the case's dark recess the keys sit in)
      for (let yy = KR.y0; yy < KR.y0 + KR.top + KR.lip + KR.well; yy++){ const aa = xl(yy) + side, bb = xr(yy) - side;
        for (let xx = aa; xx <= bb; xx++) set(xx, yy, P.well, KP.WELL); }
      const keys = []; let U = 0;
      for (const [kd, u] of R.main) U += u;
      const mainU = U; if (R.pad){ U += lay.gapU; for (const [kd, u] of R.pad) U += u; }
      const ppu = (b - a + 2) / U;
      let u0 = 0;
      const push = (list, base) => { for (const [kd, u] of list){ if (kd !== 'g') keys.push([kd, base + u0, base + u0 + u]); u0 += u; } };
      push(R.main, 0); if (R.pad){ u0 = mainU + lay.gapU; push(R.pad, 0); }
      keys.forEach(([kd, ua, ub], n) => {
        const x0 = Math.round(a + ua * ppu), x1 = Math.round(a + ub * ppu) - 2;     // one dark pixel between keys
        if (x1 < x0) return;
        const pal = kd === 'm' ? P.mod : kd === 'x' ? P.acc : P.key;
        // a few keys are older or newer than the rest: a shade warmer or cooler (yellowed caps, a replaced one)
        const hv = kh(k, n), tint = hv < .1 ? [1.04, 1.02, .94] : hv > .93 ? [.95, .97, 1.02] : [1, 1, 1];
        const tc = c => [c[0] * tint[0], c[1] * tint[1], c[2] * tint[2]];
        for (let r = 0; r < KR.top; r++){ const yy = KR.y0 + r;
          for (let xx = x0; xx <= x1; xx++){
            let c = r === 0 && KR.top > 1 ? pal.hi : pal.top, p = r === 0 && KR.top > 1 ? KP.HI : KP.TOP;
            if (r > 0 && xx === x0 && x1 - x0 >= 3) p = KP.KEYL;
            if (r > 0 && xx === x1 && x1 - x0 >= 3){ p = KP.KEYR; c = pal.side; }
            set(xx, yy, tc(c), p);
          } }
        // a legend: one faint darker pixel on some keys (the last top row, left of centre)
        if (kd !== 's' && x1 - x0 >= 2 && kh(k + 50, n) < (o.legend == null ? .45 : o.legend)){
          const yy = KR.y0 + KR.top - 1, xx = x0 + Math.max(1, Math.floor((x1 - x0) / 2) - 1);
          set(xx, yy, tc(pal.legend), part[yy * W + xx]); }
        // the space bar is worn shiny where the thumbs land
        if (kd === 's' && o.wear !== false){ const cx = Math.round((x0 + x1) / 2) - 2;
          for (const dx of [0, 1, 3]) set(cx + dx, KR.y0 + KR.top - 1, tc(pal.hi), KP.TOP); }
        // the lip: the key's front face, its bottom corners rounded off into the well
        for (let r = 0; r < KR.lip; r++){ const yy = KR.y0 + KR.top + r;
          for (let xx = x0; xx <= x1; xx++){
            if ((xx === x0 || xx === x1) && x1 - x0 >= 3 && r === KR.lip - 1) continue;
            set(xx, yy, tc(r === 0 ? pal.lip : pal.lip2 || pal.lip), KP.LIP);
          } }
      });
    });
    // 4. wear and dust: a few pale specks on the front bezel and the rim, one grime pixel by a well-used key
    for (let n = 0; n < (o.specks == null ? 5 : o.specks); n++){
      const yy = hash(sd * 3 + n * 5.7) < .5 ? fbY : rimY + 1, t = hash(sd * 11 + n * 2.3);
      const xx = Math.round(xl(yy) + side + 2 + t * (xr(yy) - xl(yy) - 2 * side - 4));
      const i = yy * W + xx; if (part[i] !== KP.CASE && part[i] !== KP.RIM) continue;
      set(xx, yy, [A[i*3] * .9 + 22, A[i*3+1] * .9 + 20, A[i*3+2] * .9 + 16], part[i]); }
    // 5. the contact shadow on the desk: the row under the bottom edge, and a dithered second row
    if (o.shadow !== false) for (let r = 1; r <= 2; r++){ const yy = yEnd + r; if (yy >= H) break;
      for (let xx = xl(yEnd) + (r === 2 ? 1 : 0); xx <= xr(yEnd) - (r === 2 ? 1 : 0); xx++){
        if (r === 2 && ((xx + yy) & 1)) continue;
        const i = yy * W + xx; if (part[i]) continue;
        const k = r === 1 ? .55 : .75; A[i*3] *= k; A[i*3+1] *= k; A[i*3+2] *= k * 1.04; } }
    return { part, y0: yb, y1: yEnd, xl, xr };
  }

  // =====================================================================================================
  // C LIGHTING for every room (Jon picked C on Nov 18: "hand-shaded ramps: A's light, but every colour steps
  // along its own ramp, cool and violet in shadow, warm where lit").
  // Every pixel gets a place in the room and a facing: the wall (straight at you), the desk top (facing up,
  // further down the picture is nearer you), the desk's front edge, a prop standing on the desk (at its foot's
  // depth, facing you), or a part of the keyboard. Each light is a point (the lamp, a string bulb) or a panel
  // (the screen, the porthole) somewhere in that room, and lights a pixel by its distance, the angle it meets
  // the surface at and, for a lamp, the angle off its shade's axis. Props found by flood fill cast shadows
  // (several samples across the bulb, so the edge softens with distance). Nothing is clipped to a box: every
  // field falls to nothing on its own, and the C ramp steps the summed light into six levels with a dithered
  // seam, so every band edge follows the light's own shape.
  // Projection: screen x = X, screen y = deskY + Z/kz - Hgt (Hgt: height above the desk top, Z: depth from the
  // wall toward you).
  // =====================================================================================================
  const C_LV = [.17, .3, .5, .76, 1.08, 1.5];
  function makeLit(o){
    const W = o.W, H = o.H, N = W * H, A = o.A, skip = o.skip, dY = o.deskY, kz = o.kz || 3;
    const PX = new Float32Array(N), PH = new Float32Array(N), PZ = new Float32Array(N);
    const NX = new Float32Array(N), NY = new Float32Array(N), NZ = new Float32Array(N), AO = new Float32Array(N).fill(1);
    const OWN = new Int16Array(N).fill(-1), TG = new Float32Array(N), WR = new Float32Array(N);
    const clampN = (v, a, b) => v < a ? a : v > b ? b : v;
    const props = (o.props || []).map((p, k) => {
      const zf = (p.foot - dY) * kz + (p.dz || 0), q = Object.assign({ id: k, zf, zb: p.deep != null ? zf - p.deep : zf, up: .3 }, p);
      if (p.cyl){ q.rows = {}; for (let i = 0; i < N; i++) if (p.m[i]){ const x = i % W, y = (i / W) | 0, r = q.rows[y];
        if (!r) q.rows[y] = [x, x]; else { r[0] = Math.min(r[0], x); r[1] = Math.max(r[1], x); } } }
      return q;
    });
    const lumA = i => .3 * A[i*3] + .59 * A[i*3+1] + .11 * A[i*3+2];
    const surf = o.surf || ((x, y) => y < dY ? 0 : y <= o.deskF ? 1 : 2);   // 0 wall, 1 desk top, 2 desk front
    for (let y = 0; y < H; y++) for (let x = 0; x < W; x++){
      const i = y * W + x; PX[i] = x + .5;
      let kp = o.kb ? o.kb.part[i] : 0, pr = -1, g = null;
      if (!kp) for (let k = props.length - 1; k >= 0; k--) if (props[k].m[i] && !props[k].occOnly){ pr = k; break; }
      let tg = 1.15;
      if (kp){
        const n = KN[kp]; PZ[i] = (y + 2 - dY) * kz; PH[i] = 2; NX[i] = n[0]; NY[i] = n[1]; NZ[i] = n[2]; AO[i] = n[3]; OWN[i] = -2;
        tg = o.kbGain || .85;                                   // pale keycaps would burn out at the ramp's top step
      } else if (pr >= 0){
        const p = props[pr];
        let nx = 0;
        if (p.cyl){ const r = p.rows[y]; if (r) nx = clampN(((x + .5) - (r[0] + r[1] + 1) / 2) / ((r[1] - r[0] + 1) / 2), -.92, .92); }
        const nz = Math.sqrt(1 - nx * nx), l = Math.hypot(p.up, 1);
        PZ[i] = p.zf; PH[i] = Math.max(0, p.foot - y); NX[i] = nx / l; NY[i] = p.up / l; NZ[i] = nz / l; OWN[i] = pr;
        WR[i] = p.wrap == null ? .35 : p.wrap;
        if (p.gain != null) tg = p.gain;                       // a pale thing (the putty case) can be held back
      } else if (o.geo && (g = o.geo(x, y, i))){
        PZ[i] = g[0]; PH[i] = g[1]; NX[i] = g[2]; NY[i] = g[3]; NZ[i] = g[4]; AO[i] = g[5] == null ? 1 : g[5];
        tg = 1.15 + 1.0 * (1 - sat((lumA(i) - 35) / 120));
      } else {
        const s = surf(x, y);
        if (s === 1){ PZ[i] = (y - dY) * kz; PH[i] = 0; NY[i] = 1; }
        else if (s === 2){ PZ[i] = ((o.deskF == null ? y : o.deskF) - dY) * kz + 1; PH[i] = (o.deskF == null ? y : o.deskF) - y; NZ[i] = 1; }
        else { PZ[i] = 0; PH[i] = dY - y; NZ[i] = 1; }
        // near-black walls need more light to show it at all, pale paper less (option A's tone gain)
        tg = 1.15 + 1.0 * (1 - sat((lumA(i) - 35) / 120));
      }
      TG[i] = tg;
    }
    // contact shadows under each prop that stands on the desk: the desk pixels right under its lowest pixel in
    // each column, one row, and a dithered second row under heavy things
    for (const p of props){ if (p.contact === false || p.occOnly) continue;
      for (let x = 0; x < W; x++){ let yl = -1;
        for (let y = H - 1; y >= 0; y--) if (p.m[y * W + x]){ yl = y; break; }
        if (yl < 0) continue;
        for (let r = 1; r <= (p.heavy ? 2 : 1); r++){ const y = yl + r; if (y >= H) break; const i = y * W + x;
          if (OWN[i] !== -1 || skip[i]) break;
          if (r === 2 && bay(x, y) >= .5) continue;
          AO[i] = Math.min(AO[i], r === 1 ? .7 : .85); } } }
    // shadow test from a pixel to a point light, through the props listed (each a silhouette at its front
    // depth, extruded back to its back depth)
    function visible(i, LX, LH, LZ, occ){
      const px = PX[i], ph = PH[i], pz = PZ[i], own = OWN[i];
      for (const p of occ){
        if (p.id === own || p.m[i]) continue;                    // a thing never shadows itself
        if ((pz < p.zb && LZ < p.zb) || (pz > p.zf && LZ > p.zf)) continue;
        const dz = LZ - pz; if (Math.abs(dz) < 1e-3) continue;
        const ns = p.zf - p.zb > 2 ? 3 : 1;
        for (let s = 0; s < ns; s++){
          const zs = ns === 1 ? p.zf : p.zb + (p.zf - p.zb) * (s + .5) / ns, t = (zs - pz) / dz;
          if (!(t > .02 && t < .98)) continue;
          // a standing thing's silhouette is extruded back from its front; a flat one (a shelf plank) is where it is
          const qx = Math.floor(px + t * (LX - px)), qy = Math.floor(dY + (p.flat ? zs : p.zf) / kz - (ph + t * (LH - ph)));
          if (qx < 0 || qy < 0 || qx >= W || qy >= H) continue;
          if (p.m[qy * W + qx]) return false;
        }
      }
      return true;
    }
    const occOf = list => list ? list.map(k => props[k]).filter(Boolean) : [];
    // a point light. L: { x, y (its place on screen), z (depth), I, r0, rMax, axis [x, up, z] + cosIn/cosOut
    // (a shade), spill (light outside the shade), wrap (soft terminator), occ [prop indices], spread (bulb
    // width, for the shadow samples), squash (how far the halo falls below vs above), box (local field) }
    function point(L){
      const LH = dY + L.z / kz - L.y, LZ = L.z, LX = L.x, rM = L.rMax, wrap = L.wrap || 0;
      const occ = occOf(L.occ), ns = occ.length ? (L.samples || 5) : 1, sp = L.spread || 0;
      const x0 = Math.max(0, Math.floor(LX - rM - 1)), x1 = Math.min(W - 1, Math.ceil(LX + rM + 1));
      const y0 = 0, y1 = H - 1;
      const F = new Float32Array(N);
      for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++){
        const i = y * W + x; if (skip[i]) continue;
        let dx = LX - PX[i], dh = LH - PH[i], dz = LZ - PZ[i];
        let d = Math.hypot(dx, dh, dz); if (d > rM || d < .5) continue;
        let lam = (NX[i] * dx + NY[i] * dh + NZ[i] * dz) / d;
        const wp = WR[i] > wrap ? WR[i] : wrap;
        lam = (lam + wp) / (1 + wp); if (lam <= 0) continue;
        let k = 1;
        if (L.axis){ const c = -(dx * L.axis[0] + dh * L.axis[1] + dz * L.axis[2]) / d;
          k = c >= L.cosIn ? 1 : c <= L.cosOut ? 0 : (c - L.cosOut) / (L.cosIn - L.cosOut); k = k * k * (3 - 2 * k);
          k = (L.spill || 0) + (1 - (L.spill || 0)) * k; }
        const de = L.squash && dh > 0 ? Math.hypot(dx, dh * L.squash, dz) : d;
        const w1 = 1 - (de / rM) ** 2; if (w1 <= 0) continue;
        let v = L.I * lam * k * w1 * w1 / (1 + (de / L.r0) ** 2);
        if (v < 1e-3) continue;
        if (ns > 1){ let vis = 0;
          for (let s = 0; s < ns; s++){ const ox = (s / (ns - 1) - .5) * sp; if (visible(i, LX + ox, LH, LZ, occ)) vis++; }
          v *= .12 + .88 * vis / ns; }
        F[i] = v * AO[i];
      }
      return L.bounce === false ? F : bounce(F, LX);
    }
    // bounce: a thing standing on the desk also takes the light that lands round its foot, reflected up off
    // the desk (Nov 17's "things read the light at their own feet", which Jon approved for the mugs), shaded
    // across a cylinder toward the light's side
    function bounce(F, lx){
      for (const p of props){ const k = p.occOnly ? 0 : p.bounce == null ? .55 : p.bounce; if (!k) continue;
        let s = 0, n = 0;
        for (let x = 0; x < W; x++){ let yl = -1; for (let y = H - 1; y >= 0; y--) if (p.m[y * W + x]){ yl = y; break; }
          if (yl < 0) continue;
          for (let r = 2; r <= 4 && yl + r < H; r++){ const i = (yl + r) * W + x; if (OWN[i] === -1 && !skip[i]){ s += F[i]; n++; } } }
        if (!n) continue;
        const fv = s / n * k;
        for (let i = 0; i < N; i++) if (OWN[i] === p.id){ const sg = lx < PX[i] ? -1 : 1, v = fv * (1 + .3 * NX[i] * sg) * AO[i];
          if (v > F[i]) F[i] = v; }
      }
      return F;
    }
    // a small point light kept in a local box (a string bulb): { f, box: [x0, y0, bw, bh] }; the box always holds
    // the whole of rMax, so the field reaches zero inside it
    function pointBox(L){
      const F = point(L), x0 = Math.max(0, Math.floor(L.x - L.rMax - 1)), x1 = Math.min(W - 1, Math.ceil(L.x + L.rMax + 1));
      let y0 = H, y1 = -1;
      for (let y = 0; y < H; y++) for (let x = x0; x <= x1; x++) if (F[y * W + x] > 0){ y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
      if (y1 < 0) return { f: new Float32Array(1), box: [0, 0, 1, 1] };
      const bw = x1 - x0 + 1, bh = y1 - y0 + 1, f = new Float32Array(bw * bh);
      for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) f[(y - y0) * bw + x - x0] = F[y * W + x];
      return { f, box: [x0, y0, bw, bh] };
    }
    // a glowing panel (the screen, the porthole) facing you: rect [x0, y0, x1, y1] at depth z, sampled on a grid.
    // L: { rect, z, I, r0, rMax, nx, ny, occ, wrap, disc }
    function panel(L){
      const [rx0, ry0, rx1, ry1] = L.rect, nx = L.nx || 5, ny = L.ny || 4, S = [];
      for (let a = 0; a < nx; a++) for (let b = 0; b < ny; b++){
        const sx = rx0 + (rx1 - rx0) * (a + .5) / nx, sy = ry0 + (ry1 - ry0) * (b + .5) / ny;
        if (L.disc && Math.hypot((sx - (rx0 + rx1) / 2) / ((rx1 - rx0) / 2), (sy - (ry0 + ry1) / 2) / ((ry1 - ry0) / 2)) > 1) continue;
        S.push([sx, dY + L.z / kz - sy]); }
      const occ = occOf(L.occ), rM = L.rMax, wrap = L.wrap || 0, F = new Float32Array(N);
      for (let i = 0; i < N; i++){
        if (skip[i]) continue;
        const pz = PZ[i], dz = L.z - pz;
        let sum = 0;
        for (let s = 0; s < S.length; s++){
          const dx = S[s][0] - PX[i], dh = S[s][1] - PH[i], d = Math.hypot(dx, dh, dz);
          if (d > rM || d < .5) continue;
          const ce = -dz / d; if (ce <= 0) continue;                      // the panel faces +z
          let lam = (NX[i] * dx + NY[i] * dh + NZ[i] * dz) / d; const wp = WR[i] > wrap ? WR[i] : wrap; lam = (lam + wp) / (1 + wp); if (lam <= 0) continue;
          const w1 = 1 - (d / rM) ** 2;
          const v = ce * lam * w1 * w1 / (1 + (d / L.r0) ** 2);
          if (v > 1e-4 && occ.length && !visible(i, S[s][0], S[s][1], L.z, occ)) continue;
          sum += v;
        }
        F[i] = L.I * sum / S.length * AO[i];
      }
      return L.bounce === false ? F : bounce(F, (rx0 + rx1) / 2);
    }
    // scale a field so it reads v at (x, y)
    // (the reference is the mean over the plain room surface, wall or desk, in a 7x5 patch round (x, y): never a prop's
    // or the keyboard's pixel, whose own facing would skew the scale)
    function norm(F, x, y, v){ let r = 0, n = 0;
      for (let yy = y - 2; yy <= y + 2; yy++) for (let xx = x - 3; xx <= x + 3; xx++){ const i = yy * W + xx;
        if (xx < 0 || yy < 0 || xx >= W || yy >= H || OWN[i] !== -1 || skip[i]) continue; r += F[i]; n++; }
      r = n ? r / n : 0; if (r > 0) for (let i = 0; i < N; i++) F[i] *= v / r; return F; }

    // ---- compose (only when a steady weight changes) ----
    // st: { amb [r,g,b], fa (Float32 N, the room's vignette), fade, big: [{ F, w, tint [r,g,b], ch: 0 lamp | 1 screen
    // | 2 other }], small: [{ f, box, w, tint }], ov (overlap), hot }
    const sL = new Float32Array(N), sM = new Float32Array(N), sS = new Float32Array(N), sIdx = new Int16Array(N);
    const knee = c => c < 205 ? c : 205 + (c - 205) / (1 + (c - 205) / 50);
    // The ramp dithers only on a seam (Nov 19, Jon: "weird latticing on Desk 1"; the rule: stepped bands, dithered
    // only along the narrow edge between two steps, never as a fill). The dither's window is in light, so a surface
    // whose light is flat and sits on a step's midpoint (DESK 1's monitor case, the NOOK's crate) was dithered
    // over its whole area, a one-pixel checker. Now a pixel keeps its dither only when a pixel within SEAM_R of it
    // (the glass and portholes aside) lies on another step without dither; otherwise it takes its nearest step.
    const SEAM_R = 2, HK_SKIP = 127, HK = new Int8Array(N), LyA = new Float64Array(N), LA = new Float64Array(N * 3);
    const hardStep = Ly => { if (Ly < C_LV[0]) return -1; if (Ly >= C_LV[5]) return 5;
      let k = 0; while (Ly >= C_LV[k + 1]) k++; return (Ly - C_LV[k]) / (C_LV[k + 1] - C_LV[k]) > .5 ? k + 1 : k; };
    function onSeam(x, y, h){
      for (let yy = Math.max(0, y - SEAM_R); yy <= Math.min(H - 1, y + SEAM_R); yy++)
        for (let xx = Math.max(0, x - SEAM_R); xx <= Math.min(W - 1, x + SEAM_R); xx++){
          const hj = HK[yy * W + xx]; if (hj !== HK_SKIP && hj !== h) return true; }
      return false;
    }
    function compose(st){
      const base = new Float32Array(N * 3), Lm = new Float32Array(N * 3);
      const lr = new Float32Array(N * 3), mr = new Float32Array(N * 3), orr = new Float32Array(N * 3);
      const lS = new Float32Array(N), mS = new Float32Array(N), oS = new Float32Array(N);
      for (const b of st.big){ if (!(b.w > 0)) continue;
        const acc = b.ch === 0 ? lr : b.ch === 1 ? mr : orr, sc = b.ch === 0 ? lS : b.ch === 1 ? mS : oS, F = b.F, w = b.w, t = b.tint;
        for (let i = 0; i < N; i++){ const v = F[i]; if (!v) continue; const e = v * w * TG[i]; sc[i] += e; acc[i*3] += e * t[0]; acc[i*3+1] += e * t[1]; acc[i*3+2] += e * t[2]; } }
      const SL = new Float32Array(N), SR = new Float32Array(N * 3), best = new Float32Array(N); sIdx.fill(-1);
      st.small.forEach((s, n) => { if (!(s.w > 0)) return;
        const [bx, by, bw, bh] = s.box, t = s.tint;
        for (let yy = 0; yy < bh; yy++) for (let xx = 0; xx < bw; xx++){
          const fv = s.f[yy * bw + xx]; if (!fv) continue;
          const i = (by + yy) * W + bx + xx, e = fv * s.w * TG[i];
          SL[i] += e; SR[i*3] += e * t[0]; SR[i*3+1] += e * t[1]; SR[i*3+2] += e * t[2];
          if (e > best[i]){ best[i] = e; sIdx[i] = n; } } });
      const ov = st.ov == null ? .3 : st.ov, amb = st.amb, fa0 = st.fa, fade = st.fade;
      const AA = st.A || A;
      for (let i = 0, j = 0; i < N; i++, j += 3){
        if (skip[i]){ HK[i] = HK_SKIP; continue; }
        const fa = fa0[i] * fade * AO[i];
        let lI = lS[i], mI = mS[i], kl = 1, km = 1;
        // where the lamp and the screen overlap the brighter one wins (summing them washed the desk white)
        if (lI > 0 && mI > 0){ const k = (Math.max(lI, mI) + ov * Math.min(lI, mI)) / (lI + mI); kl = k; km = k; }
        const Lr = amb[0] * fa + lr[j] * kl + mr[j] * km + orr[j] + SR[j];
        const Lg = amb[1] * fa + lr[j+1] * kl + mr[j+1] * km + orr[j+1] + SR[j+1];
        const Lb = amb[2] * fa + lr[j+2] * kl + mr[j+2] * km + orr[j+2] + SR[j+2];
        Lm[j] = Lr; Lm[j+1] = Lg; Lm[j+2] = Lb;
        const tot = (Lr + Lg + Lb) / 3 || 1;
        sL[i] = lI * kl / tot; sM[i] = mI * km / tot; sS[i] = SL[i] / tot;
        LyA[i] = tot; LA[j] = Lr; LA[j+1] = Lg; LA[j+2] = Lb; HK[i] = hardStep(tot);
      }
      for (let i = 0, j = 0; i < N; i++, j += 3){
        if (skip[i]) continue;
        const lI = lS[i], Lr = LA[j], Lg = LA[j+1], Lb = LA[j+2];
        // C: each colour steps along its own ramp; the light picks a step (six, dithered only at their seams),
        // and each step shifts hue as well as value: dark steps go cool and violet, bright ones warm
        const Ly = LyA[i], x = i % W, y = (i / W) | 0, b = bay(x, y);
        let q;
        if (Ly < C_LV[0]) q = C_LV[0] * .8;
        else if (Ly >= C_LV[5]) q = C_LV[5];
        else { let k = 0; while (Ly >= C_LV[k + 1]) k++;
          const t = (Ly - C_LV[k]) / (C_LV[k + 1] - C_LV[k]), ws = .18 * sat(Ly / .6);
          let up = t > .5 + (b - .5) * 2 * ws;
          if (up !== (t > .5) && !onSeam(x, y, HK[i])) up = t > .5;     // off a seam: no dither, the nearest step
          q = up ? C_LV[k + 1] : C_LV[k]; }
        const sc = q / Ly, s = sat((.6 - q) / .45), h = sat((q - .9) / .6) * Math.min(1, sL[i] * 1.5);
        const hot = lI > 1.05 ? (st.hot || 0) * (lI - 1.05) * 4 : 0, lc = st.hotCol || [1, .7, .4];
        base[j] = knee(AA[j] * Lr * sc * (1 - .2 * s) * (1 + .06 * h) + 12 * h + hot * lc[0]);
        base[j+1] = knee(AA[j+1] * Lg * sc * (1 - .1 * s) + 3 * h + hot * lc[1]);
        base[j+2] = knee(AA[j+2] * Lb * sc * (1 + .28 * s) * (1 - .14 * h) + hot * lc[2]);
        Lm[j] *= sc; Lm[j+1] *= sc; Lm[j+2] *= sc;
      }
      return { base, Lm, sL: sL.slice(), sM: sM.slice(), sS: sS.slice(), sIdx: sIdx.slice() };
    }
    // per frame: the flicker of each light multiplies its share of the stepped light (so no band edge moves).
    // out: RGBA bytes; M (Float32 3N, optional): receives the room's light for steam and dust.
    function frame(S, out, fl, M){
      const base = S.base, Lm = S.Lm, a = S.sL, b = S.sM, c = S.sS, k = S.sIdx;
      const dL = fl.lamp - 1, dM = fl.scr - 1, sm = fl.small;
      for (let i = 0, j = 0; i < N; i++, j += 3){
        if (skip[i]){ out[i * 4 + 3] = 255; continue; }
        const kk = k[i], m = 1 + a[i] * dL + b[i] * dM + (kk >= 0 && sm ? c[i] * (sm[kk] - 1) : 0), o4 = i * 4;
        out[o4] = base[j] * m; out[o4+1] = base[j+1] * m; out[o4+2] = base[j+2] * m; out[o4+3] = 255;
        if (M){ M[j] = Lm[j] * m; M[j+1] = Lm[j+1] * m; M[j+2] = Lm[j+2] * m; }
      }
    }
    return { point, pointBox, panel, norm, compose, frame, props, WR, PX, PH, PZ, NX, NY, NZ, AO, OWN, TG, dY, kz };
  }

  return { hash, vnoise, tiredBulb, makeDust, drawDust, settleDust, makeSky, drawSky,
    propMask, findKeyboard, drawKeyboard, kbPalette, KB_FULL, KB_COMPACT, makeLit };
})();
