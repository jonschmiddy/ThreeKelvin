shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R2 THE FOURTH DIMENSION, the world pass: the approved film's r2.py `frame()` per pixel. Space
// inside the hypercube turns with the hull and echoes its stars along W; the hull is its 4D
// cut, bulging, carved, inside out, mirrored, with two coloured copies a little further along
// W; the drive's light leaks through its seams; the hypercube and motes come in as light from
// `jump_r2_cube` (hot lines, and the light that glows, at four sizes for its blurs); one tone
// map lays it all on, the lines burning over the hull.
// Why: docs/why/SeqFourth.md#world-pass

#include "res://shaders/jump/jump_common.gdshaderinc"
#include "res://shaders/jump/jump_r2.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D l_core : filter_nearest, repeat_disable;
uniform sampler2D l_src0 : filter_linear, repeat_disable;
uniform sampler2D l_src1 : filter_linear, repeat_disable;
uniform sampler2D l_src3 : filter_linear, repeat_disable;
uniform sampler2D l_src4 : filter_linear, repeat_disable;
uniform sampler2D l_face : filter_nearest, repeat_disable;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform float hull_on = 0.0;
// the hypercube's size on screen (x and y of a unit), for the region space turns in
uniform vec2 ts = vec2(128.0, 70.0);
// space: its turn, the bang's ripple (time since, or < 0), the dimming, the star echoes' strength and scales
uniform float shear = 0.0;
uniform float k_bang = -1.0;
uniform float dim = 0.0;
uniform float echo_s = 0.0;
uniform vec2 echo_kw = vec2(1.0);
// the hull: its copies' strength, how far it has turned into W
uniform float echo = 0.0;
uniform float turning = 0.0;
// the drive's strain: on, wake, pulse, reach; the star at the hull's heart: on, pk, arm
uniform vec4 strain = vec4(0.0);
uniform vec3 star = vec3(0.0);
// the bang's frame light (amplitude, radius scale), the light buffers' presence
uniform vec2 bang_fl = vec2(0.0, 1.0);
uniform float src_any = 0.0;
// the soft turn (Jon's choice for turning sprites, `PixelTurn` SOFT): the turning hull and the
// turned sky are 2 x 2 points a pixel, averaged in linear light, so a re-picked pixel fades
// rather than flips (0: the film's nearest pick, for comparing)
uniform float soft = 1.0;
const vec2 SUB[4] = vec2[4](vec2(-0.25, -0.25), vec2(0.25, -0.25), vec2(-0.25, 0.25), vec2(0.25, 0.25));

const float K_CORE = 0.25;
const float K_FACE = 4.0;
const vec4 K_SRC = vec4(0.25, 0.5, 2.0, 4.0);

vec4 buf(sampler2D s, vec2 p) {
	vec2 sz = vec2(textureSize(s, 0));
	vec2 q = clamp(p - world.xy, vec2(0.0), sz - 1.0);
	return texture(s, (q + 0.5) / sz);
}

// a gaussian of the glowing light from a buffer `cell` px a texel: 5 x 5 taps, linear between
vec3 gauss(sampler2D s, float cell, float sigma, vec2 p) {
	vec2 sz = vec2(textureSize(s, 0));
	float st = max(sigma * 0.9, 1.0);
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec2 o = vec2(float(x), float(y)) * st;
			float w = exp(-dot(o, o) / (2.0 * sigma * sigma));
			acc += w * texture(s, (p + 0.5 + o - world.xy) / cell / sz).rgb;
			wsum += w;
		}
	}
	return acc / wsum;
}

// the stars alone at q: the sky less its surroundings, as r2.py's STARS (the sky less its median)
float star_at(vec2 q, vec2 px) {
	vec3 c = j_world(screen, px, q, world);
	vec3 bg = vec3(0.0);
	for (int i = 0; i < 8; i++) {
		float a = float(i) * 0.785398;
		bg += j_world(screen, px, q + floor(vec2(cos(a), sin(a)) * 2.0 + 0.5), world);
	}
	vec3 s = max(c - bg / 8.0 - 6.0 / 255.0, vec3(0.0));
	return max(s.r, max(s.g, s.b));
}

