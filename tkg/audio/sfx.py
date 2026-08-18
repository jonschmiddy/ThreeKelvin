"""Sound effects for Three Kelvin.

Built on the same synth as the music, and tuned to the same key, so the
interface sits inside the score rather than on top of it.  Every pitched sound
here uses F minor degrees -- F, G, Ab, C, Db, Eb -- which means a click landing
under the theme is consonant with whatever chord happens to be running.

Art direction translated to sound (`CLAUDE.md`, "Cold universe, warm ship"):

  * Chrome is cold.  Interface sounds are dry, thin, quiet and mechanical --
    small relays and switch contacts, no reverb tail worth speaking of.
  * Warmth is emitted, never ambient.  Only the things that actually radiate
    -- reactor, weapons fire, heat, the ship itself -- get a warm low body.
  * Ballistics run cold, energy weapons run hot.  The two weapon sounds carry
    that ruling: one is a dry mechanical crack, the other a bright ionised zap.
  * Melancholy comes from restraint.  Nothing here is a cartoon coin or a
    fanfare.  Rewards are a small bell, not a jingle.

Run:  python3 sfx.py            # -> out/sfx/*.wav
"""
import numpy as np, os
np.random.seed(31415)             # renders are deterministic
import synth
from synth import *

# A UI sound with a two-second concert tail reads as an echo in a cathedral.
# These are small hard surfaces a few feet away.
def _room(dur=0.30, decay=0.10):
    N = int(dur*SR); t = np.arange(N)/SR
    ir = np.random.randn(N)*np.exp(-t/decay)
    ir = lp(ir, 7000); ir = hp(ir, 400)
    return ir/np.max(np.abs(ir))

np.random.seed(2024)
ROOM_L, ROOM_R = _room(0.30, 0.10), _room(0.30, 0.095)

def room(x, wet=0.18):
    from scipy import signal as _sg
    L = _sg.fftconvolve(x[0], ROOM_L)[:x.shape[1]]
    R = _sg.fftconvolve(x[1], ROOM_R)[:x.shape[1]]
    w = np.stack([L, R]); m = np.max(np.abs(w))
    if m > 0: w *= np.max(np.abs(x))/m
    return (1-wet)*x + wet*w

def put(buf, x, at=0.0, gain=1.0):
    """Add x into buf starting at `at` seconds, clipped to the buffer."""
    i = int(at*SR); j = min(len(buf), i+len(x))
    if j > i: buf[i:j] += x[:j-i]*gain
    return buf

def st(mono, pan=0.0):
    """Mono -> stereo with equal-power pan."""
    L = np.cos((pan+1)*np.pi/4); R = np.sin((pan+1)*np.pi/4)
    return np.stack([mono*L*1.414, mono*R*1.414])

# ---------------- small primitives ----------------

def click(f=1200, dur=0.045, tone=0.35, damp=0.16):
    """A switch contact.  Pure noise reads as static and pure tone reads as a
    beep; a click is a filtered impulse with just enough pitched body to have
    a key, which is what lets it sit in F minor with everything else."""
    N = int(dur*SR); t = np.arange(N)/SR
    n = hp(np.random.randn(N), f*0.55)*np.exp(-t/(dur*damp))
    b = np.sin(2*np.pi*f*t)*np.exp(-t/(dur*damp*1.5))
    return (1-tone)*n + tone*b

def thunk(f=95, dur=0.16, bite=0.25):
    """Dull low body that goes nowhere.  Refusal: nothing opens up."""
    N = int(dur*SR); t = np.arange(N)/SR
    y = np.sin(2*np.pi*f*t)*np.exp(-t/(dur*0.28))
    y += bite*lp(np.random.randn(N), 700)*np.exp(-t/(dur*0.09))
    return y

def servo(dur=0.14, f0=240, f1=90, buzz=0.5):
    """A small motor seating something.  Falling buzz -- a part going home."""
    N = int(dur*SR); t = np.arange(N)/SR
    f = f0*(f1/f0)**(t/dur)
    ph = 2*np.pi*np.cumsum(f)/SR
    y = _sq(ph)*buzz + np.sin(ph)*(1-buzz)
    return y*env_adsr(N, dur*0.06, dur*0.2, 0.75, dur*0.4)

def _sq(ph):
    return np.tanh(np.sin(ph)*3.5)/np.tanh(3.5)

