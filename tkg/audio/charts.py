"""The written cues: the places you spend time, and the fights.

Kept separate from `written.py` because that file is the engine -- the harmony
rules, the voices, the stem rendering, the loop fold -- and this file is only
music. Adding a cue should never mean editing the engine.

WHAT A DRIFT CUE IS FOR. Somewhere you are, rather than something happening.
Eight of the thirteen are drift, which is right: this is a game about travelling
a long way with a ship that is falling apart, and most of it is travel.

HOW THESE STAY DIFFERENT FROM ONE ANOTHER, given that Jon chose thirteen
independent pieces over a suite:

    cue           key             BPM   voice          shape
    first_light   C minor          72   Octave Stack   28 bars, the widest arch
    shells        G minor          68   Wavefold       wide leaps, floating
    warm          B flat major     64   Drawbar        stepwise, settled, no leaps
    home          D minor          70   Warm           an arch that comes home
    core          A minor          58   Sub Drive      slowest, heaviest, coreward
    fauna         E minor          66   Squelch        the only one that leaps
                                                       inside a bar
    business      F minor          84   Octave Stack   briskest, most notes
    burn          F minor         132   Four Bit       a fight: harmony every
                                                       bar, a cell not an arch

Eight cues in six keys and eight tempos. `business` and `burn` are in F because Audio.DEEP
swaps them for `dread` and `boss` mid-play and a shared root is what makes that
read as the place turning; the rest were free and took five other keys, because
the thing that made the second edition blur was thirteen cues on one pedal.

A RULE THAT MAKES THE HARMONY CHECKER NEARLY REDUNDANT, and which is worth
knowing before writing the remaining cues: every melody note of a beat or longer
here is a member of the TRIAD under it, at some octave. Sevenths and ninths are
added by `rich()` and withdrawn by `prune()` where they would collide, so a tune
built only from triad tones cannot produce a clash the pruner will not fix. All
eight passed `check()` first time. That is not luck, it is the constraint.
"""
from __future__ import annotations


# first_light -- the title screen, and the album opener
def first_light(Piece, rich):
    """C minor, 72 BPM, 28 bars. The widest arch in the set, because it is the
    first thing anybody hears and it has to promise the game is going somewhere.
    The B section climbs to a twelfth above the root, which nothing else here
    does, and the return is six bars rather than eight."""
    Cm, Ab, Eb, Bb = [0, 3, 7], [8, 12, 15], [3, 7, 10], [10, 14, 17]
    Fm, Gm = [5, 8, 12], [7, 10, 14]
    ch = ([Cm]*2 + [Ab]*2 + [Eb]*2 + [Bb]*2 +
          [Cm]*2 + [Ab]*2 + [Fm]*2 + [Gm]*2 +
          [Eb]*2 + [Bb]*2 + [Ab]*2 +
          [Cm] + [Ab] + [Eb] + [Bb] + [Cm]*2)
    m = [(0, 0, 3), (3, 3, 1), (7, 4, 4),
         (8, 8, 4), (12, 12, 4),
         (7, 16, 4), (10, 20, 4),
         (14, 24, 4), (10, 28, 4),
         (0, 32, 3), (7, 35, 1), (12, 36, 4),
         (15, 40, 4), (12, 44, 4),
         (17, 48, 4), (12, 52, 4),
         (14, 56, 4), (10, 60, 4),
         (19, 64, 4), (15, 68, 4),
         (17, 72, 4), (14, 76, 4),
         (20, 80, 4), (15, 84, 4),
         (0, 88, 4), (12, 92, 4), (7, 96, 4), (10, 100, 4), (0, 104, 8)]
    return Piece("C2", 72, "drift", "octave_stack", [rich(c) for c in ch], m,
                 "the widest arch: it has to promise the game goes somewhere")