// the hull's panel seam under the main cut at X: darker by 32 than its 5 x 5 neighbourhood's
// mean, as r2.py found them on the cut
float seam_at(vec2 X) {
	vec2 xy = X - sc;
	vec2 h = floor(vec2(dot(ru[0], xy), dot(rv[0], xy)) + sc + 0.5) - ship.xy;
	float sum = 0.0, cnt = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec4 c = j_hull_px(hull, h + vec2(float(x), float(y)), ship.zw);
			if (c.a > 0.0) {
				sum += (c.r + c.g + c.b) / 3.0;
				cnt += 1.0;
			}
		}
	}
	vec4 c0 = j_hull_px(hull, h, ship.zw);
	return c0.a > 0.0 && (c0.r + c0.g + c0.b) / 3.0 < sum / max(cnt, 1.0) - 32.0 / 255.0 ? 1.0 : 0.0;
}

// the sky at q, mirrored at the window's edges (r2.py padded its world by reflection, so space
// turned in from outside the window is more sky, never a smear of the edge)
vec3 sky_at(vec2 q, vec2 px) {
	vec2 lo = world.xy;
	vec2 sz = world.zw;
	vec2 m = mod(q - lo, 2.0 * sz);
	m = mix(m, 2.0 * sz - 1.0 - m, step(sz, m));
	return j_world(screen, px, lo + m, world);
}

// R2's tone map: 1 - e^-L in ten steps, a 4 x 4 dither as strong as the light, white when hot
vec4 tone(vec3 L, vec2 p) {
	float lum = max(L.r, max(L.g, L.b));
	if (lum <= 0.0) {
		return vec4(0.0);
	}
	float v = 1.0 - exp(-lum);
	float q = clamp(floor(v * 10.0 + j_dith4(p) * min(1.0, v * 3.0)) / 10.0, 0.0, 1.0);
	vec3 col = mix(L / lum, vec3(1.0), clamp((lum - 1.4) / 2.5, 0.0, 1.0));
	return vec4(col, q);
}

// where space at X is drawn from: turned with the hull inside the hypercube (stretched where
// the cut is steep, clamped at the pole), rippled by the bang; f is how far it is turned
vec2 bent(vec2 X, out float f) {
	vec2 d0 = X - sc;
	vec2 sx = X;
	f = 0.0;
	if (shear > 0.0) {
		vec2 e = d0 / (ts * vec2(1.7, 1.9));
		f = pow(clamp(1.2 - dot(e, e), 0.0, 1.0), 1.5) * shear;
		float u = clamp(dot(ru[0], d0), -600.0, 600.0);
		float v = dot(rv[0], d0);
		sx = X + (vec2(u, v) + sc - X) * f;
	}
	if (k_bang >= 0.0) {
		float rr = length(vec2(d0.x, d0.y * 1.4));
		float front = 20.0 + 330.0 * k_bang;
		float disp = 5.0 * exp(-k_bang * 1.6) * sin((rr - front) / 6.0) * exp(-pow((rr - front) / 26.0, 2.0));
		sx += disp * d0 / max(rr, 1.0);
	}
	return sx;
}

