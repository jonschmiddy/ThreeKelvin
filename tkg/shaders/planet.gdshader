shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// ONE WORLD, painted per game pixel: the approved mockup's planet painter
// (the scratchpad's `sysmap/planets.js`, "Thirty-Four Worlds") on the GPU.
//
// Painted on the sphere itself, so a feature wraps round without a seam as the
// world turns: each pixel is turned into a point on the unit sphere, spun about
// the world's axis, and its surface read from 3D noise there; lit from its
// star and shaded through the world's own ramp with a 2x2 dither. Four samples
// a pixel, the commonest kind of ground winning, so a thin crack sliding across
// a pixel shades it partway instead of switching it.
//
// Then the LIGHT the world gives off or catches, gathered per pixel and added
// in a few dithered steps: its air, the sun's glint on water, the glow round
// anything burning, a diamond's glint, an oil slick's colours, a jungle's
// veins, a city's lights, lightning, auroras, an evaporating world's tail.
//
// The square is drawn with premultiplied alpha: the world's own pixels are
// opaque, and light outside it has no alpha, so it ADDS to what is behind --
// the sky round a world glows instead of being painted over.
//
// What the mockup had and this has not: its per-pixel memory, which eased each
// pixel's value over a few frames and held a shade until the surface had
// clearly moved. A shader keeps nothing between frames.

// ---------------------------------------------------------------- uniforms
uniform sampler2D ramps : filter_nearest, repeat_disable;
// worked out in cell x cell blocks of game pixels (Jon's B, for the whole map)
uniform int cell = 1;
// THE LIVE CENTRE (the map's smooth zoom, `SystemView`): where the world's true
// centre sits off the box's own (px, under a block either way), so the disc is drawn
// round it while the box stays on the grid; the dither keeps the grid's
uniform vec2 ctr_off = vec2(0.0);
// RICHER WHEN SMALL (Jon: "we could have small worlds just be richer"): 0 to 1,
// full for a world a few blocks across. Bolder ground, a crisper day and night,
// and a lit rim on its sunward edge, so it reads as a world and not a blob.
uniform float rich = 0.0;
uniform int world = 0;
uniform int base_ramp = 0;
uniform float seed = 0.0;
uniform float r = 8.0;
uniform int half_size = 16;
uniform float spin = 0.05;
uniform float tilt = 0.0;
uniform vec3 light = vec3(-0.83, -0.31, 0.47);
uniform float time = 0.0;
uniform float cloud_rate = 0.02;
uniform float bands = 8.0;
uniform bool ring = false;
// THE RINGS' SHADOW: 0, the dots' fixed two bands; 1, read off the world's own
// strip (`Rings.gd`), the same rings `planet_ring.gdshader` draws, so every
// ringlet and gap shows in the shadow too. `ring_cast`: how dark it falls.
uniform int ring_mode = 0;
uniform sampler2D ring_prof : filter_linear, repeat_disable;
uniform float ring_in = 1.5;
uniform float ring_out = 2.2;
uniform float ring_cast = 0.8;
uniform vec4 craters[9];
uniform int n_craters = 0;
uniform vec2 spot = vec2(0.0);
uniform bool has_spot = false;
uniform vec4 storms[2];
uniform vec4 ovals[4];
uniform int n_ovals = 0;
// how strongly the star's light reaches this world (the map dims the far ones)
uniform float k_light = 1.0;
uniform vec3 atm = vec3(0.0);
uniform bool has_atm = false;
uniform bool thick = false;
uniform float caps = 0.0;
uniform float clouds = 0.0;
uniform int cloud_ramp = 16;
uniform bool unlit = false;
uniform int flags = 0;
uniform vec4 flashes[5];
uniform int n_flashes = 0;
uniform vec2 bolts[25];
uniform int n_bolts = 0;
uniform vec4 towns[64];
uniform int n_towns = 0;
uniform vec3 aur_ax[2];
uniform vec3 aur_e1[2];
uniform vec3 aur_e2[2];
// a world behind the star is hidden where the star's disc covers it
uniform vec2 star_at = vec2(-9999.0);
uniform float star_r = 0.0;
uniform vec2 centre = vec2(0.0);
// LIT BY ITS OWN STAR (SIMPLIFIED, direction C, on the system map): the lit side in
// the star's colour (linear, brightest channel 1), the night side filled by the
// sky round it (linear light, 0 for none), and a sun's flare at its height
// (0..1: the lit side 10% brighter, auroras flickering). The defaults change nothing.
uniform vec3 star_tint = vec3(1.0);
uniform vec3 night_fill = vec3(0.0);
uniform float flare = 0.0;
// PAINTED (direction B, `SectorPainted`): cel-shaded in four bands on the
// world's own ramp -- the lit side and a small highlight, the terminator a 1-block
// 50% checker, the night side hue-shifted toward the sky's ambient (`p_amb`) --
// with an outline on the night side (`p_out`), the sky's light on the night limb
// (`p_bounce`), a lit rim on the day limb, and water's glint as a 1-2 block
// sparkle; its own light (air, cities, fire) in flat steps, never dithered.
uniform bool painted = false;
// RADIANT (direction A, "light through gas"; Jon: "Why do the planets and stars
// look the same between simplified, legacy and radiant?"): the world LIT, not
// shaded -- its ground's own colour (the 34 kinds' surfaces, unchanged) taken as
// an albedo and lit as a sphere by the star's real colour and direction, with a
// soft wide terminator (the star is a disc, not a point; A's lightSurface), its
// night side filled by the gas round it, the gas behind catching its limb, all
// gathered through a tone curve (never a flat white). Its air a thicker shell
// that scatters the starlight in the air's own colour, glowing all round the limb
// when the world stands between you and the star. Weights: the star, the fill,
// the limb's catch, the exposure (A's `wk`)
uniform bool radiant = false;
uniform vec4 r_wk = vec4(1.7, 9.0, 7.0, 1.15);
// how far the light wraps round past the terminator; the cloud's wash over the
// world (all over, more at the limb) and how bright that cloud is
uniform float r_wrap = 0.22;
uniform vec3 r_haze = vec3(0.22, 0.45, 16.0);
// its moons: each one's place about this world (screen px: x right, y down, z
// toward you) and its drawn radius, for the eclipse they cast on its face
uniform vec4 moon_sh[4];
uniform int n_moon_sh = 0;
// how far the lit side's middle tones are carried up (every style but LEGACY: 1)
uniform float lift = 0.0;
uniform vec3 p_amb = vec3(0.07, 0.10, 0.19);
uniform vec3 p_out = vec3(0.02, 0.03, 0.05);
uniform vec3 p_bounce = vec3(0.07, 0.10, 0.19);

// ---------------------------------------------------------------- the ramps and worlds, by number
const int R_ROCK = 0; const int R_MOON = 1; const int R_DESERT = 2; const int R_IRON = 3; const int R_ICE = 4;
const int R_CRUST = 5; const int R_GLOW = 6; const int R_SEA = 7; const int R_LAND = 8; const int R_TOXIC = 9;
const int R_CITY = 10; const int R_CRYSTAL = 11; const int R_BANDED = 12; const int R_ICEGIANT = 13; const int R_STORM = 14;
const int R_VIOLET = 15; const int R_CLOUD = 16; const int R_HAZE = 17; const int R_ASH = 18; const int R_SCORCH = 19;
const int R_CARBON = 20; const int R_ALIEN = 21; const int R_LINEAE = 22; const int R_STORM2 = 23; const int R_SWAMP = 24;
const int R_SWAMPW = 25; const int R_BLAZE = 26; const int R_GRAPHITE = 27; const int R_TAR = 28; const int R_SMOG = 29;
const int R_DIAMOND = 30; const int R_MIST = 31;

