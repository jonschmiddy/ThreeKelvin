"""Install the takes Jon picked into the game.

usage: python tools/dev/voice/install.py OUTDIR "energy:2 heat:1 ..." [--repo PATH]
  copies OUTDIR/ogg/<id>__t<take>.ogg to each line's `install` path (from
  OUTDIR/index.json), relative to the repo (default: the current directory).
Then run a Godot --import in that checkout so each .ogg gets its .import file,
and commit the .ogg and .ogg.import together.
"""
import argparse
import json
import shutil
import sys
from pathlib import Path


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    ap.add_argument("picks")
    ap.add_argument("--repo", default=".")
    a = ap.parse_args()
    doc = json.loads((Path(a.out) / "index.json").read_text(encoding="utf-8"))
    by = {e["id"]: e for e in doc["lines"]}
    done = 0
    for p in a.picks.replace("(", " ").split():
        if ":" not in p:
            continue
        i, t = p.split(":", 1)
        if i not in by or not t.isdigit():
            print("skipped", p)
            continue
        src = Path(a.out) / "ogg" / f"{i}__t{t}.ogg"
        if not src.exists():
            sys.exit(f"no take {src}")
        dst = Path(a.repo) / by[i]["install"]
        dst.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy(src, dst)
        done += 1
        print(i, "take", t, "->", dst)
    missing = [i for i in by if f"{i}:" not in a.picks]
    print(done, "installed;", "unpicked: " + ", ".join(missing) if missing else "every line picked")


if __name__ == "__main__":
    main()
