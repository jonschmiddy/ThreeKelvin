shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// THE NEBULA A SYSTEM SITS IN, SEEN FROM INSIDE (Jon: "YES THAT WOULD BE SO
// COOL"), in SIMPLIFIED, the look Jon kept from the showcase as direction C,
// "Alive" (scratchpad `showcase/C/sector`): today's layered sky refined and set
// in motion.
//
// THE CLOUD IS AT INFINITY (Jon: "the panning makes sense for the parallax,
// just not the zoom"): its density is baked once a system (`SkyBake.field`,
// `sky_field.gdshader`) and only slides by its share of the pan (`off`).
// THE LIGHT IS NOT: it is worked out here from where the system's sun is on
// screen, in "light px" (screen px over (zoom / the opening zoom)^0.42, times
// the frame's size against the showcase's), so it rides the star on a pan and
// opens out gently on a zoom: gathered round the sun, falling off, lighting the
// side of each billow that faces it, burning on the rims of the dust.
// THE GAS STREAMS: a two-phase flow map carries it along a gentle current with
// eddies, about a block every three seconds, so it churns and never pulses in
// place (held still with reduced motion).
//
//   0 EMISSION   rose hydrogen; round the sun its light has blown a BUBBLE of
//                thin gas glowing oxygen teal, its wall piled-up gas burning
//                pink-white on its inner face; dark pillars rise from a dust
//                bank toward the sun, their star-facing rims alight. The wall
//                sits in an orbit gap at the opening (`bubble_r`) and opens out
//                in light px as the map zooms, as the showcase drew it (anchored
//                to the plane, it filled the screen close in and the thick gas
//                vanished: Jon, "gas disappearing on zoom");
//   1 REFLECTION the same dust lit from outside: blue haze gathered round the
//                sun and fading with its light, white close in, the cloud's own
//                stars lighting their own patches, light shafts turning slowly;
//   2 PLANETARY  the shell's ring arcing across the sky, red at its rim and the
//                cloud's own colour within, its hot white star at the middle;
//   3 REMNANT    tangled filaments everywhere, the shell's arc red outside and
//                teal just within, lit brighter near the sun;
//   4 DARK       dust that hides what is behind it, its body dark brown-violet,
//                its edges toward the light lit, and toward the sun.
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
// The cloud is lit in linear light and tone-mapped hue-keeping (`kitTone`); an
// event's light is added over it as before (`1 - exp(-L * expo)`), so each
// event reads as it was approved; every event term is behind `w_k > 0` or
// `s_k > 0`, so nothing costs anything while the sky is calm.
// It adds light (rgb) and takes away what is behind it (alpha): premultiplied.

uniform int kind = 0;
uniform int shape = 0;
uniform float sd = 0.0;
uniform vec2 off = vec2(0.0);
// seconds on the gas's own slow clock; 0 holds it still (reduced motion)
uniform float time = 0.0;
uniform float strength = 1.0;
// the event light's exposure (as before), and the cloud's (C's tone curve)
uniform float expo = 0.8;
uniform float exposure = 1.0;
uniform float burn = 2.5;
// the cloud's own colour (`NebulaField.Cloud.base_colour`)
uniform vec3 hue = vec3(0.44, 0.88, 0.67);
// THE BAKE (`SkyBake.field`): density, billows and far gas, gradients
uniform sampler2D t0 : filter_linear, repeat_disable;
uniform sampler2D t1 : filter_linear, repeat_disable;
uniform sampler2D t2 : filter_linear, repeat_disable;
uniform vec2 ftex = vec2(576.0, 366.0);
uniform float fmb = 48.0;
// THE SUN: where it is on screen, the map's zoom and the zoom it opened at,
// the frame against the showcase's 960, its light's colour (linear, brightest
// channel 1) and its breath (1 +- 0.06)
uniform vec2 star_at = vec2(480.0, 270.0);
uniform float zoom = 1.0;
uniform float home_zoom = 1.0;
// the zoom the light is worked out at (the map's own: held in 3% steps it
// flickered more, measured, not less)
uniform float lzoom = 1.0;
uniform float lscale = 0.68;
uniform vec3 star_light = vec3(1.0, 0.72, 0.36);
uniform float breath = 1.0;
// the emission bubble's radius on the plane (map px at zoom 1)
uniform float bubble_r = 400.0;
// THE CORE: the hole's disc's outer edge on screen (px), and its flare echo
// (`SkyWeather` `flareecho`: the ring's radius on screen, its strength)
uniform float hole_r = 116.0;
uniform float e_r = 0.0;
uniform float e_k = 0.0;
// the emission cloud's young cluster: the sun's own sky pixel at no pan
uniform vec2 cc_em = vec2(480.0, 270.0);
// GRAPHICS LOW: one read a field, no far gas or veils, no flow
uniform bool low = false;
// PAINTED: the gas drifts in whole blocks instead of streaming -- each layer
// slid along the current by a whole number of blocks, slowly to and fro (the
// near ones further and faster, the far gas least), never blended between
// reads, so the paint pass sees each block step and hold
uniform bool blk_flow = false;
// PAINTED's FORM (`SectorPainted`, round 2): the cloud is painted as masses,
// not posterised. Its colour picks a ramp of the scene's curated palette and a
// place along it; then, where the cloud is thick, it is built of round PUFFS
// (one or two to a cell of the sky, each only where the cloud's own gas is, so
// the weather's shapes stay the cloud's), each lit as a dome by the sun -- its
// side toward the sun a step up, its underside a step down and cooler (the
// ramps run cool to warm) -- so the masses read as painted clouds with lobes,
// their silhouettes puffy; an event's light pushes a step or two up. Out: the
// colour at that place along the ramp, for the band memory to band and hold.
uniform bool painted = false;
uniform sampler2D p_pal : filter_nearest;
uniform vec3 p_lab[64];
uniform int p_grp[64];
uniform int p_ne = 0;
uniform int p_start[12];
uniform int p_len[12];
uniform float p_l0[12];
uniform float p_l1[12];
// the slots: the sky's (thin gas there lets the stars through), the mid gas a
// puff lends its shape to, the weather's
uniform int p_sky = 0;
uniform int p_gm = 1;
uniform int p_ev = -1;
uniform int p_gf = -1;
uniform int p_du = -1;
uniform float p_cb = 1.0;
// puffs on (emission, reflection, dark, core), their cell (sky px), how much
// the cloud's own steps are held down (the core keeps the hole the star)
uniform bool p_puffs = false;
uniform float p_cell = 64.0;
uniform float p_dim = 1.0;
// a puff's steps: base, the sun's light, its gas
uniform vec3 p_k = vec3(0.6, 3.6, 1.2);
// how far the cloud's own light must stand above a puff's to break through (steps)
uniform float p_brk = 0.8;
// THE PAINTED CLOUD'S FORM, B's (`sector_b_puffs`, baked once a system): three gas
// sheets -- far, mid, near -- of domed masses with lumpy lobes on their edges, one
// texel a block in the field bake's frame, stacked; on while baked. Each sheet
// drifts by its own whole blocks. The scene (0 emission, 1 reflection, 3 core,
// 5 dark), the hot zone's ramp, each sheet's look (amb, glow, light: B's
// `lookOf`), and the light (soft and hard radii, the hot zone's, its height; B's
// `LIGHT`, light px)
uniform sampler2D p_sheets : filter_nearest, repeat_disable;
uniform bool p_sheets_on = false;
uniform float p_dust_tau = 0.6;
uniform int p_scene = 0;
uniform int p_go = -1;
uniform vec3 p_look[3];
uniform vec4 p_light = vec4(190.0, 52.0, 80.0, 90.0);
// RADIANT (direction A, "light through gas"; `SystemView`): the cloud is a
// volume the sun shines through. Its light is cut by what stands in its way:
// each world throws a TRUE SHADOW SHAFT through the lit gas -- a dark tapering
// beam running away from the sun, its umbra closing to a point (the sun is
// bigger than the world) inside a widening penumbra, its rings' stripe in it --
// and the dust between a block and the sun dims the light that reaches it, so
// pillars throw long radial streaks; light through dust comes out reddened
// (blue goes first); a flare off the sun lights the gas; a strike's light
// scatters through the cloud round it. Only the sun's light is cut: the gas's
// own glow is not, so a shaft is lit gas going dark, never a grey stroke.
uniform bool radiant = false;
// RADIANT's emission zones (A): teal to violet to rose, in light px; their squash
// across the plane, the noise on them; the light's reach and fall; the glow's gain,
// its power, the gas's gain and the shade's own violet
uniform float r_z0 = 130.0;
uniform float r_z1 = 330.0;
uniform float r_z2 = 520.0;
uniform float r_zsq = 2.3;
uniform float r_zn = 380.0;
uniform float r_o3 = 0.78;
uniform float r_d0 = 320.0;
uniform float r_fp = 0.9;
uniform float r_ek = 2.0;
uniform float r_epow = 0.5;
uniform float r_gk = 1.1;
uniform float r_gbase = 0.3;
uniform float r_pastel = 0.5;
// RADIANT's core: the haze of the galaxy's heart lit by the disc, filling the frame
uniform float r_core_haze = 2.2;
uniform float r_floor = 0.10;
// each world: where it is drawn (screen px), its drawn radius, its true radius
// at this zoom; its rings' outer edge in its radii (0: none)
uniform vec4 r_bodies[24];
uniform float r_rings[24];
uniform int r_nb = 0;
// how much of the sun's light a shaft's umbra takes; a flare's height now
uniform float r_shaft_k = 0.82;
uniform float r_flare = 0.0;
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

