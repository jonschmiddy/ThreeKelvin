shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// A SYSTEM'S SUN, painted per game pixel: the approved mockup's star painter
// ("Twenty-Four Stars", Jon: "These are great. Bang. Done.", sealed as `ST` in
// the scratchpad's `sysmap/page/index.html`) on the GPU, for the ordinary, red
// and blue suns. A pulsar and the Core have their own painters.
//
// The mockup adds light up per pixel in a 420x300 box round the star, in the
// order its layers are drawn, then tone maps each pixel, dithers it on a 4x4
// Bayer grid and takes the nearest colour of its own palette. This does the
// same per pixel, in the same order, because two parts of it are not additive:
// the CARVED nebula darkens whatever light is behind it, and the star's FACE
// replaces everything drawn before it (its glow, the far half of a disc of gas)
// and is then lit by everything drawn after (spikes, loops of gas, flares).
//
// What the mockup splatted point by point -- sparks, the legs of a flare, a
// spray of droplets, an arcade of loops, the ribbons -- comes in from
// `SunView.gd` as a short list of whole pixels, worked out in double precision
// as the mockup did; lumps of torn light (a flare's loop, a corona's puffs) come
// in as a list of discs, each torn here by the same noise. The prominences and
// the diffraction spikes are traced here, sample by sample, because they are on
// every frame of the stars that have them and the CPU has better things to do.
//
// Laid onto the map as the mockup's `layOn` laid it: the star's own face solid,
// everything else ADDED as light (alpha 0, premultiplied), with the faintest
// colours dropped and the next faintest faded in, so the box never shows.
//
// ZOOMED (`zoom` k, 1 to 4), the star is drawn again k times bigger, not
// stretched: each game pixel of the k-times box is the mockup's picture
// sampled at its place in the 420x300 box, (pixel - centre) / k, so every
// length -- radius, cells, plumes, glow, flares -- grows by k and the pixels
// stay single game pixels. What the mockup put down as whole pixels (the
// splats, the prominences, the spikes) is put down again at the zoomed
// scale: the curves are traced k times finer and k times wider, a splat
// becomes a k-pixel dot. At k = 1 every sum is the one the mockup made.

// ---------------------------------------------------------------- uniforms
uniform float time = 0.0;
// 0 an ordinary sun, 1 a red giant, 2 a blue giant: which surface ramp
uniform int kind = 0;
uniform float R = 16.0;
uniform float limb = 0.6;
uniform float spin = 0.05;
uniform vec3 glow_c = vec3(1.0, 0.62, 0.22);
uniform float glow_r = 3.5;
uniform float glow_w = 0.45;
uniform float glow_i = 0.8;
uniform float gran = 0.0;
uniform float gran_k = 0.3;
uniform float cells = 0.0;
uniform float lumpy = 0.0;
uniform float breath = 0.0;
uniform bool embers = false;
uniform float oblate = 0.0;
uniform float eq_tilt = 0.0;
uniform float gdark = 0.0;
// the blue giant's flicker this moment (1 when it has none)
uniform float flick = 1.0;
uniform float shimmer = 0.0;
uniform float spikes = 0.0;
uniform vec3 spike_c = vec3(0.75, 0.9, 1.0);
// each spike's direction and its length this moment, as a share of `spikes`
uniform vec4 arms[8];
uniform float rays = 0.0;
uniform vec3 rays_c = vec3(0.75, 0.9, 1.0);
uniform int layers = 0;
// the carved nebula's offset, the mockup's seed * 3.1
uniform float carve_sd = 0.0;
// each plume: (cos a, sin a, length, fade) and (bend, id, index, on)
uniform vec4 plume_a[4];
uniform vec4 plume_b[4];
// each prominence: its feet (x0, y0, x1, y1) and its top (mx, my, base angle)
uniform vec4 prom_p[4];
uniform vec4 prom_q[4];
uniform int n_proms = 0;
// sunspot groups: centre, east and north on the sphere, and tilt, reach, id
uniform vec4 g_c[2];
uniform vec4 g_e[2];
uniform vec4 g_n[2];
uniform ivec2 g_count = ivec2(0);
uniform int n_groups = 0;
// rows of `data`: 0 the points' pixels and how far off them the point really
// was (X, Y, x - X, y - Y), 1 their light; 2, 3, 4 the discs
// (x, y, w, before-the-face), (light), (g * 9, u * 1.5); 5 the groups' members
uniform sampler2D data : filter_nearest, repeat_disable;
uniform int n_points = 0;
uniform vec4 pts_box = vec4(0.0);
uniform int n_blobs = 0;
// the discs' bounds, (x0, y0, x1, y1) in the box
uniform vec4 blob_box = vec4(0.0);
// how many times bigger the star is drawn, and half the drawn box in game
// pixels (the star's centre is that far in from its top-left corner)
uniform float zoom = 1.0;
uniform vec2 box_h = vec2(210.0, 150.0);
// a mass ejection's bubble: (x, y, radius, on), (cos, sin, g, u), its fade
uniform vec4 cme_a = vec4(0.0);
uniform vec4 cme_b = vec4(0.0);
uniform float cme_fade = 0.0;
// the ribbons' wave over the face: (x, y, radius, strength)
uniform vec4 wave = vec4(0.0);

