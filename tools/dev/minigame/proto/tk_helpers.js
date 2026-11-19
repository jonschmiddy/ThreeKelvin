  shuffle(a,r){a=a.slice();for(let i=a.length-1;i>0;i--){const j=Math.floor(r()*(i+1));[a[i],a[j]]=[a[j],a[i]]}return a},
  pick(a,r){return a[Math.floor(r()*a.length)]},
  int(r,lo,hi){return lo+Math.floor(r()*(hi-lo+1))},
  // ---- pixel art: the game's own palette (tkg/scripts/ui/UITheme.gd) ----
  PAL:{void:'#0a0e15',panel:'#111823',line:'#22303f',bevelHi:'#3d4d61',bevelLo:'#080b11',cold:'#6b7d94',chill:'#8fa3ba',ice:'#c3d2e2',
    ember:'#d97b29',flare:'#ff9d3d',hot:'#ffd28a',good:'#7fb89a',warn:'#b8923f',bad:'#c8503c',mark:'#b8f5d8',tractor:'#4fe0cc',brace:'#9fb0c4',them:'#c98d7a',
    t0:'#98a0a8',t1:'#4fbf82',t2:'#6a9ad4',t3:'#8b4fd4',t4:'#d99b29'},
  // A low-res canvas scaled up by a whole number so every art pixel is a clean square.
  pixel(stage,o){o=o||{};const w=o.w||160,h=o.h||120;const cv=document.createElement('canvas');cv.width=w;cv.height=h;
    cv.style.cssText='display:block;margin:0 auto;image-rendering:pixelated;image-rendering:crisp-edges;touch-action:none;max-width:100%';
    const g=cv.getContext('2d');g.imageSmoothingEnabled=false;stage.appendChild(cv);
    const fit=()=>{const dpr=window.devicePixelRatio||1;const avail=Math.max(1,stage.clientWidth-4);const s=Math.max(1,Math.floor(avail*dpr/w));cv.style.width=(w*s/dpr)+'px';cv.style.height=(h*s/dpr)+'px';api.scale=s/dpr};
    const api={cv,g,w,h,scale:1,fit,
      pt(e){const r=cv.getBoundingClientRect();return{x:Math.floor((e.clientX-r.left)*w/r.width),y:Math.floor((e.clientY-r.top)*h/r.height)}},
      clear(c){g.fillStyle=c||TK.PAL.void;g.fillRect(0,0,w,h)}};
    fit();const ro=new ResizeObserver(fit);ro.observe(stage);api.destroy=()=>ro.disconnect();return api},
  // 3x5 pixel font, 4 px advance. Draws crisp text straight onto a TK.pixel canvas.
  text(g,s,x,y,col,align){s=String(s).toUpperCase();const adv=4,wpx=s.length*adv-1;if(align==='center')x-=Math.floor(wpx/2);else if(align==='right')x-=wpx;
    g.fillStyle=col||TK.PAL.ice;for(const ch of s){const gl=FONT[ch];if(gl){for(let r=0;r<5;r++)for(let c=0;c<3;c++)if(gl[r*3+c]==='#')g.fillRect(x+c,y+r,1,1)}x+=adv}return wpx},
  // Ordered 2x2 dither between two colours: t in 0..1 is how much of b.
  // Control icons, like a tutorial key prompt: what to press and how. 13 px tall pixel art.
  // kinds: 'click' 'hold' 'drag' 'drag-h' 'drag-v' 'dial' 'key' (opts.label, e.g. 'SPACE').
  // Returns the width drawn. Animated if you pass opts.t (seconds).
  icon(g,kind,x,y,o){o=o||{};const P=TK.PAL,t=o.t||0,on=(Math.floor(t*2)%2)===0;
    const px=(c,xx,yy,w=1,h=1)=>{g.fillStyle=c;g.fillRect(x+xx,y+yy,w,h)};
    const mouse=(btn)=>{const M=['...#####...','..#..#..#..','.#...#...#.','.#...#...#.','.#########.','.#.......#.','.#.......#.','.#.......#.','.#.......#.','..#.....#..','...#####...'];
      for(let r=0;r<M.length;r++)for(let c=0;c<11;c++)if(M[r][c]==='#')px(P.ice,c,r+1);
      for(let r=1;r<5;r++)for(let c=1;c<10;c++)if(M[r][c]==='.'&&r<4&&c>1&&c<5)px(btn?P.ember:P.line,c,r+1);
      for(let r=5;r<10;r++)for(let c=2;c<9;c++)if(M[r][c]==='.')px(P.panel,c,r+1)};
    if(kind==='click'){mouse(on);if(on){px(P.hot,0,0);px(P.hot,1,1);px(P.hot,12,0)}return 13}
    if(kind==='hold'){mouse(true);for(let i=0;i<4;i++)px(i<1+Math.floor((t*3)%4)?P.ember:P.line,13+i*2,10,1,2);return 21}
    if(kind==='drag'||kind==='drag-h'||kind==='drag-v'){mouse(true);const ax=14,ay=6;
      if(kind!=='drag-v'){px(P.hot,ax,ay,7,1);px(P.hot,ax+5,ay-1);px(P.hot,ax+5,ay+1);px(P.hot,ax+1,ay-1);px(P.hot,ax+1,ay+1)}
      if(kind==='drag-v'){px(P.hot,ax+3,ay-4,1,9);px(P.hot,ax+2,ay-3);px(P.hot,ax+4,ay-3);px(P.hot,ax+2,ay+3);px(P.hot,ax+4,ay+3)}
      if(kind==='drag'){px(P.hot,ax+3,ay-4,1,9)}return 22}
    if(kind==='dial'){const R=['..#####..','.#.....#.','#...#...#','#...#...#','#...#...#','#.......#','#.......#','.#.....#.','..#####..'];
      for(let r=0;r<9;r++)for(let c=0;c<9;c++)if(R[r][c]==='#')px(r>=1&&r<=4&&c===4?P.ember:P.ice,c,r+2);
      const a=on?[[10,2],[11,3],[11,4],[10,5]]:[[10,6],[11,7],[11,8],[10,9]];a.forEach(([xx,yy])=>px(P.hot,xx,yy));px(P.hot,9,on?2:9);return 13}
    if(kind==='keys'){// a keyboard cluster: label lists the keys, e.g. 'WAD' or 'WASD'; W sits above, A S D below
      const ks=String(o.label||'WASD').toUpperCase().split('');const cap=(ch,cx,cy,lit)=>{px(P.ice,cx,cy,9,1);px(P.ice,cx,cy+9,9,1);px(P.ice,cx,cy,1,10);px(P.ice,cx+8,cy,1,10);px(lit?P.line:P.panel,cx+1,cy+1,7,8);TK.text(g,ch,x+cx+3,y+cy+(lit?2:3),lit?P.hot:P.ice)};
      const lit=Math.floor(t*2)%ks.length;let i=0;
      for(const ch of ks){const top=(ch==='W'||ch==='UP');const col=ch==='A'?0:ch==='S'?1:ch==='D'?2:1;cap(ch,col*10,top?-9:1,i===lit);i++}
      return 30}
    if(kind==='key'){const lab=String(o.label||'SPACE').toUpperCase();const w=lab.length*4+5;
      px(P.ice,0,1,w,1);px(P.ice,0,11,w,1);px(P.ice,0,1,1,11);px(P.ice,w-1,1,1,11);px(on?P.line:P.panel,1,2,w-2,9);px(P.bevelLo,1,10,w-2,1);
      TK.text(g,lab,3,on?4:5,on?P.hot:P.ice);return w}
    return 0},
  dither(g,x,y,w,h,a,b,t){const M=[0,2,3,1];for(let j=0;j<h;j++)for(let i=0;i<w;i++){g.fillStyle=(M[((y+j)&1)*2+((x+i)&1)]+.5)/4<t?b:a;g.fillRect(x+i,y+j,1,1)}},
