shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R5 QUANTUM SMEAR, the world pass: the approved film's r5.py `frame()` per pixel. The
// two-source interference field F, the haze blurred from the ghost buffer, the sky wavering
// in the cloud and rung by the rings after, the ghosts coloured by F (teal crests, rose
// troughs), the glint, the hull losing certainty under its fringes, the point and the pop.
// Why: docs/why/SeqQuantumSmear.md#world-pass

#include "res://shaders/jump/jump_common.gdshaderinc"
#include "res://shaders/jump/jump_light.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D hull : filter_nearest, repeat_disable;
uniform sampler2D aux : filter_nearest, repeat_disable;
uniform sampler2D aux2 : filter_nearest, repeat_disable;
uniform sampler2D sdf : filter_nearest, repeat_disable;
uniform sampler2D ghosts : filter_nearest, repeat_disable;
uniform sampler2D ghosts_q : filter_linear, repeat_disable;
uniform sampler2D light_back : filter_nearest, repeat_disable;
uniform sampler2D light_front : filter_nearest, repeat_disable;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec4 ship = vec4(0.0, 0.0, 1.0, 1.0);
uniform float sdf_pad = 48.0;
uniform vec4 ink_rect = vec4(0.0, 0.0, 1.0, 1.0);
uniform float d_in_max = 34.0;
uniform float hull_on = 0.0;
uniform vec2 P = vec2(772.0, 262.0);
uniform vec2 core = vec2(0.0);
// this instant
uniform float t = 0.0;
uniform float tc = 0.0;
uniform float k = -1.0;
uniform float s = 0.0;
uniform float gain = 1.0;
uniform float haze_on = 1.0;
uniform float haze_k = 1.0;
// the glint ahead: its growth, its flicker, its bar's reach
uniform float gl_g = 0.0;
uniform float gl_fk = 0.0;
uniform float gl_bar = 0.0;
// the hull: its certainty, its tremble, the fringes' crawl, the drive's pulse, the rim
uniform float alpha = 1.0;
uniform vec2 tremble = vec2(0.0);
uniform float hv_k = 0.0;
uniform float pul = 0.0;
uniform float rim_k = 0.0;
// after the snap: the point's shrink and flicker, the pop, the last speck
uniform float pt_g = -1.0;
uniform float pt_fk = 1.0;
uniform float pop = 0.0;
uniform float speck = 0.0;

const float T_WAKE = 0.8;
const vec3 TEAL = vec3(0.30, 1.00, 0.78);
const vec3 MINT = vec3(0.72, 1.00, 0.90);
const vec3 ROSE = vec3(1.00, 0.36, 0.70);
const vec3 WHT = vec3(0.96, 1.00, 0.98);

float fringe(vec2 p) {
	float r1 = length(vec2(p.x - core.x, (p.y - core.y) * 1.15));
	float r2 = length(vec2(p.x - P.x, (p.y - P.y) * 1.15));
	float psi = (r1 - r2) * (TAU / 22.0) - tc * 5.5;
	float rip = cos(r1 * (TAU / 13.0) - tc * 9.0);
	return clamp(0.5 + 0.38 * cos(psi) + 0.17 * rip, 0.0, 1.0);
}

// The cloud's density blurred (the film's box 9 twice): taps on the quarter buffer under a
// triangle 18 px wide each way; the frozen cloud's channel once snapped.
float haze(vec2 p) {
	float acc = 0.0;
	float ws = 0.0;
	for (int y = -3; y <= 3; y++) {
		for (int x = -3; x <= 3; x++) {
			float w = (4.0 - abs(float(x))) * (4.0 - abs(float(y)));
			vec3 L = j_light_at(ghosts_q, p + vec2(float(x), float(y)) * 6.0 + 0.5, world);
			acc += w * (k >= 0.0 ? L.b * haze_k : L.r + L.g);
			ws += w;
		}
	}
	return acc / ws;
}

