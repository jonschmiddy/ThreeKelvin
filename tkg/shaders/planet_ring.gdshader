shader_type canvas_item;
render_mode unshaded, blend_premul_alpha;

// HALF A WORLD'S RINGS, painted per game pixel (Jon: "can these rings be a bit
// nicer? they're flat"). Two of these sit round each ringed world: the far half
// drawn before the world, the near half after it, as the dots were.
//
// Each pixel is turned back into the point on the ring's plane it shows, and
// the ring there is read from the world's strip (`Rings.gd`): how much light
// it stops, how bright its stuff is. Then lit:
//   - the face you see is the sunlit one or the dark one. Sunlit, the ring
//     shines by its stuff, dimmer when the sun is low across it. From the dark
//     side the light comes THROUGH it, so the thick ring is dark and the thin
//     parts and the gaps glow -- the gaps turn from dark lines to light ones;
//   - the world's shadow falls across it behind the world, with a soft edge.
// Sixteen samples a block, gathered, so a gap thinner than a block still
// dims the block it crosses; then the value set in the world's own ramp with
// its 2x2 dither, and how solid the ring is set in three steps (none, half,
// all): a thin ring lets the world and the sky through.

uniform sampler2D ramps : filter_nearest, repeat_disable;
uniform sampler2D prof : filter_linear, repeat_disable;
uniform int cell = 1;
// THE LIVE CENTRE (the map's smooth zoom, `SystemView`): where the world's true
// centre sits off the box's own (px, under a block either way), so the disc is drawn
// round it while the box stays on the grid; the dither keeps the grid's
uniform vec2 ctr_off = vec2(0.0);
uniform float r = 8.0;
uniform int half_w = 20;
uniform int half_h = 8;
uniform bool near = false;
// the ring's plane: seen this far open (the squash), the rest of it away from you
uniform float open = 0.28;
uniform float rin = 1.5;
uniform float rout = 2.2;
uniform int ramp_a = 12;
uniform int ramp_b = 27;
// how dark the world's shadow on the ring is (1: black)
uniform float dark_shadow = 0.9;
uniform vec3 light = vec3(-0.83, -0.31, 0.47);
uniform float k_light = 1.0;
uniform vec2 star_at = vec2(-9999.0);
uniform float star_r = 0.0;
uniform vec2 centre = vec2(0.0);
// PAINTED (direction B): the profile set in three steps of the ring's ramp, its
// edges a step darker, a thin ring a checker over the sky (never half alpha), the
// world's shadow a crisp dark wedge
uniform bool painted = false;
// RADIANT: the ring scatters the light -- bright on the sun's side, and lit from
// behind it glows through its thin parts, a translucent veil of light
uniform bool radiant = false;

vec3 rampc(int ramp, int k) { return texelFetch(ramps, ivec2(clamp(k, 0, 5), ramp), 0).rgb; }
float bayer2(float x, float y) {
	int cl = max(cell, 1);
	int ix = ((int(x) + 1000 * cl) / cl) & 1, iy = ((int(y) + 1000 * cl) / cl) & 1;
	return iy == 0 ? (ix == 0 ? 0.0 : 2.0) : (ix == 0 ? 3.0 : 1.0);
}

