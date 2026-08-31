"""Score for "Poisoned Ground" -- the boss cue.

    python3 boss.py [--out DIR] [--loop] [--hp HZ]
"""
import numpy as np
np.random.seed(1729)          # renders are deterministic
import synth; synth.set_tempo(71)
from synth import *
from motif import (MOTIF, PHRYGIAN, FALSE_ANSWER,
                   bar as bb, octave as oc, transpose, diminish)

# =====================================================================
#  "POISONED GROUND"  -  71 BPM, F over a tritone pedal.  32 bars, 108.2 s.
#
#  Both boss ideas the notes files left unbuilt, in one piece.
#
#  DREAD_NOTES §5 -- "state the *original* motif over the tritone pedal.
#  Familiar melody, poisoned ground."  So bars 1-4 are not a variation of
#  anything: they are the opening of "Slow Drift", same five notes, same
#  F6 register, same whistle patch, note for note.  Nothing about the tune
#  is wrong.  The B♮ slides in underneath at bar 5 and the melody does not
#  change at all, which is the entire point -- everywhere else in the game
#  the motif mutates to tell you something; here it stays innocent while
#  the ground goes bad under it.
#
#  THEME_NOTES §6 -- "transpose the cycle down to E♭ minor and put the
#  motif in the bass; keep the whistle on top so it clashes."  Bars 9-16.
#  The bass plays transpose(MOTIF, -2); the whistle stays untransposed, so
#  its G♮ grinds against the bass's G♭ for eight bars.
#
#  Bars 17-24 run both mutations at once -- the whole tone of the theme
#  and the semitone of the dread cue, one beat apart.  The two soundtracks
#  of the game arguing over the same five notes.
#
#  Bars 25-32 answer the question the motif has been asking all run.  The
#  station cue answers it with the fifth ("Warm Ship", bars 23-24); the
#  boss answers it with the ♭5.
# =====================================================================

BARS = 32

# --- harmony ---------------------------------------------------------
FM    = ['F3', 'Ab3', 'C4']
EBM   = ['Eb3', 'Gb3', 'Bb3', 'F4']       # Ebm add9 -- the F pedal is the 9th
CLUST = ['F3', 'Gb3', 'Ab3', 'Bb3']       # semitone stack
TRIC  = ['F3', 'B3', 'Db4', 'Gb4']        # F + its tritone

BASS = transpose(MOTIF, -2)               # Eb F Eb F Gb -- the motif, dropped

# The tempo lock used as a compositional device rather than as a convenience.
# This cue runs at 71, so halving the motif's note values reproduces the main
# theme's 142 BPM rhythm exactly -- 0.4225 s quarters, 0.845 s on the tail.
# QUOTE is therefore not "the motif, slower": it is the opening of "Slow
# Drift", the same durations to the sample.  A boss cue that merely alluded
# to the theme would not do the job; this one has to *be* it.
QUOTE = diminish(MOTIF, 2)                # 3 beats here = 6 beats at 142

# --- the tune -------------------------------------------------------
# 36 motif statements in 108 seconds, and the cue's two real ideas -- the
# untouched quotation at the top and the ♭5 at the bottom -- were buried in
# the middle sixteen bars restating them.  So the middle gets a tune of its
# own and the two ideas get room.
#
# DESCENT is built from the cue's own pitch world: F Phrygian plus the
# tritone.  It states the semitone the whole cue turns on (F to G♭) as its
# opening gesture, climbs to a D♭6 it touches once, and comes back down
# through the B natural -- so the ♭5 is in the melody sixteen bars before
# FALSE_ANSWER lands on it, and lands as something the tune has been circling
# rather than as a surprise.
#
# The quotation at bars 1-8 stays exactly as it is.  It is the best idea in
# the cue and it costs eight of the statements; what was worth cutting was
# the middle saying it another twenty times.

