"""Render every audio asset and encode it into the Godot project.

    python3 build.py           # music + sfx
    python3 build.py music
    python3 build.py sfx

Needs numpy, scipy and soundfile (libsndfile supplies the Vorbis encoder).

What lands where
----------------
    assets/audio/music/<cue>/<stem>.ogg   the layers the game actually plays
    assets/audio/music/<cue>/mix.ogg      all layers summed, for anywhere that
                                          wants one file instead of nine
    assets/audio/sfx/*.wav                short, uncompressed, zero decode cost
    audio/out/*.wav                       full-length concert masters, kept as
                                          the reference render.  Not shipped.

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

CUES = [
    # (script, cue name, wav mix, wav stem dir)
    ('arrange.py', 'theme', 'theme_loop.wav', 'stems_loop'),
    ('dread.py',   'dread', 'dread_loop.wav', 'dread_stems_loop'),
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

def render(script, *args):
    subprocess.run([sys.executable, script, '--out', OUT] + list(args),
                   cwd=HERE, check=True)

def build_music():
    total = 0
    for script, cue, mix_wav, stem_dir in CUES:
        render(script)                                        # concert master
        render(script, '--loop', '--hp', str(GAME_HP))        # shipped
        d = os.path.join(ASSETS, 'music', cue)
        total += ogg(os.path.join(d, 'mix.ogg'), os.path.join(OUT, mix_wav))
        names = []
        for f in sorted(os.listdir(os.path.join(OUT, stem_dir))):
            if f.endswith('.wav'):
                names.append(f[:-4])
                total += ogg(os.path.join(d, f[:-4] + '.ogg'),
                             os.path.join(OUT, stem_dir, f))
        print('  %-6s %d stems: %s' % (cue, len(names), ' '.join(names)))
    print('music -> %.1f MB' % (total/1e6))

def build_sfx():
    import sfx as sfxmod
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
    what = sys.argv[1] if len(sys.argv) > 1 else 'all'
    os.makedirs(ASSETS, exist_ok=True)
    if what in ('all', 'music'): build_music()
    if what in ('all', 'sfx'):   build_sfx()
    print('assets at %s' % ASSETS)