float hsdf(vec2 h) {
	return j_hull_sdf(sdf, h, ship.zw, sdf_pad, ink_rect);
}

void fragment() {
	vec2 p = floor(SCREEN_UV / SCREEN_PIXEL_SIZE);
	vec2 px = SCREEN_PIXEL_SIZE;
	bool snapped = k >= 0.0;
	float F = fringe(p);
	float Dh = haze_on > 0.5 ? haze(p) : 0.0;

	// --- the sky: wavering inside the cloud; bent by the rings rolling out after
	vec2 q = p;
	if (!snapped && Dh > 0.0) {
		float env = clamp(Dh * 2.2, 0.0, 1.0) * s;
		q = p + vec2(floor((F - 0.5) * 3.2 * env + 0.5), floor((0.5 - F) * 1.6 * env + 0.5));
	}
	if (snapped) {
		float amp = 0.11 * exp(-k / 0.8);
		if (amp > 0.004) {
			float rr = length(vec2(p.x - P.x, (p.y - P.y) * 1.25));
			float front = 10.0 + 430.0 * pow(k, 0.75);
			float m = amp * exp(-pow((rr - front) / 22.0, 2.0)) * sin((rr - front) * 0.45);
			q = floor(P + (p - P) * (1.0 + m) + 0.5);
		}
	}
	vec3 sky = j_world(screen, px, q, world);

	// --- the probable ships as light, banded by the fringes; the haze as glow
	vec3 G = j_light(ghosts, p, world);
	vec3 gcol = TEAL * (0.10 + 1.25 * pow(F, 1.5)) + ROSE * 0.65 * (1.0 - F) * (1.0 - F);
	vec3 Lback = j_light(light_back, p, world) + gcol * G.r * gain;
	vec3 Lglow = Dh * 0.42 * (0.25 + 1.2 * F * F) * TEAL + Dh * 0.42 * 0.35 * pow(1.0 - F, 3.0) * ROSE;

	// --- the destination glint, flickering, with its bar in the hold
	if (gl_g > 0.0) {
		Lglow += j_splat(p, P, 1.0, WHT, (0.3 + 1.6 * gl_g) * gl_fk, 1.0);
		Lglow += j_splat(p, P, 6.0 + 10.0 * gl_g, TEAL, (0.10 + 0.35 * gl_g) * gl_fk, 1.0);
		if (gl_bar > 0.0) {
			Lback += exp(-pow((p.y - P.y) / 0.55, 2.0)) * exp(-abs(p.x - P.x) / gl_bar) * 0.9 * MINT;
		}
	}

	// --- the hull: certainty draining, fringes crawling its plates, the glint's rim light
	vec4 hs = vec4(0.0);
	float Lh = 0.0;
	if (!snapped && hull_on > 0.5) {
		vec2 h = p - tremble - ship.xy;
		vec4 hp = j_hull_px(hull, h, ship.zw);
		if (hp.a > 0.0) {
			hs = vec4(hp.rgb, 1.0);
			if (t > T_WAKE) {
				vec4 ax = texture(aux, (h + 0.5) / ship.zw);
				vec4 ax2 = texture(aux2, (h + 0.5) / ship.zw);
				float seam = ax.r;
				float edge2 = ax2.a;
				vec2 hc = h + ship.xy;
				float dcore = length(vec2(hc.x - core.x, (hc.y - core.y) * 1.7));
				float hv = (0.12 + 0.55 * s) * hv_k * F * F * (0.35 + 0.9 * seam + 0.5 * edge2);
				hv += (0.15 + 0.8 * s) * pul * exp(-dcore / (8.0 + 30.0 * s));
				if (rim_k > 0.0) {
					vec2 l = P - p;
					vec2 N = vec2(hsdf(h + vec2(1.0, 0.0)) - hsdf(h - vec2(1.0, 0.0)), hsdf(h + vec2(0.0, 1.0)) - hsdf(h - vec2(0.0, 1.0)));
					float facing = clamp(dot(normalize(N + 1e-6), l / (length(l) + 1e-6)), 0.0, 1.0);
					hv += facing * facing * edge2 * 0.9 * rim_k;
				}
				Lh = hv;
			}
		}
		if (t > T_WAKE) {
			Lglow += j_splat(p, core, 6.0 + 16.0 * s, TEAL, 0.10 + 0.4 * s * pul, 1.6);
		}
	}

	// --- after the snap: the whole ship as one bright point, its pop, the rings, a last speck
	if (snapped) {
		if (pt_g >= 0.0) {
			Lglow += j_splat(p, P, 1.2, WHT, (3.2 - 0.8 * pt_g) * pt_fk, 1.0);
			Lglow += j_splat(p, P, 16.0 - 11.0 * pt_g, TEAL, (0.9 - 0.3 * pt_g) * pt_fk, 1.0);
			Lglow += j_splat(p, P, 46.0 - 30.0 * pt_g, TEAL, 0.25 * (1.0 - pt_g), 1.0);
			Lback += exp(-pow((p.y - P.y) / 0.55, 2.0)) * exp(-abs(p.x - P.x) / (40.0 - 26.0 * pt_g)) * 0.9 * pt_fk * MINT;
		}
		if (pop > 0.01) {
			Lglow += j_splat(p, P, 1.6, WHT, 7.0 * pop, 1.0);
			Lglow += j_splat(p, P, 10.0 + 40.0 * (k - 0.3), TEAL, 1.0 * pop, 1.0);
			Lback += exp(-pow((p.y - P.y) / 0.6, 2.0)) * exp(-abs(p.x - P.x) / (260.0 * pop + 10.0)) * 2.4 * pop * MINT;
			Lback += exp(-pow((p.x - P.x) / 0.6, 2.0)) * exp(-abs(p.y - P.y) / (70.0 * pop + 5.0)) * 1.2 * pop * MINT;
		}
		if (k > 0.02) {
			float rr = length(vec2(p.x - P.x, (p.y - P.y) * 1.25));
			for (int j = 0; j < 2; j++) {
				float kk = k - (j == 0 ? 0.0 : 0.34);
				if (kk <= 0.0) {
					continue;
				}
				float front = 8.0 + (j == 0 ? 430.0 : 330.0) * pow(kk, 0.75);
				float env = exp(-pow((rr - front) / (12.0 + 26.0 * kk), 2.0)) * exp(-kk / 0.55) * (j == 0 ? 0.9 : 0.6);
				float band = 0.5 + 0.5 * cos((rr - front) * 0.55);
				Lglow += env * band * 0.55 * TEAL + env * (1.0 - band) * 0.30 * ROSE;
			}
		}
		if (speck > 0.0) {
			Lglow += j_splat(p, P, 0.8, WHT, 1.2 * speck, 1.0);
			Lglow += j_splat(p, P, 5.0, TEAL, 0.12 * speck, 1.0);
		}
	}

	// --- compose: sky, back light and back ghosts, glow, the hull at its certainty, the
	// front ghosts, the near light
	bool hid = hs.a > 0.5;
	vec3 o3 = j_add_line(sky, hid ? vec3(0.0) : Lback, 9.0);
	o3 = j_add_glow(o3, hid ? Lglow * 0.25 : Lglow, 7.0, p);
	if (hid) {
		float qv = j_glow_q(Lh, 7.0, p);
		vec3 lit = hs.rgb * (1.0 + 0.8 * qv) * (1.0 - 0.22 * qv * (1.0 - TEAL)) + qv * (TEAL * 0.30 + MINT * 0.10);
		o3 = mix(o3, lit, alpha);
	}
	o3 = j_add_line(o3, gcol * G.g * gain, 9.0);
	o3 = j_add_line(o3, j_light(light_front, p, world), 9.0);
	COLOR = vec4(clamp(o3, 0.0, 1.0), 1.0);
}
