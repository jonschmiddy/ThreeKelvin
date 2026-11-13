shader_type canvas_item;
render_mode unshaded, blend_disabled;

// R15 DATAMOSH, the state: the moshed picture, one tick on. Drawn in its own SubViewport that
// is never cleared, reading its last tick back through a BackBufferCopy. Each 8 px block of a
// moving block is last tick's picture moved by its vector (`vec`, whole pixels, set on the
// CPU); a few runs of blocks are sent clean (intra refresh); DC errors add flat colour that
// rides forward; the hull still being sent is the clean picture. The clean picture is the
// world (`live`, the mirror) with the baked hull lit by the drive and the drive's aura.
// Why: docs/why/SeqDatamosh.md#state-pass

#include "res://shaders/jump/jump_common.gdshaderinc"
#include "res://shaders/jump/jump_r15.gdshaderinc"

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform sampler2D live : filter_nearest, repeat_disable;
uniform sampler2D vecs : filter_nearest, repeat_disable;
uniform sampler2D info : filter_nearest, repeat_disable;
uniform sampler2D hull : filter_nearest, repeat_disable;
uniform sampler2D aux : filter_nearest, repeat_disable;
uniform vec4 world = vec4(0.0, 0.0, 960.0, 540.0);
uniform vec4 ship = vec4(0.0, 0.0, 1.0, 1.0);
uniform vec2 core = vec2(0.0);
uniform vec2 pc = vec2(0.0);
uniform vec2 grid = vec2(120.0, 68.0);
uniform float hull_on = 0.0;
uniform float t = 0.0;
uniform float tape = 0.0;
uniform int tick = 0;
uniform float pulse_t[12];
uniform float pulse_s[12];
uniform int pulse_n = 0;
uniform float glow_on = 0.0;
uniform float wake_s = 0.0;
uniform float burn_s = 0.0;
uniform float aura_a = 0.0;
uniform float aura_dx = 70.0;
uniform float axis = 270.0;
uniform float ship_l = 0.0;
uniform float refresh_p = 0.0;
uniform float dc_p = 0.0;
uniform float dc_young = 0.0;
uniform float dc_amp = 1.0;
uniform float t_mosh = 2.2;
uniform float t_span = 2.7;
uniform float rip_k = -1.0;
uniform vec4 ink_s = vec4(0.0);

vec2 clampw(vec2 q) {
	return clamp(q, world.xy, world.xy + world.zw - 1.0);
}

// The hull lit by the drive (r15.py `ship_lit`): mint, violet and white running out along
// its seams on each pulse, a white flash at the drive, the seams burning on through the mosh.
vec3 lit(vec3 ship_rgb, vec2 q) {
	if (glow_on < 0.5) {
		return ship_rgb;
	}
	float dcore = length(vec2(q.x - core.x, (q.y - core.y) * 1.7));
	float seam = texture(aux, (q - ship.xy + 0.5) / ship.zw).r;
	vec3 hv = vec3(0.0);
	for (int j = 0; j < pulse_n; j++) {
		float dtp = t - pulse_t[j];
		if (dtp < 0.0 || dtp > 0.6) {
			continue;
		}
		float s = pulse_s[j];
		float front = dtp * (150.0 + 160.0 * s);
		float amp = (0.5 + 1.1 * s) * exp(-dtp / 0.22);
		float wave = exp(-pow((dcore - front) / (5.0 + 5.0 * s), 2.0)) * amp;
		int m3 = j - 3 * (j / 3);
		vec3 pcol = m3 == 0 ? R15_MINT : (m3 == 1 ? R15_VIO : R15_WHT);
		hv += wave * (0.2 + 1.5 * seam) * pcol;
		hv += amp * 1.4 * exp(-dcore / 7.0) * exp(-dtp / 0.08) * R15_WHT;
	}
	hv += (2.2 * seam + 0.07) * burn_s * exp(-dcore / (40.0 + 160.0 * burn_s)) * (R15_MINT * 0.75 + R15_VIO * 0.25);
	float lm = max(hv.r, max(hv.g, hv.b));
	if (lm <= 0.0) {
		return ship_rgb;
	}
	float qq = j_glow_q(lm, 7.0, q);
	vec3 colr = hv / lm;
	vec3 o = ship_rgb * (1.0 + 0.85 * qq * (0.4 + 0.6 * colr)) + qq * colr * 0.6;
	return mix(o, R15_WHT, clamp((lm - 3.0) / 2.0, 0.0, 1.0));
}

