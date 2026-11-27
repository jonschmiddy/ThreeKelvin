"""The station decks' sound (Jon, Nov 26 picks): the game's files, their measurements and each deck's plan, made from
the station-sound page's own mixer (tk-scratch/station-sound/mix/tools: decks.py's recipes, smix.py's rules), so the
game plays the sounds the approved mixes were built from. Docs: docs/why/StationSound.md.

  uv run --with numpy --with scipy --with soundfile --with psutil --with pyloudnorm python -I tools/dev/station_sound.py build
      writes tkg/assets/audio/station/*.wav and station.json (files, rooms, the bus EQ, the halls, the PA's speakers)
  ... station_sound.py halls
      fits each room's Godot reverb (room size, damping, level) to the mixer's hall, on an emulation of Godot's reverb
  ... station_sound.py measure FILE [FILE ...]
      LUFS, LRA, true peak and the 2-8 kHz share (dB of 20 Hz-16 kHz) of a capture or a page mix
  ... station_sound.py pa
      re-measures the PA table (tkg/assets/audio/station/pa.json): run it after dropping in new takes

Needs the station-sound folder: TK_SCRATCH/station-sound (TK_SCRATCH, else the nearest tk-scratch above the repo).
Runs at Idle priority on cores 0-7.
"""
import json
import math
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SCRATCH = Path(os.environ.get("TK_SCRATCH") or next((q / "tk-scratch" for q in REPO.parents
                                                   if (q / "tk-scratch" / "station-sound").is_dir()), ""))
SS = SCRATCH / "station-sound"
sys.path.insert(0, str(SS / "mix" / "tools"))
import psutil  # noqa: E402

_me = psutil.Process()
_me.cpu_affinity(list(range(min(8, psutil.cpu_count()))))
if hasattr(psutil, "IDLE_PRIORITY_CLASS"):
    _me.nice(psutil.IDLE_PRIORITY_CLASS)
_argv = sys.argv
sys.argv = [sys.argv[0]]
import numpy as np  # noqa: E402
import soundfile as sf  # noqa: E402
from scipy import signal  # noqa: E402
import smix as S  # noqa: E402
import decks as DK  # noqa: E402
sys.argv = _argv

G = S.G                                                        # the hangar mixer's namespace smix runs on
SR = S.SR
ARGS = sys.argv[1:]
OUT = REPO / "tkg" / "assets" / "audio" / "station"
GAME = REPO / "tkg" / "assets" / "audio"
S.GAME = GAME                                                  # (the mixer's game: sources from this checkout, not main's)
EQ21 = [22, 32, 44, 63, 90, 125, 175, 250, 350, 500, 700, 1000, 1400, 2000, 2800, 4000, 5600, 8000, 11000, 16000, 22000]
TIERS = ["unclaimed", "outpost", "settlement", "city", "capital"]
# Each deck's picks (Jon, Nov 26) by tier: (decks.py deck, concept, the tier's change on it). Low beds below
# settlement, high from it; capital the same bed darker and lower (plan.md). Why: docs/why/StationSound.md#tiers
CAPITAL = dict(bed_dark=0.35, bed_db=-3.0)
PICKS = {
    "prom": {"unclaimed": ("prom_u", "C", {}), "outpost": ("prom_u", "C", dict(pa="cheap")),
             "settlement": ("prom", "B", {}), "city": ("prom", "B", {}), "capital": ("prom", "B", CAPITAL)},
    "yard": {"unclaimed": ("yard_u", "A", {}), "outpost": ("yard_u", "A", dict(pa="far")),
             "settlement": ("yard", "B", {}), "city": ("yard", "B", {}), "capital": ("yard", "B", CAPITAL)},
    "exch": {"unclaimed": ("exch", "B", dict(pa="tape_wall")), "outpost": ("exch", "B", {}),
             "settlement": ("exch", "B", {}), "city": ("exch", "B", {}), "capital": ("exch", "B", dict(bed_db=-3.0))},
    "board": {"unclaimed": ("board", "B", dict(behind="low", pa="tape_wall")), "outpost": ("board", "B", dict(behind="low")),
              "settlement": ("board", "B", {}), "city": ("board", "B", {}), "capital": ("board", "B", {})},
    # The Lab (Jon, Nov 26: C "Far plant"): its own bed and sounds are LabScene's; the station behind the shut door is
    # the room's, at the old Door shut mix's ref, on its fixed bus (lab_beds/old_bus.json). Why: #the-lab
    "lab": {"unclaimed": ("lab", "C", dict(behind="low", pa="tape_door")), "outpost": ("lab", "C", dict(behind="low")),
            "settlement": ("lab", "C", {}), "city": ("lab", "C", {}), "capital": ("lab", "C", {})},
}
# Each deck's PA (Jon, Nov 26, from three ideas filmed: the yard's far PA "sounds GREAT", the dry takes through the old
# wall, door and clear speakers "weird"). The Promenade and Exchange: the yard's far PA, wet 0.4 into the deck's own
# hall. The Board and Lab: a small ceiling speaker in the room (not through the wall), the room's own short echo,
# 4 dB over the mixer's through-wall level, then by capture the Board 3 dB more and the Lab 2 dB less. The yard: its
# far speaker as the mixer had it. Unclaimed reads the tape through each. Why: docs/why/StationSound.md#the-pa
PA_KIND = {"prom": "far", "exch": "far", "board": "ceiling", "lab": "ceiling"}
PA_DB = {"board": 7.0, "lab": 2.0}