def sweep(dur, lo0, lo1, hi0, hi1, curve=1.0):
    """Band-passed noise whose window travels.  Air moving, in blocks so the
    filter can actually change -- same stepped approach drone() uses."""
    N = int(dur*SR); t = np.arange(N)/SR
    n = np.random.randn(N); out = np.zeros(N); seg = int(SR*0.02)
    for i in range(0, N, seg):
        p = (min(i, N-1)/N)**curve
        out[i:i+seg] = bp(n[i:i+seg], lo0+(lo1-lo0)*p, hi0+(hi1-hi0)*p)
    return out

def zap(f, dur=0.22, bend=-0.55):
    """Energy weapon.  Bright, ionised, and it runs hot -- the pitch falls as
    the capacitor drains rather than holding a clean tone."""
    N = int(dur*SR); t = np.arange(N)/SR
    fr = f*(1+bend*(t/dur))
    ph = 2*np.pi*np.cumsum(fr)/SR
    y = _sq(ph)*0.6 + np.sin(2*ph)*0.25
    y += bp(np.random.randn(N), 1800, 9000)*0.35*np.exp(-t/(dur*0.12))
    return y*env_exp(N, 0.0015, dur*0.28)

def tone(note, dur, amp=1.0, vib=0.008):
    return whistle(hz(note), dur, amp, vib)

# ---------------- the set ----------------
# (name, builder, peak) -- peak is the balance decision, and it is the whole
# job.  Chrome sits far below gameplay so a menu is never louder than a fight.

