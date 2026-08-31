import numpy as np, os
np.random.seed(1729)          # renders are deterministic
import synth; synth.set_tempo(142)
from synth import *
from motif import (MOTIF, INVERT, bar as bb, octave as at_oct, augment,
                   loop_beats)

BARS = 72

# ---------------- harmony ----------------
# A / A' cycle : i - bVI - iv - bVII   (F minor, Aeolian)
A_CYCLE = [
    (['F3','Ab3','C4','F4'],   'F2'),
    (['Db3','F3','Ab3','C4'],  'Db2'),
    (['Bb2','Db3','F3','Ab3'], 'Bb1'),
    (['Eb3','G3','Bb3','Eb4'], 'Eb2'),
]
# B : F Dorian (D natural) -> i9 - IV - bVI - bVII
B_CYCLE = [
    (['F3','Ab3','C4','G4'],   'F2'),
    (['Bb2','D3','F3','Bb3'],  'Bb1'),
    (['Ab2','C3','Eb3','G3'],  'Ab1'),
    (['Eb3','G3','Bb3','F4'],  'Eb2'),
]
C_CHORDS = [(['Db3','F3','Ab3','C4'], 'Db2'), (['C3','Eb3','G3','C4'], 'C2')]

# --- the tune -------------------------------------------------------
# `motif_audit.py` counted 46 motif statements in this cue -- one every 2.7
# seconds for two minutes -- and no other melodic material at all.  That is
# not a motif, and no amount of recolouring the harmony under it fixes it.
#
# So the cue has a tune now, and the motif does what a motif does: it opens
# the piece, tags the end of each big section, and closes it.  Six
# statements instead of forty-six.
#
# THEME_A is a sixteen-bar period over two turns of the i-♭VI-iv-♭VII cycle.
# Antecedent ends open on the ♭VII; consequent goes higher, touches D♭6 once
# -- the only time anything in the cue reaches it -- and falls to an F over
# the E♭ chord, so it lands on the tonic PITCH without a tonic CHORD under
# it and the phrase finishes without closing.  That is a choice about this
# game rather than a rule: a cue that loops under a run which can end at any
# moment should not sound finished.
#
# It stays in F Aeolian, and that is also a choice and not an inherited
# constraint -- the modal colour is what makes this sound like this game
# rather than like film music, and a raised seventh would drag it toward a
# cadence it does not want.  The one borrowed note is the D♮ in THEME_B,
# where the section is already Dorian.

#: Sixteen bars, 64 beats, over the A cycle twice.
THEME_A = [
    ('C5', 0, 3), ('Db5', 3, 1), ('C5', 4, 2), ('Ab4', 6, 2),      # i
    ('F5', 8, 4), ('Eb5', 12, 2), ('Db5', 14, 2),                  # ♭VI
    ('Db5', 16, 2), ('F5', 18, 2), ('Ab5', 20, 4),                 # iv, climbing
    ('G5', 24, 2), ('F5', 26, 2), ('Eb5', 28, 4),                  # ♭VII: open
    ('C5', 32, 3), ('Db5', 35, 1), ('C5', 36, 2), ('F5', 38, 2),   # i again
    ('Ab5', 40, 4), ('G5', 44, 2), ('F5', 46, 2),                  # ♭VI, G is its ♯11
    ('Db6', 48, 4), ('C6', 52, 2), ('Ab5', 54, 2),                 # iv: the one high point
    ('Bb5', 56, 2), ('Ab5', 58, 2), ('F5', 60, 4),                 # ♭VII: F over E♭
]

#: Eight bars over the B cycle, which is F Dorian.  Falls where THEME_A
#: climbs, and spends the D natural at its top -- the note this section has
#: and the A sections do not.
THEME_B = [
    ('Ab5', 0, 2), ('G5', 2, 2), ('F5', 4, 4),
    ('D6', 8, 4), ('C6', 12, 2), ('Bb5', 14, 2),
    ('C6', 16, 2), ('Bb5', 18, 2), ('G5', 20, 4),
    ('Bb5', 24, 2), ('Ab5', 26, 2), ('F5', 28, 4),
]

#: The long notes only, for a voice that shadows the tune rather than
#: doubling it -- the bell takes this an octave up.
def spine(line, up=1):
    return [(n[:-1] + str(int(n[-1]) + up), b, d) for n, b, d in line if d >= 4]


def sing(track, line, bar0, amp, voice, pan=0.0, mul=0.96, off=0.0):
    for n, b, d in line:
        track.add(voice(hz(n), d*SPB*mul, amp), bb(bar0)+b+off, pan=pan)