#: Bars 9-16 and, transposed, 17-24.  Slow: at 71 BPM these are four-second
#: notes and the line takes two bars to move a third.
DESCENT = [('F5', 0, 4), ('Gb5', 4, 4),
           ('Bb5', 8, 6), ('Ab5', 14, 2),
           ('Db6', 16, 4), ('B5', 20, 4),
           ('Ab5', 24, 4), ('Gb5', 28, 4)]

#: Bars 17-24: the same line a minor third down, into the stretto, where it
#: is the third voice in an argument that previously had two.
DESCENT_LO = [('Db5', 0, 4), ('D5', 4, 4),
              ('Gb5', 8, 6), ('F5', 14, 2),
              ('Bb5', 16, 4), ('Ab5', 20, 4),
              ('F5', 24, 4), ('Eb5', 28, 4)]

#: Bars 17-24, the bowed climb -- the Phrygian tetrachord walked upward
#: under a melody that cannot walk anywhere.
CLIMB_A = [('Bb2', 0, 6), ('Db3', 6, 6), ('Eb3', 12, 4),
           ('F3', 16, 8), ('Gb3', 24, 4), ('Ab3', 28, 4)]

#: Bars 25-32: it keeps going, through B♭ to the B natural, and stops.  The
#: tritone reached by step from below while the melody leaps to it from
#: above, so the ♭5 is a destination two voices agreed on.
CLIMB_B = [('Ab3', 0, 6), ('Bb3', 6, 6), ('B3', 12, 8),
           ('Db4', 20, 4), ('B3', 24, 8)]


T = {k: Track(BARS) for k in
     ['sub', 'drone', 'pad', 'motif', 'shadow', 'bowed', 'metal', 'pulse', 'fx']}

# ============ I. RECOGNITION : bars 1-8 ============
# The title music, unaltered, over a pedal that turns tritone at bar 5.
T['sub'].add(drone(hz('F1'), 8*BAR, 0.74, 85, 200), bb(1))
T['fx'].add(air(8*BAR, 0.10, 80, 1100), bb(1))
T['drone'].add(drone(hz('B1'), 4*BAR, 0.30, 90, 260), bb(5))      # it arrives late
# One statement per bar is one every 3.38 s, the same rate arrange.py states
# it at in its own intro (bars 1, 3, 5, 7 of a 142 BPM tune).
# Every other bar rather than every bar.  Eight statements established the
# quotation and then kept establishing it; four say the same thing and leave
# the pedal audible, which is the half of this section that is actually
# doing the work.
for i, bar in enumerate([1, 3, 5, 7]):
    for n, b, d in oc(QUOTE, 6):
        T['motif'].add(whistle(hz(n), d*SPB*0.94, 0.34), bb(bar)+b,
                       pan=-0.26+0.16*i)
    if bar >= 5:
        T['pad'].add(cluster([hz(x) for x in FM], 2*BAR, 0.18, 900), bb(bar))
    if bar in (2, 6):                    # the gap the quotation leaves
        T['metal'].add(metal(hz('B4'), 5.0, 0.07), bb(bar), pan=0.30*(1 if bar == 2 else -1))
T['metal'].add(metal(hz('B5'), 7.0, 0.13), bb(7), pan=0.40)

# ============ II. DESCENT : bars 9-16 ============
# The cycle drops to E♭ minor and the motif goes into the bass with it.
# The whistle does not follow -- it holds the original pitches, so its G♮
# sits a semitone above the bass's G♭ for the whole section.
for i, bar in enumerate([9, 11, 13, 15]):
    T['sub'].add(drone(hz('F1'), 2*BAR, 0.72, 82, 180), bb(bar))  # pedal never moves
    T['pad'].add(cluster([hz(x) for x in EBM], 2*BAR, 0.30, 1200), bb(bar))
    if i in (0, 2):                       # twice, not four times
        for n, b, d in oc(BASS, 2):
            T['bowed'].add(bowed(hz(n), d*SPB*0.95, 0.46), bb(bar)+b, pan=-0.35)

    if i >= 2:
        for n, b, d in oc(BASS, 3):                               # octave up, thin
            T['bowed'].add(bowed(hz(n), d*SPB*0.95, 0.16), bb(bar)+b, pan=0.38)