def build_all():
    S = {}

    # ---- chrome: cold, dry, small -------------------------------------
    # A button is a relay closing. Two-layer: contact tick + a short Ab body.
    S['ui_click']   = (st(click(hz('Ab6'), 0.050, tone=0.30)*0.9), 0.34)
    # Hover is the same gesture at a whisper, and higher so it never competes.
    S['ui_hover']   = (st(click(hz('C7'), 0.026, tone=0.22, damp=0.10)), 0.11)
    # Confirm is the stinger specced in THEME_NOTES section 6: the motif's last
    # two notes, G -> Ab, a semitone rise. Half a second, no fanfare.
    conf = np.zeros(int(0.42*SR))
    put(conf, tone('G6', 0.13, 0.55), 0.00)
    put(conf, tone('Ab6', 0.26, 0.62), 0.10)
    S['ui_confirm'] = (room(st(conf), 0.22), 0.40)
    # Back inverts it -- Ab down to G. Same two notes, so leaving a screen is
    # audibly the same gesture as entering it, run backwards.
    back = np.zeros(int(0.30*SR))
    put(back, tone('Ab6', 0.10, 0.42), 0.00)
    put(back, tone('G6', 0.18, 0.46), 0.08)
    S['ui_back']    = (room(st(back), 0.16), 0.30)
    # Refusal. Low, dead, no pitch movement: the interface declines to open.
    S['ui_denied']  = (st(thunk(hz('F2'), 0.20, bite=0.30)), 0.42)
    # Screen change. A pressure door, not a swipe.
    S['ui_tab']     = (room(st(sweep(0.26, 300, 120, 3400, 900)*0.5
                               *env_adsr(int(0.26*SR), 0.01, 0.06, 0.5, 0.18)), 0.20), 0.30)

    # ---- cards --------------------------------------------------------
    # Draw is a card edge leaving the stack: noise, no pitch.
    N = int(0.09*SR); t = np.arange(N)/SR
    S['card_draw']  = (st(bp(np.random.randn(N), 1400, 8000)
                          *np.exp(-t/0.018)*(t/0.004).clip(0, 1), 0.12), 0.26)
    # Play is firmer and lands on the tonic -- committing to something.
    play = np.zeros(int(0.16*SR))
    put(play, click(hz('F6'), 0.07, tone=0.42), 0.000, 0.90)
    put(play, thunk(hz('F3'), 0.11, bite=0.1), 0.006, 0.35)
    S['card_play']  = (st(play, -0.08), 0.46)

    # ---- weapons: the thermal ruling, made audible ---------------------
    # Ballistics run cold -- dry mechanical crack, no ring, no glow.
    N = int(0.26*SR); t = np.arange(N)/SR
    bal = lp(np.random.randn(N), 2600)*np.exp(-t/0.012)
    bal += np.sin(2*np.pi*hz('F2')*t)*np.exp(-t/0.05)*0.7
    bal += bp(np.random.randn(N), 200, 1400)*np.exp(-t/0.10)*0.22
    S['weapon_ballistic'] = (room(st(bal, -0.12), 0.14), 0.72)
    # Energy weapons run hot -- bright, and it sags as it drains.
    S['weapon_energy']    = (room(st(zap(hz('C6'), 0.24), 0.10), 0.20), 0.66)
    # A charge weapon fires itself when ready, so this is a release, not a
    # trigger: the swell is already over by the time you hear the hit.
    ch = np.zeros(int(0.90*SR))
    put(ch, sweep(0.45, 120, 700, 900, 5200, curve=2.2)
            *np.linspace(0, 1, int(0.45*SR))**2.0, 0.00, 0.50)
    put(ch, zap(hz('F5'), 0.42, bend=-0.62), 0.40, 1.10)
    S['charge_fire'] = (room(st(ch), 0.24), 0.80)

    # ---- taking it ----------------------------------------------------
    # Hull damage: it is your ship, so it has a body and it rings a little.
    N = int(0.55*SR); t = np.arange(N)/SR
    dmg = np.sin(2*np.pi*hz('F1')*t)*np.exp(-t/0.13)
    dmg += lp(np.random.randn(N), 900)*np.exp(-t/0.05)*0.5
    put(dmg, metal(hz('Ab4'), 0.55, 0.22), 0.0)
    S['impact_hull'] = (room(st(dmg), 0.22), 0.85)
    # Blocked: bright, metallic, and over immediately. Nothing got through.
    S['shield_block'] = (room(st(metal(hz('C6'), 0.40, 0.55)*
                                 env_exp(int(0.40*SR), 0.001, 0.09), 0.06), 0.26), 0.54)

    # ---- heat: the second health bar ----------------------------------
    # Warning is a two-pulse tone. Related to the dread cue's heartbeat, so
    # running hot and being hunted sound like the same kind of trouble.
    warn = np.zeros(int(0.70*SR))
    for at in (0.0, 0.26):
        put(warn, tone('Db6', 0.16, 0.42, vib=0.004), at)
    S['heat_warn'] = (room(st(warn), 0.18), 0.40)
    # Overheat is the burn actually landing: a hot low body with grit on it.
    N = int(0.80*SR); t = np.arange(N)/SR
    ov = np.sin(2*np.pi*hz('F1')*t*(1-0.12*t/0.8))*np.exp(-t/0.24)
    ov += bp(np.random.randn(N), 120, 2600)*np.exp(-t/0.16)*0.42
    ov = np.tanh(ov*1.8)/1.8
    S['overheat'] = (room(st(ov), 0.20), 0.88)
    # Venting is a real action, so it gets a real sound: a valve opening and
    # heat leaving the ship.  Falling and resolving -- the exact opposite
    # gesture to overheat, which rises and then bites.
    vn = np.zeros(int(0.65*SR))
    put(vn, click(hz('C5'), 0.05, tone=0.30), 0.00, 0.55)
    put(vn, sweep(0.55, 900, 180, 7000, 1200, curve=0.7)
            *env_adsr(int(0.55*SR), 0.02, 0.10, 0.55, 0.30), 0.03, 0.60)
    S['vent'] = (room(st(vn), 0.16), 0.50)

    # ---- map, economy, refit ------------------------------------------
    # A jump. Air pulled out of the room, then the drone of the next place.
    jm = np.zeros(int(1.30*SR))
    put(jm, sweep(0.55, 200, 60, 5000, 400, curve=1.6)
            *np.linspace(0, 1, int(0.55*SR))**1.5, 0.00, 0.45)
    put(jm, drone(hz('F1'), 0.85, 0.5, 120, 380), 0.42)
    S['jump'] = (room(st(jm), 0.26), 0.78)
    # Scrap is the only currency, so it gets a sound -- but a cold metal tick,
    # not a coin. This game does not do jingles.
    N = int(0.20*SR); t = np.arange(N)/SR
    scr = bp(np.random.randn(N), 2500, 11000)*np.exp(-t/0.012)*0.4
    put(scr, metal(hz('Ab5'), 0.20, 0.5), 0.0)
    S['scrap_gain'] = (room(st(scr, 0.14), 0.16), 0.38)
    # A drop is worth looking at: two bells a fourth apart, ringing on.
    lt = np.zeros(int(1.10*SR))
    put(lt, bell(hz('C6'), 0.85, 0.55), 0.00)
    put(lt, bell(hz('F6'), 0.95, 0.42), 0.11)
    S['loot_drop'] = (room(st(lt), 0.34), 0.52)
    # A module seating in a hardpoint: servo, then the latch.
    ins = np.zeros(int(0.42*SR))
    put(ins, servo(0.17, 260, 95), 0.00, 0.50)
    put(ins, click(hz('F4'), 0.09, tone=0.40), 0.15, 0.85)
    put(ins, thunk(hz('F2'), 0.16, 0.2), 0.15, 0.30)
    S['module_install'] = (room(st(ins), 0.16), 0.60)
    # Docking clamps. Big, slow, mechanical, and it resolves.
    dk = np.zeros(int(1.20*SR))
    put(dk, servo(0.55, 150, 60, buzz=0.65), 0.00, 0.45)
    for at in (0.50, 0.66):
        put(dk, thunk(hz('F1'), 0.30, bite=0.35), at, 0.80)
    S['station_dock'] = (room(st(dk), 0.22), 0.74)

    # ---- run-level stings ---------------------------------------------
    # Contact. The dread cue's tritone, stated flat: F against B, no melody.
    cb = np.zeros(int(1.60*SR))
    put(cb, impact(0.55, 1.2), 0.00)
    put(cb, cluster([hz('F3'), hz('B3'), hz('C4')], 1.5, 0.40, 1100), 0.05)
    S['combat_start'] = (room(st(cb), 0.26), 0.86)
    # Victory does not celebrate. It just resolves to the tonic and stops.
    vc = np.zeros(int(1.80*SR))
    for note, at, dur, amp in [('C6', 0.00, 0.30, 0.45), ('Ab6', 0.13, 0.34, 0.42),
                               ('F6', 0.28, 1.10, 0.55)]:
        put(vc, tone(note, dur, amp), at)
    put(vc, bell(hz('F5'), 1.4, 0.30), 0.28)
    S['victory'] = (room(st(vc), 0.34), 0.56)
    # Death sting, exactly as specced in DREAD_NOTES section 5: just the
    # semitone, F -> Gb, on a single low bowed note. Two seconds.
    ds = np.zeros(int(2.40*SR))
    put(ds, bowed(hz('F2'), 1.10, 0.55, 3.2), 0.00)
    put(ds, bowed(hz('Gb2'), 1.40, 0.50, 3.4), 0.85)
    put(ds, drone(hz('F1'), 2.0, 0.30, 70, 150), 0.10)
    S['death_sting'] = (room(st(ds), 0.30), 0.80)
    return S

