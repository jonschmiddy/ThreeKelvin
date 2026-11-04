"use strict";
/* =====================================================================================================
   Custodian badge core. Shared by every badge design. Helpers come from custodian-bar/index.html.

   MODULE CONTRACT
   ---------------
   A design file mods/<lens>.js is a plain script loaded after core.js. For each badge it calls

     BADGES.push({
       id:   "<lens>-<n>",          // e.g. "pulse-1"; unique; <n> counts from 1 in that file
       lens: "<lens>",              // the file's name, without .js
       name: "Short name",          // a few words, plain
       idea: "One or two plain sentences: what the player sees and how it gets worse.",
       draw(ctx, x, cy, j, t, s) { ... return { x, y, w, h }; }
       // contract: 2,              // the finals: draw(ctx, x, cy, j, t, s, a); see ANIMATION CONTRACT
     });

   draw arguments
     ctx  a 2D canvas context (imageSmoothingEnabled is false). Draw in whole game pixels.
     x    the badge's left edge, an integer. On the screens this is 6 px after the goal text.
     cy   the badge's vertical centre, an integer: the goal text's cap middle.
     j    the jump, 1 to 40.
     t    game time in seconds. Animate in steps only: const k = step(t) (= Math.floor(t * 8)).
          At jump 16, t counts from the moment the screen opened, so wake(j, t) says when the
          one-time WAKE flash plays (the harness loops it every WAKE_LOOP s so it can be seen).
     s    the scale. Always 1. Crops are made by scaling the canvas, never by s.
   draw returns its ink box { x, y, w, h } in canvas pixels.

   Rules
     - The ink stays inside the 24 x 15 box: x .. x+23, cy-7 .. cy+7 (badgeBox(x, cy)).
       Optional s0w: N in BADGES.push widens the box to N x 15 for jumps 1-15 only (S0, and the FROM
       step arriving at 16), for a countdown set beside the sleeping shape; boxW(B, j) says which.
     - Only core.js helpers and canvas calls. No DOM, no timers, no state kept between calls
       (each call draws the whole badge from j and t alone). off() for a scratch canvas is fine.
     - Colours from COL / IC (the game's palette), mix() of two of them, or the sprite IMG.spr.
     - Animation in steps, about 8 a second: dim, flicker, pulse. Nothing slides.
       (Contract 2: transitions at 10 steps a second, idle at the stage's IDLE rate; see below.)
     - No hull number anywhere. A jumps-left countdown (countdown(j)) before 16 is allowed.
     - Stages: S0 jumps 1-15 (countdown 16-j), WAKE jump 16 (flash once), S1 16-19, S2 20-24,
       S3 25-32, FULL from 33 (the end: steady, it stops getting worse). Each stage must look
       different from the one before, and worse must read as worse.
     - It must not look like a button (no bevel plate, no raised frame). Reacting to hover is fine.

   ANIMATION CONTRACT (contract 2, the finals: Jon, Nov 4, "idle animations and also transitions")
   ------------------------------------------------------------------------------------------------
   A badge that sets  contract: 2  in its BADGES.push({...}) gets a seventh argument and the harness's
   idle and transition checks. A badge without it is contract 1 and is checked as before.

     draw(ctx, x, cy, j, t, s, a) { ... return { x, y, w, h }; }

     a    { since, from }. since = seconds since this screen opened after arriving at jump j
          (Infinity, or a undefined, when the screen did not open on an arrival); from = j - 1.
          The game passes it on the first screen after a jump; the harness passes it in --arrive.
     t    game time in seconds, as before. When arriving, the harness opens the screen at t = 0
          (t = a.since), but draw the transition from arrival(a, j), never from t.

   Two kinds of motion, both frame changes in place, never sliding (no whole-shape offset between
   two steps; a glint can travel across the glass, the badge itself never moves):

   1. TRANSITION, once, on arriving at a jump where something changes. changeKind(j) says which:
        "tick"  jumps 2-15   the countdown drops by one          TRANS_STEPS.tick  = 4  (0.4 s)
        "wake"  jump 16      the big one: it wakes               TRANS_STEPS.wake  = 12 (1.2 s)
        "worse" jumps 20, 25 smaller, each landing harder         TRANS_STEPS.worse = 8  (0.8 s)
        "full"  jump 33      the last change, the hardest worse   TRANS_STEPS.full  = 10 (1.0 s)
        "none"  every other jump (1, 17-19, 21-24, 26-32, 34-40): no transition, idle at once.
      Steps run at TRANS_RATE = 10 a second. arrival(a, j) -> the step 0 .. N-1 while it plays, else -1.
      Step 0 may show the jump before (from = a.from; draw your own look at a.from); the transition
      goes from that look to jump j's in whole-pixel steps: an eye blinking wider, a piece unfolding,
      light pouring in. No smooth easing (no cosine ramps through mix() on a fine clock); hold the
      end pose: THE LAST STEP MUST BE IDENTICAL TO IDLE FRAME 0 OF JUMP j (the harness checks it).

   2. IDLE, always, at the stage's own rate. Every stage lives (FULL too: it stops getting worse but
      not moving). Calm stages idle slowly and quietly; each worse stage idles faster and harder;
      FULL idles steadily and menacingly (a regular beat, no new randomness).
        const I = idleOf(j, t, a);   // I.k fast step (I.rate a second), I.q slow step (I.slow a second),
                                     // I.L slow steps in one loop (the stage's period), I.c idle seconds
      idleOf() counts from 0 when a transition ends (idleClock), from t otherwise, so idle frame 0
      (I.k = I.q = 0) follows the last transition step. Make idle frame 0 the rest pose.
      Run every loop of a stage off I.k and I.q, which share one grid (I.slow divides I.rate), so no
      frame is held shorter than 1 / I.rate. The harness fails a badge that changes faster than 12
      a second or is frozen at any stage.
        IDLE.S0   rate 9,  slow 3,  period 3.0 s   quiet breath at 3 a second; flicker at 9
        IDLE.S1   rate 10, slow 5,  period 2.0 s   (WAKE, jump 16, idles as S1)
        IDLE.S2   rate 12, slow 6,  period 1.5 s
        IDLE.S3   rate 12, slow 12, period 1.0 s   10 to 12 changes a second
        IDLE.FULL rate 12, slow 12, period 1.0 s   steady: the same beat every loop

   Judge per second, not per frame: shape changes at 8 to 12 a second read alive, 3 a second reads
   too still for anything but a slow breath. Whole-pixel steps only.

   The pattern:
     draw(ctx, x, cy, j, t, s, a) {
       const st = arrival(a, j);
       if (st >= 0) return arrive(ctx, x, cy, j, st, TRANS_STEPS[changeKind(j)]);   // st = N-1 equals idle 0
       const I = idleOf(j, t, a);
       ...                                                                          // the stage's loop
     }

   ANIMATION HELPERS
     TRANS_RATE = 10, TRANS_STEPS = { wake: 12, worse: 8, full: 10, tick: 4, none: 0 }
     changeKind(j) -> "wake" | "worse" | "full" | "tick" | "none"
     arriving(a) -> bool             a given with a finite since >= 0
     arrival(a, j?) -> step 0..N-1 during the transition window, else -1  (j defaults to a.from + 1)
     transLen(j) -> seconds the transition at j lasts (0 for "none")
     idleClock(t, a, j?) -> idle seconds: a.since - transLen(j) when arriving (0 during it), else t
     idleStep(t, rate) -> Math.floor(t * rate)
     IDLE[stage] = { rate, slow, period }    idleRate(j) -> IDLE[stage(j)]
     idleOf(j, t, a) -> { k, q, L, rate, slow, c }
     wake(j, t, a?)  the old jump 16 flash: with a, it plays once from a.since; without, as before
                     (loops every WAKE_LOOP s) so contract 1 badges draw unchanged.

   HELPERS (all globals)
     COL, IC                         palette objects (hex strings)
     IMG.spr                         the Custodian sprite (280 x 141), loaded before any draw
     LIGHTS                          14 of the sprite's orange pinpoints, sprite px [[x, y], ...]
     px(ctx, x, y, w, h, col, a?)    fill a rect; a = alpha 0..1 (optional)
     pxDiamond(ctx, cx, cy, hw, hh, fill)
     pxDiamondRows(ctx, cx, cy, hw, hh, fill, rows)   only the bottom `rows` rows
     glassIcon(ctx, cx, cy, r, lit, rim?)             small glass octahedron
     glass(ctx, cx, cy, r, { rim, pin, girdle?, dark?, cell?(dx, dy, d, c) })  shaded cell by cell
     diaRing(ctx, cx, cy, r, col, check?)             diamond outline, check = checkered
     frameRect(ctx, x, y, w, h, col)                  1 px outline
     mix(a, b, k) -> "rgb(...)"                       blend two hex colours, k 0..1
     checker(ctx, col) -> CanvasPattern               2x2 checker fill
     text(ctx, s, x, y, col, size?, align?) -> box    y = top of the capitals; size 8 default
     textW(s, size?) -> px    capH(size) -> px        setFont(ctx, size)
     off(w, h) -> [canvas, ctx]                       scratch canvas, smoothing off
     hull(j) -> number                                for logic only; never draw it
     stage(j) -> "S0" | "WAKE" | "S1" | "S2" | "S3" | "FULL"
     tier(j)  -> 0 S0, 1 S1 (incl. 16), 2 S2, 3 S3, 4 FULL
     countdown(j) -> 16 - j for j <= 15, else 0
     step(t) -> Math.floor(t * 8)
     wake(j, t, a?) -> -1, or the flash step 0 .. WAKE_STEPS-1 while the jump 16 flash plays (contract 1)
     breath(k, L) -> 0..1 cosine over a period of L steps (k = step(t))
     badgeBox(x, cy, w?) -> { x, y: cy - 7, w: w || 24, h: 15 }      boxW(B, j) -> 24, or B.s0w for jumps 1-15
     tooltip(j) -> [lines]   tooltipSize(lines) -> [w, h]
     drawTooltip(ctx, x, y, lines, j?) -> box         Godot TooltipPanel look; heading red from 16
   ===================================================================================================== */