def pa_room(deck, tier, mixer, wet_base):
    """A room's PA from the mixer's (speaker, db, wet, x): its deck's pick."""
    tape = tier == "unclaimed"
    if deck == "yard":
        return dict(mixer, speaker="tape" if tape else "far", wet=0.4 if tape else mixer["wet"])
    kind = PA_KIND[deck]
    wet = 0.4 if kind == "far" else round(float(wet_base), 3)
    return dict(mixer, speaker="tape" if tape else kind, wet=wet, db=round(mixer["db"] + PA_DB.get(deck, 0.0), 2))


LAB_BEDS = SS / "lab_beds" / "C_plant"
LAB_BUS = SS / "lab_beds" / "old_bus.json"
# The rooms whose mixes the bus numbers come from (the tier variants share their pick's).
MIXES = sorted({(d, c) for deck in PICKS.values() for d, c, _ in deck.values() if d != "lab"})
HALLS = sorted({(d, c) for deck in PICKS.values() for d, c, _ in deck.values()})
# The yard's crispness (Jon, Nov 26: "as crisp as hangar B2"): a level of `HangarSound.CRISP`. Why: #crispness
CRISP = {"yard": "B2"}
# The Board's own sounds, played through the Board's room as the mix had them, tamed (`StationSound.keep`): decks.BOARD_KEEP,
# the popups 10 dB down, and every tier's strike, flicker and screen sounds.
KEEP = {n: 0.0 for n in DK.BOARD_KEEP + ["lab_unclaimed_bulb", "lab_outpost_lamp", "lab_unclaimed_flicker", "lab_outpost_flicker",
                                         "lab_monitor_pop", "lab_city_screen", "lab_capital_glass"]}
KEEP.update({"board_popup_open": -10.0, "board_popup_close": -10.0})
# The PA's speakers as the game builds them (filters as stages of Godot's 2-pole filter, Q per stage; EQ10 bells):
# the mixer's `far` and `tape`, and the Board's and Lab's small ceiling speaker.
SPEAKERS = {
    "far": dict(hp=[260, 260], lp=[3200, 3200, 2400, 2400, 2400, 2400], bell={}),
    "ceiling": dict(hp=[300, 300], lp=[3000, 3000], bell={}),
    "tape": dict(hp=[380, 380], lp=[3000, 3000], bell={}, tape=True),
}


def h01(*a):
    return G["h01"](*a)


def loud1(x):
    return G["loud1"](x)


def to_mono(x):
    return x.mean(1, keepdims=True)


def write(path, x, rate=SR):
    path.parent.mkdir(parents=True, exist_ok=True)
    y = x if rate == SR else signal.resample_poly(x, rate, SR, axis=0)
    peak = np.abs(y).max()
    if peak > 0.89:                                            # stored lower; its `loud` says so
        y = y * (0.89 / peak)
    sf.write(str(path), y.astype(np.float32), rate, subtype="PCM_16")
    back, _ = sf.read(str(path), always_2d=True)
    return back if rate == SR else signal.resample_poly(back, SR, rate, axis=0)


def lp_comp(x):
    """dB the game's depth low-pass takes off this file at darkness 0..1 (21 steps): the mixer normalised after."""
    base = loud1(x)
    return [round(base - loud1(x if i == 0 else G["lowpass"](x, 7000 - 5200 * i / 20)), 2) for i in range(21)]


