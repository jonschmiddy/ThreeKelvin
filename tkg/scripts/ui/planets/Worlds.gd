class_name Worlds
extends RefCounted

## THE WORLDS: every kind of planet the system map draws, what it is made of
## and how it is lit, and each world's lasting facts from one seed.
##
## A port of the approved mockup's planet painter (the scratchpad's
## `sysmap/planets.js`, "Thirty-Four Worlds"). The painting itself is
## `planet.gdshader`; this holds what the shader is told: the colour ramps (one
## texture), what each kind of world has (air, caps, clouds, rings, storms,
## lights), and `spec()`, which rolls a world's spin, tilt, craters, storms and
## the rest from its seed exactly as the mockup did -- the same generator, the
## same order of draws -- so a world here is the world Jon approved there.

## Six steps a ramp, darkest first. The order is the shader's: `R_*` there.
const RAMP_ORDER := [
	&"rock", &"moon", &"desert", &"iron", &"ice", &"crust", &"glow", &"sea", &"land", &"toxic",
	&"city", &"crystal", &"banded", &"icegiant", &"storm", &"violet", &"cloud", &"haze", &"ash", &"scorch",
	&"carbon", &"alien", &"lineae", &"storm2", &"swamp", &"swampw", &"blaze", &"graphite", &"tar", &"smog",
	&"diamond", &"mist",
]
const RAMP := {
	&"rock": ["#15171b", "#2c2c2e", "#47433f", "#686058", "#8d8275", "#b9ad9b"],
	&"moon": ["#1b1c20", "#34363c", "#55585e", "#7a7d83", "#a2a5aa", "#cfd1d4"],
	&"desert": ["#24160c", "#4e3018", "#7c5226", "#a8763a", "#d2a05a", "#f0cc8a"],
	&"iron": ["#200c08", "#4a1a10", "#7a2e1a", "#a84a28", "#cc6e40", "#e8a070"],
	&"ice": ["#121c28", "#26405a", "#43708e", "#6fa0bc", "#a8cfe0", "#e2f2f8"],
	&"crust": ["#0e0806", "#1e120c", "#2e1c14", "#40281c", "#56362a", "#6e4636"],
	&"glow": ["#6a1c08", "#b03a10", "#e86a1c", "#ffa83c", "#ffd87a", "#fff2c0"],
	&"sea": ["#06101e", "#0a1e3a", "#123462", "#1e4f8a", "#3470b0", "#5e98d0"],
	&"land": ["#0c1a0e", "#1a3418", "#2e5426", "#4a7a34", "#74a04a", "#a8c870"],
	&"toxic": ["#1a1a06", "#3a3a0e", "#5e5e18", "#8a8a28", "#b8b042", "#e0d870"],
	&"city": ["#0c0e14", "#181c26", "#262c3a", "#3a4254", "#545e72", "#7a8496"],
	&"crystal": ["#120a1e", "#2a1648", "#46267a", "#6a3eaa", "#9a68d4", "#d0b0f4"],
	&"banded": ["#1c140e", "#4a3220", "#86603a", "#c49a62", "#e0bc86", "#f6e2b6"],
	&"icegiant": ["#0a1a24", "#14364a", "#20586e", "#348496", "#5cb2c0", "#a0e0e6"],
	&"storm": ["#1e0c08", "#4a1c10", "#86361c", "#bc5a2c", "#e08a4e", "#f6c08a"],
	&"violet": ["#140c1e", "#2c1a42", "#4a2c6a", "#6e4696", "#9a6cc0", "#cca8e8"],
	&"cloud": ["#2a3038", "#4a5260", "#78808e", "#a8b0bc", "#d4dae2", "#f4f8fc"],
	&"haze": ["#2a1606", "#5a3010", "#8a5018", "#b87428", "#dc9a44", "#f4c070"],
	&"ash": ["#121212", "#262422", "#3e3a36", "#5a544e", "#7a726a", "#9e958a"],
	&"scorch": ["#1a120e", "#33241c", "#4e3a2c", "#6c5440", "#8c7258", "#ae9478"],
	&"carbon": ["#06070a", "#101218", "#1a1e28", "#262c3a", "#3a4256", "#5a6680"],
	&"alien": ["#120a1e", "#2a1442", "#4a1e64", "#2e6a6a", "#3e9a8a", "#7ad0b8"],
	&"lineae": ["#2a0e08", "#4e1c10", "#7a3018", "#a24a28", "#c46a40", "#e09068"],
	&"storm2": ["#0e1018", "#1e2230", "#30364a", "#464e66", "#646e88", "#8a94ac"],
	&"swamp": ["#0e1208", "#1e2410", "#323a18", "#4a5222", "#646c30", "#848a44"],
	&"swampw": ["#060a08", "#0c1610", "#14241a", "#1e3426", "#2a4632", "#3a5a40"],
	&"blaze": ["#0a0e22", "#18244e", "#2c4690", "#5a7ed0", "#a8c4ff", "#f0f6ff"],
	&"graphite": ["#08090b", "#15171c", "#262a31", "#3e434c", "#646a74", "#9aa0aa"],
	&"tar": ["#030304", "#08090c", "#0f1116", "#181b22", "#262a34", "#3a404c"],
	&"smog": ["#1a1008", "#3a2410", "#5e3a18", "#84542a", "#a87240", "#c8945a"],
	&"diamond": ["#1a2230", "#34465e", "#5a7898", "#8eb0cc", "#c4dcec", "#f2fbff"],
	&"mist": ["#1a2018", "#2e3a2c", "#4a5844", "#6a7a62", "#8e9e84", "#b4c2a8"],
}

