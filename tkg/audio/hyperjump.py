"""The hyperdrive, as a sound: a start-up and a warp, on the picture's clock.

    py -3.14 hyperjump.py

WHAT IT IS, in Jon's words: "a low rumbling that then has a spooling whirr that
then finishes in a warp as the ship becomes that dot that zips off the screen".
A start-up and a warp, joined at the end rather than in the middle of the build --
splicing mid-build is what made an earlier version "kinda a awkward transition":

    audio/samples/hyperjump_turbine.mp3   (5.0 s, influence 0.70, second roll)
        "Low rumbling starship engine slowly building, turning into a rising
         turbine spool-up whirr that gets higher and faster, finishing with a
         fast warp zap as the ship vanishes into the distance, no music, no
         background noise"
        -- the start-up, whole: "i love turbine 2 as the start up".

    audio/samples/hyperjump_doppler.mp3   (1.5 s, influence 0.60, first roll)
        "A spaceship vanishing into warp, a dense thump and a fast doppler
         whoosh pulling away, no music, no background noise"

    audio/samples/hyperjump_basswarp.mp3  (1.5 s, influence 0.60, first roll)
        "Starship jumping to lightspeed, a heavy bass warp with a sharp
         stretched whoosh, cinematic, no music, no background noise"
        -- these two together are the warp.

All generated through Jon's own ElevenLabs key, so the rights question the
arrival roar still has does not apply. `audio/samples/` is gitignored, as
flameout.py explains: the source is a build input, the clip in assets/ ships.

How it got here is the argument for leaving it alone: a synthesised version
("sucks"), processed takes ("hella sucks", "muddy", "flat and bad", "it sounds
stretched out"), two takes at random, two takes spliced. Rolling more takes and
changing only timing and level is what found it. If it stops being right, roll
again; do not reach for an EQ.

TIMING, all read out of JumpFx.gd:
    turbine    its last moment within TOP_DB of its loudest, HEARD (A-weighted),
               lands on CHARGE_S, the frame the hull goes to light. Plain RMS
               would find its bass instead of its build. Its quiet head is
               trimmed to fit, and this refuses to render if CHARGE_S is more
               than MAX_TRIM_S from where the take actually tops out.
    warp       starts WARP_LEAD_S before the dot leaves -- SNAP_S + ZIP_S after
               the snap -- Jon's "as the dot leaves". turbine fades out under it.
    the warp   two short generations played as one: doppler, with basswarp
               BASS_REL_DB under it, starting together -- "doppler forward.
               this is fucking perfect". It replaced a warp cut from a longer
               take, which Jon heard at -3, -5, -7 and -9 semitones and did not
               like at any ("i just don't like the warp sound"). Its onset, not
               its peak, is what is placed.

AND BACKWARDS, ON ARRIVAL. Jon: "let's have the warp sound in reverse when the
transition to the new sector happens. right before the thruster sound cuts on
and the ship enters the new sector". So the same warp, at the same level
it plays in the jump, is written reversed to hyperjump_in.wav, cut to exactly
SectorScreen.WARP_IN_S -- read from there -- so the swell builds to the warp's
own onset and that lands on the frame the arrival drive starts.

LEVEL. The warp's loudest second sits WARP_REL_DB over turbine's, A-weighted, so
it is the climax rather than a tail; the whole clip's loudest second sits
LOUD_REL over the medium arrival's -- the clip Jon compares everything to. The
peak ceiling is a check that prints, never a gain stage, by flameout.py's rule.
"""
from __future__ import annotations

import io
import os
import re
import subprocess
import sys

import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from synth import SR                                            # noqa: E402
import flameout                                                 # noqa: E402

JUMPFX = os.path.join(HERE, "..", "scripts", "ui", "JumpFx.gd")
SECTOR = os.path.join(HERE, "..", "scripts", "ui", "SectorScreen.gd")
OUT_IN = os.path.join(HERE, "..", "assets", "audio", "sfx", "hyperjump_in.wav")
SFX = os.path.join(HERE, "..", "assets", "audio", "sfx")
SAMPLES = os.path.join(HERE, "samples")
ARRIVAL = os.path.join(SFX, "thruster_arrive_medium_a.wav")
OUT = os.path.join(SFX, "hyperjump.wav")
## The round robin an earlier version used. Left beside hyperjump.wav, Audio.play
## would still pick it half the time.
RETIRED = ("hyperjump_2.wav", "hyperjump_2.wav.import")

