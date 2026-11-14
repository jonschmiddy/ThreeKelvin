class_name SeqFourth
extends JumpSequence

## R2 THE FOURTH DIMENSION (Jon's own phrase; kept with its hypercube running off the left
## edge, Nov 10). The ship turns through a direction that isn't here: a hypercube of light
## unfolds round it, the hull bulges and turns inside out into its own mirror image, thins to
## a sliver along W and is gone; 4D motes cross our space after. Real 4D: r2.py's maths.
## Why: docs/why/SeqFourth.md#fourth-dimension

const SHADER := preload("res://shaders/jump/jump_r2.gdshader")
const CUBE := preload("res://shaders/jump/jump_r2_cube.gdshader")

const T_WAKE := 0.75
const T_UX := 1.25
const T_UY := 1.85
const T_UZ := 2.40
const T_UW := 2.90
const T_TURN0 := 3.05
const T_TURN1 := 5.30
const T_HUSH := 5.40
const T_HIT := 5.72
const T_BANG := 5.92
const UNFOLDS := [T_UX, T_UY, T_UZ, T_UW]
## The film's hull turned about its own middle (x 203, y 282: 113, 50 into the ink), its spine
## 70 px thick along W; the hypercube a unit 128 x 70 x 70 px, seen through W from 4 and Z from 7.
const AXIS := Vector2(113.0, 50.0)
const TMAX := 70.0
const TS := Vector3(128.0, 70.0, 70.0)
const DW := 4.0
const DZ := 7.0
const YAW := 0.42
const PITCH := 0.30
const MAXE := 800
## The light buffers' pre-scale: hot lines, the glow at full, half, eighth and sixteenth size, panes.
const K_CORE := 0.25
const K_SRC := [0.25, 0.5, 2.0, 4.0]
const SRC_CELL := [1.0, 2.0, 8.0, 16.0]
const K_FACE := 4.0
## The film's 120 motes (rng 42): where they start from the turn's axis (mirrored, as the hull
## went), their heading, speed, when each is widest, how long it takes to pass, its size, its side.
const MO_X := [42.00, -43.00, 30.00, 79.00, -69.00, -44.00, -16.00, 23.00, 60.00, 26.00, 22.00, -24.00, -45.00, 3.00, -51.00, 25.00, -23.00, -2.00, -5.00, 86.00, -44.00, 88.00, -17.00, -92.00, 17.00, 3.00, -70.00, 42.00, 54.00, 27.00, 3.00, 59.00, 8.00, -56.00, 39.00, 106.00, -97.00, -59.00, 41.00, 16.00, 27.00, 69.00, 105.00, 62.00, 102.00, -66.00, 45.00, 60.00, -9.00, 13.00, 48.00, 84.00, -3.00, 8.00, -28.00, 105.00, 59.00, 39.00, 46.00, -31.00, 19.00, 27.00, -51.00, -96.00, -2.00, -16.00, -36.00, 67.00, 51.00, 36.00, -24.00, 80.00, -90.00, -12.00, -6.00, 13.00, -52.00, 67.00, 18.00, 1.00, -6.00, 85.00, 32.00, -7.00, 14.00, 32.00, -37.00, 20.00, 62.00, -71.00, -33.00, -30.00, 9.00, -2.00, 92.00, -1.00, -58.00, 83.00, 68.00, 77.00, 18.00, 55.00, -102.00, -104.00, -3.00, -70.00, -89.00, 101.00, -9.00, 90.00, -80.00, -92.00, 58.00, -21.00, 55.00, -68.00, 47.00, -10.00, 14.00, -83.00]
const MO_Y := [14.00, -17.00, -36.00, 10.00, -11.00, 1.00, 7.00, -21.00, -16.00, -16.00, -18.00, 17.00, 16.00, -7.00, -4.00, 28.00, -9.00, -5.00, -21.00, 7.00, 7.00, 11.00, 5.00, -11.00, -22.00, -3.00, -15.00, -15.00, -6.00, -2.00, -1.00, -2.00, 12.00, 14.00, 6.00, 0.00, 1.00, 13.00, -14.00, 17.00, 11.00, 8.00, -3.00, 10.00, -5.00, 13.00, -18.00, -3.00, -2.00, 16.00, 11.00, -2.00, -1.00, 9.00, -15.00, 7.00, -12.00, 1.00, -14.00, 11.00, 11.00, -28.00, 13.00, -1.00, -3.00, 27.00, 6.00, 2.00, -21.00, 7.00, 10.00, 11.00, 8.00, 19.00, 9.00, -8.00, 13.00, 12.00, -19.00, -12.00, 27.00, 10.00, -3.00, 0.00, 1.00, 13.00, 10.00, 23.00, 5.00, -18.00, 14.00, -2.00, 2.00, 12.00, -3.00, -10.00, 4.00, 13.00, -6.00, 5.00, -23.00, -23.00, -4.00, 7.00, -13.00, 4.00, 6.00, -2.00, 19.00, -6.00, 11.00, -5.00, -20.00, -21.00, -8.00, -18.00, -26.00, -13.00, 6.00, -7.00]
const MO_ANG := [1.1226, -2.0855, -1.1959, 0.0148, -1.9851, 3.2527, 3.2622, -0.9831, 0.2308, 0.5126, -0.4933, 2.2978, 2.8800, -1.3714, -3.6756, 0.6503, -2.4469, -1.2476, -2.2262, -0.5820, 2.8200, -0.2236, 2.9008, -3.1663, -1.2774, -1.0501, -3.6640, 1.1095, -0.6041, -0.1409, -0.5994, -0.0073, 2.3898, 2.3404, 0.6164, 0.0262, 3.8670, 2.7388, 0.1029, 1.4657, 1.2588, -0.2333, 0.0066, -0.6261, 0.2698, 2.6115, -1.5262, -1.0816, -2.7387, 1.0049, 0.1490, 0.7169, -2.8141, 2.0080, -2.5958, -0.3305, -1.3557, 0.0948, -0.3852, 2.6677, -0.2163, -0.7047, 3.5688, -3.5752, -1.9624, 2.5699, 3.1904, -0.1416, -0.1989, 0.2267, 2.7339, -0.4220, 2.5719, 2.4437, 3.4576, -0.5800, 3.2294, 0.0229, -1.5599, -2.9699, 2.0220, 0.5125, 0.7210, 3.8435, 0.8537, -0.3970, 2.4843, 0.7284, 0.4118, -2.9368, 2.2960, -2.6249, 0.3127, 1.8309, 0.1491, -1.3133, 3.8783, -0.0566, 0.3183, 0.7021, -0.6827, -1.1079, -2.9816, 3.2088, -1.1163, 2.8819, 2.5176, 1.0065, 1.1478, 0.7674, 3.0936, -3.5385, -0.0910, -2.7131, 0.0481, -2.5703, -0.7230, -2.4389, -0.0085, -3.1580]
const MO_SP := [50.3914, 32.4722, 65.8067, 67.6793, 41.4796, 32.5679, 64.1850, 29.7491, 65.2967, 60.4682, 42.8432, 38.3654, 64.0330, 34.9248, 27.4944, 47.5654, 68.4223, 21.3820, 46.5425, 21.3392, 41.3607, 15.3921, 37.4704, 40.1734, 58.6218, 34.9543, 27.8790, 17.7273, 22.0568, 20.4674, 47.1041, 63.0003, 27.9657, 60.6737, 64.5486, 57.6238, 39.9168, 40.7611, 32.3398, 65.3155, 50.5449, 55.1540, 48.4053, 21.6948, 58.5264, 48.5053, 43.2674, 66.1492, 37.4421, 56.7018, 22.2759, 44.9676, 69.2514, 49.6761, 39.4418, 30.9079, 63.2352, 19.0647, 57.4990, 14.3041, 61.5669, 53.0948, 49.2807, 29.1625, 48.5133, 19.1364, 49.6389, 46.3690, 42.4678, 29.5722, 37.0614, 16.0194, 45.6832, 58.0962, 42.7134, 43.1354, 61.1516, 31.5780, 34.8466, 67.6720, 53.5028, 43.4049, 45.1343, 35.9841, 22.4377, 30.3553, 27.6454, 56.7226, 61.2908, 64.9349, 36.3189, 24.7298, 47.5147, 68.9811, 54.3590, 55.0152, 69.1364, 20.9367, 40.0385, 45.1059, 34.8713, 57.3284, 27.1340, 51.9281, 27.3089, 47.0579, 18.7494, 30.5963, 35.9727, 17.7613, 33.2244, 29.9343, 43.6544, 27.5168, 45.4434, 69.7033, 24.3700, 42.7130, 16.3004, 31.5039]
const MO_TC := [0.3400, 0.4752, 1.4574, 1.2352, 2.2601, 1.3215, 0.4656, 1.6337, 0.6680, 1.9686, 0.7259, 2.3828, 1.3174, 0.3626, 0.4262, 2.1178, 1.2767, 1.6747, 0.5995, 0.4284, 1.6414, 1.3992, 2.3240, 1.9157, 0.6734, 1.1082, 0.6825, 1.4875, 2.2222, 0.1976, 1.6816, 2.0650, 1.4353, 0.2669, 2.3540, 0.4527, 1.0165, 1.0880, 1.0038, 1.2320, 1.9599, 0.6054, 0.3640, 2.3075, 2.2786, 0.5354, 1.8688, 0.4194, 1.8922, 0.7587, 2.2563, 2.2563, 1.7650, 0.4243, 2.0071, 2.2165, 0.7888, 2.1683, 0.5960, 0.2662, 0.2788, 2.0355, 2.0650, 1.7473, 0.2453, 0.5629, 1.4379, 1.7245, 1.0591, 0.8356, 1.0698, 1.0914, 1.7295, 1.3856, 1.8076, 1.9497, 0.2750, 1.8211, 0.4956, 2.3898, 1.0226, 0.5184, 2.0379, 0.3301, 0.5571, 1.2529, 2.0481, 0.2807, 1.2358, 1.4710, 2.2140, 0.2059, 0.1665, 1.5458, 2.3172, 1.1402, 0.7985, 0.2421, 2.3503, 1.9546, 0.2596, 2.0973, 1.5493, 0.2166, 2.0688, 1.0431, 0.9193, 1.0679, 2.2094, 0.6045, 1.0959, 2.1682, 1.8202, 0.8756, 1.9319, 1.6678, 1.4149, 1.1242, 0.7036, 0.2647]
const MO_TAU := [0.6203, 0.4172, 0.5755, 0.8588, 0.7216, 0.6353, 0.7101, 0.8225, 0.3743, 0.5561, 0.9584, 0.9296, 0.5554, 0.8354, 0.8902, 0.4777, 0.4435, 0.4292, 0.8727, 0.9529, 0.9712, 0.7621, 0.7374, 0.3616, 0.6950, 0.7738, 0.8349, 0.4450, 0.4576, 0.3860, 0.6059, 0.3783, 0.6206, 0.9511, 0.8713, 0.6984, 0.7657, 0.5012, 0.7957, 0.5634, 0.6963, 0.8016, 0.8217, 0.8706, 0.5147, 0.7172, 0.8695, 0.4261, 0.7863, 0.5867, 0.6346, 0.8572, 0.9683, 0.7324, 0.5420, 0.8578, 0.8940, 0.3688, 0.9419, 0.7439, 0.8706, 0.3761, 0.4509, 0.9871, 0.9247, 0.9870, 0.4443, 0.7720, 0.6582, 0.6281, 0.4915, 0.6582, 0.7712, 0.6304, 0.9262, 0.5544, 0.5324, 0.3595, 0.7405, 0.8519, 0.7666, 0.4578, 0.9937, 0.8410, 0.9396, 0.7312, 0.7644, 0.5883, 0.8496, 0.9027, 0.7600, 0.9528, 0.5307, 0.6604, 0.8583, 0.7095, 0.8269, 0.8553, 0.6175, 0.9511, 0.4210, 0.8306, 0.9078, 0.6109, 0.5762, 0.5286, 0.8165, 0.4389, 0.6730, 0.3615, 0.9735, 0.5028, 0.7340, 0.4510, 0.8595, 0.8795, 0.4162, 0.3733, 0.3926, 0.4225]
const MO_R := [2.5000, 1.0000, 2.5000, 2.5000, 1.0000, 2.0000, 1.0000, 1.0000, 3.2000, 2.0000, 5.5000, 1.0000, 3.2000, 3.2000, 1.5000, 1.0000, 1.5000, 1.0000, 2.0000, 3.2000, 2.0000, 1.5000, 1.0000, 5.5000, 1.0000, 2.5000, 4.2000, 4.2000, 4.2000, 1.5000, 1.0000, 1.5000, 1.0000, 1.0000, 1.0000, 4.2000, 2.0000, 1.5000, 2.0000, 1.5000, 2.0000, 2.5000, 4.2000, 1.0000, 2.5000, 2.5000, 2.5000, 2.0000, 1.0000, 2.0000, 1.5000, 2.0000, 2.0000, 1.0000, 3.2000, 2.0000, 1.0000, 1.0000, 1.5000, 2.5000, 4.2000, 5.5000, 1.0000, 3.2000, 2.5000, 3.2000, 2.0000, 5.5000, 5.5000, 1.0000, 2.5000, 2.5000, 1.5000, 2.5000, 2.5000, 5.5000, 4.2000, 2.0000, 4.2000, 1.0000, 1.5000, 1.0000, 4.2000, 1.0000, 2.0000, 1.0000, 2.0000, 2.5000, 2.0000, 4.2000, 2.0000, 1.0000, 2.0000, 3.2000, 3.2000, 4.2000, 2.5000, 3.2000, 2.0000, 4.2000, 4.2000, 3.2000, 4.2000, 1.0000, 5.5000, 4.2000, 4.2000, 4.2000, 2.5000, 1.0000, 2.0000, 3.2000, 1.5000, 2.5000, 4.2000, 2.0000, 5.5000, 2.5000, 5.5000, 2.0000]
const MO_SGN := [1.0000, -1.0000, 1.0000, -1.0000, 1.0000, -1.0000, -1.0000, 1.0000, -1.0000, -1.0000, -1.0000, -1.0000, -1.0000, -1.0000, 1.0000, -1.0000, 1.0000, -1.0000, -1.0000, -1.0000, 1.0000, 1.0000, -1.0000, 1.0000, 1.0000, 1.0000, 1.0000, -1.0000, -1.0000, -1.0000, 1.0000, -1.0000, -1.0000, 1.0000, 1.0000, -1.0000, -1.0000, -1.0000, -1.0000, -1.0000, 1.0000, 1.0000, 1.0000, -1.0000, 1.0000, -1.0000, 1.0000, 1.0000, 1.0000, 1.0000, 1.0000, 1.0000, -1.0000, -1.0000, 1.0000, 1.0000, -1.0000, -1.0000, -1.0000, 1.0000, 1.0000, -1.0000, 1.0000, 1.0000, -1.0000, 1.0000, -1.0000, -1.0000, -1.0000, 1.0000, 1.0000, -1.0000, 1.0000, 1.0000, -1.0000, 1.0000, 1.0000, -1.0000, 1.0000, -1.0000, -1.0000, -1.0000, 1.0000, -1.0000, 1.0000, 1.0000, 1.0000, 1.0000, 1.0000, -1.0000, -1.0000, 1.0000, -1.0000, 1.0000, -1.0000, 1.0000, 1.0000, 1.0000, -1.0000, -1.0000, 1.0000, -1.0000, -1.0000, 1.0000, 1.0000, 1.0000, -1.0000, -1.0000, -1.0000, -1.0000, 1.0000, 1.0000, 1.0000, -1.0000, 1.0000, 1.0000, -1.0000, 1.0000, 1.0000, 1.0000]

