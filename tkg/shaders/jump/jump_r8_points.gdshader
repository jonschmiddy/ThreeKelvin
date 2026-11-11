shader_type canvas_item;
render_mode unshaded, blend_add, skip_vertex_transform;

// R8 MAELSTROM's points of light, into the warp field's light buffer (pre-scaled by 0.25), each a
// whole pixel placed in closed form: kind 0 the 260 stars dragged down the spiral, six-pixel
// trails on their own flow clock, a quarter of them near (a 3x3 glow, in front of the hull), the
// rest behind it; kind 1 the 60 embers the swallow flings out; kind 2 the ship's wake, 39 past
// places worked out by SeqMaelstrom. The rolls are hashes: the film's statistics, other draws.
// Why: docs/why/SeqMaelstrom.md#points

#include "res://shaders/jump/jump_common.gdshaderinc"
#include "res://shaders/jump/jump_warp.gdshaderinc"
#include "res://shaders/jump/jump_r8.gdshaderinc"

uniform sampler2D hull : filter_nearest, repeat_disable;
uniform vec4 ship = vec4(0.0, 0.0, 1.0, 1.0);
uniform int kind = 0;
uniform float t = 0.0;
// the streaks' own clock and how much of them shows; the ship's coverage hides the far ones
uniform float tau = 0.0;
uniform float vis = 0.0;
uniform float cov_on = 0.0;
// t - HIT, for the embers
uniform float k_hit = -1.0;
// the wake: screen x, y and strength per past place
uniform vec3 wake[39];

const vec3 HOT = vec3(1.0, 0.94, 1.0);
const vec3 VIO = vec3(0.55, 0.36, 1.0);
const vec3 MAG = vec3(0.95, 0.32, 0.80);
const vec3 SEA = vec3(0.30, 0.95, 0.72);

varying vec3 v_light;

float rollr(int i, int k, float lo, float hi) {
	return mix(lo, hi, jw_roll(i, k));
}

// is the hull drawn at this screen pixel (the film's `cov`, at the pixel's centre)
float covered(vec2 px) {
	vec2 v = (px - Tg) / S;
	vec2 h = floor(r8_ship_h(vec2(v.x, v.y / KY)) + 0.5);
	if (h.x < 0.0 || h.y < 0.0 || h.x >= ship.z || h.y >= ship.w) {
		return 0.0;
	}
	return texelFetch(hull, ivec2(h), 0).a > 0.0 ? 1.0 : 0.0;
}

void vertex() {
	int id = int(UV.x + 0.5);
	int corner = int(UV.y + 0.5);
	vec2 pos = vec2(-1e5);
	float size = 1.0;
	vec3 L = vec3(0.0);
	if (kind == 0) {
		// seven quads a star: six trail pixels and the near ones' glow
		int i = id / 7;
		int j = id - i * 7;
		int jj = j == 6 ? 0 : j;
		float r0 = rollr(i, 1, 70.0, 560.0);
		float a0 = rollr(i, 2, 0.0, TAU);
		float period = rollr(i, 3, 1.4, 3.2);
		float off = rollr(i, 4, 0.0, 1.0);
		bool is_near = jw_roll(i, 5) < 0.25;
		float turns = rollr(i, 6, 0.6, 1.2);
		float bright = rollr(i, 7, 0.6, 1.4);
		float ph = fract(off + tau / period);
		float pj = ph - float(jj) * 0.010 * (1.0 + tau * 0.05);
		if (pj >= 0.0 && vis > 0.0 && (j < 6 || is_near)) {
			float rr = 30.0 + r0 * pow(1.0 - pj, 1.5);
			float aa = a0 + turns * TAU * pj * pj;
			pos = floor(Tg + vec2(cos(aa) * rr, sin(aa) * rr * KY) * S + 0.5);
			float fade = min(1.0, pj * 6.0) * pow(1.0 - pj, 0.3) * vis * bright / (1.0 + float(jj) * 0.9);
			if (!is_near && cov_on > 0.5) {
				fade *= 1.0 - covered(pos);
			}
			if (j == 6) {
				L = VIO * 0.25 * fade;
				size = 3.0;
			} else {
				L = (0.6 * HOT + 0.4 * (i - (i / 3) * 3 == 0 ? SEA : VIO)) * 1.8 * fade;
			}
		}
	} else if (kind == 1) {
		int i = id / 2;
		bool halo = id - i * 2 == 1;
		float a0 = rollr(i, 11, 0.0, TAU);
		float sp = rollr(i, 12, 30.0, 200.0);
		float life = rollr(i, 13, 0.9, 2.6);
		float kk = k_hit;
		float fl = 1.0 - kk / life;
		if (kk >= 0.0 && fl > 0.0) {
			float dist = sp * (1.0 - exp(-kk * 1.5)) / 1.5;
			float aa = a0 + 0.9 * (1.0 - exp(-kk * 1.2));
			pos = floor(Tg + vec2(cos(aa) * dist, sin(aa) * dist * KY) * S + 0.5);
			float tw = 0.55 + 0.45 * jw_hash2(i, int(floor(t * 10.0)));
			L = halo ? VIO * 0.25 * fl * tw : (i - (i / 2) * 2 == 1 ? HOT : SEA) * 2.2 * fl * tw;
			size = halo ? 3.0 : 1.0;
		}
	} else {
		int i = id / 2;
		bool halo = id - i * 2 == 1;
		vec3 w = wake[i];
		if (w.z > 0.0) {
			pos = floor(w.xy + 0.5);
			L = halo ? MAG * 0.25 * w.z : HOT * 1.6 * w.z;
			size = halo ? 3.0 : 1.0;
		}
	}
	v_light = L;
	vec2 c = vec2(corner == 1 || corner == 2 || corner == 4 ? 1.0 : 0.0, corner == 2 || corner == 4 || corner == 5 ? 1.0 : 0.0);
	VERTEX = pos + 0.5 + (c - 0.5) * size;
}

void fragment() {
	COLOR = vec4(v_light * 0.25, 1.0);
}