void fragment() {
	vec2 p = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	vec2 X = p;
	vec2 d0 = X - sc;
	float fturn;
	vec3 o = sky_at(floor(bent(X, fturn) + 0.5), SCREEN_PIXEL_SIZE);
	if (soft > 0.5 && fturn > 0.001) {
		vec3 acc = vec3(0.0);
		for (int i = 0; i < 4; i++) {
			float f_;
			acc += pow(sky_at(floor(bent(X + SUB[i], f_) + 0.5), SCREEN_PIXEL_SIZE), vec3(2.2));
		}
		o = pow(acc * 0.25, vec3(1.0 / 2.2));
	}
	o *= 1.0 - dim;
	vec3 L = vec3(0.0);
	vec3 core = vec3(0.0);
	// --- the stars echoed along W, magenta ahead and mint behind
	if (echo_s > 0.0) {
		float fall = exp(-(pow(d0.x / 330.0, 2.0) + pow(d0.y / 170.0, 2.0)));
		if (fall > 0.004) {
			L += star_at(floor(d0 / echo_kw.x + sc + 0.5), SCREEN_PIXEL_SIZE) * fall * 2.2 * echo_s * R2_MAG;
			L += star_at(floor(d0 / echo_kw.y + sc + 0.5), SCREEN_PIXEL_SIZE) * fall * 2.2 * echo_s * R2_MINT;
		}
	}
	// --- the hull and its copies, cut through W
	bool hull_a = false;
	float cov = 0.0;
	bool rim = false;
	vec3 hrgb = vec3(0.0);
	float rel = 0.0;
	if (hull_on > 0.5 && hull_cut > 0.5 && abs(d0.x) < 330.0 && abs(d0.y) < 180.0) {
		if (echo > 0.01) {
			for (int i = 1; i <= 2; i++) {
				float erel;
				vec4 e = r2_slice(i, X, erel);
				if (e.a > 0.5 && j_dith4(p) < echo * (2.4 - 2.0 * abs(erel))) {
					vec3 col = i == 1 ? R2_MAG : R2_MINT;
					float lum = (e.r + e.g + e.b) / 3.0;
					o = o * 0.25 + (20.0 / 255.0 + 200.0 / 255.0 * pow(lum, 1.2)) * col * 0.95;
					if (abs(erel) > 0.75) {
						L += col * 0.8;
					}
				}
			}
		}
		vec4 h = r2_slice(0, X, rel);
		cov = h.a;
		hrgb = h.rgb;
		if (soft > 0.5) {
			// the soft turn: coverage and colour from four points across the pixel
			vec3 acc = vec3(0.0);
			float rs = 0.0;
			cov = 0.0;
			for (int i = 0; i < 4; i++) {
				float r_;
				vec4 hs = r2_slice(0, X + SUB[i], r_);
				if (hs.a > 0.5) {
					acc += pow(hs.rgb, vec3(2.2));
					rs += r_;
					cov += 0.25;
				}
			}
			if (cov > 0.0) {
				hrgb = pow(acc / (cov * 4.0), vec3(1.0 / 2.2));
				rel = rs / (cov * 4.0);
			}
		}
		hull_a = cov > 0.0;
		if (hull_a) {
			float rr;
			rim = r2_slice(0, X + vec2(1.0, 0.0), rr).a < 0.5 || r2_slice(0, X - vec2(1.0, 0.0), rr).a < 0.5
				|| r2_slice(0, X + vec2(0.0, 1.0), rr).a < 0.5 || r2_slice(0, X - vec2(0.0, 1.0), rr).a < 0.5;
			if (turning > 0.0) {
				// its cut faces tinted by where they sit along W, the cut's edge burning
				vec3 tint = r2_wcol(rel);
				float mk = 0.85 * pow(abs(rel), 0.7) * turning;
				hrgb = hrgb * (1.0 - mk) + (hrgb.r + hrgb.g + hrgb.b) / 3.0 * mk * tint * 1.25;
				if (abs(rel) > 0.80) {
					L += tint * 1.4 * turning;
				}
			}
		}
	}
	// --- the drive's strain: light gathers from the core, leaks through the seams
	if (strain.x > 0.5) {
		float wake = strain.y, pulse = strain.z;
		float d = length(vec2(d0.x, d0.y * 1.6));
		if (hull_a) {
			L += exp(-d / (24.0 + 36.0 * wake)) * (0.06 + 0.25 * wake + 0.8 * pulse) * R2_LIL;
			float fr_ = clamp((strain.w - d) / 18.0, 0.0, 1.0);
			L += seam_at(X) * (0.35 + 1.4 * pulse + 0.5 * wake) * (1.0 - 0.6 * turning) * fr_ * R2_LIL;
		}
		if (star.x > 0.5) {
			float pk = star.y;
			L += j_splat(X, sc, 1.0, R2_HOT, 3.5 * pk + 2.5 * pulse, 1.0);
			core += j_splat(X, sc, 1.2, R2_HOT, 4.0 * pk + 4.0 * pulse, 1.0);
			// a four-point glint, whole-pixel arms breathing with the pulses
			vec2 g = X - floor(sc + 0.5);
			float arm = star.z;
			float fk = 1.4 + 2.0 * pulse;
			if (g.y == 0.0 && abs(g.x) >= 1.0 && abs(g.x) < arm) {
				core += R2_HOT * pow(1.0 - abs(g.x) / arm, 1.5) * fk;
			}
			if (g.x == 0.0 && g.y != 0.0) {
				for (int k = 0; k < 2; k++) {
					float dd = 2.0 * abs(g.y) + float(k);
					if (dd >= 1.0 && dd < arm) {
						core += R2_HOT * pow(1.0 - dd / arm, 1.5) * fk * 0.5;
					}
				}
			}
			L += j_splat(X, sc, 5.0, R2_LIL, 0.5 * pk + 0.8 * pulse, 1.0);
			L += j_splat(X, sc, 22.0, R2_LIL, 0.10 * pk + 0.25 * pulse, 1.0);
		}
	}
	// --- the bang: the frame lights for two frames, a point, a ring rides the ripple
	if (k_bang >= 0.0) {
		float k = k_bang;
		if (bang_fl.x > 0.0) {
			vec2 r0 = d0 / (vec2(520.0, 330.0) * bang_fl.y);
			L += bang_fl.x * exp(-dot(r0, r0) * 1.5) * R2_LIL;
		}
		L += j_splat(X, sc, 1.5, R2_HOT, 6.0 * exp(-k / 0.12), 1.0);
		L += j_splat(X, sc, 9.0, R2_MAG, 1.6 * exp(-k / 0.18), 1.0);
		L += j_splat(X, sc, 40.0, R2_LIL, 0.7 * exp(-k / 0.30), 1.0);
		float rr = length(vec2(d0.x, d0.y * 1.4));
		float front = 20.0 + 330.0 * k;
		L += exp(-pow((rr - front) / 2.2, 2.0)) * 1.2 * exp(-k * 2.2) * r2_wcol(0.6 * cos(k * 3.0));
	}
	// --- the hypercube's light: hot lines, glow at three widths, the broad light on the hull
	if (src_any > 0.5) {
		core += buf(l_core, p).rgb / K_CORE;
		L += core;
		L += gauss(l_src0, 1.0, 1.0, p) / K_SRC.x * 1.3;
		L += gauss(l_src1, 2.0, 3.5, p) / K_SRC.y * 0.45;
		L += gauss(l_src3, 8.0, 18.0, p) / K_SRC.z * 1.3;
		if (hull_a) {
			L += gauss(l_src4, 16.0, 40.0, p) / K_SRC.w * 6.0 * 0.8;
		}
	}
	L += buf(l_face, p).rgb / K_FACE;
	// --- light on: a lit hull is a brighter hull, its rim catching it; lines burn over it
	vec4 tq = tone(L, p);
	vec3 add = tq.a * tq.rgb;
	if (hull_a) {
		vec3 oh = hrgb * (1.0 + 0.45 * tq.a + (rim ? 0.9 * tq.a : 0.0)) + 0.40 * add;
		vec4 tc = tone(core, p);
		oh += tc.a * tc.rgb * 0.8;
		o = mix(o + add, oh, cov);
	} else {
		o += add;
	}
	COLOR = vec4(clamp(o, 0.0, 1.0), 1.0);
}
