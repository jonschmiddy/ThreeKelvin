"""The source motif, and every transformation the scores apply to it.

One whistled phrase is the entire soundtrack.  `analyze.py` -> `seg.py` ->
`refine.py` measured it at F6 G6 F6 G6 A♭6 -- scale degrees **1 2 1 2 ♭3** in
F minor, quarter notes at 142 BPM with a half note on the end.

Two properties of that phrase decide everything downstream:

* **It never touches the fifth.**  No dominant, no leading tone, no cadence.
  A question with no answer, which is what you want under a run that can end
  at any moment.  "Warm Ship" is the only cue that ever answers it.
* **Degrees 1, 2 and ♭3 belong to five different modes.**  So the melody is
  never rewritten; only the harmony under it changes.  Every derived form
  below alters at most one pitch.

A form is a list of `(pitch class, beat, duration in beats)`.  It carries no
octave and no tempo -- `octave()` fixes the register, and beats become seconds
only when a `Track` places them.  That is what lets one form serve a 142 BPM
combat cue and a 71 BPM dread cue unchanged.
"""

# ---------------- forms ----------------

## As whistled.  Whole tone rocking 1-2, then the lean up to ♭3.
MOTIF    = [('F', 0, 1), ('G',  1, 1), ('F', 2, 1), ('G',  3, 1), ('Ab', 4, 2)]

## 2 -> ♭2.  One flat turns F Aeolian into F Phrygian and a drifting whole
## tone into a stalking semitone.  The whole of "Dead Sector" is this edit.
PHRYGIAN = [('F', 0, 1), ('Gb', 1, 1), ('F', 2, 1), ('Gb', 3, 1), ('Ab', 4, 2)]

## Intervals mirrored.  The D natural forces Dorian -- minor, but adventurous
## rather than bleak, which is the cheapest mood change in the set.
INVERT   = [('F', 0, 1), ('Eb', 1, 1), ('F', 2, 1), ('Eb', 3, 1), ('D',  4, 2)]

## The last note dragged from ♭3 to ♭5.  Diabolus in musica, on the one note
## the motif uses to lift.
TRITONE  = [('F', 0, 1), ('Gb', 1, 1), ('F', 2, 1), ('Gb', 3, 1), ('B',  4, 2)]

## Doubled durations and a downward tail: ends a whole step *below* the tonic,
## so there is nowhere left to come back from.
SINK     = [('F', 0, 2), ('Gb', 2, 2), ('F', 4, 2), ('E',  6, 2), ('Eb', 8, 4)]

## The answer, poisoned.  The original whole tone the whole way -- nothing
## about the tune is wrong -- and then the fifth arrives a semitone flat.
## The boss is the only other place the motif resolves, and it resolves onto
## the tritone.
FALSE_ANSWER = [('F', 0, 1), ('G',  1, 1), ('F', 2, 1), ('G',  3, 1), ('Ab', 4, 1),
                ('B', 5, 3)]

## ♭3 raised to 3.  The exact counterpart to PHRYGIAN: that one flattens a
## note into the darkest mode available, this one sharpens a note into the
## major.  Two consequences, and the second was not designed in — it was
## found by asking which whole-tone collection each note belongs to:
##
##   * F G F G A♮ is 1 2 1 2 3.  The soundtrack has been minor since the
##     first bar of the game; this is the only form that is not.
##   * **F, G and A are all in the same whole-tone collection.**  The motif's
##     oscillation already lives entirely in WT1 and only the ♭3 crosses out
##     of it, so raising that one note makes the phrase wholly whole-tone.
##     One edit turns it major and turns it impressionist at the same time,
##     which is why "Five Ways Home" can pivot from its Mozart variations
##     into its Debussy one without a join.
MAGGIORE = [('F', 0, 1), ('G',  1, 1), ('F', 2, 1), ('G',  3, 1), ('A',  4, 2)]

## The answer the motif never gives itself: the same five notes, then the
## fifth it has avoided for the whole run.  Only "Warm Ship" states this.
ANSWER   = [('F', 0, 1), ('G',  1, 1), ('F', 2, 1), ('G',  3, 1), ('Ab', 4, 1),
            ('C', 5, 3)]

# ---------------- transformations ----------------

_PC = {'C': 0, 'C#': 1, 'Db': 1, 'D': 2, 'D#': 3, 'Eb': 3, 'E': 4, 'F': 5,
       'F#': 6, 'Gb': 6, 'G': 7, 'G#': 8, 'Ab': 8, 'A': 9, 'A#': 10, 'Bb': 10,
       'B': 11}
## Spelling for a transposed pitch.  Flats throughout: every key the game uses
## is a flat key, and G♭ next to F reads as the ♭2 it is.
_SPELL = ['C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B']


def bar(n):
    """Bar number, 1-based, -> absolute beat.  4/4 everywhere."""
    return (n - 1) * 4


