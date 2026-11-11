shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R9 UNRAVEL, the world pass: the approved film's r9.py `frame()` per pixel. The threads, their
// curtains, afterglow, paint and the ghost of the curtains are drawn into light buffers by
// `jump_r9_threads`; this pass lights the sky by them, draws what is left of the hull and its
// burning front, and lays it all in the film's order: back light, glow, back paint, hull,
// front paint, front light.
// Why: docs/why/SeqUnravel.md#world-pass

#include "res://shaders/jump/jump_common.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D hull : filter_nearest, repeat_disable;
uniform sampler2D aux : filter_nearest, repeat_disable;
uniform sampler2D aux2 : filter_nearest, repeat_disable;
uniform sampler2D l_back : filter_nearest, repeat_disable;
uniform sampler2D l_front : filter_nearest, repeat_disable;
uniform sampler2D l_curt : filter_nearest, repeat_disable;
uniform sampler2D l_lag : filter_nearest, repeat_disable;
uniform sampler2D l_matter : filter_nearest, repeat_disable;
uniform sampler2D l_ghost : filter_nearest, repeat_disable;
uniform sampler2D l_lum : filter_linear, repeat_disable;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec4 ship = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec4 ink = vec4(90.0, 232.0, 236.0, 93.0);
uniform vec2 vp = vec2(772.0, 260.0);
uniform vec2 core = vec2(152.0, 284.0);
uniform float t = 0.0;
uniform float hull_on = 0.0;
uniform float hull_live = 1.0;
uniform vec2 hoff = vec2(0.0);
uniform float kt = 0.0;
uniform float reel = 0.0;
uniform float k_s = -1.0;
uniform float lag_on = 0.0;
uniform float rib_on = 0.0;
// per ink row: its unravel front and its last ink column (-1: no ink)
uniform vec2 fr[160];
uniform int rows = 0;
uniform vec3 front_sp = vec3(0.0);
// the plates: their warning glow, their edge columns
uniform float pw[8];
uniform float pe[9];
// the drive's pulses (front, amplitude, width, flash at the core) and the wake (on, s, splat r, k)
uniform vec4 pl[4];
uniform vec4 wake = vec4(0.0);
// the corona (gather, tighten, flicker, on); the ghost (fade, drift x, drift y, dissolve)
uniform vec4 cor = vec4(0.0);
uniform vec4 ghost = vec4(0.0);

const float T_SNAP = 6.15;
const float K_LINE = 0.25;
const float K_CURT = 2.0;
const float K_LAG = 0.5;
const float K_GHOST = 0.25;
const vec3 MINT = vec3(0.42, 1.00, 0.70);
const vec3 VIO = vec3(0.62, 0.36, 1.00);
const vec3 LIL = vec3(0.86, 0.80, 1.00);
const vec3 WHT = vec3(1.00, 0.97, 1.00);
const vec3 MAG = vec3(1.00, 0.36, 0.80);
const float TRI[5] = float[5](4.0, 12.0, 20.0, 12.0, 4.0);

// a light buffer at screen pixel p (the window's size, its origin at the window's)
vec4 buf(sampler2D s, vec2 p) {
	vec2 sz = vec2(textureSize(s, 0));
	vec2 q = clamp(p - world.xy, vec2(0.0), sz - 1.0);
	return texture(s, (q + 0.5) / sz);
}

// the ribbons' brightness, from its quarter-size buffer, filtered
float lum_at(vec2 p) {
	vec2 sz = vec2(textureSize(l_lum, 0));
	return texture(l_lum, (p + 0.5 - world.xy) / 4.0 / sz).r;
}

// the film's vertically stretched dissolve: random, box-filtered 13 then 5 rows by 2 columns
float dissolve(vec2 p) {
	float s = 0.0;
	for (int dy = -8; dy <= 8; dy++) {
		float w = abs(dy) <= 4 ? 5.0 : float(9 - abs(dy));
		s += w * (j_noise(vec2(p.x, p.y + float(dy))) + j_noise(vec2(p.x - 1.0, p.y + float(dy))));
	}
	return (s / 130.0 - 0.26) / (0.743 - 0.26);
}

