extends Node2D

## The comet on LOCAL's band (`CometPath`), where the map has it at the clock LOCAL holds:
## the map's head, coma and two tails in 2x2 blocks, at the band's scale.
## Why: docs/why/LocalComet.md#on-the-band

## the sky it is drawn in (`LocalSky`)
var sky
## The tails at least this long on the band, in blocks: the band's scale left them specks.
const ION_MIN := 10
const ION := [Color("#c8f0ff"), Color("#8ad0f0"), Color("#4a8ad8"), Color("#2a5ab8")]
const DUST := [Color("#ffdc96"), Color("#ffb054"), Color("#84280c")]


func _blk(p: Vector2, c: Color) -> void:
	draw_rect(Rect2((p / 2.0).floor() * 2.0, Vector2(2, 2)), c)


## Plane point p (from star A as LOCAL left the pair) on the band's screen.
func _on_band(p: Vector2) -> Vector2:
	return sky._zp(sky.band_origin() + Vector2(p.x, p.y * sky.TILT) * sky._s, sky.Z_BAND)


## Where the head is drawn, or INF while it is not in the system.
func head() -> Vector2:
	var L: SystemLayout = sky.layout if sky != null else null
	if L == null or L.comet == null or not L.comet.here(sky._tm):
		return Vector2.INF
	return (_on_band(sky._rel(L.comet.pos(L, sky._tm))) / 2.0).round() * 2.0


func _draw() -> void:
	var hs := head()
	if hs == Vector2.INF:
		return
	var L: SystemLayout = sky.layout
	var c: CometPath = L.comet
	var tm: float = sky._tm
	var a := c.age(tm)
	var p: Vector2 = sky._rel(c.pos(L, tm))
	var r := maxf(c.rel(a).length(), 1.0)
	var A := clampf(pow(2.5 * c.q / r, 2.0), 0.0, 1.0)
	var fade := clampf(a / 5.0, 0.0, 1.0) * clampf((c.T - a) / 5.0, 0.0, 1.0)
	var sun: Vector2 = _on_band(sky._rel(L.star_pos(-1, tm)))
	var away := hs - sun
	if away.length() < 0.5:
		away = Vector2.RIGHT
	var ang := roundf(atan2(away.y, away.x) / deg_to_rad(2.0)) * deg_to_rad(2.0)
	var ad := Vector2(cos(ang), sin(ang))
	# behind the star, where its disc covers the head, nothing shows
	var sr: float = float(L.star_r) * sky.star_k_of(-1) * sky._zl(sky.Z_STAR)
	var behind := p.y < 0.0 and sky.star != null
	var so: Vector2 = sky.star.position if sky.star != null else sun
	# the ion tail: straight, blue, thin
	var n_ion := maxi(ION_MIN, int((16.0 + 14.0 * A) * A))
	for k in range(1, n_ion + 1):
		var si := mini(3, int(floor(float(k - 1) / maxf(1.0, float(n_ion) / 4.0))))
		var q := hs + ad * 2.0 * float(k)
		if behind and q.distance_to(so) < sr:
			continue
		_blk(q, Color(ION[si], 0.5 * fade * maxf(A, 0.35)))
	# the dust tail: where the dust it shed is now, pushed off the light
	var last := Vector2.INF
	var head_a := atan2(c.rel(a).y, c.rel(a).x)
	for j in range(1, 13):
		var tau := 0.5 * float(j)
		if a - tau < 0.0:
			break
		var pj := c.rel(a - tau)
		if absf(wrapf(atan2(pj.y, pj.x) - head_a, -PI, PI)) > 0.7:
			break
		pj += pj.normalized() * 1.3 * maxf(A, 0.35) / maxf(sky._s, 0.05) * tau * tau
		pj += L.star_pos(-1, tm - tau) - sky._a0
		var sj := _on_band(pj)
		# (stretched to the ion tail's length: on the flat band it fell under the head)
		sj = hs + (sj - hs) * 2.0
		if sj.distance_to(last) < 2.0:
			continue
		last = sj
		if behind and sj.distance_to(so) < sr:
			continue
		var col: Color = DUST[mini(2, (j - 1) / 4)]
		var al := 0.5 * maxf(A, 0.35) * fade * (1.0 - float(j) / 14.0)
		_blk(sj, Color(col, al))
		if j > 6:
			_blk(sj + ad.orthogonal() * 2.0, Color(col, al * 0.7))
	if behind and hs.distance_to(so) < sr:
		return
	# the coma, a soft plus, and the head
	for bx in range(-2, 3):
		for by in range(-2, 3):
			var dd := Vector2(bx, by).length()
			if dd < 0.5 or dd > 2.3:
				continue
			var qb := hs + Vector2(bx, by) * 2.0
			if dd > 1.2 and int(floor(qb.x / 2.0) + floor(qb.y / 2.0)) % 2 != 0:
				continue
			_blk(qb, Color(Color("#e6f6ff"), (0.55 if dd < 1.2 else 0.3) * maxf(A, 0.4) * fade))
	_blk(hs, Color(Color("#fff6e2"), 0.95 * fade))