// ---------------------------------------------------------------- palette (UITheme.gd, as on custodian-bar)
const COL = { void: "#0a0e15", ice: "#c3d2e2", chill: "#8fa3ba", cold: "#6b7d94", flare: "#ff9d3d", hot: "#ffd28a",
  them: "#c98d7a", bad: "#c8503c", good: "#7fb89a", darkred: "#5a1a1a", steel: "#4a6582", silver: "#c3d2e2",
  panel: "#111823", panel2: "#161f2c", line: "#22303f", bevelHi: "#3d4d61", bevelLo: "#080b11" };
const IC = { amber: "#a0642a", track: "#22303f", ember: "#7a2a20", glow: "#ff8a6a", white: "#ffffff", pin: "#3a2c22",
  ul: "#4a6582", ur: "#3a516b", ll: "#304255", lr: "#2b3b4f", girdle: "#33465c", dimRim: "#6b7d94", dimGlass: "#1a2433" };

// ---------------------------------------------------------------- the sprite and the stills
const SRC = { chart: "stills/01_chart_run_start.png", local: "stills/07_local_hud_start.png",
  fight: "stills/09_custodian_fight_calm_sky.png", spr: "custodian.png" };
const IMG = {};
// 14 of the sprite's own orange pinpoints (sprite px, 280x141)
const LIGHTS = [[9,63],[21,55],[47,62],[65,36],[99,113],[118,36],[138,40],[148,64],[173,56],[194,112],[208,57],[224,94],[258,63],[268,58]];

