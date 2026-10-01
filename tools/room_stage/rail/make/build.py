"""The elevator's five floor pictures, built from what Jon judged them on.

    uv run --with pillow python tools/room_stage/rail/make/build.py

Each floor is one 144x128 picture that plays on the floor you are on and stands
muted and still on the others. This writes, one level up (`tools/room_stage/rail/`):

  <deck>.png        the floor's frames, each once, 16 to a row
  <deck>_muted.png  its first frame with most of its colour gone, half as bright
  rail.json         per deck: how long a frame lasts, which frame plays when
                    (`seq`), and `top`, the first row a short floor shows

What each floor is, as Jon settled it on the Elevator Pictures page (2026-10-01):

  stock     the city concourse backdrop (`backdrop_city_concourse2b`, the 144
            columns from 210) at sunset, raking beams whose shadows barely
            shiver, its sign a neon tube with the Starter fault. prom_sunset.py.
  services  the outpost welder under a ship, sparks and all, filmed from the
            yard (`stationshot ... yardclip`); the four frames where the hall's
            tired lamp happened to drop out are cut. src/welder_strip.png.
  hold      the Exchange's crate pile, dark, lit by its one lamp, Loose fault,
            dust only in its beam. lamp2.py.
  work      the Hiring Board, dark, lit by its shaded lamp, Starter fault, dust
            in the bright heart of its light, off the notices. lamp3.py over
            lamp2.py.
  bench     the city lab's shelves and monitor, filmed from the lab
            (`stationshot ... labclip`). src/lab_strip.png.

Every lamp fails on `lamp.flicker_at`, a line-for-line port of the game's
`ShopLight.flicker_at`. Needs Pillow only.
"""
import json
import os
import subprocess
import sys

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
SRC = os.path.join(HERE, "src")
W, H = 144, 128
COLS = 16
# The first row a short floor shows, per picture (a 5-deck station's floor is
# 72 rows; a picture is anchored so its subject stays in view).
TOP = {"stock": 34, "services": 44, "hold": 44, "work": 50, "bench": 40}


def strip(path, n=None):
	im = Image.open(path).convert("RGB")
	k = im.width // W
	return [im.crop((i * W, 0, i * W + W, H)) for i in range(k if n is None else n)]


def frames_for(deck):
	sys.path.insert(0, HERE)
	if deck == "stock":
		import prom_sunset
		return prom_sunset.render(os.path.join(SRC, "prom_p13.png"), "rake", None, 240), 33
	if deck == "hold":
		import lamp2
		lamp2.AMBIENT, lamp2.WARM, lamp2.GLOW = 0.40, 0.35, 0.25
		lamp2.SPILL, lamp2.POOL, lamp2.MOTES = (0.30, 30.0), (54, 117, 58, 6), 50
		spread = 30.0
		cone = [(45, 35), (63, 35), (54 + spread * 1.6, 116), (54 - spread * 1.6, 116)]
		return lamp2.frames(os.path.join(SRC, "hold_more.png"), 3, 240, (80, 15), cone,
			(54, 36), 90, (46, 26, 62, 36)), 33
	if deck == "work":
		import lamp2
		import lamp3
		lamp2.HOT_ALL, lamp2.MOTES, lamp2.MOTE_FLOOR = True, 50, 0.6
		lamp2.light_map = lambda w, h, cone, lamp, reach: lamp3.shade_map(w, h, lamp, reach, (45, 117, 42, 9))
		return lamp2.frames(os.path.join(SRC, "work_6.png"), 1, 240, (40, 20), None,
			(47, 62), 62, (35, 51, 60, 69)), 33
	if deck == "services":
		return strip(os.path.join(SRC, "welder_strip.png")), 66
	if deck == "bench":
		return strip(os.path.join(SRC, "lab_strip.png")), 66
	sys.exit("build: no deck %s" % deck)


def mute(im):
	grey = im.convert("L").convert("RGB")
	return Image.blend(im, grey, 0.7).point(lambda v: int(v * 0.5))


def build(deck):
	frames, ms = frames_for(deck)
	uniq, seq, seen = [], [], {}
	for f in frames:
		key = f.tobytes()
		if key not in seen:
			seen[key] = len(uniq)
			uniq.append(f)
		seq.append(seen[key])
	rows = (len(uniq) + COLS - 1) // COLS
	cols = min(COLS, len(uniq))
	atlas = Image.new("RGB", (cols * W, rows * H))
	for i, f in enumerate(uniq):
		atlas.paste(f, ((i % COLS) * W, (i // COLS) * H))
	atlas.save(os.path.join(OUT, deck + ".png"), optimize=True)
	mute(frames[0]).save(os.path.join(OUT, deck + "_muted.png"), optimize=True)
	return {"ms": ms, "frames": len(uniq), "cols": cols, "seq": seq, "top": TOP[deck]}


if __name__ == "__main__":
	if len(sys.argv) > 1:
		# one deck, in its own process: the lamp scripts keep their settings in
		# module globals, and the Exchange's must not leak into the Hiring Board's
		print(json.dumps(build(sys.argv[1])))
		sys.exit(0)
	doc = {}
	for deck in ["stock", "services", "hold", "work", "bench"]:
		out = subprocess.run([sys.executable, os.path.abspath(__file__), deck],
			capture_output=True, text=True, check=True).stdout
		doc[deck] = json.loads(out.strip().splitlines()[-1])
		print("%-8s %3d frames (%d unique), %d ms" % (deck, len(doc[deck]["seq"]), doc[deck]["frames"], doc[deck]["ms"]))
	with open(os.path.join(OUT, "rail.json"), "w", encoding="utf-8") as f:
		json.dump(doc, f, separators=(",", ":"))
		f.write("\n")
