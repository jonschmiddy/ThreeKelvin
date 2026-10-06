// THE LEGACY CHART'S ARITHMETIC: the showcase kit's GLSL helpers (scratchpad
// `showcase/kit.js`), ported for every pass of the legacy star chart
// (`ChartSky.gd`): the bakes, the place pass, the stars and the composite.
// Integer hashes (lowbias32, the same on every GPU), value and simplex noise,
// fbm, ridged fbm, domain warp, the two-phase flow map, OKLab, the hue-keeping
// tone and the 0.38 plane. Godot has no mutable globals and no built-ins outside
// a processor function, so nothing here reads either.

const float KIT_TILT = 0.38;
const float KIT_TILT_COS = 0.92499;   // sqrt(1 - 0.38^2): how much a height shows on screen
const float KIT_RAY_LEN = 2.63158;    // path length along a view ray per unit of height
const float KIT_PI = 3.14159265;
const float KIT_TAU = 6.2831853;
const mat2 KIT_R2 = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
const mat3 KIT_R3 = mat3(vec3(0.00, 0.80, 0.60), vec3(-0.80, 0.36, -0.48), vec3(-0.60, -0.48, 0.64));

// ------------------------------------------------------------------ hash
uint kitHashU(uint x) {
	x ^= x >> 16u;
	x *= 2146121005u;
	x ^= x >> 15u;
	x *= 2221713035u;
	x ^= x >> 16u;
	return x;
}
uint kitHashU2(ivec2 p) {
	uvec2 q = uvec2(p + ivec2(1073741824));
	return kitHashU(q.x ^ kitHashU(q.y));
}
uint kitHashU3(ivec3 p) {
	uvec3 q = uvec3(p + ivec3(1073741824));
	return kitHashU(q.x ^ kitHashU(q.y ^ kitHashU(q.z)));
}
float kitU2F(uint h) { return float(h >> 8u) * (1.0 / 16777216.0); }
float kitHash1(ivec2 p) { return kitU2F(kitHashU2(p)); }
vec3 kitHash3(ivec2 p) {
	uint h = kitHashU2(p);
	uint h2 = kitHashU(h);
	return vec3(kitU2F(h), kitU2F(h2), kitU2F(kitHashU(h2)));
}
float kitHash1v3(ivec3 p) { return kitU2F(kitHashU3(p)); }

// ------------------------------------------------------------------ noise
vec2 kitQuintic2(vec2 f) { return f * f * f * (f * (f * 6.0 - 15.0) + 10.0); }
float kitVnoise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = kitQuintic2(f);
	ivec2 c = ivec2(i);
	float a = kitHash1(c), b = kitHash1(c + ivec2(1, 0)), d = kitHash1(c + ivec2(0, 1)), e = kitHash1(c + ivec2(1, 1));
	return mix(mix(a, b, u.x), mix(d, e, u.x), u.y);
}

