shader_type canvas_item;
render_mode unshaded;

// THE LAB'S SCREEN AS THE CHART (science S9, Jon's 1C, Nov 4): the glass's own
// ground, and on RESEARCH the galaxy the board's three arms are drawn on, as
// the approved mockup drew them (tk-scratch/science/sheet2/tree/build/build.py,
// `glass_ground`, `galaxy` and `vignette`). On a ColorRect over the glass, so
// it is drawn per pixel of the board at any size the camera has it at: the
// rect's UV is the glass, and every pixel here is one board pixel (`gsize`).
//
// NOT THE MOCKUP'S NUMBERS FOR THE NOISE: it drew its dust from numpy's seeded
// random grids, which a shader cannot reproduce, so the dust here is a hash on
// the same grid sizes and the same smoothstep. The arms, the core, the stars'
// density, the eight blues, the five warms, the dim and the tint are its own.

// The glass, in board px (the 960x540 the board is laid out on), and its corner:
// the ground's lift, its vignette and its dust are laid on this, the board's
// own glass, wherever the rect below is.
uniform vec2 gsize = vec2(908.0, 488.0);
uniform vec2 gpos = vec2(26.0, 26.0);
// Where this rect is, in board px: the lab's glass as the camera has it, at
// least the board's glass and as much more as shows (`LabZoom`, Jon, Nov 5:
// the camera stops where the lab's own glass fills the window). Past the
// board's glass the vignette goes on falling away to its darkest.
uniform vec2 rpos = vec2(26.0, 26.0);
uniform vec2 rsize = vec2(908.0, 488.0);
// The lab's screen tint, 0..255 (labs.json `screen.tint`).
uniform vec3 tint = vec3(190.0, 240.0, 235.0);
// How much of the galaxy is up: 1 on RESEARCH, 0 on the other two tabs.
uniform float galaxy = 1.0;
// The board's animation clock, 0..1 round its loop: some stars twinkle with it.
uniform float phase = 0.0;
// How far the screen has switched to the chart: the camera's move brings it up.
uniform float amount = 1.0;

const vec3 BG = vec3(10.0, 14.0, 21.0);
const float CX = 480.0;
const float CY = 250.0;
const float SX = 1.12;
const float SY = 0.47;

float bayer(vec2 p) {
	int x = int(mod(p.x, 4.0));
	int y = int(mod(p.y, 4.0));
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(m[y * 4 + x]) / 16.0;
}

float hash(vec2 p, float seed) {
	vec3 q = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973) + seed * 0.618);
	q += dot(q, q.yzx + 33.33);
	return fract((q.x + q.y) * q.z);
}

// The mockup's `sample_noise`: a grid of random values, smoothstepped between.
// `wrap` > 0 wraps x round that many cells (the disc's turn).
float noise(float fy, float fx, float gy, float wrap, float seed) {
	float y0 = clamp(floor(fy), 0.0, gy - 2.0);
	float x0 = floor(fx);
	float ty = clamp(fy - y0, 0.0, 1.0);
	float tx = fx - x0;
	ty = ty * ty * (3.0 - 2.0 * ty);
	tx = tx * tx * (3.0 - 2.0 * tx);
	float xa = wrap > 0.0 ? mod(x0, wrap) : x0;
	float xb = wrap > 0.0 ? mod(x0 + 1.0, wrap) : x0 + 1.0;
	float a = hash(vec2(xa, y0), seed);
	float b = hash(vec2(xb, y0), seed);
	float c = hash(vec2(xa, y0 + 1.0), seed);
	float d = hash(vec2(xb, y0 + 1.0), seed);
	return mix(mix(a, b, tx), mix(c, d, tx), ty);
}

vec3 blue(int i) {
	vec3 c[8] = vec3[8](vec3(9.0, 11.0, 20.0), vec3(14.0, 19.0, 38.0), vec3(21.0, 29.0, 60.0),
		vec3(30.0, 43.0, 92.0), vec3(36.0, 60.0, 128.0), vec3(54.0, 92.0, 176.0),
		vec3(96.0, 142.0, 228.0), vec3(170.0, 204.0, 255.0));
	return c[clamp(i, 0, 7)];
}

vec3 warm(int i) {
	vec3 c[5] = vec3[5](vec3(46.0, 24.0, 10.0), vec3(104.0, 54.0, 18.0), vec3(176.0, 96.0, 32.0),
		vec3(232.0, 150.0, 62.0), vec3(255.0, 206.0, 130.0));
	return c[clamp(i, 0, 4)];
}