TURBINE = "hyperjump_turbine.mp3"
BASSWARP = "hyperjump_basswarp.mp3"
DOPPLER = "hyperjump_doppler.mp3"
NEED = ("CHARGE_S", "SNAP_S", "ZIP_S", "SPARK_S")

## The whole clip's loudest second over the medium arrival's, A-weighted.
LOUD_REL = 3.0
## The warp's loudest second over turbine's.
WARP_REL_DB = 2.0
## basswarp under doppler in the warp, after both are set to equal loudness.
BASS_REL_DB = -6.0
## Lower the warp by playing it slower, if that is ever wanted again. Jon's pair
## plays as generated.
WARP_SEMITONES = 0
## The warp starts this long before the dot leaves.
WARP_LEAD_S = 0.05
## turbine's fade-out runs this far past the warp's start, and this much more.
WARP_OVERLAP_S = 0.20
TURBINE_OUT_EXTRA_S = 0.30
## Where "stops being loud" is drawn: within this much of the take's loudest.
TOP_DB = 3.0
## How far CHARGE_S may sit from where turbine tops out, trimmed or padded.
MAX_TRIM_S = 0.15
FADE_IN_S = 0.04
TAIL_FADE_S = 0.30


def clock() -> dict:
    """The choreography's seconds, read out of JumpFx.gd. Refuses to guess."""
    src = io.open(JUMPFX, encoding="utf-8").read()
    got = {m.group(1): float(m.group(2)) for m in re.finditer(
        r"^const (\w+) := (-?\d+(?:\.\d+)?)\s*$", src, re.M)}
    miss = [k for k in NEED if k not in got]
    if miss:
        raise SystemExit("JumpFx.gd no longer declares %s as plain numbers -- "
                         "the sound is built on those, so fix them there "
                         "rather than hard-coding them here" % miss)
    return got


def warp_in_seconds() -> float:
    """SectorScreen.WARP_IN_S: how long the reversed warp runs before the arrival drive."""
    m = re.search(r"^const WARP_IN_S := (\d+(?:\.\d+)?)\s*$", io.open(SECTOR, encoding="utf-8").read(), re.M)
    if m is None:
        raise SystemExit("SectorScreen.gd no longer declares WARP_IN_S as a plain number -- "
                         "the reversed warp is cut to it, so fix it there")
    return float(m.group(1))


def reversed_warp(w, seconds) -> np.ndarray:
    """`w` backwards, exactly `seconds` long, ending on what was its onset."""
    r = w[::-1].copy()
    n = int(round(seconds * SR))
    if len(r) >= n:
        r = r[len(r) - n:].copy()
        f = int(FADE_IN_S * SR)
        r[:f] *= ramp(f)[:, None]
    else:
        r = np.vstack([np.zeros((n - len(r), 2)), r])
    e = int(0.005 * SR)
    r[-e:] *= ramp(e)[::-1][:, None]
    return r


def ramp(n):
    return (1.0 - np.cos(np.linspace(0.0, np.pi, max(n, 1)))) / 2.0


def decode(name) -> np.ndarray:
    """A sample decoded to this project's rate, as (N, 2)."""
    path = os.path.join(SAMPLES, name)
    if not os.path.exists(path):
        raise SystemExit(
            "missing %s\n"
            "audio/samples/ is gitignored -- see this file's docstring. Put the\n"
            "take back at that path, or regenerate it from the prompt recorded\n"
            "there, and run this again." % path)
    import imageio_ffmpeg
    wav = os.path.join(HERE, "out", "_%s.wav" % os.path.splitext(name)[0])
    os.makedirs(os.path.dirname(wav), exist_ok=True)
    subprocess.run([imageio_ffmpeg.get_ffmpeg_exe(), "-v", "error", "-y",
                    "-i", path, "-ar", str(SR), "-ac", "2", wav], check=True)
    y, _ = sf.read(wav, always_2d=True)
    return y


def heard(y, win_s) -> np.ndarray:
    """A-weighted RMS envelope over `win_s` windows: loudness as it is heard."""
    m = y.mean(axis=1)
    n = len(m)
    f = np.maximum(np.fft.rfftfreq(n, 1.0 / SR), 1e-6)
    f2 = f ** 2
    ra = (12194.0 ** 2 * f2 ** 2) / ((f2 + 20.6 ** 2) * np.sqrt((f2 + 107.7 ** 2) * (f2 + 737.9 ** 2))
                                    * (f2 + 12194.0 ** 2))
    a = np.fft.irfft(np.fft.rfft(m) * ra, n)
    k = max(1, int(win_s * SR))
    return np.sqrt(np.convolve(a ** 2, np.ones(k) / k, mode="same"))


