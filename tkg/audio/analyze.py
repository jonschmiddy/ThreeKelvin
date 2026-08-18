import numpy as np, scipy.io.wavfile as wav
sr, x = wav.read('rec.wav')
x = x.astype(np.float64)/32768.0
N = len(x); print(f"dur {N/sr:.2f}s sr {sr}")

win = 4096; hop = 512
w = np.hanning(win)
times, freqs, rms = [], [], []
for i in range(0, N-win, hop):
    seg = x[i:i+win]
    e = np.sqrt(np.mean(seg**2))
    S = np.abs(np.fft.rfft(seg*w))
    f = np.fft.rfftfreq(win, 1/sr)
    lo = np.searchsorted(f, 400); hi = np.searchsorted(f, 5000)
    k = lo + np.argmax(S[lo:hi])
    # parabolic interp
    a,b,c = np.log(S[k-1]+1e-12), np.log(S[k]+1e-12), np.log(S[k+1]+1e-12)
    d = 0.5*(a-c)/(a-2*b+c+1e-12)
    fr = (k+d)*sr/win
    times.append(i/sr); freqs.append(fr); rms.append(e)
times=np.array(times); freqs=np.array(freqs); rms=np.array(rms)
thr = 0.08*rms.max()
print("rms max", rms.max(), "thr", thr)
np.save('t.npy',times); np.save('f.npy',freqs); np.save('r.npy',rms)
for t,f,r in zip(times,freqs,rms):
    print(f"{t:6.3f} {f:8.1f} {r:.4f} {'*' if r>thr else ''}")