// ---------------------------------------------------------------- where the badge sits
// The goal text's ink, measured on the stills (cap top, 5 px caps). The badge's left edge is H2's:
// 6 px after the goal text on the chart and LOCAL, 7 on the fight; cy is the cap middle.
const GOALTEXT = { chart: [35, 94, 100, 5], local: [36, 52, 100, 5], fight: [30, 51, 104, 5] };
const BADGE_AT = { chart: [141, 96], local: [142, 54], fight: [141, 53] };
const BADGE_W = 24, BADGE_H = 15;
function badgeBox(x, cy, w) { return { x: x, y: cy - 7, w: w || BADGE_W, h: BADGE_H }; }
// The box a badge may ink at jump j: 24 x 15, or s0w x 15 for jumps 1-15 when the badge sets s0w
// (a countdown beside a wide sleeping shape). From jump 16 on every badge is 24 x 15.
function boxW(B, j) { return j <= 15 && B && B.s0w ? Math.max(BADGE_W, B.s0w) : BADGE_W; }

// ---------------------------------------------------------------- the ladder
// G3 with Jon's cap (Nov 3, "B"): 200 through jump 15, then +4% a jump, stops at 400 from jump 33
const HULL_CAP = 400, CAP_J = 33;
function hull(j) { return j <= 15 ? 200 : Math.min(HULL_CAP, Math.round(200 * Math.pow(1.04, j - 15))); }
function stage(j) { return j <= 15 ? "S0" : j === 16 ? "WAKE" : j <= 19 ? "S1" : j <= 24 ? "S2" : j < CAP_J ? "S3" : "FULL"; }
function tier(j) { return j <= 15 ? 0 : j <= 19 ? 1 : j <= 24 ? 2 : j < CAP_J ? 3 : 4; }
function countdown(j) { return j <= 15 ? 16 - j : 0; }
function step(t) { return Math.floor(t * 8); }
// the jump 16 flash: once in the game (t from screen open); the harness loops it every WAKE_LOOP s
const WAKE_STEPS = 8, WAKE_LOOP = 5;
function breath(k, L) { return 0.5 - 0.5 * Math.cos(2 * Math.PI * (k % L) / L); }

