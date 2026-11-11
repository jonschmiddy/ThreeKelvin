shader_type canvas_item;
render_mode unshaded, blend_add, skip_vertex_transform;

// R3 THE RIFT's points of light, into the warp field's light buffer (pre-scaled by 0.25), each
// a whole pixel placed in closed form from the clock: kind 0 the 120 infall motes spiralling into
// the throat with five-pixel trails (rift.py rng 11), kind 1 the 34 motes the shut throws out
// with their 3x3 glow (rng 5). The rolls are hashes: the film's statistics, other draws.
// Why: docs/why/SeqRift.md#points

#include "res://shaders/jump/jump_warp.gdshaderinc"

uniform int kind = 0;
uniform vec2 Tg = vec2(600.0, 262.0);
uniform float S = 1.0;
uniform float t = 0.0;
uniform float rh = 0.0;
uniform float spin = 0.0;
uniform float strength = 0.0;
// t - HEAL - 0.28, for the shut's motes
uniform float k_shut = -1.0;

const vec3 HOT = vec3(1.0, 0.93, 1.0);
const vec3 VIO = vec3(0.62, 0.40, 1.0);

varying vec3 v_light;

float rollr(int i, int k, float lo, float hi) {
	return mix(lo, hi, jw_roll(i, k));
}

void vertex() {
	int id = int(UV.x + 0.5);
	int corner = int(UV.y + 0.5);
	vec2 pos = vec2(-1e5);
	float size = 1.0;
	vec3 L = vec3(0.0);
	if (kind == 0) {
		// six quads a mote: its head (0) and five trail pixels
		int i = id / 6;
		int tr = id - i * 6;
		float r0 = rollr(i, 1, 60.0, 480.0);
		float a0 = rollr(i, 2, 0.0, TAU);
		float period = rollr(i, 3, 1.3, 2.8);
		float off = rollr(i, 4, 0.0, period);
		float ph = mod(t + off, period) / period;
		float rr = r0 * pow(1.0 - ph, 1.6) + rh + 1.5;
		float aa = a0 + 2.6 * ph * ph * (1.0 + spin);
		vec2 x = vec2(cos(aa) * rr, sin(aa) * rr * 0.85);
		float fade = min(1.0, ph * 5.0) * pow(1.0 - ph, 0.4) * strength;
		vec2 at = Tg + x * S;
		if (tr == 0) {
			pos = floor(at + 0.5);
			L = (0.6 * HOT + 0.4 * VIO) * 2.2 * fade;
		} else {
			pos = floor(at + vec2(cos(aa - 0.3), sin(aa - 0.3)) * 1.6 * float(tr) + 0.5);
			L = VIO * 0.9 * fade / float(tr);
		}
	} else {
		// two quads a mote: its pixel and its 3x3 glow
		int i = id / 2;
		bool glow = id - i * 2 == 1;
		float a = rollr(i, 11, 0.0, TAU);
		float sp = rollr(i, 12, 25.0, 150.0);
		float life = rollr(i, 13, 0.8, 2.3);
		float k = k_shut;
		float f = 1.0 - k / life;
		if (k >= 0.0 && f > 0.0) {
			float dist = sp * (1.0 - exp(-k * 1.6)) / 1.6;
			vec2 x = vec2(cos(a) * dist, sin(a) * dist * 0.75);
			pos = floor(Tg + x * S + 0.5);
			float tw = 0.55 + 0.45 * jw_hash2(i, int(floor((t) * 10.0)));
			L = glow ? VIO * 0.3 * f * tw : HOT * 2.4 * f * tw;
			size = glow ? 3.0 : 1.0;
		}
	}
	v_light = L;
	vec2 c = vec2(corner == 1 || corner == 2 || corner == 4 ? 1.0 : 0.0, corner == 2 || corner == 4 || corner == 5 ? 1.0 : 0.0);
	VERTEX = pos + 0.5 + (c - 0.5) * size;
}

void fragment() {
	COLOR = vec4(v_light * 0.25, 1.0);
}
