// THE SCIENCE DESK'S LIGHT, per art pixel: the approved page's C lighting (`roomfx.js` makeLit's
// `compose` and `frame`, tools/desk/page) on the GPU. `tools/desk/dump_desk.py` ran the page's own
// code for each light's field and the per-pixel tables; what moves is only the weights.
//
// A WEIGHT IS [steady, flicker]. The steady part (the power-on) is composed and stepped into the
// six-level C ramp; the flicker (a tired bulb, the string twinkle, the tube's life) only multiplies
// the stepped light after, so no band edge ever crawls. Every store rounds as the page's bytes do.
// Why: docs/why/DeskScene.md#the-plan

// The art with its keyboard and settled dust (RGB 0..255).
uniform sampler2D a2c_tex : filter_nearest, repeat_disable;
// lamp, screen, porthole fields
uniform sampler2D fields_tex : filter_nearest, repeat_disable;
// up to four string bulbs a pixel: index + 1, and their fields
uniform sampler2D small_i_tex : filter_nearest, repeat_disable;
uniform sampler2D small_v_tex : filter_nearest, repeat_disable;
// tone gain, occlusion, room vignette, skip
uniform sampler2D px_tex : filter_nearest, repeat_disable;
// DeskRoom.ROLE_*: which emitter a pixel is
uniform sampler2D role_tex : filter_nearest, repeat_disable;

uniform vec3 w_big = vec3(0.0);
uniform vec3 tint_lamp = vec3(1.0);
uniform vec3 tint_scr = vec3(1.0);
uniform vec3 tint_port = vec3(0.8, 0.88, 1.0);
uniform vec3 tint_small = vec3(1.0, 0.82, 0.62);
// (float and vec3 arrays are packed as vec4s: the compatibility renderer laid float[] out tight)
// A room with more than sixteen small lights defines SMALL_Q (vec4s) before the include; one whose
// bulbs crowd past four a pixel defines SMALL_SETS 2 or 3 (the bake's small_i2 / small_v2, _i3 / _v3);
// one whose bulbs each have their own tint defines SMALL_TINTS (tint_small_a, one a light). One with
// lights past the lamp, screen and porthole defines MORE_FIELDS (fields2_tex, w_more, tint_more_*).
#ifndef SMALL_SETS
#define SMALL_SETS 1
#endif
#ifndef SMALL_Q
#define SMALL_Q 4
#endif
uniform vec4 w_small[SMALL_Q];
uniform vec3 amb = vec3(0.17, 0.18, 0.23);
uniform float st_fade = 0.0;
uniform float ov = 0.3;
uniform float hot = 6.0;
uniform vec3 hot_col = vec3(1.0, 0.7, 0.4);
uniform float fl_lamp = 1.0;
uniform float fl_scr = 1.0;
uniform vec4 fl_small[SMALL_Q];
#if SMALL_SETS > 1
uniform sampler2D small_i2_tex : filter_nearest, repeat_disable;
uniform sampler2D small_v2_tex : filter_nearest, repeat_disable;
#endif
#if SMALL_SETS > 2
uniform sampler2D small_i3_tex : filter_nearest, repeat_disable;
uniform sampler2D small_v3_tex : filter_nearest, repeat_disable;
#endif
#ifdef SMALL_PICK
// the page's pick where two small lights tie (index + 1; dump.html's common)
uniform sampler2D pick_tex : filter_nearest, repeat_disable;
#endif
#ifdef MORE_FIELDS
uniform sampler2D fields2_tex : filter_nearest, repeat_disable;
uniform vec4 w_more = vec4(0.0);
uniform vec3 tint_more_0 = vec3(1.0);
uniform vec3 tint_more_1 = vec3(1.0);
uniform vec3 tint_more_2 = vec3(1.0);
uniform vec3 tint_more_3 = vec3(1.0);
#endif
#ifdef SMALL_TINTS
uniform vec4 tint_small_a[SMALL_N];
#endif
// LED glows (`addGlow`): (cx, cy, strength, radius) and colour
uniform vec4 glow_a[8];
uniform vec4 glow_c[8];
uniform int glow_n = 0;

const float C_LV[6] = float[](0.17, 0.3, 0.5, 0.76, 1.08, 1.5);
const float BAYER[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);

float bay(int x, int y) {
	return (BAYER[(y & 3) * 4 + (x & 3)] + 0.5) / 16.0;
}

float sat1(float v) {
	return clamp(v, 0.0, 1.0);
}

// A Uint8ClampedArray store: clamped, halves to even.
vec3 st8(vec3 v) {
	return clamp(roundEven(v), 0.0, 255.0);
}

float knee(float c) {
	return c < 205.0 ? c : 205.0 + (c - 205.0) / (1.0 + (c - 205.0) / 50.0);
}

