shader_type canvas_item;

// THE LIFT'S STEAM (`LiftPlume`, Jon's "AB-23", Nov 12): every lobe is a sphere lit by
// the lamps above and a little in front (a lit top, a shaded underside, the floor's
// light bounced up into its base), painted in order so a later lobe rolls over the
// ones before it (a crease where it does, its top shaded by what is under it). Five
// tones with an ordered dither between them; a dense core, a ragged see-through edge.
// The field the lobes are torn by moves on its own held clock (`tstep`, ten a second).
// `shadow_pass`: the same lobes, dropped a little, as a soft shadow on the floor.
// Why: docs/why/ShipLift.md#plume

uniform vec2 rect_size = vec2(960.0, 540.0);
// the rect's top left in the host's pixels (it reaches past the host's edges)
uniform vec2 org = vec2(0.0);
uniform int n = 0;
// x, y, radius, alpha
uniform vec4 lobe[96];
// tone shift, contrast, warmth, seed
uniform vec4 lobe2[96];
uniform float tstep = 0.0;
uniform vec4 box = vec4(0.0, 0.0, -1.0, -1.0);
uniform float floor_y = 372.0;
// five tones, crease to lit rim
uniform vec4 tones[5];
// the hall's lamps over it: x, and how far each one's light reaches across
uniform int nlamps = 0;
uniform vec2 lamps[8];
uniform float warm_k = 1.0;
uniform bool shadow_pass = false;
uniform float shadow_k = 0.34;
// how heavy (`LiftPlume.WEIGHTS`): the ragged edge's share of a lobe's alpha, and how
// much darker its underside goes
uniform float edge_a = 0.5;
uniform float under_k = 0.0;
// THE TEXTURE (Jon, Nov 13, stills to pick from): 0 as built; 1 cel (three flat
// bands, no dither, a dark line round each cluster); 2 patterned (a bold dither and
// swirl marks); 3 as built with a light outline in a darker tone of the steam
uniform int style = 0;

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[i] + 0.5) / 16.0;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	return 0.55 * vnoise(p) + 0.3 * vnoise(p * 2.1 + 5.2) + 0.15 * vnoise(p * 4.3 + 1.7);
}

// a lobe's own squash: its height over its width, kept in the seed's whole part
float aspect_of(float w) {
	float a = floor(w) / 100.0;
	return a > 0.0 ? a : 1.0;
}

// whether any lobe covers this pixel, its edge torn as the colour pass tears it
// (for the outlines of styles 1 and 3)
bool covers(vec2 p) {
	vec2 q0 = p * 0.07 + vec2(tstep * 0.19, -tstep * 0.27);
	vec2 pw = p + (vec2(fbm(q0), fbm(q0 + 31.7)) - 0.5) * 11.0;
	float edge_n = fbm(p * 0.16 + vec2(tstep * 0.31, tstep * 0.13));
	for (int i = 0; i < 96; i++) {
		if (i >= n) {
			break;
		}
		vec4 L = lobe[i];
		vec2 d = (pw - L.xy) / L.z;
		d.y /= aspect_of(lobe2[i].w);
		float en = fract(edge_n + lobe2[i].w);
		if (L.w > 0.12 && dot(d, d) < 0.9 + 0.25 * (en - 0.5)) {
			return true;
		}
	}
	return false;
}

