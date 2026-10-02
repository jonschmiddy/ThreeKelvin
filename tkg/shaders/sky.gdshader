shader_type canvas_item;
render_mode unshaded, blend_disabled;

// THE SKY EACH FRAME: the baked sky (`sky_bake.gdshader`) with its gas added
// back under slow waves of brightness, so its bands of colour creep and shift
// under the palette (Jon: "why does the gas no longer move slightly?"); and
// round a pulsar, the shell's gas lit where the beam points, like a
// lighthouse's beam in fog, both ends of it at once.
//
// THE SKY IS FAR AWAY. When the map pans it slides by `sky_off`, a tenth of
// the pan, behind orbits that move the whole way (Jon: "a parallax
// background"); the bake has `margin` pixels to spare on every side.
//
// THE STAR'S OWN LIGHT IS NOT FAR AWAY: the glow round it and the gentle
// shafts through the dust ride the star as the map pans and grow as it zooms.
// It is added here, in the same tone map the bake used, through the dust the
// bake kept in its alpha.

uniform sampler2D base : filter_nearest, repeat_disable;
uniform sampler2D gas : filter_nearest, repeat_disable;
uniform float time = 0.0;
uniform bool pulsar = false;
// where the star is on screen this frame, and how far the map is zoomed
uniform vec2 star_at = vec2(480.0, 270.0);
uniform float zoom = 1.0;
uniform vec3 star_col = vec3(1.0, 0.86, 0.62);
uniform float rays_k = 1.0;
uniform vec2 sky_off = vec2(0.0);
uniform float margin = 0.0;
// the beam's angle on screen, and whether it points across the screen at all
uniform float beam_angle = 0.0;
uniform bool beam_on = false;

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

float lit_by_beam(float d) {
	if (d >= 0.42) return 0.0;
	return min(1.0, exp(-pow(d / 0.2, 2.0)) + 0.3 * exp(-d / 0.35)) * (d > 0.36 ? (0.42 - d) / 0.06 : 1.0);
}

void fragment() {
	vec2 px = floor(UV * vec2(960.0, 540.0));
	ivec2 tp = ivec2(px - floor(sky_off) + margin);
	vec4 bs = texelFetch(base, tp, 0);
	vec3 c = bs.rgb;
	float dk = bs.a;
	vec4 g = texelFetch(gas, tp, 0);
	vec2 b = px - mod(px, 2.0);
	float m = 1.0 + 0.24 * sin(b.x * 0.011 + time * 0.22) * sin(b.y * 0.017 - time * 0.16)
		+ 0.12 * sin(b.x * 0.029 - time * 0.31) * cos(b.y * 0.025 + time * 0.27);
	c = min(vec3(1.0), c + g.rgb * m);
	// the star's light, in 2x2 blocks as the bake worked it out, at the zoom
	vec2 sv = (b + 0.5 - star_at) / zoom;
	float dd = length(vec2(sv.x, sv.y * 1.25));
	float I2 = (0.36 * exp(-dd / 42.0) + 0.06 * exp(-dd / 160.0)) * (pulsar ? 0.35 : 1.0);
	if (!pulsar) {
		float a = atan(sv.y, sv.x), n = fbm2(vec2(a * 7.0 + 30.0, 3.1), 3);
		float rays = pow(max(0.0, n - 0.45) * 2.6, 3.0);
		I2 += rays_k * rays * 0.05 * exp(-dd / 260.0) * smooth_k(10.0, 60.0, dd);
	}
	vec3 P = I2 * (1.0 - dk * 0.5) * (1.0 - dk * 0.85) * star_col;
	c = min(vec3(1.0), VOID + 1.0 - (1.0 - max(c - VOID, vec3(0.0))) * exp(-1.5 * P));
	if (pulsar && beam_on && g.a > 0.0075) {
		float a = atan(px.y - star_at.y, px.x - star_at.x);
		float d1 = abs(mod(a - beam_angle + PI, 2.0 * PI) - PI);
		float d2 = abs(mod(a - beam_angle, 2.0 * PI) - PI);
		float w = max(lit_by_beam(d1), lit_by_beam(d2));
		float add2 = 1.0 - exp(-1.5 * g.a * 4.0 * 2.2);
		c = min(vec3(1.0), c + w * add2 * vec3(1.0, 0.88, 0.72));
	}
	COLOR = vec4(c, 1.0);
}
