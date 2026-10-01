"""board_jingles.py -- the Hiring Board's commercials' jingles, scored to the picture (Jon: "can we have the jingles
last the entire commercial? and match what the person is seeing").

Each commercial is six seconds (BoardCommercial.LENGTH) and its events happen at
the times its code puts them; each cue sheet below hits those times exactly:
the ship sliding in, every stroke of the cloth, each letter of SLURP!, each reel
stopping. Three arrangements of every sheet -- arcade chip, bright pop, lounge
organ -- were auditioned on "Hiring Board, Heard" (2026-10-01), and Jon took the
arcade chip for all six. Move an event in BoardCommercial and move its hit here.

    python3 board_jingles.py          # the six chosen -> ../assets/audio/sfx/board_ad_*.wav
    python3 board_jingles.py --all    # all three arrangements -> out/board_jingles/

Levelled to -39.4 dB, loudest A-weighted second: a screen across the hall, under
the lab's tubes (-35) and the game's click (-27).
"""
import math
import os
import sys

import numpy as np
import soundfile as sf

from scipy.ndimage import minimum_filter1d, uniform_filter1d

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import synth as S                                               # noqa: E402
import flameout                                                 # noqa: E402

SR = S.SR
LEN = 6.0
GAME = os.path.join(HERE, "..", "assets", "audio", "sfx")
ALL = os.path.join(HERE, "out", "board_jingles")
TARGET = -39.4
CEIL = 0.891


def loud_second(y):
    """A-weighted level of the loudest one-second window, 100 ms hop."""
    w, hop = SR, SR // 10
    best = -200.0
    for i in range(0, max(1, len(y) - w + 1), hop):
        best = max(best, 20.0 * np.log10(max(flameout.a_weighted(y[i:i + w].T), 1e-12)))
    return best


def limit(y):
    """Look-ahead peak limiter: 5 ms ahead, 80 ms release."""
    need = np.minimum(1.0, CEIL / np.maximum(np.abs(y).max(axis=1), 1e-12))
    la = int(0.005 * SR)
    g = minimum_filter1d(need, 2 * la + 1, mode="nearest")
    rel = np.exp(-1.0 / (0.08 * SR))
    out = np.empty_like(g)
    cur = 1.0
    for i, v in enumerate(g):
        cur = v if v < cur else v + (cur - v) * rel
        out[i] = cur
    g = np.minimum(uniform_filter1d(out, la, mode="nearest"), need)
    return np.clip(y * g[:, None], -CEIL, CEIL)

CHORDS = {
	"C": ["C4", "E4", "G4"], "F": ["F3", "A3", "C4"], "G": ["G3", "B3", "D4"], "Am": ["A3", "C4", "E4"],
	"Bb": ["Bb3", "D4", "F4"], "Dm": ["D4", "F4", "A4"], "Em": ["E4", "G4", "B4"], "E": ["E4", "G#4", "B4"],
	"Em7": ["E4", "G4", "B4", "D5"], "A": ["A3", "C#4", "E4"], "B": ["B3", "D#4", "F#4"],
}


def midi(n):
	return 12.0 * math.log2(S.hz(n) / 440.0) + 69.0


def note_of(m):
	return 440.0 * 2 ** ((m - 69.0) / 12.0)


# ---------------------------------------------------------------- instruments

def chip(f, dur, duty=0.25, bend=0.0, amp=1.0):
	N = max(1, int(dur * SR))
	t = np.arange(N) / SR
	ff = f * 2 ** (bend * t / max(dur, 1e-3) / 12.0)
	ph = np.cumsum(ff) / SR
	y = np.where((ph % 1.0) < duty, 1.0, -1.0)
	return amp * S.lp(y, 3400) * S.env_adsr(N, 0.003, 0.04, 0.6, min(0.05, dur * 0.4)) * 0.3


def tri(f, dur, amp=1.0):
	N = max(1, int(dur * SR))
	t = np.arange(N) / SR
	y = 2 * np.abs(2 * ((f * t) % 1.0) - 1) - 1
	return amp * y * S.env_adsr(N, 0.003, 0.05, 0.8, min(0.04, dur * 0.3)) * 0.5