void fragment() {
	vec2 p = floor(UV * rect_size) + 0.5 + org;
	if (p.x < box.x || p.y < box.y || p.x > box.z || p.y > box.w) {
		discard;
	}
	float th = bayer4(p);
	vec2 q0 = p * 0.07 + vec2(tstep * 0.19, -tstep * 0.27);
	vec2 pw = p + (vec2(fbm(q0), fbm(q0 + 31.7)) - 0.5) * 11.0;
	if (shadow_pass) {
		// the lobes' cover, dropped and softened, darkening the floor in steps
		float dens = 0.0;
		for (int i = 0; i < 96; i++) {
			if (i >= n) {
				break;
			}
			vec4 L = lobe[i];
			vec2 d = (pw - L.xy - vec2(0.0, 10.0)) / (L.z * 1.2);
			dens += L.w * max(0.0, 1.0 - dot(d, d));
		}
		float s = floor(clamp(dens, 0.0, 1.0) * 3.0 + th) / 3.0 * shadow_k;
		if (s <= 0.0 || p.y < floor_y - 50.0) {
			discard;
		}
		COLOR = vec4(0.0, 0.0, 0.0, s);
	} else {
		float tone = -1.0;
		float a = 0.0;
		float covered = 0.0;
		float warm = 0.0;
		bool swirl = false;
		float edge_n = fbm(p * 0.16 + vec2(tstep * 0.31, tstep * 0.13));
		float eddy = fbm(p * 0.25 + vec2(-tstep * 0.23, tstep * 0.41));
		for (int i = 0; i < 96; i++) {
			if (i >= n) {
				break;
			}
			vec4 L = lobe[i];
			vec4 P = lobe2[i];
			vec2 d = (pw - L.xy) / L.z;
			d.y /= aspect_of(P.w);
			float q = dot(d, d);
			float en = fract(edge_n + P.w);
			if (q >= 0.9 + 0.25 * (en - 0.5)) {
				continue;
			}
			float nz = sqrt(max(0.0, 1.0 - q));
			float key = clamp(-d.y * 0.8 + nz * 0.5 - d.x * 0.1, 0.0, 1.0);
			float bounce = clamp(d.y - 0.6, 0.0, 1.0) * 0.6 * clamp(1.0 - (floor_y - L.y - L.z) / 60.0, 0.0, 1.0);
			float shade = key + bounce + (eddy - 0.5) * 0.35 - under_k * clamp(d.y, 0.0, 1.0);
			// its top shaded by the steam it rolls over
			shade -= 0.3 * covered * clamp(-d.y + 0.3, 0.0, 1.0);
			shade = 0.5 + (shade - 0.5) * P.y;
			float t = clamp(shade * 4.2 + 0.2 + P.x, 0.0, 4.0);
			// a crease under it where it lies over steam already there
			// (not on a thinning lobe: its rim would read as a dark ring)
			// (cel: round every billow that lies over another, so each reads as its own)
			bool crease = style == 1 ? (q > 0.74 && d.y > -0.35) : (q > 0.82 && d.y > 0.15);
			if (crease && covered > 0.4 && L.w > 0.6) {
				t = min(t, 0.8);
			}
			float la = q > 0.55 + 0.3 * en ? L.w * edge_a : L.w;
			tone = t;
			// (style 2's swirl: an arc in the lobe's lit upper quarter)
			float ang = atan(d.y, d.x);
			swirl = abs(sqrt(q) - 0.55) < 0.07 && ang > -2.7 && ang < -1.1;
			a = max(la, q > 0.8 ? a : 0.0);
			covered = max(covered, la);
			warm = max(warm, P.z * clamp(d.y + 0.3, 0.0, 1.0));
		}
		if (tone < 0.0 || a <= 0.0) {
			discard;
		}
		float lo = floor(tone);
		int pick = int(clamp((tone - lo) > th ? lo + 1.0 : lo, 0.0, 4.0));
		if (style == 1) {
			// three flat bands, no dither
			// (the painted still's three: dark, mid grey, a lit top short of white)
			pick = tone < 1.4 ? 0 : (tone < 2.8 ? 2 : 3);
		} else if (style == 2) {
			// a bold two-step pattern between the bands, and the swirl marks
			float chk = mod(p.x + p.y, 2.0) < 1.0 ? 0.3 : 0.7;
			pick = int(clamp((tone - lo) > chk ? lo + 1.0 : lo, 0.0, 4.0));
			if (swirl) {
				pick = max(pick - 2, 0);
			}
		}
		// the outline: a pixel of the cluster with open air beside it
		bool rim = false;
		if (style == 1 || style == 3) {
			bool up = covers(p + vec2(0.0, -1.0));
			bool side = covers(p + vec2(-1.0, 0.0)) && covers(p + vec2(1.0, 0.0)) && covers(p + vec2(0.0, 1.0));
			// (style 3 leaves it open on the lit tops, now and then)
			rim = !side || (!up && (style == 1 || th < 0.5));
		}
		vec3 col = tones[pick].rgb;
		if (rim) {
			// (cel: near black; outlined: a dark grey of the steam's own, light-touch)
			col = style == 1 ? tones[0].rgb * 0.6 : tones[1].rgb;
		}
		// lit by the hall's lamps over it: a little brighter under each
		float lit = 0.84;
		for (int i = 0; i < 8; i++) {
			if (i >= nlamps) {
				break;
			}
			float dx = (p.x - lamps[i].x) / lamps[i].y;
			lit = max(lit, 0.84 + 0.3 * exp(-dx * dx));
		}
		col *= lit;
		float w = floor(warm * 3.0 + th) / 3.0;
		col += w * vec3(0.5, 0.26, 0.08) * warm_k;
		float al = floor(a * 4.0 + th * 0.999) / 4.0;
		if (style == 1) {
			al = a > 0.3 ? max(a, 0.85) : 0.0;
		}
		if (rim) {
			al = max(al, 0.75);
		}
		if (al <= 0.0) {
			discard;
		}
		COLOR = vec4(min(col, vec3(1.0)), al);
	}
}