// ---------------------------------------------------------------- animation (contract 2)
// Transitions: once, on the first screen after a jump, 10 steps a second. Idle: always, per stage.
const TRANS_RATE = 10;
const TRANS_STEPS = { wake: 12, worse: 8, full: 10, tick: 4, none: 0 };
function changeKind(j) { return j === 16 ? "wake" : (j === 20 || j === 25) ? "worse" : j === CAP_J ? "full" : (j >= 2 && j <= 15) ? "tick" : "none"; }
function arriving(a) { return !!a && typeof a.since === "number" && isFinite(a.since) && a.since >= 0; }
function transLen(j) { return TRANS_STEPS[changeKind(j)] / TRANS_RATE; }
function arrival(a, j) {
  if (!arriving(a)) return -1;
  const n = TRANS_STEPS[changeKind(j != null ? j : a.from + 1)], k = Math.floor(a.since * TRANS_RATE + 1e-9);
  return k < n ? k : -1;
}
function idleClock(t, a, j) { return arriving(a) ? Math.max(0, a.since - transLen(j != null ? j : a.from + 1)) : t; }
function idleStep(t, rate) { return Math.floor(t * rate + 1e-9); }
const IDLE = {
  S0:   { rate: 9,  slow: 3,  period: 3.0 },
  WAKE: { rate: 10, slow: 5,  period: 2.0 },
  S1:   { rate: 10, slow: 5,  period: 2.0 },
  S2:   { rate: 12, slow: 6,  period: 1.5 },
  S3:   { rate: 12, slow: 12, period: 1.0 },
  FULL: { rate: 12, slow: 12, period: 1.0 } };
function idleRate(j) { return IDLE[stage(j)]; }
function idleOf(j, t, a) {
  const R = IDLE[stage(j)], c = idleClock(t, a, j);
  return { k: idleStep(c, R.rate), q: idleStep(c, R.slow), L: Math.round(R.period * R.slow), rate: R.rate, slow: R.slow, c: c };
}
// The jump 16 flash of contract 1. With a (arriving), it plays once from a.since; without a, as before:
// t from the screen opening, looped every WAKE_LOOP s by the harness so it can be seen.
function wake(j, t, a) {
  if (j !== 16) return -1;
  if (arriving(a)) { const k = Math.floor(a.since * 8); return k < WAKE_STEPS ? k : -1; }
  const k = step(t % WAKE_LOOP); return k < WAKE_STEPS ? k : -1;
}

// ---------------------------------------------------------------- drawing helpers
let PROBE = null, LS = 0; const CAPC = {}, TWC = {};
function off(w, h) { const c = document.createElement("canvas"); c.width = Math.max(1, Math.ceil(w)); c.height = Math.max(1, Math.ceil(h)); const x = c.getContext("2d"); x.imageSmoothingEnabled = false; return [c, x]; }
function setFont(ctx, size) { ctx.font = size + "px Silkscreen, monospace"; try { ctx.letterSpacing = Math.round(LS * size / 8) + "px"; } catch (e) {} ctx.textBaseline = "alphabetic"; }
function capH(size) { if (!CAPC[size]) { setFont(PROBE, size); CAPC[size] = Math.round(PROBE.measureText("H").actualBoundingBoxAscent) || Math.round(size * .625); } return CAPC[size]; }
function textW(s, size) { size = size || 8; const k = size + "|" + s;
  if (TWC[k] == null) { setFont(PROBE, size); const m = PROBE.measureText(s); TWC[k] = Math.ceil((m.actualBoundingBoxRight || m.width) + (m.actualBoundingBoxLeft || 0)); }
  return TWC[k]; }