def measure_file(x, loop):
    return dict(loud=round(loud1(x), 3), len=round(len(x) / SR, 4), onset=round(G["sync_point"](x, "onset"), 3),
                hit=round(G["sync_point"](x, "hit"), 3), loop=bool(loop), ch=int(x.shape[1]), lp=lp_comp(x))


def src(name):
    return S.src(name)


def take(name):
    return S.take(name)


# ------------------------------------------------------------------ the files
FILES = {}       # game name -> (source, kind, its processing)


def add(deck, source, kind, prefix="", **kw):
    """A file for the game, one per (source, kind, processing): named for its deck and its source take."""
    for name, (s0, k0, kw0) in FILES.items():
        if s0 == source and k0 == kind and kw0 == kw:
            return name
    stem = Path(source.replace("game:", "")).stem.lower()
    if stem.startswith(deck + "_"):
        stem = stem[len(deck) + 1:]
    name = f"{deck}_{prefix}{stem}"
    FILES[name] = (source, kind, kw)
    return name


def plan_files():
    """Every file the picked rooms play, named for the game, and each room's plan around them."""
    D = DK.deck_cfgs()
    rooms = {}
    for deck, tiers in PICKS.items():
        for tier, (dk, c, var) in tiers.items():
            rooms[f"{deck}:{tier}"] = room_plan(deck, tier, dk, c, D[dk]["concepts"][c], var)
    return rooms


def room_plan(deck, tier, dk, c, cfg, var):
    p = dict(deck=deck, tier=tier, mix=f"{dk}_{c}", name=cfg["name"], rt=cfg["rt"], size=cfg["size"], warmth=cfg["warmth"],
             wet_base=cfg["wet_base"], beds=[], bed_db=float(cfg.get("bed_db", 0.0)) + float(var.get("bed_db", 0.0)),
             bed_dark=float(var.get("bed_dark", 0.0)), layers=[], map={}, pa={}, crisp=CRISP.get(deck, ""))
    if deck == "lab":                                         # the Lab's bed is LabScene's; the rest sits on the old ref
        p["ref_db"] = round(float(cfg["ref"]), 2)
    for n in ([] if deck == "lab" else cfg.get("bed", [])):
        p["beds"].append(add(deck, n, "bed", dark=float(cfg.get("bed_dark", 0.1)), even=bool(cfg.get("bed_even"))))
    for lay in cfg.get("layers", []):
        names = lay["src"]
        if deck in ("board", "lab") and var.get("behind") == "low":
            names = DK.deck_cfgs()["prom_u"]["concepts"]["C"]["bed"]   # the low tiers' promenade behind the wall
        files = [add(deck, n, "muffled", prefix="behind_", dark=float(lay.get("dark", 0.2)), lp=float(lay["lp"]), rate=11025)
                 for n in names]
        p["layers"].append(dict(id=lay["id"], files=files, db=float(lay["db"]), wet=float(lay.get("wet", 0.0))))
    if deck == "board":
        p["keep"] = {n: dict(file=add(deck, "game:sfx/%s.wav" % n, "shot"), db=db) for n, db in KEEP.items()
                     if (GAME / "sfx" / f"{n}.wav").exists()}
    for cls, r in cfg["map"].items():
        if cls == "pa":
            mixer = dict(speaker=var.get("pa", r["speaker"]), db=float(r.get("db", 0.0)), wet=float(r.get("wet", 0.1)),
                         x=float(r.get("x", 480)))
            p["pa"] = pa_room(deck, tier, mixer, cfg["wet_base"]) | dict(mixer=mixer)
            continue
        if cls.startswith("game:") or cls == "lampgate":
            continue                                           # the game's own sounds (KEEP), or a gate this pick has not
        kind = "loop" if cls in ("fork", "tube", "weld") else "shot"
        files = [add(deck, n, kind) for n in r["src"]]
        p["map"][cls] = {k: v for k, v in r.items() if k != "src"} | dict(files=files)
    return p