var sc := Vector2.ZERO
var kk := 1.0
var _cube_mats: Array[ShaderMaterial] = []
var _bufs: Array[SubViewport] = []
var _ready := false


func _init() -> void:
	id = &"r2"
	length = 10.6
	hit_t = T_BANG
	cut_t = 5.6
	commit_t = 9.4
	swap_t = 0.6


func setup(_stage: JumpStage, _place: JumpPlace, _hull: JumpHull) -> void:
	super(_stage, _place, _hull)
	stage.build(SHADER, place.window)
	kk = place.hull_k
	sc = place.ink.position + AXIS * place.ink.size / Vector2(236.0, 93.0)
	stage.set1(&"sc", sc)
	stage.set1(&"ship", Vector4(place.canvas.position.x, place.canvas.position.y, place.canvas.size.x, place.canvas.size.y))
	stage.set1(&"tmax", TMAX * kk)
	stage.set1(&"ts", Vector2(TS.x, TS.y) * kk)
	# the fringe on the bang is a sideways slip of red and blue (an event far to the left)
	stage.set2(&"centre", Vector2(-1e5, sc.y))
	# (its flash is the world pass's own light; the finish's stays off)
	stage.set2(&"flash_floor", flash_floor)
	_build_cube()


## The hypercube's light buffers: hot lines, the glow at four sizes, the cells' panes.
func _build_cube() -> void:
	var n := 32 * MAXE + 16 + 120
	_cube_buf(1.0, &"l_core", n, {target = 0, gain_k = K_CORE})
	for i in 4:
		_cube_buf(float(SRC_CELL[i]), StringName("l_src%d" % [0, 1, 3, 4][i]), n, {target = 1, gain_k = float(K_SRC[i])})
	_cube_buf(1.0, &"l_face", 24, {target = 2, gain_k = K_FACE})
	var ma := PackedVector4Array()
	var mb := PackedVector4Array()
	for i in MO_X.size():
		ma.append(Vector4(MO_X[i], MO_Y[i], MO_ANG[i], MO_SP[i]))
		mb.append(Vector4(MO_TC[i], MO_TAU[i], MO_R[i], MO_SGN[i]))
	for m in _cube_mats:
		m.set_shader_parameter(&"mo_a", ma)
		m.set_shader_parameter(&"mo_b", mb)
		m.set_shader_parameter(&"mo_k", kk)
		m.set_shader_parameter(&"maxe", MAXE)
		m.set_shader_parameter(&"sc", sc)
		m.set_shader_parameter(&"tmax", TMAX * kk)
		m.set_shader_parameter(&"ship", Vector4(place.canvas.position.x, place.canvas.position.y, place.canvas.size.x, place.canvas.size.y))