const int W_ROCK = 0; const int W_MOON = 1; const int W_DESERT = 2; const int W_IRON = 3; const int W_ICE = 4;
const int W_LAVA = 5; const int W_VERDANT = 6; const int W_OCEAN = 7; const int W_TOXIC = 8; const int W_CITY = 9;
const int W_CRYSTAL = 10; const int W_BANDED = 11; const int W_ICEGIANT = 12; const int W_STORM = 13; const int W_VIOLET = 14;
const int W_EYEBALL = 15; const int W_HOTJUP = 16; const int W_CRACKED = 17; const int W_HURRICANE = 18; const int W_HAZE = 19;
const int W_VOLCANIC = 20; const int W_BIOLUM = 21; const int W_MEGACITY = 22; const int W_SHATTERED = 23; const int W_CARBONA = 24;
const int W_CARBONB = 25; const int W_CARBONC = 26; const int W_SCORCHED = 27; const int W_ROGUE = 28; const int W_AURORA = 29;
const int W_LIGHTNING = 30; const int W_COMET = 31; const int W_EUROPA = 32; const int W_SWAMP = 33;

const int F_CITY = 1; const int F_LIGHTNING = 2; const int F_AURORA = 4; const int F_TAIL = 8; const int F_GIANT = 16; const int F_MEGACITY = 32;