def noise_tick(dur=0.04, amp=1.0, hp=5000):
	N = int(dur * SR)
	y = S.hp(np.random.randn(N), hp) * S.env_exp(N, 0.0005, dur * 0.25)
	return amp * y * 0.3


def sad_reed(f, dur, amp=1.0, cents=-120.0):
	N = int(dur * SR)
	t = np.arange(N) / SR
	ff = f * 2 ** ((cents / 1200.0) * (t / dur) ** 1.5) * (1 + 0.015 * np.sin(2 * np.pi * 5.0 * t))
	ph = 2 * np.pi * np.cumsum(ff) / SR
	y = np.sin(ph) + 0.6 * np.sin(2 * ph) + 0.35 * np.sin(3 * ph) + 0.2 * np.sin(4 * ph)
	return amp * S.lp(y, 1600) * S.env_adsr(N, 0.04, 0.1, 0.85, 0.12) * 0.35


def whoosh(dur, rise=True, amp=1.0):
	N = int(dur * SR)
	y = np.random.randn(N)
	t = np.linspace(0, 1, N)
	out = np.zeros(N)
	steps = 24
	for k in range(steps):
		a = int(k * N / steps)
		b = int((k + 1) * N / steps)
		u = t[a]
		fc = 400 + (6000 if rise else -0) * (u if rise else 1 - u) + (0 if rise else 400)
		fc = 500 + 5500 * (u if rise else 1 - u)
		seg = S.bp(y, fc * 0.7, fc * 1.3)[a:b]
		out[a:b] = seg
	env = np.sin(np.pi * t) ** 1.5
	return amp * out * env * 0.5


# ---------------------------------------------------------------- the mixer

class Mix:
	def __init__(self):
		self.buf = np.zeros((2, int((LEN + 3) * SR)))

	def add(self, x, t, gain=1.0, pan=0.0):
		i = int(t * SR)
		if i >= self.buf.shape[1] or i < 0:
			return
		j = min(self.buf.shape[1], i + len(x))
		L = math.cos((pan + 1) * math.pi / 4)
		R = math.sin((pan + 1) * math.pi / 4)
		self.buf[0, i:j] += x[:j - i] * gain * L
		self.buf[1, i:j] += x[:j - i] * gain * R

	def out(self, wet):
		b = S.reverb(self.buf, wet) if wet > 0 else self.buf
		b = b[:, :int(LEN * SR)]
		f = int(0.25 * SR)
		b[:, -f:] *= np.linspace(1, 0, f) ** 2
		return b.T


# ---------------------------------------------------------------- arrangers
# Each turns the sheet's gestures into notes in its own voice.