// One two-band step (`bandStep` with two bands): a plateau, a dithered edge E wide.
float band2(float d, vec2 b0, vec2 b1, float e, float b) {
	float s = 0.0;
	float f = (b0.x - d) / e + 0.5;
	if (f >= 1.0 || (f > 0.0 && f > b)) s += b0.y;
	f = (b1.x - d) / e + 0.5;
	if (f >= 1.0 || (f > 0.0 && f > b)) s += b1.y;
	return s;
}

float band3(float d, vec2 b0, vec2 b1, vec2 b2, float e, float b) {
	float s = band2(d, b0, b1, e, b);
	float f = (b2.x - d) / e + 0.5;
	if (f >= 1.0 || (f > 0.0 && f > b)) s += b2.y;
	return s;
}

// The summed light at p before the ramp (`compose`'s first pass): L, the lamp's and the screen's
// intensities and their overlap weights, the small lights' sum and the one whose flicker the pixel takes.
void room_sum(ivec2 p, vec4 aux, out vec3 L, out float lI, out float kl, out float mI, out float km, out float sl, out int kk) {
	float tg = aux.r;
	vec3 fld = texelFetch(fields_tex, p, 0).rgb;
	lI = 0.0;
	mI = 0.0;
	vec3 lr = vec3(0.0);
	vec3 mr = vec3(0.0);
	vec3 orr = vec3(0.0);
	if (w_big.x > 0.0 && fld.r != 0.0) { lI = fld.r * w_big.x * tg; lr = lI * tint_lamp; }
	if (w_big.y > 0.0 && fld.g != 0.0) { mI = fld.g * w_big.y * tg; mr = mI * tint_scr; }
	if (w_big.z > 0.0 && fld.b != 0.0) { orr = fld.b * w_big.z * tg * tint_port; }
#ifdef MORE_FIELDS
	vec4 f2 = texelFetch(fields2_tex, p, 0);
	if (w_more.x > 0.0 && f2.x != 0.0) orr += f2.x * w_more.x * tg * tint_more_0;
	if (w_more.y > 0.0 && f2.y != 0.0) orr += f2.y * w_more.y * tg * tint_more_1;
	if (w_more.z > 0.0 && f2.z != 0.0) orr += f2.z * w_more.z * tg * tint_more_2;
	if (w_more.w > 0.0 && f2.w != 0.0) orr += f2.w * w_more.w * tg * tint_more_3;
#endif
	sl = 0.0;
	float best = 0.0;
	kk = -1;
#ifdef SMALL_PICK
	int pick = int(texelFetch(pick_tex, p, 0).r + 0.5) - 1;
#else
	int pick = -1;
#endif
	vec3 sr = vec3(0.0);
	for (int h = 0; h < SMALL_SETS; h++) {
		vec4 si = texelFetch(small_i_tex, p, 0);
		vec4 sv = texelFetch(small_v_tex, p, 0);
#if SMALL_SETS > 1
		if (h == 1) { si = texelFetch(small_i2_tex, p, 0); sv = texelFetch(small_v2_tex, p, 0); }
#endif
#if SMALL_SETS > 2
		if (h == 2) { si = texelFetch(small_i3_tex, p, 0); sv = texelFetch(small_v3_tex, p, 0); }
#endif
		for (int s = 0; s < 4; s++) {
			int n = int(si[s] + 0.5) - 1;
			if (n < 0) continue;
			float w = w_small[n / 4][n % 4];
			if (!(w > 0.0)) continue;
			float e = sv[s] * w * tg;
			sl += e;
#ifdef SMALL_TINTS
			sr += e * tint_small_a[n].rgb;
#endif
			if (e > best || (e == best && n == pick)) { best = e; kk = n; }
		}
	}
#ifndef SMALL_TINTS
	sr = sl * tint_small;
#endif
	float fa = aux.b * st_fade * aux.g;
	kl = 1.0;
	km = 1.0;
	if (lI > 0.0 && mI > 0.0) {
		float k = (max(lI, mI) + ov * min(lI, mI)) / (lI + mI);
		kl = k;
		km = k;
	}
	L = amb * fa + lr * kl + mr * km + orr + sr;
}

// The light at p that the ramp steps (`compose`'s Ly); -1 on a skipped pixel (the glass, a porthole).
float room_ly(ivec2 p) {
	vec4 aux = texelFetch(px_tex, p, 0);
	if (aux.a > 0.5) return -1.0;
	vec3 L;
	float lI;
	float kl;
	float mI;
	float km;
	float sl;
	int kk;
	room_sum(p, aux, L, lI, kl, mI, km, sl, kk);
	float tot = (L.r + L.g + L.b) / 3.0;
	return tot == 0.0 ? 1.0 : tot;
}

// The ramp's step for ly with no dither: below the ramp -1, past it 5, else the nearest step.
int hard_step(float ly) {
	if (ly < C_LV[0]) return -1;
	if (ly >= C_LV[5]) return 5;
	int k = 0;
	while (k < 4 && ly >= C_LV[k + 1]) k++;
	return (ly - C_LV[k]) / (C_LV[k + 1] - C_LV[k]) > 0.5 ? k + 1 : k;
}

