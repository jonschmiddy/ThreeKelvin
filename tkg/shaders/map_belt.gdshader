shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// AN ASTEROID BELT'S DUST (SIMPLIFIED, direction C): a faint band of fine dust
// along each belt's orbit, lit by the star -- warmer and brighter near it, on
// the near side a little brighter still (light scattered toward you), mottled
// along its length and turning with the belt -- so from afar a belt reads as a
// band, with its lit rocks (`SystemView._Belts`) in it. Under the rocks, the
// worlds and the palette pass, in the place's 2x2 blocks; it dims what is
// behind it a little, as dust does.

// where the star is on screen, the map's zoom and slant
uniform vec2 origin = vec2(480.0, 270.0);
uniform float zoom = 1.0;
uniform float tilt = 0.38;
// each belt: its orbit (plane px), half width, the angle it has turned, on (0/1)
uniform vec4 belts[3];
uniform int n_belts = 0;
// the star's light (display colour), and how strongly a pulsar's beam lights each belt now
uniform vec3 star_col = vec3(1.0, 0.86, 0.62);
uniform vec3 beam_k = vec3(1.0);
uniform float strength = 1.0;

float bh(vec2 p) {
	ivec2 q = ivec2(floor(p));
	uint h = (uint(q.x) * 374761393u) ^ (uint(q.y) * 668265263u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}
float bn(vec2 p) {
	vec2 i = floor(p), f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = bh(i), b = bh(i + vec2(1.0, 0.0)), c = bh(i + vec2(0.0, 1.0)), d = bh(i + vec2(1.0, 1.0));
	return a + (b - a) * u.x + (c - a) * u.y + (a - b - c + d) * u.x * u.y;
}

void fragment() {
	vec2 px = floor(UV * vec2(960.0, 540.0));
	vec2 b = px - mod(px, 2.0) + 1.0;
	vec2 p = (b - origin) / max(zoom, 1e-3);
	vec2 pl = vec2(p.x, p.y / tilt);
	float rho = length(pl);
	float th = atan(pl.y, pl.x);
	vec3 L = vec3(0.0);
	float dim = 0.0;
	for (int i = 0; i < 3; i++) {
		if (i >= n_belts) break;
		vec4 bt = belts[i];
		float dr = rho - bt.x;
		float hw = bt.y;
		if (abs(dr) > hw * 2.4) continue;
		float a = th - bt.z;
		// mottled along its length, read on the circle so it has no seam
		vec2 ca = vec2(cos(a), sin(a));
		float mot = 0.55 + 0.45 * bn(ca * 9.0 + vec2(dr / 9.0, float(i) * 7.0)) * (0.7 + 0.3 * bn(ca * 3.0 + 11.0));
		float band = exp(-pow(dr / (hw * 0.95), 2.0)) * mot;
		// the star's light falling off with distance (the map's own `light_at`)
		float kl = 0.35 + 0.65 / (1.0 + rho * rho / (160.0 * 160.0));
		float near = clamp(pl.y / max(rho, 1.0), 0.0, 1.0);
		L += star_col * band * kl * (0.20 + 0.10 * near) * beam_k[i];
		dim = max(dim, band * 0.06);
	}
	L *= strength;
	COLOR = vec4(L, dim * strength);
}
