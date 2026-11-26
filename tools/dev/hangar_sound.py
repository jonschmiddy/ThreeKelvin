"""The ship-select hangars' sound (Jon, Nov 25: "K A, S A, O A + flicker 1 (filament tick) at +10 dB, buzz at +10 dB"):
the game's files and their measurements, made from the sound3 page's own code so the game plays the sounds the
approved mixes were built from. Docs: docs/why/HangarSound.md.

  uv run --with numpy --with scipy --with soundfile --with psutil --with pyloudnorm python -I tools/dev/hangar_sound.py build
      writes tkg/assets/audio/hangar/*.wav, tkg/assets/audio/sfx/hangar_banner.wav and tkg/assets/audio/hangar/hangar.json
  ... python -I tools/dev/hangar_sound.py measure FILE.wav [FILE.wav ...]
      integrated LUFS, LRA and true peak of each file (a game capture, or a reference mix), the mixer's own meters
  python -I tools/dev/hangar_sound.py plans
      bakes each room's cues off its life into tkg/assets/audio/hangar/cues.json (`-- sheet=HangarCuesBake`);
      needs no sound3 folder or packages. Rerun after changing a room's life or HangarCues (HangarSoundTest says so)
  ... python -I tools/dev/hangar_sound.py hall PROBE.wav
      the Godot hall's decay and level from a probe capture (`-- sheet=HangarSoundFilm probe=1`)

Needs the sound3 folder: TK_SCRATCH/shipselect/sound3 (TK_SCRATCH, else the nearest tk-scratch above the repo that has it).
"""
import json
import math
import os
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
if sys.argv[1:2] == ["plans"]:                                # before the imports below: no sound3, no packages
    import subprocess
    sys.exit(subprocess.call(["bash", "tools/dev/godot.sh", "-t", "300", "--headless", "--path", "tkg", "--",
                              "sheet=HangarCuesBake"], cwd=str(REPO)))
SCRATCH = Path(os.environ.get("TK_SCRATCH") or next((q / "tk-scratch" for q in REPO.parents
                                                   if (q / "tk-scratch" / "shipselect" / "sound3").is_dir()), ""))
S3 = SCRATCH / "shipselect" / "sound3"
sys.path.insert(0, str(S3 / "tools"))
sys.argv = [sys.argv[0], str(S3 / "out")] + sys.argv[1:]      # mix.py reads its OUT from argv[1]
import numpy as np  # noqa: E402
import soundfile as sf  # noqa: E402
from scipy import signal  # noqa: E402
import mix as M  # noqa: E402
import flick as FL  # noqa: E402

ARGS = sys.argv[2:]
SR = M.SR
GS = S3 / "out" / "game_stems"
OUT = REPO / "tkg" / "assets" / "audio" / "hangar"
SFX = REPO / "tkg" / "assets" / "audio" / "sfx"
# Godot's EQ21 band centres
EQ21 = [22, 32, 44, 63, 90, 125, 175, 250, 350, 500, 700, 1000, 1400, 2000, 2800, 4000, 5600, 8000, 11000, 16000, 22000]