def tops_out(y) -> int:
    """The last sample whose heard 100 ms level is within TOP_DB of the take's loudest."""
    env = heard(y, 0.1)
    return int(np.nonzero(env > env.max() * 10.0 ** (-TOP_DB / 20.0))[0][-1])


def warp_from(y, lo_s, hi_s):
    """The warp in [lo_s, hi_s]: from its onset (within 6 dB of its heard peak, less 30 ms) on.

    Returns the audio, and its onset and peak in seconds into that audio.
    """
    env = heard(y, 0.02)
    lo, hi = int(lo_s * SR), min(len(y), int(hi_s * SR))
    pk = lo + int(np.argmax(env[lo:hi]))
    on = lo + int(np.argmax(env[lo:pk + 1] > env[pk] * 10.0 ** (-6.0 / 20.0)))
    start = max(0, on - int(0.03 * SR))
    w = y[start:hi].copy()
    n = int(0.01 * SR)
    w[:n] *= ramp(n)[:, None]
    return w, (on - start) / SR, (pk - start) / SR


def pair() -> np.ndarray:
    """doppler and basswarp as one warp: equal loudness, onsets together, basswarp BASS_REL_DB under."""
    b_raw, d_raw = decode(BASSWARP), decode(DOPPLER)
    bass, b_on, _ = warp_from(b_raw, 0.0, len(b_raw) / SR)
    dop, d_on, _ = warp_from(d_raw, 0.0, len(d_raw) / SR)
    dop = dop * 10.0 ** ((loudest_second(bass) - loudest_second(dop)) / 20.0)
    ds = int(round((b_on - d_on) * SR))
    n = max(len(bass), len(dop) + max(ds, 0)) + max(-ds, 0)
    out = np.zeros((n, 2))
    b0, d0 = max(-ds, 0), max(ds, 0)
    out[b0:b0 + len(bass)] += bass * 10.0 ** (BASS_REL_DB / 20.0)
    out[d0:d0 + len(dop)] += dop
    return out


def slower(y, semitones):
    """Read `y` slower by a playback rate, `semitones` lower. Returns the audio and the rate."""
    r = 2.0 ** (semitones / 12.0)
    n = int(len(y) / r)
    idx = np.arange(n) * r
    return np.stack([np.interp(idx, np.arange(len(y)), y[:, ch]) for ch in range(2)], axis=1), r


def loudest_second(y) -> float:
    """A-weighted level of the loudest one-second window, 100 ms hop, in dB."""
    w, hop = SR, SR // 10
    y = np.vstack([y, np.zeros((max(0, w - len(y)), 2))])
    best = -200.0
    for i in range(0, max(1, len(y) - w + 1), hop):
        best = max(best, 20.0 * np.log10(max(flameout.a_weighted(y[i:i + w].T), 1e-12)))
    return best


def gain_to(y, db):
    return y * 10.0 ** ((db - loudest_second(y)) / 20.0)


