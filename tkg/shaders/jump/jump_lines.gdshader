shader_type canvas_item;
render_mode unshaded, blend_add, world_vertex_coords;

// Streaks of light as instances (`JumpLines`): each a thin quad from head to tail, built in
// the vertex shader from the instance's own numbers and this instant's uniforms, shaded as
// the films' `streaks()` rasterised them (bright at the head, its first pixel boosted, the
// longer the dimmer) and summed into a light buffer. Mode 0 is given head and tail; 1 is
// R1's stars (home, brightness, lag); 2 is R1's flow (angle, phase, speed, depth).
// Why: docs/why/JumpLines.md#streaks

#include "res://shaders/jump/jump_light.gdshaderinc"
#include "res://shaders/jump/jump_r1.gdshaderinc"

uniform int mode = 0;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec2 vp = vec2(772.0, 281.0);
uniform vec3 col_h = vec3(1.0);
uniform vec3 col_t = vec3(1.0);
// R1's stars: the stretch, whether the hit has passed, how far the extras show
uniform float S = 0.0;
uniform float after = 0.0;
uniform float ea = 0.0;
// R1's flow: its amount, its phase and its speed
uniform float fa = 0.0;
uniform float phi = 0.0;
uniform float sp = 0.08;

varying float v_u;
varying float v_across;
varying flat float v_cnt;
varying flat float v_ih;
varying flat float v_it;
varying flat float v_thick;
varying flat vec3 v_ch;
varying flat vec3 v_ct;

void vertex() {
	vec2 a = MODEL_MATRIX[3].xy;
	vec2 bx = MODEL_MATRIX[0].xy;
	vec2 by = MODEL_MATRIX[1].xy;
	vec2 head = a;
	vec2 tail = a;
	float ih = 0.0;
	float it = 0.0;
	float thick = 1.0;
	vec3 ch = col_h;
	vec3 ct = col_t;
	bool on = true;
	if (mode == 0) {
		tail = bx;
		ih = by.x;
		it = by.y;
		on = ih > 0.0;
	} else if (mode == 1) {
		bool extra = by.x > 0.5;
		r1_star(a, vp, S, after > 0.5, extra, bx.y, head, tail);
		float slen = length(head - tail);
		if (!extra) {
			float bright = bx.x * (1.0 + 1.5 * min(abs(S), 0.72));
			float g = 1.0;
			on = slen > 1.2;
			if (after > 0.5) {
				g = 1.0 - r1_keep(slen, true);
				on = g > 0.0;
			}
			ih = bright * 1.3 * g;
			it = bright * 0.35 * g;
			ch = R1_WHT;
			ct = R1_VIO * 0.9;
		} else {
			on = ea > 0.02;
			ih = bx.x * ea * 1.2;
			it = bx.x * ea * 0.3;
			ch = R1_LIL;
			ct = R1_VIO;
		}
	} else {
		float ang = a.x;
		float u = fract(a.y - phi * bx.x);
		float uu = pow(u, 1.35);
		float ln_ = sp * bx.x * 0.35;
		float c = cos(ang);
		float s = sin(ang);
		float tx = c > 0.0 ? (world.x + world.z + 40.0 - vp.x) / c : (world.x - 40.0 - vp.x) / min(c, -1e-9);
		float ty = s > 0.0 ? (world.y + world.w + 40.0 - vp.y) / s : (world.y - 40.0 - vp.y) / min(s, -1e-9);
		float R = min(abs(tx), abs(ty));
		vec2 dv = vec2(c, s / 1.25);
		head = vp + dv * R * uu;
		tail = vp + dv * R * min(uu + ln_, 1.2);
		float fade = clamp(u / 0.08, 0.0, 1.0) * clamp((1.05 - u) / 0.2, 0.0, 1.0) * fa;
		on = fade > 0.01;
		ih = bx.y * fade * 1.6;
		it = bx.y * fade * 0.5;
		thick = by.y;
		if (by.x > 1.5) {
			ch = R1_WHT;
			ct = R1_MAG * 0.6 + R1_VIO * 0.4;
		} else {
			ch = R1_LIL;
			ct = R1_VIO;
		}
	}
	// the film's pixel i is centred on i; the screen's on i + 0.5 (an instance off is put
	// far outside the screen: Godot refuses a return in vertex())
	vec2 d = tail - head;
	float ln = max(abs(d.x), abs(d.y));
	vec2 dir = vec2(1.0, 0.0);
	vec2 nrm = vec2(0.0, 1.0);
	float hw = 0.5;
	vec2 h = head + 0.5;
	if (ln > 0.0) {
		dir = d / length(d);
		nrm = vec2(-dir.y, dir.x);
		if (nrm.y < 0.0) {
			nrm = -nrm;
		}
		// just the pixels the film's one-sample-a-pixel line touched
		hw = 0.5 * max(abs(dir.x), abs(dir.y));
	} else {
		h = floor(head + 0.5) + 0.5;
		d = vec2(0.0);
	}
	vec2 st = h - dir * 0.5;
	vec2 en = h + d + dir * 0.5;
	vec2 pos = mix(st, en, UV.x) + nrm * hw * (UV.y * 2.0 - 1.0);
	if (thick > 1.5) {
		pos.y += UV.y;
	}
	VERTEX = on ? pos : vec2(-1e5);
	v_u = UV.x;
	v_across = UV.y;
	v_cnt = ceil(ln) + 1.0;
	v_ih = ih;
	v_it = it;
	v_thick = thick;
	v_ch = ch;
	v_ct = ct;
}

void fragment() {
	float cnt = v_cnt;
	float k = clamp(floor(v_u * cnt), 0.0, cnt - 1.0);
	float u = cnt > 1.0 ? k / (cnt - 1.0) : 0.0;
	float w = (v_ih * pow(1.0 - u, 1.6) + v_it * (1.0 - u)) / sqrt(max(cnt / 6.0, 1.0)) * (k == 0.0 ? 2.4 : 1.0);
	if (v_thick > 1.5) {
		w *= mix(1.0, 0.8, v_across);
	}
	COLOR = vec4(w * mix(v_ch, v_ct, u) * J_LIGHT_K, 1.0);
}