// The clean picture at q: the world, the lit stand-in, the drive's aura round it.
vec3 clean_at(vec2 q, vec2 px, out float al) {
	vec3 img = texture(live, (q + 0.5) * px).rgb;
	al = 0.0;
	if (hull_on > 0.5) {
		vec4 hp = j_hull_px(hull, q - ship.xy, ship.zw);
		al = hp.a;
		if (al > 0.0) {
			img = mix(img, clamp(lit(hp.rgb, q), 0.0, 1.0), al);
		}
	}
	if (glow_on > 0.5 && al < 0.5) {
		vec3 Lg = j_splat(q, core, 6.0 + 14.0 * wake_s, R15_MINT * 0.6 + R15_VIO * 0.4, 0.08 + 0.35 * wake_s, 1.6);
		if (aura_a > 0.0) {
			Lg += j_splat(q, pc + vec2(10.0, 0.0), 34.0 + 30.0 * aura_a, R15_MINT * 0.55 + R15_VIO * 0.45, 0.55 * aura_a, 1.9);
			Lg += j_splat(q, pc + vec2(aura_dx, 0.0), 70.0 + 40.0 * aura_a, R15_VIO * 0.7 + R15_MINT * 0.3, 0.30 * aura_a, 2.4);
		}
		img = j_add_glow(img, Lg, 7.0, q);
	}
	return clamp(img, 0.0, 1.0);
}

int flags_at(float bx, float by) {
	if (bx < 0.0) {
		return 0;
	}
	return int(texture(info, (vec2(bx, by) + 0.5) / grid).r * 255.0 + 0.5);
}

// Intra refresh: blocks sent clean this tick, seeded at rate refresh_p (less in the heading's
// lane, so its trails stay long), then grown twice along the heading at 0.6.
bool fresh0(float bx, float by) {
	if (bx < 0.0) {
		return false;
	}
	float lane = exp(-pow((by * 8.0 + 4.0 - axis) / 60.0, 2.0)) * ((bx * 8.0 + 4.0) > ship_l ? 1.0 : 0.0);
	return r15_h(int(bx), int(by), tick * 8 + 1) < refresh_p * (1.0 - 0.8 * lane);
}

bool fresh(vec2 b) {
	bool f0m2 = fresh0(b.x - 2.0, b.y);
	bool f0m1 = fresh0(b.x - 1.0, b.y);
	bool f00 = fresh0(b.x, b.y);
	bool f1m1 = f0m1 || (f0m2 && r15_h(int(b.x) - 1, int(b.y), tick * 8 + 2) < 0.6);
	bool f10 = f00 || (f0m1 && r15_h(int(b.x), int(b.y), tick * 8 + 2) < 0.6);
	return f10 || (f1m1 && r15_h(int(b.x), int(b.y), tick * 8 + 3) < 0.6);
}

// A DC error's seed: an infected block, most often on the corruption's young front, near the heading.
bool dc0(float bx, float by) {
	if (bx < 0.0) {
		return false;
	}
	vec4 inf = texture(info, (vec2(bx, by) + 0.5) / grid);
	int fl = int(inf.r * 255.0 + 0.5);
	if ((fl & 4) == 0) {
		return false;
	}
	float t_inf = t_mosh + inf.g * t_span;
	float young = clamp(1.0 - (tape - t_inf) / 0.35, 0.0, 1.0) * dc_young;
	float wgt = (0.25 + 0.9 * exp(-pow((by * 8.0 + 4.0 - axis) / 150.0, 2.0))) * (0.5 + 1.5 * young);
	return r15_h(int(bx), int(by), tick * 8 + 4) < dc_p * 0.7 * wgt;
}

// The DC offset on block b this tick: seeds grown seven times along the heading at 0.75.
vec3 dc(vec2 b) {
	bool pk[8];
	for (int i = 0; i < 8; i++) {
		pk[i] = dc0(b.x - 7.0 + float(i), b.y);
	}
	for (int ps = 0; ps < 7; ps++) {
		for (int i = 7; i >= 1; i--) {
			pk[i] = pk[i] || (pk[i - 1] && r15_h(int(b.x) - 7 + i, int(b.y), tick * 64 + 8 + ps) < 0.75);
		}
	}
	if (!pk[7]) {
		return vec3(0.0);
	}
	float c = r15_h(int(b.x), int(b.y), tick * 8 + 5);
	vec3 col = c < 0.34 ? R15_MINT : (c < 0.60 ? R15_VIO : (c < 0.74 ? R15_ROSE : (c < 0.88 ? vec3(0.85, 0.80, 1.0) : vec3(-0.6))));
	float amp = (40.0 + 80.0 * r15_h(int(b.x), int(b.y), tick * 8 + 6)) / 255.0;
	return col * amp * dc_amp;
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 p = floor(SCREEN_UV / px);
	vec2 q = clampw(p);
	vec2 b = floor(q / 8.0);
	float al;
	vec3 cl = clean_at(q, px, al);
	int fl = flags_at(b.x, b.y);
	vec3 S = cl;
	if ((fl & 5) != 0) {
		vec2 d = floor(texture(vecs, (b + 0.5) / grid).rg * 255.0 + 0.5) - 128.0;
		S = texture(screen, (clampw(q - d) + 0.5) * px).rgb;
		if (refresh_p > 0.0 && fresh(b)) {
			S = cl;
		}
	}
	if (dc_p > 0.0) {
		S = clamp(S + dc(b), 0.0, 1.0);
	}
	// the hull refreshes itself until it is ripped, then stops from the nose back
	if (al > 0.5 && (rip_k < 0.0 || q.x < ink_s.x + ink_s.z * (1.0 - rip_k) - 6.0 * sin(q.y * 0.7))) {
		S = cl;
	}
	COLOR = vec4(S, 1.0);
}
