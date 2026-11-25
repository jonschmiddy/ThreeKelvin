shader_type canvas_item;
render_mode unshaded;

// Korvan's finish over the room, before the banners (mix18._finish): the worn deck's sheen mirroring what
// is bright over it, the haze (thick on the far wall, clear on the near floor, the crane crisp), and bloom
// round what burns. Stepped on the frame's grid as the film's were. Why: docs/why/ShipRoomKorvan.md#air

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D air1 : filter_nearest, repeat_disable;
uniform sampler2D atlas : filter_nearest, repeat_disable;
// the crane's drawn pieces this frame (frame rect, atlas rect): the load, the trolley, the drones' load
uniform vec4 m_rect[4];
uniform vec4 m_src[4];
// plain boxes of it: the hook block, the spreader, the two cargo drones
uniform vec4 m_box[4];

varying vec2 fp;

const vec3 HAZE_BASE = vec3(10.0, 15.0, 26.0);

void vertex() {
	fp = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

float bay(ivec2 q) {
	float B[16] = float[](0., 8., 2., 10., 12., 4., 14., 6., 3., 11., 1., 9., 15., 7., 13., 5.);
	return B[(q.y & 3) * 4 + (q.x & 3)] / 16.0;
}

vec3 px(ivec2 q) {
	return texelFetch(screen, clamp(q, ivec2(0), ivec2(959, 539)), 0).rgb * 255.0;
}

vec3 stepq(vec3 a, float scale, ivec2 q) {
	vec3 v = a / scale * 6.0;
	vec3 lo = floor(v);
	vec3 up = vec3(greaterThan(v - lo, vec3(bay(q))));
	return (lo + up) * scale / 6.0;
}

// the sheen's mirrored light landing on q before its blur (hero.sheen's lines)
vec3 sheen_at(ivec2 q) {
	vec3 add = vec3(0.0);
	vec4 L[5] = vec4[](vec4(0.0, 960.0, 207.0, 40.0), vec4(330.0, 640.0, 334.0, 30.0), vec4(90.0, 330.0, 372.0, 22.0),
		vec4(650.0, 910.0, 372.0, 22.0), vec4(440.0, 492.0, 342.0, 22.0));
	float K[5] = float[](0.30, 0.30, 0.28, 0.28, 0.40);
	for (int i = 0; i < 5; i++) {
		float d = float(q.y) - L[i].z;
		if (float(q.x) >= L[i].x && float(q.x) < L[i].y && d >= 1.0 && d < L[i].w && L[i].z - d >= 0.0) {
			vec3 b = max(px(ivec2(q.x, int(L[i].z - d))) - 70.0, vec3(0.0));
			add += b * K[i] * pow(1.0 - d / L[i].w, 1.5);
		}
	}
	return add;
}

bool in_crane(ivec2 q) {
	vec2 p = vec2(q) + 0.5;
	for (int i = 0; i < 4; i++) {
		vec4 r = m_rect[i];
		if (r.z > 0.0 && p.x >= r.x && p.y >= r.y && p.x < r.x + r.z && p.y < r.y + r.w) {
			vec2 s = m_src[i].xy + floor(p - r.xy);
			if (texelFetch(atlas, ivec2(s), 0).a > 0.5) {
				return true;
			}
		}
		vec4 b = m_box[i];
		if (b.z > 0.0 && p.x >= b.x && p.y >= b.y && p.x < b.x + b.z && p.y < b.y + b.w) {
			return true;
		}
	}
	return false;
}

void fragment() {
	ivec2 q = ivec2(floor(fp));
	vec3 o = px(q);
	vec4 m = texelFetch(air1, q, 0);
	if (m.w > 0.5) {
		vec3 s = vec3(0.0);
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				s += sheen_at(q + ivec2(dx, dy));
			}
		}
		o += stepq(s / 9.0, 48.0, q);
	}
	// the haze scatters the room's light: its colour is the room blurred wide (21 px), dimmed
	vec3 blur = vec3(0.0);
	vec2 sz = vec2(960.0, 540.0);
	for (int j = -2; j <= 2; j++) {
		for (int i = -2; i <= 2; i++) {
			blur += textureLod(screen, (vec2(q) + 0.5 + vec2(float(i), float(j)) * 4.0) / sz, 2.0).rgb;
		}
	}
	vec3 hz = HAZE_BASE + blur / 25.0 * 255.0 * 0.45;
	float k = in_crane(q) ? 0.17 : m.z * 255.0 / 240.0;
	o = o * (1.0 - k) + hz * k;
	// bloom round what burns: a near 7 px box and a wide 19 px one of the bright part, stepped
	vec3 b3 = vec3(0.0);
	vec3 b9 = vec3(0.0);
	for (int dy = -9; dy <= 9; dy++) {
		for (int dx = -9; dx <= 9; dx++) {
			bool near = abs(dx) <= 3 && abs(dy) <= 3;
			bool far = (abs(dx) % 3 == 0) && (abs(dy) % 3 == 0);
			if (!near && !far) {
				continue;
			}
			ivec2 r = q + ivec2(dx, dy);
			float kr = texelFetch(air1, clamp(r, ivec2(0), ivec2(959, 539)), 0).z * 255.0 / 240.0;
			vec3 c = px(r) * (1.0 - kr) + hz * kr;
			float lum = dot(c, vec3(0.3, 0.55, 0.15));
			vec3 src = c * clamp((lum - 185.0) / 70.0, 0.0, 1.0);
			if (near) {
				b3 += src;
			}
			if (far) {
				b9 += src;
			}
		}
	}
	vec3 bl = b3 / 49.0 * 0.6 + b9 / 49.0 * 0.5;
	o += stepq(bl, 72.0, q);
	COLOR = vec4(o / 255.0, 1.0);
}
