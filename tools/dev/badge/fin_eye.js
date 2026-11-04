"use strict";
// Finals: finalist 9, light-1 "The eye opens", animated (contract 2). Two badges:
//   eye-1  (eye-a) the original look at rest: silver and amber at 16, orange at 20, red only from 25.
//   eye-1b (eye-b) the same eye, loud by jump 20: orange at 16, red and bloodshot from 20.
// At rest every stage draws as light-1 drew it (eye-a); the idles and transitions are frame changes
// in place: lids blink, the iris darts, light leaks, a glint runs round the lid. The badge never moves.
(function () {
  const LENS = "eye"; // ids must be <lens>-<n>[b] with no underscore, so the lens is "eye" (file fin_eye.js)
  function hsh(a, b) { let h = Math.imul(a + 1, 73856093) ^ Math.imul(b + 7, 19349663); h = Math.imul(h ^ (h >>> 13), 1274126177); return (h ^ (h >>> 16)) >>> 0; }
  const BOX = (x, cy) => badgeBox(x, cy);

  // ---------------------------------------------------------------- the eye (light-1's, with hooks)
  // o = { rim, ir, iris, ring?, pr, pupil, blood?, ox? (iris offset, px), vein?: { seed, col, n },
  //       glint?: { at (0..11 round the lid), col } }
  function eye(ctx, cx, cy, hw, hh, o) {
    const half = dy => (Math.abs(dy) > hh ? -1 : hh <= 0 ? (dy === 0 ? hw : -1) : Math.round(hw * (1 - Math.abs(dy) / hh)));
    const ins = (dx, dy) => { const h = half(dy); return h >= 0 && Math.abs(dx) <= h; };
    const ox = o.ox || 0;
    for (let dy = -hh; dy <= hh; dy++) for (let dx = -hw; dx <= hw; dx++) {
      if (!ins(dx, dy)) continue;
      const inner = ins(dx - 1, dy) && ins(dx + 1, dy) && ins(dx, dy - 1) && ins(dx, dy + 1);
      let c;
      if (!inner) {
        c = o.rim;
        if (o.glint) { const ang = Math.atan2(dy / Math.max(1, hh), dx / hw) / (2 * Math.PI);
          if (Math.floor(((ang + 1.25) % 1) * 12) === o.glint.at) c = o.glint.col; }
      } else {
        const d = Math.abs(dx - ox) + Math.abs(dy);
        if (d <= o.pr) c = o.pupil;
        else if (d <= o.ir) c = (d === o.ir && o.ring) ? o.ring : o.iris;
        else {
          c = dy < 0 ? (dx <= 0 ? IC.ul : IC.ur) : dy === 0 ? IC.girdle : (dx <= 0 ? IC.ll : IC.lr);
          if (o.blood) c = mix(c, COL.darkred, o.blood);
          if (o.vein && hsh(dx + 40, dy + 40 + 97 * o.vein.seed) % o.vein.n === 0) c = o.vein.col;
        }
      }
      ctx.fillStyle = c; ctx.fillRect(cx + dx, cy + dy, 1, 1);
    }
  }

  // ---------------------------------------------------------------- the closed eye (S0) and its number
  // The shut lid spans the width of the eye that opens at 16 (LOOK[v][1].hw, centre x + 11), so at the
  // wake it opens in place (Jon, Nov 4: "the closed eye to be the same size ... as the opened eye").
  // A shallow U: the corners up a row, three silver pixels down each side, the seam along the bottom,
  // lashes under it. The number sits 5 px after the eye (Jon, Nov 4: "a bit more to the right"), so the S0 ink runs wider than 24 (s0w).
  // o = { hw (half width), seam (centre row colour), twitch (lashes pulled in), leak (seam light colour
  //       or null), corners, digit (number or null), digitCol }
  const NUM_GAP = 6; // the number starts this far past the eye centre + hw (5 blank px)
  function closed(ctx, x, cy, o) {
    const cor = o.corners || COL.chill, hw = o.hw, cx = x + 11, sh = hw - 4, l1 = hw - 3, l2 = Math.round(l1 / 2);
    px(ctx, cx - hw, cy - 2, 1, 1, cor); px(ctx, cx + hw, cy - 2, 1, 1, cor);
    px(ctx, cx - hw + 1, cy - 1, 3, 1, COL.silver); px(ctx, cx + hw - 3, cy - 1, 3, 1, COL.silver);
    px(ctx, cx - sh, cy, 2 * sh + 1, 1, o.seam || COL.silver);
    if (o.twitch) px(ctx, cx, cy + 1, 1, 1, COL.cold);               // the lid squeezes: one short lash
    else { [-l1, -l2, l2, l1].forEach(d => px(ctx, cx + d, cy + 1, 1, 1, COL.cold)); px(ctx, cx, cy + 1, 1, 2, COL.cold); }
    if (o.leak) px(ctx, cx - 2, cy, 5, 1, o.leak);
    if (o.digit) text(ctx, String(o.digit), cx + hw + NUM_GAP, cy - 2, o.digitCol || (o.digit <= 3 ? COL.hot : COL.chill), 8);
  }
  // the S0 box: the eye's left edge (x) to the widest number's right edge ("15", 11 px)
  const s0w = v => 11 + LOOK[v][1].hw + NUM_GAP + 11;
  const BOX0 = (x, cy, v) => badgeBox(x, cy, s0w(v));

  // ---------------------------------------------------------------- the looks at rest, per tier
  // eye-a is light-1 exactly; eye-b is a stage louder: orange at 16, red and bloodshot by 20.
  const LOOK = {
    a: [null,
      { hw: 8, hh: 2, rim: COL.silver, ir: 1, iris: IC.amber, pr: 0, pupil: COL.hot,
        irisSteps: [IC.amber, mix(IC.amber, COL.flare, 0.5), COL.flare] },
      { hw: 10, hh: 4, rim: mix(COL.silver, COL.flare, 0.45), ir: 2, iris: COL.flare, pr: 0, pupil: IC.white, pupil2: COL.hot },
      { hw: 11, hh: 6, rim: COL.flare, ir: 3, iris: COL.bad, iris2: COL.flare, ring: IC.ember, pr: 1, pupil: COL.hot, blood: 0.35, vein: mix(COL.bad, COL.darkred, 0.4) },
      { hw: 11, hh: 7, rim: COL.bad, ir: 4, iris: COL.bad, ring: COL.darkred, pr: 1, pupil: IC.white, blood: 0.7, vein: COL.bad, beat: COL.flare, glint: COL.flare }],
    b: [null,
      { hw: 9, hh: 3, rim: COL.flare, ir: 1, iris: COL.flare, pr: 0, pupil: COL.hot,
        irisSteps: [COL.flare, mix(COL.flare, COL.hot, 0.5), COL.hot] },
      { hw: 11, hh: 5, rim: COL.bad, ir: 2, iris: COL.bad, ring: COL.flare, pr: 1, pupil: IC.white, pupil2: COL.hot, blood: 0.45, vein: COL.bad },
      { hw: 11, hh: 6, rim: COL.bad, ir: 3, iris: COL.bad, iris2: COL.flare, ring: COL.darkred, pr: 1, pupil: IC.white, blood: 0.75, vein: COL.bad },
      { hw: 11, hh: 7, rim: COL.bad, ir: 4, iris: COL.bad, ring: COL.flare, pr: 2, pupil: IC.white, blood: 1, vein: COL.bad, beat: COL.hot, glint: COL.hot }] };

  // a blink: phase 1 half shut, 2 shut, 3 half shut
  const blinkHH = (hh, ph) => (ph === 2 ? 0 : Math.ceil(hh / 2));

  // ---------------------------------------------------------------- idle: the stage's living loop
  // k = fast step (I.k), q = slow step (I.q). k = q = 0 is the rest pose, light-1's look.
  function idle(ctx, x, cy, j, k, q, v) {
    const T = tier(j), cx = x + 11;
    if (T === 0) {
      // S0, 9 a second, a 3 s loop. It sleeps: the lid's seam dims on the out-breath in two whole
      // colour steps (silver, chill, cold, chill, silver, at 3 a second), and once a loop the lashes
      // twitch in a dream (one 1/9 s frame). On jump 15 light leaks through the seam, flickering
      // hot and orange on the breath: it is stirring. About 2 changes a second (15: about 3.7).
      const qq = q % 9, kk = k % 27;
      const seam = [COL.silver, COL.silver, COL.silver, COL.chill, COL.cold, COL.chill, COL.silver, COL.silver, COL.silver][qq];
      const twitch = kk === 22 || (j === 15 && kk === 10);
      const leak = j === 15 ? (qq % 3 === 2 ? COL.flare : COL.hot) : null;
      closed(ctx, x, cy, { hw: LOOK[v][1].hw, seam: seam, twitch: twitch, leak: leak, digit: countdown(j) });
      return BOX0(x, cy, v);
    }
    const P = LOOK[v][T];
    if (T === 1) {
      // S1 (16-19), 10 a second, a 2 s loop. Drowsy, just woken: the iris glows up and down in three
      // whole colour steps at 5 a second, the eye glances back at the goal text (iris 2 px left for
      // 0.4 s) and drifts back, the pupil catches a white glint once a second (0.1 s), then a slow
      // blink (half, shut, half at 10 a second). About 6 changes a second.
      const qq = q % 10, kk = k % 20;
      const iris = P.irisSteps[[0, 1, 2, 2, 1, 0, 0, 1, 1, 0][qq]];
      const ox = qq === 5 || qq === 6 ? -2 : qq === 7 ? -1 : 0;
      const hh = kk >= 16 && kk <= 18 ? blinkHH(P.hh, kk - 15) : P.hh;
      eye(ctx, cx, cy, P.hw, hh, { rim: P.rim, ir: P.ir, iris: iris, pr: P.pr, pupil: kk % 10 === 1 ? IC.white : P.pupil, ox: ox });
    } else if (T === 2) {
      // S2 (20-24), 12 a second, a 1.5 s loop. Awake and searching: the iris darts left, back, right,
      // back (saccades at 6 a second), the pupil glints white 2 frames in 6 (off the saccades' beat),
      // and one quick blink a loop (half, shut, half at 12 a second). About 8.7 changes a second.
      const qq = q % 9, kk = k % 18;
      const ox = [0, 0, -3, -3, 0, 2, 2, 0, 0][qq];
      const hh = kk >= 14 && kk <= 16 ? blinkHH(P.hh, kk - 13) : P.hh;
      eye(ctx, cx, cy, P.hw, hh, { rim: P.rim, ir: P.ir, iris: P.iris, ring: P.ring, pr: P.pr,
        pupil: k % 6 === 1 || k % 6 === 2 ? P.pupil : P.pupil2, blood: P.blood, ox: ox,
        vein: P.vein ? { seed: 0, col: P.vein, n: 7 } : null });
    } else if (T === 3) {
      // S3 (25-32), 12 a second, a 1 s loop. Bloodshot and glaring: the iris flickers red and orange
      // in a ragged 12-frame pattern, the veins crawl (a new pattern every 3 frames, 4 a second), and
      // once a loop the lids tremble shut a pixel for one frame. About 10 changes a second.
      const kk = k % 12;
      eye(ctx, cx, cy, P.hw, kk === 7 ? P.hh - 1 : P.hh, { rim: P.rim, ir: P.ir, iris: [0, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1][kk] ? P.iris2 : P.iris,
        ring: P.ring, pr: P.pr, pupil: P.pupil, blood: P.blood,
        vein: { seed: Math.floor((kk + 1) / 3) % 4, col: P.vein, n: 5 } });
    } else {
      // FULL (33+), 12 a second, a 1 s loop, the same every second. It stares: a hot glint runs once
      // round the lid a second (12 places), and a heartbeat, lub-dub on frames 1 and 3: the pupil
      // swells, the iris ring and the veins flare. Steady: 12 changes a second, no randomness.
      const kk = k % 12, lub = kk === 1, dub = kk === 3;
      eye(ctx, cx, cy, P.hw, P.hh, { rim: P.rim, ir: P.ir, iris: P.iris, ring: lub ? P.beat : P.ring,
        pr: lub || dub ? P.pr + 1 : P.pr, pupil: P.pupil, blood: P.blood,
        vein: { seed: 0, col: lub ? P.beat : P.vein, n: 4 }, glint: { at: kk, col: P.glint } });
    }
    return BOX(x, cy);
  }
  const rest = (ctx, x, cy, j, v) => idle(ctx, x, cy, j, 0, 0, v);

  // ---------------------------------------------------------------- transitions, 10 steps a second
  // Step 0 draws the jump before at rest; the last step is the new stage at rest (idle frame 0).
  function arrive(ctx, x, cy, j, st, v) {
    const kind = changeKind(j), N = TRANS_STEPS[kind], cx = x + 11;
    if (st === 0) return rest(ctx, x, cy, j - 1, v);
    if (st === N - 1) return rest(ctx, x, cy, j, v);
    const E = (hw, hh, o) => { eye(ctx, cx, cy, hw, hh, o); return BOX(x, cy); };
    if (kind === "tick") {
      // TICK (2-15), 0.4 s: the old number, then the lashes twitch and the number goes out (0.1 s),
      // the new number lights white (0.1 s), then settles to its colour.
      const hw = LOOK[v][1].hw;
      if (st === 1) closed(ctx, x, cy, { hw: hw, twitch: true, leak: j === 15 ? COL.flare : null, digit: null });
      else closed(ctx, x, cy, { hw: hw, leak: j === 15 ? IC.white : null, digit: countdown(j), digitCol: IC.white });
      return BOX0(x, cy, v);
    }
    if (kind === "wake") {
      // WAKE (16), 1.2 s: the number goes out and white light pours from the seam (0.1 s); the lids
      // crack, a hot slit (0.1 s); the eye snaps wide open, white (0.2 s); it narrows in two steps,
      // hot (0.4 s); the lid cools to its colour (0.2 s); rest.
      const F = LOOK[v][1];
      if (st === 1) { closed(ctx, x, cy, { hw: F.hw, seam: IC.white, corners: COL.hot, leak: IC.white, digit: null }); return BOX(x, cy); }
      if (st === 2) return E(11, 1, { rim: COL.hot, ir: 3, iris: IC.white, pr: 1, pupil: IC.white });
      if (st <= 4) return E(11, 7, { rim: IC.white, ir: 5, iris: COL.hot, pr: 2, pupil: IC.white });
      if (st <= 6) return E(10, 4, { rim: COL.hot, ir: 2, iris: IC.white, pr: 1, pupil: IC.white });
      if (st <= 8) return E(F.hw, F.hh, { rim: COL.hot, ir: F.ir, iris: COL.flare, pr: 0, pupil: IC.white });
      return E(F.hw, F.hh, { rim: F.rim, ir: F.ir, iris: v === "b" ? COL.hot : COL.flare, pr: 0, pupil: IC.white });
    }
    if (kind === "worse" && j === 20) {
      // WORSE (20), 0.8 s: a blink (half, shut, 0.2 s), then it opens wider than before, hot (0.2 s),
      // settles to the new size, the pupil white (0.2 s); rest.
      const A0 = LOOK[v][1], B0 = LOOK[v][2];
      if (st <= 2) return E(A0.hw, blinkHH(A0.hh, st), { rim: A0.rim, ir: A0.ir, iris: A0.iris, pr: A0.pr, pupil: A0.pupil });
      const o = { ir: B0.ir, iris: B0.iris, ring: B0.ring, pr: 1, pupil: IC.white, blood: B0.blood };
      if (st <= 4) return E(Math.min(11, B0.hw + 1), B0.hh + 1, Object.assign(o, { rim: st === 3 ? IC.white : COL.hot }));
      return E(B0.hw, B0.hh, Object.assign(o, { rim: st === 5 ? COL.hot : B0.rim, pr: B0.pr }));
    }
    if (kind === "worse") {
      // WORSE (25), 0.8 s, harder: it narrows to a red glare in two steps (0.2 s), snaps open past
      // full, white (0.1 s), blood floods the white of the eye (0.2 s), it settles to the new size
      // (0.1 s); rest.
      const A0 = LOOK[v][2], B0 = LOOK[v][3];
      if (st <= 2) return E(A0.hw, st === 1 ? 2 : 1, { rim: COL.bad, ir: A0.ir, iris: st === 1 ? A0.iris : COL.bad, pr: A0.pr, pupil: COL.hot, blood: A0.blood });
      if (st === 3) return E(11, 7, { rim: IC.white, ir: 4, iris: COL.hot, pr: 2, pupil: IC.white });
      const flood = Math.min(1, B0.blood + 0.3);
      if (st <= 5) return E(11, 7, { rim: st === 4 ? COL.hot : COL.bad, ir: B0.ir, iris: COL.bad, ring: B0.ring, pr: 1, pupil: IC.white, blood: flood,
        vein: { seed: st, col: COL.bad, n: 4 } });
      return E(B0.hw, B0.hh, { rim: COL.flare, ir: B0.ir, iris: B0.iris2, ring: B0.ring, pr: B0.pr, pupil: B0.pupil, blood: flood,
        vein: { seed: 0, col: B0.vein, n: 5 } });
    }
    // FULL (33), 1.0 s, the hardest: it shuts hard to a red line (0.1 s), goes dark (0.1 s), then
    // snaps open full, all white (0.1 s), the pupil blown wide (0.1 s), red floods in (0.2 s), the
    // pupil draws in with a beat (0.2 s); rest.
    const F = LOOK[v][4];
    if (st === 1) return E(11, 0, { rim: COL.bad, ir: 0, iris: COL.bad, pr: 0, pupil: COL.bad });
    if (st === 2) return E(11, 0, { rim: COL.darkred, ir: 0, iris: COL.darkred, pr: 0, pupil: COL.darkred });
    if (st === 3) return E(11, 7, { rim: IC.white, ir: 9, iris: IC.white, ring: COL.hot, pr: 9, pupil: IC.white });
    if (st === 4) return E(11, 7, { rim: IC.white, ir: 5, iris: COL.hot, ring: COL.flare, pr: 3, pupil: IC.white });
    if (st <= 6) return E(11, 7, { rim: st === 5 ? COL.hot : F.rim, ir: F.ir, iris: F.iris, ring: COL.hot, pr: 2, pupil: IC.white,
      blood: F.blood, vein: { seed: 0, col: F.vein, n: 4 } });
    return E(11, 7, { rim: F.rim, ir: F.ir, iris: F.iris, ring: st === 7 ? F.beat : F.ring, pr: st === 7 ? F.pr + 1 : F.pr, pupil: F.pupil,
      blood: F.blood, vein: { seed: 0, col: st === 7 ? F.beat : F.vein, n: 4 } });
  }

  function make(v, id, name, idea) {
    BADGES.push({ id: id, lens: LENS, name: name, contract: 2, idea: idea, s0w: s0w(v),
      draw(ctx, x, cy, j, t, s, a) {
        const st = arrival(a, j);
        if (st >= 0) return arrive(ctx, x, cy, j, st, v);
        const I = idleOf(j, t, a);
        return idle(ctx, x, cy, j, I.k, I.q, v);
      } });
  }
  make("a", "eye-1", "The eye opens",
    "A closed eye sleeps beside the jumps-left number, breathing. At jump 16 light pours from the seam and it snaps open; each stage it opens wider, looks about faster and burns redder, until at full strength it stares, wide and bloodshot, to a steady heartbeat.");
  make("b", "eye-1b", "The eye opens, loud",
    "The same eye, a stage louder: it wakes orange at 16, and by jump 20 it is red and bloodshot, darting about; at full strength the whole eye is blood red with a white pupil, beating.");
})();
