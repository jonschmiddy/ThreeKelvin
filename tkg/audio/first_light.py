"""Score for "First Light" -- title and lobby.  71 BPM, F minor.  48 bars.

    python3 first_light.py [--out DIR] [--loop] [--hp HZ]

=====================================================================
 Written from a measurement rather than from an impression.
=====================================================================

The brief was a slow build to something grandiose and exploratory, taken
from a reference track.  `analyze_track.py` was pointed at that track so
the brief could become numbers, because "slow build" is not something you
can write a score from and a dB-per-phrase schedule is.  What it found,
over 186 seconds:

    loudness    -27.8 dBFS at the start, -15.1 at the peak, -29.2 at the
                end.  A **+12.7 dB arch**, not a ramp.
    peak at     132 s -- **71% of the way through**, then a hard release
                over the last quarter.  The climax is nine seconds long
                and does not sit on a plateau.
    floor       the opening section is **8.3 s** and then it moves.  Worth
                writing down twice, because the first version of this score
                ignored it: eight-bar phrases are the natural unit here, so
                the floor got eight bars and ran 27 seconds before anything
                happened.  It was measured, it was in the table, and it was
                still got wrong by habit.  The floor is two bars now.
    brightness  spectral centroid 922 -> 1223 Hz, tracking the loudness.
    where from  high band 12% -> 18% of the energy; the low band holds
                station at 30-37% throughout.  So the build is **entirely
                added top**.  This is the one that would have been got
                wrong by ear: a build feels like it is getting bigger
                underneath and this one is not, and a score that answers
                it with more bass arrives loud and muddy instead of loud
                and open.
    width       0.63 -> 0.90 side/mid.  Stereo width is a build tool here,
                not a mastering afterthought.
    density     onset rate roughly triples.  More events, not just louder
                ones.
    harmony     B-flat minor, r=0.84, oscillating i(add9) <-> iv with a
                ~23 s cycle, and **no dominant and no cadence anywhere**.

That last line is why this cue was worth writing rather than licensing.
The reference and this soundtrack had already independently arrived at the
same rule -- see README, "The motif never touches the fifth ... A question
with no answer, which is what you want under a run that can end at any
moment."  And its key is not a coincidence either: B-flat minor is F
minor's **iv**.  The reference's home chord is this game's colour chord, so
its harmonic world transposes onto F minor without being bent to fit.

What is taken, and what is not
------------------------------
Taken: the arch and its proportions, the add9 oscillation, the
build-by-brightness, the widening, the tripling density.  Not taken: any
melodic material.  The tune is the same five notes everything else here is
built on, because a title cue that opened with somebody else's phrase would
be the one screen in the game that does not sound like the game.

Against "Five Ways Home"
------------------------
`home.py` is the other title cue and is NOT replaced by this -- both build,
both are in the ladder table, and the two are different answers to the same
screen.  That one is a theme and five variations: discrete eight-bar blocks,
each a self-contained way of looking at the motif, deliberately flat in
dynamic because a variation set is an argument and not a climb.  This one
is a single 162-second arc with one event in it.  A variation set is the
better piece of writing; an arc is the better title screen, because a title
screen is a place you sit in rather than a thing you listen to.  Pick by
ear.

The tempo is 71 rather than the reference's 66.3.  71 is not negotiable --
every cue in the game is 142 or exactly half, which is what makes all 28
pairings cut or crossfade without a tempo match -- so the build runs 7%
faster than the reference and the proportions were kept instead of the
seconds.
=====================================================================
"""
import numpy as np
np.random.seed(1729)          # renders are deterministic
import synth; synth.set_tempo(71)
from synth import *
from motif import MOTIF, MAGGIORE, pitches, bar as bb, augment

# --- proportions -----------------------------------------------------
# The shape, as a table, because it has already been re-cut once and will be
# again.  Everything below indexes off these names rather than off literal
# bar numbers, so moving a phrase boundary is one edit and not forty.
#
#   floor    one chord, no tune.  Two bars: the reference's own floor is
#            8.3 s and a bar here is 3.38.
#   enter    the motif arrives over the oscillation
#   figure   the keyboard enters -- the first struck note in the cue
#   gather   sixteenths, reed, widest minor voicing
#   turn     MAGGIORE.  The climax.
#   release  back to minor, back to one chord
PHRASES = [('floor', 2), ('enter', 8), ('figure', 8),
           ('gather', 8), ('turn', 8), ('release', 8)]

