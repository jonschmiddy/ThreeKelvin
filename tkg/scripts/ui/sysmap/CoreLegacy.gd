extends Node2D

## THE CORE ON THE SYSTEM MAP, in every style: the black hole Jon fixed for every
## style from the Oct 5 showcase (direction C's: "This is the best black hole
## rendition we have gotten. I love this shape and perspective. I want this no
## matter what style we pick."), the same one the star chart draws, from the
## shared `legacy_hole.gdshaderinc` (its photon table traced once a process by
## `LegacyHole`). `core_legacy.gdshader` draws it, the map behind bent through
## its lens and lit by its disc.
##
## SIZED AMONG THE ORBITS: the shadow is SHADOW map pixels across at star_k
## 1, so the disc's outer edge (three shadow radii, 116 px) is where the fabric
## and the orbit lines already stop round the core, and it grows with the map as
## the old hole did (`SystemView.star_k`, never under 1).
##
## In the map's order it sits where `CoreView` sat: among the worlds, after the
## ones behind it (which its lens bends) and before the ones in front. It keeps
## `CoreView`'s handles for the weather (`_hmat` with `hs` and `rf`,
## `drawn_zoom`, `breath_add`, `ready_to_draw`, `next_plunge`).

const SHADER := preload("res://shaders/core_legacy.gdshader")
## the shadow's radius on the map at star_k 1: 116 / 3
const SHADOW := 38.67
## the lens reaches 22 Schwarzschild radii (`lh_behind` is flat by then): in shadows
const REACH := 22.0 / 2.5980762

var ready_to_draw := false
var zoom := 1.0
var drawn_zoom := 1.0
## THE WEATHER'S FLARE (`SkyWeather` `flareecho`): the disc's light swelling.
var breath_add := 0.0
## HOW BIG THE HOLE IS DRAWN against its own zoom (`SystemView`: the showcase's
## size in every style but LEGACY, which keeps the size it had)
var hole_k := 1.0:
	set(v):
		if absf(v - hole_k) > 0.0005:
			hole_k = v
			if _hmat != null:
				_fit()
var _rect: ColorRect
var _hmat: ShaderMaterial


func _init() -> void:
	var copy := BackBufferCopy.new()
	copy.copy_mode = BackBufferCopy.COPY_MODE_VIEWPORT
	add_child(copy)
	_rect = ColorRect.new()
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hmat = ShaderMaterial.new()
	_hmat.shader = SHADER
	_rect.material = _hmat
	add_child(_rect)
	_rect.visible = false
	_fit()


## The photon table onto the material (loaded once a process). Not headless.
func setup() -> void:
	LegacyHole.apply(_hmat)
	ready_to_draw = true
	_rect.visible = true


## THE MAP'S ZOOM (`SystemView.star_k`): every frame while it eases.
func set_zoom(k: float) -> void:
	if absf(k - zoom) > 0.00001:
		zoom = k
		drawn_zoom = k
		_fit()


func _fit() -> void:
	var s := SHADOW * zoom * hole_k
	var e := ceilf(s * REACH / 2.0 + 2.0) * 2.0
	_rect.position = Vector2(-e, -e)
	_rect.size = Vector2(e * 2.0, e * 2.0)
	_hmat.set_shader_parameter("hole_px", s)
	_hmat.set_shader_parameter("kz", zoom)


## The map's clock: the disc turns, and the hole's own hot spot comes round
## every 30 s (not with reduced motion).
func step(t: float) -> void:
	if not ready_to_draw:
		return
	_hmat.set_shader_parameter("time", t)
	_hmat.set_shader_parameter("hot_on", 0.0 if DisplaySettings.reduced_motion else 1.0)
	_hmat.set_shader_parameter("breath_add", breath_add)
	# where the hole is in the place's own pixels (2x2 blocks)
	_hmat.set_shader_parameter("centre_scene", position / 2.0)


## When a clump next goes over the top edge, between `lo` and `hi` seconds from
## now: (seconds until, its screen angle); the ring flash waits for it. The
## clumps here are the disc's own, so it goes over the top a moment in.
func next_plunge(_t: float, lo: float, hi: float) -> Vector2:
	return Vector2(lerpf(lo, hi, 0.3), -PI / 2.0)