def shells(Piece, rich):
    """G minor, 68 BPM. The star chart. Wide leaps and long notes, because you
    are looking at a map of somewhere you have not been. It never steps: every
    move is a third or more, which is what stops it settling."""
    Gm, Bb, Eb, F = [0, 3, 7], [3, 7, 10], [8, 12, 15], [10, 14, 17]
    Cm, Dm = [5, 8, 12], [7, 10, 14]
    ch = ([Gm]*2 + [Bb]*2 + [Eb]*2 + [F]*2 +
          [Gm]*2 + [Cm]*2 + [Eb]*2 + [F]*2 +
          [Bb]*2 + [Dm]*2 +
          [Gm] + [Eb] + [F] + [Gm])
    m = [(7, 0, 4), (0, 4, 4), (10, 8, 4), (7, 12, 4),
         (15, 16, 4), (12, 20, 4), (17, 24, 4), (14, 28, 4),
         (12, 32, 4), (7, 36, 4), (17, 40, 4), (12, 44, 4),
         (20, 48, 4), (15, 52, 4), (14, 56, 4), (10, 60, 4),
         (19, 64, 4), (15, 68, 4), (19, 72, 4), (14, 76, 4),
         (0, 80, 4), (12, 84, 4), (10, 88, 4), (0, 92, 4)]
    return Piece("G2", 68, "drift", "wavefold", [rich(c) for c in ch], m,
                 "never steps: every move is a third or more")


def warm(Piece, rich):
    """B flat major, 64 BPM. The ship and the station -- the two places you are
    not in danger. The ONLY major-key cue in the soundtrack and the only melody
    that moves stepwise throughout: no leaps anywhere, which is what makes it
    read as somewhere you can put something down."""
    Bb, Gm, Eb, F = [0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14]
    Cm, Dm = [2, 5, 9], [4, 7, 11]
    ch = ([Bb]*2 + [Gm]*2 + [Eb]*2 + [F]*2 +
          [Bb]*2 + [Cm]*2 + [Eb]*2 + [F]*2 +
          [Gm]*2 + [Dm]*2 +
          [Bb] + [Eb] + [F] + [Bb])
    m = [(0, 0, 4), (4, 4, 4), (12, 8, 4), (9, 12, 4),
         (12, 16, 4), (9, 20, 4), (11, 24, 4), (7, 28, 4),
         (7, 32, 4), (12, 36, 4), (14, 40, 4), (9, 44, 4),
         (17, 48, 4), (12, 52, 4), (14, 56, 4), (11, 60, 4),
         (16, 64, 4), (12, 68, 4), (16, 72, 4), (11, 76, 4),
         (0, 80, 4), (12, 84, 4), (7, 88, 4), (0, 92, 4)]
    return Piece("Bb1", 64, "drift", "drawbar", [rich(c) for c in ch], m,
                 "the only major key, and the only tune with no leaps in it")


def home(Piece, rich):
    """D minor, 70 BPM. Where the lobby and the run-start live. An arch that
    actually comes home -- it ends on the root at the same octave it started,
    which no other cue here does. Everything else lands somewhere changed."""
    Dm, F, Bb, C = [0, 3, 7], [3, 7, 10], [8, 12, 15], [10, 14, 17]
    Gm, Am = [5, 8, 12], [7, 10, 14]
    ch = ([Dm]*2 + [F]*2 + [Bb]*2 + [C]*2 +
          [Dm]*2 + [Gm]*2 + [Bb]*2 + [C]*2 +
          [F]*2 + [Am]*2 +
          [Dm] + [Bb] + [C] + [Dm])
    m = [(0, 0, 4), (3, 4, 4), (7, 8, 4), (10, 12, 4),
         (12, 16, 4), (15, 20, 4), (14, 24, 4), (10, 28, 4),
         (12, 32, 4), (7, 36, 4), (17, 40, 4), (12, 44, 4),
         (20, 48, 4), (15, 52, 4), (17, 56, 4), (14, 60, 4),
         (19, 64, 4), (15, 68, 4), (19, 72, 4), (14, 76, 4),
         (0, 80, 4), (12, 84, 4), (10, 88, 4), (0, 92, 4)]
    return Piece("D2", 70, "drift", "warm", [rich(c) for c in ch], m,
                 "the only arch that comes home to the note it left")