_at, _b = {}, 1
for _name, _len in PHRASES:
    _at[_name] = _b
    _b += _len
FLOOR, ENTER, FIGURE, GATHER, TURN, RELEASE = (_at[n] for n, _ in PHRASES)
BARS = _b - 1                 # 42 * 3.3803 s = 141.97 s

# The climax spans TURN..TURN+7, so its midpoint sits at 74% of the cue
# against the reference's 76%.  Shortening the floor moved the whole build
# earlier without moving that, which is why the release did not need
# re-cutting too.

# --- the arch --------------------------------------------------------
# One number per eight-bar phrase, in dB relative to the climax, taken off
# the reference's own envelope.  Everything in the score is scaled by these
# rather than by amps chosen per event, so the shape is stated in one place
# and is legible as a shape.
#
#   phrase   1      2      3      4      5      6
#   bars     1-8    9-16   17-24  25-32  33-40  41-48
#
# These are NOT the reference's own numbers, and the difference is measured.
# A first pass used its envelope directly -- -12.7 dB floor to peak -- and the
# render came out at **-19.8**, because the schedule is not the only thing
# climbing: the instrument count triples across the same span and that
# arrives on top of the gain.  So the schedule is compressed until the
# rendered arch matches the reference's, which is the number that was
# actually wanted.  Verify with `analyze_track.py out/first_light.wav`.
#
# Stereo width is the one measurement deliberately NOT matched.  The
# reference runs 0.65-0.90 side/mid; the eight cues already in this game run
# 0.14 to 0.57, and the reference is a commercial master with a widener
# across the bus.  Matching it would have made the title screen the one cue
# that does not sound like it comes from the same room as the rest.  The
# target used instead is `shells` at 0.565 -- the star chart, which is the
# closest sibling in mood and the widest thing in here.
PHRASE_DB = [-6.2, -5.0, -3.6, -1.8, 0.0, -4.5]
G = [10 ** (d / 20.0) for d in PHRASE_DB]


_STARTS = [_at[n] for n, _ in PHRASES]


def g(bar):
    """The arch's gain at a bar. Bars are 1-based, as everywhere here.

    Reads the phrase table rather than dividing by eight -- the phrases are
    not all eight bars long any more and the arithmetic version silently
    handed the two-bar floor the wrong gain when they stopped being.
    """
    i = 0
    for k, b0 in enumerate(_STARTS):
        if bar >= b0:
            i = k
    return G[i]


# --- harmony ---------------------------------------------------------
# i(add9) <-> iv(add9), four bars each, which puts the cycle at eight bars
# against the reference's measured ~23 s (6.9 bars at this tempo).  The 9th
# is the whole colour: it is the note that makes a triad sound like a place
# rather than a chord, and the reference has one on every bar of its length.
#
# No V anywhere, and no E natural in the cue at all -- the leading tone is
# what would turn this from a place into a sentence.
I9 = (['F3', 'Ab3', 'C4', 'G4'], 'F2')          # F m add9
IV9 = (['Bb2', 'Db3', 'F3', 'C4'], 'Bb1')       # B flat m add9  <- the
                                                #    reference's own tonic
VI = (['Db3', 'F3', 'Ab3', 'Eb4'], 'Db2')       # flat VI add9, the lift
MAJ = (['F3', 'A3', 'C4', 'G4'], 'F2')          # F major add9 -- the event
MAJ_IV = (['Bb2', 'D3', 'F3', 'C4'], 'Bb1')     # B flat major add9

# --- melody ----------------------------------------------------------
# The motif is a MOTIF.  The first version of this cue had fourteen melodic
# call-sites and all fourteen were the motif -- roughly twenty-five
# statements of the same five notes in two and a half minutes, with no other
# melodic material anywhere in it.  That is not a motif, it is an ostinato,
# and the cue had no tune to be a motif *of*.
#
# So there are three real lines here and the motif appears three times: once
# bare when it enters, once as the head of the big tune, once plainly at the
# end.  Everything else is written melody.
#
# The relationship that matters is in GRAND.  Its first three notes are
# F-G-A, which is MAGGIORE -- the motif in major.  The climax does not
# restate the motif, it GROWS out of it, and the rest of the phrase is
# material the motif has never reached: the leap to C6, the descent, the
# eight-beat F.  A motif earns its keep by being the seed of something, not
# by being the something.

