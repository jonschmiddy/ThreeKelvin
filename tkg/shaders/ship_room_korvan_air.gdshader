shader_type canvas_item;
render_mode unshaded, blend_add;

// Korvan's air added over the room (hero.py, atmos20): mode 0 the shafts under each tube, the berth lamps and
// the door (each at its own weight, the crane's load cutting the berths') and the high haze in the cones,
// 2 round 20's motes in the cones, moved here from their baked places.
// Why: docs/why/ShipRoomKorvan.md#air

uniform int mode = 0;
uniform sampler2D air0 : filter_nearest, repeat_disable;
uniform sampler2D air1 : filter_nearest, repeat_disable;
uniform sampler2D air2 : filter_nearest, repeat_disable;
// round 20's motes (atmos20): their held positions per frame (motes20.png, +64), size, base, glint
uniform sampler2D motes : filter_nearest, repeat_disable;
uniform int frame = 0;
uniform float t = 0.0;
uniform float m_base[200];
uniform float m_kg[200];
uniform float m_p3[200];
uniform float tw[24];
uniform float lk = 1.0;
uniform float op = 0.0;
uniform vec4 crane = vec4(-9999.0, -9999.0, 999.0, 0.0);
uniform vec2 drone_load = vec2(-9999.0, 0.0);

varying vec2 fp;
varying vec4 vc;

const vec3 COOL = vec3(214.0, 226.0, 250.0) / 255.0;

// the cones' light this frame, 0..1+ (mix21: the wall shafts, each berth's by its lamp, the door's while open)
float cone_light(ivec2 q) {
	vec4 a = texelFetch(air0, q, 0) * 255.0 / 240.0;
	vec4 b = texelFetch(air1, q, 0) * 255.0 / 240.0;
	float f = max(a.x * lk, max(a.z * 0.72 * lk, max(a.w * 0.92 * lk, b.x * 0.92 * lk)));
	return op > 0.0 ? max(f, b.y * op) : f;
}

void vertex() {
	vc = COLOR;
	if (mode == 2) {
		// mote i: a rect drawn once at x 4i, moved to its held place this frame; its light worked out here
		int i = int(floor(VERTEX.x / 4.0));
		vec2 corner = VERTEX - vec2(float(4 * i), 0.0);
		ivec4 m = ivec4(round(texelFetch(motes, ivec2(i, frame), 0) * 255.0));
		ivec2 p = ivec2(m.r | (m.g << 8), m.b | (m.a << 8)) - 64;
		float a = 0.0;
		if (p.x >= 0 && p.x < 959 && p.y >= 0 && p.y < 539) {
			float s = cone_light(p);
			float gl = 0.55 + 0.45 * sin(2.0 * PI * m_kg[i] * t / 30.0 + m_p3[i]);
			a = s < 0.12 ? 0.0 : m_base[i] * min(1.0, s) * gl * 2.2;
		}
		vc = vec4(COOL * a, 1.0);
		VERTEX = vec2(p) + corner;
	}
	fp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
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
		// round 20: a faint cool haze high in the hall inside the cones, so they read as volume
		add += texelFetch(air2, q, 0).r * 255.0 / 240.0 * 7.0 * lk * COOL;
		COLOR = vec4(add / 255.0, 1.0);
	} else if (mode == 2) {
		COLOR = vc;
	}
}