## The order is the shader's: `W_*` there.
const WORLD_ORDER := [
	&"rock", &"moon", &"desert", &"iron", &"ice", &"lava", &"verdant", &"ocean", &"toxic", &"city",
	&"crystal", &"banded", &"icegiant", &"storm", &"violet", &"eyeball", &"hotjup", &"cracked", &"hurricane", &"haze",
	&"volcanic", &"biolum", &"megacity", &"shattered", &"carbonA", &"carbonB", &"carbonC", &"scorched", &"rogue", &"aurora",
	&"lightning", &"comet", &"europa", &"swamp",
]

## What each kind of world is: its look, its features, and what the panel calls it.
const WORLD := {
	&"rock": {"name": "ROCK", "crater": true},
	&"moon": {"name": "BARREN MOON", "crater": true},
	&"desert": {"name": "DESERT", "atm": "#e0a060", "caps": 0.92},
	&"iron": {"name": "IRON WORLD", "atm": "#e07050", "caps": 0.84},
	&"ice": {"name": "ICE WORLD", "atm": "#a0d8f0"},
	&"lava": {"name": "LAVA WORLD", "atm": "#ff6a2a"},
	&"verdant": {"name": "LIVING WORLD", "atm": "#7ab8ff", "caps": 0.8, "clouds": 0.62},
	&"ocean": {"name": "OCEAN WORLD", "atm": "#7ab8ff", "caps": 0.86, "clouds": 0.56},
	&"toxic": {"name": "TOXIC WORLD", "atm": "#d8d050"},
	&"city": {"name": "CITY WORLD", "atm": "#90a0c0", "citylights": true, "clouds": 0.7},
	&"crystal": {"name": "CRYSTAL WORLD", "atm": "#c8a0ff"},
	&"banded": {"name": "GAS GIANT", "atm": "#e8c890", "giant": true},
	&"icegiant": {"name": "ICE GIANT", "atm": "#90e0f0", "giant": true},
	&"storm": {"name": "STORM GIANT", "atm": "#f0a070", "giant": true, "spot": true},
	&"violet": {"name": "VIOLET GIANT", "atm": "#c090f0", "giant": true},
	&"eyeball": {"name": "EYEBALL WORLD", "atm": "#b0d0ff", "tidal": true},
	&"hotjup": {"name": "HOT JUPITER", "atm": "#ff8a50", "giant": true},
	&"cracked": {"name": "CRACKED WORLD", "atm": "#ff7030"},
	&"hurricane": {"name": "HURRICANE WORLD", "atm": "#7ab8ff", "caps": 0.88, "spot": true, "clouds": 0.72},
	&"haze": {"name": "HAZE WORLD", "atm": "#ffb060", "thick": true},
	&"volcanic": {"name": "VOLCANIC WORLD", "atm": "#a06040", "clouds": 0.66, "cloud_ramp": &"ash"},
	&"biolum": {"name": "GLOWING JUNGLE", "atm": "#80e0d0", "clouds": 0.7},
	&"megacity": {"name": "PLANET-CITY", "atm": "#90a0c0", "citylights": true},
	&"shattered": {"name": "SHATTERED WORLD", "shattered": true},
	&"carbonA": {"name": "GRAPHITE WORLD"},
	&"carbonB": {"name": "TAR WORLD", "atm": "#b07040", "clouds": 0.66, "cloud_ramp": &"smog"},
	&"carbonC": {"name": "DIAMOND WORLD"},
	&"scorched": {"name": "SCORCHED WORLD", "crater": true},
	&"rogue": {"name": "ROGUE WORLD", "unlit": true, "auroras": true},
	&"aurora": {"name": "AURORA WORLD", "atm": "#7ab8ff", "caps": 0.86, "clouds": 0.64, "auroras": true},
	&"lightning": {"name": "STORM WORLD", "atm": "#a0b0d8", "lightning": true},
	&"comet": {"name": "EVAPORATING WORLD", "atm": "#90e0f0", "tail": true},
	&"europa": {"name": "LINED ICE MOON"},
	&"swamp": {"name": "SWAMP WORLD", "atm": "#a0c090", "clouds": 0.6, "cloud_ramp": &"mist"},
}