func _cube_buf(cell: float, pname: StringName, n: int, params: Dictionary) -> void:
	var v := SubViewport.new()
	v.size = Vector2i((place.window.size / cell).ceil())
	v.transparent_bg = true
	v.disable_3d = true
	v.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	stage.add_child(v)
	v.canvas_transform = Transform2D(0.0, Vector2(1.0 / cell, 1.0 / cell), 0.0, -place.window.position / cell)
	stage.set1(pname, v.get_texture())
	_bufs.append(v)
	var m := ShaderMaterial.new()
	m.shader = CUBE
	m.set_shader_parameter(&"cell", cell)
	m.set_shader_parameter(&"origin", place.window.position)
	for key in params:
		m.set_shader_parameter(StringName(key), params[key])
	var node := ChartSky.MeshDraw.new()
	node.mesh = MapChart.empty_quads(n)
	node.material = m
	v.add_child(node)
	_cube_mats.append(m)


func hull_ready() -> void:
	super()
	for m in _cube_mats:
		m.set_shader_parameter(&"hull", hull.tex)
		m.set_shader_parameter(&"aux", hull.aux)
		m.set_shader_parameter(&"d_in_max", hull.d_in_max)
	_ready = true


static func span(t: float, a: float, b: float) -> float:
	return clampf((t - a) / (b - a), 0.0, 1.0)