const float BW = 420.0;
const float BH = 300.0;
const float CXB = 210.0;
const float CYB = 150.0;

const int DUST = 1;
const int PLUMES = 2;
const int WIND = 4;
const int LOBES = 8;
const int BEDISC = 16;
const int CARVE = 32;
const int CORONA = 64;

const vec3 SPACE = vec3(0.02, 0.024, 0.04);
const vec3 L_RED = vec3(0.85, 0.22, 0.1);
const vec3 L_BLU = vec3(0.35, 0.6, 1.0);
const vec3 L_ICE = vec3(0.75, 0.9, 1.0);
const vec3 L_PINK = vec3(0.9, 0.3, 0.45);
const vec3 L_DUST = vec3(0.42, 0.22, 0.12);
const vec3 HOT = vec3(1.0, 0.92, 0.75);

const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

// ON THE MAP, every other colour only: Jon's "sun a", single pixels with half
// its palette, which the map's palette pass gave it before the sun was drawn
// among the worlds instead of under that pass.
uniform bool half_pal = false;
// HOW CHUNKY (Jon: "the red hypergiant needs to look more pixellated"): the star
// worked out in cell x cell blocks of game pixels, and every pal_stride-th colour
// of its palette only. 1 and 1 are the mockup's own.
uniform int cell = 1;
uniform int pal_stride = 1;

// the mockup's own palette (`PALHEX`), in bytes
const vec3 PAL[44] = vec3[](
	vec3(5.0, 6.0, 10.0), vec3(11.0, 18.0, 32.0), vec3(51.0, 68.0, 90.0), vec3(201.0, 216.0, 234.0), vec3(255.0, 255.0, 255.0),
	vec3(30.0, 8.0, 4.0), vec3(58.0, 14.0, 8.0), vec3(94.0, 22.0, 8.0), vec3(132.0, 40.0, 12.0), vec3(168.0, 58.0, 16.0),
	vec3(194.0, 74.0, 20.0), vec3(224.0, 106.0, 32.0), vec3(236.0, 122.0, 38.0), vec3(248.0, 154.0, 58.0), vec3(255.0, 176.0, 84.0),
	vec3(255.0, 208.0, 112.0), vec3(255.0, 220.0, 150.0), vec3(255.0, 238.0, 192.0), vec3(255.0, 246.0, 226.0), vec3(42.0, 6.0, 8.0),
	vec3(74.0, 12.0, 12.0), vec3(110.0, 20.0, 16.0), vec3(150.0, 32.0, 24.0), vec3(188.0, 50.0, 32.0), vec3(216.0, 74.0, 42.0),
	vec3(238.0, 106.0, 58.0), vec3(255.0, 138.0, 80.0), vec3(106.0, 26.0, 52.0), vec3(160.0, 40.0, 74.0), vec3(216.0, 74.0, 106.0),
	vec3(255.0, 122.0, 138.0), vec3(10.0, 16.0, 48.0), vec3(16.0, 32.0, 96.0), vec3(26.0, 58.0, 138.0), vec3(42.0, 90.0, 184.0),
	vec3(74.0, 138.0, 216.0), vec3(138.0, 208.0, 240.0), vec3(200.0, 240.0, 255.0), vec3(230.0, 246.0, 255.0), vec3(52.0, 120.0, 160.0),
	vec3(79.0, 166.0, 196.0), vec3(42.0, 24.0, 16.0), vec3(74.0, 42.0, 24.0), vec3(106.0, 62.0, 34.0)
);
// each kind's surface, dark limb to hot middle, as places in the palette
const int RAMP_SUN[6] = int[](7, 10, 12, 14, 16, 18);
const int RAMP_RED[6] = int[](19, 21, 23, 25, 26, 14);
const int RAMP_BLU[6] = int[](33, 34, 35, 36, 37, 4);