# The whistle no longer restates the motif over the bass's version of it --
# it sings against it, which is what made the grind worth setting up.
for n, b, d in DESCENT:
    T['motif'].add(whistle(hz(n), d*SPB*0.94, 0.34), bb(9)+b, pan=0.18)
    if d >= 6:                                    # the peaks ring
        T['metal'].add(metal(hz(n), 5.0, 0.06), bb(9)+b, pan=-0.30)
# The pulse backbone.  No drum kit in this cue by ruling -- rhythm is the
# heart and two impacts -- so the heart IS the kit, and it builds the way a
# kit would: one thump per two bars here, doubled in the stretto, doubled
# again with an offbeat under the false answer.  The player's pulse stem is
# rung 2 of the ladder; a skirmish never hears it race.
for bar in [9, 11, 13, 15]:
    T['pulse'].add(heart(0.32 + 0.04*(bar-9)), bb(bar))
T['metal'].add(metal(hz('Gb5'), 8.0, 0.12), bb(13), pan=-0.42)

# ============ III. STRETTO : bars 17-24 ============
# Whole tone and semitone at once, one beat apart.  "Slow Drift" and
# "Dead Sector" playing the same phrase over the same pedal and disagreeing
# about one note -- which is, exactly, the one note they have ever disagreed
# about.  The B♮ pedal underneath means neither of them is right.
T['fx'].add(impact(0.62, 5.0), bb(17))
T['sub'].add(drone(hz('F1'), 8*BAR, 0.80, 80, 230), bb(17))
T['drone'].add(drone(hz('B1'), 8*BAR, 0.34, 88, 300), bb(17))
for i, bar in enumerate([17, 19, 21, 23]):
    T['pad'].add(cluster([hz(x) for x in CLUST], 2*BAR, 0.26, 1500), bb(bar))
    for n, b, d in oc(QUOTE, 5):              # theme voice, running at 142
        T['motif'].add(whistle(hz(n), d*SPB*0.94, 0.34), bb(bar)+b, pan=-0.34)
    for n, b, d in oc(PHRYGIAN, 4):                               # dread, +1 beat
        T['shadow'].add(whistle_bend(hz(n), d*SPB*0.92, 0.34, -7),
                        bb(bar)+b+1, pan=0.36)
    T['bowed'].add(bowed(hz('F2'), 2*BAR, 0.20, 3.2), bb(bar), pan=-0.44)
    T['bowed'].add(bowed(hz('Gb2'), 2*BAR, 0.17, 3.2), bb(bar)+2, pan=0.44)
for n, b, d in DESCENT_LO:                   # the third voice in the argument
    T['shadow'].add(whistle(hz(n), d*SPB*0.92, 0.20), bb(17)+b, pan=0.10)
for n, b, d in CLIMB_A:
    T['bowed'].add(bowed(hz(n), d*SPB*0.96, 0.30, 2.6), bb(17)+b, pan=-0.18)
for bar in range(17, 25):
    T['pulse'].add(heart(0.44), bb(bar))
    T['pulse'].add(heart(0.26), bb(bar)+2)
T['metal'].add(metal(hz('Gb5'), 9.0, 0.14), bb(21), pan=-0.30)
T['fx'].add(rev_swell(1.5*BAR, 0.30, hz('B2')), bb(23.5))