static func ease_out(u: float, p: float = 3.0) -> float:
	return 1.0 - pow(1.0 - clampf(u, 0.0, 1.0), p)


static func ease_in(u: float, p: float = 2.0) -> float:
	return pow(clampf(u, 0.0, 1.0), p)


## Ease out with an overshoot: a snap that lands.
static func back(u: float, s: float = 2.2) -> float:
	u = clampf(u, 0.0, 1.0) - 1.0
	return u * u * ((s + 1.0) * u + s) + 1.0


## The XW, YW and ZW angles: a carries the hull from itself to its mirror image.
static func turn_angles(t: float) -> Vector3:
	var u := span(t, T_TURN0, T_TURN1)
	var a := PI * (0.5 - 0.5 * cos(PI * pow(u, 1.35)))
	if t > T_TURN1:
		a = PI + 0.04 * minf(t - T_TURN1, 0.5)
	var b := 0.28 * sin(PI * u) * (1.0 if u < 1.0 else 0.0)
	var c := 1.4 * PI * ease3(u) + 0.6 * maxf(0.0, t - T_TURN1)
	return Vector3(a, b, c)


## R = R_xw(a) R_yw(b) R_zw(c), row-major 4 x 4.
static func rot4(a: float, b: float, c: float) -> PackedFloat64Array:
	return _mul4(_mul4(_r4(0, 3, a), _r4(1, 3, b)), _r4(2, 3, c))


