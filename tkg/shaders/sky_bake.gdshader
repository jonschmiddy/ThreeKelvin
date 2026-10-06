shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE SYSTEM'S SKY, baked once (see `SkyBake.gd`): the mockup's `bakeLook` for
// Jon's picks -- its own nebula (two colours a system, brightest and tinted by
// the star near it, thinned over the system so the worlds sit on dark sky),
// dark dust in front lit at the edge that faces the star, the star's glow and
// gentle shafts, all worked out in 2x2 blocks for the chunky palette.
//
// mode 0 writes the sky WITHOUT the gas; mode 1 writes what the gas adds (RGB)
// and, round a pulsar, how much gas there is (A) for its beam to light. The
// stars come in as a texture, placed by GDScript from the mockup's generator.

uniform int mode = 0;
uniform sampler2D stars : filter_nearest, repeat_disable;
uniform float sd = 0.0;
uniform vec2 star_at = vec2(622.0, 262.0);
uniform vec3 star_col = vec3(1.0, 0.86, 0.62);
uniform vec3 pal0 = vec3(0.15, 0.6, 0.72);
uniform vec3 pal1 = vec3(0.82, 0.24, 0.55);
uniform float thick = 1.0;
uniform bool pulsar = false;
uniform float edge = 330.0;
uniform float tilt = 0.38;
uniform float x0 = 256.0;
// harness switches, to see what each layer darkens
uniform float rays_k = 1.0;
uniform float dust_k = 1.0;
// CLEAR SKY, outside a nebula: a faint band of the galaxy across it (0 none)
uniform float band = 0.0;
// how bright its glow is (SIMPLIFIED: none -- the band is told by its crowd of faint
// stars, since a glow this faint lands on the palette's first step as grey blobs)
uniform float band_glow = 0.06;
// how wide the band is and how far it wanders (PAINTED: slim and straighter)
uniform float band_w = 150.0;
uniform float band_wob = 160.0;
// how much the band breaks into lumpy masses (PAINTED: B's band, tones of navy in
// soft masses, never a flat slab)
uniform float band_lump = 0.0;
// SIMPLIFIED round a pulsar (C): the gas picture holds the remnant's shell as
// fields, not colour -- r its filaments, g the oxygen skin just inside its
// front, b how far inside the shell (0 the limb .. 1 deep), a how much gas
// for the beam -- and `sky.gdshader` colours them every frame, glimmering
uniform bool c_remnant = false;
// THE BAKE IS BIGGER THAN THE MAP by this much on every side, so the sky has
// somewhere to slide when the map pans; map coordinates are pixel - margin.
uniform vec2 bake_size = vec2(960.0, 540.0);
uniform float margin = 0.0;

const vec3 VOID = vec3(7.0, 10.0, 18.0) / 255.0;

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
float fbm2(vec2 p, int o) {
	float a = 0.5, s = 0.0, n = 0.0;
	for (int i = 0; i < o; i++) { s += a * noise2(p); n += a; p *= 2.03; a *= 0.5; }
	return s / n;
}
float smooth_k(float a, float b, float x) { float u = clamp((x - a) / (b - a), 0.0, 1.0); return u * u * (3.0 - 2.0 * u); }
float dust_at(vec2 p) { return smooth_k(0.56, 0.7, fbm2(vec2(p.x * 0.005 + 20.0 + sd, p.y * 0.008 + 3.0), 5)); }

float ridge_v(vec2 p, int o) { return 1.0 - abs(2.0 * fbm2(p, o) - 1.0); }
vec2 warp_v(vec2 p, float amt) { return p + amt * vec2(fbm2(p, 3) - 0.5, fbm2(p + vec2(5.2, 1.3), 3) - 0.5) * 2.0; }

// THE BLAST SHELL of the star that made the pulsar, seen from inside (C's
// `remnantShell`): a ragged front of filaments, big lobes where it ran into
// thin gas and flat dents where it met thick, broken in long stretches so it
// reads as arcs and wisps, fainter filaments across its face
vec4 remnant(vec2 P) {
	vec2 r = (P - star_at) / vec2(1.0, 0.66);
	float rho = length(r);
	vec2 dir = r / max(rho, 1e-3);
	// (as big as the showcase drew it: the system sits well inside its shell)
	float R = 330.0 * (1.0 + 0.30 * (fbm2(dir * 1.5 + 3.0 + sd, 4) - 0.5) + 0.12 * (fbm2(dir * 4.6 + 1.0, 3) - 0.5));
	float x = (rho - R) / R;
	float fil = ridge_v(warp_v(P / 48.0 + 3.0 + sd, 0.6), 5);
	float fil2 = ridge_v(warp_v(P / 28.0 + 9.0, 0.5), 4);
	float wl = 0.030 + 0.035 * smooth_k(0.3, 0.7, fbm2(dir * 3.1 + 5.0, 3));
	float limb = exp(-pow((x + 0.02) / wl, 2.0));
	float shellB = smooth_k(-0.30, -0.03, x) * (1.0 - smooth_k(-0.01, 0.04, x));
	float broken = smooth_k(0.38, 0.62, fbm2(dir * 2.2 + 7.0 + sd, 3) + 0.06);
	float inner = clamp(-x / 0.25, 0.0, 1.0);
	float s = limb * (0.10 + 1.25 * pow(fil, 6.0)) * broken
		+ shellB * pow(fil2, 8.0) * 0.7 * (0.3 + 0.7 * broken)
		+ smooth_k(-0.95, -0.25, x) * (1.0 - smooth_k(-0.25, -0.02, x)) * pow(fil, 12.0) * 0.30;
	float skin = pow(ridge_v(warp_v(P / 70.0 + 21.0, 0.8), 4), 3.2) * (0.25 + 0.75 * broken);
	return vec4(clamp(s, 0.0, 1.0), clamp(skin, 0.0, 1.0), inner, clamp(s * 0.25 + skin * 0.04, 0.0, 1.0));
}