def render(c, arr, semitones=WARP_SEMITONES):
    """The jump clip, and its warp at the level it has in that clip. Returns (clip, warp, notes)."""
    snap = int(c["CHARGE_S"] * SR)

    # THE START-UP, topping out on CHARGE_S.
    turb = decode(TURBINE)
    top = tops_out(turb)
    off = top / SR - c["CHARGE_S"]
    if abs(off) > MAX_TRIM_S:
        raise SystemExit("turbine tops out %.2f s in, but JumpFx.CHARGE_S is %.2f: set CHARGE_S to %.2f"
                         % (top / SR, c["CHARGE_S"], top / SR))
    shift = snap - top
    if shift >= 0:
        lead = np.vstack([np.zeros((shift, 2)), turb])
    else:
        lead = turb[-shift:].copy()
        n = int(FADE_IN_S * SR)
        lead[:n] *= ramp(n)[:, None]
    leave = c["SNAP_S"] + c["ZIP_S"] - WARP_LEAD_S
    out_n = int((leave + WARP_OVERLAP_S + TURBINE_OUT_EXTRA_S) * SR)
    lead = lead[:snap + out_n].copy()
    lead[snap:] *= ramp(out_n)[::-1][:, None]

    # THE WARP, starting as the dot leaves.
    pr = pair()
    warp, on, pk = warp_from(pr, 0.0, len(pr) / SR)
    if semitones:
        warp, r = slower(warp, semitones)
        on, pk = on / r, pk / r
    warp = warp * 10.0 ** ((loudest_second(lead) + WARP_REL_DB - loudest_second(warp)) / 20.0)
    start = snap + int(leave * SR) - int(on * SR)

    # THE START-UP'S LEVEL IS SET BY THE START-UP ALONE. It used to be set from the
    # whole clip's loudest second, so a different warp moved turbine's level --
    # and turbine is "perfect". The warp is meant to be its loudest part, WARP_REL_DB
    # over turbine, so the clip lands LOUD_REL over the arrival with that warp.
    g = 10.0 ** ((loudest_second(arr) + LOUD_REL - WARP_REL_DB - loudest_second(lead)) / 20.0)
    ceil = 10.0 ** (flameout.LEVEL_PEAK_DB / 20.0)

    def mix(k):
        m = np.zeros((max(len(lead), start + len(warp)), 2))
        m[:len(lead)] += lead
        m[start:start + len(warp)] += warp * k
        m = m[:start + len(warp) + int(0.05 * SR)].copy()
        fo = int(TAIL_FADE_S * SR)
        m[-fo:] *= ramp(fo)[::-1][:, None]
        return m * g

    # AND IF A WARP WOULD PASS THE CEILING, THE WARP COMES DOWN, never the whole
    # jump. A deep warp matched by A-weighted loudness needs peaks a bright one
    # does not; the first render of ten new warps turned turbine down 5.6 dB for one.
    notes = []
    k = 1.0
    if float(np.abs(mix(1.0)).max()) > ceil:
        lo, hi = 0.0, 1.0
        for _ in range(16):
            mid = (lo + hi) / 2.0
            if float(np.abs(mix(mid)).max()) <= ceil:
                lo = mid
            else:
                hi = mid
        k = lo
        notes.append("warp turned down %.1f dB so the jump stays under the ceiling" % (-20.0 * np.log10(max(k, 1e-9))))
    warp = warp * k
    y = mix(k)
    peak = float(np.abs(y).max())
    if peak > ceil:
        notes.append("CEILING: peaks %.1f dB over %.1f dBFS -- lower LOUD_REL or WARP_REL_DB, do not let a limiter"
                     % (20.0 * np.log10(peak / ceil), flameout.LEVEL_PEAK_DB))
        y *= ceil / peak
    notes.append("turbine tops out %.2f s in (%s %.2f s to fit)"
                 % (top / SR, "padded" if shift >= 0 else "trimmed", abs(shift) / SR))
    notes.append("warp %+d semitones, starts %.2f s after the snap, peaks %.2f s after that"
                 % (semitones, leave, pk - on))
    return y, warp * g, notes


def main() -> int:
    c = clock()
    arr, sr = sf.read(ARRIVAL, always_2d=True)
    assert sr == SR, "the arrival clip is %d Hz" % sr
    y, warp, notes = render(c, arr)
    sf.write(OUT, y, SR, subtype="PCM_16")
    print("CHARGE_S %.2f, SNAP_S %.2f, ZIP_S %.2f from JumpFx.gd" % (c["CHARGE_S"], c["SNAP_S"], c["ZIP_S"]))
    for line in notes:
        print("  " + line)
    print("  hyperjump.wav  %.2f s long, peak %.1f dBFS, loudest second %+.1f dB over the arrival"
          % (len(y) / SR, 20.0 * np.log10(float(np.abs(y).max())), loudest_second(y) - loudest_second(arr)))
    # The same warp, at the level it has in the jump, backwards for the arrival.
    ceil = 10.0 ** (flameout.LEVEL_PEAK_DB / 20.0)
    secs = warp_in_seconds()
    if secs < len(warp) / SR - 0.01:
        print("  note: WARP_IN_S %.2f is shorter than the %.2f s warp, so the start of its swell is trimmed"
              % (secs, len(warp) / SR))
    back = reversed_warp(warp, secs)
    bpk = float(np.abs(back).max())
    if bpk > ceil:
        print("  CEILING: hyperjump_in peaks %.1f dB over -- lower WARP_REL_DB, do not let a limiter"
              % (20.0 * np.log10(bpk / ceil)))
        back *= ceil / bpk
    sf.write(OUT_IN, back, SR, subtype="PCM_16")
    print("  hyperjump_in.wav  %.2f s (SectorScreen.WARP_IN_S; the warp is %.2f s), peak %.1f dBFS"
          % (len(back) / SR, len(warp) / SR, 20.0 * np.log10(float(np.abs(back).max()))))

    for name in RETIRED:
        path = os.path.join(SFX, name)
        if os.path.exists(path):
            os.remove(path)
            print("  removed %s" % name)
    return 0


if __name__ == "__main__":
    sys.exit(main())
