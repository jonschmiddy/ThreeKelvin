import numpy as np
from scipy import signal

SR = 44100
BPM = 142.0
SPB = 60.0 / BPM          # seconds per beat
BAR = 4 * SPB             # seconds per 4/4 bar

def set_tempo(bpm):
    """Rebind tempo globals. Call BEFORE `from synth import *` in a score."""
    global BPM, SPB, BAR
    BPM = float(bpm); SPB = 60.0/BPM; BAR = 4*SPB
    return BPM, SPB, BAR

NAMES = {'C':0,'C#':1,'Db':1,'D':2,'D#':3,'Eb':3,'E':4,'F':5,'F#':6,'Gb':6,
         'G':7,'G#':8,'Ab':8,'A':9,'A#':10,'Bb':10,'B':11}

def hz(n):
    """'Ab4' -> frequency in Hz."""
    if isinstance(n, (int, float)):
        return float(n)
    i = 2 if len(n) > 2 and n[1] in '#b' else 1
    midi = 12 * (int(n[i:]) + 1) + NAMES[n[:i]]
    return 440.0 * 2 ** ((midi - 69) / 12.0)

def env_adsr(N, a=0.01, d=0.1, s=0.7, r=0.2):
    a_n, d_n, r_n = int(a*SR), int(d*SR), int(r*SR)
    s_n = max(0, N - a_n - d_n - r_n)
    if s_n == 0:
        a_n = int(N*0.1); d_n = int(N*0.3); r_n = N - a_n - d_n; s_n = 0
    parts = [np.linspace(0, 1, a_n, endpoint=False),
             np.linspace(1, s, d_n, endpoint=False),
             np.full(s_n, s),
             np.linspace(s, 0, max(1, N - a_n - d_n - s_n))]
    e = np.concatenate(parts)[:N]
    return np.pad(e, (0, max(0, N - len(e))))

def env_exp(N, atk=0.002, tau=0.25):
    a = int(atk*SR)
    e = np.exp(-np.arange(N)/(tau*SR))
    if a > 0:
        e[:a] *= np.linspace(0, 1, a)
    return e

def lp(x, fc, order=2):
    b, a = signal.butter(order, min(fc/(SR/2), 0.99), 'low')
    return signal.lfilter(b, a, x)

def hp(x, fc, order=2):
    b, a = signal.butter(order, min(fc/(SR/2), 0.99), 'high')
    return signal.lfilter(b, a, x)

def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo/(SR/2), min(hi/(SR/2), 0.99)], 'band')
    return signal.lfilter(b, a, x)

# ---------------- instruments (mono float arrays) ----------------

def whistle(f, dur, amp=1.0, vib=0.011, vrate=5.0):
    """Near-sine, matches the measured recording: ~5 Hz vibrato, tiny 2nd harmonic."""
    N = int(dur*SR); t = np.arange(N)/SR
    vdepth = vib * np.minimum(1.0, t/0.18)          # vibrato fades in
    ph = 2*np.pi*f*np.cumsum(1 + vdepth*np.sin(2*np.pi*vrate*t))/SR
    y = np.sin(ph) + 0.045*np.sin(2*ph) + 0.012*np.sin(3*ph)
    breath = hp(np.random.randn(N), 2500) * 0.010 * np.exp(-t/0.12)
    return amp * (y * env_adsr(N, 0.045, 0.08, 0.85, min(0.28, dur*0.5)) + breath)

def saw(f, N, detune=0.0):
    t = np.arange(N)/SR
    ph = 2*np.pi*f*(1+detune)*t
    y = np.zeros(N)
    for k in range(1, 26):
        if f*k > SR/2.2: break
        y += np.sin(k*ph)/k
    return y*0.55

def pad(freqs, dur, amp=1.0, cutoff=1900):
    N = int(dur*SR)
    y = np.zeros(N)
    for f in freqs:
        for dt in (-0.005, 0.0, 0.006):
            y += saw(f, N, dt) / (len(freqs)*3)
    y = lp(y, cutoff, 2)
    lfo = 1 + 0.06*np.sin(2*np.pi*0.23*np.arange(N)/SR)
    return amp * y * env_adsr(N, 0.55, 0.4, 0.78, 0.9) * lfo

def sub(f, dur, amp=1.0):
    N = int(dur*SR); t = np.arange(N)/SR
    y = np.sin(2*np.pi*f*t) + 0.22*np.sin(4*np.pi*f*t) + 0.08*signal.square(2*np.pi*f*t)
    return amp * y * env_adsr(N, 0.008, 0.12, 0.85, 0.10)