#: Long-breathed, F minor, eight bars over i(add9) -> iv(add9).  Deliberately
#: NOT an oscillation -- it falls to the flat 3rd, then climbs a sixth to its
#: peak, which is a shape the motif cannot make.
ASCENT = [('C5', 0, 4),
          ('Db5', 4, 2), ('C5', 6, 2),
          ('Ab4', 8, 4),
          ('G4', 12, 3),
          ('Bb4', 16, 4),
          ('Db5', 20, 2), ('C5', 22, 2),
          ('F5', 24, 4),
          ('Eb5', 28, 4)]

#: The same idea an octave up and inverted in direction: down first, then up
#: to B flat, the highest note before the turn.  Over i -> flat VI.
REACH = [('Ab5', 0, 4),
         ('G5', 4, 2), ('F5', 6, 2),
         ('Eb5', 8, 4),
         ('C5', 12, 4),
         ('Db5', 16, 4),
         ('F5', 20, 2), ('Ab5', 22, 2),
         ('Bb5', 24, 4),
         ('Ab5', 28, 4)]

#: The climax.  Opens on the motif in major and then goes somewhere the
#: motif never does -- the octave-and-a-fifth reach to C6, and an eight-beat
#: F to land on.  This is the tune the cue is for.
GRAND = [('F5', 0, 2), ('G5', 2, 2),
         ('A5', 4, 4),
         ('C6', 8, 4),
         ('A5', 12, 2), ('G5', 14, 2),
         ('Bb5', 16, 4),
         ('A5', 20, 2), ('G5', 22, 2),
         ('F5', 24, 8)]

#: Two notes, not five: the motif's oscillation used as texture rather than
#: quoted as a phrase.  This is what "using a motif" is supposed to look
#: like next to a tune.
OSC = [(n, i * 2, 2) for i, n in enumerate(['F4', 'G4'] * 8)]


T = {k: Track(BARS) for k in
     ['strings', 'fx', 'whistle', 'hammer', 'reed', 'glass']}

_s, _h, _b = {}, {}, {}


def st(freqs, d, a, cut=3000, atk=0.9):
    k = (tuple(round(f, 2) for f in freqs), round(d, 4), cut, atk)
    if k not in _s:
        _s[k] = strings(freqs, d, 1.0, cut, atk)
    return _s[k] * a


def hm(f, d, a, br=1.0):
    k = (round(f, 2), round(d, 4), br)
    if k not in _h:
        _h[k] = hammer(f, d, 1.0, br)
    return _h[k] * a


def be(f, d, a):
    k = (round(f, 2), round(d, 4))
    if k not in _b:
        _b[k] = bell(f, d, 1.0)
    return _b[k] * a


def bed(chord, bar0, n_bars, amp, cut=3000, atk=0.9, bass=0.30, wide=0.72):
    """The sustained floor: chord, its root an octave down, and a sub.

    One call per harmonic area rather than per bar.  A chord re-struck every
    bar is a chord progression; a chord held for four is a place, and the
    reference holds everything.

    **Divisi, and it is the whole width of the cue.**  The first version put
    the chord down as one mono source at centre and measured 0.29 side/mid
    against the reference's 0.63-0.90 -- nearly mono, and it sounded it:
    small, and pointed at you rather than around you.  Panning does not fix
    that, because panning one mono source only moves it; a stereo field needs
    two sources that are not the same signal.

    So the chord is split the way a section is actually seated -- alternate
    voices to each side -- and the halves are given different attacks and
    cutoffs, so `strings()` renders each with its own bow noise and vibrato
    phase and the two are genuinely decorrelated.  The root and the sub stay
    centred: a low frequency panned wide is a low frequency half the room
    cannot hear.
    """
    v, root = chord
    d = n_bars * BAR
    T['strings'].add(st([hz(x) for x in v[0::2]], d, amp * 0.72, cut, atk),
                     bb(bar0), pan=-wide)
    T['strings'].add(st([hz(x) for x in v[1::2]], d, amp * 0.72,
                        cut * 1.08, atk * 0.88), bb(bar0), pan=wide)
    T['strings'].add(st([hz(x) for x in v], d, amp * 0.26, cut * 0.9, atk),
                     bb(bar0))                      # the glue, centred
    T['strings'].add(st([hz(root)], d, bass, 800, atk + 0.2), bb(bar0))
    T['strings'].add(sub(hz(root) * 0.5, d * 0.97, bass * 0.62), bb(bar0))