#include "res://shaders/sky_noise.gdshaderinc"

const float GK = 4.0;

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

// ---------------------------------------------------------------- the bake, read with flow
vec2 fuv(vec2 sp) { return (sp + fmb * 2.0) / (2.0 * ftex); }
// a gentle current plus two scales of divergence-free eddies (sky px a second)
vec2 flow_vel(vec2 P) {
	vec2 a = P / 230.0, b = kitRot2(P) / 97.0 + 1.7;
	vec2 v1 = vec2(sin(a.x) * cos(a.y), -cos(a.x) * sin(a.y));
	vec2 v2 = vec2(sin(b.x) * cos(b.y), -cos(b.x) * sin(b.y));
	return vec2(0.55, -0.16) + 0.42 * v1 + 0.22 * v2;
}
// two reads carried along the current, crossfaded so neither stretches; the
// crossfade keeps its contrast (two half-weighted reads would blur to the mean)
// PAINTED: a layer's drift in whole blocks (sky px), to and fro
vec2 blk_drift(float speed, float period, float ph0) {
	if (low || time <= 0.0) return vec2(0.0);
	vec2 dir = normalize(vec2(0.55, -0.16));
	float n = round(6.0 * speed * sin(TAU * time / (period * 5.0) + ph0));
	return vec2(round(dir.x * n), round(dir.y * n)) * 2.0;
}
vec4 flowed(sampler2D T, vec2 P, float speed, float period, float ph0, bool keep) {
	if (low || time <= 0.0) return texture(T, fuv(P));
	if (blk_flow) {
		// (the bake's margin is 48 blocks: the furthest any layer goes is 7)
		return texture(T, fuv(P - blk_drift(speed, period, ph0)));
	}
	vec3 ph = kitFlowPhase(time + ph0, period);
	vec2 v = flow_vel(P) * speed;
	float wb = ph.z, wa = 1.0 - wb;
	vec4 a0 = texture(T, fuv(P - v * ph.x * period)), a1 = texture(T, fuv(P - v * ph.y * period));
	if (!keep) return a0 * wa + a1 * wb;
	float g = mix(1.0, inversesqrt(wa * wa + wb * wb), 0.6);
	vec4 m = 0.5 * (a0 + a1);
	return clamp(m + (a0 * wa + a1 * wb - m) * g, 0.0, 1.0);
}

// ---------------------------------------------------------------- the sun's light
// in light px: screen px from the star over (zoom / opening zoom)^0.42, the
// frame's scale against the showcase's; the round glow a little wide (the
// plane is tilted)
// RADIANT: how much of the sun's light the worlds' shadow shafts leave at b
float r_shafts(vec2 px) {
	float k = 1.0;
	for (int i = 0; i < 24; i++) {
		if (i >= r_nb) break;
		vec4 bd = r_bodies[i];
		vec2 away = bd.xy - star_at;
		if (length(away) < 0.5) continue;
		vec2 u = normalize(away);
		vec2 dlt = px - bd.xy;
		float s = dot(dlt, u);
		if (s <= 0.0) continue;
		float r = max(bd.z, 1.0);
		float rt = max(bd.w, 0.5);
		// long (the gas is deep): the umbra closes about fourteen true radii out,
		// the shaft fades by seventy, never shorter than a few drawn radii
		float LU = max(rt * 14.0, r * 2.0);
		float LEN = max(rt * 70.0, r * 9.0);
		if (s >= LEN) continue;
		float w = abs(-dlt.x * u.y + dlt.y * u.x);
		float hu = r * max(0.0, 1.0 - s / LU);
		float hp = r * (1.0 + 0.45 * s / LU);
		if (w >= hp) continue;
		float across = w <= hu ? 1.0 : 0.62 * (1.0 - smoothstep(hu, hp, w));
		float along = s <= r ? 1.0 : pow(clamp(1.0 - (s - r) / (LEN - r), 0.0, 1.0), 1.1);
		float dark = across * along;
		if (r_rings[i] > 0.0) {
			// the rings' shadow: a thin dark stripe across the shaft, and faint wings
			float taper = clamp(s / LU, 0.0, 1.0);
			float rw = r * r_rings[i] * (1.0 - 0.6 * taper);
			float soft = 1.0 + r * (0.06 + 0.22 * taper);
			float wing = (1.0 - smoothstep(rw - soft, rw + soft, w)) * (w > hu ? 1.0 : 0.0);
			dark = max(dark, 0.45 * wing * along);
		}
		k *= 1.0 - r_shaft_k * dark;
	}
	return k;
}
// RADIANT: the dust between sky point sp (block b on screen) and the sun, as
// what of the sun's light gets through it (8 reads, out to 260 px)
float r_rays(vec2 b, vec2 sp) {
	vec2 d = star_at - b;
	float Ld = length(d);
	if (Ld < 4.0) return 1.0;
	float reach = min(Ld, 260.0);
	vec2 st = d / Ld * reach;
	float tau = 0.0;
	for (int k = 1; k <= 8; k++) {
		tau += texture(t0, fuv(sp + st * (float(k) / 9.0))).g;
	}
	return exp(-tau / 8.0 * reach / 40.0);
}

struct Lt { float LZ; float dL; vec2 toSun; float Js; float Jc; float Jw; float att; float sh; };
Lt light_at(vec2 b) {
	Lt l;
	l.att = 1.0;
	l.sh = 1.0;
	if (radiant) {
		l.sh = r_shafts(b);
		l.att = l.sh * ((low || kind > 1) ? 1.0 : r_rays(b, b - off));
	}
	vec2 d = b - star_at;
	l.LZ = pow(max(lzoom, 1e-3) / max(home_zoom, 1e-3), 0.42) * lscale;
	l.dL = length(d * vec2(1.0, 1.15)) / l.LZ;
	l.toSun = -d / max(length(d), 1e-3);
	l.Js = 1.0 / (1.0 + pow(l.dL / 155.0, 2.0)) * mix(1.0, breath, 0.6);
	l.Jc = 1.0 / (1.0 + pow(l.dL / (38.0 * breath), 2.0));
	l.Jw = 0.35 / (1.0 + pow(l.dL / 520.0, 2.0));
	// (a flare lights the gas round, never the glow on the sun's own face: that
	// went to a flat white plate)
	l.Js *= l.att * (1.0 + 0.6 * r_flare);
	l.Jc *= l.att;
	l.Jw *= l.att * (1.0 + 0.6 * r_flare);
	return l;
}

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

