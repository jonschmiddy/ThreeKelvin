class_name JumpPlace
extends RefCounted

## Where a film's things land on this LOCAL. The films were drawn round a ship at x90 y232,
## 236x93, in a 960x540 frame with 622 px ahead of its nose; another hull or a convoy pad
## moves and resizes it. Space is scaled, never time, so the sound stays true.
## Why: docs/why/JumpPlace.md#place

const FILM_SHIP := Rect2(90.0, 232.0, 236.0, 93.0)
const FILM_ROOM := 622.0
## The drive sits 26% in from the tail and 56% down the hull on every film.
const CORE_AT := Vector2(0.2627, 0.559)

## The world window on screen (the LOCAL view, HUD excluded).
var window := Rect2(8.0, 42.0, 944.0, 491.0)
## The hull's canvas (its texture's origin and size) and its ink, on screen.
var canvas := Rect2()
var ink := Rect2()
var core := Vector2.ZERO
var pc := Vector2.ZERO
## The ink's centre of mass on screen (R14's sink), off the live canvas at every other pixel.
var centroid := Vector2.ZERO
var room := FILM_ROOM
var hull_k := 1.0


## Measured off the live view: the canvas is drawn centred in the ShipView, whole pixels.
static func measure(view: EncounterView, art: ShipView) -> JumpPlace:
	var p := JumpPlace.new()
	p.window = view.get_global_rect()
	var org := (art.get_global_rect().position + art.hull_rect().position).round()
	var used := art.canvas().get_used_rect()
	p.canvas = Rect2(org, Vector2(art.canvas_width(), art.canvas_height()))
	p.ink = Rect2(org + Vector2(used.position), Vector2(used.size))
	p.core = p.ink.position + Vector2(roundf(CORE_AT.x * p.ink.size.x), roundf(CORE_AT.y * p.ink.size.y))
	p.pc = p.ink.get_center()
	var img := art.canvas()
	var sx := 0.0
	var sy := 0.0
	var cnt := 0
	for y in range(used.position.y, used.end.y, 2):
		for x in range(used.position.x, used.end.x, 2):
			if img.get_pixel(x, y).a > 0.0:
				sx += x
				sy += y
				cnt += 1
	p.centroid = org + Vector2(sx, sy) / maxf(cnt, 1.0) if cnt > 0 else p.pc
	p.room = maxf(p.window.end.x - p.ink.end.x, 60.0)
	p.hull_k = clampf(p.ink.size.x / FILM_SHIP.size.x, 0.7, 1.3)
	return p


## A distance ahead of the nose, as the film had it, fitted to the room this LOCAL has.
func ahead(film_px: float) -> float:
	return film_px * clampf(room / FILM_ROOM, 0.35, 1.0)


## A distance measured in hull lengths.
func along(film_px: float) -> float:
	return film_px * hull_k
