shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// LEGACY's CLOUD (the rendering style LEGACY, `DisplaySettings.render_style`):
// the sector map's nebula as it was before SIMPLIFIED, its look unchanged, its
// gas now streaming on SIMPLIFIED's current (C's two-phase flow map) instead of
// churning in place: its noises are baked once (`sky_field.gdshader`, `legacy`)
// and read here carried along the flow. SIMPLIFIED's own cloud, lit by the sun,
// is `sky_nebula.gdshader`.
//
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
// ITS WEATHER (Jon: "More weather!"), set by `SkyWeather`: slot A (`w_*`) holds
// one medium event or showpiece, slot B (`s_*`) one small one. Each kind's
// events are worked out inside that kind's block, from its own terms (the
// pillars, the stars, the rim, the strands, the dust), so an event lights only
// what is there. `w_ev` / `s_ev` say which of the kind's events:
//   EMISSION    A: 0 strike (and a near strike), 1 tide, 2 jet, 3 new star;  B: 1 glints
//   REFLECTION  A: 0 shaft, 1 spoke, 2 breathe, 3 echo;                     B: 1 glitter
//   PLANETARY   A: 0 ring run, 1 fliers, 2 halo, 3 searchlights;            B: 1 lamps
//   REMNANT     A: 0 shock, 1 flare, 2 shrapnel, 3 pearls;                  B: 1 spark
//   DARK        A: 0 strike (backlit), 1 rays, 2 fan;                       B: 1 dawn, 2 ember
// Light is gathered light, added before the tone map; an event's added light
// fades out under the ship (`g_ship`); every term is behind `w_k > 0` or
// `s_k > 0`, so nothing costs anything while the sky is calm.
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
// SLOT A: where (on the sky, before `off`), how long ago (negative: its
// precursor), how strong (0: none), and what the event needs
uniform vec2 w_at = vec2(-9999.0);
uniform float w_age = 99.0;
uniform float w_k = 0.0;
uniform int w_ev = 0;
uniform vec2 w_dir = vec2(1.0, 0.0);
uniform float w_seed = 0.0;
uniform float w_size = 115.0;
uniform float w_pre = 0.0;
// the upgrades to the events there were before (a harness's `wup=0`: today's)
uniform bool w_up = true;
// chain links, bullets: meaning per event
uniform vec4 w_pts[6];
uniform int w_n = 0;
// SLOT B
uniform int s_ev = 0;
uniform vec2 s_at = vec2(-9999.0);
uniform float s_age = 99.0;
uniform float s_k = 0.0;
uniform vec2 s_dir = vec2(1.0, 0.0);
uniform float s_seed = 0.0;
// THE SHIP, on screen, and the radii its guard fades over
uniform vec4 g_ship = vec4(-9999.0, -9999.0, 30.0, 90.0);
// THE BAKE (`SkyBake.field`, legacy): t0 the kind's own noises, t1 the
// billows (two channels, high and low, so a dark cloud's lit face keeps its
// edge) and the fine noise; its size in texels and its margin in blocks
uniform sampler2D t0 : filter_linear, repeat_disable;
uniform sampler2D t1 : filter_linear, repeat_disable;
uniform vec2 ftex = vec2(576.0, 366.0);
uniform float fmb = 48.0;
// GRAPHICS LOW: one read a noise, no flow
uniform bool low = false;

#include "res://shaders/sky_noise.gdshaderinc"

// ---------------------------------------------------------------- the bake, carried on the current
// (SIMPLIFIED's own current, `sky_nebula.gdshader`: the same speed, period and
// eddies, so the two styles' gas moves alike)
vec2 fuv(vec2 sp) { return (sp + fmb * 2.0) / (2.0 * ftex); }
vec2 flow_vel(vec2 P) {
	vec2 a = P / 230.0, b = kitRot2(P) / 97.0 + 1.7;
	vec2 v1 = vec2(sin(a.x) * cos(a.y), -cos(a.x) * sin(a.y));
	vec2 v2 = vec2(sin(b.x) * cos(b.y), -cos(b.x) * sin(b.y));
	return vec2(0.55, -0.16) + 0.42 * v1 + 0.22 * v2;
}
// the two reads of the current and their weights (wb = 0: one read, no flow)
struct Fl { vec2 p0; vec2 p1; float wa; float wb; };
Fl flow_at(vec2 P) {
	Fl f;
	f.p0 = fuv(P);
	f.p1 = f.p0;
	f.wa = 1.0;
	f.wb = 0.0;
	if (low || time <= 0.0) return f;
	vec3 ph = kitFlowPhase(time, 24.0);
	vec2 v = flow_vel(P) * 0.65 * 24.0;
	f.p0 = fuv(P - v * ph.x);
	f.p1 = fuv(P - v * ph.y);
	f.wb = ph.z;
	f.wa = 1.0 - ph.z;
	return f;
}
// a crossfade that keeps its contrast (two half-weighted reads blur to the mean)
float keep(float a0, float a1, Fl f) {
	if (f.wb <= 0.0) return a0;
	float g = mix(1.0, inversesqrt(f.wa * f.wa + f.wb * f.wb), 0.6);
	float m = 0.5 * (a0 + a1);
	return clamp(m + (a0 * f.wa + a1 * f.wb - m) * g, 0.0, 1.0);
}
// a value held in two channels, high and low
float hilo(vec2 c) { return c.x + c.y / 255.0; }
// a point fixed for this cloud (k picks which), somewhere in the box lo..hi
vec2 spot(float k, vec2 lo, vec2 hi) {
	return lo + vec2(hash2(vec2(k * 13.0 + sd * 17.0, 5.0)), hash2(vec2(k * 17.0 + sd * 13.0, 9.0))) * (hi - lo);
}
// an envelope: up over r, held h, down over f (0 before it starts)
float env(float a, float r, float h, float f) { return sm(0.0, r, a) * (1.0 - sm(r + h, r + h + f, a)); }
float adiff(float a, float b) { return abs(mod(a - b + PI, TAU) - PI); }
float cross2(vec2 a, vec2 b) { return a.x * b.y - a.y * b.x; }
// a Cepheid's beat: a quick brighten, a slow fade, every seven seconds
float pulse7(float x) {
	if (x < 0.0) return 0.0;
	float q = mod(x, 7.0);
	return q < 1.05 ? sm(0.0, 1.05, q) : 1.0 - sm(1.05, 7.0, q);
}

