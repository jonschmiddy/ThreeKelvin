shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// A PULSAR'S OWN WRECK, alive: the system map's web of filaments round the
// pulsar (`bakeWreck` + `webDraw` in the scratchpad's `sysmap/template.html`;
// Jon picked "A web of filaments", then: "it looks bad static and just
// chilling there"), and the remnant gas lit by the beam like a lighthouse in
// fog (`pulsarGasLit`). Drawn over the whole map, all of it light: rgb with
// alpha 0, ADDED to the sky behind.
//
// The page baked its threads once into a list and drew each one every frame,
// turned with the whole web. A shader runs the other way round: each pixel
// turns itself BACK by the web's turn to find which thread would land on it,
// and works that thread out where it was baked -- the same noise, at the same
// place, so the web is the page's own. The page placed threads on half pixels
// of its doubled canvas; here they land on whole game pixels, and a pixel
// takes one thread where the page could stack two or leave a gap as the web
// turned.
//
// Every position here is in MAP pixels, the page's own: the noise was cut at
// those coordinates, so a web drawn anywhere else would be a different web.
// The web is cut where the pulsar stood when it was set up (`anchor`) and
// carried with it: a pixel's offset from the pulsar's centre this moment, over
// the zoom, is its offset from the anchor in the web as baked. So the map pans
// the web with its pulsar, and zooms it by working the threads out over more
// pixels, never by stretching them; the dither stays on game pixels.

// the map pixel this rect's top-left covers, and the pulsar's centre, in map pixels
uniform vec2 origin = vec2(264.0, 0.0);
uniform vec2 rect_size = vec2(696.0, 540.0);
uniform vec2 centre = vec2(622.0, 262.0);
// where the pulsar's centre was when the web was cut, in map pixels at zoom 1,
// and the map's zoom
uniform vec2 anchor = vec2(622.0, 262.0);
uniform float zoom = 1.0;
// the left edge of the map: the page baked no thread left of its panel
uniform float panel_x = 264.0;
uniform vec2 map_size = vec2(960.0, 540.0);
// the system's own web (index * 1.37), the web's turn (0.012 t), the threads' shimmer clock (0.9 t)
uniform float sd = 0.0;
uniform float turn = 0.0;
uniform float shimmer_t = 0.0;
// the beam's angle on screen, both ends of it; no beam while it points at or away from you
uniform float beam_angle = 0.0;
uniform bool has_beam = false;
uniform bool web_on = true;
// the remnant gas, from the sky's bake: per map pixel, how bright the pulsar's
// gas is there (the sky's `I`), in the red channel, unscaled
uniform sampler2D gas_tex : filter_nearest, repeat_disable;
uniform bool has_gas = false;

const vec3 WEB_COL[8] = vec3[8](
	vec3(20.0, 40.0, 74.0), vec3(34.0, 64.0, 122.0), vec3(58.0, 106.0, 168.0), vec3(106.0, 160.0, 208.0),
	vec3(42.0, 28.0, 82.0), vec3(74.0, 48.0, 128.0), vec3(106.0, 74.0, 160.0), vec3(138.0, 106.0, 192.0)
);