def sing(track, notes, bar0, amp, voice, pan=0.0, art=0.94, off=0.0, **kw):
    for n, b, d in notes:
        track.add(voice(hz(n), d * SPB * art, amp, **kw), bb(bar0) + b + off,
                  pan=pan)


# =====================================================================
#  FLOOR : bars 1-2
# =====================================================================
# One chord, no tune, and it lasts two bars.  It was eight, which ran 27
# seconds -- the reference's own floor is 8.3 s, so this was a measured
# number that got overridden by the habit of writing in eight-bar phrases.
# Dark cutoff and a long attack: at this level the ear reads brightness
# rather than volume, so the floor has to be dull as well as quiet or the
# climb has nowhere to start from.
bed(I9, FLOOR, 2, 0.187 * g(FLOOR), cut=1500, atk=1.4, bass=0.30 * g(FLOOR))
T['fx'].add(air(2 * BAR, 0.055 * g(FLOOR), 200, 1400), bb(FLOOR))
T['glass'].add(be(hz('F5'), 5.0, 0.05 * g(FLOOR)), bb(FLOOR) + 2)

# =====================================================================
#  ENTER : the motif arrives
# =====================================================================
# The oscillation starts and the tune enters over it, plain, one statement
# every four bars.  Still nothing struck: this phrase is all sustain, so
# that the keyboard entering at FIGURE registers as an event.
for i, ch in enumerate([I9, IV9]):
    bed(ch, ENTER + i * 4, 4, 0.216 * g(ENTER), cut=1900, atk=1.1,
        bass=0.34 * g(ENTER))
# The motif states in the first two bars and the line answers from bar
# three -- they were both starting at bar one, on the same instrument, which
# is not counterpoint, it is one voice playing two tunes over itself.  The
# line picks up from its own low point (beat 8) so the six bars it has left
# are the climb rather than a truncation.
sing(T['whistle'], pitches(MOTIF, 'F5'), ENTER, 0.34 * g(ENTER),
     whistle, pan=-0.12)                              # the motif, once
sing(T['whistle'], [(n, b - 8, d) for n, b, d in ASCENT if b >= 8],
     ENTER + 2, 0.30 * g(ENTER), whistle, pan=-0.06, art=0.97)
T['fx'].add(air(8 * BAR, 0.06 * g(ENTER), 240, 1900), bb(ENTER))

# =====================================================================
#  FIGURE : figuration
# =====================================================================
# The keyboard enters and the onset rate goes up for the first time.  Eight
# notes a bar, arpeggiated across the chord, panned into a widening spread --
# the reference's side/mid is 0.78 by this point and 0.65 at the start, and
# this is where that starts being deliberate.
for i, ch in enumerate([I9, VI]):
    bed(ch, FIGURE + i * 4, 4, 0.252 * g(FIGURE), cut=2500, atk=0.8,
        bass=0.40 * g(FIGURE))
