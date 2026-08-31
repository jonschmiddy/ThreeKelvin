"""Sound effects, second design: recorded material under the same rulings.

sfx.py v1 is pure synthesis and stays in the repo as the reference set --
this is the ground-up redesign.  What changed is the MATERIAL, not the
language: every sound still sits on F minor degrees, chrome still runs
cold/dry/small and only emitters get warmth (see sfx.py's header), and the
stereo infrastructure (wide/room/WIDTH) is imported from v1 unchanged.

Three shelves feed the layers:

  * samples/foley/    -- Stable Audio material (gen_foley.py, regenerable):
                         switch clicks, latches, air, debris, booms.
  * the instrument doors -- the SAME recordings the score plays: bass drum,
                         gong, bowed cymbal, chimes, glock, piano, cello.
                         An impact in the game and a downbeat in the music
                         are literally the same drum.
  * synthesis         -- v1's tonal glue (tone/zap/sweep) where pitch is
                         the point.  A beep should be a beep.

Run:  TK_VOICES=sampled python3 sfx2.py       # -> out/sfx/*.wav
"""
import numpy as np, os
np.random.seed(31415)
import synth
from synth import *
import soundfile as _sf
from sfx import (room, st, wide, put, click, thunk, servo, sweep, zap, tone,
                 WIDTH, WIDTH_DEFAULT, _sq)
import sampler

HERE = os.path.dirname(os.path.abspath(__file__))
FOLEY = os.path.join(HERE, 'samples', 'foley')

_fcache = {}
def foley(name, dur=None, gain=1.0, hpf=None, lpf=None, tail_ms=25):
    """One palette element as a trimmed mono layer at 44.1k."""
    if name not in _fcache:
        x, sr = _sf.read(os.path.join(FOLEY, name + '.wav'))
        if x.ndim > 1: x = x.mean(axis=1)
        if sr != SR:
            n = int(len(x)*SR/sr)
            x = np.interp(np.linspace(0, len(x)-1, n), np.arange(len(x)), x)
        env = np.convolve(np.abs(x), np.ones(441)/441, 'same')
        idx = np.where(env > env.max()*0.04)[0]
        x = x[max(0, idx[0]-int(0.002*SR)):idx[-1]]
        x = x/np.max(np.abs(x))
        _fcache[name] = x
    y = _fcache[name].copy()
    if dur is not None:
        n = int(dur*SR)
        if len(y) > n:
            k = min(len(y)-1, int(tail_ms*SR/1000))
            y = y[:n]; y[-k:] *= np.linspace(1, 0, k)
    if hpf: y = hp(y, hpf)
    if lpf: y = lp(y, lpf)
    return y*gain

# doors shared with the score
_gong   = lambda a, d=2.5: sampler.impact(a, d)
_cym    = lambda f, d, a: sampler.metal(f, d, a)
_bd     = sampler.kick
_chime  = lambda f, d, a: sampler.bell(f, d, a)
_pf     = lambda f, d, a: sampler._piano().note(f, d, a)*0.2

def mix(*layers):
    """Sum mono layers of unequal length -- the shortest common gesture in
    this file, so it gets a name instead of thirty put() buffers."""
    n = max(len(x) for x in layers)
    out = np.zeros(n)
    for x in layers:
        out[:len(x)] += x
    return out