// ---------------------------------------------------------------- noise, as the page's
float hash2(float x, float y) {
	uint h = (uint(int(x)) * 374761393u) ^ (uint(int(y)) * 668265263u);
	h = (h ^ (h >> 13u)) * 1274126177u;
	return float(h ^ (h >> 16u)) / 4294967296.0;
}
float noise(float x, float y) {
	float xi = floor(x), yi = floor(y), xf = x - xi, yf = y - yi;
	float u = xf * xf * (3.0 - 2.0 * xf), v = yf * yf * (3.0 - 2.0 * yf);
	float a = hash2(xi, yi), b = hash2(xi + 1.0, yi), c = hash2(xi, yi + 1.0), d = hash2(xi + 1.0, yi + 1.0);
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
float fbm2(float x, float y, int o) {
	float a = 0.5, s = 0.0, n = 0.0;
	for (int i = 0; i < o; i++) { s += a * noise(x, y); n += a; x *= 2.03; y *= 2.03; a *= 0.5; }
	return s / n;
}
float smooth_k(float a, float b, float x) { float u = clamp((x - a) / (b - a), 0.0, 1.0); return u * u * (3.0 - 2.0 * u); }
int bayer4(int x, int y) {
	int bx = x & 3, by = y & 3;
	return by == 0 ? (bx == 0 ? 0 : bx == 1 ? 8 : bx == 2 ? 2 : 10)
		: by == 1 ? (bx == 0 ? 12 : bx == 1 ? 4 : bx == 2 ? 14 : 6)
		: by == 2 ? (bx == 0 ? 3 : bx == 1 ? 11 : bx == 2 ? 1 : 9)
		: (bx == 0 ? 15 : bx == 1 ? 7 : bx == 2 ? 13 : 5);
}

void fragment() {
	vec2 P = origin + floor(UV * rect_size);
	vec3 acc = vec3(0.0);

	// THE WEB: which thread turns onto this pixel, and the thread as baked
	if (web_on) {
		// (read a quarter pixel up and left: the page rounded each thread to a half
		// pixel of its doubled canvas, and a game pixel shows the top-left of that
		// 2x2 block, so a thread moves on a pixel once it has gone a quarter of one)
		float ux = P.x - 0.25 - centre.x, uy = (P.y - 0.25 - centre.y) / 0.62;
		float ct = cos(turn), st = sin(turn);
		float rx = ux * ct + uy * st, ry = -ux * st + uy * ct;
		// the game pixel it lands on unturned, from the centre (whole game pixels),
		// then that place in the web as baked: whole map pixels at zoom 1
		float gx = floor(centre.x + rx + 0.5) - centre.x, gy = floor(centre.y + ry * 0.62 + 0.5) - centre.y;
		float x = anchor.x + gx / zoom, y = anchor.y + gy / zoom;
		ivec2 dth = ivec2(int(anchor.x + gx), int(anchor.y + gy));
		if (x >= panel_x && x < map_size.x && y >= 0.0 && y < map_size.y) {
			float dx = x - anchor.x, dy = (y - anchor.y) / 0.62, r = sqrt(dx * dx + dy * dy);
			// a broad, broken ring of fine threads, gaps where the shell has thinned
			float bd = (r - 170.0) / 75.0;
			float band = exp(-bd * bd) * smooth_k(0.42, 0.62, fbm2(x * 0.006 + sd, y * 0.009 + sd, 3));
			if (band >= 0.02) {
				float n = fbm2(x * 0.018 + sd, y * 0.024 + sd, 4), ridge = pow(1.0 - abs(2.0 * n - 1.0), 16.0);
				float v = band * ridge * 2.4;
				int k = int(floor(v * 4.0 + float(bayer4(dth.x, dth.y)) / 16.0));
				if (k > 0) {
					int step_k = min(3, k - 1);
					int hue = fbm2(x * 0.008 + 50.0 + sd, y * 0.008, 2) > 0.55 ? 1 : 0;
					float ph = fbm2(x * 0.03 + sd, y * 0.03, 2) * 9.0;
					// each thread flares as the beam sweeps across it and fades behind
					// (the thread's angle on screen as the page read it, from a table of 1024)
					float lit = 0.0;
					if (has_beam) {
						float aa = atan(dx * st + dy * ct, dx * ct - dy * st);
						aa = floor(fract(aa / TAU) * 1024.0) / 1024.0 * TAU;
						float ta = atan(sin(aa) * 0.62, cos(aa));
						float d = abs(mod(ta - beam_angle, PI));
						d = min(d, PI - d);
						d = floor(d / PI * 256.0) / 256.0 * PI;
						lit = exp(-(d / 0.2) * (d / 0.2)) + 0.4 * exp(-d / 0.55);
					}
					// a slow shimmer, each patch of thread on its own phase
					float shim = 0.75 + 0.25 * sin(floor(fract((shimmer_t + ph) / TAU) * 1024.0) / 1024.0 * TAU);
					int kk = min(3, step_k + (lit > 0.6 ? 1 : 0));
					float q = min(15.0, floor(((0.18 + 1.15 * lit) * shim - 0.06) / 0.06 + 0.5));
					if (q >= 0.0) acc += floor(WEB_COL[hue * 4 + kk] * (0.06 + q * 0.06)) / 255.0;
				}
			}
		}
	}

	// THE GAS LIT BY THE BEAM, both ends of it, where it points this moment
	if (has_gas && has_beam) {
		// the gas as baked, carried and zoomed with the pulsar: read between its
		// pixels when zoomed, so it is not blocks (at zoom 1 it lands on them)
		vec2 G = anchor + (P - centre) / zoom;
		ivec2 gmax = textureSize(gas_tex, 0) - ivec2(1);
		vec2 g0 = floor(G), gf = G - g0;
		ivec2 i0 = clamp(ivec2(g0), ivec2(0), gmax), i1 = clamp(ivec2(g0) + ivec2(1), ivec2(0), gmax);
		float I = mix(mix(texelFetch(gas_tex, i0, 0).r, texelFetch(gas_tex, ivec2(i1.x, i0.y), 0).r, gf.x),
			mix(texelFetch(gas_tex, ivec2(i0.x, i1.y), 0).r, texelFetch(gas_tex, i1, 0).r, gf.x), gf.y);
		if (G.x < 0.0 || G.y < 0.0 || G.x > float(gmax.x) || G.y > float(gmax.y)) I = 0.0;
		if (I > 0.03) {
			float sa = atan(P.y - centre.y, P.x - centre.x);
			float d = abs(mod(sa - beam_angle + PI * 0.5, PI) - PI * 0.5);
			if (d < 0.42) {
				d = floor(d / 0.42 * 256.0) / 256.0 * 0.42;
				float w = min(1.0, exp(-(d / 0.2) * (d / 0.2)) + 0.3 * exp(-d / 0.35)) * (d > 0.36 ? (0.42 - d) / 0.06 : 1.0);
				if (w >= 0.04) acc += floor(floor((1.0 - exp(-1.5 * I * 2.2)) * 255.0 * vec3(0.72, 0.88, 1.0)) * w) / 255.0;
			}
		}
	}
	COLOR = vec4(acc, 0.0);
}
