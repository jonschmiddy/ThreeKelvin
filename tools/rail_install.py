"""The elevator's floor pictures, from the stage into the game.

    python tools/rail_install.py            # copy the stage's pictures in
    python tools/rail_install.py --check    # is the game's copy what the stage holds?

THE SOURCE IS THE STAGE. `tools/room_stage/rail/` holds one picture per floor of
the station's elevator (`StationSpine`), named for the deck it shows -- stock,
services, hold, work, bench -- as Jon settled them on the Elevator Pictures page
(2026-10-01). Each floor is a run of 144x128 frames that plays on the floor you
are on (`<deck>.png`, the frames 16 to a row, each once), its first frame muted
for every other floor (`<deck>_muted.png`), and `rail.json`, which says how long
a frame lasts, which frame plays when and where a short floor's window starts.
`make/build.py` writes all of it from the scripts and pictures in `make/`.

The same picture stands at every station and level. A floor with no picture
keeps the shapes `StationSpine` draws in code.

Copied byte for byte into `tkg/art/sprites/station/rail/`, and anything there
the stage no longer holds is removed. No numpy, no Pillow.
"""
import hashlib
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGE = os.path.join(ROOT, "tools", "room_stage", "rail")
OUT = os.path.join(ROOT, "tkg", "art", "sprites", "station", "rail")
DECKS = ["stock", "services", "hold", "work", "bench"]
W, H = 144, 128


def _png_size(path):
	with open(path, "rb") as f:
		head = f.read(24)
	return int.from_bytes(head[16:20], "big"), int.from_bytes(head[20:24], "big")


def _sha(path):
	with open(path, "rb") as f:
		return hashlib.sha256(f.read()).hexdigest()


def _staged():
	"""Every file the stage installs, checked against rail.json."""
	path = os.path.join(STAGE, "rail.json")
	if not os.path.exists(path):
		return []
	with open(path, encoding="utf-8") as f:
		doc = json.load(f)
	out = ["rail.json"]
	for deck, d in doc.items():
		if deck not in DECKS:
			sys.exit("rail_install: rail.json names %s, which is not a deck (%s)" % (deck, ", ".join(DECKS)))
		n, cols = int(d["frames"]), int(d["cols"])
		want = (cols * W, ((n + cols - 1) // cols) * H)
		got = _png_size(os.path.join(STAGE, deck + ".png"))
		if got != want:
			sys.exit("rail_install: %s.png is %dx%d, rail.json says %dx%d" % ((deck,) + got + want))
		if _png_size(os.path.join(STAGE, deck + "_muted.png")) != (W, H):
			sys.exit("rail_install: %s_muted.png is not %dx%d" % (deck, W, H))
		if not d["seq"] or max(d["seq"]) >= n:
			sys.exit("rail_install: %s plays a frame it does not have" % deck)
		out += [deck + ".png", deck + "_muted.png"]
	return out


def install():
	os.makedirs(OUT, exist_ok=True)
	names = _staged()
	for f in names:
		shutil.copyfile(os.path.join(STAGE, f), os.path.join(OUT, f))
	for f in os.listdir(OUT):
		if (f.endswith(".png") or f.endswith(".json")) and f not in names:
			os.remove(os.path.join(OUT, f))
			if os.path.exists(os.path.join(OUT, f + ".import")):
				os.remove(os.path.join(OUT, f + ".import"))
	decks = [n[:-4] for n in names if n.endswith(".png") and not n.endswith("_muted.png")]
	print("installed %d of the elevator's 5 floors (%s) into %s" % (len(decks), ", ".join(decks), os.path.relpath(OUT, ROOT)))
	print("run `godot --headless --path tkg --import` so the new pictures load")


def check():
	bad = 0
	names = _staged()
	for f in names:
		got = os.path.join(OUT, f)
		if not os.path.exists(got) or _sha(got) != _sha(os.path.join(STAGE, f)):
			print("rail_install: %s has moved on since the install -- run tools/rail_install.py" % f)
			bad += 1
	if os.path.isdir(OUT):
		for f in os.listdir(OUT):
			if (f.endswith(".png") or f.endswith(".json")) and f not in names:
				print("rail_install: %s was installed but is no longer on the stage -- run tools/rail_install.py" % f)
				bad += 1
	if bad == 0:
		print("rail_install: the elevator's %d files match the stage" % len(names))
	return 1 if bad else 0


if __name__ == "__main__":
	if "--check" in sys.argv:
		sys.exit(check())
	install()