def build_file(name, source, kind, kw):
    x = take(source)
    if kind == "bed":
        y = S.tame(x, kw["dark"])
        if kw.get("even"):
            y = S.even(y)
        y = G["fold"](y)
        loop = True
    elif kind == "muffled":                                    # the station behind a closed door (the mixer's layer)
        y = S.lp4(S.tame(x, kw["dark"]), kw["lp"])
        y = G["fold"](y)
        loop = True
    elif kind == "loop":
        y = G["fold"](to_mono(S.tame(x, 0.0)))
        loop = True
    else:
        y = to_mono(S.tame(x, 0.0))
        loop = False
    y = G["norm"](y, -20.0)
    rate = kw.get("rate", SR)
    back = write(OUT / f"{name}.wav", y, rate)
    return measure_file(back, loop) | dict(src=str(source), kind=kind, rate=rate)


IMPORT = """[remap]

importer="wav"
type="AudioStreamWAV"

[params]

force/8_bit=false
force/mono=false
force/max_rate=false
force/max_rate_hz=44100
edit/trim=false
edit/normalize=false
edit/loop_mode={loop}
edit/loop_begin=0
edit/loop_end=-1
compress/mode={mode}
"""


def import_stub(name, loop):
    """Loops import as PCM looped forward on their whole length (ogg and QOA click at a seam); one-shots as QOA."""
    p = OUT / f"{name}.wav.import"
    if not p.exists():
        p.write_text(IMPORT.format(loop=2 if loop else 0, mode=0 if loop else 2), encoding="utf-8", newline=chr(10))


# ------------------------------------------------------------------ the bus, from the approved mixes
def bus_numbers(dk, c):
    """Render the approved mix and keep what its bus did: its level (LAST_GAIN_DB) and the compressor's threshold."""
    D = DK.deck_cfgs()
    dc = D[dk]
    evf = json.loads((S.FILM / f"{dc['film']}_events.json").read_text())
    ev = [e for e in evf["events"] if e["kind"] != "note"]
    for p in dc.get("pa", []):
        ev.append(dict(cls="pa", kind="pa", t=p["t"], n=0))
    got = {}
    real = S.bus

    def spy(x, target, tp=-3.5):
        n = len(x)
        y = np.vstack([x, x, x])
        y = signal.sosfilt(G["HP30"], y, axis=0)
        for s in G["BUS_EQ"]():
            y = signal.sosfilt(s, y, axis=0)
        mid = y[n:2 * n]
        from scipy import ndimage
        rms = np.sqrt(ndimage.uniform_filter1d(np.mean(mid ** 2, 1), int(0.05 * SR)) + 1e-12)
        got["thr_rms_db"] = float(np.median(20 * np.log10(rms)) + 6)
        got["pre_lufs"] = float(G["integrated"](mid))
        out = real(x, target, tp)
        got["gain_db"] = float(G["LAST_GAIN_DB"])
        return out

    S.bus = spy
    try:
        cfg = dict(dc["concepts"][c], key=c)
        cfg.setdefault("target", -37.0)
        mixv = S.render(dk, cfg, ev, evf["D"], DK.LAPS)
    finally:
        S.bus = real
    got["mix"] = G["measure"](mixv)
    got["band_2_8k_db"] = round(band_db(mixv, 2000, 8000), 2)
    return {k: (round(v, 2) if isinstance(v, float) else v) for k, v in got.items()}


def eq21_gains():
    sos = np.vstack([G["HP30"]] + list(G["BUS_EQ"]()))
    w, h = signal.sosfreqz(sos, worN=np.array(EQ21, float), fs=SR)
    return [round(float(20 * np.log10(abs(v) + 1e-12)), 2) for v in h]


def speaker_comp():
    """dB each speaker's filters take off the PA lines (their mean over the table): the mixer normalised after."""
    rows = json.loads((OUT / "pa.json").read_text())["lines"]
    out = {}
    for kind, sp in SPEAKERS.items():
        d = []
        for r in rows:
            x = to_mono(take("game:" + r["file"].replace("res://assets/audio/", "")))
            d.append(loud1(x) - loud1(speaker_sim(x, sp)))
        out[kind] = round(float(np.mean(d)), 2)
    return out


def stage(x, kind, fc, q=0.7071):
    """One Godot 2-pole filter stage (RBJ), causal, as the bus runs it."""
    w = 2 * math.pi * fc / SR
    al = math.sin(w) / (2 * q)
    c = math.cos(w)
    if kind == "lp":
        b = [(1 - c) / 2, 1 - c, (1 - c) / 2]
    else:
        b = [(1 + c) / 2, -(1 + c), (1 + c) / 2]
    a = [1 + al, -2 * c, 1 - al]
    return signal.lfilter(np.array(b) / a[0], np.array(a) / a[0], x, axis=0)