def build_all():
    S = {}

    # ---- chrome -------------------------------------------------------
    # A real switch under every click: the SAO relay is the finger-feel,
    # the Ab tick is the key it lands in.
    S['ui_click'] = (st(mix(foley('click_mech', 0.06, hpf=900)*0.8,
                            click(hz('Ab6'), 0.045, tone=0.5)*0.5)), 0.34)
    S['ui_hover'] = (st(mix(foley('click_mech', 0.03, gain=0.35, hpf=2500),
                            click(hz('C7'), 0.022, tone=0.25)*0.3)), 0.11)
    conf = np.zeros(int(0.45*SR))
    put(conf, foley('latch', 0.10, hpf=500), 0.00, 0.50)
    put(conf, tone('G6', 0.13, 0.5), 0.01)
    put(conf, tone('Ab6', 0.26, 0.6), 0.11)
    S['ui_confirm'] = (room(st(conf), 0.20), 0.40)
    back = np.zeros(int(0.32*SR))
    put(back, foley('click_mech', 0.05, gain=0.5, hpf=700), 0.0)
    put(back, tone('Ab6', 0.10, 0.4), 0.01)
    put(back, tone('G6', 0.17, 0.45), 0.09)
    S['ui_back'] = (room(st(back), 0.15), 0.30)
    S['ui_denied'] = (st(mix(foley('ratchet', 0.12, lpf=1400)*0.6,
                             thunk(hz('F2'), 0.20, 0.25))), 0.42)
    tab = np.zeros(int(0.30*SR))
    put(tab, foley('air_hiss', 0.22, gain=0.5, hpf=600), 0.0)
    put(tab, foley('latch', 0.08, gain=0.7), 0.16)
    S['ui_tab'] = (room(st(tab), 0.18), 0.30)

    # ---- cards --------------------------------------------------------
    S['card_draw'] = (st(foley('paper_slide', 0.11, hpf=1000)), 0.26)
    cp = np.zeros(int(0.18*SR))
    put(cp, foley('card_snap', 0.10, hpf=300), 0.00, 0.9)
    put(cp, click(hz('F6'), 0.06, tone=0.5), 0.005, 0.5)
    put(cp, thunk(hz('F3'), 0.10, 0.1), 0.006, 0.3)
    S['card_play'] = (st(cp, -0.08), 0.46)

    # ---- weapons ------------------------------------------------------
    # Four FAMILIES keyed on what the card mechanically is, each with round
    # robins (Audio.play picks among name/name_2/name_3), all built on the
    # serious diffusion takes -- deep discharges and mechanical actions,
    # no cartoon pitch-bend anywhere.  The v1 zap survives only inside
    # charge_fire, where a rising whine is the honest mechanic.
    def _shot(src, body, tail=0.28, act=None):
        y = np.zeros(int((0.10 + tail + 0.30)*SR))
        if act:
            put(y, foley(act, 0.05, hpf=1500), 0.000, 0.5)
        put(y, foley(src, tail + 0.25), 0.006, 1.0)
        put(y, _bd(body), 0.004, body)
        return y
    # plain kinetic: one shot, one variant per diffusion take
    S['shot_kinetic']   = (room(st(_shot('shot_kinetic_1', 0.55), -0.10), 0.12), 0.72)
    S['shot_kinetic_2'] = (room(st(_shot('shot_kinetic_3', 0.50, act='latch'), -0.08), 0.12), 0.72)
    # autocannon burst: three cracks off the same takes, jittered
    def _burst(seed):
        r = np.random.RandomState(seed)
        y = np.zeros(int(0.75*SR))
        for i in range(3):
            at = i*0.11 + r.uniform(-0.008, 0.008)
            src = ('shot_kinetic_3', 'shot_kinetic_1')[i % 2]
            put(y, foley(src, 0.16, hpf=250)*r.uniform(0.8, 1.0), at)
        put(y, _bd(0.4), 0.004, 0.4)
        put(y, foley('debris', 0.25, gain=0.2, hpf=2000), 0.36)
        return y
    S['shot_auto']   = (room(st(_burst(3), -0.10), 0.12), 0.70)
    S['shot_auto_2'] = (room(st(_burst(9), -0.06), 0.12), 0.70)
    # heavy ordnance: the big slug -- deep take, full drum, long settle
    hv = np.zeros(int(1.10*SR))
    put(hv, foley('shot_kinetic_2', 0.70), 0.00, 1.0)
    put(hv, _bd(1.0), 0.004, 0.85)
    put(hv, foley('debris', 0.45, gain=0.3, hpf=1200), 0.22)
    put(hv, thunk(hz('F1'), 0.30, 0.2), 0.01, 0.6)
    S['shot_heavy'] = (room(st(hv), 0.16), 0.85)
    hv2 = np.zeros(int(1.10*SR))
    put(hv2, foley('shot_energy_2', 0.65, lpf=3500), 0.00, 0.9)
    put(hv2, _bd(1.0), 0.004, 0.9)
    put(hv2, foley('metal_big', 0.4, lpf=2000), 0.15, 0.5)
    S['shot_heavy_2'] = (room(st(hv2), 0.16), 0.85)
    # energy discharge: the serious takes carry it; a single dark F tail
    # keeps the key without singing
    for i, src in enumerate(('shot_energy_1', 'shot_energy_2', 'shot_energy_3')):
        en = np.zeros(int(0.80*SR))
        put(en, foley(src, 0.55), 0.00, 1.0)
        put(en, _bd(0.4), 0.004, 0.35)
        put(en, np.sin(2*np.pi*hz('F2')*np.arange(int(0.4*SR))/SR)
                *np.exp(-np.arange(int(0.4*SR))/SR/0.10), 0.01, 0.30)
        S['shot_energy' + ('' if i == 0 else '_%d' % (i+1))] = (
            room(st(en, 0.08), 0.15), 0.72)
    ch = np.zeros(int(0.95*SR))
    put(ch, sweep(0.45, 120, 700, 900, 5200, curve=2.2)
            *np.linspace(0, 1, int(0.45*SR))**2.0, 0.00, 0.45)
    put(ch, foley('static_tick', 0.10, hpf=1000), 0.38, 0.7)
    put(ch, zap(hz('F5'), 0.42, bend=-0.62), 0.42, 1.05)
    put(ch, foley('steam_puff', 0.30, gain=0.4, hpf=800), 0.50)
    S['charge_fire'] = (room(st(ch), 0.22), 0.80)

    # ---- taking it ----------------------------------------------------
    dmg = np.zeros(int(0.70*SR))
    put(dmg, foley('metal_big', 0.55, lpf=6000), 0.00, 0.9)
    put(dmg, _bd(0.8), 0.002, 0.8)
    put(dmg, np.sin(2*np.pi*hz('F1')*np.arange(int(0.5*SR))/SR)
             *np.exp(-np.arange(int(0.5*SR))/SR/0.13), 0.0, 0.7)
    put(dmg, foley('debris', 0.35, gain=0.3, hpf=1500), 0.10)
    S['impact_hull'] = (room(st(dmg), 0.22), 0.85)
    ie = np.zeros(int(0.32*SR))
    put(ie, foley('metal_small', 0.18, hpf=500), 0.00, 0.85)
    put(ie, thunk(hz('F3'), 0.10, 0.3), 0.005, 0.5)
    S['impact_enemy'] = (room(st(ie, 0.18), 0.11), 0.44)
    sb = np.zeros(int(0.45*SR))
    put(sb, _cym(hz('C6'), 0.40, 0.55)*env_exp(int(0.40*SR), 0.001, 0.09), 0.0)
    put(sb, foley('static_tick', 0.06, hpf=2500), 0.00, 0.5)
    S['shield_block'] = (room(st(sb, 0.06), 0.24), 0.54)

    # ---- heat ---------------------------------------------------------
    warn = np.zeros(int(0.70*SR))
    for at in (0.0, 0.26):
        put(warn, tone('Db6', 0.16, 0.42, vib=0.004), at)
    S['heat_warn'] = (room(st(warn), 0.16), 0.40)
    ov = np.zeros(int(0.95*SR))
    put(ov, foley('boom_deep', 0.60, lpf=2500), 0.00, 0.8)
    put(ov, foley('steam_puff', 0.45, gain=0.6), 0.10)
    N = int(0.8*SR); t = np.arange(N)/SR
    put(ov, np.tanh(np.sin(2*np.pi*hz('F1')*t*(1-0.12*t/0.8))
                    *np.exp(-t/0.24)*1.8)/1.8, 0.0, 0.9)
    S['overheat'] = (room(st(ov), 0.20), 0.88)
    vn = np.zeros(int(0.70*SR))
    put(vn, foley('air_hiss', 0.55, gain=0.9), 0.02)
    put(vn, click(hz('C5'), 0.05, tone=0.3), 0.00, 0.5)
    put(vn, sweep(0.5, 900, 180, 7000, 1200, 0.7)
            *env_adsr(int(0.5*SR), 0.02, 0.1, 0.4, 0.3), 0.05, 0.35)
    S['vent'] = (room(st(vn), 0.15), 0.50)

    # ---- map, economy, refit ------------------------------------------
    jm = np.zeros(int(1.40*SR))
    put(jm, foley('whoosh', 0.6, hpf=200), 0.00, 0.9)
    put(jm, sweep(0.55, 200, 60, 5000, 400, 1.6)
            *np.linspace(0, 1, int(0.55*SR))**1.5, 0.00, 0.35)
    put(jm, drone(hz('F1'), 0.85, 0.5, 120, 380), 0.48)
    S['jump'] = (room(st(jm), 0.26), 0.78)
    scr = np.zeros(int(0.25*SR))
    put(scr, foley('metal_small', 0.15, hpf=1500), 0.00, 0.8)
    put(scr, _cym(hz('Ab5'), 0.20, 0.4), 0.01, 0.6)
    S['scrap_gain'] = (room(st(scr, 0.14), 0.15), 0.38)
    lt = np.zeros(int(1.20*SR))
    put(lt, foley('metal_small', 0.10, gain=0.5), 0.00)
    put(lt, _chime(hz('C6'), 0.85, 0.55), 0.02)
    put(lt, _chime(hz('F6'), 0.95, 0.42), 0.13)
    S['loot_drop'] = (room(st(lt), 0.32), 0.52)
    # Reworked on a listening note: the servo-and-latch read as a printer.
    # A module is BOLTED on -- so it is the wrench doing the work: two
    # turns, the torque-seat click, and the F answering that the part is
    # now part of the ship.
    ins = np.zeros(int(0.90*SR))
    put(ins, foley('wrench_work', 0.45, hpf=250), 0.00, 0.9)
    put(ins, foley('wrench_seat', 0.25, hpf=300), 0.48, 1.0)
    put(ins, thunk(hz('F2'), 0.16, 0.15), 0.50, 0.5)
    put(ins, click(hz('F4'), 0.08, tone=0.4), 0.52, 0.4)
    S['module_install'] = (room(st(ins), 0.14), 0.60)
    dk = np.zeros(int(1.30*SR))
    put(dk, foley('servo_move', 0.50, lpf=2500), 0.00, 0.6)
    put(dk, foley('metal_big', 0.45, lpf=3000), 0.52, 0.9)
    put(dk, foley('latch', 0.12), 0.70, 0.8)
    put(dk, thunk(hz('F1'), 0.30, 0.35), 0.52, 0.6)
    S['station_dock'] = (room(st(dk), 0.22), 0.74)
    jt = np.zeros(int(1.00*SR))
    put(jt, foley('latch', 0.08, gain=0.7), 0.00)
    put(jt, foley('air_hiss', 0.60, gain=1.0), 0.05)
    put(jt, foley('whoosh', 0.40, gain=0.35, hpf=500), 0.30)
    put(jt, thunk(hz('F2'), 0.12, 0.2), 0.06, 0.4)
    S['jettison'] = (room(st(jt), 0.18), 0.56)

    # ---- paperwork ----------------------------------------------------
    cs = np.zeros(int(0.42*SR))
    put(cs, foley('card_snap', 0.10, lpf=3000), 0.00, 0.9)
    put(cs, thunk(hz('F2'), 0.13, 0.3), 0.002, 0.7)
    put(cs, tone('F4', 0.10, 0.28), 0.012)
    put(cs, tone('C5', 0.10, 0.22), 0.012)
    S['contract_stamp'] = (st(cs, -0.10), 0.52)
    ar = np.zeros(int(0.95*SR))
    put(ar, foley('paper_slide', 0.20, gain=0.6), 0.00)
    put(ar, _chime(hz('F6'), 0.70, 0.30), 0.14)
    S['archive_found'] = (room(st(ar, 0.10), 0.26), 0.40)

    # ---- station services ---------------------------------------------
    # Four purchases, four different kinds of work, all heard from inside
    # the ship they are being done to.  Repairing YOUR hull earns warmth
    # (the ship is the warm thing); coolant is the one deliberately cold
    # purchase -- it is refrigerant, and the falling minor third says the
    # temperature went down.
    rp = np.zeros(int(0.85*SR))
    put(rp, foley('wrench_work', 0.40, hpf=300), 0.00, 0.9)  # the real wrench
    put(rp, foley('metal_small', 0.20, lpf=5000), 0.42, 0.8)  # plate seats
    put(rp, thunk(hz('F2'), 0.22, 0.15), 0.43, 0.6)         # ...and the ship
    S['svc_repair'] = (room(st(rp), 0.15), 0.55)            # answers, warm
    # Refuel: nozzle in, flow, and the tank's pitch RISES as it fills --
    # the oldest liquid cue there is -- then the nozzle out.
    rf = np.zeros(int(1.30*SR))
    put(rf, foley('latch', 0.08), 0.00, 0.7)
    N = int(0.85*SR); t = np.arange(N)/SR
    fill = lp(np.random.randn(N), 900)*0.5
    fill += np.sin(2*np.pi*(hz('F3')*(1+0.5*t/0.85))*t)*0.22   # rising body
    put(rf, fill*env_adsr(N, 0.06, 0.2, 0.7, 0.25), 0.10)
    put(rf, foley('latch', 0.08, gain=0.8), 1.05)
    S['svc_refuel'] = (room(st(rf), 0.14), 0.52)
    # System repair: fine electronics work, and the fault LEAVES -- the
    # little static tick dies and a clean Ab answers where it was.
    pg = np.zeros(int(0.80*SR))
    put(pg, foley('static_tick', 0.10, hpf=1200), 0.00, 0.7)
    put(pg, foley('servo_move', 0.18, lpf=3500), 0.08, 0.6)
    put(pg, foley('click_mech', 0.06), 0.30, 0.8)
    put(pg, tone('Ab5', 0.30, 0.30), 0.38)
    S['svc_purge'] = (room(st(pg), 0.16), 0.48)
    # Coolant: pressurised, COLD, and falling.  Db down to Ab -- the only
    # purchase whose pitch goes down, because that is what it bought.
    cl = np.zeros(int(0.90*SR))
    put(cl, foley('air_hiss', 0.45, hpf=900), 0.02, 0.9)
    put(cl, foley('latch', 0.08), 0.00, 0.6)
    put(cl, tone('Db5', 0.16, 0.30), 0.50)
    put(cl, tone('Ab4', 0.28, 0.34), 0.64)
    S['svc_coolant'] = (room(st(cl), 0.14), 0.50)

    # ---- the shelf and the rack ---------------------------------------
    # Five more desk actions, each its own gesture.  The blanket rule that
    # played module_install for every ship_changed made a sale sound like
    # an installation; now the sound follows the ACTION, wired at the UI.
    # Buying: the part comes over the counter and into the hold -- a slide,
    # a stow thud, and the credits tick going AWAY (down, F to C below).
    # Reworked: money changing hands should sound like a TILL. The
    # register's key-and-drawer does the work, coins land in the tray,
    # and the falling F keeps the "credits leaving" direction.
    by = np.zeros(int(0.85*SR))
    put(by, foley('register', 0.45, hpf=300), 0.00, 0.9)
    put(by, foley('coins', 0.30, hpf=400), 0.40, 0.7)
    put(by, click(hz('C5'), 0.05, tone=0.45), 0.55, 0.4)
    put(by, click(hz('F4'), 0.06, tone=0.45), 0.66, 0.4)
    S['shop_buy'] = (room(st(by), 0.13), 0.48)
    # Selling: the same slide the other way; scrap_gain rings the credits,
    # so this is just the part leaving the hold.
    sl = np.zeros(int(0.40*SR))
    put(sl, foley('paper_slide', 0.14, gain=0.5, hpf=400), 0.00)
    put(sl, foley('metal_small', 0.14, gain=0.7, lpf=4000), 0.12)
    S['shop_sell'] = (room(st(sl), 0.12), 0.40)
    # Scrapping: a teardown, not a transaction. Ratchet backing bolts out,
    # parts hitting the tray, and no resolving pitch -- the module is gone.
    sc = np.zeros(int(0.95*SR))
    put(sc, foley('ratchet', 0.13, hpf=400), 0.00, 0.8)
    put(sc, foley('ratchet', 0.11, hpf=600), 0.18, 0.6)
    put(sc, foley('debris', 0.50, hpf=500), 0.32, 0.9)
    put(sc, thunk(hz('Eb2'), 0.18, 0.25), 0.34, 0.5)
    S['module_scrap'] = (room(st(sc), 0.16), 0.55)
    # Uninstall: the install run backwards -- latch opens, servo backs out.
    un = np.zeros(int(0.45*SR))
    put(un, foley('latch', 0.09), 0.00, 0.9)
    put(un, foley('servo_move', 0.22, lpf=3000), 0.10, 0.7)
    S['module_uninstall'] = (room(st(un), 0.14), 0.55)
    # A hull transfer is the biggest purchase on the desk: dock-scale
    # machinery, two heavy seats, and then the NEW ship answers warm --
    # same F the old one spoke.
    ht = np.zeros(int(1.60*SR))
    put(ht, foley('servo_move', 0.45, lpf=2000), 0.00, 0.7)
    put(ht, foley('metal_big', 0.40, lpf=2500), 0.50, 0.9)
    put(ht, foley('latch', 0.12), 0.95, 0.9)
    put(ht, thunk(hz('F1'), 0.35, 0.3), 0.95, 0.7)
    put(ht, tone('F4', 0.40, 0.30), 1.10)
    put(ht, tone('C5', 0.35, 0.22), 1.22)
    S['hull_transfer'] = (room(st(ht), 0.22), 0.72)
    # Fabrication: work happening -- servo, sparks, and the finished part
    # dropped on the bench with a clean fifth over it.
    fb = np.zeros(int(1.10*SR))
    put(fb, foley('servo_move', 0.30, lpf=4500), 0.00, 0.8)
    put(fb, foley('static_tick', 0.10, hpf=1500), 0.28, 0.7)
    put(fb, foley('static_tick', 0.08, hpf=2000), 0.42, 0.5)
    put(fb, foley('metal_small', 0.18), 0.62, 0.8)
    put(fb, tone('F5', 0.22, 0.26), 0.70)
    put(fb, tone('C6', 0.20, 0.20), 0.80)
    S['fabricate'] = (room(st(fb), 0.16), 0.52)

    # ---- run-level stings ---------------------------------------------
    cb = np.zeros(int(1.80*SR))
    put(cb, _gong(0.6, 1.4), 0.00)
    put(cb, _bd(0.9), 0.01, 0.7)
    put(cb, cluster([hz('F3'), hz('B3'), hz('C4')], 1.5, 0.40, 1100), 0.06)
    S['combat_start'] = (room(st(cb), 0.26), 0.86)
    vc = np.zeros(int(1.90*SR))
    for note, at, dur, amp in [('C6', 0.00, 0.30, 0.45), ('Ab6', 0.13, 0.34, 0.42),
                               ('F6', 0.28, 1.10, 0.55)]:
        put(vc, tone(note, dur, amp), at)
    put(vc, _chime(hz('F5'), 1.4, 0.30), 0.28)
    put(vc, _pf(hz('F4'), 1.2, 0.5), 0.28)
    S['victory'] = (room(st(vc), 0.32), 0.56)
    ds = np.zeros(int(2.50*SR))
    put(ds, bowed(hz('F2'), 1.10, 0.55, 3.2), 0.00)
    put(ds, bowed(hz('Gb2'), 1.40, 0.50, 3.4), 0.85)
    put(ds, drone(hz('F1'), 2.0, 0.30, 70, 150), 0.10)
    put(ds, _gong(0.25, 2.2), 0.85)
    S['death_sting'] = (room(st(ds), 0.30), 0.80)

    # ---- deaths -------------------------------------------------------
    ex = np.zeros(int(1.20*SR))
    put(ex, foley('boom_deep', 0.70), 0.00, 1.0)
    put(ex, _bd(1.0), 0.005, 0.8)
    put(ex, foley('debris', 0.8, gain=0.6, hpf=800), 0.10)
    put(ex, _cym(hz('Ab5'), 0.7, 0.25), 0.12)
    S['explosion_small'] = (room(st(ex), 0.24), 0.90)
    bx = np.zeros(int(2.60*SR))
    put(bx, foley('boom_deep', 0.60), 0.00, 0.9)
    put(bx, _bd(1.0), 0.004, 0.8)
    put(bx, foley('boom_deep', 1.2, lpf=1200), 0.60, 1.0)
    put(bx, _gong(0.5, 1.8), 0.62)
    put(bx, foley('debris', 1.3, gain=0.7, hpf=600), 0.70)
    put(bx, _cym(hz('B4'), 1.4, 0.30), 0.66)
    put(bx, _cym(hz('F5'), 1.2, 0.20), 0.74)
    S['explosion_boss'] = (room(st(bx), 0.30), 1.00)
    ff = np.zeros(int(2.10*SR))
    put(ff, bowed(hz('Ab2'), 0.90, 0.40, 3.0), 0.00)
    put(ff, bowed(hz('F2'), 1.20, 0.36, 3.2), 0.70)
    put(ff, _chime(hz('Ab5'), 1.1, 0.20), 0.75)
    put(ff, foley('air_hiss', 0.8, gain=0.15, lpf=1500), 0.90)
    S['fauna_falls'] = (room(st(ff), 0.34), 0.62)
    return S


def main(out_dir='out/sfx'):
    os.makedirs(out_dir, exist_ok=True)
    for name, (y, peak) in sorted(build_all().items()):
        y = np.asarray(y, dtype=np.float64)
        if y.ndim == 1: y = st(y)
        y = wide(y, WIDTH.get(name, WIDTH_DEFAULT))
        n = y.shape[1]
        ki = max(1, min(int(0.0008*SR), n//10))
        ko = max(1, min(int(0.005*SR), n//5))
        y[:, :ki] *= np.linspace(0, 1, ki); y[:, -ko:] *= np.linspace(1, 0, ko)
        m = np.max(np.abs(y))
        if m > 0: y = y/m*peak
        write_wav('%s/%s.wav' % (out_dir, name), y)
        print('  %-18s %5.2f s  peak %.2f' % (name, y.shape[1]/SR, np.max(np.abs(y))))


if __name__ == '__main__':
    main()
