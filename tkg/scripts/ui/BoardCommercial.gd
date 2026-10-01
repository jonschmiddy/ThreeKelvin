class_name BoardCommercial
extends RefCounted
## LITTLE ANIMATED COMMERCIALS for the marketplace screen's ad slot (Jon: "Maybe
## even a little animated commercial ad?"). Every third turn of the slot plays
## one of these in place of a still ad: a few seconds of a scene, the words
## arriving on cue, and a video's progress bar along its foot.
##
## Each is drawn in the slot's box, (0, 0) to `sz` (about 107x170), at `t`
## seconds into it, 0 to LENGTH. Everything lands on whole pixels, so nothing
## smears; the Silkscreen font only at 8 and 16, about 6 and 12 pixels a letter.

const LENGTH := 6.0

const NAMES := ["HULL WAX", "STAR TAXI", "NOODLES", "ADOPT A DRONE", "COOLANT", "LUCKY SPIN"]


static func count() -> int:
	return NAMES.size()


## 0 before `a`, 1 after `b`, a straight line between.
static func _at(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func _ease(u: float) -> float:
	return 1.0 - pow(1.0 - u, 3.0)


static func draw(b: PostingBoard, sz: Vector2, i: int, t: float) -> void:
	b.draw_rect(Rect2(Vector2.ZERO, sz), Color("#000000"))
	match i % count():
		0:
			_hull_wax(b, sz, t)
		1:
			_star_taxi(b, sz, t)
		2:
			_noodles(b, sz, t)
		3:
			_drone(b, sz, t)
		4:
			_coolant(b, sz, t)
		_:
			_lucky_spin(b, sz, t)
	# a video's progress bar, and the AD mark
	b.draw_rect(Rect2(0.0, sz.y - 3.0, sz.x, 3.0), Color(0, 0, 0, 0.6))
	b.draw_rect(Rect2(0.0, sz.y - 3.0, floorf(sz.x * clampf(t / LENGTH, 0.0, 1.0)), 3.0), Color("#ff3a3a"))
	b.draw_rect(Rect2(sz.x - 16.0, 2.0, 14.0, 9.0), Color(0, 0, 0, 0.45))
	b._text("AD", sz.x - 14.0, 9.0, UITheme.FS_SMALL, Color(1, 1, 1, 0.85))


static func _stars(b: PostingBoard, sz: Vector2, t: float, n: int, speed: float, col: Color) -> void:
	for k in n:
		var x := fposmod(ShopLight.hash1(float(k) * 3.7) * sz.x - t * speed * (0.5 + ShopLight.hash1(float(k) * 1.3)), sz.x)
		var y := floorf(ShopLight.hash1(float(k) * 7.1 + 2.0) * (sz.y - 8.0))
		var tw := 0.5 + 0.5 * sin(t * 3.0 + float(k))
		b.draw_rect(Rect2(floorf(x), y, 1.0, 1.0), Color(col.r, col.g, col.b, 0.3 + 0.7 * tw))


## A sparkle: a plus that grows and shrinks.
static func _glint(b: PostingBoard, c: Vector2, u: float, col: Color) -> void:
	var r := int(round(sin(clampf(u, 0.0, 1.0) * PI) * 3.0))
	if r <= 0:
		return
	b.draw_rect(Rect2(c.x - float(r), c.y, float(r * 2 + 1), 1.0), col)
	b.draw_rect(Rect2(c.x, c.y - float(r), 1.0, float(r * 2 + 1)), col)


## HULL WAX: a dull ship slides in, a cloth goes over it, it shines.
static func _hull_wax(b: PostingBoard, sz: Vector2, t: float) -> void:
	b.draw_rect(Rect2(Vector2.ZERO, sz), Color("#140c2a"))
	_stars(b, sz, t, 30, 4.0, Color("#c8c0ff"))
	var shine := _at(t, 1.6, 3.6)
	var hull := Color("#5a5a62").lerp(Color("#d8f0ff"), shine)
	# it drops out of a jump: a flash, then it slides to the middle
	var x := floorf(lerpf(8.0, (sz.x - 64.0) * 0.5, _ease(_at(t, 0.15, 1.3))))
	if t < 0.3:
		b.draw_rect(Rect2(0.0, 67.0, sz.x, 2.0), Color(0.8, 0.85, 1.0, 1.0 - t / 0.3))
	var y := 62.0
	b.draw_rect(Rect2(x, y, 56.0, 12.0), hull)
	for k in 5:
		b.draw_rect(Rect2(x + 56.0 + float(k) * 2.0, y + 1.0 + float(k), 2.0, 10.0 - float(k) * 2.0), hull)
	b.draw_rect(Rect2(x + 16.0, y - 6.0, 16.0, 6.0), hull.darkened(0.1))
	b.draw_rect(Rect2(x - 6.0, y + 3.0, 6.0, 6.0), hull.darkened(0.2))
	b.draw_rect(Rect2(x + 4.0, y + 4.0, 44.0, 1.0), hull.darkened(0.3))
	# the cloth, rubbing back and forth along it
	if t > 1.4 and t < 3.8:
		var cx := x + 4.0 + floorf((0.5 + 0.5 * sin(t * 9.0)) * 40.0)
		b.draw_rect(Rect2(cx, y - 3.0, 12.0, 9.0), Color("#f4f0e8"))
		b.draw_rect(Rect2(cx + 2.0, y - 1.0, 8.0, 1.0), Color("#c8c0b0"))
	# where it has been, a highlight band
	if shine > 0.0:
		b.draw_rect(Rect2(x + 2.0, y + 2.0, floorf(50.0 * shine), 2.0), Color(1, 1, 1, 0.7))
	for k in 4:
		_glint(b, Vector2(x + 8.0 + float(k) * 14.0, y + 2.0 + float(k % 2) * 6.0),
			fposmod(t - 3.4 - float(k) * 0.35, 1.2) / 0.6 if t > 3.4 else 0.0, Color.WHITE)
	if t > 3.6:
		var bounce := floorf(absf(sin((t - 3.6) * 6.0)) * 4.0 * maxf(0.0, 1.0 - (t - 3.6)))
		b._centre_at("SHINE!", 0.0, 34.0 - bounce, sz.x, UITheme.FS_HEAD, Color("#f0c040"))
	if t > 4.4:
		b.draw_rect(Rect2(0.0, sz.y - 50.0, sz.x, 44.0), Color("#f0c040"))
		b._centre_at("HULL WAX", 0.0, sz.y - 34.0, sz.x, UITheme.FS_SMALL, Color("#2a1a08"))
		b._centre_at("2 FOR 1", 0.0, sz.y - 14.0, sz.x, UITheme.FS_HEAD, Color("#2a1a08"))


## STAR TAXI: stars streak past a yellow cab, and it is gone.
static func _star_taxi(b: PostingBoard, sz: Vector2, t: float) -> void:
	b.draw_rect(Rect2(Vector2.ZERO, sz), Color("#06080e"))
	for k in 18:
		var y := floorf(ShopLight.hash1(float(k) * 5.3) * (sz.y - 10.0))
		var x := fposmod(ShopLight.hash1(float(k) * 2.9) * sz.x * 2.0 - t * 140.0 * (0.6 + ShopLight.hash1(float(k))), sz.x + 40.0) - 20.0
		var x0 := maxf(floorf(x), 0.0)
		var x1 := minf(floorf(x) + 14.0, sz.x)
		if x1 > x0:
			b.draw_rect(Rect2(x0, y, x1 - x0, 1.0), Color(0.8, 0.85, 1.0, 0.6))
	var go := _at(t, 3.4, 4.0)
	var x2 := floorf(lerpf(22.0, sz.x + 60.0, go * go))
	var y2 := 84.0 + floorf(sin(t * 5.0) * 2.0)
	var cab := Color("#f0c020")
	# once it reaches the edge it is gone: a streak where it went
	if x2 + 44.0 > sz.x:
		if go < 0.6:
			b.draw_rect(Rect2(22.0, y2 + 5.0, sz.x - 22.0, 2.0), Color(1.0, 0.85, 0.3, 0.6 - go))
		x2 = -1000.0
	b.draw_rect(Rect2(x2, y2, 40.0, 12.0), cab)
	b.draw_rect(Rect2(x2 + 10.0, y2 - 6.0, 18.0, 6.0), cab)
	b.draw_rect(Rect2(x2 + 13.0, y2 - 4.0, 12.0, 3.0), Color("#7ac8f0"))
	for k in 5:
		b.draw_rect(Rect2(x2 + 2.0 + float(k) * 8.0, y2 + 5.0, 4.0, 2.0), Color("#1a1a1a") if k % 2 == 0 else cab)
	# its exhaust, flickering
	var fl := 4.0 + floorf(ShopLight.hash1(floorf(t * 20.0)) * 6.0)
	b.draw_rect(Rect2(x2 - fl, y2 + 3.0, fl, 6.0), Color("#ff8a3a"))
	b._centre_at("STAR", 0.0, 26.0, sz.x, UITheme.FS_HEAD, cab)
	b._centre_at("TAXI", 0.0, 44.0, sz.x, UITheme.FS_HEAD, cab)
	if t > 1.6:
		b._centre_at("ANYWHERE!*", 0.0, 64.0, sz.x, UITheme.FS_SMALL, Color.WHITE)
	if t > 4.3:
		b._centre_at("*NEARBY", 0.0, sz.y - 40.0, sz.x, UITheme.FS_SMALL, Color("#a0a8b8"))
		b._centre_at("CALL 4-TAXI", 0.0, sz.y - 20.0, sz.x, UITheme.FS_SMALL, cab)


## NOODLES: a bowl, steam, the chopsticks lifting, SLURP.
static func _noodles(b: PostingBoard, sz: Vector2, t: float) -> void:
	b.draw_rect(Rect2(Vector2.ZERO, sz), Color("#b8302a"))
	var c := Vector2(floorf(sz.x * 0.5), 112.0)
	# steam, three wisps rising
	for k in 3:
		for d in 6:
			var u := fposmod(t * 0.8 + float(d) / 6.0 + float(k) * 0.33, 1.0)
			var px := c.x - 14.0 + float(k) * 14.0 + floorf(sin(u * 9.0 + float(k)) * 3.0)
			var py := c.y - 14.0 - floorf(u * 40.0)
			b.draw_rect(Rect2(px, py, 2.0, 2.0), Color(1, 1, 1, 0.5 * (1.0 - u)))
	# the chopsticks, lifting a strand and putting it back
	var lift := floorf((0.5 + 0.5 * sin(t * 3.0)) * 14.0)
	b.draw_line(Vector2(c.x + 8.0, c.y - 12.0 - lift), Vector2(c.x + 34.0, c.y - 44.0 - lift), Color("#e8c890"), 2.0)
	b.draw_line(Vector2(c.x + 12.0, c.y - 10.0 - lift), Vector2(c.x + 40.0, c.y - 38.0 - lift), Color("#d8b880"), 2.0)
	for k in 3:
		b.draw_rect(Rect2(c.x + 6.0 + float(k) * 3.0, c.y - 10.0 - lift, 1.0, lift + 6.0), Color("#f0d070"))
	# the bowl: a half disc, noodles heaped in it
	for row in 14:
		var hw := floorf(sqrt(maxf(0.0, 196.0 - float(row * row))) * 1.9)
		b.draw_rect(Rect2(c.x - hw, c.y - 6.0 + float(row), hw * 2.0, 1.0), Color("#f4f0e8") if row > 1 else Color("#d8d0c0"))
	b.draw_rect(Rect2(c.x - 24.0, c.y - 8.0, 48.0, 3.0), Color("#f0d070"))
	b.draw_rect(Rect2(c.x - 22.0, c.y + 2.0, 44.0, 2.0), Color("#c83a2a"))
	# SLURP, its letters hopping
	var word := "SLURP!"
	var x0 := floorf((sz.x - float(word.length()) * 12.0) * 0.5)
	for k in word.length():
		if t > 0.3 + float(k) * 0.15:
			var hop := floorf(absf(sin(t * 7.0 + float(k) * 0.8)) * 4.0)
			b._text(word.substr(k, 1), x0 + float(k) * 12.0, 30.0 - hop, UITheme.FS_HEAD, Color("#f8e8c0"))
	if t > 3.2:
		b._centre_at("DECK 3", 0.0, 50.0, sz.x, UITheme.FS_SMALL, Color("#f8e8c0"))
	if t > 4.0:
		b._centre_at("OPEN LATE", 0.0, sz.y - 14.0, sz.x, UITheme.FS_SMALL, Color("#f8e8c0"))


## ADOPT A DRONE: a little drone bobs and blinks, and a heart comes up.
static func _drone(b: PostingBoard, sz: Vector2, t: float) -> void:
	b.draw_rect(Rect2(Vector2.ZERO, sz), Color("#1e6a72"))
	var c := Vector2(floorf(sz.x * 0.5), 86.0 + floorf(sin(t * 2.4) * 4.0))
	# the arms and their rotors, a blur that flickers
	for s in [-1.0, 1.0]:
		b.draw_rect(Rect2(c.x + s * 10.0 - (6.0 if s < 0.0 else 0.0), c.y - 9.0, 6.0, 2.0), Color("#8a9aa4"))
		var rw := 6.0 + floorf(ShopLight.hash1(floorf(t * 24.0) + s) * 6.0)
		b.draw_rect(Rect2(c.x + s * 16.0 - rw * 0.5, c.y - 12.0, rw, 1.0), Color(1, 1, 1, 0.7))
	PostingBoard._disc(b, c, 10, Color("#5a6a74"))
	PostingBoard._disc(b, c, 9, Color("#b8c8d0"))
	# the eye, blinking now and then
	var blink := fposmod(t, 1.7) < 0.12
	if blink:
		b.draw_rect(Rect2(c.x - 4.0, c.y, 9.0, 1.0), Color("#1a2a30"))
	else:
		PostingBoard._disc(b, c, 4, Color("#ffffff"))
		var look := floorf(sin(t * 1.3) * 2.0)
		PostingBoard._disc(b, c + Vector2(look, 0.0), 2, Color("#1a2a30"))
	# a little light on top, and the heart
	b.draw_rect(Rect2(c.x, c.y - 12.0, 1.0, 2.0), Color("#ff6a6a") if fposmod(t, 0.8) < 0.4 else Color("#6a2a2a"))
	if t > 2.4:
		var u := _at(t, 2.4, 4.4)
		var hc := c + Vector2(14.0, -18.0 - floorf(u * 26.0))
		var col := Color(1.0, 0.45, 0.55, 1.0 - u * 0.6)
		b.draw_rect(Rect2(hc.x - 3.0, hc.y, 3.0, 2.0), col)
		b.draw_rect(Rect2(hc.x + 1.0, hc.y, 3.0, 2.0), col)
		b.draw_rect(Rect2(hc.x - 3.0, hc.y + 2.0, 7.0, 2.0), col)
		b.draw_rect(Rect2(hc.x - 2.0, hc.y + 4.0, 5.0, 1.0), col)
		b.draw_rect(Rect2(hc.x - 1.0, hc.y + 5.0, 3.0, 1.0), col)
		b.draw_rect(Rect2(hc.x, hc.y + 6.0, 1.0, 1.0), col)
	b._centre_at("LONELY?", 0.0, 30.0, sz.x, UITheme.FS_HEAD, Color("#f0fff8"))
	if t > 3.0:
		b._centre_at("ADOPT A DRONE", 0.0, sz.y - 36.0, sz.x, UITheme.FS_SMALL, Color("#f0fff8"))
	if t > 4.0:
		b._centre_at("THEY BEEP!", 0.0, sz.y - 20.0, sz.x, UITheme.FS_SMALL, Color("#ffd0d8"))


## COOLANT: a thermometer falls from red to blue, and it snows.
static func _coolant(b: PostingBoard, sz: Vector2, t: float) -> void:
	var u := _ease(_at(t, 0.8, 3.4))
	b.draw_rect(Rect2(Vector2.ZERO, sz), Color("#5a1a10").lerp(Color("#0e2a4a"), u))
	if u > 0.3:
		for k in 26:
			var x := floorf(ShopLight.hash1(float(k) * 3.3) * sz.x + sin(t * 2.0 + float(k)) * 3.0)
			var y := floorf(fposmod(ShopLight.hash1(float(k) * 8.1) * sz.y + t * (14.0 + float(k % 5) * 4.0), sz.y))
			b.draw_rect(Rect2(x, y, 1.0, 1.0), Color(1, 1, 1, (u - 0.3) * 1.2))
	var tube := Rect2(sz.x * 0.5 - 5.0, 44.0, 10.0, 80.0)
	b.draw_rect(tube.grow(2.0), Color("#e8eef4"))
	b.draw_rect(tube, Color("#2a3440"))
	var level := lerpf(0.92, 0.18, u)
	var liquid := Color("#ff4a2a").lerp(Color("#4ac8ff"), u)
	b.draw_rect(Rect2(tube.position.x + 2.0, tube.end.y - floorf(tube.size.y * level), 6.0, floorf(tube.size.y * level)), liquid)
	PostingBoard._disc(b, Vector2(tube.get_center().x, tube.end.y + 6.0), 8, Color("#e8eef4"))
	PostingBoard._disc(b, Vector2(tube.get_center().x, tube.end.y + 6.0), 6, liquid)
	for k in 5:
		b.draw_rect(Rect2(tube.end.x + 3.0, tube.position.y + 6.0 + float(k) * 16.0, 4.0, 1.0), Color("#e8eef4"))
	if t < 2.6:
		b._centre_at("TOO HOT?", 0.0, 30.0, sz.x, UITheme.FS_HEAD, Color("#ffd8a0"))
	else:
		b._centre_at("AHHH.", 0.0, 30.0, sz.x, UITheme.FS_HEAD, Color("#c8f0ff"))
	if t > 3.8:
		b._centre_at("FROSTLINE", 0.0, sz.y - 24.0, sz.x, UITheme.FS_SMALL, Color("#c8f0ff"))
		b._centre_at("COOLANT", 0.0, sz.y - 12.0, sz.x, UITheme.FS_SMALL, Color("#c8f0ff"))


## LUCKY SPIN: three reels spin, stop one by one -- 7, 7, 3. So close.
static func _lucky_spin(b: PostingBoard, sz: Vector2, t: float) -> void:
	b.draw_rect(Rect2(Vector2.ZERO, sz), Color("#3a1a5a"))
	# bulbs round the edge, chasing
	for k in 14:
		var on := (int(t * 8.0) + k) % 3 == 0
		var bx := 6.0 + float(k % 7) * floorf((sz.x - 12.0) / 6.0)
		var by := 44.0 if k < 7 else 98.0
		b.draw_rect(Rect2(bx, by, 2.0, 2.0), Color("#ffe060") if on else Color("#6a4a20"))
	b._centre_at("LUCKY", 0.0, 22.0, sz.x, UITheme.FS_HEAD, Color("#ffe060"))
	b._centre_at("SPIN", 0.0, 38.0, sz.x, UITheme.FS_HEAD, Color("#ffe060"))
	var stops := [1.6, 2.3, 3.0]
	var last := ["7", "7", "3"]
	var w := 26.0
	var x0 := floorf((sz.x - w * 3.0 - 8.0) * 0.5)
	for k in 3:
		var r := Rect2(x0 + float(k) * (w + 4.0), 52.0, w, 40.0)
		b.draw_rect(r, Color("#f4f0e8"))
		b.draw_rect(r, Color("#1a1020"), false, 1.0)
		var sym: String = last[k]
		var dy := 0.0
		if t < stops[k]:
			sym = str(int(t * 18.0 + float(k) * 3.0) % 10)
			dy = fposmod(t * 18.0, 1.0) * 10.0 - 5.0
		b._centre_at(sym, r.position.x, r.position.y + 28.0 + floorf(dy), w, UITheme.FS_HEAD,
			Color("#c82a2a") if sym == "7" else Color("#1a1020"))
	if t > 3.4 and fposmod(t, 0.5) < 0.35:
		b._centre_at("SO CLOSE!", 0.0, 122.0, sz.x, UITheme.FS_SMALL, Color("#ffe060"))
	if t > 4.2:
		b._centre_at("SPIN AGAIN", 0.0, sz.y - 26.0, sz.x, UITheme.FS_SMALL, Color.WHITE)
		b._centre_at("1 CR", 0.0, sz.y - 10.0, sz.x, UITheme.FS_SMALL, Color("#ffe060"))
