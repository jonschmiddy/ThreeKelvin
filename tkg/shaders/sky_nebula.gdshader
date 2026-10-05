shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// THE NEBULA A SYSTEM SITS IN, SEEN FROM INSIDE (Jon: "YES THAT WOULD BE SO
// COOL"): the star chart's look for the cloud's kind (`chart_field.gdshader`,
// `neb_v2`) worked out across the whole sky round you instead of as a shape
// seen from afar -- big, vivid, billowing in place -- in the place's 2x2
// blocks, tone-mapped so nothing clips, before the palette pass sets it to the
// system's colours. Far off: it slides a little as the camera pans (`off`) and
// does not zoom; the depth sheets lie over it.
//
//   0 EMISSION   rose hydrogen billows round the teal oxygen glow of the young
//                cluster lighting it, dark pillars reaching toward the cluster
//                with their tips lit, lanes, young stars glinting;
//   1 REFLECTION blue haze round the few bright stars that light it, combed
//                into striations, shafts of their light turning slowly;
//   2 PLANETARY  the shell's ring arcing across the sky, red at its rim and the
//                cloud's own colour within, its hot white star at the middle;
//   3 REMNANT    tangled filaments everywhere, the shell's arc red outside and
//                teal just within;
//   4 DARK       dust that hides what is behind it, its edge toward the light lit.
//
// WEATHER, rare (`SystemView._Weather` sets `w_*`): in emission and dark clouds
// a distant discharge, a branching flash lighting a patch of cloud from within;
// in a remnant a shock front glimmering along the filaments as it passes; in a
// reflection cloud a shaft of a lighting star's light sweeping slowly through
// the haze.
// It adds light (rgb) and takes it away (alpha): premultiplied.

uniform int kind = 0;
uniform int shape = 0;
uniform float sd = 0.0;
uniform vec2 off = vec2(0.0);
// seconds on the gas's own slow clock; 0 holds it still (reduced motion)
uniform float time = 0.0;
uniform float strength = 1.0;
// the tone map's exposure: low enough that the orbits and worlds read over it
uniform float expo = 0.8;
// the cloud's own colour (`NebulaField.Cloud.base_colour`)
uniform vec3 hue = vec3(0.44, 0.88, 0.67);
// the weather: where (on the sky, before `off`), how long ago, how strong (0: none)
uniform vec2 w_at = vec2(-9999.0);
uniform float w_age = 99.0;
uniform float w_k = 0.0;