tracks = {k: Track(BARS) for k in
          ['whistle','lead','pad','bass','arp','perc','bell','fx']}

# ================= INTRO : bars 1-8 =================
# Motif alone, ping-pong delay.
#
# This was the ORIGINAL recorded register (F6) -- the measured pitch of the
# whistled source, see THEME_NOTES.md.  It is F5 now, an octave down, and the
# reason is the recorded instrument set: `synth.whistle` at F6 is a near-sine
# with a 4.5% second harmonic and sits there quite happily, but a piccolo at
# 1397 Hz puts its formant exactly where the ear is most sensitive, and over
# eight bare bars with nothing to mask it that is piercing rather than
# distant.
#
# The statement is NOT gone: the bell doubling at bar 17 and the outro's last
# word (bars 65-72) are both still at 6, and the outro is the one that matters
# -- the cue ends on the recording's own pitch.  What moved is the opening,
# where the note is alone and long.
for i, bar in enumerate([1, 3, 5, 7]):
    for n, b, d in at_oct(MOTIF, 5):
        tracks['whistle'].add(whistle(hz(n), d*SPB*0.94, 0.50),
                              bb(bar)+b, pan=-0.25+0.16*i)
for bar, (v, r) in zip([5, 7], [A_CYCLE[0], A_CYCLE[1]]):
    tracks['pad'].add(pad([hz(x) for x in v], 2*BAR, 0.22, 1500), bb(bar))
tracks['fx'].add(noise_swell(2*BAR, 0.12), bb(7))

# ================= A : bars 9-24 =================
# Same 5 notes, 4 harmonic colours. Melody static, harmony moves.
for rep in range(2):
    for c in range(4):
        bar = 9 + rep*8 + c*2
        v, root = A_CYCLE[c]
        tracks['pad'].add(pad([hz(x) for x in v], 2*BAR, 0.30, 2000), bb(bar))
        for k in range(4):                                  # bass: dotted pulse
            tracks['bass'].add(sub(hz(root), SPB*0.9, 0.16), bb(bar)+k*2)

    # half-time drums
    for bar in range(9+rep*8, 17+rep*8):
        tracks['perc'].add(kick(0.75), bb(bar))
        tracks['perc'].add(snare(0.42), bb(bar)+2)
        for k in range(8):
            tracks['perc'].add(hat(0.05, 0.12+0.05*(k % 2 == 0)), bb(bar)+k*0.5,
                               pan=0.3 if k % 2 else -0.3)

# The tune, stated whole, on the voice the cue is named after.
sing(tracks['whistle'], THEME_A, 9, 0.40, whistle, pan=-0.08)
sing(tracks['lead'], THEME_A, 9, 0.26, whistle, pan=0.22, off=0.0)
# spine at pitch, not 8va: the design view showed the bell's octave
# doubling topping midi 97 here -- above anything the CLIMAX reaches, and
# decoration should never overshoot the line.  The top octave now belongs
# to one place only: the second pass of A'.
for n, b, d in spine(THEME_A, up=0):
    tracks['bell'].add(bell(hz(n), d*SPB*1.5, 0.13), bb(9)+b, pan=0.42)
# ...and the motif once, as a tag, in the two bars the period leaves empty.
for n, b, d in at_oct(MOTIF, 6):
    tracks['whistle'].add(whistle(hz(n), d*SPB*0.94, 0.22), bb(23)+b, pan=0.40)

# ================= B : bars 25-40 =================
# Modal lift to F Dorian, motif inverted, arp + full drums.
pluck_cache = {}
def pk(f, d, a):
    key = (round(f, 2), round(d, 3))
    if key not in pluck_cache:
        pluck_cache[key] = pluck(f, d, 1.0)
    return pluck_cache[key]*a