# name: (source wav(s) under game_stems, how it is stored)
#   mono: a point source (the mixer narrows these to 30 %), stereo: as it is, narrow=w: mid + w x side (a hero's 60 %)
#   loop: folded into a seamless loop (the mixer's loop_to without the resample), rate: stored sample rate
FILES = {
    "k_bed_1": ("korvan_bedA/A1.wav", dict(loop=True, dark=0.1)),
    "k_bed_2": ("korvan_bedA/A2.wav", dict(loop=True, dark=0.1)),
    "k_crane_1": ("korvan_craneA/A1.wav", dict(narrow=0.6)),
    "k_crane_2": ("korvan_craneA/A2.wav", dict(narrow=0.6)),
    "k_door_1": ("korvan_doorA/A1.wav", dict(narrow=0.6)),
    "k_door_2": ("korvan_doorA/A2.wav", dict(narrow=0.6)),
    "engine_1": ("engine/A1.wav", dict(mono=True)),
    "sag_1": ("sag/A2.wav", dict(mono=True)),
    "crane_travel_1": ("crane_travel/B2.wav", dict(mono=True, loop=True)),
    "fork_1": ("fork/C1.wav", dict(mono=True, loop=True)),
    "weld_1": ("weld/A2.wav", dict(mono=True, loop=True)),
    "weld_2": ("weld/A1.wav", dict(mono=True, loop=True)),
    "grind_1": ("grind/A1.wav", dict(mono=True, loop=True)),
    "grind_2": ("grind/B1.wav", dict(mono=True, loop=True)),
    "crate_1": ("crate/A2.wav", dict(mono=True)),
    "crate_2": ("crate/C2.wav", dict(mono=True)),
    "s_bed_1": ("solari_bedA/A1.wav", dict(loop=True, dark=0.1)),
    "s_bed_2": ("solari_bedA/A2.wav", dict(loop=True, dark=0.1)),
    "s_roar_1": ("solari_roarA/A1.wav", dict(narrow=0.6)),
    "s_roar_2": ("solari_roarA/A2.wav", dict(narrow=0.6)),
    "s_pour_1": ("solari_pourA/A1.wav", dict(mono=True)),
    "s_pour_2": ("solari_pourA/A2.wav", dict(mono=True)),
    "s_embers_1": ("solari_embers/D1.wav", dict(loop=True, dark=0.3)),
    "plate_1": ("plate/B1.wav", dict(mono=True)),
    "plate_2": ("plate/B2.wav", dict(mono=True)),
    "chain_1": ("chain/A1.wav", dict(mono=True, loop=True)),
    "trolley_1": ("trolley/A2.wav", dict(mono=True, loop=True)),
    "o_bed_1": ("old_bedA/A1.wav", dict(loop=True, dark=0.1)),
    "o_bed_2": ("old_bedA/A2.wav", dict(loop=True, dark=0.1)),
    "o_lamp_1": ("old_lampA/A1.wav", dict(narrow=0.6)),
    "o_lamp_2": ("old_lampA/A2.wav", dict(narrow=0.6)),
    "o_hum_1": ("hum/B1.wav", dict(loop=True, dark=0.3, narrow=0.8)),
    "o_buzz_1": ("old_buzz/buzz_dry.wav", dict(mono=True, loop=True, raw_loop=True)),
}
ROOMS = {"korvan": "k", "solari": "s", "old": "o"}


def to_mono(x):
    return x.mean(1, keepdims=True)


def narrow(x, w):
    mid = x.mean(1, keepdims=True)
    return mid + (x - mid) * w


def fold_loop(x):
    """A seamless loop: the tail crossfaded into the head (mix.fold), declick edges no longer at the seam."""
    return M.fold(x)


def write(path, x, rate=SR):
    path.parent.mkdir(parents=True, exist_ok=True)
    y = x if rate == SR else signal.resample_poly(x, rate, SR, axis=0)
    peak = np.abs(y).max()
    if peak > 0.89:                                            # a sharp take at -20 would clip: stored lower, its
        y = y * (0.89 / peak)                                  # `loud` says so and the game plays it up to level
    sf.write(str(path), y.astype(np.float32), rate, subtype="PCM_16")
    back, _ = sf.read(str(path), always_2d=True)
    return back if rate == SR else signal.resample_poly(back, SR, rate, axis=0)


def lp_comp(x):
    """dB to add when the game's low-pass darkens the file by `dark`: the mixer normalised every stem after its
    darkening, the game's file is normalised before it. 21 steps of dark 0..1."""
    base = M.loud1(x)
    out = []
    for i in range(21):
        d = i / 20
        y = x if d == 0 else M.lowpass(x, 7000 - 5200 * d)
        out.append(round(base - M.loud1(y), 2))
    return out


def measure_file(name, x, spec):
    m = x.mean(1)
    return dict(loud=round(M.loud1(x), 3), len=round(len(x) / SR, 4), onset=round(M.sync_point(x, "onset"), 3),
                hit=round(M.sync_point(x, "hit"), 3), loop=bool(spec.get("loop")), ch=int(x.shape[1]),
                lp=lp_comp(x), peak_db=round(20 * math.log10(np.abs(m).max() + 1e-12), 1))


