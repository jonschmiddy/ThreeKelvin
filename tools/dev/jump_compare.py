"""A jump film as the game played it, beside the film Jon approved.

    uv run --with pillow --with numpy --with soundfile --with imageio-ffmpeg python \\
        tools/dev/jump_compare.py <game_dir> <id> <out_dir> [--films <round3_dir>]

<game_dir> is what `-- jumpcine whole film=<id>` wrote: f_%04d.png at 60 fps and log.txt
with the taped cues. It writes to <out_dir>:
    <id>_game.mp4      the frames with the taped cues under them (1x) and
    <id>_game_2x.mp4   the same at 1920x1080, which is how the game is seen
    <id>_compare.png   the approved film's strip frames over the game's at the same times
    <id>_compare_2x.png the ship's end of the frame at 2x, film over game, at those times
The approved films' frames are read from <round3_dir>/_<id>/frames (60 fps).
"""
from __future__ import annotations

import os
import re
import subprocess
import sys
import tempfile

import numpy as np
import soundfile as sf
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))
SFX = os.path.join(REPO, "tkg", "assets", "audio", "sfx")
## The worktrees live in GitHub/tk-wt/<name>, the main checkout in GitHub/ThreeKelvin; tk-scratch is beside both.
GITHUB = os.path.dirname(REPO) if os.path.basename(os.path.dirname(REPO)) != "tk-wt" else os.path.dirname(os.path.dirname(REPO))
ROUND3 = os.path.join(GITHUB, "tk-scratch", "jump-drive", "round3")
SR = 44100
## The approved strips' moments (the films' encode.py TS lists).
STRIP_TS = {
    "r12": [0.5, 1.84, 2.25, 2.9, 3.6, 4.3, 4.95, 5.5, 5.8, 6.0, 6.117, 6.6],
    "r4": [0.5, 1.3, 2.2, 3.0, 4.0, 4.85, 5.017, 5.08, 5.2, 5.8, 6.3, 9.5],
    "r3": [0.3, 1.8, 3.0, 3.4, 3.6, 3.8, 4.4, 4.75, 5.3, 6.6, 7.35, 8.0],
    "r8": [0.3, 1.8, 3.0, 3.75, 4.4, 4.9, 5.4, 5.8, 6.2, 6.6, 8.0, 10.2],
}
## The crop judged at 2x: the ship's end of the frame.
CROP = (0, 120, 640, 440)


def read_log(path: str):
    frames, cues = {}, []
    for line in open(path, encoding="utf-8"):
        m = re.match(r"frame (\d+) ([\d.]+)", line)
        if m:
            frames[int(m.group(1))] = float(m.group(2))
        m = re.match(r"sfx (\S+) ([-\d.]+) from ([-\d.]+)", line)
        if m:
            cues.append((m.group(1), float(m.group(2)), float(m.group(3))))
    return frames, cues


def mux(game_dir: str, cues, out_mp4: str, scale: int) -> None:
    import imageio_ffmpeg
    n = len([f for f in os.listdir(game_dir) if f.startswith("f_")])
    length = n / 60.0 + 0.1
    mix = np.zeros((int(length * SR), 2))
    for name, at, frm in cues:
        p = os.path.join(SFX, name + ".wav")
        if not os.path.exists(p):
            continue
        x, sr = sf.read(p, always_2d=True)
        if x.shape[1] == 1:
            x = np.repeat(x, 2, axis=1)
        x = x[int(frm * sr):]
        s = int(at * SR)
        e = min(s + len(x), len(mix))
        if s >= 0 and e > s:
            mix[s:e] += x[:e - s]
    wav = os.path.join(tempfile.gettempdir(), "jump_compare_%d.wav" % os.getpid())
    sf.write(wav, np.clip(mix, -1, 1), SR, subtype="PCM_16")
    ff = imageio_ffmpeg.get_ffmpeg_exe()
    vf = ["-vf", "scale=%d:%d:flags=neighbor" % (960 * scale, 540 * scale)] if scale > 1 else []
    cmd = [ff, "-y", "-loglevel", "error", "-framerate", "60", "-i", os.path.join(game_dir, "f_%04d.png"),
           "-i", wav] + vf + ["-c:v", "libx264", "-preset", "medium", "-crf", "14", "-pix_fmt", "yuv420p",
           "-tune", "animation", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-shortest",
           "-threads", "2", out_mp4]
    subprocess.run(cmd, check=True)
    os.remove(wav)


