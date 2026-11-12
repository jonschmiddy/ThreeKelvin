// R15 DATAMOSH, shared by its three passes (state, output, world): the GLITCH tooltip's
// colours (HoloTag.gd), the mint/rose split of a channel slip, a block hash, and the palette
// snap with the pair dither (R12's, over the scene's colours and the glitch's ramps).
// Why: docs/why/SeqDatamosh.md#shader-include

const vec3 R15_FILL = vec3(6.0, 16.0, 16.0) / 255.0;
const vec3 R15_SCAN = vec3(10.0, 26.0, 22.0) / 255.0;
const vec3 R15_MINT = vec3(184.0, 245.0, 216.0) / 255.0;
const vec3 R15_VIO = vec3(0.62, 0.34, 1.00);
const vec3 R15_WHT = vec3(1.00, 0.98, 1.00);
const vec3 R15_ROSE = vec3(1.00, 0.42, 0.70);
// A slip splits the picture into a mint part and a rose part that add back to it exactly.
const vec3 R15_WA = vec3(0.40, 0.66, 0.56);
const vec3 R15_WB = vec3(0.60, 0.34, 0.44);

uniform vec3 pal[64];
uniform int pal_n = 0;

float r15_lum(vec3 c) {
	return dot(c, vec3(0.30, 0.55, 0.15));
}

// A hash of three integers to 0..1: block x, block y and a salt (the tick and the draw).
float r15_h(int a, int b, int c) {
	uint x = uint(a) * 1664525u + uint(b) * 1013904223u + uint(c) * 2654435761u;
	x ^= x >> 16u;
	x *= 2246822519u;
	x ^= x >> 13u;
	x *= 3266489917u;
	x ^= x >> 16u;
	return float(x & 16777215u) / 16777216.0;
}

// Snapped to the palette: the nearest colour, the next only where the value truly falls
// between the two (r15.py `quant`, R12's LUT done per pixel).
vec3 r15_quant(vec3 img, vec2 p) {
	if (pal_n == 0) {
		return img;
	}
	vec3 c = floor(clamp(img, 0.0, 1.0) * 255.0 / 8.0) * 8.0 + 4.0;
	int a = 0, s = 0;
	float ad = 1e9, sd = 1e9;
	for (int k = 0; k < pal_n; k++) {
		vec3 dv = c - pal[k];
		float d = dot(dv, dv);
		if (d < ad) { s = a; sd = ad; a = k; ad = d; } else if (d < sd) { s = k; sd = d; }
	}
	vec3 c1 = pal[a], c2 = pal[s];
	vec3 seg = c2 - c1;
	float al = dot(c - c1, seg) / max(dot(seg, seg), 1e-6);
	al = clamp((al - 0.12) / 0.76, 0.0, 1.0);
	return (al > j_dith4(p) ? c2 : c1) / 255.0;
}

// The hull's alpha at screen pixel q (the baked stand-in, `ship` its canvas on screen).
float r15_alpha(sampler2D hull, vec2 q, vec4 ship) {
	return j_hull_px(hull, q - ship.xy, ship.zw).a;
}

// The tooltip's 1 px edge round the hull: outside it, touching it (3x3).
bool r15_ring(sampler2D hull, vec2 q, vec4 ship) {
	if (r15_alpha(hull, q, ship) > 0.5) {
		return false;
	}
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			if (r15_alpha(hull, q + vec2(float(x), float(y)), ship) > 0.5) {
				return true;
			}
		}
	}
	return false;
}
