"""Stable Audio Open: sound effects and loops.

The SFX sibling of the MusicGen stub rig.  Text prompt in, 44.1 kHz stereo
out, up to 47 s.  Trained for exactly what MusicGen failed at: one-shots,
foley, mechanical events, loops.  Never auto-plays anything.

    musicgen-env/bin/python gen_sfx.py "airlock door closing, heavy metal thunk" 4 out.wav
"""
import sys
import torch
import soundfile as sf
from diffusers import StableAudioPipeline

# torchsde's BrownianTree recurses forever on this torch/py3.13 pairing (it
# queries outside its own [t0,t1] and bisects to death).  The SDE sampler is
# structured gaussian noise; a plain gaussian is an equally valid sampler for
# this scheduler, so swap it in.
from diffusers.schedulers import scheduling_cosine_dpmsolver_multistep as _sch

class _PlainNoise:
    def __init__(self, x, sigma_min=None, sigma_max=None, seed=None, **kw):
        self.shape, self.dtype = x.shape, x.dtype
        self.device = x.device
        self.gen = torch.Generator('cpu').manual_seed(
            seed if isinstance(seed, int) else (seed[0] if seed else 0))
    def __call__(self, t0, t1):
        return torch.randn(self.shape, dtype=self.dtype,
                           generator=self.gen).to(self.device)

_sch.BrownianTreeNoiseSampler = _PlainNoise

def _cli():
    prompt, secs, out = sys.argv[1], float(sys.argv[2]), sys.argv[3]
    neg = sys.argv[4] if len(sys.argv) > 4 else "music, melody, low quality"
    pipe = StableAudioPipeline.from_pretrained(
        "stabilityai/stable-audio-open-1.0", torch_dtype=torch.float32)
    pipe = pipe.to("mps")
    gen = torch.Generator("cpu").manual_seed(1729)
    audio = pipe(prompt, negative_prompt=neg, num_inference_steps=100,
                 audio_end_in_s=secs, num_waveforms_per_prompt=1,
                 generator=gen).audios[0]
    sf.write(out, audio.T.float().cpu().numpy(), pipe.vae.sampling_rate)
    print("saved", out)


if __name__ == '__main__':
    _cli()