def pluck(f, dur, amp=1.0, damp=0.494):
    """Karplus-Strong."""
    N = int(dur*SR); L = max(2, int(SR/f))
    buf = np.random.randn(L) * np.hanning(L)
    y = np.zeros(N); i = 0
    for n in range(N):
        y[n] = buf[i]
        buf[i] = damp*(buf[i] + buf[(i+1) % L])
        i = (i+1) % L
    return amp * y * env_exp(N, 0.001, dur*0.42)

def bell(f, dur, amp=1.0):
    N = int(dur*SR); t = np.arange(N)/SR
    y = np.zeros(N)
    for r, a, tau in [(1,1.0,0.9),(2.01,0.5,0.5),(3.02,0.28,0.3),(4.97,0.14,0.18)]:
        y += a*np.sin(2*np.pi*f*r*t)*np.exp(-t/(tau*dur))
    return amp * y * env_exp(N, 0.001, dur*0.55) * 0.5

def kick(amp=1.0):
    N = int(0.42*SR); t = np.arange(N)/SR
    f = 118*np.exp(-t/0.028) + 44
    y = np.sin(2*np.pi*np.cumsum(f)/SR) * np.exp(-t/0.16)
    click = hp(np.random.randn(N), 1800)*np.exp(-t/0.004)*0.32
    return amp*np.tanh(1.5*(y+click))*0.85

def snare(amp=1.0):
    N = int(0.30*SR); t = np.arange(N)/SR
    n = bp(np.random.randn(N), 900, 7500)*np.exp(-t/0.075)
    tone = (np.sin(2*np.pi*196*t)+np.sin(2*np.pi*268*t))*np.exp(-t/0.045)*0.35
    return amp*(n+tone)*0.7

def hat(dur=0.055, amp=1.0):
    N = int(dur*SR); t = np.arange(N)/SR
    return amp*hp(np.random.randn(N), 8200)*np.exp(-t/(dur*0.32))*0.5

def noise_swell(dur, amp=1.0):
    N = int(dur*SR); t = np.arange(N)/SR
    return amp*bp(np.random.randn(N), 300, 6000)*(t/dur)**2.4*0.5

# ---------------- effects ----------------

def make_ir(dur=2.6, decay=1.5, pre=0.02):
    N = int(dur*SR); t = np.arange(N)/SR
    ir = np.random.randn(N)*np.exp(-t/decay)
    ir = lp(ir, 6500); ir = hp(ir, 180)
    ir[:int(pre*SR)] *= np.linspace(0, 1, int(pre*SR))**2
    return ir/np.max(np.abs(ir))

np.random.seed(4242)          # fixed reverb impulses
IR_L = make_ir(2.8, 1.6)
IR_R = make_ir(2.8, 1.55)

def reverb(x_st, wet=0.3):
    L = signal.fftconvolve(x_st[0], IR_L)[:x_st.shape[1]]
    R = signal.fftconvolve(x_st[1], IR_R)[:x_st.shape[1]]
    w = np.stack([L, R])
    m = np.max(np.abs(w))
    if m > 0: w /= m/ (np.max(np.abs(x_st))+1e-9)
    return (1-wet)*x_st + wet*w

def delay(x_st, time_s, fb=0.42, mix=0.32):
    d = int(time_s*SR); y = x_st.copy()
    tap = x_st.copy(); g = 1.0
    for _ in range(6):
        g *= fb
        if g < 0.02: break
        tap = np.pad(tap, ((0,0),(d,0)))[:, :x_st.shape[1]]
        tap[0] = lp(tap[0], 5200); tap[1] = lp(tap[1], 4600)
        y += mix*g*tap[::-1]          # ping-pong
    return y

# ---------------- arrangement helpers ----------------

class Track:
    def __init__(self, bars):
        self.n = int(bars*BAR*SR) + SR*3
        self.buf = np.zeros((2, self.n))
    def add(self, x, at_beat, pan=0.0, gain=1.0):
        i = int(at_beat*SPB*SR)
        j = min(self.n, i+len(x))
        if j <= i: return
        seg = x[:j-i]*gain
        L = np.cos((pan+1)*np.pi/4); R = np.sin((pan+1)*np.pi/4)
        self.buf[0, i:j] += seg*L
        self.buf[1, i:j] += seg*R
    def out(self):
        return self.buf

# ================= dread instrument set =================