// ---------------------------------------------------------------- PAINTED: form
vec3 p_oklab(vec3 c) {
	vec3 l3 = kitToLinear(c);
	float l = pow(max(0.4122214708 * l3.r + 0.5363325363 * l3.g + 0.0514459929 * l3.b, 0.0), 1.0 / 3.0);
	float m = pow(max(0.2119034982 * l3.r + 0.6806995451 * l3.g + 0.1073969566 * l3.b, 0.0), 1.0 / 3.0);
	float s = pow(max(0.0883024619 * l3.r + 0.2817188376 * l3.g + 0.6299787005 * l3.b, 0.0), 1.0 / 3.0);
	return vec3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
}
float p_hash(ivec2 c, int k) {
	uint h = (uint(c.x + 4096) * 374761393u) ^ (uint(c.y + 4096) * 668265263u) ^ (uint(k) * 2246822519u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}
// the cloud's gas at sky point P, for a puff to stand on
float p_gas(vec2 P) {
	vec4 a = texture(t0, fuv(P));
	return a.r;
}
// THE PUFF OVER sky point P: its height (0: none), its normal, how thick its gas
float p_puff(vec2 P, out vec3 nrm, out float dens) {
	nrm = vec3(0.0, 0.0, 1.0);
	dens = 0.0;
	float best = 0.0;
	vec2 q = P / p_cell;
	ivec2 ci = ivec2(floor(q));
	for (int dy = -1; dy <= 1; dy++) {
		for (int dx = -1; dx <= 1; dx++) {
			ivec2 cc = ci + ivec2(dx, dy);
			for (int k = 0; k < 2; k++) {
				vec2 c = (vec2(cc) + 0.15 + 0.7 * vec2(p_hash(cc, k * 3), p_hash(cc, k * 3 + 1))) * p_cell;
				float g = p_gas(c);
				if (g < 0.22) continue;
				vec2 d = P - c;
				float an = atan(d.y, d.x);
				float h3 = p_hash(cc, k * 3 + 2);
				// lumpy round its edge, bigger where the gas is thicker
				float R = p_cell * (0.42 + 0.30 * h3) * (0.65 + 0.55 * smoothstep(0.22, 0.75, g))
					* (1.0 + 0.10 * sin(an * 5.0 + h3 * 31.0) + 0.06 * sin(an * 9.0 + h3 * 17.0));
				float r = length(d) / R;
				if (r >= 1.0) continue;
				float z = sqrt(1.0 - r * r) * R + g * 60.0;
				if (z > best) {
					best = z;
					nrm = normalize(vec3(d / R, sqrt(1.0 - r * r)));
					dens = g;
				}
			}
		}
	}
	return best;
}
// the colour at `lv` steps along slot `g` (between two steps: the band memory bands it)
vec3 p_ramp(int g, float lv) {
	int n = p_len[g];
	float x = clamp(lv, 0.0, float(n - 1));
	int i = int(floor(x));
	vec3 a = texelFetch(p_pal, ivec2(p_start[g] + i, 0), 0).rgb;
	vec3 b2 = texelFetch(p_pal, ivec2(p_start[g] + min(i + 1, n - 1), 0), 0).rgb;
	return mix(a, b2, x - float(i));
}
// a sheet of B's form at sky point P: (height / 2 cell, normal xy, detail)
vec4 p_sheet(int k, vec2 P) {
	vec2 d = k == 0 ? blk_drift(0.30, 40.0, 0.0) : (k == 1 ? blk_drift(0.55, 30.0, 1.3) : (k == 2 ? blk_drift(0.95, 22.0, 2.6) : blk_drift(0.65, 24.0, 0.0)));
	ivec2 t = ivec2(floor((P - d + fmb * 2.0) * 0.5));
	t = clamp(t, ivec2(0), ivec2(ftex) - 1);
	return texelFetch(p_sheets, ivec2(t.x, t.y + k * int(ftex.y)), 0);
}
// a 50% / 75% coverage pattern anchored to the sheet (no alpha, ever)
bool p_pat(vec2 P, float c) {
	ivec2 q = ivec2(floor((P + fmb * 2.0) * 0.5));
	int i = (q.x & 1) + 2 * (q.y & 1);
	return c >= 0.74 ? i != 3 : (i == 0 || i == 3);
}
vec4 paint_cloud(vec3 c0, float alpha, vec3 Lev, vec2 sp, vec2 toSun, vec4 G, float Js, float tau, float dL) {
	// the shells and the strands (planetary, remnant) keep their own drawing, for
	// the band memory to band; an event's light half again as strong, so it reads
	// a band or two up
	if (!p_puffs) {
		vec3 c = vec3(1.0) - (vec3(1.0) - c0) * exp(-Lev * expo * 1.8);
		return vec4(c, alpha);
	}
	// THE RAMP AND THE PLACE ON IT the cloud's own colour gives
	vec3 lab = p_oklab(c0);
	vec3 lb = vec3(lab.x, lab.yz * mix(1.0, p_cb, smoothstep(0.16, 0.34, lab.x)));
	int best = 0;
	float bd = 1e9;
	for (int i = 0; i < 64; i++) {
		if (i >= p_ne) break;
		vec3 dd = (lb - p_lab[i]) * vec3(1.0, 1.35, 1.35);
		float e = dot(dd, dd);
		if (e < bd) { bd = e; best = i; }
	}
	int g = p_grp[best];
	float steps = float(p_len[g] - 1);
	float lv = clamp((lab.x - p_l0[g]) / max(p_l1[g] - p_l0[g], 1e-3), 0.0, 1.0) * steps * p_dim;
	float stp = 0.0;
	bool solid = g != p_sky;
	// B'S FORM: the gas built of its three sheets (the weather's light and the dust
	// keep theirs). Near over mid over far; each lit as B lights it and banded on its
	// ramp in whole steps, so its band edges are the domes' and lobes' round ones
	// (only the thick dust, the pillars and the banks, is drawn as dust: the thin
	// lanes cut the masses into plates with dark slashes)
	bool dusty = p_du >= 0 && g == p_du && tau >= p_dust_tau;
	vec4 Dk = vec4(0.0);
	if (p_sheets_on) {
		// (B's form: the dust its own sheet, smoothed; it stands over the gas)
		Dk = p_sheet(3, sp);
		dusty = p_du >= 0 && Dk.r >= p_dust_tau;
	}
	if (p_sheets_on && dusty) {
		// THE DUST, as B paints it: an opaque silhouette, its body dark, lit dust just
		// inside the edge that faces the star, its far edge the darkest step (B's
		// `dust`), so a pillar reads as one shape, not posterised murk
		vec2 no = Dk.gb * 2.0 - 1.0;
		float face = dot(no, toSun);
		float Is = 1.0 / (1.0 + pow(dL / p_light.x, 2.0));
		// (one body step; only a thin lip lit, a thin far edge dark: a wide lit band
		// followed the dust's fine noise and came out jagged)
		// (the lip by where the dust's edge is, a few blocks out along its normal: by
		// its density a bank's slow edge lit as a wide plate)
		bool out2 = p_sheet(3, sp + no * 4.0).r < p_dust_tau;
		bool out4 = p_sheet(3, sp + no * 8.0).r < p_dust_tau;
		int bi = 1;
		if (face > 0.3 && out2) bi = Is > 0.08 ? 3 : 2;
		else if (face > 0.5 && out4 && Is > 0.08) bi = 2;
		if (face < -0.2 && out2) bi = 0;
		// (the core's lanes are lit through: warm brown, never black cracks; B's)
		if (p_scene == 3) bi = max(bi, 2);
		g = p_du;
		lv = float(min(bi, p_len[g] - 1));
		steps = float(p_len[g] - 1);
		solid = true;
	} else if (p_sheets_on) {
		float Is = 1.0 / (1.0 + pow(dL / p_light.x, 2.0));
		float Ih = 1.0 / (1.0 + pow(dL / p_light.y, 2.0));
		float I = 0.5 * Is + 0.5 * Ih;
		vec3 L3 = normalize(vec3(toSun * dL, p_light.w));
		int top = -1;
		vec4 T = vec4(0.0);
		for (int k = 2; k >= 0; k--) {
			vec4 t = p_sheet(k, sp);
			float S = k == 0 ? 96.0 : (k == 1 ? 64.0 : 48.0);
			float Hp = t.r * 2.0 * S;
			if (Hp <= 0.0) continue;
			// thin gas at a mass's edge: a pattern over what lies behind
			if (Hp < 0.1 * S && !p_pat(sp, k == 0 ? 0.75 : 0.5)) continue;
			if (Hp < 0.05 * S && !p_pat(sp, 0.5)) continue;
			// the star has blown a cavity: near it only the thick gas stands
			if (k > 0 && (p_scene == 0 || p_scene == 1)) {
				float er = S * (k == 2 ? 1.25 : 0.95) * (1.0 - smoothstep(0.35, 1.25, dL / p_light.z)) * (0.62 + 0.76 * t.a);
				if (Hp < er) continue;
				if (Hp < er + 0.06 * S && !p_pat(sp, 0.5)) continue;
			}
			top = k;
			T = t;
			break;
		}
		if (top < 0) {
			// no gas here: the sky behind (an event's light still shows)
			solid = false;
			g = p_sky;
			lv = 0.0;
		} else {
			float S = top == 0 ? 96.0 : (top == 1 ? 64.0 : 48.0);
			float Hp = T.r * 2.0 * S;
			vec3 n = vec3(T.g * 2.0 - 1.0, T.b * 2.0 - 1.0, 0.0);
			n.z = sqrt(max(0.0, 1.0 - dot(n.xy, n.xy)));
			float det = T.a;
			float shade = low && top == 0 ? 0.6 : max(dot(n, L3), 0.0);
			vec3 lk = p_look[top];
			float thick = clamp(Hp / (0.9 * S), 0.0, 1.0);
			float lvB = (lk.y * (0.66 + 0.34 * shade) + lk.z * I * (lk.x + (1.0 - lk.x) * shade)) * (0.72 + 0.34 * thick)
				+ (top == 0 ? (det - 0.3) * 0.2 : max(det - 0.5, 0.0) * 0.7 - 0.01);
			g = top == 0 && p_gf >= 0 ? p_gf : p_gm;
			int nn = p_len[g];
			int cap = nn - 1;
			// THE HOT ZONE (emission): OIII where the star's light is hardest, on the
			// faces it lights; the far sheet behind the cavity in teal rings round it
			if (p_scene == 0 && p_go >= 0) {
				float c = (1.0 + 0.7 * ((top == 0 ? det : det + 0.5 * (0.5 - clamp(Hp / (1.4 * S), 0.0, 1.0))) - 0.5)) * (1.55 - 0.9 * (top == 0 ? 0.5 : shade));
				if (dL * c < p_light.z) {
					g = p_go;
					nn = p_len[g];
					if (top == 0) {
						float lf = Ih + 0.34 * (det - 0.5);
						lvB = lf > 0.74 ? 0.9 : (lf > 0.44 ? 0.6 : (lf > 0.22 ? 0.35 : 0.1));
						cap = nn - 1;
					} else {
						cap = det > 0.7 ? nn - 1 : nn - 2;
						lvB -= 0.16 + 0.42 * max(0.0, 0.62 - shade);
					}
				}
			} else if (p_scene == 1 && top == 0 && dL < p_light.z * 1.3) {
				// (reflection: the far side of the hollow in blue rings round the star)
				g = p_gm;
				nn = p_len[g];
				cap = nn - 1;
				float lf = Ih + 0.34 * (det - 0.5);
				lvB = lf > 0.74 ? 0.9 : (lf > 0.48 ? 0.72 : (lf > 0.26 ? 0.55 : 0.4));
			}
			int bi = min(int(floor(clamp(lvB, 0.0, 0.9999) * float(nn))), cap);
			// (the far sheet's darkest step only at its outer edge: a pinch inside a mass
			// drew black blades in the cloud)
			if (top == 0 && bi == 0) {
				bool edge = p_sheet(0, sp + vec2(6.0, 0.0)).r <= 0.0 || p_sheet(0, sp - vec2(6.0, 0.0)).r <= 0.0
					|| p_sheet(0, sp + vec2(0.0, 6.0)).r <= 0.0 || p_sheet(0, sp - vec2(0.0, 6.0)).r <= 0.0;
				if (!edge) bi = 1;
			}
			// the near sheets' lowest step: a pattern over what lies behind
			if (bi == 0 && top > 0 && !p_pat(sp, top == 2 ? 0.5 : 0.75)) {
				g = p_gf >= 0 ? p_gf : g;
				bi = 1;
			}
			lv = float(bi);
			steps = float(p_len[g] - 1);
			solid = true;
			// (where the cloud's own light stands well above -- an event, the disc's
			// flare -- it breaks through, steps up)
			if (e_k > 0.0) {
				float lvC = clamp((lab.x - p_l0[g]) / max(p_l1[g] - p_l0[g], 1e-3), 0.0, 1.0) * steps;
				lv = max(lv, round(lvC - mix(p_brk, 0.6, clamp(e_k * 2.0, 0.0, 1.0))));
			}
		}
	}
	// THE PUFFS: round lobes lit as domes by the sun
	else if (p_puffs && !low) {
		vec3 n;
		float dens;
		vec2 P = sp - blk_drift(0.65, 24.0, 0.0);
		float hgt = p_puff(P, n, dens);
		vec3 L3 = normalize(vec3(toSun * 0.85, 0.55));
		// (dark wine is dust only where the cloud has dust: elsewhere it is thin gas)
		bool gasy = g == p_gm || g == p_gf || g == p_sky || (g == p_du && tau < 0.3);
		if (hgt > 0.0 && gasy) {
			// THE MID LAYER: a lit puff of the mid gas, its steps set by the sun's
			// light on it and how thick its gas is, its dome's side toward the sun a
			// step up and its underside a step down (the ramp runs cool to warm)
			float lam = dot(n, L3);
			stp = lam > 0.5 ? 1.0 : (lam > -0.1 ? 0.0 : -1.0);
			g = p_gm;
			steps = float(p_len[g] - 1);
			lv = clamp(p_k.x + p_k.y * Js + p_k.z * smoothstep(0.22, 0.8, dens), 0.0, steps) * p_dim;
			// (and where the cloud's own light is well above the puff's -- an event lighting
			// the gas, the disc's flare -- it breaks through, steps up)
			float lvC = clamp((lab.x - p_l0[g]) / max(p_l1[g] - p_l0[g], 1e-3), 0.0, 1.0) * steps * p_dim;
			// (the core's flare echo lights its gas: then it may)
			lv = max(lv, lvC - mix(p_brk, 0.6, clamp(e_k * 2.0, 0.0, 1.0)));
			solid = true;
		} else if (hgt > 0.0) {
			// the hot zone and the dust: their own steps, the dome's light on them
			float lam = dot(n, L3);
			stp = lam > 0.55 ? 1.0 : (lam > -0.15 ? 0.0 : -1.0);
		} else if (gasy && g != p_sky) {
			// THE FAR LAYER: between the puffs, the far gas, cooler and paler and
			// lower in contrast (aerial perspective): its steps squeezed to the
			// middle of its ramp
			g = p_gf >= 0 ? p_gf : g;
			steps = float(p_len[g] - 1);
			lv = clamp(0.8 + 0.45 * clamp((lab.x - p_l0[g]) / max(p_l1[g] - p_l0[g], 1e-3), 0.0, 1.0) * steps, 0.0, steps);
		}
	}
	// AN EVENT'S LIGHT a step or two up its ramp, its brightest in the weather's own
	float el = dot(Lev, vec3(0.299, 0.587, 0.114));
	stp += round(clamp(el * 3.0, 0.0, 3.0));
	vec3 col = p_ramp(g, lv + stp);
	if (p_ev >= 0 && el > 0.45) col = p_ramp(p_ev, (el - 0.45) * 4.0);
	// (B's form: no sheet here is no gas -- SIMPLIFIED's thin strands are not drawn)
	// (with the sheets on, between the clouds is clear sky: the far darkness, the
	// stars through it; the sky bake's own stringy gas there set in jagged plates)
	if (!solid && el < 0.1) return p_sheets_on ? vec4(p_ramp(p_sky, 0.0), 0.86) : vec4(c0, alpha);
	return vec4(col, 1.0);
}

void fragment() {
	vec2 px = floor(UV * vec2(960.0, 540.0));
	vec2 b = px - mod(px, 2.0) + 1.0;
	vec2 sp = b - off;
	vec2 u = sp / 430.0 + vec2(sd * 1.7, sd * 0.9);
	Lt lt = light_at(b);
	float Js = lt.Js, Jc = lt.Jc;
	vec2 toSun = lt.toSun;
	// THE CLOUD HERE, carried along its current
	vec4 A = flowed(t0, sp, 0.65, 24.0, 0.0, true);
	vec4 G = (flowed(t2, sp, 0.65, 24.0, 0.0, false) - 0.5) / GK;
	vec4 B1 = flowed(t1, sp, 0.65, 24.0, 0.0, false);
	float bil = B1.r, fine = B1.g;
	float far = low ? 0.4 : flowed(t1, sp, 0.35, 30.0, 9.0, false).b;
	float veil = low ? 0.0 : flowed(t1, sp, 1.1, 18.0, 4.0, false).a;
	// what the cloud lights, in linear light (H, tone-mapped), what it lets
	// through of the stars behind it (trans), and the old way's light on top
	// (Lev, events and the kinds that kept their look: `1 - exp(-L * expo)`)
	vec3 H = vec3(0.0);
	float trans = 1.0;
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
		// EMISSION: the cloud from inside, its young cluster the system's sun
		float gB = A.r, tau = A.g, body = A.b;
		vec2 dc = sp - cc_em;
		float r = length(dc) / 720.0;
		float hv = sat((fine - 0.5) * 2.2 + 0.5);
		vec3 rose = mix(mix(HA, vec3(1.0, 0.14, 0.40), sat(hv * 1.6 - 0.5)), vec3(1.0, 0.26, 0.20), sat(0.6 - hv * 1.5));
		// THE BUBBLE: a sphere round the sun on the plane, ragged by direction,
		// its wall puffed by the cloud's own lumps; distances across it in light px
		vec2 ds = (b - star_at) * vec2(1.0, 1.15);
		vec2 dirB = normalize(ds + vec2(1e-4, 0.0));
		// (the wall opens out in light px, as the showcase drew it: anchored to the
		// plane it filled the screen at a close zoom and the thick gas vanished)
		float Rw = bubble_r * home_zoom * pow(max(zoom, 1e-3) / max(home_zoom, 1e-3), 0.42) * (1.0 + 0.16 * kitSnoise2(dirB * 1.1 + vec2(7.0, 0.3)) + 0.045 * kitSnoise2(dirB * 2.9 + vec2(3.0, 1.1)));
		float xb = (length(ds) - Rw) / lt.LZ + 24.0 * (gB - 0.4);
		// A NEW STAR (SP): its ionisation bubble clears the lane inside it
		bool ns = wa && w_ev == 3 && wr < w_size + 25.0;
		float bub = 0.0, nR = 0.0;
		if (ns) {
			bub = env(w_age - 1.5, 1.5, 11.0, 8.0) * w_k;
			nR = w_size * (1.0 - exp(-max(w_age - 1.5, 0.0) / 3.5));
			tau *= 1.0 - 0.7 * bub * sm(nR, 0.8 * nR, wr);
		}
		float inside = 1.0 - smoothstep(-30.0, 12.0, xb);
		float wallA = smoothstep(-0.55, 0.3, kitSnoise2(dirB * 1.7 + vec2(2.0, 5.0)) + 0.2);
		float wall = exp(-pow((xb - 8.0) / 40.0, 2.0)) * (0.30 + 0.70 * wallA);
		// radial streaks of the star's wind in the thin gas, churning slowly
		float streak = kitSnoise2(dirB * 6.5 + vec2(lt.dL / 230.0 - time * 0.004, sd)) * 0.5 + 0.5;
		float innerG = 0.05 + 0.24 * gB + 0.20 * streak * streak * smoothstep(20.0, 110.0, lt.dL);
		float g = mix(gB, innerG, inside) + wall * (0.50 + 0.45 * gB);
		float front = exp(-pow((xb + 12.0) / 17.0, 2.0)) * (0.30 + 0.70 * wallA) * (0.55 + 0.6 * gB);
		// the gas lit from the star's side: a soft wrap (gas, not rock)
		vec3 n = normalize(vec3(-G.xy * 18.0, 1.0));
		float face = sat(dot(n, normalize(vec3(toSun, 0.6))));
		float wrap = 0.55 + 0.6 * face;
		float ge = g * g;
		// OIII: the thin gas inside the bubble, ionised hardest, falling off hard
		float ion0 = inside * (1.0 - smoothstep(0.62, 1.10, g)) * (1.0 - 0.85 * sat(front * 1.6));
		float ion = smoothstep(0.22, 0.78, ion0);
		float Js4 = Js * Js * Js * Js;
		vec3 selfC = rose * (0.015 * g + 0.24 * ge) * (1.0 - 0.85 * ion);
		vec3 roseL = rose * vec3(1.0, 0.78, 0.82);
		vec3 litC = roseL * (0.25 * g + ge) * (Js * 1.35 + lt.Jw * 1.15) * wrap * (1.0 - 0.92 * ion)
			+ O3 * (0.10 + 0.6 * g + 1.0 * ge) * Js4 * ion * 4.0 + O3 * 0.010 * (0.3 + g) * ion
			// (the light close round the sun stays teal-white and gathered: a wide pale
			// disc there was a pastel plateau the sun sat on)
			+ mix(vec3(0.50, 1.0, 0.90), vec3(1.0, 0.95, 0.85), Jc * Jc) * (Jc * 0.32 + 0.20 / (1.0 + pow(lt.dL / 45.0, 2.0))) * (0.10 + 0.6 * g) * (1.0 - 0.5 * front)
			+ mix(vec3(1.0, 0.26, 0.40), vec3(1.0, 0.70, 0.78), sat(Js * 1.3 - 0.25)) * front * Js * 2.0
			+ vec3(1.0, 0.85, 0.65) * Jc * Jc * Jc * (0.2 + g) * 0.45;
		// far gas: deeper and cooler, seen through the gaps
		vec3 farC = mix(vec3(0.15, 0.022, 0.085), vec3(0.06, 0.025, 0.12), hv) * 0.5 * far * far * (1.0 - 0.8 * sat(g * 1.4)) * (1.0 - 0.6 * inside);
		// the dust: dark wine (never the void), faintly lit on its star side, its
		// outer skin catching the light as a rim
		float T = exp(-tau * 3.6);
		vec2 gd = G.zw;
		float dl = length(gd);
		vec3 dn = normalize(vec3(-gd * 30.0, 1.0));
		float dface = sat(dot(dn, normalize(vec3(toSun, 0.5))));
		float skin = smoothstep(0.02, 0.16, tau) * (1.0 - smoothstep(0.30, 0.62, tau));
		float rimF = pow(sat(dot(gd / max(dl, 1e-5), -toSun) * 0.65 + 0.32), 1.6);
		float rim = skin * rimF * smoothstep(0.03, 0.07, dl) * smoothstep(0.10, 0.4, Js);
		vec3 dustC = vec3(0.024, 0.008, 0.020) + rose * 0.03 * ge * (1.0 - ion) + vec3(0.17, 0.035, 0.055) * Js * pow(dface, 1.5) * 0.55;
		vec3 rimC = mix(vec3(1.0, 0.36, 0.42), vec3(1.0, 0.80, 0.68), sat(Js * 0.9 + Jc * 1.6)) * (0.05 + 1.5 * Js + 1.6 * Jc);
		selfC += rose * veil * 0.09 * (0.25 + g) * (1.0 - ion);
		litC += mix(rose, O3, ion) * veil * Js * 0.30;
		// (RADIANT: what shows through the dust reddened, blue going first)
		vec3 Tr = radiant ? exp(-tau * 3.6 * vec3(0.62, 0.80, 1.0)) : vec3(T);
		H = (selfC + farC) * Tr + dustC * (1.0 - T) + litC * Tr + rimC * rim;
		// the cloud's darkest is deep wine, never the void
		H = max(H, vec3(0.0085, 0.0028, 0.0065));
		// (the gas hides the stars behind it, as the showcase's did: let through at
		// half and more, the thick masses were dusted all over with stars)
		trans = T * (1.0 - 0.85 * sat(g * 1.6));
		if (radiant) {
			// RADIANT (A, "light through gas"): no cavity; the cloud is a volume all
			// round the sun, glowing as the light that reaches it ionises it -- OIII
			// teal close in, through violet, to H-alpha rose far out (the zones in
			// the plane, so flattened as the plane is seen), its gas in shade keeping
			// a dim violet light of its own, so nothing is black
			// (the zones on the cloud itself, about where the sun stands on it at the
			// opening -- they slide with the cloud's own share of a pan. Anchored to the
			// sun's place on screen they swept across the slow gas as the map panned,
			// and the cloud read as sliding the wrong way: Jon's "opposite")
			vec2 sun_sky = cc_em;
			vec2 dz = (sp - sun_sky) * vec2(1.0, r_zsq);
			float xz = length(dz) / lt.LZ + (fine - 0.5) * r_zn;
			float dS = length((sp - sun_sky) * vec2(1.0, 1.15)) / lt.LZ;
			// (the OIII paled toward white close in, as A's near gas: a vivid teal there
			// read as SIMPLIFIED's bubble)
			vec3 o3A = mix(vec3(0.2, 0.95, 0.85), vec3(0.55, 0.78, 1.0), r_pastel) * r_o3;
			vec3 emA = mix(mix(o3A, vec3(0.40, 0.22, 1.0), smoothstep(r_z0, r_z1, xz)), vec3(1.0, 0.2, 0.3), smoothstep(r_z1, r_z2, xz));
			float FA = pow(r_d0 * r_d0 / (r_d0 * r_d0 + dS * dS), r_fp);
			// (a volume: the gas along the whole ray, so thin places still glow; only
			// the dust's lanes go dark)
			float gv = sat(r_gbase + gB * r_gk);
			vec3 EA = gv * (emA * FA * pow(max(gv, 1e-3), r_epow) * r_ek + vec3(0.42, 0.14, 0.62) * r_floor * (0.4 + 0.6 * gv));
			// the corona: the near gas lit hard, gathered tight round the sun (A's is
			// a thin warm glow; a wide pale disc read as a halo ring)
			vec3 cor = vec3(1.0, 0.85, 0.65) * Jc * Jc * Jc * (0.2 + gv) * 0.30;
			H = EA * Tr + cor + dustC * (1.0 - T) + rimC * rim;
			trans = T * (1.0 - 0.97 * sat(gv * 4.0));
		}
		dens = body;
		float glow = body * (0.3 + 0.65 * fine) + exp(-r * r / 0.09) * (0.45 + 0.6 * fine) * 0.9;
		dk = 1.0 - T;
		// THE TIDE: a teal front washing out from the bubble's wall through the
		// rose, lighting the thick gas as it passes, and back
		if (wa && w_ev == 1) {
			float dS = length(ds);
			float tR = Rw * (0.85 + 0.9 * (1.0 - pow(1.0 - clamp(w_age / 9.0, 0.0, 1.0), 2.0)));
			float te = env(w_age, 1.5, 6.5, 2.0) * w_k;
			float tw = 60.0 * lt.LZ;
			float thick = sm(0.15, 0.6, gB * T);
			float tband = exp(-pow((dS - tR) / tw, 2.0)) * te * thick * (1.0 - inside * 0.7);
			L += O3 * (0.35 + gB) * tband * 0.8 * gk;
			// its thin brighter lip, just ahead of it (14 px wide, so the dither
			// under it does not blip along the front)
			L += O3 * (0.2 + gB) * 0.18 * exp(-pow((dS - tR - tw * 0.7) / (14.0 * lt.LZ), 2.0)) * te * thick;
		}
		// young stars glinting round the cluster, a block each
		if (r < 0.5) {
			bool gl = hash2(b * 0.5 + vec2(sd * 91.0, 3.0)) > 0.993;
			if (gl) L += STAR * 1.6 * (1.0 - r / 0.5) * T;
			// GLINTS (S): one after another in a wave out from the middle, each a faint plus
			if (wb && s_ev == 1) {
				float t0g = r * 720.0 / 90.0 + hash2(b * 0.5 + vec2(sd * 91.0, 7.0)) * 0.4;
				float gg = sm(t0g, t0g + 0.1, s_age) * (1.0 - sm(t0g + 0.25, t0g + 0.65, s_age)) * s_k;
				if (gl) {
					L += STAR * 1.6 * gg;
				} else if (gg > 0.0) {
					float nb = 0.0;
					if (hash2((b + vec2(2.0, 0.0)) * 0.5 + vec2(sd * 91.0, 3.0)) > 0.993) nb = 1.0;
					if (hash2((b - vec2(2.0, 0.0)) * 0.5 + vec2(sd * 91.0, 3.0)) > 0.993) nb = 1.0;
					if (hash2((b + vec2(0.0, 2.0)) * 0.5 + vec2(sd * 91.0, 3.0)) > 0.993) nb = 1.0;
					if (hash2((b - vec2(0.0, 2.0)) * 0.5 + vec2(sd * 91.0, 3.0)) > 0.993) nb = 1.0;
					L += mix(STAR, O3, 0.5) * 0.45 * gg * nb;
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
					* (1.0 - sm(10.0, 14.0, a)) * (0.35 + 0.65 * T) * w_k * gk;
			}
		}
		// THE NEW STAR's light: teal near it, rose further out, a torn bright rim
		if (ns) {
			vec3 Bn = O3 * exp(-wr / 30.0) * 0.5
				+ HA * sm(0.4 * nR, nR, wr) * (1.0 - sm(nR, nR + 3.0, wr)) * (0.3 + body) * 0.6
				+ vec3(1.0, 0.85, 0.8) * exp(-pow((wr - nR - 12.0 * (fine - 0.5) - 8.0 * (bil - 0.5)) / 3.0, 2.0)) * (0.4 + body) * 0.8
					* sm(0.35, 0.65, fine + 0.35 * body);
			L += Bn * bub * gk;
			float st = env(w_age, 1.5, 16.5, 4.0) * w_k;
			if (wr < 1.5) L += STAR * 6.0 * st;
			else if (wr < 3.5 && min(abs(wd.x), abs(wd.y)) < 1.0) L += STAR * 1.8 * st;
		}
	} else if (kind == 1) {
		// REFLECTION: the same dust lit from outside. Blue haze gathers round the
		// sun and fades with its light; the cloud's own few stars light their own
		// patches; dark lanes and pillars stand against the haze, rimmed blue-white
		float g = A.r, tau = A.g;
		float stri = 0.65 + 0.55 * A.b;
		// scattered light falls off faster than an emission cloud's glow: far from
		// the sun the cloud is a deep navy (a haze lit evenly was dull periwinkle)
		Js = 1.0 / (1.0 + pow(lt.dL / 100.0, 2.0)) * mix(1.0, breath, 0.6) * lt.att;
		float hv = sat((fine - 0.5) * 2.2 + 0.5);
		vec3 n = normalize(vec3(-G.xy * 10.0, 1.0));
		float face = sat(dot(n, normalize(vec3(toSun, 0.6))));
		float wrap = 0.6 + 0.5 * face;
		vec3 blue = mix(BLU, vec3(0.26, 0.40, 1.0), sat(hv * 1.4 - 0.4));
		float ge = g * g;
		float haze = 0.1 + 0.6 * sm(0.2, 0.75, bil);
		vec3 selfC = vec3(0.022, 0.030, 0.095) * (0.3 * g + ge) * 0.7;
		// close to the star the scattered light is white, turning blue as it spreads
		vec3 nearC = mix(vec3(0.50, 0.70, 1.0), vec3(0.90, 0.93, 1.0), sat(Jc * Jc * 1.25));
		// (the haze close round the sun kept from saturating to a pale disc)
		vec3 litC = blue * (0.05 + 0.45 * g + 0.6 * ge) * (Js * 1.3 * (1.0 - 0.35 * Jc) + lt.Jw * 0.10) * wrap * (0.80 + 0.35 * stri)
			+ nearC * Jc * Jc * (0.2 + g) * 0.35;
		vec3 farC = vec3(0.015, 0.02, 0.065) * far * far * (1.0 - 0.7 * sat(g * 1.4));
		float T = exp(-tau * 3.4);
		vec2 gd = G.zw;
		float dl = length(gd);
		vec3 dn = normalize(vec3(-gd * 30.0, 1.0));
		float dface = sat(dot(dn, normalize(vec3(toSun, 0.5))));
		float skin = smoothstep(0.02, 0.16, tau) * (1.0 - smoothstep(0.30, 0.62, tau));
		float rimF = pow(sat(dot(gd / max(dl, 1e-5), -toSun) * 0.65 + 0.32), 1.6);
		float rim = skin * rimF * smoothstep(0.03, 0.07, dl) * smoothstep(0.10, 0.4, Js);
		vec3 dustC = vec3(0.012, 0.014, 0.034) + blue * 0.05 * Js * dface * dface;
		selfC += vec3(0.10, 0.16, 0.40) * veil * 0.03;
		litC += blue * veil * Js * 0.30;
		// drifting light shafts from the sun, in the haze only; read on the circle
		// (no seam), turning slowly
		float ca = cos(time * 0.01), sa = sin(time * 0.01);
		vec2 dv = -toSun;
		vec2 dr = vec2(dv.x * ca - dv.y * sa, dv.x * sa + dv.y * ca);
		float shv = kitSnoise2(dr * 3.2 + vec2(3.0, 1.0)) * 0.5 + 0.5;
		float shaft = smoothstep(0.58, 0.85, shv) * sat(g * 1.4) * Js * smoothstep(30.0, 140.0, lt.dL);
		litC += vec3(0.45, 0.65, 1.0) * shaft * 0.22;
		vec3 Tr = radiant ? exp(-tau * 3.4 * vec3(0.62, 0.80, 1.0)) : vec3(T);
		H = (selfC + farC) * Tr + dustC * (1.0 - T) + litC * Tr + vec3(0.62, 0.80, 1.0) * rim * (0.05 + 1.5 * Js + 1.6 * Jc);
		H = max(H, vec3(0.0030, 0.0040, 0.0120));
		trans = T * (1.0 - 0.8 * sat(g * 1.6));
		dk = 1.0 - T;
		// THE CLOUD'S OWN STARS, each lighting its patch of the haze
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
			vec2 drr = vec2(dir.x * cos(rt) - dir.y * sin(rt), dir.x * sin(rt) + dir.y * cos(rt));
			float ray = pow(fbm(drr * 3.2 + vec2(float(k) * 5.0, sd), 3), 3.0) * 2.4;
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
				echo = mix(BLU, STAR, 0.6) * ring * haze * (0.4 + 1.6 * pow(A.a, 2.0)) * w_k * 2.0 * gk
					* (1.0 - 0.55 * sm(0.4, 0.7, haze));
			}
		}
		// the cloud's own stars and their light, at half the old strength: the sun
		// lights the haze now
		L = (BLU * haze * stri * 0.10 * min(lit, 1.5) + mix(BLU, STAR, 0.4) * shafts * 0.12 * haze) * T + sparks
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
		float clump = 0.45 + 0.9 * pow(A.b, 1.5);
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
		// SIMPLIFIED (C): the shell lit from within by its hot star -- gathered light
		// falling off from it -- oxygen teal in the hollow and on the shell's inner
		// face, the cloud's own colour in the shell's body, a thin hydrogen-red rim
		// outside; cometary knots along the inner rim, dark heads with their tips
		// lit toward the star, giving the shell its depth
		vec3 hueL = kitToLinear(hue);
		float Jp = 1.0 / (1.0 + pow(r0 / (0.42 * R0), 2.0));
		vec3 innerC = mix(O3, hueL * 1.6, 0.35);
		float shellD = (band * 0.95 + ring * 0.35) * clump;
		H = innerC * (fill * 0.30 * (0.3 + bil) + shellD * 0.55) * (0.30 + 1.5 * Jp)
			+ mix(hueL * 1.4, HA * vec3(1.0, 0.85, 0.9), 0.8) * rim * clump * 1.7 * (0.5 + Jp)
			+ mix(hueL, HA, 0.5) * outer * (0.5 + fine) * 0.22
			+ innerC * veil * 0.05 * (0.3 + Jp) + hueL * 0.012 * far * far;
		float ang = atan(dd.y, dd.x), kd = 0.0, kl = 0.0;
		float bin0 = floor(ang / 0.045);
		for (int j = -1; j <= 1; j++) {
			float bin = bin0 + float(j);
			if (hash2(vec2(bin, sd * 5.0 + 3.0)) <= 0.92) continue;
			float ak = (bin + 0.5) * 0.045;
			float rk = (0.90 + 0.06 * hash2(vec2(bin, sd * 5.0 + 4.0))) * R0;
			vec2 rad = vec2(cos(ak), sin(ak));
			vec2 v = dd - rad * rk;
			float along = dot(v, rad), across = cross2(v, rad);
			// a head and a tail streaming outward, away from the star
			float ks = 0.6 + 0.8 * hash2(vec2(bin, sd * 5.0 + 6.0));
			float head = exp(-(along * along + across * across) / (8.0 * ks));
			float tail = exp(-pow(across / (1.5 + 0.05 * max(along, 0.0)), 2.0)) * sm(0.0, 3.0, along) * (1.0 - sm(10.0, 22.0, along));
			kd = max(kd, max(head, tail * 0.7));
			kl = max(kl, exp(-pow(along + 2.5, 2.0) / 3.0 - across * across / 6.0));
		}
		H = H * (1.0 - 0.85 * kd) + mix(O3, vec3(1.0, 0.95, 0.9), 0.5) * kl * (0.06 + 0.6 * Jp) * (0.4 + clump);
		L = vec3(1.0, 0.55, 0.4) * knots * 1.6 + STAR * star + EL;
		dens = max(ring, fill);
		// the system's sun lights the shell's gas round it, in its own light
		H += hueL * (dens * 0.5 + veil * 0.2) * (Js * 0.9 + lt.Jw * 0.3) * (0.6 + 0.4 * clump) + star_light * Jc * Jc * 0.3 * (0.2 + dens);
		// the bubble blown clear of the medium: what is behind it dimmed; the knots hide it
		dk = max(0.3 * (1.0 - sm(0.8, 1.0, rr)), kd * 0.8);
	} else if (kind == 3) {
		vec2 cc = spot(1.0, vec2(-300.0, -260.0), vec2(1260.0, 800.0));
		float r = length(sp - cc) / 760.0;
		float rag = r + (bil - 0.5) * 0.3;
		// thin tangled strands: the contours of two noises, each a line
		float fil = A.b, fil2 = A.a;
		float shell = exp(-pow((rag - 0.85) / 0.14, 2.0));
		float inner = exp(-pow((rag - 0.72) / 0.12, 2.0));
		float amb = 0.3 + 0.4 * sm(0.4, 0.75, bil);
		// the strands near the sun lit by it, the hydrogen outside the shell and
		// the oxygen just within it
		float sunk = 1.0 + 1.6 * Js + 0.8 * Jc;
		L = (HA * fil * (amb * 1.2 + 1.7 * shell) + O3 * fil2 * (amb * 0.6 + 1.5 * inner)) * sunk
			+ mix(HA, O3, 0.5) * 0.06 * bil * (0.3 + shell + inner);
		dens = max(fil, fil2 * 0.8) * (0.4 + shell + inner);
		H = mix(vec3(0.15, 0.022, 0.085), vec3(0.03, 0.06, 0.08), sat(inner * 1.5)) * 0.25 * far * far + star_light * Jc * Jc * 0.25 * (0.2 + dens)
			+ mix(HA, O3, sat(inner * 1.4)) * veil * 0.04 * (0.3 + Js);
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
				float Aj = TAU * jj / 18.0 + (hash2(vec2(jj, w_seed * 50.0)) - 0.5) * 0.2;
				vec2 P = vec2(45.0 * cos(Aj), 31.5 * sin(Aj));
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
	} else if (kind == 5) {
		// THE CORE (C): the galaxy's heart. Warm clouds swirl round the hole; its
		// disc lights them in warm steps that fall off with distance (gathered
		// light, not a haze) -- cream right by the disc, then amber, orange and a
		// deep red-brown far out -- and dark lanes cut the swirl; far from the disc
		// the gas is a cool violet smoke, so the light round the hole is the
		// frame's one warm place
		float gas = A.r, lane = A.g;
		vec3 n = normalize(vec3(-G.xy * 12.0, 1.0));
		float face = sat(dot(n, normalize(vec3(toSun, 0.6))));
		float ge = gas * gas;
		float x = length((b - star_at) * vec2(1.0, 1.6)) / max(hole_r, 1.0);
		float Jh = 1.0 / (1.0 + pow(x / 1.25, 2.0));
		float Jf = 1.0 / (1.0 + pow(x / 4.0, 2.0));
		float Jn = 1.0 / (1.0 + pow(x / 0.75, 2.0));
		vec3 warm = mix(vec3(0.62, 0.07, 0.05), vec3(1.0, 0.36, 0.08), sat(Jh * 1.3));
		// (amber by the disc, as C's, not cream: gathered that bright, cream went
		// past the tone map to a pale salmon-pink)
		warm = mix(warm, vec3(1.0, 0.60, 0.26), sat(Jn * 1.4));
		vec3 lit = warm * (0.22 * gas + ge) * (Jh * 2.0 + Jf * 0.10 + Jn * 0.9) * (0.45 + 0.65 * face) * lt.att;
		// (the far smoke warm tan, lit faintly by the disc from afar, as the showcase
		// drew it: a cool violet there set the whole frame dull)
		// (red-brown as C's, not tan: its smoke is rust and wine, no green in it)
		vec3 col = vec3(0.030, 0.011, 0.014) * (0.3 * gas + ge) + vec3(0.006, 0.004, 0.012) * far * far
			+ vec3(0.36, 0.11, 0.07) * (0.3 * gas + ge) * Jf * 0.5;
		float lop = 1.0 - exp(-lane * 3.0);
		col = mix(col, vec3(0.006, 0.002, 0.003), lop * 0.85);
		lit *= 1.0 - lop * 0.85;
		col += vec3(0.16, 0.07, 0.03) * veil * 0.015;
		// THE FLARE'S ECHO: a broad warm ring sweeping out from the hole through
		// the gas, lighting its thick parts as it passes
		if (e_k > 0.0) {
			float de = length(b - star_at);
			lit += vec3(1.0, 0.64, 0.36) * exp(-pow((de - e_r) / 16.0, 2.0)) * (0.3 * gas + ge) * 2.2 * e_k * gk;
		}
		H = col + lit;
		if (radiant) {
			// RADIANT (A): the heart is a lit haze all through, rose-brown, brighter
			// toward the disc; the lanes darken it, never to black
			H += vec3(0.16, 0.07, 0.055) * r_core_haze * (0.45 + 0.55 * gas) * (0.35 + 0.65 * Jf) * (1.0 - lop * 0.4);
		}
		// the galaxy's heart is crowded with stars: more show in the gaps between the clouds
		trans = (1.0 - 0.55 * sat(gas * 1.6)) * exp(-lane * 2.5) * (radiant ? 0.5 : 1.0);
		dens = gas;
	} else {
		// DARK: thick dust hiding what lies behind it, its body dark brown-violet
		// (never void-black), its edge toward its own far light lit, and its edge
		// toward the system's sun burning as the sun comes near
		// (crisp masses: the soft baked dust sharpened, its edge broken by the
		// fine noise, so a mass reads as a shape and not as murk)
		float d = sm(0.36, 0.60, A.g + 0.10 * (fine - 0.5));
		dk = d * 0.97;
		float la = hash2(vec2(sd, 31.0)) * 6.2832;
		vec2 ld = vec2(cos(la), sin(la));
		float bil2 = flowed(t1, sp - ld * 15.36, 0.65, 24.0, 0.0, false).r;
		float face = sm(0.0, 0.012, bil - bil2);
		float rim = sm(0.05, 0.16, d) * (1.0 - sm(0.2, 0.38, d)) * face * sm(0.4, 0.72, fine);
		// DAWN (S): a bright stretch travelling along the lit rim
		if (wb && s_ev == 1) {
			rim *= 1.0 + 1.6 * exp(-pow((dot(sp - s_at, vec2(-ld.y, ld.x)) - (-120.0 + 35.0 * s_age)) / 40.0, 2.0)) * env(s_age, 1.0, 5.0, 1.5) * s_k;
		}
		L = vec3(1.0, 0.62, 0.42) * rim * 0.35 + vec3(0.3, 0.24, 0.42) * (1.0 - d) * sm(0.2, 0.5, bil) * 0.06;
		// A DARK NEBULA (SIMPLIFIED): the dust near-black, hiding what is behind it;
		// its edges toward the sun lit in a thin crisp rim, silver close to the sun
		// and amber further out; through the gaps the glow behind it and the stars
		vec2 gd = G.zw;
		float dl = length(gd);
		float skin = smoothstep(0.05, 0.25, d) * (1.0 - smoothstep(0.35, 0.72, d));
		float rimF = pow(sat(dot(gd / max(dl, 1e-5), -toSun) * 0.75 + 0.25), 3.0);
		float srim = skin * rimF * smoothstep(0.003, 0.015, dl) * smoothstep(0.02, 0.25, Js);
		vec3 rimC = mix(vec3(1.0, 0.58, 0.28), vec3(0.86, 0.90, 1.0), sat(Js * 1.6 + Jc));
		vec3 dn = normalize(vec3(-gd * 30.0, 1.0));
		float dface = sat(dot(dn, normalize(vec3(toSun, 0.5))));
		H = rimC * srim * (0.04 + 2.4 * Js + 2.0 * Jc)
			+ vec3(0.006, 0.004, 0.008) * d + vec3(0.040, 0.022, 0.012) * d * Js * dface
			+ (1.0 - d) * (vec3(0.034, 0.022, 0.052) * (0.15 + 2.2 * far * far) * (0.6 + 0.8 * fine) + star_light * 0.07 * Js);
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
	if (kind >= 2) {
		// THE GLOW OF THE CLOUD YOU ARE IN, faint, everywhere: no part of the sky
		// inside it is the black of open space
		L += (kind == 4 ? vec3(0.22, 0.17, 0.3) * 0.35 : hue * (kind == 2 ? 0.5 : 1.0)) * (0.07 + 0.1 * bil) * (1.0 - dk);
		trans = 1.0 - dk;
	}
	// THE STRIKE (emission and dark): a discharge deep in the cloud, a second, a
	// flicker, gone in under a second and a half -- upgraded, a soft double swell
	// before it, a teal afterglow after, and in a stormy system strikes walking
	// out from the cluster; in a dark cloud lit from behind, so the dust stands
	// out as black shapes with bright edges. In the emission cloud it is
	// lightning, not a pale patch: hot rose where the gas is thick, its
	// branching channel pale rose-white and bright, the dust round it caught.
	// RADIANT: THE HAZE the sun shines through, thin and everywhere, lit by what
	// reaches it -- so the shafts the worlds throw and the streaks the dust casts
	// show as light and dark beams through it, all pointing at the sun
	if (radiant && kind <= 4) {
		// (held off right round the sun: there the gas is near the top of its curve
		// already, and the haze laid a flat white plate the sun sat in)
		// (in the gas's own colour as much as the sun's: star-coloured haze over teal
		// washed the heart out to a pastel)
		vec3 hz = mix(star_light, H / max(max(H.r, max(H.g, H.b)), 1e-4), 0.65);
		H += hz * 0.045 * Js * (1.0 - sat(Jc * 2.0)) * (0.55 + 0.45 * far);
	}
	// (PAINTED: what the strike adds to the cloud itself, its flash and its channel)
	vec3 Hpre = H;
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
			if (radiant && w_age >= 0.0) {
				// (RADIANT: the discharge's light scatters through the cloud round it,
				// wide and soft, the thick gas catching most)
				float fe = exp(-w_age / 0.12) + 0.6 * exp(-max(w_age - 0.22, 0.0) / 0.14) * step(0.22, w_age);
				H += vec3(1.0, 0.55, 0.68) * fe * w_k * exp(-wr * wr / pow(1.8 * w_size, 2.0)) * (0.1 + dens) * 0.3 * gk;
			}
			vec3 lp = vec3(1.0, 0.52, 0.64);
			// the lit dust no longer hides the patch; the channel burns through it
			float Tl = mix(1.0 - dk, 1.0, min(1.0, fp * 0.8));
			// the patch a modest rose glow where the gas is thick; the CHANNEL the
			// bright thing, white-hot in its middle, so it reads as lightning and not
			// as a pale patch
			H += lp * fp * 0.24 * (0.35 + 0.65 * Tl);
			H += mix(lp, vec3(1.0, 0.94, 1.0), sat(ch * 1.6)) * sat(ch) * 6.5;
			L += mix(lc, O3, 0.5) * ag;
			trans = mix(trans, 1.0, min(1.0, fp * 0.5));
		}
	}
	vec3 Hev = (H - Hpre) * strength;
	// (RADIANT: the gas in a shaft glows by the light that reaches it, so its own
	// glow goes dark there too, not only what it scatters)
	if (radiant) H *= mix(1.0, lt.sh, 0.7);
	L *= strength;
	H *= strength;
	// the cloud in its own tone curve, the events' light over it as it always was
	vec3 c = kitToSrgb(kitTone(H * exposure, burn));
	if (painted) {
		// (the dust B paints is the pillars and their bank: an emission cloud's lanes,
		// drawn as dust, cut its masses into plates; with the sheets on they are gas)
		float dtau = (kind == 0 && p_sheets_on) ? max(A.g - 0.45 * A.a * A.b, 0.0) : A.g;
		COLOR = paint_cloud(c, clamp((1.0 - trans) * strength, 0.0, 0.97), L + Hev * 2.0, sp, toSun, G, Js, (kind <= 1) ? dtau : (kind == 4 ? 1.0 : 0.0), lt.dL);
	} else {
		c = vec3(1.0) - (vec3(1.0) - c) * exp(-L * expo);
		COLOR = vec4(c, clamp((1.0 - trans) * strength, 0.0, 0.97));
	}
}