## Glow features, as the shader's `flags` bits.
const F_CITY := 1
const F_LIGHTNING := 2
const F_AURORA := 4
const F_TAIL := 8
const F_GIANT := 16
const F_MEGACITY := 32

static var _ramp_tex: ImageTexture = null


## The ramps as one 6 x N texture, a ramp a row, darkest on the left.
static func ramp_texture() -> ImageTexture:
	if _ramp_tex == null:
		var img := Image.create(6, RAMP_ORDER.size(), false, Image.FORMAT_RGBA8)
		for y in RAMP_ORDER.size():
			var row: Array = RAMP[RAMP_ORDER[y]]
			for x in 6:
				img.set_pixel(x, y, Color(row[x]))
		_ramp_tex = ImageTexture.create_from_image(img)
	return _ramp_tex


## A ramp's colour at value `v`, with the painter's 2x2 dither at pixel (x, y).
static func ramp_color(ramp: StringName, v: float, x: int, y: int) -> Color:
	var B := [[0.0, 2.0], [3.0, 1.0]]
	var k := clampi(int(floor(v * 6.0 + (B[(y + 999) & 1][(x + 999) & 1] - 1.5) * 0.22)), 0, 5)
	return Color(RAMP[ramp][k])


## The node that draws a world of this kind: a broken world has its own.
static func view_for(world: StringName) -> Node2D:
	if world == &"shattered":
		return ShatteredView.new()
	return PlanetView.new()


static func ramp_id(name: StringName) -> int:
	return RAMP_ORDER.find(name)


static func world_id(name: StringName) -> int:
	return WORLD_ORDER.find(name)


static func display_name(world: StringName) -> String:
	return String(WORLD.get(world, {}).get("name", String(world).to_upper()))


## THE MOCKUP'S GENERATOR, bit for bit: xorshift32, as `rng()` in the
## scratchpad's template. A world's spin, tilt, craters and storms come from it
## in the mockup's order of draws, so the same seed gives the same world.
class XRng extends RefCounted:
	var s: int = 1

	func _init(seed: float) -> void:
		s = int(floor(seed)) & 0xFFFFFFFF
		if s == 0:
			s = 1

	func next() -> float:
		s = (s ^ (s << 13)) & 0xFFFFFFFF
		s = s ^ (s >> 17)
		s = (s ^ (s << 5)) & 0xFFFFFFFF
		return float(s) / 4294967296.0


## The mockup's `h3`: a 32-bit integer hash of three whole numbers, to [0, 1).
static func h3(x: int, y: int, z: int) -> float:
	var h := ((x * 374761393) ^ (y * 668265263) ^ (z * 1440662683)) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	return float((h ^ (h >> 16)) & 0xFFFFFFFF) / 4294967296.0


