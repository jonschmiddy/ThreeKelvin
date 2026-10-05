shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE GALAXY'S STANDING FIELDS, worked out once a galaxy from the blurred
// points (`ChartSky`'s bake; the mockup's `baseGen`, line for line):
//   mode 0, a probe: one texel in eight each way, what the normalisers are
//           measured from (the light before its gain, the wide and middle
//           light, the dust; and below them, the clouds' gas);
//   mode 1, the stars' gathered light with its colour (RGB) and how much of
//           it is the bulge's (A): the arms lifted at their crests and let down
//           between, the bulge climbing, the core tinted gold;
//   mode 2, the arms' light at the middle scale (R), the ridge measure (G),
//           the dark clouds (B);
//   mode 3, the clouds' own gas in their own colours, at 2x2 blocks;
//   mode 4, the dust: the lanes on the inner edge of each arm (R) and the
//           bulge's own filaments (G), before their strength and before the
//           blur that makes them dust rather than cracks (`ChartSky`).
// Everything here is in the bake's pixels: the chart's opening view, re-tilted.

#include "res://shaders/chart_galaxy.gdshaderinc"

uniform sampler2D c0 : filter_linear, repeat_disable;
uniform sampler2D c1 : filter_linear, repeat_disable;
uniform sampler2D c2 : filter_linear, repeat_disable;
uniform sampler2D c3 : filter_linear, repeat_disable;
uniform sampler2D cbf : filter_linear, repeat_disable;
uniform sampler2D cg : filter_linear, repeat_disable;
uniform int mode = 1;
uniform vec2 size = vec2(896.0, 616.0);
uniform vec2 out_size = vec2(896.0, 616.0);
uniform vec2 origin = vec2(448.0, 308.0);
uniform float eff = 0.38;
uniform float bsq = 0.86;
uniform float bul = 10.0;
uniform float arm_k = 1.0;
uniform float sd = 0.0;
uniform float ref = 0.001;
uniform float gain = 1.0;
uniform float aa_ref = 1.0;
uniform float cd_ref = 1.0;
uniform float gc_ref = 1.0;
uniform float big_r = 261.0;
uniform float chaos = 0.0;
uniform int arms = 2;
uniform float bar = 0.0;
uniform float twist = 3.0;
uniform float spin = 0.0;

vec4 at(sampler2D t, vec2 p) {
	return texture(t, (p + 0.5) / size);
}

vec3 raw_light(vec2 g) {
	float lx = g.x - origin.x, ly = (g.y - origin.y) / eff;
	float wk = 16.0 - 9.0 * arm_k;
	float wx = (g_fbm(vec2(lx * 0.022 + sd, ly * 0.022), 3.0) - 0.5) * wk;
	float wy = (g_fbm(vec2(lx * 0.022 + 31.7, ly * 0.022 - sd), 3.0) - 0.5) * wk * eff;
	float clump = 0.62 + 0.76 * g_fbm(vec2(lx * 0.05 - sd, ly * 0.05 + 4.1), 4.0) * (1.0 - 0.5 * arm_k) + 0.38 * arm_k;
	vec2 w = clamp(g + vec2(wx, wy), vec2(0.0), size - 1.001);
	float ww = 0.55 - 0.4 * arm_k, wf = 0.5 + 0.25 * arm_k;
	return (ww * at(c2, g).rgb + 0.85 * at(c1, w).rgb + wf * at(c0, w).rgb) * clump;
}

float ridge(vec2 g) {
	return (g_lum(at(c1, g).rgb) + ref * 0.3) / (g_lum(at(c3, g).rgb) + ref);
}

float aa_at(vec2 g) {
	return min(1.2, g_lum(at(c1, g).rgb) / aa_ref);
}

float shape_angle(float r, int arm, int n, float along) {
	float base = float(arm) * TAU_G / float(n) + spin;
	if (bar > 0.0 && r < bar) {
		return base + along * 0.22;
	}
	float tt = bar > 0.0 ? (r - bar) / max(0.001, 1.0 - bar) : r;
	return base + tt * twist + along;
}

// The lane at a bake pixel: where the arm's light climbs fastest toward the
// core, and along each arm's own curve just inside its crest, broken up. The
// ridge that concentrates it is squared, not cubed as the mockup had it (a
// cube of a crease is a line one pixel wide however far you zoom in), and the
// band along the arm half as wide again, so a lane is a band of dust.
float lane_shape(vec2 g) {
	vec2 p = g - origin;
	float lx = p.x, ly = p.y / eff;
	float dd = length(vec2(lx, ly));
	float r = dd / big_r;
	if (arms <= 0 || r <= 0.1 || r >= 1.1) {
		return 0.0;
	}
	float win = g_sm(0.12, 0.22, r) * (1.0 - g_sm(0.85, 1.05, r));
	vec2 un = p / max(length(p), 1e-3);
	float grad = aa_at(g + un * 5.0) - aa_at(g - un * 5.0);
	float lv = g_sm(0.07, 0.32, grad) * g_sm(0.12, 0.5, aa_at(g));
	float th = atan(ly, lx) + (g_fbm(vec2(lx * 0.02 + 7.0, ly * 0.02), 3.0) - 0.5) * (0.3 + chaos * 1.2);
	for (int k = 0; k < 12; k++) {
		if (k >= arms) {
			break;
		}
		float d = mod(th - shape_angle(r, k, arms, -0.38) + PI, TAU_G) - PI;
		float dist = abs(d) * r * big_r, ww = 4.5 * (0.6 + 0.7 * r);
		lv = max(lv, 0.5 * exp(-(dist / ww) * (dist / ww)));
	}
	float rdg = pow(1.0 - abs(2.0 * g_fbm(vec2(lx * 0.06 + sd, ly * 0.06), 4.0) - 1.0), 2.0);
	float brk = 0.3 + 0.7 * g_sm(0.3, 0.58, g_fbm(vec2(lx * 0.028 - sd, ly * 0.028 + 2.0), 4.0));
	return lv * (0.12 + rdg) * brk * win * g_sm(bul * 0.45, bul * 0.95, dd);
}