static func _r4(i: int, j: int, th: float) -> PackedFloat64Array:
	var m := PackedFloat64Array([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])
	m[i * 4 + i] = cos(th)
	m[j * 4 + j] = cos(th)
	m[i * 4 + j] = -sin(th)
	m[j * 4 + i] = sin(th)
	return m


static func _mul4(x: PackedFloat64Array, y: PackedFloat64Array) -> PackedFloat64Array:
	var o := PackedFloat64Array()
	o.resize(16)
	for i in 4:
		for j in 4:
			var s := 0.0
			for k in 4:
				s += x[i * 4 + k] * y[k * 4 + j]
			o[i * 4 + j] = s
	return o


## The unfold (point, line, square, cube, hypercube, each a snap), and the fold back, W first.
static func unfold_ext(t: float) -> Vector4:
	var e := Vector4.ZERO
	for i in 4:
		e[i] = back(span(t, UNFOLDS[i], UNFOLDS[i] + 0.30))
	if t >= T_HIT:
		var fold := [[0.12, 0.20], [0.08, 0.16], [0.04, 0.12], [0.0, 0.08]]
		for i in 4:
			e[3 - i] *= 1.0 - ease_in(span(t, T_HIT + fold[i][0], T_HIT + fold[i][1]), 1.5)
	return e