def air_loop(room):
    """The mixer's synthesized room air, 30 s (the length its breath was tuned on for Old; Korvan's and Solari's
    60 s mixes breathe 3 and 10 times, here 2 and 5 a lap), stored at 22.05 kHz: nothing in it is above 1 kHz."""
    x = M.air(room, 30 * SR, int(M.h01(room, "A", "air") * 2 ** 31))
    return M.norm(x, -20.0)


def flick_files():
    snd = FL.idea_sounds(1)
    out = {}
    for kind, vs in snd.items():
        for i, (x, src) in enumerate(vs):
            out[f"o_flick_{kind}_{i + 1}"] = (to_mono(M.norm(x, -20.0)), src)
    return out


def eq21_gains():
    """The mixer's bus EQ (HP 30 Hz and BUS_EQ) as Godot EQ21 band gains: its response at each band's centre."""
    sos = np.vstack([M.HP30] + list(M.BUS_EQ()))
    w, h = signal.sosfreqz(sos, worN=np.array(EQ21, float), fs=SR)
    return [round(float(20 * np.log10(abs(v) + 1e-12)), 2) for v in h]


def bus_numbers(room):
    """Run the approved mix and keep what its bus did: the level it gave the mix (LAST_GAIN_DB), the compressor's
    threshold in the bus's own terms, and the 50 ms crest factor (Godot's compressor reads peaks, the mixer RMS)."""
    got = {}
    real_bus = M.bus

    def spy(x, target, tp=-3.5):
        n = len(x)
        y = np.vstack([x, x, x])
        y = signal.sosfilt(M.HP30, y, axis=0)
        for s in M.BUS_EQ():
            y = signal.sosfilt(s, y, axis=0)
        mid = y[n:2 * n]
        m = np.mean(mid ** 2, 1)
        w = int(0.05 * SR)
        from scipy import ndimage
        rms = np.sqrt(ndimage.uniform_filter1d(m, w) + 1e-12)
        pk = ndimage.maximum_filter1d(np.abs(mid).max(1), w)
        got["thr_rms_db"] = float(np.median(20 * np.log10(rms)) + 6)
        got["crest_db"] = float(np.median(20 * np.log10(pk + 1e-12) - 20 * np.log10(rms)))
        got["pre_lufs"] = float(M.integrated(mid))
        out = real_bus(x, target, tp)
        got["gain_db"] = float(M.LAST_GAIN_DB)
        return out

    M.bus = spy
    try:
        mixv = M.render(room, "A")[0]
    finally:
        M.bus = real_bus
    got["mix"] = M.measure(mixv)
    return got


def build():
    OUT.mkdir(parents=True, exist_ok=True)
    files = {}
    for name, (src, spec) in FILES.items():
        x = M.read(GS / src)
        if spec.get("mono"):
            x = to_mono(x)
        if spec.get("narrow"):
            x = narrow(x, spec["narrow"])
        if spec.get("loop") and not spec.get("raw_loop"):
            x = fold_loop(x)
        x = M.norm(x, -20.0)
        y = write(OUT / f"{name}.wav", x)
        files[name] = measure_file(name, y, spec) | dict(src=f"sound3/out/game_stems/{src}")
        print(name, files[name]["loud"], files[name]["onset"], files[name]["hit"], flush=True)
    for room, k in ROOMS.items():
        y = write(OUT / f"{k}_air_1.wav", air_loop(room), 22050)
        files[f"{k}_air_1"] = measure_file(f"{k}_air_1", y, dict(loop=True)) | dict(src=f"mix.air({room})")
    for name, (x, src) in flick_files().items():
        y = write(OUT / f"{name}.wav", x)
        files[name] = measure_file(name, y, {}) | dict(src=f"flick.idea_sounds(1): {src}")
    b = M.read(S3 / "keep" / "banner_B2.mp3")
    page_loud = M.loud1(b) - 16.1                              # the page played it at -16.1 dB beside the mixes
    y = write(SFX / "hangar_banner.wav", M.norm(b, -20.0))
    files["hangar_banner"] = measure_file("hangar_banner", y, {}) | dict(src="sound3/keep/banner_B2.mp3",
                                                                       page_loud=round(page_loud, 2))
    rooms = {}
    for room in ROOMS:
        rooms[room] = {k: (round(v, 2) if isinstance(v, float) else v) for k, v in bus_numbers(room).items()}
        print(room, rooms[room], flush=True)
    data = dict(_note="Made by tools/dev/hangar_sound.py from tk-scratch/shipselect/sound3; docs/why/HangarSound.md",
                files=files, rooms=rooms, eq21=eq21_gains(), eq21_hz=EQ21)
    (OUT / "hangar.json").write_text(json.dumps(data, indent=1), encoding="utf-8")


