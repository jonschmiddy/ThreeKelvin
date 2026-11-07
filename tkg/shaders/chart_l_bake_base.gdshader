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

#include "res://shaders/chart_l_galaxy.gdshaderinc"

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
// A BALL IN THIS STYLE'S HAND (`ChartLegacy._ball_params`): on for a ball galaxy only
// (the ellipticals, the dwarfs, the merger's remnant); (look, warm reach in ball radii,
// lumpiness, irregularity); (size, fall's power, where its light ends in ball radii,
// globular clusters); its radius in bake px; how round on the screen; its stream's side
uniform bool ball_on = false;
uniform vec4 ball_k = vec4(0.0, 9.0, 0.3, 0.0);
uniform vec4 ball_f = vec4(1.0, 1.3, 2.4, 0.0);
uniform float ball_r = 60.0;
uniform float ball_sq = 0.74;
uniform float ball_side = 1.0;
const float BALL_PERSP = 0.07;

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

// A BALL'S BODY, as the bulge's own light (mode 1's RGB and A): the bulge's amber-to-gold
// climb (`ci`, `co`) at the ball's own size and profile -- a bright middle falling by its
// kind's power to where its light ends, the last of it fading out over a wide band, never
// an edge -- grained by its own points as the bulge is (the fine blur against the wide)
// and clumped by the bake's own noise, as much as the kind is lumpy. All of it bulge (A 1:
// the field's grain of star clouds, none of the disc's dust or arms) where its old warm
// light holds; past that, for a kind with gas, cool gas of the disc's (A 0). A merger's
// remnant lopsided, its outer light pushed to one side, and its stream curling off it.
vec4 ball_light(vec2 g) {
	vec2 p = g - origin;
	vec2 q = vec2(p.x, p.y / ball_sq) / ball_r;
	float look = ball_k.x, irr = ball_k.w;
	float r0 = length(q);
	if (look > 2.5) {
		q.x -= ball_side * 0.32 * g_sm(0.4, 2.0, r0);
	}
	float n = g_fbm(q * 1.4 + vec2(sd, 3.7), 3.0);
	// (the plane's near half is drawn larger on the screen than its far half, so a body
	// round in the plane reached further below its core than above it -- the round ball
	// x1.24 against BallHaloTest's 1.3, Nov 5's review: its light is drawn a little shorter
	// on the near side and longer on the far, so it is round on the screen)
	float dn = length(q) * (1.0 + irr * 0.55 * (n - 0.5)) * (1.0 + BALL_PERSP * q.y / max(length(q), 1e-3));
	float end = ball_f.z;
	// (a dwarf spheroidal spread thin: its light is low all the way across)
	float amp = look > 1.5 && look < 2.5 ? 0.55 : 1.8;
	float prof = pow(1.0 + dn * dn / 0.25, -ball_f.y) * (1.0 - g_sm(end * 0.35, end, dn));
	// its grain: its points, fine against wide, and the bake's clumps
	float e = 1e-4;
	float pts = clamp((g_lum(at(c0, g).rgb) + e) / (g_lum(at(c2, g).rgb) + e), 0.4, 2.2);
	float cl = 0.62 + 0.76 * g_fbm(vec2(p.x * 0.05 - sd, p.y / ball_sq * 0.05 + 4.1), 4.0);
	float lump = ball_k.z;
	float tex = mix(1.0, pts, 0.35 * lump) * mix(1.0, cl, lump);
	float tot = amp * prof * tex;
	// ITS FAINT EDGE BROKEN INTO HAZE AND WISPS, as the disc's outer light is (`chart_l_field`'s
	// outer disc): the palette never dithers the dark, so a smooth faint tail was one flat
	// maroon plate cut off at an ellipse; where the light is faint it is wisps of it
	float wsp = g_sm(0.25, 0.75, g_fbm(p * 0.016 + vec2(sd, 41.0), 4.0)) * 1.5
		* (0.45 + 0.55 * g_fbm(p * 0.05 + vec2(13.0, sd), 3.0));
	// (faint against its own middle: a dwarf spheroidal, faint all across, was wisps
	// through and through, one side of it lost)
	// (over a wider band, Nov 5's review: at 0.3 the round ball's edge went brown to black
	// in a ragged cut-out)
	tot *= mix(wsp, 1.0, g_sm(0.04, 0.6, tot * 1.8 / amp));
	// the merger's stream: off one side, curling out from the body as it thins
	float strm = 0.0;
	if (look > 2.5) {
		vec2 qs = vec2(q.x * ball_side, q.y);
		float a = atan(qs.y, qs.x);
		float u = mod(a + 0.6, TAU_G);
		if (u < 2.6) {
			float rs = 1.15 + 0.75 * u;
			float w = 0.16 + 0.08 * u;
			float sn = g_fbm(qs * 2.2 + vec2(9.0, sd), 3.0);
			strm = 0.55 * exp(-pow((length(qs) - rs) / w, 2.0)) * (1.0 - 0.7 * u / 2.6)
				* (0.3 + 1.4 * g_sm(0.35, 0.75, sn));
		}
	}
	// the colour: warm where its old stars hold, toward white at the middle as the bulge's;
	// a dwarf spheroidal's greyed; past the warm reach (a kind with gas) the disc's cool gas
	float inner = exp(-dn / 0.45);
	vec3 ci = vec3(1.0, 0.82, 0.55) / g_lum(vec3(1.0, 0.82, 0.55));
	vec3 co = vec3(0.95, 0.45, 0.17) / g_lum(vec3(0.95, 0.45, 0.17));
	vec3 kw = co * (1.0 - inner) + ci * inner;
	if (look > 1.5 && look < 2.5) {
		kw = mix(kw, vec3(1.0, 0.97, 0.92), 0.9);
	}
	vec3 kc = vec3(0.42, 0.62, 1.3) / g_lum(vec3(0.42, 0.62, 1.3));
	float ww = 1.0 - g_sm(ball_k.y * 0.55, ball_k.y * 1.5, dn);
	float tw = tot * ww, tc = tot * (1.0 - ww) + strm;
	vec3 col = tw * kw + tc * kc;
	float all_ = tw + tc;
	return vec4(col, all_ > 1e-6 ? tw / all_ : 0.0);
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
		if (ball_on) {
			COLOR = ball_light(g);
		}
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
