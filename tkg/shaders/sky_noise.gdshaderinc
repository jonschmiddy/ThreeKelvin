// THE SECTOR SKY'S NOISE, shared by its bake (`sky_field.gdshader`) and the
// cloud seen from inside (`sky_nebula.gdshader`), so the two read one field.
//
// Two families:
//   * the game's own value noise (`hash2`, `noise2`, `fbm`): the cloud's
//     shapes have always been made of it, and `SkyWeather` places its events
//     with a port of it (`nhash`, `nnoise`, `nfbm`), so the shapes stay this;
//   * the showcase kit's (direction C, "Alive"): an integer hash that is the
//     same on every GPU, simplex noise, fbm, ridged filaments, a domain warp,
//     the two-phase flow map and the hue-keeping tone curve.

float hash2(vec2 p) {
	ivec2 q = ivec2(floor(p));
	uint h = (uint(q.x) * 374761393u) ^ (uint(q.y) * 668265263u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}
float noise2(vec2 p) {
	vec2 i = floor(p), f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash2(i), b = hash2(i + vec2(1.0, 0.0)), c = hash2(i + vec2(0.0, 1.0)), d = hash2(i + vec2(1.0, 1.0));
	return a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y;
}
float fbm(vec2 p, int o) {
	float a = 0.5, s = 0.0, n = 0.0;
	for (int i = 0; i < o; i++) { s += a * noise2(p); n += a; p = p * 2.03 + vec2(17.1, 9.3); a *= 0.5; }
	return s / n;
}
float sm(float a, float b, float x) {
	float d = b - a;
	if (abs(d) < 1e-6) return step(a, x);
	float u = clamp((x - a) / d, 0.0, 1.0);
	return u * u * (3.0 - 2.0 * u);
}
float sat(float x) { return clamp(x, 0.0, 1.0); }
float ridge(float v, float k) { return pow(1.0 - abs(2.0 * v - 1.0), k); }

// ---------------------------------------------------------------- the kit's
uint kitHashU(uint x) { x ^= x >> 16u; x *= 2146121005u; x ^= x >> 15u; x *= 2221713035u; x ^= x >> 16u; return x; }
uint kitHashU2(ivec2 p) { uvec2 q = uvec2(p + 1073741824); return kitHashU(q.x ^ kitHashU(q.y)); }
float kitU2F(uint h) { return float(h >> 8u) * (1.0 / 16777216.0); }
float kitHash1(ivec2 p) { return kitU2F(kitHashU2(p)); }
vec3 kitHash3(ivec2 p) { uint h = kitHashU2(p); uint h2 = kitHashU(h); return vec3(kitU2F(h), kitU2F(h2), kitU2F(kitHashU(h2))); }
vec2 kitQuintic2(vec2 f) { return f * f * f * (f * (f * 6.0 - 15.0) + 10.0); }
float kitVnoise2(vec2 p) {
	vec2 i = floor(p), f = p - i, u = kitQuintic2(f);
	ivec2 c = ivec2(i);
	float a = kitHash1(c), b = kitHash1(c + ivec2(1, 0)), d = kitHash1(c + ivec2(0, 1)), e = kitHash1(c + ivec2(1, 1));
	return mix(mix(a, b, u.x), mix(d, e, u.x), u.y);
}
vec2 kitMod289_2(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 kitMod289_3(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 kitMod289_4(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 kitPermute3(vec3 x) { return kitMod289_3(((x * 34.0) + 1.0) * x); }
vec4 kitPermute4(vec4 x) { return kitMod289_4(((x * 34.0) + 1.0) * x); }
// simplex (Ashima Arts / Ian McEwan, MIT), about -1..1
float kitSnoise2(vec2 v) {
	vec4 C = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
	vec2 i = floor(v + dot(v, C.yy));
	vec2 x0 = v - i + dot(i, C.xx);
	vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;
	i = kitMod289_2(i);
	vec3 p = kitPermute3(kitPermute3(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));
	vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
	m = m * m;
	m = m * m;
	vec3 x = 2.0 * fract(p * C.www) - 1.0;
	vec3 h = abs(x) - 0.5;
	vec3 ox = floor(x + 0.5);
	vec3 a0 = x - ox;
	m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);
	vec3 g;
	g.x = a0.x * x0.x + h.x * x0.y;
	g.yz = a0.yz * x12.xz + h.yz * x12.yw;
	return 130.0 * dot(m, g);
}
float kitSnoise3(vec3 v) {
	vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
	vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
	vec3 i = floor(v + dot(v, C.yyy));
	vec3 x0 = v - i + dot(i, C.xxx);
	vec3 g = step(x0.yzx, x0.xyz);
	vec3 l = 1.0 - g;
	vec3 i1 = min(g.xyz, l.zxy);
	vec3 i2 = max(g.xyz, l.zxy);
	vec3 x1 = x0 - i1 + C.xxx;
	vec3 x2 = x0 - i2 + C.yyy;
	vec3 x3 = x0 - D.yyy;
	i = kitMod289_3(i);
	vec4 p = kitPermute4(kitPermute4(kitPermute4(i.z + vec4(0.0, i1.z, i2.z, 1.0)) + i.y + vec4(0.0, i1.y, i2.y, 1.0)) + i.x + vec4(0.0, i1.x, i2.x, 1.0));
	float n_ = 0.142857142857;
	vec3 ns = n_ * D.wyz - D.xzx;
	vec4 j = p - 49.0 * floor(p * ns.z * ns.z);
	vec4 x_ = floor(j * ns.z);
	vec4 y_ = floor(j - 7.0 * x_);
	vec4 x = x_ * ns.x + ns.yyyy;
	vec4 y = y_ * ns.x + ns.yyyy;
	vec4 h = 1.0 - abs(x) - abs(y);
	vec4 b0 = vec4(x.xy, y.xy);
	vec4 b1 = vec4(x.zw, y.zw);
	vec4 s0 = floor(b0) * 2.0 + 1.0;
	vec4 s1 = floor(b1) * 2.0 + 1.0;
	vec4 sh = -step(h, vec4(0.0));
	vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
	vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;
	vec3 p0 = vec3(a0.xy, h.x);
	vec3 p1 = vec3(a0.zw, h.y);
	vec3 p2 = vec3(a1.xy, h.z);
	vec3 p3 = vec3(a1.zw, h.w);
	vec4 norm = 1.79284291400159 - 0.85373472095314 * vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3));
	p0 *= norm.x;
	p1 *= norm.y;
	p2 *= norm.z;
	p3 *= norm.w;
	vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
	m = m * m;
	return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
}
vec2 kitRot2(vec2 p) { return vec2(0.8 * p.x - 0.6 * p.y, 0.6 * p.x + 0.8 * p.y); }
// simplex fbm, about -1..1 (mostly within +-0.6)
float kitFbm2(vec2 p, int oct) {
	float s = 0.0, a = 0.5, n = 0.0;
	for (int i = 0; i < 8; i++) { if (i >= oct) break; s += a * kitSnoise2(p); n += a; p = kitRot2(p) * 2.03 + vec2(17.3, 9.1); a *= 0.5; }
	return s / n;
}
// value fbm, 0..1
float kitVfbm2(vec2 p, int oct) {
	float s = 0.0, a = 0.5, n = 0.0;
	for (int i = 0; i < 8; i++) { if (i >= oct) break; s += a * kitVnoise2(p); n += a; p = kitRot2(p) * 2.03 + vec2(17.3, 9.1); a *= 0.5; }
	return s / n;
}
// ridged multifractal, 0..1: thin bright filaments
float kitRidge2(vec2 p, int oct) {
	float s = 0.0, a = 0.5, n = 0.0, w = 1.0;
	for (int i = 0; i < 8; i++) { if (i >= oct) break; float r = 1.0 - abs(kitSnoise2(p)); r *= r; s += a * r * w; w = clamp(r * 1.6, 0.0, 1.0); n += a; p = kitRot2(p) * 2.03 + vec2(17.3, 9.1); a *= 0.5; }
	return s / n;
}
vec2 kitWarp2(vec2 p, float amt, int oct) { return p + amt * vec2(kitFbm2(p, oct), kitFbm2(p + vec2(5.2, 1.3), oct)); }
// Two-phase flow map: sample at p - vel*phase.x*period and p - vel*phase.y*period, mixed by phase.z
vec3 kitFlowPhase(float t, float period) {
	float a = fract(t / period), b = fract(t / period + 0.5);
	return vec3(a, b, abs(1.0 - 2.0 * a));
}
vec3 kitToSrgb(vec3 c) { c = max(c, 0.0); return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c)); }
vec3 kitToLinear(vec3 s) { s = max(s, 0.0); return mix(s / 12.92, pow((s + 0.055) / 1.055, vec3(2.4)), step(0.04045, s)); }
// Hue-keeping filmic: the brightest channel through a soft shoulder, the colour keeping its ratios;
// only light past `burn` fades toward white.
vec3 kitTone(vec3 hdr, float bk) {
	hdr = max(hdr, 0.0);
	float m = max(max(hdr.r, hdr.g), hdr.b);
	if (m < 1e-6) return vec3(0.0);
	float mt = 1.0 - exp(-m);
	vec3 c = hdr * (mt / m);
	return mix(c, vec3(mt), smoothstep(bk, bk * 3.0, m));
}