void fragment() {
	vec2 tex_px = floor(UV * bake_size);
	vec2 px = tex_px - margin;
	if (px.x < x0) {
		COLOR = mode == 0 ? vec4(VOID, 1.0) : vec4(0.0);
	} else {
		// the large shapes, in 2x2 blocks
		vec2 b = px - mod(px, 2.0) + 0.5;
		vec3 Lb = texelFetch(stars, ivec2(tex_px), 0).rgb * 255.0 / 64.0;
		vec3 Gb = vec3(0.0);
		// THE GAS: wisps in two colours, brightest and tinted by the star near it
		float q = fbm2(vec2(b.x * 0.004 + sd, b.y * 0.006 - sd), 4);
		float w = fbm2(vec2(b.x * 0.004 + 5.2 + q * 1.7, b.y * 0.006 + 1.3 + q * 1.7), 5);
		float g;
		if (!pulsar) g = smooth_k(0.36, 0.96, w);
		else {
			float rr = length(vec2(b.x - star_at.x, (b.y - star_at.y) / 0.62));
			g = smooth_k(0.3, 0.8, w) * exp(-pow((rr - 190.0) / 95.0, 2.0)) * 1.3 + smooth_k(0.62, 0.9, w) * 0.2;
		}
		float mixv = fbm2(vec2(b.x * 0.007 + 9.0 + sd, b.y * 0.011), 3);
		float fil = pow(1.0 - abs(2.0 * fbm2(vec2(b.x * 0.016 + sd, b.y * 0.024), 4) - 1.0), 7.0);
		vec2 dv = vec2(b.x - star_at.x, (b.y - star_at.y) / 0.7);
		float d = max(length(dv), 1e-3), near = pulsar ? 0.0 : exp(-d / 230.0);
		// thinned over the system itself, so the worlds and orbits sit on darker sky
		vec2 e2 = vec2((b.x - star_at.x) / (edge + 30.0), (b.y - star_at.y) / ((edge + 30.0) * tilt + 30.0));
		float clear_k = pulsar ? 1.0 : 0.4 + 0.6 * smooth_k(0.75, 1.2, length(e2));
		float I = (pow(g, 1.5) * 0.44 + g * fil * 0.45 * 0.85) * (0.45 + 1.3 * near) * thick * clear_k;
		vec3 gc = mix(mix(pal0, pal1, mixv), star_col, near * 0.5);
		vec3 gas_l = I > 0.01 ? I * gc : vec3(0.0);
		// the dust, and its edge that faces the star catching the light
		// NO DUST AMONG THE ORBITS (Jon: "why is that dust lane there? it seems
		// like it's following epsilon kestrel"). A lane is drawn once and never
		// moves, so beside a world it read as that world's shadow, lagging. Cleared
		// over the system the way the gas is thinned, so the only dark shape near a
		// world is its own shadow.
		float dust_clear = dust_k * smooth_k(0.75, 1.2, length(e2));
		float dk = dust_clear * dust_at(b), back = dust_clear * dust_at(vec2(b.x - dv.x / d * 5.0, b.y - dv.y / d * 5.0 * 0.7));
		float rim = max(0.0, dk - back);
		vec3 rim_l = rim > 0.03 ? rim * (0.4 + 1.4 * near) * 0.45 * mix(vec3(1.0, 0.92, 0.84), star_col, 0.4) : vec3(0.0);
		// (round a pulsar the gas is its remnant shell, round the pulsar in the
		// system and not far sky: it goes in the gas picture with the rest, which
		// `sky.gdshader` carries and zooms with the pulsar)
		Gb += gas_l + rim_l;
		// THE GALAXY'S BAND, far off, in a clear sky: a soft glow along a line
		// across the view, mottled, faint
		if (band > 0.0) {
			float ang = sd * 2.7;
			vec2 nrm = vec2(-sin(ang), cos(ang));
			float off = dot(b - vec2(480.0, 270.0), nrm) + (fbm2(vec2(b.x * 0.003 + sd, b.y * 0.003), 3) - 0.5) * band_wob;
			float glow = exp(-pow(off / band_w, 2.0)) * (0.55 + 0.45 * fbm2(vec2(b.x * 0.012 + 3.0 + sd, b.y * 0.012), 4));
			glow *= mix(1.0, 0.25 + 1.1 * smooth_k(0.32, 0.68, fbm2(vec2(b.x * 0.0045 + 7.0 + sd, b.y * 0.0045), 3)), band_lump);
			Lb += band * band_glow * glow * vec3(0.62, 0.62, 0.78);
		}
		// THE STAR'S OWN LIGHT ROUND IT is not baked: it rides the star as the map
		// zooms and pans (`sky.gdshader`), and reads the dust from this bake's alpha.
		// what lies behind the dust is dimmed by it
		float k = 1.0 - dk * 0.85;
		Lb *= k;
		Gb *= k;
		vec3 base = (Lb.r + Lb.g + Lb.b) < 0.004 ? VOID : min(vec3(1.0), VOID + (1.0 - exp(-1.5 * Lb)));
		if (mode == 1 && pulsar && c_remnant) COLOR = remnant(b);
		else if (mode == 0) COLOR = vec4(base, dk);
		else COLOR = vec4((1.0 - exp(-1.5 * (Lb + Gb))) - (1.0 - exp(-1.5 * Lb)), pulsar ? clamp(I / 4.0, 0.0, 1.0) : 0.0);
	}
}
