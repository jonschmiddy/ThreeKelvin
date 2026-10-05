extends RefCounted

## A SYSTEM'S OWN SHORT PALETTE, for `map_palette.gdshader` (Jon picked the
## strongest take, then "even more pixelated"). Found once per system from its
## own first picture, so its colours stay true:
##   * about sixteen colours, split again and again where the picture's
##     colours spread widest (a median cut, weighted by how much of the
##     picture each colour covers);
##   * a few more from round the star, so a small bright star is not averaged
##     away into the sky;
##   * every other colour of the star painter's own palette, so a sun keeps
##     the colours it was painted in (a cut alone turned the sun cream);
##   * the void.
## A fixed palette was tried first: it turned the sun green and filled dark
## sky with grids of dots.

const K := 16
## and for a system inside a nebula, whose sky is the cloud seen from inside
## (`sky_nebula.gdshader`): at sixteen its teals and roses fell between too few
## colours and dithered into blue checks
const K_NEBULA := 24

## The star painters' own colours (the mockup's `PALHEX`s).
const SUN_PALETTE := [
	"#05060a", "#0b1220", "#33445a", "#c9d8ea", "#ffffff",
	"#1e0804", "#3a0e08", "#5e1608", "#84280c", "#a83a10", "#c24a14", "#e06a20", "#ec7a26", "#f89a3a", "#ffb054", "#ffd070", "#ffdc96", "#ffeec0", "#fff6e2",
	"#2a0608", "#4a0c0c", "#6e1410", "#962018", "#bc3220", "#d84a2a", "#ee6a3a", "#ff8a50",
	"#6a1a34", "#a0284a", "#d84a6a", "#ff7a8a",
	"#0a1030", "#102060", "#1a3a8a", "#2a5ab8", "#4a8ad8", "#8ad0f0", "#c8f0ff", "#e6f6ff", "#3478a0", "#4fa6c4",
	"#2a1810", "#4a2a18", "#6a3e22",
]
const PULSAR_PALETTE := [
	"#05060a", "#0b1220", "#12203a", "#1a3456", "#244f7a", "#3478a0", "#4fa6c4", "#7fd0e0", "#b8ecf4", "#eafcff", "#ffffff",
	"#33445a", "#c9d8ea", "#a0e4ee", "#60bcd4",
	"#0a1030", "#102060", "#1a3a8a", "#2a5ab8", "#4a8ad8", "#8ad0f0", "#c8f0ff",
	"#1a1030", "#2e1c52", "#4a3080", "#7a5ab4", "#1c1640", "#2c2466", "#463a94", "#6c5cc4",
]


## The median cut of `img`'s pixels inside `box` (x0, y0, x1, y1), into k colours.
static func median_cut(img: Image, k: int, box: Rect2i) -> PackedVector3Array:
	var hist := PackedInt32Array()
	hist.resize(32768)
	var x1 := mini(box.end.x, img.get_width())
	var y1 := mini(box.end.y, img.get_height())
	var data := img.get_data()
	var w := img.get_width()
	var bpp := 4 if img.get_format() == Image.FORMAT_RGBA8 else 3
	for y in range(maxi(0, box.position.y), y1):
		for x in range(maxi(0, box.position.x), x1, 2):
			var o := (y * w + x) * bpp
			hist[((data[o] >> 3) << 10) | ((data[o + 1] >> 3) << 5) | (data[o + 2] >> 3)] += 1
	var bins: Array = []
	for i in 32768:
		if hist[i] > 0:
			bins.append([((i >> 10) & 31) * 8 + 4, ((i >> 5) & 31) * 8 + 4, (i & 31) * 8 + 4, hist[i]])
	var boxes: Array = [bins]
	while boxes.size() < k:
		var bi := -1
		var bw := 0.0
		var ba := 0
		for i in boxes.size():
			var b: Array = boxes[i]
			if b.size() < 2:
				continue
			var lo := [255, 255, 255]
			var hi := [0, 0, 0]
			var n := 0
			for p in b:
				for a in 3:
					lo[a] = mini(lo[a], p[a])
					hi[a] = maxi(hi[a], p[a])
				n += p[3]
			var ax := [hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2]]
			var axis := ax.find(ax.max())
			var wgt := float(ax[axis]) * sqrt(float(n))
			if wgt > bw:
				bw = wgt
				bi = i
				ba = axis
		if bi < 0:
			break
		var b2: Array = boxes[bi]
		b2.sort_custom(func(p, q): return p[ba] < q[ba])
		var tot := 0
		for p in b2:
			tot += p[3]
		var acc := 0
		var cut := 1
		for i in b2.size() - 1:
			acc += b2[i][3]
			if acc >= tot / 2:
				cut = i + 1
				break
		boxes.remove_at(bi)
		boxes.insert(bi, b2.slice(cut))
		boxes.insert(bi, b2.slice(0, cut))
	var out := PackedVector3Array()
	for b in boxes:
		var r := 0.0
		var g := 0.0
		var bl := 0.0
		var n := 0.0
		for p in b:
			r += p[0] * p[3]
			g += p[1] * p[3]
			bl += p[2] * p[3]
			n += p[3]
		if n > 0.0:
			out.append(Vector3(r / n, g / n, bl / n) / 255.0)
	return out


## The palette for one system's picture `img`, its star at `star_at` with
## radius `star_r`, of `kind` ("ORDINARY", "RED", "BLUE", "PULSAR", "CORE").
## `y0`: the first row the map shows; above it is the HUD, not the system.
static func build(img: Image, x0: int, star_at: Vector2, star_r: float, kind: String, y0: int = 0, k: int = K) -> PackedVector3Array:
	if img.get_format() != Image.FORMAT_RGBA8 and img.get_format() != Image.FORMAT_RGB8:
		img.convert(Image.FORMAT_RGBA8)
	var pal := median_cut(img, k, Rect2i(x0, y0, img.get_width() - x0, img.get_height() - y0))
	var sr := maxf(40.0, star_r * 3.2)
	pal.append_array(median_cut(img, maxi(6, K >> 2), Rect2i(int(star_at.x - sr), int(star_at.y - sr), int(sr * 2), int(sr * 2))))
	var own: Array = PULSAR_PALETTE if kind == "PULSAR" else ([] if kind == "CORE" else SUN_PALETTE)
	for i in own.size():
		if i % 2 == 1:
			continue
		var c := Color(own[i])
		pal.append(Vector3(c.r, c.g, c.b))
	pal.append(Vector3(7, 10, 18) / 255.0)
	return pal
