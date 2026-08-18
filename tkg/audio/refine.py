import numpy as np, scipy.io.wavfile as wav
sr,x=wav.read('rec.wav'); x=x.astype(float)/32768
names=['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
def nm(fr):
    n=12*np.log2(fr/440)+69; k=int(round(n)); return f"{names[k%12]}{k//12-1}", (n-k)*100, 440*2**((k-69)/12)
segs=[(0.96,1.25),(1.40,1.65),(1.79,2.04),(2.22,2.47),(2.64,3.19)]
t=np.load('t.npy'); f=np.load('f.npy'); r=np.load('r.npy')
print(f"{'#':>2} {'start':>6} {'dur':>5} {'Hz':>7} {'note':>5} {'cents':>6} {'ideal':>7} {'min':>6} {'max':>6}")
for i,(a,b) in enumerate(segs,1):
    m=(t>=a)&(t<=b)
    ff=f[m]; rr=r[m]
    val=np.average(ff,weights=rr)
    n,c,ide=nm(val)
    print(f"{i:>2} {a:6.2f} {b-a:5.2f} {val:7.1f} {n:>5} {c:+6.1f} {ide:7.1f} {ff.min():6.1f} {ff.max():6.1f}")
# intervals
vals=[np.average(f[(t>=a)&(t<=b)],weights=r[(t>=a)&(t<=b)]) for a,b in segs]
print("\nintervals (semitones from note1):", [round(12*np.log2(v/vals[0]),2) for v in vals])