const vec3 HA = vec3(1.0, 0.2, 0.3);
const vec3 O3 = vec3(0.2, 0.95, 0.85);
const vec3 BLU = vec3(0.32, 0.52, 1.0);
const vec3 STAR = vec3(0.85, 0.93, 1.0);

// ONE STRIKE (Jon's approved discharge, factored): a patch of cloud `size`
// across flashing from within with its faint branching channel, a restrike, a
// flicker, and (upgraded) a teal-tinged afterglow. Summed into the frame's
// totals so overlapping links never pass one strike's peak. `back`: a dark
// cloud's version, lit from behind, its restrike `dir * 80` along.
void strike(vec2 sp, vec2 at, float a, float k, float size, float dens, bool back, vec2 dir,
		inout float fp, inout float ch, inout float ag, inout float bk) {
	if (a < 0.0 || k <= 0.0) return;
	vec2 wd = sp - at;
	float wr = length(wd);
	if (wr > 2.6 * size + (back ? 80.0 : 0.0)) return;
	float s = size / 115.0;
	float f1 = exp(-a / 0.08) + 0.4 * exp(-max(a - 0.5, 0.0) / 0.25) * step(0.5, a);
	float f2 = 0.75 * exp(-max(a - 0.22, 0.0) / 0.1) * step(0.22, a);
	float P = exp(-wr * wr / (size * size));
	float chn = 0.0;
	if (wr < 2.6 * size && f1 + f2 > 0.004) {
		chn = ridge(fbm(wd / (vec2(70.0, 38.0) * s) + vec2(sd * 3.0, 0.0), 4), 22.0) * exp(-wr * wr / (6400.0 * s * s));
	}
	float glowk = w_up ? exp(-max(a - 0.5, 0.0) / 1.4) * sm(0.3, 0.6, a) * 0.18 * k : 0.0;
	if (back) {
		vec2 d2 = sp - (at + dir * 80.0);
		float P2 = exp(-dot(d2, d2) / (size * size));
		bk += f1 * k * P + f2 * k * P2;
		ch += (f1 + f2) * k * chn * (1.0 - dens) * 0.5;
		ag += P * glowk;
	} else {
		fp += (f1 + f2) * k * P * (0.25 + dens);
		ch += (f1 + f2) * k * chn;
		ag += P * (0.25 + dens) * glowk;
	}
}

