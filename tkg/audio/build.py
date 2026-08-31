"""Render every audio asset and encode it into the Godot project.

    python3 build.py               # music + sfx
    python3 build.py music
    python3 build.py music burn    # one cue only
    python3 build.py sfx

    python3 build.py music theme --sampled    # recorded instruments, synth kit
    python3 build.py music theme --drums      # ...and a recorded kit too
    python3 build.py music --lead=piano       # what plays the melody

Needs numpy, scipy and soundfile (libsndfile supplies the Vorbis encoder).

What lands where
----------------
    assets/audio/music/<cue>/<stem>.ogg   the layers the game actually plays --
                                          only the stems some rung of Audio.gd's
                                          CUES table can reach.  See UNSHIPPED.
    assets/audio/sfx/*.wav                short, uncompressed, zero decode cost
    audio/out/*.wav                       full-length concert masters, kept as
                                          the reference render.  Not shipped.
    audio/out/<cue>_mix.ogg               all layers summed, for anywhere that
                                          wants one file instead of nine.  Also
                                          not shipped -- nothing in the game
                                          loads it, and it was 20 MB of the
                                          export when it lived under assets/.

Two things differ between the concert master and what ships:

* **No fade-out.**  Shipped cues render with `--loop`, which drops the fade and
  wraps the reverb tail back over the head.  The fade was baked into the stems
  as well as the mix, so anything looped off the old files faded out mid-loop.
* **A 32 Hz bus high-pass.**  `drone()` adds a hardcoded sub-octave, so the F1
  pedal put its strongest partial at 21.8 Hz -- inaudible on a laptop, a phone
  or a TV, and still driving the limiter.  Removing it is free level.  The
  concert master keeps it.

Each cue renders in its own process.  Two reasons: a cue holds about a gigabyte
of float64 track buffers, and the scores rebind synth's tempo globals at import,
so importing both into one interpreter gives the second one the first one's bar
length.
"""
import os, sys, subprocess
import numpy as np
import soundfile as sf

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, 'out')
ASSETS = os.path.abspath(os.path.join(HERE, '..', 'assets', 'audio'))
SR = 44100
GAME_HP = 32           # bus high-pass for shipped renders, Hz
BLOCK = SR             # encode a second at a time -- see ogg()

## Stems the arrangement renders but no rung of the ladder can reach, so they
## are encoded to nothing and cost the download nothing.
##
## Audio.gd's CUES table is the authority on what the game can play; this is the
## complement of it, written out by hand because the authority is GDScript and
## parsing it from here would be worse than keeping two short lists honest.
## Getting it wrong is loud rather than silent: _ensure_loaded() push_warning()s
## on a stem the table asks for and the disk does not have.
##
##   theme/lead, theme/perc -- rungs 3 and 4, labelled "contact" and "combat".
##     Vestigial.  Combat moved to the `burn` cue and bosses to `boss`, so the
##     theme ladder now stops at rung 2 and these two are unreachable.  They are
##     still rendered: they are the melody and the kit of the concert master,
##     and the reference render is the composition, not the shipped subset.
##
## Not listed, and deliberately: dread/bowed, dread/metal and dread/cluster are
## also unreachable today (DEEP only ever enters `dread` at rung 2), but that is
## an unspent state rather than a superseded one -- DREAD_NOTES section 4 names
## all three.  They keep shipping until that call is made.
UNSHIPPED = {
    ('theme', 'lead'),
    ('theme', 'perc'),
}

CUES = [
    # (script, cue name, wav mix, wav stem dir)
    ('arrange.py', 'theme', 'theme_loop.wav', 'stems_loop'),
    ('dread.py',   'dread', 'dread_loop.wav', 'dread_stems_loop'),
    ('burn.py',    'burn',  'burn_loop.wav',  'burn_stems_loop'),
    ('warm.py',    'warm',  'warm_loop.wav',  'warm_stems_loop'),
    ('boss.py',    'boss',  'boss_loop.wav',  'boss_stems_loop'),
    ('shells.py',  'shells','shells_loop.wav','shells_stems_loop'),
    ('business.py','business','business_loop.wav','business_stems_loop'),
    ('home.py',    'home',  'home_loop.wav',  'home_stems_loop'),
    ('first_light.py', 'first_light', 'first_light_loop.wav',
     'first_light_stems_loop'),
    ('perpetuity.py', 'perpetuity', 'perpetuity_loop.wav',
     'perpetuity_stems_loop'),
    ('core.py',    'core',    'core_loop.wav',    'core_stems_loop'),
    ('fauna.py',   'fauna',   'fauna_loop.wav',   'fauna_stems_loop'),
    ('nofault.py', 'nofault', 'nofault_loop.wav', 'nofault_stems_loop'),
]

