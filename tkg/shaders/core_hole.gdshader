shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// THE CORE: the black hole Jon picked (#11 on the black hole page, "the
// current one" with all five motions), as the system map lays it on -- the
// mockup's BH renderer (`sysmap/page/index.html`) with the map's settings
// (`CORE_P` in `sysmap/template.html`: hole radius 15, disc out to 110, seen
// from the orbits' own tilt, 0.38), painted per game pixel over its 330 x 210
// picture.
//
// What a pixel shows comes from the ray traced through it once
// (`core_trace.gdshader`, read back by `CoreView`): fallen in, or landed on the
// disc at a radius and angle. The disc is the mockup's "streak" disc: bright
// inside, fading out, one side brighter as it turns toward you, streaks of
// gas that orbit faster the closer in they are (an orbit's speed goes as
// r^-1.5, so the inner edge whips round and the outside drifts), the whole
// disc breathing and flaring. The streaks are the mockup's table, looked up
// at its own steps (half a pixel of radius, 1024 angles), so they have the
// same grain. The photon ring edges the shadow, hidden behind the near band of
// disc; the eaten star seen BEHIND the hole is drawn where its light is bent
// to.
//
// THE PHOTON RING IS LIGHT, NOT A STROKE, as on the chart (`chart_hole`): it
// was one cream band added at 70%, as thick at the sides as over the top
// ("that plain bright solid white arc ... isn't good looking", Jon). It is the
// disc's own hot inner edge bent round the hole: its brightness and colour are
// the disc's there, streaked and turning with it, brighter on the side the disc
// is brighter, thickest over the top where the far side is lensed up and
// thinning down the sides, stepping down on its outer edge in the palette's
// steps, and laid over what is there at 85% rather than added, so only its
// hottest spots reach white.
//
// The dots -- the clumps spiralling in, the eaten star's ribbon and the star
// itself in front -- are placed on the CPU each frame (`CoreView`), hidden
// there behind the hole and the near band exactly as the mockup hides them,
// and handed over as a small picture of colour numbers (`dots`). They replace
// the disc's colour where they land, as the mockup's plot did.
//
// Laid on as the map lays it (`coreDraw`): the shadow opaque black, the rest
// added at 70% to what is behind, so the faint edge of the gas is never a dark
// rim on the nebula. Under it the disc's warm light on the gas round it
// (`coreGlow`): an ellipse 152 x 82, dithered away, alpha-blended. The
// premultiplied output carries both in one draw: rgb = glow * a + gas, alpha =
// the glow's, worked so the blend floors as the mockup's integer maths did.
//
// `raw` draws the renderer's own picture opaque on its own space colour, to
// set beside the mockup's `BH.draw` pixel for pixel.
//
// ZOOMED (`kz`, the map's zoom the trace was made at), all of it is drawn kz
// times the size in single game pixels: the picture (`size`), the hole, the
// ring's width, the disc, the eaten star seen behind, the glow's ellipse; the
// streak table is read at kz times as many steps, so its grain stays a pixel
// fine. Every sum is written so that at kz = 1 it is the one it was.

// the dither in cell x cell blocks (2 on the map, whose place is drawn in 2x2 blocks)
uniform int cell = 1;
uniform sampler2D trace : filter_nearest, repeat_disable;
uniform sampler2D dots : filter_nearest, repeat_disable;
uniform float time = 0.0;
// the breath, the flare included, worked out on the CPU (the flare's draw is
// an integer hash of which 4.2 s it is)
uniform float breath = 1.0;
// the eaten star, in the picture's pixels, and whether it is behind the hole
uniform vec2 star = vec2(-999.0);
uniform bool star_behind = false;
uniform float tilt = 0.38;
uniform float rh = 15.0;
uniform float rin = 17.4;
uniform float rout = 110.0;
uniform bool raw = false;
uniform bool glow_on = true;
// the zoom, and the picture's size at it (330 x 210 at zoom 1)
uniform float kz = 1.0;
uniform vec2 size = vec2(330.0, 210.0);
// THE WEATHER (`SkyWeather`): a HOTSPOT, a clump riding the disc just outside
// the shadow (its radius in trace pixels, its disc angle, its strength), its
// lensed image over the top coming free from the trace; and a RING FLASH, the
// photon ring lighting where a clump plunged and racing round both ways
// (screen angle, age; a negative age is none)
uniform vec4 hs = vec4(0.0);
uniform vec2 rf = vec2(0.0, -1.0);

const float R_MAX = 140.0;
const float DOP = 0.45;
const float TR = 0.5;
const float TA = 1024.0;
const float NR = 262.0;