float hash2(vec2 p) {
	ivec2 q = ivec2(floor(p));
	uint h = (uint(q.x) * 374761393u) ^ (uint(q.y) * 668265263u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}
float noise2(vec2 p) {
	vec2 i = floor(p), f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash2(i), b = hash2(i + vec2(1.0, 0.0)), c = hash2(i + vec2(0.0, 1.0)), d = hash2(i + vec2(1.0, 1.0));
	return a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y;
}
float fbm(vec2 p, int o) {
	float a = 0.5, s = 0.0, n = 0.0;
	for (int i = 0; i < o; i++) { s += a * noise2(p); n += a; p = p * 2.03 + vec2(17.1, 9.3); a *= 0.5; }
	return s / n;
}
float sm(float a, float b, float x) { float u = clamp((x - a) / (b - a), 0.0, 1.0); return u * u * (3.0 - 2.0 * u); }
float ridge(float v, float k) { return pow(1.0 - abs(2.0 * v - 1.0), k); }
// a point fixed for this cloud (k picks which), somewhere in the box lo..hi
vec2 spot(float k, vec2 lo, vec2 hi) {
	return lo + vec2(hash2(vec2(k * 13.0 + sd * 17.0, 5.0)), hash2(vec2(k * 17.0 + sd * 13.0, 9.0))) * (hi - lo);
}

const vec3 HA = vec3(1.0, 0.2, 0.3);
const vec3 O3 = vec3(0.2, 0.95, 0.85);
const vec3 BLU = vec3(0.32, 0.52, 1.0);
const vec3 STAR = vec3(0.85, 0.93, 1.0);

void fragment() {
	vec2 px = floor(UV * vec2(960.0, 540.0));
	vec2 b = px - mod(px, 2.0) + 1.0;
	vec2 sp = b - off;
	vec2 u = sp / 430.0 + vec2(sd * 1.7, sd * 0.9);
	// CHURNING IN PLACE, as the chart's gas does: the push that shapes the
	// billows turns slowly, each region on its own phase and at its own pace,
	// so a billow swells, leans and subsides while its neighbours do their
	// own; nothing slides
	float ph0 = noise2(u * 0.6 + vec2(3.0, sd)) * 6.2832;
	float th = ph0 + time * (0.06 + 0.05 * noise2(u * 0.5 + vec2(sd, 51.0)));
	vec2 wv = time > 0.0 ? vec2(cos(th), sin(th)) * 0.2 : vec2(0.0);
	float w = fbm(u * 0.9 + vec2(sd, 7.0), 2);
	float bil = fbm(u * 1.4 + wv * w, 5);
	float fine = fbm(u * 4.2 + wv * w * 1.6 + vec2(5.0, sd), 4);
	vec3 L = vec3(0.0);
	float dk = 0.0;
	// how much cloud there is here, for the weather to light
	float dens = 0.0;
	if (kind == 0) {
		// the young cluster that lights it, somewhere about the view
		vec2 cc = spot(1.0, vec2(-160.0, -120.0), vec2(1120.0, 660.0));
		vec2 dc = sp - cc;
		float r = length(dc) / 720.0;
		vec2 dir = dc / max(length(dc), 1.0);
		float body = sm(0.25, 0.75, bil + 0.2 * (1.0 - min(r, 1.4)));
		float core = exp(-r * r / 0.09) * (0.45 + 0.6 * fine);
		// pillars: dark fingers reaching in toward the cluster, and lanes
		float fing = ridge(fbm(dir * 2.8 + vec2(r * 0.9 + sd, sd * 2.0) + wv * 0.15, 3), 7.0);
		float pillar = fing * sm(0.24, 0.62, r) * sm(0.32, 0.62, bil);
		float lane = ridge(fbm(u * 2.2 + vec2(sd, 11.0) + wv * 0.5, 3), 9.0);
		dk = clamp(pillar * 1.25 + lane * 0.6 * body, 0.0, 0.9);
		// the pillars' tips facing the cluster, lit
		float tip = fing * exp(-pow((r - 0.27) / 0.06, 2.0)) * sm(0.32, 0.6, bil);
		vec3 col = mix(HA, O3, sm(0.05, 0.7, core));
		float glow = body * (0.3 + 0.65 * fine) + core * 0.9;
		L = col * glow * (1.0 - dk) + vec3(1.0, 0.72, 0.55) * tip * 1.4;
		// young stars glinting round the cluster, a block each
		if (r < 0.5 && hash2(b * 0.5 + vec2(sd * 91.0, 3.0)) > 0.993) {
			L += STAR * 2.4 * (1.0 - r / 0.5);
		}
		dk *= 0.85;
		dens = body;
	} else if (kind == 1) {
		float haze = 0.1 + 0.6 * sm(0.2, 0.75, bil);
		// combed: faint striations all one way
		float stri = 0.65 + 0.55 * noise2(vec2(dot(u, vec2(0.8, 0.6)) * 12.0, dot(u, vec2(-0.6, 0.8)) * 1.5) + vec2(sd, 0.0) + wv * 0.3);
		vec2 st[3];
		int wk = -1;
		float wbest = 1e9;
		for (int k = 0; k < 3; k++) {
			st[k] = spot(float(k) + 2.0, vec2(60.0, 50.0), vec2(900.0, 490.0));
			float dw = length(w_at - st[k]);
			if (dw < wbest) { wbest = dw; wk = k; }
		}
		float lit = 0.0;
		float shafts = 0.0;
		float wbeam = 0.0;
		vec3 sparks = vec3(0.0);
		for (int k = 0; k < 3; k++) {
			vec2 d = sp - st[k];
			float r = length(d);
			lit += exp(-r * r / (240.0 * 240.0));
			// SHAFTS of its light, turning slowly round it
			vec2 dir = d / max(r, 1.0);
			float rt = time * 0.012 * (k == 1 ? -1.0 : 1.0);
			vec2 dr = vec2(dir.x * cos(rt) - dir.y * sin(rt), dir.x * sin(rt) + dir.y * cos(rt));
			float ray = pow(fbm(dr * 3.2 + vec2(float(k) * 5.0, sd), 3), 3.0) * 2.4;
			shafts += ray * exp(-r / 280.0) * sm(14.0, 90.0, r);
			if (r < 3.0) {
				sparks += STAR * 3.4;
			} else if (r < 7.0) {
				sparks += STAR * 0.6;
			}
			// THE WEATHER: one shaft of the star nearest it, brightening as it
			// sweeps slowly through the haze, and gone
			if (w_k > 0.0 && k == wk && w_age < 9.0) {
				vec2 wa = w_at - st[k];
				float a0 = atan(wa.y, wa.x) + w_age * 0.035;
				vec2 bd = vec2(cos(a0), sin(a0));
				float along = dot(d, bd);
				float across = abs(d.x * bd.y - d.y * bd.x);
				float env = sin(3.1416 * clamp(w_age / 9.0, 0.0, 1.0));
				float beam = exp(-pow(across / (10.0 + max(along, 0.0) * 0.09), 2.0)) * sm(10.0, 60.0, along) * exp(-max(along, 0.0) / 520.0);
				wbeam += beam * env * env * w_k;
			}
		}
		L = BLU * haze * stri * (0.25 + 0.9 * min(lit, 1.5)) + mix(BLU, STAR, 0.4) * shafts * 0.38 * haze + sparks
			+ mix(BLU, STAR, 0.5) * wbeam * (0.35 + haze) * 1.1;
		dens = haze;
	} else if (kind == 2) {
		// the hot star at the shell's middle, and the shell round it
		vec2 cc = spot(1.0, vec2(-80.0, -60.0), vec2(1040.0, 600.0));
		float aa = hash2(vec2(sd, 77.0)) * 3.1416;
		vec2 d = sp - cc;
		vec2 dd = vec2(d.x * cos(aa) - d.y * sin(aa), d.x * sin(aa) + d.y * cos(aa));
		if (shape == 1 || shape == 2) {
			dd.y *= 1.5;
		}
		// sized so its ring passes near the middle of the view
		float R0 = max(380.0, length(cc - vec2(480.0, 270.0)) * (0.75 + 0.35 * hash2(vec2(sd, 41.0))));
		float rr = length(dd) / R0;
		float dr = rr - 1.0 + (fine - 0.5) * 0.07 + (bil - 0.5) * 0.08;
		float ring = exp(-pow(dr / (dr < 0.0 ? 0.13 : 0.035), 2.0));
		// the rim itself, thin and red, the cloud's own colour just within it,
		// and the shell clumped into knots along it
		float rim = exp(-pow((dr + 0.012) / 0.018, 2.0));
		float band = exp(-pow((dr + 0.075) / 0.06, 2.0));
		float clump = 0.45 + 0.9 * pow(fbm(dd / R0 * 9.0 + vec2(sd, 4.0) + wv * 0.3, 3), 1.5);
		float fill = (1.0 - sm(0.4, 0.98, rr)) * 0.3;
		float knots = 0.0;
		if (shape == 3) {
			vec2 k1 = dd / R0 - vec2(1.12, 0.0);
			vec2 k2 = dd / R0 + vec2(1.12, 0.0);
			knots = exp(-dot(k1, k1) / 0.004) + exp(-dot(k2, k2) / 0.004);
		}
		float outer = sm(1.0, 1.5, rr) * sm(0.35, 0.75, bil) * 0.22;
		float r0 = length(d);
		float star = r0 < 3.0 ? 4.0 : exp(-pow(r0 / 18.0, 2.0)) * 0.7;
		L = vec3(1.0, 0.3, 0.28) * rim * 1.4 * clump + hue * (band * 0.95 + ring * 0.2) * clump
			+ hue * fill * (0.5 + 0.7 * bil) + mix(hue, HA, 0.5) * outer * (0.5 + fine)
			+ vec3(1.0, 0.55, 0.4) * knots * 1.6 + STAR * star;
		// the bubble blown clear of the medium: what is behind it dimmed
		dk = 0.3 * (1.0 - sm(0.8, 1.0, rr));
		dens = max(ring, fill);
	} else if (kind == 3) {
		vec2 cc = spot(1.0, vec2(-300.0, -260.0), vec2(1260.0, 800.0));
		float r = length(sp - cc) / 760.0;
		float rag = r + (bil - 0.5) * 0.3;
		// thin tangled strands: the contours of two noises, each a line
		float fil = ridge(fbm(u * 2.4 + vec2(sd, 2.0) + wv * 0.4, 4), 14.0);
		float fil2 = ridge(fbm(u * 3.6 + vec2(3.0, sd) - wv * 0.4, 4), 16.0);
		float shell = exp(-pow((rag - 0.85) / 0.14, 2.0));
		float inner = exp(-pow((rag - 0.72) / 0.12, 2.0));
		float amb = 0.3 + 0.4 * sm(0.4, 0.75, bil);
		L = HA * fil * (amb * 1.2 + 1.7 * shell) + O3 * fil2 * (amb * 0.6 + 1.5 * inner)
			+ mix(HA, O3, 0.5) * 0.06 * bil * (0.3 + shell + inner);
		dens = max(fil, fil2 * 0.8) * (0.4 + shell + inner);
	} else {
		float d = sm(0.3, 0.66, bil + 0.15 * (fine - 0.5));
		dk = d * 0.86;
		// its edge toward the light (from a side of the sky of its own), lit
		float la = hash2(vec2(sd, 31.0)) * 6.2832;
		vec2 ld = vec2(cos(la), sin(la));
		float bil2 = fbm(u * 1.4 + wv * w - ld * 0.05, 5);
		float face = sm(0.0, 0.012, bil - bil2);
		float rim = sm(0.05, 0.16, d) * (1.0 - sm(0.2, 0.38, d)) * face * sm(0.4, 0.72, fine);
		L = vec3(1.0, 0.62, 0.42) * rim * 0.5 + vec3(0.3, 0.24, 0.42) * (1.0 - d) * sm(0.2, 0.5, bil) * 0.35;
		dens = d;
	}
	// THE GLOW OF THE CLOUD YOU ARE IN, faint, everywhere: no part of the sky
	// inside it is the black of open space
	L += (kind == 4 ? vec3(0.22, 0.17, 0.3) : hue) * (0.07 + 0.1 * bil) * (1.0 - dk);
	// THE WEATHER: a discharge deep in the cloud (emission, dark), or a shock
	// front passing through the filaments (remnant)
	if (w_k > 0.0) {
		vec2 wd = sp - w_at;
		float wr = length(wd);
		if (kind == 0 || kind == 4) {
			// a strike, a second, a flicker, gone in under a second and a half
			float a = w_age;
			float f = exp(-a / 0.08) + 0.75 * exp(-max(a - 0.22, 0.0) / 0.1) * step(0.22, a)
				+ 0.4 * exp(-max(a - 0.5, 0.0) / 0.25) * step(0.5, a);
			// the patch of cloud it lights from within, brightest where thickest
			float patch = exp(-wr * wr / (115.0 * 115.0)) * (0.25 + dens);
			// the branching channel itself, faint, through the middle of it
			float ch = ridge(fbm(wd / vec2(70.0, 38.0) + vec2(sd * 3.0, 0.0), 4), 22.0)
				* exp(-wr * wr / (80.0 * 80.0));
			vec3 lc = kind == 0 ? vec3(1.0, 0.82, 0.9) : vec3(0.82, 0.78, 1.0);
			L += lc * f * w_k * (patch * 0.6 + ch * 1.4);
			// the lit dust no longer hides the patch
			dk *= 1.0 - min(1.0, f * w_k * patch * 0.8);
		} else if (kind == 3) {
			float R = 30.0 + w_age * 75.0;
			float front = exp(-pow((wr - R) / 12.0, 2.0)) * sm(0.0, 0.6, w_age) * (1.0 - sm(3.5, 6.0, w_age));
			L += mix(vec3(1.0, 0.9, 0.95), O3, 0.6) * front * (0.08 + dens * 0.9) * w_k;
		}
	}
	L *= strength;
	vec3 c = vec3(1.0) - exp(-L * expo);
	COLOR = vec4(c, clamp(dk * strength, 0.0, 0.95));
}