for rep in range(2):
    for c in range(4):
        bar = 25 + rep*8 + c*2
        v, root = B_CYCLE[c]
        tracks['pad'].add(pad([hz(x) for x in v], 2*BAR, 0.26, 2600), bb(bar))
        for k in range(8):
            tracks['bass'].add(sub(hz(root), SPB*0.85, 0.18), bb(bar)+k)
        # Terraced: eighths on the first pass, sixteenths on the second.
        # The design view showed B entering as a cliff -- everything at once
        # at bar 25 -- and then sixteen bars dead flat.  Now the section
        # grows into itself, which also leaves A' somewhere to go.
        order = [0, 1, 2, 3, 2, 1]
        dens = 16 if rep == 0 else 32
        for s in range(dens):
            f = hz(v[order[s % len(order)]])*(2 if s % 12 > 8 else 1)
            tracks['arp'].add(pk(f, 0.38, 0.13), bb(bar)+s*(8.0/dens),
                              pan=-0.45+0.9*((s % 6)/5))

    sing(tracks['whistle'], THEME_B, 25 + rep*8, 0.42, whistle,
         pan=-0.10 + 0.20*rep)
    if rep == 1:                       # the spine joins on the second pass
        for n, b, d in spine(THEME_B, up=0):
            tracks['bell'].add(bell(hz(n), d*SPB*1.4, 0.14), bb(33)+b,
                               pan=-0.40)
    if rep == 1:                       # the motif tags the end of the section
        for n, b, d in at_oct(INVERT, 6):
            tracks['whistle'].add(whistle(hz(n), d*SPB*0.94, 0.22), bb(39)+b,
                                  pan=-0.34)
    for bar in range(25+rep*8, 33+rep*8):
        tracks['perc'].add(kick(0.85), bb(bar))
        tracks['perc'].add(kick(0.62), bb(bar)+2.5)
        tracks['perc'].add(snare(0.55), bb(bar)+1)
        tracks['perc'].add(snare(0.55), bb(bar)+3)
        hats = 8 if rep == 0 else 16       # the kit opens up with the arps
        for k in range(hats):
            tracks['perc'].add(hat(0.04, 0.10+0.06*(k % 4 == 0)),
                               bb(bar)+k*(4.0/hats),
                               pan=0.35 if k % 2 else -0.35)

# ================= C bridge : bars 41-48 =================
# Augmentation: the motif at half speed. Everything else drops out --
# and in the emptied space, THE LOOP: the album's transponder tick, every
# three beats, very faint and far right.  This is the one place in normal
# play a player meets it before the deep cues, and it is planted exactly the
# way the lore plants its constants: in the corner of the document, never
# the subject.  A sector is where the transponder loops live.
for i, bar in enumerate([41, 45]):
    v, root = C_CHORDS[i]
    tracks['pad'].add(pad([hz(x) for x in v], 4*BAR, 0.34, 1300), bb(bar))
    for k in range(4):
        tracks['bass'].add(sub(hz(root), SPB*3.4, 0.13), bb(bar)+k*4)
    # The bridge takes the tune's own head, augmented -- not the motif.
    for n, b, d in [(n, b*2, d*2) for n, b, d in THEME_A[:4]]:
        tracks['whistle'].add(whistle(hz(n), d*SPB*0.92, 0.34), bb(bar)+b, pan=0.0)
    for n, b, d in [(n, b*2, d*2) for n, b, d in THEME_A[4:7]]:
        tracks['bell'].add(bell(hz(n), d*SPB*1.2, 0.12), bb(bar)+b, pan=0.30)
_tick = bell(hz('F6'), 1.4, 1.0)
for _b in loop_beats(3.0, 32.0):
    tracks['fx'].add(_tick*0.030, bb(41) + _b, pan=0.44)
tracks['fx'].add(noise_swell(2*BAR, 0.16), bb(47))

# ================= A' : bars 49-64 =================
# Full tutti. Motif in canon with itself, one octave down, two beats late.
for rep in range(2):
    for c in range(4):
        bar = 49 + rep*8 + c*2
        v, root = A_CYCLE[c]
        tracks['pad'].add(pad([hz(x) for x in v], 2*BAR, 0.30, 3000), bb(bar))
        for k in range(8):
            tracks['bass'].add(sub(hz(root), SPB*0.8, 0.18), bb(bar)+k)

        order = [0, 2, 1, 3, 2, 0]
        for s in range(32):
            tracks['arp'].add(pk(hz(v[order[s % 6]]), 0.34, 0.11), bb(bar)+s*0.25,
                              pan=0.45-0.9*((s % 6)/5))
    # Canon at the octave, four beats apart -- on the TUNE.  The device was
    # already here and it was being spent on five notes; a sixteen-bar period
    # is something a canon can actually do something with.
    if rep == 0:
        sing(tracks['whistle'], THEME_A, 49, 0.44, whistle, pan=-0.18)
        sing(tracks['lead'], [(n[:-1] + str(int(n[-1]) - 1), b, d)
                              for n, b, d in THEME_A], 49, 0.30, whistle,
             pan=0.30, off=4)
        for n, b, d in spine(THEME_A, up=0):
            tracks['bell'].add(bell(hz(n), d*SPB*1.5, 0.15), bb(49)+b, pan=0.44)
    if rep == 1:
        # The apex of the whole cue, reached once: the CONSEQUENT's long
        # notes -- the half of the tune that contains its D-flat 6 -- an
        # octave up, re-zeroed so they sit inside bars 57-64.  Placed whole,
        # the 16-bar spine ran to bar 72 and dropped the peak into the
        # outro; the register envelope caught it.  A climax is a register
        # nothing else has used, AT the climax.
        for n, b, d in [(n, b - 32, d) for n, b, d in spine(THEME_A, up=1)
                        if b >= 32]:
            tracks['bell'].add(bell(hz(n), d*SPB*1.6, 0.15), bb(57)+b, pan=0.30)
    for bar in range(49+rep*8, 57+rep*8):
        tracks['perc'].add(kick(0.92), bb(bar))
        tracks['perc'].add(kick(0.70), bb(bar)+2.5)
        tracks['perc'].add(kick(0.55), bb(bar)+3.5)
        tracks['perc'].add(snare(0.60), bb(bar)+1)
        tracks['perc'].add(snare(0.60), bb(bar)+3)
        for k in range(16):
            tracks['perc'].add(hat(0.04, 0.11+0.07*(k % 4 == 0)), bb(bar)+k*0.25,
                               pan=0.35 if k % 2 else -0.35)