// The ramp dithers only on a seam (Jon, Nov 19: "weird latticing on Desk 1"): a pixel keeps its dither
// only when a pixel within SEAM_R of it (the glass and portholes aside) is on another step undithered.
// A surface whose light is flat on a step's midpoint (DESK 1's monitor case) takes its nearest step.
// Why: docs/why/DeskScene.md#the-ramps-seams
const int SEAM_R = 2;
bool on_seam(ivec2 p, int h) {
	for (int dy = -SEAM_R; dy <= SEAM_R; dy++) {
		for (int dx = -SEAM_R; dx <= SEAM_R; dx++) {
			ivec2 q = p + ivec2(dx, dy);
			if ((dx == 0 && dy == 0) || q.x < 0 || q.y < 0 || q.x >= 384 || q.y >= 216) continue;
			float lj = room_ly(q);
			if (lj >= 0.0 && hard_step(lj) != h) return true;
		}
	}
	return false;
}

// The room's light at p, composed and stepped (`compose`), then flickered (`frame`).
// base: the lit colour before the byte store; lm: the light there (for steam and dust).
void room_lit(ivec2 p, out vec3 base, out vec3 lm) {
	vec4 aux = texelFetch(px_tex, p, 0);
	if (aux.a > 0.5) {
		base = vec3(0.0);
		lm = vec3(0.0);
		return;
	}
	vec3 L;
	float lI;
	float kl;
	float mI;
	float km;
	float sl;
	int kk;
	room_sum(p, aux, L, lI, kl, mI, km, sl, kk);
	float tot = (L.r + L.g + L.b) / 3.0;
	if (tot == 0.0) tot = 1.0;
	float sL = lI * kl / tot;
	float sM = mI * km / tot;
	float sS = sl / tot;
	float ly = tot;
	float b = bay(p.x, p.y);
	float q;
	if (ly < C_LV[0]) {
		q = C_LV[0] * 0.8;
	} else if (ly >= C_LV[5]) {
		q = C_LV[5];
	} else {
		int k = 0;
		while (k < 4 && ly >= C_LV[k + 1]) k++;
		float t = (ly - C_LV[k]) / (C_LV[k + 1] - C_LV[k]);
		float ws = 0.18 * sat1(ly / 0.6);
		bool up = t > 0.5 + (b - 0.5) * 2.0 * ws;
		// off a seam: no dither, the nearest step
		if (up != (t > 0.5) && !on_seam(p, t > 0.5 ? k + 1 : k)) up = t > 0.5;
		q = up ? C_LV[k + 1] : C_LV[k];
	}
	float sc = q / ly;
	float s = sat1((0.6 - q) / 0.45);
	float h = sat1((q - 0.9) / 0.6) * min(1.0, sL * 1.5);
	float ht = lI > 1.05 ? hot * (lI - 1.05) * 4.0 : 0.0;
	vec3 A = texelFetch(a2c_tex, p, 0).rgb;
	base.r = knee(A.r * L.r * sc * (1.0 - 0.2 * s) * (1.0 + 0.06 * h) + 12.0 * h + ht * hot_col.r);
	base.g = knee(A.g * L.g * sc * (1.0 - 0.1 * s) + 3.0 * h + ht * hot_col.g);
	base.b = knee(A.b * L.b * sc * (1.0 + 0.28 * s) * (1.0 - 0.14 * h) + ht * hot_col.b);
	float m = 1.0 + sL * (fl_lamp - 1.0) + sM * (fl_scr - 1.0) + (kk >= 0 ? sS * (fl_small[kk / 4][kk % 4] - 1.0) : 0.0);
	base *= m;
	lm = L * sc * m;
}

// The LED glows at p (`addGlow`): what they multiply into the art (gm) and add (ga).
void glows_at(ivec2 p, out vec3 gm, out vec3 ga) {
	gm = vec3(0.0);
	ga = vec3(0.0);
	for (int g = 0; g < 8; g++) {
		if (g >= glow_n) break;
		vec4 a = glow_a[g];
		if (a.z <= 0.0) continue;
		if (float(p.x) < floor(a.x - a.w) || float(p.x) > ceil(a.x + a.w) || float(p.y) < floor(a.y - a.w) || float(p.y) > ceil(a.y + a.w)) continue;
		float d = length(vec2(float(p.x) - a.x, float(p.y) - a.y));
		float f = band2(d, vec2(a.w * 0.45, 0.5), vec2(a.w, 0.3), 1.5, bay(p.x, p.y));
		if (f == 0.0) continue;
		float e = f * a.z;
		gm += e * 1.3 * glow_c[g].rgb;
		ga += e * 34.0 * glow_c[g].rgb;
	}
}

// The room's light at p as steam and dust read it: the stepped light plus the LED glows.
vec3 light_at(ivec2 p) {
	vec3 base;
	vec3 lm;
	room_lit(p, base, lm);
	vec3 gm;
	vec3 ga;
	glows_at(p, gm, ga);
	return lm + gm;
}