static func sphere_rand(R: XRng) -> Vector3:
	var a := R.next() * TAU
	var z := R.next() * 2.0 - 1.0
	var s := sqrt(1.0 - z * z)
	return Vector3(cos(a) * s, z, sin(a) * s)


static func _nudge(p: Vector3, R: XRng, sd: float) -> Vector3:
	var q := Vector3(p.x + (R.next() + R.next() + R.next() - 1.5) * sd, p.y + (R.next() + R.next() + R.next() - 1.5) * sd, p.z + (R.next() + R.next() + R.next() - 1.5) * sd)
	return q.normalized()


## A world's lasting facts, from one seed: everything `planet.gdshader` is told
## that does not change from frame to frame. `seed` is the layout's (or the
## gallery's) seed; the painter's own runs from it as the mockup's did.
static func spec(world: StringName, seed: int, r: float) -> Dictionary:
	var W: Dictionary = WORLD[world]
	var R := XRng.new(floor(float(seed) * 7919.0) + 13.0)
	var s := {"world": world, "r": r}
	# the painter's seed, kept small: it offsets every noise lookup, and a large
	# offset costs the GPU's float its precision (the mockup's seeds were small)
	s.seed = fmod(float(seed) * 17.3, 4096.0)
	s.spin = (0.03 + R.next() * 0.05) * (-1.0 if R.next() < 0.15 else 1.0)
	s.tilt = (R.next() - 0.5) * 0.5
	if W.get("tail", false):
		R.next()
		s.ring = false
	elif W.get("giant", false):
		s.ring = R.next() < 0.6
	else:
		s.ring = R.next() < 0.08
	s.moons = 1 + int(R.next() * 3.0) if W.get("giant", false) else (1 if R.next() < 0.35 else 0)
	s.bands = 6.0 + floor(R.next() * 7.0)
	s.cloud_rate = 0.015 + R.next() * 0.02
	var craters: Array[Vector4] = []
	if W.get("crater", false):
		for i in 9:
			var a := R.next() * TAU
			var z := R.next() * 2.0 - 1.0
			var sq := sqrt(1.0 - z * z)
			craters.append(Vector4(cos(a) * sq, z, sin(a) * sq, 0.12 + R.next() * 0.22))
	s.craters = craters
	s.spot = Vector2.ZERO
	s.has_spot = false
	if W.get("spot", false):
		s.spot = Vector2(R.next() * TAU, (R.next() - 0.5) * 0.7)
		s.has_spot = true
	if W.get("tidal", false):
		s.spin = 0.0
	# a giant's two great storms and its small ovals
	var R3 := XRng.new(floor(s.seed * 71.0) + 9.0)
	var first: Vector4
	if s.has_spot and W.get("giant", false):
		first = Vector4(s.spot.x, s.spot.y, 0.44, 0.15)
	else:
		first = Vector4(R3.next() * TAU, (-1.0 if R3.next() < 0.5 else 1.0) * (0.22 + R3.next() * 0.25), 0.42 + R3.next() * 0.2, 0.14 + R3.next() * 0.06)
	var second := Vector4(first.x + PI + (R3.next() - 0.5), -signf(first.y) * (0.2 + R3.next() * 0.3), first.z * 0.75, first.w * 0.8)
	s.storms = [first, second]
	var R2 := XRng.new(floor(s.seed * 131.0) + 7.0)
	var ovals: Array[Vector4] = []
	var n_ov := 2 + int(R2.next() * 3.0)
	for i in n_ov:
		ovals.append(Vector4(R2.next() * TAU, (R2.next() - 0.5) * 1.3, 0.6 + R2.next() * 0.7, 1.0 if R2.next() < 0.5 else 0.0))
	s.ovals = ovals
	# the auroras' magnetic poles, tipped off the spin axis
	var tl: float = (1.0 if W.get("unlit", false) else 0.55) + fmod(s.seed, 1.0) * 0.12
	var az: float = s.seed * 2.3
	var axes: Array[Vector3] = []
	var e1s: Array[Vector3] = []
	var e2s: Array[Vector3] = []
	for pole in [1.0, -1.0]:
		var ax := Vector3(pole * sin(tl) * cos(az), pole * cos(tl), pole * sin(tl) * sin(az))
		var e1 := Vector3(ax.y, -ax.x, 0.0).normalized()
		var e2 := ax.cross(e1)
		axes.append(ax)
		e1s.append(e1)
		e2s.append(e2)
	s.aur_ax = axes
	s.aur_e1 = e1s
	s.aur_e2 = e2s
	# a city world's towns, or a planet-city's hubs
	var towns: Array[Vector4] = []
	if W.get("citylights", false):
		var RC := XRng.new(floor(s.seed * 97.0) + 5.0)
		if world == &"megacity":
			for k in 40:
				var h := sphere_rand(RC)
				towns.append(Vector4(h.x, h.y, h.z, 0.6 + RC.next() * 0.6))
		else:
			var tries := 0
			while tries < 400 and towns.size() < 64:
				tries += 1
				var h := sphere_rand(RC)
				towns.append(Vector4(h.x, h.y, h.z, pow(RC.next(), 3.0)))
	s.towns = towns
	return s