def speaker_sim(x, sp):
    y = x
    for f in sp["hp"]:
        y = stage(y, "hp", f)
    for f in sp["lp"]:
        y = stage(y, "lp", f)
    for f, g in sp["bell"].items():
        y = signal.sosfilt(G["peak_sos"](f, g, 1.0), y, axis=0)
    return y


# ------------------------------------------------------------------ the halls: Godot's reverb, emulated
COMB = [0.025306122448979593, 0.026938775510204082, 0.028956916099773241, 0.03074829931972789,
        0.032244897959183672, 0.03380952380952381, 0.035306122448979592, 0.036666666666666667]
ALLP = [0.0051020408163265302, 0.007732426303854875, 0.01, 0.012607709750566893]


def godot_reverb(x, room, damp, spread_base=0.0):
    """Godot's `Reverb` (servers/audio/effects/reverb_filter.cpp) on one channel: 8 damped combs into 4 allpasses,
    wet only (x wet_scale 0.6). Its predelay has no effect at feedback 0, as in the engine. Block-vectorised."""
    fb = min(0.98, 0.7 + room * 0.28)
    aux = (damp / 2 + 0.5) ** 2
    d = math.exp(-2 * math.pi * aux * 10000 / SR)
    n = len(x)
    out = np.zeros(n)
    ex = int(round(spread_base * SR))
    for ct in COMB:
        D = int(round(ct * SR)) + ex
        B = np.zeros(n + D)
        zi = np.zeros(1)
        for s in range(0, n, D):
            e = min(n, s + D)
            prev = B[s:e] * fb                                # B[n-D], held D samples back in the padded buffer
            o, zi = signal.lfilter([1 - d], [1, -d], prev, zi=zi)
            B[s + D:e + D] = x[s:e] + o
            out[s:e] += o
    y = out
    for at in ALLP:
        D = int(round(at * SR)) + ex
        B = np.zeros(n + D)
        z = np.zeros(n)
        for s in range(0, n, D):
            e = min(n, s + D)
            aux_ = B[s:e]
            B[s + D:e + D] = 0.7 * aux_ + y[s:e]
            z[s:e] = aux_ - 0.7 * B[s + D:e + D]
        y = z
    return y * 0.6


def godot_shelf(x, gain, fc=5000.0):
    """AudioEffectHighShelfFilter at its default 6 dB (one stage), approximated as an RBJ shelf of gain `gain`."""
    return signal.sosfilt(G["shelf_sos"](fc, 20 * math.log10(gain), True), x)


def band_db(x, lo, hi):
    m = x.mean(1) if x.ndim > 1 else x
    f, P = signal.welch(m, SR, nperseg=8192)
    return float(10 * math.log10(P[(f >= lo) & (f < hi)].sum() / (P[(f >= 20) & (f < 16000)].sum() + 1e-20) + 1e-20))


def band_decay(ir, bands=((200, 400), (700, 1400), (2000, 4000), (5000, 9000))):
    """Each band's RT60 (Schroeder, -5 to -25 dB, x3) and energy."""
    out = []
    for lo, hi in bands:
        y = signal.sosfiltfilt(signal.butter(2, [lo, hi], "bp", fs=SR, output="sos"), ir)
        e = np.cumsum(y[::-1] ** 2)[::-1]
        db = 10 * np.log10(e / (e[0] + 1e-30) + 1e-30)
        i5, i25 = int(np.argmax(db < -5)), int(np.argmax(db < -25))
        out.append((3 * (i25 - i5) / SR if i25 > i5 else 0.0, float(e[0])))
    return out


def mixer_hall(rt, size, warmth, seed):
    ir = G["hall_ir"](rt, size, warmth, seed=seed, n_max=12 * SR)
    ir = G["sos_apply"](G["shelf_sos"](5000, -6.0, True), ir) * 0.9
    return ir[:, 0]


def comb_rt(room, damp, f):
    """Godot's mean comb RT60 (s) at frequency f: each comb's loop gain is its feedback times its damping low-pass."""
    fb = min(0.98, 0.7 + room * 0.28)
    d = math.exp(-2 * math.pi * (damp / 2 + 0.5) ** 2 * 10000 / SR)
    w = 2 * math.pi * f / SR
    g = fb * (1 - d) / abs(1 - d * complex(math.cos(w), -math.sin(w)))
    return float(np.mean([3 * ct / -math.log10(g) for ct in COMB]))


