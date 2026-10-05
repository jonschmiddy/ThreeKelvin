shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE GALAXY, ONE 2x2 BLOCK A FRAGMENT (`ChartSky`, Jon's pick of the mockup:
// round three, 2x2, at the sector map's angle). Drawn into a half-size
// viewport that the chart shows at twice its size, so every fragment here is
// one block of the picture.
//
// Each block is worked out afresh every frame, so nothing is ever stretched
// and nothing is ever rebuilt: the zoom redraws, the galaxy turns and the gas
// breathes in the same pass, with no seam between one build and the next.
//   * WHERE IT IS IN THE GALAXY. The block is taken into the disc's plane,
//     turned back by the galaxy's angle (`phi`, one turn every half hour, the
//     whole disc rigidly), and out again; inside the innermost ring the turn
//     climbs toward the hole (`wk`), on two copies that restart in turn and
//     cross-fade (a flow map), so it turns fast without winding up.
//   * WHAT IS THERE: the baked light of the stars (`sl_tex`), the arms and the
//     dark clouds (`aux_tex`) and the clouds' gas (`gc_tex`), and, worked out
//     here at this zoom's own scale, the gas's wisps and knots and deep in,
//     the star clouds with dark gaps between them; the dust lanes on the
//     inner edge of each arm and the bulge's filaments come baked and spread
//     (`dust_tex`), so they read as dust at every zoom, never as cracks.
//   * THE DUST HAS VOLUME ("kinda flat", Jon): its thickness billows; it is
//     lit from the core, so its core-facing edge glows and it throws a faint
//     shadow away from the core and down the screen onto what lies behind;
//     the near side of the disc (low on the screen) is thicker and sharper,
//     the far side thinner and softer; and bright stars show through where
//     it is thin.
//   * THE NAMED CLOUDS ARE OBJECTS (`neb_a` / `neb_b`, one entry a lobe, laid
//     out as the bake lays their gas): an emission nebula a glowing knot with
//     a bright rim, a reflection nebula a soft haze, a remnant a shell of
//     filaments, a planetary a small bright ring round its star; each with a
//     faint edge, in its own colour, brighter than the arms' gas, with the
//     dust held off it, and breathing slowly while it is within your sensors.
//   * WHAT IS THE SCREEN'S, NOT THE GALAXY'S: the bulge's glow (a ball, round
//     about the hole however the disc has turned), which half of it is in
//     front, the hole's light on the gas, and the gas swirling round the hole
//     in the hole's own plane.
//   * Then the light is toned to the screen, and the three depths of the sky
//     behind and, deep in, the extra stars are let through where they are
//     brighter than the galaxy in front of them.
// Out: the screen colour, and in alpha what the passes after this need to
// know -- 1 a block of the field (dithered by the palette), 0.5 a point (set
// to its nearest colour), and 0.75 / 0.25 the same on the near side of the
// swirl, which the lens must leave alone.

#include "res://shaders/chart_galaxy.gdshaderinc"

uniform sampler2D sl_tex : filter_linear, repeat_disable;
uniform sampler2D aux_tex : filter_linear, repeat_disable;
uniform sampler2D gc_tex : filter_linear, repeat_disable;
// the dust lanes (R) and the bulge's filaments (G), baked and spread
uniform sampler2D dust_tex : filter_linear, repeat_disable;
uniform vec2 bake_size = vec2(896.0, 616.0);
uniform vec2 bake_origin = vec2(448.0, 308.0);

uniform vec2 vp_size = vec2(330.0, 220.0);
uniform vec2 vp_origin = vec2(-2.0, -2.0);
uniform vec2 cpix = vec2(327.0, 217.0);
uniform float z = 1.0;
uniform float zf = 1.0;
uniform float phi = 0.0;
uniform float t = 0.0;

uniform float eff = 0.38;
uniform float bsq = 0.86;
uniform float dk_g = 1.0;
uniform float bul = 10.0;
uniform float arm_k = 1.0;
uniform float sd = 0.0;
uniform float big_r = 261.0;
uniform float gas = 1.0;
uniform float lane_amt = 0.0;
uniform float nuc_amt = 0.0;
uniform vec3 pal0 = vec3(0.36, 0.52, 0.95);
uniform vec3 pal1 = vec3(0.95, 0.36, 0.55);
uniform float rin_p = 10.0;
uniform float rb = 30.0;
// the innermost ring's reach: how far out the gas round the hole goes
uniform float rb_ring = 30.0;
uniform float rh = 10.0;
// the zoom's own constants (`ChartSky._level`)
uniform float oct = 0.0;
uniform float det_k = 0.0;
uniform float zoom_dim = 0.0;
uniform float resolved = 1.0;
uniform float dz = 0.0;
uniform float res2 = 1.0;
uniform float te_b = 1.0;
// the named clouds, a lobe each: centre (bake pixels, the galaxy's frame),
// radius (where the chart's outline is), kind; colour and how flat it lies;
// and how much it breathes, for the ones within your sensors
uniform vec4 neb_a[32];
uniform vec4 neb_b[32];
uniform float neb_glow[32];
uniform int neb_n = 0;
// how the named clouds are drawn, while Jon picks (`ChartSky.nebula_look`):
// 0 as shipped, 1 "of the galaxy", 2 "pixel-art objects", 3 "quiet until
// wanted"; and for 3, how wanted each lobe's cloud is (hovered, in sensors)
uniform int neb_style = 0;
uniform float neb_want[32];
// the swirl
uniform float swirl_amp = 0.0;
uniform vec4 clumps[6];
uniform vec3 sw_gas = vec3(0.9, 0.5, 0.4);
// the extra stars deep in: their density, the zoom their grid is at, and its index
uniform float filler_k = 0.0;
// STARS ALL THE WAY IN ("can you have stars going to the black hole ... so
// there is no gap", Jon): within this many screen pixels of the hole (its
// disc and glow) a star is drawn whether or not it outshines the light under
// it, so the bulge's stars carry on in to the shadow at the bulge's own
// density; the hole dims them where its light is brightest (`chart_hole`)
uniform float near_r = 0.0;
// DEPTH, while Jon picks ("I almost want the sectors and galaxies to look
// fluffy and deep", `ChartSky.depth_look`): 0 as it is; 1 layers you pass
// through -- sparse wisps at depths between you and the galaxy, nearer ones
// growing faster as you zoom and sliding faster as you pan, each fading out as
// it passes you and new ones fading in behind; 2 fluffy -- the gas lit as
// billowing cloud, its sides toward the core lit and the far sides in shadow,
// its thick cores darker and its edges glowing; 3 both, as strong as
// `depth_amt` (0 none, 1 both in full)
uniform int depth_look = 0;
uniform float depth_amt = 0.6;
// THE DISC AS A VOLUME, while Jon picks ("I want the actual arms of the
// galaxy and the galaxy itself to have a height ... the clouds of the arms to
// have depth themselves", `ChartSky.volume_look`): how tall its clouds pile
// up, in bake pixels (0: flat, as it was)
uniform float vol_h = 0.0;
// AND AS GAS, while Jon picks ("these look almost like physical mountains. I
// like the puffiness, but they're too solid?", `ChartSky.gas_look`): how
// dense the cloud is along a ray -- 0 the solid first-hit surface; more,
// the cloud as a volume of gas, more opaque the denser
uniform float gas_k = 0.0;
// THE GAS CHURNING ("have the new volumetric clouds billow slightly and
// move", Jon): seconds on the gas's own slow clock, held at 0 when still
// (`ChartSky.gas_billow` off, or reduced motion)
uniform float gas_t = 0.0;
// the globular clusters' centres (`ChartSky`, as the stars shader has them),
// drawn as glows when `cluster_look` is 1
uniform vec2 glob_c[32];
uniform int n_glob = 0;
uniform int cluster_look = 0;
// the middle of the chart, in its pixels (the camera looks down through it)
uniform vec2 view_c = vec2(327.0, 217.0);
// how far out the hole's disc reaches, in hole radii (`ChartSky.DISC_K`)
uniform float disc_k = 4.0;
// where YOU is, in screen pixels from the galaxy's centre, and how far round
// it the dust stands back (0: nowhere)
uniform vec2 you_rel = vec2(1e6);
uniform float you_r = 0.0;
// how many stars (`ChartSky.star_level`): the dimmest go first
uniform int star_level = 1;
// the sky behind
uniform vec2 sky_pan = vec2(0.0);
uniform int sky_seed = 0;
// a palette probe: the level's window round the centre, field only
uniform bool probe = false;

const vec3 CORE_C = vec3(1.0, 0.6, 0.26);
const vec3 SW_HOT = vec3(1.0, 0.52, 0.18);

float o3() { return 3.0 + oct; }
float o4() { return 4.0 + oct; }
float o5() { return 5.0 + oct; }

vec4 sb4(sampler2D tx, vec2 p) {
	vec2 x = p + bake_origin;
	if (x.x < 0.0 || x.y < 0.0 || x.x > bake_size.x - 1.001 || x.y > bake_size.y - 1.001) {
		return vec4(0.0);
	}
	return texture(tx, (x + 0.5) / bake_size);
}

vec3 sbb(vec2 p) {
	vec2 bs = floor((bake_size + 1.0) * 0.5);
	vec2 x = (p + bake_origin) * 0.5 - 0.25;
	if (x.x < 0.0 || x.y < 0.0 || x.x > bs.x - 1.001 || x.y > bs.y - 1.001) {
		return vec3(0.0);
	}
	return texture(gc_tex, (x + 0.5) / bs).rgb;
}

float wk(float r) {
	if (r >= rb) {
		return 0.0;
	}
	// (at 0.4 of the disc's own law: "have the stars around the black hole
	// move a bit slower", Jon -- the disc keeps its spin, what is round it calms)
	return 0.4 * 1.1 * pow(max(r, rin_p) / rin_p, -1.5) * (1.0 - g_sm(0.5 * rb, rb, r));
}

float wrap_pi(float d) {
	return mod(d + PI, TAU_G) - PI;
}

// How much a cloud in your sensors breathes now.
float neb_pulse(int i) {
	return 1.0 + neb_glow[i] * (0.5 + 0.5 * sin(t * 1.1 + float(i) * 1.7));
}

// The named clouds' light at p, how much they hold the dust off, and the
// thin dim moat just outside each, which sets it apart from the arm behind.
// THE NAMED CLOUDS, MAGNIFICENT ("redo the nebulas ... make them magnificent
// and like actually as vibrant as they are", Jon): each kind drawn as the
// thing itself, in its own light, in the cloud's own frame (`q`, 1 at its
// outline), churning with the gas (`gas_t`):
//   EMISSION, as Orion and the Eagle: rose-red hydrogen glow billowing round
//     a teal oxygen core where its young stars burn, dark dust lanes and
//     pillars reaching in from its edge with their tips lit by those stars;
//   REFLECTION, as the Pleiades: blue haze round the few bright stars that
//     light it, combed into faint striations;
//   PLANETARY, as the Ring, the Cat's Eye and the Dumbbell: a crisp ring (or
//     an hourglass, or a ring with a knot either side) red at its rim and teal
//     inside, round a hot white star;
//   REMNANT, as the Veil and the Crab: a shell of tangled filaments, red
//     outside and teal just within, the middle faint;
//   DARK, as the Horsehead: dust that hides what is behind it, its edge
//     facing the galaxy's core lit.
// Colours as they are, bright; the field's tone map keeps them off white.
void neb_v2(int i, int kind, int shp, vec2 o, vec4 a, vec4 b,
		inout vec3 light, inout float hold, inout float moat, inout float hollow, inout float ndark,
		inout float clr) {
	vec2 q = vec2(o.x, o.y / b.w) / a.z;
	float r = length(q);
	if (r > 1.3) {
		return;
	}
	float ang = atan(q.y, q.x);
	float sdk = float(i) * 7.13 + 3.0;
	// a screen pixel, in the cloud's own units (stars are a block)
	float pxq = 1.0 / max(a.z * z, 1e-3);
	vec2 cw = gas_t > 0.0 ? vec2(sin(gas_t * 0.11 + sdk), cos(gas_t * 0.09 + sdk * 1.3)) * 0.12 : vec2(0.0);
	float bil = g_fbm(q * 2.2 + cw + vec2(sdk, 3.0), 4.0);
	float fine = g_fbm(q * 6.5 + cw * 2.0 + vec2(5.0, sdk), 3.0);
	float pls = neb_pulse(i);
	vec3 HA = vec3(1.0, 0.2, 0.3);
	vec3 O3 = vec3(0.2, 0.95, 0.85);
	if (kind == 0) {
		float body = pow(max(0.0, 1.0 - r * r), 1.1) * g_sm(0.2, 0.7, bil + 0.3 * (1.0 - r));
		float core = exp(-r * r / 0.1) * (0.5 + 0.7 * fine);
		// pillars: dark fingers from the edge toward the middle, and lanes
		float fing = pow(1.0 - abs(2.0 * g_noise(vec2(ang * 2.6 + sdk, r * 1.2 + cw.x)) - 1.0), 7.0);
		float pillar = fing * g_sm(0.3, 0.85, r) * g_sm(0.35, 0.65, bil);
		float lane = pow(1.0 - abs(2.0 * g_fbm(q * 2.6 + vec2(sdk, 11.0) + cw, 3.0) - 1.0), 9.0);
		float dk = clamp(pillar * 1.3 + lane * 0.7 * body, 0.0, 0.92);
		// the pillars' tips facing the young stars, lit
		float tip = fing * exp(-pow((r - 0.3) / 0.07, 2.0)) * g_sm(0.35, 0.6, bil);
		vec3 col = mix(HA, O3, g_sm(0.05, 0.7, core));
		float glow = body * (0.55 + 0.9 * fine) + core * 1.1;
		vec2 cl = floor(q / (pxq * 2.0));
		float ys = (r < 0.45 && g_hash(int(cl.x) + i * 31, int(cl.y) + 7) > 0.975) ? 2.4 * (1.0 - r / 0.45) : 0.0;
		light += (col * glow * (1.0 - dk) + vec3(1.0, 0.72, 0.55) * tip * 1.4 + vec3(0.85, 0.93, 1.0) * ys) * pls;
		hold = max(hold, body);
		ndark = max(ndark, dk * (1.0 - g_sm(0.7, 1.1, r)));
	} else if (kind == 1) {
		float haze = pow(max(0.0, 1.0 - r), 1.3) * (0.3 + 0.9 * bil);
		// combed: faint striations all one way
		float stri = 0.65 + 0.55 * g_noise(vec2(dot(q, vec2(0.8, 0.6)) * 16.0, dot(q, vec2(-0.6, 0.8)) * 2.0) + vec2(sdk, 0.0) + cw);
		float sl = 0.0;
		float spark = 0.0;
		for (int k = 0; k < 5; k++) {
			vec2 sp = (vec2(g_hash(i * 13 + k, 5), g_hash(i * 17 + k, 9)) - 0.5) * 0.95;
			float d = length(q - sp);
			sl += exp(-d * d / 0.025);
			spark = max(spark, d < pxq * 1.6 ? 1.0 : 0.0);
		}
		vec3 blu = vec3(0.32, 0.52, 1.0);
		light += (blu * haze * stri * (0.35 + 0.55 * min(sl, 1.6)) + vec3(0.85, 0.93, 1.0) * spark * 3.2) * pls;
		hold = max(hold, haze);
	} else if (kind == 2) {
		// A BUBBLE BLOWN IN THE MEDIUM ("shouldn't a planetary nebula be a bit
		// more empty?", Jon): a crisp ring just inside its outline, brighter
		// than the gas round it, sharp on its outer edge; inside it the arm's
		// gas and dust are cleared away, faint teal only, and the hot star in
		// the middle a single bright block with a faint glow. Its own axis and
		// shape: ring, tipped ring, hourglass, or ring with a knot either side.
		float aa = g_hash(i, 77) * 3.1416;
		vec2 qq = vec2(q.x * cos(aa) - q.y * sin(aa), q.x * sin(aa) + q.y * cos(aa)) * 0.61;
		if (shp == 1) {
			qq.y *= 1.6;
		}
		float rr = length(qq);
		float dr = rr - 0.5 + (fine - 0.5) * 0.03;
		float ring = exp(-pow(dr / (dr < 0.0 ? 0.08 : 0.028), 2.0));
		float fill = (1.0 - g_sm(0.2, 0.48, rr)) * 0.12;
		if (shp == 2) {
			// an hourglass: two lobes out along the axis, a bright waist
			float lob = length(vec2(qq.x * 1.7, abs(qq.y) - 0.3));
			float dl = lob - 0.24;
			ring = exp(-pow(dl / (dl < 0.0 ? 0.06 : 0.025), 2.0))
				+ exp(-pow(length(vec2(qq.x / 0.26, qq.y / 0.08)) - 1.0, 2.0) / 0.05) * 0.8;
			fill = (1.0 - g_sm(0.1, 0.24, lob)) * 0.1;
			rr = max(rr, lob + 0.26);
		}
		float knots = 0.0;
		if (shp == 3) {
			vec2 k1 = qq - vec2(0.57, 0.0);
			vec2 k2 = qq + vec2(0.57, 0.0);
			knots = exp(-dot(k1, k1) / 0.003) + exp(-dot(k2, k2) / 0.003);
		}
		float star = r < pxq * 1.05 ? 4.0 : exp(-pow(r / (pxq * 3.0), 2.0)) * 0.6;
		light += (vec3(1.0, 0.32, 0.3) * ring * (1.3 + 0.5 * fine) + O3 * fill * (0.6 + 0.5 * bil)
			+ vec3(1.0, 0.55, 0.4) * knots * 1.6 + vec3(0.85, 0.95, 1.0) * star) * pls;
		hold = max(hold, ring * 0.9);
		hollow = max(hollow, 1.0 - g_sm(0.9, 1.15, r));
		clr = max(clr, 0.92 * (1.0 - g_sm(0.45, 0.56, rr)));
	} else if (kind == 3) {
		float rag = r + (bil - 0.5) * 0.2;
		float fil = pow(1.0 - abs(2.0 * g_fbm(q * 5.0 + vec2(sdk, 2.0) + cw, 4.0) - 1.0), 5.0);
		float shell = exp(-pow((rag - 0.8) / 0.11, 2.0));
		float inner = exp(-pow((rag - 0.7) / 0.09, 2.0));
		float mid = (1.0 - g_sm(0.0, 0.75, r)) * pow(fil, 2.0) * 0.07;
		light += (HA * shell * (0.25 + 1.7 * fil) + O3 * inner * (0.15 + 1.3 * fil) * 0.85
			+ mix(HA, O3, 0.5) * mid) * pls;
		hold = max(hold, shell * 0.8);
		hollow = max(hollow, 1.0 - g_sm(0.95, 1.3, r));
		clr = max(clr, 0.45 * (1.0 - g_sm(0.6, 0.85, r)));
	} else if (kind == 4) {
		float dens = pow(max(0.0, 1.0 - r * r), 0.8) * g_sm(0.3, 0.65, bil + 0.2 * (1.0 - r));
		ndark = max(ndark, dens * 0.92);
		moat = max(moat, dens);
		// its edge toward the core, lit
		vec2 toc = -normalize(a.xy + vec2(1e-3));
		float face = dot(normalize(q + vec2(1e-4)), normalize(vec2(toc.x, toc.y / b.w)));
		// (a thin edge only: wider, the dust read as glowing gas)
		float rim = g_sm(0.06, 0.16, dens) * (1.0 - g_sm(0.18, 0.34, dens)) * g_sm(0.2, 0.85, face)
			* g_sm(0.45, 0.75, fine);
		light += vec3(1.0, 0.62, 0.42) * rim * 0.28 * pls;
	}
}

void nebulae(vec2 p, out vec3 light, out float hold, out float moat, out float hollow, out float ndark,
		out float nclear) {
	nclear = 0.0;
	light = vec3(0.0);
	hold = 0.0;
	moat = 0.0;
	hollow = 0.0;
	ndark = 0.0;
	for (int i = 0; i < 32; i++) {
		if (i >= neb_n) {
			break;
		}
		vec4 a = neb_a[i];
		vec4 b = neb_b[i];
		vec2 o = p - a.xy;
		float dn = length(vec2(o.x, o.y / b.w)) / a.z;
		if (dn > 1.4) {
			continue;
		}
		// the kind, and (a planetary's) its shape: kind + 8 x shape
		int kw = int(a.w + 0.5);
		int kind = kw & 7;
		int shp = kw >> 3;
		// (the dark clouds are in the list only for the new look)
		if (kind == 4 && neb_style != 4) {
			continue;
		}
		float body = pow(max(0.0, 1.0 - dn * dn), 1.5);
		float n1 = g_fbm(p * 0.07 + vec2(float(i) * 7.3, 3.1), 3.0);
		float fil = 0.0;
		if (kind == 3) {
			fil = pow(1.0 - abs(2.0 * g_fbm(p * 0.13 + vec2(float(i) * 5.1, 9.0), 4.0) - 1.0), 4.0);
		}
		// each kind's own shape, as shipped
		float v = 0.0;
		if (kind == 0) {
			float knot = exp(-pow(dn / 0.38, 2.0));
			float rim = exp(-pow((dn - 0.82) / 0.12, 2.0));
			v = body * (0.35 + 0.7 * n1) + knot * 0.9 + rim * 0.45;
		} else if (kind == 1) {
			v = body * (0.45 + 0.6 * n1) * 0.7 + exp(-pow(dn / 0.45, 2.0)) * 0.25;
		} else if (kind == 3) {
			float shell = exp(-pow((dn - 0.78) / 0.13, 2.0));
			v = shell * (0.35 + 1.5 * fil) + body * fil * 0.18;
		} else if (kind == 2) {
			float ring = exp(-pow((dn - 0.58) / 0.11, 2.0));
			v = ring * (1.05 + 0.4 * n1) + exp(-pow(dn / 0.09, 2.0)) * 1.4 + body * 0.12;
		}
		vec3 c = b.rgb;
		if (neb_style == 4) {
			neb_v2(i, kind, shp, o, a, b, light, hold, moat, hollow, ndark, nclear);
		} else if (neb_style == 1) {
			// A, OF THE GALAXY: no edge, no moat. Brighter coloured gas that
			// billows out into the arm round it, with pink star-forming knots
			// and a few bright young stars inside.
			float soft = pow(max(0.0, 1.0 - dn * dn * 0.55), 2.0);
			float bil = g_fbm(p * 0.06 + vec2(float(i) * 3.7, 1.9), 4.0);
			if (kind == 3 || kind == 2) {
				// A SHELL, NOT A BLOB ("totally blown out ... I don't even know
				// what that is"): a remnant is a thin, ragged, limb-brightened
				// edge with filaments, its middle dim and see-through; a
				// planetary a small tidy ring round its star. Its own hues,
				// the filaments warmer, well below white.
				float rad = kind == 3 ? 0.8 : 0.6;
				float rag = dn + (bil - 0.5) * (kind == 3 ? 0.16 : 0.06);
				float w = kind == 3 ? 0.07 : 0.06;
				float edge = exp(-pow((rag - rad) / w, 2.0));
				float limb = exp(-pow((rag - rad + w * 1.6) / (w * 2.2), 2.0)) * 0.35;
				float inside = (1.0 - g_sm(rad - 0.15, rad, dn)) * 0.06;
				float vv = edge * (kind == 3 ? 0.35 + 1.1 * fil : 1.0) + limb + inside * (0.5 + fil);
				vec3 col = kind == 3 ? mix(c, vec3(1.0, 0.45, 0.6), fil * 0.45) : c;
				float star = kind == 2 ? exp(-pow(dn / 0.07, 2.0)) * 1.2 : 0.0;
				light += (col * vv * 0.75 + vec3(0.85, 0.95, 1.0) * star) * neb_pulse(i);
				hold = max(hold, edge * 0.8);
				// the bake's filled oval of it goes, out past the shell: the
				// shell is drawn here, and its middle shows what lies behind
				hollow = max(hollow, 1.0 - g_sm(rad + 0.15, rad + 0.5, dn));
			} else if (kind == 1) {
				// A REFLECTION IS A HAZE, NOT A PLATE (it filled the screen
				// a flat pale blue at zoom 4): starlight scattered off dust,
				// so it is dim, wispy and brightest round the star that
				// lights it, with no star-forming knots of its own.
				float wisp = pow(1.0 - abs(2.0 * g_fbm(p * 0.11 + vec2(float(i) * 4.1, 2.0), 4.0) - 1.0), 3.0);
				float near_star = exp(-pow(dn / 0.35, 2.0));
				float vv = soft * (0.04 + 0.45 * g_sm(0.4, 0.8, bil) * (0.3 + 0.7 * wisp)) + near_star * 0.3;
				float star = exp(-pow(dn / 0.05, 2.0)) * 1.1;
				light += (c * vv + vec3(0.85, 0.92, 1.0) * star) * neb_pulse(i);
				hold = max(hold, soft * 0.5);
				// and the bake's filled oval of its gas thinned the same way
				hollow = max(hollow, soft * (0.75 - 0.45 * wisp));
			} else {
				float vv = soft * (0.08 + 1.5 * g_sm(0.4, 0.78, bil));
				float knots = g_sm(0.62, 0.82, g_fbm(p * 0.16 + vec2(float(i) * 2.3, 7.0), 3.0)) * soft;
				vec3 pink = vec3(1.0, 0.42, 0.62) * 1.4;
				// and a few bright young stars born in it
				vec2 cell = floor(p * 0.8);
				float young = g_hash(int(cell.x) + i * 131, int(cell.y) * 7 + 11) > 0.985 ? soft * 3.0 : 0.0;
				light += (c * vv + pink * knots * (kind == 0 ? 0.9 : 0.45) + vec3(0.8, 0.9, 1.0) * young) * neb_pulse(i);
				hold = max(hold, soft * 0.7);
			}
		} else if (neb_style == 2) {
			// B, PIXEL-ART OBJECTS: the cloud in bands of colour stepping from
			// a deep rim to a bright core, a crisp lit rim on the side facing
			// the galaxy's core, tidy shells and rings; no stroke, no moat.
			float lvl = kind == 3 ? g_sm(0.25, 0.7, exp(-pow((dn - 0.78) / 0.12, 2.0)) * (0.4 + 1.2 * fil))
				: (kind == 2 ? g_sm(0.3, 0.8, exp(-pow((dn - 0.58) / 0.09, 2.0)))
				: body * (0.75 + 0.35 * n1));
			float band = floor(clamp(lvl, 0.0, 0.999) * 4.0) / 3.0;
			vec3 deep = c * vec3(0.55, 0.45, 0.65);
			vec3 core = mix(c, vec3(1.0), 0.45);
			vec3 col = band < 0.5 ? mix(deep, c, band * 2.0) : mix(c, core, band * 2.0 - 1.0);
			float on = lvl > 0.06 ? 1.0 : 0.0;
			vec2 toc = -normalize(a.xy + vec2(1e-3));
			float face = dot(normalize(vec2(o.x, o.y / b.w) + vec2(1e-4)), toc);
			float rim = (dn > 0.84 && dn < 1.0 && face > 0.35 && kind < 2) ? 1.0 : 0.0;
			light += (col * on * (0.6 + 0.6 * band) + core * rim * 0.9) * neb_pulse(i);
			hold = max(hold, on * 0.9);
		} else if (neb_style == 3) {
			// C, QUIET UNTIL WANTED: at rest a gentle tint of the gas; pointed
			// at, or within your sensors, it brightens and shows its shape.
			float w = neb_want[i];
			light += c * (body * 0.18 * (1.0 - w) + v * w);
			hold = max(hold, body * (0.3 + 0.6 * w));
		} else {
			// as shipped: each kind's shape, a faint edge and a dim moat
			v += 0.16 * exp(-pow((dn - 1.0) / 0.07, 2.0));
			light += c * v * neb_pulse(i);
			hold = max(hold, body);
			moat = max(moat, exp(-pow((dn - 1.16) / 0.11, 2.0)));
		}
	}
	moat *= 1.0 - hold;
}

// THE RIM, SOFT ("for some of the galaxies, we could have them more diffuse
// at the edges? They kind of hard stop", Jon): how much of the galaxy is left
// at a point of the plane (`pl`, bake pixels, unsquashed) -- all of it inside
// three quarters of the disc, thinning to none just past its rim along a
// ragged line, two scales of noise pushing it in and out so no ellipse shows.
float rim_fade(vec2 pl) {
	float rn = length(pl) / big_r;
	if (rn < 1.5) {
		return 1.0;
	}
	float en = g_fbm(pl * 0.012 + vec2(sd * 0.7, 3.0), 3.0);
	float en2 = g_noise(pl * 0.045 + vec2(9.0, sd));
	return 1.0 - g_sm(1.7, 2.3, rn + (en - 0.5) * 0.3 + (en2 - 0.5) * 0.1);
}

// Everything the galaxy carries at a point of its own frame (bake pixels):
// the disc's light dimmed by its dust, the bulge's light, the dust, the gas.
void gal_fields(vec2 p, vec2 down_p, float nearf, float youk, float smth, out vec3 o_dd, out vec3 o_bs, out float o_kd, out vec3 o_gg) {
	vec4 slv = sb4(sl_tex, p);
	vec4 aux = sb4(aux_tex, p);
	vec3 gcl_c = sbb(p);
	float a = aux.r, rg = aux.g, cd = aux.b;
	float lx = p.x, ly = p.y / eff;
	float dd = length(vec2(lx, ly)), near = exp(-dd / (bul * 1.1));
	// the named clouds: where their own gas is, the dust stands back
	float gl = g_lum(gcl_c);
	float neb = g_sm(0.04, 0.35, gl);
	vec3 arm_gas = vec3(0.0);
	vec3 neb_gas = vec3(0.0);
	// FLUFFY (`depth_look` 2 and 3): the disc's light and gas as billowing
	// cloud lit from the core -- its height a slow noise; a slope that falls
	// toward the core faces it and is lit, one that rises toward it is in its
	// own shadow; the thickest parts darker, their edges glowing
	float fluff = 1.0;
	if (depth_look >= 2) {
		// only on the galaxy's dense parts -- its arms and its bulge -- and the
		// more, the denser ("tied to the dense parts of the galaxy, not all
		// over", Jon): puffy arms, lit on top, shadowed beneath
		float dw = g_sm(0.12, 0.5, max(aux.r, slv.a * 0.9));
		float kb = (depth_look == 2 ? 1.0 : depth_amt) * dw;
		vec2 lp = vec2(lx, ly);
		vec2 dirc = -lp / max(length(lp), 1e-3);
		float t0 = g_fbm(lp * 0.035 + vec2(21.0, sd), 4.0);
		float t1 = g_fbm((lp + dirc * 2.0) * 0.035 + vec2(21.0, sd), 4.0);
		float lit = clamp((t0 - t1) * 15.0, -1.0, 1.0);
		float dens = g_sm(0.3, 0.8, t0);
		float thick = g_sm(0.62, 0.85, t0);
		float glow = g_sm(0.32, 0.5, t0) * (1.0 - g_sm(0.5, 0.68, t0));
		// (its lit tops eased off above half again as bright, or a dense
		// arm's top went to one flat pale blob)
		float fv = (0.12 + 1.4 * dens) * (1.0 + 0.95 * lit) * (1.0 - 0.5 * thick) + 0.75 * glow;
		fv = fv > 1.0 ? 1.0 + 0.5 * (fv - 1.0) / (1.0 + (fv - 1.0)) : fv;
		fluff = mix(1.0, fv, kb);
	}
	if (a > 1e-4 || gl > 1e-5) {
		float q = g_fbm(vec2(lx * 0.016 + sd, ly * 0.016 - sd), o4());
		float w = g_fbm(vec2(lx * 0.016 + 5.2 + q * 1.9, ly * 0.016 + 1.3 + q * 1.9), o5());
		float g = g_sm(0.34, 0.9, w);
		float fil = pow(1.0 - abs(2.0 * g_fbm(vec2(lx * 0.045 + sd, ly * 0.045), o4()) - 1.0), 6.0);
		float mixv = g_fbm(vec2(lx * 0.02 + 9.0 + sd, ly * 0.02), 3.0);
		float on_arm = (1.0 - arm_k) + arm_k * g_sm(0.95, 1.55, rg);
		float gas_amt = min(1.5, gas);
		float i = (pow(g, 1.5) * 0.7 + g * fil * 0.9) * (0.25 + a) * a * gas_amt * (0.6 + 1.4 * near) * on_arm;
		float knot = g_sm(0.66, 0.86, g_fbm(vec2(lx * 0.085 + 13.0 + sd, ly * 0.085), o3()))
			* g_sm(0.25, 0.6, a) * min(1.3, gas_amt) * (1.0 - 0.5 * near)
			* ((1.0 - arm_k) + arm_k * g_sm(1.15, 1.7, rg));
		float m2 = max(g_sm(0.25, 0.75, mixv), knot);
		float tex = 0.55 + 0.9 * g_fbm(vec2(lx * 0.07 + 3.3, ly * 0.07), o4());
		i *= res2 * fluff;
		vec3 col = pal0 * (1.0 - m2) + pal1 * m2;
		col = col * (1.0 - near * 0.7) + CORE_C * near * 0.7;
		arm_gas = i * col + knot * pal1 * 0.9;
		// the clouds' own gas, brighter and richer than the arms' round it
		vec3 sat = gl + (gcl_c - gl) * 1.4;
		neb_gas = max(vec3(0.0), sat) * 1.1 * tex * (0.8 + 0.3 * near) * (1.0 - 0.45 * exp(-dd / (bul * 0.8)));
	}
	vec3 nl;
	float nh, nmoat, nhollow, ndark, nclear;
	// (not in the gas's own colour: that is read where the gas is, risen above
	// the plane, and a cloud drawn there sat above its outline, sheared by the
	// churning -- "the wave is messing with the localization", Jon. A named
	// cloud is drawn only where it is.)
	if (smth > 0.5) {
		nl = vec3(0.0);
		nh = 0.0;
		nmoat = 0.0;
		nhollow = 0.0;
		ndark = 0.0;
		nclear = 0.0;
	} else {
		nebulae(p, nl, nh, nmoat, nhollow, ndark, nclear);
	}
	// THE CLOUDS' LIGHT TONED DOWN as the bulge's is, so it climbs and keeps
	// its colour instead of clipping to white
	nl *= 1.25 / (1.0 + 0.9 * g_lum(nl));
	// THE DUST: the dark clouds, the lanes and the bulge's filaments, each
	// partly see-through, billowing in thickness, with a little grit deep in,
	// and held off the named clouds but for their edges
	// (`smth`: the gas's colour, read where the gas is, carries none of the
	// plane's fine grain -- copied up a cloud's face it was stretch marks; the
	// gas's own texture is its glow, which varies with height)
	float grit = mix(1.0, 0.6 + 0.8 * g_fbm(vec2(p.x * 0.3 + 11.0, ly * 0.3), 3.0), det_k * (1.0 - smth));
	float bill = 0.4 + 1.25 * g_fbm(vec2(p.x * 0.07 + 31.0, ly * 0.07 - sd), 3.0);
	// LESS MATERIAL, AND LANES OVER HAZE ("I think the dust might be too
	// thick here", Jon, of a broad dark murk between an arm and the bulge):
	// a third less dust all told, and how much of it stays depends on how
	// lane-like it is -- dust well above its surroundings a few pixels off is
	// a lane and keeps its contrast, dust as thick as its surroundings is a
	// broad haze and mostly goes
	const float DR = 5.0;
	float cdk = 0.0;
	if (cd > 0.0) {
		float e = g_fbm(vec2(p.x * 0.06 + sd, ly * 0.06), o4());
		float fine = mix(1.0, 0.65 + 0.7 * g_fbm(vec2(p.x * 0.3 + 5.0, ly * 0.3), o3()), g_sm(0.0, 0.25, det_k));
		float cm = (sb4(aux_tex, p + vec2(DR, 0.0)).b + sb4(aux_tex, p - vec2(DR, 0.0)).b
			+ sb4(aux_tex, p + vec2(0.0, DR)).b + sb4(aux_tex, p - vec2(0.0, DR)).b) * 0.25;
		float rc = clamp((cd - cm) / max(cd, 1e-3) * 4.0, 0.0, 1.0);
		cdk = cd * g_sm(0.28, 0.72, e) * 0.46 * fine * mix(0.4, 1.0, rc);
	}
	float clear = 1.0 - 0.85 * max(neb, nh);
	vec2 du = sb4(dust_tex, p).rg;
	vec2 dm = (sb4(dust_tex, p + vec2(DR, 0.0)).rg + sb4(dust_tex, p - vec2(DR, 0.0)).rg
		+ sb4(dust_tex, p + vec2(0.0, DR)).rg + sb4(dust_tex, p - vec2(0.0, DR)).rg) * 0.25;
	// (a lane's edge is sharp because its dust is cut at a level, over a
	// broad rise: so a lane is told by where the cut dust is, against where
	// it is a few pixels off, not by the rise itself)
	float lv0 = g_sm(0.02, 0.2, du.r * lane_amt);
	float lvm = (g_sm(0.02, 0.2, sb4(dust_tex, p + vec2(DR, 0.0)).r * lane_amt)
		+ g_sm(0.02, 0.2, sb4(dust_tex, p - vec2(DR, 0.0)).r * lane_amt)
		+ g_sm(0.02, 0.2, sb4(dust_tex, p + vec2(0.0, DR)).r * lane_amt)
		+ g_sm(0.02, 0.2, sb4(dust_tex, p - vec2(0.0, DR)).r * lane_amt)) * 0.25;
	float rl = clamp((lv0 - lvm) / max(lv0, 1e-3) * 2.0, 0.0, 1.0);
	// (the bulge's filaments too: the broad dark band they made between an
	// arm and the bulge was most of the murk)
	float rn = clamp((du.g - dm.y) / max(du.g, 1e-3) * 4.0, 0.0, 1.0);
	float lane_k = mix(0.4, 1.0, rl);
	float lane = g_sm(0.02, 0.2, du.r * lane_amt * grit) * 0.55 * lane_k;
	float raw = (cdk + lane) * bill * 0.67;
	// near side thicker and sharper, far side thinner and softer
	raw = mix(raw * 0.72, min(1.0, pow(raw * 1.35, 1.15)), nearf);
	// bright stars show through where it is thin
	raw *= 1.0 - 0.6 * g_sm(0.6, 1.4, g_lum(slv.rgb)) * (1.0 - g_sm(0.25, 0.6, raw));
	// (and none round YOU: the systems and routes there are dimmed by the gas
	// alone)
	float dkv = min(1.0, (raw + du.g * nuc_amt * 0.7 * grit * 0.67 * mix(0.4, 1.0, rn)) * clear) * youk
		* (1.0 - nclear) * (1.0 - g_sm(0.6, 1.4, dd / big_r));
	// the dust toward the core and up the screen: what throws a shadow here,
	// and what this dust's lit edge faces
	vec2 un = p / max(length(p), 1e-3);
	vec2 po = p - un * (1.2 + 1.5 / z) - down_p * 0.8;
	float rawo = (sb4(aux_tex, po).b * 0.23 + g_sm(0.02, 0.2, sb4(dust_tex, po).r * lane_amt) * 0.55 * lane_k) * bill * 0.67;
	rawo = mix(rawo * 0.72, min(1.0, pow(rawo * 1.35, 1.15)), nearf);
	float shade = 1.0 - 0.4 * max(0.0, rawo - raw * 0.5) * clear * youk;
	vec3 s = slv.rgb;
	// THE OUTER DISC FADES SLOWLY ("they could fade really gradually near the
	// edge of the outer part of the galaxy", Jon). The bake's light stops where
	// its stars stop, in a few pixels, somewhere between 1.1 and 1.5 of the
	// disc's radius -- an edge however softly it was frayed. So past half the
	// radius the disc's own light gives way, by the radius, to an outer disc of
	// its own: the light the disc has in this direction at half its radius
	// (softened over a short arc), falling off as a real disc's does, by about
	// e every half radius, broken into haze and wisps, and gone into the sky
	// at about twice the radius. The stars' grain lies over it as over the rest.
	float rnd = dd / big_r;
	float tk = 1.0;
	if (rnd > 0.5) {
		vec2 pl0 = vec2(lx, ly);
		vec2 dirp = pl0 / max(length(pl0), 1e-3);
		vec3 sref = vec3(0.0);
		for (int j = -1; j <= 1; j++) {
			float aj = float(j) * 0.18;
			vec2 dj = vec2(dirp.x * cos(aj) - dirp.y * sin(aj), dirp.x * sin(aj) + dirp.y * cos(aj)) * big_r * 0.5;
			sref += sb4(sl_tex, vec2(dj.x, dj.y * eff)).rgb;
		}
		sref /= 3.0;
		// (its colour from there, its brightness held to the disc's own
		// average at half the radius: a bright arm there no longer floods
		// the haze)
		float lref = g_lum(sref);
		sref *= min(1.0, 0.6 / max(lref, 1e-4));
		float env = exp(-(rnd - 0.5) / 0.45);
		float wsp = g_sm(0.25, 0.75, g_fbm(pl0 * 0.016 + vec2(sd, 41.0), 4.0)) * 1.5
			* (0.45 + 0.55 * g_fbm(pl0 * 0.05 + vec2(13.0, sd), 3.0));
		tk = 1.0 - g_sm(0.5, 1.0, rnd);
		s = s * tk + sref * env * wsp * (1.0 - tk);
	}
	float bf = slv.a;
	float det = resolved, gcl = 1.0;
	if (det_k > 0.0 && s.r + s.g + s.b > 0.01) {
		float f1 = g_fbm(vec2(p.x * 0.25 + sd, ly * 0.25), o3());
		gcl = g_sm(0.3, 0.7, 0.6 * g_fbm(vec2(p.x * 0.9 - sd, p.y / bsq * 0.9 + 7.0), o3())
			+ 0.4 * g_fbm(vec2(p.x * 2.1 + 3.0, p.y / bsq * 2.1), 3.0));
		det = resolved * (1.0 + det_k * 0.5 * (f1 - 0.5) * (1.0 - smth)) * ((1.0 - dz) + dz * mix(0.55 + 0.75 * gcl, 0.92, smth));
	}
	vec3 kk = 1.0 - dkv * vec3(0.72, 0.8, 0.88);
	vec3 tt = vec3(1.0);
	if (dz > 0.0) {
		float ww = dz * 0.45;
		tt = 1.0 + ww * vec3(0.08 - 0.16 * gcl, -0.22 + 0.38 * gcl, -0.4 + 0.75 * gcl);
	}
	// UNRESOLVED STARS. With the stars drawn one by one thinned to accents
	// (`star_level`), the light itself carries them: a stipple, a block wide
	// at every zoom and fixed in the galaxy, so the disc and the bulge still
	// read as made of stars rather than as a painting of gas
	float stip = 1.0;
	if (star_level >= 2) {
		// its grains fixed in the galaxy, never re-drawn as the zoom changes
		// (they were a grid of screen blocks, re-hashed at every zoom: "these
		// stars are jittering around", Jon): two grids of whole powers of two,
		// the coarser growing as you zoom in while the finer fades in, their
		// blend's contrast held so the grain never goes flat between them
		float n0 = log2(max(z * 0.5, 1e-3));
		float nf = floor(n0), fr = n0 - nf;
		float gm = star_level >= 4 ? 0.456 : 0.5;
		float gg[2];
		for (int k = 0; k < 2; k++) {
			float n = nf + float(k);
			vec2 scl = floor(p * exp2(n));
			float h = g_hash(int(scl.x) * 3 + 101 + int(n) * 577, int(scl.y) * 7 - 53 - int(n) * 131);
			// (level 4: its brightest grains capped, a fifth of them fewer specks)
			gg[k] = star_level >= 4 ? min(h * h * 1.5, 1.0) : h * h * 1.5;
		}
		float gv = gm + (mix(gg[0], gg[1], fr) - gm) / sqrt(fr * fr + (1.0 - fr) * (1.0 - fr));
		float amp = star_level >= 3 ? 0.55 : 0.3;
		stip = mix(max(0.0, 1.0 - amp * 0.5 + amp * gv), 1.0, smth);
	}
	o_dd = s * (1.0 - bf) * det * kk * tt * shade * (1.0 - 0.3 * nmoat) * stip * mix(1.0, fluff, 0.8)
		* (1.0 - 0.85 * ndark);
	// the bulge is made of stars too: a grain of star clouds over it, so it
	// is not a smooth plate at any zoom
	float grain = 0.78 + 0.3 * (smth > 0.5 ? 0.5 : g_fbm(vec2(p.x * 0.3 + 17.0, p.y / bsq * 0.3), 3.0))
		+ 0.22 * g_fbm(vec2(p.x * 0.09 - 5.0, p.y / bsq * 0.09), 3.0);
	o_bs = s * bf * det * tt * grain * stip * (1.0 - 0.85 * ndark);
	o_kd = max(dkv, ndark * 0.9);
	{
		vec2 plr = vec2(lx, ly);
		float fd = rim_fade(plr);
		if (fd < 1.0) {
			float rnr = dd / big_r;
			// a few stray star-forming patches out past the edge
			float pat = g_sm(0.62, 0.8, g_fbm(plr * 0.03 + vec2(sd, 17.0), 3.0))
				* (1.0 - g_sm(1.1, 1.5, rnr)) * (1.0 - fd);
			float kf = fd + pat * 0.6;
			o_dd *= kf;
			o_kd *= kf;
			o_gg *= kf;
		}
	}
	vec3 nk = mix(kk, vec3(1.0), max(neb, nh) * 0.85);
	// (the new look draws each cloud itself: the bake's flat wash of its gas
	// only faint under it)
	float ngas = neb_style == 4 ? 0.22 : (neb_style == 3 ? 0.25 : (neb_style == 1 ? 0.9 : 0.7));
	// the bake's own gas of a shell is a filled oval: hollowed, so the shell
	// and what lies behind it show
	ngas *= 1.0 - (neb_style == 4 ? 1.0 : 0.85) * nhollow;
	vec3 ng = neb_gas * nk * ngas;
	ng *= 1.2 / (1.0 + 0.8 * g_lum(ng));
	o_gg = (arm_gas * kk * shade * (1.0 - 0.45 * nmoat) * (1.0 - nclear) * (1.0 - g_sm(0.6, 1.5, dd / big_r)) + ng)
		* (1.0 - 0.85 * ndark) + nl * nk;
	// the dust's edge that faces the core, lit by it
	float lit = max(0.0, raw - rawo) * clear;
	if (lit > 0.01) {
		float nearc = exp(-length(vec2(p.x, p.y / eff)) / (bul * 1.8));
		vec3 rc = vec3(1.0, 0.86, 0.66) * 0.5 + CORE_C * 0.5;
		// lit only as brightly as the light round it: dust out in the dark
		// between the arms has nothing to glow with
		float amb = g_sm(0.03, 0.5, g_lum(s) + g_lum(arm_gas) * 2.0);
		o_gg += lit * (0.35 + 1.4 * nearc) * 0.7 * amb * rc;
	}
}

// The block at screen offset (x, dy) from the centre, dy already taken into
// the plane, turned by `ang` and looked up in the galaxy, weighted `w`.
void look(float x, float dy, float qs, float ang, float w, float nearf, float youk, float smth,
		inout vec3 dd, inout vec3 bs, inout float kd, inout vec3 gg) {
	float ca = cos(ang), sa = sin(ang);
	vec2 p = vec2(x * ca - dy * sa, (x * sa + dy * ca) * qs) / z;
	// one bake pixel down the screen, in the galaxy's frame
	vec2 down_p = vec2(-sa / qs, ca);
	vec3 a, b, c;
	float k;
	gal_fields(p, down_p, nearf, youk, smth, a, b, k, c);
	dd += a * w;
	bs += b * w;
	kd += k * w;
	gg += c * w;
}

vec3 star_warm(float r) {
	if (r < 0.1) return vec3(196.0, 214.0, 255.0);
	if (r < 0.3) return vec3(255.0, 242.0, 214.0);
	if (r < 0.58) return vec3(255.0, 214.0, 140.0);
	if (r < 0.82) return vec3(250.0, 160.0, 80.0);
	return vec3(214.0, 92.0, 40.0);
}

vec3 star_cool(float r) {
	if (r < 0.42) return vec3(184.0, 208.0, 244.0);
	if (r < 0.68) return vec3(232.0, 238.0, 246.0);
	if (r < 0.86) return vec3(250.0, 222.0, 150.0);
	return vec3(240.0, 150.0, 80.0);
}

vec3 hexc(int h) {
	return vec3(float((h >> 16) & 255), float((h >> 8) & 255), float(h & 255));
}

// THE VOLUME'S CLOUD TOPS. The disc is a slab whose clouds pile up into puffs
// and towers where the galaxy is dense -- its arms, more toward the bulge --
// and lie flat over the gaps between arms and outside the disc. `vol_top` is
// how high the clouds stand at a point of the plane (bake pixels); none
// round the hole, which has its own disc.
float vol_top(vec2 p) {
	vec4 au = sb4(aux_tex, p);
	float bw = sb4(sl_tex, p).a;
	float ly = p.y / eff;
	float dens = g_sm(0.08, 0.55, max(au.r, 0.55 * bw));
	if (dens <= 0.0) {
		return 0.0;
	}
	float b = g_fbm(vec2(p.x, ly) * 0.045 + vec2(sd * 1.7, 31.0), 3.0);
	float b2 = g_fbm(vec2(p.x, ly) * 0.11 + vec2(13.0, sd), 2.0);
	// (rounded, as cumulus: a dome's profile, not a cliff)
	float puff = pow(g_sm(0.28, 0.82, b * 0.8 + b2 * 0.2), 1.4);
	float hole = g_sm(rh * disc_k / z * 1.1, rh * disc_k / z * 1.8, length(vec2(p.x, ly)));
	return vol_h * dens * (0.15 + 0.85 * puff) * (1.0 + 0.4 * bw) * hole;
}

// THE GAS'S COLUMN at a point of the plane: how high its puffs reach (x,
// bake pixels) and how dense it is (y). Rounder and larger than the solid
// surface's: two octaves, the second pushed about by the first, so the puffs
// billow rather than crag.
vec2 vol_gas(vec2 p, float nebk) {
	vec4 au = sb4(aux_tex, p);
	float bw = sb4(sl_tex, p).a;
	vec2 pl = vec2(p.x, p.y / eff);
	float dens = g_sm(0.08, 0.55, max(au.r, 0.55 * bw));
	dens *= nebk;
	if (length(pl) > big_r * 0.45) {
		dens *= 1.0 - g_sm(0.55, 1.2, length(pl) / big_r + (g_noise(pl * 0.015 + vec2(sd, 4.0)) - 0.5) * 0.25);
	}
	if (dens <= 0.0) {
		return vec2(0.0);
	}
	float w = g_fbm(pl * 0.018 + vec2(sd, 7.0), 2.0);
	// churning in place: the push that shapes the puffs turns slowly, each
	// region on its own phase and at its own pace, so a puff swells, leans and
	// subsides over twenty seconds or so while its neighbours do their own (at
	// three times this pace a tenth of the blocks changed every frame); and
	// the puffs' height breathes the same way. Fixed in the galaxy, nothing
	// slides
	float ph0 = g_noise(pl * 0.012 + vec2(3.0, sd)) * 6.2832;
	float th = ph0 + gas_t * (0.1 + 0.08 * g_noise(pl * 0.01 + vec2(sd, 51.0)));
	vec2 wv = vec2(1.6, -1.2) + vec2(cos(th), sin(th)) * (gas_t > 0.0 ? 0.8 : 0.0);
	float b = g_fbm(pl * 0.03 + wv * w + vec2(21.0, sd * 1.3), 2.0);
	float puff = pow(g_sm(0.25, 0.8, b), 1.2);
	if (gas_t > 0.0) {
		puff *= 0.88 + 0.24 * (0.5 + 0.5 * sin(gas_t * 0.16 + ph0 * 1.7));
	}
	float hole = g_sm(rh * disc_k / z * 1.1, rh * disc_k / z * 1.8, length(pl));
	return vec2(vol_h * dens * (0.2 + 0.8 * puff) * (1.0 + 0.4 * bw) * hole, dens * (0.45 + 0.55 * puff) * hole);
}

// A NOISE IN THREE DIMENSIONS, near enough: two noises of the plane, each slid
// along by the height in its own direction, multiplied. The gas varies up its
// column as much as across it, so the column above one point of the plane is
// not one colour copied up the screen ("the stretch marks on them vertically
// look bad", Jon). Mean about a quarter.
float gas_n3(vec2 pl, float h) {
	return g_noise(vec2(pl.x * 0.16 + h * 0.55, pl.y * 0.16 - h * 0.21))
		* g_noise(vec2(pl.y * 0.14 - h * 0.47 + 9.0, pl.x * 0.14 + h * 0.3));
}

// The gas's density at a point of the plane and a height: full low down,
// thinning over the upper half of its column into a ragged top -- wisps,
// never a silhouette -- with some puffs denser than others inside it.
float gas_rho(vec2 p, float h, float nebk) {
	vec2 c = vol_gas(p, nebk);
	if (c.y <= 0.0) {
		return 0.0;
	}
	vec2 pl = vec2(p.x, p.y / eff);
	// (the wisps at the tops drift and curl, slowly, each on its own phase)
	float ph1 = g_noise(pl * 0.05 + vec2(sd, 9.0)) * 6.2832;
	vec2 cu = gas_t > 0.0 ? vec2(sin(gas_t * 0.13 + ph1), cos(gas_t * 0.11 + ph1 * 1.3)) * 1.0 : vec2(0.0);
	float n = g_noise(pl * 0.22 + vec2(h * 0.45, -h * 0.3) + cu);
	float top = c.x * (0.75 + 0.5 * n);
	float prof = 1.0 - g_sm(top * 0.4, top + 0.5, h);
	float inner = 0.6 + 0.8 * g_noise(pl * 0.09 + vec2(h * 0.25 + 40.0, -h * 0.2));
	return gas_k * c.y * prof * inner * (0.35 + 2.6 * gas_n3(pl, h));
}

// The plane point seen through screen offset (x, ys) at height h (bake
// pixels), the turn `ang`: a point h above the plane shows h * cos(tilt) higher
// up the screen, so this one sits that much nearer the viewer.
vec2 vol_p(float x, float ys, float h, float qs, float ang) {
	float dy = (ys + h * 0.925 * z) / qs;
	float ca = cos(ang), sa = sin(ang);
	return vec2(x * ca - dy * sa, (x * sa + dy * ca) * qs) / z;
}

void fragment() {
	vec2 vp = floor(UV * vp_size);
	vec2 rel;
	if (probe) {
		rel = (vp + 0.5) / vp_size * vec2(896.0, 616.0) - vec2(448.0, 308.0);
	} else {
		rel = vp_origin + vp * 2.0 + 0.5 - cpix;
	}
	float lxs = rel.x, lys = rel.y;
	float ph = probe ? 0.0 : phi;

	// ---- the galaxy's own fields, turned
	float wb = min(1.0, sb4(sl_tex, rel / z).a);
	float qs = eff + (bsq - eff) * wb;
	float dy = lys / qs;
	float kb = probe ? 0.0 : wk(length(vec2(lxs, dy)) / z);
	vec3 f_dd = vec3(0.0), f_bs = vec3(0.0), f_gg = vec3(0.0);
	// how near the viewer this part of the disc is: low on the screen is near
	float nearf = g_sm(-0.6, 0.6, lys / z / eff / big_r);
	// no dust round YOU (`you_rel`, screen pixels from the centre)
	float youk = probe ? 1.0 : g_sm(you_r * 0.55, you_r, length(rel - you_rel));
	float f_kd = 0.0;
	// ---- THE VOLUME: the view ray marched down through the slab from its top;
	// where it first meets a cloud top is what this block shows -- so a tall
	// cloud rises above its own footprint and hides what lies behind it --
	// lit by its slope toward the core, in shadow where a taller cloud stands
	// between it and the core
	float vhit = 0.0, vshade = 1.0;
	// AS GAS: the ray's light gathered through the slab -- each step's gas
	// takes a share of what is left of the view (Beer-Lambert), so thin tops
	// and edges let what lies behind show through and dense cores hide it;
	// the cloud's colour is the galaxy's where most of that gas is, lit by
	// the core's light scattered in through what gas lies toward the core;
	// what is left of the view is the galaxy's own plane behind it
	float galpha = 0.0, gshade = 1.0, gdy = dy;
	if (!probe && vol_h > 0.0 && gas_k > 0.0 && kb < 1e-5) {
		float hm = vol_h * 1.3;
		int nst = clamp(int(hm * z * 0.925 / 2.0) + 5, 6, 24);
		float dh = hm / float(nst);
		float tr = 1.0, wsum = 0.0, hsum = 0.0, esum = 0.0;
		// each block's steps start at its own offset, fixed in the galaxy (a
		// hash of the plane point under it), so the steps do not line up
		// across a column into bands
		vec2 p00 = vol_p(lxs, lys, 0.0, qs, ph);
		// OVER A NAMED CLOUD THE ARM'S VOLUME THINS, so the cloud -- drawn
		// only where it is, at the plane -- shows there: most over a planetary
		// (a bubble blown in the medium), half over a remnant, three quarters
		// over the rest
		float nebk = 1.0;
		if (neb_style == 4) {
			for (int k = 0; k < 32; k++) {
				if (k >= neb_n) {
					break;
				}
				int kk2 = int(neb_a[k].w + 0.5) & 7;
				vec2 oo = p00 - neb_a[k].xy;
				float rr2 = length(vec2(oo.x, oo.y / neb_b[k].w)) / neb_a[k].z;
				float amt = kk2 == 2 ? 0.92 : (kk2 == 3 ? 0.5 : 0.75);
				nebk = min(nebk, 1.0 - amt * (1.0 - g_sm(0.85, 1.1, rr2)));
			}
		}
		float jt = g_hash(int(floor(p00.x * 0.5)), int(floor(p00.y / eff * 0.5)) + 977);
		for (int i = 0; i < 24; i++) {
			if (i >= nst || tr < 0.03) {
				break;
			}
			float h = hm * (1.0 - (float(i) + jt) / float(nst));
			vec2 pk = vol_p(lxs, lys, h, qs, ph);
			float rho = gas_rho(pk, h, nebk);
			// (a step down through the slab is 1 / sin of the view's slant
			// along the ray)
			float a = 1.0 - exp(-rho * dh * 2.6);
			wsum += tr * a;
			hsum += tr * a * h;
			// and its glow varies in three dimensions too
			esum += tr * a * (0.55 + 1.8 * gas_n3(vec2(pk.x, pk.y / eff) * 1.7 + 31.0, h * 1.6));
			tr *= 1.0 - a;
		}
		galpha = 1.0 - tr;
		if (galpha > 0.01) {
			vhit = hsum / max(wsum, 1e-4);
			vec2 pc = vol_p(lxs, lys, vhit, qs, ph);
			vec2 pl = vec2(pc.x, pc.y / eff);
			vec2 toc = -pl / max(length(pl), 1e-3);
			// the core's light, thinned by the gas it crosses on its way in:
			// three soft steps toward the core at the cloud's height
			float tau = 0.0;
			for (int j = 1; j <= 3; j++) {
				vec2 q = pl + toc * float(j) * hm * 0.5;
				tau += gas_rho(vec2(q.x, q.y * eff), vhit, nebk) * hm * 0.5;
			}
			float lit = exp(-tau * 1.1);
			// and where the cloud is thin against that light, its edge glows
			float rim = g_sm(0.05, 0.35, galpha) * (1.0 - g_sm(0.45, 0.85, galpha));
			gshade = (0.4 + 0.85 * lit) * (1.0 + 0.8 * rim * lit) * (1.0 + 0.3 * vhit / vol_h)
				* (esum / max(wsum, 1e-4));
			gdy = (lys + vhit * 0.925 * z) / qs;
		}
	}
	if (!probe && vol_h > 0.0 && gas_k <= 0.0 && kb < 1e-5) {
		int nst = clamp(int(vol_h * z * 0.925 / 2.0) + 4, 6, 18);
		float hprev = vol_h, dprev = -1.0;
		for (int i = 0; i <= 18; i++) {
			if (i > nst) {
				break;
			}
			float h = vol_h * (1.0 - float(i) / float(nst));
			float tp = vol_top(vol_p(lxs, lys, h, qs, ph));
			float dd2 = h - tp;
			if (dd2 <= 0.0) {
				// between this step and the last: where the ray crossed the top
				float f = dprev / max(dprev - dd2, 1e-4);
				vhit = i == 0 ? h : mix(hprev, h, clamp(f, 0.0, 1.0));
				break;
			}
			hprev = h;
			dprev = dd2;
		}
		if (vhit > 0.0) {
			vec2 ph0 = vol_p(lxs, lys, vhit, qs, ph);
			vec2 pl = vec2(ph0.x, ph0.y / eff);
			vec2 toc = -pl / max(length(pl), 1e-3);
			// its slope toward the core (the top facing the core is lit) and,
			// where the ray met a cloud's side rather than its top, that side
			float e1 = 1.5;
			float sl = (vol_top(vec2(pl.x + toc.x * e1, (pl.y + toc.y * e1) * eff)) - vol_top(ph0)) / e1;
			float lit = clamp(-sl * 1.1 + 0.3, -1.0, 1.0);
			// shadow: a taller cloud between it and the core, the light low
			float sh = 0.0;
			for (int j = 1; j <= 4; j++) {
				float dj = float(j) * vol_h * 0.6;
				vec2 q = pl + toc * dj;
				sh = max(sh, g_sm(0.0, vol_h * 0.25, vol_top(vec2(q.x, q.y * eff)) - (vhit + dj * 0.18)));
			}
			float hw = g_sm(0.0, vol_h * 0.35, vhit);
			// soft, as cloud is: the far slopes only half in shade, a shadow
			// thinning the light by a third, and the higher tops a little
			// brighter, catching more of the core's light
			vshade = mix(1.0, (0.8 + 0.4 * lit) * (1.0 - 0.33 * sh) * (1.0 + 0.25 * vhit / vol_h), hw);
			dy = (lys + vhit * 0.925 * z) / qs;
		}
	}
	if (kb < 1e-5 && galpha > 0.01) {
		vec3 c_dd = vec3(0.0), c_bs = vec3(0.0), c_gg = vec3(0.0);
		float c_kd = 0.0;
		look(lxs, gdy, qs, ph, galpha, nearf, youk, 1.0, c_dd, c_bs, c_kd, c_gg);
		look(lxs, dy, qs, ph, 1.0 - galpha, nearf, youk, 0.0, f_dd, f_bs, f_kd, f_gg);
		f_dd += c_dd * gshade;
		f_bs += c_bs * gshade;
		f_gg += c_gg * gshade;
		f_kd += c_kd;
	} else if (kb < 1e-5) {
		look(lxs, dy, qs, ph, 1.0, nearf, youk, 0.0, f_dd, f_bs, f_kd, f_gg);
		f_dd *= vshade;
		f_gg *= vshade;
	} else {
		// inside the innermost ring the turn climbs: two copies, each restarted
		// every period and cross-faded, so it turns without winding up
		float pp = min(18.0, 1.2 / kb);
		float t0 = mod(t, pp), t1 = mod(t0 + pp * 0.5, pp);
		float w0 = 1.0 - abs(2.0 * t0 / pp - 1.0), w1 = 1.0 - w0;
		if (w0 > 0.001) {
			look(lxs, dy, qs, ph + kb * t0, w0, nearf, youk, 0.0, f_dd, f_bs, f_kd, f_gg);
		}
		if (w1 > 0.001) {
			look(lxs, dy, qs, ph + kb * t1, w1, nearf, youk, 0.0, f_dd, f_bs, f_kd, f_gg);
		}
	}

	// ---- the screen's: the bulge's glow and which side of it is in front
	float vs = lys / z;
	float dball = length(vec2(lxs / z, vs / bsq));
	float dsm = sqrt(dball * dball + te_b * te_b);
	float dco = sqrt(dball * dball + bul * bul * 0.03 / (zf * zf) + te_b * te_b);
	float nuc = 3.2 * exp(-2.4 * sqrt(dsm / (bul * 0.4))) * g_sm(1.3, 4.0, zf);
	float ci = (3.0 * exp(-3.0 * sqrt(dco / (bul * (1.8 - 0.5 * arm_k)))) * (0.6 + 0.4 * resolved) + nuc) * (1.0 - dz * 0.125);
	float rout = rh * disc_k;
	float hd = length(vec2(lxs, lys / TILT));
	// the light dims a little round the hole, so the hole and its ring sit in
	// a darker ring of light rather than a white field
	float hdim = 1.0 - (0.14 + zoom_dim * 0.15) * exp(-pow(hd / (rout * 2.2), 2.0));
	float inner = exp(-dball / (bul * 0.4)), hot = exp(-dsm / (bul * 0.16 / sqrt(zf)));
	vec3 c_i = vec3(1.0, 0.82, 0.55) / g_lum(vec3(1.0, 0.82, 0.55));
	vec3 c_o = vec3(0.95, 0.45, 0.17) / g_lum(vec3(0.95, 0.45, 0.17));
	vec3 kc = c_o * (1.0 - inner) + c_i * inner;
	// toward white only at the very middle, and not all the way
	kc = (kc * (1.0 - hot * 0.6) + vec3(1.02, 0.99, 0.93) * hot * 0.6) * 0.68;
	vec3 sci = ci * kc;
	// (a cloud risen in front holds back the bulge's glow behind it)
	sci *= gas_k > 0.0 ? 1.0 - 0.7 * galpha : 1.0 - 0.7 * g_sm(0.0, vol_h * 0.5 + 1e-3, vhit) * (vol_h > 0.0 ? 1.0 : 0.0);
	float front = g_sm(-bul * 0.9, bul * 0.9, -(vs / eff) * SIN_I);
	float dbs = length(vec2(lxs / z, lys / z / bsq));
	float cis = 2.4 * exp(-3.0 * sqrt(sqrt(dbs * dbs + bul * bul * 0.03) / (bul * 1.8)));
	float bulop = dk_g > 0.5 ? g_sm(0.12, 0.7, cis * 0.55) : 0.0;
	float behind = 1.0 - 0.55 * bulop * front;
	float gd = length(vec2(lxs / (rout * 1.5), lys / (rout * 1.5 * TILT * 1.35)));
	float bhl = gd < 1.0 ? (1.0 - gd) * (1.0 - gd) * g_sm(0.05, 0.5, gd) : 0.0;
	vec3 sgh = bhl * 0.65 * vec3(1.0, 0.5, 0.18) * 0.9;

	vec3 qv = front + (1.0 - front) * (1.0 - f_kd * vec3(0.72, 0.8, 0.88));
	vec3 o = (f_dd * behind + (f_bs + sci) * qv) * hdim * 0.72;
	// THE BULGE'S EXPOSURE ("the center of the galaxy is SO WASHED out", Jon).
	// Its light sat high on the tone curve all across it, one flat cream
	// plate. Brought down over the bulge and less so toward the nucleus, it
	// climbs to the middle instead, keeps its amber-to-gold, and reaches
	// white only in a small nucleus round the hole. Deep in, where the view is
	// all bulge and was judged as it was, it eases back off.
	{
		// one exposure over the whole bulge, so its own fall toward the edge
		// is kept, easing back to the arms' only well outside it
		float wbx = exp(-pow(dball / (bul * 2.4), 2.0)) * (1.0 - g_sm(2.5, 7.0, zf));
		float nucl = exp(-dsm / (bul * 0.2));
		// and a climb of its own toward the middle, so the plateau a bright
		// bulge settles into on the tone curve still rises to its centre
		float climb = exp(-dball / (bul * 0.55));
		o *= mix(1.0, 0.4 + 0.42 * climb + 0.12 * nucl, wbx);
		float lm = g_lum(o);
		o = max(vec3(0.0), lm + (o - lm) * (1.0 + 0.35 * wbx));
	}
	if (dz > 0.0) {
		float lm = g_lum(o);
		o = max(vec3(0.0), lm + (o - lm) * (1.0 + 0.6 * dz));
	}
	// slow waves of brightness through the gas, fixed in the galaxy
	float m = 1.0;
	if (!probe) {
		float cph = cos(ph), sph = sin(ph);
		vec2 gw = vec2(lxs * cph - dy * sph, lxs * sph + dy * cph) / z;
		// slow: at the mockup's rate they swept through the arms at about
		// nine pixels a second, which read as the galaxy moving
		float tw = t * 0.2;
		m = 1.0 + 0.42 * sin(gw.x * 0.034 + tw * 0.30) * sin(gw.y * 0.047 - tw * 0.22)
			+ 0.2 * sin(gw.x * 0.071 - tw * 0.41) * cos(gw.y * 0.066 + tw * 0.35);
	}
	vec3 light = o * (1.0 - 0.42 * dz) + (f_gg * behind + sgh) * m;
	if (!probe && (depth_look == 1 || depth_look == 3)) {
		// LAYERS YOU PASS THROUGH: four sheets of sparse dust between you and
		// the galaxy, each at its own fixed height above it and with its own
		// fixed pattern, fixed in the galaxy. Zooming in brings you down
		// toward them, so a nearer sheet is drawn bigger (`mk`): it grows
		// faster than the galaxy as you zoom and slides faster as you pan;
		// the nearest thins out smoothly as you come close to it. Nothing
		// re-made as you zoom (they used to cycle, coming on and starting
		// again behind with a new pattern: "dust and gas on top of the
		// galaxy pop in and out", Jon). Only over the galaxy's dense parts --
		// its arms and bulge, as bright as they are (`gal`) -- darkening
		// them, with the edges of each wisp lit
		float ka = depth_look == 1 ? 1.0 : depth_amt;
		vec2 sp = vp_origin + vp * 2.0 + 0.5;
		vec2 cam = (view_c - cpix) / z;
		float gal = g_sm(0.07, 0.4, g_lum(light));
		float dk = 0.0, lg = 0.0;
		for (int k = 0; k < 4; k++) {
			// how near you the sheet is: it would reach you at a zoom of
			// 20, 40, 80, 160 times the opening one
			float qk = 0.05 / pow(2.0, float(k));
			float near_k = min(qk * z, 0.95);
			float mk = 1.0 / (1.0 - near_k);
			float ak = 1.0 - g_sm(0.45, 0.85, near_k);
			vec2 gp = (sp - view_c) / (mk * z) + cam;
			vec2 sd2 = vec2(float(k) * 41.0 + 7.0, -float(k) * 23.0 + 3.0);
			float f = g_fbm(gp * 0.05 + sd2, 4.0);
			float big = g_fbm(gp * 0.016 + sd2 * 0.7, 3.0);
			float wv = g_sm(0.46, 0.68, f) * g_sm(0.3, 0.6, big);
			dk = max(dk, wv * ak);
			lg += wv * (1.0 - wv) * 4.0 * ak;
		}
		light *= 1.0 - ka * 0.8 * dk * gal;
		light += light * ka * 0.7 * min(lg, 1.0) * gal;
	}

	// ---- the gas round the hole, turning in its plane
	bool keep = false;
	if (!probe && swirl_amp > 0.0) {
		float yd = lys / TILT;
		float r = length(vec2(lxs, yd)) + 0.01;
		float x = r / rout;
		float env = swirl_amp * g_sm(0.72, 1.12, x) * (1.0 - g_sm(1.7, 4.4, x))
			* (1.15 - 0.35 * g_sm(1.0, 3.0, x)) * (1.0 - g_sm(0.7 * rb_ring * z, rb_ring * z, r));
		if (env > 0.004) {
			// it turns as the disc does where it meets it, and settles to
			// nothing a little way out: only the disc spins visibly
			float rr0 = max(r / z, rin_p);
			float om = 1.1 * pow(rr0 / rin_p, -1.5) * (1.0 - g_sm(1.0, 1.8, x))
				// (the disc's own speed at its rim, then calming to 0.4 of it
				// just outside, so it is one motion with the disc)
				* mix(1.0, 0.4, g_sm(1.0, 1.2, x));
			float u = log(x), ang = atan(yd, lxs), a = ang + phi;
			float lit = 0.0, dkk = 0.0;
			for (int i = 0; i < 2; i++) {
				float ti = mod(t + float(i) * 9.0, 18.0);
				float wt = 1.0 - abs(2.0 * ti / 18.0 - 1.0);
				float uu = clamp(u + 0.016 * ti, -0.4, 3.2);
				float aa = a - 1.6 * u + om * ti + float(i) * 2.1;
				float n1 = g_fbm(vec2(cos(aa) * 2.6 + uu * 6.5 + 11.0, sin(aa) * 2.6 - uu * 3.1), 4.0);
				float n2 = g_fbm(vec2(cos(aa) * 1.7 - uu * 4.2 + 40.0, sin(aa) * 1.7 + uu * 5.3), 4.0);
				float rdg = pow(1.0 - abs(2.0 * n1 - 1.0), 3.0);
				lit += wt * (0.18 + 1.25 * rdg * (0.5 + n2));
				dkk += wt * g_sm(0.55, 0.78, n2) * (1.0 - rdg);
			}
			// clumps drifting inward, drawn out along their orbits
			for (int c = 0; c < 6; c++) {
				vec4 cl = clumps[c];
				if (cl.z < 0.02) {
					continue;
				}
				float du = (u - cl.x) / 0.11;
				if (abs(du) > 3.0) {
					continue;
				}
				float da = wrap_pi(ang - cl.y);
				float along = da > 0.0 ? da / 0.9 : da / 0.25;
				lit += cl.z * 2.2 * exp(-du * du - along * along);
			}
			float hotk = 1.0 - g_sm(0.9, 2.6, x);
			vec3 sc = SW_HOT * hotk + sw_gas * (1.0 - hotk);
			float dv = dkk * env, lv = lit * 0.55 * env;
			// its dark streaks only on the far side: on the near side, just
			// below the hole's disc, they were a dark band between the disc
			// and the swirl's own bright ring under it, which read as a gap in
			// the disc ("weird gap at the bottom of the black hole", Jon)
			dv *= g_sm(-0.2, 0.6, -yd / rout) + 0.25;
			float wf = 1.0 - g_sm(-1.0, 1.0, yd / rout);
			ivec2 blk = ivec2(vp + floor((vp_origin - cpix) * 0.5));
			keep = (1.0 - wf) * 16.0 > g_bayer(blk) + 0.5;
			light = light * (1.0 - dv * vec3(0.62, 0.7, 0.78)) + lv * sc;
		}
	}

	if (!probe && cluster_look >= 1) {
		// THE GLOBULAR CLUSTERS AS GLOWS: each a small round warm haze,
		// brightest in the middle -- an old, packed ball of stars too many to
		// tell apart; the size of their middles, a block or two across when
		// the whole galaxy is in view
		float sg = max(2.2, 0.006 * big_r * z);
		for (int k = 0; k < 32; k++) {
			if (k >= n_glob) {
				break;
			}
			vec2 cc = glob_c[k];
			float r0 = length(vec2(cc.x, cc.y / eff));
			float a0 = atan(cc.y / eff, cc.x) - phi;
			vec2 gcs = vec2(cos(a0) * r0, sin(a0) * r0 * eff) * z;
			vec2 dd = rel - gcs;
			float e2 = dot(dd, dd) / (sg * sg);
			if (e2 < 12.0) {
				float gl = exp(-e2) * 0.55 + exp(-e2 * 0.25) * 0.12;
				light += vec3(1.0, 0.84, 0.6) * gl;
			}
		}
	}
	vec3 disp = g_tone(light);
	float flag = keep ? 0.75 : 1.0;
	if (probe) {
		COLOR = vec4(disp, 1.0);
	} else {
		vec3 d255 = disp * 255.0;
		// ---- more stars as you go in, on a grid in the galaxy's own frame
		if (filler_k > 0.0) {
			// THE SAME STARS AT EVERY ZOOM ("these stars are jittering around
			// or being redrawn", Jon): each lives on a grid fixed in the
			// galaxy, one grid a level (cells sqrt(2) times finer each time),
			// with a fixed draw of its own. A level lights a fixed share of its
			// cells -- the density wanted at the zoom it arrives at -- coming in
			// a star at a time over one level's zoom and then staying, its
			// stars spreading apart as you go in while the next level's fill
			// in between; only the oldest of four, by then an eighth as dense,
			// is let go, a star at a time. So a star appears at its own fixed
			// spot and stays; nothing is re-drawn when a level changes.
			float yd0 = lys / eff;
			float r0 = length(vec2(lxs, yd0)) / z;
			float a0 = atan(yd0, lxs) + phi + wk(r0) * t;
			float u = 2.0 * log2(max(z, 1e-3));
			int lb = int(floor(u)) - 2;
			bool found = false;
			for (int kl = 0; kl < 4; kl++) {
				int L = lb + kl;
				if (L < 0 || found) {
					continue;
				}
				float wl = clamp(u - float(L) + 1.0, 0.0, 1.0) * clamp(float(L) + 3.0 - u, 0.0, 1.0);
				float zbl = pow(1.41421356, float(L));
				// the share of its cells the level lights: the density wanted
				// at its own zoom (the levels before it, spread apart, make up
				// the other half)
				float fkl = filler_k * (0.16 * (pow(zbl, -0.45) - pow(zbl, -2.0)) * (1.0 + 0.35 * g_sm(1.8, 8.0, zbl))) * wl * 0.5;
				if (fkl <= 0.0) {
					continue;
				}
				vec2 gc = vec2(cos(a0), sin(a0)) * r0 * zbl;
				ivec2 c0 = ivec2(floor(gc));
				// a block is a pixel or two across on the screen, and up the
				// screen the disc's plane is stretched by 1 / eff: that many
				// cells round it may hold the star that lands in it
				int nb = min(4, int(ceil(zbl / (z * eff))));
				for (int jy = -nb; jy <= nb; jy++) {
					for (int jx = -nb; jx <= nb; jx++) {
						if (found) {
							continue;
						}
						ivec2 cell = c0 + ivec2(jx, jy);
						float h = g_hash(cell.x * 3 + 17, cell.y * 5 + L * 7919);
						if (h > fkl * 1.7) {
							continue;
						}
						vec2 gp = vec2(cell);
						float rr = length(gp);
						float sa = atan(gp.y, gp.x) - (phi + wk(rr / zbl) * t);
						vec2 sp = vec2(cos(sa) * rr, sin(sa) * rr * eff) * (z / zbl);
						vec2 spx = floor(cpix + sp + 0.5);
						if (floor((spx - vp_origin) * 0.5) != vp) {
							continue;
						}
						vec2 ub = vec2(gp.x, gp.y * eff) / zbl;
						vec4 s = sb4(sl_tex, ub);
						float l = g_lum(s.rgb);
						float clm = 0.3 + 1.4 * g_sm(0.3, 0.7, 0.6 * g_fbm(vec2(ub.x * 0.9 - sd, ub.y / bsq * 0.9 + 7.0), 4.0)
							+ 0.4 * g_fbm(vec2(ub.x * 2.1 + 3.0, ub.y / bsq * 2.1), 3.0));
						if (h > min(1.0, l * 1.4) * fkl * clm) {
							continue;
						}
						float warm = (s.r - s.b) / max(1e-3, l);
						float r2 = g_hash(cell.x + 3, cell.y - L);
						vec3 sc = warm > 0.25 ? star_warm(r2) : star_cool(r2);
						if (g_hash(cell.x - 9, cell.y + 4 + L * 31) < 0.35) {
							// the dim ones go first when there are to be fewer
							if (star_level >= 2) {
								continue;
							}
							sc *= 0.72;
						}
						// (one in ten of those the light would hide: accents)
						bool near = length(spx - cpix) < near_r && g_hash(cell.x * 13 - 7, cell.y * 3 + 91 + L * 17) < 0.1;
						// and true white only for a few: the rest at the dimmer
						// shade every palette keeps, so a tinted star colour that
						// no palette change can recolour
						if (star_level >= 4 && min(sc.r, min(sc.g, sc.b)) > 200.0 && g_hash(cell.x + 41, cell.y - 17 + L * 13) > 0.15) {
							sc *= 0.72;
						}
						float dc = abs(sc.r - d255.r) + abs(sc.g - d255.g) + abs(sc.b - d255.b);
						if (!near && g_lum(sc) < g_lum(d255) * 1.12 + 6.0 && dc < 150.0) {
							continue;
						}
						d255 = sc;
						flag = keep ? 0.25 : 0.5;
						found = true;
					}
				}
			}
		}
		// ---- the sky behind: three depths of stars, and far galaxies
		vec2 b0 = vp_origin + vp * 2.0;
		for (int li = 0; li < 3; li++) {
			float rate = li == 0 ? 0.18 : (li == 1 ? 0.38 : 0.62);
			float cell = li == 0 ? 32.0 : (li == 1 ? 48.0 : 90.0);
			float keep_p = li == 0 ? 0.88 : (li == 1 ? 0.92 : 0.93);
			vec2 off = sky_pan * rate;
			vec2 lo = floor((b0 - off) / cell), hi = floor((b0 + 1.0 - off) / cell);
			for (int cy = 0; cy < 2; cy++) {
				for (int cx = 0; cx < 2; cx++) {
					if ((cx == 1 && hi.x == lo.x) || (cy == 1 && hi.y == lo.y)) {
						continue;
					}
					vec2 cc = vec2(cx == 0 ? lo.x : hi.x, cy == 0 ? lo.y : hi.y);
					int ix = int(cc.x), iy = int(cc.y);
					int salt = sky_seed + li * 7919;
					if (g_hash(ix * 7 + salt, iy * 13 + 5) > keep_p) {
						continue;
					}
					vec2 sp = (cc + vec2(g_hash(ix + salt, iy * 3 + 11), g_hash(ix * 5 + salt, iy + 29))) * cell + off;
					vec2 spx = floor(sp + 0.5);
					if (floor((spx - vp_origin) * 0.5) != vp) {
						continue;
					}
					float r = g_hash(ix * 11 + salt, iy * 17 + 41);
					// fewer: the dimmest colour of each depth goes first, then the
					// middle one, and the deepest layer's last
					// (level 4: half again -- the deepest layer only its very
					// brightest, the others their brighter colours)
					if ((star_level == 2 && r < 0.31) || (star_level == 3 && (r < 0.62 || li == 0) && r <= 0.93)
							|| (star_level >= 4 && (li == 0 ? r <= 0.965 : r < 0.8))) {
						continue;
					}
					vec3 sc;
					if (li == 0) {
						sc = r > 0.93 ? hexc(0x33445a) : (r < 0.31 ? hexc(0x121a26) : (r < 0.62 ? hexc(0x17202e) : hexc(0x1d2838)));
					} else if (li == 1) {
						sc = r > 0.93 ? hexc(0x6f8399) : (r < 0.31 ? hexc(0x1b2534) : (r < 0.62 ? hexc(0x26324a) : hexc(0x2e2a3a)));
					} else {
						sc = r > 0.93 ? hexc(0xc9d8ea) : (r < 0.31 ? hexc(0x33445a) : (r < 0.62 ? hexc(0x4a5a70) : hexc(0x5a4a3a)));
					}
					if (g_lum(d255) + 4.0 < g_lum(sc)) {
						d255 = sc;
						flag = keep ? 0.25 : 0.5;
					}
				}
			}
			if (li == 0) {
				// the far galaxies, on the deepest layer
				float gcell = 341.0;
				vec2 glo = floor((b0 - off - 8.0) / gcell), ghi = floor((b0 - off + 8.0) / gcell);
				for (int gy = 0; gy < 2; gy++) {
					for (int gx = 0; gx < 2; gx++) {
						if ((gx == 1 && ghi.x == glo.x) || (gy == 1 && ghi.y == glo.y)) {
							continue;
						}
						vec2 cc = vec2(gx == 0 ? glo.x : ghi.x, gy == 0 ? glo.y : ghi.y);
						int ix = int(cc.x), iy = int(cc.y);
						int salt = sky_seed + 501;
						vec2 gcen = floor((cc + vec2(g_hash(ix + salt, iy + 1), g_hash(ix + salt, iy + 2))) * gcell + off + 0.5);
						vec2 q = b0 - gcen;
						if (abs(q.x) > 8.0 || abs(q.y) > 6.0) {
							continue;
						}
						float ga = 3.0 + g_hash(ix + salt, iy + 3) * 4.0;
						float gr = 0.3 + g_hash(ix + salt, iy + 4) * 0.6;
						float gang = g_hash(ix + salt, iy + 5) * 3.1;
						float ca = cos(gang), sa = sin(gang);
						float uu = (q.x * ca + q.y * sa) / ga, vv = (-q.x * sa + q.y * ca) / (ga * gr);
						float gi = exp(-(uu * uu + vv * vv) * 1.6);
						if (gi < 0.25) {
							continue;
						}
						int pick = int(g_hash(ix + salt, iy + 6) * 3.0);
						vec3 gcol = pick == 0 ? hexc(0x3a3550) : (pick == 1 ? hexc(0x2d3a52) : hexc(0x4a3a34));
						vec3 sc = min(gcol * (0.6 + gi), vec3(255.0));
						if (g_lum(d255) < g_lum(sc)) {
							d255 = sc;
							flag = keep ? 0.25 : 0.5;
						}
					}
				}
			}
		}
		COLOR = vec4(d255 / 255.0, flag);
	}
}