void fragment() {
	// this board pixel: local to the glass, and on the board
	vec2 a = rpos + min(floor(UV * rsize), rsize - 1.0);
	vec2 l = a - gpos;
	float gw = gsize.x;
	float gh = gsize.y;
	// THE GROUND: the glass lifts toward its middle, in three dithered steps
	float nx = (l.x - gw / 2.0) / (gw / 2.0);
	float ny = (l.y - gh / 2.0) / (gh / 2.0);
	float r = sqrt(nx * nx * 0.9 + ny * ny);
	float lift = pow(clamp(1.0 - r, 0.0, 1.0), 1.4);
	float steps = floor(lift * 3.0 + bayer(l)) / 3.0;
	vec3 col = BG + tint * (0.025 + 0.03 * steps);
	if (galaxy > 0.0) {
		// THE GALAXY, tipped like the chart's, on the board's three arms
		float u = (a.x - CX) / SX;
		float v = (CY - a.y) / SY;
		float rho = length(vec2(u, v));
		float phi = atan(v, u);
		float P = 64.0;
		float fx = (phi + PI) / (2.0 * PI) * P;
		float n1 = noise(rho / 7.0, fx, 80.0, P, 3.0);
		float n2 = noise(rho / 3.0, fx * 3.0, 160.0, P * 3.0, 4.0);
		float n3 = noise((a.y - gpos.y) / 6.0, (a.x - gpos.x) / 6.0, gh / 6.0 + 3.0, 0.0, 5.0);
		float dust = clamp(0.5 * n1 + 0.3 * n2 + 0.2 * n3, 0.0, 1.0);
		float wind = radians(48.0) / 120.0;
		float arm = 0.0;
		for (int b = 0; b < 3; b++) {
			float a0 = b == 1 ? 0.0 : (b == 0 ? 120.0 : 240.0);
			float phi0 = radians(a0) - wind * 150.0;
			float x = phi - (phi0 + wind * rho);
			float d = atan(sin(x), cos(x));
			float dist = rho * abs(d);
			float width = 9.0 + 0.06 * rho;
			arm = max(arm, exp(-pow(dist / width, 2.0)));
		}
		float fade = clamp(1.0 - (rho - 338.0) / 34.0, 0.0, 1.0) * clamp(rho / 36.0, 0.0, 1.0);
		float I = arm * (0.35 + 0.85 * dust) * (1.15 - rho / 900.0) * fade + 0.2 * exp(-rho / 200.0) * dust;
		I = clamp(pow(clamp(I, 0.0, 1.0), 1.15), 0.0, 1.0);
		int q = int(clamp(floor(I * 7.0 + bayer(a) * 0.999), 0.0, 7.0));
		vec3 g = blue(q);
		float core = exp(-pow(rho / 78.0, 2.0)) * (0.55 + 0.6 * dust) + exp(-pow(rho / 40.0, 2.0)) * 0.5;
		float cq = floor(clamp(core, 0.0, 1.0) * 5.0 + bayer(a + vec2(1.0, 2.0)) * 0.999) - 1.0;
		if (cq >= 0.0) {
			g = warm(int(cq));
		}
		// the stars: about 260 on the glass, a quarter of them out at any time,
		// some twinkling round the board's loop
		float h = hash(a, 11.0);
		if (h < 260.0 / (gw * gh)) {
			float k = hash(a, 12.0);
			float tw = floor(hash(a, 13.0) * 4.0);
			float on = fract(k + phase * max(tw - 1.0, 0.0));
			if (on > 0.25) {
				float pick = hash(a, 14.0);
				vec3 sc = pick < 0.34 ? vec3(70.0, 80.0, 110.0) : (pick < 0.67 ? vec3(110.0, 130.0, 170.0) : vec3(200.0, 215.0, 255.0));
				g = max(g, sc);
			}
		}
		// dimmed, and leant toward the lab's phosphor
		float lum = dot(g, vec3(0.3, 0.59, 0.11));
		vec3 tinted = lum * tint / 200.0;
		g = (g * 0.62 + tinted * 0.38) * 0.72;
		col = mix(col, max(col, g), galaxy);
	}
	// THE VIGNETTE: the tube's corners fall away, three dithered steps
	float vx = (l.x + 0.5 - gw / 2.0) / (gw / 2.0);
	float vy = (l.y + 0.5 - gh / 2.0) / (gh / 2.0);
	float vr = pow(pow(abs(vx), 4.0) + pow(abs(vy), 4.0), 0.25);
	float vv = clamp((vr - 0.8) / 0.3, 0.0, 1.0);
	float vs = floor(vv * 3.0 + bayer(l)) / 3.0;
	col *= 1.0 - 0.6 * vs;
	COLOR = vec4(clamp(col / 255.0, 0.0, 1.0), amount);
}