def octave(seq, o):
    """Fix the register: pitch classes -> named pitches in octave `o`.

    Pitches that would fall outside the form's own span are not adjusted -- a
    form is written to sit inside one octave, so this stays a pure rename.
    """
    return [(n + str(o), b, d) for n, b, d in seq]


def augment(seq, k=2):
    """Stretch in time by `k`.  Same notes, weightless."""
    return [(n, b * k, d * k) for n, b, d in seq]


def diminish(seq, k=2):
    """Compress in time by `k`.

    At k=2 the five-note cell takes 2.5 beats instead of 5, so against 4/4 it
    starts on a different beat every repeat and only realigns after two bars.
    "Hard Burn" gets its rhythmic engine out of the motif this way rather than
    bolting a riff on beside it.
    """
    return [(n, b / k, d / k) for n, b, d in seq]


def transpose(seq, semitones):
    """Move the whole form by `semitones`, keeping it within one octave.

    Used once, for the boss cue's drop to E♭ minor.  Everything else recolours
    the motif by changing the harmony under it instead.
    """
    out = []
    for n, b, d in seq:
        out.append((_SPELL[(_PC[n] + semitones) % 12], b, d))
    return out


def retrograde(seq):
    """Play the form backwards, preserving the total span."""
    span = max(b + d for _, b, d in seq)
    return [(n, span - b - d, d) for n, b, d in reversed(seq)]


def pitches(seq, start, anchor=0):
    """Render a form to absolute pitch names, keeping every interval exactly.

    `start` names the pitch of `seq[anchor]`.  The default anchors the first
    note, which is what you want for a plain form -- but an ornamented form
    does not begin on its own first note.  `appoggiatura()` puts a grace note
    in front, so `pitches(ornamented, 'F5')` pins the *lean* to F5 and drags
    the entire melody down a step; the tune still has the right contour and is
    in the wrong key, which is a hard thing to spot in a table of note names.
    Pass `anchor=1` there, and the principal note lands where you meant.

    `octave()` names pitch classes and leaves the register to the caller,
    which is fine for a form written inside one octave in its home key.
    Transpose that form and the octave boundary moves under it:
    `transpose(MOTIF, 6)` is B D♭ B D♭ D, and naming those all in octave 5
    turns the motif's rising whole tone into a *falling major seventh*.  The
    contour — the only thing that makes the phrase recognisable — is lost.

    This walks the intervals instead.  Each step is taken as the nearest one
    consistent with the spelling, in (−6, +6]; every form in this file is
    written in small steps from its first note, so that reconstruction is
    exact for all of them.  Use it whenever a form is transposed; `octave()`
    stays correct and cheaper for a form in its home key.
    """
    offs, prev = [0], _PC[seq[0][0]]
    for n, _, _ in seq[1:]:
        pc = _PC[n]
        offs.append(offs[-1] + (pc - prev + 6) % 12 - 6)
        prev = pc
    base = _midi(start) - offs[anchor]
    return [(_name(base + o), b, d) for o, (_, b, d) in zip(offs, seq)]


def _midi(name):
    i = 2 if len(name) > 2 and name[1] in '#b' else 1
    return 12*(int(name[i:]) + 1) + _PC[name[:i]]