// ---------------------------------------------------------------- noise, as the mockup's
float h3(vec3 p) {
	ivec3 q = ivec3(p);
	uint h = (uint(q.x) * 374761393u) ^ (uint(q.y) * 668265263u) ^ (uint(q.z) * 1440662683u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}
float n3(vec3 p) {
	vec3 i = floor(p), f = p - i;
	vec3 u = f * f * (3.0 - 2.0 * f);
	float a = mix(mix(h3(i), h3(i + vec3(1, 0, 0)), u.x), mix(h3(i + vec3(0, 1, 0)), h3(i + vec3(1, 1, 0)), u.x), u.y);
	float b = mix(mix(h3(i + vec3(0, 0, 1)), h3(i + vec3(1, 0, 1)), u.x), mix(h3(i + vec3(0, 1, 1)), h3(i + vec3(1, 1, 1)), u.x), u.y);
	return mix(a, b, u.z);
}
float fbm3(vec3 p, int oct) {
	float a = 0.5, s = 0.0, n = 0.0;
	for (int i = 0; i < oct; i++) { s += a * n3(p); n += a; p *= 2.03; a *= 0.5; }
	return s / n;
}
float worley3(vec3 p) {
	vec3 i = floor(p);
	float f1 = 9.0, f2 = 9.0;
	for (int dz = -1; dz <= 1; dz++) for (int dy = -1; dy <= 1; dy++) for (int dx = -1; dx <= 1; dx++) {
		vec3 c = i + vec3(float(dx), float(dy), float(dz));
		vec3 e = c + vec3(h3(c), h3(c + vec3(17.0, 0.0, 0.0)), h3(c + vec3(0.0, 31.0, 0.0))) - p;
		float d = dot(e, e);
		if (d < f1) { f2 = f1; f1 = d; } else if (d < f2) { f2 = d; }
	}
	return sqrt(f2) - sqrt(f1);
}

// ---------------------------------------------------------------- ramps
vec3 rampc(int ramp, int k) { return texelFetch(ramps, ivec2(clamp(k, 0, 5), ramp), 0).rgb; }
float bayer2(float x, float y) {
	int cl = max(cell, 1);
	int ix = ((int(x + ctr_off.x) + 1000 * cl) / cl) & 1, iy = ((int(y + ctr_off.y) + 1000 * cl) / cl) & 1;
	return iy == 0 ? (ix == 0 ? 0.0 : 2.0) : (ix == 0 ? 3.0 : 1.0);
}
vec3 ramp_at(int ramp, float v, float x, float y) {
	return rampc(ramp, int(floor(v * 6.0 + (bayer2(x, y) - 1.5) * 0.22)));
}

// ---------------------------------------------------------------- the painted world (B)
vec3 p_lin(vec3 c) { return mix(c / 12.92, pow((c + 0.055) / 1.055, vec3(2.4)), step(0.04045, c)); }
vec3 p_srgb(vec3 c) { c = max(c, 0.0); return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
vec3 p_lab(vec3 c) {
	vec3 l3 = p_lin(c);
	float l = pow(max(0.4122214708 * l3.r + 0.5363325363 * l3.g + 0.0514459929 * l3.b, 0.0), 1.0 / 3.0);
	float m = pow(max(0.2119034982 * l3.r + 0.6806995451 * l3.g + 0.1073969566 * l3.b, 0.0), 1.0 / 3.0);
	float s = pow(max(0.0883024619 * l3.r + 0.2817188376 * l3.g + 0.6299787005 * l3.b, 0.0), 1.0 / 3.0);
	return vec3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s, 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s, 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
}
vec3 p_unlab(vec3 L) {
	float l = L.x + 0.3963377774 * L.y + 0.2158037573 * L.z;
	float m = L.x - 0.1055613458 * L.y - 0.0638541728 * L.z;
	float s = L.x - 0.0894841775 * L.y - 1.2914855480 * L.z;
	l = l * l * l; m = m * m * m; s = s * s * s;
	return p_srgb(vec3(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s, -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s, -0.0041960771 * l - 0.7034186147 * m + 1.7076147010 * s));
}
// two colours mixed in OKLab (B's `mixOk`): a night side leaning to the sky
vec3 p_mix(vec3 a, vec3 b, float t) { return p_unlab(mix(p_lab(a), p_lab(b), t)); }
// the block's checker, riding the world itself
bool p_chk(float x, float y) {
	int cl = max(cell, 1);
	return ((((int(x + ctr_off.x) + 1000 * cl) / cl) + ((int(y + ctr_off.y) + 1000 * cl) / cl)) & 1) == 1;
}
// B's extended ramp for a world: 0 outline, 1 night, 2 dusk (both leaning to the
// sky), 3..6 its own steps 1..4, 7 its brightest warmed by its star
vec3 p_ext(int ramp, int c) {
	if (c <= 0) return p_out;
	if (c == 1) return p_mix(rampc(ramp, 0), p_amb, 0.5);
	if (c == 2) return p_mix(rampc(ramp, 1), p_amb, 0.34);
	if (c >= 7) return p_mix(rampc(ramp, 5), p_srgb(star_tint) * 0.9 + 0.1, 0.3);
	return rampc(ramp, c - 2);
}

// ---------------------------------------------------------------- the surface
struct Surf { int ramp; float v; vec3 emit; bool has_emit; bool cloud; float glow; float glint; float irid; };

float wrap_pi(float a) { return atan(sin(a), cos(a)); }

// a giant's air in its jets: each band of latitude turned on by its own amount
struct Jet { float qx; float qz; float lon; float streak; };
Jet jet(float amp, float px3, float py3, float pz3) {
	float ja = time * amp * sin(py3 * bands * 0.5 + seed), cj = cos(ja), sj = sin(ja);
	Jet J;
	J.qx = px3 * cj - pz3 * sj; J.qz = px3 * sj + pz3 * cj;
	J.lon = atan(J.qz, J.qx);
	J.streak = fbm3(vec3(J.qx * 5.0 + seed, py3 * 18.0, J.qz * 5.0), 2) - 0.5;
	return J;
}
float fq(Jet J, float py3, float k, int o) { return fbm3(vec3(J.qx * k + seed, py3 * k, J.qz * k - seed), o); }

// small ovals: swirling, light or dark
float ovals_at(Jet J, float lat, float v0) {
	for (int i = 0; i < n_ovals; i++) {
		vec4 o = ovals[i];
		float dl = wrap_pi(J.lon - o.x);
		float e = pow(dl / (0.2 * o.z), 2.0) + pow((lat - o.y) / (0.07 * o.z), 2.0);
		if (e < 1.0) {
			float rho = sqrt(e), sp = 0.08 * sin(atan((lat - o.y) / (0.07 * o.z), dl / (0.2 * o.z)) * 2.0 + rho * 7.0 - time * 1.2);
			return (o.w > 0.5 ? 0.82 - e * 0.2 : 0.26 + e * 0.2) + sp;
		}
	}
	return v0;
}
// GREAT STORMS: two on every giant, the second smaller and pale. kind 0: none;
// 1: set ramp and value; 2: add to the value (the wake)
struct Storm { int kind; int ramp; float v; };
Storm one_storm(Jet J, float lat, vec4 g, bool pale) {
	Storm S; S.kind = 0; S.ramp = 0; S.v = 0.0;
	float dl = wrap_pi(J.lon - (g.x + time * 0.012));
	float ex = dl / g.z, ey = (lat - g.y) / g.w, e = ex * ex + ey * ey;
	int own = base_ramp;
	int inner;
	if (pale) inner = (world == W_ICEGIANT || world == W_VIOLET) ? R_CLOUD : (world == W_HOTJUP ? R_STORM : own);
	else inner = world == W_BANDED ? R_STORM : (world == W_STORM ? R_IRON : (world == W_HOTJUP ? R_CRUST : (world == W_ICEGIANT ? R_SEA : R_CRYSTAL)));
	if (e < 1.0) {
		float rho = sqrt(e), th = atan(ey, ex) + time * 0.5 / (0.3 + rho);
		S.kind = 1;
		if (rho > 0.82) { S.ramp = world == W_ICEGIANT ? R_CLOUD : (world == W_HOTJUP ? R_STORM : own); S.v = 0.86 - (rho - 0.82) * 1.5; return S; }
		float sw = fbm3(vec3(rho * cos(th) * 3.0 + seed, rho * sin(th) * 3.0, 5.0), 3);
		S.ramp = inner;
		S.v = (pale ? 0.62 : 0.42) + 0.2 * sin(th * 2.0 + rho * 9.0) * rho + (sw - 0.5) * 0.55 + (1.0 - rho) * 0.15;
		return S;
	}
	if (dl < 0.0 && dl > -g.z * 3.4 && abs(ey) < 1.5) {
		float kk = (1.0 + dl / (g.z * 3.4)) * (1.0 - abs(ey) / 1.5);
		S.kind = 2;
		S.v = kk * (fbm3(vec3(J.qx * 8.0 + seed, lat * 26.0 + time * 0.15, J.qz * 8.0), 3) - 0.5) * 1.1;
	}
	return S;
}
Storm great_storm(Jet J, float lat) {
	Storm hit; hit.kind = 0; hit.ramp = 0; hit.v = 0.0;
	for (int i = 0; i < 2; i++) {
		Storm s = one_storm(J, lat, storms[i], i == 1);
		if (s.kind == 1) return s;
		if (s.kind == 2 && hit.kind == 0) hit = s;
	}
	return hit;
}

Surf surf(vec3 sv, float x, float y, float lam, vec3 HV) {
	float ang = seed + time * spin, ca = cos(ang), sa = sin(ang);
	float ct = cos(tilt), st = sin(tilt);
	float tx = sv.x * ct - sv.y * st, ty = sv.x * st + sv.y * ct;
	float px3 = tx * ca + sv.z * sa, pz3 = -tx * sa + sv.z * ca, py3 = ty;
	float lat = py3;
	vec3 P = vec3(px3, py3, pz3);
	Surf S; S.ramp = base_ramp; S.v = 0.5; S.emit = vec3(0.0); S.has_emit = false; S.cloud = false; S.glow = 0.0; S.glint = 0.0; S.irid = -1.0;
	#define F(k, o) fbm3(vec3(px3 * (k) + seed, py3 * (k), pz3 * (k) - seed), o)
	if (world == W_ROCK || world == W_MOON) {
		S.v = 0.35 + F(2.2, 4) * 0.55;
		if (world == W_MOON && F(1.1, 2) < 0.42) S.v -= 0.18;
		for (int i = 0; i < n_craters; i++) { float dd = distance(P, craters[i].xyz), cr = craters[i].w; if (dd < cr) S.v += dd > cr * 0.78 ? 0.16 : -0.14; }
	} else if (world == W_DESERT) {
		S.v = 0.42 + 0.18 * sin(lat * 38.0 + F(3.0, 2) * 9.0) + F(2.0, 3) * 0.3;
	} else if (world == W_IRON) {
		S.v = 0.3 + F(2.4, 4) * 0.62;
	} else if (world == W_ICE) {
		float n = F(2.6, 4); S.v = 0.62 + n * 0.3; if (abs(n - 0.5) < 0.018) S.v = 0.18;
	} else if (world == W_LAVA) {
		float n = F(2.8, 4); S.ramp = R_CRUST; S.v = 0.25 + n * 0.55;
		if (abs(n - 0.5) < 0.05) { S.emit = ramp_at(R_GLOW, 0.95 - abs(n - 0.5) * 9.0, x, y); S.has_emit = true; }
	} else if (world == W_VERDANT || world == W_OCEAN || world == W_CITY) {
		float n = F(1.8, 5);
		float sea = world == W_OCEAN ? 0.64 : (world == W_CITY ? 0.4 : 0.5);
		if (world == W_CITY) { S.ramp = n < sea ? R_SEA : R_CITY; S.v = n < sea ? 0.3 + n * 0.4 : 0.3 + (n - sea) * 1.4; }
		else if (n < sea) { S.ramp = R_SEA; S.v = 0.35 + n * 0.55; }
		else { S.ramp = n > sea + 0.16 ? R_ROCK : R_LAND; S.v = 0.4 + (n - sea) * 1.6; }
	} else if (world == W_TOXIC) {
		S.v = 0.3 + 0.25 * sin(lat * 14.0 + F(2.0, 3) * 7.0) + F(3.0, 3) * 0.3;
	} else if (world == W_CRYSTAL) {
		float n = F(2.2, 3); S.v = floor(n * 6.0) / 6.0 + 0.1;
		if (h3(floor(P * 30.0)) < 0.035 && lam > 0.4) { S.emit = vec3(1.0); S.has_emit = true; }
	} else if (world == W_EYEBALL) {
		// locked facing its star: desert by day, ice by night, life in the twilight
		float day = dot(sv, light), n = F(2.4, 4);
		if (day > 0.35) { S.ramp = R_DESERT; S.v = 0.55 + n * 0.4; }
		else if (day > -0.12) { bool wet = n < 0.48; S.ramp = wet ? R_SEA : R_LAND; S.v = wet ? 0.45 + n * 0.4 : 0.45 + n * 0.5; }
		else { S.ramp = R_ICE; S.v = 0.55 + n * 0.35; }
	} else if (world == W_HOTJUP) {
		Jet J = jet(0.11, px3, py3, pz3);
		float turb = fq(J, py3, 2.0, 3) * 0.6, band = 0.5 + 0.5 * sin(lat * bands + turb * 4.0 + seed);
		S.ramp = R_STORM; S.v = ovals_at(J, lat, 0.35 + 0.45 * band + J.streak * 0.2);
		Storm g = great_storm(J, lat);
		if (g.kind == 1) { S.ramp = g.ramp; S.v = g.v; } else if (g.kind == 2) S.v += g.v;
		if (lam < 0.14) { S.emit = ramp_at(R_GLOW, 0.12 + 0.4 * band * (1.0 - lam / 0.14), x, y); S.has_emit = true; }
	} else if (world == W_CRACKED) {
		float wq = (F(3.0, 2) - 0.5) * 0.3, e = worley3(vec3(px3 * 2.4 + wq + seed, py3 * 2.4 - wq, pz3 * 2.4 + wq));
		S.ramp = R_ROCK; S.v = 0.3 + F(5.0, 3) * 0.5;
		if (e < 0.045) { S.emit = ramp_at(R_GLOW, 0.98 - e * 7.0, x, y); S.has_emit = true; } else if (e < 0.09) S.v *= 0.35 + e * 4.0;
	} else if (world == W_HURRICANE) {
		float n = F(1.8, 5);
		if (n < 0.62) { S.ramp = R_SEA; S.v = 0.35 + n * 0.55; } else { S.ramp = R_LAND; S.v = 0.4 + (n - 0.62) * 1.6; }
		float lon = atan(pz3, px3), lat0 = spot.y;
		float dl = wrap_pi(lon - spot.x);
		float ex = dl * cos(lat0), ey = lat - lat0, rho = length(vec2(ex, ey)), th = atan(ey, ex);
		float c = (0.5 + 0.5 * sin(th * 2.0 - rho * 16.0 + time * 0.6)) * exp(-rho * 3.2) - (rho < 0.04 ? 1.0 : 0.0);
		if (c > 0.3) { S.cloud = true; S.ramp = R_CLOUD; S.v = 0.55 + (c - 0.3) * 1.2; }
	} else if (world == W_HAZE) {
		Jet J = jet(0.04, px3, py3, pz3);
		S.ramp = R_HAZE; S.v = 0.45 + 0.1 * sin(lat * 5.0 + fq(J, py3, 1.4, 2) * 3.0) + fq(J, py3, 2.0, 3) * 0.15 + J.streak * 0.22;
	} else if (world == W_VOLCANIC) {
		float wq = (F(3.0, 2) - 0.5) * 0.5, e = worley3(vec3(px3 * 2.0 + wq + seed, py3 * 2.0 - wq, pz3 * 2.0));
		S.ramp = R_CRUST; S.v = 0.3 + F(4.0, 3) * 0.5;
		if (e < 0.042 && F(1.3, 2) > 0.52) { S.emit = ramp_at(R_GLOW, 0.9 - e * 4.0, x, y); S.has_emit = true; }
		else if (lam < 0.5 && h3(floor(P * 6.0)) < 0.04) { S.emit = ramp_at(R_GLOW, 0.55, x, y); S.has_emit = true; }
	} else if (world == W_BIOLUM) {
		float n = F(1.9, 5);
		if (n < 0.5) { S.ramp = R_SEA; S.v = 0.3 + n * 0.5; }
		else {
			S.ramp = R_ALIEN; S.v = 0.35 + (n - 0.5) * 1.5;
			float dusk = min(1.0, max(0.0, 1.0 - lam / 0.45) * 1.4);
			if (dusk > 0.0) {
				float e = worley3(vec3(px3 * 4.5 + seed, py3 * 4.5, pz3 * 4.5)), lon = atan(pz3, px3);
				float pulse = 0.5 + 0.5 * sin(lon * 5.0 + lat * 4.0 - time * 0.9);
				S.glow = dusk * pow(max(0.0, 1.0 - e / 0.055), 1.3) * (0.4 + 0.6 * pulse);
			}
		}
	} else if (world == W_CARBONA) {
		float e = worley3(vec3(px3 * 3.0 + seed, py3 * 3.0, pz3 * 3.0)), polish = F(2.0, 2);
		float sp = pow(max(0.0, dot(sv, HV)), 9.0);
		S.ramp = R_GRAPHITE; S.v = 0.3 + F(4.0, 3) * 0.25 + sp * polish * 1.1;
		if (e < 0.05) S.v *= 0.35;
		float gh = h3(floor(P * 38.0));
		if (gh < 0.03 && sp > 0.1) S.glint = min(1.0, sp * 2.0) * (0.5 + 0.5 * sin(time * 4.0 + gh * 900.0));
	} else if (world == W_CARBONB) {
		float n = F(1.6, 5);
		if (n < 0.5) { S.ramp = R_TAR; S.v = 0.32 + F(6.0, 2) * 0.12; S.irid = F(2.0, 2) * 1.2 + (1.0 - sv.z) * 0.9 + time * 0.02; }
		else { S.ramp = R_GRAPHITE; S.v = 0.28 + (n - 0.5) * 1.1 + F(5.0, 2) * 0.15; }
	} else if (world == W_CARBONC) {
		if (F(1.3, 3) > 0.6) {
			vec3 fc = floor(P * 14.0);
			float h = h3(fc);
			vec3 u = vec3(sv.x + (h - 0.5) * 0.9, sv.y + (h3(fc + vec3(5.0, 0.0, 0.0)) - 0.5) * 0.9, sv.z + 0.2);
			float s2 = pow(max(0.0, dot(normalize(u), HV)), 22.0);
			S.ramp = R_DIAMOND; S.v = 0.12 + h * 0.32 + s2 * 0.6;
			if (s2 > 0.5) S.glint = s2;
		} else { S.ramp = R_GRAPHITE; S.v = 0.18 + F(3.0, 3) * 0.28; }
	} else if (world == W_MEGACITY) {
		float lon = atan(pz3, px3), ux = lon / (2.0 * PI) * 20.0, uy = (lat + 1.0) * 9.0;
		float gx = fract(ux), gy = fract(uy);
		bool road = gx < 0.16 || gy < 0.16;
		S.ramp = R_CITY; S.v = road ? 0.16 : 0.32 + h3(vec3(floor(ux), floor(uy), 7.0)) * 0.5 + F(5.0, 2) * 0.15;
	} else if (world == W_SCORCHED) {
		S.ramp = R_SCORCH; S.v = 0.35 + F(2.5, 4) * 0.5;
		float g = F(1.2, 2);
		if (g > 0.6) { S.ramp = R_CARBON; S.v = 0.3 + (g - 0.6) * 0.8 + (lam > 0.55 ? 0.35 : 0.0); }
		for (int i = 0; i < n_craters; i++) { float dd = distance(P, craters[i].xyz), cr = craters[i].w; if (dd < cr) S.v += dd > cr * 0.78 ? 0.14 : -0.12; }
	} else if (world == W_ROGUE) {
		// near black: no sun on it, only the faint light of its own auroras
		S.ramp = R_MOON; S.v = F(2.2, 4) > 0.53 ? 0.62 : 0.05;
	} else if (world == W_AURORA) {
		float n = F(1.8, 5);
		if (n < 0.52) { S.ramp = R_SEA; S.v = 0.35 + n * 0.55; } else { S.ramp = R_LAND; S.v = 0.4 + (n - 0.52) * 1.6; }
	} else if (world == W_LIGHTNING) {
		float sw = F(1.5, 2);
		S.ramp = R_STORM2; S.v = 0.2 + F(2.6 + sw, 4) * 0.55 + 0.2 * sin(lat * 7.0 + sw * 5.0);
	} else if (world == W_COMET) {
		float turb = F(2.0, 3) * 0.25; S.ramp = R_ICEGIANT; S.v = 0.5 + 0.25 * sin(lat * 6.0 + turb * 4.0 + seed);
	} else if (world == W_EUROPA) {
		S.ramp = R_ICE; S.v = 0.72 + F(3.0, 3) * 0.2;
		if (abs(F(1.6, 3) - 0.5) < 0.012 || abs(F(3.3, 2) - 0.5) < 0.008) { S.ramp = R_LINEAE; S.v = 0.55 + F(6.0, 2) * 0.3; }
	} else if (world == W_SWAMP) {
		float n = F(2.2, 4);
		if (n < 0.47) { S.ramp = R_SWAMPW; S.v = 0.35 + n * 0.5; } else { S.ramp = R_SWAMP; S.v = 0.35 + (n - 0.47) * 1.4; }
	} else if (world == W_BANDED || world == W_ICEGIANT || world == W_STORM || world == W_VIOLET) {
		bool ice = world == W_ICEGIANT;
		Jet J = jet(ice ? 0.07 : 0.11, px3, py3, pz3);
		float turb = fq(J, py3, 2.0, 3) * (ice ? 0.25 : 0.7);
		S.v = ovals_at(J, lat, 0.5 + 0.32 * sin(lat * bands + turb * 4.0 + seed) + J.streak * (ice ? 0.14 : 0.22));
		Storm g = great_storm(J, lat);
		if (g.kind == 1) { S.ramp = g.ramp; S.v = g.v; } else if (g.kind == 2) S.v += g.v;
	}
	// polar caps
	if (caps > 0.0 && abs(lat) > caps + F(4.0, 2) * 0.12 - 0.06) { S.ramp = R_CLOUD; S.v = 0.8; }
	// clouds, drifting a little faster than the ground
	if (clouds > 0.0) {
		float cang = seed * 1.7 + time * (spin + cloud_rate), cc = cos(cang), cs = sin(cang);
		float qx = tx * cc + sv.z * cs, qz = -tx * cs + sv.z * cc;
		float c = fbm3(vec3(qx * 2.6 + 9.0, ty * 4.0, qz * 2.6), 4);
		if (c > clouds) { S.cloud = true; S.ramp = cloud_ramp; S.v = 0.6 + (c - clouds) * 1.5; }
	}
	#undef F
	return S;
}

// one sample, only to ask whether a neighbouring pixel burns or glints
Surf surf_at(float x, float y, vec3 HV) {
	float q2 = (x * x + y * y) / (r * r);
	vec3 sv = vec3(x / r, y / r, sqrt(max(0.0, 1.0 - q2)));
	return surf(sv, x, y, max(0.0, dot(sv, light)), HV);
}

// ---------------------------------------------------------------- the light it gives off
float night_of(vec3 v) { float d = dot(v, light); return d > 0.12 ? 0.0 : (d < -0.12 ? 1.0 : (0.12 - d) / 0.24); }

// THE AURORA: an oval of curtains round each magnetic pole, green at the foot,
// violet at the top, rays rippling along it; on the face a glowing band with a
// soft glow inside it, and at the edge of the world it rises above the limb.
vec3 aurora(vec3 pb, float hgt, float wash) {
	vec3 acc = vec3(0.0);
	for (int i = 0; i < 2; i++) {
		float pole = i == 0 ? 1.0 : -1.0;
		float colat = acos(clamp(dot(pb, aur_ax[i]), -1.0, 1.0));
		float ph = atan(dot(pb, aur_e2[i]), dot(pb, aur_e1[i]));
		float th = 0.3 + 0.05 * sin(ph * 3.0 + time * 0.35 + pole) + 0.025 * sin(ph * 7.0 - time * 0.6);
		float ray = 0.35 + 0.65 * max(0.0, sin(ph * 23.0 + time * 1.7 + 3.0 * sin(ph * 5.0 - time * 0.5))) * (0.6 + 0.4 * sin(ph * 4.0 + time * 0.9 + pole * 2.0));
		float w = 1.6 / r;
		float band = exp(-pow((colat - th) / w, 2.0));
		// the soft glow lying inside the ring, toward the pole
		float inner = (colat < th && colat > th - 0.14) ? (1.0 - (th - colat) / 0.14) * 0.45 : 0.0;
		float fade = exp(-hgt / 0.05), hi = clamp(hgt / 0.108, 0.0, 1.0);
		float K = (unlit ? 3.4 : 1.3) * (i == 0 ? 1.0 : 0.8) * wash;
		// a sun's flare at its height sets them flickering (eased: two slow beats, never a strobe)
		K *= 1.0 + flare * (0.35 + 0.35 * sin(time * 9.0 + pole * 1.7) * sin(time * 3.7));
		acc += (band * ray * fade) * K * vec3(0.25 + hi * 0.55, 1.0 - hi * 0.7, 0.45 + hi * 0.5);
		if (hgt <= 0.0) acc += inner * (0.4 + 0.6 * ray) * K * 0.5 * vec3(0.2, 1.0, 0.5);
	}
	return acc;
}

// the world's own point turned to where it shows on screen, and back
vec3 to_body(vec3 sv) {
	float ang = seed + time * spin, ca = cos(ang), sa = sin(ang), ct = cos(tilt), st = sin(tilt);
	float tx = sv.x * ct - sv.y * st, ty = sv.x * st + sv.y * ct;
	return vec3(tx * ca + sv.z * sa, ty, -tx * sa + sv.z * ca);
}

void fragment() {
	float S2 = float(2 * half_size + 1);
	vec2 pix = floor(UV * S2) - vec2(float(half_size));
	// each block sampled at its MIDDLE: at its corner the disc sat half a block
	// up and left, and a small world came out lopsided
	if (cell > 1) pix = floor(pix / float(cell)) * float(cell) + 0.5 * float(cell - 1);
	pix -= ctr_off;
	float x = pix.x, y = pix.y;
	vec3 L = light;
	vec3 HV = normalize(L + vec3(0.0, 0.0, 1.0));
	vec3 acc = vec3(0.0);
	vec4 base = vec4(0.0);
	float d2 = (x * x + y * y) / (r * r);

	// EVAPORATING: its air blown off the night side in a plume that thins and ripples away
	if ((flags & F_TAIL) != 0 && d2 > 1.0) {
		vec2 u = normalize(-L.xy + vec2(1e-5));
		float len = r * 3.0, curv = 0.35, d = length(pix);
		float along = dot(pix, u), sd = -pix.x * u.y + pix.y * u.x;
		float I = 0.3 * exp(-(d - r) / 2.2) * (0.35 + 0.65 * max(0.0, along / d));
		if (along > 0.0 && along < len) {
			float sN = along / len, mid = curv * sN * sN * r * 2.0, wd = r * (0.5 + sN * 1.2), q = (sd - mid) / wd;
			float gas = fbm3(vec3(along * 0.11 - time * 1.8, q * 2.2, seed + time * 0.05), 3), streak = 0.6 + 0.4 * sin(q * 9.0 + gas * 5.0);
			I += 1.5 * pow(1.0 - sN, 1.5) * exp(-q * q * 2.4) * (0.35 + gas) * streak;
		}
		float sN2 = max(0.0, along) / len;
		if (I > 0.02) acc += I * (sN2 < 0.45 ? vec3(0.55, 0.9, 1.0) : vec3(0.3, 0.5, 1.0));
	}

	if (d2 > 1.0) {
		float dd = sqrt(x * x + y * y);
		vec2 nn = vec2(x, y) / dd;
		// the air outside the edge: light, thinning with height, brightest on the sunward side
		if (radiant && has_atm) {
			// RADIANT: the air a shell a few percent of the radius deep (thicker for a
			// thick air), lit on the star's side and, backlit, glowing all round
			float th = thick ? 2.5 + 0.14 * r : 1.4 + 0.08 * r;
			if (dd - r < th) {
				float h = (dd - r) / th;
				float lit = max(0.0, (dot(nn, L.xy) + 0.35) / 1.35);
				float fwd = max(0.0, -L.z);
				acc += atm * (0.12 + 0.75 * lit + 1.4 * fwd) * pow(1.0 - h, 1.6) * (thick ? 1.0 : 0.8) * k_light;
			}
		} else if (has_atm && d2 < pow(1.0 + (thick ? 4.5 : 1.6) / r, 2.0)) {
			float lit = max(0.0, (dot(nn, L.xy) + 0.45) / 1.45), hgt = (dd - r) / (thick ? 4.5 : 1.6);
			float a = (0.08 + lit * 0.55) * pow(1.0 - hgt, thick ? 1.4 : 0.6);
			if (a > 0.03) acc += a * 0.95 * atm;
		}
		// auroras rising above the limb
		if ((flags & F_AURORA) != 0) {
			float hgt = dd / r - 1.0;
			if (hgt < 0.13) {
				vec3 pv = vec3(nn, 0.0);
				float wash = unlit ? 1.0 : 1.0 - 0.85 * (1.0 - night_of(pv));
				acc += aurora(to_body(pv), hgt, wash) * 1.1;
			}
		}
	} else {
		float nz = sqrt(1.0 - d2), nx = x / r, ny = y / r;
		vec3 nv = vec3(nx, ny, nz);
		float lam = max(0.0, dot(nv, L));
		// the shadow of the rings across the world
		float rs = 1.0;
		vec3 RN = vec3(0.0, 0.96, -0.28);
		float rdl = dot(L, RN);
		if (ring && abs(rdl) > 1e-3 && ring_mode == 0) {
			float sR = -dot(nv, RN) / rdl;
			if (sR > 0.0) { float rho = length(nv + sR * L); if (rho > 1.5 && rho < 2.2) rs = (rho > 1.82 && rho < 1.88) ? 0.75 : 0.35; }
		} else if (ring && abs(rdl) > 1e-3) {
			// four points across the pixel, so a gap thinner than it still lightens it
			float cov = 0.0;
			for (int i = 0; i < 4; i++) {
				float ax = x + (i == 0 || i == 2 ? -0.25 : 0.25) * float(cell), ay = y + (i < 2 ? -0.25 : 0.25) * float(cell);
				float q2 = min(1.0, (ax * ax + ay * ay) / (r * r));
				vec3 sv = vec3(ax / r, ay / r, sqrt(1.0 - q2));
				float sR = -dot(sv, RN) / rdl;
				if (sR > 0.0) {
					float rho = length(sv + sR * L);
					if (rho > ring_in && rho < ring_out) cov += texture(ring_prof, vec2((rho - ring_in) / (ring_out - ring_in), 0.5)).r;
				}
			}
			rs = 1.0 - ring_cast * cov * 0.25;
		}
		// A MOON'S SHADOW ON THE FACE (Jon: "shouldn't moons cast eclipses on their
		// planets?"): where the light toward the star from this point passes the
		// moon, a small dark spot -- the umbra the moon's own size, a soft penumbra
		// widening with its distance (PAINTED: crisp, two tones)
		for (int k = 0; k < 4; k++) {
			if (k >= n_moon_sh) break;
			vec4 M = moon_sh[k];
			vec3 d3 = M.xyz - vec3(x, y, nz * r);
			float tm = dot(d3, L);
			if (tm <= 0.0) continue;
			float perp = length(d3 - tm * L);
			// (a little wider than the moon is drawn: the moons are glyphs a pixel or two
			// across, and a spot that small fell inside a single block)
			float um = max(M.w, 1.2) * 1.6;
			float pen = um * 0.9 + tm * 0.02;
			float lit = painted ? (perp < um ? 0.0 : (perp < um + pen * 0.6 ? 0.5 : 1.0)) : smoothstep(um * 0.7, um + pen, perp);
			rs *= mix(0.12, 1.0, lit);
		}
		float shade = 0.1 + 0.9 * lam * rs * k_light * (1.0 + 0.1 * flare);
		// (the showcase's lit side: its middle tones carried up, so a world reads lit
		// across its face and not as a thin crescent on a dark ball)
		if (lift > 0.0) shade = mix(shade, 0.1 + 0.95 * pow(clamp(lam * rs * k_light * (1.0 + 0.1 * flare), 0.0, 1.0), 0.62), lift);
		if (rich > 0.0) {
			shade = mix(shade, smoothstep(0.06, 0.62, shade), rich);
			float limb = pow(1.0 - nz, 2.5) * max(0.0, dot(normalize(vec2(nx, ny) + vec2(1e-5)), normalize(L.xy + vec2(1e-5))));
			shade *= 1.0 + rich * 0.6 * limb;
		}
		// four samples a pixel; the commonest kind of ground wins
		// (kept in plain arrays: some drivers cannot store a struct into an array at a varying index)
		int a_ramp[4]; float a_v[4]; vec3 a_emit[4]; bool a_has[4]; float a_glow[4]; float a_glint[4]; float a_irid[4];
		int ns = 0;
		for (int i = 0; i < 4; i++) {
			float ax = x + (i == 0 || i == 2 ? -0.25 : 0.25), ay = y + (i < 2 ? -0.25 : 0.25), q2 = (ax * ax + ay * ay) / (r * r);
			if (q2 <= 1.0) {
				Surf o = surf(vec3(ax / r, ay / r, sqrt(1.0 - q2)), x, y, lam, HV);
				a_ramp[ns] = o.ramp; a_v[ns] = o.v; a_emit[ns] = o.emit; a_has[ns] = o.has_emit; a_glow[ns] = o.glow; a_glint[ns] = o.glint; a_irid[ns] = o.irid;
				ns++;
			}
		}
		if (ns == 0) {
			Surf o = surf(nv, x, y, lam, HV);
			a_ramp[0] = o.ramp; a_v[0] = o.v; a_emit[0] = o.emit; a_has[0] = o.has_emit; a_glow[0] = o.glow; a_glint[0] = o.glint; a_irid[0] = o.irid;
			ns = 1;
		}
		int ramp = a_ramp[0], best = 0;
		for (int i = 0; i < ns; i++) {
			int c = 0;
			for (int j = 0; j < ns; j++) if (a_ramp[j] == a_ramp[i]) c++;
			if (c > best) { best = c; ramp = a_ramp[i]; }
		}
		float v = 0.0, gv = 0.0, gl = 0.0, ir = 0.0;
		int n = 0, emits = 0, irn = 0;
		vec3 emit = vec3(0.0);
		bool has_emit = false;
		for (int i = 0; i < ns; i++) {
			if (a_ramp[i] == ramp) { v += a_v[i]; n++; }
			if (a_has[i]) { emits++; if (!has_emit) { emit = a_emit[i]; has_emit = true; } }
			gv += a_glow[i]; gl += a_glint[i];
			if (a_irid[i] >= 0.0) { ir += a_irid[i]; irn++; }
		}
		v /= float(n); gv /= float(ns); gl /= float(ns);
		bool cloud = ramp == cloud_ramp || ramp == R_CLOUD;
		if (emits * 2 < ns) has_emit = false;
		float sh = unlit ? 0.38 : shade;
		float vr = rich > 0.0 ? clamp(0.5 + (v - 0.5) * (1.0 + 0.7 * rich), 0.0, 1.0) : v;
		vec3 col = (has_emit && !cloud) ? emit : ramp_at(ramp, min(0.999, max(0.0, vr * sh)), x, y);
		// the star's colour on the lit side, the sky's light on the night side,
		// strongest at the limb where it wraps round (in a few dithered steps, and
		// less on a small world, so it keeps its silhouette)
		if (!unlit && !(has_emit && !cloud) && (night_fill.r + night_fill.g + night_fill.b > 0.0 || star_tint != vec3(1.0))) {
			vec3 cl = pow(col, vec3(2.2));
			cl *= mix(vec3(1.0), star_tint, 0.35 * min(1.0, lam * rs * 1.5));
			float small = clamp((18.0 - r) / 10.0, 0.0, 1.0);
			float fk = (1.0 - min(1.0, lam * 2.0)) * (0.14 + 0.9 * pow(1.0 - nz, 2.0)) * mix(1.0, 0.35, small);
			fk = floor(fk * 4.0 + (bayer2(x, y) + 0.5) / 4.0) / 4.0;
			cl += night_fill * fk;
			col = pow(cl, vec3(1.0 / 2.2));
		}
		if (painted && !unlit && !(has_emit && !cloud)) {
			// THE CEL BANDS (B): the light carries the ball, the ground lifts or drops
			// its step by one; small worlds bold and simple, a crescent that reads
			float s = v > 0.62 ? 1.0 : (v < 0.38 ? -1.0 : 0.0);
			if (r < 4.5) s = 0.0;
			float lamS = dot(nv, L) * rs * k_light * (1.0 + 0.1 * flare) - (1.0 - rs) * 0.35;
			float lamF = dot(nv, normalize(L + vec3(0.0, 0.0, 0.6))) * rs * k_light;
			float tw = 0.8 * float(max(cell, 1)) / max(r, 1.0);
			float c;
			if (lamS > 0.1 + tw && lamF > 0.66) c = 6.0 + min(s, 1.0);
			else if (lamS > 0.1 + tw) c = 4.0 + s;
			else if (lamS > 0.1 - tw && r > 4.5) c = p_chk(x, y) ? 4.0 + min(s, 0.0) : 2.0;
			else if (lamS > 0.1) c = 4.0 + min(s, 0.0);
			else c = (s > 0.0 && lamS > -0.25) ? 2.0 : 1.0;
			c = clamp(c, 1.0, 7.0);
			// the edge: an outline on the night side, the sky's light just inside it,
			// a lit rim on the day side
			float pr = float(max(cell, 1)) / r;
			vec2 o = vec2(nx, ny);
			vec2 L2 = normalize(L.xy + vec2(1e-4, 0.0));
			bool outN = false, outD = false, out2 = false;
			for (int k = 0; k < 4; k++) {
				vec2 dd = k == 0 ? vec2(1.0, 0.0) : (k == 1 ? vec2(-1.0, 0.0) : (k == 2 ? vec2(0.0, 1.0) : vec2(0.0, -1.0)));
				vec2 on = o + dd * pr;
				if (dot(on, on) >= 1.0) {
					if (dot(dd, L2) < 0.15) outN = true; else outD = true;
				}
				vec2 o2 = o + dd * pr * 2.0;
				if (dot(o2, o2) >= 1.0 && dot(dd, L2) < -0.3) out2 = true;
			}
			int ci = int(c);
			if (outN && lamS < 0.55 && r > 3.5) col = p_out;
			else if (outD && lamS > 0.35 && r > 6.0) col = p_ext(ramp, 7);
			else if (out2 && lamS < 0.0 && r > 9.0) col = p_bounce;
			else col = p_ext(ramp, ci);
		}
		if (radiant && !painted && !unlit && !(has_emit && !cloud)) {
			// RADIANT: the ground's colour as an albedo (linear), lit
			// (between the ramp's steps, not dithered: the light carries the shading, and
			// the palette's own dither steps it)
			float va = clamp(vr * 0.85 + 0.1, 0.0, 0.999) * 6.0 - 0.5;
			int vi = int(floor(va));
			vec3 alb = pow(mix(rampc(ramp, vi), rampc(ramp, vi + 1), clamp(va - float(vi), 0.0, 1.0)), vec3(2.2));
			float ld = dot(nv, L);
			// (a very wide soft terminator: the light wraps well past the half-way line,
			// as a ball of gas lit by a disc does)
			float lamR = pow(clamp((ld + r_wrap) / (1.0 + r_wrap), 0.0, 1.0), 1.4) * rs * k_light * (1.0 + 0.15 * flare);
			vec3 cR = alb * (star_tint * r_wk.x * lamR + night_fill * r_wk.y * (0.55 + 0.45 * nz));
			cR += night_fill * r_wk.z * pow(1.0 - nz, 2.0) * (0.5 + dot(alb, vec3(0.333)));
			// THE GAS IN FRONT OF IT: the world sits IN the glowing cloud, whose light
			// washes over it, most at its limb where the line of sight runs through more
			// gas, so it is softer and lower in contrast than a painted disc
			float wash = r_haze.x + r_haze.y * pow(1.0 - nz, 1.5);
			cR = cR * (1.0 - wash) + night_fill * r_haze.z * wash;
			col = pow(vec3(1.0) - exp(-cR * r_wk.w), vec3(1.0 / 2.2));
			// (in steps, dithered on the world's own grid: continuous, it fell between
			// the palette's colours differently every frame of a zoom and shimmered)
			col = floor(col * 20.0 + (bayer2(x, y) + 0.5) / 4.0) / 20.0;
		}
		base = vec4(col, 1.0);

		// the air seen edge-on round the rim of the disc, lit where the sun is
		if (radiant && has_atm) {
			float rim = pow(1.0 - nz, 2.0), ls = max(0.0, (dot(nv, L) + 0.4) / 1.4);
			acc += rim * (ls * (thick ? 1.1 : 0.75) + max(0.0, -L.z) * 1.5) * atm * k_light;
		} else if (has_atm) { float rim = pow(1.0 - nz, 2.2), ls = max(0.0, (dot(nv, L) + 0.3) / 1.3); if (rim * ls > 0.02) acc += rim * ls * (thick ? 0.9 : 0.55) * atm; }
		// the jungle's veins of light
		if (gv > 0.03) acc += gv * 2.4 * vec3(0.25, 1.0, 0.85);
		// a diamond's glint: a small cross of light, gathered from its neighbours
		if (world == W_CARBONA || world == W_CARBONC) {
			vec3 W3 = vec3(1.0, 0.97, 0.88);
			if (gl > 0.12 && lam > 0.0) acc += gl * 1.7 * W3;
			for (int k = 0; k < 4; k++) {
				vec2 o = k == 0 ? vec2(1.0, 0.0) : (k == 1 ? vec2(-1.0, 0.0) : (k == 2 ? vec2(0.0, 1.0) : vec2(0.0, -1.0)));
				for (int s = 1; s <= 2; s++) {
					vec2 q = vec2(x, y) + o * float(s);
					if (dot(q, q) > r * r) continue;
					float g = surf_at(q.x, q.y, HV).glint;
					if (g > 0.12 && (s == 1 || g > 0.6)) acc += g * 1.7 * (s == 1 ? 0.35 : 0.12) * W3;
				}
			}
		}
		// an oil slick's colours, strongest where the tar turns away from you
		if (irn * 2 > ns && lam > 0.0) {
			float h = ir / float(irn), fr = pow(1.0 - nz, 1.6) * 0.26 * min(1.0, lam * 3.0);
			acc += fr * (0.5 + 0.5 * cos(2.0 * PI * vec3(h, h + 0.33, h + 0.67)));
		}
		// the sun's glint on open water, sliding over it as the world turns
		float wet = ramp == R_SEA ? 1.0 : (ramp == R_SWAMPW ? 0.7 : (ramp == R_ICE ? 0.35 : (ramp == R_TAR ? 1.3 : 0.0)));
		if (world == W_BIOLUM) wet *= 0.15;
		if (wet > 0.0 && !cloud && lam > 0.0) {
			float g = pow(max(0.0, dot(nv, HV)), 60.0) * wet * rs;
			if (painted) {
				// (B: a 1-2 block glint, a sparkle's colours)
				if (g > 0.5) base.rgb = vec3(1.0, 0.965, 0.886);
				else if (g > 0.22) base.rgb = vec3(1.0, 0.847, 0.627);
			} else if (g > 0.01) acc += g * 1.4 * vec3(1.0, 0.94, 0.8);
		}
		// CITY LIGHTS on the night side: towns clustered on the land, a bright
		// heart to the big ones; a planet-city lit along its streets
		if ((flags & F_CITY) != 0) {
			float kn = night_of(nv);
			if (kn > 0.0) {
				vec3 pb = to_body(nv);
				float I = 0.0;
				if ((flags & F_MEGACITY) != 0) {
					float lon = atan(pb.z, pb.x), lat = pb.y;
					float gx = abs(fract(lon / (2.0 * PI) * 20.0 + 0.5) - 0.5), gy = abs(fract((lat + 1.0) * 4.5 + 0.5) - 0.5);
					float street = max(step(gx, 0.05), step(gy, 0.05));
					I += street * (0.25 + 0.5 * h3(floor(pb * r * 1.4))) * 1.2;
					for (int i = 0; i < n_towns; i++) { float d = distance(pb, towns[i].xyz); I += towns[i].w * exp(-d * d / 0.008) * 1.1 * step(h3(floor(pb * r * 1.4) + 3.0), 0.7); }
				} else if (fbm3(vec3(pb.x * 1.8 + seed, pb.y * 1.8, pb.z * 1.8 - seed), 5) >= 0.4) {
					float dens = 0.0;
					for (int i = 0; i < n_towns; i++) {
						float sz = towns[i].w, sd = 0.02 + sz * 0.07, d = distance(pb, towns[i].xyz);
						dens += (0.35 + sz) * exp(-d * d / (2.0 * sd * sd)) * (1.0 + sz * 6.0);
					}
					// the lights themselves: points scattered where the towns are thick
					float speck = h3(floor(pb * r * 1.3));
					I += dens > speck * 3.0 ? min(1.6, dens * 0.6) : 0.0;
				}
				acc += I * kn * (world == W_MEGACITY ? 0.32 : 0.42) * vec3(1.0, 0.6, 0.24) * 1.8;
			}
		}
		// auroras on the face
		if ((flags & F_AURORA) != 0) {
			float wash = unlit ? 1.0 : 1.0 - 0.85 * (1.0 - night_of(nv));
			acc += aurora(to_body(nv), 0.0, wash);
		}
		// LIGHTNING lights the cloud round it, the bright cloud tops most; the bolt itself on each strike
		for (int i = 0; i < n_flashes; i++) {
			vec4 f = flashes[i];
			float dd = distance(vec2(x, y), f.xy);
			float gI = f.w * exp(-dd * dd / (2.0 * f.z * f.z)) * (0.15 + v * v * 3.0);
			acc += gI * vec3(0.8, 0.95, 1.25);
		}
		for (int i = 0; i < n_bolts; i++) {
			vec2 b = bolts[i] - vec2(0.5);
			vec2 dlt = abs(vec2(x, y) - b);
			if (dlt.x < 1.0 && dlt.y < 1.0) acc += 1.6 * (1.0 - dlt.x) * (1.0 - dlt.y) * vec3(0.9, 0.95, 1.0);
		}
		// anything burning lights the ground round it
		if (world == W_LAVA || world == W_CRACKED || world == W_VOLCANIC || world == W_HOTJUP || world == W_CRYSTAL) {
			for (int dy = -2; dy <= 2; dy++) for (int dx = -2; dx <= 2; dx++) {
				if (dx == 0 && dy == 0) continue;
				vec2 q = vec2(x + float(dx), y + float(dy));
				if (dot(q, q) > r * r) continue;
				Surf o = surf_at(q.x, q.y, HV);
				if (o.has_emit && !o.cloud) acc += exp(-float(dx * dx + dy * dy) / 1.4) * 0.16 * o.emit;
			}
		}
	}

	// a world behind the star hides where the star's disc is
	vec2 at = centre + vec2(x, y);
	// the light, added in a few dithered steps
	float dth = painted ? 0.5 : (bayer2(x, y) + 0.5) / 4.0;
	vec3 q = max(vec3(0.0), floor((1.0 - exp(-1.6 * acc)) * 6.0 + dth - 0.5)) / 6.0;
	if (distance(at, star_at) < star_r) COLOR = vec4(0.0);
	else if (base.a > 0.0) COLOR = vec4(min(vec3(1.0), base.rgb + q), 1.0);
	else COLOR = vec4(q, 0.0);
}