def tile(img: Image.Image, label: str) -> Image.Image:
    out = img.copy()
    d = ImageDraw.Draw(out)
    d.rectangle((0, 0, 9 + 7 * len(label), 14), fill=(0, 0, 0))
    d.text((4, 2), label, fill=(255, 255, 255))
    return out


def compare(game_dir: str, film_dir: str, ts, out_png: str, crop=None, scale: int = 1) -> None:
    cols = 4
    rows = (len(ts) + cols - 1) // cols
    w, h = (960, 540) if crop is None else (crop[2] - crop[0], crop[3] - crop[1])
    gap = 6
    sheet = Image.new("RGB", (cols * (w * scale + gap), rows * (2 * h * scale + 3 * gap)), (40, 40, 40))
    for i, t in enumerate(ts):
        fi = int(round(t * 60))
        film = Image.open(os.path.join(film_dir, "f%04d.png" % fi)).convert("RGB")
        gp = os.path.join(game_dir, "f_%04d.png" % fi)
        game = Image.open(gp).convert("RGB") if os.path.exists(gp) else Image.new("RGB", (960, 540), (80, 0, 0))
        if crop is not None:
            film, game = film.crop(crop), game.crop(crop)
        if scale > 1:
            film = film.resize((w * scale, h * scale), Image.NEAREST)
            game = game.resize((w * scale, h * scale), Image.NEAREST)
        x = (i % cols) * (w * scale + gap)
        y = (i // cols) * (2 * h * scale + 3 * gap)
        sheet.paste(tile(film, "%.3fs film" % t), (x, y))
        sheet.paste(tile(game, "%.3fs game" % t), (x, y + h * scale + gap))
    sheet.save(out_png)


def main() -> int:
    game_dir, fid, out_dir = sys.argv[1], sys.argv[2], sys.argv[3]
    round3 = sys.argv[sys.argv.index("--films") + 1] if "--films" in sys.argv else ROUND3
    os.makedirs(out_dir, exist_ok=True)
    if "--strips" in sys.argv:
        # <game_dir> is `jumpcine films`' folder: <id>/f_<frame>.png at the strip's moments only
        for sid in STRIP_TS:
            sub = os.path.join(game_dir, sid)
            if os.path.isdir(sub):
                compare(sub, os.path.join(round3, "_" + sid, "frames"), STRIP_TS[sid], os.path.join(out_dir, "%s_strips.png" % sid))
                print(" ", os.path.join(out_dir, "%s_strips.png" % sid))
        return 0
    frames, cues = read_log(os.path.join(game_dir, "log.txt"))
    print("%d frames, cues: %s" % (len(frames), ", ".join("%s@%.3f" % (c[0], c[1]) for c in cues)))
    film_dir = os.path.join(round3, "_" + fid, "frames")
    ts = STRIP_TS[fid]
    compare(game_dir, film_dir, ts, os.path.join(out_dir, "%s_compare.png" % fid))
    compare(game_dir, film_dir, ts, os.path.join(out_dir, "%s_compare_2x.png" % fid), CROP, 2)
    mux(game_dir, cues, os.path.join(out_dir, "%s_game.mp4" % fid), 1)
    mux(game_dir, cues, os.path.join(out_dir, "%s_game_2x.mp4" % fid), 2)
    for f in sorted(os.listdir(out_dir)):
        if f.startswith(fid + "_"):
            print(" ", os.path.join(out_dir, f), os.path.getsize(os.path.join(out_dir, f)) // 1024, "KB")
    return 0


if __name__ == "__main__":
    sys.exit(main())