// ---------------------------------------------------------------- noise, as the mockup's
// The star painter's own hashes (not the planets'): the same integer mixing,
// so the same lattice values, so a sun's surface is the mockup's surface.
float hsh(float x, float y) {
	uint h = (uint(int(x)) * 374761393u) ^ (uint(int(y)) * 668265263u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}
float hsh3(float x, float y, float z) {
	uint h = (uint(int(x)) * 374761393u) ^ (uint(int(y)) * 668265263u) ^ (uint(int(z)) * 1442695041u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}
float sm(float u) { return u * u * (3.0 - 2.0 * u); }
float noise(float x, float y) {
	float xi = floor(x), yi = floor(y), u = sm(x - xi), v = sm(y - yi);
	float a = hsh(xi, yi), b = hsh(xi + 1.0, yi), c = hsh(xi, yi + 1.0), d = hsh(xi + 1.0, yi + 1.0);
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
float noise3(float x, float y, float z) {
	float xi = floor(x), yi = floor(y), zi = floor(z), u = sm(x - xi), v = sm(y - yi), w = sm(z - zi);
	float a = mix(mix(hsh3(xi, yi, zi), hsh3(xi + 1.0, yi, zi), u), mix(hsh3(xi, yi + 1.0, zi), hsh3(xi + 1.0, yi + 1.0, zi), u), v);
	float b = mix(mix(hsh3(xi, yi, zi + 1.0), hsh3(xi + 1.0, yi, zi + 1.0), u), mix(hsh3(xi, yi + 1.0, zi + 1.0), hsh3(xi + 1.0, yi + 1.0, zi + 1.0), u), v);
	return mix(a, b, w);
}
float fbm(float x, float y) {
	return noise(x, y) * 0.5 + noise(x * 2.03 + 17.0, y * 2.03 + 9.0) * 0.25 + noise(x * 4.1 + 3.0, y * 4.1 + 31.0) * 0.125 + noise(x * 8.3 + 11.0, y * 8.3 + 5.0) * 0.0625;
}
float fbm3(float x, float y, float z) {
	return noise3(x, y, z) * 0.5 + noise3(x * 2.03 + 17.0, y * 2.03 + 9.0, z * 2.03 + 4.0) * 0.25 + noise3(x * 4.1 + 3.0, y * 4.1 + 31.0, z * 4.1 + 13.0) * 0.125 + noise3(x * 8.3 + 11.0, y * 8.3 + 5.0, z * 8.3 + 21.0) * 0.0625;
}
// the mockup's `smooth`, which also runs backwards (a > b) as its plumes use it
float smo(float a, float b, float x) { float u = clamp((x - a) / (b - a), 0.0, 1.0); return u * u * (3.0 - 2.0 * u); }
float sq(float v) { return v * v; }
// JS Math.round, which the mockup's `add` puts every splat through
bool at(vec2 q, float x, float y) { return floor(q.x + 0.5) == x && floor(q.y + 0.5) == y; }
float ang_of(float dy, float dx) { return (dx == 0.0 && dy == 0.0) ? 0.0 : atan(dy, dx); }

vec3 ramp(float v) {
	v = clamp(v, 0.0, 0.999) * 5.0;
	int i = int(floor(v));
	int a, b;
	if (kind == 1) { a = RAMP_RED[i]; b = RAMP_RED[i + 1]; }
	else if (kind == 2) { a = RAMP_BLU[i]; b = RAMP_BLU[i + 1]; }
	else { a = RAMP_SUN[i]; b = RAMP_SUN[i + 1]; }
	return mix(PAL[a], PAL[b], v - float(i)) / 255.0;
}
// the face's colour turned back into the light that would tone map to it
vec3 inv(vec3 c) { return -log(1.0 - clamp(c, vec3(0.0), vec3(0.97))) / 1.35; }

// ---------------------------------------------------------------- the star
float radius_at(float t, float ang) {
	float r = R * (1.0 + (breath > 0.0 ? breath * sin(t * 0.8) : 0.0));
	if (oblate > 0.0) { float a2 = ang - eq_tilt; r /= sqrt(sq(cos(a2)) + sq(sin(a2) / (1.0 - oblate))); }
	// LUMPS THAT MOVE: the edge's bulges swell, sag and wander
	if (lumpy > 0.0) r *= 1.0 + lumpy * ((noise3(cos(ang) * 1.8 + 5.0, sin(ang) * 1.8, t * 0.3) - 0.5) * 2.0 + (noise3(cos(ang) * 4.0 + 2.0, sin(ang) * 4.0 + 7.0, t * 0.5) - 0.5) * 0.8);
	return r;
}

// how dark a point on the sphere is under the sunspot groups (1 = untouched)
float group_shade(vec3 p) {
	float I = 1.0;
	for (int gi = 0; gi < n_groups; gi++) {
		vec3 c = g_c[gi].xyz, e = g_e[gi].xyz, n = g_n[gi].xyz;
		float tilt = g_c[gi].w, reach = g_e[gi].w, id = g_n[gi].w;
		if (dot(p, c) < cos(reach)) continue;
		float le0 = dot(p, e), ln0 = dot(p, n), ct = cos(tilt), st = sin(tilt);
		float le = le0 * ct - ln0 * st, ln = le0 * st + ln0 * ct;
		float shade = 1.0, near = 0.0;
		int cnt = gi == 0 ? g_count.x : g_count.y;
		for (int m = 0; m < cnt; m++) {
			vec4 M = texelFetch(data, ivec2(m + gi * 32, 5), 0);
			float d = length(vec2(le - M.x, ln - M.y));
			if (M.w > 0.5) {
				// a ragged rim, its edge wavering
				float ang = ang_of(ln - M.y, le - M.x);
				float rr = M.z * (0.8 + 0.45 * noise(cos(ang) * 2.0 + M.x * 40.0, sin(ang) * 2.0 + id));
				if (d < rr * 0.42) shade = min(shade, 0.2);
				else if (d < rr) shade = min(shade, 0.56);
				near = max(near, exp(-sq((d - rr) / (rr * 1.2))));
			} else if (d < M.z) shade = min(shade, 0.42);
		}
		// bright patches round the group, where its field breaks through
		I *= shade < 1.0 ? shade : 1.0 + 0.08 * near;
	}
	return I;
}

vec3 face_colour(float dx, float dy, float Rr, float t) {
	float nx = dx / Rr, ny = dy / Rr, nz = sqrt(max(0.0, 1.0 - nx * nx - ny * ny));
	float sp = t * spin, cs = cos(sp), sn = sin(sp);
	float px = nx * cs + nz * sn, pz = -nx * sn + nz * cs, py = ny;
	// limb darkening: the edge is cooler and dimmer
	float I = 1.0 - limb * (1.0 - nz);
	if (gdark > 0.0) { float pole = abs(-dx * sin(eq_tilt) + dy * cos(eq_tilt)) / (R * (1.0 - oblate)); I *= 1.0 + gdark * (pole - 0.4); }
	// granulation: small boiling cells; giant cells for the giants
	if (gran > 0.0) { float g = fbm3(px * gran + t * 0.15, py * gran, pz * gran - t * 0.1); I *= 1.0 - gran_k + gran_k * 2.0 * g; }
	if (cells > 0.0) { float g = noise3(px * cells + t * 0.12, py * cells - t * 0.08, pz * cells + t * 0.05); I *= 0.55 + 0.8 * g * g; }
	// embers: bright seams between dark cells
	if (embers) {
		float c1 = 1.0 - abs(2.0 * fbm3(px * 2.6 + 3.0, py * 2.6, pz * 2.6 + t * 0.03) - 1.0), c2 = 1.0 - abs(2.0 * noise3(px * 7.0 + 9.0, py * 7.0, pz * 7.0 - t * 0.05) - 1.0);
		float crack = smo(0.93, 0.985, c1) + 0.5 * smo(0.95, 0.99, c2) * smo(0.6, 0.9, c1);
		float pulse = 0.7 + 0.45 * noise3(px * 3.0, py * 3.0 + t * 0.35, pz * 3.0);
		float plate = 0.16 + 0.12 * fbm3(px * 6.0 + 1.0, py * 6.0, pz * 6.0);
		float bleed = smo(0.78, 0.95, c1) * 0.22 * pulse;
		I = (plate + bleed + crack * 1.1 * pulse) * (0.55 + 0.45 * nz);
	}
	if (n_groups > 0) I *= group_shade(vec3(px, py, pz));
	I *= flick * (breath > 0.0 ? 1.0 - breath * 2.0 * sin(t * 0.8) : 1.0);
	return ramp(I);
}

// ---------------------------------------------------------------- what lies round it
vec3 glow(float x, float y, float d, float t) {
	float Rg = R * glow_r;
	if (d < R * 0.8 || d > Rg) return vec3(0.0);
	float v = glow_i * exp(-(d - R) / (R * glow_w)) * (1.0 - d / Rg) * flick;
	if (shimmer > 0.0) { float ang = ang_of(y - CYB, x - CXB); v *= 1.0 - shimmer + shimmer * 2.0 * noise(cos(ang) * 3.0 + t * 0.4, sin(ang) * 3.0 + d * 0.05 - t * 0.7); }
	return v > 0.004 ? glow_c * v : vec3(0.0);
}

// A CORONA THAT MOVES: its streamers sway and shift, their gas flows outward
vec3 corona(float dx, float dy, float d, float t) {
	float Rc = R * 3.4, br = 0.85 + 0.15 * sin(t * 0.5), sway = 0.5 * sin(t * 0.15);
	if (d < R || d > Rc) return vec3(0.0);
	float a = ang_of(dy, dx);
	float s0 = 0.5 + 0.5 * cos(a * 3.0 + sway + noise(a * 2.0 + 9.0, t * 0.12) * 3.0), str = s0 * s0 * s0;
	float flow = 0.4 + 1.0 * noise(cos(a) * 10.0 + 3.0, sin(a) * 10.0 + d * 0.09 - t * 0.9);
	float v = 0.5 * (str * 0.85 + 0.2) * flow * exp(-(d - R) / (R * 0.85)) * br;
	return v > 0.004 ? vec3(1.0, 0.78, 0.5) * v * smo(R, R * 1.25, d) : vec3(0.0);
}

// dust shed in shells: broken arcs drifting slowly outward
vec3 dust_shells(float x, float y, float dx, float dy, float d, float t) {
	if (d < R * 1.05) return vec3(0.0);
	float a = ang_of(dy, dx), v = 0.0;
	for (int k = 0; k < 4; k++) {
		float fk = float(k), m = mod(t * 2.5 + fk * 16.0, 64.0), rr = R * 1.2 + m;
		float arc = smo(0.4, 0.7, noise(cos(a) * 2.5 + fk * 7.0, sin(a) * 2.5 + fk * 3.0));
		v += arc * exp(-sq((d - rr) / 2.2)) * (1.0 - m / 64.0);
	}
	v *= 0.55 * (0.6 + 0.6 * fbm(x * 0.12, y * 0.12));
	return v > 0.01 ? L_DUST * v * 1.4 : vec3(0.0);
}

// PLUMES WITH LIFE: rising out of the face, widening and curling, hot at the
// root and cooling to dark dust at the tip
vec3 plumes(float x, float y, float dx, float dy, float t) {
	vec3 acc = vec3(0.0);
	for (int k = 0; k < 4; k++) {
		vec4 A = plume_a[k], B = plume_b[k];
		if (B.w < 0.5) continue;
		float ca = A.x, sa = A.y, len = A.z, fade = A.w, bend = B.x, id = B.y, fk = B.z;
		float reach = R + len + 10.0;
		if (y < floor(CYB - reach) || y > CYB + reach || x < floor(CXB - reach) || x > CXB + reach) continue;
		float s0 = dx * ca + dy * sa - R * 0.9, q = -dx * sa + dy * ca;
		if (s0 < 0.0 || s0 > len + 8.0) continue;
		float curl = bend * s0 * s0 / (R * 2.0) + sin(s0 * 0.08 - t * 0.6 + fk) * s0 * 0.08;
		float w = (3.0 + 2.6 * sqrt(s0)) * (0.65 + 0.7 * noise(s0 * 0.12 - t * 0.5, fk * 7.0 + q * 0.04)), body = exp(-sq((q - curl) / w));
		if (body < 0.03) continue;
		float flow = fbm(q * 0.14 + id * 5.0 + (noise(s0 * 0.05, t * 0.3) - 0.5) * 3.0, s0 * 0.1 - t * 0.7);
		float v = body * smo(len + 6.0, len * 0.4, s0) * smo(0.3, 0.75, flow) * fade * 0.95;
		if (v < 0.02) continue;
		float heat = 1.0 - s0 / (len + 1.0);
		acc += (heat > 0.6 ? vec3(1.0, 0.5, 0.22) : (heat > 0.3 ? L_RED : vec3(0.32, 0.1, 0.05))) * v;
	}
	return acc;
}

// the stellar wind: streaks of gas streaming out in every direction
vec3 wind(float dx, float dy, float d, float t) {
	if (d < R) return vec3(0.0);
	float a = ang_of(dy, dx), s = noise(a * 26.0 + 50.0, d * 0.04 - t * 0.9) * noise(a * 9.0 + 20.0, d * 0.02 - t * 0.5);
	float v = 0.9 * smo(0.25, 0.6, s) * exp(-(d - R) / (R * 2.2));
	return v > 0.01 ? L_BLU * v : vec3(0.0);
}

// TWO LOBES, ALIVE, like Eta Carinae's
vec3 lobes(float dx, float dy, float t) {
	float Rl = R * (1.0 + 0.05 * sin(t * 0.4)), ax = -0.5 + 0.07 * sin(t * 0.23), ca = cos(ax), sa = sin(ax);
	float wv = mod(t, 6.0) * Rl * 1.1;
	float u = dx * ca + dy * sa, v = -dx * sa + dy * ca, au = abs(u);
	float k = 0.0;
	for (int i = 0; i < 2; i++) {
		float sg = i == 0 ? 1.0 : -1.0;
		float cu = sg * Rl * 2.6, eu = (u - cu) / (Rl * 2.2), ev = v / (Rl * 1.6), e = length(vec2(eu, ev));
		if (e > 1.15) continue;
		float shell = exp(-sq((e - 0.95) / 0.12)), fill = 0.35 * (1.0 - e) * (e < 1.0 ? 1.0 : 0.0);
		float tex = 0.45 + 0.9 * fbm(au * 0.09 - t * 0.5, v * 0.11 + sg * 7.0);
		float lit = 1.0 + 1.3 * exp(-sq((au - wv) / (Rl * 0.7)));
		k += (shell * 0.8 + fill) * tex * lit;
	}
	float skirt = exp(-sq(u / (Rl * 0.5))) * exp(-abs(v) / (Rl * 2.4)) * 0.45 * (0.5 + 0.8 * noise(abs(v) * 0.18 - t * 0.9, v > 0.0 ? 3.0 : 9.0));
	return k + skirt > 0.01 ? vec3(0.8, 0.45, 0.4) * k * 0.75 + L_ICE * skirt : vec3(0.0);
}

// CARVING ITS NEBULA: the cloud round it eaten into a hollow, pillars lit on
// the faces toward the star
float dens_at(float x, float y, float t) {
	float d = length(vec2(x - CXB, y - CYB)), a = ang_of(y - CYB, x - CXB);
	return fbm(cos(a) * 2.2 + carve_sd, sin(a) * 2.2 + d * 0.016 + carve_sd) * 0.7 + fbm(x * 0.05 + carve_sd + t * 0.02, y * 0.05) * 0.3 + (d - 60.0) / 150.0 - 0.03 * sin(t * 0.2);
}
vec3 carve(vec3 L, float x, float y, float dx, float dy, float d, float t) {
	if (d < R) return L;
	float n = dens_at(x, y, t) + (fbm(x * 0.12 + t * 0.15, y * 0.12 - t * 0.1) - 0.5) * 0.12;
	float ux = dx / d, uy = dy / d, inward = dens_at(x - ux * 7.0, y - uy * 7.0, t);
	float cloud = smo(0.48, 0.85, n);
	float lit = smo(0.48, 0.66, n) * (1.0 - smo(0.52, 0.72, inward));
	if (cloud > 0.0) { L *= 1.0 - cloud * 0.75; L += vec3(0.05, 0.05, 0.1) * cloud * 0.35; }
	float pch = smo(0.35, 0.75, fbm(x * 0.07 + carve_sd, y * 0.07 - t * 0.1));
	if (lit > 0.02) L += (lit * pch > 0.45 ? L_ICE : L_BLU) * lit * pch * 0.5 * (0.7 + 0.5 * fbm(x * 0.1 + t * 0.2, y * 0.1));
	float wisp = smo(0.55, 0.8, fbm(x * 0.06 - t * 0.12 + (noise(x * 0.02, t * 0.1) - 0.5), y * 0.06 + 9.0 + t * 0.08)) * (1.0 - cloud) * smo(0.3, 0.55, n);
	if (wisp > 0.02) L += L_BLU * wisp * 0.4;
	float hollow = (1.0 - cloud) * 0.3 * exp(-d / 70.0) * (0.7 + 0.5 * noise(x * 0.06, y * 0.06 - t * 0.2));
	if (hollow > 0.01) L += L_BLU * hollow;
	return L;
}

// SPUN FLAT: a disc of gas off its waist; the far half before the face, the
// near half after it
vec3 bedisc(float dx, float dy, float t, bool near) {
	float ce = cos(eq_tilt), se = sin(eq_tilt);
	float u = dx * ce + dy * se, v = (-dx * se + dy * ce) / 0.24;
	if ((v >= 0.0) != near) return vec3(0.0);
	float r = length(vec2(u, v));
	if (r < R * 1.1 || r > R * 3.8) return vec3(0.0);
	float a = ang_of(v, u), sp = t * 0.9 * pow(R * 1.3 / r, 1.5);
	float wv = 0.6 + 0.5 * cos(a + log(r / R) * 2.5 - t * 0.35);
	float tex = 0.55 + 0.7 * noise(cos(a - sp) * r * 0.12 + 5.0, sin(a - sp) * r * 0.12);
	float dens = exp(-(r - R * 1.1) / (R * 1.1)) * smo(R * 1.1, R * 1.3, r);
	float k = dens * wv * tex * 1.7;
	return k > 0.01 ? (r < R * 1.8 ? L_ICE : L_BLU) * k : vec3(0.0);
}

// lumps of torn light: a flare's loop and its flashes, a corona's puffs
vec3 blobs(float x, float y, bool pre) {
	vec3 acc = vec3(0.0);
	if (x < blob_box.x || y < blob_box.y || x > blob_box.z || y > blob_box.w) return acc;
	for (int i = 0; i < n_blobs; i++) {
		vec4 A = texelFetch(data, ivec2(i, 2), 0);
		if ((A.w > 0.5) != pre) continue;
		float d = length(vec2(x - A.x, y - A.y));
		if (d > A.z) continue;
		vec4 B = texelFetch(data, ivec2(i, 3), 0), G = texelFetch(data, ivec2(i, 4), 0);
		acc += B.rgb * (1.0 - d / A.z) * (0.4 + 1.0 * fbm(x * 0.3 + G.x, y * 0.3 - G.y));
	}
	return acc;
}

// a place in the box as a place in the zoomed box, in game pixels
vec2 zoomed(vec2 q) { return box_h + (q - vec2(CXB, CYB)) * zoom; }

// single pixels of light, from SunView's list; zoomed, each is a dot k pixels
// across that starts where the point really was, its edge pixels part lit
vec3 points(float x, float y, vec2 pz) {
	vec3 acc = vec3(0.0);
	if (n_points == 0 || x < pts_box.x - 2.0 || y < pts_box.y - 2.0 || x > pts_box.z + 2.0 || y > pts_box.w + 2.0) return acc;
	float k = zoom, sub = k * clamp(k - 1.0, 0.0, 1.0);
	for (int i = 0; i < n_points; i++) {
		vec4 Q = texelFetch(data, ivec2(i, 0), 0);
		// the dot's top-left corner: at k = 1 the point's own whole pixel
		vec2 a = zoomed(Q.xy) + (0.5 - 0.5 * k + Q.zw * sub);
		vec2 cov = clamp(min(pz + 1.0, a + k) - max(pz, a), vec2(0.0), vec2(1.0));
		float c = cov.x * cov.y;
		if (c <= 0.0) continue;
		if (k > 1.0) c *= clamp(0.5 * k + 0.6 - length(pz + 0.5 - a - 0.5 * k), 0.0, 1.0);
		acc += texelFetch(data, ivec2(i, 1), 0).rgb * c;
	}
	return acc;
}

// arches of glowing gas at the edge, sampled as the mockup sampled them;
// zoomed, k times as many samples along and strands k times as far apart
vec3 proms(vec2 pz, float t) {
	vec3 acc = vec3(0.0);
	float k = zoom, x = pz.x, y = pz.y, reach = 1.89 * k + 1.61, mg = 4.0 * k;
	int ns = int(ceil(100.0 * k - 0.001)), M = int(ceil(k - 0.0001));
	for (int j = 0; j < n_proms; j++) {
		vec4 P = prom_p[j], Q = prom_q[j];
		vec2 p0 = zoomed(P.xy), p1 = zoomed(P.zw), q = zoomed(Q.xy);
		if (x < min(min(p0.x, p1.x), q.x) - mg || x > max(max(p0.x, p1.x), q.x) + mg || y < min(min(p0.y, p1.y), q.y) - mg || y > max(max(p0.y, p1.y), q.y) + mg) continue;
		float nx = cos(Q.z), ny = sin(Q.z);
		for (int i = 0; i < ns; i++) {
			float s = float(i) * 0.01 / k, u = 1.0 - s;
			float bx = u * u * p0.x + 2.0 * u * s * q.x + s * s * p1.x, by = u * u * p0.y + 2.0 * u * s * q.y + s * s * p1.y;
			if (abs(bx - x) > reach || abs(by - y) > reach) continue;
			float jit = (noise(s * 9.0 + float(j) * 5.0, t * 0.6) - 0.5) * 2.2;
			for (int w = -M; w <= M; w++) {
				float fw = abs(float(w)), o = (float(w) + jit * k) * 0.9;
				// 0.42 down the middle, 0.26 a strand out, fading past that
				float wt = w == 0 ? 0.42 : (fw < k ? mix(0.42, 0.26, fw / k) : 0.26 * (1.0 + k - fw));
				if (at(vec2(bx - ny * o, by + nx * o), x, y)) acc += L_PINK * wt;
			}
		}
	}
	return acc;
}

// diffraction spikes, three pixels wide, stepped one pixel at a time; zoomed,
// stepped one game pixel at a time down a spike k times as long and as wide
vec3 spike_light(vec2 pz) {
	vec3 acc = vec3(0.0);
	float k = zoom;
	vec2 rel = pz - box_h;
	int M = int(ceil(k - 0.0001));
	for (int j = 0; j < 8; j++) {
		vec2 dir = arms[j].xy;
		float lk = spikes * arms[j].z;
		vec2 side = vec2(-dir.y, dir.x);
		if (abs(dot(rel, side)) > k + 1.75) continue;
		float a0 = R * 0.9 * k, n0 = floor(dot(rel, dir) - a0);
		for (int m = -2; m <= 3; m++) {
			float n = n0 + float(m);
			if (n < 0.0) continue;
			float az = a0 + n, a = az / k;
			if (a >= R + lk) continue;
			float f = sq(1.0 - (a - R) / lk) * flick;
			vec2 c = box_h + dir * az;
			if (at(c, pz.x, pz.y)) acc += spike_c * 0.9 * f;
			for (int s = 1; s <= M; s++) {
				// 0.9 down the middle, 0.25 a pixel out, fading past that
				float fs = float(s), wt = fs < k ? 0.9 - 0.65 * fs / k : 0.25 * (1.0 + k - fs);
				if (at(c + side * fs, pz.x, pz.y)) acc += spike_c * wt * f;
				if (at(c - side * fs, pz.x, pz.y)) acc += spike_c * wt * f;
			}
		}
	}
	return acc;
}

// faint rays wheeling slowly round it
vec3 ray_light(float dx, float dy, float d, float t) {
	if (d < R) return vec3(0.0);
	float ang = ang_of(dy, dx), r = pow(0.5 + 0.5 * cos(ang * 9.0 + t * 0.25 + 2.0 * noise(ang * 3.0, t * 0.2)), 18.0);
	float v = rays * r * exp(-(d - R) / (R * 1.6));
	return v > 0.01 ? rays_c * v : vec3(0.0);
}

// A MASS EJECTION's bubble, ragged and streaming, bright at its front
vec3 cme(float x, float y) {
	float bx = cme_a.x, by = cme_a.y, br = cme_a.z, ca = cme_b.x, sa = cme_b.y, g = cme_b.z, u = cme_b.w;
	if (y < max(0.0, floor(by - br * 1.6 - 4.0)) || y > min(BH, by + br * 1.6 + 4.0) || x < max(0.0, floor(bx - br * 1.6 - 4.0)) || x > min(BW, bx + br * 1.6 + 4.0)) return vec3(0.0);
	float dx = x - bx, dy = y - by, d = length(vec2(dx, dy)), outw = (dx * ca + dy * sa) / (d > 0.0 ? d : 1.0);
	float th = ang_of(dy, dx), edge = br * (1.0 + 0.32 * (noise(cos(th) * 1.6 + g * 3.0, sin(th) * 1.6 + u * 0.6) - 0.5) * 2.0 + 0.18 * max(0.0, outw));
	float strands = 0.35 + 1.1 * sq(1.0 - abs(2.0 * fbm(th * 4.0 + g, d * 0.12 - u) - 1.0));
	float front = exp(-sq((d - edge) / 2.2)) * (0.08 + 0.92 * pow(max(0.0, outw), 0.7)) * strands;
	float inside = d < edge ? 0.1 * (1.0 - d / edge) * max(0.0, outw + 0.3) : 0.0;
	float v = (front + inside) * (0.5 + 0.9 * fbm(x * 0.15 + g * 7.0, y * 0.15 - u)) * cme_fade;
	return v > 0.02 ? (d < br * 0.7 ? L_PINK : vec3(1.0, 0.62, 0.32)) * v * 1.2 : vec3(0.0);
}

// ---------------------------------------------------------------- one pixel
int pick(vec3 c) {
	// the mockup looks colours up at 5 bits a channel, then takes the nearest
	vec3 q = vec3(c.r <= 0.0 ? 0.0 : (c.r >= 1.0 ? 31.0 : floor(c.r * 31.0 + 0.5)),
		c.g <= 0.0 ? 0.0 : (c.g >= 1.0 ? 31.0 : floor(c.g * 31.0 + 0.5)),
		c.b <= 0.0 ? 0.0 : (c.b >= 1.0 ? 31.0 : floor(c.b * 31.0 + 0.5))) / 31.0;
	int k = 0;
	float best = 1e9;
	int stride = max(pal_stride, half_pal ? 2 : 1);
	for (int j = 0; j < 44; j += stride) {
		vec3 p = PAL[j] / 255.0 - q;
		float d = 2.0 * p.r * p.r + 4.0 * p.g * p.g + 3.0 * p.b * p.b;
		if (d < best) { best = d; k = j; }
	}
	return k;
}

vec4 sun(float x, float y, vec2 pz) {
	float t = time, dx = x - CXB, dy = y - CYB, d = length(vec2(dx, dy));
	vec3 L = SPACE;
	// what lies behind the star, in the mockup's order
	if ((layers & DUST) != 0) L += dust_shells(x, y, dx, dy, d, t);
	if ((layers & LOBES) != 0) L += lobes(dx, dy, t);
	if ((layers & CARVE) != 0) L = carve(L, x, y, dx, dy, d, t);
	if ((layers & BEDISC) != 0) L += bedisc(dx, dy, t, false);
	if ((layers & CORONA) != 0) L += corona(dx, dy, d, t);
	if (n_blobs > 0) L += blobs(x, y, true);
	if ((layers & WIND) != 0) L += wind(dx, dy, d, t);
	L += glow(x, y, d, t);
	if ((layers & PLUMES) != 0) L += plumes(x, y, dx, dy, t);
	// the face replaces all of that
	bool face = false;
	float Rr = radius_at(t, ang_of(dy, dx));
	if (d <= Rr) { face = true; L = inv(face_colour(dx, dy, Rr, t)); }
	// and what lies in front of it
	if ((layers & BEDISC) != 0) L += bedisc(dx, dy, t, true);
	if (n_proms > 0) L += proms(pz, t);
	if (n_points > 0) L += points(x, y, pz);
	if (n_blobs > 0) L += blobs(x, y, false);
	if (cme_a.w > 0.5) L += cme(x, y);
	if (wave.w > 0.0 && d <= R * 0.98) { float k = exp(-sq((length(vec2(x - wave.x, y - wave.y)) - wave.z) / 2.0)) * wave.w * 0.6; if (k > 0.02) L += HOT * k; }
	if (spikes > 0.0) L += spike_light(pz);
	if (rays > 0.0) L += ray_light(dx, dy, d, t);
	// tone mapped, dithered, and put to the palette; no light is empty space
	if (L.r + L.g + L.b < 0.09) return vec4(0.0);
	int cl = max(cell, 1);
	float dth = (BAYER[((int(pz.y) / cl) & 3) * 4 + ((int(pz.x) / cl) & 3)] / 16.0 - 0.47) * 0.08;
	int k = pick(1.0 - exp(-L * 1.35) + dth);
	if (k == 0) return vec4(0.0);
	vec3 c = PAL[k];
	if (face) return vec4(c / 255.0, 1.0);
	// near-black is only the dither of empty space: leaving it off keeps the box from showing
	float s = c.r + c.g + c.b;
	if (s < 36.0) return vec4(0.0);
	float kk = s < 110.0 ? (s - 36.0) / 74.0 : 1.0;
	return vec4(floor(c * kk + 1e-4) / 255.0, 0.0);
}

void fragment() {
	// the game pixel in the (zoomed) box, and where in the mockup's box it samples
	vec2 pz = floor(UV * box_h * 2.0);
	float cf = float(max(cell, 1));
	pz = floor((pz - box_h) / cf) * cf + box_h;
	vec2 p = vec2(CXB, CYB) + (pz + 0.5 * (cf - 1.0) - box_h) / zoom;
	COLOR = sun(p.x, p.y, pz);
}
