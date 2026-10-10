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
// THE BOWSHOCK (`SkyWeather`, on every warp-in): a soft ring pushed into the
// fluff round the ship -- (x, y on screen, its radius, its strength) and its
// colour. It shows only where there is dust.
uniform vec4 ev = vec4(-9999.0, -9999.0, 0.0, 0.0);
uniform vec3 ev_col = vec3(0.55, 0.62, 0.8);
// SIMPLIFIED (direction C, "Alive"): the sheets made richer -- their dense cores a
// dark brown-violet in the cloud's own shade (never black, never the cloud's
// mid colour laid over everything), their sides toward the sun lit, and only
// near it: the sun's light falls off with distance (gathered, in the cloud's
// light px), from `lit_far` to `lit_near` as it nears; the wisps in the
// cloud's own glow, faint far out
uniform bool simplified = false;
uniform vec3 dark_col = vec3(0.10, 0.05, 0.08);
uniform vec3 lit_far = vec3(0.45, 0.30, 0.34);
uniform vec3 lit_near = vec3(0.34, 0.50, 0.47);
uniform vec3 wisp_col = vec3(0.25, 0.10, 0.14);
uniform float home_zoom = 1.0;
uniform float lscale = 0.94;
// THE SHEET CLOSE IN (Jon: "dust looking flat and not visually interesting"):
// a far sheet's distance beyond the plane (0: a near slot), so it knows how many
// times bigger than at the opening zoom it is drawn (`mag`). Zoomed in, the
// fluff was the opening's few soft octaves blown up -- a dull brown blanket of
// flat plates. Now, the closer it is drawn: finer octaves of its own billows
// resolve (one for every doubling, faded in, never popping), its light-facing
// sides catch a little of the sky's scattered light even far from the sun, so
// the masses read as lumps in depth, its lit edge stays a crisp rim instead of
// widening with the zoom, and its edges and its light are dithered across the
// palette's steps instead of set as plates. At the opening zoom (mag 1) every
// one of these is off: the sheet is as Jon approved it.
uniform float dist = 0.0;
// PAINTED: its paint pass bands the sheets itself; none of the close-in work
uniform bool painted = false;

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
// the same, with `o` octaves the last faded in by its fraction (never popping
// as the zoom adds one); its sum normalised by the whole octaves alone, so the
// big shapes keep their weight as the fine ones arrive
float fbmf(vec2 p, float o) {
	float a = 0.5, s = 0.0, n = 0.0;
	int whole = int(floor(o));
	for (int i = 0; i < 9; i++) {
		float w = clamp(o - float(i), 0.0, 1.0);
		if (w <= 0.0) break;
		float v = noise2(p);
		// (the whole octaves as `fbm` sums them; the ones beyond add their lumps
		// about the middle, so the cloud keeps its cover as they come in)
		if (i < whole) { s += a * v; n += a; } else { s += a * w * (v - 0.5); }
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return s / max(n, 1e-5);
}
const float BAYER4[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
float bay_jit(vec2 b) {
	ivec2 bq = ivec2(b / 2.0) & ivec2(3);
	return (BAYER4[bq.y * 4 + bq.x] + 0.5) / 16.0 - 0.5;
}
float smooth_k(float a, float b, float x) { float u = clamp((x - a) / (b - a), 0.0, 1.0); return u * u * (3.0 - 2.0 * u); }

// the cloud's density at a point of the sheet (its own units, one cloud wide),
// with `ob` octaves more of its own fine lumps (0 at the opening zoom)
float dens(vec2 w, float ob) {
	// a gentle warp only: more and the masses pull out into worms
	vec2 warp = vec2(fbm(w * 0.5 + vec2(seed, 3.0), 2), fbm(w * 0.5 + vec2(7.0, seed), 2)) - 0.5;
	float o = (simplified ? 4.0 : 5.0);
	float d = ob > 0.0 ? fbmf(w + warp * 0.45 + vec2(seed * 1.7, -seed), o + ob) : fbm(w + warp * 0.45 + vec2(seed * 1.7, -seed), int(o));
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
	// the sun's light here (SIMPLIFIED), as the cloud works it out
	// how many times bigger than at the opening zoom this sheet is drawn, and what
	// that buys: octaves, scattered light, crisp rims, dither (all 0 at mag 1)
	float mag = dist > 0.0 ? s * (1.0 / max(home_zoom, 1e-3) + dist) : 1.0;
	float ob = clamp(log2(max(mag, 1.0)) * 1.4, 0.0, 3.0);
	float mk = painted ? 0.0 : smooth_k(1.15, 2.4, mag);
	if (painted) ob = 0.0;
	vec2 dsun = b - star_at;
	float dL = length(dsun * vec2(1.0, 1.15)) / (pow(max(zoom, 1e-3) / max(home_zoom, 1e-3), 0.42) * lscale);
	float Js = 1.0 / (1.0 + pow(dL / 155.0, 2.0));
	if (look == 0) {
		float d = dens(u, 0.0);
		float strand = 1.0 - abs(2.0 * fbm(u * 3.1 + vec2(-seed, seed * 0.5), 3) - 1.0);
		float I = d * (0.35 + 0.65 * strand * strand) * strength * alpha;
		vec3 c = mix(pal0, pal1, fbm(u * 0.45 + vec2(seed * 0.3, 1.0), 2)) * I;
		if (simplified) c = wisp_col * I * (0.4 + Js) * 2.0;
		COLOR = vec4(c, 0.0);
	} else {
		float d = dens(u, ob);
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
			// (the probe toward the light a little shorter as the sheet grows, so
			// its lit edge stays a rim and does not widen into a band)
			float d2 = dens(u + normalize(dir) * 0.09 / mix(1.0, sqrt(max(mag, 1.0)), mk), ob);
			float lit = clamp((d - d2) * 3.0 + 0.35, 0.0, 1.0);
			// the dense core dark, its rim glowing
			float core = smooth_k(0.55, 1.0, d);
			float rim = d * (1.0 - core);
			vec3 gasc = mix(pal0, pal1, fbm(u * 0.5 + vec2(seed, 2.0), 2));
			vec3 dark = gasc * 0.10 + vec3(0.012, 0.016, 0.03) + core_lift;
			vec3 glow = mix(gasc, star_col, 0.35) * (0.25 + 0.75 * lit);
			vec3 c = mix(glow * (0.55 + 0.9 * rim), dark, core * (1.0 - 0.6 * lit));
			if (simplified) {
				// dark, lit only on the side toward the sun and only near it
				vec3 lc = mix(lit_far, lit_near, clamp(Js * 1.3, 0.0, 1.0));
				float lk = clamp((d - d2) * 3.0, 0.0, 1.0) * (0.15 + 0.85 * Js) + rim * 0.25 * Js;
				// (close in: the side toward the light lifted by the sky's own scattered
				// light wherever it is, so the masses have form far from the sun too)
				lk += mk * 0.22 * clamp((d - d2) * 4.0, 0.0, 1.0) * (1.0 - Js);
				lk *= 1.0 + bay_jit(b) * 0.22 * mk;
				c = mix(dark_col, lc, clamp(lk, 0.0, 1.0));
			}
			float a = clamp(d * strength * alpha * (1.0 + bay_jit(b + vec2(2.0, 0.0)) * 0.25 * mk), 0.0, 1.0);
			vec3 bow = vec3(0.0);
			if (ev.w > 0.0) {
				bow = ev_col * ev.w * exp(-pow((length(b - ev.xy) - ev.z) / 5.0, 2.0)) * d * 0.55 * alpha;
			}
			COLOR = vec4(c * a + bow, a);
		}
	}
}
