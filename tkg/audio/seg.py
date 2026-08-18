import numpy as np
t=np.load('t.npy'); f=np.load('f.npy'); r=np.load('r.npy')
thr=0.08*r.max()
on = r>thr
# find contiguous runs
segs=[]; i=0
while i<len(on):
    if on[i]:
        j=i
        while j<len(on) and on[j]: j+=1
        if (t[j-1]-t[i])>0.06: segs.append((i,j))
        i=j
    else: i+=1
names=['C','C#','D','D#','E','F','F#','G','G#','A','A#','B']
def note(fr):
    n=12*np.log2(fr/440.0)+69
    k=int(round(n)); cents=(n-k)*100
    return f"{names[k%12]}{k//12-1}", cents, 440.0*2**((k-69)/12)
print(f"{'#':>2} {'start':>6} {'end':>6} {'dur':>5} {'medHz':>8} {'note':>5} {'cents':>7} {'ideal':>8}")
for idx,(i,j) in enumerate(segs,1):
    # use middle 60% of segment, weight by rms
    a=i+int(0.2*(j-i)); b=j-int(0.2*(j-i))
    ff=f[a:b]; rr=r[a:b]
    med=np.median(ff)
    keep=np.abs(ff-med)<0.06*med
    val=np.average(ff[keep],weights=rr[keep])
    nm,c,ide=note(val)
    print(f"{idx:>2} {t[i]:6.3f} {t[j-1]:6.3f} {t[j-1]-t[i]:5.3f} {val:8.1f} {nm:>5} {c:+7.1f} {ide:8.1f}")
    print(f"    range {ff[keep].min():.1f}-{ff[keep].max():.1f} Hz, frames {(j-i)}")