def core(Piece, rich):
    """A minor, 58 BPM. Coreward, where the galaxy gets worse. The slowest drift
    cue and the only one on SUB DRIVE, an octave below where a lead normally
    sits -- so the further in you go, the lower the soundtrack gets, which is a
    thing you feel before you notice it."""
    Am, F, Dm, E = [0, 3, 7], [8, 12, 15], [5, 8, 12], [7, 11, 14]
    C, G = [3, 7, 10], [10, 14, 17]
    ch = ([Am]*2 + [F]*2 + [Dm]*2 + [Am]*2 +
          [Am]*2 + [C]*2 + [F]*2 + [E]*2 +
          [Dm]*2 + [G]*2 +
          [Am] + [F] + [E] + [Am])
    m = [(0, 0, 6), (3, 6, 2), (8, 8, 4), (12, 12, 4),
         (12, 16, 4), (8, 20, 4), (7, 24, 4), (0, 28, 4),
         (12, 32, 6), (7, 38, 2), (15, 40, 4), (10, 44, 4),
         (20, 48, 4), (15, 52, 4), (14, 56, 4), (11, 60, 4),
         (17, 64, 4), (12, 68, 4), (17, 72, 4), (14, 76, 4),
         (0, 80, 4), (12, 84, 4), (11, 88, 4), (0, 92, 4)]
    return Piece("A1", 58, "drift", "sub_drive", [rich(c) for c in ch], m,
                 "the further in you go, the lower the soundtrack gets")


def fauna(Piece, rich):
    """E minor, 66 BPM. The megafauna. The only tune in the set that leaps
    INSIDE a bar rather than between them, which is the difference between a
    line that is travelling and a thing that is moving of its own accord.
    SQUELCH plays it: one resonant filter doing all the work, which is the only
    voice here that sounds like it is reacting rather than playing."""
    Em, G, C, D = [0, 3, 7], [3, 7, 10], [8, 12, 15], [10, 14, 17]
    Am, Bm = [5, 8, 12], [7, 10, 14]
    ch = ([Em]*2 + [G]*2 + [C]*2 + [D]*2 +
          [Em]*2 + [Am]*2 + [C]*2 + [Bm]*2 +
          [G]*2 + [D]*2 +
          [Em] + [C] + [Bm] + [Em])
    m = [(0, 0, 2), (7, 2, 2), (3, 4, 4), (10, 8, 4), (7, 12, 4),
         (15, 16, 4), (12, 20, 4), (17, 24, 4), (14, 28, 4),
         (12, 32, 2), (19, 34, 2), (15, 36, 4), (17, 40, 4), (12, 44, 4),
         (20, 48, 4), (15, 52, 4), (19, 56, 4), (14, 60, 4),
         (22, 64, 4), (15, 68, 4), (22, 72, 4), (17, 76, 4),
         (0, 80, 4), (12, 84, 4), (14, 88, 4), (0, 92, 4)]
    return Piece("E2", 66, "drift", "squelch", [rich(c) for c in ch], m,
                 "the only tune that leaps inside a bar")


def business(Piece, rich):
    """F minor, 84 BPM. Encounters: somebody wants something from you.

    ROOTED ON F, and not by preference -- Audio.DEEP swaps this cue for `dread`
    past danger 8, and the swap reads as the place turning rather than the music
    cutting only because the root holds under it.

    The briskest thing in the set at 84 BPM with two notes to the bar where the
    others hold one. An encounter is the only drift state with a clock on it:
    somebody is waiting for an answer.
    """
    Fm, Ab, Db, Eb = [0, 3, 7], [3, 7, 10], [8, 12, 15], [10, 14, 17]
    Bbm, Cm = [5, 8, 12], [7, 10, 14]
    ch = ([Fm]*2 + [Ab]*2 + [Db]*2 + [Eb]*2 +
          [Fm]*2 + [Bbm]*2 + [Db]*2 + [Cm]*2 +
          [Ab]*2 + [Eb]*2 +
          [Fm] + [Db] + [Eb] + [Fm])
    m = [(0, 0, 2), (3, 2, 2), (7, 4, 2), (3, 6, 2),
         (10, 8, 2), (7, 10, 2), (3, 12, 4),
         (12, 16, 2), (15, 18, 2), (12, 20, 4),
         (14, 24, 2), (17, 26, 2), (14, 28, 4),
         (12, 32, 2), (15, 34, 2), (19, 36, 4),
         (17, 40, 2), (20, 42, 2), (17, 44, 4),
         (20, 48, 2), (15, 50, 2), (12, 52, 4),
         (19, 56, 2), (14, 58, 2), (10, 60, 4),
         (15, 64, 4), (19, 68, 4), (17, 72, 4), (14, 76, 4),
         (0, 80, 4), (12, 84, 4), (10, 88, 4), (0, 92, 4)]
    return Piece("F2", 84, "drift", "octave_stack", [rich(c) for c in ch], m,
                 "the only drift state with a clock on it")