void fragment() {
	vec2 S2 = vec2(float(2 * half_w + 1), float(2 * half_h + 1));
	vec2 pix = floor(UV * S2) - vec2(float(half_w), float(half_h));
	if (cell > 1) pix = floor(pix / float(cell)) * float(cell) + 0.5 * float(cell - 1);
	vec2 gp = pix;
	pix -= ctr_off;
	// THE WORLD'S EDGE KEPT CLEAN (Jon: a "ragged right edge" at zoom 4). The far
	// half shows round the world's limb, and in the world's own ramp: from its dark
	// side the thick ring is the ramp's darkest step, the same colour as the dim
	// edge of the disc, so the two ran together and the limb came out squared off
	// where the ring passes behind it. Sky is left between them: past the
	// disc's own test (a block is the world's if its middle is inside r), past
	// the block of thin air the world draws round its rim, and one block more,
	// so the outline is the world's circle whatever colour the ring is.
	bool edge = !near && length(pix) <= r + 2.0 * float(cell);
	vec3 L = normalize(light);
	float sq = sqrt(1.0 - open * open);
	// the face toward you, and how high the sun stands over it (below: the dark face)
	float mu = dot(L, vec3(0.0, -sq, open));
	float lit_face = mu > 0.0 ? 1.0 : 0.0;
	float sun_up = sqrt(clamp(abs(mu) * 1.6, 0.0, 1.0));
	float a_sum = 0.0, v_sum = 0.0, d_sum = 0.0, s_sum = 0.0;
	const int NS = 4;
	for (int j = 0; j < NS; j++) for (int i = 0; i < NS; i++) {
		vec2 s = pix + (vec2(float(i), float(j)) + 0.5) / float(NS) * float(cell) - 0.5 * float(cell);
		// the near half is the half below the world's centre
		if ((s.y >= 0.0) != near) continue;
		float u = s.x / r, w = s.y / (open * r);
		float rho = length(vec2(u, w));
		if (rho < rin || rho > rout) continue;
		vec4 p = texture(prof, vec2((rho - rin) / (rout - rin), 0.5));
		float o = p.r;
		if (o < 0.004) continue;
		// the point in space, in world radii, and the world's shadow on it
		vec3 P = vec3(u, w * open, w * sq);
		float b = dot(P, L);
		float miss = sqrt(max(0.0, dot(P, P) - b * b));
		float sh = b < 0.0 ? smoothstep(0.96, 1.04, miss) : 1.0;
		s_sum += o * (b < 0.0 && miss < 1.0 ? 1.0 : 0.0);
		sh = mix(1.0 - dark_shadow, 1.0, sh);
		float v;
		// (the sun's height only takes the edge off: a ring lit at a slant
		// still has to read as a ring at the size the map draws it)
		if (radiant && lit_face > 0.5) v = p.g * (0.1 + 0.78 * (0.6 + 0.4 * sun_up) * sh * min(1.25, k_light));
		else if (radiant) v = p.g * (0.08 + 3.4 * o * (1.0 - o) * sh * k_light * (0.6 + 0.4 * sun_up)) + 0.22 * (1.0 - o) * sh * k_light;
		else if (lit_face > 0.5) v = p.g * (0.1 + 0.9 * (0.55 + 0.45 * sun_up) * sh * min(1.0, k_light));
		// lit from behind: through the thin parts, hardly at all through the thick
		else v = p.g * (0.06 + 2.4 * o * (1.0 - o) * sh * k_light * (0.5 + 0.5 * sun_up));
		a_sum += o;
		v_sum += o * v;
		d_sum += o * p.b;
	}
	float n = float(NS * NS);
	float a = a_sum / n;
	vec2 at = centre + gp;
	if (edge || a <= 0.0 || distance(at, star_at) < star_r) { COLOR = vec4(0.0); }
	else {
		float v = v_sum / a_sum;
		// how solid: none, half or all -- not dithered between, which laid a
		// checkerboard over every thin ring
		float aq = a < 0.08 ? 0.0 : (a < 0.55 ? 0.5 : 1.0);
		int ramp = d_sum / a_sum > 0.5 ? ramp_b : ramp_a;
		vec3 col = rampc(ramp, int(floor(v * 6.0 + (bayer2(gp.x, gp.y) - 1.5) * 0.22)));
		if (painted) {
			int cl = max(cell, 1);
			bool chk = ((((int(gp.x) + 1000 * cl) / cl) + ((int(gp.y) + 1000 * cl) / cl)) & 1) == 1;
			int st = v < 0.38 ? 2 : (v < 0.7 ? 3 : 4);
			if (lit_face < 0.5) st -= 1;
			if (s_sum / a_sum > 0.5) st = 1;
			col = rampc(ramp, st);
			aq = a < 0.1 ? 0.0 : (a < 0.5 ? (chk ? 1.0 : 0.0) : 1.0);
		}
		COLOR = vec4(col * aq, aq);
	}
}