class Arr:
	wet = 0.2

	def __init__(self):
		self.m = Mix()

	# a voice for the tune, the stab, the bed and the sparkle; each arranger overrides
	def lead(self, n, d): return S.bell(S.hz(n), d)
	def stab(self, n, d): return S.bell(S.hz(n), d)
	def bass(self, n, d): return S.pluck(S.hz(n), d)
	def comp(self, n, d): return S.pluck(S.hz(n), d) * 0.5
	def spark(self, n, d): return S.glass(S.hz(n), d)
	def tick(self): return noise_tick()
	def sadv(self, n, d): return sad_reed(S.hz(n), d)

	def tune(self, t, notes, step, dur=None, gain=1.0):
		for k, n in enumerate(notes):
			if n:
				self.m.add(self.lead(n, dur or step * 1.6), t + k * step, gain, 0.0)

	def hit(self, t, chord, d=0.8, gain=1.0):
		for k, n in enumerate(CHORDS[chord]):
			self.m.add(self.stab(n, d), t, gain * 0.7, -0.4 + 0.4 * k)

	def bed(self, t0, t1, chords, bpm, gain=1.0):
		spb = 60.0 / bpm
		t = t0
		k = 0
		while t < t1 - 0.05:
			ch = CHORDS[chords[(k // 4) % len(chords)]]
			root = note_of(midi(ch[0]) - 12)
			if k % 2 == 0:
				self.m.add(self.bass_hz(root, spb * 0.9), t, gain * 0.8, 0.0)
			self.m.add(self.comp(ch[(k % 3)], spb * 0.8), t + spb * 0.5, gain * 0.5, 0.3 if k % 2 else -0.3)
			if k % 2 == 1:
				self.m.add(self.tick(), t, gain * 0.5, 0.5)
			t += spb
			k += 1

	def bass_hz(self, f, d): return S.pluck(f, d)

	def run(self, t0, t1, lo, hi, n=8, gain=0.8):
		a, b = midi(lo), midi(hi)
		scale = [0, 2, 4, 7, 9]
		notes = []
		m = int(min(a, b))
		while m <= max(a, b):
			if (m % 12) in [(int(midi("C4")) + s) % 12 for s in scale]:
				notes.append(m)
			m += 1
		if a > b:
			notes = notes[::-1]
		if not notes:
			return
		for k in range(n):
			mm = notes[min(len(notes) - 1, int(k * len(notes) / n))]
			t = t0 + (t1 - t0) * k / n
			self.m.add(self.spark_hz(note_of(mm), 0.25), t, gain, -0.5 + k / n)

	def spark_hz(self, f, d): return S.glass(f, d)

	def sparkle(self, t, n="C6", gain=0.6):
		self.m.add(self.spark(n, 0.5), t, gain, 0.4 if int(t * 7) % 2 else -0.4)

	def sad(self, t, notes, step, last=1.2):
		for k, n in enumerate(notes):
			d = last if k == len(notes) - 1 else step * 0.9
			self.m.add(self.sadv(n, d), t + k * step, 1.0, 0.0)

	def tickat(self, t, gain=0.7):
		self.m.add(self.tick(), t, gain, 0.3)

	def whoosh(self, t, d, rise=True, gain=0.7):
		self.m.add(whoosh(d, rise), t, gain, 0.0)


class Chip(Arr):
	wet = 0.08
	def lead(self, n, d): return chip(S.hz(n), d, 0.25)
	def stab(self, n, d): return chip(S.hz(n), d, 0.5) * 0.8
	def comp(self, n, d): return chip(S.hz(n), min(d, 0.12), 0.125) * 0.6
	def bass_hz(self, f, d): return tri(f, d * 0.8)
	def spark(self, n, d): return chip(S.hz(n), 0.08, 0.25, bend=5.0)
	def spark_hz(self, f, d): return chip(f, 0.09, 0.25)
	def tick(self): return noise_tick(0.03, 1.0, 7000)
	def sadv(self, n, d): return chip(S.hz(n), d, 0.5, bend=-1.5)


class Pop(Arr):
	wet = 0.25
	def lead(self, n, d): return S.bell(S.hz(n), d)
	def stab(self, n, d): return S.bell(S.hz(n), d) * 0.9
	def comp(self, n, d): return S.pluck(S.hz(n), d) * 0.6
	def bass_hz(self, f, d): return S.sub(f, d) * 0.8 + S.pluck(f * 2, d) * 0.3
	def spark(self, n, d): return S.glass(S.hz(n), d)
	def spark_hz(self, f, d): return S.glass(f, d)
	def tick(self): return S.hat(0.05)
	def sadv(self, n, d): return sad_reed(S.hz(n), d)


class Lounge(Arr):
	wet = 0.3
	def lead(self, n, d): return S.reed(S.hz(n), d)
	def stab(self, n, d): return S.organ(S.hz(n), d) * 0.8
	def comp(self, n, d): return S.organ(S.hz(n), d * 0.6) * 0.35
	def bass_hz(self, f, d): return S.sub(f, d)
	def spark(self, n, d): return S.bell(S.hz(n), d) * 0.7
	def spark_hz(self, f, d): return S.whistle(f, d) * 0.6
	def tick(self): return S.pluck(S.hz("C6"), 0.06) * 0.4
	def sadv(self, n, d): return sad_reed(S.hz(n), d, cents=-160.0)


# ---------------------------------------------------------------- the cue sheets
# Times are BoardCommercial's: read off its code.

def hull_wax(a):
	# 0.0 out of a jump: a flash; 0.15-1.3 it slides to the middle
	a.hit(0.0, "C", 0.4, 0.7)
	a.whoosh(0.0, 0.5, True, 0.5)
	a.run(0.15, 1.3, "G3", "C5", 6)
	# 1.4-3.8 the cloth: a stroke each way every 0.35 s, a tick on each
	t = 1.4
	while t < 3.8:
		a.tickat(t, 0.6)
		t += math.pi / 9.0
	a.bed(1.3, 4.4, ["C", "F", "G", "C"], 172, 0.8)
	# 1.6-3.6 the hull brightening: a slow climb under it
	a.run(1.6, 3.6, "C4", "C6", 10, 0.45)
	# 3.6 SHINE! -- and the glints, each 0.35 s apart, every 1.2 s
	a.tune(3.6, ["G5", "A5", "C6"], 0.12, 0.5)
	for k in range(4):
		for rep in range(2):
			tt = 3.4 + k * 0.35 + 0.3 + rep * 1.2
			if tt < 5.9:
				a.sparkle(tt, ["C6", "E6", "G6", "C7"][k], 0.5)
	# 4.4 the yellow band: HULL WAX, 2 FOR 1
	a.hit(4.4, "C", 1.4, 1.0)
	a.tune(4.6, ["E5", "D5", "C5"], 0.28, 0.6)


def star_taxi(a):
	# STAR TAXI on screen from the start, stars streaking: a driving bed
	a.bed(0.0, 3.4, ["F", "Bb", "C", "F"], 168, 0.9)
	a.tune(0.1, ["C5", "A4", None, "F5"], 0.18, 0.4)
	# 1.6 ANYWHERE!*
	a.hit(1.6, "F", 0.5, 0.8)
	a.tune(1.65, ["F5", "G5", "A5", "C6"], 0.1, 0.25)
	# the horn, just before it goes: beep beep
	for tt in (2.9, 3.15):
		a.hit(tt, "Bb", 0.18, 0.9)
	# 3.4-4.0 it zooms off
	a.whoosh(3.35, 0.7, True, 0.9)
	a.run(3.4, 4.0, "F4", "F6", 8, 0.8)
	# 4.3 *NEARBY ... CALL 4-TAXI
	a.tune(4.3, ["A4", "G4"], 0.25, 0.4, 0.6)
	a.hit(4.9, "F", 1.0, 0.9)
	a.tune(4.95, ["C5", "F5"], 0.18, 0.5)


def noodles(a):
	a.bed(0.0, 6.0, ["Am", "G", "F", "G"], 120, 0.7)
	# SLURP! a letter every 0.15 s from 0.3, each a note up
	a.tune(0.3, ["A4", "C5", "D5", "E5", "G5", "A5"], 0.15, 0.3)
	# the chopsticks: a strand lifted from each trough to each peak of sin(3t)
	for trough in (1.571, 3.665, 5.76):
		a.run(trough, trough + 0.9, "A4", "A5", 5, 0.4)
	# 3.2 DECK 3; 4.0 OPEN LATE
	a.hit(3.2, "Am", 0.6, 0.8)
	a.tune(3.25, ["E5", "D5"], 0.25, 0.4)
	a.hit(4.0, "C", 1.4, 1.0)
	a.tune(4.05, ["E5", "G5", "A5"], 0.22, 0.6)


def drone(a):
	a.bed(0.0, 6.0, ["C", "Am", "F", "G"], 110, 0.6)
	# LONELY? -- asked, rising at the end
	a.tune(0.1, ["G4", "E4", "A4"], 0.3, 0.45)
	# a blink every 1.7 s: a tiny blip
	for tt in (1.7, 3.4, 5.1):
		a.sparkle(tt, "G6", 0.35)
	# 2.4-4.4 the heart floats up
	a.run(2.4, 4.4, "C5", "C6", 8, 0.5)
	# 3.0 ADOPT A DRONE; 4.0 THEY BEEP! -- two beeps, always chip
	a.tune(3.0, ["G4", "A4", "C5", "E5"], 0.2, 0.4)
	for tt, n in ((4.0, "E6"), (4.22, "G6")):
		a.m.add(chip(S.hz(n), 0.12, 0.25, bend=4.0), tt, 0.9, 0.0)
	a.hit(4.6, "C", 1.2, 0.9)


def coolant(a):
	# TOO HOT? -- a tense stab, a wavering question
	a.hit(0.0, "Em7", 0.6, 0.8)
	a.tune(0.15, ["B4", "C5", "B4", "C5"], 0.16, 0.3, 0.7)
	# 0.8-3.4 the thermometer falls: notes falling, colder as they go
	a.run(0.8, 3.4, "E6", "E4", 12, 0.6)
	# the snow, from 1.6
	for k, tt in enumerate((1.7, 2.1, 2.45, 2.9, 3.3, 3.75, 4.3, 4.9, 5.4)):
		a.sparkle(tt, ["B6", "E6", "G#6", "B5"][k % 4], 0.35)
	# 2.6 AHHH. -- the relief: E major at last
	a.hit(2.6, "E", 1.6, 1.0)
	a.whoosh(2.4, 0.8, False, 0.4)
	# 3.8 FROSTLINE COOLANT
	a.tune(3.8, ["B5", "G#5", "E5"], 0.2, 0.5)
	a.hit(4.4, "E", 1.4, 0.9)


def lucky_spin(a):
	# the bulbs chasing and the reels spinning: ticks and a racing run, to 3.0
	t = 0.0
	while t < 3.0:
		a.tickat(t, 0.4)
		t += 0.125
	for seg in ((0.0, 1.6), (1.6, 2.3), (2.3, 3.0)):
		a.run(seg[0], seg[1], "C5", "C6", int((seg[1] - seg[0]) / 0.07), 0.35)
	# each reel stopping: 7 ... 7 ... and a 3
	a.hit(1.6, "C", 0.5, 0.9)
	a.tune(1.6, ["G5"], 0.2, 0.4)
	a.hit(2.3, "C", 0.5, 1.0)
	a.tune(2.3, ["C6"], 0.2, 0.5)
	a.m.add(S.pluck(S.hz("F#3"), 0.5) + S.pluck(S.hz("G3"), 0.5), 3.0, 1.0, 0.0)
	# 3.4 SO CLOSE! -- wah, wah, wah, wahhh
	a.sad(3.4, ["G4", "F#4", "F4", "E4"], 0.45, 1.1)
	# 4.2 SPIN AGAIN, 1 CR -- hope, quietly
	a.tune(5.2, ["C5", "E5", "G5"], 0.12, 0.3, 0.6)


SHEETS = [("ad_hull_wax", hull_wax), ("ad_star_taxi", star_taxi), ("ad_noodles", noodles),
          ("ad_drone", drone), ("ad_coolant", coolant), ("ad_lucky_spin", lucky_spin)]
ARRS = [("chip", Chip), ("pop", Pop), ("lounge", Lounge)]


## Jon's picks: the arcade chip arrangement for every commercial.
CHOSEN = 1


def main():
	every = "--all" in sys.argv
	os.makedirs(ALL if every else GAME, exist_ok=True)
	for name, sheet in SHEETS:
		for i, (an, A) in enumerate(ARRS, 1):
			if not every and i != CHOSEN:
				continue
			np.random.seed(7 + i)
			a = A()
			sheet(a)
			y = a.m.out(a.wet)
			y = y * 10 ** ((TARGET - loud_second(y)) / 20)
			y = limit(y)
			# ad_hull_wax -> the game's board_ad_hull_wax
			path = os.path.join(ALL, "%s_%d.wav" % (name, i)) if every 				else os.path.join(GAME, "board_%s.wav" % name)
			sf.write(path, y, SR, subtype="PCM_16")
			print("  %-16s %-6s %.2f s  %.1f dB  %s" % (name, an, len(y) / SR, loud_second(y), os.path.basename(path)))


if __name__ == "__main__":
	main()