## The 16 corners on screen: x, y, and their place along W and in depth (r2.py `tess_project`).
func project(R: PackedFloat64Array, ext: Vector4, yaw: float, scale: float) -> PackedVector4Array:
	var out := PackedVector4Array()
	var cy := cos(yaw)
	var sy := sin(yaw)
	var cp := cos(PITCH)
	var sp := sin(PITCH)
	for i in 16:
		var v := Vector4(float((i & 1) * 2 - 1) * ext.x, float(((i >> 1) & 1) * 2 - 1) * ext.y,
			float(((i >> 2) & 1) * 2 - 1) * ext.z, float(((i >> 3) & 1) * 2 - 1) * ext.w)
		var r := Vector4.ZERO
		for row in 4:
			r[row] = R[row * 4] * v.x + R[row * 4 + 1] * v.y + R[row * 4 + 2] * v.z + R[row * 4 + 3] * v.w
		var kw := DW / (DW - r.w)
		var p := Vector3(r.x, r.y, r.z) * kw
		var x := p.x * cy + p.z * sy
		var z := -p.x * sy + p.z * cy
		var y := p.y * cp - z * sp
		z = p.y * sp + z * cp
		var kz := DZ / (DZ - z)
		out.append(Vector4(sc.x + scale * TS.x * kk * x * kz, sc.y + scale * TS.y * kk * y * kz, r.w, z))
	return out


func step(t: float) -> void:
	var ang := turn_angles(t)
	var R := rot4(ang.x, ang.y, 0.0)
	var turning := ease3(span(t, T_TURN0, T_TURN0 + 0.5))
	var gone := t >= T_HIT + 0.2
	stage.set1(&"turning", turning)
	_step_space(t, turning)
	_step_hull(t, ang, R, turning, gone)
	_step_cube(t, ang, turning)
	# the bang: the frame lit for two frames (a local glow with fewer flashes), a slip of colour
	var kb := t - T_BANG
	var fl := Vector2(0.0, 1.0)
	flash = 0.0
	if kb >= 0.0 and kb < 0.07:
		fl.x = 2.2 if kb < 0.034 else 0.8
		flash = fl.x / 2.2
		if reduce:
			fl = Vector2(minf(fl.x, 0.35), 0.35)
			flash = minf(flash, 0.35)
	stage.set1(&"bang_fl", fl)
	stage.set1(&"k_bang", kb)
	stage.set2(&"fringe", roundf(4.0 * (1.0 - kb / 0.25)) if (kb >= 0.0 and kb < 0.25) else 0.0)
	# the shake builds through the turn, stops dead in the hush, 7 px on the bang
	var amp := 0.0
	if t >= T_UW and t < T_HUSH:
		amp = 0.4 + 2.2 * pow(span(t, T_UW, T_HUSH), 1.5)
	if t >= T_BANG:
		amp = 7.0 * exp(-(t - T_BANG) / 0.22)
	var fr := int(floor(t * 30.0)) + 99
	set_shake(Vector2(amp * (held_rand(fr, 1) * 2.0 - 1.0), amp * 0.7 * (held_rand(fr, 2) * 2.0 - 1.0)))


