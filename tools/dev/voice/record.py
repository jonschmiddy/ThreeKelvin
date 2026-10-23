"""Record A.S.H. lines with ElevenLabs, several takes each, and finish them.

COSTS MONEY. Never run `go` without Jon's OK on the number of takes and a hard
stop in credits. `plan` costs nothing and prints the estimate to ask with.

MANIFEST (JSON): {"lines": {"<id>": {"shown": "...", "spoken": "...", "ogg": "tkg/assets/audio/voice/ash/tut_<id>.ogg"}}}
  shown   the words on screen (for the pick page)
  spoken  what she says. NO ALL-CAPS WORDS: eleven_v3 spells them out letter by
          letter (FAULTS came out F-A-U-L-T-S, Oct 22). Write "Faults", keep the
          caps in `shown`. No numbers or key names either: a field like {cap}
          is said as words ("past the limit").
  ogg     where the picked take is installed in the repo (voice/install.py)

usage: uv run --with requests --with numpy --with soundfile --with scipy --with imageio-ffmpeg --with pyloudnorm \\
         python tools/dev/voice/record.py MANIFEST OUTDIR plan|go|fx [--takes 3] [--stop CREDITS]

  plan  characters, takes, estimated credits (0.4 a character on eleven_v3). No calls.
  go    generate missing takes, checking usage before and after each line, and stop
        before any call that could cross --stop. Then fx.
  fx    finish every raw take (treat.py) and write OUTDIR/index.json for voice/make_page.py.

The key comes from ELEVENLABS_API_KEY in the environment (on a Mac, export it in
~/.zshrc), or on Windows from the user environment through PowerShell. It is
kept in memory only: never print it, log it or write it to a file.
"""
import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path

import requests

sys.path.insert(0, str(Path(__file__).parent))
import ash_robotic as R  # noqa: E402
import treat as T  # noqa: E402

API = "https://api.elevenlabs.io/v1"
VOICE = "fKcFYcwdBlcXbbbVbmT9"  # "W1_2", the warm voice Jon picked
MODEL = "eleven_v3"
RATE = 0.4  # credits a character on eleven_v3 (1054 for 2636 chars, Oct 17)

_K = None


def _key():
    k = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not k and sys.platform.startswith("win"):
        k = subprocess.run(["powershell", "-NoProfile", "-Command",
                            "[Environment]::GetEnvironmentVariable('ELEVENLABS_API_KEY','User')"],
                           capture_output=True, text=True).stdout.strip()
    if not k:
        sys.exit("no ELEVENLABS_API_KEY in the environment")
    return k


def headers():
    global _K
    if _K is None:
        _K = _key()
    return {"xi-api-key": _K}


def used():
    r = requests.get(f"{API}/user/subscription", headers=headers(), timeout=30)
    r.raise_for_status()
    return int(r.json()["character_count"])


def settled(tries=12, wait=15):
    """The usage count, read until it stops moving (billing lags a call)."""
    reads = []
    for _ in range(tries):
        reads.append(used())
        if len(reads) >= 3 and reads[-1] == reads[-2] == reads[-3]:
            break
        time.sleep(wait)
    return reads[-1], reads


def load_manifest(path):
    lines = json.loads(Path(path).read_text(encoding="utf-8"))["lines"]
    for i, e in lines.items():
        caps = [w for w in e["spoken"].split() if len(w.strip(".,!?'\"")) > 1 and w.strip(".,!?'\"").isupper()]
        if caps:
            sys.exit(f"{i}: spoken text has all-caps words {caps}; eleven_v3 spells them out. Write them in normal case.")
    return lines


def plan(lines, takes):
    n = sum(len(e["spoken"]) for e in lines.values())
    print(f"{len(lines)} lines, {n} characters, x{takes} takes = {n * takes} characters,"
          f" about {round(n * takes * RATE)} credits")


