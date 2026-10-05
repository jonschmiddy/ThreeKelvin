shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// ONE SHEET OF DUST AT A DEPTH (Jon: "can we make the space dust ... volumetric?
// ... some volumetric depth that you have to wade through as you zoom and pan"):
// a screen-wide sheet at its own distance from the camera, so it grows and
// slides at its own rate as the map zooms and pans (`SystemView._step_depth`
// works out `q`, its size against the plane's, and its fade). Worked out in
// the place's 2x2 blocks and set to the system's colours by the palette pass
// after it.
//
// `look` 0: WISPS, faint strands of the system's two gas colours, added over
// the sky. `look` 1: FLUFF, billowy masses lit from the star's side, their
// cores dark and their rims glowing, laid over the sky (they hide what is
// behind them, a little).

uniform int look = 0;
// this sheet against the plane: q times as big, and slides q times as far
uniform float q = 0.5;
uniform float zoom = 1.0;
uniform vec2 pan = vec2(0.0);
uniform vec2 center = vec2(480.0, 270.0);
uniform vec2 star_at = vec2(480.0, 270.0);
uniform float seed = 0.0;
uniform float strength = 0.06;
// how much of it shows (its fade as it passes the camera or sinks to the plane)
uniform float alpha = 1.0;
// how big its clouds are, in the plane's own units
uniform float size = 260.0;
// how much of the sheet is cloud at all (higher: sparser)
uniform float cover = 0.55;
uniform vec3 pal0 = vec3(0.15, 0.6, 0.72);
uniform vec3 pal1 = vec3(0.82, 0.24, 0.55);
uniform vec3 star_col = vec3(1.0, 0.86, 0.62);
// the light a fluff's dense core still has (`look` 1): inside a nebula seen from
// inside (`sky_nebula`) the cloud round it glows through, and a black core over
// that sky set into hard black blots in the palette
uniform vec3 core_lift = vec3(0.0);

float hash2(vec2 p) {
	ivec2 qq = ivec2(floor(p));
	uint h = (uint(qq.x) * 374761393u) ^ (uint(qq.y) * 668265263u);
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
float smooth_k(float a, float b, float x) { float u = clamp((x - a) / (b - a), 0.0, 1.0); return u * u * (3.0 - 2.0 * u); }

// the cloud's density at a point of the sheet (its own units, one cloud wide)
float dens(vec2 w) {
	// a gentle warp only: more and the masses pull out into worms
	vec2 warp = vec2(fbm(w * 0.5 + vec2(seed, 3.0), 2), fbm(w * 0.5 + vec2(7.0, seed), 2)) - 0.5;
	float d = fbm(w + warp * 0.45 + vec2(seed * 1.7, -seed), 5);
	// billows: the big shape, rounded off by its own smaller lumps
	return smooth_k(cover - 0.06, cover + 0.2, d);
}

void fragment() {
	// a 2x2 block of the screen (a pixel of the half-size picture), its middle
	vec2 px = floor(UV * vec2(960.0, 540.0));
	vec2 b = px - mod(px, 2.0) + 1.0;
	// where on the sheet: the plane's own place as this sheet shows it
	float s = max(zoom * q, 1e-4);
	vec2 w = (b - center - pan * q) / s;
	// the slant: the sheets are seen edge-on like the plane, so squashed alike
	w.y /= 0.62;
	vec2 u = w / size;
	if (look == 0) {
		float d = dens(u);
		float strand = 1.0 - abs(2.0 * fbm(u * 3.1 + vec2(-seed, seed * 0.5), 3) - 1.0);
		float I = d * (0.35 + 0.65 * strand * strand) * strength * alpha;
		vec3 c = mix(pal0, pal1, fbm(u * 0.45 + vec2(seed * 0.3, 1.0), 2)) * I;
		COLOR = vec4(c, 0.0);
	} else {
		float d = dens(u);
		if (d <= 0.001) {
			COLOR = vec4(0.0);
		} else {
			// LIT FROM THE STAR'S SIDE: the density a step toward the star
			// against here -- thinner toward the star is a lit edge, thicker an
			// underside in its own shadow
			vec2 L = star_at - b;
			float ll = length(L);
			vec2 dir = ll > 0.5 ? L / ll : vec2(-1.0, 0.0);
			dir.y /= 0.62;
			float d2 = dens(u + normalize(dir) * 0.09);
			float lit = clamp((d - d2) * 3.0 + 0.35, 0.0, 1.0);
			// the dense core dark, its rim glowing
			float core = smooth_k(0.55, 1.0, d);
			float rim = d * (1.0 - core);
			vec3 gasc = mix(pal0, pal1, fbm(u * 0.5 + vec2(seed, 2.0), 2));
			vec3 dark = gasc * 0.10 + vec3(0.012, 0.016, 0.03) + core_lift;
			vec3 glow = mix(gasc, star_col, 0.35) * (0.25 + 0.75 * lit);
			vec3 c = mix(glow * (0.55 + 0.9 * rim), dark, core * (1.0 - 0.6 * lit));
			float a = clamp(d * strength * alpha, 0.0, 1.0);
			COLOR = vec4(c * a, a);
		}
	}
}