# ============ IV. THE FIFTH : bars 25-32 ============
# The motif has avoided the fifth since the first bar of the game.  Here it
# finally lands on one, and it is a semitone flat.  FALSE_ANSWER keeps the
# original whole tone the whole way in so the arrival is the only thing
# that is wrong -- and it spans exactly two bars, so it fits the cycle.
T['fx'].add(impact(0.88, 6.0), bb(25))
T['sub'].add(drone(hz('F1'), 8*BAR, 0.92, 78, 270), bb(25))
T['drone'].add(drone(hz('B1'), 8*BAR, 0.44, 86, 320), bb(25))
for i, bar in enumerate([25, 27, 29, 31]):
    T['pad'].add(cluster([hz(x) for x in TRIC], 2*BAR, 0.30, 1900), bb(bar))
    for n, b, d in oc(FALSE_ANSWER, 5):
        T['motif'].add(whistle(hz(n), d*SPB*0.94, 0.42), bb(bar)+b, pan=-0.22)
    if i >= 2:                       # the shadow joins for the last two only,
        for n, b, d in oc(FALSE_ANSWER, 4):   # so the doubling is an arrival
            T['shadow'].add(whistle_bend(hz(n)*0.9971, d*SPB*0.94, 0.24, -16),
                            bb(bar)+b+0.5, pan=0.34)
    T['bowed'].add(bowed(hz('B2'), 2*BAR, 0.22, 3.4), bb(bar), pan=0.44)
    T['bowed'].add(bowed(hz('F2'), 2*BAR, 0.22, 3.4), bb(bar), pan=-0.44)
    T['pulse'].add(heart(0.58), bb(bar))
    T['pulse'].add(heart(0.36), bb(bar)+2)
    T['pulse'].add(heart(0.22), bb(bar)+3.5)      # the offbeat: it races
# The climb finishes on the B natural in the same phrase FALSE_ANSWER lands
# on it -- by step from below against a leap from above, so the two voices
# converge on the ♭5 instead of one of them simply being wrong.
for n, b, d in CLIMB_B:
    T['bowed'].add(bowed(hz(n), d*SPB*0.96, 0.34, 2.8), bb(25)+b, pan=-0.14)
T['metal'].add(metal(hz('B5'), 10.0, 0.16), bb(29), pan=0.32)
# The loop wraps from the ♭5 straight back into the untouched theme, which
# is the joke the whole cue is built on: it never stops being the same tune.
T['fx'].add(air(4*BAR, 0.09, 70, 800), bb(29))

# ---------------- mix ----------------

FX = {'sub': (0.06, 1.00), 'drone': (0.50, 0.95), 'pad': (0.55, 0.95),
      'motif': (0.50, 0.90), 'shadow': (0.56, 0.90), 'bowed': (0.46, 0.95),
      'metal': (0.62, 0.80), 'pulse': (0.16, 1.00), 'fx': (0.50, 0.90)}

def render(name, tr):
    y = tr.out(); wet, lvl = FX[name]
    if name in ('motif', 'shadow', 'metal'):
        y = delay(y, 3*SPB, fb=0.44, mix=0.28)
    y = reverb(y, wet)*lvl
    if name == 'sub': y = lp(y, 170, 2)*1.05 + hp(y, 170, 2)*0.28
    return y

def build(out_dir='out', loop=False, highpass=None):
    """loop=True drops the fade-out and wraps the reverb tail over the head."""
    mix, stems = master(
        {n: render(n, t) for n, t in T.items()},
        shelf=(0.18, 70), drive=1.20, # 0.85, from 0.88: with the gong and reversed-cymbal textures the fx
        # stem landed at 1.021 -- over the mix is allowed, over 1.0 clips and
        # breaks the stem sum.  The ceiling is the only lever that moves it
        # (the bus is peak-normalised).
        peak=0.81,
        fade_in=(1.0, 1.3), fade_out=(4.2, 1.7),
        highpass=highpass,
        loop_len=int(BARS*BAR*SR) if loop else None)
    tag = '_loop' if loop else ''
    write_wav('%s/boss%s.wav' % (out_dir, tag), mix)
    for n, y in stems.items():
        write_wav('%s/boss_stems%s/%s.wav' % (out_dir, tag, n), y)
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
    print('boss%s  %.3f s  peak %.3f' % (
        '_loop' if a.loop else '', m.shape[1]/SR, np.max(np.abs(m))))
