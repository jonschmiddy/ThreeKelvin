"""Ears: ask MOSS-Music (OpenMOSS, Apache-2.0) about a render.

The one channel the rest of the toolbox does not have.  score_sheet.py shows
what was WRITTEN, the spectrum lanes show what was RENDERED, mastering.py
measures how LOUD -- this answers what it SOUNDS LIKE: instruments heard,
structure, performance quality, anything you can put in a question.

    listener-env/bin/python listen.py out_rock/burn.wav "What instruments do you hear?"
    listener-env/bin/python listen.py CLIP.wav --start 40 --dur 20 "Describe the guitar."

Runs on Apple GPU (MPS).  Model load is ~1 min; the answer is one opinion,
not a measurement -- treat it like a session musician in the next room.
"""
import argparse
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
WEIGHTS = {'instruct': 'MOSS-Music-8B-Instruct',
           'thinking': 'MOSS-Music-8B-Thinking'}


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('audio')
    ap.add_argument('prompt')
    ap.add_argument('--start', type=float, default=0.0, help='seconds')
    ap.add_argument('--dur', type=float, default=None, help='seconds')
    ap.add_argument('--max-tokens', type=int, default=768)
    ap.add_argument('--model', choices=('instruct', 'thinking'),
                    default='instruct')
    ap.add_argument('--greedy', action='store_true',
                    help='deterministic decoding: same audio + prompt -> same '
                         'answer.  Required in refinement loops, where a '
                         'changed description must mean the MUSIC changed.')
    a = ap.parse_args()
    W = os.path.join(HERE, 'weights', WEIGHTS[a.model])

    import torch
    sys.path.insert(0, os.path.join(HERE, 'MOSS-Music'))
    import librosa
    from src.modeling_moss_music import MossMusicModel
    from src.processing_moss_music import MossMusicProcessor

    t0 = time.time()
    device = 'mps' if torch.backends.mps.is_available() else 'cpu'
    model = MossMusicModel.from_pretrained(
        W, trust_remote_code=True, torch_dtype=torch.bfloat16,
        device_map=device)
    model.eval()
    processor = MossMusicProcessor.from_pretrained(
        W, trust_remote_code=True, enable_time_marker=True)
    print('[load %.0fs, %s]' % (time.time() - t0, device), file=sys.stderr)

    audio, _ = librosa.load(a.audio, sr=processor.config.mel_sr, mono=True,
                            offset=a.start, duration=a.dur)

    inputs = processor(text=a.prompt, audios=[audio], return_tensors='pt')
    inputs = inputs.to(model.device)
    if inputs.get('audio_data') is not None:
        inputs['audio_data'] = inputs['audio_data'].to(model.dtype)
    inputs['audio_input_mask'] = inputs['input_ids'] == processor.audio_token_id

    t0 = time.time()
    mt = a.max_tokens if a.model == 'instruct' else max(a.max_tokens, 2048)
    gen = dict(max_new_tokens=mt, num_beams=1, use_cache=True)
    if a.greedy and a.model == 'instruct':
        gen['do_sample'] = False
    else:
        # The thinking model repetition-spirals under pure greedy decoding
        # (a known reasoning-model failure), so --greedy there means a
        # FIXED SEED over sampling: deterministic on this machine, still
        # stochastic decoding.
        if a.greedy:
            torch.manual_seed(1729)
        gen.update(do_sample=True, temperature=0.8, top_p=0.8, top_k=50,
                   repetition_penalty=1.05)
    with torch.no_grad():
        out = model.generate(**inputs, **gen)
    n = inputs['input_ids'].shape[1]
    text = processor.decode(out[0, n:], skip_special_tokens=True)
    print('[gen %.0fs, %d tokens]' % (time.time() - t0, out.shape[1] - n),
          file=sys.stderr)
    print(text)


if __name__ == '__main__':
    main()
