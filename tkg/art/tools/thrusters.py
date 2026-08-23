"""The thruster library: animated exhaust plumes, drawn rather than generated.

    python art/tools/thrusters.py            # write the whole library
    python art/tools/thrusters.py --list     # just print the spec

WHY DRAWN. A plume is a tapering wedge, a heat ramp and some turbulence — the
existing `hull_medium_exhaust.png` is eleven colours. Generating that costs a
credit per roll and gives back something that is approximately the right length,
approximately on-palette, and does not loop. Drawing it means the length is the
number you asked for, the ramp is the contract's own ramp, frame 8 tiles into
frame 0 exactly, and a change of mind is a change of constant.

THE GEOMETRY. Nose points right, so engines face LEFT and the plume trails
further left. Each sprite is one nozzle: the rigging bench places thrusters
individually, so a pair baked into one file — which is what the old asset did,
because the old hull had two — is the wrong unit now.

Frame 0's nozzle end sits flush with the RIGHT edge of its frame, so a caller
positions a plume by its attach point and never has to know the length.

THE RAMPS are indexed by heat, 0.0 cold to 1.0 core. The first entry of each is
the coolest visible colour; the last is the core. Heat ramp values come from
ART_CONTRACT §3.
"""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixeltools as pt


def _hex(s):
	return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


# cold -> core. The contract's Heat/combustion ramp, extended at the hot end
# with the blue-white the existing plume uses for its core.
RAMPS = {
	"heat":     [_hex(c) for c in ("5c280c", "964214", "cc641c", "ffa63c", "ffdca0", "fff6e2")],
	"plasma":   [_hex(c) for c in ("182636", "283e56", "3a5876", "5c82a4", "8cb6d4", "cfe8f5")],
	"violet":   [_hex(c) for c in ("241338", "3d1f5e", "5c2f8a", "8250bd", "b48ae0", "e6d6ff")],
	"viridian": [_hex(c) for c in ("0d2b1e", "13472f", "1c6b46", "2f9c67", "6fd3a0", "d6f5e4")],
	"whitehot": [_hex(c) for c in ("6b3a12", "b06a1e", "e8a83c", "ffd28a", "fff0cc", "ffffff")],
}

# half-height of the throat, and plume length at rest
SIZES = {
	"s":  (3, 18),
	"m":  (5, 30),
	"l":  (7, 44),
	"xl": (10, 62),
}

FRAMES = 8          # 8 at FLAME_HZ 10 is a 0.8s loop
PAD = 1             # keeps the outermost lit pixel off the frame edge

# 4x4 ordered (Bayer) thresholds, normalised to (0,1). Used to break the ramp
# boundaries instead of blending them — see the note in frame().
BAYER = [[(v + 0.5) / 16.0 for v in row] for row in (
	(0, 8, 2, 10),
	(12, 4, 14, 6),
	(3, 11, 1, 9),
	(15, 7, 13, 5),
)]


def _noise(a, b, c):
	"""Deterministic hash noise in 0..1. Same inputs, same value, every run."""
	n = math.sin(a * 12.9898 + b * 78.233 + c * 37.719) * 43758.5453
	return n - math.floor(n)


def _shroud(t):
	"""Outer envelope: the soft, cooler gas around the jet.

	Bulges just past the throat then tapers. This is the silhouette.
	"""
	return max(0.0, (1.0 - t) ** 0.70 * (1.0 + 0.40 * math.sin(math.pi * min(1.0, t * 1.5))))


def _core(t, shock):
	"""Inner jet: narrow, much hotter, and pinched by shock diamonds.

	SHOCK DIAMONDS are the point. A supersonic exhaust is not a smooth cone --
	it is a chain of bright nodes where the flow over- and under-expands, and
	that chain is what makes a plume read as thrust rather than as a triangle.
	They are strongest at the throat and wash out downstream.
	"""
	if t > 0.72:
		return 0.0
	base = (1.0 - t / 0.72) ** 0.55
	return max(0.0, base * 0.62 * shock)