def measure(paths):
    for p in paths:
        x, sr = sf.read(p, always_2d=True)
        if sr != SR:
            x = signal.resample_poly(x, SR, sr, axis=0)
        x = x[:, :2] if x.shape[1] >= 2 else np.repeat(x, 2, 1)
        import pyloudnorm as pyln
        lufs = pyln.Meter(SR).integrated_loudness(x)
        st = M.short_term(x)                                   # the mixer's LRA reads its signal as a loop
        st = st[st > -70]
        rel = st[st > 10 * np.log10(np.mean(10 ** (st / 10))) - 20]
        lra = float(np.percentile(rel, 95) - np.percentile(rel, 10))
        print(json.dumps(dict(file=Path(p).name, seconds=round(len(x) / SR, 2), lufs=round(lufs, 1), lra=round(lra, 1),
                              tp=round(M.true_peak(x), 1), hot_2_5k=round(M.band_share(x, 2000, 5000), 4),
                              lows_below_500=round(M.band_share(x, 20, 500), 3))), flush=True)


def _decay(wet, sr):
    """Schroeder decay of a tail: RT60 from its -5 to -25 dB fall (x3), and from -5 to -15 (x6, the early part)."""
    e = np.cumsum(wet[::-1] ** 2)[::-1]
    db = 10 * np.log10(e / e[0] + 1e-20)
    i5, i15, i25 = (int(np.argmax(db < -k)) for k in (5, 15, 25))
    return round(3 * (i25 - i5) / sr, 2), round(6 * (i15 - i5) / sr, 2)


def hall(path):
    """A probe capture (`-- sheet=ShipRoomShot hallprobe=1`): the room hushed, crate_1 dry alone 2 s after the probe
    starts, the same into the hall alone at 8 s. The capture's probe start is found by its first sound. Prints the
    game's wet/dry energy and RT60 beside the mixer's own hall fed the same thud (its tail x 0.9, shelved)."""
    x, sr = sf.read(path, always_2d=True)
    if sr != SR:
        x = signal.resample_poly(x, SR, sr, axis=0)
    m = x[:, :2].mean(1)
    env = np.abs(m) > 1e-4
    on = int(np.argmax(env))                                  # the dry thud's first sample
    dry = m[on:on + int(5.5 * SR)]
    wet = m[on + int(6 * SR):]
    g = dict(wet_over_dry_db=round(10 * math.log10(np.sum(wet ** 2) / np.sum(dry ** 2)), 2), rt60=_decay(wet, SR))
    c = M.read(OUT / "crate_1.wav")
    cfg = M.CONCEPTS["A"]
    ir = M.hall_ir(cfg["rt"], cfg["size"], cfg["warmth"], seed=int(M.h01("old", "A", "ir") * 2 ** 31), n_max=12 * SR)
    pad = np.vstack([c, np.zeros((12 * SR, 2))])
    w = M.sos_apply(M.shelf_sos(5000, -6.0, True), signal.fftconvolve(pad, ir, axes=0)[:len(pad)]) * 0.9
    mm = w.mean(1)
    ref = dict(wet_over_dry_db=round(10 * math.log10(np.sum(mm ** 2) / np.sum(c.mean(1) ** 2)), 2), rt60=_decay(mm, SR))
    print(json.dumps(dict(game=g, mixer=ref)))


if __name__ == "__main__":
    cmd = ARGS[0] if ARGS else "build"
    if cmd == "build":
        build()
    elif cmd == "measure":
        measure(ARGS[1:])
    elif cmd == "hall":
        hall(ARGS[1])