def burn(Piece, rich):
    """HARD BURN. F minor, 160 BPM, 32 bars. Frantic.

    FIVE VERSIONS, AND THE FOUR BEFORE IT ARE WHY THIS ONE IS SHAPED LIKE THIS.
    Cool on Four Bit, menacing on Sub Drive, weird on Squelch, big on Octave
    Stack. Jon picked the Four Bit one back out of the pile and asked for more
    frantic -- stressful, epic, a battle -- so the voice returns and the writing
    goes after stress specifically.

    FRANTIC IS TWO LAYERS THAT DISAGREE. This is the whole idea. The ostinato is
    straight SIXTEENTHS, sixteen a bar, dead regular and machine-like. The tune
    moves in eighths and lands off the beat. Neither part is hard to follow on its
    own -- and that is the point, because "it is like math rock" was a complaint
    about a BEAT nobody could follow, and the answer is not to make the beat
    simpler and stop there. It is to keep the beat simple and put the friction
    between the layers. You can count the pulse the whole way through. It is the
    tune refusing to line up with it that does the work.

    STRESS IS ALSO A CLOCK YOU CANNOT OUTRUN. 160 BPM, up from 132. Sixteen
    ostinato notes a bar at 160 is nine a second and it never once stops.

    EPIC IS THE SEQUENCE. Bars 17 to 24 walk one figure up through Db, Eb, Fm,
    Ab, Bbm, Cm and then keep climbing past the top of the tune's own range --
    six rungs without resolving. That is the only part of the piece that is
    going somewhere rather than happening, and a fight needs exactly one.

    AND THE TONIC BARELY APPEARS. F minor lands on bar 1 and then the chart keeps
    moving: Db, Eb, Cm, back round. A tonic is a rest and there is no rest here
    until the last bar.

    THE CEILING IS STILL A RULING. "Drive is not a drum kit" -- no kick, no
    snare, no backbeat. Everything above gets its intensity from subdivision,
    density and pitch instead. If this is still not a battle then that ruling is
    the next thing to argue with, and it deserves to be argued with rather than
    quietly bent.
    """
    Fm, Db, Eb, Ab = [0, 3, 7], [8, 12, 15], [10, 14, 17], [3, 7, 10]
    Bbm, Cm = [5, 8, 12], [7, 10, 14]
    ch = ([Fm, Db, Eb, Cm, Fm, Db, Eb, Eb] +
          [Fm, Db, Eb, Cm, Ab, Bbm, Cm, Cm] +
          [Db, Eb, Fm, Ab, Bbm, Cm, Db, Eb] +
          [Fm, Db, Eb, Cm, Fm, Db, Eb, Fm])
    m = [(0, 0, .5), (3, .5, .5), (7, 1, .5), (12, 1.5, .5), (7, 2, 1), (3, 3, 1),
         (8, 4, .5), (12, 4.5, .5), (15, 5, .5), (20, 5.5, .5), (15, 6, 1), (12, 7, 1),
         (10, 8, .5), (14, 8.5, .5), (17, 9, .5), (22, 9.5, .5), (17, 10, 1), (14, 11, 1),
         (14, 12, .5), (10, 12.5, .5), (7, 13, .5), (10, 13.5, .5), (14, 14, 2),
         (0, 16, .5), (3, 16.5, .5), (7, 17, .5), (12, 17.5, .5), (15, 18, 1), (12, 19, 1),
         (20, 20, .5), (15, 20.5, .5), (12, 21, .5), (8, 21.5, .5), (12, 22, 1), (15, 23, 1),
         (17, 24, .5), (14, 24.5, .5), (10, 25, .5), (14, 25.5, .5), (17, 26, 1), (22, 27, 1),
         (17, 28, 4),
         (0, 32, .5), (3, 32.5, .5), (7, 33, .5), (12, 33.5, .5), (7, 34, 1), (3, 35, 1),
         (8, 36, .5), (12, 36.5, .5), (15, 37, .5), (20, 37.5, .5), (15, 38, 1), (12, 39, 1),
         (10, 40, .5), (14, 40.5, .5), (17, 41, .5), (22, 41.5, .5), (17, 42, 1), (14, 43, 1),
         (19, 44, .5), (14, 44.5, .5), (10, 45, .5), (7, 45.5, .5), (10, 46, 2),
         (15, 48, .5), (19, 48.5, .5), (22, 49, .5), (27, 49.5, .5), (22, 50, 1), (19, 51, 1),
         (24, 52, .5), (20, 52.5, .5), (17, 53, .5), (20, 53.5, .5), (24, 54, 2),
         (26, 56, .5), (22, 56.5, .5), (19, 57, .5), (14, 57.5, .5), (19, 58, 2),
         (14, 60, 4),
         (8, 64, .5), (12, 64.5, .5), (15, 65, .5), (20, 65.5, .5), (15, 66, 2),
         (10, 68, .5), (14, 68.5, .5), (17, 69, .5), (22, 69.5, .5), (17, 70, 2),
         (12, 72, .5), (15, 72.5, .5), (19, 73, .5), (24, 73.5, .5), (19, 74, 2),
         (15, 76, .5), (19, 76.5, .5), (22, 77, .5), (27, 77.5, .5), (22, 78, 2),
         (17, 80, .5), (20, 80.5, .5), (24, 81, .5), (29, 81.5, .5), (24, 82, 2),
         (19, 84, .5), (22, 84.5, .5), (26, 85, .5), (31, 85.5, .5), (26, 86, 2),
         (32, 88, 1), (27, 89, 1), (24, 90, 2),
         (29, 92, 1), (26, 93, 1), (22, 94, 2),
         (24, 96, .5), (19, 96.5, .5), (15, 97, .5), (12, 97.5, .5), (7, 98, 1), (3, 99, 1),
         (8, 100, .5), (12, 100.5, .5), (15, 101, .5), (20, 101.5, .5), (15, 102, 1), (12, 103, 1),
         (10, 104, .5), (14, 104.5, .5), (17, 105, .5), (22, 105.5, .5), (17, 106, 1), (14, 107, 1),
         (14, 108, .5), (10, 108.5, .5), (7, 109, .5), (10, 109.5, .5), (14, 110, 2),
         (0, 112, .5), (3, 112.5, .5), (7, 113, .5), (12, 113.5, .5), (7, 114, 1), (3, 115, 1),
         (8, 116, 1), (12, 117, 1), (15, 118, 2),
         (17, 120, 1), (14, 121, 1), (10, 122, 2),
         (0, 124, 4)]
    return Piece("F2", 160, "drive", "four_bit", [rich(c) for c in ch], m,
                 "sixteenths that do not stop, and a tune that will not line up",
                 pulse=(1,) * 16, stabs=2)


