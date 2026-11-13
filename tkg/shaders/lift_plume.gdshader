shader_type canvas_item;

// THE LIFT'S SMOKE (`LiftPlume`). Every puff is a soft blob; the blobs add into
// one density, torn by a noise field that moves on the plume's own held clock
// (`tstep`, ten a second), so the shape changes like fire's does. Density and the
// light inside it each step through four levels with a 4x4 ordered dither.
// Why: docs/why/ShipLift.md#plume

uniform vec2 rect_size = vec2(960.0, 540.0);
// the rect's top left in the host's pixels (it reaches past the host's edges)
uniform vec2 org = vec2(0.0);
uniform int n = 0;
// x, y, radius, density
uniform vec4 puff[64];
// heat, stretch x, stretch y, unused
uniform vec4 puff2[64];
uniform float tstep = 0.0;
// the source's light: x, y, radius, strength
uniform vec4 src = vec4(0.0);
uniform vec4 box = vec4(0.0, 0.0, 960.0, 540.0);
uniform float floor_y = 372.0;
// the kinds (`LiftPlume.kind`): which face the lamps light (1 the top, 0 the
// underside: S1's billows are dark above), the engines' glow along the floor,
// how much of the heat shows, how dense it reads, how hard it is torn
uniform float top_light = 1.0;
uniform float floor_glow = 0.0;
uniform float glow_k = 1.0;
uniform float alpha_k = 1.0;
uniform float turb = 1.0;
uniform vec3 c_dark = vec3(0.1, 0.11, 0.135);
uniform vec3 c_mid = vec3(0.2, 0.22, 0.26);
uniform vec3 c_lite = vec3(0.33, 0.36, 0.41);
uniform vec3 c_top = vec3(0.5, 0.53, 0.57);
uniform vec3 g_lo = vec3(0.45, 0.16, 0.06);
uniform vec3 g_mid = vec3(0.86, 0.36, 0.1);
uniform vec3 g_hi = vec3(1.0, 0.75, 0.38);
uniform vec3 g_core = vec3(1.0, 0.93, 0.7);

float bayer4(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int i = x + y * 4;
	// 0 8 2 10 / 12 4 14 6 / 3 11 1 9 / 15 7 13 5
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
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	return 0.55 * vnoise(p) + 0.3 * vnoise(p * 2.1 + 5.2) + 0.15 * vnoise(p * 4.3 + 1.7);
}

float stepq(float v, float levels, float th) {
	return floor(clamp(v, 0.0, 1.0) * levels + th) / levels;
}

void fragment() {
	vec2 p = floor(UV * rect_size) + 0.5 + org;
	if (p.x < box.x || p.y < box.y || p.x > box.z || p.y > box.w) {
		discard;
	}
	float th = bayer4(p);
	// the field the puffs are torn by: it rolls on in held steps
	vec2 q = p * 0.045 + vec2(tstep * 0.21, -tstep * 0.29);
	vec2 disp = (vec2(fbm(q), fbm(q + 31.7)) - 0.5) * 30.0 * turb;
	vec2 pd = p + disp;
	float D = 0.0;
	float H = 0.0;
	float T = 0.0;
	for (int i = 0; i < 64; i++) {
		if (i >= n) {
			break;
		}
		vec4 a = puff[i];
		vec4 b = puff2[i];
		vec2 d = (pd - a.xy) / (a.z * b.yz);
		float dd = dot(d, d);
		if (dd < 1.0) {
			float f = (1.0 - dd);
			float v = a.w * f * f;
			D += v;
			// the puff's top faces the lamps, its belly the floor
			T += v * clamp(0.55 - d.y * 0.6, 0.0, 1.0);
		}
		vec2 dh = (p - a.xy) / (a.z * b.yz * 1.25);
		float hh = dot(dh, dh);
		if (hh < 1.0) {
			H += b.x * (1.0 - hh) * (1.0 - hh);
		}
	}
	// ragged edges: the field eats the thin smoke
	float eat = fbm(p * 0.09 + vec2(-tstep * 0.41, tstep * 0.17));
	D = D - (eat - 0.4) * 0.7;
	// smoke never sinks far under the floor it rolls on
	if (p.y > floor_y + 34.0) {
		D -= (p.y - floor_y - 34.0) * 0.05;
	}
	if (D <= 0.0) {
		discard;
	}
	float lv = stepq(D * 1.1, 4.0, th);
	if (lv <= 0.0) {
		discard;
	}
	float alpha = lv >= 1.0 ? 1.0 : (lv > 0.7 ? 0.9 : (lv > 0.45 ? 0.72 : 0.45));
	float Ds = max(D + (eat - 0.4) * 0.7, 0.001);
	float top = clamp(T / Ds, 0.0, 1.0);
	// lit from above, darker at the thin edges
	float face = mix(1.0 - top, top, top_light);
	float sh = clamp(face * 0.75 + lv * 0.45 - 0.25, 0.0, 1.0);
	float sq = floor(sh * 3.0 + th) / 3.0;
	vec3 smoke = sq >= 1.0 ? c_top : (sq >= 0.66 ? c_lite : (sq >= 0.33 ? c_mid : c_dark));
	// lit from inside: the puffs' heat and the engines over them
	vec2 sd = (p - src.xy) / vec2(src.z, src.z * 0.55);
	float sl = max(0.0, 1.0 - dot(sd, sd));
	// the light sits low in the smoke, under its own top
	float L = (H + src.w * sl * sl) * (0.45 + 0.55 * (1.0 - top)) * min(D * 1.4, 1.0);
	// the engines' glow pooled low in the smoke, along the floor (S1)
	L += floor_glow * src.w * smoothstep(floor_y - 70.0, floor_y - 6.0, p.y) * min(D, 1.0);
	// fire lights smoke in patches that move with it, the level held steady (F1)
	L *= (0.7 + 0.6 * fbm(p * 0.08 + vec2(tstep * 0.53, tstep * 0.11))) * glow_k;
	float g = stepq(L * 0.7, 4.0, th);
	vec3 col = smoke;
	if (g > 0.0) {
		vec3 gc = g >= 1.0 ? g_core : (g >= 0.75 ? g_hi : (g >= 0.5 ? g_mid : g_lo));
		col = g >= 0.75 ? gc : smoke + gc * (g >= 0.5 ? 0.85 : 0.55);
		alpha = max(alpha, g >= 0.5 ? 0.95 : alpha);
	}
	COLOR = vec4(min(col, vec3(1.0)), alpha * alpha_k);
}