for i in range(8):
    v, _ = (I9, VI)[i // 4]
    for t_ in range(8):
        f = hz(v[[0, 2, 1, 3][t_ % 4]]) * (2 if t_ >= 4 else 1)
        T['hammer'].add(hm(f, BAR / 8 * 1.6, 0.20 * g(FIGURE), 0.9),
                        bb(FIGURE + i) + t_ * 0.5,
                        pan=-0.34 + 0.68 * ((t_ % 4) / 3.0))
# No motif in this phrase at all.  It is eight bars of tune, which is what
# gives the motif somewhere to come back from.
sing(T['whistle'], REACH, FIGURE, 0.36 * g(FIGURE), whistle, pan=-0.14, art=0.97)
sing(T['reed'], [(n, b, d) for n, b, d in ASCENT if d >= 4],
     FIGURE, 0.18 * g(FIGURE), reed, pan=0.32)        # the long notes only
T['fx'].add(air(8 * BAR, 0.06 * g(FIGURE), 280, 2400), bb(FIGURE))

# =====================================================================
#  GATHER : everything but the event
# =====================================================================
# The reed enters an octave under the whistle, the keyboard doubles to
# sixteenths, and the strings open to their widest minor voicing.  Everything
# that will be in the climax is now present except the one thing the climax
# actually is.
#
# The second half of this phrase goes back to i, and that is load-bearing.
# It was iv -> flatVI here, which meant the turn arrived in F major from D
# flat -- a key change, and it read as one.  Sitting on F MINOR for the four
# bars before it makes the turn what it is claimed to be below: A flat
# becomes A natural and nothing else moves at all.
for i, ch in enumerate([IV9, I9]):
    bed(ch, GATHER + i * 4, 4, 0.281 * g(GATHER), cut=3200, atk=0.6,
        bass=0.50 * g(GATHER))
for i in range(8):
    v, _ = (IV9, I9)[i // 4]
    for t_ in range(16):
        f = hz(v[[0, 2, 1, 3, 2, 3][t_ % 6]]) * (2 if t_ % 8 >= 4 else 1)
        T['hammer'].add(hm(f, BAR / 16 * 1.9, 0.15 * g(GATHER), 1.0),
                        bb(GATHER + i) + t_ * 0.25,
                        pan=-0.42 + 0.84 * ((t_ % 6) / 5.0))
sing(T['whistle'], REACH, GATHER, 0.38 * g(GATHER), whistle, pan=-0.20, art=0.97)
sing(T['reed'], [(n, b + 2, d) for n, b, d in ASCENT], GATHER,
     0.24 * g(GATHER), reed, pan=0.34)                # the line, two beats late
for k in range(2):
    sing(T['glass'], OSC, GATHER + k * 4, 0.06 * g(GATHER), glass, pan=0.26)
T['fx'].add(air(8 * BAR, 0.055 * g(GATHER), 320, 3000), bb(GATHER))
T['fx'].add(noise_swell(2 * BAR, 0.10 * g(GATHER)), bb(TURN - 2))   # into it

# =====================================================================
#  TURN : MAGGIORE.  The climax.
# =====================================================================
# The midpoint of this phrase is 74% of the way through the cue; the
# reference peaks at 76%.
#
# The event is one note.  A flat becomes A natural and the cue is in F
# major -- the same hinge "Five Ways Home" turns on, and the reason both
# cues get to have it is that it is the only thing in this soundtrack that
# can function as an arrival without a cadence.  There is still no dominant
# here.  Nothing resolves; the light just changes colour.
#
# Every build parameter peaks together and none of them is level: cutoff
# 5200 (the brightest in the cue), the widest pan spread, the glass an octave
# above everything, and the strings voiced up rather than down -- the
# measured build was all added top, and this is where that pays.
for i, ch in enumerate([MAJ, MAJ_IV]):
    bed(ch, TURN + i * 4, 4, 0.317 * g(TURN), cut=5200, atk=0.45,
        bass=0.66 * g(TURN))
for i in range(8):
    v, _ = (MAJ, MAJ_IV)[i // 4]
    T['strings'].add(st([hz(x) * 2 for x in v[:3]], BAR, 0.22 * g(TURN),
                        6000, 0.35), bb(TURN + i), pan=0.10 if i % 2 else -0.10)
    for t_ in range(16):
        f = hz(v[[0, 2, 1, 3, 2, 1][t_ % 6]]) * (2 if t_ % 8 >= 3 else 1)
        T['hammer'].add(hm(f, BAR / 16 * 2.1, 0.17 * g(TURN), 1.15),
                        bb(TURN + i) + t_ * 0.25,
                        pan=-0.48 + 0.96 * ((t_ % 6) / 5.0))
# GRAND opens F-G-A, which IS the motif in major -- so the climax states it
# and then leaves it behind inside the same phrase.
sing(T['whistle'], GRAND, TURN, 0.42 * g(TURN), whistle, pan=-0.16, art=0.97)
sing(T['reed'], [(n, b, d) for n, b, d in GRAND], TURN, 0.24 * g(TURN),
     reed, pan=0.36)
sing(T['glass'], [(n, b, d) for n, b, d in GRAND if d >= 4], TURN,
     0.13 * g(TURN), glass, pan=0.34)
# GRAND is exactly 32 beats and the phrase is exactly eight bars, so it
# states once and fills it.  An earlier version put a second statement at
# TURN+4, which overran into the release by four bars and softened the one
# edge the whole arch is built on -- the reference drops 8 dB in the bar
# after its peak, and it cannot do that with the tune still playing.
# The doubling is an octave up, in place, instead.
sing(T['whistle'], [(n[:-1] + str(int(n[-1]) + 1), b, d)
                    for n, b, d in GRAND if d >= 4],
     TURN, 0.15 * g(TURN), whistle, pan=-0.40)
T['fx'].add(air(8 * BAR, 0.05 * g(TURN), 400, 4200), bb(TURN))

# =====================================================================
#  RELEASE
# =====================================================================
# The reference drops 8 dB in the bar after its peak and keeps going, to
# below where it started.  So does this: back to minor, back to one chord,
# and the last four bars are the tune alone over a pedal.
#
# It ends ON the add9 -- unresolved, which is the same refusal the whole
# soundtrack makes, and which is also what a loop needs.  The title screen
# turns this over every two minutes twenty, and a cue that cadenced would
# announce a full stop and then start again anyway.
bed(I9, RELEASE, 4, 0.238 * g(RELEASE), cut=2400, atk=1.0,
    bass=0.40 * g(RELEASE))
bed(I9, RELEASE + 4, 4, 0.187 * g(RELEASE), cut=1700, atk=1.4,
    bass=0.30 * g(RELEASE))
# The third and last statement, augmented to half speed and alone.  After
# eight bars of a tune that grew out of it, the five notes read as a
# signature rather than as a refrain.
sing(T['whistle'], augment(pitches(MOTIF, 'F5'), 2), RELEASE,
     0.34 * g(RELEASE), whistle, pan=-0.10, art=0.92)
# Four bars of the line's long notes only, so it ends inside the phrase --
# ASCENT is eight bars and starting it at RELEASE+4 ran four bars past the
# end of the cue, where the loop wrap folded it back over the opening.
sing(T['reed'], [(n, b, d) for n, b, d in ASCENT if d >= 4 and b < 16],
     RELEASE + 4, 0.16 * g(RELEASE), reed, pan=0.30)
T['glass'].add(be(hz('F6'), 6.0, 0.07 * g(RELEASE)), bb(RELEASE + 4))
T['whistle'].add(whistle(hz('F5'), 4.4, 0.24 * g(RELEASE)), bb(BARS - 1) + 2)
T['fx'].add(air(8 * BAR, 0.05 * g(RELEASE), 200, 1600), bb(RELEASE))

# ---------------- mix ----------------

FX = {  # (reverb wet, delay in beats or None, level)
    'strings': (0.48, None, 1.05),
    'fx':      (0.50, None, 0.85),
    'whistle': (0.38, 0.75, 1.00),
    'hammer':  (0.28, 1.50, 1.05),
    'reed':    (0.34, None, 1.10),
    'glass':   (0.52, 1.50, 0.95),
}


def render(name, tr):
    y = tr.out()
    wet, dl, lvl = FX[name]
    if dl:
        y = delay(y, dl * SPB, fb=0.32, mix=0.22)
    return reverb(y, wet) * lvl


def build(out_dir='out', loop=False, highpass=None):
    """loop=True drops the fade-out and wraps the reverb tail over the head."""
    mix, stems = master(
        {n: render(n, t) for n, t in T.items()},
        shelf=(0.28, 95), drive=1.10, peak=0.86,
        fade_in=(1.2, 1.2), fade_out=(3.0, 1.5),
        highpass=highpass,
        loop_len=int(BARS * BAR * SR) if loop else None)
    tag = '_loop' if loop else ''
    write_wav('%s/first_light%s.wav' % (out_dir, tag), mix)
    for n, y in stems.items():
        write_wav('%s/first_light_stems%s/%s.wav' % (out_dir, tag, n), y)
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
    print('first_light%s  %.3f s  peak %.3f' % (
        '_loop' if a.loop else '', m.shape[1] / SR, np.max(np.abs(m))))