def _name(midi):
    return _SPELL[midi % 12] + str(midi//12 - 1)


def sequence(seq, steps, gap):
    """Restate the form at each transposition in `steps`, one entry every
    `gap` beats.

    The single most productive device in the set, and the one thing five
    cues of reharmonising a static F pedal could never do: it actually
    moves the key.  Mozart's circle-of-fifths sequence and Debussy's
    planing are the same operation with different step lists —
    `[0,-5,-10,-15,...]` walks the circle, `[0,2,4,6]` walks the whole-tone
    scale, `[0,3,6,9]` walks the diminished cycle and closes.

    Returns pitch classes, so the caller still chooses the register per
    entry.  A sequence that rises past B has to be given the octave it
    climbs into — `octave()` deliberately does not guess.
    """
    out = []
    for i, st in enumerate(steps):
        for n, b, d in transpose(seq, st):
            out.append((n, b + i*gap, d))
    return out


## Scales for the `scale=` argument below. Every key the soundtrack uses is a
## flat key, so these are spelled with flats throughout.
F_MINOR = ['F', 'G', 'Ab', 'Bb', 'C', 'Db', 'Eb']
F_MAJOR = ['F', 'G', 'A', 'Bb', 'C', 'D', 'E']


def _upper(n, semitones, scale):
    """The leaning note above `n`: the next degree of `scale` if one is given,
    otherwise a fixed interval."""
    base = _PC[n]
    if not scale:
        return _SPELL[(base + semitones) % 12]
    steps = [(_PC[x] - base) % 12 for x in scale if (_PC[x] - base) % 12]
    return _SPELL[(base + min(steps)) % 12] if steps else _SPELL[(base + semitones) % 12]


def appoggiatura(seq, semitones=1, frac=0.4, min_lean=0.1, scale=None):
    """Lean a dissonance onto every note and let it fall onto the note.

    Takes `frac` of each note's length for the leaning note, so the phrase
    keeps its rhythm exactly and only its surface changes.  This is the
    cheapest way to make a plain line sound composed rather than typed, and
    it is everywhere in Mozart.

    Pass a `scale` and the lean becomes the next degree *of that scale* above
    the note instead of a fixed interval.  That distinction is not pedantry.
    A fixed +1 semitone above F in F minor gives G♭, which is not in the key
    at all -- it is the Phrygian ♭2, which is to say it is "Dead Sector"'s
    note, and the first version of the ornamented variation put four of them
    into a Mozart pastiche.  The upper neighbour of F in F minor is G and of
    G is A♭, a whole step and a half step, so the interval is a property of
    where you stand in the key and cannot be a number.

    Raises if a lean would come out shorter than `min_lean` beats -- see
    turn() for why that guard is here.
    """
    out = []
    for n, b, d in seq:
        if d*frac < min_lean:
            raise ValueError(
                'appoggiatura: a %.3f-beat note leaves a %.4f-beat lean, under '
                'the %.2f-beat floor. Ornamenting an already-ornamented form is '
                'the usual cause.' % (d, d*frac, min_lean))
        out.append((_upper(n, semitones, scale), b, d*frac))
        out.append((n, b + d*frac, d*(1 - frac)))
    return out


def turn(seq, index, frac=0.5, up=2, down=-1, min_step=0.1):
    """Put a classical turn on one note: note, upper neighbour, note, lower
    neighbour, then the note holds whatever is left.

    `up`/`down` are in semitones because the neighbour is a property of the
    key, not of the form — the lower neighbour of F in F minor is E♮ and of
    A♭ is G, and those are different intervals.

    **`index` counts notes in the form you pass in, which is not the form you
    wrote if something has already expanded it.**  `appoggiatura()` doubles a
    form's length, so `turn(appoggiatura(MOTIF), 4)` lands on a grace note
    instead of on the ♭3 and then divides that grace note by four again.
    That shipped once: four 17 ms notes in a row, which `whistle()` renders as
    clicks because a 15 ms note cannot hold a 45 ms attack.  Hence `min_step`
    — a turn whose steps fall below it is a composition mistake and not a fast
    ornament, so this raises rather than rendering it.

    Ornament the tail separately and concatenate if you want both:

        appoggiatura(MOTIF[:4], 1, 0.34) + turn(MOTIF[4:], 0, frac=0.5)
    """
    step = seq[index][2]*frac/4.0
    if step < min_step:
        raise ValueError(
            'turn: note %d is %.3f beats, so each of the four steps would be '
            '%.4f beats, under the %.2f-beat floor. Check that `index` still '
            'points where you think it does.' % (index, seq[index][2], step, min_step))
    out = []
    for i, (n, b, d) in enumerate(seq):
        if i != index:
            out.append((n, b, d)); continue
        for k, off in enumerate((0, up, 0, down)):
            out.append((_SPELL[(_PC[n] + off) % 12], b + k*step, step))
        out.append((n, b + 4*step, d - 4*step))
    return out


## The two whole-tone collections, by pitch class.  The motif's F and G are
## both in WT1 and its A♭ is in WT0, so the phrase's one upward gesture is
## also the moment it changes collection.  "Nine Shells" is built on that.
WHOLE_TONE = {
    0: [0, 2, 4, 6, 8, 10],       # C  D  E  F♯ G♯ A♯
    1: [1, 3, 5, 7, 9, 11],       # D♭ E♭ F  G  A  B
}


def pentatonic(root, n=5):
    """Major pentatonic from `root`, as pitch classes.

    The exact complement to whole_tone() and the reason both are here.  A
    whole-tone scale is six equal steps and contains no perfect fifth at
    all, so it has no root and nothing in it can be consonant; a pentatonic
    scale is a stack of five perfect fifths and is almost nothing but
    consonance.  Alternating them is how Debussy actually writes -- the
    whole-tone passages in Voiles are episodes between pentatonic ones, not
    the substance of the piece -- and it is what keeps a rootless harmony
    from becoming a rootless hour.
    """
    r = _PC[root] if isinstance(root, str) else root
    return [_SPELL[(r + k) % 12] for k in (0, 2, 4, 7, 9)][:n]


def whole_tone(root, n=6, collection=None):
    """The whole-tone scale from `root` upward, as pitch classes.

    `collection` is inferred from the root when not given — there are only
    two, and every note decides which one it is in.
    """
    r = _PC[root] if isinstance(root, str) else root
    if collection is None:
        collection = r % 2
    pcs = WHOLE_TONE[collection]
    i = pcs.index(r % 12)
    return [_SPELL[pcs[(i + k) % 6]] for k in range(n)]
