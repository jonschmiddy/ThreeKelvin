"""Fetch the CC0 sample libraries the sampled instruments play.

Two public-domain libraries, both Versilian Studios, both CC0 1.0 -- no
attribution required, commercial use fine, no royalties:

    VSCO-2 CE   github.com/sgossner/VSCO-2-CE    orchestral: strings, winds,
                harp, glockenspiel
    VCSL        github.com/sgossner/VCSL         everything else: ocarina,
                folk harp, mallets, drums

Between them they are about 8 GB and we want well under a gigabyte, so both
are partial clones (`--filter=blob:none`) with a sparse checkout: git fetches
the tree, we name the instrument directories, and only those blobs come down.
Adding an instrument here costs its own size and nothing else.

    python3 fetch_samples.py            # fetch what the scores use
    python3 fetch_samples.py --list     # print the manifest, download nothing

Lands in `audio/samples/`, gitignored.  These are build inputs and never ship:
the game loads the rendered stems in `assets/audio/` and has no idea a sample
was involved.
"""
import os, subprocess, sys, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, 'samples')

# (repo, local dir, [instrument directories]).  The comment on each is the
# stem it plays -- see sampler.py's PATCHES table for the actual mapping.
# Karoryfer libraries: whole repos, shallow -- they are sample libraries by
# construction (SFZ + wav), CC0-1.0 per their GitHub license field, with the
# two things VCSL/VSCO mostly lack: ROUND ROBINS and real velocity layers.
KARORYFER = [
    ('https://github.com/sfzinstruments/karoryfer-bigcat.cello.git', 'cello'),
    ('https://github.com/sfzinstruments/karoryfer.meatbass.git', 'meatbass'),
]

LIBS = [
    ('https://github.com/sgossner/VSCO-2-CE.git', 'vsco2', [
        'Woodwinds/Piccolo',
        'Brass/Trumpet',            # whistle stem: the F6 register
        'Woodwinds/Flute',              # lead stem: the F5 register
        'Strings/Violin Section',       # pad, upper voices
        'Strings/Viola Section',        # pad, inner voices
        'Strings/Cello Section',        # pad, lower voices
        'Strings/Harp',                 # arp stem
        'Percussion/Glock',             # bell stem
        'Strings/Solo Contrabass',      # sub and the low bowed voices
        # Keys/Upright Piano is NOT here.  It is a fine instrument and it is
        # in the same library, but its samples are named Player_dyn1_rr1_042
        # and the pitch lives in a MappingChart.txt beside them -- so it needs
        # a loader of its own, and `Grand Piano, Kawai` in VCSL is named the
        # way everything else is.  Worth revisiting if an upright is wanted.
    ]),
    ('https://github.com/sgossner/VCSL.git', 'vcsl', [
        'Aerophones/Edge-blown Aerophones/Ocarina, Typical',
        'Idiophones/Struck Idiophones/Glockenspiel',
        'Idiophones/Struck Idiophones/Vibraphone',
        'Chordophones/Composite Chordophones/Folk Harp',
        'Membranophones/Struck Membranophones/Bass Drum 2',
        'Membranophones/Struck Membranophones/Snare Drum, Modern 1',
        'Idiophones/Struck Idiophones/Hi-Hat Cymbal',
        'Chordophones/Zithers/Grand Piano, Kawai',       # lead=piano
        # The space-y set.  A flute is a body blowing air and it sounds like
        # one; these three are struck or rubbed objects with inharmonic
        # partials and no attack to speak of, which is most of what "space"
        # means as a timbre.
        'Idiophones/Friction Idiophones/Wine Glasses',   # lead=glass
        'Idiophones/Struck Idiophones/Hand Chimes',      # lead=chimes
        'Idiophones/Struck Idiophones/Tubular Bells 1',
        # Two organs, for "Perpetuity".  The pipe organ ships separate PEDAL
        # and manual divisions and a loud/quiet pair, which is a real
        # two-manual-and-pedal instrument; the renaissance organ ships 4',
        # 8' and Full, which is registration already done for you.
        'Aerophones/Edge-blown Aerophones/Pipe Organ',
        'Aerophones/Edge-blown Aerophones/Renaissance Organ',
        # The texture set, for the full cutover: every voice that was still
        # an oscillator gets a recording.
        'Idiophones/Struck Idiophones/Suspended Cymbal 1',   # metal, swells
        'Idiophones/Struck Idiophones/Gong 1',               # impact
        'Membranophones/Other Membranophones/Ocean Drum',    # air
    ]),
]


def run(args, cwd=None):
    if subprocess.run(args, cwd=cwd).returncode:
        sys.exit("failed: " + ' '.join(args))


def fetch_sfz(url, name, branch='sfz'):
    """Fetch just the .sfz mapping files from a library's sfz branch.

    These are the library's own statement of what each sample sounds like --
    `pitch_keycenter` and `tune` per region -- and they are authoritative
    where the filename is not.  VCSL's wine glasses are the case that proved
    it: named glass1_D#4 and mapped to key 75 with tune=-28, which is D#5
    less 28 cents, and agrees with a direct FFT measurement to 1 cent.  Text
    files, a few hundred KB for the lot.
    """
    dest = os.path.join(ROOT, name)
    if not os.path.isdir(os.path.join(dest, '.git')):
        shutil.rmtree(dest, ignore_errors=True)
        print("-- cloning %s (%s branch, mappings only)" % (name, branch))
        run(['git', 'clone', '--filter=blob:none', '--no-checkout',
             '--depth', '1', '-b', branch, url, dest])
        run(['git', 'sparse-checkout', 'init', '--no-cone'], cwd=dest)
    run(['git', 'sparse-checkout', 'set', '--no-cone', '/*.sfz', '/**/*.sfz'],
        cwd=dest)
    run(['git', 'checkout'], cwd=dest)


def fetch(url, name, dirs):
    dest = os.path.join(ROOT, name)
    if not os.path.isdir(os.path.join(dest, '.git')):
        shutil.rmtree(dest, ignore_errors=True)
        print("-- cloning %s (tree only)" % name)
        run(['git', 'clone', '--filter=blob:none', '--no-checkout',
             '--depth', '1', url, dest])
        run(['git', 'sparse-checkout', 'init', '--cone'], cwd=dest)
    print("-- %s: %d instruments" % (name, len(dirs)))
    run(['git', 'sparse-checkout', 'set'] + dirs, cwd=dest)
    run(['git', 'checkout'], cwd=dest)


def size(path):
    n = 0
    for d, _, fs in os.walk(path):
        if '.git' in d.split(os.sep):
            continue
        n += sum(os.path.getsize(os.path.join(d, f)) for f in fs)
    return n


if __name__ == '__main__':
    if '--list' in sys.argv:
        for url, name, dirs in LIBS:
            print("\n%s  %s" % (name, url))
            for d in dirs:
                print("    " + d)
        sys.exit()
    os.makedirs(ROOT, exist_ok=True)
    for url, name, dirs in LIBS:
        fetch(url, name, dirs)
    fetch_sfz('https://github.com/sgossner/VCSL.git', 'vcsl-sfz')
    for url, name in KARORYFER:
        dest = os.path.join(ROOT, name)
        if not os.path.isdir(os.path.join(dest, '.git')):
            print("-- cloning %s (shallow)" % name)
            run(['git', 'clone', '--depth', '1', url, dest])
    print("\nsamples/ = %.0f MB of CC0 audio, gitignored"
          % (sum(size(os.path.join(ROOT, n)) for _, n, _ in LIBS) / 1e6))