def drone(f, dur, amp=1.0, cut0=280, cut1=900):
    """Low bowed mass. Slow filter opening, heavy detune, no clear attack."""
    N = int(dur*SR); t = np.arange(N)/SR
    y = np.zeros(N)
    for dt in (-0.010, -0.004, 0.0, 0.005, 0.011):
        y += saw(f*(1+dt), N)/5
    y += 0.25*np.sin(2*np.pi*f*0.5*t)                 # sub octave
    op = np.clip(t/(dur*0.55), 0, 1)
    seg = int(SR*0.25); out = np.zeros(N)
    for i in range(0, N, seg):                        # stepped filter sweep
        fc = cut0 + (cut1-cut0)*op[min(i, N-1)]
        out[i:i+seg] = lp(y[i:i+seg], fc, 2)
    return amp*out*env_adsr(N, dur*0.30, dur*0.15, 0.85, dur*0.32)

def cluster(freqs, dur, amp=1.0, cut=1400):
    """Minor-2nd stack. Beating between adjacent partials does the work."""
    N = int(dur*SR); y = np.zeros(N)
    for i, f in enumerate(freqs):
        for dt in (-0.004, 0.004):
            y += saw(f, N, dt)/(len(freqs)*2)
    y = lp(y, cut, 2)
    return amp*y*env_adsr(N, dur*0.38, dur*0.2, 0.8, dur*0.35)

def bowed(f, dur, amp=1.0, res=3.0):
    """Bowed-string-ish: sawtooth + bow noise through a resonant band."""
    N = int(dur*SR); t = np.arange(N)/SR
    jit = 1 + 0.0025*np.cumsum(np.random.randn(N))/SR*40
    ph = 2*np.pi*f*np.cumsum(jit)/SR
    y = signal.sawtooth(ph)*0.6
    y += bp(np.random.randn(N), f*0.8, f*4)*0.16      # bow noise
    y = bp(y, f*0.75, f*res, 2) + 0.5*lp(y, f*2, 2)
    return amp*y*env_adsr(N, dur*0.22, dur*0.1, 0.85, dur*0.35)*0.7

def metal(f, dur, amp=1.0):
    """Inharmonic struck/bowed metal — long, slightly sour tail."""
    N = int(dur*SR); t = np.arange(N)/SR; y = np.zeros(N)
    for r, a in [(1,1.0),(1.41,0.62),(2.37,0.44),(3.16,0.3),(4.53,0.2),(6.11,0.12)]:
        y += a*np.sin(2*np.pi*f*r*t + np.random.rand()*6)*np.exp(-t/(dur*0.42/r**0.4))
    return amp*y*0.30

def heart(amp=1.0):
    """Two-thump pulse. Felt more than heard."""
    out = np.zeros(int(0.85*SR))
    for off, g in [(0.0, 1.0), (0.235, 0.62)]:
        N = int(0.34*SR); t = np.arange(N)/SR
        f = 62*np.exp(-t/0.05) + 31
        th = np.sin(2*np.pi*np.cumsum(f)/SR)*np.exp(-t/0.11)*g
        i = int(off*SR); out[i:i+N] += th
    return amp*out*0.9

def impact(amp=1.0, dur=3.4):
    N = int(dur*SR); t = np.arange(N)/SR
    boom = np.sin(2*np.pi*np.cumsum(48*np.exp(-t/0.35)+27)/SR)*np.exp(-t/0.9)
    crack = lp(np.random.randn(N), 900)*np.exp(-t/0.22)*0.5
    tail = bp(np.random.randn(N), 120, 2200)*np.exp(-t/1.5)*0.16
    return amp*np.tanh(1.4*(boom+crack+tail))*0.8

def rev_swell(dur, amp=1.0, f=None):
    """Reversed rise — lands on the downbeat after it."""
    N = int(dur*SR); t = np.arange(N)/SR
    n = bp(np.random.randn(N), 200, 5200)
    if f: n = n*0.5 + np.sin(2*np.pi*f*t)*0.5
    y = n*np.exp(-t/(dur*0.4))
    return amp*y[::-1]*0.55

def whistle_bend(f, dur, amp=1.0, cents=0.0, vib=0.013):
    """Whistle whose pitch drifts by `cents` across its length."""
    N = int(dur*SR); t = np.arange(N)/SR
    bend = 2**((cents*(t/dur))/1200)
    vd = vib*np.minimum(1.0, t/0.25)
    ph = 2*np.pi*f*np.cumsum(bend*(1+vd*np.sin(2*np.pi*4.4*t)))/SR
    y = np.sin(ph) + 0.05*np.sin(2*ph)
    br = hp(np.random.randn(N), 2200)*0.014*np.exp(-t/0.2)
    return amp*(y*env_adsr(N, 0.09, 0.14, 0.85, min(0.5, dur*0.45)) + br)

