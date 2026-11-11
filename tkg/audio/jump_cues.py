"""The jump films' sound: each film's approved mix, split into the cues the game fires.

    uv run --with numpy --with soundfile --with pyloudnorm python jump_cues.py [--from DIR]

Each film in scripts/ui/jump/Seq*.gd names an `id` and a `cut_t`, the moment its mix falls
silent before the hit. The mix (audio/samples/jump/<ID>_mix.wav, gitignored like the other
sources; `--from tk-scratch/jump-drive/round3` copies them in from the films' folders) is
cut there into two cues, written to assets/audio/sfx/:

    jump_<id>_build.wav   the film from its first frame to the cut
    jump_<id>_hit.wav     the cut to the end: the silence, the hit, the tail

The game fires the build on the film's first frame and the hit on the frame the clock
crosses `cut_t` (`JumpDirector`), so a hitch in the build cannot drift the hit off its
picture: the hit cue is re-synced to the picture at the cut.

It refuses to write when:
  - the mix is louder than CUT_DB in the CUT_MS after the cut (the films cut dead there, so
    the hit cue must start in silence), unless the film says `hard`;
  - the hit's onset in the cue (the first 5 ms whose level comes within ONSET_DB of the
    cue's loudest 5 ms) lands more than a frame (1/60 s) off the film's `hit_t` (not for a
    film in RAMP, whose hit climbs);
  - the mix's loudest second is off LUFS_WANT by more than LUFS_TOL (hyperjump.wav's level,
    which every film was levelled to).

It also writes scripts/sim/jump_cues.json (cue names, their starts and lengths, the hit's
onset) for `JumpSeqTest` to read the tape against.
"""
from __future__ import annotations

import json
import os
import re
import shutil
import sys

import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
TKG = os.path.dirname(HERE)
SEQ_DIR = os.path.join(TKG, "scripts", "ui", "jump")
SFX = os.path.join(TKG, "assets", "audio", "sfx")
SAMPLES = os.path.join(HERE, "samples", "jump")
JSON_OUT = os.path.join(TKG, "scripts", "sim", "jump_cues.json")
TEMPLATE_IMPORT = os.path.join(SFX, "hyperjump.wav.import")

CUT_DB = -50.0
CUT_MS = 12
ONSET_DB = 10.0
FRAME_S = 1.0 / 60.0
LUFS_WANT = -15.8
LUFS_TOL = 0.3
SR = 44100
## Films whose cut is not in a silence (none yet).
HARD = set()
## Films whose hit is a climb, not one onset: R10's run lands seven ring punches, each louder,
## into the jump's boom, so the first window within ONSET_DB of the loudest is a punch mid-run.
## Their onset is recorded but not held to `hit_t`.
RAMP = {"r10"}


def seqs() -> dict:
    """{id: {cut_t, hit_t, file}} from the Seq*.gd files, their consts folded."""
    out = {}
    for name in sorted(os.listdir(SEQ_DIR)):
        if not (name.startswith("Seq") and name.endswith(".gd")):
            continue
        text = open(os.path.join(SEQ_DIR, name), encoding="utf-8").read()
        m = re.search(r'\n\tid = &"(\w+)"', text)
        if not m:
            continue
        consts = {}
        for cm in re.finditer(r"^const (\w+) := (.+)$", text, re.M):
            try:
                consts[cm.group(1)] = eval(cm.group(2), {"__builtins__": {}}, consts)
            except Exception:
                pass
        vals = {}
        for key in ("cut_t", "hit_t"):
            vm = re.search(r"\n\t%s = (.+)" % key, text)
            vals[key] = float(eval(vm.group(1), {"__builtins__": {}}, consts))
        out[m.group(1)] = dict(vals, file=name)
    return out


def level_db(x: np.ndarray) -> float:
    return 20.0 * np.log10(np.sqrt(np.mean(x ** 2)) + 1e-12)


def onset_s(x: np.ndarray) -> float:
    """First 5 ms window whose level comes within ONSET_DB of the loudest 5 ms window."""
    win = int(0.005 * SR)
    n = len(x) // win
    lv = np.array([level_db(x[i * win:(i + 1) * win]) for i in range(n)])
    top = lv.max()
    first = int(np.argmax(lv >= top - ONSET_DB))
    return first * win / SR