# ================= OUTRO : bars 65-72 =================
v, root = A_CYCLE[0]
tracks['pad'].add(pad([hz(x) for x in v], 8*BAR, 0.30, 1100), bb(65))
for k in range(6):
    tracks['bass'].add(sub(hz(root), SPB*1.6, 0.15*(1-k/7)), bb(65)+k*2)
for bar in [65, 66, 67]:
    tracks['perc'].add(kick(0.55), bb(bar))
    tracks['perc'].add(snare(0.30), bb(bar)+2)
for n, b, d in at_oct(MOTIF, 5):
    tracks['lead'].add(whistle(hz(n), d*SPB*0.96, 0.38), bb(65)+b, pan=-0.1)
for n, b, d in augment(at_oct(MOTIF, 6), 2):       # last word: original register
    tracks['whistle'].add(whistle(hz(n), d*SPB*1.0, 0.44), bb(69)+b, pan=0.0)
tracks['whistle'].add(whistle(hz('F6'), 3.2, 0.30), bb(72)+2)

# ---------------- mix ----------------

FX = {  # (reverb wet, delay time in beats or None, level)
    'whistle': (0.42, 0.75, 1.00),
    'lead':    (0.30, 0.75, 1.00),
    'pad':     (0.45, None, 0.95),
    'bass':    (0.05, None, 1.00),
    'arp':     (0.34, 0.50, 0.85),
    'perc':    (0.14, None, 0.95),
    'bell':    (0.50, 1.50, 0.80),
    'fx':      (0.55, None, 0.80),
}

def render(name, tr):
    y = tr.out()
    wet, dl, lvl = FX[name]
    if dl: y = delay(y, dl*SPB, fb=0.40, mix=0.28)
    y = reverb(y, wet)*lvl
    if name == 'bass': y = lp(y, 220, 2)*1.0 + hp(y, 220, 2)*0.35
    if name == 'perc': y = hp(y, 70, 2)*1.0 + lp(y, 70, 2)*0.35   # keep the knock, cut the boom
    return y

def build(out_dir='out', loop=False, highpass=None):
    """loop=True drops the fade-out and wraps the reverb tail over the head."""
    mix, stems = master(
        {n: render(n, t) for n, t in tracks.items()},
        shelf=(0.25, 90), drive=1.25, peak=0.82,
        # 0.82: humanization's gain jitter can lift a hot bass stem ~+2 dB,
        # and the ceiling is the lever on a peak-normalised bus.
        fade_in=(0.05, 1.0), fade_out=(2.6, 1.6),
        highpass=highpass,
        loop_len=int(BARS*BAR*SR) if loop else None)
    tag = '_loop' if loop else ''
    write_wav('%s/theme%s.wav' % (out_dir, tag), mix)
    for n, y in stems.items():
        write_wav('%s/stems%s/%s.wav' % (out_dir, tag, n), y)
    return mix, stems

if __name__ == '__main__':
    import argparse
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out', default='out')
    ap.add_argument('--loop', action='store_true',
                    help='no fade-out; wrap the reverb tail back over the head')
    ap.add_argument('--hp', type=float, default=None, help='bus high-pass, Hz')
    a = ap.parse_args()
    m, _ = build(a.out, loop=a.loop, highpass=a.hp)
    print('theme%s  %.3f s  peak %.3f' % (
        '_loop' if a.loop else '', m.shape[1]/SR, np.max(np.abs(m))))