// the orange palette, darkest first; then the eaten star's two colours
const vec3 PAL[10] = vec3[10](
	vec3(30.0, 8.0, 4.0), vec3(74.0, 20.0, 6.0), vec3(132.0, 40.0, 12.0), vec3(194.0, 74.0, 20.0),
	vec3(236.0, 122.0, 38.0), vec3(255.0, 176.0, 84.0), vec3(255.0, 220.0, 150.0), vec3(255.0, 246.0, 226.0),
	vec3(216.0, 236.0, 255.0), vec3(58.0, 90.0, 138.0));
const int C_TSTAR = 8;
const int C_TRIM = 9;
const int C_HOLE = 10;
const int C_SPACE = -1;
const vec3 SPACE = vec3(5.0, 6.0, 10.0);

const float BAYER[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// ---------------------------------------------------------------- the mockup's 2D noise
float hash(ivec2 c) {
	uint h = (uint(c.x) * 374761393u) ^ (uint(c.y) * 668265263u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}
float noise(vec2 p) {
	vec2 i = floor(p), f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	ivec2 c = ivec2(i);
	float a = hash(c), b = hash(c + ivec2(1, 0)), cc = hash(c + ivec2(0, 1)), d = hash(c + ivec2(1, 1));
	return a + (b - a) * u.x + (cc - a) * u.y + (a - b - cc + d) * u.x * u.y;
}
float fbm(vec2 p) {
	return noise(p) * 0.6 + noise(p * 2.1) * 0.3 + noise(p * 4.3) * 0.1;
}
// the streak table, read at the mockup's own steps
float streak(float r, float a) {
	float ta = TA * kz;
	float ri = min(NR * kz - 1.0, floor(r / TR + 0.5));
	float ai = mod(floor(a / TAU * ta + 0.5), ta);
	float R = ri * TR / kz, A = ai / ta * TAU;
	return fbm(vec2(cos(A) * R * 0.11 + 40.0, sin(A) * R * 0.11 + 40.0));
}

float adiff(float a, float b) { return abs(mod(a - b + PI, TAU) - PI); }
float sm(float a, float b, float x) { float u = clamp((x - a) / (b - a), 0.0, 1.0); return u * u * (3.0 - 2.0 * u); }

float disc(float r, float a) {
	if (r > rout || r < rin * 0.55) return 0.0;
	float plunge = r < rin ? pow((r - rin * 0.55) / (rin * 0.45), 1.6) : 1.0;
	float f = 1.0 - (max(r, rin) - rin) / (rout - rin);
	float base = pow(f, 1.4);
	float d = 1.0 + DOP * cos(a + 0.4);
	float a2 = a - 1.1 * pow(r / rin, -1.5) * time;
	float s = 0.55 + 0.8 * streak(r, a2);
	float value = base * d * s * breath * plunge;
	// the hotspot: Doppler-bright on the side swinging toward you
	if (hs.z > 0.0) {
		float spt = exp(-pow((r - hs.x) / (2.5 * kz), 2.0) - pow(adiff(a, hs.y) / 0.28, 2.0));
		float D = 1.0 + 0.5 * cos(a + 0.4);
		value += 1.4 * spt * D * D * D * hs.z * plunge;
	}
	return value;
}

float u16(vec4 c) {
	return floor(c.r * 255.0 + 0.5) * 256.0 + floor(c.g * 255.0 + 0.5);
}

void fragment() {
	float W = size.x, H = size.y;
	int hi = int(H);
	ivec2 p = ivec2(floor(UV * vec2(W, H)));
	vec4 t0 = texelFetch(trace, p, 0);
	int fl = int(floor(t0.b * 255.0 + 0.5));
	int kind = fl & 3;
	bool inner = (fl & 4) != 0;
	bool front = (fl & 8) != 0;
	bool open = (fl & 16) != 0;
	float r = u16(t0) / 65535.0 * R_MAX * kz;
	float a = u16(texelFetch(trace, p + ivec2(0, hi), 0)) / 65535.0 * TAU - PI;
	vec2 sky = vec2(u16(texelFetch(trace, p + ivec2(0, hi * 2), 0)), u16(texelFetch(trace, p + ivec2(0, hi * 3), 0))) / 65535.0 * 2048.0 * kz - 1024.0 * kz;

	float u = float(p.x) - W / 2.0, v = float(p.y) - H / 2.0;
	float d = length(vec2(u, v));
	float val = 0.0;
	// rays that went round the hole first (the thin inner rings) a little dimmer
	if (kind == 2) val = disc(r, a) * (inner ? 0.75 : 1.0);
	int code = C_SPACE;
	bool done = false;
	bool over = false;
	// the photon ring, hidden behind the part of the disc that crosses in front:
	// up is 1 over the top of the hole, 0 at its sides
	float up = clamp(-v / max(d, 1e-3), -1.0, 1.0);
	float rw = max(0.5 * kz, rh * 0.06) * (0.3 + 1.2 * max(0.0, up));
	float rwi = max(0.5 * kz, rh * 0.04);
	if (d > rh - rwi && d <= rh + rw && !front && up > -0.2 && val < 0.5) {
		// the disc's hot inner edge, seen round the hole: the far side over the
		// top, so the angle is the screen's own
		float ar = atan(v, u);
		// (the core's disc runs hotter at its inner edge than the chart's: scaled so
		// white is the streaks' peaks, not the band)
		float vr = 0.62 * disc(rin * 1.04, ar) * (0.75 + 0.55 * max(0.0, up));
		vr *= 1.0 - 0.55 * smoothstep(rh, rh + rw + 0.5 * kz, d);
		// the ring flash: lit where the clump went over the edge, racing round both ways
		if (rf.y >= 0.0) {
			vr *= 1.0 + 1.5 * exp(-pow((adiff(ar, rf.x) - 5.2 * rf.y) / 0.3, 2.0)) * (1.0 - sm(0.5, 0.7, rf.y))
				+ 0.6 * sm(0.4, 0.7, rf.y) * exp(-max(rf.y - 0.7, 0.0) / 1.5);
		}
		float th = (BAYER[((p.y / max(cell, 1)) & 3) * 4 + ((p.x / max(cell, 1)) & 3)] / 16.0 - 0.5) * 0.9;
		int kq = int(floor(vr * 7.0 + th));
		// white only where the disc is hottest
		code = vr > 1.15 ? 7 : clamp(kq, 2, 6);
		over = true;
		done = true;
	}
	if (!done && kind == 1 && val < 0.06) { code = C_HOLE; done = true; }
	if (!done) {
		float f = kind == 2 ? 1.0 - (r - rin) / (rout - rin) : 0.0;
		int back = C_SPACE;
		// the eaten star behind the hole, seen where its light is bent to
		if (star_behind && open && (kind == 0 || (kind == 2 && f < 0.22))) {
			vec2 e = sky - star;
			if (dot(e, e) < 6.5 * kz * kz) back = dot(e, vec2(W / 2.0, H / 2.0) - star) > 0.0 ? 7 : C_TSTAR;
		}
		code = back;
		if (val > 0.02) {
			float th = (BAYER[((p.y / max(cell, 1)) & 3) * 4 + ((p.x / max(cell, 1)) & 3)] / 16.0 - 0.5) * 0.9;
			int k = int(floor(val * 8.0 + th));
			if (k >= 1 || (k == 0 && val > 0.07)) code = back != C_SPACE ? back : min(7, k);
		}
	}
	int dot_c = int(floor(texelFetch(dots, p, 0).r * 255.0 + 0.5));
	if (dot_c > 0) {
		code = dot_c - 1;
		over = false;
	}

	if (raw) {
		vec3 c = code == C_HOLE ? vec3(0.0) : (code == C_SPACE ? SPACE : PAL[code]);
		COLOR = vec4(c / 255.0, 1.0);
	} else if (code == C_HOLE) {
		COLOR = vec4(0.0, 0.0, 0.0, 1.0);
	} else if (over) {
		// the ring laid over what is there at 85% (premultiplied)
		COLOR = vec4(PAL[code] / 255.0 * 0.85, 0.85);
	} else {
		// the gas, added at 70% (truncated, as the mockup's integer maths)
		vec3 add = code == C_SPACE ? vec3(0.0) : floor(PAL[code] * 0.7);
		vec3 g = vec3(0.0);
		float ga = 0.0;
		// the disc's light on the gas round it
		if (glow_on) {
			float gd = length(vec2(u / 152.0 / kz, v / 82.0 / kz));
			if (gd < 1.0) {
				float gv = (1.0 - gd) * (1.0 - gd) * (1.0 + 0.08 * sin(time * 1.3));
				int bx = ((int(floor(u / float(max(cell, 1)))) + 99) & 3), by = ((int(floor(v / float(max(cell, 1)))) + 99) & 3);
				if (gv * 4.5 * 16.0 >= BAYER[by * 4 + bx] * 0.9) {
					ga = floor((0.12 + gv * 0.26) * 255.0 + 0.5);
					g = gv > 0.45 ? vec3(255.0, 176.0, 84.0) : vec3(194.0, 74.0, 20.0);
				}
			}
		}
		if (ga > 0.0) {
			// the mockup's blend is integer: (behind * (255 - a) + glow * a) >> 8,
			// floored. So the screen keeps (255 - a) / 256 of what is behind, and
			// a quarter of a step is taken off to lean the GPU's rounding toward
			// that floor (measured: a half overshoots, the blender's own rounding
			// is not quite to nearest; a quarter leaves 7% of the glow's pixels
			// one step off, where a plain blend left 15%); the gas, whole
			// numbers, rides along in the same sum
			COLOR = vec4((g * ga / 256.0 - 0.25 + add) / 255.0, (ga + 1.0) / 256.0);
		} else {
			COLOR = vec4(add / 255.0, 0.0);
		}
	}
}