def ogg(path, wav_path, compression=0.3):
    """Encode a WAV to Ogg Vorbis.

    Written a block at a time on purpose.  libsndfile's Vorbis encoder sizes a
    stack buffer from the write length, so handing it a two-minute buffer in
    one call overflows the thread stack and segfaults inside
    _preextrapolate_helper.  A one-second block is nowhere near that limit.

    compression runs 0 = best quality / largest, 1 = worst / smallest; the
    libsndfile default is 0.4.  These stems are sparse and Vorbis codes them
    very efficiently, so buying quality back costs almost nothing.
    """
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with sf.SoundFile(wav_path) as src, \
         sf.SoundFile(path, 'w', src.samplerate, src.channels, format='OGG',
                      subtype='VORBIS', compression_level=compression) as dst:
        while True:
            block = src.read(BLOCK, dtype='float32')
            if not len(block):
                break
            dst.write(block)
    return os.path.getsize(path)

#: Set by --sampled/--drums and passed to every score subprocess.  It has to
#: travel as environment rather than as an argument, because a score binds its
#: instruments with `from synth import *` at import time -- long before its own
#: argument parser runs.  See sampler.py.
VOICES = {}

def render(script, *args):
    subprocess.run([sys.executable, script, '--out', OUT] + list(args),
                   cwd=HERE, check=True, env=dict(os.environ, **VOICES))

def build_music(only=()):
    """Render and encode every cue, or just the named ones.

    Renders are deterministic per machine but not across them, so a partial
    rebuild is only safe on the box that produced the masters -- otherwise
    the rebuilt cue and the untouched ones come from different noise
    realisations.  `python3 build.py music <cue>` exists for iterating on a
    new score without re-encoding 36 MB of finished ones.
    """
    total = 0
    todo = [c for c in CUES if not only or c[1] in only]
    missing = set(only) - {c[1] for c in CUES}
    if missing:
        raise SystemExit('unknown cue(s): %s (have: %s)' % (
            ' '.join(sorted(missing)), ' '.join(c[1] for c in CUES)))
    for script, cue, mix_wav, stem_dir in todo:
        render(script)                                        # concert master
        render(script, '--loop', '--hp', str(GAME_HP))        # shipped
        d = os.path.join(ASSETS, 'music', cue)
        # Beside the concert master, not under assets/.  Nothing in the game
        # loads the summed mix, so shipping one per cue was 20 MB of export for
        # a convenience only the render pipeline ever wants.
        ogg(os.path.join(OUT, cue + '_mix.ogg'), os.path.join(OUT, mix_wav))
        names, skipped = [], []
        for f in sorted(os.listdir(os.path.join(OUT, stem_dir))):
            if not f.endswith('.wav'):
                continue
            stem = f[:-4]
            if (cue, stem) in UNSHIPPED:
                skipped.append(stem)
                continue
            names.append(stem)
            total += ogg(os.path.join(d, stem + '.ogg'),
                         os.path.join(OUT, stem_dir, f))
        print('  %-6s %d stems: %s%s' % (cue, len(names), ' '.join(names),
              '   (unshipped: %s)' % ' '.join(skipped) if skipped else ''))
    print('music -> %.1f MB' % (total/1e6))

def build_sfx():
    # sfx2 is the shipping set -- the hybrid redesign (recorded material +
    # foley palette + tonal glue).  sfx.py v1 stays runnable as the pure
    # synthesis reference.  sfx2 plays recorded doors, so it needs voices.
    os.environ.setdefault('TK_VOICES', 'sampled')
    import sfx2 as sfxmod
    src = os.path.join(OUT, 'sfx')
    sfxmod.main(src)
    d = os.path.join(ASSETS, 'sfx')
    os.makedirs(d, exist_ok=True)
    n = size = 0
    for f in sorted(os.listdir(src)):
        if not f.endswith('.wav'):
            continue
        # SFX stay uncompressed: a UI click has to be instant, and the whole
        # set is smaller than a single music stem anyway.
        data = open(os.path.join(src, f), 'rb').read()
        open(os.path.join(d, f), 'wb').write(data)
        n += 1; size += len(data)
    print('sfx   %d files -> %.1f MB' % (n, size/1e6))

if __name__ == '__main__':
    argv = sys.argv[1:]
    # Recorded instruments instead of oscillators for the melodic stems, and
    # optionally for the kit as well.  Measured on `theme`: renders ~40%
    # FASTER (pluck() is a per-sample Python loop and resampling is not), and
    # the encoded stems came out 7% SMALLER, because a recorded flute has far
    # less above 8 kHz than three detuned saws and Vorbis charges for that.
    # audio/samples/ has to exist -- `python3 fetch_samples.py`.
    if '--sampled' in argv or '--drums' in argv or any(
            a.startswith('--lead=') for a in argv):
        VOICES['TK_VOICES'] = 'sampled+drums' if '--drums' in argv else 'sampled'
    for a in argv:                                  # --lead=piano, --lead=vibes
        if a.startswith('--lead='):
            VOICES['TK_LEAD'] = a.split('=', 1)[1]
    argv = [a for a in argv if not a.startswith('--')]
    what = argv[0] if argv else 'all'
    only = tuple(argv[1:])
    os.makedirs(ASSETS, exist_ok=True)
    if what in ('all', 'music'): build_music(only)
    if what in ('all', 'sfx'):   build_sfx()
    print('assets at %s' % ASSETS)