# The mixer's hall: its bands' decays as multiples of rt (hall_ir), at each band's middle.
HALL_BANDS = ((125, lambda w: 1.25), (700, lambda w: 1.0), (2500, lambda w: 0.62 - 0.2 * w), (6000, lambda w: 0.38 - 0.2 * w))


def fit_hall(rt, size, warmth, shelf=0.25):
    """The Godot room size and damping whose comb decays best match the mixer's hall band by band, then the level
    (dB on the hall bus) that matches its energy, from one emulated impulse."""
    best = None
    for room in np.arange(0.0, 1.0001, 0.005):
        for damp in np.arange(0.0, 1.0001, 0.05):
            err = sum(math.log(comb_rt(room, damp, f) / (k(warmth) * rt)) ** 2 for f, k in HALL_BANDS)
            if best is None or err < best[0]:
                best = (err, float(room), float(damp))
    err, room, damp = best
    L = int((rt * 1.3 + 0.8) * SR)
    imp = np.zeros(L)
    imp[0] = 1.0
    g = godot_shelf(godot_reverb(imp, room, damp), shelf)
    mh = mixer_hall(rt, size, warmth, 7)
    e_w = float(np.sum(mh ** 2))
    e_g = float(np.sum(g ** 2))
    return dict(room=round(room, 3), damp=round(damp, 2), shelf=shelf, db=round(10 * math.log10(e_w / e_g), 2),
                predelay=round(1000 * (0.012 + 0.05 * size), 1),
                rt_want=[round(k(warmth) * rt, 2) for f, k in HALL_BANDS],
                rt_godot=[round(comb_rt(room, damp, f), 2) for f, k in HALL_BANDS],
                rt_sim_mixer=[round(a[0], 2) for a in band_decay(mh[:L])],
                rt_sim_godot=[round(a[0], 2) for a in band_decay(g)], err=round(err, 3))


def halls():
    """Check the emulation on the hangar's measured hall, then fit each room's."""
    c = take("game:hangar/crate_1.wav").mean(1)
    pad = np.concatenate([c, np.zeros(10 * SR)])
    g = godot_shelf(godot_reverb(pad, 0.955, 0.5), 0.5) * 10 ** (-10.5 / 20)
    w = signal.fftconvolve(pad, mixer_hall(5.5, 1.0, 0.6, 7))[:len(pad)]
    print(json.dumps(dict(check="the hangar's hall on crate_1 (Godot measured it 0.04 dB over the mixer's)",
                          emulated_godot=round(10 * math.log10(np.sum(g ** 2) / np.sum(c ** 2)), 2),
                          mixer=round(10 * math.log10(np.sum(w ** 2) / np.sum(c ** 2)), 2))), flush=True)
    D = DK.deck_cfgs()
    out = {}
    for dk, c in HALLS:
        cfg = D[dk]["concepts"][c]
        out[f"{dk}_{c}"] = fit_hall(cfg["rt"], cfg["size"], cfg["warmth"])
        print(f"{dk}_{c}", json.dumps(out[f"{dk}_{c}"]), flush=True)
    return out


# ------------------------------------------------------------------ build
def build():
    OUT.mkdir(parents=True, exist_ok=True)
    pa()
    rooms = plan_files()
    files = {}
    for name, (source, kind, kw) in FILES.items():
        files[name] = build_file(name, source, kind, kw)
        import_stub(name, files[name]["loop"])
        print(name, kind, files[name]["loud"], files[name]["len"], flush=True)
    clunk = _clunk()
    files["pa_tape_clunk"] = measure_file(write(OUT / "pa_tape_clunk.wav", clunk), False) | dict(src="synth", kind="shot", rate=SR)
    import_stub("pa_tape_clunk", False)
    hl = halls()
    bus = {}
    for dk, c in MIXES:
        bus[f"{dk}_{c}"] = bus_numbers(dk, c)
        print(f"{dk}_{c}", bus[f"{dk}_{c}"], flush=True)
    lab_bus = json.loads(LAB_BUS.read_text())
    for key, p in rooms.items():
        p["hall"] = hl[p["mix"]]
        if p["deck"] == "lab":                                # the game's own lab levels: no bus gain over them
            p["bus"] = dict(gain_db=0.0, thr_rms_db=round(float(lab_bus["thr"]), 2), page_gain_db=round(float(lab_bus["gain"]), 2))
        else:
            p["bus"] = {k: v for k, v in bus[p["mix"]].items() if k in ("gain_db", "thr_rms_db")}
    for tier in TIERS:                                         # Jon's lab beds, as made (22 s seamless, levels set)
        src = LAB_BEDS / f"lab_{tier}.wav"
        x, sr = sf.read(str(src), always_2d=True)
        sf.write(str(OUT / f"lab_{tier}.wav"), x.astype(np.float32), sr, subtype="PCM_16")
        import_stub(f"lab_{tier}", True)
        files[f"lab_{tier}"] = measure_file(x, True) | dict(src=f"station-sound/lab_beds/C_plant/lab_{tier}.wav", kind="labbed",
                                                         rate=sr)
    data = dict(_note="Made by tools/dev/station_sound.py from tk-scratch/station-sound; docs/why/StationSound.md",
                files=files, rooms=rooms, eq21=eq21_gains(), eq21_hz=EQ21, speakers=SPEAKERS,
                speaker_db=speaker_comp(), mixes=bus)
    (OUT / "station.json").write_text(json.dumps(data, indent=1), encoding="utf-8", newline=chr(10))
    for p in OUT.glob("*.wav"):
        if p.stem not in files:
            print("stale (not in the plan):", p.name)