## Space: it turns with the hull inside the hypercube, echoes its stars along W, dims, ripples.
func _step_space(t: float, turning: float) -> void:
	var shear := 0.0
	if t >= T_TURN0 and t < T_BANG + 0.05:
		shear = turning * (1.0 - ease3(span(t, T_HIT, T_BANG)))
	stage.set1(&"shear", shear)
	var settle := exp(-(t - T_BANG) / 0.7) if t >= T_BANG else 0.0
	var es := 0.0
	var kw := Vector2.ONE
	if shear > 0.02 or settle > 0.03:
		es = maxf(shear, settle)
		var f := shear if shear > 0.02 else sqrt(settle)
		kw = Vector2(1.0 + 0.28 * f, 1.0 - 0.20 * f)
	stage.set1(&"echo_s", es)
	stage.set1(&"echo_kw", kw)
	var dim := 0.30 * ease3(span(t, T_UW - 0.3, T_TURN1)) + 0.12 * span(t, T_HUSH, T_HIT)
	stage.set1(&"dim", dim * (1.0 - ease3(span(t, T_BANG + 0.3, T_BANG + 2.5))))


## The hull's cut and its two copies, and the drive's strain on it.
func _step_hull(t: float, ang: Vector3, R: PackedFloat64Array, turning: float, gone: bool) -> void:
	var w0 := 0.0
	if t >= T_HIT:
		w0 = TMAX * kk * 1.01 * pow(ease_out(span(t, T_HIT, T_HIT + 0.22), 1.3), 0.55)
	var cut := t < T_HIT + 0.2
	var ru := PackedVector2Array([Vector2(R[0], R[4]), Vector2.ZERO, Vector2.ZERO])
	var rv := PackedVector2Array([Vector2(R[1], R[5]), Vector2.ZERO, Vector2.ZERO])
	var rw := PackedVector2Array([Vector2(R[3], R[7]), Vector2.ZERO, Vector2.ZERO])
	var cp := PackedVector4Array([Vector4(0.0, 0.0, 1.0, w0), Vector4(0, 0, 1, 0), Vector4(0, 0, 1, 0)])
	var echo := 0.0
	if cut:
		echo = turning * (1.0 - span(t, T_HIT, T_HIT + 0.06))
		var sep := 0.22 + 0.25 * ease3(span(t, T_TURN0, T_TURN1))
		sep *= 1.0 - 0.85 * ease_in(span(t, T_HUSH, T_HIT + 0.04), 2.0)
		for i in 2:
			var sgn := 1.0 if i == 0 else -1.0
			var Re := rot4(ang.x + sgn * 0.45 * sep / 0.47, ang.y - sgn * 0.12, 0.0)
			ru[i + 1] = Vector2(Re[0], Re[4])
			rv[i + 1] = Vector2(Re[1], Re[5])
			rw[i + 1] = Vector2(Re[3], Re[7])
			var off := Vector2(46.0, -20.0) * sgn * sep * kk
			cp[i + 1] = Vector4(off.x, off.y, DW / (DW - sgn * sep * 1.6), w0 + sgn * sep * 0.5 * TMAX * kk)
	for m: ShaderMaterial in [stage.mat1] + _cube_mats:
		m.set_shader_parameter(&"ru", ru)
		m.set_shader_parameter(&"rv", rv)
		m.set_shader_parameter(&"rw", rw)
		m.set_shader_parameter(&"cut_p", cp)
		m.set_shader_parameter(&"hull_cut", 1.0 if (cut and _ready) else 0.0)
	stage.set1(&"echo", echo if echo > 0.01 else 0.0)
	# the drive wakes: light gathers from the core and runs out along the seams; a star at its heart
	var wake := ease3(span(t, T_WAKE, T_UW))
	var pulse := 0.0
	for i in 4:
		var k := t - float(UNFOLDS[i])
		if k >= 0.0 and k < 0.5:
			pulse += exp(-k / 0.09) * (0.6 + 0.25 * float(i))
	var reach := 20.0 + 260.0 * ease3(span(t, T_WAKE, T_TURN0 + 0.4)) if t >= T_WAKE else -1e3
	stage.set1(&"strain", Vector4(0.0 if gone else 1.0, wake, pulse, reach))
	var star := Vector3.ZERO
	if t >= T_WAKE and t < T_HIT + 0.15:
		var pk := ease_out(span(t, T_WAKE, T_WAKE + 0.35))
		star = Vector3(1.0, pk, floorf(3.0 + 9.0 * pk * (0.5 + 0.5 * wake) + 14.0 * pulse))
	stage.set1(&"star", star)