// what is left of the hull's light at ink pixel hi (its seams, front, plates, the ribbons near it)
float hull_light(vec2 p, vec2 hi, vec2 hc, float F) {
	float seam = texture(aux, (hc + 0.5) / ship.zw).r;
	float edge2 = texture(aux2, (hc + 0.5) / ship.zw).a;
	float Lh = 0.0;
	float dc = length(vec2(hi.x + ink.x - core.x, (hi.y + ink.y - core.y) * 1.7));
	if (wake.x > 0.5) {
		for (int j = 0; j < 4; j++) {
			if (pl[j].y > 0.0) {
				Lh += exp(-pow((dc - pl[j].x) / pl[j].z, 2.0)) * pl[j].y * (0.2 + 1.6 * seam) + pl[j].w * exp(-dc / 7.0);
			}
		}
		Lh += seam * (0.15 + 0.6 * wake.y) * (dc < 30.0 + 220.0 * wake.y ? 1.0 : 0.0);
		for (int k = 0; k < 8; k++) {
			if (pw[k] > 0.01) {
				float inside = hi.x >= pe[k] && hi.x < pe[k + 1] ? 1.0 : 0.0;
				Lh += pw[k] * (1.4 * seam * inside + 1.2 * (abs(hi.x - pe[k + 1]) < 1.5 ? 1.0 : 0.0));
			}
		}
	}
	if (F >= 0.0) {
		float dist = max(hi.x - F, 0.0);
		Lh += 2.4 * exp(-dist / 1.3) + 0.35 * exp(-dist / 9.0);
	}
	if (rib_on > 0.5) {
		Lh += clamp(lum_at(p), 0.0, 1.0) * 0.30;
		if (edge2 > 0.5) {
			float b8 = 0.0;
			for (int y = -1; y <= 1; y++) {
				for (int x = -1; x <= 1; x++) {
					b8 += lum_at(p + vec2(float(x), float(y)) * 4.0);
				}
			}
			Lh += clamp(b8 / 9.0 * 2.0, 0.0, 0.9);
		}
	}
	return Lh;
}

