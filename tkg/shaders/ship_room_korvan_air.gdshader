shader_type canvas_item;
render_mode unshaded, blend_add;

// Korvan's air added over the room (hero.py): mode 0 the shafts under each tube, the berth lamps and the
// door (each at its own weight, the crane's load cutting the berths'), 1 the dust motes drifting in them.
// Why: docs/why/ShipRoomKorvan.md#air

uniform int mode = 0;
uniform sampler2D air0 : filter_nearest, repeat_disable;
uniform sampler2D air1 : filter_nearest, repeat_disable;
uniform float tw[24];
uniform float lk = 1.0;
uniform float op = 0.0;
uniform vec4 crane = vec4(-9999.0, -9999.0, 999.0, 0.0);
uniform vec2 drone_load = vec2(-9999.0, 0.0);

varying vec2 fp;
varying vec4 vc;

void vertex() {
	fp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	vc = COLOR;
}

float crane_cm(float x) {
	float c = clamp(min(x - crane.x, crane.y - x) / 6.0, 0.0, 1.0);
	float h = drone_load.y;
	float d = clamp(min(x - (drone_load.x - h), (drone_load.x + h) - x) / 6.0, 0.0, 1.0) * 0.5;
	return max(c, d);
}

void fragment() {
	if (mode == 0) {
		ivec2 q = ivec2(floor(fp));
		vec4 a = texelFetch(air0, q, 0);
		vec4 b = texelFetch(air1, q, 0);
		int i = int(round(a.y * 255.0));
		float w = i > 0 ? tw[i - 1] : 0.0;
		vec3 add = a.x * 255.0 / 240.0 * w * 32.0 * vec3(1.0, 0.92, 0.78);
		float cut = 1.0 - 0.85 * crane_cm(float(q.x)) * (float(q.y) >= crane.z ? 1.0 : 0.0);
		float berth = (a.z * 0.92 + a.w * 0.92 + b.x * 0.92) * 255.0 / 240.0;
		berth += a.z * 255.0 / 240.0 * (0.72 - 0.92);
		add += berth * lk * 30.0 * cut * vec3(0.84, 0.92, 1.0);
		add += b.y * 255.0 / 240.0 * op * 44.0 * vec3(1.0, 0.74, 0.42);
		COLOR = vec4(add / 255.0, 1.0);
	} else {
		// a mote: a 2 x 1 rect, its glint in COLOR.r; lit by the shaft at its left pixel
		ivec2 q = ivec2(int(floor(fp.x / 2.0)) * 2, int(floor(fp.y)));
		vec4 a = texelFetch(air0, q, 0);
		vec4 b = texelFetch(air1, q, 0);
		float s = max(a.x * 255.0 / 240.0 * lk, max(b.y * 255.0 / 240.0 * op, a.z * 255.0 / 240.0 * 0.5));
		float al = s > 0.15 ? 0.35 * s * vc.r : 0.0;
		COLOR = vec4(vec3(255.0, 236.0, 200.0) / 255.0 * al * 0.5, 1.0);
	}
}