## The hypercube: unfolding, turning with beads of energy along its edges, folding to a point;
## then its faint afterimage swelling outward; and the motes after the bang.
func _step_cube(t: float, ang: Vector3, turning: float) -> void:
	var on := 0.0
	var faces := 0.0
	var gain := 0.0
	var beads := 0.0
	var bead_ph := 0.0
	var vx := PackedVector4Array()
	var ext := Vector4.ONE
	var yaw := YAW + 0.25 * ease3(span(t, T_UZ, T_TURN1)) + 0.05 * sin(t * 0.7)
	if t >= T_UX and t < T_BANG + 0.02:
		on = 1.0
		faces = 1.0
		ext = unfold_ext(t)
		gain = 0.55 + 0.35 * turning
		for u: float in UNFOLDS:
			var k := t - u
			if k >= 0.0 and k < 0.4:
				gain += 1.2 * exp(-k / 0.08)
		if t > T_HUSH:
			gain *= 0.75 + 1.8 * ease_in(span(t, T_HIT, T_BANG), 2.0)
		beads = ease3(span(t, T_UW, T_UW + 0.6)) * (1.0 - span(t, T_HUSH, T_HUSH + 0.1)) * 1.6
		if t >= T_HIT:
			beads += 2.0 * span(t, T_HIT, T_BANG)
		bead_ph = t * (0.6 + 1.6 * ease3(span(t, T_UW, T_TURN1)))
		vx = project(rot4(ang.x, ang.y, ang.z), ext, yaw, 1.0)
	elif t >= T_BANG + 0.02 and t < T_BANG + 2.2:
		on = 1.0
		var k := t - T_BANG
		var a0 := turn_angles(T_HIT)
		gain = 0.24 * exp(-k / 0.6) * (1.0 - span(k, 1.6, 2.2))
		vx = project(rot4(a0.x + 0.5 * k, a0.y + 0.2 * k, a0.z + 0.9 * k), ext, yaw, 1.12 + 0.9 * ease_out(k / 2.2, 2.0))
	else:
		vx.resize(16)
	var kb := t - T_BANG
	var motes := false
	if kb >= 0.0:
		for i in MO_TC.size():
			var q := kb - float(MO_TC[i]) + float(MO_TAU[i])
			if q >= 0.0 and q <= 2.0 * float(MO_TAU[i]):
				motes = true
				break
	for m in _cube_mats:
		m.set_shader_parameter(&"cube_on", on)
		m.set_shader_parameter(&"faces_on", faces)
		m.set_shader_parameter(&"vx", vx)
		m.set_shader_parameter(&"ext", ext)
		m.set_shader_parameter(&"gain", gain)
		m.set_shader_parameter(&"beads", beads)
		m.set_shader_parameter(&"bead_ph", bead_ph)
		m.set_shader_parameter(&"mote", Vector4(1.0 if kb >= 0.0 else 0.0, kb, sc.x, sc.y))
	stage.set1(&"src_any", 1.0 if (on > 0.5 or motes) else 0.0)


func teardown() -> void:
	for v in _bufs:
		if is_instance_valid(v):
			v.queue_free()
	_bufs.clear()
