shader_type canvas_item;
render_mode unshaded;

// A BANK OF DUST ACROSS LOCAL'S SKY (`LocalFx`: a red star's warm dust, a dust
// shoal across the lane). Not a thing with an outline (debris and buoys went 0
// for 13 as pictures), so drawn here: a mass of fine dust in 2x2 blocks, as the
// sky is, thick in its heart and thinning to scattered grains at its edge, lit
// on the side toward the star and shadowed away from it, its colours pulled to
// the system's own palette (`pal`, the sky's), drifting very slowly. Behind the
// subject's pieces; never on your ship, never under the event's band.
//
// The bank is an ellipse (`centre`, `radii`, turned `tilt`) roughened by noise.

uniform vec2 centre = vec2(700.0, 160.0);
uniform vec2 radii = vec2(260.0, 120.0);
uniform float tilt = 0.0;
uniform float dens = 0.85;
uniform vec3 lit_col = vec3(0.62, 0.38, 0.22);
uniform vec3 dark_col = vec3(0.12, 0.07, 0.06);
uniform vec2 to_star = vec2(-0.6, -0.8);
uniform float time = 0.0;
uniform vec2 drift = vec2(-1.2, 0.3);
uniform float seed = 0.0;
uniform vec4 ship = vec4(-999.0, -999.0, 0.0, 0.0);
uniform float band_y = 9999.0;
uniform vec3 pal[72];
uniform int pal_n = 0;

varying vec2 local;

void vertex() {
	local = VERTEX;
}

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vn(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(h21(i), h21(i + vec2(1.0, 0.0)), u.x), mix(h21(i + vec2(0.0, 1.0)), h21(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * vn(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v / 0.9375;
}

float bayer2(vec2 p) {
	vec2 i = mod(floor(p), 2.0);
	return i.x == i.y ? (i.x < 0.5 ? 0.125 : 0.375) : (i.x < 0.5 ? 0.875 : 0.625);
}

void fragment() {
	// in 2x2 blocks, as the sky is drawn
	vec2 b = floor(local / 2.0);
	vec2 p = b * 2.0 + 1.0;
	vec2 q = p - centre;
	float c = cos(-tilt);
	float s = sin(-tilt);
	q = vec2(q.x * c - q.y * s, q.x * s + q.y * c);
	vec2 w = (p + vec2(seed * 31.0, seed * 17.0) - drift * time) / 46.0;
	float n = fbm(w);
	float n2 = fbm(w * 2.7 + 5.0);
	float rr = length(q / radii) + (n - 0.5) * 0.55;
	float body = clamp(1.0 - rr, 0.0, 1.0);
	float d = clamp(body * 2.2 * dens * (0.55 + 0.75 * n) - 0.08, 0.0, 1.0);
	// grains scattered past its edge
	if (d <= 0.0 && rr < 1.35 && h21(b + seed) > 0.985 - 0.06 * (1.35 - rr)) {
		d = 0.35;
	}
	// kept off your ship and above the band
	vec2 lo = ship.xy - 10.0;
	vec2 hi = ship.xy + ship.zw + 10.0;
	vec2 dd = max(max(lo - p, p - hi), vec2(0.0));
	d *= clamp(length(dd) / 18.0, 0.0, 1.0);
	d *= clamp((band_y - p.y) / 16.0, 0.0, 1.0);
	// stepped cover, dithered between steps (the sky's own way)
	float cover = floor(d * 4.0 + bayer2(b)) / 4.0;
	if (cover <= 0.0) {
		discard;
	}
	// lit toward the star: the slope of the dust's own thickness that way
	float toward = (fbm(w + to_star * 0.06) - n) * 9.0 + 0.45 + 0.25 * (n2 - 0.5);
	float l = clamp(toward, 0.0, 1.0);
	l = floor(l * 3.0 + bayer2(b + 1.0)) / 3.0;
	vec3 colr = mix(dark_col, lit_col, l);
	if (pal_n > 0) {
		vec3 qq = colr * 255.0;
		float best = 1e9;
		vec3 pick = colr;
		for (int i = 0; i < pal_n; i++) {
			vec3 e = qq - pal[i] * 255.0;
			float de = e.r * e.r * 2.0 + e.g * e.g * 4.0 + e.b * e.b * 3.0;
			if (de < best) {
				best = de;
				pick = pal[i];
			}
		}
		colr = mix(colr, pick, 0.6);
	}
	COLOR = vec4(colr, clamp(cover * 0.92, 0.0, 0.92));
}