// y is the top of the capitals, as the game lays text out
function text(ctx, s, x, y, col, size, align) {
  size = size || 8; const h = capH(size), w = textW(s, size);
  const x0 = align === "center" ? Math.round(x - w / 2) : align === "right" ? Math.round(x - w) : Math.round(x);
  setFont(ctx, size); ctx.fillStyle = col; ctx.fillText(s, x0, Math.round(y) + h);
  return { x: x0, y: Math.round(y), w: w, h: h };
}
function px(ctx, x, y, w, h, col, a) {
  if (a != null) ctx.globalAlpha = Math.max(0, Math.min(1, a));
  ctx.fillStyle = col; ctx.fillRect(x, y, w, h);
  if (a != null) ctx.globalAlpha = 1;
}
function pxDiamond(ctx, cx, cy, hw, hh, fill) {
  ctx.fillStyle = fill;
  if (hh <= 0) { ctx.fillRect(cx - hw, cy, 2 * hw + 1, 1); return; }
  for (let dy = -hh; dy <= hh; dy++) { const half = Math.round(hw * (1 - Math.abs(dy) / hh)); ctx.fillRect(cx - half, cy + dy, 2 * half + 1, 1); }
}
function pxDiamondRows(ctx, cx, cy, hw, hh, fill, rows) { // only the bottom `rows` rows
  ctx.fillStyle = fill;
  if (hh <= 0) { if (rows > 0) ctx.fillRect(cx - hw, cy, 2 * hw + 1, 1); return; }
  for (let dy = hh; dy >= -hh; dy--) { if (hh - dy >= rows) break; const half = Math.round(hw * (1 - Math.abs(dy) / hh)); ctx.fillRect(cx - half, cy + dy, 2 * half + 1, 1); }
}
// a small glass octahedron in the Custodian's colours
function glassIcon(ctx, cx, cy, r, lit, rim) {
  pxDiamond(ctx, cx, cy, r, r, rim || COL.silver);
  pxDiamond(ctx, cx + 1, cy + 1, r - 1, r - 1, "#1a2433");
  pxDiamond(ctx, cx, cy, r - 1, r - 1, COL.steel);
  px(ctx, cx - r + 2, cy, 2 * r - 3, 1, "#33465c");
  px(ctx, cx, cy - 1, 1, 2, lit ? COL.hot : "#3a2c22");
}
// A glass octahedron cell by cell, as the sprite shades it: lit upper left, dark lower right.
// s = { rim, pin, girdle?, dark?, cell?(dx, dy, d, colour) -> colour to replace a cell, or null }
function glass(ctx, cx, cy, r, s) {
  for (let dy = -r; dy <= r; dy++) for (let dx = -r; dx <= r; dx++) {
    const d = Math.abs(dx) + Math.abs(dy); if (d > r) continue;
    let c;
    if (d === r) c = s.rim;
    else if (dx === 0 && dy === 0) c = s.pin;
    else if (dy === 0) c = s.girdle || IC.girdle;
    else c = dy < 0 ? (dx <= 0 ? IC.ul : (s.dark ? IC.ll : IC.ur)) : (dx <= 0 ? IC.ll : IC.lr);
    if (s.cell) c = s.cell(dx, dy, d, c) || c;
    ctx.fillStyle = c; ctx.fillRect(cx + dx, cy + dy, 1, 1);
  }
}
function diaRing(ctx, cx, cy, r, col, check) {
  ctx.fillStyle = col;
  for (let dy = -r; dy <= r; dy++) { const a = r - Math.abs(dy);
    [cx - a, cx + a].forEach((x, i) => { if (i && a === 0) return; if (!check || ((x + cy + dy) & 1) === 0) ctx.fillRect(x, cy + dy, 1, 1); }); }
}
function frameRect(ctx, x, y, w, h, col) { ctx.fillStyle = col; ctx.fillRect(x, y, w, 1); ctx.fillRect(x, y + h - 1, w, 1); ctx.fillRect(x, y, 1, h); ctx.fillRect(x + w - 1, y, 1, h); }
function mix(a, b, k) {
  function p(h) { if (h.charAt(0) !== "#") { const m = h.match(/\d+/g); return [+m[0], +m[1], +m[2]]; } return [parseInt(h.substr(1, 2), 16), parseInt(h.substr(3, 2), 16), parseInt(h.substr(5, 2), 16)]; }
  const A = p(a), B = p(b); return "rgb(" + A.map(function (v, i) { return Math.round(v + (B[i] - v) * k); }).join(",") + ")";
}
const PAT = {};
function checker(ctx, col) {
  if (!PAT[col]) { const o = off(2, 2); o[1].fillStyle = col; o[1].fillRect(0, 0, 1, 1); o[1].fillRect(1, 1, 1, 1); PAT[col] = o[0]; }
  return ctx.createPattern(PAT[col], "repeat");
}

