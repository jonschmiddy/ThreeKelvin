#!/usr/bin/env python3
"""golden_diff.py A B: compare two GoldenFrames capture folders file by file.

Prints each differing file with its changed pixel count, each file missing from B or extra in B,
and exits 1 on any of them (0 when the folders match, 2 on bad usage). `_varies/` holds the frames
the harness lists as known to vary: they are counted, never compared.

    uv run --with pillow tools/dev/golden_diff.py A B
"""
import sys
from pathlib import Path

from PIL import Image, ImageChops

SKIP = "_varies"


def frames(root: Path) -> dict[str, Path]:
    return {p.relative_to(root).as_posix(): p for p in sorted(root.rglob("*.png"))
            if SKIP not in p.relative_to(root).parts}


def changed(a: Path, b: Path) -> str | None:
    """None when the two images are the same pixels, else a note saying how they differ."""
    with Image.open(a) as ia, Image.open(b) as ib:
        if ia.size != ib.size:
            return "size %dx%d vs %dx%d" % (*ia.size, *ib.size)
        bands = ImageChops.difference(ia.convert("RGBA"), ib.convert("RGBA")).split()
        # a pixel counts once if any channel moved; the alpha channel is judged like the rest
        mask = bands[0]
        for ch in bands[1:]:
            mask = ImageChops.lighter(mask, ch)
        box = mask.getbbox()
        if box is None:
            return None
        return "%d px changed, within %s" % (sum(mask.histogram()[1:]), box)


def main(argv: list[str]) -> int:
    if len(argv) != 3 or not all(Path(a).is_dir() for a in argv[1:]):
        print(__doc__.strip().splitlines()[0], file=sys.stderr)
        return 2
    a_dir, b_dir = Path(argv[1]), Path(argv[2])
    fa, fb = frames(a_dir), frames(b_dir)
    bad = 0
    for name in sorted(fa.keys() | fb.keys()):
        if name not in fb:
            print("MISSING  %s (in A, not in B)" % name)
        elif name not in fa:
            print("EXTRA    %s (in B, not in A)" % name)
        else:
            note = changed(fa[name], fb[name])
            if note is None:
                continue
            print("DIFFERS  %s: %s" % (name, note))
        bad += 1
    skipped = len(list((a_dir / SKIP).rglob("*.png")))
    if skipped:
        print("(%d frames in A's %s/ not compared)" % (skipped, SKIP))
    if not fa or not fb:
        print("NOTHING to compare: %d frames in A, %d in B" % (len(fa), len(fb)))
        return 1
    print("%d frames compared, %d differ or are missing or extra" % (len(fa.keys() | fb.keys()), bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