void fragment() {
	vec2 p = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	// --- the sky: drawn a little toward the corona while taut; rung by the snap
	vec2 d = p - vp;
	float r = length(vec2(d.x, d.y * 1.3));
	float m = 0.0;
	if (kt > 0.0 && t < T_SNAP) {
		m += 0.10 * kt * exp(-r / 170.0) + 0.12 * reel * exp(-r / 120.0);
	}
	if (k_s >= 0.0) {
		float frt = 10.0 + 400.0 * pow(k_s, 0.8);
		m += -0.14 * exp(-k_s / 0.7) * exp(-pow((r - frt) / 15.0, 2.0)) * sign(r - frt + 1e-3);
		m += 0.22 * exp(-k_s / 0.10) * exp(-r / 150.0);
	}
	vec2 sq = abs(m) > 1e-3 ? floor(vp + d * (1.0 + m) + 0.5) : p;
	vec3 sky = j_world(screen, SCREEN_PIXEL_SIZE, sq, world);
	// the ribbons light the space round them: a lit cloud is a brighter cloud
	if (rib_on > 0.5) {
		float soft = 0.0;
		for (int y = 0; y < 5; y++) {
			for (int x = 0; x < 5; x++) {
				soft += TRI[x] * TRI[y] * lum_at(p + vec2(float(x - 2), float(y - 2)) * 8.0);
			}
		}
		soft /= 52.0 * 52.0;
		sky *= 1.0 + clamp(soft, 0.0, 0.6) * (0.9 * MINT + 0.4 * VIO);
	}

	// --- the hull that is left: the ink right of its row's front
	bool ship_a = false;
	vec3 lit = vec3(0.0);
	vec2 hi = p - hoff - ink.xy;
	vec2 hc = p - hoff - ship.xy;
	int row = int(floor(hi.y));
	if (hull_on > 0.5 && hull_live > 0.5 && row >= 0 && row < rows) {
		vec4 px = j_hull_px(hull, hc, ship.zw);
		float F = fr[row].x;
		if (px.a > 0.0 && hi.x >= F) {
			ship_a = true;
			float Lh = hull_light(p, hi, hc, F);
			float q = j_glow_q(Lh, 7.0, p);
			lit = px.rgb * (1.0 + 0.9 * q) + q * (MINT * 0.22 + VIO * 0.18);
			lit = mix(lit, WHT * 0.85 + MINT * 0.15, clamp((Lh - 2.2) / 1.5, 0.0, 1.0));
		}
	}

	// --- glow light: curtains, afterglow, the ghost, the drive, the front, the corona, the burst
	vec3 gl = buf(l_curt, p).rgb / K_CURT;
	if (lag_on > 0.5) {
		gl += buf(l_lag, p).rgb / K_LAG;
	}
	if (ghost.x > 0.0 && dissolve(p) > ghost.w) {
		vec2 g0 = floor(p - ghost.yz + 0.5);
		vec3 mm = vec3(0.0);
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				mm += buf(l_ghost, g0 + vec2(float(x), float(y))).rgb;
			}
		}
		gl += mm / 9.0 / K_GHOST * ghost.x;
	}
	if (wake.w > 0.0) {
		gl += j_splat(p, core + hoff, wake.z, VIO, wake.w, 1.0);
	}
	if (hull_on > 0.5 && hull_live > 0.5) {
		int fr_row = int(floor(p.y - ink.y - hoff.y));
		if (fr_row >= 0 && fr_row < rows) {
			vec2 f = fr[fr_row];
			if (f.y >= 0.0 && f.x >= 0.0 && f.x <= f.y && p.x == floor(ink.x + hoff.x + f.x + 0.5)) {
				gl += 0.35 * (WHT * 0.5 + MINT * 0.5);
			}
		}
		if (front_sp.z > 0.0) {
			gl += j_splat(p, front_sp.xy, 14.0, MINT, 0.22, 1.0);
		}
	}
	if (cor.w > 0.0) {
		float g = cor.x, tight = cor.y;
		gl += j_splat(p, vp, 1.0 + 1.4 * g * (1.0 - 0.6 * tight), WHT, (0.5 + 2.6 * g + 3.0 * tight) * cor.z, 1.0);
		gl += j_splat(p, vp, 5.0 + 12.0 * g * (1.0 - 0.5 * tight), MINT, 0.25 + 0.7 * g, 1.0);
		gl += j_splat(p, vp, 26.0 + 30.0 * g * (1.0 - 0.4 * tight), VIO, 0.06 + 0.2 * g, 1.0);
	}
	vec3 back = buf(l_back, p).rgb / K_LINE;
	if (k_s >= 0.0) {
		gl += j_splat(p, vp, 2.0, WHT, 6.0 * exp(-k_s / 0.16), 1.0);
		gl += j_splat(p, vp, 22.0 + 50.0 * k_s, MINT * 0.6 + VIO * 0.4, 0.8 * exp(-k_s / 0.3), 1.0);
		float frt = 10.0 + 400.0 * pow(k_s, 0.8);
		gl += exp(-pow((r - frt) / (6.0 + 12.0 * k_s), 2.0)) * exp(-k_s / 0.30) * 0.18 * (MINT * 0.5 + VIO * 0.5);
		float bar = exp(-pow((p.y - vp.y) / 0.6, 2.0)) * exp(-abs(p.x - vp.x) / (300.0 * exp(-k_s / 0.4) + 16.0));
		back += bar * 1.8 * exp(-k_s / 0.28) * (LIL * 0.5 + MINT * 0.5);
	}
	if (ship_a) {
		gl *= 0.25;
		back = vec3(0.0);
	}

	// --- composite: back light, glow, back paint, hull, front paint, front light
	vec3 o = j_add_line(sky, back, 9.0);
	o = j_add_glow(o, gl, 7.0, p);
	vec4 mt = buf(l_matter, p);
	if (mt.a > 0.25 && mt.a < 0.75 && !ship_a) {
		o = mt.rgb;
	}
	if (ship_a) {
		o = lit;
	}
	if (mt.a >= 0.75) {
		o = mt.rgb;
	}
	o = j_add_line(o, buf(l_front, p).rgb / K_LINE, 9.0);
	COLOR = vec4(clamp(o, 0.0, 1.0), 1.0);
}