def _clunk():
    """The tape's cut: a short mechanical clunk (the mixer's 95 Hz decay), alone."""
    k = int(0.06 * SR)
    t = np.arange(k) / SR
    y = np.exp(-t / 0.012) * np.sin(2 * np.pi * 95 * t)
    return np.repeat(y[:, None], 1, 1)


def pa():
    """Each PA line's own loudest second and length, into the table; the chime's length and the level it had against
    the old take it was cut from (`ref_loud`: it plays where it sat on that line); the bang's level, length, first
    sound and low-pass loss; then each speaker's loss over the new lines into station.json."""
    p = OUT / "pa.json"
    d = json.loads(p.read_text())
    for r in d["lines"]:
        x = take("game:" + r["file"].replace("res://assets/audio/", ""))
        r["loud"] = round(loud1(x), 2)
        r["secs"] = round(len(x) / SR, 3)
    if "chime" in d:
        c = d["chime"]
        x = take("game:" + c["file"].replace("res://assets/audio/", ""))
        c["secs"] = round(len(x) / SR, 3)
        c["ref_loud"] = round(loud1(take("game:" + c["src"].split("'")[0])), 2)
    if "bang" in d:
        b = d["bang"]
        x = take("game:" + b["file"].replace("res://assets/audio/", ""))
        b.update(loud=round(loud1(x), 2), secs=round(len(x) / SR, 3), onset=round(G["sync_point"](x, "onset"), 3),
                 lp=lp_comp(x))
    p.write_text(json.dumps(d, indent=1), encoding="utf-8", newline=chr(10))
    print("pa:", len(d["lines"]), "lines measured")
    st = OUT / "station.json"
    if st.exists():
        s = json.loads(st.read_text())
        s["speaker_db"] = speaker_comp()
        for room in s["rooms"].values():
            mixer = room["pa"]["mixer"]
            room["pa"] = pa_room(room["deck"], room["tier"], mixer, room["wet_base"]) | dict(mixer=mixer)
        s["speakers"] = json.loads(json.dumps(SPEAKERS))
        st.write_text(json.dumps(s, indent=1), encoding="utf-8", newline=chr(10))
        print("speaker_db:", s["speaker_db"])


def measure(paths):
    import pyloudnorm as pyln
    for p in paths:
        x, sr = sf.read(p, always_2d=True)
        if sr != SR:
            x = signal.resample_poly(x, SR, sr, axis=0)
        x = x[:, :2] if x.shape[1] >= 2 else np.repeat(x, 2, 1)
        print(json.dumps(dict(file=Path(p).name, seconds=round(len(x) / SR, 2),
                              lufs=round(pyln.Meter(SR).integrated_loudness(x), 2), lra=round(G["lra"](x), 1),
                              tp=round(G["true_peak"](x), 1), band_2_8k=round(band_db(x, 2000, 8000), 2),
                              band_4_8k=round(band_db(x, 4000, 8000), 2))), flush=True)


if __name__ == "__main__":
    cmd = ARGS[0] if ARGS else "build"
    if cmd == "build":
        build()
    elif cmd == "halls":
        halls()
    elif cmd == "measure":
        measure(ARGS[1:])
    elif cmd == "pa":
        pa()