def loudest_second(x: np.ndarray) -> float:
    import pyloudnorm as pyln
    m = pyln.Meter(SR, block_size=1.0)
    best = -120.0
    for s in range(0, len(x) - SR + 1, int(0.05 * SR)):
        v = m.integrated_loudness(x[s:s + SR])
        if np.isfinite(v):
            best = max(best, v)
    return best


def write_import(wav: str) -> None:
    """A QOA import beside the wav, as the other effects have; Godot fills the uid and paths."""
    dst = wav + ".import"
    if os.path.exists(dst):
        return
    lines = []
    for line in open(TEMPLATE_IMPORT, encoding="utf-8"):
        if line.startswith(("uid=", "path=", "dest_files=")):
            continue
        if line.startswith("source_file="):
            line = 'source_file="res://assets/audio/sfx/%s"\n' % os.path.basename(wav)
        lines.append(line)
    open(dst, "w", encoding="utf-8", newline="\n").writelines(lines)


def main() -> int:
    args = sys.argv[1:]
    if "--from" in args:
        src_root = args[args.index("--from") + 1]
        os.makedirs(SAMPLES, exist_ok=True)
        for sid in seqs():
            up = sid.upper()
            src = os.path.join(src_root, "_" + sid, "sound", "%s_mix.wav" % up)
            if os.path.exists(src):
                shutil.copyfile(src, os.path.join(SAMPLES, "%s_mix.wav" % up))
                print("copied", src)
    table = {}
    bad = 0
    for sid, s in seqs().items():
        path = os.path.join(SAMPLES, "%s_mix.wav" % sid.upper())
        if not os.path.exists(path):
            print("%s: no mix at %s (audio/samples/ is gitignored; see this file's docstring)" % (sid, path))
            bad += 1
            continue
        x, sr = sf.read(path, always_2d=True)
        if sr != SR:
            print("%s: %d Hz, want %d" % (sid, sr, SR))
            bad += 1
            continue
        cut, hit_t = s["cut_t"], s["hit_t"]
        ci = int(round(cut * SR))
        w = int(CUT_MS / 1000.0 * SR)
        at_cut = level_db(x[ci:ci + w])
        before = level_db(x[max(ci - w, 0):ci])
        if at_cut > CUT_DB and sid not in HARD:
            print("%s: %.1f dBFS after the cut (%.3f s; %.1f before it), louder than %.0f" % (sid, at_cut, cut, before, CUT_DB))
            bad += 1
            continue
        hit = x[ci:]
        on = cut + onset_s(hit.mean(axis=1))
        if abs(on - hit_t) > FRAME_S and sid not in RAMP:
            print("%s: the hit's onset is at %.4f s, %.1f ms off hit_t %.4f" % (sid, on, (on - hit_t) * 1000.0, hit_t))
            bad += 1
            continue
        lufs = loudest_second(x)
        if abs(lufs - LUFS_WANT) > LUFS_TOL:
            print("%s: loudest second %.2f LUFS, want %.1f +-%.1f" % (sid, lufs, LUFS_WANT, LUFS_TOL))
            bad += 1
            continue
        build_wav = os.path.join(SFX, "jump_%s_build.wav" % sid)
        hit_wav = os.path.join(SFX, "jump_%s_hit.wav" % sid)
        sf.write(build_wav, x[:ci], SR, subtype="PCM_16")
        sf.write(hit_wav, hit, SR, subtype="PCM_16")
        write_import(build_wav)
        write_import(hit_wav)
        table[sid] = {
            "build": {"cue": "jump_%s_build" % sid, "at": 0.0, "len": round(ci / SR, 4)},
            "hit": {"cue": "jump_%s_hit" % sid, "at": round(cut, 4), "len": round(len(hit) / SR, 4), "onset": round(on, 4)},
            "cut_t": round(cut, 4), "hit_t": round(hit_t, 4), "lufs": round(lufs, 2),
            "cut_dbfs": round(at_cut, 1), "file": s["file"],
        }
        print("%s: build %.3f s, hit %.3f s from %.3f (onset %.4f, hit_t %.4f, %.1f dBFS before the cut and %.1f after, %.2f LUFS)"
              % (sid, ci / SR, len(hit) / SR, cut, on, hit_t, before, at_cut, lufs))
    if bad:
        print("%d film(s) refused; nothing written for them" % bad)
    with open(JSON_OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(table, f, indent=1, sort_keys=True)
        f.write("\n")
    print("wrote", JSON_OUT)
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