def _length_scale(behaviour, f, n):
	"""How long this frame's plume is, as a multiple of the resting length."""
	p = 2.0 * math.pi * f / n
	if behaviour == "steady":
		return 1.0 + 0.05 * math.sin(p)
	if behaviour == "pulse":
		return 1.0 + 0.22 * math.sin(p)
	if behaviour == "surge":
		# a long asymmetric shove: quick build, slow decay
		x = f / float(n)
		return 1.12 + 0.30 * math.exp(-((x - 0.15) ** 2) / 0.02) - 0.06 * x
	if behaviour == "flicker":
		# deterministic stutter, and one frame where it nearly gutters out
		seq = [1.0, 0.88, 1.06, 0.72, 1.0, 0.94, 1.10, 0.60]
		return seq[f % len(seq)]
	return 1.0


def _bright(behaviour, f, n):
	if behaviour == "flicker":
		return [1.0, 0.9, 1.0, 0.7, 1.0, 0.95, 1.0, 0.55][f % 8]
	if behaviour == "surge":
		x = f / float(n)
		return 0.9 + 0.25 * math.exp(-((x - 0.15) ** 2) / 0.02)
	return 1.0


def frame(w, h, half, length, ramp, behaviour, f, n):
	"""One frame, nozzle flush right, plume trailing left."""
	rows = [bytearray(w * 4) for _ in range(h)]
	L = max(2.0, length * _length_scale(behaviour, f, n))
	gain = _bright(behaviour, f, n)
	cy = (h - 1) / 2.0
	nozzle = w - 1 - PAD
	phase = 2.0 * math.pi * f / n

	# Shock spacing scales with the throat, the way it does on a real nozzle.
	spacing = max(2.6, half * 1.7)

	for i in range(int(L)):
		t = i / L
		x = nozzle - i
		if x < PAD:
			break

		# --- the shock chain -------------------------------------------------
		# Node brightness and pinch share one term so the jet fattens exactly
		# where it flares. Decays downstream as the flow settles.
		shock = 1.0 + 0.45 * math.exp(-t * 3.2) * math.cos(2.0 * math.pi * i / spacing)

		# --- turbulent silhouette --------------------------------------------
		# Three octaves, the highest of them per-frame noise, so the outline is
		# ragged and never repeats as a smooth curve.
		wob = (0.13 * math.sin(phase * 2.0 + t * 6.0)
		       + 0.09 * math.sin(-phase * 3.0 + t * 14.0)
		       + 0.16 * (_noise(i, f, 1.0) - 0.5))
		hw = half * _shroud(t) * (1.0 + wob)

		# --- the tail comes apart --------------------------------------------
		# Past two-thirds the plume stops being a body and becomes wisps. Without
		# this it ends in a neat point, which is the single most model-looking
		# thing a drawn plume can do.
		if t > 0.62:
			frag = _noise(i * 3, f * 7, 2.0)
			cut = (t - 0.62) / 0.38
			if frag < cut * 0.85:
				continue
			hw *= 1.0 - 0.45 * cut

		# --- bloom at the throat ---------------------------------------------
		if i < 2:
			hw *= 1.25

		if hw < 0.4:
			continue
		chw = half * _core(t, shock)
		span = int(hw)
		for j in range(-span, span + 1):
			y = int(round(cy + j))
			if y < 0 or y >= h:
				continue
			a = abs(j)
			r = a / max(hw, 0.5)
			# Shroud heat, then the core overrides it where the core reaches.
			heat = (1.0 - t) ** 0.9 * (1.0 - 0.75 * r * r) * 0.62
			if a <= chw:
				cr = a / max(chw, 0.5)
				heat = max(heat, (1.0 - t * 0.55) * (1.0 - 0.30 * cr * cr) * shock * 0.98)
			heat *= gain
			if heat <= 0.07:
				continue
			# ORDERED DITHER between ramp bands. The contract asks for it by name
			# and forbids anti-aliasing, so the gradient has to be broken up with
			# a threshold pattern rather than blended. Without it a plume reads as
			# flat shells rather than a continuous flame.
			e = min(1.0, heat) * (len(ramp) - 1)
			k = int(e)
			if k < len(ramp) - 1 and (e - k) > BAYER[y & 3][x & 3]:
				k += 1
			c = ramp[min(len(ramp) - 1, k)]
			o = x * 4
			rows[y][o:o + 4] = bytes((c[0], c[1], c[2], 255))
	return rows


