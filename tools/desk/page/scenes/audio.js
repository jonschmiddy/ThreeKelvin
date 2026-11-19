// Desk sound: a room bed per desk, the lamp click, the monitor power-on, and the CRT hum that keeps going once the monitor
// is on (Jon, Nov 18: "There needs to be some kind of CRT hum at the end of G into I"; then "G into the hum. Remove I."). Picked here.
// The shell calls DESK_AUDIO.tick(T, ts) once per frame for the PLAYING tile only (ts = that desk's scene time,
// which runs backwards while leaving), so only the playing tile makes sound and the bed follows the room's fade.
// Times come from the scene: s.times = {lamp, crt} in scene seconds if the scene exposes them; otherwise the
// table below, read from each scene's own timeline constants (desk_1: 2.5 + T.click / T.dot; the others T.lamp, T.crt).
// Audio starts only after a tap or key press (browsers require it).
(function(){
  const ROOM = id => id.startsWith('desk_1') ? 'desk_1' : id;          // desk_1n / desk_1s share desk_1's room
  const TIMES = { desk_1:{lamp:3.45, crt:5.10}, desk_2:{lamp:3.45, crt:5.60}, bunk_1:{lamp:3.55, crt:5.95}, nook_1:{lamp:3.20, crt:4.90} };
  const ROWS = [
    {id:'hum', label:'CRT HUM', log:'crt hum', ideas:['Mains hum: 60 Hz with a soft 120, a faint flyback whine kept well down','Transformer buzz: a few low harmonics, a little grit, a slow wobble','Hum with static: the mains hum, no whine, faint sparse crackle on the glass','None']},
    {id:'poweron', label:'MONITOR POWER-ON', log:'power-on', ideas:['Heavy toggle: low thunk, soft hum swells in, faint crackle (take 1)','Breaker + transformer: deep clunk, hum rising, relay ticks (take 1)','Tube wakes: soft click, static sweeps the glass, low thump (take 1)','Heavy toggle (take 2)','Breaker + transformer (take 2)','Tube wakes (take 2)','G into the hum: the toggle thunk, then the CRT hum warms up (your pick)']},
  ];
  // Jon, Nov 17: every room plays the ship cabin drone (bunk A); the lamp is A. Only the monitor power-on is still open.
  const BED = 'audio/bed_bunk_1_A.wav';
  // L = the Lab's own power-on from the game (lab_monitor_pop + lab_city_screen 0.6 s later), the default for the monitor
  // power-on round 2 (Nov 17, Jon turned down A, B, C and the Lab's L): D-F take 1 of three new ideas, G-I take 2
  const LET = r => r.id === 'poweron' ? 'DEFGHIJ' : r.id === 'hum' ? 'ABCX' : 'ABC';   // hum X = none
  const PO = {D:'poweron2_A.mp3',E:'poweron2_B.mp3',F:'poweron2_C.mp3',G:'poweron3_A.mp3',H:'poweron3_B.mp3',I:'poweron3_C.mp3',J:'poweron_K.wav'};   // J = G into the hum (Nov 18): G alone (poweron_K), the hum warms up after it; I is gone
  const url = (id,k) => id === 'hum' ? (k === 'X' ? null : 'audio/crt_hum_' + k + '.wav') : PO[k] && id === 'poweron' ? 'audio/' + PO[k] : 'audio/' + id + '_' + k + ((id.startsWith('bed_') || k === 'L') ? '.wav' : '.mp3');
  const KEY = 'deskpower-audio-picks';
  let picks = {};
  try{ picks = JSON.parse(localStorage.getItem(KEY) || '{}') || {}; }catch(e){ picks = {}; }
  const pick = id => id === 'poweron' ? ('DEFGHIJ'.includes(picks[id]) && picks[id] ? picks[id] : 'J') : id === 'hum' ? ('ABCX'.includes(picks[id]) && picks[id] ? picks[id] : 'A') : 'A';

  // ---- engine ----
  let ac = null, out = null, humBus = null; const bufs = {};
  // hum volume (Jon, Nov 19: "The hum is too quiet."): a dial in dB over the file's level; the hum files sit at -44 dB RMS,
  // so +14 dB puts the hum a little over the bed (-37 dB RMS). Remembered per viewer.
  const HUM_DB_KEY = 'deskpower-hum-db', HUM_DB_DEF = 14;
  let humDb = HUM_DB_DEF;
  try{ const v = parseFloat(localStorage.getItem(HUM_DB_KEY)); if(isFinite(v)) humDb = Math.max(0, Math.min(30, v)); }catch(e){}
  const humGainOf = db => Math.pow(10, db / 20);
  function unlock(){
    if(!ac){ try{ ac = new (window.AudioContext||window.webkitAudioContext)(); out = ac.createGain(); out.connect(ac.destination);
      humBus = ac.createGain(); humBus.gain.value = humGainOf(humDb); humBus.connect(out); }catch(e){ ac = null; return; } }
    if(ac.state === 'suspended') ac.resume().catch(()=>{});
    setStatus();
  }
  ['pointerdown','keydown','touchend'].forEach(ev => document.addEventListener(ev, unlock, {capture:true, passive:true}));
  function load(u){
    if(!bufs[u]) bufs[u] = fetch(u).then(r => { if(!r.ok) throw new Error(u + ' ' + r.status); return r.arrayBuffer(); })
      .then(b => new Promise((ok,no) => { const p = ac.decodeAudioData(b, ok, no); if(p && p.catch) p.catch(no); }));
    bufs[u].catch(e => { delete bufs[u]; console.warn('audio', e.message || e); });
    return bufs[u];
  }
  function oneShot(id){
    if(!ac || ac.state !== 'running') return;
    load(url(id, pick(id))).then(b => { const s = ac.createBufferSource(); s.buffer = b; s.connect(out); s.start(); }).catch(()=>{});
  }
  // the room bed: one at a time, crossfaded when the room or the pick changes
  let bed = null;           // {u, src, g}
  let bedWant = 0, lastTick = 0;
  function setBed(u){
    if(bed && bed.u === u) return;
    if(bed){ const old = bed; old.g.gain.cancelScheduledValues(ac.currentTime); old.g.gain.setTargetAtTime(0, ac.currentTime, .25); setTimeout(()=>{ try{ old.src.stop(); }catch(e){} }, 2000); }
    bed = null; if(!u) return;
    const g = ac.createGain(); g.gain.value = 0; g.connect(out);
    const me = {u, src:null, g}; bed = me;
    load(u).then(b => { if(bed !== me) return; const s = ac.createBufferSource(); s.buffer = b; s.loop = true; s.connect(g); s.start(); me.src = s; }).catch(()=>{});
  }
  function bedLevel(v){ if(bed) bed.g.gain.setTargetAtTime(v, ac.currentTime, .12); }
  // the CRT hum (Jon, Nov 18: "I want a hum as the screen warms up. It would just be G into the hum. Remove I."). The power-on
  // is G alone (audio/poweron_K.wav, made by tk-scratch/science/terminal_sound/g_hum.py); the hum loop (audio/crt_hum_*.wav,
  // crt_hum.py, levelled 2 dB(A) under the bed) starts on its own source at G's thunk decay, HUM_AT after the crt time, with a
  // warm-up: its gain swells to 1.25 (2 dB over steady) by 1.6 s and settles to 1 by 2.4 s, its pitch rises from 0.9 to true
  // over 2 s, and a low-pass opens from 160 Hz to 20 kHz over 2.2 s, so the harmonics bloom and the whine comes in last. It is
  // the one looping source from the first swell on: no hand-off, gap or double hum. A room gain on top follows the room's fade
  // like the bed; the loop stops once it has been silent 1.5 s (left, replayed). Entering a room already past HUM_AT: no
  // warm-up, the hum just fades in.
  const HUM_AT = .83;          // g_hum.py: G's thunk peaks at 0.79 s and decays to a quarter by 0.83 s
  const WARM = {peak:1.25, peakAt:1.6, settleAt:2.4, rate0:.9, rateAt:2.0, lp0:160, lpAt:2.2};
  let hum = null, humWant = 0, humZero = 0;
  function humGraph(dest){
    const rg = ac.createGain(), wg = ac.createGain(), lp = ac.createBiquadFilter();
    rg.gain.value = 0; rg.connect(humBus || dest); wg.connect(rg); lp.type = 'lowpass'; lp.Q.value = .5; lp.frequency.value = 20000; lp.connect(wg);
    return {rg, wg, lp};
  }
  function warmUp(s, n, t){
    n.wg.gain.setValueAtTime(0, t); n.wg.gain.linearRampToValueAtTime(WARM.peak, t + WARM.peakAt); n.wg.gain.linearRampToValueAtTime(1, t + WARM.settleAt);
    s.playbackRate.setValueAtTime(WARM.rate0, t); s.playbackRate.linearRampToValueAtTime(1, t + WARM.rateAt);
    n.lp.frequency.setValueAtTime(WARM.lp0, t); n.lp.frequency.exponentialRampToValueAtTime(20000, t + WARM.lpAt);
  }
  function setHum(u, warm, force){
    if(hum && hum.u === u && !force) return;
    if(hum){ const old = hum; old.g.gain.cancelScheduledValues(ac.currentTime); old.g.gain.setTargetAtTime(0, ac.currentTime, .2); setTimeout(()=>{ try{ old.src && old.src.stop(); }catch(e){} }, 1500); }
    hum = null; if(!u) return;
    const n = humGraph(out); const me = {u, src:null, g:n.rg, warm:!!warm}; hum = me;
    load(u).then(b => { if(hum !== me) return; const s = ac.createBufferSource(); s.buffer = b; s.loop = true; s.connect(n.lp); const t = ac.currentTime;
      if(warm) warmUp(s, n, t); else { n.wg.gain.setValueAtTime(0, t); n.wg.gain.linearRampToValueAtTime(1, t + .4); }
      s.start(t); me.src = s; me.t0 = t; }).catch(()=>{});
  }
  function humLevel(v){ if(hum && !hum.dying) hum.g.gain.setTargetAtTime(v, ac.currentTime, .12); }

  // ---- leaving: the game's own quit sound (Jon, Nov 19: "use the same effect you made for when the game is closed") ----
  // tkg/assets/audio/sfx/power_off.wav, the line-to-dot collapse from GameShell._fade_out: quiet ticks, a whine from 0.44 s,
  // cut at OFF_CUT. As in the game (Audio.power_down), the hum coasts down with the picture (pitch to 0.3, ease-in, so it
  // holds a moment and then goes) and is cut 60 ms before that click, so it lands in silence. The cut is placed where the
  // leaving timeline crosses the crt time (the screen goes dark); OFF_SPEED is how fast leaving runs the timeline back.
  // The file is mastered hot (-6 dB RMS in its whine), so it plays OFF_DB under, near G's loudest moment. The lamp clicks
  // again as the leaving timeline crosses the lamp time.
  const OFF_URL = 'audio/power_off.wav', OFF_CUT = 1.47;
  const OFF_DB_KEY = 'deskpower-off-db', OFF_DB_DEF = -22;
  let offDb = OFF_DB_DEF;
  try{ const v = parseFloat(localStorage.getItem(OFF_DB_KEY)); if(isFinite(v)) offDb = Math.max(-40, Math.min(0, v)); }catch(e){}
  function powerOff(lead){            // lead = real seconds until the screen goes dark
    const t = ac.currentTime, off = Math.max(0, OFF_CUT - lead), left = OFF_CUT - off;
    load(OFF_URL).then(b => { const s = ac.createBufferSource(), g = ac.createGain(); s.buffer = b; g.gain.value = humGainOf(offDb);
      s.connect(g); g.connect(out); s.start(ac.currentTime, off); }).catch(()=>{});
    if(hum){ const h = hum; h.dying = true; const cut = t + Math.max(.05, left - .06);
      h.g.gain.cancelScheduledValues(t); h.g.gain.setValueAtTime(h.g.gain.value, t); h.g.gain.setValueAtTime(h.g.gain.value, cut); h.g.gain.linearRampToValueAtTime(0, cut + .04);
      if(h.src){ const pr = h.src.playbackRate, r0 = pr.value, n = 24, curve = new Float32Array(n);
        for(let i = 0; i < n; i++){ const x = i / (n - 1); curve[i] = r0 + (.3 - r0) * x * x; }
        pr.cancelScheduledValues(t); pr.setValueCurveAtTime(curve, t, Math.max(.05, cut - t)); }
      setTimeout(() => { if(hum === h){ try{ h.src && h.src.stop(); }catch(e){} hum = null; } }, (cut - t + .2) * 1000); }
  }
  const offFired = new WeakMap();      // per leave: did the power-off start

  // ---- per frame, from the shell ----
  const prev = new WeakMap(); let lastT = null;
  function tick(T, ts){
    const p = prev.get(T); prev.set(T, ts);
    if(T !== lastT){ lastT = T; prev.set(T, ts); return; }          // a tile just became active: no catch-up sounds
    lastTick = performance.now();
    if(!ac || ac.state !== 'running') return;
    const room = ROOM(T.s.id), tm = T.s.times || TIMES[room] || TIMES.desk_1;
    // the bed rises with the room after act 1 goes black (2.5) and falls the same way as leaving runs it back
    setBed(TIMES[room] ? BED : null);
    const A = (window.DESK && DESK.ACT1 && DESK.ACT1.black) || 2.5;
    bedWant = Math.max(0, Math.min(1, (ts - (A - .3)) / 1.4));
    bedLevel(ac.currentTime < previewUntil ? 0 : bedWant);
    // the hum: from G's thunk decay (crt + HUM_AT) on, at the room's own level; warmed up when the scene crosses that moment
    const hs = tm.crt + HUM_AT * (window.DESK_SCENE_SPEED || 1), hu = url('hum', pick('hum'));
    if(hu) load(hu); load(url('poweron', pick('poweron'))); load(url('lamp', pick('lamp')));   // cached ahead, so G and its warm-up land on time
    load(OFF_URL);
    // leaving: the power-off starts OFF_CUT before the screen goes dark (at once, part-way in, if there is less time), once per leave
    if(T.leave && TIMES[room]){
      const sp = window.DESK_OFF_SPEED || 2.2, lead = (ts - tm.crt) / sp;
      if(offFired.get(T) !== T.leave && ts > tm.crt && lead <= OFF_CUT){ offFired.set(T, T.leave); powerOff(lead); }
      if(p != null && p > tm.lamp && ts <= tm.lamp && p - ts <= .5) oneShot('lamp');
    }
    if(hum && hum.dying) return;
    const humOn = !!(hu && TIMES[room] && ts >= hs);
    humWant = humOn ? bedWant : 0;
    if(humOn){ humZero = 0;
      const crossing = p != null && !T.leave && p < hs && ts - p <= .25;
      if(crossing) setHum(hu, true, true); else if(!hum || hum.u !== hu) setHum(hu, false);
      humLevel(humWant); }
    else if(hum){ humLevel(0); if(!humZero) humZero = performance.now(); else if(performance.now() - humZero > 1500){ setHum(null); humZero = 0; } }
    // one-shots fire when the scene clock crosses their time going forward (never on a jump, never while leaving)
    if(p == null || T.leave || ts <= p || ts - p > .25) return;
    if(p < tm.lamp && ts >= tm.lamp) oneShot('lamp');
    if(p < tm.crt && ts >= tm.crt) oneShot('poweron');
  }
  // a paused or hidden desk stops ticking: let its bed fall away
  setInterval(() => { if(ac && performance.now() - lastTick > 400){ if(bed) bedLevel(0); if(hum) humLevel(0); } }, 200);

  // ---- picker ----
  const css = document.createElement('style');
  css.textContent = `.da{border:1px solid var(--line);background:var(--panel);padding:10px 12px;margin:0 0 30px}
.da h2{font-size:16px;letter-spacing:.08em;margin:0 0 4px;color:var(--acc)}
.da .st{font-family:"Silkscreen",monospace;font-size:11px;letter-spacing:.08em;color:var(--mut)}
.da .st.on{color:#7fb89a}
.da .rows{display:grid;gap:8px;margin:10px 0}
.da .row{display:grid;grid-template-columns:minmax(0,170px) minmax(0,1fr);gap:6px 12px;align-items:start}
@media (max-width:640px){.da .row{grid-template-columns:minmax(0,1fr)}}
.da .lab{font-family:"Silkscreen",monospace;font-size:12px;letter-spacing:.06em;padding-top:6px}
.da .opts{display:flex;flex-wrap:wrap;gap:6px;min-width:0}
.da .opts button{display:flex;gap:8px;align-items:center;text-align:left;font-family:"IBM Plex Mono",monospace;letter-spacing:0;font-size:12.5px;max-width:100%;white-space:normal}
.da .opts button b{font-family:"Silkscreen",monospace;font-weight:400;color:var(--mut)}
.da .opts button.on{border-color:var(--acc);color:var(--fg)}
.da .opts button.on b{color:var(--acc)}
.da .log{display:flex;gap:8px;align-items:center;flex-wrap:wrap}
.da code{font-size:13px;color:var(--fg);background:#0d131c;border:1px solid var(--line);padding:4px 8px;overflow-wrap:anywhere;min-width:0}`;
  document.head.appendChild(css);
  const sec = document.createElement('section'); sec.className = 'da';
  sec.innerHTML = '<h2>SOUND</h2><p>Every room plays the ship cabin drone, and the lamp is A (your picks). The monitor power-on is new: three ideas, two takes each. Tap a letter to hear it, and it plays when the desk powers on. Only the playing desk makes sound.</p><div class="st"></div><div class="rows"></div><div class="log"><code></code><button type="button">COPY</button></div>';
  const st = sec.querySelector('.st'), rows = sec.querySelector('.rows'), code = sec.querySelector('code'), copy = sec.querySelector('.log button');
  function setStatus(){ const on = ac && ac.state === 'running'; st.textContent = on ? 'SOUND ON' : 'TAP ANYWHERE ON THE PAGE TO TURN SOUND ON'; st.classList.toggle('on', !!on); }
  function logLine(){ return 'picks: ' + ROWS.map(r => r.log + ' ' + pick(r.id)).join(', ') + ', hum volume +' + humDb + ' dB, power-off ' + offDb + ' dB'; }
  let previewing = null, previewUntil = 0;
  function preview(id){
    if(!ac) return;
    if(id === 'hum'){
      // hear G into the hum for 5 s at its game level: G, then the warm-up at G's thunk decay
      if(previewing){ try{ previewing.stop(); }catch(e){} previewing = null; }
      const u = url('hum', pick('hum')); if(!u) return;
      Promise.all([load(u), load(url('poweron', 'J'))]).then(([b, gb]) => { const t = ac.currentTime + .05;
        const gs = ac.createBufferSource(); gs.buffer = gb; gs.connect(out); gs.start(t);
        const n = humGraph(out), s = ac.createBufferSource(); s.buffer = b; s.loop = true; s.connect(n.lp);
        n.rg.gain.setValueAtTime(1, t); n.rg.gain.setValueAtTime(1, t + 5.4); n.rg.gain.linearRampToValueAtTime(0, t + 6);
        warmUp(s, n, t + HUM_AT); s.start(t + HUM_AT); s.stop(t + 6.1); previewing = s; }).catch(()=>{});
      return;
    }
    if(id.startsWith('bed_')){
      // hear the bed alone for 5 s at its game level (the playing desk's bed steps aside)
      if(previewing){ try{ previewing.stop(); }catch(e){} previewing = null; }
      load(url(id, pick(id))).then(b => { const s = ac.createBufferSource(), g = ac.createGain(); s.buffer = b; s.loop = true; s.connect(g); g.connect(out);
        const t = ac.currentTime; g.gain.setValueAtTime(0, t); g.gain.linearRampToValueAtTime(1, t + .4); g.gain.setValueAtTime(1, t + 4.4); g.gain.linearRampToValueAtTime(0, t + 5);
        s.start(t); s.stop(t + 5.1); previewing = s; previewUntil = t + 5.1; if(bed) bedLevel(0); }).catch(()=>{});
    } else oneShot(id);
  }
  function paint(){
    for(const r of ROWS) r.btns.forEach((b,i) => { const on = pick(r.id) === LET(r)[i]; b.classList.toggle('on', on); b.setAttribute('aria-pressed', on); });
    code.textContent = logLine(); setStatus();
  }
  for(const r of ROWS){
    const row = document.createElement('div'); row.className = 'row';
    const lab = document.createElement('div'); lab.className = 'lab'; lab.textContent = r.label;
    const opts = document.createElement('div'); opts.className = 'opts';
    r.btns = r.ideas.map((idea, i) => { const k = LET(r)[i], b = document.createElement('button'); b.type = 'button';
      b.innerHTML = '<b></b><span></span>'; b.firstChild.textContent = k; b.lastChild.textContent = idea;
      b.onclick = () => { unlock(); picks[r.id] = k; try{ localStorage.setItem(KEY, JSON.stringify(picks)); }catch(e){} paint(); console.log(logLine()); preview(r.id); };
      opts.append(b); return b; });
    row.append(lab, opts); rows.append(row);
  }
  // the hum volume dial, under the hum's letters
  { const row = document.createElement('div'); row.className = 'row';
    const lab = document.createElement('div'); lab.className = 'lab'; lab.textContent = 'HUM VOLUME';
    const box = document.createElement('div'); box.className = 'opts'; box.style.alignItems = 'center';
    const rng = document.createElement('input'); rng.type = 'range'; rng.min = 0; rng.max = 30; rng.step = 1; rng.value = humDb; rng.style.width = 'min(100%,320px)'; rng.setAttribute('aria-label', 'Hum volume');
    const val = document.createElement('span'); val.style.fontSize = '13px';
    const hear = document.createElement('button'); hear.type = 'button'; hear.textContent = 'HEAR IT';
    const show = () => { val.textContent = '+' + humDb + ' dB' + (humDb === HUM_DB_DEF ? ' (default)' : ''); };
    rng.oninput = () => { humDb = +rng.value; show(); if(humBus) humBus.gain.setTargetAtTime(humGainOf(humDb), ac.currentTime, .05);
      try{ localStorage.setItem(HUM_DB_KEY, String(humDb)); }catch(e){} code.textContent = logLine(); };
    hear.onclick = () => { unlock(); preview('hum'); };
    show(); box.append(rng, val, hear); row.append(lab, box); rows.append(row); }
  // the power-off volume dial: the game's quit sound with the hum coasting down into its cut
  function previewOff(){
    const u = url('hum', pick('hum'));
    Promise.all([load(OFF_URL), u ? load(u) : Promise.resolve(null)]).then(([ob, hb]) => { const t = ac.currentTime + .05, at = t + 1.2, cut = at + OFF_CUT - .06;
      if(hb){ const n = humGraph(out), s = ac.createBufferSource(); s.buffer = hb; s.loop = true; s.connect(n.lp); n.wg.gain.value = 1;
        n.rg.gain.setValueAtTime(0, t); n.rg.gain.linearRampToValueAtTime(1, t + .3); n.rg.gain.setValueAtTime(1, cut); n.rg.gain.linearRampToValueAtTime(0, cut + .04);
        const c = new Float32Array(24); for(let i = 0; i < 24; i++){ const x = i / 23; c[i] = 1 - .7 * x * x; }
        s.playbackRate.setValueCurveAtTime(c, at, cut - at); s.start(t); s.stop(cut + .1); }
      const o = ac.createBufferSource(), g = ac.createGain(); o.buffer = ob; g.gain.value = humGainOf(offDb); o.connect(g); g.connect(out); o.start(at); }).catch(()=>{});
  }
  { const row = document.createElement('div'); row.className = 'row';
    const lab = document.createElement('div'); lab.className = 'lab'; lab.textContent = 'POWER-OFF (LEAVE)';
    const box = document.createElement('div'); box.className = 'opts'; box.style.alignItems = 'center';
    const rng = document.createElement('input'); rng.type = 'range'; rng.min = -40; rng.max = 0; rng.step = 1; rng.value = offDb; rng.style.width = 'min(100%,320px)'; rng.setAttribute('aria-label', 'Power-off volume');
    const val = document.createElement('span'); val.style.fontSize = '13px';
    const hear = document.createElement('button'); hear.type = 'button'; hear.textContent = 'HEAR IT';
    const show = () => { val.textContent = offDb + ' dB' + (offDb === OFF_DB_DEF ? ' (default)' : '') + ' · the game’s quit sound'; };
    rng.oninput = () => { offDb = +rng.value; show(); try{ localStorage.setItem(OFF_DB_KEY, String(offDb)); }catch(e){} code.textContent = logLine(); };
    hear.onclick = () => { unlock(); previewOff(); };
    show(); box.append(rng, val, hear); row.append(lab, box); rows.append(row); }
  copy.onclick = () => { try{ navigator.clipboard.writeText(code.textContent).catch(()=>{}); }catch(e){} };
  const mount = () => { const wrap = document.querySelector('.wrap'), first = wrap && wrap.querySelector('section'); if(first) wrap.insertBefore(sec, first); else document.body.append(sec); paint(); };
  if(document.readyState === 'loading') document.addEventListener('DOMContentLoaded', mount); else mount();
  window.DESK_AUDIO = { tick, picks: () => ({...picks}), log: logLine, _state: () => ({ac: ac && ac.state, bed: bed && bed.u, level: bedWant, hum: hum && hum.u, humSrc: !!(hum && hum.src), humLevel: humWant, humWarm: !!(hum && hum.warm), humT0: hum && hum.t0, now: ac && ac.currentTime}) };
})();
