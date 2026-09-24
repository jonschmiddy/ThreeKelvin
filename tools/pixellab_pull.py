"""Pull finished characters off PixelLab as files, and write a roll manifest.

    python tools/pixellab_pull.py <ids.txt> <outdir> [animation name]

`ids.txt` is one "<name> <character uuid>" per line. Writes <outdir>/<name>/
per character and <outdir>/manifest.json ready for `walker_roll.py`.

WHY NOT JUST ASK FOR THE FRAME URLS. `get_character` returns every frame of
every animation as its own signed URL, roughly 230 characters each. One
character with a 16-frame walk is 4KB of URL; a cast of seventy is most of a
conversation spent on strings nobody reads. The per-character download endpoint
hands back the same pixels as one zip, needs no key, and costs nothing.

Its one quirk, worth knowing rather than debugging twice: it answers 423 with a
JSON body -- not a zip -- while ANY animation on that character is still
generating. That is a useful interlock, so a 423 here is reported as "still
drawing", not as a failure.
"""

import io
import json
import os
import sys
import urllib.error
import urllib.request
import zipfile

ENDPOINT = "https://api.pixellab.ai/mcp/characters/%s/download"


def pull(name, cid, outdir):
    dest = os.path.join(outdir, name)
    try:
        with urllib.request.urlopen(ENDPOINT % cid, timeout=180) as r:
            blob = r.read()
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:120]
        raise RuntimeError("HTTP %d %s" % (e.code, body))
    if not blob.startswith(b"PK"):
        raise RuntimeError(blob.decode("utf-8", "replace")[:120])
    zipfile.ZipFile(io.BytesIO(blob)).extractall(dest)
    return dest


def frames(dest, anim):
    """-> the east frames of `anim`, in order.

    Sorted by the number IN the filename, not by the filename. frame_10 sorts
    before frame_2 as text, which silently shuffles a walk cycle into nonsense
    that still measures as a cycle.
    """
    d = os.path.join(dest, "Idle", "animations", anim, "east")
    if not os.path.isdir(d):
        have = os.path.join(dest, "Idle", "animations")
        got = sorted(os.listdir(have)) if os.path.isdir(have) else []
        raise RuntimeError("no animation %r (has: %s)" % (anim, ", ".join(got)))
    fs = [f for f in os.listdir(d) if f.endswith(".png")]
    fs.sort(key=lambda f: int("".join(c for c in f if c.isdigit()) or 0))
    return [os.path.join(d, f) for f in fs]


def main(argv):
    ids, outdir = argv[0], argv[1]
    anim = argv[2] if len(argv) > 2 else "walk"
    os.makedirs(outdir, exist_ok=True)

    man, waiting, failed = {}, [], []
    for line in io.open(ids, encoding="utf-8"):
        line = line.split("#")[0].strip()
        if not line:
            continue
        name, cid = line.split()[0], line.split()[1]
        try:
            dest = pull(name, cid, outdir)
            man[name] = frames(dest, anim)
            print("  %-12s %2d frames" % (name, len(man[name])))
        except RuntimeError as e:
            if "still being generated" in str(e) or "423" in str(e):
                waiting.append(name)
                print("  %-12s still drawing" % name)
            else:
                failed.append((name, str(e)))
                print("  %-12s FAILED  %s" % (name, e))

    out = os.path.join(outdir, "manifest.json")
    io.open(out, "w", encoding="utf-8", newline="\n").write(
        json.dumps(man, indent=1, sort_keys=True))
    print("\n%d ready, %d still drawing, %d failed -> %s"
          % (len(man), len(waiting), len(failed), out))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