vec2 kitM289_2(vec2 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 kitM289_3(vec3 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec4 kitM289_4(vec4 x) { return x - floor(x * (1.0 / 289.0)) * 289.0; }
vec3 kitPermute3(vec3 x) { return kitM289_3(((x * 34.0) + 1.0) * x); }
vec4 kitPermute4(vec4 x) { return kitM289_4(((x * 34.0) + 1.0) * x); }

float kitSnoise2(vec2 v) {
	const vec4 C = vec4(0.211324865405187, 0.366025403784439, -0.577350269189626, 0.024390243902439);
	vec2 i = floor(v + dot(v, C.yy));
	vec2 x0 = v - i + dot(i, C.xx);
	vec2 i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
	vec4 x12 = x0.xyxy + C.xxzz;
	x12.xy -= i1;
	i = kitM289_2(i);
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
	const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
	const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
	vec3 i = floor(v + dot(v, C.yyy));
	vec3 x0 = v - i + dot(i, C.xxx);
	vec3 g = step(x0.yzx, x0.xyz);
	vec3 l = 1.0 - g;
	vec3 i1 = min(g.xyz, l.zxy);
	vec3 i2 = max(g.xyz, l.zxy);
	vec3 x1 = x0 - i1 + C.xxx;
	vec3 x2 = x0 - i2 + C.yyy;
	vec3 x3 = x0 - D.yyy;
	i = kitM289_3(i);
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

// ------------------------------------------------------------------ fbm and friends
float kitFbm2(vec2 p, int oct) {
	float s = 0.0, a = 0.5, n = 0.0;
	for (int i = 0; i < 10; i++) {
		if (i >= oct) {
			break;
		}
		s += a * kitSnoise2(p);
		n += a;
		p = KIT_R2 * p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return s / n;
}
float kitFbm3(vec3 p, int oct) {
	float s = 0.0, a = 0.5, n = 0.0;
	for (int i = 0; i < 10; i++) {
		if (i >= oct) {
			break;
		}
		s += a * kitSnoise3(p);
		n += a;
		p = KIT_R3 * p * 2.02 + vec3(17.3, 9.1, 4.7);
		a *= 0.5;
	}
	return s / n;
}
float kitRidge3(vec3 p, int oct) {
	float s = 0.0, a = 0.5, n = 0.0, w = 1.0;
	for (int i = 0; i < 10; i++) {
		if (i >= oct) {
			break;
		}
		float r = 1.0 - abs(kitSnoise3(p));
		r *= r;
		s += a * r * w;
		w = clamp(r * 1.6, 0.0, 1.0);
		n += a;
		p = KIT_R3 * p * 2.02 + vec3(17.3, 9.1, 4.7);
		a *= 0.5;
	}
	return s / n;
}
vec2 kitWarp2(vec2 p, float amt, int oct) {
	return p + amt * vec2(kitFbm2(p, oct), kitFbm2(p + vec2(5.2, 1.3), oct));
}
// fbm with a continuous octave count: the finest octave fades in as you zoom,
// so nothing pops
float fbm2F(vec2 p, float oct) {
	float s = 0.0, a = 0.5, n = 0.0;
	for (int i = 0; i < 8; i++) {
		float w = clamp(oct - float(i), 0.0, 1.0);
		if (w <= 0.0) {
			break;
		}
		s += a * w * kitSnoise2(p);
		n += a * w;
		p = KIT_R2 * p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return s / max(n, 1e-4);
}
float fbm3F(vec3 p, float oct) {
	float s = 0.0, a = 0.5, n = 0.0;
	for (int i = 0; i < 8; i++) {
		float w = clamp(oct - float(i), 0.0, 1.0);
		if (w <= 0.0) {
			break;
		}
		s += a * w * kitSnoise3(p);
		n += a * w;
		p = KIT_R3 * p * 2.02 + vec3(17.3, 9.1, 4.7);
		a *= 0.5;
	}
	return s / max(n, 1e-4);
}
// Two-phase flow map: sample a field at two phases and mix by z, each phase
// resetting while its weight is nothing, so the stream never stretches
vec3 kitFlowPhase(float t, float period) {
	float a = fract(t / period), b = fract(t / period + 0.5);
	return vec3(a, b, abs(1.0 - 2.0 * a));
}

// ------------------------------------------------------------------ colour
vec3 kitToSrgb(vec3 c) {
	c = max(c, 0.0);
	return mix(c * 12.92, 1.055 * pow(c, vec3(1.0 / 2.4)) - 0.055, step(0.0031308, c));
}
float kitLum(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
float kitCbrt(float x) { return sign(x) * pow(abs(x), 1.0 / 3.0); }
vec3 kitOklab(vec3 c) {
	float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
	float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
	float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;
	l = kitCbrt(l);
	m = kitCbrt(m);
	s = kitCbrt(s);
	return vec3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
}
vec3 kitOklabToLinear(vec3 L) {
	float l = L.x + 0.3963377774 * L.y + 0.2158037573 * L.z;
	float m = L.x - 0.1055613458 * L.y - 0.0638541728 * L.z;
	float s = L.x - 0.0894841775 * L.y - 1.2914855480 * L.z;
	l = l * l * l;
	m = m * m * m;
	s = s * s * s;
	return vec3(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
		-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
		-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s);
}
vec3 kitOklch(vec3 lin) {
	vec3 L = kitOklab(lin);
	return vec3(L.x, length(L.yz), atan(L.z, L.y));
}
vec3 kitOklchToLinear(vec3 lch) {
	return kitOklabToLinear(vec3(lch.x, lch.y * cos(lch.z), lch.y * sin(lch.z)));
}
// Hue-keeping filmic: the brightest channel through a soft shoulder, the colour
// keeping its ratios; only light past `burn` fades toward white
vec3 kitTone(vec3 hdr, float burn) {
	hdr = max(hdr, 0.0);
	float m = max(max(hdr.r, hdr.g), hdr.b);
	if (m < 1e-6) {
		return vec3(0.0);
	}
	float mt = 1.0 - exp(-m);
	vec3 c = hdr * (mt / m);
	return mix(c, vec3(mt), smoothstep(burn, burn * 3.0, m));
}

// ------------------------------------------------------------------ dither, plane, stars
float kitBayer4(ivec2 b) {
	const float B[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	ivec2 m = b & ivec2(3);
	return (B[m.y * 4 + m.x] + 0.5) / 16.0;
}
mat2 kitRot(float a) {
	float c = cos(a), s = sin(a);
	return mat2(vec2(c, -s), vec2(s, c));
}
vec2 kitViewToPlane(vec2 v, float phi, float k) {
	return kitRot(-phi) * (vec2(v.x, v.y / KIT_TILT) / k);
}
// crisp stars on a grid, one block each: (found, brightness, temperature, spare)
vec4 kitStar(vec2 q, float blk, float cell, float prob, int seed) {
	vec4 r = vec4(0.0);
	ivec2 c0 = ivec2(floor(q / cell));
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			ivec2 c = c0 + ivec2(i, j);
			vec3 h = kitHash3(c + ivec2(seed * 7919, seed * 3571));
			if (h.z > prob) {
				continue;
			}
			vec2 s = (vec2(c) + h.xy) * cell;
			vec2 d = abs(q - s);
			if (d.x <= 0.5 * blk && d.y <= 0.5 * blk) {
				vec3 g = kitHash3(c + ivec2(seed * 131 + 17, seed * 977 + 5));
				r = vec4(1.0, g.x, g.y, g.z);
			}
		}
	}
	return r;
}
vec3 kitStarTint(float t) {
	vec3 a = vec3(1.0, 0.62, 0.38), b = vec3(1.0, 0.9, 0.78), c = vec3(0.72, 0.82, 1.0);
	return t < 0.5 ? mix(a, b, t * 2.0) : mix(b, c, t * 2.0 - 1.0);
}