// ---------------------------------------------------------------- the tooltip (no hull figure)
const TIERLINE = ["", "It woke after jump 15.", "It is already stronger.", "It is much stronger now.", ""];
function tooltip(j) {
  const L = ["THE CUSTODIAN", "It guards the core."];
  if (j < 15) L.push("It starts to grow stronger", "in " + (16 - j) + " jumps.");
  else if (j === 15) L.push("It starts to grow stronger", "after your next jump.");
  else if (j < CAP_J) L.push("It grows stronger with every", "jump you take.", TIERLINE[tier(j)], "It can grow to twice its strength.");
  else L.push("It is at full strength.", "It will not grow any more.");
  return L;
}
// Godot's TooltipPanel look: bevel(PANEL2), 6 px top and bottom, 9 px sides, Silkscreen 8, 11 px pitch, hsep under the heading.
function tooltipSize(L) { let w = 0; L.forEach(s => { w = Math.max(w, textW(s, 8)); }); return [w + 18, 6 + 11 + 3 + 11 * (L.length - 1) + 6]; }
function drawTooltip(ctx, x, y, L, j) {
  const sz = tooltipSize(L), w = sz[0], h = sz[1];
  px(ctx, x, y, w, h, "#161f2c");
  px(ctx, x, y, w, 1, "#3d4d61"); px(ctx, x, y, 1, h, "#3d4d61");
  px(ctx, x, y + h - 1, w, 1, "#080b11"); px(ctx, x + w - 1, y, 1, h, "#080b11");
  text(ctx, L[0], x + 9, y + 6 + 3, j >= 16 ? COL.bad : COL.them);
  px(ctx, x + 9, y + 6 + 12, w - 18, 1, "#22303f");
  for (let i = 1; i < L.length; i++) text(ctx, L[i], x + 9, y + 6 + 14 + 11 * (i - 1) + 3, COL.ice);
  return { x: x, y: y, w: w, h: h };
}

// ---------------------------------------------------------------- registry and boot
const BADGES = [];
// Loads the stills, the sprite and the font, then sets the letter spacing so GOAL: REACH THE CORE
// measures as in the game (99 px), as custodian-bar does. Calls done() when ready.
function coreBoot(done) {
  const names = Object.keys(SRC); let left = names.length;
  const go = () => {
    const fonts = document.fonts ? document.fonts.load("8px Silkscreen").catch(() => {}) : Promise.resolve();
    Promise.race([fonts, new Promise(r => setTimeout(r, 2500))]).then(() => {
      PROBE = document.createElement("canvas").getContext("2d");
      setFont(PROBE, 8); const m = PROBE.measureText("GOAL: REACH THE CORE");
      const ink = (m.actualBoundingBoxRight || m.width) + (m.actualBoundingBoxLeft || 0);
      LS = Math.max(0, Math.min(2, Math.round((99 - ink) / 19)));
      done();
    });
  };
  names.forEach(n => { const im = new Image(); im.onload = im.onerror = () => { if (--left === 0) go(); }; im.src = SRC[n]; IMG[n] = im; });
}
