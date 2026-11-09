extends Node2D

## The comet on LOCAL's band (`CometPath`), where the map has it at the clock LOCAL holds:
## the map's look (head, coma, gold dust tail, blue ion tail) a little bigger.
## Why: docs/why/LocalComet.md#on-the-band

## the sky it is drawn in (`LocalSky`)
var sky
## Its size against the map's (Jon, Nov 9, "K3"): a real presence in the sky that does
## not upstage the ship. Why: docs/why/LocalComet.md#size
const K_NEAR := 1.25
const K_FAR := 1.0
const SkyWeatherS := preload("res://scripts/ui/sysmap/SkyWeather.gd")


## Plane point p (from star A as LOCAL left the pair) on the band's screen.
func _on_band(p: Vector2) -> Vector2:
	return sky._zp(sky.band_origin() + Vector2(p.x, p.y * sky.TILT) * sky._s, sky.Z_BAND)


## Where the head is drawn, or INF while it is not in the system.
func head() -> Vector2:
	var L: SystemLayout = sky.layout if sky != null else null
	if L == null or L.comet == null or not L.comet.here(sky._tm):
		return Vector2.INF
	return (_on_band(sky._rel(L.comet.pos(L, sky._tm))) / 2.0).round() * 2.0


## The map's look (`SkyWeather.RealComet.paint`) at the band's place, held at LOCAL's clock.
func _draw() -> void:
	var hs := head()
	if hs == Vector2.INF:
		return
	var L: SystemLayout = sky.layout
	var c: CometPath = L.comet
	var tm: float = sky._tm
	var a := c.age(tm)
	var A := clampf(pow(2.5 * c.q / maxf(c.rel(a).length(), 1.0), 2.0), 0.0, 1.0)
	var fade := clampf(a / 5.0, 0.0, 1.0) * clampf((c.T - a) / 5.0, 0.0, 1.0)
	var away := hs - _on_band(sky._rel(L.star_pos(-1, tm)))
	var ad := away.normalized() if away.length() > 0.5 else Vector2.RIGHT
	var going := _on_band(sky._rel(c.pos(L, tm + 0.5))) - hs
	var side: Vector2 = SkyWeatherS.RealComet.trailing_side(ad, going)
	SkyWeatherS.RealComet.paint(self, hs, ad, side, lerpf(K_FAR, K_NEAR, A), fade, bool(sky.radiant))
