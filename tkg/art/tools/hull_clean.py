# Clean a PixelLab hull take against its template: drop pixels outside the
# template's silhouette (grown a pixel), recolour lone rust, orange or blue
# specks on the white tile to the tile around them, and drop small islands.
# Dithering and the lit slots are left alone. Run from the folder of takes.

from PIL import Image, ImageFilter
from collections import Counter, deque
import colorsys
T='/home/user/ThreeKelvin/tkg/art/hull_templates/template_solari_%s.png'
def sat(c):
    return colorsys.rgb_to_hsv(c[0]/255,c[1]/255,c[2]/255)[1]
def clean(src, w, out):
    im=Image.open(src).convert('RGBA'); W,H=im.size
    keep=Image.open(T%w).convert('RGBA').getchannel('A').point(lambda v:255 if v else 0).filter(ImageFilter.MaxFilter(3))
    a=im.load(); k=keep.load(); st=Counter()
    for y in range(H):
        for x in range(W):
            if a[x,y][3] and not k[x,y]: a[x,y]=(0,0,0,0); st['outside']+=1
    # specks of a foreign colour on the white tile: a saturated pixel (rust,
    # orange, blue) whose neighbours are almost all pale tile
    for _ in range(3):
        b=im.copy(); bp=b.load()
        for y in range(1,H-1):
            for x in range(1,W-1):
                c=bp[x,y]
                if not c[3] or sat(c) < .28: continue
                n8=[bp[x+dx,y+dy] for dx in (-1,0,1) for dy in (-1,0,1) if dx or dy]
                tiles=[n for n in n8 if n[3] and sat(n) < .22]
                if len(tiles) >= 6:
                    a[x,y]=Counter(tiles).most_common(1)[0][0]; st['speck']+=1
    seen=set(); comps=[]
    for y in range(H):
        for x in range(W):
            if a[x,y][3] and (x,y) not in seen:
                q=deque([(x,y)]); seen.add((x,y)); c=[]
                while q:
                    p=q.popleft(); c.append(p)
                    for d in ((1,0),(-1,0),(0,1),(0,-1)):
                        n=(p[0]+d[0],p[1]+d[1])
                        if 0<=n[0]<W and 0<=n[1]<H and n not in seen and a[n][3]: seen.add(n); q.append(n)
                comps.append(c)
    comps.sort(key=len,reverse=True)
    for c in comps[1:]:
        if len(c)<60:
            for p in c: a[p]=(0,0,0,0)
            st['island']+=len(c)
    im.save(out); return dict(st)
for n,w in (('L1','light'),('M5','medium'),('H1','heavy')):
    print(n, clean(n+'.png', w, n+'.clean.png'))