// The bulge's own dust: filaments wound into it, in the disc's plane.
float nuc_shape(vec2 g) {
	vec2 p = g - origin;
	float xd = p.x, yd = p.y / eff, rd = length(vec2(xd, yd));
	if (rd >= bul * 1.8 || rd <= bul * 0.06) {
		return 0.0;
	}
	float a2 = atan(yd, xd) + 2.6 * exp(-rd / (bul * 0.7));
	vec2 w = vec2(cos(a2), sin(a2)) * rd;
	float rdg = pow(1.0 - abs(2.0 * g_fbm(vec2(w.x * 0.16 + sd, w.y * 0.16 - sd), 4.0) - 1.0), 3.0);
	return g_sm(0.12, 0.55, rdg) * g_sm(bul * 0.08, bul * 0.3, rd) * (1.0 - g_sm(bul, bul * 1.8, rd));
}

void fragment() {
	vec2 pix = floor(UV * out_size);
	if (mode == 0) {
		float ph = floor(out_size.y * 0.5);
		bool gas_row = pix.y >= ph;
		vec2 g = vec2(pix.x, gas_row ? pix.y - ph : pix.y) * 8.0;
		if (gas_row) {
			COLOR = vec4(g_lum(at(cg, g).rgb), 0.0, 0.0, 1.0);
		} else {
			float d = length(vec2(g.x - origin.x, (g.y - origin.y) / eff));
			float raw = d > bul * 1.3 ? g_lum(raw_light(g)) : -1.0;
			COLOR = vec4(raw, g_lum(at(c3, g).rgb), g_lum(at(c1, g).rgb), at(cg, g).a);
		}
	} else if (mode == 1) {
		vec2 g = pix;
		vec2 bf = at(cbf, g).rg;
		float bf0 = bf.r > 1e-5 ? min(1.0, bf.g / bf.r) : 0.0;
		float i0 = g_lum(raw_light(g)) * gain;
		float lw = g_sm(0.08, 0.45, i0 * (1.0 - bf0));
		float rg = clamp(ridge(g), 0.3, 2.6);
		float cont = pow(rg, 0.9 * arm_k * lw);
		float crest = arm_k * lw * g_sm(1.25, 2.0, rg);
		float cap = 0.8 + 0.4 * arm_k;
		float idr = i0 * (1.0 - bf0), idc = idr * cont * (1.0 + 0.45 * crest);
		// capped, as the mockup did, so the disc's crowd is a plateau the arms
		// stand on; but with a little of the light past the cap let through, so
		// a smooth disc (a lenticular, an elliptical's) still climbs to its
		// middle instead of flattening into one plate
		float xi = max(idc, idr * 0.38);
		float id = cap * tanh(xi / cap) + 0.12 * max(0.0, xi - cap);
		float ib = 1.7 * tanh(i0 * bf0 * 1.3 / 1.7);
		float tot = id + ib;
		vec3 cr = 0.6 * at(c3, g).rgb + 0.3 * at(c2, g).rgb + 0.1 * at(c1, g).rgb;
		float cl = g_lum(cr);
		vec3 h = cl > 1e-6 ? cr / cl : vec3(0.85, 0.98, 1.25);
		h = 1.0 + (h - 1.0) * 1.7;
		float d = length(vec2(g.x - origin.x, (g.y - origin.y) / bsq));
		float wc = exp(-d / bul) * 0.7, inner = exp(-d / (bul * 0.4));
		vec3 ci = vec3(1.0, 0.82, 0.55) / g_lum(vec3(1.0, 0.82, 0.55));
		vec3 co = vec3(0.95, 0.45, 0.17) / g_lum(vec3(0.95, 0.45, 0.17));
		vec3 k = co * (1.0 - inner) + ci * inner;
		h = h * (1.0 - wc) + k * wc;
		h = h * (1.0 - 0.25 * crest) + vec3(0.9, 0.98, 1.3) * 0.25 * crest;
		COLOR = vec4(max(vec3(0.0), tot * h), tot > 1e-6 ? ib / tot : 0.0);
	} else if (mode == 2) {
		vec2 g = pix;
		float aa = min(1.2, g_lum(at(c1, g).rgb) / aa_ref);
		float cd = g_sm(0.08, 0.9, at(cg, g).a / cd_ref);
		COLOR = vec4(aa, ridge(g), cd, 1.0);
	} else if (mode == 4) {
		COLOR = vec4(lane_shape(pix), nuc_shape(pix), 0.0, 1.0);
	} else {
		vec2 g = pix * 2.0 + 0.5;
		vec3 c = at(cg, g).rgb;
		float l = g_lum(c);
		vec3 o = vec3(0.0);
		if (l > 2.5e-5) {
			float i = pow(min(1.3, l / gc_ref), 0.85) * 0.8;
			o = max(vec3(0.0), 1.0 + (c / l - 1.0) * 2.2) * i;
		}
		COLOR = vec4(o, 1.0);
	}
}