def strip(name, size, colour, behaviour):
	half, length = SIZES[size]
	ramp = RAMPS[colour]
	peak = max(_length_scale(behaviour, f, FRAMES) for f in range(FRAMES))
	fw = int(length * peak) + 2 * PAD + 1
	fh = 2 * (half + 1) + 2 * PAD + 1
	out = [bytearray(fw * FRAMES * 4) for _ in range(fh)]
	for f in range(FRAMES):
		fr = frame(fw, fh, half, length, ramp, behaviour, f, FRAMES)
		for y in range(fh):
			out[y][f * fw * 4:(f + 1) * fw * 4] = fr[y]
	return fw, fh, out


# name -> (size, colour, behaviour). Twenty, spanning every axis, each one
# chosen rather than produced by a cross product: a extra-large flicker would
# never be used, an extra-small surge is a contradiction.
LIBRARY = [
	("thruster_s_heat_steady",      "s",  "heat",     "steady"),
	("thruster_s_heat_flicker",     "s",  "heat",     "flicker"),
	("thruster_s_plasma_steady",    "s",  "plasma",   "steady"),
	("thruster_s_violet_steady",    "s",  "violet",   "steady"),
	("thruster_s_viridian_flicker", "s",  "viridian", "flicker"),
	("thruster_m_heat_steady",      "m",  "heat",     "steady"),
	("thruster_m_heat_pulse",       "m",  "heat",     "pulse"),
	("thruster_m_heat_flicker",     "m",  "heat",     "flicker"),
	("thruster_m_plasma_steady",    "m",  "plasma",   "steady"),
	("thruster_m_plasma_pulse",     "m",  "plasma",   "pulse"),
	("thruster_m_violet_steady",    "m",  "violet",   "steady"),
	("thruster_m_viridian_flicker", "m",  "viridian", "flicker"),
	("thruster_l_heat_steady",      "l",  "heat",     "steady"),
	("thruster_l_heat_pulse",       "l",  "heat",     "pulse"),
	("thruster_l_heat_surge",       "l",  "heat",     "surge"),
	("thruster_l_plasma_steady",    "l",  "plasma",   "steady"),
	("thruster_l_violet_pulse",     "l",  "violet",   "pulse"),
	("thruster_xl_heat_surge",      "xl", "heat",     "surge"),
	("thruster_xl_plasma_surge",    "xl", "plasma",   "surge"),
	("thruster_xl_whitehot_surge",  "xl", "whitehot", "surge"),
]


def main(argv):
	here = os.path.dirname(os.path.abspath(__file__))
	dest = os.path.abspath(os.path.join(here, "..", "sprites", "thrusters"))
	if "--list" in argv:
		for n, s, c, b in LIBRARY:
			half, length = SIZES[s]
			print("%-30s %-3s %-9s %-8s  half %2d  len %2d" % (n, s, c, b, half, length))
		return
	if not os.path.isdir(dest):
		os.makedirs(dest)
	print("%-30s %-9s %-7s %s" % ("file", "frame", "strip", "colours"))
	for n, s, c, b in LIBRARY:
		fw, fh, rows = strip(n, s, c, b)
		p = os.path.join(dest, n + ".png")
		pt.encode(p, fw * FRAMES, fh, rows)
		pal = pt.palette(fw * FRAMES, fh, rows)
		print("%-30s %-9s %-7s %d" % (n + ".png", "%dx%d" % (fw, fh),
		                              "%dx%d" % (fw * FRAMES, fh), len(pal)))
	print()
	print("%d thrusters, %d frames each, written to %s" % (len(LIBRARY), FRAMES, dest))


if __name__ == "__main__":
	main(sys.argv[1:])