def main(out_dir='out/sfx'):
    os.makedirs(out_dir, exist_ok=True)
    for name, (y, peak) in sorted(build_all().items()):
        y = np.asarray(y, dtype=np.float64)
        if y.ndim == 1: y = st(y)
        # Edges first, then normalise.  A sample that starts or ends on a
        # non-zero value clicks -- and a click on every UI click is a long
        # mystery bug -- but these are transient sounds whose peak IS the
        # first millisecond, so the in-fade has to be short enough to leave
        # the attack alone, and normalising afterwards is what guarantees the
        # printed peak is the one the balance table asked for.
        n = y.shape[1]
        ki = max(1, min(int(0.0008*SR), n//10))
        ko = max(1, min(int(0.005*SR), n//5))
        y[:, :ki] *= np.linspace(0, 1, ki); y[:, -ko:] *= np.linspace(1, 0, ko)
        m = np.max(np.abs(y))
        if m > 0: y = y/m*peak
        write_wav('%s/%s.wav' % (out_dir, name), y)
        print('  %-18s %5.2f s  peak %.2f' % (name, y.shape[1]/SR, np.max(np.abs(y))))

def audition(out_path='out/sfx_audition.wav', gap=0.9):
    """Every sound in one file, in balance order, spaced so you can hear each
    one land. This is the review artefact -- twenty-four separate files is not
    something anyone can judge a set from."""
    S = build_all()
    order = sorted(S, key=lambda n: (n.split('_')[0], n))
    parts = []
    for name in order:
        y = np.asarray(S[name][0], dtype=np.float64)
        if y.ndim == 1: y = st(y)
        m = np.max(np.abs(y))
        if m > 0: y = y/m*S[name][1]
        parts.append(y)
        parts.append(np.zeros((2, int(gap*SR))))
        print('  %-18s %.2f s' % (name, y.shape[1]/SR))
    write_wav(out_path, np.concatenate(parts, axis=1))
    print('audition -> %s' % out_path)

if __name__ == '__main__':
    import sys
    if '--audition' in sys.argv:
        audition()
    else:
        main()