## The shader's flags for a kind of world.
static func flags(world: StringName) -> int:
	var W: Dictionary = WORLD[world]
	var f := 0
	if W.get("citylights", false):
		f |= F_CITY
	if world == &"megacity":
		f |= F_MEGACITY
	if W.get("lightning", false):
		f |= F_LIGHTNING
	if W.get("auroras", false):
		f |= F_AURORA
	if W.get("tail", false):
		f |= F_TAIL
	if W.get("giant", false):
		f |= F_GIANT
	return f


## How far the shader's square reaches from the world's centre, in game pixels:
## the world, its air, its auroras, a tail.
static func half_size(world: StringName, r: float) -> int:
	return int(ceil(r * (3.4 if WORLD[world].get("tail", false) else 1.25))) + 7


## LIGHTNING THIS MOMENT: the flashes and their bolts, as the mockup rolled them
## -- one chance in every 0.16 s slot, a flicker of strike, dark beat, strike,
## dying away. A storm world flashes often; a giant now and then, on its night
## side only. Returns [flashes (x, y, sigma, strength), bolts (x, y)] in pixels
## from the world's centre.
static func lightning(s: Dictionary, light: Vector3, t: float) -> Array:
	var W: Dictionary = WORLD[s.world]
	var storm_world: bool = W.get("lightning", false)
	if not storm_world and not W.get("giant", false):
		return [[], []]
	var r: float = s.r
	var ang: float = s.seed + t * s.spin
	var ca := cos(ang)
	var sa := sin(ang)
	var ct := cos(s.tilt)
	var st := sin(s.tilt)
	var flashes: Array[Vector4] = []
	var bolts: Array[Vector2] = []
	var SL := 0.16
	var k0 := int(floor(t / SL))
	for k in range(k0 - 4, k0 + 1):
		if h3(k, 3, int(floor(s.seed))) > (0.32 if storm_world else 0.14):
			continue
		var a := t - float(k) * SL
		var I := 1.0 if a < 0.05 else (0.15 if a < 0.11 else (0.75 if a < 0.19 else exp(-(a - 0.19) * 12.0)))
		var R := XRng.new(float(k) * 7919.0 + 11.0)
		var p := sphere_rand(R)
		var tx := p.x * ca - p.z * sa
		var v := Vector3(tx * ct + p.y * st, -tx * st + p.y * ct, p.x * sa + p.z * ca)
		var d := v.dot(light)
		var night := 0.0 if d > 0.12 else (1.0 if d < -0.12 else (0.12 - d) / 0.24)
		if v.z < 0.15 or (not storm_world and night < 0.6):
			continue
		var sx := v.x * r
		var sy := v.y * r
		var sg := (2.5 + R.next() * 3.0) if storm_world else (1.5 + R.next() * 1.5)
		flashes.append(Vector4(sx, sy, sg, I))
		if a < 0.05 or (a > 0.11 and a < 0.15):
			var bx := sx
			var by := sy
			for i in 5:
				bolts.append(Vector2(bx, by))
				bx += R.next() * 2.0 - 1.0
				by += R.next() * 1.6 - 0.2
		if flashes.size() >= 5:
			break
	return [flashes, bolts]