def air(dur, amp=1.0, lo=120, hi=1400):
    N = int(dur*SR); t = np.arange(N)/SR
    n = bp(np.random.randn(N), lo, hi)
    m = 1 + 0.5*np.sin(2*np.pi*0.11*t) + 0.3*np.sin(2*np.pi*0.047*t+1.1)
    return amp*n*m*env_adsr(N, dur*0.25, dur*0.2, 0.9, dur*0.3)*0.4


# ================= master bus =================
# Both scores used to print stems straight off the instrument chain and apply
# the bus (low-shelf cut -> soft clip -> peak normalise -> fades) to the mix
# only.  The stems therefore neither summed to the mix nor sat at its level:
# the dread stems needed +3.7 dB to match, and because the last stage is a peak
# normalise the correction was render-dependent, so there was no fixed number
# to compensate with either.  A game that layers stems at runtime is building
# the mix itself, so it has to be the same mix.

def _bus_shelf(x, k, fc):
    """The tilt used on both cues: subtract k of the lowpassed signal."""
    return x - k*lp(x, fc, 2)

def master(stems, shelf=(0.25, 90), drive=1.25, peak=0.89,
           fade_in=(0.05, 1.0), fade_out=(2.6, 1.6),
           highpass=None, loop_len=None):
    """Sum rendered stems through the master bus.  Returns (mix, printed).

    Every stage is applied identically to the bus and to each stem, so the
    printed stems sum back to the mix sample-for-sample.  The soft clipper is
    the only non-linear stage, and it is applied as a *shared gain curve* taken
    from the summed bus -- which is what printing stems off a real mix bus
    does.  The identity that makes it exact:

        tanh(a*b)/a  ==  b * G     where  G = tanh(a*b)/(a*b)

    G depends only on the bus, so scaling every stem by it and summing
    reproduces the clipped bus rather than approximating it.

    highpass: corner in Hz for a bus high-pass.  drone() adds a hardcoded
        sub-octave, so an F1 pedal puts its strongest partial at 21.8 Hz --
        below the reproduction floor of every laptop, phone and TV, while still
        driving the clipper.  Set this to reclaim that headroom.
    loop_len: length in samples of the musical body.  Skips the fade-out and
        wraps the reverb tail past loop_len back over the head, so the file
        loops without a seam or a gap.
    """
    names = list(stems)
    bus = sum(stems[n] for n in names)

    # Linear stages first: filters distribute over a sum exactly.
    def lin(x):
        y = _bus_shelf(x, shelf[0], shelf[1])
        return hp(y, highpass, 2) if highpass else y
    bus = lin(bus)
    printed = {n: lin(stems[n]) for n in names}

    d = drive*bus
    safe = np.where(np.abs(d) > 1e-9, d, 1.0)
    G = np.where(np.abs(d) > 1e-9, np.tanh(d)/safe, 1.0)

    bus = bus*G
    g = peak/np.max(np.abs(bus))
    bus = bus*g
    printed = {n: v*G*g for n, v in printed.items()}

    if loop_len:
        def wrap(x):
            body = x[:, :loop_len].copy()
            tail = x[:, loop_len:]
            m = min(tail.shape[1], loop_len)
            body[:, :m] += tail[:, :m]
            return body
        bus = wrap(bus)
        printed = {n: wrap(v) for n, v in printed.items()}
        m = np.max(np.abs(bus))          # the wrap can push the sum past the ceiling
        if m > peak:
            bus = bus*(peak/m)
            printed = {n: v*(peak/m) for n, v in printed.items()}
    else:
        env = np.ones(bus.shape[1])
        if fade_in[0] > 0:
            k = int(fade_in[0]*SR); env[:k] = np.linspace(0, 1, k)**fade_in[1]
        if fade_out[0] > 0:
            k = int(fade_out[0]*SR); env[-k:] = np.linspace(1, 0, k)**fade_out[1]
        bus = bus*env
        printed = {n: v*env for n, v in printed.items()}
    return bus, printed

def write_wav(path, x):
    """Write a (2, N) float buffer as 16-bit stereo."""
    import os, scipy.io.wavfile as wav
    os.makedirs(os.path.dirname(path) or '.', exist_ok=True)
    wav.write(path, SR, (np.clip(x.T, -1, 1)*32767).astype(np.int16))