def go(lines, out, takes, stop):
    raw = out / "raw"
    raw.mkdir(parents=True, exist_ok=True)
    spend_f = out / "spend.json"
    sp = json.loads(spend_f.read_text()) if spend_f.exists() else {"calls": {}, "usage_reads": []}
    u0, reads = settled()
    sp.setdefault("start_used", u0)
    sp["usage_reads"].append({"when": "before", "used": u0, "reads": reads})
    spend_f.write_text(json.dumps(sp, indent=1))
    for i, e in lines.items():
        text = e["spoken"]
        for take in range(1, takes + 1):
            f = raw / f"{i}__t{take}.mp3"
            if f.exists():
                continue
            spent = max(sum(sp["calls"].values()), used() - sp["start_used"])
            if spent + len(text) * RATE * 1.5 > stop:
                print(f"STOP: spent {spent}; the next call could cross {stop}")
                spend_f.write_text(json.dumps(sp, indent=1))
                return
            r = requests.post(f"{API}/text-to-speech/{VOICE}", headers={**headers(), "Content-Type": "application/json"},
                              params={"output_format": "mp3_44100_128"}, timeout=180,
                              json={"text": text, "model_id": MODEL})
            if r.status_code != 200:
                print("ERROR", i, take, r.status_code, r.text[:300])
                spend_f.write_text(json.dumps(sp, indent=1))
                return
            f.write_bytes(r.content)
            cost = r.headers.get("character-cost") or r.headers.get("x-character-count")
            sp["calls"][f.name] = int(cost) if cost else round(len(text) * RATE)
            print(f.name, len(text), "chars, billed", cost)
            spend_f.write_text(json.dumps(sp, indent=1))
        u, reads = settled()
        sp["usage_reads"].append({"when": f"after {i}", "used": u, "reads": reads})
        sp["end_used"] = u
        spend_f.write_text(json.dumps(sp, indent=1))
    print("used", sp.get("end_used", 0) - sp["start_used"], "credits; billed", sum(sp["calls"].values()))


def fx(lines, out, takes):
    for d in ("mp3", "ogg"):
        (out / d).mkdir(parents=True, exist_ok=True)
    spend_f = out / "spend.json"
    sp = json.loads(spend_f.read_text()) if spend_f.exists() else {"calls": {}}
    rows = []
    for i, e in lines.items():
        row = {"id": i, "shown": e["shown"], "spoken": e["spoken"], "install": e["ogg"], "takes": []}
        for take in range(1, takes + 1):
            raw = out / "raw" / f"{i}__t{take}.mp3"
            if not raw.exists():
                continue
            ogg = out / "ogg" / f"{i}__t{take}.ogg"
            x, y = T.treat(raw, ogg)
            mp3 = out / "mp3" / f"{i}__t{take}.mp3"
            R.encode(y, mp3)
            row["takes"].append({"take": take, "mp3": f"mp3/{mp3.name}", "ogg": f"ogg/{ogg.name}",
                                 "duration_s": round(len(y) / R.SR, 3), "lufs": round(T.lufs(y), 1),
                                 "credits": sp["calls"].get(raw.name), "flag": T.auto_flag(R.decode(raw))})
        rows.append(row)
        print(i, [(t["duration_s"], t["flag"]) for t in row["takes"]])
    (out / "index.json").write_text(json.dumps({"voice_id": VOICE, "model_id": MODEL,
                                                "target_lufs": T.TARGET_LUFS, "lines": rows},
                                               indent=1, ensure_ascii=False), encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("manifest")
    ap.add_argument("out")
    ap.add_argument("cmd", choices=["plan", "go", "fx"])
    ap.add_argument("--takes", type=int, default=3)
    ap.add_argument("--stop", type=int, default=0, help="hard stop in credits (required for go)")
    a = ap.parse_args()
    lines = load_manifest(a.manifest)
    out = Path(a.out)
    if a.cmd == "plan":
        plan(lines, a.takes)
    elif a.cmd == "go":
        if a.stop <= 0:
            sys.exit("go needs --stop CREDITS, the hard stop Jon approved")
        go(lines, out, a.takes, a.stop)
        fx(lines, out, a.takes)
    else:
        fx(lines, out, a.takes)


if __name__ == "__main__":
    main()
