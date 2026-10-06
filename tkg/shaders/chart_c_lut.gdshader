shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE SIMPLIFIED CHART'S PALETTE LOOKUP, made once a palette (`ChartSky`): for
// every cell of a 32-step-a-channel cube (x = b 32 + r, y = g), the nearest
// palette colour A in OKLab, a partner B (the nearest colour on the far side of
// A, so the cell lies between them), and whether A and B may be dithered: they
// are near each other (OKLab distance under `near`) and neither is dark (L over
// `dark`), so flat darkness never gets a checker. The showcase kit's `P.lut`.

uniform sampler2D pal : filter_nearest;
uniform int n = 0;
uniform float near = 0.11;
uniform float dark = 0.20;
// colours kept for one thing only (the radiant style's hole bands, indices
// [exact_lo, exact_hi)): taken only by a colour within `exact_r` of them, never
// as a dither partner, so a smooth tan gradient never lands on a hole band and
// draws a rust ring round an elliptical
uniform int exact_lo = 0;
uniform int exact_hi = 0;
uniform float exact_r = 0.035;
// THE SHOWCASE A's PARTNER RULE (0: off): the partner must be near in lightness
// and nearer still in hue and chroma (chroma weighted `lchr`), and lie toward the
// colour (within about 50 degrees of the way from A to it), so a smooth tan
// gradient never dithers toward a rust or a grey across hues
uniform float lchr = 0.0;

vec3 to_lin(vec3 s) {
	return mix(s / 12.92, pow((s + 0.055) / 1.055, vec3(2.4)), step(0.04045, s));
}
float cbrt1(float x) { return sign(x) * pow(abs(x), 1.0 / 3.0); }
vec3 oklab(vec3 c) {
	float l = 0.4122214708 * c.r + 0.5363325363 * c.g + 0.0514459929 * c.b;
	float m = 0.2119034982 * c.r + 0.6806995451 * c.g + 0.1073969566 * c.b;
	float s = 0.0883024619 * c.r + 0.2817188376 * c.g + 0.6299787005 * c.b;
	l = cbrt1(l);
	m = cbrt1(m);
	s = cbrt1(s);
	return vec3(0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
		1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
		0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s);
}

void fragment() {
	ivec2 p = ivec2(floor(UV * vec2(1024.0, 32.0)));
	float r = float(p.x % 32), b = float(p.x / 32), g = float(p.y);
	vec3 L = oklab(to_lin(vec3(r, g, b) / 31.0));
	int A = 0;
	float dA = 1e9;
	for (int i = 0; i < 128; i++) {
		if (i >= n) {
			break;
		}
		vec3 q = oklab(to_lin(texelFetch(pal, ivec2(i, 0), 0).rgb));
		vec3 d = L - q;
		float dd = dot(d, d);
		if (i >= exact_lo && i < exact_hi && dd > exact_r * exact_r) {
			continue;
		}
		if (dd < dA) {
			dA = dd;
			A = i;
		}
	}
	vec3 qa = oklab(to_lin(texelFetch(pal, ivec2(A, 0), 0).rgb));
	int B = A;
	float dB = 1e9;
	for (int i = 0; i < 128; i++) {
		if (i >= n) {
			break;
		}
		if (i == A || (i >= exact_lo && i < exact_hi)) {
			continue;
		}
		vec3 q = oklab(to_lin(texelFetch(pal, ivec2(i, 0), 0).rgb));
		if (dot(L - qa, q - qa) <= 0.0) {
			continue;
		}
		if (lchr > 0.0) {
			vec3 ab = q - qa;
			if (ab.x * ab.x + lchr * dot(ab.yz, ab.yz) > near * near) {
				continue;
			}
			vec3 la = L - qa;
			float t = dot(la, ab) / max(dot(ab, ab), 1e-9);
			if (dot(la, la) - t * t * dot(ab, ab) > 0.6 * dot(la, la)) {
				continue;
			}
		}
		vec3 d = L - q;
		float dd = dot(d, d);
		if (dd < dB) {
			dB = dd;
			B = i;
		}
	}
	vec3 qb = oklab(to_lin(texelFetch(pal, ivec2(B, 0), 0).rgb));
	bool ok = B != A && length(qa - qb) < near && min(qa.x, qb.x) > dark;
	COLOR = vec4(float(A) / 255.0, float(B) / 255.0, ok ? 1.0 : 0.0, 1.0);
}