void fragment() {
	vec2 px = floor(UV * vec2(960.0, 540.0));
	vec2 b = px - mod(px, 2.0) + 1.0;
	vec2 sp = b - off;
	vec2 u = sp / 430.0 + vec2(sd * 1.7, sd * 0.9);
	// STREAMING ON THE CURRENT (SIMPLIFIED's): the billows, the fine knots and the
	// kind's own noises, all read from the bake carried along the flow, so the
	// gas drifts and eddies as SIMPLIFIED's does (it used to churn in place)
	Fl F = flow_at(sp);
	vec4 B0 = texture(t1, F.p0), B1 = F.wb > 0.0 ? texture(t1, F.p1) : B0;
	vec4 K0 = texture(t0, F.p0), K1 = F.wb > 0.0 ? texture(t0, F.p1) : K0;
	float bil = hilo(B0.rg) * F.wa + hilo(B1.rg) * F.wb;
	float fine = keep(B0.b, B1.b, F);
	vec3 L = vec3(0.0);
	float dk = 0.0;
	// how much cloud there is here, for the weather to light
	float dens = 0.0;
	// THE WEATHER: is a slot live, and how far this block is from slot A's place
	bool wa = w_k > 0.0;
	bool wb = s_k > 0.0;
	vec2 wd = sp - w_at;
	float wr = length(wd);
	// THE SHIP'S GUARD: an event's light fades out round the ship (the cloud does not)
	float gk = sm(g_ship.z, g_ship.w, length(b - g_ship.xy));
	if (kind == 0) {
		// the young cluster that lights it, somewhere about the view
		vec2 cc = spot(1.0, vec2(-160.0, -120.0), vec2(1120.0, 660.0));
		vec2 dc = sp - cc;
		float r = length(dc) / 720.0;
		vec2 dir = dc / max(length(dc), 1.0);
		float body = sm(0.25, 0.75, bil + 0.2 * (1.0 - min(r, 1.4)));
		float core = exp(-r * r / 0.09) * (0.45 + 0.6 * fine);
		// pillars: dark fingers reaching in toward the cluster, and lanes
		float fing = keep(ridge(hilo(K0.rg), 7.0), ridge(hilo(K1.rg), 7.0), F);
		float pillar = fing * sm(0.24, 0.62, r) * sm(0.32, 0.62, bil);
		float lane = keep(ridge(hilo(K0.ba), 9.0), ridge(hilo(K1.ba), 9.0), F);
		dk = clamp(pillar * 1.25 + lane * 0.6 * body, 0.0, 0.9);
		// the pillars' tips facing the cluster, lit
		float tip = fing * exp(-pow((r - 0.27) / 0.06, 2.0)) * sm(0.32, 0.6, bil);
		// A NEW STAR (SP): its ionisation bubble clears the lane inside it
		bool ns = wa && w_ev == 3 && wr < w_size + 25.0;
		float bub = 0.0, nR = 0.0;
		if (ns) {
			bub = env(w_age - 1.5, 1.5, 11.0, 8.0) * w_k;
			nR = w_size * (1.0 - exp(-max(w_age - 1.5, 0.0) / 3.5));
			dk *= 1.0 - 0.7 * bub * sm(nR, 0.8 * nR, wr);
		}
		// THE TIDE: a teal front washing out from the cluster through the rose, and back
		float glow = body * (0.3 + 0.65 * fine) + core * 0.9;
		float tR = 0.0, te = 0.0, tband = 0.0;
		if (wa && w_ev == 1) {
			tR = 520.0 * (1.0 - pow(1.0 - clamp(w_age / 9.0, 0.0, 1.0), 2.0));
			te = env(w_age, 1.5, 6.5, 2.0) * w_k;
			// (only where the cloud is lit: a dim lane turned teal falls between the
			// palette's colours and dithers into blue checks)
			tband = exp(-pow((r * 720.0 - tR) / 60.0, 2.0)) * te * sm(0.55, 0.9, glow * (1.0 - dk));
		}
		vec3 col = mix(HA, O3, sm(0.05, 0.7, core + 0.55 * tband));
		L = col * glow * (1.0 - dk) + vec3(1.0, 0.72, 0.55) * tip * 1.4;
		if (wa && w_ev == 1) {
			// its thin brighter lip, just ahead of it
			// (14 px wide: at 8 it crossed a block in a few frames, early on two
			// blocks a frame, and the dither under it blipped along the front)
			L += O3 * glow * 0.15 * exp(-pow((r * 720.0 - tR - 40.0) / 14.0, 2.0)) * te;
		}
		// young stars glinting round the cluster, a block each
		if (r < 0.5) {
			bool gl = hash2(b * 0.5 + vec2(sd * 91.0, 3.0)) > 0.993;
			if (gl) L += STAR * 2.4 * (1.0 - r / 0.5);
			// GLINTS (S): one after another in a wave out from the middle, each a faint plus
			if (wb && s_ev == 1) {
				float tg = r * 720.0 / 90.0 + hash2(b * 0.5 + vec2(sd * 91.0, 7.0)) * 0.4;
				float g = sm(tg, tg + 0.1, s_age) * (1.0 - sm(tg + 0.25, tg + 0.65, s_age)) * s_k;
				if (gl) {
					L += STAR * 1.6 * g;
				} else if (g > 0.0) {
					float nb = 0.0;
					if (hash2((b + vec2(2.0, 0.0)) * 0.5 + vec2(sd * 91.0, 3.0)) > 0.993) nb = 1.0;
					if (hash2((b - vec2(2.0, 0.0)) * 0.5 + vec2(sd * 91.0, 3.0)) > 0.993) nb = 1.0;
					if (hash2((b + vec2(0.0, 2.0)) * 0.5 + vec2(sd * 91.0, 3.0)) > 0.993) nb = 1.0;
					if (hash2((b - vec2(0.0, 2.0)) * 0.5 + vec2(sd * 91.0, 3.0)) > 0.993) nb = 1.0;
					L += mix(STAR, O3, 0.5) * 0.45 * g * nb;
				}
			}
		}
		// A JET (Herbig-Haro): the pillar's tip warms, then two hair-thin threads
		// grow out sideways, each led by a knot with a little bow wave
		if (wa && w_ev == 2 && wr < 110.0) {
			float a = w_age;
			float warm = env(a, 2.0, 6.0, 3.0);
			L += vec3(1.0, 0.72, 0.55) * 1.8 * warm * exp(-wr * wr / 196.0) * w_k;
			float head = min(76.0, 9.0 * max(a - 2.0, 0.0));
			float across = wd.x * w_dir.y - wd.y * w_dir.x;
			for (int si = 0; si < 2; si++) {
				float sg = si == 0 ? 1.0 : -1.0;
				float along = sg * dot(wd, w_dir);
				if (along < -8.0) continue;
				float thread = exp(-pow(across / 1.5, 2.0)) * sm(2.0, 6.0, along) * (1.0 - sm(head - 2.0, head + 2.0, along)) * 0.32;
				float kn = 0.0;
				for (int i = 0; i < 3; i++) {
					float fi = float(i);
					float sii = min(76.0 - 12.0 * fi, 9.0 * max(a - 2.0 - 0.9 * fi, 0.0));
					kn += exp(-(pow(along - sii, 2.0) + across * across) / 9.0) * (i == 0 ? 1.6 : 0.7) * step(0.5, sii);
				}
				vec2 cq = vec2(along - (head - 4.0), across);
				float cr = length(cq);
				float cap = exp(-pow((cr - 6.0) / 1.5, 2.0)) * sm(0.2, 0.8, cq.x / max(cr, 1.0)) * step(4.0, head);
				L += (mix(HA, vec3(1.0, 0.55, 0.5), 0.5) * (thread + kn) + vec3(1.0, 0.86, 0.6) * cap * 1.2)
					* (1.0 - sm(10.0, 14.0, a)) * (1.0 - dk) * w_k * gk;
			}
		}
		// THE NEW STAR's light: teal near it, rose further out, a torn bright rim
		if (ns) {
			vec3 B = O3 * exp(-wr / 30.0) * 0.5
				+ HA * sm(0.4 * nR, nR, wr) * (1.0 - sm(nR, nR + 3.0, wr)) * (0.3 + body) * 0.6
				+ vec3(1.0, 0.85, 0.8) * exp(-pow((wr - nR - 12.0 * (fine - 0.5) - 8.0 * (bil - 0.5)) / 3.0, 2.0)) * (0.4 + body) * 0.8
					* sm(0.35, 0.65, fine + 0.35 * body);
			L += B * bub * gk;
			float st = env(w_age, 1.5, 16.5, 4.0) * w_k;
			if (wr < 1.5) L += STAR * 6.0 * st;
			else if (wr < 3.5 && min(abs(wd.x), abs(wd.y)) < 1.0) L += STAR * 1.8 * st;
		}
		dk *= 0.85;
		dens = body;
	} else if (kind == 1) {
		float haze = 0.1 + 0.6 * sm(0.2, 0.75, bil);
		// combed: faint striations all one way
		float stri = 0.65 + 0.55 * keep(K0.r, K1.r, F);
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
			bool me = wa && k == wk;
			// A SPOKE: the shadow of a clump near the star, swinging round it, its far
			// end lagging (light takes time to cross the cloud); it only darkens
			float mk = 1.0;
			if (me && w_ev == 1) {
				float an = atan(d.y, d.x), tha = w_seed * TAU + 0.06 * (w_age - r / 40.0);
				float spk = exp(-pow(adiff(an, tha) / 0.16, 2.0)) + 0.6 * exp(-pow(adiff(an, tha + 2.2) / 0.09, 2.0));
				mk = 1.0 - 0.85 * env(w_age, 4.0, 9.0, 5.0) * w_k * min(spk, 1.0) * sm(12.0, 40.0, r);
			}
			// BREATHING: a Cepheid's pulses rippling out through the haze
			float pk = 1.0, sk = 1.0;
			if (me && w_ev == 2) {
				float e = env(w_age, 4.0, 18.0, 6.0) * w_k;
				pk = 1.0 + 0.35 * e * pulse7(w_age - r / 15.0);
				sk = 1.0 + 0.5 * e * pulse7(w_age);
				sparks += mix(STAR, BLU, 0.3) * 0.9 * e * pulse7(w_age) * exp(-r * r / 196.0);
			}
			lit += exp(-r * r / (240.0 * 240.0)) * mk * pk;
			// SHAFTS of its light, turning slowly round it
			vec2 dir = d / max(r, 1.0);
			float rt = time * 0.012 * (k == 1 ? -1.0 : 1.0);
			vec2 dr = vec2(dir.x * cos(rt) - dir.y * sin(rt), dir.x * sin(rt) + dir.y * cos(rt));
			float ray = pow(fbm(dr * 3.2 + vec2(float(k) * 5.0, sd), 3), 3.0) * 2.4;
			shafts += ray * exp(-r / 280.0) * sm(14.0, 90.0, r) * mk;
			if (r < 3.0) {
				sparks += STAR * 3.4 * sk;
			} else if (r < 7.0) {
				sparks += STAR * 0.6 * sk;
			}
			// THE SHAFT: one shaft of the star nearest it, brightening as it sweeps
			// slowly through the haze, and gone; upgraded, the star swells first
			if (me && w_ev == 0) {
				if (w_up && r < 7.0) sparks += STAR * 1.0 * sm(-2.0, 0.0, w_age) * (1.0 - sm(8.0, 9.0, w_age)) * w_k;
				if (w_age < 9.0) {
					vec2 wa2 = w_at - st[k];
					float a0 = atan(wa2.y, wa2.x) + w_age * 0.035;
					vec2 bd = vec2(cos(a0), sin(a0));
					float along = dot(d, bd);
					float acr = abs(d.x * bd.y - d.y * bd.x);
					float en = sin(3.1416 * clamp(w_age / 9.0, 0.0, 1.0));
					float beam = exp(-pow(acr / (10.0 + max(along, 0.0) * 0.09), 2.0)) * sm(10.0, 60.0, along) * exp(-max(along, 0.0) / 520.0);
					wbeam += beam * en * en * w_k;
				}
			}
		}
		// THE ECHO (SP): a star flashes, then thin rings spread from it through
		// the dust, showing swirls and knots the haze hides
		vec3 echo = vec3(0.0);
		if (wa && w_ev == 3 && wk >= 0) {
			vec2 d = sp - st[wk];
			float r = length(d);
			if (r < 30.0) {
				float fl = 3.0 * exp(-max(w_age, 0.0) / 0.7) * step(0.0, w_age) + 0.8 * sm(-1.5, 0.0, w_age) * step(w_age, 0.0);
				sparks += mix(STAR, vec3(1.0, 0.7, 0.5), sm(0.3, 1.5, w_age)) * fl * (r < 7.0 ? 1.0 : 0.0) * w_k
					+ mix(STAR, vec3(1.0, 0.7, 0.5), sm(0.3, 1.5, w_age)) * 0.45 * fl * exp(-r * r / 144.0) * w_k;
			}
			float ring = 0.0;
			for (int i = 0; i < 2; i++) {
				float Ri = 16.0 * (w_age - (i == 0 ? 0.5 : 4.0));
				if (Ri > 0.0) ring += exp(-pow((r - Ri) / (6.0 + 0.02 * Ri), 2.0)) * (1.0 - sm(260.0, 360.0, Ri)) * (i == 0 ? 1.0 : 0.55);
			}
			if (ring > 0.01) {
				echo = mix(BLU, STAR, 0.6) * ring * haze * (0.4 + 1.6 * pow(fbm(u * 6.0 + vec2(sd, 3.0), 3), 2.0)) * w_k * 2.0 * gk
					* (1.0 - 0.55 * sm(0.4, 0.7, haze));
			}
		}
		L = BLU * haze * stri * (0.25 + 0.9 * min(lit, 1.5)) + mix(BLU, STAR, 0.4) * shafts * 0.38 * haze + sparks
			+ mix(BLU, STAR, 0.5) * wbeam * (0.35 + haze) * 1.1 * (w_up ? (0.75 + 0.45 * stri) * gk : 1.0) + echo;
		// GLITTER (S): single blocks along one striation catching the light in turn
		if (wb && s_ev == 1) {
			vec2 q = sp - s_at;
			float along = dot(q, vec2(-0.6, 0.8)), across = dot(q, vec2(0.8, 0.6));
			if (abs(across) < 5.0 && haze > 0.3 && hash2(b * 0.5 + vec2(sd * 7.0, 11.0)) > 0.84) {
				L += STAR * 2.4 * exp(-pow((along - 30.0 * s_age) / 10.0, 2.0)) * haze * env(s_age, 0.3, 3.7, 1.0) * s_k;
			}
		}
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
		float clump = 0.45 + 0.9 * pow(keep(K0.r, K1.r, F), 1.5);
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
		vec3 EL = vec3(0.0);
		// THE RING RUN: the star pulses, and a bead runs both ways round the rim
		// from the point nearest you, meeting on the far side with a flare
		if (wa && w_ev == 0) {
			float dth = adiff(atan(dd.y, dd.x), atan(w_dir.y, w_dir.x)), ph = 0.9 * max(w_age - 0.8, 0.0);
			float e = (1.0 - sm(6.0, 8.0, w_age)) * w_k;
			float bead = exp(-pow((dth - ph) / 0.18, 2.0)) * (1.0 - sm(3.0, 3.4, ph));
			float trail = exp(-max(ph - dth, 0.0) / 0.6) * step(dth, ph);
			float meet = exp(-pow((w_age - 4.3) / 0.5, 2.0)) * exp(-pow((PI - dth) / 0.3, 2.0));
			rim *= 1.0 + (1.6 * bead + 0.5 * trail + 1.5 * meet) * e * gk;
			band *= 1.0 + 0.8 * bead * e * gk;
			star *= 1.0 + 1.2 * env(w_age, 0.3, 0.0, 0.5) * w_k;
		}
		// FLIERS: paired knots riding out along the long axis, the rim (or the
		// ansae) flaring where they arrive
		if (wa && w_ev == 1) {
			float s = R0 * (0.15 + 0.97 * (1.0 - pow(1.0 - clamp(w_age / 6.0, 0.0, 1.0), 2.0)));
			float head = 0.0, thread = 0.0;
			for (int si = 0; si < 2; si++) {
				float side = si == 0 ? 1.0 : -1.0;
				vec2 v = dd - vec2(side * s, 0.0);
				head += exp(-dot(v, v) / 12.0) * (1.0 - sm(6.0, 9.0, w_age));
				thread += exp(-pow(dd.y / 1.2, 2.0)) * step(0.0, side * dd.x) * sm(0.15 * R0, 0.25 * R0, abs(dd.x)) * (1.0 - sm(s - 3.0, s, abs(dd.x)));
				vec2 rv = dd - vec2(side * R0, 0.0);
				rim *= 1.0 + 2.0 * exp(-pow((w_age - 6.0) / 1.2, 2.0)) * exp(-dot(rv, rv) / 625.0) * w_k;
			}
			if (shape == 3) knots *= 1.0 + 0.9 * env(w_age - 5.5, 0.5, 1.0, 4.0) * w_k;
			EL += (vec3(1.0, 0.5, 0.32) * 2.2 * head + mix(hue, HA, 0.5) * 0.15 * thread * (1.0 - sm(5.0, 10.0, w_age))) * w_k * gk;
		}
		// THE HALO: faint clumped rings drifting out past the rim
		if (wa && w_ev == 2) {
			float halo = 0.0;
			for (int i = 0; i < 2; i++) {
				float ai = w_age - 6.0 * float(i);
				if (ai > 0.0) halo += exp(-pow((rr - (1.06 + 0.012 * ai)) / 0.012, 2.0)) * clump * env(ai, 3.0, 9.0, 8.0) * (i == 0 ? 1.0 : 0.6);
			}
			EL += mix(hue, HA, 0.4) * 1.0 * halo * w_k * gk;
		}
		// SEARCHLIGHTS (SP): soft beams of starlight fanning out through the shell
		if (wa && w_ev == 3) {
			float an = atan(d.y, d.x);
			float bm = 0.0;
			for (int j = 0; j < 4; j++) {
				if (j >= w_n) break;
				float aj = w_seed * TAU + float(j) * (w_n == 2 ? PI : PI * 0.5) + 0.02 * w_age;
				bm += exp(-pow(adiff(an, aj) * r0 / (3.0 + 0.015 * r0), 2.0));
			}
			bm *= exp(-r0 / (2.2 * R0)) * sm(20.0, 60.0, r0);
			float e = env(w_age, 4.0, 6.0, 6.0) * w_k;
			rim *= 1.0 + 0.7 * bm * e;
			EL += mix(STAR, hue, 0.4) * bm * e * 1.5 * (0.3 + clump * min(ring + band + rim + 0.2, 0.9)) * gk;
		}
		// LAMPS (S): cometary knots along the rim lighting in turn, tails pointing out
		if (wb && s_ev == 1 && abs(rr - 0.97) < 0.08) {
			float ang = atan(dd.y, dd.x), a0 = atan(s_dir.y, s_dir.x);
			float bin0 = floor(ang / 0.05);
			float head = 0.0, tail = 0.0;
			for (int j = -1; j <= 1; j++) {
				float bin = bin0 + float(j);
				if (hash2(vec2(bin, sd * 9.0)) <= 0.6) continue;
				float ak = (bin + 0.5) * 0.05;
				float rk = (0.97 + 0.03 * hash2(vec2(bin, sd * 9.0 + 1.0))) * R0;
				float dk2 = adiff(ak, a0);
				float tk = dk2 / 0.25;
				float lt = sm(tk, tk + 0.6, s_age) * (1.0 - sm(5.0, 8.0, s_age)) * step(dk2, 0.75);
				if (lt <= 0.0) continue;
				vec2 kp = vec2(cos(ak), sin(ak)) * rk;
				vec2 v = dd - kp;
				vec2 rad = vec2(cos(ak), sin(ak));
				float along = dot(v, rad), across = cross2(v, rad);
				head += exp(-dot(v, v) / 9.0) * lt;
				tail += exp(-pow(across / 1.2, 2.0)) * sm(0.0, 2.0, along) * (1.0 - sm(6.0, 10.0, along)) * lt;
			}
			EL += (vec3(1.0, 0.55, 0.4) * 1.8 * head + hue * 0.6 * tail) * s_k;
		}
		L = vec3(1.0, 0.3, 0.28) * rim * 1.4 * clump + hue * (band * 0.95 + ring * 0.2) * clump
			+ hue * fill * (0.5 + 0.7 * bil) + mix(hue, HA, 0.5) * outer * (0.5 + fine)
			+ vec3(1.0, 0.55, 0.4) * knots * 1.6 + STAR * star + EL;
		// the bubble blown clear of the medium: what is behind it dimmed
		dk = 0.3 * (1.0 - sm(0.8, 1.0, rr));
		dens = max(ring, fill);
	} else if (kind == 3) {
		vec2 cc = spot(1.0, vec2(-300.0, -260.0), vec2(1260.0, 800.0));
		float r = length(sp - cc) / 760.0;
		float rag = r + (bil - 0.5) * 0.3;
		// thin tangled strands: the contours of two noises, each a line
		float fil = keep(ridge(hilo(K0.rg), 14.0), ridge(hilo(K1.rg), 14.0), F);
		float fil2 = keep(ridge(hilo(K0.ba), 16.0), ridge(hilo(K1.ba), 16.0), F);
		float shell = exp(-pow((rag - 0.85) / 0.14, 2.0));
		float inner = exp(-pow((rag - 0.72) / 0.12, 2.0));
		float amb = 0.3 + 0.4 * sm(0.4, 0.75, bil);
		L = HA * fil * (amb * 1.2 + 1.7 * shell) + O3 * fil2 * (amb * 0.6 + 1.5 * inner)
			+ mix(HA, O3, 0.5) * 0.06 * bil * (0.3 + shell + inner);
		dens = max(fil, fil2 * 0.8) * (0.4 + shell + inner);
		float fm = max(fil, fil2);
		// THE SHOCK: a front glimmering along the filaments as it passes; upgraded,
		// a teal glow where it will start, and the strands behind it cooling to red
		if (wa && w_ev == 0) {
			if (w_up) L += O3 * fil2 * 0.45 * exp(-pow((wr - 30.0) / 30.0, 2.0)) * sm(-1.5, 0.0, w_age) * step(w_age, 0.0) * w_k;
			float R = 30.0 + w_age * 75.0;
			float front = exp(-pow((wr - R) / 12.0, 2.0)) * sm(0.0, 0.6, w_age) * (1.0 - sm(3.5, 6.0, w_age));
			L += mix(vec3(1.0, 0.9, 0.95), O3, 0.6) * front * (0.08 + dens * 0.9) * w_k;
			if (w_up && w_age > 0.0) {
				float trail = sm(R - 60.0, R - 12.0, wr) * (1.0 - sm(R - 12.0, R, wr));
				L += mix(O3, HA, clamp((R - wr) / 60.0, 0.0, 1.0)) * trail * fm * 0.4 * (1.0 - sm(3.5, 6.0, w_age)) * w_k * gk;
			}
		}
		// A FLARE: one stretch of strand catches cold blue-white and burns down
		// through teal to red; a neighbour along it answers, weaker
		if (wa && w_ev == 1 && wr < 120.0) {
			float x = dot(wd, w_dir), y = wd.x * w_dir.y - wd.y * w_dir.x;
			float m1 = exp(-x * x / 900.0 - y * y / 100.0), m2 = exp(-pow((x - 50.0) / 25.0, 2.0) - y * y / 100.0);
			vec3 CB = vec3(0.75, 0.9, 1.0);
			vec3 c1 = mix(mix(CB, O3, sm(1.5, 3.0, w_age)), HA, sm(3.0, 5.5, w_age));
			vec3 c2 = mix(mix(CB, O3, sm(3.5, 5.0, w_age)), HA, sm(5.0, 7.5, w_age));
			L += (c1 * m1 * env(w_age, 1.0, 1.0, 4.0) + c2 * 0.5 * m2 * env(w_age - 2.0, 1.0, 1.0, 4.0)) * fm * 2.2 * w_k * gk;
		}
		// SHRAPNEL: bullets punching out through the shell, V-shaped wakes behind
		if (wa && w_ev == 2) {
			float e = env(w_age, 1.0, 9.0, 4.0) * w_k * gk;
			for (int j = 0; j < 6; j++) {
				if (j >= w_n) break;
				vec4 pt = w_pts[j];
				vec2 dj = vec2(cos(pt.z), sin(pt.z));
				vec2 v = sp - (pt.xy + dj * pt.w * w_age);
				float dist2 = dot(v, v);
				if (dist2 > 4900.0) continue;
				float x = -dot(v, dj), y = abs(cross2(v, dj));
				float head = exp(-dist2 / 6.0) * 2.4;
				float wake = exp(-pow((y - 0.35 * x) / 2.0, 2.0)) * sm(0.0, 4.0, x) * exp(-x / 25.0) * 0.7;
				// (faint: five of these summed to a pale smudge that hid the heads)
				float stir = fm * 0.12 * exp(-dist2 / 400.0);
				vec3 cj = hash2(vec2(float(j), w_seed * 100.0)) < 0.5 ? O3 : HA;
				L += cj * (head + wake + stir) * e;
			}
		}
		// PEARLS (SP): a faint tilted ring, eighteen beads lighting round it one by one
		if (wa && w_ev == 3 && wr < 70.0) {
			vec2 q = vec2(dot(wd, w_dir), -wd.x * w_dir.y + wd.y * w_dir.x);
			float e = length(vec2(q.x / 45.0, q.y / 31.5));
			L += mix(HA, hue, 0.3) * 0.15 * exp(-pow((e - 1.0) / 0.06, 2.0)) * env(w_age, 2.0, 12.0, 8.0) * w_k * gk;
			float j0 = floor(atan(q.y / 31.5, q.x / 45.0) / (TAU / 18.0) + 0.5);
			float bead = 0.0;
			for (int j = -1; j <= 1; j++) {
				float jj = mod(j0 + float(j), 18.0);
				float A = TAU * jj / 18.0 + (hash2(vec2(jj, w_seed * 50.0)) - 0.5) * 0.2;
				vec2 P = vec2(45.0 * cos(A), 31.5 * sin(A));
				float tj = 1.0 + 8.0 * hash2(vec2(jj, w_seed * 50.0 + 1.0));
				bead += exp(-dot(q - P, q - P) / 5.0) * sm(tj, tj + 0.6, w_age) * (1.0 - sm(14.0, 20.0, w_age));
			}
			L += mix(vec3(1.0, 0.5, 0.55), STAR, 0.3) * 1.8 * bead * w_k * gk;
		}
		// A SPARK (S, and the near spark): a point racing along the strands, seen
		// only where it crosses one, a faint red trail cooling behind it
		if (wb && s_ev == 1) {
			vec2 hp = s_at + s_dir * 40.0 * s_age;
			float e = env(s_age, 0.3, 2.7, 1.0) * s_k;
			L += mix(STAR, O3, 0.4) * exp(-dot(sp - hp, sp - hp) / 100.0) * fm * 2.4 * e;
			vec2 q = sp - s_at;
			float along = dot(q, s_dir), across = abs(cross2(q, s_dir)), behind = 40.0 * s_age - along;
			L += HA * exp(-pow(across / 3.0, 2.0)) * step(0.0, along) * step(0.0, behind) * exp(-behind / 30.0) * fil * 0.4 * e;
		}
	} else {
		float d = sm(0.3, 0.66, bil + 0.15 * (fine - 0.5));
		dk = d * 0.86;
		// its edge toward the light (from a side of the sky of its own), lit
		float la = hash2(vec2(sd, 31.0)) * 6.2832;
		vec2 ld = vec2(cos(la), sin(la));
		// (the billows a little toward the light, carried the same way: 0.05 in
		// noise is 15.36 sky px)
		vec2 lsh = ld * 15.36 / (2.0 * ftex);
		float bil2 = hilo(texture(t1, F.p0 - lsh).rg) * F.wa + (F.wb > 0.0 ? hilo(texture(t1, F.p1 - lsh).rg) * F.wb : 0.0);
		float face = sm(0.0, 0.012, bil - bil2);
		float rim = sm(0.05, 0.16, d) * (1.0 - sm(0.2, 0.38, d)) * face * sm(0.4, 0.72, fine);
		// DAWN (S): a bright stretch travelling along the lit rim
		if (wb && s_ev == 1) {
			rim *= 1.0 + 1.6 * exp(-pow((dot(sp - s_at, vec2(-ld.y, ld.x)) - (-120.0 + 35.0 * s_age)) / 40.0, 2.0)) * env(s_age, 1.0, 5.0, 1.5) * s_k;
		}
		L = vec3(1.0, 0.62, 0.42) * rim * 0.5 + vec3(0.3, 0.24, 0.42) * (1.0 - d) * sm(0.2, 0.5, bil) * 0.35;
		// RAYS: warm light streaming through the gaps from the lit side, each
		// clump casting a stripe of shadow behind it
		if (wa && w_ev == 1) {
			vec2 pl = vec2(-ld.y, ld.x);
			float rays = sm(0.42, 0.72, fbm(vec2(dot(sp, pl) * 0.02 + w_seed * 10.0 + 0.12 * w_age, 0.5), 3));
			float up = 0.0;
			for (int i = 1; i <= 3; i++) {
				up = max(up, sm(0.3, 0.66, fbm(u * 1.4 - ld * (30.0 * float(i)) * 1.4 / 430.0, 2)));
			}
			L += vec3(1.0, 0.62, 0.42) * rays * (1.0 - d) * (1.0 - up) * 0.5 * env(w_age, 3.0, 7.0, 4.0) * w_k * gk;
		}
		// THE FAN (SP): a buried star brightens, and a cone of amber opens out of the dust
		if (wa && w_ev == 2 && wr < 110.0) {
			float e = env(w_age, 4.0, 14.0, 8.0) * w_k;
			float Lf = 90.0 * (1.0 - pow(1.0 - clamp(w_age / 4.0, 0.0, 1.0), 2.0));
			// (brightest along its axis and fading to its sides, never a flat
			// wedge: with a flat top the palette cut it into a pale triangle with
			// ruled edges; and lit by the dust it falls on, so it is grainy)
			float ca = dot(wd / max(wr, 1.0), w_dir);
			float fan = exp(-pow(acos(clamp(ca, -1.0, 1.0)) / 0.28, 2.0)) * step(0.0, ca) * sm(Lf, Lf - 35.0, wr) * sm(2.0, 8.0, wr);
			dk *= 1.0 - 0.45 * fan * e;
			L += vec3(1.0, 0.66, 0.38) * fan * (0.3 + 0.7 * d) * (0.35 + 1.1 * fine * fine) * exp(-wr / 55.0) * e * 2.2 * gk;
			if (wr < 1.5) L += vec3(1.0, 0.5, 0.3) * 1.5 * e * (1.0 - 0.6 * dk);
		}
		// AN EMBER (S): a dull red point deep in the dust glowing up like a blown coal
		if (wb && s_ev == 2) {
			vec2 q = sp - s_at;
			float r2 = dot(q, q);
			if (r2 < 3600.0) {
				float x1 = max(s_age, 0.0), x2 = max(s_age - 1.6, 0.0);
				float f = (1.0 - exp(-x1 / 0.3)) * exp(-x1 / 0.8)
					+ (s_seed > 0.5 ? 0.5 * (1.0 - exp(-x2 / 0.3)) * exp(-x2 / 0.8) : 0.0);
				L += vec3(1.0, 0.45, 0.3) * f * (2.0 * exp(-r2 / 9.0) + 0.4 * exp(-r2 / 484.0)) * (1.0 - 0.5 * dk) * s_k;
			}
		}
		dens = d;
	}
	// THE GLOW OF THE CLOUD YOU ARE IN, faint, everywhere: no part of the sky
	// inside it is the black of open space
	L += (kind == 4 ? vec3(0.22, 0.17, 0.3) : hue) * (0.07 + 0.1 * bil) * (1.0 - dk);
	// THE STRIKE (emission and dark): a discharge deep in the cloud, a second, a
	// flicker, gone in under a second and a half -- upgraded, a soft double swell
	// before it, a teal afterglow after, and in a stormy system strikes walking
	// out from the cluster; in a dark cloud lit from behind, so the dust stands
	// out as black shapes with bright edges
	if (wa && w_ev == 0 && (kind == 0 || kind == 4)) {
		bool back = kind == 4 && w_up;
		vec3 lc = kind == 0 ? vec3(1.0, 0.82, 0.9) : vec3(0.82, 0.78, 1.0);
		float fp = 0.0, ch = 0.0, ag = 0.0, bk = 0.0;
		strike(sp, w_at, w_age, w_k, w_size, dens, back, w_dir, fp, ch, ag, bk);
		for (int i = 0; i < 6; i++) {
			if (i >= w_n) break;
			vec4 pt = w_pts[i];
			strike(sp, pt.xy, w_age - pt.z, w_k * pt.w, w_size * pow(0.85, float(i + 1)), dens, back, w_dir, fp, ch, ag, bk);
		}
		// the precursor: the patch swelling softly, twice
		if (w_up && w_age < 0.0 && wr < 2.6 * w_size) {
			float P = exp(-wr * wr / (w_size * w_size));
			float patch = back ? P * (pow(1.0 - dens, 2.0) * 1.2 + dens * (1.0 - dens) * 3.2) : P * (0.25 + dens);
			L += lc * 0.07 * w_k * patch * (0.5 - 0.5 * cos(TAU * (w_age + w_pre) / 1.2)) * sm(-w_pre, -w_pre + 0.6, w_age);
		}
		if (back) {
			L += lc * bk * (pow(1.0 - dens, 2.0) * 1.6 + dens * (1.0 - dens) * 3.2) + lc * ch * 1.4
				+ mix(lc, vec3(0.5, 0.4, 0.85), 0.5) * ag * (pow(1.0 - dens, 2.0) * 1.2 + dens * (1.0 - dens) * 3.2);
		} else {
			fp = min(fp, 0.25 + dens);
			L += lc * (fp * 0.6 + ch * 1.4) + mix(lc, O3, 0.5) * ag;
			// the lit dust no longer hides the patch
			dk *= 1.0 - min(1.0, fp * 0.8);
		}
	}
	L *= strength;
	vec3 c = vec3(1.0) - exp(-L * expo);
	COLOR = vec4(c, clamp(dk * strength, 0.0, 0.95));
}