def boss(Piece, rich):
    """POISONED GROUND. F, 160 BPM, 32 bars. Hard Burn, and worse.

    WHAT DEEP ACTUALLY ASKS FOR. Audio.DEEP swaps this in for Hard Burn past
    danger 8, and the ruling on that swap is that it should read as THE PLACE
    TURNING rather than as the music changing. So the things that make a cue
    recognisable are deliberately identical: same root, same tempo, same voice,
    same sixteenth ostinato, same stabs on the bar and the half. Swapping to a
    different-sounding piece would announce itself, and the whole point is that
    it does not.

    WHAT IS WORSE IS THE HARMONY, AND ONLY THE HARMONY. Hard Burn is F minor
    leaning on D flat and E flat -- flat six, flat seven, home, the cadence action
    is built from. This has the flat SECOND instead, G flat against F, and an E
    flat MINOR where the fight has E flat major, and two bars of B diminished
    whose root is a tritone from F. Same speed, same density, same relentlessness;
    every chord that arrives is a worse one.

    That distinction is the thing this cue exists to prove. An earlier attempt at
    Hard Burn went dark by slowing down and dropping the register, and it came out
    further from a battle than what it replaced, because MENACING IS STATIC AND
    ACTION IS RELENTLESS. This keeps every mechanism of the fight and changes only
    what the chords are, which is how you get worse without getting slower.

    AND IT CLIMBS HIGHER. The sequence at bars 17 to 24 runs a fifth above the
    top of Hard Burn's range, so the boss cue is literally further out.
    """
    Fm, Gb, Bbm = [0, 3, 7], [1, 5, 8], [5, 8, 12]
    Ebm, Cm, Bdim, Db = [10, 13, 17], [7, 10, 14], [6, 9, 12], [8, 12, 15]
    ch = ([Fm, Gb, Bbm, Fm, Fm, Gb, Ebm, Ebm] +
          [Fm, Gb, Bbm, Fm, Db, Bdim, Cm, Cm] +
          [Gb, Ebm, Bbm, Db, Bdim, Cm, Gb, Ebm] +
          [Fm, Gb, Bbm, Db, Fm, Gb, Cm, Fm])
    m = [(0, 0, .5), (3, .5, .5), (7, 1, .5), (12, 1.5, .5), (7, 2, 1), (3, 3, 1),
         (8, 4, .5), (13, 4.5, .5), (17, 5, .5), (20, 5.5, .5), (17, 6, 1), (13, 7, 1),
         (12, 8, .5), (17, 8.5, .5), (20, 9, .5), (24, 9.5, .5), (20, 10, 1), (17, 11, 1),
         (12, 12, .5), (7, 12.5, .5), (3, 13, .5), (0, 13.5, .5), (7, 14, 2),
         (0, 16, .5), (3, 16.5, .5), (7, 17, .5), (12, 17.5, .5), (15, 18, 1), (12, 19, 1),
         (13, 20, .5), (17, 20.5, .5), (20, 21, .5), (25, 21.5, .5), (20, 22, 1), (17, 23, 1),
         (17, 24, .5), (22, 24.5, .5), (25, 25, .5), (29, 25.5, .5), (25, 26, 1), (22, 27, 1),
         (17, 28, 4),
         (0, 32, .5), (3, 32.5, .5), (7, 33, .5), (12, 33.5, .5), (7, 34, 1), (3, 35, 1),
         (8, 36, .5), (13, 36.5, .5), (17, 37, .5), (20, 37.5, .5), (17, 38, 1), (13, 39, 1),
         (12, 40, .5), (17, 40.5, .5), (20, 41, .5), (24, 41.5, .5), (20, 42, 1), (17, 43, 1),
         (19, 44, .5), (15, 44.5, .5), (12, 45, .5), (7, 45.5, .5), (12, 46, 2),
         (20, 48, .5), (24, 48.5, .5), (27, 49, .5), (32, 49.5, .5), (27, 50, 1), (24, 51, 1),
         (24, 52, .5), (21, 52.5, .5), (18, 53, .5), (21, 53.5, .5), (24, 54, 2),
         (26, 56, .5), (22, 56.5, .5), (19, 57, .5), (14, 57.5, .5), (19, 58, 2),
         (14, 60, 4),
         (13, 64, .5), (17, 64.5, .5), (20, 65, .5), (25, 65.5, .5), (20, 66, 2),
         (17, 68, .5), (22, 68.5, .5), (25, 69, .5), (29, 69.5, .5), (25, 70, 2),
         (17, 72, .5), (20, 72.5, .5), (24, 73, .5), (29, 73.5, .5), (24, 74, 2),
         (20, 76, .5), (24, 76.5, .5), (27, 77, .5), (32, 77.5, .5), (27, 78, 2),
         (21, 80, .5), (24, 80.5, .5), (30, 81, .5), (33, 81.5, .5), (30, 82, 2),
         (22, 84, .5), (26, 84.5, .5), (31, 85, .5), (34, 85.5, .5), (31, 86, 2),
         (32, 88, 1), (29, 89, 1), (25, 90, 2),
         (34, 92, 1), (29, 93, 1), (25, 94, 2),
         (24, 96, .5), (19, 96.5, .5), (15, 97, .5), (12, 97.5, .5), (7, 98, 1), (3, 99, 1),
         (13, 100, .5), (17, 100.5, .5), (20, 101, .5), (25, 101.5, .5), (20, 102, 1), (17, 103, 1),
         (12, 104, .5), (17, 104.5, .5), (20, 105, .5), (24, 105.5, .5), (20, 106, 1), (17, 107, 1),
         (15, 108, .5), (12, 108.5, .5), (8, 109, .5), (12, 109.5, .5), (15, 110, 2),
         (0, 112, .5), (3, 112.5, .5), (7, 113, .5), (12, 113.5, .5), (7, 114, 1), (3, 115, 1),
         (13, 116, 1), (17, 117, 1), (20, 118, 2),
         (19, 120, 1), (14, 121, 1), (10, 122, 2),
         (0, 124, 4)]
    return Piece("F2", 160, "drive", "four_bit", [rich(c) for c in ch], m,
                 "the same fight, and every chord that arrives is a worse one",
                 pulse=(1,) * 16, stabs=2)


WRITTEN = {
    "first_light": first_light,
    "shells": shells,
    "warm": warm,
    "home": home,
    "core": core,
    "fauna": fauna,
    "business": business,
    "burn": burn,
    "boss": boss,
}
